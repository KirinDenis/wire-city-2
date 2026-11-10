; ============================================================================
;  FLAT3.ASM - Lesson 27, step 3. A 32-BIT PROGRAM: FLAT2, and then the
;  processor stays in protected mode - with its own clock and its own keys.
;
;      FASM FLAT3.ASM FLAT3.COM
;
;  FLAT2 went there and came back with the interrupts off. A program that
;  LIVES there needs them on: the timer to count time and the keyboard to
;  steer. So this step writes a second table, the IDT - one line for each
;  interrupt, saying which of OUR routines takes it - and moves the timer
;  and the keyboard out of the processor's way. Then it runs in 32 bits:
;
;      the picture is drawn into HIMEM's megabyte, ABOVE 1 MB, and copied to
;      the screen at 0A0000h. Both are just numbers in one register: EDI.
;      Arrows move the square, on our clock. Esc comes back to DOS.
;
;  THE GDT, SIX LINES NOW:
;
;      00h   nothing
;      08h   our code, 32-BIT: starts where DOS put us, 4 GB long
;      10h   our data, 32-bit, the same start and length
;      18h   FLAT: starts at nought, 4 GB - the screen, the BIOS, HIMEM's
;      20h   our code, 16-bit, 64K  \  only for the way back: real mode
;      28h   our data, 16-bit, 64K  /  must find its own shapes again
;
;  THE CLASH. The timer is IRQ 0, and the interrupt controller sends it as
;  INT 8 - the 8086 left numbers 0 to 31 free, and IBM used them. Intel had
;  reserved them: in protected mode INT 8 is the processor's own DOUBLE
;  FAULT, INT 13 its general protection. So while we are there the
;  controller is told to send IRQ 0 to 7 as INT 32 to 39, and told back on
;  the way out. Every IRQ but the timer's and the keyboard's is masked.
;
;  WHAT IS GIVEN BACK: the controller's numbers and masks, the timer's
;  divider, text mode, the gate, HIMEM's megabyte. And the BIOS's clock at
;  0040:006C goes on counting all the while: every fourth tick of ours adds
;  one to it, as lesson 26's handler let the BIOS do.
;
;  THE PHYSICAL FACT: FLAT1's - the 21st address wire has a gate.
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
Head2   db 13, 10, 'A 32-BIT PROGRAM', 13, 10, 13, 10, '$'
TStop   db 13, 10, 'Not this machine: protected mode needs real mode, HIMEM', 13, 10
        db 'and a megabyte free. Nothing was changed.', 13, 10, '$'
TGot    db '  HIMEM gave a megabyte at ........... $'
TGate   db '  A20, after the keyboard chip ....... $'
TGateNo db 13, 10, 'The gate would not open: we stay. HIMEM has its megabyte back.', 13, 10, '$'
TFrames db '  frames drawn ....................... $'
TTicks  db '  ticks of our clock ................. $'
TFault  db 'The processor stopped us: exception $'
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
;  6. THE TABLES - six descriptors, and 48 interrupt gates
; ============================================================================
;  Four of the six lines start where DOS put us: CS * 16, written in here.
        xor  eax, eax           ; EAX = 0, the top half too
        mov  ax, cs             ; EAX = our segment
        shl  eax, 4             ; EAX = CS * 16: our first byte, a 32-bit address
        mov  [Base], eax        ; kept
        mov  word [Gdt+08h+2], ax       ; the start, bits 0-15, of each:
        mov  word [Gdt+10h+2], ax       ;  code 32, data 32,
        mov  word [Gdt+20h+2], ax       ;  code 16, data 16
        mov  word [Gdt+28h+2], ax
        shr  eax, 16            ; AL = bits 16-23
        mov  byte [Gdt+08h+4], al
        mov  byte [Gdt+10h+4], al
        mov  byte [Gdt+20h+4], al
        mov  byte [Gdt+28h+4], al
        mov  eax, [Base]        ; EAX = our first byte
        add  eax, Gdt           ; + the table's offset = the table's address
        mov  dword [GdtPtr+2], eax
        mov  eax, [Base]
        add  eax, Idt           ; the same for the interrupt table
        mov  dword [IdtPtr+2], eax
        mov  [RealCs], cs       ; and our segment, for the way back

