; ==================================================================
;  SCENE.INC - MULTIPLAY SOKO II's picture of the warehouse.
;  Straight down the whole level fits on the screen: the biggest cell of
;  16, 12, 10, 8, 6 pixels that holds the turned level (VIEWSET); Z
;  shows it close up at 16, following your man; V isometric.
;  What does not move is drawn ONCE into the background (BUILDBG): the
;  walls with their growth, the park and its things, the goals.  What
;  moves or plays is drawn every frame over a copy of it (FRAME): the
;  water's ripples, the torches, the towers (they rise over the water),
;  the fountains, the gate and its bridge, then the candies, diamond,
;  mines, crates and men, the blasts and the counts, the crow, the HUD.
;  Grid cells are (c, r) - column, row; the turned grid's are (cc, rr),
;  as the screen shows them (TURNED, UNTURN).
; ==================================================================
CL_FLOOR = 0                    ; CLASS: what a cell is, for the picture
CL_WALL  = 1
CL_MOAT  = 2                    ; outside, next to a wall (eight ways)
CL_PARK  = 3                    ; outside: grass, and the park's things
CL_YARD  = 4                    ; shut in by the walls: grass, nothing on it
CL_ROAD  = 5                    ; from the gate's bridge to the edge
CLW     = 64                    ; the claims: a byte a screen cell
CLH     = 40
MAXWATER = 300
MAXTORCH = 32
MAXTOWER = 32
MAXFOUNT = 16

; ------------------------------------------------------------------
;  VIEWSET - the view for the level, the turn and the mode as they are
;  now: the size of a cell, the projection, a new camera, a new
;  background.  SETSZ - size SI (0..4 straight down, 5 isometric).
; ------------------------------------------------------------------
VIEWSET:call TURNED
        cmp  byte [view],2
        je   .iso
        xor  si,si              ; 16 px first
        cmp  byte [view],1
        je   .set               ; close up: always 16
.fit:   mov  bl,[SIZES+si]
        mov  al,[tcols]
        mul  bl                 ; the turned level's width at this size
        cmp  ax,320
        ja   .less
        mov  al,[trows]
        mul  bl
        cmp  ax,PFBOT-PFTOP     ; ...and its height
        jbe  .set
.less:  inc  si
        cmp  si,NSIZE-1
        jb   .fit               ; the last size is taken whatever it holds
.set:   call SETSZ
        jmp  .done
.iso:   mov  si,5
        call SETSZ
.done:  mov  byte [camnew],1
        mov  byte [bgok],0
        mov  byte [bst],0       ; the crow flies off when the view changes
        mov  byte [dirty],1
        ret

SETSZ:  mov  [vsz],si
        mov  ax,si
        mov  cx,NKIND*2
        mul  cx                 ; a row of NKIND words a size  (DX goes)
        add  ax,spt
        mov  [sptrow],ax
        mov  ax,si
        mov  cx,NLOOK*2
        mul  cx
        add  ax,mant
        mov  [mantrow],ax
        cmp  si,5
        je   .iso
        mov  al,[SIZES+si]
        xor  ah,ah
        mov  [cell],ax
        mov  [vcx],ax           ; a column on: one cell right
        mov  [vry],ax           ; a row on: one cell down
        mov  [vsw],ax
        mov  [vsh],ax
        xor  ax,ax
        mov  [vcy],ax
        mov  [vrx],ax
        mov  [vlift],ax
        ret
.iso:   mov  word [cell],12
        mov  word [vcx],12      ; a column on: right and down
        mov  word [vcy],6
        mov  word [vrx],-12     ; a row on: left and down
        mov  word [vry],6
        mov  word [vsw],24
        mov  word [vsh],12
        mov  word [vlift],-6    ; the walls rise 6 over their tiles
        ret

; ------------------------------------------------------------------
;  TURNED - the grid as the view turns it (Q, E): [turn] 0..3 quarter
;  turns clockwise.  Out: tcols, trows; tstart - the cell at the turned
;  top left; tdcol, tdrow - what a column on and a row on add to a cell.
;  The cell at turned (cc,rr) is, for turn 0: (cc, rr); 1: (rr, h-1-cc);
;  2: (w-1-cc, h-1-rr); 3: (w-1-rr, cc) - as (column, row).
; ------------------------------------------------------------------
TURNED: mov  al,[lvw]
        mov  ah,[lvh]
        mov  bl,[turn]
        cmp  bl,1
        je   .t1
        cmp  bl,2
        je   .t2
        cmp  bl,3
        je   .t3
        mov  [tcols],al         ; turn 0: as it is
        mov  [trows],ah
        mov  word [tstart],0
        mov  word [tdcol],1
        mov  word [tdrow],NCOL
        ret
.t1:    mov  [tcols],ah         ; a quarter: h columns of w rows
        mov  [trows],al
        mov  al,ah
        xor  ah,ah
        dec  ax                 ; h-1
        mov  cl,5
        shl  ax,cl              ; (h-1)*32: the bottom left cell
        mov  [tstart],ax
        mov  word [tdcol],-NCOL ; a column on: a row up
        mov  word [tdrow],1     ; a row on: a column right
        ret
.t2:    mov  [tcols],al         ; a half: upside down
        mov  [trows],ah
        mov  bl,al              ; BL = w
        mov  al,ah
        xor  ah,ah
        dec  ax
        mov  cl,5
        shl  ax,cl              ; (h-1)*32...
        add  al,bl
        dec  ax                 ; ...+ w-1: the bottom right cell
        mov  [tstart],ax
        mov  word [tdcol],-1
        mov  word [tdrow],-NCOL
        ret
.t3:    mov  [tcols],ah         ; three quarters
        mov  [trows],al
        xor  ah,ah
        dec  ax                 ; w-1: the top right cell
        mov  [tstart],ax
        mov  word [tdcol],NCOL  ; a column on: a row down
        mov  word [tdrow],-1    ; a row on: a column left
        ret

; UNTURN - turned (AX = cc, BX = rr), signed, as the grid's CX = c, DX = r
UNTURN: mov  cl,[turn]
        cmp  cl,1
        je   .t1
        cmp  cl,2
        je   .t2
        cmp  cl,3
        je   .t3
        mov  cx,ax              ; turn 0: the same
        mov  dx,bx
        ret
.t1:    mov  cx,bx              ; c = rr
        mov  dl,[lvh]
        xor  dh,dh
        dec  dx
        sub  dx,ax              ; r = h-1-cc
        ret
.t2:    mov  cl,[lvw]
        xor  ch,ch
        dec  cx
        sub  cx,ax              ; c = w-1-cc
        mov  dl,[lvh]
        xor  dh,dh
        dec  dx
        sub  dx,bx              ; r = h-1-rr
        ret
.t3:    mov  cl,[lvw]
        xor  ch,ch
        dec  cx
        sub  cx,bx              ; c = w-1-rr
        mov  dx,ax              ; r = cc
        ret

; CELLXY - where cell AX (row*32 + column) lands: AX = x, DX = y, before
; ox and oy are added - the grid turned, then projected.  clobbers BX, CX.
CELLXY: mov  bl,al
        and  bl,NCOL-1          ; BL = c
        mov  cl,5
        shr  ax,cl
        mov  bh,al              ; BH = r
        mov  al,[turn]
        cmp  al,1
        je   .t1
        cmp  al,2
        je   .t2
        cmp  al,3
        je   .t3
        mov  cl,bl              ; CL = cc, CH = rr
        mov  ch,bh
        jmp  .proj
.t1:    mov  cl,[lvh]
        dec  cl
        sub  cl,bh              ; cc = h-1-r
        mov  ch,bl              ; rr = c
        jmp  .proj
.t2:    mov  cl,[lvw]
        dec  cl
        sub  cl,bl              ; cc = w-1-c
        mov  ch,[lvh]
        dec  ch
        sub  ch,bh              ; rr = h-1-r
        jmp  .proj
.t3:    mov  cl,bh              ; cc = r
        mov  ch,[lvw]
        dec  ch
        sub  ch,bl              ; rr = w-1-c
.proj:  mov  [tcc],cl
        mov  [trr],ch
TCXY:   mov  al,[tcc]           ; (entered here: turned tcc, trr known)
        xor  ah,ah
        imul word [vcx]         ; cc*CX  (DX goes)
        mov  cx,ax
        mov  al,[trr]
        xor  ah,ah
        imul word [vrx]
        add  cx,ax              ; x = cc*CX + rr*RX
        mov  al,[tcc]
        xor  ah,ah
        imul word [vcy]
        mov  [tyy],ax
        mov  al,[trr]
        xor  ah,ah
        imul word [vry]
        add  ax,[tyy]           ; y = cc*CY + rr*RY
        mov  dx,ax
        mov  ax,cx
        ret

; FLDIV - AX = floor(AX / BX), signed, BX > 0.  clobbers DX.
FLDIV:   cwd
        idiv bx                 ; rounds toward 0: DX the remainder
        or   dx,dx
        jns  .ok
        dec  ax                 ; a negative remainder: floor is one lower
.ok:    ret

; GRIDAT - the grid's bits at CX = c, DX = r (signed): G_OUT past the
; level's own rectangle.  keeps everything but AL.
GRIDAT: cmp  cx,0
        jl   .out
        cmp  dx,0
        jl   .out
        push bx
        mov  bl,[lvw]
        xor  bh,bh
        cmp  cx,bx
        jge  .out1
        mov  bl,[lvh]
        cmp  dx,bx
        jge  .out1
        mov  bx,dx
        push cx
        mov  cl,5
        shl  bx,cl              ; r * 32
        pop  cx
        add  bx,cx
        mov  al,[grid+bx]
        pop  bx
        ret
.out1:  pop  bx
.out:   mov  al,G_OUT
        ret

