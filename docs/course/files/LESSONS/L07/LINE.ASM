; ============================================================================
;  LINE.ASM - Lesson 7. Memory is one line. The screen is not.
;
;      FASM LINE.ASM LINE.COM
;
;      1  the fold     a toy screen of forty bytes, and the same forty in a row
;      2  across       +1, +1, +1 - and why the strip fills up solid
;      3  down         +10 on the toy screen, +320 on the real one
;      4  the real one lines by coordinates, a filled box, a window
;
;  THE ONE FACT THIS LESSON HANDS OVER: memory is one-dimensional, the screen
;  is two-dimensional, and the only thing between them is where the line
;  folds. On the text screen it folds every 80 cells; in mode 13h, every 320
;  bytes. Everything else here follows from that.
;
;      offset = y * width + x
;
;  You have met that five times - in C in lesson 1, in assembly in lesson 3,
;  as two shifts in 5B, inside Plot in lesson 6. Here you see the numbers
;  themselves, written in the cells.
;
;  WHY A HORIZONTAL LINE IS NEARLY FREE: its bytes are NEIGHBOURS, so one
;  REP STOSB draws the whole run. A vertical line is the same pixels 320
;  bytes apart, so it costs a loop and an ADD every time. That is not taste,
;  it is the shape of the memory.
;
;  THE EXPLANATION IS IN TEXT MODE ON PURPOSE. B800 is the other
;  memory-mapped screen from lesson 1, and it is the one that can hold
;  legible numbers. So the lesson explains itself on one screen and draws on
;  the other, with the same arithmetic behind both.
;
;  Owlos - legacy software modernization - https://owlos.sk
; ============================================================================
format binary as 'com'
        org  100h

TEXT    = 0B800h                ; the text screen: 80x25, TWO bytes a cell
VGA     = 0A000h                ; the graphics screen: 320x200, one byte
W       = 320
H       = 200
ROW     = 160                   ; a text row is 160 BYTES, not 80 - see above

TOYW    = 5                     ; the toy screen: five across, four down.
TOYH    = 4                     ; Twenty bytes - and the strip below fits in ONE row.
CELLW   = 6                     ; how wide a cell is drawn, in characters
GX      = 25                    ; where the grid sits, in characters
GY      = 5
SX      = 0                     ; and where the strip sits
SY      = 15

NORM    = 07h                   ; grey on black
HEAD    = 0Fh                   ; white
LIT     = 4Eh                   ; yellow on red: the byte being written now

        jmp  Boot               ; over the tables and routines, to the boot

; ---- what the frames say ---------------------------------------------------
t_head  db 'MEMORY IS ONE LINE.  THE SCREEN IS NOT.',0
t_toy   db 'A toy screen: five across, four down. Every cell is ONE byte, and',0
t_toy2  db 'the number in it is where that byte lives in memory.',0
t_strip db 'The same twenty bytes as the machine really holds them - ONE row:',0
t_fold  db 'The picture folds every 5 bytes. A real screen folds every 320.  ',0
t_acr   db 'ACROSS: the offset goes up by ONE, and the bytes are NEIGHBOURS. ',0
t_acr2  db 'Neighbours are what REP STOSB writes - one instruction, whole line',0
t_dwn   db 'DOWN: the offset goes up by FIVE - by 320 on the real screen.   ',0
t_dwn2  db 'Never neighbours. So a vertical line costs a loop and an ADD.     ',0
t_form  db 'offset = y * width + x',0
t_key   db '- any key -',0

; ---- state -----------------------------------------------------------------
tx      dw 0                    ; which cell of the toy screen we are at
ty      dw 0
num     dw 0                    ; and what number is written in it
lx      dw 0                    ; the real thing: a line by coordinates
ly      dw 0
llen    dw 0
col     db 15

include 'DRAW7.INC'

