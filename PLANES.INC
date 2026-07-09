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
        mov  bx,si              ; the dead stay dead - attrition war
        shr  bx,1
        cmp  byte ptr [pst+bx],0
        je   @@fly
        jmp  @@next
@@fly:
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
        jl   @@trl              ; inside the leash: go drop a trail point
@@resp: mov  ax,[locki]         ; a teleported target is a lost target
        cmp  ax,si
        jne  @@rlk
        mov  word ptr [locki],0FFFFh
@@rlk:  push si                 ; the SAME jet teleports: callsign and
                                ; armour stay (no fake reincarnation)
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
        mov  bx,si              ; a teleported jet must not leave its old
        mov  cl,4               ; contrail hanging in the sky: reseed the
        shl  bx,cl              ; whole ring at the new position
        mov  cx,TLN
@@rtf:  mov  ax,[pax+si]
        mov  [TLX+bx],ax
        mov  ax,[pay+si]
        mov  [TLY+bx],ax
        mov  ax,[paz+si]
        mov  [TLZ+bx],ax
        add  bx,2
        loop @@rtf
@@trl:  ; drop a contrail point every 8th tick
        mov  ax,[lasttk]
        and  ax,7
        jnz  @@next
        mov  bx,si
        mov  cl,4
        shl  bx,cl              ; slot base = plane*TLN*2 (TLN=16)
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
@@nth:  ; ---- attrition: when a team is wiped, run the victory banner,
        ; then field two fresh squadrons (scores carry over) ----
        cmp  word ptr [rndovr],0
        je   @@rchk
        dec  word ptr [rndovr]
        jnz  @@rret
        call RESPAWNALL
        jmp  @@rret
@@rchk: xor  cx,cx              ; cl = friendlies alive, ch = hostiles
        xor  si,si
@@rc:   mov  bx,si
        shr  bx,1
        cmp  byte ptr [pst+bx],0
        jne  @@rcn
        test si,2
        jnz  @@rch
        inc  cl
        jmp  @@rcn
@@rch:  inc  ch
@@rcn:  add  si,2
        cmp  si,NPLANE*2
        jb   @@rc
        cmp  byte ptr [dying],0 ; the player is a green too: while he
        jne  @@rcp              ; fights, the team stands
        inc  cl
@@rcp:  test cl,cl
        jnz  @@rc2
        mov  byte ptr [rwin],1  ; the hostiles hold the sky
        mov  word ptr [rndovr],160
        jmp  @@rret
@@rc2:  test ch,ch
        jnz  @@rret
        mov  byte ptr [rwin],0
        mov  word ptr [rndovr],160
@@rret: ret

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
        mov  bx,si              ; dead jets are debris, not aircraft
        shr  bx,1
        cmp  byte ptr [pst+bx],0
        jne  @@skip
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
        mov  cl,4
        shl  bx,cl
        mov  [pfc],bx           ; slot base (TLN=16)
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
        mov  al,8               ; white vapour, 2 px - visible on the sky
        mov  es:[di],al
        mov  es:[di+1],al
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
        mov  ax,[hitfx]         ; cannon-hit sparkle: a yellow star
        cmp  ax,[pidx]
        jne  @@nfl
        cmp  word ptr [hitft],0
        je   @@nfl
        mov  ax,[dsx]
        cmp  ax,3
        jl   @@nfl
        cmp  ax,316
        jg   @@nfl
        mov  ax,[dsy]
        cmp  ax,3
        jl   @@nfl
        cmp  ax,188
        jg   @@nfl
        call ROW320
        add  di,[dsx]
        mov  al,96
        mov  es:[di],al
        mov  es:[di-2],al
        mov  es:[di+2],al
        mov  es:[di-640],al
        mov  es:[di+640],al
        mov  al,8
        mov  es:[di-321],al
        mov  es:[di+321],al
        mov  es:[di-319],al
        mov  es:[di+319],al
@@nfl:  mov  bx,[pdz]
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
        ; friendly: green square (red when locked)
        mov  byte ptr [COLOR],95
        mov  ax,[locki]
        cmp  ax,[pidx]
        jne  @@fc1
        mov  byte ptr [COLOR],19
@@fc1:
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
        jmp  @@mlbl
@@hst:  ; hostile: yellow diamond (red when locked)
        mov  byte ptr [COLOR],96
        mov  ax,[locki]
        cmp  ax,[pidx]
        jne  @@hc1
        mov  byte ptr [COLOR],19
@@hc1:
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
@@mlbl: ; ---- the callsign under the marker (close targets only) ----
        cmp  word ptr [dsac],6
        jl   @@nomk             ; a distant dot stays a dot
        mov  ax,[dsx]
        cmp  ax,20              ; FDRAW has no clipping: stay on screen
        jl   @@nomk
        cmp  ax,299
        jg   @@nomk
        mov  ax,[dsy]
        add  ax,[dsac]
        add  ax,3
        cmp  ax,2
        jl   @@nomk
        cmp  ax,185
        jg   @@nomk
        mov  [fty],ax
        mov  ax,[dsx]
        sub  ax,14
        mov  [ftx],ax
        mov  si,[pidx]
        call CSDRAW             ; marker colour carries over (red = locked)
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

; ---------------------------------------------------------------------------
;  LOCKHUD - the aiming ring at (160,100), r=20 dotted. White when free;
;  IFF-coloured when locked. A locked target off the screen gets a small
;  block riding the ring edge toward it; TARGET/FRIEND + callsign are
;  printed under the ring.
; ---------------------------------------------------------------------------
LOCKHUD:
        cmp  byte ptr [chsview],0
        jne  @@lkoff
        cmp  byte ptr [tgtcam],0
        jne  @@lkoff
        cmp  byte ptr [dying],0
        je   @@lkh
@@lkoff:
        ret                     ; no glass to project the ring on
@@lkh:  mov  word ptr [dsac],8
        cmp  word ptr [phit],0  ; taking fire: the ring flashes red
        je   @@lh0
        mov  word ptr [dsac],19
        jmp  @@ring
@@lh0:  mov  ax,[locki]
        cmp  ax,0FFFFh
        je   @@ring
        mov  word ptr [dsac],95
        test ax,2
        jz   @@ring
        mov  word ptr [dsac],19
@@ring: mov  word ptr [tpi],0
@@ck:   mov  ax,[tpi]
        call SINQ
        mov  bx,20
        imul bx
        mov  bx,256
        idiv bx
        add  ax,160
        mov  [dsx],ax
        mov  ax,[tpi]
        add  ax,64
        call SINQ
        mov  bx,20
        imul bx
        mov  bx,256
        idiv bx
        mov  bx,100
        sub  bx,ax
        mov  ax,bx
        call ROW320
        add  di,[dsx]
        mov  ax,[dsac]
        mov  es:[di],al
        add  word ptr [tpi],16
        cmp  word ptr [tpi],256
        jb   @@ck
        mov  si,[locki]
        cmp  si,0FFFFh
        je   @@done
        ; where is the target on screen?
        mov  ax,[pax+si]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[paz+si]
        sub  ax,[camz]
        mov  [wdz],ax
        push si
        call ROTXZ
        pop  si
        mov  dx,[pay+si]
        sub  dx,[camy]
        mov  ax,[rcx]
        mov  cx,[rcz]
        push si
        call PPOINT
        pop  si
        jc   @@offs
        cmp  ax,0
        jl   @@dir
        cmp  ax,319
        jg   @@dir
        cmp  dx,0
        jl   @@dir
        cmp  dx,191
        jg   @@dir
        jmp  @@text             ; visible: its marker is already red
@@offs: mov  ax,160             ; behind us: point straight down
        mov  dx,192
@@dir:  sub  ax,160             ; shrink the direction onto the ring edge
        sub  dx,100
@@hv:   mov  bx,ax
        or   bx,bx
        jns  @@a1
        neg  bx
