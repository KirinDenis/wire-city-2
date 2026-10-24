; ============================================================================
;  K_D4.INC - KIT: drawing into a FOUR-BITS-A-PIXEL back buffer, the one
;  K_CARD.INC sends to EGA, CGA, Hercules or mode 13h. Two pixels a byte,
;  the left in the high nibble: 160 bytes a row at 320x200. EGA 640 ("wide",
;  [d4_wide] = 1): 320 bytes a row, 640 fine pixels - the game still counts
;  320 columns, every column a BYTE (both nibbles the colour), so pictures
;  are compiled twice as wide and D4_PSETF reaches the fine pixels.
;
;        mov  ax,[crd_buf]       ; the buffer (K_CARD's CRD_MEM, or your own)
;        mov  bl,[crd_wide]      ; 0: 160 bytes a row, 1: EGA 640's 320
;        call D4_INIT            ; row table, dim table, the BIOS 8x8 font
;        ...D4_ROWS, D4_FILL, D4_PSET, D4_SPR, D4_PRINT4, D4_PRINT8...
;  Where it draws: segment [d4_seg], from offset [d4_base] (D4_INIT sets
;  them; point them at a background buffer of the same layout to draw
;  that, then D4_COPYBG it into the frame each turn). Rows outside
;  [d4_clipt]..[d4_clipb]-1 are not drawn by D4_SPR.
;  Colours 0..15: KIT\ART\PALETTE.TXT's meanings (and K_CARD's crd_pal).
;  Pictures: text art - db width, height, then the rows, a character a
;  pixel: '0'..'9' 'A'..'F' a colour, '.' see-through, 'S' 's' 'P' 'p' the
;  four colours in [d4_look] (a man's shirt, its shade, trousers, theirs).
;  Width even; drawn at even x. D4_COMP turns one into masks and inks.
; ============================================================================

if used d4_seg
d4_seg    dw 0                  ; the buffer drawn into
d4_base   dw 0                  ;  ...from this offset in it
d4_wide   db 0                  ; 1: EGA 640, a column a byte
d4_rowb   dw 160                ; bytes a row: 160 or 320
d4_clipt  dw 0                  ; D4_SPR draws rows clipt..clipb-1
d4_clipb  dw 200
d4_look   db 12,4,1,0           ; 'S' 's' 'P' 'p': red shirt, blue trousers
d4_tx     dw 0                  ; text: the next letter's top left,
d4_ty     dw 0
d4_tclr   db 15                 ;  its colour,
d4_tshad  db 0                  ;  1: a black shadow 1 down and right first,
d4_tscale db 1                  ;  D4_PRINT8: 1 or 2 times as big
d4_font   dd 0F000FA6Eh         ; the 8x8 font (D4_INIT asks the BIOS)
d4_glyph  rb 8
d4_nbuf   rb 8
d4_rowtab rw 200                ; y * [d4_rowb]
d4_dimtab rb 256                ; a byte's two pixels a step darker
; d4_dim16 - each colour one step darker (PALETTE.TXT's PALDIM)
d4_dim16  db 0,0,0,1,0,1,4,8,0,1,2,3,4,5,6,7
end if

; ----------------------------------------------------------------------
;@ D4_INIT    point the 4bpp drawing at a buffer; row, dim and font tables
;  in:  AX = the buffer's segment (drawn from offset 0); BL = 0 narrow
;       (160 bytes a row), 1 EGA 640 (320)
;  out: - ([d4_seg], [d4_base] = 0, [d4_wide], [d4_rowb], [d4_font])
;  needs: -
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:622-673 LAYOUT (rowtab), 678-707 PREP
;        (dimtab, the font through INT 10h 1130h)
; ----------------------------------------------------------------------
if used D4_INIT
D4_INIT:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        push es
        mov  [d4_seg],ax
        mov  word [d4_base],0
        mov  [d4_wide],bl
        mov  ax,160
        or   bl,bl
        jz   .n
        mov  ax,320             ; EGA 640: 640 pixels, two a byte
.n:     mov  [d4_rowb],ax
        mov  di,d4_rowtab       ; rowtab[y] = y * the row's bytes
        xor  ax,ax
        mov  cx,200
.row:   mov  [di],ax
        add  di,2
        add  ax,[d4_rowb]       ; the next row's start
        loop .row
        xor  bx,bx              ; dimtab[b]: both nibbles a step darker
.dim:   mov  al,bl
        mov  cl,4
        shr  al,cl              ; the left pixel
        mov  si,ax
        and  si,0Fh
        mov  ah,[d4_dim16+si]
        shl  ah,cl              ; darker, back in the high nibble
        mov  al,bl
        and  al,0Fh             ; the right pixel
        mov  si,ax
        and  si,0Fh
        or   ah,[d4_dim16+si]
        mov  [d4_dimtab+bx],ah
        inc  bl
        jnz  .dim
        mov  ax,0F000h          ; the 8x8 font: a CGA BIOS keeps it at
        mov  es,ax              ;  F000:FA6E; an EGA or VGA BIOS says
        mov  bp,0FA6Eh          ;  where its own is in ES:BP
        mov  ax,1130h
        mov  bh,3               ; BH 3: the 8x8 font, characters 0..127
        int  10h
        mov  word [d4_font],bp
        mov  word [d4_font+2],es
        pop  es
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ D4_PSET    one pixel: x BX (0..319), y DX (0..199), colour AL; clipped
;  in:  BX, DX (off the screen: nothing), AL = 0..15
;  out: -
;  needs: D4_INIT. At EGA 640 the whole column byte (both fine pixels).
;  from: GAMES\MULTSOK2\DRAW.INC:499-539 PSET (proven there)
; ----------------------------------------------------------------------
if used D4_PSET
D4_PSET:
        cmp  bx,320
        jae  .no                ; unsigned: off either side
        cmp  dx,200
        jae  .no
        push ax
        push cx
        push di
        push es
        mov  es,[cs:d4_seg]
        mov  di,dx
        shl  di,1               ; a word a row
        mov  di,[cs:d4_rowtab+di]
        add  di,[cs:d4_base]
        and  al,0Fh
        cmp  byte [cs:d4_wide],0
        je   .n
        add  di,bx              ; EGA 640: the column's byte, both halves
        mov  ah,11h
        mul  ah                 ; colour * 11h: both nibbles
        mov  [es:di],al
        jmp  .x
.n:     mov  cx,bx
        shr  cx,1
        add  di,cx              ; the byte: x/2
        test bl,1
        jnz  .odd
        mov  cl,4
        shl  al,cl              ; an even x: the high nibble
        and  byte [es:di],0Fh
        jmp  .put
.odd:   and  byte [es:di],0F0h
.put:   or   [es:di],al
.x:     pop  es
        pop  di
        pop  cx
        pop  ax
.no:    ret
end if

; ----------------------------------------------------------------------
;@ D4_PSETF   one FINE pixel: at EGA 640 x BX 0..639; else as D4_PSET
;  in:  BX = x, DX = y, AL = colour 0..15 (off the screen: nothing)
;  out: -
;  needs: D4_INIT
;  from: GAMES\MULTSOK2\DRAW.INC:541-571 PSETF (proven there)
; ----------------------------------------------------------------------
if used D4_PSETF
D4_PSETF:
        cmp  byte [cs:d4_wide],0
        je   D4_PSET
        cmp  bx,640
        jae  .no                ; unsigned: off either side
        cmp  dx,200
        jae  .no
        push ax
        push cx
        push di
        push es
        mov  es,[cs:d4_seg]
        mov  di,dx
        shl  di,1
        mov  di,[cs:d4_rowtab+di]
        add  di,[cs:d4_base]
        mov  cx,bx
        shr  cx,1
        add  di,cx              ; the byte: two fine pixels
        and  al,0Fh
        test bl,1
        jnz  .odd
        mov  cl,4
        shl  al,cl              ; the left: the high nibble
        and  byte [es:di],0Fh
        jmp  .put
.odd:   and  byte [es:di],0F0h
.put:   or   [es:di],al
        pop  es
        pop  di
        pop  cx
        pop  ax
.no:    ret
end if

; ----------------------------------------------------------------------
;@ D4_GET     read one pixel's colour: x BX (0..319), y DX -> AL
;  in:  BX, DX
;  out: AL = colour 0..15 (0 off the screen); at EGA 640 the column's left
;  needs: D4_INIT
;  from: new (D4_PSET's addressing, read)
; ----------------------------------------------------------------------
if used D4_GET
D4_GET:
        xor  al,al
        cmp  bx,320
        jae  .no
        cmp  dx,200
        jae  .no
        push cx
        push di
        push es
        mov  es,[cs:d4_seg]
        mov  di,dx
        shl  di,1
        mov  di,[cs:d4_rowtab+di]
        add  di,[cs:d4_base]
        cmp  byte [cs:d4_wide],0
        je   .n
        add  di,bx              ; EGA 640: the column's byte
        mov  al,[es:di]
        jmp  .hi
.n:     mov  cx,bx
        shr  cx,1
        add  di,cx              ; the byte: x/2
        mov  al,[es:di]
        test bl,1
        jz   .hi
        and  al,0Fh             ; odd x: the low nibble
        jmp  .x
.hi:    mov  cl,4
        shr  al,cl              ; even x: the high nibble
.x:     pop  es
        pop  di
        pop  cx
.no:    ret
end if

; ----------------------------------------------------------------------
;@ D4_ROWS    fill whole rows AX..DX-1 with colour BL
;  in:  AX = the first row, DX = the row past the last (clamped to 200;
;       DX <= AX: nothing), BL = colour 0..15
;  out: -
;  needs: D4_INIT
;  from: GAMES\MULTSOK2\DRAW.INC:435-455 FILLROWS (+ the empty-range guard)
; ----------------------------------------------------------------------
if used D4_ROWS
D4_ROWS:
        push ax
        push cx
        push dx
        push di
        push es
        cmp  dx,200
        jbe  .c
        mov  dx,200             ; no further than the last row
.c:     cmp  dx,ax
        jbe  .out               ; nothing (or backwards): nothing
        mov  es,[d4_seg]
        sub  dx,ax              ; rows
        push dx
        mul  word [d4_rowb]     ; AX = y * the row's bytes  (DX goes)
        mov  di,ax
        add  di,[d4_base]
        pop  ax
        mov  cx,[d4_rowb]
        shr  cx,1               ; words a row
        mul  cx                 ; words to fill  (DX goes)
        mov  cx,ax
        mov  al,bl
        and  al,0Fh
        mov  ah,11h
        mul  ah                 ; the colour in both nibbles
        mov  ah,al
        cld
        rep  stosw
.out:   pop  es
        pop  di
        pop  dx
        pop  cx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ D4_FILL    a box: x BX (even), y DX, CX wide (even), SI high, colour AL
;  in:  BX, DX may be negative or past the edge: clipped
;  out: -
;  needs: D4_INIT. At EGA 640 x and width count the 320 columns.
;  from: GAMES\MULTSOK2\DRAW.INC:457-489 FILLBOX (proven there)
; ----------------------------------------------------------------------
if used D4_FILL
D4_FILL:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push es
        mov  es,[d4_seg]
        and  al,0Fh
        mov  ah,11h
        mul  ah                 ; the colour in both nibbles
        mov  ah,al
        cmp  byte [d4_wide],0
        jne  .row               ; EGA 640: a column a byte already
        sar  bx,1               ; byte column (signed)
        shr  cx,1               ; bytes wide
.row:   or   si,si
        jz   .done
        or   cx,cx
        jz   .done
        cmp  dx,200
        jae  .next              ; off the screen (unsigned: above it too)
        mov  di,dx
        shl  di,1
        mov  di,[d4_rowtab+di]
        add  di,[d4_base]
        push bx
        push cx
.b:     cmp  bx,[d4_rowb]
        jae  .bn                ; off a side (unsigned)
        mov  [es:di+bx],al
.bn:    inc  bx                 ; the next byte
        loop .b
        pop  cx
        pop  bx
.next:  inc  dx                 ; the next row
        dec  si
        jmp  .row
.done:  pop  es
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ D4_COPYBG  copy rows BX..DX-1 of a background buffer into the frame
;  in:  AX = the background's segment (the same layout, from offset 0);
;       BX = the first row, DX = the row past the last (clamped to 200)
;  out: -
;  needs: D4_INIT ([d4_seg]:[d4_base] is the frame)
;  from: GAMES\MULTSOK2\DRAW.INC:479-497 COPYBG (rows as parameters)
; ----------------------------------------------------------------------
if used D4_COPYBG
D4_COPYBG:
        push ax
        push cx
        push dx
        push si
        push di
        push ds
        push es
        cmp  dx,200
        jbe  .c
        mov  dx,200
.c:     cmp  dx,bx
        jbe  .out               ; nothing to copy
        mov  es,[d4_seg]
        push ax                 ; the background's segment
        sub  dx,bx              ; rows
        mov  cx,dx
        mov  ax,bx
        mul  word [d4_rowb]     ; the first byte  (DX goes)
        mov  si,ax
        mov  di,ax
        add  di,[d4_base]
        mov  ax,cx
        mul  word [d4_rowb]     ; bytes  (DX goes)
        shr  ax,1               ; words (rows are even)
        mov  cx,ax
        pop  ds                 ; DS = the background
        cld
        rep  movsw
.out:   pop  es
        pop  ds
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ D4_DIM     darken rows BX..DX-1 one step (dusk, a dialog's backdrop)
;  in:  BX = the first row, DX = the row past the last (clamped to 200)
;  out: -
;  needs: D4_INIT (its d4_dimtab, from d4_dim16)
;  from: GAMES\MULTSOK2\DRAW.INC:575-598 DIM (rows as parameters)
; ----------------------------------------------------------------------
if used D4_DIM
D4_DIM:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push ds
        push es
        cmp  dx,200
        jbe  .c
        mov  dx,200
.c:     cmp  dx,bx
        jbe  .out
        sub  dx,bx              ; rows
        mov  cx,dx
        mov  ax,bx
        mul  word [d4_rowb]     ; the first byte  (DX goes)
        add  ax,[d4_base]
        mov  si,ax
        mov  di,ax
        mov  ax,cx
        mul  word [d4_rowb]     ; bytes  (DX goes)
        mov  cx,ax
        mov  bx,d4_dimtab
        mov  ax,[d4_seg]
        mov  ds,ax
        mov  es,ax
        cld
.d:     lodsb
        xlat byte [cs:bx]       ; both pixels a step darker
        stosb
        loop .d
.out:   pop  es
        pop  ds
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ D4_PIXC    a text-art character AL -> colour AL; CF = 1 see-through
;  in:  AL = '0'..'9' 'A'..'F' (or 'a'..'f'), '.', 'S' 's' 'P' 'p'
;  out: AL = colour 0..15; CF = 1 for '.' (AL undefined then)
;  needs: - ([d4_look] for S s P p)
;  from: GAMES\MULTSOK2\DRAW.INC:285-310 PIXC (the look from d4_look, not BP)
; ----------------------------------------------------------------------
if used D4_PIXC
D4_PIXC:
        cmp  al,'.'
        je   .clear
        cmp  al,'S'
        je   .s0
        cmp  al,'s'
        je   .s1
        cmp  al,'P'
        je   .s2
        cmp  al,'p'
        je   .s3
        cmp  al,'A'
        jb   .dig
        sub  al,'A'-10          ; 'A'..'F' -> 10..15 ('a'..'f' too, below)
        jmp  .ok
.dig:   sub  al,'0'             ; '0'..'9' -> 0..9
.ok:    and  al,0Fh
        clc
        ret
.s0:    mov  al,[cs:d4_look]    ; the look's four colours
        jmp  .ok
.s1:    mov  al,[cs:d4_look+1]
        jmp  .ok
.s2:    mov  al,[cs:d4_look+2]
        jmp  .ok
.s3:    mov  al,[cs:d4_look+3]
        jmp  .ok
.clear: stc
        ret
end if

; ----------------------------------------------------------------------
;@ D4_COMP    compile a text-art picture (DS:SI) to masks and inks at ES:DI
;  in:  DS:SI = db width (even), height, then the rows; ES:DI = room for
;       2 + width*height bytes (EGA 640: 2 + 2*width*height)
;  out: SI past the picture, DI past the compiled one
;  needs: D4_INIT ([d4_wide] picks the form: EGA 640 a byte a pixel)
;  from: GAMES\MULTSOK2\DRAW.INC:26-145 COMPILE, SOLIDC, COMPILEW (proven)
;  Compiled: db rows, db bytes a row (+80h: solid, no see-through pixel -
;  then the inks alone), then (mask, ink) pairs: buf = buf AND mask OR ink.
; ----------------------------------------------------------------------
if used D4_COMP
D4_COMP:
        push ax
        push bx
        push cx
        push dx
        cld
        cmp  byte [cs:d4_wide],0
        jne  .wide
        push si
        lodsw                   ; width, height
        mul  ah                 ; every pixel  (AX = w*h)
        mov  cx,ax
        jcxz .solid0            ; (an empty picture: solid, nothing in it)
.scan:  lodsb
        cmp  al,'.'
        je   .holed             ; one see-through pixel: masks it is
        loop .scan
.solid0:pop  si
        jmp  .solid
.holed: pop  si
        lodsb                   ; width
        mov  dl,al
        shr  dl,1               ; DL = bytes a row: two pixels each
        lodsb                   ; height
        mov  ch,al
        stosb                   ; rows
        mov  al,dl
        stosb                   ; bytes a row
        or   ch,ch
        jz   .done
        or   dl,dl
        jz   .done
.row:   mov  dh,dl
.byte:  lodsb                   ; the left pixel
        call D4_PIXC
        mov  bl,0               ; BL = mask
        jnc  .l
        mov  bl,0F0h            ; see-through: keep the buffer's high nibble
        xor  al,al
.l:     mov  cl,4
        shl  al,cl              ; the left pixel into the high nibble
        mov  bh,al              ; BH = ink
        lodsb                   ; the right pixel
        call D4_PIXC
        jnc  .r
        or   bl,0Fh             ; see-through: keep the low nibble
        xor  al,al
.r:     or   bh,al
        mov  al,bl
        stosb                   ; the mask...
        mov  al,bh
        stosb                   ; ...and the ink
        dec  dh
        jnz  .byte
        dec  ch
        jnz  .row
        jmp  .done
.solid: lodsb                   ; a solid picture: the inks alone
        mov  dl,al
        shr  dl,1               ; bytes a row
        lodsb
        mov  ch,al
        stosb                   ; rows
        mov  al,dl
        or   al,80h             ; the mark: no masks follow
        stosb
        or   ch,ch
        jz   .done
        or   dl,dl
        jz   .done
.srow:  mov  dh,dl
.sbyte: lodsb
        call D4_PIXC
        mov  cl,4
        shl  al,cl              ; the left pixel, high nibble
        mov  bh,al
        lodsb
        call D4_PIXC
        or   al,bh              ; and the right
        stosb
        dec  dh
        jnz  .sbyte
        dec  ch
        jnz  .srow
        jmp  .done
; EGA 640: every pixel a byte, both its halves the colour
.wide:  push si
        lodsw                   ; width, height
        mul  ah                 ; every pixel  (AX = w*h)
        mov  cx,ax
        jcxz .wsol0
.wscan: lodsb
        cmp  al,'.'
        je   .wholed
        loop .wscan
.wsol0: pop  si
        jmp  .wsolid
.wholed:pop  si
        lodsb
        mov  dl,al              ; DL = width: a byte a pixel out
        lodsb
        mov  ch,al
        stosb                   ; rows
        mov  al,dl
        stosb                   ; bytes a row
        or   ch,ch
        jz   .done
        or   dl,dl
        jz   .done
.wrow:  mov  dh,dl
.wpix:  lodsb
        call D4_PIXC
        mov  bl,0FFh            ; see-through: the whole byte kept
        mov  bh,0
        jc   .wput
        mov  bl,0
        mov  ah,11h
        mul  ah                 ; colour * 11h: both nibbles   (AH goes)
        mov  bh,al
.wput:  mov  al,bl
        stosb
        mov  al,bh
        stosb
        dec  dh
        jnz  .wpix
        dec  ch
        jnz  .wrow
        jmp  .done
.wsolid:lodsb
        mov  dl,al
        lodsb
        mov  ch,al
        stosb
        mov  al,dl
        or   al,80h             ; the mark: no masks follow
        stosb
        or   ch,ch
        jz   .done
        or   dl,dl
        jz   .done
.wsrow: mov  dh,dl
.wspix: lodsb
        call D4_PIXC
        mov  ah,11h
        mul  ah                 ; colour * 11h: both nibbles
        stosb
        dec  dh
        jnz  .wspix
        dec  ch
        jnz  .wsrow
.done:  pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ D4_COMP2   compile a text-art picture twice as big both ways (a winner)
;  in:  DS:SI = the picture; ES:DI = room for 2 + 4*width*height bytes
;       (EGA 640: 2 + 8*width*height)
;  out: SI past the picture, DI past the compiled one
;  needs: D4_INIT; drawn with D4_SPR like any other
;  from: GAMES\MULTSOK2\DRAW.INC:221-283 COMPILE2 (proven there)
; ----------------------------------------------------------------------
if used D4_COMP2
D4_COMP2:
        push ax
        push bx
        push cx
        push dx
        cld
        lodsb
        mov  dl,al              ; DL = width: bytes a row out, doubled
        lodsb
        mov  ch,al              ; rows in
        shl  al,1               ; rows out: twice as many
        stosb
        mov  al,dl
        cmp  byte [cs:d4_wide],0
        je   .bw
        shl  al,1               ; EGA 640: two bytes a pixel
.bw:    stosb
        or   ch,ch
        jz   .done
        or   dl,dl
        jz   .done
.row:   mov  dh,2               ; each row twice
.twice: push si
        mov  cl,dl
.pix:   lodsb
        call D4_PIXC
        mov  bl,0FFh            ; see-through: the whole byte kept
        mov  bh,0
        jc   .put
        mov  bl,0
        mov  ah,11h
        mul  ah                 ; colour * 11h: both nibbles   (AH goes)
        mov  bh,al
.put:   mov  al,bl
        stosb
        mov  al,bh
        stosb
        cmp  byte [cs:d4_wide],0
        je   .p1
        mov  al,bl              ; EGA 640: the pixel's second byte
        stosb
        mov  al,bh
        stosb
.p1:    dec  cl
        jnz  .pix
        dec  dh
        jz   .next
        pop  si                 ; the same row again
        jmp  .twice
.next:  add  sp,2               ; past this row for good
        dec  ch
        jnz  .row
.done:  pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ D4_SPR     draw a compiled picture at x BX (even), y DX; clipped
;  in:  AX:SI = the compiled picture (D4_COMP/D4_COMP2); BX = x, DX = y
;       (either may be negative or past the edge)
;  out: -
;  needs: D4_INIT; rows outside [d4_clipt]..[d4_clipb]-1 are skipped
;  from: GAMES\MULTSOK2\DRAW.INC:320-405 DRAWSPR (proven there)
; ----------------------------------------------------------------------
if used D4_SPR
D4_SPR:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        push ds
        push es
        mov  es,[d4_seg]
        mov  ds,ax              ; from here on: our own data through cs:
        cld
        lodsb
        xor  ah,ah
        mov  cx,ax              ; CX = rows
        lodsb
        cmp  byte [cs:d4_wide],0
        jne  .w                 ; EGA 640: a column is a byte
        sar  bx,1               ; x/2: the byte column, signed
.w:     jcxz .done
        test al,80h
        jnz  .solid
        mov  bp,ax              ; BP = bytes a row
.row:   cmp  dx,[cs:d4_clipt]
        jl   .skip
        cmp  dx,[cs:d4_clipb]
        jge  .done              ; rows only go down: nothing more shows
        mov  di,dx
        shl  di,1               ; a word per row
        mov  di,[cs:d4_rowtab+di] ; DI = y * the row's bytes
        add  di,[cs:d4_base]    ; + which buffer
        add  di,bx              ; + the byte column
        push cx
        push bx
        mov  cx,bp
        jcxz .rend
.byte:  lodsw                   ; AL = mask, AH = ink
        cmp  bx,[cs:d4_rowb]    ; unsigned: a negative column is huge
        jae  .off
        and  [es:di],al
        or   [es:di],ah
.off:   inc  di
        inc  bx
        loop .byte
.rend:  pop  bx
        pop  cx
        jmp  .down
.skip:  add  si,bp
        add  si,bp              ; past this row's pairs: 2 bytes each
.down:  inc  dx                 ; the next row
        loop .row
.done:  pop  es
        pop  ds
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
.solid: and  al,7Fh             ; a solid picture: the ink, copied
        mov  bp,ax
.srow:  cmp  dx,[cs:d4_clipt]
        jl   .sskip
        cmp  dx,[cs:d4_clipb]
        jge  .done
        mov  di,dx
        shl  di,1
        mov  di,[cs:d4_rowtab+di]
        add  di,[cs:d4_base]
        add  di,bx
        push cx
        push bx
        mov  cx,bp
        jcxz .snext
        cmp  bx,0
        jl   .sclip
        mov  ax,bx
        add  ax,cx              ; its right end
        cmp  ax,[cs:d4_rowb]
        ja   .sclip
        rep  movsb              ; all on the screen: the plain copy
        jmp  .snext
.sclip: lodsb                   ; over an edge: byte by byte
        cmp  bx,[cs:d4_rowb]
        jae  .soff
        mov  [es:di],al
.soff:  inc  di
        inc  bx
        loop .sclip
.snext: pop  bx
        pop  cx
        jmp  .sdown
.sskip: add  si,bp
.sdown: inc  dx                 ; the next row
        loop .srow
        jmp  .done
end if

; ----------------------------------------------------------------------
;@ D4_PRINT4  the zero-ended string at SI in 4x6 letters at [d4_tx],[d4_ty]
;  in:  SI = the string (small letters print as capitals; ASCII 32..95);
;       [d4_tx], [d4_ty] the top left, [d4_tclr], [d4_tshad] 1 = shadow
;  out: SI past the string's zero; [d4_tx] past its last letter (4 a letter)
;  needs: D4_INIT
;  from: GAMES\MULTSOK2\DRAW.INC:602-668 PUTC4, GLYPH4, PRINT4; the font
;        MULTSOK2.ASM:3237-3302 (OWL FLY III's 4x6, RESDAT.ASM)
; ----------------------------------------------------------------------
if used D4_PRINT4
D4_PRINT4:
        push ax
        push bx
        push cx
        push dx
.c:     lodsb
        or   al,al
        jz   .end
        call .putc
        jmp  .c
.end:   pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
.putc:  push si
        cmp  al,'a'
        jb   .up
        cmp  al,'z'
        ja   .up
        sub  al,20h             ; small letters as capitals
.up:    sub  al,32
        jb   .pend              ; below the space: nothing
        cmp  al,64
        jae  .pend              ; past '_': nothing
        xor  ah,ah
        mov  si,ax
        shl  si,1
        shl  si,1
        add  si,ax              ; * 5: five rows a letter
        add  si,d4_font4
        cmp  byte [d4_tshad],0
        je   .main
        mov  bx,[d4_tx]
        inc  bx                 ; one right
        mov  dx,[d4_ty]
        inc  dx                 ; one down
        xor  al,al
        call .glyph             ; the shadow
.main:  mov  bx,[d4_tx]
        mov  dx,[d4_ty]
        mov  al,[d4_tclr]
        call .glyph
.pend:  add  word [d4_tx],4     ; the next letter's place
        pop  si
        ret
; .glyph - the five rows at SI (the high 3 bits each) at x BX, y DX
.glyph: push si
        mov  ch,5
.r:     mov  cl,[si]
        inc  si
        push bx
        mov  ah,3
.b:     shl  cl,1
        jnc  .n
        call D4_PSET
.n:     inc  bx                 ; the next column
        dec  ah
        jnz  .b
        pop  bx
        inc  dx                 ; the next row
        dec  ch
        jnz  .r
        pop  si
        ret
end if

if used d4_font4
; OWL FLY III's 4x6 letters, ASCII 32 to 95, five rows each, the high
; three bits of a row the pixels
d4_font4:
        db 0,0,0,0,0                                        ; space
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
;@ D4_NUM     AX unsigned in 4x6 digits at [d4_tx],[d4_ty], at least CL of them
;  in:  AX = the number, CL = the least digits (zeros in front; 0 or 1: none)
;  out: - ([d4_tx] past it)
;  needs: D4_INIT; D4_PRINT4 (included with it)
;  from: GAMES\MULTSOK2\DRAW.INC:670-704 PNUM4, NUMSTR (proven there)
; ----------------------------------------------------------------------
if used D4_NUM
D4_NUM:
        push ax
        push bx
        push cx
        push dx
        push si
        mov  si,d4_nbuf+6
        mov  byte [si],0
        mov  bx,10
        xor  ch,ch              ; digits so far
.dig:   xor  dx,dx
        div  bx                 ; AX = value / 10, DX = the last digit
        add  dl,'0'
        dec  si
        mov  [si],dl
        inc  ch                 ; one more digit
        or   ax,ax
        jnz  .dig
.pad:   cmp  ch,cl
        jae  .out
        cmp  si,d4_nbuf
        jbe  .out               ; the buffer's room: six digits at most
        dec  si
        mov  byte [si],'0'      ; zeros in front up to CL digits
        inc  ch
        jmp  .pad
.out:   call D4_PRINT4
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ D4_SNUM    AX signed in 4x6 digits ('-' first if below 0), CL digits least
;  in:  AX = the number, CL = the least digits
;  out: - ([d4_tx] past it)
;  needs: D4_INIT, D4_NUM
;  from: GAMES\MULTSOK2\DRAW.INC:662-669 PSNUM4 (proven there)
; ----------------------------------------------------------------------
if used D4_SNUM
D4_SNUM:
        push ax
        push si
        or   ax,ax
        jns  .pos
        mov  si,.minus
        call D4_PRINT4
        neg  ax                 ; the size; the sign is printed
.pos:   call D4_NUM
        pop  si
        pop  ax
        ret
.minus  db '-',0
end if

; ----------------------------------------------------------------------
;@ D4_PRINT8  the zero-ended string at SI in the BIOS 8x8 letters
;  in:  SI = the string (ASCII 0..127); [d4_tx], [d4_ty] the top left,
;       [d4_tclr], [d4_tshad] 1 = shadow, [d4_tscale] 1 or 2
;  out: SI past the string's zero; [d4_tx] past it (8 or 16 a letter)
;  needs: D4_INIT (it finds the font)
;  from: GAMES\MULTSOK2\DRAW.INC:706-782 PUTC8, GLYPH8, PRINT8, GETGLY
; ----------------------------------------------------------------------
if used D4_PRINT8
D4_PRINT8:
        push ax
        push bx
        push cx
        push dx
        push di
.c:     lodsb
        or   al,al
        jz   .end
        call .putc
        jmp  .c
.end:   pop  di
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
.putc:  push si
        call .getgly            ; its 8 rows into d4_glyph
        cmp  byte [d4_tshad],0
        je   .main
        mov  bx,[d4_tx]
        inc  bx                 ; the shadow one right...
        mov  dx,[d4_ty]
        inc  dx                 ; ...one down
        cmp  byte [d4_tscale],1
        je   .s1
        inc  bx                 ; twice as big: the shadow twice as far
        inc  dx
.s1:    xor  al,al
        call .glyph
.main:  mov  bx,[d4_tx]
        mov  dx,[d4_ty]
        mov  al,[d4_tclr]
        call .glyph
        mov  al,[d4_tscale]
        mov  ah,8
        mul  ah                 ; the letter's width: 8 * scale
        add  [d4_tx],ax         ; on by it
        pop  si
        ret
.glyph: mov  si,d4_glyph
        mov  ch,8
.r:     mov  cl,[si]
        inc  si
        push bx
        mov  ah,8
.b:     shl  cl,1
        jnc  .n
        call D4_PSET
        cmp  byte [d4_tscale],1
        je   .n
        inc  bx                 ; a 2x2 block
        call D4_PSET
        inc  dx
        call D4_PSET
        dec  bx
        call D4_PSET
        dec  dx
.n:     inc  bx                 ; the next column
        cmp  byte [d4_tscale],1
        je   .n1
        inc  bx
.n1:    dec  ah
        jnz  .b
        pop  bx
        inc  dx                 ; the next row
        cmp  byte [d4_tscale],1
        je   .n2
        inc  dx
.n2:    dec  ch
        jnz  .r
        ret
; .getgly - character AL's 8 rows into d4_glyph
.getgly:push si
        push ds
        push es
        push cs
        pop  es
        and  ax,7Fh             ; 0..127: the font BH 3 gives
        mov  cl,3
        shl  ax,cl              ; 8 bytes a glyph
        lds  si,[d4_font]       ; DS:SI = the font (read before DS moves)
        add  si,ax
        mov  di,d4_glyph
        mov  cx,4
        cld
        rep  movsw
        pop  es
        pop  ds
        pop  si
        ret
end if

; ----------------------------------------------------------------------
;@ D4_BANNER  string SI centred across the screen at y DX: 8x8 yellow on a box
;  in:  SI = the zero-ended string, DX = its top; the box colour 1 (deep
;       blue), the letters 14 (gold) with a shadow
;  out: - ([d4_tshad] back to 0, [d4_tscale] 1)
;  needs: D4_INIT, D4_FILL, D4_PRINT8 (included with it)
;  from: GAMES\MULTSOK2\DRAW.INC:796-826 BANNER (proven there)
; ----------------------------------------------------------------------
if used D4_BANNER
D4_BANNER:
        push ax
        push bx
        push cx
        push dx
        push si
        push si
        xor  cx,cx              ; the length
.l:     lodsb
        or   al,al
        jz   .e
        inc  cx
        jmp  .l
.e:     pop  si
        mov  ax,cx
        mov  cl,3
        shl  ax,cl              ; 8 px a letter
        mov  cx,ax
        add  cx,8               ; the box: 4 px either side
        mov  bx,320
        sub  bx,cx              ; what is left over...
        sar  bx,1               ; ...half of it each side
        and  bx,0FFFEh          ; its left, even
        push dx
        push bx
        push si
        sub  dx,3               ; the box 3 px above the letters
        mov  si,14              ; 14 rows high
        mov  al,1               ; deep blue
        call D4_FILL
        pop  si
        pop  bx
        pop  dx
        add  bx,4               ; the letters 4 px in
        mov  [d4_tx],bx
        mov  [d4_ty],dx
        mov  byte [d4_tclr],14
        mov  byte [d4_tscale],1
        mov  byte [d4_tshad],1
        call D4_PRINT8
        mov  byte [d4_tshad],0
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if
