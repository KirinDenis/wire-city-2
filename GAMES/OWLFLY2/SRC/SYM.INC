; SYM.INC - part of WIRE CITY (included from CITY.ASM, after UI.INC)
; ============================================================================
;  THE FOURTH SEGMENT, opened 2026-07-29 because UISEG filled its 8K window
;  and the rule in this project is to open a segment, not to shave bytes.
;  The arrangement is SKYSEG's and UISEG's, copied: PARA aligned, padded to
;  claim its whole window so the linker parks the next thing exactly where
;  the loader expects, and an assemble-time guard that refuses to overflow.
;  Layout now: CODE at CS+0, SKYSEG CS+1000h, UISEG CS+1200h, SYMSEG
;  CS+1400h, and the back buffer moved up to CS+1600h to make room.
;
;  What lives here: the SCOPE SYMBOLS. They earned the move by being the
;  cleanest tenants in the building - pure drawing, every input in a
;  main-segment variable, not one byte of their own CS-relative data. So
;  they can be anywhere, and anything that has to stay put should not be.
;
;  Code here runs with DS = the main segment, like the other far segments,
;  and cannot near-call into CODE: it reaches home through the thunks in
;  PLANES.INC (SINQF, CLIPLINF, LINEF).
;
;  Far doors: BQJETF (an aeroplane), BQSTAF (a radar), BQSHKF (a Shilka).
; ============================================================================

SYMSEG  SEGMENT PARA PUBLIC 'CODE'
        ASSUME  CS:SYMSEG, DS:CODE, ES:NOTHING, SS:CODE

SYMBASE label byte              ; offset zero, for the window guard below

BQJETF  PROC FAR
        call BQJET
        ret
BQJETF  ENDP
BQSTAF  PROC FAR
        call BQSTA
        ret
BQSTAF  ENDP
BQSHKF  PROC FAR
        call BQSHK
        ret
BQSHKF  ENDP
TOPSTRIPF PROC FAR
        call TOPSTRIP
        ret
TOPSTRIPF ENDP
BOTSTRIPF PROC FAR
        call BOTSTRIP
        ret
BOTSTRIPF ENDP
SHKBRGF PROC FAR
        call SHKBRG
        ret
SHKBRGF ENDP
GNDMARKF PROC FAR
        call GNDMARK
        ret
GNDMARKF ENDP
BQCITYF PROC FAR
        call BQCITY
        ret
BQCITYF ENDP

; atan(i/32) as a bearing, 0..32 of 256. Thirty-three bytes buy a real
; bearing without a divide-heavy iteration or a 256-entry table: the
; octant comes from the signs, the ratio picks the row.
SHKATN  db 0,1,3,4,5,6,8,9,10,11,12,13,15,16,17,18,19
        db 20,21,22,23,24,25,25,26,27,28,29,29,30,31,31,32


; ---------------------------------------------------------------------------
BQPT:   mov  ax,[bqal]
        imul word ptr [bqsn]
        mov  bx,256
        idiv bx
        mov  cx,ax              ; along * sin
        mov  ax,[bqac]
        imul word ptr [bqcs]
        idiv bx
        add  ax,cx
        add  ax,[bqx]
        push ax
        mov  ax,[bqal]
        imul word ptr [bqcs]
        idiv bx
        mov  cx,ax              ; along * cos
        mov  ax,[bqac]
        imul word ptr [bqsn]
        idiv bx
        sub  ax,cx
        add  ax,[bqy]
        mov  dx,ax
        pop  ax
        ret

; ---------------------------------------------------------------------------
;  BQSEG - one line of a symbol, from (bqal,bqac) to the pair in AX,BX.
;  Clipped: a contact at the rim of the scope must not paint over the panel.
; ---------------------------------------------------------------------------
BQSEG:  push ax
        push bx
        call BQPT
        mov  [sx0],ax
        mov  [sy0],dx
        pop  bx
        pop  ax
        mov  [bqal],ax
        mov  [bqac],bx
        call BQPT
        mov  [sx1],ax
        mov  [sy1],dx
        call FAR PTR CLIPLINF
        jc   @@sn
        call FAR PTR LINEF
@@sn:   ret

; ---------------------------------------------------------------------------
;  BQJET - the aeroplane: a fuselage seven pixels long, a wing eight across
;  and a tailplane, swung to [bqa]. in: bqx/bqy centre, bqa heading, COLOR.
; ---------------------------------------------------------------------------
BQJET:  mov  ax,[bqa]
        and  ax,255
        push ax
        call FAR PTR SINQF
        mov  [bqsn],ax
        pop  ax
        add  ax,64
        call FAR PTR SINQF
        mov  [bqcs],ax
        mov  word ptr [bqal],5  ; nose to tail
        mov  word ptr [bqac],0
        mov  ax,-3
        xor  bx,bx
        call BQSEG
        mov  word ptr [bqal],1  ; the wing, a shade ahead of centre
        mov  word ptr [bqac],-5
        mov  ax,1
        mov  bx,5
        call BQSEG
        mov  word ptr [bqal],-3 ; the tailplane
        mov  word ptr [bqac],-2
        mov  ax,-3
        mov  bx,2
        call BQSEG
        mov  word ptr [bqal],3  ; and the CANOPY: a bar across the spine
        mov  word ptr [bqac],-1 ; just behind the nose. Three pixels, and
        mov  ax,3               ; they are what turns a cross into an
        mov  bx,1               ; aeroplane seen from above
        call BQSEG
        ret

; ---------------------------------------------------------------------------
;  BQSTA - a ground radar: a static lozenge with the dish's two arms. It
;  does NOT turn - that is the point. Aircraft are the things that have a
;  heading, and a mark that never rotates cannot be mistaken for one at a
;  glance, which is the whole job of a radar symbol.
; ---------------------------------------------------------------------------
BQSTA:  mov  word ptr [bqsn],0  ; no rotation: sin 0, cos 256
        mov  word ptr [bqcs],256
        mov  word ptr [bqal],-4 ; the MAST, straight up
        mov  word ptr [bqac],0
        mov  ax,3
        xor  bx,bx
        call BQSEG
        mov  word ptr [bqal],3  ; ...and the DISH on top of it: a shallow
        mov  word ptr [bqac],-3 ; bowl opening upward, drawn as three sides
        mov  ax,5               ; of a triangle. It is a picture, not a
        xor  bx,bx              ; plan - a radar has no heading worth
        call BQSEG              ; showing, and a mark that cannot be
        mov  word ptr [bqal],5  ; mistaken for an aircraft is the point
        mov  word ptr [bqac],0
        mov  ax,3
        mov  bx,3
        call BQSEG
        mov  word ptr [bqal],3
        mov  word ptr [bqac],-3
        mov  ax,3
        mov  bx,3
        call BQSEG
        ret

; ---------------------------------------------------------------------------
;  BQSHK - a Shilka: a short body across the track, and a BARREL that points
;  where its turret really points. The turret bearing is already computed
;  for the 3D model, so on the scope it costs nothing - and it is the one
;  thing a pilot wants to know about a gun: is it looking at me.
;  in: bqx/bqy, bqa = the TURRET's bearing relative to our heading, COLOR.
; ---------------------------------------------------------------------------
BQSHK:  ; A PICTURE, from the side, and it does not rotate. The plan view
        ; said which way the turret pointed, but at four pixels nobody read
        ; it; this says "tracked vehicle with guns" at a glance, which is
        ; the thing you actually need off a scope. The barrels sit at the
        ; angle they are famous for.
        mov  word ptr [bqsn],0
        mov  word ptr [bqcs],256
        mov  word ptr [bqal],-3 ; the track run
        mov  word ptr [bqac],-4
        mov  ax,-3
        mov  bx,4
        call BQSEG
        mov  word ptr [bqal],-1 ; the hull deck
        mov  word ptr [bqac],-4
        mov  ax,-1
        mov  bx,4
        call BQSEG
        mov  word ptr [bqal],-3 ; and its two ends
        mov  word ptr [bqac],-4
        mov  ax,-1
        mov  bx,-4
        call BQSEG
        mov  word ptr [bqal],-3
        mov  word ptr [bqac],4
        mov  ax,-1
        mov  bx,4
        call BQSEG
        mov  word ptr [bqal],-1 ; the turret drum
        mov  word ptr [bqac],-2
        mov  ax,1
        mov  bx,-2
        call BQSEG
        mov  word ptr [bqal],1
        mov  word ptr [bqac],-2
        mov  ax,1
        mov  bx,2
        call BQSEG
        mov  word ptr [bqal],1
        mov  word ptr [bqac],2
        mov  ax,-1
        mov  bx,2
        call BQSEG
        mov  word ptr [bqal],1  ; the barrels, up and out the way they are
        mov  word ptr [bqac],2  ; drawn on every photograph of the thing
        mov  ax,4
        mov  bx,5
        call BQSEG
        ret

