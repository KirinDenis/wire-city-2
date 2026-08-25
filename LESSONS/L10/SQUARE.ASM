; ============================================================================
;  SQUARE.ASM - Lesson 10. The square that is not there.
;
;      FASM SQUARE.ASM SQUARE.COM
;
;      1  the words      vertex, edge, face - and the machine has no sine
;      2  one vector     centre, angle, length: the clock's arm, back again
;      3  four           four tips are four VERTICES - still no square
;      4  edges          tip to tip: the wire skeleton stands up
;      5  the turn       the angles grow, the "square" rotates - redrawn,
;                        every frame, from four numbers
;      6  wireframe      the vectors hidden: what every engine's debug
;                        view shows, and what OWL FLY's LOW mode ships
;      7  translate      the centre moves; angle and length ride along
;      8  scale          the lengths breathe; the angles stand still
;      9  the words      three transformations - and the missing FACE
;
;  THE ONE FACT THIS LESSON HANDS OVER: there is no square. There are four
;  radius vectors - one centre, one length, four angles a quarter-turn
;  apart - and every picture of a "rotating square" is those numbers,
;  recomputed and redrawn each frame. A vertex is where a vector ends.
;  An edge is two tips joined - the LINE from lesson 8 draws it, byte for
;  byte the same routine. A face is filled between edges, and it is
;  missing here ON PURPOSE: filling a polygon is a craft of its own, and
;  it gets its own lesson.
;
;  THE MACHINE HAS NO SINE. A table has: 256 cells minted once (SINTAB.INC,
;  beside this file), the whole circle in one byte, and cos(a) is sin(a)
;  a quarter-turn on - the same table read 64 cells later. The games'
;  hsin and hcos are exactly this, grown up.
;
;  Owlos - legacy software modernization - https://owlos.sk
; ============================================================================
format binary as 'com'
        org  100h

TEXT    = 0B800h                ; the text screen: 80x25, TWO bytes a cell
VGA     = 0A000h                ; the graphics screen: 320x200, one byte
W       = 320
H       = 200
ROW     = 160                   ; a text row is 160 BYTES - two per cell

NORM    = 07h                   ; grey on black
HEAD    = 0Fh                   ; white
VECC    = 10                    ; a vector is green
VTXC    = 14                    ; a vertex is yellow
EDGC    = 15                    ; an edge is white

CX0     = 160                   ; the centre's home...
CY0     = 100
R0      = 70                    ; ...and the vectors' home length

        jmp  Boot

; ============================================================================
;  VecXY - one radius vector, made flesh.
;  in:  AL = the angle, 0..255 - the whole circle in one byte
;  out: [vx],[vy] = where its tip lands on the screen
;
;  XLAT is new: AL becomes the byte at [BX+AL] - one instruction, and the
;  table IS the sine. IMUL is MUL's signed brother: the table is full of
;  negative numbers and they must stay negative. SAR is SHR that keeps the
;  sign: /128 as a SHIFT - never a divide - because the table speaks in
;  128ths. And the minus in the y line is the screen's own: the beam draws
;  top to bottom, screen y grows DOWN, so what the paper adds, the tube
;  subtracts.
; ============================================================================
VecXY:  push ax
        mov  bx, SINTAB
        xlatb                   ; AL = sin(AL), -127..127
        imul byte [rad]         ; AX = sin * length, sign kept
        mov  cl, 7
        sar  ax, cl             ; /128, sign kept
        add  ax, [scx]
        mov  [vx], ax
        pop  ax
        add  al, 64             ; cos(a) = sin(a + a quarter-turn): the
        xlatb                   ;  byte wraps round by itself - 256 IS
        imul byte [rad]         ;  the full circle
        mov  cl, 7
        sar  ax, cl
        mov  bx, [scy]
        sub  bx, ax             ; THE MINUS: paper y grows up, screen y down
        mov  [vy], bx
        ret

; ---- Verts: all four tips - one length, angles a quarter-turn apart --------
Verts:  mov  al, [ang]
        add  al, 32             ; the first corner sits at "half past one"
        mov  si, vlist
        mov  cx, 4
.v:     push cx
        push ax
        push si
        call VecXY
        pop  si
        mov  ax, [vx]
        mov  [si], ax
        mov  ax, [vy]
        mov  [si+2], ax
        pop  ax
        add  al, 64             ; the next corner: a quarter-turn on
        pop  cx
        add  si, 4
        loop .v
        ret

