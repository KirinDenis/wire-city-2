; ============================================================================
;  MANDEL.ASM - Lesson 1F. ONLY THE PALETTE MOVES.
;
;      FASM MANDEL.ASM MANDEL.COM
;
;      SPACE         stop the colours, and start them again
;      LEFT / RIGHT  turn them slower, faster, the other way
;      R             draw the whole picture again - and time it again
;      ESC           back to DOS
;
;  A DEBT PAID. Lesson 1E's nozzle burned yellow, orange, red, and the
;  lesson never said how: GLOW rewrote one entry of the palette, and not one
;  pixel. This lesson is that trick, the classic way - a fractal, drawn
;  once, slowly, and then set in motion by the palette alone.
;
;  THE PICTURE: the Mandelbrot set. For every pixel, a point c of the plane;
;  start at z = 0 and repeat z = z*z + c. Some points run away to infinity,
;  some never do. The pixel's number comes from HOW MANY STEPS it took to
;  run away - past a distance of 2 it never comes back: n steps, colour
;  n*4 round the 128 that turn, so the rings round the set are narrow. A
;  point still home after 128 steps is taken as one that never leaves:
;  number 0, black, the one colour the turning never touches.
;
;      z = x + iy:   x' = x*x - y*y + cx       y' = 2*x*y + cy
;      away when     x*x + y*y > 4
;
;  THE NUMBERS ARE 4.12 FIXED POINT: a word, 12 bits of fraction - 4096 is
;  one - and four of whole number and sign, -8 to +8. A square has 24 bits
;  of fraction and does not fit a word: IMUL leaves it in DX:AX, the test
;  for 4 reads the high word, and a shift right by 12 across both words
;  brings it back - lesson 1E's double words, in every step.
;
;  THE PHYSICAL FACT THIS LESSON HANDS OVER:
;
;      A PIXEL IS A NUMBER, NOT A COLOUR. Between video memory and the
;      screen stands the DAC: 256 entries of red, green and blue, six bits
;      each, read for every pixel as the beam draws it, seventy times a
;      second. Write three bytes to port 3C9h, and every pixel that holds
;      that number changes colour at once - in the next frame, with no
;      pixel touched. The picture costs seconds and sixty four thousand
;      writes; turning all its colours costs 385 OUTs.
;
;  WHAT IS BORROWED FROM THE ENGINE: ENGINE\E_8086.INC alone - it keeps FASM
;  inside the 8086 instruction set. Everything else is here.
;
;  Owlos - legacy software modernization - https://owlos.sk
; ============================================================================
MAXIT   = 128                 ; steps before a point counts as home
CYC     = 128                 ; colours 1..128 turn; 0 (home) never does
XSTART  = -10240              ; the left edge: -2.5 in 4.12
XSTEP   = 45                  ; a pixel across: 3.5/320 of the plane
YSTEP   = 54                  ; a pixel down: 1.2 times XSTEP - mode 13h's
                              ;  pixels are taller than they are wide
TURNS   = 1000                ; palette turns timed against the picture
WHITE   = 255                 ; the words' colour, never turned

format binary as 'com'
        org 100h

        include '..\..\ENGINE\E_8086.INC'

START:  cld                     ; LODSB walks up
        mov  ax,0013h           ; VGA 320x200, 256 colours
        int  10h
        call MKRAMP             ; the 128 colours, made from five
        mov  dx,3C8h            ; DAC 255: white, for the words
        mov  al,WHITE
        out  dx,al
        inc  dx
        mov  al,63
        out  dx,al
        out  dx,al
        out  dx,al

AGAIN:  mov  word [phase],0     ; the colours where they start
        call SPINPAL            ; written into DAC 1..128
        call DRAW               ; the picture - timed, into dticks
        call TIMEPAL            ; a thousand palette turns - timed
        call WORDS              ; the two numbers, on the screen