; ============================================================================
;  TOPSTRIP / BOTSTRIP - the compact 4x6 readouts for the NO-COCKPIT view.
;  That view used to carry BIOS teletype text in the 8x8 ROM font, twice the
;  size of anything else on the glass and unable to share a row with it.
;  These are the same words in the game's own font, drawn into the back
;  buffer like everything else, so they can sit anywhere and be any colour.
;  The strip used to ride the cockpit's overhead bank; with the new panel
;  that only repeated the readouts under the screens, so it moved here.
;  ES=bufseg.
; ============================================================================
TOPSTRIP:
        mov  byte ptr [COLOR],8
        mov  word ptr [ftx],100
        mov  word ptr [fty],2
        mov  si,offset MSGTITLE
        call FAR PTR FDRAWF
        mov  byte ptr [COLOR],97
        mov  word ptr [ftx],146
        mov  si,offset MSGTIM
        call FAR PTR FDRAWF
        mov  byte ptr [COLOR],8
        mov  word ptr [ftx],154
        mov  ax,[lasttk]        ; BIOS ticks -> seconds
        xor  dx,dx
        mov  bx,18
        div  bx
        call FAR PTR FNUMF
        mov  byte ptr [COLOR],97
        mov  word ptr [ftx],178
        mov  si,offset MSGALT
        call FAR PTR FDRAWF
        mov  byte ptr [COLOR],8
        mov  ax,[camy]
        call FAR PTR FNUMF
        cmp  byte ptr [mslcam],0 ; missile camera armed: amber M
        je   @@tsm
        mov  byte ptr [COLOR],97
        mov  word ptr [ftx],216
        mov  word ptr [fty],2
        mov  si,offset MSGM2
        call FAR PTR FDRAWF
@@tsm:
        cmp  byte ptr [sbok],0  ; sound-mode letter: amber = all sounds,
        je   @@tss              ; white = effects only, red = silence
        mov  byte ptr [COLOR],97
        mov  al,[sndmod]
        cmp  al,2
        je   @@tsc
        mov  byte ptr [COLOR],8
        cmp  al,1
        je   @@tsc
        mov  byte ptr [COLOR],19
@@tsc:  mov  word ptr [ftx],226
        mov  word ptr [fty],2
        mov  si,offset MSGS3
        call FAR PTR FDRAWF
@@tss:  ret

BOTSTRIP:
        mov  byte ptr [COLOR],97
        mov  word ptr [ftx],4
        mov  word ptr [fty],192
        mov  si,offset MSGHDG2
        call FAR PTR FDRAWF
        add  word ptr [ftx],4   ; a space between the word and the number
        mov  byte ptr [COLOR],8
        mov  ax,[heading]
        mov  cx,3
        call FAR PTR FNUMZF
        mov  byte ptr [COLOR],97
        mov  word ptr [ftx],40
        mov  si,offset MSGSPD2
        call FAR PTR FDRAWF
        add  word ptr [ftx],4
        mov  byte ptr [COLOR],8
        mov  ax,[vel]
        mov  cx,4
        call FAR PTR FNUMZF
        mov  byte ptr [COLOR],97
        mov  word ptr [ftx],88
        mov  si,offset MSGFUE2
        call FAR PTR FDRAWF
        add  word ptr [ftx],4
        mov  byte ptr [COLOR],8
        cmp  word ptr [fuel],1200
        jge  @@bs1
        mov  byte ptr [COLOR],19
@@bs1:  mov  ax,[fuel]
        xor  dx,dx
        mov  bx,60
        div  bx
        mov  cx,3
        call FAR PTR FNUMZF
        mov  byte ptr [COLOR],97
        mov  word ptr [ftx],136
        mov  si,offset MSGTHR2
        call FAR PTR FDRAWF
        add  word ptr [ftx],4
        mov  byte ptr [COLOR],8
        mov  ax,[throt]
        mov  bx,100
        imul bx
        mov  bx,64
        idiv bx
        mov  cx,3
        call FAR PTR FNUMZF
        cmp  byte ptr [abon],0
        je   @@bs2
        mov  byte ptr [COLOR],97
        mov  si,offset MSGAB
        call FAR PTR FDRAWF
@@bs2:  ret

; ---------------------------------------------------------------------------
;  SHKBRG - the bearing from [wdx] east and [wdz] north, 0..255 with 0 due
;  north and 64 due east - the same compass the jets steer by. Octant from
;  the signs, then the smaller leg over the larger picks a row of SHKATN.
;  out: AX = the bearing. Clobbers BX, CX, DX.
; ---------------------------------------------------------------------------
SHKBRG: mov  ax,[wdx]
        mov  bx,[wdz]
        mov  cx,ax              ; keep the signs; work on magnitudes
        mov  dx,bx
        or   ax,ax
        jns  @@b1
        neg  ax
@@b1:   or   bx,bx
        jns  @@b2
        neg  bx
@@b2:   cmp  ax,bx
        ja   @@bwide
        ; the target is more north/south than east/west
        or   bx,bx
        jnz  @@bt1
        xor  ax,ax              ; both zero: call it north and be done
        ret
@@bt1:  push cx
        push dx
        mov  cl,5
        shl  ax,cl              ; |dx|*32/|dz|, and |dx| <= |dz| so it fits
        xor  dx,dx
        div  bx
        mov  bx,ax
        mov  al,cs:[SHKATN+bx]
        xor  ah,ah
        pop  dx
        pop  cx
        or   dx,dx
        js   @@bs               ; southward
        or   cx,cx
        jns  @@bd               ; north-east: the angle IS the bearing
        neg  ax                 ; north-west
        and  ax,255
        ret
@@bs:   or   cx,cx
        jns  @@bse
        add  ax,128             ; south-west
        ret
@@bse:  mov  bx,128             ; south-east
        sub  bx,ax
        mov  ax,bx
@@bd:   ret
@@bwide:; more east/west than north/south
        push cx
        push dx
        xchg ax,bx
        mov  cl,5
        shl  ax,cl              ; |dz|*32/|dx|
        xor  dx,dx
        div  bx
        mov  bx,ax
        mov  al,cs:[SHKATN+bx]
        xor  ah,ah
        pop  dx
        pop  cx
        or   cx,cx
        js   @@bw
        or   dx,dx              ; eastward
        js   @@bse2
        mov  bx,64              ; north-east
        sub  bx,ax
        mov  ax,bx
        ret
@@bse2: add  ax,64              ; south-east
        ret
@@bw:   or   dx,dx              ; westward
        js   @@bsw
        add  ax,192             ; north-west
        and  ax,255
        ret
@@bsw:  mov  bx,192             ; south-west
        sub  bx,ax
        mov  ax,bx
        ret


; ---------------------------------------------------------------------------
;  BQCITY - the CITY on the scope: one small square per built cell, laid
;  under everything else so the traffic paints over it. This is what a
;  ground-mapping radar gives you, and it is the difference between "a dot
;  is somewhere" and "a dot is over the town".
;
;  There is no list of buildings in this game. Every one of them is computed
;  from its own cell hash the moment it is drawn, which is why this walks
;  cells and asks HBLD one at a time - and why it only runs on the two
;  tightest zooms. At the widest the scope reaches eighty cells in each
;  direction; that is twenty-five thousand questions a frame, and the answer
;  would be a solid grey square anyway.
;   in: the scope frame (rbcx/rbcy/rbsh/rbrad). ES = bufseg.
; ---------------------------------------------------------------------------
BQCITY: mov  al,[rbsh]
        cmp  al,BQZHOUS
        ja   @@cx               ; wound out: not worth asking
        ; how many cells the glass reaches, each way: rbrad << rbsh / 256
        mov  ax,[rbrad]
        mov  cl,[rbsh]
        shl  ax,cl
        mov  cl,8
        shr  ax,cl              ; cells (a cell is 256 units)
        inc  ax
        mov  [bqcr],ax
        mov  ax,[camx]          ; the cell we are standing in
        add  ax,BIAS
        mov  cl,8
        shr  ax,cl
        mov  [bqci],ax
        mov  ax,[camz]
        add  ax,BIAS
        mov  cl,8
        shr  ax,cl
        mov  [bqcj],ax
        mov  ax,[bqcr]          ; walk the box around it
        neg  ax
        mov  [bqcu],ax
@@cu:   mov  ax,[bqcr]
        neg  ax
        mov  [bqcv],ax
@@cv:   mov  ax,[bqci]
        add  ax,[bqcu]
        mov  [gi],ax
        mov  ax,[bqcj]
        add  ax,[bqcv]
        mov  [gj],ax
        call FAR PTR HBLDF
        cmp  word ptr [bstreet],0
        jne  @@cn               ; street, field or open ground: nothing here
        mov  ax,[gi]            ; the cell's centre, in the world
        mov  cl,8
        shl  ax,cl
        sub  ax,BIAS
        add  ax,128
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[gj]
        mov  cl,8
        shl  ax,cl
        sub  ax,BIAS
        add  ax,128
        sub  ax,[camz]
        mov  [wdz],ax
        call FAR PTR ROTXZF
        mov  cl,[rbsh]
        mov  ax,[rcx]
        sar  ax,cl
        cmp  ax,[rbrad]
        jg   @@cn
        cmp  ax,[rbradn]
        jl   @@cn
        mov  bx,[rcz]
        sar  bx,cl
        cmp  bx,[rbrad]
        jg   @@cn
        cmp  bx,[rbradn]
        jl   @@cn
        add  ax,[rbcx]
        mov  [dsx],ax
        mov  ax,[rbcy]
        sub  ax,bx              ; ahead is up the glass
        call FAR PTR UROWF
        add  di,[dsx]
        mov  al,18              ; the map's own city brown, so the scope and
        mov  es:[di],al         ; the map agree about where the town is
        mov  es:[di+1],al
        mov  es:[di+320],al
        mov  es:[di+321],al
@@cn:   inc  word ptr [bqcv]
        mov  ax,[bqcr]
        cmp  [bqcv],ax
        jle  @@cv
        inc  word ptr [bqcu]
        mov  ax,[bqcr]
        cmp  [bqcu],ax
        jle  @@cu
@@cx:   ret


