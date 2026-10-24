; ============================================================================
;  FFONT.ASM - KIT test: K_FONT.INC (the good letters: outlined, shadowed,
;  big and smooth, a colour ramp down the letters).
;
;      FFONT          checks, then shows every font and style until Esc
;      FFONT /AUTO    the same, holds the picture ~2 s, prints PASS/FAIL
;      FFONT /S       (with /AUTO or without) also writes SHOT.RAW: the screen + DAC
;
;  Every check draws on a cleared screen and READS THE PIXELS BACK out of
;  A000h: a letter draws exactly its glyph's bits (counted here straight
;  from the BIOS font, k*k times at scale k), every ring pixel touches the
;  letter and no background pixel touching the letter is left un-ringed,
;  every shadow pixel lies one down-right of an ink pixel, a gradient runs
;  its first colour at the top and its last at the bottom, letters half off
;  any edge never wrap round and never write past the screen's 64000 bytes,
;  measured widths equal FNT_WIDTH, and every register comes back.
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

Main:   cld
        call IsAuto             ; [auto] = 1 if /AUTO is on the command line
        mov  ax,0013h
        int  10h                ; 320x200, a byte a pixel
        mov  ax,0A000h
        mov  es,ax              ; ES = the screen
        call Sent               ; a pattern past the last pixel

; ---- the BIOS's own bits of 'A' and 'H', counted here, not by K_FONT -------
        mov  al,'A'
        mov  bh,3
        mov  cx,8
        call RomBits
        mov  [bitsA],ax
        mov  al,'H'
        mov  bh,3
        mov  cx,8
        call RomBits
        mov  [bitsH],ax
        mov  al,'A'
        mov  bh,6
        mov  cx,16
        call RomBits
        mov  [bitsA16],ax

; ---- 1. 8x8 'A', plain: exactly its bits; x2 and x3 blocks: 4x, 9x --------
        call Plain
        mov  byte [fnt_font],FNT_F8
        call Clear
        mov  si,sA
        mov  bx,10
        mov  dx,10
        call FNT_PUT
        mov  al,15
        call Count
        cmp  ax,[bitsA]
        jne  .f1
        cmp  bx,18              ; BX on by 8
        jne  .f1
        call Clear
        mov  byte [fnt_scale],2
        mov  bx,10
        call FNT_PUT
        mov  al,15
        call Count
        mov  cx,[bitsA]
        shl  cx,1
        shl  cx,1               ; CX = 4 * bits
        cmp  ax,cx
        jne  .f1
        cmp  bx,26              ; BX on by 16
        jne  .f1
        call Clear
        mov  byte [fnt_scale],3
        mov  bx,10
        call FNT_PUT
        mov  al,15
        call Count
        mov  cx,[bitsA]
        mov  dx,cx
        shl  cx,1
        shl  cx,1
        shl  cx,1               ; 8 * bits
        add  cx,dx              ; 9 * bits
        cmp  ax,cx
.f1:    mov  si,m1
        call Rec

; ---- 2. 8x16 'A', 4x6 'A' (10 bits), digits '81' (28 + 17) ----------------
        call Plain
        call Clear
        mov  byte [fnt_font],FNT_F16
        mov  si,sA
        mov  bx,10
        mov  dx,10
        call FNT_PUT
        mov  al,15
        call Count
        cmp  ax,[bitsA16]
        jne  .f2
        call Clear
        mov  byte [fnt_font],FNT_F4
        mov  bx,10
        call FNT_PUT
        mov  al,15
        call Count
        cmp  ax,10
        jne  .f2
        cmp  bx,14              ; 4 a letter
        jne  .f2
        call Clear
        mov  byte [fnt_font],FNT_FDIG
        mov  si,s81
        mov  bx,10
        call FNT_PUT
        mov  al,15
        call Count
        cmp  ax,45
        jne  .f2
        cmp  bx,24              ; 7 a digit
.f2:    mov  si,m2
        call Rec

