; TOWN.INC - part of WIRE CITY (included from OWLFLY3.ASM, after SYM.INC)
; ============================================================================
;  THE FIFTH SEGMENT, opened 2026-08-03 because the main segment had
;  TWENTY-SIX bytes left and the rule in this project is to open a segment,
;  not to shave bytes. The arrangement is SKYSEG's, UISEG's and SYMSEG's,
;  copied: PARA aligned, padded to claim its whole window so the linker
;  parks the next thing where the loader expects, and an assemble-time
;  guard that refuses to overflow.
;  Layout now: CODE at CS+0, SKYSEG CS+1000h, UISEG CS+1200h, SYMSEG
;  CS+1600h, TOWNSEG CS+1800h, VIDSEG CS+1A00h (24K) - see OWLFLY3.ASM,
;  which moved the back buffer up to CS+2000h to make room.
;
;  What lives here: THE TOWN. The windows on the buildings, and the traffic
;  in the streets. Both earned the move the way the scope symbols did -
;  they are pure drawing, every input already in a main-segment variable,
;  so they can live anywhere and the things that cannot should not.
;
;  Code here runs with DS = the main segment and cannot near-call into
;  CODE: it reaches home through the thunks in PLANES.INC (PROJPTF,
;  SCANPLYF, PUTPIXF).
;
;  Far doors: WINFACEF (glaze a wall), TRAFFICF / CARHITF / CCLOCKF (the
;  vehicles), and - since the streets started being planned by the BLOCK -
;  BLKTABF (bake the block table, once, after DSGEN), BLKINFF (what kind of
;  block is this cell in), ROADOKF (should this avenue cell be paved) and
;  ROADYF (bend a paved quad onto the ground it lies on).
;
;  Developed in LAB\HOUSE.COM, which is where to go to change any of it -
;  it holds one city block still and lets you walk round it. See
;  LAB\README.md.
; ============================================================================

segment TOWNSEG

label TOWNBASE byte   ; zero, for the window guard below

KTIM    dw NKILL dup(0)

; KTICK - one tick of mourning. Clobbers AX,BX,CX.
KTICK:  xor  bx,bx
        mov  cx,NKILL
.t:    cmp  word [cs:KTIM+bx],0
        je   .tn
        dec  word [cs:KTIM+bx]
.tn:   add  bx,2
        loop .t
        ret

; ============================================================================
;  CCLOCKF - the traffic clock. The lights must be driven by TIME, not by
;  frames: run them off the frame counter and the signal cycle becomes a
;  measurement of the renderer. That is not hypothetical - in the lab the
;  scene got heavy enough to drop to a dozen frames a second and a
;  twenty-second cycle quietly became a minute and a half, so the cross
;  street never went green.
;  The game already measures everything needed: lasttk is the BIOS tick,
;  fcnt the frames into it and fprev how long the last one took - the same
;  three LERPSET draws the camera between ticks with. Time from the clock,
;  smoothness from the frame rate, neither borrowing from the other.
; ============================================================================
CCLOCKF:
        mov  ax,[lasttk]
        mov  bx,ax
        sub  bx,[ctick]         ; whole ticks since we last looked
        jz   .same
        cmp  bx,64              ; a wrap or a very long stall: take one tick
        jbe  .dt               ; rather than leap a thousand
        mov  bx,1
.dt:   mov  [ctick],ax
        push bx
        call KTICK              ; the wrecks burn down on the clock too
        pop  bx
        mov  ax,bx
        mov  bx,TKSUB
        imul bx
        sub  ax,[cfrac]         ; minus what interpolation already advanced
        mov  [cstep],ax
        mov  word [cfrac],0
        jmp  .adv
.same: mov  ax,[fprev]
        cmp  ax,1
        jge  .r1
        mov  ax,1
