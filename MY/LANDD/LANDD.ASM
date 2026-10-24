; ============================================================================
;  LANDD.ASM - LUNAR LANDER for DOS (mode 13h, PC speaker).
;  Built from KIT\T_ARCADE (loop, states, /AUTO), with K_PHYS for the
;  motion, the recipe KIT\REC\R_ENGINE for the sounds.
;
;  THE GAME. Up = main thrust (uses fuel), Left/Right = side thrusters
;  (use fuel). Gravity pulls down. Three landing pads in the ground, each
;  with a points multiplier (x1, x2, x5). A landing is good when the ship
;  is on a pad and slow enough down and sideways: points, then a new level
;  (new ground). Otherwise a crash: an explosion, one life less. Three
;  lives, then GAME OVER with the score.
;
;  THE STATES (one byte, [state]): TITLE --Enter--> PLAY --landed--> LAND
;  (card, then the next level), PLAY --crash--> BOOM (explosion, then the
;  next life, or OVER when none is left), OVER --Enter after 1 s--> TITLE.
;
;  /AUTO: an autopilot flies to the first pad. After the first landing or
;  crash the result stays up for about a second, SHOT_SAVE takes the
;  picture, the program prints what happened and quits by itself.
;  Esc quits at any time.
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

LANW    = 12                    ; the lander's sprite: 12 x 8
LANH    = 8
GRAV    = 20                    ; gravity, 8.8 a tick each tick (20/256 px)
THRUST  = 45                    ; main thrust, 8.8 a tick, against gravity
SIDE    = 40                    ; side thrusters, 8.8 a tick sideways
FUELMAX = 500                   ; fuel: one unit a tick of any thruster
LIVES   = 3
CARDT   = 36                    ; a result card holds 36 ticks (2 s)
NPAD    = 3                     ; landing pads
PADW    = 24                    ; a pad is 24 columns wide
GMIN    = 110                   ; ground rows: 110 (high) .. 185 (low)
GMAX    = 185
VSAFE   = 256                   ; touchdown limit, 8.8: 1 pixel a tick down
HSAFE   = 128                   ; touchdown limit sideways: half a pixel a tick
AUTOMAX = 900                   ; /AUTO: ticks in the air before a forced crash

ST_TITLE = 0
ST_PLAY  = 1
ST_LAND  = 2                    ; landed: the points card
ST_BOOM  = 3                    ; crashed: the explosion
ST_OVER  = 4                    ; no lives left: GAME OVER

start:  call GETAUTO            ; [auto] = 1 with /AUTO
        call MEM_INIT           ; our 64K kept, the rest for DOS to give
        call VGA_ON             ; mode 13h and the back buffer
        jc   nomem
        call KEY_ON             ; our keyboard: held keys and taps
        call MTH_SEED           ; every game different
        mov  si,lan_t           ; the lander: text art -> compiled sprite
        mov  di,lan_c
        call SPR_COMPILE
        mov  byte [txt_style],1 ; letters with a shadow
        call TIM_STEPS          ; start the tick count

frame:  mov  al,SC_ESC
        call KEY_TAP            ; Esc since the last frame?
        jnz  quit
        call TIM_STEPS          ; AX = ticks gone by
        mov  cx,ax
        jcxz .draw              ; no tick yet: draw again
.step:  call STEP               ; the rules, once a tick (keeps CX)
        loop .step
.draw:  call DRAW
        call VGA_SHOW           ; the buffer onto the screen
        cmp  byte [autoshot],0  ; /AUTO: the result is up - take the picture
        jne  autoend
        jmp  frame

autoend:
        call SHOT_SAVE          ; the game screen is up: SCREEN.PNG

quit:   call SPK_STOP           ; the speaker silent
        call KEY_OFF            ; the BIOS gets its keyboard back
        call VGA_OFF            ; text mode 3, the buffer given back
        cmp  byte [auto],0
        je   .bye
        call REPORT             ; the lines of what happened
.bye:   mov  ax,4C00h
        int  21h

nomem:  mov  dx,t_nomem         ; no memory for the buffer: say so, leave
        mov  ah,9
        int  21h
        mov  ax,4C01h
        int  21h

