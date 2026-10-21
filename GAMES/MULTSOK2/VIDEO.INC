; ==================================================================
;  VIDEO.INC - MULTIPLAY SOKO II's three cards.  The game draws into its
;  own buffer (DRAW.INC: 320x200, two pixels a byte); BLIT finds, row
;  by row, the stretch that differs from what the card already shows
;  (a copy in pseg) and converts only that stretch:
;    EGA  mode 0Dh, 320x200, sixteen colours in four planes: a plane
;         byte is 8 pixels, one bit of each; the tables give every
;         plane's bits for two pixels at once (FASM computes them).  On
;         a VGA the sixteen are our own (ART.DAT's palette, into the DAC).
;    CGA  mode 4, 320x200, four colours, palette 1 bright (cyan, magenta,
;         white): each colour a 2x2 half-tone (ART.DAT's map); the even
;         rows at B800:0000, the odd ones at B800:2000.
;    HERC 720x348 dots, no BIOS mode: the 6845 programmed by hand.  A
;         pixel is two dots wide; 200 rows become 300 (2, 1, 2, 1...);
;         a colour is a density of dots (ART.DAT's brightness); memory is
;         four banks, row y at (y AND 3)*2000h + (y/4)*90.
;  Detection asks the BIOS (VGA: INT 10h 1A00h; EGA: 12h/10h), then the
;  equipment word, then watches the Hercules' retrace bit move.
; ==================================================================
CARD_EGA = 1
CARD_CGA = 2
CARD_HGC = 3

; ------------------------------------------------------------------
;  DETECT - capega, capcga, caphgc: what this machine can show; isvga:
;  a VGA (our own sixteen colours).  Card: the best of them.
; ------------------------------------------------------------------
DETECT: mov  ax,1A00h
        int  10h                ; a VGA BIOS answers AL = 1Ah, BL = display
        cmp  al,1Ah
        jne  .ega
        cmp  bl,8               ; VGA, colour monitor
        jne  .mcga
        mov  byte [isvga],1
        jmp  .both
.mcga:  cmp  bl,0Bh             ; MCGA (0Bh mono, 0Ch colour): CGA's modes
        jb   .mono
        mov  byte [capcga],1
        jmp  .pick
.ega:   mov  ah,12h
        mov  bl,10h             ; EGA: "tell me your configuration"
        int  10h
        cmp  bl,10h             ; unchanged: no EGA BIOS
        je   .equip
        or   bh,bh              ; BH 0: a colour monitor
        jnz  .mono
.both:  mov  byte [capega],1    ; EGA and VGA show CGA's mode 4 as well
        mov  byte [capcga],1
        jmp  .pick
.equip: push ds
        xor  ax,ax
        mov  ds,ax
        mov  al,[0410h]         ; the equipment word: bits 4-5 the display
        pop  ds
        and  al,30h
        cmp  al,30h             ; 30h: monochrome, at 3B4h
        je   .mono
        mov  byte [capcga],1
        jmp  .pick
.mono:  mov  dx,3BAh            ; a Hercules' bit 7 here follows the
        in   al,dx              ;  retrace; an MDA's never moves
        and  al,80h
        mov  ah,al
        mov  cx,8000h
.watch: in   al,dx
        and  al,80h
        cmp  al,ah
        jne  .herc
        loop .watch
        jmp  .pick
.herc:  mov  byte [caphgc],1
.pick:  mov  al,CARD_EGA        ; the best this machine has: EGA, the
        cmp  byte [capega],0    ;  pilot's choice "for authenticity"
        jne  .set
        mov  al,CARD_CGA
        cmp  byte [capcga],0
        jne  .set
        mov  al,CARD_HGC
        cmp  byte [caphgc],0
        jne  .set
        xor  al,al              ; none of ours
.set:   mov  [card],al
        ret

; ------------------------------------------------------------------
;  VSET - the chosen card's graphics mode, cleared; every row of the
;  next BLIT goes out whole.  VRESET - the text mode DOS lent us.
; ------------------------------------------------------------------
VSET:   mov  byte [vfull],1
        mov  al,[card]
        cmp  al,CARD_CGA
        je   .cga
        cmp  al,CARD_HGC
        je   .herc
        mov  ax,000Dh           ; EGA 320x200, sixteen colours
        int  10h
        cmp  byte [isvga],0
        je   .egaok             ; a real EGA: its own sixteen
        mov  si,artpal          ; a VGA: ours, through the DAC registers
        xor  di,di              ;  the sixteen attributes point at
.dac:   mov  bl,[DACIX+di]
        xor  bh,bh
        mov  dh,[si]            ; red
        mov  ch,[si+1]          ; green
        mov  cl,[si+2]          ; blue
        mov  ax,1010h
        push si
        push di
        int  10h
        pop  di
        pop  si
        add  si,3
        inc  di
        cmp  di,16
        jb   .dac
.egaok: mov  word [vconv],EGACONV
        ret
.cga:   mov  ax,0004h           ; CGA 320x200, four colours
        int  10h
        mov  ah,0Bh
        mov  bx,0101h           ; BH 1: palette 1 - cyan, magenta, white
        int  10h
        mov  ah,0Bh
        mov  bx,0010h           ; BH 0: black background, BL bit 4 bright
        int  10h
        cmp  byte [capega],0
        jne  .attr              ; an EGA or VGA takes the attributes
        mov  dx,3D9h            ; a real CGA: the colour register itself -
        mov  al,30h             ;  bit 5 palette 1, bit 4 bright
        out  dx,al
        jmp  .cgaok
.attr:  mov  bx,3B01h           ; attribute 1 = light cyan 3Bh
        call .att
        mov  bx,3D02h           ;           2 = light magenta 3Dh
        call .att
        mov  bx,3F03h           ;           3 = white 3Fh
        call .att
.cgaok: mov  word [vconv],CGACONV
        ret
.att:   mov  ax,1000h           ; BL = the register, BH = its colour
        int  10h
        ret
.herc:  mov  dx,3BFh            ; HERCULES HAS NO BIOS MODE: config port
        mov  al,1               ;  first (allow graphics),
        out  dx,al
        mov  dx,3B8h
        mov  al,2               ;  graphics timings, the screen dark,
        out  dx,al
        mov  si,HGCPRM          ;  the twelve 6845 registers,
        xor  ah,ah
.hp:    mov  dx,3B4h
        mov  al,ah
        out  dx,al              ; the register's number...
        inc  dx
        lodsb
        out  dx,al              ; ...and its value
        inc  ah
        cmp  ah,12
        jb   .hp
        push es
        mov  ax,0B000h          ;  the page wiped,
        mov  es,ax
        xor  di,di
        xor  ax,ax
        mov  cx,4000h
        rep  stosw
        pop  es
        mov  dx,3B8h
        mov  al,0Ah             ;  the screen on: graphics, page 0
        out  dx,al
        mov  word [vconv],HGCCONV
        ret

VRESET: cmp  byte [vmode],0
        je   .done              ; never left text: nothing to undo
        cmp  byte [card],CARD_HGC
        jne  .bios
        mov  dx,3B8h
        xor  al,al
        out  dx,al              ; the screen dark
        mov  ax,0007h           ; the BIOS's mono text mode: its 6845 timings
        int  10h
        mov  dx,3BFh
        xor  al,al
        out  dx,al              ; graphics locked away again
        jmp  .done
.bios:  xor  ah,ah
        mov  al,[origmode]      ; the mode DOS lent us, as it was
        int  10h
.done:  mov  byte [vmode],0
        ret

; ------------------------------------------------------------------
;  MKTABS - the chosen card's tables, from ART.DAT's maps: the CGA's or
;  the Hercules' (one room, ctab = htab: only one card is ever up).
;  Index: a buffer byte, two pixels (left in the high nibble).  For each
;  row parity, the first table gives those two pixels' bits as the left
;  half of an output byte, the second (256 on) as the right half:
;  out = T[b0] OR T2[b1].
; ------------------------------------------------------------------
MKTABS: cmp  byte [card],CARD_HGC
        je   .herc
        xor  bx,bx              ; BL = the byte, BH = the row parity
.c:     mov  al,bl
        mov  cl,4
        shr  al,cl              ; L: the left pixel...
        xor  ch,ch              ;  ...at an even x
        call .cg
        mov  dl,al              ; DL = the left pixel's CGA colour
        mov  al,bl
        and  al,0Fh             ; R, at an odd x
        mov  ch,1
        call .cg
        mov  dh,al              ; DH = the right pixel's
        push bx
        mov  al,bh
        xor  ah,ah
        mov  cl,9
        shl  ax,cl              ; parity * 512
        mov  di,ax
        xor  bh,bh
        add  di,bx              ; + the byte
        mov  al,dl
        mov  cl,2
        shl  al,cl
        or   al,dh              ; L<<2 | R: the right half
        mov  [ctab+256+di],al
        mov  cl,4
        shl  al,cl              ; L<<6 | R<<4: the left half
        mov  [ctab+di],al
        pop  bx
        inc  bl
        jnz  .c
        inc  bh
        cmp  bh,2
        jb   .c
        ret
; the Hercules: each pixel two dots, by its brightness and the row
.herc:  xor  bx,bx
.h:     mov  al,bl
        mov  cl,4
        shr  al,cl
        call .hg
        mov  dl,al
        mov  al,bl
        and  al,0Fh
        call .hg
        mov  dh,al
        push bx
        mov  al,bh
        xor  ah,ah
        mov  cl,9
        shl  ax,cl
        mov  di,ax
        xor  bh,bh
        add  di,bx
        mov  al,dl
        mov  cl,2
        shl  al,cl
        or   al,dh
        mov  [htab+256+di],al
        mov  cl,4
        shl  al,cl
        mov  [htab+di],al
        pop  bx
        inc  bl
        jnz  .h
        inc  bh
        cmp  bh,2
        jb   .h
        ret
; .cg - colour AL's CGA colour on row parity BH, x parity CH
.cg:    xor  ah,ah
        shl  ax,1
        shl  ax,1               ; 4 a colour
        mov  si,ax
        mov  al,bh
        shl  al,1               ; + 2 a row parity
        add  al,ch              ; + the x parity
        xor  ah,ah
        add  si,ax
        mov  al,[artcga+si]
        and  al,3
        ret
; .hg - colour AL's two dots on row parity BH
.hg:    push bx
        xor  ah,ah
        mov  si,ax
        mov  al,[arthgc+si]     ; its brightness, 0..4
        cmp  al,4
        jbe  .hl
        mov  al,4
.hl:    xor  ah,ah
        mov  si,ax
        cmp  bh,0
        mov  al,[HGPAT0+si]
        je   .hr
        mov  al,[HGPAT1+si]
.hr:    pop  bx
        ret

; ------------------------------------------------------------------
;  BLIT - the buffer out to the card, only what changed: for each row,
;  the first and the last word (four pixels) that differ from pseg's
;  copy; that stretch is copied there and converted.  vfull: every row
;  whole (after a mode change).
; ------------------------------------------------------------------
BLIT:   push es
        mov  word [by],0
.row:   mov  ax,[by]
        mov  cx,160
        mul  cx                 ; AX = y*160  (DX goes)
        mov  [boff],ax
        cmp  byte [vfull],0
        jne  .all
        push ds
        mov  es,[pseg]
        mov  ds,[gseg]
        mov  si,ax
        mov  di,ax
        mov  cx,80
        repe cmpsw              ; the first word that differs...
        pop  ds
        je   .next              ; ...none: the row is as it was
        mov  ax,79
        sub  ax,cx
        mov  [w0],ax            ; its number, 0..79
        push ds
        mov  ds,[gseg]
        mov  si,[cs:boff]
        add  si,158
        mov  di,si
        mov  cx,80
        std
        repe cmpsw              ; ...and the last, from the row's end
        cld
        pop  ds
        mov  [w1],cx
        jmp  .copy
.all:   mov  word [w0],0
        mov  word [w1],79
.copy:  push ds
        mov  es,[pseg]
        mov  si,[boff]
        mov  ax,[w0]
        shl  ax,1
        add  si,ax
        mov  di,si
        mov  cx,[w1]
        sub  cx,[w0]
        inc  cx                 ; the stretch, in words
        mov  ds,[gseg]
        rep  movsw              ; the copy: what the card is about to show
        pop  ds
        call [vconv]
.next:  inc  word [by]
        cmp  word [by],200
        jb   .row
        mov  byte [vfull],0
        pop  es
        ret

; EGACONV - row [by], words [w0]..[w1] to the four planes.  A plane byte
; is 8 pixels = 2 words = 4 buffer bytes: four lookups, OR-ed.
EGACONV:mov  ax,[w0]
        shr  ax,1
        mov  [g0],ax            ; the first plane byte
        mov  cx,[w1]
        shr  cx,1
        sub  cx,ax
        inc  cx
        mov  [gn],cx            ; how many
        mov  ax,[by]
        mov  cx,40
        mul  cx
        add  ax,[g0]
        mov  [gdst],ax          ; where on the card
        mov  ax,[g0]
        shl  ax,1
        shl  ax,1
        add  ax,[boff]
        mov  [gsrc],ax          ; where in the buffer
        push ds
        mov  ax,0A000h
        mov  es,ax
        mov  bx,etab            ; plane 0's tables
        mov  ah,1               ; plane 0's bit in the map mask
.plane: mov  dx,3C4h
        mov  al,2               ; sequencer register 2: the map mask
        out  dx,ax
        push ax
        push bx
        mov  si,[gsrc]
        mov  di,[gdst]
        mov  cx,[gn]
        mov  ds,[gseg]
.g:     lodsb
        xlat byte [cs:bx]       ; pixels 0,1 -> bits 7,6
        mov  ah,al
        inc  bh
        lodsb
        xlat byte [cs:bx]       ; pixels 2,3 -> bits 5,4
        or   ah,al
        inc  bh
        lodsb
        xlat byte [cs:bx]       ; 4,5 -> 3,2
        or   ah,al
        inc  bh
        lodsb
        xlat byte [cs:bx]       ; 6,7 -> 1,0
        or   al,ah
        sub  bh,3
        stosb
        loop .g
        push cs
        pop  ds
        pop  bx
        pop  ax
        add  bx,1024            ; the next plane's four tables
        shl  ah,1               ; and its bit
        cmp  ah,10h
        jb   .plane
        mov  dx,3C4h
        mov  ax,0F02h           ; every plane writable again
        out  dx,ax
        pop  ds
        ret

; CGACONV - row [by], words [w0]..[w1]: a word is four pixels, one byte
CGACONV:mov  ax,[by]
        mov  di,ax
        and  di,1
        mov  cl,13
        shl  di,cl              ; (y AND 1) * 2000h: the bank
        shr  ax,1
        mov  cx,80
        mul  cx                 ; (y/2)*80: the row in its bank
        add  di,ax
        add  di,[w0]
        mov  bx,[by]
        and  bx,1
        mov  cl,9
        shl  bx,cl
        add  bx,ctab            ; this row parity's tables
        mov  si,[w0]
        shl  si,1
        add  si,[boff]
        mov  cx,[w1]
        sub  cx,[w0]
        inc  cx
        mov  ax,0B800h
        mov  es,ax
        push ds
        mov  ds,[gseg]
.w:     lodsb
        xlat byte [cs:bx]       ; pixels 0,1: the byte's left half
        mov  ah,al
        inc  bh
        lodsb
        xlat byte [cs:bx]       ; pixels 2,3: its right half
        or   al,ah
        dec  bh
        stosb
        loop .w
        pop  ds
        ret

; HGCCONV - row [by] becomes Hercules rows: an even row two of them, an
; odd one one (200 -> 300), 24 rows down from the top of 348
HGCCONV:mov  ax,[by]
        mov  bx,ax
        shr  ax,1
        mov  cx,3
        mul  cx                 ; (y/2)*3
        add  ax,24
        test bl,1
        jz   .even
        add  ax,2
        jmp  HROW               ; an odd row: its one Hercules row
.even:  push ax
        call HROW
        pop  ax
        inc  ax                 ; and the one under it
; HROW - Hercules row AX from buffer row [by], words [w0]..[w1]
HROW:   mov  bx,ax
        and  bx,1
        mov  cl,9
        shl  bx,cl
        add  bx,htab            ; the row parity's tables
        mov  di,ax
        and  di,3
        mov  cl,13
        shl  di,cl              ; (Y AND 3) * 2000h: the bank
        shr  ax,1
        shr  ax,1
        mov  cx,90
        mul  cx                 ; (Y/4)*90
        add  di,ax
        add  di,5               ; 40 dots in: 640 of the 720, centred
        add  di,[w0]
        mov  si,[w0]
        shl  si,1
        add  si,[boff]
        mov  cx,[w1]
        sub  cx,[w0]
        inc  cx
        mov  ax,0B000h
        mov  es,ax
        push ds
        mov  ds,[gseg]
.w:     lodsb
        xlat byte [cs:bx]
        mov  ah,al
        inc  bh
        lodsb
        xlat byte [cs:bx]
        or   al,ah
        dec  bh
        stosb
        loop .w
        pop  ds
        ret

; ------------------------------------------------------------------
;  The tables.  ETAB: plane p, place q (which two pixels of the eight),
;  byte b: plane p's bits of b's two pixels, at place q.  Pure bit
;  arithmetic, so FASM computes all 4096 bytes.
; ------------------------------------------------------------------
macro EPT p,q
{
  repeat 256
    db (((((%-1) shr (4+p)) and 1) shl 1) + (((%-1) shr p) and 1)) shl (6-2*q)
  end repeat
}
etab:   EPT 0,0
        EPT 0,1
        EPT 0,2
        EPT 0,3
        EPT 1,0
        EPT 1,1
        EPT 1,2
        EPT 1,3
        EPT 2,0
        EPT 2,1
        EPT 2,2
        EPT 2,3
        EPT 3,0
        EPT 3,1
        EPT 3,2
        EPT 3,3
HGCPRM  db 35h,2Dh,2Eh,07h,5Bh,02h,57h,57h,02h,03h,00h,00h
DACIX   db 0,1,2,3,4,5,20,7,56,57,58,59,60,61,62,63  ; mode 0Dh's DAC places
HGPAT0  db 0,2,2,3,3            ; a brightness's two dots on an even row
HGPAT1  db 0,0,1,1,3            ;  ...and on an odd one: 0 none .. 4 both
