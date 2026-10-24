; ============================================================================
;  DTEXT.ASM - KIT test: K_TEXT.INC (letters and numbers in mode 13h, DOS).
;
;      DTEXT          draws, checks, shows the page until Esc
;      DTEXT /AUTO    the same, holds the page ~2 s, prints PASS/FAIL
;      DTEXT /S       (with /AUTO or without) also writes SHOT.RAW: the screen + DAC
;
;  The checks count pixels read back from A000h against the font's own
;  bits: a letter draws exactly as many pixels as its glyph has bits (four
;  times as many at x2), only those (the background stays), a letter half
;  off the screen does not wrap to the other side; and the number strings
;  are compared byte by byte.
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

Main:   cld
        call IsAuto             ; [auto] = 1 if /AUTO is on the command line
        mov  ax,0013h
        int  10h                ; 320x200, a byte a pixel
        mov  ax,0A000h
        mov  es,ax              ; ES = the screen

; ---- the bits of 'A' in the BIOS font, counted here independently ----------
        push es
        mov  ax,1130h
        mov  bh,3
        int  10h                ; ES:BP = the 8x8 font
        mov  si,'A'*8
        add  si,bp              ; ES:SI = the glyph of 'A'
        xor  dx,dx              ; DX = the bits
        mov  cx,8
.ab:    mov  al,[es:si]
        inc  si
.bit:   shl  al,1
        adc  dx,0               ; DX += the bit that fell out
        or   al,al
        jnz  .bit
        loop .ab
        pop  es
        mov  [bitsA],dx

; ---- 1. one 8x8 letter: exactly its bits ------------------------------------
        call Clear
        mov  byte [txt_col],15
        mov  si,sA
        mov  bx,10
        mov  dx,10
        call TXT_PUT8
        mov  al,15
        call Count
        cmp  ax,[bitsA]
        mov  si,m8
        call Rec

; ---- 2. scale 2: four times as many; BX after the letter = x + 16 ----------
        call Clear
        mov  byte [txt_scale],2
        mov  si,sA
        mov  bx,10
        mov  dx,10
        call TXT_PUT8
        mov  byte [txt_scale],1
        mov  [bxout],bx
        mov  al,15
        call Count
        mov  cx,[bitsA]
        add  cx,cx              ; CX = 2 bits
        add  cx,cx              ; CX = 4 bits
        cmp  ax,cx
        jne  .s0
        cmp  word [bxout],26
.s0:    mov  si,m8x2
        call Rec

; ---- 3. transparent: the background stays where the letters are not -------
        call Clear
        call Fill3              ; the whole screen colour 3
        mov  si,sHello
        mov  bx,0
        mov  dx,0
        call TXT_PUT8
        mov  al,15
        call Count
        push ax
        mov  al,3
        call Count
        pop  cx
        add  ax,cx              ; ink + background
        cmp  ax,64000           ; = every pixel: nothing else was touched
        mov  si,mTrans
        call Rec

; ---- 4. shadow and ring: the ink the same, the shade beside it ------------
        call Clear
        mov  byte [txt_shc],8
        mov  byte [txt_style],1
        mov  si,sA
        mov  bx,10
        mov  dx,10
        call TXT_PUT8
        mov  al,15
        call Count
        cmp  ax,[bitsA]         ; all the ink still shows...
        jne  .h0
        mov  al,8
        call Count
        cmp  ax,0               ; ...and a shadow is there
        je   .h1
        cmp  al,al
        jmp  .h0
.h1:    or   sp,sp              ; ZF = 0
.h0:    mov  si,mShad
        call Rec

        call Clear
        mov  byte [txt_style],2
        mov  si,sA
        mov  bx,10
        mov  dx,10
        call TXT_PUT8
        mov  byte [txt_style],0
        mov  al,15
        call Count
        cmp  ax,[bitsA]
        jne  .o0
        mov  ax,9               ; left of the cell, by the letter's middle
        mov  bx,14
        call Peek               ; 'A' touches its cell's left at row 4:
        cmp  al,8               ;  the ring must be there
.o0:    mov  si,mRing
        call Rec

; ---- 5. the 4x6 letters: 'H' is 11 pixels, 'h' the same -------------------
        call Clear
        mov  si,sH
        mov  bx,10
        mov  dx,10
        call TXT_PUT4
        mov  [bxout],bx
        mov  al,15
        call Count
        cmp  ax,11
        jne  .f0
        cmp  word [bxout],14    ; on by 4
        jne  .f0
        call Clear
        mov  si,sh
        mov  bx,10
        mov  dx,10
        call TXT_PUT4
        mov  al,15
        call Count
        cmp  ax,11
.f0:    mov  si,m4
        call Rec