.r1:   mov  bx,ax
        mov  ax,[fcnt]
        mov  cx,TKSUB
        imul cx
        idiv bx
        cmp  ax,TKSUB-1
        jle  .f1
        mov  ax,TKSUB-1         ; never run past the tick we are inside
.f1:   mov  bx,ax
        sub  ax,[cfrac]
        mov  [cstep],ax
        mov  [cfrac],bx
.adv:  mov  ax,[cstep]
        cmp  ax,0
        jle  .d
        add  [cartf],ax
.w:    cmp  word [cartf],CART
        jb   .d
        sub  word [cartf],CART
        add  word [caradv],8
        jmp  .w
.d:    retf

; ============================================================================
;  THE BLOCK TABLE - one byte per 8x8-cell block, the whole toroidal world
;  in 32x32 of them, baked once when the heightmap is built.
;
;  WHY A TABLE AT ALL. Every question about a block used to be answered by
;  hashing the CELL that asked. That is fine while the answer only has to be
;  CONSISTENT - and wrong the moment two cells of the SAME block are allowed
;  to disagree. Which is exactly what broke the streets. HBLD asked the
;  per-cell zoning first, and the zoning reads a height node every four
;  cells; wherever one node inside a city block wandered out of the 120..167
;  band its cells fell through to "the terrain mesh paints this", and the
;  avenue running past them lost two cells in the middle. From the air the
;  city did not read as a city - it read as street fragments with gaps, and
;  no line round the outside of it at all.
;
;  So the BLOCK decides, once, for all sixty-four of its cells, and the
;  answer is written down. One byte:
;     bits 0..3   the superblock hash & 15 - the 3-in-16 clustering test
;     bits 4..5   the district (0/3 residential, 1 downtown, 2 industry)
;     bit  6      BLKCITY: the block's CENTRE node is in the city band
;  Bits 0..5 sit exactly where HBLD's old SBHASH put them, so the building
;  path reads this byte through BLKINFF and carries on unchanged - and there
;  is now ONE place in the program that decides whether a block is a block.
;
;  1024 bytes, in a segment that was padding out its window with zeroes
;  anyway. The rule in this project is to open a segment, not to shave.
; ============================================================================
BLKCITY = 40h

; ---- BLKTABF - bake all 1024 blocks. Called once, after DSGEN. ------------
BLKTABF:
        xor  si,si              ; block i
.bi:   xor  di,di              ; block j
.bj:   mov  ax,si
        mov  bx,di
        call BLKHASH
        mov  bx,ax
        mov  cl,4
        shr  bx,cl
        and  bx,3               ; the district, back into bits 4..5
        mov  cl,4
        shl  bx,cl
        and  ax,15              ; the clustering nibble
        or   ax,bx
        push ax
        mov  ax,si              ; the block's CENTRE node: (2i+1, 2j+1).
        add  ax,ax              ; A block is 8 cells, a height node is 4,
        inc  ax                 ; so a block spans exactly 2x2 nodes and
        and  ax,63              ; this is the one at its middle.
        mov  cl,6
        shl  ax,cl
        mov  bx,di
        add  bx,bx
        inc  bx
        and  bx,63
        add  bx,ax
        mov  al,[HMAP+bx]       ; DS is the main segment in here
        cmp  al,120
        jb   .nz               ; the same band GETZONE calls city, read
        cmp  al,168             ; once for the block instead of per cell
        jae  .nz
        pop  ax
        or   ax,BLKCITY
        jmp  .put
.nz:   pop  ax
.put:  mov  bx,si
        mov  cl,5
        shl  bx,cl
        add  bx,di
        mov  [cs:BLKT+bx],al
        inc  di
        cmp  di,32
        jb   .bj
        inc  si
        cmp  si,32
        jb   .bi
        retf

