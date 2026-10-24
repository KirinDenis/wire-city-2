; ============================================================================
;  R_CAMERA.ASM - recipe: the camera of a 2D map, one axis at a time.
;
;  A level that fits the view is centred, and stays still - guide TILES:
;  "the whole level is always on the screen", the first players hated a
;  view that scrolled. A bigger one (a close-up, a long scroller) follows
;  the player, who walks the middle half of the view freely before it
;  moves (the dead zone), and the map's edges never come inside the view.
;
;        mov  ax,[mapw]          ; the map's width in pixels
;        mov  bx,[manx]          ; the player's middle, in map pixels
;        mov  cx,320             ; the view's width
;        mov  dx,[camx]          ; where map pixel 0 lands on the screen now
;        mov  si,[camnew]        ; 1: a new level or view - centre him at once
;        call CAMAXIS
;        mov  [camx],dx          ; screen x = map x + camx
;        ...the same for y with the playfield's height...
;        mov  word [camnew],0
;
;  copy: CAMAXIS.   define before: -   calls: -   needs: -
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:2316-2433 (CAMERA: its x half and y
;        half are the same rule; here once, for any axis, with the band a
;        quarter of the view each side, as MULTSOK2's x)
; ============================================================================

; ----------------------------------------------------------------------
;@ CAMAXIS    one axis of a 2D camera: centre a map that fits, else follow
;  in:  AX = the map's size (pixels), BX = the player's place on the map,
;       CX = the view's size, DX = the offset now (screen = map + offset),
;       SI = 1 to put the player in the middle at once (a new level), 0 not
;  out: DX = the new offset (even: a whole byte at 2 pixels a byte)
; ----------------------------------------------------------------------
CAMAXIS:push ax
        push bx
        push cx
        push di
        mov  [camw],ax          ; the map's size, for the clamp
        cmp  ax,cx
        ja   .fol               ; bigger than the view: follow him
        mov  dx,cx
        sub  dx,ax              ; the room left over...
        sar  dx,1               ; ...half of it either side
        jmp  .set
.fol:   or   si,si
        jz   .keep
        mov  dx,cx
        sar  dx,1               ; the view's middle...
        sub  dx,bx              ; ...minus his place: he lands in the middle
.keep:  mov  di,dx
        add  di,bx              ; DI = his place on the screen
        mov  ax,cx
        sar  ax,1
        sar  ax,1               ; AX = a quarter of the view: the band
        cmp  di,ax
        jge  .lo
        add  dx,ax              ; in the first quarter: offset += band - s
        sub  dx,di
.lo:    neg  ax
        add  ax,cx              ; AX = view - band: the last quarter's start
        cmp  di,ax
        jle  .clamp
        sub  dx,di              ; in the last quarter: offset -= s - (view - band)
        add  dx,ax
.clamp: cmp  dx,0
        jle  .c1
        xor  dx,dx              ; the map's first pixel never comes inside
.c1:    mov  ax,cx
        sub  ax,[camw]          ; AX = view - map: the lowest offset
        cmp  dx,ax
        jge  .set
        mov  dx,ax              ; nor its last
.set:   and  dx,0FFFEh          ; even
        pop  di
        pop  cx
        pop  bx
        pop  ax
        ret

camw    dw 0                    ; CAMAXIS: the map's size
