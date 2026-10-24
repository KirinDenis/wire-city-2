; ============================================================================
;  K_VGA.INC - KIT: VGA mode 13h (320x200, 256 colours), a back buffer, the
;  retrace, the palette (the DAC: 256 entries of red, green, blue, 0..63).
;
;        call MEM_INIT           ; K_MEM: first of all
;        call VGA_ON             ; mode 13h + a 64000-byte buffer: [vga_buf]
;        jc   .nomem
;  .frame: mov es,[vga_buf]      ; draw into the buffer, 320 bytes a row
;        mov  al,0
;        call VGA_CLS
;        ...draw...
;        call VGA_SHOW           ; the retrace, then the buffer to A000h
;        ...
;        call VGA_OFF            ; text mode 3, the buffer given back
;  Needs K_MEM.INC included too (VGA_ON allocates through MEM_ALLOC).
;  Guide topics VIDEO and RENDER.
; ============================================================================

if used vga_buf
vga_buf  dw 0                   ; the back buffer's segment (0 = none yet)
end if

; ----------------------------------------------------------------------
;@ VGA_ON     mode 13h + a back buffer (cleared to 0) in [vga_buf]
;  in:  -
;  out: CF = 1 no memory for the buffer (the mode is NOT set then);
;       [vga_buf] = the buffer's segment
;  needs: K_MEM's MEM_INIT first; include K_MEM.INC
;  from: new (guide rule 7: DOS 4Ah/48h instead of L19\CLIP.ASM:112-114's
;        CS+1000h); the mode set as LESSONS\L11\KEYS.ASM
; ----------------------------------------------------------------------
if used VGA_ON
VGA_ON:
        push ax
        push bx
        push cx
        cmp  word [vga_buf],0   ; a buffer from before?
        jne  .have
        mov  bx,0FA0h           ; 64000 bytes = 0FA0h paragraphs
        call MEM_ALLOC          ; AX = its segment, CF = none
        jc   .fail
        mov  [vga_buf],ax
.have:  mov  ax,[vga_buf]
        mov  cx,64000           ; the whole buffer
        xor  bl,bl              ; colour 0
        call MEM_CLEAR
        mov  ax,0013h           ; BIOS: mode 13h, 320x200x256
        int  10h
        clc                     ; done
