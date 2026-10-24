; ============================================================================
;  R_TERRDR.ASM - recipe: the island drawn as FILLED quads, far to near,
;  each square coloured by its highest corner and creased along its seams
;  in the same colour darker - OWL FLY's ground, as lesson 22 builds it.
;
;        call GNDORD             ; once, at the start: the drawing order
;        ...each frame, after the camera is set (R3_CAMERA or R_FLIGHT):
;        mov  es,[buffer]
;        call GNDDRAW            ; the ground, around the eye, GND_NR nodes out
;
;  The eye looks over a DISK of radius GND_NR nodes (1024 units each): the
;  first [gnddisk] entries of a table sorted by distance, drawn from the far
;  end in. A disk because a square view block's corners overflow the 16-bit
;  turn at diagonal headings (guide RENDER: Rotation). Cost is the NUMBER of
;  squares: 12 nodes = 441 squares, 24 = 1793 and a quarter of the speed.
;
;  The cull drops a square when all four corners are behind the eye, or all
;  off one side (x > 3z/4: right for FOCAL 220). It assumes a LEVEL eye -
;  with pitch or another FOCAL set [gndcull] to 0.
;
;  copy: GNDORD GNDDRAW GNDPREP GNDQUAD and the tables at the end.
;  define before: GND_NR (optional, default 12; 24 at most)
;  calls: K_3D (ROTXZ FACEFILL STROKEPOLY CLIPLINE LINE R3_SAFE, the camera
;         r3_camx/r3_camy/r3_camz), K_TERR (TER_RAW TER_WH TER_BAND; TER_PAL
;         for the colours, 1..6 and the seams 9..14)
;  needs: TER_GEN before the first frame; R3_TRAP for the divide guard
;  from: LESSONS\L22\FILL.ASM GROUND/DRAWQUAD:1181-1414, ORDPREP:1415-1531,
;        TERRPREP:1532-1681
; ============================================================================

if ~ defined GND_NR | defined gnd_dnr
GND_NR  = 12                    ; how many nodes out the ground reaches
gnd_dnr = 1
end if
GND_NS  = 2*GND_NR+1            ; squares across the block
GND_TS  = 2*GND_NR+2            ; nodes across (one more: the far edge)

gndseam db 1                    ; 1: crease each square's seams (colour + 8)
gndcull db 1                    ; 1: drop squares behind / off the sides
gnddisk dw 0                    ; squares inside the disk (GNDORD)
gndk    dw 0                    ; the square being drawn
gndn    dw 0                    ; GNDORD's scratch
gndd    dw 0
gndta   dw 0                    ; node counters
gndtb   dw 0
gndsi   dw 0                    ; the slot walking the cache
gndcgi  dw 0                    ; the node under the eye
gndcgj  dw 0
gndgi   dw 0
gndgj   dw 0
gndraw  db 0                    ; scratch: a raw height
gndqor  db 0                    ; the OR of a square's four outcodes
gndqe   dw 0                    ; the stroke's edge
gndqedg db 0                    ; the edges this square owns

;@ GNDORD     once: the ground's drawing order (a disk, nearest first), seam owners
; ---- GNDORD: the drawing order, nearest first, and each square's own edges.
;  Once at the start (it walks every square for every distance: slow).
GNDORD: push ax
        push bx
        push cx
        push dx
        push si
        mov  word [gndn],0
        mov  word [gndd],0      ; the squared distance being filled in
.dl:    mov  word [gndta],0
.al:    mov  word [gndtb],0
.bl:    mov  ax,[gndta]
        sub  ax,GND_NR          ; da
        imul ax                 ; da*da (small)
        mov  bx,ax
        mov  ax,[gndtb]
        sub  ax,GND_NR          ; db
        imul ax                 ; db*db
        add  ax,bx              ; the squared distance
        cmp  ax,[gndd]
        jne  .nx
        mov  ax,[gndta]
        mov  bx,GND_TS
        mul  bx                 ; ta*TS
        add  ax,[gndtb]
        add  ax,ax              ; the slot, in bytes (a word a node)
        mov  bx,[gndn]
        add  bx,bx
        mov  [GNDTORD+bx],ax
        mov  si,[gndn]          ; which edges are its own: those shared
        xor  al,al              ;  with FARTHER neighbours (drawn before)
        mov  bx,[gndtb]
        sub  bx,GND_NR          ; db
        cmp  bx,0
        jg   .e0
        or   al,1               ; edge 0 (corner 0 -> 1)
.e0:    cmp  bx,0
        jl   .e2
        or   al,4               ; edge 2 (corner 2 -> 3)
.e2:    mov  bx,[gndta]
        sub  bx,GND_NR          ; da
        cmp  bx,0
        jl   .e1
        or   al,2               ; edge 1 (corner 1 -> 2)
.e1:    cmp  bx,0
        jg   .e3
        or   al,8               ; edge 3 (corner 3 -> 0)
.e3:    mov  [GNDTEDGE+si],al
        inc  word [gndn]
.nx:    inc  word [gndtb]
        cmp  word [gndtb],GND_NS
        jl   .bl
        inc  word [gndta]
        cmp  word [gndta],GND_NS
        jl   .al
        cmp  word [gndd],GND_NR*GND_NR
        jne  .nd
        mov  ax,[gndn]          ; the disk of radius NR ends here
        mov  [gnddisk],ax
.nd:    inc  word [gndd]
        cmp  word [gndd],2*GND_NR*GND_NR+1
        jl   .dl
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

;@ GNDDRAW    the island as filled quads far to near, seams creased (each frame, ES)
; ---- GNDDRAW: the ground, this frame, into ES. Keeps every register.
GNDDRAW:push ax
        push bx
        push cx
        push dx
        push si
        push di
        call GNDPREP            ; every node turned ONCE into the cache
        mov  ax,[gnddisk]
        dec  ax                 ; the farthest square of the disk...
        mov  [gndk],ax
.rx:    mov  si,GNDQUAD
        call R3_SAFE            ; a divide fault drops one square, no more
        dec  word [gndk]        ; ...and nearer: the painter's algorithm
        jns  .rx
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; ---- GNDPREP: per node of the block - its place turned by the heading, its
;  height, its raw byte (for the colour) and its outcode (for the cull).
GNDPREP:mov  ax,[r3_camx]
        add  ax,TER_BIAS
        mov  cl,10
        shr  ax,cl
        mov  [gndcgi],ax        ; the node the eye is over
        mov  ax,[r3_camz]
        add  ax,TER_BIAS
        shr  ax,cl
        mov  [gndcgj],ax
        mov  word [gndsi],0
        mov  word [gndta],0
.al:    mov  word [gndtb],0
.bl:    mov  ax,[gndcgi]
        add  ax,[gndta]
        sub  ax,GND_NR
        mov  [gndgi],ax         ; this slot's node, map coordinates
        mov  ax,[gndcgj]
        add  ax,[gndtb]
        sub  ax,GND_NR
        mov  [gndgj],ax
        mov  ax,[gndgi]
        mov  cl,10
        shl  ax,cl              ; gi*1024
        sub  ax,TER_BIAS
        sub  ax,[r3_camx]
        mov  [wdx],ax           ; east of the eye
        mov  ax,[gndgj]
        shl  ax,cl
        sub  ax,TER_BIAS
        sub  ax,[r3_camz]
        mov  [wdz],ax           ; north of it
        call ROTXZ              ; rc_x, rc_z
        mov  si,[gndsi]
        mov  ax,[rc_x]
        mov  [GNDTRX+si],ax
        mov  ax,[rc_z]
        mov  [GNDTRZ+si],ax
        mov  bx,[gndgi]
        mov  dx,[gndgj]
        call TER_RAW            ; AX = the raw byte
        mov  [gndraw],al
        call TER_WH             ; AX = world height
        mov  [GNDTWY+si],ax
        shr  si,1               ; byte tables
        mov  al,[gndraw]
        mov  [GNDTH+si],al
        xor  al,al              ; the outcode: 1 behind, 2 right, 4 left
        mov  bx,[rc_z]
        cmp  bx,NEARZ
        jge  .o0
        or   al,1
.o0:    mov  dx,bx
        sar  dx,1
        sar  dx,1               ; z/4 (SAR: z can be negative)
        sub  bx,dx              ; 3z/4: the screen's half width at z
        mov  dx,[rc_x]
        cmp  dx,bx
        jle  .o1
        or   al,2
.o1:    neg  bx
        cmp  dx,bx
        jge  .o2
        or   al,4
.o2:    mov  [GNDTOUT+si],al
        add  word [gndsi],2
        inc  word [gndtb]
        cmp  word [gndtb],GND_TS
        jl   .bl
        inc  word [gndta]
        cmp  word [gndta],GND_TS
        jl   .al
        ret

; ---- GNDQUAD: square [gndk] - culled, filled, creased (under R3_SAFE)
GNDQUAD:mov  bx,[gndk]
        add  bx,bx
        mov  si,[GNDTORD+bx]    ; the slot of its first corner
        mov  di,si
        shr  di,1
        mov  al,[GNDTOUT+di]    ; AND of the codes: all outside one plane?
        mov  ah,al
        mov  bl,[GNDTOUT+di+GND_TS]
        and  al,bl
        or   ah,bl
        mov  bl,[GNDTOUT+di+GND_TS+1]
        and  al,bl
        or   ah,bl
        mov  bl,[GNDTOUT+di+1]
        and  al,bl
        or   ah,bl
        mov  [gndqor],ah        ; the OR: bit 0 = the near plane cuts it
        cmp  byte [gndcull],0
        je   .in
        or   al,al
        jnz  .skip              ; gone, not a corner loaded
.in:    mov  ax,[GNDTRX+si]     ; corner 0 = (ta, tb)
        mov  [IX],ax
        mov  ax,[GNDTRZ+si]
        mov  [IZ],ax
        mov  ax,[GNDTWY+si]
        sub  ax,[r3_camy]       ; below the eye
        mov  [IY],ax
        mov  ax,[GNDTRX+si+GND_TS*2]    ; corner 1 = (ta+1, tb)
        mov  [IX+2],ax
        mov  ax,[GNDTRZ+si+GND_TS*2]
        mov  [IZ+2],ax
        mov  ax,[GNDTWY+si+GND_TS*2]
        sub  ax,[r3_camy]
        mov  [IY+2],ax
        mov  ax,[GNDTRX+si+GND_TS*2+2]  ; corner 2 = (ta+1, tb+1)
        mov  [IX+4],ax
        mov  ax,[GNDTRZ+si+GND_TS*2+2]
        mov  [IZ+4],ax
        mov  ax,[GNDTWY+si+GND_TS*2+2]
        sub  ax,[r3_camy]
        mov  [IY+4],ax
        mov  ax,[GNDTRX+si+2]           ; corner 3 = (ta, tb+1)
        mov  [IX+6],ax
        mov  ax,[GNDTRZ+si+2]
        mov  [IZ+6],ax
        mov  ax,[GNDTWY+si+2]
        sub  ax,[r3_camy]
        mov  [IY+6],ax
        mov  al,[GNDTH+di]      ; the colour: the HIGHEST corner's band
        mov  ah,[GNDTH+di+GND_TS]
        cmp  al,ah
        jae  .c1
        mov  al,ah
.c1:    mov  ah,[GNDTH+di+GND_TS+1]
        cmp  al,ah
        jae  .c2
        mov  al,ah
.c2:    mov  ah,[GNDTH+di+1]
        cmp  al,ah
        jae  .c3
        mov  al,ah
.c3:    call TER_BAND
        mov  [COLOR],al
        call FACEFILL           ; near clip, project, fill
        cmp  byte [gndseam],0
        je   .skip
        cmp  word [NPOLY],3
        jl   .skip              ; nothing was drawn
        add  byte [COLOR],8     ; the same band, darker
        test byte [gndqor],1
        jz   .own
        call STROKEPOLY         ; cut by the near plane: outline it whole
        ret
.own:   mov  bx,[gndk]
        mov  al,[GNDTEDGE+bx]   ; only the edges it owns
        mov  [gndqedg],al
        mov  word [gndqe],0
.e:     shr  byte [gndqedg],1
        jnc  .en
        mov  si,[gndqe]
        mov  ax,[PX+si]
        mov  [sx0],ax
        mov  ax,[PY+si]
        mov  [sy0],ax
        add  si,2
        and  si,7               ; corner 3 -> corner 0
        mov  ax,[PX+si]
        mov  [sx1],ax
        mov  ax,[PY+si]
        mov  [sy1],ax
        call CLIPLINE
        jc   .en
        call LINE
.en:    add  word [gndqe],2
        cmp  word [gndqe],8
        jl   .e
.skip:  ret

GNDTRX   dw GND_TS*GND_TS dup(0)  ; each node turned: right of the eye
GNDTRZ   dw GND_TS*GND_TS dup(0)  ; ...ahead of it
GNDTWY   dw GND_TS*GND_TS dup(0)  ; ...its world height
GNDTH    db GND_TS*GND_TS dup(0)  ; ...its raw byte
GNDTOUT  db GND_TS*GND_TS dup(0)  ; ...its outcode
GNDTORD  dw GND_NS*GND_NS dup(0)  ; squares by distance, nearest first
GNDTEDGE db GND_NS*GND_NS dup(0)  ; ...and the edges each one owns
