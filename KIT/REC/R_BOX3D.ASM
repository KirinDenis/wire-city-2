; ============================================================================
;  R_BOX3D.ASM - recipe: solid box buildings. A box shows only the walls
;  that face the eye (the west wall only from the west...) and its roof
;  only from above - decided in the WORLD, so it holds at any heading -
;  each filled and, if asked, outlined; boxes are painted far to near.
;
;        mov  si,TOWN            ; the boxes: BOXW words each (below)
;        mov  cx,TOWNN           ; how many (BOXMAX at most)
;        mov  es,[buffer]
;        call BOXALL             ; sorted far to near, culled, drawn
;
;  A box, 8 words:  x, z         its middle (world)
;                   hw, hd       half its width (x) and depth (z)
;                   y0, y1       its foot and its top (world heights)
;                   lit, shade   db colours: south/north walls, east/west
;                   roof, line   db colours: the roof; the outline (0: none)
;  e.g.     dw 2000,3000, 200,150, 0,600
;           db 24,22, 26,0
;
;  Boxes are not sorted against the ground: draw the ground first, then the
;  boxes (a house behind a ridge paints over it - guide RENDER). Put the
;  foot at the ground's height there (K_TERR's TER_H) or a little under.
;
;  copy: BOXALL BOXDRAW and their words.
;  define before: BOXMAX (optional, default 32), BOXFAR (optional, 20000:
;         a box wholly farther than this is not drawn)
;  calls: K_3D (R3_YAW, R3_QUAD, r3_wirec, the camera)
;  from: GAMES\OWLFLY3\SRC\WORLD.INC DRAWBOX:235-270, ROTCUL:596-680,
;        VISFILL:682-719 (+ WORLD2.INC FACEV/FACETOPC: the corners); the
;        sort is new (OWL FLY's town is drawn in a precomputed cell order)
; ============================================================================

if ~ defined BOXMAX | defined box_d1
BOXMAX  = 32                    ; boxes BOXALL can sort
box_d1  = 1
end if
if ~ defined BOXFAR | defined box_d2
BOXFAR  = 20000                 ; farther than this: not drawn
box_d2  = 1
end if
BOXW    = 16                    ; bytes a box

boxp    dw 0                    ; the box being drawn (its 8 words)
boxc    db 0                    ; the wall being drawn: its colour
boxx0   dw 0                    ; its bounds, world
boxx1   dw 0
boxz0   dw 0
boxz1   dw 0
boxmin  dw 0                    ; its nearest and farthest corner, ahead
boxmax  dw 0
boxn    dw 0                    ; BOXALL: how many
boxt    dw 0                    ; BOXALL: the table
boxkey  dw BOXMAX dup(0)        ; each box's distance...
boxord  dw BOXMAX dup(0)        ; ...and the drawing order (box offsets)

;@ BOXALL     solid boxes from a table, sorted far to near, culled, drawn
; ---- BOXALL: the boxes at SI, CX of them, far to near. Keeps registers.
BOXALL: push ax
        push bx
        push cx
        push dx
        push si
        push di
        cmp  cx,BOXMAX
        jbe  .n
        mov  cx,BOXMAX          ; no more than the table holds
.n:     mov  [boxn],cx
        jcxz .done
        xor  di,di
.k:     mov  ax,[si]            ; the key: |dx| + |dz| (unsigned, no MUL)
        sub  ax,[r3_camx]
        jns  .k1
        neg  ax
.k1:    mov  bx,[si+2]
        sub  bx,[r3_camz]
        jns  .k2
        neg  bx
.k2:    add  ax,bx
        jnc  .k3
        mov  ax,0FFFFh          ; past 65535: as far as it gets
.k3:    mov  [boxkey+di],ax
        mov  [boxord+di],si
        add  si,BOXW
        add  di,2
        loop .k
        mov  cx,[boxn]          ; ---- insertion sort, farthest first ----
        cmp  cx,1
        jbe  .draw
        mov  si,2               ; SI = i*2, i from 1
.i:     mov  ax,[boxkey+si]
        mov  dx,[boxord+si]
        mov  di,si
.j:     or   di,di
        jz   .put
        cmp  [boxkey+di-2],ax   ; the one before is nearer?
        jae  .put               ;   no: here it goes
        mov  bx,[boxkey+di-2]   ;   yes: it moves up one
        mov  [boxkey+di],bx
        mov  bx,[boxord+di-2]
        mov  [boxord+di],bx
        sub  di,2
        jmp  .j
.put:   mov  [boxkey+di],ax
        mov  [boxord+di],dx
        add  si,2
        mov  ax,[boxn]
        add  ax,ax
        cmp  si,ax
        jb   .i
.draw:  xor  di,di
        mov  cx,[boxn]
.d:     mov  si,[boxord+di]
        call BOXDRAW
        add  di,2
        loop .d
.done:  pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

;@ BOXDRAW    one solid box: only the walls that face the eye, the roof from above
; ---- BOXDRAW: the box at SI (8 words, above) into ES. Keeps registers.
BOXDRAW:push ax
        push bx
        push cx
        push dx
        push si
        push di
        mov  [boxp],si
        mov  ax,[si]            ; the bounds
        sub  ax,[si+4]
        mov  [boxx0],ax         ; x - hw
        mov  ax,[si]
        add  ax,[si+4]
        mov  [boxx1],ax         ; x + hw
        mov  ax,[si+2]
        sub  ax,[si+6]
        mov  [boxz0],ax         ; z - hd
        mov  ax,[si+2]
        add  ax,[si+6]
        mov  [boxz1],ax         ; z + hd
        mov  word [boxmin],32767 ; ---- the cull: the footprint, turned ----
        mov  word [boxmax],-32768
        mov  ax,[boxx0]
        mov  cx,[boxz0]
        call .trk
        mov  ax,[boxx1]
        mov  cx,[boxz0]
        call .trk
        mov  ax,[boxx1]
        mov  cx,[boxz1]
        call .trk
        mov  ax,[boxx0]
        mov  cx,[boxz1]
        call .trk
        cmp  word [boxmax],NEARZ
        jl   .x                 ; wholly behind
        cmp  word [boxmin],BOXFAR
        jg   .x                 ; wholly too far
        mov  si,[boxp]
        mov  al,[si+15]         ; the outline colour: 0 = none
        mov  [r3_wirec],al
        ; ---- the roof, from above ----
        mov  ax,[r3_camy]
        cmp  ax,[si+10]
        jle  .walls
        mov  ax,[boxx0]
        mov  bx,[boxz0]
        mov  cx,[boxx1]
        mov  dx,[boxz1]
        mov  [r3_qx],ax         ; (x0,z0) (x1,z0) (x1,z1) (x0,z1) at y1
        mov  [r3_qz],bx
        mov  [r3_qx+2],cx
        mov  [r3_qz+2],bx
        mov  [r3_qx+4],cx
        mov  [r3_qz+4],dx
        mov  [r3_qx+6],ax
        mov  [r3_qz+6],dx
        mov  ax,[si+10]
        mov  [r3_qy],ax
        mov  [r3_qy+2],ax
        mov  [r3_qy+4],ax
        mov  [r3_qy+6],ax
        mov  al,[si+14]
        call .quad
.walls: mov  ax,[boxx0]         ; ---- west: the eye west of x0 ----
        sub  ax,[r3_camx]
        jle  .e
        mov  si,[boxp]
        mov  al,[si+13]         ; the shaded colour (east/west)
        mov  [boxc],al
        mov  ax,[boxx0]
        mov  bx,[boxz1]
        mov  cx,[boxx0]
        mov  dx,[boxz0]
        call .wall
.e:     mov  ax,[r3_camx]       ; east: the eye east of x1
        sub  ax,[boxx1]
        jle  .s
        mov  si,[boxp]
        mov  al,[si+13]
        mov  [boxc],al
        mov  ax,[boxx1]
        mov  bx,[boxz0]
        mov  cx,[boxx1]
        mov  dx,[boxz1]
        call .wall
.s:     mov  ax,[boxz0]         ; south: the eye south of z0
        sub  ax,[r3_camz]
        jle  .nn
        mov  si,[boxp]
        mov  al,[si+12]         ; the lit colour (south/north)
        mov  [boxc],al
        mov  ax,[boxx0]
        mov  bx,[boxz0]
        mov  cx,[boxx1]
        mov  dx,[boxz0]
        call .wall
.nn:    mov  ax,[r3_camz]       ; north: the eye north of z1
        sub  ax,[boxz1]
        jle  .x
        mov  si,[boxp]
        mov  al,[si+12]
        mov  [boxc],al
        mov  ax,[boxx1]
        mov  bx,[boxz1]
        mov  cx,[boxx0]
        mov  dx,[boxz1]
        call .wall
.x:     pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
; .wall: from (AX,BX) to (CX,DX) along the ground, foot to top; the colour
; is [boxc]
.wall:  mov  si,[boxp]
        mov  [r3_qx],ax         ; corner a, foot
        mov  [r3_qz],bx
        mov  [r3_qx+2],ax       ; corner a, top
        mov  [r3_qz+2],bx
        mov  [r3_qx+4],cx       ; corner b, top
        mov  [r3_qz+4],dx
        mov  [r3_qx+6],cx       ; corner b, foot
        mov  [r3_qz+6],dx
        mov  ax,[si+8]
        mov  [r3_qy],ax
        mov  [r3_qy+6],ax
        mov  ax,[si+10]
        mov  [r3_qy+2],ax
        mov  [r3_qy+4],ax
        mov  al,[boxc]          ; AL = the colour
; .quad: R3_QUAD in colour AL, outlined when [r3_wirec] is not 0
.quad:  mov  ah,0
        cmp  byte [r3_wirec],0
        je   .q
        mov  ah,2               ; filled + outline
.q:     call R3_QUAD
        ret
; .trk: corner (AX = x, CX = z) turned; its depth into boxmin/boxmax
.trk:   push ax
        push bx
        push cx
        mov  bx,[r3_camy]       ; (the height does not matter here)
        call R3_YAW             ; CX = ahead of the eye
        cmp  cx,[boxmin]
        jge  .t1
        mov  [boxmin],cx
.t1:    cmp  cx,[boxmax]
        jle  .t2
        mov  [boxmax],cx
.t2:    pop  cx
        pop  bx
        pop  ax
        ret
