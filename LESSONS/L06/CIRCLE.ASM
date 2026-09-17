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

        jmp  Boot               ; over the routines, to the boot

; ---- sine, from the generated table ----------------------------------------
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

; ---- squash a vertical distance so the shape looks round --------------------
;  213/256 is 0.832, and the pixel is 1.2 times taller than it is wide. One
;  multiply, one shift, and nothing else in this program knows about it.
;  In C:   int sq(int d) { return flat ? d * 213 >> 8 : d; }
Sq:     cmp  word [flat], 0     ; flat == 0 ?
        je   .no                ;   yes: return d as it is
        mov  bx, 213            ; BX = 213
        imul bx                 ; AX = d * 213
        mov  cl, 8              ; CL = 8
        sar  ax, cl             ; AX >>= 8
.no:    ret                     ; return AX

; ---- one pixel, if it is on the screen -------------------------------------
;  In C:   if (pxy >= 0 && pxy < H && pxx >= 0 && pxx < W) screen[pxy * 320 + pxx] = col;
Px:     mov  ax, [pxy]          ; AX = pxy
        cmp  ax, 0              ; pxy < 0 ?
        jl   .out               ;   yes: return
        cmp  ax, H              ; pxy >= 200 ?
        jge  .out               ;   yes: return
        mov  bx, [pxx]          ; BX = pxx
        cmp  bx, 0              ; pxx < 0 ?
        jl   .out               ;   yes: return
        cmp  bx, W              ; pxx >= 320 ?
        jge  .out               ;   yes: return
        mov  cx, W              ; CX = 320
        mul  cx                 ; AX = pxy * 320
        add  ax, bx             ; AX = pxy * 320 + pxx
        mov  di, ax             ; DI = the pixel
        mov  al, [col]          ; AL = col
        stosb                   ; screen[DI++] = col
.out:   ret                     ; return

; ---- one point, offset from the centre -------------------------------------
;  AX = across, DX = down. Both already squashed if they needed to be.
;  In C:   void pp(int across, int down) { pxx = CX_ + across;  pxy = CY_ + down;  px(); }
PP:     add  ax, CX_            ; AX = across + 160
        mov  [pxx], ax          ; pxx = AX
        add  dx, CY_            ; DX = down + 100
        mov  [pxy], dx          ; pxy = DX
        call Px                 ; px()
        ret                     ; return

; ---- the eight the symmetry gives us ---------------------------------------
;  Work out one eighth of a circle and the other seven are the same numbers
;  with the signs changed and the axes swapped. That is why the loop only ever
;  runs while x <= y.
;  In C:
;
;      void p8(void)
;      {
;          qy = sq(oy);  qx = sq(ox);         /* the DOWN distances, squashed */
;          pp( ox,  qy);  pp(-ox,  qy);  pp( ox, -qy);  pp(-ox, -qy);
;          pp( oy,  qx);  pp(-oy,  qx);  pp( oy, -qx);  pp(-oy, -qx);
;      }
P8:     mov  ax, [oy]           ; AX = oy
        call Sq                 ; AX = sq(oy)
        mov  [qy], ax           ; qy = AX
        mov  ax, [ox]           ; AX = ox
        call Sq                 ; AX = sq(ox)
        mov  [qx], ax           ; qx = AX
                                ;
        mov  ax, [ox]           ; across = ox
        mov  dx, [qy]           ; down = qy
        call PP                 ; pp( ox,  qy)
        mov  ax, [ox]           ; across = ox
        neg  ax                 ; across = -ox
        mov  dx, [qy]           ; down = qy
        call PP                 ; pp(-ox,  qy)
        mov  ax, [ox]           ; across = ox
        mov  dx, [qy]           ; down = qy
        neg  dx                 ; down = -qy
        call PP                 ; pp( ox, -qy)
        mov  ax, [ox]           ; across = ox
        neg  ax                 ; across = -ox
        mov  dx, [qy]           ; down = qy
        neg  dx                 ; down = -qy
        call PP                 ; pp(-ox, -qy)
                                ;
        mov  ax, [oy]           ; across = oy: the axes swapped
        mov  dx, [qx]           ; down = qx
        call PP                 ; pp( oy,  qx)
        mov  ax, [oy]           ; across = oy
        neg  ax                 ; across = -oy
        mov  dx, [qx]           ; down = qx
        call PP                 ; pp(-oy,  qx)
        mov  ax, [oy]           ; across = oy
        mov  dx, [qx]           ; down = qx
        neg  dx                 ; down = -qx
        call PP                 ; pp( oy, -qx)
        mov  ax, [oy]           ; across = oy
        neg  ax                 ; across = -oy
        mov  dx, [qx]           ; down = qx
        neg  dx                 ; down = -qx
        call PP                 ; pp(-oy, -qx)
        ret                     ; return

