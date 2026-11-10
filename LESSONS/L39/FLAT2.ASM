; ============================================================================
;  FLAT2.ASM - Lesson 27, step 2. INTO PROTECTED MODE AND BACK: FLAT1, and
;  then a megabyte written above the first one.
;
;      FASM FLAT2.ASM FLAT2.COM
;
;  FLAT1 looked. This step goes: it asks HIMEM for a megabyte, opens the
;  21st address wire itself, sets ONE BIT in CR0, writes the whole megabyte
;  through a single register, reads it back, clears the bit, and is in real
;  mode again - with DOS, the BIOS and the keyboard as they were.
;
;  WHY THE TRIP. In real mode an address is SEGMENT * 16 + OFFSET, both 16
;  bits: the most it can say is FFFF:FFFF, 10FFEFh, just past one megabyte.
;  In protected mode a segment register no longer holds a paragraph. It
;  holds a SELECTOR: the number of a line in a table we write ourselves, the
;  GDT, and each line - a DESCRIPTOR - says where the segment starts (32
;  bits) and how long it is (up to 4 GB). Our table has four lines:
;
;      00h   nothing - the processor wants the first line empty
;      08h   our code, 16-bit: starts where DOS put us, 64K long
;      10h   our data, the same place and length - real mode's shape
;      18h   FLAT: starts at nought and runs for 4 GB, every byte there is
;
;  Through 18h one 32-bit offset is a whole address. That is flat memory.
;
;  TWO RULES OF THE TRIP. Interrupts stay off all the way: the vectors of
;  real mode mean nothing to protected mode, and an interrupt would jump
;  into nonsense. And before the bit is cleared again, every segment gets a
;  64K line loaded into it: the processor keeps a descriptor's length after
;  the bit goes, and real mode expects 64K.
;
;  THE PHYSICAL FACT: FLAT1's - the 21st address wire has a gate, and the
;  gate is a pin of the keyboard controller. This step works that pin.
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
Head2   db 13, 10, 'THERE AND BACK', 13, 10, 13, 10, '$'
TStop   db 13, 10, 'Not this machine: protected mode needs real mode, HIMEM', 13, 10
        db 'and a megabyte free. Nothing was changed.', 13, 10, '$'
TGot    db '  HIMEM gave a megabyte at ........... $'
TGate   db '  A20, after the keyboard chip ....... $'
TGateNo db 13, 10, 'The gate would not open: no trip. HIMEM has its megabyte back.', 13, 10, '$'
TWrote  db '  in protected mode, written ......... $'
TBytes  db ' bytes, each its own address', 13, 10, '$'
TRead   db '  read back, wrong ................... $'
TBack   db 13, 10, 'Back in real mode: DOS is printing this.', 13, 10, '$'
THex    db 'h', 13, 10, '$'

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

; ---- a number in hexadecimal, all eight digits: lesson 25's -------------------
;  In C:   for (i = 0; i < 8; i++) { v = rotl(v, 4); putchar(hex[v & 15]); }
Hex32:  mov  cx, 8              ; CX = 8 digits: all of EAX
.top:   rol  eax, 4             ; the top four bits round to the bottom
        push eax                ; DOS spoils AL: keep the rest
        and  al, 0Fh            ; AL = those four bits: 0..15
        add  al, '0'            ; AL = '0'..'9', or past '9' for 10..15
        cmp  al, '9'            ; past '9'?
        jbe  .put               ;   no: a digit as it is
        add  al, 'A' - '9' - 1  ;   yes: 7 more, so 10..15 land on 'A'..'F'
.put:   mov  dl, al             ; DL = the character
        mov  ah, 2              ; AH = 2: write one character
        int  21h                ; putchar(DL)
        pop  eax
        loop .top               ; CX = CX - 1, and again while CX != 0
        ret

; ---- is the 21st wire let through? FLAT1's test, made a routine ---------------
;  Two addresses that differ ONLY in that wire:
;
;      0000:0500   = 0 * 16 + 0500h          =  00500h
;      FFFF:0510   = FFFF0h + 0510h          = 100500h - 21 bits: A20 is 1
;
;  With the gate shut the top bit never reaches memory, and both are 00500h.
;  So: nought into one, FFh into the other, and read the first one back.
;  If it reads FFh, the second write landed on it. Both bytes are put back
;  as they were; with interrupts off, nothing else looks in between.
;  Out:  BL = FFh if the gate is SHUT (the address wrapped), else 00h
A20Test:
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
        ret