; ---- BLKHASH - the superblock hash for block (AX=i, BX=j) -> AX.
; This is WORLD2.INC's old SBHASH with the >>3 already done by the caller,
; character for character. It has to stay that way: change one and the
; buildings and the streets are planned by two different worlds.
BLKHASH:
        push si
        and  ax,31
        mov  si,ax
        mov  ax,bx
        and  ax,31
        mov  bx,ax
        mov  ax,331
        mul  si
        mov  si,ax
        mov  ax,769
        mul  bx
        add  ax,si
        mov  bx,ax
        mov  cl,4
        shr  bx,cl
        xor  ax,bx
        pop  si
        ret

; ---- BLKCTYF - BLKCTY through a far door, for the MAP. -------------------
;  The baked minimap asks this once per node at startup: is the block under
;  this node BUILT? It used to answer that question itself, out of the height
;  band, and got a different answer from the one the buildings and the scope
;  were using - see the note over MMAPGENF. There is one town in this game
;  and this is where it is decided.
;   in: AX = block i, BX = block j.  out: CF=1 built. RETF leaves flags alone.
BLKCTYF:
        call BLKCTY
        retf

; ---- BLKINFF - the block byte for the cell in [gi],[gj].  out: AX --------
BLKINFF:
        mov  ax,[gi]
        mov  bx,[gj]
        mov  cl,3
        shr  ax,cl
        shr  bx,cl
        call BLKGETN
        retf

; BLKGETN - the byte for BLOCK (AX=i, BX=j) -> AX. Clobbers BX,CX.
BLKGETN:
        and  ax,31
        mov  cl,5
        shl  ax,cl
        and  bx,31
        add  bx,ax
        mov  al,[cs:BLKT+bx]
        xor  ah,ah
        ret

; BLKCTY - is block (AX=i, BX=j) a BUILT city block?  CF=1 = yes.
; Preserves AX, BX and DX; clobbers CX.
BLKCTY: push ax
        push bx
        call BLKGETN
        test al,BLKCITY
        jz   .no
        and  al,15
        cmp  al,3               ; the same 3-in-16 that plants the buildings
        jae  .no
        pop  bx
        pop  ax
        stc
        ret
.no:   pop  bx
        pop  ax
        clc
        ret

; CELLH - raw heightmap value under CELL (AX=gi, BX=gj) -> AL.  The engine's
; GETH, which lives in the main segment where this code cannot call.
CELLH:  mov  cl,2
        shr  bx,cl
        and  bx,63
        push bx
        shr  ax,cl
        and  ax,63
        mov  cl,6
        shl  ax,cl
        pop  bx
        add  bx,ax
        mov  al,[HMAP+bx]
        ret

; ============================================================================
;  ROADOKF - cell [gi],[gj] is on the avenue grid (ISROAD said so); should it
;  actually be PAVED?  CF=1 = yes.
;
;  A ROAD IS A MADE THING. It is laid out straight, in long runs at right
;  angles, and it does not stop because the ground under twelve feet of it
;  is a little high. That is the whole argument for deciding this at block
;  level: the avenues of a city block run END TO END, all eight cells, and
;  the terrain is left to do what terrain does underneath them.
;
;  AND THE RING FALLS OUT OF IT FOR FREE. ISROAD puts the two-cell strip on
;  the WEST and SOUTH edges of each block, so a block only owns half of its
;  own frame - the other two sides are the strips belonging to the blocks
;  north and east of it. So the question is not "is MY block built" but "is
;  ANY block this strip touches built", and the answer paves the far kerb of
;  every outermost block as well. A cluster of city blocks comes out wearing
;  a closed belt of avenue, 2048-unit straights and square corners, and the
;  traffic model never notices: every stretch is still axis-aligned, still
;  eight cells to a green, so the lanes, the global slots and the identity
;  CARV*CARG = one block all hold exactly as before.
;
;  The sea is the one thing that still cuts a street. A causeway standing on
;  the water at height zero reads worse than an honest gap.
; ============================================================================
ROADOKF:
        push dx                 ; HBLD's contract says it clobbers AX,BX,CX,SI
                                ; and six call sites believe it; do not widen
                                ; that from inside a far door
        mov  ax,[gi]
        mov  bx,[gj]
        call CELLH
        cmp  al,88
        jb   .no               ; below sea level: no road, block or no block
        mov  ax,[gi]
        mov  cl,3
        shr  ax,cl              ; block i
        mov  bx,[gj]
        shr  bx,cl              ; block j
        mov  dx,ax              ; keep it: the west test moves AX
        call BLKCTY
        jc   .yes              ; our own block is city: the avenue runs
        mov  cx,[gi]            ; a north-south strip is this block's west
        and  cx,7               ; edge AND the east edge of the block before
        cmp  cx,2               ; it - and that one's outermost avenue is
        jae  .w                ; what closes the ring on this side
        dec  ax
        call BLKCTY
        jc   .yes
