; ============================================================================
;  PIVOT.ASM - Lesson 5. A table, a radius vector, and a square that turns.
;
;      FASM PIVOT.ASM PIVOT.COM
;
;  Lesson 4 said the machine cannot afford to divide. This one is what you do
;  instead: you look the answer up. Sixty-five numbers, made once by a program
;  on another machine, and from them come every angle this series will ever
;  need - the square here, the aeroplane later, the whole camera.
;
;      SPACE   turn the retrace wait on and off. Watch the flicker.
;      ESC     leave
;
;  WHY THE CIRCLE HAS 256 STEPS. Because an angle then wraps with AND 255 and
;  never needs a division - and because 64 steps to the quarter means the
;  table index is the bottom six bits, which is a mask rather than a modulo.
;  Degrees are a human convention; 256 is the machine's.
;
;  AND WHY THIS SQUARE NEEDS A REAL LINE ROUTINE. Lesson 3 got its lines free,
;  because they were horizontal and horizontal pixels are neighbours in
;  memory. Turn the square one degree and not one edge is horizontal any more.
;  The cheap case was a gift of the layout, and rotation takes it straight
;  back - which is why Bresenham is here, adding and subtracting its way along
;  without a single multiply.
;
;  Owlos - legacy software modernization - https://owlos.sk
; ============================================================================
format binary as 'com'
        org  100h

VGA     = 0A000h
W       = 320
H       = 200
CX_     = 160                   ; the centre it turns about
CY_     = 100
R       = 44                    ; half the square, corner to centre on each axis

        jmp  Boot

; ---- sine, from the table --------------------------------------------------
;  in:  AX = angle, any value at all
;  out: AX = sin(angle) * 256, from -256 to +256
;
;  The table holds only the first quarter. The other three are the same
;  sixty-five numbers read backwards, or negated, or both - which is the
;  whole reason for storing a quarter and not a circle.
SINQ:   and  ax, 255            ; one AND, and any angle is in range
        mov  bx, ax
        mov  cl, 6
        shr  bx, cl             ; BX = which quarter, 0..3
        and  ax, 63             ; AX = how far into it, 0..63
        cmp  bx, 1
        je   .back
        cmp  bx, 3
        je   .back
        jmp  .have
.back:  mov  dx, 64             ; quarters 1 and 3 read the table backwards
        sub  dx, ax
        mov  ax, dx
.have:  add  ax, ax             ; two bytes to an entry
        mov  si, ax
        mov  ax, [SINT+si]
        cmp  bx, 2
        jb   .done              ; quarters 0 and 1 are above the axis
        neg  ax                 ; 2 and 3 below it
.done:  ret

; ---- one corner, turned ----------------------------------------------------
;  in:  [px],[py] = the corner as an offset from the centre
;       [ang]     = the angle
;  out: [rx],[ry] = where it lands on the screen
;
;      x = cx + (px*cos - py*sin) / 256
;      y = cy + (px*sin + py*cos) / 256
;
;  Two multiplies and two shifts per corner. No division anywhere, and no
;  angle bigger than a byte.
Rot:    mov  ax, [ang]
        call SINQ
        mov  [sn], ax
        mov  ax, [ang]
        add  ax, 64             ; cos(a) is sin(a + a quarter). One add.
        call SINQ
        mov  [co], ax

        mov  ax, [px]
        imul word [co]
        mov  bx, ax
        mov  ax, [py]
        imul word [sn]
        sub  bx, ax
        mov  ax, bx
        mov  cl, 8
        sar  ax, cl             ; /256, and SAR keeps the sign
        add  ax, CX_
        mov  [rx], ax

        mov  ax, [px]
        imul word [sn]
        mov  bx, ax
        mov  ax, [py]
        imul word [co]
        add  bx, ax
        mov  ax, bx
        mov  cl, 8
        sar  ax, cl
        add  ax, CY_
        mov  [ry], ax
        ret

; ---- a line between any two points -----------------------------------------
;  [lx0],[ly0] -> [lx1],[ly1], colour in [col].  Bresenham: the whole thing
;  runs on adds, subtracts and comparisons. Not one multiply in the loop.
Line:   mov  ax, [lx1]
        sub  ax, [lx0]
        mov  word [sx], 1
        jns  .xok
        neg  ax
        mov  word [sx], -1
.xok:   mov  [ddx], ax

        mov  ax, [ly1]
        sub  ax, [ly0]
        mov  word [sy], 1
        jns  .yok
        neg  ax
        mov  word [sy], -1
.yok:   mov  [ddy], ax

        mov  ax, [ddx]
        sub  ax, [ddy]
        mov  [ferr], ax

