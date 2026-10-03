; ============================================================================
;  KEYS.ASM - Lesson 11. The keyboard is a computer.
;
;      FASM KEYS.ASM KEYS.COM
;
;      1  the port      IN from 60h: the wire itself. Press = the KEY's
;                       number; release = the same number + 80h. No letters
;                       anywhere - letters are made upstairs.
;      2  the BIOS      INT 16h: the pair - scan code AND the ASCII the
;                       BIOS minted from it. Then the TRAP: five busy
;                       seconds, and the 16-cell buffer answers for them.
;      3  DOS           INT 21h: a whole line, edited for free - the
;                       highest floor does the most and hears the last.
;      4  the game      our own INT 9: a KEYS table, one cell per key,
;                       and the square drives diagonally - two keys HELD
;                       at once, which no floor above the wire can say.
;
;  THE ONE FACT THIS LESSON HANDS OVER: the keyboard is a computer of its
;  own. It sends the NUMBER of a KEY down the wire - the scan code - and
;  everything else is floors built on top: the BIOS turns numbers into
;  letters and queues them, DOS turns letters into lines. A game asks a
;  question none of those floors can answer - "which keys are held DOWN,
;  right now?" - so it unplugs the BIOS and listens to the wire itself.
;  OWL FLY's cockpit reads a KEYS table exactly like frame four's.
;
;  Owlos - legacy software modernization - https://owlos.sk
; ============================================================================
format binary as 'com'
        org  100h

TEXT    = 0B800h                ; the text screen: 80x25, TWO bytes a cell
VGA     = 0A000h                ; the graphics screen: 320x200, one byte
W       = 320
H       = 200
ROW     = 160                   ; a text row is 160 BYTES - two per cell

NORM    = 07h                   ; grey on black
HEAD    = 0Fh                   ; white
PAIR    = 0Eh                   ; yellow: a scan code, fresh off the wire
GOOD    = 0Ah                   ; green: the character a code became
DIMC    = 08h                   ; dark grey: a release - the same key, going
BOXC    = 15                    ; the square, white

        jmp  Boot               ; over the tables and routines, to the boot

; ---- what the frames say ---------------------------------------------------
t_head  db 'THE KEYBOARD IS A COMPUTER',0
t_p1    db 'PORT 60h - the wire itself. Press keys; watch the bytes. ESC ends.',0
t_p2    db 'press = the KEY''s number    release = the same number + 80h',0
t_b1    db 'INT 16h - the BIOS floor. Every key comes back as a PAIR:',0
t_b2    db 'scan code : ASCII = character.  ESC springs the trap.',0
t_b3    db 'BUSY for five seconds - type NOW, into the silence...',0
t_b4    db '...and here is everything the 16-cell BUFFER kept for us:',0
t_d1    db 'INT 21h - the DOS floor. A whole line, edited for free:',0
t_d2    db 'YOU TYPED: ',0
t_dp    db 13,10,'  > $'        ; DOS prints up to '$' - CP/M's mark, kept
t_g1    db 'Now we unplug the BIOS and listen to the wire ourselves.',0
t_g2    db 'Arrows drive the square. TWO arrows - a diagonal. ESC leaves.',0
t_key   db '- any key -',0

; ---- state -----------------------------------------------------------------
last    db 0                    ; the port frame: the byte we already showed
keys    db 128 dup (0)          ; one cell per key: 1 = held, 0 = up
old9o   dw 0                    ; where INT 9 pointed before us - offset...
old9s   dw 0                    ; ...and segment: unplug politely, replug too
bxp     dw 154                  ; the square's top-left corner
byp     dw 94
kbuf    db 30, 0, 30 dup (0)    ; DOS line input: room, count, the text

include 'DRAW11.INC'

