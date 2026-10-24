; ============================================================================
;@ T_SNAKE    grid-step game: snake in a ring buffer, food on a free cell, speed-up, best score
;  T_SNAKE.ASM - KIT template: the smallest grid game. The world is cells,
;  not pixels; the snake moves one cell at a time, as often as its speed
;  says - the speed is 8.8 moves a tick, summed into an accumulator, so it
;  can be any fraction (a move every 4 ticks, then every 3.2, ...).
;
;  THE BODY IS A RING BUFFER: body[] holds the cells, [head] is where the
;  newest is; the tail is [len]-1 places behind. A move writes one word and
;  forgets one - no shifting of the whole snake. occ[] marks the cells the
;  snake covers, so "did it bite itself" is one byte read.
;  Food lands on a random FREE cell (MTH_RANGE, then the next free one).
;  Each food: longer, +1 score, faster. A wall or itself: GAME OVER, the
;  best score kept while the program runs; Enter plays again, Esc quits.
;
;  /AUTO: a pilot steers to the food (never into a wall or itself) at full
;  speed for ~2 s, then drives into the top wall; checks food, growth,
;  speed-up, the GAME OVER and the best score. Uses: K_MEM K_VGA K_KEYS
;  K_TIME K_MATH K_DRAW K_TEXT (DOS lines) K_SPK K_FONT, REC\R_TITLE.
;  Build: KIT\MAKEWIN T_SNAKE T_SNAKE
;  LETTERS: the title card is R_TITLE's TTLRUN over DRAWFLD (the words
;  t_name t_sub t_keys), before KEY_ON; /AUTO shows it 12 ticks. The score
;  line: FNT_HUD words + FNT_LSCORE digits, ringed; GAME OVER: FNT_LFIRE.
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

COLS    = 32                    ; the field: 32 x 19 cells of 10 pixels
ROWS    = 19
CELL    = 10
TOP     = 10                    ; the field starts below the score line
RING    = 1024                  ; body ring: a power of two (wrap by AND)
START   = 4                     ; the snake's first length
SPD0    = 64                    ; 8.8 moves a tick: 64 = one every 4 ticks
SPDUP   = 16                    ; faster by this much a food
SPDMAX  = 512                   ; two moves a tick at most
AUTOT   = 36                    ; /AUTO: ticks of steering before the crash

start:  call GETAUTO
        call MEM_INIT
        call VGA_ON
        jc   nomem
        call MTH_SEED
        call NEWGAME
        mov  word [ttl_name],t_name ; ---- the title card (KIT\REC\R_TITLE):
        mov  word [ttl_sub],t_sub ;  our words,
        mov  word [ttl_keys],t_keys
        mov  word [ttlbg],DRAWFLD ;  the field and the snake behind them
        xor  cx,cx              ; a person: until Enter or Esc
        cmp  byte [auto],0
        je   .ttl
        mov  cx,12              ; /AUTO: shown 12 ticks, then on
