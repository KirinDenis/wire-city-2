; ============================================================================
;  CUBE.ASM - Lesson 0E. The first cube.
;
;      FASM CUBE.ASM CUBE.COM
;
;      1  the origin      a cross, and ONE vector out to one corner
;      2  eight vectors   eight arrows and eight tips - and no cube yet
;      3  join them       twelve edges, and the cube appears out of a LIST
;      4  hide them       the wireframe alone: all an engine ever shows you
;      5  turn it         one axis, then two - the same routine both times
;      6  move it         X and Y: every vertex takes the SAME offset
;      7  move it in Z    ...and NOTHING happens. That is "no perspective".
;      8  the wire        the back edges show through the front, for ever
;      9  the order       the same two turns, swapped, land somewhere else
;
;  THE ONE FACT THIS LESSON HANDS OVER: a model is a list of VECTORS
;  measured from its own centre, plus a list of WHICH ENDS TO JOIN. The
;  cube below is eight triples of signed bytes and twelve pairs of indices,
;  and there is nothing else to it. Moving the cube is not moving a cube -
;  it is transforming eight vectors. The cube never existed.
;
;  That is lesson 10's square, one dimension up, and it is worth saying
;  again in the same words: the shape is not in the program. Only the
;  corners are, and the list that joins them.
;
;  THE PHYSICAL FACT: A PROJECTION IS A DELETED COORDINATE. The screen is
;  320x200 bytes and has no depth anywhere in it. This program computes z
;  honestly, turns it, translates it - and then never reads it again. That
;  deletion is the whole of the projection, it costs ZERO instructions, and
;  it is exactly why there is no perspective here: perspective is a DIVIDE,
;  and we have not paid for one.
;
;  WHAT IS DELIBERATELY MISSING, and neither is an accident:
;
;      NO PERSPECTIVE          far edges are drawn exactly as long as near
;                              ones. Stage 7 moves the cube at your face
;                              and the picture does not change by a pixel.
;      NO HIDDEN-LINE REMOVAL  every edge is drawn, including the four at
;                              the back. You can see through the box, and
;                              that is why the word is WIREFRAME.
;
;  AND THE MATRIX IS THE SAME ONE. Rot2 below is lesson 12's rotation, bare
;  - and this lesson shows what it always was: a turn about an AXIS is a
;  plain two-dimensional turn in the plane PERPENDICULAR to that axis. Turn
;  about Y and the pair is (x,z). Turn about X and the pair is (y,z). One
;  routine, called twice, handed a different pair. Nothing new was needed
;  to leave the plane.
;
;  Owlos - legacy software modernization - https://owlos.sk
; ============================================================================
format binary as 'com'
        org  100h

VGA     = 0A000h                ; the graphics screen: 320x200, one byte a
W       = 320                   ;  pixel, and NO DEPTH ANYWHERE IN IT
H       = 200

CX0     = 160                   ; where the world's origin lands on glass
CY0     = 100

NV      = 8                     ; eight corners...
NE      = 12                    ; ...and twelve joins. That is the model.

VECC    = 10                    ; a vector is green - lesson 10's colour
EDGEC   = 15                    ; an edge is white
ORGC    = 14                    ; the origin is yellow
TIPC    = 11                    ; a corner, marked
ALTC    = 12                    ; the OTHER order, in stage 9: red

        jmp  Boot               ; over the routines, to the boot at the bottom

