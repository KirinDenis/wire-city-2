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

        jmp  Boot               ; over the tables and routines, to the boot

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
;  In C:
;
;      void face(void)
;      {
;          for (ti = 0; ti < 12; ti++) {
;              vang = TICKS[ti];
;              for (vlen = crad - crad / 4; vlen <= crad; vlen++) { vec(); plot(); }
;          }
;      }
Face:   mov  word [ti], 0       ; ti = 0
.tick:  mov  bx, [ti]           ; BX = ti
        add  bx, bx             ; BX = ti * 2: a word to an entry
        mov  ax, [TICKS+bx]     ; AX = TICKS[ti]
        mov  [vang], ax         ; vang = TICKS[ti]
        mov  ax, [crad]         ; AX = crad
        mov  dx, ax             ; DX = crad
        mov  cl, 2              ; CL = 2
        sar  dx, cl             ; DX = crad / 4 ...
        sub  ax, dx             ; AX = crad - crad / 4: ... so the tick starts three quarters out
        mov  [vlen], ax         ; vlen = AX
.out:   call Vec                ; vec()
        call Plot               ; plot()
        inc  word [vlen]        ; vlen++
        mov  ax, [vlen]         ; AX = vlen
        cmp  ax, [crad]         ; vlen <= crad ?
        jle  .out               ;   yes: one pixel further out
        inc  word [ti]          ; ti++
        cmp  word [ti], 12      ; ti < 12 ?
        jl   .tick              ;   yes: the next mark
        ret                     ; return

; ---- one clock: a centre, a radius, and the three angles of the moment -----
;  In C:
;
;      void clock(void)                    /* vcx, vcy, crad = this clock */
;      {
;          col = 9;  face();
;          for (int i = 0; i < 3; i++) {
;              vang = angs[i];
;              rlen = crad - (crad >> SHORTR[i]);
;              col  = HCOL[i];
;              ray();
;          }
;      }
Clock:  mov  byte [col], 9      ; col = 9: the face is light blue
        call Face               ; face()
                                ;
        xor  si, si             ; i = 0: three hands, differing in three numbers
.hand:  mov  bx, si             ; BX = i
        add  bx, bx             ; BX = i * 2: SI counts hands, BX counts bytes
        mov  ax, [angs+bx]      ; AX = angs[i]
        mov  [vang], ax         ; vang = angs[i]: this hand's angle...
        mov  ax, [crad]         ; AX = crad
        mov  dx, ax             ; DX = crad
        mov  bx, si             ; BX = i
        mov  cl, [SHORTR+bx]    ; CL = SHORTR[i]
        sar  dx, cl             ; DX = crad >> SHORTR[i]: r/2 for the hour, r/4, r/8
        sub  ax, dx             ; AX = crad - that: so the hour hand is the short one
        mov  [rlen], ax         ; rlen = AX: ...and this hand's length
        mov  al, [HCOL+bx]      ; AL = HCOL[i]
        mov  [col], al          ; col = HCOL[i]
        push si                 ; keep i: SINQ eats SI - lesson 5 warned about it
        call Ray                ; ray()
        pop  si                 ; i back
        inc  si                 ; i++
        cmp  si, 3              ; i < 3 ?
        jl   .hand              ;   yes: the next hand
        ret                     ; return

