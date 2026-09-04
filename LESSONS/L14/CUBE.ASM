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

        jmp  Boot

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
Rot2:   push ax
        mov  bx, SINTAB
        xlatb                   ; AL = sin(a), -127..127
        mov  [tsin], al
        pop  ax
        add  al, 64             ; cos(a) = sin(a + a quarter-turn)
        xlatb
        mov  [tcos], al
        mov  al, [tcos]
        imul byte [pa]          ; a*cos, signed
        mov  dx, ax
        mov  al, [tsin]
        imul byte [pb]          ; b*sin
        sub  dx, ax             ; a' = a*cos - b*sin, in 128ths
        mov  cl, 7
        sar  dx, cl             ; /128 as a SHIFT: the table speaks 128ths
        mov  [t1], dl           ; PARKED - b' still needs the OLD a
        mov  al, [tsin]
        imul byte [pa]          ; a*sin
        mov  dx, ax
        mov  al, [tcos]
        imul byte [pb]          ; b*cos
        add  dx, ax             ; b' = a*sin + b*cos
        sar  dx, cl
        mov  [pb], dl
        mov  al, [t1]           ; ...and only now is a' allowed to land
        mov  [pa], al
        ret

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
Xform:  mov  si, VERTS
        xor  di, di             ; a projected corner is two WORDS
        mov  cx, NV
.v:     push cx
        mov  al, [si]           ; the corner, straight out of the table:
        mov  [vx3], al          ;  three signed bytes, measured from the
        mov  al, [si+1]         ;  cube's OWN CENTRE, which is zero
        mov  [vy3], al
        mov  al, [si+2]
        mov  [vz3], al

        push si                 ; ---- the two turns, in the order [swap]
        push di                 ;      asks for. Stage 9 asks for both.
        cmp  byte [swap], 0
        jne  .xf
        call TurnY
        call TurnX
        jmp  .turned
.xf:    call TurnX
        call TurnY
.turned:
        pop  di
        pop  si

        mov  al, [vx3]          ; ---- translate: the SAME three numbers
        cbw                     ;  added to every corner, which is why the
        add  ax, [tx]           ;  shape does not change when it moves
        add  ax, CX0            ; ---- and project: x goes straight across
        mov  [sx+di], ax
        mov  al, [vy3]
        cbw
        add  ax, [ty]
        mov  bx, CY0
        sub  bx, ax             ; THE MINUS: paper y up, the beam draws down
        mov  [sy+di], bx
        mov  al, [vz3]
        cbw
        add  ax, [tz]           ; the depth, computed and translated as
        mov  [vzs], ax          ;  honestly as the other two - AND THEN
                                ;  NEVER READ AGAIN. That silence is the
                                ;  projection, and it costs nothing.
        add  si, 3
        add  di, 2
        pop  cx
        loop .v
        ret

; ---- a turn about Y is a flat turn of the (x,z) pair, and nothing else --
TurnY:  mov  al, [vx3]
        mov  [pa], al
        mov  al, [vz3]
        mov  [pb], al
        mov  al, [angy]
        call Rot2
        mov  al, [pa]
        mov  [vx3], al
        mov  al, [pb]
        mov  [vz3], al
        ret

; ---- ...and a turn about X is the same routine, handed (y,z) -----------
TurnX:  mov  al, [vy3]
        mov  [pa], al
        mov  al, [vz3]
        mov  [pb], al
        mov  al, [angx]
        call Rot2
        mov  al, [pa]
        mov  [vy3], al
        mov  al, [pb]
        mov  [vz3], al
        ret

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
Origin: mov  ax, CX0
        add  ax, [tx]           ; the cube's own zero: the arrows start here
        mov  [ocx], ax
        mov  ax, CY0
        sub  ax, [ty]
        mov  [ocy], ax
        mov  word [p0x], CX0-5  ; ...and the ROOM's zero, which never moves
        mov  word [p1x], CX0+5
        mov  word [p0y], CY0
        mov  word [p1y], CY0
        mov  byte [col], ORGC
        call Line
        mov  word [p0x], CX0
        mov  word [p1x], CX0
        mov  word [p0y], CY0-5
        mov  word [p1y], CY0+5
        mov  byte [col], ORGC
        call Line
        ret

; ---- the scaffolding: one green arrow from the centre to each corner ----
;  [nvec] says how many of the eight are switched on, so stage 1 can show
;  exactly one of them and stage 2 can bring the rest.
Vecs:   mov  cl, [nvec]
        xor  ch, ch
        jcxz .out
        mov  bl, [vfrom]        ; WHICH corner to start from. Stage 1 shows
        xor  bh, bh             ;  one, and not corner zero: at this angle
        add  bx, bx             ;  corner zero sits nearly on the body
        mov  di, bx             ;  diagonal that points at you, and its
                                ;  arrow projects to fourteen pixels. A
                                ;  corner on another diagonal is sixty.
.a:     push cx
        mov  ax, [ocx]
        mov  [p0x], ax
        mov  ax, [ocy]
        mov  [p0y], ax
        mov  ax, [sx+di]
        mov  [p1x], ax
        mov  ax, [sy+di]
        mov  [p1y], ax
        mov  byte [col], VECC
        push di
        call Line
        pop  di
        mov  byte [dcol], TIPC  ; and the tip, marked: a CORNER
        mov  ax, [sx+di]
        mov  bx, [sy+di]
        push di
        call Dot
        pop  di
        add  di, 2
        pop  cx
        loop .a
.out:   ret

; ---- the model, drawn: twelve lines, and the LIST is the whole trick ----
;  Nothing here knows what a cube is. It reads pairs of corner numbers and
;  joins them. Change the twelve pairs and the same eight corners become a
;  different object entirely.
Edges:  mov  si, EDGES
        mov  cx, NE
