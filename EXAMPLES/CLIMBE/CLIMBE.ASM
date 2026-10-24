; ============================================================================
;  CLIMBE.ASM - FLAT CLIMB, EGA. A burglar climbs the front of a tall block
;  of flats looking for windows that open. Things come flying out of the open
;  ones - bottles, bricks, hammers. He dodges sideways or he does not: a hit
;  flashes BOOM! / BAM! / CLANK! and he falls down the front. Three lives,
;  then GAME OVER with the score and the height reached.
;  The picture: KIT's K_D4 draws into a four-bits-a-pixel frame, K_CARD sends
;  what changed to the EGA (640x200 mode 0Eh if the card has it, else 0Dh).
;  Keys: arrows (up climbs, down slowly, left and right), Enter, Esc.
;  /AUTO: climbs without dodging, takes one SHOT_SAVE when the word is up,
;  prints a few lines and quits by itself.
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

AUTOT    = 150                  ; /AUTO: ticks of play, then the way out
AUTOSEED = 1234                 ; /AUTO: the same game every run
LIVES0   = 3
BURGX0   = 152                  ; the burglar's start column (even)
GROUND   = 1576                 ; his top row on the street (1600 - 24)
BUILDB   = 1600                 ; the building's bottom row, world
CAMHOLD  = 150                  ; his screen row while the building scrolls
NOBJ     = 6                    ; things in the air at once
WORDT    = 24                   ; ticks a hit word stays up
CARDT    = 36                   ; game over card: ticks before a key counts
ST_TITLE = 0
ST_PLAY  = 1
ST_OVER  = 2

; ---- the start: the card, the frame, the keys, the game's seed --------------
start:  call GETAUTO            ; [auto] = 1 with /AUTO
        call CRD_DETECT         ; which card: [crd_card], 0 = none
        cmp  byte [crd_card],0
        je   nocard
        call CRD_MEM            ; the 4bpp frame, from DOS
        jc   nomem
        mov  ax,[crd_buf]       ; the frame's segment
        mov  bl,[crd_wide]      ; 1: EGA 640, a column a byte
        call D4_INIT            ; drawing tables for that frame
        call CRD_SET            ; the mode up, cleared
        jc   nomode
        call KEY_ON             ; our keyboard, last
        call MTH_SEED           ; a different game each run...
        cmp  byte [auto],0
        je   .seed
        mov  word [mth_seed],AUTOSEED ; ...but the test plays the same one
.seed:  call TIM_STEPS          ; start the tick count
        mov  byte [state],ST_TITLE
        cmp  byte [auto],0
        je   frame
        call NEWGAME            ; /AUTO starts at once

; ---- the loop: ticks -> rules once a tick -> draw -> show what changed -----
frame:  mov  al,SC_ESC
        call KEY_TAP            ; Esc: out by the one way
        jnz  quit
        cmp  byte [auto],0
        je   .run
        cmp  word [ticks],AUTOT ; /AUTO: played long enough?
        jae  quit
.run:   call TIM_STEPS          ; AX = ticks gone by
        mov  cx,ax
        jcxz .draw
.step:  call STEP               ; the rules, once a tick (keeps CX)
        loop .step
.draw:  call DRAW
        call CRD_BLIT           ; what changed, onto the card
        call SHOTCHK            ; /AUTO: the one screen to keep
        jmp  frame

; ---- the one way out: every layer given back, then the words --------------
quit:   call SPK_STOP           ; silence first
        call KEY_OFF            ; the BIOS keyboard back
        call CRD_RESET          ; text mode again
        cmp  byte [auto],0
        je   .bye
        call REPORT             ; the /AUTO lines
.bye:   mov  ax,4C00h
        int  21h

nocard: mov  dx,t_nocard
        jmp  dosmsg
nomem:  mov  dx,t_nomem
        jmp  dosmsg
nomode: mov  dx,t_nomode
dosmsg: mov  ah,9
        int  21h
        mov  ax,4C01h           ; errorlevel 1: it did not run
        int  21h

; ---- STEP: one tick of the game, by the state. Keeps every register -------
STEP:   push ax
        push bx
        push cx
        push dx
        push si
        push di
        inc  word [ticks]       ; the game's clock: one more tick
        call SPK_TICK           ; the speaker's effect, one tick on
        cmp  byte [state],ST_PLAY
        je   .play
        cmp  byte [state],ST_OVER
        je   .over
        cmp  byte [auto],0      ; the title: /AUTO starts at once
        jne  .go
        mov  al,SC_ENTER
        call KEY_TAP            ; Enter starts a game
        jz   .done
