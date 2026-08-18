; VIDEO.INC - part of WIRE CITY (included from OWLFLY3.ASM)
; (SETPAL/APPLYPAL and both palette tables moved to UISEG 2026-07-27
;  as APPLYPALF - once-at-startup DAC data paid the stack guard's
;  rent for the SA pages. See UI.INC.)

; ============================================================================
;  CLEAR BACK-BUFFER  (top = sky, bottom = ground)   ES=bufseg
; ============================================================================
; The NEWTON sky: a five-step blue ramp dithered with blue noise, shaded
; by the PERPENDICULAR distance to the real horizon line, so the haze
; rotates with the world instead of with the screen. The heavy code and
; its tables live in SKY.INC in their own segment; this stub only
; anchors the frame's horizon pivot and picks the dither mode.
; The pivot: the old band stack put the horizon at v = pofs of the roll
; rotation about (160,horiz), so its on-screen anchor point is
; (160 - pofs*rsin/256, horiz + pofs*rcos/256).
CLEARBUF:
        mov  ax,[rsin]
        mov  [sinr],ax
        mov  ax,[rcos]
        mov  [cosr],ax
        imul word [pofs]    ; (AX still holds rcos here)
        mov  bx,256
        idiv bx
        add  ax,[horiz]
        mov  [hcur],ax
        mov  ax,[pofs]
        imul word [rsin]
        mov  bx,256
        idiv bx
        neg  ax
        add  ax,160
        mov  [cx0],ax
        mov  word [pmrow],-9999 ; new frame: the pattern cache is stale
        mov  byte [wdith],0
        cmp  word [sinr],0  ; banked: the grain must turn with the
        je   .lvl              ; world - per-pixel walk, not the tile
        mov  byte [wdith],1
.lvl:  call SKYSEG:SKYFILL
        ret

; ============================================================================
;  COPY BACK-BUFFER -> A000:0000
; ============================================================================
BLIT:   cmp  byte [vcard],6     ; VGA and MCGA: the straight copy below.
        jb   .cnv               ; Anything older converts the frame in
        push ds                 ; VIDSEG - the renderer never knows
        mov  ax,[bufseg]
        mov  ds,ax
        mov  ax,0A000h
        mov  es,ax
        xor  si,si
        xor  di,di
        mov  cx,32000
        rep  movsw
        pop  ds
        ret
.cnv:  call VIDSEG:VBLITF
        ret

; ============================================================================
;  WAIT FOR VERTICAL RETRACE (sync)
; ============================================================================
WAITV:  cmp  byte [vcard],1     ; Hercules has no 3DAh - the floating
        je   .h                  ; port reads FFh and the loop below
        mov  dx,3DAh             ; would spin on it forever
.w1:   in   al,dx
        test al,8
        jnz  .w1
.w2:   in   al,dx
        test al,8
        jz   .w2
.h:    ret                      ; tearing guard only: Hercules goes bare