; ---- the gate, worked by hand: the keyboard controller's output port -----------
;  The keyboard controller is a small computer of its own, an 8042, at two
;  ports: 64h takes commands and gives its status, 60h takes and gives data.
;  Command D1h says "the next byte on 60h is for your OUTPUT PORT" - eight
;  pins of the chip, wired out to the board:
;
;      bit 0   the RESET line of the processor. 0 restarts the PC. Keep it 1
;      bit 1   THE A20 GATE. 1 lets the 21st address wire through
;
;  So DFh (1101 1111) opens the gate and DDh (1101 1101) shuts it, and both
;  keep bit 0 at 1. Before each byte we wait: bit 1 of the status says the
;  controller has not taken the last byte yet.
;  In:   AH = DFh to open, DDh to shut
KbcWait:
        in   al, 64h            ; AL = the controller's status
        test al, 2              ; bit 1: is its input still full?
        jnz  KbcWait            ;   yes: wait till it has taken it
        ret

A20Set: cli                     ; no key may cut in between the two bytes
        call KbcWait
        mov  al, 0D1h           ; D1h: the next byte is for the output port
        out  64h, al
        call KbcWait
        mov  al, ah             ; AL = DFh or DDh
        out  60h, al            ; the pins: bit 1 is the gate
        call KbcWait            ; and wait till it has done it
        sti
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
        mov  dx, TA20           ; '  A20, the 21st address wire ...'
        call Puts
        call A20Test            ; BL = FFh: shut
        mov  [Shut], bl         ; kept: the gate is given back as it was found
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
        jmp  Stop
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

; ============================================================================
;  4. A MEGABYTE FROM HIMEM - and where it is
; ============================================================================
;  Not ours to take: HIMEM hands it out. AH = 09h with DX = 1024 asks for
;  1024 KB and gives back a HANDLE, a number for the block. HIMEM may move a
;  block about until it is LOCKED: AH = 0Ch locks it and says where it is,
;  a 32-bit address in DX:BX. Real mode cannot reach that address. Protected
;  mode can.
        test byte [Mode], 1     ; virtual 8086? the switch is not ours
        jnz  Stop
        cmp  word [Big], 1024   ; a block of a megabyte free?
        jb   Stop
        mov  dx, Head2
        call Puts
        mov  ah, 09h            ; AH = 09h: a block, please
        mov  dx, 1024           ; DX = its size in KB: a megabyte
        call dword [Xms]        ; AX = 1: given; DX = its handle
        cmp  ax, 1
        jne  Stop
        mov  [Handle], dx       ; kept: the lock, the unlock and the giving
        mov  ah, 0Ch            ; AH = 0Ch: lock it, and say where it is
        call dword [Xms]        ; DX:BX = its address, 32 bits
        cmp  ax, 1
        jne  Free
        mov  word [Phys], bx    ; the low half...
        mov  word [Phys+2], dx  ; ...and the high: a 32-bit address
        mov  dx, TGot           ; '  HIMEM gave a megabyte at ...'
        call Puts
        mov  eax, [Phys]
        call Hex32              ; above 100000h: past real mode's reach
        mov  dx, THex
        call Puts

; ============================================================================
;  5. THE GATE - opened by our own hand, and tested
; ============================================================================
;  With the gate shut, an address with A20 set lands a megabyte lower: a
;  megabyte written at 100000h and on would go over DOS itself. So the gate
;  is opened, tested again, and the trip is called off if it is still shut.
        mov  dx, TGate          ; '  A20, after the keyboard chip ...'
        call Puts
        mov  ah, 0DFh           ; DFh: the gate open, the reset line kept at 1
        call A20Set
        call A20Test            ; BL = FFh: still shut
        mov  dx, TOpen          ; 'open'
        cmp  bl, 0FFh
        jne  .open
        mov  dx, TGateNo        ; still shut: no trip
        call Puts
        jmp  Unlock
