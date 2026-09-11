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

        jmp  Boot

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
Rot2:   push ax
        mov  bx, SINTAB
        xlatb                   ; AL = sin(a), -127..127
        cbw                     ; ...widened: the coordinates are words now
        mov  [tsin], ax
        pop  ax
        add  al, 64             ; cos(a) = sin(a + a quarter-turn)
        xlatb
        cbw
        mov  [tcos], ax
        mov  ax, [tcos]
        imul word [pa]          ; a*cos - fits AX; DX is only the sign
        mov  [t2], ax
        mov  ax, [tsin]
        imul word [pb]          ; b*sin
        mov  dx, [t2]
        sub  dx, ax             ; a' = a*cos - b*sin, in 128ths
        mov  cl, 7
        sar  dx, cl             ; /128 as a SHIFT, since lesson 10
        mov  [t1], dx           ; PARKED - b' still wants the OLD a
        mov  ax, [tsin]
        imul word [pa]
        mov  [t2], ax
        mov  ax, [tcos]
        imul word [pb]
        add  ax, [t2]           ; b' = a*sin + b*cos
        sar  ax, cl
        mov  [pb], ax
        mov  ax, [t1]           ; ...and only now is a' allowed to land
        mov  [pa], ax
        ret

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
ProjMul:
        imul word [rcp]         ; DX:AX = coord * (d/z * 256)
        mov  al, ah             ; the middle two bytes of the product...
        mov  ah, dl             ;  ...ARE the product divided by 256
        ret

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
Xform:  mov  byte [ok], 1
        mov  si, VERTS
        xor  di, di
        mov  cx, 8
.v:     push cx

        mov  al, [si]           ; ---- MODEL: turn the cube on its own ---
        cbw
        mov  [pa], ax
        mov  al, [si+2]
        cbw
        mov  [pb], ax
        mov  al, [objyaw]       ; about Y, so the pair is (x, z)
        push si
        push di
        call Rot2
        pop  di
        pop  si
        mov  ax, [pa]
        mov  [mx], ax
        mov  ax, [pb]
        mov  [mz], ax
        mov  al, [si+1]         ; ...and its fixed tilt, about X, so the
        cbw                     ;  pair is (y, z). Two turns and a move:
        mov  [pa], ax           ;  THAT IS THE MODEL MATRIX, written out.
        mov  ax, [mz]
        mov  [pb], ax
        mov  al, MPITCH
        push si
        push di
        call Rot2
        pop  di
        pop  si
        mov  ax, [pa]
        mov  [my], ax
        mov  ax, [pb]
        mov  [mz], ax

        mov  ax, [mx]           ; ---- ...and put it where it stands -----
        add  ax, [objx]
        sub  ax, [camx]         ; ---- VIEW: minus where the camera is ---
        mov  [vx], ax
        mov  ax, [my]
        add  ax, [objy]
        sub  ax, [camy]
        mov  [vy], ax
        mov  ax, [mz]
        add  ax, [objz]
        sub  ax, [camz]
        mov  [vz], ax

        mov  ax, [vx]           ; ---- ...and turn by MINUS the yaw ------
        mov  [pa], ax
        mov  ax, [vz]
        mov  [pb], ax
        mov  al, [camyaw]
        neg  al                 ; THE INVERSE OF A TURN, ENTIRE. One byte:
                                ;  transpose a rotation - flip it about its
                                ;  diagonal - and you have the turn back
                                ;  the other way. No divide, no determinant.
        push si
        push di
        call Rot2
        pop  di
        pop  si
        mov  ax, [pa]
        mov  [vx], ax
        mov  ax, [pb]
        mov  [vz], ax

        cmp  word [vz], ZNEAR   ; ---- the near plane, as a TEST ---------
        jl   .drop              ;      lesson 0F's promise, now that the
        cmp  word [vz], ZFAR    ;      camera can move, has to be an IF
        jg   .drop

        mov  bx, [vz]           ; ---- PROJECT: lesson 0F, through RECIP -
        add  bx, bx             ; one word a row
        mov  ax, [RECIP+bx]
        mov  [rcp], ax
        mov  ax, [vx]
        push si
        push di
        call ProjMul
        pop  di
        pop  si
        add  ax, CX0
        mov  [sx+di], ax
        mov  ax, [vy]
        push si
        push di
        call ProjMul
        pop  di
        pop  si
        mov  bx, CY0
        sub  bx, ax             ; THE MINUS: paper y up, the beam draws down
        mov  [sy+di], bx

        mov  ax, [sx+di]        ; ---- and off the glass is dropped too --
        cmp  ax, 4              ;      because Line does not clip, and
        jl   .drop              ;      clipping is a lesson of its own that
        cmp  ax, W-5            ;      this course has not reached. We drop
        jg   .drop              ;      the WHOLE cube - crude, visible, and
        mov  ax, [sy+di]        ;      honest about being the crude answer.
        cmp  ax, 4
        jl   .drop
        cmp  ax, H-5
        jg   .drop

        add  si, 3
        add  di, 2
        pop  cx
        dec  cx                 ; LOOP reaches one signed byte back and this
        jz   .done              ;  body is longer than that. Count by hand,
        jmp  .v                 ;  and let a JMP do the reaching.