; ---- 3. the ring, 1 px, 8x8 x1: ink whole, ring exact ---------------------
        call Plain
        mov  byte [fnt_style],FNT_RING
        mov  byte [fnt_rc],4
        call Clear
        mov  si,sAW
        mov  bx,40
        mov  dx,40
        call FNT_PUT
        mov  al,15
        mov  ah,4
        call RingChk            ; DL = 0: exact
        or   dl,dl
        jnz  .f3
        mov  al,15
        call Count
        mov  cx,ax
        mov  al,'W'
        mov  bh,3
        push cx
        mov  cx,8
        call RomBits
        pop  cx
        add  ax,[bitsA]         ; AX = A's bits + W's
        cmp  ax,cx
.f3:    mov  si,m3
        call Rec

; ---- 4. the ring on a big smooth letter (x4, Scale2x twice), and x3 -------
        call Plain
        mov  byte [fnt_style],FNT_RING
        mov  byte [fnt_rc],4
        mov  byte [fnt_scale],4
        mov  byte [fnt_smooth],1
        call Clear
        mov  si,sAW
        mov  bx,20
        mov  dx,40
        call FNT_PUT
        mov  al,15
        mov  ah,4
        call RingChk
        or   dl,dl
        jnz  .f4
        mov  byte [fnt_scale],3
        call Clear
        mov  bx,20
        call FNT_PUT
        mov  al,15
        mov  ah,4
        call RingChk
        or   dl,dl
        jnz  .f4
        mov  al,15
        call Count
        cmp  ax,100             ; something sizeable drawn
        jae  .p4
        or   al,1               ; ZF = 0: too little
        jmp  .f4
.p4:    cmp  ax,ax              ; ZF = 1
.f4:    mov  si,m4
        call Rec

; ---- 5. ring 2 px: nothing next to the ink unringed, and fatter than 1 ----
        call Plain
        mov  byte [fnt_style],FNT_RING
        mov  byte [fnt_rc],4
        mov  byte [fnt_scale],2
        mov  byte [fnt_smooth],1
        call Clear
        mov  si,sAW
        mov  bx,40
        mov  dx,40
        call FNT_PUT
        mov  al,4
        call Count
        mov  [ring1],ax
        mov  byte [fnt_rw],2
        call Clear
        mov  bx,40
        call FNT_PUT
        mov  al,15
        mov  ah,4
        call RingChk
        test dl,2               ; a background pixel touching the ink?
        jnz  .f5
        mov  al,4
        call Count
        cmp  ax,[ring1]
        ja   .p5
        or   al,1               ; ZF = 0: fail
        jmp  .f5
.p5:    cmp  ax,ax
.f5:    mov  si,m5
        call Rec

; ---- 6. FNT_HUD: 'AZ' ink 10 + 9, ring exact ------------------------------
        call Clear
        mov  byte [fnt_col],15
        mov  byte [fnt_rc],4
        mov  si,sAZ
        mov  bx,50
        mov  dx,50
        call FNT_HUD
        cmp  bx,58
        jne  .f6
        mov  al,15
        call Count
        cmp  ax,19
        jne  .f6
        mov  al,15
        mov  ah,4
        call RingChk
        or   dl,dl
.f6:    mov  si,m6
        call Rec

; ---- 7. shadow: ink whole, every shadow pixel down-right of an ink one ----
        call Plain
        mov  byte [fnt_style],FNT_SHADOW
        mov  byte [fnt_shc],8
        call Clear
        mov  si,sA
        mov  bx,60
        mov  dx,60
        call FNT_PUT
        mov  al,15
        call Count
        cmp  ax,[bitsA]
        jne  .f7
        mov  al,8
        call Count
        or   ax,ax
        jz   .f7n
        call ShadChk            ; ZF = 1: every 8 has a 15 up-left
        jmp  .f7
.f7n:   or   al,1               ; no shadow: fail
.f7:    mov  si,m7
        call Rec

