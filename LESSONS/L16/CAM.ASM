; ============================================================================
;  CAM.ASM - Lesson 10. The view matrix and the projection matrix.
;
;      FASM CAM.ASM CAM.COM
;
;      1  the cube        one cube, seen from a camera at the origin
;      2  move the CUBE   its model placement changes. It slides right.
;      3  move the CAMERA its view matrix changes. The cube slides right.
;      4  both at once    one answer in grey, the other in white, and a red
;                         dot promised on every corner they disagree about.
;                         THERE ARE NONE. The picture cannot tell you which
;                         of the two happened.
;      5  turn the CUBE   it spins where it stands
;      6  turn the CAMERA it swings across the glass and leaves - and this
;                         is NOT the same thing. Read stage 6's comment.
;      7  fly it          the arrows walk and turn the camera, ESC ends it
;
;  THREE SPACES AND TWO MATRICES, and the names are the ones everybody
;  else uses. Learn them here and every graphics book you ever open will
;  be talking about the same things:
;
;      MODEL SPACE    the cube's own eight corners, at plus and minus
;                     eighteen, measured from its own centre - lesson 0E
;        | the MODEL matrix: where the cube is put, and how it is turned
;      WORLD SPACE    the same corners, placed somewhere
;        | the VIEW matrix: where it is all seen from
;      VIEW SPACE     the same corners again, measured from the EYE
;        | the PROJECTION: the divide of lesson 0F
;      THE GLASS      two numbers, and they go on the screen
;
;  THE VIEW MATRIX IS THE INVERSE OF THE CAMERA'S PLACEMENT. That is the
;  classical statement and it is exactly what the code does:
;
;      view = R(-yaw) x (world - camera)
;
;  To LOOK from c turned by a, you SUBTRACT c and turn by MINUS a. Placing
;  a camera and looking through it are inverses of one another, and that is
;  the whole of why the signs are flipped below.
;
;  THE PROJECTION IS A MATRIX TOO, in every engine you will meet - a fourth
;  row that copies z into w, and a divide by w at the very end. We do not
;  write it that way here, and it is worth one sentence why: the matrix
;  form exists so that a LONG CHAIN of transforms can be multiplied
;  together first and the divide paid once at the end. We have no chain. We
;  have one divide, from last lesson, done where it happens. Same
;  arithmetic, fewer ceremonies.
;
;  THE ONE FACT THIS LESSON HANDS OVER: A PICTURE CANNOT TELL YOU WHETHER
;  THE CUBE MOVED OR THE CAMERA DID. Stage 2 slides the cube. Stage 3
;  leaves the cube alone and slides the camera the other way. Stage 4 draws
;  both answers on top of each other and hunts for a pixel of difference.
;  There is none, and there cannot be: only where the eye is RELATIVE to
;  the cube decides the picture, and two ways of arranging the same
;  relation are the same arrangement.
;
;  AND ONE PLACE THE TRICK STOPS, because it would be dishonest to let you
;  generalise it: TURNING is not symmetric. Turning the cube spins it where
;  it stands. Turning the camera swings the whole picture about the EYE,
;  which is somewhere else entirely. Stages 5 and 6 show both, and they do
;  not look alike. The equivalence is about WHERE things are, not about
;  which way they face.
;
;  Owlos - legacy software modernization - https://owlos.sk
; ============================================================================
format binary as 'com'
        org  100h

VGA     = 0A000h                ; the graphics screen: 320x200, no depth
W       = 320
H       = 200

CX0     = 160                   ; where the eye's axis meets the glass, and
CY0     = 100                   ;  it is nailed there for ever

DEYE    = 270                   ; the eye to the glass - lesson 0F's d, and
                                ;  the same sixty degrees of field
ZNEAR   = 40                    ; the table's first live row
ZFAR    = 255                   ; ...and its last: a byte has no more
HOMEZ   = 170                   ; where the cube stands to begin with
MYAW0   = 24                    ; ...and how it is turned when it rests -
MPITCH  = 20                    ;  because a cube seen face on is a square
                                ;  and teaches nobody anything. The pitch
                                ;  never changes; it is part of the MODEL
                                ;  matrix and its whole job is to let you
                                ;  see that this is a box.
SWING   = 44                    ; how far stages 2, 3 and 4 slide
NE      = 12                    ; twelve joins, since lesson 0E

EDGEC   = 15                    ; an edge is white
OTHERC  = 8                     ; the OTHER answer, in stage 4: grey
DIFFC   = 12                    ; a corner the two answers disagree on: red
AXISC   = 14                    ; the eye's axis: yellow

STEPF   = 9                     ; how far one key walks you
STEPT   = 3                     ; ...and how far it turns you. Small: with
                                ;  one cube out there and nothing else,
                                ;  turning is how you lose it.

        jmp  Boot               ; over the routines, to the boot at the bottom

