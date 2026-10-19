; WAR.INC - part of OWL FLY II (included from CITY.ASM: the sixth segment)
; ============================================================================
;  THE SHARED WAR (the pilot, 2026-10-18: one war for everyone in a sky).
;
;  Until now every machine fought its own 20 v 20: the wire carried only
;  the humans, so two pilots in one sky saw two different wars - a bot shot
;  down on one screen flew on, untouched, on the other. Now ONE machine
;  runs the war, the WAR HOST, and the others watch it:
;
;  WHO HOSTS: the pilot with the LOWEST pid heard in the sky. Every machine
;  works that out for itself from the 'P' packets NET.INC already hears, so
;  every machine gets the same answer and no server is needed - with no
;  network you are your own host; on a wire without a server the lowest
;  pilot is; with the WIRE CITY server too (it hosts the SKY, not the war).
;  The host leaves: its packets stop, and a second later the next lowest
;  carries on from the positions it was drawing.
;
;  WHAT GOES: on a socket of its own, 5858h (a palindrome, as NET.INC's
;  5757h is, so the byte order of Novell's socket numbers can never bite;
;  and a build without this file never opens it, so it passes them by):
;
;    'B' (host -> all, every WEVERY ticks): the bots, slots 1..WARN-1 -
;        where each is, its heading, down or flying and its armour, its
;        callsign; the round's countdown and winner and the two team
;        scores; and the sides it deals the humans (THE SIDES ON THE
;        WIRE, below). 13 + 35 x 9 + 1 + 5 x 3 = 344 bytes: under the
;        512 an old relay passes.
;        +0 'B'  +1 gid  +3 host pid  +5 rndovr  +7 rwin  +8 tscf
;        +10 tsch  +12 n  then n x { pax pay paz (words)  pah (byte)
;        state (bit 7 down, 0..6 armour)  callsign (pcs<<6 | pnum) }
;        then m  and m x { pid (word)  side (byte) }
;    'K' (host -> all, with every other 'B'): the twenty Shilkas, 206
;        bytes - laid out where WSENDK is.
;    'X' (client -> host): "my guns hit slot S for D" - the host's armour
;        is the one that counts. +0 'X' +1 gid +3 pid +5 slot offset, or
;        80h + a Shilka's number  +6 D
;
;  WHAT CHANGES ON A CLIENT (warcl = 1, in the main segment, while a lower
;  host's 'B' keeps coming): its AI stops DECIDING for the war's slots - no
;  turns, no lane ends, no leash, no building or midair deaths, no
;  launches, no cannon, no round of its own (PLANES.INC: WARCLT and the
;  gates beside it) - and those slots fly on along their heading between
;  packets, as the host's own physics would, each packet setting them
;  right. Its guns still hit them at once, for the spark and the kill on
;  its own screen, and tell the host ('X'). The moment the packets stop for
;  WSTALE ticks - the host left, or a wire that drops big packets - it
;  fights its own war again, exactly as before: nothing ever freezes.
;
;  Slots WARN..39 stay as they always were: the wire's pilots (NET.INC,
;  NETSLT) or this machine's own transports and tanker when nobody wears
;  them. The Shilkas ride in a 'K' of their own - see THE SHILKAS IN THE
;  WAR below - and the host's leash holds a jet to the NEAREST pilot, not
;  to its own camera (WLEASHF), or the war would crowd round the host.
;
;  The same file as OWL FLY III's, word for word but for where it lives
;  and the crewed Shilka II does not have - a change to one is a change to
;  both. Here it has a segment of its own, WARSEG (CS+1A00h, 8K): the
;  main 64K is full and no other window had the 5K its buffers and code
;  take - and opening it moved the back buffer and CITY.DAT up 200h
;  (CITY.ASM, both constants, with the note there read first). DS = the
;  main segment on every door, as the rest of the far code has it.
;
;  Far doors:
;    WARINITF  - open 5858h and post the listens (after NETINITF)
;    WARTICKF  - once a frame, after NETAPPLY: what came, who hosts, and -
;                the host - what goes
;    WARHITF   - a client's guns hit a war bot: SI = its offset, AL = points
;    WSHKXF    - SHKHIT: a client's shell found Shilka [shki]
;    WSHKGF    - SHKGUN: a Shilka's burst told on slot SI
;    WLEASHF   - PLANESUPD: is jet SI still near a pilot? (CF=1: no)
; ============================================================================

segment WARSEG

label WARBASE byte    ; zero, for the window guard at the end

WARSOCK = 5858h               ; the war's socket - a palindrome
WARN    = 36                  ; the war's slots: 1..WARN-1
WLSTN   = 6                   ; listen ECBs of its own. Not two: our OWN 'B'
                                ;  and 'K' come back to us (the wire echoes a
                                ;  broadcast), and with two they filled both
                                ;  and a client's 'X' found no ear; with four
                                ;  a burst of three 'X' in a slow host's frame
                                ;  still lost one (both measured at 1 fps)
WBUF    = 384                 ; the biggest war packet, header and all: 'B',
                                ;  30 + 328. A bigger one lands with an error
                                ;  and is listened past