; ---- 8. gradient: 1 at the top row, 4 at the bottom, all pixels counted ---
        call Plain
        mov  byte [fnt_scale],4
        mov  word [fnt_gtab],g4
        mov  byte [fnt_gn],4
        call Clear
        mov  si,sH
        mov  bx,100
        mov  dx,60
        call FNT_PUT
        call Bounds
        mov  ax,[minx]
        mov  bx,[miny]
        call RowCol             ; AL = the first lit colour in row miny
        cmp  al,1
        jne  .f8
        mov  bx,[maxy]
        call RowCol
        cmp  al,4
        jne  .f8
        mov  al,1
        call Count
        mov  cx,ax
        mov  al,2
        call Count
        add  cx,ax
        mov  al,3
        call Count
        add  cx,ax
        mov  al,4
        call Count
        add  cx,ax              ; CX = every pixel of the ramp
        mov  ax,[bitsH]
        mov  dx,16
        mul  dx                 ; AX = 16 * bits (x4)
        cmp  ax,cx
.f8:    mov  si,m8
        call Rec

; ---- 9. clipping: half off every edge, no wrap, nothing past 64000 --------
        call Plain
        mov  byte [fnt_style],FNT_RINGSH
        mov  byte [fnt_scale],2
        mov  byte [fnt_smooth],1
        mov  byte [fnt_rw],2
        mov  byte [fnt_shd],3
        mov  byte [fnt_shc],8
        mov  byte [fnt_rc],4
        call Clear
        mov  si,sW
        mov  bx,-8              ; half off the left
        mov  dx,80
        call FNT_PUT
        mov  si,sHUD
        mov  bx,-3
        mov  dx,120
        call FNT_HUD
        mov  bx,290             ; nothing may reach the right side
        mov  cx,319
        mov  dx,0
        mov  si,199
        call Zero
        jnz  .f9
        call Clear
        mov  si,sW
        mov  bx,312             ; half off the right
        mov  dx,80
        call FNT_PUT
        mov  si,sHUD
        mov  bx,317
        mov  dx,120
        call FNT_HUD
        mov  bx,0
        mov  cx,30
        mov  dx,0
        mov  si,199
        call Zero
        jnz  .f9
        call Clear
        mov  si,sW
        mov  bx,100
        mov  dx,-10             ; half off the top
        call FNT_PUT
        mov  si,sHUD
        mov  bx,150
        mov  dx,-3
        call FNT_HUD
        mov  bx,0
        mov  cx,319
        mov  dx,20
        mov  si,199
        call Zero
        jnz  .f9
        call Clear
        mov  si,sW
        mov  bx,100
        mov  dx,192             ; half off the bottom
        call FNT_PUT
        mov  si,sHUD
        mov  bx,150
        mov  dx,197
        call FNT_HUD
        mov  byte [fnt_scale],4
        mov  si,sAW
        mov  bx,250
        mov  dx,180             ; a big one off the bottom right
        call FNT_PUT
        mov  bx,0
        mov  cx,319
        mov  dx,0
        mov  si,160
        call Zero
        jnz  .f9
        call SentOK             ; past the screen untouched
.f9:    mov  si,m9
        call Rec

