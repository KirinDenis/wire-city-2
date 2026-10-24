; LANDA - a Lunar Lander for the 8086 (DOS .COM, VGA mode 13h, PC speaker).
; Up = main thrust, Left/Right = side thrusters, Enter = start, Esc = quit.
; LANDA.COM /AUTO : an autopilot plays one landing or crash, saves the screen, quits.
        org  100h
        include '..\..\ENGINE\E_8086.INC'

GRAV    =    4                  ; gravity added to vy each step (1/64 pixel per step)
THRUST  =    10                 ; main engine pull per step
SIDEA   =    5                  ; side engine pull per step
VYMAX   =    48                 ; safe touchdown fall speed
VXMAX   =    24                 ; safe touchdown sideways speed
XMIN    =    384                ; 6 pixels, in 1/64 pixel
XMAX    =    20032              ; 313 pixels
YMIN    =    640                ; 10 pixels

macro txt x,y,c,s {
        mov  word [t_x],x
        mov  word [t_y],y
        mov  byte [t_c],c
        mov  si,s
        call puts
}

; ---------------------------------------------------------------- start
start:
        cld
        mov  ax,cs
        add  ax,3000h           ; the paragraphs we want: program + two screens
        cmp  ax,[2]             ; PSP:2 = top of memory
        jbe  .memok
        mov  dx,m_nomem
        mov  ah,9
        int  21h
        mov  ax,4C01h
        int  21h
.memok:
        mov  cl,[80h]           ; command tail length
        xor  ch,ch
        mov  si,81h
.sc:    or   cx,cx
        jz   .noa
        lodsb
        dec  cx                 ; one character used
        cmp  al,'/'
        jne  .sc
        mov  al,[si]
        and  al,0DFh            ; upper case
        cmp  al,'A'
        jne  .sc
        mov  byte [auto],1
.noa:
        mov  ax,cs
        add  ax,1000h           ; background screen 64K above the program
        mov  [bgseg],ax
        add  ax,1000h           ; back buffer another 64K up
        mov  [bkseg],ax
        push cs
        pop  es
        mov  di,bss0
        mov  cx,bss1-bss0       ; clear keys, latches, ground
        xor  al,al
        rep  stosb
        call gettick
        xor  ax,5A5Ah           ; mix the seed
        mov  [rnd],ax
        mov  ax,13h
        int  10h                ; mode 13h
        push bp
        mov  ax,1130h
        mov  bh,3               ; the ROM 8x8 font
        int  10h
        mov  [fontoff],bp
        mov  [fontseg],es
        pop  bp
        push cs
        pop  es
        mov  ax,3509h
        int  21h                ; read the old INT 9
        mov  [old9o],bx
        mov  [old9s],es
        push cs
        pop  es
        mov  ax,2509h
        mov  dx,kb_isr
        int  21h                ; take INT 9
        call gen
        call mkbg               ; ground to show behind the title
        cmp  byte [auto],0
        jne  restart
        call title
restart:
        mov  word [score],0
        mov  byte [lives],3
        mov  byte [level],1
        call newlevel
        call gettick
        mov  [lastt],ax

frame:
        call vsync
        cmp  byte [keys+1],0    ; Esc held
        jne  quit
        call gettick
        mov  bx,ax
        sub  ax,[lastt]         ; ticks passed since the last frame
        mov  [lastt],bx
        cmp  ax,6
        jbe  .n
        mov  ax,6               ; at most six physics steps a frame
.n:     mov  cx,ax
        cmp  byte [auto],0
        je   .m
        mov  bx,cx
        shl  cx,1               ; x2
        add  cx,bx              ; x3: the autopilot runs fast
.m:     or   cx,cx
        jz   .render
.t:     push cx
        call tick
        pop  cx
        loop .t
        cmp  byte [state],4
        jne  .render
        call gameover
        jmp  restart
