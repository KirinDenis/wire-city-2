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
;  In C there is no way to write this program, and that is the lesson:
;
;      void patch(void)  { wrd = 0x1234; }          /* ...except the 1234 is a CELL */
;      void change(void) { *(int *)(0x111) = 0x5678;  patch(); }   /* and this
;                          writes INTO patch()'s code, so it now stores 5678 */
;
;  A C compiler will not let a program write over its own functions. The
;  8086 has no such rule: code is bytes at an address, and MOV can reach it.
Start:  call Patch              ; 0100: E8 0D 00      patch()
Change: mov  word [Patch+1], 5678h
                                ; 0103: C7 06 11 01 78 56 - the self-patch:
                                ;  *(0111h) = 5678h, INTO the mov inside Patch
        call Patch              ; 0109: E8 04 00      patch() - now storing 5678h
        jmp  Boot               ; 010C: the titles drew these cells blank;
                                ;  the lesson parks its doorway here. DOS
                                ;  ENTERS at 0100, so the map RUNS the
                                ;  moment you start the program - frame
                                ;  one is its footprint - and then falls
                                ;  through here into the frames
        db   1 dup (?)          ; 010F: the rest of the gap
Patch:  mov  ax, 1234h          ; 0110: B8 34 12      AX = 1234h - and 34 12 are
                                ;  two CELLS, which the frames rewrite
        db   89h, 06h           ; 0113: mov [wrd], ax - the LONG write, typed as
        dw   wrd                ;  bytes. FASM would shorten it to A3, which has
                                ;  no register field, and frame 5 pokes that
                                ;  field. Code is bytes: type them
        ret                     ; 0117: C3            return

        db   0E8h dup (?)       ; ...and nothing until the word itself
wrd     dw   ?                  ; 0200: rubbish until somebody writes it

; ---- the road: jmp's distance cell picks the branch ------------------------
;  A tiny subroutine, its own map printed by frame 6. The distance in
;  cell [Road+1] is 0 for Day, 4 for Night - poked at run time.
;  In C:   void road(void) { puts(dist ? "NIGHT " : "DAY "); }   - but `dist` is
;  not a variable: it is the byte after the jump's opcode, cell 0 of `jmp short`.
Road:   jmp  short RDay         ; EB 00: the opcode, and the DISTANCE cell - 0
RDay:   mov  si, t_day          ; SI = "DAY "    each road names itself on the
        jmp  short ROn          ; over Night      glass, so a poke can be seen
RNight: mov  si, t_night        ; SI = "NIGHT "
ROn:    call PutS               ; puts()
        ret                     ; return
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
;  In C:   void line(char *s) { puts_at(row, 2, s);  row++; }
Line:   push dx                 ; keep DX: MUL eats it, and Say2 keeps its
        mov  ax, [row]          ; AX = row        second line there
        mov  bx, ROW            ; BX = 160 bytes a row
        mul  bx                 ; AX = row * 160
        mov  di, ax             ; DI = the row start
        add  di, 2*2            ; DI += column 2
        call PutS               ; puts()
        inc  word [row]         ; row++
        pop  dx                 ; DX back
        ret                     ; return

; ---- print the word: its two cells sign by sign, then the whole ------------
;  The bytes are shown IN ADDRESS ORDER - 34 12 for 1234h - because the
;  screen is the titles' cell strip made real.
;  In C:
;
;      void show_w(void)                       /* "34 12   as a word: 1234h" */
;      {
;          unsigned char *c = (unsigned char *)&wrd;
;          attr = WARM;  put_hex(c[0]);  putc(' ');  put_hex(c[1]);   /* address order */
;          attr = NORM;  puts(t_asw);  put_hex(wrd >> 8);  put_hex(wrd & 255);  puts("h");
;          row += 2;
;      }
ShowW:  mov  ax, [row]          ; AX = row
        mov  bx, ROW            ; BX = 160 bytes a row
        mul  bx                 ; AX = row * 160
        mov  di, ax             ; DI = the row start
        add  di, 6*2            ; DI += column 6
        mov  byte [attr], WARM  ; attr = yellow
        mov  al, byte [wrd]     ; AL = c[0]: the LOW cell first, address order
        call PutB               ; put_hex(c[0])
        mov  al, ' '            ; AL = ' '
        call PutC               ; putc(' ')
        mov  al, byte [wrd+1]   ; AL = c[1]
        call PutB               ; put_hex(c[1])
        mov  byte [attr], NORM  ; attr = NORM
        mov  si, t_asw          ; SI = "   as a word: "
        call PutS               ; puts()
        mov  ax, [wrd]          ; AX = wrd
        xchg al, ah             ; AL <-> AH: XCHG swaps the halves - PutB wants
        call PutB               ; put_hex(high)   the high byte first for a WORD
        xchg al, ah             ; AL <-> AH again
        call PutB               ; put_hex(low)
        mov  si, t_ash          ; SI = "h"
        call PutS               ; puts()
        add  word [row], 2      ; row += 2
        ret                     ; return
