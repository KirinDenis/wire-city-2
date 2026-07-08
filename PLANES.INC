; PLANES.INC - part of WIRE CITY (included from CITY.ASM)
; ============================================================================
;  AI traffic: F-15 Strike Eagle II style low-poly jets in the sky.
;  Model: 13 vertices / 8 quad faces (triangles repeat a vertex), painter-
;  sorted by face depth each frame - no BSP, no culling, just like 1989.
;  The engine nozzle face uses palette index 94, whose DAC entry is cycled
;  yellow/orange/red every few ticks by GAMELOOP (the classic VGA trick:
;  the fire "burns" without redrawing a single pixel).
; ============================================================================

; ---------------------------------------------------------------------------
;  PLANESUPD - one physics tick of the AI: fly gentle circles, stay near
;  the player (leash respawn when too far). Called from INPUT.
; ---------------------------------------------------------------------------
PLANESUPD:
        xor  si,si              ; plane offset (words)
@@pl:
        ; gentle circle: nudge the heading on every 4th tick
        mov  ax,[lasttk]
        and  ax,3
        jnz  @@mv
        mov  ax,[pah+si]
        test si,2               ; alternate circling directions
        jnz  @@ccw
        inc  ax
        jmp  @@turn
@@ccw:  dec  ax
@@turn: and  ax,255
        mov  [pah+si],ax
@@mv:
        ; advance 30 units along the heading
        mov  ax,[pah+si]
        push si
        call SINQ
        mov  bx,30
        imul bx
        mov  bx,256
        idiv bx
        pop  si
        add  [pax+si],ax
        mov  ax,[pah+si]
        add  ax,64
        push si
        call SINQ
        mov  bx,30
        imul bx
        mov  bx,256
        idiv bx
        pop  si
        add  [paz+si],ax
        ; leash: wandered too far -> respawn in a random spot nearby
        mov  ax,[pax+si]
        sub  ax,[camx]
        jns  @@l1
        neg  ax
@@l1:   cmp  ax,12000
        jge  @@resp
        mov  ax,[paz+si]
        sub  ax,[camz]
        jns  @@l2
        neg  ax
@@l2:   cmp  ax,12000
        jl   @@next
@@resp: push si
        call RND16
        pop  si
        and  ax,8191
        sub  ax,4096
        add  ax,[camx]
        mov  [pax+si],ax
        push si
        call RND16
        pop  si
        and  ax,8191
        sub  ax,4096
        add  ax,[camz]
        mov  [paz+si],ax
        push si
        call RND16
        pop  si
        and  ax,511
        add  ax,800             ; altitude 800..1311
        mov  [pay+si],ax
        ; drop a contrail point every 8th tick
        mov  ax,[lasttk]
        and  ax,7
        jnz  @@next
        mov  bx,si
        mov  cl,3
        shl  bx,cl              ; slot base = plane*TLN*2
        add  bx,[tlh]
        mov  ax,[pax+si]
        mov  [TLX+bx],ax
        mov  ax,[pay+si]
        mov  [TLY+bx],ax
        mov  ax,[paz+si]
        mov  [TLZ+bx],ax
@@next: add  si,2
        cmp  si,NPLANE*2
        jb   @@pl
        mov  ax,[lasttk]        ; advance the shared ring head
        and  ax,7
        jnz  @@nth
        mov  ax,[tlh]
        add  ax,2
        cmp  ax,TLN*2
        jb   @@th2
        xor  ax,ax
@@th2:  mov  [tlh],ax
@@nth:  ret