.render:
        call render
        call sound
        cmp  byte [auto],0
        je   frame
        inc  word [atime]       ; frames in AUTO
        cmp  word [atime],3000
        jb   .e
        mov  byte [result],3    ; timeout: should not happen
        call SHOT_SAVE
        jmp  quit
.e:     mov  al,[state]
        cmp  al,2
        jb   frame
        cmp  al,3
        ja   frame
        cmp  word [stimer],25
        ja   frame
        call SHOT_SAVE          ; the game screen is up
        jmp  quit

; ---------------------------------------------------------------- way out
quit:
        call spk_off
        push ds
        mov  dx,[old9o]
        mov  ax,[old9s]
        mov  ds,ax
        mov  ax,2509h
        int  21h                ; give INT 9 back
        pop  ds
        mov  ax,3
        int  10h                ; text mode
        cmp  byte [auto],0
        je   .x
        mov  dx,s_auto
        call dprint
        mov  al,[result]
        cmp  al,1
        jne  .r2
        mov  al,[mulv]
        add  al,'0'
        mov  [m_mul],al
        mov  dx,m_land
        call dprint
        jmp  .st
.r2:    cmp  al,2
        jne  .r3
        mov  dx,m_crash
        call dprint
        mov  ax,[hvx]
        call dnum
        mov  dx,m_vy
        call dprint
        mov  ax,[hvy]
        call dnum
        mov  dx,m_crlf
        call dprint
        jmp  .st
.r3:    mov  dx,m_none
        call dprint
.st:    mov  dx,m_score
        call dprint
        mov  ax,[score]
        call dnum
        mov  dx,m_lives
        call dprint
        mov  al,[lives]
        xor  ah,ah
        call dnum
        mov  dx,m_fuel
        call dprint
        mov  ax,[fuel]
        call dnum
        mov  dx,m_crlf
        call dprint
.x:     mov  ax,4C00h
        int  21h

dprint: mov  ah,9               ; DOS print $-string at DX
        int  21h
        ret

dnum:   xor  cx,cx              ; print AX in decimal through DOS
        mov  bx,10
.d:     xor  dx,dx
        div  bx                 ; ax / 10, divisor is a constant
        push dx
        inc  cx
        or   ax,ax
        jnz  .d
.o:     pop  dx
        add  dl,'0'             ; digit to ASCII
        mov  ah,2
        int  21h
        loop .o
        ret

; ---------------------------------------------------------------- keyboard
kb_isr: push ax
        push bx
        push ds
        push cs
        pop  ds
        in   al,60h             ; scan code
        xor  bh,bh
        mov  bl,al
        and  bl,7Fh
        test al,80h
        jnz  .rel
        mov  byte [keys+bx],1
        mov  byte [latch+bx],1
        jmp  .eoi
.rel:   mov  byte [keys+bx],0
.eoi:   mov  al,20h
        out  20h,al             ; end of interrupt
        pop  ds
        pop  bx
        pop  ax
        iret

; ---------------------------------------------------------------- time, random
gettick:
        push ds
        mov  ax,40h
        mov  ds,ax
        mov  ax,[6Ch]           ; BIOS tick, 18.2 a second
        pop  ds
        ret

vsync:  mov  dx,3DAh
.a:     in   al,dx
        test al,8
        jnz  .a
.b:     in   al,dx
        test al,8
        jz   .b
        ret

rand:   push dx                 ; AX = 0..255 from the high byte of an LCG
        mov  ax,[rnd]
        mov  dx,25173
        mul  dx                 ; rnd * 25173
        add  ax,13849
        mov  [rnd],ax
        mov  al,ah
        xor  ah,ah
        pop  dx
        ret

; ---------------------------------------------------------------- speaker
spk_on: push ax                 ; AX = PIT divisor
        mov  al,0B6h
        out  43h,al
        pop  ax
        out  42h,al
        mov  al,ah
        out  42h,al
        in   al,61h
        or   al,3
        out  61h,al
        ret