; ---- STEP: one tick of the rules, by the state. Keeps every register -----
STEP:   push ax
        push bx
        push cx
        push dx
        push si
        push di
        inc  word [ticks]       ; the game's clock
        mov  byte [thrusting],0 ; PLAYTICK sets it while the main engine pushes
        cmp  byte [auto],0
        je   .st
        call AUTOPILOT          ; /AUTO: the keys a player would press
.st:    mov  al,[state]
        cmp  al,ST_PLAY
        je   .play
        cmp  al,ST_TITLE
        je   .title
        cmp  al,ST_OVER
        je   .over
        call CARDTICK           ; LAND and BOOM: the card, then the next step
        jmp  .auto
.title: mov  al,SC_ENTER        ; TITLE: Enter starts a game
        call KEY_TAP
        jz   .auto
        call NEWGAME
        jmp  .auto
.over:  cmp  word [cardclk],0
        je   .ok
        dec  word [cardclk]     ; the card's minimum hold, one tick less
        jmp  .auto
.ok:    mov  al,SC_ENTER
        call KEY_TAP
        jz   .auto
        mov  byte [state],ST_TITLE
        jmp  .auto
.play:  call PLAYTICK
.auto:  cmp  byte [auto],0
        je   .snd
        cmp  byte [autoev],0    ; an outcome (landing or crash) happened?
        je   .snd
        inc  word [autocnt]     ; ticks since it, for the picture
        cmp  word [autocnt],24  ; about 1.3 s with the result on screen
        jb   .snd
        mov  byte [autoshot],1  ; the shot is taken after this frame
.snd:   mov  al,[thrusting]
        call ENG_TICK          ; the engine's rumble, or the chime or crash
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; ---- NEWGAME: score 0, lives full, the first level ------------------------
NEWGAME:mov  word [score],0     ; the score starts at 0
        mov  byte [lives],LIVES ; three lives
        call NEWLEVEL
        ret

; ---- NEWLEVEL: new ground, the lander at the top, fuel full ----------------
NEWLEVEL:
        call GENLEVEL
        call LANDER
        ret

; ---- LANDER: the lander back at the top, a random column, fuel full --------
LANDER: mov  ax,250
        call MTH_RANGE          ; AX = 0..249
        add  ax,30              ; a start column 30..279
        mov  word [lnx+PHY_P],ax
        mov  word [lnx+PHY_V],0 ; no sideways speed
        mov  byte [lnx+PHY_F],0 ; no fraction
        mov  word [lny+PHY_P],12 ; near the top
        mov  word [lny+PHY_V],0 ; not moving yet
        mov  byte [lny+PHY_F],0
        mov  word [fuel],FUELMAX
        mov  byte [state],ST_PLAY
        ret

; ---- GENLEVEL: the ground as a random walk, three flat pads ---------------
GENLEVEL:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        mov  word [gh_h],150    ; the walk starts in the middle
        xor  si,si              ; SI = the column
.col:   mov  ax,7
        call MTH_RANGE          ; AX = 0..6
        sub  ax,3               ; -3..+3 rows a column
        add  ax,[gh_h]          ; the walk takes one step
        mov  bx,GMIN
        mov  cx,GMAX
        call MTH_CLAMP          ; held between the lowest and the highest ground
        mov  [gh_h],ax
        mov  [gh+si],al         ; one byte a column
        inc  si                 ; the next column
        cmp  si,320
        jb   .col
        xor  si,si              ; SI = the pad * 2 (word arrays)
.pad:   mov  ax,60
        call MTH_RANGE          ; AX = 0..59
        add  ax,[pbase+si]      ; the pad's zone: 20.., 125.., 230..
        mov  [padx+si],ax       ; the pad's first column
        mov  di,ax
        add  di,12              ; DI = the middle column
        mov  al,[gh+di]         ; the ground row there...
        xor  ah,ah
        mov  dx,ax              ; ...is the pad's height
        mov  di,[padx+si]       ; DI = the first column again
        mov  cx,PADW            ; CX = its width
