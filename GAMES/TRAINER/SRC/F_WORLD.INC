; ============================================================================
;  F_WORLD.INC - camera, backdrop, the airfield and its tables
; ============================================================================
; ============================================================================
CAMERA: mov  ax,[hdg]
        add  ax,[hy]            ; the head turns the view...
        and  ax,255
        mov  [heading],ax
        mov  ax,[pit]
        add  ax,[aoa]           ; ...from inside the ATTITUDE
        add  ax,[hp]
        mov  [pitch],ax
        mov  ax,[rol]
        mov  [roll],ax
        cmp  word ptr [view],0
        jne  @@fp
        mov  word ptr [roll],0
        mov  word ptr [pitch],-8
        mov  ax,[hdg]           ; the chase camera eases after the
        mov  ah,al              ;  nose: 8.8 angle, signed 16-bit
        xor  al,al              ;  wrap = free mod-256 arithmetic
        sub  ax,[chdgf]
        mov  cl,4
        sar  ax,cl
        add  [chdgf],ax
        mov  al,byte ptr [chdgf+1]
        xor  ah,ah
        mov  [heading],ax
        push ax
        call SINQ
        mov  bx,210
        imul bx
        mov  bx,256
        idiv bx
        mov  bx,[apx]
        sub  bx,ax
        mov  [camx],bx
        pop  ax
        add  ax,64
        call SINQ
        mov  bx,210
        imul bx
        mov  bx,256
        idiv bx
        mov  bx,[apz]
        sub  bx,ax
        mov  [camz],bx
        mov  ax,[apy]
        add  ax,58
        mov  [camy],ax
        ret
@@fp:   mov  ax,[apx]
        mov  [camx],ax
        mov  ax,[apz]
        mov  [camz],ax
        mov  ax,[apy]
        add  ax,6
        mov  [camy],ax
        ret

; ============================================================================
;  BACKDROP - sky above the shifted horizon, tan plain below
; ============================================================================
BACKDROP:
        mov  ax,[bufseg]
        mov  es,ax
        mov  ax,[horiz]
        add  ax,[pofs]
        cmp  ax,4
        jge  @@b1
        mov  ax,4
@@b1:   cmp  ax,196
        jle  @@b2
        mov  ax,196
@@b2:   mov  [hrow],ax
        mov  bx,320
        mul  bx                 ; DX:AX = hrow*320 (fits)
        mov  cx,ax
        shr  cx,1               ; words of sky
        mov  ax,0C0Ch           ; sky colour pair
        xor  di,di
        rep  stosw
        mov  ax,[hrow]
        mov  bx,320
        mul  bx
        mov  di,ax
        mov  ax,32000
        mov  cx,32000           ; ground: the rest of the buffer
        shr  di,1
        sub  cx,di
        shl  di,1
        mov  ax,0A0Ah           ; the tan plain
        rep  stosw
        mov  ax,[hrow]          ; the horizon itself: a dark edge
        mov  bx,320
        mul  bx
        mov  di,ax
        mov  ax,0808h
        mov  cx,320
        rep  stosw
        ret


; ============================================================================
;  GQUAD - flat ground rectangle x0,z0,x1,z1 at y=0, colour [qcol]
;  in: qx0,qz0,qx1,qz1 set by caller
; ============================================================================
GQUAD:  mov  ax,[qx0]
        mov  dx,[qz0]
        xor  bx,bx
        mov  [vwy],bx
        call PUTV0
        mov  ax,[qx1]
        mov  dx,[qz0]
        call PUTV1
        mov  ax,[qx1]
        mov  dx,[qz1]
        call PUTV2
        mov  ax,[qx0]
        mov  dx,[qz1]
        call PUTV3
        call FACEFILL
        ret
; PUTVn: world (AX=x, DX=z, [vwy]=y) -> camera space into IX/IY/IZ slot n
PUTV0:  mov  di,0
        jmp  PUTV
PUTV1:  mov  di,2
        jmp  PUTV
PUTV2:  mov  di,4
        jmp  PUTV
PUTV3:  mov  di,6
PUTV:   push di
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,dx
        sub  ax,[camz]
        mov  [wdz],ax
        call ROTXZ
        pop  di
        mov  ax,[rcx]
        mov  [IX+di],ax
        mov  ax,[rcz]
        mov  [IZ+di],ax
        mov  ax,[vwy]
        sub  ax,[camy]
        mov  [IY+di],ax
        ret