@@a1:   cmp  bx,18
        jg   @@shr
        mov  bx,dx
        or   bx,bx
        jns  @@a2
        neg  bx
@@a2:   cmp  bx,18
        jle  @@pt
@@shr:  sar  ax,1
        sar  dx,1
        jmp  @@hv
@@pt:   add  ax,160
        add  dx,100
        mov  [dsx],ax
        mov  ax,dx
        call ROW320
        add  di,[dsx]
        mov  ax,[dsac]
        mov  es:[di],al
        mov  es:[di+1],al
        mov  es:[di+320],al
        mov  es:[di+321],al
@@text: mov  si,[locki]
        mov  byte ptr [COLOR],19
        mov  bx,offset MSGTGT
        test si,2
        jnz  @@t2
        mov  byte ptr [COLOR],95
        mov  bx,offset MSGFRD
@@t2:   mov  word ptr [ftx],148
        mov  word ptr [fty],124
        push si
        mov  si,bx
        call FDRAW
        pop  si
        mov  word ptr [ftx],142
        mov  word ptr [fty],132
        call CSDRAW
@@done: cmp  word ptr [rndovr],0
        je   @@nob
        mov  ax,[lasttk]        ; the victory banner blinks
        test ax,4
        jz   @@nob
        cmp  byte ptr [rwin],0
        jne  @@bw
        mov  byte ptr [COLOR],95
        mov  word ptr [ftx],140
        mov  word ptr [fty],44
        mov  si,offset MSGVWIN
        call FDRAW
        jmp  @@nob
@@bw:   mov  byte ptr [COLOR],96
        mov  word ptr [ftx],138
        mov  word ptr [fty],44
        mov  si,offset MSGBWIN
        call FDRAW
@@nob:  ret

; ---------------------------------------------------------------------------
;  CSDRAW - print the callsign of plane SI (offset) at ftx/fty in the
;  current COLOR: pool name (friendly/hostile by parity) + number.
; ---------------------------------------------------------------------------
CSDRAW: push si
        mov  bx,si
        shr  bx,1
        mov  al,[pcs+bx]
        xor  ah,ah
        add  ax,ax
        mov  bx,ax
        pop  ax                 ; plane offset
        push ax
        test ax,2
        jnz  @@hn
        mov  si,[FNTAB+bx]
        jmp  @@nm
@@hn:   mov  si,[HNTAB+bx]
@@nm:   call FDRAW
        add  word ptr [ftx],2
        pop  bx
        shr  bx,1
        mov  al,[pnum+bx]
        xor  ah,ah
        call FNUM
        ret

; ---------------------------------------------------------------------------
;  TGTVIEW - sensor view of the locked target on the green MFD: callsign,
;  a wireframe of the jet (aspect follows its heading) and the IFF tag.
; ---------------------------------------------------------------------------
TGTVIEW:
        mov  si,[locki]
        mov  byte ptr [COLOR],8
        mov  word ptr [ftx],197
        mov  word ptr [fty],155
        call CSDRAW
        mov  si,[locki]
        mov  byte ptr [COLOR],19
        mov  bx,offset MSGTGT
        test si,2
        jnz  @@tg
        mov  byte ptr [COLOR],95
        mov  bx,offset MSGFRD
@@tg:   mov  word ptr [ftx],197
        mov  word ptr [fty],182
        push si
        mov  si,bx
        call FDRAW
        pop  si
        ; wireframe: rotate the model by its aspect, project small
        mov  ax,[pah+si]
        sub  ax,[heading]
        and  ax,255
        push ax
        call SINQ
        mov  [msin],ax
        pop  ax
        add  ax,64
        call SINQ
        mov  [mcos],ax
        xor  si,si
        xor  di,di
@@tv2:  mov  ax,[MVERT+si]      ; vx = (mx*mcos + mz*msin)/256
        imul word ptr [mcos]
        mov  bx,ax
        mov  ax,[MVERT+si+4]
        imul word ptr [msin]
        add  ax,bx
        cwd
        mov  bx,256
        idiv bx
        mov  [dsx],ax
        mov  ax,[MVERT+si]      ; vz = (mz*mcos - mx*msin)/256 + 300
        imul word ptr [msin]
        mov  bx,ax
        mov  ax,[MVERT+si+4]
        imul word ptr [mcos]
        sub  ax,bx
        cwd
        mov  bx,256
        idiv bx
        add  ax,300
        mov  [dsac],ax
        mov  ax,[dsx]           ; sx = 217 + vx*64/vz
        mov  bx,64
        imul bx
        idiv word ptr [dsac]
        add  ax,217
        mov  [PVX+di],ax
        mov  ax,[MVERT+si+2]    ; sy = 170 - vy*64/vz
        mov  bx,64
        imul bx
        idiv word ptr [dsac]
        mov  bx,170
        sub  bx,ax
        mov  [PVY+di],bx
        add  si,6
        add  di,2
        cmp  si,13*6
        jb   @@tv2
        xor  si,si              ; sensor-green edges
@@te:   mov  al,[WEDG+si]
        xor  ah,ah
        add  ax,ax
        mov  bx,ax
        mov  ax,[PVX+bx]
        mov  [sx0],ax
        mov  ax,[PVY+bx]
        mov  [sy0],ax
        mov  al,[WEDG+si+1]
        xor  ah,ah
        add  ax,ax
        mov  bx,ax
        mov  ax,[PVX+bx]
        mov  [sx1],ax
        mov  ax,[PVY+bx]
        mov  [sy1],ax
        mov  byte ptr [COLOR],95
        push si
        call CLIPLINE
        jc   @@ten
        call LINE
@@ten:  pop  si
        add  si,2
        cmp  si,NWEDG*2
        jb   @@te
        ret

; ---------------------------------------------------------------------------
;  MSLUPD - one tick of the missile: home on the lock target (or fly
;  straight), proximity-fuse against every living jet, die by timer.
; ---------------------------------------------------------------------------
MSLUPD: cmp  byte ptr [msact],0
        je   @@out
        dec  word ptr [mlife]
        jnz  @@mv
        mov  byte ptr [msact],0 ; burned out
        ret
@@mv:   mov  ax,[msx]           ; remember the old spot (exhaust puff)
        mov  [mpx],ax
        mov  ax,[msy]
        mov  [mpy],ax
        mov  ax,[msz]
        mov  [mpz],ax
        mov  si,[mstgt]
        cmp  si,0FFFFh
        je   @@str
        mov  bx,si              ; target died mid-flight? go ballistic
        shr  bx,1
        cmp  byte ptr [pst+bx],0
        je   @@home
        mov  word ptr [mstgt],0FFFFh
@@str:  mov  ax,[mvx]           ; straight: the velocity set at launch
        add  [msx],ax
        mov  ax,[mvy]
        add  [msy],ax
        mov  ax,[mvz]
        add  [msz],ax
        jmp  @@prox
@@home: ; chase at 64/tick, direction normalised by the dominant axis
        mov  ax,[pax+si]
        sub  ax,[msx]
        mov  [wdx],ax           ; dx
        mov  ax,[pay+si]
        sub  ax,[msy]
        mov  [wdz],ax           ; dy (borrowing the scratch)
        mov  ax,[paz+si]
        sub  ax,[msz]
        mov  [ctx],ax           ; dz
        mov  bx,[wdx]           ; m = max of the absolutes
        or   bx,bx
        jns  @@m1
        neg  bx
@@m1:   mov  ax,[wdz]
        or   ax,ax
        jns  @@m2
        neg  ax
@@m2:   cmp  ax,bx
        jle  @@m3
        mov  bx,ax
@@m3:   mov  ax,[ctx]
        or   ax,ax
        jns  @@m4
        neg  ax
@@m4:   cmp  ax,bx
        jle  @@m5
        mov  bx,ax
@@m5:   test bx,bx
        jnz  @@m6
        inc  bx
