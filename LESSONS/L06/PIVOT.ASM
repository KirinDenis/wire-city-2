; ============================================================================
;  PIVOT.ASM - Lesson 6. A square that turns, and the flicker that comes free.
;
;      FASM PIVOT.ASM PIVOT.COM
;
;      SPACE   turn the retrace wait on and off. Watch the difference.
;      ESC     leave
;
;  Lesson 5 made sixty-four points sit on a ring. This one joins them up, and
;  the joining turns out to be the hard part.
;
;  WHY THIS NEEDS A REAL LINE ROUTINE. Lesson 3 got its lines free, because
;  they were horizontal and horizontal pixels are neighbours in memory. Turn
;  the square by one step and not one edge is horizontal any more. The cheap
;  case was a gift of the layout, and rotation takes it straight back.
;
;  Bresenham is the answer, and it is the same shape of trick as the sine
;  table: refuse to do the expensive thing. There is no division in it, no
;  multiply in the loop, and no fraction. It carries an error term and looks
;  at its sign - that is all.
;
;  AND THEN THE PICTURE FLICKERS, because we clear the whole screen and redraw
;  it while the card is reading the same memory out to the glass. Bit 3 of
;  port 3DAh says when the beam is on its way back; draw then and nobody sees
;  the drawing. SPACE turns that wait on and off so you can see what it buys.
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
R       = 44                    ; half the square, on each axis

        jmp  Boot

include 'SINT.INC'

; the four corners, as offsets from the centre, going round
corn    dw -R,-R
        dw  R,-R
        dw  R, R
        dw -R, R

cxs     dw 0,0,0,0              ; and where they land on the screen
cys     dw 0,0,0,0

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
fer     dw 0

; ---- sine, from the table made in lesson 5 ---------------------------------
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

; ---- one corner, turned ----------------------------------------------------
;  in:  [px],[py] = the corner as an offset from the centre
;       [ang]     = the angle
;  out: [rx],[ry] = where it lands on the screen
;
;      x = cx + (px*cos - py*sin) / 256
;      y = cy + (px*sin + py*cos) / 256
;
;  Two multiplies and two shifts a corner. No division, and no angle bigger
;  than a byte.
Rot:    mov  ax, [ang]
        call SINQ
        mov  [sn], ax
        mov  ax, [ang]
        add  ax, 64             ; cos is sin a quarter along. One add.
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
;  [lx0],[ly0] -> [lx1],[ly1], colour in [col].
;
;  Bresenham. The idea is one sentence: walk along the axis the line is
;  longest in, one pixel at a time, and keep a running error that says when
;  the other axis has fallen far enough behind to deserve a step. Adds,
;  subtracts and a comparison. No multiply in the loop, no divide anywhere.
Line:   mov  ax, [lx1]
        sub  ax, [lx0]
        mov  word [sx], 1       ; which way along x
        jns  .xok
        neg  ax
        mov  word [sx], -1
.xok:   mov  [ddx], ax          ; and how far, always positive

        mov  ax, [ly1]
        sub  ax, [ly0]
        mov  word [sy], 1
        jns  .yok
        neg  ax
        mov  word [sy], -1
.yok:   mov  [ddy], ax

        mov  ax, [ddx]
        sub  ax, [ddy]
        mov  [fer], ax          ; the error starts as the difference

.plot:  mov  ax, [ly0]          ; the one multiply, and it is the address
        mov  bx, W
        mul  bx
        add  ax, [lx0]
        mov  di, ax
        mov  al, [col]
        stosb

        mov  ax, [lx0]          ; arrived?
        cmp  ax, [lx1]
        jne  .step
        mov  ax, [ly0]
        cmp  ax, [ly1]
        je   .done

.step:  mov  ax, [fer]
        add  ax, ax             ; twice the error, which is a shift
        mov  bx, ax

        mov  ax, [ddy]
        neg  ax
        cmp  bx, ax
        jle  .noX
        mov  ax, [fer]
        sub  ax, [ddy]
        mov  [fer], ax
        mov  ax, [lx0]
        add  ax, [sx]
        mov  [lx0], ax
.noX:   cmp  bx, [ddx]
        jge  .plot
        mov  ax, [fer]
        add  ax, [ddx]
        mov  [fer], ax
        mov  ax, [ly0]
        add  ax, [sy]
        mov  [ly0], ax
        jmp  .plot
.done:  ret

; ---- wait for the beam to go home ------------------------------------------
;  Bit 3 of port 3DAh is up while the card is between pictures. Draw then and
;  nobody sees the drawing; draw at any other moment and they see half of it.
Retr:   mov  dx, 3DAh
.a:     in   al, dx             ; first make sure we are not already inside
        test al, 8              ; one, or we would go early and gain nothing
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

        ; turn all four corners, straight out of the list
        mov  si, 0
.corner:mov  bx, si
        add  bx, bx
        add  bx, bx             ; four bytes to a corner: two words
        mov  ax, [corn+bx]
        mov  [px], ax
        mov  ax, [corn+bx+2]
        mov  [py], ax
        push si                 ; SINQ reads the table through SI, so anything
        call Rot                ; that calls it must not be keeping something
        pop  si                 ; there. This cost a silent blank screen.
        mov  bx, si
        add  bx, bx
        mov  ax, [rx]
        mov  [cxs+bx], ax
        mov  ax, [ry]
        mov  [cys+bx], ax
        inc  si
        cmp  si, 4
        jl   .corner

        ; and join each one to the next, the last one back to the first
        mov  byte [col], 44
        mov  si, 0
.edge:  mov  bx, si
        add  bx, bx
        mov  ax, [cxs+bx]
        mov  [lx0], ax
        mov  ax, [cys+bx]
        mov  [ly0], ax
        mov  bx, si
        inc  bx
        and  bx, 3              ; 3 comes back round to 0. One AND, again.
        add  bx, bx
        mov  ax, [cxs+bx]
        mov  [lx1], ax
        mov  ax, [cys+bx]
        mov  [ly1], ax
        call Line
        inc  si
        cmp  si, 4
        jl   .edge

        inc  word [ang]         ; one step of 256 to the circle, per frame

        ; Both jumps back to .frame are hundreds of bytes away, which an 8086
        ; conditional jump cannot reach - so each is inverted and skips over
        ; an unconditional one. Fourth time in this series.
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