; ---- one frame: wait for the beam, turn the colours, read a key -------------
FRAME:  call WAITVR             ; the beam is going back up: no tearing
        cmp  byte [run],0       ; stopped?
        je   .keys
        mov  ax,[spd]           ; AX = the turn a frame
        add  ax,[phase]         ; AX = phase + spd
        and  ax,CYC-1           ; AX mod 128: AND, because 128 is 2^7
        mov  [phase],ax         ; phase = it
        call SPINPAL            ; 385 OUTs - and the whole picture moves
.keys:  mov  ah,1               ; a key waiting?
        int  16h
        jz   FRAME              ;   no
        xor  ah,ah              ; take it: AL = ASCII, AH = scan code
        int  16h
        cmp  al,27              ; ESC?
        je   QUIT
        cmp  al,' '             ; SPACE: stop, or go
        jne  .nr
        xor  byte [run],1       ; run = 1 - run
        jmp  FRAME
.nr:    and  al,0DFh            ; lower case to upper
        cmp  al,'R'             ; R: the picture again
        je   AGAIN
        cmp  ah,4Bh             ; LEFT
        jne  .rt
        cmp  word [spd],-4      ; as far as it goes?
        jle  FRAME
        dec  word [spd]         ; spd--
        jmp  FRAME
.rt:    cmp  ah,4Dh             ; RIGHT
        jne  FRAME
        cmp  word [spd],4
        jge  FRAME
        inc  word [spd]         ; spd++
        jmp  FRAME

QUIT:   mov  ax,0003h           ; text mode again
        int  10h
        mov  ax,4C00h           ; and back to DOS
        int  21h

; ---- DRAW: every pixel's number, and the time it took -----------------------
;  The set is its own reflection in the x axis: row r and row 199-r hold the
;  same numbers, so only the top hundred rows are worked out. cy for row r
;  is (r - 100) * YSTEP + YSTEP/2 - half a step off, so the rows mirror
;  exactly. In C:
;      for (r = 0; r < 100; r++) {
;          cy = (r - 100) * YSTEP + YSTEP / 2;
;          for (c = 0, cx = XSTART; c < 320; c++, cx += XSTEP)
;              screen[r][c] = screen[199 - r][c] = steps(cx, cy);
;      }
DRAW:   call TICKS              ; AX = the BIOS clock now
        mov  [t0],ax            ; t0 = it
        mov  ax,0A000h          ; ES = the screen: we watch it fill
        mov  es,ax
        mov  word [row],0       ; r = 0
.r:     mov  ax,[row]           ; AX = r
        sub  ax,100             ; AX = r - 100
        mov  bx,YSTEP           ; BX = the step down
        imul bx                 ; AX = (r - 100) * YSTEP: a word, |AX| < 5400
        add  ax,YSTEP/2         ; AX += half a step
        mov  [cyv],ax           ; cy = it
        mov  ax,[row]           ; DI = r * 320: the row's first byte
        mov  bx,320
        mul  bx                 ; AX = r * 320 (DX = 0: r < 100)
        mov  di,ax              ; DI = it
        mov  ax,199             ; AX = 199
        sub  ax,[row]           ; AX = 199 - r: the mirror row
        mul  bx                 ; AX = (199 - r) * 320
        mov  [mrow],ax          ; mrow = its first byte
        mov  word [cxv],XSTART  ; cx = the left edge
        mov  word [col],0       ; c = 0
.c:     call STEPS              ; AL = this point's number
        mov  [es:di],al         ; the pixel...
        mov  bx,[mrow]          ; BX = the mirror row's start
        add  bx,[col]           ; BX += c
        mov  [es:bx],al         ; ...and its reflection
        inc  di                 ; the next pixel
        add  word [cxv],XSTEP   ; cx += a step across
        inc  word [col]         ; c++
        cmp  word [col],320     ; the whole row?
        jb   .c
        mov  ah,1               ; ESC pressed while it draws?
        int  16h
        jz   .nk
        cmp  al,27
        jne  .nk
        jmp  QUIT               ;   then go - a slow picture must not trap you
