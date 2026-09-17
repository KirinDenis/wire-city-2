; ============================================================================
;  DRAW7.INC - the small routines lesson 7 leans on.
;
;  Two screens, and the same idea twice. The text screen at B800 holds TWO
;  bytes a cell - the character and its colour - so a row of it is 160 bytes
;  and not 80. The graphics screen at A000 holds ONE byte a pixel, so a row
;  is 320. Both fold; only the number differs.
;
;  Everything here writes through ES:DI, so whoever calls it has already
;  pointed ES at the screen it means.
; ============================================================================

attr    db 07h                  ; the colour the next character is written in
rows    dw 0                    ; how many rows a box or a frame has
lsave   dw 0

; ---- one character at ES:DI, in [attr], and DI moves on --------------------
;  In C:   *text++ = (attr << 8) | AL;    - a cell is two bytes: the character, its colour
PutC:   mov  ah, [attr]         ; AH = attr: the colour, above the character in AL
        stosw                   ; *es:di++ = AX: character AND colour, in one instruction
        ret                     ; return

; ---- an asciiz string at ES:DI ---------------------------------------------
;  In C:   while (*s) *text++ = (attr << 8) | *s++;
PutS:   lodsb                   ; AL = *si++
        or   al, al             ; the end of the string?
        jz   .done              ;   yes: return
        mov  ah, [attr]         ; AH = attr
        stosw                   ; *es:di++ = AX
        jmp  PutS               ; the next character
.done:  ret                     ; return