.done:  ret
.drop:  mov  byte [ok], 0
        pop  cx
        ret

; ---- Keep: park the eight corners just computed as the OTHER answer -----
Keep:   xor  di, di
        mov  cx, 8
.c:     mov  ax, [sx+di]
        mov  [sxd+di], ax
        mov  ax, [sy+di]
        mov  [syd+di], ax
        add  di, 2
        loop .c
        ret

; ---- the twelve edges, from whichever pair [esrc] points at ------------
;  The y table sits sixteen bytes after the x table, so one routine draws
;  either answer - lesson 0F's pointer, kept.
Edges:  mov  si, EDGES
        mov  cx, NE
.e:     push cx
        mov  bx, [esrc]
        mov  al, [si]
        xor  ah, ah
        add  ax, ax
        add  bx, ax
        mov  ax, [bx]
        mov  [p0x], ax
        mov  ax, [bx+16]
        mov  [p0y], ax
        mov  bx, [esrc]
        mov  al, [si+1]
        xor  ah, ah
        add  ax, ax
        add  bx, ax
        mov  ax, [bx]
        mov  [p1x], ax
        mov  ax, [bx+16]
        mov  [p1y], ax
        mov  al, [ecol]
        mov  [col], al
        push si
        call Line
        pop  si
        add  si, 2
        pop  cx
        loop .e
        ret

; ---- Differ: a red dot on every corner the two answers disagree about --
;  More than ONE pixel apart. Two routes through integer arithmetic will
;  not always round the same way, and painting that red would teach only
;  that rounding exists. Two pixels apart would be a real disagreement.
Differ: xor  di, di
        mov  cx, 8
.d:     push cx
        mov  ax, [sx+di]
        sub  ax, [sxd+di]
        cmp  ax, 1
        jg   .red
        cmp  ax, -1
        jl   .red
        mov  ax, [sy+di]
        sub  ax, [syd+di]
        cmp  ax, 1
        jg   .red
        cmp  ax, -1
        jge  .ok
.red:   mov  byte [dcol], DIFFC
        mov  ax, [sx+di]
        mov  bx, [sy+di]
        push di
        call Dot
        pop  di
.ok:    add  di, 2
        pop  cx
        loop .d
        ret

; ---- the eye's axis where it meets the glass: a small yellow cross -----
Axis:   mov  word [p0x], CX0-5
        mov  word [p1x], CX0+5
        mov  word [p0y], CY0
        mov  word [p1y], CY0
        mov  byte [col], AXISC
        call Line
        mov  word [p0x], CX0
        mov  word [p1x], CX0
        mov  word [p0y], CY0-5
        mov  word [p1y], CY0+5
        mov  byte [col], AXISC
        call Line
        ret

; ---- one whole picture --------------------------------------------------
Frame:  call Vsync
        call GClear
        call Axis
        call Xform
        cmp  byte [ok], 0
        je   .out
        mov  byte [ecol], EDGEC
        mov  word [esrc], sx
        call Edges
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
Frame4: call Vsync
        call GClear
        call Axis
        mov  ax, [swing]        ; the CUBE moved, the camera at home
        mov  [objx], ax
        mov  word [camx], 0
        call Xform
        mov  al, [ok]
        mov  [ok1], al
        call Keep
        mov  word [objx], 0     ; ...or the CAMERA moved, the cube at home
        mov  ax, [swing]
        neg  ax
        mov  [camx], ax
        call Xform
        cmp  byte [ok], 0
        je   .out
        cmp  byte [ok1], 0
        je   .out
        mov  byte [ecol], OTHERC
        mov  word [esrc], sxd
        call Edges
        mov  byte [ecol], EDGEC
        mov  word [esrc], sx
        call Edges
        call Differ
.out:   mov  word [objx], 0
        mov  word [camx], 0
        ret

; ---- Sweep: run [which] to and fro until a key --------------------------
;  1 the cube slides, 2 the camera slides, 3 both at once,
;  4 the cube turns,  5 the camera turns
Sweep:  cmp  byte [which], 3
        jne  .one
        call Frame4
        jmp  .step