.nk:    inc  word [row]         ; r++
        cmp  word [row],100     ; the top half done?
        jb   .r
        call TICKS              ; AX = the clock now
        sub  ax,[t0]            ; AX = how many ticks the picture took
        mov  [dticks],ax        ; dticks = it
        ret

; ---- STEPS: AL = how many steps the point (cxv, cyv) took to run away -------
;  x lives in SI and y in BX - DI is the pixel, and CL is wanted for the
;  shifts - so the count of steps lives in BP.
STEPS:  push di                 ; keep the pixel
        xor  si,si              ; x = 0
        xor  bx,bx              ; y = 0
        mov  bp,1               ; n = 1: the first step
.it:    mov  ax,si              ; AX = x
        imul si                 ; DX:AX = x*x, 24 bits of fraction
        mov  [x2l],ax           ; kept: the low word...
        mov  [x2h],dx           ; ...and the high
        mov  ax,bx              ; AX = y
        imul bx                 ; DX:AX = y*y
        mov  [y2l],ax           ; kept
        mov  [y2h],dx
        add  ax,[x2l]           ; DX:AX = x*x + y*y: the low words...
        adc  dx,[x2h]           ; ...and the high, with the low's carry
        cmp  dx,1024            ; past 4? 4 << 24 is 1024 << 16: the high
        jae  .away              ;  word alone says it. Yes: it ran away
        mov  ax,si              ; ---- y = 2*x*y + cy ----
        imul bx                 ; DX:AX = x*y, 24 bits of fraction
        mov  cl,11              ; *2 and >>12 is >>11:
        shr  ax,cl              ;   the low word's top 5 bits come down,
        mov  cl,5
        shl  dx,cl              ;   the high word's low 11 go up,
        or   ax,dx              ;   and together they are the word
        add  ax,[cyv]           ; AX += cy
        mov  bx,ax              ; y = it
        mov  ax,[x2l]           ; ---- x = x*x - y*y + cx ----
        mov  dx,[x2h]           ; DX:AX = x*x
        sub  ax,[y2l]           ; DX:AX -= y*y: the low words...
        sbb  dx,[y2h]           ; ...and the high, with the low's borrow
        mov  cl,12              ; >>12 across both words:
        shr  ax,cl
        mov  cl,4
        shl  dx,cl
        or   ax,dx              ; AX = x*x - y*y, 12 bits of fraction again
        add  ax,[cxv]           ; AX += cx
        mov  si,ax              ; x = it
        inc  bp                 ; n++
        cmp  bp,MAXIT           ; still home after 128 steps?
        jbe  .it                ;   not yet: another step
        xor  ax,ax              ;   yes: number 0 - it never leaves
        pop  di
        ret
.away:  mov  ax,bp              ; AX = n, the steps it took
        shl  ax,1
        shl  ax,1               ; AX = n*4: four colours of the ramp a step,
                                ;  so the rings round the set are narrow
        and  ax,CYC-1           ; round the ramp: AND, 128 is 2^7
        inc  ax                 ; AX = 1..128: never 0, the colour of home
        pop  di
        ret

; ---- SPINPAL: DAC 1..128 = the ramp, turned by [phase] ----------------------
;  Port 3C8h takes the first entry's number; then 3C9h takes red, green,
;  blue, red, green, blue... and the DAC steps on by itself after each
;  three. One OUT for the index, 384 for the colours: 385 in all.
;  In C:
;      outp(0x3C8, 1);
;      for (k = 0; k < 128; k++) {
;          i = (k + phase) & 127;
;          outp(0x3C9, ramp[i].r); outp(0x3C9, ramp[i].g); outp(0x3C9, ramp[i].b);
;      }
SPINPAL:
        mov  dx,3C8h            ; DX = the DAC's write index
        mov  al,1               ; from entry 1
        out  dx,al
        inc  dx                 ; DX = 3C9h, the DAC's data
        mov  bx,[phase]         ; BX = the ramp's colour that goes first
        mov  cx,CYC             ; CX = 128 entries
