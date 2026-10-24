; ============================================================================
;  DSPR.ASM - KIT test: K_SPR.INC (text-art sprites in mode 13h).
;
;      DSPR           draws, checks, shows the picture until Esc
;      DSPR /AUTO     the same, holds the picture ~2 s, prints PASS/FAIL
;      DSPR /S       (with /AUTO or without) also writes SHOT.RAW: the screen + DAC
;
;  The checks read pixels back from A000h: a sprite on a coloured screen
;  leaves the background exactly where its see-through pixels are; half
;  off a corner it draws exactly its visible quarter; flipped, doubled,
;  from text, compiled and RLE-packed it draws the same pixels; and the
;  overlap tests answer known cases.
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

; ---- 1. compile: the size, a hole, a colour, the length --------------------
        mov  si,BALL
        mov  di,ballc
        call SPR_COMPILE
        cmp  di,ballc+2+64      ; DI past the 66 bytes
        jne  .c0
        cmp  word [ballc],0808h ; the size
        jne  .c0
        cmp  byte [ballc+2],255 ; '.' : the hole
        jne  .c0
        cmp  byte [ballc+2+2],4 ; '4'
        jne  .c0
        cmp  byte [ballc+2+8+2],12 ; 'C'
.c0:    mov  si,mComp
        call Rec

; ---- 2. drawn on colour 3: exactly 52 pixels change ------------------------
        call Fill3
        mov  si,ballc
        mov  bx,100
        mov  dx,100
        call SPR_DRAW
        mov  al,3
        call Count
        cmp  ax,64000-52        ; 12 holes leave the background
        mov  si,mDraw
        call Rec

; ---- 3. half off two corners: 13 + 13, nothing wraps, the sentinel kept ----
        call Fill3
        mov  si,ballc
        mov  bx,-4
        mov  dx,-4
        call SPR_DRAW           ; its bottom-right quarter: 13 solid
        mov  bx,316
        mov  dx,196
        call SPR_DRAW           ; its top-left quarter: 13 solid
        mov  bx,-8
        mov  dx,50
        call SPR_DRAW           ; wholly off: nothing
        mov  bx,320
        call SPR_DRAW
        mov  bx,50
        mov  dx,200
        call SPR_DRAW
        mov  al,3
        call Count
        cmp  ax,64000-26
        jne  .k0
        cmp  word [es:64000],0A55Ah
.k0:    mov  si,mClip
        call Rec

; ---- 4. flipped: the arrow points the other way -----------------------------
        mov  si,ARROW
        mov  di,arrowc
        call SPR_COMPILE
        call Clear
        mov  si,arrowc
        xor  bx,bx
        xor  dx,dx
        call SPR_DRAWF          ; 'E...' flipped is '...E'
        mov  ax,3
        xor  bx,bx
        call Peek
        cmp  al,14              ; E at the right now
        jne  .f0
        xor  ax,ax
        call Peek
        cmp  al,0               ; nothing at the left
        jne  .f0
        mov  ax,2
        mov  bx,1
        call Peek               ; row 1 'EE..' flipped '..EE'
        cmp  al,14
.f0:    mov  si,mFlip
        call Rec

; ---- 5. twice as big: four times the pixels, half off still clipped --------
        call Fill3
        mov  si,ballc
        mov  bx,10
        mov  dx,10
        call SPR_DRAWS
        mov  al,3
        call Count
        cmp  ax,64000-4*52
        jne  .s0
        call Fill3
        mov  bx,-8              ; the right half of the 16x16 on
        mov  dx,0
        call SPR_DRAWS
        mov  al,3
        call Count
        cmp  ax,64000-2*52      ; the ball is symmetric: half its pixels
.s0:    mov  si,mBig
        call Rec

; ---- 6. from text = compiled; a colour offset shifts every colour ----------
        call Clear
        mov  si,BALL
        mov  bx,50
        mov  dx,50
        call SPR_TEXT
        mov  si,ballc
        mov  bx,150
        mov  dx,50
        call SPR_DRAW
        mov  ax,50
        mov  bx,50
        mov  cx,150
        mov  dx,50
        call Same8              ; ZF = the two 8x8 blocks are equal
        jne  .t0
        mov  byte [spr_base],32
        mov  si,BALL
        mov  di,ballb
        call SPR_COMPILE
        mov  byte [spr_base],0
        cmp  byte [ballb+2+8+2],12+32
.t0:    mov  si,mText
        call Rec

; ---- 7. box overlap ---------------------------------------------------------
        mov  si,boxA
        mov  di,boxB1
        call SPR_HIT            ; (5,5) 10x10 over (0,0) 10x10: a hit
        jnc  .b0
        mov  di,boxB2
        call SPR_HIT            ; edge to edge: no
        jc   .b0
        mov  di,boxB3
        call SPR_HIT            ; corner to corner: no
        jc   .b0
        mov  di,boxB4
        call SPR_HIT            ; one pixel into the corner: a hit
        jnc  .b0
        cmp  al,al              ; ZF = 1: all four right
        jmp  .b1
