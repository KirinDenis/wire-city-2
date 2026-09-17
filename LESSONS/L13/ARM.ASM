; ============================================================================
;  ARM.ASM - Lesson 0D. The arm that adds up.
;
;      FASM ARM.ASM ARM.COM
;
;      1  standing      the cell: ground, two fixtures, a cube, the arm home
;      2  the shoulder  ONE motor turns - and all three needles turn
;      3  the elbow     two needles turn; the shoulder's does not
;      4  the wrist     one needle turns, and only one
;      5  the reach     only the tip inks: the WORKSPACE draws itself
;      6  the job       pick, carry, place, and round again - for ever
;
;  THE ONE FACT THIS LESSON HANDS OVER: a chain inherits its parent's
;  PLACE and its parent's TURN. Lesson 12's sky inherited only the place -
;  the Moon's orbit does not tilt when the Earth spins. A machine is not
;  like that. Turn the shoulder and the forearm goes with it, although its
;  own motor never moved.
;
;  And the whole of that costs ONE INSTRUCTION. Every joint here turns
;  about the SAME axis, so their matrices need not be multiplied at all -
;  the ANGLES ADD:
;
;      absolute angle of a link = absolute angle of its parent + its own
;
;  ...which is  ADD AL, [own]  and nothing else. In three dimensions the
;  axes differ, angles stop adding, and the matrices have to be multiplied
;  for real. That is the next lesson.
;
;  THE ANGLE IS A BYTE - lesson 10's table, 256 cells for the whole turn -
;  so the circle closes itself: 255 + 1 is 0, and that wrap is not a fault
;  to guard against, it is the geometry coming out right. The same byte
;  does one more favour: SUB of two angles lands on the SHORT WAY ROUND,
;  already signed, which is how each motor knows which way to turn.
;
;  NOBODY TYPED WHERE THE CUBE SITS. Boot runs the chain with the picking
;  pose and with the placing pose and drops a fixture wherever the tip
;  lands, so the jaws always meet the cube exactly. Going the other way -
;  angles FROM a target - is inverse kinematics, and it is its own lesson.
;
;  Owlos - legacy software modernization - https://owlos.sk
; ============================================================================
format binary as 'com'
        org  100h

VGA     = 0A000h                ; the graphics screen: 320x200, one byte a
W       = 320                   ;  pixel, and NO DEPTH ANYWHERE IN IT. ES
H       = 200                   ;  points here and DI is sixteen bits, so
                                ;  every stray write this program can make
                                ;  lands inside the video segment.
GROUND  = 178                   ; the floor of the cell
BX0     = 150                   ; the shoulder's throne: the one place in
BY0     = 120                   ;  this machine that is bolted down

NJ      = 4                     ; rows in the arm: the base and three links
JROW    = 4                     ; parent, own angle, length, ink

MR      = 9                     ; the motor ring - and the rim the BALL rides
MARC    = 5                     ; the wedge, inside it
MTIN    = 0                     ; the ZERO RAY runs from the motor's centre
MTOUT   = 16                    ;  out past its rim

JOPEN   = 9                     ; the jaws, half apart...
JCLOSE  = 5                     ; ...and closed on an eight-wide cube

WROW    = 4                     ; a waypoint: three angles and a grip flag
NWP     = 15

        jmp  Boot               ; over the routines, to the boot at the bottom

; ============================================================================
;  RotV - LESSON 12'S MATRIX, byte for byte. Turn the base vector by an
;  angle.
;  in:  AL = the angle, 0..255 - the whole circle in one byte
;       [bvx],[bvy] = the base vector, signed bytes
;  out: [vx],[vy] = the turned vector, in SCREEN pixels
;
;      x' = x*cos(a) - y*sin(a)
;      y' = x*sin(a) + y*cos(a)
;
;  Four IMULs, two adds. Today it is asked for three link lengths, two
;  jaw corners and - once, at boot - the thirty-two dots of a motor ring.
;  NEG carries lesson 10's screen rule: paper y grows up, the beam draws
;  DOWN, so the turned y is flipped once, here, and nowhere else.
; ============================================================================
;  In C:
;
;      void rotv(int a)                       /* (bvx, bvy) -> (vx, vy)     */
;      {
;          int s = SINTAB[a];                 /* sin * 127                  */
;          int c = SINTAB[(a + 64) & 255];    /* cos = sin a quarter on     */
;          vx =   (bvx * c - bvy * s) >> 7;   /* the matrix, row one        */
;          vy = -((bvx * s + bvy * c) >> 7);  /* row two, and THE MINUS:    */
;      }                                      /*  screen y grows downward   */
RotV:   push ax                 ; keep a
        mov  bx, SINTAB         ; BX = the table
        xlatb                   ; AL = SINTAB[a] = s: sin(a), -127..127
        mov  [tsin], al         ; tsin = s   parked: four products want both ratios
        pop  ax                 ; AL = a
        add  al, 64             ; AL = a + 64: cos(a) = sin(a + a quarter-turn)
        xlatb                   ; AL = SINTAB[a + 64] = c
        mov  [tcos], al         ; tcos = c
        mov  al, [tcos]         ; AL = c
        imul byte [bvx]         ; AX = bvx * c, sign kept
        mov  dx, ax             ; DX = bvx * c
        mov  al, [tsin]         ; AL = s
        imul byte [bvy]         ; AX = bvy * s
        sub  dx, ax             ; DX = bvx * c - bvy * s, in 128ths
        mov  cl, 7              ; CL = 7
        sar  dx, cl             ; DX >>= 7: /128 as a SHIFT, the table speaks 128ths
        mov  [vx], dx           ; vx = DX
        mov  al, [tsin]         ; AL = s
        imul byte [bvx]         ; AX = bvx * s
        mov  dx, ax             ; DX = bvx * s
        mov  al, [tcos]         ; AL = c
        imul byte [bvy]         ; AX = bvy * c
        add  dx, ax             ; DX = bvx * s + bvy * c
        sar  dx, cl             ; DX >>= 7
        neg  dx                 ; DX = -DX: THE MINUS, screen y grows down the tube
        mov  [vy], dx           ; vy = DX
        ret                     ; return

