; RASTER.INC - part of WIRE CITY (included from CITY.ASM)
; ============================================================================
;  CLIPNEAR: Sutherland-Hodgman clip of the face IX/IY/IZ[0..3] to Z >= NEARZ.
;  Output polygon -> OX/OY/OZ[0..NPOLY-1] (3..5 verts). Walks the 4 edges;
;  keeps in-front vertices and, on each in/out crossing, inserts the edge's
;  intersection with the Z=NEARZ plane (APPENDISECT). This is what lets a
;  building you fly past get sliced cleanly instead of popping out of view.
; ============================================================================
; PITCH4 - rotate the 4 face vertices IY/IZ about the camera X axis by the
; current pitch. One shared spot: every filled/stroked polygon passes here,
; so the whole world pitches for loops and dives. Clobbers AX,BX,CX,DI.
PITCH4: push si
        xor  si,si
@@l:    mov  ax,[IY+si]
        imul word ptr [pcos]
        mov  bx,256
        idiv bx
        mov  cx,ax              ; y*pcos/256
        mov  ax,[IZ+si]
        imul word ptr [psin]
        mov  bx,256
        idiv bx
        sub  cx,ax              ; y' = (y*pcos - z*psin)/256
        mov  ax,[IY+si]
        imul word ptr [psin]
        mov  bx,256
        idiv bx
        mov  di,ax              ; y*psin/256
        mov  ax,[IZ+si]
        imul word ptr [pcos]
        mov  bx,256
        idiv bx
        add  ax,di              ; z' = (y*psin + z*pcos)/256
        mov  [IZ+si],ax
        mov  [IY+si],cx
        add  si,2
        cmp  si,8
        jl   @@l
        pop  si
        ret

CLIPNEAR:
        call PITCH4             ; apply pitch before the near-plane clip
        mov  word ptr [oc],0
        mov  word ptr [ci],0
@@cl:   mov  ax,[ci]
        add  ax,2
        cmp  ax,8
        jl   @@nw
        xor  ax,ax
@@nw:   mov  [ni],ax
        ; curIn -> dl, nextIn -> dh
        mov  si,[ci]
        mov  ax,[IZ+si]
        mov  dl,0
        cmp  ax,NEARZ
        jl   @@a
        mov  dl,1
@@a:    mov  si,[ni]
        mov  ax,[IZ+si]
        mov  dh,0
        cmp  ax,NEARZ
        jl   @@b
        mov  dh,1
@@b:    test dl,dl
        jz   @@nocur
        mov  si,[ci]
        call APPENDV
@@nocur:
        cmp  dl,dh
        je   @@nois
        call APPENDISECT
@@nois:
        mov  ax,[ci]
        add  ax,2
        cmp  ax,8
        jge  @@end
        mov  [ci],ax
        jmp  @@cl
@@end:  mov  ax,[oc]
        mov  [NPOLY],ax
        ret

; append vertex IX/IY/IZ[si] to O*[oc]; oc++
APPENDV:
        mov  di,[oc]
        add  di,di
        mov  ax,[IX+si]
        mov  [OX+di],ax
        mov  ax,[IY+si]
        mov  [OY+di],ax
        mov  ax,[IZ+si]
        mov  [OZ+di],ax
        inc  word ptr [oc]
        ret

; append intersection of edge ci->ni with plane Z=NEARZ
APPENDISECT:
        mov  si,[ci]
        mov  di,[ni]
        mov  ax,NEARZ
        sub  ax,[IZ+si]
        mov  [tnum],ax          ; num = NEARZ - z0
        mov  ax,[IZ+di]
        sub  ax,[IZ+si]
        mov  [tden],ax          ; den = z1 - z0  (nonzero)
        mov  ax,[IX+di]
        sub  ax,[IX+si]
        imul word ptr [tnum]
        idiv word ptr [tden]
        add  ax,[IX+si]
        push ax                 ; ox
        mov  ax,[IY+di]
        sub  ax,[IY+si]
        imul word ptr [tnum]
        idiv word ptr [tden]
        add  ax,[IY+si]
        push ax                 ; oy
        mov  di,[oc]
        add  di,di
        pop  ax
        mov  [OY+di],ax
        pop  ax
        mov  [OX+di],ax
        mov  word ptr [OZ+di],NEARZ
        inc  word ptr [oc]
        ret

; project OX/OY/OZ[0..NPOLY-1] -> PX/PY
PROJPOLY:
        mov  word ptr [pk],0