; ---- 10. widths: fixed, scaled, digits, proportional measured, centred ----
        call Plain
        mov  si,sABC
        call FNT_WIDTH
        cmp  cx,23              ; 8x8: 3*8 - 1
        jne  .f10
        mov  byte [fnt_font],FNT_F4
        call FNT_WIDTH
        cmp  cx,11              ; 4x6: 3*4 - 1
        jne  .f10
        mov  byte [fnt_font],FNT_F8
        mov  byte [fnt_scale],2
        call FNT_WIDTH
        cmp  cx,46              ; 8x8 x2: 3*16 - 2
        jne  .f10
        mov  byte [fnt_font],FNT_FDIG
        mov  byte [fnt_scale],1
        mov  si,s120
        call FNT_WIDTH
        cmp  cx,20              ; digits: 3*7 - 1
        jne  .f10
        call Plain              ; proportional x4 smooth: measured = FNT_WIDTH
        mov  byte [fnt_scale],4
        mov  byte [fnt_smooth],1
        mov  byte [fnt_prop],1
        mov  byte [fnt_gap],2
        call Clear
        mov  si,sOWL
        call FNT_WIDTH
        mov  [wid],cx
        mov  bx,20
        mov  dx,50
        call FNT_PUT
        call Bounds
        mov  ax,[maxx]
        sub  ax,[minx]
        inc  ax                 ; AX = the measured width
        cmp  ax,[wid]
        jne  .f10
        cmp  word [minx],20     ; the first letter starts AT x
        jne  .f10
        call Clear
        mov  bx,160
        mov  dx,50
        call FNT_CENTER
        call Bounds
        mov  ax,[minx]
        add  ax,[maxx]          ; left + right = 319 or 320 when centred
        cmp  ax,319
        je   .f10
        cmp  ax,320
.f10:   mov  si,m10
        call Rec

; ---- 11. FNT_HEIGHT, FNT_NUMZ / FNT_NUM strings, FNT_RIGHT ----------------
        call Plain
        mov  byte [fnt_font],FNT_F16
        mov  byte [fnt_scale],2
        call FNT_HEIGHT
        cmp  cx,32
        jne  .f11
        mov  byte [fnt_font],FNT_F4
        mov  byte [fnt_scale],3
        call FNT_HEIGHT
        cmp  cx,15
        jne  .f11
        call Plain
        mov  byte [fnt_font],FNT_FDIG
        call Clear
        mov  ax,120
        mov  cl,5
        mov  bx,10
        mov  dx,10
        call FNT_NUMZ
        mov  di,s00120
        call NbEq               ; ZF = 1: fnt_nb ends in that string
        jne  .f11
        mov  ax,65535
        mov  bx,10
        call FNT_NUM
        mov  di,s65535
        call NbEq               ; ZF = 1: fnt_nb ends in that string
        jne  .f11
        mov  ax,0
        call FNT_NUM
        mov  di,s0
        call NbEq               ; ZF = 1: fnt_nb ends in that string
        jne  .f11
        call Clear
        mov  si,s120
        mov  bx,300
        mov  dx,10
        call FNT_RIGHT          ; its last column lands on x = 300
        call Bounds
        cmp  word [maxx],300
.f11:   mov  si,m11
        call Rec

; ---- 12. every register kept (BX is the only "out") -----------------------
        mov  al,FNT_LTITLE
        call FNT_LOOK
        call Clear
        mov  ax,1111h
        mov  cx,2222h
        mov  dx,30
        mov  si,sOWL
        mov  di,4444h
        mov  bp,5555h
        mov  bx,10
        call FNT_PUT
        call FNT_CENTER
        call FNT_WIDTH          ; (CX out here - set again below)
        mov  cx,2222h
        call FNT_HUD
        mov  ax,1111h
        mov  ax,77
        call FNT_NUMZ
        cmp  ax,77
        jne  .f12
        mov  ax,1111h
        mov  al,FNT_LHUD
        call FNT_LOOK
        cmp  ax,1111h-11h+FNT_LHUD
        jne  .f12
        cmp  cx,2222h
        jne  .f12
        cmp  dx,30
        jne  .f12
        cmp  si,sOWL
        jne  .f12
        cmp  di,4444h
        jne  .f12
        cmp  bp,5555h
        jne  .f12
        mov  ax,es
        cmp  ax,0A000h
.f12:   mov  si,m12
        call Rec

; ---- 13. transparent: ink + the untouched background = 64000 -------------
        call Plain
        mov  byte [fnt_scale],2
        mov  byte [fnt_smooth],1
        call Fill3
        mov  si,sAW
        mov  bx,10
        mov  dx,10
        call FNT_PUT
        mov  al,15
        call Count
        mov  cx,ax
        mov  al,3
        call Count
        add  ax,cx
        cmp  ax,64000
        mov  si,m13
        call Rec