spk_off:
        in   al,61h
        and  al,0FCh
        out  61h,al
        ret

sound:  mov  al,[state]
        cmp  al,1
        jne  .n1
        cmp  byte [thr],0
        je   .off
        call rand
        mov  cl,4
        shl  ax,cl              ; noise x16
        add  ax,9000            ; around 100 Hz rumble
        jmp  .play
.n1:    cmp  al,2
        jne  .n2
        mov  ax,2281            ; C
        cmp  word [stimer],30
        ja   .play
        mov  ax,1810            ; E
        cmp  word [stimer],20
        ja   .play
        mov  ax,1522            ; G
        cmp  word [stimer],10
        ja   .play
        mov  ax,1140            ; high C
        cmp  word [stimer],0
        ja   .play
        jmp  .off
.n2:    cmp  al,3
        jne  .off
        cmp  word [stimer],0
        je   .off
        mov  ax,40
        sub  ax,[stimer]        ; time since the crash
        mov  cl,7
        shl  ax,cl              ; x128: pitch falls as it goes
        add  ax,1500
        push ax
        call rand
        and  ax,3Fh
        shl  ax,1               ; noise
        pop  bx
        add  ax,bx
.play:  call spk_on
        ret
.off:   call spk_off
        ret

; ---------------------------------------------------------------- game logic
tick:   mov  al,[state]
        cmp  al,1
        je   .play
        cmp  al,2
        je   .land
        cmp  al,3
        je   .crash
        ret
.play:  call getinput
        call step
        ret
.land:  dec  word [stimer]
        jnz  .r
        inc  byte [level]
        call newlevel
.r:     ret
.crash: dec  word [stimer]
        jnz  .r
        cmp  byte [lives],0
        jne  .resp
        mov  byte [state],4     ; game over
        ret
.resp:  call spawn
        ret

getinput:
        cmp  byte [auto],0
        jne  autopilot
        mov  al,[keys+48h]      ; Up
        mov  [inup],al
        mov  al,[keys+4Bh]      ; Left
        mov  [inl],al
        mov  al,[keys+4Dh]      ; Right
        mov  [inr],al
        ret

autopilot:
        xor  al,al
        mov  [inup],al
        mov  [inl],al
        mov  [inr],al
        call pix
        mov  bx,[tgtx]
        sub  bx,[pxp]           ; pixels still to go sideways
        mov  ax,bx
        shl  ax,1
        add  ax,bx              ; x3 = the speed we want
        cmp  ax,96
        jle  .a1
        mov  ax,96
.a1:    cmp  ax,-96
        jge  .a2
        mov  ax,-96
.a2:    mov  dx,[vx]
        sub  dx,ax              ; speed minus wanted speed
        cmp  dx,6
        jle  .a3
        mov  byte [inl],1
.a3:    cmp  dx,-6
        jge  .a4
        mov  byte [inr],1
.a4:    mov  ax,bx
        or   ax,ax
        jns  .a5
        neg  ax                 ; |dx|
.a5:    cmp  ax,6
        jg   .far
        mov  ax,[tgty]
        sub  ax,[pyp]           ; height above the pad
        mov  dx,44
        cmp  ax,45
        jg   .v
        mov  dx,24              ; slow down near the pad
        jmp  .v
.far:   mov  ax,50
        sub  ax,[pyp]
        shl  ax,1               ; hover near y = 50
        cmp  ax,40
        jle  .f1
        mov  ax,40
.f1:    cmp  ax,-40
        jge  .f2
        mov  ax,-40
.f2:    mov  dx,ax
.v:     cmp  [vy],dx
        jle  .a6
        mov  byte [inup],1
.a6:    ret

burn:   mov  bx,[fuel]          ; AX = fuel to burn
        sub  bx,ax
        jge  .k
        xor  bx,bx
.k:     mov  [fuel],bx
        ret

