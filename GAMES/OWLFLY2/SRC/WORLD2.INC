; WORLD2.INC - part of WIRE CITY (included from CITY.ASM)
; ============================================================================
;  FACEV  build a vertical face quad from footprint corners [fa],[fb]
;  using camera-space corners FRX/FRZ and heights bry0(bottom)/bry1(top)
;  quad order: A_bottom, A_top, B_top, B_bottom
; ============================================================================
FACEV:  mov  si,[fa]
        add  si,si
        mov  ax,[FRX+si]
        mov  [IX],ax
        mov  [IX+2],ax
        mov  ax,[FRZ+si]
        mov  [IZ],ax
        mov  [IZ+2],ax
        mov  si,[fb]
        add  si,si
        mov  ax,[FRX+si]
        mov  [IX+4],ax
        mov  [IX+6],ax
        mov  ax,[FRZ+si]
        mov  [IZ+4],ax
        mov  [IZ+6],ax
        mov  ax,[bry0]
        mov  [IY],ax
        mov  [IY+6],ax
        mov  ax,[bry1]
        mov  [IY+2],ax
        mov  [IY+4],ax
        ret

; ============================================================================
;  FACETOPC  build the roof quad from all 4 footprint corners at bry1
; ============================================================================
FACETOPC:
        mov  ax,[FRX]
        mov  [IX],ax
        mov  ax,[FRZ]
        mov  [IZ],ax
        mov  ax,[FRX+2]
        mov  [IX+2],ax
        mov  ax,[FRZ+2]
        mov  [IZ+2],ax
        mov  ax,[FRX+4]
        mov  [IX+4],ax
        mov  ax,[FRZ+4]
        mov  [IZ+4],ax
        mov  ax,[FRX+6]
        mov  [IX+6],ax
        mov  ax,[FRZ+6]
        mov  [IZ+6],ax
        mov  ax,[bry1]
        mov  [IY],ax
        mov  [IY+2],ax
        mov  [IY+4],ax
        mov  [IY+6],ax
        ret

; ============================================================================
;  HBLD  deterministic building descriptor for grid cell [gi],[gj]
;   out: bstreet (1 = empty avenue cell), and if 0: bhw,bhd (half-size 84..115)
;        and bhgt2 (height 100..355).  Clobbers AX,BX,CX,SI.
;   Streets: any cell with gi&3==0 or gj&3==0 is empty -> 3x3 blocks + wide
;   avenues. Otherwise a cheap integer hash of (gi,gj) picks the dimensions;
;   bit-fields of the hash give width / depth / height (deterministic, so the
;   same cell always looks identical - no per-frame flicker, no storage).
; ============================================================================
HBLD:   mov  ax,[gi]            ; world zoning first: city / plains / mountains
        mov  bx,[gj]
        call GETZONE
        cmp  ax,1
        je   @@st               ; plains: the terrain mesh paints the land
        cmp  ax,2
        je   @@st               ; mountains: the terrain mesh IS the mountain
        cmp  ax,3
        je   @@st               ; water: the terrain mesh paints the sea
        cmp  ax,4
        je   @@st               ; foothills: terrain paints the woods
        mov  ax,[gi]
        and  ax,3
        jz   @@st              ; gi on an avenue -> street
        mov  ax,[gj]
        and  ax,3
        jz   @@st              ; gj on an avenue -> street
        call CELLHASH          ; ax = hash of (gi,gj)
        mov  bx,ax
        and  bx,31              ; hash 7/8/9 of 32 -> flat terrain patches
        cmp  bx,7
        je   @@forest
        cmp  bx,8
        je   @@water
        cmp  bx,9
        je   @@field
        ; --- superblock clustering: only ~3/16 of 8x8 blocks are built up.
        ; Structures stay grouped (a built block keeps full density) but the
        ; groups themselves are rare - SimCity-style districts on open land.
        push ax                 ; keep the cell hash
        call SBHASH             ; superblock hash (clustering decision)
        mov  [sbh],ax
        and  ax,15
        cmp  ax,3
        jae  @@unbuilt          ; empty block: open ground (patches still apply)
        pop  ax
        ; district type from the block hash: 0/3 residential, 1 downtown, 2 industry
        mov  bx,[sbh]
        mov  cl,4
        shr  bx,cl
        and  bx,3
        mov  [bdist],bx
        ; base footprint from the cell hash
        mov  bx,ax
        and  bx,31              ; bits[0..4]  -> half width  84..115
        add  bx,84
        mov  [bhw],bx
        mov  bx,ax
        mov  cl,5
        shr  bx,cl
        and  bx,31              ; bits[5..9]  -> half depth  84..115
        add  bx,84
        mov  [bhd],bx
        mov  bx,ax              ; wall colour scheme 0..3 (grey/blue/red/white)
        mov  cl,13
        shr  bx,cl
        and  bx,3
        mov  [bschm],bx
        mov  bx,ax              ; bsel = building selector 0..7
        mov  cl,10
        shr  bx,cl
        and  bx,7
        mov  si,[bdist]
        cmp  si,1
        je   @@com
        cmp  si,2
        je   @@ind
        ; --- residential: low boxes, an occasional tower ---
        mov  word ptr [btype],0
        cmp  bx,6
        jb   @@rh
        mov  word ptr [btype],2 ; tower
