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
RAD     equ 8                   ; painter walk radius, in cells
NORD    equ (2*RAD+1)*(2*RAD+1) ; cells in the walk (289)
MAXD2   equ RAD*RAD*2           ; biggest squared cell distance in it
BLK0    equ 24                  ; the lab block: cells BLK0..BLK1 both axes
BLK1    equ 39                  ; 16x16 = four superblocks = four districts

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
        call MOVECAM
        cmp  byte ptr [KEYS+SC_ESC],0
        jne  @@quit
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
;  emit every cell that has it.
; ============================================================================
BUILDORD:
        mov  word ptr [ordn],0
        mov  word ptr [okey],MAXD2
@@k:    mov  word ptr [odi],-RAD
@@i:    mov  word ptr [odj],-RAD
@@j:    mov  ax,[odi]
        imul word ptr [odi]
        mov  bx,ax
        mov  ax,[odj]
        imul word ptr [odj]
        add  ax,bx
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
        ; ---- the two lab switches, on the key EDGE (hold does nothing) ----
        mov  bl,SC_W
        mov  si,offset winon
        mov  di,offset wlat
        call TOGGLE
        mov  bl,SC_E
        mov  si,offset edgeon
        mov  di,offset elat
        call TOGGLE
        ret

FENCE:  cmp  ax,6000            ; keep the camera inside the lab's room
        jle  @@n1
        mov  ax,6000
@@n1:   cmp  ax,-6000
        jge  @@n2
        mov  ax,-6000
@@n2:   ret

; TOGGLE - BL=scancode, SI=the flag, DI=its latch. Flips the flag once per
; press: without the latch a switch would buzz at the frame rate.
TOGGLE: xor  bh,bh              ; BL is the scancode, BH must not be junk
        mov  al,[KEYS+bx]
        or   al,al
        jz   @@up
        cmp  byte ptr [di],0
        jne  @@d
        mov  byte ptr [di],1
        xor  byte ptr [si],1
        ret
@@up:   mov  byte ptr [di],0
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
        mov  ax,[gi]
        and  ax,3
        jz   @@road
        mov  ax,[gj]
        and  ax,3
        jnz  @@put
@@road: mov  byte ptr [COLOR],120
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
        je   @@ret              ; plain street cell -> nothing to draw
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
        add  ax,60
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
@@ba1:  mov  [boxt],ax
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
        mov  ax,[pwcx]
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
        mov  [boxt],ax
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
        mov  cl,2
        shr  bx,cl
        add  bx,7               ; puffs grow as they rise
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
;  LHBLD - the lab's building descriptor for cell [gi],[gj].
;  The game's HBLD with two things removed: the terrain zoning (there is no
;  terrain here) and the superblock "is this block built up" test (only
;  ~3/16 of blocks are, and a lab wants houses in front of it, not a field
;  to search). EVERY number that decides how the building LOOKS is the
;  game's, and so is the hash - these are the game's own cells.
; ============================================================================
LHBLD:  mov  ax,[gi]
        and  ax,3
        jz   @@st               ; gi on an avenue -> street
        mov  ax,[gj]
        and  ax,3
        jz   @@st               ; gj on an avenue -> street
        call CELLHASH
        mov  bx,ax
        and  bx,31              ; hash 7/8/9 of 32 -> flat terrain patches
        cmp  bx,7
        je   @@forest
        cmp  bx,8
        je   @@water
        cmp  bx,9
        je   @@field
        push ax
        call SBHASH             ; the district still comes from the block
        mov  [sbh],ax
        pop  ax
        mov  bx,[sbh]
        mov  cl,4
        shr  bx,cl
        and  bx,3               ; 0/3 residential, 1 downtown, 2 industry
        mov  [bdist],bx
        mov  bx,ax
        and  bx,31              ; bits[0..4]  -> half width  84..115
        add  bx,84
        mov  [bhw],bx
        mov  bx,ax
        mov  cl,5
        shr  bx,cl
        and  bx,31              ; bits[5..9]  -> half depth  84..115
        add  bx,84
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
        add  bx,60              ; height 60..123
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
        mov  bx,36
        imul bx                 ; downtown bonus 0..288
        mov  si,ax
        pop  ax
        mov  bx,ax
        and  bx,63
        add  bx,50
        add  bx,si              ; height 50..401
        mov  [bhgt2],bx
        jmp  @@bdone
@@ind:  mov  word ptr [bschm],0 ; --- industry: smoking factories, always grey
        mov  word ptr [btype],4
        cmp  bx,5
        jb   @@ih
        mov  word ptr [btype],0 ; 5..7 plain shed