pix:    mov  ax,[px]
        mov  cl,6
        shr  ax,cl              ; /64 = pixels
        mov  [pxp],ax
        mov  ax,[py]
        shr  ax,cl
        mov  [pyp],ax
        ret

step:   mov  byte [thr],0
        mov  byte [sl],0
        mov  byte [sr],0
        mov  ax,[vy]
        add  ax,GRAV            ; gravity
        cmp  byte [inup],0
        je   .nu
        cmp  word [fuel],0
        je   .nu
        sub  ax,THRUST          ; main engine pushes up
        mov  byte [thr],1
        push ax
        mov  ax,2
        call burn
        pop  ax
.nu:    mov  [vy],ax
        cmp  byte [inl],0
        je   .nl
        cmp  word [fuel],0
        je   .nl
        sub  word [vx],SIDEA    ; left
        mov  byte [sl],1
        mov  ax,1
        call burn
.nl:    cmp  byte [inr],0
        je   .nr
        cmp  word [fuel],0
        je   .nr
        add  word [vx],SIDEA    ; right
        mov  byte [sr],1
        mov  ax,1
        call burn
.nr:    mov  ax,[vx]
        add  [px],ax            ; move
        mov  ax,[vy]
        add  [py],ax
        mov  ax,[px]
        cmp  ax,XMIN
        jge  .x1
        mov  ax,XMIN
        mov  [px],ax
        mov  word [vx],0
.x1:    cmp  ax,XMAX
        jle  .x2
        mov  ax,XMAX
        mov  [px],ax
        mov  word [vx],0
.x2:    mov  ax,[py]
        cmp  ax,YMIN
        jge  .y1
        mov  ax,YMIN
        mov  [py],ax
        cmp  word [vy],0
        jge  .y1
        mov  word [vy],0
.y1:    call check
        ret

check:  call pix
        mov  bx,[pxp]
        sub  bx,4               ; left foot column
        mov  cx,9
.c:     mov  al,[gh+bx]
        xor  ah,ah
        cmp  [pyp],ax
        jge  .hit
        inc  bx
        loop .c
        ret
.hit:   mov  ax,[vx]
        or   ax,ax
        jns  .p
        neg  ax
.p:     mov  [avx],ax           ; |vx|
        mov  bx,[pxp]
        sub  bx,4
        mov  dl,[pm+bx+4]       ; pad multiplier under the middle
        or   dl,dl
        jz   crash
        mov  cx,9
.pc:    cmp  [pm+bx],dl         ; every column on the same pad
        jne  crash
        inc  bx
        loop .pc
        cmp  word [vy],VYMAX
        jg   crash
        cmp  word [avx],VXMAX
        jg   crash
        mov  [mulv],dl          ; landed
        mov  al,dl
        xor  ah,ah
        mov  bx,50
        mul  bx                 ; 50 points x multiplier
        mov  bx,ax
        mov  ax,[fuel]
        xor  dx,dx
        mov  si,10
        div  si                 ; fuel / 10 as a bonus
        add  ax,bx
        mov  [lastpts],ax
        add  [score],ax
        mov  byte [state],2
        mov  word [stimer],40
        mov  word [vx],0
        mov  word [vy],0
        mov  bx,[pxp]
        mov  al,[gh+bx]
        xor  ah,ah
        mov  cl,6
        shl  ax,cl              ; x64: sit exactly on the pad
        mov  [py],ax
        cmp  byte [result],0
        jne  .r
        mov  byte [result],1
.r:     ret
crash:  mov  cl,2
        mov  ax,[vy]
        sar  ax,cl              ; speeds as shown in the HUD
        mov  [hvy],ax
        mov  ax,[avx]
        sar  ax,cl
        mov  [hvx],ax
        dec  byte [lives]
        mov  byte [state],3
        mov  word [stimer],40
        mov  byte [thr],0
        cmp  byte [result],0
        jne  .r
        mov  byte [result],2