.go:    call NEWGAME
        jmp  .done
.over:  cmp  word [cardclk],0
        je   .ok
        dec  word [cardclk]     ; the card holds for a little
        jmp  .done
.ok:    mov  al,SC_ENTER
        call KEY_TAP
        jz   .done
        mov  byte [state],ST_TITLE
        jmp  .done
.play:  call PLAYTICK           ; the burglar: keys, climbing, windows
        call OBJTICK            ; the things in the air, and their hits
        call SPAWN              ; a new thing thrown, now and then
        cmp  word [wordt],0     ; a hit word counts down
        je   .done
        dec  word [wordt]
.done:  pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; ---- NEWGAME: score 0, lives full, the street, nothing in the air ----------
NEWGAME:
        mov  word [score],0
        mov  byte [lives],LIVES0
        mov  word [burx],BURGX0
        mov  word [burw],GROUND
        mov  word [burvy],0
        mov  byte [fall],0
        mov  word [maxfl],1
        mov  word [wordt],0
        mov  byte [state],ST_PLAY
        xor  si,si              ; clear the things in the air
.c:     mov  byte [ob_on+si],0
        inc  si                 ; the next slot
        cmp  si,NOBJ
        jb   .c
        xor  si,si              ; clear which windows were entered
.t:     mov  byte [tk+si],0
        inc  si                 ; the next window
        cmp  si,160
        jb   .t
        ret

; ---- PLAYTICK: one tick of the burglar -----------------------------------
PLAYTICK:
        cmp  byte [fall],0
        je   .ctl
        call FALLTICK           ; he is falling: the fall, no keys
        ret
.ctl:   mov  al,SC_LF           ; left and right: two columns a tick
        call KEY_HELD
        jz   .r
        sub  word [burx],2      ; left: x - 2
.r:     mov  al,SC_RT
        call KEY_HELD
        jz   .lim
        add  word [burx],2      ; right: x + 2
.lim:   cmp  word [burx],0      ; keep him on the front
        jge  .hi
        mov  word [burx],0
.hi:    cmp  word [burx],304
        jle  .vert
        mov  word [burx],304
.vert:  cmp  byte [auto],0      ; /AUTO climbs without a key pressed
        jne  .climb
        mov  al,SC_UP
        call KEY_HELD
        jnz  .climb
        mov  al,SC_DN           ; down, slowly: a row a tick
        call KEY_HELD
        jz   .win
        inc  word [burw]        ; down: y + 1
        cmp  word [burw],GROUND
        jle  .win
        mov  word [burw],GROUND ; not below the street
        jmp  .win
.climb: sub  word [burw],2      ; up: y - 2, two rows a tick
        cmp  word [burw],0
        jge  .st
        mov  word [burw],0      ; the roof
.st:    test word [burw],0Fh    ; a step sound every 16 rows
        jnz  .anim
        mov  al,SPX_CLICK
        call SPK_FX
.anim:  mov  ax,[ticks]         ; the legs swap every four ticks
        shr  ax,1               ; ticks / 2
        shr  ax,1               ; ticks / 4
        and  ax,1               ; 0 or 1
        mov  [burfr],al
.win:   call WINCHECK           ; the windows he is at, and the height
        ret

; ---- FALLTICK: he has been hit; he falls down the front -------------------
FALLTICK:
        cmp  word [burvy],14    ; the fall speeds up, to 14 rows a tick
        jge  .f1
        inc  word [burvy]       ; one row a tick faster
.f1:    mov  ax,[burvy]
        add  [burw],ax          ; down: y + speed
        cmp  word [burw],GROUND
        jle  .r
        mov  word [burw],GROUND ; the street
        mov  byte [fall],0
        mov  word [burx],BURGX0
        dec  byte [lives]       ; one life less
        jz   .over
        mov  al,SPX_ALARM       ; the fall ends with a warble
        call SPK_FX
.r:     ret
.over:  mov  byte [state],ST_OVER
        mov  word [cardclk],CARDT
        mov  al,SPX_OVER
        call SPK_FX
        ret

; ---- WINCHECK: the floor he is on, the height score, the open windows -----
WINCHECK:
        mov  ax,GROUND
        sub  ax,[burw]          ; rows up from the street
        jge  .pos
        xor  ax,ax