; ============================================================================
;  WORLD - pavement, markings, buildings, the radar
; ============================================================================
WORLD:  call GRID
        mov  si,offset GTAB     ; the flat world is a table of rects
@@g:    lodsw
        cmp  ax,32767
        je   @@gdone
        mov  [qx0],ax
        lodsw
        mov  [qz0],ax
        lodsw
        mov  [qx1],ax
        lodsw
        mov  [qz1],ax
        lodsw
        mov  [COLOR],al
        push si
        call GQUAD
        pop  si
        jmp  @@g
@@gdone:
        ; ---- hangars: back wall, sides, roof (open toward the apron) ----
        mov  si,offset HTAB
@@h:    lodsw
        cmp  ax,32767
        je   @@hdone
        mov  [hx0],ax
        lodsw
        mov  [hz0],ax
        lodsw
        mov  [hx1],ax
        lodsw
        mov  [hz1],ax
        lodsw
        mov  [hh],ax
        push si
        call HBOX
        pop  si
        jmp  @@h
@@hdone:
        call RADAR
        ret

; ---- GRID: the OWL FLY ground grid, ported from WORLD.INC/M3D.INC ----------
; world-aligned 1-px lines around the camera (they rotate with the view):
; each edge runs NEARCLIP -> PROJPT -> CLIPLINE -> LINE, the exact
; pipeline the wireframe city used on this same flat ground
GPITCH  equ 256
GRAD    equ 7
GRID:   ; ---- the ground, TWO STATIC SCALES: fine 512 cells around the
        ; camera, coarse 2048 cells out to 14336 - both anchored to
        ; the world, so NOTHING ever re-scales with altitude (the old
        ; tier switch jolted the whole scene mid-climb: frames 54-55
        ; of the first user recording, gpi 1024 -> 2048).
        mov  word ptr [gext],14336
        mov  word ptr [gpit],512
        mov  ax,[camx]          ; the fine board: 8x8 of 512
        and  ax,0FE00h
        sub  ax,2048
        mov  [inx0],ax
        mov  ax,[camz]
        and  ax,0FE00h
        sub  ax,2048
        mov  [inz0],ax
        mov  ax,[camx]          ; the coarse board: 14x14 of 2048
        and  ax,0F800h
        sub  ax,14336
        mov  [gsx],ax
        mov  ax,[camz]
        and  ax,0F800h
        sub  ax,14336
        mov  [gsz],ax
        mov  word ptr [gj],0
        mov  ax,[gsz]
        mov  [gwz],ax
@@orow: mov  word ptr [gi],0
        mov  ax,[gsx]
        mov  [gwx],ax
@@ocel: mov  ax,[gwx]           ; fully under the fine board? skip
        cmp  ax,[inx0]
        jl   @@odrw
        add  ax,2048
        mov  bx,[inx0]
        add  bx,4096
        cmp  ax,bx
        jg   @@odrw
        mov  ax,[gwz]
        cmp  ax,[inz0]
        jl   @@odrw
        add  ax,2048
        mov  bx,[inz0]
        add  bx,4096
        cmp  ax,bx
        jg   @@odrw
        jmp  @@onxt
@@odrw: mov  ax,[gwx]
        mov  [qx0],ax
        add  ax,2048
        mov  [qx1],ax
        mov  ax,[gwz]
        mov  [qz0],ax
        add  ax,2048
        mov  [qz1],ax
        mov  ax,[gwx]           ; world-cell parity at the 2048 scale
        mov  cl,11
        sar  ax,cl
        mov  bx,ax
        mov  ax,[gwz]
        sar  ax,cl
        add  ax,bx
        test ax,1
        jz   @@oca
        mov  byte ptr [COLOR],24
        jmp  @@ocq
@@oca:  mov  byte ptr [COLOR],10
@@ocq:  call GQUAD
@@onxt: mov  ax,[gwx]
        add  ax,2048
        mov  [gwx],ax
        inc  word ptr [gi]
        cmp  word ptr [gi],14
        jl   @@ocel
        mov  ax,[gwz]
        add  ax,2048
        mov  [gwz],ax
        inc  word ptr [gj]
        cmp  word ptr [gj],14
        jl   @@orow
        mov  word ptr [gj],0    ; the fine board paints over
        mov  ax,[inz0]
        mov  [gwz],ax