; ---- DrawVec: the vector at [si] - a green line home, a yellow tip ---------
DrawVec:
        push si
        mov  ax, [scx]
        mov  [p0x], ax
        mov  ax, [scy]
        mov  [p0y], ax
        mov  ax, [si]
        mov  [p1x], ax
        mov  ax, [si+2]
        mov  [p1y], ax
        mov  byte [col], VECC
        call Line               ; lesson 8's line, byte for byte
        pop  si
        mov  byte [dcol], VTXC
        mov  ax, [si]
        mov  bx, [si+2]
        call Dot                ; the tip is the VERTEX - make it visible
        ret

DrawVecs:
        mov  si, vlist
        mov  cx, 4
.v:     push cx
        push si
        call DrawVec
        pop  si
        pop  cx
        add  si, 4
        loop .v
        ret

; ---- EdgeFT: one edge - SI and BX point at two entries of vlist ------------
EdgeFT: mov  ax, [si]
        mov  [p0x], ax
        mov  ax, [si+2]
        mov  [p0y], ax
        mov  ax, [bx]
        mov  [p1x], ax
        mov  ax, [bx+2]
        mov  [p1y], ax
        jmp  Line               ; Line's ret returns for us

DrawEdges:
        mov  byte [col], EDGC
        mov  si, vlist
        mov  bx, vlist+4
        call EdgeFT
        mov  si, vlist+4
        mov  bx, vlist+8
        call EdgeFT
        mov  si, vlist+8
        mov  bx, vlist+12
        call EdgeFT
        mov  si, vlist+12
        mov  bx, vlist          ; the last tip closes back on the first
        call EdgeFT
        ret

; ---- what the frames say ---------------------------------------------------
t_head  db 'THE SQUARE THAT IS NOT THERE',0
t_a1    db 'A picture is not made of squares. It is made of VERTICES -',0
t_a2    db 'and a vertex is where a VECTOR ends: an angle and a length',0
t_a3    db 'from a centre. The clock formula, four times over.',0
t_a4    db 'Join neighbouring tips: EDGES - lesson 8 draws them.',0
t_a5    db 'The machine has no sine. A TABLE has: 256 cells, minted',0
t_a6    db 'once, and cos(a) is sin(a) a quarter-turn on. Same table.',0
t_a7    db 'The games'' hsin and hcos are exactly this, grown up.',0
t_z1    db 'Three transformations - and there are no more:',0
t_z2    db 'TRANSLATE moves the centre. ROTATE turns the angles.',0
t_z3    db 'SCALE changes the lengths. Everything that ever moved on',0
t_z4    db 'this screen was these three, done to four vectors.',0
t_z5    db 'The FACE is missing on purpose: filling a polygon is a',0
t_z6    db 'craft of its own - and it gets its own lesson.',0
t_ow1   db 'Owlos - legacy software modernization',0
t_ow2   db 'owlos.sk',0
t_key   db '- any key -',0

; ---- state -----------------------------------------------------------------
scx     dw CX0                  ; where the centre stands NOW
scy     dw CY0
rad     db R0                   ; how long the vectors are NOW
ang     db 0                    ; degrees-of-256 added to every corner
tt      db 0                    ; the wander clock: translate and scale
vx      dw 0                    ; VecXY's answer
vy      dw 0
vlist   dw 8 dup (0)            ; the four tips: x,y  x,y  x,y  x,y

include 'SINTAB.INC'
include 'DRAW10.INC'

; ---- one spin frame: wipe, recompute, redraw -------------------------------
;  This loop IS the lesson: nothing rotates. Four numbers change, the
;  screen is wiped, four vectors are drawn where the numbers now say.
Spin:   call Vsync
        call GClear
        call Verts
        cmp  byte [shvec], 0
        je   .nv
        call DrawVecs
.nv:    call DrawEdges
        ret

Boot:   cld
        mov  ax, 0003h          ; the text screen, 80x25
        int  10h
        call TextOff
        mov  ax, TEXT
        mov  es, ax

; ---- 1. the words ----------------------------------------------------------
        mov  byte [attr], HEAD
        mov  si, t_head
        mov  di, 0*ROW + 26*2
        call PutS
        mov  byte [attr], NORM
        mov  si, t_a1
        mov  di, 3*ROW + 7*2
        call PutS
        mov  si, t_a2
        mov  di, 4*ROW + 7*2
        call PutS
        mov  si, t_a3
        mov  di, 5*ROW + 7*2
        call PutS
        mov  si, t_a4
        mov  di, 7*ROW + 7*2
        call PutS
        mov  byte [attr], HEAD
        mov  si, t_a5
        mov  di, 10*ROW + 7*2
        call PutS
        mov  si, t_a6
        mov  di, 11*ROW + 7*2
        call PutS
        mov  byte [attr], NORM
        mov  si, t_a7
        mov  di, 12*ROW + 7*2
        call PutS
        call Bottom
        call Key

