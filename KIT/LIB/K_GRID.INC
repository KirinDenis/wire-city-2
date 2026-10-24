; ============================================================================
;  K_GRID.INC - KIT: the grid of a tile game - a byte a cell, a bit a thing.
;
;  The grid is the truth (guide TILES): walls, goals, crates, the man, the
;  floor are bits of one byte per cell; the picture, the sound and the
;  packets are made from it. The rows are 32 bytes wide whatever the level's
;  width, so a cell is row*32 + column - shifts, never a multiply - and a
;  step is a fixed delta: up -32, right +1, down +32, left -1. A zero row
;  sits before the grid and after it, and column 31 is never part of a
;  level, so the neighbours of an edge cell read 0 with no bounds test.
;
;  A CELL is an index 0..1023 (row*32 + column) in a register - never a
;  pointer; the byte is [grd_map+bx]. A level is up to 31 wide, 32 high.
;
;        mov  si,LEVEL1          ; db 7,5 then 5 rows of 7: '#######' ...
;        xor  di,di              ; DI = 0: the Sokoban letters
;        call GRD_LOAD           ; walls, crates, goals, the man (grd_start)
;        mov  bx,[grd_start]
;        mov  ax,GRD_WALL*256 + GRD_FLOOR
;        call GRD_FLOOD          ; GRD_FLOOR on all he can reach
;
;  The bits (a game may give them its own names: WALL = GRD_WALL):
GRD_WALL  = 1                   ; a wall: nothing enters
GRD_GOAL  = 2                   ; a goal / mark / exit
GRD_BOX   = 4                   ; a crate (or any pushable thing)
GRD_FLOOR = 8                   ; inside the walls: GRD_FLOOD's mark
GRD_MAN   = 16                  ; a man (or any mover) stands here
GRD_SEEN  = 32                  ; RESERVED: the searches mark with it, then clear it
GRD_ITEM  = 64                  ; a candy, a coin, a key...
GRD_OUT   = 128                 ; free for the game (MULTSOK2: outside the walls)
GRD_ROW   = 32                  ; the row stride, bytes
GRD_CELLS = 32*32               ; cells in the grid
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:35-43 (the bits), 846-909 (LOADLEV),
;        1075-1122 (FREECELL), 1220-1247 (FLOOD), 3226-3230 (DIRKEYS/DSTEP)
;  Guide topic TILES.
; ============================================================================

; the grid itself: a zero row, 32 rows of 32, a zero row
if used grd_map
grd_pad  rb GRD_ROW             ; row -1: reads 0
grd_map  rb GRD_CELLS           ; THE GRID: [grd_map + row*32 + column]
grd_tail rb GRD_ROW             ; row 32: reads 0
end if
if used grd_w
grd_w    db 0                   ; the level's width, columns (1..31)
end if
if used grd_h
grd_h    db 0                   ; the level's height, rows (1..32)
end if
if used grd_start
grd_start dw 0FFFFh             ; GRD_LOAD: the first cell with GRD_MAN
end if
if used grd_nbox
grd_nbox  dw 0                  ; GRD_LOAD: crates in the level
end if
if used grd_ngood
grd_ngood dw 0                  ; GRD_LOAD: crates already on a goal
end if
if used grd_dstep
grd_dstep dw -GRD_ROW, 1, GRD_ROW, -1   ; a step per direction: 0 up 1 right 2 down 3 left
end if

