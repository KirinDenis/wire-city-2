; ============================================================================
;  K_NETX.INC - KIT: the helpers every game writes around ENGINE\E_NET.INC.
;  Waiting for our name without stopping the game, sending state on a
;  change or a heartbeat, draining the listens through a handler, clamping
;  what came off the wire, making a name printable, and the join: wait for
;  the address, listen for a host, else host - or play alone.
;
;  E_NET stays the transport (NETOPEN NETPID NETSEND NETRECV NETCLOSE, its
;  net_ok and NETIN); include it too - this file calls it, never copies it:
;        include '..\..\ENGINE\E_NET.INC'
;        include '..\..\KIT\LIB\K_NETX.INC'
;  NETSOCK and NETLEN are defined for E_NET before both (docs\guide\MULTI.MD).
;
;  THE INCLUDER MAY DEFINE, before the include (defaults in brackets):
;    NTX_EVERY   ticks between heartbeats when nothing changed (9, 2 a s)
;    NTX_WIREWT  ticks NTX_JOIN waits for our address (270, 15 s)
;    NTX_JOINT   ticks NTX_JOIN listens for a host's world (36, 2 s)
;    NTX_DRMAX   packets one NTX_DRAIN takes at most (32: a frame never
;                waits on the wire)
;  VARIABLES: ntx_pid (word) - our name once NTX_WAITNAME/NTX_JOIN had it.
;  NTX_JOIN's answers: NTX_ALONE 0, NTX_HOST 1, NTX_CLIENT 2, NTX_QUIT 3.
; ============================================================================

if ~ defined NTX_EVERY | defined ntx_everydef
ntx_everydef = 1
NTX_EVERY = 9
end if
if ~ defined NTX_WIREWT | defined ntx_wirewtdef
ntx_wirewtdef = 1
NTX_WIREWT = 270
end if
if ~ defined NTX_JOINT | defined ntx_jointdef
ntx_jointdef = 1
NTX_JOINT = 36
end if
if ~ defined NTX_DRMAX | defined ntx_drmaxdef
ntx_drmaxdef = 1
NTX_DRMAX = 32
end if
NTX_ALONE  = 0
NTX_HOST   = 1
NTX_CLIENT = 2
NTX_QUIT   = 3

; ----------------------------------------------------------------------
;@ NTX_WAITNAME ask the wire for our name, once a frame, never waiting
;  in:  - (call every frame until ZF = 0; with no IPX it stays ZF = 1)
;  out: AX = our name, kept in ntx_pid; ZF = 1: not named yet (AX = 0) -
;       send nothing yet: our own echo cannot be told from a stranger's
;  needs: E_NET's NETOPEN first
;  from: EXAMPLES\NETSQ.ASM:59-64; docs\guide\NET.MD "The address arrives late"
; ----------------------------------------------------------------------
if used NTX_WAITNAME
NTX_WAITNAME:
        mov  ax,[ntx_pid]
        or   ax,ax
        jnz  .done              ; named already: ZF = 0
        push bx
        push cx
        push dx
        push si
        push di
        call NETPID             ; AX = the name, 0 while the address is away
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        mov  [ntx_pid],ax
        or   ax,ax              ; ZF = 1: not yet
.done:  ret
end if

; ----------------------------------------------------------------------
;@ NTX_SENDST send our whole state on a change, or on the heartbeat
;  in:  SI -> NETLEN bytes (the state packet); AL = 1 it changed, 0 not
;  out: CF = 0 sent; CF = 1 not now - not named (ntx_pid 0), already sent
;       this tick (a change waits for the next tick, it is not lost), the
;       beat not due, or the wire dropped it (then it goes again next tick)
;  needs: NTX_WAITNAME (it sets ntx_pid); E_NET
;  from: EXAMPLES\NETSQ.ASM:119-137; MULTSOK2.ASM:2702-2711 (one a tick)
; ----------------------------------------------------------------------
if used NTX_SENDST
NTX_SENDST:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        or   al,al
        jz   .c
        mov  byte [ntx_dirty],1 ; kept until it goes
.c:     cmp  word [ntx_pid],0
        je   .no
        call ntx_now
        cmp  ax,[ntx_sent]
        je   .no                ; one send a tick at most
        cmp  byte [ntx_dirty],0
        jne  .go
        mov  bx,ax
        sub  bx,[ntx_sent]      ; ticks since the last send
        cmp  bx,NTX_EVERY
        jb   .no
.go:    mov  [ntx_sent],ax
        mov  byte [ntx_dirty],0
        call NETSEND            ; SI -> the state
        jnc  .out
        mov  byte [ntx_dirty],1 ; dropped: again on the next tick
