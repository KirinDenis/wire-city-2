; ==================================================================
;  DRAW.INC - MULTSOKO's back buffer and what goes into it.
;  The buffer: 320x200, TWO PIXELS A BYTE - the left one in the high
;  nibble - 160 bytes a row, in gseg at [tbase]: 0 the frame that goes
;  out to the card, BGOFF the background it is copied from (the walls,
;  the park, the water: drawn once a level, not every frame).  Every x
;  a picture is drawn at is even, so a picture is whole bytes.
;  Pictures are compiled into sseg: db rows, db bytes a row, then a
;  (mask, ink) pair a byte, drawn as  buf = (buf AND mask) OR ink.
;  Text: OWL FLY's own 4x6 letters for the counts, the BIOS's 8x8 for
;  the titles.
; ==================================================================

; ------------------------------------------------------------------
;  COMPILE - a raw picture, DS:SI (db width, height, then its rows,
;  a character a pixel), into ES:DI.  BP -> the look in CS: shirt, its
;  shade, cap and trousers, their shade.  SI and DI end past both.
;  clobbers AX, BX, CX, DX.
;  A picture with no see-through pixel at all - a stone, the water, the
;  grass, a crate - is SOLID: bytes a row + 80h, then the ink alone, half
;  the room and drawn as a plain copy.
; ------------------------------------------------------------------
COMPILE:push si
        lodsw                   ; width, height
        mov  cl,al
        mul  ah                 ; every pixel  (AX = w*h)
        mov  cx,ax
.scan:  lodsb
        cmp  al,'.'
        je   .holed             ; one see-through pixel: masks it is
        loop .scan
        pop  si
        jmp  SOLIDC
.holed: pop  si
        lodsb                   ; width
        mov  dl,al
        shr  dl,1               ; DL = bytes a row: two pixels each
        lodsb                   ; height
        mov  ch,al
        stosb                   ; rows
        mov  al,dl
        stosb                   ; bytes a row
.row:   mov  dh,dl
.byte:  lodsb                   ; the left pixel
        call PIXC
        mov  bl,0               ; BL = mask
        jnc  .l
        mov  bl,0F0h            ; see-through: keep the buffer's high nibble
        xor  al,al
.l:     mov  cl,4
        shl  al,cl              ; the left pixel into the high nibble
        mov  bh,al              ; BH = ink
        lodsb                   ; the right pixel
        call PIXC
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
        ret

; SOLIDC - COMPILE's solid kind: db rows, db bytes a row + 80h, the ink
SOLIDC: lodsb
        mov  dl,al
        shr  dl,1
        lodsb
        mov  ch,al
        stosb
        mov  al,dl
        or   al,80h             ; the mark: no masks follow
        stosb
.row:   mov  dh,dl
.byte:  lodsb
        call PIXC
        mov  cl,4
        shl  al,cl
        mov  bh,al
        lodsb
        call PIXC
        or   al,bh
        stosb
        dec  dh
        jnz  .byte
        dec  ch
        jnz  .row
        ret

; COMPILE2 - the same, every pixel doubled both ways: the winner's man
COMPILE2:
        lodsb
        mov  dl,al              ; DL = width: bytes a row out, doubled
        lodsb
        mov  ch,al              ; rows in
        shl  al,1
        stosb                   ; rows out: twice as many
        mov  al,dl
        stosb
.row:   mov  dh,2               ; each row twice
.twice: push si
        mov  cl,dl
.pix:   lodsb
        call PIXC
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
        dec  cl
        jnz  .pix
        dec  dh
        jz   .next
        pop  si                 ; the same row again
        jmp  .twice
.next:  add  sp,2               ; past this row for good
        dec  ch
        jnz  .row
        ret

; PIXC - a picture's character AL as a colour: CF=1 see-through
PIXC:   cmp  al,'.'
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
        sub  al,'A'-10          ; 'A'..'F' -> 10..15
        jmp  .ok
.dig:   sub  al,'0'             ; '0'..'9' -> 0..9
.ok:    and  al,0Fh
        clc
        ret
.s0:    mov  al,[cs:bp]         ; the look's four colours
        jmp  .ok
.s1:    mov  al,[cs:bp+1]
        jmp  .ok