.flat:  mov  [gh+di],dl         ; a flat column at that height
        inc  di                 ; the next column
        dec  cx                 ; one column less to go
        jnz  .flat
        mov  ax,3
        call MTH_RANGE          ; AX = 0..2
        shl  ax,1               ; x2: a word index
        mov  bx,ax
        mov  ax,[pmul_t+bx]     ; the pad's multiplier: 1, 2 or 5
        mov  [padm+si],ax
        add  si,2               ; the next pad
        cmp  si,NPAD*2
        jb   .pad
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; ---- PLAYTICK: one tick of flight ------------------------------------------
PLAYTICK:
        mov  byte [thrusting],0 ; the engine is off until it pushes
        xor  bx,bx              ; BX = the side push, 8.8 a tick (0 none)
        mov  al,SC_LF
        call KEY_HELD
        jz   .r1
        mov  bx,-SIDE           ; left arrow: push left
.r1:    mov  al,SC_RT
        call KEY_HELD
        jz   .r2
        mov  bx,SIDE            ; right arrow: push right
.r2:    xor  dx,dx              ; DX = the main thrust (0 none)
        mov  al,SC_UP
        call KEY_HELD
        jz   .r3
        mov  dx,-THRUST         ; up arrow: the main engine pushes up
.r3:    cmp  word [fuel],0      ; any fuel left?
        jg   .burn
        xor  bx,bx              ; the tanks are dry: no side push
        xor  dx,dx              ; and no main engine
        jmp  .go
.burn:  mov  ax,bx
        or   ax,dx              ; a thruster on?
        jz   .go
        dec  word [fuel]        ; one unit of fuel a tick
        or   dx,dx
        jz   .go
        mov  byte [thrusting],1 ; the main engine's rumble
.go:    mov  ax,bx              ; the sideways push...
        mov  si,lnx
        call PHY_INTEG          ; ...v += push, p += v (K_PHYS)
        cmp  word [lnx+PHY_V],1024    ; a sideways cap: 4 pixels a tick
        jle  .c2
        mov  word [lnx+PHY_V],1024
.c2:    cmp  word [lnx+PHY_V],-1024
        jge  .c3
        mov  word [lnx+PHY_V],-1024
.c3:    mov  ax,GRAV            ; gravity...
        add  ax,dx              ; ...less the main thrust (thrust is upward)
        mov  si,lny
        call PHY_INTEG          ; the fall: v += accel, p += v
        cmp  word [lnx+PHY_P],0 ; the left wall
        jge  .w1
        mov  word [lnx+PHY_P],0
        mov  word [lnx+PHY_V],0
.w1:    cmp  word [lnx+PHY_P],320-LANW  ; the right wall
        jle  .w2
        mov  word [lnx+PHY_P],320-LANW
        mov  word [lnx+PHY_V],0
.w2:    cmp  word [lny+PHY_P],0 ; the top of the screen
        jge  .w3
        mov  word [lny+PHY_P],0
        mov  word [lny+PHY_V],0
.w3:    call LANDCHK            ; CF = 1: the ship has touched the ground
        jnc  .r
        call TOUCH
.r:     ret

; ---- LANDCHK: CF = 1 when the lander's feet reach the ground --------------
LANDCHK:
        push ax
        push bx
        push dx
        mov  dx,255             ; DX = the highest ground under the ship (to find)
        mov  ax,[lnx+PHY_P]     ; its left column
        call GMIN_ROW
        mov  ax,[lnx+PHY_P]
        add  ax,6               ; its middle column
        call GMIN_ROW
        mov  ax,[lnx+PHY_P]
        add  ax,LANW-2          ; its right column
        call GMIN_ROW           ; DX = the top of the ground under it
        mov  ax,[lny+PHY_P]
        add  ax,LANH           ; AX = the row under its feet
        cmp  ax,dx
        jl   .no                ; the feet are above the ground: no touch
        stc                     ; CF = 1: touched
        jmp  .x
.no:    clc
.x:     pop  dx
        pop  bx
        pop  ax
        ret

; GMIN_ROW: in AX = a column, DX = a row so far. Out: DX = the higher one
GMIN_ROW:
        push bx
        mov  bx,ax
        mov  al,[gh+bx]        ; the ground's row in that column
        xor  ah,ah
        cmp  ax,dx
        jae  .k                 ; not higher than DX: keep DX
        mov  dx,ax              ; higher: the new top
.k:     pop  bx
        ret

; GROWAT: in AX = a column, out AX = the ground's row there
GROWAT: mov  bx,ax
        mov  al,[gh+bx]
        xor  ah,ah
        ret

