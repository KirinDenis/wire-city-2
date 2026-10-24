; ============================================================================
;  R_WIRE.ASM - recipe: the island as a WIREFRAME relief, with a floating
;  horizon so the hills hide what is behind them: one byte per screen
;  column holds the highest thing drawn there so far, the lattice is drawn
;  from the eye OUTWARD, and a pixel shows only above its column's skyline.
;  That is the whole of hidden-line removal, and it is 320 bytes.
;
;        call WIRORD             ; once: the drawing order, nearest first
;        ...each frame, after the camera is set:
;        mov  es,[buffer]        ; (cleared: nothing else is painted)
;        call WIRDRAW            ; the lattice, WIR_NR nodes out
;
;  [wirhide] = 0 draws every line (see-through). Every node's height is
;  doubled once more than K_TERR's (TER_VEX) would - a wire slope reads
;  flat otherwise - set [wirvex] to 0 for the ground's own. The lattice is
;  a SQUARE block: keep WIR_NR at 12 or less (its corners must stay under
;  ~23000 after the turn). Pitch works (the nodes are pitched in the cache).
;
;  copy: WIRORD WIRDRAW WIRPREP WIRLINE and the tables at the end.
;  define before: WIR_NR (optional, default 12)
;  calls: K_3D (R3_VIEW R3_EDGEC, r3_line), K_TERR (TER_RAW TER_WH TER_BAND)
;  from: EXAMPLES\RELIEF.ASM GRIDC:835-927, ORDPREP:928-1001, TERRPREP:
;        1002-1104, HLINE:1266-1335, the skyline reset in FRAME:635-641
; ============================================================================

if ~ defined WIR_NR | defined wir_dnr
WIR_NR  = 12                    ; how many nodes out
wir_dnr = 1
end if
WIR_NS  = 2*WIR_NR+1            ; squares across
WIR_TS  = 2*WIR_NR+2            ; nodes across

wirhide db 1                    ; 1: the skyline hides; 0: see-through
wirvex  db 1                    ; extra doublings of the height (wire only)
wirk    dw 0                    ; the square being drawn
wirn    dw 0                    ; WIRORD scratch
wird    dw 0
wirta   dw 0
wirtb   dw 0
wirsi   dw 0
wircgi  dw 0
wircgj  dw 0
wirgi   dw 0
wirgj   dw 0
wirraw  db 0
wirhsx  dw 0                    ; WIRLINE's state
wirhsy  dw 0
wirhdx  dw 0
wirhdy  dw 0
wirherr dw 0
wirhx   dw 0
wirhy   dw 0
wirhrow dw 0

;@ WIRORD     once: the wire lattice's drawing order, nearest first
; ---- WIRORD: every square of the block by squared distance, nearest first
WIRORD: push ax
        push bx
        push dx
        mov  word [wirn],0
        mov  word [wird],0
.dl:    mov  word [wirta],0
.al:    mov  word [wirtb],0
.bl:    mov  ax,[wirta]
        sub  ax,WIR_NR
        imul ax                 ; da*da
        mov  bx,ax
        mov  ax,[wirtb]
        sub  ax,WIR_NR
        imul ax                 ; db*db
        add  ax,bx              ; the squared distance
        cmp  ax,[wird]
        jne  .nx
        mov  ax,[wirta]
        mov  bx,WIR_TS
        mul  bx                 ; ta*TS
        add  ax,[wirtb]
        add  ax,ax              ; a word a node
        mov  bx,[wirn]
        add  bx,bx
        mov  [WIRTORD+bx],ax
        inc  word [wirn]
.nx:    inc  word [wirtb]
        cmp  word [wirtb],WIR_NS
        jl   .bl
        inc  word [wirta]
        cmp  word [wirta],WIR_NS
        jl   .al
        inc  word [wird]
        cmp  word [wird],2*WIR_NR*WIR_NR+1
        jl   .dl
        pop  dx
        pop  bx
        pop  ax
        ret

;@ WIRDRAW    the island as a wireframe relief, hills hiding hills (floating horizon)
; ---- WIRDRAW: the lattice into ES, nearest square first. Keeps registers.
WIRDRAW:push ax
        push bx
        push cx
        push dx
        push si
        push di
        push es
        push ds
        pop  es
        mov  di,WIRHOR          ; the skyline starts at the floor: the first
        mov  al,200             ;  thing drawn in a column always shows
        mov  cx,320
        cld
        rep  stosb
        pop  es
        call WIRPREP
        mov  ax,WIRLINE         ; the edges go through our line, not LINE
        cmp  byte [wirhide],0
        jne  .h
        xor  ax,ax
.h:     mov  [r3_line],ax
        mov  word [wirk],0
.rx:    mov  bx,[wirk]
        add  bx,bx
        mov  si,[WIRTORD+bx]    ; the square's first node
        mov  di,si
        shr  di,1
        mov  al,[WIRTCOL+di]    ; its colour
        push ax
        mov  di,si              ; ---- the edge going east ----
        add  di,WIR_TS*2
        call .edge
        pop  ax
        push ax
        mov  di,si              ; ---- the edge going north ----
        add  di,2
        call .edge
        pop  ax
        inc  word [wirk]
        cmp  word [wirk],WIR_NS*WIR_NS
        jl   .rx
        mov  word [r3_line],0
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
; .edge: node slot SI to node slot DI, colour AL (SI kept)
.edge:  mov  bx,[WIRTX+si]
        mov  [r3_vx0],bx
        mov  bx,[WIRTY+si]
        mov  [r3_vy0],bx
        mov  bx,[WIRTZ+si]
        mov  [r3_vz0],bx
        mov  bx,[WIRTX+di]
        mov  [r3_vx1],bx
        mov  bx,[WIRTY+di]
        mov  [r3_vy1],bx
        mov  bx,[WIRTZ+di]
        mov  [r3_vz1],bx
        call R3_EDGEC           ; near clip, project, screen clip, draw
        ret

