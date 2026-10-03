; ============================================================================
;  SLANT.ASM - Lesson 8. The program that rewrites itself.
;
;      FASM SLANT.ASM SLANT.COM
;
;      1  code is bytes   the program reads its own ADD and prints it
;      2  two crosses     the left one asks a question at every pixel;
;                         the right one wrote the answer into its code
;      3  the trap        the prefetch queue, the jump, and why the
;                         debugger will never show you this bug
;      4  the debt        a slanted line on the toy screen, step by step
;      5  the fan         one routine, every direction, no questions
;                         left inside the loop
;
;  THE ONE FACT THIS LESSON HANDS OVER: an instruction is bytes, and they
;  live in the same memory as your data. A program can READ its own code -
;  frame 1 does - and it can WRITE it. Today that idea wears the name JIT:
;  a program writing, at run time, the exact instructions the moment needs.
;  Its old name is self-modifying code, and it was how a line drawer
;  earned its speed: decide the direction ONCE, write it into the ADD, and
;  the inner loop runs with no questions left inside it.
;
;  THE PRICE IS A RULE. The 8086 reads ahead: while one instruction runs,
;  the next SIX BYTES of code already sit inside the prefetch queue - real
;  silicon, a real copy. Patch a byte the queue has swallowed and the OLD
;  byte executes; the write went to memory, the queue does not look back.
;  Any jump empties the queue. So: PATCH, THEN JUMP. Always - even when,
;  as everywhere below, the patched ADD is farther ahead than six bytes.
;  The rule costs two bytes; the bug it prevents cannot be seen in a
;  debugger at all, because a debugger single-steps on interrupts and an
;  interrupt empties the queue too. Step through it and it works; let it
;  run and it does not. (DOSBox does not model the queue - the emulator
;  forgives what real iron does not. The rule stands.)
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

TOYW    = 5                     ; lesson 7's toy screen, back for one frame:
TOYH    = 4                     ;  five across, four down, one byte a cell
CELLW   = 6
GX      = 25                    ; where the grid sits, in characters
GY      = 7

NORM    = 07h                   ; grey on black
HEAD    = 0Fh                   ; white
LIT     = 4Eh                   ; yellow on red: the cell the line just lit

        jmp  Boot               ; over the routines, to the boot at the bottom

; ============================================================================
;  The line - frame 5's whole point. From (p0x,p0y) to (p1x,p1y) in [col]:
;  ONE routine for every direction, because the two directions it must
;  remember are decided once and written into the two ADDs of the loop.
; ============================================================================
;  In C:
;
;      void line(void)
;      {
;          int adx = abs(p1x - p0x), stx = (p1x >= p0x) ? 1 : -1;
;          int ady = abs(p1y - p0y), sty = (p1y >= p0y) ? 320 : -320;
;          int dmaj, dmin, major_step, minor_step;
;          if (adx >= ady) { dmaj = adx; dmin = ady; major_step = stx; minor_step = sty; }
;          else            { dmaj = ady; dmin = adx; major_step = sty; minor_step = stx; }
;          int at = p0y * 320 + p0x, debt = 0;
;          for (int n = dmaj + 1; n > 0; n--) {
;              screen[at] = col;
;              debt += dmin;
;              if (debt >= dmaj) { debt -= dmaj; at += minor_step; }
;              at += major_step;
;          }
;      }
;
;  What C cannot show: major_step and minor_step are not variables here.
;  They are written INTO the two ADD instructions of the loop, so the loop
;  carries no `if` about which way the line leans. THE RULE for code that
;  rewrites itself on an 8086: patch, then JUMP - the prefetch queue has
;  already fetched the old bytes, and only a jump throws them away.
Line:
        mov  ax, [p1x]          ; AX = p1x
        sub  ax, [p0x]          ; AX = dx = p1x - p0x, signed...
        mov  bx, 1              ; BX = stx = +1: ...and the step right with it
        or   ax, ax             ; dx < 0 ?
        jns  .dxp               ;   no
        neg  ax                 ;   yes: AX = -dx. NEG: nought minus the thing. The
        mov  bx, -1             ;        BX = -1   DISTANCE must be positive; its
