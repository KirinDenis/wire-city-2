; TERRAIN.INC - part of WIRE CITY (included from CITY.ASM)
; The world generator (RND16, HGET/HPUT, DSGEN, GETH, GETZONE, WORLDH)
; lives in ENGINE\E_MATH.INC + ENGINE\E_TERR.INC - shared with the
; standalone examples in EXAMPLES\. This file keeps the game-side parts:
; the per-frame 3D mesh cache, the terrain rasterizer and the minimap.

; ============================================================================
;  TERRPREP - once per frame: rotate all NSIDE^2 nodes around the camera into
;  camera space (TRX/TRZ) and cache their heights (TWH world, TH raw).
; ============================================================================
TERRPREP:
        mov  ax,[camx]
        add  ax,BIAS
        mov  cl,2
        shr  ax,cl
        mov  cl,8
        shr  ax,cl              ; (camx+BIAS)>>10 = camera node x
        mov  [tnx],ax
        mov  ax,[camz]
        add  ax,BIAS
        mov  cl,2
        shr  ax,cl
        mov  cl,8
        shr  ax,cl
        mov  [tnz],ax
        mov  word ptr [tta],0
@@al:   mov  word ptr [ttb],0
@@bl:   ; world position of node (tnx+tta-NR, tnz+ttb-NR)
        mov  ax,[tnx]
        add  ax,[tta]
        sub  ax,NR
        mov  bx,ax              ; node x (for HGET, wraps)
        mov  cl,2
        shl  ax,cl
        mov  cl,8
        shl  ax,cl              ; node*1024
        sub  ax,BIAS
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[tnz]
        add  ax,[ttb]
        sub  ax,NR
        mov  dx,ax              ; node z
        mov  cl,2
        shl  ax,cl
        mov  cl,8
        shl  ax,cl
        sub  ax,BIAS
        sub  ax,[camz]
        mov  [wdz],ax
        push bx
        push dx
        call ROTXZ
        pop  dx
        pop  bx
        ; cache index si = tta*41 + ttb   (41 = 32 + 8 + 1)
        mov  ax,[tta]
        mov  cl,5
        shl  ax,cl              ; *32
        push bx
        mov  bx,[tta]
        mov  cl,3
        shl  bx,cl              ; *8
        add  ax,bx
        pop  bx
        add  ax,[tta]           ; *41
        add  ax,[ttb]
        mov  si,ax
        add  si,si              ; word offset
        mov  ax,[rcx]
        mov  [TRX+si],ax
        mov  ax,[rcz]
        mov  [TRZ+si],ax
        call HGET               ; AL = raw H of node (BX,DX preserved inside)
        mov  di,si
        shr  di,1
        mov  [TH+di],al
        xor  ah,ah
        push si
        call WORLDH
        pop  si
        mov  [TWH+si],ax
        inc  word ptr [ttb]
        cmp  word ptr [ttb],NSIDE
        jl   @@bl
        inc  word ptr [tta]
        cmp  word ptr [tta],NSIDE
        jl   @@al
        ret

; ============================================================================
;  TERRAIN - draw the 3D landscape: 1600 heightmap quads far -> near (TORD).
;  Colours by the max raw H of the quad corners: water, grass, woods, rock,
;  snow. Near quads also get a grid stroke. Buildings draw after this.
; ============================================================================
TERRAIN:
        mov  word ptr [tidx],0
@@tl:   mov  si,[tidx]
        add  si,si
        mov  al,[TORD+si]       ; di (signed)
        cbw
        add  ax,NR              ; a = di+NR
        mov  [tta],ax
        mov  al,[TORD+si+1]
        cbw
        add  ax,NR
        mov  [ttb],ax
        ; base cache index = a*41+b   (41 = 32 + 8 + 1)
        mov  ax,[tta]
        mov  cl,5
        shl  ax,cl              ; *32
        mov  bx,[tta]
        mov  cl,3
        shl  bx,cl              ; *8
        add  ax,bx
        add  ax,[tta]           ; *41
        add  ax,[ttb]
        mov  si,ax
        add  si,si              ; word index of node (a,b)
        ; corners: n0=(a,b) n1=(a+1,b) n2=(a+1,b+1) n3=(a,b+1)
        mov  ax,[TRX+si]
        mov  [IX],ax
        mov  ax,[TRZ+si]
        mov  [IZ],ax
        mov  ax,[TWH+si]
        sub  ax,[camy]
        mov  [IY],ax
        mov  ax,[TRX+si+82]     ; +41 nodes = +82 bytes -> (a+1,b)
        mov  [IX+2],ax
        mov  ax,[TRZ+si+82]
        mov  [IZ+2],ax
        mov  ax,[TWH+si+82]
        sub  ax,[camy]
        mov  [IY+2],ax
        mov  ax,[TRX+si+84]     ; (a+1,b+1)
        mov  [IX+4],ax
        mov  ax,[TRZ+si+84]
        mov  [IZ+4],ax
        mov  ax,[TWH+si+84]
        sub  ax,[camy]
        mov  [IY+4],ax
        mov  ax,[TRX+si+2]      ; (a,b+1)
        mov  [IX+6],ax
        mov  ax,[TRZ+si+2]
        mov  [IZ+6],ax
        mov  ax,[TWH+si+2]
        sub  ax,[camy]
        mov  [IY+6],ax
        ; quick cull: all corners behind, or all beyond FARZ
        mov  ax,[IZ]
        cmp  ax,[IZ+2]
        jge  @@z1
        mov  ax,[IZ+2]
