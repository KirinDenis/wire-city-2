; ============================================================================
;  FTITLE.ASM - KIT test: the recipe KIT\REC\R_TITLE.ASM (the title card,
;  its blink, its loop, the score line), included whole as a program that
;  copied it would hold it.
;
;      FTITLE         checks, shows the title, then the score line over a
;                     day sky with clouds and a sun, until Esc
;      FTITLE /AUTO   the same, ~2 s each, prints PASS/FAIL
;      FTITLE /S      also writes SHOT.RAW (the title) and SHOT2.RAW (the HUD)
;
;  The checks draw into the back buffer and read it back: PRESS ENTER is
;  there when the blink is lit and gone when it is dark, and nothing else
;  on the card changes; the name is centred; TTLRUN gives up after its
;  ticks and says so; the score line on a white picture is yellow digits
;  in a black ring, and it stays in its strip at the top.
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

Main:   cld
        call IsAuto
        call MEM_INIT
        call VGA_ON             ; mode 13h and a back buffer
        jnc  .ok
        mov  dx,sNoMem
        mov  ah,9
        int  21h
        mov  ax,4C01h
        int  21h
.ok:    mov  ax,[vga_buf]
        mov  es,ax              ; ES = the back buffer

; ---- 1. the blink: PRESS ENTER lit at tick 0, gone at tick 12 ------------
        xor  al,al
        call VGA_CLS
        xor  ax,ax              ; tick 0: lit
        call TTLCARD
        mov  al,14
        mov  dx,166
        mov  si,199
        call CountRows
        mov  [lit],ax
        mov  dx,0
        mov  si,160
        call Sum
        mov  [sum1],ax
        xor  al,al
        call VGA_CLS
        mov  ax,12              ; tick 12: dark
        call TTLCARD
        mov  al,14
        mov  dx,166
        mov  si,199
        call CountRows
        or   ax,ax              ; nothing yellow down there now
        jnz  .f1
        cmp  word [lit],100     ; and a real line of letters before
        jb   .f1n
        mov  dx,0
        mov  si,160
        call Sum
        cmp  ax,[sum1]          ; the rest of the card the same
        jmp  .f1
.f1n:   or   al,1
.f1:    mov  si,m1
        call Rec

; ---- 2. the name centred (its ring both sides, its shadow 3 to the right) -
        mov  dx,15
        mov  si,58
        call Bounds             ; (the card from check 1 is still there)
        mov  ax,[minx]
        add  ax,[maxx]          ; left + right: 319 centred, +3 for the shadow
        cmp  ax,317
        jb   .f2n
        cmp  ax,325
        ja   .f2n
        cmp  word [minx],20     ; and it is big: more than 20 from each side
        jb   .f2n
        cmp  ax,ax
        jmp  .f2
.f2n:   or   al,1
.f2:    mov  si,m2
        call Rec

; ---- 3. TTLRUN: 10 ticks of the sky with the card, then AL = 0 ------------
        mov  word [ttlbg],Sky
        call TIM_TICK
        mov  [t0],ax
        mov  cx,10
        call TTLRUN
        mov  bl,al
        call TIM_TICK
        sub  ax,[t0]            ; AX = ticks it ran
        cmp  bl,0               ; it timed out?
        jne  .f3
        cmp  ax,10
        jb   .f3n
        cmp  ax,30              ; and not much more than it was given
        ja   .f3n
        cmp  ax,ax
        jmp  .f3
.f3n:   or   al,1
.f3:    mov  si,m3
        call Rec

; ---- 4. the score line on white: yellow digits, black ring, in its strip --
        mov  al,15
        call VGA_CLS
        mov  ax,120
        mov  cx,5000
        mov  dl,3
        call TTLHUD
        mov  al,14
        mov  dx,0
        mov  si,13
        call CountRows
        cmp  ax,60              ; five bold digits of yellow
        jb   .f4n
        mov  al,0
        call CountRows
        cmp  ax,100             ; and their dark rings
        jb   .f4n
        mov  al,15
        mov  dx,14
        mov  si,199
        call CountRows
        cmp  ax,186*320         ; everything below the strip untouched
        jne  .f4n
        cmp  ax,ax
        jmp  .f4
.f4n:   or   al,1
.f4:    mov  si,m4
        call Rec

