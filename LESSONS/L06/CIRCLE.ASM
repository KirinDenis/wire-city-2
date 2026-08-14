; ============================================================================
;  CIRCLE.ASM - Lesson 6. A round thing, on a screen that is not square.
;
;      FASM CIRCLE.ASM CIRCLE.COM
;
;      1  from the table      64 points, and you can see the gaps between them
;      2  every pixel         the midpoint algorithm: adds and shifts, no more
;      3  the same, squashed  and NOW it looks round
;      4  filled              which is the horizontal span again
;
;  THE POINT OF THE WHOLE LESSON is between frames 2 and 3, and it is this:
;  frame 2 is a mathematically perfect circle and it looks like an egg. Mode
;  13h is 320 by 200 on a screen that is four units wide and three tall, so a
;  pixel is a fifth taller than it is wide. A shape with equal radii in PIXELS
;  is therefore a fifth too tall in MILLIMETRES.
;
;  To draw something that looks round you have to draw something that is not:
;  ry = rx * 5/6, which in this series' arithmetic is (rx * 213) >> 8. So the
;  oval is not a harder circle to be done later. It is the circle you actually
;  have to draw, and the true one is the special case nobody wants.
;
;  NOT ONE MULTIPLY IN THE LOOP. The midpoint algorithm carries a decision
;  variable and steps it with additions - the same trick as Bresenham's line
;  in lesson 5. The only multiply here is the squash, once per point, and it
;  is the multiply-and-shift from lesson 4.
;
;  Owlos - legacy software modernization - https://owlos.sk
; ============================================================================
format binary as 'com'
        org  100h

VGA     = 0A000h
W       = 320
H       = 200
CX_     = 160
CY_     = 100
RAD     = 70

        jmp  Boot

; ---- sine, from the generated table ----------------------------------------
SINQ:   and  ax, 255
        mov  bx, ax
        mov  cl, 6
        shr  bx, cl
        and  ax, 63
        cmp  bx, 1
        je   .back
        cmp  bx, 3
        je   .back
        jmp  .have
.back:  mov  dx, 64
        sub  dx, ax
        mov  ax, dx
.have:  add  ax, ax
        mov  si, ax
        mov  ax, [SINT+si]
        cmp  bx, 2
        jb   .done
        neg  ax
.done:  ret

; ---- squash a vertical distance so the shape looks round --------------------
;  213/256 is 0.832, and the pixel is 1.2 times taller than it is wide. One
;  multiply, one shift, and nothing else in this program knows about it.
Sq:     cmp  word [flat], 0
        je   .no
        mov  bx, 213
        imul bx
        mov  cl, 8
        sar  ax, cl
.no:    ret

; ---- one pixel, if it is on the screen -------------------------------------
Px:     mov  ax, [pxy]
        cmp  ax, 0
        jl   .out
        cmp  ax, H
        jge  .out
        mov  bx, [pxx]
        cmp  bx, 0
        jl   .out
        cmp  bx, W
        jge  .out
        mov  cx, W
        mul  cx
        add  ax, bx
        mov  di, ax
        mov  al, [col]
        stosb
.out:   ret

; ---- one point, offset from the centre -------------------------------------
;  AX = across, DX = down. Both already squashed if they needed to be.
PP:     add  ax, CX_
        mov  [pxx], ax
        add  dx, CY_
        mov  [pxy], dx
        call Px
        ret

; ---- the eight the symmetry gives us ---------------------------------------
;  Work out one eighth of a circle and the other seven are the same numbers
;  with the signs changed and the axes swapped. That is why the loop only ever
;  runs while x <= y.
P8:     mov  ax, [oy]
        call Sq
        mov  [qy], ax
        mov  ax, [ox]
        call Sq
        mov  [qx], ax

        mov  ax, [ox]
        mov  dx, [qy]
        call PP
        mov  ax, [ox]
        neg  ax
        mov  dx, [qy]
        call PP
        mov  ax, [ox]
        mov  dx, [qy]
        neg  dx
        call PP
        mov  ax, [ox]
        neg  ax
        mov  dx, [qy]
        neg  dx
        call PP

        mov  ax, [oy]
        mov  dx, [qx]
        call PP
        mov  ax, [oy]
        neg  ax
        mov  dx, [qx]
        call PP
        mov  ax, [oy]
        mov  dx, [qx]
        neg  dx
        call PP
        mov  ax, [oy]
        neg  ax
        mov  dx, [qx]
        neg  dx
        call PP
        ret

; ---- four horizontal spans, for the filled one -----------------------------
;  The span between two symmetric points is a run of neighbouring bytes, which
;  is lesson 3's free line. A filled circle is not a new idea either.
Span:   mov  ax, [spy]
        cmp  ax, 0
        jl   .out
        cmp  ax, H
        jge  .out
        mov  cx, W
        mul  cx
        mov  di, ax
        mov  ax, CX_
        sub  ax, [sph]
        jns  .lok
        xor  ax, ax
