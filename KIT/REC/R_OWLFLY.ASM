; R_OWLFLY.ASM - an owl flies in from the screen's edge, sits on its cell, flies off (mode 13h)
; ============================================================================
;  Recipe: copy after your program's way out (or include it there).
;  The owl of MULTIPLAY SOKO II: it flies in from the left or the right
;  edge at 36 px a second (2 px a tick each way at most), lands on its
;  wall, sits (frame 0) until the game sends it off, then flies off the
;  nearer way, up past the top. Its frames: KIT\ART\OWL.TXT (OWL16S
;  sitting, OWL16U / OWL16D wings up / down, swapped every 2 ticks).
;  Use: OWLCALL once with the cell to land on; OWLTICK every pass of the
;  main loop (it moves by the ticks gone, capped, so a stall never makes it
;  jump); OWLDRAW every frame after the background; OWLAWAY to send it.
;  It hoots on landing in the game: put your sound where ".land" says.
;  Lay the dusk over it again after drawing (R_DUSK.ASM DUSK on its box).
;  States [ow_st]: 0 none, 1 flying in, 2 sitting, 3 flying off.
; ============================================================================

; ----------------------------------------------------------------------
;@ OWLCALL    an owl comes: from the left or right edge to cell BX, DX
;  in:  BX, DX = the top left of the 16x16 cell it lands on
;  out: -
;  needs: [now] (R_CLOCK.ASM)
;  from: GAMES\MULTSOK2\SCENE.INC BIRDTICK 2827-2845 (proven there)
; ----------------------------------------------------------------------
OWLCALL:push ax
        mov  [ow_tx],bx
        mov  [ow_ty],dx
        mov  word [ow_x],-16    ; in from the left...
        test word [now],1
        jz   .side
        mov  word [ow_x],320    ; ...or the right
.side:  mov  word [ow_y],0
        mov  ax,[now]
        mov  [ow_when],ax
        mov  byte [ow_st],1
        pop  ax
        ret

; ----------------------------------------------------------------------
;@ OWLAWAY    the sitting owl flies off, the nearer way, up past the top
;  in:  -
;  out: -
;  needs: -
;  from: GAMES\MULTSOK2\SCENE.INC BIRDTICK .leave 2880-2887
; ----------------------------------------------------------------------
OWLAWAY:cmp  byte [ow_st],0
        je   .r
        mov  byte [ow_st],3
        mov  word [ow_tx],-24
        cmp  word [ow_x],160
        jl   .s0
        mov  word [ow_tx],330   ; the nearer edge
.s0:    mov  word [ow_ty],-24
.r:     ret

; ----------------------------------------------------------------------
;@ OWLTICK    the owl's flight: 2 px a tick each way, by the ticks gone
;  in:  -
;  out: CF = 1 when it moved (draw a frame)
;  needs: [now] (R_CLOCK.ASM)
;  from: GAMES\MULTSOK2\SCENE.INC BIRDTICK 2827-2933 (proven there)
; ----------------------------------------------------------------------
OWLTICK:push ax
        push cx
        push dx
        mov  ax,[now]
        mov  dx,ax
        sub  dx,[ow_when]       ; ticks since the last call
        mov  [ow_when],ax
        cmp  dx,8
        jbe  .dt
        mov  dx,8               ; capped: a stall never makes it jump
.dt:    mov  cx,dx
        shl  cx,1               ; at most 2 px a tick each way
        mov  al,[ow_st]
        cmp  al,1
        je   .move
        cmp  al,3
        je   .move
        clc                     ; none, or sitting: nothing moves
        jmp  .r
.move:  mov  ax,[ow_tx]
        sub  ax,[ow_x]
        call OW_STEP
        add  [ow_x],ax
        mov  ax,[ow_ty]
        sub  ax,[ow_y]
        call OW_STEP
        add  [ow_y],ax
        mov  ax,[ow_tx]         ; there only when both are
        cmp  ax,[ow_x]
        jne  .on
        mov  ax,[ow_ty]
        cmp  ax,[ow_y]
        jne  .on
        cmp  byte [ow_st],1
        jne  .gone
.land:  mov  byte [ow_st],2     ; landed (the game hoots here)
        jmp  .on
.gone:  mov  byte [ow_st],0     ; off the screen: gone
.on:    stc
.r:     pop  dx
        pop  cx
        pop  ax
        ret
; OW_STEP - AX = the way left, CX = the most: AX = this step
OW_STEP:or   ax,ax
        jns  .p
        neg  ax
        cmp  ax,cx
        jbe  .n
        mov  ax,cx
.n:     neg  ax
        ret
.p:     cmp  ax,cx
        jbe  .r
        mov  ax,cx
.r:     ret

; ----------------------------------------------------------------------
;@ OWLDRAW    the owl now: sitting, or flying with its wings beating
;  in:  -
;  out: -
;  needs: DRAWTXT (SI picture at BX, DX, see-through, clipped, keeps all),
;       [now], KIT\ART\OWL.TXT included (OWL16S, OWL16U, OWL16D)
;  from: GAMES\MULTSOK2\SCENE.INC DRAWBIRD 2935-2958 (proven there)
; ----------------------------------------------------------------------
OWLDRAW:cmp  byte [ow_st],0
        je   .r
        push ax
        push bx
        push dx
        push si
        mov  si,OWL16S          ; sitting
        cmp  byte [ow_st],2
        je   .k
        mov  si,OWL16U          ; wings up...
        test word [now],2
        jz   .k
        mov  si,OWL16D          ; ...wings down, every 2 ticks
.k:     mov  bx,[ow_x]
        mov  dx,[ow_y]
        call DRAWTXT
        pop  si
        pop  dx
        pop  bx
        pop  ax
.r:     ret

ow_st   db 0                    ; 0 none, 1 in, 2 sitting, 3 off
ow_x    dw 0                    ; where it is (top left)
ow_y    dw 0
ow_tx   dw 0                    ; where it goes
ow_ty   dw 0
ow_when dw 0                    ; the tick of the last OWLTICK