.b0:    or   sp,sp              ; ZF = 0
.b1:    mov  si,mHit
        call Rec

; ---- 8. pixel overlap: boxes that meet only in see-through pixels ----------
        mov  si,ballc
        mov  di,ballc
        mov  bx,7
        mov  dx,0
        call SPR_PIXHIT         ; side by side, one column in common: a hit
        jnc  .p0
        mov  bx,6
        mov  dx,6
        call SPR_PIXHIT         ; corners overlap 2x2, all holes: no
        jc   .p0
        mov  bx,8
        mov  dx,0
        call SPR_PIXHIT         ; apart: no
        jc   .p0
        mov  bx,-3
        mov  dx,-3
        call SPR_PIXHIT         ; well inside: a hit
        jnc  .p0
        cmp  al,al
        jmp  .p1
.p0:    or   sp,sp
.p1:    mov  si,mPix
        call Rec

; ---- 9. animation frame and the frame of a strip ---------------------------
        mov  ax,100
        mov  bl,6
        mov  bh,4
        call SPR_ANIM           ; 100/6 = 16, 16 mod 4 = 0
        cmp  ax,0
        jne  .a0
        mov  ax,23
        mov  bl,5
        mov  bh,3
        call SPR_ANIM           ; 23/5 = 4, 4 mod 3 = 1
        cmp  ax,1
        jne  .a0
        mov  ax,7
        xor  bx,bx
        call SPR_ANIM           ; zeros are ones: 7 mod 1 = 0, no fault
        cmp  ax,0
        jne  .a0
        mov  si,ballc
        mov  ax,2
        call SPR_NTH            ; frame 2 of 66-byte frames
        cmp  si,ballc+2*66
.a0:    mov  si,mAnim
        call Rec

; ---- 10. RLE: packed and drawn = drawn compiled ------------------------------
        mov  si,ballc
        mov  di,ballr
        call SPR_RLEPACK
        mov  [rlend],di
        call Fill3
        mov  si,ballr
        mov  bx,60
        mov  dx,60
        call SPR_RLE
        mov  si,ballc
        mov  bx,160
        mov  dx,60
        call SPR_DRAW
        mov  ax,60
        mov  bx,60
        mov  cx,160
        mov  dx,60
        call Same8
        jne  .r0
        mov  al,3
        call Count
        cmp  ax,64000-2*52      ; and nothing else touched
.r0:    mov  si,mRle
        call Rec

        call MkLong             ; 100x3: long runs, a long hole, literals
        mov  si,longc
        mov  di,longr
        call SPR_RLEPACK
        call Fill3
        mov  si,longr
        mov  bx,10
        mov  dx,120
        call SPR_RLE
        mov  si,longc
        mov  bx,10
        mov  dx,130
        call SPR_DRAW
        xor  si,si              ; SI = the differences
        mov  bx,120
.lr:    mov  ax,10
.lc:    push ax
        call Peek
        mov  cl,al
        pop  ax
        add  bx,10
        push ax
        call Peek
        cmp  al,cl
        je   .le
        inc  si
.le:    pop  ax
        sub  bx,10
        inc  ax
        cmp  ax,110
        jb   .lc
        inc  bx
        cmp  bx,123
        jb   .lr
        mov  al,3
        call Count
        mov  cx,ax
        or   si,si              ; no difference...
        jne  .l0
        cmp  cx,64000-2*(300-40) ; ...and 260 solid each, nothing else
.l0:    mov  si,mLong
        call Rec

; ---- the picture ------------------------------------------------------------
        call Clear
        mov  byte [spr_base],0
        mov  si,STAR0           ; a two-frame strip
        mov  di,starc
        call SPR_COMPILE
        mov  si,STAR1
        call SPR_COMPILE        ; DI goes on: frame 1 right after frame 0
        xor  dx,dx
.gy:    xor  bx,bx
.gx:    mov  si,ballc
        mov  ax,bx
        add  ax,dx
        mov  cl,3
        shr  ax,cl              ; AX = (x + y) / 8: 3 a step
        and  al,3               ; flipped / doubled by place
        call SPR_DRAWM
        add  bx,24
        cmp  bx,320
        jl   .gx
        add  dx,24
        cmp  dx,100
        jl   .gy
        mov  si,arrowc
        mov  bx,20
        mov  dx,120
        call SPR_DRAWS
        mov  bx,60
        call SPR_DRAWF
        mov  si,BALL
        mov  bx,100
        mov  dx,120
        call SPR_TEXT
        mov  si,longr
        mov  bx,150
        mov  dx,120
        call SPR_RLE
        mov  ax,1
        mov  si,starc
        call SPR_NTH
        mov  bx,120
        mov  dx,160
        call SPR_DRAWS
        mov  si,starc
        mov  bx,80
        call SPR_DRAWS

        call Hold               ; ~2 s under /AUTO, else until Esc
        mov  ax,0003h
        int  10h                ; text again
        call Report
        mov  ax,4C00h
        int  21h