.no:    stc
.out:   pop  di                 ; (POP keeps the flags)
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ NTX_DRAIN  every packet that came, through a handler of yours
;  in:  BX = the handler. It is called with AX = the sender's name and
;       DI -> NETIN (NETLEN bytes), once a packet; it may change any
;       register but SP and the segment registers.
;  out: AX = packets handled (at most NTX_DRMAX; the rest wait a frame)
;  needs: E_NET's NETOPEN (with no IPX: AX = 0 at once)
;  from: EXAMPLES\NETSQ.ASM:114-117; MULTSOK2.ASM:2618-2622
; ----------------------------------------------------------------------
if used NTX_DRAIN
NTX_DRAIN:
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        mov  [ntx_hnd],bx
        mov  word [ntx_cnt],0
.l:     cmp  word [ntx_cnt],NTX_DRMAX
        jae  .done              ; enough for one frame
        call NETRECV            ; CF=0: AX = who, DI -> NETIN
        jc   .done
        inc  word [ntx_cnt]     ; one more handled
        call word [ntx_hnd]
        jmp  .l
.done:  mov  ax,[ntx_cnt]
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ NTX_CLAMP  a signed word off the wire into BX..DX
;  in:  AX = the value (a packet is someone else's word), BX = the lowest,
;       DX = the highest allowed (signed, BX <= DX)
;  out: AX within BX..DX; CF = 1 it was outside (clamped - or drop the packet)
;  needs: -
;  from: EXAMPLES\NETSQ.ASM:181-190; MULTSOK2.ASM:2961-2966 (mine clock)
; ----------------------------------------------------------------------
if used NTX_CLAMP
NTX_CLAMP:
        cmp  ax,bx
        jge  .lo
        mov  ax,bx              ; below: the lowest
        stc
        ret
.lo:    cmp  ax,dx
        jle  .ok
        mov  ax,dx              ; above: the highest
        stc
        ret
.ok:    clc
        ret
end if

; ----------------------------------------------------------------------
;@ NTX_CLAMPU an unsigned word (or a byte with AH = 0) into BX..DX
;  in:  AX = the value, BX = the lowest, DX = the highest (unsigned)
;  out: AX within BX..DX; CF = 1 it was outside
;  needs: -
;  from: MULTSOK2.ASM:2862-2875 (clocks and slots kept in range)
; ----------------------------------------------------------------------
if used NTX_CLAMPU
NTX_CLAMPU:
        cmp  ax,bx
        jae  .lo
        mov  ax,bx              ; below: the lowest
        stc
        ret
.lo:    cmp  ax,dx
        jbe  .ok
        mov  ax,dx              ; above: the highest
        stc
        ret
.ok:    clc
        ret
end if

; ----------------------------------------------------------------------
;@ NTX_NAME   8 letters off the wire made printable: 32..126 kept, else '?'
;  in:  SI -> 8 bytes (a name from a packet), DI -> 8 bytes for it (SI = DI
;       allowed: in place). Both in DS.
;  out: - (zeros after the first zero, so a short name stays short)
;  needs: -
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:3112-3127 COPYNAME
; ----------------------------------------------------------------------
if used NTX_NAME
NTX_NAME:
        push ax
        push cx
        push si
        push di
        mov  cx,8
.c:     mov  al,[si]
        inc  si                 ; the next letter in
        or   al,al
        jz   .pad
        cmp  al,32
        jb   .q
        cmp  al,126
        jbe  .put
.q:     mov  al,'?'             ; a control code or a high byte
.put:   mov  [di],al            ; DS-relative: ES may be the screen
        inc  di                 ; the next letter out
        loop .c
        jmp  .out
.pad:   mov  [di],al            ; AL = 0: the rest of the name
        inc  di                 ; the next place
        loop .pad
.out:   pop  di
        pop  si
        pop  cx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ NTX_JOIN   into the room's game: wait for our name, listen for a host, else host
;  in:  AL = the kind letter (payload byte 0) of the host's world packet;
;       AH = the protocol byte it carries at +1 (0: not checked);
;       BX = a status routine of yours, or 0: called once a tick with
;       AL = 0 waiting for our address / 1 listening for a host, CX = ticks
;       left; it may change any register but SP and the segment registers
;       (it draws "waiting..." - it must MOVE, NET.MD).
;       Enter while it waits: alone. Esc: NTX_QUIT (you quit).
;  out: AL = NTX_ALONE 0 (no IPX, no name in NTX_WIREWT ticks, Enter),
;       NTX_HOST 1 (nobody answered in NTX_JOINT ticks: we host),
;       NTX_CLIENT 2 (a host's world came), NTX_QUIT 3 (Esc); AH = 0.
;       DX = the host's name (ours when we host; 0 alone/quit).
;       DI -> NETIN = that world packet (NTX_CLIENT only): apply it now.
;       ntx_pid = our name (0 alone). Other packets heard meanwhile are
;       dropped: state is sent again on the beat.
;  needs: E_NET's NETOPEN first (with no IPX it returns NTX_ALONE at once)
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:737-790 JOIN/JKEY; OWLFLY3\SRC\UI.INC:793-870
; ----------------------------------------------------------------------
if used NTX_JOIN
NTX_JOIN:
        push bx
        push cx
        push si
        push bp
        mov  [ntx_jkind],ax     ; the kind and the protocol
        mov  [ntx_jstat],bx
        cmp  byte [net_ok],0
        je   .alone             ; no IPX card here
        call ntx_now
        mov  [ntx_jt0],ax       ; the waits count from here
        mov  word [ntx_jtk],0FFFFh
.addr:  call NTX_WAITNAME       ; ZF = 1: not named yet
        jnz  .named
        mov  al,0               ; stage 0: the address
        mov  cx,NTX_WIREWT
        call ntx_jpass          ; AL = 0 go on, 1 time up, 2 Enter, 3 Esc
        or   al,al
        jz   .addr
        cmp  al,3
        je   .quit
        jmp  .alone             ; no name in time, or Enter: alone
.named: call ntx_now
        mov  [ntx_jt0],ax       ; listening counts from now
        mov  word [ntx_jtk],0FFFFh
.look:  call NETRECV            ; CF=0: AX = who, DI -> NETIN
        jc   .pass
        mov  bl,byte [ntx_jkind]
        cmp  [di],bl
        jne  .look              ; not a world: dropped
        mov  bl,byte [ntx_jkind+1]
        or   bl,bl
        jz   .host1
        cmp  [di+1],bl
        jne  .look              ; another version of the game: not ours
.host1: mov  dx,ax              ; DX = the host's name
        mov  al,NTX_CLIENT
        jmp  .out
.pass:  mov  al,1               ; stage 1: listening
        mov  cx,NTX_JOINT
        call ntx_jpass
        or   al,al
        jz   .look
        cmp  al,1
        je   .ours
        cmp  al,3
        je   .quit
.alone: xor  dx,dx              ; alone: no name on the wire
        mov  [ntx_pid],dx
        mov  al,NTX_ALONE
        jmp  .out
.ours:  mov  dx,[ntx_pid]       ; nobody: our own game, we host it
        mov  al,NTX_HOST
        jmp  .out
.quit:  xor  dx,dx
        mov  al,NTX_QUIT
.out:   xor  ah,ah
        pop  bp
        pop  si
        pop  cx
        pop  bx
        ret

; ntx_jpass - one pass of a join wait: AL = the stage, CX = its limit in
; ticks. Yields, reads a key, shows the status once a tick.
; AL out: 0 go on, 1 time up, 2 Enter, 3 Esc. Keeps DI.
ntx_jpass:
        push di
        mov  [ntx_jsg],al
        mov  [ntx_jlim],cx
        mov  ax,1680h           ; the time slice back: in the browser a loop
        int  2Fh                ;  that never yields starves the emulator
        mov  ah,1               ; a key?
        int  16h
        jz   .clock
        xor  ah,ah
        int  16h
        cmp  al,27
        je   .esc
        cmp  al,13
        je   .ent
.clock: call ntx_now
        mov  bx,ax
        sub  bx,[ntx_jt0]       ; ticks waited
        cmp  bx,[ntx_jlim]
        jae  .up
        cmp  ax,[ntx_jtk]
        je   .go                ; shown this tick already
        mov  [ntx_jtk],ax
        cmp  word [ntx_jstat],0
        je   .go
        mov  cx,[ntx_jlim]
        sub  cx,bx              ; ticks left (BX < the limit: above 0)
        mov  al,[ntx_jsg]
        push bp
        call word [ntx_jstat]   ; the caller's caption, moving
        pop  bp
.go:    xor  al,al
        jmp  .ret
.up:    mov  al,1
        jmp  .ret
.ent:   mov  al,2
        jmp  .ret
.esc:   mov  al,3
.ret:   pop  di
        ret
end if

; ntx_now - AX = the BIOS tick's low word (inner: keeps everything else)
if used NTX_SENDST | used NTX_JOIN
ntx_now:
        push ds
        xor  ax,ax
        mov  ds,ax
        mov  ax,[046Ch]         ; 0000:046C = 0040:006C
        pop  ds
        ret
end if

ntx_pid   dw 0                  ; our name, 0 = not named / alone
ntx_sent  dw 0                  ; the tick of our last send
ntx_hnd   dw 0                  ; NTX_DRAIN's handler
ntx_cnt   dw 0                  ;  and its count
ntx_jkind dw 0                  ; NTX_JOIN: the world's kind, protocol
ntx_jstat dw 0                  ;  the status routine
ntx_jt0   dw 0                  ;  the wait's start
ntx_jtk   dw 0                  ;  the tick last shown
ntx_jlim  dw 0                  ;  this stage's limit
ntx_jsg   db 0                  ;  this stage
ntx_dirty db 1                  ; a change not sent yet
