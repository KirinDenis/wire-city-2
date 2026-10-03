; ============================================================================
;  MATH.ASM - Lesson 4. The arithmetic underneath everything.
;
;      FASM MATH.ASM MATH.COM
;
;  Lesson 3 drew shapes and never once asked what a number costs. This one
;  does, and it starts where it has to: a program cannot even SHOW you a
;  number until it can divide.
;
;      1  the byte and the character   five is 05. "5" is 53. Not the same.
;      2  printing a number            divide by ten, keep the remainder
;      3  a ball, falling              acceleration and friction, in integers
;
;  WHY THE FIRST FRAME IS WHAT IT IS. Lesson 2 looked at 48 45 4C 4C 4F and
;  said: the letters ARE the bytes, lying in the file in the order you typed
;  them. This is the same fact from the other side. The NUMBER five is the
;  byte 05; the CHARACTER "5" is the byte 53. Put 05 into the text screen and
;  a club comes up, because that is what code 5 is in this font. Nobody is
;  converting anything for you, and nothing on this machine ever will.
;
;  Owlos - legacy software modernization - https://owlos.sk
; ============================================================================
format binary as 'com'
        org  100h

TEXT    = 0B800h                ; the text screen, from lesson 1
VGA     = 0A000h                ; and the graphics one
W       = 320
FLOOR   = 104                   ; the ball rests with its top here. See the
                                ; note beside the comparison - 8.8 signed runs
                                ; out at 127 pixels, and 104+16 fills the frame

; a cell on the text screen is TWO bytes - the character, then its colour -
; so the offset of row/col is (row*80 + col) * 2. Lesson 1's arithmetic with
; a different width and a stride of two.
CELL    = 2

        jmp  Boot               ; over the words and routines, to the boot

; ---- words --------------------------------------------------------------
t1a     db 'A byte holding the NUMBER five is 05.',0
t1b     db 'A byte holding the CHARACTER "5" is 53.',0
t1c     db 'this cell holds 5',0
t1d     db 'this one holds 53',0
t1e     db 'Nothing converts one into the other for you.',0

t2a     db 'Dividing 64000 by ten, over and over. The remainder is the digit:',0
tdiv    db '/ 10 =',0
trem    db 'remainder',0
t2b     db 'The digits fell out backwards - 0, 0, 0, 4, 6.',0
t2c     db 'Push them, pop them, and they come back as:',0
t2d     db 'Five digits, five divisions. Ten is not a power of two.',0

y       dw 0                    ; height, 8.8
v       dw 0                    ; speed, 8.8
x       dw 0                    ; sideways, whole pixels
n       dw 0                    ; what is left to divide
rem     dw 0                    ; the digit that just fell off
row     dw 0                    ; which line of the trace we are on


; ---- wait for anything -----------------------------------------------------
;  In C:   int key(void) { return get_key(); }   - waits
Key:    mov  ah, 0              ; AH = 0: BIOS 16h, service 0 - wait for a key
        int  16h                ; AL = the character
        ret                     ; return

; ---- a zero-terminated string to the text screen ---------------------------
;   SI = the text   DI = cell offset   BL = colour
;  In C:   while (*s) *cell++ = (colour << 8) | *s++;
Puts:   mov  ah, bl             ; AH = the colour, above the character in AL
.l:     lodsb                   ; AL = *s++
        or   al, al             ; the end of the string?
        jz   .done              ;   yes: return
        stosw                   ; *cell++ = AX: AL is the character, AH its colour, and DI
        jmp  .l                 ; the next character: steps on by two because a cell is two bytes
.done:  ret                     ; return