; ---- 2. one vector, then four ----------------------------------------------
        mov  ax, 0013h          ; the graphics screen, 320x200
        int  10h
        mov  ax, VGA
        mov  es, ax
        call GClear
        mov  byte [dcol], EDGC  ; the centre, in white - translation will
        mov  ax, [scx]          ;  move THIS dot before the lesson is out
        mov  bx, [scy]
        call Dot
        call Verts
        mov  si, vlist          ; the first vector, alone on the screen
        call DrawVec
        call Key
        mov  si, vlist+4        ; ...then its three brothers, one a beat
        call DrawVec
        call Hold
        mov  si, vlist+8
        call DrawVec
        call Hold
        mov  si, vlist+12
        call DrawVec
        call Key

; ---- 3. the edges, one a beat ----------------------------------------------
        mov  byte [col], EDGC
        mov  si, vlist
        mov  bx, vlist+4
        call EdgeFT
        call Hold
        mov  si, vlist+4
        mov  bx, vlist+8
        call EdgeFT
        call Hold
        mov  si, vlist+8
        mov  bx, vlist+12
        call EdgeFT
        call Hold
        mov  si, vlist+12
        mov  bx, vlist
        call EdgeFT
        call Key

; ---- 4. the turn -----------------------------------------------------------
        mov  byte [shvec], 1
.spin1: call Spin
        inc  byte [ang]
        call KeyChk
        or   al, al
        jz   .spin1

; ---- 5. wireframe: the vectors hidden --------------------------------------
        mov  byte [shvec], 0
.spin2: call Spin
        inc  byte [ang]
        call KeyChk
        or   al, al
        jz   .spin2

; ---- 6. translate: the centre moves ----------------------------------------
        mov  byte [shvec], 1
.mov1:  mov  al, [tt]
        mov  bx, SINTAB
        xlatb
        mov  bl, 60             ; sixty pixels of wander, each way
        imul bl
        mov  cl, 7
        sar  ax, cl
        add  ax, CX0
        mov  [scx], ax
        call Spin
        add  byte [tt], 2
        call KeyChk
        or   al, al
        jz   .mov1
        mov  word [scx], CX0    ; home again

; ---- 7. scale: the lengths breathe -----------------------------------------
.scl1:  mov  al, [tt]
        mov  bx, SINTAB
        xlatb
        mov  bl, 30             ; thirty length-units of breath
        imul bl
        mov  cl, 7
        sar  ax, cl
        add  ax, R0
        mov  [rad], al
        call Spin
        add  byte [tt], 2
        call KeyChk
        or   al, al
        jz   .scl1
        mov  byte [rad], R0     ; home again

; ---- 8. the words, closing -------------------------------------------------
        mov  ax, 0003h
        int  10h
        call TextOff
        mov  ax, TEXT
        mov  es, ax
        mov  byte [attr], HEAD
        mov  si, t_head
        mov  di, 0*ROW + 26*2
        call PutS
        mov  si, t_z1
        mov  di, 3*ROW + 7*2
        call PutS
        mov  byte [attr], NORM
        mov  si, t_z2
        mov  di, 5*ROW + 7*2
        call PutS
        mov  si, t_z3
        mov  di, 6*ROW + 7*2
        call PutS
        mov  si, t_z4
        mov  di, 7*ROW + 7*2
        call PutS
        mov  si, t_z5
        mov  di, 10*ROW + 7*2
        call PutS
        mov  si, t_z6
        mov  di, 11*ROW + 7*2
        call PutS
        mov  byte [attr], HEAD
        mov  si, t_ow1
        mov  di, 15*ROW + 7*2
        call PutS
        mov  byte [attr], 0Eh
        mov  si, t_ow2
        mov  di, 16*ROW + 7*2
        call PutS
        mov  byte [attr], NORM
        call Bottom
        call Key

        mov  ax, 0003h          ; a clean screen back to DOS
        int  10h
        mov  ax, 4C00h
        int  21h

shvec   db 1                    ; the spin frames: draw the vectors, or not