; CLASS - what cell CX = c, DX = r is (CL_...) in AL, its bits in AH
CLASS:  call GRIDAT
        mov  ah,al
        test al,G_WALL
        jz   .nw
        mov  al,CL_WALL
        ret
.nw:    test al,G_FLOOR
        jz   .void
        mov  al,CL_FLOOR
        ret
.void:  push si
        push ax
        mov  si,NEIGH8          ; a wall any of eight ways: water
.n:     push cx
        push dx
        add  cx,[si]
        add  dx,[si+2]
        call GRIDAT
        pop  dx
        pop  cx
        test al,G_WALL
        jnz  .moat
        add  si,4
        cmp  si,NEIGH8+32
        jb   .n
        pop  ax
        pop  si
        call ISROAD
        jnc  .park
        mov  al,CL_ROAD
        ret
.park:  mov  al,CL_PARK
        test ah,G_OUT
        jnz  .r
        mov  al,CL_YARD         ; a courtyard: the walls all round it
.r:     ret
.moat:  pop  ax
        pop  si
        mov  al,CL_MOAT
        ret

; ISROAD - CF=1: cell CX, DX is on the road, the gate's way out, two or
; more cells out from it.  keeps everything.
ISROAD: cmp  byte [hasgate],0
        je   .no
        push ax
        cmp  word [gdc],0
        je   .vert
        cmp  dx,[gater]         ; the way runs across: the gate's row
        jne  .no1
        mov  ax,cx
        sub  ax,[gatec]
        cmp  word [gdc],0
        jg   .p
        neg  ax
.p:     cmp  ax,2
        jl   .no1
        pop  ax
        stc
        ret
.vert:  cmp  cx,[gatec]         ; the way runs up or down: the gate's column
        jne  .no1
        mov  ax,dx
        sub  ax,[gater]
        cmp  word [gdr],0
        jg   .q
        neg  ax
.q:     cmp  ax,2
        jl   .no1
        pop  ax
        stc
        ret
.no1:   pop  ax
.no:    clc
        ret

; HASH - AL = a byte for cell CX, DX and the level: the scatter of the
; stones, the park, the torches, the candies' worth.  The seed through a
; generator, its bytes swapped, through it again (ArtGen2's Hash).
; keeps everything but AX.
HASH:   push bx
        push cx
        push dx
        mov  ax,dx
        and  ax,63
        mov  bx,cx
        mov  cl,6
        shl  ax,cl              ; (r AND 63) * 64
        and  bx,63
        add  ax,bx              ; + (c AND 63)
        mov  bx,[level]
        mov  cl,12
        shl  bx,cl              ; + level * 4096
        add  ax,bx
        mov  bx,25173
        mul  bx                 ; (DX goes)
        add  ax,13849
        xchg al,ah              ; its bytes swapped
        mul  bx
        add  ax,13849
        mov  al,ah              ; the high byte: the good one
        xor  ah,ah
        pop  dx
        pop  cx
        pop  bx
        ret

; ------------------------------------------------------------------
;  DRAWK - kind AX of the view's size at the cell whose top left is
;  x BX, y DX.  DRAWP - picture SI there.  Straight down a picture
;  stands on its cell's bottom row (a tall one rises over the cell
;  above); isometric a tile or block on its tile's bottom, anything
;  narrower centred, its feet at the tile's middle.  clobbers all but BP.
; ------------------------------------------------------------------
DRAWK:  push bx
        mov  bx,ax
        shl  bx,1
        add  bx,[sptrow]
        mov  si,[bx]
        pop  bx
DRAWP:  or   si,si
        jz   .none
        push ds
        mov  ds,[sseg]
        mov  ax,[si]            ; AL = rows, AH = bytes a row
        pop  ds
        and  ah,7Fh             ; (+80h: a solid picture)
        cmp  word [vsz],5
        je   .iso
        xor  ah,ah
        neg  ax
        add  ax,[cell]
        add  dx,ax              ; y + cell - rows
        jmp  DRAWSPR
.iso:   cmp  ah,12
        jne  .stand
        xor  ah,ah
        neg  ax
        add  ax,12
        add  dx,ax              ; a tile or a block: y + 12 - rows
        jmp  DRAWSPR
.stand: add  bx,4               ; 16 wide on 24: centred
        xor  ah,ah
        neg  ax
        add  ax,8
        add  dx,ax              ; its feet at y + 8
        jmp  DRAWSPR
.none:  ret

; ------------------------------------------------------------------
;  BUILDBG - the background for the view as it is (straight down only):
;  every screen cell, top row first, two passes - the ground, then what
;  stands on it, so a thing further down covers what is behind it.
; ------------------------------------------------------------------
BUILDBG:mov  word [tbase],BGOFF
        mov  ax,PFTOP
        mov  dx,PFBOT
        xor  bl,bl
        call FILLROWS           ; black: the floor is the background
        mov  word [clipt],PFTOP
        mov  word [clipb],PFBOT
        xor  ax,ax
        mov  [nwater],ax
        mov  [ntorch],ax
        mov  [ntower],ax
        mov  [nfount],ax
        mov  [gatevis],al
        mov  [bridvis],al
        mov  bx,[cell]          ; the screen's cells, a few past its edges
        mov  ax,[ox]
        neg  ax
        call FLDIV
        mov  [cc0],ax
        mov  ax,319
        sub  ax,[ox]
        call FLDIV
        mov  [cc1],ax
        mov  ax,PFTOP
        sub  ax,[oy]
        call FLDIV
        mov  [rr0],ax
        mov  ax,PFBOT-1
        sub  ax,[oy]
        call FLDIV
        add  ax,2               ; two more: a tall thing below the edge
        mov  [rr1],ax           ;  reaches up into the screen
        push es
        push ds
        pop  es
        mov  di,claim
        mov  cx,CLW*CLH/2
        xor  ax,ax
        rep  stosw              ; nothing placed yet
        pop  es
        mov  byte [bpass],0
.pass:  mov  ax,[rr0]
        mov  [brr],ax
.row:   mov  ax,[cc0]
        mov  [bcc],ax
.cell:  call BGCELL
        inc  word [bcc]
        mov  ax,[bcc]
        cmp  ax,[cc1]
        jle  .cell
        inc  word [brr]
        mov  ax,[brr]
        cmp  ax,[rr1]
        jle  .row
        inc  byte [bpass]
        cmp  byte [bpass],2
        jb   .pass
        call DUSKPREP           ; and the evening over all of it
        xor  ax,ax
        mov  bx,320
        mov  cx,PFTOP
        mov  dx,PFBOT
        call DUSK
        mov  word [tbase],0
        mov  ax,[ox]
        mov  [bgox],ax
        mov  ax,[oy]
        mov  [bgoy],ax
        mov  byte [bgok],1
        ret

; ------------------------------------------------------------------
;  DUSK - evening round the castle.  Each side of the level has its own
;  margin of land to the screen's edge; across it the light goes by the
;  golden section: the first 0.382 of it (1/phi^2) stays in full light,
;  then the land darkens a colour step, pixel by pixel through a 4x4
;  ordered dither (BAYER) - a few pixels at first, all of them at the
;  edge - so it fades with no edge, and the eye goes to the floor.  A
;  margin under 3 cells keeps its light (there is no park to darken), and
;  never inside the level's box: the castle and its floor keep theirs.
;  DUSKPREP, for the view: TXF[x], TYF[y] - how far across its margin a
;  column, a row is, 0..255.  DUSK: the box AX..BX-1 (x even), CX..DX-1
;  of [tbase]: a pixel is as far as the further of its column and row.
; ------------------------------------------------------------------
DUSKPREP:
        mov  ax,[ox]            ; the level's box on the screen
        mov  [lx0],ax
        mov  al,[tcols]
        xor  ah,ah
        mul  word [cell]        ; (DX goes)
        add  ax,[ox]
        dec  ax
        mov  [lx1],ax
        mov  ax,[oy]
        mov  [ly0],ax
        mov  al,[trows]
        xor  ah,ah
        mul  word [cell]
        add  ax,[oy]
        dec  ax
        mov  [ly1],ax
        xor  si,si              ; the columns
.x:     xor  al,al
        mov  bx,[lx0]
        cmp  si,bx
        jge  .xr
        mov  ax,bx              ; left of the level: d = lx0 - x of lx0
        sub  ax,si
        mov  cx,bx
        call FRAC
        jmp  .xs
.xr:    mov  bx,[lx1]
        cmp  si,bx
        jle  .xs                ; over the level: 0, full light
        mov  ax,si              ; right of it: d = x - lx1 of 319 - lx1
        sub  ax,bx
        mov  cx,319
        sub  cx,bx
        call FRAC
.xs:    mov  [TXF+si],al
        inc  si
        cmp  si,320
        jb   .x
        xor  si,si              ; the rows: the playfield's margins
.y:     xor  al,al
        mov  bx,[ly0]
        cmp  si,bx
        jge  .yr
        mov  ax,bx              ; above the level: of ly0 - PFTOP
        sub  ax,si
        mov  cx,bx
        sub  cx,PFTOP
        call FRAC
        jmp  .ys
.yr:    mov  bx,[ly1]
        cmp  si,bx
        jle  .ys
        mov  ax,si              ; below it: of PFBOT-1 - ly1
        sub  ax,bx
        mov  cx,PFBOT-1
        sub  cx,bx
        call FRAC
.ys:    mov  [TYF+si],al
        inc  si
        cmp  si,200
        jb   .y
        ret
; FRAC - AL = d/D as 0..255: AX = d (> 0), CX = D; a margin of 0, 0.
; clobbers DX.
FRAC:   push ax                 ; a margin under 3 cells: no park there to
        mov  ax,[cell]          ;  darken - it keeps its light
        add  ax,ax
        add  ax,[cell]
        cmp  cx,ax
        pop  ax
        jl   .z
        push bx
        mov  bx,256
        mul  bx                 ; DX:AX = d*256
        div  cx                 ; AX = d*256 / D
        pop  bx
        cmp  ax,255
        jbe  .r
        mov  al,255
