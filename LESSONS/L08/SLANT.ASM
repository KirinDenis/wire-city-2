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
;  In 1986 it was called self-modifying code, and it was how a line drawer
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

        jmp  Boot

; ============================================================================
;  The line - frame 5's whole point. From (p0x,p0y) to (p1x,p1y) in [col]:
;  ONE routine for every direction, because the two directions it must
;  remember are decided once and written into the two ADDs of the loop.
; ============================================================================
Line:
        mov  ax, [p1x]
        sub  ax, [p0x]          ; dx, signed...
        mov  bx, 1              ; ...and the step right that goes with it
        or   ax, ax
        jns  .dxp
        neg  ax                 ; NEG: nought minus the thing. The DISTANCE
        mov  bx, -1             ;  must be positive; its SIGN moves into the
.dxp:   mov  [adx], ax          ;  step instead
        mov  [stx], bx
        mov  ax, [p1y]
        sub  ax, [p0y]          ; dy, signed, the same way...
        mov  bx, W              ; ...but ITS step is a whole row
        or   ax, ax
        jns  .dyp
        neg  ax
        mov  bx, -W
.dyp:   mov  [ady], ax
        mov  [sty], bx

        ; ---- which distance is longer DRIVES the loop; the other one
        ; feeds the debt. Both answers are written into the code.
        mov  ax, [adx]
        cmp  ax, [ady]
        jb   .ymaj
        mov  [dmaj], ax         ; x-major: step right every pixel...
        mov  ax, [ady]
        mov  [dmin], ax
        mov  ax, [stx]
        mov  [.majs+2], ax       ; ...so the driving ADD gets +-1
        mov  ax, [sty]
        mov  [.mins+2], ax       ; ...and the debt ADD gets +-320
        jmp  .go
.ymaj:  mov  [dmin], ax         ; y-major: the roles swap, nothing else
        mov  ax, [ady]
        mov  [dmaj], ax
        mov  ax, [sty]
        mov  [.majs+2], ax
        mov  ax, [stx]
        mov  [.mins+2], ax
.go:    jmp  short .fl          ; THE RULE again: patch, then jump
.fl:
        mov  ax, [p0y]          ; where the line starts, lesson 7's formula
        mov  bx, W
        mul  bx                 ; y * 320 ...
        add  ax, [p0x]          ; ... + x
        mov  di, ax
        mov  bl, [col]
        mov  cx, [dmaj]
        inc  cx                 ; both ends belong to the line
        xor  dx, dx             ; DX = the debt, starting clean
.px:    mov  [es:di], bl
        add  dx, [dmin]         ; every step, the debt grows by the short
        cmp  dx, [dmaj]         ;  distance - reached the long one?
        jb   .nod
        sub  dx, [dmaj]         ; paid off...
.mins:  add  di, W              ; ...with one sideways step   (REWRITTEN)
.nod:
.majs:  add  di, W              ; the driving step, every pixel (REWRITTEN)
        loop .px
        ret

; ---- one spoke of the fan: draw, next colour, a beat -----------------------
FanOne: call Line
        inc  byte [col]         ; walk the palette as the fan walks round
        cmp  byte [col], 16
        jb   .c
        mov  byte [col], 1      ; never 0 - a black line draws nothing
.c:     call Hold
        ret

; ---- what the frames say ---------------------------------------------------
t_head  db 'THE PROGRAM THAT REWRITES ITSELF',0
t_c1    db 'An instruction is bytes. Here is ADD DI,320 - read out of THIS',0
t_c2    db 'program, by this program, while it runs:',0
t_c3    db 'It lives in the same memory as your data. So a program can also',0
t_c4    db 'WRITE its own instructions. Today that is called JIT.',0
t_c5    db 'In 1986 it was called self-modifying code.',0
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
SlopeIf:
.px:    mov  [es:di], bl
        cmp  byte [sdir], 0     ; the question...
        jnz  .up
        add  di, W+1            ; ...one answer: a row down, a pixel right
        jmp  .nx
.up:    add  di, 1-W            ; ...the other: a row up, a pixel right
.nx:    loop .px
        ret

; ---- the RIGHT cross: the question is asked ONCE ---------------------------
;  The answer is WRITTEN INTO THE ADD before the loop starts. What is left
;  inside the loop is a write, an add and the count - no questions.
SlopeJit:
        mov  ax, W+1            ; the same two answers...
        cmp  byte [sdir], 0
        jz   .wr
        mov  ax, 1-W
.wr:    mov  [.step+2], ax      ; ...but written into the instruction: code
                                ;  is bytes, and these two are its number
        jmp  short .fl          ; THE RULE: patch, then jump - the jump