; ---- TOUCH: the ship has touched the ground: a landing or a crash ---------
TOUCH:  mov  ax,[lny+PHY_V]
        call ABSAX              ; AX = the speed down, no sign
        cmp  ax,VSAFE
        jg   CRASH              ; too fast down: crash
        mov  ax,[lnx+PHY_V]
        call ABSAX              ; AX = the speed sideways, no sign
        cmp  ax,HSAFE
        jg   CRASH              ; too fast sideways: crash
        mov  ax,[lnx+PHY_P]
        add  ax,6               ; the ship's middle column
        call PADMUL             ; AX = that pad's multiplier, 0 for none
        or   ax,ax
        jz   CRASH              ; not on a pad: crash
        mov  [lastmul],ax
        mov  bx,ax              ; BX = the multiplier
        mov  ax,100
        mul  bx                 ; AX = 100 points times the multiplier
        mov  [lastpts],ax
        add  [score],ax         ; the score goes up
        mov  byte [lastland],1
        mov  byte [autoev],1    ; /AUTO: an outcome happened
        mov  byte [state],ST_LAND
        mov  word [cardclk],CARDT
        call ENG_CHIME          ; the landing chime
        ret

; ---- CRASH: the lander is lost: explosion, one life less ------------------
CRASH:  mov  byte [lastland],0
        mov  word [lastmul],0
        mov  byte [autoev],1    ; /AUTO: an outcome happened
        mov  byte [state],ST_BOOM
        mov  word [cardclk],CARDT
        mov  word [boom],0      ; the explosion's age
        mov  ax,[lnx+PHY_P]
        add  ax,LANW/2          ; the explosion at the ship's middle
        mov  [exx],ax
        mov  ax,[lny+PHY_P]
        add  ax,LANH/2
        mov  [exy],ax
        dec  byte [lives]       ; one life less
        call ENG_CRASH          ; the crash sound
        ret

; ---- PADMUL: in AX = a column, out AX = the multiplier of its pad, 0 none --
PADMUL: push bx
        push si
        xor  si,si              ; SI = the pad * 2
.p:     mov  bx,ax
        sub  bx,[padx+si]       ; BX = how far into that pad
        jl   .n                 ; before it
        cmp  bx,PADW
        jl   .hit               ; inside it
.n:     add  si,2               ; the next pad
        cmp  si,NPAD*2
        jb   .p
        xor  ax,ax              ; on no pad
        jmp  .x
.hit:   mov  ax,[padm+si]       ; the multiplier of the pad
.x:     pop  si
        pop  bx
        ret

; ---- CARDTICK: the card or the explosion, one tick -----------------------
CARDTICK:
        inc  word [boom]        ; the age (the explosion draws it)
        cmp  word [cardclk],0
        je   .next
        dec  word [cardclk]     ; the card holds one tick more
        ret
.next:  cmp  byte [state],ST_LAND
        je   NEWLEVEL           ; landed: the next level
        cmp  byte [lives],0
        je   .over
        call LANDER             ; a life left: the lander back at the top
        ret
.over:  mov  byte [state],ST_OVER
        mov  word [cardclk],CARDT
        mov  ax,[score]
        cmp  ax,[hiscore]
        jbe  .r
        mov  [hiscore],ax       ; a new best, kept while the program runs
.r:     ret

; ---- ABSAX: AX = |AX| -------------------------------------------------------
ABSAX:  or   ax,ax
        jns  .p
        neg  ax                 ; a negative speed made positive
.p:     ret

; ---- AUTOPILOT (/AUTO only): the keys a player would press ----------------
AUTOPILOT:
        mov  byte [key_held+SC_UP],0
        mov  byte [key_held+SC_LF],0
        mov  byte [key_held+SC_RT],0
        cmp  byte [state],ST_TITLE
        jne  .play
        cmp  word [ticks],5     ; the title shown 5 ticks: Enter
        jb   .r
        mov  byte [key_hit+SC_ENTER],1
        ret
.play:  cmp  byte [state],ST_PLAY
        jne  .r
        inc  word [aplay]       ; ticks played, for the run's length
        cmp  word [aplay],AUTOMAX
        jb   .steer
        call CRASH              ; too long in the air: it counts as a crash