; ---- an unsigned number to the text screen, in decimal ----------------------
;   AX = the number   DI = cell offset   BL = colour
;
; THIS IS THE LESSON, so here it is worked out by hand before any code.
;
; Take a number apart by dividing it by ten. What falls off is the REMAINDER,
; and that is the last digit. What is left is the QUOTIENT, and that is
; everything still to come. Do it again until nothing is left:
;
;     64000 / 10 = 6400   remainder 0     <- the last digit
;      6400 / 10 =  640   remainder 0
;       640 / 10 =   64   remainder 0
;        64 / 10 =    6   remainder 4
;         6 / 10 =    0   remainder 6     <- the first digit
;                                            and now nothing is left
;
; Five divisions for five digits. The digits arrive backwards - 0, 0, 0, 4, 6
; - so they go onto the stack, and the stack hands them back the right way
; round: 6, 4, 0, 0, 0.
;
; Then each one has to become a character, and that is one addition:
;
;     digit 6  + 48 = 54, and 54 is the code of the character "6"
;     digit 0  + 48 = 48, and 48 is the code of the character "0"
;
; It works because whoever laid out ASCII put the ten digits in a row, in
; order, on purpose. Nothing else about the alphabet is that convenient.
;
; And ten is not a power of two, which is the whole trouble: there is no
; shift that divides by ten. It has to be a real DIV, once per digit, at
; about a hundred and fifty cycles each. Printing "64000" costs more than
; drawing a line across the screen.
;  In C:
;
;      void put_u(unsigned n)                 /* at cell DI, in colour BL */
;      {
;          int digits[5], count = 0;
;          do { digits[count++] = n % 10;  n /= 10; } while (n);     /* push */
;          while (count) *cell++ = (colour << 8) | (digits[--count] + '0');  /* pop */
;      }
PutU:   mov  cx, 0              ; count = 0: how many digits we end up with
        mov  bp, 10             ; BP = 10, the divisor
.split: xor  dx, dx             ; DX = 0: DIV works on DX:AX, so clear the top half
        div  bp                 ; AX = n / 10, DX = the remainder
        push dx                 ; push the digit
        inc  cx                 ; count++
        or   ax, ax             ; n == 0 ?
        jnz  .split             ;   no: again, until there is nothing left to divide
        mov  ah, bl             ; AH = the colour
.out:   pop  dx                 ; DX = the digit, last pushed first
        mov  al, dl             ; AL = the digit
        add  al, '0'            ; AL += 48: 7 becomes 55, which is the character "7"
        stosw                   ; *cell++ = AX
        loop .out               ; while (--count)
        ret                     ; return

; ---- a cell on the text screen, at [row] and the column in AX --------------
;  In C:   int cell(int column) { return (row * 80 + column) * 2; }
Cell:   push ax                 ; keep the column
        mov  ax, [row]          ; AX = row
        mov  bx, 80             ; BX = 80 cells a row
        mul  bx                 ; AX = row * 80
        pop  bx                 ; BX = the column
        add  ax, bx             ; AX = row * 80 + column
        add  ax, ax             ; AX *= 2: two bytes to a cell
        mov  di, ax             ; DI = the cell
        ret                     ; return DI

; ---- a filled rectangle, from lesson 3 -------------------------------------
;   DI = top-left offset   AL = colour   BX = width   DX = height   ES = VGA
;  In C:   for (; height--; at += 320) memset(screen + at, colour, width);
Rect:   push di                 ; keep the row start
        mov  cx, bx             ; CX = width
        rep  stosb              ; while (cx--) *es:di++ = al: one row
        pop  di                 ; DI = the row start again
        add  di, W              ; DI += 320: the row below
        dec  dx                 ; height--
        jnz  Rect               ; while (height)
        ret                     ; return

;  In C:
;
;      int main(void)
;      {
;          set_mode(3);
;          /* 1 */ five strings, two raw cells 0E05 and 0E35;  key();
;          /* 2 */ n = 64000;  for (row = 5; n; row++) { print n, "/ 10 =", n / 10, "remainder", n % 10;  n /= 10; }  key();
;          /* 3 */ set_mode(0x13);  y = 8 << 8;  v = 0;  x = 6;
;                  for (i = 0; i < 100; i++) { rect(x, y >> 8);  x += 3;  v += 40;  y += v;
;                                              if (y >= FLOOR << 8) { y = FLOOR << 8;  v = -v * 205 >> 8; } }
;                  key();
;          set_mode(3);  exit(0);
;      }
Boot:   cld                     ; string ops count UP
        mov  ax, 0003h          ; AX = 3: text mode. Setting it also clears it.
        int  10h                ; set_mode(3)
        mov  ax, TEXT           ; AX = B800h
        mov  es, ax             ; ES = the text screen

