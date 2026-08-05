; WORLD.INC - part of WIRE CITY (included from CITY.ASM)
; DEAD (flat-ground era; replaced by the TERRAIN mesh, no callers) -----------
; Kept as READING, not as bytes: the radar stations of 2026-07-28 needed the
; room and this routine had no callers left. IF 0 hands the whole thing to
; the assembler's wastebasket - every line survives here, none of them ship.
; ----- ground grid: world-aligned lines around the camera (rotate with view)
IF 0
GRID:   mov  byte ptr [COLOR],6
        ; lines parallel to world-Z (fixed X = gi)
        mov  ax,[camgi]
        sub  ax,GR
        mov  [gi],ax
@@gx:   mov  ax,[gi]            ; worldX = gi*256 - BIAS
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
        mov  ax,[rcx]
        mov  [x0],ax
        mov  ax,[rcz]
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
        mov  ax,[rcx]
        mov  [x1],ax
        mov  ax,[rcz]
        mov  [z1],ax
        mov  ax,[camy]
        neg  ax
        mov  [y0],ax
        mov  [y1],ax
        call DRAWEDGE3D
        mov  ax,[gi]
        inc  ax
        mov  [gi],ax
        mov  bx,[camgi]
        add  bx,GR
        cmp  ax,bx
        jle  @@gx
        ; lines parallel to world-X (fixed Z = gj)
        mov  ax,[camgj]
        sub  ax,GR
        mov  [gj],ax
@@gz:   mov  ax,[gj]
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
        mov  ax,[rcx]
        mov  [x0],ax
        mov  ax,[rcz]
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
        mov  ax,[rcx]
        mov  [x1],ax
        mov  ax,[rcz]
        mov  [z1],ax
        mov  ax,[camy]
        neg  ax
        mov  [y0],ax
        mov  [y1],ax
        call DRAWEDGE3D
        mov  ax,[gj]
        inc  ax
        mov  [gj],ax
        mov  bx,[camgj]
        add  bx,GR
        cmp  ax,bx
        jle  @@gz
        ret
ENDIF
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
        mov  word ptr [ring],0  ; reuse [ring] as the BORD index
@@bl:   mov  si,[ring]
        add  si,si
        mov  al,[BORD+si]       ; di (signed)
        cbw
        mov  [cdi],ax
        mov  al,[BORD+si+1]     ; dj (signed)
        cbw
        mov  [cdj],ax
        call RENDERCELL
        inc  word ptr [ring]
        cmp  word ptr [ring],2401
        jl   @@bl
        ret

; ============================================================================
;  DRAWBOX - one solid box standing on the terrain. Centre [wcx,wcz], half
;  size bhw/bhd, vertical span gbase+boxb .. gbase+boxt. Runs the normal
;  visible-face fill + distance-coloured stroke + windows. boxb/boxt survive.
; ============================================================================
DRAWBOX:
        call ROTCUL
        jc   @@r
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
        jle  @@nf
        call FACETOPC
        call FACEFILL
@@nf:   call VISFILL
        mov  ax,[minrz]         ; stroke colour by distance
        cmp  ax,500
        jg   @@nn
        mov  al,3
        jmp  @@cc
@@nn:   cmp  ax,1200
        jg   @@ff
        mov  al,2
        jmp  @@cc
@@ff:   mov  al,1
@@cc:   mov  [COLOR],al
        mov  [scol],al          ; VISSTROKE restores this per face
        mov  ax,[gbase]
        add  ax,[boxt]
        cmp  [camy],ax
        jle  @@ns
        call FACETOPC
        call FACESTROKE
@@ns:   call VISSTROKE
@@r:    ret

; ============================================================================
;  PUFFBOX - one soft smoke cube: haze colour, no outline, no windows.
;  Same box parameters as DRAWBOX.
; ============================================================================
PUFFBOX:
        call ROTCUL
        jc   @@r
        mov  ax,[gbase]
        add  ax,[boxb]
        sub  ax,[camy]
        mov  [bry0],ax
        mov  ax,[gbase]
        add  ax,[boxt]
        sub  ax,[camy]
        mov  [bry1],ax
        mov  byte ptr [COLOR],12 ; horizon-haze grey reads as smoke
        mov  ax,[gbase]
        add  ax,[boxt]
        cmp  [camy],ax
        jle  @@nf
        call FACETOPC
        call FACEFILL