.r:     ret
.steer: mov  ax,[padx]          ; the target: pad 0's middle column
        add  ax,12
        mov  bx,[lnx+PHY_P]
        add  bx,6               ; the ship's middle column
        sub  ax,bx              ; AX = how far to go, to the right
        mov  dx,ax              ; DX = the same, for the descent
        mov  cl,4
        shl  ax,cl              ; x16: the sideways speed wanted, 8.8
        cmp  ax,512
        jle  .c1
        mov  ax,512             ; two pixels a tick at most
.c1:    cmp  ax,-512
        jge  .c2
        mov  ax,-512
.c2:    sub  ax,[lnx+PHY_V]     ; AX = the speed still to add
        cmp  ax,8
        jg   .rt                ; too slow to the right: push right
        cmp  ax,-8
        jl   .lf                ; too fast to the right: push left
        jmp  .vert
.rt:    mov  byte [key_held+SC_RT],1
        jmp  .vert
.lf:    mov  byte [key_held+SC_LF],1
.vert:  mov  ax,dx
        call ABSAX              ; AX = how far off the pad, no sign
        cmp  ax,12
        jle  .onpad
        mov  bx,40              ; off the pad: hold about row 40
        cmp  word [lny+PHY_P],40
        jl   .near              ; higher up than that: come down to it
        mov  bx,-20             ; lower than that: climb back
        jmp  .near
.onpad: mov  ax,[lnx+PHY_P]
        add  ax,6               ; the middle column
        call GROWAT             ; AX = the ground's row under it
        sub  ax,[lny+PHY_P]     ; less the ship's top
        sub  ax,LANH            ; AX = the altitude: the gap under the feet
        mov  bx,400             ; high up: a fall of 1.5 pixels a tick
        cmp  ax,30
        jg   .near              ; more than 30 rows to go: fast
        or   ax,ax
        jns  .slow
        xor  ax,ax              ; touching: no altitude left
.slow:  mov  cl,2
        shl  ax,cl              ; x4: the nearer the ground, the slower
        add  ax,40              ; a floor of 40: 0.16 pixel a tick
        mov  bx,ax              ; the fall wanted, slowing down to the touch
.near:  mov  ax,[lny+PHY_V]
        cmp  ax,bx
        jle  .r
        mov  byte [key_held+SC_UP],1 ; falling faster than wanted: thrust
        ret

; ---- DRAW: the picture into the back buffer ---------------------------------
DRAW:   push es
        mov  es,[vga_buf]       ; ES = the buffer, 320 bytes a row
        xor  al,al
        call VGA_CLS           ; black sky
        mov  byte [txt_scale],1
        cmp  byte [state],ST_TITLE
        je   .title
        call DRAWGROUND
        call DRAWPADS
        cmp  byte [state],ST_PLAY
        jne  .np
        call DRAWLAN
        call DRAWHUD
        jmp  .x
.np:    cmp  byte [state],ST_LAND
        jne  .nl
        call DRAWLANDCARD
        jmp  .x
.nl:    cmp  byte [state],ST_BOOM
        jne  .over
        call DRAWBOOM
        mov  byte [txt_col],12
        mov  si,t_crash
        mov  bx,160
        mov  dx,60
        call TXT_CENTER
        jmp  .x
.over:  mov  byte [txt_col],12
        mov  si,t_over
        mov  bx,160
        mov  dx,70
        call TXT_CENTER
        mov  byte [txt_col],15
        mov  si,t_score
        mov  bx,110
        mov  dx,100
        call TXT_PUT
        mov  ax,[score]
        call TXT_NUM            ; the score of the game
        mov  si,t_best
        mov  bx,110
        mov  dx,112
        call TXT_PUT
        mov  ax,[hiscore]
        call TXT_NUM            ; the best this session
        jmp  .x
.title: mov  byte [txt_scale],2 ; the name, twice as big
        mov  byte [txt_col],14
        mov  si,t_name
        mov  bx,160
        mov  dx,50
        call TXT_CENTER
        mov  byte [txt_scale],1
        mov  byte [txt_col],7
        mov  si,t_keys1
        mov  bx,160
        mov  dx,100
        call TXT_CENTER
        mov  si,t_keys2
        mov  dx,116
        call TXT_CENTER
        mov  byte [txt_col],15
        mov  si,t_enter
        mov  dx,140
        call TXT_CENTER
.x:     pop  es
        ret

