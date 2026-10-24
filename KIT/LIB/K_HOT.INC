; ============================================================================
;  K_HOT.INC - KIT: hotspots - the things on a point-and-click screen, which
;  one a click is on, which must still be taken.
;
;  A table of things, HOT_SIZE (12) bytes each, in the order they are drawn
;  (the last is on top):
;     +0  dw x        +2  dw y        +4  dw width    +6  dw height
;     +8  dw sprite   a compiled K_SPR sprite (db w,h, w*h bytes, 255 the
;                     hole), or 0: a plain rectangle, solid all over
;    +10  db flags    HOT_LOADED 1 (it is there), HOT_TAKEN 2, HOT_NEEDED 4
;    +11  db user     yours (a slot number, a name index...)
;
;        items  db 3*HOT_SIZE dup(0)
;        mov  di,items                   ; thing 0
;        mov  si,keyc                    ; its compiled sprite
;        mov  bx,40                      ; x
;        mov  dx,60                      ; y
;        call HOT_PUT                    ; size from the sprite, LOADED
;        ...
;        mov  si,items
;        mov  cx,3
;        call HOT_NEEDALL                ; every one must be taken
;        ...a click at AX,DX:
;        call HOT_HIT                    ; BX = the thing, CF = 1 nothing
;        jc   .miss
;        call HOT_TAKE                   ; BX taken
;        call HOT_ALLTAKEN               ; CF = 1: the room is done
;
;  Every call takes SI = the table, CX = how many things are in it.
; ============================================================================

HOT_SIZE   = 12                 ; bytes a thing
HOT_X      = 0
HOT_Y      = 2
HOT_W      = 4
HOT_H      = 6
HOT_SPR    = 8
HOT_FLAGS  = 10
HOT_USER   = 11
HOT_LOADED = 1                  ; flags: it is there to be drawn and clicked
HOT_TAKEN  = 2                  ;  taken: not drawn, not clicked
HOT_NEEDED = 4                  ;  must be taken before the screen is done

if used hot_maxy
hot_maxy dw 200                 ; HOT_HIT: a click at y >= this hits nothing
hot_how  db 0                   ; HOT_HIT's answer came from pass 1 or 2
end if

; ----------------------------------------------------------------------
;@ HOT_ENTRY  DI = the address of thing BX in the table SI
;  in:  SI = the table, BX = the thing's number (0 = the first)
;  out: DI = SI + BX * HOT_SIZE
;  needs: -
;  from: new
; ----------------------------------------------------------------------
if used HOT_ENTRY
HOT_ENTRY:
        push ax
        mov  ax,bx
        shl  ax,1               ; n*2
        add  ax,bx              ; n*3
        shl  ax,1               ; n*6
        shl  ax,1               ; n*12
        add  ax,si              ; + the table
        mov  di,ax
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ HOT_PUT    fill thing DI from a compiled sprite at (BX,DX): size from it, LOADED
;  in:  DI = the thing's entry, SI = the compiled sprite (or 0, then CX =
;       width and AX = height of a plain rectangle), BX = x, DX = y
;  out: - (flags = HOT_LOADED, user = 0)
;  needs: K_SPR's SPR_COMPILE made the sprite
;  from: new (STORY.ASM LOADSPR filled ITEMTAB from a .SPR header)
; ----------------------------------------------------------------------
if used HOT_PUT
HOT_PUT:
        push ax
        push cx
        mov  [di+HOT_X],bx
        mov  [di+HOT_Y],dx
        mov  [di+HOT_SPR],si
        test si,si
        jz   .rect
        xor  ah,ah
        mov  al,[si]            ; the sprite's width
        mov  cx,ax
        mov  al,[si+1]          ; its height
.rect:  mov  [di+HOT_W],cx
        mov  [di+HOT_H],ax
        mov  word [di+HOT_FLAGS],HOT_LOADED ; flags, and user = 0
        pop  cx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ HOT_HIT    which thing is at (AX,DX)? Its pixels first, last drawn first; then its box
;  in:  AX = x, DX = y, SI = the table, CX = things; [hot_maxy]
;  out: BX = the thing, CF = 0; CF = 1 nothing there (BX kept).
;       [hot_how] = 1 hit by an opaque pixel within 3 of the point, 2 by
;       the rectangle only
;  needs: only LOADED and not TAKEN things count
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:1211-1286 HITTEST, ported to 8086:
;        two passes, the last drawn first: (1) a thing with an opaque
;        pixel within +-3 of the point, so where two overlap the one
;        really under it wins; (2) a thing whose rectangle holds it - the
;        clear middle of a glass ashtray is still the ashtray
; ----------------------------------------------------------------------
if used HOT_HIT
HOT_HIT:
        cmp  dx,[hot_maxy]
        jl   .go
        mov  byte [hot_how],0
        stc                     ; the panel, not the room
        ret
