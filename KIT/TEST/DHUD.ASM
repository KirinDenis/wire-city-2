; ============================================================================
;  DHUD.ASM - KIT test: the recipe REC\R_HUD.ASM (bar gauge, blink, popups).
;
;      DHUD           draws, checks, shows the HUD until Esc (it lives:
;                     the gauge drains, the warning blinks, popups rise)
;      DHUD /AUTO     the checks, ~2 s of the live HUD, PASS/FAIL lines
;      DHUD /S       (with /AUTO or without) also writes SHOT.RAW: the screen + DAC
;
;  The recipe is included whole, as a program that copied it would hold it.
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

Main:   cld
        call IsAuto             ; [auto] = 1 if /AUTO is on the command line
        mov  ax,0013h
        int  10h                ; 320x200, a byte a pixel
        mov  ax,0A000h
        mov  es,ax              ; ES = the screen

; ---- 1. the gauge: half lit green, the rest dark; yellow, red, clamps ------
        call Clear
        mov  ax,10
        mov  bx,10
        mov  cx,50
        mov  dx,100
        call HUDBAR             ; 5 of 10 lit
        mov  al,10
        call Count
        cmp  ax,5*30            ; 5 segments of 6x5, green
        jne  .g0
        mov  al,8
        call Count
        cmp  ax,5*30            ; 5 dark
        jne  .g0
        call Clear
        mov  ax,10
        mov  bx,10
        mov  cx,20
        mov  dx,100
        call HUDBAR             ; 2 lit: under half, yellow
        mov  al,14
        call Count
        cmp  ax,2*30
        jne  .g0
        call Clear
        mov  ax,10
        mov  cx,10
        call HUDBAR             ; 1 lit: under a quarter, red
        mov  al,12
        call Count
        cmp  ax,30
        jne  .g0
        call Clear
        mov  ax,10
        mov  cx,1
        mov  dx,1000
        call HUDBAR             ; a little left still shows one segment
        mov  al,12
        call Count
        cmp  ax,30
.g0:    mov  si,mBar
        call Rec

        call Clear
        mov  ax,10
        mov  bx,10
        mov  cx,500
        mov  dx,100
        call HUDBAR             ; over full: all 10, no overflow
        mov  al,10
        call Count
        cmp  ax,10*30
        jne  .z0
        call Clear
        mov  ax,10
        mov  bx,10
        mov  cx,5
        xor  dx,dx
        call HUDBAR             ; a full of 0: empty, no divide fault
        mov  al,8
        call Count
        cmp  ax,10*30
.z0:    mov  si,mBarz
        call Rec

; ---- 2. the blink: 55 of 73 ticks lit ---------------------------------------
        xor  ax,ax
        call HUDBLINK
        jnc  .b0
        mov  ax,54
        call HUDBLINK
        jnc  .b0
        mov  ax,55
        call HUDBLINK
        jc   .b0
        mov  ax,72
        call HUDBLINK
        jc   .b0
        mov  ax,73
        call HUDBLINK
        jnc  .b0
        mov  ax,65535
        call HUDBLINK           ; 65535 mod 73 = 54: lit, no overflow
        jnc  .b0
        call Clear
        mov  si,sWarn
        mov  dx,50
        mov  ax,60
        call HUDWARN            ; dark part: nothing
        mov  al,12
        call Count
        or   ax,ax
        jnz  .b0
        mov  ax,10
        call HUDWARN            ; lit part: red letters
        mov  al,12
        call Count
        or   ax,ax
        jz   .b0
        cmp  al,al
        jmp  .b1
.b0:    or   sp,sp
.b1:    mov  si,mBlink
        call Rec

; ---- 3. a popup rises, and goes --------------------------------------------
        call Clear
        mov  ax,100             ; tick 100
        mov  cx,25
        mov  bx,160
        mov  dx,100             ; its bottom at y 100
        call HUDPOPADD
        mov  ax,100
        call HUDPOPDRAW         ; age 0: letters on rows 95..99
        mov  al,14
        mov  bx,95
        mov  dx,99
        call CountRows
        or   ax,ax
        jz   .p0
        call Clear
        mov  ax,115
        call HUDPOPDRAW         ; age 15: risen 5, rows 90..94
        mov  al,14
        mov  bx,95
        mov  dx,99
        call CountRows          ; nothing gold left at the old rows
        or   ax,ax
        jnz  .p0
        mov  al,14
        mov  bx,90
        mov  dx,94
        call CountRows
        or   ax,ax
        jz   .p0
        call Clear
        mov  ax,129
        call HUDPOPDRAW         ; age 29: gone, its slot free
        mov  al,14
        call Count
        or   ax,ax
        jnz  .p0
        cmp  word [hudpops+6],0
        jne  .p0
        call Clear
        mov  ax,200
        mov  cx,-7
        mov  bx,100
        mov  dx,100
        call HUDPOPADD          ; a loss
        call HUDPOPDRAW
        mov  al,12
        call Count              ; red
        or   ax,ax
        jz   .p0
        cmp  al,al
        jmp  .p1
