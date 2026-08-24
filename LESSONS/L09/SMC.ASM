; ============================================================================
;  SMC.ASM - Lesson 9. Self-modifying code: the titles, run for real.
;
;      FASM SMC.ASM SMC.COM
;
;      1  the footprint   you ran the program - the map ALREADY ran
;      2  the unwind      one more poke winds it back to 1234h
;      3  the self-patch  call Change: the program rewrites ITS OWN cells
;      4  your poke       9ABCh written straight into the mov
;      5  the registers   B8->BB and 06->1E: the run works through BX
;      6  the road        jmp's distance cell picks DAY or NIGHT
;
;  THE MAP IS THE TITLES' MAP, byte for byte. The opening infographic of
;  this lesson walks a little program; THIS FILE PUTS THAT PROGRAM AT THE
;  SAME ADDRESSES, so DEBUG shows exactly what the titles drew:
;
;      0100  E8 0D 00            Start:   call Patch
;      0103  C7 06 11 01 78 56   Change:  mov  word [0111h], 5678h
;      0109  E8 04 00                     call Patch
;      010C  E9 xx xx                     jmp Boot  (the titles drew these
;      010F  ..                            cells blank; the doorway lives
;                                          here - see below)
;      0110  B8 34 12            Patch:   mov  ax, 1234h
;      0113  89 06 00 02                  mov  [0200h], ax
;      0117  C3                           ret
;      0200  ?? ??               wrd:     the word - rubbish until written
;
;  The lesson's frames live PAST the word and drive these pieces by
;  calling them, printing [0200h] between runs. Asserts at the bottom
;  refuse to assemble if any address drifts off the titles' map.
;
;  THE LONG WRITE IS TYPED AS BYTES. FASM would shorten mov [wrd],ax to
;  A3 - the form with no register field - so the lesson types the four
;  cells itself: 89 06, then the address. Code is bytes; here the lesson
;  practises what it preaches.
;
;  THE RULE FROM LESSON 8 STANDS: patch, then jump - every poke below is
;  followed by the two-byte flush jump before the patched code runs.
;
;  Owlos - legacy software modernization - https://owlos.sk
; ============================================================================
format binary as 'com'
        org  100h

TEXT    = 0B800h                ; the text screen: 80x25, TWO bytes a cell
ROW     = 160                   ; a text row is 160 BYTES - two per cell

NORM    = 07h                   ; grey on black
HEAD    = 0Fh                   ; white
WARM    = 0Eh                   ; yellow: freshly written, like the titles

; ---- the titles' program, at the titles' addresses -------------------------
Start:  call Patch              ; 0100: E8 0D 00
Change: mov  word [Patch+1], 5678h
                                ; 0103: C7 06 11 01 78 56 - the self-patch
        call Patch              ; 0109: E8 04 00
        jmp  Boot               ; 010C: the titles drew these cells blank;
                                ;  the lesson parks its doorway here. DOS
                                ;  ENTERS at 0100, so the map RUNS the
                                ;  moment you start the program - frame
                                ;  one is its footprint - and then falls
                                ;  through here into the frames
        db   1 dup (?)          ; 010F: the rest of the gap
Patch:  mov  ax, 1234h          ; 0110: B8 34 12
        db   89h, 06h           ; 0113: the LONG write, typed as bytes -
        dw   wrd                ;  FASM would shorten it to A3, which has
                                ;  no register field, and frame 5 pokes
                                ;  that field. Code is bytes: type them.
        ret                     ; 0117: C3

        db   0E8h dup (?)       ; ...and nothing until the word itself
wrd     dw   ?                  ; 0200: rubbish until somebody writes it

; ---- the road: jmp's distance cell picks the branch ------------------------
;  A tiny subroutine, its own map printed by frame 6. The distance in
;  cell [Road+1] is 0 for Day, 4 for Night - poked at run time.
Road:   jmp  short RDay         ; EB 00 - the distance cell starts at Day
RDay:   mov  si, t_day          ; B3-style tiny branches grew printing:
        jmp  short ROn          ;  each road names itself on the glass
RNight: mov  si, t_night
ROn:    call PutS
        ret
RDIST   = RNight - RDay         ; what to poke for the Night road

include 'DRAW9.INC'

; ---- what the frames say ---------------------------------------------------
t_head  db 'SELF-MODIFYING CODE',0
t_sub   db 'the titles, run for real - lesson 9',0
t_r1    db 'You just ran the program - and it looked like nothing. But the',0
t_r2    db 'MAP already ran: entry is 0100, and 0100 is the first call.',0
t_c1    db 'Unwind it - one more poke, 1234h back into the mov, and call:',0
t_c2    db 'ax held 12 34, memory took 34 12. Low byte first.',0
t_p1    db 'call Change - the program rewrites ITS OWN cells 0111-0112,',0
t_p2    db 'then calls Patch itself. One call, a different subroutine:',0
t_k1    db 'Your poke: 9ABCh straight into the mov, then the flush jump',0
t_k2    db '(lesson 8: patch, then jump), then the same call again:',0
t_g1    db 'Two register pokes: B8 becomes BB, 06 becomes 1E - three bits',0
t_g2    db 'each. The same three instructions now work through BX:',0
t_j1    db 'The road: jmp short is an opcode and a DISTANCE CELL.',0
t_j2    db 'Poke the distance - the same jump takes the other road:',0
t_day   db 'DAY   ',0
t_night db 'NIGHT ',0
t_key   db '- any key -',0
t_ow1   db 'Owlos - legacy software modernization',0
t_ow2   db 'owlos.sk',0

row     dw 0                    ; where the next line goes, in rows

