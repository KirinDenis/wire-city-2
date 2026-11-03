; ============================================================================
;  R2.ASM - Lesson 25, step 2. THE ADDRESSES: ANY REGISTER, TIMES 1, 2, 4
;  OR 8.
;
;      FASM R2.ASM R2.COM
;
;  Lesson 24 asked which processor this is. From here on the course writes
;  for the 80386, so every program of this lesson asks first - E_CPU.INC,
;  the lesson 24 detector with its printing taken out - and then runs 386
;  code. The 80186 and 80286 are passed over: what they added, the 386 has.
;
;  Four steps, one program growing - each the one before it and a little
;  more, each built and run:
;
;      R1   the registers: 32 bits, and the 8086's names for the low half
;      R2   the addresses: any register, times 1, 2, 4 or 8
;      R3   the new instructions
;      R4   what did NOT change
;
;  Every line of the output sets the 8086's way against the 386's, and
;  prints what each one got. They have to agree.
;
;  R1.ASM, and the addresses.
;
;  THE 8086's ADDRESSES. An instruction may name memory as a sum, and the
;  chip offers exactly these sums and no others:
;
;      [BX + SI + n]   [BX + DI + n]   [BP + SI + n]   [BP + DI + n]
;      [SI + n]        [DI + n]        [BP + n]        [BX + n]      [n]
;
;  Four registers may hold an address - BX, BP, SI and DI. [AX], [CX], [DX]
;  and [SP] do not exist, and nothing multiplies: a table of words wants its
;  index doubled first, by hand, in one of those four.
;
;  THE 386's. Any of the eight 32-bit registers as the base, any but ESP as
;  the index, the index times 1, 2, 4 or 8, and a number:
;
;      [base + index*scale + n]        [Sq + EAX*2]     [EBX + ECX*4 + 10]
;
;  The byte 67h in front says "this address is 32 bits" - lesson 24's 66h,
;  for addresses. In real mode the sum must still stay under 10000h: a
;  segment is 64 KB, as before, and past it Intel's manual has the 386 raise
;  exception 13. So the top half of an index register must be 0 - which is
;  why MOV EAX,7 below, and not MOV AX,7.
;
;  LEA - Load Effective Address - works an address out and keeps the number,
;  without reading memory and without touching the flags. With the 386's
;  addresses that makes it a small calculator: LEA EAX,[EAX+EAX*4] is EAX
;  times 5.
;
;  Owlos - legacy software modernization - https://owlos.sk
; ============================================================================
format binary as 'com'
        org  100h

        jmp  Boot               ; over the data and the routines

; ---- the text ---------------------------------------------------------------
CrLf    db 13, 10, '$'
Colon   db ':$'

Head1   db 'REGISTERS: 32 bits, the low half keeps the 8086''s name', 13, 10, '$'
TEax    db '  EAX = $'
TAx     db '   AX = $'
TAh     db '   AH = $'
TAl     db '   AL = $'
TMov    db '  MOV AX,0     EAX = $'
TStays  db '   the top half stays', 13, 10, '$'
TShr    db '  SHR EAX,16   $'
TNoName db '       the top half has no name of its own', 13, 10, '$'
TSum86  db '  100000 + 50000   8086  ADD, ADC  DX:AX = $'
TSum386 db '                   386   one ADD     EAX = $'
TTick   db '  FS: the BIOS clock, 0040:006C, one MOV = $'

;  From step 2 on, a line is a label, the 8086's answer and the 386's, in
;  columns. TIMES pads each label with spaces to column 53, so the numbers
;  line up however long the words are; a Gap after the 8086's number
;  brings the 386's to column 64.
Head2   db 'ADDRESSES: any register, times 1, 2, 4 or 8'
        times Head2+53-$ db ' '
        db '8086 got   386 got', 13, 10, '$'
TSq     db '  squares[7]   8086 doubles 7 in BX, 386 [Sq+EAX*2]'
        times TSq+53-$ db ' '
        db '$'
TPix    db '  320*y + x    8086 shifts by CL, 386 LEA and SHL'
        times TPix+53-$ db ' '
        db '$'
Gap4    db '       $'           ; after four digits: 4 + 7 = 11

; ---- a line of text ---------------------------------------------------------
;  In C:   fputs(dx, stdout);       the text ends with '$', DOS's own end
Puts:   mov  ah, 9              ; AH = 9: write a string, up to the '$'
        int  21h                ; DOS writes DS:DX
        ret