; ---------------------------------------------------------------------------
;  GNDMARK - the IFF marker over a GROUND target: a square if it is ours, a
;  diamond if it is theirs, the same two shapes the jets have worn since the
;  scoreboard learned to speak them. Ground units had none at all - you
;  could only find a battery by seeing it, which at four pixels across is
;  no way to find anything.
;  Sized by range like the aircraft marker, so it shrinks honestly, and
;  clipped, so a target at the edge cannot paint over the panel.
;   in: pdx/pdy/pdz = the target in camera space (the model draw has just
;       set them), COLOR = the colour, [gmks] = 0 square / 1 diamond,
;       [gmkn] = the size numerator - a radar station is not a Shilka.
; ---------------------------------------------------------------------------
GNDMARK:
        mov  ax,[pdz]
        cmp  ax,NEARZ
        jle  @@gmx
        cmp  ax,11000           ; past this it is a speck; let it be one
        jg   @@gmx
        mov  ax,[pdx]
        mov  dx,[pdy]
        mov  cx,[pdz]
        call FAR PTR PPOINTF
        jc   @@gmx
        mov  [dsx],ax
        mov  [dsy],dx
        mov  bx,[pdz]           ; half-size = gmkn/range, clamped
        mov  ax,[gmkn]
        cwd
        idiv bx
        add  ax,3
        cmp  ax,22
        jle  @@gm1
        mov  ax,22
@@gm1:  mov  [dsac],ax
        cmp  byte ptr [gmks],0
        jne  @@gmd
        ; ---- ours: a square ----
        mov  ax,[dsx]
        sub  ax,[dsac]
        mov  [sx0],ax
        mov  [sx1],ax
        mov  ax,[dsy]
        sub  ax,[dsac]
        mov  [sy0],ax
        mov  ax,[dsy]
        add  ax,[dsac]
        mov  [sy1],ax
        call @@gml
        mov  ax,[dsx]
        add  ax,[dsac]
        mov  [sx0],ax
        mov  [sx1],ax
        mov  ax,[dsy]
        sub  ax,[dsac]
        mov  [sy0],ax
        mov  ax,[dsy]
        add  ax,[dsac]
        mov  [sy1],ax
        call @@gml
        mov  ax,[dsx]
        sub  ax,[dsac]
        mov  [sx0],ax
        mov  ax,[dsx]
        add  ax,[dsac]
        mov  [sx1],ax
        mov  ax,[dsy]
        sub  ax,[dsac]
        mov  [sy0],ax
        mov  [sy1],ax
        call @@gml
        mov  ax,[dsx]
        sub  ax,[dsac]
        mov  [sx0],ax
        mov  ax,[dsx]
        add  ax,[dsac]
        mov  [sx1],ax
        mov  ax,[dsy]
        add  ax,[dsac]
        mov  [sy0],ax
        mov  [sy1],ax
        call @@gml
        ret
@@gmd:  ; ---- theirs: a diamond ----
        mov  ax,[dsx]
        mov  [sx0],ax
        mov  ax,[dsy]
        sub  ax,[dsac]
        mov  [sy0],ax
        mov  ax,[dsx]
        add  ax,[dsac]
        mov  [sx1],ax
        mov  ax,[dsy]
        mov  [sy1],ax
        call @@gml
        mov  ax,[dsx]
        add  ax,[dsac]
        mov  [sx0],ax
        mov  ax,[dsy]
        mov  [sy0],ax
        mov  ax,[dsx]
        mov  [sx1],ax
        mov  ax,[dsy]
        add  ax,[dsac]
        mov  [sy1],ax
        call @@gml
        mov  ax,[dsx]
        mov  [sx0],ax
        mov  ax,[dsy]
        add  ax,[dsac]
        mov  [sy0],ax
        mov  ax,[dsx]
        sub  ax,[dsac]
        mov  [sx1],ax
        mov  ax,[dsy]
        mov  [sy1],ax
        call @@gml
        mov  ax,[dsx]
        sub  ax,[dsac]
        mov  [sx0],ax
        mov  ax,[dsy]
        mov  [sy0],ax
        mov  ax,[dsx]
        mov  [sx1],ax
        mov  ax,[dsy]
        sub  ax,[dsac]
        mov  [sy1],ax
        call @@gml
        ret
@@gml:  call FAR PTR CLIPLINF
        jc   @@gmn
        call FAR PTR LINEF
@@gmn:  ret
@@gmx:  ret


; ============================================================================
;  LOOKING OUT OF THE SIDE OF THE COCKPIT - the 1980s move, and the reason
;  it was the 1980s move: you cannot see your wingman, the runway you are
;  turning onto or the thing that just shot at you through a forward-facing
;  slot. The camera turns EXACTLY ninety degrees, because a painted console
;  can only be right at one angle, and the artwork does the rest.
;
;  Keys: F6 left, F7 right, and Ctrl+left / Ctrl+right the same - so the
;  hand already on the stick can do it. Pressing the same side again, or
;  the other side, comes back to the front.
;
;  The turn is done to [heading] for the length of the render and taken
;  back afterwards, which is the trick CHASESET/CHASERST already play. It
;  is refused outright while the chase, orbit or missile camera is up:
;  those own the camera, and there is no cockpit around it to look out of.
; ============================================================================
; ============================================================================
;  CPSLOADF - load CPSIDE.DAT into a page of its own, once, at startup.
;
;  THE PAGE GOES ON TOP, and that is the whole design. Everything from the
;  back buffer upwards is stacked nose to tail - buffer, resseg, sndseg,
;  scrseg - so a page opened anywhere below shoves the entire map along, and
;  that has gone wrong twice in this project (read the note beside resseg in
;  CITY.ASM). Past the scratch page nothing is stacked on anything, so this
;  one costs no other segment a paragraph.
;
;  It is also its OWN FILE rather than a third resource in CITY.DAT: that
;  file is read in one go with CX=0FFF0h and so can never exceed 64K, and
;  the front panel alone is 64000 of those bytes.
;
;  No file, or the wrong file: cpsseg stays 0, the view keys are dead and
;  the game flies on with the front panel it has always had.
; ============================================================================
; ============================================================================
;  *** TEMPORARY: WHICH PART OF THE RENDER *** (2026-08-06)
;
;  The frame markers said GREEN - it wedges inside RENDER - and RENDER is
;  fifteen calls deep, so that is a room, not an address. These split the
;  room: AL = the stage that just FINISHED, drawn as AL little blocks along
;  the top of the screen.
;
;  BLOCKS AND NOT COLOURS, on purpose. Naming a hue off a frozen screen is
;  guesswork - "amber or yellow?" - but counting six blocks is not, and the
;  count is what the answer needs to be. They sit at x=160 so they never
;  touch the stage square in the corner, and the next blit wipes them, so in
;  flight the bar just flickers at full length.
;
;  REMOVE ME with the stage markers once this is caught.
; ============================================================================
RMARKF  PROC FAR
        push es
        push di
        push cx
        mov  cx,0A000h
        mov  es,cx
        mov  di,160
        xor  ch,ch
        mov  cl,al
        jcxz @@d
@@blk:  push cx
        push di
        mov  cx,6               ; six lit pixels...
@@px:   mov  byte ptr es:[di],19
        mov  byte ptr es:[di+320],19
        inc  di
        loop @@px
        pop  di
        add  di,8               ; ...and two dark, so they can be counted
        pop  cx
        loop @@blk
@@d:    pop  cx
        pop  di
        pop  es
        ret
RMARKF  ENDP

; ============================================================================
;  HITFLSHF - the world flares red and yellow when something hits you.
;
;  It is drawn AFTER the world and BEFORE the head-up display, and both
;  halves of that matter. After the world, so the flash is what you see
;  instead of the ground; before the HUD, so the gunsight and the strips
;  ride on top and stay readable - a pilot who has just been hit is the one
;  who most needs to still see his sight. The panel and the side consoles
;  paint over it later for free, which is why this can flood all 200 rows
;  and never think about where the glass ends.
;
;  BANDS, not a wash. There is no alpha in a 256-colour buffer, so a full
;  flood would simply replace the picture; alternating filled rows let the
;  world show through between them and read as a flare rather than a curtain.
;  The stride widens as phit falls - 2, 3, 4 - so it thins out on its own,
;  and it only runs for the top three ticks of the nine: about a sixth of a
;  second, which is the "moment" that was asked for. Any longer and it stops
;  being an impact and starts being a screen effect.
;
;  Red and yellow are not picked for taste either - they are this game's own
;  two attention colours, the ones the locked target and the enemy IFF
;  already wear. ES = bufseg, set by the main loop before RENDER.
; ============================================================================
HITFLSHF PROC FAR
        cmp  byte ptr [dying],0
        jne  @@x                ; going down has a picture of its own
        mov  bx,[phit]
        cmp  bx,6
        jb   @@x
        neg  bx
        add  bx,11              ; phit 9,8,7 -> stride 2,3,4
        cld
        xor  si,si
@@row:  mov  ax,si
        xor  dx,dx
        div  bx
        or   dx,dx
        jnz  @@nx               ; not one of this pass's rows
        mov  ah,19              ; red...
        test si,2
        jz   @@c1
        mov  ah,96              ; ...and yellow, in pairs
@@c1:   push ax
        mov  ax,si
        mov  dx,320
        mul  dx
        mov  di,ax
        pop  ax
        mov  al,ah
        mov  cx,320
        rep  stosb
@@nx:   inc  si
        cmp  si,200
        jb   @@row
@@x:    ret
HITFLSHF ENDP

