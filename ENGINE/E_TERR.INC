; E_TERR.INC - WIRE CITY engine: the procedural world
; ============================================================================
;  Diamond-Square heightmap generation on a 64x64 torus plus the height /
;  zoning helpers built on it. This is the whole planet factory: seed the
;  LCG, call DSGEN once, and HGET answers any world question after that.
;
;  CONTRACT: the includer defines
;     HMAP           - 4096 bytes (64x64 node heights, row = x, col = y)
;     dss,dsh,dsx,dsy,dsamp,dsac  dw - generator state / scratch
;     RND16          - from E_MATH.INC (and its rseed)
; ============================================================================

; ---- heightmap access: node (BX=x, DX=y), toroidal --------------------------
HGET:   push bx                 ; out: AL = height ; preserves BX,DX
        push dx
        and  bx,63
        mov  cl,6
        shl  bx,cl
        and  dx,63
        add  bx,dx
        mov  al,[HMAP+bx]
        pop  dx
        pop  bx
        ret
HPUT:   push bx                 ; in: AL = height ; preserves BX,DX,AX
        push dx
        and  bx,63
        mov  cl,6
        shl  bx,cl
        and  dx,63
        add  bx,dx
        mov  [HMAP+bx],al
        pop  dx
        pop  bx
        ret

; ============================================================================
;  DSGEN - Diamond-Square heightmap on a 64x64 TORUS (from CityGame's integer
;  terrain generator), then a histogram stretch to the full 0..255 range
;  (plain DS averaging squeezes everything toward the middle, flattening it).
; ============================================================================
DSGEN:  mov  word ptr [dss],32  ; seed anchors on the coarsest grid
        mov  word ptr [dsamp],128
        xor  bx,bx
        xor  dx,dx
        call RND16
        and  al,127
        add  al,64              ; anchors 64..191 (mid range)
        call HPUT
        mov  bx,32
        call RND16
        and  al,127
        add  al,64
        call HPUT
        xor  bx,bx
        mov  dx,32
        call RND16
        and  al,127
        add  al,64
        call HPUT
        mov  bx,32
        call RND16
        and  al,127
        add  al,64
        call HPUT
@@pass: ; ---- diamond step ----
        mov  ax,[dss]
        shr  ax,1
        mov  [dsh],ax
        mov  word ptr [dsx],0
@@dx:   mov  word ptr [dsy],0
@@dy:   mov  bx,[dsx]
        mov  dx,[dsy]
        call HGET
        xor  ah,ah
        mov  [dsac],ax
        mov  bx,[dsx]
        add  bx,[dss]
        call HGET
        xor  ah,ah
        add  [dsac],ax
        mov  dx,[dsy]
        add  dx,[dss]
        call HGET
        xor  ah,ah
        add  [dsac],ax
        mov  bx,[dsx]
        call HGET
        xor  ah,ah
        add  [dsac],ax
        call @@noise            ; AX = avg4 + noise, clamped 0..255
        mov  bx,[dsx]
        add  bx,[dsh]
        mov  dx,[dsy]
        add  dx,[dsh]
        call HPUT
        mov  ax,[dsy]
        add  ax,[dss]
        mov  [dsy],ax
        cmp  ax,64
        jb   @@dy
        mov  ax,[dsx]
        add  ax,[dss]
        mov  [dsx],ax
        cmp  ax,64
        jb   @@dx
        ; ---- square step: the two edge midpoints of every square ----
        mov  word ptr [dsx],0
@@sx:   mov  word ptr [dsy],0
@@sy:   ; point (dsx+h, dsy): neighbours (x,y) (x+s,y) (x+h,y-h) (x+h,y+h)
        mov  bx,[dsx]
        mov  dx,[dsy]
        call HGET
        xor  ah,ah
        mov  [dsac],ax
        mov  bx,[dsx]
        add  bx,[dss]
        call HGET
        xor  ah,ah
        add  [dsac],ax
        mov  bx,[dsx]
        add  bx,[dsh]
        mov  dx,[dsy]
        sub  dx,[dsh]
        call HGET
        xor  ah,ah
        add  [dsac],ax
        mov  dx,[dsy]
        add  dx,[dsh]
        call HGET
        xor  ah,ah
        add  [dsac],ax
        call @@noise
        mov  bx,[dsx]
        add  bx,[dsh]
        mov  dx,[dsy]
        call HPUT
        ; point (dsx, dsy+h): neighbours (x,y) (x,y+s) (x-h,y+h) (x+h,y+h)
        mov  bx,[dsx]
        mov  dx,[dsy]
        call HGET
        xor  ah,ah
        mov  [dsac],ax
        mov  dx,[dsy]
        add  dx,[dss]
        call HGET
        xor  ah,ah
        add  [dsac],ax
        mov  bx,[dsx]
        sub  bx,[dsh]
        mov  dx,[dsy]
        add  dx,[dsh]
        call HGET
        xor  ah,ah
        add  [dsac],ax
        mov  bx,[dsx]
        add  bx,[dsh]
        call HGET
        xor  ah,ah
        add  [dsac],ax
        call @@noise
        mov  bx,[dsx]
        mov  dx,[dsy]
        add  dx,[dsh]
        call HPUT
        mov  ax,[dsy]
        add  ax,[dss]
        mov  [dsy],ax
        cmp  ax,64
        jb   @@sy
        mov  ax,[dsx]
        add  ax,[dss]
        mov  [dsx],ax
        cmp  ax,64
        jb   @@sx
        ; ---- next octave: halve side and amplitude ----
        mov  ax,[dsh]
        mov  [dss],ax
        mov  ax,[dsamp]
        shr  ax,1
        cmp  ax,4
        jge  @@a4
        mov  ax,4
