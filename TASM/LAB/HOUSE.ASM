; ============================================================================
;  HOUSE.COM - THE HOUSE LAB.  A test bed, not a game.
;
;  One block of the city, standing still, with a camera you can walk round
;  it. No flight model, no physics, no combat, no panel, no sound. The
;  point is to be able to look at a building for as long as it takes.
;
;  WHY THIS IS A SEPARATE PROGRAM
;   - the game's main 64K segment has about fifty bytes left in it;
;   - and you cannot judge how something LOOKS from a cockpit that never
;     stops moving. The game computes its buildings from a cell hash every
;     frame - there is no building list to edit - so every experiment
;     inside the game costs a full sortie to see once.
;
;  WHAT IS THE SAME AS THE GAME, ON PURPOSE
;   Everything that decides how a building looks: CELLHASH and SBHASH, the
;   footprint / height / colour-scheme bit-fields, the five structure types
;   (box, spire, telescoping tower, arch, factory + smoke), DRAWBOX,
;   ROTCUL, FACEV, FACETOPC, WINFACE, WLIT2, the PALDAY colours, the
;   FOCAL 220 lens, the 256-unit cell. The block drawn here is the game's
;   OWN cells 24..39 - the same hashes, so the same houses, down to which
;   windows are lit. Change a number here and it means the same thing
;   there.
;
;  WHAT IS DIFFERENT, AND WHY
;   - the ground is flat at y=0 (no terrain mesh): a lab wants a scene it
;     can hold still, and gbase is kept as a variable so the code that
;     goes back into the game is unchanged;
;   - the superblock "is this block built up at all" test is dropped, so
;     the block is dense - in the game only ~3/16 of blocks are built and
;     you would spend the session hunting for a house;
;   - no ruins, no zoning: every cell here is city.
;
;  KEYS: arrows fly (up/down forward+back, left/right turn), A/Z climb
;  and descend, S/X look up and down, , and . slide sideways, Shift is
;  fast, W toggles the windows, E toggles the outlines, ESC quits.
;
;  Build: LAB\BUILD.BAT inside DOSBox, or MAKE LAB from Windows.
; ============================================================================
FOCAL   equ 220                 ; the game's lens
NEARZ   equ 40                  ; near clip plane
FARZ    equ 21600               ; far clip distance
BIAS    equ 8192                ; world->cell bias (the game's convention)
RAD     equ 16                  ; painter walk radius, in cells. It has to
NORD    equ (2*RAD+1)*(2*RAD+1) ; reach ACROSS the block from outside it,
MAXD2   equ RAD*RAD*2           ; or you stand off and see one row of houses
                                ; with the rest of the city missing (which
                                ; is exactly what RAD 8 did, 2026-08-03).
NCOL    equ 4                   ; panes across a wall...
NROW    equ 8                   ; ...and down it. Both went up when a
                                ; building grew to own a 2x2 plot: 3x5 on a
                                ; wall twice the size is not windows, it is
                                ; garage doors.
NSTR    equ 8                   ; lattice row stride - a POWER OF TWO, kept
                                ; separate from NCOL+1 so the index stays a
                                ; shift. NCOL may be anything under it.
NLAT    equ NSTR*(NROW+1)       ; the corner lattice the panes share
WMINPX  equ 6                   ; a wall thinner than this carries no glass
WQUADPX equ 5                   ; ...and below this many pixels per CELL the
                                ; whole facade drops to lit dots
DGRAIN  equ 3                   ; the stipple a wall wears everywhere: just
                                ; enough to stop it being one flat index
DSHADE  equ 9                   ; ...and where down the wall (of 16) the real
                                ; darkening starts. Above this, grain only.
; ---- traffic. CARV*CARG = 2048 = eight cells = ONE BLOCK per green, and
; that identity is what the whole scheme rests on (see TRAFFIC).
TKSUB   equ 12                  ; traffic-clock steps per BIOS tick (18.2 Hz)
CARV    equ 1                   ; units per clock step while moving
CARG    equ 2048                ; clock steps of green
CARCLR  equ 256                 ; all-red clearance between the two greens
CART    equ 2*(CARG+CARCLR)     ; the whole signal cycle (~21 s)
CARRST  equ 200                 ; how far into its cell a stopped vehicle
                                ; waits - just short of the next crossing
LANEOF  equ 96                  ; lane centre from the avenue centre
VCOL0   equ 126                 ; first vehicle colour (8 lit/shade pairs)
NPALLAB equ 22                  ; the lab's own DAC entries, from 120 up
                                ; (an immediate, so it must be declared here:
                                ;  TASM reads this file once, top to bottom)
BLK0    equ 24                  ; the lab block: cells BLK0..BLK1 both axes.
BLK1    equ 35                  ; 12x12 straddles the superblock boundary at
                                ; 32, so the block carries more than one
                                ; district - residential, downtown, industry
                                ; side by side to compare.

SC_ESC  equ 01h
SC_UP   equ 48h
SC_DN   equ 50h
SC_LF   equ 4Bh
SC_RT   equ 4Dh
SC_A    equ 1Eh                 ; climb
SC_Z    equ 2Ch                 ; descend
SC_S    equ 1Fh                 ; look up
SC_X    equ 2Dh                 ; look down
SC_CMA  equ 33h                 ; slide left
SC_PER  equ 34h                 ; slide right
SC_W    equ 11h                 ; windows on/off
SC_E    equ 12h                 ; outlines on/off
SC_T    equ 14h                 ; wall shading on/off
SC_C    equ 2Eh                 ; traffic on/off
SC_LSH  equ 2Ah
SC_RSH  equ 36h

        .8086
        LOCALS
        JUMPS
CODE    SEGMENT
        ASSUME cs:CODE, ds:CODE, es:CODE, ss:CODE
        ORG  100h

; ============================================================================
;  START
; ============================================================================
START:  cld
        mov  ax,cs              ; back buffer: the 64K above the program
        add  ax,1000h
        mov  [bufseg],ax
        mov  dx,offset HELP     ; the key card, in text mode, before we go
        mov  ah,9
        int  21h
        xor  ah,ah
        int  16h
        call BUILDORD           ; the painter's far->near cell order
        mov  ax,0013h           ; VGA 320x200, 256 colours
        int  10h
        call SETPAL
        mov  ax,3509h           ; take the keyboard: a camera wants key
        int  21h                ; STATE, not the typematic repeat
        mov  [oldk9],bx
        mov  [oldk9+2],es
        push ds
        mov  dx,offset KBINT
        mov  ax,cs
        mov  ds,ax
        mov  ax,2509h
        int  21h
        pop  ds

; ---- one frame -------------------------------------------------------------
@@frame:
        push es
        mov  ax,40h             ; the BIOS tick drives the chimney smoke
        mov  es,ax
        mov  ax,es:[6Ch]
        pop  es
        mov  [labtk],ax
        call CCLOCK
        call MOVECAM
        cmp  byte ptr [HITS+SC_ESC],0   ; the event, not the held state:
        jne  @@quit                     ; a tap must never be missed
        call SETTRIG            ; heading/pitch -> trig, horizon offset
        mov  ax,[bufseg]
        mov  es,ax
        call CLEARSKY
        call CAMCELL
        call GROUNDPASS         ; streets and plots first, as one flat layer
        call BLDPASS            ; then the houses, far -> near
        call STATUS
        call WAITVR
        call BLIT
        jmp  @@frame

@@quit: push ds                 ; hand the keyboard back before leaving
        mov  dx,[oldk9]
        mov  ax,[oldk9+2]
        mov  ds,ax
        mov  ax,2509h
        int  21h
        pop  ds
        mov  ax,0003h
        int  10h
        mov  ax,4C00h
        int  21h

; ============================================================================
;  BUILDORD - the painter's order, built once at startup.
;  The game ships this table pre-sorted (BORD) because it cannot spare the
;  code; here it is worth the twenty lines to see how it is made. Cells are
;  emitted in falling order of squared distance di*di+dj*dj, so walking the
;  table draws far before near. Translation does not change relative order,
;  so ONE table serves every camera position - the world costs no sort per
;  frame. A counting pass, not a sort: for each key from MAXD2 down to 0,
;  emit every cell that has it. That is MAXD2 sweeps of the whole square,
;  so the squares get tabulated first and the inner loop never multiplies.
; ============================================================================
BUILDORD:
        mov  word ptr [odi],-RAD ; SQD[di+RAD] = di*di, once
@@sq:   mov  ax,[odi]
        imul word ptr [odi]
        mov  si,[odi]
        add  si,RAD
        add  si,si
        mov  [SQD+si],ax
        inc  word ptr [odi]
        cmp  word ptr [odi],RAD
        jle  @@sq
        mov  word ptr [ordn],0
        mov  word ptr [okey],MAXD2
@@k:    mov  word ptr [odi],-RAD
@@i:    mov  si,[odi]
        add  si,RAD
        add  si,si
        mov  ax,[SQD+si]
        mov  [disq],ax
        mov  word ptr [odj],-RAD
@@j:    mov  si,[odj]
        add  si,RAD
        add  si,si
        mov  ax,[SQD+si]
        add  ax,[disq]
        cmp  ax,[okey]
        jne  @@nx
        mov  si,[ordn]
        add  si,si
        mov  al,byte ptr [odi]
        mov  [ORDT+si],al
        mov  al,byte ptr [odj]
        mov  [ORDT+si+1],al
        inc  word ptr [ordn]
@@nx:   inc  word ptr [odj]
        cmp  word ptr [odj],RAD
        jle  @@j
        inc  word ptr [odi]
        cmp  word ptr [odi],RAD
        jle  @@i
        dec  word ptr [okey]
        jns  @@k
        ret

; ============================================================================
;  MOVECAM - the free camera. Reads the key STATE table, so movement is
;  smooth and diagonals work; nothing here is a flight model on purpose.
;  Forward is horizontal (the view direction with the pitch taken out) and
;  altitude is its own pair of keys - that is what makes a camera easy to
;  park where you want it, and an aeroplane hard.
; ============================================================================
MOVECAM:
        mov  word ptr [mstep],10
        mov  word ptr [mturn],1
        cmp  byte ptr [KEYS+SC_LSH],0
        jne  @@fast
        cmp  byte ptr [KEYS+SC_RSH],0
        je   @@nf
@@fast: mov  word ptr [mstep],34
        mov  word ptr [mturn],3
@@nf:   cmp  byte ptr [KEYS+SC_LF],0
        je   @@nl
        mov  ax,[heading]
        sub  ax,[mturn]
        and  ax,255
        mov  [heading],ax
@@nl:   cmp  byte ptr [KEYS+SC_RT],0
        je   @@nr
        mov  ax,[heading]
        add  ax,[mturn]
        and  ax,255
        mov  [heading],ax
@@nr:   ; forward vector = (hsin,hcos)/256, from LAST frame's trig - one
        ; frame of lag on a lab camera is not worth a second SETTRIG
        cmp  byte ptr [KEYS+SC_UP],0
        je   @@nu
        mov  ax,[hsin]
        imul word ptr [mstep]
        mov  bx,256
        idiv bx
        add  [camx],ax
        mov  ax,[hcos]
        imul word ptr [mstep]
        mov  bx,256
        idiv bx
        add  [camz],ax
@@nu:   cmp  byte ptr [KEYS+SC_DN],0
        je   @@nd
        mov  ax,[hsin]
        imul word ptr [mstep]
        mov  bx,256
        idiv bx
        sub  [camx],ax
        mov  ax,[hcos]
        imul word ptr [mstep]
        mov  bx,256
        idiv bx
        sub  [camz],ax
@@nd:   ; right vector = forward turned 90 deg = (hcos,-hsin)/256
        cmp  byte ptr [KEYS+SC_PER],0
        je   @@ns1
        mov  ax,[hcos]
        imul word ptr [mstep]
        mov  bx,256
        idiv bx
        add  [camx],ax
        mov  ax,[hsin]
        imul word ptr [mstep]
        mov  bx,256
        idiv bx
        sub  [camz],ax
@@ns1:  cmp  byte ptr [KEYS+SC_CMA],0
        je   @@ns2
        mov  ax,[hcos]
        imul word ptr [mstep]
        mov  bx,256
        idiv bx
        sub  [camx],ax
        mov  ax,[hsin]
        imul word ptr [mstep]
        mov  bx,256
        idiv bx
        add  [camz],ax
@@ns2:  cmp  byte ptr [KEYS+SC_A],0
        je   @@nc1
        mov  ax,[mstep]
        add  [camy],ax
@@nc1:  cmp  byte ptr [KEYS+SC_Z],0
        je   @@nc2
        mov  ax,[mstep]
        sub  [camy],ax
@@nc2:  cmp  byte ptr [KEYS+SC_S],0
        je   @@np1
        inc  word ptr [pitch]
@@np1:  cmp  byte ptr [KEYS+SC_X],0
        je   @@np2
        dec  word ptr [pitch]
@@np2:  ; ---- fences. The lab is a room, not a world: keep the camera in
        ; it, and keep the coordinates far from the 16-bit edge where the
        ; game's own world wraps.
        mov  ax,[pitch]
        cmp  ax,48
        jle  @@f1
        mov  word ptr [pitch],48
@@f1:   cmp  ax,-48
        jge  @@f2
        mov  word ptr [pitch],-48
@@f2:   mov  ax,[camy]
        cmp  ax,12
        jge  @@f3
        mov  word ptr [camy],12
@@f3:   cmp  ax,3000
        jle  @@f4
        mov  word ptr [camy],3000
@@f4:   mov  ax,[camx]
        call FENCE
        mov  [camx],ax
        mov  ax,[camz]
        call FENCE
        mov  [camz],ax
        ; ---- the two lab switches ----
        mov  bl,SC_W
        mov  si,offset winon
        call TOGGLE
        mov  bl,SC_E
        mov  si,offset edgeon
        call TOGGLE
        mov  bl,SC_T
        mov  si,offset texon
        call TOGGLE
        mov  bl,SC_C
        mov  si,offset caron
        call TOGGLE
        ret

FENCE:  cmp  ax,6000            ; keep the camera inside the lab's room
        jle  @@n1
        mov  ax,6000
@@n1:   cmp  ax,-6000
        jge  @@n2
        mov  ax,-6000
@@n2:   ret

; TOGGLE - BL=scancode, SI=the flag. Flips it once per press and takes the
; press from HITS, not KEYS: a switch is an EVENT. Polling KEYS once a frame
; misses any tap shorter than a frame - which a real finger never is, but an
; automated one always is (the screenshot rig, 2026-08-03) - and a held key
; would flip the switch at the frame rate. HITS is set by the interrupt and
; cleared here, so no press is ever lost and none is ever counted twice.
TOGGLE: xor  bh,bh              ; BL is the scancode, BH must not be junk
        cmp  byte ptr [HITS+bx],0
        je   @@d
        mov  byte ptr [HITS+bx],0
        xor  byte ptr [si],1
@@d:    ret

; ============================================================================
;  CLEARSKY - the backdrop. The lab camera does not roll, so the horizon is
;  a straight line at horiz+pofs and the sky is three flat bands above it:
;  deep blue, a lighter band, then the haze the buildings fade into. The
;  game's dithered five-step sky lives in its own segment and is not what a
;  house is judged against.  ES = bufseg.
; ============================================================================
CLEARSKY:
        mov  ax,[horiz]
        add  ax,[pofs]
        mov  [hcur],ax
        xor  di,di
        mov  word ptr [crow],0
@@r:    mov  ax,[hcur]
        sub  ax,[crow]          ; rows above the horizon line
        jg   @@sky
        mov  al,10              ; ground
        jmp  @@fill
@@sky:  cmp  ax,20
        jg   @@s2
        mov  al,12              ; haze, hard against the horizon
        jmp  @@fill
@@s2:   cmp  ax,60
        jg   @@s3
        mov  al,9               ; the band above it
        jmp  @@fill
@@s3:   mov  al,7               ; zenith
@@fill: mov  ah,al
        mov  cx,160
        rep  stosw
        inc  word ptr [crow]
        cmp  word ptr [crow],200
        jb   @@r
        ret

; ============================================================================
;  CAMCELL - which cell the camera stands in (the same shr-8 as the game)
; ============================================================================
CAMCELL:
        mov  ax,[camx]
        add  ax,BIAS
        mov  cl,8
        shr  ax,cl
        mov  [camgi],ax
        mov  ax,[camz]
        add  ax,BIAS
        mov  cl,8
        shr  ax,cl
        mov  [camgj],ax
        ret

; ============================================================================
;  CELLSET - gi,gj from the walk entry [ordi]; CF=1 if outside the block.
;  Also lays down the cell's world centre in wcx,wcz.
; ============================================================================
CELLSET:
        mov  si,[ordi]
        add  si,si
        mov  al,[ORDT+si]
        cbw
        mov  bx,[camgi]
        add  bx,ax
        mov  [gi],bx
        mov  al,[ORDT+si+1]
        cbw
        mov  bx,[camgj]
        add  bx,ax
        mov  [gj],bx
        mov  ax,[gi]
        cmp  ax,BLK0
        jl   @@out
        cmp  ax,BLK1
        jg   @@out
        mov  ax,[gj]
        cmp  ax,BLK0
        jl   @@out
        cmp  ax,BLK1
        jg   @@out
        mov  ax,[gi]            ; centre = gi*256 + 128 - BIAS
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
        clc
        ret
@@out:  stc
        ret

; PAIRC - shift the centre to the middle of the 2x2 plot. Buildings own the
; pair; the flat patches are still one cell each and keep the cell centre.
; (It goes AFTER CELLSET's last label, not inside it: a non-local label
;  closes the @@ scope, and @@out went undefined the first time.)
PAIRC:  add  word ptr [wcx],128
        add  word ptr [wcz],128
        ret

; ============================================================================
;  GROUNDPASS - one flat quad per cell: asphalt on the avenues, pavement on
;  the plots. A whole layer of its own, drawn before any house, exactly as
;  the game draws its terrain mesh before its buildings: mixed into the
;  same walk, a near cell's ground would paint over a far building's feet.
; ============================================================================
GROUNDPASS:
        mov  word ptr [ordi],0
@@l:    call CELLSET
        jc   @@nx
        mov  word ptr [bhw],128 ; the full cell, edge to edge
        mov  word ptr [bhd],128
        call ROTCUL
        jc   @@nx
        xor  ax,ax              ; the lab's ground is flat at y=0
        sub  ax,[camy]
        mov  [bry1],ax
        mov  byte ptr [COLOR],121
        call ISROAD             ; the SAME test LHBLD uses, or the asphalt
        jnc  @@put              ; and the houses disagree about the plan
        mov  byte ptr [COLOR],120
@@put:  call FACETOPC
        call FACEFILL
@@nx:   inc  word ptr [ordi]
        mov  ax,[ordn]
        cmp  [ordi],ax
        jb   @@l
        ret

; ============================================================================
;  BLDPASS - the houses, far -> near, one linear walk of the order table
; ============================================================================
BLDPASS:
        mov  word ptr [ordi],0
@@l:    call CELLSET
        jc   @@nx
        call RENDERCELL
@@nx:   inc  word ptr [ordi]
        mov  ax,[ordn]
        cmp  [ordi],ax
        jb   @@l
        ret

; ============================================================================
;  RENDERCELL - one cell's structure. The game's routine with the terrain
;  and the ruins taken out; wcx,wcz are already set by CELLSET.
; ============================================================================
RENDERCELL:
        call LHBLD
        mov  ax,[bstreet]
        cmp  ax,1
        jne  @@built
        call TRAFFIC            ; a road cell: whatever is driving on it
        jmp  @@ret
@@built:
        mov  byte ptr [roofc],17
        cmp  ax,0
        jne  @@nopair
        call PAIRC              ; a building owns the 2x2 plot; the flat
@@nopair:                       ; patches are still one cell each
        call ROTCUL             ; bounds -> rotate corners -> cull
        jc   @@ret
        mov  word ptr [gbase],0 ; flat ground. In the game this is the
                                ; terrain height under the cell.
        mov  ax,[bstreet]
        cmp  ax,2
        jne  @@solid
        mov  ax,[gbase]         ; a flat patch: forest / water / field
        add  ax,2               ; a hair above the ground (paint order)
        sub  ax,[camy]
        mov  [bry1],ax
        mov  al,[bcol]
        mov  [COLOR],al
        call FACETOPC
        call FACEFILL
        jmp  @@ret
@@solid:
        mov  bx,[bschm]         ; wall colours from the building's scheme
        add  bx,bx
        mov  al,[WSCH+bx]
        mov  [wallL],al
        mov  al,[WSCH+bx+1]
        mov  [wallS],al
        mov  bx,[bschm]         ; the third rung, the lab's own
        mov  al,[WDRK+bx]
        mov  [wallD],al
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
        mov  word ptr [bhw],112
        mov  word ptr [bhd],112
        mov  word ptr [boxb],0
        mov  ax,[bhgt2]
        add  ax,120
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
        cmp  ax,480
        jle  @@ba1
        mov  ax,480
@@ba1:  mov  [boxt],ax
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
        mov  ax,[pwcx]
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
        mov  [boxt],ax
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
        mov  word ptr [puffk],0
@@pf:   mov  si,[puffk]
        add  si,si
        mov  ax,[labtk]
        add  ax,ax              ; climb 2 units per tick
        add  ax,[PUFO+si]
        and  ax,63              ; age 0..63
        cmp  ax,50
        ja   @@pnx              ; old puff has dissolved
        mov  bx,ax
        mov  cl,1
        shr  bx,cl
        add  bx,14              ; puffs grow as they rise
        mov  [bhw],bx
        mov  [bhd],bx
        add  ax,360            ; chimney top + age
        mov  [boxb],ax
        add  ax,20
        mov  [boxt],ax
        call PUFFBOX
@@pnx:  inc  word ptr [puffk]
        cmp  word ptr [puffk],3
        jl   @@pf
@@ret:  ret

; ============================================================================
;  LHBLD - the lab's building descriptor for cell [gi],[gj].
;  The game's HBLD with two things removed: the terrain zoning (there is no
;  terrain here) and the superblock "is this block built up" test (only
;  ~3/16 of blocks are, and a lab wants houses in front of it, not a field
;  to search). EVERY number that decides how the building LOOKS is the
;  game's, and so is the hash - these are the game's own cells.
; ============================================================================
LHBLD:  call ISROAD
        jc   @@st
        ; ---- ONE BUILDING TO EVERY 2x2 CELLS. A 256-unit plot beside a
        ; 512-unit avenue is what made the city look microscopic: the road
        ; was twice the width of the thing it served. Widening the building
        ; inside its own cell cannot fix that - at half-width 230 it would
        ; already be standing in the near traffic lane. So the building
        ; takes the pair and the other three cells are its garden.
        mov  ax,[gi]
        or   ax,[gj]
        test ax,1
        jnz  @@st
        call CELLHASH
        mov  bx,ax
        and  bx,31              ; hash 7/8/9 of 32 -> flat terrain patches
        cmp  bx,7
        je   @@forest
        cmp  bx,8
        je   @@water
        cmp  bx,9
        je   @@field
        ; ---- the district: the BLOCK sets the flavour, the CELL gets a
        ; say. A pure district is the thing that makes a procedural city
        ; look drawn by a zoning computer: eighty identical sheds, then
        ; eighty identical houses. Three cells in eight take a neighbour's
        ; district instead, so a machine shop stands behind the houses and
        ; a shed leans on a tower - and the block still reads as what it
        ; mostly is.
        push ax                 ; the cell hash is wanted after this
        call SBHASH
        mov  [sbh],ax
        mov  cl,4
        shr  ax,cl
        and  ax,3               ; 0/3 residential, 1 downtown, 2 industry
        mov  [bdist],ax
        call DHASH              ; the cell's own opinion
        mov  bx,ax
        and  bx,7
        cmp  bx,5
        jb   @@dok
        mov  bx,ax
        mov  cl,3
        shr  bx,cl
        and  bx,3
        inc  bx                 ; +1..4, so never its own district again
        add  bx,[bdist]
        and  bx,3
        mov  [bdist],bx
