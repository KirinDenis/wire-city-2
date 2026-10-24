; ============================================================================
;  LANDB.ASM - LUNAR LANDER for DOS (8086, flat FASM, a .COM, VGA mode 13h)
;  Up = main thrust, Left/Right = side thrusters. Land softly on a pad: the
;  pad's multiplier times 50 points, plus what fuel is left. Crash: a life.
;  Three lives, then GAME OVER. /AUTO: an autopilot plays itself, takes one
;  screenshot, prints what happened and quits.
;
;  UNITS: positions and speeds are 1/16 pixel (a word each), speeds per BIOS
;  tick. Gravity is 1 unit a tick, so a thrust of 3 nets 2 upward.
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

NSEG    = 40                    ; ground points every 8 pixels (41 points)
GRAV    = 1                     ; gravity, units per tick per tick
THR     = 3                     ; main thrust, units per tick per tick
SIDE    = 1                     ; side thrust
FUEL0   = 1000                  ; a full tank
VYMAX   = 24                    ; the fastest safe touchdown, down
VXMAX   = 12                    ; and sideways
LIVES   = 3
WAITT   = 40                    ; ticks the landing / crash result stays up
CARDT   = 18                    ; GAME OVER ignores Enter this long
AUTOMAX = 500                   ; /AUTO gives up after this many ticks of play

ST_TITLE = 0
ST_PLAY  = 1
ST_LAND  = 2
ST_CRASH = 3
ST_OVER  = 4

start:  call GETAUTO            ; [auto] = 1 with /AUTO
        call MEM_INIT           ; keep our 64K, the rest is DOS's
        call VGA_ON             ; mode 13h + back buffer
        jc   nomem
        call KEY_ON             ; our keyboard hook
        call MTH_SEED           ; every game different
        mov  si,ship_t          ; text art -> compiled sprite
        mov  di,ship_c
        call SPR_COMPILE
        mov  byte [txt_style],1 ; letters with a shadow
        mov  word [px],160      ; harmless values before the first game
        mov  word [alt],100
        call TIM_STEPS          ; start the step count

frame:  mov  al,SC_ESC
        call KEY_TAP            ; Esc since the last frame?
        jnz  quit
        cmp  byte [finish],0    ; /AUTO is done?
        jne  quit
        call TIM_STEPS          ; AX = ticks gone by, 0..4
        mov  cx,ax
        jcxz .draw              ; none yet: draw again
.step:  call STEP               ; the rules, once a tick (keeps CX)
        loop .step
.draw:  call DRAW
        call VGA_SHOW           ; wait for the retrace, show the buffer
        cmp  byte [doshot],1    ; /AUTO wants its picture now?
        jne  frame
        mov  byte [doshot],2
        call SHOT_SAVE          ; the screen -> SHOT.RAW
        jmp  frame

quit:   call SPK_STOP           ; speaker silent
        call KEY_OFF            ; the BIOS gets its keyboard back
        call VGA_OFF            ; text mode 3
        cmp  byte [auto],0
        je   .bye
        call REPORT             ; /AUTO: say what happened
.bye:   mov  ax,4C00h
        int  21h

nomem:  mov  dx,t_nomem
        mov  ah,9
        int  21h
        mov  ax,4C01h
        int  21h

; ---- STEP: one tick of the rules by state. Keeps every register -----------
STEP:   push ax
        push bx
        push cx
        push dx
        push si
        push di
        inc  word [ticks]       ; the game's clock
        cmp  byte [auto],0
        je   .st
        call AUTOKEYS           ; /AUTO: the keys a pilot would press
.st:    mov  al,[state]
        cmp  al,ST_PLAY
        je   .play
        cmp  al,ST_LAND
        je   .land
        cmp  al,ST_CRASH
        je   .crash
        cmp  al,ST_OVER
        je   .over
        mov  al,SC_ENTER        ; TITLE: Enter starts
        call KEY_TAP
        jz   .snd
        call NEWGAME
        jmp  .snd
.play:  call PLAYTICK
        jmp  .snd
.land:  dec  word [wcnt]        ; the result stays up a while
        call WAITCHK
        cmp  word [wcnt],0
        jne  .snd
        inc  word [level]       ; next level: new ground, a fresh tank
        call NEWLEVEL
        jmp  .snd
