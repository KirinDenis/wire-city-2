; ============================================================================
;  DDRAW.ASM - KIT test: K_DRAW.INC (2D drawing in mode 13h).
;
;      DDRAW          draws, checks, shows the picture until Esc
;      DDRAW /AUTO    the same, holds the picture ~2 s, prints PASS/FAIL
;      DDRAW /S       (with /AUTO or without) also writes SHOT.RAW: the screen + DAC
;
;  Every check draws on a cleared screen and READS THE PIXELS BACK out of
;  A000h: a box fills exactly w*h bytes, a shape half off the screen fills
;  only its visible part, a clipped line leaves every byte outside the clip
;  window alone, and the 1536 bytes past the screen's 64000 stay untouched.
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

Main:   cld
        call IsAuto             ; [auto] = 1 if /AUTO is on the command line
        mov  ax,0013h
        int  10h                ; 320x200, a byte a pixel
        mov  ax,0A000h
        mov  es,ax              ; ES = the screen
        mov  word [es:64000],0A55Ah ; a sentinel past the last pixel

; ---- 1. DRW_RECT fills exactly w*h ------------------------------------------
        call Clear
        mov  byte [drw_col],5
        mov  ax,10
        mov  bx,10
        mov  cx,30
        mov  dx,20
        call DRW_RECT
        mov  al,5
        call Count
        cmp  ax,600             ; 30 * 20
        mov  si,mRect
        call Rec

; ---- 2. a box half off the top left, and one off the bottom right ---------
        call Clear
        mov  ax,-10
        mov  bx,-5
        mov  cx,30
        mov  dx,20
        call DRW_RECT           ; 20 x 15 of it on the screen
        mov  ax,300
        mov  bx,190
        mov  cx,50
        mov  dx,50
        call DRW_RECT           ; 20 x 10 of it
        mov  al,5
        call Count
        cmp  ax,300+200
        mov  si,mRclip
        call Rec

; ---- 3. pixels: only the one on the screen lands ---------------------------
        call Clear
        mov  byte [drw_col],6
        mov  ax,-1
        xor  bx,bx
        call DRW_PIXEL
        mov  ax,320
        call DRW_PIXEL
        xor  ax,ax
        mov  bx,200
        call DRW_PIXEL
        mov  bx,-1
        call DRW_PIXEL
        mov  ax,319
        mov  bx,199
        call DRW_PIXEL          ; the last pixel: this one is on
        mov  al,6
        call Count
        cmp  ax,1
        mov  si,mPix
        call Rec

; ---- 4. h-line and v-line cut at the edges; a frame's outline --------------
        call Clear
        mov  ax,-5
        mov  bx,50
        mov  cx,20
        call DRW_HLINE          ; 15 on
        mov  ax,100
        mov  bx,190
        mov  cx,20
        call DRW_VLINE          ; 10 on
        mov  ax,20
        mov  bx,20
        mov  cx,10
        mov  dx,5
        call DRW_FRAME          ; 2*10 + 2*5 - 4 = 26
        mov  al,6
        call Count
        cmp  ax,15+10+26
        mov  si,mLines
        call Rec

; ---- 5. a line from far left to far right: exactly 320 pixels --------------
        call Clear
        mov  byte [drw_col],7
        mov  ax,-50
        mov  bx,100
        mov  cx,400
        mov  dx,150
        call DRW_LINE
        mov  al,7
        call Count
        cmp  ax,320
        mov  si,mLine
        call Rec

; ---- 6. a clip window: nothing lands outside it -----------------------------
        call Clear
        mov  ax,100
        mov  bx,50
        mov  cx,199
        mov  dx,149
        call DRW_CLIP           ; the window 100..199 x 50..149
        xor  ax,ax
        xor  bx,bx
        mov  cx,319
        mov  dx,199
        call DRW_LINE           ; corner to corner, through the window
        mov  ax,-30
        mov  bx,120
        mov  cx,600
        mov  dx,60
        call DRW_LINE           ; across, ends far outside
        mov  ax,150
        mov  bx,100
        mov  cx,80
        call DRW_DISC           ; a disc bigger than the window
        call DRW_NOCLIP
        mov  al,7
        call Count
        mov  [inside],ax        ; what landed (all of it must be inside)
        mov  byte [drw_col],0
        mov  ax,100
        mov  bx,50
        mov  cx,100
        mov  dx,100
        call DRW_RECT           ; wipe the window
        mov  al,7
        call Count              ; AX = what was outside: must be 0
        cmp  word [inside],100  ; and something was drawn inside
        jb   .w0
        or   ax,ax