.fail:  pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ VGA_OFF    back to text mode 3 and the buffer given back (every way out)
;  in:  -
;  out: - ([vga_buf] = 0)
;  needs: -
;  from: LESSONS\L11\KEYS.ASM (Bye: mode 3)
; ----------------------------------------------------------------------
if used VGA_OFF
VGA_OFF:
        push ax
        mov  ax,0003h           ; BIOS: text mode 3, 80x25, a clean screen
        int  10h
        mov  ax,[vga_buf]
        call MEM_FREE           ; (0 = none: ignored)
        mov  word [vga_buf],0
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ VGA_CLS    fill the whole back buffer with colour AL
;  in:  AL = the colour; [vga_buf]
;  out: -
;  needs: VGA_ON
;  from: new (REP STOSW, as every game's clear)
; ----------------------------------------------------------------------
if used VGA_CLS
VGA_CLS:
        push ax
        push cx
        push di
        push es
        mov  es,[vga_buf]       ; ES = the buffer
        xor  di,di
        mov  ah,al              ; AX = the colour twice
        mov  cx,32000           ; 64000 bytes = 32000 words
        cld
        rep  stosw
        pop  es
        pop  di
        pop  cx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ VGA_WAIT   wait for the start of the next vertical retrace
;  in:  -
;  out: -
;  needs: -
;  from: EXAMPLES\RELIEF.ASM:1646-1657 (WAITVR)
; ----------------------------------------------------------------------
if used VGA_WAIT
VGA_WAIT:
        push ax
        push dx
        mov  dx,3DAh            ; the VGA status port
.o:     in   al,dx
        test al,8               ; bit 3: the beam is in vertical retrace
        jnz  .o                 ; wait OUT any retrace running
.i:     in   al,dx
        test al,8
        jz   .i                 ; wait for the next one to begin
        pop  dx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ VGA_SHOW   wait for the retrace, copy the back buffer to the screen
;  in:  [vga_buf]
;  out: -
;  needs: VGA_ON
;  from: EXAMPLES\RELIEF.ASM:1624-1636 (SHOW), registers kept
; ----------------------------------------------------------------------
if used VGA_SHOW
VGA_SHOW:
        call VGA_WAIT
        push cx
        push si
        push di
        push ds
        push es
        mov  cx,0A000h
        mov  es,cx              ; ES = the screen
        mov  ds,[vga_buf]       ; DS = the buffer (read before DS changes)
        xor  si,si
        xor  di,di
        mov  cx,32000           ; 64000 bytes as 32000 words
        cld
        rep  movsw
        pop  es
        pop  ds
        pop  di
        pop  si
        pop  cx
        ret
end if

; ----------------------------------------------------------------------
;@ VGA_PAL    set DAC entries from a tagged list: index,r,g,b ... 255
;  in:  SI = the list (DS): entries of 4 bytes, ended by a 255 byte;
;       colours 0..63. Entry 255 cannot be in it - use VGA_PALRUN
;  out: -
;  needs: -
;  from: EXAMPLES\JET.ASM:478-492 (SETPAL)
; ----------------------------------------------------------------------
if used VGA_PAL
VGA_PAL:
        push ax
        push dx
        push si
        cld
.p:     lodsb                   ; AL = the entry's number
        cmp  al,255             ; the end?
        je   .done
        mov  dx,3C8h            ; DAC write index
        out  dx,al
        inc  dx                 ; 3C9h: the data, red green blue
        lodsb
        out  dx,al
        lodsb
        out  dx,al
        lodsb
        out  dx,al
        jmp  .p
.done:  pop  si
        pop  dx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ VGA_PALRUN set CX DAC entries from AL on, from r,g,b bytes at SI
;  in:  AL = the first entry, CX = how many (1..256), SI = 3*CX bytes (DS)
;  out: -
;  needs: -
;  from: LESSONS\L31\MANDEL.ASM:241-259 (SPINPAL's OUT run)
; ----------------------------------------------------------------------
if used VGA_PALRUN
VGA_PALRUN:
        push ax
        push cx
        push dx
        push si
        mov  dx,3C8h
        out  dx,al              ; from entry AL
        inc  dx                 ; 3C9h
        mov  ax,cx
        add  cx,cx              ; CX = count * 2
        add  cx,ax              ; CX = count * 3 bytes
        cld
.e:     lodsb
        out  dx,al
        loop .e
        pop  si
        pop  dx
        pop  cx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ VGA_PALGET read CX DAC entries from AL on into r,g,b bytes at DI
;  in:  AL = the first entry, CX = how many (1..256), DI = 3*CX bytes (DS)
;  out: -
;  needs: -
;  from: new (DAC read index 3C7h, the mirror of VGA_PALRUN)
; ----------------------------------------------------------------------
if used VGA_PALGET
VGA_PALGET:
        push ax
        push cx
        push dx
        push di
        push es
        push ds
        pop  es                 ; STOSB writes ES:DI: ES = ours
        mov  dx,3C7h            ; DAC read index
        out  dx,al
        mov  dx,3C9h
        mov  ax,cx
        add  cx,cx              ; CX = count * 2
        add  cx,ax              ; CX = count * 3 bytes
        cld
.e:     in   al,dx
        stosb
        loop .e
        pop  es
        pop  di
        pop  dx
        pop  cx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ VGA_FADE   the whole DAC at level AL (0 black .. 64 full) of a palette
;  in:  AL = level 0..64, SI = the full palette, 768 bytes (DS), 0..63 each
;  out: -
;  needs: keep the palette (VGA_PALGET 0,256 or your table); step AL one
;         a tick (TIM_WAIT 1) for a fade
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:3297-3311 (PALSET), ported to 8086,
;        64 levels instead of 8
; ----------------------------------------------------------------------
if used VGA_FADE
VGA_FADE:
        push ax
        push bx
        push cx
        push dx
        push si
        mov  bl,al              ; BL = the level
        cmp  bl,64
        jbe  .lv
        mov  bl,64              ; no brighter than the palette itself
.lv:    mov  dx,3C8h
        xor  al,al
        out  dx,al              ; from entry 0
        inc  dx                 ; 3C9h
        mov  cx,768             ; 256 entries * 3
        mov  bh,6               ; the shift count, kept out of CL's way
        cld
.e:     lodsb                   ; AL = the colour, 0..63
        mul  bl                 ; AX = colour * level (at most 63*64)
        push cx
        mov  cl,bh
        shr  ax,cl              ; AX = / 64
        pop  cx
        out  dx,al
        loop .e
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ VGA_CYCLE  rotate DAC entries AL..AL+CX-1 one place (colour cycling)
;  in:  AL = the first entry, CX = how many (2..256; less: nothing)
;  out: - (entry AL gets the colour of AL+1, the last gets the first's)
;  needs: -
;  from: new (reads the DAC back; the lesson's way of a phase into a
;        ramp table is LESSONS\L31\MANDEL.ASM:241-259)
; ----------------------------------------------------------------------
if used VGA_CYCLE
VGA_CYCLE:
        cmp  cx,2
        jb   .none
        cmp  cx,256
        ja   .none
        push ax
        push cx
        push si
        push di
        mov  di,vga_tmp
        call VGA_PALGET         ; vga_tmp = the range as it is
        mov  si,vga_tmp+3       ; SI = the second entry's r,g,b
        dec  cx                 ; CX = all but the first
        call VGA_PALRUN         ; entries AL.. = old AL+1..
        add  al,cl              ; AL = the last entry (wraps past 255)
        mov  si,vga_tmp         ; SI = the old first's r,g,b, still there
        mov  cx,1
        call VGA_PALRUN         ; the last = the old first
        pop  di
        pop  si
        pop  cx
        pop  ax
.none:  ret
vga_tmp  db 768 dup(0)          ; one palette's worth of scratch
end if

; ----------------------------------------------------------------------
;@ VGA_RAMP   make a gradient: CX bands of BL steps between key colours
;  in:  SI = CX+1 key colours, r,g,b each (0..63); CX = bands (1..);
;       BL = steps a band (1..255); DI = the output, CX*BL*3 bytes (DS)
;  out: - (each band starts ON its key and stops one step short of the
;       next: the last key is never written, so key 0 = last key makes a
;       ramp with no seam when it cycles). Write it with VGA_PALRUN.
;  needs: -
;  from: LESSONS\L31\MANDEL.ASM:286-318 (MKRAMP), bands and steps made
;        parameters (the lesson: 4 bands of 32 by a shift)
; ----------------------------------------------------------------------
if used VGA_RAMP
VGA_RAMP:
        or   bl,bl              ; no steps: nothing to divide by
        jz   .out
        jcxz .out
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        mov  bp,cx              ; BP = the bands to go
.band:  xor  dx,dx              ; DX = f, the step in the band
.f:     push si
        mov  cx,3               ; three channels
.ch:    mov  al,[si+3]          ; AL = the band's end b (0..63)
        xor  ah,ah
        push dx
        mov  dl,[si]            ; DL = the start a
        xor  dh,dh
        sub  ax,dx              ; AX = b - a (-63..63)
        pop  dx
        push dx
        imul dx                 ; DX:AX = (b - a) * f, |..| < 63*255: fits AX
        push bx
        xor  bh,bh              ; BX = steps, 1..255 - never 0 (checked)
        cwd                     ; DX:AX = the product, sign-extended
        idiv bx                 ; AX = (b - a) * f / steps, |AX| < 64
        pop  bx
        pop  dx
        add  al,[si]            ; AL = a + that: between a and b
        mov  [di],al
        inc  di
        inc  si                 ; the next channel
        loop .ch
        pop  si
        inc  dx                 ; f++
        cmp  dl,bl              ; all the steps of the band?
        jb   .f
        add  si,3               ; the next key
        dec  bp
        jnz  .band
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
.out:   ret
end if

; ----------------------------------------------------------------------
;@ VGA_GLOW   set DAC entry AL to colour (BX mod CX) of a table: a glow
;  in:  AL = the entry; SI = CX colours r,g,b (DS); CX = how many (0 =
;       nothing); BX = the phase (a tick, a frame count: any number)
;  out: -
;  needs: -
;  from: new (a one-entry form of LESSONS\L31\MANDEL.ASM's SPINPAL)
; ----------------------------------------------------------------------
if used VGA_GLOW
VGA_GLOW:
        jcxz .none
        push ax
        push cx
        push dx
        push si
        push ax                 ; the entry, kept
        mov  ax,bx              ; AX = the phase
        xor  dx,dx
        div  cx                 ; DX = phase mod CX (CX is not 0: checked)
        mov  ax,dx
        add  dx,dx              ; DX = n * 2
        add  dx,ax              ; DX = n * 3: its bytes
        add  si,dx              ; SI = that colour
        pop  ax                 ; AL = the entry
        mov  cx,1
        call VGA_PALRUN
        pop  si
        pop  dx
        pop  cx
        pop  ax
.none:  ret
end if

; ----------------------------------------------------------------------
;@ VGA_PALCOL a palette's brightest, darkest and greyest entries
;  in:  SI = a palette of 768 bytes (DS) - VGA_PALGET 0,256 makes one
;  out: AL = the brightest entry, AH = the darkest, BL = the nearest a
;       mid grey (38 of 63) that is truly grey - for text and outlines
;       over a picture whose palette you did not choose
;  needs: -
;  from: LAB\OWLFLY4\ENGINE\STORY.ASM:1750-1805 (PALCOLS), ported to 8086
; ----------------------------------------------------------------------
if used VGA_PALCOL
VGA_PALCOL:
        push cx
        push dx
        push si
        push di
        push bp
        mov  word [vga_pmax],0
        mov  word [vga_pmin],0FFFFh
        mov  word [vga_pgry],0FFFFh
        xor  cx,cx              ; CX = the entry, 0..255
.e:     xor  ax,ax
        xor  bx,bx
        mov  al,[si]            ; AX = r
        mov  bl,[si+1]
        add  ax,bx              ; + g
        mov  bl,[si+2]
        add  ax,bx              ; + b: the brightness, 0..189
        cmp  ax,[vga_pmax]
        jbe  .n1
        mov  [vga_pmax],ax
        mov  [vga_white],cl
.n1:    cmp  ax,[vga_pmin]
        jae  .n2
        mov  [vga_pmin],ax
        mov  [vga_black],cl
.n2:    xor  ax,ax
        xor  bx,bx
        xor  dx,dx
        mov  al,[si]            ; AX = r
        mov  bl,[si+1]          ; BX = g
        mov  dl,[si+2]          ; DX = b
        add  si,3
        xor  bp,bp              ; BP = the sum of distances
        mov  di,ax
        sub  di,38              ; |r - grey|
        call .absadd
        mov  di,bx
        sub  di,38              ; |g - grey|
        call .absadd
        mov  di,dx
        sub  di,38              ; |b - grey|
        call .absadd
        mov  di,ax
        sub  di,bx              ; |r - g|
        call .absadd
        mov  di,bx
        sub  di,dx              ; |g - b|
        call .absadd
        cmp  bp,[vga_pgry]
        jae  .n3
        mov  [vga_pgry],bp
        mov  [vga_grey],cl
.n3:    inc  cx
        cmp  cx,256
        jb   .e
        mov  al,[vga_white]
        mov  ah,[vga_black]
        mov  bl,[vga_grey]
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        ret
.absadd:test di,di
        jns  .pos
        neg  di                 ; DI = |DI|
.pos:   add  bp,di              ; BP += it
        ret
vga_pmax  dw 0
vga_pmin  dw 0
vga_pgry  dw 0
vga_white db 0
vga_black db 0
vga_grey  db 0
end if

; ----------------------------------------------------------------------
;@ VGA_ROW    DI = row AX * 320 (the row's first byte), by shifts
;  in:  AX = the row, 0..199
;  out: DI = AX * 320
;  needs: -
;  from: new (y*256 + y*64: the games' ROW320 without MUL)
; ----------------------------------------------------------------------
if used VGA_ROW
VGA_ROW:
        push ax
        push cx
        mov  cl,6
        shl  ax,cl              ; AX = y * 64
        mov  di,ax              ; DI = y * 64
        shl  ax,1
        shl  ax,1               ; AX = y * 256
        add  di,ax              ; DI = y * 320
        pop  cx
        pop  ax
        ret
end if