; ============================================================================
;  Rot2 - lesson 12's matrix, GROWN TO WORDS.
;
;  in:  AL = the angle, 0..255 - the whole circle in one byte, still
;       [pa],[pb] = a pair of coordinates, and these are WORDS now
;  out: [pa],[pb] turned
;
;  A corner a hundred and seventy units away does not fit in a byte, so the
;  pair are words, the sine is widened with CBW, and IMUL WORD does the
;  multiplying. The product still fits AX by itself - two hundred and fifty
;  five times a hundred and twenty seven is thirty two thousand three
;  hundred and eighty five, just under the limit - so DX holds only the
;  sign and we ignore it. THAT IS A BUDGET, NOT A COINCIDENCE: keep every
;  coordinate under two hundred and fifty eight or this routine overflows
;  in silence, and the numbers below are chosen to fit it.
;
;  This one routine is now doing both matrices. Called with the cube's own
;  yaw it is the MODEL rotation; called with the camera's yaw NEGATED it is
;  the VIEW rotation. Same four multiplies either way.
; ============================================================================
;  In C:
;
;      void rot2(int a)                     /* turns the pair (pa, pb) */
;      {
;          int s = SINTAB[a];               /* sin * 127, -127..127    */
;          int c = SINTAB[(a + 64) & 255];  /* cos = sin a quarter on  */
;          int na = (pa * c - pb * s) >> 7; /* the matrix, row one     */
;          int nb = (pa * s + pb * c) >> 7; /*             row two     */
;          pa = na;  pb = nb;               /* both from the OLD pa!   */
;      }
;
;  The `na` is the whole trap of lesson 12: row two needs the old pa, so
;  row one's answer is parked in t1 until row two is done.
Rot2:   push ax                 ; keep a
        mov  bx, SINTAB         ; BX = the table
        xlatb                   ; AL = SINTAB[a]: sin(a), -127..127
        cbw                     ; AX = AL, sign and all: the coordinates
        mov  [tsin], ax         ; tsin = s                  are words now
        pop  ax                 ; AL = a
        add  al, 64             ; AL = a + 64: cos(a) = sin(a + a quarter)
        xlatb                   ; AL = SINTAB[a + 64]  (AL wraps by itself)
        cbw                     ; AX = AL
        mov  [tcos], ax         ; tcos = c
        mov  ax, [tcos]         ; AX = c
        imul word [pa]          ; AX = pa * c   - fits AX; DX is only the sign
        mov  [t2], ax           ; t2 = pa * c
        mov  ax, [tsin]         ; AX = s
        imul word [pb]          ; AX = pb * s
        mov  dx, [t2]           ; DX = pa * c
        sub  dx, ax             ; DX = pa * c - pb * s     in 128ths
        mov  cl, 7              ; CL = 7
        sar  dx, cl             ; DX >>= 7: / 128 as a SHIFT, since lesson 10
        mov  [t1], dx           ; t1 = na   PARKED - nb still wants the OLD pa
        mov  ax, [tsin]         ; AX = s
        imul word [pa]          ; AX = pa * s
        mov  [t2], ax           ; t2 = pa * s
        mov  ax, [tcos]         ; AX = c
        imul word [pb]          ; AX = pb * c
        add  ax, [t2]           ; AX = pa * s + pb * c
        sar  ax, cl             ; AX >>= 7
        mov  [pb], ax           ; pb = nb
        mov  ax, [t1]           ; AX = na
        mov  [pa], ax           ; pa = na   ...and only now may it land
        ret                     ; return

; ============================================================================
;  ProjMul - one coordinate through the projection, with no divide.
;
;  in:  AX = a view-space coordinate, [rcp] = d/z out of RECIP, in 256ths
;  out: AX = where it lands, measured from the eye's axis
;
;  IMUL WORD leaves a THIRTY-TWO bit product in DX and AX, and here it
;  really is thirty-two bits. We want it divided by two hundred and fifty
;  six - and nothing needs shifting eight times, because
;
;      a 32-bit product shifted right by eight IS its middle two bytes.
;
;  AL takes AH, AH takes DL, and that is the divide: two MOVs, four clocks,
;  exact. It works because the answer fits sixteen bits; if it did not, DH
;  would hold something and these two MOVs would throw it away in silence.
; ============================================================================
;  In C:   int projmul(int v) { return ((long)v * rcp) >> 8; }
ProjMul:
        imul word [rcp]         ; DX:AX = v * rcp   (rcp = d/z * 256)
        mov  al, ah             ; AL = AH   \  the middle two bytes of the
        mov  ah, dl             ; AH = DL   /  product ARE the product / 256
        ret                     ; return AX