.e:     and  bx,CYC-1           ; BX mod 128: round the ramp
        mov  si,bx              ; SI = BX
        add  si,si              ; SI = BX*2
        add  si,bx              ; SI = BX*3: three bytes a colour
        mov  al,[RAMP+si]       ; red
        out  dx,al
        mov  al,[RAMP+si+1]     ; green
        out  dx,al
        mov  al,[RAMP+si+2]     ; blue
        out  dx,al
        inc  bx                 ; the next colour of the ramp
        loop .e
        ret

; ---- TIMEPAL: a thousand palette turns, timed by the same clock -------------
;  No waiting for the beam here: the OUTs as fast as they go. The picture
;  does not change - each turn writes the colours back where they were.
TIMEPAL:
        call TICKS              ; AX = the clock
        mov  [t0],ax
        mov  word [cnt],TURNS   ; a thousand
.t:     call SPINPAL            ; 385 OUTs
        dec  word [cnt]
        jnz  .t
        call TICKS
        sub  ax,[t0]            ; AX = ticks for a thousand turns
        mov  [pticks],ax        ; pticks = it
        ret

; ---- TICKS: AX = the BIOS clock, 0040:006C, 18.2 ticks a second -------------
TICKS:  push es
        mov  ax,40h             ; ES = the BIOS data area
        mov  es,ax
        mov  ax,[es:6Ch]        ; AX = the low word of the tick count
        pop  es
        ret

; ---- MKRAMP: 128 colours, a straight line between each two of five ---------
;  Four bands of 32: black to blue, blue to ice, ice to amber, amber to
;  black - and black meets black, so the ramp has no seam when it turns.
;  Each value is a + (b - a) * f / 32, f = 0..31: lesson 0F's straight
;  line, once for red, once for green, once for blue.
MKRAMP: xor  di,di              ; DI = the byte of RAMP being made
        xor  bx,bx              ; BX = the band's first key colour, *3
.band:  xor  dx,dx              ; DX = f, 0..31
.f:     xor  si,si              ; SI = the channel: red, green, blue
.ch:    mov  al,[KEYS+bx+si+3]  ; AL = the band's end, b
        cbw                     ; AX = b
        mov  cx,ax              ; CX = b
        mov  al,[KEYS+bx+si]    ; AL = the band's start, a
        cbw                     ; AX = a
        sub  cx,ax              ; CX = b - a
        push ax                 ; keep a
        mov  ax,cx              ; AX = b - a
        push dx                 ; IMUL writes DX
        imul dx                 ; AX = (b - a) * f: a word, |..| < 64*32
        pop  dx
        mov  cl,5               ; CL = 5
        sar  ax,cl              ; AX = /32, keeping the sign
        pop  cx                 ; CX = a
        add  ax,cx              ; AX = a + (b - a) * f / 32
        mov  [RAMP+di],al       ; the byte
        inc  di
        inc  si                 ; the next channel
        cmp  si,3
        jb   .ch
        inc  dx                 ; f++
        cmp  dx,32
        jb   .f
        add  bx,3               ; the next band
        cmp  bx,12              ; four bands?
        jb   .band
        ret

; ---- WORDS: the two times, on a black band at the foot ----------------------
WORDS:  mov  ax,0A000h          ; ES = the screen
        mov  es,ax
        mov  di,182*320         ; rows 182..199: black
        mov  cx,18*320/2        ; CX = their words
        xor  ax,ax              ; AX = 0: colour 0, twice
        rep  stosw
        mov  ax,[dticks]        ; "THE PICTURE: nnnn TICKS"
        mov  di,LINE1+13
        call PUTNUM
        mov  si,LINE1
        mov  ax,183             ; row 183
        call TXT
        mov  ax,[pticks]        ; "1000 PALETTE TURNS: nnnn TICKS"
        mov  di,LINE2+20
        call PUTNUM
        mov  si,LINE2
        mov  ax,192             ; row 192
        call TXT
        ret