@@nf:   call MEGAFILL           ; flat fill that keeps the smoke colour
@@r:    ret

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
        je   @@ret              ; not city: the terrain mesh paints it
        cmp  ax,3
        jne  @@notroad
        call ROADCELL           ; a city street: tarmac, then whatever is
        jmp  @@ret              ; driving on it
@@notroad:
        mov  byte ptr [roofc],17
        call BCHK
        jz   @@stands
        jmp  @@ret              ; a ruin: rubble and smoke, no walls
@@stands:
        ; cell centre world coords:  gi*256 + 128 - BIAS   (shl = *CELL)
        ; ...but a BUILDING owns the 2x2 plot whose corner this cell is, so
        ; its centre is another 128 out on both axes. The flat patches
        ; (forest/water/field) are still one cell each and keep the first.
        mov  ax,[gi]
        mov  cl,8
        shl  ax,cl
        add  ax,128
        cmp  word ptr [bstreet],0
        jne  @@c1
        add  ax,128
@@c1:   sub  ax,BIAS
        mov  [wcx],ax
        mov  ax,[gj]
        mov  cl,8
        shl  ax,cl
        add  ax,128
        cmp  word ptr [bstreet],0
        jne  @@c2
        add  ax,128
@@c2:   sub  ax,BIAS
        mov  [wcz],ax
        call ROTCUL             ; bounds -> rotate corners -> cull
        jc   @@ret
        ; ground height under this cell (terrain-aware)
        mov  ax,[gi]
        mov  bx,[gj]
        call GETH
        call WORLDH
        mov  [gbase],ax
        ; flat terrain patch (forest/water/field)? fill it on the local ground
        mov  ax,[bstreet]
        cmp  ax,2
        jne  @@solid
        mov  ax,[gbase]
        add  ax,2               ; a hair above the terrain quad (paint order)
        sub  ax,[camy]
        mov  [bry1],ax
        mov  al,[bcol]
        mov  [COLOR],al
        call FACETOPC
        call FACEFILL
        jmp  @@ret
@@solid:
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
        je   @@bspire
        cmp  ax,2
        je   @@btower
        cmp  ax,3
        je   @@barch
        cmp  ax,4
        je   @@bfact
        mov  word ptr [boxb],0  ; type 0: plain box
        mov  ax,[bhgt2]
        mov  [boxt],ax
        call DRAWBOX
        jmp  @@ret
        ; ---- the composites doubled with the plot, 2026-08-03: a spire
        ; sized for a 256 cell is a needle on a 512 one.
@@bspire:                       ; slim tall block + antenna spike
        mov  word ptr [bhw],112
        mov  word ptr [bhd],112
        mov  word ptr [boxb],0
        mov  ax,[bhgt2]
        add  ax,120             ; spires read taller than plain boxes
        mov  [boxt],ax
        call DRAWBOX
        mov  word ptr [bhw],28
        mov  word ptr [bhd],28
        mov  ax,[bhgt2]
        add  ax,120
        mov  [boxb],ax
        add  ax,180
        mov  [boxt],ax
        call DRAWBOX
        jmp  @@ret
@@btower:                       ; telescoping tower: wide base, narrow top
        mov  word ptr [boxb],0
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
        jmp  @@ret
@@barch:                        ; gate building: two legs + lintel on top
        mov  ax,[bhgt2]
        cmp  ax,480
        jle  @@ba1
        mov  ax,480
@@ba1:  mov  [boxt],ax          ; leg height
        mov  word ptr [bhw],68
        mov  word ptr [bhd],160
        mov  word ptr [boxb],0
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
        mov  word ptr [bhw],220
        mov  bx,[boxt]
        mov  ax,bx
        sub  ax,88
        mov  [boxb],ax
        mov  ax,bx
        add  ax,12
        mov  [boxt],ax
        call DRAWBOX
        jmp  @@ret
@@bfact:                        ; factory: low hall + chimney + smoke loop
        mov  word ptr [boxb],0
        mov  ax,[bhgt2]
        mov  [boxt],ax          ; hall (industrial heights are low)
        call DRAWBOX
        mov  word ptr [bhw],26
        mov  word ptr [bhd],26
        mov  ax,[pwcx]
        add  ax,128
        mov  [wcx],ax
        mov  ax,[pwcz]
        add  ax,80
        mov  [wcz],ax
        mov  word ptr [boxb],0
        mov  word ptr [boxt],360
        call DRAWBOX            ; chimney
        ; SimCity-style smoke: 3 puffs rise on a loop and dissolve. Phase is
        ; driven by the BIOS tick, so the animation speed is real-time.
        mov  word ptr [puffk],0
