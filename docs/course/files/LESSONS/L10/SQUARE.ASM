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

        jmp  Boot               ; over the routines, to the boot at the bottom

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
;  In C:
;
;      void vec_xy(int a)
;      {
;          vx = scx + (SINTAB[a] * rad >> 7);               /* sin, in 128ths   */
;          vy = scy - (SINTAB[(a + 64) & 255] * rad >> 7);  /* cos = sin + 64,  */
;      }                                                    /*  and THE MINUS   */
VecXY:  push ax                 ; keep a
        mov  bx, SINTAB         ; BX = the table
        xlatb                   ; AL = SINTAB[a]: sin(a), -127..127
        imul byte [rad]         ; AX = sin * rad, sign kept
        mov  cl, 7              ; CL = 7
        sar  ax, cl             ; AX >>= 7: /128, sign kept
        add  ax, [scx]          ; AX += scx
        mov  [vx], ax           ; vx = AX
        pop  ax                 ; AL = a
        add  al, 64             ; AL = a + 64: cos(a) = sin(a + a quarter-turn).
        xlatb                   ; AL = SINTAB[a + 64]   The byte wraps round by
        imul byte [rad]         ; AX = cos * rad         itself - 256 IS the circle
        mov  cl, 7              ; CL = 7
        sar  ax, cl             ; AX >>= 7
        mov  bx, [scy]          ; BX = scy
        sub  bx, ax             ; BX = scy - AX: THE MINUS, paper y up, screen y down
        mov  [vy], bx           ; vy = BX
        ret                     ; return

; ---- Verts: all four tips - one length, angles a quarter-turn apart --------
;  In C:
;
;      void verts(void)
;      {
;          int a = ang + 32;                        /* "half past one"      */
;          for (int i = 0; i < 4; i++, a += 64) {   /* a quarter-turn apart */
;              vec_xy(a);
;              vlist[i].x = vx;  vlist[i].y = vy;
;          }
;      }
Verts:  mov  al, [ang]          ; AL = ang
        add  al, 32             ; AL = a = ang + 32: the first corner at "half past one"
        mov  si, vlist          ; SI = &vlist[0]
        mov  cx, 4              ; CX = 4 corners
.v:     push cx                 ; keep the count
        push ax                 ; keep a
        push si                 ; keep SI: VecXY uses BX, CX
        call VecXY              ; vec_xy(a)
        pop  si                 ; SI back
        mov  ax, [vx]           ; AX = vx
        mov  [si], ax           ; vlist[i].x = vx
        mov  ax, [vy]           ; AX = vy
        mov  [si+2], ax         ; vlist[i].y = vy
        pop  ax                 ; AL = a
        add  al, 64             ; a += 64: the next corner, a quarter-turn on
        pop  cx                 ; the count
        add  si, 4              ; SI += 4: the next entry, two words
        loop .v                 ; 4 corners
        ret                     ; return

; ---- DrawVec: the vector at [si] - a green line home, a yellow tip ---------
;  In C:
;
;      void draw_vec(int *v)                          /* v = one entry of vlist */
;      {
;          p0x = scx;  p0y = scy;  p1x = v[0];  p1y = v[1];
;          col = VECC;  line();                        /* a green line home      */
;          dcol = VTXC; dot(v[0], v[1]);               /* the tip: the VERTEX    */
;      }
DrawVec:
        push si                 ; keep v
        mov  ax, [scx]          ; AX = scx
        mov  [p0x], ax          ; p0x = scx
        mov  ax, [scy]          ; AX = scy
        mov  [p0y], ax          ; p0y = scy
        mov  ax, [si]           ; AX = v.x
        mov  [p1x], ax          ; p1x = v.x
        mov  ax, [si+2]         ; AX = v.y
        mov  [p1y], ax          ; p1y = v.y
        mov  byte [col], VECC   ; col = green
        call Line               ; line(): lesson 8's, byte for byte
        pop  si                 ; SI = v
        mov  byte [dcol], VTXC  ; dcol = yellow
        mov  ax, [si]           ; AX = v.x   \  dot(v.x, v.y)
        mov  bx, [si+2]         ; BX = v.y   /
        call Dot                ; dot(): the tip is the VERTEX - make it visible
        ret                     ; return

