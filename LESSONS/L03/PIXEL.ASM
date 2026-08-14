; ============================================================================
;  PIXEL.ASM - Lesson 3. The screen, one byte at a time.
;
;      FASM PIXEL.ASM PIXEL.COM
;
;  Lesson 1 put a pixel on the screen in C. Lesson 2 showed that a program is
;  only bytes in a file. This one puts the two together: the screen is bytes
;  as well, and from here on we write them ourselves.
;
;  Seven frames, a key between each, Esc to leave early. Nothing here is a
;  library call - there is no library on this machine, and after this lesson
;  you will not want one:
;
;      1  one dot                  one byte, at one address
;      2  every colour there is    64000 bytes, each one after the last
;      3  black                    and nothing else, because we asked for it
;      4  two lines                one of them is a single instruction
;      5  an empty square          drawn ON TOP - nothing was cleared
;      6  a filled square          the same line, done 48 times
;      7  two hundred of them      random colours, random places
;
;  WHY THE FILE IS IN THIS ORDER, and it is not tidiness. The routines every
;  frame shares - Key, Rect, Rand - sit at the top and are jumped over. The
;  frames follow, in the order they run. And the way OUT is the last four
;  lines of the file, reached by simply falling off the end of the last frame,
;  so no jump is needed to get there.
;
;  That shape exists because of how the lesson is recorded: every step adds a
;  frame immediately above those last four lines, which never move. The
;  insertion point is the same on every step of a ten-minute take, and nothing
;  that already works is ever edited again.
;
;  Owlos - legacy software modernization - https://owlos.sk
; ============================================================================
format binary as 'com'
        org  100h

VGA     = 0A000h                ; where the graphics screen lives
W       = 320                   ; and how wide a row of it is, in bytes
H       = 200                   ; and how many rows there are

; ---- the whole of the arithmetic -------------------------------------------
;
;   offset = y * 320 + x
;
; That is the entire lesson, and it is the same line lesson 1 wrote in C. The
; screen is not a grid. It is ONE long row of 64000 bytes, and it only looks
; like a grid because the card reads 320 of them, drops a line, and reads 320
; more. Everything below is that arithmetic with different numbers in it.
; ----------------------------------------------------------------------------

        jmp  Boot               ; over the routines the frames share

; ---- wait for anything -----------------------------------------------------
Key:    mov  ah, 0              ; INT 16h function 0: sleep until a key
        int  16h
        cmp  al, 27             ; Esc means "that is enough"
        jne  .stay              ; NOT `je Bye`. Bye is the last four lines of
        jmp  Bye                ; the file, far more than 127 bytes away, and
.stay:  ret                     ; an 8086 conditional jump cannot reach that.
                                ; FASM has no .8086 directive, so it would
                                ; have taken the 386 long form without saying
                                ; a word - and the program would run on every
                                ; emulator and die on the machine it is for.
                                ; Leaving from inside a call is fine, by the
                                ; way: DOS does not care about our stack.

; ---- a filled rectangle ----------------------------------------------------
;   DI = top-left offset    AL = colour    BX = width    DX = height
;
; A filled shape is not a new idea. It is the horizontal line from frame 4,
; done once per row, with DI moved on by 320 between them.
Rect:   push di
        mov  cx, bx
        rep  stosb              ; one row - the same single instruction
        pop  di
        add  di, W              ; down to the next row
        dec  dx
        jnz  Rect
        ret

; ---- a number that looks random --------------------------------------------
; Multiply, add, keep the low half, and use it as the seed for the next one.
;
; It is not random at all, and you can prove that without reading a line of
; it: run the program twice and frame 7 comes out identical, square for
; square, colour for colour. Nothing here asked the clock what time it was.
;
; That is not a shortcoming, it is the whole trick - two bytes of seed instead
; of a stored picture. It is how a city gets built later in this series, and
; how two machines on a network end up in the same world without sending it
; to each other.
Rand:   mov  ax, [seed]
        mov  bx, 25173
        mul  bx
        add  ax, 13849
        mov  [seed], ax
        ret

seed    dw   0

; ---- the machine, set up once ----------------------------------------------
Boot:   cld                     ; string instructions count UPWARDS. Said once
                                ; here so nothing below has to wonder.

        mov  ax, 0013h          ; mode 13h - 320 x 200, 256 colours
        int  10h                ; the video BIOS, same doorbell as lesson 1

        mov  ax, VGA
        mov  es, ax             ; from here on ES *is* the screen. DS is still
                                ; us, which is how [seed] keeps working.

