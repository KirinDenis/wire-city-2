; ============================================================================
;  K_TEXT.INC - KIT: letters and numbers on a mode-13h picture, and on DOS.
;
;  Two fonts, one set of calls:
;    [txt_font] 0  the BIOS's 8x8 letters (characters 0..127; the video
;                  BIOS says where they are, INT 10h AX=1130h BH=3; a CGA
;                  BIOS without that call keeps them at F000:FA6E)
;    [txt_font] 1  OWL FLY's own 4x6 letters, built in: ASCII 32..95 (small
;                  letters drawn as capitals), 3x5 pixels in a 4x6 cell
;  How they look, set once and kept:
;    [txt_col]    the ink                    [txt_scale] 1 or 2 (2 = twice as big)
;    [txt_style]  0 plain, 1 a shadow down-right, 2 a ring all round - the
;                 ring reads on any background, even the ink's own colour
;    [txt_shc]    the shadow's / ring's colour (0 black)
;    [txt_boxc]   TXT_BOX's box colour
;  Only the letters' pixels are drawn (transparent), each clipped to the
;  screen 0..319 x 0..199, into ES (320 bytes a row).
;
;        mov  byte [txt_col],14
;        mov  byte [txt_style],2        ; ringed
;        mov  si,hello                  ; db 'SCORE ',0
;        mov  bx,8                      ; x
;        mov  dx,4                      ; y
;        call TXT_PUT                   ; BX = past the last letter
;        mov  ax,[score]
;        call TXT_NUM                   ; the number right after it
;
;  TXT_DOS, TXT_DOSZ, TXT_DOSNUM, TXT_DOSCR are for text-mode programs and
;  test reports: DOS INT 21h, so a > redirect catches them.
; ============================================================================

; ---- the look --------------------------------------------------------------
if used txt_col
txt_col   db 15                 ; the ink
end if
if used txt_shc
txt_shc   db 0                  ; the shadow's / ring's colour
end if
if used txt_style
txt_style db 0                  ; 0 plain, 1 shadow, 2 ring
end if
if used txt_scale
txt_scale db 1                  ; 1 or 2
end if
if used txt_font
txt_font  db 0                  ; 0 the BIOS 8x8, 1 the built-in 4x6
end if
if used txt_boxc
txt_boxc  db 1                  ; TXT_BOX's box (1 dark blue)
end if

; ---- TXT_DOT (inside the kit): a scale x scale block of colour AL at
;  (BX,DX), clipped to the screen. Every register kept.
if used TXT_DOT
TXT_DOT:
        push bx
        push cx
        push dx
        push di
        mov  ch,[txt_scale]     ; CH = rows of the block
.r:     mov  cl,[txt_scale]     ; CL = columns
        push bx
.c:     cmp  bx,319             ; off the screen? (unsigned: a negative
        ja   .n                 ;  x is huge too)
        cmp  dx,199
        ja   .n
        push ax
        push bx
        mov  di,dx              ; DI = y
        mov  ax,dx
        push cx
        mov  cl,8
        shl  di,cl              ; DI = y * 256
        mov  cl,6
        shl  ax,cl              ; AX = y * 64
        pop  cx
        add  di,ax              ; DI = y * 320
        add  di,bx              ; DI = y * 320 + x
        pop  bx
        pop  ax
        mov  [es:di],al         ; the pixel
.n:     inc  bx                 ; x++
        dec  cl
        jnz  .c
        pop  bx
        inc  dx                 ; y++
        dec  ch
        jnz  .r
        pop  di
        pop  dx
        pop  cx
        pop  bx
        ret
end if

; ---- TXT_GLY (inside the kit): the glyph in txt_g ([txt_gr] rows, [txt_gw]
;  pixels wide, the left pixel the top bit) at (BX,DX) in colour AL.
if used TXT_GLY
TXT_GLY:
        push bx
        push cx
        push dx
        push si
        push bp
        mov  si,txt_g           ; SI = the rows
        mov  ch,[txt_gr]        ; CH = rows left
.r:     mov  ah,[si]            ; AH = this row's bits
        inc  si
        push bx
        mov  cl,[txt_gw]        ; CL = pixels across
