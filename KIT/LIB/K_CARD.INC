; ============================================================================
;  K_CARD.INC - KIT: the other video cards. One picture, drawn in a back
;  buffer of FOUR BITS A PIXEL (two pixels a byte, the left one in the high
;  nibble - K_D4.INC draws into it), sent to whatever card the machine has:
;    CRD_EGAW  EGA 640  mode 0Eh, 640x200, 16 colours - the buffer 320 bytes
;              a row, every one of the game's 320 columns a BYTE (two fine
;              pixels): a picture is twice as wide
;    CRD_EGA   EGA      mode 0Dh, 320x200, 16 colours in four bit planes
;    CRD_CGA   CGA      mode 4, 320x200, 4 colours: each of the 16 a 2x2
;              half-tone of black, cyan, magenta, white
;    CRD_HGC   HERCULES 720x348 mono, no BIOS mode (the 6845 by hand): a
;              pixel two dots wide, 200 rows into 300, a colour a density
;    CRD_VGA   VGA/MCGA mode 13h, 320x200: the 16 colours in DAC 0..15
;  On a VGA the EGA modes take our own 16 colours (crd_pal) through the DAC.
;  Only what changed in each row goes out (a copy of what the card shows,
;  or at EGA 640 a checksum a row).
;
;        call CRD_DETECT         ; what the machine has: crd_cap, crd_card
;        ...a text menu may change [crd_card] (K_MENU's MNU_SHOW)...
;        call CRD_MEM            ; the buffers: [crd_buf] (and the copy)
;        jc   .nomem
;        call CRD_SET            ; the mode; CF = this machine has not got it
;        ...draw into [crd_buf], [crd_rowb] bytes a row (K_D4: D4_INIT with
;           AX = [crd_buf], BL = [crd_wide])...
;        call CRD_BLIT           ; what changed, to the card
;        ...
;        call CRD_RESET          ; back to DOS's text mode (3, or 7 on mono)
;  Guide topic VIDEO ("The seam", CGA, EGA, Hercules). Rules kept: never 3DAh
;  on a Hercules, never B000h graphics on a colour card (CRD_SET refuses a
;  card crd_cap says is absent), never mode 3 forced on a mono machine.
; ============================================================================

CRD_EGAW = 1                    ; crd_card: the menu's order, MULTSOK2's
CRD_EGA  = 2
CRD_CGA  = 3
CRD_HGC  = 4
CRD_VGA  = 5
CRD_N    = 5                    ; cards in crd_cap

if used crd_card
crd_card  db 0                  ; the card in use (CRD_DETECT: the best)
crd_cap   db 0,0,0,0,0          ; crd_cap+card-1 = 1: this machine shows it
crd_isvga db 0                  ; 1: a DAC (VGA or MCGA): our own colours
crd_ega   db 0                  ; 1: EGA attribute registers (EGA or VGA)
crd_mono  db 0                  ; 1: DOS lent us mode 7 (a mono machine)
crd_orig  db 3                  ; the text mode DOS lent us (CRD_DETECT)
crd_on    db 0                  ; 1: CRD_SET put a graphics mode up
crd_full  db 0                  ; 1: the next CRD_BLIT sends every row whole
crd_wide  db 0                  ; 1: EGA 640 - the buffer 320 bytes a row
crd_rowb  dw 160                ; the buffer's bytes a row: 160 or 320
crd_vstride dw 40               ; EGA plane bytes a row on the card: 40 / 80
crd_buf   dw 0                  ; the 4bpp frame's segment (offset 0)
crd_copy  dw 0                  ; what the card shows (narrow cards only)
crd_blk   dw 0                  ; the DOS block both live in
crd_hgcseg dw 0B000h            ; where the Hercules page is (a test may aim
                                ;  it at RAM to read the converter's bytes)
; crd_pal - the 16 colours for a VGA's DAC, R G B 0..63 (MULTSOK2's ART.DAT
; palette; overwrite before CRD_SET for your own)
crd_pal   db  0, 0, 0,  2, 6,26,  0,38, 4,  6,26,36
          db 36, 8, 4, 38,14,42, 40,22, 8, 44,44,42
          db 21,21,22, 16,34,63, 24,63,18, 42,60,63
          db 60,20,12, 63,34,50, 63,56,18, 63,63,63
; crd_cgamap - each colour on a CGA (palette 1: 0 black 1 cyan 2 magenta
; 3 white) as a 2x2: even row (even x, odd x), odd row (even x, odd x)
crd_cgamap db 0,0,0,0, 0,1,0,0, 1,0,0,1, 1,1,1,1
          db 2,0,0,2, 2,2,2,2, 2,0,0,2, 3,3,3,3
          db 3,0,0,3, 1,1,1,1, 1,1,1,1, 1,3,1,3
          db 2,2,2,2, 2,3,3,2, 3,2,2,3, 3,3,3,3
; crd_hgcmap - each colour's brightness on a Hercules, 0 (dark) .. 4 (lit)
crd_hgcmap db 0,1,1,2,1,2,2,3,1,2,2,3,2,3,3,4
end if

; ----------------------------------------------------------------------
;@ CRD_DETECT ask the machine which cards it shows: crd_cap, the best in crd_card
;  in:  -
;  out: - ([crd_card] = the best: EGA 640, EGA, VGA 13h, CGA, Hercules; 0 =
;       none of them. [crd_cap+n-1] = 1 for every card n shown. [crd_isvga],
;       [crd_ega], [crd_mono], [crd_orig] = the text mode DOS lent us)
;  needs: - (call it in text mode, before CRD_SET)
;  from: GAMES\MULTSOK2\VIDEO.INC:34-95 DETECT (proven there); MCGA and the
;        BL 7 VGA from GAMES\OWLFLY3\SRC\VID.INC:132-188
; ----------------------------------------------------------------------
if used CRD_DETECT
CRD_DETECT:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        push es
        mov  ah,0Fh
        int  10h                ; AL = the mode DOS lent us
        mov  [crd_orig],al
        mov  byte [crd_mono],0
        cmp  al,7
        jne  .clr
        mov  byte [crd_mono],1  ; a mono screen
.clr:   xor  ax,ax
        mov  [crd_cap],al       ; nothing known yet
        mov  word [crd_cap+1],ax
        mov  word [crd_cap+3],ax
        mov  [crd_isvga],al
        mov  [crd_ega],al
        mov  ax,1A00h
        int  10h                ; a VGA or MCGA BIOS answers AL = 1Ah, BL
        cmp  al,1Ah
        jne  .ega
        cmp  bl,7               ; VGA, mono monitor
        je   .vga
        cmp  bl,8               ; VGA, colour monitor
        je   .vga
        cmp  bl,0Ah             ; MCGA 0Ah..0Ch: CGA's modes and 13h
        jb   .ega
        cmp  bl,0Ch
        ja   .ega
        mov  byte [crd_isvga],1
        mov  byte [crd_cap+CRD_CGA-1],1
        mov  byte [crd_cap+CRD_VGA-1],1
        jmp  .pick
.vga:   mov  byte [crd_isvga],1
        mov  byte [crd_cap+CRD_VGA-1],1
        jmp  .both
.ega:   mov  ah,12h
        mov  bl,10h             ; EGA: "tell me your configuration"
        int  10h
        cmp  bl,10h             ; unchanged: no EGA BIOS
        je   .equip
        or   bh,bh              ; BH 0: a colour monitor
        jnz  .mono
.both:  mov  byte [crd_ega],1   ; EGA and VGA show 0Dh, 0Eh and CGA's 4
        mov  byte [crd_cap+CRD_EGAW-1],1
        mov  byte [crd_cap+CRD_EGA-1],1
        mov  byte [crd_cap+CRD_CGA-1],1
        jmp  .pick
.equip: push ds
        xor  ax,ax
        mov  ds,ax
        mov  al,[0410h]         ; the equipment word: bits 4-5 the display
        pop  ds
        and  al,30h
        cmp  al,30h             ; 30h: monochrome, at 3B4h
        je   .mono
        mov  byte [crd_cap+CRD_CGA-1],1
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
.herc:  mov  byte [crd_cap+CRD_HGC-1],1
.pick:  mov  si,.order          ; the best this machine has
.p:     mov  al,[si]
        inc  si
        or   al,al
        jz   .set               ; none of ours: 0
        mov  bl,al
        xor  bh,bh
        cmp  byte [crd_cap-1+bx],0
        je   .p
.set:   mov  [crd_card],al
        pop  es
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
.order  db CRD_EGAW,CRD_EGA,CRD_VGA,CRD_CGA,CRD_HGC,0
end if

; ----------------------------------------------------------------------
;@ CRD_MEM    the 4bpp frame (and the copy) for [crd_card], from DOS
;  in:  [crd_card]
;  out: CF = 1 no memory. [crd_buf] = the frame's segment (cleared to 0),
;       [crd_wide], [crd_rowb] = 160 or 320 bytes a row, [crd_copy]
;  needs: CRD_DETECT (or [crd_card] set). It shrinks the .COM to 64K (INT
;       21h 4Ah) and takes 64000 bytes (48h) once; called again (another
;       card) it reuses them. DOS frees them at the exit.
;  from: new (guide rule 7, DOS 4Ah/48h; the layout from
;        GAMES\MULTSOK2\MULTSOK2.ASM:622-673 LAYOUT)
; ----------------------------------------------------------------------
if used CRD_MEM
CRD_MEM:
        push ax
        push bx
        push cx
        push di
        push es
        mov  byte [crd_wide],0
        mov  word [crd_rowb],160
        mov  word [crd_vstride],40
        cmp  byte [crd_card],CRD_EGAW
        jne  .lay
        mov  byte [crd_wide],1  ; EGA 640: 320 bytes a row, 80 plane bytes
        mov  word [crd_rowb],320
        mov  word [crd_vstride],80
.lay:   cmp  word [crd_blk],0
        jne  .have
        push cs
        pop  es                 ; ES = the PSP: a .COM's own block
        mov  bx,1000h           ; 64K: all a .COM needs
        mov  ah,4Ah             ; DOS: resize (refused if smaller already:
        int  21h                ;  then it is small enough - go on)
        mov  bx,0FA0h           ; 64000 bytes in paragraphs
        mov  ah,48h             ; DOS: allocate
        int  21h                ; AX = the segment, CF = none
        jc   .fail
        mov  [crd_blk],ax
.have:  mov  ax,[crd_blk]
        mov  [crd_buf],ax       ; the frame at its start
        add  ax,7D0h            ; 32000 bytes on: the copy (narrow cards)
        mov  [crd_copy],ax
        mov  es,[crd_blk]
        xor  di,di
        xor  ax,ax
        mov  cx,32000           ; 64000 bytes, as words
        cld
        rep  stosw              ; all black
        mov  byte [crd_full],1  ; the next blit: every row
        clc
.fail:  pop  es
        pop  di
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ CRD_SET    put up [crd_card]'s graphics mode (cleared), tables made
;  in:  [crd_card]; [crd_pal] (VGA: the 16 colours into the DAC)
;  out: CF = 1 this machine has not got that card (nothing changed)
;  needs: CRD_DETECT, CRD_MEM; calls CRD_MKTAB itself
;  from: GAMES\MULTSOK2\VIDEO.INC:101-187 VSET (proven there); mode 13h
;        branch new; Hercules as OWLFLY3\SRC\VID.INC:498-541 VSETMDF
; ----------------------------------------------------------------------
if used CRD_SET
CRD_SET:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push es
        mov  bl,[crd_card]
        xor  bh,bh
        or   bl,bl
        jz   .no
        cmp  bl,CRD_N
        ja   .no
        cmp  byte [crd_cap-1+bx],0
        je   .no                ; not in this machine: refuse
        call CRD_MKTAB
        mov  byte [crd_full],1
        mov  byte [crd_on],1
        mov  al,bl
        cmp  al,CRD_CGA
        je   .cga
        cmp  al,CRD_HGC
        je   .herc
        cmp  al,CRD_VGA
        je   .v13
        mov  ax,000Dh           ; EGA 320x200, sixteen colours
        cmp  byte [crd_wide],0
        je   .ega
        mov  al,0Eh             ;  or 640x200
.ega:   int  10h
        cmp  byte [crd_isvga],0
        je   .ok                ; a real EGA: its own sixteen
        mov  si,crd_pal         ; a VGA: ours, through the DAC registers
        xor  di,di              ;  the sixteen attributes point at
.dac:   mov  bl,[.dacix+di]
        xor  bh,bh
        mov  dh,[si]            ; red
        mov  ch,[si+1]          ; green
        mov  cl,[si+2]          ; blue
        mov  ax,1010h           ; BIOS: one DAC register
        push si
        push di
        int  10h
        pop  di
        pop  si
        add  si,3               ; the next colour's R G B
        inc  di                 ; the next attribute
        cmp  di,16
        jb   .dac
        jmp  .ok
.v13:   mov  ax,0013h           ; 320x200x256: our 16 in DAC 0..15
        int  10h
        mov  dx,3C8h
        xor  al,al
        out  dx,al              ; from DAC register 0 on
        inc  dx                 ; 3C9h: R, G, B, R, G, B ...
        mov  si,crd_pal
        mov  cx,48              ; 16 colours x 3
.vp:    lodsb
        out  dx,al
        loop .vp
        jmp  .ok
.cga:   mov  ax,0004h           ; CGA 320x200, four colours
        int  10h
        mov  ah,0Bh
        mov  bx,0101h           ; BH 1: palette 1 - cyan, magenta, white
        int  10h
        mov  ah,0Bh
        mov  bx,0010h           ; BH 0: black background, BL bit 4 bright
        int  10h
        cmp  byte [crd_ega],0
        jne  .attr              ; an EGA or VGA takes the attributes
        mov  dx,3D9h            ; a real CGA: the colour register itself -
        mov  al,30h             ;  bit 5 palette 1, bit 4 bright
        out  dx,al
        jmp  .ok
.attr:  mov  bx,3B01h           ; attribute 1 = light cyan 3Bh
        call .att
        mov  bx,3D02h           ;           2 = light magenta 3Dh
        call .att
        mov  bx,3F03h           ;           3 = white 3Fh
        call .att
        jmp  .ok
.herc:  mov  dx,3BFh            ; HERCULES HAS NO BIOS MODE: config port
        mov  al,1               ;  first (allow graphics),
        out  dx,al
        mov  dx,3B8h
        mov  al,2               ;  graphics timings, the screen dark,
        out  dx,al
        mov  si,.hgcprm         ;  the twelve 6845 registers,
        xor  ah,ah
.hp:    mov  dx,3B4h
        mov  al,ah
        out  dx,al              ; the register's number...
        inc  dx
        lodsb
        out  dx,al              ; ...and its value
        inc  ah                 ; the next register
        cmp  ah,12
        jb   .hp
        mov  es,[crd_hgcseg]    ;  the page wiped,
        xor  di,di
        xor  ax,ax
        mov  cx,4000h
        cld
        rep  stosw
        mov  dx,3B8h
        mov  al,0Ah             ;  the screen on: graphics, page 0
        out  dx,al
.ok:    clc
        jmp  .out
.no:    stc
.out:   pop  es
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
.att:   mov  ax,1000h           ; BL = the register, BH = its colour
        int  10h
        ret
.hgcprm db 35h,2Dh,2Eh,07h,5Bh,02h,57h,57h,02h,03h,00h,00h
.dacix  db 0,1,2,3,4,5,20,7,56,57,58,59,60,61,62,63  ; 0Dh's DAC places
end if

; ----------------------------------------------------------------------
;@ CRD_RESET  back to the text mode DOS lent us (Hercules: mode 7 by hand)
;  in:  -
;  out: -
;  needs: - (does nothing if CRD_SET never put a mode up)
;  from: GAMES\MULTSOK2\VIDEO.INC:189-206 VRESET (proven there)
; ----------------------------------------------------------------------
if used CRD_RESET
CRD_RESET:
        push ax
        push dx
        cmp  byte [crd_on],0
        je   .done              ; never left text: nothing to undo
        cmp  byte [crd_card],CRD_HGC
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
        mov  al,[crd_orig]      ; the mode DOS lent us, as it was
        int  10h
.done:  mov  byte [crd_on],0
        pop  dx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ CRD_MKTAB  make the CGA half-tone or Hercules density tables (crd_tab)
;  in:  [crd_card]; [crd_cgamap] / [crd_hgcmap] (change them, call again)
;  out: - (for the other cards it does nothing)
;  needs: - (CRD_SET calls it)
;  from: GAMES\MULTSOK2\VIDEO.INC:216-315 MKTABS (proven there)
;  The table: index a buffer byte (two pixels); 512 a row parity; the
;  first 256 give the two pixels as the left half of a card byte, the
;  next 256 as the right half: out = T[b0] OR T2[b1].
; ----------------------------------------------------------------------
if used CRD_MKTAB
CRD_MKTAB:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        cmp  byte [crd_card],CRD_HGC
        je   .herc
        cmp  byte [crd_card],CRD_CGA
        jne  .out
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
        call .put
        inc  bl                 ; the next byte
        jnz  .c
        inc  bh                 ; the next row parity
        cmp  bh,2
        jb   .c
        jmp  .out
; the Hercules: each pixel two dots, by its brightness and the row
.herc:  xor  bx,bx
.h:     mov  al,bl
        mov  cl,4
        shr  al,cl              ; the left pixel
        call .hg
        mov  dl,al
        mov  al,bl
        and  al,0Fh             ; the right pixel
        call .hg
        mov  dh,al
        call .put
        inc  bl                 ; the next byte
        jnz  .h
        inc  bh                 ; the next row parity
        cmp  bh,2
        jb   .h
.out:   pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
; .put - DL left, DH right (2 bits each) into byte BL of parity BH
.put:   push bx
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
        mov  [crd_tab+256+di],al
        mov  cl,4
        shl  al,cl              ; L<<6 | R<<4: the left half
        mov  [crd_tab+di],al
        pop  bx
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
        mov  al,[crd_cgamap+si]
        and  al,3
        ret
; .hg - colour AL's two dots on row parity BH
.hg:    xor  ah,ah
        mov  si,ax
        mov  al,[crd_hgcmap+si] ; its brightness, 0..4
        cmp  al,4
        jbe  .hl
        mov  al,4
.hl:    xor  ah,ah
        mov  si,ax
        cmp  bh,0
        mov  al,[.pat0+si]
        je   .hr
        mov  al,[.pat1+si]
.hr:    ret
.pat0   db 0,2,2,3,3            ; a brightness's two dots on an even row
.pat1   db 0,0,1,1,3            ;  ...and on an odd one: 0 none .. 4 both
end if

if used crd_tab
crd_tab rb 1024                 ; CRD_MKTAB: 2 row parities x 2 halves
end if

; ----------------------------------------------------------------------
;@ CRD_BLIT   send what changed in the 4bpp frame to the card
;  in:  [crd_buf] (the frame), [crd_card]; [crd_full] = 1 sends every row
;  out: -
;  needs: CRD_SET
;  from: GAMES\MULTSOK2\VIDEO.INC:323-608 BLIT, BLITW, EGACONV, CGACONV,
;        HGCCONV, HROW and the EPT tables (proven there); mode 13h new
;  Narrow cards: per row the first and last differing word against the
;  copy, that stretch copied and converted. EGA 640: a checksum a row, a
;  changed row whole.
; ----------------------------------------------------------------------
if used CRD_BLIT
CRD_BLIT:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push es
        cld
        cmp  byte [crd_wide],0
        jne  .wide
        mov  word [crd_by],0
.row:   mov  ax,[crd_by]
        mov  cx,160
        mul  cx                 ; AX = y*160  (DX goes)
        mov  [crd_boff],ax
        cmp  byte [crd_full],0
        jne  .all
        push ds
        mov  es,[crd_copy]
        mov  ds,[crd_buf]
        mov  si,ax
        mov  di,ax
        mov  cx,80
        repe cmpsw              ; the first word that differs...
        pop  ds
        je   .next              ; ...none: the row is as it was
        mov  ax,79
        sub  ax,cx              ; its number, 0..79
        mov  [crd_w0],ax
        push ds
        mov  ds,[crd_buf]
        mov  si,[cs:crd_boff]
        add  si,158             ; the row's last word
        mov  di,si
        mov  cx,80
        std
        repe cmpsw              ; ...and the last, from the row's end
        cld
        pop  ds
        mov  [crd_w1],cx
        jmp  .copy
.all:   mov  word [crd_w0],0
        mov  word [crd_w1],79
.copy:  push ds
        mov  es,[crd_copy]
        mov  si,[crd_boff]
        mov  ax,[crd_w0]
        shl  ax,1               ; words to bytes
        add  si,ax
        mov  di,si
        mov  cx,[crd_w1]
        sub  cx,[crd_w0]
        inc  cx                 ; the stretch, in words
        mov  ds,[crd_buf]
        rep  movsw              ; the copy: what the card is about to show
        pop  ds
        call .conv
.next:  inc  word [crd_by]      ; the next row
        cmp  word [crd_by],200
        jb   .row
        jmp  .done
; EGA 640: no copy (no room), a checksum a row - its 160 words added,
; turned a bit between each, so a pixel moved changes it too
.wide:  mov  word [crd_by],0
.wrow:  mov  ax,[crd_by]
        mul  word [crd_rowb]    ; AX = y*320  (DX goes)
        mov  [crd_boff],ax
        push ds
        mov  si,ax
        mov  ds,[crd_buf]
        mov  cx,160
        xor  dx,dx
.s:     lodsw
        add  dx,ax              ; the sum...
        rol  dx,1               ; ...turned a bit
        loop .s
        pop  ds
        mov  bx,[crd_by]
        shl  bx,1               ; a word a row
        cmp  byte [crd_full],0
        jne  .out
        cmp  dx,[crd_rsum+bx]
        je   .wnext             ; as it was
.out:   mov  [crd_rsum+bx],dx
        mov  word [crd_w0],0
        mov  word [crd_w1],159
        call .ega
.wnext: inc  word [crd_by]      ; the next row
        cmp  word [crd_by],200
        jb   .wrow
.done:  mov  byte [crd_full],0
        pop  es
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
; .conv - row [crd_by], words [crd_w0]..[crd_w1] to the card in use
.conv:  mov  al,[crd_card]
        cmp  al,CRD_CGA
        je   .cga
        cmp  al,CRD_HGC
        je   .hgc
        cmp  al,CRD_VGA
        je   .v13
; .ega - to the four planes. A plane byte is 8 pixels = 4 buffer bytes:
; four lookups, OR-ed. [crd_vstride] plane bytes a row: 40, or 80.
.ega:   mov  ax,[crd_w0]
        shr  ax,1               ; two words a plane byte
        mov  [crd_g0],ax        ; the first plane byte
        mov  cx,[crd_w1]
        shr  cx,1
        sub  cx,ax
        inc  cx                 ; how many
        mov  [crd_gn],cx
        mov  ax,[crd_by]
        mul  word [crd_vstride] ; (DX goes)
        add  ax,[crd_g0]
        mov  [crd_gdst],ax      ; where on the card
        mov  ax,[crd_g0]
        shl  ax,1
        shl  ax,1               ; four buffer bytes a plane byte
        add  ax,[crd_boff]
        mov  [crd_gsrc],ax      ; where in the buffer
        push ds
        mov  ax,0A000h
        mov  es,ax
        mov  bx,crd_etab        ; plane 0's tables
        mov  ah,1               ; plane 0's bit in the map mask
.plane: mov  dx,3C4h
        mov  al,2               ; sequencer register 2: the map mask
        out  dx,ax
        push ax
        push bx
        mov  si,[crd_gsrc]
        mov  di,[crd_gdst]
        mov  cx,[crd_gn]
        mov  ds,[crd_buf]
.g:     lodsb
        xlat byte [cs:bx]       ; pixels 0,1 -> bits 7,6
        mov  ah,al
        inc  bh                 ; the next table, 256 on
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
        sub  bh,3               ; back to the first of the four
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
; .cga - a word is four pixels, one CGA byte
.cga:   mov  ax,[crd_by]
        mov  di,ax
        and  di,1
        mov  cl,13
        shl  di,cl              ; (y AND 1) * 2000h: the bank
        shr  ax,1
        mov  cx,80
        mul  cx                 ; (y/2)*80: the row in its bank
        add  di,ax
        add  di,[crd_w0]        ; + a byte a word
        mov  bx,[crd_by]
        and  bx,1
        mov  cl,9
        shl  bx,cl              ; parity * 512
        add  bx,crd_tab         ; this row parity's tables
        mov  si,[crd_w0]
        shl  si,1               ; words to bytes
        add  si,[crd_boff]
        mov  cx,[crd_w1]
        sub  cx,[crd_w0]
        inc  cx                 ; words
        mov  ax,0B800h
        mov  es,ax
        push ds
        mov  ds,[crd_buf]
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
; .hgc - an even row two Hercules rows, an odd one one (200 -> 300),
; 24 rows down from the top of 348
.hgc:   mov  ax,[crd_by]
        mov  bx,ax
        shr  ax,1
        mov  cx,3
        mul  cx                 ; (y/2)*3
        add  ax,24              ; the letterbox's top
        test bl,1
        jz   .even
        add  ax,2               ; an odd row: its one Hercules row
        jmp  .hrow
.even:  push ax
        call .hrow
        pop  ax
        inc  ax                 ; and the one under it
; .hrow - Hercules row AX from buffer row [crd_by], words w0..w1
.hrow:  mov  bx,ax
        and  bx,1
        mov  cl,9
        shl  bx,cl              ; its parity * 512
        add  bx,crd_tab         ; the row parity's tables
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
        add  di,[crd_w0]
        mov  si,[crd_w0]
        shl  si,1               ; words to bytes
        add  si,[crd_boff]
        mov  cx,[crd_w1]
        sub  cx,[crd_w0]
        inc  cx                 ; words: a byte each
        mov  es,[crd_hgcseg]
        push ds
        mov  ds,[crd_buf]
.hw:    lodsb
        xlat byte [cs:bx]
        mov  ah,al
        inc  bh
        lodsb
        xlat byte [cs:bx]
        or   al,ah
        dec  bh
        stosb
        loop .hw
        pop  ds
        ret
; .v13 - mode 13h: a buffer byte is two screen bytes
.v13:   mov  ax,[crd_by]
        mov  cx,320
        mul  cx                 ; y*320  (DX goes)
        mov  di,[crd_w0]
        shl  di,1
        shl  di,1               ; four pixels a word
        add  di,ax
        mov  si,[crd_w0]
        shl  si,1               ; words to bytes
        add  si,[crd_boff]
        mov  cx,[crd_w1]
        sub  cx,[crd_w0]
        inc  cx
        shl  cx,1               ; bytes
        mov  ax,0A000h
        mov  es,ax
        push ds
        mov  ds,[crd_buf]
.vb:    lodsb
        mov  ah,al
        and  ah,0Fh             ; the right pixel
        shr  al,1
        shr  al,1
        shr  al,1
        shr  al,1               ; the left pixel
        stosw                   ; left, then right
        loop .vb
        pop  ds
        ret

; the blit's own state
crd_by    dw 0
crd_boff  dw 0
crd_w0    dw 0
crd_w1    dw 0
crd_g0    dw 0
crd_gn    dw 0
crd_gsrc  dw 0
crd_gdst  dw 0
crd_rsum  rw 200                ; EGA 640: a checksum a row

; crd_etab: plane p, place q (which two pixels of the eight), byte b:
; plane p's bits of b's two pixels, at place q. FASM computes all 4096.
macro CRD_EPT p,q
{
  repeat 256
    db (((((%-1) shr (4+p)) and 1) shl 1) + (((%-1) shr p) and 1)) shl (6-2*q)
  end repeat
}
crd_etab:
        CRD_EPT 0,0
        CRD_EPT 0,1
        CRD_EPT 0,2
        CRD_EPT 0,3
        CRD_EPT 1,0
        CRD_EPT 1,1
        CRD_EPT 1,2
        CRD_EPT 1,3
        CRD_EPT 2,0
        CRD_EPT 2,1
        CRD_EPT 2,2
        CRD_EPT 2,3
        CRD_EPT 3,0
        CRD_EPT 3,1
        CRD_EPT 3,2
        CRD_EPT 3,3
end if
