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

        jmp  Boot               ; over the routines, to the boot at the bottom

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
;  Tick - one beat of the sky: every body = its parent + the matrix.
;  The Sun is row 0 and asks nothing; the table is parents-first, so a
;  child always reads a parent that has already moved THIS frame.
; ============================================================================
;  In C:
;
;      void tick(void)                /* BODIES[b] = {parent, bx, by, angle, step, ink} */
;      {
;          for (int b = 1; b < NBODY; b++) {
;              bvx = BODIES[b].bx;  bvy = BODIES[b].by;
;              rotv(BODIES[b].angle);
;              int par = BODIES[b].parent;
;              bpx[b] = bpx[par] + vx;              /* ME = PARENT + MATRIX x BASE */
;              bpy[b] = bpy[par] + vy;
;              BODIES[b].angle += BODIES[b].step;   /* a byte: it wraps itself     */
;          }
;      }
Tick:   mov  si, BODIES+BROW    ; SI = &BODIES[1]: row 1, the Earth - the Sun stands
        mov  di, 2              ; DI = b * 2: the word offset of body 1 in bpx/bpy
        mov  cx, NBODY-1        ; CX = 5 bodies
.b:     push cx                 ; keep the count
        push si                 ; keep SI and DI: RotV uses BX, CX, DX
        push di                 ; (the pair)
        mov  al, [si+1]         ; AL = BODIES[b].bx
        mov  [bvx], al          ; bvx = AL: the base vector, into the matrix's window
        mov  al, [si+2]         ; AL = BODIES[b].by
        mov  [bvy], al          ; bvy = AL
        mov  al, [si+3]         ; AL = BODIES[b].angle: the body's angle today
        call RotV               ; rotv(angle)
        pop  di                 ; DI back
        pop  si                 ; SI back
        mov  bl, [si]           ; BL = par: whose child is it?
        xor  bh, bh             ; BX = par
        add  bx, bx             ; BX = par * 2: index -> word offset
        mov  ax, [bpx+bx]       ; AX = bpx[par]: ME = PARENT...
        add  ax, [vx]           ; AX += vx:     ...+ MATRIX x BASE
        mov  [bpx+di], ax       ; bpx[b] = AX
        mov  ax, [bpy+bx]       ; AX = bpy[par]
        add  ax, [vy]           ; AX += vy
        mov  [bpy+di], ax       ; bpy[b] = AX
        mov  al, [si+4]         ; AL = BODIES[b].step: a signed step, so one
        add  [si+3], al         ; BODIES[b].angle += step   satellite runs the OTHER way
        add  si, BROW           ; SI += 6: the next row
        add  di, 2              ; b++
        pop  cx                 ; the count
        loop .b                 ; 5 bodies
        ret                     ; return

; ---- Trail: every active body leaves one pixel of ink where it stands ------
;  In C:   for (b = 0; b < nact; b++) screen[bpy[b] * 320 + bpx[b]] = BODIES[b].ink;
Trail:  mov  si, BODIES         ; SI = &BODIES[0]
        xor  di, di             ; DI = 0: b * 2
        mov  cl, [nact]         ; CL = nact
        xor  ch, ch             ; CX = nact bodies switched on
.p:     push cx                 ; keep the count
        mov  ax, [bpy+di]       ; AX = bpy[b]
        mov  bx, W              ; BX = 320
        mul  bx                 ; AX = bpy[b] * 320: lesson 7's formula, every time
        add  ax, [bpx+di]       ; AX = bpy[b] * 320 + bpx[b]
        mov  bx, ax             ; BX = the offset
        mov  al, [si+5]         ; AL = BODIES[b].ink: the body's own ink
        mov  [es:bx], al        ; screen[BX] = ink
        add  si, BROW           ; SI += 6: the next row
        add  di, 2              ; b++
        pop  cx                 ; the count
        loop .p                 ; nact bodies
        ret                     ; return

; ---- Arms: the green vectors, parent to child - lesson 10's arrows, alive --
;  In C:
;
;      void arms(void)
;      {
;          for (int b = 1; b < NBODY; b++) {
;              int par = BODIES[b].parent;
;              col = VECC;
;              line(bpx[par], bpy[par], bpx[b], bpy[b]);   /* parent to child */
;          }
;      }
Arms:   mov  si, BODIES+BROW    ; SI = &BODIES[1]
        mov  di, 2              ; DI = b * 2, b = 1
        mov  cx, NBODY-1        ; CX = 5 bodies