; ---- one frame's worth of screen bookkeeping -------------------------------
Line:   push dx                 ; SI = the text; prints at the current row,
        mov  ax, [row]          ;  two columns in, and moves the row on.
        mov  bx, ROW            ;  DX is saved: MUL eats it, and Say2 keeps
        mul  bx                 ;  its second line there
        mov  di, ax
        add  di, 2*2
        call PutS
        inc  word [row]
        pop  dx
        ret

; ---- print the word: its two cells sign by sign, then the whole ------------
;  The bytes are shown IN ADDRESS ORDER - 34 12 for 1234h - because the
;  screen is the titles' cell strip made real.
ShowW:  mov  ax, [row]
        mov  bx, ROW
        mul  bx
        mov  di, ax
        add  di, 6*2
        mov  byte [attr], WARM
        mov  al, byte [wrd]     ; the LOW cell first: address order
        call PutB
        mov  al, ' '
        call PutC
        mov  al, byte [wrd+1]
        call PutB
        mov  byte [attr], NORM
        mov  si, t_asw
        call PutS
        mov  ax, [wrd]
        xchg al, ah             ; XCHG: swap the halves - PutB wants the
        call PutB               ;  high byte first when printing a WORD
        xchg al, ah
        call PutB
        mov  si, t_ash
        call PutS
        add  word [row], 2
        ret
t_asw   db '   as a word: ',0
t_ash   db 'h',0

; ---- the lower screen, wiped: six frames do not fit 25 rows ---------------
Fresh:  mov  di, 3*ROW          ; keep the headline, clear the rest
        mov  cx, (25-3)*80
        mov  ax, 0720h          ; a space, in grey on black
        rep  stosw
        mov  word [row], 3
        ret

; ---- a captioned pair of lines, then a beat --------------------------------
Say2:   mov  byte [attr], HEAD
        call Line
        mov  si, dx
        mov  byte [attr], NORM
        call Line
        ret

Boot:   cld
        ; ---- the doorway burns itself: entry used the jmp at 010C once;
        ; poke a ret over it, and Change is a callable subroutine again.
        ; The program repairs its own map by the very trick it teaches.
        mov  byte [Start+0Ch], 0C3h
        jmp  short .fb          ; the rule: patch, then jump
.fb:
        mov  ax, 0003h          ; the text screen, 80x25
        int  10h
        call TextOff
        mov  ax, TEXT
        mov  es, ax

        mov  byte [attr], HEAD  ; the headline, and the subtitle under it
        mov  si, t_head
        mov  di, 0*ROW + 30*2
        call PutS
        mov  byte [attr], 08h
        mov  si, t_sub
        mov  di, 1*ROW + 22*2
        call PutS
        mov  word [row], 3

; ---- 1. the footprint -------------------------------------------------------
        mov  si, t_r1
        mov  dx, t_r2
        call Say2
        call ShowW              ; 78 56: the map ran on the way in, faster
        call Key                ;  than the eye - THIS is the whole lesson

; ---- 2. the unwind ---------------------------------------------------------
        mov  si, t_c1
        mov  dx, t_c2
        call Say2
        mov  word [Patch+1], 1234h
        jmp  short .f0          ; the rule: patch, then jump
.f0:    call Patch              ; 1234h lands, swapped
        call ShowW
        call Key

; ---- 3. the self-patch -----------------------------------------------------
        mov  si, t_p1
        mov  dx, t_p2
        call Say2
        call Change             ; the program rewrites its own cells...
        call ShowW              ; ...and 78 56 says it worked
        call Key

; ---- 4. your poke ----------------------------------------------------------
        call Fresh              ; page two: the first three frames stand,
                                ;  read, and make way
        mov  si, t_k1
        mov  dx, t_k2
        call Say2
        mov  word [Patch+1], 9ABCh
        jmp  short .f1          ; THE RULE: patch, then jump
.f1:    call Patch
        call ShowW
        call Key

; ---- 5. the registers ------------------------------------------------------
        mov  si, t_g1
        mov  dx, t_g2
        call Say2
        mov  byte [Patch], 0BBh ; mov ax,imm16 becomes mov BX,imm16...
        mov  byte [Patch+4], 1Eh
                                ; ...and the write's modrm now says BX too
        jmp  short .f2          ; the rule again
.f2:    call Patch
        call ShowW
        call Key

; ---- 6. the road -----------------------------------------------------------
        mov  si, t_j1
        mov  dx, t_j2
        call Say2
        mov  ax, [row]
        mov  bx, ROW
        mul  bx
        mov  di, ax
        add  di, 6*2
        mov  byte [attr], WARM
        call Road               ; DAY - the distance cell holds nought
        mov  byte [Road+1], RDIST
        jmp  short .f3
.f3:    call Road               ; NIGHT - the same jump, poked
        mov  byte [Road+1], 0
        jmp  short .f4
.f4:    call Road               ; and DAY again: the road is yours
        mov  byte [attr], NORM
        add  word [row], 2

        inc  word [row]         ; the signature, the way every lesson ends
        mov  byte [attr], HEAD
        mov  si, t_ow1
        call Line
        mov  byte [attr], WARM
        mov  si, t_ow2
        call Line
        mov  byte [attr], NORM
        mov  si, t_key
        mov  ax, [row]
        mov  bx, ROW
        mul  bx
        mov  di, ax
        add  di, 34*2
        mov  byte [attr], 08h
        call PutS
        call Key

        mov  ax, 0003h          ; a clean screen back to DOS
        int  10h
        mov  ax, 4C00h
        int  21h

; ---- the map must BE the titles' map - or refuse to assemble ---------------
assert Start  = 100h
assert Change = 103h
assert Patch  = 110h
assert wrd    = 200h
