; ============================================================================
;  DRAW.INC - what lessons 3, 5 and 5B already built, in one file.
;
;  Nothing in here is new. SINQ is lesson 5's quarter-table sine, Plot is
;  lesson 5B's pixel with its address built out of shifts, Clear and Key are
;  from lesson 3, and Retr is the retrace wait. They are in a file so that
;  lesson 6 can get straight to the new idea - which is exactly what the
;  ENGINE folder in this repository is for.
;
;  Plot works on vx, vy and col, which the program that includes this one
;  declares. That is the contract, and it is the whole of it.
; ============================================================================

; ---- the sine table, folded into four quarters (lesson 5) ------------------
;  IT EATS SI. Every caller has to know that, and this is where it is said.
SINQ:   and  ax, 255            ; the angle, mod 256 - a whole circle
        mov  bx, ax
        mov  cl, 6
        shr  bx, cl             ; bx = which quarter, 0..3
        and  ax, 63             ; ax = how far into it, 0..63
        cmp  bx, 1
        je   .back
        cmp  bx, 3
        je   .back
        jmp  .have
.back:  mov  dx, 64             ; quarters 1 and 3 read the table backwards
        sub  dx, ax
        mov  ax, dx
.have:  add  ax, ax             ; two bytes to an entry
        mov  si, ax
        mov  ax, [SINT+si]
        cmp  bx, 2
        jb   .done
        neg  ax                 ; and the bottom half is negative
.done:  ret

; ---- one pixel at vx, vy in colour col, and nothing off the screen ---------
;  The address is row*320 + column, and 320 is 256 + 64 - so it is two
;  shifts and an add, not a MUL (lesson 5B).
Plot:   mov  ax, [vy]
        cmp  ax, 0
        jl   .out
        cmp  ax, H
        jge  .out
        mov  bx, [vx]
        cmp  bx, 0
        jl   .out
        cmp  bx, W
        jge  .out
        mov  dx, ax
        mov  cl, 8
        shl  ax, cl             ; y * 256
        mov  cl, 6
        shl  dx, cl             ; y * 64
        add  ax, dx             ; y * 320
        add  ax, bx             ; + x
        mov  di, ax
        mov  al, [col]
        stosb
.out:   ret

; ---- the whole screen, black (lesson 3) ------------------------------------
Clear:  xor  di, di
        xor  ax, ax
        mov  cx, W*H/2          ; words, because STOSW writes two bytes
        rep  stosw
        ret

; ---- wait for a key, and wait for the beam to go home -----------------------
Key:    mov  ah, 0
        int  16h
        ret

Retr:   mov  dx, 3DAh
.a:     in   al, dx             ; first make sure we are not already inside
        test al, 8              ; one, or we would go early and gain nothing
        jnz  .a
.b:     in   al, dx
        test al, 8
        jz   .b
        ret