.b:     shl  ah,1               ; the next pixel into CF
        jnc  .n
        call TXT_DOT            ; set: a block
.n:     push ax
        mov  al,[txt_scale]
        cbw                     ; AX = the scale
        add  bx,ax              ; x += scale
        pop  ax
        dec  cl
        jnz  .b
        pop  bx
        push ax
        mov  al,[txt_scale]
        cbw                     ; AX = the scale
        add  dx,ax              ; y += scale
        pop  ax
        dec  ch
        jnz  .r
        pop  bp
        pop  si
        pop  dx
        pop  cx
        pop  bx
        ret
txt_g     db 8 dup(0)           ; the glyph being drawn
txt_gr    db 8                  ; its rows
txt_gw    db 8                  ; its width
end if

; ---- TXT_LOAD (inside the kit): character AL's glyph into txt_g in the
;  current font; CF = 1 when the font has no picture for it. AX kept.
if used TXT_LOAD
TXT_LOAD:
        push ax
        push cx
        push si
        push di
        cmp  byte [txt_font],0
        jne  .f4
        cmp  al,128             ; the BIOS 8x8 table holds 0..127
        jae  .no
        cmp  word [txt_fptr+2],0 ; the font found yet?
        jne  .have
        call TXT_FINDF
.have:  xor  ah,ah
        mov  cl,3
        shl  ax,cl              ; AX = char * 8: eight bytes a glyph
        push ds
        push es
        push ds
        pop  es                 ; ES:DI = txt_g
        mov  di,txt_g
        lds  si,[txt_fptr]      ; DS:SI = the font (read before DS moves)
        add  si,ax
        mov  cx,4
        cld
        rep  movsw              ; the eight rows
        pop  es
        pop  ds
        mov  byte [txt_gr],8
        mov  byte [txt_gw],8
        jmp  .ok
.f4:    cmp  al,'a'             ; small letters as capitals
        jb   .up
        cmp  al,'z'
        ja   .up
        sub  al,20h             ; AL = the capital
.up:    sub  al,32              ; AL = the index from the space
        jb   .no                ; below the space: no picture
        cmp  al,64
        jae  .no                ; past '_': none
        xor  ah,ah
        mov  si,ax
        add  si,si              ; SI = 2i
        add  si,si              ; SI = 4i
        add  si,ax              ; SI = 5i: five rows a letter
        add  si,txt_f4
        mov  di,txt_g
        mov  cx,5
.cp:    mov  al,[si]            ; the five rows
        mov  [di],al
        inc  si
        inc  di
        loop .cp
        mov  byte [txt_gr],5
        mov  byte [txt_gw],3
.ok:    clc
        jmp  .r
.no:    stc
.r:     pop  di
        pop  si
        pop  cx
        pop  ax
        ret

; TXT_FINDF - ask the video BIOS where its 8x8 font is (AX=1130h BH=3);
; preset F000:FA6E, which a CGA BIOS that does not know the call leaves.
TXT_FINDF:
        push ax
        push bx
        push cx
        push dx
        push bp
        push es
        mov  ax,0F000h
        mov  es,ax
        mov  bp,0FA6Eh          ; ES:BP = the CGA place
        mov  ax,1130h
        mov  bh,3               ; BH 3: the 8x8 font, characters 0..127
        int  10h                ; ES:BP = the font (CX, DL clobbered)
        mov  word [txt_fptr],bp
        mov  word [txt_fptr+2],es
        pop  es
        pop  bp
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
txt_fptr  dd 0                  ; the 8x8 font, offset and segment (0 = not asked yet)

