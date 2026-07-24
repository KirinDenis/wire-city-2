; NET.INC - part of WIRE CITY (included from CITY.ASM, after SKY.INC)
; ============================================================================
;  THE WIRE: IPX multiplayer, 1990 style.
;
;  The whole world is procedural from one 16-bit seed, so "join a
;  game" is a two-byte handshake: the newcomer broadcasts HELLO, the
;  pilot already flying answers SEED, the newcomer runs the same DSGEN
;  and stands in the same world - island, city, clouds and all. After
;  that everyone broadcasts an 11-byte POS each physics tick, and the
;  other pilots fly YOUR sky as jets in the last four AI slots, drawn
;  by PLANESDRAW like any other traffic.
;
;  Transport: real-mode IPX (INT 2F detect, far entry, ECBs) - inside
;  DOSBox that is IPXNET over UDP; over the internet it is the ViewOwl
;  relay's /ipx pipe. The socket is 5757h: a palindrome, so the
;  big-endian-ness of Novell socket numbers can never bite.
;
;  This file APPENDS to SKYSEG: the ECBs, buffers and code all live in
;  the far segment - the main 64K pays for nothing but four far calls
;  and the premote flags. The 8K window guard sits at the end of THIS
;  file now, covering sky + net together.
;
;  Far doors:
;    NETINITF  - detect IPX, open socket, learn our address, post
;                listens. Returns AL=1 (and DX=our pid) or AL=0.
;    NETHELLOF - broadcast HELLO (the joiner's knock)
;    NETPOLLF  - drain arrived packets. Returns AL=1 + DX=seed ONCE
;                when a SEED lands (the joiner's answer); applies POS
;                and answers HELLO (when hosting) as a side effect.
;    NETHOSTF  - the knock went unanswered: we are the host now
;    NETPOSF   - broadcast our POS (self-gated to one per BIOS tick)
; ============================================================================

SKYSEG  SEGMENT PARA PUBLIC 'CODE'
        ASSUME  CS:SKYSEG, DS:CODE, ES:NOTHING, SS:CODE

NETSOCK equ 5757h               ; the palindrome socket
NETSLT  equ 36                  ; remote pilots wear AI slots 36..39
NRMT    equ 4
NLSTN   equ 4                   ; listen ECBs in flight

; ---- ECB field map (one fragment) ------------------------------------------
; THE LAYOUT THAT ACTUALLY FLIES (proven in EXAMPLES\BBS.ASM): the ECB
; starts with a LINK dword, THEN the ESR - InUse is at +8, not +4. The
; textbook 38-byte map put our segment word where DOSBox reads the
; fragment count: 4514 fragments of garbage = the send that never
; returned (postmortem 2026-07-23).
E_LNK   equ 0                   ; link dword
E_ESR   equ 4                   ; ESR far address, 0 = we poll
E_INUSE equ 8                   ; nonzero while the driver owns it
E_CC    equ 9                   ; completion code, 0 = clean
E_SOCK  equ 10                  ; socket, raw
E_IMM   equ 28                  ; immediate address (6)
E_FCNT  equ 34                  ; fragment count
E_F1OF  equ 36                  ; fragment 1: offset, segment, length
E_F1SG  equ 38
E_F1LN  equ 40
ECBSZ   equ 42

; ---- IPX header field map --------------------------------------------------
H_PT    equ 5                   ; packet type (4 = IPX)
H_DNET  equ 6                   ; destination network (4)
H_DNODE equ 10                  ; destination node (6)
H_DSOCK equ 16                  ; destination socket
HDRSZ   equ 30

; ---- the wire's own state (CS-relative, far from the crowded 64K) ----------
ipxep   dd 0                    ; the IPX far entry point
mynode  db 10 dup(0)            ; our internetwork address: net(4)+node(6)
netok   db 0                    ; 1 = IPX up, socket open
nethost db 0                    ; 1 = we answer HELLOs with our seed
mypid   dw 0                    ; our name on the wire (node tail bytes)
sentk   dw 0                    ; last tick a POS went out
rpid    dw NRMT dup(0)          ; who wears remote slot i (0 = nobody)
rlast   dw NRMT dup(0)          ; the tick their last POS arrived
adtk    dw 0                    ; the tick the last sky ad went out
; send: ECB + header + payload, header and payload CONTIGUOUS - the
; one fragment covers both
SECB    db ECBSZ dup(0)
SHDR    db HDRSZ dup(0)
SPAY    db 16 dup(0)
; receive: NLSTN listen ECBs, 64-byte buffers
RECB    db NLSTN*ECBSZ dup(0)
RBUF    db NLSTN*64 dup(0)

; ============================ the far doors =================================
NETINITF PROC FAR
        call NETINIT
        ret
NETINITF ENDP
NETPOLLF PROC FAR
        call NETPOLL
        ret
NETPOLLF ENDP
NETHOSTF PROC FAR
        mov  byte ptr [nethost],1
        ret
NETHOSTF ENDP
NETPOSF PROC FAR
        call NETPOS
        ret
NETPOSF ENDP

; ---- NETINIT: find IPX, open the socket, learn our name --------------------
NETINIT:
        push es
        mov  ax,7A00h
        int  2Fh
        cmp  al,0FFh
        jne  @@no
        mov  word ptr [ipxep],di
        mov  word ptr [ipxep+2],es
        mov  bx,0               ; open socket: DX = number, AL = live
        mov  al,0               ; until program exit
        mov  dx,NETSOCK
        int  7Ah
        sti                     ; the driver may hand IF back OFF - and
                                ; a frozen BIOS tick starves every wait
        or   al,al
        jnz  @@no
        ; (an IRQ 11 mask lived here for one afternoon: it silenced
        ; DOSBox's ESR bell - and with it, packet DELIVERY. The menu
        ; freeze it was blamed for turned out to be the first UEDGE's
        ; doing. The bell rings; DOSBox answers itself at INT 73h.)
        mov  bx,9               ; our internetwork address -> mynode
        mov  ax,SKYSEG
        mov  es,ax
        mov  si,offset mynode
        int  7Ah
        sti                     ; the driver may hand IF back OFF - and
                                ; a frozen BIOS tick starves every wait
        mov  ax,word ptr [mynode+8] ; the node's tail names us on the
        mov  [mypid],ax             ; wire (DOSBox hands out unique
        or   ax,ax                  ; nodes; zero would read as free)
        jnz  @@pid
        inc  ax
        mov  [mypid],ax
@@pid:  xor  si,si              ; post the listens
@@pl:   push si
        call NETLSTN
        pop  si
        inc  si
        cmp  si,NLSTN
        jb   @@pl
        mov  byte ptr [netok],1
        ; ---- is the wire actually CONNECTED? Send a probe: DOSBox
        ; marks it undeliverable when no ipxnet server is on the other
        ; end, and the completion code says so. The menu shows the
        ; verdict, so "why can't we see each other" answers itself.
        mov  byte ptr [SPAY],'W'
        mov  cx,1
        call NETXMIT
        mov  al,1               ; 1 = IPX up but the wire is DARK
        cmp  byte ptr [SECB+E_CC],0
        jne  @@drk
        mov  al,2               ; 2 = the wire is LIVE
@@drk:  mov  dx,[mypid]
        pop  es
        ret
@@no:   mov  byte ptr [netok],0
        xor  al,al
        pop  es
        ret

; ---- NETLSTN: arm listen ECB si (0..NLSTN-1) -------------------------------
NETLSTN:
        push es
        mov  ax,si
        mov  bx,ECBSZ
        mul  bx
        mov  di,offset RECB
        add  di,ax              ; DI -> the ECB
        mov  ax,si
        mov  cl,6
        shl  ax,cl
        add  ax,offset RBUF     ; its 64-byte buffer
        mov  word ptr cs:[di+E_LNK],0
        mov  word ptr cs:[di+E_LNK+2],0
        mov  word ptr cs:[di+E_ESR],0   ; no ESR: we poll
        mov  word ptr cs:[di+E_ESR+2],0
        mov  word ptr cs:[di+E_SOCK],NETSOCK
        mov  word ptr cs:[di+E_FCNT],1
        mov  word ptr cs:[di+E_F1OF],ax
        mov  word ptr cs:[di+E_F1SG],SKYSEG
        mov  word ptr cs:[di+E_F1LN],64
        mov  ax,SKYSEG
        mov  es,ax
        mov  si,di              ; ES:SI -> ECB
        mov  bx,4               ; ListenForPacket
        int  7Ah
        sti                     ; the driver may hand IF back OFF - and
                                ; a frozen BIOS tick starves every wait
        pop  es
        ret

; ---- NETXMIT: broadcast SHDR+SPAY, CX = payload bytes ----------------------
; Quietly drops the packet if the send ECB is still in flight.
NETXMIT:
        cmp  byte ptr [netok],0
        je   @@drop
        cmp  byte ptr [SECB+E_INUSE],0
        jne  @@drop
        push es
        mov  byte ptr [SHDR+H_PT],4
        mov  ax,word ptr [mynode]   ; our own network number: DOSBox
        mov  word ptr [SHDR+H_DNET],ax   ; broadcasts stay on the wire
        mov  ax,word ptr [mynode+2]
        mov  word ptr [SHDR+H_DNET+2],ax
        mov  ax,0FFFFh
        mov  word ptr [SHDR+H_DNODE],ax
        mov  word ptr [SHDR+H_DNODE+2],ax
        mov  word ptr [SHDR+H_DNODE+4],ax
        mov  word ptr [SHDR+H_DSOCK],NETSOCK
        mov  word ptr [SECB+E_LNK],0
        mov  word ptr [SECB+E_LNK+2],0
        mov  word ptr [SECB+E_ESR],0
        mov  word ptr [SECB+E_ESR+2],0
        mov  word ptr [SECB+E_SOCK],NETSOCK
        mov  word ptr [SECB+E_IMM],0FFFFh
        mov  word ptr [SECB+E_IMM+2],0FFFFh
        mov  word ptr [SECB+E_IMM+4],0FFFFh
        mov  word ptr [SECB+E_FCNT],1
        mov  word ptr [SECB+E_F1OF],offset SHDR
        mov  word ptr [SECB+E_F1SG],SKYSEG
        mov  ax,HDRSZ
        add  ax,cx
        mov  word ptr [SECB+E_F1LN],ax
        mov  ax,SKYSEG
        mov  es,ax
        mov  si,offset SECB
        mov  bx,3               ; SendPacket
        int  7Ah
        sti                     ; the driver may hand IF back OFF - and
                                ; a frozen BIOS tick starves every wait
        mov  cx,5000            ; BBS.ASM's manner: give the driver its
@@sw:   cmp  byte ptr [SECB+E_INUSE],0   ; time (bounded - a game frame
        je   @@sd               ; must never wedge on the wire)
        mov  bx,0Ah             ; RelinquishControl
        int  7Ah
        sti                     ; the driver may hand IF back OFF - and
                                ; a frozen BIOS tick starves every wait
        loop @@sw
@@sd:   pop  es
@@drop: ret

; (HELLO/SEED retired: the menu joins from the 'G' ads, which carry
; the seed already - the handshake became a billboard)

; ---- NETPOS: our position, one broadcast per BIOS tick ---------------------
; Every ~18 ticks the HOST also advertises the sky itself: gid, seed,
; heads, the war score and the name - the menu's whole world.
NETPOS: cmp  byte ptr [netok],0
        je   @@r
        mov  ax,[lasttk]
        cmp  ax,[sentk]
        je   @@r
        mov  [sentk],ax
        mov  byte ptr [SPAY],'P'
        mov  ax,[mypid]
        mov  word ptr [SPAY+1],ax
        mov  ax,[ggid]
        mov  word ptr [SPAY+3],ax
        mov  ax,[camx]
        mov  word ptr [SPAY+5],ax
        mov  ax,[camy]
        mov  word ptr [SPAY+7],ax
        mov  ax,[camz]
        mov  word ptr [SPAY+9],ax
        mov  ax,[heading]
        mov  word ptr [SPAY+11],ax
        mov  cx,13
        call NETXMIT
        cmp  byte ptr [nethost],0
        je   @@r
        mov  ax,[lasttk]        ; the once-a-second sky ad
        sub  ax,[adtk]
        cmp  ax,18
        jb   @@r
        mov  ax,[lasttk]
        mov  [adtk],ax
        call NETADS
@@r:    ret

; ---- NETADS: broadcast the sky ad ('G') ------------------------------------
NETADS: mov  byte ptr [SPAY],'G'
        mov  ax,[ggid]
        mov  word ptr [SPAY+1],ax
        mov  ax,[wseed]
        mov  word ptr [SPAY+3],ax
        mov  al,1               ; heads: us + everyone on our wire
        xor  si,si
@@hc:   mov  di,si
        add  di,di
        cmp  word ptr [rpid+di],0
        je   @@hn
        inc  al
@@hn:   inc  si
        cmp  si,NRMT
        jb   @@hc
        mov  [SPAY+5],al
        ; the war score: kills BY green = yellows down (20..39), and
        ; the mirror. A botless arena reports zeros.
        xor  al,al
        xor  ah,ah
        cmp  byte ptr [gbots],0
        je   @@sc0
        xor  si,si
@@scl:  cmp  byte ptr [premote+si+1],0
        jne  @@scn              ; a live pilot is nobody's kill
        cmp  byte ptr [pst+si+1],0
        je   @@scn
        cmp  si,19              ; slots 1..19 green, 20..39 yellow
        jae  @@scy
        inc  ah                 ; a green down: yellow scores
        jmp  @@scn
@@scy:  inc  al                 ; a yellow down: green scores
@@scn:  inc  si
        cmp  si,39
        jb   @@scl
@@sc0:  mov  [SPAY+6],al
        mov  [SPAY+7],ah
        mov  al,[gbots]
        mov  [SPAY+8],al
        push es
        mov  ax,SKYSEG          ; the name rides at +9: DS gname ->
        mov  es,ax              ; our own SPAY via es:di
        mov  si,offset gname
        mov  di,offset SPAY+9
        mov  cx,8
        cld
        rep  movsb
        pop  es
        mov  cx,17
        call NETXMIT
        ret

; ---- NETPOLL: drain the listens, keep the remote pilots honest -------------
NETPOLL:
        xor  ax,ax
        cmp  byte ptr [netok],0
        jne  @@go
        ret
@@go:   xor  si,si              ; walk the listen ECBs
@@e:    push si
        mov  ax,si
        mov  bx,ECBSZ
        mul  bx
        mov  di,offset RECB
        add  di,ax
        cmp  byte ptr cs:[di+E_INUSE],0
        jne  @@next             ; still listening
        cmp  byte ptr cs:[di+E_CC],0
        jne  @@rearm            ; a bad landing: just relisten
        mov  ax,si              ; the packet: RBUF + si*64 + HDRSZ
        mov  cl,6
        shl  ax,cl
        add  ax,offset RBUF+HDRSZ
        mov  bx,ax              ; BX -> payload
        mov  al,cs:[bx]
        cmp  al,'P'
        je   @@pos
        cmp  al,'G'
        je   @@gad
        jmp  @@rearm
@@gad:  ; ---- a sky's ad: upsert the menu's list (UISEG) ----
        push es
        push si
        mov  ax,UISEG
        mov  es,ax
        mov  dx,word ptr cs:[bx+1]  ; its gid
        mov  bp,-1                  ; first free row
        xor  si,si
@@gf:   mov  ax,si
        mov  cl,4
        shl  ax,cl
        mov  di,ax
        cmp  word ptr es:[GLIST+di],dx
        je   @@gu               ; known sky: refresh it
        cmp  word ptr es:[GLIST+di],0
        jne  @@gn
        cmp  bp,-1
        jne  @@gn
        mov  bp,si              ; remember the empty bunk
@@gn:   inc  si
        cmp  si,NGL
        jb   @@gf
        cmp  bp,-1
        je   @@gz               ; the board is full: let it pass
        mov  si,bp
        mov  ax,si
        mov  cl,4
        shl  ax,cl
        mov  di,ax
@@gu:   mov  word ptr es:[GLIST+di],dx
        mov  ax,word ptr cs:[bx+3]
        mov  word ptr es:[GLIST+di+2],ax ; seed
        mov  al,cs:[bx+5]
        mov  es:[GLIST+di+4],al     ; heads
        mov  al,cs:[bx+6]
        mov  es:[GLIST+di+5],al     ; the score
        mov  al,cs:[bx+7]
        mov  es:[GLIST+di+6],al
        mov  al,cs:[bx+8]
        mov  es:[GLIST+di+7],al     ; bots
        add  di,8                   ; the name rides at +8
        xor  si,si
@@gnm:  mov  al,cs:[bx+si+9]
        mov  es:[GLIST+di],al
        inc  di
        inc  si
        cmp  si,8
        jb   @@gnm
        sub  di,16                  ; back to the entry base
        mov  ax,di                  ; freshness stamp
        mov  cl,3
        shr  ax,cl                  ; row*2 = di/16*2 = di/8
        mov  di,ax
        push es
        mov  ax,40h
        mov  es,ax
        mov  ax,es:[6Ch]
        pop  es
        mov  word ptr es:[GLAST+di],ax
@@gz:   pop  si
        pop  es
        jmp  @@rearm
@@pos:  mov  ax,word ptr cs:[bx+1]  ; whose position?
        cmp  ax,[mypid]
        je   @@rearm            ; our own echo
        or   ax,ax
        jz   @@rearm
        mov  dx,word ptr cs:[bx+3]  ; whose SKY?
        cmp  dx,[ggid]
        jne  @@rearm            ; a different game on the same wire
        call RSLOT              ; DI = remote index 0..3 or -1
        cmp  di,-1
        je   @@rearm
        push si
        mov  si,di
        add  si,si
        mov  ax,[lasttk]
        mov  [rlast+si],ax
        mov  ax,di
        add  ax,NETSLT          ; the plane slot
        mov  si,ax
        mov  byte ptr [premote+si],1
        mov  byte ptr [pst+si],0
        mov  byte ptr [ptype+si],0
        add  si,si              ; word index
        mov  ax,word ptr cs:[bx+5]
        mov  [pax+si],ax
        mov  ax,word ptr cs:[bx+7]
        mov  [pay+si],ax
        mov  ax,word ptr cs:[bx+9]
        mov  [paz+si],ax
        mov  ax,word ptr cs:[bx+11]
        mov  [pah+si],ax
        pop  si
@@rearm:
        pop  si
        push si
        call NETLSTN            ; back on watch
@@next: pop  si
        inc  si
        cmp  si,NLSTN
        jb   @@e
        ; ---- sweep the ghosts: silence for ~5 s frees the slot ----
        xor  si,si
@@sw:   mov  di,si
        add  di,di
        cmp  word ptr [rpid+di],0
        je   @@swn
        mov  ax,[lasttk]
        sub  ax,[rlast+di]
        cmp  ax,90
        jb   @@swn
        mov  word ptr [rpid+di],0
        mov  bx,si
        add  bx,NETSLT
        mov  byte ptr [pst+bx],1     ; the jet fades from the sky
        mov  byte ptr [premote+bx],0
@@swn:  inc  si
        cmp  si,NRMT
        jb   @@sw
        xor  ax,ax
        ret

; ---- RGRID: the radar's compass-true grey grid + the north anchor ----------
; Dots every 4096 world units through WCAM2 (the same yaw the world
; turns by), clipped in PIXEL space so any zoom fits, plus two
; brighter dots up the NORTH radius. ES = bufseg (the caller's).
RGRIDF  PROC FAR
        call RGRID
        ret
RGRIDF  ENDP
RGRID:  mov  word ptr [rgk],-4
@@gx:   mov  word ptr [rgj],-4
@@gz:   mov  ax,[camx]
        and  ax,0F000h          ; the nearest grid corner west of us
        mov  bx,[rgk]
        mov  cl,12
        shl  bx,cl
        add  ax,bx
        sub  ax,[camx]
        mov  [wdx2],ax
        mov  ax,[camz]
        and  ax,0F000h
        mov  bx,[rgj]
        shl  bx,cl
        add  ax,bx
        sub  ax,[camz]
        mov  [wdz2],ax
        call WCAM2              ; cldu = right of the nose, cldd = ahead
        mov  cl,[rzsh]
        mov  ax,[cldu]
        sar  ax,cl
        cmp  ax,14
        jg   @@gn
        cmp  ax,-14
        jl   @@gn
        mov  bx,[cldd]
        sar  bx,cl
        cmp  bx,14
        jg   @@gn
        cmp  bx,-14
        jl   @@gn
        add  ax,87
        push ax
        mov  ax,171
        sub  ax,bx
        call ROWAD
        mov  di,ax
        pop  ax
        add  di,ax
        mov  al,30              ; quiet trim grey
        mov  es:[di],al
@@gn:   inc  word ptr [rgj]
        cmp  word ptr [rgj],5
        jl   @@gz
        inc  word ptr [rgk]
        cmp  word ptr [rgk],5
        jl   @@gx
        ; -- the north anchor: two brighter dots up the N radius --
        mov  si,13
        call RNDOT
        mov  si,10
        call RNDOT
        ret
RNDOT:  mov  ax,[hsin]          ; one wall-grey dot SI px north
        neg  ax
        imul si
        mov  cx,256
        idiv cx
        add  ax,87
        push ax
        mov  ax,[hcos]
        imul si
        mov  cx,256
        idiv cx
        mov  bx,ax
        mov  ax,171
        sub  ax,bx
        call ROWAD
        mov  di,ax
        pop  ax
        add  di,ax
        mov  al,0
        mov  es:[di],al
        ret

; ---- RSLOT: pid in AX -> remote index in DI (alloc), -1 if full ------------
RSLOT:  push si
        xor  si,si
@@f:    mov  di,si
        add  di,di
        cmp  [rpid+di],ax
        je   @@got
        inc  si
        cmp  si,NRMT
        jb   @@f
        xor  si,si              ; not seen before: first free bunk
@@a:    mov  di,si
        add  di,di
        cmp  word ptr [rpid+di],0
        je   @@new
        inc  si
        cmp  si,NRMT
        jb   @@a
        mov  di,-1              ; the sky is full
        pop  si
        ret
@@new:  mov  [rpid+di],ax
@@got:  mov  di,si
        pop  si
        ret

; ---- THE WINDOW GUARD (sky + net together) ---------------------------------
; SKYSEG lives at CS+1000h with UISEG at CS+1200h right behind: 8K,
; not a byte more. The build refuses to overflow instead of letting
; the neighbour eat the cloud tables (postmortem 2026-07-23) - and
; the ORG pad below CLAIMS the full window, so the linker parks
; UISEG exactly at CS+1200h.
IF ($-BNOISE) GT 8176
        %OUT *** SKYSEG overflows its 8K window before UISEG ***
        .ERR
ENDIF
        ORG  1FF0h
        db   16 dup(?)

SKYSEG  ENDS
