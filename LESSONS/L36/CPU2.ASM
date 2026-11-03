; ============================================================================
;  CPU2.ASM - Lesson 24, step 2. WRITE INTO THE FLAGS, AND READ THEM BACK.
;
;      FASM CPU2.ASM CPU2.COM
;
;  CPU1.ASM and two tries more. POPF writes a word into the flags register;
;  PUSHF reads back what the processor kept of it. A bit the processor has
;  takes what we wrote. A bit it does not have is not a memory cell at all
;  - it is a wire tied to 1 or to 0 inside the chip, and it reads back
;  whatever it is tied to, no matter what we wrote.
;
;  Bits 12 to 15 are the ones that differ between generations:
;
;                  write 0000h      write F000h
;      8086, 186   reads 1111...    reads 1111...   tied to 1, all four
;      286         reads 0000...    reads 0000...   tied to 0, in real mode
;      386 and up  reads 0000...    reads 0111...   12, 13, 14 are there
;
;  THE PHYSICAL FACT: a register is not sixteen boxes on every chip. Some of
;  its bits are wires that one generation has and another does not, and
;  writing and reading back is how a program feels for them.
;
;  WHAT ELSE THE TWO WORDS DO: their bits 0 to 11 are all 0. Bit 8 is TF,
;  the trap flag of lesson 23 - kept off, as it must be, or INT 1 would
;  fire after every instruction. Bit 9 is IF - so for the four instructions
;  of a try the interrupts wait, and the flags as they were are put back.
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

Was     dw 0                    ; the flags as we found them
Got0    dw 0                    ; what came back from 0000h
GotF    dw 0                    ; what came back from F000h

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
        jmp  .say
.i86:   mov  dx, Is86
        jmp  .say
.i286:  mov  dx, Is286
.say:   call Puts               ; the verdict

Bye:    mov  ax, 4C00h          ; AH = 4Ch exit, AL = 0 the code
        int  21h                ; exit(0)