.ttl:   call TTLRUN             ; (the BIOS's keys: before KEY_ON)
        cmp  al,27
        je   quit               ; Esc on the title: back to DOS
        call KEY_ON
        call TIM_STEPS          ; start the step count

frame:  mov  al,SC_ESC
        call KEY_TAP
        jnz  quit
        cmp  word [aend],27     ; /AUTO: the GAME OVER card seen 1.5 s
        jae  quit
        call KEYDIR             ; arrows -> the next direction
        call TIM_STEPS          ; ticks gone by
        mov  cx,ax
        jcxz .draw
.step:  call STEP               ; one tick (keeps CX)
        loop .step
.draw:  call DRAW
        call VGA_SHOW
        jmp  frame

quit:   call SPK_STOP           ; every way out: sound, keys, screen
        call KEY_OFF
        call VGA_OFF
        cmp  byte [auto],0
        je   .bye
        call REPORT
.bye:   mov  ax,4C00h
        int  21h
nomem:  mov  dx,t_nomem
        mov  ah,9
        int  21h
        mov  ax,4C01h
        int  21h

; ---- NEWGAME: a short snake in the middle, heading right ----------------
NEWGAME:push ax
        push bx
        push cx
        push di
        push es
        push ds
        pop  es
        mov  di,occ             ; the field empty
        mov  cx,COLS*ROWS
        xor  al,al
        rep  stosb
        pop  es
        mov  word [head],START-1
        mov  word [len],START
        xor  bx,bx              ; BX = ring place * 2
        mov  di,9*COLS+8        ; the tail's cell: row 9, column 8
.b:     mov  [body+bx],di
        mov  byte [occ+di],1    ; (a cell index is a byte offset into occ)
        inc  di                 ; the next cell to the right
        add  bx,2               ; the next ring place
        cmp  bx,START*2
        jb   .b
        mov  byte [dir],1       ; right
        mov  byte [ndir],1
        mov  word [score],0
        mov  word [spd],SPD0
        cmp  byte [auto],0
        je   .s
        mov  word [spd],256     ; /AUTO: a move every tick from the start
.s:     mov  ax,[spd]
        mov  [spd0],ax          ; (a check: the speed-up)
        mov  word [acc],0
        mov  byte [over],0
        call FOOD
        pop  di
        pop  cx
        pop  bx
        pop  ax
        ret

; ---- STEP: one tick; the snake moves as many cells as the speed has added
STEP:   push ax
        push bx
        push cx
        push dx
        call SPK_TICK
        cmp  byte [over],0
        je   .live
        cmp  byte [auto],0
        je   .ov
        inc  word [aend]        ; /AUTO: ticks the card has shown
.ov:    mov  al,SC_ENTER        ; GAME OVER: Enter plays again
        call KEY_TAP
        jz   .r
        call NEWGAME
        jmp  .r
.live:  cmp  byte [auto],0
        je   .acc
        call PILOT              ; /AUTO picks [ndir]
.acc:   mov  ax,[spd]
        add  [acc],ax           ; 8.8: the moves owed grow by the speed
.mv:    cmp  word [acc],256     ; a whole move owed?
        jb   .r
        sub  word [acc],256     ; pay one
        call MOVE
        cmp  byte [over],0
        je   .mv
.r:     pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; ---- MOVE: one cell on in [ndir]; eat, grow, or die ----------------------
MOVE:   mov  al,[ndir]
        mov  [dir],al
        call NEXTCELL           ; BX = the cell ahead, CF = a wall
        jc   .dead
        mov  dx,bx              ; DX = the new head's cell
        cmp  dx,[food]
        je   .eat
        mov  bx,[head]          ; no food: the tail leaves its cell
        sub  bx,[len]
        inc  bx                 ; tail = head - len + 1
        and  bx,RING-1          ; round the ring
        shl  bx,1               ; a word a place
        mov  bx,[body+bx]
        mov  byte [occ+bx],0    ; the tail's cell is free (before the test:
        jmp  .go                ;  the head may follow into it)
.eat:   inc  word [len]         ; longer by one: the tail stays
        inc  word [score]
        inc  word [eaten]       ; a check
        add  word [spd],SPDUP   ; faster
        cmp  word [spd],SPDMAX
        jbe  .snd
        mov  word [spd],SPDMAX
.snd:   push ax
        mov  al,SPX_COIN
        call SPK_FX
        pop  ax
.go:    mov  bx,dx
        cmp  byte [occ+bx],0    ; bit itself?
        jne  .dead
        mov  byte [occ+bx],1
        mov  bx,[head]
        inc  bx                 ; the next ring place
        and  bx,RING-1          ; round the ring
        mov  [head],bx
        shl  bx,1               ; a word a place
        mov  [body+bx],dx       ; the new head
        cmp  dx,[food]
        jne  .r
        call FOOD               ; it was eaten: a new one