@@pf:   mov  si,[puffk]
        add  si,si
        mov  ax,[lasttk]
        add  ax,ax              ; climb 2 units per tick
        add  ax,[PUFO+si]       ; per-puff phase offset
        and  ax,63              ; age 0..63
        cmp  ax,50
        ja   @@pnx              ; old puff has dissolved
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
@@pnx:  inc  word ptr [puffk]
        cmp  word ptr [puffk],3
        jl   @@pf
@@ret:  ret

; ============================================================================
;  ROADCELL - one city street cell: the tarmac, then the traffic on it.
;  The tarmac is cut off at ROADR / ROADZ, the traffic much nearer at CARZ -
;  past that a car is one pixel and costs a whole box.
;  TWO LEVELS OF DETAIL (see the constants in CITY.ASM): out past ROADLOD a
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
        jns  @@d1               ; there are a thousand street cells in the
        neg  ax                 ; walk. Chebyshev on the cell offsets: no
@@d1:   mov  bx,ax              ; multiply, no projection, just two compares.
        mov  ax,[cdj]
        or   ax,ax
        jns  @@d2
        neg  ax
@@d2:   cmp  ax,bx
        jle  @@d3
        mov  bx,ax
@@d3:   cmp  bx,ROADR           ; bx = the distance in CELLS, and it decides
        jg   @@x                ; the level of detail as well as the cull
        mov  word ptr [rlod],0
        cmp  bx,ROADLOD
        jle  @@one
        mov  ax,[gi]            ; ---- grouped: the 2x2 block of cells whose
        or   ax,[gj]            ; corner is even. Only that corner draws;
        test ax,1               ; the other three are inside its quad.
        jnz  @@x
        mov  word ptr [rlod],1
@@one:  mov  ax,[gi]            ; cell centre: gi*256 + 128 - BIAS ...
        mov  cl,8
        shl  ax,cl
        add  ax,128
        cmp  word ptr [rlod],0
        je   @@c1
        add  ax,128             ; ...and a group's centre is a cell further
@@c1:   sub  ax,BIAS
        mov  [wcx],ax
        mov  ax,[gj]
        mov  cl,8
        shl  ax,cl
        add  ax,128
        cmp  word ptr [rlod],0
        je   @@c2
        add  ax,128
@@c2:   sub  ax,BIAS
        mov  [wcz],ax
        mov  ax,128             ; the full cell, edge to edge - or the full
        cmp  word ptr [rlod],0  ; group, which is two of them
        je   @@c3
        mov  ax,256
@@c3:   mov  [bhw],ax
        mov  [bhd],ax
        call ROTCUL
        jc   @@r
        mov  ax,[minrz]
        cmp  ax,ROADZ
        jg   @@r
        mov  byte ptr [COLOR],ASPHALT
        call FACETOPC           ; the quad, flat...
        call FAR PTR ROADYF     ; ...and now bent onto the ground, corner by
        call FACEFILL           ; corner (see TOWN.INC: it used to take ONE
                                ; height for the whole cell, which on a
                                ; slope is a slab hovering over the hill)
        cmp  word ptr [rlod],0
        jne  @@r                ; grouped detail is too far out for traffic
        mov  ax,[minrz]
        cmp  ax,CARZ
        jg   @@r                ; tarmac reaches further than the traffic
        mov  ax,[gi]            ; the ground the vehicles stand on
        mov  bx,[gj]
        call GETH
        call WORLDH
        mov  [gbase],ax
        mov  word ptr [vmode],0 ; draw them, do not test them
        call FAR PTR TRAFFICF