;  THE IDT. Eight bytes a line, a GATE: where the routine is (a selector and
;  a 32-bit offset, the offset in two halves around the rest) and what kind
;  of gate - 8Eh, a 32-bit interrupt gate, present, which turns interrupts
;  off on the way in, as real mode's INT does. 0 to 31 are the processor's
;  complaints, 32 the timer, 33 the keyboard, 34 to 47 the IRQs we mask.
;  In C:   for (v = 0; v < 48; v++)
;              idt[v] = gate(08h, v < 32 ? exc[v] : v == 32 ? Tick
;                                 : v == 33 ? Key : Spur);
        xor  ebx, ebx           ; EBX = the vector, 0..47 - all 32 bits nought:
                                ;  it goes into a 32-bit address below
.g:     mov  ax, Spur           ; AX = the routine: by default, "nothing"
        cmp  bx, 32
        jae  .n1
        mov  ax, [ExcTab+ebx*2] ; 0..31: the stub for that complaint
.n1:    cmp  bx, 32
        jne  .n2
        mov  ax, Tick           ; 32: IRQ 0, the timer
.n2:    cmp  bx, 33
        jne  .n3
        mov  ax, Key            ; 33: IRQ 1, the keyboard
.n3:    mov  [Idt+ebx*8], ax            ; the offset, bits 0-15
        mov  word [Idt+ebx*8+2], 08h    ; the selector: our 32-bit code
        mov  word [Idt+ebx*8+4], 8E00h  ; byte 4 = 0, byte 5 = 8Eh: the kind
        mov  word [Idt+ebx*8+6], 0      ; the offset, bits 16-31: we are low
        inc  bx                 ; the next vector
        cmp  bx, 48
        jb   .g

; ============================================================================
;  7. THE MACHINE IS OURS - the picture, the controller, the timer, the bit
; ============================================================================
;  The interrupt controller, an 8259 at ports 20h and 21h, is told its
;  numbers in four bytes, ICW1 to ICW4 (initialisation command words). After
;  them its mask is clear, so the mask is written straight after: a 1 bit
;  shuts an IRQ out.
        mov  ax, 13h            ; mode 13h: 320 x 200, 256 colours - the BIOS
        int  10h                ;  does it, while we still have the BIOS
        cli                     ; nothing in between, from here to the gates
        in   al, 21h            ; AL = the master's mask
        mov  [Mask1], al        ; kept, to give back
        in   al, 0A1h           ; AL = the second controller's mask
        mov  [Mask2], al
        mov  al, 32             ; IRQ 0..7 as INT 32..39
        call PicMap
        mov  al, 11111100b      ; only IRQ 0, the timer, and 1, the keys
        out  21h, al
        mov  al, 11111111b      ; the second controller: nothing at all
        out  0A1h, al
        mov  al, 36h            ; lesson 26's timer: channel 0, low and high,
        out  43h, al            ;  square wave, binary
        mov  ax, 16384          ; 1193182 / 16384 = 72.8 ticks a second
        out  40h, al            ; the low byte...
        mov  al, ah
        out  40h, al            ; ...and the high
        mov  [RealSp], sp       ; real mode's stack, to come back to
        and  esp, 0FFFFh        ; ESP = SP: the top half nought, for 32 bits

;  NEW: LIDT [m], load the interrupt descriptor table register: LGDT's
;  twin, six bytes, the length less one and the address. Flags: none.
        lgdt [GdtPtr]           ; the descriptors
        lidt [IdtPtr]           ; the gates
        mov  eax, cr0           ; EAX = CR0
        or   al, 1              ; bit 0, PE = 1
        mov  cr0, eax           ; PROTECTED MODE - after the next jump
        jmp  08h:Pm32           ; CS = line 08h: 32-BIT code from here on

PicMap: mov  bl, al             ; BL = the first INT number for IRQ 0
        mov  al, 11h            ; ICW1: start; edge-triggered; two chips;
        out  20h, al            ;  ICW4 will come
        mov  al, bl             ; ICW2: the number for IRQ 0
        out  21h, al
        mov  al, 04h            ; ICW3: the second chip hangs on IRQ 2
        out  21h, al
        mov  al, 01h            ; ICW4: 8086 mode - a vector number each
        out  21h, al
        ret

