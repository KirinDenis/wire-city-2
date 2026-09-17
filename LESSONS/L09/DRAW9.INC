; ============================================================================
;  DRAW9.INC - the small routines lesson 9 leans on.
;
;  Lesson 8's toolbox with the graphics half left behind: this lesson
;  never leaves the text screen - the drama is in the CELLS, and B800 is
;  where cells can be read. PutB is here again, because printing bytes
;  sign by sign IS the lesson. Everything writes through ES:DI; the
;  caller has pointed ES at B800 once, in Boot.
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

; ---- the byte in AL, as two hex digits -------------------------------------
;  A nibble is 0..15: below ten a digit, from ten a letter, and the seven
;  is the gap between '9' and 'A' in the ASCII table (lesson 8's PutB).
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

; ---- no cursor, so nothing blinks through the frames -----------------------
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