.r:     ret
.z:     xor  al,al
        ret

DUSK:   cmp  cx,PFTOP           ; the box, kept on the playfield
        jge  .c1
        mov  cx,PFTOP
.c1:    cmp  dx,PFBOT
        jle  .c2
        mov  dx,PFBOT
.c2:    or   ax,ax
        jns  .c3
        xor  ax,ax
.c3:    cmp  bx,320
        jle  .c4
        mov  bx,320
.c4:    and  ax,0FFFEh
        mov  [dkx0],ax
        mov  [dkx1],bx
        mov  [dky],cx
        mov  [dky1],dx
        push es
        mov  es,[gseg]
.row:   mov  ax,[dky]
        cmp  ax,[dky1]
        jge  .done
        mov  bx,ax
        mov  dl,[TYF+bx]
        mov  [dtyr],dl          ; how far across its margin this row is
        mov  di,ax
        shl  di,1
        mov  di,[rowtab+di]
        add  di,[tbase]
        mov  bx,[dkx0]
        shr  bx,1
        add  di,bx              ; the row's first byte
        and  ax,3
        shl  ax,1
        shl  ax,1
        mov  [drow4],ax         ; the dither's row
        mov  si,[dkx0]          ; SI = x
.px:    cmp  si,[dkx1]
        jae  .next
        mov  al,[TXF+si]        ; the further of column and row
        cmp  al,[dtyr]
        jae  .t
        mov  al,[dtyr]
.t:     mov  bx,si
        and  bx,3
        add  bx,[drow4]
        mov  bl,[BAYER+bx]      ; this pixel's place in the dither
        xor  bh,bh
        xor  cl,cl
        cmp  al,[DUSKT1+bx]
        jbe  .put
        inc  cl                 ; past this place's threshold: a step darker
.put:   or   cl,cl
        jz   .pn
        mov  al,[es:di]
        mov  bx,DIM16
        test si,1
        jnz  .odd
        mov  ah,al              ; the left pixel: the high nibble
        shr  ah,1
        shr  ah,1
        shr  ah,1
        shr  ah,1
        and  al,0Fh
.d1:    xchg al,ah
        xlatb                   ; a step darker, CL times
        xchg al,ah
        dec  cl
        jnz  .d1
        shl  ah,1
        shl  ah,1
        shl  ah,1
        shl  ah,1
        or   al,ah
        jmp  .st
.odd:   mov  ah,al
        and  ah,0F0h
        and  al,0Fh
.d2:    xlatb
        dec  cl
        jnz  .d2
        or   al,ah
.st:    mov  [es:di],al
.pn:    test si,1
        jz   .pe
        inc  di                 ; past the right pixel: the next byte
.pe:    inc  si
        jmp  .px
.next:  inc  word [dky]
        jmp  .row
.done:  pop  es
        ret
; the thresholds, by the dither's place b: from 0.382 of the margin
; (98/256) the first pixels darken, by the edge all of them
DUSKT1:
  repeat 16
        db 98 + ((%-1)*150)/16
  end repeat

; BGCELL - screen cell (bcc, brr), pass bpass
BGCELL: mov  ax,[bcc]
        mov  bx,[brr]
        call UNTURN
        mov  [bc],cx
        mov  [br],dx
        mov  ax,[bcc]
        imul word [cell]
        add  ax,[ox]
        mov  [bx0],ax           ; its top left on the screen
        mov  ax,[brr]
        imul word [cell]
        add  ax,[oy]
        mov  [by0],ax
        mov  cx,[bc]
        mov  dx,[br]
        call CLASS
        mov  [bcls],al
        mov  [bbits],ah
        cmp  byte [bpass],0
        je   GROUND
        jmp  STAND

; GROUND - the first pass: what lies flat
GROUND: cmp  al,CL_FLOOR
        jne  .wall
        test ah,G_GOAL
        jz   .r
        mov  ax,K_GOL
        jmp  .put
.wall:  cmp  al,CL_WALL
        jne  .moat
        call ISGATE
        jnc  .stone
        mov  ax,[bx0]
        mov  [gatex],ax
        mov  ax,[by0]
        mov  [gatey],ax
        mov  byte [gatevis],1
        mov  ax,K_GT0
        jmp  .put
.stone: mov  cx,[bc]
        mov  dx,[br]
        call HASH
        and  al,3
        add  al,K_WA1           ; one of the four heaps of stones
        call .put
        mov  byte [bside],0     ; growth where a side faces out
.gs:    call SIDECELL           ; CX, DX: the cell on that side
        call GRIDAT
        test al,G_OUT
        jz   .gn
        mov  al,[bside]
        xor  ah,ah
        add  ax,K_FGN
        call .put
.gn:    inc  byte [bside]
        cmp  byte [bside],4
        jb   .gs
.r:     ret
.moat:  cmp  al,CL_MOAT
        jne  .road
        call ISBRIDGE
        jnc  .water
        mov  ax,[bx0]
        mov  [bridx],ax
        mov  ax,[by0]
        mov  [bridy],ax
        mov  byte [bridvis],1
.water: mov  byte [bside],0     ; banks where the next cell is dry land
        mov  byte [bbank],0
.ws:    call SIDECELL
        call CLASS
        cmp  al,CL_MOAT
        je   .wn
        cmp  al,CL_WALL
        je   .wn
        mov  cl,[bside]
        mov  al,1
        shl  al,cl
        or   [bbank],al
.wn:    inc  byte [bside]
        cmp  byte [bside],4
        jb   .ws
        mov  bx,[nwater]        ; the water is drawn every frame: listed
        cmp  bx,MAXWATER
        jae  .wx
        mov  ax,6
        mul  bx                 ; (DX goes)
        mov  bx,ax
        mov  ax,[bx0]
        mov  word [water+bx],ax
        mov  ax,[by0]
        mov  word [water+bx+2],ax
        mov  cx,[bc]            ; its own phase of the ripples: the wind
        mov  dx,[br]            ;  is not a grid
        call HASH
        mov  ah,al
        and  ah,3
        mov  al,[bbank]
        mov  word [water+bx+4],ax  ; AL the banks, AH the phase
        inc  word [nwater]
.wx:    mov  ax,K_MO0           ; and frame 0 into the background
        call .put
        mov  al,[bbank]
        call BANKS
        ret
.road:  cmp  al,CL_ROAD
        jne  .grass
        mov  ax,K_ROD
        jmp  .put
.grass: mov  ax,K_GRS           ; a courtyard: plain grass
        cmp  byte [bcls],CL_PARK
        jne  .put
        mov  cx,[bc]            ; the park: as the land has it - wet
        mov  dx,[br]            ;  grass, the garden's meadow (a stone in
        call LAND               ;  one cell of five), grass in the wood,
        mov  bl,al              ;  the pines' dark floor
        mov  ax,K_GRS
        cmp  bl,64
        jb   .put
        cmp  bl,136
        jae  .wood
        call HASH
        mov  bl,5
        div  bl                 ; AH = the scatter mod 5
        or   ah,ah
        mov  ax,K_GRL
        jnz  .put
        mov  ax,K_GR2
        jmp  .put
.wood:  cmp  bl,196
        jb   .put
        mov  ax,K_GRD
.put:   mov  bx,[bx0]
        mov  dx,[by0]
        xor  ah,ah
        jmp  DRAWK

; BANKS - the banks in bits AL (1 N, 2 E, 4 S, 8 W) at bx0, by0
BANKS:  mov  [bbank],al
        mov  ax,K_BKN
.b:     shr  byte [bbank],1
        jnc  .n
        push ax
        mov  bx,[bx0]
        mov  dx,[by0]
        call DRAWK
        pop  ax
.n:     inc  ax
        cmp  ax,K_BKW
        jbe  .b
        ret

; SIDECELL - CX, DX: the grid cell on screen side [bside] (0 up, 1 right,
; 2 down, 3 left) of (bc, br), as the turn has the grid on the screen
SIDECELL:
        mov  bl,[turn]
        xor  bh,bh
        shl  bx,1
        shl  bx,1
        shl  bx,1               ; 8 bytes a turn
        mov  al,[bside]
        xor  ah,ah
        shl  ax,1
        add  bx,ax              ; + 2 a side
        mov  al,[SDIR+bx]
        cbw
        mov  cx,[bc]
        add  cx,ax
        mov  al,[SDIR+bx+1]
        cbw
        mov  dx,[br]
        add  dx,ax
        ret

; ISGATE - CF=1: (bc, br) is the gate.  ISBRIDGE - its bridge: the cell
; one out from it
ISGATE: cmp  byte [hasgate],0
        je   .no
        mov  ax,[bc]
        cmp  ax,[gatec]
        jne  .no
        mov  ax,[br]
        cmp  ax,[gater]
        jne  .no
        stc
        ret
.no:    clc
        ret
ISBRIDGE:
        cmp  byte [hasgate],0
        je   .no
        mov  ax,[gatec]
        add  ax,[gdc]
        cmp  ax,[bc]
        jne  .no
        mov  ax,[gater]
        add  ax,[gdr]
        cmp  ax,[br]
        jne  .no
        stc
        ret
.no:    clc
        ret

; STAND - the second pass: what stands up
STAND:  cmp  al,CL_WALL
        jne  .park
        call ISGATE
        jc   .r
        call CORNER
        jnc  .torch
        mov  cx,[bc]
        mov  dx,[br]
        call HASH
        mov  bl,3
        div  bl
        or   ah,ah
        jz   .torch             ; a third of the corners keep no tower
        mov  si,towers
        mov  bx,[ntower]
        cmp  bx,MAXTOWER
        jae  .r
        jmp  .list
