; ============================================================================
;@ T_BREAK    breakout skeleton: paddle, ball with 8.8 velocity, wall / brick / paddle bounces, lives
;  T_BREAK.ASM - KIT template: a paddle, a ball, a wall of bricks.
;  THE BALL moves in 8.8 fixed point on both axes: a whole-pixel word and
;  a 256ths byte each, a velocity word each (8.8 pixels a tick). Moving
;  is ADD on the fraction, ADC on the whole: speeds like 1.4 pixels a tick
;  are exact over time, not rounded every tick.
;  THE BOUNCES: x is moved first, then y - a brick met after the x move
;  turns vx round, after the y move vy, so the ball bounces off the side
;  it really hit. The paddle sends it back up, angled by WHERE it was hit
;  (the edge: steep sideways, the middle: straight up) - that is the
;  player's aim. Bricks are 32 x 8, so the brick under a pixel is found
;  by shifts: column = x / 32, row = (y - BRY) / 8.
;  Space launches the ball; the arrows move the paddle; a ball lost costs a
;  life; the wall cleared comes back faster. Esc quits.
;  /AUTO: the paddle follows the ball for ~4 s; checks bricks broken, the
;  score, paddle and wall bounces. Uses: K_MEM K_VGA K_KEYS K_TIME K_MATH
;  K_DRAW K_TEXT (DOS lines) K_SPR (SPR_HIT) K_SPK K_FONT, REC\R_TITLE.
;  Build: KIT\MAKEWIN T_BREAK T_BREAK
;  LETTERS: the title card is R_TITLE's TTLRUN over DRAWFLD (the words
;  t_name t_sub t_keys), before KEY_ON; /AUTO shows it 12 ticks. The score
;  line: FNT_HUD words + FNT_LSCORE digits, ringed; the hint 8x16 ringed.
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

BCOLS   = 10                    ; bricks: 10 x 5 of 32 x 8 pixels
BROWS   = 5
BRY     = 40                    ; the wall's top row
PADY    = 188                   ; the paddle: its row, 40 x 5
PADW    = 40
PADH    = 5
PADSP   = 5                     ; paddle pixels a tick
BALL    = 4                     ; the ball: 4 x 4
VY0     = 1024                  ; 8.8: 4 pixels a tick
LIVES   = 3
AUTOT   = 90                    ; /AUTO: ticks (5 s)

start:  call GETAUTO
        call MEM_INIT
        call VGA_ON
        jc   nomem
        mov  byte [lives],LIVES
        call WALL               ; all the bricks up
        call PARK               ; the ball on the paddle
        mov  word [ttl_name],t_name ; ---- the title card (KIT\REC\R_TITLE):
        mov  word [ttl_sub],t_sub ;  our words,
        mov  word [ttl_keys],t_keys
        mov  word [ttlbg],DRAWFLD ;  the wall and the paddle behind them
        xor  cx,cx              ; a person: until Enter or Esc
        cmp  byte [auto],0
        je   .ttl
        mov  cx,12              ; /AUTO: shown 12 ticks, then on