.s2:    mov  al,[cs:bp+2]
        jmp  .ok
.s3:    mov  al,[cs:bp+3]
        jmp  .ok
.clear: stc
        ret

; ------------------------------------------------------------------
;  DRAWSPR - a compiled picture, sseg:SI, its top left at x BX (even,
;  may be negative), y DX (may be negative), into gseg at [tbase].
;  Rows outside clipt..clipb-1 and bytes off the sides are skipped.
;  Keeps DS; clobbers AX, BX, CX, DX, SI, DI.
;  In C:  for each row, for each byte b:
;            buf[y][x/2+b] = (buf[y][x/2+b] & mask) | ink;
; ------------------------------------------------------------------
DRAWSPR:push bp
        push ds
        push es
        mov  es,[cs:gseg]
        mov  ds,[cs:sseg]       ; from here on: our own data through cs:
        lodsb
        xor  ah,ah
        mov  cx,ax              ; CX = rows
        lodsb
        sar  bx,1               ; x/2: the byte column, signed
        test al,80h
        jnz  .solid
        mov  bp,ax              ; BP = bytes a row
.row:   cmp  dx,[cs:clipt]
        jl   .skip
        cmp  dx,[cs:clipb]
        jge  .done              ; rows only go down: nothing more shows
        mov  di,dx
        shl  di,1               ; a word per row
        mov  di,[cs:rowtab+di]  ; DI = y*160
        add  di,[cs:tbase]      ; + which buffer
        add  di,bx              ; + the byte column
        push cx
        push bx
        mov  cx,bp
.byte:  lodsw                   ; AL = mask, AH = ink
        cmp  bx,160             ; unsigned: a negative column is huge
        jae  .off
        and  [es:di],al
        or   [es:di],ah
.off:   inc  di
        inc  bx
        loop .byte
        pop  bx
        pop  cx
        jmp  .down
.skip:  add  si,bp
        add  si,bp              ; past this row's pairs: 2 bytes each
.down:  inc  dx
        loop .row
.done:  pop  es
        pop  ds
        pop  bp
        ret
.solid: and  al,7Fh             ; a solid picture: the ink, copied
        mov  bp,ax
.srow:  cmp  dx,[cs:clipt]
        jl   .sskip
        cmp  dx,[cs:clipb]
        jge  .done
        mov  di,dx
        shl  di,1
        mov  di,[cs:rowtab+di]
        add  di,[cs:tbase]
        add  di,bx
        push cx
        push bx
        mov  cx,bp
        cmp  bx,0
        jl   .sclip
        mov  ax,bx
        add  ax,cx
        cmp  ax,160
        ja   .sclip
        rep  movsb              ; all on the screen: the plain copy
        jmp  .snext
.sclip: lodsb                   ; over an edge: byte by byte
        cmp  bx,160
        jae  .soff
        mov  [es:di],al
.soff:  inc  di
        inc  bx
        loop .sclip
.snext: pop  bx
        pop  cx
        jmp  .sdown
.sskip: add  si,bp
.sdown: inc  dx
        loop .srow
        jmp  .done

; ------------------------------------------------------------------
;  FILLROWS - rows AX..DX-1 of [tbase] all colour BL (a nibble)
;  FILLBOX  - the box x BX (even), y DX, CX wide (even), SI high, in
;             colour AL; clipped to the screen
;  COPYBG   - the background's playfield rows into the frame
;  PSET     - pixel x BX, y DX, colour AL into [tbase]; keeps everything
; ------------------------------------------------------------------
FILLROWS:
        push es
        mov  es,[gseg]
        sub  dx,ax              ; rows
        push dx
        mov  cx,160
        mul  cx                 ; AX = y*160  (DX goes)
        mov  di,ax
        add  di,[tbase]
        pop  ax
        mov  cx,80
        mul  cx                 ; words to fill  (DX goes)
        mov  cx,ax
        mov  al,bl
        mov  ah,11h
        mul  ah                 ; the colour in both nibbles
        mov  ah,al
        rep  stosw
        pop  es
        ret

FILLBOX:push es
        mov  es,[gseg]
        mov  ah,11h
        mul  ah
        mov  ah,al              ; AL = AH = the colour, both nibbles
        sar  bx,1               ; byte column
        shr  cx,1               ; bytes wide
