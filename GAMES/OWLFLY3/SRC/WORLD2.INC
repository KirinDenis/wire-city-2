; WORLD2.INC - part of WIRE CITY (included from OWLFLY3.ASM)
; ============================================================================
;  FACEV  build a vertical face quad from footprint corners [fa],[fb]
;  using camera-space corners FRX/FRZ and heights bry0(bottom)/bry1(top)
;  quad order: A_bottom, A_top, B_top, B_bottom
; ============================================================================
FACEV:  mov  si,[fa]
        add  si,si
        mov  ax,[FRX+si]
        mov  [IX],ax
        mov  [IX+2],ax
        mov  ax,[FRZ+si]
        mov  [IZ],ax
        mov  [IZ+2],ax
        mov  si,[fb]
        add  si,si
        mov  ax,[FRX+si]
        mov  [IX+4],ax
        mov  [IX+6],ax
        mov  ax,[FRZ+si]
        mov  [IZ+4],ax
        mov  [IZ+6],ax
        mov  ax,[bry0]
        mov  [IY],ax
        mov  [IY+6],ax
        mov  ax,[bry1]
        mov  [IY+2],ax
        mov  [IY+4],ax
        ret

; ============================================================================
;  FACETOPC  build the roof quad from all 4 footprint corners at bry1
; ============================================================================
FACETOPC:
        mov  ax,[FRX]
        mov  [IX],ax
        mov  ax,[FRZ]
        mov  [IZ],ax
        mov  ax,[FRX+2]
        mov  [IX+2],ax
        mov  ax,[FRZ+2]
        mov  [IZ+2],ax
        mov  ax,[FRX+4]
        mov  [IX+4],ax
        mov  ax,[FRZ+4]
        mov  [IZ+4],ax
        mov  ax,[FRX+6]
        mov  [IX+6],ax
        mov  ax,[FRZ+6]
        mov  [IZ+6],ax
        mov  ax,[bry1]
        mov  [IY],ax
        mov  [IY+2],ax
        mov  [IY+4],ax
        mov  [IY+6],ax
        ret

; ============================================================================
;  HBLD  deterministic building descriptor for grid cell [gi],[gj]
;   out: bstreet - 0 a building, 1 nothing (the terrain mesh paints it),
;        2 a flat patch, 3 a CITY STREET; and if 0: bhw,bhd (half-size) and
;        bhgt2 (height).  Clobbers AX,BX,CX,SI.
;   Two questions, asked at two different scales, and that is the point:
;   the STREET GRID is the block's (ISROAD marks the strip, ROADOKF says
;   whether any block it touches is a built city block), and the PLOT is the
;   cell's own (its zone, then a cheap integer hash of (gi,gj) whose
;   bit-fields give width / depth / height - deterministic, so the same cell
;   always looks identical: no per-frame flicker, no storage).
; ============================================================================
HBLD:   call ISROAD             ; THE STREET GRID GOES FIRST, and it is
        jc   .road             ; decided by the BLOCK - see ROADOKF in
                                ; TOWN.INC. The per-cell zoning below must
                                ; not get a vote on it: it reads a height
                                ; node every four cells, and one node
                                ; drifting out of the city band used to cut
                                ; an avenue in half.
        mov  ax,[gi]            ; a PLOT, though, is the cell's own business:
        mov  bx,[gj]            ; plains, sea, foothills and mountains are
        call GETZONE            ; all painted by the terrain mesh, and a
        or   ax,ax              ; building has to stand where it stands
        jnz  .st
        ; ---- ONE BUILDING TO EVERY 2x2 CELLS. A 256-unit plot beside a
        ; 512-unit avenue is what made the city look microscopic: the road
        ; was twice the width of the thing it served. Widening the building
        ; inside its own cell cannot fix that - at half-width 230 it would
        ; already be standing in the near traffic lane. So the building
        ; takes the pair, its centre moves to the pair's centre (see
        ; RENDERCELL), and the other three cells are its garden.
        mov  ax,[gi]
        or   ax,[gj]
        test ax,1
        jnz  .st
        call CELLHASH          ; ax = hash of (gi,gj)
        mov  bx,ax
        and  bx,31              ; hash 7/8/9 of 32 -> flat terrain patches
        cmp  bx,7
        je   .forest
        cmp  bx,8
        je   .water
        cmp  bx,9
        je   .field
        ; --- superblock clustering: only ~3/16 of 8x8 blocks are built up.
        ; Structures stay grouped (a built block keeps full density) but the
        ; groups themselves are rare - SimCity-style districts on open land.
        push ax                 ; keep the cell hash
        call TOWNSEG:BLKINFF   ; the block byte: clustering nibble in 0..3,
        mov  [sbh],ax           ; district in 4..5 - where SBHASH put them
        and  ax,15
        cmp  ax,3
        jae  .unbuilt          ; empty block: open ground (patches still apply)
        pop  ax
        ; ---- district: the BLOCK sets the flavour, the CELL gets a say.
        ; 0/3 residential, 1 downtown, 2 industry. A pure district is what
        ; makes a procedural city look drawn by a zoning computer: sixty
        ; identical sheds, then sixty identical houses. Three cells in eight
        ; take a neighbour's district instead, so a machine shop stands
        ; behind the houses and a shed leans on a tower - and the block
        ; still reads as what it mostly is.
        mov  bx,[sbh]
        mov  cl,4
        shr  bx,cl
        and  bx,3
        mov  [bdist],bx
        push ax                 ; the cell hash is wanted after this
        call DHASH              ; the cell's own opinion
        mov  bx,ax
        and  bx,7
        cmp  bx,5
        jb   .dok
        mov  bx,ax
        mov  cl,3
        shr  bx,cl
        and  bx,3
        inc  bx                 ; +1..4, so never its own district again
        add  bx,[bdist]
        and  bx,3
        mov  [bdist],bx
