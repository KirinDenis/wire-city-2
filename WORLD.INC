; WORLD.INC - part of WIRE CITY (included from CITY.ASM)
; DEAD (flat-ground era; replaced by the TERRAIN mesh, no callers) -----------
; ----- ground grid: world-aligned lines around the camera (rotate with view)
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

; ----- buildings: painter's algorithm, far -> near by squared cell distance --
;  Outer loop walks the d^2 bucket from MAXD2 down to 0; inner scan renders the
;  cells whose cdi*cdi+cdj*cdj matches the current bucket. [ring] = bucket.
;  (camgi/camgj are also set in RENDER before GRID; recomputed here too.)
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
        mov  word ptr [ring],MAXD2
@@d2:   mov  word ptr [cdi],-RAD
@@iloop:
        mov  word ptr [cdj],-RAD
@@jloop:
        mov  ax,[cdi]           ; cdi^2 + cdj^2
        imul ax
        mov  bx,ax
        mov  ax,[cdj]
        imul ax
        add  ax,bx
        cmp  ax,[ring]
        jne  @@jnext
        call RENDERCELL         ; this cell is in the current distance bucket
@@jnext:
        mov  ax,[cdj]
        inc  ax
        mov  [cdj],ax
        cmp  ax,RAD
        jle  @@jloop
        mov  ax,[cdi]
        inc  ax
        mov  [cdi],ax
        cmp  ax,RAD
        jle  @@iloop
        dec  word ptr [ring]
        mov  ax,[ring]
        cmp  ax,0
        jge  @@d2
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
        mov  byte ptr [COLOR],17 ; sun-lit roof
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
        je   @@ret              ; plain street cell -> nothing to draw
        ; cell centre world coords:  gi*256 + 128 - BIAS   (shl = *CELL)
        mov  ax,[gi]
        mov  cl,8
        shl  ax,cl
        add  ax,128
        sub  ax,BIAS
        mov  [wcx],ax
        mov  ax,[gj]
        mov  cl,8
        shl  ax,cl
        add  ax,128
        sub  ax,BIAS
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
@@bspire:                       ; slim tall block + antenna spike
        mov  word ptr [bhw],56
        mov  word ptr [bhd],56
        mov  word ptr [boxb],0
        mov  ax,[bhgt2]
        add  ax,60              ; spires read taller than plain boxes
        mov  [boxt],ax
        call DRAWBOX
        mov  word ptr [bhw],14
        mov  word ptr [bhd],14
        mov  ax,[bhgt2]
        add  ax,60
        mov  [boxb],ax
        add  ax,90
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
        add  ax,12
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
        cmp  ax,240
        jle  @@ba1
        mov  ax,240
@@ba1:  mov  [boxt],ax          ; leg height
        mov  word ptr [bhw],34
        mov  word ptr [bhd],80
        mov  word ptr [boxb],0
        mov  ax,[pwcx]
        sub  ax,76
        mov  [wcx],ax
        call DRAWBOX
        mov  ax,[pwcx]
        add  ax,76
        mov  [wcx],ax
        call DRAWBOX
        mov  ax,[pwcx]          ; lintel spans both legs
        mov  [wcx],ax
        mov  word ptr [bhw],110
        mov  bx,[boxt]
        mov  ax,bx
        sub  ax,44
        mov  [boxb],ax
        mov  ax,bx
        add  ax,6
        mov  [boxt],ax
        call DRAWBOX
        jmp  @@ret
@@bfact:                        ; factory: low hall + chimney + smoke loop
        mov  word ptr [boxb],0
        mov  ax,[bhgt2]
        mov  [boxt],ax          ; hall (industrial heights are low)
        call DRAWBOX
        mov  word ptr [bhw],13
        mov  word ptr [bhd],13
        mov  ax,[pwcx]
        add  ax,64
        mov  [wcx],ax
        mov  ax,[pwcz]
        add  ax,40
        mov  [wcz],ax
        mov  word ptr [boxb],0
        mov  word ptr [boxt],180
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
        mov  cl,2
        shr  bx,cl
        add  bx,7               ; puffs grow as they rise: half-size 7..19
        mov  [bhw],bx
        mov  [bhd],bx
        add  ax,180             ; chimney top + age
        mov  [boxb],ax
        add  ax,10
        mov  [boxt],ax
        call PUFFBOX
@@pnx:  inc  word ptr [puffk]
        cmp  word ptr [puffk],3
        jl   @@pf
@@ret:  ret

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
        mov  al,[scol]          ; windows change COLOR - restore per face
        mov  [COLOR],al
        mov  word ptr [fa],3
        mov  word ptr [fb],0
        call FACEV
        call FACESTROKE
        call WINMAYBE
@@e:    mov  ax,[camx]
        cmp  ax,[bwx1]
        jle  @@s
        mov  al,[scol]
        mov  [COLOR],al
        mov  word ptr [fa],1
        mov  word ptr [fb],2
        call FACEV
        call FACESTROKE
        call WINMAYBE
@@s:    mov  ax,[camz]
        cmp  ax,[bwz0]
        jge  @@n
        mov  al,[scol]
        mov  [COLOR],al
        mov  word ptr [fa],0
        mov  word ptr [fb],1
        call FACEV
        call FACESTROKE
        call WINMAYBE
@@n:    mov  ax,[camz]
        cmp  ax,[bwz1]
        jle  @@d
        mov  al,[scol]
        mov  [COLOR],al
        mov  word ptr [fa],2
        mov  word ptr [fb],3
        call FACEV
        call FACESTROKE
        call WINMAYBE
@@d:    ret

; windows only on near faces
WINMAYBE:
        mov  ax,[minrz]
        cmp  ax,1200
        jg   @@x
        cmp  word ptr [bhw],50  ; no windows on spikes/chimneys/lintels
        jl   @@x
        mov  ax,[boxt]
        sub  ax,[boxb]
        cmp  ax,60              ; nor on flat slabs
        jl   @@x
        call WINFACE
@@x:    ret