; ============================================================================
;  Int9 - OUR keyboard driver: sixteen instructions, the whole job.
;
;  IRET is new: an interrupt ends with IRET, not RET - the interrupt
;  pushed the FLAGS as well as the address, and IRET pops all three.
;  ROL is new: rotate left - the bit pushed out at the top comes back in
;  at the bottom, so bit 7 lands in bit 0 in one step. And OUT is IN's
;  twin, port writing: the 20h sent to port 20h is the END OF INTERRUPT
;  nod to the interrupt controller - forget it, and it politely never
;  rings again: the machine's keyboard is dead until the reset button.
;
;  CS: on the table, because DS is NOT OURS here - the interrupt fires
;  in the middle of whoever was running, with THEIR registers.
; ============================================================================
;  In C:
;
;      void interrupt int9(void)             /* the CPU calls it, on every key */
;      {
;          unsigned char b = inp(0x60);      /* the byte off the wire         */
;          keys[b & 0x7F] = !(b >> 7);       /* bit 7 set = released          */
;          outp(0x20, 0x20);                 /* EOI, or it never rings again  */
;      }
;
;  The `interrupt` keyword is what IRET and the pushes are: C compilers for
;  DOS had it, and it means exactly "save what you touch, and return with
;  the flags". There is no keyword for [cs:]: C assumes DS is yours.
Int9:   push ax                 ; keep AX and BX: this is somebody else's moment
        push bx                 ; (the pair)
        in   al, 60h            ; AL = inp(0x60): the byte, straight off the wire
        mov  bl, al             ; BL = b
        and  bx, 007Fh          ; BX = b & 0x7F: the KEY number, bit 7 stripped
        rol  al, 1              ; AL = b rotated left: bit 7 (the release flag) into bit 0...
        and  al, 1              ; AL &= 1: ...alone: 1 = released
        xor  al, 1              ; AL ^= 1: ...flipped: 1 = HELD - the table's word
        mov  [cs:keys+bx], al   ; keys[BX] = AL: one cell per key, and no queue at all
        mov  al, 20h            ; AL = 20h
        out  20h, al            ; outp(0x20, 0x20): EOI, "taken" - or INT 9 never fires again
        pop  bx                 ; BX back
        pop  ax                 ; AX back
        iret                    ; return, flags and all

; ---- PutPair: AH = scan, AL = ascii -> "38:61=a " at ES:DI -------------------
;  In C:
;
;      void put_pair(int scan, int ascii)        /* "38:61=a " */
;      {
;          attr = PAIR;  put_hex(scan);  putc(':');  put_hex(ascii);  putc('=');
;          attr = GOOD;  putc(ascii);
;          attr = NORM;  putc(' ');
;          if (di >= 22*ROW) di = 8*ROW + 2*2;    /* the screen is not endless */
;      }
PutPair:
        push ax                 ; keep the pair
        mov  byte [attr], PAIR  ; attr = yellow
        mov  al, ah             ; AL = scan
        call PutB               ; put_hex(scan): the scan code first, the wire's word
        mov  al, ':'            ; AL = ':'
        call PutC               ; putc(':')
        pop  ax                 ; AL = ascii
        push ax                 ; keep it again
        call PutB               ; put_hex(ascii): then the ASCII the BIOS minted
        mov  al, '='            ; AL = '='
        call PutC               ; putc('=')
        pop  ax                 ; AL = ascii
        mov  byte [attr], GOOD  ; attr = green
        call PutC               ; putc(ascii): the character itself, in the flesh
        mov  byte [attr], NORM  ; attr = NORM
        mov  al, ' '            ; AL = ' '
        call PutC               ; putc(' ')
        cmp  di, 22*ROW         ; di >= row 22 ?  the screen is not endless
        jb   .ok                ;   no
        mov  di, 8*ROW + 2*2    ;   yes: DI = row 8, column 2 - wrap home
.ok:    ret                     ; return