WSTALE  = 18                  ; ticks without a 'B' before the host is gone (~1 s)
WLIVE   = 36                  ; a pilot heard within this many ticks flies the sky
WEVERY  = 4                   ; the host's 'B', every 4 ticks (~4.5 a second)
WHOLD   = 36                  ; a bot WE downed stays down this long, whatever comes
WJUMP   = 2000                ; a move this big is a respawn: the contrail goes too

wok     db 0                    ; 1 = the socket is open
whost   dw 0                    ; the host whose war we watch (0: our own war)
wlast   dw 0                    ; the tick its last 'B' came
wsent   dw 0                    ; the tick our last 'B' went (when we host)
whold   dw NPLANE dup(0)        ; the tick we shot each bot down (client)
WSECB   db ECBSZ dup(0)
WSHDR   db HDRSZ dup(0)
WSPAY   db 13+(WARN-1)*9+1+WTMAX*3 dup(0) ; the biggest that goes: a 'B', sides and all
WRECB   db WLSTN*ECBSZ dup(0)
WRBUF   db WLSTN*WBUF dup(0)

; ---- WARINITF: open the war's socket and listen - only if NET.INC is up ----
WARINITF:
        push es
        mov  ax,SKYSEG
        mov  es,ax
        cmp  byte [es:netok],0
        je   .no                ; no IPX: our own war, as ever
        mov  bx,0               ; open socket: DX = number, AL = 0 until exit
        mov  al,0
        mov  dx,WARSOCK
        int  7Ah
        sti                     ; the driver may hand IF back OFF
        or   al,al
        jnz  .no
        xor  si,si
.pl:    push si
        call WARM
        pop  si
        inc  si
        cmp  si,WLSTN
        jb   .pl
        mov  byte [cs:wok],1
.no:    pop  es
        retf

; ---- WARM: arm listen ECB si (0..WLSTN-1) on the war's socket ---------------
WARM:   push es
        mov  ax,si
        mov  bx,ECBSZ
        mul  bx
        mov  di,WRECB
        add  di,ax              ; DI -> the ECB
        mov  ax,si
        mov  bx,WBUF
        mul  bx
        add  ax,WRBUF           ; its buffer
        mov  word [cs:di+E_LNK],0
        mov  word [cs:di+E_LNK+2],0
        mov  word [cs:di+E_ESR],0   ; no ESR: we poll
        mov  word [cs:di+E_ESR+2],0
        mov  word [cs:di+E_SOCK],WARSOCK
        mov  word [cs:di+E_FCNT],1
        mov  word [cs:di+E_F1OF],ax
        mov  word [cs:di+E_F1SG],WARSEG
        mov  word [cs:di+E_F1LN],WBUF
        mov  ax,WARSEG
        mov  es,ax
        mov  si,di              ; ES:SI -> ECB
        mov  bx,4               ; ListenForPacket
        int  7Ah
        sti
        pop  es
        ret

; ---- WXMIT: broadcast WSHDR+WSPAY on the war's socket, CX = payload bytes ---
; NET.INC's NETXMIT, on this segment's ECB: drops the packet if the last
; one is still in flight - a war packet late is a war packet stale.
WXMIT:  push es
        mov  ax,SKYSEG
        mov  es,ax
        cmp  byte [cs:WSECB+E_INUSE],0
        jne  .out
        mov  byte [cs:WSHDR+H_PT],4
        mov  ax,word [es:mynode]    ; our own network number: DOSBox
        mov  word [cs:WSHDR+H_DNET],ax   ; broadcasts stay on the wire
        mov  ax,word [es:mynode+2]
        mov  word [cs:WSHDR+H_DNET+2],ax
        mov  ax,0FFFFh
        mov  word [cs:WSHDR+H_DNODE],ax
        mov  word [cs:WSHDR+H_DNODE+2],ax
        mov  word [cs:WSHDR+H_DNODE+4],ax
        mov  word [cs:WSHDR+H_DSOCK],WARSOCK
        mov  word [cs:WSECB+E_LNK],0
        mov  word [cs:WSECB+E_LNK+2],0
        mov  word [cs:WSECB+E_ESR],0
        mov  word [cs:WSECB+E_ESR+2],0
        mov  word [cs:WSECB+E_SOCK],WARSOCK
        mov  word [cs:WSECB+E_IMM],0FFFFh
        mov  word [cs:WSECB+E_IMM+2],0FFFFh
        mov  word [cs:WSECB+E_IMM+4],0FFFFh
        mov  word [cs:WSECB+E_FCNT],1
        mov  word [cs:WSECB+E_F1OF],WSHDR
        mov  word [cs:WSECB+E_F1SG],WARSEG
        mov  ax,HDRSZ
        add  ax,cx
        mov  word [cs:WSECB+E_F1LN],ax
        mov  ax,WARSEG
        mov  es,ax
        mov  si,WSECB
        mov  bx,3               ; SendPacket
        int  7Ah
        sti
        mov  cx,5000            ; give the driver its time - bounded: a
.sw:    cmp  byte [cs:WSECB+E_INUSE],0   ; frame never wedges on the wire
        je   .out
        mov  bx,0Ah             ; RelinquishControl
        int  7Ah
        sti
        loop .sw
