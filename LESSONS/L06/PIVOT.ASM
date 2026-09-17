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

        jmp  Boot               ; over the tables and routines, to the boot

include 'SINT.INC'              ; lesson 5's sixty-five numbers

; the four corners, as offsets from the centre, going round
corn    dw -R,-R
        dw  R,-R
        dw  R, R
        dw -R, R

cxs     dw 0,0,0,0              ; and where they land on the screen
cys     dw 0,0,0,0

ang     dw 0                    ; the angle the square is at, 0..255
sn      dw 0                    ; sin(ang) * 256 ...
co      dw 0                    ; ... and cos(ang) * 256, for this frame
px      dw 0                    ; the corner Rot is given ...
py      dw 0
rx      dw 0                    ; ... and where it lands
ry      dw 0
sync    dw 0                    ; 1 = wait for the retrace, 0 = do not
col     db 0                    ; the colour Line draws in
lx0     dw 0                    ; Line: from ...
ly0     dw 0
lx1     dw 0                    ; ... to
ly1     dw 0
ddx     dw 0                    ; how far in x, always positive
ddy     dw 0                    ; how far in y, always positive
sx      dw 0                    ; which way in x: +1 or -1
sy      dw 0                    ; which way in y
fer     dw 0                    ; the running error

; ---- sine, from the table made in lesson 5 ---------------------------------
;  In C:
;
;      int sinq(int a)                       /* sin(a) * 256, a in 256ths of a turn */
;      {
;          int q = (a & 255) >> 6;           /* which quarter, 0..3       */
;          int i = a & 63;                   /* how far into it           */
;          if (q == 1 || q == 3) i = 64 - i; /* odd quarters run backwards */
;          return q < 2 ? SINT[i] : -SINT[i];
;      }
SINQ:   and  ax, 255            ; a &= 255: a whole circle
        mov  bx, ax             ; BX = a
        mov  cl, 6              ; CL = 6
        shr  bx, cl             ; q = a >> 6: which quarter, 0..3
        and  ax, 63             ; i = a & 63: how far into it
        cmp  bx, 1              ; q == 1 ?
        je   .back              ;   yes: backwards
        cmp  bx, 3              ; q == 3 ?
        je   .back              ;   yes: backwards
        jmp  .have              ; else: forwards
.back:  mov  dx, 64             ; DX = 64
        sub  dx, ax             ; DX = 64 - i
        mov  ax, dx             ; i = 64 - i
.have:  add  ax, ax             ; AX = i * 2: two bytes to an entry
        mov  si, ax             ; SI = i * 2
        mov  ax, [SINT+si]      ; AX = SINT[i]
        cmp  bx, 2              ; q < 2 ?
        jb   .done              ;   yes: return SINT[i]
        neg  ax                 ; AX = -SINT[i]: the bottom half is negative
.done:  ret                     ; return AX

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
;  In C:
;
;      void rot(void)
;      {
;          sn = sinq(ang);  co = sinq(ang + 64);
;          rx = CX_ + ((px * co - py * sn) >> 8);
;          ry = CY_ + ((px * sn + py * co) >> 8);
;      }
Rot:    mov  ax, [ang]          ; AX = ang
        call SINQ               ; AX = sin(ang) * 256
        mov  [sn], ax           ; sn = AX
        mov  ax, [ang]          ; AX = ang
        add  ax, 64             ; AX = ang + 64: cos is sin a quarter along. One add.
        call SINQ               ; AX = cos(ang) * 256
        mov  [co], ax           ; co = AX
                                ;
        mov  ax, [px]           ; AX = px
        imul word [co]          ; AX = px * co
        mov  bx, ax             ; BX = px * co
        mov  ax, [py]           ; AX = py
        imul word [sn]          ; AX = py * sn
        sub  bx, ax             ; BX = px * co - py * sn
        mov  ax, bx             ; AX = BX
        mov  cl, 8              ; CL = 8
        sar  ax, cl             ; AX >>= 8: /256, and SAR keeps the sign
        add  ax, CX_            ; AX += 160
        mov  [rx], ax           ; rx = AX
                                ;
        mov  ax, [px]           ; AX = px
        imul word [sn]          ; AX = px * sn
        mov  bx, ax             ; BX = px * sn
        mov  ax, [py]           ; AX = py
        imul word [co]          ; AX = py * co
        add  bx, ax             ; BX = px * sn + py * co
        mov  ax, bx             ; AX = BX
        mov  cl, 8              ; CL = 8
        sar  ax, cl             ; AX >>= 8
        add  ax, CY_            ; AX += 100
        mov  [ry], ax           ; ry = AX
        ret                     ; return