@@p:    mov  si,[pk]
        add  si,si
        mov  ax,[OX+si]
        mov  dx,[OY+si]
        mov  cx,[OZ+si]
        call PROJPT
        mov  si,[pk]
        add  si,si
        mov  [PX+si],ax
        mov  [PY+si],dx
        inc  word ptr [pk]
        mov  ax,[pk]
        cmp  ax,[NPOLY]
        jl   @@p
        ret

; ============================================================================
;  SCANPOLY: solid-fill convex polygon PX/PY[0..NPOLY-1] in COLOR (ES=bufseg).
;  Scanline fill: for each y in [minY,maxY] (clamped to screen), intersect the
;  y line with every edge (half-open lo<=y<hi so each scanline hits exactly 2
;  edges), take min/max x, clamp to [0,319], and rep-stosb the span. The
;  fills (drawn far->near) are what hide buildings behind nearer ones.
; ============================================================================
SCANPOLY:
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
        mov  al,[COLOR]
        rep  stosb
@@nextY:
        mov  ax,[scy]
        inc  ax
        mov  [scy],ax
        cmp  ax,[scymax]
        jle  @@yloop
@@done: ret

; ============================================================================
;  STROKEPOLY: outline polygon PX/PY[0..NPOLY-1] with COLOR  (ES=bufseg)
; ============================================================================
STROKEPOLY:
        mov  word ptr [pk],0
@@s:    mov  si,[pk]
        add  si,si
        mov  ax,[PX+si]
        mov  [sx0],ax
        mov  ax,[PY+si]
        mov  [sy0],ax
        mov  ax,[pk]
        inc  ax
        cmp  ax,[NPOLY]
        jl   @@nj
        xor  ax,ax
@@nj:   add  ax,ax
        mov  si,ax
        mov  ax,[PX+si]
        mov  [sx1],ax
        mov  ax,[PY+si]
        mov  [sy1],ax
        call CLIPLINE
        jc   @@sk
        call LINE
@@sk:   inc  word ptr [pk]
        mov  ax,[pk]
        cmp  ax,[NPOLY]
        jl   @@s
        ret

; ============================================================================
;  FACEFILL / FACESTROKE: clip current IX/IY/IZ face, then fill / stroke
; ============================================================================
FACEFILL:
        call CLIPNEAR
        mov  ax,[NPOLY]
        cmp  ax,3
        jl   @@x
        call PROJPOLY
        call SCANPOLY
@@x:    ret

FACESTROKE:
        call CLIPNEAR
        mov  ax,[NPOLY]
        cmp  ax,2
        jl   @@x
        call PROJPOLY
        call STROKEPOLY
@@x:    ret

; ============================================================================
;  SCREEN LINE CLIPPING (Cohen-Sutherland), rect 0..319 x 0..199
;  in/out: sx0,sy0,sx1,sy1   ; CF=1 if the line is fully rejected
; ============================================================================
OUTCODE:                        ; in: AX=x, BX=y -> AL=code
        push cx
        xor  cl,cl
        cmp  ax,0
        jge  @@c1
        or   cl,1
        jmp  @@c2
@@c1:   cmp  ax,319
        jle  @@c2
        or   cl,2
@@c2:   cmp  bx,0
        jge  @@c3
        or   cl,8
        jmp  @@c4
@@c3:   cmp  bx,199
        jle  @@c4
        or   cl,4
@@c4:   mov  al,cl
        pop  cx
        ret

CLIPLINE:
        mov  ax,[sx0]
        mov  bx,[sy0]
        call OUTCODE
        mov  [oc0],al
        mov  ax,[sx1]
        mov  bx,[sy1]
        call OUTCODE
        mov  [oc1],al
@@iter: mov  al,[oc0]
        or   al,[oc1]
        jnz  @@nacc
        clc
        ret
@@nacc: mov  al,[oc0]
        and  al,[oc1]
        jz   @@clip
        stc
        ret
@@clip: mov  al,[oc0]
        test al,al
        jnz  @@use0
        mov  al,[oc1]
@@use0: mov  [ocsel],al
        mov  ax,[sx1]
        sub  ax,[sx0]
        mov  [cdx],ax
        mov  ax,[sy1]
        sub  ax,[sy0]
        mov  [cdy],ax
        mov  al,[ocsel]
        test al,8
        jnz  @@top
        test al,4
        jnz  @@bot
        test al,2
        jnz  @@right
        ; LEFT: x=0
        mov  ax,[sx0]
        neg  ax
        imul word ptr [cdy]
        idiv word ptr [cdx]
        add  ax,[sy0]
        mov  [ny],ax
        mov  word ptr [nx],0
        jmp  @@apply
