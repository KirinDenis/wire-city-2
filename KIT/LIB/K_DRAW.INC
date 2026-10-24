; ============================================================================
;  K_DRAW.INC - KIT: 2D drawing in mode 13h, one byte a pixel.
;
;  Every routine draws into the segment in ES, 320 bytes a row, and CLIPS
;  to the window [drw_cx0..drw_cx1] x [drw_cy0..drw_cy1] (inclusive; the
;  whole screen 0..319 x 0..199 unless DRW_CLIP narrowed it). Coordinates
;  are SIGNED words: a shape half off the screen is simply cut. Keep them
;  inside -16000..16000 (the line clipper multiplies two of them).
;
;  The colour is a variable, set once and kept:
;        mov  byte [drw_col],14          ; yellow
;        mov  ax,10                      ; x
;        mov  bx,20                      ; y
;        mov  cx,100                     ; width
;        mov  dx,50                      ; height
;        call DRW_RECT
;  DRW_DITHER and DRW_GRADV also read [drw_col2] (the second shade) and
;  DRW_DITHER [drw_frac] (how much of it, 0..255).
;  Nothing here needs a palette: the colours are whatever the DAC holds.
; ============================================================================

; ---- the shared state: the colour, the second shade, the clip window -------
if used drw_col
drw_col  db 15                  ; the ink every DRW_ routine draws with
end if
if used drw_col2
drw_col2 db 0                   ; DITHER / GRADV: the second shade
end if
if used drw_frac
drw_frac db 128                 ; DITHER: how much of drw_col2, 0..255
end if
if used drw_cx0
drw_cx0  dw 0                   ; the clip window, inclusive:
drw_cy0  dw 0                   ;  the whole screen unless DRW_CLIP says
drw_cx1  dw 319                 ;  otherwise
drw_cy1  dw 199
end if