; ---- 6. a letter half off the left edge does not wrap ---------------------
        call Clear
        mov  si,sM
        mov  bx,-4
        mov  dx,50
        call TXT_PUT8           ; its right half on the screen
        mov  si,sM
        mov  bx,316
        mov  dx,100
        call TXT_PUT8           ; its left half
        mov  al,15
        call Count
        mov  [bxout],ax
        xor  cx,cx              ; CX = pixels where a wrap would land
        mov  bx,49
.wr:    mov  si,316
.wc:    mov  ax,si
        call Peek               ; row y-1's right end (x -4 wraps there)
        cmp  al,15
        jne  .wn
        inc  cx
.wn:    inc  si
        cmp  si,320
        jb   .wc
        inc  bx
        cmp  bx,58
        jb   .wr
        mov  bx,101
.wl:    xor  si,si
.wl2:   mov  ax,si
        call Peek               ; row y+1's left end (x 320+ wraps there)
        cmp  al,15
        jne  .wm
        inc  cx
.wm:    inc  si
        cmp  si,4
        jb   .wl2
        inc  bx
        cmp  bx,109
        jb   .wl
        cmp  word [bxout],0     ; something drew
        je   .w1
        or   cx,cx              ; and nothing wrapped
        jmp  .w0
.w1:    or   sp,sp
.w0:    mov  si,mWrap
        call Rec

; ---- 7. the number strings -------------------------------------------------
        xor  ax,ax
        mov  cl,1
        call TXT_NUMSTR
        mov  di,s0
        call StrEq
        jne  .n0
        mov  ax,65535
        mov  cl,1
        call TXT_NUMSTR
        mov  di,s65535
        call StrEq
        jne  .n0
        mov  ax,7
        mov  cl,3
        call TXT_NUMSTR
        mov  di,s007
        call StrEq
        jne  .n0
        mov  ax,12345
        mov  cl,3
        call TXT_NUMSTR         ; too wide for 3: runs long
        mov  di,s12345
        call StrEq
.n0:    mov  si,mNum
        call Rec

        call Clear
        mov  ax,1400
        mov  bx,0
        mov  dx,0
        call TXT_NUMK
        mov  si,txt_nb
        mov  di,s14k
        call StrEq
        jne  .k0
        mov  ax,65535
        call TXT_NUMK
        mov  si,txt_nb
        mov  di,s655k
        call StrEq
        jne  .k0
        mov  ax,999
        call TXT_NUMK
        mov  si,txt_nb
        mov  di,s999
        call StrEq
.k0:    mov  si,mNumk
        call Rec

        call Clear              ; TXT_SNUM -12 draws what "-12" draws
        mov  ax,-12
        mov  bx,0
        mov  dx,0
        call TXT_SNUM
        mov  [bxout],bx
        mov  al,15
        call Count
        push ax
        call Clear
        mov  si,sM12
        mov  bx,0
        mov  dx,0
        call TXT_PUT
        mov  al,15
        call Count
        pop  cx
        cmp  ax,cx
        jne  .g0
        cmp  word [bxout],24    ; three cells
.g0:    mov  si,mSnum
        call Rec

; ---- 8. width and box ------------------------------------------------------
        mov  si,sHello          ; 'HELLO' 5 letters
        call TXT_WIDTH
        cmp  cx,40              ; 8x8 x1: 40
        jne  .x0
        mov  byte [txt_font],1
        mov  byte [txt_scale],2
        call TXT_WIDTH
        mov  byte [txt_font],0
        mov  byte [txt_scale],1
        cmp  cx,40              ; 4x6 x2: 40 too
.x0:    mov  si,mWid
        call Rec

        call Clear
        mov  byte [txt_boxc],1
        mov  si,sHI
        mov  bx,160
        mov  dx,100
        call TXT_BOX            ; letters 152..167, box 148..171 x 97..110
        mov  al,1
        call Count
        push ax
        mov  al,15
        call Count
        pop  cx
        add  ax,cx              ; box + ink
        cmp  ax,24*14           ; = the whole box
        jne  .b0
        mov  ax,148
        mov  bx,97
        call Peek               ; its top-left corner
        cmp  al,1
        jne  .b0
        mov  ax,147
        call Peek               ; one left of it: untouched
        cmp  al,0
.b0:    mov  si,mBox
        call Rec

; ---- the page: every font, size and style ----------------------------------
        call Clear
        xor  dx,dx