; Fill3 - the whole screen colour 3
Fill3:  push ax
        push cx
        push di
        xor  di,di
        mov  ax,0303h
        mov  cx,32000
        rep  stosw
        pop  di
        pop  cx
        pop  ax
        ret

; Same8 - ZF = 1 if the 8x8 blocks at (AX,BX) and (CX,DX) are equal
Same8:  push ax
        push bx
        push cx
        push dx
        push si
        push di
        mov  si,ax
        mov  di,cx
        mov  cx,8               ; rows
.r:     push cx
        mov  cx,8
.c:     push bx
        mov  ax,si
        call Peek
        mov  ah,al
        push ax
        mov  bx,dx
        mov  ax,di
        call Peek
        pop  bx                 ; BH = the first block's pixel
        cmp  al,bh
        pop  bx
        jne  .x
        inc  si
        inc  di
        loop .c
        sub  si,8
        sub  di,8
        inc  bx
        inc  dx
        pop  cx
        loop .r
        cmp  al,al              ; ZF = 1
        jmp  .e
.x:     pop  cx                 ; ZF = 0 from the compare
.e:     pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; MkLong - longc: 100x3, row 0 all colour 5, row 1 holes 20..59 and 5
; elsewhere, row 2 alternating 9,10 (literals)
MkLong: mov  di,longc
        mov  byte [di],100
        mov  byte [di+1],3
        add  di,2
        mov  cx,100
        mov  al,5
.a:     mov  [di],al
        inc  di
        loop .a
        xor  bx,bx
.b:     mov  al,5
        cmp  bx,20
        jb   .b1
        cmp  bx,60
        jae  .b1
        mov  al,255
.b1:    mov  [di],al
        inc  di
        inc  bx
        cmp  bx,100
        jb   .b
        xor  bx,bx
.c:     mov  al,bl
        and  al,1
        add  al,9
        mov  [di],al
        inc  di
        inc  bx
        cmp  bx,100
        jb   .c
        ret

BALL    db 8,8
        db '..4444..'
        db '.4CCCC4.'
        db '4CCFFCC4'
        db '4CCCFCC4'
        db '4CCCCCC4'
        db '4CCCCCC4'
        db '.4CCCC4.'
        db '..4444..'
ARROW   db 4,2
        db 'E...'
        db 'EE..'
STAR0   db 7,7
        db '...E...'
        db '...E...'
        db '..EEE..'
        db 'EEEFEEE'
        db '..EEE..'
        db '...E...'
        db '...E...'
STAR1   db 7,7
        db 'E.....E'
        db '.E...E.'
        db '..EEE..'
        db '..EFE..'
        db '..EEE..'
        db '.E...E.'
        db 'E.....E'
boxA    dw 0,0,10,10
boxB1   dw 5,5,10,10
boxB2   dw 10,0,5,5
boxB3   dw -3,-3,3,3
boxB4   dw -3,-3,4,4
rlend   dw 0
mComp   db 'SPR_COMPILE: size, hole 255, colours, 66 bytes$'
mDraw   db 'SPR_DRAW: 52 solid pixels drawn, 12 holes see-through$'
mClip   db 'SPR_DRAW clipped: 13 + 13 at the corners, none off-screen$'
mFlip   db 'SPR_DRAWF: the arrow faces the other way$'
mBig    db 'SPR_DRAWS: 4 * 52 pixels, half off the edge 2 * 52$'
mText   db 'SPR_TEXT draws what SPR_DRAW draws; spr_base shifts$'
mHit    db 'SPR_HIT: overlap yes, edge no, corner no, corner+1 yes$'
mPix    db 'SPR_PIXHIT: solid meets solid; holes over holes do not$'
mAnim   db 'SPR_ANIM 0, 1, zeros safe; SPR_NTH frame 2$'
mRle    db 'SPR_RLEPACK + SPR_RLE draw what SPR_DRAW draws$'
mLong   db 'SPR_RLE with word counts: 100-wide rows the same$'

ballc   db 2+64 dup(0)
ballb   db 2+64 dup(0)
arrowc  db 2+8 dup(0)
ballr   db 200 dup(0)
starc   db 2*(2+49) dup(0)
longc   db 2+300 dup(0)
longr   db 700 dup(0)

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
sAll    db 'DSPR: all checks PASS',13,10,'$'
sSome   db 'DSPR: SOME CHECKS FAILED',13,10,'$'


        include '..\..\KIT\LIB\K_SPR.INC'