.fl:                            ;  empties the prefetch queue (frame 3)
.px:    mov  [es:di], bl
.step:  add  di, W+1            ; 81 C7 lo hi - the number above is written
                                ;  over lo hi. 320 forces the WIDE form, so
                                ;  the slot is always two bytes
        loop .px
        ret

; ---- one toy cell at (tx,ty), a two-digit number in [attr] -----------------
;  Lesson 7's cell, one lesson on: the number in the cell is the offset,
;  offset = y * width + x.
Cell:   mov  ax, [ty]
        add  ax, GY
        mov  bx, ROW
        mul  bx                 ; which text row the cell is drawn on...
        mov  di, ax
        mov  ax, [tx]
        mov  bx, CELLW
        mul  bx
        add  ax, GX
        add  ax, ax             ; ...and which column, two bytes a character
        add  di, ax
        mov  al, ' '
        call PutC
        mov  ax, [ty]
        mov  bx, TOYW
        mul  bx                 ; the cell's own offset, written inside it
        add  ax, [tx]
        call PutN
        mov  al, ' '
        call PutC
        ret

; ---- the whole toy grid ----------------------------------------------------
Grid:   mov  word [ty], 0
.row:   mov  word [tx], 0
.cell:  call Cell
        inc  word [tx]
        mov  ax, [tx]
        cmp  ax, TOYW
        jl   .cell
        inc  word [ty]
        mov  ax, [ty]
        cmp  ax, TOYH
        jl   .row
        ret

; ---- the hint at the bottom ------------------------------------------------
Bottom: mov  si, t_key
        mov  di, 23*ROW + 34*2
        mov  byte [attr], 08h
        call PutS
        mov  byte [attr], NORM
        ret

; ---- a headline and a clean screen -----------------------------------------
Head:   call TClear
        mov  byte [attr], HEAD
        mov  si, t_head
        mov  di, 0*ROW + 24*2
        call PutS
        mov  byte [attr], NORM
        ret

Boot:   cld                     ; DI counts UP in every STOS
        mov  ax, 0003h          ; the text screen, 80x25
        int  10h
        call TextOff
        mov  ax, TEXT
        mov  es, ax             ; frames 1, 3 and 4 talk on the text screen

; ---- 1. code is bytes ------------------------------------------------------
;  The program reads ITS OWN instruction and prints it. SlopeJit's ADD is
;  ADD DI,321: the assembler wrote 81 C7 41 01, and here those bytes are.
F1:     call Head
        mov  si, t_c1
        mov  di, 3*ROW + 7*2
        call PutS
        mov  si, t_c2
        mov  di, 4*ROW + 7*2
        call PutS
        mov  si, SlopeJit.step  ; <- the address of a LIVE instruction
        mov  cx, 4              ;    four bytes: opcode, register, number
        mov  di, 7*ROW + 30*2
        mov  byte [attr], HEAD
.byte:  lodsb                   ; the byte of code, into AL like any data
        call PutB               ; ...printed as two hex digits (lesson 2)
        mov  al, ' '
        call PutC
        loop .byte
        mov  byte [attr], NORM
        mov  si, t_c3
        mov  di, 10*ROW + 7*2
        call PutS
        mov  si, t_c4
        mov  di, 11*ROW + 7*2
        call PutS
        mov  byte [attr], HEAD
        mov  si, t_c5
        mov  di, 13*ROW + 7*2
        call PutS
        mov  byte [attr], NORM
        mov  si, t_x1
        mov  di, 17*ROW + 7*2
        call PutS
        mov  si, t_x2
        mov  di, 18*ROW + 7*2
        call PutS
        mov  si, t_x3
        mov  di, 19*ROW + 7*2
        call PutS
        mov  si, t_x4
        mov  di, 20*ROW + 7*2
        call PutS
        call Bottom
        call Key

; ---- 2. the two crosses ----------------------------------------------------
;  Each cross is two diagonal runs. The left pair goes through SlopeIf -
;  480 questions; the right pair through SlopeJit - one question, then a
;  loop with nothing inside it but work. The pictures come out identical.
F2:     mov  ax, 0013h
        int  10h
        mov  ax, VGA
        mov  es, ax
        call GClear
        mov  bl, 14             ; the asking cross, in yellow
        mov  byte [sdir], 0
        mov  di, 40*W + 20      ; down-right from (20,40)...
        mov  cx, 120
        call SlopeIf
        call Hold
        mov  byte [sdir], 1
        mov  di, 159*W + 20     ; ...up-right from (20,159): an X
        mov  cx, 120
        call SlopeIf
        call Hold
        mov  bl, 10             ; the rewritten cross, in green
        mov  byte [sdir], 0
        mov  di, 40*W + 180
        mov  cx, 120
        call SlopeJit
        call Hold
        mov  byte [sdir], 1
        mov  di, 159*W + 180
        mov  cx, 120
        call SlopeJit
        call Key

