; TOWN.INC - part of WIRE CITY (included from CITY.ASM, after SYM.INC)
; ============================================================================
;  THE FIFTH SEGMENT, opened 2026-08-03 because the main segment had
;  TWENTY-SIX bytes left and the rule in this project is to open a segment,
;  not to shave bytes. The arrangement is SKYSEG's, UISEG's and SYMSEG's,
;  copied: PARA aligned, padded to claim its whole window so the linker
;  parks the next thing where the loader expects, and an assemble-time
;  guard that refuses to overflow.
;  Layout now: CODE at CS+0, SKYSEG CS+1000h, UISEG CS+1200h, SYMSEG
;  CS+1400h, TOWNSEG CS+1600h... - see CITY.ASM, which moved the back
;  buffer up to CS+1A00h to make room.
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
;  Far doors: WINFACEF (glaze a wall).
;
;  Developed in LAB\HOUSE.COM, which is where to go to change any of it -
;  it holds one city block still and lets you walk round it. See
;  LAB\README.md.
; ============================================================================

TOWNSEG SEGMENT PARA PUBLIC 'CODE'
        ASSUME  CS:TOWNSEG, DS:CODE, ES:NOTHING, SS:CODE

TOWNBASE label byte             ; offset zero, for the window guard below

; ============================================================================
;  WINFACEF - lit panes on the current wall (IX/IY/IZ[0..3] already pitched
;  by the CLIPNEAR inside FACESTROKE; PX/PY hold its projected outline).
;
;  THE PANE IS A QUAD ON THE WALL, not a square stamped on the screen.
;  What was here before got the pane CENTRES right - lerped in camera space
;  and projected one at a time - and then drew each pane as an axis-aligned
;  square of fixed world size. A square does not foreshorten. Look along a
;  wall and its columns crowd together while the glass keeps its width; the
;  windows stop lying on the brick and start floating over it.
;
;  DOING IT WITHOUT A MATRIX PER PANE. A wall quad is A_bot, A_top, B_top,
;  B_bot - and A_top-A_bot equals B_top-B_bot, because both are the same
;  vertical rise. So the wall is a PARALLELOGRAM, and PITCH4 is linear, so
;  it is still one after the pitch. Every point on it is
;
;        P(i,j) = V0 + (i/NCOL)*U + (j/NROW)*V,   U = V3-V0, V = V1-V0
;
;  so the whole corner lattice comes out of ONE row of column offsets and
;  ONE column of row offsets, combined by ADDITION. NCOL+NROW+2
;  interpolations for the face, then nothing but adds. The panes SHARE that
;  lattice - 24 projections carry 15 panes instead of 60 - and the mullion
;  between them is made by shrinking each pane to half its cell after
;  projection, which at that size is the same picture as shrinking it on
;  the wall.
;
;  NO DISTANCE GATE. The old code refused to glaze anything past minrz
;  1200, so a city switched its lights on at a magic radius. The wall's own
;  projected box decides now: glass appears the moment the wall is worth
;  more than WMINPX pixels.
;
;  QUADS OR DOTS IS DECIDED PER WALL, and that is not a detail. Deciding
;  per PANE - draw a dot if this one comes out under two pixels - makes the
;  far city crawl: a pane on the threshold flips between dot and quad as
;  the camera creeps, its neighbour flips on a different frame, and the
;  facade seethes. A pane's projected size is not a smooth function of
;  anything. The WALL's is: it grows steadily as you approach. So one
;  decision, for the whole facade, once. A dot has no size to change and
;  sits on the unshrunk centre, which moves smoothly.
; ============================================================================
WINFACEF PROC FAR
        ; ---- the wall's own projected box: the cull and the level of
        ; detail in one. PX/PY are the outline FACESTROKE just projected.
        mov  cx,[NPOLY]
        mov  ax,[PX]
        mov  [fbx0],ax
        mov  [fbx1],ax
        mov  ax,[PY]
        mov  [fby0],ax
        mov  [fby1],ax
        dec  cx
        mov  si,2
@@bb:   mov  ax,[PX+si]
        cmp  ax,[fbx0]
        jge  @@b1
        mov  [fbx0],ax