@@ih:   mov  bx,ax
        and  bx,31
        add  bx,50              ; low industry: 50..81
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
VISFILL:
        mov  ax,[camx]          ; west (camx < bwx0): corners 3,0
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
@@s:    mov  ax,[camz]          ; south (camz < bwz0): 0,1 - the sunny side
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
;  been PITCHED ALREADY - FACESTROKE's CLIPNEAR does that in place. Pitch
;  them a second time and the glass turns again about the camera axis and
;  slides off the wall exactly when you dive at the city, which is the only
;  way you ever approach it. So when the outlines are switched OFF, the
;  pitch still has to happen: PITCH4 stands in for the stroke.
; ---------------------------------------------------------------------------
EDGEWIN:
        call FACEV
        mov  al,[scol]          ; the windows change COLOR - restore it
        mov  [COLOR],al
        cmp  byte ptr [edgeon],0
        je   @@nostr
        call FACESTROKE
        jmp  @@win
@@nostr:
        call PITCH4
@@win:  cmp  byte ptr [winon],0
        je   @@d
        mov  ax,[minrz]         ; windows only on near faces
        cmp  ax,1200
        jg   @@d
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
;  The glass walks the wall in CAMERA space and every pane is projected on
;  its own: a grid interpolated in SCREEN space is affine, which looks fine
;  at a distance and slides the windows clean off the building when you
;  close in. Each pane carries its own Z test too, so a half-clipped wall
;  keeps the glass it can still show.
;
;  THIS IS THE ROUTINE THE LAB EXISTS FOR. 3 columns x 5 rows of square
;  dots is what a house is currently wearing; W turns it off so you can see
;  what it is worth.
; ============================================================================
WINFACE:
        mov  byte ptr [wc],0
@@cl:   mov  al,[wc]            ; u = (2c+1)/6 across the wall
        cbw
        add  ax,ax
        inc  ax
        mov  [wfu],ax
        mov  ax,[IX+4]          ; column top = C1 + (C2-C1)*u/6
        sub  ax,[IX+2]
        imul word ptr [wfu]
        mov  bx,6
        idiv bx
        add  ax,[IX+2]
        mov  [wtcx],ax
        mov  ax,[IY+4]
        sub  ax,[IY+2]
        imul word ptr [wfu]
        mov  bx,6
        idiv bx
        add  ax,[IY+2]
        mov  [wtcy],ax
        mov  ax,[IZ+4]
        sub  ax,[IZ+2]
        imul word ptr [wfu]
        mov  bx,6
        idiv bx
        add  ax,[IZ+2]
        mov  [wtcz],ax
        mov  ax,[IX+6]          ; column bottom = C0 + (C3-C0)*u/6
        sub  ax,[IX]
        imul word ptr [wfu]
        mov  bx,6
        idiv bx
        add  ax,[IX]
        mov  [wbcx],ax
        mov  ax,[IY+6]
        sub  ax,[IY]
        imul word ptr [wfu]
        mov  bx,6
        idiv bx
        add  ax,[IY]
        mov  [wbcy],ax
        mov  ax,[IZ+6]
        sub  ax,[IZ]
        imul word ptr [wfu]
        mov  bx,6
        idiv bx
        add  ax,[IZ]
        mov  [wbcz],ax
        mov  byte ptr [wr],0
@@rl:   mov  al,[wr]            ; v = (2r+1)/10 down the column
        cbw
        add  ax,ax
        inc  ax
        mov  [wfv],ax
        mov  ax,[wbcz]          ; depth first: it gates AND it sizes
        sub  ax,[wtcz]
        imul word ptr [wfv]
        mov  bx,10
        idiv bx
        add  ax,[wtcz]
        mov  [wgz],ax
        cmp  ax,NEARZ
        jl   @@wn               ; this pane is behind us
        mov  ax,[wbcx]
        sub  ax,[wtcx]
        imul word ptr [wfv]
        mov  bx,10
        idiv bx
        add  ax,[wtcx]
        mov  [wgx],ax
        mov  ax,[wbcy]
        sub  ax,[wtcy]
        imul word ptr [wfv]
        mov  bx,10
        idiv bx
        add  ax,[wtcy]
        mov  [wgy],ax
        mov  ax,[wgx]
        mov  dx,[wgy]
        mov  cx,[wgz]
        call PROJPT
        mov  [wpx],ax
        mov  [wpy],dx
        call WLIT2
        jz   @@wn
        mov  ax,6160            ; a pane is ~28 units of glass: r=28*220/z
        cwd
        idiv word ptr [wgz]
        or   ax,ax
        jnz  @@ws1
        inc  ax                 ; never smaller than one lit pixel
@@ws1:  cmp  ax,10
        jle  @@ws2
        mov  ax,10              ; ...and never a wall of light
@@ws2:  mov  [wbsz],al
        sar  ax,1               ; centre the pane on its point
        mov  bx,[wpx]
        sub  bx,ax
        mov  [wpx],bx
        mov  bx,[wpy]
        sub  bx,ax
        mov  [wpy],bx
        mov  byte ptr [wbj],0
@@wby:  mov  byte ptr [wbi],0
@@wbx:  mov  al,[wbi]
        cbw
        add  ax,[wpx]
        js   @@wbs
        cmp  ax,319
        jg   @@wbs
        mov  bl,[wbj]
        xor  bh,bh
        add  bx,[wpy]
        js   @@wbs
        cmp  bx,199
        jg   @@wbs
        call PUTPIXEL
