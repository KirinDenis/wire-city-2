; ============================================================================
;  PMOUSE.ASM - KIT test: K_MOUSE.INC (INT 33h in mode 13h, the cursor
;  drawn by hand with its save-under, the keyboard as a mouse).
;
;      PMOUSE         checks, then shows pointers on a pattern until Esc
;      PMOUSE /AUTO   the same, the picture held ~2 s, PASS/FAIL printed
;
;  With a mouse driver (DOSBox has one): a position set comes back from the
;  driver halved exactly, the range holds. Without one those checks say so
;  and pass on the keyboard path alone. Every cursor drawn and taken down -
;  in a corner, cut by every edge, the hand's hot point off the left -
;  leaves the screen byte for byte as it was.
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

EDGE    = 200                   ; the pointer's colours in this test: none
INK     = 201                   ; of the pattern's checks can mistake them

Main:   cld
        call IsAuto
        mov  ax,0013h
        int  10h
        mov  ax,0A000h
        mov  es,ax
        mov  byte [mou_edge],EDGE
        mov  byte [mou_ink],INK

; ---- 1. the driver: a position set comes back halved; the range holds -------
        call MOU_INIT
        jc   .nod
        mov  byte [drv],1
        mov  ax,123
        mov  bx,77
        call MOU_SET
        call MOU_READ
        cmp  ax,123
        jne  .d0
        cmp  bx,77
        jne  .d0
        mov  ax,319             ; the last column: 638 in the driver
        mov  bx,199
        call MOU_SET
        call MOU_READ
        cmp  ax,319
        jne  .d0
        cmp  bx,199
        jne  .d0
        mov  ax,10
        mov  bx,20
        mov  cx,100
        mov  dx,120
        call MOU_RANGE          ; the pointer pulled inside: (100,120)
        mov  ax,300
        mov  bx,5
        call MOU_SET            ; outside: kept at (100,20)
        call MOU_READ
        cmp  ax,100
        jne  .d0
        cmp  bx,20
        jne  .d0
        xor  ax,ax
        xor  bx,bx
        mov  cx,319
        mov  dx,199
        call MOU_RANGE
        cmp  ax,ax
        call PassZ
.d0:    mov  si,mDrv
        call ChkOk
        jmp  .keys
.nod:   mov  si,mNoDrv          ; no driver: noted, not failed
        cmp  ax,ax
        call Chk

; ---- 2. the keys move the pointer, clamp it, latch a click -------------------
.keys:  mov  ax,50
        mov  bx,50
        call MOU_SET
        mov  ah,4Dh             ; right
        call MOU_KEYS
        jnc  .k0
        mov  ah,48h             ; up
        call MOU_KEYS
        jnc  .k0
        cmp  word [mou_x],54
        jne  .k0
        cmp  word [mou_y],46
        jne  .k0
        mov  ax,1
        mov  bx,1
        call MOU_SET
        mov  ah,4Bh             ; left past the edge
        call MOU_KEYS
        cmp  word [mou_x],0
        jne  .k0
        mov  ah,01h             ; Esc: not the pointer's
        call MOU_KEYS
        jc   .k0
        call MOU_READ           ; and the driver was kept in step
        cmp  ax,0
        jne  .k0
        cmp  bx,1
        call PassZ
.k0:    mov  si,mKeys
        call ChkOk

        mov  ax,5555h
        mov  bx,6666h
        call MOU_CLICK          ; nothing pressed yet
        jc   .c0
        cmp  ax,5555h
        jne  .c0
        cmp  bx,6666h
        jne  .c0
        mov  ax,30
        mov  bx,40
        call MOU_SET
        mov  ah,1Ch             ; Enter
        call MOU_KEYS
        jnc  .c0
        call MOU_CLICK          ; the latched click, where the pointer is
        jnc  .c0
        cmp  ax,30
        jne  .c0
        cmp  bx,40
        jne  .c0
        call MOU_CLICK          ; consumed: once only
        jc   .c0
        cmp  ax,ax
        call PassZ
.c0:    mov  si,mClick
        call ChkOk

; ---- 3. the cursor: drawn, its hot point coloured, taken down byte-exact -----
        call Pattern
        mov  word [mou_shape],MOU_ARROW16
        mov  ax,100
        mov  bx,100
        call MOU_SET
        call Regs
        call MOU_CURDRAW
        call RegsSame
        jne  .a0
        mov  ax,100
        mov  bx,100
        call Peek
        cmp  al,EDGE            ; the tip: outline
        jne  .a0
        mov  ax,101
        mov  bx,102
        call Peek
        cmp  al,INK             ; inside: fill
        jne  .a0
        call MOU_CURHIDE
        call Same               ; ZF = the pattern untouched
        call PassZ
.a0:    mov  si,mDraw
        call ChkOk

        ; at every edge, the hand cut off the left, drawn over itself
        mov  ax,318
        mov  bx,198
        call MOU_SET
        call MOU_CURDRAW        ; 2x2 of it on the screen
        mov  ax,319
        mov  bx,199
        call Peek
        cmp  al,INK             ; the arrow's (1,1)
        jne  .e0
        cmp  word [mou_sw],2
        jne  .e0
        call MOU_CURHIDE
        call Same
        jne  .e0
        mov  word [mou_shape],MOU_HAND16 ; hot point (5,0)
        mov  ax,2
        xor  bx,bx
        call MOU_SET
        call MOU_CURDRAW
        mov  ax,2
        xor  bx,bx
        call Peek
        cmp  al,EDGE            ; the fingertip at the hot point
        jne  .e0
        cmp  word [mou_sw],13   ; 3 columns cut off
        jne  .e0
        mov  ax,319
        mov  bx,199
        call MOU_SET
        call MOU_CURDRAW        ; drawn again elsewhere: the first taken down
        mov  word [mou_shape],MOU_ARROW8
        mov  ax,0
        mov  bx,195
        call MOU_SET
        call MOU_CURDRAW
        call MOU_CURHIDE
        call MOU_CURHIDE        ; twice: the second does nothing
        call Same
        call PassZ