@@b1:   cmp  ax,[fbx1]
        jle  @@b2
        mov  [fbx1],ax
@@b2:   mov  ax,[PY+si]
        cmp  ax,[fby0]
        jge  @@b3
        mov  [fby0],ax
@@b3:   cmp  ax,[fby1]
        jle  @@b4
        mov  [fby1],ax
@@b4:   add  si,2
        loop @@bb
        cmp  word ptr [fbx1],0  ; wholly off the glass? nothing to glaze
        jl   @@ret
        cmp  word ptr [fbx0],319
        jg   @@ret
        cmp  word ptr [fby1],0
        jl   @@ret
        cmp  word ptr [fby0],199
        jg   @@ret
        mov  ax,[fbx1]
        sub  ax,[fbx0]
        cmp  ax,WMINPX
        jl   @@ret
        mov  ax,[fby1]
        sub  ax,[fby0]
        cmp  ax,WMINPX
        jl   @@ret
        ; ---- quads or dots, once, for the whole wall ----------------------
        mov  byte ptr [wquad],0
        mov  ax,[fbx1]
        sub  ax,[fbx0]
        cwd
        mov  bx,NCOL
        idiv bx
        cmp  ax,WQUADPX
        jl   @@lod
        mov  ax,[fby1]
        sub  ax,[fby0]
        cwd
        mov  bx,NROW
        idiv bx
        cmp  ax,WQUADPX
        jl   @@lod
        mov  byte ptr [wquad],1
@@lod:
        ; ---- U along the wall, V up it ------------------------------------
        mov  ax,[IX+6]
        sub  ax,[IX]
        mov  [wux],ax
        mov  ax,[IY+6]
        sub  ax,[IY]
        mov  [wuy],ax
        mov  ax,[IZ+6]
        sub  ax,[IZ]
        mov  [wuz],ax
        mov  ax,[IX+2]
        sub  ax,[IX]
        mov  [wvx],ax
        mov  ax,[IY+2]
        sub  ax,[IY]
        mov  [wvy],ax
        mov  ax,[IZ+2]
        sub  ax,[IZ]
        mov  [wvz],ax
        ; ---- the two axes of offsets. Everything after this is addition.
        ; NOTE THE CS: OVERRIDES from here down. DS is the MAIN segment, so
        ; the lattice - which lives at the bottom of this file - has to be
        ; addressed through CS. Miss one and it reads the main segment
        ; instead, silently.
        mov  word ptr [wi],0
@@ci:   mov  si,[wi]
        add  si,si
        mov  ax,[wux]
        imul word ptr [wi]
        mov  bx,NCOL
        idiv bx
        mov  cs:[CUX+si],ax
        mov  ax,[wuy]
        imul word ptr [wi]
        mov  bx,NCOL
        idiv bx
        mov  cs:[CUY+si],ax
        mov  ax,[wuz]
        imul word ptr [wi]
        mov  bx,NCOL
        idiv bx
        mov  cs:[CUZ+si],ax
        inc  word ptr [wi]
        cmp  word ptr [wi],NCOL
        jle  @@ci
        mov  word ptr [wj],0
@@rj:   mov  si,[wj]
        add  si,si
        mov  ax,[wvx]
        imul word ptr [wj]
        mov  bx,NROW
        idiv bx
        mov  cs:[RVX+si],ax
        mov  ax,[wvy]
        imul word ptr [wj]
        mov  bx,NROW
        idiv bx
        mov  cs:[RVY+si],ax
        mov  ax,[wvz]
        imul word ptr [wj]
        mov  bx,NROW
        idiv bx
        mov  cs:[RVZ+si],ax
        inc  word ptr [wj]
        cmp  word ptr [wj],NROW
        jle  @@rj
        ; ---- project the lattice once ------------------------------------
        mov  word ptr [wj],0