.r:     ret

spawn:  call rand
        and  ax,7Fh
        add  ax,30              ; start x 30..157
        mov  cl,6
        shl  ax,cl
        mov  [px],ax
        mov  word [py],1536     ; 24 pixels
        mov  word [vx],16
        mov  word [vy],0
        mov  word [fuel],500
        cmp  byte [auto],0
        je   .r
        mov  ax,[tgtx]
        sub  ax,30
        mov  cl,6
        shl  ax,cl              ; start 30 pixels left of the wide pad
        mov  [px],ax
        mov  word [py],2560     ; 40 pixels
        mov  word [vx],0
.r:     mov  byte [state],1
        mov  word [stimer],0
        mov  byte [thr],0
        mov  byte [sl],0
        mov  byte [sr],0
        call pix
        ret

newlevel:
        call gen
        call mkbg
        call spawn
        ret

; ---------------------------------------------------------------- ground
gen:    push cs
        pop  es
        mov  di,pm
        mov  cx,320
        xor  al,al
        rep  stosb              ; no pads yet
        mov  bx,150
        xor  si,si
.g:     call rand
        and  ax,15
        sub  ax,8               ; step -8..7
        add  bx,ax
        cmp  bx,105
        jge  .a
        mov  bx,105
.a:     cmp  bx,180
        jle  .b
        mov  bx,180
.b:     mov  [gh+si],bl
        inc  si
        cmp  si,320
        jb   .g
        call rand
        and  ax,6Fh
        add  ax,16
        mov  [pad1s],ax
        mov  bx,ax
        mov  cx,40              ; wide pad, x2
        mov  dl,2
        call setpad
        call rand
        and  ax,6Fh
        add  ax,176
        mov  [pad2s],ax
        mov  bx,ax
        mov  cx,24              ; narrow pad, x5
        mov  dl,5
        call setpad
        mov  ax,[pad1s]
        add  ax,20              ; centre of the wide pad
        mov  [tgtx],ax
        mov  bx,ax
        mov  al,[gh+bx]
        xor  ah,ah
        mov  [tgty],ax
        ret

setpad: mov  al,[gh+bx]         ; BX start, CX width, DL multiplier
.s:     mov  [gh+bx],al
        mov  [pm+bx],dl
        inc  bx
        loop .s
        ret

mkbg:   mov  es,[bgseg]
        xor  di,di
        mov  cx,32000
        xor  ax,ax
        rep  stosw              ; black sky
        mov  bp,70
.s:     call rand
        mov  di,[rnd]           ; a star at a random place
        cmp  di,64000
        jae  .sk
        mov  byte [es:di],7
.sk:    dec  bp
        jnz  .s
        xor  si,si
.col:   xor  ax,ax
        mov  al,[gh+si]
        mov  bp,ax              ; top of this column
        mov  dx,320
        mul  dx                 ; top * 320
        add  ax,si
        mov  di,ax
        mov  cx,200
        sub  cx,bp              ; rows to the bottom
        mov  bl,[pm+si]
        xor  bh,bh              ; row number
.row:   mov  al,6               ; brown rock
        cmp  bh,0
        jne  .r1
        mov  al,7               ; grey crest
.r1:    or   bl,bl
        jz   .put
        mov  al,8               ; pad body
        cmp  bh,3
        jae  .put
        mov  al,10              ; x2 pad is green
        cmp  bl,2
        je   .put
        mov  al,14              ; x5 pad is yellow
.put:   stosb
        add  di,319             ; next row, same column
        inc  bh
        loop .row
        inc  si
        cmp  si,320
        jb   .col
        mov  ax,[pad1s]
        add  ax,12
        mov  [t_x],ax
        mov  bx,[pad1s]
        mov  al,[gh+bx]
        xor  ah,ah
        add  ax,5
        mov  [t_y],ax
        mov  byte [t_c],15
        mov  si,s_x2
        call puts
        mov  ax,[pad2s]
        add  ax,4
        mov  [t_x],ax
        mov  bx,[pad2s]
        mov  al,[gh+bx]
        xor  ah,ah
        add  ax,5
        mov  [t_y],ax
        mov  si,s_x5
        call puts
        push cs
        pop  es
        ret

