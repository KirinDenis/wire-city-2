; ============================================================================
;  R3.ASM - Lesson 25, step 3. THE NEW INSTRUCTIONS: ONE WHERE THE 8086
;  NEEDED SEVERAL.
;
;      FASM R3.ASM R3.COM
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
;  R2.ASM, and the new instructions. Each one does what took the 8086
;  several instructions, or a loop:
;
;      MOVZX r, byte    a byte made wider, the new bits 0. No flags.
;                       8086: MOV AL,... and MOV AH,0
;      MOVSX r, byte    a byte made wider, the new bits copies of its sign
;                       bit, so -5 stays -5. No flags. The S is for SIGN:
;                       it is not MOVSB or MOVSD, which copy strings.
;                       8086: MOV AL,... and CBW - and into AX only
;      IMUL  r, r       any register times any register, into the first.
;                       CF and OF say the answer did not fit.
;                       8086: one operand only - AX times it, the answer
;                       in DX:AX, and DX is spoilt whether you wanted it
;      SETcc r8         a condition made a byte, 0 or 1, without a jump:
;                       SETL "less", SETZ "zero"... No flags changed.
;                       8086: a MOV, a jump, and a MOV jumped over
;      BSR   r, r       the number of the highest 1 bit - BSF, the lowest.
;                       ZF = 1 if there is no 1 at all, and then the
;                       answer means nothing.
;                       8086: shift until a 1 falls out, counting
;
;  And more, named here only: BT, BTS, BTR and BTC test one bit and set,
;  clear or turn it over; SHLD and SHRD shift through two registers; and
;  a conditional jump now reaches anywhere in the segment - 0F 8x, the
;  very jump that hung lesson 24's 186. From the 186, which the 386 has
;  as well: a shift by a number written in the instruction, PUSH of a
;  number, PUSHA and POPA.
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

Head3   db 'NEW INSTRUCTIONS: one where the 8086 needed several'
        times Head3+53-$ db ' '
        db '8086 got   386 got', 13, 10, '$'
TZx     db '  MOVZX  200, a byte made wider, the top 0'
        times TZx+53-$ db ' '
        db '$'
TSx     db '  MOVSX  -5, a byte made wider, the top its sign'
        times TSx+53-$ db ' '
        db '$'
TMul    db '  IMUL   1000 * 300, into any register'
        times TMul+53-$ db ' '
        db '$'
TSet    db '  SETL   is 5 less than 9? - with no jump'
        times TSet+53-$ db ' '
        db '$'
TBsr    db '  BSR    the highest 1 bit of 320 - no loop'
        times TBsr+53-$ db ' '
        db '$'
Gap9    db '  $'                ; after DX:AX, nine characters: 9 + 2 = 11
Gap2    db '         $'         ; after two digits: 2 + 9 = 11

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

; ============================================================================
;  STEP 3 - THE NEW INSTRUCTIONS
; ============================================================================
        mov  dx, Head3
        call Puts

        ; A byte made a word: 200 is C8h, and the top byte must be 0.
        mov  dx, TZx
        call Puts
        mov  al, [B200]         ; AL = 200 = C8h
        mov  ah, 0              ; AH = 0: AX = 00C8h = 200
        call Hex16
        mov  dx, Gap4
        call Puts
        movzx eax, byte [B200]  ; EAX = 200: the byte, and 24 bits of 0
        call Hex32
        mov  dx, CrLf
        call Puts

        ; -5 is FBh as a byte, FFFBh as a word, FFFFFFFBh as a double word:
        ; widening a negative number fills the new bits with ones.
        mov  dx, TSx
        call Puts
        mov  al, [Bm5]          ; AL = -5 = FBh
        cbw                     ; AH = 8 copies of AL's top bit: AX = FFFBh
        call Hex16
        mov  dx, Gap4
        call Puts
        movsx eax, byte [Bm5]   ; EAX = -5 = FFFFFFFBh: 24 copies of the sign
        call Hex32
        mov  dx, CrLf
        call Puts

        ; 1000 * 300 = 300000 = 0004 93E0h: more than 16 bits hold.
        mov  dx, TMul
        call Puts
        mov  ax, 1000           ; AX = 1000: the 8086's IMUL multiplies AX
        mov  bx, 300            ; BX = 300
        imul bx                 ; DX:AX = AX * BX = 300000 = 0004 93E0h
        mov  [Lo16], ax         ; kept: the printing spoils them
        mov  [Hi16], dx
        mov  ax, [Hi16]
        call Hex16              ; 0004
        mov  dx, Colon
        call Puts
        mov  ax, [Lo16]
        call Hex16              ; 93E0
        mov  dx, Gap9
        call Puts
        mov  ecx, 1000          ; ECX = 1000
        mov  ebx, 300           ; EBX = 300
        imul ecx, ebx           ; ECX = ECX * EBX = 300000; EAX and EDX alone
        mov  eax, ecx           ; ...into EAX, for the printing
        call Hex32              ; 000493E0
        mov  dx, CrLf
        call Puts

        ; Is 5 less than 9? As a number: 1 or 0.
        mov  dx, TSet
        call Puts
        mov  ax, 5              ; AX = 5
        mov  bl, 0              ; BL = 0, the answer if not - MOV keeps flags
        cmp  ax, 9              ; 5 - 9 < 0: "less"
        jnl  .notl              ;   not less: BL stays 0
        mov  bl, 1              ;   less: BL = 1
.notl:  mov  al, bl             ; AL = the answer
        call Hex8               ; 01
        mov  dx, Gap2
        call Puts
        mov  ax, 5              ; AX = 5
        cmp  ax, 9              ; 5 - 9 < 0: "less"
        setl al                 ; AL = 1 if less, 0 if not: no jump at all
        call Hex8               ; 01
        mov  dx, CrLf
        call Puts

        ; The highest 1 bit of 320 = 1 0100 0000b: bit 8 (256).
        mov  dx, TBsr
        call Puts
        mov  bx, 320            ; BX = 320 = 0000 0001 0100 0000b
        mov  cx, 16             ; CX = 16: one above bit 15, the top
.shift: dec  cx                 ; CX = the number of the bit about to fall
        shl  bx, 1              ; ...and out it falls, into CF
        jnc  .shift             ;   a 0: on - BX is not 0, a 1 will come
        mov  ax, cx             ; AX = 8: bit 8 was the first 1 out
        call Hex16              ; 0008
        mov  dx, Gap4
        call Puts
        mov  ebx, 320           ; EBX = 320
        bsr  eax, ebx           ; EAX = 8: the highest 1 is bit 8; ZF = 0
        call Hex32              ; 00000008
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

B200    db 200                  ; C8h: a byte above 127, but not negative
Bm5     db -5                   ; FBh: a negative byte