; ============================================================================
;  Chain - THE WHOLE LESSON, and it is one ADD.
;
;  Walk the arm parents-first. Every link takes its parent's absolute
;  angle, adds its OWN motor's angle, and that sum is where it points in
;  the world. Then it hangs off the end of its parent:
;
;      ME = PARENT + MATRIX(absolute angle) x (LENGTH, 0)
;
;  The base vector is always (length, 0) - a link is just a stick lying
;  east until it is turned - so two of the matrix's four products come out
;  zero and what falls out is r*cos, r*sin: the clock formula of lesson
;  10, which lesson 12 showed was the matrix's first column. It is the
;  same arithmetic for the fourth time and it has not changed once.
; ============================================================================
;  In C:
;
;      void chain(void)                        /* ARM[j] = {parent, own, len, ink} */
;      {
;          for (int j = 1; j < NJ; j++) {
;              int par = ARM[j].parent;
;              jab[j] = jab[par] + ARM[j].own;   /* THE INHERITANCE: a byte, wraps */
;              bvx = ARM[j].len;  bvy = 0;       /* a stick lying east...          */
;              rotv(jab[j]);                     /* ...turned to where it points   */
;              jx[j] = jx[par] + vx;             /* ME = PARENT + MATRIX x (len,0) */
;              jy[j] = jy[par] + vy;
;          }
;      }
Chain:  mov  si, ARM+JROW       ; SI = &ARM[1]: row 1, the first link. Row 0 is
        mov  word [ji], 1       ; j = 1        the base, which asks nothing, never moves
        mov  cx, NJ-1           ; CX = 3 links
.j:     push cx                 ; keep the count
        mov  bl, [si]           ; BL = par: whose child is it?
        xor  bh, bh             ; BX = par
        mov  al, [jab+bx]       ; AL = jab[par]: the PARENT's absolute angle...
        add  al, [si+1]         ; AL += own: ...plus this motor's OWN angle. THAT
        mov  bx, [ji]           ; BX = j       IS THE INHERITANCE, and that is the
        mov  [jab+bx], al       ; jab[j] = AL  whole instruction. A byte: wraps itself
        mov  bl, [si+2]         ; BL = len
        mov  [bvx], bl          ; bvx = len: the length becomes the base vector,
        mov  byte [bvy], 0      ; bvy = 0    a stick lying east...
        mov  bx, [ji]           ; BX = j
        mov  al, [jab+bx]       ; AL = jab[j]: ...turned by where this link points
        push si                 ; keep SI: RotV uses BX, CX, DX
        call RotV               ; rotv(jab[j]): vx, vy
        pop  si                 ; SI back
        mov  di, [ji]           ; DI = j
        add  di, di             ; DI = j * 2: a joint is a WORD, index -> offset
        mov  bl, [si]           ; BL = par
        xor  bh, bh             ; BX = par
        add  bx, bx             ; BX = par * 2
        mov  ax, [jx+bx]        ; AX = jx[par]: ME = PARENT...
        add  ax, [vx]           ; AX += vx:    ...+ MATRIX x (LENGTH, 0)
        mov  [jx+di], ax        ; jx[j] = AX
        mov  ax, [jy+bx]        ; AX = jy[par]
        add  ax, [vy]           ; AX += vy
        mov  [jy+di], ax        ; jy[j] = AX
        inc  word [ji]          ; j++
        add  si, JROW           ; SI += 4: the next row
        pop  cx                 ; the count
        loop .j                 ; 3 links
        ret                     ; return

; ---- Pose: put a waypoint's three angles straight into the motors -------
;  in: SI = a waypoint row. Used at boot to ASK the chain where a pose
;  puts the tip, before anything is drawn.
;  In C:   ARM[1].own = wp[0];  ARM[2].own = wp[1];  ARM[3].own = wp[2];
Pose:   mov  al, [si]           ; AL = wp[0]
        mov  [ARM+1*JROW+1], al ; ARM[1].own = AL: the shoulder
        mov  al, [si+1]         ; AL = wp[1]
        mov  [ARM+2*JROW+1], al ; ARM[2].own = AL: the elbow
        mov  al, [si+2]         ; AL = wp[2]
        mov  [ARM+3*JROW+1], al ; ARM[3].own = AL: the wrist
        ret                     ; return

; ============================================================================
;  MakeRing - the thirty-two dots of a motor ring, minted ONCE.
;
;  The ring never changes shape, so it is not recomputed every frame: the
;  matrix is asked thirty-two times at boot and after that a motor costs
;  thirty-two ADDs. This is the lesson-4 habit, kept.
; ============================================================================
;  In C:
;
;      void make_ring(void)
;      {
;          for (int i = 0, a = 0; i < 32; i++, a += 8) {  /* 256/32: a full turn */
;              bvx = MR;  bvy = 0;  rotv(a);
;              RINGX[i] = vx;  RINGY[i] = vy;
;          }
;      }
MakeRing:
        xor  si, si             ; i = 0
        mov  byte [rk], 0       ; rk = a = 0
.r:     mov  byte [bvx], MR     ; bvx = MR, the ring's radius
        mov  byte [bvy], 0      ; bvy = 0
        mov  al, [rk]           ; AL = a
        push si                 ; keep i
        call RotV               ; rotv(a)
        pop  si                 ; i back
        mov  ax, [vx]           ; AX = vx
        mov  [RINGX+si], al     ; RINGX[i] = vx  (a byte: the ring is small)
        mov  ax, [vy]           ; AX = vy
        mov  [RINGY+si], al     ; RINGY[i] = vy
        add  byte [rk], 8       ; a += 8: 256/32, a full turn in thirty-two steps
        inc  si                 ; i++
        cmp  si, 32             ; i < 32 ?
        jb   .r                 ;   yes: next dot
        ret                     ; return

; ============================================================================
;  Motors - THE PICTURE THIS LESSON LIVES OR DIES BY.
;
;  Each motor sits at the pivot it drives - the end of the PARENT link -
;  and carries four marks, of which exactly one can ever stand still:
;
;      the ring          32 dots, in this link's own colour
;      the BALL          fat, white, riding the rim at this link's
;                        ABSOLUTE angle. It is the SHAFT, so it moves
;                        whenever the link moves - no matter WHO moved it.
;      the needle        the line out to the ball, so the angle reads as a
;                        direction and not as a floating dot
;      the housing tick  a short grey scratch OUTSIDE the ring, at the
;                        PARENT's angle: this motor's zero. The shoulder's
;                        tick never moves, because the shoulder's housing
;                        is bolted to a pillar that never moves.
;      the wedge         dots from the tick round to the ball. ITS LENGTH
;                        IS THE OWN ANGLE, drawn - swept the short way, so
;                        it is the angle a human would measure.
;
;  THE FIRST VERSION PUT THE FAT MARK ON THE HOUSING and left a thin
;  needle on the shaft. Every number was right and the picture was dead:
;  the boldest thing on the screen was the one thing that could not move,
;  and the shoulder - the motor the lesson tells you to watch first - had
;  a mark nailed to east for ever. Turn a motor and the eye must SEE the
;  ball go round. Weight goes on what moves.
; ============================================================================
;  In C:
;
;      void motors(void)
;      {
;          for (int j = 1; j < NJ; j++) {
;              mcx = jx[j-1];  mcy = jy[j-1];             /* the pivot: the parent's end */
;              dcol = ARM[j].ink;                         /* the ring, 32 dots           */
;              for (int i = 0; i < 32; i++) plot(mcx + RINGX[i], mcy + RINGY[i]);
;              /* the wedge: from the parent's angle, own steps of 8, the short way */
;              int a = jab[j-1], n = ARM[j].own, d = 8;
;              if (n >= 128) { n = 256 - n; d = -8; }
;              for (; n >= 8; n -= 8, a += d) { bvx = MARC; bvy = 0; rotv(a); plot(mcx+vx, mcy+vy); }
;              /* the zero ray: the parent's direction, through the joint */
;              bvx = MTIN;  bvy = 0; rotv(jab[j-1]); p0x = mcx+vx; p0y = mcy+vy;
;              bvx = MTOUT; bvy = 0; rotv(jab[j-1]); p1x = mcx+vx; p1y = mcy+vy;
;              col = 8;  line();
;              /* the ball: on the rim, where this link leaves */
;              bvx = MR; bvy = 0; rotv(jab[j]);  dcol = 15;  dot(mcx+vx, mcy+vy);
;          }
;      }
Motors: mov  si, ARM+JROW       ; SI = &ARM[1]
        mov  word [mj], 1       ; j = 1
