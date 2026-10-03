; TERRAIN.INC - part of WIRE CITY (included from OWLFLY3.ASM)
; The world generator (RND16, HGET/HPUT, DSGEN, GETH, GETZONE, WORLDH)
; lives in ENGINE\E_MATH.INC + ENGINE\E_TERR.INC - shared with the
; standalone examples in EXAMPLES\. This file keeps the game-side parts:
; the per-frame 3D mesh cache, the terrain rasterizer and the minimap.

; ---- BRDGEN: the front line - 17 jagged z offsets around the map centre ---
BRDGEN: xor  si,si
.b:    call RND16
        mov  bl,ah              ; high byte (the TERRA resonance lesson)
        xor  bh,bh
        sub  bx,128
        mov  ax,bx
        mov  bx,6
        imul bx                 ; +/-768
        mov  [bordz+si],ax
        add  si,2
        cmp  si,17*2
        jb   .b
        ret

; (MMAPGEN went out to SYMSEG as MMAPGENF on 2026-08-05. It bakes the
;  minimap ONCE, at startup, out of HMAP and into the scratch segment - it
;  calls nothing hot, it is never called again, and the main segment was
;  down to TWO bytes with an aerodrome to build. The cheapest bytes are
;  always the coldest ones.)

; ============================================================================
;  MINIMAP - blit the baked map to the bottom-right corner (rows 123..186)
;  with a white frame, and stamp the plane: white 2x2 blip + red course tick.
;  ES=bufseg. Our shared debug eye on what DSGEN actually built.
; ============================================================================
; ROW320 - DI = AX*320 (row start offset). Clobbers BX.
ROW320: mov  di,ax
        mov  bx,ax
        mov  cl,8
        shl  di,cl              ; *256
        mov  cl,6
        shl  bx,cl              ; *64
        add  di,bx
        ret

MINIMAP:
        cld
        ; white frame so the map does not blend into the terrain
        mov  ax,[mapt]
        dec  ax
        call ROW320
        add  di,251             ; top edge
        mov  al,8
        mov  cx,66
        rep  stosb
        mov  ax,[mapt]
        add  ax,64
        call ROW320
        add  di,251             ; bottom edge
        mov  al,8
        mov  cx,66
        rep  stosb
        mov  ax,[mapt]
        dec  ax
        call ROW320
        add  di,251             ; side edges
        mov  al,8
        mov  cx,66
.fr:   mov  [es:di],al
        mov  [es:di+65],al
        add  di,320
        loop .fr
        ; blit the baked map (it lives in the far scratch segment)
        mov  ax,[mapt]
        call ROW320
        add  di,252
        push ds
        mov  ax,[scrseg]
        mov  ds,ax
        xor  si,si
        mov  cx,64
.row:  push cx
        mov  cx,32
        rep  movsw              ; one 64-byte map row
        pop  cx
        add  di,320-64
        loop .row
        pop  ds
        ; the front line: a jagged red stroke across the map
        xor  cx,cx