.l:     push cx                 ; keep the count
        push si                 ; keep SI and DI: Line uses DI
        push di                 ; (the pair)
        mov  bl, [si]           ; BL = par: from the parent...
        xor  bh, bh             ; BX = par
        add  bx, bx             ; BX = par * 2
        mov  ax, [bpx+bx]       ; AX = bpx[par]
        mov  [p0x], ax          ; p0x = bpx[par]
        mov  ax, [bpy+bx]       ; AX = bpy[par]
        mov  [p0y], ax          ; p0y = bpy[par]
        mov  ax, [bpx+di]       ; AX = bpx[b]: ...to the child
        mov  [p1x], ax          ; p1x = bpx[b]
        mov  ax, [bpy+di]       ; AX = bpy[b]
        mov  [p1y], ax          ; p1y = bpy[b]
        mov  byte [col], VECC   ; col = green
        call Line               ; line(): lesson 8's, byte for byte, again
        pop  di                 ; DI back
        pop  si                 ; SI back
        pop  cx                 ; the count
        add  si, BROW           ; SI += 6: the next row
        add  di, 2              ; b++
        loop .l                 ; 5 bodies
        ret                     ; return

; ---- Marks: a five-pixel Dot for each body, in its own ink ------------------
;  In C:   for (b = 0; b < NBODY; b++) { dcol = BODIES[b].ink;  dot(bpx[b], bpy[b]); }
Marks:  mov  si, BODIES         ; SI = &BODIES[0]
        xor  di, di             ; DI = 0: b * 2
        mov  cx, NBODY          ; CX = 6 bodies
.d:     push cx                 ; keep the count
        push si                 ; keep SI and DI: Dot uses DI
        push di                 ; (the pair)
        mov  al, [si+5]         ; AL = BODIES[b].ink
        mov  [dcol], al         ; dcol = AL
        mov  ax, [bpx+di]       ; AX = bpx[b]   \  dot(bpx[b], bpy[b])
        mov  bx, [bpy+di]       ; BX = bpy[b]   /
        call Dot                ; dot()
        pop  di                 ; DI back
        pop  si                 ; SI back
        pop  cx                 ; the count
        add  si, BROW           ; SI += 6: the next row
        add  di, 2              ; b++
        loop .d                 ; 6 bodies
        ret                     ; return

; ---- TrailRun: ink until a key - the maths remembers where it has been -----
;  In C:
;
;      void trail_run(void)
;      {
;          gclear();  dcol = 14;  dot(CX0, CY0);         /* the Sun first */
;          do { vsync(); tick(); trail(); } while (!key_check());
;      }
TrailRun:
        call GClear             ; gclear()
        mov  byte [dcol], 14    ; dcol = 14, yellow: the Sun first, so the sky has a middle
        mov  ax, CX0            ; AX = CX0   \  dot(CX0, CY0)
        mov  bx, CY0            ; BX = CY0   /
        call Dot                ; dot()
.f:     call Vsync              ; vsync()
        call Tick               ; tick()
        call Trail              ; trail()
        call KeyChk             ; AL = key_check()
        or   al, al             ; a key ?
        jz   .f                 ;   no: another frame
        ret                     ; return

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

;  In C:
;
;      int main(void)
;      {
;          set_mode(3); cursor_off();                      /* 1: the words       */
;          puts_at(...six lines...); bottom(); key();
;          set_mode(0x13);
;          nact = 2;     trail_run();                      /* 2: Sun and Earth   */
;          nact = 3;     trail_run();                      /* 3: + the Moon      */
;          nact = NBODY; trail_run();                      /* 4: the whole sky   */
;          do { vsync(); gclear(); tick(); arms(); marks(); } while (!key_check()); /* 5 */
;          set_mode(3); cursor_off();                      /* 6: the words       */
;          puts_at(...); bottom(); key();
;          set_mode(3); exit(0);
;      }
Boot:   cld                     ; string ops count UP (STOSW, LODSB)
        mov  ax, 0003h          ; AX = 3: the text screen, 80x25
        int  10h                ; set_mode(3)
        call TextOff            ; cursor_off()
        mov  ax, TEXT           ; AX = B800h
        mov  es, ax             ; ES = the text screen

