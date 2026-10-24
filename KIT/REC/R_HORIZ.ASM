; ============================================================================
;  R_HORIZ.ASM - recipe: the sky and the ground, split along the REAL
;  horizon - tilted by the roll, moved by the pitch - so a level split never
;  argues with a banked world. The frame's first drawing: it fills every
;  row (no clear needed), one crossing per row and a word fill each side.
;
;        ...after the camera is set this frame (R3_CAMERA / FLIGHT):
;        mov  es,[buffer]
;        call HZPIVOT            ; the horizon's pivot and slope this frame
;        call HZFILL             ; sky [hzsky] above it, ground [hzgnd] below
;
;  The horizon is the line through (hzcol, hzrow) at the roll's angle:
;  a pixel is GROUND when (y-hzrow)*hzcos - (x-hzcol)*hzsin > 0. Per row
;  that is one crossing x = hzcol + (y-hzrow)*hzcos/hzsin; nearly level
;  (|hzsin| < 8) the whole row goes by the sign, which is also what keeps
;  that divide from overflowing (|y-hzrow| is clamped to 500 first, so the
;  quotient stays under 16000). R_LADDER reads the same pivot.
;
;  copy: HZPIVOT HZFILL and their words.
;  define before: -   (set [hzsky] and [hzgnd] to your colours)
;  calls: K_3D's pofs/horiz/rsin/rcos (SETTRIG's, via R3_CAMERA or R3_TRIG)
;  from: GAMES\OWLFLY3B\SRC\VIDEO.INC CLEARBUF:17-33 (the pivot),
;        VID.INC SKYGNDF:910-1040 + SGFILL (the fill, whole screen, no window)
; ============================================================================

hzsky   db 1                    ; the sky's colour
hzgnd   db 2                    ; the ground's
hzrow   dw 100                  ; the pivot: a point of the horizon...
hzcol   dw 160
hzsin   dw 0                    ; ...and the roll's sine and cosine
hzcos   dw 256

;@ HZPIVOT    the horizon's pivot and slope this frame (from the pitch and roll)
; ---- HZPIVOT: the horizon this frame. The pitch shifts it pofs along the
;  roll's own "down": (160 - pofs*rsin/256, horiz + pofs*rcos/256).
HZPIVOT:push ax
        push bx
        push dx
        mov  ax,[rsin]
        mov  [hzsin],ax
        mov  ax,[rcos]
        mov  [hzcos],ax
        mov  bx,256
        imul word [pofs]        ; DX:AX = rcos * pofs
        idiv bx                 ; AX = rcos*pofs/256 (|pofs| <= 2600: fits)
        add  ax,[horiz]
        mov  [hzrow],ax
        mov  ax,[pofs]
        imul word [rsin]        ; DX:AX = pofs * rsin
        idiv bx                 ; / 256
        neg  ax
        add  ax,160
        mov  [hzcol],ax
        pop  dx
        pop  bx
        pop  ax
        ret

;@ HZFILL     sky and ground split along the banked horizon (the frame's clear)
; ---- HZFILL: all 200 rows of ES, sky one side of the horizon, ground the
;  other. Keeps every register.
HZFILL: push ax
        push bx
        push cx
        push dx
        push si
        push di
        cld
        xor  di,di
        xor  si,si              ; SI = the row
.row:   mov  ax,si
        sub  ax,[hzrow]         ; y - hzrow, clamped to +-500
        cmp  ax,500
        jle  .c1
        mov  ax,500
.c1:    cmp  ax,-500
        jge  .c2
        mov  ax,-500
.c2:    imul word [hzcos]       ; DX:AX = (y-hzrow)*cos
        mov  bx,[hzsin]
        mov  cx,bx
        or   cx,cx
        jns  .a
        neg  cx                 ; |sin|
.a:     cmp  cx,8
        jae  .tilt
        mov  bl,[hzsky]         ; nearly level: the sign decides the row
        or   dx,dx
        js   .one
        jnz  .gnd
        or   ax,ax
        jz   .one
.gnd:   mov  bl,[hzgnd]
.one:   mov  al,bl
        mov  ah,bl
        xor  cx,cx              ; one colour: the crossing anywhere will do
        jmp  .fill
.tilt:  idiv bx                 ; the crossing, relative to hzcol (< 16000)
        add  ax,[hzcol]
        mov  cx,ax
        mov  al,[hzgnd]         ; sin > 0: the ground on the left
        mov  ah,[hzsky]
        or   bx,bx
        jns  .fill
        xchg al,ah              ; sin < 0: the sky is
.fill:  cmp  cx,0               ; the crossing, held on the screen
        jge  .f1
        xor  cx,cx
.f1:    cmp  cx,320
        jle  .f2
        mov  cx,320
.f2:    push cx
        call .span              ; left of the crossing...
        pop  cx
        neg  cx
        add  cx,320
        mov  al,ah
        call .span              ; ...and right of it
        inc  si
        cmp  si,200
        jb   .row
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
; .span: CX bytes of AL at ES:DI, by words; AX kept
.span:  push ax
        mov  ah,al
        shr  cx,1
        rep  stosw
        jnc  .s1
        stosb
.s1:    pop  ax
        ret