@@dok:  pop  ax
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
        mov  bx,ax              ; wall scheme 0..3 (grey/blue/red/white)
        mov  cl,13
        shr  bx,cl
        and  bx,3
        mov  [bschm],bx
        mov  bx,ax              ; building selector 0..7
        mov  cl,10
        shr  bx,cl
        and  bx,7
        mov  si,[bdist]
        cmp  si,1
        je   @@com
        cmp  si,2
        je   @@ind
        mov  word ptr [btype],0 ; --- residential: low boxes, a tower now
        cmp  bx,6               ;     and then
        jb   @@rh
        mov  word ptr [btype],2
@@rh:   mov  bx,ax
        and  bx,63
        add  bx,bx              ; height 120..246 - twice the old, or the
        add  bx,120             ; doubled footprint reads as a paving slab
        mov  [bhgt2],bx
        jmp  @@bdone
@@com:  mov  word ptr [btype],0 ; --- downtown: a tall mixed skyline
        cmp  bx,3
        jb   @@ch
        cmp  bx,5
        jb   @@ctw
        cmp  bx,7
        jb   @@csp
        mov  word ptr [btype],3 ; 7 arch
        jmp  @@ch
@@ctw:  mov  word ptr [btype],2
        jmp  @@ch
@@csp:  mov  word ptr [btype],1
@@ch:   push ax                 ; towers cluster toward the block centre
        mov  bx,[gi]
        and  bx,7
        sub  bx,4
        jns  @@a1
        neg  bx
