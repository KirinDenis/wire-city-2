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

        jmp  Boot

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
RotV:   push ax
        mov  bx, SINTAB
        xlatb                   ; AL = sin(a), -127..127
        mov  [tsin], al         ; parked: four products want both ratios
        pop  ax
        add  al, 64             ; cos(a) = sin(a + a quarter-turn)
        xlatb
        mov  [tcos], al
        mov  al, [tcos]
        imul byte [bvx]         ; x*cos, sign kept
        mov  dx, ax
        mov  al, [tsin]
        imul byte [bvy]         ; y*sin
        sub  dx, ax             ; x' = x*cos - y*sin, in 128ths
        mov  cl, 7
        sar  dx, cl             ; /128 as a SHIFT: the table speaks 128ths
        mov  [vx], dx
        mov  al, [tsin]
        imul byte [bvx]         ; x*sin
        mov  dx, ax
        mov  al, [tcos]
        imul byte [bvy]         ; y*cos
        add  dx, ax             ; y' = x*sin + y*cos
        sar  dx, cl
        neg  dx                 ; THE MINUS: screen y grows down the tube
        mov  [vy], dx
        ret

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
Chain:  mov  si, ARM+JROW       ; row 1: the first link. Row 0 is the base,
        mov  word [ji], 1       ;  which asks nothing and never moves.
        mov  cx, NJ-1
.j:     push cx
        mov  bl, [si]           ; whose child is it?
        xor  bh, bh
        mov  al, [jab+bx]       ; the PARENT's absolute angle...
        add  al, [si+1]         ; ...plus this motor's OWN angle. THAT IS
        mov  bx, [ji]           ;  THE INHERITANCE, and that is the whole
        mov  [jab+bx], al       ;  instruction. A byte, so it wraps itself.
        mov  bl, [si+2]         ; the link's length becomes the base
        mov  [bvx], bl          ;  vector: a stick lying east...
        mov  byte [bvy], 0
        mov  bx, [ji]
        mov  al, [jab+bx]       ; ...turned by where this link points
        push si
        call RotV
        pop  si
        mov  di, [ji]
        add  di, di             ; a joint is a WORD: index -> offset
        mov  bl, [si]
        xor  bh, bh
        add  bx, bx
        mov  ax, [jx+bx]        ; ME = PARENT...
        add  ax, [vx]           ; ...+ MATRIX x (LENGTH, 0)
        mov  [jx+di], ax
        mov  ax, [jy+bx]
        add  ax, [vy]
        mov  [jy+di], ax
        inc  word [ji]
        add  si, JROW
        pop  cx
        loop .j
        ret

; ---- Pose: put a waypoint's three angles straight into the motors -------
;  in: SI = a waypoint row. Used at boot to ASK the chain where a pose
;  puts the tip, before anything is drawn.
Pose:   mov  al, [si]
        mov  [ARM+1*JROW+1], al
        mov  al, [si+1]
        mov  [ARM+2*JROW+1], al
        mov  al, [si+2]
        mov  [ARM+3*JROW+1], al
        ret

; ============================================================================
;  MakeRing - the thirty-two dots of a motor ring, minted ONCE.
;
;  The ring never changes shape, so it is not recomputed every frame: the
;  matrix is asked thirty-two times at boot and after that a motor costs
;  thirty-two ADDs. This is the lesson-4 habit, kept.
; ============================================================================
MakeRing:
        xor  si, si
        mov  byte [rk], 0
.r:     mov  byte [bvx], MR
        mov  byte [bvy], 0
        mov  al, [rk]
        push si
        call RotV
        pop  si
        mov  ax, [vx]
        mov  [RINGX+si], al
        mov  ax, [vy]
        mov  [RINGY+si], al
        add  byte [rk], 8       ; 256/32: a full turn in thirty-two steps
        inc  si
        cmp  si, 32
        jb   .r
        ret

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
Motors: mov  si, ARM+JROW
        mov  word [mj], 1
.m:     mov  bx, [mj]
        dec  bx                 ; the pivot is the PARENT's end
        add  bx, bx
        mov  ax, [jx+bx]
        mov  [mcx], ax
        mov  ax, [jy+bx]
        mov  [mcy], ax
        mov  al, [si+3]         ; the ring wears its link's colour
        mov  [dcol], al
        push si
        xor  si, si