.crash: inc  word [age]         ; the explosion grows a tick
        dec  word [wcnt]
        call WAITCHK
        cmp  word [wcnt],0
        jne  .snd
        cmp  byte [lives],0
        je   .dead
        call SETSHIP            ; same ground, a new ship
        mov  word [fuel],FUEL0
        mov  byte [state],ST_PLAY
        jmp  .snd
.dead:  mov  byte [state],ST_OVER
        mov  word [cardclk],CARDT
        jmp  .snd
.over:  cmp  word [cardclk],0
        je   .ok
        dec  word [cardclk]     ; the card's minimum hold
        jmp  .snd
.ok:    mov  al,SC_ENTER
        call KEY_TAP
        jz   .snd
        mov  byte [state],ST_TITLE
.snd:   call SPK_TICK           ; the speaker's effect one tick on
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; WAITCHK (/AUTO only): at wait = 22 ask for the screenshot, at 0 finish
WAITCHK:cmp  byte [auto],0
        je   .r
        cmp  word [wcnt],22
        jne  .z
        mov  byte [doshot],1
.z:     cmp  word [wcnt],0
        jne  .r
        mov  byte [finish],1
.r:     ret

; ---- NEWGAME / NEWLEVEL / SETSHIP -------------------------------------------
NEWGAME:mov  word [score],0
        mov  byte [lives],LIVES
        mov  word [level],1
NEWLEVEL:
        call MKGROUND           ; new jagged ground and pads
        call SETSHIP
        mov  word [fuel],FUEL0
        mov  byte [state],ST_PLAY
        ret

SETSHIP:mov  ax,240
        call MTH_RANGE          ; AX = 0..239
        add  ax,40              ; x pixel 40..279
        mov  cl,4
        shl  ax,cl              ; x * 16: into 1/16 pixel units
        mov  [shipx],ax
        mov  word [shipy],20*16 ; high above the ground
        mov  ax,17
        call MTH_RANGE          ; 0..16
        sub  ax,8               ; a drift of -8..8 units
        mov  [vx],ax
        mov  word [vy],0
        mov  byte [thr],0
        mov  byte [sidel],0
        mov  byte [sider],0
        mov  ax,[shipx]
        mov  cl,4
        sar  ax,cl              ; back to whole pixels
        mov  [px],ax
        mov  word [alt],100
        xor  ax,ax
        call SPK_DRONE          ; engine silent
        ret

; ---- MKGROUND: 41 heights by random walk, two flat pads, then per column ----
MKGROUND:
        mov  word [pt],140
        mov  si,2               ; SI = word offset of point 1
.g:     mov  ax,49
        call MTH_RANGE          ; 0..48
        sub  ax,24              ; a step of -24..24
        add  ax,[pt+si-2]       ; from the previous point's height
        mov  bx,110
        mov  cx,185
        call MTH_CLAMP          ; kept between 110 and 185
        mov  [pt+si],ax
        add  si,2
        cmp  si,(NSEG+1)*2
        jb   .g
        mov  ax,10              ; pad 0 (x2): segment 2..11, 4 segments wide
        call MTH_RANGE
        add  ax,2
        mov  si,ax
        mov  cl,3
        shl  ax,cl              ; x0 = segment * 8
        mov  [padx0],ax
        add  ax,32              ; 4 segments = 32 pixels
        mov  [padx1],ax
        mov  cx,4
        call FLAT               ; points SI+1..SI+4 as high as point SI
        mov  ax,18              ; pad 1 (x5): segment 18..35, 3 segments wide
        call MTH_RANGE
        add  ax,18
        mov  si,ax
        mov  cl,3
        shl  ax,cl
        mov  [padx0+2],ax
        add  ax,24              ; 3 segments = 24 pixels
        mov  [padx1+2],ax
        mov  cx,3
        call FLAT
        xor  si,si              ; SI = column x
.x:     mov  bx,si
        mov  cl,3
        shr  bx,cl              ; segment = x / 8
        shl  bx,1               ; as a word offset
        mov  ax,[pt+bx+2]
        sub  ax,[pt+bx]         ; AX = the segment's rise (signed)
        mov  dx,si
        and  dx,7               ; DX = k = x mod 8
        imul dx                 ; DX:AX = rise * k
        mov  cl,3
        sar  ax,cl              ; / 8: how far along the slope
        add  ax,[pt+bx]         ; plus the segment's start height
        mov  [gnd+si],al        ; the column's ground row
        inc  si
        cmp  si,320
        jb   .x
        ret
