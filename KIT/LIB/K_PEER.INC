; ============================================================================
;  K_PEER.INC - KIT: the player table every network game needs. Who is in
;  the room, when each was last heard, which colour each wears, who hosts,
;  when to send our own heartbeat.
;
;  The transport is ENGINE\E_NET.INC (NETOPEN NETPID NETSEND NETRECV
;  NETCLOSE); this file never touches the wire, it only keeps the books:
;        call NETRECV            ; CF=0: AX = who sent it, DI -> NETIN
;        call PEER_HEARD         ; BX -> his slot (a new one taken), CF full
;        mov  ax,[di+2]          ; ...copy what you need into the slot,
;        mov  [bx+MY_X],ax       ;    clamped (K_NETX NTX_CLAMP)
;  and once a frame PEER_TIMEOUT (who has gone), PEER_HOST (who keeps the
;  shared world), PEER_BEAT (send our state now?).
;
;  THE INCLUDER MAY DEFINE, before the include (defaults in brackets):
;    PEER_MAX    slots for OTHER players (8). We are not in the table: our
;                own name is the variable peer_me.
;    PEER_USER   bytes of the program's own in each slot (0) - where it
;                keeps a player's x, y, look... at PEER_U+0, PEER_U+1...
;    PEER_GONE   ticks unheard before a player has gone (55, 3 s)
;    PEER_EVERY  ticks between heartbeats when nothing changed (9, 2 a s)
;
;  A SLOT (BX -> it; peer_tab .. peer_end, PEER_SIZE bytes each):
;    PEER_PID    word: his name on the wire (NETRECV's AX), 0 = slot free
;    PEER_TICK   word: the BIOS tick he was last heard
;    PEER_CI     byte: his colour index 0..7 (PEER_COLOR of his name)
;    PEER_MARK   byte: the program's own flag, 0 when the slot is taken
;    PEER_U      the program's PEER_USER bytes, 0 when the slot is taken
;  Walk them:   mov bx,peer_tab / .l: cmp word [bx+PEER_PID],0 / ... /
;               add bx,PEER_SIZE / cmp bx,peer_end / jb .l
;
;  VARIABLES: peer_me (word) - our own name: write it when the wire names
;  us (K_NETX NTX_WAITNAME, or E_NET NETPID not 0); 0 = not named / alone.
;
;  Tick arithmetic is the low word of 0040:006Ch, differences taken mod
;  65536: wraps cleanly. At midnight the BIOS resets the tick - every slot
;  then looks old for one frame, drops, and comes back with the next beat.
;  Include it after the program's way out (it is code and data).
; ============================================================================

if ~ defined PEER_MAX | defined peer_maxdef
peer_maxdef = 1
PEER_MAX = 8
end if
if ~ defined PEER_USER | defined peer_userdef
peer_userdef = 1
PEER_USER = 0
end if
if ~ defined PEER_GONE | defined peer_gonedef
peer_gonedef = 1
PEER_GONE = 55
end if
if ~ defined PEER_EVERY | defined peer_everydef
peer_everydef = 1
PEER_EVERY = 9
end if

PEER_PID   = 0
PEER_TICK  = 2
PEER_CI    = 4
PEER_MARK  = 5
PEER_U     = 6
PEER_SIZE  = PEER_U + ((PEER_USER + 1) and 0FFFEh) ; kept even: words align

; ----------------------------------------------------------------------
;@ PEER_INIT  empty the player table; we are not named yet
;  in:  -
;  out: - (peer_me = 0; the next PEER_BEAT once named sends at once)
;  needs: -
;  from: EXAMPLES\NETSQ.ASM:41-50 (slots cleared)
; ----------------------------------------------------------------------
if used PEER_INIT
PEER_INIT:
        push bx
        push cx
        mov  bx,peer_tab
        mov  cx,PEER_MAX*PEER_SIZE ; every byte of every slot
.z:     mov  byte [bx],0        ; DS-relative: ES may be the screen
        inc  bx                 ; the next byte
        loop .z
        mov  word [peer_me],0
        mov  word [peer_sent],0
        mov  byte [peer_dirty],1
        pop  cx
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ PEER_HEARD a packet came from AX: find his slot or take a free one
;  in:  AX = the sender's name (NETRECV's AX). DI (the packet) is not read.
;  out: BX -> his slot, its PEER_TICK stamped now; AX = 1 a slot just
;       taken (zeroed: set its PEER_U fields), 0 he was known.
;       CF = 1: the table is full, or AX was 0 or our own name - ignore.
;  needs: PEER_INIT once
;  from: EXAMPLES\NETSQ.ASM:163-195 (heard); MULTSOK2.ASM:1128-1180 SLOTOF
; ----------------------------------------------------------------------
if used PEER_HEARD
PEER_HEARD:
        push cx
        push dx
        push si
        or   ax,ax
        jz   .no                ; 0 names nobody
        cmp  ax,[peer_me]
        je   .no                ; our own echo is not a player
        mov  dx,ax              ; DX = his name
        call PEER_FIND          ; BX -> his slot if he is known
        jnc  .known
        mov  bx,peer_tab        ; a newcomer: the first free slot