@@rh:   mov  bx,ax
        and  bx,63
        add  bx,60              ; height 60..123
        mov  [bhgt2],bx
        jmp  @@bdone
@@com:  ; --- commercial downtown: tall mixed skyline ---
        mov  word ptr [btype],0
        cmp  bx,3
        jb   @@ch               ; 0..2 tall box
        cmp  bx,5
        jb   @@ctw              ; 3..4 tower
        cmp  bx,7
        jb   @@csp              ; 5..6 spire
        mov  word ptr [btype],3 ; 7 arch
        jmp  @@ch
@@ctw:  mov  word ptr [btype],2
        jmp  @@ch
@@csp:  mov  word ptr [btype],1
@@ch:   ; downtown height: towers cluster toward the block centre.
        ; dist = |gi&7 - 4| + |gj&7 - 4| (0..8); centre -> +288 bonus.
        push ax
        mov  bx,[gi]
        and  bx,7
        sub  bx,4
        jns  @@a1
        neg  bx
@@a1:   mov  si,bx              ; |gi&7 - 4|
        mov  bx,[gj]
        and  bx,7
        sub  bx,4
        jns  @@a2
        neg  bx
@@a2:   add  si,bx              ; manhattan dist to superblock centre, 0..8
        mov  ax,8
        sub  ax,si
        mov  bx,36
        imul bx                 ; downtown bonus 0..288
        mov  si,ax
        pop  ax
        mov  bx,ax
        and  bx,63              ; per-building variation 0..63
        add  bx,50
        add  bx,si              ; height 50..401 (respawn clears all)
        mov  [bhgt2],bx
        jmp  @@bdone
@@ind:  ; --- industrial: smoking factories and low sheds (always grey) ---
        mov  word ptr [bschm],0
        mov  word ptr [btype],4
        cmp  bx,5
        jb   @@ih               ; 0..4 factory with chimney
        mov  word ptr [btype],0 ; 5..7 plain shed
@@ih:   mov  bx,ax
        and  bx,31
        add  bx,50              ; low industry: 50..81
        mov  [bhgt2],bx
@@bdone:
        mov  word ptr [bstreet],0
        ret
@@st:   mov  word ptr [bstreet],1
        ret
@@unbuilt:
        pop  ax                 ; discard the kept cell hash
        jmp  @@st
@@forest:
        mov  byte ptr [bcol],15
        jmp  @@patch