.torch: mov  cx,[bc]
        mov  dx,[br]
        call HASH
        cmp  al,236
        jbe  .r
        inc  dx                 ; a floor below, right or left: a torch
        call GRIDAT
        dec  dx
        test al,G_FLOOR
        jnz  .lt
        inc  cx
        call GRIDAT
        dec  cx
        test al,G_FLOOR
        jnz  .lt
        dec  cx
        call GRIDAT
        inc  cx
        test al,G_FLOOR
        jz   .r
.lt:    mov  si,torches
        mov  bx,[ntorch]
        cmp  bx,MAXTORCH
        jae  .r
.list:  shl  bx,1
        shl  bx,1               ; 4 bytes an entry
        mov  ax,[bx0]
        mov  [si+bx],ax
        mov  ax,[by0]
        mov  [si+bx+2],ax
        cmp  si,towers
        jne  .tc
        inc  word [ntower]
        ret
.tc:    cmp  si,torches
        jne  .fc
        inc  word [ntorch]
        ret
.fc:    inc  word [nfount]
.r:     ret
.park:  cmp  al,CL_PARK
        jne  .r
        call CLAIMED            ; something stands here already
        jc   .r
        mov  cx,[bc]            ; the land says which of the park's four
        mov  dx,[br]            ;  parts this is...
        call LAND
        mov  si,ZWET
        cmp  al,64
        jb   .zone
        mov  si,ZGARDEN
        cmp  al,136
        jb   .zone
        mov  si,ZWOOD
        cmp  al,196
        jb   .zone
        mov  si,ZPINE
.zone:  add  cx,7               ; ...the scatter, which of its things
        add  dx,3
        call HASH
        call DECOR              ; AL = the kind, AH = cells wide
        cmp  al,0FFh
        je   .r
        mov  [dkind],al
        mov  [dwide],ah
        mov  bl,byte [vsz]      ; how many cells tall at this size
        xor  bh,bh
        mov  ax,NKIND*2
        mul  bx
        mov  bl,[dkind]
        shl  bx,1
        add  bx,ax
        mov  si,[spt+bx]
        push ds
        mov  ds,[sseg]
        mov  al,[si]            ; its rows
        pop  ds
        xor  ah,ah
        add  ax,[cell]
        dec  ax
        xor  dx,dx
        div  word [cell]        ; rounded up
        mov  [dtall],al
        mov  byte [dkx],0        ; every cell it covers: park, unclaimed
.ck:    mov  byte [dqx],0
.cq:    mov  ax,[bcc]
        add  al,[dqx]
        adc  ah,0
        mov  bx,[brr]
        sub  bl,[dkx]
        sbb  bh,0
        push ax
        push bx
        call UNTURN
        call CLASS
        pop  bx
        pop  dx                 ; DX = cc, BX = rr
        cmp  al,CL_PARK
        je   .cok
        cmp  byte [dkx],0
        je   .r                 ; its foot must be on grass...
        cmp  al,CL_ROAD
        jne  .r                 ; ...what it rises over grass or road
.cok:   mov  ax,dx
        call CLAIMAT
        jc   .r
        inc  byte [dqx]
        mov  al,[dqx]
        cmp  al,[dwide]
        jb   .cq
        inc  byte [dkx]
        mov  al,[dkx]
        cmp  al,[dtall]
        jb   .ck
        mov  byte [dkx],0        ; all clear: claim them
.mk:    mov  byte [dqx],0
.mq:    mov  ax,[bcc]
        add  al,[dqx]
        adc  ah,0
        mov  bx,[brr]
        sub  bl,[dkx]
        sbb  bh,0
        call CLAIMSET
        inc  byte [dqx]
        mov  al,[dqx]
        cmp  al,[dwide]
        jb   .mq
        inc  byte [dkx]
        mov  al,[dkx]
        cmp  al,[dtall]
        jb   .mk
        mov  cx,[bc]            ; a little off the grid: it is a park
        add  cx,2
        mov  dx,[br]
        add  dx,11
        call HASH
        push ax
        and  al,7
        sub  al,3
        cbw
        imul word [cell]        ; -3..4 sixteenths of a cell
        mov  cl,4
        sar  ax,cl
        and  ax,0FFFEh          ; even
        add  ax,[bx0]
        mov  [dx0],ax
        pop  ax
        mov  cl,3
        shr  al,cl
        and  al,3
        dec  al
        cbw
        imul word [cell]
        mov  cl,3
        sar  ax,cl              ; -1..2 eighths
        add  ax,[by0]
        mov  [dy0],ax
        cmp  byte [dkind],K_FN0
        jne  .draw
        mov  si,founts          ; a fountain plays: listed
        mov  bx,[nfount]
        cmp  bx,MAXFOUNT
        jae  .draw
        shl  bx,1
        shl  bx,1
        mov  ax,[dx0]
        mov  [si+bx],ax
        mov  ax,[dy0]
        mov  [si+bx+2],ax
        inc  word [nfount]
.draw:  mov  al,[dkind]
        xor  ah,ah
        mov  bx,[dx0]
        mov  dx,[dy0]
        jmp  DRAWK

; CORNER - CF=1: (bc, br) is an outer corner of the walls - two walls
; beside it, one across and one up or down, and the outside beyond the
; corner they make
CORNER: mov  cx,[bc]
        mov  dx,[br]
        xor  bx,bx              ; BL: walls left/right/up/down as bits
        dec  cx
        call GRIDAT
        test al,G_WALL
        jz   .l
        or   bl,1
.l:     add  cx,2
        call GRIDAT
        test al,G_WALL
        jz   .rt
        or   bl,2
.rt:    dec  cx
        dec  dx
        call GRIDAT
        test al,G_WALL
        jz   .u
        or   bl,4
.u:     add  dx,2
        call GRIDAT
        test al,G_WALL
        jz   .d
        or   bl,8
.d:     dec  dx
        mov  al,bl
        and  al,3
        cmp  al,1               ; exactly one of left, right
        je   .h
        cmp  al,2
        jne  .no
.h:     mov  al,bl
        and  al,12
        cmp  al,4               ; and exactly one of up, down
        je   .v
        cmp  al,8
        jne  .no
.v:     test bl,2               ; the corner's outside: away from both
        jz   .xl
        dec  cx                 ;  a wall on the right: look left
        jmp  .y
.xl:    inc  cx
.y:     test bl,8
        jz   .yu
        dec  dx                 ;  a wall below: look up
        jmp  .look
.yu:    inc  dx
.look:  call GRIDAT
        test al,G_OUT
        jz   .no
        stc
        ret
.no:    clc
        ret

; DECOR - SI = a part of the park's table, AL = the scatter: AL = the
; kind for it (0FFh nothing), AH = how many cells wide (ArtGen2's Decor,
; the same thresholds)
DECOR:
.d:     cmp  al,[si]
        jb   .hit
        add  si,3
        cmp  byte [si],0FFh
        jne  .d
        mov  al,0FFh
        ret
.hit:   mov  ax,[si+1]          ; AL = kind, AH = width
        ret

; CLAIMED - CF=1: screen cell (bcc, brr) is taken.  CLAIMAT - the same
; for AX = cc, BX = rr; CLAIMSET - take it.  Off the claims: free.
CLAIMED:mov  ax,[bcc]
        mov  bx,[brr]
CLAIMAT:call CLIX
        jc   .free
        cmp  byte [claim+bx],0
        je   .free
        stc
        ret
.free:  clc
        ret
CLAIMSET:
        call CLIX
        jc   .off
        mov  byte [claim+bx],1
.off:   ret
; CLIX - BX = the claims' index of cc AX, rr BX; CF=1 off the claims
CLIX:   sub  ax,[cc0]
        jl   .off
        cmp  ax,CLW
        jge  .off
        sub  bx,[rr0]
        jl   .off
        cmp  bx,CLH
        jge  .off
        push ax
        mov  ax,bx
        mov  bx,CLW
        mul  bx                 ; (DX goes)
        pop  bx
        add  bx,ax
        clc
        ret
.off:   stc
        ret

; ------------------------------------------------------------------
;  RENDER - the frame, as the view has it; then out to the card
; ------------------------------------------------------------------
RENDER: mov  word [tbase],0
        cmp  byte [view],2
        jne  .flat
        call FRAMEISO
        jmp  .top
.flat:  call CAMERA
        mov  ax,[ox]
        cmp  ax,[bgox]
        jne  .bg
        mov  ax,[oy]
        cmp  ax,[bgoy]
        jne  .bg
        cmp  byte [bgok],0
        jne  .have
.bg:    call BUILDBG
.have:  call COPYBG
        call FRAMEFL
.top:   mov  word [clipt],0
        mov  word [clipb],200
        call HUD
        call BANNERS
        cmp  byte [phase],3
        jne  .out
        call WINNER
.out:   jmp  BLIT

; FRAMEFL - straight down: what moves and plays, over the background
FRAMEFL:mov  word [clipt],PFTOP
        mov  word [clipb],PFBOT
        mov  ax,[now]           ; a gust of wind: a band 48 px wide that
        shl  ax,1               ;  sweeps the screen left to right, 73 px
        shl  ax,1               ;  a second, every 7 s
        and  ax,511
        sub  ax,96
        mov  [gustx],ax
        mov  si,water           ; the water: each cell its own phase of the
        mov  cx,[nwater]        ;  ripples, torn white under the gust
        jcxz .gate
.w:     push cx
        push si
        mov  bx,[si]
        mov  dx,[si+2]
        mov  [bx0],bx
        mov  [by0],dx
        mov  ax,K_MO4
        mov  cx,bx
        add  cx,[cell]
        cmp  cx,[gustx]
        jle  .calm
        mov  cx,[gustx]
        add  cx,48
        cmp  bx,cx
        jl   .wk