.pos:   xor  dx,dx
        mov  cx,40
        div  cx                 ; AX = the floor under his head (0 = street)
        mov  [tmpk],ax
        inc  ax                 ; the floor's number: 1 = street
        mov  [flrnow],ax
        cmp  ax,[maxfl]
        jle  .w0
        sub  ax,[maxfl]         ; floors gained since the top
        mov  dx,10
        mul  dx                 ; 10 points for each new floor
        add  [score],ax
        mov  ax,[flrnow]
        mov  [maxfl],ax
.w0:    mov  word [tmpj],0      ; his floor, then the one above
.kl:    mov  ax,[tmpk]
        add  ax,[tmpj]          ; floor = his floor + j
        cmp  ax,39
        ja   .kn
        mov  [tmpkk],ax
        mov  word [tmpi],0
.il:    mov  bx,[tmpkk]
        mov  cx,[tmpi]
        call ISOPEN             ; AL = 1 if that window is open
        or   al,al
        jz   .in
        mov  ax,[tmpkk]         ; window number = floor * 4 + window
        shl  ax,1
        shl  ax,1               ; * 4
        add  ax,[tmpi]
        mov  si,ax
        cmp  byte [tk+si],0     ; entered already?
        jne  .in
        call WINHIT             ; CF = 1: he is at this window
        jnc  .in
        mov  byte [tk+si],1     ; he is in: this one is his
        add  word [score],100   ; 100 points for a window entered
        inc  word [entered]
.in:    inc  word [tmpi]        ; the next window of the floor
        cmp  word [tmpi],4
        jb   .il
.kn:    inc  word [tmpj]
        cmp  word [tmpj],2
        jb   .kl
        ret

; ---- ISOPEN: is window BX (floor) CX (0..3) open? AL = 1 open --------------
ISOPEN: mov  ax,bx              ; AX = the floor
        mov  dx,3
        mul  dx                 ; 3 * floor
        mov  si,ax
        mov  ax,cx              ; AX = the window
        mov  dx,5
        mul  dx                 ; 5 * window
        add  si,ax              ; 3 * floor + 5 * window
        mov  ax,bx
        mov  dx,cx
        mul  dx                 ; floor * window
        add  ax,si              ; a mix of the two
        and  ax,3               ; 0..3: one in four is open
        cmp  ax,1
        mov  al,0
        jne  .o
        mov  al,1
.o:     ret

; ---- WINHIT: does the burglar's box touch window [tmpkk], [tmpi]? CF = yes -
WINHIT: mov  ax,[tmpi]
        mov  dx,72
        mul  dx                 ; 72 * window
        add  ax,36              ; its left column
        mov  dx,ax              ; DX = the window's left
        mov  ax,[burx]
        add  ax,16              ; his right edge
        cmp  dx,ax
        jge  .no
        mov  ax,dx
        add  ax,40              ; the window's right edge
        cmp  ax,[burx]
        jle  .no
        mov  ax,[tmpkk]
        mov  dx,40
        mul  dx                 ; 40 * floor
        mov  dx,1560
        sub  dx,ax              ; the floor's top, world row
        add  dx,8               ; the window's top
        mov  ax,dx
        add  ax,20              ; the window's bottom
        cmp  ax,[burw]
        jle  .no
        mov  ax,[burw]
        add  ax,24              ; his bottom
        cmp  dx,ax
        jge  .no
        stc
        ret
.no:    clc
        ret

; ---- SPAWN: now and then, a thing comes out of an open window ------------
SPAWN:  cmp  byte [fall],0
        jne  SPNO
        mov  ax,[ticks]
        and  ax,7               ; one roll in eight ticks
        jnz  SPNO
        xor  di,di              ; a free slot
.f:     cmp  byte [ob_on+di],0
        je   .got
        inc  di
        cmp  di,NOBJ
        jb   .f
        jmp  SPNO
.got:   mov  [tmps],di
        mov  ax,GROUND
        sub  ax,[burw]          ; rows up from the street
        jge  .p2
        xor  ax,ax
.p2:    xor  dx,dx
        mov  cx,40
        div  cx                 ; AX = his floor
        mov  [tmpk],ax
        mov  ax,5
        call MTH_RANGE          ; 0..4
        add  ax,[tmpk]          ; a floor near him
        sub  ax,2               ; from two below to two above
        jge  .p3
        xor  ax,ax
.p3:    cmp  ax,39
        jbe  .p4
        mov  ax,39
