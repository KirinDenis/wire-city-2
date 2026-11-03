; ============================================================================
;  E_CPU.INC - WIRE CITY engine: is this an 80386?
; ============================================================================
;  A program that uses 386 instructions has to ask first, and has to ask in
;  8086 code: on an 8086 the first 386 instruction does not fail politely,
;  it runs as something else. Lesson 24 (LESSONS\L36, CPU2.ASM) is the long
;  version of this file, with every line printed; this is its verdict alone.
;
;  POPF writes a word into the flags, PUSHF reads back what stayed. Bits 12
;  to 15 are wires on the older chips:
;
;      write 0000h and they read 1111    an 8086 or 186: tied to 1
;      write F000h and they read 0000    a 286: tied to 0
;      anything else                     a 386 or newer
;
;  Every line below is 8086 code and every jump is short - the file is safe
;  to call on the very chip it is meant to turn away.
;
;  CONTRACT: none. Include it anywhere a routine may stand, and call
;
;      NEED386   returns on a 386 or newer; on anything older it says so
;                and goes back to DOS with exit code 1
;      IS386     CF = 0 on a 386 or newer, CF = 1 on an 8086, 186 or 286;
;                AX is lost, the flags are put back as they were
; ============================================================================

IS386:  pushf                   ; the flags as they are, to put back
        xor  ax, ax             ; AX = 0000h: every bit 0
        push ax
        popf                    ; ...written into the flags
        pushf
        pop  ax                 ; AX = what stayed
        and  ax, 0F000h         ; AX = bits 12-15 only
        cmp  ax, 0F000h         ; all four still 1, though we wrote 0?
        je   .old               ;   yes: an 8086 or 186
        mov  ax, 0F000h         ; AX = F000h: bits 12-15 set
        push ax
        popf                    ; ...written into the flags
        pushf
        pop  ax                 ; AX = what stayed
        and  ax, 0F000h         ; AX = bits 12-15 only
        jz   .old               ; all four 0, though we wrote 1: a 286
        popf                    ; the flags as they were
        clc                     ; CF = 0: a 386 or newer
        ret
.old:   popf                    ; the flags as they were
        stc                     ; CF = 1: older than the 386
        ret

NEED386:
        call IS386              ; CF = 1 on anything older than a 386
        jnc  .yes               ;   CF = 0: go on
        mov  dx, NOT386         ; DS:DX = the reason
        mov  ah, 9              ; AH = 9: write a string, up to the '$'
        int  21h
        mov  ax, 4C01h          ; AH = 4Ch exit, AL = 1: not done
        int  21h                ; exit(1) - never comes back
.yes:   ret

NOT386  db 'This program needs an 80386 or newer.', 13, 10, '$'