@@right:                        ; x=319
        mov  ax,319
        sub  ax,[sx0]
        imul word ptr [cdy]
        idiv word ptr [cdx]
        add  ax,[sy0]
        mov  [ny],ax
        mov  word ptr [nx],319
        jmp  @@apply
@@top:                          ; y=0
        mov  ax,[sy0]
        neg  ax
        imul word ptr [cdx]
        idiv word ptr [cdy]
        add  ax,[sx0]
        mov  [nx],ax
        mov  word ptr [ny],0
        jmp  @@apply
@@bot:                          ; y=199
        mov  ax,199
        sub  ax,[sy0]
        imul word ptr [cdx]
        idiv word ptr [cdy]
        add  ax,[sx0]
        mov  [nx],ax
        mov  word ptr [ny],199
@@apply:
        mov  al,[oc0]
        test al,al
        jz   @@setp1
        mov  ax,[nx]
        mov  [sx0],ax
        mov  ax,[ny]
        mov  [sy0],ax
        mov  ax,[sx0]
        mov  bx,[sy0]
        call OUTCODE
        mov  [oc0],al
        jmp  @@iter
@@setp1:
        mov  ax,[nx]
        mov  [sx1],ax
        mov  ax,[ny]
        mov  [sy1],ax
        mov  ax,[sx1]
        mov  bx,[sy1]
        call OUTCODE
        mov  [oc1],al
        jmp  @@iter

; ============================================================================
;  LINE (Bresenham)   in: sx0,sy0,sx1,sy1, COLOR   ; ES=bufseg
; ============================================================================
LINE:
        mov  ax,[sx1]
        sub  ax,[sx0]
        mov  word ptr [lsx],1
        jns  @@dxp
        neg  ax
        mov  word ptr [lsx],-1
@@dxp:  mov  [ldx],ax
        mov  ax,[sy1]
        sub  ax,[sy0]
        mov  word ptr [lsy],1
        jns  @@dyp
        neg  ax
        mov  word ptr [lsy],-1
@@dyp:  neg  ax
        mov  [ldy],ax
        mov  ax,[ldx]
        add  ax,[ldy]
        mov  [lerr],ax
        mov  ax,[sx0]
        mov  [lx],ax
        mov  ax,[sy0]
        mov  [ly],ax
@@loop:
        mov  ax,[lx]
        mov  bx,[ly]
        call PUTPIXEL
        mov  ax,[lx]
        cmp  ax,[sx1]
        jne  @@cont
        mov  ax,[ly]
        cmp  ax,[sy1]
        jne  @@cont
        ret
@@cont: mov  ax,[lerr]
        add  ax,ax
        mov  bx,ax              ; e2
        cmp  bx,[ldy]
        jl   @@sx
        mov  ax,[lerr]
        add  ax,[ldy]
        mov  [lerr],ax
        mov  ax,[lx]
        add  ax,[lsx]
        mov  [lx],ax
@@sx:   cmp  bx,[ldx]
        jg   @@sy
        mov  ax,[lerr]
        add  ax,[ldx]
        mov  [lerr],ax
        mov  ax,[ly]
        add  ax,[lsy]
        mov  [ly],ax
@@sy:   jmp  @@loop

; ============================================================================
;  PUTPIXEL  in: AX=x, BX=y, COLOR   ; ES=bufseg   (preserves registers)
; ============================================================================
PUTPIXEL:
        push ax
        push bx
        push cx
        push dx
        push di
        mov  di,bx
        mov  cl,8
        shl  di,cl              ; y*256
        mov  dx,bx
        mov  cl,6
        shl  dx,cl              ; y*64
        add  di,dx
        add  di,ax              ; +x
        mov  dl,[COLOR]
        mov  es:[di],dl
        pop  di
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; ============================================================================
;  CROSSHAIR in screen center  ; ES=bufseg
; ============================================================================
; the gunsight: the bar through the centre stays LEVEL with the horizon
; (rotates against the bank), the small tick points at the sky - works
; inverted too. When the real horizon leaves the glass (|pitch| >= 16 or
; bank > 45 deg) a standby horizon appears where the real one is, clamped
; near the ring. Hidden in the cinema views. Uses the LERPED trig: called
; from inside RENDER, so it is as smooth as the world.
CROSS:  cmp  byte ptr [chsview],0
        jne  @@no
        cmp  byte ptr [tgtcam],0
        jne  @@no
        cmp  byte ptr [dying],0
        jne  @@no
        cmp  byte ptr [mcact],0
        jne  @@no
        cmp  byte ptr [mslcam],0 ; armed: a little amber M on the glass
        je   @@noarm
        mov  byte ptr [COLOR],97
        mov  word ptr [ftx],8
        mov  word ptr [fty],14
        mov  si,offset MSGM2
        call FDRAW