; ============================================================================
;  Rot2 - LESSON 12'S MATRIX, bare, and the whole of three dimensions.
;
;  in:  AL = the angle, 0..255 - the whole circle in one byte
;       [pa],[pb] = a PAIR of coordinates, signed bytes
;  out: [pa],[pb] turned by that angle
;
;      a' = a*cos - b*sin
;      b' = a*sin + b*cos
;
;  Four IMULs, two adds - the same four, the same two, since lesson 12.
;  What is new is only which pair you hand it:
;
;      turn about Y   ->   the pair is (x, z)
;      turn about X   ->   the pair is (y, z)
;      turn about Z   ->   the pair is (x, y)   - the flat turn we know
;
;  Because a turn about an axis leaves that axis alone and rotates the
;  plane perpendicular to it, and a rotation of a plane is the 2x2 matrix
;  we have had for two lessons. There is no third-dimensional arithmetic
;  in this program. There is the same arithmetic, aimed twice.
;
;  Note there is no NEG here. The screen's y-flip is not the model's
;  business: it happens once, at the projection, and nowhere else.
; ============================================================================
;  In C:
;
;      void rot2(int a)                     /* turns the byte pair (pa, pb) */
;      {
;          int s = SINTAB[a];               /* sin * 127, -127..127         */
;          int c = SINTAB[(a + 64) & 255];  /* cos = sin a quarter turn on  */
;          int na = (pa * c - pb * s) >> 7; /* the matrix, row one          */
;          int nb = (pa * s + pb * c) >> 7; /*             row two          */
;          pa = na;  pb = nb;               /* row two used the OLD pa      */
;      }
Rot2:   push ax                 ; keep a
        mov  bx, SINTAB         ; BX = the table
        xlatb                   ; AL = SINTAB[a] = s: sin(a), -127..127
        mov  [tsin], al         ; tsin = s
        pop  ax                 ; AL = a
        add  al, 64             ; AL = a + 64: cos(a) = sin(a + a quarter-turn)
        xlatb                   ; AL = SINTAB[a + 64] = c
        mov  [tcos], al         ; tcos = c
        mov  al, [tcos]         ; AL = c
        imul byte [pa]          ; AX = pa * c, signed
        mov  dx, ax             ; DX = pa * c
        mov  al, [tsin]         ; AL = s
        imul byte [pb]          ; AX = pb * s
        sub  dx, ax             ; DX = pa * c - pb * s, in 128ths
        mov  cl, 7              ; CL = 7
        sar  dx, cl             ; DX >>= 7: /128 as a SHIFT, the table speaks 128ths
        mov  [t1], dl           ; t1 = na   PARKED - nb still needs the OLD pa
        mov  al, [tsin]         ; AL = s
        imul byte [pa]          ; AX = pa * s
        mov  dx, ax             ; DX = pa * s
        mov  al, [tcos]         ; AL = c
        imul byte [pb]          ; AX = pb * c
        add  dx, ax             ; DX = pa * s + pb * c
        sar  dx, cl             ; DX >>= 7
        mov  [pb], dl           ; pb = nb
        mov  al, [t1]           ; AL = na
        mov  [pa], al           ; pa = na   ...and only now is it allowed to land
        ret                     ; return

; ============================================================================
;  Xform - the whole pipeline, once per corner, and it is four short steps.
;
;      turn about Y      the pair (x,z), by [angy]
;      turn about X      the pair (y,z), by [angx]
;      translate         add the same three numbers to every corner
;      project           throw z away and put x,y on the glass
;
;  THE ORDER IS THE MEANING. Turn first, then move: the corners spin about
;  the cube's own centre and then the whole cube walks. Move first and they
;  would spin about the middle of the screen instead, dragging the box
;  round in a circle - a different animal, and a common first bug.
; ============================================================================
;  In C:
;
;      void xform(void)
;      {
;          for (int i = 0; i < NV; i++) {
;              vx3 = VERTS[i*3]; vy3 = VERTS[i*3+1]; vz3 = VERTS[i*3+2];
;              if (!swap) { turn_y(); turn_x(); }        /* the order is the meaning */
;              else       { turn_x(); turn_y(); }
;              sx[i] = CX0 + (vx3 + tx);                 /* translate, and project:  */
;              sy[i] = CY0 - (vy3 + ty);                 /* paper y up, beam down    */
;              vzs   = vz3 + tz;                         /* z: computed, never read  */
;          }
;      }
Xform:  mov  si, VERTS          ; SI = &VERTS[0]
        xor  di, di             ; DI = 0: i * 2, a projected corner is two WORDS
        mov  cx, NV             ; CX = 8 corners
.v:     push cx                 ; keep the count
        mov  al, [si]           ; AL = VERTS[i*3]: the corner, straight out of
        mov  [vx3], al          ; vx3 = x    the table: three signed bytes,
        mov  al, [si+1]         ; AL = VERTS[i*3+1]   measured from the cube's
        mov  [vy3], al          ; vy3 = y    OWN CENTRE, which is zero
        mov  al, [si+2]         ; AL = VERTS[i*3+2]
        mov  [vz3], al          ; vz3 = z

        push si                 ; keep SI and DI   ---- the two turns, in the
        push di                 ; (the pair)       order swap asks for
        cmp  byte [swap], 0     ; swap ?
        jne  .xf                ;   yes: X first
        call TurnY              ;   no:  turn_y()
        call TurnX              ;        turn_x()
        jmp  .turned            ; over the other order