; ============================================================================
;  Xform - the whole chain, once per corner, and every step has a name.
;
;  out: [ok] = 1 if the cube may be drawn, 0 if it was dropped
;       sx, sy = its eight corners on the glass
;
;      MODEL     turn the corner by the cube's own yaw, then add where the
;                cube stands. That pair of operations IS the model matrix.
;      VIEW      subtract where the camera stands, then turn by MINUS the
;                camera's yaw. That pair IS the view matrix, and both
;                halves are inverted because looking is the inverse of
;                placing.
;      PROJECT   lesson 0F's divide, through the table.
;
;  Stage 2 changes [objx]. Stage 3 changes [camx]. Nothing else differs,
;  and stage 4 is the proof that nothing else needs to.
; ============================================================================
;  In C:
;
;      int xform(void)                       /* 1 = draw the cube, 0 = drop it */
;      {
;          for (int i = 0; i < 8; i++) {
;              int x = VERTS[i*3], y = VERTS[i*3+1], z = VERTS[i*3+2];
;              /* MODEL: the cube's own turn, then its place */
;              pa = x;  pb = z;  rot2(objyaw);   x = pa;  z = pb;   /* about Y */
;              pa = y;  pb = z;  rot2(MPITCH);   y = pa;  z = pb;   /* about X */
;              /* VIEW: minus the camera's place, then MINUS its turn */
;              vx = x + objx - camx;  vy = y + objy - camy;  vz = z + objz - camz;
;              pa = vx; pb = vz;  rot2(-camyaw);  vx = pa;  vz = pb;
;              /* the near plane, as a test - and the far one */
;              if (vz < ZNEAR || vz > ZFAR) return 0;
;              /* PROJECT: lesson 0F, through the table */
;              rcp = RECIP[vz];
;              sx[i] = CX0 + projmul(vx);
;              sy[i] = CY0 - projmul(vy);       /* paper y up, beam down */
;              /* off the glass: drop the whole cube - the crude answer */
;              if (sx[i] < 4 || sx[i] > W-5 || sy[i] < 4 || sy[i] > H-5) return 0;
;          }
;          return 1;
;      }
;
;  SI walks VERTS three bytes a corner, DI walks sx/sy two bytes a corner,
;  and every call pushes both because Rot2 and ProjMul use the registers.
Xform:  mov  byte [ok], 1       ; ok = 1: innocent until a corner drops
        mov  si, VERTS          ; SI = &VERTS[0]
        xor  di, di             ; DI = 0: i * 2, the index into sx/sy
        mov  cx, 8              ; CX = 8 corners