; ---------------------------------------------------------------- drawing
plot:   cmp  cx,200             ; AL colour, BX x, CX y, ES target
        jae  .x
        cmp  bx,320
        jae  .x
        push ax
        push dx
        push di
        push ax
        mov  ax,cx
        mov  dx,320
        mul  dx                 ; y * 320
        add  ax,bx
        mov  di,ax
        pop  ax
        mov  [es:di],al
        pop  di
        pop  dx
        pop  ax
.x:     ret

putc:   push ax                 ; AL char at t_x,t_y colour t_c, into ES
        push bx
        push cx
        push dx
        push si
        push di
        push ds
        xor  ah,ah
        mov  cl,3
        shl  ax,cl              ; char * 8
        mov  si,ax
        add  si,[cs:fontoff]
        mov  ax,[cs:t_y]
        mov  bx,320
        mul  bx                 ; y * 320
        add  ax,[cs:t_x]
        mov  di,ax
        mov  ds,[cs:fontseg]
        mov  cx,8
.row:   lodsb
        mov  bh,al
        mov  bl,8
        push di
.px:    shl  bh,1
        jnc  .no
        mov  al,[cs:t_c]
        mov  [es:di],al
.no:    inc  di
        dec  bl
        jnz  .px
        pop  di
        add  di,320
        loop .row
        pop  ds
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

puts:   push ax
        push si
.l:     lodsb
        or   al,al
        jz   .d
        call putc
        add  word [t_x],8
        jmp  .l
.d:     pop  si
        pop  ax
        ret

putnum: push ax
        push bx
        push cx
        push dx
        xor  cx,cx
        mov  bx,10
.d:     xor  dx,dx
        div  bx                 ; ax / 10, constant divisor
        push dx
        inc  cx
        or   ax,ax
        jnz  .d
.o:     pop  ax
        add  al,'0'             ; digit to ASCII
        call putc
        add  word [t_x],8
        loop .o
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

putsnum:
        or   ax,ax
        jns  putnum
        push ax
        mov  al,'-'
        call putc
        add  word [t_x],8
        pop  ax
        neg  ax
        jmp  putnum

copybg: push ds
        mov  ax,[bkseg]
        mov  es,ax
        mov  ax,[bgseg]
        mov  ds,ax
        xor  si,si
        xor  di,di
        mov  cx,32000
        rep  movsw
        pop  ds
        ret

blit:   push ds
        mov  ax,[bkseg]
        mov  ds,ax
        mov  ax,0A000h
        mov  es,ax
        xor  si,si
        xor  di,di
        mov  cx,32000
        rep  movsw
        pop  ds
        push cs
        pop  es
        ret

render: call copybg
        call pix
        cmp  byte [state],3
        je   .ex
        call drawship
        jmp  .h
.ex:    call explode
.h:     call hud
        call msgs
        call blit
        ret

drawship:
        mov  ax,[pxp]
        sub  ax,4
        mov  [sx],ax
        mov  ax,[pyp]
        sub  ax,8
        mov  [sy],ax
        mov  si,ship
        xor  bp,bp
.r:     xor  di,di
.c:     lodsb
        or   al,al
        jz   .n
        mov  bx,[sx]
        add  bx,di
        mov  cx,[sy]
        add  cx,bp
        call plot
.n:     inc  di
        cmp  di,9
        jb   .c
        inc  bp
        cmp  bp,8
        jb   .r
        cmp  byte [state],1
        jne  .z
        cmp  byte [thr],0
        je   .s1
        mov  bx,[pxp]
        mov  cx,[pyp]
        sub  cx,3
        mov  al,14
        call plot               ; main flame
        inc  cx
        call plot
        mov  al,12
        inc  cx
        call plot
        inc  cx
        call plot
