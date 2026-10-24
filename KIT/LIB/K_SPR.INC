; ============================================================================
;  K_SPR.INC - KIT: sprites for mode 13h, drawn as TEXT ART in the source.
;
;  A picture is typed into the program, one character a pixel:
;      .  (or a space)  see-through: what is behind shows
;      0..9  A..Z       a colour, 0..35, plus [spr_base] (a palette offset,
;                       default 0: then '0'..'9' 'A'..'F' are the 16 EGA
;                       colours of the default VGA palette, 'G'.. go on)
;  Small letters are the capitals. The picture starts with its size:
;
;  BALL    db 8,8                  ; width, height (1..255 each)
;          db '..4444..'
;          db '.4CCCC4.'
;          db '4CCFFCC4'           ; F: white, the shine
;          db '4CCCFCC4'
;          db '4CCCCCC4'
;          db '4CCCCCC4'
;          db '.4CCCC4.'
;          db '..4444..'
;
;  SPR_TEXT draws it straight from the text (slow, fine for a few). For a
;  game, SPR_COMPILE it once at start into a COMPILED sprite - db width,
;  height, then width*height bytes, row by row, 255 = see-through - and draw
;  that with SPR_DRAW (or F flipped, S twice as big, M any of those):
;
;          mov  si,BALL
;          mov  di,ballc           ; ballc db 2+8*8 dup(?)
;          call SPR_COMPILE
;          ...
;          mov  si,ballc
;          mov  bx,[x]
;          mov  dx,[y]
;          call SPR_DRAW           ; clipped at every edge, see-through kept
;
;  A strip of frames is the same sprites one after another: SPR_NTH finds
;  frame n, SPR_ANIM says which n the clock is at. SPR_HIT and SPR_PIXHIT
;  say whether two things touch. SPR_RLEPACK / SPR_RLE: a big picture with
;  holes, packed, drawn without a single test a pixel (not clipped).
;  Everything draws into ES, 320 bytes a row; sprites live in DS.
; ============================================================================

if used spr_base
spr_base db 0                   ; added to every text-art colour
end if

; ---- SPR_CODE (inside the kit): text-art character AL -> AL = colour, or
;  CF = 1 for see-through.
if used SPR_CODE
SPR_CODE:
        cmp  al,'0'
        jb   .clr               ; '.', ' ', anything below '0'
        cmp  al,'9'
        jbe  .dig
        and  al,0DFh            ; small letters as capitals
        cmp  al,'A'
        jb   .clr
        cmp  al,'Z'
        ja   .clr
        sub  al,'A'-10          ; 'A'..'Z' -> 10..35
        jmp  .ok
.dig:   sub  al,'0'             ; '0'..'9' -> 0..9
.ok:    add  al,[spr_base]      ; the palette offset
        clc
        ret
.clr:   stc
        ret
end if

; ----------------------------------------------------------------------
;@ SPR_TEXT   draw a text-art sprite straight from its text, clipped, see-through
;  in:  SI = the text art (db w,h, then the rows), BX = x, DX = y (signed),
;       [spr_base] the colour offset
;  out: -
;  needs: -
;  from: GAMES\MULTSOK2\DRAW.INC:26-72 COMPILE + PIXC 283-310 (the text
;        art), ported to a byte a pixel and drawn at once
; ----------------------------------------------------------------------
if used SPR_TEXT
SPR_TEXT:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        mov  cl,[si]            ; CL = the width
        mov  ch,[si+1]          ; CH = the height
        add  si,2               ; SI = the first row
        or   cl,cl
        jz   .done              ; an empty picture
        or   ch,ch
        jz   .done
.row:   push bx
        push cx
.px:    lodsb                   ; AL = the character
        call SPR_CODE           ; AL = the colour, or CF: see-through
        jc   .n
        cmp  bx,319             ; on the screen? (unsigned: negative is huge)
        ja   .n
        cmp  dx,199
        ja   .n
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
        mov  [es:di],al         ; the pixel