.out:   pop  es
        ret

; ---- WARTICKF: once a frame -------------------------------------------------
WARTICKF:
        cmp  byte [cs:wok],0
        jne  .go
        retf
.go:    push es
        ; ---- 1. what came: every listen that landed, then armed again
        xor  si,si
.e:     push si
        mov  ax,si
        mov  bx,ECBSZ
        mul  bx
        mov  di,WRECB
        add  di,ax
        cmp  byte [cs:di+E_INUSE],0
        jne  .nx               ; still listening
        cmp  byte [cs:di+E_CC],0
        jne  .re               ; a bad landing: just listen again
        mov  ax,si
        mov  bx,WBUF
        mul  bx
        add  ax,WRBUF+HDRSZ
        mov  bx,ax              ; BX -> the payload
        call WTAKE
.re:    pop  si
        push si
        call WARM
.nx:    pop  si
        inc  si
        cmp  si,WLSTN
        jb   .e
        ; ---- 2. still watching a host's war?
        mov  byte [warcl],0
        cmp  word [cs:whost],0
        je   .own
        mov  ax,[lasttk]
        sub  ax,[cs:wlast]
        cmp  ax,WSTALE
        jae  .lost
        mov  byte [warcl],1     ; its war, not ours: a client sends no war
        jmp  .out
.lost:  mov  word [cs:whost],0  ; gone: our own war again, from where it stands
.own:   ; ---- 3. our own war - and its host, if nobody LOWER flies the sky.
        ; Alone too: the site's live map watches the war (the server keeps
        ; the host's packets for it), and a pilot who joins finds it running
        mov  ax,SKYSEG
        mov  es,ax
        xor  si,si
.rp:    mov  ax,[es:rpid+si]
        or   ax,ax
        jz   .rn
        mov  dx,[lasttk]
        sub  dx,[es:rlast+si]
        cmp  dx,WLIVE
        jae  .rn
        cmp  ax,[es:mypid]
        jb   .out              ; a lower pilot flies: his war is coming
.rn:    add  si,2
        cmp  si,NRMT*2
        jb   .rp
        mov  ax,[lasttk]
        sub  ax,[cs:wsent]
        cmp  ax,WEVERY
        jb   .out
        mov  ax,[lasttk]
        mov  [cs:wsent],ax
        call WSENDB
        xor  byte [cs:wktog],1
        jz   .out              ; every other 'B' takes the Shilkas along
        mov  ax,SKYSEG
        mov  es,ax
        call WSENDK
.out:   pop  es
        retf

; ---- WTAKE: one war packet, BX -> its payload (CS) --------------------------
WTAKE:  mov  dx,word [cs:bx+1]  ; its sky
        cmp  dx,[ggid]
        jne  .x
        mov  al,[cs:bx]
        cmp  al,'B'
        je   .b
        cmp  al,'X'
        je   .hit
        cmp  al,'K'
        je   .shk
.x:     ret
.shk:   mov  dx,word [cs:bx+3]  ; the Shilkas of the host we follow, only
        or   dx,dx
        jz   .x
        cmp  dx,[cs:whost]
        jne  .x
        jmp  WAPPLYK
.b:     ; a host's war: only a LOWER pid than ours hosts us (our own echo,
        ; an equal, a higher - none of them)
        mov  ax,SKYSEG
        mov  es,ax
        mov  dx,word [cs:bx+3]
        cmp  dx,[es:mypid]
        jae  .x
        mov  ax,[cs:whost]      ; the one we follow, or a lower one: theirs.
        or   ax,ax              ;  A higher one while ours still sends is a
        jz   .take              ;  machine that has not heard ours yet
        cmp  dx,ax
        jbe  .take
        mov  ax,[lasttk]
        sub  ax,[cs:wlast]
        cmp  ax,WSTALE
        jb   .x
.take:  mov  [cs:whost],dx
        mov  ax,[lasttk]
        mov  [cs:wlast],ax
        jmp  WAPPLY
.hit:   ; a client's guns found one of OUR bots: our armour counts it
        cmp  byte [warcl],0
        jne  .x                ; we are a client ourselves: not ours to count
        xor  ah,ah
        mov  al,[cs:bx+5]       ; the slot's offset
        test al,80h
        jnz  .hk               ; 80h + n: Shilka n
        mov  si,ax
        cmp  si,2
        jb   .x
        cmp  si,WARN*2
        jae  .x
        mov  di,si
        shr  di,1
        cmp  byte [pst+di],0
        jne  .x                ; down already
        mov  al,[cs:bx+6]
        sub  [php+di],al
        jg   .x                ; wounded, still flying
        call CODE:BOOMF         ; SI = the bot: down, here - and in the next 'B'
        ret
.hk:    and  al,7Fh
        cmp  al,NSHILK
        jae  .x
        mov  si,ax
        mov  ax,UISEG
        mov  es,ax
        cmp  byte [es:shkst+si],0
        jne  .x                ; burning already
        mov  al,[es:shkhp+si]
        sub  al,[cs:bx+6]
        jbe  .hb               ; SHKDAM's sum: the last one burns it
        mov  [es:shkhp+si],al
        ret
.hb:    jmp  WSHKBURN           ; here, and in the next 'K'