@@r:
@@x:    ret

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
        mov  word ptr [minrz],32767
        mov  word ptr [maxrz],-32768
        mov  ax,[bwx0]          ; corner 0 = (bwx0,bwz0)
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[bwz0]
        sub  ax,[camz]
        mov  [wdz],ax
        call ROTXZ
        mov  ax,[rcx]
        mov  [FRX],ax
        mov  ax,[rcz]
        mov  [FRZ],ax
        call @@trk
        mov  ax,[bwx1]          ; corner 1 = (bwx1,bwz0)
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[bwz0]
        sub  ax,[camz]
        mov  [wdz],ax
        call ROTXZ
        mov  ax,[rcx]
        mov  [FRX+2],ax
        mov  ax,[rcz]
        mov  [FRZ+2],ax
        call @@trk
        mov  ax,[bwx1]          ; corner 2 = (bwx1,bwz1)
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[bwz1]
        sub  ax,[camz]
        mov  [wdz],ax
        call ROTXZ
        mov  ax,[rcx]
        mov  [FRX+4],ax
        mov  ax,[rcz]
        mov  [FRZ+4],ax
        call @@trk
        mov  ax,[bwx0]          ; corner 3 = (bwx0,bwz1)
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[bwz1]
        sub  ax,[camz]
        mov  [wdz],ax
        call ROTXZ
        mov  ax,[rcx]
        mov  [FRX+6],ax
        mov  ax,[rcz]
        mov  [FRZ+6],ax
        call @@trk
        mov  ax,[maxrz]         ; cull
        cmp  ax,NEARZ
        jl   @@rej              ; entirely behind
        mov  ax,[minrz]
        cmp  ax,FARZ
        jg   @@rej              ; entirely too far
        clc
        ret
@@rej:  stc
        ret
@@trk:  mov  ax,[rcz]           ; update minrz/maxrz with rcz
        cmp  ax,[minrz]
        jge  @@t1
        mov  [minrz],ax
@@t1:   cmp  ax,[maxrz]
        jle  @@t2
        mov  [maxrz],ax
@@t2:   ret

; iterate visible vertical faces, calling FACEV+FACEFILL for each
VISFILL:
        ; west  (camx < bwx0): corners 3,0  - E/W faces get the shaded colour
        mov  ax,[camx]
        cmp  ax,[bwx0]
        jge  @@e
        mov  al,[wallS]
        mov  [COLOR],al
        mov  word ptr [fa],3
        mov  word ptr [fb],0
        call FACEV
        call FACEFILL
@@e:    mov  ax,[camx]          ; east (camx > bwx1): 1,2
        cmp  ax,[bwx1]
        jle  @@s
        mov  al,[wallS]
        mov  [COLOR],al
        mov  word ptr [fa],1
        mov  word ptr [fb],2
        call FACEV
        call FACEFILL
@@s:    mov  ax,[camz]          ; south (camz < bwz0): 0,1 - sun-facing sides
        cmp  ax,[bwz0]
        jge  @@n
        mov  al,[wallL]
        mov  [COLOR],al
        mov  word ptr [fa],0
        mov  word ptr [fb],1
        call FACEV
        call FACEFILL
@@n:    mov  ax,[camz]          ; north (camz > bwz1): 2,3
        cmp  ax,[bwz1]
        jle  @@d
        mov  al,[wallL]
        mov  [COLOR],al
        mov  word ptr [fa],2
        mov  word ptr [fb],3
        call FACEV
        call FACEFILL
@@d:    ret

; iterate visible vertical faces, stroking + windows on near ones
VISSTROKE:
        mov  ax,[camx]
        cmp  ax,[bwx0]
        jge  @@e
        mov  word ptr [fa],3
        mov  word ptr [fb],0
        call EDGEWIN
@@e:    mov  ax,[camx]
        cmp  ax,[bwx1]
        jle  @@s
        mov  word ptr [fa],1
        mov  word ptr [fb],2
        call EDGEWIN
@@s:    mov  ax,[camz]
        cmp  ax,[bwz0]
        jge  @@n
        mov  word ptr [fa],0
        mov  word ptr [fb],1
        call EDGEWIN
@@n:    mov  ax,[camz]
        cmp  ax,[bwz1]
        jle  @@d
        mov  word ptr [fa],2
        mov  word ptr [fb],3
        call EDGEWIN
@@d:    ret

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
        mov  ax,[NPOLY]         ; the wall never made it through the clip
        cmp  ax,3
        jl   @@x
        cmp  word ptr [bhw],50  ; no windows on spikes/chimneys/lintels
        jl   @@x
        mov  ax,[boxt]
        sub  ax,[boxb]
        cmp  ax,60              ; nor on flat slabs
        jl   @@x
        call FAR PTR WINFACEF
@@x:    ret
