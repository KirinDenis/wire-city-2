; ============================================================================
;@ T_PLAT     platformer skeleton: text-row tile map, 8.8 gravity and jump, tile collision, coins, scrolling camera
;  T_PLAT.ASM - KIT template: a side-on platform game to grow from.
;  THE MAP is text in the source, one letter a 16x16 tile: '.' air, '#'
;  brick, '=' grass, 'o' a coin. It is 40 tiles wide - twice the screen -
;  so the camera follows the player across (camx, clamped to the map).
;  THE TILES are text art compiled once by SPR_COMPILE and drawn by
;  SPR_DRAW, which clips the half tiles at the screen's edges.
;
;  THE PHYSICS, one step a BIOS tick (TIM_STEPS):
;    x: whole pixels, SPEED a tick on the arrows; a wall pushes it back to
;       the tile's edge.
;    y: 8.8 fixed point - [py] whole pixels, [pyf] 256ths - with [vy] in
;       8.8 pixels a tick. Gravity adds GRAV to vy every tick, vy adds to
;       y; the fraction carries (ADD then ADC), so slow speeds still move.
;    falling onto a solid tile: stand on it (vy = 0, on the ground);
;    rising into one: bump the head (vy = 0, falls back).
;  Up or Space jumps from the ground. A coin under the player's middle is
;  taken (the map letter becomes air). Falling off the bottom: back to
;  the start. Esc quits.
;  /AUTO: holds Right, jumps at walls and gaps; checks the walk, the camera,
;  a coin, a jump and its landing, a head bump. Uses: K_MEM K_VGA K_KEYS
;  K_TIME K_MATH K_TEXT (DOS lines) K_SPR K_SPK K_FONT, REC\R_TITLE.
;  Build: KIT\MAKEWIN T_PLAT T_PLAT
;  LETTERS: the title card is R_TITLE's TTLRUN over DRAWLVL (the words:
;  t_name t_sub t_keys), before KEY_ON - it reads the BIOS's keys; /AUTO
;  shows it 12 ticks. The score: FNT_HUD's ringed 4x6 word and FNT_LSCORE's
;  bold ringed digits - they read on the sky and on the bricks alike.
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

MAPW    = 40                    ; tiles across
MAPH    = 12                    ; tiles down (12 * 16 = 192 rows)
TILE    = 16
MAPY    = 8                     ; the map's top on the screen (score above)
PW      = 10                    ; the player: 10 x 14
PH      = 14
SPEED   = 3                     ; pixels a tick across
GRAV    = 96                    ; 8.8: 0.375 pixels a tick, every tick
JUMPV   = -1408                 ; 8.8: -5.5 pixels a tick, up
VMAX    = 1792                  ; 8.8: 7 pixels a tick, the fastest fall (< a tile)
STARTX  = 40
STARTY  = 100
AUTOT   = 70                    ; /AUTO: ticks of play (3.8 s)

start:  call GETAUTO
        call MEM_INIT
        call VGA_ON
        jc   nomem
        mov  si,brick_t         ; the tiles and the player, compiled once
        mov  di,brick_c
        call SPR_COMPILE
        mov  si,grass_t
        mov  di,grass_c
        call SPR_COMPILE
        mov  si,coin_t
        mov  di,coin_c
        call SPR_COMPILE
        mov  si,man_t
        mov  di,man_c
        call SPR_COMPILE
        call RESPAWN
        mov  word [ttl_name],t_name ; ---- the title card (KIT\REC\R_TITLE):
        mov  word [ttl_sub],t_sub ;  our words,
        mov  word [ttl_keys],t_keys
        mov  word [ttlbg],DRAWLVL ;  the level standing behind them
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
        cmp  word [aplay],AUTOT ; /AUTO: long enough (0 forever without)
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

RESPAWN:mov  word [px],STARTX
        mov  word [py],STARTY
        mov  byte [pyf],0
        mov  word [vy],0
        ret