;  In C, the four frames:
;
;      int main(void)
;      {
;          set_mode(3); cursor_off();
;          /* 1 */ for (;;) { b = inp(0x60); if (b == last) continue; last = b;
;                             if (b == 1) break; attr = b < 0x80 ? PAIR : DIMC; put_hex(b); }
;                  key_flush();
;          /* 2 */ while ((k = key()) != ESC) put_pair(k);  hold5();
;                  while (key_waiting()) put_pair(key());
;          /* 3 */ dos_puts(t_dp); dos_gets(kbuf); puts(kbuf + 2);
;          /* 4 */ old9 = int_vector[9]; int_vector[9] = int9;   set_mode(0x13);
;                  do { vsync(); box(0); if (keys[UP]) ...; box(BOXC); } while (!keys[ESC]);
;                  int_vector[9] = old9;
;      }
Boot:   cld                     ; string ops count UP (STOSW, LODSB)
        mov  ax, 0003h          ; AX = 3: the text screen, 80x25
        int  10h                ; set_mode(3)
        call TextOff            ; cursor_off()
        mov  ax, TEXT           ; AX = B800h
        mov  es, ax             ; ES = the text screen

; ---- 1. the port: the wire itself -------------------------------------------
        mov  byte [attr], HEAD  ; attr = HEAD
        mov  si, t_head         ; SI = t_head
        mov  di, 0*ROW + 27*2   ; DI = row 0, column 27
        call PutS               ; puts()
        mov  byte [attr], NORM  ; attr = NORM
        mov  si, t_p1           ; SI = t_p1
        mov  di, 2*ROW + 2*2    ; DI = row 2, column 2
        call PutS               ; puts()
        mov  si, t_p2           ; SI = t_p2
        mov  di, 3*ROW + 2*2    ; DI = row 3, column 2
        call PutS               ; puts()
        mov  di, 6*ROW + 2*2    ; DI = row 6, column 2: where the bytes will land
.port:  in   al, 60h            ; AL = b = inp(0x60). IN with a NUMBER is new:
                                ;  ports below 256 fit in the instruction
                                ;  itself. 60h holds the LAST byte the keyboard
                                ;  sent - a latch, not a queue: read it twice,
                                ;  get the same byte twice
        cmp  al, [last]         ; b == last ?  so only a CHANGE is worth printing
        je   .port              ;   yes: read again
        mov  [last], al         ; last = b
        cmp  al, 1              ; b == 1 ?  scan 01 is ESC's press: the frame is done
        je   .pdone             ;   yes: out
        mov  byte [attr], PAIR  ; attr = yellow
        cmp  al, 80h            ; b < 80h ?  releases in the dim grey - same
        jb   .pc                ;   yes: a press   number, top bit up, the key
        mov  byte [attr], DIMC  ;   no:  attr = dim grey   on its way out
.pc:    call PutB               ; put_hex(b)
        mov  byte [attr], NORM  ; attr = NORM
        mov  al, ' '            ; AL = ' '
        call PutC               ; putc(' ')
        cmp  di, 22*ROW         ; di >= row 22 ?  wrap before the hint line
        jb   .port              ;   no: next byte
        mov  di, 6*ROW + 2*2    ;   yes: DI = row 6, column 2
        jmp  .port              ; next byte
.pdone: call KeyFlush           ; key_flush(): the BIOS heard every one of those
                                ;  keys too, and queued them - empty its buffer
                                ;  or frame two starts pre-typed

; ---- 2. the BIOS: the pair, then the trap ------------------------------------
        call TClear             ; tclear()
        mov  byte [attr], HEAD  ; attr = HEAD
        mov  si, t_head         ; SI = t_head
        mov  di, 0*ROW + 27*2   ; DI = row 0, column 27
        call PutS               ; puts()
        mov  byte [attr], NORM  ; attr = NORM
        mov  si, t_b1           ; SI = t_b1
        mov  di, 2*ROW + 2*2    ; DI = row 2, column 2
        call PutS               ; puts()
        mov  si, t_b2           ; SI = t_b2
        mov  di, 3*ROW + 2*2    ; DI = row 3, column 2
        call PutS               ; puts()
        mov  di, 8*ROW + 2*2    ; DI = row 8, column 2