@@wbs:  inc  byte ptr [wbi]
        mov  al,[wbi]
        cmp  al,[wbsz]
        jl   @@wbx
        inc  byte ptr [wbj]
        mov  al,[wbj]
        cmp  al,[wbsz]
        jl   @@wby
@@wn:   inc  byte ptr [wr]
        cmp  byte ptr [wr],5
        jl   @@rl
        inc  byte ptr [wc]
        cmp  byte ptr [wc],3
        jl   @@cl
        ret

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
        mov  di,offset STATB+26
        mov  al,[winon]
        call PUTFLAG
        mov  di,offset STATB+31
        mov  al,[edgeon]
        call PUTFLAG
        mov  byte ptr [tcol],8
        mov  si,offset STATB
        mov  ax,190
        mov  bx,8
        call TXT
        ret

PUTFLAG:                        ; AL=0/1 -> 'OFF' / 'ON ' at CS:DI
        or   al,al
        jz   @@off
        mov  byte ptr [di],'O'
        mov  byte ptr [di+1],'N'
        mov  byte ptr [di+2],' '
        ret
@@off:  mov  byte ptr [di],'O'
        mov  byte ptr [di+1],'F'
        mov  byte ptr [di+2],'F'
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
;  its typematic delay cannot tell you.
; ============================================================================
KBINT:  push ax
        push bx
        push di
        push ds
        mov  ax,cs
        mov  ds,ax
        in   al,60h
        mov  ah,al
        and  al,7Fh
        mov  bl,al
        xor  bh,bh
        mov  di,offset KEYS
        add  di,bx
        test ah,80h
        jnz  @@brk
        mov  byte ptr [di],1
        jmp  @@eoi
@@brk:  mov  byte ptr [di],0
@@eoi:  mov  al,20h
        out  20h,al
        pop  ds
        pop  di
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
        mov  cx,2*3
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

; ---- the game's wall schemes, unchanged: grey / blue / red / white -------
WSCH    db 0,16, 20,21, 22,23, 24,25
PUFO    dw 0,21,42              ; smoke puff phase offsets (loop of 64)

HELP    db 13,10,'  HOUSE LAB - one city block, standing still.',13,10,13,10
        db '  ARROWS   fly: up/down forward and back, left/right turn',13,10
        db '  A / Z    climb / descend',13,10
        db '  S / X    look up / look down',13,10
        db '  , / .    slide left / right',13,10
        db '  SHIFT    fast',13,10
        db '  W        windows on / off',13,10
        db '  E        outlines on / off',13,10
        db '  ESC      back to DOS',13,10,13,10
        db '  Press any key.',13,10,'$'

STATB   db 'X'                  ;0
        db '     '              ;1..5    camera X
        db 'Z'                  ;6
        db '     '              ;7..11   camera Z
        db 'Y'                  ;12
        db '     '              ;13..17  camera height
        db 'H'                  ;18
        db '     '              ;19..23  heading
        db ' W'                 ;24,25
        db '   '                ;26..28  windows
        db ' E'                 ;29,30
        db '   '                ;31..33  outlines
        db 0

; ============================================================================
;  STATE.  Everything below the line is the contract the ENGINE modules
;  state at the top of E_M3D.INC and E_RAST.INC, plus the lab's own.
; ============================================================================
bufseg  dw 0
oldk9   dw 0,0                  ; the BIOS keyboard handler we displaced
labtk   dw 0                    ; BIOS tick, for the chimney smoke
tcol    db 8                    ; TXT colour
winon   db 1                    ; the two lab switches...
edgeon  db 1
wlat    db 0                    ; ...and their key-edge latches
elat    db 0
mstep   dw 10                   ; camera speed this frame
mturn   dw 1
hcur    dw 100                  ; horizon row for the backdrop
crow    dw 0                    ; backdrop row counter
; ---- camera: parked south of the block, looking north at it ----------------
camx    dw 0
camy    dw 300
camz    dw -3400
camgi   dw 0
camgj   dw 0
; ---- the painter's walk ----------------------------------------------------
ordn    dw 0                    ; entries actually in ORDT
ordi    dw 0                    ; walk cursor
okey    dw 0                    ; BUILDORD: the squared distance being emitted
odi     dw 0
odj     dw 0
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
wallL   db 0                    ; this building's two wall colours
wallS   db 0
scol    db 1                    ; stroke colour (windows overwrite COLOR)
puffk   dw 0
; ---- windows ---------------------------------------------------------------
wc      db 0
wr      db 0
wfu     dw 0
wfv     dw 0
wtcx    dw 0
wtcy    dw 0
wtcz    dw 0
wbcx    dw 0
wbcy    dw 0
wbcz    dw 0
wgx     dw 0
wgy     dw 0
wgz     dw 0
wpx     dw 0
wpy     dw 0
wbsz    db 0
wbi     db 0
wbj     db 0
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

KEYS    db 128 dup(0)           ; key state, written by KBINT
ORDT    db NORD*2 dup(0)        ; the painter's order: (di,dj) pairs

CODE    ENDS
        END START
