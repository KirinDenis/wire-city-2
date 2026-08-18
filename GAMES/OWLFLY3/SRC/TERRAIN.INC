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
        mov  word [tta],0
.al:   mov  word [ttb],0
.bl:   ; world position of node (tnx+tta-NR, tnz+ttb-NR)
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
        mov  ax,[rc_x]
        mov  [TRX+si],ax
        mov  ax,[rc_z]
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
        inc  word [ttb]
        cmp  word [ttb],NSIDE
        jl   .bl
        inc  word [tta]
        cmp  word [tta],NSIDE
        jl   .al
        ret

; ============================================================================
;  TERRAIN - draw the 3D landscape: 1600 heightmap quads far -> near (TORD).
;  Colours by the max raw H of the quad corners: water, grass, woods, rock,
;  snow. Near quads also get a grid stroke. Buildings draw after this.
; ============================================================================
TERRAIN:
        mov  word [tidx],0
.tl:   mov  si,[tidx]
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
        jge  .z1
        mov  ax,[IZ+2]
.z1:   cmp  ax,[IZ+4]
        jge  .z2
        mov  ax,[IZ+4]
.z2:   cmp  ax,[IZ+6]
        jge  .z3
        mov  ax,[IZ+6]
.z3:   cmp  ax,NEARZ
        jl   .next             ; max z < NEARZ -> fully behind
        mov  ax,[IZ]
        cmp  ax,[IZ+2]
        jle  .n1
        mov  ax,[IZ+2]
.n1:   cmp  ax,[IZ+4]
        jle  .n2
        mov  ax,[IZ+4]
.n2:   cmp  ax,[IZ+6]
        jle  .n3
        mov  ax,[IZ+6]
.n3:   cmp  ax,FARZ
        jg   .next             ; min z beyond far -> skip
        ; colour from the max raw H of the 4 corners
        mov  di,si
        shr  di,1               ; byte index
        mov  al,[TH+di]
        mov  ah,[TH+di+41]
        cmp  al,ah
        jae  .c1
        mov  al,ah
.c1:   mov  ah,[TH+di+42]
        cmp  al,ah
        jae  .c2
        mov  al,ah
.c2:   mov  ah,[TH+di+1]
        cmp  al,ah
        jae  .c3
        mov  al,ah
.c3:   ; al = max H
        cmp  al,88
        jb   .water
        cmp  al,168
        jb   .grass
        cmp  al,200
        jb   .woods
        cmp  al,230
        jb   .rock
        mov  byte [COLOR],8 ; snow caps
        jmp  .fill
.water:
        mov  byte [COLOR],14
        jmp  .fill
.grass:
        mov  byte [COLOR],10
        jmp  .fill
.woods:
        mov  byte [COLOR],15
        jmp  .fill
.rock: mov  byte [COLOR],13
.fill: ; PITCH4 (inside FACEFILL's clip) rotates IY/IZ in place; stash them
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
        jl   .next
        cmp  ax,2
        jg   .next
        mov  ax,[ttb]
        sub  ax,NR
        cmp  ax,-3
        jl   .next
        cmp  ax,2
        jg   .next
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
        mov  byte [COLOR],28 ; dark ground colour: edges sit IN the relief
        call FACESTROKE
.next: inc  word [tidx]
        cmp  word [tidx],1600
        jl   .tl
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
