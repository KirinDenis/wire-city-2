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

        jmp  Boot               ; over the routines, to the boot

; ---- sine, from the table --------------------------------------------------
;  in:  AX = angle, any value at all
;  out: AX = sin(angle) * 256, from -256 to +256
;
;  The table holds only the first quarter. The other three are the same
;  sixty-five numbers read backwards, or negated, or both - which is the
;  whole reason for storing a quarter and not a circle.
;  In C:
;
;      int sinq(int a)                       /* sin(a) * 256, a in 256ths of a turn */
;      {
;          int q = (a & 255) >> 6;           /* which quarter, 0..3       */
;          int i = a & 63;                   /* how far into it           */
;          if (q == 1 || q == 3) i = 64 - i; /* odd quarters run backwards */
;          return q < 2 ? SINT[i] : -SINT[i];
;      }
SINQ:   and  ax, 255            ; a &= 255: one AND, and any angle is in range
        mov  bx, ax             ; BX = a
        mov  cl, 6              ; CL = 6
        shr  bx, cl             ; q = a >> 6: BX = which quarter, 0..3
        and  ax, 63             ; i = a & 63: AX = how far into it, 0..63
        cmp  bx, 1              ; q == 1 ?
        je   .back              ;   yes: backwards
        cmp  bx, 3              ; q == 3 ?
        je   .back              ;   yes: backwards
        jmp  .have              ; else: forwards
.back:  mov  dx, 64             ; DX = 64: quarters 1 and 3 read the table backwards
        sub  dx, ax             ; DX = 64 - i
        mov  ax, dx             ; i = 64 - i
.have:  add  ax, ax             ; AX = i * 2: two bytes to an entry
        mov  si, ax             ; SI = i * 2
        mov  ax, [SINT+si]      ; AX = SINT[i]
        cmp  bx, 2              ; q < 2 ?
        jb   .done              ;   yes: quarters 0 and 1 are above the axis
        neg  ax                 ; AX = -SINT[i]: 2 and 3 below it
.done:  ret                     ; return AX

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
        add  ax, 64             ; AX = ang + 64: cos(a) is sin(a + a quarter). One add.
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
;  [lx0],[ly0] -> [lx1],[ly1], colour in [col].  Bresenham: the whole thing
;  runs on adds, subtracts and comparisons. Not one multiply in the loop.
;  In C:
;
;      void line(void)                          /* lx0,ly0 -> lx1,ly1 in col */
;      {
;          ddx = abs(lx1 - lx0);  sx = lx1 >= lx0 ? 1 : -1;
;          ddy = abs(ly1 - ly0);  sy = ly1 >= ly0 ? 1 : -1;
;          ferr = ddx - ddy;
;          for (;;) {
;              screen[ly0 * 320 + lx0] = col;
;              if (lx0 == lx1 && ly0 == ly1) return;
;              int e2 = ferr * 2;
;              if (e2 > -ddy) { ferr -= ddy;  lx0 += sx; }
;              if (e2 <  ddx) { ferr += ddx;  ly0 += sy; }
;          }
;      }
Line:   mov  ax, [lx1]          ; AX = lx1
        sub  ax, [lx0]          ; AX = lx1 - lx0
        mov  word [sx], 1       ; sx = 1: which way along x
        jns  .xok               ; not negative ? fine
        neg  ax                 ; AX = -AX
        mov  word [sx], -1      ; sx = -1
.xok:   mov  [ddx], ax          ; ddx = AX: how far, always positive
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
        mov  [ferr], ax         ; ferr = AX: the error starts as the difference
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
.step:  mov  ax, [ferr]         ; AX = ferr
        add  ax, ax             ; AX = ferr * 2: e2 = ferr * 2, which is one shift
        mov  bx, ax             ; e2 = AX
                                ;
        mov  ax, [ddy]          ; AX = ddy
        neg  ax                 ; AX = -ddy
        cmp  bx, ax             ; e2 > -ddy ?
        jle  .noX               ;   no: x stays
        mov  ax, [ferr]         ; AX = ferr
        sub  ax, [ddy]          ; AX = ferr - ddy
        mov  [ferr], ax         ; ferr = AX
        mov  ax, [lx0]          ; AX = lx0
        add  ax, [sx]           ; AX = lx0 + sx
        mov  [lx0], ax          ; lx0 = AX
.noX:   cmp  bx, [ddx]          ; e2 < ddx ?
        jge  .plot              ;   no: y stays, plot the next
        mov  ax, [ferr]         ; AX = ferr
        add  ax, [ddx]          ; AX = ferr + ddx
        mov  [ferr], ax         ; ferr = AX
        mov  ax, [ly0]          ; AX = ly0
        add  ax, [sy]           ; AX = ly0 + sy
        mov  [ly0], ax          ; ly0 = AX
        jmp  .plot              ; plot the next
.done:  ret                     ; return

