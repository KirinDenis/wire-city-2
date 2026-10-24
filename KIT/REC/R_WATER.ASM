; R_WATER.ASM - water that moves by the beat, glints and a shimmer (mode 13h)
; ============================================================================
;  Recipe: copy after your program's way out (or include it there).
;  WATERCELL - a moat cell: one of KIT\ART\WATER.TXT's frames, each cell at
;    its own phase, a frame every two beats; once a minute a band 48 px
;    wide - a breath of wind - drifts across, the swells brighter under it.
;    Make a list of your water cells (x, y, phase) when you draw the
;    background, and call WATERCELL for each every frame (it is SOLID: it
;    covers the cell; draw banks over it after).
;  GLINT - a candy's (or anything's) spot of light: dark most of the time,
;    then for 8 ticks a spot on a ring round it - blue, pale, white, pale -
;    each thing on a period of its own, 80..207 ticks, at a new place every
;    time, every fourth time a white star (KIT\ART\SPARKLE.TXT).
;  SHIMMER - a light going round a gem, a place each beat.
;  The original (SCENE.INC) is 4 bits a pixel; this is mode 13h, through
;  the program's PSET and DRAWTXT. Colours: PALETTE.TXT's.
; ============================================================================

; ----------------------------------------------------------------------
;@ WATERCELL  a water cell's frame by the beat and its own phase; the wind
;  in:  BX, DX = the cell's top left (16x16), AL = its phase (a hash)
;  out: -
;  needs: DRAWTXT (SI picture at BX, DX, see-through, clipped, keeps all),
;       [now] [beat] (R_CLOCK.ASM), KIT\ART\WATER.TXT included (WATER16A..D,
;       WATER16W)
;  from: GAMES\MULTSOK2\SCENE.INC FRAMEFL 1497-1535 (proven there)
; ----------------------------------------------------------------------
WATERCELL:
        push ax
        push cx
        push si
        mov  ah,al              ; AH = its phase
        mov  cx,[now]           ; a breath of wind: a band 48 px wide that
        and  cx,1023            ;  drifts across left to right, 18 px a
        sub  cx,96              ;  second, once a minute: its left edge
        mov  si,WATER16W
        push bx
        add  bx,16              ; the cell's right edge
        cmp  bx,cx
        pop  bx
        jle  .calm              ; the band has not reached it
        add  cx,48              ; the band's right edge
        cmp  bx,cx
        jl   .draw              ; under the wind
.calm:  mov  al,[beat]
        shr  al,1               ; a frame every two beats
        add  al,ah              ;  + its own phase
        and  al,3
        xor  ah,ah
        shl  ax,1               ; a word a frame
        mov  si,ax
        mov  si,[WT_FR+si]
.draw:  call DRAWTXT
        pop  si
        pop  cx
        pop  ax
        ret
WT_FR   dw WATER16A,WATER16B,WATER16C,WATER16D

; ----------------------------------------------------------------------
;@ GLINT      a thing's glint: a spot of light on its own period, a star
;  in:  AX = the thing's seed (its cell number), BX, DX = its cell's top
;       left
;  out: -
;  needs: PSET, DRAWTXT, [cell] dw, PERIOD and [now] (R_CLOCK.ASM),
;       KIT\ART\SPARKLE.TXT included (SPARKL16, drawn at 16)
;  from: GAMES\MULTSOK2\SCENE.INC GLINT 1969-2016, SPOT 2035-2056
; ----------------------------------------------------------------------
GLINT:  push ax
        push bx
        push cx
        push dx
        push si
        mov  [wt_x],bx
        mov  [wt_y],dx
        mov  si,ax              ; SI = the seed
        mov  bx,80              ; its period: 80..207 ticks
        mov  cl,127
        call PERIOD             ; AX = which glint, DX = ticks into it
        cmp  dx,8
        jae  .r                 ; dark, most of the time
        test al,3
        jnz  .spot
        cmp  dl,2               ; every fourth glint a star, in its middle
        jb   .spot
        cmp  dl,6
        jae  .spot
        mov  bx,[wt_x]
        mov  dx,[wt_y]
        push si
        mov  si,SPARKL16
        call DRAWTXT
        pop  si
        jmp  .r
.spot:  mov  cl,al
        shl  al,1
        shl  al,1
        add  al,cl              ; which glint * 5
        mov  cx,si
        add  al,cl              ;  + the seed: a new place every time
        cmp  dl,4
        jb   .p
        inc  al                 ; half way through, the light slides on
.p:     and  ax,7
        mov  si,ax
        shl  si,1
        add  si,ax              ; 3 bytes a place
        add  si,WT_RINGC
        mov  bx,dx
        mov  ch,[WT_GLC+bx]     ; how bright, so far into it
        call WT_SPOT
.r:     pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; ----------------------------------------------------------------------
;@ SHIMMER    a spot of light going round a gem, a place each beat
;  in:  AX = the gem's seed (its cell), BX, DX = its cell's top left
;  out: -
;  needs: PSET, [cell] dw, [beat] (R_CLOCK.ASM)
;  from: GAMES\MULTSOK2\SCENE.INC SHIMMER 2018-2033 (ring RINGG)
; ----------------------------------------------------------------------
SHIMMER:push ax
        push bx
        push cx
        push si
        mov  [wt_x],bx
        mov  [wt_y],dx
        mov  bx,ax
        mov  cl,3
        shr  bx,cl
        add  ax,bx              ; a phase from the seed
        add  al,[beat]          ; a place each beat
        and  ax,7
        mov  si,ax
        shl  si,1
        add  si,ax              ; 3 bytes a place
        add  si,WT_RINGG
        mov  ch,[si+2]          ; its colour
        call WT_SPOT
        pop  si
        pop  cx
        pop  bx
        pop  ax
        ret

; WT_SPOT - the spot at ring place SI (x, y in 16ths of a cell) over the
; cell at wt_x, wt_y, colour CH: a pixel, two at 12 and over. keeps all.
WT_SPOT:push ax
        push bx
        push cx
        push dx
        mov  al,[si]            ; x in 16ths
        xor  ah,ah
        mul  word [cell]        ; * cell  (DX goes)
        mov  cl,4
        shr  ax,cl              ; / 16
        add  ax,[wt_x]
        mov  bx,ax
        mov  al,[si+1]          ; y in 16ths
        xor  ah,ah
        mul  word [cell]
        mov  cl,4
        shr  ax,cl
        add  ax,[wt_y]
        mov  dx,ax
        mov  al,ch
        call PSET
        cmp  word [cell],12
        jb   .r
        inc  bx                 ; two pixels at the big sizes
        call PSET
.r:     pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
; the rings (x, y in 16ths, colour): a candy's, close; a gem's, wider.
; White at the top, where the light falls, pale cyan at the sides, blue under
WT_RINGC db 6,8,11, 6,6,11, 8,5,15, 9,6,15, 10,8,11, 9,10,9, 8,10,9, 6,10,9
WT_RINGG db 4,9,11, 5,6,15, 8,4,15, 11,6,15, 12,9,11, 10,12,9, 8,13,9, 6,12,9
WT_GLC   db 9,11,15,15,15,11,11,9      ; a glint fades in and out: no blink
wt_x     dw 0
wt_y     dw 0