; ---- the pictures: the title (lit), then the HUD over the sky -------------
        call Sky
        xor  ax,ax
        call TTLCARD
        call VGA_SHOW
        mov  dx,fShot
        call Hold
        call Sky
        mov  ax,1250
        mov  cx,48000
        mov  dl,1
        call TTLHUD
        call VGA_SHOW
        mov  dx,fShot2
        call Hold
        call VGA_OFF            ; text again, the buffer given back
        call Report
        mov  ax,4C00h
        int  21h

; ============================================================================
;  The test's helpers.
; ============================================================================
; Sky - a day: the sky's ramp, white clouds under the HUD, a sun, hills
Sky:    push ax
        push bx
        push cx
        push dx
        push si
        push di
        xor  di,di
        xor  dx,dx              ; DX = y
.y:     mov  bx,dx
        mov  cl,4
        shr  bx,cl              ; a band every 16 rows
        mov  al,[skyc+bx]
        mov  cx,320
        rep  stosb
        inc  dx
        cmp  dx,200
        jb   .y
        mov  si,clouds          ; the clouds: x, y, w, h, colour
.c:     lodsw
        cmp  ax,-1
        je   .sun
        mov  bx,ax
        lodsw
        mov  dx,ax
        lodsw
        mov  cx,ax
        lodsw
        mov  di,ax
        lodsb
        call Box
        jmp  .c
.sun:   pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
skyc    db 55,55,54,54,53,77,101,15,2,2,120,120,2   ; 13 bands of 16 rows
clouds  dw 10,0,90,9
        db 15
        dw 20,6,60,6
        db 15
        dw 120,2,70,8
        db 15
        dw 250,0,30,12
        db 14                   ; the sun right behind LIVES
        dw 240,4,50,6
        db 14
        dw 60,40,80,14
        db 15
        dw 200,60,90,10
        db 15
        dw 0,150,320,4
        db 48
        dw -1

; Box - colour AL, x BX, y DX, CX wide, DI high (all on the screen)
Box:    push ax
        push bx
        push cx
        push dx
        push si
        push di
        mov  si,di              ; SI = rows
.r:     push ax
        push cx
        mov  ax,dx
        mov  di,320
        push dx
        mul  di                 ; AX = y * 320
        pop  dx
        add  ax,bx
        mov  di,ax
        pop  cx
        pop  ax
        push cx
        rep  stosb
        pop  cx
        inc  dx
        dec  si
        jnz  .r
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; CountRows - AX = pixels of colour AL in rows DX..SI
CountRows:
        push bx
        push cx
        push dx
        push di
        mov  bl,al              ; BL = the colour
        push dx
        mov  ax,dx
        mov  di,320
        mul  di                 ; AX = y0 * 320
        mov  di,ax              ; DI = the first byte
        pop  dx
        mov  ax,si
        sub  ax,dx
        inc  ax                 ; AX = rows
        mov  cx,320
        mul  cx                 ; AX = rows * 320 (at most 64000)
        mov  cx,ax              ; CX = bytes
        xor  dx,dx              ; DX = the count
.l:     cmp  [es:di],bl
        jne  .n
        inc  dx
.n:     inc  di
        loop .l
        mov  ax,dx
        pop  di
        pop  dx
        pop  cx
        pop  bx
        ret

; Sum - AX = the sum of the bytes in rows DX..SI
Sum:    push bx
        push cx
        push dx
        push si
        push di
        mov  cx,si
        sub  cx,dx
        inc  cx                 ; CX = rows
        mov  ax,dx
        mov  bx,320
        mul  bx                 ; AX = y0 * 320
        mov  di,ax
        xor  bx,bx              ; BX = the sum
        xor  ah,ah
.r:     push cx
        mov  cx,320
.p:     mov  al,[es:di]
        add  bx,ax              ; sum += the byte
        inc  di
        loop .p
        pop  cx
        loop .r
        mov  ax,bx
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        ret

; Bounds - minx, maxx of the pixels that are not 0 in rows DX..SI
Bounds: push ax
        push bx
        push cx
        push dx
        push di
        mov  word [minx],320
        mov  word [maxx],0
        mov  ax,dx
        mov  cx,320
        push dx
        mul  cx                 ; AX = y0 * 320
        pop  dx
        mov  di,ax
.y:     xor  bx,bx              ; BX = x
.x:     cmp  byte [es:di],0
        je   .n
        cmp  bx,[minx]
        jae  .a
        mov  [minx],bx
.a:     cmp  bx,[maxx]
        jbe  .n
        mov  [maxx],bx