.w:    mov  cx,[gj]            ; the same again along the other axis
        and  cx,7
        cmp  cx,2
        jae  .no
        dec  bx
        call BLKCTY             ; AX is already i-1 if we came off a west
        jc   .yes              ; strip, so this is the DIAGONAL block - the
        cmp  ax,dx              ; one cell that would otherwise leave a
        je   .no               ; two-by-two notch in the ring's corner
        mov  ax,dx
        call BLKCTY
        jc   .yes
.no:   pop  dx                 ; POP leaves the flags alone, so the carry
        clc                     ; can be set either side of it
        retf
.yes:  pop  dx
        stc
        retf

; ============================================================================
;  ROADYF - sit the quad FACETOPC has just built ON THE GROUND, corner by
;  corner.
;
;  A road cell used to take ONE height: GETH at the cell, which is the
;  height NODE the cell happens to fall in, held flat across all 256 units.
;  The terrain under it is not flat - the mesh interpolates between nodes
;  1024 apart - so on any slope that flat cell is a paving slab hovering
;  over the hill at one end and buried in it at the other. Which is exactly
;  what the pilot photographed. The road has to interpolate the same way the
;  ground does, and it has to do it PER CORNER.
;
;  AND IT COMES OUT CHEAP, because these corners are not arbitrary points. A
;  cell edge is a multiple of 256 and a node is 1024, so every corner lands
;  on a QUARTER of a node cell - the weights are only ever 0/4, 1/4, 2/4,
;  3/4, 4/4. Four node heights fetched once, then two multiplies and an
;  arithmetic shift per corner. No divides, no second trip to the map, and
;  the whole quad stays inside ONE node cell (a 2x2 group is anchored on an
;  even cell, so it spans two quarters, never a boundary).
;
;  in:  bwx0/bwz0/bwx1/bwz1 - the quad's world bounds, as ROTCUL left them
;  out: IY[0..3] - ground height at each corner, lifted ROADLIFT clear of
;       the terrain quad and made camera-relative, in ROTCUL's corner order
;       (0 = x0z0, 1 = x1z0, 2 = x1z1, 3 = x0z1)
; ============================================================================
ROADYF:
        push si
        push di
        push dx
        mov  ax,[bwx0]          ; which cell the west edge is, and which
        add  ax,BIAS            ; quarter of its node that puts it in
        mov  cl,8
        shr  ax,cl
        mov  si,ax
        and  ax,3
        mov  [cs:RYA],ax
        mov  ax,[bhw]           ; 128 -> one cell wide, 256 -> two; the
        add  ax,127             ;  flat patches ride this door too now,
        mov  cl,7               ;  and their 116 must round UP to the
        shr  ax,cl              ;  quarter it covers, not down to nothing
        add  ax,[cs:RYA]
        mov  [cs:RYA1],ax       ; the east edge, 1..4 quarters along
        mov  ax,[bwz0]
        add  ax,BIAS
        mov  cl,8
        shr  ax,cl
        mov  di,ax
        and  ax,3
        mov  [cs:RYB],ax
        mov  ax,[bhd]
        add  ax,127             ; the same rounding on the other axis
        mov  cl,7
        shr  ax,cl
        add  ax,[cs:RYB]
        mov  [cs:RYB1],ax
        mov  cl,2
        shr  si,cl              ; node x = cell >> 2
        shr  di,cl              ; node z
        mov  ax,si              ; ---- the four node heights, once
        mov  bx,di
        call NODEH
        mov  [cs:RYH],ax
        mov  ax,si
        inc  ax
        mov  bx,di
        call NODEH
        mov  [cs:RYH+2],ax
        mov  ax,si
        mov  bx,di
        inc  bx
        call NODEH
        mov  [cs:RYH+4],ax
        mov  ax,si
        inc  ax
        mov  bx,di
        inc  bx
        call NODEH
        mov  [cs:RYH+6],ax
        mov  ax,[cs:RYA]        ; ---- and the four corners
        mov  bx,[cs:RYB]
        call RYLERP
        mov  [IY],ax
        mov  ax,[cs:RYA1]
        mov  bx,[cs:RYB]
        call RYLERP
        mov  [IY+2],ax
        mov  ax,[cs:RYA1]
        mov  bx,[cs:RYB1]
        call RYLERP
        mov  [IY+4],ax
        mov  ax,[cs:RYA]
        mov  bx,[cs:RYB1]
        call RYLERP
        mov  [IY+6],ax
        pop  dx
        pop  di
        pop  si
        retf