; ============================================================================
;  SFXLOADF - the sound bank, into the page ABOVE cpsseg.
;
;  That address is not a taste. Opening a far data page anywhere lower moves
;  the back buffer and everything stacked on it, and that has gone wrong
;  twice in this project and looked like a graphics effect both times. Past
;  cpsseg nothing is stacked on anything, which is exactly why CPSIDE.DAT
;  sits where it does - this is the same shelf, one storey up.
;
;  Optional, like CPSIDE.DAT: no file, sfxseg stays zero, SFXPLAY returns
;  without touching anything and the game runs on with its engine note.
; ============================================================================
SFXLOADF PROC FAR
        mov  ax,ds              ; the MAIN segment - see CPSLOADF for why the
        add  ax,5FFFh           ;  paragraph is never hand-typed
        and  ax,0F000h          ; scrseg...
        add  ax,2000h           ; ...past its 64K AND past cpsseg's
        mov  [sfxseg],ax
        ; ---- AND IS THERE ROOM UP THERE? This is the highest thing the game
        ; asks for - about 512K above the code, plus its own 64K - which on a
        ; 640K machine is close enough to the ceiling to be worth asking
        ; rather than assuming. The BIOS keeps the answer at 0040:0013 in
        ; kilobytes; six shifts turn that into the first paragraph past the
        ; end. Fail it and the bank simply does not load, which the rest of
        ; this routine already knows how to mean.
        push es
        mov  cx,40h
        mov  es,cx
        mov  cx,es:[13h]        ; conventional memory, KB
        pop  es
        mov  bx,cx
        mov  cl,6
        shl  bx,cl              ; ...as a segment
        mov  cx,ax
        add  cx,1000h           ; the top of the bank
        jc   @@no               ; wrapped 20 bits: there is certainly no room
        cmp  cx,bx
        ja   @@no
        mov  dx,offset SXNAME
        mov  ax,3D00h
        int  21h
        jc   @@no
        mov  bx,ax
        push ds
        mov  ax,[sfxseg]
        mov  ds,ax
        xor  dx,dx
        mov  cx,0FFF0h
        mov  ah,3Fh
        int  21h
        pop  ds
        mov  ah,3Eh
        int  21h
        push es
        mov  ax,[sfxseg]
        mov  es,ax
        cmp  word ptr es:[0],4653h  ; 'SF', little-endian
        pop  es
        je   @@ok
@@no:   mov  word ptr [sfxseg],0    ; no bank: every effect is a no-op
@@ok:   ret
SFXLOADF ENDP

CPSLOADF PROC FAR
        mov  ax,ds              ; the MAIN segment - cs in here is SYMSEG, and
                                ; typing its paragraph offset is exactly the
                                ; kind of hand-copied constant that has gone
                                ; stale twice already
        add  ax,5FFFh
        and  ax,0F000h          ; ...scrseg's own arithmetic...
        add  ax,1000h           ; ...and the page past its 64K
        mov  [cpsseg],ax
        mov  dx,offset SFNAME
        mov  ax,3D00h
        int  21h
        jc   @@no
        mov  bx,ax
        push ds
        mov  ax,[cpsseg]
        mov  ds,ax
        xor  dx,dx
        mov  cx,0FFF0h
        mov  ah,3Fh
        int  21h
        pop  ds
        mov  ah,3Eh
        int  21h
        push es
        mov  ax,[cpsseg]
        mov  es,ax
        cmp  word ptr es:[0],5043h  ; 'CP', little-endian
        jne  @@bad
        mov  ax,es:[2]
        mov  [cplo],ax
        mov  ax,es:[4]
        mov  [cpro],ax
        pop  es
        ret
@@bad:  pop  es
@@no:   mov  word ptr [cpsseg],0
        ret
CPSLOADF ENDP

SVIEWF  PROC FAR
        cmp  word ptr [cpsseg],0
        je   @@nokeys           ; no artwork loaded: the keys do nothing
        cmp  byte ptr [dying],0
        jne  @@fwd
        cmp  byte ptr [chsview],0
        jne  @@fwd
        cmp  byte ptr [tgtcam],0
        jne  @@fwd
        cmp  byte ptr [mcact],0
        jne  @@fwd              ; another camera owns the view
        mov  al,[KEYS+SC_F6]    ; ---- the four keys, all edge-triggered
        mov  bl,1
        mov  si,offset SVP6
        call SVKEY
        mov  al,[KEYS+SC_F7]
        mov  bl,2
        mov  si,offset SVP7
        call SVKEY
        cmp  byte ptr [KEYS+SC_CTL],0
        je   @@noc
        mov  al,[KEYS+SC_LF]
        mov  bl,1
        mov  si,offset SVPL
        call SVKEY
        mov  al,[KEYS+SC_RT]
        mov  bl,2
        mov  si,offset SVPR
        call SVKEY
        jmp  @@apply
@@noc:  mov  byte ptr cs:[SVPL],0 ; Ctrl let go: forget the arrows, or the
        mov  byte ptr cs:[SVPR],0 ; next Ctrl press would swallow its edge
@@apply:
        cmp  byte ptr [sview],0
        je   @@d
        ; ---- TURN THE CAMERA MATRIX, AND DECOMPOSE IT HONESTLY.
        ;
        ; The renderer has no camera matrix to hand: it is a chain, yaw in
        ; ROTXZ, then pitch in PITCH4, then roll as a rotation of the picture
        ; in APPLYROLL. Written out, that chain IS a matrix -
        ;
        ;       M = Z(roll) . X(pitch) . Y(heading)
        ;
        ; - and turning the pilot's head ninety degrees about his own spine,
        ; which in camera axes is simply Y, gives M' = Y(+-90) . M. The
        ; trouble is that M' has to go back into the chain as a new
        ; (heading, pitch, roll), and the first version of this just swapped
        ; the angles about: pitch = -bank, bank = +pitch. That is EXACT at
        ; zero pitch and increasingly wrong away from it, which is why the
        ; pilot found it fine straight and level and nonsense in a loop.
        ;
        ; Ninety degrees is special enough to fold by hand. Conjugating,
        ;       Y(90).Z(r) = X(-r).Y(90)      Y(90).X(p) = Z(p).Y(90)
        ; so, looking RIGHT,   M' = X(-r) . Z(p) . Y(h+90)
        ;     and looking LEFT, M' = X(+r) . Z(-p) . Y(h-90)
        ; Those leading two are in the WRONG ORDER for the chain, and no
        ; substitution of angles will reorder them - the product has to be
        ; multiplied out and read back as Z.X.Y. Its bottom row and its
        ; middle column are all that is needed, and both sides share them
        ; but for one sign:
        ;
        ;   m20 = -sinR.sinP     m21 = -+ sinR.cosP     m22 = cosR
        ;
        ;   heading' = heading +-90 + atan2(m20, m22)
        ;   pitch'   = atan2(m21, |(m20,m22)|)
        ;   roll'    = atan2(+- sinP, cosR.cosP)
        ;
        ; Three arctangents and a length, ONCE A FRAME - not per vertex - so
        ; the exact answer costs about what the wrong one did. SHKBRG is
        ; already a full atan2 on this segment (it is what the Shilkas take
        ; their bearings with), and the length falls out of the first angle
        ; without a square root: rotate (m20,m22) back by it and read the
        ; axis. Nothing is clamped and nothing goes singular; the view is
        ; right at any attitude, upside down included.
        mov  ax,[heading]       ; the WHOLE attitude is saved and restored -
        mov  cs:[SVSAV],ax      ; a head turn rewrites all three
        mov  ax,[pitch]
        mov  cs:[SVSAP],ax
        mov  ax,[roll]
        mov  cs:[SVSAR],ax
        ; ---- the trig of the pilot's real attitude
        mov  ax,[pitch]
        call FAR PTR SINQF
        mov  cs:[SVSP],ax
        mov  ax,[pitch]
        add  ax,64
        call FAR PTR SINQF
        mov  cs:[SVCP],ax
        mov  ax,[roll]
        call FAR PTR SINQF
        mov  cs:[SVSR],ax
        mov  ax,[roll]
        add  ax,64
        call FAR PTR SINQF
        mov  cs:[SVCR],ax
        ; ---- the three entries of M' that the decomposition needs
        mov  ax,cs:[SVSR]
        imul word ptr cs:[SVSP]
        mov  bx,256
        idiv bx
        neg  ax
        mov  cs:[SVM20],ax      ; m20 = -sinR.sinP
        mov  ax,cs:[SVSR]
        imul word ptr cs:[SVCP]
        mov  bx,256
        idiv bx
        cmp  byte ptr [sview],1
        je   @@m1
        neg  ax                 ; looking right flips this one, and only it
@@m1:   mov  cs:[SVM21],ax      ; m21 = -+ sinR.cosP
        ; ---- heading correction, and the length of (m20,m22) with it
        mov  ax,cs:[SVM20]
        mov  [wdx],ax           ; SHKBRG's inputs; the render pipeline sets
        mov  ax,cs:[SVCR]       ; these fresh before every rotation, so they
        mov  [wdz],ax           ; are scratch to borrow
        call SHKBRG
        mov  cs:[SVHC],ax       ; atan2(m20, m22)
        call FAR PTR SINQF
        imul word ptr cs:[SVM20]
        mov  bx,256
        idiv bx
        mov  cx,ax
        mov  ax,cs:[SVHC]
        add  ax,64
        call FAR PTR SINQF
        imul word ptr cs:[SVCR]
        mov  bx,256
        idiv bx
        add  ax,cx              ; m20.sin + m22.cos = |(m20,m22)|, no sqrt
        mov  [wdz],ax
        mov  ax,cs:[SVM21]
        mov  [wdx],ax
        call SHKBRG
        cmp  ax,128             ; pitch is signed, -64..64
        jb   @@p1
        sub  ax,256
@@p1:   mov  [pitch],ax
        ; ---- the new bank
        mov  ax,cs:[SVSP]
        cmp  byte ptr [sview],1
        jne  @@b1
        neg  ax                 ; looking left flips this one