; ---- WIRPREP: every node of the block, camera space (turned + pitched)
WIRPREP:mov  ax,[r3_camx]
        add  ax,TER_BIAS
        mov  cl,10
        shr  ax,cl
        mov  [wircgi],ax        ; the node under the eye
        mov  ax,[r3_camz]
        add  ax,TER_BIAS
        shr  ax,cl
        mov  [wircgj],ax
        mov  word [wirsi],0
        mov  word [wirta],0
.al:    mov  word [wirtb],0
.bl:    mov  ax,[wircgi]
        add  ax,[wirta]
        sub  ax,WIR_NR
        mov  [wirgi],ax
        mov  ax,[wircgj]
        add  ax,[wirtb]
        sub  ax,WIR_NR
        mov  [wirgj],ax
        mov  bx,[wirgi]
        mov  dx,[wirgj]
        call TER_RAW            ; AX = the raw byte
        mov  [wirraw],al
        call TER_WH             ; AX = world height
        mov  cl,[wirvex]
        shl  ax,cl              ; and the wire's own exaggeration
        mov  bx,ax              ; BX = y
        mov  ax,[wirgi]
        mov  cl,10
        shl  ax,cl
        sub  ax,TER_BIAS        ; AX = x
        mov  cx,[wirgj]
        push ax
        mov  ax,cx
        mov  cl,10
        shl  ax,cl
        sub  ax,TER_BIAS
        mov  cx,ax              ; CX = z
        pop  ax
        call R3_VIEW            ; camera space
        mov  si,[wirsi]
        mov  [WIRTX+si],ax
        mov  [WIRTY+si],bx
        mov  [WIRTZ+si],cx
        shr  si,1
        mov  al,[wirraw]
        call TER_BAND
        mov  [WIRTCOL+si],al
        add  word [wirsi],2
        inc  word [wirtb]
        cmp  word [wirtb],WIR_TS
        jl   .bl
        inc  word [wirta]
        cmp  word [wirta],WIR_TS
        jl   .al
        ret

;@ WIRLINE    a clipped screen line drawn only above the skyline (an r3_line hook)
; ---- WIRLINE: LINE that asks the skyline before every pixel. In: sx0..sy1
;  clipped to the screen, COLOR, ES. A pixel shows only if it is above
;  WIRHOR[x], and then it IS the skyline there.
WIRLINE:mov  ax,[sx1]
        sub  ax,[sx0]
        mov  word [wirhsx],1
        jns  .xok
        neg  ax                 ; |dx|
        mov  word [wirhsx],-1
.xok:   mov  [wirhdx],ax
        mov  ax,[sy1]
        sub  ax,[sy0]
        mov  word [wirhsy],1
        jns  .yok
        neg  ax                 ; |dy|
        mov  word [wirhsy],-1
.yok:   mov  [wirhdy],ax
        mov  ax,320
        imul word [wirhsy]      ; +320 or -320: a step in y
        mov  [wirhrow],ax
        mov  ax,[wirhdx]
        sub  ax,[wirhdy]
        mov  [wirherr],ax       ; the error starts as the difference
        mov  ax,[sx0]
        mov  [wirhx],ax
        mov  ax,[sy0]
        mov  [wirhy],ax
        mov  bx,320
        mul  bx                 ; AX = sy0 * 320
        add  ax,[sx0]
        mov  di,ax              ; the first pixel
.plot:  mov  bx,[wirhx]
        mov  al,[WIRHOR+bx]     ; the skyline in this column
        xor  ah,ah
        cmp  ax,[wirhy]
        jle  .on                ; at or below it: hidden
        mov  ax,[wirhy]
        mov  [WIRHOR+bx],al     ; the new skyline
        mov  al,[COLOR]
        mov  [es:di],al
.on:    mov  ax,[wirhx]
        cmp  ax,[sx1]
        jne  .step
        mov  ax,[wirhy]
        cmp  ax,[sy1]
        je   .done
.step:  mov  ax,[wirherr]
        add  ax,ax
        mov  bx,ax              ; e2 = err*2
        mov  ax,[wirhdy]
        neg  ax
        cmp  bx,ax              ; e2 > -dy ?
        jle  .nox
        mov  ax,[wirherr]
        sub  ax,[wirhdy]
        mov  [wirherr],ax
        mov  ax,[wirhx]
        add  ax,[wirhsx]
        mov  [wirhx],ax
        add  di,[wirhsx]
.nox:   cmp  bx,[wirhdx]        ; e2 < dx ?
        jge  .plot
        mov  ax,[wirherr]
        add  ax,[wirhdx]
        mov  [wirherr],ax
        mov  ax,[wirhy]
        add  ax,[wirhsy]
        mov  [wirhy],ax
        add  di,[wirhrow]
        jmp  .plot
.done:  ret

WIRTX   dw WIR_TS*WIR_TS dup(0) ; each node, camera space
WIRTY   dw WIR_TS*WIR_TS dup(0)
WIRTZ   dw WIR_TS*WIR_TS dup(0)
WIRTCOL db WIR_TS*WIR_TS dup(0) ; ...and its band colour
WIRTORD dw WIR_NS*WIR_NS dup(0) ; squares, nearest first
WIRHOR  db 320 dup(200)         ; THE SKYLINE: a byte a column
