; SKY.INC - part of WIRE CITY (included from CITY.ASM, AFTER "CODE ENDS")
; ============================================================================
;  THE NEWTON SKY, living in its own segment.
;
;  This is the first tenant of the land the EXE conversion opened up:
;  everything here - the blue-noise matrix, the ramp tables, the four
;  cloud coats, ninety-six cloud positions and all the code that walks
;  them - sits OUTSIDE the crowded main 64K segment, whose BSS ceiling
;  had about 1.8K of stack headroom left. Only ~90 bytes of hot
;  variables stayed behind in DATA.INC where DS can reach them fast.
;
;  Segmentation contract:
;    DS = SS = the main CODE segment (the game's one-segment world).
;    CS = SKYSEG while any code here runs; TASM's ASSUME emits the CS
;         override on every table access automatically. The one manual
;         override is TSKY via [bp+si] (BP-based defaults to SS).
;    ES = bufseg on entry to SKYFILL and WCLOUDF (the callers' contract,
;         same as RENDER's).
;  Entry points (all FAR): SKYBAKE once at startup after rseed is
;  seeded; SKYFILL from CLEARBUF each frame; WCLOUDF from RENDER after
;  the stars and before the terrain, so a cloud behind a ridge is
;  painted over, as it should be.
;
;  The sky itself is NEWTON's, ported with its geometry intact because
;  the conventions matched exactly: OWLFLY's (rsin,rcos) screen rotate
;  is NEWTON's ROTPT, OWLFLY's ROTXZ is NEWTON's WCAM. The horizon
;  pivot is derived per frame in CLEARBUF: the horizon line sits at
;  v = pofs of the band rotation, so its on-screen anchor is
;  (160 - pofs*sin/256, horiz + pofs*cos/256).
; ============================================================================

SKYSEG  SEGMENT PARA PUBLIC 'CODE'
        ASSUME  CS:SKYSEG, DS:CODE, ES:NOTHING, SS:CODE

; ---- the tables: all CS-relative, none of them in the main segment --------
; They stand BEFORE the code: TASM will only emit the CS override on a
; symbol it has already seen (a forward reference "needs override").
; BNOISE: 16x16 blue noise. An ORDERED matrix (Bayer) is built for
; sampling along the screen axes: rotate the sampling and its careful
; low-discrepancy order collapses into dirt. Blue noise has no
; directional structure to lose - the texture rides the bank without
; paying for it in artefacts. Void-and-cluster, sigma 1.9, frozen.
BNOISE  db 13,128,250,153,173,238,52,165,61,194,38,122,157,113,246,66
        db 90,222,55,5,81,199,142,120,0,150,29,255,17,97,233,200
        db 41,161,188,136,94,34,68,219,98,189,175,109,221,85,60,178
        db 119,24,209,108,230,183,248,25,86,239,145,76,210,49,171,6
        db 227,75,245,48,14,154,112,170,126,58,71,8,140,196,36,149
        db 101,141,166,125,64,213,43,202,228,47,235,207,23,164,131,253
        db 56,201,32,88,180,146,78,9,135,37,186,107,124,243,84,114
        db 12,234,191,3,223,251,103,163,220,16,159,177,99,45,73,218
        db 172,96,69,134,117,21,59,197,115,148,254,91,33,229,193,26
        db 143,40,160,242,208,35,176,89,217,130,80,63,1,211,156,65
        db 184,216,110,82,50,151,241,70,18,54,206,240,174,138,15,127
        db 237,57,7,198,168,100,123,185,44,195,31,152,118,192,106,95
        db 20,121,247,139,27,226,4,144,111,232,167,10,87,53,252,225
        db 79,155,181,92,62,205,77,249,179,22,102,137,236,74,39,203
        db 169,46,30,231,190,132,42,158,93,129,224,67,215,162,28,187
        db 105,212,72,116,19,104,214,11,244,83,204,51,182,2,133,147
TSKY    db 256 dup(0)           ; sky: tile row per distance, standing
SBASE   db 200 dup(0)           ; per-height-above-horizon: sky shade
SFRAC   db 200 dup(0)           ; per-height-above-horizon: sky fraction
CSHW    db 256 dup(0)           ; the four coats: width per row...
CSHS    db 256 dup(0)           ; ...and start column, 64 rows each
CLX     dw 96 dup(0)            ; the ninety-six clouds: east, north,
CLZ     dw 96 dup(0)            ; cloudbase, size
CLH     dw 96 dup(0)
CLM     dw 96 dup(0)
VLD     dw 24 dup(0)            ; this frame's visible list: distance,
VLU     dw 24 dup(0)            ; sideways reach, instance
VLI     db 24 dup(0)

; ---- the far doors ---------------------------------------------------------
SKYBAKE PROC FAR
        call XBAKE
        ret
SKYBAKE ENDP

SKYFILL PROC FAR
        call BGND
        ret
SKYFILL ENDP

WCLOUDF PROC FAR
        call WCLOUD
        ret
WCLOUDF ENDP

; ---- BGND: sky and ground, split by the horizon LINE -----------------------
; One span each side of the line per row, the sky shaded by the
; PERPENDICULAR distance to it - so the haze ramp rotates with the
; world instead of with the screen. The ground side is two flat
; greens: the terrain mesh repaints nearly all of it every frame.
BGND:   mov  word ptr [mrow],0
        mov  word ptr [rowb],0
@@mr:   mov  ax,[mrow]
        sub  ax,[hcur]
        imul word ptr [cosr]
        mov  bx,256
        idiv bx
        mov  [fmv],ax           ; f at the pivot column of this row
        mov  bx,[sinr]
        or   bx,bx
        jge  @@ab
        neg  bx
@@ab:   cmp  bx,8               ; level: the row is all one thing
        jb   @@one
        ; banked: guard the crossing divide. x - cx0 = fmv*256/sinr;
        ; any crossing ON the glass has |x-cx0| < 512, so |fmv| >=
        ; 2*|sinr| means the row never crosses on screen - and skipping
        ; the divide is also what keeps IDIV from faulting when the
        ; horizon is pitched far off the top or bottom.
        mov  ax,[fmv]
        or   ax,ax
        jge  @@fa
        neg  ax
@@fa:   add  bx,bx              ; bx = 2*|sinr|
        cmp  ax,bx
        jae  @@one
        jmp  @@split
@@one:  mov  word ptr [spa],0
        mov  word ptr [spl],320
        mov  al,0
        cmp  word ptr [fmv],0
        jl   @@ws
        mov  al,1
@@ws:   mov  [sptype],al
        call FSP
        jmp  @@nr
@@split:mov  ax,[fmv]           ; the line crosses this row at
        mov  cx,256             ; x = cx0 + f*256/sin r
        imul cx
        idiv word ptr [sinr]
        add  ax,[cx0]
        mov  bx,ax
        or   bx,bx
        jge  @@x1
        xor  bx,bx
@@x1:   cmp  bx,320
        jle  @@x2
        mov  bx,320
@@x2:   cmp  word ptr [sinr],0
        jl   @@neg
        mov  word ptr [spa],0   ; sin>0: f falls as x grows - ground left
        mov  [spl],bx
        mov  byte ptr [sptype],1
        push bx
        call FSP
        pop  bx
        mov  [spa],bx
        mov  ax,320
        sub  ax,bx
        mov  [spl],ax
        mov  byte ptr [sptype],0
        call FSP
        jmp  @@nr
@@neg:  mov  word ptr [spa],0   ; sin<0: sky on the left instead
        mov  [spl],bx
        mov  byte ptr [sptype],0
        push bx
        call FSP
        pop  bx
        mov  [spa],bx
        mov  ax,320
        sub  ax,bx
        mov  [spl],ax
        mov  byte ptr [sptype],1
        call FSP
@@nr:   add  word ptr [rowb],320
        inc  word ptr [mrow]
        cmp  word ptr [mrow],200
        jb   @@mr
        ret

; ---- FSP: fill span [spa..spa+spl) of row [mrow], sky or ground ------------
; One shade per span, taken at its centre - the retro compromise.
FSP:    cmp  word ptr [spl],0
        jle  @@fr
        mov  ax,[spl]
        shr  ax,1
        add  ax,[spa]
        sub  ax,[cx0]
        imul word ptr [sinr]
        mov  bx,256
        idiv bx
        neg  ax                 ; f = fmv - (x-cx0)*sin/256
        add  ax,[fmv]
        or   ax,ax
        jge  @@f1
        neg  ax
@@f1:   cmp  ax,199
        jbe  @@f2
        mov  ax,199
@@f2:   mov  bx,ax
        cmp  byte ptr [sptype],0
        jne  @@fg
        mov  al,[SBASE+bx]      ; the sky ramp, by height above the line
        mov  [dbase],al
        mov  al,[SFRAC+bx]
        mov  [dfrac],al
        jmp  @@ff
@@fg:   mov  al,10              ; the settled green of the plain
        cmp  bx,16              ; the first rows past the line keep the
        jae  @@fb               ; dark far-ground band the city wore
        mov  al,28
@@fb:   mov  di,[rowb]
        add  di,[spa]
        mov  cx,[spl]
        jcxz @@fr
        rep  stosb
        ret
@@ff:   mov  di,[rowb]
        add  di,[spa]
        mov  cx,[spl]
        cmp  byte ptr [wdith],0
        je   @@fast
        mov  ax,[mrow]          ; banked: the slow, honest grain
        mov  bx,[spa]
        call WSTART
        call DFILLW
        ret
@@fast: mov  ax,[mrow]
        call MKPATT
        call DFILL
@@fr:   ret

; ---- MKPATT: cut the row's 16-pixel dither pattern (wings level) -----------
; The anchor (tile row and phase) is cached per screen row: several
; spans in a row ask for the same one. PATT itself is rebuilt each
; call - the shade in dbase/dfrac changes from span to span.
MKPATT: push bx
        push cx
        push si
        cmp  ax,[pmrow]
        je   @@have
        mov  [pmrow],ax
        sub  ax,[hcur]          ; wings level, the world frame IS the
        mov  ah,0               ; screen frame; the tile row comes from
        mov  si,ax              ; the same table the banked path reads
        mov  al,[TSKY+si]
        xor  ah,ah
        mov  [pf0],ax
        mov  ax,[cx0]
        neg  ax
        and  ax,15
        mov  [pt0],ax
@@have: mov  ax,[pt0]
        mov  [pti],ax
        xor  bx,bx
@@m:    mov  ax,[pti]
        and  ax,15
        add  ax,[pf0]
        mov  si,ax
        mov  ah,[BNOISE+si]
        mov  al,[dbase]
        cmp  [dfrac],ah
        jbe  @@m1
        inc  al
@@m1:   mov  [PATT+bx],al
        inc  word ptr [pti]
        inc  bx
        cmp  bx,16
        jb   @@m
        pop  si
        pop  cx
        pop  bx
        ret

; ---- DFILL: fill CX pixels at ES:DI with PATT, phased by screen x ----------
; The hot loop of the common case reads PATT in the MAIN segment via
; DS - no segment prefix anywhere inside.
DFILL:  jcxz @@z                ; CX=0 must mean zero, not 65536
        push bx
        mov  bx,di
        and  bx,15              ; the tile is 16 wide, and 320 is
@@f:    mov  al,[PATT+bx]       ; still a multiple of it
        stosb
        inc  bx
        and  bx,15
        loop @@f
        pop  bx
@@z:    ret

; ---- DFILLW: the same span, but the GRAIN BELONGS TO THE WORLD ------------
; No integer map can rotate a dither: it preserves the pixel lattice,
; so only a per-pixel walk of fractional world coordinates does it -
; t and f as 8.8 accumulators, stepping by (cos, -sin). The wrap at
; 65536 is harmless: all we ever read are bits 8..9.
;  in: ES:DI dest, CX count, wt8/wf8 the span start, dbase/dfrac shade
DFILLW: jcxz @@z
        push bx
        push dx
        push si
        push bp
        mov  bx,[wt8]
        mov  dx,[wf8]
        mov  bp,offset TSKY
@@p:    mov  al,dh
        xor  ah,ah
        mov  si,ax
        mov  al,cs:[bp+si]      ; TSKY lives HERE, but BP-based
        mov  ah,bh              ; addressing defaults to SS - the one
        and  ah,15              ; override ASSUME cannot place for us
        add  al,ah
        xor  ah,ah
        mov  si,ax
        mov  ah,[BNOISE+si]
        mov  al,[dbase]
        cmp  [dfrac],ah
        jbe  @@l1
        inc  al
@@l1:   stosb
        add  bx,[cosr]          ; one pixel east in the WORLD frame
        sub  dx,[sinr]
        loop @@p
        pop  bp
        pop  si
        pop  dx
        pop  bx
@@z:    ret

; ---- WSTART: world coords of (BX = x, AX = y) into wt8/wf8, 8.8 ----------
WSTART: push cx
        push dx
        push si
        sub  ax,[hcur]
        mov  si,ax              ; si = dy
        sub  bx,[cx0]           ; bx = dx
        mov  ax,bx
        imul word ptr [cosr]
        mov  cx,ax
        mov  ax,si
        imul word ptr [sinr]
        add  ax,cx
        mov  [wt8],ax           ; t*256 = dx*cos + dy*sin
        mov  ax,si
        imul word ptr [cosr]
        mov  cx,ax
        mov  ax,bx
        imul word ptr [sinr]
        sub  cx,ax
        mov  [wf8],cx           ; f*256 = dy*cos - dx*sin
        pop  si
        pop  dx
        pop  cx
        ret

; ---- ROWAD: AX = row -> AX = row*320 --------------------------------------
ROWAD:  push bx
        push cx
        mov  bx,ax
        mov  cl,8
        shl  ax,cl
        mov  cl,6
        shl  bx,cl
        add  ax,bx
        pop  cx
        pop  bx
        ret

; ---- ROTPT: horizon-frame (AX=t, BX=f) -> screen (AX=x, DX=y) -------------
ROTPT:  push bx
        push si
        mov  si,ax              ; si = t
        imul word ptr [cosr]
        mov  cx,256
        idiv cx
        mov  di,ax              ; t*cos
        mov  ax,bx
        imul word ptr [sinr]
        mov  cx,256
        idiv cx
        sub  di,ax              ; x = cx0 + (t*cos - f*sin)/256
        add  di,[cx0]
        mov  ax,si
        imul word ptr [sinr]
        mov  cx,256
        idiv cx
        mov  si,ax              ; t*sin
        mov  ax,bx
        imul word ptr [cosr]
        mov  cx,256
        idiv cx
        add  ax,si              ; y = hcur + (t*sin + f*cos)/256
        add  ax,[hcur]
        mov  dx,ax
        mov  ax,di
        pop  si
        pop  bx
        ret

; ---- CLSEG: a span drawn ALONG the horizon, not along a screen row -------
; The clouds live at a height above the horizon and stretch sideways
; along it, so in a bank their spans are tilted lines. The screen
; address walks by a DDA - one add and a carry, never a multiply.
; A pixel that lands off the glass is skipped, not clipped.
;  in: AX=x0, DX=y0 (screen), CX=length, dbase/dfrac shade, cfv the f
CLSEG:  or   cx,cx
        jle  @@z
        push bp
        push cx                 ; CL is needed for the shifts below
        mov  [cxv],ax           ; the screen walk: integers plus an 8.8
        mov  [cyv],dx           ; error each, so nothing overflows at
        mov  word ptr [cxe],0   ; x = 300 the way a packed 8.8 would
        mov  word ptr [cye],0
        mov  cl,8
        mov  ax,[cosr]
        mov  bx,ax
        sar  bx,cl
        mov  [dxi],bx
        and  ax,255
        shl  ax,cl
        mov  [dxf],ax
        mov  ax,[sinr]
        mov  bx,ax
        sar  bx,cl
        mov  [dyi],bx
        and  ax,255
        shl  ax,cl
        mov  [dyf],ax
        mov  ax,[cyv]
        call ROWAD
        mov  [crb],ax           ; the row base moves by +-320, never by
        mov  bx,[cfv]           ; a multiply. f is CONSTANT along the
        and  bx,255             ; segment - it is a line parallel to the
        mov  al,[TSKY+bx]       ; horizon - so its tile row is too
        xor  ah,ah
        mov  [ctrow],ax
        xor  bx,bx              ; bx = the walk's column counter
        pop  cx
@@p:    mov  ax,[cxv]
        or   ax,ax
        jl   @@nx
        cmp  ax,319
        jg   @@nx
        mov  dx,[cyv]
        or   dx,dx
        jl   @@nx
        cmp  dx,199
        jg   @@nx
        mov  di,[crb]
        add  di,ax
        mov  ax,bx
        and  ax,15
        add  ax,[ctrow]
        mov  si,ax
        mov  ah,[BNOISE+si]
        mov  al,[dbase]
        cmp  [dfrac],ah
        jbe  @@p1
        inc  al
@@p1:   mov  es:[di],al
        mov  si,[cdup]          ; and a twin one pixel ACROSS the line:
        or   si,si              ; neighbouring segments sit 1 px apart
        jz   @@nx               ; perpendicular, and a rotated lattice
        cmp  si,320             ; drops pixels between them - this is
        je   @@d1               ; what closes the gaps
        cmp  word ptr [cxv],319
        jge  @@nx
@@d1:   add  si,di
        mov  es:[si],al
@@nx:   inc  bx
        mov  ax,[dxi]
        add  [cxv],ax
        mov  ax,[dxf]
        add  [cxe],ax
        jnc  @@y
        inc  word ptr [cxv]
@@y:    mov  ax,[dyi]
        or   ax,ax
        jz   @@y1
        add  [cyv],ax
        mov  dx,320
        cmp  ax,0
        jg   @@y0
        neg  dx
@@y0:   add  [crb],dx
@@y1:   mov  ax,[dyf]
        add  [cye],ax
        jnc  @@y2
        inc  word ptr [cyv]
        add  word ptr [crb],320
@@y2:   loop @@p
        pop  bp
@@z:    ret

; ---- WCAM2: world delta (wdx2 east, wdz2 north) -> cldu, cldd -------------
; OWLFLY's ROTXZ with NEWTON's 32-bit middles: d = dz*cos + dx*sin,
; u = dx*cos - dz*sin, exact for any 16-bit delta.
WCAM2:  mov  ax,[wdz2]
        imul word ptr [hcos]
        mov  bx,ax
        mov  cx,dx
        mov  ax,[wdx2]
        imul word ptr [hsin]
        add  bx,ax
        adc  cx,dx
        mov  al,bh
        mov  ah,cl
        mov  [cldd],ax
        mov  ax,[wdx2]
        imul word ptr [hcos]
        mov  bx,ax
        mov  cx,dx
        mov  ax,[wdz2]
        imul word ptr [hsin]
        sub  bx,ax
        sbb  cx,dx
        mov  al,bh
        mov  ah,cl
        mov  [cldu],ax
        ret

; ---- WCLOUD: the weather lives in the WORLD -------------------------------
; Ninety-six clouds stand on the torus at random spots, heights and
; sizes, wearing one of four silhouettes baked fresh each launch -
; fly past them, turn and find different ones, climb and look DOWN
; on them. Far to near; the terrain pass afterwards buries whatever
; hides behind a ridge.
WCLOUD: mov  ax,[sinr]          ; the twin-pixel direction, once
        or   ax,ax
        jge  @@s1
        neg  ax
@@s1:   mov  bx,[cosr]
        or   bx,bx
        jge  @@s2
        neg  bx
@@s2:   mov  word ptr [cdup],320
        cmp  ax,bx
        jle  @@s3
        mov  word ptr [cdup],1
@@s3:   ; ---- cull and collect ----
        xor  si,si              ; instance index
        mov  word ptr [qcn],0
@@cull: mov  ax,si
        add  ax,ax
        mov  di,ax
        mov  ax,[CLX+di]
        sub  ax,[camx]
        mov  [wdx2],ax
        mov  ax,[CLZ+di]
        sub  ax,[camz]
        mov  [wdz2],ax
        push si
        call WCAM2
        pop  si
        mov  ax,[cldd]
        cmp  ax,250
        jl   @@next
        cmp  ax,11500
        jg   @@next
        mov  bx,[cldu]
        or   bx,bx
        jns  @@c1
        neg  bx
@@c1:   mov  cx,ax
        add  cx,cx
        cmp  bx,cx              ; more than two widths off the bow
        jg   @@next
        mov  bx,[qcn]
        cmp  bx,20              ; the visible list has walls
        jae  @@next
        add  bx,bx
        mov  [VLD+bx],ax        ; keep its distance...
        mov  ax,[cldu]
        mov  [VLU+bx],ax        ; ...and its sideways reach
        shr  bx,1
        mov  ax,si
        mov  [VLI+bx],al        ; ...and who it is
        inc  word ptr [qcn]
@@next: inc  si
        cmp  si,96
        jb   @@cull
        ; ---- draw, farthest first ----
@@pick: mov  word ptr [qcb],-1
        mov  bx,-1
        xor  si,si
@@fmax: cmp  si,[qcn]
        jae  @@fdn
        mov  di,si
        add  di,di
        mov  ax,[VLD+di]
        cmp  ax,bx
        jle  @@fnx
        mov  bx,ax
        mov  [qcb],si
@@fnx:  inc  si
        jmp  @@fmax
@@fdn:  cmp  word ptr [qcb],-1
        je   @@done
        mov  si,[qcb]
        add  si,si
        mov  ax,[VLD+si]
        mov  [qcd],ax           ; this cloud's d
        mov  ax,[VLU+si]
        mov  [qcu],ax           ; and u
        mov  word ptr [VLD+si],-1
        shr  si,1
        mov  bl,[VLI+si]
        xor  bh,bh
        mov  [qci],bx
        call CDRAW
        jmp  @@pick
@@done: ret

; ---- CDRAW: one cloud, rows of CLSEG under the shape tables ---------------
CDRAW:  mov  bx,[qci]
        add  bx,bx
        mov  di,bx
        mov  ax,[qcu]           ; t of the centre: 220*u/d
        mov  cx,220
        imul cx
        idiv word ptr [qcd]
        mov  [qct],ax
        mov  ax,[camy]          ; the camera height in world units
        sub  ax,[CLH+di]        ; minus the cloud's base
        mov  cx,220
        imul cx
        idiv word ptr [qcd]
        mov  [qcf],ax           ; f of the cloud base
        cmp  ax,-950
        jl   @@out
        cmp  ax,1000
        jg   @@out
        mov  ax,[CLM+di]        ; scale: 352*size/d, 8.8 of table cols
        mov  cx,352
        imul cx
        idiv word ptr [qcd]
        cmp  ax,8
        jge  @@sc1
        mov  ax,8
@@sc1:  cmp  ax,640
        jle  @@sc2
        mov  ax,640
@@sc2:  mov  [qcs],ax
        mov  bx,ax              ; rows on screen: 64*scale/512 (clouds
        mov  cl,3               ; squat: half as tall as wide)
        shr  bx,cl
        cmp  bx,2
        jge  @@h1
        mov  bx,2
@@h1:   cmp  bx,80
        jle  @@h2
        mov  bx,80
@@h2:   mov  [qch],bx
        mov  ax,16384           ; source step per screen row, 8.8
        cwd
        idiv bx
        mov  [qcp],ax
        mov  word ptr [qcr],0   ; the source walker
        mov  word ptr [qcw],0   ; the screen row walker
        mov  ax,[qci]
        mov  cl,6
        shl  ax,cl              ; shape base = shape*64 (shape = index&3
        and  ax,255             ; folds all the clouds onto four coats)
        mov  [qcb],ax
@@row:  mov  ax,[qcr]
        mov  al,ah
        xor  ah,ah              ; source row 0..63
        add  ax,[qcb]
        mov  si,ax
        mov  al,[CSHW+si]
        or   al,al
        jz   @@nr
        xor  ah,ah
        mov  cx,[qcs]
        imul cx
        mov  al,ah              ; width in px: W*scale/256
        mov  ah,dl
        or   ax,ax
        jnz  @@w1
        mov  ax,1
@@w1:   mov  [qcv],ax
        mov  al,[CSHS+si]
        xor  ah,ah
        sub  ax,70              ; the silhouette's own centre
        mov  cx,[qcs]
        imul cx
        mov  al,ah
        mov  ah,dl
        add  ax,[qct]           ; t of this row's left edge
        mov  bx,[qcf]
        sub  bx,[qcw]           ; the rows stack UP from the base
        mov  [cfv],bx           ; CLSEG's tile row rides f
        push ax
        mov  ax,[qcr]           ; the cloud light: haze-blue at the
        mov  al,ah              ; base, sunlit white up top
        xor  ah,ah
        mov  cx,6
        imul cx
        add  ax,40
        cmp  ax,511
        jbe  @@sh1
        mov  ax,511
@@sh1:  mov  [dfrac],al
        mov  al,ah
        add  al,SKYZ+4
        mov  [dbase],al
        pop  ax
        mov  bx,[cfv]
        call ROTPT
        mov  cx,[qcv]
        call CLSEG
@@nr:   mov  ax,[qcp]
        add  [qcr],ax
        inc  word ptr [qcw]
        mov  ax,[qcw]
        cmp  ax,[qch]
        jl   @@row
@@out:  ret

; ---- XBAKE: sky ramp + the cloud wardrobe + the weather map ---------------
; TSKY: tile row per |f| - the sky's rows never move. SBASE/SFRAC: the
; five-step blue ramp by height above the horizon, dithering between
; neighbours. Four cloud coats cut by a random walk, then ninety-six
; clouds scattered over the whole torus.
XBAKE:  xor  si,si              ; the sky's tile rows
@@ts:   mov  ax,si
        and  ax,15
        mov  cl,4
        shl  ax,cl
        mov  [TSKY+si],al
        inc  si
        cmp  si,256
        jb   @@ts
        xor  si,si              ; sky ramp by height above the horizon
@@sk:   mov  ax,si
        add  ax,ax
        add  ax,ax
        add  ax,si              ; ax = f*5, split 8.8
        cmp  ah,4
        jb   @@s2
        mov  dl,SKYZ            ; past the ramp: zenith deep
        xor  al,al
        jmp  @@s3
@@s2:   or   al,al
        jnz  @@s4
        mov  dl,SKYZ+4
        sub  dl,ah
        jmp  @@s3
@@s4:   mov  dl,SKYZ+3
        sub  dl,ah
        neg  al
@@s3:   mov  [SBASE+si],dl
        mov  [SFRAC+si],al
        inc  si
        cmp  si,200
        jb   @@sk
        ; ---- four cloud coats, cut fresh every launch ----
        xor  bp,bp              ; bp = shape base in the tables
@@sh:   xor  bx,bx              ; the width walk
        mov  dx,55              ; the start walk begins near centre
        xor  si,si
@@cw:   call RNDS
        mov  al,ah
        xor  ah,ah
        and  ax,7
        sub  ax,2               ; drift +3/-2: clouds like to grow
        add  bx,ax
        cmp  si,40
        jb   @@w1
        sub  bx,3               ; ...and taper at the top
@@w1:   or   bx,bx
        jns  @@w2
        xor  bx,bx
@@w2:   cmp  bx,105
        jle  @@w3
        mov  bx,105
@@w3:   call RNDS
        mov  al,ah
        xor  ah,ah
        and  ax,3
        dec  ax
        add  dx,ax
        cmp  dx,15
        jge  @@w4
        mov  dx,15
@@w4:   cmp  dx,110
        jle  @@w5
        mov  dx,110
@@w5:   mov  di,bp
        add  di,si
        mov  [CSHW+di],bl
        mov  [CSHS+di],dl
        inc  si
        cmp  si,64
        jb   @@cw
        add  bp,64
        cmp  bp,256
        jb   @@sh
        ; ---- and NINETY-SIX of them, scattered over the whole torus ----
        xor  si,si
@@ci:   call RNDS
        mov  [CLX+si],ax        ; anywhere at all: the world wraps
        call RNDS
        mov  [CLZ+si],ax
        call RNDS
        and  ax,1023
        add  ax,400
        mov  [CLH+si],ax        ; cloudbase 400..1423: real cumulus
        call RNDS               ; heights, or the sky hugs the horizon
        and  ax,1023
        add  ax,500
        mov  [CLM+si],ax        ; size 500..1523: cumulus are BIG
        add  si,2
        cmp  si,192
        jb   @@ci
        ret

; ---- RNDS: the engine's RND16, restated here ------------------------------
; A near CALL cannot cross segments; ten bytes of LCG can. Same
; constants, same [rseed] in DS: one shared random stream.
RNDS:   push bx
        push dx
        mov  ax,[rseed]
        mov  bx,25173
        mul  bx
        add  ax,13849
        mov  [rseed],ax
        pop  dx
        pop  bx
        ret

SKYSEG  ENDS
