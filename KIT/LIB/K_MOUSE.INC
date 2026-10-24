; ============================================================================
;  K_MOUSE.INC - KIT: the mouse (INT 33h) in mode 13h, a cursor drawn by
;  hand, and the keyboard as a mouse.
;
;        call MOU_INIT           ; CF = 1: no driver - the keys still work
;  .frame:
;        mov  ah,1
;        int  16h                ; a key?
;        jz   .nokey
;        xor  ah,ah
;        int  16h                ; AH = scan code, AL = the character
;        cmp  al,27
;        je   .quit
;        call MOU_KEYS           ; arrows move the pointer, Enter/Space click
;  .nokey:
;        call MOU_READ           ; AX = x 0..319, BX = y, CX = buttons
;        call MOU_CLICK          ; CF = 1: a click since last asked, at AX,BX
;        jnc  .noclick
;        ...hit test AX,BX...
;  .noclick:
;        mov  es,[buf]           ; the back buffer, the scene drawn in it
;        call MOU_CURDRAW        ; the pointer into it, what was under kept
;        ...copy the buffer to the screen...
;        call MOU_CURHIDE        ; the buffer exactly as it was again
;
;  The pointer lives in [mou_x],[mou_y] (screen pixels), whether the mouse
;  or the keys moved it. The driver counts x in 640 columns in mode 13h;
;  every call here halves and doubles it, so a caller never sees that.
;  Give every mouse screen the keyboard path (MOU_KEYS): an emulator in a
;  browser may not have the mouse yet, and a phone has none.
;  Guide topic INPUT (The mouse).
; ============================================================================

if used mou_x
mou_ok    db 0                  ; 1 = a driver answered MOU_INIT
mou_x     dw 160                ; the pointer, screen pixels
mou_y     dw 100
mou_btn   dw 0                  ; buttons at the last MOU_READ: bit 0 left, 1 right
mou_x0    dw 0                  ; the range the pointer stays in (MOU_RANGE)
mou_y0    dw 0
mou_x1    dw 319
mou_y1    dw 199
mou_step  dw 4                  ; MOU_KEYS: pixels an arrow moves the pointer
mou_kclk  db 0                  ; MOU_KEYS: a click latched by Enter/Space
mou_shape dw MOU_ARROW8         ; MOU_CURDRAW's picture (MOU_ARROW8/16, MOU_HAND8/16)
mou_ink   db 15                 ; the pointer's fill (white)
mou_edge  db 0                  ; its outline (black)
mou_on    db 0                  ; 1 = drawn now, its save-under is held
mou_sx    dw 0                  ; where it was drawn, clipped: left, top,
mou_sy    dw 0
mou_sw    dw 0                  ;  width and height of the saved box
mou_sh    dw 0
mou_save  db 16*16 dup(0)       ; what was under it
end if

; ---- MOU_DRV (inside the kit): INT 33h with the registers it clobbers kept.
;  The driver may change registers it was not asked for; this keeps SI DI
;  BP ES DS. Every caller here passes AX BX CX DX and reads them back.
if used MOU_DRV
MOU_DRV:
        push si
        push di
        push bp
        push es
        push ds
        int  33h
        pop  ds
        pop  es
        pop  bp
        pop  di
        pop  si
        ret
end if

; ----------------------------------------------------------------------
;@ MOU_INIT   reset the mouse driver, range the whole 320x200 screen
;  in:  -
;  out: CF = 1 no driver (then [mou_ok] = 0 and only MOU_KEYS moves the
;       pointer); the pointer is put at the screen's middle either way
;  needs: call it after the mode is set (a reset reads the mode)
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM (MOUSEOK, ranges 7/8 at PKLOADED
;        541-820, ported to 8086); INT 33h AX=0 as docs\guide\INPUT.MD
; ----------------------------------------------------------------------
if used MOU_INIT
MOU_INIT:
        push ax
        push bx
        push cx
        push dx
        mov  byte [mou_ok],0
        push es
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:33h*4]      ; the vector's offset
        or   ax,[es:33h*4+2]    ; ... and segment: 0:0 = no driver at all
        pop  es
        jz   .none
        xor  ax,ax
        call MOU_DRV            ; AX = FFFFh if a driver is there
        cmp  ax,0FFFFh
        jne  .none
        mov  byte [mou_ok],1