; ---- STEP: one tick of the player's physics. Keeps every register -------
STEP:   push ax
        push bx
        push cx
        push dx
        push di
        call SPK_TICK
        cmp  byte [auto],0
        je   .x
        call PILOT              ; /AUTO: the keys
.x:     xor  cx,cx              ; ---- across: CX = this tick's step
        mov  al,SC_LF
        call KEY_HELD
        jz   .x1
        sub  cx,SPEED           ; left
        mov  byte [face],1
.x1:    mov  al,SC_RT
        call KEY_HELD
        jz   .x2
        add  cx,SPEED           ; right
        mov  byte [face],0
.x2:    mov  ax,[px]
        add  ax,cx              ; AX = the x it wants
        mov  bx,[py]
        or   cx,cx
        jz   .y
        js   .left
        add  ax,PW-1            ; moving right: test the right edge
        call SOLID2             ; at the top and bottom of the player
        jnc  .xok
        mov  cl,4
        sar  ax,cl              ; the wall's tile column...
        shl  ax,cl              ; ...its left pixel
        dec  ax                 ; the last free pixel before it
.xok:   sub  ax,PW-1            ; back to the player's left edge
        jmp  .xset              ;  (pushed against the wall if one)
.left:  call SOLID2             ; moving left: test the left edge
        jnc  .xset
        mov  cl,4
        sar  ax,cl              ; the wall's tile column
        inc  ax                 ; the tile to its right
        shl  ax,cl              ; its left pixel
.xset:  mov  [px],ax
.y:     mov  ax,[vy]            ; ---- down: gravity, then the 8.8 move
        add  ax,GRAV            ; vy += g
        cmp  ax,VMAX
        jle  .vy
        mov  ax,VMAX            ; never faster than a tile a tick
.vy:    mov  [vy],ax
        mov  dl,al              ; DL = vy's fraction
        mov  al,ah
        cbw                     ; AX = vy's whole pixels, sign kept
        add  [pyf],dl           ; fraction + fraction: CF a whole pixel
        adc  [py],ax            ; whole + whole + that carry
        mov  al,[ground]
        mov  [wasgr],al
        mov  byte [ground],0
        mov  ax,[px]
        mov  bx,[py]
        cmp  word [vy],0
        jl   .up
        add  bx,PH              ; falling: the row under the feet
        call SOLIDX
        jnc  .coin
        mov  cl,4
        sar  bx,cl              ; the floor's tile row
        shl  bx,cl              ; its top pixel
        sub  bx,PH              ; stand on it
        mov  [py],bx
        mov  byte [pyf],0
        mov  word [vy],0
        mov  byte [ground],1
        cmp  byte [wasgr],0
        jne  .coin
        cmp  word [jumps],0
        je   .coin
        inc  word [lands]       ; a check: came down after a jump
        jmp  .coin
.up:    call SOLIDX             ; rising: the head's row
        jnc  .coin
        mov  cl,4
        sar  bx,cl              ; the ceiling's tile row
        inc  bx                 ; the row below it
        shl  bx,cl              ; its top pixel: the head just under
        mov  [py],bx
        mov  byte [pyf],0
        mov  word [vy],0        ; the bump stops the rise
        inc  word [bumps]
.coin:  mov  ax,[px]            ; ---- a coin under the middle?
        add  ax,PW/2
        mov  bx,[py]
        add  bx,PH/2
        call TILEAT             ; AL = the letter, DI = where in the map
        cmp  al,'o'
        jne  .jump
        mov  byte [map+di],'.'  ; taken: air now
        inc  word [score]
        mov  al,SPX_COIN
        call SPK_FX
.jump:  cmp  byte [ground],0    ; ---- the jump, from the ground only
        je   .fall
        mov  al,SC_UP
        call KEY_HELD
        jnz  .jmp
        mov  al,SC_SPACE
        call KEY_HELD
        jz   .fall
.jmp:   mov  word [vy],JUMPV
        mov  byte [ground],0
        inc  word [jumps]
        mov  al,SPX_JUMP
        call SPK_FX
