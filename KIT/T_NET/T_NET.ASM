; ============================================================================
;@ T_NET      network game skeleton: a square each, colours per player, heartbeat, timeout, HOST shown
;  T_NET.ASM - KIT template: a network game's skeleton. A square each:
;  every player moves his own with the arrows, every machine in the room
;  draws them all, each in a colour of his own (the same on every screen).
;  The lowest name heard keeps the shared world - here it only wears the
;  word HOST, top right; give it a ball or a score to keep. Esc quits.
;  NETSQ (EXAMPLES\NETSQ.ASM) reworked on the kit: K_PEER keeps the table,
;  K_NETX waits for the name, sends, drains and clamps; E_NET is the wire.
;
;  ON THE WIRE CITY SITE:
;      build A:\KIT\T_NET\T_NET.ASM --net=ROOM
;  and the second player - another browser window, or a friend with this
;  folder on his A: - must give the SAME ROOM:
;      build A:\KIT\T_NET\T_NET.ASM --net=ROOM
;  THE TRAP: without =ROOM the room is the folder's name, so a copy in
;  A:\MY\SQ meets only other copies in a folder called SQ. Name the room
;  each time, the same on both sides. Put the two windows side by side: a
;  hidden tab's DOS PC nearly stops (docs\guide\MULTI.MD).
;
;  COPY IT: A:\MY\NAME\NAME.ASM - the include paths hold from there. Change
;  NETSOCK (a palindrome of your own) and PROTO, grow the packet at its end.
;
;  The packet, NETLEN = 6 bytes: +0 'Q', +1 PROTO, +2 x, +4 y (words) -
;  the whole state each time (state, not events): sent on a move and twice
;  a second anyway, so a newcomer sees everyone at once. A square unheard
;  for 3 s is gone. Nothing is sent before the wire names us.
;  No IPX (or no address): it says so on the top line and plays alone.
;  LETTERS: K_FONT's, straight on the screen (no back buffer here): the
;  title card is R_TITLE's TTLCARD (redrawn only as PRESS ENTER blinks),
;  the top band's words and HOST are 8x8 ringed (cleared, then written,
;  only when they change).
;  /AUTO (the kit's test run): the title 12 ticks, then moves by itself for 2 s, quits, and says on
;  DOS's output how it went.
; ============================================================================
NETSOCK   = 4E4Eh               ; the socket: a palindrome, never 5757h/5858h
NETLEN    = 6                   ; 'Q', PROTO, x, y
PROTO     = 1                   ; another version of the game is not ours
PEER_MAX  = 8                   ; other players at once
PEER_USER = 8                   ; in each slot: x, y, and where it is drawn
U_X       = PEER_U              ; his square: x...
U_Y       = PEER_U+2            ;  ...y
U_DX      = PEER_U+4            ; where it is drawn now (0FFFFh: nowhere)
U_DY      = PEER_U+6
SIDE      = 12                  ; a square's side, in pixels
STEP      = 4                   ; pixels an arrow moves it
TOP       = 16                  ; the top two text rows stay for words
AUTOT     = 36                  ; /AUTO: ticks before it quits (2 s)

        org  100h
        include '..\..\ENGINE\E_8086.INC'

start:  call isauto             ; /AUTO on the command line?
        jne  .a
        mov  byte [auto],1
.a:     mov  ax,13h             ; VGA 320x200, 256 colours
        int  10h
        call TITLE              ; the title card until Enter (Esc: DOS)
        jnc  .go
        mov  ax,3
        int  10h
        mov  ax,4C00h
        int  21h
.go:    call PEER_INIT
        mov  word [myx],154     ; ours, in the middle, white until named
        mov  word [myy],94
        mov  byte [mycol],15
        mov  word [mydx],0FFFFh
        call now
        mov  [t0],ax
        mov  [lastt],ax
        call NETOPEN            ; CF: no IPX - alone, still a square
        mov  si,twait
        jnc  .net
        mov  byte [solo],1
        mov  si,tsolo
.net:   call status

main:   mov  ax,1680h           ; give the time slice back: in the browser a
        int  2Fh                ;  loop that never yields starves the emulator
        cmp  byte [solo],0
        jne  .keys
        cmp  word [peer_me],0
        jne  .keys
        call NTX_WAITNAME       ; ZF: not named yet - ask every frame
        jz   .keys
        mov  [peer_me],ax       ; named: our colour and place, from the name
        call PEER_COLOR         ; AX = 0..7, the same on every machine
        mov  bx,ax
        add  al,8               ; 8..15: every one shows on black
        mov  [mycol],al
        mov  cl,5
        shl  bx,cl              ; 32 pixels apart, from x 32 - or every
        add  bx,32              ;  square starts on every other one
        mov  [myx],bx
        mov  byte [moved],1
        mov  si,tnamed
        call status
.keys:  cmp  byte [auto],0
        je   .key
        call now                ; /AUTO: a step a tick, back and forth
        cmp  ax,[lastt]
        je   .rx
        mov  [lastt],ax
        sub  ax,[t0]            ; ticks since the start
        cmp  ax,AUTOT
        jae  quit
        mov  bx,[myx]
        add  bx,[adir]          ; a step along
        cmp  bx,320-SIDE
        jbe  .ab
        neg  word [adir]        ; the edge: back
        jmp  .rx
.ab:    mov  [myx],bx
        mov  byte [moved],1
        jmp  .rx
.key:   mov  ah,1               ; a key?
        int  16h
        jz   .rx
        xor  ah,ah
        int  16h
        cmp  ah,1               ; Esc
        je   quit
        mov  bx,[myx]
        mov  dx,[myy]
        cmp  ah,4Bh             ; Left
        jne  .k1
        sub  bx,STEP            ; four pixels left
.k1:    cmp  ah,4Dh             ; Right
        jne  .k2
        add  bx,STEP            ; four pixels right
.k2:    cmp  ah,48h             ; Up
        jne  .k3
        sub  dx,STEP            ; four pixels up
.k3:    cmp  ah,50h             ; Down
        jne  .k4
        add  dx,STEP            ; four pixels down
.k4:    mov  ax,bx              ; kept on the screen (signed: left of 0 is
        mov  bx,0               ;  negative)
        push dx
        mov  dx,320-SIDE
        call NTX_CLAMP
        pop  dx
        mov  [myx],ax
        mov  ax,dx
        mov  bx,TOP
        mov  dx,200-SIDE
        call NTX_CLAMP
        mov  [myy],ax
        mov  byte [moved],1

.rx:    mov  bx,took            ; everything that came, through took
        call NTX_DRAIN

        mov  byte [pkt],'Q'     ; our state, whole
        mov  byte [pkt+1],PROTO
        mov  ax,[myx]
        mov  [pkt+2],ax
        mov  ax,[myy]
        mov  [pkt+4],ax
        mov  si,pkt
        mov  al,[moved]         ; on a move at once, else on the heartbeat
        call NTX_SENDST         ;  (nothing while unnamed)
        mov  byte [moved],0     ; a change not sent yet waits inside

.old:   call PEER_TIMEOUT       ; who has gone quiet: off the screen
        jc   .host
        cmp  word [bx+U_DX],0FFFFh
        je   .old
        mov  ax,[bx+U_DX]
        mov  bx,[bx+U_DY]
        xor  cl,cl              ; in black
        call square
        jmp  .old

.host:  xor  dx,dx              ; who keeps the world? ZF: we do
        call PEER_HOST
        mov  al,0
        jnz  .h1
        mov  al,1
.h1:    cmp  al,[ishost]
        je   .draw
        mov  [ishost],al
        mov  si,tnohost
        or   al,al
        jz   .h2
        mov  si,thost
.h2:    push es
        mov  ax,0A000h
        mov  es,ax              ; (this game draws on the screen itself)
        mov  bx,260             ; the band's right part black...
        mov  cx,60
        call band
        mov  al,FNT_LBODY       ; ...and the word in K_FONT's 8x8, yellow,
        call FNT_LOOK           ;  ringed black
        mov  byte [fnt_style],FNT_RING
        mov  byte [fnt_col],14
        mov  bx,315             ; ending at x 315
        mov  dx,4
        call FNT_RIGHT
        pop  es

.draw:  call draw
        jmp  main

quit:   call PEER_COUNT
        mov  [heard],al
        call NETCLOSE           ; the socket back, then text mode 3
        mov  ax,3
        int  10h
        cmp  byte [auto],0
        je   .x
        mov  dx,dsolo           ; /AUTO: how it went, on DOS's output
        cmp  byte [solo],0
        jne  .say
        mov  dx,dnoname
        cmp  word [peer_me],0
        je   .say
        mov  dx,dnamed
.say:   mov  ah,9
        int  21h
        mov  al,[heard]
        add  al,'0'             ; 0..8 others heard, as a digit
        mov  [dheard+15],al
        mov  dx,dheard
        mov  ah,9
        int  21h
.x:     mov  ax,4C00h
        int  21h

; ---- took: AX = who, DI -> his packet (NTX_DRAIN's handler) ----------------
took:   cmp  byte [di],'Q'
        jne  .r                 ; not ours
        cmp  byte [di+1],PROTO
        jne  .r                 ; another version
        call PEER_HEARD         ; BX -> his slot, AX = 1 new; CF full
        jc   .r                 ; the room is fuller than the table
        or   ax,ax
        jz   .old
        mov  word [bx+U_DX],0FFFFh ; new: drawn nowhere yet
.old:   mov  si,bx
        mov  ax,[di+2]          ; x, clamped: a packet is someone's word
        mov  bx,0
        mov  dx,320-SIDE
        call NTX_CLAMP
        mov  [si+U_X],ax
        mov  ax,[di+4]          ; y, the same
        mov  bx,TOP
        mov  dx,200-SIDE
        call NTX_CLAMP
        mov  [si+U_Y],ax
.r:     ret

; ---- draw: each square that moved - away from where it was, onto where it is
draw:   mov  dx,3DAh            ; wait for the vertical retrace: a square
.w1:    in   al,dx              ;  moved while the beam passes it tears
        test al,8
        jnz  .w1
.w2:    in   al,dx
        test al,8
        jz   .w2
        push es
        mov  ax,0A000h
        mov  es,ax
        mov  si,peer_tab
.d:     cmp  word [si+PEER_PID],0
        je   .dn
        mov  ax,[si+U_X]
        cmp  ax,[si+U_DX]
        jne  .mv
        mov  ax,[si+U_Y]
        cmp  ax,[si+U_DY]
        je   .dn
.mv:    mov  ax,[si+U_DX]       ; away from where it was drawn
        cmp  ax,0FFFFh
        je   .new
        mov  bx,[si+U_DY]
        xor  cl,cl              ; in black
        call square
.new:   mov  ax,[si+U_X]
        mov  [si+U_DX],ax
        mov  bx,[si+U_Y]
        mov  [si+U_DY],bx
        mov  cl,[si+PEER_CI]
        add  cl,8               ; his colour, 8..15
        call square
.dn:    add  si,PEER_SIZE       ; the next slot
        cmp  si,peer_end
        jb   .d
        mov  ax,[myx]           ; ours last, over the others
        cmp  ax,[mydx]
        jne  .me
        mov  ax,[myy]
        cmp  ax,[mydy]
        je   .mine
.me:    mov  ax,[mydx]
        cmp  ax,0FFFFh
        je   .mine
        mov  bx,[mydy]
        xor  cl,cl              ; away from where ours was
        call square
.mine:  mov  ax,[myx]
        mov  [mydx],ax
        mov  bx,[myy]
        mov  [mydy],bx
        mov  cl,[mycol]
        call square
        pop  es
        ret

; ---- square: AX = x, BX = y, CL = colour; ES = A000h. Keeps all ------------
square: push ax
        push bx
        push cx
        push dx
        push di
        push ax
        mov  ax,320
        mul  bx                 ; AX = y x 320: its first row (DX lost)
        pop  di
        add  di,ax              ; + x: its corner
        mov  al,cl
        mov  bx,SIDE            ; rows to fill
.r:     mov  cx,SIDE
        rep  stosb
        add  di,320-SIDE        ; the next row's corner
        dec  bx                 ; one row fewer
        jnz  .r
        pop  di
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; ---- status: SI -> the top line's words (0-ended): K_FONT's 8x8, ringed,
;  on the band's left part (cleared first: the words change in place)
status: push es
        mov  ax,0A000h
        mov  es,ax
        xor  bx,bx
        mov  cx,260
        call band               ; x 0..259 of the band black
        mov  al,FNT_LBODY       ; 8x8, grey, ringed black
        call FNT_LOOK
        mov  byte [fnt_style],FNT_RING
        mov  bx,4
        mov  dx,4
        call FNT_PUT            ; BX = past the words
        cmp  word [peer_me],0
        je   .r
        mov  ax,[peer_me]       ; named: our name in hex after the words,
        mov  di,thex            ;  in our colour
        push bx
        call hex4               ; (it takes BX)
        pop  bx
        mov  si,thex
        mov  al,[mycol]
        mov  [fnt_col],al
        add  bx,8               ; a gap
        call FNT_PUT
.r:     pop  es
        ret

; ---- band: rows 0..TOP-1 from x BX, CX wide, black; ES = A000h. Keeps all
band:   push ax
        push cx
        push dx
        push di
        mov  dx,TOP             ; rows
        mov  di,bx              ; the first row's start
        xor  al,al
.r:     push cx
        push di
        rep  stosb
        pop  di
        pop  cx
        add  di,320             ; the next row
        dec  dx                 ; one row fewer
        jnz  .r
        pop  di
        pop  dx
        pop  cx
        pop  ax
        ret

; ---- TITLE: R_TITLE's card, drawn straight on the screen (this game has no
;  back buffer): drawn once, and again only when PRESS ENTER blinks - the
;  same pixels over themselves do not flicker. CF = 1 Esc. /AUTO: 12 ticks.
TITLE:  push es
        mov  ax,0A000h
        mov  es,ax
        mov  word [ttl_name],t_name ; our words on the card
        mov  word [ttl_sub],t_sub
        mov  word [ttl_keys],t_keys
        call now
        mov  [t0],ax
        mov  byte [tlit],2      ; (neither: the first look draws)
.f:     call now
        call TTLBLINK           ; CF = 1 lit
        sbb  al,al              ; AL = 0FFh lit, 0 dark
        and  al,1
        cmp  al,[tlit]
        je   .k
        mov  [tlit],al
        mov  di,166*320         ; PRESS ENTER's rows black...
        mov  cx,30*320/2
        xor  ax,ax
        rep  stosw
        call now
        call TTLCARD            ; ...and the card over them again
.k:     mov  ax,1680h           ; the time slice back (the browser)
        int  2Fh
        cmp  byte [auto],0
        je   .key
        call now
        sub  ax,[t0]            ; ticks shown
        cmp  ax,12
        jb   .f
        jmp  .go
.key:   mov  ah,1
        int  16h                ; a key waiting?
        jz   .f
        xor  ah,ah
        int  16h
        cmp  al,27
        je   .esc
        cmp  al,13
        je   .go
        cmp  al,' '
        jne  .f
.go:    xor  di,di              ; the screen black for the play
        mov  cx,32000
        xor  ax,ax
        rep  stosw
        pop  es
        clc
        ret
.esc:   pop  es
        stc
        ret

; ---- hex4: AX as four hex digits at DI ------------------------------------
hex4:   mov  cx,4
.h:     push cx
        mov  cl,4
        rol  ax,cl              ; the top digit to the bottom
        pop  cx
        mov  bl,al
        and  bl,0Fh             ; one digit, 0..15
        add  bl,'0'
        cmp  bl,'9'
        jbe  .p
        add  bl,7               ; A..F
.p:     mov  [di],bl
        inc  di                 ; the next place
        loop .h
        ret

; ---- isauto: ZF = 1 when the command line holds /AUTO --------------------
isauto: mov  si,81h
        mov  cl,[80h]
        xor  ch,ch
.l:     cmp  cx,5
        jb   .no
        cmp  word [si],'/A'
        jne  .n
        cmp  word [si+2],'UT'
        jne  .n
        cmp  byte [si+4],'O'
        je   .yes
.n:     inc  si                 ; the next character
        dec  cx                 ; one fewer left
        jmp  .l
.no:    or   sp,sp              ; ZF = 0
        ret
.yes:   cmp  al,al              ; ZF = 1
        ret

; ---- now: AX = the BIOS tick's low word, 18.2 a second --------------------
now:    push ds
        xor  ax,ax
        mov  ds,ax
        mov  ax,[046Ch]
        pop  ds
        ret

        include '..\..\ENGINE\E_NET.INC'
        include '..\..\KIT\LIB\K_NETX.INC'
        include '..\..\KIT\LIB\K_PEER.INC'
        include '..\..\KIT\LIB\K_FONT.INC' ; the good letters (FNT_*)
        include '..\..\KIT\REC\R_TITLE.ASM' ; TTLCARD, the title card

auto    db 0                    ; 1: /AUTO
solo    db 0                    ; 1: no IPX
moved   db 0                    ; our square moved since the last send
ishost  db 0FFh                 ; HOST shown? (0FFh: nothing shown yet)
mycol   db 15
heard   db 0
myx     dw 0
myy     dw 0
mydx    dw 0                    ; where ours is drawn (0FFFFh: nowhere)
mydy    dw 0
adir    dw STEP                 ; /AUTO's way along
t0      dw 0
lastt   dw 0
pkt:    db NETLEN dup(0)
tsolo   db 'no IPX - alone',0
twait   db 'waiting for a name',0
tnamed  db 'on the wire, named',0
thost   db 'HOST',0
tnohost db 0                    ; (the band cleared, nothing written)
tlit    db 0                    ; TITLE: the blink as drawn
t_name  db 'Squares',0          ; the title card's words (R_TITLE TTLCARD)
t_sub   db 'one each, one room',0
t_keys  db 'Arrows',0,'move',0  ; the key, what it does...
        db 'Esc',0,'quit',0
        db 0                    ; ...an empty key ends them
thex    db '0000',0
dsolo   db 'T_NET: no IPX - alone',13,10,'$'
dnoname db 'T_NET: IPX here, no address came - alone',13,10,'$'
dnamed  db 'T_NET: named on the wire',13,10,'$'
dheard  db 'T_NET: others: 0 heard, played and quit cleanly',13,10,'$'