.calm:  mov  al,[anim]
        shr  al,1
        add  al,[si+5]          ; its phase
        and  ax,3
        add  ax,K_MO0
.wk:    call DRAWK
        pop  si
        push si
        mov  al,[si+4]
        call BANKS
        pop  si
        pop  cx
        add  si,6
        loop .w
.gate:  cmp  byte [gatevis],0
        je   .brid
        cmp  byte [phase],0
        je   .brid              ; down: as the background has it
        mov  ax,K_GT1           ; rising
        cmp  byte [phase],1
        je   .gt
        mov  ax,K_GT2           ; up
.gt:    mov  bx,[gatex]
        mov  dx,[gatey]
        call DRAWK
.brid:  cmp  byte [bridvis],0
        je   .torch
        cmp  byte [phase],2
        jb   .torch             ; the bridge comes down with the gate up
        mov  ax,K_BRV
        mov  bl,[turn]
        and  bl,1               ; the way runs up the screen: planks across
        cmp  word [gdc],0
        je   .bv
        xor  bl,1
.bv:    or   bl,bl
        jz   .bk
        mov  ax,K_BRH
.bk:    mov  bx,[bridx]
        mov  dx,[bridy]
        call DRAWK
.torch: mov  si,torches         ; the torches flicker, each its own way
        mov  cx,[ntorch]
        jcxz .tow
.t:     push cx
        push si
        mov  bx,[si]
        mov  dx,[si+2]
        mov  al,[anim]
        add  al,cl
        and  ax,1
        add  ax,K_TR0
        call DRAWK
        pop  si
        pop  cx
        add  si,4
        loop .t
.tow:   mov  si,towers
        mov  cx,[ntower]
        jcxz .fnt
.tw:    push cx
        push si
        mov  bx,[si]
        mov  dx,[si+2]
        mov  ax,K_TWR
        call DRAWK
        pop  si
        pop  cx
        add  si,4
        loop .tw
.fnt:   mov  si,founts
        mov  cx,[nfount]
        jcxz .things
.f:     push cx
        push si
        mov  bx,[si]
        mov  dx,[si+2]
        mov  al,[anim]          ; four frames: the water falls
        and  ax,3
        add  ax,K_FN0
        call DRAWK
        pop  si
        push si
        mov  ax,[si]            ; and the evening over it, as over the land
        mov  bx,ax
        add  bx,[cell]
        add  bx,[cell]          ; two cells wide,
        mov  dx,[si+2]
        add  dx,[cell]          ; standing on its cell's bottom,
        mov  cx,[cell]
        shr  cx,1
        add  cx,[cell]
        neg  cx
        add  cx,dx              ; a cell and a half high
        call DUSK
        pop  si
        pop  cx
        add  si,4
        loop .f
.things:call THINGS
        call OVERLAY
        jmp  DRAWBIRD

; FRAMEISO - isometric: no background - the level's cells every frame,
; on grass, back to front: first the floor and the water, then the
; walls and what is on the floor
FRAMEISO:
        call CAMERA
        mov  ax,PFTOP
        mov  dx,PFBOT
        mov  bl,2
        call FILLROWS           ; grass
        mov  word [clipt],PFTOP
        mov  word [clipb],PFBOT
        mov  byte [pass],0
.pass:  call ROWS0
.row:   call COLS0
.cell:  mov  bx,[cptr]
        mov  al,[bx]
        cmp  byte [pass],0
        jne  .stand
        test al,G_FLOOR
        jz   .wat
        mov  ax,K_IFLR
        test byte [bx],G_GOAL
        jz   .flat
        mov  ax,K_GOL
.flat:  call CURK
        jmp  .next
.wat:   test al,G_WALL
        jnz  .next
        mov  ax,[cptr]
        sub  ax,grid
        mov  cx,ax
        and  cx,NCOL-1
        mov  dx,ax
        push cx
        mov  cl,5
        shr  dx,cl
        pop  cx
        call CLASS
        cmp  al,CL_MOAT
        jne  .next
        mov  al,[anim]
        and  ax,3
        add  ax,K_MO0
        call CURK
        jmp  .next
.stand: test al,G_WALL
        jz   .thing
        mov  ax,[cptr]
        sub  ax,grid
        cmp  byte [hasgate],0
        je   .stone
        cmp  ax,[gatecell]
        jne  .stone
        mov  ax,K_GT0           ; the gate, as the phase has it
        add  al,[phase]
        cmp  ax,K_GT2
        jbe  .gk
        mov  ax,K_GT2
.gk:    call CURK
        jmp  .next
.stone: mov  cx,ax
        and  cx,NCOL-1
        mov  dx,ax
        push cx
        mov  cl,5
        shr  dx,cl
        pop  cx
        call HASH
        and  ax,3
        add  ax,K_WA1
        call CURK
        jmp  .next
.thing: call THING
.next:  call NEXTCOL
        jb   .cell
        call NEXTROW
        jb   .row
        inc  byte [pass]
        cmp  byte [pass],2
        jb   .pass
        jmp  OVERLAY

; the turned grid, row by row, column by column, the way RENDER always
; walked it: ROWS0 starts, COLS0 starts a row, NEXTCOL / NEXTROW step
; (CF=1: still inside).  cptr: the cell; curx, cury: its top left.
ROWS0:  mov  ax,[ox]
        mov  [rowx],ax
        mov  ax,[oy]
        mov  [rowy],ax
        mov  ax,[tstart]
        add  ax,grid
        mov  [cidx],ax
        mov  byte [crow],0
        ret
COLS0:  mov  ax,[rowx]
        mov  [curx],ax
        mov  ax,[rowy]
        mov  [cury],ax
        mov  ax,[cidx]
        mov  [cptr],ax
        mov  byte [ccol],0
        ret
NEXTCOL:mov  ax,[vcx]
        add  [curx],ax
        mov  ax,[vcy]
        add  [cury],ax
        mov  ax,[tdcol]
        add  [cptr],ax
        inc  byte [ccol]
        mov  al,[ccol]
        cmp  al,[tcols]
        ret
NEXTROW:mov  ax,[vrx]
        add  [rowx],ax
        mov  ax,[vry]
        add  [rowy],ax
        mov  ax,[tdrow]
        add  [cidx],ax
        inc  byte [crow]
        mov  al,[crow]
        cmp  al,[trows]
        ret
; CURK - kind AX at the current cell
CURK:   mov  bx,[curx]
        mov  dx,[cury]
        jmp  DRAWK

; THINGS - what is on the floor, every cell of the turned grid
THINGS: call ROWS0
.row:   call COLS0
.cell:  call THING
        call NEXTCOL
        jb   .cell
        call NEXTROW
        jb   .row
        ret

; THING - on cell [cptr]: a candy, the diamond, a mine, a crate, men
THING:  mov  bx,[cptr]
        mov  al,[bx]
        test al,G_FLOOR
        jz   .r
        test al,G_CANDY
        jz   .gem
        test al,G_BOX or G_MAN
        jnz  .gem
        mov  ax,bx
        sub  ax,grid
        call CANDYV             ; AX = 0, 1, 2: its worth less one
        add  ax,K_CA1
        call CURK
        mov  ax,[cptr]          ; and now and then a glint on it, each
        sub  ax,grid            ;  candy at its own moments
        mov  bx,37
        mul  bx                 ; (DX goes)
        mov  bl,[anim]
        xor  bh,bh
        add  ax,bx
        add  ax,bx
        add  ax,bx              ; + anim*3
        and  ax,31
        cmp  ax,3
        jae  .gem
        mov  ax,K_CSP
        call CURK
.gem:   mov  ax,[cptr]
        sub  ax,grid
        cmp  ax,[gemcell]
        jne  .mine
        mov  ax,K_DI0           ; growing out of the floor
        cmp  word [gemclk],GEMLIFE-GEMGROW
        ja   .gk
        mov  al,[anim]          ; then sparkling now and then
        and  ax,3
        cmp  ax,3
        mov  ax,K_DI1
        jne  .gk
        mov  ax,K_DI2
.gk:    call CURK
.mine:  mov  ax,[cptr]
        sub  ax,grid
        call MINEAT
        jc   .box
        mov  ax,K_MIN
        call CURK
.box:   mov  bx,[cptr]
        mov  al,[bx]
        test al,G_BOX
        jz   .men
        mov  ax,K_BOX
        test byte [bx],G_GOAL
        jz   .bk
        mov  ax,K_BOG           ; home: green
.bk:    call CURK
        ret
.men:   test al,G_MAN
        jz   .r
        jmp  DRAWMEN
.r:     ret

; CANDYV - AX = a candy's worth less one (0..2) for cell AX
CANDYV: mov  cx,ax
        and  cx,NCOL-1
        mov  dx,ax
        push cx
        mov  cl,5
        shr  dx,cl
        pop  cx
        add  cx,5
        add  dx,9
        call HASH
        mov  bl,3
        div  bl
        mov  al,ah
        xor  ah,ah
        ret

; MINEAT - a mine ticking on cell AX?  CF=0: yes, SI -> it.  keeps AX.
MINEAT: mov  si,mines
.m:     cmp  [si+M_CELL],ax
        jne  .n
        cmp  word [si+M_LEFT],0
        jg   .yes               ; still ticking (below 0: the blast)
.n:     add  si,MSIZE
        cmp  si,mines+MAXP*MSIZE
        jb   .m
        stc
        ret
.yes:   clc
        ret

; DRAWMEN - every man standing on cell [cptr]; your marker over yours
DRAWMEN:mov  ax,[cptr]
        sub  ax,grid
        mov  [ccell],ax
        mov  word [pidx],players
