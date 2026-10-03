; KEYB.INC - part of WIRE CITY (included from OWLFLY3.ASM)
; ============================================================================
;  KEYBOARD INTERRUPT HANDLER (INT 9)
;  Own key-state table KEYS[scancode] = 1 pressed / 0 released
; ============================================================================
KBINT:  push ax
        push bx
        push di
        push ds
        mov  ax,cs
        mov  ds,ax
        in   al,60h
        mov  ah,al
        and  al,7Fh
        mov  bl,al
        xor  bh,bh
        mov  di,KEYS
        add  di,bx
        test ah,80h
        jnz  .brk
        mov  byte [di],1
        add  di,KHIT-KEYS       ; ...and LATCH it: the same scan code in the
        mov  byte [di],1        ;  hit table, which nothing clears but the
        call VIDSEG:KMAKEF      ; BOND: ...and STAMP it (VID.INC: how long
        jmp  .eoi               ;  it is held). A tap between two frames is
                                ;  invisible in KEYS and cannot be lost
                                ;  here - see the note beside KHIT.
.brk:  mov  byte [di],0
        call VIDSEG:KBRKF       ; BOND: bank the ticks it was held
.eoi:  mov  al,20h
        out  20h,al
        pop  ds
        pop  di
        pop  bx
        pop  ax
        iret