.dxp:   mov  [adx], ax          ; adx = |dx|       SIGN moves into the step instead
        mov  [stx], bx          ; stx = +-1
        mov  ax, [p1y]          ; AX = p1y
        sub  ax, [p0y]          ; AX = dy = p1y - p0y, the same way...
        mov  bx, W              ; BX = sty = +320: ...but ITS step is a row
        or   ax, ax             ; dy < 0 ?
        jns  .dyp               ;   no
        neg  ax                 ;   yes: AX = -dy
        mov  bx, -W             ;        BX = -320
.dyp:   mov  [ady], ax          ; ady = |dy|
        mov  [sty], bx          ; sty = +-320

        ; ---- which distance is longer DRIVES the loop; the other one
        ; feeds the debt. Both answers are written into the code.
        mov  ax, [adx]          ; AX = adx
        cmp  ax, [ady]          ; adx < ady ?
        jb   .ymaj              ;   yes: y-major
        mov  [dmaj], ax         ; dmaj = adx    x-major: step right every pixel...
        mov  ax, [ady]          ; AX = ady
        mov  [dmin], ax         ; dmin = ady
        mov  ax, [stx]          ; AX = stx
        mov  [.majs+2], ax      ; major_step = stx  ...so the driving ADD gets +-1
        mov  ax, [sty]          ; AX = sty
        mov  [.mins+2], ax      ; minor_step = sty  ...and the debt ADD gets +-320
        jmp  .go                ; over the y-major case
.ymaj:  mov  [dmin], ax         ; dmin = adx    y-major: the roles swap, no more
        mov  ax, [ady]          ; AX = ady
        mov  [dmaj], ax         ; dmaj = ady
        mov  ax, [sty]          ; AX = sty
        mov  [.majs+2], ax      ; major_step = sty
        mov  ax, [stx]          ; AX = stx
        mov  [.mins+2], ax      ; minor_step = stx
.go:    jmp  short .fl          ; THE RULE again: patch, then jump
.fl:
        mov  ax, [p0y]          ; AX = p0y       where the line starts:
        mov  bx, W              ; BX = 320       lesson 7's formula
        mul  bx                 ; AX = p0y * 320
        add  ax, [p0x]          ; AX = p0y * 320 + p0x
        mov  di, ax             ; DI = at
        mov  bl, [col]          ; BL = col
        mov  cx, [dmaj]         ; CX = dmaj
        inc  cx                 ; CX = n = dmaj + 1: both ends belong to the line
        xor  dx, dx             ; DX = debt = 0, starting clean
.px:    mov  [es:di], bl        ; screen[at] = col
        add  dx, [dmin]         ; debt += dmin: every step the debt grows by
        cmp  dx, [dmaj]         ; debt >= dmaj ?  the short distance - reached
        jb   .nod               ;   no             the long one?
        sub  dx, [dmaj]         ;   yes: debt -= dmaj, paid off...
.mins:  add  di, W              ;        at += minor_step  ...one sideways step   (REWRITTEN)
.nod:
.majs:  add  di, W              ; at += major_step: the driving step, every pixel (REWRITTEN)
        loop .px                ; n-- ; while (n)
        ret                     ; return

; ---- one spoke of the fan: draw, next colour, a beat -----------------------
;  In C:   line();  if (++col == 16) col = 1;  hold();
FanOne: call Line               ; line()
        inc  byte [col]         ; col++: walk the palette as the fan walks round
        cmp  byte [col], 16     ; col == 16 ?
        jb   .c                 ;   no
        mov  byte [col], 1      ;   yes: col = 1 - never 0, a black line draws nothing
.c:     call Hold               ; hold()
        ret                     ; return

