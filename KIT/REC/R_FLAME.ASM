; R_FLAME.ASM - a torch's live flame, drawn every frame (mode 13h)
; ============================================================================
;  Recipe: copy after your program's way out (or include it there).
;  "The torches do not burn, they blink" - two pictures had swapped on the
;  beat. A flame is drawn, not pasted: rows of fire from the cup up, each
;  narrower - white at the heart, yellow, red at its edges - its height and
;  its lean from two short irregular tables, every torch at its own place
;  in them, a step a frame. Draw KIT\ART\TORCH.TXT TORCH16 (the bare torch)
;  first, then FLAME over it.
;  The original (SCENE.INC) is 4 bits a pixel; this one is mode 13h, a byte
;  a pixel, through the program's PSET. Colours are PALETTE.TXT's: 15 white,
;  14 gold, 12 red.
; ============================================================================

; ----------------------------------------------------------------------
;@ FLAME      a torch's flame, alive: a little different every frame
;  in:  BX, DX = the torch's cell, top left; AL = its place in the tables
;       (from where it is: x/2 + 3y - so no two torches burn alike)
;  out: -
;  needs: PSET (AL colour at BX, DX, clipped, keeps all), [cell] dw (the
;       cell's pixels: 16 for TORCH16), [fstep] (R_CLOCK.ASM)
;  from: GAMES\MULTSOK2\SCENE.INC FLAME 1644-1752 (4bpp, PSETF; here 13h)
; ----------------------------------------------------------------------
FLAME:  push ax
        push bx
        push cx
        push dx
        push si
        mov  [fl_ph],al
        mov  ax,[cell]
        shr  ax,1               ; half a cell
        add  bx,ax              ; the cell's middle across,
        add  dx,ax              ;  and down: the cup
        mov  [fl_y0],dx
        mov  [fl_x0],bx
        mov  ax,[fstep]
        add  al,[fl_ph]         ; its own place in the table
        and  ax,15
        mov  bx,ax
        mov  al,[FL_H+bx]       ; its height now, 16ths of the cell
        mul  byte [cell]        ; AX = height * cell
        mov  cl,4
        shr  ax,cl              ; / 16: in pixels
        or   ax,ax
        jz   .r                 ; no flame (never a divide by 0 below)
        mov  [fl_h],ax
        mov  ax,[fstep]
        shr  ax,1               ; its lean, half as quick
        add  al,[fl_ph]
        add  al,5               ; out of step with its height
        and  ax,15
        mov  bx,ax
        mov  al,[FL_S+bx]       ; -2..2 pixels at its tip, at 16
        cbw
        imul word [cell]        ; AX = lean * cell  (DX goes)
        mov  cl,4
        sar  ax,cl              ; / 16
        mov  [fl_s],ax
        xor  si,si              ; SI: the row, from the cup up
.row:   cmp  si,[fl_h]
        jae  .r
        mov  ax,si
        mov  cl,4
        shl  ax,cl              ; row * 16
        xor  dx,dx
        div  word [fl_h]        ; how far up, 16ths (0..15; fl_h > 0)
        mov  [fl_v],ax
        mov  bx,ax
        mov  al,[FL_W+bx]       ; its half-width there, 32nds of the cell
        mul  byte [cell]        ; AX = half-width * cell
        mov  cl,5
        shr  ax,cl              ; / 32: pixels
        mov  [fl_w],ax
        mov  ax,[fl_s]
        imul si                 ; lean * row  (DX goes)
        idiv word [fl_h]        ; / height: leaning more the higher
        add  ax,[fl_x0]
        mov  [fl_c],ax          ; the row's middle
        mov  cx,[fl_w]
        neg  cx                 ; CX: from its left edge...
.px:    cmp  cx,[fl_w]
        jg   .nr                ; ...to its right
        mov  ax,cx
        or   ax,ax
        jns  .a
        neg  ax                 ; |k|
.a:     mov  bx,ax
        shl  ax,1
        add  ax,bx              ; 3 * |k|: how far from the middle
        mov  bx,[fl_w]
        mov  dl,14              ; a thread of a flame: yellow,
        or   bx,bx
        jnz  .wd
        cmp  word [fl_v],12
        jb   .put
        mov  dl,12              ;  red at its tip
        jmp  .put
.wd:    mov  dl,15              ; its heart white,
        cmp  ax,bx
        jae  .y
        cmp  word [fl_v],8
        jb   .put
        mov  dl,14              ;  yellow higher up;
        jmp  .put
.y:     mov  dl,14              ; then yellow,
        shl  bx,1               ; 2 * half-width
        cmp  ax,bx
        jb   .put
        mov  dl,12              ; red at its edges
.put:   mov  al,dl
        mov  bx,[fl_c]
        add  bx,cx              ; x = middle + k
        mov  dx,[fl_y0]
        sub  dx,si              ; y = cup - row
        call PSET
        inc  cx
        jmp  .px
.nr:    inc  si
        jmp  .row
.r:     pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
; the tables: the height a frame (16ths of the cell), the lean (pixels at
; 16), the half-width going up (32nds of the cell)
FL_H    db 7,7,8,7,6,7,8,8,7,6,6,7,8,7,7,6
FL_S    db 0,1,1,2,1,0,-1,-1,0,1,0,-1,-2,-1,0,0
FL_W    db 3,4,4,4,4,3,3,3,2,2,2,2,1,1,1,0
fl_ph   db 0
fl_x0   dw 0
fl_y0   dw 0
fl_h    dw 0
fl_s    dw 0
fl_v    dw 0
fl_w    dw 0
fl_c    dw 0