.w0:    mov  si,mWin
        call Rec

; ---- 7. a line wholly outside draws nothing ---------------------------------
        call Clear
        mov  byte [drw_col],7
        mov  ax,-100
        mov  bx,-100
        mov  cx,-10
        mov  dx,-50
        call DRW_LINE
        mov  ax,330
        mov  bx,-20
        mov  cx,330
        mov  dx,250
        call DRW_LINE
        mov  al,7
        call Count
        or   ax,ax
        mov  si,mLout
        call Rec

; ---- 8. disc and circle: the edge where it should be, aspect-squashed ------
        call Clear
        mov  byte [drw_col],9
        mov  ax,160
        mov  bx,100
        mov  cx,40
        call DRW_DISC           ; across 40, down 40*213/256 = 33
        mov  ax,160
        mov  bx,100
        call Peek               ; the centre
        cmp  al,9
        jne  .d0
        mov  ax,200
        call Peek               ; the right edge, on
        cmp  al,9
        jne  .d0
        mov  ax,201
        call Peek               ; one past it, off
        cmp  al,0
        jne  .d0
        mov  ax,160
        mov  bx,67
        call Peek               ; the top: 100 - 33, on
        cmp  al,9
        jne  .d0
        mov  bx,66
        call Peek               ; one above, off
        cmp  al,0
.d0:    mov  si,mDisc
        call Rec

        call Clear
        mov  byte [drw_col],10
        mov  ax,160
        mov  bx,100
        mov  cx,40
        call DRW_CIRCLE
        mov  ax,200
        mov  bx,100
        call Peek               ; the right edge, on
        cmp  al,10
        jne  .c0
        mov  ax,120
        call Peek               ; the left edge, on
        cmp  al,10
        jne  .c0
        mov  ax,160
        mov  bx,133
        call Peek               ; the bottom, on
        cmp  al,10
        jne  .c0
        mov  bx,100
        call Peek               ; the centre, off: a ring
        cmp  al,0
.c0:    mov  si,mCirc
        call Rec

; ---- 9. a disc on the corner: clipped, the sentinel past 64000 kept --------
        call Clear
        mov  byte [drw_col],9
        mov  ax,310
        mov  bx,195
        mov  cx,60
        call DRW_DISC
        mov  ax,5
        mov  bx,5
        mov  cx,60
        call DRW_CIRCLE
        cmp  word [es:64000],0A55Ah
        mov  si,mSent
        call Rec

; ---- 10. a polygon square: rows 10..39 (the bottom left out), x 10..50 ------
        call Clear
        mov  byte [drw_col],11
        mov  si,square
        mov  cx,4
        call DRW_POLY
        mov  al,11
        call Count
        cmp  ax,30*41
        mov  si,mPoly
        call Rec

; ---- 11. a triangle: in where it should be, out where it should not --------
        call Clear
        mov  byte [drw_col],12
        mov  ax,0
        mov  bx,0
        mov  cx,100
        mov  dx,0
        mov  si,0
        mov  di,100
        call DRW_TRI
        mov  ax,10
        mov  bx,10
        call Peek
        cmp  al,12
        jne  .t0
        mov  ax,90
        mov  bx,90
        call Peek
        cmp  al,0
.t0:    mov  si,mTri
        call Rec

; ---- 12. dither at half: exactly half of a 16x16 box each shade ------------
        call Clear
        mov  byte [drw_col],1
        mov  byte [drw_col2],2
        mov  byte [drw_frac],128
        xor  ax,ax
        xor  bx,bx
        mov  cx,16
        mov  dx,16
        call DRW_DITHER
        mov  al,2
        call Count
        cmp  ax,128
        jne  .h0
        mov  al,1
        call Count
        cmp  ax,128
.h0:    mov  si,mDith
        call Rec