.f:     cmp  word [bx+PEER_PID],0
        je   .take
        add  bx,PEER_SIZE       ; the next slot
        cmp  bx,peer_end
        jb   .f
.no:    stc                     ; full: the room is bigger than the table
        jmp  .out
.take:  mov  si,bx
        mov  cx,PEER_SIZE       ; the slot zeroed, byte by byte
.z:     mov  byte [si],0
        inc  si                 ; the next byte
        loop .z
        mov  [bx+PEER_PID],dx
        mov  ax,dx
        call PEER_COLOR         ; AX = 0..7
        mov  [bx+PEER_CI],al
        mov  dx,1               ; "new"
        jmp  .stamp
.known: xor  dx,dx              ; "known"
.stamp: call peer_now
        mov  [bx+PEER_TICK],ax
        mov  ax,dx
        clc
.out:   pop  si                 ; (POP keeps the flags)
        pop  dx
        pop  cx
        ret
end if

; ----------------------------------------------------------------------
;@ PEER_FIND  the slot of player AX
;  in:  AX = his name
;  out: BX -> his slot; CF = 1 not in the table (AX = 0 is never found)
;  needs: PEER_INIT once
;  from: EXAMPLES\NETSQ.ASM:166-172
; ----------------------------------------------------------------------
if used PEER_FIND
PEER_FIND:
        or   ax,ax
        jz   .no                ; 0 marks a free slot, not a player
        mov  bx,peer_tab
.l:     cmp  [bx+PEER_PID],ax
        je   .yes
        add  bx,PEER_SIZE       ; the next slot
        cmp  bx,peer_end
        jb   .l
.no:    stc
        ret
.yes:   clc
        ret
end if

; ----------------------------------------------------------------------
;@ PEER_DROP  free slot BX (he left, or the game threw him out)
;  in:  BX -> the slot
;  out: - (its PEER_U bytes stay as they were: erase his picture from them)
;  needs: -
;  from: MULTSOK2.ASM:1188-1192 DROPMAN
; ----------------------------------------------------------------------
if used PEER_DROP
PEER_DROP:
        mov  word [bx+PEER_PID],0
        ret
end if

; ----------------------------------------------------------------------
;@ PEER_TIMEOUT free a slot not heard for PEER_GONE ticks - call until CF
;  in:  - (once a frame:  .t: call PEER_TIMEOUT / jc .done / erase him / jmp .t)
;  out: CF = 0: BX -> a slot just freed (PEER_PID 0 now, its PEER_U as last
;       heard - for erasing him); CF = 1: nobody more has gone (BX lost)
;  needs: PEER_INIT once
;  from: EXAMPLES\NETSQ.ASM:139-152
; ----------------------------------------------------------------------
if used PEER_TIMEOUT
PEER_TIMEOUT:
        push ax
        push cx
        call peer_now
        mov  cx,ax              ; CX = now
        mov  bx,peer_tab
.l:     cmp  word [bx+PEER_PID],0
        je   .n
        mov  ax,cx
        sub  ax,[bx+PEER_TICK] ; ticks since we heard him
        cmp  ax,PEER_GONE
        jb   .n
        mov  word [bx+PEER_PID],0 ; gone: that is how leaving looks
        clc
        jmp  .out
.n:     add  bx,PEER_SIZE       ; the next slot
        cmp  bx,peer_end
        jb   .l
        stc
.out:   pop  cx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ PEER_COUNT players in the table (us not counted)
;  in:  -
;  out: AX = slots in use, 0..PEER_MAX
;  needs: PEER_INIT once
;  from: new
; ----------------------------------------------------------------------
if used PEER_COUNT
PEER_COUNT:
        push bx
        xor  ax,ax
        mov  bx,peer_tab
.l:     cmp  word [bx+PEER_PID],0
        je   .n
        inc  ax                 ; one more in