.xf:    call TurnX              ; turn_x()
        call TurnY              ; turn_y()
.turned:
        pop  di                 ; DI back
        pop  si                 ; SI back

        mov  al, [vx3]          ; AL = vx3   ---- translate: the SAME three
        cbw                     ; AX = vx3   numbers added to every corner,
        add  ax, [tx]           ; AX = vx3 + tx   which is why the shape does
        add  ax, CX0            ; AX = CX0 + vx3 + tx   not change when it moves
        mov  [sx+di], ax        ; sx[i] = AX ---- and project: x straight across
        mov  al, [vy3]          ; AL = vy3
        cbw                     ; AX = vy3
        add  ax, [ty]           ; AX = vy3 + ty
        mov  bx, CY0            ; BX = CY0
        sub  bx, ax             ; BX = CY0 - (vy3 + ty): THE MINUS, paper y up,
        mov  [sy+di], bx        ; sy[i] = BX             the beam draws down
        mov  al, [vz3]          ; AL = vz3
        cbw                     ; AX = vz3
        add  ax, [tz]           ; AX = vz3 + tz: the depth, computed and
        mov  [vzs], ax          ; vzs = AX   translated as honestly as the other
                                ;  two - AND THEN NEVER READ AGAIN. That
                                ;  silence is the projection, and it costs nothing
        add  si, 3              ; SI += 3: the next corner's bytes
        add  di, 2              ; DI += 2: the next corner's word
        pop  cx                 ; the count
        loop .v                 ; 8 corners
        ret                     ; return

; ---- a turn about Y is a flat turn of the (x,z) pair, and nothing else --
;  In C:   pa = vx3; pb = vz3; rot2(angy); vx3 = pa; vz3 = pb;
TurnY:  mov  al, [vx3]          ; AL = vx3
        mov  [pa], al           ; pa = vx3
        mov  al, [vz3]          ; AL = vz3
        mov  [pb], al           ; pb = vz3
        mov  al, [angy]         ; AL = angy
        call Rot2               ; rot2(angy)
        mov  al, [pa]           ; AL = pa
        mov  [vx3], al          ; vx3 = pa
        mov  al, [pb]           ; AL = pb
        mov  [vz3], al          ; vz3 = pb
        ret                     ; return

; ---- ...and a turn about X is the same routine, handed (y,z) -----------
;  In C:   pa = vy3; pb = vz3; rot2(angx); vy3 = pa; vz3 = pb;
TurnX:  mov  al, [vy3]          ; AL = vy3
        mov  [pa], al           ; pa = vy3
        mov  al, [vz3]          ; AL = vz3
        mov  [pb], al           ; pb = vz3
        mov  al, [angx]         ; AL = angx
        call Rot2               ; rot2(angx)
        mov  al, [pa]           ; AL = pa
        mov  [vy3], al          ; vy3 = pa
        mov  al, [pb]           ; AL = pb
        mov  [vz3], al          ; vz3 = pb
        ret                     ; return

; ---- the origin, and there are TWO of them --------------------------------
;  THE ROOM'S ZERO is the yellow cross, and it is nailed to the middle of
;  the screen for ever. It has to be: the projection reads world x and
;  world y straight off, so the room is what the glass is bolted to.
;
;  THE CUBE'S OWN ZERO is [ocx],[ocy] - where the model's centre has been
;  translated to. It is not drawn as a cross; the eight green arrows come
;  out of it, and that bundle IS the cube's own frame. Move the cube and
;  you see the bundle walk away from the yellow cross, which is exactly
;  what translating a model means.
;
;  The first version drew the yellow cross at the CUBE's centre, so it
;  travelled - and that quietly said the room moves. It does not.
;  In C:
;
;      void origin(void)
;      {
;          ocx = CX0 + tx;  ocy = CY0 - ty;        /* the cube's own zero    */
;          line(CX0-5, CY0, CX0+5, CY0);           /* the room's, a cross,   */
;          line(CX0, CY0-5, CX0, CY0+5);           /*  which never moves     */
;      }
Origin: mov  ax, CX0            ; AX = CX0
        add  ax, [tx]           ; AX = CX0 + tx
        mov  [ocx], ax          ; ocx = AX: the cube's own zero, the arrows start here
        mov  ax, CY0            ; AX = CY0
        sub  ax, [ty]           ; AX = CY0 - ty
        mov  [ocy], ax          ; ocy = AX
        mov  word [p0x], CX0-5  ; p0x = 155  \  the ROOM's zero, which never
        mov  word [p1x], CX0+5  ; p1x = 165   > moves: the horizontal stroke
        mov  word [p0y], CY0    ; p0y = 100   >
        mov  word [p1y], CY0    ; p1y = 100  /
        mov  byte [col], ORGC   ; col = yellow
        call Line               ; line()
        mov  word [p0x], CX0    ; p0x = 160  \
        mov  word [p1x], CX0    ; p1x = 160   > the vertical stroke
        mov  word [p0y], CY0-5  ; p0y = 95    >
        mov  word [p1y], CY0+5  ; p1y = 105  /
        mov  byte [col], ORGC   ; col = yellow
        call Line               ; line()
        ret                     ; return