; ---- a line between any two points -----------------------------------------
;  [lx0],[ly0] -> [lx1],[ly1], colour in [col].
;
;  Bresenham. The idea is one sentence: walk along the axis the line is
;  longest in, one pixel at a time, and keep a running error that says when
;  the other axis has fallen far enough behind to deserve a step. Adds,
;  subtracts and a comparison. No multiply in the loop, no divide anywhere.
;  In C:
;
;      void line(void)                          /* lx0,ly0 -> lx1,ly1 in col */
;      {
;          ddx = abs(lx1 - lx0);  sx = lx1 >= lx0 ? 1 : -1;
;          ddy = abs(ly1 - ly0);  sy = ly1 >= ly0 ? 1 : -1;
;          fer = ddx - ddy;
;          for (;;) {
;              screen[ly0 * 320 + lx0] = col;
;              if (lx0 == lx1 && ly0 == ly1) return;
;              int e2 = fer * 2;
;              if (e2 > -ddy) { fer -= ddy;  lx0 += sx; }
;              if (e2 <  ddx) { fer += ddx;  ly0 += sy; }
;          }
;      }
Line:   mov  ax, [lx1]          ; AX = lx1
        sub  ax, [lx0]          ; AX = lx1 - lx0
        mov  word [sx], 1       ; sx = 1: which way along x
        jns  .xok               ; not negative ? fine
        neg  ax                 ; AX = -AX
        mov  word [sx], -1      ; sx = -1
.xok:   mov  [ddx], ax          ; ddx = AX: and how far, always positive
                                ;
        mov  ax, [ly1]          ; AX = ly1
        sub  ax, [ly0]          ; AX = ly1 - ly0
        mov  word [sy], 1       ; sy = 1
        jns  .yok               ; not negative ? fine
        neg  ax                 ; AX = -AX
        mov  word [sy], -1      ; sy = -1
.yok:   mov  [ddy], ax          ; ddy = AX
                                ;
        mov  ax, [ddx]          ; AX = ddx
        sub  ax, [ddy]          ; AX = ddx - ddy
        mov  [fer], ax          ; fer = AX: the error starts as the difference
                                ;
.plot:  mov  ax, [ly0]          ; AX = ly0: the one multiply, and it is the address
        mov  bx, W              ; BX = 320
        mul  bx                 ; AX = ly0 * 320
        add  ax, [lx0]          ; AX = ly0 * 320 + lx0
        mov  di, ax             ; DI = the pixel
        mov  al, [col]          ; AL = col
        stosb                   ; screen[DI++] = col
                                ;
        mov  ax, [lx0]          ; AX = lx0: arrived?
        cmp  ax, [lx1]          ; lx0 == lx1 ?
        jne  .step              ;   no: step on
        mov  ax, [ly0]          ; AX = ly0
        cmp  ax, [ly1]          ; ly0 == ly1 ?
        je   .done              ;   yes: return
                                ;
.step:  mov  ax, [fer]          ; AX = fer
        add  ax, ax             ; AX = fer * 2: twice the error, which is a shift
        mov  bx, ax             ; e2 = AX
                                ;
        mov  ax, [ddy]          ; AX = ddy
        neg  ax                 ; AX = -ddy
        cmp  bx, ax             ; e2 > -ddy ?
        jle  .noX               ;   no: x stays
        mov  ax, [fer]          ; AX = fer
        sub  ax, [ddy]          ; AX = fer - ddy
        mov  [fer], ax          ; fer = AX
        mov  ax, [lx0]          ; AX = lx0
        add  ax, [sx]           ; AX = lx0 + sx
        mov  [lx0], ax          ; lx0 = AX
.noX:   cmp  bx, [ddx]          ; e2 < ddx ?
        jge  .plot              ;   no: y stays, plot the next
        mov  ax, [fer]          ; AX = fer
        add  ax, [ddx]          ; AX = fer + ddx
        mov  [fer], ax          ; fer = AX
        mov  ax, [ly0]          ; AX = ly0
        add  ax, [sy]           ; AX = ly0 + sy
        mov  [ly0], ax          ; ly0 = AX
        jmp  .plot              ; plot the next
.done:  ret                     ; return

; ---- wait for the beam to go home ------------------------------------------
;  Bit 3 of port 3DAh is up while the card is between pictures. Draw then and
;  nobody sees the drawing; draw at any other moment and they see half of it.
;  In C:   while (inp(0x3DA) & 8) ;  while (!(inp(0x3DA) & 8)) ;
Retr:   mov  dx, 3DAh           ; DX = 3DAh: the status port
.a:     in   al, dx             ; AL = inp(0x3DA): first make sure we are not already inside
        test al, 8              ; bit 3 up ?   one, or we would go early and gain nothing
        jnz  .a                 ;   yes: wait for it to drop
.b:     in   al, dx             ; AL = inp(0x3DA)
        test al, 8              ; bit 3 up ?
        jz   .b                 ;   no: wait for the retrace to begin
        ret                     ; return