.bd:   mov  bx,cx
        shr  bx,1
        shr  bx,1               ; band = column/4
        add  bx,bx
        mov  ax,[bordz+bx]
        add  ax,24576+BIAS
        push cx
        mov  cl,10
        shr  ax,cl              ; node j
        and  ax,63
        mov  bx,63
        sub  bx,ax              ; map row (north up)
        mov  ax,bx
        add  ax,[mapt]
        call ROW320
        pop  cx
        add  di,252
        add  di,cx
        mov  al,19
        mov  [es:di],al
        inc  cx
        cmp  cx,64
        jb   .bd
        ; plane blip at node (camx,camz)
        mov  ax,[camx]
        add  ax,BIAS
        mov  cl,2
        shr  ax,cl
        mov  cl,8
        shr  ax,cl
        and  ax,63
        mov  bx,ax              ; col = node x
        mov  ax,[camz]
        add  ax,BIAS
        mov  cl,2
        shr  ax,cl
        mov  cl,8
        shr  ax,cl
        and  ax,63
        mov  dx,63
        sub  dx,ax              ; row = 63 - node z
        mov  ax,dx
        add  ax,[mapt]
        push bx
        call ROW320             ; di = row*320
        pop  bx
        add  di,252             ; map column
        add  di,bx
        mov  al,8               ; white 2x2 blip
        mov  [es:di],al
        mov  [es:di+1],al
        mov  [es:di+320],al
        mov  [es:di+321],al
        ; heading tick: 3 map pixels ahead of the blip
        mov  ax,[hsin]
        add  ax,ax
        add  ax,[hsin]          ; hsin*3
        mov  bx,256
        cwd
        idiv bx                 ; dxn = -3..3
        mov  si,ax
        mov  ax,[hcos]
        add  ax,ax
        add  ax,[hcos]
        cwd
        idiv bx                 ; dzn
        mov  cx,320             ; +Z is up on the map -> minus one row per node
        imul cx                 ; DX:AX = dzn*320
        mov  cx,ax
        mov  ax,si
        sub  ax,cx              ; pixel = dxn - dzn*320
        add  di,ax
        mov  al,19              ; red course tick
        mov  [es:di],al
        ret

; ============================================================================
;  TERRH - bilinear terrain height at world (camx,camz).  out: AX (>=0).
;  Node grid pitch is 1024; fractions are taken in 1/64 of a node.
;  NB: WORLDH's imul clobbers DX, so BX/DX are re-set before every HGET.
; ============================================================================
TERRH:  mov  ax,[camx]
        add  ax,BIAS            ; unsigned world coordinate
        mov  bx,ax
        mov  cl,2
        shr  bx,cl
        mov  cl,8
        shr  bx,cl              ; node x
        mov  cl,4
        shr  ax,cl
        and  ax,63              ; fx = fraction across the node, 0..63
        mov  [tta],bx           ; node x
        mov  [dsx],ax           ; fx
        mov  ax,[camz]
        add  ax,BIAS
        mov  dx,ax
        mov  cl,2
        shr  dx,cl
        mov  cl,8
        shr  dx,cl              ; node z
        mov  cl,4
        shr  ax,cl
        and  ax,63              ; fz
        mov  [ttb],dx
        mov  [dsy],ax
        ; world heights of the 4 surrounding nodes
        mov  bx,[tta]
        mov  dx,[ttb]
        call HGET
        xor  ah,ah
        call WORLDH
        mov  [x0],ax            ; h00 (reuse edge scratch vars)
        mov  bx,[tta]
        inc  bx
        mov  dx,[ttb]
        call HGET
        xor  ah,ah
        call WORLDH
        mov  [x1],ax            ; h10
        mov  bx,[tta]
        mov  dx,[ttb]
        inc  dx
        call HGET
        xor  ah,ah
        call WORLDH
        mov  [y0],ax            ; h01
        mov  bx,[tta]
        inc  bx
        mov  dx,[ttb]
        inc  dx
        call HGET
        xor  ah,ah
        call WORLDH
        mov  [y1],ax            ; h11
        ; ha = h00 + (h10-h00)*fx/64 ; hb = h01 + (h11-h01)*fx/64
        mov  ax,[x1]
        sub  ax,[x0]
        imul word [dsx]
        mov  bx,64
        idiv bx
        add  ax,[x0]
        mov  [x0],ax            ; ha
        mov  ax,[y1]
        sub  ax,[y0]
        imul word [dsx]
        mov  bx,64
        idiv bx
        add  ax,[y0]            ; hb
        ; h = ha + (hb-ha)*fz/64
        sub  ax,[x0]
        imul word [dsy]
        mov  bx,64
        idiv bx
        add  ax,[x0]
        ret

; (MINIMAP2 moved to UISEG as MINIMAP2F 2026-07-27: the stack guard
;  fired when the radar grew its SA symbology, and the map only plots
;  pixels - no near calls home - so it pays rent in the far segment)