; FLAT: SI = a point number, CX = how many following points to level with it
FLAT:   shl  si,1               ; word offset
        mov  ax,[pt+si]
.f:     add  si,2
        mov  [pt+si],ax
        loop .f
        ret

; ---- PLAYTICK: thrust, gravity, motion, touchdown -----------------------------
PLAYTICK:
        mov  byte [thr],0
        mov  byte [sidel],0
        mov  byte [sider],0
        add  word [vy],GRAV     ; gravity: vy += 1 (down is positive)
        cmp  word [fuel],0
        je   .moved             ; an empty tank: gravity only
        cmp  byte [key_held+SC_UP],0
        je   .l
        sub  word [vy],THR      ; main thrust: vy -= 3
        mov  byte [thr],1
        sub  word [fuel],3      ; it burns 3 a tick...
        jnc  .l
        mov  word [fuel],0      ; ...but never below 0
.l:     cmp  word [fuel],0
        je   .moved
        cmp  byte [key_held+SC_LF],0
        je   .r
        sub  word [vx],SIDE     ; left thruster: vx -= 1
        mov  byte [sidel],1
        dec  word [fuel]        ; side burn: 1 a tick
.r:     cmp  word [fuel],0
        je   .moved
        cmp  byte [key_held+SC_RT],0
        je   .moved
        add  word [vx],SIDE     ; right thruster: vx += 1
        mov  byte [sider],1
        dec  word [fuel]
.moved: mov  ax,[vx]
        add  [shipx],ax         ; x += vx
        mov  ax,[vy]
        add  [shipy],ax         ; y += vy
        mov  ax,[shipx]
        mov  bx,64              ; keep 4 pixels clear of each side
        mov  cx,5040
        call MTH_CLAMP
        cmp  ax,[shipx]
        je   .xok
        mov  word [vx],0        ; hit the side wall of the sky: stop
.xok:   mov  [shipx],ax
        mov  ax,[shipy]
        mov  bx,160             ; not above pixel row 10
        mov  cx,3200
        call MTH_CLAMP
        cmp  ax,[shipy]
        je   .yok
        mov  word [vy],0        ; the ceiling
.yok:   mov  [shipy],ax
        cmp  byte [thr],0       ; the engine's roar: noise from tick to tick
        je   .quiet
        mov  ax,1500
        call MTH_RANGE          ; 0..1499
        add  ax,2500            ; a divisor 2500..3999: a rumbling note
        jmp  .dr
.quiet: xor  ax,ax              ; no thrust: no drone
.dr:    call SPK_DRONE
        mov  ax,[shipx]
        mov  cl,4
        sar  ax,cl              ; whole pixel x
        mov  [px],ax
        mov  bx,ax
        mov  al,[gnd+bx]        ; ground under the middle
        mov  dl,[gnd+bx-4]      ; under the left foot
        mov  dh,[gnd+bx+4]      ; under the right foot
        cmp  al,dl
        jbe  .m1
        mov  al,dl
.m1:    cmp  al,dh
        jbe  .m2
        mov  al,dh              ; AL = the highest ground of the three
.m2:    xor  ah,ah
        mov  [gtop],ax
        mov  ax,[shipy]
        mov  cl,4
        sar  ax,cl              ; whole pixel y of the feet
        mov  [py],ax
        mov  bx,[gtop]
        sub  bx,ax              ; BX = altitude = ground - feet
        jg   .fly
        xor  bx,bx
        mov  [alt],bx
        jmp  TOUCH              ; (TOUCH returns for us)
.fly:   mov  [alt],bx
        ret

; TOUCH: the feet are in the ground - a landing if all is right, else a crash
TOUCH:  mov  byte [thr],0
        xor  ax,ax
        call SPK_DRONE          ; the engine off
        xor  si,si              ; SI = pad * 2
.p:     mov  ax,[px]
        sub  ax,4               ; the left foot
        cmp  ax,[padx0+si]
        jl   .np
        mov  ax,[px]
        add  ax,4               ; the right foot
        cmp  ax,[padx1+si]
        jg   .np
        jmp  .onpad
.np:    add  si,2
        cmp  si,4
        jb   .p
        jmp  .crash             ; on no pad