@@m6:   mov  [cty],bx           ; m
        mov  ax,[wdx]
        mov  cx,64
        imul cx
        idiv word ptr [cty]
        add  [msx],ax
        mov  ax,[wdz]
        mov  cx,64
        imul cx
        idiv word ptr [cty]
        add  [msy],ax
        mov  ax,[ctx]
        mov  cx,64
        imul cx
        idiv word ptr [cty]
        add  [msz],ax
@@prox: ; proximity fuse: |dx|+|dy|+|dz| < 160 pops any living jet
        xor  si,si
@@px:   mov  bx,si
        shr  bx,1
        cmp  byte ptr [pst+bx],0
        jne  @@pxn
        mov  ax,[pax+si]
        sub  ax,[msx]
        jns  @@p1
        neg  ax
@@p1:   cmp  ax,160
        jge  @@pxn
        mov  bx,ax
        mov  ax,[pay+si]
        sub  ax,[msy]
        jns  @@p2
        neg  ax
@@p2:   add  bx,ax
        mov  ax,[paz+si]
        sub  ax,[msz]
        jns  @@p3
        neg  ax
@@p3:   add  bx,ax
        cmp  bx,160
        jge  @@pxn
        call BOOM               ; direct hit: SI = the unlucky jet
        inc  word ptr [psc]     ; chalk one on the canopy
        mov  byte ptr [msact],0
        ret
@@pxn:  add  si,2
        cmp  si,NPLANE*2
        jb   @@px
@@out:  ret

; ---------------------------------------------------------------------------
;  BOOM - break plane SI into its faces. The jet hides behind a respawn
;  timer; a wreck slot (round robin of 4) gets: ground height, per-face
;  world positions with random scatter velocities, and pre-rotated corner
;  offsets, so the debris keeps the jet's shape as it flies apart.
; ---------------------------------------------------------------------------
BOOM:   mov  bx,si
        shr  bx,1
        mov  byte ptr [pst+bx],1 ; down for good (attrition war)
        mov  ax,[locki]
        cmp  ax,si
        jne  @@bk1
        mov  word ptr [locki],0FFFFh
@@bk1:  test si,2               ; scoreboard: the other team scores
        jnz  @@bsc
        inc  word ptr [tsch]    ; a friendly fell
        jmp  @@bsd
@@bsc:  inc  word ptr [tscf]    ; a hostile fell
@@bsd:  mov  ax,[pax+si]        ; hand the breakup spot to WRKFILL
        mov  [bpx],ax
        mov  ax,[pay+si]
        mov  [bpy],ax
        mov  ax,[paz+si]
        mov  [bpz],ax
        mov  ax,[pah+si]
        mov  [bph],ax
        jmp  WRKFILL

; PBOOM - the PLAYER breaks apart (cinematic death).
PBOOM:  mov  ax,[camx]
        mov  [bpx],ax
        mov  ax,[camy]
        mov  [bpy],ax
        mov  ax,[camz]
        mov  [bpz],ax
        mov  ax,[heading]
        mov  [bph],ax
        jmp  WRKFILL

; ---------------------------------------------------------------------------
;  WRKFILL - break a jet at (bpx,bpy,bpz) heading bph into a wreck slot:
;  ground height, per-face world positions with random scatter velocities,
;  pre-rotated corner offsets. Shared by BOOM (AI) and PBOOM (player).
; ---------------------------------------------------------------------------
WRKFILL:
        mov  di,[wnext]         ; claim a wreck slot
        add  word ptr [wnext],WRKSZ
        cmp  word ptr [wnext],WRKSZ*4
        jb   @@bk2
        mov  word ptr [wnext],0
@@bk2:  add  di,offset WRK
        mov  word ptr [di],1    ; wtim = 1: alive and burning
        ; ground height under the kill (TERRH reads camx/camz: swap in)
        push word ptr [camx]
        push word ptr [camz]
        mov  ax,[bpx]
        mov  [camx],ax
        mov  ax,[bpz]
        mov  [camz],ax
        push di
        call TERRH
        pop  di
        pop  word ptr [camz]
        pop  word ptr [camx]
        add  ax,6               ; debris rests a touch above the slope
        mov  [di+2],ax          ; wgy
        ; the dying jet's orientation
        mov  ax,[bph]
        push di
        call SINQ
        mov  [msin],ax
        pop  di
        mov  ax,[bph]
        add  ax,64
        push di
        call SINQ
        mov  [mcos],ax
        pop  di
        ; ---- per face: centroid -> world position + velocity + corners ----
        mov  word ptr [tpi],0   ; face index
@@bf:   ; centroid = avg of the face's 4 vertices (model space)
        xor  ax,ax
        mov  [ctx],ax
        mov  [cty],ax
        mov  [ctz],ax
        mov  word ptr [wcc],0
@@bc:   mov  bx,[tpi]
        add  bx,bx
        add  bx,bx
        mov  ax,[tpi]
        add  bx,ax              ; MFACE record = f*5
        mov  ax,[wcc]
        add  bx,ax
        mov  al,[MFACE+bx]
        xor  ah,ah
        mov  bx,ax
        add  bx,bx
        add  bx,ax
        add  bx,bx              ; vertex id * 6
        mov  ax,[MVERT+bx]
        add  [ctx],ax
        mov  ax,[MVERT+bx+2]
        add  [cty],ax
        mov  ax,[MVERT+bx+4]
        add  [ctz],ax
        inc  word ptr [wcc]
        cmp  word ptr [wcc],4
        jb   @@bc
        mov  ax,[ctx]
        sar  ax,1
        sar  ax,1
        mov  [ctx],ax
        mov  ax,[cty]
        sar  ax,1
        sar  ax,1
        mov  [cty],ax
        mov  ax,[ctz]
        sar  ax,1
        sar  ax,1
        mov  [ctz],ax
        ; face record base = di + WFP + f*12
        mov  bx,[tpi]
        add  bx,bx
        add  bx,bx
        mov  ax,[tpi]
        add  ax,ax
        add  ax,ax
        add  ax,ax
        add  bx,ax              ; f*12
        add  bx,di
        add  bx,WFP
        push bx
        mov  ax,[ctx]           ; world position = jet + rot(centroid)
        mov  dx,[ctz]
        call ROTMS
        pop  bx
        add  ax,[bpx]
        mov  [bx],ax            ; fx
        add  dx,[bpz]
        mov  [bx+4],dx          ; fz
        mov  ax,[cty]
        add  ax,[bpy]
        mov  [bx+2],ax          ; fy
        push bx                 ; scatter velocities
        call RND16
        pop  bx
        and  ax,31
        sub  ax,16
        mov  [bx+6],ax          ; vx
        push bx
        call RND16
        pop  bx
        and  ax,15
        add  ax,6
        mov  [bx+8],ax          ; vy: pops up, gravity brings it down
        push bx
        call RND16
        pop  bx
        and  ax,31
        sub  ax,16
        mov  [bx+10],ax         ; vz
        ; ---- corners: pre-rotated offsets from the face centre ----
        mov  word ptr [wcc],0
@@bo:   mov  bx,[tpi]
        add  bx,bx
        add  bx,bx
        mov  ax,[tpi]
        add  bx,ax              ; f*5
        mov  ax,[wcc]
        add  bx,ax
        mov  al,[MFACE+bx]
        xor  ah,ah
        mov  bx,ax
        add  bx,bx
        add  bx,ax
        add  bx,bx              ; vid*6
        mov  ax,[MVERT+bx]
        sub  ax,[ctx]
        push word ptr [MVERT+bx+2]
        mov  dx,[MVERT+bx+4]
        sub  dx,[ctz]
        call ROTMS              ; AX/DX = rotated x/z offsets
        mov  bx,[tpi]           ; corner slot = di + WCO + f*24 + c*6
        push ax
        mov  ax,bx
        add  bx,bx
        add  bx,ax              ; f*3
        mov  cl,3
        shl  bx,cl              ; f*24
        mov  ax,[wcc]
        add  bx,ax
        add  bx,ax
        add  bx,ax
        add  bx,ax
        add  bx,ax
        add  bx,ax              ; + c*6
        add  bx,di
        add  bx,WCO
        pop  ax
        mov  [bx],ax            ; ox
        mov  [bx+4],dx          ; oz
        pop  ax                 ; raw model y
        sub  ax,[cty]
        mov  [bx+2],ax          ; oy
        inc  word ptr [wcc]
        cmp  word ptr [wcc],4
        jb   @@bo
        inc  word ptr [tpi]
        cmp  word ptr [tpi],NFACE
        jb   @@bf
        ret