@@a1:   mov  si,bx
        mov  bx,[gj]
        and  bx,7
        sub  bx,4
        jns  @@a2
        neg  bx
@@a2:   add  si,bx              ; manhattan dist to the centre, 0..8
        mov  ax,8
        sub  ax,si
        mov  bx,60              ; the plot doubled, so the skyline follows -
        imul bx                 ; downtown bonus 0..480
        mov  si,ax
        pop  ax
        mov  bx,ax
        and  bx,63
        add  bx,bx
        add  bx,100
        add  bx,si              ; height 100..706
        mov  [bhgt2],bx
        jmp  @@bdone
@@ind:  mov  word ptr [bschm],0 ; --- industry: smoking factories, always grey
        mov  word ptr [btype],4
        cmp  bx,5
        jb   @@ih
        mov  word ptr [btype],0 ; 5..7 plain shed
@@ih:   mov  bx,ax
        and  bx,31
        add  bx,bx
        add  bx,100             ; low industry: 100..162
        mov  [bhgt2],bx
@@bdone:
        mov  word ptr [bstreet],0
        ret
@@st:   mov  word ptr [bstreet],1
        ret
@@forest:
        mov  byte ptr [bcol],15
        jmp  @@patch
@@water:
        mov  byte ptr [bcol],14
        jmp  @@patch
@@field:
        mov  byte ptr [bcol],11
@@patch:
        mov  word ptr [bhw],116
        mov  word ptr [bhd],116
        mov  word ptr [bstreet],2
        ret

