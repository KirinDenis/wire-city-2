; WORLD.INC - part of WIRE CITY (included from OWLFLY3.ASM)
; DEAD (flat-ground era; replaced by the TERRAIN mesh, no callers) -----------
; Kept as READING, not as bytes: the radar stations of 2026-07-28 needed the
; room and this routine had no callers left. IF 0 hands the whole thing to
; the assembler's wastebasket - every line survives here, none of them ship.
; ----- ground grid: world-aligned lines around the camera (rotate with view)
; BACK IN SERVICE FOR LOW, 2026-08-19. It sat under `if 0` for a year as a
; keepsake; the quality ladder wants exactly what it does. In LOW the ground
; is not relief at all - no heightmap, no 1600 quads, no per-node cache -
; it is this flat lattice of world-aligned lines around the camera, which
; is what WIRE CITY drew and what a slow machine can afford.
;
; GR is its reach in CELLS of 256 world units: 24 puts the far edge about
; 6100 units out. Two lines per step, both ways, so the whole ground is
; about a hundred clipped 3D edges.
GR      = 12                    ; see the arithmetic in GRID below

; ---- pitch one edge endpoint, the way PITCH4 pitches the polygons ----------
;  THE GRID AND THE MESH MUST SHARE ONE CAMERA. The polygon path really
;  rotates its points by pitch (PITCH4, inside FACEFILL's clip); this edge
;  path did not - it came back from the flat-ground era, when the whole
;  game faked pitch as a horizon shift. In the cockpit, where pitch stays
;  small, nobody could tell. The spectator's orbit looks DOWN at up to
;  eighty degrees, and there the two camera models tear apart - buildings
;  pitched properly, grid not pitched at all, "the objects live their own
;  life". Same rotation, same trig, and the two worlds are one again.
;      in: SI -> the y word, DI -> the z word (already heading-rotated)
PITCHP: mov  ax,[si]
        imul word [pcos]
        mov  bx,256
        idiv bx
        mov  cx,ax              ; y*pcos/256
        mov  ax,[di]
        imul word [psin]
        mov  bx,256
        idiv bx
        sub  cx,ax              ; y' = (y*pcos - z*psin)/256
        mov  ax,[si]
        imul word [psin]
        mov  bx,256
        idiv bx
        push ax
        mov  ax,[di]
        imul word [pcos]
        mov  bx,256
        idiv bx
        pop  bx
        add  ax,bx              ; z' = (y*psin + z*pcos)/256
        mov  [di],ax
        mov  [si],cx
        ret
GRID:   ; ---- WHY THE GRID CAME APART, IN ONE NUMBER --------------------------
        ; CLAMPAX pins a projected coordinate at +-4000. With FOCAL 220 that
        ; is reached when |x| / z passes 18.2 - and past that point PROJPT
        ; stops dividing and SUBSTITUTES the coordinate. A filled polygon
        ; does not mind: the span filler clips it either way. A LINE does:
        ; move one endpoint and the whole segment swings, which is the mess
        ; the splash screen showed the moment the camera turned. It has
        ; nothing to do with how fast the machine is - it happens at 30000
        ; cycles as readily as at 7000.
        ;
        ; So the grid has to keep its own corner inside that ratio:
        ;
        ;    worst lateral offset = GR * 256 * sqrt(2)
        ;    needs   nzmin  >=  that / 18.2
        ;
        ;    GR=24 -> 8688 -> 478      GR=12 -> 4344 -> 239
        ;
        ; GR 24 with a near plane of 256 was still off by nearly double,
        ; which is exactly why the first fix did not take. GR 12 and 288
        ; clears it with room, and costs the nearest cell of grid.
        ; The REAL cure is clipping the edge against the side planes in 3D
        ; instead of clamping it in 2D - that is a job for the whole line
        ; pipeline, and it wants the C# rig to check the geometry first.
        ; Restored before we leave, or every model in the game loses its
        ; nose at 288.
        ; 2. Put the plane on the ground UNDER THE AIRCRAFT rather than on
        ;    world zero, so the runway, the hangars and the block you are
        ;    diving at stand on the grid instead of floating over it. Over
        ;    hills it drifts, and that is the honest price of a flat ground
        ;    in a game that has relief.
        mov  word [nzmin],288
        call TERRH              ; AX = ground height under the camera
        sub  ax,[camy]
        mov  [gndy],ax
        mov  byte [COLOR],6
        ; lines parallel to world-Z (fixed X = gi)
        mov  ax,[camgi]
        sub  ax,GR
        mov  [gi],ax
.gx:   mov  ax,[gi]            ; worldX = gi*256 - BIAS
        mov  cl,8
        shl  ax,cl
        sub  ax,BIAS
        mov  [wcx],ax
        ; endpoint A (worldX, Zmin)
        mov  ax,[wcx]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[camgj]
        sub  ax,GR
        mov  cl,8
        shl  ax,cl
        sub  ax,BIAS
        sub  ax,[camz]
        mov  [wdz],ax
        call ROTXZ
        mov  ax,[rc_x]
        mov  [x0],ax
        mov  ax,[rc_z]
        mov  [z0],ax
        ; endpoint B (worldX, Zmax)
        mov  ax,[wcx]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[camgj]
        add  ax,GR
        mov  cl,8
        shl  ax,cl
        sub  ax,BIAS
        sub  ax,[camz]
        mov  [wdz],ax
        call ROTXZ
        mov  ax,[rc_x]
        mov  [x1],ax
        mov  ax,[rc_z]
        mov  [z1],ax
        mov  ax,[gndy]          ; the plane sits on the ground UNDER US, not
        mov  [y0],ax            ;  on world zero - worked out once a frame
        mov  [y1],ax            ;  at the top of GRID
        mov  si,y0              ; and PITCH both ends, exactly as PITCH4
        mov  di,z0              ;  pitches every polygon - one camera,
        call PITCHP             ;  or the grid lives a life of its own
        mov  si,y1
        mov  di,z1
        call PITCHP
        call DRAWEDGE3D
        mov  ax,[gi]
        inc  ax
        mov  [gi],ax
        mov  bx,[camgi]
        add  bx,GR
        cmp  ax,bx
        jle  .gx
        ; lines parallel to world-X (fixed Z = gj)
        mov  ax,[camgj]
        sub  ax,GR
        mov  [gj],ax
.gz:   mov  ax,[gj]
        mov  cl,8
        shl  ax,cl
        sub  ax,BIAS
        sub  ax,[camz]
        mov  [wdz],ax
        ; endpoint A (Xmin, worldZ)
        mov  ax,[camgi]
        sub  ax,GR
        mov  cl,8
        shl  ax,cl
        sub  ax,BIAS
        sub  ax,[camx]
        mov  [wdx],ax
        call ROTXZ
        mov  ax,[rc_x]
        mov  [x0],ax
        mov  ax,[rc_z]
        mov  [z0],ax
        ; endpoint B (Xmax, worldZ)
        mov  ax,[camgi]
        add  ax,GR
        mov  cl,8
        shl  ax,cl
        sub  ax,BIAS
        sub  ax,[camx]
        mov  [wdx],ax
        call ROTXZ
        mov  ax,[rc_x]
        mov  [x1],ax
        mov  ax,[rc_z]
        mov  [z1],ax
        mov  ax,[gndy]          ; the plane sits on the ground UNDER US, not
        mov  [y0],ax            ;  on world zero - worked out once a frame
        mov  [y1],ax            ;  at the top of GRID
        mov  si,y0              ; and PITCH both ends, exactly as PITCH4
        mov  di,z0              ;  pitches every polygon - one camera,
        call PITCHP             ;  or the grid lives a life of its own
        mov  si,y1
        mov  di,z1
        call PITCHP
        call DRAWEDGE3D
        mov  ax,[gj]
        inc  ax
        mov  [gj],ax
        mov  bx,[camgj]
        add  bx,GR
        cmp  ax,bx
        jle  .gz
        mov  word [nzmin],NEARZ ; back to the models' near plane, or every
        ret                     ;  nose in the game gets sliced at 256
; ----- buildings: one linear far->near walk of the BORD order table ---------
;  2401 cells to radius 24; empty cells drop out of RENDERCELL quickly, and
;  the clustered city keeps the populated count low. Real buildings all the
;  way to the horizon - the megablock stand-ins are gone.
BUILDINGS:
        mov  ax,[camx]          ; camera cell = (pos+BIAS)>>8  (shr = floor /CELL)
        add  ax,BIAS
        mov  cl,8
        shr  ax,cl
        mov  [camgi],ax
        mov  ax,[camz]
        add  ax,BIAS
        mov  cl,8
        shr  ax,cl
        mov  [camgj],ax
        mov  word [ring],0  ; reuse [ring] as the BORD index
.bl:   mov  si,[ring]
        add  si,si
        mov  al,[BORD+si]       ; di (signed)
        cbw
        mov  [cdi],ax
        mov  al,[BORD+si+1]     ; dj (signed)
        cbw
        mov  [cdj],ax
        call RENDERCELL
        inc  word [ring]
        cmp  word [ring],2401
        jl   .bl
        ret

; ============================================================================
;  DRAWBOX - one solid box standing on the terrain. Centre [wcx,wcz], half
;  size bhw/bhd, vertical span gbase+boxb .. gbase+boxt. Runs the normal
;  visible-face fill + distance-coloured stroke + windows. boxb/boxt survive.
; ============================================================================
DRAWBOX:
        call ROTCUL
        jc   .r
        mov  ax,[gbase]
        add  ax,[boxb]
        sub  ax,[camy]
        mov  [bry0],ax
        mov  ax,[gbase]
        add  ax,[boxt]
        sub  ax,[camy]
        mov  [bry1],ax
        mov  al,[roofc]         ; 17 for a building, its own paint for a
        mov  [COLOR],al         ; vehicle
        mov  ax,[gbase]
        add  ax,[boxt]
        cmp  [camy],ax
        jle  .nf
        call FACETOPC
        call FACEFILL
.nf:   call VISFILL
        mov  ax,[minrz]         ; stroke colour by distance
        cmp  ax,500
        jg   .nn
        mov  al,3
        jmp  .cc
.nn:   cmp  ax,1200
        jg   .ff
        mov  al,2
        jmp  .cc
.ff:   mov  al,1
.cc:   mov  [COLOR],al
        mov  [scol],al          ; VISSTROKE restores this per face
        mov  ax,[gbase]
        add  ax,[boxt]
        cmp  [camy],ax
        jle  .ns
        call FACETOPC
        call FACESTROKE
.ns:   call VISSTROKE
.r:    ret

; ============================================================================
;  PUFFBOX - one soft smoke cube: haze colour, no outline, no windows.
;  Same box parameters as DRAWBOX.
; ============================================================================
PUFFBOX:
        call ROTCUL
        jc   .r
        mov  ax,[gbase]
        add  ax,[boxb]
        sub  ax,[camy]
        mov  [bry0],ax
        mov  ax,[gbase]
        add  ax,[boxt]
        sub  ax,[camy]
        mov  [bry1],ax
        mov  byte [COLOR],12 ; horizon-haze grey reads as smoke
        mov  ax,[gbase]
        add  ax,[boxt]
        cmp  [camy],ax
        jle  .nf
        call FACETOPC
        call FACEFILL
.nf:   call MEGAFILL           ; flat fill that keeps the smoke colour
.r:    ret

; ----- render one city cell (cdi,cdj relative to camera cell) ---------------
;  Looks up the building for cell (camgi+cdi, camgj+cdj), rotates its 4
;  footprint corners into camera space (FRX/FRZ + min/maxrz), culls if all
;  behind/too far, then fills+strokes only the box faces facing the camera
;  (chosen by world-space camx/camz vs the footprint, so yaw-independent).
;  Visible vertical faces are drawn via FACEV; roof via FACETOPC.
RENDERCELL:
        mov  ax,[camgi]
        add  ax,[cdi]
        mov  [gi],ax
        mov  ax,[camgj]
        add  ax,[cdj]
        mov  [gj],ax
        call HBLD
        mov  ax,[bstreet]
        cmp  ax,1
        je   .ret              ; not city: the terrain mesh paints it
        cmp  ax,3
        jne  .notroad
        call ROADCELL           ; a city street: tarmac, then whatever is
        jmp  .ret              ; driving on it
.notroad:
        mov  byte [roofc],17
        call BCHK
        jz   .stands
        jmp  .ret              ; a ruin: rubble and smoke, no walls
.stands:
        ; cell centre world coords:  gi*256 + 128 - BIAS   (shl = *CELL)
        ; ...but a BUILDING owns the 2x2 plot whose corner this cell is, so
        ; its centre is another 128 out on both axes. The flat patches
        ; (forest/water/field) are still one cell each and keep the first.
        mov  ax,[gi]
        mov  cl,8
        shl  ax,cl
        add  ax,128
        cmp  word [bstreet],0
        jne  .c1
        add  ax,128
.c1:   sub  ax,BIAS
        mov  [wcx],ax
        mov  ax,[gj]
        mov  cl,8
        shl  ax,cl
        add  ax,128
        cmp  word [bstreet],0
        jne  .c2
        add  ax,128
.c2:   sub  ax,BIAS
        mov  [wcz],ax
        call ROTCUL             ; bounds -> rotate corners -> cull
        jc   .ret
        ; ground height under this cell (terrain-aware)
        mov  ax,[gi]
        mov  bx,[gj]
        call GETH
        call WORLDH
        mov  [gbase],ax
        ; flat terrain patch (forest/water/field)? fill it on the local ground
        mov  ax,[bstreet]
        cmp  ax,2
        jne  .solid
        mov  ax,[gbase]
        add  ax,2               ; a hair above the terrain quad (paint order)
        sub  ax,[camy]
        mov  [bry1],ax
        mov  al,[bcol]
        mov  [COLOR],al
        call FACETOPC
        call FACEFILL
        jmp  .ret
.solid:
        ; pick this building's wall colours from its scheme (SimCity mix)
        mov  bx,[bschm]
        add  bx,bx
        mov  al,[WSCH+bx]
        mov  [wallL],al
        mov  al,[WSCH+bx+1]
        mov  [wallS],al
        ; composite structures: each type is a small stack of DRAWBOX calls
        mov  ax,[wcx]           ; composites move the centre - remember it
        mov  [pwcx],ax
        mov  ax,[wcz]
        mov  [pwcz],ax
        mov  ax,[btype]
        cmp  ax,1
        je   .bspire
        cmp  ax,2
        je   .btower
        cmp  ax,3
        je   .barch
        cmp  ax,4
        je   .bfact
        mov  word [boxb],0  ; type 0: plain box
        mov  ax,[bhgt2]
        mov  [boxt],ax
        call DRAWBOX
        jmp  .ret
        ; ---- the composites doubled with the plot, 2026-08-03: a spire
        ; sized for a 256 cell is a needle on a 512 one.
.bspire:                       ; slim tall block + antenna spike
        mov  word [bhw],112
        mov  word [bhd],112
        mov  word [boxb],0
        mov  ax,[bhgt2]
        add  ax,120             ; spires read taller than plain boxes
        mov  [boxt],ax
        call DRAWBOX
        mov  word [bhw],28
        mov  word [bhd],28
        mov  ax,[bhgt2]
        add  ax,120
        mov  [boxb],ax
        add  ax,180
        mov  [boxt],ax
        call DRAWBOX
        jmp  .ret
.btower:                       ; telescoping tower: wide base, narrow top
        mov  word [boxb],0
        mov  ax,[bhgt2]
        shr  ax,1
        mov  [boxt],ax
        call DRAWBOX
        mov  ax,[bhw]
        shr  ax,1
        add  ax,24
        mov  [bhw],ax
        mov  [bhd],ax
        mov  ax,[bhgt2]
        shr  ax,1
        mov  [boxb],ax
        mov  ax,[bhgt2]
        mov  [boxt],ax
        call DRAWBOX
        jmp  .ret
.barch:                        ; gate building: two legs + lintel on top
        mov  ax,[bhgt2]
        cmp  ax,480
        jle  .ba1
        mov  ax,480
.ba1:  mov  [boxt],ax          ; leg height
        mov  word [bhw],68
        mov  word [bhd],160
        mov  word [boxb],0
        mov  ax,[pwcx]
        sub  ax,152
        mov  [wcx],ax
        call DRAWBOX
        mov  ax,[pwcx]
        add  ax,152
        mov  [wcx],ax
        call DRAWBOX
        mov  ax,[pwcx]          ; lintel spans both legs
        mov  [wcx],ax
        mov  word [bhw],220
        mov  bx,[boxt]
        mov  ax,bx
        sub  ax,88
        mov  [boxb],ax
        mov  ax,bx
        add  ax,12
        mov  [boxt],ax
        call DRAWBOX
        jmp  .ret
.bfact:                        ; factory: low hall + chimney + smoke loop
        mov  word [boxb],0
        mov  ax,[bhgt2]
        mov  [boxt],ax          ; hall (industrial heights are low)
        call DRAWBOX
        mov  word [bhw],26
        mov  word [bhd],26
        mov  ax,[pwcx]
        add  ax,128
        mov  [wcx],ax
        mov  ax,[pwcz]
        add  ax,80
        mov  [wcz],ax
        mov  word [boxb],0
        mov  word [boxt],360
        call DRAWBOX            ; chimney
        ; SimCity-style smoke: 3 puffs rise on a loop and dissolve. Phase is
        ; driven by the BIOS tick, so the animation speed is real-time.
        mov  word [puffk],0
.pf:   mov  si,[puffk]
        add  si,si
        mov  ax,[lasttk]
        add  ax,ax              ; climb 2 units per tick
        add  ax,[PUFO+si]       ; per-puff phase offset
        and  ax,63              ; age 0..63
        cmp  ax,50
        ja   .pnx              ; old puff has dissolved
        mov  bx,ax
        mov  cl,1
        shr  bx,cl
        add  bx,14              ; puffs grow as they rise: half-size 14..38
        mov  [bhw],bx
        mov  [bhd],bx
        add  ax,ax
        add  ax,360             ; chimney top + age
        mov  [boxb],ax
        add  ax,20
        mov  [boxt],ax
        call PUFFBOX
.pnx:  inc  word [puffk]
        cmp  word [puffk],3
        jl   .pf
.ret:  ret

; ============================================================================
;  ROADCELL - one city street cell: the tarmac, then the traffic on it.
;  The tarmac is cut off at ROADR / ROADZ, the traffic much nearer at CARZ -
;  past that a car is one pixel and costs a whole box.
;  TWO LEVELS OF DETAIL (see the constants in OWLFLY3.ASM): out past ROADLOD a
;  quad covers a 2x2 GROUP of cells instead of one, and only the group's
;  even/even anchor draws it. That is an exact merge, not a simplification -
;  an avenue is two cells wide and every one of those groups is road all the
;  way through - and it is what lets the road reach the whole walk.
;  The surface is bent onto the terrain corner by corner by ROADYF; the
;  flat gbase is now only what the VEHICLES stand on.
; ============================================================================
ROADCELL:
        mov  ax,[cdi]           ; ---- the cheap cull FIRST. Everything below
        or   ax,ax              ; costs four rotations and a big fill, and
        jns  .d1               ; there are a thousand street cells in the
        neg  ax                 ; walk. Chebyshev on the cell offsets: no
.d1:   mov  bx,ax              ; multiply, no projection, just two compares.
        mov  ax,[cdj]
        or   ax,ax
        jns  .d2
        neg  ax
.d2:   cmp  ax,bx
        jle  .d3
        mov  bx,ax
.d3:   cmp  bx,ROADR           ; bx = the distance in CELLS, and it decides
        jg   .x                ; the level of detail as well as the cull
        mov  word [rlod],0
        cmp  bx,ROADLOD
        jle  .one
        mov  ax,[gi]            ; ---- grouped: the 2x2 block of cells whose
        or   ax,[gj]            ; corner is even. Only that corner draws;
        test ax,1               ; the other three are inside its quad.
        jnz  .x
        mov  word [rlod],1
.one:  mov  ax,[gi]            ; cell centre: gi*256 + 128 - BIAS ...
        mov  cl,8
        shl  ax,cl
        add  ax,128
        cmp  word [rlod],0
        je   .c1
        add  ax,128             ; ...and a group's centre is a cell further
.c1:   sub  ax,BIAS
        mov  [wcx],ax
        mov  ax,[gj]
        mov  cl,8
        shl  ax,cl
        add  ax,128
        cmp  word [rlod],0
        je   .c2
        add  ax,128
.c2:   sub  ax,BIAS
        mov  [wcz],ax
        mov  ax,128             ; the full cell, edge to edge - or the full
        cmp  word [rlod],0  ; group, which is two of them
        je   .c3
        mov  ax,256
.c3:   mov  [bhw],ax
        mov  [bhd],ax
        call ROTCUL
        jc   .r
        mov  ax,[minrz]
        cmp  ax,ROADZ
        jg   .r
        mov  byte [COLOR],ASPHALT
        call FACETOPC           ; the quad, flat...
        call TOWNSEG:ROADYF   ; ...and now bent onto the ground, corner by
        call FACEFILL           ; corner (see TOWN.INC: it used to take ONE
                                ; height for the whole cell, which on a
                                ; slope is a slab hovering over the hill)
        cmp  word [rlod],0
        jne  .r                ; grouped detail is too far out for traffic
        mov  ax,[minrz]
        cmp  ax,CARZ
        jg   .r                ; tarmac reaches further than the traffic
        mov  ax,[gi]            ; the ground the vehicles stand on
        mov  bx,[gj]
        call GETH
        call WORLDH
        mov  [gbase],ax
        mov  word [vmode],0 ; draw them, do not test them
        call TOWNSEG:TRAFFICF
.r:
.x:    ret

; ============================================================================
;  ROTCUL - shared box setup: world bounds from (wcx,wcz,bhw,bhd), rotate the
;  4 footprint corners into camera space (FRX/FRZ), track min/max rz, and
;  cull. out: CF=1 -> box entirely behind/beyond, skip drawing.
; ============================================================================
ROTCUL:
        mov  ax,[wcx]
        sub  ax,[bhw]
        mov  [bwx0],ax
        mov  ax,[wcx]
        add  ax,[bhw]
        mov  [bwx1],ax
        mov  ax,[wcz]
        sub  ax,[bhd]
        mov  [bwz0],ax
        mov  ax,[wcz]
        add  ax,[bhd]
        mov  [bwz1],ax
        mov  word [minrz],32767
        mov  word [maxrz],-32768
        mov  ax,[bwx0]          ; corner 0 = (bwx0,bwz0)
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[bwz0]
        sub  ax,[camz]
        mov  [wdz],ax
        call ROTXZ
        mov  ax,[rc_x]
        mov  [FRX],ax
        mov  ax,[rc_z]
        mov  [FRZ],ax
        call .trk
        mov  ax,[bwx1]          ; corner 1 = (bwx1,bwz0)
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[bwz0]
        sub  ax,[camz]
        mov  [wdz],ax
        call ROTXZ
        mov  ax,[rc_x]
        mov  [FRX+2],ax
        mov  ax,[rc_z]
        mov  [FRZ+2],ax
        call .trk
        mov  ax,[bwx1]          ; corner 2 = (bwx1,bwz1)
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[bwz1]
        sub  ax,[camz]
        mov  [wdz],ax
        call ROTXZ
        mov  ax,[rc_x]
        mov  [FRX+4],ax
        mov  ax,[rc_z]
        mov  [FRZ+4],ax
        call .trk
        mov  ax,[bwx0]          ; corner 3 = (bwx0,bwz1)
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[bwz1]
        sub  ax,[camz]
        mov  [wdz],ax
        call ROTXZ
        mov  ax,[rc_x]
        mov  [FRX+6],ax
        mov  ax,[rc_z]
        mov  [FRZ+6],ax
        call .trk
        mov  ax,[maxrz]         ; cull
        cmp  ax,NEARZ
        jl   .rej              ; entirely behind
        mov  ax,[minrz]
        cmp  ax,FARZ
        jg   .rej              ; entirely too far
        clc
        ret
.rej:  stc
        ret
.trk:  mov  ax,[rc_z]           ; update minrz/maxrz with rc_z
        cmp  ax,[minrz]
        jge  .t1
        mov  [minrz],ax
.t1:   cmp  ax,[maxrz]
        jle  .t2
        mov  [maxrz],ax
.t2:   ret

; iterate visible vertical faces, calling FACEV+FACEFILL for each
VISFILL:
        ; west  (camx < bwx0): corners 3,0  - E/W faces get the shaded colour
        mov  ax,[camx]
        cmp  ax,[bwx0]
        jge  .e
        mov  al,[wallS]
        mov  [COLOR],al
        mov  word [fa],3
        mov  word [fb],0
        call FACEV
        call FACEFILL
.e:    mov  ax,[camx]          ; east (camx > bwx1): 1,2
        cmp  ax,[bwx1]
        jle  .s
        mov  al,[wallS]
        mov  [COLOR],al
        mov  word [fa],1
        mov  word [fb],2
        call FACEV
        call FACEFILL
.s:    mov  ax,[camz]          ; south (camz < bwz0): 0,1 - sun-facing sides
        cmp  ax,[bwz0]
        jge  .n
        mov  al,[wallL]
        mov  [COLOR],al
        mov  word [fa],0
        mov  word [fb],1
        call FACEV
        call FACEFILL
.n:    mov  ax,[camz]          ; north (camz > bwz1): 2,3
        cmp  ax,[bwz1]
        jle  .d
        mov  al,[wallL]
        mov  [COLOR],al
        mov  word [fa],2
        mov  word [fb],3
        call FACEV
        call FACEFILL
.d:    ret

; iterate visible vertical faces, stroking + windows on near ones
VISSTROKE:
        mov  ax,[camx]
        cmp  ax,[bwx0]
        jge  .e
        mov  word [fa],3
        mov  word [fb],0
        call EDGEWIN
.e:    mov  ax,[camx]
        cmp  ax,[bwx1]
        jle  .s
        mov  word [fa],1
        mov  word [fb],2
        call EDGEWIN
.s:    mov  ax,[camz]
        cmp  ax,[bwz0]
        jge  .n
        mov  word [fa],0
        mov  word [fb],1
        call EDGEWIN
.n:    mov  ax,[camz]
        cmp  ax,[bwz1]
        jle  .d
        mov  word [fa],2
        mov  word [fb],3
        call EDGEWIN
.d:    ret

; ---------------------------------------------------------------------------
;  EDGEWIN - outline one wall, then glaze it.
;  THE ORDER IS LOAD-BEARING. WINFACEF reads IX/IY/IZ expecting them to have
;  been PITCHED ALREADY - FACESTROKE's CLIPNEAR does that in place - and
;  PX/PY expecting the wall's projected outline, which PROJPOLY leaves
;  there. Pitch them a second time and the glass turns again about the
;  camera axis and slides off the wall exactly when you dive at the city,
;  which is the only way you ever approach it.
;  There is no distance gate any more: WINFACEF decides from the wall's own
;  projected size, so the glass fades in instead of switching on at 1200.
; ---------------------------------------------------------------------------
EDGEWIN:
        call FACEV
        mov  al,[scol]          ; windows change COLOR - restore per face
        mov  [COLOR],al
        call FACESTROKE
        cmp  byte [qual],2      ; LOW: boxes and nothing but boxes. The
        je   .x                 ;  glass is a per-wall pass of its own and
                                ;  the city has hundreds of walls in it.
        mov  ax,[NPOLY]         ; the wall never made it through the clip
        cmp  ax,3
        jl   .x
        cmp  word [bhw],50  ; no windows on spikes/chimneys/lintels
        jl   .x
        mov  ax,[boxt]
        sub  ax,[boxb]
        cmp  ax,60              ; nor on flat slabs
        jl   .x
        call TOWNSEG:WINFACEF
.x:    ret