; ---- WAPPLY: a host's 'B' onto our slots, BX -> its payload (CS) ------------
WAPPLY: mov  [cs:wapb],bx       ; the payload's start: the sides follow the bots
        mov  ax,[cs:bx+5]
        mov  [rndovr],ax        ; the round is the host's
        mov  al,[cs:bx+7]
        mov  [rwin],al
        mov  ax,[cs:bx+8]
        mov  [tscf],ax          ; and so is the score
        mov  ax,[cs:bx+10]
        mov  [tsch],ax
        xor  ch,ch
        mov  cl,[cs:bx+12]
        cmp  cl,WARN-1
        jbe  .n
        mov  cl,WARN-1
.n:     add  bx,13
        mov  si,2               ; slot 1
.s:     jcxz .done
        push cx
        mov  di,si
        shr  di,1
        cmp  byte [premote+di],0
        jne  .kept             ; a real pilot wears it here: the wire's, not the war's
        ; a jump this big is a respawn or a leash: the contrail goes with it
        mov  ax,[cs:bx]
        sub  ax,[pax+si]
        jns  .j1
        neg  ax
.j1:    mov  dx,ax
        mov  ax,[cs:bx+4]
        sub  ax,[paz+si]
        jns  .j2
        neg  ax
.j2:    add  dx,ax
        mov  ax,[cs:bx]
        mov  [pax+si],ax
        mov  ax,[cs:bx+2]
        mov  [pay+si],ax
        mov  ax,[cs:bx+4]
        mov  [paz+si],ax
        cmp  dx,WJUMP
        jb   .pos
        call WTRAIL
.pos:   xor  ah,ah
        mov  al,[cs:bx+6]
        mov  [pah+si],ax
        mov  al,[cs:bx+8]       ; the callsign: pcs<<6 | pnum
        mov  ah,al
        and  al,63
        mov  [pnum+di],al
        mov  cl,6
        shr  ah,cl
        mov  [pcs+di],ah
        mov  al,[cs:bx+7]       ; down or flying, and the armour
        mov  ah,al
        and  ah,7Fh
        mov  [php+di],ah
        test al,80h
        jz   .alive
        cmp  byte [pst+di],0
        jne  .kept             ; down here already
        push bx                 ; the host saw it go down: so do we -
        push si                 ; the wreck and the bang, here too
        call CODE:BOOMF
        pop  si
        pop  bx
        jmp  .kept
.alive: cmp  byte [pst+di],0
        je   .kept
        ; down here, flying there: one WE shot stays down a while (the host
        ; may not have heard our 'X' yet); else it is the next round's
        mov  ax,[lasttk]
        sub  ax,[cs:whold+si]
        cmp  ax,WHOLD
        jb   .kept
        mov  byte [pst+di],0
.kept:  add  bx,9
        add  si,2
        pop  cx
        dec  cx
        jmp  .s
.done:  jmp  WTREAD             ; and the sides the host deals, after them

; ---- WTRAIL: the contrail ring of slot SI, all of it at where it is now ----
; (PLANESUPD's leash does the same: a jet that moved far must not drag a
; line across the sky from where it was.)
WTRAIL: push bx
        push cx
        mov  bx,si
        add  bx,bx
        add  bx,bx              ; si*4
        mov  ax,bx
        add  ax,ax
        add  bx,ax              ; si*12: a ring of TLN words
        mov  cx,TLN
.r:     mov  ax,[pax+si]
        mov  [TLX+bx],ax
        mov  ax,[pay+si]
        mov  [TLY+bx],ax
        mov  ax,[paz+si]
        mov  [TLZ+bx],ax
        add  bx,2
        loop .r
        pop  cx
        pop  bx
        ret

; ---- WSENDB: our war, as a 'B'. ES = SKYSEG ---------------------------------
WSENDB: cmp  byte [cs:WSECB+E_INUSE],0
        je   .go
        ret                     ; the last one still in flight: not over it
.go:    call WTEAMS             ; the sides dealt first (ES = SKYSEG)
        mov  byte [cs:WSPAY],'B'
        mov  ax,[ggid]
        mov  word [cs:WSPAY+1],ax
        mov  ax,[es:mypid]
        mov  word [cs:WSPAY+3],ax
        mov  ax,[rndovr]
        mov  word [cs:WSPAY+5],ax
        mov  al,[rwin]
        mov  [cs:WSPAY+7],al
        mov  ax,[tscf]
        mov  word [cs:WSPAY+8],ax
        mov  ax,[tsch]
        mov  word [cs:WSPAY+10],ax
        mov  byte [cs:WSPAY+12],WARN-1
        mov  bx,WSPAY+13
        mov  si,2
.s:     mov  ax,[pax+si]
        mov  [cs:bx],ax
        mov  ax,[pay+si]
        mov  [cs:bx+2],ax
        mov  ax,[paz+si]
        mov  [cs:bx+4],ax
        mov  ax,[pah+si]
        mov  [cs:bx+6],al
        mov  di,si
        shr  di,1
        mov  al,[php+di]
        and  al,7Fh
        cmp  byte [pst+di],0
        je   .up
        mov  al,80h             ; down: no armour to tell (it went below 0)