; ---- four horizontal spans, for the filled one -----------------------------
;  The span between two symmetric points is a run of neighbouring bytes, which
;  is lesson 3's free line. A filled circle is not a new idea either.
;  In C:
;
;      void span(void)                       /* row spy, sph either side of the centre */
;      {
;          if (spy < 0 || spy >= H) return;
;          int left = CX_ - sph;  if (left < 0) left = 0;
;          memset(screen + spy * 320 + left, col, sph * 2 + 1);
;      }
Span:   mov  ax, [spy]          ; AX = spy
        cmp  ax, 0              ; spy < 0 ?
        jl   .out               ;   yes: return
        cmp  ax, H              ; spy >= 200 ?
        jge  .out               ;   yes: return
        mov  cx, W              ; CX = 320
        mul  cx                 ; AX = spy * 320
        mov  di, ax             ; DI = the row
        mov  ax, CX_            ; AX = 160
        sub  ax, [sph]          ; left = 160 - sph
        jns  .lok               ; left >= 0 ? fine
        xor  ax, ax             ; left = 0
.lok:   add  di, ax             ; DI += left
        mov  cx, [sph]          ; CX = sph
        add  cx, cx             ; CX = sph * 2
        inc  cx                 ; CX = sph * 2 + 1 pixels
        mov  al, [col]          ; AL = col
        rep  stosb              ; while (cx--) *es:di++ = al
.out:   ret                     ; return

;  In C:
;
;      int main(void)
;      {
;          set_mode(0x13);
;          /* 1 */ for (ang = 0; ang < 256; ang += 4) pp(cos * RAD >> 8, sin * RAD >> 8);  key();
;          /* 2 */ clear(); flat = 0; ring(); key();
;          /* 3 */ clear(); flat = 1; ring(); key();
;          /* 4 */ clear(); flat = 1; disc(); key();
;          set_mode(3); exit(0);
;      }
Boot:   cld                     ; string ops count UP
        mov  ax, 0013h          ; AX = 13h: 320x200, one byte a pixel
        int  10h                ; set_mode(0x13)
        mov  ax, VGA            ; AX = A000h
        mov  es, ax             ; ES = the screen

; ---- 1. sixty-four points off the table ------------------------------------
        mov  byte [col], 44     ; col = 44, orange
        mov  word [ang], 0      ; ang = 0
        mov  cx, 64             ; CX = 64 points
.dots:  push cx                 ; keep the count: SINQ eats CL
        mov  ax, [ang]          ; AX = ang
        add  ax, 64             ; AX = ang + 64: cos
        call SINQ               ; AX = cos(ang) * 256
        mov  bx, RAD            ; BX = 70
        imul bx                 ; AX = cos * 70
        mov  cl, 8              ; CL = 8
        sar  ax, cl             ; AX >>= 8
        mov  [ox], ax           ; ox = across
                                ;
        mov  ax, [ang]          ; AX = ang
        call SINQ               ; AX = sin(ang) * 256
        mov  bx, RAD            ; BX = 70
        imul bx                 ; AX = sin * 70
        mov  cl, 8              ; CL = 8
        sar  ax, cl             ; AX >>= 8
        mov  dx, ax             ; down = AX
        mov  ax, [ox]           ; across = ox
        call PP                 ; pp(across, down)
                                ;
        add  word [ang], 4      ; ang += 4: 256/64 - one step of the table per point
        pop  cx                 ; the count back
        loop .dots              ; while (--cx)
        call Key                ; key()