; ---- PUTNUM: AX as four places, right-aligned, into the text at DI ---------
PUTNUM: mov  word [di],'  '     ; blanks first
        mov  word [di+2],'  '
        add  di,3               ; DI = the last place
        mov  bx,10              ; BX = 10
.d:     xor  dx,dx              ; DX:AX = n
        div  bx                 ; AX = n/10, DX = the last digit
        add  dl,'0'             ; DL = its character
        mov  [di],dl
        dec  di                 ; one place left
        or   ax,ax              ; more?
        jnz  .d
        ret

; ---- TXT: ASCIIZ at SI, row AX, from column 8, in the PC's ROM font --------
;  The glyphs at F000:FA6E, eight bytes each - lesson 1A's first letters.
TXT:    mov  bx,320
        mul  bx                 ; AX = row * 320
        add  ax,8               ; AX += 8: column 8
        mov  di,ax              ; DI = the first cell's top-left
.ch:    lodsb                   ; AL = the next character
        or   al,al
        jz   .done
        push si
        xor  ah,ah
        mov  cl,3
        shl  ax,cl              ; AX = char * 8: its glyph
        mov  si,0FA6Eh
        add  si,ax              ; SI = F000:FA6E + char * 8
        push ds
        mov  ax,0F000h
        mov  ds,ax              ; DS = the ROM
        mov  cx,8               ; eight rows
        push di
.row:   lodsb                   ; AL = a row of bits
        mov  ah,al
        push cx
        mov  cx,8               ; eight columns
.px:    shl  ah,1               ; CF = the next pixel
        jnc  .np
        mov  byte [es:di],WHITE
.np:    inc  di
        loop .px
        add  di,320-8           ; the next row of the cell
        pop  cx
        loop .row
        pop  di
        pop  ds
        pop  si
        add  di,8               ; the next cell
        jmp  .ch
.done:  ret

; ---- WAITVR: the vertical retrace's start ----------------------------------
;  Bit 3 of port 3DAh is 1 while the beam flies back to the top. Wait for
;  it to end, then for the next to begin: the colours change between two
;  pictures, never in the middle of one.
WAITVR: mov  dx,3DAh
.w1:    in   al,dx
        test al,8
        jnz  .w1
.w2:    in   al,dx
        test al,8
        jz   .w2
        ret

; ---- the five key colours of the ramp, DAC values 0..63 ---------------------
KEYS    db  0, 0, 0             ; black
        db  4,10,44             ; deep blue
        db 44,63,63             ; ice
        db 63,40, 0             ; amber
        db  0, 0, 0             ; black again: the ramp closes on itself

LINE1   db 'THE PICTURE:     0 TICKS',0
LINE2   db '1000 PALETTE TURNS:     0 TICKS',0

; ---- the state ---------------------------------------------------------------
phase   dw 0                    ; the ramp's colour that DAC 1 shows
spd     dw 1                    ; the turn a frame, -4..4
run     db 1                    ; 1 turning, 0 stopped
row     dw 0                    ; DRAW: r
col     dw 0                    ;  c
mrow    dw 0                    ;  the mirror row's first byte
cxv     dw 0                    ; the point: cx...
cyv     dw 0                    ;  ...and cy
x2l     dw 0                    ; x*x, a double word
x2h     dw 0
y2l     dw 0                    ; y*y, a double word
y2h     dw 0
t0      dw 0                    ; a clock reading
dticks  dw 0                    ; the picture's ticks
pticks  dw 0                    ; a thousand turns' ticks
cnt     dw 0                    ; TIMEPAL's count
RAMP    db CYC*3 dup(0)         ; 128 colours, three bytes each