; ---------------------------------------------------------------------------
;  ROTMS - rotate (AX=x, DX=z) by msin/mcos:
;  x' = (x*mcos + z*msin)/256 ; z' = (z*mcos - x*msin)/256.
; ---------------------------------------------------------------------------
ROTMS:  mov  [dsx],ax
        mov  [dsy],dx
        imul word ptr [mcos]
        mov  bx,ax
        mov  ax,[dsy]
        imul word ptr [msin]
        add  ax,bx
        cwd
        mov  bx,256
        idiv bx
        push ax
        mov  ax,[dsx]
        imul word ptr [msin]
        mov  bx,ax
        mov  ax,[dsy]
        imul word ptr [mcos]
        sub  ax,bx
        cwd
        mov  bx,256
        idiv bx
        mov  dx,ax
        pop  ax
        ret

; ---------------------------------------------------------------------------
;  WRECKUPD - one tick of the debris: fly apart, fall (gravity 3/tick),
;  stop on the ground. Landed pieces zero their velocities and stay.
; ---------------------------------------------------------------------------
WRECKUPD:
        mov  di,offset WRK
        mov  word ptr [tpi],4   ; wreck slots
@@ww:   cmp  word ptr [di],0
        je   @@wn
        cmp  word ptr [di],30000
        jae  @@wf
        inc  word ptr [di]      ; age (burns while < 600)
@@wf:   mov  bx,WFP
@@wp:   mov  ax,[bx+di+6]       ; fx += vx
        add  [bx+di],ax
        mov  ax,[bx+di+10]      ; fz += vz
        add  [bx+di+4],ax
        mov  ax,[bx+di+8]
        sub  ax,3               ; gravity
        mov  [bx+di+8],ax
        add  [bx+di+2],ax       ; fy += vy
        mov  ax,[di+2]          ; wgy
        cmp  [bx+di+2],ax
        jg   @@wg
        mov  [bx+di+2],ax       ; grounded: rest and stop
        xor  ax,ax
        mov  [bx+di+6],ax
        mov  [bx+di+8],ax
        mov  [bx+di+10],ax
@@wg:   add  bx,12
        cmp  bx,WFP+8*12
        jb   @@wp
@@wn:   add  di,WRKSZ
        dec  word ptr [tpi]
        jnz  @@ww
        ret

; ---------------------------------------------------------------------------
;  WRECKDRAW - the fallen jets: each face is a quad at its debris position
;  (pre-rotated corner offsets), plus flickering fire (glow 94) and rising
;  smoke dots while the wreck still burns (wtim < 600).
; ---------------------------------------------------------------------------
WRECKDRAW:
        mov  word ptr [pidx],0  ; wreck slot index 0..3
@@wd:   mov  ax,WRKSZ
        imul word ptr [pidx]
        mov  di,ax
        add  di,offset WRK
        cmp  word ptr [di],0
        je   @@wdn
        mov  ax,[di+WFP]        ; reject by the first face's position
        sub  ax,[camx]
        jns  @@wq1
        neg  ax
@@wq1:  cmp  ax,9000
        jge  @@wdn
        mov  ax,[di+WFP+4]
        sub  ax,[camz]
        jns  @@wq2
        neg  ax
@@wq2:  cmp  ax,9000
        jge  @@wdn
        ; ---- the eight faces ----
        mov  word ptr [pfc],0
@@wface:
        mov  bx,[pfc]
        add  bx,bx
        add  bx,bx
        mov  ax,[pfc]
        add  ax,ax
        add  ax,ax
        add  ax,ax
        add  bx,ax              ; f*12
        add  bx,di
        add  bx,WFP
        mov  [ctx],bx           ; -> face record
        mov  bx,[pfc]           ; colour from the model table
        add  bx,bx
        add  bx,bx
        mov  ax,[pfc]
        add  bx,ax              ; f*5
        mov  al,[MFACE+bx+4]
        mov  [COLOR],al
        mov  word ptr [wcc],0   ; four corners -> IX/IY/IZ
@@wc:   mov  bx,[pfc]
        mov  ax,bx
        add  bx,bx
        add  bx,ax              ; f*3
        mov  cl,3
        shl  bx,cl              ; f*24
        mov  ax,[wcc]
        add  bx,ax
        add  bx,ax
        add  bx,ax
        add  bx,ax
        add  bx,ax
        add  bx,ax              ; + c*6
        add  bx,di
        add  bx,WCO
        mov  si,[ctx]           ; face record
        mov  ax,[si]            ; fx + ox
        add  ax,[bx]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[si+4]          ; fz + oz
        add  ax,[bx+4]
        sub  ax,[camz]
        mov  [wdz],ax
        mov  ax,[si+2]          ; fy + oy
        add  ax,[bx+2]
        sub  ax,[camy]
        push ax
        push di
        call ROTXZ
        pop  di
        pop  ax
        mov  si,[wcc]
        add  si,si
        mov  [IY+si],ax
        mov  ax,[rcx]
        mov  [IX+si],ax
        mov  ax,[rcz]
        mov  [IZ+si],ax
        inc  word ptr [wcc]
        cmp  word ptr [wcc],4
        jb   @@wc
        push di
        call FACEFILL
        pop  di
        inc  word ptr [pfc]
        cmp  word ptr [pfc],NFACE
        jb   @@wface
        ; ---- fire and smoke while it burns ----
        cmp  word ptr [di],600
        jae  @@wdn
        mov  word ptr [wcc],0   ; three plumes on faces 0, 3 and 6
@@wsm:  mov  ax,[wcc]
        mov  bx,36
        imul bx                 ; face k*3 record = k*36 bytes
        mov  bx,ax
        add  bx,di
        add  bx,WFP             ; -> face record
        ; fire: flickering glow block right at the piece
        mov  ax,[lasttk]
        test ax,2
        jz   @@wfm
        mov  ax,[bx]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[bx+4]
        sub  ax,[camz]
        mov  [wdz],ax
        mov  ax,[bx+2]
        sub  ax,[camy]
        add  ax,6
        mov  [ctz],ax           ; ry for later
        push bx
        push di
        call ROTXZ
        mov  dx,[ctz]
        mov  ax,[rcx]
        mov  cx,[rcz]
        call PPOINT
        pop  di
        pop  bx
        jc   @@wfm
        cmp  ax,0
        jl   @@wfm
        cmp  ax,318
        jg   @@wfm
        cmp  dx,0
        jl   @@wfm
        cmp  dx,190
        jg   @@wfm
        push bx
        push di
        mov  [dsx],ax
        mov  ax,dx
        call ROW320
        add  di,[dsx]
        mov  al,94              ; palette-cycled fire
        mov  es:[di],al
        mov  es:[di+1],al
        mov  es:[di+320],al
        mov  es:[di+321],al
        pop  di
        pop  bx
@@wfm:  ; smoke: a grey dot climbing out of the same piece
        mov  ax,[wcc]
        mov  cx,40
        imul cx
        mov  cx,[lasttk]
        add  cx,cx
        add  ax,cx
        and  ax,127             ; rising phase 0..127
        mov  [ctz],ax
        mov  ax,[bx]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[bx+4]
        sub  ax,[camz]
        mov  [wdz],ax
        mov  ax,[bx+2]
        sub  ax,[camy]
        add  ax,10
        add  ax,[ctz]
        mov  [ctz],ax
        push di
        call ROTXZ
        mov  dx,[ctz]
        mov  ax,[rcx]
        mov  cx,[rcz]
        call PPOINT
        pop  di
        jc   @@wsn
        cmp  ax,0
        jl   @@wsn
        cmp  ax,319
        jg   @@wsn
        cmp  dx,0
        jl   @@wsn
        cmp  dx,191
        jg   @@wsn
        push di
        mov  [dsx],ax
        mov  ax,dx
        call ROW320
        add  di,[dsx]
        mov  al,25              ; smoke grey
        mov  es:[di],al
        pop  di