; ---- 1. the words ----------------------------------------------------------
        mov  byte [attr], HEAD  ; attr = HEAD
        mov  si, t_head         ; SI = t_head
        mov  di, 0*ROW + 24*2   ; DI = row 0, column 24
        call PutS               ; puts()
        mov  byte [attr], NORM  ; attr = NORM
        mov  si, t_a1           ; SI = t_a1
        mov  di, 3*ROW + 7*2    ; DI = row 3, column 7
        call PutS               ; puts()
        mov  si, t_a2           ; SI = t_a2
        mov  di, 4*ROW + 7*2    ; DI = row 4, column 7
        call PutS               ; puts()
        mov  si, t_a3           ; SI = t_a3
        mov  di, 5*ROW + 7*2    ; DI = row 5, column 7
        call PutS               ; puts()
        mov  byte [attr], HEAD  ; attr = HEAD
        mov  si, t_a4           ; SI = t_a4
        mov  di, 8*ROW + 7*2    ; DI = row 8, column 7
        call PutS               ; puts()
        mov  si, t_a5           ; SI = t_a5
        mov  di, 9*ROW + 7*2    ; DI = row 9, column 7
        call PutS               ; puts()
        mov  byte [attr], NORM  ; attr = NORM
        mov  si, t_a6           ; SI = t_a6
        mov  di, 11*ROW + 7*2   ; DI = row 11, column 7
        call PutS               ; puts()
        call Bottom             ; bottom(): "- any key -"
        call Key                ; key()

; ---- 2. Sun and Earth: one turned vector on a standing centre --------------
        mov  ax, 0013h          ; AX = 13h: the graphics screen, 320x200
        int  10h                ; set_mode(0x13)
        mov  ax, VGA            ; AX = A000h
        mov  es, ax             ; ES = the graphics screen
        mov  byte [nact], 2     ; nact = 2: the Sun and the Earth
        call TrailRun           ; trail_run(): the trail is a clean circle, the
                                ;  triangle bent round, exactly as promised
; ---- 3. the Moon: a turn around a centre that is itself turning ------------
        mov  byte [nact], 3     ; nact = 3
        call TrailRun           ; trail_run(): the Moon's ink is a WAVE round the
                                ;  Sun - no line of code says wave
; ---- 4. the whole sky: three turns deep ------------------------------------
        mov  byte [nact], NBODY ; nact = 6
        call TrailRun           ; trail_run(): the Moon's satellite writes the lace
; ---- 5. planetarium: wiped and redrawn, the arms showing --------------------
.plan:  call Vsync              ; vsync()
        call GClear             ; gclear()
        call Tick               ; tick()
        call Arms               ; arms(): the green vectors CARRY the sky - what
        call Marks              ; marks()  the trails could never show
        call KeyChk             ; AL = key_check()
        or   al, al             ; a key ?
        jz   .plan              ;   no: another frame

; ---- 6. the words, closing -------------------------------------------------
        mov  ax, 0003h          ; AX = 3: the text screen
        int  10h                ; set_mode(3)
        call TextOff            ; cursor_off()
        mov  ax, TEXT           ; AX = B800h
        mov  es, ax             ; ES = the text screen
        mov  byte [attr], HEAD  ; attr = HEAD
        mov  si, t_head         ; SI = t_head
        mov  di, 0*ROW + 24*2   ; DI = row 0, column 24
        call PutS               ; puts()
        mov  byte [attr], NORM  ; attr = NORM
        mov  si, t_z1           ; SI = t_z1
        mov  di, 3*ROW + 7*2    ; DI = row 3, column 7
        call PutS               ; puts()
        mov  si, t_z2           ; SI = t_z2
        mov  di, 4*ROW + 7*2    ; DI = row 4, column 7
        call PutS               ; puts()
        mov  si, t_z3           ; SI = t_z3
        mov  di, 5*ROW + 7*2    ; DI = row 5, column 7
        call PutS               ; puts()
        mov  si, t_z4           ; SI = t_z4
        mov  di, 6*ROW + 7*2    ; DI = row 6, column 7
        call PutS               ; puts()
        mov  byte [attr], HEAD  ; attr = HEAD
        mov  si, t_z5           ; SI = t_z5
        mov  di, 9*ROW + 7*2    ; DI = row 9, column 7
        call PutS               ; puts()
        mov  si, t_z6           ; SI = t_z6
        mov  di, 10*ROW + 7*2   ; DI = row 10, column 7
        call PutS               ; puts()
        mov  byte [attr], HEAD  ; attr = HEAD
        mov  si, t_ow1          ; SI = t_ow1
        mov  di, 14*ROW + 7*2   ; DI = row 14, column 7
        call PutS               ; puts()
        mov  byte [attr], 0Eh   ; attr = 0Eh
        mov  si, t_ow2          ; SI = t_ow2
        mov  di, 15*ROW + 7*2   ; DI = row 15, column 7
        call PutS               ; puts()
        mov  byte [attr], NORM  ; attr = NORM
        call Bottom             ; bottom(): "- any key -"
        call Key                ; key()

Bye:    mov  ax, 0003h          ; AX = 3: a clean screen back to DOS
        int  10h                ; set_mode(3)
        mov  ax, 4C00h          ; AH = 4Ch exit, AL = 0 the code
        int  21h                ; exit(0)