.bg:    mov  ax,dx              ; a striped background, to show the styles
        and  al,15
        add  al,16
        push dx
        mov  di,dx
        mov  cl,8
        shl  di,cl              ; DI = y * 256
        mov  cl,6
        shl  dx,cl              ; DX = y * 64
        add  di,dx              ; DI = y * 320
        mov  cx,320
        rep  stosb
        pop  dx
        inc  dx
        cmp  dx,200
        jb   .bg
        mov  byte [txt_col],14
        mov  byte [txt_scale],2
        mov  byte [txt_style],2
        mov  byte [txt_shc],0
        mov  si,sTitle
        mov  bx,160
        mov  dx,8
        call TXT_CENTER
        mov  byte [txt_scale],1
        mov  byte [txt_style],0
        mov  byte [txt_col],15
        mov  si,sPlain
        mov  bx,8
        mov  dx,40
        call TXT_PUT8
        mov  byte [txt_style],1
        mov  si,sShadow
        mov  bx,8
        mov  dx,54
        call TXT_PUT8
        mov  byte [txt_style],2
        mov  si,sRinged
        mov  bx,8
        mov  dx,68
        call TXT_PUT8
        mov  byte [txt_style],0
        mov  si,sSmall
        mov  bx,8
        mov  dx,88
        call TXT_PUT4
        mov  byte [txt_style],2
        mov  si,sSmall
        mov  bx,8
        mov  dx,98
        call TXT_PUT4
        mov  byte [txt_scale],2
        mov  si,sBig4
        mov  bx,8
        mov  dx,112
        call TXT_PUT4
        mov  byte [txt_scale],1
        mov  byte [txt_font],1
        mov  si,sScore
        mov  bx,8
        mov  dx,134
        call TXT_PUT
        mov  ax,1234
        call TXT_NUM
        mov  si,sSp
        call TXT_PUT
        mov  ax,42
        mov  cl,5
        call TXT_NUMZ
        call TXT_PUT
        mov  ax,-300
        call TXT_SNUM
        call TXT_PUT
        mov  ax,48700
        call TXT_NUMK
        mov  byte [txt_font],0
        mov  byte [txt_style],0
        mov  byte [txt_col],14
        mov  byte [txt_boxc],1
        mov  si,sPaused
        mov  bx,160
        mov  dx,160
        call TXT_BOX

        call Hold               ; ~2 s under /AUTO, else until Esc
        mov  ax,0003h
        int  10h                ; text again
        call Report
        mov  dx,sDos            ; and the DOS helpers themselves
        call TXT_DOS
        mov  ax,12345
        call TXT_DOSNUM
        mov  si,sDosz
        call TXT_DOSZ
        call TXT_DOSCR
        mov  ax,4C00h
        int  21h

; Fill3 - the whole screen colour 3
Fill3:  xor  di,di
        mov  ax,0303h
        mov  cx,32000
        rep  stosw
        ret

; StrEq - ZF = 1 if the zero-ended strings at SI and DI are the same
StrEq:  push ax
        push si
        push di
.l:     mov  al,[si]
        cmp  al,[di]
        jne  .e
        inc  si
        inc  di
        or   al,al
        jnz  .l
.e:     pop  di
        pop  si
        pop  ax
        ret

bitsA   dw 0
bxout   dw 0
sA      db 'A',0
sH      db 'H',0
sh      db 'h',0
sM      db 'M',0
sHI     db 'HI',0
sM12    db '-12',0
sHello  db 'HELLO',0
s0      db '0',0
s65535  db '65535',0
s007    db '007',0
s12345  db '12345',0
s14k    db '1.4K',0
s655k   db '65.5K',0
s999    db '999',0
sTitle  db 'K_TEXT',0
sPlain  db 'The BIOS 8x8, plain',0
sShadow db 'The BIOS 8x8, a shadow',0
sRinged db 'The BIOS 8x8, ringed: reads on anything',0
sSmall  db 'THE BUILT-IN 4X6 LETTERS: 0123456789 +-:%.!?',0
sBig4   db '4X6 AT X2',0
sScore  db 'SCORE ',0
sSp     db '  ',0
sPaused db 'PAUSED - ESC QUITS',0
sDos    db 'TXT_DOS, TXT_DOSNUM: $'
sDosz   db ' (TXT_DOSZ)',0
m8      db 'TXT_PUT8: one letter draws exactly its glyph bits$'
m8x2    db 'TXT_PUT8 x2: four times the pixels, BX on by 16$'
mTrans  db 'transparent: ink + untouched background = 64000$'
mShad   db 'style 1: ink whole, a shadow beside it$'
mRing   db 'style 2: ink whole, the ring at the letter edge$'
m4      db 'TXT_PUT4: H = 11 pixels, h the same, BX on by 4$'
mWrap   db 'letters half off either edge never wrap$'
mNum    db 'TXT_NUMSTR: 0, 65535, 007, 12345 too wide runs long$'
mNumk   db 'TXT_NUMK: 1.4K, 65.5K, 999$'
mSnum   db 'TXT_SNUM -12 draws what "-12" draws$'
mWid    db 'TXT_WIDTH: HELLO 40 in 8x8, 40 in 4x6 x2$'
mBox    db 'TXT_BOX: box + letters fill 24*14 exactly$'

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
sAll    db 'DTEXT: all checks PASS',13,10,'$'
sSome   db 'DTEXT: SOME CHECKS FAILED',13,10,'$'


        include '..\..\KIT\LIB\K_TEXT.INC'
