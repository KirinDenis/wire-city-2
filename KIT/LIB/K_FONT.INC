; ============================================================================
;  K_FONT.INC - KIT: the house's good letters - outlined, shadowed, big,
;  smooth, with a colour ramp down the letters. For titles, HUD numbers
;  over a moving picture, and menus. Mode 13h, into ES (320 bytes a row).
;
;  K_TEXT.INC is the plain kit (TXT_*); this is the look (FNT_*). Both can
;  be included in one program - no name is shared.
;
;  FOUR FONTS, [fnt_font]:
;    FNT_F4    0  OWL FLY's 4x6 letters (3x5 in a 4x6 cell), ASCII 32..95,
;                 small letters drawn as capitals - the lessons' HUD font
;    FNT_F8    1  the BIOS's 8x8 letters, all 256 (INT 10h AX=1130h BH=3/4)
;    FNT_F16   2  the VGA BIOS's 8x16 letters (BH=6) - readable menus and
;                 long text; on a card without them, the 8x8 rows doubled
;    FNT_FDIG  3  bold arcade digits 6x7 (a 7x8 cell): 0-9 space - + : . % /
;                 - score and HUD numbers; any other character is a blank
;  THE LOOK, set once and kept (or all at once by FNT_LOOK):
;    [fnt_scale]  1..4 - each pixel of the font becomes scale x scale
;    [fnt_smooth] 1: at x2, x3, x4 the steps of a diagonal are filled in
;                 (Scale2x / Scale3x) - the 8x8 font at x4 looks drawn,
;                 not blown up. 0: square blocks (OWL FLY's UBIG look)
;    [fnt_prop]   1: each letter only as wide as its pixels plus one column
;                 (an I is narrow, a W wide) - the title look. 0: fixed cells
;    [fnt_style]  FNT_PLAIN, FNT_SHADOW (down-right), FNT_RING (a ring
;                 round every letter - reads on ANY background), FNT_RINGSH
;                 (ring, and a shadow of letter+ring)
;    [fnt_col]    the ink        [fnt_rc] the ring's colour  [fnt_rw] ring 1 or 2 px
;    [fnt_shc]    the shadow's colour         [fnt_shd] its offset in pixels
;    [fnt_gap]    extra pixels between letters
;    [fnt_gtab]   0, or a table of colours spread over the letters' height
;    [fnt_gn]     its length - a gradient: fnt_gold fnt_fire fnt_ice
;                 fnt_steel fnt_lime are ready, all in the DEFAULT palette
;
;  THE OUTLINE RULE: a dark ring one pixel round light letters. Then the
;  text reads on sky, on snow, on its own colour - everywhere.
;
;        mov  al,FNT_LTITLE             ; 8x8 x4 smooth, gold, ring+shadow
;        call FNT_LOOK
;        mov  si,name                   ; db 'OWL RUN',0
;        mov  bx,160                    ; the centre
;        mov  dx,30                     ; the top
;        call FNT_CENTER
;        mov  al,FNT_LSCORE             ; bold digits, ringed
;        call FNT_LOOK
;        mov  ax,[score]
;        mov  cl,5
;        mov  bx,250
;        mov  dx,4
;        call FNT_NUMZ                  ; 00120
;
;  FNT_HUD is the fast way for text redrawn every frame: the 4x6 letters
;  ringed by bit masks (lesson 1A's TXT46O), no map, no scale.
;  Only the letters' pixels are drawn (transparent), every pixel clipped
;  to 0..319 x 0..199. Every routine keeps every register but its "out:".
;
;  TWO TARGETS, [fnt_target]:
;    0  mode 13h: a byte a pixel in ES, 320 bytes a row (the default)
;    1  a FOUR-BITS-A-PIXEL buffer - K_D4.INC's, the one K_CARD.INC sends
;       to EGA, EGA 640, CGA and Hercules. ES is not used then. Every font,
;       scale, ring, shadow and look draws the same there:
;        call D4_INIT            ; (K_D4) AX = [crd_buf], BL = [crd_wide]
;        call FNT_OND4           ; the letters go where K_D4 draws
;        mov  al,FNT_LTITLE      ; ...then FNT_LOOK, FNT_PUT... as in 13h
;       or FNT_TO4 for a buffer of your own; FNT_TO13 back to mode 13h.
;       Colours are 0..15 there (KIT\ART\PALETTE.TXT). The two ramps the
;       looks use (fnt_gold, fnt_fire) are swapped for their 16-colour
;       twins by themselves; for others take fnt_gold4 fnt_fire4 fnt_ice4
;       fnt_steel4 fnt_lime4 (lengths FNT_GOLDN...). At EGA 640 (320 bytes
;       a row) a letter pixel is one of the game's 320 columns, a byte;
;       FNT_TO4 with DL = 1 draws on the 640 fine pixels instead (x 0..639).
;    A program that never calls FNT_TO4/FNT_OND4 assembles none of the 4bpp
;    code: its 13h drawing is exactly as fast as before.
; ============================================================================

FNT_F4     = 0                  ; the fonts
FNT_F8     = 1
FNT_F16    = 2
FNT_FDIG   = 3
FNT_PLAIN  = 0                  ; the styles
FNT_SHADOW = 1
FNT_RING   = 2
FNT_RINGSH = 3
FNT_LHUD   = 0                  ; the looks for FNT_LOOK
FNT_LMENU  = 1
FNT_LTITLE = 2
FNT_LSUB   = 3
FNT_LSCORE = 4
FNT_LBODY  = 5
FNT_LBIG   = 6
FNT_LFIRE  = 7

; ---- the look: FNT_LOOK copies a record over these, in this order ----------
if used FNT_GLYPH | used FNT_HUD | used FNT_LOOK | used FNT_HEIGHT
fnt_font   db FNT_F8            ; which font
fnt_scale  db 1                 ; 1..4
fnt_smooth db 0                 ; 1: Scale2x/3x at x2..x4
fnt_prop   db 0                 ; 1: proportional widths
fnt_style  db FNT_PLAIN         ; 0 plain 1 shadow 2 ring 3 ring+shadow
fnt_col    db 15                ; the ink
fnt_rc     db 0                 ; the ring's colour
fnt_rw     db 1                 ; the ring's width, 1 or 2
fnt_shc    db 0                 ; the shadow's colour
fnt_shd    db 1                 ; the shadow's offset, pixels down and right
fnt_gap    db 0                 ; extra pixels between letters
fnt_gn     db 0                 ; the gradient's length (0: plain ink)
fnt_gtab   dw 0                 ; the gradient's colours, top to bottom
end if

; ---- ready gradients, default mode-13h palette (no DAC change needed) -----
FNT_GOLDN  = 8                  ; their lengths, for [fnt_gn]
FNT_FIREN  = 8
FNT_ICEN   = 8
FNT_STEELN = 8
FNT_LIMEN  = 8
if used fnt_gold
fnt_gold   db 92,68,44,44,43,43,42,6        ; pale yellow to gold to brown
end if
if used fnt_fire
fnt_fire   db 15,44,43,42,41,40,40,112      ; white-hot to red to dark red
end if
if used fnt_ice
fnt_ice    db 15,100,76,52,53,54,55,32      ; white to cyan to blue
end if
if used fnt_steel
fnt_steel  db 31,31,30,29,27,26,24,22       ; white to grey
end if
if used fnt_lime
fnt_lime   db 94,70,46,47,48,48,120,120     ; pale to green to dark green
end if
; ---- their 16-colour twins, for the 4bpp target (EGA/CGA/Hercules) --------
if used fnt_gold4
fnt_gold4  db 15,14,14,14,14,14,6,6         ; white, gold, brown
end if
if used fnt_fire4
fnt_fire4  db 15,14,14,12,12,12,4,4         ; white-hot, gold, red, dark red
end if
if used fnt_ice4
fnt_ice4   db 15,11,11,9,9,3,1,1            ; white, pale cyan, blue, deep blue
end if
if used fnt_steel4
fnt_steel4 db 15,15,7,7,7,8,8,8             ; white, grey, dark grey
end if
if used fnt_lime4
fnt_lime4  db 15,10,10,10,10,2,2,2          ; white, lime, green
end if

; ---- the target: where the letters land ------------------------------------
if used fnt_target
fnt_target db 0                 ; 0: mode 13h bytes in ES; 1: the 4bpp buffer
fnt_tseg   dw 0                 ; 4bpp: the buffer's segment
fnt_tbase  dw 0                 ;  the offset of its first row
fnt_trowb  dw 160               ;  bytes a row: 160, or 320 at EGA 640
fnt_tcol   db 0                 ;  1: a pixel is a whole byte (EGA 640's columns)
fnt_txmax  dw 319               ;  the last x: 319, or 639 on the fine pixels
end if

; ----------------------------------------------------------------------
;@ FNT_TO4    draw the letters into a 4-bits-a-pixel buffer (EGA/CGA/Hercules) instead of ES
;  in:  AX = the buffer's segment, BX = the offset of its first row,
;       CX = bytes a row (160; 320 at EGA 640), DL = at 320 a row: 0 = 320
;       columns a byte each (K_D4's way), 1 = the 640 fine pixels (x 0..639)
;  out: - (fnt_target = 1 and its fnt_t... variables)
;  needs: - (the buffer two pixels a byte, the left in the high nibble)
;  from: new
; ----------------------------------------------------------------------
if used FNT_TO4
FNT_TO4:
        push ax
        mov  [fnt_tseg],ax
        mov  [fnt_tbase],bx
        mov  [fnt_trowb],cx
        mov  byte [fnt_target],1
        mov  byte [fnt_tcol],0  ; two pixels a byte...
        mov  ax,319
        cmp  cx,160
        jbe  .s                 ; 160 a row: 320 pixels
        or   dl,dl
        jnz  .f
        mov  byte [fnt_tcol],1  ; ...or EGA 640's column bytes
        jmp  .s
.f:     mov  ax,cx
        add  ax,ax              ; AX = two fine pixels a byte
        dec  ax                 ; the last x
.s:     mov  [fnt_txmax],ax
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ FNT_OND4   draw the letters where K_D4 draws (its d4_seg, d4_base, d4_rowb)
;  in:  - (K_D4's D4_INIT called first)
;  out: - (fnt_target = 1)
;  needs: K_D4.INC included, D4_INIT
;  from: new
; ----------------------------------------------------------------------
if used FNT_OND4
FNT_OND4:
        push ax
        push bx
        push cx
        push dx
        mov  ax,[d4_seg]
        mov  bx,[d4_base]
        mov  cx,[d4_rowb]
        xor  dl,dl              ; a column a byte at EGA 640, as K_D4
        call FNT_TO4
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ FNT_TO13   draw the letters into ES again, a byte a pixel (mode 13h, the default)
;  in:  -
;  out: - (fnt_target = 0)
;  needs: -
;  from: new
; ----------------------------------------------------------------------
if used FNT_TO13
FNT_TO13:
        mov  byte [fnt_target],0
        ret
end if

; ---- FNT_P4 (inside): one pixel AL (0..15) into the 4bpp buffer at ES:DI +
;  x BX, DI = its row's first byte; x past [fnt_txmax] (or negative): none
if used FNT_P4
FNT_P4:
        cmp  bx,[fnt_txmax]     ; unsigned: off either side
        ja   .no
        push ax
        push bx
        push cx
        and  al,0Fh
        cmp  byte [fnt_tcol],0
        je   .nib
        mov  ah,11h
        mul  ah                 ; AX = colour * 11h: both nibbles
        mov  [es:di+bx],al      ; EGA 640: the column's byte
        jmp  .x
.nib:   mov  cl,bl              ; CL bit 0: odd x
        shr  bx,1               ; BX = x / 2: the byte
        test cl,1
        jnz  .odd
        mov  cl,4
        shl  al,cl              ; an even x: the high nibble
        and  byte [es:di+bx],0Fh
        jmp  .put
.odd:   and  byte [es:di+bx],0F0h
.put:   or   [es:di+bx],al
.x:     pop  cx
        pop  bx
        pop  ax
.no:    ret
end if

; ---- FNT_ROW4 (inside): DI = the 4bpp buffer's row DX (0..199) first byte
if used FNT_ROW4
FNT_ROW4:
        push ax
        push dx
        mov  ax,dx
        mul  word [fnt_trowb]   ; AX = y * bytes a row (DX lost)
        add  ax,[fnt_tbase]     ; + where the first row is
        mov  di,ax
        pop  dx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ FNT_LOOK   set the whole look at once: AL = FNT_LHUD/LMENU/LTITLE/LSUB/LSCORE/LBODY/LBIG/LFIRE
;  in:  AL = the look's number (an unknown number is ignored)
;  out: fnt_font .. fnt_gtab set (change any of them after, e.g. [fnt_col])
;  needs: -
;  from: new
;       FNT_LHUD   4x6, ringed black, white       - HUD words over the play
;       FNT_LMENU  8x16, shadowed, white          - menus, long text
;       FNT_LTITLE 8x8 x4 smooth proportional, gold ramp, ring 2 + shadow
;       FNT_LSUB   8x8 x2 smooth proportional, white, ringed - subtitles
;       FNT_LSCORE bold digits, yellow, ringed    - the score line
;       FNT_LBODY  8x8, light grey, shadowed      - a line of text
;       FNT_LBIG   4x6 x3 square blocks, yellow, ring+shadow (UBIG)
;       FNT_LFIRE  8x16 x2 smooth proportional, fire ramp, ring+shadow
; ----------------------------------------------------------------------
if used FNT_LOOK
FNT_LOOK:
        push ax
        push cx
        push si
        push di
        push es
        cmp  al,FNT_NLOOK       ; a look we have?
        jae  .x                 ;   no: nothing changes
        mov  ah,14
        mul  ah                 ; AX = look * 14: fourteen bytes a record
        mov  si,fnt_looks
        add  si,ax              ; SI = the record
        push ds
        pop  es                 ; ES:DI = the look's variables
        mov  di,fnt_font
        mov  cx,14
        cld
        rep  movsb
.x:     pop  es
        pop  di
        pop  si
        pop  cx
        pop  ax
        ret
;          font      sc sm pr style      col rc rw shc shd gap gn         gtab
fnt_looks:
        db FNT_F4,   1, 0, 0, FNT_RING,   15, 0, 1, 0,  1,  0,  0
        dw 0
        db FNT_F16,  1, 0, 0, FNT_SHADOW, 15, 0, 1, 0,  1,  0,  0
        dw 0
        db FNT_F8,   4, 1, 1, FNT_RINGSH, 15, 0, 2, 0,  3,  2,  FNT_GOLDN
        dw fnt_gold
        db FNT_F8,   2, 1, 1, FNT_RING,   15, 0, 1, 0,  1,  1,  0
        dw 0
        db FNT_FDIG, 1, 0, 0, FNT_RING,   14, 0, 1, 0,  1,  0,  0
        dw 0
        db FNT_F8,   1, 0, 0, FNT_SHADOW, 7,  0, 1, 0,  1,  0,  0
        dw 0
        db FNT_F4,   3, 0, 0, FNT_RINGSH, 14, 0, 1, 0,  2,  0,  0
        dw 0
        db FNT_F16,  2, 1, 1, FNT_RINGSH, 15, 0, 2, 0,  2,  2,  FNT_FIREN
        dw fnt_fire
FNT_NLOOK = ($-fnt_looks)/14
end if

; ---- inside the kit: the working state ------------------------------------
if used FNT_GLYPH
fnt_gb     db 16 dup(0)         ; the glyph's rows, the left pixel the top bit
fnt_gh     db 8                 ; its rows
fnt_gw     db 8                 ; its pixels across
fnt_cw     db 8                 ; its cell's width (the fixed advance)
fnt_adv    dw 8                 ; pixels to the next letter (scale, gap in)
fnt_ready  db 0                 ; 1: the BIOS fonts asked for
fnt_plo    dd 0                 ; 8x8, characters 0..127
fnt_phi    dd 0                 ; 8x8, characters 128..255 (0: none)
fnt_p16    dd 0                 ; 8x16 (0: none)
end if
if used fnt_geo
;          rows cell width   - per font
fnt_geo    db 5, 4, 3           ; FNT_F4
           db 8, 8, 8           ; FNT_F8
           db 16,8, 8           ; FNT_F16
           db 7, 7, 6           ; FNT_FDIG
end if

; ---- FNT_SC (inside): AX = the scale, held to 1..4 --------------------------
if used FNT_SC
FNT_SC: mov  al,[fnt_scale]
        xor  ah,ah              ; AX = the scale
        or   al,al
        jnz  .lo
        inc  ax                 ; 0 -> 1
.lo:    cmp  ax,4
        jbe  .r
        mov  ax,4               ; above 4 -> 4
.r:     ret
end if

; ---- FNT_INIT (inside): ask the video BIOS where its fonts are ------------
if used FNT_INIT
FNT_INIT:
        push ax
        push bx
        push cx
        push dx
        push bp
        push es
        mov  ax,0F000h
        mov  es,ax
        mov  bp,0FA6Eh          ; ES:BP = where a CGA BIOS keeps 0..127
        mov  ax,1130h
        mov  bh,3               ; BH 3: 8x8, characters 0..127
        int  10h
        mov  word [fnt_plo],bp
        mov  word [fnt_plo+2],es
        xor  bp,bp
        mov  es,bp              ; ES:BP = 0: "none" if the call is not known
        mov  ax,1130h
        mov  bh,4               ; BH 4: 8x8, characters 128..255
        int  10h
        mov  word [fnt_phi],bp
        mov  word [fnt_phi+2],es
        xor  bp,bp
        mov  es,bp
        mov  ax,1130h
        mov  bh,6               ; BH 6: 8x16 (VGA)
        int  10h
        mov  word [fnt_p16],bp
        mov  word [fnt_p16+2],es
        mov  byte [fnt_ready],1
        pop  es
        pop  bp
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ---- FNT_FAR (inside): CX rows from [BX] (a far pointer) + AX into fnt_gb,
;  each row DL times (1, or 2 to double an 8x8 into 8x16). Keeps all.
if used FNT_FAR
FNT_FAR:
        push ax
        push cx
        push si
        push di
        push ds
        push es
        push ds
        pop  es                 ; ES:DI = fnt_gb
        mov  di,fnt_gb
        lds  si,[bx]            ; DS:SI = the font (read before DS moves)
        add  si,ax              ; SI = the glyph
.r:     lodsb                   ; AL = a row
        stosb
        cmp  dl,1
        je   .n
        stosb                   ; the same row again
.n:     loop .r
        pop  es
        pop  ds
        pop  di
        pop  si
        pop  cx
        pop  ax
        ret
end if

; ---- FNT_GLYPH (inside): AL = a character -> fnt_gb (rows), fnt_gh, fnt_gw,
;  fnt_adv; CF = 1 when it has no pixels (a space, or none in this font) -
;  the advance is set either way. Keeps every register.
if used FNT_GLYPH
FNT_GLYPH:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        cmp  byte [fnt_ready],0 ; the BIOS asked yet?
        jne  .rd
        call FNT_INIT
.rd:    mov  bl,[fnt_font]
        cmp  bl,FNT_FDIG
        jbe  .fok
        mov  bl,FNT_F8          ; an unknown font: the 8x8
.fok:   xor  bh,bh
        mov  si,bx
        add  si,si              ; SI = 2f
        add  si,bx              ; SI = 3f: three bytes a font
        mov  ah,[fnt_geo+si]
        mov  [fnt_gh],ah        ; rows
        mov  ah,[fnt_geo+si+1]
        mov  [fnt_cw],ah        ; cell
        mov  ah,[fnt_geo+si+2]
        mov  [fnt_gw],ah        ; width
        mov  di,fnt_gb          ; no picture until one is found
        mov  cx,8
.z:     mov  word [di],0
        add  di,2               ; the next two rows
        loop .z
        cmp  bl,FNT_F8
        je   .f8
        cmp  bl,FNT_F16
        je   .f16
        cmp  bl,FNT_FDIG
        je   .fd
; -- the 4x6 letters
        cmp  al,'a'             ; small letters as capitals
        jb   .up
        cmp  al,'z'
        ja   .up
        sub  al,20h             ; AL = the capital
.up:    sub  al,32              ; AL = the index from the space
        jb   .shape             ; below the space: none
        cmp  al,64
        jae  .shape             ; past '_': none
        xor  ah,ah
        mov  si,ax
        add  si,si              ; SI = 2i
        add  si,si              ; SI = 4i
        add  si,ax              ; SI = 5i: five rows a letter
        add  si,fnt_f4
        mov  di,fnt_gb
        mov  cx,5
.c4:    mov  al,[si]
        mov  [di],al
        inc  si
        inc  di
        loop .c4
        jmp  .shape
; -- the 8x8 letters
.f8:    mov  dl,1               ; each row once
        mov  cx,8
.lo8:   mov  bx,fnt_plo
        cmp  al,128
        jb   .g8
        mov  bx,fnt_phi         ; 128..255
        sub  al,128             ; AL = its place in the upper half
        cmp  word [bx+2],0      ; that half known?
        je   .shape             ;   no: a blank
.g8:    xor  ah,ah
        push cx
        mov  cl,3
        shl  ax,cl              ; AX = char * 8: eight bytes a glyph
        pop  cx
        call FNT_FAR
        jmp  .shape
; -- the 8x16 letters
.f16:   cmp  word [fnt_p16+2],0 ; the VGA font there?
        jne  .h16
        mov  dl,2               ;   no: the 8x8, each row twice
        mov  cx,8
        jmp  .lo8
.h16:   xor  ah,ah
        mov  cl,4
        shl  ax,cl              ; AX = char * 16
        mov  bx,fnt_p16
        mov  cx,16
        mov  dl,1
        call FNT_FAR
        jmp  .shape
; -- the digits
.fd:    cmp  al,'0'
        jb   .fdp
        cmp  al,'9'
        ja   .fdp
        sub  al,'0'             ; AL = 0..9
        jmp  .fdg
.fdp:   mov  si,fnt_fdp         ; the rest this font has
        mov  ah,10              ; AH = the first of them
.fl:    cmp  byte [si],0
        je   .shape             ; not here: a blank
        cmp  al,[si]
        je   .ff
        inc  si
        inc  ah                 ; the next glyph
        jmp  .fl
.ff:    mov  al,ah
.fdg:   xor  ah,ah
        mov  si,ax
        mov  cl,3
        shl  si,cl              ; SI = 8i
        sub  si,ax              ; SI = 7i: seven rows a digit
        add  si,fnt_fd
        mov  di,fnt_gb
        mov  cx,7
.cd:    mov  al,[si]
        mov  [di],al
        inc  si
        inc  di
        loop .cd
; -- its shape: blank? how wide?
.shape: mov  cl,[fnt_gh]
        xor  ch,ch              ; CX = rows
        mov  si,fnt_gb
        xor  ah,ah              ; AH = every row ORed: the columns used
.or:    or   ah,[si]
        inc  si
        loop .or
        call FNT_SC             ; AX = the scale (AH lost: kept below)
        mov  dl,al              ; DL = the scale
        mov  si,fnt_gb          ; (OR again: FNT_SC took AH)
        mov  cl,[fnt_gh]
        xor  ch,ch
        xor  ah,ah
.or2:   or   ah,[si]
        inc  si
        loop .or2
        cmp  byte [fnt_prop],0
        je   .fixed
        or   ah,ah              ; proportional: a blank?
        jz   .half
        xor  cl,cl              ; CL = blank columns on the left
.lead:  test ah,80h
        jnz  .ld
        shl  ah,1               ; one column left
        inc  cl
        jmp  .lead
.ld:    or   cl,cl
        jz   .wd                ; already at the left
        push cx
        mov  si,fnt_gb
        mov  ch,[fnt_gh]
.sh:    shl  byte [si],cl       ; every row CL columns left
        inc  si
        dec  ch
        jnz  .sh
        pop  cx
.wd:    mov  al,8               ; width = 8 - blank columns on the right
.tr:    test ah,1
        jnz  .tw
        shr  ah,1
        dec  al                 ; one column fewer
        jmp  .tr
.tw:    mov  [fnt_gw],al
        inc  al                 ; the letter and one column of gap
        jmp  .adv
.half:  mov  al,[fnt_cw]
        shr  al,1               ; a proportional space: half a cell
        jmp  .adv
.fixed: mov  al,[fnt_cw]
.adv:   mul  dl                 ; AX = columns * scale
        add  al,[fnt_gap]
        adc  ah,0               ; AX += the gap
        mov  [fnt_adv],ax
        clc                     ; CF = 0 unless it is blank
        mov  si,fnt_gb
        mov  cl,[fnt_gh]
        xor  ch,ch
.bl:    cmp  byte [si],0
        jne  .r                 ; a pixel somewhere: drawable
        inc  si
        loop .bl
        stc                     ; nothing: blank
.r:     pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
fnt_fdp db ' -+:.%/',0          ; FNT_FDIG's glyphs 10.. in this order
end if

if used fnt_f4
; OWL FLY III's 4x6 letters (GAMES\OWLFLY3B\SRC\VID.INC VFONT) with the rest
; of ASCII 32..95 MULTSOK2 drew for them: five rows, the high three bits
fnt_f4  db 0,0,0,0,0                                        ; space
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

if used fnt_fd
; FNT_FDIG: bold arcade digits, two-pixel strokes, six wide, seven high
fnt_fd db 01111000b,11001100b,11001100b,11001100b,11001100b,11001100b,01111000b ; 0
        db 00110000b,01110000b,00110000b,00110000b,00110000b,00110000b,01111000b ; 1
        db 01111000b,11001100b,00001100b,00111000b,01100000b,11000000b,11111100b ; 2
        db 01111000b,11001100b,00001100b,00111000b,00001100b,11001100b,01111000b ; 3
        db 00011000b,00111000b,01111000b,11011000b,11111100b,00011000b,00011000b ; 4
        db 11111100b,11000000b,11111000b,00001100b,00001100b,11001100b,01111000b ; 5
        db 00111000b,01100000b,11000000b,11111000b,11001100b,11001100b,01111000b ; 6
        db 11111100b,00001100b,00011000b,00110000b,01100000b,01100000b,01100000b ; 7
        db 01111000b,11001100b,11001100b,01111000b,11001100b,11001100b,01111000b ; 8
        db 01111000b,11001100b,11001100b,01111100b,00001100b,00011000b,01110000b ; 9
        db 0,0,0,0,0,0,0                                                         ; space
        db 0,0,0,01111000b,0,0,0                                                 ; -
        db 0,00110000b,00110000b,11111100b,00110000b,00110000b,0                 ; +
        db 0,00110000b,00110000b,0,00110000b,00110000b,0                         ; :
        db 0,0,0,0,0,00110000b,00110000b                                         ; .
        db 11000100b,11001100b,00011000b,00110000b,01100000b,11001100b,10001100b ; %
        db 00001100b,00001100b,00011000b,00110000b,01100000b,11000000b,11000000b ; /
end if

; ---- the maps (inside): a byte a pixel, 0 empty, 1 letter, 2 ring; each
;  with a margin of two empty pixels all round, a row = width + 4 bytes
if used FNT_MAP
fnt_ma   db 240 dup(0)          ; the glyph itself: (8+4) x (16+4)
fnt_mc   db 720 dup(0)          ; Scale2x's first pass at x4: (16+4) x (32+4)
fnt_mb   db 2448 dup(0)         ; the letter as drawn: (32+4) x (64+4)
fnt_mp   dw 0                   ; the map to draw (fnt_ma at x1, else fnt_mb)
fnt_w    dw 0                   ; its letter's width...
fnt_h    dw 0                   ; ...and height, in pixels
fnt_ss   dw 0                   ; the scalers: the source's row
fnt_sd   dw 0                   ;  the destination's row
fnt_k    dw 0                   ;  the factor
fnt_yc   dw 0                   ;  rows left
fnt_xc   dw 0                   ;  columns left
fnt_pr   dw 0                   ;  the source row's first pixel
fnt_qr   dw 0                   ;  the destination row's first pixel
fnt_n    db 9 dup(0)            ; Scale3x: A B C / D E F / G H I
fnt_o    db 9 dup(0)            ; Scale3x: the nine pixels out
end if

; ---- FNT_MAP (inside): fnt_gb -> the map to draw, fnt_mp/fnt_w/fnt_h -------
if used FNT_MAP
FNT_MAP:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push es
        push ds
        pop  es                 ; ES = ours while the maps are built
        cld
        mov  di,fnt_ma          ; the glyph's map empty
        mov  cx,120
        xor  ax,ax
        rep  stosw
        mov  al,[fnt_gw]
        xor  ah,ah
        mov  bx,ax
        add  bx,4               ; BX = its row: width + 4
        mov  si,fnt_gb
        mov  di,fnt_ma
        add  di,bx
        add  di,bx              ; two margin rows down
        add  di,2               ; and two columns in
        mov  dl,[fnt_gh]        ; DL = rows
.r:     mov  ah,[si]            ; AH = the row's bits
        inc  si
        push di
        mov  cl,[fnt_gw]        ; CL = columns
.c:     shl  ah,1               ; the next pixel into CF
        jnc  .n
        mov  byte [di],1
.n:     inc  di
        dec  cl
        jnz  .c
        pop  di
        add  di,bx              ; the next row
        dec  dl
        jnz  .r
        call FNT_SC             ; AX = the scale
        mov  cx,ax              ; CX = k
        mov  al,[fnt_gw]
        xor  ah,ah
        mov  bx,ax              ; BX = width
        mov  al,[fnt_gh]
        mov  dx,ax              ; DX = height
        mov  si,fnt_ma
        cmp  cx,1
        jne  .big
        mov  [fnt_mp],si        ; x1: the glyph's map as it is
        mov  [fnt_w],bx
        mov  [fnt_h],dx
        jmp  .x
.big:   mov  di,fnt_mb
        mov  [fnt_mp],di
        push bx
        push dx
        cmp  byte [fnt_smooth],0
        je   .blk
        cmp  cx,3
        je   .s3
        cmp  cx,4
        je   .s4
        mov  cx,bx              ; x2: Scale2x
        call FNT_EPX
        jmp  .sz
.s3:    mov  cx,bx              ; x3: Scale3x
        call FNT_S3X
        jmp  .sz
.s4:    mov  di,fnt_mc          ; x4: Scale2x twice
        mov  cx,bx
        call FNT_EPX
        mov  si,fnt_mc
        mov  di,fnt_mb
        add  cx,cx              ; twice as wide
        add  dx,dx              ; twice as high
        call FNT_EPX
        jmp  .sz
.blk:   mov  ax,cx              ; AX = k
        mov  cx,bx
        call FNT_BLK            ; square blocks
.sz:    pop  dx
        pop  bx
        call FNT_SC             ; AX = k
        push ax
        mul  bx                 ; AX = width * k (DX lost)
        mov  [fnt_w],ax
        pop  ax
        mov  cl,[fnt_gh]
        xor  ch,ch
        mul  cx                 ; AX = height * k
        mov  [fnt_h],ax
.x:     pop  es
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ---- FNT_SCL0 (inside): SI = source map, DI = destination, CX = the
;  source's width, DX = its height, AX = k: zero the destination, set the
;  rows and the first pixels. ES = DS. Keeps all but the fnt_ variables.
if used FNT_SCL0
FNT_SCL0:
        push ax
        push bx
        push cx
        push dx
        push di
        mov  [fnt_k],ax
        mov  [fnt_yc],dx
        mov  [fnt_xc],cx
        mov  bx,cx
        add  bx,4
        mov  [fnt_ss],bx        ; the source's row: width + 4
        mul  cx                 ; AX = width * k (DX lost)
        add  ax,4
        mov  [fnt_sd],ax        ; the destination's row: width*k + 4
        mov  bx,ax
        mov  ax,[fnt_yc]
        mul  word [fnt_k]       ; AX = height * k
        add  ax,4               ; + the margins
        mul  bx                 ; AX = the destination's bytes
        mov  cx,ax
        xor  al,al
        cld
        rep  stosb              ; the destination empty
        pop  di
        mov  ax,[fnt_ss]
        add  ax,ax              ; two rows of margin
        add  ax,2               ;  and two columns
        add  ax,si
        mov  [fnt_pr],ax        ; the source's first pixel
        mov  ax,[fnt_sd]
        add  ax,ax
        add  ax,2
        add  ax,di
        mov  [fnt_qr],ax        ; the destination's first pixel
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ---- FNT_BLK (inside): square blocks, k x k a pixel (OWL FLY's UBIG) -------
if used FNT_BLK
FNT_BLK:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        call FNT_SCL0
.y:     mov  si,[fnt_pr]
        mov  di,[fnt_qr]
        mov  ax,[fnt_xc]
        push ax
.x:     cmp  byte [si],0
        je   .n
        push di
        mov  dx,[fnt_k]         ; DX = rows of the block
.br:    mov  cx,[fnt_k]
        push di
.bc:    mov  byte [di],1
        inc  di
        loop .bc
        pop  di
        add  di,[fnt_sd]        ; the block's next row
        dec  dx
        jnz  .br
        pop  di
.n:     inc  si
        add  di,[fnt_k]         ; the next block across
        pop  ax
        dec  ax
        push ax
        jnz  .x
        pop  ax
        mov  ax,[fnt_ss]
        add  [fnt_pr],ax        ; the next source row
        mov  ax,[fnt_sd]
        mul  word [fnt_k]       ; AX = k destination rows
        add  [fnt_qr],ax
        dec  word [fnt_yc]
        jnz  .y
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ---- FNT_EPX (inside): Scale2x - each pixel E becomes four; a corner takes
;  its two neighbours' value when they agree and the other two differ:
;      B           E0 = D==B && B!=H && D!=F ? D : E      E0 E1
;    D E F         E1 = B==F && ...          ? F : E      E2 E3
;      H           E2 = D==H, E3 = H==F the same way
;  SI = source, DI = destination, CX = width, DX = height. ES = DS.
if used FNT_EPX
FNT_EPX:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        mov  ax,2
        call FNT_SCL0
        mov  bx,[fnt_ss]        ; BX = the source's row
        mov  bp,[fnt_sd]        ; BP = the destination's row (SS = DS)
.y:     mov  si,[fnt_pr]
        mov  di,[fnt_qr]
        mov  ax,[fnt_xc]
        mov  [fnt_k],ax         ; (k is 2 here: the slot counts columns)
.x:     mov  al,[si]            ; AL = E
        push si
        sub  si,bx
        mov  ah,[si]            ; AH = B, above
        pop  si
        mov  cl,[si+bx]         ; CL = H, below
        mov  dl,[si-1]          ; DL = D, left
        mov  dh,[si+1]          ; DH = F, right
        mov  ch,al              ; the four corners default to E
        mov  [di],al
        mov  [di+1],al
        mov  [bp+di],al
        mov  [bp+di+1],al
        cmp  ah,cl              ; B == H: no corner moves
        je   .n
        cmp  dl,dh              ; D == F: no corner moves
        je   .n
        cmp  dl,ah              ; E0: D == B?
        jne  .e1
        mov  [di],dl
.e1:    cmp  ah,dh              ; E1: B == F?
        jne  .e2
        mov  [di+1],dh
.e2:    cmp  dl,cl              ; E2: D == H?
        jne  .e3
        mov  [bp+di],dl
.e3:    cmp  cl,dh              ; E3: H == F?
        jne  .n
        mov  [bp+di+1],dh
.n:     inc  si
        add  di,2               ; two pixels on
        dec  word [fnt_k]
        jnz  .x
        add  [fnt_pr],bx        ; the next source row
        mov  ax,bp
        add  ax,ax              ; two destination rows
        add  [fnt_qr],ax
        dec  word [fnt_yc]
        jnz  .y
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ---- FNT_S3X (inside): Scale3x - each pixel E becomes nine:
;      A B C     if B!=H && D!=F:   E0 = D==B ? D : E
;      D E F       E1 = (D==B && E!=C) || (B==F && E!=A) ? B : E
;      G H I       E2 = B==F ? F : E
;                  E3 = (D==B && E!=G) || (D==H && E!=A) ? D : E    E4 = E
;                  E5 = (B==F && E!=I) || (H==F && E!=C) ? F : E
;                  E6 = D==H ? D : E
;                  E7 = (D==H && E!=I) || (H==F && E!=G) ? H : E
;                  E8 = H==F ? F : E
;  SI = source, DI = destination, CX = width, DX = height. ES = DS.
if used FNT_S3X
FNT_S3X:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        mov  ax,3
        call FNT_SCL0
        mov  bx,[fnt_ss]        ; BX = the source's row
        mov  bp,[fnt_sd]        ; BP = the destination's row
.y:     mov  si,[fnt_pr]
        mov  di,[fnt_qr]
        mov  ax,[fnt_xc]
        mov  [fnt_k],ax         ; columns left
.x:     push si                 ; ---- the nine around E into fnt_n
        sub  si,bx              ; the row above
        mov  al,[si-1]
        mov  [fnt_n],al         ; A
        mov  al,[si]
        mov  [fnt_n+1],al       ; B
        mov  al,[si+1]
        mov  [fnt_n+2],al       ; C
        add  si,bx              ; this row
        mov  al,[si-1]
        mov  [fnt_n+3],al       ; D
        mov  al,[si]
        mov  [fnt_n+4],al       ; E
        mov  al,[si+1]
        mov  [fnt_n+5],al       ; F
        add  si,bx              ; the row below
        mov  al,[si-1]
        mov  [fnt_n+6],al       ; G
        mov  al,[si]
        mov  [fnt_n+7],al       ; H
        mov  al,[si+1]
        mov  [fnt_n+8],al       ; I
        pop  si
        mov  al,[fnt_n+4]       ; AL = E
        push di                 ; ---- all nine E to start
        push es
        push ds
        pop  es
        mov  di,fnt_o
        mov  cx,9
        rep  stosb
        pop  es
        pop  di
        mov  ah,[fnt_n+1]       ; B
        cmp  ah,[fnt_n+7]       ; B == H: nothing moves
        je   .put
        mov  ah,[fnt_n+3]       ; D
        cmp  ah,[fnt_n+5]       ; D == F: nothing moves
        je   .put
        xor  dx,dx              ; DL: equal pairs, DH: E differs from a corner
        mov  ah,[fnt_n+3]
        cmp  ah,[fnt_n+1]
        jne  .q1
        or   dl,1               ; bit 0: D == B
.q1:    mov  ah,[fnt_n+1]
        cmp  ah,[fnt_n+5]
        jne  .q2
        or   dl,2               ; bit 1: B == F
.q2:    mov  ah,[fnt_n+3]
        cmp  ah,[fnt_n+7]
        jne  .q3
        or   dl,4               ; bit 2: D == H
.q3:    mov  ah,[fnt_n+7]
        cmp  ah,[fnt_n+5]
        jne  .q4
        or   dl,8               ; bit 3: H == F
.q4:    cmp  al,[fnt_n+2]
        je   .q5
        or   dh,1               ; bit 0: E != C
.q5:    cmp  al,[fnt_n]
        je   .q6
        or   dh,2               ; bit 1: E != A
.q6:    cmp  al,[fnt_n+6]
        je   .q7
        or   dh,4               ; bit 2: E != G
.q7:    cmp  al,[fnt_n+8]
        je   .q8
        or   dh,8               ; bit 3: E != I
.q8:    test dl,1               ; E0 = D==B ? D
        jz   .o1
        mov  ah,[fnt_n+3]
        mov  [fnt_o],ah
.o1:    test dl,1               ; E1 = (D==B && E!=C) || (B==F && E!=A) ? B
        jz   .o1b
        test dh,1
        jnz  .o1y
.o1b:   test dl,2
        jz   .o2
        test dh,2
        jz   .o2
.o1y:   mov  ah,[fnt_n+1]
        mov  [fnt_o+1],ah
.o2:    test dl,2               ; E2 = B==F ? F
        jz   .o3
        mov  ah,[fnt_n+5]
        mov  [fnt_o+2],ah
.o3:    test dl,1               ; E3 = (D==B && E!=G) || (D==H && E!=A) ? D
        jz   .o3b
        test dh,4
        jnz  .o3y
.o3b:   test dl,4
        jz   .o5
        test dh,2
        jz   .o5
.o3y:   mov  ah,[fnt_n+3]
        mov  [fnt_o+3],ah
.o5:    test dl,2               ; E5 = (B==F && E!=I) || (H==F && E!=C) ? F
        jz   .o5b
        test dh,8
        jnz  .o5y
.o5b:   test dl,8
        jz   .o6
        test dh,1
        jz   .o6
.o5y:   mov  ah,[fnt_n+5]
        mov  [fnt_o+5],ah
.o6:    test dl,4               ; E6 = D==H ? D
        jz   .o7
        mov  ah,[fnt_n+3]
        mov  [fnt_o+6],ah
.o7:    test dl,4               ; E7 = (D==H && E!=I) || (H==F && E!=G) ? H
        jz   .o7b
        test dh,8
        jnz  .o7y
.o7b:   test dl,8
        jz   .o8
        test dh,4
        jz   .o8
.o7y:   mov  ah,[fnt_n+7]
        mov  [fnt_o+7],ah
.o8:    test dl,8               ; E8 = H==F ? F
        jz   .put
        mov  ah,[fnt_n+5]
        mov  [fnt_o+8],ah
.put:   push si                 ; ---- the nine out, three rows of three
        push di
        mov  si,fnt_o
        mov  dx,3
.pr:    mov  al,[si]
        mov  [di],al
        mov  al,[si+1]
        mov  [di+1],al
        mov  al,[si+2]
        mov  [di+2],al
        add  si,3
        add  di,bp              ; the next destination row
        dec  dx
        jnz  .pr
        pop  di
        pop  si
        inc  si
        add  di,3               ; three pixels on
        dec  word [fnt_k]
        jz   .ny
        jmp  .x
.ny:    add  [fnt_pr],bx        ; the next source row
        mov  ax,bp
        add  ax,ax
        add  ax,bp              ; three destination rows
        add  [fnt_qr],ax
        dec  word [fnt_yc]
        jz   .done
        jmp  .y
.done:  pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ---- FNT_RINGM (inside): the ring into the map - every empty pixel within
;  [fnt_rw] (1 or 2) of a letter pixel becomes 2. Lesson 1A's "grow the
;  letter, carve the letter out", on a byte map instead of bits.
if used FNT_RINGM
FNT_RINGM:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        mov  bx,[fnt_w]
        add  bx,4               ; BX = the map's row
        mov  si,fnt_r1          ; the eight neighbours...
        mov  cx,8
        cmp  byte [fnt_rw],2
        jb   .tb
        mov  si,fnt_r2          ; ...or the twenty of a round 5x5
        mov  cx,20
.tb:    mov  di,fnt_off         ; the offsets for this row length
        push cx
.mk:    mov  al,[si+1]
        cbw                     ; AX = dy
        imul bx                 ; AX = dy * row (DX lost)
        push ax
        mov  al,[si]
        cbw                     ; AX = dx
        pop  dx
        add  ax,dx              ; AX = dy * row + dx
        mov  [di],ax
        add  si,2
        add  di,2
        loop .mk
        pop  bp                 ; BP = how many
        mov  si,[fnt_mp]
        add  si,bx
        add  si,bx
        add  si,2               ; SI = the letter's first pixel
        mov  dx,[fnt_h]         ; DX = rows
.y:     mov  cx,[fnt_w]         ; CX = columns
        push si
.x:     cmp  byte [si],1        ; a letter pixel?
        jne  .n
        push bx
        push cx
        mov  cx,bp
        mov  di,fnt_off
.o:     mov  bx,[di]            ; BX = to the neighbour
        cmp  byte [si+bx],0     ; empty?
        jne  .on
        mov  byte [si+bx],2     ;   yes: ring
.on:    add  di,2
        loop .o
        pop  cx
        pop  bx
.n:     inc  si
        loop .x
        pop  si
        add  si,bx              ; the next row
        dec  dx
        jnz  .y
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
fnt_r1  db -1,-1, 0,-1, 1,-1, -1,0, 1,0, -1,1, 0,1, 1,1
fnt_r2  db -1,-1, 0,-1, 1,-1, -1,0, 1,0, -1,1, 0,1, 1,1
        db -1,-2, 0,-2, 1,-2, -1,2, 0,2, 1,2, -2,-1, -2,0, -2,1, 2,-1, 2,0, 2,1
fnt_off dw 20 dup(0)
end if

; ---- FNT_BLIT (inside): the map onto ES with its letter's top-left at
;  (BX,DX). AL = 0: everything not empty in [fnt_shc] (the shadow; the
;  caller moves BX/DX by the offset); AL = 1: ring in [fnt_rc], letter in
;  [fnt_col] or the gradient. Every pixel clipped. Keeps all.
if used FNT_BLIT
FNT_BLIT:
if used FNT_TO4 | used FNT_OND4
        cmp  byte [fnt_target],0 ; the 4bpp buffer? (only assembled when
        je   .b13               ;  the program can choose it)
        jmp  FNT_BLIT4
.b13:
end if
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        mov  [fnt_bm],al
        sub  bx,2               ; the map's margin
        sub  dx,2
        mov  [fnt_bx],bx
        mov  si,[fnt_mp]        ; SI = the map's first byte
        mov  ax,[fnt_h]
        add  ax,4
        mov  [fnt_by],ax        ; rows of the map
        mov  bp,[fnt_w]
        add  bp,4               ; BP = columns of the map
        xor  cx,cx              ; CX = the map row, 0..
.y:     cmp  dx,199             ; this row on the screen? (unsigned: a
        ja   .skip              ;  negative y is huge too)
        mov  di,dx
        mov  ax,dx
        push cx
        mov  cl,8
        shl  di,cl              ; DI = y * 256
        mov  cl,6
        shl  ax,cl              ; AX = y * 64
        pop  cx
        add  di,ax              ; DI = y * 320
        mov  al,[fnt_col]       ; the ink of this row
        cmp  byte [fnt_gn],0
        je   .ink
        mov  ax,cx
        sub  ax,2               ; AX = the row in the letter
        jns  .g1
        xor  ax,ax              ; above it: the first colour
.g1:    cmp  ax,[fnt_h]
        jb   .g2
        mov  ax,[fnt_h]
        dec  ax                 ; below it: the last
.g2:    push dx
        mul  byte [fnt_gn]      ; AX = row * colours  (byte multiply)
        xor  dx,dx
        div  word [fnt_h]       ; AX = row * colours / height (height >= 5)
        mov  bx,[fnt_gtab]
        add  bx,ax
        mov  al,[bx]            ; AL = this row's colour
        pop  dx
.ink:   mov  [fnt_bi],al
        mov  bx,[fnt_bx]        ; BX = x
        push si
        push cx
        mov  cx,bp
.x:     mov  al,[si]
        or   al,al
        jz   .n                 ; empty
        cmp  bx,319
        ja   .n                 ; off the screen
        cmp  byte [fnt_bm],0
        jne  .main
        mov  al,[fnt_shc]       ; the shadow: one colour
        jmp  .put
.main:  cmp  al,1
        mov  al,[fnt_bi]        ; the letter
        je   .put
        mov  al,[fnt_rc]        ; the ring
.put:   push di
        add  di,bx
        mov  [es:di],al
        pop  di
.n:     inc  si
        inc  bx                 ; x++
        loop .x
        pop  cx
        pop  si
.skip:  add  si,bp              ; the next map row
        inc  dx                 ; y++
        inc  cx
        cmp  cx,[fnt_by]
        jb   .y
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
fnt_bm  db 0                    ; 0 shadow, 1 ring and letter
fnt_bi  db 0                    ; this row's ink
fnt_bx  dw 0                    ; the map's left on the screen
fnt_by  dw 0                    ; the map's rows
end if

; ---- FNT_BLIT4 (inside): FNT_BLIT into the 4bpp buffer, the same contract;
;  the 256-colour ramps the looks name are swapped for their 16-colour twins
if used FNT_BLIT4
FNT_BLIT4:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        push es
        mov  [fnt_bm],al
        sub  bx,2               ; the map's margin
        sub  dx,2
        mov  [fnt_bx],bx
        mov  si,[fnt_mp]        ; SI = the map's first byte
        mov  ax,[fnt_h]
        add  ax,4
        mov  [fnt_by],ax        ; rows of the map
        mov  bp,[fnt_w]
        add  bp,4               ; BP = columns of the map
        mov  es,[fnt_tseg]      ; ES = the 4bpp buffer
        mov  ax,[fnt_gtab]      ; the ramp, in 16 colours
        cmp  ax,fnt_gold
        jne  .g0
        mov  ax,fnt_gold4
.g0:    cmp  ax,fnt_fire
        jne  .g9
        mov  ax,fnt_fire4
.g9:    mov  [fnt_g4],ax
        xor  cx,cx              ; CX = the map row, 0..
.y:     cmp  dx,199             ; this row in the buffer? (unsigned)
        ja   .skip
        call FNT_ROW4           ; DI = the row's first byte
        mov  al,[fnt_col]       ; the ink of this row
        cmp  byte [fnt_gn],0
        je   .ink
        mov  ax,cx
        sub  ax,2               ; AX = the row in the letter
        jns  .r1
        xor  ax,ax              ; above it: the first colour
.r1:    cmp  ax,[fnt_h]
        jb   .r2
        mov  ax,[fnt_h]
        dec  ax                 ; below it: the last
.r2:    push dx
        mul  byte [fnt_gn]      ; AX = row * colours  (byte multiply)
        xor  dx,dx
        div  word [fnt_h]       ; AX = row * colours / height (height >= 5)
        mov  bx,[fnt_g4]
        add  bx,ax
        mov  al,[bx]            ; AL = this row's colour
        pop  dx
.ink:   mov  [fnt_bi],al
        mov  bx,[fnt_bx]        ; BX = x
        push si
        push cx
        mov  cx,bp
.x:     mov  al,[si]
        or   al,al
        jz   .n                 ; empty
        cmp  byte [fnt_bm],0
        jne  .main
        mov  al,[fnt_shc]       ; the shadow: one colour
        jmp  .put
.main:  cmp  al,1
        mov  al,[fnt_bi]        ; the letter
        je   .put
        mov  al,[fnt_rc]        ; the ring
.put:   call FNT_P4             ; clipped there
.n:     inc  si
        inc  bx                 ; x++
        loop .x
        pop  cx
        pop  si
.skip:  add  si,bp              ; the next map row
        inc  dx                 ; y++
        inc  cx
        cmp  cx,[fnt_by]
        jb   .y
        pop  es
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
fnt_g4  dw 0                    ; the ramp in use
end if

; ----------------------------------------------------------------------
;@ FNT_CHAR   one letter AL at (BX,DX) in the current font, size and style
;  in:  AL = the character, BX = x, DX = y (the letter's top-left, may be
;       off the screen), ES = where to draw; the look in fnt_font..fnt_gtab
;  out: BX = x of the next letter
;  needs: -
;  from: new - the ring is LESSONS\L26\LETTERS.ASM:2072-2160 TXT46O's
;        dilated mask (grow, carve the letter out) on a byte map; x2/x3 are
;        Scale2x/Scale3x; square blocks are GAMES\OWLFLY3\SRC\UI.INC:274
;        UBIG; the shadow is GAMES\MULTSOK2\DRAW.INC:602 PUTC4's
; ----------------------------------------------------------------------
if used FNT_CHAR
FNT_CHAR:
        push ax
        call FNT_GLYPH          ; its rows, its advance
        jc   .adv               ; blank: just move on
        call FNT_MAP            ; the letter, scaled, as a byte map
        test byte [fnt_style],FNT_RING
        jz   .nr
        call FNT_RINGM          ; the ring into the map
.nr:    test byte [fnt_style],FNT_SHADOW
        jz   .main
        push bx
        push dx
        mov  al,[fnt_shd]
        xor  ah,ah
        add  bx,ax              ; the shadow down and right
        add  dx,ax
        xor  al,al
        call FNT_BLIT           ; the shadow first
        pop  dx
        pop  bx
.main:  mov  al,1
        call FNT_BLIT           ; ring and letter over it
.adv:   add  bx,[fnt_adv]       ; x on to the next letter
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ FNT_PUT    zero-ended string SI at (BX,DX) in the current font and look
;  in:  SI = the string, BX = x, DX = y (top-left), ES = where to draw
;  out: BX = x past the last letter (a number can follow at once)
;  needs: -
;  from: new (GAMES\MULTSOK2\DRAW.INC PRINT8's loop)
; ----------------------------------------------------------------------
if used FNT_PUT
FNT_PUT:
        push ax
        push si
.l:     mov  al,[si]
        inc  si
        or   al,al              ; the end?
        jz   .e
        call FNT_CHAR
        jmp  .l
.e:     pop  si
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ FNT_WIDTH  CX = the width in pixels string SI takes in the current font and look
;  in:  SI = the string; fnt_font, fnt_scale, fnt_prop, fnt_gap
;  out: CX = from the first letter's left to the last letter's right (the
;       ring and the shadow are outside it); 0 for an empty string
;  needs: -
;  from: new
; ----------------------------------------------------------------------
if used FNT_WIDTH
FNT_WIDTH:
        push ax
        push si
        xor  cx,cx              ; CX = the advances so far
.l:     mov  al,[si]
        inc  si
        or   al,al
        jz   .e
        call FNT_GLYPH          ; fnt_adv = this letter's
        add  cx,[fnt_adv]
        jmp  .l
.e:     jcxz .r                 ; nothing: 0
        call FNT_SC             ; AX = the scale
        add  al,[fnt_gap]
        adc  ah,0               ; AX = the last letter's gap column and gap
        sub  cx,ax              ; not part of the width
.r:     pop  si
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ FNT_HEIGHT CX = the height in pixels of the current font at its scale
;  in:  fnt_font, fnt_scale
;  out: CX = rows * scale (4x6: 5, 8x8: 8, 8x16: 16, digits: 7, times scale)
;  needs: -
;  from: new
; ----------------------------------------------------------------------
if used FNT_HEIGHT
FNT_HEIGHT:
        push ax
        push si
        call FNT_SC             ; AX = the scale
        mov  cx,ax
        mov  al,[fnt_font]
        cmp  al,FNT_FDIG
        jbe  .f
        mov  al,FNT_F8
.f:     xor  ah,ah
        mov  si,ax
        add  si,si
        add  si,ax              ; SI = 3f
        mov  al,[fnt_geo+si]    ; AL = rows
        mul  cl                 ; AX = rows * scale
        mov  cx,ax
        pop  si
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ FNT_CENTER string SI centred on x BX, its top at y DX (current font and look)
;  in:  SI = the string, BX = the centre's x, DX = y, ES = where to draw
;  out: BX = x past the last letter
;  needs: -
;  from: new
; ----------------------------------------------------------------------
if used FNT_CENTER
FNT_CENTER:
        push cx
        call FNT_WIDTH          ; CX = the width
        shr  cx,1               ; half of it
        sub  bx,cx              ; the left
        call FNT_PUT
        pop  cx
        ret
end if

; ----------------------------------------------------------------------
;@ FNT_RIGHT  string SI ending at x BX (right-aligned), top at y DX
;  in:  SI = the string, BX = the right edge's x, DX = y, ES = where to draw
;  out: BX = x past the last letter
;  needs: -
;  from: new
; ----------------------------------------------------------------------
if used FNT_RIGHT
FNT_RIGHT:
        push cx
        call FNT_WIDTH          ; CX = the width
        sub  bx,cx              ; the left
        inc  bx                 ; the last column lands ON BX
        call FNT_PUT
        pop  cx
        ret
end if

; ----------------------------------------------------------------------
;@ FNT_NUM    AX unsigned in decimal at (BX,DX) in the current font and look
;  in:  AX = the number, BX = x, DX = y, ES = where to draw
;  out: BX = x past the last digit
;  needs: -
;  from: new
; ----------------------------------------------------------------------
if used FNT_NUM
FNT_NUM:
        push cx
        mov  cl,1
        call FNT_NUMZ
        pop  cx
        ret
end if

; ----------------------------------------------------------------------
;@ FNT_NUMZ   AX unsigned, zero-padded to CL digits (a score: 00120), at (BX,DX)
;  in:  AX = the number, CL = at least this many digits (1..5), BX = x, DX = y
;  out: BX = x past the last digit; [fnt_nb] holds the digits, zero-ended
;  needs: -
;  from: new
; ----------------------------------------------------------------------
if used FNT_NUMZ
FNT_NUMZ:
        push ax
        push cx
        push dx
        push si
        push di
        mov  [fnt_ny],dx        ; y, for after the divides
        mov  di,fnt_nb+5        ; just past the last digit
        mov  byte [di],0
        mov  si,10              ; SI = the base (not 0)
        xor  ch,ch              ; CH = digits so far
.d:     xor  dx,dx
        div  si                 ; AX = n / 10, DX = the last digit
        add  dl,'0'
        dec  di
        mov  [di],dl
        inc  ch
        or   ax,ax
        jnz  .d
.p:     cmp  ch,cl              ; padded enough?
        jae  .o
        cmp  di,fnt_nb
        jbe  .o                 ; five digits is all there is room for
        dec  di
        mov  byte [di],'0'
        inc  ch
        jmp  .p
.o:     mov  si,di              ; SI = the first digit
        mov  dx,[fnt_ny]        ; DX = y again
        call FNT_PUT
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  ax
        ret
fnt_nb  db 6 dup(0)
fnt_ny  dw 0
end if

; ----------------------------------------------------------------------
;@ FNT_HUD    fast: string SI in the 4x6 letters ringed, at (BX,DX) - for every frame
;  in:  SI = the string, BX = x, DX = y (the letters' top-left), ES = where
;       to draw; [fnt_col] the ink, [fnt_rc] the ring
;  out: BX = x past the last letter (4 pixels a letter)
;  needs: -
;  from: LESSONS\L26\LETTERS.ASM:2110-2165 TXT46O (the ring of bit masks:
;        o = up|here|down, o |= o<<1 | o>>1, o &= ~here), clipped here;
;        the letters are ASCII 32..95 (MULTSOK2's FONT4)
; ----------------------------------------------------------------------
if used FNT_HUD
FNT_HUD:
        push ax
        push cx
        push dx
        push si
        push di
        push bp
.ch:    mov  al,[si]
        inc  si
        or   al,al              ; the end?
        jz   .done
        cmp  al,'a'             ; small letters as capitals
        jb   .up
        cmp  al,'z'
        ja   .up
        sub  al,20h
.up:    sub  al,32
        jb   .adv               ; nothing below the space
        cmp  al,64
        jae  .adv               ; nor past '_'
        push si
        xor  ah,ah
        mov  si,ax
        add  si,si              ; 2i
        add  si,si              ; 4i
        add  si,ax              ; 5i
        add  si,fnt_f4          ; SI = its five rows
        mov  word [fnt_hq],0    ; q[0], q[1] = 0: two empty rows on top
        mov  word [fnt_hq+7],0  ; q[7], q[8] = 0: and two below
        mov  di,fnt_hq+2
        mov  cx,5
.cp:    mov  al,[si]
        inc  si
        shr  al,1               ; a column for the ring on the left
        mov  [di],al
        inc  di
        loop .cp
        pop  si
        push dx
        dec  dx                 ; y - 1: the ring's row above
        xor  di,di              ; DI = row 0..6
.row:   mov  al,[fnt_hq+di]     ; up
        or   al,[fnt_hq+di+1]   ; | here
        or   al,[fnt_hq+di+2]   ; | down: one row taller
        mov  ah,al
        shl  ah,1               ; o << 1
        or   ah,al
        shr  al,1               ; o >> 1
        or   ah,al              ; AH = one pixel wider too
        mov  al,[fnt_hq+di+1]   ; AL = here
        mov  cl,al
        not  cl
        and  ah,cl              ; AH = the ring: grown, the letter carved out
        cmp  dx,199
        ja   .nrow              ; this row off the screen
if used FNT_TO4 | used FNT_OND4
        cmp  byte [fnt_target],0
        je   .r13
        call .row4              ; the 4bpp buffer
        jmp  .nrow
.r13:
end if
        push di
        push bx
        mov  di,dx
        mov  bp,dx
        mov  cl,8
        shl  di,cl              ; DI = y * 256
        mov  cl,6
        shl  bp,cl              ; BP = y * 64
        add  di,bp              ; DI = y * 320
        dec  bx                 ; x - 1: the ring's column on the left
        mov  ch,5               ; five columns: ring, three, ring
.px:    cmp  bx,319
        ja   .nx                ; off the screen
        shl  ah,1               ; a ring pixel?
        jnc  .nr
        mov  cl,[fnt_rc]
        mov  [es:di+bx],cl
.nr:    shl  al,1               ; a letter pixel?
        jnc  .nl
        mov  cl,[fnt_col]
        mov  [es:di+bx],cl
        jmp  .nl
.nx:    shl  ah,1               ; off the screen: just shift both
        shl  al,1
.nl:    inc  bx
        dec  ch
        jnz  .px
        pop  bx
        pop  di
.nrow:  inc  dx                 ; y++
        inc  di                 ; the next row
        cmp  di,7               ; seven rows: ring, five, ring
        jb   .row
        pop  dx
.adv:   add  bx,4               ; four pixels a letter
        jmp  .ch
.done:  pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  ax
        ret
if used FNT_TO4 | used FNT_OND4
; .row4: one row of five columns into the 4bpp buffer: AH = the ring's
; bits, AL = the letter's (high bit the left), BX = x, DX = y. AX lost.
.row4:  push bx
        push cx
        push di
        push es
        mov  es,[fnt_tseg]
        call FNT_ROW4           ; DI = the row's first byte
        dec  bx                 ; x - 1: the ring's column on the left
        mov  cx,ax              ; CH = ring, CL = letter
        mov  ah,5               ; five columns: ring, three, ring
.p4:    shl  ch,1               ; a ring pixel?
        jnc  .q4
        mov  al,[fnt_rc]
        call FNT_P4             ; clipped there
.q4:    shl  cl,1               ; a letter pixel?
        jnc  .w4
        mov  al,[fnt_col]
        call FNT_P4
.w4:    inc  bx
        dec  ah
        jnz  .p4
        pop  es
        pop  di
        pop  cx
        pop  bx
        ret
end if
fnt_hq  db 9 dup(0)             ; the rows with the ring's room above and below
end if