; ---------------------------------------------------------------------------
;  PLANESDRAW - render the AI jets (called after BUILDINGS: they own the
;  sky, so painting over the world is the painter's order we want).
;  Per plane: rotate the model by (plane heading - camera heading), add
;  the camera-space centre, cache 13 vertices, bubble-sort the 8 faces
;  far -> near by average depth, then feed each to FACEFILL.
; ---------------------------------------------------------------------------
PLANESDRAW:
        mov  word ptr [pidx],0
@@pd:
        mov  si,[pidx]
        ; centre -> camera space (yaw only; PITCH4 pitches faces later)
        mov  ax,[pax+si]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[paz+si]
        sub  ax,[camz]
        mov  [wdz],ax
        ; quick reject on the world-space box
        mov  ax,[wdx]
        jns  @@q1
        neg  ax
@@q1:   cmp  ax,9000
        jge  @@skip
        mov  ax,[wdz]
        jns  @@q2
        neg  ax
@@q2:   cmp  ax,9000
        jge  @@skip
        call ROTXZ              ; -> rcx (right), rcz (depth)
        mov  ax,[rcz]
        cmp  ax,-100
        jl   @@skip             ; fully behind the camera
        cmp  ax,8500
        jge  @@skip             ; a pixel-sized dot: not worth the maths
        mov  [pdz],ax
        mov  ax,[rcx]
        mov  [pdx],ax
        mov  ax,[pay+si]
        sub  ax,[camy]
        mov  [pdy],ax
        ; ---- contrail: TLN dots behind the jet (haze colour) ----
        mov  bx,si
        mov  cl,3
        shl  bx,cl
        mov  [pfc],bx           ; slot base
        mov  word ptr [tpi],0
@@tr:   mov  bx,[pfc]
        add  bx,[tpi]
        mov  ax,[TLX+bx]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[TLZ+bx]
        sub  ax,[camz]
        mov  [wdz],ax
        push bx
        call ROTXZ
        pop  bx
        mov  dx,[TLY+bx]
        sub  dx,[camy]
        mov  ax,[rcx]
        mov  cx,[rcz]
        call PPOINT
        jc   @@trn
        cmp  ax,0
        jl   @@trn
        cmp  ax,319
        jg   @@trn
        cmp  dx,0
        jl   @@trn
        cmp  dx,199
        jg   @@trn
        mov  [dsx],ax
        mov  ax,dx
        call ROW320
        add  di,[dsx]
        mov  al,12              ; haze: reads as vapour day and night
        mov  es:[di],al
@@trn:  add  word ptr [tpi],2
        cmp  word ptr [tpi],TLN*2
        jb   @@tr
        mov  si,[pidx]          ; PROJPT inside PPOINT clobbers SI
        ; model yaw relative to the camera: A = plane heading - heading
        mov  ax,[pah+si]
        sub  ax,[heading]
        and  ax,255
        push ax
        push si
        call SINQ
        mov  [msin],ax
        pop  si
        pop  ax
        add  ax,64
        push si
        call SINQ
        mov  [mcos],ax
        pop  si
        ; ---- transform the 13 model vertices into the PV cache ----
        xor  si,si              ; model table offset (6 bytes/vertex)
        xor  di,di              ; cache offset (2 bytes/vertex)
@@tv:   mov  ax,[MVERT+si]      ; vx = (mx*mcos + mz*msin)/256 + pdx
        imul word ptr [mcos]
        mov  bx,ax
        mov  ax,[MVERT+si+4]
        imul word ptr [msin]
        add  ax,bx
        cwd
        mov  bx,256
        idiv bx
        add  ax,[pdx]
        mov  [PVX+di],ax
        mov  ax,[MVERT+si+2]    ; vy = my + pdy
        add  ax,[pdy]
        mov  [PVY+di],ax
        mov  ax,[MVERT+si]      ; vz = (mz*mcos - mx*msin)/256 + pdz
        imul word ptr [msin]
        mov  bx,ax
        mov  ax,[MVERT+si+4]
        imul word ptr [mcos]
        sub  ax,bx
        cwd
        mov  bx,256
        idiv bx
        add  ax,[pdz]
        mov  [PVZ+di],ax
        add  si,6
        add  di,2
        cmp  si,13*6
        jb   @@tv
        ; ---- face depths: FCD = avg z of the face corners ----
        xor  si,si              ; face index
@@fd:   mov  bx,si
        add  bx,bx
        add  bx,bx
        add  bx,si              ; face record = 5 bytes
        push si
        mov  al,[MFACE+bx]      ; corner ids -> depths, pairwise averaged
        xor  ah,ah
        add  ax,ax
        mov  si,ax
        mov  cx,[PVZ+si]
        mov  al,[MFACE+bx+1]
        xor  ah,ah
        add  ax,ax
        mov  si,ax
        add  cx,[PVZ+si]
        sar  cx,1               ; (a+b)/2
        mov  al,[MFACE+bx+2]
        xor  ah,ah
        add  ax,ax
        mov  si,ax
        mov  dx,[PVZ+si]
        mov  al,[MFACE+bx+3]
        xor  ah,ah
        add  ax,ax
        mov  si,ax
        add  dx,[PVZ+si]
        sar  dx,1               ; (c+d)/2
        add  cx,dx
        sar  cx,1               ; face average depth
        pop  si
        mov  bx,si
        add  bx,bx
        mov  [FCD+bx],cx
        mov  ax,si
        mov  bx,si
        mov  [FCO+bx],al        ; order starts as identity
        inc  si
        cmp  si,NFACE
        jb   @@fd
        ; ---- bubble far -> near (descending depth) ----
        mov  cx,NFACE-1
@@bs:   push cx
        xor  si,si
@@bi:   mov  bx,si
        add  bx,bx
        mov  ax,[FCD+bx]
        cmp  ax,[FCD+bx+2]
        jge  @@nsw
        xchg ax,[FCD+bx+2]      ; swap depths
        mov  [FCD+bx],ax
        mov  al,[FCO+si]        ; swap order entries
        xchg al,[FCO+si+1]
        mov  [FCO+si],al
@@nsw:  inc  si
        cmp  si,NFACE-1
        jb   @@bi
        pop  cx
        loop @@bs
        ; ---- draw the faces in painter order ----
        mov  word ptr [pfc],0
@@df:   mov  si,[pfc]
        mov  al,[FCO+si]
        xor  ah,ah
        mov  bx,ax
        add  bx,bx
        add  bx,bx
        add  ax,bx              ; *5
        mov  bx,ax              ; face record offset
        mov  al,[MFACE+bx+4]
        mov  [COLOR],al
        xor  cx,cx              ; corner 0..3
@@dc:   push bx
        push cx
        mov  si,cx
        mov  al,[MFACE+bx+si]
        xor  ah,ah
        add  ax,ax
        mov  si,ax              ; vertex cache offset
        mov  di,cx
        add  di,di              ; IX/IY/IZ slot
        mov  ax,[PVX+si]
        mov  [IX+di],ax
        mov  ax,[PVY+si]
        mov  [IY+di],ax
        mov  ax,[PVZ+si]
        mov  [IZ+di],ax
        pop  cx
        pop  bx
        inc  cx
        cmp  cx,4
        jb   @@dc
        call FACEFILL
        inc  word ptr [pfc]
        cmp  word ptr [pfc],NFACE
        jb   @@df
        ; ---- IFF marker: friendly = green square, hostile = yellow
        ; diamond, sized to the wingspan (11440/rz px half-size) ----
        mov  ax,[pdz]
        cmp  ax,NEARZ
        jle  @@nomk
        mov  ax,[pdx]
        mov  dx,[pdy]
        mov  cx,[pdz]
        call PPOINT
        jc   @@nomk
        mov  [dsx],ax           ; marker centre on screen
        mov  [dsy],dx
        mov  bx,[pdz]
        mov  ax,11440
        cwd
        idiv bx
        add  ax,3
        cmp  ax,24
        jle  @@mr1
        mov  ax,24
@@mr1:  mov  [dsac],ax          ; half-size
        test word ptr [pidx],2
        jnz  @@hst
        ; friendly: green square
        mov  byte ptr [COLOR],95
        mov  ax,[dsx]
        sub  ax,[dsac]
        mov  [sx0],ax
        mov  ax,[dsx]
        add  ax,[dsac]
        mov  [sx1],ax
        mov  ax,[dsy]
        sub  ax,[dsac]
        mov  [sy0],ax
        mov  [sy1],ax
        call @@mln              ; top
        mov  ax,[dsx]
        sub  ax,[dsac]
        mov  [sx0],ax
        mov  ax,[dsx]
        add  ax,[dsac]
        mov  [sx1],ax
        mov  ax,[dsy]
        add  ax,[dsac]
        mov  [sy0],ax
        mov  [sy1],ax
        call @@mln              ; bottom
        mov  ax,[dsx]
        sub  ax,[dsac]
        mov  [sx0],ax
        mov  [sx1],ax
        mov  ax,[dsy]
        sub  ax,[dsac]
        mov  [sy0],ax
        mov  ax,[dsy]
        add  ax,[dsac]
        mov  [sy1],ax
        call @@mln              ; left
        mov  ax,[dsx]
        add  ax,[dsac]
        mov  [sx0],ax
        mov  [sx1],ax
        mov  ax,[dsy]
        sub  ax,[dsac]
        mov  [sy0],ax
        mov  ax,[dsy]
        add  ax,[dsac]
        mov  [sy1],ax
        call @@mln              ; right
        jmp  @@nomk
@@hst:  ; hostile: yellow diamond
        mov  byte ptr [COLOR],96
        mov  ax,[dsx]
        mov  [sx0],ax
        mov  ax,[dsy]
        sub  ax,[dsac]
        mov  [sy0],ax
        mov  ax,[dsx]
        add  ax,[dsac]
        mov  [sx1],ax
        mov  ax,[dsy]
        mov  [sy1],ax
        call @@mln              ; top -> right
        mov  ax,[dsx]
        add  ax,[dsac]
        mov  [sx0],ax
        mov  ax,[dsy]
        mov  [sy0],ax
        mov  ax,[dsx]
        mov  [sx1],ax
        mov  ax,[dsy]
        add  ax,[dsac]
        mov  [sy1],ax
        call @@mln              ; right -> bottom
        mov  ax,[dsx]
        mov  [sx0],ax
        mov  ax,[dsy]
        add  ax,[dsac]
        mov  [sy0],ax
        mov  ax,[dsx]
        sub  ax,[dsac]
        mov  [sx1],ax
        mov  ax,[dsy]
        mov  [sy1],ax
        call @@mln              ; bottom -> left
        mov  ax,[dsx]
        sub  ax,[dsac]
        mov  [sx0],ax
        mov  ax,[dsy]
        mov  [sy0],ax
        mov  ax,[dsx]
        mov  [sx1],ax
        mov  ax,[dsy]
        sub  ax,[dsac]
        mov  [sy1],ax
        call @@mln              ; left -> top
        jmp  @@nomk
@@mln:  call CLIPLINE
        jc   @@mlx
        call LINE
@@mlx:  ret
@@nomk:
@@skip:
        add  word ptr [pidx],2
        cmp  word ptr [pidx],NPLANE*2
        jb   @@pd
        ret

; ---------------------------------------------------------------------------
;  PPOINT - project one camera-space point (yaw-rotated, not yet pitched).
;  in: AX=rx, DX=ry, CX=rz. Applies the PITCH4 rotation, then PROJPT
;  (bank + sway + clamps). out: AX=sx, DX=sy; carry set = behind camera.
;  Clobbers everything PROJPT does, plus dsx/dsy/dsac.
; ---------------------------------------------------------------------------
PPOINT: mov  [dsx],ax           ; rx
        mov  [dsy],dx           ; ry
        mov  [dsac],cx          ; rz
        mov  ax,dx              ; y' = (ry*pcos - rz*psin)/256
        imul word ptr [pcos]
        mov  bx,256
        idiv bx
        mov  cx,ax
        mov  ax,[dsac]
        imul word ptr [psin]
        mov  bx,256
        idiv bx
        sub  cx,ax
        push cx                 ; y'
        mov  ax,[dsy]           ; z' = (ry*psin + rz*pcos)/256
        imul word ptr [psin]
        mov  bx,256
        idiv bx
        mov  cx,ax
        mov  ax,[dsac]
        imul word ptr [pcos]
        mov  bx,256
        idiv bx
        add  ax,cx
        pop  dx                 ; y'
        cmp  ax,NEARZ
        jl   @@behind
        mov  cx,ax
        mov  ax,[dsx]
        call PROJPT             ; AX=sx, DX=sy
        clc
        ret
@@behind:
        stc
        ret