@@lj:   mov  word ptr [wi],0
@@li:   mov  si,[wi]
        add  si,si
        mov  di,[wj]
        add  di,di
        mov  ax,[IZ]
        add  ax,cs:[CUZ+si]
        add  ax,cs:[RVZ+di]
        mov  [wlz],ax
        mov  ax,[IX]
        add  ax,cs:[CUX+si]
        add  ax,cs:[RVX+di]
        mov  [wlx],ax
        mov  ax,[IY]
        add  ax,cs:[CUY+si]
        add  ax,cs:[RVY+di]
        mov  [wly],ax
        mov  bx,[wj]            ; lattice slot = j*NSTR + i
        mov  cl,3
        shl  bx,cl
        add  bx,[wi]
        cmp  word ptr [wlz],NEARZ
        jge  @@lok
        mov  byte ptr cs:[WSOK+bx],0 ; this corner is behind us; any pane
        jmp  @@ln                    ; touching it drops out
@@lok:  mov  byte ptr cs:[WSOK+bx],1
        add  bx,bx
        push bx
        mov  ax,[wlx]
        mov  dx,[wly]
        mov  cx,[wlz]
        call FAR PTR PROJPTF
        pop  bx
        mov  cs:[WSX+bx],ax
        mov  cs:[WSY+bx],dx
@@ln:   inc  word ptr [wi]
        cmp  word ptr [wi],NCOL
        jle  @@li
        inc  word ptr [wj]
        cmp  word ptr [wj],NROW
        jle  @@lj
        ; ---- one pane per cell -------------------------------------------
        mov  byte ptr [wr],0
@@pr:   mov  byte ptr [wc],0
@@pc:   mov  al,[wr]
        cbw
        mov  cl,3
        shl  ax,cl              ; r*NSTR
        mov  bl,[wc]
        xor  bh,bh
        add  ax,bx
        mov  [wbase],ax         ; the cell's bottom-left lattice slot
        mov  bx,ax
        cmp  byte ptr cs:[WSOK+bx],0
        je   @@pn
        cmp  byte ptr cs:[WSOK+bx+1],0
        je   @@pn
        cmp  byte ptr cs:[WSOK+bx+NSTR],0
        je   @@pn
        cmp  byte ptr cs:[WSOK+bx+NSTR+1],0
        je   @@pn
        call WLIT2              ; dark windows are most of them
        jz   @@pn
        mov  si,[wbase]
        add  si,si
        mov  ax,cs:[WSX+si]     ; bottom left
        mov  [PX],ax
        mov  ax,cs:[WSY+si]
        mov  [PY],ax
        mov  ax,cs:[WSX+si+2]   ; bottom right
        mov  [PX+2],ax
        mov  ax,cs:[WSY+si+2]
        mov  [PY+2],ax
        mov  ax,cs:[WSX+si+2*NSTR+2] ; top right
        mov  [PX+4],ax
        mov  ax,cs:[WSY+si+2*NSTR+2]
        mov  [PY+4],ax
        mov  ax,cs:[WSX+si+2*NSTR]   ; top left
        mov  [PX+6],ax
        mov  ax,cs:[WSY+si+2*NSTR]
        mov  [PY+6],ax
        mov  ax,[PX]            ; centroid
        add  ax,[PX+2]
        add  ax,[PX+4]
        add  ax,[PX+6]
        sar  ax,1
        sar  ax,1
        mov  [wcxc],ax
        mov  ax,[PY]
        add  ax,[PY+2]
        add  ax,[PY+4]
        add  ax,[PY+6]
        sar  ax,1
        sar  ax,1
        mov  [wcyc],ax
        cmp  byte ptr [wquad],0
        je   @@dot              ; the whole wall is in dot mode
        xor  si,si              ; shrink to half the cell: the mullion
@@sh:   mov  ax,[PX+si]
        add  ax,[wcxc]
        sar  ax,1
        mov  [PX+si],ax
        mov  ax,[PY+si]
        add  ax,[wcyc]
        sar  ax,1
        mov  [PY+si],ax
        add  si,2
        cmp  si,8
        jb   @@sh
        mov  word ptr [NPOLY],4
        call FAR PTR SCANPLYF
        jmp  @@pn
