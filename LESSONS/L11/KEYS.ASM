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

        jmp  Boot

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
Int9:   push ax
        push bx
        in   al, 60h            ; the byte, straight off the wire
        mov  bl, al
        and  bx, 007Fh          ; the KEY number: bit 7 stripped
        rol  al, 1              ; bit 7 (the release flag) into bit 0...
        and  al, 1              ; ...alone: 1 = released
        xor  al, 1              ; ...flipped: 1 = HELD - the table's word
        mov  [cs:keys+bx], al   ; one cell per key, and no queue at all
        mov  al, 20h
        out  20h, al            ; EOI: "taken" - or INT 9 never fires again
        pop  bx
        pop  ax
        iret

; ---- PutPair: AH = scan, AL = ascii -> "38:61=a " at ES:DI -------------------
PutPair:
        push ax
        mov  byte [attr], PAIR
        mov  al, ah
        call PutB               ; the scan code first: the wire's word
        mov  al, ':'
        call PutC
        pop  ax
        push ax
        call PutB               ; then the ASCII the BIOS minted
        mov  al, '='
        call PutC
        pop  ax
        mov  byte [attr], GOOD
        call PutC               ; then the character itself, in the flesh
        mov  byte [attr], NORM
        mov  al, ' '
        call PutC
        cmp  di, 22*ROW         ; the screen is not endless: wrap home
        jb   .ok
        mov  di, 8*ROW + 2*2
.ok:    ret

Boot:   cld
        mov  ax, 0003h          ; the text screen, 80x25
        int  10h
        call TextOff
        mov  ax, TEXT
        mov  es, ax

; ---- 1. the port: the wire itself -------------------------------------------
        mov  byte [attr], HEAD
        mov  si, t_head
        mov  di, 0*ROW + 27*2
        call PutS
        mov  byte [attr], NORM
        mov  si, t_p1
        mov  di, 2*ROW + 2*2
        call PutS
        mov  si, t_p2
        mov  di, 3*ROW + 2*2
        call PutS
        mov  di, 6*ROW + 2*2    ; where the bytes will land
.port:  in   al, 60h            ; IN with a NUMBER is new: ports below 256
                                ;  fit in the instruction itself. 60h holds
                                ;  the LAST byte the keyboard sent - a
                                ;  latch, not a queue: read it twice, get
                                ;  the same byte twice.
        cmp  al, [last]         ; so only a CHANGE is worth printing
        je   .port
        mov  [last], al
        cmp  al, 1              ; scan 01 is ESC's press: the frame is done
        je   .pdone
        mov  byte [attr], PAIR
        cmp  al, 80h            ; releases in the dim grey - same number,
        jb   .pc                ;  top bit up, the key on its way out
        mov  byte [attr], DIMC
.pc:    call PutB
        mov  byte [attr], NORM
        mov  al, ' '
        call PutC
        cmp  di, 22*ROW         ; wrap before the hint line
        jb   .port
        mov  di, 6*ROW + 2*2
        jmp  .port
.pdone: call KeyFlush           ; the BIOS heard every one of those keys
                                ;  too, and queued them - empty its buffer
                                ;  or frame two starts pre-typed

; ---- 2. the BIOS: the pair, then the trap ------------------------------------
        call TClear
        mov  byte [attr], HEAD
        mov  si, t_head
        mov  di, 0*ROW + 27*2
        call PutS
        mov  byte [attr], NORM
        mov  si, t_b1
        mov  di, 2*ROW + 2*2
        call PutS
        mov  si, t_b2
        mov  di, 3*ROW + 2*2
        call PutS
        mov  di, 8*ROW + 2*2
.bios:  call Key                ; AH=0 WAITS: the buffer hands over a pair
        cmp  al, 27             ; the ESCAPE CHARACTER this time - ASCII,
        je   .btrap             ;  because on this floor letters exist
        call PutPair
        jmp  .bios
.btrap: mov  si, t_b3
        mov  di, 14*ROW + 2*2
        call PutS
        call Hold5              ; five seconds of deliberate deafness -
                                ;  type into them, the wire still works
        mov  si, t_b4
        mov  di, 16*ROW + 2*2
        call PutS
        mov  di, 18*ROW + 2*2