; ---- what time is it, and what angle is that -------------------------------
;  INT 21h function 2Ch hands back CH hours, CL minutes, DH seconds, in plain
;  binary. (The BIOS clock, INT 1Ah, gives BCD and makes you unpick it.)
;
;  A circle is 256 steps and a minute is 60 seconds, and 60 does not divide
;  256. So this wants a real DIV - and that is fine. Lesson 4 argued against
;  DIV and lesson 5B took the last one out of the drawing, because those ran
;  sixty-four times a frame. This one runs THREE times a frame. Know what an
;  instruction costs, then spend it where it does not matter.
;  In C:
;
;      void now(void)
;      {
;          dos_time(&hrs, &mins, &secs);
;          angs[2] = a60(secs);
;          angs[1] = a60(mins);
;          int h = hrs;  while (h >= 12) h -= 12;
;          angs[0] = (h * 60 + mins) * 16 / 45;    /* 0..719 * 256 / 720 */
;      }
Now:    mov  ah, 2Ch            ; AH = 2Ch: DOS, get the time
        int  21h                ; CH = hours, CL = minutes, DH = seconds
        mov  [hrs], ch          ; hrs = CH
        mov  [mins], cl         ; mins = CL
        mov  [secs], dh         ; secs = DH
                                ;
        mov  al, [secs]         ; AL = secs
        xor  ah, ah             ; AH = 0: AX = secs
        call A60                ; AX = a60(secs)
        mov  [angs+4], ax       ; angs[2] = AX: the second hand
                                ;
        mov  al, [mins]         ; AL = mins
        xor  ah, ah             ; AH = 0: AX = mins
        call A60                ; AX = a60(mins)
        mov  [angs+2], ax       ; angs[1] = AX: the minute hand
                                ;
        mov  al, [hrs]          ; AL = hrs: and the hour hand, the awkward one
        xor  ah, ah             ; AH = 0: h = hrs
.h12:   cmp  ax, 12             ; h >= 12 ?  13:00 is one o'clock on a face
        jl   .h12ok             ;   no: done
        sub  ax, 12             ;   yes: h -= 12
        jmp  .h12               ; and look again
.h12ok: mov  bx, 60             ; BX = 60
        mul  bx                 ; AX = h * 60: hours into minutes...
        mov  bl, [mins]         ; BL = mins
        xor  bh, bh             ; BH = 0: BX = mins
        add  ax, bx             ; AX = h * 60 + mins: ...plus the minutes: 0..719 round the face,
        mov  cl, 4              ; CL = 4:  because the hand moves DURING the hour
        shl  ax, cl             ; AX *= 16 (719*16 = 11504, still a word)
        xor  dx, dx             ; DX = 0: the high word of the dividend
        mov  bx, 45             ; BX = 45
        div  bx                 ; AX /= 45.  *16/45 IS *256/720
        mov  [angs], ax         ; angs[0] = AX
        ret                     ; return

; ---- 0..59 as an angle, 0..255 ---------------------------------------------
;  In C:   int a60(int n) { return n * 256 / 60; }
A60:    mov  cl, 8              ; CL = 8
        shl  ax, cl             ; AX = n * 256 (59*256 = 15104, fits)
        xor  dx, dx             ; DX = 0: the high word of the dividend
        mov  bx, 60             ; BX = 60
        div  bx                 ; AX /= 60. The divide we can afford
        ret                     ; return AX

; ---- has anybody pressed anything? Without stopping to wait ----------------
tick    dw 0                    ; how many turns frame 2 has drawn
;  In C:   int peek(void) { if (!key_waiting()) return 0;  get_key();  return 1; }
Peek:   mov  ah, 1              ; AH = 1: BIOS 16h, service 1 - is a key waiting?
        int  16h                ; ZF set means nothing is waiting
        jz   .none              ; nothing: return 0
        mov  ah, 0              ; AH = 0: service 0 - read it
        int  16h                ; get_key(): take it, or the next frame sees it again
        mov  al, 1              ; AL = 1
        ret                     ; return 1