.row:   or   si,si
        jz   .done
        cmp  dx,200
        jae  .next              ; off the screen (unsigned: above it too)
        mov  di,dx
        shl  di,1
        mov  di,[rowtab+di]
        add  di,[tbase]
        push bx
        push cx
.b:     cmp  bx,160
        jae  .bn
        mov  [es:di+bx],al
.bn:    inc  bx
        loop .b
        pop  cx
        pop  bx
.next:  inc  dx
        dec  si
        jmp  .row
.done:  pop  es
        ret

COPYBG: push ds
        push es
        mov  ax,[gseg]
        mov  ds,ax
        mov  es,ax
        mov  si,BGOFF+PFTOP*160
        mov  di,PFTOP*160
        mov  cx,(PFBOT-PFTOP)*80
        rep  movsw
        pop  es
        pop  ds
        ret

PSET:   cmp  bx,320
        jae  .no                ; unsigned: off either side
        cmp  dx,200
        jae  .no
        push ax
        push cx
        push di
        push es
        mov  es,[cs:gseg]
        mov  di,dx
        shl  di,1
        mov  di,[cs:rowtab+di]
        add  di,[cs:tbase]
        mov  cx,bx
        shr  cx,1
        add  di,cx              ; the byte
        and  al,0Fh
        test bl,1
        jnz  .odd
        mov  cl,4
        shl  al,cl              ; an even x: the high nibble
        and  byte [es:di],0Fh
        jmp  .put
.odd:   and  byte [es:di],0F0h
.put:   or   [es:di],al
        pop  es
        pop  di
        pop  cx
        pop  ax
.no:    ret

; DIM - the playfield darkened, every colour one step down: under the
; winner, the warehouse stays where it was, in the evening
DIM:    push ds
        push es
        mov  ax,[gseg]
        mov  ds,ax
        mov  es,ax
        mov  si,PFTOP*160
        mov  di,si
        mov  cx,(PFBOT-PFTOP)*160
        mov  bx,dimtab
.d:     lodsb
        xlat byte [cs:bx]
        stosb
        loop .d
        pop  es
        pop  ds
        ret

; ------------------------------------------------------------------
;  Text.  [tx], [ty]: the top left; [tclr]: the colour; [tshad] 1: a
;  black shadow one pixel down and right first.
;  PUTC4 - the 4x6 letters (3 wide, 5 high, a column and a row apart);
;  PRINT4 - the zero-ended string at SI; PNUM4 - AX unsigned, at least
;  CL digits; PSNUM4 - AX signed.  All keep SI past what they print.
; ------------------------------------------------------------------
PUTC4:  push si
        cmp  al,'a'
        jb   .up
        cmp  al,'z'
        ja   .up
        sub  al,20h             ; small letters as capitals
.up:    sub  al,32
        jb   .end               ; below the space: nothing
        cmp  al,64
        jae  .end               ; past '_': nothing
        xor  ah,ah
        mov  si,ax
        shl  si,1
        shl  si,1
        add  si,ax              ; * 5: five rows a letter
        add  si,FONT4
        cmp  byte [tshad],0
        je   .main
        mov  bx,[tx]
        inc  bx
        mov  dx,[ty]
        inc  dx
        xor  al,al
        call GLYPH4             ; the shadow
.main:  mov  bx,[tx]
        mov  dx,[ty]
        mov  al,[tclr]
        call GLYPH4
.end:   add  word [tx],4
        pop  si
        ret
; GLYPH4 - the five rows at SI (the high 3 bits each) at x BX, y DX
GLYPH4: push si
        mov  ch,5
.r:     mov  cl,[si]
        inc  si
        push bx
        mov  ah,3
.b:     shl  cl,1
        jnc  .n
        call PSET
.n:     inc  bx
        dec  ah
        jnz  .b
        pop  bx
        inc  dx
        dec  ch
        jnz  .r
        pop  si
        ret

PRINT4: lodsb
        or   al,al
        jz   .end
        call PUTC4
        jmp  PRINT4
.end:   ret

PSNUM4: or   ax,ax
        jns  PNUM4
        push ax
        push cx
        mov  al,'-'
        call PUTC4
        pop  cx
        pop  ax
        neg  ax                 ; the size; the sign is printed