; ---- 14. K_TEXT and K_FONT in one program: both link, each its own width --
        call Plain
        mov  si,sABC
        call TXT_WIDTH          ; K_TEXT: 3 cells of 8 = 24
        cmp  cx,24
        jne  .f14
        call FNT_WIDTH          ; K_FONT: to the last ink column = 23
        cmp  cx,23
.f14:   mov  si,m14
        call Rec

; ============================================================================
;  The picture: every font and style over stripes of white, black, colours.
; ============================================================================
        call Stripes
        mov  al,FNT_LTITLE      ; the title look
        call FNT_LOOK
        mov  si,sTitle
        mov  bx,160
        mov  dx,3
        call FNT_CENTER
        mov  al,FNT_LFIRE       ; 8x16 x2, fire
        call FNT_LOOK
        mov  si,sFire
        mov  bx,8
        mov  dx,40
        call FNT_PUT
        mov  al,FNT_LFIRE       ; the same with the ice ramp
        call FNT_LOOK
        mov  word [fnt_gtab],fnt_ice
        mov  byte [fnt_gn],FNT_ICEN
        mov  si,sIce
        mov  bx,180
        mov  dx,40
        call FNT_PUT
        mov  al,FNT_LSUB        ; 8x8 x2 smooth, ringed
        call FNT_LOOK
        mov  si,sSmooth
        mov  bx,8
        mov  dx,76
        call FNT_PUT
        mov  byte [fnt_smooth],0 ; the same, square blocks
        mov  byte [fnt_prop],0
        mov  si,sBlock
        mov  bx,162
        mov  dx,76
        call FNT_PUT
        mov  al,FNT_LBIG        ; UBIG: 4x6 x3
        call FNT_LOOK
        mov  si,sBig
        mov  bx,8
        mov  dx,98
        call FNT_PUT
        mov  al,FNT_LSUB        ; 8x8 x3 smooth (Scale3x), lime ramp
        call FNT_LOOK
        mov  byte [fnt_scale],3
        mov  byte [fnt_style],FNT_RINGSH
        mov  byte [fnt_shd],2
        mov  word [fnt_gtab],fnt_lime
        mov  byte [fnt_gn],FNT_LIMEN
        mov  si,sX3
        mov  bx,150
        mov  dx,94
        call FNT_PUT
        mov  al,FNT_LMENU       ; 8x16 menu lines, shadowed
        call FNT_LOOK
        mov  si,sMenu1
        mov  bx,8
        mov  dx,120
        call FNT_PUT
        mov  byte [fnt_style],FNT_RING
        mov  byte [fnt_col],14
        mov  si,sMenu2
        mov  bx,168
        mov  dx,120
        call FNT_PUT
        call Plain              ; 8x8: plain, shadow, ring
        mov  si,sP8
        mov  bx,8
        mov  dx,140
        call FNT_PUT
        mov  byte [fnt_style],FNT_SHADOW
        mov  si,sS8
        mov  bx,88
        call FNT_PUT
        mov  byte [fnt_style],FNT_RING
        mov  si,sR8
        mov  bx,184
        call FNT_PUT
        mov  byte [fnt_col],15  ; FNT_HUD, the 4x6 ringed, fast
        mov  byte [fnt_rc],0
        mov  si,sHud
        mov  bx,8
        mov  dx,156
        call FNT_HUD
        mov  al,FNT_LHUD        ; 4x6 through FNT_PUT: plain, then x2 ring
        call FNT_LOOK
        mov  byte [fnt_style],FNT_PLAIN
        mov  si,sHudP
        mov  bx,8
        mov  dx,166
        call FNT_PUT
        mov  byte [fnt_style],FNT_RING
        mov  byte [fnt_scale],2
        mov  si,sHud2
        mov  bx,150
        mov  dx,163
        call FNT_PUT
        mov  al,FNT_LHUD        ; the score line: a label, then digits
        call FNT_LOOK
        mov  si,sScore
        mov  bx,8
        mov  dx,184
        call FNT_PUT
        mov  al,FNT_LSCORE
        call FNT_LOOK
        mov  ax,1250
        mov  cl,6
        mov  bx,36
        mov  dx,182
        call FNT_NUMZ
        mov  byte [fnt_scale],2 ; digits x2, steel ramp
        mov  byte [fnt_rw],1
        mov  word [fnt_gtab],fnt_steel
        mov  byte [fnt_gn],FNT_STEELN
        mov  si,sTime
        mov  bx,312
        mov  dx,180
        call FNT_RIGHT

        call Hold               ; ~2 s under /AUTO, else until Esc
        mov  ax,0003h
        int  10h                ; text again
        call Report
        mov  ax,4C00h
        int  21h