.n:     inc  di
        inc  bx
        cmp  bx,320
        jb   .x
        inc  dx
        cmp  dx,si
        jbe  .y
        pop  di
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; Rec - record a check: ZF = 1 passed; SI = its name ($-ended)
Rec:    push ax
        push bx
        mov  al,0
        jnz  .f
        mov  al,1
.f:     mov  bx,[nres]
        add  bx,bx
        add  bx,bx              ; four bytes a result
        mov  word [res+bx],si
        mov  [res+bx+2],al
        inc  word [nres]
        pop  bx
        pop  ax
        ret

; Report - the PASS/FAIL lines, by DOS
Report: mov  si,res
        mov  cx,[nres]
        jcxz .sum
.l:     mov  dx,sPass
        cmp  byte [si+2],1
        je   .p
        mov  dx,sFail
        mov  byte [bad],1
.p:     mov  ah,9
        int  21h
        mov  dx,[si]
        mov  ah,9
        int  21h
        mov  dx,sCrlf
        mov  ah,9
        int  21h
        add  si,4
        loop .l
.sum:   mov  dx,sAll
        cmp  byte [bad],0
        je   .s
        mov  dx,sSome
.s:     mov  ah,9
        int  21h
        ret

; Hold - SHOT file DX under /S; ~2 s by the tick under /AUTO, else until Esc
Hold:   call Shot
        cmp  byte [auto],0
        je   .key
        call TIM_TICK
        mov  bx,ax
.t:     call TIM_TICK
        sub  ax,bx              ; ticks gone
        cmp  ax,36
        jb   .t
        ret
.key:   xor  ah,ah
        int  16h
        cmp  al,27
        jne  .key
        ret

; IsAuto - [auto] = 1 for /AUTO, [shot] = 1 for /S
IsAuto: mov  si,81h
        mov  cl,[80h]
        xor  ch,ch
        jcxz .no
.l:     lodsb
        cmp  al,'/'
        jne  .n
        mov  al,[si]
        and  al,0DFh
        cmp  al,'A'
        jne  .s
        mov  byte [auto],1
.s:     cmp  al,'S'
        jne  .n
        mov  byte [shot],1
.n:     loop .l
.no:    ret

; Shot - under /S: the screen and the DAC into the file named at DX
Shot:   cmp  byte [shot],0
        je   .r
        push ds
        push es
        push dx
        mov  dx,3C7h
        xor  al,al
        out  dx,al
        mov  dx,3C9h
        mov  di,dac
        mov  cx,768
.p:     in   al,dx
        mov  [di],al
        inc  di
        loop .p
        pop  dx
        xor  cx,cx
        mov  ah,3Ch
        int  21h                ; create it
        jc   .x
        mov  bx,ax
        mov  ax,0A000h
        mov  ds,ax              ; DS = the screen
        xor  dx,dx
        mov  cx,64000
        mov  ah,40h
        int  21h
        pop  es
        pop  ds
        push ds
        push es
        mov  dx,dac
        mov  cx,768
        mov  ah,40h
        int  21h
        mov  ah,3Eh
        int  21h
.x:     pop  es
        pop  ds
.r:     ret

fShot   db 'SHOT.RAW',0
fShot2  db 'SHOT2.RAW',0
shot    db 0
auto    db 0
bad     db 0
nres    dw 0
res     db 4*8 dup(0)
lit     dw 0
sum1    dw 0
t0      dw 0
minx    dw 0
maxx    dw 0
sNoMem  db 'FTITLE: no memory for the back buffer',13,10,'$'
sPass   db 'PASS $'
sFail   db 'FAIL $'
sCrlf   db 13,10,'$'
sAll    db 'FTITLE: all checks PASS',13,10,'$'
sSome   db 'FTITLE: SOME CHECKS FAILED',13,10,'$'
m1      db 'TTLCARD blink: PRESS ENTER lit at tick 0, gone at 12, rest same$'
m2      db 'TTLCARD: the name centred, big$'
m3      db 'TTLRUN: 10 ticks over the sky, then AL = 0$'
m4      db 'TTLHUD on white: yellow digits, black ring, only its strip$'
dac     db 768 dup(0)

        include '..\..\KIT\REC\R_TITLE.ASM'
        include '..\..\KIT\LIB\K_FONT.INC'
        include '..\..\KIT\LIB\K_VGA.INC'
        include '..\..\KIT\LIB\K_MEM.INC'
        include '..\..\KIT\LIB\K_TIME.INC'