.v:     push cx                 ; keep the count across the calls

        mov  al, [si]           ; AL = x    ---- MODEL: turn the cube ------
        cbw                     ; AX = x
        mov  [pa], ax           ; pa = x
        mov  al, [si+2]         ; AL = z
        cbw                     ; AX = z
        mov  [pb], ax           ; pb = z
        mov  al, [objyaw]       ; AL = objyaw: about Y, so the pair is (x, z)
        push si                 ; keep SI and DI: Rot2 uses BX, CX, DX, AX
        push di                 ; keep SI and DI: Rot2/ProjMul use the registers
        call Rot2               ; rot2(objyaw)
        pop  di                 ; DI back
        pop  si                 ; SI back
        mov  ax, [pa]           ; AX = pa
        mov  [mx], ax           ; mx = x turned
        mov  ax, [pb]           ; AX = pb
        mov  [mz], ax           ; mz = z turned
        mov  al, [si+1]         ; AL = y: ...and its fixed tilt, about X, so
        cbw                     ; AX = y   the pair is (y, z). Two turns and
        mov  [pa], ax           ; pa = y   a move: THAT IS THE MODEL MATRIX,
        mov  ax, [mz]           ; AX = mz  written out
        mov  [pb], ax           ; pb = mz
        mov  al, MPITCH         ; AL = MPITCH
        push si                 ; keep SI and DI: Rot2/ProjMul use the registers
        push di                 ; (the pair)
        call Rot2               ; rot2(MPITCH)
        pop  di                 ; DI back
        pop  si                 ; SI back
        mov  ax, [pa]           ; AX = pa
        mov  [my], ax           ; my = y turned
        mov  ax, [pb]           ; AX = pb
        mov  [mz], ax           ; mz = z turned again

        mov  ax, [mx]           ; AX = mx   ---- ...and put it where it stands
        add  ax, [objx]         ; AX = mx + objx
        sub  ax, [camx]         ; AX = mx + objx - camx   ---- VIEW: minus
        mov  [vx], ax           ; vx = AX                  where the camera is
        mov  ax, [my]           ; AX = my
        add  ax, [objy]         ; AX = my + objy
        sub  ax, [camy]         ; AX = my + objy - camy
        mov  [vy], ax           ; vy = AX
        mov  ax, [mz]           ; AX = mz
        add  ax, [objz]         ; AX = mz + objz
        sub  ax, [camz]         ; AX = mz + objz - camz
        mov  [vz], ax           ; vz = AX

        mov  ax, [vx]           ; AX = vx   ---- ...and turn by MINUS the yaw
        mov  [pa], ax           ; pa = vx
        mov  ax, [vz]           ; AX = vz
        mov  [pb], ax           ; pb = vz
        mov  al, [camyaw]       ; AL = camyaw
        neg  al                 ; AL = -camyaw. THE INVERSE OF A TURN, ENTIRE.
                                ;  One byte: transpose a rotation - flip it
                                ;  about its diagonal - and you have the turn
                                ;  back the other way. No divide, no determinant
        push si                 ; keep SI and DI: Rot2/ProjMul use the registers
        push di                 ; (the pair)
        call Rot2               ; rot2(-camyaw)
        pop  di                 ; DI back
        pop  si                 ; SI back
        mov  ax, [pa]           ; AX = pa
        mov  [vx], ax           ; vx = AX
        mov  ax, [pb]           ; AX = pb
        mov  [vz], ax           ; vz = AX

        cmp  word [vz], ZNEAR   ; vz < ZNEAR ?  ---- the near plane, as a TEST:
        jl   .drop              ;   yes: drop     lesson 0F's promise, now that
        cmp  word [vz], ZFAR    ; vz > ZFAR ?     the camera can move, has to
        jg   .drop              ;   yes: drop     be an IF

        mov  bx, [vz]           ; BX = vz    ---- PROJECT: lesson 0F, via RECIP
        add  bx, bx             ; BX = vz * 2: one word a row
        mov  ax, [RECIP+bx]     ; AX = RECIP[vz]
        mov  [rcp], ax          ; rcp = AX
        mov  ax, [vx]           ; AX = vx
        push si                 ; keep SI and DI: Rot2/ProjMul use the registers
        push di                 ; (the pair)
        call ProjMul            ; AX = vx * rcp / 256
        pop  di                 ; DI back
        pop  si                 ; SI back
        add  ax, CX0            ; AX += CX0
        mov  [sx+di], ax        ; sx[i] = AX
        mov  ax, [vy]           ; AX = vy
        push si                 ; keep SI and DI: Rot2/ProjMul use the registers
        push di                 ; (the pair)
        call ProjMul            ; AX = vy * rcp / 256
        pop  di                 ; DI back
        pop  si                 ; SI back
        mov  bx, CY0            ; BX = CY0
        sub  bx, ax             ; BX = CY0 - AX: THE MINUS, paper y up, beam down
        mov  [sy+di], bx        ; sy[i] = BX

        mov  ax, [sx+di]        ; AX = sx[i]   ---- and off the glass is dropped
        cmp  ax, 4              ; sx < 4 ?        too, because Line does not
        jl   .drop              ;   yes: drop     clip, and clipping is a lesson
        cmp  ax, W-5            ; sx > 315 ?      of its own this course has
        jg   .drop              ;   yes: drop     not reached. We drop the WHOLE
        mov  ax, [sy+di]        ; AX = sy[i]      cube - crude, visible, and
        cmp  ax, 4              ; sy < 4 ?        honest about being the crude
        jl   .drop              ;   yes: drop     answer
        cmp  ax, H-5            ; sy > 195 ?
        jg   .drop              ;   yes: drop

        add  si, 3              ; SI += 3: the next corner's bytes
        add  di, 2              ; DI += 2: the next corner's word
        pop  cx                 ; CX = the count
        dec  cx                 ; CX--   LOOP reaches one signed byte back and
        jz   .done              ; done?   this body is longer than that. Count
        jmp  .v                 ;   no: next corner   by hand, let a JMP reach
.done:  ret                     ; return 1  (ok is still 1)
.drop:  mov  byte [ok], 0       ; ok = 0
        pop  cx                 ; the count, off the stack
        ret                     ; return 0

; ---- Keep: park the eight corners just computed as the OTHER answer -----
;  In C:   for (i = 0; i < 8; i++) { sxd[i] = sx[i];  syd[i] = sy[i]; }
Keep:   xor  di, di             ; DI = 0  (i * 2)
        mov  cx, 8              ; CX = 8 corners
.c:     mov  ax, [sx+di]        ; AX = sx[i]
        mov  [sxd+di], ax       ; sxd[i] = AX
        mov  ax, [sy+di]        ; AX = sy[i]
        mov  [syd+di], ax       ; syd[i] = AX
        add  di, 2              ; i++
        loop .c                 ; 8 times
        ret                     ; return

; ---- the twelve edges, from whichever pair [esrc] points at ------------
;  The y table sits sixteen bytes after the x table, so one routine draws
;  either answer - lesson 0F's pointer, kept.
;  In C:
;
;      void edges(void)                   /* esrc points at sx or at sxd */
;      {
;          int *X = esrc, *Y = esrc + 8;  /* the y table is 16 bytes on   */
;          for (int e = 0; e < NE; e++) {
;              int a = EDGES[e*2], b = EDGES[e*2+1];
;              p0x = X[a];  p0y = Y[a];
;              p1x = X[b];  p1y = Y[b];
;              col = ecol;
;              line();
;          }
;      }
Edges:  mov  si, EDGES          ; SI = &EDGES[0]
        mov  cx, NE             ; CX = 12 joins