; DRAWGROUND: the ground, a grey column a column, down to the screen's foot
DRAWGROUND:
        mov  byte [drw_col],7   ; grey ground
        xor  si,si              ; SI = the column
.c:     mov  ax,si              ; AX = the column
        mov  bl,[gh+si]         ; BL = the ground's row here
        xor  bh,bh              ; BX = that row
        mov  dx,200
        sub  dx,bx              ; DX = the rows from it down to the foot
        mov  cx,1               ; one column wide
        call DRW_RECT
        inc  si                 ; the next column
        cmp  si,320
        jb   .c
        ret

; DRAWPADS: a yellow stripe on each pad, its multiplier above it
DRAWPADS:
        xor  si,si              ; SI = the pad * 2
.pd:    push si
        mov  di,[padx+si]       ; DI = the pad's first column
        add  di,12              ; DI = its middle
        mov  bl,[gh+di]         ; BL = the ground row under the middle
        xor  bh,bh              ; BX = that row
        dec  bx                 ; BX = one row above: the stripe
        mov  ax,[padx+si]       ; AX = the stripe's left column
        mov  cx,PADW            ; CX = its width
        mov  dx,2               ; DX = two rows thick
        mov  byte [drw_col],14  ; yellow
        call DRW_RECT
        mov  dx,bx              ; DX = the stripe's row
        sub  dx,10              ; DX = the label, ten rows above it
        mov  bx,[padx+si]       ; BX = the pad's first column
        add  bx,8               ; a little in from its edge
        mov  si,t_x
        mov  byte [txt_col],15  ; white
        call TXT_PUT            ; BX = past the X
        pop  si
        push si
        mov  ax,[padm+si]       ; AX = the multiplier
        call TXT_NUM            ; the number after the X
        pop  si
        add  si,2               ; the next pad
        cmp  si,NPAD*2
        jb   .pd
        ret

; DRAWLAN: the lander, and a flame under it while the main engine pushes
DRAWLAN:
        cmp  byte [thrusting],0
        je   .sh
        mov  ax,[lnx+PHY_P]
        add  ax,4               ; the flame's column
        mov  bx,[lny+PHY_P]
        add  bx,LANH            ; just under the feet
        mov  cx,4
        mov  dx,3
        mov  byte [drw_col],12  ; red flame
        call DRW_RECT
.sh:    mov  si,lan_c
        mov  bx,[lnx+PHY_P]
        mov  dx,[lny+PHY_P]
        call SPR_DRAW
        ret

; DRAWHUD: fuel, score, lives, the speeds in tenths of a pixel a tick, the height
DRAWHUD:
        mov  byte [txt_col],15
        mov  si,t_fuel
        mov  bx,4
        mov  dx,2
        call TXT_PUT
        mov  ax,[fuel]
        call TXT_NUM
        mov  si,t_score
        mov  bx,110
        mov  dx,2
        call TXT_PUT
        mov  ax,[score]
        call TXT_NUM
        mov  si,t_lives
        mov  bx,240
        mov  dx,2
        call TXT_PUT
        mov  al,[lives]
        xor  ah,ah
        call TXT_NUM
        mov  si,t_vs
        mov  bx,4
        mov  dx,12
        call TXT_PUT
        mov  ax,[lny+PHY_V]
        call TENTHS
        call TXT_SNUM           ; the vertical speed, down is plus
        mov  si,t_hs
        mov  bx,110
        mov  dx,12
        call TXT_PUT
        mov  ax,[lnx+PHY_V]
        call TENTHS
        call TXT_SNUM           ; the sideways speed
        mov  si,t_alt
        mov  bx,200
        mov  dx,12
        call TXT_PUT
        mov  ax,[lnx+PHY_P]
        add  ax,6               ; the middle column
        call GROWAT             ; AX = the ground's row under it
        sub  ax,[lny+PHY_P]     ; less the ship's top
        sub  ax,LANH            ; less its height: the gap under the feet
        jns  .alt
        xor  ax,ax              ; touching: zero
.alt:   call TXT_NUM
        ret

; TENTHS: AX = a speed in 8.8 -> tenths of a pixel a tick (signed)
TENTHS: mov  cx,10
        imul cx                 ; DX:AX = speed x 10 (small: AX holds it)
        mov  cl,8
        sar  ax,cl              ; /256: 8.8 to whole units
        ret