.p0:    or   sp,sp
.p1:    mov  si,mPop
        call Rec

; ---- 4. nine popups in eight slots: the oldest gives way -------------------
        mov  di,hudpops         ; all free
        mov  cx,HUDPOPN*HUDPOPS
        xor  al,al
.cl:    mov  [di],al
        inc  di
        loop .cl
        xor  ax,ax              ; ticks 300..308
.ad:    push ax
        add  ax,300
        mov  cx,5
        mov  bx,50
        mov  dx,50
        call HUDPOPADD
        pop  ax
        inc  ax
        cmp  ax,9
        jb   .ad
        mov  si,hudpops         ; the one of tick 300 must be gone
        xor  cx,cx              ; CX = slots still at 300
        xor  dx,dx              ; DX = slots busy
.sc:    cmp  word [si+6],0
        je   .sn
        inc  dx
        cmp  word [si],300
        jne  .sn
        inc  cx
.sn:    add  si,HUDPOPS
        cmp  si,hudpops+HUDPOPN*HUDPOPS
        jb   .sc
        cmp  dx,8
        jne  .o0
        or   cx,cx
.o0:    mov  si,mFull
        call Rec

; ---- the live HUD: ~2 s under /AUTO (until Esc without it) -----------------
        mov  di,hudpops
        mov  cx,HUDPOPN*HUDPOPS
        xor  al,al
.c2:    mov  [di],al
        inc  di
        loop .c2
        mov  word [hudbper],18  ; the demo blinks once a second
        mov  word [hudbon],12
        call Tick
        mov  [t0],ax
        mov  [tlast],ax
.live:  call Tick
        mov  [now],ax
        sub  ax,[t0]
        cmp  byte [auto],0
        je   .nk
        cmp  ax,40              ; ~2 s
        jb   .nk
        jmp  .out
.nk:    mov  ax,[now]
        cmp  ax,[tlast]
        je   .key               ; a new picture only on a new tick
        mov  [tlast],ax
        call Clear
        mov  ax,[now]
        sub  ax,[t0]            ; AX = ticks since the start
        and  ax,127             ; the fuel drains and fills again
        mov  cx,127
        sub  cx,ax              ; CX = the fuel
        mov  dx,127             ; of 127
        mov  ax,20
        mov  bx,20
        mov  word [hudnseg],20
        call HUDBAR
        mov  word [hudnseg],10
        mov  si,sFuel
        mov  bx,20
        mov  dx,12
        mov  byte [txt_font],1
        mov  byte [txt_col],15
        call TXT_PUT
        mov  byte [txt_font],0
        cmp  cx,32              ; low fuel: the warning
        jae  .nw
        mov  si,sLow
        mov  dx,90
        mov  ax,[now]
        call HUDWARN
.nw:    mov  ax,[now]
        and  ax,7               ; a popup every 8 ticks
        jnz  .np
        mov  ax,[now]
        mov  bx,ax
        and  bx,127
        add  bx,96              ; somewhere across
        mov  cx,ax
        and  cx,31
        sub  cx,8               ; -8..23
        jnz  .pz
        inc  cx                 ; never 0 (0 is a free slot)
.pz:    mov  dx,170
        call HUDPOPADD
.np:    mov  ax,[now]
        call HUDPOPDRAW
.key:   cmp  byte [auto],0
        jne  .live
        mov  ah,1
        int  16h                ; a key waiting?
        jz   .live
        xor  ah,ah
        int  16h
        cmp  al,27              ; Esc?
        je   .out
        jmp  .live
.out:   call Shot
        mov  ax,0003h
        int  10h                ; text again
        call Report
        mov  ax,4C00h
        int  21h

; Tick - AX = the BIOS tick
Tick:   push es
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:046Ch]
        pop  es
        ret

; CountRows - AX = pixels of colour AL in rows BX..DX
CountRows:
        push bx
        push cx
        push dx
        push di
        push ax                 ; the colour
        sub  dx,bx
        inc  dx                 ; DX = rows
        mov  ax,320
        mul  dx                 ; AX = rows * 320: the bytes
        mov  cx,ax
        mov  ax,320
        mul  bx                 ; AX = first row * 320
        mov  di,ax
        pop  ax
        xor  dx,dx              ; DX = the count
.l:     repne scasb
        jne  .e
        inc  dx
        jcxz .e
        jmp  .l
.e:     mov  ax,dx
        pop  di
        pop  dx
        pop  cx
        pop  bx
        ret

t0      dw 0
tlast   dw 0
now     dw 0
sWarn   db 'WARNING',0
sLow    db 'LOW FUEL',0
sFuel   db 'FUEL',0
mBar    db 'HUDBAR: 5 of 10 green, 2 yellow, 1 red, a little shows$'
mBarz   db 'HUDBAR: over full clamps, a full of 0 is empty, no fault$'
mBlink  db 'HUDBLINK 55 of 73, tick 65535 safe; HUDWARN only when lit$'
mPop    db 'HUDPOP: rises a pixel every 3 ticks, gone at 29, red loss$'
mFull   db 'HUDPOPADD: nine in eight slots, the oldest gives way$'