; ---- the scaffolding: one green arrow from the centre to each corner ----
;  [nvec] says how many of the eight are switched on, so stage 1 can show
;  exactly one of them and stage 2 can bring the rest.
;  In C:
;
;      void vecs(void)
;      {
;          for (int i = vfrom; i < vfrom + nvec; i++) {
;              p0x = ocx;  p0y = ocy;               /* from the cube's zero */
;              p1x = sx[i]; p1y = sy[i];            /* ...to the corner     */
;              col = VECC;  line();
;              dcol = TIPC; dot(sx[i], sy[i]);      /* and the tip, marked  */
;          }
;      }
Vecs:   mov  cl, [nvec]         ; CL = nvec
        xor  ch, ch             ; CX = nvec
        jcxz .out               ; if (nvec == 0) return
        mov  bl, [vfrom]        ; BL = vfrom: WHICH corner to start from. Stage
        xor  bh, bh             ; BX = vfrom   1 shows one, and not corner zero:
        add  bx, bx             ; BX = vfrom * 2   at this angle corner zero sits
        mov  di, bx             ; DI = i * 2   nearly on the body diagonal that
                                ;  points at you, and its arrow projects to
                                ;  fourteen pixels. A corner on another
                                ;  diagonal is sixty
.a:     push cx                 ; keep the count
        mov  ax, [ocx]          ; AX = ocx
        mov  [p0x], ax          ; p0x = ocx
        mov  ax, [ocy]          ; AX = ocy
        mov  [p0y], ax          ; p0y = ocy
        mov  ax, [sx+di]        ; AX = sx[i]
        mov  [p1x], ax          ; p1x = sx[i]
        mov  ax, [sy+di]        ; AX = sy[i]
        mov  [p1y], ax          ; p1y = sy[i]
        mov  byte [col], VECC   ; col = green
        push di                 ; keep i: Line uses DI
        call Line               ; line()
        pop  di                 ; i back
        mov  byte [dcol], TIPC  ; dcol = cyan: the tip, marked - a CORNER
        mov  ax, [sx+di]        ; AX = sx[i]   \  dot(sx[i], sy[i])
        mov  bx, [sy+di]        ; BX = sy[i]   /
        push di                 ; keep i: Dot uses DI
        call Dot                ; dot()
        pop  di                 ; i back
        add  di, 2              ; i++
        pop  cx                 ; the count
        loop .a                 ; nvec times
.out:   ret                     ; return

; ---- the model, drawn: twelve lines, and the LIST is the whole trick ----
;  Nothing here knows what a cube is. It reads pairs of corner numbers and
;  joins them. Change the twelve pairs and the same eight corners become a
;  different object entirely.
;  In C:
;
;      void edges(void)
;      {
;          for (int e = 0; e < NE; e++) {
;              int a = EDGES[e*2], b = EDGES[e*2+1];
;              p0x = sx[a];  p0y = sy[a];
;              p1x = sx[b];  p1y = sy[b];
;              col = ecol;
;              line();
;          }
;      }
Edges:  mov  si, EDGES          ; SI = &EDGES[0]
        mov  cx, NE             ; CX = 12 joins