.open:  call Puts

; ============================================================================
;  6. THE TABLE - where each selector starts
; ============================================================================
;  Lines 08h and 10h must start where DOS put this program, or every offset
;  in it would point somewhere else. That is CS * 16 - known only now, at
;  run time - so it is written into them here. A descriptor keeps its start
;  in three pieces, for the 286's sake: bits 0-15 at byte 2, bits 16-23 at
;  byte 4, bits 24-31 at byte 7 (nought here: we are below a megabyte).
        xor  eax, eax           ; EAX = 0, the top half too
        mov  ax, cs             ; EAX = our segment
        shl  eax, 4             ; EAX = CS * 16: our first byte, a 32-bit address
        mov  [Base], eax        ; kept
        mov  word [Gdt+08h+2], ax       ; code: the start, bits 0-15
        mov  word [Gdt+10h+2], ax       ; data: the same
        shr  eax, 16            ; AL = bits 16-23
        mov  byte [Gdt+08h+4], al       ; code: the start, bits 16-23
        mov  byte [Gdt+10h+4], al       ; data: the same
        mov  eax, [Base]        ; EAX = our first byte
        add  eax, Gdt           ; + the table's offset = the table's address
        mov  dword [GdtPtr+2], eax  ; LGDT wants it as an address, not an offset
        mov  [RealCs], cs       ; and our segment, for the way back

; ============================================================================
;  7. THE TRIP
; ============================================================================
;  NEW: LGDT [m], load the global descriptor table register. Six bytes: the
;  table's length less one, then its 32-bit address. It only says where the
;  table is - nothing changes until a selector is loaded. Flags: none.
;
;  NEW: MOV EAX,CR0 and MOV CR0,EAX - the control register, whole. Bit 0 is
;  PE. The trap: set it, and the very next instructions are still decoded
;  the real-mode way - only a FAR JUMP loads CS with a selector and makes
;  the switch real. It comes straight after.
        cli                     ; no interrupts: their vectors mean nothing now
        mov  [RealSp], sp       ; real mode's stack, to come back to
        lgdt [GdtPtr]           ; the processor knows our table
        mov  eax, cr0           ; EAX = CR0
        or   al, 1              ; bit 0, PE = 1
        mov  cr0, eax           ; PROTECTED MODE - after the next jump
        jmp  08h:.pm            ; CS = line 08h: our code, by its descriptor
.pm:    mov  ax, 10h            ; selector 10h: our data
        mov  ds, ax             ; DS, ES, SS = our data - every offset the same
        mov  es, ax             ;  as a moment ago, through a descriptor now
        mov  ss, ax
        mov  ax, 18h            ; selector 18h: FLAT, 4 GB from nought
        mov  fs, ax             ; FS = all the memory there is

        ; The megabyte: each double word gets its own address written into
        ; it. [FS:EDI] is a 32-bit address: FASM puts the byte 67h in front
        ; of the instruction, and the processor takes EDI whole. In a 16-bit
        ; segment it would otherwise take DI, and stop at 64K.
        mov  edi, [Phys]        ; EDI = HIMEM's megabyte: a whole address
        mov  ecx, 1024*1024/4   ; ECX = 262144 double words
.w:     mov  [fs:edi], edi      ; *edi = edi
        add  edi, 4             ; EDI += 4: the next double word
        dec  ecx                ; ECX = ECX - 1
        jnz  .w                 ; and again, the whole megabyte

        ; And read it back. A wrong one means two addresses landed on one
        ; byte - the wrap of FLAT1, or memory that is not there.
        mov  edi, [Phys]        ; EDI = the start again
        mov  ecx, 1024*1024/4   ; ECX = 262144 double words
        xor  ebx, ebx           ; EBX = 0: none wrong yet
.r:     cmp  [fs:edi], edi      ; does it hold its own address?
        je   .ok
        inc  ebx                ;   no: one more wrong
