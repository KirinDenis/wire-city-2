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

t2a     db 'To print a number, divide it by ten. Once per digit.',0
t2b     db 'Ten is not a power of two, so no shift will do it -',0
t2c     db 'and DIV costs about forty additions on this machine.',0

y       dw 0                    ; height, 8.8
v       dw 0                    ; speed, 8.8
x       dw 0                    ; sideways, whole pixels


; ---- wait for anything -----------------------------------------------------
Key:    mov  ah, 0
        int  16h
        cmp  al, 27
        jne  .stay
        jmp  Bye
.stay:  ret

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
; THIS IS THE LESSON. Ten is not a power of two, so there is no shift that
; does this: it has to be a real division, once per digit. The remainder is
; the digit, the quotient is what is left to print, and the digits come out
; backwards - which is why they go on the stack and come off in reverse.
;
; Add 48 to each one. That is the whole of the conversion, and 48 is the code
; of the character "0" - so digit + '0' lands exactly on the character for
; that digit, because whoever laid out ASCII put the ten digits in a row on
; purpose.
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

; ---- 2. printing a number --------------------------------------------------
        mov  ax, 0003h
        int  10h
        mov  bl, 0Fh
        mov  di, (4*80+16)*CELL
        mov  si, t2a
        call Puts

        mov  bl, 0Eh
        mov  di, (8*80+24)*CELL
        mov  ax, 7
        call PutU
        mov  di, (9*80+24)*CELL
        mov  ax, 42
        call PutU
        mov  di, (10*80+24)*CELL
        mov  ax, 320
        call PutU
        mov  di, (11*80+24)*CELL
        mov  ax, 64000
        call PutU

        mov  bl, 08h
        mov  di, (15*80+10)*CELL
        mov  si, t2b
        call Puts
        mov  di, (16*80+10)*CELL
        mov  si, t2c
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
; Everything is 8.8 - the top byte whole pixels, the bottom byte the fraction.
; Same convention as the sine table in the games, where the values are sin*256
; for exactly this reason.
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

        ; v += g. Acceleration is nothing more than adding the same number
        ; every step - that is the whole definition, and here it is.
        mov  ax, [v]
        add  ax, 40             ; 40/256 of a pixel per step, per step
        mov  [v], ax

        mov  ax, [y]            ; y += v
        add  ax, [v]
        mov  [y], ax

        ; the floor. 8.8 in a SIGNED 16-bit word tops out at 127.99 pixels -
        ; 128*256 is 32768, which is negative - so the floor has to live below
        ; that or every comparison against it reads the wrong way round. This
        ; is the whole of fixed point in one constant: you buy the fraction
        ; with range, and you have to know where the edge is.
        cmp  ax, FLOOR*256
        jl   .next
        mov  word [y], FLOOR*256
        mov  ax, [v]
        neg  ax                 ; turn the fall into a rise...
        mov  bx, 205
        imul bx                 ; ...and keep 205/256 of it. MULTIPLY AND
        mov  al, ah             ; SHIFT: the >>8 is free, because it is just
        mov  ah, dl             ; taking the high byte of one word and the low
        mov  [v], ax            ; byte of the other. That is fixed point.

.next:  pop  cx
        loop .step
        call Key

Bye:    mov  ax, 0003h
        int  10h
        mov  ax, 4C00h
        int  21h