.m:     mov  bx, [mj]           ; BX = j
        dec  bx                 ; BX = j - 1: the pivot is the PARENT's end
        add  bx, bx             ; BX = (j - 1) * 2
        mov  ax, [jx+bx]        ; AX = jx[j-1]
        mov  [mcx], ax          ; mcx = AX
        mov  ax, [jy+bx]        ; AX = jy[j-1]
        mov  [mcy], ax          ; mcy = AX
        mov  al, [si+3]         ; AL = ARM[j].ink
        mov  [dcol], al         ; dcol = AL: the ring wears its link's colour
        push si                 ; keep the row
        xor  si, si             ; i = 0
; ---- CBW is new: Convert Byte to Word. It copies bit 7 of AL over the
;      whole of AH, so a signed byte becomes the same number as a signed
;      word: 0FFh (minus one) becomes 0FFFFh (still minus one), and 7 stays
;      7. It touches AH and nothing else - NO FLAGS. Without it, a ring
;      offset of minus five would arrive as plus two hundred and fifty one
;      and the ring would be drawn a screen away. Its trap is CWD, which
;      does the same trick one size up, AX into DX:AX.
.d:     mov  al, [RINGY+si]     ; AL = RINGY[i]: the ring, 32 adds and no maths
        cbw                     ; AX = AL: signed byte -> signed word, sign kept
        add  ax, [mcy]          ; AX = mcy + RINGY[i]
        mov  bx, ax             ; BX = y
        mov  al, [RINGX+si]     ; AL = RINGX[i]
        cbw                     ; AX = AL
        add  ax, [mcx]          ; AX = x = mcx + RINGX[i]
        push si                 ; keep i: Plot uses DI, but the rule holds
        call Plot               ; plot(x, y)
        pop  si                 ; i back
        inc  si                 ; i++
        cmp  si, 32             ; i < 32 ?
        jb   .d                 ;   yes: next dot
        pop  si                 ; SI = the row again

; ---- the WEDGE: from this motor's zero round to where its link points.
;      One dot every eight steps of angle, so the arc is as long as the
;      own angle is big - the own angle, made into a thing you can see.
;      Swept the SHORT way: past a half turn it goes round the other side,
;      which is the angle a human would have measured anyway.
        mov  bx, [mj]           ; BX = j
        dec  bx                 ; BX = j - 1
        mov  al, [jab+bx]       ; AL = jab[j-1]: start at the parent's angle, the zero
        mov  [arca], al         ; arca = a
        mov  al, [si+1]         ; AL = own: and sweep this motor's own angle
        cmp  al, 128            ; own >= 128 ?
        jb   .wp                ;   no: sweep forwards
        neg  al                 ;   yes: AL = 256 - own, past half a turn: the other way
        mov  byte [arcd], -8    ;        arcd = -8
        jmp  .wn                ; over the forward case
.wp:    mov  byte [arcd], 8     ; arcd = 8
.wn:    mov  [arcn], al         ; arcn = n, how much is left to sweep
.w:     cmp  byte [arcn], 8     ; n >= 8 ?
        jb   .wd                ;   no: the wedge is done
        mov  byte [bvx], MARC   ; bvx = MARC, the wedge's radius
        mov  byte [bvy], 0      ; bvy = 0
        mov  al, [arca]         ; AL = a
        push si                 ; keep the row
        call RotV               ; rotv(a)
        pop  si                 ; row back
        mov  ax, [mcy]          ; AX = mcy
        add  ax, [vy]           ; AX = mcy + vy
        mov  bx, ax             ; BX = y
        mov  ax, [mcx]          ; AX = mcx
        add  ax, [vx]           ; AX = x = mcx + vx
        push si                 ; keep the row
        call Plot               ; plot(x, y)
        pop  si                 ; row back
        mov  al, [arcd]         ; AL = arcd
        add  [arca], al         ; a += arcd
        sub  byte [arcn], 8     ; n -= 8
        jmp  .w                 ; next dot of the wedge

; ---- the ZERO RAY: the parent's direction, CONTINUED through the joint.
;      It is where this link would point if this motor stood at zero, and
;      it is the one line the skeleton alone can never show you - the
;      parent's link arrives from the opposite side. At the shoulder the
;      parent is the world, so this ray is the horizon, and it is the only
;      mark in the whole picture entitled to stand still.
.wd:    mov  bx, [mj]           ; BX = j
        dec  bx                 ; BX = j - 1
        mov  byte [bvx], MTIN   ; bvx = MTIN: the ray's near end (the centre)
        mov  byte [bvy], 0      ; bvy = 0
        mov  al, [jab+bx]       ; AL = jab[j-1]: the parent's angle
        push si                 ; keep the row
        call RotV               ; rotv(jab[j-1])
        pop  si                 ; row back
        mov  ax, [mcx]          ; AX = mcx
        add  ax, [vx]           ; AX = mcx + vx
        mov  [p0x], ax          ; p0x = AX
        mov  ax, [mcy]          ; AX = mcy
        add  ax, [vy]           ; AX = mcy + vy
        mov  [p0y], ax          ; p0y = AX
        mov  bx, [mj]           ; BX = j
        dec  bx                 ; BX = j - 1
        mov  byte [bvx], MTOUT  ; bvx = MTOUT: the ray's far end, past the rim
        mov  byte [bvy], 0      ; bvy = 0
        mov  al, [jab+bx]       ; AL = jab[j-1]
        push si                 ; keep the row
        call RotV               ; rotv(jab[j-1])
        pop  si                 ; row back
        mov  ax, [mcx]          ; AX = mcx
        add  ax, [vx]           ; AX = mcx + vx
        mov  [p1x], ax          ; p1x = AX
        mov  ax, [mcy]          ; AX = mcy
        add  ax, [vy]           ; AX = mcy + vy
        mov  [p1y], ax          ; p1y = AX
        mov  byte [col], 8      ; col = 8, grey
        push si                 ; keep the row
        call Line               ; line()
        pop  si                 ; row back