.onpad: mov  ax,[vy]
        cmp  ax,VYMAX           ; too fast down?
        jg   .crash
        mov  ax,[vx]
        call MTH_ABS            ; AX = |vx|
        cmp  ax,VXMAX           ; too fast sideways?
        jg   .crash
        mov  ax,[padmul+si]     ; landed: the pad's multiplier...
        mov  [lastmul],ax
        mov  bx,50
        mul  bx                 ; AX = 50 * multiplier
        mov  dx,[fuel]
        mov  cl,3
        shr  dx,cl              ; DX = fuel / 8 as a bonus
        add  ax,dx              ; AX = points
        mov  [lastpts],ax
        add  [score],ax         ; score += points
        mov  ax,[gtop]
        mov  cl,4
        shl  ax,cl              ; the pad's row * 16
        mov  [shipy],ax         ; set down exactly on the pad
        mov  word [vx],0
        mov  word [vy],0
        mov  byte [state],ST_LAND
        mov  word [wcnt],WAITT
        mov  al,SPX_COIN        ; the landing chime
        call SPK_FX
        cmp  byte [auto_res],0
        jne  .r
        mov  byte [auto_res],1  ; /AUTO's first outcome: a landing
        mov  ax,[lastmul]
        mov  [auto_mul],ax
.r:     ret
.crash: dec  byte [lives]       ; a life lost
        mov  byte [state],ST_CRASH
        mov  word [wcnt],WAITT
        mov  word [age],0
        mov  ax,[px]
        mov  [ex],ax            ; where it blows up
        mov  ax,[py]
        mov  [ey],ax
        mov  al,SPX_BOOM        ; the crash
        call SPK_FX
        cmp  byte [auto_res],0
        jne  .r
        mov  byte [auto_res],2  ; /AUTO's first outcome: a crash
        ret

; ---- AUTOKEYS (/AUTO only): a simple autopilot into the key tables ------------
AUTOKEYS:
        mov  byte [key_held+SC_UP],0
        mov  byte [key_held+SC_LF],0
        mov  byte [key_held+SC_RT],0
        cmp  byte [state],ST_PLAY
        je   .play
        cmp  byte [state],ST_TITLE
        jne  .r
        cmp  word [ticks],5     ; the title seen for 5 ticks: Enter
        jb   .r
        mov  byte [key_hit+SC_ENTER],1
.r:     ret
.play:  inc  word [aplay]
        cmp  word [aplay],AUTOMAX
        jb   .go
        mov  byte [finish],1    ; no outcome in time: stop anyway
        ret
.go:    mov  ax,[padx0]         ; pad 0's middle
        add  ax,[padx1]
        shr  ax,1
        sub  ax,[px]            ; AX = how far across it is
        mov  bx,ax
        mov  ax,[padx0+2]       ; pad 1's middle
        add  ax,[padx1+2]
        shr  ax,1
        sub  ax,[px]
        mov  cx,ax
        mov  ax,bx
        call MTH_ABS
        mov  dx,ax              ; DX = |distance to pad 0|
        mov  ax,cx
        call MTH_ABS            ; AX = |distance to pad 1|
        cmp  dx,ax
        jle  .near
        mov  bx,cx              ; pad 1 is nearer: aim at it
.near:  mov  [tdx],bx
        mov  ax,bx
        call MTH_ABS
        mov  [tabs],ax
        call MTH_SQRT           ; AX = sqrt |distance|
        shl  ax,1
        shl  ax,1               ; * 4: the speed that can still be stopped
        cmp  word [tdx],0
        jge  .sg
        neg  ax                 ; the pad is to the left
.sg:    mov  dx,[vx]
        sub  dx,ax              ; DX = speed now - wanted speed
        cmp  dx,1
        jle  .nl
        mov  byte [key_held+SC_LF],1 ; too fast right: push left
.nl:    cmp  dx,-1
        jge  .nr
        mov  byte [key_held+SC_RT],1 ; too slow: push right
.nr:    mov  ax,[alt]
        call MTH_SQRT           ; AX = sqrt altitude
        mov  bx,ax
        shl  ax,1
        add  ax,bx              ; * 3
        add  ax,3               ; wanted fall speed: slow near the ground
        cmp  word [tabs],16
        jle  .vy
        cmp  word [alt],50
        jge  .vy
        xor  ax,ax              ; far from the pad and low: hold the height
