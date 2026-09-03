; ============================================================================
;  ORBITS.ASM - Lesson 12. The triangle that turns the sky.
;
;      FASM ORBITS.ASM ORBITS.COM
;
;      1  the words      the school triangle hid two ratios - and a matrix
;      2  Sun + Earth    one turned vector, hung on a standing centre
;      3  + the Moon     a turn around a centre that is itself turning
;      4  the whole sky  six bodies, three turns deep - the trails write
;                        the lace by themselves
;      5  planetarium    same table, wiped and redrawn: the green arms are
;                        lesson 10's vectors, carrying the sky
;      6  the words      the clock formula was the matrix's first column
;
;  THE ONE FACT THIS LESSON HANDS OVER: turning ANY vector costs FOUR
;  multiplies - x' = x*cos - y*sin, y' = x*sin + y*cos - and that little
;  square of numbers is the rotation MATRIX: its columns are simply where
;  the two anchor arrows (1,0) and (0,1) land. Hang a turned vector on a
;  parent that is itself a turned vector and you have a Moon; hang one
;  more and you have the lace its satellite draws. The whole sky below is
;  ONE routine and a six-row table.
;
;  Every body is the same sentence: ME = PARENT + MATRIX x BASE-VECTOR.
;  The table is ordered parents-first, so by the time a child asks, its
;  parent has already moved this frame.
;
;  THE MACHINE STILL HAS NO SINE. The table from lesson 10 has: 256 cells,
;  the whole circle in one byte, cos(a) = sin(a+64). The trig is asked
;  ONCE per body per frame; after that the sky is integer multiplies -
;  which is how a 4.77 MHz chip affords an orrery.
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
VECC    = 10                    ; a vector is green - lesson 10's colour

CX0     = 160                   ; the Sun's throne: the middle of the sky
CY0     = 100

NBODY   = 6                     ; the sky, counted
BROW    = 6                     ; ...and how wide one row of it is

        jmp  Boot

; ============================================================================
;  RotV - THE MATRIX, made flesh: turn the base vector by an angle.
;  in:  AL = the angle, 0..255 - the whole circle in one byte
;       [bvx],[bvy] = the base vector, signed bytes
;  out: [vx],[vy] = the turned vector, in SCREEN pixels
;
;      x' = x*cos(a) - y*sin(a)
;      y' = x*sin(a) + y*cos(a)
;
;  Four IMULs, two adds - the whole price of a turn, for ANY vector. The
;  columns of that little square are just where the anchors (1,0) and
;  (0,1) land; feed it the vector (r,0) and out falls x'=r*cos, y'=r*sin -
;  lesson 10's clock formula. It was the matrix's FIRST COLUMN all along.
;
;  NEG is new: two's complement negation, the minus sign as an instruction.
;  It carries lesson 10's screen rule: paper y grows up, the beam draws
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
        sar  dx, cl             ; /128 as a SHIFT: the table speaks in 128ths
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
;  Tick - one beat of the sky: every body = its parent + the matrix.
;  The Sun is row 0 and asks nothing; the table is parents-first, so a
;  child always reads a parent that has already moved THIS frame.
; ============================================================================
Tick:   mov  si, BODIES+BROW    ; row 1: the Earth - the Sun stands
        mov  di, 2              ; word offset of body 1 in bpx/bpy
        mov  cx, NBODY-1
.b:     push cx
        push si
        push di
        mov  al, [si+1]         ; the base vector, into the matrix's window
        mov  [bvx], al
        mov  al, [si+2]
        mov  [bvy], al
        mov  al, [si+3]         ; the body's angle today
        call RotV
        pop  di
        pop  si
        mov  bl, [si]           ; whose child is it?
        xor  bh, bh
        add  bx, bx             ; index -> word offset
        mov  ax, [bpx+bx]       ; ME = PARENT...
        add  ax, [vx]           ; ...+ MATRIX x BASE
        mov  [bpx+di], ax
        mov  ax, [bpy+bx]
        add  ax, [vy]
        mov  [bpy+di], ax
        mov  al, [si+4]         ; and the angle walks on - a signed step,
        add  [si+3], al         ;  so one satellite runs the OTHER way
        add  si, BROW
        add  di, 2
        pop  cx
        loop .b
        ret