@@noarm:
        mov  byte ptr [COLOR],8
        ; ---- levelled bar: two segments along (rcos,rsin) ----
        mov  ax,[rcos]
        mov  bx,4
        imul bx
        mov  bx,256
        idiv bx
        mov  [dsx],ax           ; inner end
        mov  ax,[rsin]
        mov  bx,4
        imul bx
        mov  bx,256
        idiv bx
        mov  [dsy],ax
        mov  ax,[rcos]
        mov  bx,14
        imul bx
        mov  bx,256
        idiv bx
        mov  [ctx],ax           ; outer end
        mov  ax,[rsin]
        mov  bx,14
        imul bx
        mov  bx,256
        idiv bx
        mov  [cty],ax
        mov  ax,160             ; right wing of the bar
        add  ax,[dsx]
        mov  [sx0],ax
        mov  ax,100
        add  ax,[dsy]
        mov  [sy0],ax
        mov  ax,160
        add  ax,[ctx]
        mov  [sx1],ax
        mov  ax,100
        add  ax,[cty]
        mov  [sy1],ax
        call CLIPLINE
        jc   @@l2
        call LINE
@@l2:   mov  ax,160             ; left wing
        sub  ax,[dsx]
        mov  [sx0],ax
        mov  ax,100
        sub  ax,[dsy]
        mov  [sy0],ax
        mov  ax,160
        sub  ax,[ctx]
        mov  [sx1],ax
        mov  ax,100
        sub  ax,[cty]
        mov  [sy1],ax
        call CLIPLINE
        jc   @@l3
        call LINE
@@l3:   ; the sky tick: perp=(-rsin,rcos), the sky always sits at -perp
        mov  ax,[rsin]
        mov  bx,6
        imul bx
        mov  bx,256
        idiv bx
        mov  [dsx],ax
        mov  ax,[rcos]
        mov  bx,6
        imul bx
        mov  bx,256
        idiv bx
        neg  ax
        mov  [dsy],ax
        mov  ax,[rsin]
        mov  bx,10
        imul bx
        mov  bx,256
        idiv bx
        mov  [ctx],ax
        mov  ax,[rcos]
        mov  bx,10
        imul bx
        mov  bx,256
        idiv bx
        neg  ax
        mov  [cty],ax
        mov  ax,160
        add  ax,[dsx]
        mov  [sx0],ax
        mov  ax,100
        add  ax,[dsy]
        mov  [sy0],ax
        mov  ax,160
        add  ax,[ctx]
        mov  [sx1],ax
        mov  ax,100
        add  ax,[cty]
        mov  [sy1],ax
        call CLIPLINE
        jc   @@sb
        call LINE
@@sb:   ; ---- standby horizon: only when the real one left the glass ----
        mov  ax,[pitch]
        or   ax,ax
        jns  @@p1
        neg  ax
@@p1:   cmp  ax,16
        jge  @@show
        mov  ax,[roll]          ; bank = distance from wings-level
        cmp  ax,128
        jbe  @@b1
        neg  ax
        add  ax,256
@@b1:   cmp  ax,32
        jl   @@no
@@show: mov  ax,[pofs]          ; where the real horizon is, clamped in
        mov  bx,6
        cwd
        idiv bx
        cmp  ax,26
        jle  @@c1
        mov  ax,26
@@c1:   cmp  ax,-26
        jge  @@c2
        mov  ax,-26
@@c2:   mov  [dsac],ax
        mov  ax,[rsin]          ; centre = (160,100) + perp*offset
        imul word ptr [dsac]
        mov  bx,256
        idiv bx
        neg  ax
        add  ax,160
        mov  [ctx],ax
        mov  ax,[rcos]
        imul word ptr [dsac]
        mov  bx,256
        idiv bx
        add  ax,100
        mov  [cty],ax
        mov  ax,[rcos]          ; +-30 along the horizon direction
        mov  bx,30
        imul bx
        mov  bx,256
        idiv bx
        mov  [dsx],ax
        mov  ax,[rsin]
        mov  bx,30
        imul bx
        mov  bx,256
        idiv bx
        mov  [dsy],ax
        mov  ax,[ctx]
        sub  ax,[dsx]
        mov  [sx0],ax
        mov  ax,[cty]
        sub  ax,[dsy]
        mov  [sy0],ax
        mov  ax,[ctx]
        add  ax,[dsx]
        mov  [sx1],ax
        mov  ax,[cty]
        add  ax,[dsy]
        mov  [sy1],ax
        call CLIPLINE
        jc   @@no
        call LINE
@@no:   ret