; ============================================================================
;  The test's helpers.
; ============================================================================
; Plain - the look back to: 8x8, x1, blocks, fixed, plain, white, no ramp
Plain:  mov  byte [fnt_font],FNT_F8
        mov  byte [fnt_scale],1
        mov  byte [fnt_smooth],0
        mov  byte [fnt_prop],0
        mov  byte [fnt_style],FNT_PLAIN
        mov  byte [fnt_col],15
        mov  byte [fnt_rc],0
        mov  byte [fnt_rw],1
        mov  byte [fnt_shc],0
        mov  byte [fnt_shd],1
        mov  byte [fnt_gap],0
        mov  byte [fnt_gn],0
        mov  word [fnt_gtab],0
        ret

; RomBits - AX = the set bits of character AL in the BIOS font BH (3: 8x8,
; 6: 8x16), CX rows
RomBits:push bx
        push cx
        push dx
        push si
        push bp
        push es
        push ax
        push cx
        mov  ax,1130h
        int  10h                ; ES:BP = the font
        pop  cx
        pop  ax
        xor  ah,ah
        mul  cx                 ; AX = char * rows
        mov  si,ax
        add  si,bp              ; ES:SI = the glyph
        xor  dx,dx
.r:     mov  al,[es:si]
        inc  si
.b:     shl  al,1
        adc  dx,0               ; DX += the bit that fell out
        or   al,al
        jnz  .b
        loop .r
        mov  ax,dx
        pop  es
        pop  bp
        pop  si
        pop  dx
        pop  cx
        pop  bx
        ret

; RingChk - AL = ink, AH = ring. DL bit 0: a ring pixel with no ink among its
; eight neighbours; bit 1: some other pixel with ink beside it (unringed).
; Scans x 1..318, y 1..198.
RingChk:push bx
        push cx
        push si
        push di
        xor  dl,dl
        mov  di,321
        mov  bx,198
.y:     mov  cx,318
.x:     mov  dh,[es:di]
        cmp  dh,al
        je   .n                 ; the ink itself
        cmp  dh,ah
        jne  .bg
        call Beside             ; CF = ink beside
        jc   .n                 ; a ring pixel touching ink: right
        or   dl,1
        jmp  .n
.bg:    call Beside
        jnc  .n                 ; background with no ink beside: right
        or   dl,2
.n:     inc  di
        loop .x
        add  di,2               ; past x 319 and x 0
        dec  bx
        jnz  .y
        pop  di
        pop  si
        pop  cx
        pop  bx
        ret
; Beside - CF = 1 if one of the eight around ES:DI is AL
Beside: push si
        push bx
        mov  si,nOff
.l:     mov  bx,[si]
        cmp  [es:di+bx],al
        je   .y
        add  si,2
        cmp  si,nOff+16
        jb   .l
        pop  bx
        pop  si
        clc
        ret
.y:     pop  bx
        pop  si
        stc
        ret
nOff    dw -321,-320,-319,-1,1,319,320,321