.up:    mov  [cs:bx+7],al
        mov  al,[pcs+di]
        mov  cl,6
        shl  al,cl
        or   al,[pnum+di]
        mov  [cs:bx+8],al
        add  bx,9
        add  si,2
        cmp  si,WARN*2
        jb   .s
        ; the sides (WTEAMS): n, then n x { pid (word), side (byte) }
        mov  di,bx
        inc  bx
        xor  cx,cx
        xor  si,si
.wt:    mov  dx,si
        add  dx,dx
        xchg dx,di
        mov  ax,[cs:wtpid+di]
        xchg dx,di
        or   ax,ax
        jz   .wtn
        mov  [cs:bx],ax
        mov  al,[cs:wtsid+si]
        mov  [cs:bx+2],al
        add  bx,3
        inc  cx
.wtn:   inc  si
        cmp  si,WTMAX
        jb   .wt
        mov  [cs:di],cl
        mov  cx,bx
        sub  cx,WSPAY           ; the whole payload
        jmp  WXMIT

; ---- WARHITF: our guns hit a bot of the host's war --------------------------
; in: SI = its offset, AL = the points. Tells the host ('X'), and holds the
; bot down here if it went down here, until the host's own 'B' agrees.
WARHITF:
        push ax
        push bx
        push cx
        push si                 ; WXMIT walks SI; the gun's loop needs it back
        push es
        cmp  si,WARN*2
        jae  .r
        mov  bx,[lasttk]
        mov  [cs:whold+si],bx
        mov  ah,al              ; the points...
        mov  bx,si
        mov  al,bl              ; ...on this slot
        call WSENDX
.r:     pop  es
        pop  si
        pop  cx
        pop  bx
        pop  ax
        retf

; ---- WSENDX: an 'X' to the host. AL = what was hit (a slot's offset, or
; 80h + a Shilka), AH = the points. Clobbers AX BX CX SI ES.
WSENDX: cmp  byte [cs:WSECB+E_INUSE],0
        jne  .r                 ; the last one still in flight: not over it
        mov  [cs:WSPAY+5],al
        mov  [cs:WSPAY+6],ah
        mov  byte [cs:WSPAY],'X'
        mov  ax,[ggid]
        mov  word [cs:WSPAY+1],ax
        mov  ax,SKYSEG
        mov  es,ax
        mov  ax,[es:mypid]
        mov  word [cs:WSPAY+3],ax
        mov  cx,7
        jmp  WXMIT
.r:     ret