; ---- AX = the offset of cell (tx,ty) on the toy screen ---------------------
;  Two lines, and they are the lesson: a row is TOYW bytes long, so getting
;  to row y costs y of them, and then x more.
;  In C:   int toy_ofs(void) { return ty * TOYW + tx; }
ToyOfs: mov  ax, [ty]           ; AX = ty
        mov  bx, TOYW           ; BX = 5, the width
        mul  bx                 ; AX = ty * 5: y * width ...
        add  ax, [tx]           ; AX = ty * 5 + tx: ... + x
        ret                     ; return AX

; ---- one cell of the grid, in [attr] ---------------------------------------
;  In C:
;
;      void cell_draw(void)
;      {
;          num = toy_ofs();
;          gotoxy(GX + tx * CELLW, GY + ty);
;          putc(' ');  put_num(num);  putc(' ');
;      }
CellDraw:
        call ToyOfs             ; AX = toy_ofs()
        mov  [num], ax          ; num = AX
        mov  ax, [ty]           ; AX = ty
        add  ax, GY             ; AX = ty + GY: which text row this cell is drawn on
        mov  bx, ROW            ; BX = 160 bytes a row
        mul  bx                 ; AX = (ty + GY) * 160
        mov  di, ax             ; DI = the row start
        mov  ax, [tx]           ; AX = tx
        mov  bx, CELLW          ; BX = 6 characters a cell
        mul  bx                 ; AX = tx * 6: and which column
        add  ax, GX             ; AX = tx * 6 + GX
        add  ax, ax             ; AX *= 2: doubled, because a cell is two bytes
        add  di, ax             ; DI += the column
        mov  al, ' '            ; AL = ' '
        call PutC               ; putc(' ')
        mov  ax, [num]          ; AX = num
        call PutN               ; put_num(num)
        mov  al, ' '            ; AL = ' '
        call PutC               ; putc(' ')
        ret                     ; return

; ---- the same byte in the strip, in [attr] ---------------------------------
;  The strip is those twenty numbers laid end to end, in ONE text row, with
;  no folding anywhere at all - which is what the memory actually is. The
;  grid above and the strip below hold the same bytes; only the grid folds.
;  In C:
;
;      void strip_draw(void)
;      {
;          num = toy_ofs();
;          gotoxy(SX + num * 4, SY);            /* ONE row: no folding anywhere */
;          putc(' ');  put_num(num);  putc(' ');
;      }
StripDraw:
        call ToyOfs             ; AX = toy_ofs()
        mov  [num], ax          ; num = AX
        mov  bx, 4              ; BX = 4 characters to a number...
        mul  bx                 ; AX = num * 4
        add  ax, SX             ; AX = num * 4 + SX
        add  ax, ax             ; AX *= 2: ...and two bytes to a character
        add  ax, SY*ROW         ; AX += row SY: and the whole strip is ONE row
        mov  di, ax             ; DI = the cell
        mov  al, ' '            ; AL = ' '
        call PutC               ; putc(' ')
        mov  ax, [num]          ; AX = num
        call PutN               ; put_num(num)
        mov  al, ' '            ; AL = ' '
        call PutC               ; putc(' ')
        ret                     ; return

; ---- the whole toy screen, as a grid and as a strip ------------------------
;  In C:   for (ty = 0; ty < TOYH; ty++) for (tx = 0; tx < TOYW; tx++) { cell_draw(); strip_draw(); }
Grid:   mov  word [ty], 0       ; ty = 0
.row:   mov  word [tx], 0       ; tx = 0
.cell:  call CellDraw           ; cell_draw()
        call StripDraw          ; strip_draw()
        inc  word [tx]          ; tx++
        mov  ax, [tx]           ; AX = tx
        cmp  ax, TOYW           ; tx < TOYW ?
        jl   .cell              ;   yes: next cell
        inc  word [ty]          ; ty++
        mov  ax, [ty]           ; AX = ty
        cmp  ax, TOYH           ; ty < TOYH ?
        jl   .row               ;   yes: next row
        ret                     ; return

