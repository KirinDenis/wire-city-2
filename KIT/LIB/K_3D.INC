; ============================================================================
;  K_3D.INC - KIT: 3D on the engine's own pipeline (ENGINE\E_M3D.INC and
;  ENGINE\E_RAST.INC) without declaring their sixty variables by hand: the
;  camera, a world point on the screen, a 3D line, a filled quad, a whole
;  model painted far to near, an orbit and a chase camera, and the INT 0
;  safety net every 3D program wants.
;
;        FOCAL = 270             ; optional, BEFORE the include (default 220)
;        ...
;        call R3_TRAP            ; INT 0 caught from here on (R3_UNTRAP on
;                                ;  every way out)
;  .frame: mov ax,[camx]          ; world x
;        mov  bx,[camy]          ; y (up)
;        mov  cx,[camz]          ; z
;        mov  dx,[heading_]      ; 0 north (+z), 64 east (+x), 256 a circle
;        xor  si,si              ; pitch (+ nose up)
;        xor  di,di              ; roll  (+ banked right)
;        call R3_CAMERA
;        mov  es,[buffer]        ; every drawing goes into ES, 320 a row
;        mov  si,SHIPV           ; the model: vertices dw x,y,z ...
;        mov  di,SHIPF           ;  faces db a,b,c,d,colour ... (Obj2Inc)
;        mov  cx,SHIPNV
;        mov  dx,SHIPNF
;        xor  al,al              ; 0 filled, 1 wire, 2 filled + outline
;        call R3_MODEL           ; at [r3_mx],[r3_my],[r3_mz], yaw [r3_myaw]
;
;  WORLD: x east, y up, z north, words. Angles 256 = a circle. A point is
;  used only as point - camera (mod 65536), so the world may wrap; but what
;  is drawn must lie within ~23000 of the camera on x and z (the turn adds
;  two products in 16 bits) - draw a DISK around the eye, not a square.
;  Model vertices: |x|,|y|,|z| * 2^[r3_mshl] under ~23000 too.
;
;  CONSTANTS (define before the include to change them):
;      FOCAL  = 220   the lens: 160/FOCAL is half the view's width (72 deg)
;      NEARZ  = 40    the near plane: nothing nearer is drawn
;      R3_MAXV = 64   the most vertices a model may have
;      R3_MAXF = 64   the most faces a model may have
;
;  THE ENGINE ITSELF COMES WITH THIS FILE, so these names are TAKEN - a
;  program must not define any of them (they are the engine's, they keep no
;  kit prefix). Engine routines (they keep NO registers): SINQ SETTRIG
;  ROTXZ PROJPT APPLYROLL CLAMPAX PITCH4 CLIPNEAR APPENDV APPENDISECT
;  PROJPOLY SCANPOLY STROKEPOLY FACEFILL FACESTROKE OUTCODE CLIPLINE LINE
;  PUTPIXEL. Engine variables: heading pitch roll hsin hcos rsin rcos psin
;  pcos pofs horiz swayx swayy wdx wdz rc_x rc_z ptmp rddx rddy rsxo tnum
;  tden cdx cdy nx ny IX IY IZ OX OY OZ PX PY NPOLY COLOR oc ci ni pk pminy
;  pmaxy scy scymax scxl scxr oc0 oc1 ocsel lx ly ldx ldy lsx lsy lerr sx0
;  sy0 sx1 sy1 SINT. THE SHORT ONES BITE: oc ci ni pk nx ny lx ly sx0 sy0
;  are RESERVED - name your own things otherwise. Do NOT define fastp,
;  qual, linereg or clipx0 unless you mean the engine options they switch
;  (see the engine files).
;
;  Using the engine directly is allowed: FACEFILL fills the quad in
;  IX/IY/IZ (camera space, turned by the heading, NOT pitched - FACEFILL
;  pitches it, and rotates IY/IZ in place: load them again before a second
;  call), COLOR is its colour, ES the buffer.
;  Guide topic RENDER.
; ============================================================================

