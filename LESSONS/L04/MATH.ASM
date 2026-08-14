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

        jmp  Boot

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
Key:    mov  ah, 0
        int  16h
        ret

; ---- a zero-terminated string to the text screen ---------------------------
;   SI = the text   DI = cell offset   BL = colour
Puts:   mov  ah, bl
.l:     lodsb
        or   al, al
        jz   .done
        stosw                   ; AL is the character, AH its colour, and DI
        jmp  .l                 ; steps on by two because a cell is two bytes
.done:  ret

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
PutU:   mov  cx, 0              ; how many digits we end up with
        mov  bp, 10
.split: xor  dx, dx             ; DIV works on DX:AX, so clear the top half
        div  bp                 ; AX = AX/10, DX = the remainder
        push dx
        inc  cx
        or   ax, ax
        jnz  .split             ; until there is nothing left to divide
        mov  ah, bl
.out:   pop  dx
        mov  al, dl
        add  al, '0'            ; 7 becomes 55, which is the character "7"
        stosw
        loop .out
        ret

; ---- a cell on the text screen, at [row] and the column in AX --------------
Cell:   push ax
        mov  ax, [row]
        mov  bx, 80
        mul  bx
        pop  bx
        add  ax, bx
        add  ax, ax             ; two bytes to a cell
        mov  di, ax
        ret

; ---- a filled rectangle, from lesson 3 -------------------------------------
;   DI = top-left offset   AL = colour   BX = width   DX = height   ES = VGA
Rect:   push di
        mov  cx, bx
        rep  stosb
        pop  di
        add  di, W
        dec  dx
        jnz  Rect
        ret

Boot:   cld
        mov  ax, 0003h          ; text mode. Setting it also clears it.
        int  10h
        mov  ax, TEXT
        mov  es, ax

; ---- 1. the byte and the character -----------------------------------------
        mov  bl, 0Fh
        mov  di, (4*80+16)*CELL
        mov  si, t1a
        call Puts
        mov  di, (6*80+16)*CELL
        mov  si, t1b
        call Puts

        mov  bl, 0Bh
        mov  di, (10*80+22)*CELL
        mov  si, t1c
        call Puts
        mov  di, (10*80+46)*CELL
        mov  si, t1d
        call Puts

        ; and now the two bytes themselves, written raw into the screen
        mov  di, (12*80+27)*CELL
        mov  ax, 0E05h          ; colour 0E, character 05
        stosw
        mov  di, (12*80+51)*CELL
        mov  ax, 0E35h          ; colour 0E, character 53 - which is "5"
        stosw

        mov  bl, 08h
        mov  di, (16*80+10)*CELL
        mov  si, t1e
        call Puts
        call Key

; ---- 2. printing a number, WITH ITS WORKING SHOWN --------------------------
; The first version of this frame just printed 7 and 64000 and said "printing
; needs a division". That proves nothing: the screen looked exactly like any
; other language's output, and the viewer had only my word for what happened
; underneath.
;
; So this one prints the division itself. Every line on the screen is one turn
; of the loop below, with the number going in, the quotient coming out, and
; the remainder that is the digit.
        mov  ax, 0003h
        int  10h
        mov  bl, 0Fh
        mov  di, (2*80+6)*CELL
        mov  si, t2a
        call Puts

        mov  word [n], 64000
        mov  word [row], 5

.trace: mov  ax, 8              ; the number we are dividing
        call Cell
        mov  bl, 0Eh
        mov  ax, [n]
        call PutU

        mov  ax, 16             ; "/ 10 ="
        call Cell
        mov  bl, 08h
        mov  si, tdiv
        call Puts

        mov  ax, [n]            ; and here is the division itself
        xor  dx, dx
        mov  bp, 10
        div  bp
        mov  [n], ax            ; the quotient - what is left to print
        mov  [rem], dx          ; the remainder - the digit that fell off

        mov  ax, 24             ; the quotient
        call Cell
        mov  bl, 0Eh
        mov  ax, [n]
        call PutU

        mov  ax, 32             ; "remainder"
        call Cell
        mov  bl, 08h
        mov  si, trem
        call Puts

        mov  ax, 43             ; and the digit, in white
        call Cell
        mov  bl, 0Fh
        mov  ax, [rem]
        call PutU

        inc  word [row]
        cmp  word [n], 0
        jne  .trace

        mov  bl, 0Bh
        mov  di, (12*80+6)*CELL
        mov  si, t2b
        call Puts
        mov  di, (14*80+6)*CELL
        mov  si, t2c
        call Puts
        mov  bl, 0Fh
        mov  di, (14*80+42)*CELL
        mov  ax, 64000
        call PutU

        mov  bl, 08h
        mov  di, (17*80+6)*CELL
        mov  si, t2d
        call Puts
        call Key

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
        mov  ax, 0013h
        int  10h
        mov  ax, VGA
        mov  es, ax

        mov  di, (FLOOR+5)*W    ; the floor, right across
        mov  al, 8
        mov  cx, W
        rep  stosb

        mov  word [y], 8*256
        mov  word [v], 0
        mov  word [x], 6
        mov  cx, 100

.step:  push cx
        mov  ax, [y]
        mov  al, ah
        xor  ah, ah             ; y >> 8 - the whole-pixel part
        mov  bx, W
        mul  bx
        add  ax, [x]
        mov  di, ax
        mov  al, 44
        mov  bx, 5
        mov  dx, 5
        call Rect

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

        mov  ax, [v]
        add  ax, 40             ; v = v + g. One step older, one step faster.
        mov  [v], ax            ; 40/256 of a pixel per step, per step.

        mov  ax, [y]
        add  ax, [v]            ; y = y + v. It has moved by whatever its
        mov  [y], ax            ; speed happened to be this step.

        ; the floor. 8.8 in a SIGNED 16-bit word tops out at 127.99 pixels -
        ; 128*256 is 32768, which is negative - so the floor has to live below
        ; that or every comparison against it reads the wrong way round. This
        ; is the whole of fixed point in one constant: you buy the fraction
        ; with range, and you have to know where the edge is.
        cmp  ax, FLOOR*256
        jl   .next
        mov  word [y], FLOOR*256
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
        mov  ax, [v]
        neg  ax                 ; turn the fall into a rise...
        mov  bx, 205
        imul bx                 ; ...and take four fifths of it.

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

.next:  pop  cx
        loop .step
        call Key

Bye:    mov  ax, 0003h
        int  10h
        mov  ax, 4C00h
        int  21h
