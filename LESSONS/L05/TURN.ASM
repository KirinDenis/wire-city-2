; ============================================================================
;  TURN.ASM - Lesson 5. Sixty-five numbers, and what they are for.
;
;      FASM TURN.ASM TURN.COM
;
;      1  the wave     the table, drawn as what it is
;      2  the circle   the same numbers, used the other way
;      3  the vector   where the two of them come from
;
;  The table was made by MKSIN.C, which ran once on another machine and is
;  not part of this program at all. What IS here is sixty-five whole numbers
;  and the four lines of arithmetic that unfold them into a whole circle.
;
;  A CIRCLE HAS 256 STEPS. Not 360 - 360 is a human convention with no factor
;  of two in it worth having. With 256 an angle wraps with AND 255, which is
;  free, and the quarter is the bottom six bits, which is a mask rather than a
;  division. Every constant in here was chosen because it is a power of two.
;
;  AND SINE IS KEPT AS sin*256. One is 256, a half is 128. Multiply by a
;  radius and shift down eight, and you have a distance in pixels without ever
;  having written a number with a dot in it.
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

include 'SINT.INC'

ang     dw 0
ptx     dw 0
pty     dw 0
col     db 0

; ---- sine, out of the quarter table ----------------------------------------
;  in:  AX = any angle at all
;  out: AX = sin(angle) * 256, from -256 to +256
;
;  The table holds one quarter. The second is the same numbers read backwards,
;  the third is the first negated, the fourth is the second negated - so
;  sixty-five words cover the whole circle and nothing is stored twice.
SINQ:   and  ax, 255            ; one AND and any angle is in range. No divide.
        mov  bx, ax
        mov  cl, 6
        shr  bx, cl             ; BX = the quarter, 0..3   (that is a/64)
        and  ax, 63             ; AX = how far into it     (that is a mod 64)
        cmp  bx, 1
        je   .back
        cmp  bx, 3
        je   .back
        jmp  .have
.back:  mov  dx, 64             ; quarters 1 and 3 read it backwards
        sub  dx, ax
        mov  ax, dx
.have:  add  ax, ax             ; two bytes to a word
        mov  si, ax
        mov  ax, [SINT+si]
        cmp  bx, 2
        jb   .done              ; 0 and 1 are above the axis
        neg  ax                 ; 2 and 3 below it
.done:  ret

; ---- one pixel, if it is on the screen -------------------------------------
Px:     mov  ax, [pty]
        cmp  ax, 0
        jl   .out
        cmp  ax, H
        jge  .out
        mov  bx, [ptx]
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

Key:    mov  ah, 0
        int  16h
        ret

Clear:  xor  di, di
        xor  ax, ax
        mov  cx, W*H/2
        rep  stosw
        ret

Boot:   cld
        mov  ax, 0013h
        int  10h
        mov  ax, VGA
        mov  es, ax

; ---- 1. the table, drawn as what it is -------------------------------------
; One pixel per entry, straight across the screen: the angle is the x, the
; sine is the y. If the sixty-five numbers are right, this is a sine wave -
; and if they are not, it will be obvious from here.
        mov  byte [col], 44
        mov  word [ang], 0
        mov  cx, 256
.wave:  push cx
        mov  ax, [ang]
        add  ax, 32
        mov  [ptx], ax          ; the angle, across

        mov  ax, [ang]
        call SINQ
        mov  cl, 2
        sar  ax, cl             ; sin*256 is too tall for the screen; /4
        neg  ax                 ; and down the screen is the wrong way up
        add  ax, CY_
        mov  [pty], ax
        call Px

        inc  word [ang]
        pop  cx
        loop .wave

        mov  di, CY_*W + 32
        mov  cx, 256
        mov  al, 8
        rep  stosb
        call Key

; ---- 2. the same numbers, used the other way -------------------------------
; Now instead of putting the sine on the screen, put it on a radius. x is the
; cosine of the angle times the radius, y is the sine - and sixty-four of them
; make a ring. Same table, same routine, different question.
        call Clear
        mov  byte [col], 44
        mov  word [ang], 0
        mov  cx, 64
.ring:  push cx
        mov  ax, [ang]
        add  ax, 64             ; cos(a) is sin(a + a quarter). One addition.
        call SINQ
        mov  bx, RAD
        imul bx
        mov  cl, 8
        sar  ax, cl             ; * radius / 256, and that is the whole of it
        add  ax, CX_
        mov  [ptx], ax

        mov  ax, [ang]
        call SINQ
        mov  bx, RAD
        imul bx
        mov  cl, 8
        sar  ax, cl
        add  ax, CY_
        mov  [pty], ax
        call Px

        add  word [ang], 4      ; 256 / 64 - one step of the table per point
        pop  cx
        loop .ring
        call Key

; ---- 3. where those two numbers come from ----------------------------------
; One angle, and the two sides of the triangle it stands on. The horizontal
; run is the cosine, the vertical run is the sine, and the dot is where they
; meet. Everything above is this, done over and over.
        call Clear
        mov  word [ang], 40

        mov  ax, [ang]          ; work out the point once
        add  ax, 64
        call SINQ
        mov  bx, RAD
        imul bx
        mov  cl, 8
        sar  ax, cl
        add  ax, CX_
        mov  [ptx], ax
        mov  ax, [ang]
        call SINQ
        mov  bx, RAD
        imul bx
        mov  cl, 8
        sar  ax, cl
        add  ax, CY_
        mov  [pty], ax

        ; the cosine, along the middle
        mov  di, CY_*W + CX_
        mov  cx, [ptx]
        sub  cx, CX_
        mov  al, 9
        rep  stosb

        ; the sine, straight down from there
        mov  ax, CY_
        mov  bx, W
        mul  bx
        add  ax, [ptx]
        mov  di, ax
        mov  cx, [pty]
        sub  cx, CY_
.down:  mov  byte [es:di], 14
        add  di, W
        loop .down

        mov  byte [col], 15
        call Px                 ; and the corner where they meet
        call Key

Bye:    mov  ax, 0003h
        int  10h
        mov  ax, 4C00h
        int  21h
