; ============================================================================
;  NETSQ.ASM - a square each, on the network: the smallest game made with
;  ..\ENGINE\E_NET.INC. Every player moves his own square with the arrows;
;  every machine in the room draws them all. Esc quits.
;
;      on the WIRE CITY site:   build A:\EXAMPLES\NETSQ.ASM --net=netsq
;      a second player:         the same, in a second tab or a friend's
;
;  The packet: x and y (words), the colour (a byte) - five bytes, sent when
;  the square moves and twice a second anyway, so a newcomer sees everyone
;  at once. A square not heard for three seconds is gone. Nothing is sent
;  before the wire has named us: until then our own echo would read as a
;  stranger's. Alone, or with no IPX, it is still a square to move.
; ============================================================================
NETSOCK = 4E4Eh                 ; our socket: a palindrome - its byte order
                                ;  cannot bite; never OWL FLY's 5757h/5858h
NETLEN  = 5                     ; x (word), y (word), colour (byte)
MAXP    = 8                     ; squares at once - ours is slot 0
SIDE    = 12                    ; a square's side, in pixels
STEP    = 4                     ; pixels an arrow moves it
BEAT    = 9                     ; ticks between sends when still: 2 a second
GONE    = 55                    ; ticks unheard before a square is gone: 3 s

; a slot: who, where it is, where it was drawn, its colour, when last heard
P_PID   = 0
P_X     = 2
P_Y     = 4
P_DX    = 6                     ; where it is drawn now (FFFFh: nowhere)
P_DY    = 8
P_COL   = 10
P_HEARD = 12
P_SIZE  = 14

format binary as 'com'
        org  100h
        include '..\ENGINE\E_8086.INC'

start:  mov  ax,13h             ; VGA 320x200, 256 colours
        int  10h
        call NETOPEN            ; CF: no IPX - alone, still a square
        mov  di,slots           ; every slot empty, nothing drawn
        mov  cx,MAXP*P_SIZE/2
        xor  ax,ax
        rep  stosw
        mov  si,0
.clr:  mov  word [slots+si+P_X],0FFFFh   ; nowhere, and drawn nowhere
        mov  word [slots+si+P_DX],0FFFFh
        add  si,P_SIZE          ; the next slot
        cmp  si,MAXP*P_SIZE
        jb   .clr
        mov  word [slots+P_X],154   ; ours, in the middle
        mov  word [slots+P_Y],94
        mov  byte [slots+P_COL],15  ; white until the wire names us
        call tick
        mov  [lastsend],ax

main:   mov  ax,1680h           ; give the time slice back: in the browser a
        int  2Fh                ;  loop that never yields starves the emulator
        cmp  word [slots+P_PID],0   ; not named yet? ask the wire again -
        jne  .keys                  ;  in the browser the address comes late
        call NETPID
        or   ax,ax
        jz   .keys
        mov  [slots+P_PID],ax
        xor  al,ah              ; both bytes of the name: on the relay the low
        mov  bl,al              ;  one is 86h for everyone, the high one numbers
        and  bx,7               ;  the players - 0..7 either way
        mov  al,bl
        add  al,8               ; a colour of eight, 8..15 - every one shows on
                                ;  black (16 would be black itself)
        mov  [slots+P_COL],al
        mov  cl,5
        shl  bx,cl              ; and a place of its own: 32 pixels apart,
        add  bx,32              ;  from x 32 - or every square starts on
        mov  [slots+P_X],bx     ;  every other one
        mov  byte [moved],1     ; and say so
.keys: mov  ah,1               ; a key?
        int  16h
        jz   .rx
        xor  ah,ah
        int  16h
        cmp  ah,1               ; Esc
        je   quit
        mov  bx,[slots+P_X]
        mov  dx,[slots+P_Y]
        cmp  ah,4Bh             ; Left
        jne  .k1
        sub  bx,STEP            ; four pixels left
.k1:   cmp  ah,4Dh             ; Right
        jne  .k2
        add  bx,STEP            ; four pixels right
.k2:   cmp  ah,48h             ; Up
        jne  .k3
        sub  dx,STEP            ; four pixels up
.k3:   cmp  ah,50h             ; Down
        jne  .k4
        add  dx,STEP            ; four pixels down
.k4:   cmp  bx,320-SIDE         ; kept on the screen (signed: left of 0
        jle  .k5                ;  is negative)
        mov  bx,320-SIDE
.k5:   or   bx,bx
        jns  .k6
        xor  bx,bx
.k6:   cmp  dx,200-SIDE
        jle  .k7
        mov  dx,200-SIDE
.k7:   or   dx,dx
        jns  .k8
        xor  dx,dx
.k8:   mov  [slots+P_X],bx
        mov  [slots+P_Y],dx
        mov  byte [moved],1

.rx:   call NETRECV            ; everything that came: CF when no more
        jc   .send
        call heard
        jmp  .rx

.send: cmp  word [slots+P_PID],0   ; not named yet: say nothing - our own
        je   .old                   ;  echo cannot be told from a stranger's
        call tick
        mov  bx,ax
        sub  bx,[lastsend]      ; ticks since our last send
        cmp  byte [moved],0
        jne  .go
        cmp  bx,BEAT
        jb   .old
.go:   mov  [lastsend],ax
        mov  byte [moved],0
        mov  ax,[slots+P_X]     ; our packet: x, y, colour
        mov  [pkt],ax
        mov  ax,[slots+P_Y]
        mov  [pkt+2],ax
        mov  al,[slots+P_COL]
        mov  [pkt+4],al
        mov  si,pkt
        call NETSEND

.old:  call tick               ; the ones not heard for three seconds: gone
        mov  dx,ax
        mov  si,P_SIZE          ; theirs only: slot 0 is ours
.o:    cmp  word [slots+si+P_PID],0
        je   .on
        mov  ax,dx
        sub  ax,[slots+si+P_HEARD]  ; ticks since we heard it
        cmp  ax,GONE
        jb   .on
        mov  word [slots+si+P_PID],0
        mov  word [slots+si+P_X],0FFFFh  ; nowhere: draw takes it away
.on:   add  si,P_SIZE          ; the next slot
        cmp  si,MAXP*P_SIZE
        jb   .o

        call draw
        jmp  main

quit:   call NETCLOSE           ; the socket back, then text mode 3
        mov  ax,3
        int  10h
        ret

; ---- heard: AX = who, DI -> his packet: his slot found or taken, set -------
heard:  mov  bx,ax
        xor  si,si              ; his slot, or the first free one
        mov  bp,0FFFFh
.f:    add  si,P_SIZE          ; theirs start at slot 1
        cmp  si,MAXP*P_SIZE
        jae  .free
        cmp  [slots+si+P_PID],bx
        je   .set
        cmp  word [slots+si+P_PID],0
        jne  .f
        cmp  bp,0FFFFh
        jne  .f
        mov  bp,si              ; the first free slot, kept
        jmp  .f
.free: cmp  bp,0FFFFh
        je   .full              ; the room is fuller than the screen: let it go
        mov  si,bp
        mov  [slots+si+P_PID],bx
.set:  mov  ax,[di]            ; x, clamped: a packet is someone's word
        cmp  ax,320-SIDE
        jbe  .x
        mov  ax,320-SIDE
.x:    mov  [slots+si+P_X],ax
        mov  ax,[di+2]          ; y, the same
        cmp  ax,200-SIDE
        jbe  .y
        mov  ax,200-SIDE
.y:    mov  [slots+si+P_Y],ax
        mov  al,[di+4]
        mov  [slots+si+P_COL],al
        call tick
        mov  [slots+si+P_HEARD],ax
.full: ret

; ---- draw: each square that moved - away from where it was, onto where it is
draw:   mov  dx,3DAh            ; wait for the vertical retrace: a square
.w1:   in   al,dx               ;  moved while the beam passes it tears
        test al,8
        jnz  .w1
.w2:   in   al,dx
        test al,8
        jz   .w2
        push es
        mov  ax,0A000h
        mov  es,ax
        xor  si,si
.d:    mov  ax,[slots+si+P_X]
        cmp  ax,[slots+si+P_DX]
        jne  .moved
        mov  ax,[slots+si+P_Y]
        cmp  ax,[slots+si+P_DY]
        je   .dn
.moved: mov  ax,[slots+si+P_DX] ; away from where it was drawn
        cmp  ax,0FFFFh
        je   .new
        mov  bx,[slots+si+P_DY]
        xor  cl,cl              ; in black
        call square
.new:  mov  ax,[slots+si+P_X]
        mov  [slots+si+P_DX],ax
        mov  bx,[slots+si+P_Y]
        mov  [slots+si+P_DY],bx
        cmp  ax,0FFFFh          ; gone: nothing more to draw
        je   .dn
        mov  cl,[slots+si+P_COL]
        call square
.dn:   add  si,P_SIZE          ; the next slot
        cmp  si,MAXP*P_SIZE
        jb   .d
        mov  ax,[slots+P_X]     ; ours drawn last, over the others
        mov  bx,[slots+P_Y]
        mov  cl,[slots+P_COL]
        call square
        pop  es
        ret

; ---- square: AX = x, BX = y, CL = colour; ES = A000h ------------------------
square: push si
        push ax
        mov  ax,320
        mul  bx                 ; AX = y x 320: its first row's start (DX lost)
        pop  di
        add  di,ax              ; + x: its corner
        mov  al,cl
        mov  bx,SIDE            ; rows to fill
.r:    mov  cx,SIDE
        rep  stosb
        add  di,320-SIDE        ; the next row's corner
        dec  bx                 ; one row fewer
        jnz  .r
        pop  si
        ret

; ---- tick: AX = the BIOS tick's low word, 18.2 a second ---------------------
tick:   push es
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:046Ch]
        pop  es
        ret

        include '..\ENGINE\E_NET.INC'

moved    db 0
lastsend dw 0
pkt:     db NETLEN dup(0)       ; (a bare label: its words and bytes alike)
slots:   db MAXP*P_SIZE dup(0)