; ---- light one byte up, in the grid AND in the strip -----------------------
;  The same byte, in both pictures, at the same moment. That is the whole
;  point of having two pictures.
;  In C:   attr = LIT;  cell_draw();  strip_draw();  attr = NORM;
Light:  mov  byte [attr], LIT   ; attr = yellow on red
        call CellDraw           ; cell_draw()
        call StripDraw          ; strip_draw()
        mov  byte [attr], NORM  ; attr = NORM
        ret                     ; return

; ---- the hint at the bottom ------------------------------------------------
;  In C:   attr = 8;  puts_at(23, 34, "- any key -");  attr = NORM;
Bottom: mov  si, t_key          ; SI = the string
        mov  di, 23*ROW + 34*2  ; DI = row 23, column 34
        mov  byte [attr], 08h   ; attr = 8, dark grey
        call PutS               ; puts()
        mov  byte [attr], NORM  ; attr = NORM
        ret                     ; return

;  In C:
;
;      int main(void)
;      {
;          set_mode(3); cursor_off();
;          /* 1 */ tclear(); puts_at(...); grid(); puts_at(...); bottom(); key();
;          /* 2 */ puts_at(...); for (ty = 1, tx = 0; tx < TOYW; tx++) { light(); hold(); } key();
;          /* 3 */ tclear(); puts_at(...); grid(); ...; for (tx = 2, ty = 0; ty < TOYH; ty++) { light(); hold(); } key();
;          /* 4 */ set_mode(0x13); gclear(); hline(); vline(); vline(); box(); frame(); key();
;          set_mode(3); exit(0);
;      }
Boot:   cld                     ; string ops count UP: DI counts up in every STOS
        mov  ax, 0003h          ; AX = 3: the text screen, 80x25
        int  10h                ; set_mode(3)
        call TextOff            ; cursor_off()
        mov  ax, TEXT           ; AX = B800h
        mov  es, ax             ; ES = the text screen, for frames 1-3

; ---- 1. the fold -----------------------------------------------------------
F1:     call TClear
        mov  byte [attr], HEAD  ; attr = HEAD
        mov  si, t_head         ; SI = t_head
        mov  di, 0*ROW + 20*2   ; DI = row 0, column 20
        call PutS               ; puts()
        mov  byte [attr], NORM  ; attr = NORM
        mov  si, t_toy          ; SI = t_toy
        mov  di, 2*ROW + 7*2    ; DI = row 2, column 7
        call PutS               ; puts()
        mov  si, t_toy2         ; SI = t_toy2
        mov  di, 3*ROW + 7*2    ; DI = row 3, column 7
        call PutS               ; puts()
        call Grid               ; grid(): the toy screen, twice
        mov  si, t_strip        ; SI = t_strip
        mov  di, 13*ROW + 7*2   ; DI = row 13, column 7
        call PutS               ; puts()
        mov  byte [attr], HEAD  ; attr = HEAD
        mov  si, t_fold         ; SI = t_fold
        mov  di, 19*ROW + 7*2   ; DI = row 19, column 7
        call PutS               ; puts()
        mov  si, t_form         ; SI = t_form
        mov  di, 21*ROW + 28*2  ; DI = row 21, column 28
        call PutS               ; puts()
        mov  byte [attr], NORM  ; attr = NORM
        call Bottom             ; bottom(): "- any key -"
        call Key                ; key()

; ---- 2. across: the bytes are neighbours -----------------------------------
F2:     mov  byte [attr], HEAD
        mov  si, t_acr          ; SI = t_acr
        mov  di, 19*ROW + 7*2   ; DI = row 19, column 7
        call PutS               ; puts()
        mov  byte [attr], NORM  ; attr = NORM
        mov  si, t_acr2         ; SI = t_acr2
        mov  di, 20*ROW + 7*2   ; DI = row 20, column 7
        call PutS               ; puts()
        mov  word [ty], 1       ; ty = 1: the whole second row of the toy screen
        mov  word [tx], 0       ; tx = 0