; NODEH - world height of heightmap node (AX=x, BX=z) -> AX.  HGET and
; WORLDH in one, written out here because both live in the main segment
; where this code cannot near-call. Clobbers BX,CX.
NODEH:  and  ax,63
        mov  cl,6
        shl  ax,cl
        and  bx,63
        add  bx,ax
        mov  al,[HMAP+bx]
        xor  ah,ah
        sub  ax,88              ; ...WORLDH: sea floor flat, mountains steep
        jns  .w0
        xor  ax,ax
        ret
.w0:   mov  bx,5
        imul bx
        cmp  ax,560
        jle  .w1
        mov  bx,ax
        sub  bx,560
        add  ax,bx
.w1:   ret

; RYLERP - bilinear the four node heights at (AX=a, BX=b), a and b being
; QUARTERS of a node, 0..4.  out: AX, camera-relative and lifted.
RYLERP: call RYLERPR
        add  ax,ROADLIFT
        sub  ax,[camy]
        ret

; RYLERPR - the same bilinear in plain WORLD height: what a foundation
; wants. CELLYF sums four of these, and sums of the lifted camera-relative
; answers would overflow a word at altitude.
RYLERPR:
        mov  [cs:RYTA],ax
        mov  [cs:RYTB],bx
        mov  ax,[cs:RYH+2]      ; ha = h00 + (h10-h00)*a/4
        sub  ax,[cs:RYH]
        imul word [cs:RYTA]
        mov  cl,2
        sar  ax,cl
        add  ax,[cs:RYH]
        mov  [cs:RYTH],ax
        mov  ax,[cs:RYH+6]      ; hb = h01 + (h11-h01)*a/4
        sub  ax,[cs:RYH+4]
        imul word [cs:RYTA]
        mov  cl,2
        sar  ax,cl
        add  ax,[cs:RYH+4]
        sub  ax,[cs:RYTH]       ; h = ha + (hb-ha)*b/4
        imul word [cs:RYTB]
        mov  cl,2
        sar  ax,cl
        add  ax,[cs:RYTH]
        ret

CELLYF:
        mov  cx,1               ; one cell...
        cmp  word [bstreet],0
        jne  CLYGO
        inc  cx                 ; ...or the solid building's 2x2 plot
CLYGO:
        push si
        push di
        mov  ax,[gi]
        mov  si,ax
        and  ax,3
        mov  [cs:RYA],ax
        add  ax,cx
        cmp  ax,4
        jle  .ca
        mov  ax,4               ; leaning past the node: take its edge,