.p:     mov  bx,[pidx]
        cmp  byte [bx+P_ON],0
        je   .n
        cmp  byte [bx+P_OUT],0
        jne  .n                 ; out through the gate: not here
        mov  al,[bx+P_ROW]
        xor  ah,ah
        mov  cl,5
        shl  ax,cl
        add  al,[bx+P_COL]
        cmp  ax,[ccell]
        jne  .n
        mov  al,[bx+P_LOOK]
        xor  ah,ah
        shl  ax,1
        mov  bx,ax
        add  bx,[mantrow]
        mov  si,[bx]            ; his picture, his colours
        mov  bx,[curx]
        mov  dx,[cury]
        call DRAWP
        mov  ax,[pidx]
        cmp  ax,[mep]
        jne  .n
        mov  ax,K_YOU
        cmp  word [vsz],5
        jne  .you
        sub  word [cury],12     ; isometric: the marker over his head
        call CURK
        add  word [cury],12
        jmp  .n
.you:   call CURK
.n:     add  word [pidx],PSIZE
        cmp  word [pidx],players+MAXP*PSIZE
        jb   .p
        ret

; ------------------------------------------------------------------
;  OVERLAY - the blasts on their nine cells; each mine's seconds on it
;  and each still man's over him (not at the smallest sizes: the list
;  under the floor has every count)
; ------------------------------------------------------------------
OVERLAY:mov  word [pidx],mines
.m:     mov  si,[pidx]
        mov  ax,[si+M_CELL]
        cmp  ax,0FFFFh
        je   .mn
        mov  dx,[si+M_LEFT]
        or   dx,dx
        jns  .fuse
        mov  [ccell],ax         ; a blast: its nine cells
        mov  word [boff9],-NCOL-1
.b:     mov  ax,[ccell]
        add  ax,[boff9]
        cmp  ax,NCOL*NCOL
        jae  .bn
        mov  bx,ax
        test byte [grid+bx],G_FLOOR or G_WALL
        jz   .bn
        call CELLXY
        add  ax,[ox]
        add  dx,[oy]
        mov  bx,ax
        mov  ax,K_BLA
        call DRAWK
.bn:    inc  word [boff9]
        mov  ax,[boff9]
        and  ax,NCOL-1
        cmp  ax,2
        jne  .bc
        add  word [boff9],NCOL-3
.bc:    cmp  word [boff9],NCOL+1
        jle  .b
        jmp  .mn
.fuse:  cmp  word [cell],10
        jb   .mn
        call CELLXY
        add  ax,[ox]
        add  dx,[oy]
        mov  bx,[vsw]
        shr  bx,1
        add  ax,bx
        mov  bx,ax              ; its middle across
        mov  ax,[vsh]
        sub  ax,6
        shr  ax,1
        add  dx,ax              ; and down
        mov  si,[pidx]
        mov  ax,[si+M_LEFT]
        call SECS
        mov  cl,14
        call OVNUM
.mn:    add  word [pidx],MSIZE
        cmp  word [pidx],mines+MAXP*MSIZE
        jb   .m
        cmp  word [cell],10
        jb   .done
        mov  word [pidx],players
.p:     mov  si,[pidx]
        cmp  byte [si+P_ON],0
        je   .pn
        cmp  byte [si+P_OUT],0
        jne  .pn
        cmp  word [si+P_STUN],0
        je   .pn
        mov  al,[si+P_ROW]
        xor  ah,ah
        mov  cl,5
        shl  ax,cl
        add  al,[si+P_COL]
        call CELLXY
        add  ax,[ox]
        add  dx,[oy]
        mov  bx,[vsw]
        shr  bx,1
        add  ax,bx
        mov  bx,ax
        sub  dx,4               ; over his head
        cmp  word [vsz],5
        jne  .ph
        sub  dx,10
.ph:    mov  si,[pidx]
        mov  ax,[si+P_STUN]
        call SECS
        mov  cl,12
        call OVNUM
.pn:    add  word [pidx],PSIZE
        cmp  word [pidx],players+MAXP*PSIZE
        jb   .p
.done:  ret

; SECS - AX ticks as whole seconds, rounded up: (AX + 17) / 18
SECS:   add  ax,17
        mov  cl,18
        div  cl                 ; AL = seconds
        xor  ah,ah
        ret

; OVNUM - number AX (0..99) centred on x BX, its top at y DX, colour CL,
; in the 4x6 letters with a shadow; nothing outside the playfield
OVNUM:  cmp  dx,PFTOP
        jl   .no
        cmp  dx,PFBOT-6
        jg   .no
        mov  [ty],dx
        mov  [tclr],cl
        mov  byte [tshad],1
        sub  bx,2               ; one digit: 4 wide
        cmp  ax,10
        jb   .one
        sub  bx,2               ; two: 8
.one:   and  bx,0FFFEh
        mov  [tx],bx
        mov  cl,1
        call PNUM4
        mov  byte [tshad],0
.no:    ret

; ------------------------------------------------------------------
;  HUD - the level line over the playfield, the players under it
; ------------------------------------------------------------------
HUD:    xor  ax,ax
        mov  dx,PFTOP
        xor  bl,bl
        call FILLROWS
        mov  ax,PFBOT
        mov  dx,200
        xor  bl,bl
        call FILLROWS
        mov  byte [tshad],0
        mov  word [ty],1
        mov  word [tx],2
        mov  byte [tclr],7
        mov  si,TLEV
        call PRINT4
        mov  byte [tclr],14
        mov  ax,[level]
        inc  ax
        mov  cl,2
        call PNUM4
        mov  byte [tclr],7
        mov  al,'/'
        call PUTC4
        mov  ax,NLEVELS
        mov  cl,2
        call PNUM4
        mov  word [tx],70
        mov  si,TCRATE
        call PRINT4
        mov  byte [tclr],14
        mov  ax,[ngood]
        mov  cl,1
        call PNUM4
        mov  byte [tclr],7
        mov  al,'/'
        call PUTC4
        mov  ax,[nbox]
        mov  cl,1
        call PNUM4
        mov  word [tx],140
        mov  si,TMOVES
        call PRINT4
        mov  byte [tclr],14
        mov  ax,[moves]
        mov  cl,1
        call PNUM4
        mov  word [tx],204
        mov  byte [tclr],7
        mov  si,TCANDY
        call PRINT4
        mov  byte [tclr],10
        mov  ax,[ncandy]
        mov  cl,1
        call PNUM4
        mov  word [tx],270      ; who keeps the castle
        mov  byte [tclr],8
        mov  si,TALONE
        cmp  byte [netmode],0
        je   .net
        mov  byte [tclr],11
        mov  si,THOST
        cmp  byte [netmode],1
        je   .net
        mov  si,TONLINE
.net:   call PRINT4
        jmp  PLIST

; PLIST - the players under the playfield: two rows of four
PLIST:  mov  word [pidx],players
        mov  byte [pslot],0
.p:     mov  bx,[pidx]
        cmp  byte [bx+P_ON],0
        je   .n
        mov  al,[pslot]
        and  ax,3
        mov  cx,80
        mul  cx                 ; (DX goes)
        mov  [pcol],ax
        mov  [tx],ax
        mov  al,[pslot]
        xor  ah,ah
        shr  ax,1
        shr  ax,1
        mov  cx,6
        mul  cx
        add  ax,PFBOT+2
        mov  [ty],ax
        mov  bx,[pidx]
        cmp  bx,[mep]
        jne  .mark
        mov  byte [tclr],14
        mov  al,'>'             ; this machine's man
        call PUTC4
.mark:  mov  bx,[pidx]          ; his shirt's colour, a block
        mov  al,[bx+P_LOOK]
        xor  ah,ah
        shl  ax,1
        shl  ax,1
        mov  si,ax
        mov  al,[LOOKS+si]
        mov  bx,[pcol]
        add  bx,4
        mov  dx,[ty]
        mov  cx,4
        mov  si,5
        call FILLBOX
        mov  ax,[pcol]
        add  ax,10
        mov  [tx],ax
        mov  byte [tclr],15
        mov  si,[pidx]
        add  si,P_NAME
        call PNAME
        mov  ax,[pcol]
        add  ax,42
        mov  [tx],ax
        cmp  byte [netmode],0
        je   .score
        mov  bx,[pidx]
        mov  ax,[bx+P_PID]
        cmp  ax,[hostpid]
        jne  .score
        mov  byte [tclr],12
        mov  al,'*'             ; the host
        call PUTC4
.score: mov  ax,[pcol]
        add  ax,46
        mov  [tx],ax
        mov  byte [tclr],14
        mov  bx,[pidx]
        mov  ax,[bx+P_SCORE]
        mov  cl,1
        call PSNUM4
        mov  ax,[pcol]
        add  ax,68
        mov  [tx],ax
        mov  bx,[pidx]
        cmp  byte [bx+P_OUT],0
        je   .stun
        mov  byte [tclr],11
        mov  si,TOUT
        call PRINT4
        jmp  .slot
.stun:  mov  ax,[bx+P_STUN]
        or   ax,ax
        jz   .cool
        mov  byte [tclr],12
        mov  al,'Z'
        call PUTC4
        mov  bx,[pidx]
        mov  ax,[bx+P_STUN]
        jmp  .secs
.cool:  mov  ax,[bx+P_COOL]
        or   ax,ax
        jz   .ready
        mov  byte [tclr],7
        mov  al,'M'
        call PUTC4
        mov  bx,[pidx]
        mov  ax,[bx+P_COOL]
.secs:  call SECS
        mov  cl,1
        call PNUM4
        jmp  .slot
.ready: mov  byte [tclr],10
        mov  al,'M'             ; his mine is ready
        call PUTC4
.slot:  inc  byte [pslot]
.n:     add  word [pidx],PSIZE
        cmp  word [pidx],players+MAXP*PSIZE
        jb   .p
        ret

; PNAME - a player's name at SI: up to 8 letters, to the first zero
PNAME:  mov  cx,8
.c:     lodsb
        or   al,al
        jz   .end
        push cx
        call PUTC4
        pop  cx
        loop .c