@@wsn:  inc  word ptr [wcc]
        cmp  word ptr [wcc],3
        jb   @@wsm
@@wdn:  inc  word ptr [pidx]
        cmp  word ptr [pidx],4
        jb   @@wd
        ret

; ---------------------------------------------------------------------------
;  MSLDRAW - the missile in flight: a burning 2x2 dot (glow 94) and a
;  little grey exhaust puff at its previous position.
; ---------------------------------------------------------------------------
MSLDRAW:
        cmp  byte ptr [msact],0
        je   @@no
        mov  ax,[msx]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[msz]
        sub  ax,[camz]
        mov  [wdz],ax
        call ROTXZ
        mov  dx,[msy]
        sub  dx,[camy]
        mov  ax,[rcx]
        mov  cx,[rcz]
        call PPOINT
        jc   @@puff
        cmp  ax,0
        jl   @@puff
        cmp  ax,318
        jg   @@puff
        cmp  dx,0
        jl   @@puff
        cmp  dx,190
        jg   @@puff
        mov  [dsx],ax
        mov  ax,dx
        call ROW320
        add  di,[dsx]
        mov  al,94              ; the motor burns with the engine palette
        mov  es:[di],al
        mov  es:[di+1],al
        mov  es:[di+320],al
        mov  es:[di+321],al
@@puff: mov  ax,[mpx]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[mpz]
        sub  ax,[camz]
        mov  [wdz],ax
        call ROTXZ
        mov  dx,[mpy]
        sub  dx,[camy]
        mov  ax,[rcx]
        mov  cx,[rcz]
        call PPOINT
        jc   @@no
        cmp  ax,0
        jl   @@no
        cmp  ax,319
        jg   @@no
        cmp  dx,0
        jl   @@no
        cmp  dx,191
        jg   @@no
        mov  [dsx],ax
        mov  ax,dx
        call ROW320
        add  di,[dsx]
        mov  al,25              ; exhaust puff
        mov  es:[di],al
@@no:   ret

; ---------------------------------------------------------------------------
;  AMSLUPD - the AI's war: every couple of seconds a random living jet
;  fires a homing missile (pool of NAMSL) at the first living enemy in
;  ~7000 range. Missiles chase at 56/tick and pop the target via BOOM.
;  Nobody shoots at the player - yet.
; ---------------------------------------------------------------------------
AMSLUPD:
        cmp  word ptr [aifire],0
        je   @@tcy
        dec  word ptr [aifire]
        jmp  @@fly
@@tcy:  mov  word ptr [aifire],24
        xor  bx,bx              ; a free launch rail?
@@fs:   cmp  byte ptr [amact+bx],0
        je   @@have
        inc  bx
        cmp  bx,NAMSL
        jb   @@fs
        jmp  @@fly
@@have: mov  [wcc],bx           ; slot index
        call RND16              ; random shooter
        and  ax,31
        add  ax,ax
        mov  si,ax              ; shooter offset
        mov  bx,si
        shr  bx,1
        cmp  byte ptr [pst+bx],0
        jne  @@fly
        mov  dx,si              ; hunt the OTHER team
        and  dx,2
        xor  dx,2
        xor  di,di
@@tg:   mov  bx,di
        and  bx,2
        cmp  bx,dx
        jne  @@tgn
        mov  bx,di
        shr  bx,1
        cmp  byte ptr [pst+bx],0
        jne  @@tgn
        mov  ax,[pax+di]
        sub  ax,[pax+si]
        jns  @@g1
        neg  ax
@@g1:   mov  bx,ax
        cmp  bx,10000
        jge  @@tgn
        mov  ax,[paz+di]
        sub  ax,[paz+si]
        jns  @@g2
        neg  ax
@@g2:   add  bx,ax
        cmp  bx,10000
        jl   @@shoot
@@tgn:  add  di,2
        cmp  di,NPLANE*2
        jb   @@tg
        jmp  @@fly
@@shoot:
        mov  bx,[wcc]
        mov  byte ptr [amact+bx],1
        add  bx,bx              ; word offset
        mov  ax,[pax+si]
        mov  [amx+bx],ax
        mov  [ampx+bx],ax
        mov  ax,[pay+si]
        sub  ax,10
        mov  [amy+bx],ax
        mov  [ampy+bx],ax
        mov  ax,[paz+si]
        mov  [amz+bx],ax
        mov  [ampz+bx],ax
        mov  [amtgt+bx],di
        mov  word ptr [amlife+bx],160
@@fly:  ; ---- fly the pool ----
        mov  word ptr [wcc],0
@@ml:   mov  bx,[wcc]
        cmp  byte ptr [amact+bx],0
        je   @@mn
        add  bx,bx
        dec  word ptr [amlife+bx]
        jnz  @@go
@@fiz:  mov  bx,[wcc]           ; burned out (or the target died)
        mov  byte ptr [amact+bx],0
        jmp  @@mn
@@go:   mov  ax,[amx+bx]        ; old spot for the puff
        mov  [ampx+bx],ax
        mov  ax,[amy+bx]
        mov  [ampy+bx],ax
        mov  ax,[amz+bx]
        mov  [ampz+bx],ax
        mov  si,[amtgt+bx]
        mov  di,si
        shr  di,1
        cmp  byte ptr [pst+di],0
        jne  @@fiz
        ; chase at 56/tick, dominant-axis normalised
        mov  ax,[pax+si]
        sub  ax,[amx+bx]
        mov  [ctx],ax
        mov  ax,[pay+si]
        sub  ax,[amy+bx]
        mov  [cty],ax
        mov  ax,[paz+si]
        sub  ax,[amz+bx]
        mov  [ctz],ax
        mov  di,[ctx]           ; m = max of the absolutes
        or   di,di
        jns  @@a1
        neg  di
@@a1:   mov  ax,[cty]
        or   ax,ax
        jns  @@a2
        neg  ax
@@a2:   cmp  ax,di
        jle  @@a3
        mov  di,ax
@@a3:   mov  ax,[ctz]
        or   ax,ax
        jns  @@a4
        neg  ax
@@a4:   cmp  ax,di
        jle  @@a5
        mov  di,ax
@@a5:   test di,di
        jnz  @@a6
        inc  di
@@a6:   ; proximity fuse first: manhattan < 160
        mov  ax,[ctx]
        or   ax,ax              ; mov sets no flags
        jns  @@b1
        neg  ax
@@b1:   mov  dx,ax
        mov  ax,[cty]
        or   ax,ax
        jns  @@b2
        neg  ax
@@b2:   add  dx,ax
        mov  ax,[ctz]
        or   ax,ax
        jns  @@b3
        neg  ax
@@b3:   add  dx,ax
        cmp  dx,160
        jge  @@step
        push word ptr [wcc]     ; BOOM reuses this scratch
        call BOOM               ; SI = the target
        pop  word ptr [wcc]
        jmp  @@fiz
@@step: mov  ax,[ctx]
        mov  cx,56
        imul cx
        idiv di
        add  [amx+bx],ax
        mov  ax,[cty]
        mov  cx,56
        imul cx
        idiv di
        add  [amy+bx],ax
        mov  ax,[ctz]
        mov  cx,56
        imul cx
        idiv di
        add  [amz+bx],ax
@@mn:   inc  word ptr [wcc]
        cmp  word ptr [wcc],NAMSL
        jb   @@ml
        ret