.go:    push ax
        push cx
        push dx
        push si
        push di
        push bp
        push bx
        mov  [hot_px],ax
        mov  [hot_py],dx
        mov  [hot_n],cx
        mov  byte [hot_how],1
.pass:  mov  cx,[hot_n]
.thing: jcxz .again             ; none left in this pass
        dec  cx                 ; from the last drawn back
        mov  bx,cx
        call HOT_ENTRY          ; DI = thing CX
        mov  al,[di+HOT_FLAGS]
        and  al,HOT_LOADED+HOT_TAKEN
        cmp  al,HOT_LOADED      ; there, not taken
        jne  .thing
        mov  ax,[hot_px]
        sub  ax,[di+HOT_X]      ; AX = x within the thing
        jl   .thing
        cmp  ax,[di+HOT_W]
        jge  .thing
        mov  dx,[hot_py]
        sub  dx,[di+HOT_Y]      ; DX = y within the thing
        jl   .thing
        cmp  dx,[di+HOT_H]
        jge  .thing
        cmp  byte [hot_how],2   ; pass 2: the rectangle is enough
        je   .hit
        mov  bp,[di+HOT_SPR]
        test bp,bp
        jz   .hit               ; no sprite: solid all over
        call HOT_NEAR           ; CF = 1 an opaque pixel within 3
        jc   .hit
        jmp  .thing
.again: cmp  byte [hot_how],2
        je   .none
        mov  byte [hot_how],2
        jmp  .pass
.hit:   pop  bx                 ; the caller's BX is not wanted back
        mov  bx,cx              ; BX = the thing
        clc
        jmp  .out
.none:  mov  byte [hot_how],0
        pop  bx
        stc
.out:   pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  ax
        ret
end if

if used hot_px
hot_px  dw 0                    ; HOT_HIT: the point
hot_py  dw 0
hot_n   dw 0                    ; the things in the table
end if

; ---- HOT_NEAR (inside the kit): is there an opaque pixel of sprite BP
;  within +-3 of (AX,DX), sprite coordinates, inside DI's W x H? CF = 1
;  yes. Every register kept.
if used HOT_NEAR
HOT_NEAR:
        push ax
        push bx
        push cx
        push dx
        push si
        mov  [hot_cx],ax
        mov  [hot_cy],dx
        mov  si,-3              ; SI = dy
.dy:    mov  bx,-3              ; BX = dx
.dx:    mov  ax,[hot_cx]
        add  ax,bx              ; AX = column looked at
        jl   .next
        cmp  ax,[di+HOT_W]
        jge  .next
        mov  dx,[hot_cy]
        add  dx,si              ; DX = row looked at
        jl   .next
        cmp  dx,[di+HOT_H]
        jge  .next
        push ax
        mov  al,dl
        mul  byte [ds:bp]       ; AX = row * the sprite's own width (bytes)
        mov  cx,ax
        pop  ax
        add  cx,ax              ; + the column
        add  cx,bp              ; + the sprite's address
        add  cx,2               ; past its w,h
        push bx
        mov  bx,cx
        cmp  byte [bx],255      ; the hole?
        pop  bx
        jne  .yes
.next:  inc  bx                 ; the next dx
        cmp  bx,3
        jle  .dx
        inc  si                 ; the next dy
        cmp  si,3
        jle  .dy
        clc
        jmp  .out
.yes:   stc
.out:   pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

if used hot_cx
hot_cx  dw 0                    ; HOT_NEAR: the point within the thing
hot_cy  dw 0
end if

; ----------------------------------------------------------------------
;@ HOT_TAKE   mark thing BX taken (no longer drawn or clicked)
;  in:  SI = the table, BX = the thing
;  out: -
;  needs: -
;  from: STORY.ASM TAKE (its flag bit 2)
; ----------------------------------------------------------------------
if used HOT_TAKE
HOT_TAKE:
        push di
        call HOT_ENTRY
        or   byte [di+HOT_FLAGS],HOT_TAKEN
        pop  di
        ret
end if