; ----------------------------------------------------------------------
;@ GRD_CLEAR  empty the whole grid (and its zero rows): every cell 0
;  in:  -
;  out: -
;  needs: -
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:846-849 (LOADLEV's first lines)
; ----------------------------------------------------------------------
if used GRD_CLEAR
GRD_CLEAR:
        push ax
        push cx
        push di
        push es
        push ds
        pop  es                 ; ES = DS: the grid is ours
        mov  di,grd_map-GRD_ROW ; from the zero row in front
        mov  cx,(GRD_CELLS+2*GRD_ROW)/2  ; words: the grid and both zero rows
        xor  ax,ax
        cld
        rep  stosw              ; all zero
        pop  es
        pop  di
        pop  cx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ GRD_INSIDE CF=1 if cell BX is off the level (outside grd_w x grd_h)
;  in:  BX = a cell, any value (negative ones are off)
;  out: CF = 1 off the level, 0 inside it
;  needs: grd_w, grd_h set (GRD_LOAD does it)
;  from: new
; ----------------------------------------------------------------------
if used GRD_INSIDE
GRD_INSIDE:
        push ax
        cmp  bx,GRD_CELLS       ; UNSIGNED: a negative cell is huge
        jae  .off
        mov  al,bl
        and  al,GRD_ROW-1       ; AL = the column: the low 5 bits
        cmp  al,[grd_w]
        jae  .off
        mov  ax,bx
        shl  ax,1               ; AX = cell*2
        shl  ax,1               ; cell*4
        shl  ax,1               ; cell*8: AH = cell/32, the row
        cmp  ah,[grd_h]
        jae  .off
        pop  ax
        clc                     ; inside
        ret
.off:   pop  ax
        stc                     ; off the level
        ret
end if

; ----------------------------------------------------------------------
;@ GRD_AT     AL = the bits of cell BX; off the level it reads as a wall
;  in:  BX = a cell, any value
;  out: AL = its bits (GRD_WALL for a cell off the level)
;  needs: grd_w, grd_h set
;  from: new (the safe read MULTSOK2 gets from its zero rows)
; ----------------------------------------------------------------------
if used GRD_AT
GRD_AT: call GRD_INSIDE
        jc   .off
        mov  al,[grd_map+bx]    ; AL = the cell's bits
        ret
.off:   mov  al,GRD_WALL        ; off the map: a wall
        ret
end if

; ----------------------------------------------------------------------
;@ GRD_SET    set the bits AL in cell BX (nothing if BX is off the grid)
;  in:  BX = a cell, AL = the bits to set
;  out: -
;  needs: -
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:1726 (or byte [bp],G_BOX)
; ----------------------------------------------------------------------
if used GRD_SET
GRD_SET:cmp  bx,GRD_CELLS       ; unsigned: off the grid?
        jae  .r
        or   [grd_map+bx],al    ; the bits on
.r:     ret
end if

; ----------------------------------------------------------------------
;@ GRD_CLR    clear the bits AL in cell BX (nothing if BX is off the grid)
;  in:  BX = a cell, AL = the bits to clear
;  out: -
;  needs: -
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:1725 (and byte [bx],0FFh xor G_BOX)
; ----------------------------------------------------------------------
if used GRD_CLR
GRD_CLR:cmp  bx,GRD_CELLS       ; unsigned: off the grid?
        jae  .r
        not  al                 ; AL = every bit but those
        and  [grd_map+bx],al    ; the bits off
        not  al                 ; AL back as it came
.r:     ret
end if

; ----------------------------------------------------------------------
;@ GRD_CELL   BX = the cell of column AL, row AH (row*32 + column)
;  in:  AL = column 0..31, AH = row 0..31
;  out: BX = the cell
;  needs: -
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:1680-1684 (row*32 + column)
; ----------------------------------------------------------------------
if used GRD_CELL
GRD_CELL:
        push cx
        mov  bl,ah
        xor  bh,bh              ; BX = the row
        mov  cl,5
        shl  bx,cl              ; BX = row*32
        mov  cl,al
        xor  ch,ch              ; CX = the column
        add  bx,cx              ; BX = row*32 + column
        pop  cx
        ret
end if

; ----------------------------------------------------------------------
;@ GRD_XY     AL = column, AH = row of cell BX
;  in:  BX = a cell 0..1023
;  out: AL = column, AH = row
;  needs: -
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:1202-1210 (SETPOS)
; ----------------------------------------------------------------------
if used GRD_XY
GRD_XY: mov  ax,bx
        shl  ax,1               ; cell*2
        shl  ax,1               ; cell*4
        shl  ax,1               ; cell*8: AH = cell/32, the row
        mov  al,bl
        and  al,GRD_ROW-1       ; AL = the low 5 bits: the column
        ret
end if

; ----------------------------------------------------------------------
;@ GRD_STEP   DX = the cell delta of direction AL (0 up 1 right 2 down 3 left)
;  in:  AL = direction (only its low 2 bits count)
;  out: DX = -32, +1, +32 or -1
;  needs: -
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:3230 (DSTEP), 1663-1667 (MOVE)
; ----------------------------------------------------------------------
if used GRD_STEP
GRD_STEP:
        push bx
        mov  bl,al
        and  bx,3               ; BX = the direction 0..3 (BH cleared too)
        shl  bx,1               ; a word per direction
        mov  dx,[grd_dstep+bx]  ; DX = the step
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ GRD_KEYDIR AL = the direction of scan code AH: arrows and W A S D
;  in:  AH = a scan code (INT 16h AH=0 gives it in AH; K_KEYS' too)
;  out: AL = 0 up 1 right 2 down 3 left, CF=0; CF=1 not a walking key
;  needs: -
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:3226-3229 (DIRKEYS)
;  A view turned by T quarter turns: dir = (AL - T) AND 3 (guide TILES).
; ----------------------------------------------------------------------
if used GRD_KEYDIR
GRD_KEYDIR:
        push bx
        mov  bx,grd_dirkeys
.k:     cmp  byte [bx],0
        je   .no                ; the table's end: not ours
        cmp  [bx],ah
        je   .yes
        add  bx,2               ; the next pair
        jmp  .k
.yes:   mov  al,[bx+1]          ; AL = its direction
        pop  bx
        clc
        ret
.no:    pop  bx
        stc
        ret
grd_dirkeys db 48h,0, 11h,0     ; Up, W
        db 4Dh,1, 20h,1         ; Right, D
        db 50h,2, 1Fh,2         ; Down, S
        db 4Bh,3, 1Eh,3         ; Left, A
        db 0
end if

; ----------------------------------------------------------------------
;@ GRD_UNSEE  clear the GRD_SEEN bit in every cell (the searches do it)
;  in:  -
;  out: -
;  needs: -
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:1115-1122 (FREECELL .unsee)
; ----------------------------------------------------------------------
if used GRD_UNSEE
GRD_UNSEE:
        push bx
        mov  bx,GRD_CELLS-1
.u:     and  byte [grd_map+bx],0FFh xor GRD_SEEN
        dec  bx                 ; the cell before
        jns  .u
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ GRD_FLOOD  set bit AL on every cell reachable from cell BX (AH bits block)
;  in:  BX = the start cell, AL = the bit to spread (GRD_FLOOR),
;       AH = the bits that stop it (GRD_WALL)
;  out: -  (the start gets AL even if it is blocked)
;  needs: grd_w, grd_h set; the level inside its walls (or the floor runs
;         to the level's edge, never further)
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:1220-1247 (FLOOD: passes until one adds
;        nothing - slow on a big open map, a few passes on a maze level)
; ----------------------------------------------------------------------
if used GRD_FLOOD
GRD_FLOOD:
        push bx
        push cx
        push dx
        push si
        or   [grd_map+bx],al    ; the start
        cmp  byte [grd_w],0
        je   .r                 ; no level: nothing to walk
        cmp  byte [grd_h],0
        je   .r
        mov  cl,al
        or   cl,ah              ; CL = done or blocked: skip such a cell
.pass:  xor  ch,ch              ; CH = 1 when this pass added a cell
        mov  si,grd_map
        mov  dh,[grd_h]         ; rows to go
.row:   push si
        mov  dl,[grd_w]         ; columns to go
.col:   test [si],cl
        jnz  .next              ; a wall, or flooded already
        mov  bl,[si-1]
        or   bl,[si+1]
        or   bl,[si-GRD_ROW]
        or   bl,[si+GRD_ROW]    ; the four neighbours' bits together
        test bl,al
        jz   .next              ; none of them flooded
        or   [si],al            ; this one too
        mov  ch,1
.next:  inc  si                 ; the next column
        dec  dl                 ; one column fewer to go
        jnz  .col
        pop  si
        add  si,GRD_ROW         ; the next row
        dec  dh                 ; one row fewer to go
        jnz  .row
        or   ch,ch
        jnz  .pass              ; it grew: once more
.r:     pop  si
        pop  dx
        pop  cx
        pop  bx
        ret
end if

; the searches' private words
if used GRD_BFS | used GRD_PATH
grd_bw   dw 0                   ; GRD_BFS: want mask (low), want value (high)
grd_bk   dw 0                   ; walk bits (low), block bits (high)
grd_pfrom dw 0                  ; GRD_PATH: the cell it starts from
grd_pk   db 0                   ; GRD_PATH: the direction being tried
; grd_near - BX + DX: may the search enter it? CF=1 no. A yes marks it
; GRD_SEEN and queues it at DI (DI += 2). Keeps all but DI and the flags.
grd_near:
        push ax
        push bx
        add  bx,dx              ; BX = the neighbour
        call GRD_INSIDE
        jc   .no                ; off the level
        mov  al,[grd_map+bx]
        test al,GRD_SEEN
        jnz  .no                ; queued already
        test al,byte [grd_bk+1]
        jnz  .no                ; a blocking thing on it
        mov  ah,byte [grd_bk]
        or   ah,ah
        jz   .yes               ; no walk bits asked: any free cell
        test al,ah
        jz   .no                ; not floor (or whatever walking needs)
.yes:   or   byte [grd_map+bx],GRD_SEEN
        mov  [di],bx            ; queued
        add  di,2               ; the queue's tail moves on
        pop  bx
        pop  ax
        clc
        ret
.no:    pop  bx
        pop  ax
        stc
        ret
end if

; ----------------------------------------------------------------------
;@ GRD_BFS    nearest cell from BX whose bits AND AL equal AH, and its distance
;  in:  BX = the start cell, AL = mask, AH = value: found when
;       (bits AND AL) = AH (GRD_GOAL,GRD_GOAL: a goal; FREECELL's free floor
;       is AL = GRD_WALL+GRD_BOX+GRD_MAN, AH = 0); DL = walk bits: a cell is
;       entered only if it has one of them (0 = any); DH = block bits: never
;       entered if it has one; SI -> a queue, 2 bytes a cell (2048 is always
;       enough)
;  out: CF=0 BX = the cell found, CX = its distance in steps (0: the start);
;       CF=1 none reachable (BX, CX as they came)
;  needs: grd_w, grd_h set; GRD_SEEN unused by the game
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:1075-1122 (FREECELL), the ring count new
; ----------------------------------------------------------------------
if used GRD_BFS
GRD_BFS:push ax
        push dx
        push si
        push di
        push bp
        push bx
        push cx
        mov  [grd_bw],ax
        mov  [grd_bk],dx
        mov  di,si              ; DI: the queue's tail, SI: its head
        or   byte [grd_map+bx],GRD_SEEN
        mov  [di],bx            ; the start, queued
        add  di,2               ; tail on
        xor  cx,cx              ; CX = the ring being taken: distance 0
        mov  bp,di              ; BP = the end of this ring in the queue
.take:  cmp  si,di
        jae  .none              ; all walked, none found
        cmp  si,bp
        jb   .same
        inc  cx                 ; past the ring's end: one step further
        mov  bp,di              ; the next ring ends where the tail is now
.same:  mov  bx,[si]            ; BX = the next cell
        add  si,2               ; head on
        mov  al,[grd_map+bx]
        and  al,byte [grd_bw]        ; its bits under the mask
        cmp  al,byte [grd_bw+1]
        je   .found
        mov  dx,-GRD_ROW        ; its neighbours: up,
        call grd_near
        mov  dx,1               ;  right,
        call grd_near
        mov  dx,GRD_ROW         ;  down,
        call grd_near
        mov  dx,-1              ;  left
        call grd_near
        jmp  .take
.found: call GRD_UNSEE
        add  sp,4               ; drop the CX and BX that came in
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  ax
        clc
        ret
.none:  call GRD_UNSEE
        pop  cx
        pop  bx
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  ax
        stc
        ret
end if

; ----------------------------------------------------------------------
;@ GRD_PATH   the first step from cell BX toward cell DI by a shortest path
;  in:  BX = from (an enemy), DI = to (the player); DL = walk bits, DH =
;       block bits (as GRD_BFS; the two end cells are never tested);
;       SI -> a queue, 2 bytes a cell (2048 is always enough)
;  out: CF=0 AX = the direction 0..3 to step from BX (0FFh: BX = DI already),
;       CX = the path's length in steps; CF=1 no path (AX, CX destroyed)
;  needs: grd_w, grd_h set; GRD_SEEN unused by the game
;  from: new - GRD_BFS run from the TARGET: the first time it touches the
;        start, the cell it came from is the start's next step (the same
;        answer as parent links, without storing them)
; ----------------------------------------------------------------------
if used GRD_PATH
GRD_PATH:
        push bx
        push dx
        push si
        push di
        push bp
        xor  cx,cx
        mov  ax,0FFh            ; "here already"
        cmp  bx,di
        je   .ok                ; from = to: no step, distance 0
        mov  [grd_bk],dx
        mov  [grd_pfrom],bx
        mov  bx,di              ; the search begins at the target
        mov  di,si              ; DI: the tail, SI: the head
        or   byte [grd_map+bx],GRD_SEEN
        mov  [di],bx
        add  di,2               ; tail on
        mov  bp,di              ; the end of ring 0
.take:  cmp  si,di
        jae  .none
        cmp  si,bp
        jb   .same
        inc  cx                 ; the next ring: one step further
        mov  bp,di
.same:  mov  bx,[si]            ; BX = a cell CX steps from the target
        add  si,2               ; head on
        mov  byte [grd_pk],0
        mov  dx,-GRD_ROW        ; up
        call .near
        jc   .hit
        mov  byte [grd_pk],1
        mov  dx,1               ; right
        call .near
        jc   .hit
        mov  byte [grd_pk],2
        mov  dx,GRD_ROW         ; down
        call .near
        jc   .hit
        mov  byte [grd_pk],3
        mov  dx,-1              ; left
        call .near
        jc   .hit
        jmp  .take
.hit:   inc  cx                 ; the start is one ring further out
        mov  al,[grd_pk]        ; BX -> start was this way,
        add  al,2               ;  so start -> BX is the opposite one
        and  ax,3               ; AX = 0..3 (AH = 0)
        call GRD_UNSEE
.ok:    pop  bp
        pop  di
        pop  si
        pop  dx
        pop  bx
        clc
        ret
.none:  call GRD_UNSEE
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  bx
        stc
        ret
; .near - CF=1: BX+DX is the start; else queue it if it may be walked
.near:  push bx
        add  bx,dx              ; BX = the neighbour
        cmp  bx,[grd_pfrom]
        pop  bx
        je   .isst
        call grd_near           ; (its CF is not ours: the start was not met)
        clc
        ret
.isst:  stc
        ret
end if

; ----------------------------------------------------------------------
;@ GRD_LOAD   a level from text: db width, height, then the rows' letters
;  in:  SI -> db w, h, then h rows of w letters (no line ends) - the
;       format of MULTSOK2's LEVELS.INC; DI -> the letters' table: pairs
;       db letter, bits ... db 0 - or DI = 0 for Sokoban's: # wall, $ crate,
;       . goal, * crate on a goal, @ man, + man on a goal; any other letter
;       (space, - _) is an empty cell
;  out: CF=1 too big (w > 31, h > 32) or empty - the grid is cleared;
;       CF=0 grd_w, grd_h, grd_start (the first cell with GRD_MAN, 0FFFFh
;       none), grd_nbox, grd_ngood (crates, crates on a goal) set
;  needs: then GRD_FLOOD from grd_start if the game wants GRD_FLOOR
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:846-909 (LOADLEV); the letter table new.
;        MULTSOK2 does not put G_MAN on the grid at load: the kit does.
; ----------------------------------------------------------------------
if used GRD_LOAD
GRD_LOAD:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        call GRD_CLEAR
        or   di,di
        jnz  .tab
        mov  di,grd_soko        ; no table given: Sokoban's letters
.tab:   xor  ax,ax
        mov  [grd_nbox],ax
        mov  [grd_ngood],ax
        mov  word [grd_start],0FFFFh
        mov  [grd_w],al
        mov  [grd_h],al         ; nothing yet, in case it is refused
        cld
        lodsb
        mov  dl,al              ; DL = the width
        lodsb
        mov  dh,al              ; DH = the height
        or   dl,dl
        jz   .bad
        cmp  dl,GRD_ROW-1
        ja   .bad               ; column 31 must stay empty
        or   dh,dh
        jz   .bad
        cmp  dh,32
        ja   .bad
        mov  [grd_w],dl
        mov  [grd_h],dh
        mov  bx,grd_map
        mov  ch,dh              ; CH = rows to go
.row:   push bx
        mov  cl,dl              ; CL = columns to go
.col:   lodsb                   ; AL = the letter
        call .look              ; AH = its bits
        mov  [bx],ah
        mov  al,ah
        and  al,GRD_BOX or GRD_GOAL
        cmp  al,GRD_BOX
        je   .box
        cmp  al,GRD_BOX or GRD_GOAL
        jne  .man
        inc  word [grd_ngood]   ; a crate home already
.box:   inc  word [grd_nbox]    ; one crate more
.man:   test ah,GRD_MAN
        jz   .nx
        cmp  word [grd_start],0FFFFh
        jne  .nx                ; the first man only
        mov  ax,bx
        sub  ax,grd_map         ; AX = the cell
        mov  [grd_start],ax
.nx:    inc  bx                 ; the next column
        dec  cl                 ; one column fewer to go
        jnz  .col
        pop  bx
        add  bx,GRD_ROW         ; the next grid row
        dec  ch                 ; one row fewer to go
        jnz  .row
        clc
        jmp  .r
.bad:   stc
.r:     pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
; .look - AH = the bits of letter AL from the table at DI (0: not in it)
.look:  push di
.l:     mov  ah,[di]
        or   ah,ah
        jz   .lr                ; the end: an empty cell, AH = 0
        cmp  ah,al
        je   .lf
        add  di,2               ; the next pair
        jmp  .l
.lf:    mov  ah,[di+1]          ; AH = its bits
.lr:    pop  di
        ret
grd_soko db '#',GRD_WALL, '$',GRD_BOX, '*',GRD_BOX or GRD_GOAL
        db '.',GRD_GOAL, '@',GRD_MAN, '+',GRD_MAN or GRD_GOAL
        db 0
end if