.e:     push cx
        mov  bl, [si]           ; from this corner...
        xor  bh, bh
        add  bx, bx
        mov  ax, [sx+bx]
        mov  [p0x], ax
        mov  ax, [sy+bx]
        mov  [p0y], ax
        mov  bl, [si+1]         ; ...to that one
        xor  bh, bh
        add  bx, bx
        mov  ax, [sx+bx]
        mov  [p1x], ax
        mov  ax, [sy+bx]
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

; ---- one whole picture --------------------------------------------------
Frame:  call Vsync
        call GClear
        call Xform
        call Origin
        call Vecs
        cmp  byte [shedge], 0
        je   .no
        mov  byte [ecol], EDGEC
        call Edges
.no:    ret

; ---- Spin: turn until a key, by whatever steps are set ------------------
Spin:   call Frame
        mov  al, [stepy]
        add  [angy], al
        mov  al, [stepx]
        add  [angx], al
        call KeyChk
        or   al, al
        jz   Spin
        ret

; ---- Walk: slide by (dx,dy,dz) until a key, bouncing at the limits ------
;  The steps are signed BYTES and the offsets are WORDS, so every one of
;  them goes through CBW first - a byte and a word do not add, and the
;  assembler is right to refuse.
Walk:   call Frame
        mov  al, [wdx]
        cbw
        add  [tx], ax
        mov  al, [wdy]
        cbw
        add  [ty], ax
        mov  al, [wdz]
        cbw
        add  [tz], ax
        mov  ax, [tx]           ; a small pen, so the box stays on glass
        cmp  ax, 70
        jle  .l1
        neg  byte [wdx]
.l1:    cmp  ax, -70
        jge  .l2
        neg  byte [wdx]
.l2:    mov  ax, [ty]
        cmp  ax, 50
        jle  .l3
        neg  byte [wdy]
.l3:    cmp  ax, -50
        jge  .l4
        neg  byte [wdy]
.l4:    mov  ax, [tz]
        cmp  ax, 120
        jle  .l5
        neg  byte [wdz]
.l5:    cmp  ax, -120
        jge  .l6
        neg  byte [wdz]
.l6:    call KeyChk
        or   al, al
        jz   Walk
        ret

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
Boot:   cld
        mov  ax, 0013h          ; the graphics screen, 320x200
        int  10h
        mov  ax, VGA
        mov  es, ax

; ---- 1. the origin, and ONE corner ---------------------------------------
        mov  byte [angy], 24    ; stood at an angle from the start, or a
        mov  byte [angx], 20    ;  cube looks like a square and teaches
        mov  byte [vfrom], 1    ;  nobody anything. And corner ONE, not
        mov  byte [nvec], 1     ;  zero: at this angle corner zero sits
        mov  byte [shedge], 0   ;  almost on the body diagonal that points
                                ;  at you, so its arrow projects to
                                ;  fourteen pixels and teaches nothing
                                ;  either. Corner one is sixty out.
        call Frame
        call Key

; ---- 2. all eight vectors - and still no cube ----------------------------
        mov  byte [vfrom], 0
        mov  byte [nvec], NV
        call Frame
        call Key

; ---- 3. join them: the edge list arrives ---------------------------------
        mov  byte [shedge], 1
        call Frame
        call Key

; ---- 4. hide the scaffolding: what an engine actually shows you ----------
        mov  byte [nvec], 0
        call Frame
        call Key

; ---- 5. turn it: one axis, then two, by the same routine -----------------
        mov  byte [stepy], 1
        mov  byte [stepx], 0
        call Spin               ; about Y alone
        mov  byte [stepx], 1
        call Spin               ; and now about two axes at once

; ---- 6. move it: every corner takes the SAME offset ----------------------
        mov  byte [stepy], 0
        mov  byte [stepx], 0
        mov  byte [angy], 24    ; back to the pose stage one stood in. The
        mov  byte [angx], 20    ;  spin stopped wherever the key landed,
        mov  byte [vfrom], 0    ;  and a still frame at a random angle
        mov  byte [nvec], NV    ;  looks like an accident. The arrows come
                                ;  back too, so you can watch the WHOLE
                                ;  bundle travel together
        mov  byte [wdx], 2      ;  the WHOLE bundle travel together
        mov  byte [wdy], 1
        mov  byte [wdz], 0
        call Walk

; ---- 7. move it in Z - and watch nothing happen --------------------------
        mov  word [tx], 0
        mov  word [ty], 0
        mov  byte [wdx], 0
        mov  byte [wdy], 0
        mov  byte [wdz], 3      ; straight at your face, and back again
        call Walk

; ---- 8. the wire: turn it slowly and look THROUGH it ---------------------
        mov  word [tz], 0
        mov  byte [wdz], 0
        mov  byte [nvec], 0
        mov  byte [stepy], 1
        mov  byte [stepx], 0
        call Spin

; ---- 9. the order of two turns is not free -------------------------------
;      The same two angles, applied the other way round, put the corners
;      somewhere else. Draw both: white is Y-then-X, red is X-then-Y. If
;      turning were like adding, one cube would hide the other.
        mov  byte [angy], 40
        mov  byte [angx], 40
        mov  byte [swap], 0
        call Frame              ; white: Y first, then X
        mov  byte [swap], 1
        call Xform              ; the same numbers, the other order...
        mov  byte [ecol], ALTC
        call Edges              ; ...drawn on top, in red
        call Key

Bye:    mov  ax, 0003h          ; a clean screen back to DOS
        int  10h
        mov  ax, 4C00h
        int  21h