.none:  xor  al, al             ; AL = 0
        ret                     ; return 0

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
;  In C:
;
;      void vec(void)
;      {
;          vx = vcx + (sinq(vang) * vlen >> 8);
;          int up = sinq(vang + 64) * vlen >> 8;      /* cos: a quarter turn on */
;          vy = vcy - (up * SQUASH >> 8);              /* 5/6, and UP is minus  */
;      }
Vec:    mov  ax, [vang]         ; AX = vang
        call SINQ               ; AX = sin(a)*256, because the table is *256
        mov  bx, [vlen]         ; BX = vlen
        imul bx                 ; AX = sin * vlen: 256*90 still fits a word
        mov  cl, 8              ; CL = 8
        sar  ax, cl             ; AX >>= 8: and /256 undoes the table. SAR, because
        add  ax, [vcx]          ; AX += vcx:  half of every circle is negative
        mov  [vx], ax           ; vx = AX: x = cx + sin(a)*r/256
                                ;
        mov  ax, [vang]         ; AX = vang
        add  ax, 64             ; AX = vang + 64: a quarter turn along the table IS cosine
        call SINQ               ; AX = cos(a)*256
        mov  bx, [vlen]         ; BX = vlen
        imul bx                 ; AX = cos * vlen
        mov  cl, 8              ; CL = 8
        sar  ax, cl             ; up = AX >> 8: how far UP the point is
        mov  bx, SQUASH         ; BX = 213
        imul bx                 ; AX = up * 213: the screen is not square: five sixths,
        mov  cl, 8              ; CL = 8
        sar  ax, cl             ; AX >>= 8:  or the circle comes out an egg
        neg  ax                 ; AX = -AX: UP is minus, because rows count downwards
        add  ax, [vcy]          ; AX += vcy
        mov  [vy], ax           ; vy = AX: y = cy - cos(a)*r/256
        ret                     ; return

; ---- a ray: ONE angle, every length from the middle outwards ---------------
;  In C:   for (vlen = 0; vlen <= rlen; vlen++) { vec(); plot(); }
Ray:    mov  word [vlen], 0     ; vlen = 0
.step:  call Vec                ; vec(): the same formula, one pixel further out
        call Plot               ; plot()
        inc  word [vlen]        ; vlen++
        mov  ax, [vlen]         ; AX = vlen
        cmp  ax, [rlen]         ; vlen <= rlen ?
        jle  .step              ;   yes: further out
        ret                     ; return

; ---- a ring: ONE length, every angle round the circle ----------------------
;  In C:   for (vang = 0; vang < 256; vang++) { vec(); plot(); }
Ring:   mov  word [vang], 0     ; vang = 0
.p:     call Vec                ; vec(): the same formula, one step further round
        call Plot               ; plot()
        inc  word [vang]        ; vang++: 256 points. At 128 the dots come out two
        cmp  word [vang], 256   ; vang < 256 ?  pixels apart and the circle looks dotted
        jl   .p                 ;   yes: further round
        ret                     ; return

;  In C:
;
;      int main(void)
;      {
;          set_mode(0x13);
;          /* 1 */ clear(); eight spokes of ray(); ring(); key();
;          /* 2 */ for (tick = 0; !peek(); tick++) { retr(); clear(); three rays at tick, 2*tick, 4*tick; }
;          /* 3 */ while (!peek()) { retr(); clear(); now(); one clock(); }
;          /* 4 */ while (!peek()) { retr(); clear(); now(); for each of CLK[10]: clock(); }
;          set_mode(3); exit(0);
;      }
Boot:   cld                     ; string ops count UP: DI counts UP in every STOS
        mov  ax, 0013h          ; AX = 13h: 320x200, one byte a pixel
        int  10h                ; set_mode(0x13)
        mov  ax, VGA            ; AX = A000h
        mov  es, ax             ; ES = the screen, once, for all of it

; ---- 1. the formula, drawn --------------------------------------------------
F1:     call Clear              ; clear()
        mov  word [vang], 0     ; vang = 0
        mov  word [rlen], 90    ; rlen = 90
.spoke: mov  byte [col], 9      ; col = 9, light blue
        call Ray                ; ray(): a ray IS the vector, over and over, longer
        mov  ax, [rlen]         ; AX = rlen
        mov  [vlen], ax         ; vlen = rlen
        call Vec                ; vec(): and once more at the far end, for a bright
        mov  byte [col], 15     ; col = 15, white:  dot: THAT is the point the formula gives
        call Plot               ; plot()
        add  word [vang], 32    ; vang += 32: an eighth of a turn on
        mov  ax, [rlen]         ; AX = rlen
        sub  ax, 9              ; AX -= 9: and a little shorter each time
        mov  [rlen], ax         ; rlen = AX
        cmp  word [vang], 256   ; vang < 256 ?
        jl   .spoke             ;   yes: the next spoke
                                ;
        mov  word [vlen], 45    ; vlen = 45: and now hold the LENGTH still instead and
        mov  byte [col], 14     ; col = 14, yellow:  turn the angle all the way round: a circle
        call Ring               ; ring():  is the same formula, asked the other way
        call Key                ; key()