@@dot:  ; one lit dot per window, from the UNSHRUNK centre - it moves as a
        ; smooth function of the camera, so the far city twinkles at worst
        ; and never changes size. A distant lit facade is exactly this.
        mov  ax,[wcxc]
        cmp  ax,0               ; MOV sets no flags - test, do not assume
        jl   @@pn
        cmp  ax,319
        jg   @@pn
        mov  bx,[wcyc]
        cmp  bx,0
        jl   @@pn
        cmp  bx,199
        jg   @@pn
        call FAR PTR PUTPIXF
@@pn:   inc  byte ptr [wc]
        cmp  byte ptr [wc],NCOL
        jl   @@pc
        inc  byte ptr [wr]
        cmp  byte ptr [wr],NROW
        jl   @@pr
@@ret:  ret
WINFACEF ENDP

; ---- lit? a hash of gi,gj,fa,wr,wc -> ZF=1 dark, else COLOR is the glass
WLIT2:  mov  ax,[gi]
        mov  bx,131
        imul bx
        mov  si,ax
        mov  ax,[gj]
        mov  bx,977
        imul bx
        add  ax,si
        mov  bx,[fa]
        add  ax,bx
        mov  bl,[wr]
        xor  bh,bh
        mov  cx,101
        push ax
        mov  ax,bx
        mul  cx
        mov  bx,ax
        pop  ax
        add  ax,bx
        mov  bl,[wc]
        xor  bh,bh
        mov  cx,57
        push ax
        mov  ax,bx
        mul  cx
        mov  bx,ax
        pop  ax
        add  ax,bx
        mov  bx,ax
        mov  cl,5
        shr  bx,cl
        xor  ax,bx
        mov  bx,ax
        and  bx,7
        cmp  bx,3
        jl   @@lit
        xor  al,al
        ret
@@lit:  mov  bx,ax
        and  bx,31
        jnz  @@cy
        mov  byte ptr [COLOR],5
        jmp  @@d
@@cy:   mov  byte ptr [COLOR],4
@@d:    mov  al,1
        or   al,al
        ret

; ============================================================================
;  TRAFFICF - the vehicles standing on, or driving through, one road cell.
;  ROADCELL has already set gi/gj, gbase and culled by distance.
;
;  THERE IS NO LIST OF VEHICLES, exactly as there is no list of buildings.
;  A vehicle's position is a function of (lane, slot, time) and nothing is
;  stored: the argument that lets the world ship as a recipe lets the
;  traffic ship as one too - and it means every client of a shared sky
;  computes identical traffic from the clock, with nothing on the wire.
;
;  THE LANE, NOT THE CELL, CARRIES THE PHASE. Hash the phase per cell and a
;  vehicle jumps sideways every time it crosses a cell boundary. So slots
;  are spaced one cell apart ALONG A LANE and numbered globally, and a cell
;  works out which slot happens to be inside it right now. A vehicle stays
;  the same vehicle - same size, same paint - all the way down the street.
;
;  THE RULES:
;
;  * Right-hand traffic falls out of the geometry. An avenue is two cells
;    wide; the lanes sit at +-LANEOF from its centre, and which one runs
;    which way is fixed so a driver's right hand is always to the kerb.
;
;  * The lights are a function of time, so they need no state either. The
;    north-south avenues take the first green, the east-west ones the
;    second, with an all-red clearance between. A whole lane starts and
;    stops together - which is what a signalled platoon looks like - so one
;    closed form serves every vehicle on it.
;
;  * A green is worth EXACTLY ONE BLOCK: CARV*CARG = 2048 = 8 cells. That
;    identity is the trick the rest hangs on. Because a slot advances a
;    whole number of blocks per cycle, and a block is 8 cells, THE CELL A
;    SLOT RESTS IN NEVER CHANGES MODULO 8. So "does this slot stop on a
;    crossing?" is answered once, by s AND 7, and forever. Ban those two
;    slots in eight and the junction is clear at every red, for free, with
;    no vehicle ever having to look at another one.
; ============================================================================
TRAFFICF PROC FAR
        mov  ax,[gi]
        and  ax,7
        cmp  ax,2
        jge  @@ew
        call NSAVE