@@irow: mov  word ptr [gi],0
        mov  ax,[inx0]
        mov  [gwx],ax
@@icel: mov  ax,[gwx]
        mov  [qx0],ax
        add  ax,512
        mov  [qx1],ax
        mov  ax,[gwz]
        mov  [qz0],ax
        add  ax,512
        mov  [qz1],ax
        mov  ax,[gwx]           ; parity at the 512 scale
        mov  cl,9
        sar  ax,cl
        mov  bx,ax
        mov  ax,[gwz]
        sar  ax,cl
        add  ax,bx
        test ax,1
        jz   @@ica
        mov  byte ptr [COLOR],24
        jmp  @@icq
@@ica:  mov  byte ptr [COLOR],10
@@icq:  call GQUAD
        mov  ax,[gwx]
        add  ax,512
        mov  [gwx],ax
        inc  word ptr [gi]
        cmp  word ptr [gi],8
        jl   @@icel
        mov  ax,[gwz]
        add  ax,512
        mov  [gwz],ax
        inc  word ptr [gj]
        cmp  word ptr [gj],8
        jl   @@irow
        ret
gi      dw 0
gj      dw 0
gsh     dw 9
inx0    dw 0
inz0    dw 0

; ---- HAZE: the distance band that swallows the grid's far edge -------------
; the finite grid cannot reach the horizon in 16 bits, so the last
; degrees above its edge wear atmospheric haze: K = FOCAL*camy/gext
; rows below the horizon - exactly the angle the seam sits at.
; Painted OVER the world, so the grid emerges out of it.
HAZE:   mov  ax,[camy]
        or   ax,ax
        jle  @@no
        mov  bx,FOCAL
        imul bx
        idiv word ptr [gext]
        or   ax,ax
        jz   @@no
        cmp  ax,90
        jle  @@k1
        mov  ax,90
@@k1:   mov  bx,198             ; keep the band on the screen
        sub  bx,[hrow]
        jle  @@no
        cmp  ax,bx
        jle  @@k2
        mov  ax,bx
@@k2:   mov  [hzk],ax
        mov  ax,[hrow]
        add  ax,2               ; the dark horizon edge stays visible
        mov  bx,320
        mul  bx
        mov  di,ax
        mov  ax,[hzk]
        mov  bx,160
        imul bx
        mov  cx,ax
        mov  ax,[bufseg]
        mov  es,ax
        mov  ax,0707h
        rep  stosw
@@no:   ret
hzk     dw 0

; ---- DRAWEDGE3D + NEARCLIP + PROJ2: verbatim from OWL FLY M3D.INC ----------
; ...plus PITCHE: the engine's PROJPT knows no pitch - every polygon
; passes through PITCH4 in the rasterizer, so the edge path must pitch
; its two endpoints the same way or the grid lives at its own angle
; (found by measuring a debug-harness screenshot).
PITCHE: mov  ax,[y0]
        imul word ptr [pcos]
        mov  bx,256
        idiv bx
        mov  cx,ax
        mov  ax,[z0]
        imul word ptr [psin]
        mov  bx,256
        idiv bx
        sub  cx,ax              ; y0' = (y*pcos - z*psin)/256
        mov  ax,[y0]
        imul word ptr [psin]
        mov  bx,256
        idiv bx
        mov  di,ax
        mov  ax,[z0]
        imul word ptr [pcos]
        mov  bx,256
        idiv bx
        add  ax,di              ; z0' = (y*psin + z*pcos)/256
        mov  [z0],ax
        mov  [y0],cx
        mov  ax,[y1]
        imul word ptr [pcos]
        mov  bx,256
        idiv bx
        mov  cx,ax
        mov  ax,[z1]
        imul word ptr [psin]
        mov  bx,256
        idiv bx
        sub  cx,ax
        mov  ax,[y1]
        imul word ptr [psin]
        mov  bx,256
        idiv bx
        mov  di,ax
        mov  ax,[z1]
        imul word ptr [pcos]
        mov  bx,256
        idiv bx
        add  ax,di
        mov  [z1],ax
        mov  [y1],cx
        ret

DRAWEDGE3D:
        call PITCHE
        call NEARCLIP
        jc   @@skip
        call PROJ2
        call CLIPLINE
        jc   @@skip
        call LINE
