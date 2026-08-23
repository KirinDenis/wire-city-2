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
PutC:   mov  ah, [attr]
        stosw                   ; character AND colour, in one instruction
        ret

; ---- an asciiz string at ES:DI ---------------------------------------------
PutS:   lodsb
        or   al, al
        jz   .done
        mov  ah, [attr]
        stosw
        jmp  PutS
.done:  ret

; ---- a number 0..99, right-aligned in two characters -----------------------
PutN:   xor  ah, ah
        mov  bl, 10
        div  bl                 ; AL = tens, AH = units (lesson 4's trick)
        mov  bh, ah             ; keep the units, DIV has just eaten AH
        or   al, al
        jz   .space             ; no leading zero: a nine is " 9", not "09"
        add  al, '0'
        jmp  .put
.space: mov  al, ' '
.put:   call PutC
        mov  al, bh
        add  al, '0'
        call PutC
        ret

; ---- the byte in AL, as two hex digits -------------------------------------
;  Lesson 2 wrote a whole hex viewer; this is its heart in eight lines. A
;  nibble is 0..15: below ten it is a digit, from ten it is a letter, and
;  the seven is the gap between '9' and 'A' in the ASCII table.
PutB:   push ax
        push cx
        mov  cl, 4
        shr  al, cl             ; the high nibble first...
        call .dig
        pop  cx
        pop  ax
        push ax
        and  al, 0Fh            ; ...then the low one
        call .dig
        pop  ax
        ret
.dig:   add  al, '0'
        cmp  al, '9'
        jbe  .put
        add  al, 7              ; hop the gap: ':' becomes 'A'
.put:   call PutC
        ret

; ---- the whole text screen, blank -------------------------------------------
TClear: xor  di, di
        mov  cx, 80*25
        mov  ax, 0720h          ; a space, in grey on black
        rep  stosw
        ret

; ---- the whole graphics screen, black --------------------------------------
GClear: xor  di, di
        xor  ax, ax
        mov  cx, W*H/2          ; words, because STOSW writes two bytes
        rep  stosw
        ret

; ---- no cursor, so nothing blinks through the explanation ------------------
TextOff:
        mov  ah, 1
        mov  cx, 2000h          ; bit 5 of CH turns it off
        int  10h
        ret

; ---- wait for a key ---------------------------------------------------------
Key:    mov  ah, 0
        int  16h
        ret

; A fifth of a second, off the BIOS tick at 0040:006C - the same clock the
; whole PC counts on, eighteen and a bit times a second. (It wraps at
; midnight; nothing here is running at midnight.)
Hold:   push es
        push dx                 ; frame 4 keeps its debt in DX across this
        mov  ax, 0040h
        mov  es, ax
        mov  bx, [es:6Ch]
        add  bx, 4
.wait:  mov  ax, [es:6Ch]
        cmp  ax, bx
        jb   .wait
        pop  dx
        pop  es
        ret