.ttl:   call TTLRUN             ; (the BIOS's keys: before KEY_ON)
        cmp  al,27
        je   quit               ; Esc on the title: back to DOS
        call KEY_ON
        call TIM_STEPS

frame:  mov  al,SC_ESC
        call KEY_TAP
        jnz  quit
        cmp  word [aplay],AUTOT
        jae  quit
        call TIM_STEPS
        mov  cx,ax
        jcxz .draw
.step:  call STEP               ; keeps CX
        loop .step
.draw:  call DRAW
        call VGA_SHOW
        jmp  frame

quit:   call SPK_STOP
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

; WALL: every brick back; PARK: the ball sits on the paddle until Space
WALL:   push cx
        push di
        push es
        push ds
        pop  es
        mov  di,bricks
        mov  cx,BCOLS*BROWS
        mov  al,1
        rep  stosb
        pop  es
        pop  di
        pop  cx
        mov  word [left],BCOLS*BROWS
        ret
PARK:   mov  byte [parked],1
        mov  byte [bxf],0
        mov  byte [byf],0
        mov  word [by],PADY-BALL
        ret

; ---- STEP: one tick. Keeps every register ---------------------------------
STEP:   push ax
        push bx
        push cx
        push dx
        push si
        push di
        call SPK_TICK
        cmp  byte [auto],0
        je   .pad
        call PILOT
.pad:   mov  al,SC_LF           ; the paddle
        call KEY_HELD
        jz   .p1
        sub  word [padx],PADSP  ; left
.p1:    mov  al,SC_RT
        call KEY_HELD
        jz   .p2
        add  word [padx],PADSP  ; right
.p2:    mov  ax,[padx]
        xor  bx,bx
        mov  cx,320-PADW
        call MTH_CLAMP          ; held on the screen
        mov  [padx],ax
        cmp  byte [parked],0
        je   .fly
        add  ax,PADW/2-BALL/2   ; parked: the ball rides the paddle's middle
        mov  [bx_],ax
        mov  al,SC_SPACE
        call KEY_HELD
        jz   .r
        mov  byte [parked],0    ; launched: up, toward the nearer wall
        mov  ax,[speed]
        neg  ax                 ; vy = -speed (up)
        mov  [vy],ax
        mov  ax,384             ; vx = 1.5 pixels a tick...
        cmp  word [padx],160-PADW/2
        jge  .lv
        neg  ax                 ; ...to the left from the left half
.lv:    mov  [vx],ax
        jmp  .r
.fly:   mov  si,bx_             ; ---- across
        mov  ax,[vx]
        call MOVE88
        mov  ax,[bx_]
        cmp  ax,0               ; the left wall?
        jge  .x1
        mov  word [bx_],0
        jmp  .xw
.x1:    cmp  ax,320-BALL        ; the right wall?
        jle  .x2
        mov  word [bx_],320-BALL
.xw:    neg  word [vx]          ; bounce: vx = -vx
        inc  word [walls]
        jmp  .y
.x2:    call BRICKHIT           ; a brick at the new place?
        jnc  .y
        neg  word [vx]          ; hit from the side: vx = -vx
.y:     mov  si,by              ; ---- down
        mov  ax,[vy]
        call MOVE88
        cmp  word [by],0        ; the top wall?
        jge  .y1
        mov  word [by],0
        neg  word [vy]          ; bounce
        inc  word [walls]
        jmp  .pd
.y1:    call BRICKHIT
        jnc  .pd
        neg  word [vy]          ; hit from above or below: vy = -vy
.pd:    cmp  word [vy],0        ; ---- the paddle, only while falling
        jle  .lost
        mov  ax,[bx_]
        mov  [boxa],ax
        mov  ax,[by]
        mov  [boxa+2],ax
        mov  ax,[padx]
        mov  [boxb],ax
        mov  si,boxa
        mov  di,boxb
        call SPR_HIT            ; CF = 1 they overlap
        jnc  .lost
        mov  ax,[speed]
        neg  ax                 ; up again at the wall's speed
        mov  [vy],ax
        mov  ax,[bx_]
        add  ax,BALL/2          ; the ball's middle...
        sub  ax,[padx]
        sub  ax,PADW/2          ; ...minus the paddle's: -22..22
        mov  cl,5
        shl  ax,cl              ; * 32: vx up to 2.75 pixels a tick, 8.8
        mov  [vx],ax
        inc  word [pads]
        mov  al,SPX_BLIP
        call SPK_FX
.lost:  cmp  word [by],200      ; ---- past the bottom: a ball lost
        jl   .r
        call PARK
        mov  al,SPX_HIT
        call SPK_FX
        dec  byte [lives]       ; one fewer
        jnz  .r
        mov  byte [lives],LIVES ; none left: a new game
        mov  word [score],0
        call WALL
.r:     pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; MOVE88: the axis at SI (dw whole, then db fraction) moves by AX (8.8)
MOVE88: push ax
        push dx
        mov  dl,al              ; DL = the fraction of the step
        mov  al,ah
        cbw                     ; AX = its whole pixels, the sign kept
        add  [si+2],dl          ; fraction + fraction: CF a whole pixel
        adc  [si],ax            ; whole + whole + that carry
        pop  dx
        pop  ax
        ret

; BRICKHIT: CF = 1 if a corner of the ball is in a brick - that brick goes
BRICKHIT:
        mov  ax,[bx_]           ; the four corners in turn
        mov  bx,[by]
        call BRICKAT
        jc   .hit
        add  ax,BALL-1          ; top right
        call BRICKAT
        jc   .hit
        add  bx,BALL-1          ; bottom right
        call BRICKAT
        jc   .hit
        sub  ax,BALL-1          ; bottom left
        call BRICKAT
        jnc  .r
.hit:   mov  byte [bricks+si],0 ; gone
        add  word [score],10    ; 10 a brick
        inc  word [broken]
        mov  al,SPX_COIN
        call SPK_FX
        dec  word [left]        ; the wall cleared?
        jnz  .hc
        call WALL               ; again, faster
        add  word [speed],64    ; + 0.25 pixels a tick
.hc:    stc
.r:     ret
; BRICKAT: CF = 1 if pixel (AX,BX) is on a standing brick, SI = its index
BRICKAT:push ax
        push bx
        push cx
        sub  bx,BRY             ; rows from the wall's top
        jb   .no                ; above the wall
        cmp  bx,BROWS*8
        jae  .no                ; below it
        cmp  ax,320
        jae  .no                ; off the sides
        mov  cl,3
        shr  bx,cl              ; row = / 8
        mov  si,bx
        shl  si,1               ; row * 2
        shl  si,1               ; row * 4
        add  si,bx              ; row * 5
        shl  si,1               ; row * 10 = the row's first brick
        mov  cl,5
        shr  ax,cl              ; column = x / 32
        add  si,ax              ; SI = row * 10 + column
        cmp  byte [bricks+si],0
        je   .no
        stc
        jmp  .r
.no:    clc
.r:     pop  cx
        pop  bx
        pop  ax
        ret

; PILOT (/AUTO): left 1 s, Space, then the paddle's middle under the ball
PILOT:  inc  word [aplay]
        mov  byte [key_held+SC_LF],0
        mov  byte [key_held+SC_RT],0
        cmp  word [aplay],20    ; first the paddle to the left...
        jae  .go
        mov  byte [key_held+SC_LF],1
        ret
.go:    mov  byte [key_held+SC_SPACE],1 ; ...then launch, and follow
        mov  ax,[bx_]
        sub  ax,[padx]
        sub  ax,PADW/2-BALL/2-6 ; aim 6 pixels off-centre: an angled return
        cmp  ax,-3
        jge  .r1
        mov  byte [key_held+SC_LF],1
.r1:    cmp  ax,3
        jle  .r
        mov  byte [key_held+SC_RT],1
.r:     ret

; ---- DRAW: the field, the score line over it, the launch hint -------------
DRAW:   call DRAWFLD
        push es
        mov  es,[vga_buf]
        mov  byte [fnt_col],15  ; the words: K_FONT's fast 4x6, ringed
        mov  byte [fnt_rc],0
        mov  si,t_score
        mov  bx,4
        mov  dx,6
        call FNT_HUD            ; BX = past the word
        push bx
        mov  si,t_lives
        mov  bx,268
        call FNT_HUD
        mov  al,FNT_LSCORE      ; the numbers: bold digits, ringed
        call FNT_LOOK
        mov  ax,[score]
        mov  cl,4               ; 0120
        pop  bx
        add  bx,4               ; a gap after SCORE
        mov  dx,4               ; 7 high: the foot on the words' foot
        call FNT_NUMZ
        mov  byte [fnt_col],15  ; the balls left, white...
        cmp  byte [lives],1
        ja   .lc
        mov  byte [fnt_col],12  ; ...red on the last
.lc:    mov  al,[lives]
        xor  ah,ah
        mov  cl,1
        mov  bx,294
        call FNT_NUMZ
        cmp  byte [parked],0
        je   .x
        mov  al,FNT_LMENU       ; the hint: 8x16 yellow, ringed + shadow
        call FNT_LOOK
        mov  byte [fnt_style],FNT_RINGSH
        mov  byte [fnt_col],14
        mov  si,t_space
        mov  bx,160
        mov  dx,124
        call FNT_CENTER
.x:     pop  es
        ret

; ---- DRAWFLD: bricks, paddle, ball (the title's picture too) --------------
DRAWFLD:push es
        mov  es,[vga_buf]
        xor  al,al
        call VGA_CLS
        xor  si,si              ; SI = brick index
        mov  bx,BRY             ; BX = its row's y
        xor  di,di              ; DI = the row number
.row:   xor  ax,ax              ; AX = x
.br:    cmp  byte [bricks+si],0
        je   .nb
        mov  cl,[rowcol+di]
        mov  [drw_col],cl
        mov  cx,31              ; 31 x 7: a gap of one between bricks
        mov  dx,7
        call DRW_RECT
.nb:    inc  si                 ; the next brick
        add  ax,32              ; 32 pixels on
        cmp  ax,320
        jb   .br
        add  bx,8               ; the next row
        inc  di
        cmp  di,BROWS
        jb   .row
        mov  byte [drw_col],7   ; the paddle
        mov  ax,[padx]
        mov  bx,PADY
        mov  cx,PADW
        mov  dx,PADH
        call DRW_RECT
        mov  byte [drw_col],15  ; the ball
        mov  ax,[bx_]
        mov  bx,[by]
        mov  cx,BALL
        mov  dx,BALL
        call DRW_RECT
        pop  es
        ret

; ---- REPORT (/AUTO) -------------------------------------------------------
REPORT: mov  si,c_brick
        mov  ax,[broken]
        call PFA
        mov  si,c_score
        mov  ax,[score]
        call PFA
        mov  si,c_pad
        mov  ax,[pads]
        call PFA
        mov  si,c_wall
        mov  ax,[walls]
        call PFA
        ret
; PFA: PASS if AX is above 0, with the words at SI and the value
PFA:    mov  dx,t_pass
        or   ax,ax
        jnz  .s
        mov  dx,t_fail
.s:     call TXT_DOS
        call TXT_DOSZ
        mov  si,t_val
        call TXT_DOSZ
        call TXT_DOSNUM
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
bx_     dw 0                    ; the ball's x: whole pixels...
bxf     db 0,0                  ;  ...its 256ths (MOVE88 reads +2)
by      dw 0                    ; the ball's y
byf     db 0,0
vx      dw 0                    ; 8.8 pixels a tick
vy      dw 0
speed   dw VY0                  ; how fast it climbs, 8.8
padx    dw 160-PADW/2
parked  db 1
lives   db 0
score   dw 0
left    dw 0                    ; bricks standing
boxa    dw 0,0,BALL,BALL        ; SPR_HIT's boxes: the ball, the paddle
boxb    dw 0,PADY,PADW,PADH
rowcol  db 12,6,14,10,9         ; the rows' colours
auto    db 0
aplay   dw 0
broken  dw 0
pads    dw 0
walls   dw 0
t_score db 'SCORE',0
t_lives db 'BALLS',0
t_space db 'Space launches',0
t_name  db 'Breakout',0         ; the title card's words (R_TITLE TTLCARD)
t_sub   db 'aim by where it hits',0
t_keys  db 'Arrows',0,'paddle',0 ; the key, what it does...
        db 'Space',0,'launch',0
        db 'Esc',0,'quit',0
        db 0                    ; ...an empty key ends them
t_pass  db 'PASS T_BREAK $'
t_fail  db 'FAIL T_BREAK $'
t_val   db ': ',0
c_brick db 'bricks broken',0
c_score db 'score',0
c_pad   db 'paddle returns (angled by where it hit)',0
c_wall  db 'wall bounces',0
t_nomem db 'Not enough memory for the screen buffer.',13,10,'$'
bricks  db BCOLS*BROWS dup(0)   ; 1 = standing

        include '..\..\KIT\LIB\K_MEM.INC'
        include '..\..\KIT\LIB\K_VGA.INC'
        include '..\..\KIT\LIB\K_KEYS.INC'
        include '..\..\KIT\LIB\K_TIME.INC'
        include '..\..\KIT\LIB\K_MATH.INC'
        include '..\..\KIT\LIB\K_DRAW.INC'
        include '..\..\KIT\LIB\K_TEXT.INC'
        include '..\..\KIT\LIB\K_SPR.INC'
        include '..\..\KIT\LIB\K_SPK.INC'
        include '..\..\KIT\LIB\K_FONT.INC' ; the good letters (FNT_*)
        include '..\..\KIT\REC\R_TITLE.ASM' ; TTLRUN, the title card