.e0:    mov  si,mEdges
        call ChkOk

; ---- the picture: pointers on the pattern, held ---------------------------
        mov  byte [mou_edge],0
        mov  byte [mou_ink],15
        mov  si,shapes
        mov  cx,4
        mov  ax,60
.p1:    push ax
        mov  bx,90
        call MOU_SET
        lodsw
        mov  [mou_shape],ax
        mov  byte [mou_on],0    ; leave each one standing
        call MOU_CURDRAW
        pop  ax
        add  ax,60              ; the next one to the right
        loop .p1
        call Hold
        mov  ax,0003h
        int  10h
        call Report
        mov  ax,4C00h
        int  21h

; Pattern - every pixel = low byte of its offset + high byte (never 0..15
; in a way the checks rely on)
Pattern:
        xor  di,di
        mov  cx,64000
.l:     mov  ax,di
        add  al,ah              ; the pixel's pattern byte
        stosb
        loop .l
        ret

; Same - ZF = 1 if the whole screen is still the pattern
Same:   push ax
        push cx
        push di
        xor  di,di
        mov  cx,64000
.l:     mov  ax,di
        add  al,ah
        cmp  al,[es:di]
        jne  .o
        inc  di
        loop .l
        cmp  ax,ax
.o:     pop  di
        pop  cx
        pop  ax
        ret

; Peek - AL = the screen's pixel at (AX,BX)
Peek:   push bx
        push cx
        push di
        mov  di,bx
        mov  cl,8
        shl  di,cl              ; y * 256
        mov  cl,6
        shl  bx,cl              ; y * 64
        add  di,bx              ; y * 320
        add  di,ax              ; + x
        mov  al,[es:di]
        pop  di
        pop  cx
        pop  bx
        ret

drv     db 0
shapes  dw MOU_ARROW8,MOU_ARROW16,MOU_HAND8,MOU_HAND16
mDrv    db 'MOU_SET/MOU_READ 123,77 and 319,199 back halved; MOU_RANGE holds$'
mNoDrv  db 'MOU_INIT no mouse driver: CF (the driver checks skipped)$'
mKeys   db 'MOU_KEYS arrows move by mou_step, clamp at 0, Esc not ours$'
mClick  db 'MOU_CLICK none: CF 0, AX BX kept; Enter latched once, at the pointer$'
mDraw   db 'MOU_CURDRAW tip outline, inside fill, registers kept; HIDE exact$'
mEdges  db 'MOU_CURDRAW cut at right/bottom/left (hand), redrawn: screen exact$'

; ---- the test's own harness ---------------------------------------------
; PassZ - ZF = 1: this check passed so far ([okf] = 1). All kept.
PassZ:  jnz  .o
        mov  byte [okf],1
.o:     ret

; ChkOk - record [okf] as the result (SI = its name), then [okf] = 0
ChkOk:  cmp  byte [okf],1
        mov  byte [okf],0       ; (flags kept)
        jmp  Chk

; Chk - record one result: ZF = 1 PASS, SI = its name ($-ended). All kept.
Chk:    push ax
        push bx
        mov  al,0
        jnz  .f
        mov  al,1
.f:     mov  bx,[nres]
        shl  bx,1
        shl  bx,1               ; four bytes a result
        mov  [res+bx],si
        mov  byte [res+bx+2],al
        inc  word [nres]
        pop  bx
        pop  ax
        ret

; Report - the PASS/FAIL lines by DOS (to NAME.OUT under RUNWIN)
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

; IsAuto - [auto] = 1 if the command line holds /A (/AUTO)
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
        jne  .n
        mov  byte [auto],1
.n:     loop .l
.no:    ret

; Hold - ~2 s by the BIOS tick under /AUTO; else until Esc
Hold:   cmp  byte [auto],0
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

; Regs / RegsSame - snapshot BX CX DX SI DI BP ES, compare: ZF = 1 same
Regs:   mov  [rg],bx
        mov  [rg+2],cx
        mov  [rg+4],dx
        mov  [rg+6],si
        mov  [rg+8],di
        mov  [rg+10],bp
        mov  [rg+12],es
        ret
RegsSame:
        cmp  [rg],bx
        jne  .o
        cmp  [rg+2],cx
        jne  .o
        cmp  [rg+4],dx
        jne  .o
        cmp  [rg+6],si
        jne  .o
        cmp  [rg+8],di
        jne  .o
        cmp  [rg+10],bp
        jne  .o
        push ax
        mov  ax,es
        cmp  [rg+12],ax
        pop  ax
.o:     ret

auto    db 0
okf     db 0
bad     db 0
nres    dw 0
rg      dw 7 dup(0)
res     dw 2*80 dup(0)
sPass   db 'PASS $'
sFail   db 'FAIL $'
sCrlf   db 13,10,'$'
sAll    db 'ALL PASS',13,10,'$'
sSome   db 'SOME FAILED',13,10,'$'

        include '..\..\KIT\LIB\K_MOUSE.INC'