; ----------------------------------------------------------------------
;@ HOT_NEEDALL mark every LOADED thing NEEDED (a screen with no NEED list)
;  in:  SI = the table, CX = things
;  out: -
;  needs: mark single ones NEEDED yourself: or byte [di+HOT_FLAGS],HOT_NEEDED
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:975-1004 MARKNEED (MNALL: no NEED
;        line, everything is needed)
; ----------------------------------------------------------------------
if used HOT_NEEDALL
HOT_NEEDALL:
        push bx
        push cx
        push di
        mov  di,si
        jcxz .out
.l:     test byte [di+HOT_FLAGS],HOT_LOADED
        jz   .n                 ; not loaded: never needed
        or   byte [di+HOT_FLAGS],HOT_NEEDED
.n:     add  di,HOT_SIZE        ; the next thing
        loop .l
.out:   pop  di
        pop  cx
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ HOT_NEXTWANTED BX = the first thing that is needed, there and not taken yet
;  in:  SI = the table, CX = things
;  out: BX = the thing, CF = 0; CF = 1 none left (BX kept)
;  needs: -
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:1288-1305 NEXTWANTED
; ----------------------------------------------------------------------
if used HOT_NEXTWANTED
HOT_NEXTWANTED:
        push ax
        push dx
        push di
        mov  di,si
        xor  dx,dx              ; DX = the number
.l:     cmp  dx,cx
        jae  .no
        mov  al,[di+HOT_FLAGS]
        and  al,HOT_LOADED+HOT_TAKEN+HOT_NEEDED
        cmp  al,HOT_LOADED+HOT_NEEDED ; loaded, needed, not taken
        je   .yes
        add  di,HOT_SIZE        ; the next thing
        inc  dx                 ; its number
        jmp  .l
.yes:   mov  bx,dx
        clc
        jmp  .out
.no:    stc
.out:   pop  di
        pop  dx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ HOT_ALLTAKEN every needed thing taken?  CF = 1 yes
;  in:  SI = the table, CX = things
;  out: CF = 1 all taken (the screen is done), CF = 0 some still wanted
;  needs: HOT_NEEDALL or your own NEEDED marks first (none needed: done)
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:1307-1315 ALLTAKEN
; ----------------------------------------------------------------------
if used HOT_ALLTAKEN
HOT_ALLTAKEN:
        push bx
        call HOT_NEXTWANTED
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ HOT_CENTRE AX,DX = the middle of thing BX, kept on the screen and above [hot_maxy]
;  in:  SI = the table, BX = the thing
;  out: AX = x, DX = y (where the keyboard or /AUTO puts the pointer)
;  needs: -
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:1317-1341 CENTRE
; ----------------------------------------------------------------------
if used HOT_CENTRE
HOT_CENTRE:
        push di
        call HOT_ENTRY
        mov  ax,[di+HOT_W]
        shr  ax,1               ; half the width
        add  ax,[di+HOT_X]      ; + left = the middle
        mov  dx,[di+HOT_H]
        shr  dx,1               ; half the height
        add  dx,[di+HOT_Y]      ; + top
        cmp  ax,0
        jge  .a
        xor  ax,ax
.a:     cmp  ax,319
        jle  .b
        mov  ax,319
.b:     cmp  dx,0
        jge  .c
        xor  dx,dx
.c:     mov  di,[hot_maxy]
        dec  di                 ; the last row of the room
        cmp  dx,di
        jle  .d
        mov  dx,di
.d:     pop  di
        ret
end if

; ----------------------------------------------------------------------
;@ HOT_DRAW   draw every thing that is there and not taken, in table order
;  in:  ES = the screen or buffer, SI = the table, CX = things
;  out: -
;  needs: K_SPR.INC included (SPR_DRAW); a thing with sprite 0 is not drawn
;  from: STORY.ASM DRAWALL
; ----------------------------------------------------------------------
if used HOT_DRAW
HOT_DRAW:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        mov  di,si
        jcxz .out
.l:     mov  al,[di+HOT_FLAGS]
        and  al,HOT_LOADED+HOT_TAKEN
        cmp  al,HOT_LOADED
        jne  .n
        mov  si,[di+HOT_SPR]
        test si,si
        jz   .n
        mov  bx,[di+HOT_X]
        mov  dx,[di+HOT_Y]
        call SPR_DRAW
.n:     add  di,HOT_SIZE        ; the next thing
        loop .l
.out:   pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if
