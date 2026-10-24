; R_LIFE.ASM - the park's life: butterflies, fireflies, ducks, each on its own phase (mode 13h)
; ============================================================================
;  Recipe: copy after your program's way out (or include it there).
;  "The bushes and trees behind the castle - make life more interesting":
;  a pixel or three each, slow, each at its own moments. Butterflies over
;  flowers, beds and blossom (two pixels whose wings open and shut);
;  fireflies by the trees of the wood, out in the dusk, glowing a third of
;  a second on periods of their own (2.6 to 4.3 s); a duck or two drifting
;  on the water. A few of each, never on the floor.
;  When you draw the background, LIFEADD each creature's home (which
;  things get one: KIT\ART\SCATTER.TXT LIFE); every frame, after the
;  background copy, call LIFE once. Clear [lf_n] for a new background.
;  The original (SCENE.INC) draws through a 4bpp PSET; here the program's
;  mode 13h PSET. Colours: PALETTE.TXT's.
; ============================================================================
LF_MAX  = 24                    ; creatures at most (6 bytes each)

; ----------------------------------------------------------------------
;@ LIFEADD    a creature of the park: its kind and home, its own phase
;  in:  CL = its kind (0 butterfly, 1 firefly, 2 duck), BX, DX = its home
;       (a butterfly over a flower's top, a firefly by a tree's middle, a
;       duck on a water cell's middle)
;  out: -  (full: ignored)
;  needs: -
;  from: GAMES\MULTSOK2\SCENE.INC LIFEADD 1216-1236 (proven there)
; ----------------------------------------------------------------------
LIFEADD:push ax
        push cx
        push dx
        push di
        mov  di,[lf_n]
        cmp  di,LF_MAX
        jae  .r                 ; full
        inc  word [lf_n]
        push dx
        mov  ax,6
        mul  di                 ; 6 bytes a creature  (DX goes)
        mov  di,ax
        pop  dx
        mov  word [lf_tab+di],bx
        mov  word [lf_tab+di+2],dx
        mov  ax,dx
        add  ax,dx
        add  ax,dx              ; 3y
        add  ax,bx              ; + x: its own phase
        mov  ch,al
        mov  word [lf_tab+di+4],cx ; kind, phase
.r:     pop  di
        pop  dx
        pop  cx
        pop  ax
        ret

; ----------------------------------------------------------------------
;@ LIFE       every frame: each creature flutters, glows or drifts
;  in:  -
;  out: -
;  needs: PSET (AL colour at BX, DX, clipped, keeps all), [cell] dw (the
;       swing scales with it: 16), [now] (R_CLOCK.ASM)
;  from: GAMES\MULTSOK2\SCENE.INC LIFE 1238-1356 (proven there)
; ----------------------------------------------------------------------
LIFE:   push ax
        push bx
        push cx
        push dx
        push si
        mov  cx,[lf_n]
        jcxz .r
        mov  si,lf_tab
.l:     push cx
        push si
        mov  ax,[si]
        mov  [lf_x],ax
        mov  ax,[si+2]
        mov  [lf_y],ax
        mov  al,[si+5]
        xor  ah,ah
        mov  [lf_ph],ax         ; its phase
        mov  al,[si+4]          ; its kind
        cmp  al,1
        je   .fly
        ja   .duck
        mov  ax,[now]           ; a butterfly
        shr  ax,1
        add  ax,[lf_ph]
        call LF_WX
        add  [lf_x],ax          ; round its flower...
        mov  ax,[now]
        shr  ax,1
        mov  bx,ax
        shr  bx,1
        add  ax,bx              ;  ...up and down half as fast again
        add  ax,[lf_ph]
        add  ax,5
        call LF_WX
        sar  ax,1
        add  [lf_y],ax
        mov  bx,[lf_ph]
        and  bx,3
        mov  al,[LF_BUT+bx]     ; white, yellow, pink, pale blue
        mov  bx,[lf_x]
        mov  dx,[lf_y]
        mov  cx,[now]
        shr  cx,1
        add  cx,[lf_ph]
        test cl,1
        jz   .shut
        dec  bx                 ; wings open
        call PSET
        add  bx,2
        call PSET
        jmp  .n
.shut:  call PSET               ; wings shut, up
        dec  dx
        call PSET
        jmp  .n
.fly:   mov  bx,[lf_ph]         ; a firefly: its own period, 24..39
        and  bx,15              ;  frames
        add  bx,24
        mov  ax,[now]
        shr  ax,1
        add  ax,[lf_ph]
        xor  dx,dx
        div  bx                 ; DX = frames into its period (BX >= 24)
        cmp  dx,6
        jae  .n                 ; dark, most of the time
        mov  [lf_glow],dl
        mov  ax,[now]
        mov  cl,3
        shr  ax,cl              ; drifting slowly
        add  ax,[lf_ph]
        call LF_WX
        add  [lf_x],ax
        mov  ax,[now]
        mov  cl,3
        shr  ax,cl
        add  ax,[lf_ph]
        add  ax,4
        call LF_WX
        add  [lf_y],ax
        mov  al,14              ; its glow, gold...
        cmp  byte [lf_glow],0
        je   .dim
        cmp  byte [lf_glow],5
        jne  .g
.dim:   mov  al,10              ; ...lime as it comes and goes: no blink
.g:     mov  bx,[lf_x]
        mov  dx,[lf_y]
        call PSET
        jmp  .n
.duck:  mov  ax,[now]           ; a duck: a step every 16 ticks
        mov  cl,4
        shr  ax,cl
        add  ax,[lf_ph]
        call LF_WX
        sar  ax,1               ; and not far
        add  [lf_x],ax
        mov  bx,[lf_x]
        mov  dx,[lf_y]
        mov  al,15
        call PSET               ; its white body
        inc  bx
        call PSET
        inc  bx
        dec  dx
        mov  al,2               ; its green head
        call PSET
.n:     pop  si
        pop  cx
        add  si,6
        loop .l
.r:     pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
; LF_WX - AX = LF_SWING[AX AND 15] * cell / 16: a soft swing for the
; cell's size.  clobbers BX, CL, DX.
LF_WX:  and  ax,15
        mov  bx,ax
        mov  al,[LF_SWING+bx]
        cbw
        imul word [cell]        ; swing * cell  (DX goes)
        mov  cl,4
        sar  ax,cl              ; / 16
        ret
LF_SWING db 0,3,5,6,7,6,5,3,0,-3,-5,-6,-7,-6,-5,-3   ; a sine, 16 steps
LF_BUT   db 15,14,13,11
lf_n     dw 0                   ; creatures listed
lf_x     dw 0
lf_y     dw 0
lf_ph    dw 0
lf_glow  db 0
lf_tab   rb LF_MAX*6            ; x, y, kind, phase
