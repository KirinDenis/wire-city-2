; M3D.INC - part of WIRE CITY (included from CITY.ASM)
; ============================================================================
;  DRAW A 3D EDGE: near clip -> project -> line clip -> draw
; ============================================================================
DRAWEDGE3D:
        call NEARCLIP
        jc   @@skip
        call PROJ2
        call CLIPLINE
        jc   @@skip
        call LINE
@@skip: ret

; ----- near Z-plane clipping ------------------------------------------------
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

; ----- project both points --------------------------------------------------
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

CLAMPAX:
        cmp  ax,4000
        jle  @@a1
        mov  ax,4000
@@a1:   cmp  ax,-4000
        jge  @@a2
        mov  ax,-4000
@@a2:   ret

; ============================================================================
;  SINQ  in: AX=angle (any, wrapped to 0..255 = full circle)
;        out: AX = sin(angle)*256  (range -256..256);  clobbers BX,CX,SI
;  Quarter table SINT[0..64] + symmetry: q0=+T[idx] q1=+T[64-idx]
;  q2=-T[idx] q3=-T[64-idx].  cos(a) = SINQ(a+64).
; ============================================================================
SINQ:   and  ax,255             ; wrap to one circle
        mov  bx,ax
        mov  cl,6
        shr  bx,cl              ; bx = quadrant 0..3  (angle/64)
        and  ax,63              ; ax = idx within quadrant 0..63
        cmp  bx,0
        je   @@q0
        cmp  bx,1
        je   @@q1
        cmp  bx,2
        je   @@q2
        ; q3: -SINT[64-idx]
        mov  bx,64
        sub  bx,ax
        add  bx,bx
        mov  si,bx
        mov  ax,[SINT+si]
        neg  ax
        ret
@@q0:   add  ax,ax
        mov  si,ax
        mov  ax,[SINT+si]
        ret
@@q1:   mov  bx,64              ; SINT[64-idx]
        sub  bx,ax
        add  bx,bx
        mov  si,bx
        mov  ax,[SINT+si]
        ret
@@q2:   add  ax,ax              ; -SINT[idx]
        mov  si,ax
        mov  ax,[SINT+si]
        neg  ax
        ret

; ============================================================================
;  SETTRIG  heading -> hsin/hcos, roll -> rsin/rcos (all *256).
;  Call ONCE per frame before RENDER. Clobbers AX,BX,CX,SI.
; ============================================================================
SETTRIG:
        mov  ax,[heading]
        call SINQ
        mov  [hsin],ax
        mov  ax,[heading]
        add  ax,64
        call SINQ
        mov  [hcos],ax
        mov  ax,[roll]
        call SINQ
        neg  ax                 ; flip roll direction (bank into the turn)
        mov  [rsin],ax
        mov  ax,[roll]
        add  ax,64
        call SINQ
        mov  [rcos],ax
        mov  ax,[pitch]         ; pitch trig for the vertex rotation
        call SINQ
        mov  [psin],ax
        mov  ax,[pitch]
        add  ax,64
        call SINQ
        mov  [pcos],ax
        ; background horizon shift: pofs = psin*FOCAL/pcos (clamped tangent)
        mov  ax,[pcos]
        cmp  ax,48
        jl   @@pbig             ; looking almost straight up/down
        mov  ax,[psin]
        mov  bx,FOCAL
        imul bx
        idiv word ptr [pcos]
        jmp  @@pset
@@pbig: mov  ax,2600            ; push the horizon far off screen
        cmp  word ptr [psin],0
        jge  @@pset
        neg  ax
@@pset: mov  [pofs],ax
        ret

; ============================================================================
;  ROTXZ  yaw-rotate world-relative (wdx,wdz) -> camera-space (rcx,rcz)
;   in:  wdx,wdz (mem)   out: rcx,rcz (mem)   clobbers AX,BX,DX
;   rcx = (wdx*hcos - wdz*hsin)/256 ;  rcz = (wdx*hsin + wdz*hcos)/256
;   Each term: imul (->DX:AX) then idiv 256. Inputs are small view offsets
;   so |product| < ~500k (fits DX:AX) and |quotient| < ~3000 (fits 16-bit).
; ============================================================================
ROTXZ:  mov  ax,[wdx]
        imul word ptr [hcos]    ; DX:AX = wdx*cos*256
        mov  bx,256
        idiv bx                 ; AX = wdx*cos   (the *256 cancels)
        mov  [rcx],ax
        mov  ax,[wdz]
        imul word ptr [hsin]
        mov  bx,256
        idiv bx
        mov  bx,[rcx]
        sub  bx,ax
        mov  [rcx],bx
        mov  ax,[wdx]
        imul word ptr [hsin]
        mov  bx,256
        idiv bx
        mov  [rcz],ax
        mov  ax,[wdz]
        imul word ptr [hcos]
        mov  bx,256
        idiv bx
        mov  bx,[rcz]
        add  bx,ax
        mov  [rcz],bx
        ret

; ============================================================================
;  APPLYROLL  bank the scene: rotate a projected point about screen (160,100)
;   in: AX=sx_raw, DX=sy_raw   out: AX=sx, DX=sy   clobbers BX,SI,rddx/rddy/rsxo
;   Same *256 / idiv 256 fixed-point rotate as ROTXZ. Applied per vertex
;   inside PROJPT so all world geometry tilts; HUD/crosshair bypass it.
; ============================================================================
APPLYROLL:
        sub  ax,160             ; rddx,rddy = offset from the view centre
        mov  [rddx],ax
        sub  dx,[horiz]         ; roll pivots on the pitch horizon
        mov  [rddy],dx
        ; sx = 160 + (rddx*rcos - rddy*rsin)/256
        mov  ax,[rddx]
        imul word ptr [rcos]
        mov  bx,256
        idiv bx
        mov  si,ax
        mov  ax,[rddy]
        imul word ptr [rsin]
        mov  bx,256
        idiv bx
        mov  bx,si
        sub  bx,ax
        add  bx,160
        mov  [rsxo],bx
        ; sy = 100 + (rddx*rsin + rddy*rcos)/256
        mov  ax,[rddx]
        imul word ptr [rsin]
        mov  bx,256
        idiv bx
        mov  si,ax
        mov  ax,[rddy]
        imul word ptr [rcos]
        mov  bx,256
        idiv bx
        mov  bx,si
        add  bx,ax
        add  bx,[horiz]
        mov  ax,[rsxo]
        mov  dx,bx
        ret

; ============================================================================
;  PROJPT  perspective-project one camera-space point, then bank + clamp.
;   in: AX=rx, DX=ry, CX=rz (>0)   out: AX=sx, DX=sy   clobbers BX,CX,SI,ptmp
;   sx = 160 + rx*FOCAL/rz ;  sy = 100 - ry*FOCAL/rz ;  then APPLYROLL.
;   rz must already be >= NEARZ (caller/NEARCLIP guarantees it) so the
;   divide can't overflow. CLAMPAX bounds results to +/-4000 for safe 2D clip.
; ============================================================================
PROJPT: push dx                 ; save ry
        ; guard: a side point can have |rx| up to ~29000 (grid corner)
        ; while rz is small; rx*FOCAL/rz would then overflow a 16-bit
        ; quotient (INT 0). Safe ratio |rx|/rz <= 32767/FOCAL, and past
        ; rz=256 even the worst |rx| cannot overflow. BOTH constants
        ; scale with FOCAL - do not hardcode them again.
        cmp  cx,256
        jge  @@sxok
        mov  bx,ax
        or   bx,bx
        jns  @@g1
        neg  bx                 ; bx = |rx|
@@g1:   push ax
        mov  ax,cx
        mov  dx,32767/FOCAL     ; safe |rx|/rz ratio for this lens
        mul  dx                 ; ax = rz*(32767/FOCAL), rz<256 fits 16-bit
        cmp  bx,ax
        pop  ax
        jbe  @@sxok             ; |rx| <= rz*204 -> divide is safe
        mov  bx,4000            ; would overflow: clamp offscreen, keep sign
        or   ax,ax
        jns  @@g2
        neg  bx
@@g2:   mov  ax,bx
        jmp  @@sxadd
@@sxok: mov  bx,FOCAL
        imul bx                 ; DX:AX = rx*FOCAL
        idiv cx                 ; AX = rx*FOCAL/rz
@@sxadd:
        add  ax,160             ; sx_raw (screen centre x = 160)
        call CLAMPAX            ; clamp BEFORE roll so APPLYROLL can't overflow
        mov  [ptmp],ax
        pop  ax                 ; ry
        cmp  cx,256             ; same overflow guard as rx: pitched vertices
        jge  @@syok             ; can be far above/below at small rz
        mov  bx,ax
        or   bx,bx
        jns  @@g3
        neg  bx
@@g3:   push ax
        mov  ax,cx
        mov  dx,32767/FOCAL
        mul  dx
        cmp  bx,ax
        pop  ax
        jbe  @@syok
        mov  bx,4000
        or   ax,ax
        jns  @@g4
        neg  bx
@@g4:   mov  ax,bx
        jmp  @@syadd
@@syok: mov  bx,FOCAL
        imul bx
        idiv cx
@@syadd:
        mov  bx,[horiz]
        sub  bx,ax              ; sy_raw = horiz - ry*FOCAL/rz
        mov  ax,bx
        call CLAMPAX
        mov  dx,ax
        mov  ax,[ptmp]          ; AX=sx_raw, DX=sy_raw (both clamped)
        call APPLYROLL          ; bank the whole scene about (160,horiz)
        call CLAMPAX            ; final clamp for the 2D clipper
        mov  [ptmp],ax
        mov  ax,dx
        call CLAMPAX
        mov  dx,ax
        mov  ax,[ptmp]
        ret