; ----------------------------------------------------------------------
;@ DRW_ADDR   DI = the offset of pixel (AX,BX): y*320 + x, no clipping
;  in:  AX = x, BX = y (on the screen)
;  out: DI = BX*320 + AX
;  needs: -
;  from: ENGINE\E_RAST.INC PUTPIXEL (y*256 + y*64, no MUL)
; ----------------------------------------------------------------------
if used DRW_ADDR
DRW_ADDR:
        push bx
        push cx
        mov  di,bx              ; DI = y
        mov  cl,8               ; CL = 8
        shl  di,cl              ; DI = y * 256
        mov  cl,6               ; CL = 6
        shl  bx,cl              ; BX = y * 64
        add  di,bx              ; DI = y * 320
        add  di,ax              ; DI = y * 320 + x
        pop  cx
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ DRW_CLIP   set the clip window every DRW_ routine cuts to (inclusive)
;  in:  AX = left x, BX = top y, CX = right x, DX = bottom y
;  out: - (the window is clamped to the screen)
;  needs: DRW_NOCLIP gives the whole screen back
;  from: new (E_RAST's clipx0..clipy1 idea, OWL FLY III BOND)
; ----------------------------------------------------------------------
if used DRW_CLIP
DRW_CLIP:
        push ax
        push bx
        push cx
        push dx
        cmp  ax,0               ; left below 0?
        jge  .a
        xor  ax,ax              ;   clamp
.a:     cmp  bx,0               ; top below 0?
        jge  .b
        xor  bx,bx
.b:     cmp  cx,319             ; right past 319?
        jle  .c
        mov  cx,319
.c:     cmp  dx,199             ; bottom past 199?
        jle  .d
        mov  dx,199
.d:     mov  [drw_cx0],ax
        mov  [drw_cy0],bx
        mov  [drw_cx1],cx
        mov  [drw_cy1],dx
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ DRW_NOCLIP clip to the whole screen again (0..319 x 0..199)
;  in:  -
;  out: -
;  needs: -
;  from: new
; ----------------------------------------------------------------------
if used DRW_NOCLIP
DRW_NOCLIP:
        mov  word [drw_cx0],0
        mov  word [drw_cy0],0
        mov  word [drw_cx1],319
        mov  word [drw_cy1],199
        ret
end if

; ----------------------------------------------------------------------
;@ DRW_PIXEL  one pixel in [drw_col], if it is inside the clip window
;  in:  AX = x, BX = y, [drw_col]
;  out: -
;  needs: -
;  from: LESSONS\L06\CIRCLE.ASM Px (the clip test), E_RAST PUTPIXEL
; ----------------------------------------------------------------------
if used DRW_PIXEL
DRW_PIXEL:
        cmp  ax,[drw_cx0]       ; left of the window?
        jl   .r
        cmp  ax,[drw_cx1]       ; right of it?
        jg   .r
        cmp  bx,[drw_cy0]       ; above?
        jl   .r
        cmp  bx,[drw_cy1]       ; below?
        jg   .r
        push dx
        push di
        call DRW_ADDR           ; DI = y*320 + x
        mov  dl,[drw_col]
        mov  [es:di],dl         ; the pixel
        pop  di
        pop  dx
.r:     ret
end if

; ----------------------------------------------------------------------
;@ DRW_HLINE  horizontal line of CX pixels from (AX,BX) to the right, clipped
;  in:  AX = x, BX = y, CX = length (0 or less draws nothing), [drw_col]
;  out: -
;  needs: -
;  from: LESSONS\L07\DRAW7.INC:107-115 HLine (+ the clip)
; ----------------------------------------------------------------------
if used DRW_HLINE
DRW_HLINE:
        push ax
        push cx
        push dx
        push di
        cmp  cx,0               ; nothing to draw?
        jle  .r
        cmp  bx,[drw_cy0]       ; the row above the window?
        jl   .r
        cmp  bx,[drw_cy1]       ; below it?
        jg   .r
        mov  dx,ax              ; DX = x
        add  dx,cx              ; DX = x + length
        dec  dx                 ; DX = the right end, inclusive
        cmp  ax,[drw_cx0]       ; left end off the window?
        jge  .l
        mov  ax,[drw_cx0]       ;   cut it
.l:     cmp  dx,[drw_cx1]       ; right end off?
        jle  .w
        mov  dx,[drw_cx1]       ;   cut it
.w:     mov  cx,dx              ; CX = right
        sub  cx,ax              ; CX = right - left
        jl   .r                 ; nothing left of it
        inc  cx                 ; CX = the pixels
        call DRW_ADDR           ; DI = y*320 + left
        mov  al,[drw_col]
        cld
        rep  stosb              ; one instruction, the whole line
.r:     pop  di
        pop  dx
        pop  cx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ DRW_VLINE  vertical line of CX pixels from (AX,BX) downwards, clipped
;  in:  AX = x, BX = y, CX = length (0 or less draws nothing), [drw_col]
;  out: -
;  needs: -
;  from: LESSONS\L07\DRAW7.INC:121-130 VLine (+ the clip)
; ----------------------------------------------------------------------
if used DRW_VLINE
DRW_VLINE:
        push ax
        push bx
        push cx
        push dx
        push di
        cmp  cx,0               ; nothing to draw?
        jle  .r
        cmp  ax,[drw_cx0]       ; the column left of the window?
        jl   .r
        cmp  ax,[drw_cx1]       ; right of it?
        jg   .r
        mov  dx,bx              ; DX = y
        add  dx,cx              ; DX = y + length
        dec  dx                 ; DX = the bottom end, inclusive
        cmp  bx,[drw_cy0]       ; top off the window?
        jge  .t
        mov  bx,[drw_cy0]       ;   cut it
.t:     cmp  dx,[drw_cy1]       ; bottom off?
        jle  .h
        mov  dx,[drw_cy1]       ;   cut it
.h:     mov  cx,dx              ; CX = bottom
        sub  cx,bx              ; CX = bottom - top
        jl   .r                 ; nothing left of it
        inc  cx                 ; CX = the pixels
        call DRW_ADDR           ; DI = top*320 + x
        mov  al,[drw_col]
.d:     mov  [es:di],al         ; the pixel
        add  di,320             ; DI += 320: the one below
        loop .d
.r:     pop  di
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ---- DRW_CUTBOX (inside the kit): clip box AX,BX,CX,DX (x,y,w,h) to the
;  window. Out: AX = left, BX = top, CX = width, DX = rows, [drw_skip] =
;  the rows cut off the top; CF = 1 when nothing is left. SI kept.
if used DRW_CUTBOX
DRW_CUTBOX:
        cmp  cx,0               ; no width?
        jle  .no
        cmp  dx,0               ; no height?
        jle  .no
        add  cx,ax              ; CX = x + w
        dec  cx                 ; CX = the right end, inclusive
        add  dx,bx              ; DX = y + h
        dec  dx                 ; DX = the bottom end, inclusive
        cmp  ax,[drw_cx0]       ; left off?
        jge  .l
        mov  ax,[drw_cx0]
.l:     cmp  cx,[drw_cx1]       ; right off?
        jle  .r
        mov  cx,[drw_cx1]
.r:     mov  word [drw_skip],0  ; no rows cut off the top yet
        cmp  bx,[drw_cy0]       ; top off?
        jge  .t
        push ax
        mov  ax,[drw_cy0]       ; AX = the window's top
        sub  ax,bx              ; AX = the rows above it
        mov  [drw_skip],ax      ; remember them (GRADV needs them)
        pop  ax
        mov  bx,[drw_cy0]
.t:     cmp  dx,[drw_cy1]       ; bottom off?
        jle  .b
        mov  dx,[drw_cy1]
.b:     sub  cx,ax              ; CX = right - left
        jl   .no
        inc  cx                 ; CX = the width left
        sub  dx,bx              ; DX = bottom - top
        jl   .no
        inc  dx                 ; DX = the rows left
        clc
        ret
.no:    stc
        ret
drw_skip dw 0
end if

; ----------------------------------------------------------------------
;@ DRW_RECT   filled rectangle, clipped
;  in:  AX = x, BX = y, CX = width, DX = height, [drw_col]
;  out: -
;  needs: -
;  from: LESSONS\L07\DRAW7.INC:135-140 Box (+ the clip)
; ----------------------------------------------------------------------
if used DRW_RECT
DRW_RECT:
        push ax
        push bx
        push cx
        push dx
        push di
        call DRW_CUTBOX         ; AX,BX = top left, CX = width, DX = rows
        jc   .r                 ; nothing on the screen
        call DRW_ADDR           ; DI = the top-left corner
        mov  al,[drw_col]
        cld
.row:   push cx
        push di
        rep  stosb              ; one row
        pop  di
        pop  cx
        add  di,320             ; DI += 320: the next row
        dec  dx                 ; rows--
        jnz  .row
.r:     pop  di
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ DRW_FRAME  rectangle outline, one pixel wide, clipped
;  in:  AX = x, BX = y, CX = width, DX = height, [drw_col]
;  out: -
;  needs: -
;  from: LESSONS\L07\DRAW7.INC:142-172 Frame
; ----------------------------------------------------------------------
if used DRW_FRAME
DRW_FRAME:
        cmp  cx,0               ; no width?
        jle  .r
        cmp  dx,0               ; no height?
        jle  .r
        push ax
        push bx
        push cx
        call DRW_HLINE          ; the top
        push bx
        add  bx,dx              ; BX = y + h
        dec  bx                 ; BX = the bottom row
        call DRW_HLINE          ; the bottom
        pop  bx
        mov  cx,dx              ; CX = the height
        call DRW_VLINE          ; the left
        pop  cx
        push cx
        add  ax,cx              ; AX = x + w
        dec  ax                 ; AX = the right column
        mov  cx,dx              ; CX = the height
        call DRW_VLINE          ; the right
        pop  cx
        pop  bx
        pop  ax
.r:     ret
end if

; ----------------------------------------------------------------------
;@ DRW_LINE   line (AX,BX)-(CX,DX), Cohen-Sutherland clipped, Bresenham
;  in:  AX = x0, BX = y0, CX = x1, DX = y1 (-16000..16000), [drw_col]
;  out: -
;  needs: -
;  from: ENGINE\E_RAST.INC OUTCODE/CLIPLINE 367-545 (the clip, its window
;        form) + LINEC 682-736 (Bresenham, here stepping the offset by
;        +-1 and +-320 instead of a multiply a pixel); names prefixed: the
;        engine's oc0/nx/ny/lx... clash with programs
; ----------------------------------------------------------------------
if used DRW_LINE
DRW_LINE:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        mov  [drw_lx0],ax       ; the ends into the clipper's variables
        mov  [drw_ly0],bx
        mov  [drw_lx1],cx
        mov  [drw_ly1],dx
        call DRW_CLIPLN         ; cut to the window
        jc   .done              ; nothing of it is inside
        mov  ax,[drw_lx0]
        mov  bx,[drw_ly0]
        call DRW_ADDR           ; DI = the first pixel
        mov  cx,[drw_lx1]
        sub  cx,[drw_lx0]       ; CX = x1 - x0
        mov  si,1               ; SI = a step right
        jns  .p1
        neg  cx                 ; CX = |dx|
        mov  si,-1              ; SI = a step left
.p1:    mov  dx,[drw_ly1]
        sub  dx,[drw_ly0]       ; DX = y1 - y0
        mov  bp,320             ; BP = a step down
        jns  .p2
        neg  dx                 ; DX = |dy|
        mov  bp,-320            ; BP = a step up
.p2:    cmp  cx,dx              ; which way is longer?
        jae  .maj               ;   across: as it is
        xchg cx,dx              ; down: CX = |dy| the long one, DX = |dx|
        xchg si,bp              ;  SI = the long step, BP = the short
.maj:   mov  [drw_lmaj],cx      ; the long distance
        mov  bx,cx              ; BX = the error...
        shr  bx,1               ; ...starts at half the long distance
        inc  cx                 ; CX = the pixels: long distance + 1
        mov  al,[drw_col]
.px:    mov  [es:di],al         ; the pixel
        add  di,si              ; one step along the long axis
        sub  bx,dx              ; error -= the short distance
        jns  .nx                ; still >= 0: no step across
        add  bx,[drw_lmaj]      ; error += the long distance
        add  di,bp              ; and one step along the short axis
.nx:    loop .px
.done:  pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; DRW_LCODE - AX = x, BX = y -> AL = the out-code (1 left 2 right 4 below 8 above)
DRW_LCODE:
        push cx
        xor  cl,cl
        cmp  ax,[drw_cx0]
        jge  .c1
        or   cl,1
        jmp  .c2
.c1:    cmp  ax,[drw_cx1]
        jle  .c2
        or   cl,2
.c2:    cmp  bx,[drw_cy0]
        jge  .c3
        or   cl,8
        jmp  .c4
.c3:    cmp  bx,[drw_cy1]
        jle  .c4
        or   cl,4
.c4:    mov  al,cl
        pop  cx
        ret

; DRW_CLIPLN - cut drw_lx0..drw_ly1 to the window; CF = 1 all outside.
; The divisions are safe: an edge is crossed only by an end that is
; outside it while the other is not, so the divisor (the line's extent
; across that edge) is never 0, and the quotient is never more than the
; other extent.
DRW_CLIPLN:
        mov  ax,[drw_lx0]
        mov  bx,[drw_ly0]
        call DRW_LCODE
        mov  [drw_oc0],al
        mov  ax,[drw_lx1]
        mov  bx,[drw_ly1]
        call DRW_LCODE
        mov  [drw_oc1],al
.iter:  mov  al,[drw_oc0]
        or   al,[drw_oc1]
        jnz  .nacc
        clc                     ; both inside: accept
        ret
.nacc:  mov  al,[drw_oc0]
        and  al,[drw_oc1]
        jz   .clip
        stc                     ; both beyond the same edge: reject
        ret
.clip:  mov  al,[drw_oc0]
        test al,al
        jnz  .use0
        mov  al,[drw_oc1]       ; the end that is outside
.use0:  mov  [drw_ocs],al
        mov  ax,[drw_lx1]
        sub  ax,[drw_lx0]       ; cdx = x1 - x0
        mov  [drw_cdx],ax
        mov  ax,[drw_ly1]
        sub  ax,[drw_ly0]       ; cdy = y1 - y0
        mov  [drw_cdy],ax
        mov  al,[drw_ocs]
        test al,8
        jnz  .top
        test al,4
        jnz  .bot
        test al,2
        jnz  .right
        mov  ax,[drw_cx0]       ; LEFT: x = cx0
        sub  ax,[drw_lx0]       ; AX = cx0 - x0
        imul word [drw_cdy]     ; DX:AX = (cx0 - x0) * cdy
        idiv word [drw_cdx]     ; AX = that / cdx
        add  ax,[drw_ly0]       ; AX = y0 + ...: the y where it crosses
        mov  [drw_ny],ax
        mov  ax,[drw_cx0]
        mov  [drw_nx],ax
        jmp  .apply
.right: mov  ax,[drw_cx1]       ; RIGHT: x = cx1
        sub  ax,[drw_lx0]       ; AX = cx1 - x0
        imul word [drw_cdy]     ; DX:AX = (cx1 - x0) * cdy
        idiv word [drw_cdx]     ; AX = that / cdx
        add  ax,[drw_ly0]       ; AX = the y where it crosses
        mov  [drw_ny],ax
        mov  ax,[drw_cx1]
        mov  [drw_nx],ax
        jmp  .apply
.top:   mov  ax,[drw_cy0]       ; TOP: y = cy0
        sub  ax,[drw_ly0]       ; AX = cy0 - y0
        imul word [drw_cdx]     ; DX:AX = (cy0 - y0) * cdx
        idiv word [drw_cdy]     ; AX = that / cdy
        add  ax,[drw_lx0]       ; AX = the x where it crosses
        mov  [drw_nx],ax
        mov  ax,[drw_cy0]
        mov  [drw_ny],ax
        jmp  .apply
.bot:   mov  ax,[drw_cy1]       ; BOTTOM: y = cy1
        sub  ax,[drw_ly0]       ; AX = cy1 - y0
        imul word [drw_cdx]     ; DX:AX = (cy1 - y0) * cdx
        idiv word [drw_cdy]     ; AX = that / cdy
        add  ax,[drw_lx0]       ; AX = the x where it crosses
        mov  [drw_nx],ax
        mov  ax,[drw_cy1]
        mov  [drw_ny],ax
.apply: mov  al,[drw_oc0]
        test al,al
        jz   .setp1
        mov  ax,[drw_nx]        ; the first end moves to the crossing
        mov  [drw_lx0],ax
        mov  bx,[drw_ny]
        mov  [drw_ly0],bx
        call DRW_LCODE
        mov  [drw_oc0],al
        jmp  .iter
.setp1: mov  ax,[drw_nx]        ; the second end moves to the crossing
        mov  [drw_lx1],ax
        mov  bx,[drw_ny]
        mov  [drw_ly1],bx
        call DRW_LCODE
        mov  [drw_oc1],al
        jmp  .iter

drw_lx0  dw 0
drw_ly0  dw 0
drw_lx1  dw 0
drw_ly1  dw 0
drw_cdx  dw 0
drw_cdy  dw 0
drw_nx   dw 0
drw_ny   dw 0
drw_lmaj dw 0
drw_oc0  db 0
drw_oc1  db 0
drw_ocs  db 0
end if

; ---- the round shapes share the midpoint walk ------------------------------
;  x starts at 0 and y at the radius; a decision variable says which of the
;  two candidate pixels is nearer the true circle; every step is an add. A
;  mode-13h pixel is a fifth taller than it is wide, so every DOWN distance
;  is squashed by 213/256 - that is what makes it LOOK round.
;  DRW_CIRSTEP: one step of the walk; DRW_CIRSQ: AX = AX * 213 / 256.
if used DRW_CIRSTEP
DRW_CIRSTEP:
        mov  ax,[drw_dv]        ; AX = d
        cmp  ax,0               ; d < 0 ?
        jge  .out
        mov  ax,[drw_ox]        ; d += 4x + 6
        add  ax,ax              ; AX = 2x
        add  ax,ax              ; AX = 4x
        add  ax,6               ; AX = 4x + 6
        add  [drw_dv],ax        ; d += AX
        jmp  .on
.out:   mov  ax,[drw_ox]        ; d += 4(x - y) + 10, y--
        sub  ax,[drw_oy]        ; AX = x - y
        add  ax,ax              ; AX = 2(x - y)
        add  ax,ax              ; AX = 4(x - y)
        add  ax,10              ; AX = 4(x - y) + 10
        add  [drw_dv],ax        ; d += AX
        dec  word [drw_oy]      ; y--
.on:    inc  word [drw_ox]      ; x++
        ret
; start the walk for radius CX
DRW_CIRBEG:
        mov  word [drw_ox],0    ; x = 0
        mov  [drw_oy],cx        ; y = r
        mov  ax,cx              ; AX = r
        add  ax,ax              ; AX = 2r
        neg  ax                 ; AX = -2r
        add  ax,3               ; AX = 3 - 2r
        mov  [drw_dv],ax        ; d = 3 - 2r
        ret
; AX = AX * 213 / 256 (AX >= 0): the squash, overflow-free through DX
DRW_CIRSQ:
        push dx
        push bx
        mov  bx,213             ; BX = 213
        mul  bx                 ; DX:AX = d * 213
        mov  al,ah              ; AX = (DX:AX) >> 8: AL = the middle byte...
        mov  ah,dl              ; ...AH = the high byte
        pop  bx
        pop  dx
        ret
drw_ox   dw 0
drw_oy   dw 0
drw_dv   dw 0
drw_ccx  dw 0
drw_ccy  dw 0
drw_qx   dw 0
drw_qy   dw 0
end if

; ----------------------------------------------------------------------
;@ DRW_CIRCLE round ring (aspect-corrected midpoint), centre AX,BX radius CX
;  in:  AX = centre x, BX = centre y, CX = radius across (0..16000), [drw_col]
;  out: - (the height is radius*213/256: it looks round on a 4:3 screen)
;  needs: -
;  from: LESSONS\L06\CIRCLE.ASM Ring/P8/Sq (constants made parameters, the
;        squash widened to 32 bits, each pixel clipped by DRW_PIXEL)
; ----------------------------------------------------------------------
if used DRW_CIRCLE
DRW_CIRCLE:
        cmp  cx,0               ; a negative radius: nothing
        jl   .r
        push ax
        push bx
        push cx
        push dx
        mov  [drw_ccx],ax       ; the centre
        mov  [drw_ccy],bx
        call DRW_CIRBEG
.l:     mov  ax,[drw_ox]
        cmp  ax,[drw_oy]        ; x > y: the eighth is done
        jg   .done
        call DRW_CIRSQ          ; AX = sq(x)
        mov  [drw_qx],ax
        mov  ax,[drw_oy]
        call DRW_CIRSQ          ; AX = sq(y)
        mov  [drw_qy],ax
        mov  cx,[drw_ox]        ; across ox, down qy - and the other seven
        mov  dx,[drw_qy]
        call .p4
        mov  cx,[drw_oy]        ; across oy, down qx: the axes swapped
        mov  dx,[drw_qx]
        call .p4
        call DRW_CIRSTEP
        jmp  .l
.done:  pop  dx
        pop  cx
        pop  bx
        pop  ax
.r:     ret
; the four points (+-CX, +-DX) round the centre
.p4:    mov  ax,[drw_ccx]
        add  ax,cx              ; x = cx + across
        mov  bx,[drw_ccy]
        add  bx,dx              ; y = cy + down
        call DRW_PIXEL
        sub  bx,dx
        sub  bx,dx              ; y = cy - down
        call DRW_PIXEL
        sub  ax,cx
        sub  ax,cx              ; x = cx - across
        call DRW_PIXEL
        add  bx,dx
        add  bx,dx              ; y = cy + down
        call DRW_PIXEL
        ret
end if

; ----------------------------------------------------------------------
;@ DRW_DISC   filled round disc (aspect-corrected), centre AX,BX radius CX
;  in:  AX = centre x, BX = centre y, CX = radius across (0..16000), [drw_col]
;  out: -
;  needs: -
;  from: LESSONS\L06\CIRCLE.ASM Disc/Span (spans now clipped both sides -
;        the lesson's Span cut only the left); OWLFLY3 SYM.INC BLDISC's
;        row-by-row clipping idea
; ----------------------------------------------------------------------
if used DRW_DISC
DRW_DISC:
        cmp  cx,0               ; a negative radius: nothing
        jl   .r
        push ax
        push bx
        push cx
        push dx
        mov  [drw_ccx],ax
        mov  [drw_ccy],bx
        call DRW_CIRBEG
.l:     mov  ax,[drw_ox]
        cmp  ax,[drw_oy]        ; x > y: done
        jg   .done
        call DRW_CIRSQ
        mov  [drw_qx],ax        ; qx = sq(x)
        mov  ax,[drw_oy]
        call DRW_CIRSQ
        mov  [drw_qy],ax        ; qy = sq(y)
        mov  cx,[drw_ox]        ; half width ox on rows cy +- qy
        mov  dx,[drw_qy]
        call .s2
        mov  cx,[drw_oy]        ; half width oy on rows cy +- qx
        mov  dx,[drw_qx]
        call .s2
        call DRW_CIRSTEP
        jmp  .l
.done:  pop  dx
        pop  cx
        pop  bx
        pop  ax
.r:     ret
; two spans, half width CX, on rows cy + DX and cy - DX
.s2:    mov  ax,[drw_ccx]
        sub  ax,cx              ; AX = cx - half: the left end
        add  cx,cx              ; CX = 2 * half
        inc  cx                 ; CX = 2 * half + 1 pixels
        mov  bx,[drw_ccy]
        add  bx,dx              ; BX = cy + down
        call DRW_HLINE
        sub  bx,dx
        sub  bx,dx              ; BX = cy - down
        call DRW_HLINE
        ret
end if

; ----------------------------------------------------------------------
;@ DRW_POLY   filled convex polygon from a point list, scanline, clipped
;  in:  SI = the points (dw x,y, x,y, ...), CX = how many (3..), [drw_col]
;  out: - (the bottom row is left out, so polygons sharing an edge never
;        overlap; a polygon that is not convex fills its outline's hull
;        row by row - give it convex ones)
;  needs: -
;  from: ENGINE\E_RAST.INC:191-295 SCANPOLY (reads the list in place, rows
;        cut to the clip window, names prefixed)
; ----------------------------------------------------------------------
if used DRW_POLY
DRW_POLY:
        cmp  cx,3               ; fewer than three points: no area
        jl   .ret
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        mov  [drw_pn],cx        ; n
        mov  [drw_pl],si        ; the list
        mov  ax,cx              ; AX = n
        add  ax,ax              ; AX = 2n
        add  ax,ax              ; AX = 4n: bytes in the list
        add  ax,si              ; AX = past the list
        mov  [drw_pe],ax
        mov  ax,[si+2]          ; min and max y over all points
        mov  [drw_pmin],ax
        mov  [drw_pmax],ax
.mm:    mov  ax,[si+2]
        cmp  ax,[drw_pmin]
        jge  .mm1
        mov  [drw_pmin],ax
.mm1:   cmp  ax,[drw_pmax]
        jle  .mm2
        mov  [drw_pmax],ax
.mm2:   add  si,4               ; the next point
        loop .mm
        mov  ax,[drw_pmin]      ; the rows, cut to the window
        cmp  ax,[drw_cy0]
        jge  .y0
        mov  ax,[drw_cy0]
.y0:    mov  [drw_py],ax
        mov  ax,[drw_pmax]
        cmp  ax,[drw_cy1]
        jle  .y1
        mov  ax,[drw_cy1]
.y1:    mov  [drw_pym],ax
        mov  ax,[drw_py]
        cmp  ax,[drw_pym]
        jg   .done
.yl:    mov  word [drw_pxl],32767
        mov  word [drw_pxr],-32768
        mov  si,[drw_pl]        ; SI = this edge's first point
.el:    mov  di,si
        add  di,4               ; DI = its second point...
        cmp  di,[drw_pe]
        jb   .nw
        mov  di,[drw_pl]        ; ...the first one again after the last
.nw:    mov  ax,[si+2]          ; AX = y of the one end
        mov  bx,[di+2]          ; BX = y of the other
        cmp  ax,bx
        jle  .io
        xchg ax,bx              ; AX = the lower y, BX = the higher
.io:    mov  dx,[drw_py]
        cmp  dx,ax              ; this row above the edge?
        jl   .en
        cmp  dx,bx              ; at or below its far end? (half-open:
        jge  .en                ;  a flat edge is never crossed)
        mov  ax,[di]
        sub  ax,[si]            ; AX = x2 - x1
        mov  bx,[drw_py]
        sub  bx,[si+2]          ; BX = row - y1
        imul bx                 ; DX:AX = (x2 - x1) * (row - y1)
        mov  bx,[di+2]
        sub  bx,[si+2]          ; BX = y2 - y1, never 0 here
        idiv bx                 ; AX = the x offset where the row crosses
        add  ax,[si]            ; AX = x1 + that
        cmp  ax,[drw_pxl]
        jge  .nl
        mov  [drw_pxl],ax       ; the leftmost crossing
.nl:    cmp  ax,[drw_pxr]
        jle  .en
        mov  [drw_pxr],ax       ; the rightmost crossing
.en:    add  si,4               ; the next edge
        cmp  si,[drw_pe]
        jb   .el
        mov  ax,[drw_pxl]
        mov  cx,[drw_pxr]
        cmp  ax,cx
        jg   .ny                ; no crossing on this row
        sub  cx,ax              ; CX = right - left
        inc  cx                 ; CX = the span's pixels
        mov  bx,[drw_py]
        call DRW_HLINE          ; the span (clipped across there)
.ny:    mov  ax,[drw_py]
        inc  ax                 ; the next row
        mov  [drw_py],ax
        cmp  ax,[drw_pym]
        jle  .yl
.done:  pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
.ret:   ret
drw_pn   dw 0
drw_pl   dw 0
drw_pe   dw 0
drw_pmin dw 0
drw_pmax dw 0
drw_py   dw 0
drw_pym  dw 0
drw_pxl  dw 0
drw_pxr  dw 0
end if

; ----------------------------------------------------------------------
;@ DRW_TRI    filled triangle (AX,BX) (CX,DX) (SI,DI), clipped
;  in:  AX,BX = x0,y0; CX,DX = x1,y1; SI,DI = x2,y2; [drw_col]
;  out: -
;  needs: -
;  from: new glue over DRW_POLY (E_RAST SCANPOLY)
; ----------------------------------------------------------------------
if used DRW_TRI
DRW_TRI:
        push cx
        push si
        mov  [drw_t3],ax        ; the three corners into a list
        mov  [drw_t3+2],bx
        mov  [drw_t3+4],cx
        mov  [drw_t3+6],dx
        mov  [drw_t3+8],si
        mov  [drw_t3+10],di
        mov  si,drw_t3
        mov  cx,3
        call DRW_POLY
        pop  si
        pop  cx
        ret
drw_t3   dw 6 dup(0)
end if

; ---- DRW_DROW (inside the kit): CX pixels at ES:DI in the 4-pixel pattern
;  [drw_patt], phased by the screen x (DI and 3 is x and 3: 320 is a
;  multiple of 4). CX = 0 draws nothing. AX, BX kept.
if used DRW_DROW
DRW_DROW:
        jcxz .z                 ; CX = 0 must mean zero, not 65536
        push ax
        push bx
        mov  bx,di
        and  bx,3               ; BX = x and 3
.f:     mov  al,[drw_patt+bx]
        stosb                   ; the pixel
        inc  bx
        and  bx,3               ; the next phase
        loop .f
        pop  bx
        pop  ax
.z:     ret
; DRW_DPAT - bake row BX's pattern: shade AL, or AH where frac DL beats
; the Bayer threshold. AX, BX, DX kept.
DRW_DPAT:
        push bx
        push cx
        push si
        and  bx,3               ; BX = y and 3: the matrix row
        add  bx,bx              ; BX = 2 (y and 3)
        add  bx,bx              ; BX = 4 (y and 3): its offset
        xor  si,si
.m:     mov  cl,al              ; CL = the first shade
        cmp  dl,[drw_bayer+bx]  ; frac above the threshold?
        jbe  .m1
        mov  cl,ah              ;   the second shade
.m1:    mov  [drw_patt+si],cl
        inc  bx
        inc  si
        cmp  si,4
        jb   .m
        pop  si
        pop  cx
        pop  bx
        ret
drw_patt  db 4 dup(0)
drw_bayer db   0,128, 32,160    ; 4x4 ordered matrix, x16
          db 192, 64,224, 96
          db  48,176, 16,144
          db 240,112,208, 80
end if

; ----------------------------------------------------------------------
;@ DRW_DITHER Bayer-dithered box between two shades: a colour between colours
;  in:  AX = x, BX = y, CX = width, DX = height; [drw_col] shade A,
;       [drw_col2] shade B, [drw_frac] how much B (0 = all A, 128 = half,
;       255 = all B)
;  out: -
;  needs: -
;  from: EXAMPLES\SOLO.ASM:1599-1629 MKPATT/DFILL (DFILL's CX=0 guard)
; ----------------------------------------------------------------------
if used DRW_DITHER
DRW_DITHER:
        push ax
        push bx
        push cx
        push dx
        push di
        call DRW_CUTBOX         ; AX,BX = top left, CX = width, DX = rows
        jc   .r
        call DRW_ADDR           ; DI = the top-left corner
        cld
.row:   push ax
        push dx
        mov  al,[drw_col]       ; AL = shade A
        mov  ah,[drw_col2]      ; AH = shade B
        mov  dl,[drw_frac]      ; DL = how much B
        call DRW_DPAT           ; this row's pattern
        pop  dx
        pop  ax
        push cx
        push di
        call DRW_DROW           ; the row
        pop  di
        pop  cx
        add  di,320             ; DI += 320: the next row
        inc  bx                 ; y++
        dec  dx                 ; rows--
        jnz  .row
.r:     pop  di
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ DRW_GRADV  vertical gradient box, [drw_col] at the top to [drw_col2] at the bottom, dithered
;  in:  AX = x, BX = y, CX = width, DX = height; [drw_col] the top colour,
;       [drw_col2] the bottom colour - a run of palette entries between
;       them (a ramp: 16..31 greys, or your own SETPAL ramp)
;  out: -
;  needs: -
;  from: new, over SOLO's dither (EXAMPLES\SOLO.ASM BAKE's sky ramp idea:
;        a whole shade plus a Bayer fraction a row)
; ----------------------------------------------------------------------
if used DRW_GRADV
DRW_GRADV:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        mov  [drw_gh],dx        ; the full height, for the step
        call DRW_CUTBOX         ; AX,BX = top left, CX = width, DX = rows
        jc   .r
        call DRW_ADDR           ; DI = the top-left corner
        push dx
        push cx
        mov  al,[drw_col2]
        sub  al,[drw_col]       ; AL = bottom - top
        mov  byte [drw_gdir],1  ; going up the palette
        jnc  .pos
        neg  al                 ; AL = |bottom - top|
        mov  byte [drw_gdir],-1 ; going down it
.pos:   xor  ah,ah              ; AX = |d|
        mov  cl,8               ; CL = 8
        shl  ax,cl              ; AX = |d| * 256 (at most 65280)
        mov  cx,[drw_gh]
        dec  cx                 ; CX = height - 1: the steps
        jz   .flat              ; one row: no step at all
        xor  dx,dx              ; DX:AX = |d| * 256
        div  cx                 ; AX = the step a row, 8.8 (CX >= 1)
        jmp  .st
.flat:  xor  ax,ax              ; one row: no step
.st:    mov  bp,ax              ; BP = the step
        mul  word [drw_skip]    ; AX = step * rows cut off the top
        mov  si,ax              ; SI = the shade so far, 8.8
        pop  cx
        pop  dx
        cld
.row:   push ax
        push dx
        mov  ax,si
        mov  dl,al              ; DL = the fraction
        mov  al,ah              ; AL = whole steps
        cmp  byte [drw_gdir],1
        jne  .dn
        add  al,[drw_col]       ; AL = top + steps
        mov  ah,al
        inc  ah                 ; AH = the next shade up
        jmp  .sh
.dn:    neg  al
        add  al,[drw_col]       ; AL = top - steps
        mov  ah,al
        dec  ah                 ; AH = the next shade down
.sh:    call DRW_DPAT           ; the row's pattern (BX = the row)
        pop  dx
        pop  ax
        push cx
        push di
        call DRW_DROW           ; the row
        pop  di
        pop  cx
        add  di,320             ; the next row
        add  si,bp              ; the shade moves on a step
        inc  bx                 ; y++
        dec  dx                 ; rows--
        jnz  .row
.r:     pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
drw_gh   dw 0
drw_gdir db 0
end if