@@b1:   mov  [wdx],ax
        mov  ax,cs:[SVCR]
        imul word ptr cs:[SVCP]
        mov  bx,256
        idiv bx
        mov  [wdz],ax
        call SHKBRG
        mov  [roll],ax
        ; ---- and the new heading
        mov  ax,cs:[SVSAV]
        add  ax,cs:[SVHC]
        cmp  byte ptr [sview],1
        je   @@h1
        add  ax,64
        jmp  @@h2
@@h1:   sub  ax,64
@@h2:   and  ax,255
        mov  [heading],ax
@@d:    ret
@@fwd:  mov  byte ptr [sview],0 ; the other cameras take the view back
@@nokeys:
        ret
SVIEWF  ENDP

; SVKEY - one view key. AL = its KEYS byte, BL = the side it selects,
; SI = its edge-memory byte. Pressing the side you are already on, or the
; other side, returns to the front: one key, both ways.
SVKEY:  cmp  al,cs:[si]
        je   @@r
        mov  cs:[si],al
        test al,al
        jz   @@r
        cmp  [sview],bl
        je   @@off
        mov  [sview],bl
        ret
@@off:  mov  byte ptr [sview],0
@@r:    ret

SVSAV   dw 0                    ; the pilot's real attitude, parked here for
SVSAP   dw 0                    ; the length of one render while his head is
SVSAR   dw 0                    ; turned: heading, pitch, bank
SVSP    dw 0                    ; ...and the working set of the decomposition
SVCP    dw 0
SVSR    dw 0
SVCR    dw 0
SVM20   dw 0
SVM21   dw 0
SVHC    dw 0
SVP6    db 0                    ; the four view keys, edge-triggered
SVP7    db 0
SVPL    db 0
SVPR    db 0

; SVRSTF - point the camera back down the nose. The physics step that
; follows must never see the turned heading.
SVRSTF  PROC FAR
        cmp  byte ptr [sview],0
        je   @@r
        mov  ax,cs:[SVSAV]      ; all three back: the physics step that
        mov  [heading],ax       ; follows must never see the pilot's neck
        mov  ax,cs:[SVSAP]
        mov  [pitch],ax
        mov  ax,cs:[SVSAR]
        mov  [roll],ax
@@r:    ret
SVRSTF  ENDP

; ============================================================================
;  SIDEBMPF - blit one side console over the rendered world, straight out of
;  its RLE stream. There is no decompressed copy of these pictures anywhere:
;  that is what saves them a 64K far page each.
;
;  Token byte, two bits of type and six of count; count 0 means a WORD count
;  follows, so a long run of one grey costs three bytes rather than dozens.
;      00      end of image
;      40 | n  LITERAL n - n palette bytes follow
;      80 | n  RUN n     - one palette byte follows, repeated
;      C0 | n  SKIP n    - transparent: the world shows through
;  ES = bufseg on entry.
; ============================================================================
SIDEBMPF PROC FAR
        cmp  word ptr [cpsseg],0
        je   @@r
        cld
        mov  si,[cplo]
        cmp  byte ptr [sview],1
        je   @@go
        mov  si,[cpro]
@@go:   push ds
        mov  ax,[cpsseg]
        mov  ds,ax              ; DS:SI = the stream, ES:DI = the screen
        xor  di,di
@@t:    lodsb
        or   al,al
        jz   @@d
        mov  bl,al
        and  al,3Fh
        mov  cl,al
        xor  ch,ch
        or   cl,cl
        jnz  @@n
        lodsw                   ; count 0: a word count follows the token
        mov  cx,ax
@@n:    and  bl,0C0h
        cmp  bl,0C0h
        je   @@skip
        cmp  bl,80h
        je   @@run
        rep  movsb              ; literal
        jmp  @@t
@@run:  lodsb
        rep  stosb
        jmp  @@t
@@skip: add  di,cx
        jmp  @@t
@@d:    pop  ds
@@r:    ret
SIDEBMPF ENDP

; ============================================================================
;  MMTCOL - the colour of one node's GROUND.  in: BX = node i, DX = node j
;  (both toroidal, negatives welcome). out: AL. Preserves BX and DX.
;
;  This is TERRAIN's ladder, the same five bands and the same thresholds the
;  3D mesh paints - and that is the whole point of it. The map used to carry
;  a SIXTH band, 120..167 in brown, labelled CITY. That band is GETZONE's
;  city ZONE, which is a range of heights and nothing more: it covers 28 to
;  40 per cent of the world, most of which is never built on, and the mesh
;  paints all of it plain grass. So the map disagreed with the ground under
;  the nose over a third of the world, and the disagreement came out as
;  brown mottle. Where the town really is now comes from the town.
; ============================================================================
MMTCOL: push bx
        push dx
        and  bx,63              ; HGET, written out: it lives in the main
        mov  cl,6               ; segment, where this code cannot near-call
        shl  bx,cl
        and  dx,63
        add  bx,dx
        mov  al,[HMAP+bx]
        mov  ah,14              ; water
        cmp  al,88
        jb   @@d
        mov  ah,10              ; grass
        cmp  al,168
        jb   @@d
        mov  ah,15              ; woods
        cmp  al,200
        jb   @@d
        mov  ah,13              ; rock
        cmp  al,230
        jb   @@d
        mov  ah,8               ; snow
@@d:    mov  al,ah
        pop  dx
        pop  bx
        ret

; The five colours around one node, while it is being decided. SYMSEG had no
; CS-relative data of its own until now - these five bytes are the first, and
; they are read back with the CS override TASM emits under the ASSUME, which
; is why they stand HERE, above the only code that touches them.
MMCC    db 0                    ; the node itself
MMCN    db 0                    ; ...and north, south, east, west of it
MMCS    db 0
MMCE    db 0
MMCW    db 0

; ============================================================================
;  MMAPGENF - bake the 64x64 world minimap from HMAP into the scratch page.
;  Once, at startup, right after DSGEN and after BLKTABF (it asks the block
;  table). It lives out here because it is the coldest code in the program:
;  called exactly one time, calling nothing hot, every input already in a
;  main-segment variable. The main segment was down to two bytes and the
;  aerodromes need call sites - and none of what follows costs it a byte.
;  North (+Z) up.
;
;  THREE PASSES OVER EVERY NODE, and the middle one is the reason the map
;  used to be speckled. The map paints ONE PIXEL PER NODE with a hard
;  threshold, so a single node that crossed a band on its own became a lone
;  dark dot with nothing around it - not a wood, not a hill, just the place
;  where the fractal happened to step over 168. Counted on the real 55x50
;  glass: fifty-five lone pixels of two thousand seven hundred and fifty at
;  one pixel a node. They vanish at two and four pixels a node, which is the
;  tell - a feature of the world would not care about the zoom.
;
;  So a node with no orthogonal neighbour of its own colour is not a place;
;  it is given to whichever colour holds the majority around it. That is
;  done here, once, and costs the frame nothing at all.
;
;  TWO PAGES come out of this: the map proper at offset 0, and at MMWIDE the
;  same land whose towns have been generalised into cities, for the
;  whole-world step. MMSETUP decides which one the blit walks.
; ============================================================================
MMAPGENF PROC FAR
        push es                 ; the map is baked into the scratch segment
        mov  ax,[scrseg]
        mov  es,ax
        mov  word ptr [dsx],0   ; node i (world X)
@@i:    mov  word ptr [dsy],0   ; node j (world Z)
@@j:    mov  bx,[dsx]           ; ---- the node and its four neighbours ----
        mov  dx,[dsy]
        call MMTCOL
        mov  cs:[MMCC],al
        mov  bx,[dsx]
        mov  dx,[dsy]
        inc  dx
        call MMTCOL
        mov  cs:[MMCN],al
        mov  bx,[dsx]
        mov  dx,[dsy]
        dec  dx
        call MMTCOL
        mov  cs:[MMCS],al
        mov  bx,[dsx]
        inc  bx
        mov  dx,[dsy]
        call MMTCOL
        mov  cs:[MMCE],al
        mov  bx,[dsx]
        dec  bx
        mov  dx,[dsy]
        call MMTCOL
        mov  cs:[MMCW],al
        ; ---- is it a place, or a threshold crossing? ----
        mov  al,cs:[MMCC]
        cmp  al,cs:[MMCN]
        je   @@col
        cmp  al,cs:[MMCS]
        je   @@col
        cmp  al,cs:[MMCE]
        je   @@col
        cmp  al,cs:[MMCW]
        je   @@col              ; one neighbour of our own colour is enough
        mov  al,cs:[MMCN]       ; none: the majority of the four takes it,
        cmp  al,cs:[MMCS]       ; and a colour that appears twice among four
        je   @@col              ; IS the majority
        cmp  al,cs:[MMCE]
        je   @@col
        cmp  al,cs:[MMCW]
        je   @@col
        mov  al,cs:[MMCS]
        cmp  al,cs:[MMCE]
        je   @@col
        cmp  al,cs:[MMCW]
        je   @@col
        mov  al,cs:[MMCE]
        cmp  al,cs:[MMCW]
        je   @@col
        mov  al,cs:[MMCN]       ; four different colours round one node: the
                                ; world does not do this, but the code must
                                ; still come out somewhere. North.
        ; ---- and the town, from the town ----