; ---- 3. the trap -----------------------------------------------------------
F3:     mov  ax, 0003h
        int  10h
        call TextOff
        mov  ax, TEXT
        mov  es, ax
        call Head
        mov  byte [attr], HEAD
        mov  si, t_t1
        mov  di, 3*ROW + 7*2
        call PutS
        mov  byte [attr], NORM
        mov  si, t_t2
        mov  di, 4*ROW + 7*2
        call PutS
        mov  si, t_t3
        mov  di, 5*ROW + 7*2
        call PutS
        mov  byte [attr], HEAD
        mov  si, t_t4
        mov  di, 7*ROW + 7*2
        call PutS
        mov  byte [attr], NORM
        mov  si, t_t5
        mov  di, 10*ROW + 7*2
        call PutS
        mov  si, t_t6
        mov  di, 11*ROW + 7*2
        call PutS
        mov  si, t_t7
        mov  di, 12*ROW + 7*2
        call PutS
        mov  si, t_t8
        mov  di, 13*ROW + 7*2
        call PutS
        call Bottom
        call Key

; ---- 4. the debt, on the toy screen ----------------------------------------
;  The walk from (0,0) to (4,2), one cell a beat, the debt printed beside
;  it: 0, 2, 4-pays-down, 2, 4-pays-down, done. dx=4, dy=2 - two downs
;  spread as evenly as whole steps can be.
F4:     call Head
        mov  si, t_d1
        mov  di, 2*ROW + 7*2
        call PutS
        mov  si, t_d2
        mov  di, 3*ROW + 7*2
        call PutS
        mov  si, t_d3
        mov  di, 4*ROW + 7*2
        call PutS
        call Grid
        mov  si, t_debt
        mov  di, 13*ROW + 25*2
        call PutS
        call Bottom
        mov  word [tx], 0       ; the walk itself: x drives, the debt
        mov  word [ty], 0       ;  decides when y may follow
        xor  dx, dx             ; DX = the debt
.step:  mov  byte [attr], LIT
        call Cell               ; light the cell the line owns...
        mov  byte [attr], NORM
        push dx
        mov  ax, dx
        mov  di, 13*ROW + 31*2  ; ...and show the debt beside the grid
        mov  byte [attr], HEAD
        call PutN
        mov  byte [attr], NORM
        pop  dx
        call Hold
        call Hold               ; two beats: this frame is the slow one
        mov  ax, [tx]
        cmp  ax, TOYW-1
        jae  .done
        inc  word [tx]          ; the step right, every time...
        add  dx, 2              ; ...grows the debt by dy
        cmp  dx, 4              ; reached dx?
        jb   .step
        sub  dx, 4              ; paid off...
        inc  word [ty]          ; ...with the one step down
        jmp  .step
.done:  call Key

; ---- 5. the fan ------------------------------------------------------------
;  Everything at once: the debt from frame 4 inside the loop, the two
;  rewritten ADDs from frame 2 in front of it. One routine, every
;  direction on the screen, drawn as a fan from the centre.
F5:     call Head
        mov  si, t_f1
        mov  di, 9*ROW + 7*2
        call PutS
        mov  si, t_f2
        mov  di, 10*ROW + 7*2
        call PutS
        mov  si, t_f3
        mov  di, 11*ROW + 7*2
        call PutS
        call Bottom
        call Key
        mov  ax, 0013h
        int  10h
        mov  ax, VGA
        mov  es, ax
        call GClear
        mov  word [p0x], 160    ; every line starts at the centre
        mov  word [p0y], 100
        mov  word [p1y], 0      ; ---- along the top edge, left to right
        mov  word [p1x], 0
.top:   call FanOne
        add  word [p1x], 16
        cmp  word [p1x], W
        jl   .top
        mov  word [p1x], W-1    ; ---- down the right edge
        mov  word [p1y], 0
.rgt:   call FanOne
        add  word [p1y], 16
        cmp  word [p1y], H
        jl   .rgt
        mov  word [p1y], H-1    ; ---- along the bottom, right to left
        mov  word [p1x], W-1
.bot:   call FanOne
        sub  word [p1x], 16
        cmp  word [p1x], 0
        jge  .bot
        mov  word [p1x], 0      ; ---- and up the left edge, closing it
        mov  word [p1y], H-1
.lft:   call FanOne
        sub  word [p1y], 16
        cmp  word [p1y], 0
        jge  .lft
        call Key

Bye:    mov  ax, 0003h          ; back to text, 80x25
        int  10h
        mov  ax, 4C00h          ; and hand the machine back to DOS
        int  21h