.bios:  call Key                ; k = key(): AH=0 WAITS, the buffer hands over a pair
        cmp  al, 27             ; k == ESC ?  the ESCAPE CHARACTER this time -
        je   .btrap             ;   yes: the trap   ASCII, because on this floor letters exist
        call PutPair            ; put_pair(k)
        jmp  .bios              ; the next key
.btrap: mov  si, t_b3           ; SI = t_b3
        mov  di, 14*ROW + 2*2   ; DI = row 14, column 2
        call PutS               ; puts()
        call Hold5              ; hold5(): five seconds of deliberate deafness -
                                ;  type into them, the wire still works
        mov  si, t_b4           ; SI = t_b4
        mov  di, 16*ROW + 2*2   ; DI = row 16, column 2
        call PutS               ; puts()
        mov  di, 18*ROW + 2*2   ; DI = row 18, column 2
.drain: mov  ah, 1              ; key_waiting()?  asked WITHOUT waiting
        int  16h                ; ZF set = the buffer is empty
        jz   .bdone             ;   empty: done
        mov  ah, 0              ; k = key(): take it...
        int  16h                ; AL = the character, AH = the scan code
        call PutPair            ; put_pair(k): ...and show what the buffer remembered
        jmp  .drain             ; the next one
.bdone: call Bottom             ; bottom()
        call Key                ; key()

; ---- 3. DOS: a whole line ----------------------------------------------------
        call TClear             ; tclear()
        mov  byte [attr], HEAD  ; attr = HEAD
        mov  si, t_head         ; SI = t_head
        mov  di, 0*ROW + 27*2   ; DI = row 0, column 27
        call PutS               ; puts()
        mov  byte [attr], NORM  ; attr = NORM
        mov  si, t_d1           ; SI = t_d1
        mov  di, 2*ROW + 2*2    ; DI = row 2, column 2
        call PutS               ; puts()
        mov  ah, 2              ; AH = 2: set cursor - park the DOS cursor under
        mov  bh, 0              ; BH = 0    our text: DOS prints where the BIOS
        mov  dx, 0400h          ; DX = row 4, column 0   cursor is
        int  10h                ; gotoxy(0, 4)
        mov  dx, t_dp           ; DX = the prompt
        mov  ah, 9              ; AH = 9: DOS print string, up to the $
        int  21h                ; dos_puts(t_dp): DOS prints the prompt...
        mov  dx, kbuf           ; DX = the buffer: room, count, the text
        mov  ah, 0Ah            ; AH = 0Ah: DOS buffered input
        int  21h                ; dos_gets(kbuf): ...and DOS reads the line.
                                ;  Backspace, the 30-column limit, the beep past
                                ;  it - all free of charge, all of it DOS
        mov  byte [attr], NORM  ; attr = NORM
        mov  si, t_d2           ; SI = t_d2, "YOU TYPED: "
        mov  di, 8*ROW + 2*2    ; DI = row 8, column 2
        call PutS               ; puts()
        mov  bl, [kbuf+1]       ; BL = kbuf[1], the count: DOS counted for us...
        mov  bh, 0              ; BX = the count
        mov  byte [kbuf+2+bx], 0 ; kbuf[2 + count] = 0: ...so cap the text there
        mov  byte [attr], GOOD  ; attr = green
        mov  si, kbuf+2         ; SI = kbuf + 2, the text
        call PutS               ; puts()
        call Bottom             ; bottom()
        call Key                ; key()