@@a4:   mov  [dsamp],ax
        cmp  word ptr [dss],1
        jg   @@pass
        ; ---- histogram stretch: min..max -> 0..255 ----
        mov  al,255             ; al = min so far
        mov  ah,0               ; ah = max so far
        xor  si,si
@@mm:   mov  bl,[HMAP+si]
        cmp  bl,al
        jae  @@m1
        mov  al,bl
@@m1:   cmp  bl,ah
        jbe  @@m2
        mov  ah,bl
@@m2:   inc  si
        cmp  si,4096
        jb   @@mm
        mov  bl,ah
        sub  bl,al              ; range = max - min
        jz   @@sdone            ; degenerate map: leave as is
        mov  bh,0
        mov  [dsy],bx           ; dsy = range (word)
        mov  ah,0
        mov  [dsx],ax           ; dsx = min (word)
        xor  si,si
@@sc:   mov  al,[HMAP+si]
        mov  ah,0
        sub  ax,[dsx]           ; v - min
        mov  cx,255
        mul  cx                 ; DX:AX = (v-min)*255 ; DX=0 (fits 16 bits)
        div  word ptr [dsy]     ; AX = scaled 0..255
        mov  [HMAP+si],al
        inc  si
        cmp  si,4096
        jb   @@sc
@@sdone:
        ret
@@noise:                        ; AX = dsac/4 + (rnd & (amp-1)) - amp/2, 0..255
        call RND16
        mov  bx,[dsamp]
        dec  bx
        and  ax,bx              ; 0..amp-1
        mov  bx,[dsamp]
        shr  bx,1
        sub  ax,bx              ; -amp/2 .. amp/2-1
        mov  bx,[dsac]
        shr  bx,1
        shr  bx,1               ; avg of 4
        add  ax,bx
        jns  @@n1
        xor  ax,ax
@@n1:   cmp  ax,255
        jle  @@n2
        mov  ax,255
@@n2:   ret

; ============================================================================
;  GETH - world height for cell (AX=gi, BX=gj) from the DS map (1 node = 4x4
;  cells, toroidal). out: AX = height 0..255.
; ============================================================================
GETH:   mov  cl,2
        shr  ax,cl              ; node x = gi>>2 (wraps in HGET)
        push bx
        mov  bx,ax
        pop  dx
        mov  cl,2
        shr  dx,cl              ; node y
        call HGET
        xor  ah,ah
        ret

; ============================================================================
;  GETZONE - world zoning from the Diamond-Square heightmap.
;   in: AX=cell gi, BX=cell gj
;   out: AX = 0 city / 1 plains / 2 mountains / 3 water / 4 foothills
;  Height bands: <88 sea, 88..119 plains, 120..167 city (lowlands),
;  168..199 foothills (dense woods), >=200 mountains.
; ============================================================================
GETZONE:
        call GETH
        cmp  ax,88
        jb   @@water
        cmp  ax,120
        jb   @@plain
        cmp  ax,168
        jb   @@city
        cmp  ax,200
        jb   @@foot
        mov  ax,2               ; mountains
        ret
@@water:
        mov  ax,3
        ret
@@foot: mov  ax,4
        ret
@@plain:
        mov  ax,1
        ret
@@city: xor  ax,ax
        ret

; ============================================================================
;  WORLDH - map height H (0..255) -> world height.  Sea floor clamps to 0,
;  land rises 5/unit, mountains (H>200) climb twice as fast -> peaks ~1110.
;   in: AX = raw H   out: AX = world height
; ============================================================================
WORLDH: sub  ax,88
        jns  @@w0
        xor  ax,ax              ; below sea level -> 0 (water surface)
        ret
@@w0:   mov  bx,5
        imul bx                 ; (H-88)*5   (max 835)
        cmp  ax,560             ; H=200 -> 560: steepen above this (mountains)
        jle  @@w1
        mov  bx,ax
        sub  bx,560
        add  ax,bx              ; doubled slope above 560 -> peaks ~1110
@@w1:   ret