; OWL FLY III's 4x6 letters (OWLFLY3B VID.INC VFONT) with the rest of ASCII
; 32..95 MULTSOK2 drew for them: five rows each, the high three bits a row
txt_f4  db 0,0,0,0,0                                        ; space
        db 01000000b,01000000b,01000000b,00000000b,01000000b ; !
        db 10100000b,10100000b,00000000b,00000000b,00000000b ; "
        db 10100000b,11100000b,10100000b,11100000b,10100000b ; #
        db 01100000b,11000000b,01000000b,01100000b,11000000b ; $
        db 10100000b,00100000b,01000000b,10000000b,10100000b ; %
        db 01000000b,10100000b,01000000b,10100000b,01100000b ; &
        db 01000000b,01000000b,00000000b,00000000b,00000000b ; '
        db 00100000b,01000000b,01000000b,01000000b,00100000b ; (
        db 10000000b,01000000b,01000000b,01000000b,10000000b ; )
        db 00000000b,10100000b,01000000b,10100000b,00000000b ; *
        db 00000000b,01000000b,11100000b,01000000b,00000000b ; +
        db 00000000b,00000000b,00000000b,01000000b,10000000b ; ,
        db 00000000b,00000000b,11100000b,00000000b,00000000b ; -
        db 00000000b,00000000b,00000000b,00000000b,01000000b ; .
        db 00100000b,00100000b,01000000b,10000000b,10000000b ; /
        db 11100000b,10100000b,10100000b,10100000b,11100000b ; 0
        db 01000000b,11000000b,01000000b,01000000b,11100000b ; 1
        db 11100000b,00100000b,11100000b,10000000b,11100000b ; 2
        db 11100000b,00100000b,11100000b,00100000b,11100000b ; 3
        db 10100000b,10100000b,11100000b,00100000b,00100000b ; 4
        db 11100000b,10000000b,11100000b,00100000b,11100000b ; 5
        db 11100000b,10000000b,11100000b,10100000b,11100000b ; 6
        db 11100000b,00100000b,01000000b,01000000b,01000000b ; 7
        db 11100000b,10100000b,11100000b,10100000b,11100000b ; 8
        db 11100000b,10100000b,11100000b,00100000b,11100000b ; 9
        db 00000000b,01000000b,00000000b,01000000b,00000000b ; :
        db 00000000b,01000000b,00000000b,01000000b,10000000b ; ;
        db 00100000b,01000000b,10000000b,01000000b,00100000b ; <
        db 00000000b,11100000b,00000000b,11100000b,00000000b ; =
        db 10000000b,01000000b,00100000b,01000000b,10000000b ; >
        db 11100000b,00100000b,01000000b,00000000b,01000000b ; ?
        db 11100000b,10100000b,11100000b,10000000b,11100000b ; @
        db 01000000b,10100000b,11100000b,10100000b,10100000b ; A
        db 11000000b,10100000b,11000000b,10100000b,11000000b ; B
        db 01100000b,10000000b,10000000b,10000000b,01100000b ; C
        db 11000000b,10100000b,10100000b,10100000b,11000000b ; D
        db 11100000b,10000000b,11000000b,10000000b,11100000b ; E
        db 11100000b,10000000b,11000000b,10000000b,10000000b ; F
        db 01100000b,10000000b,10100000b,10100000b,01100000b ; G
        db 10100000b,10100000b,11100000b,10100000b,10100000b ; H
        db 11100000b,01000000b,01000000b,01000000b,11100000b ; I
        db 00100000b,00100000b,00100000b,10100000b,01000000b ; J
        db 10100000b,11000000b,10000000b,11000000b,10100000b ; K
        db 10000000b,10000000b,10000000b,10000000b,11100000b ; L
        db 10100000b,11100000b,10100000b,10100000b,10100000b ; M
        db 11100000b,10100000b,10100000b,10100000b,10100000b ; N
        db 11100000b,10100000b,10100000b,10100000b,11100000b ; O
        db 11100000b,10100000b,11100000b,10000000b,10000000b ; P
        db 11100000b,10100000b,10100000b,11100000b,00100000b ; Q
        db 11000000b,10100000b,11000000b,10100000b,10100000b ; R
        db 11100000b,10000000b,11100000b,00100000b,11100000b ; S
        db 11100000b,01000000b,01000000b,01000000b,01000000b ; T
        db 10100000b,10100000b,10100000b,10100000b,11100000b ; U
        db 10100000b,10100000b,10100000b,10100000b,01000000b ; V
        db 10100000b,10100000b,10100000b,11100000b,10100000b ; W
        db 10100000b,10100000b,01000000b,10100000b,10100000b ; X
        db 10100000b,10100000b,01000000b,01000000b,01000000b ; Y
        db 11100000b,00100000b,01000000b,10000000b,11100000b ; Z
        db 11000000b,10000000b,10000000b,10000000b,11000000b ; [
        db 10000000b,10000000b,01000000b,00100000b,00100000b ; \
        db 01100000b,00100000b,00100000b,00100000b,01100000b ; ]
        db 01000000b,10100000b,00000000b,00000000b,00000000b ; ^
        db 00000000b,00000000b,00000000b,00000000b,11100000b ; _