; ============================================================================
;  THE SHILKAS IN THE WAR. Twenty of them crawl the front, and they drive:
;  a post each machine planted for itself would put one battery in two
;  places. So the host's go out too, as a 'K' with every other 'B':
;    +0 'K'  +1 gid  +3 host pid  +5 n (NSHILK)  then n x { shkx shky shkz
;    (words)  hull  turret  barrels  state (bit 7 burning, 0..5 armour) }
;  6 + 20 x 10 = 206 bytes. A client's own Shilkas stop deciding (SHKTICK:
;  no AI, no drive, no aim, no gun) and stand where the 'K' puts them (in
;  III, all but the one he crews: II has no crewed seat). A client's shell on a Shilka burns it at once on his screen and tells the
;  host ('X', 80h + the vehicle); the host's guns on a pilot over the wire
;  are told to him ('H', as the bots' are) instead of being chalked here.
; ============================================================================
wktog   db 0                    ; every other 'B' takes a 'K' along
wkhold  dw NSHILK dup(0)        ; the tick we hit each Shilka (client)

; ---- WSENDK: our Shilkas, as a 'K'. ES = SKYSEG ------------------------------
WSENDK: cmp  byte [cs:WSECB+E_INUSE],0
        jne  .r                 ; the 'B' still in flight: the next one, then
        mov  byte [cs:WSPAY],'K'
        mov  ax,[ggid]
        mov  word [cs:WSPAY+1],ax
        mov  ax,[es:mypid]
        mov  word [cs:WSPAY+3],ax
        mov  byte [cs:WSPAY+5],NSHILK
        mov  bx,WSPAY+6
        mov  ax,UISEG
        mov  es,ax
        xor  si,si
.k:     mov  di,si
        add  di,di
        mov  ax,[es:shkx+di]
        mov  [cs:bx],ax
        mov  ax,[es:shky+di]
        mov  [cs:bx+2],ax
        mov  ax,[es:shkz+di]
        mov  [cs:bx+4],ax
        mov  al,[es:shkh+si]
        mov  [cs:bx+6],al
        mov  al,[es:shkt+si]
        mov  [cs:bx+7],al
        mov  al,[es:shkel+si]
        mov  [cs:bx+8],al
        mov  al,[es:shkhp+si]
        and  al,3Fh
        cmp  byte [es:shkst+si],0
        je   .up
        mov  al,80h             ; burning: no armour to tell
.up:    mov  [cs:bx+9],al
        add  bx,10
        inc  si
        cmp  si,NSHILK
        jb   .k
        mov  cx,6+NSHILK*10
        jmp  WXMIT
.r:     ret

; ---- WAPPLYK: a host's 'K' onto our Shilkas, BX -> its payload (CS) ---------
WAPPLYK:
        cmp  byte [cs:bx+5],NSHILK
        jne  .r                 ; not our twenty: leave ours be
        add  bx,6
        mov  ax,UISEG
        mov  es,ax
        xor  si,si
.k:     mov  di,si
        add  di,di
        mov  ax,[cs:bx]
        mov  [es:shkx+di],ax
        mov  ax,[cs:bx+2]
        mov  [es:shky+di],ax
        mov  ax,[cs:bx+4]
        mov  [es:shkz+di],ax
        mov  al,[cs:bx+6]
        mov  [es:shkh+si],al
        mov  al,[cs:bx+7]
        mov  [es:shkt+si],al
        mov  al,[cs:bx+8]
        mov  [es:shkel+si],al
        mov  al,[cs:bx+9]
        mov  ah,al
        and  ah,3Fh
        test al,80h
        jz   .up
        cmp  byte [es:shkst+si],0
        jne  .kn                ; burning here already
        call WSHKBURN           ; the host saw it burn: so do we
        jmp  .kn
.up:    cmp  byte [es:shkst+si],0
        je   .hp
        push ax                 ; burning here, standing there: one WE hit
        mov  ax,[lasttk]        ;  burns a while (the host may not have our
        sub  ax,[cs:wkhold+di]  ;  'X' yet); then it is the host's word
        cmp  ax,WHOLD
        pop  ax
        jb   .kn
        mov  byte [es:shkst+si],0
.hp:    mov  [es:shkhp+si],ah
.kn:    add  bx,10
        inc  si
        cmp  si,NSHILK
        jb   .k
.r:     ret

; ---- WSHKBURN: Shilka SI burns - SHKDAM's last hit, from out here. ES = UISEG
; Eight slabs of grey steel, the fire and the bang, and no lock on it.
WSHKBURN:
        push bx
        push di
        push si
        push es
        mov  byte [es:shkhp+si],0
        mov  byte [es:shkst+si],1
        mov  ax,si
        add  ax,ax
        add  ax,SHKLK
        cmp  ax,[locki]
        jne  .nl
        mov  word [locki],0FFFFh
.nl:    mov  bx,si
        add  bx,bx
        mov  ax,[es:shkx+bx]
        mov  [bpx],ax
        mov  ax,[es:shkz+bx]
        mov  [bpz],ax
        mov  word [bschm],0     ; grey walls: steel, not brick
        call CODE:WRKATF
        pop  es
        pop  si
        pop  di
        pop  bx
        ret

; ---- WSHKXF: our shell found a Shilka ([cs:shki] in UISEG, [rhdmg] points).
; SHKHIT calls it just before its own SHKDAM: a client tells the host too.
WSHKXF: cmp  byte [warcl],0
        je   .r0
        push ax
        push bx
        push cx
        push si
        push es
        mov  ax,UISEG
        mov  es,ax
        mov  bx,[es:shki]
        mov  si,bx
        add  si,si
        mov  ax,[lasttk]
        mov  [cs:wkhold+si],ax
        mov  al,bl
        or   al,80h
        mov  ah,[rhdmg]
        call WSENDX
        pop  es
        pop  si
        pop  cx
        pop  bx
        pop  ax
.r0:    retf

; ---- WSHKGF: a Shilka's burst told on slot SI (SHKGUN's lottery). A pilot
; over the wire is TOLD - his machine decides; an AI jet loses one, and the
; last one brings it down. It never did: SHKGUN only counted down, so a jet
; the flak took to 0 flew on, and the next shell wrapped it to 255 - a bot
; nothing could kill, found when the war put its armour on the wire.
WSHKGF: mov  bx,si
        shr  bx,1
        cmp  byte [premote+bx],0
        jne  .tell
        dec  byte [php+bx]
        jg   .r                 ; hit, still flying
        call CODE:BOOMF         ; SI = the jet: the flak got it
.r:     retf
.tell:  mov  al,bl
        mov  ah,1
        call SKYSEG:NETHITAIF
        retf

; ---- WLEASHF: the leash of AI jet SI, to the NEAREST pilot ------------------
; One machine flies the war for the whole sky. A jet leashed to that
; machine's camera alone would crowd round its pilot and leave everyone
; else an empty sky - so the leash holds while the jet is inside 12000 of
; ANY pilot: this camera, or a pilot over the wire (slots NETSLT..). Alone
; in the sky that is the camera and nothing else: the war as it always was.
; out: CF=0 inside. CF=1 beyond them all, and [wlcx]/[wlcz] is the pilot it
; re-enters beside - the pilots in turn, this camera one of them.
wturn   db 0                    ; the last pilot a jet re-entered beside
WLEASHF:
        push bx
        push di
        mov  ax,[camx]
        mov  dx,[camz]
        call WNEAR
        jnc  .in
        mov  di,NETSLT          ; the pilots over the wire
.p:     cmp  byte [premote+di],0
        je   .pn
        cmp  byte [pst+di],0
        jne  .pn                ; a pilot down anchors nothing
        mov  bx,di
        add  bx,bx
        mov  ax,[pax+bx]
        mov  dx,[paz+bx]
        call WNEAR
        jnc  .in