t_asw   db '   as a word: ',0
t_ash   db 'h',0

; ---- the lower screen, wiped: six frames do not fit 25 rows ---------------
;  In C:   for (i = 3*80; i < 25*80; i++) text[i] = 0x0720;   row = 3;
Fresh:  mov  di, 3*ROW          ; DI = row 3: keep the headline, clear the rest
        mov  cx, (25-3)*80      ; CX = 22 rows of 80 cells
        mov  ax, 0720h          ; AX = 0720h: a space, in grey on black
        rep  stosw              ; while (cx--) *es:di++ = ax
        mov  word [row], 3      ; row = 3
        ret                     ; return

; ---- a captioned pair of lines, then a beat --------------------------------
;  In C:   void say2(char *a, char *b) { attr = HEAD; line(a);  attr = NORM; line(b); }
Say2:   mov  byte [attr], HEAD  ; attr = white
        call Line               ; line(SI): the first, bright
        mov  si, dx             ; SI = DX, the second line
        mov  byte [attr], NORM  ; attr = NORM
        call Line               ; line(SI): the second, plain
        ret                     ; return

;  In C:
;
;      int main(void)                       /* entered THROUGH Start, which already ran */
;      {
;          *(char *)0x10C = 0xC3;           /* a RET over the doorway jmp: change() is  */
;          set_mode(3); cursor_off();       /*  a callable subroutine again              */
;          say2(t_r1, t_r2); show_w(); key();                                   /* 1 */
;          say2(t_c1, t_c2); *(int *)0x111 = 0x1234; patch(); show_w(); key();  /* 2 */
;          say2(t_p1, t_p2); change(); show_w(); key();                         /* 3 */
;          fresh(); say2(t_k1, t_k2); *(int *)0x111 = 0x9ABC; patch(); show_w(); key(); /* 4 */
;          say2(t_g1, t_g2); *(char *)0x110 = 0xBB; *(char *)0x114 = 0x1E;       /* 5 */
;                            patch(); show_w(); key();
;          say2(t_j1, t_j2); road(); *(char *)(Road+1) = RDIST; road();          /* 6 */
;                            *(char *)(Road+1) = 0; road();
;          ...the signature...  set_mode(3); exit(0);
;      }
Boot:   cld                     ; string ops count UP (STOSW, LODSB)
        ; ---- the doorway burns itself: entry used the jmp at 010C once;
        ; poke a ret over it, and Change is a callable subroutine again.
        ; The program repairs its own map by the very trick it teaches.
        mov  byte [Start+0Ch], 0C3h ; *(010Ch) = C3h: a RET where the jmp was
        jmp  short .fb          ; the rule: patch, then jump
.fb:
        mov  ax, 0003h          ; AX = 3: the text screen, 80x25
        int  10h                ; set_mode(3)
        call TextOff            ; cursor_off()
        mov  ax, TEXT           ; AX = B800h
        mov  es, ax             ; ES = the text screen

        mov  byte [attr], HEAD  ; the headline, and the subtitle under it
        mov  si, t_head         ; SI = t_head, the first line
        mov  di, 0*ROW + 30*2   ; DI = row 0, column 30
        call PutS               ; puts()
        mov  byte [attr], 08h   ; attr = 08h
        mov  si, t_sub          ; SI = t_sub, the first line
        mov  di, 1*ROW + 22*2   ; DI = row 1, column 22
        call PutS               ; puts()
        mov  word [row], 3      ; row = 3

; ---- 1. the footprint -------------------------------------------------------
        mov  si, t_r1           ; SI = t_r1, the first line
        mov  dx, t_r2           ; DX = t_r2, the second
        call Say2               ; say2(): the two captions
        call ShowW              ; 78 56: the map ran on the way in, faster
        call Key                ;  than the eye - THIS is the whole lesson