; ---- CBW is new: Convert Byte to Word. It copies bit 7 of AL over the
;      whole of AH, so a signed byte becomes the same number as a signed
;      word: 0FFh (minus one) becomes 0FFFFh (still minus one), and 7 stays
;      7. It touches AH and nothing else - NO FLAGS. Without it, a ring
;      offset of minus five would arrive as plus two hundred and fifty one
;      and the ring would be drawn a screen away. Its trap is CWD, which
;      does the same trick one size up, AX into DX:AX.
.d:     mov  al, [RINGY+si]     ; the ring: thirty-two adds and no maths
        cbw                     ; signed byte -> signed word, sign kept
        add  ax, [mcy]
        mov  bx, ax
        mov  al, [RINGX+si]
        cbw
        add  ax, [mcx]
        push si
        call Plot
        pop  si
        inc  si
        cmp  si, 32
        jb   .d
        pop  si

; ---- the WEDGE: from this motor's zero round to where its link points.
;      One dot every eight steps of angle, so the arc is as long as the
;      own angle is big - the own angle, made into a thing you can see.
;      Swept the SHORT way: past a half turn it goes round the other side,
;      which is the angle a human would have measured anyway.
        mov  bx, [mj]
        dec  bx
        mov  al, [jab+bx]       ; start at the parent's angle: the zero
        mov  [arca], al
        mov  al, [si+1]         ; and sweep this motor's own angle
        cmp  al, 128
        jb   .wp
        neg  al                 ; past half a turn: 256 - own, the other way
        mov  byte [arcd], -8
        jmp  .wn
.wp:    mov  byte [arcd], 8
.wn:    mov  [arcn], al
.w:     cmp  byte [arcn], 8
        jb   .wd
        mov  byte [bvx], MARC
        mov  byte [bvy], 0
        mov  al, [arca]
        push si
        call RotV
        pop  si
        mov  ax, [mcy]
        add  ax, [vy]
        mov  bx, ax
        mov  ax, [mcx]
        add  ax, [vx]
        push si
        call Plot
        pop  si
        mov  al, [arcd]
        add  [arca], al
        sub  byte [arcn], 8
        jmp  .w

; ---- the ZERO RAY: the parent's direction, CONTINUED through the joint.
;      It is where this link would point if this motor stood at zero, and
;      it is the one line the skeleton alone can never show you - the
;      parent's link arrives from the opposite side. At the shoulder the
;      parent is the world, so this ray is the horizon, and it is the only
;      mark in the whole picture entitled to stand still.
.wd:    mov  bx, [mj]
        dec  bx
        mov  byte [bvx], MTIN
        mov  byte [bvy], 0
        mov  al, [jab+bx]
        push si
        call RotV
        pop  si
        mov  ax, [mcx]
        add  ax, [vx]
        mov  [p0x], ax
        mov  ax, [mcy]
        add  ax, [vy]
        mov  [p0y], ax
        mov  bx, [mj]
        dec  bx
        mov  byte [bvx], MTOUT
        mov  byte [bvy], 0
        mov  al, [jab+bx]
        push si
        call RotV
        pop  si
        mov  ax, [mcx]
        add  ax, [vx]
        mov  [p1x], ax
        mov  ax, [mcy]
        add  ax, [vy]
        mov  [p1y], ax
        mov  byte [col], 8
        push si
        call Line
        pop  si

; ---- the BALL: a bead on the rim where the link crosses it - the SHAFT.
;      No needle is drawn to it, because the link IS the needle: it leaves
;      the joint in exactly this direction. The bead is white and fat so
;      that the eye is caught by the thing that moves, which was the whole
;      fault of the first version.
        mov  bx, [mj]
        mov  byte [bvx], MR
        mov  byte [bvy], 0
        mov  al, [jab+bx]
        push si
        call RotV
        pop  si
        mov  byte [dcol], 15
        mov  ax, [mcy]
        add  ax, [vy]
        mov  bx, ax
        mov  ax, [mcx]
        add  ax, [vx]
        push si
        call Dot
        pop  si
        inc  word [mj]
        add  si, JROW
        cmp  word [mj], NJ      ; this loop body is longer than 127 bytes,
        jae  .done              ;  so a JB back to the top would have to be
        jmp  .m                 ;  a 386 long jump. Invert it and jump over