.p4:    mov  [tmpk],ax
        mov  ax,4
        call MTH_RANGE          ; a window, 0..3
        mov  [tmpi],ax
        mov  bx,[tmpk]
        mov  cx,[tmpi]
        call ISOPEN             ; only from an open one
        or   al,al
        jz   SPNO
        mov  ax,[tmpi]
        mov  dx,72
        mul  dx                 ; 72 * window
        add  ax,54              ; window's left (36) + 18: the throw's column
        mov  [tmpx],ax
        mov  ax,[tmpk]
        mov  dx,40
        mul  dx                 ; 40 * floor
        mov  dx,1574
        sub  dx,ax              ; the row it leaves from
        mov  [tmpy],dx
        mov  ax,[burx]
        add  ax,8               ; his middle
        sub  ax,[tmpx]          ; the distance to him, signed
        cwd                     ; DX:AX
        mov  cx,12
        idiv cx                 ; AX = distance / 12
        and  ax,0FFFEh          ; even: whole columns
        cmp  ax,6
        jle  .v1
        mov  ax,6               ; at most six columns a tick
.v1:    cmp  ax,-6
        jge  .v2
        mov  ax,-6
.v2:    mov  [tmpvx],ax
        mov  ax,3
        call MTH_RANGE          ; the kind: 0 bottle, 1 brick, 2 hammer
        mov  [tmpkind],al
        mov  di,[tmps]
        mov  byte [ob_on+di],1
        mov  al,[tmpkind]
        mov  [ob_kd+di],al
        mov  bx,di
        shl  bx,1               ; word index of the slot
        mov  ax,[tmpx]
        mov  [ob_x+bx],ax
        mov  ax,[tmpy]
        mov  [ob_y+bx],ax
        mov  ax,[tmpvx]
        mov  [ob_vx+bx],ax
        mov  word [ob_vy+bx],-4 ; thrown up first
        inc  word [spawned]
        mov  al,SPX_JUMP        ; the whoosh of a throw
        call SPK_FX
SPNO:   ret

; ---- OBJTICK: the things in the air move; one that touches him hits ------
OBJTICK:
        xor  di,di
.o:     cmp  byte [ob_on+di],0
        je   .n
        mov  bx,di
        shl  bx,1               ; word index of this slot
        cmp  word [ob_vy+bx],10
        jge  .g
        inc  word [ob_vy+bx]    ; gravity: one row a tick more, up to ten
.g:     mov  ax,[ob_vx+bx]
        add  [ob_x+bx],ax       ; sideways
        mov  ax,[ob_vy+bx]
        add  [ob_y+bx],ax       ; down (up at first)
        mov  ax,[ob_y+bx]
        cmp  ax,BUILDB+60
        jg   .kill
        mov  ax,[ob_x+bx]
        cmp  ax,-40
        jl   .kill
        cmp  ax,360
        jg   .kill
        cmp  byte [state],ST_PLAY
        jne  .n
        cmp  byte [fall],0
        jne  .n
        call HITTEST            ; CF = it touches him
        jnc  .n
        mov  byte [ob_on+di],0  ; the thing is gone
        call HITBURG
        jmp  .n
.kill:  mov  byte [ob_on+di],0
.n:     inc  di                 ; the next slot
        cmp  di,NOBJ
        jb   .o
        ret

; ---- HITTEST: the thing in slot BX/2 against his box. CF = touching -------
HITTEST:
        mov  ax,[ob_x+bx]
        mov  dx,[burx]
        add  dx,16              ; his right edge
        cmp  ax,dx
        jge  .no
        add  ax,8               ; the thing's right edge (8 wide)
        cmp  ax,[burx]
        jle  .no
        mov  ax,[ob_y+bx]
        mov  dx,[burw]
        add  dx,24              ; his bottom
        cmp  ax,dx
        jge  .no
        add  ax,9               ; the thing's bottom (9 high)
        cmp  ax,[burw]
        jle  .no
        stc
        ret
.no:    clc
        ret

; ---- HITBURG: slot DI hit him: the word, the sound, the fall --------------
HITBURG:
        push bx
        push di
        mov  al,[ob_kd+di]      ; which thing: 0 bottle, 1 brick, 2 hammer
        mov  [wordi],al         ; its word: BOOM, BAM, CLANK
        mov  [hitkind],al
        inc  byte [hitn]
        mov  byte [fall],1
        mov  word [burvy],0     ; the fall starts slow
        mov  word [wordt],WORDT
        mov  al,SPX_HIT         ; the hit: a low thump
        cmp  byte [hitkind],0
        jne  .s
        mov  al,SPX_BOOM        ; the bottle: the rumble
