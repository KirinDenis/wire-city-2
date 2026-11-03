; ============================================================================
;  CPU4.ASM - Lesson 24, step 4. THE PROCESSOR SAYS ITS OWN NAME.
;
;      FASM CPU4.ASM CPU4.COM
;
;  CPU3.ASM, and one bit more. Late 486s and every Pentium have bit 21 of
;  EFLAGS, ID, and it means one thing: this processor has CPUID, an
;  instruction that answers questions about the processor itself.
;
;      bit 21   ID      it moves: CPUID is there
;
;      CPUID with EAX = 0   EAX = the highest question it answers,
;                           EBX, EDX, ECX = twelve letters, the maker:
;                           'GenuineIntel', 'AuthenticAMD'...
;      CPUID with EAX = 1   EAX bits 8-11 the family, 4-7 the model,
;                           0-3 the stepping (the revision of the die)
;
;  So the four programs go from feeling for wires to being told. Before
;  CPUID there was no instruction for the question, and every program that
;  cared did what CPU2 and CPU3 do.
;
;  The two tries of EFLAGS here - AC and ID - are made one after the
;  other, before anything is printed, so both start from the same flags.
;
;  Owlos - legacy software modernization - https://owlos.sk
; ============================================================================
format binary as 'com'
        org  100h

        ; Keeps every conditional jump inside what an 8086 has: FASM would
        ; otherwise use the 386's long jump, 0F 8x, without a word.
        include '..\..\ENGINE\E_8086.INC'

        jmp  Boot               ; over the data and the routines

; ---- the text ---------------------------------------------------------------
;  A line of letters over the bits: each letter sits over its bit. The
;  dashes are bits with no name, and on the 8086 the top four are those too.
Names   db '         -NIIODITSZ-A-P-C', 13, 10, '$'
AsIs    db 'as it is $'
Put0    db 'put 0000 $'
PutF    db 'put F000 $'
CrLf    db 13, 10, '$'
Is86    db 13, 10, 'An 8086 or an 80186: bits 12 to 15 are tied to 1.', 13, 10, '$'
Is286   db 13, 10, 'An 80286: bits 12 to 15 are tied to 0.', 13, 10, '$'
Is386   db 13, 10, 'An 80386 or newer: bits 12 to 14 take what we write.', 13, 10, '$'
Stop    db 'What follows is 386 code, so the program stops here.', 13, 10, '$'

;  The top half: bits 31 to 22 have no name; then ID, VIP, VIF, AC, VM, RF.
Names32 db 13, 10, '         ----------IVVAVR-NIIODITSZ-A-P-C', 13, 10, '$'
EFl     db 'EFLAGS   $'
FlAC    db 'flip AC  $'
Is486   db 13, 10, 'An 80486 or newer: bit 18, AC, is there.', 13, 10, '$'
Only386 db 13, 10, 'An 80386: bit 18, AC, is not there.', 13, 10, '$'
FlID    db 'flip ID  $'
NoId    db 'No CPUID: bit 21, ID, is not there.', 13, 10, '$'
Says    db 'CPUID is there. The processor says: $'
Maker   db 12 dup '?', 13, 10, '$'   ; CPUID's twelve letters go here
Fam     db 'family $'
Model   db ', model $'
Step    db ', stepping $'
Fam4    db ' - an 80486', 13, 10, '$'
Fam5    db ' - a Pentium', 13, 10, '$'
Fam6    db ' - a Pentium Pro or newer', 13, 10, '$'

Was     dw 0                    ; the flags as we found them
Got0    dw 0                    ; what came back from 0000h
GotF    dw 0                    ; what came back from F000h
Was32   dd 0                    ; EFLAGS as we found them, all 32 bits
Got32   dd 0                    ; what came back from flipping AC
GotID   dd 0                    ; what came back from flipping ID
Sig     dd 0                    ; CPUID 1's EAX: family, model, stepping

; ---- a line of text ---------------------------------------------------------
;  In C:   fputs(dx, stdout);       the text ends with '$', DOS's own end
Puts:   mov  ah, 9              ; AH = 9: write a string, up to the '$'
        int  21h                ; DOS writes DS:DX
        ret

; ---- one word as sixteen binary digits --------------------------------------
;  In C:   for (i = 0; i < 16; i++) { putchar('0' + (w >> 15)); w <<= 1; }
;
;  SHL moves every bit of BX one place up, and the top one falls out into
;  the carry flag. ADC then adds that carry to '0': '0' or '1'.
Bin16:  mov  cx, 16             ; CX = 16 digits
.next:  mov  dl, '0'            ; DL = '0'
        shl  bx, 1              ; CF = the top bit, BX moves up one place
        adc  dl, 0              ; DL = '0' + CF: '0' or '1'
        mov  ah, 2              ; AH = 2: write one character
        int  21h                ; putchar(DL)
        loop .next              ; CX = CX - 1, and again while CX != 0
        ret