PNUM4:  push si
        call NUMSTR
        call PRINT4
        pop  si
        ret

; NUMSTR - AX unsigned as digits at SI (in nbuf), at least CL of them
NUMSTR: mov  si,nbuf+6
        mov  byte [si],0
        mov  bx,10
        xor  ch,ch              ; digits so far
.dig:   xor  dx,dx
        div  bx                 ; AX = value / 10, DX = the last digit
        add  dl,'0'
        dec  si
        mov  [si],dl
        inc  ch
        or   ax,ax
        jnz  .dig
.pad:   cmp  ch,cl
        jae  .out
        dec  si
        mov  byte [si],'0'      ; zeros in front up to CL digits
        inc  ch
        jmp  .pad
.out:   ret

; ------------------------------------------------------------------
;  PUTC8 - the BIOS's 8x8 letter AL at [tx], [ty], [tscale] times as
;  big (1 or 2), in [tclr], a shadow if [tshad]; PRINT8 - a string.
; ------------------------------------------------------------------
PUTC8:  push si
        call GETGLY             ; its 8 rows into glyph
        cmp  byte [tshad],0
        je   .main
        mov  bx,[tx]
        inc  bx
        mov  dx,[ty]
        inc  dx
        cmp  byte [tscale],1
        je   .s1
        inc  bx                 ; twice as big: the shadow twice as far
        inc  dx
.s1:    xor  al,al
        call GLYPH8
.main:  mov  bx,[tx]
        mov  dx,[ty]
        mov  al,[tclr]
        call GLYPH8
        mov  al,[tscale]
        mov  ah,8
        mul  ah
        add  [tx],ax            ; on by the letter's width
        pop  si
        ret
GLYPH8: mov  si,glyph
        mov  ch,8
.r:     mov  cl,[si]
        inc  si
        push bx
        mov  ah,8
.b:     shl  cl,1
        jnc  .n
        call PSET
        cmp  byte [tscale],1
        je   .n
        inc  bx                 ; a 2x2 block
        call PSET
        inc  dx
        call PSET
        dec  bx
        call PSET
        dec  dx
.n:     inc  bx
        cmp  byte [tscale],1
        je   .n1
        inc  bx
.n1:    dec  ah
        jnz  .b
        pop  bx
        inc  dx
        cmp  byte [tscale],1
        je   .n2
        inc  dx
.n2:    dec  ch
        jnz  .r
        ret

PRINT8: lodsb
        or   al,al
        jz   .end
        call PUTC8
        jmp  PRINT8
.end:   ret

; GETGLY - character AL's 8 rows into glyph.  clobbers AX, CX, DI.
GETGLY: push si
        push ds
        push es
        push cs
        pop  es
        xor  ah,ah
        mov  cl,3
        shl  ax,cl              ; 8 bytes a glyph
        lds  si,[fontp]         ; DS:SI = the font (read before DS moves)
        add  si,ax
        mov  di,glyph
        mov  cx,4
        rep  movsw
        pop  es
        pop  ds
        pop  si
        ret

; STRLEN - CX = the length of the zero-ended string at SI
STRLEN: push si
        xor  cx,cx
.l:     lodsb
        or   al,al
        jz   .e
        inc  cx
        jmp  .l
.e:     pop  si
        ret

; BANNER - string SI centred across the screen, its top at y DX, in the
; 8x8 letters, yellow on a dark box, over whatever is there
BANNER: push dx
        call STRLEN
        mov  ax,cx
        mov  cl,3
        shl  ax,cl              ; 8 px a letter
        mov  cx,ax
        add  cx,8               ; the box: 4 px either side
        mov  bx,320
        sub  bx,cx
        shr  bx,1
        and  bx,0FFFEh          ; its left, even
        pop  dx
        push dx
        push bx
        push si
        sub  dx,3
        mov  si,14              ; 14 rows high
        mov  al,1               ; dark blue
        call FILLBOX
        pop  si
        pop  bx
        pop  dx
        add  bx,4
        mov  [tx],bx
        mov  [ty],dx
        mov  byte [tclr],14
        mov  byte [tscale],1
        mov  byte [tshad],1
        call PRINT8
        mov  byte [tshad],0
        ret