; ============================================================================
;  TRAFFIC - the vehicles standing on, or driving through, one road cell.
;
;  THERE IS NO LIST OF VEHICLES, exactly as there is no list of buildings.
;  A vehicle's position is a function of (lane, slot, time) and nothing is
;  stored: the same argument that lets the world ship as a recipe lets the
;  traffic ship as one too. Two clients of the same sky compute identical
;  traffic from the tick with no network traffic at all.
;
;  THE LANE, NOT THE CELL, CARRIES THE PHASE. Hash the phase per cell and a
;  vehicle jumps sideways every time it crosses a cell boundary. So: slots
;  are spaced one cell apart ALONG A LANE and numbered globally, and a cell
;  works out which slot happens to be inside it right now. A vehicle stays
;  the same vehicle - same size, same paint - all the way down the street.
;
;  THE RULES, and they are the interesting part:
;
;  * Right-hand traffic falls out of the geometry. An avenue is two cells
;    (512 units) wide; the two lanes sit at +-LANEOF from its centre, and
;    which lane goes which way is fixed so that a driver's right hand is
;    always toward the kerb.
;
;  * The lights are a function of time, so they need no state either. The
;    north-south avenues take the first green, the east-west ones the
;    second, with an all-red clearance between. A whole lane starts and
;    stops together - which is what a signalled platoon actually looks
;    like - so one closed form serves every vehicle on it.
;
;  * A green is worth EXACTLY ONE BLOCK: CARV*CARG = 2048 = 8 cells. That
;    identity is the trick the rest hangs on. Because a slot advances a
;    whole number of blocks per cycle, and a block is 8 cells, THE CELL A
;    SLOT RESTS IN NEVER CHANGES MODULO 8. So "does this slot stop on a
;    crossing?" is answered once, by s AND 7, and forever. Ban those two
;    slots in eight and the junction box is clear at every red, for free,
;    with no vehicle ever having to look at another one.
;
;  Stopped vehicles wait at CARRST into their cell - just short of the
;  stop line - so a red leaves a proper queue behind it rather than a row
;  of cars parked on cell boundaries.
; ============================================================================
TRAFFIC:
        cmp  byte ptr [caron],0
        je   @@d
        mov  word ptr [gbase],0 ; the lab's road is flat. In the game this
                                ; is GETH under the cell, like a building.
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
;  CCLOCK - the traffic clock: the BIOS tick, interpolated by counting
;  frames inside it. The game already does this for the camera, and traffic
;  needs it for TWO separate reasons:
;
;   - moving on the raw 18.2 Hz tick judders, because the world around it
;     is being redrawn three or four times as often;
;   - moving per FRAME makes the signal cycle a measurement of the
;     renderer. That is not a hypothetical: at first pass the lights ran on
;     frames, the scene got heavy enough to drop to a dozen frames a
;     second, and a twenty-second cycle quietly became a minute and a half.
;     The cross street never went green in half a minute of watching.
;
;  So: ctick/cfrm measure how many frames the last tick lasted, and cstep
;  hands the difference to cartf. Time comes from the clock; smoothness
;  comes from the frame rate; neither borrows from the other.
; ============================================================================
CCLOCK: mov  ax,[labtk]
        cmp  ax,[ctick]
        je   @@same
        mov  [ctick],ax
        mov  ax,[cfrm]          ; how many frames that tick lasted
        cmp  ax,1
        jge  @@r1
        mov  ax,1
@@r1:   cmp  ax,60
        jle  @@r2
        mov  ax,60
@@r2:   mov  [crate],ax
        mov  word ptr [cfrm],0
        mov  ax,TKSUB           ; close the tick out exactly, whatever the
        sub  ax,[cfrac]         ; interpolation had guessed
        mov  [cstep],ax
        mov  word ptr [cfrac],0
        jmp  @@adv
@@same: inc  word ptr [cfrm]
        mov  ax,[cfrm]
        mov  bx,TKSUB
        imul bx
        idiv word ptr [crate]
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

; ============================================================================
;  CARTIME - where this lane's platoon has got to.
;   in:  vstart - the frame in the cycle when this lane's green begins
;   out: voff - how far into its cell a vehicle is (0..255)
;        vadv - how many cells the platoon has advanced, all time
;  d = CARV * clamp(frame - start, 0, CARG) + CARRST, plus the whole blocks
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
        jl   @@no               ; this slot comes to rest ON a crossing.
                                ; It simply does not exist - which is how
                                ; the junction stays clear at every red
                                ; without one vehicle ever looking at
                                ; another.
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
        mov  ax,[wcx]           ; a two-box vehicle moves its own centre
        mov  [vcx0],ax
        mov  ax,[wcz]
        mov  [vcz0],ax
        mov  ax,[vtype]
        cmp  ax,5
        je   @@bus
        cmp  ax,6
        jge  @@truck
        ; ---- a car: a low body with a cabin sat on it ---------------------
        mov  ax,31
        mov  bx,13
        call VSIZE
        mov  word ptr [boxb],0
        mov  word ptr [boxt],14
        call DRAWBOX
        mov  ax,15
        mov  bx,12
        call VSIZE
        mov  word ptr [boxb],14
        mov  word ptr [boxt],26
        call DRAWBOX
        ret
@@bus:  ; ---- a bus IS a box, and there is no shame in that ----------------
        mov  ax,82
        mov  bx,18
        call VSIZE
        mov  word ptr [boxb],0
        mov  word ptr [boxt],46
        call DRAWBOX
        ret
@@truck:; ---- a truck: a tall cab in front, a longer body behind it --------
        mov  ax,16
        mov  bx,17
        call VSIZE
        mov  word ptr [boxb],0
        mov  word ptr [boxt],42
        mov  ax,40
        call VSHIFT
        call DRAWBOX
        mov  ax,40
        mov  bx,18
        call VSIZE
        mov  word ptr [boxb],6
        mov  word ptr [boxt],46
        mov  ax,-22
        call VSHIFT
        call DRAWBOX
@@no:   ret

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

; VHASH - what this slot on this lane is carrying. A third hash, so that a
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
;  ISROAD - is cell [gi],[gj] road rather than a plot?  CF=1 = road.
;  TWO cells in every eight, so an avenue is 512 units across - twice the
;  old one. The built fraction is untouched: (6/8) squared is exactly what
;  (3/4) squared gave. Wider streets and blocks twice the size, the same
;  amount of city. Streets are what a city is SEEN through; at one cell the
;  buildings on the far side stood right on top of the ones in front.
;  The 8-cell period also lines up with the downtown height bonus, which
;  already measures its distance from the block centre with gi&7.
;  Clobbers AX.  (Game divergence: HBLD still tests gi&3 - see README.)
; ============================================================================
ISROAD: mov  ax,[gi]
        and  ax,7
        cmp  ax,2
        jl   @@yes
        mov  ax,[gj]
        and  ax,7
        cmp  ax,2
        jl   @@yes
        clc
        ret
@@yes:  stc
        ret

; DHASH - a SECOND, independent hash of the cell. The first one's bits are
; all spoken for (width, depth, selector, scheme), and reusing them would
; tie a cell's district to its shape - tall buildings would always be the
; ones that changed district, and the eye finds that sort of thing.
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

; SBHASH / CELLHASH - the game's, character for character. These are what
; make the lab's houses the game's houses.
SBHASH: mov  ax,[gi]
        mov  cl,3
        shr  ax,cl
        and  ax,31
        mov  si,ax
        mov  ax,[gj]
        mov  cl,3
        shr  ax,cl
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
        ret

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
;  DRAWBOX - one solid box standing on the ground. The game's routine.
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
        cmp  byte ptr [texon],0
        je   @@rflat
        mov  byte ptr [dcolA],17 ; a roof is horizontal: no gradient to run
        mov  byte ptr [dcolB],0  ; down it, just gravel. 17 against 0 rather
        mov  byte ptr [dgrad],0  ; than against 16 - the closer pair, or the
        mov  word ptr [dmixc],6  ; stipple reads as dirt instead of texture
        call DITHFILL
        jmp  @@nf
@@rflat:
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
        mov  [scol],al
        mov  ax,[gbase]
        add  ax,[boxt]
        cmp  [camy],ax
        jle  @@ns
        cmp  byte ptr [edgeon],0
        je   @@ns
        call FACETOPC
        call FACESTROKE
@@ns:   call VISSTROKE
@@r:    ret

; ============================================================================
;  PUFFBOX - one soft smoke cube: haze colour, no outline, no windows
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
        mov  byte ptr [COLOR],12
        mov  ax,[gbase]
        add  ax,[boxt]
        cmp  [camy],ax
        jle  @@nf
        call FACETOPC
        call FACEFILL
@@nf:   call MEGAFILL
@@r:    ret

; ============================================================================
;  ROTCUL - world bounds from (wcx,wcz,bhw,bhd), rotate the 4 footprint
;  corners into camera space (FRX/FRZ), track min/max rz, and cull.
;  out: CF=1 -> the box is entirely behind or beyond; skip it.
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
        mov  ax,[maxrz]
        cmp  ax,NEARZ
        jl   @@rej              ; entirely behind
        mov  ax,[minrz]
        cmp  ax,FARZ
        jg   @@rej              ; entirely too far
        clc
        ret
@@rej:  stc
        ret
@@trk:  mov  ax,[rcz]
        cmp  ax,[minrz]
        jge  @@t1
        mov  [minrz],ax
@@t1:   cmp  ax,[maxrz]
        jle  @@t2
        mov  [maxrz],ax
@@t2:   ret

; ============================================================================
;  FACEV / FACETOPC - build a face quad in camera space from the footprint
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
;  VISFILL / MEGAFILL / VISSTROKE - which of the four walls face the camera.
;  Chosen in WORLD space (camx/camz against the footprint), so the answer
;  does not depend on where the camera is looking - only on where it is.
; ============================================================================
;  Each wall is shaded down its own height between two rungs of its
;  scheme's three-colour ramp - and WHICH two rungs is what keeps the sun
;  in the picture. The sunny walls run light->mid, the shaded walls run
;  mid->dark, so the two sides stay a clear step apart while both of them
;  stop being one flat colour. Nine effective steps out of three indices.
VISFILL:
        mov  ax,[camx]          ; west (camx < bwx0): corners 3,0
        cmp  ax,[bwx0]
        jge  @@e
        call SHADEDS
        mov  word ptr [fa],3
        mov  word ptr [fb],0
        call FACEV
        call WALLFILL