; ---- write a word into the flags, read back what stuck -----------------------
;  In C:   flags = ax; ax = flags; flags = Was; return ax;
;
;  POPF takes a word off the stack and puts it into the flags register - all
;  of it at once, every bit the processor lets it. PUSHF is the way back.
Try:    push ax                 ; the word to write
        popf                    ; ...into the flags register
        pushf                   ; what the processor kept of it
        pop  ax                 ; ...into AX: the answer
        push word [Was]         ; the flags as they were
        popf                    ; ...put back, before anything else runs
        ret

; ============================================================================
;  FROM HERE ON, 386 CODE. Nothing below is called before the verdict.
; ============================================================================

; ---- one double word as 32 binary digits ------------------------------------
;  Bin16 with EBX in place of BX: the same SHL and ADC, 32 times. Each of
;  `shl ebx, 1` is the bytes of `shl bx, 1` with 66h in front.
Bin32:  mov  cx, 32             ; CX = 32 digits
.next:  mov  dl, '0'            ; DL = '0'
        shl  ebx, 1             ; CF = the top bit, EBX moves up one place
        adc  dl, 0              ; DL = '0' + CF: '0' or '1'
        mov  ah, 2              ; AH = 2: write one character
        int  21h                ; putchar(DL)
        loop .next              ; CX = CX - 1, and again while CX != 0
        ret

; ---- turn bits of EFLAGS over, read back what stuck ----------------------------
;  In C:   was = eflags; eflags = was ^ eax; eax = eflags; eflags = was;
;
;  PUSHFD and POPFD are PUSHF and POPF for all 32 bits: four bytes on the
;  stack, not two. XOR turns over exactly the bits that are 1 in EDX and
;  leaves every other bit as it was - TF and IF included.
Try32:  mov  edx, eax           ; EDX = the bits to turn over
        pushfd                  ; EFLAGS onto the stack, all 32 bits
        pop  eax                ; EAX = EFLAGS as they are
        mov  [Was32], eax       ; kept, to put back
        xor  eax, edx           ; EAX = the same, with those bits turned over
        push eax                ; the double word to write
        popfd                   ; ...into EFLAGS
        pushfd                  ; what the processor kept of it
        pop  eax                ; ...into EAX: the answer
        push dword [Was32]      ; EFLAGS as they were
        popfd                   ; ...put back
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

; ---- the program --------------------------------------------------------------
Boot:   mov  dx, Names          ; the names of the bits
        call Puts               ; ...over the columns they name
        mov  dx, AsIs           ; 'as it is '
        call Puts
        pushf                   ; the flags register onto the stack
        pop  bx                 ; ...and off it into BX, where we can see it
        mov  [Was], bx          ; kept, to put back after every try
        call Bin16              ; sixteen ones and zeros
        mov  dx, CrLf           ; the end of the line
        call Puts

        xor  ax, ax             ; AX = 0000h: every bit 0
        call Try                ; write it, read it back
        mov  [Got0], ax         ; what came back
        mov  dx, Put0           ; 'put 0000 '
        call Puts
        mov  bx, [Got0]         ; ...and what came back, in ones and zeros
        call Bin16
        mov  dx, CrLf
        call Puts

        mov  ax, 0F000h         ; AX = F000h: bits 12 to 15 set, the rest 0
        call Try                ; write it, read it back
        mov  [GotF], ax         ; what came back
        mov  dx, PutF           ; 'put F000 '
        call Puts
        mov  bx, [GotF]         ; ...and what came back, in ones and zeros
        call Bin16
        mov  dx, CrLf
        call Puts

        ; Which wires are there. AND keeps only bits 12-15 of the top byte.
        mov  al, byte [Got0+1]  ; AL = bits 8-15 of what came back from 0
        and  al, 0F0h           ; AL = bits 12-15 only
        cmp  al, 0F0h           ; all four 1, though we wrote 0?
        je   .i86               ;   yes: tied to 1 - an 8086 or 186
        mov  al, byte [GotF+1]  ; AL = bits 8-15 of what came back from F000h
        and  al, 0F0h           ; AL = bits 12-15 only
        jz   .i286              ; all four 0, though we wrote 1: a 286
        mov  dx, Is386          ; some of them took the 1: a 386 or newer
        call Puts               ; the verdict
        jmp  Step3              ; ...and on, into 32 bits
.i86:   mov  dx, Is86
        jmp  .say
.i286:  mov  dx, Is286
.say:   call Puts               ; the verdict
        mov  dx, Stop           ; and why this is the end
        call Puts
        jmp  Bye

