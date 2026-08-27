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

; ---- the byte in AL, as two hex digits (lesson 8, byte for byte) -----------
;  A nibble is 0..15: below ten it is a digit, from ten a letter, and the
;  seven is the gap between '9' and 'A' in the ASCII table.
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
        jbe  PutC
        add  al, 7              ; '9'+1 is ':', not 'A' - hop the gap
        jmp  PutC

; ---- the whole text screen, blank -------------------------------------------
TClear: xor  di, di
        mov  cx, 80*25
        mov  ax, 0720h          ; a space, in grey on black
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

; ---- empty the BIOS keyboard buffer -----------------------------------------
;  AH=1 asks WITHOUT waiting: is anything queued? AH=0 takes one. Loop
;  until the answer is no. Frame one polls the port while the BIOS, on
;  its interrupt, queues the very same keys - leave them and frame two
;  reads a conversation that already happened.
KeyFlush:
        mov  ah, 1
        int  16h
        jz   .done
        mov  ah, 0
        int  16h
        jmp  KeyFlush
.done:  ret

; ---- wait for the beam to fly home (lesson 10, byte for byte) ---------------
;  Port 3DAh, bit 3: the VERTICAL RETRACE - wipe and redraw NOW and the
;  eye never sees the half-drawn picture.
Vsync:  push ax
        push dx
        mov  dx, 3DAh
.out:   in   al, dx
        test al, 8
        jnz  .out
.in:    in   al, dx
        test al, 8
        jz   .in
        pop  dx
        pop  ax
        ret

; ---- five seconds, off the BIOS tick at 0040:006C ---------------------------
;  Eighteen and a bit ticks a second; 91 of them is five seconds. The
;  frame is BUSY on purpose: the viewer types into the silence, and the
;  buffer remembers for him.
Hold5:  push es
        mov  ax, 0040h
        mov  es, ax
        mov  bx, [es:6Ch]
        add  bx, 91
.wait:  mov  ax, [es:6Ch]
        cmp  ax, bx
        jb   .wait
        pop  es
        ret

; ---- the hint at the bottom of a text frame --------------------------------
Bottom: mov  si, t_key
        mov  di, 23*ROW + 34*2
        mov  byte [attr], 08h
        call PutS
        mov  byte [attr], NORM
        ret

; ---- Box: the 12-by-12 square at ([bxp],[byp]), filled with AL --------------
;  Offset = y * 320 + x: lesson 7's formula, one more time. Painted black
;  it is the eraser; painted white it is the player.
Box:    push ax
        mov  ax, [byp]
        mov  bx, W
        mul  bx                 ; y * 320...
        add  ax, [bxp]          ; ...+ x
        mov  di, ax
        pop  ax
        mov  dx, 12             ; twelve rows...
.row:   mov  cx, 12             ; ...of twelve pixels
        push di
        rep  stosb
        pop  di
        add  di, W              ; the next row starts one fold later
        dec  dx
        jnz  .row
        ret
