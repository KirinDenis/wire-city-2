; ============================================================================
;  CLOCK.ASM - Lesson 6. The radius vector, and ten clocks that keep it.
;
;      FASM CLOCK.ASM CLOCK.COM
;
;      1  the vectors    a length and an angle in, a point out
;      2  the timer      the same vector, turned a step at a time
;      3  one clock      three vectors, and DOS says what angles to use
;      4  ten clocks     one routine, ten centres, ten radii, one time
;
;  ONE FORMULA, AND EVERYTHING ON THE SCREEN IS MADE OF IT:
;
;      x = cx + sin(a) * r / 256
;      y = cy - cos(a) * r / 256
;
;  A CIRCLE is that, with r fixed and a going all the way round.
;  A HAND is that, with a fixed and r growing out of the middle.
;  Nothing here draws a line and nothing here draws a circle. There is one
;  routine, Vec, and two loops that call it differently.
;
;  IT IS ALSO WHERE THE 3D COMES FROM. A thing in a game world is a distance
;  and a direction from somewhere else - the aeroplane from the camera, the
;  wheel from the aeroplane - and each one is worked out like this. Learn it
;  flat, on a clock face, and the third axis is one more line of the same.
;
;  MINUS ON THE Y, because rows count DOWNWARDS and twelve o'clock is UP.
;  That one sign is the difference between a clock and a clock running back.
;
;  THE FILE READS NEWEST FIRST, and that is not untidiness. Each part of the
;  lesson adds its data and its routines at one point - just under the jump -
;  and its picture at another, just above the exit. What you are reading is
;  the order it was built in, upside down.
;
;  Owlos - legacy software modernization - https://owlos.sk
; ============================================================================
format binary as 'com'
        org  100h

VGA     = 0A000h
W       = 320                   ; the screen, in pixels
H       = 200
SQUASH  = 213                   ; 5/6 in 256ths: a pixel is taller than wide

        jmp  Boot

; ---- ten clocks: a centre and a radius each, and nothing else --------------
;  THE TIME IS NOT IN HERE. There is one time, and ten faces showing it.
NCLK    = 10
CLK     dw 160,100,48
        dw  45, 32,28
        dw 275, 32,28
        dw  45,168,28
        dw 275,168,28
        dw 160, 24,18
        dw 160,176,18
        dw  50,100,22
        dw 270,100,22
        dw 216, 62,13

; ---- the time, once, for every clock on the screen -------------------------
hrs     db 0                    ; FASM keeps ss for the segment register, so
mins    db 0                    ;  these three are named out of its way
secs    db 0
angs    dw 0, 0, 0              ; the hour, minute and second hands, as ANGLES
SHORTR  db 1, 2, 3              ; each hand is r minus r/2, r/4, r/8
HCOL    db 14, 15, 40           ; yellow, white, red
crad    dw 0                    ; how big the clock being drawn is
ti      dw 0                    ; which of the twelve marks is being drawn

; 256 steps do not divide by twelve, so the twelve marks are worked out once
; and written down, instead of drifting a step further round each hour
TICKS   dw 0, 21, 43, 64, 85, 107, 128, 149, 171, 192, 213, 235

; ---- the face: twelve marks, each a ray that starts three quarters out -----
;  A ring of single dots goes gappy as the clock grows: the points are a
;  circumference apart, and the circumference grows with the radius. A tick
;  does not, because it is a short RAY - solid at any size.
Face:   mov  word [ti], 0
.tick:  mov  bx, [ti]
        add  bx, bx             ; a word to an entry
        mov  ax, [TICKS+bx]
        mov  [vang], ax
        mov  ax, [crad]
        mov  dx, ax
        mov  cl, 2
        sar  dx, cl             ; r/4 ...
        sub  ax, dx             ; ... so the tick starts three quarters out
        mov  [vlen], ax
.out:   call Vec
        call Plot
        inc  word [vlen]
        mov  ax, [vlen]
        cmp  ax, [crad]
        jle  .out
        inc  word [ti]
        cmp  word [ti], 12
        jl   .tick
        ret

; ---- one clock: a centre, a radius, and the three angles of the moment -----
Clock:  mov  byte [col], 9      ; the face is light blue
        call Face

        xor  si, si             ; three hands, differing in three numbers