end if

; ----------------------------------------------------------------------
;@ TXT_CHAR   one letter AL at (BX,DX) in the current font, scale and style
;  in:  AL = the character, BX = x, DX = y, [txt_font] [txt_col]
;       [txt_scale] [txt_style] [txt_shc]
;  out: BX = x of the next letter (8 or 4 times the scale on)
;  needs: -
;  from: GAMES\MULTSOK2\DRAW.INC:602-746 PUTC4/PUTC8/GLYPH8 (shadow, x2),
;        LESSONS\L26\LETTERS.ASM:2072 TXT46O's ring (drawn here as the
;        letter in txt_shc at its eight neighbours, then the ink)
; ----------------------------------------------------------------------
if used TXT_CHAR
TXT_CHAR:
        push ax
        call TXT_LOAD           ; its picture into txt_g
        jc   .adv               ; none: just move on
        cmp  byte [txt_style],1
        jb   .ink               ; plain
        ja   .ring
        push bx                 ; 1: the shadow, a scale down and right
        push dx
        mov  al,[txt_scale]
        cbw                     ; AX = the scale
        add  bx,ax              ; x + scale
        add  dx,ax              ; y + scale
        mov  al,[txt_shc]
        call TXT_GLY
        pop  dx
        pop  bx
        jmp  .ink
.ring:  push si                 ; 2: the ring, one pixel all round
        mov  si,txt_ring
        mov  al,[txt_shc]
.rg:    push bx
        push dx
        push ax
        mov  al,[si]
        cbw                     ; AX = dx of this neighbour
        add  bx,ax              ; x + dx
        mov  al,[si+1]
        cbw                     ; AX = dy
        add  dx,ax              ; y + dy
        pop  ax
        call TXT_GLY
        pop  dx
        pop  bx
        add  si,2               ; the next neighbour
        cmp  si,txt_ring+16
        jb   .rg
        pop  si
.ink:   mov  al,[txt_col]
        call TXT_GLY            ; the letter itself on top
.adv:   mov  al,8               ; the cell: 8 wide...
        cmp  byte [txt_font],0
        je   .w
        mov  al,4               ; ...or 4
.w:     mul  byte [txt_scale]   ; AX = cell * scale
        add  bx,ax              ; x on to the next cell
        pop  ax
        ret
txt_ring db -1,-1, 0,-1, 1,-1, -1,0, 1,0, -1,1, 0,1, 1,1
end if

; ----------------------------------------------------------------------
;@ TXT_PUT    zero-ended string SI at (BX,DX) in the current font and look
;  in:  SI = the string (DS), BX = x, DX = y, [txt_font] [txt_col]
;       [txt_scale] [txt_style] [txt_shc]
;  out: BX = x past the last letter (a number can follow at once)
;  needs: -
;  from: GAMES\MULTSOK2\DRAW.INC PRINT4/PRINT8; EXAMPLES\RELIEF.ASM:747 TXT
; ----------------------------------------------------------------------
if used TXT_PUT
TXT_PUT:
        push ax
        push si
.l:     mov  al,[si]
        inc  si
        or   al,al              ; the end?
        jz   .e
        call TXT_CHAR
        jmp  .l
