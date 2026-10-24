; ============================================================================
;  R_STARS.ASM - recipe: a starfield on the celestial sphere. Each star is a
;  DIRECTION (azimuth, elevation), placed 7000 units out from the eye every
;  frame, so it turns with the heading, pitches, banks and never comes
;  nearer - the sky of a night flight, not dots stuck to the glass.
;
;        ...each frame, after the sky is filled and before the ground:
;        mov  es,[buffer]
;        call STARS
;
;  The table is made by the assembler (a fixed LCG): STARN stars, azimuth
;  0..255, elevation 2..61 (of 64 = straight up). Every fourth one is
;  bright ([starhi]), the rest [starlo]. Replace STARTAB with your own
;  constellations: dw azimuth, elevation each.
;
;  copy: STARS and STARTAB.
;  define before: STARN (optional, default 48)
;  calls: K_3D (SINQ, R3_POINT, the camera)
;  from: GAMES\OWLFLY3\SRC\SCENE.INC STARS:215-280 (the direction at radius
;        27*256, rotated and projected), through R3_POINT
; ============================================================================

if ~ defined STARN | defined star_dn
STARN   = 48                    ; how many stars
star_dn = 1
end if

starhi  db 15                   ; the bright ones' colour
starlo  db 7                    ; the rest
stari   dw 0                    ; the star being drawn
starrh  dw 0                    ; scratch: its horizontal radius...
stary   dw 0                    ; ...and height
starx   dw 0

;@ STARS      stars on the celestial sphere: they turn, pitch and bank with the camera
; ---- STARS: every star into ES. Keeps every register.
STARS:  push ax
        push bx
        push cx
        push dx
        push si
        push di
        mov  word [stari],0
.st:    mov  si,[stari]
        shl  si,1
        shl  si,1               ; 2 words a star
        mov  ax,[STARTAB+si+2]  ; rh = cos(el)*27  (~7000 across)
        add  ax,64
        call SINQ
        mov  cx,27
        imul cx                 ; AX = cos(el)*256*27 (< 6913: fits)
        mov  [starrh],ax
        mov  si,[stari]
        shl  si,1
        shl  si,1
        mov  ax,[STARTAB+si+2]  ; y = sin(el)*27
        call SINQ
        mov  cx,27
        imul cx                 ; AX = sin(el)*256*27
        mov  [stary],ax
        mov  si,[stari]
        shl  si,1
        shl  si,1
        mov  ax,[STARTAB+si]    ; x = sin(az)*rh/256
        call SINQ
        imul word [starrh]      ; DX:AX = sin*rh
        mov  bx,256
        idiv bx                 ; AX = sin*rh/256 (|q| <= rh)
        mov  [starx],ax
        mov  si,[stari]
        shl  si,1
        shl  si,1
        mov  ax,[STARTAB+si]    ; z = cos(az)*rh/256
        add  ax,64
        call SINQ
        imul word [starrh]      ; DX:AX = cos*rh
        mov  bx,256
        idiv bx                 ; AX = cos*rh/256
        mov  cx,ax
        add  cx,[r3_camz]       ; out from the eye, wherever it is
        mov  ax,[starx]
        add  ax,[r3_camx]
        mov  bx,[stary]
        add  bx,[r3_camy]
        call R3_POINT
        jc   .sn                ; behind, or off the glass
        mov  di,bx
        mov  cl,8
        shl  di,cl              ; y*256
        mov  cl,6
        shl  bx,cl              ; y*64
        add  di,bx
        add  di,ax              ; + x
        mov  al,[starlo]
        test byte [stari],3
        jnz  .c
        mov  al,[starhi]        ; every fourth: bright
.c:     mov  [es:di],al
.sn:    inc  word [stari]
        cmp  word [stari],STARN
        jb   .st
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; the sky: azimuth, elevation - made at assembly time by a fixed LCG
STARTAB:
star_s = 4321
repeat STARN
  star_s = (star_s*25173 + 13849) and 0FFFFh
        dw (star_s shr 8) and 255           ; azimuth 0..255
  star_s = (star_s*25173 + 13849) and 0FFFFh
        dw 2 + ((star_s shr 8) mod 60)      ; elevation 2..61
end repeat