; ---- 2. the same vector, turned ---------------------------------------------
;  Three of them at three speeds, which is every turning thing in a game: a
;  radar sweep, a rotor, and the second hand two frames from here.
F2:     mov  word [tick], 0     ; tick = 0
.f:     call Retr               ; retr()
        call Clear              ; clear()
        mov  ax, [tick]         ; AX = tick
        mov  [vang], ax         ; vang = tick
        mov  word [rlen], 90    ; rlen = 90
        mov  byte [col], 9      ; col = 9, light blue
        call Ray                ; ray()
        mov  ax, [tick]         ; AX = tick
        add  ax, ax             ; AX = tick * 2: twice round in the same time
        mov  [vang], ax         ; vang = tick * 2
        mov  word [rlen], 60    ; rlen = 60
        mov  byte [col], 14     ; col = 14, yellow
        call Ray                ; ray()
        mov  ax, [tick]         ; AX = tick
        mov  cl, 2              ; CL = 2
        shl  ax, cl             ; AX = tick * 4: and four times
        mov  [vang], ax         ; vang = tick * 4
        mov  word [rlen], 35    ; rlen = 35
        mov  byte [col], 40     ; col = 40, red
        call Ray                ; ray()
        inc  word [tick]        ; tick++
        call Peek               ; AL = peek()
        cmp  al, 0              ; a key ?
        jne  F3                 ;   yes: the short jump goes FORWARDS (lesson 5B)...
        jmp  .f                 ;   no: ...and JMP does the reaching back

; ---- 3. one clock ------------------------------------------------------------
F3:     call Retr               ; retr()
        call Clear              ; clear()
        call Now                ; now()
        mov  word [vcx], 160    ; vcx = 160
        mov  word [vcy], 100    ; vcy = 100
        mov  word [crad], 80    ; crad = 80
        call Clock              ; clock()
        call Peek               ; AL = peek()
        cmp  al, 0              ; a key ?
        jne  F4                 ;   yes: on to frame 4
        jmp  F3                 ;   no: the next frame

; ---- 4. ten of them ----------------------------------------------------------
;  The time is read ONCE, above the loop. A clock is a centre and a radius;
;  the moment is not part of it.
F4:     call Retr               ; retr()
        call Clear              ; clear()
        call Now                ; now()
        mov  si, CLK            ; SI = &CLK[0]
        mov  bp, NCLK           ; BP = 10 left
.each:  mov  ax, [si]           ; AX = SI->x
        mov  [vcx], ax          ; vcx = AX
        mov  ax, [si+2]         ; AX = SI->y
        mov  [vcy], ax          ; vcy = AX
        mov  ax, [si+4]         ; AX = SI->r
        mov  [crad], ax         ; crad = AX
        add  si, 6              ; SI++: three words to a clock
        push si                 ; keep SI: SINQ eats SI. BP survives everything
        call Clock              ; clock()
        pop  si                 ; SI back
        dec  bp                 ; BP--
        jnz  .each              ; while (BP): the next clock
        call Peek               ; AL = peek()
        cmp  al, 0              ; a key ?
        jne  Bye                ;   yes: leave
        jmp  F4                 ;   no: the next frame

Bye:    mov  ax, 0003h          ; AX = 3: back to text, 80x25
        int  10h                ; set_mode(3)
        mov  ax, 4C00h          ; AH = 4Ch exit, AL = 0 the code
        int  21h                ; exit(0): hand the machine back to DOS