;  In C:   for (i = 0; i < 4; i++) draw_vec(&vlist[i]);
DrawVecs:
        mov  si, vlist          ; SI = &vlist[0]
        mov  cx, 4              ; CX = 4
.v:     push cx                 ; keep the count
        push si                 ; keep SI
        call DrawVec            ; draw_vec(SI)
        pop  si                 ; SI back
        pop  cx                 ; the count
        add  si, 4              ; SI += 4: the next entry
        loop .v                 ; 4 vectors
        ret                     ; return

; ---- EdgeFT: one edge - SI and BX point at two entries of vlist ------------
;  In C:   void edge(int *a, int *b) { p0x = a[0]; p0y = a[1]; p1x = b[0]; p1y = b[1]; line(); }
EdgeFT: mov  ax, [si]           ; AX = a.x
        mov  [p0x], ax          ; p0x = a.x
        mov  ax, [si+2]         ; AX = a.y
        mov  [p0y], ax          ; p0y = a.y
        mov  ax, [bx]           ; AX = b.x
        mov  [p1x], ax          ; p1x = b.x
        mov  ax, [bx+2]         ; AX = b.y
        mov  [p1y], ax          ; p1y = b.y
        jmp  Line               ; line(), and Line's RET returns for us

;  In C:   col = EDGC;  edge(&vlist[0], &vlist[1]);  edge(&vlist[1], &vlist[2]);
;                       edge(&vlist[2], &vlist[3]);  edge(&vlist[3], &vlist[0]);
DrawEdges:
        mov  byte [col], EDGC   ; col = white
        mov  si, vlist          ; SI = &vlist[0]
        mov  bx, vlist+4        ; BX = &vlist[1]
        call EdgeFT             ; edge(0, 1)
        mov  si, vlist+4        ; SI = &vlist[1]
        mov  bx, vlist+8        ; BX = &vlist[2]
        call EdgeFT             ; edge(1, 2)
        mov  si, vlist+8        ; SI = &vlist[2]
        mov  bx, vlist+12       ; BX = &vlist[3]
        call EdgeFT             ; edge(2, 3)
        mov  si, vlist+12       ; SI = &vlist[3]
        mov  bx, vlist          ; BX = &vlist[0]: the last tip closes back on the first
        call EdgeFT             ; edge(3, 0)
        ret                     ; return

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
shvec   db 1                    ; the spin frames: draw the vectors, or not

include 'SINTAB.INC'
include 'DRAW10.INC'

; ---- one spin frame: wipe, recompute, redraw -------------------------------
;  This loop IS the lesson: nothing rotates. Four numbers change, the
;  screen is wiped, four vectors are drawn where the numbers now say.
;  In C:   vsync(); gclear(); verts(); if (shvec) draw_vecs(); draw_edges();
Spin:   call Vsync              ; vsync()
        call GClear             ; gclear()
        call Verts              ; verts(): four numbers -> four tips
        cmp  byte [shvec], 0    ; shvec ?
        je   .nv                ;   no: no scaffolding
        call DrawVecs           ; draw_vecs()
.nv:    call DrawEdges          ; draw_edges()
        ret                     ; return