.fall:  cmp  word [py],200      ; off the bottom of the world?
        jl   .cam
        call RESPAWN
.cam:   mov  ax,[px]            ; ---- the camera: the player in the middle
        add  ax,PW/2-160        ; camx = centre - half the screen
        xor  bx,bx
        mov  cx,MAPW*TILE-320
        call MTH_CLAMP          ; held to the map's ends
        mov  [camx],ax
        pop  di
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; ---- TILEAT: AL = the map letter at pixel (AX,BX), DI = its offset -------
;  Off the map's sides: '#' (walls), above or below it: '.' (air).
TILEAT: push ax
        push bx
        push cx
        mov  cl,4
        sar  ax,cl              ; column = x / 16
        sar  bx,cl              ; row = y / 16
        cmp  ax,MAPW
        jae  .wall              ; (negative is huge unsigned: also a wall)
        cmp  bx,MAPH
        jae  .air
        mov  di,bx
        shl  di,1               ; row * 2
        shl  di,1               ; row * 4
        add  di,bx              ; row * 5
        mov  cl,3
        shl  di,cl              ; row * 40
        add  di,ax              ; + column
        pop  cx
        pop  bx
        pop  ax
        mov  al,[map+di]
        ret
.air:   pop  cx
        pop  bx
        pop  ax
        mov  al,'.'             ; above or below: air
        mov  di,0FFFFh          ; no place in the map
        ret
.wall:  pop  cx
        pop  bx
        pop  ax
        mov  al,'#'             ; past a side: wall
        mov  di,0FFFFh
        ret
; SOLID: CF = 1 if pixel (AX,BX) is in a brick or grass tile. Keeps all.
SOLID:  push ax
        push dx
        push di
        call TILEAT
        cmp  al,'#'
        je   .y
        cmp  al,'='
        je   .y
        clc
        jmp  .r
.y:     stc
.r:     pop  di
        pop  dx
        pop  ax
        ret
; SOLID2: CF = 1 if column AX is solid at the player's top or bottom row
SOLID2: call SOLID              ; (AX, BX = py)
        jc   .r
        push bx
        add  bx,PH-1            ; the bottom row
        call SOLID
        pop  bx
.r:     ret
; SOLIDX: CF = 1 if row BX is solid under the player's left or right side
SOLIDX: push ax
        inc  ax                 ; a pixel in from the left
        call SOLID
        jc   .r
        add  ax,PW-3            ; a pixel in from the right
        call SOLID
.r:     pop  ax
        ret

; ---- PILOT (/AUTO): hold Right; jump at a wall or a gap ahead -----------
PILOT:  inc  word [aplay]
        mov  byte [key_held+SC_RT],1
        mov  byte [key_held+SC_UP],0
        mov  ax,[px]
        add  ax,PW+3            ; just ahead of the player
        mov  bx,[py]
        add  bx,PH/2
        call SOLID              ; a wall ahead?
        jc   .j
        add  bx,PH/2+2          ; the floor ahead
        call SOLID
        jc   .r
.j:     mov  byte [key_held+SC_UP],1
.r:     ret

; ---- DRAW: the level, then the score over it ------------------------------
DRAW:   call DRAWLVL
        push es
        mov  es,[vga_buf]
        mov  byte [fnt_col],15  ; the score line: COINS in K_FONT's fast
        mov  byte [fnt_rc],0    ;  4x6 letters, ringed black (FNT_HUD)...
        mov  si,t_coins
        mov  bx,4
        mov  dx,3
        call FNT_HUD            ; BX = past the word
        mov  al,FNT_LSCORE      ; ...the number in bold ringed digits
        call FNT_LOOK
        mov  ax,[score]
        mov  cl,3               ; three digits: 007
        add  bx,4               ; a gap
        mov  dx,1               ; 7 high: its foot on the word's foot
        call FNT_NUMZ
        pop  es
        ret