.ca:   mov  [cs:RYA1],ax       ;  never the mirrored hill beyond it
        mov  ax,[gj]
        mov  di,ax
        and  ax,3
        mov  [cs:RYB],ax
        add  ax,cx
        cmp  ax,4
        jle  .cb
        mov  ax,4
.cb:   mov  [cs:RYB1],ax
        mov  cl,2
        shr  si,cl              ; node x = cell >> 2
        shr  di,cl              ; node z
        mov  ax,si              ; ---- the four node heights, once
        mov  bx,di
        call NODEH
        mov  [cs:RYH],ax
        mov  ax,si
        inc  ax
        mov  bx,di
        call NODEH
        mov  [cs:RYH+2],ax
        mov  ax,si
        mov  bx,di
        inc  bx
        call NODEH
        mov  [cs:RYH+4],ax
        mov  ax,si
        inc  ax
        mov  bx,di
        inc  bx
        call NODEH
        mov  [cs:RYH+6],ax
        ; ---- the four corners, raw: the lowest, and the sum for the mean
        mov  ax,[cs:RYA]
        mov  bx,[cs:RYB]
        call RYLERPR
        mov  si,ax              ; the min so far...
        mov  di,ax              ; ...and the sum (world heights: no overflow)
        mov  ax,[cs:RYA1]
        mov  bx,[cs:RYB]
        call RYLERPR
        add  di,ax
        cmp  ax,si
        jge  .m1
        mov  si,ax
.m1:   mov  ax,[cs:RYA1]
        mov  bx,[cs:RYB1]
        call RYLERPR
        add  di,ax
        cmp  ax,si
        jge  .m2
        mov  si,ax
.m2:   mov  ax,[cs:RYA]
        mov  bx,[cs:RYB1]
        call RYLERPR
        add  di,ax
        cmp  ax,si
        jge  .m3
        mov  si,ax
.m3:   mov  ax,di
        add  ax,2               ; the centre: the rounded mean of four
        mov  cl,2
        shr  ax,cl
        mov  dx,ax
        mov  ax,si              ; the foundation
        pop  di
        pop  si
        retf

RYH     dw 4 dup(0)             ; h00 h10 h01 h11 of the node cell
RYA     dw 0                    ; the quad's corners, in quarters of a node
RYA1    dw 0
RYB     dw 0
RYB1    dw 0
RYTA    dw 0                    ; RYLERP's arguments, where IMUL can reach
RYTB    dw 0
RYTH    dw 0

BLKT    db 1024 dup(0)          ; 32x32 blocks, baked by BLKTABF

; ============================================================================
;  THE AERODROMES, PAVED.
;
;  Six flat slabs a field: the concrete, two edge lines, the centreline and
;  a threshold bar at each end. Every one is the same shape the streets and
;  the buildings use - a world footprint through ROTCUL, the top quad off
;  FACETOPC, FACEFILL - so nothing new had to be taught to the rasteriser.
;
;  THE CORNERS ARE NOT BENT. ROADYF exists to sit a quad on a slope corner
;  by corner, and it cannot be used here for two reasons, both good: it
;  assumes the quad lies inside ONE heightmap node cell and a strip spans
;  three, and there is nothing to bend to. The ground under an aerodrome was
;  stamped level by AFINITF before the world was baked, so all four corners
;  are at one height and that height is written straight into bry1. The
;  flattening pays for itself again.
;
;  The markings ride one unit above the concrete AND are drawn after it -
;  belt and braces, because this engine sorts by painter and a slab that
;  ties on depth with the one under it would flicker between frames.
; ============================================================================
AFDRAWF:
        mov  word [afi],0