; ---- one hexadecimal digit ------------------------------------------------------
;  In C:   putchar("0123456789ABCDEF"[al & 15]);
Digit:  and  al, 0Fh            ; AL = the low four bits: 0..15
        add  al, '0'            ; AL = '0'..'9', or past '9' for 10..15
        cmp  al, '9'            ; past '9'?
        jbe  .put               ;   no: a digit as it is
        add  al, 'A' - '9' - 1  ;   yes: 7 more, so 10..15 land on 'A'..'F'
.put:   mov  dl, al             ; DL = the character
        mov  ah, 2              ; AH = 2: write one character
        int  21h                ; putchar(DL)
        ret

; ---- a number in hexadecimal: 8, 4 or 2 digits ----------------------------------
;  In C:   for (i = 0; i < n; i++) { v = rotl(v, 4); putchar(hex[v & 15]); }
;
;  ROL turns EAX round by four bits: the top digit comes out at the bottom,
;  where Digit takes it, and nothing is lost - eight turns and EAX is back.
;  Hex16 and Hex8 first move AX or AL up to the top, so the same loop works.
Hex32:  mov  cx, 8              ; CX = 8 digits: all of EAX
        jmp  HexTop
Hex16:  shl  eax, 16            ; AX up to the top half: its four digits
        mov  cx, 4              ;  lead now
        jmp  HexTop
Hex8:   shl  eax, 24            ; AL up to the top byte
        mov  cx, 2              ; CX = 2 digits
HexTop: rol  eax, 4             ; the top four bits round to the bottom
        push eax                ; Digit and DOS spoil AL: keep the rest
        call Digit              ; one digit, the low four bits of AL
        pop  eax
        loop HexTop             ; CX = CX - 1, and again while CX != 0
        ret

; ---- is this a 386? - 8086 code, short jumps ----------------------------------
        include '..\..\ENGINE\E_CPU.INC'

; ---- the program --------------------------------------------------------------
Boot:   call NEED386            ; an 8086 or 286 is told, and goes back to DOS
                                ;  - nothing above this line is 386 code

; ============================================================================
;  STEP 1 - THE REGISTERS
; ============================================================================
        mov  dx, Head1
        call Puts

        ; One register, four names. MOV EAX,... is MOV AX,... with 66h in
        ; front and four bytes of number instead of two.
        mov  dx, TEax           ; '  EAX = '
        call Puts
        mov  eax, 12345678h     ; EAX = 1234 5678h, all 32 bits
        mov  [Keep], eax        ; kept: the printing spoils EAX
        call Hex32              ; 12345678
        mov  dx, TAx            ; '   AX = '
        call Puts
        mov  eax, [Keep]
        call Hex16              ; AX, the low half: 5678
        mov  dx, TAh            ; '   AH = '
        call Puts
        mov  eax, [Keep]
        mov  al, ah             ; AL = AH: the second byte
        call Hex8               ; 56
        mov  dx, TAl            ; '   AL = '
        call Puts
        mov  eax, [Keep]
        call Hex8               ; AL, the lowest byte: 78
        mov  dx, CrLf
        call Puts

        ; Write the low half, and the top half stays as it was.
        mov  dx, TMov           ; '  MOV AX,0     EAX = '
        call Puts
        mov  eax, [Keep]        ; EAX = 12345678h
        mov  ax, 0              ; AX = 0 - and bits 16-31 untouched
        call Hex32              ; 12340000
        mov  dx, TStays
        call Puts

        ; The top half has no name: shift it down to where AX is.
        mov  dx, TShr           ; '  SHR EAX,16   '
        call Puts
        mov  eax, [Keep]
        shr  eax, 16            ; bits 16-31 down to 0-15: EAX = 1234h
        call Hex16              ; 1234
        mov  dx, TNoName
        call Puts

        ; 100000 + 50000 = 150000: too big for 16 bits (65535 at most).
        ; The 8086 holds such a number in TWO registers, DX the top half
        ; and AX the bottom, and adds it in two steps:
        ;
        ;     100000 = 0001 86A0h      86A0 + C350 = 1 49F0: the low
        ;      50000 = 0000 C350h       halves overflow, CF = 1, and ADC
        ;                               adds that 1 into the top halves
        mov  ax, 86A0h          ; DX:AX = 100000 = 0001 86A0h
        mov  dx, 0001h
        mov  bx, 0C350h         ; CX:BX =  50000 = 0000 C350h
        mov  cx, 0000h
        add  ax, bx             ; AX = 86A0 + C350 = 49F0, CF = 1
        adc  dx, cx             ; DX = 1 + 0 + CF = 2
        mov  [Lo16], ax         ; kept: the printing spoils them
        mov  [Hi16], dx
        mov  dx, TSum86         ; '... DX:AX = '
        call Puts
        mov  ax, [Hi16]
        call Hex16              ; 0002
        mov  dx, Colon
        call Puts
        mov  ax, [Lo16]
        call Hex16              ; 49F0
        mov  dx, CrLf
        call Puts

        ; The 386: one register holds it, one ADD adds it. The carry out
        ; of bit 15 runs on into bit 16 inside the adder.
        mov  eax, 100000        ; EAX = 0001 86A0h
        mov  ebx, 50000         ; EBX = 0000 C350h
        add  eax, ebx           ; EAX = 0002 49F0h = 150000
        push eax
        mov  dx, TSum386        ; '... EAX = '
        call Puts
        pop  eax
        call Hex32              ; 000249F0
        mov  dx, CrLf
        call Puts

        ; FS, a new segment register. The BIOS counts its clock ticks, 18.2
        ; a second, in a double word at 0040:006C - the time since midnight.
        ; The 8086 reads it as two words, in two instructions; the 386 in
        ; one, and no tick can fall between the halves: an interrupt comes
        ; only between instructions, never inside one.
        mov  dx, TTick          ; '  FS: the BIOS clock ... = '
        call Puts
        mov  ax, 0040h          ; the BIOS's data segment
        mov  fs, ax             ; FS = 0040h - DS still points at us
        mov  eax, [fs:006Ch]    ; EAX = the ticks, all 32 bits at once
        call Hex32
        mov  dx, CrLf
        call Puts