; ---- 4. the game: unplug the BIOS --------------------------------------------
        call TClear             ; tclear()
        mov  byte [attr], HEAD  ; attr = HEAD
        mov  si, t_head         ; SI = t_head
        mov  di, 0*ROW + 27*2   ; DI = row 0, column 27
        call PutS               ; puts()
        mov  byte [attr], NORM  ; attr = NORM
        mov  si, t_g1           ; SI = t_g1
        mov  di, 3*ROW + 2*2    ; DI = row 3, column 2
        call PutS               ; puts()
        mov  si, t_g2           ; SI = t_g2
        mov  di, 5*ROW + 2*2    ; DI = row 5, column 2
        call PutS               ; puts()
        call Bottom             ; bottom(): "- any key -"
        call Key                ; key()
        xor  ax, ax             ; AX = 0
        mov  es, ax             ; ES = segment ZERO: the interrupt vector table,
                                ;  256 addresses, four bytes each
        cli                     ; interrupts OFF. CLI is new: while the two
                                ;  halves of the address change - half-old,
                                ;  half-new is a jump into nowhere
        mov  ax, [es:9*4]       ; AX = vector[9].offset
        mov  [old9o], ax        ; old9o = AX: remember where INT 9 pointed - the
        mov  ax, [es:9*4+2]     ; AX = vector[9].segment   BIOS gets its keyboard
        mov  [old9s], ax        ; old9s = AX               back on the way out
        mov  word [es:9*4], Int9 ; vector[9].offset = Int9
        mov  [es:9*4+2], cs     ; vector[9].segment = cs
        sti                     ; interrupts on: STI, and the door is open again
        mov  ax, 0013h          ; AX = 13h: the graphics screen, 320x200
        int  10h                ; set_mode(0x13)
        mov  ax, VGA            ; AX = A000h
        mov  es, ax             ; ES = the graphics screen
.game:  call Vsync              ; vsync()
        xor  al, al             ; AL = 0: erase, the square repainted in black
        call Box                ; box(0)
        cmp  byte [keys+48h], 0 ; keys[UP] ?  HELD - not "arrived": HELD
        je   .g1                ;   no
        cmp  word [byp], 4      ; byp < 4 ?  the top edge
        jb   .g1                ;   yes: stay
        sub  word [byp], 2      ; byp -= 2
.g1:    cmp  byte [keys+50h], 0 ; keys[DOWN] ?
        je   .g2                ;   no
        cmp  word [byp], H-16   ; byp > 184 ?  the bottom edge
        ja   .g2                ;   yes: stay
        add  word [byp], 2      ; byp += 2
.g2:    cmp  byte [keys+4Bh], 0 ; keys[LEFT] ?
        je   .g3                ;   no
        cmp  word [bxp], 4      ; bxp < 4 ?
        jb   .g3                ;   yes: stay
        sub  word [bxp], 2      ; bxp -= 2
.g3:    cmp  byte [keys+4Dh], 0 ; keys[RIGHT] ?
        je   .g4                ;   no
        cmp  word [bxp], W-16   ; bxp > 304 ?
        ja   .g4                ;   yes: stay
        add  word [bxp], 2      ; bxp += 2
.g4:    mov  al, BOXC           ; AL = white
        call Box                ; box(BOXC)
        cmp  byte [keys+1], 0   ; keys[ESC] ?  OUR cell now; the BIOS hears nothing
        je   .game              ;   no: another frame
        xor  ax, ax             ; AX = 0       give the keyboard back: the old
        mov  es, ax             ; ES = 0       address, both halves, behind
        cli                     ; interrupts off     closed interrupts
        mov  ax, [old9o]        ; AX = old9o
        mov  [es:9*4], ax       ; vector[9].offset = old9o
        mov  ax, [old9s]        ; AX = old9s
        mov  [es:9*4+2], ax     ; vector[9].segment = old9s
        sti                     ; interrupts on

Bye:    mov  ax, 0003h          ; AX = 3: a clean screen back to DOS
        int  10h                ; set_mode(3)
        mov  ax, 4C00h          ; AH = 4Ch exit, AL = 0 the code
        int  21h                ; exit(0)
