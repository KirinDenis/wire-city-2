; SHOT.INC - the experiment's "screen" tool: SHOT_SAVE writes what the
; screen shows NOW to SHOT.RAW in the current folder; the runner turns it
; into SCREEN.PNG. It asks the BIOS which mode is on:
;   mode 13h (VGA 320x200x256): 64000 bytes of A000h, then the DAC (768)
;   mode 0Dh / 0Eh (EGA 320x200 / 640x200, 16 colours): 'EG', width,
;     height (words), the picture read back plane by plane from where the
;     CRTC shows it (its start address and row length - a hardware scroll
;     is followed), a byte a pixel 0..15, then 16 colours as the DAC has
;     them through the attribute palette (768 bytes, the rest 0)
; Call it while the picture is on the screen, before mode 3. Keeps every
; register and gives the EGA's read-map register back. Include it after
; your program's way out:      include '..\SHOT.INC'
SHOT_SAVE:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        push ds
        push es
        push cs
        pop  ds
        push cs
        pop  es
        mov  ah,0Fh
        int  10h                ; AL = the mode now
        cmp  al,13h
        je   .vga
        mov  word [shot_w],320
        cmp  al,0Dh
        je   .ega
        mov  word [shot_w],640
        cmp  al,0Eh
        je   .ega
        jmp  .x                 ; another mode: no picture
.vga:   mov  di,shot_pal
        mov  dx,3C7h
        xor  al,al
        out  dx,al              ; read the DAC from colour 0
        mov  dx,3C9h
        mov  cx,768
.p:     in   al,dx
        stosb
        loop .p
        call .create
        jc   .x
        push ds
        mov  ax,0A000h
        mov  ds,ax
        mov  ah,40h
        mov  cx,64000
        xor  dx,dx
        int  21h                ; the screen
        pop  ds
        jmp  .pal
; ---- EGA: palette through the attribute registers, then plane by plane
.ega:   mov  di,shot_pal
        mov  cx,384
        xor  ax,ax
        rep  stosw              ; 768 bytes of 0
        xor  bx,bx              ; colour 0..15
.attr:  mov  dx,3DAh
        in   al,dx              ; the attribute flip-flop to "index"
        mov  dx,3C0h
        mov  al,bl
        out  dx,al              ; palette register BL (display off for now)
        inc  dx
        in   al,dx              ; 3C1h: its DAC index
        mov  [shot_ai+bx],al
        inc  bx
        cmp  bx,16
        jb   .attr
        mov  dx,3DAh
        in   al,dx
        mov  dx,3C0h
        mov  al,20h
        out  dx,al              ; the display back on
        xor  bx,bx
        mov  di,shot_pal
.dac:   mov  dx,3C7h
        mov  al,[shot_ai+bx]
        out  dx,al              ; read that DAC entry
        mov  dx,3C9h
        in   al,dx
        stosb
        in   al,dx
        stosb
        in   al,dx
        stosb
        inc  bx
        cmp  bx,16
        jb   .dac
        mov  dx,3D4h            ; the CRTC: where the picture starts
        mov  al,0Ch
        out  dx,al
        inc  dx
        in   al,dx
        mov  ah,al              ; start, high byte
        dec  dx
        mov  al,0Dh
        out  dx,al
        inc  dx
        in   al,dx              ; start, low byte
        mov  [shot_row0],ax
        dec  dx
        mov  al,13h
        out  dx,al
        inc  dx
        in   al,dx              ; the offset register: words a row
        xor  ah,ah
        shl  ax,1               ; x2: bytes a row
        mov  [shot_bpr],ax
        mov  dx,3CEh
        in   al,dx
        mov  [shot_gci],al      ; the graphics controller's index, kept
        mov  al,4
        out  dx,al
        inc  dx
        in   al,dx
        mov  [shot_map],al      ; its read-map register, kept
        call .create
        jc   .back
        mov  word [shot_hdr],'EG'
        mov  ax,[shot_w]
        mov  [shot_hdr+2],ax
        mov  word [shot_hdr+4],200
        mov  bx,[shot_fh]
        mov  ah,40h
        mov  cx,6
        mov  dx,shot_hdr
        int  21h                ; 'EG', width, height
        mov  bp,200             ; rows to go
        mov  si,[shot_row0]     ; this row's first byte in A000h
.row:   push si
        mov  di,shot_rowb
        mov  cx,[shot_w]
        shr  cx,1
        shr  cx,1
        shr  cx,1               ; /8: bytes across
.byte:  mov  dx,3CEh
        mov  al,4
        out  dx,al
        inc  dx
        push ds
        mov  ax,0A000h
        mov  ds,ax
        mov  al,0
        out  dx,al
        mov  bl,[si]            ; plane 0
        mov  al,1
        out  dx,al
        mov  bh,[si]            ; plane 1
        mov  al,2
        out  dx,al
        mov  ah,[si]            ; plane 2
        mov  al,3
        out  dx,al
        mov  dl,[si]            ; plane 3 (DX not needed till the next byte)
        pop  ds
        mov  dh,8               ; eight pixels
.pix:   xor  al,al
        shl  dl,1
        rcl  al,1               ; plane 3: the colour's top bit
        shl  ah,1
        rcl  al,1
        shl  bh,1
        rcl  al,1
        shl  bl,1
        rcl  al,1               ; plane 0: its bottom bit
        stosb
        dec  dh
        jnz  .pix
        inc  si
        loop .byte
        pop  si
        add  si,[shot_bpr]      ; the next row
        mov  bx,[shot_fh]
        mov  ah,40h
        mov  cx,[shot_w]
        mov  dx,shot_rowb
        int  21h                ; one row of pixels
        dec  bp
        jnz  .row
.pal:   mov  bx,[shot_fh]
        mov  ah,40h
        mov  cx,768
        mov  dx,shot_pal
        int  21h                ; the palette
        mov  ah,3Eh
        int  21h                ; closed
.back:  mov  dx,3CEh            ; (harmless after mode 13h too: not EGA there)
        cmp  word [shot_bpr],0
        je   .x
        mov  al,4
        out  dx,al
        inc  dx
        mov  al,[shot_map]
        out  dx,al              ; read map as it was
        dec  dx
        mov  al,[shot_gci]
        out  dx,al              ; index as it was
        mov  word [shot_bpr],0
.x:     pop  es
        pop  ds
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
.create:
        mov  ah,3Ch
        xor  cx,cx
        mov  dx,shot_nm
        int  21h                ; create SHOT.RAW; CF on failure
        mov  bx,ax              ; the handle
        mov  [shot_fh],ax
        ret
shot_nm   db 'SHOT.RAW',0
shot_w    dw 0
shot_bpr  dw 0
shot_fh   dw 0
shot_row0 dw 0
shot_gci  db 0
shot_map  db 0
shot_hdr  dw 0,0,0
shot_ai   db 16 dup(0)
shot_pal  db 768 dup(0)
shot_rowb db 640 dup(0)
