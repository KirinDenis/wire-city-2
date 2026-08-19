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

        jmp  Boot

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
ToyOfs: mov  ax, [ty]
        mov  bx, TOYW
        mul  bx                 ; y * width ...
        add  ax, [tx]           ; ... + x
        ret

; ---- one cell of the grid, in [attr] ---------------------------------------
CellDraw:
        call ToyOfs
        mov  [num], ax
        mov  ax, [ty]           ; which text row this cell is drawn on
        add  ax, GY
        mov  bx, ROW
        mul  bx
        mov  di, ax
        mov  ax, [tx]           ; and which column
        mov  bx, CELLW
        mul  bx
        add  ax, GX
        add  ax, ax             ; doubled, because a cell is two bytes
        add  di, ax
        mov  al, ' '
        call PutC
        mov  ax, [num]
        call PutN
        mov  al, ' '
        call PutC
        ret

; ---- the same byte in the strip, in [attr] ---------------------------------
;  The strip is those twenty numbers laid end to end, in ONE text row, with
;  no folding anywhere at all - which is what the memory actually is. The
;  grid above and the strip below hold the same bytes; only the grid folds.
StripDraw:
        call ToyOfs
        mov  [num], ax
        mov  bx, 4              ; four characters to a number...
        mul  bx
        add  ax, SX
        add  ax, ax             ; ...and two bytes to a character
        add  ax, SY*ROW         ; and the whole strip is ONE row
        mov  di, ax
        mov  al, ' '
        call PutC
        mov  ax, [num]
        call PutN
        mov  al, ' '
        call PutC
        ret

; ---- the whole toy screen, as a grid and as a strip ------------------------
Grid:   mov  word [ty], 0
.row:   mov  word [tx], 0
.cell:  call CellDraw
        call StripDraw
        inc  word [tx]
        mov  ax, [tx]
        cmp  ax, TOYW
        jl   .cell
        inc  word [ty]
        mov  ax, [ty]
        cmp  ax, TOYH
        jl   .row
        ret

; ---- light one byte up, in the grid AND in the strip -----------------------
;  The same byte, in both pictures, at the same moment. That is the whole
;  point of having two pictures.
Light:  mov  byte [attr], LIT
        call CellDraw
        call StripDraw
        mov  byte [attr], NORM
        ret

; ---- the hint at the bottom ------------------------------------------------
Bottom: mov  si, t_key
        mov  di, 23*ROW + 34*2
        mov  byte [attr], 08h
        call PutS
        mov  byte [attr], NORM
        ret

Boot:   cld                     ; DI counts UP in every STOS
        mov  ax, 0003h          ; the text screen, 80x25
        int  10h
        call TextOff
        mov  ax, TEXT
        mov  es, ax             ; ES points at the text screen for frames 1-3

; ---- 1. the fold -----------------------------------------------------------
F1:     call TClear
        mov  byte [attr], HEAD
        mov  si, t_head
        mov  di, 0*ROW + 20*2
        call PutS
        mov  byte [attr], NORM
        mov  si, t_toy
        mov  di, 2*ROW + 7*2
        call PutS
        mov  si, t_toy2
        mov  di, 3*ROW + 7*2
        call PutS
        call Grid
        mov  si, t_strip
        mov  di, 13*ROW + 7*2
        call PutS
        mov  byte [attr], HEAD
        mov  si, t_fold
        mov  di, 19*ROW + 7*2
        call PutS
        mov  si, t_form
        mov  di, 21*ROW + 28*2
        call PutS
        mov  byte [attr], NORM
        call Bottom
        call Key

; ---- 2. across: the bytes are neighbours -----------------------------------
F2:     mov  byte [attr], HEAD
        mov  si, t_acr
        mov  di, 19*ROW + 7*2
        call PutS
        mov  byte [attr], NORM
        mov  si, t_acr2
        mov  di, 20*ROW + 7*2
        call PutS
        mov  word [ty], 1       ; the whole second row of the toy screen
        mov  word [tx], 0
.step:  call Light              ; one byte at a time, so the +1 can be seen
        call Hold
        inc  word [tx]
        mov  ax, [tx]
        cmp  ax, TOYW
        jl   .step
        call Key

; ---- 3. down: never neighbours ---------------------------------------------
F3:     call TClear
        mov  byte [attr], HEAD
        mov  si, t_head
        mov  di, 0*ROW + 20*2
        call PutS
        mov  byte [attr], NORM
        call Grid
        mov  byte [attr], HEAD
        mov  si, t_dwn
        mov  di, 19*ROW + 7*2
        call PutS
        mov  byte [attr], NORM
        mov  si, t_dwn2
        mov  di, 20*ROW + 7*2
        call PutS
        mov  byte [attr], HEAD
        mov  si, t_form
        mov  di, 21*ROW + 28*2
        call PutS
        mov  byte [attr], NORM
        call Bottom
        mov  word [tx], 2       ; one column, all the way down
        mov  word [ty], 0
.step:  call Light
        call Hold
        inc  word [ty]
        mov  ax, [ty]
        cmp  ax, TOYH
        jl   .step
        call Key

; ---- 4. and now the real screen --------------------------------------------
;  The same two rules on 320 bytes to a row. A filled box is a horizontal
;  line done sixty times; a window is a box with four lines round it - which
;  is every frame you have ever seen on a DOS screen.
F4:     mov  ax, 0013h
        int  10h
        mov  ax, VGA
        mov  es, ax
        call GClear

        mov  word [lx], 20      ; a horizontal line, by coordinates
        mov  word [ly], 20
        mov  word [llen], 280
        mov  byte [col], 15
        call HLine

        mov  word [lx], 20      ; and two vertical ones - the same pixels,
        mov  word [ly], 30      ;  and not the same price
        mov  word [llen], 150
        mov  byte [col], 14
        call VLine
        mov  word [lx], 299
        mov  word [ly], 30
        mov  word [llen], 150
        call VLine

        mov  word [lx], 60      ; a filled box: one horizontal line, sixty
        mov  word [ly], 70      ;  times over
        mov  word [llen], 200
        mov  byte [col], 1
        mov  cx, 60
        call Box

        mov  word [lx], 60      ; and the window round it
        mov  word [ly], 70
        mov  word [llen], 200
        mov  byte [col], 15
        mov  cx, 60
        call Frame
        call Key

Bye:    mov  ax, 0003h          ; back to text, 80x25
        int  10h
        mov  ax, 4C00h          ; and hand the machine back to DOS
        int  21h