; DRAWLANDCARD: the points of a landing
DRAWLANDCARD:
        mov  byte [txt_col],14
        mov  si,t_landed        ; "LANDED ON X"
        mov  bx,96
        mov  dx,70
        call TXT_PUT
        mov  ax,[lastmul]
        call TXT_NUM            ; ...and the multiplier after it
        mov  byte [txt_col],15
        mov  si,t_pts
        mov  bx,96
        mov  dx,90
        call TXT_PUT
        mov  ax,[lastpts]
        call TXT_NUM            ; the points won
        ret

; DRAWBOOM: sparks flying out from the crash, and a fireball while young
DRAWBOOM:
        xor  si,si              ; SI = the spark, a word index (8 sparks)
.d:     mov  ax,[dirx+si]
        imul word [boom]        ; the direction times the age
        shl  ax,1               ; two pixels a tick
        add  ax,[exx]          ; the spark's column
        mov  di,ax              ; DI = the column, kept
        mov  ax,[diry+si]
        imul word [boom]
        shl  ax,1
        add  ax,[exy]          ; the spark's row
        mov  bx,ax              ; BX = the row
        mov  ax,di              ; AX = the column
        mov  cx,4               ; a 4 x 4 spark
        mov  dx,4
        mov  byte [drw_col],14  ; yellow...
        test si,4               ; ...every other one red
        jz   .c
        mov  byte [drw_col],12
.c:     call DRW_RECT
        add  si,2               ; the next spark
        cmp  si,16
        jb   .d
        cmp  word [boom],12     ; the fireball while it is young
        jae  .r
        mov  ax,[exx]
        sub  ax,3               ; a 6 x 6 ball round the crash
        mov  bx,[exy]
        sub  bx,3
        mov  cx,6
        mov  dx,6
        mov  byte [drw_col],15  ; white hot
        call DRW_RECT
.r:     ret

; ---- REPORT (/AUTO): what happened, on DOS's output -------------------------
REPORT: cmp  byte [lastland],0
        je   .cr
        mov  si,r_land          ; "landed on x"
        call TXT_DOSZ
        mov  ax,[lastmul]
        call TXT_DOSNUM
        mov  si,r_pad           ; " pad"
        call TXT_DOSZ
        call TXT_DOSCR
        jmp  .sc
.cr:    mov  si,r_crash         ; "crashed"
        call TXT_DOSZ
        call TXT_DOSCR
.sc:    mov  si,r_score         ; "score "
        call TXT_DOSZ
        mov  ax,[score]
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

; ---- the lander's picture (text art: '.' see-through, 0..F the BIOS colours)
lan_t   db LANW,LANH
        db '.....FF.....'
        db '....F99F....'
        db '...F9BB9F...'
        db '..F999999F..'
        db '.FFFFFFFFFF.'
        db '.F.FFFFFF.F.'
        db '.C........C.'
        db 'CC........CC'

; ---- the ground's pads: x, multiplier; the first columns of the zones
pbase   dw 20,125,230
pmul_t  dw 1,2,5

