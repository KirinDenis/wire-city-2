; ============================================================================
;  FLAT1.ASM - Lesson 27, step 1. WHERE ARE WE? Before a program takes the
;  memory above one megabyte, it looks at three things.
;
;      FASM FLAT1.ASM FLAT1.COM
;
;  Lesson 26 ended with CLOCK.COM at 64803 bytes: a .COM is one segment, 64K
;  for the code, the data and the stack together, and it is full. The 386
;  can address four gigabytes. This lesson goes and gets them, in steps:
;
;      FLAT1   where are we: the processor's mode, the 21st address wire,
;              and who keeps the memory above one megabyte
;      FLAT2   into protected mode and back, and a megabyte written up there
;      FLAT3   a 32-bit program: flat memory, its own clock and keys
;
;  THE THREE THINGS
;
;      CR0, bit 0      PE, protection enable. 0: real mode, as the 8086 ran.
;                      1: protected mode - or VIRTUAL 8086, a real mode
;                      pretended by a memory manager (EMM386) that owns the
;                      processor. Then the processor is not ours to switch
;      A20             the 21st address wire. See the fact below
;      XMS             HIMEM, the keeper of the memory above 1 MB. A program
;                      asks it for a block, as DOS is asked for a file
;
;  THE PHYSICAL FACT THIS LESSON HANDS OVER:
;
;      THE 21ST ADDRESS WIRE HAS A GATE. The 8086 had twenty address wires,
;      A0 to A19: 2^20 is one megabyte. FFFF:0010 is FFFF0h + 10h = 100000h,
;      a 1 and twenty noughts - and with no 21st wire the 1 fell off, and
;      the address wrapped round to 00000h. Programs counted on it. So when
;      the 286 brought more wires, IBM put a gate on A20 and kept it shut:
;      the 21st wire held at nought, and the wrap kept. The spare pin they
;      found for the gate was on the KEYBOARD CONTROLLER. Every PC since has
;      that gate.
;
;  Owlos - legacy software modernization - https://owlos.sk
; ============================================================================
format binary as 'com'
        org  100h

        jmp  Boot               ; over the data and the routines

; ---- the text ---------------------------------------------------------------
CrLf    db 13, 10, '$'
Head1   db 'WHERE ARE WE?', 13, 10, 13, 10, '$'
TPe     db '  CR0 bit 0, PE, read by SMSW ........ $'
TReal   db '0   real mode: the processor is ours', 13, 10, '$'
TV86    db '1   virtual 8086: a memory manager owns', 13, 10
        db '                                         the processor, not us', 13, 10, '$'
TA20    db '  A20, the 21st address wire ......... $'
TShut   db 'shut: FFFF:0510 is 0000:0500', 13, 10, '$'
TOpen   db 'open: FFFF:0510 is 100500h', 13, 10, '$'
TXms    db '  XMS, the keeper above 1 MB ......... $'
TNoXms  db 'none', 13, 10, '$'
TFree   db 'found, $'
TKb     db ' KB free', 13, 10, '$'
TBlock  db '                                         the largest block $'
TKb2    db ' KB', 13, 10, '$'

; ---- a line of text ---------------------------------------------------------
;  In C:   fputs(dx, stdout);       the text ends with '$', DOS's own end
Puts:   mov  ah, 9              ; AH = 9: write a string, up to the '$'
        int  21h                ; DOS writes DS:DX
        ret

; ---- a number in decimal, and not one DIV in it -------------------------------
;  In C:   n = eax;  do { q = n / 10;  push(n - q*10);  n = q; } while (n);
;          while (count--) putchar('0' + pop());
;
;  NEW: MUL with a 32-bit register. MUL EDX multiplies EAX by EDX, unsigned,
;  and the answer is 64 bits wide: the top half in EDX, the low half in EAX.
;  Flags: CF and OF say the top half is not nought; we read neither. The trap:
;  it is EDX:EAX it writes, so whatever was in EDX is gone.
;
;  WHY IT DIVIDES. 0CCCCCCCDh is 2^35 / 10, rounded up. n times it is n / 10
;  times 2^35: the top half, EDX, is that over 2^32, and three more shifts
;  make it over 2^35. For every n that fits in 32 bits the answer is exactly
;  n / 10, rounded down - checked, not hoped: it is the compilers' own trick.
Dec32:  xor  cx, cx             ; CX = 0: no digits yet
.d:     mov  ebx, eax           ; EBX = n
        mov  edx, 0CCCCCCCDh    ; EDX = 2^35 / 10, rounded up
        mul  edx                ; EDX:EAX = n * 2^35 / 10
        shr  edx, 3             ; EDX = q = n / 10: the top half over 2^3
        lea  eax, [edx*4+edx]   ; EAX = q * 5: LEA as a calculator, lesson 25
        add  eax, eax           ; EAX = q * 10
        sub  ebx, eax           ; EBX = n - q*10: the last digit, 0..9
        push bx                 ; kept: the digits come out last first
        inc  cx                 ; CX = one more digit
        mov  eax, edx           ; EAX = q: what is left
        test eax, eax           ; anything left?
        jnz  .d                 ;   yes: its last digit next
.p:     pop  dx                 ; DL = a digit, 0..9, the first one first
        add  dl, '0'            ; DL = '0'..'9'
        mov  ah, 2              ; AH = 2: write one character
        int  21h                ; putchar(DL)
        loop .p                 ; CX = CX - 1, and again while CX != 0
        ret

; ---- is this a 386? - 8086 code, short jumps ----------------------------------
        include '..\..\ENGINE\E_CPU.INC'