.hand:  mov  bx, si
        add  bx, bx             ; SI counts hands, BX counts bytes
        mov  ax, [angs+bx]
        mov  [vang], ax         ; this hand's angle...
        mov  ax, [crad]
        mov  dx, ax
        mov  bx, si
        mov  cl, [SHORTR+bx]
        sar  dx, cl             ; r/2 for the hour, r/4, r/8
        sub  ax, dx             ; so the hour hand is the short one
        mov  [rlen], ax         ; ...and this hand's length
        mov  al, [HCOL+bx]
        mov  [col], al
        push si                 ; SINQ eats SI - lesson 5 warned about it
        call Ray
        pop  si
        inc  si
        cmp  si, 3
        jl   .hand
        ret

; ---- what time is it, and what angle is that -------------------------------
;  INT 21h function 2Ch hands back CH hours, CL minutes, DH seconds, in plain
;  binary. (The BIOS clock, INT 1Ah, gives BCD and makes you unpick it.)
;
;  A circle is 256 steps and a minute is 60 seconds, and 60 does not divide
;  256. So this wants a real DIV - and that is fine. Lesson 4 argued against
;  DIV and lesson 5B took the last one out of the drawing, because those ran
;  sixty-four times a frame. This one runs THREE times a frame. Know what an
;  instruction costs, then spend it where it does not matter.
Now:    mov  ah, 2Ch
        int  21h
        mov  [hrs], ch
        mov  [mins], cl
        mov  [secs], dh

        mov  al, [secs]
        xor  ah, ah
        call A60
        mov  [angs+4], ax       ; the second hand

        mov  al, [mins]
        xor  ah, ah
        call A60
        mov  [angs+2], ax       ; the minute hand

        mov  al, [hrs]          ; and the hour hand, the awkward one
        xor  ah, ah
.h12:   cmp  ax, 12             ; 13:00 is one o'clock on a face
        jl   .h12ok
        sub  ax, 12
        jmp  .h12
.h12ok: mov  bx, 60
        mul  bx                 ; hours into minutes...
        mov  bl, [mins]
        xor  bh, bh
        add  ax, bx             ; ...plus the minutes: 0..719 round the face,
        mov  cl, 4              ;  because the hand moves DURING the hour
        shl  ax, cl             ; *16 (719*16 = 11504, still a word)
        xor  dx, dx
        mov  bx, 45
        div  bx                 ; /45.  *16/45 IS *256/720
        mov  [angs], ax
        ret

; ---- 0..59 as an angle, 0..255 ---------------------------------------------
A60:    mov  cl, 8
        shl  ax, cl             ; *256 (59*256 = 15104, fits)
        xor  dx, dx
        mov  bx, 60
        div  bx                 ; /60. The divide we can afford
        ret

; ---- has anybody pressed anything? Without stopping to wait ----------------
tick    dw 0                    ; how many turns frame 2 has drawn
Peek:   mov  ah, 1
        int  16h                ; ZF set means nothing is waiting
        jz   .none
        mov  ah, 0
        int  16h                ; take it, or the next frame sees it again
        mov  al, 1
        ret
.none:  xor  al, al
        ret

; ---- what Vec is given, and what it hands back -----------------------------
vcx     dw 160                  ; the centre it measures from
vcy     dw 100
vang    dw 0                    ; the angle: 0..255 is a whole circle
vlen    dw 0                    ; and how far out along it
vx      dw 0                    ; the answer
vy      dw 0
col     db 15
rlen    dw 0                    ; how long a ray is

include 'SINT.INC'              ; lesson 5's sixty-five numbers
include 'DRAW.INC'              ; and lessons 3 and 5B's routines

; ---- THE RADIUS VECTOR ------------------------------------------------------
;  in:  vang the angle, vlen the length, vcx/vcy the centre
;  out: vx/vy the point.  Eats AX, BX, CX, DX and SI (SINQ does).
Vec:    mov  ax, [vang]
        call SINQ               ; AX = sin(a)*256, because the table is *256
        mov  bx, [vlen]
        imul bx                 ; * the length: 256*90 still fits a word
        mov  cl, 8
        sar  ax, cl             ; and /256 undoes the table. SAR, because
        add  ax, [vcx]          ;  half of every circle is negative
        mov  [vx], ax           ; x = cx + sin(a)*r/256

        mov  ax, [vang]
        add  ax, 64             ; a quarter turn along the table IS cosine
        call SINQ
        mov  bx, [vlen]
        imul bx
        mov  cl, 8
        sar  ax, cl             ; AX = how far UP the point is
        mov  bx, SQUASH
        imul bx                 ; the screen is not square: five sixths,
        mov  cl, 8
        sar  ax, cl             ;  or the circle comes out an egg
        neg  ax                 ; UP is minus, because rows count downwards
        add  ax, [vcy]
        mov  [vy], ax           ; y = cy - cos(a)*r/256
        ret