@@water:
        mov  byte ptr [bcol],14
        jmp  @@patch
@@field:
        mov  byte ptr [bcol],11
@@patch:                        ; flat ground patch fills most of the cell
        mov  word ptr [bhw],116
        mov  word ptr [bhd],116
        mov  word ptr [bstreet],2
        ret

; SBHASH - superblock (8x8 cells) hash for cell [gi],[gj] -> AX.
; Single source of truth for "is this block built up": HBLD plans buildings
; with it; anything distance-related must agree with this decision.
SBHASH: mov  ax,[gi]
        mov  cl,3
        shr  ax,cl
        and  ax,31              ; superblock i (toroidal)
        mov  si,ax
        mov  ax,[gj]
        mov  cl,3
        shr  ax,cl
        and  ax,31
        mov  bx,ax
        mov  ax,331
        mul  si
        mov  si,ax
        mov  ax,769
        mul  bx
        add  ax,si
        mov  bx,ax
        mov  cl,4
        shr  bx,cl
        xor  ax,bx
        ret

; hash = mix(gi*1973 + gj*9277) - shared by buildings, patches and mountains
CELLHASH:
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
        xor  ax,bx
        ret

; ============================================================================
;  WINFACE  draw lit windows on the current vertical face (IX/IY/IZ[0..3])
;  corner order: 0=A_bot 1=A_top 2=B_top 3=B_bot ; needs all IZ>=NEARZ
; ============================================================================
WINFACE:
        ; The glass walks the wall in CAMERA space and every pane is
        ; projected on its own. The old grid was bilinear in SCREEN
        ; space - affine, which is fine at a distance but slides the
        ; windows clean off the building when you close in, leaving
        ; them hanging in the air beside it (user report 2026-07-27).
        ; A corner behind the near plane no longer kills the whole
        ; face either: each pane carries its own Z test, so a
        ; half-clipped wall keeps the glass it can still show.
        ;
        ; NO PITCH4 HERE. FACESTROKE ran on this face one call ago and
        ; its CLIPNEAR already pitched IX/IY/IZ IN PLACE. Pitching again
        ; turned the glass a second time about the camera axis, so the
        ; windows slid off the wall exactly when you dived at the city -
        ; which is the only way you ever approach it (2026-07-27).
        mov  byte ptr [wc],0
@@cl:   mov  al,[wc]            ; u = (2c+1)/6 across the wall
        cbw
        add  ax,ax
        inc  ax
        mov  [wfu],ax
        mov  ax,[IX+4]          ; column top = C1 + (C2-C1)*u/6
        sub  ax,[IX+2]
        imul word ptr [wfu]
        mov  bx,6
        idiv bx
        add  ax,[IX+2]
        mov  [wtcx],ax
        mov  ax,[IY+4]
        sub  ax,[IY+2]
        imul word ptr [wfu]
        mov  bx,6
        idiv bx
        add  ax,[IY+2]
        mov  [wtcy],ax
        mov  ax,[IZ+4]
        sub  ax,[IZ+2]
        imul word ptr [wfu]
        mov  bx,6
        idiv bx
        add  ax,[IZ+2]
        mov  [wtcz],ax
        mov  ax,[IX+6]          ; column bottom = C0 + (C3-C0)*u/6
        sub  ax,[IX]
        imul word ptr [wfu]
        mov  bx,6
        idiv bx
        add  ax,[IX]
        mov  [wbcx],ax
        mov  ax,[IY+6]
        sub  ax,[IY]
        imul word ptr [wfu]
        mov  bx,6
        idiv bx
        add  ax,[IY]
        mov  [wbcy],ax
        mov  ax,[IZ+6]
        sub  ax,[IZ]
        imul word ptr [wfu]
        mov  bx,6
        idiv bx
        add  ax,[IZ]
        mov  [wbcz],ax
        mov  byte ptr [wr],0