; ---- 1. the byte and the character -----------------------------------------
        mov  bl, 0Fh            ; colour = white
        mov  di, (4*80+16)*CELL ; DI = row 4, column 16
        mov  si, t1a            ; SI = t1a
        call Puts               ; puts()
        mov  di, (6*80+16)*CELL ; DI = row 6, column 16
        mov  si, t1b            ; SI = t1b
        call Puts               ; puts()
                                ;
        mov  bl, 0Bh            ; colour = light cyan
        mov  di, (10*80+22)*CELL; DI = row 10, column 22
        mov  si, t1c            ; SI = t1c
        call Puts               ; puts()
        mov  di, (10*80+46)*CELL; DI = row 10, column 46
        mov  si, t1d            ; SI = t1d
        call Puts               ; puts()
                                ;
        ; and now the two bytes themselves, written raw into the screen
        mov  di, (12*80+27)*CELL; DI = row 12, column 27
        mov  ax, 0E05h          ; colour 0E, character 05
        stosw                   ; *cell++ = AX: a club
        mov  di, (12*80+51)*CELL; DI = row 12, column 51
        mov  ax, 0E35h          ; colour 0E, character 53 - which is "5"
        stosw                   ; *cell++ = AX: a five
                                ;
        mov  bl, 08h            ; colour = dark grey
        mov  di, (16*80+10)*CELL; DI = row 16, column 10
        mov  si, t1e            ; SI = t1e
        call Puts               ; puts()
        call Key                ; key()

; ---- 2. printing a number, WITH ITS WORKING SHOWN --------------------------
; The first version of this frame just printed 7 and 64000 and said "printing
; needs a division". That proves nothing: the screen looked exactly like any
; other language's output, and the viewer had only my word for what happened
; underneath.
;
; So this one prints the division itself. Every line on the screen is one turn
; of the loop below, with the number going in, the quotient coming out, and
; the remainder that is the digit.
        mov  ax, 0003h          ; AX = 3: text mode again, which clears it
        int  10h                ; set_mode(3)
        mov  bl, 0Fh            ; colour = white
        mov  di, (2*80+6)*CELL  ; DI = row 2, column 6
        mov  si, t2a            ; SI = t2a
        call Puts               ; puts()
                                ;
        mov  word [n], 64000    ; n = 64000
        mov  word [row], 5      ; row = 5
                                ;