; ---- what the frames say ---------------------------------------------------
t_head  db 'THE PROGRAM THAT REWRITES ITSELF',0
t_c1    db 'An instruction is bytes. Here is ADD DI,320 - read out of THIS',0
t_c2    db 'program, by this program, while it runs:',0
t_c3    db 'It lives in the same memory as your data. So a program can also',0
t_c4    db 'WRITE its own instructions. Today that is called JIT.',0
t_c5    db 'Its old name is self-modifying code.',0
t_x1    db 'Next: two crosses. The LEFT one asks "up or down?" at EVERY',0
t_x2    db 'pixel - 480 questions with the same answer. The RIGHT one was',0
t_x3    db 'asked ONCE: the answer was written into its ADD before the loop.',0
t_x4    db 'The pictures will be identical. That is the point.',0
t_t1    db 'THE TRAP. The 8086 reads ahead: six bytes of the code to come',0
t_t2    db 'already sit in the PREFETCH QUEUE - real silicon, a real copy.',0
t_t3    db 'Patch a byte the queue has swallowed, and the OLD byte runs.',0
t_t4    db 'Any jump empties the queue. So the rule: PATCH, THEN JUMP.',0
t_t5    db 'And the debugger? It single-steps on interrupts, and an',0
t_t6    db 'interrupt empties the queue too. Step through it: it works.',0
t_t7    db 'Let it run: it does not. The one bug your debugger cannot show',0
t_t8    db 'you - which is why it is a rule, not a memory.',0
t_d1    db 'A slanted line is a horizontal line that pays a DEBT. Every',0
t_d2    db 'step RIGHT adds dy to the debt; when the debt reaches dx, one',0
t_d3    db 'step DOWN pays it off. From (0,0) to (4,2): dx=4, dy=2.',0
t_debt  db 'debt:',0
t_f1    db 'Now both together: the debt pays for the slope, the rewritten',0
t_f2    db 'ADDs pay for the direction - ONE routine, every direction, and',0
t_f3    db 'no questions left inside the loop. Any key - and watch.',0
t_key   db '- any key -',0

; ---- state -----------------------------------------------------------------
tx      dw 0                    ; toy cell being drawn
ty      dw 0
p0x     dw 0                    ; the line: from (p0x,p0y) to (p1x,p1y)
p0y     dw 0
p1x     dw 0
p1y     dw 0
adx     dw 0                    ; |dx|, |dy| - the two distances
ady     dw 0
stx     dw 0                    ; and the two signed steps: +-1, +-320
sty     dw 0
dmaj    dw 0                    ; the long distance drives the loop...
dmin    dw 0                    ; ...the short one feeds the debt
sdir    db 0                    ; the crosses: 0 = down-right, 1 = up-right
col     db 15

include 'DRAW8.INC'

; ============================================================================
;  Frame 2's two slope routines. Both draw CX pixels from ES:DI in BL,
;  stepping one pixel right and one row up or down - a perfect diagonal.
; ============================================================================

; ---- the LEFT cross: the question is asked at every pixel ------------------
;  [sdir] never changes while the loop runs, so this is a loop asking, CX
;  times over, a question whose answer was known before it started.
;  In C:
;
;      void slope_if(int at, int n, int c)
;      {
;          while (n--) {
;              screen[at] = c;
;              if (sdir == 0) at += 321;  else at += 1 - 320;   /* asked EVERY pixel */
;          }
;      }
SlopeIf:
.px:    mov  [es:di], bl        ; screen[at] = c
        cmp  byte [sdir], 0     ; sdir == 0 ?  the question...
        jnz  .up                ;   no: the other answer
        add  di, W+1            ;   yes: at += 321, a row down, a pixel right
        jmp  .nx                ; over the other answer
.up:    add  di, 1-W            ; at += 1 - 320: a row up, a pixel right
.nx:    loop .px                ; n-- ; while (n)
        ret                     ; return

; ---- the RIGHT cross: the question is asked ONCE ---------------------------
;  The answer is WRITTEN INTO THE ADD before the loop starts. What is left
;  inside the loop is a write, an add and the count - no questions.
;  In C there is no way to write this; the nearest is a lie:
;
;      void slope_jit(int at, int n, int c)
;      {
;          int step = (sdir == 0) ? 321 : 1 - 320;     /* asked ONCE...           */
;          while (n--) { screen[at] = c;  at += step; } /* ...but `step` here is a */
;      }                                                /*  VARIABLE. Below it is  */
;                                                       /*  the ADD's own two bytes */
SlopeJit:
        mov  ax, W+1            ; AX = 321: one of the two answers...
        cmp  byte [sdir], 0     ; sdir == 0 ?
        jz   .wr                ;   yes: 321 it is
        mov  ax, 1-W            ;   no:  AX = 1 - 320