; ---- 2. every pixel, and it looks like an egg ------------------------------
        call Clear              ; clear()
        mov  word [flat], 0     ; flat = 0
        call Ring               ; ring()
        call Key                ; key()

; ---- 3. the same circle, squashed, and NOW it looks round ------------------
        call Clear              ; clear()
        mov  word [flat], 1     ; flat = 1
        call Ring               ; ring()
        call Key                ; key()

; ---- 4. filled ------------------------------------------------------------
        call Clear              ; clear()
        mov  word [flat], 1     ; flat = 1
        call Disc               ; disc()
        call Key                ; key()

Bye:    mov  ax, 0003h          ; AX = 3: back to text
        int  10h                ; set_mode(3)
        mov  ax, 4C00h          ; AH = 4Ch exit, AL = 0 the code
        int  21h                ; exit(0)

;  In C:   memset(screen, 0, 64000);
Clear:  xor  di, di             ; DI = 0
        xor  ax, ax             ; AX = 0: black, twice
        mov  cx, W*H/2          ; CX = 32000 words
        rep  stosw              ; while (cx--) *es:di++ = ax
        ret                     ; return

;  In C:   void key(void) { if (get_key() == 27) bye(); }
Key:    mov  ah, 0              ; AH = 0: BIOS 16h, wait for a key
        int  16h                ; AL = the character
        cmp  al, 27             ; escape ?
        jne  .stay              ;   no: return
        jmp  Bye                ;   yes: leave
.stay:  ret                     ; return

; ---- the midpoint circle ---------------------------------------------------
;  x starts at 0 and y at the radius, and a decision variable says which of
;  the two candidate pixels is nearer the true circle. Every step is an add
;  or a shift. There is no multiply, no divide, no square root and no sine.
;  In C:
;
;      void ring(void)
;      {
;          ox = 0;  oy = RAD;  dv = 3 - 2 * RAD;
;          while (ox <= oy) {
;              p8();
;              if (dv < 0)  dv += 4 * ox + 6;
;              else       { dv += 4 * (ox - oy) + 10;  oy--; }
;              ox++;
;          }
;      }
Ring:   mov  word [ox], 0       ; ox = 0
        mov  ax, RAD            ; AX = 70
        mov  [oy], ax           ; oy = 70
        add  ax, ax             ; AX = 2r
        neg  ax                 ; AX = -2r
        add  ax, 3              ; AX = 3 - 2r: d = 3 - 2r
        mov  [dv], ax           ; dv = AX
.l:     mov  ax, [ox]           ; AX = ox
        cmp  ax, [oy]           ; ox > oy ?
        jg   .done              ;   yes: the eighth is done
        call P8                 ; p8()
        mov  ax, [dv]           ; AX = dv
        cmp  ax, 0              ; dv < 0 ?
        jge  .out               ;   no: the other branch
        mov  ax, [ox]           ; AX = ox: d += 4x + 6
        add  ax, ax             ; AX = 2x
        add  ax, ax             ; AX = 4x
        add  ax, 6              ; AX = 4x + 6
        add  [dv], ax           ; dv += AX
        jmp  .on                ; and on
.out:   mov  ax, [ox]           ; AX = ox: d += 4(x - y) + 10
        sub  ax, [oy]           ; AX = x - y
        add  ax, ax             ; AX = 2(x - y)
        add  ax, ax             ; AX = 4(x - y)
        add  ax, 10             ; AX = 4(x - y) + 10
        add  [dv], ax           ; dv += AX
        dec  word [oy]          ; oy--
.on:    inc  word [ox]          ; ox++
        jmp  .l                 ; the next step
.done:  ret                     ; return