.e:     push cx                 ; keep the count
        mov  bl, [si]           ; BL = a: from this corner...
        xor  bh, bh             ; BX = a
        add  bx, bx             ; BX = a * 2: words
        mov  ax, [sx+bx]        ; AX = sx[a]
        mov  [p0x], ax          ; p0x = sx[a]
        mov  ax, [sy+bx]        ; AX = sy[a]
        mov  [p0y], ax          ; p0y = sy[a]
        mov  bl, [si+1]         ; BL = b: ...to that one
        xor  bh, bh             ; BX = b
        add  bx, bx             ; BX = b * 2
        mov  ax, [sx+bx]        ; AX = sx[b]
        mov  [p1x], ax          ; p1x = sx[b]
        mov  ax, [sy+bx]        ; AX = sy[b]
        mov  [p1y], ax          ; p1y = sy[b]
        mov  al, [ecol]         ; AL = ecol
        mov  [col], al          ; col = ecol
        push si                 ; keep SI: the rule is to keep what the loop needs
        call Line               ; line()
        pop  si                 ; SI back
        add  si, 2              ; SI += 2: the next pair
        pop  cx                 ; the count
        loop .e                 ; 12 times
        ret                     ; return

; ---- one whole picture --------------------------------------------------
;  In C:   vsync(); gclear(); xform(); origin(); vecs(); if (shedge) { ecol = EDGEC; edges(); }
Frame:  call Vsync              ; vsync()
        call GClear             ; gclear()
        call Xform              ; xform()
        call Origin             ; origin()
        call Vecs               ; vecs()
        cmp  byte [shedge], 0   ; shedge ?
        je   .no                ;   no: no edges yet
        mov  byte [ecol], EDGEC ; ecol = white
        call Edges              ; edges()
.no:    ret                     ; return

; ---- Spin: turn until a key, by whatever steps are set ------------------
;  In C:   do { frame(); angy += stepy; angx += stepx; } while (!key_check());
Spin:   call Frame              ; frame()
        mov  al, [stepy]        ; AL = stepy
        add  [angy], al         ; angy += stepy
        mov  al, [stepx]        ; AL = stepx
        add  [angx], al         ; angx += stepx
        call KeyChk             ; AL = key_check()
        or   al, al             ; a key ?
        jz   Spin               ;   no: another frame
        ret                     ; return

; ---- Walk: slide by (dx,dy,dz) until a key, bouncing at the limits ------
;  The steps are signed BYTES and the offsets are WORDS, so every one of
;  them goes through CBW first - a byte and a word do not add, and the
;  assembler is right to refuse.
;  In C:
;
;      void walk(void)
;      {
;          do {
;              frame();
;              tx += wdx;  ty += wdy;  tz += wdz;
;              if (tx >  70 || tx <  -70) wdx = -wdx;    /* a small pen, so  */
;              if (ty >  50 || ty <  -50) wdy = -wdy;    /*  the box stays   */
;              if (tz > 120 || tz < -120) wdz = -wdz;    /*  on the glass    */
;          } while (!key_check());
;      }
Walk:   call Frame              ; frame()
        mov  al, [wdx]          ; AL = wdx, a signed byte...
        cbw                     ; AX = wdx  ...widened: a byte and a word do
        add  [tx], ax           ; tx += wdx   not add, the assembler is right
        mov  al, [wdy]          ; AL = wdy    to refuse
        cbw                     ; AX = wdy
        add  [ty], ax           ; ty += wdy
        mov  al, [wdz]          ; AL = wdz
        cbw                     ; AX = wdz
        add  [tz], ax           ; tz += wdz
        mov  ax, [tx]           ; AX = tx        a small pen, so the box stays
        cmp  ax, 70             ; tx > 70 ?      on the glass
        jle  .l1                ;   no
        neg  byte [wdx]         ;   yes: wdx = -wdx
.l1:    cmp  ax, -70            ; tx < -70 ?
        jge  .l2                ;   no
        neg  byte [wdx]         ;   yes: wdx = -wdx
.l2:    mov  ax, [ty]           ; AX = ty
        cmp  ax, 50             ; ty > 50 ?
        jle  .l3                ;   no
        neg  byte [wdy]         ;   yes: wdy = -wdy
.l3:    cmp  ax, -50            ; ty < -50 ?
        jge  .l4                ;   no
        neg  byte [wdy]         ;   yes: wdy = -wdy
.l4:    mov  ax, [tz]           ; AX = tz
        cmp  ax, 120            ; tz > 120 ?
        jle  .l5                ;   no
        neg  byte [wdz]         ;   yes: wdz = -wdz