@@ew:   mov  ax,[gj]
        and  ax,7
        cmp  ax,2
        jge  @@d
        call EWAVE
@@d:    ret
TRAFFICF ENDP

; ---- a north-south avenue: the lanes run along Z, the cell index along
; the lane is gj, and the light takes the first green ------------------------
NSAVE:  mov  ax,[gi]            ; the avenue's centre line
        and  ax,0FFF8h
        inc  ax
        mov  cl,8
        shl  ax,cl
        sub  ax,BIAS
        mov  [vcen],ax
        mov  word ptr [vstart],0
        call CARTIME
        mov  ax,[gi]
        and  ax,0FFF8h
        mov  [vlane],ax
        mov  word ptr [vaxis],0
        mov  ax,[gj]            ; the cell's own start along the lane
        mov  cl,8
        shl  ax,cl
        sub  ax,BIAS
        mov  [vcell],ax
        ; ---- the +Z lane, kerb to its right
        mov  ax,[vcen]
        add  ax,LANEOF
        mov  [wcx],ax
        mov  ax,[vcell]
        add  ax,[voff]
        mov  [wcz],ax
        mov  ax,[gj]
        sub  ax,32
        sub  ax,[vadv]
        mov  [vslot],ax
        mov  word ptr [vdir],1
        call VEHICLE
        ; ---- the -Z lane, mirrored inside its own cell so it runs the
        ; other way and hands over to the cell behind it, not ahead
        mov  ax,[vcen]
        sub  ax,LANEOF
        mov  [wcx],ax
        mov  ax,255
        sub  ax,[voff]
        add  ax,[vcell]
        mov  [wcz],ax
        mov  ax,[gj]
        sub  ax,32
        add  ax,[vadv]
        mov  [vslot],ax
        inc  word ptr [vlane]   ; the other side of the road is its own lane
        mov  word ptr [vdir],-1
        call VEHICLE
        ret

; ---- an east-west avenue: everything swapped, and the second green --------
EWAVE:  mov  ax,[gj]
        and  ax,0FFF8h
        inc  ax
        mov  cl,8
        shl  ax,cl
        sub  ax,BIAS
        mov  [vcen],ax
        mov  word ptr [vstart],CARG+CARCLR
        call CARTIME
        mov  ax,[gj]
        and  ax,0FFF8h
        add  ax,200             ; keep the two axes' lane keys apart
        mov  [vlane],ax
        mov  word ptr [vaxis],1
        mov  ax,[gi]
        mov  cl,8
        shl  ax,cl
        sub  ax,BIAS
        mov  [vcell],ax
        ; ---- the +X lane. Facing +X the kerb is at -Z, so this one takes
        ; the near side of the road and the -X lane the far side
        mov  ax,[vcen]
        sub  ax,LANEOF
        mov  [wcz],ax
        mov  ax,[vcell]
        add  ax,[voff]
        mov  [wcx],ax
        mov  ax,[gi]
        sub  ax,32
        sub  ax,[vadv]
        mov  [vslot],ax
        mov  word ptr [vdir],1
        call VEHICLE
        ; ---- the -X lane
        mov  ax,[vcen]
        add  ax,LANEOF
        mov  [wcz],ax
        mov  ax,255
        sub  ax,[voff]
        add  ax,[vcell]
        mov  [wcx],ax
        mov  ax,[gi]
        sub  ax,32
        add  ax,[vadv]
        mov  [vslot],ax
        inc  word ptr [vlane]
        mov  word ptr [vdir],-1
        call VEHICLE
        ret

; ============================================================================
;  CARTIME - where this lane's platoon has got to.
;   in:  vstart - the clock step in the cycle when this lane's green begins
;   out: voff - how far into its cell a vehicle is (0..255)
;        vadv - how many cells the platoon has advanced, all time
;  d = CARV * clamp(clock - start, 0, CARG) + CARRST, plus the whole blocks
;  banked in caradv. Two clamps and a multiply: a closed form, so no vehicle
;  has to be simulated and nothing has to be remembered.
; ============================================================================
CARTIME:
        mov  ax,[cartf]
        sub  ax,[vstart]
        jge  @@c1
        xor  ax,ax              ; the light has not gone green yet