.done:  ret                     ;  a plain JMP instead: this is an 8086.

; ---- DrawArm: the pillar, then the three links in their own inks --------
DrawArm:
        mov  word [p0x], BX0
        mov  word [p0y], GROUND
        mov  word [p1x], BX0
        mov  word [p1y], BY0
        mov  byte [col], 7
        call Line
        mov  si, ARM+JROW
        mov  di, 2
.l:     mov  bl, [si]
        xor  bh, bh
        add  bx, bx
        mov  ax, [jx+bx]
        mov  [p0x], ax
        mov  ax, [jy+bx]
        mov  [p0y], ax
        mov  ax, [jx+di]
        mov  [p1x], ax
        mov  ax, [jy+di]
        mov  [p1y], ax
        mov  al, [si+3]
        mov  [col], al
        push si
        push di
        call Line
        pop  di
        pop  si
        add  si, JROW
        add  di, 2
        cmp  di, NJ*2
        jb   .l
        ret

; ---- Jaws: two bars beside the gripper's axis, [jaw] out on each side ---
Jaws:   mov  al, [jaw]
        call OneJaw
        mov  al, [jaw]
        neg  al
        call OneJaw
        ret

OneJaw: mov  [jofs], al
        mov  byte [bvx], -2     ; the near end, just behind the tip
        mov  al, [jofs]
        mov  [bvy], al
        mov  al, [jab+3]
        call RotV
        mov  ax, [jx+6]
        add  ax, [vx]
        mov  [p0x], ax
        mov  ax, [jy+6]
        add  ax, [vy]
        mov  [p0y], ax
        mov  byte [bvx], 8      ; ...and the far end - a TILTED base
        mov  al, [jofs]         ;  vector, so all four of the matrix's
        mov  [bvy], al          ;  products earn their keep this time
        mov  al, [jab+3]
        call RotV
        mov  ax, [jx+6]
        add  ax, [vx]
        mov  [p1x], ax
        mov  ax, [jy+6]
        add  ax, [vy]
        mov  [p1y], ax
        mov  byte [col], 12
        call Line
        ret

; ---- the cell: the floor, and the two fixtures the chain chose ----------
Ground: mov  word [p0x], 0
        mov  word [p0y], GROUND
        mov  word [p1x], W-1
        mov  word [p1y], GROUND
        mov  byte [col], 8
        call Line
        ret

Fixt:   mov  ax, [pax]
        mov  bx, [pay]
        call OneFix
        mov  ax, [pbx]
        mov  bx, [pby]
        call OneFix
        ret

OneFix: sub  ax, 9
        mov  [frx], ax
        add  bx, 5
        mov  [fry], bx
        mov  word [frw], 19
        mov  word [frh], 5
        mov  byte [frcol], 6
        call FillR
        ret

Cube:   mov  ax, [cbx]
        sub  ax, 4
        mov  [frx], ax
        mov  ax, [cby]
        sub  ax, 4
        mov  [fry], ax
        mov  word [frw], 8
        mov  word [frh], 8
        mov  byte [frcol], 11
        call FillR
        ret

; ---- CubeFollow: THE GRAB, entire. -------------------------------------
;  The cube is a body with a parent column, exactly like lesson 12's sky.
;  While that column says 3 it is a child of the gripper and rides the
;  tip; while it says FF the world holds it and it does not move. Closing
;  the jaws writes one byte. Nothing else in this program knows what
;  "holding" means.
CubeFollow:
        cmp  byte [cpar], 3
        jne  .no
        mov  ax, [jx+6]
        mov  [cbx], ax
        mov  ax, [jy+6]
        mov  [cby], ax
.no:    ret

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
Panel:  mov  si, ARM+JROW
        mov  byte [pj], 1
        mov  byte [prow], 0
.r:     mov  al, [si+3]
        mov  [pcol], al
        mov  dh, [prow]
        mov  dl, 0
        push si
        call Goto
        pop  si
        mov  al, [si+1]         ; OWN
        push si
        call PutB
        pop  si
        mov  dh, [prow]
        mov  dl, 3
        push si
        call Goto
        pop  si
        mov  bl, [pj]
        xor  bh, bh
        mov  al, [jab+bx]       ; ABSOLUTE
        push si
        call PutB
        pop  si
        inc  byte [prow]
        inc  byte [pj]
        add  si, JROW
        cmp  byte [pj], NJ
        jb   .r
        ret

