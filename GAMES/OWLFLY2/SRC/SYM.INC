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
        mov  si,offset MSGT2
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


; ---- THE WINDOW GUARD ------------------------------------------------------
IF ($-SYMBASE) GT 8176
        %OUT *** SYMSEG overflows its 8K window ***
        .ERR
ENDIF
        ORG  1FF0h              ; claim the whole window, the way SKYSEG does
        db   16 dup(0)

SYMSEG  ENDS
