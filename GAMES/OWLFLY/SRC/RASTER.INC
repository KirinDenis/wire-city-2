; RASTER.INC - part of WIRE CITY (included from CITY.ASM)
; The rasterizer (PITCH4, CLIPNEAR, PROJPOLY, SCANPOLY, STROKEPOLY,
; FACEFILL, CLIPLINE, LINE, PUTPIXEL) moved to ENGINE\E_RAST.INC
; (shared with the EXAMPLES). This file keeps the gunsight.

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