.e:     pop  si
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ TXT_PUT8   string SI at (BX,DX) in the BIOS 8x8 letters (x1/x2, styled)
;  in:  SI = the string, BX = x, DX = y, [txt_col] [txt_scale] [txt_style]
;  out: BX = x past the last letter ([txt_font] is left as it was)
;  needs: -
;  from: EXAMPLES\RELIEF.ASM:747-791 TXT; font pointer as
;        GAMES\MULTSOK2\MULTSOK2.ASM:699-705
; ----------------------------------------------------------------------
if used TXT_PUT8
TXT_PUT8:
        push ax
        mov  al,[txt_font]
        mov  byte [txt_font],0
        call TXT_PUT
        mov  [txt_font],al
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ TXT_PUT4   string SI at (BX,DX) in the built-in 4x6 letters (x1/x2, styled)
;  in:  SI = the string, BX = x, DX = y, [txt_col] [txt_scale] [txt_style]
;  out: BX = x past the last letter ([txt_font] is left as it was)
;  needs: -
;  from: GAMES\OWLFLY3B\SRC\VID.INC:1241-1288 VFONT + GAMES\OWLFLY3\SRC\
;        HUD.INC:232-301 FDRAW; the full ASCII 32..95 set from MULTSOK2.ASM
;        FONT4
; ----------------------------------------------------------------------
if used TXT_PUT4
TXT_PUT4:
        push ax
        mov  al,[txt_font]
        mov  byte [txt_font],1
        call TXT_PUT
        mov  [txt_font],al
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ TXT_LEN    CX = the length of the zero-ended string at SI
;  in:  SI = the string
;  out: CX = its characters
;  needs: -
;  from: GAMES\MULTSOK2\DRAW.INC:770-778 STRLEN
; ----------------------------------------------------------------------
if used TXT_LEN
TXT_LEN:
        push ax
        push si
        xor  cx,cx
.l:     mov  al,[si]
        inc  si
        or   al,al
        jz   .e
        inc  cx                 ; one more
        jmp  .l
.e:     pop  si
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ TXT_WIDTH  CX = the width in pixels string SI takes in the current font
;  in:  SI = the string, [txt_font] [txt_scale]
;  out: CX = characters * cell (8 or 4) * scale
;  needs: -
;  from: new
; ----------------------------------------------------------------------
if used TXT_WIDTH
TXT_WIDTH:
        push ax
        push dx
        call TXT_LEN            ; CX = characters
        mov  al,8               ; the cell
        cmp  byte [txt_font],0
        je   .w
        mov  al,4
.w:     mul  byte [txt_scale]   ; AX = cell * scale
        mul  cx                 ; AX = characters * cell * scale
        mov  cx,ax
        pop  dx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ TXT_CENTER string SI centred on x BX, its top at y DX
;  in:  SI = the string, BX = the centre x (160: the screen), DX = y
;  out: -
;  needs: -
;  from: GAMES\MULTSOK2\DRAW.INC:796-806 BANNER (the centring)
; ----------------------------------------------------------------------
if used TXT_CENTER
TXT_CENTER:
        push bx
        push cx
        call TXT_WIDTH          ; CX = the width
        shr  cx,1               ; CX = half of it
        sub  bx,cx              ; BX = the left edge
        call TXT_PUT
        pop  cx
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ TXT_BOX    string SI centred on x BX at y DX, on a box of [txt_boxc]
;  in:  SI = the string, BX = the centre x, DX = y of the letters' top,
;       [txt_boxc] the box (default 1 dark blue) and the text look
;  out: - (the box reaches 4 pixels round the letters across, 3 up/down)
;  needs: -
;  from: GAMES\MULTSOK2\DRAW.INC:796-826 BANNER
; ----------------------------------------------------------------------
if used TXT_BOX
TXT_BOX:
        push ax
        push bx
        push cx
        push dx
        push di
        call TXT_WIDTH          ; CX = the letters' width
        push bx
        mov  ax,cx
        shr  ax,1               ; AX = half the width
        sub  bx,ax              ; BX = the letters' left
        sub  bx,4               ; BX = the box's left
        add  cx,8               ; CX = the box's width
        push dx
        sub  dx,3               ; DX = the box's top
        mov  al,8               ; the letters' height: 8...
        cmp  byte [txt_font],0
        je   .h
        mov  al,5               ; ...or 5
