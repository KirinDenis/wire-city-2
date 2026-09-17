; ============================================================================
;  DRAW8.INC - the small routines lesson 8 leans on.
;
;  Lesson 7's toolbox, one tool richer: PutB prints a byte as two hex
;  digits, because this lesson's first frame prints BYTES OF CODE - the
;  program reading its own instruction off the same memory its data lives
;  in. Everything writes through ES:DI; the caller has already pointed ES
;  at whichever screen it means.
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

; ---- the byte in AL, as two hex digits -------------------------------------
;  Lesson 2 wrote a whole hex viewer; this is its heart in eight lines. A
;  nibble is 0..15: below ten it is a digit, from ten it is a letter, and
;  the seven is the gap between '9' and 'A' in the ASCII table.
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
        jbe  .put               ;   yes
        add  al, 7              ;   no: AL += 7, hop the gap: ':' becomes 'A'
.put:   call PutC               ; putc(AL)
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

; ---- wait for a key ---------------------------------------------------------
;  In C:   int key(void) { return get_key(); }   - waits
Key:    mov  ah, 0              ; AH = 0: BIOS 16h, service 0 - wait for a key
        int  16h                ; AL = the character, AH = the scan code
        ret                     ; return

; A fifth of a second, off the BIOS tick at 0040:006C - the same clock the
; whole PC counts on, eighteen and a bit times a second. (It wraps at
; midnight; nothing here is running at midnight.)
;  In C:   int t = bios_tick() + 4;  while (bios_tick() < t) ;   - a fifth of a second
Hold:   push es                 ; keep ES
        push dx                 ; keep DX: frame 4 keeps its debt in DX across this
        mov  ax, 0040h          ; AX = 0040h, the BIOS data segment
        mov  es, ax             ; ES = 0040h
        mov  bx, [es:6Ch]       ; BX = the tick count at 0040:006C
        add  bx, 4              ; BX = t = tick + 4
.wait:  mov  ax, [es:6Ch]       ; AX = the tick now
        cmp  ax, bx             ; tick < t ?
        jb   .wait              ;   yes: keep waiting
        pop  dx                 ; DX back
        pop  es                 ; ES back
        ret                     ; return
