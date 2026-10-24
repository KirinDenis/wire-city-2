; R_BGTWO.ASM - the still background drawn ONCE in two passes, copied under what moves (mode 13h)
; ============================================================================
;  Recipe: copy after your program's way out (or include it there).
;  What does not move is drawn once per level and view into a background
;  buffer of its own: every cell's GROUND first (pass 0: grass, stone,
;  floor, the first frame of the water), then every cell's UPRIGHT thing
;  (pass 1: trees, walls' growth, statues), row by row, top row first, so
;  a thing lower on the screen covers what stands behind it. Each upright
;  picture stands on its cell's bottom row (y + cell - height): a tall tree
;  rises over the cell above. Two rows past the screen's bottom are walked
;  too - a tall thing below the edge reaches up into the screen.
;  Each frame: BGCOPY the background into the frame buffer, then draw what
;  moves over it (water cells, flames, fountains, creatures, the owl), then
;  show the frame. A frame is drawn only when something changed (R_CLOCK).
;  While walking, the program lists what must be drawn every frame (water
;  cells with their phase, torches, fountains, life) - BGGROUND/BGTHING are
;  the place to do it.
;  Mode 13h: a buffer is 64000 bytes, a segment of its own - take two from
;  DOS (INT 21h 4Ah shrink the .COM to 64K, then 48h BX=4000 twice).
; ============================================================================

; ----------------------------------------------------------------------
;@ BGBUILD    draw the background once: every cell's ground, then its upright thing
;  in:  ES = the background buffer; [bg_ox] [bg_oy] = the screen place of
;       cell (0, 0); [bg_cols] [bg_rows] = cells to walk (add 2 rows for
;       tall things below the edge); [cell] dw
;  out: -
;  needs: the program's BGGROUND and BGTHING - in: CX = column, DX = row;
;       out: SI = a text-art picture to draw there, or 0 - each may change
;       AX BX CX DX DI, and must keep ES, BP, DS;
;       DRAWTXT (SI picture at BX, DX, see-through, clipped, keeps all)
;  from: GAMES\MULTSOK2\SCENE.INC BUILDBG 440-513 (the two passes, proven)
; ----------------------------------------------------------------------
BGBUILD:push ax
        push bx
        push cx
        push dx
        push si
        push di
        xor  di,di              ; the buffer black first
        xor  ax,ax
        mov  cx,32000
        cld
        rep  stosw
        mov  byte [bg_pass],0
.pass:  xor  dx,dx              ; DX = the row
.row:   xor  cx,cx              ; CX = the column
.cell:  push cx
        push dx
        xor  si,si
        cmp  byte [bg_pass],0
        jne  .up
        call BGGROUND           ; pass 0: the ground
        jmp  .got
.up:    call BGTHING            ; pass 1: what stands on it
.got:   pop  dx
        pop  cx
        or   si,si
        jz   .no
        push dx                 ; (the row: MUL takes DX)
        mov  ax,cx
        mul  word [cell]        ; column * cell  (DX goes)
        add  ax,[bg_ox]
        mov  bx,ax              ; BX = x
        pop  ax
        push ax                 ; AX = the row
        mul  word [cell]        ; row * cell
        add  ax,[bg_oy]
        add  ax,[cell]          ; the cell's bottom...
        mov  dl,[si+1]
        xor  dh,dh
        sub  ax,dx              ; ...less the picture's height: it stands
        mov  dx,ax              ; DX = y
        call DRAWTXT
        pop  dx
.no:    inc  cx
        cmp  cx,[bg_cols]
        jb   .cell
        inc  dx
        cmp  dx,[bg_rows]
        jb   .row
        inc  byte [bg_pass]
        cmp  byte [bg_pass],2
        jb   .pass
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; ----------------------------------------------------------------------
;@ BGCOPY     the background under the frame: copy segment AX to segment ES
;  in:  AX = the background buffer's segment, ES = the frame buffer's
;  out: -
;  needs: -
;  from: GAMES\MULTSOK2\SCENE.INC RENDER / COPYBG 1469-1495 (13h: 64000 bytes)
; ----------------------------------------------------------------------
BGCOPY: push cx
        push si
        push di
        push ds
        mov  ds,ax
        xor  si,si
        xor  di,di
        mov  cx,32000           ; 64000 bytes, a word at a time
        cld
        rep  movsw
        pop  ds
        pop  di
        pop  si
        pop  cx
        ret

bg_ox   dw 0                    ; the screen place of cell (0, 0)
bg_oy   dw 0
bg_cols dw 20                   ; cells to walk
bg_rows dw 13
bg_pass db 0