; ---- the BALL: a bead on the rim where the link crosses it - the SHAFT.
;      No needle is drawn to it, because the link IS the needle: it leaves
;      the joint in exactly this direction. The bead is white and fat so
;      that the eye is caught by the thing that moves, which was the whole
;      fault of the first version.
        mov  bx, [mj]           ; BX = j
        mov  byte [bvx], MR     ; bvx = MR: on the rim
        mov  byte [bvy], 0      ; bvy = 0
        mov  al, [jab+bx]       ; AL = jab[j]: where THIS link leaves
        push si                 ; keep the row
        call RotV               ; rotv(jab[j])
        pop  si                 ; row back
        mov  byte [dcol], 15    ; dcol = 15, white and fat
        mov  ax, [mcy]          ; AX = mcy
        add  ax, [vy]           ; AX = mcy + vy
        mov  bx, ax             ; BX = y
        mov  ax, [mcx]          ; AX = mcx
        add  ax, [vx]           ; AX = x = mcx + vx
        push si                 ; keep the row
        call Dot                ; dot(x, y): the ball
        pop  si                 ; row back
        inc  word [mj]          ; j++
        add  si, JROW           ; SI += 4: the next row
        cmp  word [mj], NJ      ; j < NJ ?   This loop body is longer than 127
        jae  .done              ;   no: done  bytes, so a JB back to the top would
        jmp  .m                 ;   yes: next have to be a 386 long jump. Invert it
.done:  ret                     ; return      and jump over a plain JMP: an 8086

; ---- DrawArm: the pillar, then the three links in their own inks --------
;  In C:
;
;      void draw_arm(void)
;      {
;          col = 7;  line(BX0, GROUND, BX0, BY0);            /* the pillar */
;          for (int j = 1; j < NJ; j++) {
;              int par = ARM[j].parent;
;              col = ARM[j].ink;
;              line(jx[par], jy[par], jx[j], jy[j]);         /* the link   */
;          }
;      }
DrawArm:
        mov  word [p0x], BX0    ; p0x = BX0     \
        mov  word [p0y], GROUND ; p0y = GROUND   > the pillar, floor to throne
        mov  word [p1x], BX0    ; p1x = BX0      >
        mov  word [p1y], BY0    ; p1y = BY0     /
        mov  byte [col], 7      ; col = 7, grey
        call Line               ; line()
        mov  si, ARM+JROW       ; SI = &ARM[1]
        mov  di, 2              ; DI = j * 2, j = 1
.l:     mov  bl, [si]           ; BL = par
        xor  bh, bh             ; BX = par
        add  bx, bx             ; BX = par * 2
        mov  ax, [jx+bx]        ; AX = jx[par]
        mov  [p0x], ax          ; p0x = jx[par]
        mov  ax, [jy+bx]        ; AX = jy[par]
        mov  [p0y], ax          ; p0y = jy[par]
        mov  ax, [jx+di]        ; AX = jx[j]
        mov  [p1x], ax          ; p1x = jx[j]
        mov  ax, [jy+di]        ; AX = jy[j]
        mov  [p1y], ax          ; p1y = jy[j]
        mov  al, [si+3]         ; AL = ARM[j].ink
        mov  [col], al          ; col = AL
        push si                 ; keep SI and DI: Line uses DI
        push di                 ; (the pair)
        call Line               ; line()
        pop  di                 ; DI back
        pop  si                 ; SI back
        add  si, JROW           ; SI += 4: the next row
        add  di, 2              ; j++
        cmp  di, NJ*2           ; j < NJ ?
        jb   .l                 ;   yes: next link
        ret                     ; return

; ---- Jaws: two bars beside the gripper's axis, [jaw] out on each side ---
;  In C:   one_jaw(jaw);  one_jaw(-jaw);
Jaws:   mov  al, [jaw]          ; AL = jaw
        call OneJaw             ; one_jaw(jaw): one side
        mov  al, [jaw]          ; AL = jaw
        neg  al                 ; AL = -jaw
        call OneJaw             ; one_jaw(-jaw): the other
        ret                     ; return

;  In C:
;
;      void one_jaw(int ofs)                       /* ofs: how far off the axis */
;      {
;          bvx = -2; bvy = ofs; rotv(jab[3]);      /* the near end, behind the tip */
;          p0x = jx[3] + vx;  p0y = jy[3] + vy;
;          bvx =  8; bvy = ofs; rotv(jab[3]);      /* the far end: a TILTED base   */
;          p1x = jx[3] + vx;  p1y = jy[3] + vy;    /*  vector, all four products   */
;          col = 12;  line();                      /*  earn their keep this time   */
;      }
OneJaw: mov  [jofs], al         ; jofs = ofs
        mov  byte [bvx], -2     ; bvx = -2: the near end, just behind the tip
        mov  al, [jofs]         ; AL = ofs
        mov  [bvy], al          ; bvy = ofs
        mov  al, [jab+3]        ; AL = jab[3], the gripper's absolute angle
        call RotV               ; rotv(jab[3])
        mov  ax, [jx+6]         ; AX = jx[3], the tip
        add  ax, [vx]           ; AX = jx[3] + vx
        mov  [p0x], ax          ; p0x = AX
        mov  ax, [jy+6]         ; AX = jy[3]
        add  ax, [vy]           ; AX = jy[3] + vy
        mov  [p0y], ax          ; p0y = AX
        mov  byte [bvx], 8      ; bvx = 8: ...and the far end - a TILTED base
        mov  al, [jofs]         ; AL = ofs   vector, so all four of the matrix's
        mov  [bvy], al          ; bvy = ofs  products earn their keep this time
        mov  al, [jab+3]        ; AL = jab[3]
        call RotV               ; rotv(jab[3])
        mov  ax, [jx+6]         ; AX = jx[3]
        add  ax, [vx]           ; AX = jx[3] + vx
        mov  [p1x], ax          ; p1x = AX
        mov  ax, [jy+6]         ; AX = jy[3]
        add  ax, [vy]           ; AX = jy[3] + vy
        mov  [p1y], ax          ; p1y = AX
        mov  byte [col], 12     ; col = 12, red
        call Line               ; line()
        ret                     ; return