.r:     ret
.dead:  mov  byte [over],1
        mov  al,SPX_OVER
        call SPK_FX
        mov  ax,[score]
        cmp  ax,[best]
        jbe  .r
        mov  [best],ax          ; the best score, kept in memory
        ret

; NEXTCELL: BX = the cell one step in direction AL from the head; CF = wall
NEXTCELL:
        push ax
        push dx
        mov  bx,[head]
        shl  bx,1               ; a word a place
        mov  bx,[body+bx]       ; BX = the head's cell
        mov  dx,bx
        and  dx,COLS-1          ; DX = its column (COLS is 32: a mask)
        cmp  al,0
        je   .up
        cmp  al,2
        je   .dn
        cmp  al,3
        je   .lf
        cmp  dx,COLS-1          ; right
        je   .wall
        inc  bx                 ; one column right
        jmp  .ok
.lf:    or   dx,dx
        jz   .wall
        dec  bx                 ; one column left
        jmp  .ok
.up:    cmp  bx,COLS
        jb   .wall              ; the top row
        sub  bx,COLS            ; a row up
        jmp  .ok
.dn:    add  bx,COLS            ; a row down
        cmp  bx,COLS*ROWS
        jae  .wall              ; past the bottom row
.ok:    clc
        jmp  .r
.wall:  stc
.r:     pop  dx
        pop  ax
        ret

; ---- FOOD: on a random free cell (a random start, then the next free) ----
FOOD:   push ax
        push bx
        push cx
        mov  ax,COLS*ROWS
        call MTH_RANGE          ; AX = 0..607
        mov  bx,ax
        mov  cx,COLS*ROWS       ; at most every cell once
.f:     cmp  byte [occ+bx],0
        je   .ok
        inc  bx                 ; taken: the next cell
        cmp  bx,COLS*ROWS
        jb   .n
        xor  bx,bx              ; round to the first
.n:     loop .f
.ok:    mov  [food],bx          ; (a full field keeps the last tried)
        pop  cx
        pop  bx
        pop  ax
        ret

; ---- KEYDIR: an arrow pressed -> [ndir], never straight back -------------
KEYDIR: mov  si,dirkeys
        xor  dl,dl              ; DL = direction 0..3
.k:     lodsb
        call KEY_TAP
        jz   .n
        mov  al,[dir]
        xor  al,2               ; the reverse of now (0<->2, 1<->3)
        cmp  al,dl
        je   .n
        mov  [ndir],dl
.n:     inc  dl                 ; the next direction
        cmp  dl,4
        jb   .k
        ret
dirkeys db SC_UP, SC_RT, SC_DN, SC_LF

; ---- PILOT (/AUTO): toward the food on a safe cell; later, into the wall -
PILOT:  inc  word [aplay]
        cmp  word [aplay],AUTOT
        jb   .steer
        mov  byte [ndir],0      ; time's up: straight up into the wall
        ret
.steer: mov  ax,[food]          ; the wish: the food's side, across first
        and  ax,COLS-1          ; food column
        mov  bx,[head]
        shl  bx,1               ; a word a place
        mov  bx,[body+bx]
        mov  cx,bx
        and  cx,COLS-1          ; head column
        mov  dl,1               ; right?
        cmp  ax,cx
        ja   .try
        mov  dl,3               ; left?
        jb   .try
        mov  dl,2               ; same column: down or up
        cmp  [food],bx
        ja   .try
        mov  dl,0
.try:   mov  cx,4               ; the wish, then the other three in turn
.t:     mov  al,dl
        mov  ah,[dir]
        xor  ah,2               ; never straight back
        cmp  al,ah
        je   .nx
        call NEXTCELL
        jc   .nx                ; a wall
        cmp  byte [occ+bx],0
        jne  .nx                ; its own body
        mov  [ndir],dl
        ret
.nx:    inc  dl                 ; the next direction round
        and  dl,3
        loop .t
        ret                     ; boxed in: whatever comes