.n:     inc  bx                 ; x++
        dec  cl
        jnz  .px
        pop  cx
        pop  bx
        inc  dx                 ; y++
        dec  ch
        jnz  .row
.done:  pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ SPR_COMPILE text art -> a compiled sprite (db w,h, w*h bytes, 255 see-through)
;  in:  SI = the text art, DI = where the compiled sprite goes (DS, room for
;       2 + w*h bytes), [spr_base] the colour offset (a colour that comes
;       out 255 would read as see-through: keep base + 35 below 255)
;  out: DI = past the compiled sprite (compile a strip of frames in a row)
;  needs: -
;  from: GAMES\MULTSOK2\DRAW.INC:26-72 COMPILE (4bpp mask/ink there; here
;        8bpp, one byte a pixel, 255 the hole)
; ----------------------------------------------------------------------
if used SPR_COMPILE
SPR_COMPILE:
        push ax
        push cx
        push si
        mov  al,[si]            ; the size goes over as it is
        mov  [di],al
        mov  ah,[si+1]
        mov  [di+1],ah
        mul  ah                 ; AX = w * h: every pixel
        mov  cx,ax
        add  si,2
        add  di,2
        jcxz .e                 ; an empty picture
.l:     mov  al,[si]            ; AL = the character
        inc  si
        call SPR_CODE           ; AL = the colour...
        jnc  .s
        mov  al,255             ; ...or the hole
.s:     mov  [di],al
        inc  di
        loop .l
.e:     pop  si
        pop  cx
        pop  ax
        ret
end if

; ---- SPR_CORE (inside the kit): draw compiled sprite SI at (BX,DX), clipped
;  to the screen, see-through 255 kept; [spr_mode] bit 0 flips it across,
;  bit 1 draws it twice as big. Every register kept.
if used SPR_CORE
SPR_CORE:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        mov  [spr_x],bx
        mov  [spr_y],dx
        xor  ax,ax
        mov  al,[si]            ; AX = the width
        mov  [spr_w],ax
        dec  ax
        mov  [spr_wm1],ax       ; w - 1: for the flip
        mov  al,[si+1]          ; AX = the height
        mov  dx,[spr_w]         ; DX = the width
        xor  cx,cx              ; CL = the shift: 0, or 1 at x2
        test byte [spr_mode],2
        jz   .s1
        inc  cx                 ; CL = 1
        shl  ax,1               ; the drawn height: twice
        shl  dx,1               ; the drawn width: twice
.s1:    mov  [spr_sh],cl
        add  si,2
        mov  [spr_dat],si       ; the pixels
        ; the columns: c0 = max(0, -x), c1 = min(dw, 320 - x)
        xor  bx,bx              ; BX = c0 = 0
        mov  cx,[spr_x]
        neg  cx                 ; CX = -x
        jle  .c0
        mov  bx,cx              ; c0 = -x
.c0:    mov  cx,320
        sub  cx,[spr_x]         ; CX = 320 - x
        cmp  cx,dx
        jle  .c1
        mov  cx,dx              ; c1 = dw
.c1:    cmp  bx,cx
        jl   .cok
        jmp  .done              ; no column on the screen
.cok:   mov  [spr_c0],bx
        mov  [spr_c1],cx
        ; the rows: r0 = max(0, -y), r1 = min(dh, 200 - y)
        xor  bx,bx              ; BX = r0
        mov  cx,[spr_y]
        neg  cx                 ; CX = -y
        jle  .r0
        mov  bx,cx
.r0:    mov  cx,200
        sub  cx,[spr_y]         ; CX = 200 - y
        cmp  cx,ax
        jle  .r1
        mov  cx,ax              ; r1 = dh
.r1:    cmp  bx,cx
        jl   .rok
        jmp  .done              ; no row on the screen
.rok:   mov  [spr_r1],cx
        mov  bp,bx              ; BP = the drawn row