.h:     mul  byte [txt_scale]   ; AX = height * scale
        add  ax,6               ; AX = the box's rows
        mov  di,ax
        mov  al,[txt_boxc]
        call TXT_FILL           ; the box
        pop  dx
        pop  bx
        call TXT_CENTER         ; the letters on it
        pop  di
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; TXT_FILL - box BX,DX (x,y), CX wide, DI rows, colour AL, clipped
TXT_FILL:
        push bx
        push cx
        push dx
        push di
        push si
        mov  si,cx              ; SI = the width
.r:     mov  cx,si
        push bx
.c:     cmp  bx,319             ; on the screen? (unsigned)
        ja   .n
        cmp  dx,199
        ja   .n
        push di
        push ax
        push cx
        mov  di,dx
        mov  ax,dx
        mov  cl,8
        shl  di,cl              ; DI = y * 256
        mov  cl,6
        shl  ax,cl              ; AX = y * 64
        add  di,ax              ; DI = y * 320
        add  di,bx              ; DI = y * 320 + x
        pop  cx
        pop  ax
        mov  [es:di],al
        pop  di
.n:     inc  bx                 ; x++
        loop .c
        pop  bx
        inc  dx                 ; y++
        dec  di                 ; rows--
        jnz  .r
        pop  si
        pop  di
        pop  dx
        pop  cx
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ TXT_UTOA   AX unsigned as decimal digits at DI, at least CL of them
;  in:  AX = the value, CL = the fewest digits (0 or 1: no padding), DI = where
;  out: DI = past the last digit (no end mark written)
;  needs: -
;  from: GAMES\MULTSOK2\DRAW.INC:672-693 NUMSTR; the field rule of
;        GAMES\OWLFLY3\SRC\HUD.INC:327-347 FNUMZ (too long runs long)
; ----------------------------------------------------------------------
if used TXT_UTOA
TXT_UTOA:
        push ax
        push bx
        push cx
        push dx
        push si
        mov  si,txt_ub+6        ; SI = the end of a scratch: digits go backwards
        mov  bx,10
        xor  ch,ch              ; CH = digits so far
.dig:   xor  dx,dx              ; DX:AX = the value
        div  bx                 ; AX = value / 10, DX = the last digit
        add  dl,'0'             ; DL = its character
        dec  si
        mov  [si],dl
        inc  ch                 ; one more digit
        or   ax,ax
        jnz  .dig
.pad:   cmp  ch,cl              ; as many as asked?
        jae  .cp
        cmp  si,txt_ub          ; (never more than the scratch holds)
        jbe  .cp
        dec  si
        mov  byte [si],'0'      ; a zero in front
        inc  ch
        jmp  .pad
.cp:    mov  al,[si]            ; copy them out, forwards
        mov  [di],al
        inc  si
        inc  di
        cmp  si,txt_ub+6
        jb   .cp
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
txt_ub   db 6 dup(0)
end if

; ----------------------------------------------------------------------
;@ TXT_NUMSTR SI = AX as a zero-ended decimal string, at least CL digits
;  in:  AX = the value (unsigned), CL = the fewest digits
;  out: SI = the string (in txt_nb, good until the next call)
;  needs: -
;  from: GAMES\MULTSOK2\DRAW.INC:672-693 NUMSTR
; ----------------------------------------------------------------------
if used TXT_NUMSTR
TXT_NUMSTR:
        push di
        mov  di,txt_nb
        call TXT_UTOA
        mov  byte [di],0        ; the end mark
        mov  si,txt_nb
        pop  di
        ret
end if
if used txt_nb
txt_nb   db 12 dup(0)
end if

; ----------------------------------------------------------------------
;@ TXT_NUM    AX unsigned in decimal at (BX,DX), current font and look
;  in:  AX = the value, BX = x, DX = y
;  out: BX = x past the last digit
;  needs: -
;  from: GAMES\OWLFLY3\SRC\HUD.INC:302-315 FNUM
; ----------------------------------------------------------------------
if used TXT_NUM
TXT_NUM:
        push cx
        push si
        mov  cl,1
        call TXT_NUMSTR
        call TXT_PUT
        pop  si
        pop  cx
        ret
end if