.e:     push cx                 ; keep the count
        mov  bx, [esrc]         ; BX = X, whichever table esrc points at
        mov  al, [si]           ; AL = a, the first corner's number
        xor  ah, ah             ; AX = a
        add  ax, ax             ; AX = a * 2: words
        add  bx, ax             ; BX = &X[a]
        mov  ax, [bx]           ; AX = X[a]
        mov  [p0x], ax          ; p0x = X[a]
        mov  ax, [bx+16]        ; AX = Y[a]: the y table sits 16 bytes after
        mov  [p0y], ax          ; p0y = Y[a]
        mov  bx, [esrc]         ; BX = X again
        mov  al, [si+1]         ; AL = b, the second corner's number
        xor  ah, ah             ; AX = b
        add  ax, ax             ; AX = b * 2
        add  bx, ax             ; BX = &X[b]
        mov  ax, [bx]           ; AX = X[b]
        mov  [p1x], ax          ; p1x = X[b]
        mov  ax, [bx+16]        ; AX = Y[b]
        mov  [p1y], ax          ; p1y = Y[b]
        mov  al, [ecol]         ; AL = ecol
        mov  [col], al          ; col = ecol
        push si                 ; keep SI: Line uses it? No - but it uses
        call Line               ; line()    everything else, and the rule is
        pop  si                 ;           to keep what the loop needs
        add  si, 2              ; SI += 2: the next pair
        pop  cx                 ; the count
        loop .e                 ; 12 times
        ret                     ; return

; ---- Differ: a red dot on every corner the two answers disagree about --
;  More than ONE pixel apart. Two routes through integer arithmetic will
;  not always round the same way, and painting that red would teach only
;  that rounding exists. Two pixels apart would be a real disagreement.
;  In C:
;
;      void differ(void)
;      {
;          for (int i = 0; i < 8; i++) {
;              int dx = sx[i] - sxd[i], dy = sy[i] - syd[i];
;              if (dx > 1 || dx < -1 || dy > 1 || dy < -1) {
;                  dcol = DIFFC;  dot(sx[i], sy[i]);
;              }
;          }
;      }
Differ: xor  di, di             ; DI = 0  (i * 2)
        mov  cx, 8              ; CX = 8 corners
.d:     push cx                 ; keep the count
        mov  ax, [sx+di]        ; AX = sx[i]
        sub  ax, [sxd+di]       ; AX = dx = sx[i] - sxd[i]
        cmp  ax, 1              ; dx > 1 ?
        jg   .red               ;   yes: a real disagreement
        cmp  ax, -1             ; dx < -1 ?
        jl   .red               ;   yes
        mov  ax, [sy+di]        ; AX = sy[i]
        sub  ax, [syd+di]       ; AX = dy = sy[i] - syd[i]
        cmp  ax, 1              ; dy > 1 ?
        jg   .red               ;   yes
        cmp  ax, -1             ; dy >= -1 ?
        jge  .ok                ;   yes: within a pixel, no dot
.red:   mov  byte [dcol], DIFFC ; dcol = red
        mov  ax, [sx+di]        ; AX = sx[i]   \  dot(sx[i], sy[i])
        mov  bx, [sy+di]        ; BX = sy[i]   /
        push di                 ; keep i: Dot uses DI
        call Dot                ; dot()
        pop  di                 ; i back
.ok:    add  di, 2              ; i++
        pop  cx                 ; the count
        loop .d                 ; 8 times
        ret                     ; return

; ---- the eye's axis where it meets the glass: a small yellow cross -----
;  In C:   line(CX0-5, CY0, CX0+5, CY0);  line(CX0, CY0-5, CX0, CY0+5);  in yellow
Axis:   mov  word [p0x], CX0-5  ; p0x = 155  \
        mov  word [p1x], CX0+5  ; p1x = 165   > the horizontal stroke
        mov  word [p0y], CY0    ; p0y = 100   >
        mov  word [p1y], CY0    ; p1y = 100  /
        mov  byte [col], AXISC  ; col = yellow
        call Line               ; line()
        mov  word [p0x], CX0    ; p0x = 160  \
        mov  word [p1x], CX0    ; p1x = 160   > the vertical stroke
        mov  word [p0y], CY0-5  ; p0y = 95    >
        mov  word [p1y], CY0+5  ; p1y = 105  /
        mov  byte [col], AXISC  ; col = yellow
        call Line               ; line()
        ret                     ; return

; ---- one whole picture --------------------------------------------------
;  In C:
;
;      void frame(void)
;      {
;          vsync();  gclear();  axis();
;          if (!xform()) return;             /* a corner dropped: no cube */
;          ecol = EDGEC;  esrc = sx;  edges();
;      }
Frame:  call Vsync              ; vsync()
        call GClear             ; gclear()
        call Axis               ; axis()
        call Xform              ; ok = xform()
        cmp  byte [ok], 0       ; ok ?
        je   .out               ;   no: return
        mov  byte [ecol], EDGEC ; ecol = white
        mov  word [esrc], sx    ; esrc = sx
        call Edges              ; edges()
.out:   ret