.pn:    inc  di
        cmp  di,NETSLT+NRMT
        jb   .p
        ; beyond them all: the next pilot in turn takes it (0 = this camera,
        ; 1..NRMT = the wire's slots); the camera always answers, so the
        ; walk ends within one lap
        mov  bl,[cs:wturn]
.t:     inc  bl
        cmp  bl,NRMT
        jbe  .tc
        xor  bl,bl
.tc:    or   bl,bl
        jz   .cam
        xor  bh,bh
        mov  di,bx
        add  di,NETSLT-1
        cmp  byte [premote+di],0
        je   .t
        cmp  byte [pst+di],0
        jne  .t
        mov  [cs:wturn],bl
        add  di,di
        mov  ax,[pax+di]
        mov  [wlcx],ax
        mov  ax,[paz+di]
        mov  [wlcz],ax
        stc
        jmp  .r
.cam:   mov  [cs:wturn],bl
        mov  ax,[camx]
        mov  [wlcx],ax
        mov  ax,[camz]
        mov  [wlcz],ax
        stc
        jmp  .r
.in:    clc
.r:     pop  di
        pop  bx
        retf

; WNEAR: is jet SI inside 12000 of the pilot at AX,DX (x,z)? CF=0 yes,
; CF=1 no. The square leash PLANESUPD always had, its distances unsigned.
WNEAR:  sub  ax,[pax+si]
        jns  .a
        neg  ax
.a:     cmp  ax,12000
        jae  .no
        sub  dx,[paz+si]
        jns  .b
        neg  dx
.b:     cmp  dx,12000
        jae  .no
        clc
        ret
.no:    stc
        ret

; ============================================================================
;  THE SIDES ON THE WIRE (the pilot, 2026-10-19): every human who joins is
;  the enemy - the sides fill evenly - and when leaving makes them uneven by
;  two, the latest to join crosses over. The WAR HOST deals them (WTEAMS),
;  every 'B' carries the deal after its bots, and each pilot takes his own
;  at his next life (AFSPAWN -> SETSIDE, PLANES.INC): nobody changes sides
;  in mid-air. Everyone else reads a pilot's side from his own 'P' (+16,
;  NET.INC) - his word, as his life is. The latest to join is the highest
;  pid: the relay numbers its connections in order. A pilot who comes to
;  host carries on with the deal he last heard (WTREAD keeps it).
; ============================================================================
WTMAX   = NRMT+1                ; the humans one sky holds: us and the wire's four
wtpid   dw WTMAX dup(0)         ; the deal: who...
wtsid   db WTMAX dup(0)         ; ...and which side (0 the even slots', 1 the odd)
wapb    dw 0                    ; WAPPLY's payload, for WTREAD

; ---- WTEAMS: the war host deals the sides. ES = SKYSEG -----------------------
WTEAMS: push ax
        push bx
        push cx
        push dx
        push si
        push di
        ; the ones gone off the wire leave the deal
        xor  si,si
.g:     mov  bx,si
        add  bx,bx
        mov  ax,[cs:wtpid+bx]
        or   ax,ax
        jz   .gn
        call WFLIES
        jc   .gn
        mov  word [cs:wtpid+bx],0
.gn:    inc  si
        cmp  si,WTMAX
        jb   .g
        ; us, not dealt yet: on the side we fly
        mov  ax,[es:mypid]
        call WINDEX
        jc   .us
        push ax
        xor  ax,ax
        call WINDEX             ; an empty entry (there is one: us + NRMT)
        pop  ax
        jnc  .us
        mov  bx,di
        add  bx,bx
        mov  [cs:wtpid+bx],ax
        mov  dl,[myside]
        mov  [cs:wtsid+di],dl
.us:    ; a pilot heard and not dealt: to the side with fewer - and, even,
        ; against the latest to join
        xor  si,si
.p:     mov  ax,[es:rpid+si]
        or   ax,ax
        jz   .pn
        mov  dx,[lasttk]
        sub  dx,[es:rlast+si]
        cmp  dx,WLIVE
        jae  .pn
        call WINDEX
        jc   .pn               ; dealt already
        push ax
        xor  ax,ax
        call WINDEX
        pop  ax
        jnc  .pn               ; no room
        push di                 ; the empty entry
        call WCOUNT             ; CL the even side's, CH the odd's
        mov  dl,0
        cmp  cl,ch
        jb   .sd               ; fewer on the even side
        mov  dl,1
        ja   .sd               ; fewer on the odd
        call WLAST              ; level: against the latest to join
        cmp  di,0FFFFh
        je   .sd
        mov  dl,[cs:wtsid+di]
        xor  dl,1
.sd:    pop  di
        mov  bx,di
        add  bx,bx
        mov  [cs:wtpid+bx],ax
        mov  [cs:wtsid+di],dl
.pn:    add  si,2
        cmp  si,NRMT*2
        jb   .p
        ; two up on one side: its latest to join crosses (at his next life)
        call WCOUNT
        mov  al,ch
        add  al,2
        cmp  cl,al
        jb   .b1
        mov  al,0               ; the even side two up
        jmp  .bm
.b1:    mov  al,cl
        add  al,2
        cmp  ch,al
        jb   .bx               ; even enough
        mov  al,1
.bm:    call WLASTON
        cmp  di,0FFFFh
        je   .bx
        xor  byte [cs:wtsid+di],1
.bx:    ; and our own next life's side, as we deal it to ourselves
        mov  ax,[es:mypid]
        call WINDEX
        jnc  .x
        mov  al,[cs:wtsid+di]
        mov  [wside],al
.x:     pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; WFLIES: does pid AX fly this sky - us, or a pilot heard lately? CF=1 yes. ES = SKYSEG.
WFLIES: cmp  ax,[es:mypid]
        je   .y
        push si
        push dx
        xor  si,si
.r:     cmp  ax,[es:rpid+si]
        jne  .n
        mov  dx,[lasttk]
        sub  dx,[es:rlast+si]
        cmp  dx,WLIVE
        jb   .yy
.n:     add  si,2
        cmp  si,NRMT*2
        jb   .r
        pop  dx
        pop  si
        clc
        ret
.yy:    pop  dx
        pop  si
.y:     stc
        ret

; WINDEX: pid AX's entry in the deal (AX 0: an empty one): DI its index, CF=1 found.
WINDEX: xor  di,di
.l:     push di
        add  di,di
        cmp  ax,[cs:wtpid+di]
        pop  di
        je   .f
        inc  di
        cmp  di,WTMAX
        jb   .l
        clc
        ret
.f:     stc
        ret

; WCOUNT: CL, CH = the dealt pilots on the even side, on the odd.
WCOUNT: push si
        push bx
        xor  cx,cx
        xor  si,si
.c:     mov  bx,si
        add  bx,bx
        cmp  word [cs:wtpid+bx],0
        je   .cn
        cmp  byte [cs:wtsid+si],0
        jne  .c1
        inc  cl
        jmp  .cn
.c1:    inc  ch
.cn:    inc  si
        cmp  si,WTMAX
        jb   .c
        pop  bx
        pop  si
        ret

; WLAST / WLASTON: DI = the deal's latest to join (the highest pid) - on side
; AL, or on either (WLAST) - never us: the host is not the one moved.
; 0FFFFh: nobody. AX and the rest kept.
WLAST:  push ax
        mov  al,0FFh
        call WLASTON
        pop  ax
        ret
WLASTON:
        push bx
        push cx
        push si
        mov  di,0FFFFh
        xor  cx,cx              ; the highest pid so far
        xor  si,si
.l:     mov  bx,si
        add  bx,bx
        mov  bx,[cs:wtpid+bx]
        or   bx,bx
        jz   .n
        cmp  bx,[es:mypid]
        je   .n
        cmp  al,0FFh
        je   .s
        cmp  al,[cs:wtsid+si]
        jne  .n
.s:     cmp  bx,cx
        jbe  .n
        mov  cx,bx
        mov  di,si
.n:     inc  si
        cmp  si,WTMAX
        jb   .l
        pop  si
        pop  cx
        pop  bx
        ret

; ---- WTREAD: a host's 'B' read past its bots, BX -> the sides it deals ----
; The deal kept whole (we carry it on if we come to host), and our own entry
; is our next life's side. An older host's 'B' has none: nothing changes.
WTREAD: mov  di,[cs:wapb]
        mov  ah,[cs:di-HDRSZ+2]  ; the IPX length, big-endian
        mov  al,[cs:di-HDRSZ+3]
        sub  ax,HDRSZ
        add  ax,di               ; the payload's end
        mov  dx,ax
        mov  ax,bx
        inc  ax
        cmp  ax,dx
        ja   .r                 ; no sides in it
        xor  ch,ch
        mov  cl,[cs:bx]
        cmp  cl,WTMAX
        ja   .r
        mov  ax,cx
        add  ax,ax
        add  ax,cx
        add  ax,bx
        inc  ax                  ; BX + 1 + n*3
        cmp  ax,dx
        ja   .r                 ; cut short: the old deal stands
        inc  bx
        xor  si,si
.z:     mov  di,si
        add  di,di
        mov  word [cs:wtpid+di],0
        inc  si
        cmp  si,WTMAX
        jb   .z
        push es
        mov  ax,SKYSEG
        mov  es,ax
        xor  si,si
.f:     jcxz .q
        mov  ax,[cs:bx]
        mov  di,si
        add  di,di
        mov  [cs:wtpid+di],ax
        mov  dl,[cs:bx+2]
        and  dl,1
        mov  [cs:wtsid+si],dl
        cmp  ax,[es:mypid]
        jne  .nm
        mov  [wside],dl          ; ours: the side of our next life
        mov  byte [wdealt],1     ;  (and Enter may take a jet: SPECTUPF)
.nm:    add  bx,3
        inc  si
        dec  cx
        jmp  .f
.q:     pop  es
.r:     ret

; ---- THE WINDOW GUARD ------------------------------------------------------
label WAREND byte
if ($-WARBASE) > 8176
        %OUT *** WARSEG overflows its 8K window ***
        .ERR
end if
        rb 1FF0h - $   ; claim the whole window, the way TOWNSEG does
        db   16 dup(0)