@@c1:   cmp  ax,CARG
        jle  @@c2
        mov  ax,CARG            ; ...and now it is red again
@@c2:   mov  bx,CARV
        imul bx
        add  ax,CARRST
        mov  bx,ax
        and  ax,255
        mov  [voff],ax
        mov  cl,8
        shr  bx,cl
        add  bx,[caradv]
        mov  [vadv],bx
        ret

; ============================================================================
;  VEHICLE - is there one in this slot, and if so, put it on the road.
;  wcx/wcz are its centre; vaxis says which way its length runs; vdir which
;  way it points.
; ============================================================================
VEHICLE:
        mov  ax,[vslot]
        and  ax,7
        cmp  ax,2
        jl   @@no               ; this slot comes to rest ON a crossing, so
                                ; it does not exist - which is how the
                                ; junction stays clear at every red without
                                ; one vehicle ever looking at another
        call VHASH
        mov  [vh],ax
        and  ax,3
        jz   @@no               ; a gap in the traffic
        mov  ax,[vh]
        mov  cl,4
        shr  ax,cl
        and  ax,7               ; 0..4 car, 5 bus, 6..7 truck
        mov  [vtype],ax
        mov  ax,[vh]            ; the paint: eight lit/shade pairs
        mov  cl,8
        shr  ax,cl
        and  ax,7
        add  ax,ax
        add  ax,VCOL0
        mov  [wallL],al
        mov  [roofc],al
        inc  ax
        mov  [wallS],al
        call KDEAD              ; ...unless somebody shot it
        jc   @@no
        cmp  word ptr [vmode],0
        jne  @@test             ; a bullet is asking, not the renderer
        mov  ax,[wcx]           ; a two-box vehicle moves its own centre
        mov  [vcx0],ax
        mov  ax,[wcz]
        mov  [vcz0],ax
        mov  word ptr [boxb],0
        mov  ax,[vtype]
        cmp  ax,5
        je   @@bus
        cmp  ax,6
        jge  @@truck
        ; ---- a car: a low body with a cabin sat on it ---------------------
        mov  ax,31
        mov  bx,13
        call VSIZE
        mov  word ptr [boxt],14
        call FAR PTR DRAWBOXF
        mov  ax,15
        mov  bx,12
        call VSIZE
        mov  word ptr [boxb],14
        mov  word ptr [boxt],26
        call FAR PTR DRAWBOXF
        ret
@@bus:  ; ---- a bus IS a box, and there is no shame in that ----------------
        mov  ax,82
        mov  bx,18
        call VSIZE
        mov  word ptr [boxt],46
        call FAR PTR DRAWBOXF
        ret
@@truck:; ---- a truck: a tall cab in front, a longer body behind it --------
        mov  ax,16
        mov  bx,17
        call VSIZE
        mov  word ptr [boxt],42
        mov  ax,40
        call VSHIFT
        call FAR PTR DRAWBOXF
        mov  ax,40
        mov  bx,18
        call VSIZE
        mov  word ptr [boxb],6
        mov  word ptr [boxt],46
        mov  ax,-22
        call VSHIFT
        call FAR PTR DRAWBOXF
@@no:   ret

; ---- the bullet's question. One box round the whole vehicle: a shell does
; not care that a truck has a cab. THIS IS WHY THE TRAFFIC NEEDED NO LIST -
; given the cell, where its vehicle is right now is arithmetic, so the test
; is O(1) per round and there is nothing to search.
@@test: mov  bx,[vtype]         ; class: 0 car, 1 bus, 2 truck
        cmp  bx,5
        jb   @@c0
        je   @@c1
        mov  bx,2
        jmp  @@cls
@@c0:   xor  bx,bx
        jmp  @@cls
@@c1:   mov  bx,1
@@cls:  mov  al,cs:[VLEN+bx]    ; half length along the lane
        xor  ah,ah
        mov  [vhl],ax
        mov  al,cs:[VWID+bx]
        xor  ah,ah
        mov  [vhw],ax
        mov  al,cs:[VHGT+bx]
        xor  ah,ah
        mov  [vhh],ax
        cmp  word ptr [vaxis],0
        jne  @@tew
        mov  ax,[vhl]           ; length runs along Z
        mov  [vtz],ax
        mov  ax,[vhw]
        mov  [vtx],ax
        jmp  @@tgo