; ---- the cell: the floor, and the two fixtures the chain chose ----------
;  In C:   col = 8;  line(0, GROUND, 319, GROUND);
Ground: mov  word [p0x], 0      ; p0x = 0
        mov  word [p0y], GROUND ; p0y = GROUND
        mov  word [p1x], W-1    ; p1x = 319
        mov  word [p1y], GROUND ; p1y = GROUND
        mov  byte [col], 8      ; col = 8, grey
        call Line               ; line()
        ret                     ; return

;  In C:   one_fix(pax, pay);  one_fix(pbx, pby);
Fixt:   mov  ax, [pax]          ; AX = pax  \  the left fixture
        mov  bx, [pay]          ; BX = pay  /
        call OneFix             ; one_fix(pax, pay)
        mov  ax, [pbx]          ; AX = pbx  \  the right fixture
        mov  bx, [pby]          ; BX = pby  /
        call OneFix             ; one_fix(pbx, pby)
        ret                     ; return

;  In C:   void one_fix(int x, int y) { fill_rect(x - 9, y + 5, 19, 5, 6); }
OneFix: sub  ax, 9              ; AX = x - 9
        mov  [frx], ax          ; frx = x - 9: a 19-wide plate, centred
        add  bx, 5              ; BX = y + 5
        mov  [fry], bx          ; fry = y + 5: just under the tip
        mov  word [frw], 19     ; frw = 19
        mov  word [frh], 5      ; frh = 5
        mov  byte [frcol], 6    ; frcol = 6, brown
        call FillR              ; fill_rect()
        ret                     ; return

;  In C:   fill_rect(cbx - 4, cby - 4, 8, 8, 11);
Cube:   mov  ax, [cbx]          ; AX = cbx
        sub  ax, 4              ; AX = cbx - 4
        mov  [frx], ax          ; frx = cbx - 4
        mov  ax, [cby]          ; AX = cby
        sub  ax, 4              ; AX = cby - 4
        mov  [fry], ax          ; fry = cby - 4
        mov  word [frw], 8      ; frw = 8
        mov  word [frh], 8      ; frh = 8
        mov  byte [frcol], 11   ; frcol = 11, cyan
        call FillR              ; fill_rect()
        ret                     ; return