.none:  xor  ax,ax
        xor  bx,bx
        mov  cx,319
        mov  dx,199
        call MOU_RANGE          ; the whole screen
        mov  ax,160
        mov  bx,100
        call MOU_SET            ; the middle
        cmp  byte [mou_ok],1
        je   .ok
        stc
        jmp  .out
.ok:    clc
.out:   pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ MOU_RANGE  keep the pointer inside x AX..CX, y BX..DX (screen pixels)
;  in:  AX = left x, BX = top y, CX = right x, DX = bottom y (inclusive,
;       0..319 / 0..199; a left above its right is swapped)
;  out: - (the pointer is pulled inside if it was out)
;  needs: -
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM PKLOADED (INT 33h 7/8, x doubled
;        for mode 13h); the keyboard's clamp PKK5-PKK8
; ----------------------------------------------------------------------
if used MOU_RANGE
MOU_RANGE:
        push ax
        push bx
        push cx
        push dx
        cmp  ax,cx
        jle  .xo
        xchg ax,cx              ; left <= right
.xo:    cmp  bx,dx
        jle  .yo
        xchg bx,dx              ; top <= bottom
.yo:    call MOU_CLIPX          ; AX into 0..319
        xchg ax,cx
        call MOU_CLIPX          ; CX too
        xchg ax,cx
        xchg ax,bx
        call MOU_CLIPY          ; BX into 0..199
        xchg ax,bx
        xchg ax,dx
        call MOU_CLIPY          ; DX too
        xchg ax,dx
        mov  [mou_x0],ax
        mov  [mou_y0],bx
        mov  [mou_x1],cx
        mov  [mou_y1],dx
        cmp  byte [mou_ok],1
        jne  .put
        push bx
        push dx
        mov  dx,cx
        shl  dx,1               ; right x in the driver's 640 columns
        inc  dx                 ; ... and its odd half: 2x+1
        mov  cx,ax
        shl  cx,1               ; left x * 2
        mov  ax,7
        call MOU_DRV            ; x range CX..DX
        pop  dx
        pop  cx                 ; CX = top y
        mov  ax,8
        call MOU_DRV            ; y range CX..DX
.put:   mov  ax,[mou_x]
        mov  bx,[mou_y]
        call MOU_SET            ; pulled inside the new range
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ---- MOU_CLIPX / MOU_CLIPY (inside the kit): AX into 0..319 / 0..199.
if used MOU_CLIPX
MOU_CLIPX:
        cmp  ax,0
        jge  .a
        xor  ax,ax
.a:     cmp  ax,319
        jle  .b
        mov  ax,319
.b:     ret
end if
if used MOU_CLIPY
MOU_CLIPY:
        cmp  ax,0
        jge  .a
        xor  ax,ax
.a:     cmp  ax,199
        jle  .b
        mov  ax,199
.b:     ret
end if