; ---- 2. the unwind ---------------------------------------------------------
        mov  si, t_c1           ; SI = t_c1, the first line
        mov  dx, t_c2           ; DX = t_c2, the second
        call Say2               ; say2(): the two captions
        mov  word [Patch+1], 1234h ; *(0111h) = 1234h: the poke, into the mov
        jmp  short .f0          ; the rule: patch, then jump
.f0:    call Patch              ; patch(): 1234h lands, swapped
        call ShowW              ; show_w(): the word, cell by cell
        call Key                ; key()

; ---- 3. the self-patch -----------------------------------------------------
        mov  si, t_p1           ; SI = t_p1, the first line
        mov  dx, t_p2           ; DX = t_p2, the second
        call Say2               ; say2(): the two captions
        call Change             ; the program rewrites its own cells...
        call ShowW              ; ...and 78 56 says it worked
        call Key                ; key()

; ---- 4. your poke ----------------------------------------------------------
        call Fresh              ; page two: the first three frames stand,
                                ;  read, and make way
        mov  si, t_k1           ; SI = t_k1, the first line
        mov  dx, t_k2           ; DX = t_k2, the second
        call Say2               ; say2(): the two captions
        mov  word [Patch+1], 9ABCh ; *(0111h) = 9ABCh: your poke
        jmp  short .f1          ; THE RULE: patch, then jump
.f1:    call Patch              ; patch(): 9ABCh lands
        call ShowW              ; show_w(): the word, cell by cell
        call Key                ; key()

; ---- 5. the registers ------------------------------------------------------
        mov  si, t_g1           ; SI = t_g1, the first line
        mov  dx, t_g2           ; DX = t_g2, the second
        call Say2               ; say2(): the two captions
        mov  byte [Patch], 0BBh ; *(0110h) = BBh: mov ax,imm16 becomes mov BX,imm16...
        mov  byte [Patch+4], 1Eh ; *(0114h) = 1Eh: ...and the write's modrm now
                                ;  says BX too
        jmp  short .f2          ; the rule again
.f2:    call Patch              ; patch(): through BX this time
        call ShowW              ; show_w(): the word, cell by cell
        call Key                ; key()

; ---- 6. the road -----------------------------------------------------------
        mov  si, t_j1           ; SI = t_j1, the first line
        mov  dx, t_j2           ; DX = t_j2, the second
        call Say2               ; say2(): the two captions
        mov  ax, [row]          ; AX = row
        mov  bx, ROW            ; BX = 160 bytes a row
        mul  bx                 ; AX = row * 160
        mov  di, ax             ; DI = the row start
        add  di, 6*2            ; DI += column 6
        mov  byte [attr], WARM  ; attr = yellow
        call Road               ; road(): DAY - the distance cell holds nought
        mov  byte [Road+1], RDIST ; *(Road+1) = RDIST: the distance to Night
        jmp  short .f3          ; the rule: patch, then jump
.f3:    call Road               ; road(): NIGHT - the same jump, poked
        mov  byte [Road+1], 0   ; *(Road+1) = 0
        jmp  short .f4          ; the rule
.f4:    call Road               ; road(): and DAY again - the road is yours
        mov  byte [attr], NORM  ; attr = NORM
        add  word [row], 2      ; row += 2

        inc  word [row]         ; row++: the signature, the way every lesson ends
        mov  byte [attr], HEAD  ; attr = HEAD
        mov  si, t_ow1          ; SI = t_ow1, the first line
        call Line               ; line(SI): one row of text
        mov  byte [attr], WARM  ; attr = WARM
        mov  si, t_ow2          ; SI = t_ow2, the first line
        call Line               ; line(SI): one row of text
        mov  byte [attr], NORM  ; attr = NORM
        mov  si, t_key          ; SI = t_key, the first line
        mov  ax, [row]          ; AX = row
        mov  bx, ROW            ; BX = 160 bytes a row
        mul  bx                 ; AX = row * 160
        mov  di, ax             ; DI = the row start
        add  di, 34*2           ; DI += column 34
        mov  byte [attr], 08h   ; attr = dark grey
        call PutS               ; puts(): "- any key -"
        call Key                ; key()

        mov  ax, 0003h          ; AX = 3: a clean screen back to DOS
        int  10h                ; set_mode(3)
        mov  ax, 4C00h          ; AH = 4Ch exit, AL = 0 the code
        int  21h                ; exit(0)

; ---- the map must BE the titles' map - or refuse to assemble ---------------
assert Start  = 100h
assert Change = 103h
assert Patch  = 110h
assert wrd    = 200h