.end:   ret

; BANNERS - the news, in the level line's place over the playfield - never
; over the floor itself: a question, the gate's news, the wait to come in
BANNERS:mov  bl,[pend]
        or   bl,bl
        jz   .gate
        xor  bh,bh
        shl  bx,1
        mov  si,[QTAB+bx]       ; R, N or P asked: again to do it
        jmp  TOPLINE
.gate:  mov  si,TRISE
        cmp  byte [phase],1
        je   TOPLINE
        cmp  byte [phase],2
        jne  .in
        mov  si,TWALK           ; and the seconds left, in its place
        mov  di,TWALKN
        mov  ax,[pclk]
        call SECS
        mov  cl,10
        div  cl
        add  ax,'00'
        mov  [di],ax            ; two digits
        jmp  TOPLINE
.in:    cmp  byte [netmode],2
        jne  .end
        cmp  word [mep],ghost   ; a client the host has not let in yet
        jne  .end
        mov  si,TCOMING
        jmp  TOPLINE
.end:   ret

; TOPLINE - string SI across the top line, centred, the 8x8 letters,
; yellow on dark blue
TOPLINE:push si
        xor  ax,ax
        mov  dx,PFTOP
        mov  bl,1
        call FILLROWS
        pop  si
        call STRLEN
        mov  ax,cx
        mov  cl,3
        shl  ax,cl
        mov  bx,320
        sub  bx,ax
        shr  bx,1
        and  bx,0FFFEh
        mov  [tx],bx
        mov  word [ty],0
        mov  byte [tclr],14
        mov  byte [tscale],1
        mov  byte [tshad],0
        jmp  PRINT8

; ------------------------------------------------------------------
;  WINNER - after every level: the warehouse in the evening, the man
;  who did most in it jumping on a red podium, his name, what he got,
;  confetti; the others' takings under him
; ------------------------------------------------------------------
WINNER: call DIM
        mov  ax,[now]
        mov  [wtick],ax
        mov  cx,40              ; confetti, falling, each its own way
.c:     push cx
        mov  ax,cx
        mov  bx,41
        mul  bx
        add  ax,cx
        mov  bx,cx
        shl  bx,1
        shl  bx,1
        shl  bx,1
        add  ax,bx              ; x: a spread of the 40
        xor  dx,dx
        mov  bx,316
        div  bx
        mov  bx,dx              ; BX = x
        and  bx,0FFFEh
        mov  ax,cx
        and  ax,3
        inc  ax
        mul  word [wtick]       ; falling 1..4 px a tick
        mov  si,cx
        mov  dx,23
        push ax
        mov  ax,si
        mul  dx
        pop  dx
        add  ax,dx              ; y: started at its own height
        xor  dx,dx
        mov  si,PFBOT-PFTOP-4
        div  si
        add  dx,PFTOP
        mov  ax,cx
        and  al,7
        add  al,9               ; the bright colours
        mov  cx,2
        mov  si,2
        call FILLBOX
        pop  cx
        loop .c
        mov  si,TWINNER         ; WINNER, twice as big, its colour cycling
        call STRLEN
        mov  ax,cx
        mov  cl,4
        shl  ax,cl
        mov  bx,320
        sub  bx,ax
        shr  bx,1
        and  bx,0FFFEh
        mov  [tx],bx
        mov  word [ty],22
        mov  al,[anim]
        and  al,3
        mov  bl,al
        xor  bh,bh
        mov  al,[WINCLR+bx]
        mov  [tclr],al
        mov  byte [tscale],2
        mov  byte [tshad],1
        call PRINT8
        mov  byte [tscale],1
        mov  bx,136             ; the podium
        mov  dx,108
        mov  cx,48
        mov  si,14
        mov  al,4
        call FILLBOX
        mov  bx,138
        mov  dx,108
        mov  cx,44
        mov  si,2
        mov  al,12
        call FILLBOX
        mov  word [tx],156
        mov  word [ty],111
        mov  byte [tclr],14
        mov  al,'1'
        call PUTC8
        mov  al,[winner]
        cmp  al,MAXP
        jae  .none
        xor  ah,ah
        mov  cx,PSIZE
        mul  cx
        add  ax,players
        mov  [wptr],ax
        mov  bx,ax
        mov  al,[bx+P_LOOK]
        call MKBIG              ; his big picture, in his colours
        mov  si,[bigat]
        mov  bl,[anim]          ; he jumps
        and  bx,7
        mov  al,[BOUNCE+bx]
        cbw
        mov  dx,76
        sub  dx,ax
        mov  bx,144
        call DRAWSPR
        mov  si,[wptr]          ; his name, big
        add  si,P_NAME
        mov  di,wname
        mov  cx,8
        rep  movsb
        mov  byte [di],0
        mov  si,wname
        mov  dx,128
        call BANNER
        mov  di,wline           ; + what he got this level
        mov  byte [di],'+'
        inc  di
        mov  bx,[wptr]
        mov  ax,[bx+P_GAIN]
        or   ax,ax
        jns  .g
        xor  ax,ax
.g:     mov  cl,1
        push di
        call NUMSTR
        pop  di
.cp:    lodsb
        stosb
        or   al,al
        jnz  .cp
        dec  di
        mov  si,TLEVPTS
.cp2:   lodsb
        stosb
        or   al,al
        jnz  .cp2
        mov  si,wline
        mov  dx,144
        call BANNER
.none:  mov  word [pidx],players ; the others, a line each
        mov  word [ty],160
        mov  byte [pslot],0
.o:     mov  bx,[pidx]
        cmp  byte [bx+P_ON],0
        je   .on
        mov  al,[pslot]
        and  ax,1
        mov  cx,100
        mul  cx
        add  ax,64
        mov  [tx],ax
        mov  byte [tclr],15
        mov  si,[pidx]
        add  si,P_NAME
        call PNAME
        mov  al,[pslot]
        and  ax,1
        mov  cx,100
        mul  cx
        add  ax,104
        mov  [tx],ax
        mov  byte [tclr],14
        mov  al,'+'
        call PUTC4
        mov  bx,[pidx]
        mov  ax,[bx+P_GAIN]
        mov  cl,1
        call PSNUM4
        inc  byte [pslot]
        test byte [pslot],1
        jnz  .on
        add  word [ty],6
.on:    add  word [pidx],PSIZE
        cmp  word [pidx],players+MAXP*PSIZE
        jb   .o
        ret

; MKBIG - the winner's man, look AL, twice as big at sseg:[bigat] -
; compiled from the raw 16 px one unless it is that look already
MKBIG:  cmp  al,[biglook]
        je   .r
        mov  [biglook],al
        xor  ah,ah
        shl  ax,1
        shl  ax,1
        mov  bp,LOOKS
        add  bp,ax              ; his four colours
        push es
        mov  es,[sseg]
        mov  di,[bigat]
        mov  si,rawman
        call COMPILE2
        pop  es
.r:     ret

; ------------------------------------------------------------------
;  The crow: now and then one flies in, sits on a wall, caws, flies
;  off.  This machine's alone (nobody else needs to see the same one).
;  BIRDTICK from TIMERS; DRAWBIRD in the frame.
; ------------------------------------------------------------------
BIRDTICK:
        cmp  byte [view],2
        je   .r                 ; straight down only
        cmp  byte [phase],3
        je   .r
        mov  ax,[now]
        mov  dx,ax
        sub  dx,[bwhen]
        mov  [bwhen],ax
        cmp  dx,8
        jbe  .dt
        mov  dx,8
.dt:    mov  [bdt],dx
        mov  al,[bst]
        or   al,al
        jnz  .fly
        mov  ax,[now]           ; none: is it time?
        sub  ax,[bnext]
        js   .r
        call RND
        mov  al,ah
        xor  ah,ah
        shl  ax,1
        shl  ax,1
        add  ax,400             ; the next one 22..78 s after this
        add  ax,[now]
        mov  [bnext],ax
        mov  byte [btries],24   ; a wall to sit on, on the screen
.try:   call RND
        mov  al,ah
        xor  ah,ah
        mov  bl,[lvw]
        div  bl
        mov  cl,ah              ; a column
        call RND
        mov  al,ah
        xor  ah,ah
        mov  bl,[lvh]
        div  bl                 ; AH = a row
        mov  al,ah
        xor  ah,ah
        push cx
        mov  cl,5
        shl  ax,cl
        pop  cx
        add  al,cl
        mov  bx,ax
        test byte [grid+bx],G_WALL
        jz   .again
        cmp  bx,[gatecell]
        je   .again
        mov  ax,bx
        call CELLXY
        add  ax,[ox]
        add  dx,[oy]
        cmp  ax,0
        jl   .again
        cmp  ax,320-16
        jg   .again
        cmp  dx,PFTOP+8
        jl   .again
        mov  [btx],ax
        mov  [bty],dx
        mov  word [bx_],-16     ; in from the left or the right
        test word [now],1
        jz   .side
        mov  word [bx_],320
.side:  mov  word [by_],PFTOP
        mov  byte [bst],1
        mov  byte [dirty],1
        ret
.again: dec  byte [btries]
        jnz  .try
        ret
.fly:   cmp  al,2
        je   .sit
        call .move              ; flying in, or out
        jnc  .r
        cmp  byte [bst],3
        je   .gone
        mov  byte [bst],2       ; landed
        call RND
        mov  al,ah
        and  ax,63
        add  ax,80              ; sits 4..8 s
        mov  [bclk],ax
        shr  ax,1
        mov  [bcaw],ax          ; and caws again half way
        mov  al,SF_CAW
        call SFX
        ret
.gone:  mov  byte [bst],0
        mov  byte [dirty],1
        ret
.sit:   mov  ax,[bdt]
        sub  [bclk],ax
        jg   .s1
        mov  byte [bst],3       ; off again, the other way
        mov  ax,[bx_]
        mov  word [btx],-24
        cmp  ax,160
        jl   .s0
        mov  word [btx],330