; ============================================================================
;  32 BITS. Every instruction below is decoded the 32-bit way: EAX without a
;  66h in front, [EDI] without a 67h. CS = 08h, DS = SS = 10h - our data, at
;  the same offsets as ever - and ES = FS = 18h, flat: an offset there IS
;  the address.
; ============================================================================
        use32
Pm32:   mov  ax, 10h            ; selector 10h: our data, 32-bit
        mov  ds, ax
        mov  ss, ax             ; the stack: the same bytes, through 10h
        mov  ax, 18h            ; selector 18h: flat
        mov  es, ax             ; ES = flat: STOSD writes anywhere in 4 GB
        mov  fs, ax
        mov  gs, ax
        sti                     ; our gates are in: interrupts on

Frame:  ; ---- the bands, into the megabyte above 1 MB --------------------------
        mov  edi, [Phys]        ; EDI = HIMEM's megabyte: the back buffer
        xor  edx, edx           ; EDX = y = 0
.row:   mov  eax, edx           ; EAX = y
        add  eax, [Clk]         ; + our clock: the bands roll
        and  eax, 63            ; 0..63
        add  eax, 32            ; colours 32..95: the palette's rainbow
        imul eax, eax, 01010101h ; the colour in all four bytes
        mov  ecx, 320/4         ; ECX = 80 double words: one row
        rep  stosd              ; ES:EDI, four pixels a write, EDI moves on
        inc  edx                ; y++
        cmp  edx, 200
        jb   .row

        ; ---- the square: one step for each tick of our clock -------------
.tick:  mov  eax, [Clk]         ; EAX = our clock now
        cmp  eax, [Seen]        ; ticks we have not moved for?
        je   .box
        inc  dword [Seen]       ; one of them...
        call Move               ; ...one step
        jmp  .tick
.box:   imul edi, [BoxY], 320   ; EDI = y * 320: IMUL with three operands
        add  edi, [BoxX]        ; + x
        add  edi, [Phys]        ; + the buffer: the square's corner, an address
        mov  edx, 24            ; EDX = 24 rows
.b:     mov  eax, 0F0F0F0Fh     ; colour 15, white, four times
        mov  ecx, 24/4          ; ECX = 6 double words: 24 pixels
        rep  stosd
        add  edi, 320 - 24      ; EDI = the next row's first pixel
        dec  edx
        jnz  .b

        ; ---- the buffer to the screen: 64000 bytes from one address to
        ;      another, both of them just numbers --------------------------
        push ds                 ; MOVSD reads DS:ESI - so DS is flat for it
        mov  esi, [Phys]        ; ESI = the back buffer, above 1 MB
        mov  ax, 18h
        mov  ds, ax             ; DS = flat
        mov  edi, 0A0000h       ; EDI = the screen: 0A000h * 16, an address
        mov  ecx, 64000/4       ; ECX = 16000 double words
        rep  movsd              ; the picture
        pop  ds                 ; DS = our data again

        inc  dword [Frames]     ; frames++
        cmp  byte [EscHit], 0   ; was Esc pressed, however briefly?
        je   Frame              ;   no: the next frame

        ; Esc went down. Its UP code must come to us too: let it reach the
        ; BIOS in real mode, which never saw it go down, and the machine is
        ; handed back with a key half pressed. Measured: DOSBox-X fell over
        ; at its next command when we did not wait.
.up:    cmp  byte [Keys+1], 0   ; Esc still held?
        jne  .up                ;   yes: wait for it to come up
        cli                     ; home, with nothing cutting in
        jmp  ToReal

; ---- the arrows: two pixels a tick, kept on the screen ------------------------
;  The scan codes: 48h up, 50h down, 4Bh left, 4Dh right.
Move:   cmp  byte [Keys+48h], 0 ; up?
        je   .dn
        cmp  dword [BoxY], 2    ; not off the top
        jl   .dn
        sub  dword [BoxY], 2    ; y -= 2
.dn:    cmp  byte [Keys+50h], 0 ; down?
        je   .lf
        cmp  dword [BoxY], 200 - 24 - 2
        jg   .lf
        add  dword [BoxY], 2    ; y += 2
.lf:    cmp  byte [Keys+4Bh], 0 ; left?
        je   .rt
        cmp  dword [BoxX], 2
        jl   .rt
        sub  dword [BoxX], 2    ; x -= 2