; ---- DRAWLVL: sky, the visible tiles, the player (the title's picture too)
DRAWLVL:push es
        mov  es,[vga_buf]
        mov  al,1               ; a dark blue sky
        call VGA_CLS
        xor  di,di              ; DI = tile row
.row:   mov  ax,[camx]
        mov  cl,4
        shr  ax,cl              ; the first column seen
        mov  si,ax
        add  ax,21              ; 21 columns cover 320 pixels + a part
        mov  [lastc],ax
.col:   cmp  si,MAPW
        jae  .nrow
        mov  ax,si
        shl  ax,cl              ; column * 16
        sub  ax,[camx]          ; on the screen
        mov  bx,di
        shl  bx,cl              ; row * 16
        add  bx,MAPY            ; below the score line
        push ax
        push bx
        mov  ax,si
        shl  ax,cl              ; the tile's map pixel x
        mov  bx,di
        shl  bx,cl              ; ... and y
        push di
        call TILEAT             ; AL = its letter
        pop  di
        pop  dx                 ; DX = screen y
        pop  bx                 ; BX = screen x
        push si
        mov  si,brick_c
        cmp  al,'#'
        je   .d
        mov  si,grass_c
        cmp  al,'='
        je   .d
        mov  si,coin_c
        cmp  al,'o'
        jne  .nd
.d:     call SPR_DRAW
.nd:    pop  si
        mov  cl,4
        inc  si                 ; the next column
        cmp  si,[lastc]
        jb   .col
.nrow:  inc  di                 ; the next row
        cmp  di,MAPH
        jb   .row
        mov  si,man_c           ; the player, facing where he went
        mov  bx,[px]
        sub  bx,[camx]
        mov  dx,[py]
        add  dx,MAPY
        mov  al,[face]
        call SPR_DRAWM          ; mode bit 0: flipped
        pop  es
        ret

; ---- REPORT (/AUTO) -------------------------------------------------------
REPORT: mov  si,c_walk
        mov  ax,[px]
        sub  ax,STARTX          ; how far it got
        cmp  ax,100
        call PFA                ; PASS if above
        mov  si,c_cam
        mov  ax,[camx]
        cmp  ax,0
        call PFA
        mov  si,c_coin
        mov  ax,[score]
        cmp  ax,0
        call PFA
        mov  si,c_jump
        mov  ax,[lands]         ; jumped, and came down on a floor
        cmp  ax,0
        call PFA
        mov  si,c_bump
        mov  ax,[bumps]
        cmp  ax,0
        call PFA
        ret
; PFA: PASS if the last compare said "above" (unsigned), else FAIL
PFA:    mov  dx,t_pass
        ja   .s
        mov  dx,t_fail
.s:     call TXT_DOS
        call TXT_DOSZ
        mov  si,t_val
        call TXT_DOSZ
        call TXT_DOSNUM         ; the value checked
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

; ---- THE MAP: MAPH rows of MAPW letters ('.' air '#' brick '=' grass 'o' coin)
map     db '........................................'
        db '........................................'
        db '........................................'
        db '........................ooo.............'
        db '.......................#####.......ooo..'
        db '...............ooo.................###..'
        db '.........###..#####.....................'
        db '........................................'
        db '...........................ooo..........'
        db '.....ooo..#..........#.....###.....#....'
        db '=================....=========..========'
        db '#################....#########..########'

; ---- the pictures (text art, the 16 BIOS colours) -------------------------
brick_t db 16,16
        db '6666666C66666666'
        db '6CCCCCC6CCCCCCC6'
        db '6CCCCCC6CCCCCCC6'
        db '4444444444444444'
        db 'CCC6CCCCCCC6CCCC'
        db 'CCC6CCCCCCC6CCCC'
        db 'CCC6CCCCCCC6CCCC'
        db '4444444444444444'
        db '6666666C66666666'
        db '6CCCCCC6CCCCCCC6'
        db '6CCCCCC6CCCCCCC6'
        db '4444444444444444'
        db 'CCC6CCCCCCC6CCCC'
        db 'CCC6CCCCCCC6CCCC'
        db 'CCC6CCCCCCC6CCCC'
        db '4444444444444444'
grass_t db 16,16
        db 'AAAAAAAAAAAAAAAA'
        db 'A2AAA2AAAA2AAA2A'
        db '2222222222222222'
        db '6662666662666626'
        db '6666666666666666'
        db '6686666666668666'
        db '6666666666666666'
        db '6666668666666666'
        db '6666666666666666'
        db '6866666666666686'
        db '6666666666666666'
        db '6666666686666666'
        db '6666666666666666'
        db '6668666666666666'
        db '6666666666686666'
        db '6666666666666666'
coin_t  db 16,16
        db '................'
        db '................'
        db '................'
        db '.....666666.....'
        db '....6EEEEEE6....'
        db '...6EEFEEEEE6...'
        db '...6EFEEEEEE6...'
        db '...6EEEE6EEE6...'
        db '...6EEEE6EEE6...'
        db '...6EEEEEEEE6...'
        db '...6EEEEEEEE6...'
        db '....6EEEEEE6....'
        db '.....666666.....'
        db '................'
        db '................'
        db '................'
man_t   db PW,PH
        db '...6666...'
        db '..666666..'
        db '..EEEE0E..'
        db '..EEEEEE..'
        db '...EEEE...'
        db '..CCCCCC..'
        db '.CCCCCCCC.'
        db 'ECCCCCCCCE'
        db 'E.CCCCCC.E'
        db '..111111..'
        db '..11..11..'
        db '..11..11..'
        db '.666..666.'
        db '.666..666.'

; ---- state ----------------------------------------------------------------
px      dw 0                    ; the player's left, map pixels
py      dw 0                    ; his top, whole map pixels (signed)
pyf     db 0                    ;  and its 256ths
vy      dw 0                    ; 8.8 pixels a tick, down +
ground  db 0                    ; 1 = standing on something
wasgr   db 0
face    db 0                    ; 0 right, 1 left (SPR_DRAWM's flip bit)
camx    dw 0                    ; the screen's left edge in the map
lastc   dw 0
score   dw 0
auto    db 0
aplay   dw 0
jumps   dw 0
lands   dw 0
bumps   dw 0
t_coins db 'COINS',0
t_name  db 'Platform',0         ; the title card's words (R_TITLE TTLCARD)
t_sub   db 'run, jump, take coins',0
t_keys  db 'Arrows',0,'walk',0  ; the key, what it does...
        db 'Up, Space',0,'jump',0
        db 'Esc',0,'quit',0
        db 0                    ; ...an empty key ends them
t_pass  db 'PASS T_PLAT $'
t_fail  db 'FAIL T_PLAT $'
t_val   db ': ',0
c_walk  db 'it walked right more than 100 pixels',0
c_cam   db 'the camera scrolled (camx)',0
c_coin  db 'coins taken',0
c_jump  db 'jumps that landed on a floor',0
c_bump  db 'head bumps under a tile',0
t_nomem db 'Not enough memory for the screen buffer.',13,10,'$'
brick_c db 2+256 dup(0)
grass_c db 2+256 dup(0)
coin_c  db 2+256 dup(0)
man_c   db 2+PW*PH dup(0)

        include '..\..\KIT\LIB\K_MEM.INC'
        include '..\..\KIT\LIB\K_VGA.INC'
        include '..\..\KIT\LIB\K_KEYS.INC'
        include '..\..\KIT\LIB\K_TIME.INC'
        include '..\..\KIT\LIB\K_MATH.INC'
        include '..\..\KIT\LIB\K_TEXT.INC'
        include '..\..\KIT\LIB\K_SPR.INC'
        include '..\..\KIT\LIB\K_SPK.INC'
        include '..\..\KIT\LIB\K_FONT.INC' ; the good letters (FNT_*)
        include '..\..\KIT\REC\R_TITLE.ASM' ; TTLRUN, the title card