; ---- Trail: every active body leaves one pixel of ink where it stands ------
Trail:  mov  si, BODIES
        xor  di, di
        mov  cl, [nact]
        xor  ch, ch
.p:     push cx
        mov  ax, [bpy+di]
        mov  bx, W
        mul  bx                 ; y * 320: lesson 7's formula, every time
        add  ax, [bpx+di]
        mov  bx, ax
        mov  al, [si+5]         ; the body's own ink
        mov  [es:bx], al
        add  si, BROW
        add  di, 2
        pop  cx
        loop .p
        ret

; ---- Arms: the green vectors, parent to child - lesson 10's arrows, alive --
Arms:   mov  si, BODIES+BROW
        mov  di, 2
        mov  cx, NBODY-1
.l:     push cx
        push si
        push di
        mov  bl, [si]           ; from the parent...
        xor  bh, bh
        add  bx, bx
        mov  ax, [bpx+bx]
        mov  [p0x], ax
        mov  ax, [bpy+bx]
        mov  [p0y], ax
        mov  ax, [bpx+di]       ; ...to the child
        mov  [p1x], ax
        mov  ax, [bpy+di]
        mov  [p1y], ax
        mov  byte [col], VECC
        call Line               ; lesson 8's line, byte for byte, again
        pop  di
        pop  si
        pop  cx
        add  si, BROW
        add  di, 2
        loop .l
        ret

; ---- Marks: a five-pixel Dot for each body, in its own ink ------------------
Marks:  mov  si, BODIES
        xor  di, di
        mov  cx, NBODY
.d:     push cx
        push si
        push di
        mov  al, [si+5]
        mov  [dcol], al
        mov  ax, [bpx+di]
        mov  bx, [bpy+di]
        call Dot
        pop  di
        pop  si
        pop  cx
        add  si, BROW
        add  di, 2
        loop .d
        ret

; ---- TrailRun: ink until a key - the maths remembers where it has been -----
TrailRun:
        call GClear
        mov  byte [dcol], 14    ; the Sun first, so the sky has a middle
        mov  ax, CX0
        mov  bx, CY0
        call Dot
.f:     call Vsync
        call Tick
        call Trail
        call KeyChk
        or   al, al
        jz   .f
        ret

; ---- what the frames say ---------------------------------------------------
t_head  db 'THE TRIANGLE THAT TURNS THE SKY',0
t_a1    db 'The school triangle hid two ratios: a leg over the',0
t_a2    db 'hypotenuse. The size cancels - SIN and COS belong',0
t_a3    db 'to the ANGLE. Hypotenuse 1: the tip walks a circle.',0
t_a4    db 'Turning ANY vector costs FOUR multiplies - a MATRIX:',0
t_a5    db 'its columns are where the anchors (1,0),(0,1) land.',0
t_a6    db 'Hang a turned vector on a turning parent: a MOON.',0
t_z1    db 'Six bodies, three turns deep: ONE routine, four IMULs,',0
t_z2    db 'and a six-row table. The trails drew themselves - the',0
t_z3    db 'lace is the Moon''s satellite, and nothing in the code',0
t_z4    db 'ever heard of lace.',0
t_z5    db 'Feed the matrix (r,0): out falls r*cos, r*sin - the',0
t_z6    db 'clock formula of lesson 10 was its FIRST COLUMN.',0
t_ow1   db 'Owlos - legacy software modernization',0
t_ow2   db 'owlos.sk',0
t_key   db '- any key -',0

; ---- the sky, as a table ----------------------------------------------------
;  parent, base vector x,y, angle, step, ink - six bytes a body.
;  One tilted base vector on purpose: the circle is the same, the matrix
;  does not care where the arm starts. One NEGATIVE step on purpose: the
;  same table row, running the other way round.
BODIES  db 0FFh,  0,  0,   0,  0, 14    ; the Sun: yellow, bolted down
        db 0,    62,  0,   0,  1, 15    ; the Earth, 62 out, once per 256
        db 1,    22,  0,  60,  3,  7    ; the Moon, 22 from the Earth
        db 1,    11,  0, 120,  5,  9    ; a satellite of the Earth
        db 1,    11, 11, 200,-4, 11    ; another - TILTED base, backwards
        db 2,     8,  0,   0,  7, 12    ; the Moon's own satellite: the
                                        ;  one that writes the lace