; ---- a number 0..99, right-aligned in two characters -----------------------
;  In C:
;
;      void put_num(int n)                  /* 0..99, right-aligned in two */
;      {
;          int tens = n / 10, units = n % 10;
;          putc(tens ? '0' + tens : ' ');   /* no leading zero: " 9", not "09" */
;          putc('0' + units);
;      }
PutN:   xor  ah, ah             ; AX = n (AL held it; AH cleared)
        mov  bl, 10             ; BL = 10
        div  bl                 ; AL = n / 10 = tens, AH = n % 10 = units (lesson 4's trick)
        mov  bh, ah             ; BH = units: kept, the next PutC eats AH
        or   al, al             ; tens == 0 ?
        jz   .space             ;   yes: a space, no leading zero
        add  al, '0'            ;   no:  AL = '0' + tens
        jmp  .put               ; over the space
.space: mov  al, ' '            ; AL = ' '
.put:   call PutC               ; putc(AL)
        mov  al, bh             ; AL = units
        add  al, '0'            ; AL = '0' + units
        call PutC               ; putc(AL)
        ret                     ; return

; ---- the whole text screen, blank -------------------------------------------
;  In C:   for (i = 0; i < 80*25; i++) text[i] = 0x0720;    - a space, grey on black
TClear: xor  di, di             ; DI = 0: the top-left cell
        mov  cx, 80*25          ; CX = 2000 cells
        mov  ax, 0720h          ; AX = 0720h: a space, in grey on black
        rep  stosw              ; while (cx--) *es:di++ = ax
        ret                     ; return

; ---- the whole graphics screen, black --------------------------------------
;  In C:   memset(screen, 0, 64000);
GClear: xor  di, di             ; DI = 0: the top-left pixel
        xor  ax, ax             ; AX = 0: two black pixels
        mov  cx, W*H/2          ; CX = 32000 words, because STOSW writes two
        rep  stosw              ; while (cx--) *es:di++ = ax
        ret                     ; return

; ---- no cursor, so nothing blinks through the explanation ------------------
;  In C:   cursor_off();   - BIOS 10h, service 1: set the cursor's shape
TextOff:
        mov  ah, 1              ; AH = 1: set cursor shape
        mov  cx, 2000h          ; CX = 2000h: bit 5 of CH turns it off
        int  10h                ; cursor_off()
        ret                     ; return

; ---- wait for a key, and wait a moment -------------------------------------
;  In C:   int key(void) { return get_key(); }   - waits
Key:    mov  ah, 0              ; AH = 0: BIOS 16h, service 0 - wait for a key
        int  16h                ; AL = the character, AH = the scan code
        ret                     ; return

; A fifth of a second, off the BIOS tick at 0040:006C - the same clock the
; whole PC counts on, eighteen and a bit times a second. (It wraps at
; midnight; nothing here is running at midnight.)
;  In C:   int t = bios_tick() + 4;  while (bios_tick() < t) ;   - a fifth of a second
Hold:   push es                 ; keep ES
        mov  ax, 0040h          ; AX = 0040h, the BIOS data segment
        mov  es, ax             ; ES = 0040h
        mov  bx, [es:6Ch]       ; BX = the tick count at 0040:006C
        add  bx, 4              ; BX = t = tick + 4
.wait:  mov  ax, [es:6Ch]       ; AX = the tick now
        cmp  ax, bx             ; tick < t ?
        jb   .wait              ;   yes: keep waiting
        pop  es                 ; ES back
        ret                     ; return

; ---- a horizontal line: lx, ly, llen, col ----------------------------------
;  THE POINT OF THE LESSON. The bytes of this line are NEIGHBOURS, so the
;  whole run is one REP STOSB - the processor writes it without the loop
;  ever coming back to us.
;  In C:   memset(screen + ly * 320 + lx, col, llen);   - the bytes are NEIGHBOURS
HLine:  mov  ax, [ly]           ; AX = ly
        mov  bx, W              ; BX = 320
        mul  bx                 ; AX = ly * 320 ...
        add  ax, [lx]           ; AX = ly * 320 + lx: ... + x
        mov  di, ax             ; DI = at
        mov  cx, [llen]         ; CX = llen pixels
        mov  al, [col]          ; AL = col
        rep  stosb              ; while (cx--) *es:di++ = al: one instruction, whole line
        ret                     ; return

; ---- a vertical line: lx, ly, llen, col ------------------------------------
;  The same number of pixels, and never neighbours: each is 320 bytes past
;  the last. So there is no REP to be had - it is a loop, and an ADD.
;  In C:   for (at = ly * 320 + lx, n = llen; n--; at += 320) screen[at] = col;
VLine:  mov  ax, [ly]           ; AX = ly
        mov  bx, W              ; BX = 320
        mul  bx                 ; AX = ly * 320
        add  ax, [lx]           ; AX = ly * 320 + lx
        mov  di, ax             ; DI = at
        mov  cx, [llen]         ; CX = llen pixels
        mov  al, [col]          ; AL = col
.down:  mov  [es:di], al        ; screen[at] = col
        add  di, W              ; at += 320: the pixel below is 320 bytes further on
        loop .down              ; n-- ; while (n)
        ret                     ; return

; ---- a filled box: a horizontal line, done CX times ------------------------
;  In C:   for (rows = CX; rows--; ly++) hline();
Box:    mov  [rows], cx         ; rows = CX
.r:     call HLine              ; hline()
        inc  word [ly]          ; ly++
        dec  word [rows]        ; rows--
        jnz  .r                 ; while (rows)
        ret                     ; return

; ---- and a window is a box with four lines round it ------------------------
;  In C:
;
;      void frame(int rows)                 /* lx, ly, llen = the box    */
;      {
;          int top = ly, width = llen;
;          hline();                         /* the top                   */
;          ly = top + rows - 1;  hline();   /* the bottom                */
;          ly = top;  llen = rows;  vline();               /* the left  */
;          lx = lx + width - 1;   vline();                 /* the right */
;      }
Frame:  mov  [rows], cx         ; rows = CX
        mov  ax, [llen]         ; AX = llen
        mov  [lsave], ax        ; lsave = width
        call HLine              ; hline(): the top
        mov  bx, [ly]           ; BX = top
        mov  ax, bx             ; AX = top
        add  ax, [rows]         ; AX = top + rows
        dec  ax                 ; AX = top + rows - 1
        mov  [ly], ax           ; ly = AX
        call HLine              ; hline(): the bottom
        mov  [ly], bx           ; ly = top: back up to the top for the sides
        mov  ax, [rows]         ; AX = rows
        mov  [llen], ax         ; llen = rows
        call VLine              ; vline(): the left
        mov  ax, [lx]           ; AX = lx
        add  ax, [lsave]        ; AX = lx + width
        dec  ax                 ; AX = lx + width - 1
        mov  [lx], ax           ; lx = AX
        call VLine              ; vline(): the right
        ret                     ; return