; ============================================================================
;  Frame4 - BOTH answers, drawn on each other, and counted.
;
;  First the cube moved and the camera left alone. Park that answer.
;  Then the cube left alone and the camera moved the other way. Draw the
;  parked one in grey, this one in white on top, and hunt for a corner
;  they disagree about. Different numbers going in; the same pixels coming
;  out, or the claim of this lesson is false.
; ============================================================================
;  In C:
;
;      void frame4(void)
;      {
;          vsync();  gclear();  axis();
;          objx = swing;  camx = 0;   ok1 = xform();  keep();   /* cube moved   */
;          objx = 0;  camx = -swing;  ok  = xform();            /* camera moved */
;          if (ok && ok1) {
;              ecol = OTHERC; esrc = sxd; edges();               /* grey under   */
;              ecol = EDGEC;  esrc = sx;  edges();               /* white over   */
;              differ();                                         /* red where not */
;          }
;          objx = camx = 0;
;      }
Frame4: call Vsync              ; vsync()
        call GClear             ; gclear()
        call Axis               ; axis()
        mov  ax, [swing]        ; AX = swing
        mov  [objx], ax         ; objx = swing: the CUBE moved...
        mov  word [camx], 0     ; camx = 0      ...the camera at home
        call Xform              ; ok = xform()
        mov  al, [ok]           ; AL = ok
        mov  [ok1], al          ; ok1 = ok
        call Keep               ; keep(): park that answer in sxd/syd
        mov  word [objx], 0     ; objx = 0      ...or the cube at home
        mov  ax, [swing]        ; AX = swing
        neg  ax                 ; AX = -swing
        mov  [camx], ax         ; camx = -swing ...and the CAMERA moved
        call Xform              ; ok = xform()
        cmp  byte [ok], 0       ; ok ?
        je   .out               ;   no: nothing to compare
        cmp  byte [ok1], 0      ; ok1 ?
        je   .out               ;   no
        mov  byte [ecol], OTHERC ; ecol = grey
        mov  word [esrc], sxd   ; esrc = sxd: the parked answer
        call Edges              ; edges()
        mov  byte [ecol], EDGEC ; ecol = white
        mov  word [esrc], sx    ; esrc = sx: this answer, on top
        call Edges              ; edges()
        call Differ             ; differ()
.out:   mov  word [objx], 0     ; objx = 0
        mov  word [camx], 0     ; camx = 0
        ret                     ; return

; ---- Sweep: run [which] to and fro until a key --------------------------
;  1 the cube slides, 2 the camera slides, 3 both at once,
;  4 the cube turns,  5 the camera turns
;  In C:
;
;      void sweep(void)
;      {
;          do {
;              if (which == 3) frame4(); else frame();
;              swing += swd;                              /* to and fro   */
;              if (swing >  SWING) swd = -swd;
;              if (swing < -SWING) swd = -swd;
;              switch (which) {
;                  case 1: objx   =  swing;               break;  /* cube slides   */
;                  case 2: camx   = -swing;               break;  /* camera slides */
;                  case 4: objyaw =  swing * 2 + MYAW0;   break;  /* cube turns    */
;                  case 5: camyaw =  swing / 4;           break;  /* camera turns  */
;              }
;          } while (!key_check());
;      }
Sweep:  cmp  byte [which], 3    ; which == 3 ?
        jne  .one               ;   no: one answer
        call Frame4             ;   yes: frame4() - both answers
        jmp  .step              ; over the plain frame
.one:   call Frame              ;   no:  frame()
.step:  mov  al, [swd]          ; AL = swd, +1 or -1
        cbw                     ; AX = swd
        mov  bx, [swing]        ; BX = swing
        add  bx, ax             ; BX = swing + swd
        mov  [swing], bx        ; swing = BX
        cmp  bx, SWING          ; swing > SWING ?
        jle  .n1                ;   no: still inside
        neg  byte [swd]         ;   yes: swd = -swd, turn round
.n1:    cmp  bx, -SWING         ; swing < -SWING ?
        jge  .n2                ;   no: still inside
        neg  byte [swd]         ;   yes: swd = -swd
.n2:    mov  al, [which]        ; AL = which
        cmp  al, 1              ; which == 1 ?
        jne  .c2                ;   no: not the cube sliding
        mov  [objx], bx         ;   objx = swing: the cube slides
.c2:    cmp  al, 2              ; which == 2 ?
        jne  .c4                ;   no: not the camera sliding
        mov  ax, bx             ;   AX = swing
        neg  ax                 ;   AX = -swing
        mov  [camx], ax         ;   camx = -swing: the camera slides the other way
.c4:    cmp  al, 4              ; which == 4 ?
        jne  .c5                ;   no: not the cube turning
        mov  al, bl             ;   AL = swing (low byte)
        add  al, al             ;   AL = swing * 2
        add  al, MYAW0          ;   AL = swing * 2 + MYAW0
        mov  [objyaw], al       ;   objyaw = AL: the cube turns where it stands