@@z1:   cmp  ax,[IZ+4]
        jge  @@z2
        mov  ax,[IZ+4]
@@z2:   cmp  ax,[IZ+6]
        jge  @@z3
        mov  ax,[IZ+6]
@@z3:   cmp  ax,NEARZ
        jl   @@next             ; max z < NEARZ -> fully behind
        mov  ax,[IZ]
        cmp  ax,[IZ+2]
        jle  @@n1
        mov  ax,[IZ+2]
@@n1:   cmp  ax,[IZ+4]
        jle  @@n2
        mov  ax,[IZ+4]
@@n2:   cmp  ax,[IZ+6]
        jle  @@n3
        mov  ax,[IZ+6]
@@n3:   cmp  ax,FARZ
        jg   @@next             ; min z beyond far -> skip
        ; colour from the max raw H of the 4 corners
        mov  di,si
        shr  di,1               ; byte index
        mov  al,[TH+di]
        mov  ah,[TH+di+41]
        cmp  al,ah
        jae  @@c1
        mov  al,ah
@@c1:   mov  ah,[TH+di+42]
        cmp  al,ah
        jae  @@c2
        mov  al,ah
@@c2:   mov  ah,[TH+di+1]
        cmp  al,ah
        jae  @@c3
        mov  al,ah
@@c3:   ; al = max H
        cmp  al,88
        jb   @@water
        cmp  al,168
        jb   @@grass
        cmp  al,200
        jb   @@woods
        cmp  al,230
        jb   @@rock
        mov  byte ptr [COLOR],8 ; snow caps
        jmp  @@fill
@@water:
        mov  byte ptr [COLOR],14
        jmp  @@fill
@@grass:
        mov  byte ptr [COLOR],10
        jmp  @@fill
@@woods:
        mov  byte ptr [COLOR],15
        jmp  @@fill
