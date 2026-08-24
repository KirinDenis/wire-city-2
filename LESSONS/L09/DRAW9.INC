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

; ---- the byte in AL, as two hex digits -------------------------------------
;  A nibble is 0..15: below ten a digit, from ten a letter, and the seven
;  is the gap between '9' and 'A' in the ASCII table (lesson 8's PutB).
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

; ---- no cursor, so nothing blinks through the frames -----------------------
TextOff:
        mov  ah, 1
        mov  cx, 2000h          ; bit 5 of CH turns it off
        int  10h
        ret

; ---- wait for a key ---------------------------------------------------------
Key:    mov  ah, 0
        int  16h
        ret