.vy:    mov  dx,[vy]
        cmp  dx,ax
        jle  .x
        mov  byte [key_held+SC_UP],1 ; falling too fast: burn
.x:     ret

; ---- DRAW: the picture into the back buffer ----------------------------------
DRAW:   push es
        mov  es,[vga_buf]       ; ES = the buffer
        xor  al,al
        call VGA_CLS            ; black sky
        cmp  byte [state],ST_TITLE
        je   .title
        call DRAWWORLD
        cmp  byte [state],ST_OVER
        je   .over
        cmp  byte [state],ST_LAND
        je   .land
        cmp  byte [state],ST_CRASH
        jne  .x
        cmp  word [age],6
        jb   .x
        mov  si,t_crash         ; CRASHED over the wreck
        mov  bx,160
        mov  dx,60
        mov  byte [txt_col],12
        mov  byte [txt_boxc],4
        call TXT_BOX
        jmp  .x
.land:  mov  si,t_landed        ; LANDED +points
        mov  bx,108
        mov  dx,60
        mov  byte [txt_col],10
        call TXT_PUT
        mov  ax,[lastpts]
        call TXT_NUM
        jmp  .x
.over:  mov  si,t_over
        mov  bx,160
        mov  dx,70
        mov  byte [txt_col],12
        mov  byte [txt_boxc],4
        call TXT_BOX
        mov  si,t_final
        mov  bx,100
        mov  dx,92
        mov  byte [txt_col],15
        call TXT_PUT
        mov  ax,[score]
        call TXT_NUM
        jmp  .x
.title: mov  byte [txt_scale],2
        mov  byte [txt_col],14
        mov  si,t_name
        mov  bx,160
        mov  dx,36
        call TXT_CENTER
        mov  byte [txt_scale],1
        mov  byte [txt_col],7
        mov  si,t_k1
        mov  dx,86
        call TXT_CENTER
        mov  si,t_k2
        mov  dx,100
        call TXT_CENTER
        mov  si,t_k3
        mov  dx,114
        call TXT_CENTER
        mov  byte [txt_col],15
        mov  si,t_enter
        mov  dx,140
        call TXT_CENTER
.x:     pop  es
        ret

; DRAWWORLD: ground, pads, ship or explosion, HUD
DRAWWORLD:
        xor  si,si              ; SI = column
.g:     mov  ax,si
        mov  bl,[gnd+si]
        xor  bh,bh              ; BX = the ground's top row
        mov  cx,200
        sub  cx,bx              ; CX = rows from there to the bottom
        mov  byte [drw_col],8   ; dark grey rock
        call DRW_VLINE
        mov  cx,1
        mov  byte [drw_col],7   ; a light edge on top
        call DRW_VLINE
        inc  si
        cmp  si,320
        jb   .g
        xor  si,si              ; SI = pad * 2
.pd:    mov  ax,[padx0+si]
        mov  bx,ax
        mov  bl,[gnd+bx]
        xor  bh,bh              ; BX = the pad's row
        mov  cx,[padx1+si]
        sub  cx,ax              ; CX = its width
        mov  dx,3
        mov  byte [drw_col],10  ; green pad
        call DRW_RECT
        push cx
        push bx
        mov  byte [txt_col],14
        mov  bx,ax
        add  bx,8               ; the multiplier a little in from the left
        pop  dx
        sub  dx,10              ; above the pad
        push si
        mov  si,[padtxt+si]
        call TXT_PUT
        pop  si
        pop  cx
        add  si,2
        cmp  si,4
        jb   .pd
        cmp  byte [state],ST_CRASH
        je   .boom
        mov  ax,[px]
        mov  cl,4
        mov  bx,[shipy]
        sar  bx,cl
        mov  [py],bx            ; feet row now
        sub  ax,4
        mov  bx,ax              ; sprite left x = px - 4
        mov  dx,[py]
        sub  dx,8               ; sprite top y = feet - 8
        mov  si,ship_c
        call SPR_DRAW
        cmp  byte [thr],0
        je   .sl
        mov  ax,[px]
        dec  ax                 ; the flame under the ship, 3 wide
        mov  bx,[py]
        mov  dx,[ticks]
        and  dx,3
        add  dx,3               ; 3..6 rows, flickering
        mov  cx,3
        mov  byte [drw_col],14
        call DRW_RECT
        mov  byte [drw_col],12
        mov  cx,1
        inc  ax
        sub  dx,2
        call DRW_RECT           ; a red core