; ---- a ray: ONE angle, every length from the middle outwards ---------------
Ray:    mov  word [vlen], 0
.step:  call Vec                ; the same formula, one pixel further out
        call Plot
        inc  word [vlen]
        mov  ax, [vlen]
        cmp  ax, [rlen]
        jle  .step
        ret

; ---- a ring: ONE length, every angle round the circle ----------------------
Ring:   mov  word [vang], 0
.p:     call Vec                ; the same formula, one step further round
        call Plot
        inc  word [vang]        ; 256 points. At 128 the dots come out two
        cmp  word [vang], 256   ;  pixels apart and the circle looks dotted
        jl   .p
        ret

Boot:   cld                     ; DI counts UP in every STOS
        mov  ax, 0013h          ; 320x200, one byte a pixel
        int  10h
        mov  ax, VGA
        mov  es, ax             ; ES points at the screen, once, for all of it

; ---- 1. the formula, drawn --------------------------------------------------
F1:     call Clear
        mov  word [vang], 0
        mov  word [rlen], 90
.spoke: mov  byte [col], 9
        call Ray                ; a ray IS the vector, over and over, longer
        mov  ax, [rlen]
        mov  [vlen], ax
        call Vec                ; and once more at the far end, for a bright
        mov  byte [col], 15     ;  dot: THAT is the point the formula gives
        call Plot
        add  word [vang], 32    ; an eighth of a turn on
        mov  ax, [rlen]
        sub  ax, 9              ; and a little shorter each time
        mov  [rlen], ax
        cmp  word [vang], 256
        jl   .spoke

        mov  word [vlen], 45    ; and now hold the LENGTH still instead and
        mov  byte [col], 14     ;  turn the angle all the way round: a circle
        call Ring               ;  is the same formula, asked the other way
        call Key

; ---- 2. the same vector, turned ---------------------------------------------
;  Three of them at three speeds, which is every turning thing in a game: a
;  radar sweep, a rotor, and the second hand two frames from here.
F2:     mov  word [tick], 0
.f:     call Retr
        call Clear
        mov  ax, [tick]
        mov  [vang], ax
        mov  word [rlen], 90
        mov  byte [col], 9
        call Ray
        mov  ax, [tick]
        add  ax, ax             ; twice round in the same time
        mov  [vang], ax
        mov  word [rlen], 60
        mov  byte [col], 14
        call Ray
        mov  ax, [tick]
        mov  cl, 2
        shl  ax, cl             ; and four times
        mov  [vang], ax
        mov  word [rlen], 35
        mov  byte [col], 40
        call Ray
        inc  word [tick]
        call Peek
        cmp  al, 0
        jne  F3                 ; the short jump goes FORWARDS (lesson 5B)...
        jmp  .f                 ; ...and JMP does the reaching back

; ---- 3. one clock ------------------------------------------------------------
F3:     call Retr
        call Clear
        call Now
        mov  word [vcx], 160
        mov  word [vcy], 100
        mov  word [crad], 80
        call Clock
        call Peek
        cmp  al, 0
        jne  F4
        jmp  F3

; ---- 4. ten of them ----------------------------------------------------------
;  The time is read ONCE, above the loop. A clock is a centre and a radius;
;  the moment is not part of it.
F4:     call Retr
        call Clear
        call Now
        mov  si, CLK
        mov  bp, NCLK
.each:  mov  ax, [si]
        mov  [vcx], ax
        mov  ax, [si+2]
        mov  [vcy], ax
        mov  ax, [si+4]
        mov  [crad], ax
        add  si, 6              ; three words to a clock
        push si                 ; SINQ eats SI. BP survives everything
        call Clock
        pop  si
        dec  bp
        jnz  .each
        call Peek
        cmp  al, 0
        jne  Bye
        jmp  F4

Bye:    mov  ax, 0003h          ; back to text, 80x25
        int  10h
        mov  ax, 4C00h          ; and hand the machine back to DOS
        int  21h