@@tew:  mov  ax,[vhl]
        mov  [vtx],ax
        mov  ax,[vhw]
        mov  [vtz],ax
@@tgo:  mov  ax,[hitx]
        sub  ax,[wcx]
        jns  @@t1
        neg  ax
@@t1:   cmp  ax,[vtx]
        jg   @@no
        mov  ax,[hitz]
        sub  ax,[wcz]
        jns  @@t2
        neg  ax
@@t2:   cmp  ax,[vtz]
        jg   @@no
        mov  ax,[hity]
        sub  ax,[gbase]         ; height above the road
        js   @@no
        cmp  ax,[vhh]
        jg   @@no
        call KADD               ; struck: it burns for KRESP ticks
        mov  word ptr [vhitf],1
        ret

VLEN    db 31,82,56             ; half length by class: car, bus, truck
VWID    db 13,18,18
VHGT    db 26,46,46

; ============================================================================
;  THE KILL RING. A vehicle is a function of (lane, slot, clock), so the only
;  thing that has to be REMEMBERED about one is that it is not there any
;  more - and that is true of at most a handful at a time. Eight slots,
;  round robin, each with a timer: exactly the trick the buildings' four
;  "walking wounded" use, and for the same reason. An old kill may be
;  forgotten and a fresh vehicle takes the road again; war is hazy.
;
;  It lives HERE, in TOWNSEG, and is reached with CS: overrides - DS is the
;  main segment. Nothing else in the program has any business with it, and
;  the main segment has 94 bytes left.
; ============================================================================
; ---- WINFACEF's corner lattice. It lives here, not in the main segment's
; BSS, because nothing out there has ever read a byte of it - and 180 bytes
; of the main segment is 180 bytes. Reached with CS: throughout.
CUX     dw (NCOL+1) dup(0)      ; i*U/NCOL, one per column boundary
CUY     dw (NCOL+1) dup(0)
CUZ     dw (NCOL+1) dup(0)
RVX     dw (NROW+1) dup(0)      ; j*V/NROW, one per row boundary
RVY     dw (NROW+1) dup(0)
RVZ     dw (NROW+1) dup(0)
WSX     dw NLAT dup(0)          ; the projected corner lattice...
WSY     dw NLAT dup(0)
WSOK    db NLAT dup(0)          ; ...and which of its corners are in front

KLANE   dw NKILL dup(0)
KSLOT   dw NKILL dup(0)
KTIM    dw NKILL dup(0)
KNEXT   dw 0

; KDEAD - is (vlane,vslot) a wreck?  CF=1 yes.  Clobbers AX,BX,CX.
KDEAD:  xor  bx,bx
        mov  cx,NKILL
@@k:    cmp  word ptr cs:[KTIM+bx],0
        je   @@kn
        mov  ax,[vlane]
        cmp  ax,cs:[KLANE+bx]
        jne  @@kn
        mov  ax,[vslot]
        cmp  ax,cs:[KSLOT+bx]
        jne  @@kn
        stc
        ret
@@kn:   add  bx,2
        loop @@k
        clc
        ret

; KADD - remember this one as dead. Clobbers AX,BX.
KADD:   mov  bx,cs:[KNEXT]
        mov  ax,[vlane]
        mov  cs:[KLANE+bx],ax
        mov  ax,[vslot]
        mov  cs:[KSLOT+bx],ax
        mov  word ptr cs:[KTIM+bx],KRESP
        add  bx,2
        cmp  bx,NKILL*2
        jb   @@k1
        xor  bx,bx
@@k1:   mov  cs:[KNEXT],bx
        ret

; KTICK - one tick of mourning. Clobbers AX,BX,CX.
KTICK:  xor  bx,bx
        mov  cx,NKILL
@@t:    cmp  word ptr cs:[KTIM+bx],0
        je   @@tn
        dec  word ptr cs:[KTIM+bx]
