; ============================================================================
;  DRAW11.INC - the small routines lesson 11 leans on.
;
;  Lesson 10's toolbox, trimmed to this lesson's needs, plus PutB from
;  lesson 8 - the byte as two hex digits, because tonight the screen will
;  be full of scan codes. Two newcomers: KeyFlush empties the BIOS
;  keyboard buffer (frame one talks to the PORT, and the BIOS quietly
;  queues every key it hears - frame two must not start pre-typed), and
;  Box stamps the 12-by-12 square the finale drives with the arrows.
; ============================================================================

attr    db 07h                  ; the colour the next character is written in

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

; ---- the byte in AL, as two hex digits (lesson 8, byte for byte) -----------
;  A nibble is 0..15: below ten it is a digit, from ten a letter, and the
;  seven is the gap between '9' and 'A' in the ASCII table.
;  In C:
;
;      void put_hex(int b) { digit(b >> 4);  digit(b & 15); }
;      void digit(int n)   { n += '0';  if (n > '9') n += 7;  putc(n); }
PutB:   push ax                 ; keep b
        push cx                 ; keep CX
        mov  cl, 4              ; CL = 4
        shr  al, cl             ; AL = b >> 4: the high nibble first...
        call .dig               ; digit(b >> 4)
        pop  cx                 ; CX back
        pop  ax                 ; AL = b
        push ax                 ; keep b
        and  al, 0Fh            ; AL = b & 15: ...then the low one
        call .dig               ; digit(b & 15)
        pop  ax                 ; AL = b
        ret                     ; return
.dig:   add  al, '0'            ; AL = n + '0'
        cmp  al, '9'            ; a digit ?
        jbe  PutC               ;   yes: putc(AL), and its RET is ours
        add  al, 7              ;   no: AL += 7, '9'+1 is ':', not 'A' - hop the gap
        jmp  PutC               ; putc(AL)

; ---- the whole text screen, blank -------------------------------------------
;  In C:   for (i = 0; i < 80*25; i++) text[i] = 0x0720;    - a space, grey on black
TClear: xor  di, di             ; DI = 0: the top-left cell
        mov  cx, 80*25          ; CX = 2000 cells
        mov  ax, 0720h          ; AX = 0720h: a space, in grey on black
        rep  stosw              ; while (cx--) *es:di++ = ax
        ret                     ; return

; ---- no cursor, so nothing blinks through the explanation ------------------
;  In C:   cursor_off();   - BIOS 10h, service 1: set the cursor's shape
TextOff:
        mov  ah, 1              ; AH = 1: set cursor shape
        mov  cx, 2000h          ; CX = 2000h: bit 5 of CH turns it off
        int  10h                ; cursor_off()
        ret                     ; return

; ---- wait for a key ---------------------------------------------------------
;  In C:   int key(void) { return get_key(); }   - waits
Key:    mov  ah, 0              ; AH = 0: BIOS 16h, service 0 - wait for a key
        int  16h                ; AL = the character, AH = the scan code
        ret                     ; return

; ---- empty the BIOS keyboard buffer -----------------------------------------
;  AH=1 asks WITHOUT waiting: is anything queued? AH=0 takes one. Loop
;  until the answer is no. Frame one polls the port while the BIOS, on
;  its interrupt, queues the very same keys - leave them and frame two
;  reads a conversation that already happened.
;  In C:   while (key_waiting()) get_key();
KeyFlush:
        mov  ah, 1              ; AH = 1: is a key waiting?
        int  16h                ; ZF set = no
        jz   .done              ;   no: return
        mov  ah, 0              ; AH = 0: take it
        int  16h                ; get_key()
        jmp  KeyFlush           ; and ask again
.done:  ret                     ; return

; ---- wait for the beam to fly home (lesson 10, byte for byte) ---------------
;  Port 3DAh, bit 3: the VERTICAL RETRACE - wipe and redraw NOW and the
;  eye never sees the half-drawn picture.
;  In C:   while ( inp(0x3DA) & 8) ;   while (!(inp(0x3DA) & 8)) ;
Vsync:  push ax                 ; keep AX and DX for the caller
        push dx                 ; keep DX
        mov  dx, 3DAh           ; DX = 3DAh, the VGA status port
.out:   in   al, dx             ; AL = inp(0x3DA)
        test al, 8              ; bit 3 = the beam is in vertical retrace
        jnz  .out               ; while (retrace) ;   - wait it out
.in:    in   al, dx             ; AL = inp(0x3DA)
        test al, 8              ; bit 3 again
        jz   .in                ; while (!retrace) ;  - wait for the next
        pop  dx                 ; DX back
        pop  ax                 ; AX back
        ret                     ; return

; ---- five seconds, off the BIOS tick at 0040:006C ---------------------------
;  Eighteen and a bit ticks a second; 91 of them is five seconds. The
;  frame is BUSY on purpose: the viewer types into the silence, and the
;  buffer remembers for him.
;  In C:   int t = bios_tick() + 91;  while (bios_tick() < t) ;   - 91 ticks: five seconds
Hold5:  push es                 ; keep ES
        mov  ax, 0040h          ; AX = 0040h, the BIOS data segment
        mov  es, ax             ; ES = 0040h
        mov  bx, [es:6Ch]       ; BX = the tick count at 0040:006C
        add  bx, 91             ; BX = t = tick + 91: five seconds at 18.2 a second
.wait:  mov  ax, [es:6Ch]       ; AX = the tick now
        cmp  ax, bx             ; tick < t ?
        jb   .wait              ;   yes: keep waiting
        pop  es                 ; ES back
        ret                     ; return

; ---- the hint at the bottom of a text frame --------------------------------
;  In C:   attr = 8;  puts_at(23, 34, "- any key -");  attr = NORM;
Bottom: mov  si, t_key          ; SI = the string
        mov  di, 23*ROW + 34*2  ; DI = row 23, column 34
        mov  byte [attr], 08h   ; attr = 8, dark grey
        call PutS               ; puts()
        mov  byte [attr], NORM  ; attr = NORM
        ret                     ; return

; ---- Box: the 12-by-12 square at ([bxp],[byp]), filled with AL --------------
;  Offset = y * 320 + x: lesson 7's formula, one more time. Painted black
;  it is the eraser; painted white it is the player.
;  In C:
;
;      void box(int c)
;      {
;          unsigned char *at = screen + byp * 320 + bxp;
;          for (int r = 0; r < 12; r++, at += 320) memset(at, c, 12);
;      }
Box:    push ax                 ; keep c
        mov  ax, [byp]          ; AX = byp
        mov  bx, W              ; BX = 320
        mul  bx                 ; AX = byp * 320
        add  ax, [bxp]          ; AX = byp * 320 + bxp
        mov  di, ax             ; DI = at, the top-left corner
        pop  ax                 ; AL = c
        mov  dx, 12             ; DX = 12 rows...
.row:   mov  cx, 12             ; CX = 12: ...of twelve pixels
        push di                 ; keep the row's start
        rep  stosb              ; while (cx--) *es:di++ = al
        pop  di                 ; DI = the row's start again
        add  di, W              ; at += 320: the next row starts one fold later
        dec  dx                 ; rows--
        jnz  .row               ; while (rows)
        ret                     ; return