; ----------------------------------------------------------------------
;@ TXT_NUMZ   AX unsigned, zero-padded to CL digits, at (BX,DX)
;  in:  AX = the value, CL = the digits (1..5), BX = x, DX = y
;  out: BX = x past the last digit (a value too wide runs long, never lies)
;  needs: -
;  from: GAMES\OWLFLY3\SRC\HUD.INC:317-347 FNUMZ
; ----------------------------------------------------------------------
if used TXT_NUMZ
TXT_NUMZ:
        push si
        call TXT_NUMSTR
        call TXT_PUT
        pop  si
        ret
end if

; ----------------------------------------------------------------------
;@ TXT_SNUM   AX signed in decimal at (BX,DX): "-12", "7"
;  in:  AX = the value (signed), BX = x, DX = y
;  out: BX = x past the last digit
;  needs: -
;  from: GAMES\MULTSOK2\DRAW.INC:659-668 PSNUM4
; ----------------------------------------------------------------------
if used TXT_SNUM
TXT_SNUM:
        push ax
        or   ax,ax
        jns  .p
        push ax
        mov  al,'-'
        call TXT_CHAR           ; the sign
        pop  ax
        neg  ax                 ; AX = the size (-32768 stays 32768 unsigned)
.p:     call TXT_NUM
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ TXT_NUMK   AX unsigned, short: 999 as "999", 1400 as "1.4K", 65535 "65.5K"
;  in:  AX = the value, BX = x, DX = y
;  out: BX = x past the text
;  needs: -
;  from: new (TXT_UTOA's digits)
; ----------------------------------------------------------------------
if used TXT_NUMK
TXT_NUMK:
        cmp  ax,1000
        jae  .k
        jmp  TXT_NUM            ; under a thousand: as it is
.k:     push ax
        push cx
        push dx
        push si
        push di
        push dx
        xor  dx,dx              ; DX:AX = the value
        mov  cx,100
        div  cx                 ; AX = hundreds (10..655): tenths of a K
        xor  dx,dx
        mov  cx,10
        div  cx                 ; AX = thousands, DX = the tenth
        mov  di,txt_nb
        mov  cl,1
        call TXT_UTOA           ; the thousands
        mov  byte [di],'.'
        add  dl,'0'             ; DL = the tenth's digit
        mov  [di+1],dl
        mov  byte [di+2],'K'
        mov  byte [di+3],0
        pop  dx
        mov  si,txt_nb
        call TXT_PUT
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ TXT_DOS    print the $-ended string at DX by DOS (text mode, redirectable)
;  in:  DX = the string
;  out: -
;  needs: -
;  from: INT 21h AH=9, as every program here
; ----------------------------------------------------------------------
if used TXT_DOS
TXT_DOS:
        push ax
        mov  ah,9
        int  21h
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ TXT_DOSZ   print the zero-ended string at SI by DOS
;  in:  SI = the string
;  out: -
;  needs: -
;  from: new (INT 21h AH=2 a character)
; ----------------------------------------------------------------------
if used TXT_DOSZ
TXT_DOSZ:
        push ax
        push dx
        push si
.l:     mov  dl,[si]
        inc  si
        or   dl,dl
        jz   .e
        mov  ah,2
        int  21h
        jmp  .l
.e:     pop  si
        pop  dx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ TXT_DOSNUM print AX unsigned in decimal by DOS
;  in:  AX = the value
;  out: -
;  needs: -
;  from: new (TXT_NUMSTR + TXT_DOSZ)
; ----------------------------------------------------------------------
if used TXT_DOSNUM
TXT_DOSNUM:
        push cx
        push si
        mov  cl,1
        call TXT_NUMSTR
        call TXT_DOSZ
        pop  si
        pop  cx
        ret
end if

; ----------------------------------------------------------------------
;@ TXT_DOSCR  print a new line (CR LF) by DOS
;  in:  -
;  out: -
;  needs: -
;  from: new
; ----------------------------------------------------------------------
if used TXT_DOSCR
TXT_DOSCR:
        push ax
        push dx
        mov  ah,2
        mov  dl,13
        int  21h
        mov  dl,10
        int  21h
        pop  dx
        pop  ax
        ret
end if