; ----------------------------------------------------------------------
;@ MOU_SET    put the pointer at (AX,BX), the driver told too
;  in:  AX = x, BX = y (pulled into the range of MOU_RANGE)
;  out: - ([mou_x],[mou_y])
;  needs: -
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:1449-1466 MOUSESET (else the
;        driver's next reading pulls the pointer straight back)
; ----------------------------------------------------------------------
if used MOU_SET
MOU_SET:
        push ax
        push bx
        push cx
        push dx
        cmp  ax,[mou_x0]
        jge  .a
        mov  ax,[mou_x0]
.a:     cmp  ax,[mou_x1]
        jle  .b
        mov  ax,[mou_x1]
.b:     cmp  bx,[mou_y0]
        jge  .c
        mov  bx,[mou_y0]
.c:     cmp  bx,[mou_y1]
        jle  .d
        mov  bx,[mou_y1]
.d:     mov  [mou_x],ax
        mov  [mou_y],bx
        cmp  byte [mou_ok],1
        jne  .out
        mov  cx,ax
        shl  cx,1               ; x in the driver's 640 columns
        mov  dx,bx
        mov  ax,4
        call MOU_DRV            ; the driver's pointer to CX,DX
.out:   pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ MOU_READ   where the pointer is and which buttons are down now
;  in:  -
;  out: AX = x 0..319, BX = y 0..199, CX = buttons (bit 0 left, bit 1
;       right; 0 with no driver); [mou_x] [mou_y] [mou_btn] the same
;  needs: MOU_INIT first (with no driver it answers what MOU_KEYS set)
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM PKMOUSE (INT 33h AX=3, x halved
;        for mode 13h), ported to 8086
; ----------------------------------------------------------------------
if used MOU_READ
MOU_READ:
        push dx
        cmp  byte [mou_ok],1
        jne  .keys
        mov  ax,3
        call MOU_DRV            ; BX = buttons, CX = x (640), DX = y
        shr  cx,1               ; x in screen pixels
        and  bx,3               ; left and right only
        mov  [mou_btn],bx
        mov  ax,cx
        cmp  ax,[mou_x0]        ; the driver's range is ours, but a
        jge  .a                 ; driver reset elsewhere is not:
        mov  ax,[mou_x0]        ; clamp anyway
.a:     cmp  ax,[mou_x1]
        jle  .b
        mov  ax,[mou_x1]
.b:     cmp  dx,[mou_y0]
        jge  .c
        mov  dx,[mou_y0]
.c:     cmp  dx,[mou_y1]
        jle  .d
        mov  dx,[mou_y1]
.d:     mov  [mou_x],ax
        mov  [mou_y],dx
        jmp  .out
.keys:  mov  word [mou_btn],0
.out:   mov  ax,[mou_x]
        mov  bx,[mou_y]
        mov  cx,[mou_btn]
        pop  dx
        ret
end if

; ----------------------------------------------------------------------
;@ MOU_CLICK  was the left button pressed (or Enter/Space by MOU_KEYS) since last asked?
;  in:  -
;  out: CF = 1 a click; then AX = x, BX = y where it was pressed (the
;       pointer, for a key click). CF = 0: AX, BX kept
;  needs: MOU_INIT first
;  from: new (INT 33h AX=5, press counts kept by the driver, as
;        docs\guide\INPUT.MD The mouse: a click shorter than a frame is
;        not lost; STORY.ASM's WASDOWN edge lost them at a low frame rate)
; ----------------------------------------------------------------------
if used MOU_CLICK
MOU_CLICK:
        push cx
        push dx
        push ax
        push bx
        cmp  byte [mou_kclk],0
        je   .drv
        mov  byte [mou_kclk],0  ; a key click: consumed
        cmp  byte [mou_ok],1
        jne  .key
        mov  ax,5
        xor  bx,bx
        call MOU_DRV            ; and the driver's count with it
.key:   pop  bx
        pop  ax
        mov  ax,[mou_x]
        mov  bx,[mou_y]
        jmp  .yes
.drv:   cmp  byte [mou_ok],1
        jne  .no
        mov  ax,5
        xor  bx,bx              ; the left button
        call MOU_DRV            ; BX = presses since, CX,DX = the last one
        test bx,bx
        jz   .no
        shr  cx,1               ; x in screen pixels
        pop  bx
        pop  ax
        mov  ax,cx
        mov  bx,dx
.yes:   pop  dx
        pop  cx
        stc
        ret
.no:    pop  bx
        pop  ax
        pop  dx
        pop  cx
        clc
        ret
end if

; ----------------------------------------------------------------------
;@ MOU_KEYS   the keyboard as a mouse: arrows move the pointer, Enter/Space click
;  in:  AH = the scan code of a key just taken (INT 16h AH=0, or KEY_NEW's)
;  out: CF = 1 the key was the pointer's (moved, or a click latched for
;       MOU_CLICK); CF = 0 not ours - the caller acts on it
;  needs: -
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:603-674 PKLOOP (the arrows a step,
;        Enter or space clicks, the driver kept in step), ported to 8086
; ----------------------------------------------------------------------
if used MOU_KEYS
MOU_KEYS:
        push ax
        push bx
        cmp  ah,1Ch             ; Enter
        je   .clk
        cmp  ah,39h             ; Space
        je   .clk
        mov  bx,[mou_y]
        mov  al,ah
        mov  ah,0
        cmp  al,48h             ; up
        jne  .k1
        sub  bx,[mou_step]      ; y - step
        jmp  .move
.k1:    cmp  al,50h             ; down
        jne  .k2
        add  bx,[mou_step]      ; y + step
        jmp  .move
.k2:    cmp  al,4Bh             ; left
        jne  .k3
        mov  ax,[mou_x]
        sub  ax,[mou_step]      ; x - step
        jmp  .movx
.k3:    cmp  al,4Dh             ; right
        jne  .not
        mov  ax,[mou_x]
        add  ax,[mou_step]      ; x + step
        jmp  .movx
.move:  mov  ax,[mou_x]
.movx:  call MOU_SET            ; clamped to the range, the driver told
        jmp  .yes
.clk:   mov  byte [mou_kclk],1
.yes:   pop  bx
        pop  ax
        stc
        ret
.not:   pop  bx
        pop  ax
        clc
        ret
end if

; ----------------------------------------------------------------------
;@ MOU_CURDRAW draw the pointer at [mou_x],[mou_y] into ES, keeping what was under it
;  in:  ES = the screen or a back buffer (320 bytes a row), [mou_shape]
;       [mou_ink] [mou_edge]
;  out: - (if it was drawn already it is first taken down: MOU_CURHIDE)
;  needs: MOU_CURHIDE before anything else draws where it is, or before
;         the buffer is drawn over; the same ES for both
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:1352-1446 CURSHOW/CURBITS/CURADDR,
;        ported to 8086 and clipped at every edge (the source kept the
;        whole cursor on the screen, so its tip never reached the right
;        and bottom edges); the hand's hot point is new
; ----------------------------------------------------------------------
if used MOU_CURDRAW
MOU_CURDRAW:
        cmp  byte [mou_on],1
        jne  .go
        call MOU_CURHIDE
.go:    push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        mov  si,[mou_shape]     ; db size, hot x, hot y, then the words
        xor  ah,ah
        mov  al,[si+1]
        mov  bx,[mou_x]
        sub  bx,ax              ; BX = left of the picture (may be < 0)
        mov  al,[si+2]
        mov  dx,[mou_y]
        sub  dx,ax              ; DX = top of the picture
        mov  al,[si]
        mov  bp,ax              ; BP = the size, 8 or 16
        ; across: the columns that are on the screen
        mov  ax,bx
        cmp  ax,0
        jge  .l0
        xor  ax,ax              ; clipped left
.l0:    mov  [mou_sx],ax
        mov  cx,bx
        add  cx,bp              ; CX = right edge + 1
        cmp  cx,320
        jle  .r0
        mov  cx,320             ; clipped right
.r0:    sub  cx,ax              ; CX = the width drawn
        jg   .w0
        xor  cx,cx
.w0:    mov  [mou_sw],cx
        sub  ax,bx              ; AX = columns cut off the left
        mov  [mou_cutx],ax
        ; down: the rows on the screen
        mov  ax,dx
        cmp  ax,0
        jge  .t0
        xor  ax,ax
.t0:    mov  [mou_sy],ax
        mov  cx,dx
        add  cx,bp              ; CX = bottom + 1
        cmp  cx,200
        jle  .b0
        mov  cx,200
.b0:    sub  cx,ax              ; CX = the rows drawn
        jg   .h0
        xor  cx,cx
.h0:    mov  [mou_sh],cx
        sub  ax,dx              ; AX = rows cut off the top
        ; the bitmaps: outline at SI+3, fill BP words further
        add  ax,ax              ; a word a row
        lea  bx,[si+3]
        add  bx,ax              ; BX = the first outline row drawn
        mov  [mou_rowo],bx
        add  bx,bp              ; + size again: the fill's row (BX + 2*size)
        add  bx,bp              ; BX = the same row of the fill (+2*size)
        mov  [mou_rowf],bx
        ; save what is under, then draw
        mov  ax,[mou_sy]
        call MOU_ROWAD          ; DI = row AX's offset
        add  di,[mou_sx]        ; DI = the box's top left
        mov  si,mou_save
        mov  cx,[mou_sh]
        jcxz .done
.row:   push cx
        push di
        mov  cx,[mou_sw]
        jcxz .rnext
        mov  bx,[mou_rowo]
        mov  dx,[bx]            ; DX = the outline's bits, the left on top
        mov  bx,[mou_rowf]
        mov  bp,[bx]            ; BP = the fill's bits
        push cx
        mov  cx,[mou_cutx]
        shl  dx,cl              ; the columns cut off the left gone
        shl  bp,cl              ; the fill's cut columns gone too
        pop  cx
.pix:   mov  al,[es:di]
        mov  [si],al            ; kept
        inc  si                 ; the next save byte
        shl  bp,1               ; CF = fill bit
        jnc  .nf
        shl  dx,1               ; keep the outline's bits in step
        mov  al,[mou_ink]
        mov  [es:di],al
        jmp  .nx
.nf:    shl  dx,1               ; CF = outline bit
        jnc  .nx
        mov  al,[mou_edge]
        mov  [es:di],al
.nx:    inc  di                 ; the next pixel
        loop .pix
.rnext: add  word [mou_rowo],2  ; the next row of each bitmap
        add  word [mou_rowf],2  ; ... of both
        pop  di
        add  di,320             ; the next screen row
        pop  cx
        loop .row
.done:  mov  byte [mou_on],1
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

if used mou_cutx
mou_cutx dw 0                   ; MOU_CURDRAW: columns cut off the left
mou_rowo dw 0                   ;  the outline row being drawn
mou_rowf dw 0                   ;  the fill row being drawn
end if

; ---- MOU_ROWAD (inside the kit): DI = AX * 320, by shifts. AX kept.
if used MOU_ROWAD
MOU_ROWAD:
        push ax
        push cx
        mov  cl,6
        shl  ax,cl              ; AX = y * 64
        mov  di,ax
        shl  ax,1               ; AX = y * 128
        shl  ax,1               ; AX = y * 256
        add  di,ax              ; DI = y*64 + y*256 = y*320
        pop  cx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ MOU_CURHIDE put back what MOU_CURDRAW drew over, exactly where it was drawn
;  in:  ES = the same segment MOU_CURDRAW drew into
;  out: - (nothing happens if the pointer is not drawn)
;  needs: -
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:1393-1419 CURHIDE (restores where it
;        was DRAWN, whatever [mou_x] says by now), ported to 8086
; ----------------------------------------------------------------------
if used MOU_CURHIDE
MOU_CURHIDE:
        cmp  byte [mou_on],1
        jne  .out
        push ax
        push cx
        push dx
        push si
        push di
        mov  ax,[mou_sy]
        call MOU_ROWAD
        add  di,[mou_sx]        ; DI = the box's top left
        mov  si,mou_save
        mov  dx,[mou_sh]
        test dx,dx
        jz   .done
        cld
.row:   mov  cx,[mou_sw]
        push di
        rep  movsb              ; DS:SI -> ES:DI, the row back
        pop  di
        add  di,320             ; the next row
        dec  dx                 ; one row fewer
        jnz  .row
.done:  mov  byte [mou_on],0
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  ax
.out:   ret
end if

; ----------------------------------------------------------------------
;@ MOU_ARROW8 the pointers: MOU_ARROW8 MOU_ARROW16 MOU_HAND8 MOU_HAND16 (mov [mou_shape],...)
;  in:  - (data: db size, hot x, hot y; size words of the outline, size
;       words of the fill, the left pixel the top bit)
;  out: -
;  needs: MOU_CURDRAW draws them; a shape of your own in the same form
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:3567-3618 CUROUT/CURIN, CUR8OUT/
;        CUR8IN (the arrows); the hands new
; ----------------------------------------------------------------------
if used MOU_ARROW8
MOU_ARROW8:
        db 8,0,0
        dw 1100000000000000b
        dw 1110000000000000b
        dw 1111000000000000b
        dw 1111100000000000b
        dw 1111110000000000b
        dw 1111100000000000b
        dw 1101100000000000b
        dw 1000110000000000b
        dw 0000000000000000b
        dw 0100000000000000b
        dw 0110000000000000b
        dw 0111000000000000b
        dw 0111100000000000b
        dw 0110000000000000b
        dw 0000000000000000b
        dw 0000000000000000b
end if
if used MOU_ARROW16
MOU_ARROW16:
        db 16,0,0
        dw 1100000000000000b
        dw 1110000000000000b
        dw 1111000000000000b
        dw 1111100000000000b
        dw 1111110000000000b
        dw 1111111000000000b
        dw 1111111100000000b
        dw 1111111110000000b
        dw 1111111111000000b
        dw 1111111111100000b
        dw 1111111000000000b
        dw 1110011100000000b
        dw 1100011100000000b
        dw 1000001110000000b
        dw 0000001110000000b
        dw 0000000110000000b
        dw 0000000000000000b
        dw 0100000000000000b
        dw 0110000000000000b
        dw 0111000000000000b
        dw 0111100000000000b
        dw 0111110000000000b
        dw 0111111000000000b
        dw 0111111100000000b
        dw 0111111110000000b
        dw 0111110000000000b
        dw 0110110000000000b
        dw 0100011000000000b
        dw 0000011000000000b
        dw 0000001100000000b
        dw 0000001100000000b
        dw 0000000000000000b
end if
if used MOU_HAND8
MOU_HAND8:
        db 8,3,0                ; the fingertip is the hot point
        dw 0011100000000000b
        dw 0011100000000000b
        dw 0011111000000000b
        dw 1111111100000000b
        dw 1111111100000000b
        dw 0111111100000000b
        dw 0011111000000000b
        dw 0011111000000000b
        dw 0000000000000000b
        dw 0001000000000000b
        dw 0001000000000000b
        dw 0001110000000000b
        dw 0111111000000000b
        dw 0011111000000000b
        dw 0001110000000000b
        dw 0000000000000000b
end if
if used MOU_HAND16
MOU_HAND16:
        db 16,5,0               ; the fingertip is the hot point
        dw 0000011000000000b
        dw 0000111100000000b
        dw 0000111100000000b
        dw 0000111100000000b
        dw 0000111111000000b
        dw 0000111111111000b
        dw 0110111111111110b
        dw 1111111111111110b
        dw 1111111111111110b
        dw 0111111111111110b
        dw 0011111111111110b
        dw 0011111111111100b
        dw 0001111111111100b
        dw 0001111111111000b
        dw 0000111111111000b
        dw 0000111111111000b
        dw 0000000000000000b
        dw 0000011000000000b
        dw 0000011000000000b
        dw 0000011000000000b
        dw 0000011000000000b
        dw 0000011011000000b
        dw 0000011011011000b
        dw 0110111111111100b
        dw 0111111111111100b
        dw 0011111111111100b
        dw 0001111111111100b
        dw 0001111111111000b
        dw 0000111111111000b
        dw 0000111111110000b
        dw 0000011111110000b
        dw 0000000000000000b
end if