.l5:    cmp  ax, -120           ; tz < -120 ?
        jge  .l6                ;   no
        neg  byte [wdz]         ;   yes: wdz = -wdz
.l6:    call KeyChk             ; AL = key_check()
        or   al, al             ; a key ?
        jz   Walk               ;   no: another frame
        ret                     ; return

; ============================================================================
;  THE MODEL. Eight corners, three signed bytes each, and every one of them
;  measured FROM THE CUBE'S OWN CENTRE - which is zero, zero, zero. There is
;  no position in this table and there is no cube in it either. Only corners.
;
;  The first four are the far face, z minus forty; the last four the near
;  face, z plus forty. Both go round the same way, which is what lets the
;  edge list below be written by eye.
; ============================================================================
VERTS   db -40,-40,-40          ; 0
        db  40,-40,-40          ; 1
        db  40, 40,-40          ; 2
        db -40, 40,-40          ; 3
        db -40,-40, 40          ; 4
        db  40,-40, 40          ; 5
        db  40, 40, 40          ; 6
        db -40, 40, 40          ; 7

; ============================================================================
;  AND THE LIST OF WHICH TO JOIN - twelve pairs, twenty four bytes, and THIS
;  is where the cube actually lives. The corners above are a cloud of eight
;  points; they become a box only because these pairs say so. Rewrite these
;  twenty four bytes and the same eight corners are a different object.
; ============================================================================
EDGES   db 0,1, 1,2, 2,3, 3,0   ; the far face
        db 4,5, 5,6, 6,7, 7,4   ; the near face
        db 0,4, 1,5, 2,6, 3,7   ; and the four that join them

; ---- state ---------------------------------------------------------------
sx      dw NV dup (0)           ; where every corner lands on the glass...
sy      dw NV dup (0)
vzs     dw 0                    ; ...and the depth that nobody ever reads

vx3     db 0                    ; one corner, while it is being worked on
vy3     db 0
vz3     db 0
pa      db 0                    ; the pair Rot2 is holding
pb      db 0
t1      db 0                    ; a' parked, while b' still wants the old a
tsin    db 0
tcos    db 0

angy    db 0                    ; the two angles the model is turned by
angx    db 0
stepy   db 0                    ; ...and how fast each of them walks
stepx   db 0

tx      dw 0                    ; where the cube has been moved to
ty      dw 0
tz      dw 0
wdx     db 0                    ; ...and which way it is sliding
wdy     db 0
wdz     db 0

ocx     dw CX0                  ; where the origin lands, this frame
ocy     dw CY0
vfrom   db 0                    ; the first corner-vector to draw...
nvec    db 0                    ; how many corner-vectors are switched on
shedge  db 0                    ; are the edges drawn at all?
ecol    db EDGEC
swap    db 0                    ; 0 = turn about Y then X; 1 = the other
                                ;  way round. Stage 9 draws both, because
                                ;  they do NOT land in the same place.

include 'SINTAB.INC'
include 'DRAW14.INC'

; ============================================================================
;  In C:
;
;      int main(void)
;      {
;          set_mode(0x13);
;          angy = 24; angx = 20; vfrom = 1; nvec = 1; shedge = 0; frame(); key();  /* 1 */
;          vfrom = 0; nvec = NV;                                  frame(); key();  /* 2 */
;          shedge = 1;                                            frame(); key();  /* 3 */
;          nvec = 0;                                              frame(); key();  /* 4 */
;          stepy = 1; stepx = 0; spin();  stepx = 1; spin();                       /* 5 */
;          stepy = stepx = 0; angy = 24; angx = 20; vfrom = 0; nvec = NV;
;          wdx = 2; wdy = 1; wdz = 0; walk();                                      /* 6 */
;          tx = ty = 0; wdx = wdy = 0; wdz = 3; walk();                            /* 7 */
;          tz = 0; wdz = 0; nvec = 0; stepy = 1; stepx = 0; spin();                /* 8 */
;          angy = angx = 40; swap = 0; frame();                                    /* 9 */
;          swap = 1; xform(); ecol = ALTC; edges(); key();
;          set_mode(3); exit(0);
;      }
Boot:   cld                     ; string ops count UP (STOSW in GClear)
        mov  ax, 0013h          ; AX = 13h: the graphics screen, 320x200
        int  10h                ; set_mode(0x13)
        mov  ax, VGA            ; AX = A000h
        mov  es, ax             ; ES = the screen, for the whole program