@@tn:   add  bx,2
        loop @@t
        ret

; ============================================================================
;  CARHITF - did this round hit a vehicle? in: gi,gj (the cell), gbase (the
;  road under it), hitx/hity/hitz (the round). out: CF=1 struck.
;  The same lane arithmetic the renderer uses, asked a different question.
; ============================================================================
CARHITF PROC FAR
        mov  word ptr [vmode],1
        mov  word ptr [vhitf],0
        mov  ax,[gi]
        and  ax,7
        cmp  ax,2
        jge  @@ew
        call NSAVE
        cmp  word ptr [vhitf],0
        jne  @@yes
@@ew:   mov  ax,[gj]
        and  ax,7
        cmp  ax,2
        jge  @@no
        call EWAVE
        cmp  word ptr [vhitf],0
        jne  @@yes
@@no:   mov  word ptr [vmode],0
        clc
        ret
@@yes:  mov  word ptr [vmode],0
        stc
        ret
CARHITF ENDP

; VSIZE - AX = half length along the lane, BX = half width across it
VSIZE:  cmp  word ptr [vaxis],0
        jne  @@ew
        mov  [bhd],ax
        mov  [bhw],bx
        ret
@@ew:   mov  [bhw],ax
        mov  [bhd],bx
        ret

; VSHIFT - AX = how far to move along the lane from the vehicle's centre,
; forward positive. Which world axis that is, and which sign, is vaxis/vdir.
VSHIFT: imul word ptr [vdir]
        cmp  word ptr [vaxis],0
        jne  @@ew
        add  ax,[vcz0]
        mov  [wcz],ax
        ret
@@ew:   add  ax,[vcx0]
        mov  [wcx],ax
        ret

; VHASH - what this slot on this lane is carrying. A third hash, so a
; vehicle's paint is not tied to the shape of the block it is passing.
VHASH:  mov  ax,[vlane]
        mov  bx,2503
        imul bx
        mov  si,ax
        mov  ax,[vslot]
        mov  bx,7919
        imul bx
        add  ax,si
        mov  bx,ax
        mov  cl,6
        shr  bx,cl
        xor  ax,bx
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
CCLOCKF PROC FAR
        mov  ax,[lasttk]
        mov  bx,ax
        sub  bx,[ctick]         ; whole ticks since we last looked
        jz   @@same
        cmp  bx,64              ; a wrap or a very long stall: take one tick
        jbe  @@dt               ; rather than leap a thousand
        mov  bx,1
@@dt:   mov  [ctick],ax
        push bx
        call KTICK              ; the wrecks burn down on the clock too
        pop  bx
        mov  ax,bx
        mov  bx,TKSUB
        imul bx
        sub  ax,[cfrac]         ; minus what interpolation already advanced
        mov  [cstep],ax
        mov  word ptr [cfrac],0
        jmp  @@adv
@@same: mov  ax,[fprev]
        cmp  ax,1
        jge  @@r1
        mov  ax,1
@@r1:   mov  bx,ax
        mov  ax,[fcnt]
        mov  cx,TKSUB
        imul cx
        idiv bx
        cmp  ax,TKSUB-1
        jle  @@f1
        mov  ax,TKSUB-1         ; never run past the tick we are inside
@@f1:   mov  bx,ax
        sub  ax,[cfrac]
        mov  [cstep],ax
        mov  [cfrac],bx
@@adv:  mov  ax,[cstep]
        cmp  ax,0
        jle  @@d
        add  [cartf],ax
@@w:    cmp  word ptr [cartf],CART
        jb   @@d
        sub  word ptr [cartf],CART
        add  word ptr [caradv],8
        jmp  @@w
@@d:    ret
CCLOCKF ENDP

; ---- THE WINDOW GUARD ------------------------------------------------------
IF ($-TOWNBASE) GT 8176
        %OUT *** TOWNSEG overflows its 8K window ***
        .ERR
ENDIF
        ORG  1FF0h              ; claim the whole window, the way SKYSEG does
        db   16 dup(0)

TOWNSEG ENDS