.rt:    cmp  byte [Keys+4Dh], 0 ; right?
        je   .x
        cmp  dword [BoxX], 320 - 24 - 2
        jg   .x
        add  dword [BoxX], 2    ; x += 2
.x:     ret

; ---- INT 32, IRQ 0: OUR CLOCK -------------------------------------------------
;  An interrupt arrives with whatever DS was running - in the copy above it
;  is the flat one - so the first thing is our own. IRETD is IRET for 32
;  bits: it takes EIP, CS and the flags back, four bytes each.
Tick:   push eax
        push ds
        mov  ax, 10h
        mov  ds, ax             ; DS = our data
        inc  dword [Clk]        ; clk++: 72.8 a second
        test byte [Clk], 3      ; the low two bits nought: every fourth tick
        jnz  .eoi
        mov  ax, 18h
        mov  ds, ax             ; DS = flat: the BIOS's data at 400h on
        inc  dword [46Ch]       ; the BIOS's clock, 0040:006C, one more
        cmp  dword [46Ch], 1800B0h      ; a whole day of its ticks?
        jb   .eoi
        mov  dword [46Ch], 0    ;   midnight: back to nought,
        mov  byte [470h], 1     ;   and the flag that says a day went by
.eoi:   mov  al, 20h            ; to the controller: done
        out  20h, al
        pop  ds
        pop  eax
        iretd

; ---- INT 33, IRQ 1: OUR KEYS - lesson 23's handler, in 32 bits -----------------
;  Port 60h holds the scan code: bit 7 clear when a key goes down, set when
;  it comes up. Keys[code] = 1 while it is held.
Key:    push eax
        push ebx
        push ds
        mov  ax, 10h
        mov  ds, ax             ; DS = our data
        in   al, 60h            ; AL = the scan code
        movzx ebx, al           ; EBX = it, for an address
        and  bl, 7Fh            ; EBX = the key, without the up-or-down bit
        shr  al, 7              ; AL = 1 if it came up, 0 if it went down
        xor  al, 1              ; AL = 1 if it is held now
        mov  [Keys+ebx], al     ; keys[code] = held
        cmp  ebx, 1             ; Esc?
        jne  .eoi
        or   [EscHit], al       ; remembered: a tap shorter than one frame
                                ;  goes down AND up before the loop looks
.eoi:   mov  al, 20h            ; to the controller: done
        out  20h, al
        pop  ds
        pop  ebx
        pop  eax
        iretd

; ---- INT 34..47: masked IRQs. Only a spurious one could come: nothing to do ---
Spur:   iretd

; ---- INT 0..31: THE PROCESSOR COMPLAINS ---------------------------------------
;  A divide by nought is INT 0, a wrong selector INT 13. With no gate for it
;  the processor would fault again, then a third time - and on the third it
;  resets the machine. So each has a stub: it notes its number and goes
;  home, and DOS prints the number. The stack is left as it lies: the way
;  back sets a new one.
rept 32 n:0
{
Exc#n:  push n                  ; the vector's number
        jmp  ExcAll
}
ExcAll: mov  ax, 10h
        mov  ds, ax             ; DS = our data
        pop  eax                ; EAX = the number the stub pushed
        mov  [Fault], eax       ; kept, to print
                                ; ...and home: ToReal is next

; ---- HOME: line 28h into every segment, then the 16-bit code line -------------
ToReal: mov  ax, 28h            ; selector 28h: 64K, real mode's shape
        mov  ds, ax
        mov  es, ax
        mov  fs, ax
        mov  gs, ax
        mov  ss, ax
        jmp  20h:Back16         ; CS = line 20h: 16-bit code again

        use16
Back16: mov  eax, cr0           ; EAX = CR0
        and  al, 0FEh           ; bit 0, PE = 0
        mov  cr0, eax           ; REAL MODE - after the next jump
        push word [RealCs]      ; a far jump to a segment known only at run
        push word Rm            ;  time: push it and its offset, and RETF
        retf