@@col:  mov  bx,63              ; screen row = 63 - j (north up)
        sub  bx,[dsy]
        mov  cl,6
        shl  bx,cl
        add  bx,[dsx]
        mov  es:[bx+MMWIDE],al  ; the WIDE page gets the bare land; its
                                ; towns are stamped by the pass below
        cmp  al,14              ; nobody builds on the water
        je   @@put
        push ax
        push bx
        mov  ax,[dsx]           ; a block is 8 cells, a node is 4: a block
        shr  ax,1               ; is exactly 2x2 nodes
        mov  bx,[dsy]
        shr  bx,1
        call FAR PTR BLKCTYF    ; the SAME question the buildings and the
        pop  bx                 ; scope's BQCITY ask. One town, one answer.
        pop  ax
        jnc  @@put              ; (POP leaves the carry alone)
        mov  al,18              ; the map's city brown
@@put:  mov  es:[bx],al
        inc  word ptr [dsy]
        cmp  word ptr [dsy],64
        jl   @@j
        inc  word ptr [dsx]
        cmp  word ptr [dsx],64
        jl   @@i
        ; ====================================================================
        ;  THE WIDE PAGE: conurbations, not blocks.
        ;
        ;  At the whole-world step the glass is 55 pixels across a 64-node
        ;  world, so a block - two nodes - is ONE PIXEL, and it is dropped
        ;  outright wherever the 3-for-4 sampling skips its column. A scatter
        ;  of single dark pixels is precisely what the pilot called decoration
        ;  and refused, twice. It is not noise, either: this world's towns
        ;  really are isolated blocks. BLKHASH passes three blocks in sixteen
        ;  with no spatial clustering at all, so of the fifty-five to seventy
        ;  built blocks in a world a good third stand entirely alone. Drawing
        ;  them honestly at world scale draws speckle, honestly.
        ;
        ;  So this page answers the question a map at this scale is actually
        ;  asked - WHERE ARE THE CITIES - by taking a 2x2 patch of blocks and
        ;  painting the whole patch if two or more of it are built. About
        ;  fourteen places in a world, four nodes square, which reads as a
        ;  town and not as dirt on the glass. A city on a map at 1:world is a
        ;  symbol, not a footprint; it is allowed to be bigger than the
        ;  streets under it.
        ; ====================================================================
        mov  word ptr [dsx],0   ; patch i (0..15) - four blocks square
@@ci:   mov  word ptr [dsy],0   ; patch j
@@cj:   xor  si,si              ; how many of its four blocks are built
        xor  di,di
@@cb:   mov  ax,[dsx]
        add  ax,ax
        mov  bx,di
        shr  bx,1
        add  ax,bx              ; block i = 2*patch + (di>>1)
        mov  bx,[dsy]
        add  bx,bx
        mov  cx,di
        and  cx,1
        add  bx,cx              ; block j = 2*patch + (di&1)
        call FAR PTR BLKCTYF
        jnc  @@cb1
        inc  si
@@cb1:  inc  di
        cmp  di,4
        jb   @@cb
        cmp  si,2               ; one block on its own is a hamlet, and a
        jl   @@cn               ; hamlet is not a place you navigate by
        xor  di,di              ; paint the patch: 4x4 nodes
@@cp:   mov  ax,[dsx]
        mov  cl,2
        shl  ax,cl
        mov  bx,di
        mov  cl,2
        shr  bx,cl
        add  ax,bx              ; node i
        mov  si,ax
        mov  ax,[dsy]
        mov  cl,2
        shl  ax,cl
        mov  bx,di
        and  bx,3
        add  ax,bx              ; node j
        mov  bx,63
        sub  bx,ax
        mov  cl,6
        shl  bx,cl
        add  bx,si
        cmp  byte ptr es:[bx+MMWIDE],14
        je   @@cp1              ; the shoreline stays the shoreline
        mov  byte ptr es:[bx+MMWIDE],18
@@cp1:  inc  di
        cmp  di,16
        jb   @@cp
@@cn:   inc  word ptr [dsy]
        cmp  word ptr [dsy],16
        jl   @@cj
        inc  word ptr [dsx]
        cmp  word ptr [dsx],16
        jl   @@ci
        pop  es
        ret
MMAPGENF ENDP

; ============================================================================
;  BLASTF - THE MOMENT OF DESTRUCTION, which this game never actually had.
;
;  What the wreck pool already does is BURNING: six tongues of flame on each
;  of eight tumbling pieces, a fan of glass shards for two seconds, a smoke
;  column for fifty. What it never did is EXPLODE. A hit went straight from
;  an intact aeroplane to a burning one, so the thing you actually aimed at
;  - the instant it comes apart - was over before it read. That is what the
;  pilot meant by sixteen frames.
;
;  So: a seven-second arc, laid over the burn rather than replacing it.
;
;    0.0 - 1.4s   THE FIREBALL. A ball at the breakup point, growing fast
;                 and rising as it cools - white-hot core, amber shell, then
;                 red, then the grey of smoke. Two discs, hot inside cool.
;    1.4 - 6.0s   THE COOK-OFF. Three smaller blasts, at 26, 58 and 96
;                 ticks, each on a DIFFERENT piece of the wreck - so they go
;                 off wherever that piece has fallen to by then, which is
;                 what makes it read as the wreck cooking rather than as one
;                 explosion stuttering.
;
;  It rides the pool, so it covers everything the pool covers: aeroplanes,
;  buildings, radar stations, the Shilkas. One call site, four bytes of the
;  main segment, and every kill in the game gets it.
;
;  in: DI = wreck slot, ES = bufseg. Preserves DI.
; ============================================================================
BLSEC   db 26,58,96             ; when the three cook-offs go
BLFACE  db 2,5,7                ; ...and which piece each one takes
BLAGE   dw 0
BLRW    dw 0                    ; the ball's radius, in world units
BLRY    dw 0                    ; how far it has risen
BLC0    db 0                    ; core colour
BLC1    db 0                    ; shell colour
BLCX    dw 0                    ; where it landed on the glass, and how big
BLCY    dw 0
BLRP    dw 0

BLASTF  PROC FAR
        push di
        push si
        mov  ax,[di]
        mov  cs:[BLAGE],ax
        cmp  ax,25
        jae  @@sec
        ; ---- THE FIREBALL: 40 + age*14 of radius, capped, rising age*4
        mov  si,14
        imul si
        add  ax,40
        cmp  ax,230
        jle  @@r1
        mov  ax,230
@@r1:   mov  cs:[BLRW],ax
        mov  ax,cs:[BLAGE]
        add  ax,ax
        add  ax,ax
        mov  cs:[BLRY],ax
        mov  ax,cs:[BLAGE]      ; and it cools as it goes
        mov  bl,94              ; white-hot
        mov  bh,97
        cmp  ax,5
        jb   @@c1
        mov  bl,97              ; amber
        mov  bh,19
        cmp  ax,13
        jb   @@c1
        mov  bl,19              ; red
        mov  bh,12
        cmp  ax,20
        jb   @@c1
        mov  bl,12              ; and out into smoke
        mov  bh,12
@@c1:   mov  cs:[BLC0],bl
        mov  cs:[BLC1],bh
        mov  bx,di
        add  bx,WFP             ; face 0 is where it came apart
        call BLBALL
        jmp  @@d
        ; ---- THE COOK-OFF: three of them, each on its own piece
@@sec:  xor  si,si
@@sl:   mov  bl,cs:[BLSEC+si]
        xor  bh,bh
        mov  ax,cs:[BLAGE]
        sub  ax,bx
        js   @@sn               ; not yet
        cmp  ax,14
        jae  @@sn               ; and long over
        mov  cs:[BLRY],ax       ; a small one: 24 + age*10, rising
        push ax
        mov  bx,10
        imul bx
        add  ax,24
        mov  cs:[BLRW],ax
        pop  ax
        mov  bl,94
        mov  bh,97
        cmp  ax,4
        jb   @@c2
        mov  bl,97
        mov  bh,19
        cmp  ax,9
        jb   @@c2
        mov  bl,19
        mov  bh,12
@@c2:   mov  cs:[BLC0],bl
        mov  cs:[BLC1],bh
        mov  al,cs:[BLFACE+si]  ; whichever piece this one belongs to,
        xor  ah,ah              ; wherever it has fallen to by now
        mov  bx,12
        imul bx
        add  ax,WFP
        add  ax,di
        mov  bx,ax
        push si
        call BLBALL
        pop  si
@@sn:   inc  si
        cmp  si,3
        jb   @@sl
@@d:    pop  si
        pop  di
        ret
BLASTF  ENDP

; ---- BLBALL - project the face record at BX and paint the two discs.
; Reads BLRW (world radius), BLRY (rise), BLC0/BLC1. Clobbers plenty.
BLBALL: mov  ax,[bx]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[bx+4]
        sub  ax,[camz]
        mov  [wdz],ax
        mov  ax,[bx+2]
        add  ax,cs:[BLRY]
        sub  ax,[camy]
        mov  [ctz],ax
        call FAR PTR ROTXZF
        mov  ax,[rcz]
        cmp  ax,NEARZ
        jl   @@r                ; behind us
        mov  cs:[BLRP],ax       ; keep rz: the radius needs it
        mov  dx,[ctz]
        mov  ax,[rcx]
        mov  cx,[rcz]
        call FAR PTR PPOINTF
        jc   @@r
        mov  cs:[BLCX],ax
        mov  cs:[BLCY],dx
        mov  ax,cs:[BLRW]       ; world radius -> pixels: r*FOCAL/rz
        mov  bx,FOCAL
        imul bx
        idiv word ptr cs:[BLRP]
        cmp  ax,1
        jl   @@r                ; a pixel or less: not worth the arithmetic
        cmp  ax,60
        jle  @@b1
        mov  ax,60              ; and never the whole screen
@@b1:   push ax
        mov  al,cs:[BLC1]
        mov  cs:[BLCOL],al
        pop  ax
        push ax
        call BLDISC             ; the cool shell...
        pop  ax
        shr  ax,1
        cmp  ax,1
        jl   @@r
        push ax
        mov  al,cs:[BLC0]
        mov  cs:[BLCOL],al
        pop  ax
        call BLDISC             ; ...and the hot core inside it