@@skip: ret

NEARCLIP:
        mov  ax,[z0]
        cmp  ax,NEARZ
        jge  @@p0in
        mov  bx,[z1]
        cmp  bx,NEARZ
        jl   @@rej
        call CLIPP0
        clc
        ret
@@p0in: mov  bx,[z1]
        cmp  bx,NEARZ
        jge  @@both
        call CLIPP1
        clc
        ret
@@both: clc
        ret
@@rej:  stc
        ret

CLIPP0: mov  bx,[z1]
        sub  bx,[z0]
        mov  ax,NEARZ
        sub  ax,[z0]
        mov  [tnum],ax
        mov  [tden],bx
        mov  ax,[x1]
        sub  ax,[x0]
        imul word ptr [tnum]
        idiv word ptr [tden]
        add  ax,[x0]
        mov  [x0],ax
        mov  ax,[y1]
        sub  ax,[y0]
        imul word ptr [tnum]
        idiv word ptr [tden]
        add  ax,[y0]
        mov  [y0],ax
        mov  word ptr [z0],NEARZ
        ret

CLIPP1: mov  bx,[z0]
        sub  bx,[z1]
        mov  ax,NEARZ
        sub  ax,[z1]
        mov  [tnum],ax
        mov  [tden],bx
        mov  ax,[x0]
        sub  ax,[x1]
        imul word ptr [tnum]
        idiv word ptr [tden]
        add  ax,[x1]
        mov  [x1],ax
        mov  ax,[y0]
        sub  ax,[y1]
        imul word ptr [tnum]
        idiv word ptr [tden]
        add  ax,[y1]
        mov  [y1],ax
        mov  word ptr [z1],NEARZ
        ret

PROJ2:  mov  ax,[x0]
        mov  dx,[y0]
        mov  cx,[z0]
        call PROJPT
        mov  [sx0],ax
        mov  [sy0],dx
        mov  ax,[x1]
        mov  dx,[y1]
        mov  cx,[z1]
        call PROJPT
        mov  [sx1],ax
        mov  [sy1],dx
        ret

; ---- grid scratch -----------------------------------------------------------
gpit    dw 256
gext    dw 1792
gsx     dw 0
gsz     dw 0
gwx     dw 0
gwz     dw 0
x0      dw 0
y0      dw 0
z0      dw 0
x1      dw 0
y1      dw 0
z1      dw 0


; ---- HBOX: hangar/tower box hx0..hx1, hz0..hz1, height hh ------------------
; walls colour 16, roof 17; the +z face is left open (the door)
HBOX:   mov  byte ptr [COLOR],16
        ; back wall (z = hz0)
        mov  ax,[hx0]
        mov  dx,[hz0]
        xor  bx,bx
        mov  [vwy],bx
        call PUTV0
        mov  ax,[hx1]
        mov  dx,[hz0]
        call PUTV1
        mov  ax,[hx1]
        mov  dx,[hz0]
        push word ptr [vwy]
        mov  ax,[hh]
        mov  [vwy],ax
        mov  ax,[hx1]
        mov  dx,[hz0]
        call PUTV2
        mov  ax,[hx0]
        mov  dx,[hz0]
        call PUTV3
        pop  word ptr [vwy]
        call FACEFILL
        ; left wall (x = hx0)
        mov  byte ptr [COLOR],18
        xor  ax,ax
        mov  [vwy],ax
        mov  ax,[hx0]
        mov  dx,[hz0]
        call PUTV0
        mov  ax,[hx0]
        mov  dx,[hz1]
        call PUTV1
        mov  ax,[hh]
        mov  [vwy],ax
        mov  ax,[hx0]
        mov  dx,[hz1]
        call PUTV2
        mov  ax,[hx0]
        mov  dx,[hz0]
        call PUTV3
        call FACEFILL
        ; right wall (x = hx1)
        xor  ax,ax
        mov  [vwy],ax
        mov  ax,[hx1]
        mov  dx,[hz0]
        call PUTV0
        mov  ax,[hx1]
        mov  dx,[hz1]
        call PUTV1
        mov  ax,[hh]
        mov  [vwy],ax
        mov  ax,[hx1]
        mov  dx,[hz1]
        call PUTV2
        mov  ax,[hx1]
        mov  dx,[hz0]
        call PUTV3
        call FACEFILL
        ; roof
        mov  byte ptr [COLOR],17
        mov  ax,[hh]
        mov  [vwy],ax
        mov  ax,[hx0]
        mov  dx,[hz0]
        call PUTV0
        mov  ax,[hx1]
        mov  dx,[hz0]
        call PUTV1
        mov  ax,[hx1]
        mov  dx,[hz1]
        call PUTV2
        mov  ax,[hx0]
        mov  dx,[hz1]
        call PUTV3
        call FACEFILL
        ret