; ---- the state ---------------------------------------------------------------
state    db ST_TITLE
lives    db 0
score    dw 0
hiscore  dw 0
fuel     dw 0
thrusting db 0
boom     dw 0                   ; the explosion's age, ticks
cardclk  dw 0                   ; a card's ticks left
ticks    dw 0
exx      dw 0                   ; the crash's centre
exy      dw 0
lastland db 0                   ; 1 the last outcome was a landing
lastmul  dw 0                   ; its multiplier
lastpts  dw 0                   ; its points
gh_h     dw 0
gh       db 320 dup(0)          ; the ground: a row a column
padx     dw NPAD dup(0)         ; each pad's first column
padm     dw NPAD dup(0)         ; each pad's multiplier
dirx     dw -1,0,1,1,1,0,-1,-1  ; the sparks' directions
diry     dw -1,-1,-1,0,1,1,1,0
lnx      dw 3 dup(0)            ; the lander's sideways axis (K_PHYS record, 6 bytes)
lny      dw 3 dup(0)            ; its vertical axis
; the recipe R_ENGINE's state
eng_t    dw 0                   ; ticks left of the chime or crash, 0 none
eng_kind db 0                   ; 1 chime, 2 crash
; /AUTO and its checks
auto     db 0
autoev   db 0                   ; 1 an outcome happened
autocnt  dw 0
autoshot db 0
aplay    dw 0
; the words
t_name   db 'LUNAR LANDER',0
t_keys1  db 'UP MAIN THRUST   LEFT RIGHT SIDE',0
t_keys2  db 'LAND SLOW AND LEVEL ON A PAD',0
t_enter  db 'ENTER STARTS   ESC QUITS',0
t_fuel   db 'FUEL ',0
t_score  db 'SCORE ',0
t_best   db 'BEST ',0
t_lives  db 'LIVES ',0
t_vs     db 'VS ',0
t_hs     db 'HS ',0
t_alt    db 'ALT ',0
t_x      db 'X',0
t_landed db 'LANDED ON X',0
t_pts    db 'POINTS ',0
t_crash  db 'CRASHED',0
t_over   db 'GAME OVER',0
r_land   db 'landed on x',0
r_pad    db ' pad',0
r_crash  db 'crashed',0
r_score  db 'score ',0
t_nomem  db 'Not enough memory for the screen buffer.',13,10,'$'
lan_c    db 2+LANW*LANH dup(0)  ; the compiled sprite

; ---- the recipe R_ENGINE: the engine's rumble, the landing chime, the crash
ENG_RUMBLE = 9000               ; the engine's base divisor (~130 Hz)
ENG_SPREAD = 4                  ; shift of the random jump: 16 x 0..255
ENG_CHLEN = 40                  ; the chime's ticks (about 2 s)
ENG_CRLEN = 40                  ; the crash's ticks

ENG_TICK:
        push ax
        push bx
        push cx
        cmp  word [eng_t],0
        je   .engine
        dec  word [eng_t]       ; one tick of the chime or crash gone
        cmp  byte [eng_kind],1
        je   .chime
        ; the crash: a pitch falling as it goes, with noise on it
        mov  ax,ENG_CRLEN
        sub  ax,[eng_t]         ; ticks since the crash
        mov  cl,7
        shl  ax,cl              ; x128: the divisor grows, the pitch falls
        add  ax,1500            ; from about 800 Hz
        mov  bx,ax
        call MTH_RND
        mov  al,ah              ; the high bits
        xor  ah,ah
        and  al,3Fh             ; 0..63
        shl  ax,1               ; x2: the noise
        add  ax,bx              ; tone plus noise
        call SPK_TONE
        jmp  .x
.chime: mov  bx,[eng_t]         ; C E G C' by quarters of the chime
        mov  ax,2281            ; C
        cmp  bx,30
        ja   .say
        mov  ax,1810            ; E
        cmp  bx,20
        ja   .say
        mov  ax,1522            ; G
        cmp  bx,10
        ja   .say
        mov  ax,1140            ; the high C
.say:   call SPK_TONE
        jmp  .x
.engine:
        or   al,al
        jz   .quiet
        call MTH_RND
        mov  al,ah              ; the high bits
        xor  ah,ah
        mov  cl,ENG_SPREAD
        shl  ax,cl              ; x16: a jump of 0..4080
        add  ax,ENG_RUMBLE      ; around the base: a rumble, not a note
        call SPK_TONE
        jmp  .x
.quiet: call SPK_OFF
.x:     pop  cx
        pop  bx
        pop  ax
        ret

ENG_CHIME:
        mov  byte [eng_kind],1
        mov  word [eng_t],ENG_CHLEN
        ret

ENG_CRASH:
        mov  byte [eng_kind],2
        mov  word [eng_t],ENG_CRLEN
        ret

        include '..\..\KIT\LIB\K_MEM.INC'
        include '..\..\KIT\LIB\K_VGA.INC'
        include '..\..\KIT\LIB\K_KEYS.INC'
        include '..\..\KIT\LIB\K_TIME.INC'
        include '..\..\KIT\LIB\K_MATH.INC'
        include '..\..\KIT\LIB\K_DRAW.INC'
        include '..\..\KIT\LIB\K_TEXT.INC'
        include '..\..\KIT\LIB\K_SPR.INC'
        include '..\..\KIT\LIB\K_SPK.INC'
        include '..\..\KIT\LIB\K_PHYS.INC'
        include '..\SHOT.INC'