Rm:     mov  ax, cs             ; AX = our segment
        mov  ds, ax             ; DS, ES, SS = paragraphs again
        mov  es, ax
        mov  ss, ax
        mov  sp, [RealSp]       ; the stack as it was
        xor  ax, ax
        mov  fs, ax             ; FS, GS = 0, as we found them
        mov  gs, ax
        lidt [RealIdt]          ; real mode's vectors: 256 of them at 0000:0000
        mov  al, 8              ; IRQ 0..7 as INT 8..15 again
        call PicMap
        mov  al, [Mask1]        ; and the masks as they were
        out  21h, al
        mov  al, [Mask2]
        out  0A1h, al
        mov  al, 36h            ; the timer: channel 0, low and high, square
        out  43h, al
        xor  al, al             ; nought means 65536: 18.2 a second again
        out  40h, al
        out  40h, al
        sti                     ; interrupts back: we are home
        mov  ax, 3              ; text mode
        int  10h

        mov  dx, TFrames        ; '  frames drawn ...'
        call Puts
        mov  eax, [Frames]
        call Dec32
        mov  dx, CrLf
        call Puts
        mov  dx, TTicks         ; '  ticks of our clock ...'
        call Puts
        mov  eax, [Clk]
        call Dec32
        mov  dx, CrLf
        call Puts
        cmp  dword [Fault], -1  ; did the processor complain?
        je   .ok
        mov  dx, TFault         ; 'The processor stopped us: exception '
        call Puts
        mov  eax, [Fault]
        call Dec32
        mov  dx, CrLf
        call Puts
.ok:    mov  dx, TBack          ; 'Back in real mode: DOS is printing this.'
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
Mask1   db 0                    ; the interrupt controllers' masks, as found
Mask2   db 0
Xms     dd 0                    ; HIMEM's entry: offset, then segment
Big     dw 0                    ; the largest free block, KB
All     dw 0                    ; all that is free, KB
Handle  dw 0                    ; HIMEM's number for our megabyte
Phys    dd 0                    ; where it is: a 32-bit address
Base    dd 0                    ; CS * 16: our first byte, as an address
RealCs  dw 0                    ; our segment, for the way back
RealSp  dw 0                    ; the stack pointer, for the way back
Clk     dd 0                    ; our clock: 72.8 ticks a second
Seen    dd 0                    ; the ticks the square has moved for
Frames  dd 0                    ; frames drawn
Fault   dd -1                   ; the processor's complaint, if it made one
BoxX    dd 148                  ; the square's corner, in pixels
BoxY    dd 88
EscHit  db 0                    ; 1 once Esc has gone down
Keys    rb 128                  ; Keys[scan code] = 1 while it is held

ExcTab:                         ; where each of the 32 stubs is
rept 32 n:0
{
        dw Exc#n
}

; ---- the GDT: six descriptors, eight bytes each --------------------------------
;  bytes 0-1 the length less one, bits 0-15     bytes 2-3 the start, 0-15
;  byte  4   the start, bits 16-23              byte  5   what it is:
;                                                   9Ah code, run and read
;                                                   92h data, read and write
;  byte  6   high nibble: G (length counted in 4K pieces) and D/B (32-bit);
;            low nibble: the length, bits 16-19
;  byte  7   the start, bits 24-31
        align 8                 ; the processor reads it fastest on 8
Gdt     dw 0, 0, 0, 0                   ; 00h: empty, by the rules
        dw 0FFFFh, 0                    ; 08h: our code, 32-bit, 4 GB...
        db 0, 9Ah, 0CFh, 0              ;  ...the start filled in at run time
        dw 0FFFFh, 0                    ; 10h: our data, 32-bit, 4 GB
        db 0, 92h, 0CFh, 0
        dw 0FFFFh, 0                    ; 18h: FLAT - start 0, all 4 GB
        db 0, 92h, 0CFh, 0
        dw 0FFFFh, 0                    ; 20h: our code, 16-bit, 64K
        db 0, 9Ah, 00h, 0
        dw 0FFFFh, 0                    ; 28h: our data, 16-bit, 64K
        db 0, 92h, 00h, 0
GdtPtr: dw 6*8-1                ; the table's length less one
        dd 0                    ; and its address, filled in at run time
IdtPtr: dw 48*8-1               ; 48 gates
        dd 0                    ; the address, filled in at run time
RealIdt:dw 256*4-1              ; real mode's: 256 vectors of four bytes...
        dd 0                    ; ...at address nought
        align 8
Idt:    rb 48*8                 ; the gates, written at run time