.step:  call Light              ; light(): one byte at a time, so the +1 can be seen
        call Hold               ; hold()
        inc  word [tx]          ; tx++
        mov  ax, [tx]           ; AX = tx
        cmp  ax, TOYW           ; tx < TOYW ?
        jl   .step              ;   yes: the next byte
        call Key                ; key()

; ---- 3. down: never neighbours ---------------------------------------------
F3:     call TClear
        mov  byte [attr], HEAD  ; attr = HEAD
        mov  si, t_head         ; SI = t_head
        mov  di, 0*ROW + 20*2   ; DI = row 0, column 20
        call PutS               ; puts()
        mov  byte [attr], NORM  ; attr = NORM
        call Grid               ; grid(): the toy screen, twice
        mov  byte [attr], HEAD  ; attr = HEAD
        mov  si, t_dwn          ; SI = t_dwn
        mov  di, 19*ROW + 7*2   ; DI = row 19, column 7
        call PutS               ; puts()
        mov  byte [attr], NORM  ; attr = NORM
        mov  si, t_dwn2         ; SI = t_dwn2
        mov  di, 20*ROW + 7*2   ; DI = row 20, column 7
        call PutS               ; puts()
        mov  byte [attr], HEAD  ; attr = HEAD
        mov  si, t_form         ; SI = t_form
        mov  di, 21*ROW + 28*2  ; DI = row 21, column 28
        call PutS               ; puts()
        mov  byte [attr], NORM  ; attr = NORM
        call Bottom             ; bottom(): "- any key -"
        mov  word [tx], 2       ; tx = 2: one column, all the way down
        mov  word [ty], 0       ; ty = 0
.step:  call Light              ; light()
        call Hold               ; hold()
        inc  word [ty]          ; ty++
        mov  ax, [ty]           ; AX = ty
        cmp  ax, TOYH           ; ty < TOYH ?
        jl   .step              ;   yes: the next byte, a row further on
        call Key                ; key()

; ---- 4. and now the real screen --------------------------------------------
;  The same two rules on 320 bytes to a row. A filled box is a horizontal
;  line done sixty times; a window is a box with four lines round it - which
;  is every frame you have ever seen on a DOS screen.
F4:     mov  ax, 0013h          ; AX = 13h: the graphics screen, 320x200
        int  10h                ; set_mode(0x13)
        mov  ax, VGA            ; AX = A000h
        mov  es, ax             ; ES = the graphics screen
        call GClear             ; gclear()

        mov  word [lx], 20      ; a horizontal line, by coordinates
        mov  word [ly], 20      ; ly = 20
        mov  word [llen], 280   ; llen = 280
        mov  byte [col], 15     ; col = 15
        call HLine              ; hline(lx, ly, llen, col)

        mov  word [lx], 20      ; and two vertical ones - the same pixels,
        mov  word [ly], 30      ;  and not the same price
        mov  word [llen], 150   ; llen = 150
        mov  byte [col], 14     ; col = 14
        call VLine              ; vline(lx, ly, llen, col)
        mov  word [lx], 299     ; lx = 299
        mov  word [ly], 30      ; ly = 30
        mov  word [llen], 150   ; llen = 150
        call VLine              ; vline(lx, ly, llen, col)

        mov  word [lx], 60      ; a filled box: one horizontal line, sixty
        mov  word [ly], 70      ;  times over
        mov  word [llen], 200   ; llen = 200
        mov  byte [col], 1      ; col = 1
        mov  cx, 60             ; CX = 60 rows
        call Box                ; box(): CX rows of hline

        mov  word [lx], 60      ; and the window round it
        mov  word [ly], 70      ; ly = 70
        mov  word [llen], 200   ; llen = 200
        mov  byte [col], 15     ; col = 15
        mov  cx, 60             ; CX = 60 rows
        call Frame              ; frame(): four lines round a box
        call Key                ; key()

Bye:    mov  ax, 0003h          ; AX = 3: back to text, 80x25
        int  10h                ; set_mode(3)
        mov  ax, 4C00h          ; AH = 4Ch exit, AL = 0 the code
        int  21h                ; exit(0): hand the machine back to DOS