@@r:    ret

; ---- BLDISC - solid disc, centre BLCX/BLCY, radius AX, colour BLCOL.
; Row by row, half width = isqrt(r*r - dy*dy). No table and no trig, and the
; circle comes out round: a fireball drawn as a diamond reads as a diamond.
; ES = bufseg. Clobbers AX,BX,CX,DX,SI,DI.
BLDISC: mov  cs:[BLRAD],ax
        neg  ax
        mov  si,ax              ; si = dy, walking up from -r
@@row:  mov  ax,cs:[BLCY]
        add  ax,si
        cmp  ax,0
        jl   @@next
        cmp  ax,199
        jg   @@next
        mov  cs:[BLROW],ax
        mov  ax,si              ; dy*dy
        imul si
        mov  cx,ax
        mov  ax,cs:[BLRAD]      ; r*r
        imul ax
        sub  ax,cx
        jns  @@w1
        xor  ax,ax
@@w1:   call BLSQRT             ; ax = half width
        mov  dx,ax
        add  dx,dx
        inc  dx                 ; dx = the full span
        mov  cx,cs:[BLCX]
        sub  cx,ax              ; cx = its left end
        jns  @@l1
        add  dx,cx              ; off the left edge: shorten and square up
        xor  cx,cx
@@l1:   cmp  dx,0
        jle  @@next
        mov  ax,cx
        add  ax,dx
        cmp  ax,320
        jle  @@l2
        mov  dx,320             ; ...and off the right
        sub  dx,cx
        cmp  dx,0
        jle  @@next
@@l2:   mov  ax,cs:[BLROW]      ; di = row*320 + x, as 256 + 64
        mov  di,ax
        mov  bx,ax
        push cx
        mov  cl,8
        shl  di,cl
        mov  cl,6
        shl  bx,cl
        pop  cx
        add  di,bx
        add  di,cx
        mov  cx,dx
        mov  al,cs:[BLCOL]
        cld
        rep  stosb
@@next: inc  si
        mov  ax,cs:[BLRAD]
        cmp  si,ax
        jle  @@row
        ret

BLRAD   dw 0
BLROW   dw 0
BLCOL   db 0

; ---- BLSQRT - AX = floor(sqrt(AX)), by subtracting the odd numbers.
BLSQRT: xor  cx,cx
        mov  bx,1
@@s:    cmp  ax,bx
        jb   @@sd
        sub  ax,bx
        add  bx,2
        inc  cx
        jmp  @@s
@@sd:   mov  ax,cx
        ret

; ============================================================================
;  THE LANDING GEAR.
;
;  You cannot see your own legs from the cockpit, so this only ever runs
;  behind the chase camera (F3) - PLAYERDRAW is the one call site, and
;  PLAYERDRAW itself only runs in that view. The legs could not go in the
;  F15 model: that is 23 verts and 14 faces against the engine's 25/16 cap,
;  and a leg is sixteen and four.
;
;  NO TRIGONOMETRY HAPPENS HERE. The gear's travel is six POSES, fitted
;  outside the game and shipped as GEARM.INC - one canonical leg per step,
;  in whole model units, about its own pivot. All three legs are the same
;  leg; they differ only in where they hang, so the table is walked once per
;  leg with (x0, -1, z0) added. What the game draws is exactly the picture
;  that was fitted, and no rounding of a sine can drift it.
;
;  Each leg is a CROSS of two strut quads and a cross of two wheel quads.
;  A single quad is invisible edge-on, and the chase camera sits directly
;  astern: a wheel modelled only in the side plane read as a dark stick.
;
;  in: [gearp] 0..GEARNS-1, and the roll/pitch sines PLAYERDRAW has just
;  put in mcos/msin/pdy/pdx. ES = bufseg, DS = the main segment.
; ============================================================================
        include GEARM.INC
IF ($-GEARVT) NE (GEARNS*GEARNV*6 + GEARNF*5 + 12)
        %OUT *** GEARM.INC does not match GEARNS/GEARNV/GEARNF in DATA.INC ***
        .ERR
ENDIF
gvb     dw 0                    ; this step's base in GEARVT
glx     dw 0                    ; the leg being drawn: where it hangs...
glz     dw 0
gli     dw 0                    ; ...which leg it is, and how far through
gvi     dw 0                    ;  its vertices and its faces we are
gfi     dw 0
gmx     dw 0                    ; one vertex, in model space. NOT 'gvx': TASM
gmy     dw 0                    ;  folds case and that is the GVX array four
gmz     dw 0                    ;  lines down - the same trap osbyo carries
gy1     dw 0                    ; ...and its half-rotated y
GVX     dw GEARNV dup(0)        ; the leg in camera space
GVY     dw GEARNV dup(0)
GVZ     dw GEARNV dup(0)

GEARDRAWF PROC FAR
        mov  al,[gearp]
        or   al,al
        jz   @@x                ; stowed: nothing hangs out of the aeroplane
        xor  ah,ah
        mov  bx,ax              ; this step's table: step * GEARNV * 6
        mov  cl,5
        shl  bx,cl              ; *32
        mov  dx,bx
        add  bx,bx              ; *64
        add  bx,dx              ; *96
        mov  cs:[gvb],bx
        mov  word ptr cs:[gli],0
@@leg:  mov  bx,cs:[gli]
        add  bx,bx
        mov  ax,cs:[GEARLX+bx]
        mov  cs:[glx],ax
        mov  ax,cs:[GEARLZ+bx]
        mov  cs:[glz],ax
        ; ---- the sixteen vertices, through PLAYERDRAW's own transform ----
        mov  di,cs:[gvb]
        mov  word ptr cs:[gvi],0