.dok:  pop  ax
        ; base footprint from the cell hash
        mov  bx,ax              ; footprint, on the 2x2 plot: half size
        and  bx,31              ; 168..230, so the building is 336..460
        add  bx,bx              ; across in a 512 plot and still keeps its
        add  bx,168             ; feet out of the road
        mov  [bhw],bx
        mov  bx,ax
        mov  cl,5
        shr  bx,cl
        and  bx,31
        add  bx,bx
        add  bx,168
        mov  [bhd],bx
        mov  bx,ax              ; wall colour scheme 0..3 (grey/blue/red/white)
        mov  cl,13
        shr  bx,cl
        and  bx,3
        mov  [bschm],bx
        mov  bx,ax              ; bsel = building selector 0..7
        mov  cl,10
        shr  bx,cl
        and  bx,7
        mov  si,[bdist]
        cmp  si,1
        je   .com
        cmp  si,2
        je   .ind
        ; --- residential: low boxes, an occasional tower ---
        mov  word [btype],0
        cmp  bx,6
        jb   .rh
        mov  word [btype],2 ; tower
.rh:   mov  bx,ax
        and  bx,63
        add  bx,bx              ; height 120..246 - twice the old, or the
        add  bx,120             ; doubled footprint reads as a paving slab
        mov  [bhgt2],bx
        jmp  .bdone
.com:  ; --- commercial downtown: tall mixed skyline ---
        mov  word [btype],0
        cmp  bx,3
        jb   .ch               ; 0..2 tall box
        cmp  bx,5
        jb   .ctw              ; 3..4 tower
        cmp  bx,7
        jb   .csp              ; 5..6 spire
        mov  word [btype],3 ; 7 arch
        jmp  .ch
.ctw:  mov  word [btype],2
        jmp  .ch
.csp:  mov  word [btype],1
.ch:   ; downtown height: towers cluster toward the block centre.
        ; dist = |gi&7 - 4| + |gj&7 - 4| (0..8); centre -> +288 bonus.
        push ax
        mov  bx,[gi]
        and  bx,7
        sub  bx,4
        jns  .a1
        neg  bx
.a1:   mov  si,bx              ; |gi&7 - 4|
        mov  bx,[gj]
        and  bx,7
        sub  bx,4
        jns  .a2
        neg  bx
.a2:   add  si,bx              ; manhattan dist to superblock centre, 0..8
        mov  ax,8
        sub  ax,si
        mov  bx,60              ; the plot doubled, so the skyline follows -
        imul bx                 ; downtown bonus 0..480
        mov  si,ax
        pop  ax
        mov  bx,ax
        and  bx,63              ; per-building variation
        add  bx,bx
        add  bx,100
        add  bx,si              ; height 100..706 (respawn clears all)
        mov  [bhgt2],bx
        jmp  .bdone