; ShadChk - ZF = 1 if every pixel of colour 8 has colour 15 up-left of it
ShadChk:push ax
        push cx
        push di
        mov  di,321
        mov  cx,64000-321
.l:     cmp  byte [es:di],8
        jne  .n
        cmp  byte [es:di-321],15
        jne  .x                 ; ZF = 0
.n:     inc  di
        loop .l
        cmp  ax,ax              ; ZF = 1
.x:     pop  di
        pop  cx
        pop  ax
        ret

; Bounds - minx, maxx, miny, maxy of the pixels that are not 0
Bounds: push ax
        push bx
        push cx
        push dx
        push di
        mov  word [minx],320
        mov  word [maxx],0
        mov  word [miny],200
        mov  word [maxy],0
        xor  di,di
        xor  dx,dx              ; DX = y
.y:     xor  bx,bx              ; BX = x
.x:     cmp  byte [es:di],0
        je   .n
        cmp  bx,[minx]
        jae  .a
        mov  [minx],bx
.a:     cmp  bx,[maxx]
        jbe  .b
        mov  [maxx],bx
.b:     cmp  dx,[miny]
        jae  .c
        mov  [miny],dx
.c:     cmp  dx,[maxy]
        jbe  .n
        mov  [maxy],dx
.n:     inc  di
        inc  bx
        cmp  bx,320
        jb   .x
        inc  dx
        cmp  dx,200
        jb   .y
        pop  di
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; RowCol - AL = the first non-0 pixel's colour in row BX (0 if none)
RowCol: push cx
        push di
        mov  ax,bx
        mov  cx,320
        mul  cx                 ; AX = y * 320
        mov  di,ax
        mov  cx,320
.l:     mov  al,[es:di]
        or   al,al
        jnz  .x
        inc  di
        loop .l
.x:     pop  di
        pop  cx
        ret

; Zero - ZF = 1 if every pixel x BX..CX, y DX..SI is 0
Zero:   push ax
        push bx
        push dx
        push di
.y:     mov  ax,dx
        push dx
        mov  di,320
        mul  di                 ; AX = y * 320
        pop  dx
        add  ax,bx
        mov  di,ax              ; DI = the row's first pixel
        push bx
.x:     cmp  byte [es:di],0
        jne  .no
        inc  di
        inc  bx
        cmp  bx,cx
        jbe  .x
        pop  bx
        inc  dx
        cmp  dx,si
        jbe  .y
        cmp  ax,ax              ; ZF = 1
        jmp  .r
.no:    pop  bx                 ; ZF = 0 (from the compare)
.r:     pop  di
        pop  dx
        pop  bx
        pop  ax
        ret

; Sent / SentOK - a pattern in the 1536 bytes past the screen, and its check
Sent:   push ax
        push cx
        push di
        mov  di,64000
        mov  cx,768
        mov  ax,0A55Ah
        rep  stosw
        pop  di
        pop  cx
        pop  ax
        ret
SentOK: push ax
        push cx
        push di
        mov  di,64000
        mov  cx,768
        mov  ax,0A55Ah
        repe scasw              ; ZF = 1 if all 768 words are the pattern
        pop  di
        pop  cx
        pop  ax
        ret

; NbEq - ZF = 1 if fnt_nb's digits (they end at fnt_nb+5) are string DI
NbEq:   push cx
        push si
        mov  si,di
        xor  cx,cx
.l:     cmp  byte [si],0        ; CX = the string's length
        je   .e
        inc  si
        inc  cx
        jmp  .l
.e:     mov  si,fnt_nb+5
        sub  si,cx              ; SI = where that many digits begin
        call StrEq
        pop  si
        pop  cx
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

; Stripes - a busy background: diagonal bands of white, black and colours,
; and a white and a black block under the title's middle
Stripes:push ax
        push bx
        push cx
        push dx
        push di
        xor  di,di
        xor  dx,dx              ; DX = y