.s1:    cmp  byte [sl],0
        je   .s2
        mov  al,14
        mov  bx,[pxp]
        add  bx,5
        mov  cx,[pyp]
        sub  cx,5
        call plot               ; flame on the right pushes left
        inc  bx
        call plot
.s2:    cmp  byte [sr],0
        je   .z
        mov  al,14
        mov  bx,[pxp]
        sub  bx,5
        mov  cx,[pyp]
        sub  cx,5
        call plot
        dec  bx
        call plot
.z:     ret

explode:
        mov  ax,40
        sub  ax,[stimer]
        mov  [ex_t],ax          ; time since the crash
        xor  si,si
.d:     mov  bp,1
.k:     mov  bx,si
        shl  bx,1
        mov  al,[exdir+bx]
        cbw
        imul word [ex_t]        ; dir * t
        imul bp                 ; x ring 1..3
        mov  cl,3
        sar  ax,cl              ; / 8
        add  ax,[pxp]
        push ax
        mov  al,[exdir+bx+1]
        cbw
        imul word [ex_t]
        imul bp
        mov  cl,3
        sar  ax,cl
        add  ax,[pyp]
        sub  ax,4
        mov  cx,ax
        pop  bx
        mov  al,14
        cmp  word [ex_t],14
        jb   .p
        mov  al,12
        cmp  word [ex_t],28
        jb   .p
        mov  al,4
.p:     call plot
        inc  bp
        cmp  bp,4
        jb   .k
        inc  si
        cmp  si,16
        jb   .d
        ret

hud:    txt  4,2,15,s_fuel
        mov  byte [t_c],15
        cmp  word [fuel],100
        jae  .f
        mov  byte [t_c],12      ; low fuel in red
.f:     mov  ax,[fuel]
        call putnum
        txt  96,2,15,s_score
        mov  ax,[score]
        call putnum
        txt  216,2,15,s_lives
        mov  al,[lives]
        xor  ah,ah
        call putnum
        txt  4,12,15,s_vx
        mov  byte [t_c],10
        mov  ax,[vx]
        or   ax,ax
        jns  .a
        neg  ax
.a:     cmp  ax,VXMAX
        jle  .b
        mov  byte [t_c],12      ; too fast sideways
.b:     mov  ax,[vx]
        mov  cl,2
        sar  ax,cl
        call putsnum
        txt  84,12,15,s_vy
        mov  byte [t_c],10
        cmp  word [vy],VYMAX
        jle  .c
        mov  byte [t_c],12      ; falling too fast
.c:     mov  ax,[vy]
        mov  cl,2
        sar  ax,cl
        call putsnum
        txt  164,12,15,s_alt
        mov  byte [t_c],15
        mov  bx,[pxp]
        mov  al,[gh+bx]
        xor  ah,ah
        sub  ax,[pyp]           ; height above the ground
        jge  .d
        xor  ax,ax
.d:     call putnum
        ret

msgs:   cmp  byte [state],2
        jne  .c
        txt  104,80,10,s_landed
        mov  ax,[lastpts]
        call putnum
        ret
.c:     cmp  byte [state],3
        jne  .z
        txt  124,80,12,s_crash
.z:     ret

; ---------------------------------------------------------------- screens
title:  mov  byte [latch+1Ch],0
        call copybg
        txt  109,20,14,s_name
        txt  108,20,14,s_name
        txt  40,50,15,s_k1
        txt  40,62,15,s_k2
        txt  40,74,15,s_k3
        txt  40,86,15,s_k4
        txt  40,98,15,s_k5
        txt  80,130,10,s_k6
        call blit