if ~ defined FOCAL | defined r3_dfoc
FOCAL   = 220                   ; the lens (OWL FLY's): ~72 degrees across
r3_dfoc = 1
end if
if ~ defined NEARZ | defined r3_dnz
NEARZ   = 40                    ; the near clip plane
r3_dnz  = 1
end if
if ~ defined R3_MAXV | defined r3_dmv
R3_MAXV = 64                    ; vertices a model may have
r3_dmv  = 1
end if
if ~ defined R3_MAXF | defined r3_dmf
R3_MAXF = 64                    ; faces a model may have
r3_dmf  = 1
end if

; ---- the engine's contract: E_M3D + E_RAST (EXAMPLES\RELIEF.ASM's block) ---
heading dw 0                    ; the camera's heading, pitch and roll
pitch   dw 0
roll    dw 0
hsin    dw 0                    ; SETTRIG's answers, *256
hcos    dw 256
rsin    dw 0
rcos    dw 256
psin    dw 0
pcos    dw 256
pofs    dw 0                    ; the horizon's shift for the pitch
horiz   dw 100                  ; the row the eye's axis meets
swayx   dw 0                    ; view float (0: none)
swayy   dw 0
wdx     dw 0                    ; ROTXZ in...
wdz     dw 0
rc_x    dw 0                    ; ...and out
rc_z    dw 0
ptmp    dw 0                    ; projection scratch
rddx    dw 0
rddy    dw 0
rsxo    dw 0
tnum    dw 0                    ; clip interpolation scratch
tden    dw 0
cdx     dw 0                    ; line clip deltas / new point
cdy     dw 0
nx      dw 0
ny      dw 0
IX      dw 4 dup(0)             ; a face in (camera space)
IY      dw 4 dup(0)
IZ      dw 4 dup(0)
OX      dw 6 dup(0)             ; near-clipped
OY      dw 6 dup(0)
OZ      dw 6 dup(0)
PX      dw 6 dup(0)             ; projected
PY      dw 6 dup(0)
NPOLY   dw 0
oc      dw 0
ci      dw 0
ni      dw 0
pk      dw 0
pminy   dw 0
pmaxy   dw 0
scy     dw 0                    ; scanline filler state
scymax  dw 0
scxl    dw 0
scxr    dw 0
oc0     db 0                    ; Cohen-Sutherland outcodes
oc1     db 0
ocsel   db 0
lx      dw 0                    ; LINE's state
ly      dw 0
ldx     dw 0
ldy     dw 0
lsx     dw 0
lsy     dw 0
lerr    dw 0
sx0     dw 0                    ; a screen line: CLIPLINE then LINE
sy0     dw 0
sx1     dw 0
sy1     dw 0
COLOR   db 0
; quarter sine table: SINT[i] = round(256*sin(i*90/64 deg)), i=0..64
SINT    dw 0,6,13,19,25,31,38,44,50,56,62,68,74,80,86,92,98,104,109,115
        dw 121,126,132,137,142,147,153,157,162,167,172,177,181,185,190,194
        dw 198,202,206,209,213,216,220,223,226,229,231,234,237,239,241,243
        dw 245,247,248,250,251,252,253,254,255,255,256,256,256

        include '..\..\ENGINE\E_M3D.INC'
        include '..\..\ENGINE\E_RAST.INC'

; ---- the kit's own state -----------------------------------------------------
r3_camx  dw 0                   ; the camera in the world (R3_CAMERA sets)
r3_camy  dw 0
r3_camz  dw 0
r3_pz    dw 0                   ; R3_POINT: the point's depth in front of the eye
r3_x0    dw 0                   ; R3_EDGE: the two ends, world
r3_y0    dw 0
r3_z0    dw 0
r3_x1    dw 0
r3_y1    dw 0
r3_z1    dw 0
r3_vx0   dw 0                   ; R3_EDGEC: the two ends, camera space
r3_vy0   dw 0                   ;  (turned AND pitched; cut in place)
r3_vz0   dw 0
r3_vx1   dw 0
r3_vy1   dw 0
r3_vz1   dw 0
r3_line  dw 0                   ; 0: LINE draws an edge; else the routine
                                ;  here does (sx0..sy1 clipped, COLOR, ES)
r3_qx    dw 4 dup(0)            ; R3_QUAD: four corners, world, in order
r3_qy    dw 4 dup(0)
r3_qz    dw 4 dup(0)
r3_wirec db 15                  ; the outline's colour (mode 2)
r3_mx    dw 0                   ; R3_MODEL: where the model stands, world
r3_my    dw 0
r3_mz    dw 0
r3_myaw  dw 0                   ; ...its heading (0: its +z points north)
r3_mshl  db 0                   ; ...its vertices * 2^this (0: as written)
r3_chd   dw 300                 ; R3_CHASE: how far behind...
r3_chh   dw 80                  ; ...how far above
r3_chnew db 1                   ; 1: snap behind at once (then it eases)
r3_chang dw 0                   ; the chase camera's own heading
r3_faults dw 0                  ; divide faults caught since the start
r3_quit  dw 0                   ; R3_INT0: a fault outside guarded 3D code
                                ;  jumps here (your way out); 0 = it quits
r3_savesp dw 0                  ; where the trap puts the stack back (0 none)
r3_old0  dw 0,0                 ; DOS's INT 0, kept while ours is in
r3_on    db 0                   ; 1 = ours is in
r3_lastf dw 0                   ; scratch: faults in the last R3_SAFE
; model and face scratch
r3_mvt   dw 0                   ; vertex table, face table, counts
r3_mft   dw 0
r3_mnv   dw 0
r3_mnf   dw 0
r3_mmode db 0
r3_ms    dw 0                   ; sin/cos of (model yaw - camera heading)
r3_mc    dw 0
r3_pdx   dw 0                   ; the model's place, camera space (unpitched)
r3_pdy   dw 0
r3_pdz   dw 0
r3_tx    dw 0                   ; one vertex, scaled
r3_tz    dw 0
r3_pfc   dw 0                   ; the face being painted
r3_pm    db 0                   ; r3_face: the mode of this face
r3_pc    db 0                   ; ...and its colour
r3_fx    dw 4 dup(0)            ; r3_face: four corners, camera space,
r3_fy    dw 4 dup(0)            ;  turned, not pitched
r3_fz    dw 4 dup(0)
r3_pvx   dw R3_MAXV dup(0)      ; the model's vertices, camera space
r3_pvy   dw R3_MAXV dup(0)
r3_pvz   dw R3_MAXV dup(0)
r3_fcd   dw R3_MAXF dup(0)      ; face depths...
r3_fco   db R3_MAXF dup(0)      ; ...and the order they are painted in
r3_oh    dw 0                   ; R3_ORBIT scratch
r3_od    dw 0
r3_oa    dw 0
r3_s0    dw 0
r3_s1    dw 0

; ----------------------------------------------------------------------
;@ R3_CAMERA  place the camera: AX,BX,CX = x,y,z; DX heading, SI pitch, DI roll
;  in:  AX,BX,CX = the eye in the world; DX = heading (0 north/+z, 64
;       east/+x); SI = pitch (+ nose up, 64 straight up); DI = roll (+
;       banked right: the world on the screen turns the other way)
;  out: [r3_camx],[r3_camy],[r3_camz], heading/pitch/roll and their sines
;  needs: once a frame, before anything is drawn
;  from: ENGINE\E_M3D.INC SETTRIG (the camera as RELIEF.ASM keeps it)
; ----------------------------------------------------------------------
if used R3_CAMERA
R3_CAMERA:
        mov  [r3_camx],ax
        mov  [r3_camy],bx
        mov  [r3_camz],cx
        mov  [heading],dx
        mov  [pitch],si
        mov  [roll],di
        call R3_TRIG
        ret
end if

; ----------------------------------------------------------------------
;@ R3_TRIG    rerun SETTRIG after changing heading/pitch/roll yourself
;  in:  [heading],[pitch],[roll]
;  out: hsin hcos psin pcos rsin rcos pofs
;  from: ENGINE\E_M3D.INC SETTRIG, registers kept
; ----------------------------------------------------------------------
if used R3_TRIG
R3_TRIG:
        push ax
        push bx
        push cx
        push dx
        push si
        call SETTRIG
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ R3_YAW     world point AX,BX,CX -> camera space turned by the heading
;  in:  AX,BX,CX = world x,y,z
;  out: AX = right of the eye, BX = above it, CX = ahead of it - NOT
;       pitched (what FACEFILL wants in IX/IY/IZ)
;  needs: R3_CAMERA this frame
;  from: ENGINE\E_M3D.INC ROTXZ (EXAMPLES\RELIEF.ASM TERRPREP's use)
; ----------------------------------------------------------------------
if used R3_YAW
R3_YAW: push dx
        sub  ax,[r3_camx]       ; world - camera, mod 65536
        mov  [wdx],ax
        sub  cx,[r3_camz]
        mov  [wdz],cx
        sub  bx,[r3_camy]       ; height above the eye
        push bx
        call ROTXZ              ; rc_x, rc_z (eats AX BX DX)
        pop  bx
        mov  ax,[rc_x]
        mov  cx,[rc_z]
        pop  dx
        ret
end if

; ----------------------------------------------------------------------
;@ R3_PITCH   tilt a turned point by the camera's pitch: BX=y, CX=z
;  in:  BX = y, CX = z (camera space, turned by R3_YAW)
;  out: BX, CX pitched (x does not change)
;  from: GAMES\OWLFLY3\SRC\PLANES.INC PPOINT:1154-1182 (same IDIVs; their
;        quotient is never above the input, so they cannot fault)
; ----------------------------------------------------------------------
if used R3_PITCH
R3_PITCH:
        push ax
        push dx
        push si
        push di
        mov  si,bx              ; SI = y
        mov  di,cx              ; DI = z
        mov  bx,256
        mov  ax,si
        imul word [pcos]        ; DX:AX = y*pcos
        idiv bx                 ; AX = y*pcos/256
        mov  cx,ax
        mov  ax,di
        imul word [psin]        ; DX:AX = z*psin
        idiv bx                 ; AX = z*psin/256
        sub  cx,ax              ; CX = y' = (y*pcos - z*psin)/256
        push cx
        mov  ax,si
        imul word [psin]        ; DX:AX = y*psin
        idiv bx                 ; AX = y*psin/256
        mov  cx,ax
        mov  ax,di
        imul word [pcos]        ; DX:AX = z*pcos
        idiv bx                 ; AX = z*pcos/256
        add  cx,ax              ; CX = z' = (y*psin + z*pcos)/256
        pop  bx                 ; BX = y'
        pop  di
        pop  si
        pop  dx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ R3_VIEW    world point AX,BX,CX -> full camera space (turned and pitched)
;  in:  AX,BX,CX = world x,y,z
;  out: AX = right, BX = up, CX = ahead (CX < NEARZ: behind the near plane)
;  needs: R3_CAMERA this frame
;  from: R3_YAW + R3_PITCH (OWLFLY3 PPOINT's order: turn, then pitch)
; ----------------------------------------------------------------------
if used R3_VIEW
R3_VIEW:
        call R3_YAW
        call R3_PITCH
        ret
end if

; ----------------------------------------------------------------------
;@ R3_POINT   world point AX,BX,CX -> screen AX,BX; CF = not on the screen
;  in:  AX,BX,CX = world x,y,z
;  out: AX = screen x, BX = screen y (clamped to +-4000 when off the
;       screen but in front); CF = 1 behind the near plane (AX=BX=-30000)
;       or off the screen; [r3_pz] = the depth (scale a sprite by it)
;  needs: R3_CAMERA this frame
;  from: GAMES\OWLFLY3\SRC\PLANES.INC PPOINT:1154-1195 + E_M3D PROJPT
; ----------------------------------------------------------------------
if used R3_POINT
R3_POINT:
        push cx
        push dx
        push si
        call R3_VIEW            ; AX,BX,CX camera space
        mov  [r3_pz],cx
        cmp  cx,NEARZ
        jl   .behind
        mov  dx,bx
        call PROJPT             ; AX = sx, DX = sy (eats BX CX SI)
        mov  bx,dx
        cmp  ax,0
        jl   .off
        cmp  ax,319
        jg   .off
        cmp  bx,0
        jl   .off
        cmp  bx,199
        jg   .off
        clc
        jmp  .x
.behind:mov  ax,-30000
        mov  bx,ax
.off:   stc
.x:     pop  si
        pop  dx
        pop  cx
        ret
end if

; ----------------------------------------------------------------------
;@ R3_EDGE    a 3D line from (r3_x0,r3_y0,r3_z0) to (r3_x1,..) in colour AL
;  in:  r3_x0 r3_y0 r3_z0 r3_x1 r3_y1 r3_z1 = the ends, world; AL = colour;
;       ES = the buffer
;  out: - (cut at the near plane and the screen's edge; a divide fault in
;       it is caught by R3_TRAP and the line is dropped)
;  needs: R3_CAMERA this frame
;  from: GAMES\OWLFLY3\SRC\M3D.INC DRAWEDGE3D:5-97, ends turned by R3_VIEW
; ----------------------------------------------------------------------
if used R3_EDGE
R3_EDGE:push ax
        push bx
        push cx
        push ax
        mov  ax,[r3_x0]
        mov  bx,[r3_y0]
        mov  cx,[r3_z0]
        call R3_VIEW
        mov  [r3_vx0],ax
        mov  [r3_vy0],bx
        mov  [r3_vz0],cx
        mov  ax,[r3_x1]
        mov  bx,[r3_y1]
        mov  cx,[r3_z1]
        call R3_VIEW
        mov  [r3_vx1],ax
        mov  [r3_vy1],bx
        mov  [r3_vz1],cx
        pop  ax
        call R3_EDGEC
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ R3_EDGEC   a 3D line already in camera space (r3_vx0..r3_vz1), colour AL
;  in:  r3_vx0 r3_vy0 r3_vz0 r3_vx1 r3_vy1 r3_vz1 = the ends, camera space
;       (turned AND pitched, as R3_VIEW gives; they are cut in place);
;       AL = colour; ES = the buffer; [r3_line] = 0 (LINE) or your own
;       line routine (a floating horizon: see REC\R_WIRE.ASM)
;  out: -
;  from: GAMES\OWLFLY3\SRC\M3D.INC DRAWEDGE3D/NEARCLIP/PROJ2:5-97,
;        EXAMPLES\RELIEF.ASM's savesp around it
; ----------------------------------------------------------------------
if used R3_EDGEC
R3_EDGEC:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        mov  [COLOR],al
        mov  si,.body
        call r3_guard
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
.body:  mov  ax,[r3_vz0]        ; ---- the near plane ----
        cmp  ax,NEARZ
        jge  .p0in
        cmp  word [r3_vz1],NEARZ
        jl   .x                 ; both behind: nothing
        mov  si,r3_vx0          ; end 0 is cut, toward end 1
        mov  di,r3_vx1
        call .cut
        jc   .x
        jmp  .proj
.p0in:  cmp  word [r3_vz1],NEARZ
        jge  .proj              ; both in front
        mov  si,r3_vx1          ; end 1 is cut, toward end 0
        mov  di,r3_vx0
        call .cut
        jc   .x
.proj:  mov  ax,[r3_vx0]        ; ---- both ends onto the glass ----
        mov  dx,[r3_vy0]
        mov  cx,[r3_vz0]
        call PROJPT
        mov  [sx0],ax
        mov  [sy0],dx
        mov  ax,[r3_vx1]
        mov  dx,[r3_vy1]
        mov  cx,[r3_vz1]
        call PROJPT
        mov  [sx1],ax
        mov  [sy1],dx
        call CLIPLINE           ; ---- the screen's edge ----
        jc   .x
        mov  ax,[r3_line]
        or   ax,ax
        jz   .ln
        call ax                 ; your own line
        ret
.ln:    call LINE
.x:     ret
; .cut: the end at [SI] (x,y,z words 6 apart: r3_vx0, r3_vy0... are laid
; out x0 y0 z0 x1 y1 z1, so +0 x, +2 y, +4 z) moved onto z = NEARZ along
; the line to the end at [DI]. CF = 1: the numbers do not fit, drop it.
.cut:   mov  bx,[di+4]
        sub  bx,[si+4]          ; den = z(in) - z(out), > 0 ...
        jle  .bad               ; ...unless it wrapped: drop the line
        mov  cx,NEARZ
        sub  cx,[si+4]          ; num = NEARZ - z(out), 0 < num <= den
        mov  ax,[di]
        sub  ax,[si]            ; x(in) - x(out)
        imul cx                 ; DX:AX = that * num
        idiv bx                 ; AX = that * num / den (num <= den: fits)
        add  [si],ax            ; x moved onto the plane
        mov  ax,[di+2]
        sub  ax,[si+2]          ; y(in) - y(out)
        imul cx                 ; DX:AX = that * num
        idiv bx                 ; / den
        add  [si+2],ax          ; y moved onto the plane
        mov  word [si+4],NEARZ  ; z IS the plane
        clc
        ret
.bad:   stc
        ret
end if

; ----------------------------------------------------------------------
;@ R3_QUAD    a quad of 4 world corners (r3_qx/qy/qz): AL colour, AH mode
;  in:  r3_qx, r3_qy, r3_qz = 4 words each, the corners in order round;
;       AL = colour; AH = 0 filled, 1 wire, 2 filled + outline [r3_wirec];
;       ES = the buffer
;  out: - (one quad: draw far ones first, the later paints over)
;  needs: R3_CAMERA this frame
;  from: ENGINE\E_RAST.INC FACEFILL/FACESTROKE (corners as OWLFLY3 WORLD2.INC
;        FACEV loads them)
; ----------------------------------------------------------------------
if used R3_QUAD
R3_QUAD:push ax
        push bx
        push cx
        push si
        push ax
        xor  si,si
.c:     mov  ax,[r3_qx+si]
        mov  bx,[r3_qy+si]
        mov  cx,[r3_qz+si]
        call R3_YAW
        mov  [r3_fx+si],ax
        mov  [r3_fy+si],bx
        mov  [r3_fz+si],cx
        add  si,2
        cmp  si,8
        jb   .c
        pop  ax
        call r3_face
        pop  si
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; r3_face - paint r3_fx/fy/fz (camera space, turned, not pitched): AL the
; colour, AH the mode (0 fill, 1 wire, 2 fill + [r3_wirec] outline). Keeps
; nothing; each FACEFILL runs under the divide guard.
if used r3_face
r3_face:mov  [r3_pc],al
        mov  [r3_pm],ah
        cmp  ah,1
        je   .wire
        mov  [COLOR],al
        mov  si,.fill
        call r3_guard
        cmp  byte [r3_pm],2
        jne  .x
        mov  al,[r3_wirec]
        mov  [r3_pc],al
.wire:  mov  si,.strk
        call r3_guard
.x:     ret
.fill:  call .load
        call FACEFILL
        ret
.strk:  call .load              ; again: FACEFILL pitched IY/IZ in place
        mov  al,[r3_pc]
        mov  [COLOR],al
        call FACESTROKE
        ret
.load:  xor  si,si
.l:     mov  ax,[r3_fx+si]
        mov  [IX+si],ax
        mov  ax,[r3_fy+si]
        mov  [IY+si],ax
        mov  ax,[r3_fz+si]
        mov  [IZ+si],ax
        add  si,2
        cmp  si,8
        jb   .l
        ret
end if

; ----------------------------------------------------------------------
;@ R3_MODEL   draw a model (Obj2Inc tables) at [r3_mx/my/mz], yaw [r3_myaw]
;  in:  SI = vertices (dw x,y,z each), DI = faces (db a,b,c,d,colour each;
;       a triangle repeats its last corner), CX = vertex count, DX = face
;       count; AL = 0 filled, 1 wire, 2 filled + outline in [r3_wirec];
;       [r3_mx],[r3_my],[r3_mz] = where it stands (world), [r3_myaw] = its
;       heading (its +z points that way), [r3_mshl] = scale shift;
;       ES = the buffer
;  out: CF = 1: CX > R3_MAXV or DX > R3_MAXF, nothing drawn
;  needs: R3_CAMERA this frame. Faces are sorted far to near by the mean
;       depth of their corners and painted in that order (no culling).
;  from: GAMES\OWLFLY3\SRC\PLANES.INC MODELDRAW:837-1025 + LESSONS\L30\
;        HANGAR.ASM CORNERS/DEPTHS/BUBBLE/PAINT; the turn summed in 32 bits
;        (MODELDRAW's 16-bit sum overflows past |x| = 128)
; ----------------------------------------------------------------------
if used R3_MODEL
R3_MODEL:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        cmp  cx,R3_MAXV
        ja   .big
        cmp  dx,R3_MAXF
        ja   .big
        mov  [r3_mvt],si
        mov  [r3_mft],di
        mov  [r3_mnv],cx
        mov  [r3_mnf],dx
        mov  [r3_mmode],al
        or   dx,dx
        jz   .done
        jcxz .done
        ; ---- the model's turn relative to the camera's ----
        mov  ax,[r3_myaw]
        sub  ax,[heading]       ; a = yaw - heading (camera turn undone)
        push ax
        call SINQ               ; AX = sin(a)*256
        mov  [r3_ms],ax
        pop  ax
        add  ax,64              ; a quarter on: the cosine
        call SINQ
        mov  [r3_mc],ax
        ; ---- where it stands, camera space ----
        mov  ax,[r3_mx]
        mov  bx,[r3_my]
        mov  cx,[r3_mz]
        call R3_YAW
        mov  [r3_pdx],ax
        mov  [r3_pdy],bx
        mov  [r3_pdz],cx
        ; ---- every vertex turned and placed ----
        mov  si,[r3_mvt]
        xor  di,di
        mov  cx,[r3_mnv]
.tv:    push cx
        mov  cl,[r3_mshl]
        mov  ax,[si]
        shl  ax,cl              ; x * 2^shl
        mov  [r3_tx],ax
        mov  ax,[si+4]
        shl  ax,cl              ; z * 2^shl
        mov  [r3_tz],ax
        mov  ax,[si+2]
        shl  ax,cl              ; y * 2^shl
        add  ax,[r3_pdy]        ; + where it stands
        mov  [r3_pvy+di],ax
        mov  ax,[r3_tx]         ; x' = (x*cos + z*sin)/256, 32 bits
        imul word [r3_mc]       ; DX:AX = x*cos
        mov  bx,ax
        mov  cx,dx              ; CX:BX = it
        mov  ax,[r3_tz]
        imul word [r3_ms]       ; DX:AX = z*sin
        add  ax,bx
        adc  dx,cx              ; DX:AX = x*cos + z*sin
        mov  al,ah              ; /256: the middle two bytes
        mov  ah,dl
        add  ax,[r3_pdx]        ; + where it stands
        mov  [r3_pvx+di],ax
        mov  ax,[r3_tz]         ; z' = (z*cos - x*sin)/256, 32 bits
        imul word [r3_mc]       ; DX:AX = z*cos
        mov  bx,ax
        mov  cx,dx              ; CX:BX = it
        mov  ax,[r3_tx]
        imul word [r3_ms]       ; DX:AX = x*sin
        sub  bx,ax
        sbb  cx,dx              ; CX:BX = z*cos - x*sin
        mov  al,bh              ; /256: the middle two bytes
        mov  ah,cl
        add  ax,[r3_pdz]        ; + where it stands
        mov  [r3_pvz+di],ax
        add  si,6               ; the next vertex (6 bytes)
        add  di,2               ; the next cache word
        pop  cx
        loop .tv
        ; ---- each face's depth: halves of halves, no sum overflows ----
        xor  si,si              ; SI = the face
.fd:    call .rec               ; BX = &faces[f]
        mov  al,[bx]
        call .vz                ; AX = z of that corner
        mov  cx,ax
        mov  al,[bx+1]
        call .vz
        sar  cx,1               ; z0/2
        sar  ax,1               ; z1/2
        add  cx,ax              ; (z0+z1)/2
        mov  al,[bx+2]
        call .vz
        mov  dx,ax
        mov  al,[bx+3]
        call .vz
        sar  dx,1               ; z2/2
        sar  ax,1               ; z3/2
        add  dx,ax              ; (z2+z3)/2
        sar  cx,1
        sar  dx,1
        add  cx,dx              ; the mean of the four
        mov  bx,si
        add  bx,bx              ; BX = f*2
        mov  [r3_fcd+bx],cx
        mov  ax,si
        mov  [r3_fco+si],al     ; the order starts as the table's
        inc  si
        cmp  si,[r3_mnf]
        jb   .fd
        ; ---- bubble far -> near (a single face needs none) ----
        mov  cx,[r3_mnf]
        dec  cx                 ; n-1 passes
        jz   .paint
.bs:    push cx
        xor  si,si
.bi:    mov  bx,si
        add  bx,bx              ; BX = i*2
        mov  ax,[r3_fcd+bx]
        cmp  ax,[r3_fcd+bx+2]   ; farther than the next?
        jge  .nsw               ;   yes: the right way round
        xchg ax,[r3_fcd+bx+2]   ; swap the depths...
        mov  [r3_fcd+bx],ax
        mov  al,[r3_fco+si]     ; ...and the faces
        xchg al,[r3_fco+si+1]
        mov  [r3_fco+si],al
.nsw:   inc  si
        mov  bx,[r3_mnf]
        dec  bx                 ; BX = n-1
        cmp  si,bx
        jb   .bi
        pop  cx
        loop .bs
        ; ---- paint, far to near ----
.paint: mov  word [r3_pfc],0
.df:    mov  si,[r3_pfc]
        mov  al,[r3_fco+si]
        xor  ah,ah
        mov  si,ax              ; SI = the face
        call .rec               ; BX = &faces[f]
        xor  di,di              ; DI = the corner, in words
.dc:    mov  al,[bx]            ; the vertex number
        xor  ah,ah
        cmp  ax,[r3_mnv]
        jb   .vok
        xor  ax,ax              ; a number past the table: vertex 0
.vok:   add  ax,ax
        mov  si,ax              ; SI = its cache word
        mov  ax,[r3_pvx+si]
        mov  [r3_fx+di],ax
        mov  ax,[r3_pvy+si]
        mov  [r3_fy+di],ax
        mov  ax,[r3_pvz+si]
        mov  [r3_fz+di],ax
        inc  bx
        add  di,2
        cmp  di,8
        jb   .dc
        mov  al,[bx]            ; BX is on the colour byte now
        mov  ah,[r3_mmode]
        call r3_face
        inc  word [r3_pfc]
        mov  ax,[r3_mnf]
        cmp  [r3_pfc],ax
        jb   .df
.done:  clc
        jmp  .out
.big:   stc
.out:   pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
; .rec: BX = the face table + SI*5
.rec:   mov  bx,si
        add  bx,bx
        add  bx,bx              ; f*4
        add  bx,si              ; f*5
        add  bx,[r3_mft]
        ret
; .vz: AX = the cached z of vertex AL (0 past the table)
.vz:    push si
        xor  ah,ah
        cmp  ax,[r3_mnv]
        jb   .z1
        xor  ax,ax
.z1:    add  ax,ax
        mov  si,ax
        mov  ax,[r3_pvz+si]
        pop  si
        ret
end if

; ----------------------------------------------------------------------
;@ R3_ORBIT   camera on a circle round a point, looking at it
;  in:  AX,BX,CX = the point (world); DX = the camera's heading (the side
;       it looks from: 0 = from the south, looking north); SI = distance
;       along the ground (0..32767); DI = height above the point
;  out: the camera set (as R3_CAMERA), roll 0, pitched down onto the point
;  from: EXAMPLES\SMOKE.ASM:99-128 (position = point - dist along the
;        view); the pitch found by walking SINT, no divide (new)
; ----------------------------------------------------------------------
if used R3_ORBIT
R3_ORBIT:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push ax
        push bx
        push cx
        mov  [r3_od],si
        mov  [r3_oh],di
        mov  [heading],dx
        ; ---- the pitch: the smallest a with d*sin(a) >= |h|*cos(a) ----
        mov  ax,di
        or   ax,ax
        jns  .h1
        neg  ax                 ; |h|
.h1:    mov  [r3_oa],ax         ; (|h| for the walk)
        xor  di,di              ; DI = a, 0..64
.pw:    mov  ax,di
        call SINQ               ; AX = sin(a)*256
        imul word [r3_od]       ; DX:AX = d*sin
        mov  [r3_s0],ax         ; kept in memory: SINQ eats BX CX SI
        mov  [r3_s1],dx
        mov  ax,di
        add  ax,64
        call SINQ               ; AX = cos(a)*256
        imul word [r3_oa]       ; DX:AX = |h|*cos
        cmp  [r3_s1],dx         ; d*sin >= |h|*cos ? (32-bit, signed)
        jg   .pf
        jl   .pn
        cmp  [r3_s0],ax
        jae  .pf
.pn:    inc  di                 ; a step steeper
        cmp  di,64
        jb   .pw
.pf:    cmp  word [r3_oh],0
        jle  .pu
        neg  di                 ; above the point: look DOWN (pitch < 0)
.pu:    mov  [pitch],di
        mov  word [roll],0
        call R3_TRIG
        ; ---- the eye: the point - d along the heading, + h up ----
        mov  ax,[hsin]
        imul word [r3_od]       ; DX:AX = sin*d
        mov  bx,256
        idiv bx                 ; AX = sin*d/256 (|q| <= d: fits)
        mov  si,ax
        mov  ax,[hcos]
        imul word [r3_od]       ; DX:AX = cos*d
        idiv bx                 ; AX = cos*d/256
        pop  cx                 ; the point's z
        pop  bx                 ; ...y
        sub  cx,ax              ; camz = z - d*cos
        add  bx,[r3_oh]         ; camy = y + h
        pop  ax                 ; ...x
        sub  ax,si              ; camx = x - d*sin
        mov  [r3_camx],ax
        mov  [r3_camy],bx
        mov  [r3_camz],cx
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ R3_CHASE   chase camera: behind and above a thing, turning after it
;  in:  AX,BX,CX = the thing (world); DX = its heading; [r3_chd] = how far
;       behind, [r3_chh] = how far above; [r3_chnew] = 1 to snap at once
;  out: the camera set (R3_ORBIT round the thing); [r3_chang] eases a
;       quarter of the way to DX each call, so a turn swings the view
;  from: the idea of GAMES\OWLFLY3\SRC\PLANES.INC CHASESET:3466-3688,
;        simplified to an eased orbit (new)
; ----------------------------------------------------------------------
if used R3_CHASE
R3_CHASE:
        push dx
        push si
        push di
        cmp  byte [r3_chnew],0
        je   .ease
        mov  byte [r3_chnew],0
        mov  [r3_chang],dx      ; snap
        and  word [r3_chang],255
        jmp  .go
.ease:  push ax
        mov  ax,dx
        sub  ax,[r3_chang]      ; the short way round...
        cbw                     ; ...as a signed byte, -128..127
        mov  si,ax
        sar  si,1
        sar  si,1               ; a quarter of it
        jnz  .st
        or   ax,ax
        jz   .st                ; there already
        mov  si,1               ; under 4 off: one step (flags: OR's)
        jns  .st
        mov  si,-1
.st:    add  [r3_chang],si      ; a quarter of the way
        and  word [r3_chang],255
        pop  ax
.go:    mov  dx,[r3_chang]
        mov  si,[r3_chd]
        mov  di,[r3_chh]
        call R3_ORBIT
        pop  di
        pop  si
        pop  dx
        ret
end if

; ----------------------------------------------------------------------
;@ R3_TRAP    take INT 0: a divide fault in 3D code drops that face/line
;  in:  [r3_quit] = your way out for a fault OUTSIDE the kit's 3D code
;       (0: the trap gives INT 0 back, sets text mode 3 and quits, code 1)
;  out: - (safe to call twice)
;  needs: R3_UNTRAP on EVERY way out - DOS reuses this memory
;  from: EXAMPLES\RELIEF.ASM:167-176 (install), 1368-1375 (TRAP0)
; ----------------------------------------------------------------------
if used R3_TRAP
R3_TRAP:push ax
        push es
        cmp  byte [r3_on],0
        jne  .x
        xor  ax,ax
        mov  es,ax              ; ES = 0: the vector table
        mov  ax,[es:0]
        mov  [r3_old0],ax       ; DOS's INT 0, kept
        mov  ax,[es:2]
        mov  [r3_old0+2],ax
        cli                     ; two words: no interrupt between them
        mov  word [es:0],R3_INT0
        mov  [es:2],cs
        sti
        mov  byte [r3_on],1
.x:     pop  es
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ R3_UNTRAP  give INT 0 back (every way out; safe when not taken)
;  in:  -
;  out: -
;  from: EXAMPLES\RELIEF.ASM:227-234
; ----------------------------------------------------------------------
if used R3_UNTRAP
R3_UNTRAP:
        push ax
        push es
        cmp  byte [r3_on],0
        je   .x
        xor  ax,ax
        mov  es,ax
        cli
        mov  ax,[r3_old0]
        mov  [es:0],ax
        mov  ax,[r3_old0+2]
        mov  [es:2],ax
        sti
        mov  byte [r3_on],0
.x:     pop  es
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ R3_SAFE    run the routine at SI under the divide guard; CF = it faulted
;  in:  SI = a near routine (it gets every other register as you set them)
;  out: CF = 1 a divide fault stopped it (its registers are then garbage,
;       and [r3_faults] counts it); else what the routine returns
;  needs: R3_TRAP, or a fault is not caught at all
;  from: EXAMPLES\RELIEF.ASM DRAWEDGE3D's savesp (the longjmp), made general
; ----------------------------------------------------------------------
if used R3_SAFE
R3_SAFE:push word [r3_faults]
        call r3_guard
        push bp
        mov  bp,sp
        push ax
        mov  ax,[r3_faults]
        sub  ax,[bp+2]          ; faults caught while it ran
        mov  [r3_lastf],ax
        pop  ax
        pop  bp
        add  sp,2               ; the count we kept
        push ax
        xor  ax,ax
        cmp  ax,[r3_lastf]      ; CF = (0 < faults)
        pop  ax
        ret
end if

; r3_guard - call the routine at SI with the trap's return point set to
; just after this call; the guard before it is put back afterwards
; (guards nest).
if used r3_guard
r3_guard:
        push word [r3_savesp]
        call .g
        pop  word [r3_savesp]
        ret
.g:     mov  [r3_savesp],sp     ; the trap comes back to the RET of .g
        jmp  si
end if

; ----------------------------------------------------------------------
;  R3_INT0 - the INT 0 handler R3_TRAP installs (never call it)
;  in:  -  (the CPU enters it on a divide fault)
;  out: inside guarded 3D code: back to that code's caller as if it had
;       finished; elsewhere: to [r3_quit], or a clean exit with code 1
;  from: EXAMPLES\RELIEF.ASM TRAP0:1368-1375 (+ the unguarded way out, new)
; ----------------------------------------------------------------------
if used R3_TRAP
R3_INT0:mov  ax,cs
        mov  ds,ax              ; our data, whatever the fault had in DS
        inc  word [r3_faults]
        cld
        cmp  word [r3_savesp],0
        je   .out               ; not in guarded code
        mov  sp,[r3_savesp]     ; everything since the guard: gone
        sti                     ; the INT cleared IF on the way in
        ret                     ; ...out of the guard, as if done
.out:   mov  ax,[r3_quit]
        or   ax,ax
        jz   .die
        sti
        jmp  ax                 ; your way out
.die:   call R3_UNTRAP
        mov  ax,0003h
        int  10h                ; text mode again
        mov  dx,.msg
        mov  ah,9
        int  21h
        mov  ax,4C01h
        int  21h
.msg    db   'Divide fault outside the 3D code - stopped.',13,10,'$'
end if