.c5:    cmp  al, 5              ; which == 5 ?
        jne  .k                 ;   no: not the camera turning
        mov  ax, bx             ;   AX = swing
        mov  cl, 2              ;   CL = 2
        sar  ax, cl             ;   AX = swing / 4: a QUARTER of the sweep,
        mov  [camyaw], al       ;   camyaw = AL      because turning the camera
                                ;  moves the cube across the glass very fast:
                                ;  past about fifteen degrees it is off the
                                ;  edge and dropped, and a blank screen
                                ;  teaches nothing. The camera turns, which
.k:     call KeyChk             ; AL = key_check()   is NOT the same thing
        or   al, al             ; a key ?
        jz   Sweep              ;   no: another frame
        ret                     ;   yes: return

; ---- StepXZ: one pace along the way the camera is facing ---------------
;  In C:   pa = 0;  pb = STEPF;  rot2(camyaw);   - the pace, turned to face
StepXZ: mov  word [pa], 0       ; pa = 0
        mov  word [pb], STEPF   ; pb = STEPF: one pace straight ahead
        mov  al, [camyaw]       ; AL = camyaw
        call Rot2               ; rot2(camyaw): pa, pb = the pace, turned
        ret                     ; return

; ---- Fly: the arrows, one step a key, until ESC ------------------------
;  One step per keypress, redrawn between: a great many DOS programs
;  worked exactly this way, and it makes the motion deterministic. Arrow
;  keys arrive with AL zero and the scan code in AH - that is what an
;  EXTENDED key is, and lesson 11 met them at the wire.
;  In C:
;
;      void fly(void)
;      {
;          for (;;) {
;              frame();
;              int k = get_key();                /* AL = char, AH = scan */
;              if (k == ESC) return;
;              if (char != 0) continue;          /* not an arrow key     */
;              switch (scan) {
;                  case UP:    step_xz(); camx += pa; camz += pb; break;
;                  case DOWN:  step_xz(); camx -= pa; camz -= pb; break;
;                  case LEFT:  camyaw -= STEPT; break;
;                  case RIGHT: camyaw += STEPT; break;
;              }
;          }
;      }
Fly:    call Frame              ; frame()
        mov  ah, 0              ; get_key()  (BIOS 16h, service 0: waits)
        int  16h                ; AL = the character, AH = the scan code
        cmp  al, 27             ; AL == ESC ?
        je   .out               ;   yes: return
        or   al, al             ; AL != 0 ?
        jnz  Fly                ;   yes: an ordinary key, not ours
        cmp  ah, 72             ; scan == UP ?
        je   .fwd               ;   -> .fwd
        cmp  ah, 80             ; scan == DOWN ?
        je   .back              ;   -> .back
        cmp  ah, 75             ; scan == LEFT ?
        je   .left              ;   -> .left
        cmp  ah, 77             ; scan == RIGHT ?
        je   .right             ;   -> .right
        jmp  Fly                ; anything else: ignored
.fwd:   call StepXZ             ; pa, pb = one pace, turned
        mov  ax, [pa]           ; AX = pa
        add  [camx], ax         ; camx += pa
        mov  ax, [pb]           ; AX = pb
        add  [camz], ax         ; camz += pb
        jmp  Fly                ; back to the top of the loop
.back:  call StepXZ             ; the same pace...
        mov  ax, [pa]           ; AX = pa
        sub  [camx], ax         ; camx -= pa     ...taken backwards
        mov  ax, [pb]           ; AX = pb
        sub  [camz], ax         ; camz -= pb
        jmp  Fly                ; back to the top of the loop
.left:  mov  al, [camyaw]       ; AL = camyaw
        sub  al, STEPT          ; AL -= STEPT
        mov  [camyaw], al       ; camyaw = AL  (a byte: wraps at 256 = a turn)
        jmp  Fly                ; back to the top of the loop
.right: mov  al, [camyaw]       ; AL = camyaw
        add  al, STEPT          ; AL += STEPT
        mov  [camyaw], al       ; camyaw = AL
        jmp  Fly                ; back to the top of the loop
.out:   ret

; ============================================================================
;  THE CUBE - lesson 0E's, unchanged: eight corners measured from its own
;  centre, and twelve pairs saying which to join. Nothing in these tables
;  knows where the cube stands, and nothing in them knows about a camera.
;  That is what MODEL SPACE means.
; ============================================================================
VERTS   db -18,-18,-18
        db  18,-18,-18
        db  18, 18,-18
        db -18, 18,-18
        db -18,-18, 18
        db  18,-18, 18
        db  18, 18, 18
        db -18, 18, 18

EDGES   db 0,1, 1,2, 2,3, 3,0
        db 4,5, 5,6, 6,7, 7,4
        db 0,4, 1,5, 2,6, 3,7

; ---- state ---------------------------------------------------------------
sx      dw 8 dup (0)            ; the corners on the glass - what is drawn
sy      dw 8 dup (0)
sxd     dw 8 dup (0)            ; ...and the other answer, parked in stage 4
syd     dw 8 dup (0)
esrc    dw sx
ecol    db EDGEC
ok      db 1
ok1     db 1