@@rl:   mov  al,[wr]            ; v = (2r+1)/10 down the column
        cbw
        add  ax,ax
        inc  ax
        mov  [wfv],ax
        mov  ax,[wbcz]          ; depth first: it gates AND it sizes
        sub  ax,[wtcz]
        imul word ptr [wfv]
        mov  bx,10
        idiv bx
        add  ax,[wtcz]
        mov  [wgz],ax
        cmp  ax,NEARZ
        jl   @@wn               ; this pane is behind us
        mov  ax,[wbcx]
        sub  ax,[wtcx]
        imul word ptr [wfv]
        mov  bx,10
        idiv bx
        add  ax,[wtcx]
        mov  [wgx],ax
        mov  ax,[wbcy]
        sub  ax,[wtcy]
        imul word ptr [wfv]
        mov  bx,10
        idiv bx
        add  ax,[wtcy]
        mov  [wgy],ax
        mov  ax,[wgx]
        mov  dx,[wgy]
        mov  cx,[wgz]
        call PROJPT
        mov  [wpx],ax
        mov  [wpy],dx
        call WLIT2
        jz   @@wn
        mov  ax,6160            ; a pane is ~28 units of glass: r=28*220/z
        cwd
        idiv word ptr [wgz]
        or   ax,ax
        jnz  @@ws1
        inc  ax                 ; never smaller than one lit pixel
@@ws1:  cmp  ax,10
        jle  @@ws2
        mov  ax,10              ; ...and never a wall of light
@@ws2:  mov  [wbsz],al
        sar  ax,1               ; centre the pane on its point
        mov  bx,[wpx]
        sub  bx,ax
        mov  [wpx],bx
        mov  bx,[wpy]
        sub  bx,ax
        mov  [wpy],bx
        mov  byte ptr [wbj],0
@@wby:  mov  byte ptr [wbi],0
@@wbx:  mov  al,[wbi]
        cbw
        add  ax,[wpx]
        js   @@wbs
        cmp  ax,319
        jg   @@wbs
        mov  bl,[wbj]
        xor  bh,bh
        add  bx,[wpy]
        js   @@wbs
        cmp  bx,199
        jg   @@wbs
        call PUTPIXEL
@@wbs:  inc  byte ptr [wbi]
        mov  al,[wbi]
        cmp  al,[wbsz]
        jl   @@wbx
        inc  byte ptr [wbj]
        mov  al,[wbj]
        cmp  al,[wbsz]
        jl   @@wby
@@wn:   inc  byte ptr [wr]
        cmp  byte ptr [wr],5
        jl   @@rl
        inc  byte ptr [wc]
        cmp  byte ptr [wc],3
        jl   @@cl
        ret

; lit? hash from gi,gj,fa,wr,wc -> ZF=1 not lit else COLOR set
WLIT2:  mov  ax,[gi]
        mov  bx,131
        imul bx
        mov  si,ax
        mov  ax,[gj]
        mov  bx,977
        imul bx
        add  ax,si
        mov  bx,[fa]
        add  ax,bx
        mov  bl,[wr]
        xor  bh,bh
        mov  cx,101
        push ax
        mov  ax,bx
        mul  cx
        mov  bx,ax
        pop  ax
        add  ax,bx
        mov  bl,[wc]
        xor  bh,bh
        mov  cx,57
        push ax
        mov  ax,bx
        mul  cx
        mov  bx,ax
        pop  ax
        add  ax,bx
        mov  bx,ax
        mov  cl,5
        shr  bx,cl
        xor  ax,bx
        mov  bx,ax
        and  bx,7
        cmp  bx,3
        jl   @@lit
        xor  al,al
        ret
@@lit:  mov  bx,ax
        and  bx,31
        jnz  @@cy
        mov  byte ptr [COLOR],5
        jmp  @@d
@@cy:   mov  byte ptr [COLOR],4
@@d:    mov  al,1
        or   al,al
        ret