.w:     call vsync
        cmp  byte [keys+1],0
        jne  quit
        cmp  byte [latch+1Ch],0
        je   .w
        ret

gameover:
        call spk_off
        mov  byte [latch+1Ch],0
        call copybg
        txt  120,50,12,s_over
        txt  112,70,15,s_sc
        mov  ax,[score]
        call putnum
        txt  80,110,10,s_k7
        txt  80,122,15,s_k8
        call blit
.w:     call vsync
        cmp  byte [keys+1],0
        jne  quit
        cmp  byte [latch+1Ch],0
        je   .w
        ret

        include '..\SHOT.INC'

; ---------------------------------------------------------------- data
ship    db 0,0,0,0,15,0,0,0,0
        db 0,0,0,7,15,7,0,0,0
        db 0,0,7,7,11,7,7,0,0
        db 0,7,7,7,7,7,7,7,0
        db 0,7,7,8,8,8,7,7,0
        db 0,0,8,0,0,0,8,0,0
        db 0,8,0,0,0,0,0,8,0
        db 7,7,0,0,0,0,0,7,7
exdir   db 4,0, 4,2, 3,3, 2,4, 0,4, -2,4, -3,3, -4,2
        db -4,0, -4,-2, -3,-3, -2,-4, 0,-4, 2,-4, 3,-3, 4,-2
s_name  db 'LUNAR LANDER',0
s_k1    db 'UP ARROW     MAIN THRUST',0
s_k2    db 'LEFT/RIGHT   SIDE THRUSTERS',0
s_k3    db 'LAND ON A PAD: VX<=6, VY<=12',0
s_k4    db 'PAD x2 AND x5 MULTIPLY POINTS',0
s_k5    db '3 LIVES.  ESC QUITS TO DOS',0
s_k6    db 'PRESS ENTER TO START',0
s_k7    db 'ENTER = PLAY AGAIN',0
s_k8    db 'ESC   = QUIT TO DOS',0
s_over  db 'GAME OVER',0
s_sc    db 'SCORE ',0
s_fuel  db 'FUEL ',0
s_score db 'SCORE ',0
s_lives db 'LIVES ',0
s_vx    db 'VX ',0
s_vy    db 'VY ',0
s_alt   db 'ALT ',0
s_landed db 'LANDED! +',0
s_crash db 'CRASHED!',0
s_x2    db 'x2',0
s_x5    db 'x5',0
m_nomem db 'Not enough memory.',13,10,'$'
s_auto  db 'LANDA /AUTO: $'
m_land  db 'landed on x'
m_mul   db '2',' pad',13,10,'$'
m_crash db 'crashed, touchdown vx $'
m_vy    db ' vy $'
m_none  db 'no landing or crash',13,10,'$'
m_score db 'score $'
m_lives db ', lives left $'
m_fuel  db ', fuel left $'
m_crlf  db 13,10,'$'
auto    db 0
state   db 0
result  db 0
lives   db 3
level   db 1
thr     db 0
sl      db 0
sr      db 0
inup    db 0
inl     db 0
inr     db 0
mulv    db 0
t_c     db 15
px      dw 0
py      dw 0
vx      dw 0
vy      dw 0
pxp     dw 0
pyp     dw 0
avx     dw 0
hvx     dw 0
hvy     dw 0
fuel    dw 0
score   dw 0
lastpts dw 0
stimer  dw 0
lastt   dw 0
rnd     dw 1
atime   dw 0
t_x     dw 0
t_y     dw 0
sx      dw 0
sy      dw 0
ex_t    dw 0
pad1s   dw 0
pad2s   dw 0
tgtx    dw 0
tgty    dw 0
bgseg   dw 0
bkseg   dw 0
fontoff dw 0
fontseg dw 0
old9o   dw 0
old9s   dw 0
; reserved buffers, cleared at start
bss0:
keys    rb 128
latch   rb 128
gh      rb 320
pm      rb 320
bss1:
