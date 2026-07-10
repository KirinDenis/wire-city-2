; ============================================================================
;  JET.COM - WIRE CITY engine example 03: the aircraft
;
;  The whole jet is 13 vertices and 8 quad faces (triangles repeat a
;  corner). Every frame: rotate the vertices with the quarter-table sine,
;  average each face's corner depths, bubble-sort the faces far -> near
;  (between two frames the order barely changes, so the bubble is nearly
;  O(n) - and n is 8), then hand each face to the engine pipeline:
;  near-clip -> perspective-project -> scanline-fill. Painter's algorithm:
;  no z-buffer anywhere, the near faces simply paint over the far ones.
;
;  Left / Right arrows change the spin, ESC quits. The nozzle burns by
;  DAC cycling: one palette register rewritten every few frames - the
;  pixels never change, the COLOUR does.
;
;  ~3 KB of .COM on the same ENGINE\ modules the game flies on.
; ============================================================================
FOCAL   equ 220                 ; the game's lens
NEARZ   equ 40                  ; near clip plane
NFACE   equ 8

        .8086
        LOCALS
        JUMPS
CODE    SEGMENT
        ASSUME cs:CODE, ds:CODE, es:CODE, ss:CODE
        ORG  100h

START:  cld
        mov  ax,cs              ; back buffer: the 64K above the program
        add  ax,1000h
        mov  [bufseg],ax
        mov  ax,0013h           ; VGA 320x200, 256 colours
        int  10h
        call SETPAL
        call SETTRIG            ; camera trig for a straight, level view
                                ; (heading/pitch/roll all zero)
; ---- one frame -------------------------------------------------------------
@@frame:
        mov  ax,[bufseg]        ; clear the back buffer
        mov  es,ax
        xor  di,di
        xor  ax,ax
        mov  cx,32000
        rep  stosw
        ; ---- spin, then model yaw -> msin/mcos ----
        mov  ax,[spd]
        add  [mhead],ax
        and  word ptr [mhead],255
        mov  ax,[mhead]
        call SINQ
        mov  [msin],ax
        mov  ax,[mhead]
        add  ax,64
        call SINQ
        mov  [mcos],ax
        ; ---- transform the 13 vertices into the cache (x8 scale) ----
        xor  si,si              ; model table offset (6 bytes/vertex)
        xor  di,di              ; cache offset (2 bytes/vertex)
@@tv:   mov  ax,[MVERT+si]      ; vx = (mx*mcos + mz*msin)/256
        imul word ptr [mcos]
        mov  bx,ax
        mov  ax,[MVERT+si+4]
        imul word ptr [msin]
        add  ax,bx
        cwd
        mov  bx,256
        idiv bx
        mov  cl,3
        shl  ax,cl              ; x8: the model ships quarter-scale
        mov  [PVX+di],ax
        mov  ax,[MVERT+si+2]    ; vy = my (x8), a bit below the eye
        shl  ax,cl
        sub  ax,20
        mov  [PVY+di],ax
        mov  ax,[MVERT+si]      ; vz = (mz*mcos - mx*msin)/256
        imul word ptr [msin]
        mov  bx,ax
        mov  ax,[MVERT+si+4]
        imul word ptr [mcos]
        sub  ax,bx
        cwd
        mov  bx,256
        idiv bx
        mov  cl,3
        shl  ax,cl
        add  ax,300             ; park it in front of the lens
        mov  [PVZ+di],ax
        add  si,6
        add  di,2
        cmp  si,13*6
        jb   @@tv
        ; ---- face depths: FCD = avg z of the face corners ----
        xor  si,si
@@fd:   mov  bx,si
        add  bx,bx
        add  bx,bx
        add  bx,si              ; face record = 5 bytes
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
        ; ---- draw the faces in painter order ----
        mov  word ptr [pfc],0
@@df:   mov  si,[pfc]
        mov  al,[FCO+si]
        xor  ah,ah
        mov  bx,ax
        add  bx,bx
        add  bx,bx
        add  ax,bx              ; *5
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
        ; ---- the nozzle burns: DAC-cycle colour 94 ----
        inc  word ptr [gcnt]
        test word ptr [gcnt],7
        jnz  @@ng
        mov  bx,[gph]
        add  bx,bx
        add  bx,[gph]           ; *3
        mov  dx,3C8h
        mov  al,94
        out  dx,al
        inc  dx
        mov  al,[GLOWT+bx]
        out  dx,al
        mov  al,[GLOWT+bx+1]
        out  dx,al
        mov  al,[GLOWT+bx+2]
        out  dx,al
        inc  word ptr [gph]
        cmp  word ptr [gph],3
        jb   @@ng
        mov  word ptr [gph],0
@@ng:
        ; ---- vsync, blit, keys ----
        call WAITVR
        push ds
        mov  ax,0A000h
        mov  es,ax
        mov  ds,[bufseg]        ; DS is still ours at this point
        xor  si,si
        xor  di,di
        mov  cx,32000
        rep  movsw
        pop  ds
        mov  ah,1               ; a key?
        int  16h
        jz   @@frame
        xor  ah,ah
        int  16h
        cmp  al,27
        je   @@quit
        or   al,al              ; extended key? AH = scan code
        jnz  @@frame
        cmp  ah,4Bh             ; Left: spin slower / the other way
        jne  @@kr
        dec  word ptr [spd]
        cmp  word ptr [spd],-4
        jge  @@frame
        mov  word ptr [spd],-4
        jmp  @@frame
@@kr:   cmp  ah,4Dh             ; Right: spin faster
        jne  @@frame
        inc  word ptr [spd]
        cmp  word ptr [spd],4
        jle  @@frame
        mov  word ptr [spd],4
        jmp  @@frame
@@quit: mov  ax,0003h
        int  10h
        mov  ax,4C00h
        int  21h

; ---- wait for the vertical retrace edge ------------------------------------
WAITVR: mov  dx,3DAh
@@w1:   in   al,dx
        test al,8
        jnz  @@w1
@@w2:   in   al,dx
        test al,8
        jz   @@w2
        ret

; ---- the few DAC entries this model wears ----------------------------------
SETPAL: mov  si,offset PAL
@@p:    lodsb
        cmp  al,255
        je   @@done
        mov  dx,3C8h
        out  dx,al
        inc  dx
        lodsb
        out  dx,al
        lodsb
        out  dx,al
        lodsb
        out  dx,al
        jmp  @@p
@@done: ret
PAL     db   0,  2, 4,12        ; backdrop: night blue
        db  16, 20,20,22        ; body shade
        db  24, 52,52,56        ; body sun-lit
        db  25, 34,34,38        ; body sides / fin
        db  27, 44,44,46        ; wings
        db  94, 63,34, 6        ; nozzle (cycled)
        db 255

; ---- the aircraft: 13 vertices, 8 faces (from the game's DATA.INC) ---------
; model vertices (x,y,z), nose +Z, wingspan ~104 world units
MVERT   dw   0,  1, 16          ; 0 nose
        dw  -2,  2,-11          ; 1 rear top L
        dw   2,  2,-11          ; 2 rear top R
        dw  -2, -2,-11          ; 3 rear bottom L
        dw   2, -2,-11          ; 4 rear bottom R
        dw -13,  1, -8          ; 5 wing tip L
        dw  13,  1, -8          ; 6 wing tip R
        dw   0,  1,  6          ; 7 wing root fore
        dw  -2,  1,-11          ; 8 wing rear L
        dw   2,  1,-11          ; 9 wing rear R
        dw   0,  2, -5          ; 10 fin base fore
        dw   0,  7,-13          ; 11 fin top rear
        dw   0,  2,-11          ; 12 fin base rear
; faces: 4 corner ids (triangles repeat the first) + colour
MFACE   db 0,1,2,0, 24          ; body top (sun-lit)
        db 0,3,4,0, 16          ; body bottom (shade)
        db 0,1,3,0, 25          ; body left
        db 0,2,4,0, 25          ; body right
        db 7,5,8,7, 27          ; wing L
        db 7,6,9,7, 27          ; wing R
        db 10,11,12,10, 25      ; tail fin
        db 1,2,4,3, 94          ; engine nozzle: palette-cycled fire
GLOWT   db 63,52,12             ; nozzle DAC cycle: yellow
        db 63,34, 6             ; orange
        db 56,14, 4             ; red

; ---- engine contract: E_M3D + E_RAST (see the module headers) --------------
bufseg  dw 0
mhead   dw 0                    ; model heading (the spin)
spd     dw 1                    ; spin per frame (arrows, -4..4)
gcnt    dw 0                    ; glow frame counter
gph     dw 0                    ; glow phase 0..2
heading dw 0                    ; camera: straight, level, still
pitch   dw 0
roll    dw 0
hsin    dw 0
hcos    dw 256
rsin    dw 0
rcos    dw 256
psin    dw 0
pcos    dw 256
pofs    dw 0
horiz   dw 100
swayx   dw 0
swayy   dw 0
wdx     dw 0
wdz     dw 0
rcx     dw 0
rcz     dw 0
rddx    dw 0
rddy    dw 0
rsxo    dw 0
ptmp    dw 0
msin    dw 0                    ; model yaw sin/cos
mcos    dw 0
pfc     dw 0                    ; face draw counter
PVX     dw 13 dup(0)            ; camera-space vertex cache
PVY     dw 13 dup(0)
PVZ     dw 13 dup(0)
FCD     dw NFACE dup(0)         ; face depths for the painter sort
FCO     db NFACE dup(0)         ; face draw order
IX      dw 4 dup(0)             ; face input verts (3D)
IY      dw 4 dup(0)
IZ      dw 4 dup(0)
OX      dw 6 dup(0)             ; near-clipped verts
OY      dw 6 dup(0)
OZ      dw 6 dup(0)
PX      dw 6 dup(0)             ; projected verts (screen)
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
tnum    dw 0                    ; clip interpolation scratch
tden    dw 0
cdx     dw 0                    ; line clip deltas / new point
cdy     dw 0
nx      dw 0
ny      dw 0
oc0     db 0                    ; Cohen-Sutherland outcodes
oc1     db 0
ocsel   db 0
lx      dw 0                    ; Bresenham state (LINE)
ly      dw 0
ldx     dw 0
ldy     dw 0
lsx     dw 0
lsy     dw 0
lerr    dw 0
sx0     dw 0
sy0     dw 0
sx1     dw 0
sy1     dw 0
COLOR   db 0
; quarter sine table: SINT[i] = round(256*sin(i*90/64 deg)), i=0..64
SINT    dw 0,6,13,19,25,31,38,44,50,56,62,68,74,80,86,92,98,104,109,115
        dw 121,126,132,137,142,147,153,157,162,167,172,177,181,185,190,194
        dw 198,202,206,209,213,216,220,223,226,229,231,234,237,239,241,243
        dw 245,247,248,250,251,252,253,254,255,255,256,256,256

        INCLUDE ..\ENGINE\E_M3D.INC
        INCLUDE ..\ENGINE\E_RAST.INC

CODE    ENDS
        END START