;  In C:
;
;      int main(void)
;      {
;          set_mode(3); cursor_off(); puts_at(...); bottom(); key();      /* 1 */
;          set_mode(0x13); gclear(); dot(scx, scy); verts();              /* 2 */
;          draw_vec(&vlist[0]); key(); draw_vec(&vlist[1]); hold(); ...
;          col = EDGC; edge(0,1); hold(); edge(1,2); hold(); ...; key();  /* 3 */
;          shvec = 1; do { spin(); ang++; } while (!key_check());         /* 4 */
;          shvec = 0; do { spin(); ang++; } while (!key_check());         /* 5 */
;          shvec = 1; do { scx = CX0 + SINTAB[tt] * 60 >> 7; spin(); tt += 2; }
;                     while (!key_check());  scx = CX0;                   /* 6 */
;          do { rad = R0 + SINTAB[tt] * 30 >> 7; spin(); tt += 2; }
;                     while (!key_check());  rad = R0;                    /* 7 */
;          set_mode(3); cursor_off(); puts_at(...); bottom(); key();      /* 8 */
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
        mov  di, 0*ROW + 26*2   ; DI = row 0, column 26
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
        mov  si, t_a4           ; SI = t_a4
        mov  di, 7*ROW + 7*2    ; DI = row 7, column 7
        call PutS               ; puts()
        mov  byte [attr], HEAD  ; attr = HEAD
        mov  si, t_a5           ; SI = t_a5
        mov  di, 10*ROW + 7*2   ; DI = row 10, column 7
        call PutS               ; puts()
        mov  si, t_a6           ; SI = t_a6
        mov  di, 11*ROW + 7*2   ; DI = row 11, column 7
        call PutS               ; puts()
        mov  byte [attr], NORM  ; attr = NORM
        mov  si, t_a7           ; SI = t_a7
        mov  di, 12*ROW + 7*2   ; DI = row 12, column 7
        call PutS               ; puts()
        call Bottom             ; bottom(): "- any key -"
        call Key                ; key()

; ---- 2. one vector, then four ----------------------------------------------
        mov  ax, 0013h          ; AX = 13h: the graphics screen, 320x200
        int  10h                ; set_mode(0x13)
        mov  ax, VGA            ; AX = A000h
        mov  es, ax             ; ES = the graphics screen
        call GClear             ; gclear()
        mov  byte [dcol], EDGC  ; dcol = white: the centre - translation will
        mov  ax, [scx]          ; AX = scx      move THIS dot before the lesson is out
        mov  bx, [scy]          ; BX = scy
        call Dot                ; dot(scx, scy)
        call Verts              ; verts()
        mov  si, vlist          ; the first vector, alone on the screen
        call DrawVec            ; draw_vec(SI)
        call Key                ; key()
        mov  si, vlist+4        ; ...then its three brothers, one a beat
        call DrawVec            ; draw_vec(SI)
        call Hold               ; hold(): a fifth of a second
        mov  si, vlist+8        ; SI = &vlist[2]
        call DrawVec            ; draw_vec(SI)
        call Hold               ; hold(): a fifth of a second
        mov  si, vlist+12       ; SI = &vlist[3]
        call DrawVec            ; draw_vec(SI)
        call Key                ; key()

; ---- 3. the edges, one a beat ----------------------------------------------
        mov  byte [col], EDGC   ; col = white
        mov  si, vlist          ; SI = &vlist[0]
        mov  bx, vlist+4        ; BX = &vlist[1]
        call EdgeFT             ; edge(SI, BX)
        call Hold               ; hold(): a fifth of a second
        mov  si, vlist+4        ; SI = &vlist[1]
        mov  bx, vlist+8        ; BX = &vlist[2]
        call EdgeFT             ; edge(SI, BX)
        call Hold               ; hold(): a fifth of a second
        mov  si, vlist+8        ; SI = &vlist[2]
        mov  bx, vlist+12       ; BX = &vlist[3]
        call EdgeFT             ; edge(SI, BX)
        call Hold               ; hold(): a fifth of a second
        mov  si, vlist+12       ; SI = &vlist[3]
        mov  bx, vlist          ; BX = &vlist[0]: the last tip closes back on the first
        call EdgeFT             ; edge(SI, BX)
        call Key                ; key()

; ---- 4. the turn -----------------------------------------------------------
        mov  byte [shvec], 1    ; shvec = 1: the vectors shown
.spin1: call Spin               ; spin(): one frame
        inc  byte [ang]         ; ang++   - and that is the whole rotation
        call KeyChk             ; AL = key_check()
        or   al, al             ; a key ?
        jz   .spin1             ;   no: another frame

; ---- 5. wireframe: the vectors hidden --------------------------------------
        mov  byte [shvec], 0    ; shvec = 0: the vectors hidden
.spin2: call Spin               ; spin()
        inc  byte [ang]         ; ang++
        call KeyChk             ; AL = key_check()
        or   al, al             ; a key ?
        jz   .spin2             ;   no: another frame

; ---- 6. translate: the centre moves ----------------------------------------
        mov  byte [shvec], 1    ; shvec = 1
.mov1:  mov  al, [tt]           ; AL = tt, the wander clock
        mov  bx, SINTAB         ; BX = the table
        xlatb                   ; AL = SINTAB[tt]
        mov  bl, 60             ; BL = 60: sixty pixels of wander, each way
        imul bl                 ; AX = sin * 60
        mov  cl, 7              ; CL = 7
        sar  ax, cl             ; AX >>= 7: /128
        add  ax, CX0            ; AX += CX0
        mov  [scx], ax          ; scx = AX: the centre, moved
        call Spin               ; spin()
        add  byte [tt], 2       ; tt += 2
        call KeyChk             ; AL = key_check()
        or   al, al             ; a key ?
        jz   .mov1              ;   no: another frame
        mov  word [scx], CX0    ; scx = CX0: home again

; ---- 7. scale: the lengths breathe -----------------------------------------
.scl1:  mov  al, [tt]           ; AL = tt
        mov  bx, SINTAB         ; BX = the table
        xlatb                   ; AL = SINTAB[tt]
        mov  bl, 30             ; BL = 30: thirty length-units of breath
        imul bl                 ; AX = sin * 30
        mov  cl, 7              ; CL = 7
        sar  ax, cl             ; AX >>= 7
        add  ax, R0             ; AX += R0
        mov  [rad], al          ; rad = AL: the length, changed
        call Spin               ; spin()
        add  byte [tt], 2       ; tt += 2
        call KeyChk             ; AL = key_check()
        or   al, al             ; a key ?
        jz   .scl1              ;   no: another frame
        mov  byte [rad], R0     ; rad = R0: home again

; ---- 8. the words, closing -------------------------------------------------
        mov  ax, 0003h          ; AX = 3: the text screen
        int  10h                ; set_mode(3)
        call TextOff            ; cursor_off()
        mov  ax, TEXT           ; AX = B800h
        mov  es, ax             ; ES = the text screen
        mov  byte [attr], HEAD  ; attr = HEAD
        mov  si, t_head         ; SI = t_head
        mov  di, 0*ROW + 26*2   ; DI = row 0, column 26
        call PutS               ; puts()
        mov  si, t_z1           ; SI = t_z1
        mov  di, 3*ROW + 7*2    ; DI = row 3, column 7
        call PutS               ; puts()
        mov  byte [attr], NORM  ; attr = NORM
        mov  si, t_z2           ; SI = t_z2
        mov  di, 5*ROW + 7*2    ; DI = row 5, column 7
        call PutS               ; puts()
        mov  si, t_z3           ; SI = t_z3
        mov  di, 6*ROW + 7*2    ; DI = row 6, column 7
        call PutS               ; puts()
        mov  si, t_z4           ; SI = t_z4
        mov  di, 7*ROW + 7*2    ; DI = row 7, column 7
        call PutS               ; puts()
        mov  si, t_z5           ; SI = t_z5
        mov  di, 10*ROW + 7*2   ; DI = row 10, column 7
        call PutS               ; puts()
        mov  si, t_z6           ; SI = t_z6
        mov  di, 11*ROW + 7*2   ; DI = row 11, column 7
        call PutS               ; puts()
        mov  byte [attr], HEAD  ; attr = HEAD
        mov  si, t_ow1          ; SI = t_ow1
        mov  di, 15*ROW + 7*2   ; DI = row 15, column 7
        call PutS               ; puts()
        mov  byte [attr], 0Eh   ; attr = 0Eh
        mov  si, t_ow2          ; SI = t_ow2
        mov  di, 16*ROW + 7*2   ; DI = row 16, column 7
        call PutS               ; puts()
        mov  byte [attr], NORM  ; attr = NORM
        call Bottom             ; bottom(): "- any key -"
        call Key                ; key()

Bye:    mov  ax, 0003h          ; AX = 3: a clean screen back to DOS
        int  10h                ; set_mode(3)
        mov  ax, 4C00h          ; AH = 4Ch exit, AL = 0 the code
        int  21h                ; exit(0)