@@rock: mov  byte ptr [COLOR],13
@@fill: ; PITCH4 (inside FACEFILL's clip) rotates IY/IZ in place; stash them
        ; so the stroke pass below starts from unpitched vertices, not
        ; double-pitched ones (that was the "grid drifts away" bug).
        mov  ax,[IY]
        mov  [SIY],ax
        mov  ax,[IY+2]
        mov  [SIY+2],ax
        mov  ax,[IY+4]
        mov  [SIY+4],ax
        mov  ax,[IY+6]
        mov  [SIY+6],ax
        mov  ax,[IZ]
        mov  [SIZ],ax
        mov  ax,[IZ+2]
        mov  [SIZ+2],ax
        mov  ax,[IZ+4]
        mov  [SIZ+4],ax
        mov  ax,[IZ+6]
        mov  [SIZ+6],ax
        call FACEFILL
        ; near quads: dark relief edges so low flight reads the slopes
        mov  ax,[tta]
        sub  ax,NR
        cmp  ax,-3
        jl   @@next
        cmp  ax,2
        jg   @@next
        mov  ax,[ttb]
        sub  ax,NR
        cmp  ax,-3
        jl   @@next
        cmp  ax,2
        jg   @@next
        mov  ax,[SIY]           ; restore the unpitched vertices
        mov  [IY],ax
        mov  ax,[SIY+2]
        mov  [IY+2],ax
        mov  ax,[SIY+4]
        mov  [IY+4],ax
        mov  ax,[SIY+6]
        mov  [IY+6],ax
        mov  ax,[SIZ]
        mov  [IZ],ax
        mov  ax,[SIZ+2]
        mov  [IZ+2],ax
        mov  ax,[SIZ+4]
        mov  [IZ+4],ax
        mov  ax,[SIZ+6]
        mov  [IZ+6],ax
        mov  byte ptr [COLOR],28 ; dark ground colour: edges sit IN the relief
        call FACESTROKE
@@next: inc  word ptr [tidx]
        cmp  word ptr [tidx],1600
        jl   @@tl
        ret

; ============================================================================
;  MMAPGEN - bake the 64x64 world minimap from HMAP (once, after DSGEN).
;  Colours: water/plain/CITY-BROWN/woods/rock/snow. North (+Z) is up.
; ============================================================================
MMAPGEN:
        push es                 ; the map is baked into the scratch segment
        mov  ax,[scrseg]
        mov  es,ax
        mov  word ptr [dsx],0   ; node i (world X)
@@i:    mov  word ptr [dsy],0   ; node j (world Z)
@@j:    mov  bx,[dsx]
        mov  dx,[dsy]
        call HGET               ; AL = H
        mov  ah,14              ; water
        cmp  al,88
        jb   @@put
        mov  ah,10              ; plains green
        cmp  al,120
        jb   @@put
        mov  ah,18              ; CITY -> brown blocks
        cmp  al,168
        jb   @@put
        mov  ah,15              ; woods
        cmp  al,200
        jb   @@put
        mov  ah,13              ; rock
        cmp  al,230
        jb   @@put
        mov  ah,8               ; snow
@@put:  mov  bx,63              ; screen row = 63 - j (north up)
        sub  bx,[dsy]
        mov  cl,6
        shl  bx,cl
        add  bx,[dsx]
        mov  es:[bx],ah
        inc  word ptr [dsy]
        cmp  word ptr [dsy],64
        jl   @@j
        inc  word ptr [dsx]
        cmp  word ptr [dsx],64
        jl   @@i
        pop  es
        ret

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
@@fr:   mov  es:[di],al
        mov  es:[di+65],al
        add  di,320
        loop @@fr
        ; blit the baked map (it lives in the far scratch segment)
        mov  ax,[mapt]
        call ROW320
        add  di,252
        push ds
        mov  ax,[scrseg]
        mov  ds,ax
        xor  si,si
        mov  cx,64
@@row:  push cx
        mov  cx,32
        rep  movsw              ; one 64-byte map row
        pop  cx
        add  di,320-64
        loop @@row
        pop  ds
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
        mov  es:[di],al
        mov  es:[di+1],al
        mov  es:[di+320],al
        mov  es:[di+321],al
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
        sub  ax,cx              ; pixel offset = dxn - dzn*320
        add  di,ax
        mov  al,19              ; red course tick
        mov  es:[di],al
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
        imul word ptr [dsx]
        mov  bx,64
        idiv bx
        add  ax,[x0]
        mov  [x0],ax            ; ha
        mov  ax,[y1]
        sub  ax,[y0]
        imul word ptr [dsx]
        mov  bx,64
        idiv bx
        add  ax,[y0]            ; hb
        ; h = ha + (hb-ha)*fz/64
        sub  ax,[x0]
        imul word ptr [dsy]
        mov  bx,64
        idiv bx
        add  ax,[x0]
        ret

; ============================================================================
;  MINIMAP2 - the baked map at half scale (32x32, every other row and
;  column) on the green MFD at (202,155). White plane blip, red course
;  tick. Full 1:1 map needs a 64x64 green square in the artwork.
; ============================================================================
MINIMAP2:
        cld
        mov  ax,155
        call ROW320
        add  di,202
        push ds                 ; the map lives in the far scratch segment
        mov  ax,[scrseg]
        mov  ds,ax
        xor  si,si
        mov  dx,32              ; dest rows
@@row:  mov  cx,32
@@px:   lodsb                   ; every other source column
        inc  si
        stosb
        loop @@px
        add  si,64              ; skip the odd source row
        add  di,320-32
        dec  dx
        jnz  @@row
        pop  ds
        ; plane blip at node (camx,camz), halved
        mov  ax,[camx]
        add  ax,BIAS
        mov  cl,2
        shr  ax,cl
        mov  cl,8
        shr  ax,cl
        and  ax,63
        shr  ax,1
        mov  bx,ax              ; col/2
        mov  ax,[camz]
        add  ax,BIAS
        mov  cl,2
        shr  ax,cl
        mov  cl,8
        shr  ax,cl
        and  ax,63
        mov  dx,63
        sub  dx,ax              ; row = 63 - node z
        shr  dx,1
        mov  ax,dx
        add  ax,155
        push bx
        call ROW320
        pop  bx
        add  di,202
        add  di,bx
        mov  al,8               ; white blip
        mov  es:[di],al
        ; course tick 1-2 px ahead of the blip
        mov  ax,[hsin]
        add  ax,ax              ; hsin*2 -> -2..2 screen px
        mov  bx,256
        cwd
        idiv bx
        mov  si,ax
        mov  ax,[hcos]
        add  ax,ax
        cwd
        idiv bx                 ; dz -> minus one row per unit (+Z is up)
        mov  cx,320
        imul cx
        mov  cx,ax
        mov  ax,si
        sub  ax,cx
        add  di,ax
        mov  al,19              ; red course tick
        mov  es:[di],al
        ret