; ---- the program --------------------------------------------------------------
Boot:   call NEED386            ; an 8086 or 286 is told, and goes back to DOS
        mov  dx, Head1
        call Puts

; ============================================================================
;  1. CR0, BIT 0 - whose is the processor?
; ============================================================================
;  NEW: SMSW, store machine status word. It copies the low 16 bits of CR0,
;  the control register, into a general register. It is the 286's way in,
;  and it runs at any privilege, even under a memory manager - MOV AX,CR0
;  would not. Flags: none touched. The trap: it only READS. LMSW writes, and
;  we are not writing yet.
        mov  dx, TPe            ; '  CR0 bit 0, PE ...'
        call Puts
        smsw ax                 ; AX = the low half of CR0
        mov  [Mode], al         ; kept: the next steps ask the same question
        mov  dx, TReal          ; '0   real mode'
        test al, 1              ; bit 0, PE: 1 = protected, or V86
        jz   .pe
        mov  dx, TV86           ; '1   virtual 8086'
.pe:    call Puts

; ============================================================================
;  2. A20 - is the 21st address wire held at nought?
; ============================================================================
;  Two addresses that differ ONLY in that wire:
;
;      0000:0500   = 0 * 16 + 0500h          =  00500h
;      FFFF:0510   = FFFF0h + 0510h          = 100500h - 21 bits: A20 is 1
;
;  With the gate shut the top bit never reaches memory, and both are 00500h.
;  So: nought into one, FFh into the other, and read the first one back.
;  If it reads FFh, the second write landed on it. Both bytes are put back
;  as they were; with interrupts off, nothing else looks in between.
        mov  dx, TA20           ; '  A20, the 21st address wire ...'
        call Puts
        cli                     ; nobody else, till both bytes are back
        push ds
        push es
        xor  ax, ax
        mov  ds, ax             ; DS = 0000h
        dec  ax                 ; AX = FFFFh: 0 - 1, all sixteen bits set
        mov  es, ax             ; ES = FFFFh
        mov  si, 0500h          ; DS:SI = 00500h
        mov  di, 0510h          ; ES:DI = 100500h, if the wire is let through
        mov  al, [si]           ; AL = what was at 00500h
        push ax                 ; kept
        mov  al, [es:di]        ; AL = what was at the other one
        push ax                 ; kept
        mov  byte [si], 00h     ; 00500h = 00h
        mov  byte [es:di], 0FFh ; the other = FFh
        mov  bl, [si]           ; BL = 00500h again: FFh if they are one byte
        pop  ax
        mov  [es:di], al        ; the other one back as it was...
        pop  ax
        mov  [si], al           ; ...and 00500h last: right, even if they
        pop  es                 ;  turned out to be the same byte
        pop  ds
        sti                     ; interrupts back on
        mov  dx, TOpen          ; 'open'
        cmp  bl, 0FFh           ; did the second write land on the first?
        jne  .a20
        mov  dx, TShut          ; 'shut': it did. The address wrapped
.a20:   call Puts

; ============================================================================
;  3. XMS - who keeps the memory above one megabyte?
; ============================================================================
;  INT 2Fh is DOS's switchboard: AH names who is asked. 43h is HIMEM. AL =
;  80h back means it is here; then AX = 4310h gives the address to CALL it
;  at, in ES:BX. HIMEM's functions are calls, not interrupts: AH = 08h asks
;  how much is free, and comes back with the largest block in AX and all of
;  it in DX, in kilobytes.
;
;  NEW: CALL DWORD [address] - a FAR call through memory. The four bytes
;  there are an offset and then a segment; the CPU pushes CS and IP, and
;  jumps to both. Flags: none. The trap: CALL [address] without DWORD is a
;  NEAR call - it would take the offset alone and jump into our own segment.
        mov  dx, TXms           ; '  XMS, the keeper above 1 MB ...'
        call Puts
        mov  ax, 4300h          ; AH = 43h, HIMEM; AL = 00h: are you there?
        int  2Fh                ; AL = 80h: yes
        cmp  al, 80h
        je   .xms
        mov  dx, TNoXms         ; 'none'
        call Puts
        jmp  .done
.xms:   push es                 ; ES comes back changed
        mov  ax, 4310h          ; AL = 10h: where do I call you?
        int  2Fh                ; ES:BX = HIMEM's entry
        mov  word [Xms], bx     ; the offset first...
        mov  word [Xms+2], es   ; ...then the segment: a far address
        pop  es
        mov  ah, 08h            ; AH = 08h: how much is free?
        call dword [Xms]        ; AX = the largest block, DX = all, in KB
        mov  [Big], ax          ; kept: printing spoils AX
        mov  [All], dx          ; kept
        mov  dx, TFree          ; 'found, '
        call Puts
        movzx eax, word [All]   ; EAX = all that is free, KB
        call Dec32              ; in decimal
        mov  dx, TKb            ; ' KB free'
        call Puts
        mov  dx, TBlock         ; '...the largest block '
        call Puts
        movzx eax, word [Big]   ; EAX = the largest block, KB
        call Dec32
        mov  dx, TKb2           ; ' KB'
        call Puts

.done:  mov  ax, 4C00h          ; AH = 4Ch exit, AL = 0: all done
        int  21h

; ---- the data ---------------------------------------------------------------
Mode    db 0                    ; the low byte of CR0, as SMSW read it
Xms     dd 0                    ; HIMEM's entry: offset, then segment
Big     dw 0                    ; the largest free block, KB
All     dw 0                    ; all that is free, KB