.plot:  mov  ax, [ly0]          ; the one multiply, and it is the address
        mov  bx, W
        mul  bx
        add  ax, [lx0]
        mov  di, ax
        mov  al, [col]
        stosb

        mov  ax, [lx0]
        cmp  ax, [lx1]
        jne  .step
        mov  ax, [ly0]
        cmp  ax, [ly1]
        je   .done

.step:  mov  ax, [ferr]
        add  ax, ax             ; e2 = ferr * 2, which is one shift
        mov  bx, ax

        mov  ax, [ddy]
        neg  ax
        cmp  bx, ax
        jle  .noX
        mov  ax, [ferr]
        sub  ax, [ddy]
        mov  [ferr], ax
        mov  ax, [lx0]
        add  ax, [sx]
        mov  [lx0], ax
.noX:   cmp  bx, [ddx]
        jge  .plot
        mov  ax, [ferr]
        add  ax, [ddx]
        mov  [ferr], ax
        mov  ax, [ly0]
        add  ax, [sy]
        mov  [ly0], ax
        jmp  .plot
.done:  ret

; ---- wait for the beam to go home ------------------------------------------
;  Bit 3 of port 3DAh is up while the card is between pictures. Draw then and
;  nobody sees the drawing - draw at any other moment and they see half of it.
Retr:   mov  dx, 3DAh
.a:     in   al, dx             ; first make sure we are NOT in one already,
        test al, 8              ; or we would go early and gain nothing
        jnz  .a
.b:     in   al, dx
        test al, 8
        jz   .b
        ret

Boot:   cld
        mov  ax, 0013h
        int  10h
        mov  ax, VGA
        mov  es, ax

.frame: cmp  word [sync], 0
        je   .clear
        call Retr

.clear: xor  di, di             ; the whole screen, every frame
        xor  ax, ax
        mov  cx, W*H/2
        rep  stosw

        ; the four corners, each one turned by the same angle
        mov  word [px], -R
        mov  word [py], -R
        call Rot
        mov  ax, [rx]
        mov  [ax0], ax
        mov  ax, [ry]
        mov  [ay0], ax

        mov  word [px], R
        mov  word [py], -R
        call Rot
        mov  ax, [rx]
        mov  [ax1], ax
        mov  ax, [ry]
        mov  [ay1], ax

        mov  word [px], R
        mov  word [py], R
        call Rot
        mov  ax, [rx]
        mov  [ax2], ax
        mov  ax, [ry]
        mov  [ay2], ax

        mov  word [px], -R
        mov  word [py], R
        call Rot
        mov  ax, [rx]
        mov  [ax3], ax
        mov  ax, [ry]
        mov  [ay3], ax

        mov  byte [col], 44
        mov  si, edges
        mov  cx, 4
.edge:  push cx
        push si
        lodsw
        mov  bx, ax
        mov  ax, [bx]
        mov  [lx0], ax
        lodsw
        mov  bx, ax
        mov  ax, [bx]
        mov  [ly0], ax
        lodsw
        mov  bx, ax
        mov  ax, [bx]
        mov  [lx1], ax
        lodsw
        mov  bx, ax
        mov  ax, [bx]
        mov  [ly1], ax
        call Line
        pop  si
        add  si, 8
        pop  cx
        loop .edge

        inc  word [ang]         ; one step of 256 to the circle, every frame

        ; Both jumps back to .frame are two hundred bytes away, which an 8086
        ; conditional jump cannot reach - so each one is inverted and skips
        ; over an unconditional jump instead. Third time this has come up in
        ; the series; ENGINE\E_8086.INC does it for the games automatically.
        mov  ah, 1
        int  16h
        jnz  .akey
        jmp  .frame
.akey:  mov  ah, 0
        int  16h
        cmp  al, 27
        je   Bye
        cmp  al, ' '
        je   .flip
        jmp  .frame
.flip:  xor  word [sync], 1     ; SPACE flips the retrace wait
        jmp  .frame

Bye:    mov  ax, 0003h
        int  10h
        mov  ax, 4C00h
        int  21h

; ---- the four edges, as pointers to the corners we just worked out ---------
edges   dw ax0,ay0,ax1,ay1
        dw ax1,ay1,ax2,ay2
        dw ax2,ay2,ax3,ay3
        dw ax3,ay3,ax0,ay0

include 'SINT.INC'

ang     dw 0
sn      dw 0
co      dw 0
px      dw 0
py      dw 0
rx      dw 0
ry      dw 0
sync    dw 0
col     db 0
lx0     dw 0
ly0     dw 0
lx1     dw 0
ly1     dw 0
ddx     dw 0
ddy     dw 0
sx      dw 0
sy      dw 0
ferr     dw 0
ax0     dw 0
ay0     dw 0
ax1     dw 0
ay1     dw 0
ax2     dw 0
ay2     dw 0
ax3     dw 0
ay3     dw 0