.row:   mov  ax,bp
        mov  cl,[spr_sh]
        shr  ax,cl              ; AX = the sprite's row
        mul  word [spr_w]       ; AX = row * w (DX = 0: small)
        add  ax,[spr_dat]
        mov  si,ax              ; SI = that row's pixels
        mov  ax,[spr_y]
        add  ax,bp              ; AX = the screen row
        mov  di,ax
        mov  cl,8
        shl  di,cl              ; DI = y * 256
        mov  cl,6
        shl  ax,cl              ; AX = y * 64
        add  di,ax              ; DI = y * 320
        add  di,[spr_x]
        mov  bx,[spr_c0]        ; BX = the drawn column
        add  di,bx              ; DI = the first pixel on the screen
        mov  cl,[spr_sh]
.px:    mov  ax,bx
        shr  ax,cl              ; AX = the sprite's column
        test byte [spr_mode],1
        jz   .nf
        neg  ax
        add  ax,[spr_wm1]       ; AX = w - 1 - column: flipped
.nf:    push si
        add  si,ax
        mov  al,[si]            ; AL = the pixel
        pop  si
        cmp  al,255             ; see-through?
        je   .sk
        mov  [es:di],al
.sk:    inc  di
        inc  bx                 ; the next column
        cmp  bx,[spr_c1]
        jb   .px
        inc  bp                 ; the next row
        cmp  bp,[spr_r1]
        jb   .row
.done:  pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
spr_mode db 0
spr_sh   db 0
spr_x    dw 0
spr_y    dw 0
spr_w    dw 0
spr_wm1  dw 0
spr_dat  dw 0
spr_c0   dw 0
spr_c1   dw 0
spr_r1   dw 0
end if

; ----------------------------------------------------------------------
;@ SPR_DRAW   draw a compiled sprite, clipped at every edge, see-through kept
;  in:  SI = the compiled sprite, BX = x, DX = y (signed: half off is fine)
;  out: -
;  needs: SPR_COMPILE made it
;  from: new (13h masked blit: the inventory found none in 8bpp)
; ----------------------------------------------------------------------
if used SPR_DRAW
SPR_DRAW:
        mov  byte [spr_mode],0
        jmp  SPR_CORE
end if

; ----------------------------------------------------------------------
;@ SPR_DRAWF  draw a compiled sprite flipped across (facing the other way)
;  in:  SI = the compiled sprite, BX = x, DX = y
;  out: -
;  needs: SPR_COMPILE made it
;  from: new
; ----------------------------------------------------------------------
if used SPR_DRAWF
SPR_DRAWF:
        mov  byte [spr_mode],1
        jmp  SPR_CORE
end if

