; VIDEO.INC - part of WIRE CITY (included from CITY.ASM)
; ============================================================================
;  SET PALETTE
; ============================================================================
SETPAL: mov  dx,3C8h            ; in: SI -> palette table (NPALC colours)
        xor  al,al
        out  dx,al
        mov  dx,3C9h
        mov  cx,NPALC*3
        cld                     ; lodsb must walk forward
@@pl:   lodsb
        out  dx,al
        loop @@pl
        ret

; pick the palette that matches [daymode] and load it
APPLYPAL:
        cmp  byte ptr [daymode],0
        je   @@nit
        mov  si,offset PALDAY
        jmp  @@go
@@nit:  mov  si,offset PALNITE
@@go:   call SETPAL
        ret

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
        imul word ptr [pofs]    ; (AX still holds rcos here)
        mov  bx,256
        idiv bx
        add  ax,[horiz]
        mov  [hcur],ax
        mov  ax,[pofs]
        imul word ptr [rsin]
        mov  bx,256
        idiv bx
        neg  ax
        add  ax,160
        mov  [cx0],ax
        mov  word ptr [pmrow],-9999 ; new frame: the pattern cache is stale
        mov  byte ptr [wdith],0
        cmp  word ptr [sinr],0  ; banked: the grain must turn with the
        je   @@lvl              ; world - per-pixel walk, not the tile
        mov  byte ptr [wdith],1
@@lvl:  call FAR PTR SKYFILL
        ret

; ============================================================================
;  COPY BACK-BUFFER -> A000:0000
; ============================================================================
BLIT:   push ds
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

; ============================================================================
;  WAIT FOR VERTICAL RETRACE (sync)
; ============================================================================
WAITV:  mov  dx,3DAh
@@w1:   in   al,dx
        test al,8
        jnz  @@w1
@@w2:   in   al,dx
        test al,8
        jz   @@w2
        ret