.s0:    mov  word [bty],PFTOP-24
        mov  byte [dirty],1
        ret
.s1:    mov  ax,[bclk]
        cmp  ax,[bcaw]
        jg   .r
        mov  word [bcaw],-1     ; once
        mov  al,SF_CAW
        call SFX
.r:     ret
; .move - toward btx, bty: 3 px a tick across, 2 down; CF=1 there
.move:  mov  byte [dirty],1
        mov  ax,[bdt]
        mov  cx,ax
        shl  cx,1
        add  cx,ax              ; 3 a tick
        mov  ax,[btx]
        sub  ax,[bx_]
        call .step
        add  [bx_],ax
        mov  bx,ax
        mov  cx,[bdt]
        shl  cx,1               ; 2 a tick
        mov  ax,[bty]
        sub  ax,[by_]
        call .step
        add  [by_],ax
        or   ax,bx
        jnz  .on
        mov  ax,[btx]
        cmp  ax,[bx_]
        jne  .on
        stc
        ret
.on:    clc
        ret
; .step - AX = the way left, CX = the most: AX = this step
.step:  or   ax,ax
        jns  .sp
        neg  ax
        cmp  ax,cx
        jbe  .sn
        mov  ax,cx
.sn:    neg  ax
        ret
.sp:    cmp  ax,cx
        jbe  .sr
        mov  ax,cx
.sr:    ret

DRAWBIRD:
        cmp  byte [bst],0
        je   .r
        mov  ax,K_BD0           ; sitting
        cmp  byte [bst],2
        je   .k
        mov  ax,[now]
        and  ax,2
        shr  ax,1
        add  ax,K_BD1           ; wings up, wings down
.k:     mov  bx,[bx_]
        and  bx,0FFFEh
        mov  dx,[by_]
        call DRAWK
        mov  ax,[bx_]           ; the evening over it too
        and  ax,0FFFEh
        mov  bx,ax
        add  bx,[cell]
        mov  cx,[by_]
        mov  dx,cx
        add  dx,[cell]
        jmp  DUSK
.r:     ret

; ------------------------------------------------------------------
;  TITLE - the name, a piece of the castle, the keys; the wire's news
;  comes under it (JOINMSG)
; ------------------------------------------------------------------
TITLE:  mov  word [tbase],0
        mov  word [clipt],0
        mov  word [clipb],200
        xor  ax,ax
        mov  dx,200
        xor  bl,bl
        call FILLROWS
        xor  si,si
        call SETSZ              ; 16 px pictures
        mov  si,TVIG            ; the castle: db x/16, y/16... kind
.v:     lodsb
        cmp  al,0FFh
        je   .text
        xor  ah,ah
        mov  cl,4
        shl  ax,cl
        mov  bx,ax              ; x
        lodsb
        xor  ah,ah
        shl  ax,cl
        mov  dx,ax              ; y
        lodsb
        xor  ah,ah
        push si
        cmp  al,K_MAN
        jne  .k
        lodsb                   ; a man: his look follows
        pop  si
        inc  si
        push si
        xor  ah,ah
        shl  ax,1
        mov  si,ax
        add  si,[mantrow]
        mov  si,[si]
        call DRAWP
        pop  si
        jmp  .v
.k:     call DRAWK
        pop  si
        jmp  .v
.text:  mov  si,TNAME           ; the name, big, gold
        call STRLEN
        mov  ax,cx
        mov  cl,4
        shl  ax,cl
        mov  bx,320
        sub  bx,ax
        shr  bx,1
        and  bx,0FFFEh
        mov  [tx],bx
        mov  word [ty],6
        mov  byte [tclr],14
        mov  byte [tscale],2
        mov  byte [tshad],1
        call PRINT8
        mov  byte [tscale],1
        mov  byte [tshad],0
        mov  si,TLINES          ; the keys, in the small letters
.l:     lodsw
        cmp  ax,0FFFFh
        je   .done
        mov  [tx],ax
        lodsw
        mov  [ty],ax
        lodsb
        mov  [tclr],al
        call PRINT4
        jmp  .l
.done:  ret

; JOINMSG - line SI under the title, a spinner after it, on the screen
JOINMSG:push si
        mov  ax,1680h
        int  2Fh                ; yield: a wait must not starve the host
        mov  ax,184
        mov  dx,200
        xor  bl,bl
        call FILLROWS
        pop  si
        mov  dx,188
        call BANNER
        call TICK
        mov  cl,2
        shr  ax,cl              ; a quarter of a second a step
        and  ax,3
        mov  bx,ax
        mov  al,[SPIN+bx]
        call PUTC8
        jmp  BLIT

; the scene's tables
SIZES   db 16,12,10,8,6
NEIGH8  dw -1,-1, 0,-1, 1,-1, -1,0, 1,0, -1,1, 0,1, 1,1
; per turn, the grid's step for the screen's up, right, down, left
SDIR    db 0,-1, 1,0, 0,1, -1,0          ; turn 0
        db -1,0, 0,-1, 1,0, 0,1          ; a quarter
        db 0,1, -1,0, 0,-1, 1,0          ; a half
        db 1,0, 0,1, -1,0, 0,-1          ; three quarters
; the park: up to this scatter, this kind, this many cells wide
; the four parts of the park, by the land's height (LAND): wet ground,
; the garden, the wood, the pines
ZWET    db 22,K_PND,2, 40,K_BSH,1, 60,K_FLW,1, 0FFh
ZGARDEN db 6,K_FN0,2, 12,K_STA,1, 18,K_LMP,1, 22,K_WEL,1, 34,K_FLB,2
        db 44,K_HED,2, 66,K_FLW,1, 80,K_BSH,1, 84,K_ROK,1, 0FFh
ZWOOD   db 30,K_OAK,2, 80,K_TRE,1, 100,K_BSH,1, 106,K_ROK,1, 0FFh
ZPINE   db 90,K_PIN,1, 105,K_ROK,1, 115,K_TRE,1, 0FFh
; DUSK's ordered dither: a 4x4 Bayer matrix, the order the pixels darken
BAYER   db 0,8,2,10, 12,4,14,6, 3,11,1,9, 15,7,13,5
WINCLR  db 14,15,14,12
BOUNCE  db 0,5,9,11,11,9,5,0    ; how high he is, frame by frame
; the title's castle: db column, row (16 px cells), kind [, look]
TVIG    db 0,5,K_GRS, 1,5,K_GRS, 2,5,K_GRS, 3,5,K_GRS, 4,5,K_GRS, 5,5,K_GRS
        db 6,5,K_GRS, 7,5,K_GRS, 8,5,K_GRS, 9,5,K_GRS, 10,5,K_GRS, 11,5,K_GRS
        db 12,5,K_GRS, 13,5,K_GRS, 14,5,K_GRS, 15,5,K_GRS, 16,5,K_GRS, 17,5,K_GRS
        db 18,5,K_GRS, 19,5,K_GRS
        db 0,6,K_MO0, 1,6,K_MO1, 2,6,K_MO2, 3,6,K_MO3, 4,6,K_MO0, 5,6,K_MO1
        db 6,6,K_MO2, 7,6,K_MO3, 8,6,K_MO0, 9,6,K_BRV, 10,6,K_MO2, 11,6,K_MO3
        db 12,6,K_MO0, 13,6,K_MO1, 14,6,K_MO2, 15,6,K_MO3, 16,6,K_MO0, 17,6,K_MO1
        db 18,6,K_MO2, 19,6,K_MO3
        db 0,7,K_WA1, 1,7,K_WA2, 2,7,K_WA3, 3,7,K_WA4, 4,7,K_WA1, 5,7,K_WA3
        db 6,7,K_WA2, 7,7,K_WA4, 8,7,K_WA1, 9,7,K_GT2, 10,7,K_WA3, 11,7,K_WA2
        db 12,7,K_WA1, 13,7,K_WA4, 14,7,K_WA3, 15,7,K_WA2, 16,7,K_WA1, 17,7,K_WA4
        db 18,7,K_WA2, 19,7,K_WA3
        db 0,7,K_FGN, 1,7,K_FGN, 2,7,K_FGN, 3,7,K_FGN, 4,7,K_FGN, 5,7,K_FGN
        db 6,7,K_FGN, 7,7,K_FGN, 8,7,K_FGN, 10,7,K_FGN, 11,7,K_FGN, 12,7,K_FGN
        db 13,7,K_FGN, 14,7,K_FGN, 15,7,K_FGN, 16,7,K_FGN, 17,7,K_FGN, 18,7,K_FGN
        db 19,7,K_FGN
        db 1,5,K_OAK, 4,5,K_PIN, 6,5,K_BSH, 12,5,K_FN0, 15,5,K_STA, 17,5,K_TRE
        db 3,7,K_TWR, 16,7,K_TWR, 7,7,K_TR0, 11,7,K_TR1
        db 2,8,K_CA1, 4,8,K_BOX, 6,8,K_CA2, 7,8,K_MAN,0, 9,8,K_MAN,1, 11,8,K_CA3
        db 13,8,K_GOL, 13,8,K_BOG, 15,8,K_CA1, 17,8,K_DI2
        db 0,9,K_WA2, 1,9,K_WA1, 2,9,K_WA4, 3,9,K_WA3, 4,9,K_WA2, 5,9,K_WA1
        db 6,9,K_WA3, 7,9,K_WA4, 8,9,K_WA2, 9,9,K_WA1, 10,9,K_WA2, 11,9,K_WA3
        db 12,9,K_WA4, 13,9,K_WA1, 14,9,K_WA2, 15,9,K_WA3, 16,9,K_WA1, 17,9,K_WA4
        db 18,9,K_WA2, 19,9,K_WA1
        db 0FFh