; ---------------------------------------------------------------------------
;  AMSLDRAW - the AI missiles: glow dots with exhaust puffs.
; ---------------------------------------------------------------------------
AMSLDRAW:
        mov  word ptr [tpi],0
@@dl:   mov  bx,[tpi]
        cmp  byte ptr [amact+bx],0
        je   @@dn
        add  bx,bx
        mov  ax,[amx+bx]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[amz+bx]
        sub  ax,[camz]
        mov  [wdz],ax
        push bx
        call ROTXZ
        pop  bx
        mov  dx,[amy+bx]
        sub  dx,[camy]
        mov  ax,[rcx]
        mov  cx,[rcz]
        push bx
        call PPOINT
        pop  bx
        jc   @@puff
        cmp  ax,0
        jl   @@puff
        cmp  ax,318
        jg   @@puff
        cmp  dx,0
        jl   @@puff
        cmp  dx,190
        jg   @@puff
        push bx
        mov  [dsx],ax
        mov  ax,dx
        call ROW320
        add  di,[dsx]
        mov  al,94
        mov  es:[di],al
        mov  es:[di+1],al
        mov  es:[di+320],al
        mov  es:[di+321],al
        pop  bx
@@puff: mov  ax,[ampx+bx]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[ampz+bx]
        sub  ax,[camz]
        mov  [wdz],ax
        push bx
        call ROTXZ
        pop  bx
        mov  dx,[ampy+bx]
        sub  dx,[camy]
        mov  ax,[rcx]
        mov  cx,[rcz]
        call PPOINT
        jc   @@dn
        cmp  ax,0
        jl   @@dn
        cmp  ax,319
        jg   @@dn
        cmp  dx,0
        jl   @@dn
        cmp  dx,191
        jg   @@dn
        mov  [dsx],ax
        mov  ax,dx
        call ROW320
        add  di,[dsx]
        mov  al,25
        mov  es:[di],al
@@dn:   inc  word ptr [tpi]
        cmp  word ptr [tpi],NAMSL
        jb   @@dl
        ret

; ---------------------------------------------------------------------------
;  TRCUPD - fly the tracer rounds: straight at ~150/tick with a slight
;  droop, burned out after 30 ticks (~4500 reach, same as the hit test).
; ---------------------------------------------------------------------------
TRCUPD: xor  bx,bx
@@t:    cmp  byte ptr [trcact+bx],0
        je   @@n
        mov  di,bx
        add  di,di
        dec  word ptr [trlif+di]
        jnz  @@f
        mov  byte ptr [trcact+bx],0
        jmp  @@n
@@f:    mov  ax,[trvx+di]
        add  [tcx+di],ax
        mov  ax,[trvy+di]
        add  [tcy+di],ax
        dec  word ptr [trvy+di] ; the round droops as it flies
        mov  ax,[trvz+di]
        add  [tcz+di],ax
@@n:    inc  bx
        cmp  bx,NTRC
        jb   @@t
        ret

; ---------------------------------------------------------------------------
;  GUNDRAW - the tracer rounds: each is a 3D streak from its position
;  half a velocity step back, with a random 1px tumble on the tail and
;  a red/yellow flicker. The rounds keep flying after the trigger is
;  released - the pool renders whatever is still in the air.
; ---------------------------------------------------------------------------
GUNDRAW:
        mov  word ptr [tpi],0
@@gl:   mov  bx,[tpi]
        cmp  byte ptr [trcact+bx],0
        je   @@gn
        mov  di,bx
        add  di,di
        mov  ax,[tcx+di]        ; the head of the streak
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[tcz+di]
        sub  ax,[camz]
        mov  [wdz],ax
        push di
        call ROTXZ
        pop  di
        mov  dx,[tcy+di]
        sub  dx,[camy]
        mov  ax,[rcx]
        mov  cx,[rcz]
        push di
        call PPOINT
        pop  di
        jc   @@gn
        mov  [sx0],ax
        mov  [sy0],dx
        mov  ax,[trvx+di]       ; the tail: half a step behind
        sar  ax,1
        mov  bx,[tcx+di]
        sub  bx,ax
        sub  bx,[camx]
        mov  [wdx],bx
        mov  ax,[trvz+di]
        sar  ax,1
        mov  bx,[tcz+di]
        sub  bx,ax
        sub  bx,[camz]
        mov  [wdz],bx
        mov  ax,[trvy+di]
        sar  ax,1
        mov  dx,[tcy+di]
        sub  dx,ax
        sub  dx,[camy]
        push dx
        push di
        call ROTXZ
        pop  di
        pop  dx
        mov  ax,[rcx]
        mov  cx,[rcz]
        call PPOINT
        jc   @@gn
        push ax                 ; a pinch of tumble on the tail end
        push dx
        call RND16
        mov  bx,ax
        pop  dx
        pop  ax
        mov  cx,bx
        and  cx,3
        dec  cx
        add  ax,cx
        push ax
        mov  ax,bx
        mov  cl,2
        shr  ax,cl
        and  ax,3
        dec  ax
        add  dx,ax
        pop  ax
        mov  [sx1],ax
        mov  [sy1],dx
        mov  byte ptr [COLOR],96
        test bx,1000h
        jz   @@gc
        mov  byte ptr [COLOR],19
@@gc:   call CLIPLINE
        jc   @@gn
        call LINE
@@gn:   inc  word ptr [tpi]
        cmp  word ptr [tpi],NTRC
        jb   @@gl
        ret

; ---------------------------------------------------------------------------
;  AIGUN - knife-range strafing. Every ~0.8 s a random living jet with an
;  enemy (or the player, hostiles only) within 2500 fires a 4-round burst
;  into the shared tracer pool and rolls the dice: 1-in-4 bursts land a
;  hit. Jets lose HP down to the usual BOOM; the player soaks 8 hits,
;  flashes the ring red, and rides the crash screen on the last one.
; ---------------------------------------------------------------------------
AIGUN:  cmp  word ptr [aigt],0
        je   @@go
        dec  word ptr [aigt]
        ret
@@go:   mov  word ptr [aigt],14
        call RND16
        and  ax,31              ; shooter among the first 32
        add  ax,ax
        mov  si,ax
        mov  bx,si
        shr  bx,1
        cmp  byte ptr [pst+bx],0
        jne  @@no
        test si,2               ; hostiles check the player first
        jz   @@ai
        cmp  byte ptr [dying],0
        jne  @@ai               ; the player is already falling
        mov  ax,[camx]
        sub  ax,[pax+si]
        jns  @@p1
        neg  ax
@@p1:   cmp  ax,2500
        jge  @@ai
        mov  bx,ax
        mov  ax,[camz]
        sub  ax,[paz+si]
        jns  @@p2
        neg  ax
@@p2:   add  bx,ax
        cmp  bx,2500
        jge  @@ai
        mov  di,0FFFFh          ; target: the player
        jmp  @@fire
@@ai:   mov  dx,si              ; find a living enemy in knife range
        and  dx,2
        xor  dx,2
        xor  di,di
@@tg:   mov  bx,di
        and  bx,2
        cmp  bx,dx
        jne  @@tn
        mov  bx,di
        shr  bx,1
        cmp  byte ptr [pst+bx],0
        jne  @@tn
        mov  ax,[pax+di]
        sub  ax,[pax+si]
        jns  @@g1
        neg  ax
@@g1:   mov  bx,ax
        cmp  bx,2500
        jge  @@tn
        mov  ax,[paz+di]
        sub  ax,[paz+si]
        jns  @@g2
        neg  ax
@@g2:   add  bx,ax
        cmp  bx,2500
        jl   @@fire
@@tn:   add  di,2
        cmp  di,NPLANE*2
        jb   @@tg
@@no:   ret
@@fire: ; direction to the target
        cmp  di,0FFFFh
        jne  @@tt
        mov  ax,[camx]
        sub  ax,[pax+si]
        mov  [ctx],ax
        mov  ax,[camy]
        sub  ax,[pay+si]
        mov  [cty],ax
        mov  ax,[camz]
        sub  ax,[paz+si]
        mov  [ctz],ax
        jmp  @@dir
@@tt:   mov  ax,[pax+di]
        sub  ax,[pax+si]
        mov  [ctx],ax
        mov  ax,[pay+di]
        sub  ax,[pay+si]
        mov  [cty],ax
        mov  ax,[paz+di]
        sub  ax,[paz+si]
        mov  [ctz],ax
@@dir:  mov  bx,[ctx]           ; m = max of the absolutes
        or   bx,bx
        jns  @@m1
        neg  bx
@@m1:   mov  ax,[cty]
        or   ax,ax
        jns  @@m2
        neg  ax
@@m2:   cmp  ax,bx
        jle  @@m3
        mov  bx,ax
@@m3:   mov  ax,[ctz]
        or   ax,ax
        jns  @@m4
        neg  ax
@@m4:   cmp  ax,bx
        jle  @@m5
        mov  bx,ax
@@m5:   test bx,bx
        jz   @@no               ; on top of each other: hold fire
        mov  [wcc],bx           ; m
        ; ---- a 4-round burst into the shared tracer pool ----
        mov  word ptr [tpi],4
@@bs:   mov  bx,[trnext]
        inc  word ptr [trnext]
        and  word ptr [trnext],NTRC-1
        mov  byte ptr [trcact+bx],1
        add  bx,bx
        mov  word ptr [trlif+bx],24
        mov  ax,[pax+si]
        mov  [tcx+bx],ax
        mov  ax,[pay+si]
        sub  ax,10
        mov  [tcy+bx],ax
        mov  ax,[paz+si]
        mov  [tcz+bx],ax
        mov  ax,[ctx]           ; velocity = dir*150/m + spread
        mov  cx,150
        imul cx
        idiv word ptr [wcc]
        mov  [trvx+bx],ax
        mov  ax,[cty]
        mov  cx,150
        imul cx
        idiv word ptr [wcc]
        mov  [trvy+bx],ax
        mov  ax,[ctz]
        mov  cx,150
        imul cx
        idiv word ptr [wcc]
        mov  [trvz+bx],ax
        push bx
        call RND16
        pop  bx
        and  ax,7
        sub  ax,3
        add  [trvx+bx],ax
        push bx
        call RND16
        pop  bx
        and  ax,7
        sub  ax,3
        add  [trvy+bx],ax
        push bx
        call RND16
        pop  bx
        and  ax,7
        sub  ax,3
        add  [trvz+bx],ax
        dec  word ptr [tpi]
        jnz  @@bs
        ; ---- the dice: 1-in-4 bursts connect ----
        call RND16
        and  ax,3
        jnz  @@no2
        cmp  di,0FFFFh
        jne  @@hai
        inc  byte ptr [pdam]    ; the player takes one
        mov  word ptr [phit],6
        cmp  byte ptr [pdam],8
        jb   @@no2
        call CRASHHANDLE        ; shot down (resets pdam itself)
        ret
@@hai:  mov  bx,di
        shr  bx,1
        dec  byte ptr [php+bx]
        jnz  @@no2
        mov  si,di              ; the last hit: BOOM wants SI
        call BOOM
@@no2:  ret

; ---------------------------------------------------------------------------
;  RESPAWNALL - field two fresh squadrons: every slot alive, scattered
;  around the player, new callsigns and armour, trails reseeded. Used at
;  startup and at the start of every round. Drops any lock.
; ---------------------------------------------------------------------------
RESPAWNALL:
        mov  word ptr [locki],0FFFFh
        xor  si,si
@@rs:   mov  bx,si
        shr  bx,1
        mov  byte ptr [pst+bx],0
        call RND16              ; preserves SI/BX
        and  ax,16383
        sub  ax,8192
        add  ax,[camx]
        mov  [pax+si],ax
        call RND16
        and  ax,16383
        sub  ax,8192
        add  ax,[camz]
        mov  [paz+si],ax
        call RND16
        and  ax,1023
        add  ax,700
        mov  [pay+si],ax
        call RND16
        and  ax,255
        mov  [pah+si],ax
        call RND16
        and  ax,3
        mov  [pcs+bx],al
        call RND16
        and  ax,31
        inc  ax
        mov  [pnum+bx],al
        call RND16
        and  ax,3
        add  ax,2
        mov  [php+bx],al
        mov  bx,si              ; seed the contrail at the spawn point
        mov  cl,4
        shl  bx,cl
        mov  cx,TLN
@@rsf:  mov  ax,[pax+si]
        mov  [TLX+bx],ax
        mov  ax,[pay+si]
        mov  [TLY+bx],ax
        mov  ax,[paz+si]
        mov  [TLZ+bx],ax
        add  bx,2
        loop @@rsf
        add  si,2
        cmp  si,NPLANE*2
        jb   @@rs
        mov  byte ptr [pst],1   ; slot 0 never flies: the player is the
        ret                     ; 20th green

; ---------------------------------------------------------------------------
;  CHASESET / CHASERST - the F3 chase camera. For the render only: park
;  the camera 400 behind the jet along the heading and 60 above, wings
;  level (pitch=roll=0 - the classic steady chase); afterwards hand the
;  pilot's world back before physics touches psin/pcos again.
; ---------------------------------------------------------------------------
CHASESET:
        cmp  byte ptr [dying],0
        jne  @@go2
        cmp  byte ptr [tgtcam],0
        jne  @@go2
        cmp  byte ptr [chsview],0
        je   @@r
@@go2:  mov  ax,[camx]
        mov  [svx],ax
        mov  ax,[camy]
        mov  [svy],ax
        mov  ax,[camz]
        mov  [svz],ax
        mov  ax,[pitch]
        mov  [svp],ax
        mov  ax,[roll]
        mov  [svr],ax
        mov  ax,[heading]
        mov  [svh],ax
        cmp  byte ptr [dying],0
        je   @@livecam
        cmp  word ptr [flbcnt],0
        je   @@wrk
        mov  bx,[flbc]          ; flashback: re-fly the recorded tick,
        mov  ax,[FLB+bx]        ; full attitude - reliving the moment
        mov  [camx],ax
        mov  ax,[FLB+bx+2]
        mov  [camy],ax
        mov  ax,[FLB+bx+4]
        mov  [camz],ax
        mov  ax,[FLB+bx+6]
        mov  [heading],ax
        mov  ax,[FLB+bx+8]
        mov  [pitch],ax
        mov  ax,[FLB+bx+10]
        mov  [roll],ax
        jmp  @@r
@@wrk:  mov  ax,[dcx]           ; then hold on the burning wreck
        mov  [camx],ax
        mov  ax,[dcy]
        mov  [camy],ax
        mov  ax,[dcz]
        mov  [camz],ax
        jmp  @@level
@@livecam:
        cmp  byte ptr [tgtcam],0
        jne  @@tcam
        mov  ax,[hsin]          ; 400 back along the heading
        mov  bx,400
        imul bx
        mov  bx,256
        idiv bx
        sub  [camx],ax
        mov  ax,[hcos]
        mov  bx,400
        imul bx
        mov  bx,256
        idiv bx
        sub  [camz],ax
        add  word ptr [camy],60
@@level:
        mov  word ptr [pitch],0
        mov  word ptr [roll],0
@@r:    ret
@@tcam: ; ---- orbit the target (mode 1: the jet; mode 2: its debris) ----
        cmp  byte ptr [tgtcam],2
        je   @@twrk
        mov  si,[tgti]
        mov  ax,[pax+si]
        mov  [pdx],ax
        mov  ax,[pay+si]
        mov  [pdy],ax
        mov  ax,[paz+si]
        mov  [pdz],ax
        jmp  @@torb
@@twrk: mov  bx,[tcws]          ; follow the first piece as it falls
        mov  ax,[bx+WFP]
        mov  [pdx],ax
        mov  ax,[bx+WFP+2]
        mov  [pdy],ax
        mov  ax,[bx+WFP+4]
        mov  [pdz],ax
@@torb: mov  ax,[tgel]          ; H = sin(el)*400/256
        and  ax,255
        call SINQ
        mov  bx,400
        imul bx
        mov  bx,256
        idiv bx
        mov  [cty],ax
        mov  ax,[tgel]          ; R = cos(el)*400/256
        add  ax,64
        and  ax,255
        call SINQ
        mov  bx,400
        imul bx
        mov  bx,256
        idiv bx
        mov  [ctx],ax
        mov  ax,[tgaz]          ; cam = centre - dir(az)*R + (0,H,0)
        call SINQ
        imul word ptr [ctx]
        mov  bx,256
        idiv bx
        mov  bx,[pdx]
        sub  bx,ax
        mov  [camx],bx
        mov  ax,[tgaz]
        add  ax,64
        call SINQ
        imul word ptr [ctx]
        mov  bx,256
        idiv bx
        mov  bx,[pdz]
        sub  bx,ax
        mov  [camz],bx
        mov  ax,[pdy]
        add  ax,[cty]
        mov  [camy],ax
        mov  ax,[tgaz]          ; look at the target
        mov  [heading],ax
        mov  ax,[tgel]
        neg  ax
        mov  [pitch],ax
        mov  word ptr [roll],0
        jmp  @@r

CHASERST:
        cmp  byte ptr [dying],0
        jne  @@go2
        cmp  byte ptr [tgtcam],0
        jne  @@go2
        cmp  byte ptr [chsview],0
        je   @@r
@@go2:
        mov  ax,[svx]
        mov  [camx],ax
        mov  ax,[svy]
        mov  [camy],ax
        mov  ax,[svz]
        mov  [camz],ax
        mov  ax,[svp]
        mov  [pitch],ax
        mov  ax,[svr]
        mov  [roll],ax
        mov  ax,[svh]
        mov  [heading],ax
        call SETTRIG            ; physics needs the real trig back
@@r:    ret

; ---------------------------------------------------------------------------
;  PLAYERDRAW - our own jet in the chase view: the model rolls about the
;  nose axis and pitches about the wings (the camera is level, so the
;  banking is real on screen), parked at (0,-60,400) in camera space.
; ---------------------------------------------------------------------------
PLAYERDRAW:
        mov  ax,[svr]           ; roll sin/cos
        call SINQ
        mov  [msin],ax
        mov  ax,[svr]
        add  ax,64
        call SINQ
        mov  [mcos],ax
        mov  ax,[svp]           ; pitch sin/cos
        and  ax,255
        call SINQ
        mov  [pdx],ax
        mov  ax,[svp]
        add  ax,64
        and  ax,255
        call SINQ
        mov  [pdy],ax
        ; ---- transform the 13 vertices ----
        xor  si,si
        xor  di,di
@@tv:   mov  ax,[MVERT+si]      ; x' = (x*rc + y*rs)/256
        imul word ptr [mcos]
        mov  bx,ax
        mov  ax,[MVERT+si+2]
        imul word ptr [msin]
        add  ax,bx
        cwd
        mov  bx,256
        idiv bx
        mov  [PVX+di],ax
        mov  ax,[MVERT+si]      ; y' = (y*rc - x*rs)/256
        imul word ptr [msin]
        mov  cx,ax
        mov  ax,[MVERT+si+2]
        imul word ptr [mcos]
        sub  ax,cx
        cwd
        mov  bx,256
        idiv bx
        mov  [pdz],ax           ; y' scratch
        imul word ptr [pdy]     ; y'' = (y'*pc + z*ps)/256 - 60
        mov  bx,ax
        mov  ax,[MVERT+si+4]
        imul word ptr [pdx]
        add  ax,bx
        cwd
        mov  bx,256
        idiv bx
        sub  ax,60
        mov  [PVY+di],ax
        mov  ax,[pdz]           ; z'' = (z*pc - y'*ps)/256 + 400
        imul word ptr [pdx]
        mov  cx,ax
        mov  ax,[MVERT+si+4]
        imul word ptr [pdy]
        sub  ax,cx
        cwd
        mov  bx,256
        idiv bx
        add  ax,400
        mov  [PVZ+di],ax
        add  si,6
        add  di,2
        cmp  si,13*6
        jb   @@tv
        ; ---- face depths, painter sort, draw (as PLANESDRAW does) ----
        xor  si,si
@@fd:   mov  bx,si
        add  bx,bx
        add  bx,bx
        add  bx,si
        push si
        mov  al,[MFACE+bx]
        xor  ah,ah
        add  ax,ax
        mov  si,ax
        mov  cx,[PVZ+si]
        mov  al,[MFACE+bx+1]
        xor  ah,ah
        add  ax,ax
        mov  si,ax
        add  cx,[PVZ+si]
        sar  cx,1
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
        sar  dx,1
        add  cx,dx
        sar  cx,1
        pop  si
        mov  bx,si
        add  bx,bx
        mov  [FCD+bx],cx
        mov  ax,si
        mov  bx,si
        mov  [FCO+bx],al
        inc  si
        cmp  si,NFACE
        jb   @@fd
        mov  cx,NFACE-1
@@bs:   push cx
        xor  si,si
@@bi:   mov  bx,si
        add  bx,bx
        mov  ax,[FCD+bx]
        cmp  ax,[FCD+bx+2]
        jge  @@nsw
        xchg ax,[FCD+bx+2]
        mov  [FCD+bx],ax
        mov  al,[FCO+si]
        xchg al,[FCO+si+1]
        mov  [FCO+si],al
@@nsw:  inc  si
        cmp  si,NFACE-1
        jb   @@bi
        pop  cx
        loop @@bs
        mov  word ptr [pfc],0
@@df:   mov  si,[pfc]
        mov  al,[FCO+si]
        xor  ah,ah
        mov  bx,ax
        add  bx,bx
        add  bx,bx
        add  ax,bx
        mov  bx,ax
        mov  al,[MFACE+bx+4]
        mov  [COLOR],al
        xor  cx,cx
@@dc:   push bx
        push cx
        mov  si,cx
        mov  al,[MFACE+bx+si]
        xor  ah,ah
        add  ax,ax
        mov  si,ax
        mov  di,cx
        add  di,di
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
        ret

; ---------------------------------------------------------------------------
;  DEATHTXT - CRASH (blinking red) and PRESS SPACE over the falling wreck.
; ---------------------------------------------------------------------------
DEATHTXT:
        cmp  byte ptr [dying],0
        je   @@no
        mov  ax,[lasttk]
        test ax,4
        jz   @@ps
        mov  byte ptr [COLOR],19
        mov  word ptr [ftx],142
        mov  word ptr [fty],80
        mov  si,offset MSGGO
        call FDRAW
@@ps:   cmp  word ptr [dytick],18
        jb   @@no               ; the prompt waits out the first second
        mov  byte ptr [COLOR],8
        mov  word ptr [ftx],138
        mov  word ptr [fty],92
        mov  si,offset MSGPS2
        call FDRAW
@@no:   ret

; ---------------------------------------------------------------------------
;  FLBSEED - fill the black box with the current state, so an early death
;  replays a still frame instead of garbage from a previous life.
; ---------------------------------------------------------------------------
FLBSEED:
        xor  bx,bx
@@f:    mov  ax,[camx]
        mov  [FLB+bx],ax
        mov  ax,[camy]
        mov  [FLB+bx+2],ax
        mov  ax,[camz]
        mov  [FLB+bx+4],ax
        mov  ax,[heading]
        mov  [FLB+bx+6],ax
        mov  ax,[pitch]
        mov  [FLB+bx+8],ax
        mov  ax,[roll]
        mov  [FLB+bx+10],ax
        add  bx,12
        cmp  bx,FLBSZ
        jb   @@f
        mov  word ptr [flbh],0
        ret