.s:     call SPK_FX
        pop  di
        pop  bx
        ret

; ---- DRAW: by the state -----------------------------------------------------
DRAW:   cmp  byte [state],ST_TITLE
        jne  .n1
        jmp  DRAW_TITLE
.n1:    cmp  byte [state],ST_OVER
        jne  .play
        jmp  DRAW_OVER
.play:  call CAMSET
        call DRAW_SCENE
        call DRAW_OBJS
        call DRAW_BURG
        call DRAW_HUD
        call DRAW_WORD
        ret

; ---- CAMSET: the building's row on the top of the screen -------------------
CAMSET: mov  ax,[burw]
        sub  ax,CAMHOLD         ; he stays on row 150; the front moves
        jge  .c
        xor  ax,ax              ; the roof is in view: no higher
.c:     mov  [camy],ax
        ret

; ---- DRAW_SCENE: the sky, the front of the block, the floors, the street ---
DRAW_SCENE:
        mov  bx,0
        mov  dx,0
        mov  cx,320
        mov  si,200
        mov  al,1               ; the night sky
        call D4_FILL
        mov  bx,0
        mov  dx,[camy]
        neg  dx                 ; the roof's row on the screen: 0 - camy
        mov  cx,320
        mov  si,BUILDB
        mov  al,6               ; the brick front
        call D4_FILL
        mov  word [tmpk],0      ; every floor, from the street up
.fl:    mov  ax,[tmpk]
        mov  dx,40
        mul  dx                 ; 40 * floor: a floor is 40 rows
        mov  dx,1560
        sub  dx,ax              ; the floor's top, world
        sub  dx,[camy]          ; on the screen
        mov  [tmpys],dx
        cmp  dx,200
        jge  .fs                ; below the screen: not drawn
        mov  ax,dx
        add  ax,40              ; its bottom on the screen
        cmp  ax,0
        jle  .fs                ; above it: not drawn
        call DRAW_FLOOR
.fs:    inc  word [tmpk]
        cmp  word [tmpk],40
        jb   .fl
        mov  bx,0
        mov  dx,BUILDB
        sub  dx,[camy]          ; the street, under the building
        mov  cx,320
        mov  si,200
        mov  al,8               ; dark grey pavement
        call D4_FILL
        ret

; ---- DRAW_FLOOR: floor [tmpk] at screen row [tmpys]: ledge and 4 windows ---
DRAW_FLOOR:
        mov  bx,0
        mov  dx,[tmpys]
        add  dx,36              ; the ledge at the floor's foot
        mov  cx,320
        mov  si,4
        mov  al,7
        call D4_FILL
        mov  word [tmpi],0
.w:     mov  ax,[tmpi]
        mov  dx,72
        mul  dx                 ; 72 * window
        add  ax,36              ; its left column
        mov  [tmpwx],ax
        mov  bx,ax
        sub  bx,2               ; the frame, two columns out
        mov  dx,[tmpys]
        add  dx,6
        mov  cx,44
        mov  si,24
        mov  al,15              ; white frame
        call D4_FILL
        mov  bx,[tmpk]
        mov  cx,[tmpi]
        call ISOPEN
        mov  [tmpop],al
        mov  ax,[tmpk]
        shl  ax,1
        shl  ax,1               ; floor * 4
        add  ax,[tmpi]
        mov  si,ax
        mov  byte [tmpcol],9    ; closed glass: light blue
        cmp  byte [tmpop],0
        je   .g
        mov  byte [tmpcol],0    ; open: a dark room
        cmp  byte [tk+si],0
        je   .g
        mov  byte [tmpcol],8    ; open, and he has been in
.g:     mov  bx,[tmpwx]
        mov  dx,[tmpys]
        add  dx,8               ; the glass, under the frame's top
        mov  cx,40
        mov  si,20
        mov  al,[tmpcol]
        call D4_FILL
        cmp  byte [tmpop],0
        jne  .o
        mov  bx,[tmpwx]         ; closed: a cross bar
        mov  dx,[tmpys]
        add  dx,17
        mov  cx,40
        mov  si,2
        mov  al,15
        call D4_FILL
        jmp  .nx
.o:     mov  bx,[tmpwx]         ; open: a lit strip at the top
        mov  dx,[tmpys]
        add  dx,8
        mov  cx,40
        mov  si,3
        mov  al,14
        call D4_FILL
.nx:    inc  word [tmpi]        ; the next window
        cmp  word [tmpi],4
        jb   .w
        ret