.trace: mov  ax, 8              ; column 8: the number we are dividing
        call Cell               ; DI = cell(8)
        mov  bl, 0Eh            ; colour = yellow
        mov  ax, [n]            ; AX = n
        call PutU               ; put_u(n)
                                ;
        mov  ax, 16             ; column 16: "/ 10 ="
        call Cell               ; DI = cell(16)
        mov  bl, 08h            ; colour = dark grey
        mov  si, tdiv           ; SI = tdiv
        call Puts               ; puts()
                                ;
        mov  ax, [n]            ; AX = n: and here is the division itself
        xor  dx, dx             ; DX = 0: the top half of the dividend
        mov  bp, 10             ; BP = 10
        div  bp                 ; AX = n / 10, DX = n % 10
        mov  [n], ax            ; n = the quotient - what is left to print
        mov  [rem], dx          ; rem = the remainder - the digit that fell off
                                ;
        mov  ax, 24             ; column 24: the quotient
        call Cell               ; DI = cell(24)
        mov  bl, 0Eh            ; colour = yellow
        mov  ax, [n]            ; AX = n
        call PutU               ; put_u(n)
                                ;
        mov  ax, 32             ; column 32: "remainder"
        call Cell               ; DI = cell(32)
        mov  bl, 08h            ; colour = dark grey
        mov  si, trem           ; SI = trem
        call Puts               ; puts()
                                ;
        mov  ax, 43             ; column 43: and the digit, in white
        call Cell               ; DI = cell(43)
        mov  bl, 0Fh            ; colour = white
        mov  ax, [rem]          ; AX = rem
        call PutU               ; put_u(rem)
                                ;
        inc  word [row]         ; row++
        cmp  word [n], 0        ; n == 0 ?
        jne  .trace             ;   no: the next line of the trace
                                ;
        mov  bl, 0Bh            ; colour = light cyan
        mov  di, (12*80+6)*CELL ; DI = row 12, column 6
        mov  si, t2b            ; SI = t2b
        call Puts               ; puts()
        mov  di, (14*80+6)*CELL ; DI = row 14, column 6
        mov  si, t2c            ; SI = t2c
        call Puts               ; puts()
        mov  bl, 0Fh            ; colour = white
        mov  di, (14*80+42)*CELL; DI = row 14, column 42
        mov  ax, 64000          ; AX = 64000
        call PutU               ; put_u(64000): the digits the right way round
                                ;
        mov  bl, 08h            ; colour = dark grey
        mov  di, (17*80+6)*CELL ; DI = row 17, column 6
        mov  si, t2d            ; SI = t2d
        call Puts               ; puts()
        call Key                ; key()

; ---- 3. a thrown ball, and the trail it leaves -----------------------------
; NOT an animation. Every step is drawn and nothing is rubbed out, so the whole
; flight stands still on the screen at once - which is the only way to SEE the
; thing this frame is about.
;
; Sideways the ball moves the same three pixels every step, so those gaps are
; all equal. Downwards it moves by v, and v grows by g every step, so those
; gaps get bigger and bigger. Equal time, unequal distance: that IS
; acceleration, and it is a picture rather than a sentence.
;
; EVERYTHING HERE IS 8.8, and that needs numbers rather than a name.
;
; A word is sixteen bits. Read the top eight as whole pixels and the bottom
; eight as 256ths of a pixel, and one word carries both. So:
;
;     8 pixels down       is  8 * 256  = 2048
;     half a pixel        is       128
;     v = 40              is  40 / 256 = 0.156 of a pixel per step
;     v after ten steps   is 400 / 256 = 1.56  pixels per step
;
; Nothing here is a fraction. 2048 is a whole number, 40 is a whole number,
; and the decimal point exists only in the way we agree to read them.
;
; To get the pixel back out, take the top byte:
;
;     y = 2088   ->  top byte is 8    ->  eight pixels down
;     y = 2344   ->  top byte is 9    ->  nine pixels down
;
; Which is what a shift of eight IS. There is no shift instruction below -
; MOV AL,AH just reads the other half of the word, and it costs two cycles
; instead of DIV's hundred and fifty.
        mov  ax, 0013h          ; AX = 13h: 320x200, one byte a pixel
        int  10h                ; set_mode(0x13)
        mov  ax, VGA            ; AX = A000h
        mov  es, ax             ; ES = the graphics screen
                                ;
        mov  di, (FLOOR+5)*W    ; DI = row FLOOR+5: the floor, right across
        mov  al, 8              ; AL = 8, dark grey
        mov  cx, W              ; CX = 320 pixels
        rep  stosb              ; while (cx--) *es:di++ = al
                                ;
        mov  word [y], 8*256    ; y = 8.0 in 8.8
        mov  word [v], 0        ; v = 0
        mov  word [x], 6        ; x = 6
        mov  cx, 100            ; CX = 100 steps
                                ;