; ---- step 3: the 386 and up only ------------------------------------------------
;  Both lines are printed from ONE try: the flags before it and after it.
;  The arithmetic flags change with almost every instruction, so EFLAGS
;  read a moment earlier would differ in PF or ZF, and mean nothing.
Step3:  mov  eax, 1 shl 18      ; EAX = bit 18 alone: AC
        call Try32              ; turn it over, read back
        mov  [Got32], eax       ; what came back
        mov  eax, 1 shl 21      ; EAX = bit 21 alone: ID. MOV leaves the
                                ;  flags alone, so this try starts from
        call Try32              ;  the very EFLAGS the first one put back
        mov  [GotID], eax       ; what came back

        mov  dx, Names32        ; the names of all 32 bits
        call Puts
        mov  dx, EFl            ; 'EFLAGS   '
        call Puts
        mov  ebx, [Was32]       ; EFLAGS as both tries found them
        call Bin32              ; 32 ones and zeros
        mov  dx, CrLf
        call Puts
        mov  dx, FlAC           ; 'flip AC  '
        call Puts
        mov  ebx, [Got32]       ; ...and what came back, in ones and zeros
        call Bin32
        mov  dx, CrLf
        call Puts
        mov  dx, FlID           ; 'flip ID  '
        call Puts
        mov  ebx, [GotID]       ; ...and what came back, in ones and zeros
        call Bin32
        mov  dx, CrLf
        call Puts

        mov  eax, [Got32]       ; what came back from AC
        xor  eax, [Was32]       ; EAX = the bits that changed
        test eax, 1 shl 18      ; did AC change?
        jnz  Step4              ;   yes: a 486 or newer - on
        mov  dx, Only386        ;   no: the wire is not there - a 386
        call Puts
        jmp  Bye

; ---- step 4: the 486 and up only ------------------------------------------------
Step4:  mov  dx, Is486          ; the verdict of step 3
        call Puts
        mov  eax, [GotID]       ; what came back from ID
        xor  eax, [Was32]       ; EAX = the bits that changed
        test eax, 1 shl 21      ; did ID change?
        jnz  .ask               ;   yes: CPUID is there - ask it
        mov  dx, NoId           ;   no: an early 486, and no way to ask
        call Puts
        jmp  Bye

; CPUID. EAX says which question; the answer comes back in EAX, EBX, ECX
; and EDX - all four are written, whatever the question.
.ask:   mov  dx, Says           ; 'CPUID is there. The processor says: '
        call Puts
        xor  eax, eax           ; EAX = 0: the maker, and the last question
        cpuid                   ; EBX, EDX, ECX = twelve letters
        mov  dword [Maker], ebx     ; letters 1-4, in that order:
        mov  dword [Maker+4], edx   ;  5-8 - EDX before ECX, as Intel
        mov  dword [Maker+8], ecx   ;  9-12   defined it
        push eax                ; EAX = the highest question it answers
        mov  dx, Maker          ; the twelve letters
        call Puts
        pop  eax                ; the highest question
        cmp  eax, 1             ; does it answer question 1?
        jb   Bye                ;   no: the name is all we get

        mov  eax, 1             ; EAX = 1: family, model, stepping
        cpuid                   ; EAX = the signature; EBX, ECX, EDX more
        mov  [Sig], eax         ; kept: we take it apart three times

        ; SHR by a number written in the instruction - `shr eax, 8` - is
        ; not 8086 code: the 8086 shifts by 1 or by CL. The 186 added it,
        ; and here, past two verdicts, we are on a 486 at least.
        mov  dx, Fam            ; 'family '
        call Puts
        mov  eax, [Sig]
        shr  eax, 8             ; bits 8-11 down to 0-3: the family
        call Digit              ; one hex digit, the low four bits of AL
        mov  dx, Model          ; ', model '
        call Puts
        mov  eax, [Sig]
        shr  eax, 4             ; bits 4-7 down to 0-3: the model
        call Digit
        mov  dx, Step           ; ', stepping '
        call Puts
        mov  eax, [Sig]         ; bits 0-3 are where they belong already
        call Digit

        mov  eax, [Sig]
        shr  eax, 8             ; the family again
        and  al, 0Fh            ; AL = 0..15
        mov  dx, Fam4           ; 4: an 80486
        cmp  al, 4
        je   .name
        mov  dx, Fam5           ; 5: a Pentium
        cmp  al, 5
        je   .name
        mov  dx, Fam6           ; 6 and up: newer still
.name:  call Puts

Bye:    mov  ax, 4C00h          ; AH = 4Ch exit, AL = 0 the code
        int  21h                ; exit(0)