; ---- DRAW_OBJS: the things in the air, one picture each --------------------
DRAW_OBJS:
        xor  di,di
.o:     cmp  byte [ob_on+di],0
        je   .n
        mov  bx,di
        shl  bx,1               ; word index
        mov  ax,[ob_x+bx]
        mov  [tmpx],ax
        mov  ax,[ob_y+bx]
        sub  ax,[camy]          ; on the screen
        mov  [tmpys],ax
        cmp  byte [ob_kd+di],1
        je   .brick
        jb   .bottle
        mov  bx,[tmpx]          ; a hammer: head, and the handle
        mov  dx,[tmpys]
        mov  cx,6
        mov  si,3
        mov  al,8
        call D4_FILL
        mov  bx,[tmpx]
        add  bx,2               ; the handle, in the middle
        mov  dx,[tmpys]
        add  dx,3
        mov  cx,2
        mov  si,6
        mov  al,6
        call D4_FILL
        jmp  .n
.brick: mov  bx,[tmpx]          ; a brick: red, with a mortar line
        mov  dx,[tmpys]
        mov  cx,8
        mov  si,5
        mov  al,4
        call D4_FILL
        mov  bx,[tmpx]
        mov  dx,[tmpys]
        add  dx,2
        mov  cx,8
        mov  si,1
        mov  al,6
        call D4_FILL
        jmp  .n
.bottle:mov  bx,[tmpx]          ; a bottle: the neck, and the green body
        add  bx,2
        mov  dx,[tmpys]
        mov  cx,2
        mov  si,3
        mov  al,2
        call D4_FILL
        mov  bx,[tmpx]
        mov  dx,[tmpys]
        add  dx,3
        mov  cx,4
        mov  si,6
        mov  al,10
        call D4_FILL
.n:     inc  di                 ; the next slot
        cmp  di,NOBJ
        jb   .o
        ret

; ---- DRAW_BURG: the burglar, from fills: hood, mask, suit, loot, legs -------
DRAW_BURG:
        mov  ax,[burw]
        sub  ax,[camy]          ; his row on the screen
        mov  [tmpys],ax
        mov  bx,[burx]
        add  bx,2               ; the suit
        mov  dx,[tmpys]
        add  dx,8
        mov  cx,12
        mov  si,12
        mov  al,8
        call D4_FILL
        mov  bx,[burx]
        add  bx,4               ; the hood, light grey
        mov  dx,[tmpys]
        add  dx,2
        mov  cx,8
        mov  si,7
        mov  al,7
        call D4_FILL
        mov  bx,[burx]
        add  bx,4               ; the mask: black, over the eyes
        mov  dx,[tmpys]
        add  dx,5
        mov  cx,8
        mov  si,3
        mov  al,0
        call D4_FILL
        mov  bx,[burx]
        add  bx,12              ; the loot bag, yellow
        mov  dx,[tmpys]
        add  dx,14
        mov  cx,4
        mov  si,6
        mov  al,14
        call D4_FILL
        mov  bx,[burx]
        mov  dx,[tmpys]
        add  dx,8               ; the arms: lifted on the other step
        mov  al,[burfr]
        xor  ah,ah
        shl  ax,1
        shl  ax,1               ; 0 or 4 rows
        sub  dx,ax              ; the lifted arm
        mov  cx,2
        mov  si,8
        mov  al,8
        call D4_FILL
        mov  bx,[burx]
        add  bx,14              ; the other arm
        mov  dx,[tmpys]
        add  dx,8
        mov  cx,2
        mov  si,8
        mov  al,8
        call D4_FILL
        mov  bx,[burx]          ; the left leg
        add  bx,2
        mov  dx,[tmpys]
        add  dx,20
        mov  cx,4
        mov  si,4
        mov  al,0
        call D4_FILL
        mov  bx,[burx]          ; the right leg, stepping
        add  bx,10
        mov  dx,[tmpys]
        add  dx,20
        mov  al,[burfr]
        xor  ah,ah
        shl  ax,1               ; 0 or 2 rows
        add  dx,ax              ; the step
        mov  cx,4
        mov  si,4
        mov  al,0
        call D4_FILL
        ret

; ---- DRAW_HUD: score, floor, lives, in a black strip across the top --------
DRAW_HUD:
        mov  bx,0
        mov  dx,0
        mov  cx,320
        mov  si,12
        mov  al,0
        call D4_FILL
        mov  word [d4_tx],4
        mov  word [d4_ty],3
        mov  byte [d4_tclr],15
        mov  byte [d4_tshad],0
        mov  byte [d4_tscale],1
        mov  si,s_score
        call D4_PRINT4
        mov  ax,[score]
        mov  cl,1
        call D4_NUM
        add  word [d4_tx],12    ; a gap before the next label
        mov  si,s_floor
        call D4_PRINT4
        mov  ax,[flrnow]
        mov  cl,1
        call D4_NUM
        add  word [d4_tx],12
        mov  si,s_lives
        call D4_PRINT4
        xor  ah,ah
        mov  al,[lives]
        mov  cl,1
        call D4_NUM
        ret

; ---- DRAW_WORD: BOOM! / BAM! / CLANK! in a black band, while it lasts -----
DRAW_WORD:
        cmp  word [wordt],0
        je   .r
        mov  bx,0
        mov  dx,90
        mov  cx,320
        mov  si,30
        mov  al,0
        call D4_FILL
        mov  al,[wordi]
        xor  ah,ah
        shl  ax,1               ; word index
        mov  bx,ax
        mov  ax,[wordx+bx]
        mov  [d4_tx],ax         ; centred
        mov  word [d4_ty],96
        mov  byte [d4_tshad],1
        mov  byte [d4_tscale],2 ; big letters
        mov  byte [d4_tclr],14
        test word [ticks],2     ; flashing yellow and white
        jz   .c
        mov  byte [d4_tclr],15
.c:     mov  al,[wordi]
        xor  ah,ah
        shl  ax,1
        mov  bx,ax
        mov  si,[wordp+bx]
        call D4_PRINT8
        mov  byte [d4_tshad],0
        mov  byte [d4_tscale],1
.r:     ret

; ---- DRAW_TITLE: the building behind, the name and the keys ----------------
DRAW_TITLE:
        mov  word [camy],1000
        call DRAW_SCENE
        mov  bx,0
        mov  dx,50
        mov  cx,320
        mov  si,80
        mov  al,0
        call D4_FILL
        mov  word [d4_tx],80
        mov  word [d4_ty],60
        mov  byte [d4_tclr],14
        mov  byte [d4_tshad],1
        mov  byte [d4_tscale],2
        mov  si,s_title
        call D4_PRINT8
        mov  byte [d4_tshad],0
        mov  byte [d4_tscale],1
        mov  byte [d4_tclr],15
        mov  word [d4_tx],68
        mov  word [d4_ty],100
        mov  si,s_keys1
        call D4_PRINT8
        mov  word [d4_tx],64
        mov  word [d4_ty],114
        mov  si,s_keys2
        call D4_PRINT8
        ret

; ---- DRAW_OVER: the game over card: score and height -----------------------
DRAW_OVER:
        mov  bx,0
        mov  dx,0
        mov  cx,320
        mov  si,200
        mov  al,0
        call D4_FILL
        mov  word [d4_tx],88
        mov  word [d4_ty],60
        mov  byte [d4_tclr],12
        mov  byte [d4_tshad],1
        mov  byte [d4_tscale],2
        mov  si,s_over
        call D4_PRINT8
        mov  byte [d4_tshad],0
        mov  byte [d4_tscale],1
        mov  byte [d4_tclr],15
        mov  word [d4_tx],100
        mov  word [d4_ty],100
        mov  si,s_score
        call D4_PRINT4
        mov  ax,[score]
        mov  cl,1
        call D4_NUM
        mov  word [d4_tx],100
        mov  word [d4_ty],110
        mov  si,s_height
        call D4_PRINT4
        mov  ax,[maxfl]
        mov  cl,1
        call D4_NUM
        ret

; ---- SHOTCHK: /AUTO takes its one SHOT_SAVE while the word is up ----------
SHOTCHK:
        cmp  byte [auto],0
        je   .r
        cmp  byte [shotdone],0
        jne  .r
        cmp  word [wordt],20    ; the hit word is on the screen
        jae  .go
        cmp  word [ticks],AUTOT-2 ; no hit by the end: the last screen
        jb   .r
.go:    mov  byte [shotdone],1
        call SHOT_SAVE
.r:     ret

; ---- REPORT: the /AUTO lines, after the screen is text again --------------
REPORT: mov  dx,r_floor
        mov  ah,9
        int  21h
        mov  ax,[maxfl]
        call PNUM
        mov  dx,r_nl
        mov  ah,9
        int  21h
        mov  dx,r_thr
        mov  ah,9
        int  21h
        mov  ax,[spawned]
        call PNUM
        mov  dx,r_nl
        mov  ah,9
        int  21h
        cmp  byte [hitn],0
        je   .nohit
        mov  al,[hitkind]
        xor  ah,ah
        shl  ax,1
        mov  bx,ax
        mov  dx,[hitlines+bx]
        mov  ah,9
        int  21h
        jmp  .ent
.nohit: mov  dx,r_nohit
        mov  ah,9
        int  21h
.ent:   mov  dx,r_ent
        mov  ah,9
        int  21h
        mov  ax,[entered]
        call PNUM
        mov  dx,r_nl
        mov  ah,9
        int  21h
        mov  dx,r_score
        mov  ah,9
        int  21h
        mov  ax,[score]
        call PNUM
        mov  dx,r_nl
        mov  ah,9
        int  21h
        ret

; ---- PNUM: AX unsigned in decimal to the screen ----------------------------
PNUM:   push ax
        push bx
        push cx
        push dx
        mov  bx,10
        xor  cx,cx              ; digits so far
.d:     xor  dx,dx
        div  bx                 ; AX / 10: the last digit to DX
        push dx
        inc  cx                 ; one digit more
        or   ax,ax
        jnz  .d
.p:     pop  dx
        add  dl,'0'             ; digit to a character
        mov  ah,2
        int  21h
        loop .p
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; ---- GETAUTO: [auto] = 1 if the command line holds /AUTO -------------------
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

; ---- the words, the tables, the state ---------------------------------------
t_nocard db 'No EGA, VGA, CGA or Hercules picture in this PC.',13,10,'$'
t_nomem  db 'Not enough memory for the picture.',13,10,'$'
t_nomode db 'This PC will not show the picture mode.',13,10,'$'
s_title  db 'FLAT CLIMB',0
s_keys1  db 'ARROWS: CLIMB AND DODGE',0
s_keys2  db 'ENTER: START   ESC: QUIT',0
s_over   db 'GAME OVER',0
s_score  db 'SCORE ',0
s_floor  db 'FLOOR ',0
s_lives  db 'LIVES ',0
s_height db 'HEIGHT ',0
w_boom   db 'BOOM!',0
w_bam    db 'BAM!',0
w_clank  db 'CLANK!',0
wordp    dw w_boom,w_bam,w_clank
wordx    dw 120,128,112         ; each word centred at 16 pixels a letter
r_floor  db 'climbed to floor $'
r_thr    db 'things thrown: $'
r_ent    db 'windows entered: $'
r_score  db 'score $'
r_nohit  db 'not hit by anything',13,10,'$'
r_nl     db 13,10,'$'
h0       db 'hit by a bottle: BOOM!',13,10,'$'
h1       db 'hit by a brick: BAM!',13,10,'$'
h2       db 'hit by a hammer: CLANK!',13,10,'$'
hitlines dw h0,h1,h2

auto     db 0
state    db 0
fall     db 0
burx     dw BURGX0
burw     dw GROUND
burvy    dw 0
burfr    db 0
camy     dw 0
score    dw 0
lives    db LIVES0
maxfl    dw 1
flrnow   dw 1
wordt    dw 0
wordi    db 0
ticks    dw 0
cardclk  dw 0
spawned  dw 0
entered  dw 0
hitn     db 0
hitkind  db 0
shotdone db 0
tmpk     dw 0
tmpi     dw 0
tmpj     dw 0
tmpkk    dw 0
tmpys    dw 0
tmpwx    dw 0
tmpx     dw 0
tmpy     dw 0
tmpvx    dw 0
tmpop    db 0
tmpcol   db 0
tmps     dw 0
tmpkind  db 0
ob_on    db NOBJ dup(0)         ; a thing in the air: 1 = it is flying
ob_kd    db NOBJ dup(0)         ; its kind: 0 bottle, 1 brick, 2 hammer
ob_x     dw NOBJ dup(0)
ob_y     dw NOBJ dup(0)         ; world rows
ob_vx    dw NOBJ dup(0)
ob_vy    dw NOBJ dup(0)
tk       db 160 dup(0)          ; 160 windows (40 floors x 4): entered yet?

        include '..\..\KIT\LIB\K_CARD.INC'
        include '..\..\KIT\LIB\K_D4.INC'
        include '..\..\KIT\LIB\K_KEYS.INC'
        include '..\..\KIT\LIB\K_TIME.INC'
        include '..\..\KIT\LIB\K_MATH.INC'
        include '..\..\KIT\LIB\K_SPK.INC'
        include '..\SHOT.INC'