@@e:    mov  ax,[camx]          ; east (camx > bwx1): 1,2
        cmp  ax,[bwx1]
        jle  @@s
        call SHADEDS
        mov  word ptr [fa],1
        mov  word ptr [fb],2
        call FACEV
        call WALLFILL
@@s:    mov  ax,[camz]          ; south (camz < bwz0): 0,1 - the sunny side
        cmp  ax,[bwz0]
        jge  @@n
        call SUNNYDS
        mov  word ptr [fa],0
        mov  word ptr [fb],1
        call FACEV
        call WALLFILL
@@n:    mov  ax,[camz]          ; north (camz > bwz1): 2,3
        cmp  ax,[bwz1]
        jle  @@d
        call SUNNYDS
        mov  word ptr [fa],2
        mov  word ptr [fb],3
        call FACEV
        call WALLFILL
@@d:    ret

SUNNYDS:                        ; light at the eaves, mid at the pavement
        mov  al,[wallL]
        mov  [COLOR],al
        mov  [dcolA],al
        mov  al,[wallS]
        mov  [dcolB],al
        ret
SHADEDS:                        ; mid at the eaves, dark at the pavement
        mov  al,[wallS]
        mov  [COLOR],al
        mov  [dcolA],al
        mov  al,[wallD]
        mov  [dcolB],al
        ret

; ============================================================================
;  DITHPOLY - SCANPOLY, but the span goes down in TWO colours mixed by an
;  ordered dither instead of one flat colour. This is what stops a building
;  reading as a painted cube: a flat span of one index is the flattest thing
;  a screen can show, and the cure is per-pixel variation, not more colours.
;
;  THE MATRIX IS 2 WIDE AND 8 TALL, AND BOTH NUMBERS ARE THE DESIGN.
;  Two wide means the pattern repeats every WORD along the scanline, so the
;  inner loop is still REP STOSW and a dithered wall costs what a flat wall
;  costs. Eight tall buys 16 mix levels, and 16 levels is what keeps a
;  gradient from stepping in visible bands. A 4x4 Bayer would need a
;  four-byte period and an unrolled loop for the same 16 levels.
;
;  in:  dcolA - the lighter colour, dcolB - the darker one
;       dgrad = 1: the mix runs 0..16 down the face's projected height
;               0: the mix is dmixc everywhere (a stipple, for roofs)
;       dtop, dhgt - the face's top row and height (DITHFILL sets them)
;       PX/PY/NPOLY, ES = bufseg
; ============================================================================
DITHPOLY:
        mov  ax,[PY]
        mov  [pminy],ax
        mov  [pmaxy],ax
        mov  cx,[NPOLY]
        dec  cx
        mov  si,2
@@mm:   mov  ax,[PY+si]
        cmp  ax,[pminy]
        jge  @@mm1
        mov  [pminy],ax
@@mm1:  cmp  ax,[pmaxy]
        jle  @@mm2
        mov  [pmaxy],ax
@@mm2:  add  si,2
        loop @@mm
        mov  ax,[pminy]
        cmp  ax,0
        jge  @@y0
        xor  ax,ax
@@y0:   mov  [scy],ax
        mov  ax,[pmaxy]
        cmp  ax,199
        jle  @@y1
        mov  ax,199
@@y1:   mov  [scymax],ax
        mov  ax,[scy]
        cmp  ax,[scymax]
        jg   @@done
@@yloop:
        mov  word ptr [scxl],32767
        mov  word ptr [scxr],-32768
        mov  cx,[NPOLY]
        xor  si,si
@@eloop:
        mov  di,si
        add  di,2
        mov  ax,[NPOLY]
        add  ax,ax
        cmp  di,ax
        jl   @@nw2
        xor  di,di
@@nw2:  mov  ax,[PY+si]
        mov  bx,[PY+di]
        cmp  ax,bx
        jle  @@io
        xchg ax,bx
@@io:   mov  dx,[scy]
        cmp  dx,ax
        jl   @@enext
        cmp  dx,bx
        jge  @@enext
        mov  ax,[PX+di]
        sub  ax,[PX+si]
        mov  bx,[scy]
        sub  bx,[PY+si]
        imul bx
        mov  bx,[PY+di]
        sub  bx,[PY+si]
        idiv bx
        add  ax,[PX+si]
        cmp  ax,[scxl]
        jge  @@nxl
        mov  [scxl],ax
@@nxl:  cmp  ax,[scxr]
        jle  @@enext
        mov  [scxr],ax
@@enext:
        add  si,2
        loop @@eloop
        mov  ax,[scxl]
        cmp  ax,[scxr]
        jg   @@nextY
        cmp  ax,0
        jge  @@fxl
        xor  ax,ax
@@fxl:  mov  [scxl],ax
        mov  ax,[scxr]
        cmp  ax,319
        jle  @@fxr
        mov  ax,319
@@fxr:  mov  [scxr],ax
        mov  ax,[scxl]
        cmp  ax,[scxr]
        jg   @@nextY
        ; ---- how dark is this row? ----------------------------------------
        mov  ax,[dmixc]
        cmp  byte ptr [dgrad],0
        je   @@mok
        mov  ax,[scy]
        sub  ax,[dtop]
        mov  bx,16
        imul bx                 ; DX:AX - do NOT CWD, IMUL already set DX
        idiv word ptr [dhgt]    ; 0 at the eaves, 16 at the pavement
        ; ---- THE CURVE, and it is the whole difference between shading and
        ; noise. A straight 0..16 ramp spends most of the wall near half
        ; mix, and half mix in a two-colour dither is a CHECKERBOARD - the
        ; loudest pattern a screen can make, and it shouts louder than the
        ; shading it is supposed to carry. So: a thin stipple over the whole
        ; wall (DGRAIN), and the real darkening saved for the bottom third,
        ; where a building genuinely does stand in its own shadow and its
        ; neighbours'. Light shading, not a halftone screen.
        sub  ax,DSHADE
        jge  @@ramp
        xor  ax,ax
@@ramp: add  ax,ax
        add  ax,DGRAIN
@@mok:  cmp  ax,0
        jge  @@c1
        xor  ax,ax
@@c1:   cmp  ax,16
        jle  @@c2
        mov  ax,16
@@c2:   mov  [dmix],ax
        ; ---- the row's two bytes, one per column parity -------------------
        mov  bx,[scy]
        and  bx,7
        add  bx,bx
        mov  al,[DITH2+bx]
        xor  ah,ah
        cmp  ax,[dmix]
        jl   @@k0d
        mov  al,[dcolA]
        jmp  @@k0s
@@k0d:  mov  al,[dcolB]
@@k0s:  mov  [dpb0],al
        mov  al,[DITH2+bx+1]
        xor  ah,ah
        cmp  ax,[dmix]
        jl   @@k1d
        mov  al,[dcolA]
        jmp  @@k1s
@@k1d:  mov  al,[dcolB]
@@k1s:  mov  [dpb1],al
        ; the word, phased to where the span actually starts - otherwise the
        ; grain swims along the wall as the span edge moves
        mov  al,[dpb0]
        mov  ah,[dpb1]
        test word ptr [scxl],1
        jz   @@pw
        mov  al,[dpb1]
        mov  ah,[dpb0]
@@pw:   mov  [dpw],ax
        ; ---- lay it down --------------------------------------------------
        mov  di,[scy]
        mov  cl,8
        shl  di,cl
        mov  bx,[scy]
        mov  cl,6
        shl  bx,cl
        add  di,bx
        add  di,[scxl]
        mov  cx,[scxr]
        sub  cx,[scxl]
        inc  cx
        mov  dx,cx
        shr  cx,1
        mov  ax,[dpw]
        jcxz @@odd
        rep  stosw
@@odd:  test dx,1               ; an odd span ends on the parity it started
        jz   @@nextY            ; on, so AL is already the right byte
        stosb
@@nextY:
        mov  ax,[scy]
        inc  ax
        mov  [scy],ax
        cmp  ax,[scymax]
        jle  @@yloop
@@done: ret

; ============================================================================
;  DITHFILL - FACEFILL's dithered twin: clip, project, measure the face's
;  projected height (the gradient runs down THAT, not down the screen), fill.
; ============================================================================
DITHFILL:
        call CLIPNEAR
        mov  ax,[NPOLY]
        cmp  ax,3
        jl   @@x
        call PROJPOLY
        mov  ax,[PY]
        mov  [dtop],ax
        mov  [dbot],ax
        mov  cx,[NPOLY]
        dec  cx
        mov  si,2
@@h:    mov  ax,[PY+si]
        cmp  ax,[dtop]
        jge  @@h1
        mov  [dtop],ax
@@h1:   cmp  ax,[dbot]
        jle  @@h2
        mov  [dbot],ax
@@h2:   add  si,2
        loop @@h
        mov  ax,[dbot]
        sub  ax,[dtop]
        jnz  @@h3
        mov  ax,1               ; an edge-on face: never divide by nothing
@@h3:   mov  [dhgt],ax
        call DITHPOLY
@@x:    ret