; ----------------------------------------------------------------------
;@ SPR_DRAWS  draw a compiled sprite twice as big (each pixel 2x2)
;  in:  SI = the compiled sprite, BX = x, DX = y
;  out: -
;  needs: SPR_COMPILE made it
;  from: new (MULTSOK2 PUTC8's x2 idea, for pictures)
; ----------------------------------------------------------------------
if used SPR_DRAWS
SPR_DRAWS:
        mov  byte [spr_mode],2
        jmp  SPR_CORE
end if

; ----------------------------------------------------------------------
;@ SPR_DRAWM  draw a compiled sprite in mode AL: bit 0 flipped, bit 1 x2
;  in:  SI = the compiled sprite, BX = x, DX = y, AL = 0..3
;  out: -
;  needs: SPR_COMPILE made it
;  from: new
; ----------------------------------------------------------------------
if used SPR_DRAWM
SPR_DRAWM:
        mov  [spr_mode],al
        and  byte [spr_mode],3
        jmp  SPR_CORE
end if

; ----------------------------------------------------------------------
;@ SPR_NTH    SI = frame AX of a strip of equal compiled sprites
;  in:  SI = the first frame, AX = n (0 = the first)
;  out: SI = frame n (each frame is 2 + w*h bytes)
;  needs: the frames compiled one after another (SPR_COMPILE in a row)
;  from: new
; ----------------------------------------------------------------------
if used SPR_NTH
SPR_NTH:
        push ax
        push bx
        push dx
        mov  bx,ax              ; BX = n
        mov  al,[si]
        mul  byte [si+1]        ; AX = w * h
        add  ax,2               ; AX = the bytes a frame
        mul  bx                 ; AX = n frames of them
        add  si,ax              ; SI = frame n
        pop  dx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ SPR_ANIM   AX = which frame a looping animation is at, from a clock
;  in:  AX = the clock (the BIOS tick, a frame counter), BL = ticks a frame,
;       BH = frames in the loop (0 in either is taken as 1)
;  out: AX = the frame, 0..BH-1
;  needs: -
;  from: new (MULTSOK2 POPNUM's "a pixel every three ticks" idea)
; ----------------------------------------------------------------------
if used SPR_ANIM
SPR_ANIM:
        push bx
        push cx
        push dx
        mov  cl,bl
        xor  ch,ch              ; CX = ticks a frame
        or   cx,cx
        jnz  .t
        inc  cx                 ; never divide by 0
.t:     xor  dx,dx              ; DX:AX = the clock
        div  cx                 ; AX = frames gone by
        mov  cl,bh
        xor  ch,ch              ; CX = frames in the loop
        or   cx,cx
        jnz  .f
        inc  cx
.f:     xor  dx,dx
        div  cx                 ; DX = frames gone by mod frames
        mov  ax,dx
        pop  dx
        pop  cx
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ SPR_HIT    CF = 1 if two boxes overlap (axis-aligned, signed coordinates)
;  in:  SI = box A, DI = box B: each dw x, y, width, height
;  out: CF = 1 they overlap (touching edges do not), CF = 0 they do not
;  needs: -
;  from: new (the inventory: no object-vs-object collision in the code)
; ----------------------------------------------------------------------
if used SPR_HIT
SPR_HIT:
        push ax
        mov  ax,[di]
        add  ax,[di+4]          ; AX = B's right edge (x + w)
        cmp  [si],ax            ; A starts at or right of it?
        jge  .no
        mov  ax,[si]
        add  ax,[si+4]          ; AX = A's right edge
        cmp  [di],ax            ; B starts at or right of it?
        jge  .no
        mov  ax,[di+2]
        add  ax,[di+6]          ; AX = B's bottom (y + h)
        cmp  [si+2],ax          ; A starts at or below it?
        jge  .no
        mov  ax,[si+2]
        add  ax,[si+6]          ; AX = A's bottom
        cmp  [di+2],ax          ; B starts at or below it?
        jge  .no
        pop  ax
        stc                     ; they overlap
        ret
.no:    pop  ax
        clc
        ret
end if

; ----------------------------------------------------------------------
;@ SPR_PIXHIT CF = 1 if two compiled sprites overlap in a solid pixel of both
;  in:  SI = sprite A, DI = sprite B, BX = B's x - A's x, DX = B's y - A's y
;  out: CF = 1 a pixel of A and a pixel of B (neither 255) meet
;  needs: SPR_COMPILE made them; test SPR_HIT first, it is much cheaper
;  from: new
; ----------------------------------------------------------------------
if used SPR_PIXHIT
SPR_PIXHIT:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        mov  [spr_hdx],bx
        mov  [spr_hdy],dx
        xor  ax,ax
        mov  al,[si]
        mov  [spr_haw],ax       ; A's width
        mov  al,[di]
        mov  [spr_hbw],ax       ; B's width
        ; the columns in A: x0 = max(0, dx), x1 = min(wA, dx + wB)
        mov  ax,bx
        cmp  ax,0
        jge  .x0
        xor  ax,ax
.x0:    mov  [spr_hx0],ax
        mov  ax,bx
        add  ax,[spr_hbw]       ; AX = dx + wB
        cmp  ax,[spr_haw]
        jle  .x1
        mov  ax,[spr_haw]
.x1:    mov  [spr_hx1],ax
        cmp  ax,[spr_hx0]
        jle  .no                ; no column in common
        ; the rows in A: y0 = max(0, dy), y1 = min(hA, dy + hB)
        mov  cx,dx
        cmp  cx,0
        jge  .y0
        xor  cx,cx              ; CX = y0
.y0:    xor  ax,ax
        mov  al,[di+1]
        add  ax,dx              ; AX = dy + hB
        xor  bx,bx
        mov  bl,[si+1]          ; BX = hA
        cmp  ax,bx
        jle  .y1
        mov  ax,bx
.y1:    mov  [spr_hy1],ax
        cmp  ax,cx
        jle  .no                ; no row in common
        add  si,2               ; the pixels
        add  di,2
        mov  [spr_hpa],si
        mov  [spr_hpb],di
.row:   mov  ax,cx
        mul  word [spr_haw]     ; AX = y * wA
        add  ax,[spr_hpa]
        mov  si,ax              ; SI = A's row y
        mov  ax,cx
        sub  ax,[spr_hdy]       ; AX = y - dy: B's row
        mul  word [spr_hbw]     ; AX = that * wB
        add  ax,[spr_hpb]
        sub  ax,[spr_hdx]       ; ...minus dx: B's column = A's - dx
        mov  di,ax              ; DI = B's row, indexed by A's x
        mov  bx,[spr_hx0]
.px:    cmp  byte [si+bx],255   ; A see-through here?
        je   .nx
        cmp  byte [di+bx],255   ; B?
        je   .nx
        stc                     ; both solid: a hit
        jmp  .out
.nx:    inc  bx
        cmp  bx,[spr_hx1]
        jl   .px
        inc  cx                 ; the next row
        cmp  cx,[spr_hy1]
        jl   .row
.no:    clc
.out:   pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
spr_hdx  dw 0
spr_hdy  dw 0
spr_haw  dw 0
spr_hbw  dw 0
spr_hx0  dw 0
spr_hx1  dw 0
spr_hy1  dw 0
spr_hpa  dw 0
spr_hpb  dw 0
end if

; ----------------------------------------------------------------------
;@ SPR_RLE    draw an RLE stream (literal/run/skip tokens) at (BX,DX), not clipped
;  in:  SI = the stream (DS), BX = x, DX = y; the whole picture must be on
;       the screen. Tokens: a byte, two bits type and six count (count 0:
;       a word count follows):  00 the end, 40|n n bytes follow as they
;       are, 80|n one byte follows n times, C0|n skip n (see-through).
;       The stream walks the screen 320 bytes a row: a row's end and the
;       next row's start are one skip.
;  out: -
;  needs: SPR_RLEPACK makes a stream from a compiled sprite
;  from: GAMES\OWLFLY3\SRC\SYM.INC:1252-1291 SIDEBMPF (its token grammar)
; ----------------------------------------------------------------------
if used SPR_RLE
SPR_RLE:
        push ax
        push bx
        push cx
        push si
        push di
        mov  di,dx
        mov  ax,dx
        mov  cl,8
        shl  di,cl              ; DI = y * 256
        mov  cl,6
        shl  ax,cl              ; AX = y * 64
        add  di,ax              ; DI = y * 320
        add  di,bx              ; DI = the top left
        cld
.t:     lodsb                   ; the token
        or   al,al
        jz   .d                 ; 00: the end
        mov  bl,al
        and  al,3Fh
        mov  cl,al
        xor  ch,ch              ; CX = the count
        or   cl,cl
        jnz  .n
        lodsw                   ; count 0: a word count follows
        mov  cx,ax
.n:     and  bl,0C0h            ; BL = the type
        cmp  bl,0C0h
        je   .skip
        cmp  bl,80h
        je   .run
.lit:   rep  movsb              ; LITERAL: CX bytes as they are
        jmp  .t
.run:   lodsb                   ; RUN: one byte, CX times
        rep  stosb
        jmp  .t
.skip:  add  di,cx              ; SKIP: the background shows
        jmp  .t
.d:     pop  di
        pop  si
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ SPR_RLEPACK pack a compiled sprite into an SPR_RLE stream
;  in:  SI = the compiled sprite, DI = where the stream goes (DS; at most
;       3 + w*h*2 bytes - a picture with no runs grows, one with holes and
;       long runs shrinks)
;  out: DI = past the stream (its 00 end mark)
;  needs: -
;  from: new (the packer OWLFLY3's TOOLS made on Windows, as 8086 code)
; ----------------------------------------------------------------------
if used SPR_RLEPACK
SPR_RLEPACK:
        push ax
        push bx
        push cx
        push dx
        push si
        push bp
        xor  dx,dx
        mov  dl,[si]            ; DX = w
        xor  ax,ax
        mov  al,[si+1]
        mov  bp,ax              ; BP = rows left
        add  si,2               ; SI = row 0
        mov  word [spr_pskip],0 ; nothing see-through waiting
        or   dx,dx
        jz   .end
        or   bp,bp
        jz   .end
.row:   xor  bx,bx              ; BX = c, the column
.col:   cmp  bx,dx
        jae  .eol
        mov  al,[si+bx]
        cmp  al,255             ; see-through?
        jne  .solid
        inc  word [spr_pskip]   ; one more to skip
        inc  bx
        jmp  .col
.solid: call .flush             ; the skip before it, if any
        mov  cx,1               ; CX = the run of AL from c
.rl:    push bx
        add  bx,cx
        cmp  bx,dx
        jae  .rle
        cmp  [si+bx],al
        jne  .rle
        pop  bx
        inc  cx
        jmp  .rl
.rle:   pop  bx
        cmp  cx,3               ; three or more the same: a RUN
        jb   .lit
        mov  ah,80h
        call .tok               ; 80 | n
        mov  [di],al            ; the byte
        inc  di
        add  bx,cx              ; c += n
        jmp  .col
.lit:   mov  [spr_pst],bx       ; LITERAL from c: up to a hole, the row's
        xor  cx,cx              ;  end, or the start of a run of three
.ll:    cmp  bx,dx
        jae  .lend
        mov  al,[si+bx]
        cmp  al,255
        je   .lend
        jcxz .ltake             ; the first one always goes in
        mov  ax,bx
        add  ax,2
        cmp  ax,dx              ; two more on this row?
        jae  .ltake
        mov  al,[si+bx]
        cmp  al,[si+bx+1]
        jne  .ltake
        cmp  al,[si+bx+2]
        je   .lend              ; a run of three starts here
.ltake: inc  cx
        inc  bx
        jmp  .ll
.lend:  mov  ah,40h
        call .tok               ; 40 | n
        push si
        add  si,[spr_pst]       ; SI = the first of them
.lcp:   mov  al,[si]            ; the bytes as they are
        mov  [di],al
        inc  si
        inc  di
        loop .lcp
        pop  si
        jmp  .col
.eol:   add  si,dx              ; the next row
        dec  bp
        jz   .end
        mov  ax,320
        sub  ax,dx              ; AX = 320 - w: the gap to the next row
        add  [spr_pskip],ax     ;  is part of the skip
        jmp  .row
.end:   mov  byte [di],0        ; the end (a trailing skip is not needed)
        inc  di
        pop  bp
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
; .flush - a SKIP token for spr_pskip, if any. AX kept.
.flush: cmp  word [spr_pskip],0
        je   .fr
        push ax
        push cx
        mov  cx,[spr_pskip]
        mov  ah,0C0h
        call .tok
        mov  word [spr_pskip],0
        pop  cx
        pop  ax
.fr:    ret
; .tok - token type AH with count CX (a word count after 00 when > 63). AL kept.
.tok:   cmp  cx,63
        ja   .tw
        push ax
        or   ah,cl              ; type | count
        mov  [di],ah
        inc  di
        pop  ax
        ret
.tw:    mov  [di],ah            ; type | 0...
        mov  [di+1],cx          ; ...and the word count
        add  di,3
        ret
spr_pskip dw 0
spr_pst   dw 0
end if