.sl:    cmp  byte [sidel],0
        je   .sr
        mov  ax,[px]
        add  ax,5               ; pushing left: flame on the right side
        mov  bx,[py]
        sub  bx,4
        mov  cx,3
        mov  dx,2
        mov  byte [drw_col],14
        call DRW_RECT
.sr:    cmp  byte [sider],0
        je   .hud
        mov  ax,[px]
        sub  ax,7               ; pushing right: flame on the left side
        mov  bx,[py]
        sub  bx,4
        mov  cx,3
        mov  dx,2
        mov  byte [drw_col],14
        call DRW_RECT
        jmp  .hud
.boom:  cmp  word [age],30      ; the fireball lives about 30 ticks
        jae  .hud
        mov  ax,[ex]
        mov  bx,[ey]
        sub  bx,4
        mov  cx,[age]
        shr  cx,1
        add  cx,2               ; red outer disc
        mov  byte [drw_col],4
        call DRW_DISC
        mov  cx,[age]
        mov  dx,cx
        shr  cx,1
        shr  dx,1
        shr  dx,1
        add  cx,dx              ; about age * 3/4 ... of a half: orange
        shr  cx,1
        inc  cx
        mov  byte [drw_col],12
        call DRW_DISC
        mov  cx,[age]
        shr  cx,1
        shr  cx,1
        inc  cx
        mov  byte [drw_col],14  ; yellow heart
        call DRW_DISC
        mov  cx,16              ; sparks flying about
.sp:    push cx
        mov  ax,[age]
        shl  ax,1
        add  ax,6               ; spread = 2 * age + 6
        mov  si,ax
        shl  ax,1
        inc  ax                 ; 2 * spread + 1 possible offsets
        call MTH_RANGE
        sub  ax,si
        add  ax,[ex]            ; spark x
        push ax
        mov  ax,si
        shl  ax,1
        inc  ax
        call MTH_RANGE
        sub  ax,si
        add  ax,[ey]
        sub  ax,4               ; spark y
        mov  bx,ax
        pop  ax
        mov  byte [drw_col],15
        call DRW_PIXEL
        pop  cx
        loop .sp
.hud:   mov  byte [txt_col],15  ; line 1: fuel, score, lives
        mov  si,t_fuel
        mov  bx,4
        mov  dx,2
        cmp  word [fuel],200
        jae  .f1
        mov  byte [txt_col],12  ; a nearly empty tank in red
.f1:    call TXT_PUT
        mov  ax,[fuel]
        call TXT_NUM
        mov  byte [txt_col],15
        mov  si,t_score
        add  bx,8
        call TXT_PUT
        mov  ax,[score]
        call TXT_NUM
        mov  si,t_lives
        add  bx,8
        call TXT_PUT
        mov  al,[lives]
        xor  ah,ah
        call TXT_NUM
        mov  si,t_level
        add  bx,8
        call TXT_PUT
        mov  ax,[level]
        call TXT_NUM
        mov  byte [txt_col],15  ; line 2: speeds and altitude
        mov  si,t_vx
        mov  bx,4
        mov  dx,12
        mov  ax,[vx]
        call MTH_ABS
        cmp  ax,VXMAX
        jle  .v1
        mov  byte [txt_col],12  ; too fast sideways: red
.v1:    call TXT_PUT
        mov  ax,[vx]
        call TXT_SNUM
        mov  byte [txt_col],15
        mov  si,t_vy
        add  bx,8
        cmp  word [vy],VYMAX
        jle  .v2
        mov  byte [txt_col],12  ; too fast down: red
.v2:    call TXT_PUT
        mov  ax,[vy]
        call TXT_SNUM
        mov  byte [txt_col],15
        mov  si,t_alt
        add  bx,8
        call TXT_PUT
        mov  ax,[alt]
        call TXT_NUM
        ret

; ---- REPORT (/AUTO): what happened, by DOS's output ----------------------------
REPORT: mov  si,t_rep
        call TXT_DOSZ
        call TXT_DOSCR
        cmp  byte [auto_res],1
        je   .landed
        cmp  byte [auto_res],2
        je   .crashed
        mov  si,t_none
        call TXT_DOSZ
        jmp  .nl