; ---- 13. gradient: the top row pure top colour, the bottom near the end -----
        call Clear
        mov  byte [drw_col],16
        mov  byte [drw_col2],31
        xor  ax,ax
        xor  bx,bx
        mov  cx,10
        mov  dx,32
        call DRW_GRADV
        xor  ax,ax
        xor  bx,bx
        call Peek               ; the top row: pure 16
        cmp  al,16
        jne  .g0
        mov  ax,9
        call Peek
        cmp  al,16
        jne  .g0
        xor  ax,ax
        mov  bx,31
        call Peek
        cmp  al,30
        jb   .g1
        cmp  al,31
        ja   .g1
        cmp  al,al              ; 30 or 31: ZF = 1
        jmp  .g0
.g1:    or   sp,sp              ; ZF = 0
.g0:    mov  si,mGrad
        call Rec

; ---- the picture: everything at once ----------------------------------------
        call Clear
        mov  byte [drw_col],16
        mov  byte [drw_col2],31
        xor  ax,ax
        xor  bx,bx
        mov  cx,320
        mov  dx,200
        call DRW_GRADV          ; the sky
        mov  byte [drw_col],2
        mov  byte [drw_col2],10
        mov  byte [drw_frac],100
        xor  ax,ax
        mov  bx,150
        mov  cx,320
        mov  dx,50
        call DRW_DITHER         ; the grass
        mov  byte [drw_col],14
        mov  ax,260
        mov  bx,40
        mov  cx,25
        call DRW_DISC           ; the sun
        mov  byte [drw_col],12
        mov  ax,260
        mov  bx,40
        mov  cx,32
        call DRW_CIRCLE         ; its ring
        mov  byte [drw_col],6
        mov  ax,40
        mov  bx,100
        mov  cx,80
        mov  dx,50
        call DRW_RECT           ; a house
        mov  byte [drw_col],4
        mov  ax,30
        mov  bx,100
        mov  cx,80
        mov  dx,60
        mov  si,130
        mov  di,100
        call DRW_TRI            ; its roof
        mov  byte [drw_col],15
        mov  ax,40
        mov  bx,100
        mov  cx,80
        mov  dx,50
        call DRW_FRAME
        mov  byte [drw_col],13
        mov  si,penta
        mov  cx,5
        call DRW_POLY           ; a kite
        mov  byte [drw_col],15
        mov  cx,0
.fan:   push cx
        mov  ax,160
        mov  bx,190
        mov  dx,0
        call DRW_LINE           ; a fan of lines off the top
        pop  cx
        add  cx,40
        cmp  cx,321
        jb   .fan

        call Hold               ; ~2 s under /AUTO, else until Esc
        mov  ax,0003h
        int  10h                ; text again
        call Report
        mov  ax,4C00h
        int  21h

square  dw 10,10, 50,10, 50,40, 10,40
penta   dw 180,90, 210,110, 200,140, 160,140, 150,110
inside  dw 0
mRect   db 'DRW_RECT fills exactly 30*20 = 600 pixels$'
mRclip  db 'DRW_RECT clipped at both corners: 300 + 200$'
mPix    db 'DRW_PIXEL: four off-screen pixels skipped, one drawn$'
mLines  db 'DRW_HLINE/VLINE clipped, DRW_FRAME 26: 51 pixels$'
mLine   db 'DRW_LINE from x -50 to 400: exactly 320 pixels$'
mWin    db 'DRW_CLIP window: nothing lands outside it$'
mLout   db 'DRW_LINE wholly off the screen draws nothing$'
mDisc   db 'DRW_DISC edge at r across, r*213/256 down$'
mCirc   db 'DRW_CIRCLE edges on, centre empty$'
mSent   db 'shapes past the corner: bytes past 64000 untouched$'
mPoly   db 'DRW_POLY square: 30 rows * 41 = 1230 pixels$'
mTri    db 'DRW_TRI: inside drawn, outside empty$'
mDith   db 'DRW_DITHER at 128: 128 of each shade in 16*16$'
mGrad   db 'DRW_GRADV: the top row pure, the bottom row near the end$'

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
sAll    db 'DDRAW: all checks PASS',13,10,'$'
sSome   db 'DDRAW: SOME CHECKS FAILED',13,10,'$'

        include '..\..\KIT\LIB\K_DRAW.INC'