; ---- DRAW: the field, the score line over it, GAME OVER -------------------
DRAW:   call DRAWFLD
        push es
        mov  es,[vga_buf]
        mov  byte [fnt_col],15  ; the words: K_FONT's fast 4x6, ringed
        mov  byte [fnt_rc],0
        mov  si,t_score
        mov  bx,4
        mov  dx,3
        call FNT_HUD            ; BX = past the word
        push bx
        mov  si,t_best
        mov  bx,232
        call FNT_HUD
        mov  al,FNT_LSCORE      ; the numbers: bold digits, ringed
        call FNT_LOOK
        mov  ax,[score]
        mov  cl,3               ; 007
        pop  bx
        add  bx,4               ; a gap after SCORE
        mov  dx,1               ; 7 high: the foot on the words' foot
        call FNT_NUMZ
        mov  byte [fnt_col],15  ; the best in white
        mov  ax,[best]
        mov  bx,256
        call FNT_NUMZ
        cmp  byte [over],0
        je   .x
        mov  al,FNT_LFIRE       ; GAME OVER: 8x16 x2, the fire ramp,
        call FNT_LOOK           ;  ringed and shadowed
        mov  si,t_over
        mov  bx,160
        mov  dx,70
        call FNT_CENTER
        mov  al,FNT_LMENU       ; what now: 8x16, ringed
        call FNT_LOOK
        mov  byte [fnt_style],FNT_RINGSH
        mov  si,t_again
        mov  bx,160
        mov  dx,112
        call FNT_CENTER
.x:     pop  es
        ret

