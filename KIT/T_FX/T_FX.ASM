; ============================================================================
;@ T_FX       title screen / demo effect: plasma + colour cycling, wavy rows, sine scroller, tune, fades
;  T_FX.ASM - KIT template: the screen a game opens on. FXTITLE is a whole
;  routine - call it after VGA_ON and KEY_ON; it returns on any key with the
;  screen faded to black (AL = the key's scan code), and the game goes on
;  with its own picture and palette.
;
;  WHAT MOVES, AND WHAT IT COSTS (LESSONS\L31\MANDEL.ASM's lesson: "only the
;  palette moves"):
;    the plasma is drawn ONCE, into a segment of its own, from a table of
;      sines (MTH_SIN made into 0..32 bytes): four waves summed, a pixel is
;      64 + 0..127 - a NUMBER, not a colour;
;    the colours are 128 DAC entries made by VGA_RAMP from five key colours
;      (the first = the last: no seam), turned by VGA_CYCLE every tick -
;      the whole picture flows, and not one pixel is written for it;
;    each frame the rows are copied to the back buffer shifted by a sine of
;      their row and the time: the plasma waves like a flag, for the price
;      of the copy that had to happen anyway;
;    the scroller: the 8x8 BIOS letters twice as big with a shadow, each
;      letter lifted by a sine of where it is on the screen;
;    a tune on the speaker (SPK_TUNE, played by SPK_TICK once a tick);
;    VGA_FADE in from black at the start and out to black at the end (the
;      cycled palette is read back first, so the fade starts from it).
;  /AUTO: a "key" after 3 s; checks the fade up, the cycling, the scroller,
;  the tune, and that the DAC is black at the end. Uses: K_MEM K_VGA K_KEYS
;  K_TIME K_MATH K_TEXT (DOS lines) K_SPK K_FONT. Build: KIT\MAKEWIN T_FX T_FX
;  LETTERS: K_FONT's - the name FNT_LTITLE with our own ramp (fx_gold: a
;  ramp must avoid the DAC entries you cycle), the subtitle and the
;  scroller FNT_LSUB (ringed: they read on the moving plasma), PRESS ANY
;  KEY 8x16 ringed. The game after the title: KIT\REC\R_TITLE.ASM.
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

PBASE   = 64                    ; the plasma's 128 colours: DAC 64..191
PN      = 128
SCRY    = 150                   ; the scroller's line
FADEST  = 2                     ; fade speed: levels a tick (64 = full)
AUTOT   = 54                    ; /AUTO: ticks before the "key"

start:  call GETAUTO
        call MEM_INIT
        call VGA_ON
        jc   nomem
        mov  bx,0FA0h           ; 64000 bytes for the plasma
        call MEM_ALLOC
        jc   nomem2
        mov  [plas],ax
        call KEY_ON
        call FXTITLE            ; the title screen, until a key
        mov  al,15              ; (a check: entry 15, white text, read
        mov  cx,1               ;  back while the DAC is still ours)
        mov  di,rgb2
        call VGA_PALGET
        call SPK_STOP           ; every way out: sound, memory, keys, screen
        mov  ax,[plas]
        call MEM_FREE
        call KEY_OFF
        call VGA_OFF
        cmp  byte [auto],0
        je   .bye
        call REPORT
.bye:   mov  ax,4C00h
        int  21h
nomem2: call VGA_OFF
nomem:  mov  dx,t_nomem
        mov  ah,9
        int  21h
        mov  ax,4C01h
        int  21h

; ---- FXTITLE: the title screen until a key; out AL = the key, DAC black ---
FXTITLE:call MKSINE             ; the byte sine table
        call MKPLASMA           ; the picture, once
        mov  si,keys            ; the palette: 128 colours round a loop
        mov  di,ramp
        mov  cx,4               ; 4 bands...
        mov  bl,PN/4            ; ...of 32 steps
        call VGA_RAMP
        mov  al,PBASE
        mov  cx,PN
        mov  si,ramp
        call VGA_PALRUN         ; into DAC 64..191
        xor  al,al
        mov  cx,256
        mov  di,pal
        call VGA_PALGET         ; the whole palette, to fade with
        xor  al,al
        mov  si,pal
        call VGA_FADE           ; black, before the first frame shows
        mov  si,tune
        call SPK_TUNE
        mov  [tune0],si         ; (a check: where it started)
        call KEY_FLUSH          ; old taps do not count
        call TIM_STEPS
.frame: call TIM_STEPS
        mov  cx,ax
        jcxz .draw
.step:  call FXSTEP             ; one tick (keeps CX)
        loop .step
        cmp  byte [fxst],3      ; faded out: done
        je   .done
.draw:  call FXDRAW
        call VGA_SHOW
        jmp  .frame
.done:  mov  al,[fxkey]
        ret

; FXSTEP: one tick - the tune, the clocks, the fade or the cycling
FXSTEP: push ax
        push cx
        push si
        call SPK_TICK
        inc  word [phase]       ; the time
        add  word [scroll],2    ; the scroller: 2 pixels a tick
        mov  al,[fxst]
        cmp  al,1
        je   .run
        cmp  al,2
        je   .out
        cmp  al,0
        jne  .r
        mov  al,[lvl]           ; 0: fading in
        add  al,FADEST          ; brighter
        cmp  al,64
        jb   .fi
        mov  al,64
        mov  byte [fxst],1      ; full: run
        mov  [maxlvl],al
        push di
        mov  al,PBASE           ; (a check: entry 64's colour now)
        mov  cx,1
        mov  di,rgb0
        call VGA_PALGET
        pop  di
        mov  al,64
.fi:    mov  [lvl],al
        mov  si,pal
        call VGA_FADE
        jmp  .r
.run:   mov  al,PBASE           ; 1: the colours go round a place a tick
        mov  cx,PN
        call VGA_CYCLE
        inc  word [cycles]
        cmp  byte [auto],0
        je   .key
        cmp  word [phase],AUTOT
        jb   .r
        mov  al,SC_SPACE        ; /AUTO: a key, as if pressed
        jmp  .got
.key:   call KEY_ANY            ; AL = a key since the last look, 0 none
        jz   .r
.got:   mov  [fxkey],al
        push di
        mov  al,PBASE           ; (a check: entry 64 after the cycling)
        mov  cx,1
        mov  di,rgb1
        call VGA_PALGET
        xor  al,al              ; the palette as it is now, cycled: the
        mov  cx,256             ;  fade out starts from what is seen
        mov  di,pal
        call VGA_PALGET
        pop  di
        mov  byte [fxst],2
        jmp  .r
.out:   mov  al,[lvl]           ; 2: fading out
        sub  al,FADEST          ; darker
        jnc  .fo
        xor  al,al
.fo:    mov  [lvl],al
        mov  si,pal
        call VGA_FADE
        or   al,al
        jnz  .r
        mov  byte [fxst],3      ; black: FXTITLE returns
.r:     pop  si
        pop  cx
        pop  ax
        ret

; MKSINE: sinb[a] = (sin(a) + 256) / 16, 0..32, for a = 0..255
MKSINE: xor  bx,bx
.s:     mov  ax,bx
        call MTH_SIN            ; AX = sin * 256, -256..256
        add  ax,256             ; 0..512
        mov  cl,4
        shr  ax,cl              ; / 16: 0..32
        mov  [sinb+bx],al
        inc  bx                 ; the next angle
        cmp  bx,256
        jb   .s
        ret

; MKPLASMA: pixel = 64 + four sine waves summed (0..128, held to 127)
MKPLASMA:
        push es
        mov  es,[plas]
        xor  di,di
        xor  dx,dx              ; DX = y
.y:     xor  cx,cx              ; CX = x
.x:     mov  bx,cx
        and  bx,255             ; wave 1: across, a 256-pixel period
        mov  al,[sinb+bx]
        mov  bx,dx
        shl  bx,1               ; wave 2: down, twice as fast
        add  bx,64              ;  a quarter turn on
        and  bx,255
        add  al,[sinb+bx]
        mov  bx,cx
        add  bx,dx              ; wave 3: on the diagonal
        and  bx,255
        add  al,[sinb+bx]
        mov  bx,cx
        shr  bx,1               ; wave 4: x/2 - y, the other diagonal
        sub  bx,dx
        and  bx,255             ; (negative wraps round: AND keeps 0..255)
        add  al,[sinb+bx]       ; AL = 0..128
        cmp  al,PN
        jb   .k
        mov  al,PN-1            ; 128 -> 127: inside the ramp
.k:     add  al,PBASE           ; a DAC entry 64..191
        stosb
        inc  cx                 ; the next x
        cmp  cx,320
        jb   .x
        inc  dx                 ; the next row
        cmp  dx,200
        jb   .y
        pop  es
        ret

; FXDRAW: the plasma rows, each shifted by a sine; the title; the scroller
FXDRAW: push es
        mov  es,[vga_buf]
        mov  dx,[plas]          ; DX = the plasma's segment (DS is ours)
        xor  bx,bx              ; BX = row
        xor  di,di
.row:   mov  ax,bx
        shl  ax,1               ; two waves down the screen...
        shl  ax,1
        add  ax,[phase]         ; ...moving with the time
        add  ax,[phase]
        call MTH_SIN            ; AX = -256..256
        mov  cl,5
        sar  ax,cl              ; / 32: a shift of -8..8 pixels
        jns  .p
        add  ax,320             ; left: start that far from the row's end
.p:     mov  si,di              ; SI = the row's start in the plasma
        add  si,ax              ;  + the shift
        mov  cx,320
        sub  cx,ax              ; CX = bytes from there to the row's end
        push ds
        mov  ds,dx
        rep  movsb              ; the row's tail first...
        mov  cx,ax              ; ...then its head (AX bytes)
        sub  si,320             ; back to the row's start
        rep  movsb
        pop  ds
        inc  bx                 ; the next row
        cmp  bx,200
        jb   .row
        mov  al,FNT_LTITLE      ; the title: K_FONT's 8x8 x4 smooth, a ramp
        call FNT_LOOK           ;  down the letters, ring 2 + shadow
        mov  word [fnt_gtab],fx_gold ; our ramp: FNT_LTITLE's gold has DAC
        mov  byte [fnt_gn],FXGOLDN ;  68 and 92, which the plasma cycles
        mov  si,t_title
        mov  bx,160             ; centred on x 160
        mov  dx,30              ; its top
        call FNT_CENTER
        mov  al,FNT_LSUB        ; the subtitle: 8x8 x2 smooth, ringed
        call FNT_LOOK
        mov  si,t_sub
        mov  bx,160
        mov  dx,70
        call FNT_CENTER
        mov  al,FNT_LSUB        ; the scroller: the same look, fixed cells
        call FNT_LOOK           ;  (16 pixels a letter, as the loop steps)
        mov  byte [fnt_prop],0
        mov  ax,320
        sub  ax,[scroll]        ; AX = x of the first letter
        mov  si,t_scroll
.ch:    mov  bl,[si]
        or   bl,bl
        jz   .end
        cmp  ax,-16             ; off the left?
        jl   .nx
        cmp  ax,320             ; past the right: the rest is too
        jge  .tail
        push ax
        add  ax,[phase]
        add  ax,[phase]         ; the wave travels with the time
        call MTH_SIN            ; AX = -256..256
        mov  cl,5
        sar  ax,cl              ; -8..8 pixels
        add  ax,SCRY
        mov  dx,ax              ; DX = this letter's y
        pop  ax
        mov  bx,ax              ; BX = its x
        push ax
        mov  al,[si]
        call FNT_CHAR           ; one ringed letter at (BX,DX)
        pop  ax
.nx:    inc  si                 ; the next letter...
        add  ax,16              ; ...16 pixels on
        jmp  .ch
.end:   cmp  ax,0               ; the last letter gone off the left?
        jg   .tail
        mov  word [scroll],0    ; from the right again
.tail:  test byte [phase],16    ; blinking: 16 ticks on, 16 off
        jz   .x
        mov  al,FNT_LMENU       ; PRESS ANY KEY: 8x16, yellow, ringed
        call FNT_LOOK
        mov  byte [fnt_style],FNT_RINGSH
        mov  byte [fnt_col],14
        mov  si,t_any
        mov  bx,160
        mov  dx,178
        call FNT_CENTER
.x:     pop  es
        ret

; ---- REPORT (/AUTO) -------------------------------------------------------
REPORT: mov  si,c_fade          ; the fade came up to full
        cmp  byte [maxlvl],64
        call PFE
        mov  si,c_cyc           ; the cycling changed entry 64's colour
        mov  ax,word [rgb0]
        cmp  ax,word [rgb1]
        jne  .c1
        mov  al,[rgb0+2]
        cmp  al,[rgb1+2]
.c1:    call PFN
        mov  si,c_scr           ; the scroller moved
        cmp  word [scroll],0
        call PFN
        mov  si,c_tune          ; the tune went on from where it started
        mov  ax,[spk_tp]
        cmp  ax,[tune0]
        call PFN
        mov  si,c_blk           ; FXTITLE left the DAC black
        cmp  byte [fxst],3
        jne  .b
        mov  al,[rgb2]          ; entry 15 as FXTITLE left it
        or   al,[rgb2+1]
        or   al,[rgb2+2]
        cmp  al,0
.b:     call PFE
        ret
; PFE: PASS if the last compare said equal; PFN: if not equal
PFE:    mov  dx,t_pass
        je   PFS
        mov  dx,t_fail
        jmp  PFS
PFN:    mov  dx,t_pass
        jne  PFS
        mov  dx,t_fail
PFS:    call TXT_DOS
        call TXT_DOSZ
        call TXT_DOSCR
        ret

; ---- GETAUTO: [auto] = 1 if the command line holds /AUTO -----------------
GETAUTO:mov  si,81h
        xor  ch,ch
        mov  cl,[80h]           ; the command line's length
.s:     jcxz .no
        lodsb
        dec  cx                 ; one character read
        cmp  al,'/'
        jne  .s
        cmp  cx,4
        jb   .no
        mov  ax,[si]
        and  ax,0DFDFh          ; upper case
        cmp  ax,'AU'
        jne  .s
        mov  ax,[si+2]
        and  ax,0DFDFh
        cmp  ax,'TO'
        jne  .s
        mov  byte [auto],1
.no:    ret

; ---- data -----------------------------------------------------------------
keys    db  2, 0,12             ; the ramp's key colours (r,g,b 0..63):
        db 30, 4,40             ;  deep blue, violet, orange, gold...
        db 63,24, 4
        db 63,58,20
        db  2, 0,12             ;  ...and the first again: no seam
; the tune: note (25 = middle C), ticks; 0 a rest; 0FFh the end
tune    db 25,4, 29,4, 32,4, 37,8, 0,2, 32,4, 37,12, 0,4
        db 30,4, 34,4, 37,4, 42,8, 0,2, 37,4, 42,12, 0FFh
FXGOLDN = 8                     ; our ramp for the title, top to bottom: DAC
fx_gold db 15,44,44,43,43,42,42,6 ;  entries the plasma does not cycle (<64)
t_title db 'WIRE CITY',0
t_sub   db 'a title from the kit',0
t_scroll db 'A TITLE SCREEN FROM THE KIT ... THE PALETTE TURNS, THE ROWS WAVE, '
        db 'THE LETTERS RIDE A SINE ... PRESS ANY KEY',0
t_any   db 'PRESS ANY KEY',0
t_pass  db 'PASS T_FX $'
t_fail  db 'FAIL T_FX $'
c_fade  db 'VGA_FADE brought the palette up from black to full',0
c_cyc   db 'VGA_CYCLE turned the plasma colours (DAC 64 changed)',0
c_scr   db 'the sine scroller moved',0
c_tune  db 'SPK_TUNE played on from its first note',0
c_blk   db 'the fade out left the DAC black (entry 15 read back 0,0,0)',0
t_nomem db 'Not enough memory for the screen buffers.',13,10,'$'
auto    db 0
fxst    db 0                    ; 0 fade in, 1 run, 2 fade out, 3 done
fxkey   db 0
lvl     db 0                    ; the fade's level, 0..64
maxlvl  db 0
plas    dw 0                    ; the plasma's segment
phase   dw 0                    ; ticks since the start
scroll  dw 0                    ; pixels the scroller has gone
cycles  dw 0
tune0   dw 0
rgb0    db 3 dup(0)
rgb1    db 3 dup(0)
rgb2    db 3 dup(0)
sinb    db 256 dup(0)           ; 0..32 sine bytes
ramp    db PN*3 dup(0)          ; the 128 colours
pal     db 768 dup(0)           ; the whole palette, for the fades

        include '..\..\KIT\LIB\K_MEM.INC'
        include '..\..\KIT\LIB\K_VGA.INC'
        include '..\..\KIT\LIB\K_KEYS.INC'
        include '..\..\KIT\LIB\K_TIME.INC'
        include '..\..\KIT\LIB\K_MATH.INC'
        include '..\..\KIT\LIB\K_TEXT.INC'
        include '..\..\KIT\LIB\K_SPK.INC'
        include '..\..\KIT\LIB\K_FONT.INC' ; the good letters (FNT_*)