.lok:   add  di, ax
        mov  cx, [sph]
        add  cx, cx
        inc  cx
        mov  al, [col]
        rep  stosb
.out:   ret

Boot:   cld
        mov  ax, 0013h
        int  10h
        mov  ax, VGA
        mov  es, ax

; ---- 1. sixty-four points off the table ------------------------------------
        mov  byte [col], 44
        mov  word [ang], 0
        mov  cx, 64
.dots:  push cx
        mov  ax, [ang]
        add  ax, 64             ; cos
        call SINQ
        mov  bx, RAD
        imul bx
        mov  cl, 8
        sar  ax, cl
        mov  [ox], ax

        mov  ax, [ang]
        call SINQ
        mov  bx, RAD
        imul bx
        mov  cl, 8
        sar  ax, cl
        mov  dx, ax
        mov  ax, [ox]
        call PP

        add  word [ang], 4      ; 256/64 - one step of the table per point
        pop  cx
        loop .dots
        call Key

; ---- 2. every pixel, and it looks like an egg ------------------------------
        call Clear
        mov  word [flat], 0
        call Ring
        call Key

; ---- 3. the same circle, squashed, and NOW it looks round ------------------
        call Clear
        mov  word [flat], 1
        call Ring
        call Key

; ---- 4. filled ------------------------------------------------------------
        call Clear
        mov  word [flat], 1
        call Disc
        call Key

Bye:    mov  ax, 0003h
        int  10h
        mov  ax, 4C00h
        int  21h

Clear:  xor  di, di
        xor  ax, ax
        mov  cx, W*H/2
        rep  stosw
        ret

Key:    mov  ah, 0
        int  16h
        cmp  al, 27
        jne  .stay
        jmp  Bye
.stay:  ret

; ---- the midpoint circle ---------------------------------------------------
;  x starts at 0 and y at the radius, and a decision variable says which of
;  the two candidate pixels is nearer the true circle. Every step is an add
;  or a shift. There is no multiply, no divide, no square root and no sine.
Ring:   mov  word [ox], 0
        mov  ax, RAD
        mov  [oy], ax
        add  ax, ax
        neg  ax
        add  ax, 3              ; d = 3 - 2r
        mov  [dv], ax
.l:     mov  ax, [ox]
        cmp  ax, [oy]
        jg   .done
        call P8
        mov  ax, [dv]
        cmp  ax, 0
        jge  .out
        mov  ax, [ox]           ; d += 4x + 6
        add  ax, ax
        add  ax, ax
        add  ax, 6
        add  [dv], ax
        jmp  .on
.out:   mov  ax, [ox]           ; d += 4(x - y) + 10
        sub  ax, [oy]
        add  ax, ax
        add  ax, ax
        add  ax, 10
        add  [dv], ax
        dec  word [oy]
.on:    inc  word [ox]
        jmp  .l
.done:  ret

; ---- the same walk, but filling as it goes ---------------------------------
Disc:   mov  word [ox], 0
        mov  ax, RAD
        mov  [oy], ax
        add  ax, ax
        neg  ax
        add  ax, 3
        mov  [dv], ax
.l:     mov  ax, [ox]
        cmp  ax, [oy]
        jle  .go                ; the body below is 135 bytes, and a
        jmp  .done              ; conditional jump reaches 127
.go:    mov  ax, [oy]
        call Sq
        mov  [qy], ax
        mov  ax, [ox]
        call Sq
        mov  [qx], ax

        mov  ax, [ox]
        mov  [sph], ax
        mov  ax, CY_
        add  ax, [qy]
        mov  [spy], ax
        call Span
        mov  ax, CY_
        sub  ax, [qy]
        mov  [spy], ax
        call Span

        mov  ax, [oy]
        mov  [sph], ax
        mov  ax, CY_
        add  ax, [qx]
        mov  [spy], ax
        call Span
        mov  ax, CY_
        sub  ax, [qx]
        mov  [spy], ax
        call Span

        mov  ax, [dv]
        cmp  ax, 0
        jge  .out
        mov  ax, [ox]
        add  ax, ax
        add  ax, ax
        add  ax, 6
        add  [dv], ax
        jmp  .on
.out:   mov  ax, [ox]
        sub  ax, [oy]
        add  ax, ax
        add  ax, ax
        add  ax, 10
        add  [dv], ax
        dec  word [oy]
.on:    inc  word [ox]
        jmp  .l
.done:  ret

include 'SINT.INC'

ang     dw 0
ox      dw 0
oy      dw 0
qx      dw 0
qy      dw 0
dv      dw 0
flat    dw 0
pxx     dw 0
pxy     dw 0
sph     dw 0
spy     dw 0
col     db 0