.ok:    add  edi, 4             ; EDI += 4
        dec  ecx
        jnz  .r
        mov  [Wrong], ebx       ; kept for the printing, in real mode

        ; Back. Every segment gets line 10h, real mode's 64K, before the bit
        ; is cleared: the processor keeps the length a descriptor gave.
        mov  ax, 10h            ; selector 10h: 64K
        mov  fs, ax             ; FS = 64K again, not 4 GB
        mov  eax, cr0           ; EAX = CR0
        and  al, 0FEh           ; bit 0, PE = 0
        mov  cr0, eax           ; REAL MODE - after the next jump
        push word [RealCs]      ; a far jump to a segment known only at run
        push word .rm           ;  time: push it and its offset, and RETF
        retf                    ;  takes them both. CS = our paragraph again
.rm:    mov  ax, cs             ; AX = our segment
        mov  ds, ax             ; DS, ES, SS = paragraphs again, as DOS gave
        mov  es, ax
        mov  ss, ax
        mov  sp, [RealSp]       ; the stack as it was
        xor  ax, ax
        mov  fs, ax             ; FS = 0, as we found it
        sti                     ; interrupts back: we are home

        mov  dx, TWrote         ; '  in protected mode, written ...'
        call Puts
        mov  eax, 1024*1024     ; EAX = the bytes
        call Dec32
        mov  dx, TBytes
        call Puts
        mov  dx, TRead          ; '  read back, wrong ...'
        call Puts
        mov  eax, [Wrong]
        call Dec32              ; 0, if every one held its own address
        mov  dx, CrLf
        call Puts
        mov  dx, TBack          ; 'Back in real mode: DOS is printing this.'
        call Puts

; ============================================================================
;  8. EVERYTHING GIVEN BACK - the gate as it was found, the megabyte to HIMEM
; ============================================================================
        cmp  byte [Shut], 0FFh  ; was the gate shut when we came?
        jne  Unlock
        mov  ah, 0DDh           ; DDh: the gate shut, the reset line kept at 1
        call A20Set
Unlock: mov  ah, 0Dh            ; AH = 0Dh: unlock it
        mov  dx, [Handle]
        call dword [Xms]
Free:   mov  ah, 0Ah            ; AH = 0Ah: free it - HIMEM's again
        mov  dx, [Handle]
        call dword [Xms]
        jmp  Done

Stop:   mov  dx, TStop          ; not this machine
        call Puts
Done:   mov  ax, 4C00h          ; AH = 4Ch exit, AL = 0: all done
        int  21h

; ---- the data ---------------------------------------------------------------
Mode    db 0                    ; the low byte of CR0, as SMSW read it
Shut    db 0                    ; FFh if the gate was shut when we came
Xms     dd 0                    ; HIMEM's entry: offset, then segment
Big     dw 0                    ; the largest free block, KB
All     dw 0                    ; all that is free, KB
Handle  dw 0                    ; HIMEM's number for our megabyte
Phys    dd 0                    ; where it is: a 32-bit address
Wrong   dd 0                    ; double words that did not hold their address
Base    dd 0                    ; CS * 16: our first byte, as an address
RealCs  dw 0                    ; our segment, for the way back
RealSp  dw 0                    ; the stack pointer, for the way back

; ---- the table: four descriptors, eight bytes each ----------------------------
;  bytes 0-1 the length less one, bits 0-15     bytes 2-3 the start, 0-15
;  byte  4   the start, bits 16-23              byte  5   what it is:
;                                                   9Ah code, run and read
;                                                   92h data, read and write
;  byte  6   high nibble: G (length counted in 4K pieces) and B (32-bit);
;            low nibble: the length, bits 16-19
;  byte  7   the start, bits 24-31
        align 8                 ; the processor reads it fastest on 8
Gdt     dw 0, 0, 0, 0                   ; 00h: empty, by the rules
        dw 0FFFFh, 0                    ; 08h: our code, 64K...
        db 0, 9Ah, 00h, 0               ;  ...the start filled in at run time
        dw 0FFFFh, 0                    ; 10h: our data, 64K...
        db 0, 92h, 00h, 0               ;  ...the start filled in at run time
        dw 0FFFFh, 0                    ; 18h: FLAT - start 0, and the length
        db 0, 92h, 0CFh, 0              ;  FFFFFh pieces of 4K: all 4 GB
GdtPtr: dw 4*8-1                ; the table's length less one
        dd 0                    ; and its address, filled in at run time