; ---- CubeFollow: THE GRAB, entire. -------------------------------------
;  The cube is a body with a parent column, exactly like lesson 12's sky.
;  While that column says 3 it is a child of the gripper and rides the
;  tip; while it says FF the world holds it and it does not move. Closing
;  the jaws writes one byte. Nothing else in this program knows what
;  "holding" means.
;  In C:   if (cpar == 3) { cbx = jx[3];  cby = jy[3]; }
CubeFollow:
        cmp  byte [cpar], 3     ; cpar == 3 ?  (the gripper's)
        jne  .no                ;   no: the world holds it, it stays
        mov  ax, [jx+6]         ; AX = jx[3], the tip
        mov  [cbx], ax          ; cbx = jx[3]
        mov  ax, [jy+6]         ; AX = jy[3]
        mov  [cby], ax          ; cby = jy[3]
.no:    ret                     ; return

; ============================================================================
;  Panel - the instruments. NOT prose: two numbers a motor, in hex, in the
;  colour of the link they drive.
;
;      left   the motor's OWN angle - what its shaft was told to do
;      right  the ABSOLUTE angle it adds up to - where the link points
;
;  Move one motor and watch the left column freeze while the right column
;  runs. The BIOS teletype draws these: in a graphics mode it still knows
;  how, out of the ROM font, and it costs this program no font of its own.
; ============================================================================
;  In C:
;
;      void panel(void)
;      {
;          for (int j = 1; j < NJ; j++) {
;              pcol = ARM[j].ink;
;              gotoxy(0, j - 1);  put_hex(ARM[j].own);   /* OWN      */
;              gotoxy(3, j - 1);  put_hex(jab[j]);       /* ABSOLUTE */
;          }
;      }
Panel:  mov  si, ARM+JROW       ; SI = &ARM[1]
        mov  byte [pj], 1       ; j = 1
        mov  byte [prow], 0     ; row = 0
.r:     mov  al, [si+3]         ; AL = ARM[j].ink
        mov  [pcol], al         ; pcol = AL
        mov  dh, [prow]         ; DH = row   \  gotoxy(0, row)
        mov  dl, 0              ; DL = 0     /
        push si                 ; keep the row
        call Goto               ; gotoxy()
        pop  si                 ; row back
        mov  al, [si+1]         ; AL = ARM[j].own: OWN
        push si                 ; keep the row
        call PutB               ; put_hex(own)
        pop  si                 ; row back
        mov  dh, [prow]         ; DH = row   \  gotoxy(3, row)
        mov  dl, 3              ; DL = 3     /
        push si                 ; keep the row
        call Goto               ; gotoxy()
        pop  si                 ; row back
        mov  bl, [pj]           ; BL = j
        xor  bh, bh             ; BX = j
        mov  al, [jab+bx]       ; AL = jab[j]: ABSOLUTE
        push si                 ; keep the row
        call PutB               ; put_hex(jab[j])
        pop  si                 ; row back
        inc  byte [prow]        ; row++
        inc  byte [pj]          ; j++
        add  si, JROW           ; SI += 4: the next row
        cmp  byte [pj], NJ      ; j < NJ ?
        jb   .r                 ;   yes: next motor
        ret                     ; return

;  In C:   gotoxy(DL, DH)   - BIOS 10h, service 2: put the cursor where the number goes
Goto:   mov  ah, 2              ; AH = 2: set cursor position
        xor  bh, bh             ; BH = 0: page 0
        int  10h                ; gotoxy(DL, DH)
        ret                     ; return

;  In C:   void put_hex(int b) { put_nibble(b >> 4);  put_nibble(b & 15); }
PutB:   push ax                 ; keep b
        mov  cl, 4              ; CL = 4
        shr  al, cl             ; AL = b >> 4: the high nibble
        call PutN               ; put_nibble(b >> 4)
        pop  ax                 ; AL = b
        and  al, 0Fh            ; AL = b & 15: the low nibble, and fall into...
;  In C:   void put_nibble(int n) { putch(n < 10 ? '0' + n : 'A' + n - 10); }
PutN:   cmp  al, 10             ; n < 10 ?
        jb   .d                 ;   yes: a digit
        add  al, 'A'-10         ;   no:  AL = 'A' + n - 10
        jmp  .w                 ; over the digit case
.d:     add  al, '0'            ; AL = '0' + n
.w:     mov  ah, 0Eh            ; AH = 0Eh: BIOS teletype, and in mode 13h
        mov  bl, [pcol]         ; BL = pcol   BL is the ink
        xor  bh, bh             ; BH = 0: page 0
        int  10h                ; putch(AL)
        ret                     ; return

; ---- Paint: the whole picture, on whatever is already on the screen -----
;  In C:   ground(); fixt(); draw_arm(); motors(); jaws(); cube(); panel();
Paint:  call Ground             ; ground()
        call Fixt               ; fixt()
        call DrawArm            ; draw_arm()
        call Motors             ; motors()
        call Jaws               ; jaws()
        call Cube               ; cube()
        call Panel              ; panel()
        ret                     ; return

; ---- Frame: a moving picture - wipe on the retrace, then paint ----------
;  Kept apart from Paint on purpose: the reach stage paints the arm ON TOP
;  of ink it must not wipe, and one routine that always wiped destroyed
;  exactly that picture the first time it ran.
;  In C:   chain(); cube_follow(); vsync(); gclear(); paint();
Frame:  call Chain              ; chain()
        call CubeFollow         ; cube_follow()
        call Vsync              ; vsync()
        call GClear             ; gclear()
        call Paint              ; paint()
        ret                     ; return

; ---- SweepRun: drive ONE motor to and fro until a key stops it ----------
;  in: [swj] which motor, [swlo]..[swhi] how far, [swd] which way
;  In C:
;
;      void sweep_run(void)
;      {
;          do {
;              frame();
;              ARM[swj].own += swd;
;              if (ARM[swj].own == swhi) swd = -swd;     /* the far stop  */
;              if (ARM[swj].own == swlo) swd = -swd;     /* the near stop */
;          } while (!key_check());
;      }
SweepRun:
.f:     call Frame              ; frame()
        mov  al, [swj]          ; AL = swj, which motor
        mov  cl, JROW           ; CL = 4
        mul  cl                 ; AX = swj * 4
        add  ax, ARM+1          ; AX = &ARM[swj].own: the own-angle byte of that row
        mov  si, ax             ; SI = that
        mov  al, [si]           ; AL = own
        add  al, [swd]          ; AL = own + swd
        mov  [si], al           ; ARM[swj].own = AL
        cmp  al, [swhi]         ; own == swhi ?
        jne  .n1                ;   no
        neg  byte [swd]         ;   yes: swd = -swd
.n1:    cmp  al, [swlo]         ; own == swlo ?
        jne  .n2                ;   no
        neg  byte [swd]         ;   yes: swd = -swd
.n2:    call KeyChk             ; AL = key_check()
        or   al, al             ; a key ?
        jz   .f                 ;   no: another frame
        ret                     ; return

; ---- the motors, eased one step a frame toward the waypoint -------------
;  The step is chosen by SUBTRACTING the angles: on a circle of 256 that
;  difference IS the short way round, already carrying its sign. No
;  comparison, no special case at the wrap - the byte did it.
;  In C:
;
;      void step_j(void)
;      {
;          for (int j = 1; j <= 3; j++) {
;              signed char d = TG[j-1] - ARM[j].own;   /* a BYTE: the short way round, signed */
;              if (d > 0) ARM[j].own++;
;              if (d < 0) ARM[j].own--;
;          }
;      }
StepJ:  mov  si, ARM+JROW       ; SI = &ARM[1]
        mov  di, TG             ; DI = &TG[0]
        mov  cx, 3              ; CX = 3 motors
.j:     mov  al, [di]           ; AL = TG[j-1], the target
        sub  al, [si+1]         ; AL = target - own: the SHORT way round, signed
        jz   .n                 ; d == 0 ? there already
        js   .neg               ; d < 0 ?  the other way
        inc  byte [si+1]        ; ARM[j].own++
        jmp  .n                 ; over the other case
.neg:   dec  byte [si+1]        ; ARM[j].own--
.n:     add  si, JROW           ; SI += 4: the next row
        inc  di                 ; DI++: the next target
        loop .j                 ; 3 motors
        ret                     ; return

;  In C:   if (jawt > jaw) jaw++;  else if (jawt < jaw) jaw--;
StepJaw:
        mov  al, [jawt]         ; AL = jawt, the target
        cmp  al, [jaw]          ; jawt == jaw ?
        je   .n                 ;   yes: there already
        jb   .dn                ; jawt < jaw ?
        inc  byte [jaw]         ;   no:  jaw++
        ret                     ; return
.dn:    dec  byte [jaw]         ;   yes: jaw--
.n:     ret                     ; return

;  In C:
;
;      int arrived(void)
;      {
;          for (int j = 1; j <= 3; j++) if (TG[j-1] != ARM[j].own) return 0;
;          return jawt == jaw;
;      }
Arrived:
        mov  si, ARM+JROW       ; SI = &ARM[1]
        mov  di, TG             ; DI = &TG[0]
        mov  cx, 3              ; CX = 3 motors
.j:     mov  al, [di]           ; AL = TG[j-1]
        cmp  al, [si+1]         ; TG[j-1] == ARM[j].own ?
        jne  .no                ;   no: return 0
        add  si, JROW           ; SI += 4
        inc  di                 ; DI++
        loop .j                 ; 3 motors
        mov  al, [jawt]         ; AL = jawt
        cmp  al, [jaw]          ; jawt == jaw ?
        jne  .no                ;   no: return 0
        mov  al, 1              ; AL = 1
        ret                     ; return 1
.no:    xor  al, al             ; AL = 0
        ret                     ; return 0

;  In C:
;
;      void set_wp(void)
;      {
;          char *w = WP + wpi * WROW;
;          TG[0] = w[0];  TG[1] = w[1];  TG[2] = w[2];
;          jawt = w[3] ? JCLOSE : JOPEN;
;      }
SetWP:  mov  al, [wpi]          ; AL = wpi
        mov  cl, WROW           ; CL = 4
        mul  cl                 ; AX = wpi * 4
        add  ax, WP             ; AX = &WP[wpi]
        mov  si, ax             ; SI = w
        mov  al, [si]           ; AL = w[0]
        mov  [TG], al           ; TG[0] = w[0]
        mov  al, [si+1]         ; AL = w[1]
        mov  [TG+1], al         ; TG[1] = w[1]
        mov  al, [si+2]         ; AL = w[2]
        mov  [TG+2], al         ; TG[2] = w[2]
        mov  byte [jawt], JOPEN ; jawt = JOPEN
        cmp  byte [si+3], 0     ; w[3] ?  (the grip flag)
        je   .o                 ;   no: open
        mov  byte [jawt], JCLOSE ;  yes: jawt = JCLOSE
.o:     ret                     ; return

;  In C:
;
;      void advance(void)
;      {
;          if (!arrived()) return;
;          cpar = (jawt == JCLOSE) ? 3 : 0xFF;   /* the gripper's, or the world's */
;          if (++wpi >= NWP) wpi = 0;
;          set_wp();
;      }
Advance:
        call Arrived            ; AL = arrived()
        or   al, al             ; arrived ?
        jz   .out               ;   no: return
        mov  byte [cpar], 0FFh  ; cpar = FF: ...the world takes it back...
        cmp  byte [jawt], JCLOSE ; jawt == JCLOSE ?
        jne  .next              ;   no
        mov  byte [cpar], 3     ;   yes: cpar = 3, ...or the gripper does. ONE BYTE
.next:  inc  byte [wpi]         ; wpi++
        cmp  byte [wpi], NWP    ; wpi < NWP ?
        jb   .set               ;   yes
        mov  byte [wpi], 0      ;   no: wpi = 0, round again
.set:   call SetWP              ; set_wp()
.out:   ret                     ; return

; ============================================================================
;  THE ARM, as a table. Parent, own angle, length, ink - four bytes a link,
;  and row 0 is the base: it has no parent, no length, and never moves.
; ============================================================================
ARM     db 0FFh,  0,  0,  7     ; the base - the shoulder's pivot
        db 0,    64, 52, 10     ; the upper arm, green: lesson 10's colour
        db 1,   192, 42, 14     ; the forearm, yellow
        db 2,     0, 18, 12     ; the gripper, red

; ---- the job, as waypoints: three angles and a grip flag ---------------
;  Every working pose puts the gripper's ABSOLUTE angle at 192 - straight
;  down - though no line of this table says so. The three own angles add
;  up to it. That is a real robot keeping its tool level, done by
;  arithmetic and nothing else.
WP      db  96, 48, 48, 0       ;  0  above the left fixture
        db  96, 64, 32, 0       ;  1  down on it            <- pose A
        db  96, 64, 32, 1       ;  2  CLOSE - the cube changes parent
        db  96, 48, 48, 1       ;  3  lift
        db  32,208,208, 1       ;  4  across
        db  32,192,224, 1       ;  5  down on the right     <- pose B
        db  32,192,224, 0       ;  6  OPEN - the world has it again
        db  32,208,208, 0       ;  7  stand off
        db  32,192,224, 0       ;  8  down again
        db  32,192,224, 1       ;  9  CLOSE
        db  32,208,208, 1       ; 10  lift
        db  96, 48, 48, 1       ; 11  back across
        db  96, 64, 32, 1       ; 12  down on the left
        db  96, 64, 32, 0       ; 13  OPEN
        db  96, 48, 48, 0       ; 14  stand off, and round again

HOME    db  64,192,  0, 0       ; the pose it rests in

; ---- state --------------------------------------------------------------
jx      dw BX0                  ; where every joint stands NOW. Joint 0 is
        dw 3 dup (0)            ;  minted on its throne; the chain fills
jy      dw BY0                  ;  the rest, parents first, every frame.
        dw 3 dup (0)
jab     db 0                    ; and where each link POINTS - the sums
        db 3 dup (0)
ji      dw 1                    ; the chain's walking index

bvx     db 0                    ; the matrix's window: base vector in...
bvy     db 0
vx      dw 0                    ; ...turned vector out
vy      dw 0
tsin    db 0                    ; the two ratios, parked for four products
tcos    db 0

RINGX   db 32 dup (0)           ; the motor ring, minted once at boot
RINGY   db 32 dup (0)
rk      db 0
mj      dw 1
mcx     dw 0
mcy     dw 0
arca    db 0                    ; the wedge: where it is, how much is left
arcn    db 0                    ;  to sweep, and which way round it goes
arcd    db 8

jaw     db JOPEN                ; how far the jaws stand apart
jawt    db JOPEN
jofs    db 0

cbx     dw 0                    ; the cube: where it is...
cby     dw 0
cpar    db 0FFh                 ; ...and WHOSE it is. FF the world, 3 the
                                ;  gripper. That is the whole of holding.
pax     dw 0                    ; the two fixtures, placed by the chain
pay     dw 0
pbx     dw 0
pby     dw 0

TG      db 0,0,0                ; the three angles this waypoint wants
wpi     db 0

swj     db 1                    ; which motor a sweep drives, and how far
swlo    db 0
swhi    db 0
swd     db 1

pj      db 1                    ; the instrument panel's own counters
prow    db 0
pcol    db 15
tick    db 0

include 'SINTAB.INC'
include 'DRAW13.INC'

; ============================================================================
;  In C:
;
;      int main(void)
;      {
;          set_mode(0x13);  make_ring();
;          pose(WP[1]); chain(); pax = jx[3]; pay = jy[3];    /* where pose A lands */
;          pose(WP[5]); chain(); pbx = jx[3]; pby = jy[3];    /* where pose B lands */
;          cbx = pax;  cby = pay;                             /* the cube, on the left */
;          pose(HOME); frame(); key();                                          /* 1 */
;          pose(HOME); swj = 1; swlo =  32; swhi =  96; swd = 1; sweep_run();   /* 2 */
;          pose(HOME); swj = 2; swlo = 160; swhi = 224; swd = 1; sweep_run();   /* 3 */
;          pose(HOME); swj = 3; swlo =   0; swhi =  64; swd = 1; sweep_run();   /* 4 */
;          ...the reach, then the job - below...
;      }
Boot:   cld                     ; string ops count UP (STOSW in GClear)
        mov  ax, 0013h          ; AX = 13h: the graphics screen, 320x200
        int  10h                ; set_mode(0x13)
        mov  ax, VGA            ; AX = A000h
        mov  es, ax             ; ES = the screen, for the whole program
        call MakeRing           ; make_ring()

; ---- ask the chain where the two working poses put the tip, and put a
;      fixture there. Nobody types these numbers: the arithmetic that
;      reaches the cube is the same arithmetic that placed it.
        mov  si, WP + 1*WROW    ; SI = &WP[1]: pose A
        call Pose               ; pose(WP[1])
        call Chain              ; chain()
        mov  ax, [jx+6]         ; AX = jx[3], the tip
        mov  [pax], ax          ; pax = jx[3]
        mov  ax, [jy+6]         ; AX = jy[3]
        mov  [pay], ax          ; pay = jy[3]
        mov  si, WP + 5*WROW    ; SI = &WP[5]: pose B
        call Pose               ; pose(WP[5])
        call Chain              ; chain()
        mov  ax, [jx+6]         ; AX = jx[3]
        mov  [pbx], ax          ; pbx = jx[3]
        mov  ax, [jy+6]         ; AX = jy[3]
        mov  [pby], ax          ; pby = jy[3]
        mov  ax, [pax]          ; AX = pax: the cube starts on the left fixture
        mov  [cbx], ax          ; cbx = pax
        mov  ax, [pay]          ; AX = pay
        mov  [cby], ax          ; cby = pay

; ---- 1. standing ---------------------------------------------------------
        mov  si, HOME           ; SI = HOME
        call Pose               ; pose(HOME)
        call Frame              ; frame()
        call Key                ; key()

; ---- 2. the shoulder alone ----------------------------------------------
        mov  si, HOME           ; SI = HOME
        call Pose               ; pose(HOME)
        mov  byte [swj], 1      ; swj = 1: the shoulder
        mov  byte [swlo], 32    ; swlo = 32
        mov  byte [swhi], 96    ; swhi = 96
        mov  byte [swd], 1      ; swd = 1
        call SweepRun           ; sweep_run(): one motor moves - every needle turns

; ---- 3. the elbow alone --------------------------------------------------
        mov  si, HOME           ; SI = HOME
        call Pose               ; pose(HOME)
        mov  byte [swj], 2      ; swj = 2: the elbow
        mov  byte [swlo], 160   ; swlo = 160
        mov  byte [swhi], 224   ; swhi = 224
        mov  byte [swd], 1      ; swd = 1
        call SweepRun           ; sweep_run(): the shoulder's needle stands still now

; ---- 4. the wrist alone --------------------------------------------------
        mov  si, HOME           ; SI = HOME
        call Pose               ; pose(HOME)
        mov  byte [swj], 3      ; swj = 3: the wrist
        mov  byte [swlo], 0     ; swlo = 0
        mov  byte [swhi], 64    ; swhi = 64
        mov  byte [swd], 1      ; swd = 1
        call SweepRun           ; sweep_run(): the end of the chain moves nothing else

; ---- 5. the reach: only the tip inks ------------------------------------
;      No arm is drawn and the screen is never wiped, so what fills in is
;      every place this machine can put its hand. A robot's WORKSPACE,
;      and no line of code has heard the word.
;  In C, the reach:
;
;      pose(HOME); gclear(); ground(); swd = 1; tick = 0;
;      do {
;          vsync(); chain();
;          dcol = 3; plot(jx[3], jy[3]);                 /* only the tip inks   */
;          ARM[2].own += 4;  if (ARM[2].own > 220) ARM[2].own = 40;   /* elbow: fast */
;          if ((++tick & 3) == 0) {                      /* shoulder: one in four */
;              ARM[1].own += swd;
;              if (ARM[1].own == 96) swd = -swd;
;              if (ARM[1].own == 32) swd = -swd;
;          }
;      } while (!key_check());
;      chain(); paint(); key();                          /* the arm on top, nothing wiped */
        mov  si, HOME           ; SI = HOME
        call Pose               ; pose(HOME)
        call GClear             ; gclear()
        call Ground             ; ground(): the floor stays, so the shape has a
        mov  byte [swd], 1      ; swd = 1    world to be measured against
        mov  byte [tick], 0     ; tick = 0
.sp:    call Vsync              ; vsync()
        call Chain              ; chain()
        mov  byte [dcol], 3     ; dcol = 3, cyan
        mov  ax, [jx+6]         ; AX = jx[3]  \  plot(jx[3], jy[3])
        mov  bx, [jy+6]         ; BX = jy[3]  /
        call Plot               ; plot(): only the tip inks
        mov  al, [ARM+2*JROW+1] ; AL = ARM[2].own: the elbow sweeps fast...
        add  al, 4              ; AL += 4
        cmp  al, 220            ; > 220 ?
        jbe  .k1                ;   no
        mov  al, 40             ;   yes: AL = 40, round again
.k1:    mov  [ARM+2*JROW+1], al ; ARM[2].own = AL
        inc  byte [tick]        ; tick++
; ---- TEST is new: it ANDs its two operands, sets the flags, and THROWS
;      THE ANSWER AWAY. CMP is to SUB what TEST is to AND - the arithmetic
;      happens, only the verdict is kept. Here it asks "are the bottom two
;      bits both zero?", which is a counter divisible by four, without
;      dividing anything. Its trap is AND, which looks identical and
;      QUIETLY DESTROYS the register it tested.
        test byte [tick], 3     ; (tick & 3) == 0 ?  ...and the shoulder crawls,
        jnz  .k2                ;   no: skip     one step in four, so the two
        mov  al, [ARM+1*JROW+1] ; AL = ARM[1].own   never fall in step
        add  al, [swd]          ; AL += swd
        mov  [ARM+1*JROW+1], al ; ARM[1].own = AL
        cmp  al, 96             ; own == 96 ?
        jne  .k3                ;   no
        neg  byte [swd]         ;   yes: swd = -swd
.k3:    cmp  al, 32             ; own == 32 ?
        jne  .k2                ;   no
        neg  byte [swd]         ;   yes: swd = -swd
.k2:    call KeyChk             ; AL = key_check()
        or   al, al             ; a key ?
        jz   .sp                ;   no: another frame
        call Chain              ; chain(): the arm, put back on top of its own reach
        call Paint              ; paint() - PAINT, not Frame: nothing is wiped
        call Key                ; key()

; ---- 6. the job, for ever ------------------------------------------------
;  In C:
;
;      pose(WP[0]); wpi = 0; set_wp(); cbx = pax; cby = pay; cpar = 0xFF;
;      do { step_j(); step_jaw(); frame(); advance(); } while (!key_check());
        mov  si, WP             ; SI = &WP[0]
        call Pose               ; pose(WP[0])
        mov  byte [wpi], 0      ; wpi = 0
        call SetWP              ; set_wp()
        mov  ax, [pax]          ; AX = pax   \  the cube back on the left
        mov  [cbx], ax          ; cbx = pax   >
        mov  ax, [pay]          ; AX = pay    >
        mov  [cby], ax          ; cby = pay  /
        mov  byte [cpar], 0FFh  ; cpar = FF: the world's
.jb:    call StepJ              ; step_j()
        call StepJaw            ; step_jaw()
        call Frame              ; frame()
        call Advance            ; advance()
        call KeyChk             ; AL = key_check()
        or   al, al             ; a key ?
        jz   .jb                ;   no: another frame

Bye:    mov  ax, 0003h          ; AX = 3: a clean screen back to DOS
        int  10h                ; set_mode(3)
        mov  ax, 4C00h          ; AH = 4Ch exit, AL = 0 the code
        int  21h                ; exit(0)
