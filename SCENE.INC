; SCENE.INC - part of WIRE CITY (included from CITY.ASM)
; ============================================================================
;  RENDER THE WORLD
; ============================================================================
RENDER: ; camera cell (needed by GRID and BUILDINGS)
        mov  ax,[camx]
        add  ax,BIAS
        mov  cl,8
        shr  ax,cl
        mov  [camgi],ax
        mov  ax,[camz]
        add  ax,BIAS
        mov  cl,8
        shr  ax,cl
        mov  [camgj],ax
        cmp  byte ptr [daymode],0
        jne  @@day              ; stars only at night
        call STARS
@@day:  call TERRPREP           ; rotate + cache the terrain nodes
        call TERRAIN            ; real 3D relief, far -> near
        call RENDERMEGAS        ; distant city blocks on the lowlands
        call BUILDINGS
        call MINIMAP            ; bottom-right world map + plane marker
        ret

; ----- stars (sky background; horizon is the sky/ground colour split) -------
STARS:  mov  byte ptr [COLOR],8
        mov  si,offset STARTAB
        mov  cx,STARN
@@s:    push cx
        mov  ax,[si]            ; star X (word)
        mov  [tmpsx],ax
        mov  ax,[si+2]          ; star Y (word)
        mov  [tmpsy],ax
        mov  bx,[tmpsy]
        cmp  bx,[horiz]         ; skip stars below the pitched horizon
        jge  @@sk
        mov  ax,[tmpsx]
        call PUTPIXEL
@@sk:   pop  cx
        add  si,4
        loop @@s
        ret

; ============================================================================
;  FAR BELT - megablocks and REAL mountains, world objects at 4x4-cell scale.
;  Painter order: Chebyshev rings from MEGR in to ring 2 (cells inside ring 2
;  are covered by the near per-cell pass). City-zone megas draw as one grey
;  block the size of a whole quarter; mountain-zone megas draw as pyramids.
; ============================================================================
RENDERMEGAS:
        mov  ax,[camgi]
        mov  cl,2
        shr  ax,cl
        mov  [cammgi],ax
        mov  ax,[camgj]
        mov  cl,2
        shr  ax,cl
        mov  [cammgj],ax
        mov  word ptr [mring],MEGR
@@rl:   call MEGARING
        dec  word ptr [mring]
        cmp  word ptr [mring],1 ; ring 1 too: near-pass misses its mountains
        jge  @@rl
        ret

; walk the perimeter of Chebyshev ring [mring], calling MEGACELL per cell
MEGARING:
        mov  ax,[mring]
        neg  ax
        mov  [cdi],ax
@@trow: mov  ax,[mring]         ; top & bottom edges
        neg  ax
        mov  [cdj],ax
        call MEGACELL
        mov  ax,[mring]
        mov  [cdj],ax
        call MEGACELL
        mov  ax,[cdi]
        inc  ax
        mov  [cdi],ax
        cmp  ax,[mring]
        jle  @@trow
        mov  ax,[mring]         ; left & right edges (corners already done)
        neg  ax
        inc  ax
        mov  [cdj],ax
@@lcol: mov  ax,[cdj]
        mov  bx,[mring]
        dec  bx
        cmp  ax,bx
        jg   @@done
        mov  ax,[mring]
        neg  ax
        mov  [cdi],ax
        call MEGACELL
        mov  ax,[mring]
        mov  [cdi],ax
        call MEGACELL
        mov  ax,[cdj]
        inc  ax
        mov  [cdj],ax
        jmp  @@lcol
@@done: ret

; ----- one megablock at (cammgi+cdi, cammgj+cdj) -----------------------------
MEGACELL:
        mov  ax,[cammgi]
        add  ax,[cdi]
        mov  bx,ax              ; mi
        mov  cl,2
        shl  ax,cl
        add  ax,2               ; centre cell gi = mi*4+2
        mov  [gi],ax
        mov  ax,[cammgj]
        add  ax,[cdj]
        mov  cl,2
        shl  ax,cl
        add  ax,2
        mov  [gj],ax
        mov  ax,[gi]
        mov  bx,[gj]
        call GETZONE            ; 0 city / 1 plain / 2 mnt / 3 water / 4 foothills
        test ax,ax
        jnz  @@ret              ; only city megas here: terrain draws the rest
        push ax                 ; keep stack shape (zone, always 0 now)
        ; world centre of the mega (centre cell's centre)
        mov  ax,[gi]
        mov  cl,8
        shl  ax,cl
        add  ax,128
        sub  ax,BIAS
        mov  [wcx],ax
        mov  ax,[gj]
        mov  cl,8
        shl  ax,cl
        add  ax,128
        sub  ax,BIAS
        mov  [wcz],ax
        ; mega hash for heights
        mov  ax,[gi]
        mov  bx,1973
        imul bx
        mov  si,ax
        mov  ax,[gj]
        mov  bx,9277
        imul bx
        add  ax,si
        mov  bx,ax
        mov  cl,7
        shr  bx,cl
        xor  ax,bx              ; ax = hash
        pop  bx                 ; (zone, always city here)
        ; --- city mega: one block covering the whole quarter ---
        cmp  word ptr [mring],3 ; rings 1-2 city covered by real buildings
        jl   @@ret
        mov  word ptr [bhw],350
        mov  word ptr [bhd],350
        and  ax,255
        add  ax,80              ; height 80..335 (approximates the quarter)
        mov  [bhgt2],ax
        call ROTCUL
        jc   @@ret
        mov  ax,[gi]            ; sit the block on the local terrain
        mov  bx,[gj]
        call GETH
        call WORLDH
        mov  [gbase],ax
        sub  ax,[camy]
        mov  [bry0],ax
        mov  ax,[gbase]
        add  ax,[bhgt2]
        sub  ax,[camy]
        mov  [bry1],ax
        ; solid haze-coloured silhouette; nearer rings get shade + outline
        mov  byte ptr [COLOR],1
        cmp  word ptr [mring],12
        jge  @@mfill
        mov  byte ptr [COLOR],16
@@mfill:
        mov  ax,[gbase]
        add  ax,[bhgt2]
        cmp  [camy],ax
        jle  @@mnr
        call FACETOPC
        call FACEFILL
@@mnr:  call MEGAFILL
        cmp  word ptr [mring],12
        jge  @@ret              ; distant rings: silhouette only
        mov  al,1               ; distant stroke colour, and VISSTROKE's
        mov  [COLOR],al         ; per-face restore value (scol) must match
        mov  [scol],al
        call VISSTROKE
@@ret:  ret

; fill the visible vertical faces with the CURRENT colour (no per-side tint)
MEGAFILL:
        mov  ax,[camx]
        cmp  ax,[bwx0]
        jge  @@e
        mov  word ptr [fa],3
        mov  word ptr [fb],0
        call FACEV
        call FACEFILL
@@e:    mov  ax,[camx]
        cmp  ax,[bwx1]
        jle  @@s
        mov  word ptr [fa],1
        mov  word ptr [fb],2
        call FACEV
        call FACEFILL
@@s:    mov  ax,[camz]
        cmp  ax,[bwz0]
        jge  @@n
        mov  word ptr [fa],0
        mov  word ptr [fb],1
        call FACEV
        call FACEFILL
@@n:    mov  ax,[camz]
        cmp  ax,[bwz1]
        jle  @@d
        mov  word ptr [fa],2
        mov  word ptr [fb],3
        call FACEV
        call FACEFILL
@@d:    ret