; WALLFILL - one wall, shaded or flat, depending on the T switch. The flat
; path is kept working on purpose: a look is judged by what it is worth, and
; you cannot see that until you can turn it off.
WALLFILL:
        cmp  byte ptr [texon],0
        je   @@flat
        mov  byte ptr [dgrad],1
        call DITHFILL
        ret
@@flat: call FACEFILL
        ret

MEGAFILL:                       ; the same walk, keeping the current COLOR
        mov  ax,[camx]
        cmp  ax,[bwx0]
        jge  @@e
        mov  word ptr [fa],3
        mov  word ptr [fb],0
        call FACEV
        call FACEFILL
@@e:    mov  ax,[camx]
        cmp  ax,[bwx1]
        jle  @@s
        mov  word ptr [fa],1
        mov  word ptr [fb],2
        call FACEV
        call FACEFILL
@@s:    mov  ax,[camz]
        cmp  ax,[bwz0]
        jge  @@n
        mov  word ptr [fa],0
        mov  word ptr [fb],1
        call FACEV
        call FACEFILL
@@n:    mov  ax,[camz]
        cmp  ax,[bwz1]
        jle  @@d
        mov  word ptr [fa],2
        mov  word ptr [fb],3
        call FACEV
        call FACEFILL
@@d:    ret

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
;  THE ORDER IS LOAD-BEARING. WINFACE reads IX/IY/IZ expecting them to have
;  been PITCHED ALREADY - CLIPNEAR does that in place. Pitch them a second
;  time and the glass turns again about the camera axis and slides off the
;  wall exactly when you dive at the city, which is the only way you ever
;  approach it. It also reads PX/PY, the wall's projected outline, for its
;  own cull. So when the outlines are switched OFF the clip and the
;  projection still have to run - only the stroke is skipped.
;
;  There is no distance gate any more. The wall's projected size decides:
;  glass appears the moment the wall is worth more than WMINPX pixels, and
;  a pane too small to fill becomes one lit dot. A city seen from a long
;  way off IS speckle, and it should not switch on at some magic radius.
; ---------------------------------------------------------------------------
EDGEWIN:
        call FACEV
        mov  al,[scol]          ; the windows change COLOR - restore it
        mov  [COLOR],al
        cmp  byte ptr [edgeon],0
        je   @@nostr
        call FACESTROKE         ; clip -> project -> stroke
        jmp  @@win
@@nostr:
        call CLIPNEAR
        mov  ax,[NPOLY]
        cmp  ax,3
        jl   @@d
        call PROJPOLY
@@win:  cmp  byte ptr [winon],0
        je   @@d
        mov  ax,[NPOLY]         ; the wall never made it through the clip
        cmp  ax,3
        jl   @@d
        cmp  word ptr [bhw],50  ; not on spikes, chimneys or lintels
        jl   @@d
        mov  ax,[boxt]
        sub  ax,[boxb]
        cmp  ax,60              ; nor on flat slabs
        jl   @@d
        call WINFACE
@@d:    ret

; ============================================================================
;  WINFACE - lit panes on the current wall (IX/IY/IZ[0..3] already pitched).
;
;  THE PANE IS A QUAD ON THE WALL, not a square stamped on the screen.
;  What was here before got the pane CENTRES right - they were lerped in
;  camera space and projected one at a time - and then drew each pane as an
;  axis-aligned square of fixed world size. A square does not foreshorten.
;  Look along a wall and its columns crowd together while the glass keeps
;  its width; the windows stop lying on the brick and start floating over
;  it. That is the whole complaint, and the fix is to give every pane four
;  corners and let the projection do to them what it does to the wall.
;
;  DOING IT WITHOUT A MATRIX PER PANE. A wall quad is A_bot, A_top, B_top,
;  B_bot - and A_top-A_bot equals B_top-B_bot, because both are the same
;  vertical rise. So the wall is a PARALLELOGRAM, and PITCH4 is linear, so
;  it is still a parallelogram after the pitch. Every point on it is
;
;        P(i,j) = V0 + (i/NCOL)*U + (j/NROW)*V,   U = V3-V0, V = V1-V0
;
;  which means the whole corner lattice comes out of ONE row of column
;  offsets and ONE column of row offsets, combined by ADDITION. NCOL+NROW+2
;  interpolations for the face, then nothing but adds.
;
;  The panes share that lattice: (NCOL+1)*(NROW+1) = 24 projections carry
;  15 panes, instead of 60 if each pane were projected alone. The mullion
;  between them is made by shrinking each pane to half its cell AFTER
;  projection - a pane is small enough that shrinking it on screen and
;  shrinking it on the wall are the same picture.
;
;  Distance is handled by the pane itself: when its projected box is under
;  two pixels there is nothing to fill, so it becomes one lit dot. That is
;  what a far-off lit facade looks like, and it means the glass fades in
;  instead of switching on.
; ============================================================================
WINFACE:
        ; ---- the wall's own projected box: the cull and the level of
        ; detail in one. PX/PY are the outline EDGEWIN just projected.
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
        ; ---- quads or dots? ONE decision, for the whole wall ---------------
        ; Deciding per PANE is what made the far city crawl: a pane sitting
        ; near the threshold flips between a dot and a two-pixel quad as the
        ; camera creeps, and its neighbour flips on a different frame, so the
        ; facade seethes - some windows bigger, some smaller, every frame.
        ; The WALL's size changes smoothly and in one direction as you
        ; approach, so switching on that switches the whole facade at once,
        ; once, and nothing dances in between.
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
        mov  word ptr [wi],0
@@ci:   mov  si,[wi]
        add  si,si
        mov  ax,[wux]
        imul word ptr [wi]
        mov  bx,NCOL
        idiv bx
        mov  [CUX+si],ax
        mov  ax,[wuy]
        imul word ptr [wi]
        mov  bx,NCOL
        idiv bx
        mov  [CUY+si],ax
        mov  ax,[wuz]
        imul word ptr [wi]
        mov  bx,NCOL
        idiv bx
        mov  [CUZ+si],ax
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
        mov  [RVX+si],ax
        mov  ax,[wvy]
        imul word ptr [wj]
        mov  bx,NROW
        idiv bx
        mov  [RVY+si],ax
        mov  ax,[wvz]
        imul word ptr [wj]
        mov  bx,NROW
        idiv bx
        mov  [RVZ+si],ax
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
        add  ax,[CUZ+si]
        add  ax,[RVZ+di]
        mov  [wlz],ax
        mov  ax,[IX]
        add  ax,[CUX+si]
        add  ax,[RVX+di]
        mov  [wlx],ax
        mov  ax,[IY]
        add  ax,[CUY+si]
        add  ax,[RVY+di]
        mov  [wly],ax
        mov  bx,[wj]            ; lattice slot = j*NSTR + i
        mov  cl,3
        shl  bx,cl
        add  bx,[wi]
        cmp  word ptr [wlz],NEARZ
        jge  @@lok
        mov  byte ptr [WSOK+bx],0   ; this corner is behind us; any pane
        jmp  @@ln                   ; touching it drops out
@@lok:  mov  byte ptr [WSOK+bx],1
        add  bx,bx
        push bx
        mov  ax,[wlx]
        mov  dx,[wly]
        mov  cx,[wlz]
        call PROJPT
        pop  bx
        mov  [WSX+bx],ax
        mov  [WSY+bx],dx
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
        cmp  byte ptr [WSOK+bx],0
        je   @@pn
        cmp  byte ptr [WSOK+bx+1],0
        je   @@pn
        cmp  byte ptr [WSOK+bx+NSTR],0
        je   @@pn
        cmp  byte ptr [WSOK+bx+NSTR+1],0
        je   @@pn
        call WLIT2              ; dark windows are most of them
        jz   @@pn
        mov  si,[wbase]
        add  si,si
        mov  ax,[WSX+si]        ; bottom left
        mov  [PX],ax
        mov  ax,[WSY+si]
        mov  [PY],ax
        mov  ax,[WSX+si+2]      ; bottom right
        mov  [PX+2],ax
        mov  ax,[WSY+si+2]
        mov  [PY+2],ax
        mov  ax,[WSX+si+2*NSTR+2] ; top right
        mov  [PX+4],ax
        mov  ax,[WSY+si+2*NSTR+2]
        mov  [PY+4],ax
        mov  ax,[WSX+si+2*NSTR]   ; top left
        mov  [PX+6],ax
        mov  ax,[WSY+si+2*NSTR]
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
        call SCANPOLY
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
        call PUTPIXEL
@@pn:   inc  byte ptr [wc]
        cmp  byte ptr [wc],NCOL
        jl   @@pc
        inc  byte ptr [wr]
        cmp  byte ptr [wr],NROW
        jl   @@pr
@@ret:  ret

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
;  STATUS - one line of numbers along the bottom. A lab that cannot tell
;  you where the camera is standing makes you fly the same approach twice.
; ============================================================================
STATUS:
        mov  ax,[camx]
        mov  di,offset STATB+1
        call PUTNUM
        mov  ax,[camz]
        mov  di,offset STATB+7
        call PUTNUM
        mov  ax,[camy]
        mov  di,offset STATB+13
        call PUTNUM
        mov  ax,[heading]
        mov  di,offset STATB+19
        call PUTNUM
        mov  di,offset STATB+25
        mov  al,[winon]
        mov  bl,'W'
        call PUTSW
        mov  di,offset STATB+26
        mov  al,[edgeon]
        mov  bl,'E'
        call PUTSW
        mov  di,offset STATB+27
        mov  al,[texon]
        mov  bl,'T'
        call PUTSW
        mov  di,offset STATB+28
        mov  al,[caron]
        mov  bl,'C'
        call PUTSW
        mov  byte ptr [tcol],8
        mov  si,offset STATB
        mov  ax,190
        mov  bx,8
        call TXT
        ret