.one:   call Frame
.step:  mov  al, [swd]
        cbw
        mov  bx, [swing]
        add  bx, ax
        mov  [swing], bx
        cmp  bx, SWING
        jle  .n1
        neg  byte [swd]
.n1:    cmp  bx, -SWING
        jge  .n2
        neg  byte [swd]
.n2:    mov  al, [which]
        cmp  al, 1
        jne  .c2
        mov  [objx], bx         ; the cube slides
.c2:    cmp  al, 2
        jne  .c4
        mov  ax, bx
        neg  ax
        mov  [camx], ax         ; ...or the camera slides the other way
.c4:    cmp  al, 4
        jne  .c5
        mov  al, bl
        add  al, al
        add  al, MYAW0
        mov  [objyaw], al       ; ...or the cube turns where it stands
.c5:    cmp  al, 5
        jne  .k
        mov  ax, bx             ; a QUARTER of the sweep, because turning
        mov  cl, 2              ;  the camera moves the cube across the
        sar  ax, cl             ;  glass very fast indeed: past about
        mov  [camyaw], al       ;  fifteen degrees it is off the edge and
                                ;  dropped, and a blank screen teaches
                                ;  nothing. ...or the camera turns, which
                                ;  is NOT the
.k:     call KeyChk             ;  same thing at all
        or   al, al
        jz   Sweep
        ret

; ---- StepXZ: one pace along the way the camera is facing ---------------
StepXZ: mov  word [pa], 0
        mov  word [pb], STEPF
        mov  al, [camyaw]
        call Rot2
        ret

; ---- Fly: the arrows, one step a key, until ESC ------------------------
;  One step per keypress, redrawn between: a great many DOS programs
;  worked exactly this way, and it makes the motion deterministic. Arrow
;  keys arrive with AL zero and the scan code in AH - that is what an
;  EXTENDED key is, and lesson 11 met them at the wire.
Fly:    call Frame
        mov  ah, 0
        int  16h
        cmp  al, 27
        je   .out
        or   al, al
        jnz  Fly                ; an ordinary key: not ours
        cmp  ah, 72             ; up
        je   .fwd
        cmp  ah, 80             ; down
        je   .back
        cmp  ah, 75             ; left
        je   .left
        cmp  ah, 77             ; right
        je   .right
        jmp  Fly
.fwd:   call StepXZ
        mov  ax, [pa]
        add  [camx], ax
        mov  ax, [pb]
        add  [camz], ax
        jmp  Fly
.back:  call StepXZ
        mov  ax, [pa]
        sub  [camx], ax
        mov  ax, [pb]
        sub  [camz], ax
        jmp  Fly
.left:  mov  al, [camyaw]
        sub  al, STEPT
        mov  [camyaw], al
        jmp  Fly
.right: mov  al, [camyaw]
        add  al, STEPT
        mov  [camyaw], al
        jmp  Fly
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
Boot:   cld
        mov  ax, 0013h
        int  10h
        mov  ax, VGA
        mov  es, ax

; ---- 1. the cube, from a camera at the origin ---------------------------
        call Frame
        call Key

; ---- 2. move the CUBE: its model placement changes ----------------------
        mov  byte [which], 1
        mov  word [swing], 0
        mov  byte [swd], 1
        call Sweep
        mov  word [objx], 0

; ---- 3. move the CAMERA: its view matrix changes, the cube untouched ----
        mov  byte [which], 2
        mov  word [swing], 0
        mov  byte [swd], 1
        call Sweep
        mov  word [camx], 0

; ---- 4. both answers on each other, and counted -------------------------
        mov  byte [which], 3
        mov  word [swing], 0
        mov  byte [swd], 1
        call Sweep

; ---- 5. turn the CUBE: it spins where it stands -------------------------
        mov  byte [which], 4
        mov  word [swing], 0
        mov  byte [swd], 1
        call Sweep
        mov  byte [objyaw], MYAW0

; ---- 6. turn the CAMERA, and watch it NOT be the same thing -------------
;      Turning the cube spun it about its own centre. Turning the camera
;      swings the whole picture about the EYE - which is a hundred and
;      seventy units away from the cube - so the cube travels sideways
;      across the glass and leaves it. Same instruction, negated; utterly
;      different picture. The equivalence of stage 4 was about WHERE
;      things are, never about which way they face.
        mov  byte [which], 5
        mov  word [swing], 0
        mov  byte [swd], 1
        call Sweep
        mov  byte [camyaw], 0

; ---- 7. fly it ----------------------------------------------------------
        mov  word [camx], 0
        mov  word [camz], 0
        mov  byte [camyaw], 0
        call Fly

Bye:    mov  ax, 0003h          ; a clean screen back to DOS
        int  10h
        mov  ax, 4C00h
        int  21h