; ---- 1. the origin, and ONE corner ---------------------------------------
        mov  byte [angy], 24    ; angy = 24   stood at an angle from the start,
        mov  byte [angx], 20    ; angx = 20   or a cube looks like a square and
        mov  byte [vfrom], 1    ; vfrom = 1   teaches nobody anything. And corner
        mov  byte [nvec], 1     ; nvec = 1    ONE, not zero: at this angle corner
        mov  byte [shedge], 0   ; shedge = 0  zero sits almost on the body
                                ;  diagonal that points at you, so its arrow
                                ;  projects to fourteen pixels and teaches
                                ;  nothing either. Corner one is sixty out
        call Frame              ; frame()
        call Key                ; key()

; ---- 2. all eight vectors - and still no cube ----------------------------
        mov  byte [vfrom], 0    ; vfrom = 0
        mov  byte [nvec], NV    ; nvec = 8
        call Frame              ; frame()
        call Key                ; key()

; ---- 3. join them: the edge list arrives ---------------------------------
        mov  byte [shedge], 1   ; shedge = 1
        call Frame              ; frame()
        call Key                ; key()

; ---- 4. hide the scaffolding: what an engine actually shows you ----------
        mov  byte [nvec], 0     ; nvec = 0
        call Frame              ; frame()
        call Key                ; key()

; ---- 5. turn it: one axis, then two, by the same routine -----------------
        mov  byte [stepy], 1    ; stepy = 1
        mov  byte [stepx], 0    ; stepx = 0
        call Spin               ; spin(): about Y alone
        mov  byte [stepx], 1    ; stepx = 1
        call Spin               ; spin(): and now about two axes at once

; ---- 6. move it: every corner takes the SAME offset ----------------------
        mov  byte [stepy], 0    ; stepy = 0
        mov  byte [stepx], 0    ; stepx = 0
        mov  byte [angy], 24    ; angy = 24   back to the pose stage one stood
        mov  byte [angx], 20    ; angx = 20   in. The spin stopped wherever the
        mov  byte [vfrom], 0    ; vfrom = 0   key landed, and a still frame at a
        mov  byte [nvec], NV    ; nvec = 8    random angle looks like an accident.
                                ;  The arrows come back too, so you can watch
                                ;  the WHOLE bundle travel together
        mov  byte [wdx], 2      ; wdx = 2
        mov  byte [wdy], 1      ; wdy = 1
        mov  byte [wdz], 0      ; wdz = 0
        call Walk               ; walk()

; ---- 7. move it in Z - and watch nothing happen --------------------------
        mov  word [tx], 0       ; tx = 0
        mov  word [ty], 0       ; ty = 0
        mov  byte [wdx], 0      ; wdx = 0
        mov  byte [wdy], 0      ; wdy = 0
        mov  byte [wdz], 3      ; wdz = 3: straight at your face, and back again
        call Walk               ; walk()

; ---- 8. the wire: turn it slowly and look THROUGH it ---------------------
        mov  word [tz], 0       ; tz = 0
        mov  byte [wdz], 0      ; wdz = 0
        mov  byte [nvec], 0     ; nvec = 0
        mov  byte [stepy], 1    ; stepy = 1
        mov  byte [stepx], 0    ; stepx = 0
        call Spin               ; spin()

; ---- 9. the order of two turns is not free -------------------------------
;      The same two angles, applied the other way round, put the corners
;      somewhere else. Draw both: white is Y-then-X, red is X-then-Y. If
;      turning were like adding, one cube would hide the other.
        mov  byte [angy], 40    ; angy = 40
        mov  byte [angx], 40    ; angx = 40
        mov  byte [swap], 0     ; swap = 0
        call Frame              ; frame(): white, Y first then X
        mov  byte [swap], 1     ; swap = 1
        call Xform              ; xform(): the same numbers, the other order...
        mov  byte [ecol], ALTC  ; ecol = red
        call Edges              ; edges(): ...drawn on top, in red
        call Key                ; key()

Bye:    mov  ax, 0003h          ; AX = 3: a clean screen back to DOS
        int  10h                ; set_mode(3)
        mov  ax, 4C00h          ; AH = 4Ch exit, AL = 0 the code
        int  21h                ; exit(0)