Goto:   mov  ah, 2              ; put the cursor where the number goes
        xor  bh, bh
        int  10h
        ret

PutB:   push ax                 ; a byte as two hex signs
        mov  cl, 4
        shr  al, cl
        call PutN
        pop  ax
        and  al, 0Fh
PutN:   cmp  al, 10
        jb   .d
        add  al, 'A'-10
        jmp  .w
.d:     add  al, '0'
.w:     mov  ah, 0Eh            ; teletype, and in mode 13h BL is the ink
        mov  bl, [pcol]
        xor  bh, bh
        int  10h
        ret

; ---- Paint: the whole picture, on whatever is already on the screen -----
Paint:  call Ground
        call Fixt
        call DrawArm
        call Motors
        call Jaws
        call Cube
        call Panel
        ret

; ---- Frame: a moving picture - wipe on the retrace, then paint ----------
;  Kept apart from Paint on purpose: the reach stage paints the arm ON TOP
;  of ink it must not wipe, and one routine that always wiped destroyed
;  exactly that picture the first time it ran.
Frame:  call Chain
        call CubeFollow
        call Vsync
        call GClear
        call Paint
        ret

; ---- SweepRun: drive ONE motor to and fro until a key stops it ----------
;  in: [swj] which motor, [swlo]..[swhi] how far, [swd] which way
SweepRun:
.f:     call Frame
        mov  al, [swj]
        mov  cl, JROW
        mul  cl
        add  ax, ARM+1          ; the own-angle byte of that row
        mov  si, ax
        mov  al, [si]
        add  al, [swd]
        mov  [si], al
        cmp  al, [swhi]
        jne  .n1
        neg  byte [swd]
.n1:    cmp  al, [swlo]
        jne  .n2
        neg  byte [swd]
.n2:    call KeyChk
        or   al, al
        jz   .f
        ret

; ---- the motors, eased one step a frame toward the waypoint -------------
;  The step is chosen by SUBTRACTING the angles: on a circle of 256 that
;  difference IS the short way round, already carrying its sign. No
;  comparison, no special case at the wrap - the byte did it.
StepJ:  mov  si, ARM+JROW
        mov  di, TG
        mov  cx, 3
.j:     mov  al, [di]
        sub  al, [si+1]
        jz   .n
        js   .neg
        inc  byte [si+1]
        jmp  .n
.neg:   dec  byte [si+1]
.n:     add  si, JROW
        inc  di
        loop .j
        ret

StepJaw:
        mov  al, [jawt]
        cmp  al, [jaw]
        je   .n
        jb   .dn
        inc  byte [jaw]
        ret
.dn:    dec  byte [jaw]
.n:     ret

Arrived:
        mov  si, ARM+JROW
        mov  di, TG
        mov  cx, 3
.j:     mov  al, [di]
        cmp  al, [si+1]
        jne  .no
        add  si, JROW
        inc  di
        loop .j
        mov  al, [jawt]
        cmp  al, [jaw]
        jne  .no
        mov  al, 1
        ret
.no:    xor  al, al
        ret

SetWP:  mov  al, [wpi]
        mov  cl, WROW
        mul  cl
        add  ax, WP
        mov  si, ax
        mov  al, [si]
        mov  [TG], al
        mov  al, [si+1]
        mov  [TG+1], al
        mov  al, [si+2]
        mov  [TG+2], al
        mov  byte [jawt], JOPEN
        cmp  byte [si+3], 0
        je   .o
        mov  byte [jawt], JCLOSE
.o:     ret

Advance:
        call Arrived
        or   al, al
        jz   .out
        mov  byte [cpar], 0FFh  ; ...the world takes it back...
        cmp  byte [jawt], JCLOSE
        jne  .next
        mov  byte [cpar], 3     ; ...or the gripper does. ONE BYTE.
.next:  inc  byte [wpi]
        cmp  byte [wpi], NWP
        jb   .set
        mov  byte [wpi], 0
.set:   call SetWP
.out:   ret

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
Boot:   cld
        mov  ax, 0013h          ; the graphics screen, 320x200
        int  10h
        mov  ax, VGA
        mov  es, ax
        call MakeRing