; ---- state ------------------------------------------------------------------
bpx     dw CX0                  ; where every body stands NOW - the Sun
        dw 5 dup (0)            ;  is minted standing on its throne
bpy     dw CY0
        dw 5 dup (0)
bvx     db 0                    ; the matrix's window: base vector in...
bvy     db 0
vx      dw 0                    ; ...turned vector out
vy      dw 0
tsin    db 0                    ; the two ratios, parked for four products
tcos    db 0
nact    db 2                    ; how much of the sky is switched on

include 'SINTAB.INC'
include 'DRAW12.INC'

Boot:   cld
        mov  ax, 0003h          ; the text screen, 80x25
        int  10h
        call TextOff
        mov  ax, TEXT
        mov  es, ax

; ---- 1. the words ----------------------------------------------------------
        mov  byte [attr], HEAD
        mov  si, t_head
        mov  di, 0*ROW + 24*2
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
        mov  byte [attr], HEAD
        mov  si, t_a4
        mov  di, 8*ROW + 7*2
        call PutS
        mov  si, t_a5
        mov  di, 9*ROW + 7*2
        call PutS
        mov  byte [attr], NORM
        mov  si, t_a6
        mov  di, 11*ROW + 7*2
        call PutS
        call Bottom
        call Key

; ---- 2. Sun and Earth: one turned vector on a standing centre --------------
        mov  ax, 0013h          ; the graphics screen, 320x200
        int  10h
        mov  ax, VGA
        mov  es, ax
        mov  byte [nact], 2
        call TrailRun           ; the trail is a clean circle: the triangle,
                                ;  bent round, exactly as promised
; ---- 3. the Moon: a turn around a centre that is itself turning ------------
        mov  byte [nact], 3
        call TrailRun           ; the Moon's ink is a WAVE round the Sun -
                                ;  no line of code says wave
; ---- 4. the whole sky: three turns deep ------------------------------------
        mov  byte [nact], NBODY
        call TrailRun           ; and the Moon's satellite writes the lace
; ---- 5. planetarium: wiped and redrawn, the arms showing --------------------
.plan:  call Vsync
        call GClear
        call Tick
        call Arms               ; the green vectors CARRY the sky - what
        call Marks              ;  the trails could never show
        call KeyChk
        or   al, al
        jz   .plan

; ---- 6. the words, closing -------------------------------------------------
        mov  ax, 0003h
        int  10h
        call TextOff
        mov  ax, TEXT
        mov  es, ax
        mov  byte [attr], HEAD
        mov  si, t_head
        mov  di, 0*ROW + 24*2
        call PutS
        mov  byte [attr], NORM
        mov  si, t_z1
        mov  di, 3*ROW + 7*2
        call PutS
        mov  si, t_z2
        mov  di, 4*ROW + 7*2
        call PutS
        mov  si, t_z3
        mov  di, 5*ROW + 7*2
        call PutS
        mov  si, t_z4
        mov  di, 6*ROW + 7*2
        call PutS
        mov  byte [attr], HEAD
        mov  si, t_z5
        mov  di, 9*ROW + 7*2
        call PutS
        mov  si, t_z6
        mov  di, 10*ROW + 7*2
        call PutS
        mov  byte [attr], HEAD
        mov  si, t_ow1
        mov  di, 14*ROW + 7*2
        call PutS
        mov  byte [attr], 0Eh
        mov  si, t_ow2
        mov  di, 15*ROW + 7*2
        call PutS
        mov  byte [attr], NORM
        call Bottom
        call Key

Bye:    mov  ax, 0003h          ; a clean screen back to DOS
        int  10h
        mov  ax, 4C00h
        int  21h