.f:    mov  bx,[afi]
        add  bx,bx
        mov  [cs:afq],bx        ; the word index, kept: everything below
                                ;  clobbers BX and wants it again
        ; ---- the CHEAP cull first, on BOTH axes, the way ROADCELL does it.
        ; Culling on minrz alone is what let the first version paint half the
        ; sky: minrz bounds how far the strip is AHEAD and says nothing about
        ; how far it is to the SIDE, and a field walks up to twelve nodes to
        ; find flat ground. Beside the camera and level with it is exactly
        ; the ratio of rx to rz that PROJPT has to clamp. ----
        mov  ax,[afx+bx]
        sub  ax,[camx]
        or   ax,ax
        jns  .cx
        neg  ax
.cx:   cmp  ax,AFVIS
        jg   .n
        mov  ax,[afz+bx]
        sub  ax,[camz]
        or   ax,ax
        jns  .cz
        neg  ax
.cz:   cmp  ax,AFVIS
        jg   .n
        mov  bx,[cs:afq]
        mov  ax,[afx+bx]
        mov  [wcx],ax
        mov  ax,[afz+bx]
        mov  [wcz],ax
        mov  word [bhw],AFW ; ---- the CULL is done on the whole strip,
        mov  word [bhd],AFLEN ; and only the cull: this rectangle is far
        call CODE:ROTCULF   ;  too big to hand to the rasteriser
        jc   .n
        mov  ax,[minrz]
        cmp  ax,AFVIS
        jg   .n
        mov  bx,[cs:afq]        ; the concrete's own flat height, made
        mov  ax,[afy+bx]        ;  camera-relative once for the whole field
        add  ax,ROADLIFT
        sub  ax,[camy]
        mov  [cs:afy1],ax
        ; ---- BOND: THE STRIP IS ONE RECTANGLE. No slabs, no paint, no
        ; thresholds, no hangars or tower beside it - one stroked quad the
        ; size of the concrete. v3 laid it in AFSEG slabs because a FILLED
        ; quad that size broke the rasteriser (below); LOW only strokes it,
        ; and the near-plane clip takes the end you are standing on.
        mov  [bry1],ax
        mov  bx,[cs:afq]
        mov  ax,[afx+bx]
        mov  [wcx],ax
        mov  ax,[afz+bx]
        mov  [wcz],ax
        mov  word [bhw],AFW
        mov  word [bhd],AFLEN
        mov  byte [COLOR],AFPAINT
        call AFQUAD
        jmp  .n
        ; ====================================================================
        ;  AND NOW IN SEGMENTS, because a runway is not a road cell and this
        ;  engine only knows how to draw road cells.
        ;
        ;  The first attempt paved the strip as ONE quad, three thousand
        ;  units by three hundred. It looked right from the circuit and
        ;  covered half the sky on takeoff. The reason is in PROJPT: past a
        ;  ratio of |rx| to rz that a 16-bit divide cannot hold, the guard
        ;  CLAMPS the vertex to +-4000 and keeps its sign. That is the right
        ;  thing to do with one runaway point of a small quad; on a slab
        ;  longer than the near clip plane is close, it drags a corner right
        ;  across the screen and fills everything between. Every ground quad
        ;  the game already draws is a CELL - 256 units - and that is not a
        ;  coincidence, it is the size the projection is safe at.
        ;
        ;  So the strip is AFSEG slabs laid end to end, each a cell and a bit
        ;  long. The centreline is dashed because one dash per segment is
        ;  what falls out of the loop for free - and a dashed centreline is
        ;  also exactly what is painted on a real one.
        ; ====================================================================
.n:    inc  word [afi]
        cmp  word [afi],1       ; BOND: our own field alone (AFSPAWN puts us
        jb   .f                 ;  on field 0) - v3 walked all NAF of them
        retf

; ---- AFQUAD - one painted slab, from wcx/wcz/bhw/bhd at bry1 --------------
AFQUAD: call CODE:ROTCULF
        jc   .q
        call CODE:FACETOPCF
        call CODE:FACEFILLF
.q:    ret
afq     dw 0                    ; the field being paved, as a word index
afy1    dw 0                    ; ...and its concrete, camera-relative