;  In C:
;
;      int main(void)
;      {
;          set_mode(0x13);
;          for (;;) {
;              if (sync) retr();
;              memset(screen, 0, 64000);
;              for (i = 0; i < 4; i++) { px = corn[i].x;  py = corn[i].y;  rot();  cxs[i] = rx;  cys[i] = ry; }
;              col = 44;
;              for (i = 0; i < 4; i++) { j = (i + 1) & 3;  line(cxs[i], cys[i], cxs[j], cys[j]); }
;              ang++;
;              if (key_waiting()) { k = get_key();  if (k == 27) break;  if (k == ' ') sync ^= 1; }
;          }
;          set_mode(3); exit(0);
;      }
Boot:   cld                     ; string ops count UP
        mov  ax, 0013h          ; AX = 13h: 320x200, one byte a pixel
        int  10h                ; set_mode(0x13)
        mov  ax, VGA            ; AX = A000h
        mov  es, ax             ; ES = the screen
                                ;
.frame: cmp  word [sync], 0     ; sync == 0 ?
        je   .clear             ;   yes: no waiting
        call Retr               ;   no: retr()
                                ;
.clear: xor  di, di             ; DI = 0: the whole screen, every frame
        xor  ax, ax             ; AX = 0: black, twice
        mov  cx, W*H/2          ; CX = 32000 words
        rep  stosw              ; while (cx--) *es:di++ = ax
                                ;
        ; turn all four corners, straight out of the list
        mov  si, 0              ; i = 0
.corner:mov  bx, si             ; BX = i
        add  bx, bx             ; BX = i * 2
        add  bx, bx             ; BX = i * 4: four bytes to a corner: two words
        mov  ax, [corn+bx]      ; AX = corn[i].x
        mov  [px], ax           ; px = AX
        mov  ax, [corn+bx+2]    ; AX = corn[i].y
        mov  [py], ax           ; py = AX
        push si                 ; keep i: SINQ reads the table through SI, so anything
        call Rot                ; rot():  that calls it must not be keeping something
        pop  si                 ; i back:  there. This cost a silent blank screen.
        mov  bx, si             ; BX = i
        add  bx, bx             ; BX = i * 2: a word to an entry
        mov  ax, [rx]           ; AX = rx
        mov  [cxs+bx], ax       ; cxs[i] = rx
        mov  ax, [ry]           ; AX = ry
        mov  [cys+bx], ax       ; cys[i] = ry
        inc  si                 ; i++
        cmp  si, 4              ; i < 4 ?
        jl   .corner            ;   yes: the next corner
                                ;
        ; and join each one to the next, the last one back to the first
        mov  byte [col], 44     ; col = 44, orange
        mov  si, 0              ; i = 0
.edge:  mov  bx, si             ; BX = i
        add  bx, bx             ; BX = i * 2
        mov  ax, [cxs+bx]       ; AX = cxs[i]
        mov  [lx0], ax          ; lx0 = cxs[i]
        mov  ax, [cys+bx]       ; AX = cys[i]
        mov  [ly0], ax          ; ly0 = cys[i]
        mov  bx, si             ; BX = i
        inc  bx                 ; BX = i + 1
        and  bx, 3              ; j = (i + 1) & 3: 3 comes back round to 0. One AND, again.
        add  bx, bx             ; BX = j * 2
        mov  ax, [cxs+bx]       ; AX = cxs[j]
        mov  [lx1], ax          ; lx1 = cxs[j]
        mov  ax, [cys+bx]       ; AX = cys[j]
        mov  [ly1], ax          ; ly1 = cys[j]
        call Line               ; line()
        inc  si                 ; i++
        cmp  si, 4              ; i < 4 ?
        jl   .edge              ;   yes: the next edge
                                ;
        inc  word [ang]         ; ang++: one step of 256 to the circle, per frame
                                ;
        ; Both jumps back to .frame are hundreds of bytes away, which an 8086
        ; conditional jump cannot reach - so each is inverted and skips over
        ; an unconditional one. Fourth time in this series.
        mov  ah, 1              ; AH = 1: BIOS 16h, is a key waiting?
        int  16h                ; ZF set means no
        jnz  .akey              ; a key: read it
        jmp  .frame             ; none: the next frame
.akey:  mov  ah, 0              ; AH = 0: read it
        int  16h                ; AL = k
        cmp  al, 27             ; escape ?
        je   Bye                ;   yes: leave
        cmp  al, ' '            ; space ?
        je   .flip              ;   yes: flip
        jmp  .frame             ; anything else: the next frame
.flip:  xor  word [sync], 1     ; sync ^= 1: SPACE flips the retrace wait
        jmp  .frame             ; the next frame

Bye:    mov  ax, 0003h          ; AX = 3: back to text
        int  10h                ; set_mode(3)
        mov  ax, 4C00h          ; AH = 4Ch exit, AL = 0 the code
        int  21h                ; exit(0)