; ---- DRAWFLD: the field, the food, the snake (the title's picture too) ---
DRAWFLD:push es
        mov  es,[vga_buf]
        xor  al,al
        call VGA_CLS
        mov  byte [drw_col],8   ; the field's edge
        mov  ax,0
        mov  bx,TOP-1
        mov  cx,COLS*CELL
        mov  dx,ROWS*CELL+2
        call DRW_FRAME
        mov  bx,[food]          ; the food: a red disc
        call CELLXY
        add  ax,CELL/2          ; its centre
        add  bx,CELL/2
        mov  cx,4
        mov  byte [drw_col],12
        call DRW_DISC
        mov  si,[len]           ; the body, tail to head
        mov  di,[head]
        sub  di,si
        inc  di                 ; DI = the tail's ring place
.b:     and  di,RING-1          ; round the ring
        mov  bx,di
        shl  bx,1               ; a word a place
        mov  bx,[body+bx]
        call CELLXY
        mov  byte [drw_col],2   ; green body...
        cmp  si,1
        jne  .c
        mov  byte [drw_col],14  ; ...yellow head
.c:     mov  cx,CELL-1
        mov  dx,CELL-1
        call DRW_RECT
        inc  di                 ; the next place toward the head
        dec  si                 ; one fewer to draw
        jnz  .b
        pop  es
        ret
; CELLXY: cell BX -> AX = its left pixel, BX = its top pixel
CELLXY: push cx
        mov  ax,bx
        and  ax,COLS-1          ; column
        mov  cl,5
        shr  bx,cl              ; row = cell / 32
        mov  cx,ax
        shl  ax,1               ; col * 2
        shl  ax,1               ; col * 4
        add  ax,cx              ; col * 5
        shl  ax,1               ; col * 10 = x
        mov  cx,bx
        shl  bx,1               ; row * 2
        shl  bx,1               ; row * 4
        add  bx,cx              ; row * 5
        shl  bx,1               ; row * 10
        add  bx,TOP             ; y below the score line
        pop  cx
        ret

; ---- REPORT (/AUTO) -------------------------------------------------------
REPORT: mov  si,c_eat
        cmp  word [eaten],0     ; food eaten
        call PF
        mov  si,c_grow
        xor  dl,dl              ; DL = 0 fail, 1 pass
        mov  ax,[len]
        sub  ax,START           ; AX = how much it grew
        cmp  ax,[eaten]         ; as much as it ate?
        jne  .g
        mov  dl,al              ; (eaten > 0 was checked above)
.g:     or   dl,dl
        call PF
        mov  si,c_fast
        mov  ax,[spd]
        cmp  ax,[spd0]          ; faster than it began
        call PF
        mov  si,c_over
        xor  dl,dl
        mov  ax,[best]
        cmp  byte [over],0      ; GAME OVER reached...
        je   .o
        cmp  ax,[score]         ; ...and the best is this score...
        jne  .o
        mov  dl,al              ; ...which is above 0 (NZ = pass)
.o:     or   dl,dl
        call PF
        mov  si,t_len
        call TXT_DOSZ
        mov  ax,[len]
        call TXT_DOSNUM
        call TXT_DOSCR
        ret
; PF: PASS if the last compare said "not equal", else FAIL; SI = the words
PF:     mov  dx,t_pass
        jne  .s
        mov  dx,t_fail
.s:     call TXT_DOS
        call TXT_DOSZ
        call TXT_DOSCR
        ret

; ---- GETAUTO: [auto] = 1 if the command line holds /AUTO -----------------
GETAUTO:mov  si,81h
        xor  ch,ch
        mov  cl,[80h]           ; the command line's length
.s:     jcxz .no
        lodsb
        dec  cx                 ; one character read
        cmp  al,'/'
        jne  .s
        cmp  cx,4
        jb   .no
        mov  ax,[si]
        and  ax,0DFDFh          ; upper case
        cmp  ax,'AU'
        jne  .s
        mov  ax,[si+2]
        and  ax,0DFDFh
        cmp  ax,'TO'
        jne  .s
        mov  byte [auto],1
.no:    ret

; ---- state ----------------------------------------------------------------
head    dw 0                    ; the head's ring place
len     dw 0                    ; cells long
dir     db 1                    ; 0 up 1 right 2 down 3 left
ndir    db 1                    ; the next move's direction
food    dw 0                    ; the food's cell (row*32 + column)
score   dw 0
best    dw 0                    ; the best this session
spd     dw 0                    ; 8.8 moves a tick
acc     dw 0                    ; moves owed, 8.8
over    db 0
auto    db 0
aplay   dw 0
aend    dw 0
eaten   dw 0
spd0    dw 0
t_score db 'SCORE',0
t_best  db 'BEST',0
t_over  db 'GAME OVER',0
t_again db 'Enter: again   Esc: quit',0
t_name  db 'Snake',0            ; the title card's words (R_TITLE TTLCARD)
t_sub   db 'eat, grow, go faster',0
t_keys  db 'Arrows',0,'steer',0 ; the key, what it does...
        db 'Esc',0,'quit',0
        db 0                    ; ...an empty key ends them
t_pass  db 'PASS T_SNAKE $'
t_fail  db 'FAIL T_SNAKE $'
c_eat   db 'the pilot ate food (a free cell found by MTH_RANGE)',0
c_grow  db 'the ring-buffer body grew by one a food',0
c_fast  db 'the speed went up with the food',0
c_over  db 'it crashed: GAME OVER, the best score kept',0
t_len   db '  length at the end ',0
t_nomem db 'Not enough memory for the screen buffer.',13,10,'$'
occ     db COLS*ROWS dup(0)     ; 1 = the snake is on this cell
body    dw RING dup(0)          ; the ring of cells

        include '..\..\KIT\LIB\K_MEM.INC'
        include '..\..\KIT\LIB\K_VGA.INC'
        include '..\..\KIT\LIB\K_KEYS.INC'
        include '..\..\KIT\LIB\K_TIME.INC'
        include '..\..\KIT\LIB\K_MATH.INC'
        include '..\..\KIT\LIB\K_DRAW.INC'
        include '..\..\KIT\LIB\K_TEXT.INC'
        include '..\..\KIT\LIB\K_SPK.INC'
        include '..\..\KIT\LIB\K_FONT.INC' ; the good letters (FNT_*)
        include '..\..\KIT\REC\R_TITLE.ASM' ; TTLRUN, the title card