PUTSW:                          ; AL=flag, BL=the letter -> one char at CS:DI
        or   al,al              ; the letter means ON, a dash means OFF:
        jnz  @@on               ; three switches in three columns, and the
        mov  bl,'-'             ; status line still fits the screen
@@on:   mov  [di],bl
        ret

; PUTNUM - signed AX into the 5 characters at CS:DI, right aligned
PUTNUM: push di
        add  di,4
        mov  bx,10
        mov  cx,5
        xor  si,si
        or   ax,ax
        jns  @@pos
        neg  ax
        mov  si,1
@@pos:  xor  dx,dx
        div  bx
        add  dl,'0'
        mov  [di],dl
        dec  di
        dec  cx
        or   ax,ax
        jnz  @@pos
        or   si,si
        jz   @@pad
        mov  byte ptr [di],'-'
        dec  di
        dec  cx
@@pad:  or   cx,cx
        jle  @@done
@@p1:   mov  byte ptr [di],' '
        dec  di
        loop @@p1
@@done: pop  di
        ret

; ---- TXT: ASCIIZ at SI -> back buffer at row AX, column BX, colour tcol.
; The glyphs are the PC's own ROM font at F000:FA6E - the characters the
; machine boots with. No font resource, no converter.
TXT:    push es
        mov  cx,ax
        mov  ax,[bufseg]
        mov  es,ax
        mov  ax,cx
        mov  cx,320
        mul  cx
        add  ax,bx
        mov  di,ax
@@ch:   lodsb
        or   al,al
        jz   @@done
        push si
        xor  ah,ah
        mov  cl,3
        shl  ax,cl              ; glyph offset = char*8
        mov  si,0FA6Eh
        add  si,ax
        push ds
        mov  ax,0F000h
        mov  ds,ax
        mov  cx,8
        push di
@@row:  lodsb                   ; one row of bits, MSB = the left pixel
        mov  ah,al
        push cx
        mov  cx,8
@@px:   shl  ah,1
        jnc  @@np
        mov  al,cs:[tcol]
        mov  es:[di],al
@@np:   inc  di
        loop @@px
        add  di,320-8
        pop  cx
        loop @@row
        pop  di
        pop  ds
        pop  si
        add  di,8
        jmp  @@ch
@@done: pop  es
        ret

; ============================================================================
;  KBINT - the game's INT 9: our own KEYS[scancode] table, 1 down 0 up.
;  A camera needs to know that a key IS held, which the BIOS buffer with
;  its typematic delay cannot tell you. HITS is the lab's addition: a
;  sticky "this key went down since you last looked", for the switches.
; ============================================================================
KBINT:  push ax
        push bx
        push ds
        mov  ax,cs
        mov  ds,ax
        in   al,60h
        mov  ah,al
        and  al,7Fh
        mov  bl,al
        xor  bh,bh
        test ah,80h
        jnz  @@brk
        mov  byte ptr [KEYS+bx],1
        mov  byte ptr [HITS+bx],1
        jmp  @@eoi
@@brk:  mov  byte ptr [KEYS+bx],0
@@eoi:  mov  al,20h
        out  20h,al
        pop  ds
        pop  bx
        pop  ax
        iret

; ============================================================================
;  BLIT / WAITVR
; ============================================================================
BLIT:   push ds
        mov  ax,[bufseg]
        mov  ds,ax
        mov  ax,0A000h
        mov  es,ax
        xor  si,si
        xor  di,di
        mov  cx,32000
        rep  movsw
        pop  ds
        ret

WAITVR: mov  dx,3DAh
@@w1:   in   al,dx
        test al,8
        jnz  @@w1
@@w2:   in   al,dx
        test al,8
        jz   @@w2
        ret

; ============================================================================
;  SETPAL - the game's day palette, slots 0..30, byte for byte.
;  Slots 31..93 are the photo cockpit: Panel2Inc rewrites them from the
;  artwork on every build, so nothing outside the cockpit may use them -
;  and the lab does not. 120/121 are the lab's own two, taken from the
;  free top of the DAC (the game stops at 119).
; ============================================================================
SETPAL: mov  dx,3C8h
        xor  al,al
        out  dx,al
        mov  dx,3C9h
        mov  si,offset PALDAY
        mov  cx,31*3
@@p:    lodsb
        out  dx,al
        loop @@p
        mov  dx,3C8h
        mov  al,120
        out  dx,al
        mov  dx,3C9h
        mov  si,offset PALLAB
        mov  cx,NPALLAB*3
@@p2:   lodsb
        out  dx,al
        loop @@p2
        ret

PALDAY  db 36,37,40          ;0  wall N/S (light grey)
        db 30,32,36          ;1  far stroke (fades to haze)
        db 22,24,28          ;2  mid stroke
        db 12,13,16          ;3  near stroke (dark on light)
        db 16,22,32          ;4  window (dark glass)
        db 24,28,38          ;5  window (lighter glass)
        db 18,32,16          ;6  ground grid
        db 18,32,58          ;7  sky top (blue)
        db 63,63,63          ;8  HUD / white
        db 34,46,62          ;9  sky band (lighter near horizon)
        db 22,38,18          ;10 ground (green)
        db 32,46,28          ;11 field / ground band near horizon
        db 50,56,63          ;12 haze at the horizon (near white)
        db 26,17,10          ;13 mountains/rock (dark brown)
        db 16,32,54          ;14 water
        db 12,27,10          ;15 forest
        db 28,29,33          ;16 wall E/W (shaded side)
        db 44,45,48          ;17 roof (sun-lit)
        db 33,24,14          ;18 minimap city (brown)
        db 63, 6, 6          ;19 red (map course tick)
        db 30,34,48          ;20 blue wall lit
        db 22,26,40          ;21 blue wall shade
        db 46,28,22          ;22 red wall lit
        db 34,20,16          ;23 red wall shade
        db 52,52,54          ;24 white wall lit
        db 40,40,44          ;25 white wall shade
        db 24,38,60          ;26 sky step 2
        db 42,51,63          ;27 sky step 4, next to the haze
        db 14,26,12          ;28 dark far ground at the horizon
        db 10,10,12          ;29 cockpit panel (dark)
        db 20,20,23          ;30 cockpit panel trim
PALLAB  db 17,18,20          ;120 asphalt: the avenues
        db 30,29,26          ;121 pavement: the plot a house stands on
        ; ---- the third rung of each wall ramp. The game's WSCH gives every
        ; scheme a LIT and a SHADED colour and stops there, which is enough
        ; to tell two sides of a box apart and not enough to shade either of
        ; them. These four are the step below the shaded one, ~2/3 of it.
        ; They cost nothing anyone else wants: the cockpit owns 31..93 and
        ; is rewritten by Panel2Inc every build, the game itself stops at
        ; 119, and the DAC has 134 slots nobody has ever asked for.
        db 19,20,23          ;122 grey wall, dark
        db 14,17,27          ;123 blue wall, dark
        db 22,13,10          ;124 red wall, dark
        db 27,27,30          ;125 white wall, dark
        ; ---- eight vehicle paints, each a lit face and a shaded one. The
        ; city is grey by design; the traffic is the only thing in it
        ; allowed to be a colour.
        db 52,12,12          ;126 red
        db 34, 7, 7          ;127
        db 16,28,54          ;128 blue
        db 10,18,36          ;129
        db 56,50,14          ;130 yellow - the buses and the odd taxi
        db 38,33, 8          ;131
        db 14,42,22          ;132 green
        db  9,28,14          ;133
        db 56,56,58          ;134 white
        db 38,38,40          ;135
        db 24,25,28          ;136 charcoal
        db 15,16,19          ;137
        db 58,32, 8          ;138 orange
        db 40,21, 5          ;139
        db 12,44,46          ;140 teal
        db  8,30,31          ;141

; ---- the game's wall schemes, unchanged: grey / blue / red / white -------
WSCH    db 0,16, 20,21, 22,23, 24,25
WDRK    db 122,123,124,125      ; ...and the lab's third rung for each
PUFO    dw 0,21,42              ; smoke puff phase offsets (loop of 64)

; ---- the dither matrix: 2 wide (one WORD per scanline, so REP STOSW
; survives) by 8 tall (16 levels, so a gradient does not band).
; Two properties, both built in and both load-bearing:
;   - thresholds 0..7 sit on a CHECKERBOARD, so mix 8 comes out as a clean
;     50/50 chequer and not as stripes;
;   - inside that, low thresholds alternate columns as well as rows. Put
;     0,1,2 all in one column - which is what the first version did - and
;     the light stipple that most of a wall wears lines up into vertical
;     rows, and the eye reads corduroy instead of texture.
DITH2   db  0,13
        db  8, 5
        db  2,15
        db 10, 7
        db  4, 9
        db 12, 1
        db  6,11
        db 14, 3