mx      dw 0                    ; one corner, turned but not yet placed
my      dw 0
mz      dw 0
vx      dw 0                    ; ...and the same corner, in view space
vy      dw 0
vz      dw 0
pa      dw 0                    ; the pair Rot2 is holding - words now
pb      dw 0
t1      dw 0
t2      dw 0
tsin    dw 0
tcos    dw 0
rcp     dw 0

; ---- THE MODEL MATRIX, as four numbers -----------------------------------
;  Where the cube stands, and which way it faces. Stage 2 changes objx;
;  stage 5 changes objyaw. Both are ADDED to the corner, forwards.
objx    dw 0
objy    dw 0
objz    dw HOMEZ
objyaw  db MYAW0

; ---- THE VIEW MATRIX, as four numbers ------------------------------------
;  Where the camera stands, and which way IT faces - a real camera, set
;  like any other state and flown by the arrow keys in stage 7. What is
;  worth noticing is not that it is a fiction, because it is not. It is
;  WHERE these are spent: every one of them is SUBTRACTED or NEGATED on
;  the way to the eye's frame, because the view matrix is the inverse of
;  the camera's placement.
camx    dw 0
camy    dw 0
camz    dw 0
camyaw  db 0

swing   dw 0                    ; the sweep's own counter
swd     db 1
which   db 0

include 'SINTAB.INC'
include 'RECIP.INC'
include 'DRAW16.INC'

; ============================================================================
;  In C:
;
;      int main(void)
;      {
;          set_mode(0x13);
;          frame(); get_key();                       /* 1 */
;          which = 1; swing = 0; swd = 1; sweep(); objx = 0;     /* 2 */
;          which = 2; swing = 0; swd = 1; sweep(); camx = 0;     /* 3 */
;          which = 3; swing = 0; swd = 1; sweep();               /* 4 */
;          which = 4; swing = 0; swd = 1; sweep(); objyaw = MYAW0; /* 5 */
;          which = 5; swing = 0; swd = 1; sweep(); camyaw = 0;   /* 6 */
;          camx = camz = camyaw = 0; fly();                      /* 7 */
;          set_mode(3);  exit(0);
;      }
Boot:   cld                     ; string ops count UP (STOSW in GClear)
        mov  ax, 0013h          ; AX = 13h: 320x200, 256 colours
        int  10h                ; set_mode(0x13)
        mov  ax, VGA            ; AX = A000h
        mov  es, ax             ; ES = the screen, for the whole program

; ---- 1. the cube, from a camera at the origin ---------------------------
        call Frame              ; frame()
        call Key                ; get_key()

; ---- 2. move the CUBE: its model placement changes ----------------------
        mov  byte [which], 1    ; which = 1
        mov  word [swing], 0    ; swing = 0
        mov  byte [swd], 1      ; swd = 1
        call Sweep              ; sweep()
        mov  word [objx], 0     ; objx = 0: the cube back home

; ---- 3. move the CAMERA: its view matrix changes, the cube untouched ----
        mov  byte [which], 2    ; which = 2
        mov  word [swing], 0    ; swing = 0
        mov  byte [swd], 1      ; swd = 1
        call Sweep              ; sweep()
        mov  word [camx], 0     ; camx = 0: the camera back home

; ---- 4. both answers on each other, and counted -------------------------
        mov  byte [which], 3    ; which = 3
        mov  word [swing], 0    ; swing = 0
        mov  byte [swd], 1      ; swd = 1
        call Sweep              ; sweep()

; ---- 5. turn the CUBE: it spins where it stands -------------------------
        mov  byte [which], 4    ; which = 4
        mov  word [swing], 0    ; swing = 0
        mov  byte [swd], 1      ; swd = 1
        call Sweep              ; sweep()
        mov  byte [objyaw], MYAW0 ; objyaw = MYAW0: the cube's rest turn

; ---- 6. turn the CAMERA, and watch it NOT be the same thing -------------
;      Turning the cube spun it about its own centre. Turning the camera
;      swings the whole picture about the EYE - which is a hundred and
;      seventy units away from the cube - so the cube travels sideways
;      across the glass and leaves it. Same instruction, negated; utterly
;      different picture. The equivalence of stage 4 was about WHERE
;      things are, never about which way they face.
        mov  byte [which], 5    ; which = 5
        mov  word [swing], 0    ; swing = 0
        mov  byte [swd], 1      ; swd = 1
        call Sweep              ; sweep()
        mov  byte [camyaw], 0   ; camyaw = 0: the camera looks straight again

; ---- 7. fly it ----------------------------------------------------------
        mov  word [camx], 0     ; camx = 0    \
        mov  word [camz], 0     ; camz = 0     > the camera at the origin
        mov  byte [camyaw], 0   ; camyaw = 0  /
        call Fly                ; fly()

Bye:    mov  ax, 0003h          ; AX = 3: text mode, a clean screen for DOS
        int  10h                ; set_mode(3)
        mov  ax, 4C00h          ; AH = 4Ch exit, AL = 0 the code
        int  21h                ; exit(0)