; ---- 1. one dot ------------------------------------------------------------
; y = 100, x = 160. The middle. One byte, and that byte is the colour.
        mov  di, 100*W + 160
        mov  byte [es:di], 15   ; 15 is white in the default palette
        call Key

; ---- 2. every colour there is ----------------------------------------------
; 64000 bytes, and each is the number after the one before it. Nothing here
; says WHERE a colour goes: they are simply laid down the memory in order.
;
; And it comes out as diagonal stripes, which is the thing to stop on. A row
; is 320 bytes and there are only 256 colours, so every row starts 64 colours
; further along than the one above it. The picture is slanted because 320 does
; not divide by 256 - and that is proof, on the glass, that this is one long
; row of bytes rather than a grid.
        xor  di, di             ; start of the screen
        xor  al, al             ; and of the colours
        mov  cx, W*H            ; 64000 - every byte there is
.pal:   stosb                   ; ES:DI <- AL, then DI steps on by one
        inc  al                 ; the next byte is the next colour, and at 255
        loop .pal               ; it rolls round to 0 on its own
        call Key

; ---- 3. black, and nothing else --------------------------------------------
; STOS, not MOVS. They are easy to confuse and they are not the same job:
; STOS *stores* AL or AX into ES:DI, so it fills and needs no source; MOVS
; *copies* from DS:SI to ES:DI, so it needs something to copy FROM. There is
; no page of zeroes lying about to copy, so filling is the right instruction.
;
; MOVS is what the next lesson is about: that is how a second screen, drawn
; where nobody can see it, gets poured onto this one.
        xor  di, di
        xor  ax, ax             ; colour 0 - black
        mov  cx, W*H/2          ; 32000 WORDS, not 64000 bytes: two pixels go
        rep  stosw              ; at a time, and the whole screen goes in one
        call Key                ; instruction that repeats itself

; ---- 4. one line across, one line down -------------------------------------
; Look at what these two cost. Across, the pixels are next to each other in
; memory, so the whole line is one instruction. Down, they are 320 bytes
; apart, so it has to be a loop. Same line on the glass; completely different
; price - and that difference is why everything in these games is drawn in
; horizontal spans.
        mov  di, 100*W + 60     ; y = 100, x = 60
        mov  al, 15
        mov  cx, 200            ; 200 pixels across...
        rep  stosb              ; ...and this is the whole line

        mov  di, 40*W + 160     ; y = 40, x = 160
        mov  cx, 120
.down:  mov  byte [es:di], 14   ; yellow
        add  di, W              ; the pixel below is 320 bytes further on
        loop .down
        call Key

; ---- 5. an outline, and NO clearing first ----------------------------------
; The lines are still underneath. Nothing on this machine is ever cleared
; unless you clear it: there is no scene, no display list and nobody tidying
; up behind you. The screen holds whatever was last written into it.
        mov  al, 12             ; red
        mov  di, 60*W + 40      ; the top edge
        mov  cx, 240
        rep  stosb
        mov  di, 140*W + 40     ; the bottom edge
        mov  cx, 240
        rep  stosb

        mov  di, 60*W + 40      ; and the two sides, together, down one loop
        mov  cx, 81
.side:  mov  byte [es:di], 12
        mov  byte [es:di+239], 12
        add  di, W
        loop .side
        call Key

; ---- 6. a filled square ----------------------------------------------------
        mov  di, 70*W + 200     ; y = 70, x = 200
        mov  al, 42             ; a green out of the middle of the palette
        mov  bx, 64             ; wide
        mov  dx, 48             ; and tall
        call Rect
        call Key

; ---- 7. two hundred of them ------------------------------------------------
        mov  si, 200            ; how many
.one:   call Rand
        and  ax, 0FFh           ; x: 0..255, so x+48 is always on the screen
        mov  di, ax
        call Rand
        and  ax, 07Fh           ; y: 0..127...
        add  ax, 8              ; ...pushed down clear of the top
        mov  bx, W
        mul  bx                 ; AX = y * 320. This is the arithmetic again,
        add  di, ax             ; and it is the only arithmetic there is.
        call Rand               ; AL is now the colour, whatever it is
        mov  bx, 48             ; a fixed size, so nothing here can run off
        mov  dx, 40             ; the edge and wrap onto the next row
        call Rect
        dec  si
        jnz  .one
        call Key

; ---- the way out -----------------------------------------------------------
; Reached by falling off the end of the last frame, so no jump is needed to
; get here - and that is the point of it being last. Every step of this lesson
; adds a frame immediately ABOVE these four lines, which never move.
Bye:    mov  ax, 0003h          ; give the text screen back. This program owns
        int  10h                ; the card and nobody will put it right for us
        mov  ax, 4C00h
        int  21h
