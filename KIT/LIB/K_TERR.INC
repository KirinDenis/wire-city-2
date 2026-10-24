; ============================================================================
;  K_TERR.INC - KIT: the island. ENGINE\E_TERR.INC's Diamond-Square map on a
;  64x64 torus, wrapped: made from a seed, asked for its height anywhere
;  (bilinear, as the ground is drawn), coloured by bands, shown as a map,
;  and searched for ground worth standing on.
;
;        mov  ax,1234            ; a seed (0: from the clock, every run new)
;        call TER_GEN            ; the island, in HMAP
;        call TER_PAL            ; DAC 1..6 the bands, 9..14 the same darker
;        mov  ax,[px]            ; world x
;        mov  bx,[pz]            ;  and z
;        call TER_H              ; AX = the ground's height there
;
;  THE WORLD (the games' own): x east, z north, words. A node every 1024
;  units, node (gi,gj) at x = gi*1024 - TER_BIAS, z = gj*1024 - TER_BIAS;
;  64 nodes are 65536 units, so a word wraps exactly once round the island
;  and it has no edge. Heights: the map's raw byte 0..255 (bands: < 88 sea,
;  88..119 sand, 120..167 grass, 168..199 woods, 200..229 rock, 230+ snow)
;  turned into world units by WORLDH ((h-88)*5, sea 0, twice as steep past
;  560) and doubled TER_VEX times (a slope reads flat otherwise).
;
;  CONSTANTS (define before the include to change them):
;      TER_VEX = 1    heights * 2^TER_VEX (0: the game's own; peaks ~1110)
;      TER_BIAS = 8192 (fixed: it is how the engine places node 0)
;
;  INCLUDES ENGINE\E_MATH.INC and ENGINE\E_TERR.INC: their names are taken
;  - RND16 rseed HMAP HGET HPUT DSGEN GETH GETZONE WORLDH dss dsh dsx dsy
;  dsamp dsac. Do not include E_MATH.INC again. HGET clobbers CL and WORLDH
;  BX and DX; the TER_ routines keep every register.
;  Guide topic RENDER (Terrain).
; ============================================================================

if ~ defined TER_VEX | defined ter_dvex
TER_VEX  = 1                    ; heights doubled once
ter_dvex = 1
end if
TER_BIAS = 8192                 ; world -> node bias (the engine's BIAS)

; ---- the engine's contract: E_MATH + E_TERR ---------------------------------
rseed   dw 1                    ; the LCG's state
dss     dw 0                    ; Diamond-Square: the side...
dsh     dw 0                    ; ...its half...
dsx     dw 0                    ; ...the loop and scratch
dsy     dw 0
dsamp   dw 0                    ; ...the noise amplitude
dsac    dw 0                    ; ...the accumulator
HMAP    db 4096 dup(0)          ; the 64x64 map, row = x (gi), column = y (gj)

        include '..\..\ENGINE\E_MATH.INC'
        include '..\..\ENGINE\E_TERR.INC'

; ---- the kit's own state -------------------------------------------------------
ter_glo   dw 1                  ; TER_FINDGND: the lowest ground it takes...
ter_ghi   dw ((199-88)*5) shl TER_VEX ; ...and the highest (woods' top)
ter_gstep dw 64                 ; ...how much wider each ring of the search
ter_mx    dw 0                  ; TER_MAP: where the map was drawn...
ter_my    dw 0
ter_mc    dw 1                  ; ...and its pixels a node
ter_t0    dw 0                  ; scratch
ter_t1    dw 0
ter_fx    dw 0
ter_fz    dw 0
ter_gi    dw 0
ter_gj    dw 0
ter_h00   dw 0
ter_h10   dw 0
ter_h01   dw 0
ter_h11   dw 0
ter_cx    dw 0                  ; TER_FINDGND's search
ter_cz    dw 0
ter_bx    dw 0
ter_bz    dw 0
ter_bh    dw 0
ter_ring  dw 0
ter_e     dw 0
ter_kx    dw 0
ter_kz    dw 0

; ----------------------------------------------------------------------
;@ TER_GEN    make the island from a seed (AX; 0 = from the BIOS tick)
;  in:  AX = the seed (the same seed, the same island)
;  out: HMAP filled, stretched to the full 0..255
;  from: ENGINE\E_TERR.INC DSGEN (as EXAMPLES\RELIEF.ASM:156-161 seeds it)
; ----------------------------------------------------------------------
if used TER_GEN
TER_GEN:push ax
        push bx
        push cx
        push dx
        push si
        push di
        or   ax,ax
        jnz  .s
        push es
        mov  es,ax              ; ES = 0 (AX is 0 here)
        mov  ax,[es:046Ch]      ; the tick: every run differs
        pop  es
        or   ax,1               ; never nought
.s:     mov  [rseed],ax
        call DSGEN
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ TER_RAW    AX = the raw map byte (0..255) of node BX = gi, DX = gj
;  in:  BX = node x, DX = node z (any: they wrap round the island)
;  out: AX = the height byte, AH = 0
;  from: ENGINE\E_TERR.INC HGET (which eats CL - kept here)
; ----------------------------------------------------------------------
if used TER_RAW
TER_RAW:push cx
        call HGET
        xor  ah,ah
        pop  cx
        ret
end if

; ----------------------------------------------------------------------
;@ TER_WH     AX = the world height of a raw map byte AX
;  in:  AX = 0..255
;  out: AX = world units (sea 0), * 2^TER_VEX
;  from: ENGINE\E_TERR.INC WORLDH (which eats BX DX - kept here)
; ----------------------------------------------------------------------
if used TER_WH
TER_WH: push bx
        push cx
        push dx
        call WORLDH
        mov  cl,TER_VEX
        shl  ax,cl              ; the exaggeration
        pop  dx
        pop  cx
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ TER_NODEH  AX = the world height at node BX = gi, DX = gj
;  in:  BX, DX = the node (wrapping)
;  out: AX = TER_WH(TER_RAW): what TER_H gives exactly on the node
;  from: LESSONS\L22\FILL.ASM TERRPREP (HGET then WORLDH then << VEXAG)
; ----------------------------------------------------------------------
if used TER_NODEH
TER_NODEH:
        call TER_RAW
        call TER_WH
        ret
end if

; ----------------------------------------------------------------------
;@ TER_H      AX = the ground's height at world point AX = x, BX = z
;  in:  AX = world x, BX = world z
;  out: AX = height in world units, bilinear between the 4 nodes round it
;       (the drawn quads' corners meet it exactly)
;  from: GAMES\OWLFLY3\SRC\TERRAIN.INC TERRH:432-509 (fractions in 64ths of
;        a node; its divides are by the constant 64 of a product < 64*h)
; ----------------------------------------------------------------------
if used TER_H
TER_H:  push bx
        push cx
        push dx
        add  ax,TER_BIAS        ; an unsigned world coordinate
        mov  dx,ax
        mov  cl,10
        shr  dx,cl              ; node x = >> 10
        mov  [ter_gi],dx
        mov  cl,4
        shr  ax,cl
        and  ax,63              ; fx: across the node, in 64ths
        mov  [ter_fx],ax
        mov  ax,bx
        add  ax,TER_BIAS
        mov  dx,ax
        mov  cl,10
        shr  dx,cl              ; node z
        mov  [ter_gj],dx
        mov  cl,4
        shr  ax,cl
        and  ax,63              ; fz
        mov  [ter_fz],ax
        mov  bx,[ter_gi]        ; the four nodes round it
        mov  dx,[ter_gj]
        call TER_NODEH
        mov  [ter_h00],ax
        inc  bx
        call TER_NODEH
        mov  [ter_h10],ax
        inc  dx
        call TER_NODEH
        mov  [ter_h11],ax
        dec  bx
        call TER_NODEH
        mov  [ter_h01],ax
        mov  bx,64
        mov  ax,[ter_h10]       ; ha = h00 + (h10-h00)*fx/64
        sub  ax,[ter_h00]
        imul word [ter_fx]      ; DX:AX = (h10-h00)*fx
        idiv bx                 ; / 64 (|q| < |h10-h00|)
        add  ax,[ter_h00]
        mov  [ter_t0],ax        ; ha
        mov  ax,[ter_h11]       ; hb = h01 + (h11-h01)*fx/64
        sub  ax,[ter_h01]
        imul word [ter_fx]      ; DX:AX = (h11-h01)*fx
        idiv bx                 ; / 64
        add  ax,[ter_h01]       ; hb
        sub  ax,[ter_t0]        ; h = ha + (hb-ha)*fz/64
        imul word [ter_fz]      ; DX:AX = (hb-ha)*fz
        idiv bx                 ; / 64
        add  ax,[ter_t0]
        pop  dx
        pop  cx
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ TER_BAND   AL = the band colour (1..6) of a raw height AL
;  in:  AL = raw 0..255
;  out: AL = 1 sea, 2 sand, 3 grass, 4 woods, 5 rock, 6 snow (TER_PAL's
;       entries; +8 is the same band darker)
;  from: LESSONS\L22\FILL.ASM QBAND:1691-1706
; ----------------------------------------------------------------------
if used TER_BAND
TER_BAND:
        push bx
        mov  bl,1               ; sea
        cmp  al,88
        jb   .set
        mov  bl,2               ; sand
        cmp  al,120
        jb   .set
        mov  bl,3               ; grass
        cmp  al,168
        jb   .set
        mov  bl,4               ; woods
        cmp  al,200
        jb   .set
        mov  bl,5               ; rock
        cmp  al,230
        jb   .set
        mov  bl,6               ; snow
.set:   mov  al,bl
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ TER_PAL    set DAC 1..6 to the six bands and 9..14 to them at half light
;  in:  -
;  out: - (7 = a red for messages, 8 black)
;  from: LESSONS\L22\FILL.ASM SETPAL/PAL:1902-1946
; ----------------------------------------------------------------------
if used TER_PAL
TER_PAL:push ax
        push cx
        push dx
        push si
        mov  dx,3C8h
        mov  al,1
        out  dx,al              ; from entry 1
        inc  dx
        mov  si,.pal
        mov  cx,14*3
.p:     lodsb
        out  dx,al              ; r, g, b; the index steps itself
        loop .p
        pop  si
        pop  dx
        pop  cx
        pop  ax
        ret
.pal    db  4,10,28,  46,42,26,  16,38,10,  10,26, 8,  26,24,22,  46,48,50
        db 60,12, 8,   0, 0, 0
        db  2, 5,14,  23,21,13,   8,19, 5,   5,13, 4,  13,12,11,  23,24,25
end if

; ----------------------------------------------------------------------
;@ TER_MAP    the island seen from above, by bands, north up, into ES
;  in:  AX = left x, BX = top y, CX = pixels a node (1..3: 64..192 wide);
;       ES = the buffer
;  out: - ([ter_mx],[ter_my],[ter_mc] remember it for TER_MAPPT)
;  from: EXAMPLES\RELIEF.ASM MAPVIEW:1542-1586 (any origin, any cell)
; ----------------------------------------------------------------------
if used TER_MAP
TER_MAP:push ax
        push bx
        push cx
        push dx
        push si
        push di
        mov  [ter_mx],ax
        mov  [ter_my],bx
        mov  [ter_mc],cx
        mov  ax,bx
        mov  bx,320
        mul  bx                 ; AX = top * 320
        add  ax,[ter_mx]
        mov  di,ax              ; DI = the map's corner
        mov  word [ter_gj],63   ; the TOP row is the highest z: north up
.row:   mov  word [ter_gi],0
        push di
.col:   mov  bx,[ter_gi]
        mov  dx,[ter_gj]
        call TER_RAW
        call TER_BAND           ; AL = the colour
        mov  cx,[ter_mc]        ; a cell of mc x mc pixels
        push di
.cy:    push cx
        push di
        mov  cx,[ter_mc]
        rep  stosb
        pop  di
        add  di,320
        pop  cx
        loop .cy
        pop  di
        add  di,[ter_mc]        ; the next cell to the right
        inc  word [ter_gi]
        cmp  word [ter_gi],64
        jb   .col
        pop  di
        mov  ax,320
        mul  word [ter_mc]      ; AX = a row of cells, in bytes
        add  di,ax
        dec  word [ter_gj]
        jns  .row
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ TER_MAPPT  world point AX = x, BX = z -> its pixel AX,BX on the last TER_MAP
;  in:  AX, BX = world x, z
;  out: AX = screen x, BX = screen y (the middle of its node's cell)
;  from: EXAMPLES\RELIEF.ASM MAPVIEW's mark:1588-1621
; ----------------------------------------------------------------------
if used TER_MAPPT
TER_MAPPT:
        push cx
        push dx
        add  ax,TER_BIAS
        mov  cl,10
        shr  ax,cl              ; node x
        and  ax,63
        mul  word [ter_mc]      ; * pixels a node
        add  ax,[ter_mx]
        push ax
        mov  ax,bx
        add  ax,TER_BIAS
        shr  ax,cl              ; node z (CL is still 10)
        and  ax,63
        mov  bx,63
        sub  bx,ax              ; rows count down from the top
        mov  ax,bx
        mul  word [ter_mc]
        add  ax,[ter_my]
        mov  bx,ax
        pop  ax
        mov  cx,[ter_mc]
        shr  cx,1               ; to the cell's middle
        add  ax,cx
        add  bx,cx
        pop  dx
        pop  cx
        ret
end if

; ----------------------------------------------------------------------
;@ TER_TOP    AX = the highest ground on the whole island (world units)
;  in:  -
;  out: AX (spawn above it; a ceiling above that)
;  from: LESSONS\L22\FILL.ASM TOPOFMAP:690-716
; ----------------------------------------------------------------------
if used TER_TOP
TER_TOP:push cx
        push si
        mov  si,HMAP
        mov  cx,4096
        xor  ah,ah              ; the tallest byte so far
.l:     lodsb
        cmp  al,ah
        jbe  .n
        mov  ah,al
.n:     loop .l
        mov  al,ah
        xor  ah,ah
        call TER_WH
        pop  si
        pop  cx
        ret
end if

; ----------------------------------------------------------------------
;@ TER_FINDGND legal ground near AX = x, BX = z: out of the sea, off the peaks
;  in:  AX, BX = the spot wanted (world); [ter_glo]..[ter_ghi] = the
;       heights allowed (default: above the sea, at most the woods' top);
;       [ter_gstep] = how much each ring of the search widens (64)
;  out: AX, BX = the spot chosen (the HIGHEST legal one on the first ring
;       that has any), CX = its height; CF = 1 nothing in 40 rings: AX,BX
;       as given
;  from: GAMES\OWLFLY3\SRC\UI.INC FINDGND:3293-3375 (its crude compass:
;        16 points a ring, each axis -1, 0, +1, 0)
; ----------------------------------------------------------------------
if used TER_FINDGND
TER_FINDGND:
        push dx
        mov  [ter_cx],ax
        mov  [ter_cz],bx
        mov  word [ter_bh],0    ; the best height so far (0 = none)
        mov  word [ter_ring],0
.fr:    mov  word [ter_e],0     ; 16 points on this ring
.fp:    mov  ax,[ter_e]
        and  ax,3
        call .unit              ; AX = -1, 0, 1, 0
        call .out               ; * (ring+1) * step
        add  ax,[ter_cx]
        mov  [ter_kx],ax        ; candidate x
        mov  ax,[ter_e]
        shr  ax,1
        shr  ax,1
        and  ax,3
        call .unit
        call .out
        add  ax,[ter_cz]
        mov  [ter_kz],ax        ; candidate z
        mov  bx,ax
        mov  ax,[ter_kx]
        call TER_H
        cmp  ax,[ter_glo]
        jb   .fn                ; in the sea
        cmp  ax,[ter_ghi]
        ja   .fn                ; up the mountain
        cmp  ax,[ter_bh]
        jbe  .fn
        mov  [ter_bh],ax        ; the best legal ground so far
        mov  ax,[ter_kx]
        mov  [ter_bx],ax
        mov  ax,[ter_kz]
        mov  [ter_bz],ax
.fn:    inc  word [ter_e]
        cmp  word [ter_e],16
        jb   .fp
        cmp  word [ter_bh],0
        jne  .fd                ; something on this ring: stop widening
        inc  word [ter_ring]
        cmp  word [ter_ring],40
        jb   .fr
        mov  ax,[ter_cx]        ; nothing: as it was, and say so
        mov  bx,[ter_cz]
        xor  cx,cx
        pop  dx
        stc
        ret
.fd:    mov  ax,[ter_bx]
        mov  bx,[ter_bz]
        mov  cx,[ter_bh]
        pop  dx
        clc
        ret
.unit:  dec  ax                 ; 0..3 -> -1, 0, 1, 2...
        cmp  ax,2
        jne  .u1
        xor  ax,ax              ; ...and 2 -> 0
.u1:    ret
.out:   push dx
        mov  dx,[ter_ring]
        inc  dx
        imul dx                 ; AX = unit * (ring+1), -40..40
        imul word [ter_gstep]   ; AX = * step (keep step*40 < 32768)
        pop  dx
        ret
end if