.wr:    mov  [.step+2], ax      ; *(.step + 2) = AX: ...written INTO the instruction.
                                ;  Code is bytes, and these two are its number
        jmp  short .fl          ; THE RULE: patch, then jump - the jump
.fl:                            ;  empties the prefetch queue (frame 3)
.px:    mov  [es:di], bl        ; screen[at] = c
.step:  add  di, W+1            ; at += (whatever the two bytes say). 81 C7 lo hi:
                                ;  the number above is written over lo hi. 320
                                ;  forces the WIDE form, so the slot is always two
        loop .px                ; n-- ; while (n)
        ret                     ; return

; ---- one toy cell at (tx,ty), a two-digit number in [attr] -----------------
;  Lesson 7's cell, one lesson on: the number in the cell is the offset,
;  offset = y * width + x.
;  In C:
;
;      void cell(void)                              /* the toy cell at (tx, ty) */
;      {
;          gotoxy(GX + tx * CELLW, GY + ty);
;          putc(' ');  put_num(ty * TOYW + tx);  putc(' ');   /* its own offset */
;      }
Cell:   mov  ax, [ty]           ; AX = ty
        add  ax, GY             ; AX = ty + GY
        mov  bx, ROW            ; BX = 160 bytes a row
        mul  bx                 ; AX = (ty + GY) * 160: which text row...
        mov  di, ax             ; DI = the row start
        mov  ax, [tx]           ; AX = tx
        mov  bx, CELLW          ; BX = 6 characters a cell
        mul  bx                 ; AX = tx * 6
        add  ax, GX             ; AX = tx * 6 + GX
        add  ax, ax             ; AX *= 2: ...and which column, two bytes a character
        add  di, ax             ; DI += the column
        mov  al, ' '            ; AL = ' '
        call PutC               ; putc(' ')
        mov  ax, [ty]           ; AX = ty
        mov  bx, TOYW           ; BX = 5
        mul  bx                 ; AX = ty * 5
        add  ax, [tx]           ; AX = ty * 5 + tx: the cell's own offset
        call PutN               ; put_num(AX): written inside it
        mov  al, ' '            ; AL = ' '
        call PutC               ; putc(' ')
        ret                     ; return

; ---- the whole toy grid ----------------------------------------------------
;  In C:   for (ty = 0; ty < TOYH; ty++) for (tx = 0; tx < TOYW; tx++) cell();
Grid:   mov  word [ty], 0       ; ty = 0
.row:   mov  word [tx], 0       ; tx = 0
.cell:  call Cell               ; cell()
        inc  word [tx]          ; tx++
        mov  ax, [tx]           ; AX = tx
        cmp  ax, TOYW           ; tx < TOYW ?
        jl   .cell              ;   yes: next cell
        inc  word [ty]          ; ty++
        mov  ax, [ty]           ; AX = ty
        cmp  ax, TOYH           ; ty < TOYH ?
        jl   .row               ;   yes: next row
        ret                     ; return

; ---- the hint at the bottom ------------------------------------------------
;  In C:   attr = 8;  puts_at(23, 34, "- any key -");  attr = NORM;
Bottom: mov  si, t_key          ; SI = the string
        mov  di, 23*ROW + 34*2  ; DI = row 23, column 34
        mov  byte [attr], 08h   ; attr = 8, dark grey
        call PutS               ; puts()
        mov  byte [attr], NORM  ; attr = NORM
        ret                     ; return

; ---- a headline and a clean screen -----------------------------------------
;  In C:   tclear();  attr = HEAD;  puts_at(0, 24, t_head);  attr = NORM;
Head:   call TClear             ; tclear()
        mov  byte [attr], HEAD  ; attr = white
        mov  si, t_head         ; SI = t_head
        mov  di, 0*ROW + 24*2   ; DI = row 0, column 24
        call PutS               ; puts()
        mov  byte [attr], NORM  ; attr = NORM
        ret                     ; return