; ---- the same walk, but filling as it goes ---------------------------------
;  In C:
;
;      void disc(void)                      /* ring(), but spans instead of dots */
;      {
;          ox = 0;  oy = RAD;  dv = 3 - 2 * RAD;
;          while (ox <= oy) {
;              qy = sq(oy);  qx = sq(ox);
;              sph = ox;  spy = CY_ + qy;  span();  spy = CY_ - qy;  span();
;              sph = oy;  spy = CY_ + qx;  span();  spy = CY_ - qx;  span();
;              if (dv < 0)  dv += 4 * ox + 6;
;              else       { dv += 4 * (ox - oy) + 10;  oy--; }
;              ox++;
;          }
;      }
Disc:   mov  word [ox], 0       ; ox = 0
        mov  ax, RAD            ; AX = 70
        mov  [oy], ax           ; oy = 70
        add  ax, ax             ; AX = 2r
        neg  ax                 ; AX = -2r
        add  ax, 3              ; AX = 3 - 2r
        mov  [dv], ax           ; dv = AX
.l:     mov  ax, [ox]           ; AX = ox
        cmp  ax, [oy]           ; ox <= oy ?
        jle  .go                ;   yes: go on.  The body below is 135 bytes, and a
        jmp  .done              ;   no: done.    conditional jump reaches 127
.go:    mov  ax, [oy]           ; AX = oy
        call Sq                 ; AX = sq(oy)
        mov  [qy], ax           ; qy = AX
        mov  ax, [ox]           ; AX = ox
        call Sq                 ; AX = sq(ox)
        mov  [qx], ax           ; qx = AX
                                ;
        mov  ax, [ox]           ; AX = ox
        mov  [sph], ax          ; sph = ox
        mov  ax, CY_            ; AX = 100
        add  ax, [qy]           ; AX = 100 + qy
        mov  [spy], ax          ; spy = AX
        call Span               ; span(): below the middle
        mov  ax, CY_            ; AX = 100
        sub  ax, [qy]           ; AX = 100 - qy
        mov  [spy], ax          ; spy = AX
        call Span               ; span(): above it
                                ;
        mov  ax, [oy]           ; AX = oy: the axes swapped
        mov  [sph], ax          ; sph = oy
        mov  ax, CY_            ; AX = 100
        add  ax, [qx]           ; AX = 100 + qx
        mov  [spy], ax          ; spy = AX
        call Span               ; span()
        mov  ax, CY_            ; AX = 100
        sub  ax, [qx]           ; AX = 100 - qx
        mov  [spy], ax          ; spy = AX
        call Span               ; span()
                                ;
        mov  ax, [dv]           ; AX = dv
        cmp  ax, 0              ; dv < 0 ?
        jge  .out               ;   no: the other branch
        mov  ax, [ox]           ; AX = ox
        add  ax, ax             ; AX = 2x
        add  ax, ax             ; AX = 4x
        add  ax, 6              ; AX = 4x + 6
        add  [dv], ax           ; dv += AX
        jmp  .on                ; and on
.out:   mov  ax, [ox]           ; AX = ox
        sub  ax, [oy]           ; AX = x - y
        add  ax, ax             ; AX = 2(x - y)
        add  ax, ax             ; AX = 4(x - y)
        add  ax, 10             ; AX = 4(x - y) + 10
        add  [dv], ax           ; dv += AX
        dec  word [oy]          ; oy--
.on:    inc  word [ox]          ; ox++
        jmp  .l                 ; the next step
.done:  ret                     ; return

include 'SINT.INC'              ; lesson 5's sixty-five numbers

ang     dw 0                    ; frame 1: the angle round the table
ox      dw 0                    ; the midpoint walk: x across ...
oy      dw 0                    ; ... and y down, from the centre
qx      dw 0                    ; the same two, squashed
qy      dw 0
dv      dw 0                    ; the decision variable
flat    dw 0                    ; 1 = squash, 0 = the honest egg
pxx     dw 0                    ; the pixel Px is asked for
pxy     dw 0
sph     dw 0                    ; a span: half its width ...
spy     dw 0                    ; ... and its row
col     db 0                    ; the colour everything is drawn in