; ---- ask the chain where the two working poses put the tip, and put a
;      fixture there. Nobody types these numbers: the arithmetic that
;      reaches the cube is the same arithmetic that placed it.
        mov  si, WP + 1*WROW    ; pose A
        call Pose
        call Chain
        mov  ax, [jx+6]
        mov  [pax], ax
        mov  ax, [jy+6]
        mov  [pay], ax
        mov  si, WP + 5*WROW    ; pose B
        call Pose
        call Chain
        mov  ax, [jx+6]
        mov  [pbx], ax
        mov  ax, [jy+6]
        mov  [pby], ax
        mov  ax, [pax]          ; the cube starts on the left fixture
        mov  [cbx], ax
        mov  ax, [pay]
        mov  [cby], ax

; ---- 1. standing ---------------------------------------------------------
        mov  si, HOME
        call Pose
        call Frame
        call Key

; ---- 2. the shoulder alone ----------------------------------------------
        mov  si, HOME
        call Pose
        mov  byte [swj], 1
        mov  byte [swlo], 32
        mov  byte [swhi], 96
        mov  byte [swd], 1
        call SweepRun           ; one motor moves - and every needle turns

; ---- 3. the elbow alone --------------------------------------------------
        mov  si, HOME
        call Pose
        mov  byte [swj], 2
        mov  byte [swlo], 160
        mov  byte [swhi], 224
        mov  byte [swd], 1
        call SweepRun           ; the shoulder's needle stands still now

; ---- 4. the wrist alone --------------------------------------------------
        mov  si, HOME
        call Pose
        mov  byte [swj], 3
        mov  byte [swlo], 0
        mov  byte [swhi], 64
        mov  byte [swd], 1
        call SweepRun           ; the end of the chain moves nothing else

; ---- 5. the reach: only the tip inks ------------------------------------
;      No arm is drawn and the screen is never wiped, so what fills in is
;      every place this machine can put its hand. A robot's WORKSPACE,
;      and no line of code has heard the word.
        mov  si, HOME
        call Pose
        call GClear
        call Ground             ; the floor stays, so the shape has a
        mov  byte [swd], 1      ;  world to be measured against
        mov  byte [tick], 0
.sp:    call Vsync
        call Chain
        mov  byte [dcol], 3
        mov  ax, [jx+6]
        mov  bx, [jy+6]
        call Plot
        mov  al, [ARM+2*JROW+1] ; the elbow sweeps fast...
        add  al, 4
        cmp  al, 220
        jbe  .k1
        mov  al, 40
.k1:    mov  [ARM+2*JROW+1], al
        inc  byte [tick]
; ---- TEST is new: it ANDs its two operands, sets the flags, and THROWS
;      THE ANSWER AWAY. CMP is to SUB what TEST is to AND - the arithmetic
;      happens, only the verdict is kept. Here it asks "are the bottom two
;      bits both zero?", which is a counter divisible by four, without
;      dividing anything. Its trap is AND, which looks identical and
;      QUIETLY DESTROYS the register it tested.
        test byte [tick], 3     ; ...and the shoulder crawls, one step in
        jnz  .k2                ;  four, so the two never fall in step
        mov  al, [ARM+1*JROW+1]
        add  al, [swd]
        mov  [ARM+1*JROW+1], al
        cmp  al, 96
        jne  .k3
        neg  byte [swd]
.k3:    cmp  al, 32
        jne  .k2
        neg  byte [swd]
.k2:    call KeyChk
        or   al, al
        jz   .sp
        call Chain              ; the arm, put back on top of its own reach
        call Paint              ;  - PAINT, not Frame: nothing is wiped
        call Key

; ---- 6. the job, for ever ------------------------------------------------
        mov  si, WP
        call Pose
        mov  byte [wpi], 0
        call SetWP
        mov  ax, [pax]
        mov  [cbx], ax
        mov  ax, [pay]
        mov  [cby], ax
        mov  byte [cpar], 0FFh
.jb:    call StepJ
        call StepJaw
        call Frame
        call Advance
        call KeyChk
        or   al, al
        jz   .jb

Bye:    mov  ax, 0003h          ; a clean screen back to DOS
        int  10h
        mov  ax, 4C00h
        int  21h