.ind:  ; --- industrial: smoking factories and low sheds (always grey) ---
        mov  word [bschm],0
        mov  word [btype],4
        cmp  bx,5
        jb   .ih               ; 0..4 factory with chimney
        mov  word [btype],0 ; 5..7 plain shed
.ih:   mov  bx,ax
        and  bx,31
        add  bx,bx
        add  bx,100             ; low industry: 100..162
        mov  [bhgt2],bx
.bdone:
        mov  word [bstreet],0
        ret
.st:   mov  word [bstreet],1
        ret
.road: call TOWNSEG:ROADOKF   ; ...but only where a block this strip
        jnc  .st               ; touches is BUILT UP. Only ~3/16 of blocks
                                ; are, so without that test the island wears
                                ; a full road grid over empty countryside -
                                ; and asking about the STRIP rather than the
                                ; cell's own block is what closes the ring
                                ; round the outside of a district. Same
                                ; table, same single source of truth, as the
                                ; one that decides the buildings above.
        mov  word [bstreet],3 ; a CITY street: tarmac and traffic.
        ret                       ; Distinct from 1, which also means
                                  ; "plains / sea / mountain, the terrain
                                  ; mesh paints it" - and you cannot drive
                                  ; a bus across those. Everything that
                                  ; tests bstreet for 0 (is there a
                                  ; building?) is unaffected.
.unbuilt:
        pop  ax                 ; discard the kept cell hash
        jmp  .st
.forest:
        mov  byte [bcol],15
        jmp  .patch
.water:
        mov  byte [bcol],14
        jmp  .patch
.field:
        mov  byte [bcol],11
.patch:                        ; flat ground patch fills most of the cell
        mov  word [bhw],116
        mov  word [bhd],116
        mov  word [bstreet],2
        ret

; ============================================================================
;  ISROAD - is cell [gi],[gj] road rather than a plot?  CF=1 = road.
;  TWO cells in every eight, so an avenue is 512 units across - twice the
;  old one, which was one cell in four. The built fraction is untouched:
;  (6/8) squared is exactly what (3/4) squared gave. Wider streets and
;  blocks twice the size, the same amount of city. Streets are what a city
;  is SEEN through; at one cell the buildings on the far side stood right
;  on top of the ones in front, and there was nowhere to put a bus.
;  The 8-cell period also lines up with the downtown height bonus, which
;  already measures its distance from the block centre with gi&7.
;  Clobbers AX.
; ============================================================================
ISROAD: mov  ax,[gi]
        and  ax,7
        cmp  ax,2
        jl   .yes
        mov  ax,[gj]
        and  ax,7
        cmp  ax,2
        jl   .yes
        clc
        ret
.yes:  stc
        ret

; DHASH - a SECOND, independent hash of the cell. The first one's bits are
; all spoken for (width, depth, selector, scheme), and reusing them would
; tie a cell's district to its shape - the tall buildings would always be
; the ones that changed district, and the eye finds that sort of thing.
DHASH:  mov  ax,[gi]
        mov  bx,3121
        imul bx
        mov  si,ax
        mov  ax,[gj]
        mov  bx,6151
        imul bx
        add  ax,si
        mov  bx,ax
        mov  cl,9
        shr  bx,cl
        xor  ax,bx
        ret

; SBHASH went out to TOWNSEG on 2026-08-04 and became BLKHASH, baked once
; into the BLOCK TABLE and read back through BLKINFF. It was already called
; the single source of truth for "is this block built up" - but it was being
; ASKED cell by cell, and that let the cells of one block answer differently
; and tore the streets apart. Read TOWN.INC for what replaced it. The bytes
; it gave back here are what pays for the two far calls in HBLD.

; hash = mix(gi*1973 + gj*9277) - shared by buildings, patches and mountains
CELLHASH:
        mov  ax,[gi]
        mov  bx,1973
        imul bx
        mov  si,ax
        mov  ax,[gj]
        mov  bx,9277
        imul bx
        add  ax,si
        mov  bx,ax
        mov  cl,7
        shr  bx,cl
        xor  ax,bx
        ret

; ============================================================================
;  The windows moved out on 2026-08-03. WINFACE and WLIT2 now live in
;  TOWNSEG (TOWN.INC) and are reached through the far door WINFACEF: the
;  main segment was down to twenty-six bytes and the new pane geometry is
;  bigger than the old, so the rule applied - open a segment, do not shave
;  bytes. Read TOWN.INC for what changed and LAB\README.md for why.
; ============================================================================