; ============================================================================
;  STEP 2 - THE ADDRESSES
; ============================================================================
        mov  dx, Head2
        call Puts

        ; Item 7 of a table of words: 7 * 2 = 14 bytes in. The 8086 has to
        ; get the 7 into one of its four address registers and double it.
        mov  dx, TSq
        call Puts
        mov  ax, 7              ; AX = 7, the index - but [AX] does not exist
        mov  bx, ax             ; BX = 7: BX may hold an address
        shl  bx, 1              ; BX = 14: two bytes a word
        mov  ax, [Squares+bx]   ; AX = squares[7] = 49 = 0031h
        call Hex16
        mov  dx, Gap4
        call Puts
        ; The 386 doubles it inside the address: [Sq + EAX*2]. FASM wrote
        ; 67 8B 84 00 and four bytes of Squares - 67h for a 32-bit address,
        ; and the 00 says EAX + EAX: the same sum, the way FASM likes it.
        mov  eax, 7             ; EAX = 7: ALL 32 bits, the top half 0
        mov  ax, [Squares+eax*2]  ; AX = squares[7]; EAX's top half stays 0
        call Hex32              ; 00000031
        mov  dx, CrLf
        call Puts

        ; Where pixel (x, y) = (100, 50) lies in the 320-wide screen of
        ; mode 13h: 320*y + x. 320 = 256 + 64, so two shifts and an add.
        ; The 8086 shifts by 1 or by CL, nothing else.
        mov  dx, TPix
        call Puts
        mov  ax, 50             ; AX = y = 50
        mov  bx, ax             ; BX = y
        mov  cl, 8              ; CL = 8
        shl  ax, cl             ; AX = y*256 = 12800
        mov  cl, 6              ; CL = 6
        shl  bx, cl             ; BX = y*64 = 3200
        add  ax, bx             ; AX = y*320 = 16000
        add  ax, 100            ; AX = y*320 + x = 16100 = 3EE4h
        call Hex16
        mov  dx, Gap4
        call Puts
        ; The 386: LEA makes y*5 out of an address it never reads, and a
        ; shift by a number written in the instruction - the 186's - makes
        ; it y*320. 5 * 64 = 320.
        mov  eax, 50            ; EAX = y = 50
        lea  eax, [eax+eax*4]   ; EAX = y + y*4 = y*5 = 250, no memory read
        shl  eax, 6             ; EAX = y*5*64 = y*320 = 16000
        add  eax, 100           ; EAX = y*320 + x = 16100 = 00003EE4h
        call Hex32
        mov  dx, CrLf
        call Puts

Bye:    mov  ax, 4C00h          ; AH = 4Ch exit, AL = 0 the code
        int  21h                ; exit(0)

; ---- the numbers ------------------------------------------------------------
Keep    dd 0                    ; a number kept while another is printed
Lo16    dw 0                    ; the 8086's sum: the low half...
Hi16    dw 0                    ;  ...and the high half

;  The squares of 0 to 15, a word each: squares[i] is i*2 bytes in.
Squares dw 0, 1, 4, 9, 16, 25, 36, 49, 64, 81, 100, 121, 144, 169, 196, 225