.step:  push cx                 ; keep the count
        mov  ax, [y]            ; AX = y
        mov  al, ah             ; AL = the top byte
        xor  ah, ah             ; AH = 0: AX = y >> 8 - the whole-pixel part
        mov  bx, W              ; BX = 320
        mul  bx                 ; AX = (y >> 8) * 320
        add  ax, [x]            ; AX += x
        mov  di, ax             ; DI = the ball's top left
        mov  al, 44             ; colour = 44, red
        mov  bx, 5              ; width = 5
        mov  dx, 5              ; height = 5
        call Rect               ; rect()

        add  word [x], 3        ; sideways: the same every step, for ever

        ; WHERE IS THE MASS? There is none, and that is not us cutting a
        ; corner - it is Galileo's. A heavy ball and a light one fall at the
        ; same rate, because the pull on a thing grows with its mass exactly
        ; as fast as its mass resists being moved. The two cancel. Force
        ; equals mass times acceleration, so acceleration equals force over
        ; mass - and once you have divided, the mass is gone.
        ;
        ; What is left has only two lines in it, and here they both are:
        ;
        ;     v = v + g      the speed grows by the same amount every step
        ;     y = y + v      and the height changes by whatever the speed is
        ;
        ; g is our 40. Nothing else in this program knows any physics at all.
        ;
        ; And what is coming after them, so it is not a surprise: when y
        ; reaches the floor we turn v around and keep four fifths of it. That
        ; is the bounce, and losing the other fifth is why it dies down.

        mov  ax, [v]            ; AX = v
        add  ax, 40             ; v = v + g. One step older, one step faster.
        mov  [v], ax            ; 40/256 of a pixel per step, per step.

        mov  ax, [y]            ; AX = y
        add  ax, [v]            ; y = y + v. It has moved by whatever its
        mov  [y], ax            ; speed happened to be this step.

        ; the floor. 8.8 in a SIGNED 16-bit word tops out at 127.99 pixels -
        ; 128*256 is 32768, which is negative - so the floor has to live below
        ; that or every comparison against it reads the wrong way round. This
        ; is the whole of fixed point in one constant: you buy the fraction
        ; with range, and you have to know where the edge is.
        cmp  ax, FLOOR*256      ; y < the floor, in 8.8 ?
        jl   .next              ;   yes: still falling
        mov  word [y], FLOOR*256; y = the floor: no sinking into it
        ; THE BOUNCE, worked out first. We want four fifths of the speed
        ; back, and four fifths of 256 is 204.8 - call it 205. Then:
        ;
        ;     v          = 1000        which is 1000/256 = 3.9 px a step
        ;     1000 * 205 = 205000
        ;     205000 / 256 = 800       which is  800/256 = 3.1 px a step
        ;     800 / 1000 = 0.8         four fifths, as ordered
        ;
        ; Multiplying by 205 and then shifting down eight IS multiplying by
        ; four fifths. That is the whole trick, and it never once writes a
        ; number with a dot in it.
        mov  ax, [v]            ; AX = v
        neg  ax                 ; AX = -v: turn the fall into a rise...
        mov  bx, 205            ; BX = 205, four fifths of 256
        imul bx                 ; DX:AX = -v * 205: ...and take four fifths of it.

        ; IMUL leaves a 32-bit answer in TWO registers: DX holds the top half,
        ; AX the bottom. Shifting all 32 bits right by eight would mean
        ; sliding one byte out of DX and into AX - so instead of shifting we
        ; just pick the two bytes up where they already are:
        ;
        ;     205000 in hex is 3 20C8   ->  DX = 0003, AX = 20C8
        ;     we want 800, which in hex is  0320
        ;     AH is 20, DL is 03         ->  put them together: 0320
        ;
        mov  al, ah             ; the top byte of AX becomes the bottom byte
        mov  ah, dl             ; the bottom byte of DX becomes the top one
        mov  [v], ax            ; and that is the answer, already shifted

.next:  pop  cx                 ; the count back
        loop .step              ; while (--cx)
        call Key                ; key()

Bye:    mov  ax, 0003h          ; AX = 3: back to text
        int  10h                ; set_mode(3)
        mov  ax, 4C00h          ; AH = 4Ch exit, AL = 0 the code
        int  21h                ; exit(0)