;  In C:
;
;      int main(void)
;      {
;          set_mode(3); cursor_off();
;          /* 1 */ head(); puts_at(...); for (i = 0; i < 4; i++) put_hex(code[i]); ...; key();
;          /* 2 */ set_mode(0x13); gclear(); slope_if(...) x2; slope_jit(...) x2; key();
;          /* 3 */ set_mode(3); head(); puts_at(...eight lines...); key();
;          /* 4 */ head(); grid(); for (tx = ty = debt = 0; ; ) { cell(); put_num(debt);
;                  if (tx == 4) break; tx++; debt += 2; if (debt >= 4) { debt -= 4; ty++; } }
;          /* 5 */ head(); puts_at(...); key(); set_mode(0x13); gclear();
;                  the fan: p1 walks the four edges of the screen, fan_one() each spoke
;          set_mode(3); exit(0);
;      }
Boot:   cld                     ; string ops count UP: DI counts up in every STOS
        mov  ax, 0003h          ; AX = 3: the text screen, 80x25
        int  10h                ; set_mode(3)
        call TextOff            ; cursor_off()
        mov  ax, TEXT           ; AX = B800h
        mov  es, ax             ; ES = the text screen: frames 1, 3 and 4 talk here

; ---- 1. code is bytes ------------------------------------------------------
;  The program reads ITS OWN instruction and prints it. SlopeJit's ADD is
;  ADD DI,321: the assembler wrote 81 C7 41 01, and here those bytes are.
F1:     call Head
        mov  si, t_c1           ; SI = t_c1
        mov  di, 3*ROW + 7*2    ; DI = row 3, column 7
        call PutS               ; puts()
        mov  si, t_c2           ; SI = t_c2
        mov  di, 4*ROW + 7*2    ; DI = row 4, column 7
        call PutS               ; puts()
        mov  si, SlopeJit.step  ; SI = &SlopeJit.step: the address of a LIVE instruction
        mov  cx, 4              ; CX = 4 bytes: opcode, register, number
        mov  di, 7*ROW + 30*2   ; DI = row 7, column 30
        mov  byte [attr], HEAD  ; attr = white
.byte:  lodsb                   ; AL = *si++: the byte of code, into AL like any data
        call PutB               ; put_hex(AL): ...printed as two hex digits (lesson 2)
        mov  al, ' '            ; AL = ' '
        call PutC               ; putc(' ')
        loop .byte              ; 4 bytes
        mov  byte [attr], NORM  ; attr = NORM
        mov  si, t_c3           ; SI = t_c3
        mov  di, 10*ROW + 7*2   ; DI = row 10, column 7
        call PutS               ; puts()
        mov  si, t_c4           ; SI = t_c4
        mov  di, 11*ROW + 7*2   ; DI = row 11, column 7
        call PutS               ; puts()
        mov  byte [attr], HEAD  ; attr = HEAD
        mov  si, t_c5           ; SI = t_c5
        mov  di, 13*ROW + 7*2   ; DI = row 13, column 7
        call PutS               ; puts()
        mov  byte [attr], NORM  ; attr = NORM
        mov  si, t_x1           ; SI = t_x1
        mov  di, 17*ROW + 7*2   ; DI = row 17, column 7
        call PutS               ; puts()
        mov  si, t_x2           ; SI = t_x2
        mov  di, 18*ROW + 7*2   ; DI = row 18, column 7
        call PutS               ; puts()
        mov  si, t_x3           ; SI = t_x3
        mov  di, 19*ROW + 7*2   ; DI = row 19, column 7
        call PutS               ; puts()
        mov  si, t_x4           ; SI = t_x4
        mov  di, 20*ROW + 7*2   ; DI = row 20, column 7
        call PutS               ; puts()
        call Bottom             ; bottom(): "- any key -"
        call Key                ; key()