.n:     add  bx,PEER_SIZE       ; the next slot
        cmp  bx,peer_end
        jb   .l
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ PEER_HOST  who keeps the shared world: the lowest name heard lately
;  in:  DX = a name to leave out (the host that went quiet), 0 = none
;  out: AX = the host's name: the LOWEST of peer_me and every slot heard
;       within PEER_GONE ticks (except DX). ZF = 1: it is us - we host.
;       Not named yet (peer_me = 0): AX = 0, ZF = 1 (alone, our own host).
;       Two hosts that hear each other both get the lower: they merge.
;  needs: PEER_INIT; peer_me set when named
;  from: docs\guide\MULTI.MD "A world they share"; MULTSOK2.ASM:2761-2779
;        NEXTHOST; OWLFLY3\SRC\WAR.INC:10-16
; ----------------------------------------------------------------------
if used PEER_HOST
PEER_HOST:
        push bx
        push cx
        push si
        mov  si,[peer_me]       ; the lowest so far: ours
        or   si,si
        jz   .done              ; not named: alone
        call peer_now
        mov  cx,ax              ; CX = now
        mov  bx,peer_tab
.l:     mov  ax,[bx+PEER_PID]
        or   ax,ax
        jz   .n                 ; a free slot
        cmp  ax,dx
        je   .n                 ; the one left out
        push cx
        sub  cx,[bx+PEER_TICK] ; ticks since we heard him
        cmp  cx,PEER_GONE
        pop  cx                 ; (POP keeps the flags)
        jae  .n                 ; not heard lately
        cmp  ax,si
        jae  .n
        mov  si,ax              ; lower: the host so far
.n:     add  bx,PEER_SIZE       ; the next slot
        cmp  bx,peer_end
        jb   .l
.done:  mov  ax,si
        cmp  ax,[peer_me]       ; ZF = 1: it is us
        pop  si
        pop  cx
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ PEER_COLOR a colour/start index 0..7 from a name, the same on every machine
;  in:  AX = the name
;  out: AX = 0..7 - both bytes used: on the site's relay the LOW byte is
;       86h for everyone and the high byte numbers the players (0186h,
;       0286h, 0386h give 7, 4, 5). Add 8 for a colour that shows on black.
;  needs: -
;  from: EXAMPLES\NETSQ.ASM:65-70; docs\guide\MULTI.MD "The packet"
; ----------------------------------------------------------------------
if used PEER_COLOR
PEER_COLOR:
        xor  al,ah              ; both bytes of the name
        and  ax,7               ; 0..7, AH = 0
        ret
end if

; ----------------------------------------------------------------------
;@ PEER_BEAT  send our state now? on a change at once, else every PEER_EVERY
;  in:  AL = 1: our state changed since the last send, 0: it did not
;  out: CF = 0: send it now (the send is counted as done); CF = 1: not now -
;       not named yet (peer_me = 0), or already sent this tick (a change
;       is kept and goes on the next tick), or the beat not due
;  needs: PEER_INIT; peer_me set when named
;  from: EXAMPLES\NETSQ.ASM:119-128; docs\guide\MULTI.MD (one send a tick)
; ----------------------------------------------------------------------
if used PEER_BEAT
PEER_BEAT:
        push ax
        push bx
        or   al,al
        jz   .c
        mov  byte [peer_dirty],1 ; kept until it is sent
.c:     cmp  word [peer_me],0
        je   .no                ; unnamed: our echo would read as a stranger
        call peer_now
        cmp  ax,[peer_sent]
        je   .no                ; one send a tick at most
        cmp  byte [peer_dirty],0
        jne  .yes
        mov  bx,ax
        sub  bx,[peer_sent]     ; ticks since the last send
        cmp  bx,PEER_EVERY
        jb   .no
.yes:   mov  [peer_sent],ax
        mov  byte [peer_dirty],0
        clc
        jmp  .out
.no:    stc
.out:   pop  bx
        pop  ax
        ret
end if

; peer_now - AX = the BIOS tick's low word (inner: keeps everything else)
if used PEER_HEARD | used PEER_TIMEOUT | used PEER_HOST | used PEER_BEAT
peer_now:
        push ds
        xor  ax,ax
        mov  ds,ax
        mov  ax,[046Ch]         ; 0000:046C = 0040:006C
        pop  ds
        ret
end if

peer_me    dw 0                 ; our name, 0 = not named / alone
peer_sent  dw 0                 ; the tick of our last send (PEER_BEAT)
peer_dirty db 1                 ; a change not sent yet
           db 0                 ; (the table on a word)
peer_tab   db PEER_MAX*PEER_SIZE dup(0)
peer_end:
