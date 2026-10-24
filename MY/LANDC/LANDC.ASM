; ============================================================================
;  LANDC.ASM - LUNAR LANDER for DOS. A .COM in mode 13h (320x200, 256 colours).
;  Up = main engine (uses fuel), Left/Right = side thrusters, Enter starts,
;  Esc quits. Three lives, three pads with multipliers x1 x2 x3.
;  /AUTO on the command line: an autopilot plays, SHOT_SAVE is called while the
;  game screen is up, then the program prints what happened and quits.
;  Time is the BIOS tick (18.2 a second): one physics step and one picture a tick.
;  Keys are read by our own INT 9 handler (keys held down); INT 9 is given back.
;  Units: positions and speeds are in 1/16 pixel, speeds per tick.
; ============================================================================

        org  100h
        include '..\..\ENGINE\E_8086.INC'

GRAV     equ 2          ; gravity: 2 units a tick, every tick
THRUST   equ 5          ; main engine pulls up 5 units a tick (3 net, with gravity)
SIDEACC  equ 2          ; a side thruster pushes 2 units a tick
FUELMAX  equ 240        ; full tanks
MSGT     equ 36         ; ticks a landing or crash message stays up (about 2 s)
PADW     equ 28         ; a landing pad is 28 pixels wide

; ---------------------------------------------------------------- the start
start:
        xor  ch,ch                  ; CH = 0, so CX = the length of the command tail
        mov  cl,[80h]               ; the tail's length (PSP offset 80h)
        mov  si,81h                 ; the tail's first byte
        mov  byte [auto_on],0       ; no /AUTO yet
.scan:  cmp  cx,4                   ; four bytes left that could hold AUTO?
        jb   .go
        cmp  byte [si],'A'          ; the letter A ...
        jne  .next
        cmp  byte [si+1],'U'        ; ... then U ...
        jne  .next
        cmp  byte [si+2],'T'        ; ... then T ...
        jne  .next
        cmp  byte [si+3],'O'        ; ... then O
        jne  .next
        mov  byte [auto_on],1       ; /AUTO found
        jmp  .go
.next:  inc  si                     ; look one byte further on
        dec  cx                     ; one byte fewer left to look at
        jmp  .scan
.go:
        mov  ax,3509h              ; DOS: read the old INT 9 (keyboard)
        int  21h
        mov  [old9],bx             ; keep its offset
        mov  [old9+2],es           ; and its segment
        mov  ax,2509h              ; DOS: INT 9 now goes to our handler
        mov  dx,kb_isr
        int  21h
        mov  ax,1130h              ; BIOS: where the ROM font is
        mov  bh,3                  ; the 8x8 font, characters 0..127
        int  10h
        mov  [font_seg],es         ; its segment
        mov  [font_off],bp         ; and its offset
        mov  ax,0013h              ; BIOS: mode 13h, 320x200, 256 colours
        int  10h
        mov  ax,0A000h             ; ES = the screen, for all drawing
        mov  es,ax
        call set_pal
        call get_tick              ; seed the random numbers from the BIOS tick
        or   ax,1                  ; never 0: an LCG from 0 stays 0
        mov  [rng],ax
        cmp  byte [auto_on],1
        jne  .title
        call start_game            ; /AUTO plays at once, no title
        jmp  .ticks
.title: mov  byte [state],0        ; the title screen first
.ticks: call get_tick
        mov  [tick_last],ax

; ---------------------------------------------------------------- the loop
main:
        call wait_tick             ; one BIOS tick per frame
        cmp  byte [kb_held+1],1    ; Esc held: quit
        je   quit
        call update                ; the game by its state
        call draw_frame            ; its picture
        call sound                 ; its sound for this tick
        cmp  byte [state],4        ; the /AUTO run is over?
        je   finish
        jmp  main

finish:                            ; /AUTO: the picture that is up is the shot
        call SHOT_SAVE
quit:
        call sound_off
        call restore_kb            ; INT 9 given back to the BIOS
        mov  ax,0003h              ; BIOS: text mode 3
        int  10h
        cmp  byte [auto_on],1
        jne  exit
        call print_result          ; /AUTO: say what happened
exit:
        mov  ax,4C00h              ; DOS: end
        int  21h

include '..\SHOT.INC'

; ---------------------------------------------------------------- state machine
update:
        mov  al,[state]
        cmp  al,0
        je   update_title
        cmp  al,1
        je   update_play
        cmp  al,2
        je   update_msg
        cmp  al,3
        je   update_over
        ret                         ; state 4 (/AUTO over): nothing more

update_title:
        cmp  byte [kb_held+1Ch],1   ; Enter starts
        jne  .r
        call start_game
.r:     ret

start_game:
        mov  word [score],0         ; new game: no points
        mov  word [lives],3         ; three lives
        mov  word [auto_t],0        ; the /AUTO clock
        call new_level
        ret

new_level:                          ; new ground, then a lander at the top
        call gen_ground
        call spawn
        ret

spawn:                              ; a lander at the top, full tanks, still
        mov  word [lx],157*16       ; left side at column 157
        mov  word [ly],20*16        ; 20 px down from the top
        mov  word [vx],0
        mov  word [vy],0
        mov  word [fuel],FUELMAX
        mov  byte [ev],0
        mov  word [msg_t],0
        mov  byte [state],1         ; flying
        ret

update_play:
        call read_inputs            ; the keys, or the autopilot
        call phys_step              ; gravity, thrust, the ground
        cmp  byte [state],1         ; still flying?
        jne  .r
        cmp  byte [auto_on],1
        jne  .r
        inc  word [auto_t]          ; /AUTO clock: one more tick
        cmp  word [auto_t],1200     ; about 66 seconds with no landing: give up
        jb   .r
        mov  byte [ev],0
        mov  byte [state],4
.r:     ret

update_msg:
        inc  word [msg_t]           ; one more tick on the message
        cmp  word [msg_t],MSGT
        jb   .r
        cmp  byte [auto_on],1
        jne  .man
        mov  byte [state],4         ; /AUTO: this picture is the shot
        ret
.man:   cmp  byte [ev],1
        je   .landed
        dec  word [lives]           ; a crash costs a life
        jz   .over
        call spawn                  ; the same ground, a new lander
        ret
.landed:
        call new_level              ; a landing: new ground
        ret
.over:  mov  byte [state],3         ; no lives left: GAME OVER
        mov  word [over_t],0
.r:     ret

update_over:
        inc  word [over_t]          ; one more tick on GAME OVER
        cmp  word [over_t],54       ; about 3 seconds
        jb   .r
        mov  byte [state],0         ; back to the title
.r:     ret

; ---------------------------------------------------------------- the keys
read_inputs:
        cmp  byte [auto_on],1
        je   autopilot
        mov  al,[kb_held+48h]       ; Up arrow (scan 48h) held?
        mov  [f_up],al
        mov  al,[kb_held+4Bh]       ; Left arrow (scan 4Bh)
        mov  [f_left],al
        mov  al,[kb_held+4Dh]       ; Right arrow (scan 4Dh)
        mov  [f_right],al
        ret

; ---------------------------------------------------------------- the autopilot
autopilot:
        mov  byte [f_up],0
        mov  byte [f_left],0
        mov  byte [f_right],0
        mov  ax,[lx]
        mov  cl,4
        shr  ax,cl                  ; AX = the lander's left column (px)
        mov  bx,[pad_xs]
        add  bx,11                  ; BX = the left column that centres it on pad 0
        sub  bx,ax                  ; BX = the distance to go sideways (right is +)
        mov  [dxp],bx
        mov  ax,bx                  ; AX = the distance
        cmp  ax,24
        jle  .ax1
        mov  ax,24                  ; the sideways speed wanted, at most 24 units
.ax1:   cmp  ax,-24
        jge  .ax2
        mov  ax,-24
.ax2:   mov  bx,[vx]
        sub  bx,ax                  ; BX = speed too much (+) or too little (-)
        cmp  bx,2
        jle  .nots
        mov  byte [f_left],1        ; too fast to the right: push left
        jmp  .vert
.nots:  cmp  bx,-2
        jge  .vert
        mov  byte [f_right],1       ; too slow to the right: push right
.vert:  mov  ax,[dxp]
        cmp  ax,0
        jge  .absd
        neg  ax                     ; AX = the size of the distance
.absd:  shl  ax,1                   ; 2 px of height for each px sideways
        mov  bx,[pad_ys]            ; the pad's ground height
        add  bx,10                  ; the glide goes to 10 px under it
        sub  bx,ax                  ; ... less 2 px for each px sideways
        cmp  bx,0
        jge  .tyok
        mov  bx,0                   ; never above the top
.tyok:  mov  ax,[ly]
        mov  cl,4
        sar  ax,cl                  ; AX = the lander's top (px)
        sub  bx,ax                  ; BX = the fall wanted (px, the speed in units)
        cmp  bx,30
        jle  .vd1
        mov  bx,30
.vd1:   cmp  bx,-8
        jge  .vd2
        mov  bx,-8
.vd2:   mov  ax,[vy]
        sub  ax,bx                  ; AX = falling faster than wanted (+)?
        cmp  ax,3
        jle  .done
        mov  byte [f_up],1          ; yes: the main engine
.done:  ret

; ---------------------------------------------------------------- the physics
phys_step:
        cmp  byte [f_up],0          ; the main engine on?
        je   .nothr
        cmp  word [fuel],2          ; and at least 2 fuel?
        jb   .nothr
        sub  word [vy],THRUST       ; up is less y: 5 units up a tick
        sub  word [fuel],2          ; the engine burns 2 fuel a tick
.nothr: add  word [vy],GRAV         ; gravity: 2 units down a tick
        cmp  byte [f_left],0        ; the left thruster
        je   .nl
        cmp  word [fuel],1
        jb   .nl
        sub  word [vx],SIDEACC      ; push left: 2 units
        dec  word [fuel]            ; 1 fuel
.nl:    cmp  byte [f_right],0       ; the right thruster
        je   .nr
        cmp  word [fuel],1
        jb   .nr
        add  word [vx],SIDEACC      ; push right: 2 units
        dec  word [fuel]            ; 1 fuel
.nr:    cmp  word [vy],120          ; falling at most 120 units a tick
        jle  .vyup
        mov  word [vy],120
.vyup:  cmp  word [vy],-60          ; rising at most 60
        jge  .vxmax
        mov  word [vy],-60
.vxmax: cmp  word [vx],40          ; sideways at most 40 either way
        jle  .vxmin
        mov  word [vx],40
.vxmin: cmp  word [vx],-40
        jge  .move
        mov  word [vx],-40
.move:  mov  ax,[vx]
        add  [lx],ax               ; the lander moves sideways by vx
        mov  ax,[vy]
        add  [ly],ax               ; and down by vy
        cmp  word [lx],0           ; the left wall
        jge  .rwall
        mov  word [lx],0
        mov  word [vx],0
.rwall: cmp  word [lx],313*16      ; the right wall
        jle  .ceil
        mov  word [lx],313*16
        mov  word [vx],0
.ceil:  cmp  word [ly],0           ; the top of the screen
        jge  .cols
        mov  word [ly],0
        mov  word [vy],0
.cols:  mov  ax,[lx]
        mov  cl,4
        shr  ax,cl                 ; AX = the lander's left column (px, /16)
        mov  [c0],ax
        add  ax,3                  ; the middle column: + 3
        mov  [c3],ax
        mov  ax,[c0]
        add  ax,6                  ; the right column: + 6
        mov  [c6],ax
        mov  bx,[c0]
        mov  al,[gh+bx]           ; the ground under the left column
        mov  [h0],al
        mov  bx,[c3]
        mov  al,[gh+bx]           ; under the middle
        mov  [h3],al
        mov  bx,[c6]
        mov  al,[gh+bx]           ; under the right
        mov  [h6],al
        mov  al,[h0]              ; the smallest row = the highest ground under it
        cmp  al,[h3]
        jbe  .m1
        mov  al,[h3]
.m1:    cmp  al,[h6]
        jbe  .m2
        mov  al,[h6]
.m2:    mov  [mingh],al
        mov  ax,[ly]
        mov  cl,4
        sar  ax,cl                 ; AX = the lander's top row (px)
        add  ax,4                  ; + 4: its bottom row
        mov  bl,[mingh]
        mov  bh,0
        cmp  ax,bx                 ; the bottom at or under that ground?
        jge  .touch
        ret                        ; still in the air

.touch: mov  bx,[c0]
        mov  al,[gpad+bx]          ; the pad under the left column (0 = none)
        mov  [mult_last],al
        mov  bx,[c6]
        cmp  al,[gpad+bx]          ; the right column on the same pad?
        jne  .crash
        cmp  byte [mult_last],0    ; and a pad at all?
        je   .crash
        cmp  word [vy],24          ; down gently: at most 24 units a tick
        jg   .crash
        mov  ax,[vx]
        cmp  ax,0
        jge  .absx
        neg  ax                    ; the sideways speed, as a size
.absx:  cmp  ax,10                 ; sideways at most 10 units a tick
        jg   .crash
        mov  byte [ev],1           ; LANDED on a pad
        mov  al,[mult_last]
        mov  ah,0
        mov  bx,100
        mul  bx                    ; the multiplier times 100 (DX becomes 0)
        add  ax,[fuel]             ; plus the fuel left, a point a unit
        add  [score],ax
        jmp  .settle
.crash: mov  byte [ev],2           ; CRASHED
.settle:
        mov  al,[mingh]
        mov  ah,0
        sub  ax,5                  ; the bottom row one above the highest ground under it
        mov  cl,4
        shl  ax,cl                 ; back to 1/16 px (times 16)
        mov  [ly],ax
        mov  word [vx],0
        mov  word [vy],0
        mov  word [msg_t],0
        mov  byte [f_up],0
        mov  byte [f_left],0
        mov  byte [f_right],0
        mov  byte [state],2        ; the message
        ret

; ---------------------------------------------------------------- the ground
gen_ground:                         ; jagged ground by a random walk, then 3 pads
        mov  word [yc],150
        xor  bx,bx                  ; BX = the column, 0..319
.col:   mov  cx,7
        call rnd_mod                ; AX = 0..6
        sub  ax,3                   ; -3..+3: this column's step
        add  ax,[yc]                ; the new height
        cmp  ax,110
        jge  .lo
        mov  ax,110                 ; not above row 110
.lo:    cmp  ax,180
        jle  .hi
        mov  ax,180                 ; not below row 180
.hi:    mov  [yc],ax
        mov  [gh+bx],al
        mov  byte [gpad+bx],0      ; no pad here (yet)
        inc  bx                     ; next column
        cmp  bx,320
        jb   .col
        mov  cx,3
        call rnd_mod                ; AX = 0..2: which pad gets which multiplier
        mov  [padr],ax
        mov  word [padk],0
.pad:   mov  cx,30
        call rnd_mod               ; AX = 0..29
        add  ax,20                 ; 20..49 px in
        mov  [padx],ax
        mov  ax,[padk]
        mov  cx,105
        mul  cx                    ; AX = the pad's number * 105 (DX becomes 0)
        add  ax,[padx]             ; + its random start: the pad's left column
        mov  [padx],ax
        mov  ax,[padk]
        add  ax,[padr]             ; the multiplier: (number + shift) mod 3, plus 1
        cmp  ax,3
        jb   .m1
        sub  ax,3
.m1:    inc  ax
        mov  [padm],al
        mov  si,[padx]
        add  si,14                 ; the pad's middle
        mov  al,[gh+si]
        mov  [padh],al             ; its height
        mov  bx,[padk]
        shl  bx,1                  ; BX = number * 2 (words)
        mov  ax,[padx]
        mov  [pad_xs+bx],ax
        mov  ah,0
        mov  al,[padh]
        mov  [pad_ys+bx],ax
        mov  bx,[padk]
        mov  al,[padm]
        mov  [pad_ms+bx],al
        mov  si,[padx]
        mov  cx,PADW               ; the pad is flat, and carries its multiplier
.fill:  mov  al,[padh]
        mov  [gh+si],al
        mov  al,[padm]
        mov  [gpad+si],al
        inc  si                    ; next column
        loop .fill
        inc  word [padk]
        cmp  word [padk],3
        jb   .pad
        ret

draw_ground:                        ; every column: from its top row to the bottom
        xor  bx,bx                  ; BX = the column
.col:   mov  al,[gh+bx]
        mov  ah,0
        mov  [gy],ax                ; the top row of this column
        mul  word [c320]            ; AX = top row * 320 (DX becomes 0)
        add  ax,bx                  ; + the column
        mov  di,ax                  ; DI = the top pixel of the column
        mov  al,2                   ; ground colour
        cmp  byte [gpad+bx],0
        je   .ground
        mov  al,4                   ; a pad: yellow
.ground:
        mov  cx,200
        sub  cx,[gy]               ; CX = rows from the top to the bottom
.px:    mov  [es:di],al
        add  di,320                 ; one row down
        loop .px
        inc  bx                     ; next column
        cmp  bx,320
        jb   .col
        ret

draw_pad_labels:                    ; "X1 PAD" and so on, above each pad
        mov  word [txt_sc],1
        mov  word [pidx],0
.l:     mov  bx,[pidx]
        shl  bx,1                   ; BX = pad number * 2 (words)
        mov  cx,[pad_xs+bx]
        sub  cx,6                   ; a little left of the pad
        mov  [plx],cx
        mov  dx,[pad_ys+bx]
        sub  dx,12                  ; above the ground
        mov  [ply],dx
        mov  bx,[pidx]
        mov  al,[pad_ms+bx]
        mov  ah,0
        dec  ax                     ; the multiplier 1..3 as an index 0..2
        shl  ax,1
        mov  bx,ax
        mov  si,[pad_strs+bx]       ; its text
        mov  bx,[plx]
        mov  dx,[ply]
        mov  al,4                   ; yellow
        call draw_str
        inc  word [pidx]
        cmp  word [pidx],3
        jb   .l
        ret

; ---------------------------------------------------------------- the pictures
draw_frame:
        call clear_screen
        call calc_lpos
        mov  al,[state]
        cmp  al,0
        je   .title
        cmp  al,3
        je   .over
        call draw_ground
        call draw_pad_labels
        mov  al,[state]
        cmp  al,1
        je   .play
        cmp  al,4
        jne  .msg
        cmp  byte [ev],0            ; /AUTO timed out: the play picture
        je   .play
.msg:   call draw_msg
        ret
.play:  call draw_lander
        call draw_flames
        call draw_hud
        ret
.title: call draw_title
        ret
.over:  call draw_over
        ret

clear_screen:
        cld
        xor  ax,ax                  ; black
        xor  di,di
        mov  cx,32000               ; 64000 bytes as words
        rep  stosw
        ret

calc_lpos:                          ; the lander's top-left pixel
        mov  ax,[lx]
        mov  cl,4
        shr  ax,cl
        mov  [lpx],ax
        mov  ax,[ly]
        mov  cl,4
        sar  ax,cl
        mov  [lpy],ax
        ret

draw_lander:                        ; body 7 x 3 white, legs cyan
        mov  bx,[lpx]
        mov  dx,[lpy]
        mov  cx,7                   ; 7 pixels wide
        mov  si,3                   ; 3 rows high
        mov  al,1
        call fill_rect
        mov  bx,[lpx]
        mov  dx,[lpy]
        add  dx,3                   ; the legs start under the body
        mov  cx,1
        mov  si,2
        mov  al,3
        call fill_rect
        mov  bx,[lpx]
        add  bx,6                   ; the right leg, 6 columns over
        mov  dx,[lpy]
        add  dx,3
        mov  cx,1
        mov  si,2
        mov  al,3
        call fill_rect
        ret

draw_flames:
        cmp  byte [f_up],0          ; main engine: a flame under the lander
        je   .side
        cmp  word [fuel],2
        jb   .side
        mov  bx,[lpx]
        add  bx,2
        mov  dx,[lpy]
        add  dx,5                   ; one row under the legs
        mov  cx,3
        mov  si,3
        mov  al,5
        call fill_rect
.side:  cmp  byte [f_left],0        ; left thruster: flame out of the right side
        je   .fr
        mov  bx,[lpx]
        add  bx,7
        mov  dx,[lpy]
        add  dx,1
        mov  cx,2
        mov  si,1
        mov  al,6
        call fill_rect
.fr:    cmp  byte [f_right],0       ; right thruster: flame out of the left side
        je   .fe
        mov  bx,[lpx]
        sub  bx,2
        mov  dx,[lpy]
        add  dx,1
        mov  cx,2
        mov  si,1
        mov  al,6
        call fill_rect
.fe:    ret

draw_msg:
        cmp  byte [ev],1
        jne  .boom
        call draw_lander            ; landed: the lander stands on the pad
        jmp  .txt
.boom:  call draw_boom              ; crashed: the explosion
.txt:   call draw_hud
        mov  word [txt_sc],2
        mov  dx,50
        cmp  byte [ev],1
        jne  .cr
        mov  si,s_landed
        mov  bx,112
        mov  al,4
        jmp  .say
.cr:    mov  si,s_crashed
        mov  bx,104
        mov  al,6
.say:   call draw_str
        mov  word [txt_sc],1
        cmp  byte [ev],1
        jne  .ret
        mov  al,[mult_last]         ; the pad's name under it
        mov  ah,0
        dec  ax
        shl  ax,1
        mov  bx,ax
        mov  si,[pad_strs+bx]
        mov  bx,120
        mov  dx,80
        mov  al,1
        call draw_str
.ret:   ret

draw_boom:                          ; 12 sparks flying out, a ring that grows
        mov  ax,[msg_t]
        shr  ax,1                   ; the radius: msg_t / 2
        mov  [br],ax
        mov  al,4                   ; yellow at first
        cmp  word [msg_t],12
        jb   .c
        mov  al,5                   ; then orange
        cmp  word [msg_t],24
        jb   .c
        mov  al,6                   ; then red
.c:     mov  [bc],al
        mov  word [bi],0
.p:     mov  bx,[bi]
        mov  al,[bdx+bx]           ; the spark's direction across
        cbw
        imul word [br]             ; direction * radius
        add  ax,[lpx]
        add  ax,3                  ; from the lander's middle
        mov  [qx],ax
        mov  bx,[bi]
        mov  al,[bdy+bx]           ; the spark's direction down
        cbw
        imul word [br]
        add  ax,[lpy]
        add  ax,2
        mov  dx,ax                 ; DX = the row
        mov  bx,[qx]               ; BX = the column
        mov  al,[bc]
        call put_px
        inc  bx                    ; a two-pixel spark
        mov  al,[bc]
        call put_px
        inc  word [bi]
        cmp  word [bi],12
        jb   .p
        ret

draw_hud:
        mov  word [txt_sc],1
        mov  si,h_fuel              ; row 1: fuel, lives, score
        mov  bx,2
        mov  dx,2
        mov  al,3
        call draw_str
        mov  ax,[fuel]
        mov  bx,40
        mov  dx,2
        call draw_num
        mov  si,h_lives
        mov  bx,96
        mov  dx,2
        mov  al,3
        call draw_str
        mov  ax,[lives]
        mov  bx,136
        mov  dx,2
        call draw_num
        mov  si,h_score
        mov  bx,170
        mov  dx,2
        mov  al,3
        call draw_str
        mov  ax,[score]
        mov  bx,210
        mov  dx,2
        call draw_num
        mov  si,h_alt              ; row 2: altitude, vertical and horizontal speed
        mov  bx,2
        mov  dx,12
        mov  al,3
        call draw_str
        mov  ax,[lx]               ; the ground under the middle, minus the lander
        mov  cl,4
        shr  ax,cl
        add  ax,3
        mov  bx,ax
        mov  al,[gh+bx]
        mov  ah,0
        mov  [yc],ax
        mov  ax,[ly]
        mov  cl,4
        sar  ax,cl                 ; the lander's top row
        mov  bx,[yc]
        sub  bx,ax                 ; ground minus top
        sub  bx,5                  ; minus the lander's height: the altitude
        mov  ax,bx
        cmp  ax,0
        jge  .alt
        mov  ax,0
.alt:   mov  bx,40
        mov  dx,12
        call draw_num
        mov  si,h_vs
        mov  bx,96
        mov  dx,12
        mov  al,3
        call draw_str
        mov  ax,[vy]
        mov  cl,2
        sar  ax,cl                 ; the vertical speed, a quarter unit each
        mov  bx,120
        mov  dx,12
        call draw_snum
        mov  si,h_hs
        mov  bx,170
        mov  dx,12
        mov  al,3
        call draw_str
        mov  ax,[vx]
        mov  cl,2
        sar  ax,cl                 ; the horizontal speed
        mov  bx,194
        mov  dx,12
        call draw_snum
        ret

draw_title:
        mov  word [txt_sc],2
        mov  si,t_name
        mov  bx,64
        mov  dx,40
        mov  al,4
        call draw_str
        mov  word [txt_sc],1
        mov  si,t_l1
        mov  bx,100
        mov  dx,100
        mov  al,1
        call draw_str
        mov  si,t_l2
        mov  bx,60
        mov  dx,116
        mov  al,1
        call draw_str
        mov  si,t_l3
        mov  bx,36
        mov  dx,132
        mov  al,3
        call draw_str
        mov  si,t_l4
        mov  bx,76
        mov  dx,160
        mov  al,1
        call draw_str
        ret

draw_over:
        mov  word [txt_sc],2
        mov  si,s_gameover
        mov  bx,88
        mov  dx,70
        mov  al,6
        call draw_str
        mov  word [txt_sc],1
        mov  si,h_score
        mov  bx,120
        mov  dx,110
        mov  al,3
        call draw_str
        mov  ax,[score]
        mov  bx,176
        mov  dx,110
        call draw_num
        ret

; ---------------------------------------------------------------- the drawing blocks
put_px:                             ; one pixel: BX = x, DX = y, AL = colour; clipped
        cmp  bx,320
        jae  .o                     ; off the sides (negative too)
        cmp  dx,200
        jae  .o                     ; off the top or bottom
        push ax
        push cx
        push dx
        mov  ax,dx                  ; AX = y
        mul  word [c320]            ; DX:AX = y * 320 (DX becomes 0)
        add  ax,bx                  ; + x
        mov  di,ax
        pop  dx
        pop  cx
        pop  ax
        mov  [es:di],al
.o:     ret

fill_rect:                          ; BX = x, DX = y, CX = wide, SI = high, AL = colour
        mov  [fr_c],al
        mov  [fr_x],bx
        mov  [fr_y],dx
        mov  [fr_w],cx
        mov  [fr_h],si
        mov  word [fr_j],0          ; the row
.row:   mov  word [fr_i],0          ; the column
.col:   mov  bx,[fr_x]
        add  bx,[fr_i]
        mov  dx,[fr_y]
        add  dx,[fr_j]
        mov  al,[fr_c]
        call put_px
        inc  word [fr_i]            ; next column
        mov  ax,[fr_i]
        cmp  ax,[fr_w]
        jb   .col
        inc  word [fr_j]            ; next row
        mov  ax,[fr_j]
        cmp  ax,[fr_h]
        jb   .row
        ret

; ---------------------------------------------------------------- text
draw_str:                           ; SI = 0-ended text, BX = x, DX = y, AL = colour
        mov  [txt_x],bx
        mov  [txt_y],dx
        mov  [txt_c],al
.nc:    lodsb                       ; the next character
        test al,al
        jz   .r
        push si
        call draw_char
        pop  si
        jmp  .nc
.r:     ret

draw_char:                          ; AL = the character, at txt_x, txt_y, scale txt_sc
        mov  ah,0
        mov  cl,3
        shl  ax,cl                  ; AX = character * 8 (8 bytes a glyph)
        add  ax,[font_off]          ; + the font's offset
        mov  si,ax
        push ds
        mov  ax,[font_seg]
        mov  ds,ax                  ; DS = the ROM font
        push es
        push cs
        pop  es                     ; ES = our segment, to copy the glyph into
        mov  di,glyph
        mov  cx,8
        rep  movsb                  ; the 8 rows of the glyph
        pop  es                     ; ES = the screen again
        pop  ds                     ; DS = our segment again
        mov  word [row],0
.row:   mov  bx,[row]
        mov  al,[glyph+bx]          ; this row's 8 bits, leftmost first
        mov  [bits],al
        mov  word [colm],0
.bit:   shl  byte [bits],1          ; the top bit goes to CF
        jnc  .nxt
        mov  ax,[colm]
        mul  word [txt_sc]         ; column * scale (DX becomes 0)
        add  ax,[txt_x]
        mov  [px0],ax
        mov  ax,[row]
        mul  word [txt_sc]         ; row * scale
        add  ax,[txt_y]
        mov  [py0],ax
        call draw_block
.nxt:   inc  word [colm]           ; next bit
        cmp  word [colm],8
        jb   .bit
        inc  word [row]            ; next row
        cmp  word [row],8
        jb   .row
        mov  ax,[txt_sc]
        mov  cl,3
        shl  ax,cl                 ; 8 * scale: the advance to the next character
        add  [txt_x],ax
        ret

draw_block:                         ; a txt_sc by txt_sc block at px0, py0 in colour txt_c
        mov  word [blky],0
.yy:    mov  word [blkx],0
.xx:    mov  bx,[px0]
        add  bx,[blkx]
        mov  dx,[py0]
        add  dx,[blky]
        mov  al,[txt_c]
        call put_px
        inc  word [blkx]
        mov  ax,[blkx]
        cmp  ax,[txt_sc]
        jb   .xx
        inc  word [blky]
        mov  ax,[blky]
        cmp  ax,[txt_sc]
        jb   .yy
        ret

draw_num:                           ; AX unsigned at BX, DX (white)
        push bx
        push dx
        call num_conv
        pop  dx
        pop  bx
        mov  al,1
        call draw_str
        ret

draw_snum:                          ; AX signed at BX, DX: a minus sign if below 0
        mov  [sn_x],bx
        mov  [sn_y],dx
        cmp  ax,0
        jge  .pos
        neg  ax                     ; its size
        push ax
        mov  bx,[sn_x]
        mov  dx,[sn_y]
        mov  si,s_minus
        mov  al,1
        call draw_str
        pop  ax
        mov  bx,[sn_x]
        add  bx,8                   ; the number after the sign
        mov  dx,[sn_y]
        call draw_num
        ret
.pos:   mov  bx,[sn_x]
        mov  dx,[sn_y]
        call draw_num
        ret

num_conv:                           ; AX unsigned -> SI = its digits, 0-ended (numbuf)
        mov  byte [numbuf+6],0
        mov  di,numbuf+6            ; the digits are written backwards from here
        mov  cx,10
.dg:    xor  dx,dx
        div  cx                     ; AX / 10: DX = the last digit (CX is 10)
        dec  di
        add  dl,'0'                 ; to ASCII
        mov  [di],dl
        test ax,ax
        jnz  .dg
        mov  si,di
        ret

; ---------------------------------------------------------------- random numbers
get_tick:                           ; AX = the BIOS tick (low word, 18.2 a second)
        push es
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:046Ch]
        pop  es
        ret

wait_tick:                          ; wait for the next tick
        mov  bx,[tick_last]
.w:     call get_tick
        cmp  ax,bx
        je   .w
        mov  [tick_last],ax
        ret

rnd_byte:                           ; AL = a random byte (BX kept)
        mov  ax,[rng]
        mul  word [mulk]           ; DX:AX = rng * 25173
        add  ax,13849              ; the LCG step
        mov  [rng],ax
        mov  al,ah                 ; the high byte is the good one
        ret

rnd_mod:                            ; AX = a random number 0..CX-1 (CX from 1 to 255; BX kept)
        call rnd_byte
        mov  ah,0
        xor  dx,dx
        div  cx                     ; DX = AX mod CX
        mov  ax,dx
        ret

; ---------------------------------------------------------------- sound: the PC speaker
tone:                               ; AX = divisor: the speaker on at that pitch
        mov  bx,ax
        mov  al,0B6h               ; PIT channel 2, square wave
        out  43h,al
        mov  al,bl
        out  42h,al
        mov  al,bh
        out  42h,al
        in   al,61h
        or   al,3                  ; speaker gate and data on
        out  61h,al
        ret

sound_off:
        in   al,61h
        and  al,0FCh               ; speaker gate and data off
        out  61h,al
        ret

sound:
        mov  al,[state]
        cmp  al,1
        jne  .nopl
        cmp  byte [f_up],0         ; thrusting: a roar, a new pitch each tick
        je   .off
        cmp  word [fuel],2
        jb   .off
        call rnd_byte
        mov  ah,0
        add  ax,1000               ; divisor 1000..1255: a low noise
        call tone
        ret
.nopl:  cmp  al,2
        jne  .off
        cmp  byte [ev],2
        jne  .chime
        cmp  word [msg_t],18       ; a crash: noise for 18 ticks
        jae  .off
        call rnd_byte
        mov  ah,0
        mov  cl,3
        shl  ax,cl                 ; 0..2040
        add  ax,2000
        call tone
        ret
.chime: cmp  word [msg_t],16       ; a landing: four notes, four ticks each
        jae  .off
        mov  bx,[msg_t]
        shl  bx,1
        mov  ax,[chime+bx]
        call tone
        ret
.off:   call sound_off
        ret

; ---------------------------------------------------------------- DOS and the keys
print_result:                       ; /AUTO: one line for the landing or crash, one for the score
        cmp  byte [ev],1
        jne  .notland
        mov  si,s_land1
        call pr_z
        mov  al,[mult_last]
        add  al,'0'                 ; the multiplier as a digit
        mov  dl,al
        mov  ah,2                   ; DOS: print the character in DL
        int  21h
        mov  si,s_pad
        call pr_z
        jmp  .score
.notland:
        cmp  byte [ev],2
        jne  .timeout
        mov  si,s_crash
        call pr_z
        jmp  .score
.timeout:
        mov  si,s_timeout
        call pr_z
.score: mov  si,s_score_p
        call pr_z
        mov  ax,[score]
        call num_conv
        call pr_z
        mov  si,s_crlf
        call pr_z
        ret

pr_z:                               ; SI = 0-ended text: to the DOS output
        lodsb
        test al,al
        jz   .d
        mov  dl,al
        mov  ah,2                   ; DOS: print the character in DL
        int  21h
        jmp  pr_z
.d:     ret

restore_kb:                         ; INT 9 given back
        push ds
        lds  dx,dword [old9]        ; DS:DX = the old handler
        mov  ax,2509h
        int  21h
        pop  ds
        ret

kb_isr:                             ; INT 9: a key down or up sets its held flag
        push ax
        push bx
        push ds
        push cs
        pop  ds                     ; DS = our data
        in   al,60h                 ; the scan code; bit 7 = key released
        mov  bl,al
        and  bl,7Fh                 ; the key number 0..127
        mov  bh,0
        test al,80h
        jnz  .up
        mov  byte [kb_held+bx],1    ; down
        jmp  .ack
.up:    mov  byte [kb_held+bx],0    ; up
.ack:   in   al,61h                 ; tell the keyboard its key was taken
        or   al,80h
        out  61h,al
        and  al,7Fh
        out  61h,al
        mov  al,20h                 ; end of interrupt to the PIC
        out  20h,al
        pop  ds
        pop  bx
        pop  ax
        iret

set_pal:                            ; colours 0..7 into the DAC (6-bit values)
        mov  dx,3C8h
        mov  al,0
        out  dx,al
        mov  dx,3C9h
        mov  si,pal_tab
        mov  cx,24
.p:     lodsb
        out  dx,al
        loop .p
        ret

; ---------------------------------------------------------------- data
auto_on     db 0
state       db 0            ; 0 title, 1 flying, 2 landed or crashed, 3 game over, 4 /AUTO done
ev          db 0            ; 0 none, 1 landed, 2 crashed
f_up        db 0
f_left      db 0
f_right     db 0
lx          dw 0            ; the lander, 1/16 px
ly          dw 0
vx          dw 0            ; its speed, 1/16 px a tick
vy          dw 0
fuel        dw 0
lives       dw 0
score       dw 0
msg_t       dw 0            ; ticks the message has been up
over_t      dw 0
auto_t      dw 0
mult_last   db 0            ; the multiplier of the pad last landed on
mingh       db 0            ; the highest ground under the lander
h0          db 0
h3          db 0
h6          db 0
c0          dw 0            ; the lander's left, middle and right columns
c3          dw 0
c6          dw 0
dxp         dw 0
rng         dw 0
mulk        dw 25173
yc          dw 0
padk        dw 0
padx        dw 0
padr        dw 0
padm        db 0
padh        db 0
pad_xs      dw 0,0,0        ; the pads: left column, height, multiplier
pad_ys      dw 0,0,0
pad_ms      db 0,0,0
gh          db 320 dup(0)   ; the ground's top row, every column
gpad        db 320 dup(0)   ; the pad's multiplier, every column (0 = none)
c320        dw 320
font_seg    dw 0
font_off    dw 0
tick_last   dw 0
old9        dw 0,0
kb_held     db 128 dup(0)   ; key held flags, by scan code
txt_x       dw 0
txt_y       dw 0
txt_c       db 0
txt_sc      dw 1
chr         db 0
glyph       db 8 dup(0)
row         dw 0
colm        dw 0
bits        db 0
px0         dw 0
py0         dw 0
blky        dw 0
blkx        dw 0
gy          dw 0
fr_c        db 0
fr_x        dw 0
fr_y        dw 0
fr_w        dw 0
fr_h        dw 0
fr_i        dw 0
fr_j        dw 0
lpx         dw 0
lpy         dw 0
br          dw 0
bc          db 0
bi          dw 0
qx          dw 0
bdx         db 2,2,1,0,-1,-2,-2,-2,-1,0,1,2
bdy         db 0,1,2,2,2,1,0,-1,-2,-2,-2,-1
numbuf      db 8 dup(0)
sn_x        dw 0
sn_y        dw 0
pidx        dw 0
plx         dw 0
ply         dw 0
chime       dw 2281,2281,2281,2281, 1809,1809,1809,1809
            dw 1521,1521,1521,1521, 1140,1140,1140,1140
pal_tab     db 0,0,0        ; 0 black
            db 63,63,63     ; 1 white
            db 36,24,12     ; 2 ground brown
            db 0,63,63      ; 3 cyan
            db 63,63,0      ; 4 yellow
            db 63,32,0      ; 5 orange
            db 63,0,0       ; 6 red
            db 24,24,24     ; 7 grey

t_name      db 'LUNAR LANDER',0
t_l1        db 'UP  MAIN ENGINE',0
t_l2        db 'LEFT RIGHT  SIDE THRUSTERS',0
t_l3        db 'LAND ON A PAD, SLOW AND UPRIGHT',0
t_l4        db 'ENTER START   ESC QUIT',0
s_gameover  db 'GAME OVER',0
s_landed    db 'LANDED',0
s_crashed   db 'CRASHED',0
s_minus     db '-',0
s_x1        db 'X1 PAD',0
s_x2        db 'X2 PAD',0
s_x3        db 'X3 PAD',0
pad_strs    dw s_x1,s_x2,s_x3
h_fuel      db 'FUEL',0
h_lives     db 'LIVES',0
h_score     db 'SCORE',0
h_alt       db 'ALT',0
h_vs        db 'VS',0
h_hs        db 'HS',0
s_land1     db 'landed on x',0
s_pad       db ' pad',13,10,0
s_crash     db 'crashed',13,10,0
s_timeout   db 'no landing or crash in 66 seconds',13,10,0
s_score_p   db 'score ',0
s_crlf      db 13,10,0