; ---- 2. the two crosses ----------------------------------------------------
;  Each cross is two diagonal runs. The left pair goes through SlopeIf -
;  480 questions; the right pair through SlopeJit - one question, then a
;  loop with nothing inside it but work. The pictures come out identical.
F2:     mov  ax, 0013h          ; AX = 13h: the graphics screen, 320x200
        int  10h                ; set_mode(0x13)
        mov  ax, VGA            ; AX = A000h
        mov  es, ax             ; ES = the graphics screen
        call GClear             ; gclear()
        mov  bl, 14             ; BL = 14, yellow: the asking cross
        mov  byte [sdir], 0     ; sdir = 0: down-right
        mov  di, 40*W + 20      ; DI = at = (20, 40)
        mov  cx, 120            ; CX = 120 pixels
        call SlopeIf            ; slope_if(at, 120, 14): down-right from (20,40)...
        call Hold               ; hold()
        mov  byte [sdir], 1     ; sdir = 1: up-right
        mov  di, 159*W + 20     ; DI = at = (20, 159)
        mov  cx, 120            ; CX = 120
        call SlopeIf            ; slope_if(): ...up-right from (20,159): an X
        call Hold               ; hold()
        mov  bl, 10             ; BL = 10, green: the rewritten cross
        mov  byte [sdir], 0     ; sdir = 0
        mov  di, 40*W + 180     ; DI = at = (180, 40)
        mov  cx, 120            ; CX = 120
        call SlopeJit           ; slope_jit(at, 120, 10)
        call Hold               ; hold()
        mov  byte [sdir], 1     ; sdir = 1
        mov  di, 159*W + 180    ; DI = at = (180, 159)
        mov  cx, 120            ; CX = 120
        call SlopeJit           ; slope_jit()
        call Key                ; key()

; ---- 3. the trap -----------------------------------------------------------
F3:     mov  ax, 0003h          ; AX = 3: the text screen
        int  10h                ; set_mode(3)
        call TextOff            ; cursor_off()
        mov  ax, TEXT           ; AX = B800h
        mov  es, ax             ; ES = the text screen
        call Head               ; head(): a clean screen, the headline
        mov  byte [attr], HEAD  ; attr = HEAD
        mov  si, t_t1           ; SI = t_t1
        mov  di, 3*ROW + 7*2    ; DI = row 3, column 7
        call PutS               ; puts()
        mov  byte [attr], NORM  ; attr = NORM
        mov  si, t_t2           ; SI = t_t2
        mov  di, 4*ROW + 7*2    ; DI = row 4, column 7
        call PutS               ; puts()
        mov  si, t_t3           ; SI = t_t3
        mov  di, 5*ROW + 7*2    ; DI = row 5, column 7
        call PutS               ; puts()
        mov  byte [attr], HEAD  ; attr = HEAD
        mov  si, t_t4           ; SI = t_t4
        mov  di, 7*ROW + 7*2    ; DI = row 7, column 7
        call PutS               ; puts()
        mov  byte [attr], NORM  ; attr = NORM
        mov  si, t_t5           ; SI = t_t5
        mov  di, 10*ROW + 7*2   ; DI = row 10, column 7
        call PutS               ; puts()
        mov  si, t_t6           ; SI = t_t6
        mov  di, 11*ROW + 7*2   ; DI = row 11, column 7
        call PutS               ; puts()
        mov  si, t_t7           ; SI = t_t7
        mov  di, 12*ROW + 7*2   ; DI = row 12, column 7
        call PutS               ; puts()
        mov  si, t_t8           ; SI = t_t8
        mov  di, 13*ROW + 7*2   ; DI = row 13, column 7
        call PutS               ; puts()
        call Bottom             ; bottom(): "- any key -"
        call Key                ; key()

; ---- 4. the debt, on the toy screen ----------------------------------------
;  The walk from (0,0) to (4,2), one cell a beat, the debt printed beside
;  it: 0, 2, 4-pays-down, 2, 4-pays-down, done. dx=4, dy=2 - two downs
;  spread as evenly as whole steps can be.
F4:     call Head
        mov  si, t_d1           ; SI = t_d1
        mov  di, 2*ROW + 7*2    ; DI = row 2, column 7
        call PutS               ; puts()
        mov  si, t_d2           ; SI = t_d2
        mov  di, 3*ROW + 7*2    ; DI = row 3, column 7
        call PutS               ; puts()
        mov  si, t_d3           ; SI = t_d3
        mov  di, 4*ROW + 7*2    ; DI = row 4, column 7
        call PutS               ; puts()
        call Grid               ; grid(): the toy screen
        mov  si, t_debt         ; SI = t_debt
        mov  di, 13*ROW + 25*2  ; DI = row 13, column 25
        call PutS               ; puts()
        call Bottom             ; bottom(): "- any key -"
        mov  word [tx], 0       ; tx = 0: the walk itself - x drives, the debt
        mov  word [ty], 0       ; ty = 0   decides when y may follow
        xor  dx, dx             ; DX = debt = 0
