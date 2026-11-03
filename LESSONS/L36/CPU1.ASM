; ============================================================================
;  CPU1.ASM - Lesson 24, step 1. THE FLAGS REGISTER, AS IT IS.
;
;      FASM CPU1.ASM CPU1.COM
;
;  The first of four small programs, each the one before it and a little
;  more. Together they answer one question, asked from inside: what
;  processor is this program running on?
;
;      CPU1   the flags register, sixteen bits, printed as they are
;      CPU2   write into the flags and read them back: 8086, 286 or 386
;      CPU3   on a 386, the flags are 32 bits wide: 386 or 486
;      CPU4   on a 486 or later, the processor says its own name
;
;  This one only looks. PUSHF puts the flags on the stack, POP takes them
;  into a register we can print, and a line above names every bit.
;
;  THE WHOLE PROGRAM IS 8086 CODE, and has to be: it is meant to run on
;  any of them, and the oldest one is the one that must not fall over.
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
CrLf    db 13, 10, '$'

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

; ---- the program --------------------------------------------------------------
Boot:   mov  dx, Names          ; the names of the bits
        call Puts               ; ...over the columns they name
        mov  dx, AsIs           ; 'as it is '
        call Puts
        pushf                   ; the flags register onto the stack
        pop  bx                 ; ...and off it into BX, where we can see it
        call Bin16              ; sixteen ones and zeros
        mov  dx, CrLf           ; the end of the line
        call Puts

Bye:    mov  ax, 4C00h          ; AH = 4Ch exit, AL = 0 the code
        int  21h                ; exit(0)
