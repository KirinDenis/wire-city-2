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
;  In C:
;
;      int sinq(int a)                       /* sin(a) * 256, a in 256ths of a turn */
;      {
;          int q = (a & 255) >> 6;           /* which quarter, 0..3       */
;          int i = a & 63;                   /* how far into it           */
;          if (q == 1 || q == 3) i = 64 - i; /* odd quarters run backwards */
;          return q < 2 ? SINT[i] : -SINT[i];
;      }
SINQ:   and  ax, 255            ; a &= 255: the angle, mod 256 - a whole circle
        mov  bx, ax             ; BX = a
        mov  cl, 6              ; CL = 6
        shr  bx, cl             ; q = a >> 6: which quarter, 0..3
        and  ax, 63             ; i = a & 63: how far into it, 0..63
        cmp  bx, 1              ; q == 1 ?
        je   .back              ;   yes: backwards
        cmp  bx, 3              ; q == 3 ?
        je   .back              ;   yes: backwards
        jmp  .have              ; else: forwards
.back:  mov  dx, 64             ; DX = 64: quarters 1 and 3 read the table backwards
        sub  dx, ax             ; DX = 64 - i
        mov  ax, dx             ; i = 64 - i
.have:  add  ax, ax             ; AX = i * 2: two bytes to an entry
        mov  si, ax             ; SI = i * 2
        mov  ax, [SINT+si]      ; AX = SINT[i]
        cmp  bx, 2              ; q < 2 ?
        jb   .done              ;   yes: return SINT[i]
        neg  ax                 ; AX = -SINT[i]: and the bottom half is negative
.done:  ret                     ; return AX

; ---- one pixel at vx, vy in colour col, and nothing off the screen ---------
;  The address is row*320 + column, and 320 is 256 + 64 - so it is two
;  shifts and an add, not a MUL (lesson 5B).
;  In C:
;
;      void plot(void)
;      {
;          if (vy < 0 || vy >= H || vx < 0 || vx >= W) return;
;          screen[(vy << 8) + (vy << 6) + vx] = col;     /* vy * 320 + vx */
;      }
Plot:   mov  ax, [vy]           ; AX = vy
        cmp  ax, 0              ; vy < 0 ?
        jl   .out               ;   yes: return
        cmp  ax, H              ; vy >= 200 ?
        jge  .out               ;   yes: return
        mov  bx, [vx]           ; BX = vx
        cmp  bx, 0              ; vx < 0 ?
        jl   .out               ;   yes: return
        cmp  bx, W              ; vx >= 320 ?
        jge  .out               ;   yes: return
        mov  dx, ax             ; DX = vy
        mov  cl, 8              ; CL = 8
        shl  ax, cl             ; AX = vy << 8: y * 256
        mov  cl, 6              ; CL = 6
        shl  dx, cl             ; DX = vy << 6: y * 64
        add  ax, dx             ; AX = y * 320
        add  ax, bx             ; AX = y * 320 + x
        mov  di, ax             ; DI = the pixel
        mov  al, [col]          ; AL = col
        stosb                   ; screen[DI++] = col
.out:   ret                     ; return

; ---- the whole screen, black (lesson 3) ------------------------------------
;  In C:   memset(screen, 0, 64000);
Clear:  xor  di, di             ; DI = 0: the top left corner
        xor  ax, ax             ; AX = 0: black, twice
        mov  cx, W*H/2          ; CX = 32000 words, because STOSW writes two bytes
        rep  stosw              ; while (cx--) *es:di++ = ax
        ret                     ; return

; ---- wait for a key, and wait for the beam to go home -----------------------
;  In C:   int key(void) { return get_key(); }   - waits
Key:    mov  ah, 0              ; AH = 0: BIOS 16h, service 0 - wait for a key
        int  16h                ; AL = the character, AH = the scan code
        ret                     ; return

;  In C:   while (inp(0x3DA) & 8) ;  while (!(inp(0x3DA) & 8)) ;
Retr:   mov  dx, 3DAh           ; DX = 3DAh: the status port
.a:     in   al, dx             ; AL = inp(0x3DA): first make sure we are not already inside
        test al, 8              ; bit 3 up ?   one, or we would go early and gain nothing
        jnz  .a                 ;   yes: wait for it to drop
.b:     in   al, dx             ; AL = inp(0x3DA)
        test al, 8              ; bit 3 up ?
        jz   .b                 ;   no: wait for the retrace to begin
        ret                     ; return
