; R_DUSK.ASM - dusk by the golden section: a Bayer-dithered vignette round the play (mode 13h)
; ============================================================================
;  Recipe: copy after your program's way out (or include it there).
;  Across each margin of land - between the play's box (the castle) and
;  the screen's edge - the first 0.382 stays in full light; beyond it each
;  pixel goes ONE colour step darker (PALETTE.TXT PALDIM) when the margin's
;  fraction there passes its place in a 4x4 ordered (Bayer) matrix, so a
;  few pixels darken first and all of them at the edge: a dusk with no
;  edge, and the eye goes to the play. Rules found the hard way:
;  - one step only: two steps went black;
;  - a margin narrower than 3 cells keeps its light (a big level fills the
;    screen; dusk over it is gloom);
;  - the box itself is never darkened;
;  - things drawn every frame where the dusk may be (fountains, the owl)
;    get DUSK over their box again; lights (torches, fireflies) do not.
;  Use: DUSKPREP once a view (the box, the screen), DUSK over the whole
;  background once, then DUSK over each moving thing's box every frame.
;  The original (SCENE.INC) works on 4 bits a pixel; this one is mode 13h,
;  a byte a pixel, colours 0..15 (a byte over 15 is left as it is).
; ============================================================================

; ----------------------------------------------------------------------
;@ DUSKPREP   the dusk for a view: how far across its margin each column, row is
;  in:  [dk_x0] [dk_x1] = the play box's first and last column, [dk_y0]
;       [dk_y1] its first and last row (screen pixels, inside 0..319,
;       0..199); [cell] dw = a cell's pixels (the 3-cell rule)
;  out: -  (fills DK_TX 320 bytes, DK_TY 200 bytes: 0..255)
;  needs: -
;  from: GAMES\MULTSOK2\SCENE.INC DUSKPREP 528-610 (proven there)
; ----------------------------------------------------------------------
DUSKPREP:
        push ax
        push bx
        push cx
        push dx
        push si
        xor  si,si              ; the columns
.x:     xor  al,al
        mov  bx,[dk_x0]
        cmp  si,bx
        jge  .xr
        mov  ax,bx              ; left of the box: d = x0 - x of x0
        sub  ax,si
        mov  cx,bx
        call DK_FRAC
        jmp  .xs
.xr:    mov  bx,[dk_x1]
        cmp  si,bx
        jle  .xs                ; over the box: 0, full light
        mov  ax,si              ; right of it: d = x - x1 of 319 - x1
        sub  ax,bx
        mov  cx,319
        sub  cx,bx
        call DK_FRAC
.xs:    mov  [DK_TX+si],al
        inc  si
        cmp  si,320
        jb   .x
        xor  si,si              ; the rows
.y:     xor  al,al
        mov  bx,[dk_y0]
        cmp  si,bx
        jge  .yr
        mov  ax,bx              ; above the box: of y0
        sub  ax,si
        mov  cx,bx
        call DK_FRAC
        jmp  .ys
.yr:    mov  bx,[dk_y1]
        cmp  si,bx
        jle  .ys
        mov  ax,si              ; below it: of 199 - y1
        sub  ax,bx
        mov  cx,199
        sub  cx,bx
        call DK_FRAC
.ys:    mov  [DK_TY+si],al
        inc  si
        cmp  si,200
        jb   .y
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
; DK_FRAC - AL = d/D as 0..255: AX = d (> 0), CX = D. A margin under 3
; cells: 0. clobbers DX.
DK_FRAC:push ax
        mov  ax,[cell]
        add  ax,ax
        add  ax,[cell]          ; 3 cells
        cmp  cx,ax
        pop  ax
        jl   .z                 ; too narrow: it keeps its light
        push bx
        mov  bx,256
        mul  bx                 ; DX:AX = d * 256
        div  cx                 ; / D (D >= 3 cells > 0; d <= D: fits)
        pop  bx
        cmp  ax,255
        jbe  .r
        mov  al,255
.r:     ret
.z:     xor  al,al
        ret

; ----------------------------------------------------------------------
;@ DUSK       darken box AX..BX-1, CX..DX-1 of the buffer in ES, one step, dithered
;  in:  AX, BX = the box's first column and one past its last; CX, DX =
;       its first row and one past its last (any values: clamped)
;  out: -
;  needs: DUSKPREP for the view; ES = the buffer (320 bytes a row);
;       KIT\ART\PALETTE.TXT included (PALDIM)
;  from: GAMES\MULTSOK2\SCENE.INC DUSK 612-726, BAYER 3078 (4bpp; here 13h)
; ----------------------------------------------------------------------
DUSK:   push ax
        push bx
        push cx
        push dx
        push si
        push di
        cmp  cx,0               ; the box, kept on the screen
        jge  .c1
        xor  cx,cx
.c1:    cmp  dx,200
        jle  .c2
        mov  dx,200
.c2:    or   ax,ax
        jns  .c3
        xor  ax,ax
.c3:    cmp  bx,320
        jle  .c4
        mov  bx,320
.c4:    cmp  bx,ax              ; nothing of it on the screen (a thing off
        jle  .done              ;  the left edge: its right side negative,
        mov  [dk_bx0],ax        ;  huge unsigned - it once dimmed far past
        mov  [dk_bx1],bx        ;  its row: "interference")
        mov  [dk_by],cx
        mov  [dk_by1],dx
.row:   mov  ax,[dk_by]
        cmp  ax,[dk_by1]
        jge  .done
        mov  bx,ax
        mov  dl,[DK_TY+bx]
        mov  [dk_tyr],dl        ; how far across its margin this row is
        mov  di,ax
        mov  cl,6
        shl  di,cl              ; y * 64
        mov  dh,al
        xor  dl,dl              ; DX = y * 256
        add  di,dx              ; y * 320
        add  di,[dk_bx0]        ; the row's first pixel
        and  ax,3
        shl  ax,1
        shl  ax,1
        mov  [dk_r4],ax         ; the dither's row
        mov  si,[dk_bx0]        ; SI = x
.px:    cmp  si,[dk_bx1]
        jae  .next
        mov  al,[DK_TX+si]      ; the further of column and row
        cmp  al,[dk_tyr]
        jae  .t
        mov  al,[dk_tyr]
.t:     mov  bx,si
        and  bx,3
        add  bx,[dk_r4]
        mov  bl,[DK_BAYER+bx]   ; this pixel's place in the dither
        xor  bh,bh
        cmp  al,[DK_T1+bx]
        jbe  .pn                ; not past its threshold: lit
        mov  al,[es:di]
        cmp  al,15
        ja   .pn                ; not one of the sixteen: left alone
        mov  bl,al
        xor  bh,bh
        mov  al,[PALDIM+bx]     ; one step darker
        mov  [es:di],al
.pn:    inc  di
        inc  si
        jmp  .px
.next:  inc  word [dk_by]
        jmp  .row
.done:  pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
; the thresholds by the dither's place b: from 0.382 of the margin (98/256)
; the first pixels darken, by the edge all of them
DK_T1:
  repeat 16
        db 98 + ((%-1)*150)/16
  end repeat
DK_BAYER db 0,8,2,10, 12,4,14,6, 3,11,1,9, 15,7,13,5   ; the order they darken
dk_x0   dw 0                    ; the play's box (in)
dk_x1   dw 319
dk_y0   dw 0
dk_y1   dw 199
dk_bx0  dw 0
dk_bx1  dw 0
dk_by   dw 0
dk_by1  dw 0
dk_r4   dw 0
dk_tyr  db 0
DK_TX   rb 320
DK_TY   rb 200
