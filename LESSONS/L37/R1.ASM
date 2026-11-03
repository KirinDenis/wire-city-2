; ============================================================================
;  R1.ASM - Lesson 25, step 1. THE REGISTERS: WHAT THE 8086 HAD, WHAT THE 386
;  MADE OF THEM.
;
;      FASM R1.ASM R1.COM
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
;  THE 386's REGISTERS, ALL 32 BITS WIDE
;
;      EAX  EBX  ECX  EDX  ESI  EDI  EBP  ESP     EFLAGS  EIP
;
;  The low 16 bits of each keep the 8086's name: AX is the low half of EAX,
;  and AH and AL are still the two bytes of AX. The top half has NO name:
;  the only way to it is a shift or a rotate.
;
;      EAX  |      top half: no name      |    AH    |    AL    |
;           31                          16 15       8 7        0
;                                         |-------- AX ---------|
;
;  Writing AX leaves the top half alone. And two new segment registers,
;  FS and GS: four places to point at, not two (DS and ES).
;
;  THE PHYSICAL FACT. The 386's adder is 32 wires wide. The carry out of
;  bit 15, which the 8086 drops into the carry flag for ADC to pick up,
;  runs on into bit 16 inside the chip.
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

Bye:    mov  ax, 4C00h          ; AH = 4Ch exit, AL = 0 the code
        int  21h                ; exit(0)

; ---- the numbers ------------------------------------------------------------
Keep    dd 0                    ; a number kept while another is printed
Lo16    dw 0                    ; the 8086's sum: the low half...
Hi16    dw 0                    ;  ...and the high half
