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
; F-15 style banded horizon, now ROLL-AWARE: the five bands are drawn as
; rotated parallelograms (SCANPOLY) about (160,horiz), so banking the plane
; banks the sky/ground split with the rest of the scene. Bands overlap by 2
; v-units so integer rounding can't leave unpainted seams.
; F-15 SE style horizon: four sky steps brightening toward a white haze
; line, then the far ground DARK against it, then the normal green. Bands
; overlap by 2 v-units so rounding never leaves seams; pitch (pofs) and
; roll (BGCORN) move the whole stack as one.
CLEARBUF:
        mov  byte ptr [COLOR],7 ; deep upper sky
        mov  word ptr [bgv0],-3000
        mov  word ptr [bgv1],-58
        call BGBAND
        mov  byte ptr [COLOR],26 ; sky step 2
        mov  word ptr [bgv0],-60
        mov  word ptr [bgv1],-32
        call BGBAND
        mov  byte ptr [COLOR],9 ; sky step 3
        mov  word ptr [bgv0],-34
        mov  word ptr [bgv1],-14
        call BGBAND
        mov  byte ptr [COLOR],27 ; sky step 4, brightest blue
        mov  word ptr [bgv0],-16
        mov  word ptr [bgv1],-4
        call BGBAND
        mov  byte ptr [COLOR],12 ; white haze on the horizon line
        mov  word ptr [bgv0],-6
        mov  word ptr [bgv1],2
        call BGBAND
        mov  byte ptr [COLOR],28 ; far ground reads DARK against the haze
        mov  word ptr [bgv0],0
        mov  word ptr [bgv1],16
        call BGBAND
        mov  byte ptr [COLOR],10 ; normal ground
        mov  word ptr [bgv0],14
        mov  word ptr [bgv1],3000
        call BGBAND
        ret

; one background band: a parallelogram spanning u=-600..600 along the horizon
; direction, v=[bgv0..bgv1] across it, rotated by roll about (160,horiz).
BGBAND: mov  word ptr [NPOLY],4
        mov  ax,[pofs]          ; pitch slides the whole band stack
        add  [bgv0],ax
        add  [bgv1],ax
        mov  ax,-600
        mov  bx,[bgv0]
        xor  si,si
        call BGCORN
        mov  ax,600
        mov  bx,[bgv0]
        mov  si,2
        call BGCORN
        mov  ax,600
        mov  bx,[bgv1]
        mov  si,4
        call BGCORN
        mov  ax,-600
        mov  bx,[bgv1]
        mov  si,6
        call BGCORN
        call SCANPOLY
        ret

; corner: PX[si] = 160 + (u*rcos - v*rsin)/256 ; PY[si] = horiz + (u*rsin + v*rcos)/256
BGCORN: mov  [bgu],ax
        mov  [bgv],bx
        mov  ax,[bgu]
        imul word ptr [rcos]
        mov  cx,256
        idiv cx
        mov  bx,ax
        mov  ax,[bgv]
        imul word ptr [rsin]
        mov  cx,256
        idiv cx
        sub  bx,ax
        add  bx,160
        mov  [PX+si],bx
        mov  ax,[bgu]
        imul word ptr [rsin]
        mov  cx,256
        idiv cx
        mov  bx,ax
        mov  ax,[bgv]
        imul word ptr [rcos]
        mov  cx,256
        idiv cx
        add  bx,ax
        add  bx,[horiz]
        mov  [PY+si],bx
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