; ---- wait for the beam to go home ------------------------------------------
;  Bit 3 of port 3DAh is up while the card is between pictures. Draw then and
;  nobody sees the drawing - draw at any other moment and they see half of it.
;  In C:   while (inp(0x3DA) & 8) ;  while (!(inp(0x3DA) & 8)) ;
Retr:   mov  dx, 3DAh           ; DX = 3DAh: the status port
.a:     in   al, dx             ; AL = inp(0x3DA): first make sure we are NOT in one already,
        test al, 8              ; bit 3 up ?  or we would go early and gain nothing
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
;              px = -R; py = -R; rot(); ax0 = rx; ay0 = ry;     /* four corners */
;              px =  R; py = -R; rot(); ax1 = rx; ay1 = ry;
;              px =  R; py =  R; rot(); ax2 = rx; ay2 = ry;
;              px = -R; py =  R; rot(); ax3 = rx; ay3 = ry;
;              col = 44;
;              for (e = edges, n = 4; n--; e += 4)               /* four edges  */
;                  { lx0 = *e[0]; ly0 = *e[1]; lx1 = *e[2]; ly1 = *e[3]; line(); }
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
        ; the four corners, each one turned by the same angle
        mov  word [px], -R      ; px = -R: top left
        mov  word [py], -R      ; py = -R
        call Rot                ; rot()
        mov  ax, [rx]           ; AX = rx
        mov  [ax0], ax          ; ax0 = rx
        mov  ax, [ry]           ; AX = ry
        mov  [ay0], ax          ; ay0 = ry
                                ;
        mov  word [px], R       ; px = R: top right
        mov  word [py], -R      ; py = -R
        call Rot                ; rot()
        mov  ax, [rx]           ; AX = rx
        mov  [ax1], ax          ; ax1 = rx
        mov  ax, [ry]           ; AX = ry
        mov  [ay1], ax          ; ay1 = ry
                                ;
        mov  word [px], R       ; px = R: bottom right
        mov  word [py], R       ; py = R
        call Rot                ; rot()
        mov  ax, [rx]           ; AX = rx
        mov  [ax2], ax          ; ax2 = rx
        mov  ax, [ry]           ; AX = ry
        mov  [ay2], ax          ; ay2 = ry
                                ;
        mov  word [px], -R      ; px = -R: bottom left
        mov  word [py], R       ; py = R
        call Rot                ; rot()
        mov  ax, [rx]           ; AX = rx
        mov  [ax3], ax          ; ax3 = rx
        mov  ax, [ry]           ; AX = ry
        mov  [ay3], ax          ; ay3 = ry
                                ;
        mov  byte [col], 44     ; col = 44, orange
        mov  si, edges          ; e = edges
        mov  cx, 4              ; n = 4
.edge:  push cx                 ; keep n
        push si                 ; keep e
        lodsw                   ; AX = *e++: the address of a corner's x
        mov  bx, ax             ; BX = that address
        mov  ax, [bx]           ; AX = the corner's x
        mov  [lx0], ax          ; lx0 = AX
        lodsw                   ; AX = *e++: the address of its y
        mov  bx, ax             ; BX = that address
        mov  ax, [bx]           ; AX = the corner's y
        mov  [ly0], ax          ; ly0 = AX
        lodsw                   ; AX = *e++: the next corner's x
        mov  bx, ax             ; BX = that address
        mov  ax, [bx]           ; AX = its x
        mov  [lx1], ax          ; lx1 = AX
        lodsw                   ; AX = *e++: and its y
        mov  bx, ax             ; BX = that address
        mov  ax, [bx]           ; AX = its y
        mov  [ly1], ax          ; ly1 = AX
        call Line               ; line()
        pop  si                 ; e back
        add  si, 8              ; e += 4 words: the next edge
        pop  cx                 ; n back
        loop .edge              ; while (--n)
                                ;
        inc  word [ang]         ; ang++: one step of 256 to the circle, every frame

        ; Both jumps back to .frame are two hundred bytes away, which an 8086
        ; conditional jump cannot reach - so each one is inverted and skips
        ; over an unconditional jump instead. Third time this has come up in
        ; the series; ENGINE\E_8086.INC does it for the games automatically.
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

; ---- the four edges, as pointers to the corners we just worked out ---------
;  In C:   int *edges[4][4] = { {&ax0,&ay0,&ax1,&ay1}, ... };
edges   dw ax0,ay0,ax1,ay1      ; top
        dw ax1,ay1,ax2,ay2      ; right
        dw ax2,ay2,ax3,ay3      ; bottom
        dw ax3,ay3,ax0,ay0      ; left, back to the first corner

include 'SINT.INC'              ; the sixty-five numbers, made by MKSIN.C

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
ferr     dw 0                   ; the running error
ax0     dw 0                    ; the four corners, turned: where they landed
ay0     dw 0
ax1     dw 0
ay1     dw 0
ax2     dw 0
ay2     dw 0
ax3     dw 0
ay3     dw 0