HELP    db 13,10,'  HOUSE LAB - one city block, standing still.',13,10,13,10
        db '  ARROWS   fly: up/down forward and back, left/right turn',13,10
        db '  A / Z    climb / descend',13,10
        db '  S / X    look up / look down',13,10
        db '  , / .    slide left / right',13,10
        db '  SHIFT    fast',13,10
        db '  W        windows on / off',13,10
        db '  E        outlines on / off',13,10
        db '  T        wall shading on / off',13,10
        db '  C        traffic on / off',13,10
        db '  ESC      back to DOS',13,10,13,10
        db '  The three letters at the bottom right are those switches:',13,10
        db '  the letter is ON, a dash is OFF.',13,10,13,10
        db '  Press any key.',13,10,'$'

STATB   db 'X'                  ;0
        db '     '              ;1..5    camera X
        db 'Z'                  ;6
        db '     '              ;7..11   camera Z
        db 'Y'                  ;12
        db '     '              ;13..17  camera height
        db 'H'                  ;18
        db '     '              ;19..23  heading
        db ' '                  ;24
        db '    '               ;25..28  the switches: a letter is ON,
        db 0                    ;        a dash is OFF

; ============================================================================
;  STATE.  Everything below the line is the contract the ENGINE modules
;  state at the top of E_M3D.INC and E_RAST.INC, plus the lab's own.
; ============================================================================
bufseg  dw 0
oldk9   dw 0,0                  ; the BIOS keyboard handler we displaced
labtk   dw 0                    ; BIOS tick, for the chimney smoke
tcol    db 8                    ; TXT colour
winon   db 1                    ; the three lab switches
edgeon  db 1
texon   db 0                    ; OFF. It reads well in a still and CRAWLS in
                                ; motion - the matrix is indexed by SCREEN
                                ; x and y, so the grain is nailed to the
                                ; glass and the wall slides through it. Left
                                ; switched off, not deleted: see the README.
dcolA   db 0                    ; the dither pair: lighter, darker
dcolB   db 0
dgrad   db 1                    ; 1 = mix runs down the face, 0 = flat mix
dpb0    db 0                    ; this row's byte for even / odd columns
dpb1    db 0
dpw     dw 0                    ; ...packed and phased to the span start
dmix    dw 0                    ; this row's mix level 0..16
dmixc   dw 5                    ; the flat mix, when dgrad = 0
dtop    dw 0                    ; the face's projected top row...
dbot    dw 0
dhgt    dw 1                    ; ...and its height, never zero
mstep   dw 10                   ; camera speed this frame
mturn   dw 1
hcur    dw 100                  ; horizon row for the backdrop
crow    dw 0                    ; backdrop row counter
; ---- camera: parked south of the block, looking north at it. The block
; spans cells 24..35, world -2048..1024 both axes, so its centre is -512.
camx    dw -512
camy    dw 260
camz    dw -2600
camgi   dw 0
camgj   dw 0
; ---- the painter's walk ----------------------------------------------------
ordn    dw 0                    ; entries actually in ORDT
ordi    dw 0                    ; walk cursor
okey    dw 0                    ; BUILDORD: the squared distance being emitted
odi     dw 0
odj     dw 0
disq    dw 0                    ; di*di, hoisted out of the inner loop
; ---- the cell being drawn --------------------------------------------------
gi      dw 0
gj      dw 0
wcx     dw 0
wcz     dw 0
pwcx    dw 0                    ; the cell centre a composite moves off
pwcz    dw 0
gbase   dw 0                    ; ground under the cell (0 here, terrain there)
bstreet dw 0
bhw     dw 100
bhd     dw 100
bhgt2   dw 100
bschm   dw 0
btype   dw 0
bdist   dw 0
sbh     dw 0
bcol    db 0
boxb    dw 0
boxt    dw 0
bry0    dw 0
bry1    dw 0
bwx0    dw 0
bwx1    dw 0
bwz0    dw 0
bwz1    dw 0
minrz   dw 0
maxrz   dw 0
FRX     dw 4 dup(0)             ; footprint corners, camera space
FRZ     dw 4 dup(0)
fa      dw 0
fb      dw 0
wallL   db 0                    ; this building's wall ramp: light, mid...
wallS   db 0
wallD   db 0                    ; ...and dark, the lab's third rung
scol    db 1                    ; stroke colour (windows overwrite COLOR)
roofc   db 17                   ; the top face: 17 for a building, its own
                                ; paint for a vehicle
puffk   dw 0
; ---- traffic ---------------------------------------------------------------
caron   db 1
cartf   dw 0                    ; where we are in the signal cycle
caradv  dw 0                    ; whole blocks the platoons have banked
ctick   dw 0                    ; the traffic clock: last BIOS tick seen,
cfrm    dw 0                    ; frames inside it, frames the last tick
crate   dw 4                    ; lasted, where the interpolation had got
cfrac   dw 0                    ; to, and this frame's share
cstep   dw 0
vcen    dw 0                    ; the avenue's centre line
vcell   dw 0                    ; this cell's start along the lane
vstart  dw 0                    ; the frame this lane's green begins
voff    dw 0                    ; how far into its cell a vehicle is
vadv    dw 0                    ; cells the platoon has advanced
vlane   dw 0                    ; which lane, for the hash
vslot   dw 0                    ; which vehicle on it
vaxis   dw 0                    ; 0 = length runs along Z, 1 = along X
vdir    dw 1                    ; +1 or -1 along that axis
vtype   dw 0                    ; 0..4 car, 5 bus, 6..7 truck
vh      dw 0                    ; this vehicle's hash
vcx0    dw 0                    ; its centre, before a two-box body moves it
vcz0    dw 0
; ---- windows ---------------------------------------------------------------
wc      db 0                    ; pane column / row (also WLIT2's hash input)
wr      db 0
wux     dw 0                    ; U: along the wall, in camera space
wuy     dw 0
wuz     dw 0
wvx     dw 0                    ; V: up the wall
wvy     dw 0
wvz     dw 0
wi      dw 0                    ; lattice cursors
wj      dw 0
wlx     dw 0                    ; the lattice point being projected
wly     dw 0
wlz     dw 0
wbase   dw 0                    ; the cell's bottom-left lattice slot
wcxc    dw 0                    ; the pane's centre on screen
wcyc    dw 0
wquad   db 0                    ; 1 = this wall gets pane quads, 0 = dots
fbx0    dw 0                    ; the WALL's projected box: cull + detail
fbx1    dw 0
fby0    dw 0
fby1    dw 0
CUX     dw (NCOL+1) dup(0)      ; i*U/NCOL, one per column boundary
CUY     dw (NCOL+1) dup(0)
CUZ     dw (NCOL+1) dup(0)
RVX     dw (NROW+1) dup(0)      ; j*V/NROW, one per row boundary
RVY     dw (NROW+1) dup(0)
RVZ     dw (NROW+1) dup(0)
WSX     dw NLAT dup(0)          ; the projected corner lattice...
WSY     dw NLAT dup(0)
WSOK    db NLAT dup(0)          ; ...and which of its corners are in front
; ---- E_M3D contract --------------------------------------------------------
heading dw 0
pitch   dw 0
roll    dw 0                    ; a camera does not bank. Left at zero, so
                                ; APPLYROLL is the identity and the horizon
                                ; stays a straight line CLEARSKY can fill.
hsin    dw 0
hcos    dw 256
rsin    dw 0
rcos    dw 256
psin    dw 0
pcos    dw 256
pofs    dw 0
horiz   dw 100
swayx   dw 0
swayy   dw 0
wdx     dw 0
wdz     dw 0
rcx     dw 0
rcz     dw 0
rddx    dw 0
rddy    dw 0
rsxo    dw 0
ptmp    dw 0
; ---- E_RAST contract -------------------------------------------------------
IX      dw 4 dup(0)             ; the face going in
IY      dw 4 dup(0)
IZ      dw 4 dup(0)
OX      dw 6 dup(0)             ; near-clipped
OY      dw 6 dup(0)
OZ      dw 6 dup(0)
PX      dw 6 dup(0)             ; projected
PY      dw 6 dup(0)
NPOLY   dw 0
oc      dw 0
ci      dw 0
ni      dw 0
pk      dw 0
pminy   dw 0
pmaxy   dw 0
scy     dw 0
scymax  dw 0
scxl    dw 0
scxr    dw 0
tnum    dw 0
tden    dw 0
cdx     dw 0
cdy     dw 0
nx      dw 0
ny      dw 0
oc0     db 0
oc1     db 0
ocsel   db 0
lx      dw 0
ly      dw 0
ldx     dw 0
ldy     dw 0
lsx     dw 0
lsy     dw 0
lerr    dw 0
sx0     dw 0
sy0     dw 0
sx1     dw 0
sy1     dw 0
COLOR   db 0
; quarter sine table: SINT[i] = round(256*sin(i*90/64 deg)), i=0..64
SINT    dw 0,6,13,19,25,31,38,44,50,56,62,68,74,80,86,92,98,104,109,115
        dw 121,126,132,137,142,147,153,157,162,167,172,177,181,185,190,194
        dw 198,202,206,209,213,216,220,223,226,229,231,234,237,239,241,243
        dw 245,247,248,250,251,252,253,254,255,255,256,256,256

        INCLUDE ..\ENGINE\E_M3D.INC
        INCLUDE ..\ENGINE\E_RAST.INC

KEYS    db 128 dup(0)           ; key state (held), written by KBINT
HITS    db 128 dup(0)           ; key went down, cleared by whoever reads it
SQD     dw (2*RAD+1) dup(0)     ; squares of -RAD..RAD
ORDT    db NORD*2 dup(0)        ; the painter's order: (di,dj) pairs

CODE    ENDS
        END START