.landed:mov  si,t_lx
        call TXT_DOSZ
        mov  ax,[auto_mul]
        call TXT_DOSNUM
        mov  si,t_pad
        call TXT_DOSZ
        jmp  .nl
.crashed:
        mov  si,t_crashed
        call TXT_DOSZ
.nl:    call TXT_DOSCR
        mov  si,t_sc
        call TXT_DOSZ
        mov  ax,[score]
        call TXT_DOSNUM
        call TXT_DOSCR
        mov  si,t_lv
        call TXT_DOSZ
        mov  al,[lives]
        xor  ah,ah
        call TXT_DOSNUM
        mov  si,t_lvl
        call TXT_DOSZ
        mov  ax,[level]
        call TXT_DOSNUM
        call TXT_DOSCR
        mov  si,t_tk
        call TXT_DOSZ
        mov  ax,[ticks]
        call TXT_DOSNUM
        call TXT_DOSCR
        ret

; ---- GETAUTO: [auto] = 1 if the command line holds /AUTO -----------------------
GETAUTO:mov  si,81h
        xor  ch,ch
        mov  cl,[80h]           ; the tail's length
.s:     jcxz .no
        lodsb
        dec  cx
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

; ---- data ------------------------------------------------------------------------
ship_t  db 9,8                  ; the lander, 9 x 8 (text art, BIOS colours)
        db '....7....'
        db '...777...'
        db '..77B77..'
        db '..77777..'
        db '.F77777F.'
        db '.F77777F.'
        db 'F.C...C.F'
        db 'FF.....FF'

state   db ST_TITLE
lives   db 0
score   dw 0
level   dw 0
fuel    dw 0
shipx   dw 0                    ; 1/16 pixel
shipy   dw 0
vx      dw 0
vy      dw 0
px      dw 160                  ; whole pixels
py      dw 0
alt     dw 100
gtop    dw 0
thr     db 0
sidel   db 0
sider   db 0
wcnt    dw 0
age     dw 0
ex      dw 0
ey      dw 0
cardclk dw 0
ticks   dw 0
lastmul dw 0
lastpts dw 0
padx0   dw 0,0
padx1   dw 0,0
padmul  dw 2,5
padtxt  dw t_x2,t_x5
pt      dw NSEG+1 dup(0)
gnd     db 320 dup(0)
; /AUTO
auto    db 0
finish  db 0
doshot  db 0
auto_res db 0
auto_mul dw 0
aplay   dw 0
tdx     dw 0
tabs    dw 0
; words
t_name  db 'LUNAR LANDER',0
t_k1    db 'UP  MAIN THRUSTER',0
t_k2    db 'LEFT / RIGHT  SIDE THRUSTERS',0
t_k3    db 'LAND SOFTLY ON A PAD: X2 OR X5',0
t_enter db 'ENTER PLAYS   ESC QUITS',0
t_over  db 'GAME OVER',0
t_final db 'FINAL SCORE ',0
t_crash db 'CRASHED',0
t_landed db 'LANDED! +',0
t_fuel  db 'FUEL ',0
t_score db 'SCORE ',0
t_lives db 'LIVES ',0
t_level db 'LV ',0
t_vx    db 'VX ',0
t_vy    db 'VY ',0
t_alt   db 'ALT ',0
t_x2    db 'X2',0
t_x5    db 'X5',0
t_rep   db 'LANDB /AUTO REPORT',0
t_none  db 'no landing or crash in time',0
t_lx    db 'landed on x',0
t_pad   db ' pad',0
t_crashed db 'crashed',0
t_sc    db 'score ',0
t_lv    db 'lives left ',0
t_lvl   db '  level ',0
t_tk    db 'ticks run ',0
t_nomem db 'Not enough memory for the screen buffer.',13,10,'$'
ship_c  db 2+9*8 dup(0)

        include '..\..\KIT\LIB\K_MEM.INC'
        include '..\..\KIT\LIB\K_VGA.INC'
        include '..\..\KIT\LIB\K_KEYS.INC'
        include '..\..\KIT\LIB\K_TIME.INC'
        include '..\..\KIT\LIB\K_MATH.INC'
        include '..\..\KIT\LIB\K_DRAW.INC'
        include '..\..\KIT\LIB\K_TEXT.INC'
        include '..\..\KIT\LIB\K_SPR.INC'
        include '..\..\KIT\LIB\K_SPK.INC'
        include '..\SHOT.INC'