.step:  mov  byte [attr], LIT   ; attr = yellow on red
        call Cell               ; cell(): light the cell the line owns...
        mov  byte [attr], NORM  ; attr = NORM
        push dx                 ; keep the debt: MUL and DIV eat DX
        mov  ax, dx             ; AX = debt
        mov  di, 13*ROW + 31*2  ; DI = row 13, column 31: ...beside the grid
        mov  byte [attr], HEAD  ; attr = white
        call PutN               ; put_num(debt)
        mov  byte [attr], NORM  ; attr = NORM
        pop  dx                 ; DX = debt
        call Hold               ; hold()
        call Hold               ; hold(): two beats, this frame is the slow one
        mov  ax, [tx]           ; AX = tx
        cmp  ax, TOYW-1         ; tx >= 4 ?  the last cell
        jae  .done              ;   yes: done
        inc  word [tx]          ; tx++: the step right, every time...
        add  dx, 2              ; debt += 2: ...grows the debt by dy
        cmp  dx, 4              ; debt >= 4 ?  reached dx?
        jb   .step              ;   no: next cell
        sub  dx, 4              ;   yes: debt -= 4, paid off...
        inc  word [ty]          ; ty++: ...with the one step down
        jmp  .step              ; next cell
.done:  call Key                ; key()

; ---- 5. the fan ------------------------------------------------------------
;  Everything at once: the debt from frame 4 inside the loop, the two
;  rewritten ADDs from frame 2 in front of it. One routine, every
;  direction on the screen, drawn as a fan from the centre.
F5:     call Head
        mov  si, t_f1           ; SI = t_f1
        mov  di, 9*ROW + 7*2    ; DI = row 9, column 7
        call PutS               ; puts()
        mov  si, t_f2           ; SI = t_f2
        mov  di, 10*ROW + 7*2   ; DI = row 10, column 7
        call PutS               ; puts()
        mov  si, t_f3           ; SI = t_f3
        mov  di, 11*ROW + 7*2   ; DI = row 11, column 7
        call PutS               ; puts()
        call Bottom             ; bottom(): "- any key -"
        call Key                ; key()
        mov  ax, 0013h          ; AX = 13h: the graphics screen
        int  10h                ; set_mode(0x13)
        mov  ax, VGA            ; AX = A000h
        mov  es, ax             ; ES = the graphics screen
        call GClear             ; gclear()
        mov  word [p0x], 160    ; p0x = 160  \  every line starts at the centre
        mov  word [p0y], 100    ; p0y = 100  /
        mov  word [p1y], 0      ; p1y = 0    ---- along the top edge, left to right
        mov  word [p1x], 0      ; p1x = 0
.top:   call FanOne             ; fan_one()
        add  word [p1x], 16     ; p1x += 16
        cmp  word [p1x], W      ; p1x < 320 ?
        jl   .top               ;   yes: next spoke
        mov  word [p1x], W-1    ; p1x = 319  ---- down the right edge
        mov  word [p1y], 0      ; p1y = 0
.rgt:   call FanOne             ; fan_one()
        add  word [p1y], 16     ; p1y += 16
        cmp  word [p1y], H      ; p1y < 200 ?
        jl   .rgt               ;   yes: next spoke
        mov  word [p1y], H-1    ; p1y = 199  ---- along the bottom, right to left
        mov  word [p1x], W-1    ; p1x = 319
.bot:   call FanOne             ; fan_one()
        sub  word [p1x], 16     ; p1x -= 16
        cmp  word [p1x], 0      ; p1x >= 0 ?
        jge  .bot               ;   yes: next spoke
        mov  word [p1x], 0      ; p1x = 0    ---- and up the left edge, closing it
        mov  word [p1y], H-1    ; p1y = 199
.lft:   call FanOne             ; fan_one()
        sub  word [p1y], 16     ; p1y -= 16
        cmp  word [p1y], 0      ; p1y >= 0 ?
        jge  .lft               ;   yes: next spoke
        call Key                ; key()

Bye:    mov  ax, 0003h          ; AX = 3: back to text, 80x25
        int  10h                ; set_mode(3)
        mov  ax, 4C00h          ; AH = 4Ch exit, AL = 0 the code
        int  21h                ; exit(0): hand the machine back to DOS