.y:     xor  bx,bx              ; BX = x
.x:     mov  ax,bx
        add  ax,dx              ; x + y
        mov  cl,3
        shr  ax,cl              ; (x + y) / 8
        and  ax,7               ; one of eight bands
        push bx
        mov  bx,ax
        mov  al,[band+bx]
        pop  bx
        mov  [es:di],al
        inc  di
        inc  bx
        cmp  bx,320
        jb   .x
        inc  dx
        cmp  dx,200
        jb   .y
        pop  di
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
band    db 15,9,14,0,12,7,2,11

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

; Shot - under /S: the screen (64000 bytes) and the DAC (768) into SHOT.RAW
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
auto    db 0
bad     db 0
nres    dw 0
res     db 4*20 dup(0)
bitsA   dw 0
bitsH   dw 0
bitsA16 dw 0
ring1   dw 0
wid     dw 0
minx    dw 0
maxx    dw 0
miny    dw 0
maxy    dw 0
g4      db 1,2,3,4
sA      db 'A',0
sH      db 'H',0
sW      db 'W',0
sAW     db 'AW',0
sAZ     db 'AZ',0
s81     db '81',0
sABC    db 'ABC',0
s120    db '120',0
sOWL    db 'OWL',0
sHUD    db 'HUD',0
s00120  db '00120',0
s65535  db '65535',0
s0      db '0',0
sTitle  db 'Owl Fonts',0
sFire   db 'Fire 8x16',0
sIce    db 'Ice x2',0
sSmooth db 'Smooth x2',0
sBlock  db 'Blocks x2',0
sBig    db 'UBIG 4X6 X3',0
sX3     db 'Lime x3',0
sMenu1  db '1 New game',0
sMenu2  db '2 Ringed menu',0
sP8     db '8x8 plain',0
sS8     db '8x8 shadow',0
sR8     db '8x8 ringed',0
sHud    db 'FNT_HUD: ALT 1200  SPD 340  FUEL 87%  THE 4X6 RINGED, FAST',0
sHudP   db '4X6 PLAIN - LOST ON STRIPES',0
sHud2   db '4X6 X2 RING',0
sScore  db 'SCORE',0
sTime   db '12:45',0
sPass   db 'PASS $'
sFail   db 'FAIL $'
sCrlf   db 13,10,'$'
sAll    db 'FFONT: all checks PASS',13,10,'$'
sSome   db 'FFONT: SOME CHECKS FAILED',13,10,'$'
m1      db '8x8 A plain = its BIOS bits; x2 = 4x, x3 = 9x; BX on by 8, 16$'
m2      db '8x16 A = its bits; 4x6 A = 10; digits 81 = 45; advances 4, 7$'
m3      db 'ring 1px on 8x8 AW: every ring pixel touches ink, none missing$'
m4      db 'ring on smooth x4 (Scale2x twice) and x3 (Scale3x): exact$'
m5      db 'ring 2px: nothing next to the ink unringed, fatter than 1px$'
m6      db 'FNT_HUD AZ: 19 ink pixels, ring exact, BX on by 8$'
m7      db 'shadow: ink whole, every shadow pixel down-right of ink$'
m8      db 'gradient: first colour on top, last at the bottom, 16x bits$'
m9      db 'clipping: off all four edges no wrap, 64000+ untouched$'
m10     db 'widths: ABC 23/11/46, digits 20, prop x4 measured, centred$'
m11     db 'FNT_HEIGHT 32/15, FNT_NUMZ 00120, NUM 65535 0, FNT_RIGHT$'
m12     db 'registers kept by PUT CENTER HUD NUMZ LOOK$'
m13     db 'transparent: ink + untouched background = 64000$'
m14     db 'K_TEXT + K_FONT in one program: TXT_WIDTH 24, FNT_WIDTH 23$'
dac     db 768 dup(0)

        include '..\..\KIT\LIB\K_FONT.INC'
        include '..\..\KIT\LIB\K_TEXT.INC'