.drain: mov  ah, 1              ; anything queued? - asked WITHOUT waiting
        int  16h
        jz   .bdone
        mov  ah, 0
        int  16h                ; take it...
        call PutPair            ; ...and show what the buffer remembered
        jmp  .drain
.bdone: call Bottom
        call Key

; ---- 3. DOS: a whole line ----------------------------------------------------
        call TClear
        mov  byte [attr], HEAD
        mov  si, t_head
        mov  di, 0*ROW + 27*2
        call PutS
        mov  byte [attr], NORM
        mov  si, t_d1
        mov  di, 2*ROW + 2*2
        call PutS
        mov  ah, 2              ; park the DOS cursor under our text -
        mov  bh, 0              ;  DOS prints where the BIOS cursor is,
        mov  dx, 0400h          ;  row 4, column 0
        int  10h
        mov  dx, t_dp
        mov  ah, 9              ; DOS prints the prompt...
        int  21h
        mov  dx, kbuf
        mov  ah, 0Ah            ; ...and DOS reads the line: Backspace,
        int  21h                ;  the 30-column limit, the beep past it -
                                ;  all of it free of charge, all of it DOS
        mov  byte [attr], NORM
        mov  si, t_d2
        mov  di, 8*ROW + 2*2
        call PutS
        mov  bl, [kbuf+1]       ; DOS counted the characters for us...
        mov  bh, 0
        mov  byte [kbuf+2+bx], 0 ; ...so cap the text where the count says
        mov  byte [attr], GOOD
        mov  si, kbuf+2
        call PutS
        call Bottom
        call Key

; ---- 4. the game: unplug the BIOS --------------------------------------------
        call TClear
        mov  byte [attr], HEAD
        mov  si, t_head
        mov  di, 0*ROW + 27*2
        call PutS
        mov  byte [attr], NORM
        mov  si, t_g1
        mov  di, 3*ROW + 2*2
        call PutS
        mov  si, t_g2
        mov  di, 5*ROW + 2*2
        call PutS
        call Bottom
        call Key
        xor  ax, ax
        mov  es, ax             ; segment ZERO: the interrupt vector table,
                                ;  256 addresses, four bytes each
        cli                     ; CLI is new: interrupts OFF while the two
                                ;  halves of the address change - half-old,
                                ;  half-new is a jump into nowhere
        mov  ax, [es:9*4]
        mov  [old9o], ax        ; remember where INT 9 pointed - the BIOS
        mov  ax, [es:9*4+2]     ;  gets its keyboard back on the way out
        mov  [old9s], ax
        mov  word [es:9*4], Int9
        mov  [es:9*4+2], cs
        sti                     ; STI: and the door is open again
        mov  ax, 0013h          ; the graphics screen, 320x200
        int  10h
        mov  ax, VGA
        mov  es, ax
.game:  call Vsync
        xor  al, al             ; erase: the square repainted in black
        call Box
        cmp  byte [keys+48h], 0 ; up arrow HELD? - not "arrived": HELD
        je   .g1
        cmp  word [byp], 4
        jb   .g1
        sub  word [byp], 2
.g1:    cmp  byte [keys+50h], 0 ; down
        je   .g2
        cmp  word [byp], H-16
        ja   .g2
        add  word [byp], 2
.g2:    cmp  byte [keys+4Bh], 0 ; left
        je   .g3
        cmp  word [bxp], 4
        jb   .g3
        sub  word [bxp], 2
.g3:    cmp  byte [keys+4Dh], 0 ; right
        je   .g4
        cmp  word [bxp], W-16
        ja   .g4
        add  word [bxp], 2
.g4:    mov  al, BOXC
        call Box
        cmp  byte [keys+1], 0   ; ESC - OUR cell now; the BIOS hears nothing
        je   .game
        xor  ax, ax             ; give the keyboard back: the old address,
        mov  es, ax             ;  both halves, behind closed interrupts
        cli
        mov  ax, [old9o]
        mov  [es:9*4], ax
        mov  ax, [old9s]
        mov  [es:9*4+2], ax
        sti

Bye:    mov  ax, 0003h          ; a clean screen back to DOS
        int  10h
        mov  ax, 4C00h
        int  21h