; ============================================================================
;  The test's own helpers (the same in every D test).
; ============================================================================
; Clear - the screen black
Clear:  push ax
        push cx
        push di
        xor  di,di
        xor  ax,ax
        mov  cx,32000           ; 64000 bytes as words
        rep  stosw
        pop  di
        pop  cx
        pop  ax
        ret

; Count - AX = how many of the 64000 pixels are colour AL
Count:  push cx
        push dx
        push di
        xor  di,di
        mov  cx,64000
        xor  dx,dx              ; DX = the count
.l:     repne scasb             ; on to the next byte equal to AL
        jne  .e                 ; none left
        inc  dx                 ; one more
        jcxz .e                 ; that was the last byte
        jmp  .l
.e:     mov  ax,dx
        pop  di
        pop  dx
        pop  cx
        ret

; Peek - AL = the pixel at (AX,BX)
Peek:   push di
        push bx
        push cx
        mov  di,bx
        mov  cl,8
        shl  di,cl              ; DI = y * 256
        mov  cl,6
        shl  bx,cl              ; BX = y * 64
        add  di,bx              ; DI = y * 320
        add  di,ax              ; DI = y * 320 + x
        mov  al,[es:di]
        pop  cx
        pop  bx
        pop  di
        ret

; Rec - record a check: ZF = 1 passed; SI = its name ($-ended)
Rec:    push ax
        push bx
        mov  al,0
        jnz  .f
        mov  al,1
.f:     mov  bx,[nres]
        add  bx,bx              ; BX = 2 * n
        add  bx,bx              ; BX = 4 * n: four bytes a result
        mov  word [res+bx],si
        mov  [res+bx+2],al
        inc  word [nres]
        pop  bx
        pop  ax
        ret

; Report - the PASS/FAIL lines, by DOS (they go to NAME.OUT under RUNWIN)
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

; Hold - ~2 s by the BIOS tick under /AUTO; else until Esc
Hold:   call Shot
        cmp  byte [auto],0
        je   .key
        push es
        xor  ax,ax
        mov  es,ax
        mov  bx,[es:046Ch]      ; BX = the tick now
.t:     mov  ax,[es:046Ch]
        sub  ax,bx              ; AX = ticks gone
        cmp  ax,36              ; ~2 s?
        jb   .t
        pop  es
        ret
.key:   xor  ah,ah
        int  16h                ; wait for a key
        cmp  al,27              ; Esc?
        jne  .key
        ret

; IsAuto - [auto] = 1 if the command line holds /A (/AUTO), [shot] = 1 for /S
IsAuto: mov  si,81h
        mov  cl,[80h]
        xor  ch,ch              ; CX = the tail's length
        jcxz .no
.l:     lodsb
        cmp  al,'/'
        jne  .n
        mov  al,[si]
        and  al,0DFh            ; capital
        cmp  al,'A'
        jne  .s
        mov  byte [auto],1
.s:     cmp  al,'S'
        jne  .n
        mov  byte [shot],1
.n:     loop .l
.no:    ret

; Shot - under /S: the screen (64000 bytes) and the DAC (768) into SHOT.RAW,
; for a look at the picture from outside DOS
Shot:   cmp  byte [shot],0
        je   .r
        push ds
        mov  dx,3C7h
        xor  al,al
        out  dx,al              ; read the DAC from entry 0
        mov  dx,3C9h
        mov  di,dac
        mov  cx,768
.p:     in   al,dx
        mov  [di],al
        inc  di
        loop .p
        mov  dx,fShot
        xor  cx,cx
        mov  ah,3Ch
        int  21h                ; create SHOT.RAW
        jc   .x
        mov  bx,ax
        push es
        pop  ds                 ; DS = the screen
        xor  dx,dx
        mov  cx,64000
        mov  ah,40h
        int  21h                ; the pixels
        pop  ds
        push ds
        mov  dx,dac
        mov  cx,768
        mov  ah,40h
        int  21h                ; the palette
        mov  ah,3Eh
        int  21h
.x:     pop  ds
.r:     ret
fShot   db 'SHOT.RAW',0
shot    db 0
dac     db 768 dup(0)

auto    db 0
bad     db 0
nres    dw 0
res     db 4*40 dup(0)
sPass   db 'PASS $'
sFail   db 'FAIL $'
sCrlf   db 13,10,'$'
sAll    db 'DHUD: all checks PASS',13,10,'$'
sSome   db 'DHUD: SOME CHECKS FAILED',13,10,'$'


        include '..\..\KIT\REC\R_HUD.ASM'
        include '..\..\KIT\LIB\K_DRAW.INC'
        include '..\..\KIT\LIB\K_TEXT.INC'
