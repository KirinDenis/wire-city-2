; ============================================================================
;  R_BLAST.ASM - recipe: a kill reads as a BANG - a growing fireball, hot
;  core in a cooler shell, cooling to smoke, then three cook-offs.
;
;  Guide GAMEPLAY "Damage": a fireball (a hot core in a cooler shell,
;  cooling to smoke grey), three cook-offs on three different pieces - not
;  "sixteen frames". OWL FLY III's schedule by age in ticks: the ball grows
;  and rises for 25 ticks, white-hot under 5, amber under 13, red under 20,
;  then smoke; the cook-offs go at 26, 58 and 96, 14 ticks each. Drawn as
;  two discs, row by row with an integer root: no table, no trig, round.
;
;        ...the kill: blage = 1, blx/bly = where (the wreck's centre)
;        ...each tick: inc word [blage] while it is not 0
;        ...each frame:
;        mov  ax,[blx]
;        mov  bx,[bly]
;        mov  cx,[blage]
;        call BLASTDRAW          ; CF=1: over - set blage = 0
;
;  copy: BLASTDRAW, BLASTSTAGE, BLDISC, BLSQRT and the tables.
;  define before: BL_HOT, BL_AMB, BL_RED, BL_SMK (colours: VGA default
;        15, 14, 40, 24)
;  calls: -   needs: ES = the buffer (320 a row, 200 rows)
;  from: GAMES\OWLFLY3\SRC\SYM.INC:1597-1598 (BLSEC), 1608-1700 (BLASTF:
;        sizes scaled from world units to pixels, about 1/10), 1747-1822
;        (BLDISC, BLSQRT: clipped at all four edges)
; ============================================================================

; ----------------------------------------------------------------------
;@ BLASTSTAGE the fireball at age AX: radius, rise and colours (CF=1 over)
;  in:  AX = ticks since the kill (0..)
;  out: CF=0 CX = radius px (0: none now), DX = how far it has risen px,
;       BL = core colour, BH = shell colour, SI = 0 the ball, 1..3 a
;       cook-off; CF=1 the blast is over
; ----------------------------------------------------------------------
BLASTSTAGE:
        push ax
        cmp  ax,25
        jae  .sec
        mov  cx,ax
        shr  cx,1               ; age/2
        add  cx,4               ; radius 4 + age/2: 4..16
        mov  dx,ax
        shr  dx,1               ; it rises age/2
        xor  si,si
        mov  bx,BL_AMB*256 + BL_HOT   ; white-hot in an amber shell
        cmp  ax,5
        jb   .ok
        mov  bx,BL_RED*256 + BL_AMB   ; amber in red
        cmp  ax,13
        jb   .ok
        mov  bx,BL_SMK*256 + BL_RED   ; red in smoke
        cmp  ax,20
        jb   .ok
        mov  bx,BL_SMK*256 + BL_SMK   ; out into smoke
        jmp  .ok
.sec:   xor  si,si              ; the cook-offs: which one is burning?
.s:     mov  bl,[BLSEC+si]
        xor  bh,bh
        mov  dx,ax
        sub  dx,bx              ; DX = its own age
        jb   .sn                ; not yet
        cmp  dx,14
        jb   .cook
.sn:    inc  si                 ; the next cook-off
        cmp  si,3
        jb   .s
        xor  cx,cx              ; between them: nothing burns now
        cmp  ax,96+14
        jae  .over
        xor  dx,dx
        mov  si,0
        jmp  .ok
.cook:  mov  cx,dx
        shr  cx,1               ; radius 2 + age/2: 2..8
        add  cx,2
        mov  bx,BL_AMB*256 + BL_HOT
        cmp  dx,4
        jb   .ck
        mov  bx,BL_RED*256 + BL_AMB
        cmp  dx,9
        jb   .ck
        mov  bx,BL_SMK*256 + BL_RED
.ck:    shr  dx,1               ; it rises age/2 too
        inc  si                 ; SI = 1..3
.ok:    pop  ax
        clc
        ret
.over:  pop  ax
        stc
        ret

; ----------------------------------------------------------------------
;@ BLASTDRAW  draw the blast of age CX standing at pixel (AX,BX)
;  in:  AX = x, BX = y (where it burns), CX = its age in ticks
;  out: CF=1 over (draw nothing more; clear the age)
; ----------------------------------------------------------------------
BLASTDRAW:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        mov  [blpx],ax
        mov  [blpy],bx
        mov  ax,cx
        call BLASTSTAGE
        jc   .r
        jcxz .done              ; between cook-offs
        mov  ax,[blpx]
        mov  di,[blpy]
        or   si,si
        jz   .at                ; the ball sits on the kill
        dec  si
        shl  si,1               ; a word per cook-off
        add  ax,[BLDX+si]       ; each on its own piece
        add  di,[BLDY+si]
.at:    sub  di,dx              ; risen
        mov  dl,bh              ; the cool shell...
        push bx
        mov  bx,di
        call BLDISC
        pop  bx
        shr  cx,1               ; ...the hot core inside it, half as big
        jcxz .done
        mov  dl,bl
        mov  bx,di
        call BLDISC
.done:  clc
.r:     pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; ----------------------------------------------------------------------
;@ BLDISC     a solid disc, centre (AX,BX), radius CX, colour DL, clipped
;  in:  AX = x, BX = y, CX = radius 0..100, DL = colour; ES = the buffer
;  out: -
; ----------------------------------------------------------------------
BLDISC: push ax
        push bx
        push cx
        push dx
        push si
        push di
        mov  [bdcx],ax
        mov  [bdcy],bx
        mov  [bdr],cx
        mov  [bdcol],dl
        mov  si,cx
        neg  si                 ; SI = dy, walking down from -r
.row:   mov  ax,[bdcy]
        add  ax,si              ; the row
        cmp  ax,0
        jl   .next
        cmp  ax,199
        jg   .next
        mov  [bdrow],ax
        mov  ax,si
        imul si                 ; dy*dy (r <= 100: it fits a word)
        mov  cx,ax
        mov  ax,[bdr]
        imul ax                 ; r*r
        sub  ax,cx              ; r*r - dy*dy, never below 0 here
        call BLSQRT             ; AX = the half width
        mov  dx,ax
        add  dx,dx
        inc  dx                 ; DX = the full span
        mov  cx,[bdcx]
        sub  cx,ax              ; CX = its left end
        jns  .l1
        add  dx,cx              ; off the left edge: shorten it
        xor  cx,cx
.l1:    cmp  dx,0
        jle  .next
        cmp  cx,320
        jge  .next              ; all of it off the right
        mov  ax,cx
        add  ax,dx
        cmp  ax,320
        jle  .l2
        mov  dx,320             ; ...and off the right
        sub  dx,cx
.l2:    mov  ax,[bdrow]         ; DI = row*320 + x, as 256 + 64
        mov  di,ax
        mov  bx,ax
        push cx
        mov  cl,8
        shl  di,cl              ; row*256
        mov  cl,6
        shl  bx,cl              ; row*64
        pop  cx
        add  di,bx
        add  di,cx              ; + x
        mov  cx,dx
        mov  al,[bdcol]
        cld
        rep  stosb
.next:  inc  si                 ; the next row
        cmp  si,[bdr]
        jle  .row
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; BLSQRT - AX = floor(sqrt(AX)), by taking away the odd numbers. keeps all else.
BLSQRT: push bx
        push cx
        xor  cx,cx
        mov  bx,1
.s:     cmp  ax,bx
        jb   .sd
        sub  ax,bx              ; take the next odd number away
        add  bx,2               ; the next odd number
        inc  cx                 ; one more taken: the root grows
        jmp  .s
.sd:    mov  ax,cx
        pop  cx
        pop  bx
        ret

BLSEC   db 26,58,96             ; when the three cook-offs go
BLDX    dw -6, 7, 2             ; ...and on which piece: offsets, pixels
BLDY    dw 2, 3, -1
blpx    dw 0
blpy    dw 0
bdcx    dw 0                    ; BLDISC's centre, radius, row, colour
bdcy    dw 0
bdr     dw 0
bdrow   dw 0
bdcol   db 0