; ---- RADAR: the Blender-built station: static tower, spinning dish -------
RADAR:  mov  word ptr [mbuf],offset RBBUF
        mov  word ptr [mox],-700
        mov  word ptr [moy],0
        mov  word ptr [moz],-300
        mov  word ptr [myaw],0
        call MDRAW
        mov  word ptr [mbuf],offset RDBUF
        mov  word ptr [moy],0   ; the mast height is baked in the mesh
        mov  ax,[spin]
        add  ax,ax
        and  ax,255
        mov  [myaw],ax
        call MDRAW
        mov  word ptr [mbuf],offset TWBUF
        mov  word ptr [mox],600 ; the control tower, clear of the hangars
        mov  word ptr [moy],0
        mov  word ptr [moz],-520
        mov  word ptr [myaw],0
        call MDRAW
        ret

; ---- the flat world: x0,z0,x1,z1,colour ; 32767 ends ----
GTAB    dw  -3200, 240,  1800, 360, 11   ; the runway, 1250 m
        dw  -3200, -70,  1800, -10, 13   ; the taxiway
        dw  -3200, -10, -3000, 240, 13   ; west connector
        dw   1550, -10,  1800, 240, 13   ; east connector
        dw   -350,-420,   350, -70, 13   ; the apron
        dw  -3200, -42,  1780, -38, 15   ; yellow taxi centreline
        ; threshold stripes (the 23 end, east)
        dw   1720, 252,  1780, 264, 14
        dw   1720, 270,  1780, 282, 14
        dw   1720, 288,  1780, 300, 14
        dw   1720, 306,  1780, 318, 14
        dw   1720, 324,  1780, 336, 14
        dw   1720, 342,  1780, 354, 14
        ; runway number 23 (7-segment quads, read from the east)
        dw   1600, 268,  1608, 300, 14
        dw   1608, 292,  1628, 300, 14
        dw   1628, 268,  1636, 300, 14
        dw   1636, 268,  1656, 276, 14
        dw   1656, 268,  1664, 300, 14
        dw   1600, 308,  1608, 340, 14
        dw   1608, 332,  1628, 340, 14
        dw   1628, 308,  1636, 340, 14
        dw   1636, 332,  1656, 340, 14
        dw   1656, 308,  1664, 340, 14
        ; touchdown-zone bars
        dw   1420, 252,  1460, 270, 14
        dw   1420, 330,  1460, 348, 14
        dw   1260, 252,  1300, 270, 14
        dw   1260, 330,  1300, 348, 14
        ; centreline dashes
        dw  -3100, 297, -3010, 303, 14
        dw  -2880, 297, -2790, 303, 14
        dw  -2660, 297, -2570, 303, 14
        dw  -2440, 297, -2350, 303, 14
        dw  -2220, 297, -2130, 303, 14
        dw  -2000, 297, -1910, 303, 14
        dw  -1780, 297, -1690, 303, 14
        dw  -1560, 297, -1470, 303, 14
        dw  -1340, 297, -1250, 303, 14
        dw  -1120, 297, -1030, 303, 14
        dw   -900, 297,  -810, 303, 14
        dw   -680, 297,  -590, 303, 14
        dw   -460, 297,  -370, 303, 14
        dw   -240, 297,  -150, 303, 14
        dw    -20, 297,    70, 303, 14
        dw    200, 297,   290, 303, 14
        dw    420, 297,   510, 303, 14
        dw    640, 297,   730, 303, 14
        dw    860, 297,   950, 303, 14
        dw  32767
; ---- boxes: x0,z0,x1,z1,height ; 32767 ends --------------------------------
HTAB    dw  -300,-400,-100,-300, 60  ; hangar west
        dw    50,-400, 250,-300, 60  ; hangar east
        dw  32767