@@vt:   mov  bx,di
        mov  ax,cs:[GEARVT+bx]
        add  ax,cs:[glx]
        mov  cs:[gmx],ax
        mov  ax,cs:[GEARVT+bx+2]
        dec  ax                 ; every leg hangs off the belly, y = -1
        mov  cs:[gmy],ax
        mov  ax,cs:[GEARVT+bx+4]
        add  ax,cs:[glz]
        mov  cs:[gmz],ax
        mov  ax,cs:[gmx]        ; x' = (x*mcos + y*msin)/256
        imul word ptr [mcos]
        mov  bx,ax
        mov  ax,cs:[gmy]
        imul word ptr [msin]
        add  ax,bx
        cwd
        mov  bx,256
        idiv bx
        mov  bx,cs:[gvi]
        mov  cs:[GVX+bx],ax
        mov  ax,cs:[gmx]        ; y' = (y*mcos - x*msin)/256
        imul word ptr [msin]
        mov  cx,ax
        mov  ax,cs:[gmy]
        imul word ptr [mcos]
        sub  ax,cx
        cwd
        mov  bx,256
        idiv bx
        mov  cs:[gy1],ax
        imul word ptr [pdy]     ; y'' = (y'*pc + z*ps)/256 - 15
        mov  bx,ax
        mov  ax,cs:[gmz]
        imul word ptr [pdx]
        add  ax,bx
        cwd
        mov  bx,256
        idiv bx
        sub  ax,15
        mov  bx,cs:[gvi]
        mov  cs:[GVY+bx],ax
        mov  ax,cs:[gy1]        ; z'' = (z*pc - y'*ps)/256 + 100
        imul word ptr [pdx]
        mov  cx,ax
        mov  ax,cs:[gmz]
        imul word ptr [pdy]
        sub  ax,cx
        cwd
        mov  bx,256
        idiv bx
        add  ax,100
        mov  bx,cs:[gvi]
        mov  cs:[GVZ+bx],ax
        add  di,6
        add  word ptr cs:[gvi],2
        cmp  word ptr cs:[gvi],GEARNV*2
        jb   @@vt
        ; ---- and its four faces. No sort: a leg's own quads are a cross
        ; and a wheel, they do not overlap each other, and the whole leg
        ; goes down before the airframe does. ----
        mov  word ptr cs:[gfi],0
@@fc:   mov  bx,cs:[gfi]
        mov  al,cs:[GEARFC+bx+4]
        mov  [COLOR],al
        xor  cx,cx
@@fv:   mov  bx,cs:[gfi]
        add  bx,cx
        mov  al,cs:[GEARFC+bx]
        xor  ah,ah
        add  ax,ax
        mov  bx,ax
        mov  di,cx
        add  di,di
        mov  ax,cs:[GVX+bx]
        mov  [IX+di],ax
        mov  ax,cs:[GVY+bx]
        mov  [IY+di],ax
        mov  ax,cs:[GVZ+bx]
        mov  [IZ+di],ax
        inc  cx
        cmp  cx,4
        jb   @@fv
        call FAR PTR FACEFILLF  ; clobbers everything: all our state is
                                ;  in CS variables, deliberately
        add  word ptr cs:[gfi],5
        cmp  word ptr cs:[gfi],GEARNF*5
        jb   @@fc
        inc  word ptr cs:[gli]
        cmp  word ptr cs:[gli],3
        jb   @@leg
@@x:    ret
GEARDRAWF ENDP

; ============================================================================
;  THE PILOT'S FOUR RAILS.
;
;  He had four missiles and could only ever have ONE in the air: the launch
;  gate was "the missile is not in flight", and a missile lives up to 280
;  ticks. Fifteen seconds of a fight in which the weapon does not answer,
;  and it is always the fifteen seconds you needed it.
;
;  THE BODIES DID NOT CHANGE. MSLUPD1 and MSLDRAW1 are the code that was
;  written for one missile, instruction for instruction. What is here is the
;  POOL and a pair of swaps: a slot is loaded into the eleven working words
;  the old code reads, the old code runs, and the slot is written back. The
;  homing, the proximity fuse, the detonation and the smoke are sixty-odd
;  accesses of delicate arithmetic - rewriting every one of them to carry an
;  index is how you put three new bugs in while taking one out.
;
;  It lives out HERE because the arrays are ninety-six bytes and the main
;  segment had a hundred and eleven. The walk is out here too, so the main
;  segment pays for two thunks and a call site instead of four loops.
; ============================================================================
pmact   dw NPMSL dup(0)         ; slot in flight?
pmx     dw NPMSL dup(0)         ; ...and the same eleven words, per slot
pmy     dw NPMSL dup(0)
pmz     dw NPMSL dup(0)
pmpx    dw NPMSL dup(0)
pmpy    dw NPMSL dup(0)
pmpz    dw NPMSL dup(0)
pmvx    dw NPMSL dup(0)
pmvy    dw NPMSL dup(0)
pmvz    dw NPMSL dup(0)
pmtgt   dw NPMSL dup(0FFFFh)
pmlife  dw NPMSL dup(0)

MSLLOAD:                        ; slot [msi] -> the working set
        mov  bx,[msi]
        mov  ax,cs:[pmact+bx]
        mov  [msact],al
        mov  ax,cs:[pmx+bx]
        mov  [msx],ax
        mov  ax,cs:[pmy+bx]
        mov  [msy],ax
        mov  ax,cs:[pmz+bx]
        mov  [msz],ax
        mov  ax,cs:[pmpx+bx]
        mov  [mpx],ax
        mov  ax,cs:[pmpy+bx]
        mov  [mpy],ax
        mov  ax,cs:[pmpz+bx]
        mov  [mpz],ax
        mov  ax,cs:[pmvx+bx]
        mov  [mvx],ax
        mov  ax,cs:[pmvy+bx]
        mov  [mvy],ax
        mov  ax,cs:[pmvz+bx]
        mov  [mvz],ax
        mov  ax,cs:[pmtgt+bx]
        mov  [mstgt],ax
        mov  ax,cs:[pmlife+bx]
        mov  [mlife],ax
        ret
MSLSAVE:                        ; ...and back again
        mov  bx,[msi]
        mov  al,[msact]
        xor  ah,ah
        mov  cs:[pmact+bx],ax
        mov  ax,[msx]
        mov  cs:[pmx+bx],ax
        mov  ax,[msy]
        mov  cs:[pmy+bx],ax
        mov  ax,[msz]
        mov  cs:[pmz+bx],ax
        mov  ax,[mpx]
        mov  cs:[pmpx+bx],ax
        mov  ax,[mpy]
        mov  cs:[pmpy+bx],ax
        mov  ax,[mpz]
        mov  cs:[pmpz+bx],ax
        mov  ax,[mvx]
        mov  cs:[pmvx+bx],ax
        mov  ax,[mvy]
        mov  cs:[pmvy+bx],ax
        mov  ax,[mvz]
        mov  cs:[pmvz+bx],ax
        mov  ax,[mstgt]
        mov  cs:[pmtgt+bx],ax
        mov  ax,[mlife]
        mov  cs:[pmlife+bx],ax
        ret

MSLLOADF PROC FAR               ; the swaps, for the callers at home
        call MSLLOAD
        ret
MSLLOADF ENDP
MSLSAVEF PROC FAR
        call MSLSAVE
        ret
MSLSAVEF ENDP

MSLPOOLF PROC FAR               ; one tick of every rail
        mov  word ptr [msi],0
@@s:    call MSLLOAD
        call FAR PTR MSLUPD1F
        call MSLSAVE
        add  word ptr [msi],2
        cmp  word ptr [msi],NPMSL*2
        jb   @@s
        ret
MSLPOOLF ENDP

MSLDRWPF PROC FAR               ; ...and one picture of every rail
        mov  word ptr [msi],0
@@s:    call MSLLOAD
        call FAR PTR MSLDRAW1F
        add  word ptr [msi],2
        cmp  word ptr [msi],NPMSL*2
        jb   @@s
        ret
MSLDRWPF ENDP

MSLFREEF PROC FAR               ; a free rail into [msi]. CF=1 = all four are
        mov  word ptr [msi],0   ;  in the air, which is a fine problem to have
@@s:    mov  bx,[msi]
        cmp  word ptr cs:[pmact+bx],0
        je   @@got
        add  word ptr [msi],2
        cmp  word ptr [msi],NPMSL*2
        jb   @@s
        stc
        ret
@@got:  clc
        ret
MSLFREEF ENDP

MSLCLRF PROC FAR                ; a fresh jet has four EMPTY rails, not
        xor  bx,bx              ;  whatever was still flying when it died
@@s:    mov  word ptr cs:[pmact+bx],0
        add  bx,2
        cmp  bx,NPMSL*2
        jb   @@s
        ret
MSLCLRF ENDP

; ============================================================================
;  RAMPTXT - the only instruction this game gives, and it earns its place.
;
;  A sortie now begins stopped on the concrete with the brakes set, and a
;  pilot who has never seen this screen has no way to know that. Everything
;  else here is discoverable by pushing something; a jet that does not move
;  is not, because the correct input is to UNDO a state nobody told you
;  about. So the aeroplane says it, and stops saying it the moment it stops
;  being true - which is the design rule: this is a DESCRIPTION OF THE
;  CURRENT STATE, not a tutorial playing out on a timer.
;
;  Two states only. On the brakes: what is holding her. Rolling below flying
;  speed: what makes her fly. Airborne, it is gone for good.
;
;  It lives out here because it is a caption: it draws once a frame, it is
;  nowhere near the render's hot path, and in the main segment it cost 195
;  bytes of the 232 that were free - which is exactly the thing the top of
;  NEXT.md says not to do. The strings stay home; FDRAW is reached through
;  the door the map pages already opened.
; ============================================================================
RAMPTXTF PROC FAR
        cmp  byte ptr [dying],0
        jne  @@rx
        cmp  byte ptr [onrwy],0
        je   @@rx               ; flying: she is on her own
        cmp  byte ptr [abrk],0
        je   @@roll
        mov  ax,[lasttk]        ; PARKED - and the state BLINKS, because a
        test ax,4               ;  steady caption reads as furniture and
        jz   @@r2               ;  stops being seen after the second look
        mov  byte ptr [COLOR],19
        mov  word ptr [ftx],142
        mov  word ptr [fty],70
        mov  si,offset MSGBRK
        call FAR PTR FDRAWF
@@r2:   mov  byte ptr [COLOR],PNLGRN ; GREEN, not white - white is AFPAINT,
        mov  word ptr [ftx],110      ;  which is the paint on the runway
        mov  word ptr [fty],82       ;  directly underneath, and the two sat
        mov  si,offset MSGBRK2       ;  on top of each other. Green is the
        call FAR PTR FDRAWF          ;  panel's own "a system is talking to
        ret                          ;  you" colour and nothing on the ground
                                     ;  wears it
@@roll: cmp  word ptr [vel],VRSPD-VRFLAP
        jae  @@rx               ; past VR she knows what she is doing
        mov  byte ptr [COLOR],PNLGRN
        mov  word ptr [ftx],118
        mov  word ptr [fty],82
        mov  si,offset MSGBRK3
        call FAR PTR FDRAWF
@@rx:   ret
RAMPTXTF ENDP

; ============================================================================
;  *** TEMPORARY: THE FROZEN FRAME SAYS WHERE IT STOPPED ***
;
;  A network freeze that keeps its SOUND is a main loop spinning, not a
;  crash and not memory - the interrupts are plainly alive. The picture is
;  still on the glass, so the picture can be made to answer: each stage of
;  the frame stamps a coloured square straight into VIDEO memory, and the
;  next BLIT wipes it. In flight they flicker. When it wedges, the LAST one
;  written stays - and its colour names the quarter of the frame that hung.
;
;  RED   - INPUT and the physics are done
;  GREEN - the wire is done (NETPOLL + NETAPPLY, the prime suspect)
;  AMBER - the render is done
;  WHITE - the blit is done, the frame closed cleanly
;
;  A frozen WHITE means it died early in the next frame; a frozen GREEN
;  means it died in the render; a frozen RED means it died on the wire.
;  Each door is five bytes at the call site, which is what the main segment
;  had to spare - the stage number is baked into the door, not passed.
;  REMOVE ME once it is caught.
; ============================================================================
STGMARK:                        ; AL = colour, a 8x2 block at the top left
        push es
        push di
        push cx
        mov  cx,0A000h
        mov  es,cx
        xor  di,di
        mov  cx,8
@@m:    mov  es:[di],al
        mov  es:[di+320],al
        inc  di
        loop @@m
        pop  cx
        pop  di
        pop  es
        ret
STG0F   PROC FAR
        mov  al,19
        call STGMARK
        ret
STG0F   ENDP
STG1F   PROC FAR
        mov  al,95
        call STGMARK
        ret
STG1F   ENDP
STG2F   PROC FAR
        mov  al,97
        call STGMARK
        ret
STG2F   ENDP
STG3F   PROC FAR
        mov  al,8
        call STGMARK
        ret
STG3F   ENDP

; ---- THE WINDOW GUARD ------------------------------------------------------
        PUBLIC SYMEND           ; how full this window is, in the linker map
SYMEND  label byte
IF ($-SYMBASE) GT 8176
        %OUT *** SYMSEG overflows its 8K window ***
        .ERR
ENDIF
        ORG  1FF0h              ; claim the whole window, the way SKYSEG does
        db   16 dup(0)

SYMSEG  ENDS
