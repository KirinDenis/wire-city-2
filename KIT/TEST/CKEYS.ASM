; CKEYS.ASM - test of KIT\LIB\K_KEYS.INC: hook INT 9, a key fed through
; KEY_REMOTE (INT 16h 05h into the BIOS buffer), the held table and the
; tap latch, KEY_NEW / KEY_ANY / KEY_PEEK / KEY_WAIT on poked tables, a
; press and release through the real handler (the 8042 command D2h), the
; vector given back, the BIOS path. With /AUTO it quits by itself.
        org  100h
        include '..\..\ENGINE\E_8086.INC'

; EXPECT v, 'name' - AX must be v: a PASS/FAIL line with what AX was
macro EXPECT v, text
{
        local ..str, ..skip
        mov  [got],ax
        cmp  ax,v
        mov  si, ..str
        call RESULT
        jmp ..skip
..str     db   text,0
..skip:
}
; KEEPS fn, axin, 'name' - fn called with AX = axin must keep BX CX DX SI
; DI BP ES and AX too (for a routine with no answer)
macro KEEPS fn, axin, text
{
        local ..bad, ..done
        mov  ax,axin
        mov  [kax],ax
        mov  ax,[kax]
        mov  bx,0FA0h
        mov  cx,2222h
        mov  dx,3333h
        mov  si,4444h
        mov  di,5555h
        mov  bp,6666h
        push ds
        pop  es
        call fn
        cmp  ax,[kax]
        jne ..bad
        cmp  bx,0FA0h
        jne ..bad
        cmp  cx,2222h
        jne ..bad
        cmp  dx,3333h
        jne ..bad
        cmp  si,4444h
        jne ..bad
        cmp  di,5555h
        jne ..bad
        cmp  bp,6666h
        jne ..bad
        mov  ax,es
        mov  bx,ds
        cmp  ax,bx
        jne ..bad
        xor  ax,ax
        jmp ..done
..bad:    mov  ax,1
..done:   EXPECT 0, text
}

; STUFF scan, char - put a key into the BIOS buffer as a script would
macro STUFF sc, chr
{
        mov  cx,sc*256+chr
        mov  ah,05h
        int  16h
}
; ZFIS v, 'name' - after a ZF answer: AX = 1 if NZ, 0 if ZF, must be v
macro ZFIS v, text
{
        local ..z, ..d
        jz ..z
        mov  ax,1
        jmp ..d
..z:      xor  ax,ax
..d:      EXPECT v, text
}

start:  call GETAUTO
        call KEY_FLUSH          ; nothing from the command line typed
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:9*4]
        mov  [v9o],ax           ; the BIOS's vector, to compare later
        mov  ax,[es:9*4+2]
        mov  [v9s],ax
        push ds
        pop  es
        call KEY_ON
        call KEY_ON             ; twice: the second must do nothing
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:9*4]
        mov  bx,[es:9*4+2]
        push ds
        pop  es
        cmp  ax,KEY_INT9
        jne  .h1
        mov  ax,cs
        cmp  bx,ax
.h1:    ZFIS 0, 'KEY_ON vector 9 = our handler (called twice)'
        ; ---- a key fed through the BIOS buffer ----
        STUFF SC_SPACE, ' '
        call KEY_REMOTE         ; frame 1: the key arrives
        mov  al,SC_SPACE
        call KEY_HELD
        ZFIS 1, 'KEY_REMOTE: Space held'
        mov  al,SC_SPACE
        call KEY_TAP
        ZFIS 1, 'KEY_TAP Space: latched'
        mov  al,SC_SPACE
        call KEY_TAP
        ZFIS 0, 'KEY_TAP Space again: consumed'
        mov  cx,25              ; 25 frames: past key_rhmax (20)
.r:     call KEY_REMOTE
        loop .r
        mov  al,SC_SPACE
        call KEY_HELD
        ZFIS 0, 'KEY_REMOTE: Space let go after its frames'
        ; a tap fed and let go before anyone looked: the latch keeps it
        STUFF SC_ENTER, 13
        call KEY_REMOTE
        mov  cx,25
.r2:    call KEY_REMOTE
        loop .r2
        mov  al,SC_ENTER
        call KEY_HELD
        ZFIS 0, 'Enter up again'
        mov  al,SC_ENTER
        call KEY_TAP
        ZFIS 1, 'KEY_TAP Enter: the tap between frames kept'
        ; ---- the real handler: a make and a break through the 8042 ----
        mov  al,SC_X
        call KBC_SEND
        cmp  byte [key_hit+SC_X],0   ; did the make reach our handler?
        jne  .i2
        mov  si,t_skip          ; the emulator has no D2h: not a failure
        call PUTS
        call NL
        jmp  .i3
.i2:    mov  al,SC_X+80h
        call KBC_SEND
        mov  al,SC_X
        call KEY_HELD
        mov  ax,0
        jz   .i1
        inc  ax
.i1:    mov  bl,[key_hit+SC_X]
        mov  bh,0
        mov  cl,8
        shl  bx,cl
        or   ax,bx              ; AH = latch, AL = held
        EXPECT 0100h, 'INT 9 handler: X pressed + released = latch 1, held 0'
        mov  byte [key_hit+SC_X],0
        ; typematic: two makes, the latch fires once
        mov  al,SC_Z
        call KBC_SEND
        mov  al,SC_Z
        call KEY_TAP
        mov  al,SC_Z
        call KBC_SEND           ; a repeat while held
        mov  al,SC_Z
        call KEY_TAP
        ZFIS 0, 'INT 9 handler: a typematic repeat does not re-latch'
        mov  al,SC_Z+80h
        call KBC_SEND
        ; E0 prefix + grey arrow: lands in the arrow's cell
        mov  al,0E0h
        call KBC_SEND
        mov  al,SC_UP
        call KBC_SEND
        mov  al,SC_UP
        call KEY_HELD
        ZFIS 1, 'INT 9 handler: E0 48 = Up held'
        mov  al,0E0h
        call KBC_SEND
        mov  al,SC_UP+80h
        call KBC_SEND
        mov  al,SC_UP
        call KEY_HELD
        ZFIS 0, 'INT 9 handler: E0 C8 = Up let go'
        mov  al,[key_held+60h]
        xor  ah,ah
        EXPECT 0, 'INT 9 handler: E0 left no cell 60h'
.i3:    call KEY_FLUSH
        ; ---- edges and sweeps on poked tables ----
        mov  byte [key_held+SC_A],1
        call KEY_NEW
        EXPECT SC_A, 'KEY_NEW = A, newly down'
        call KEY_NEW
        EXPECT 0, 'KEY_NEW again = 0 (still held, not new)'
        mov  byte [key_held+SC_A],0
        call KEY_NEW
        EXPECT 0, 'KEY_NEW after the release = 0'
        mov  byte [key_hit+SC_Q],1
        mov  byte [key_hit+SC_D],1
        call KEY_ANY
        xor  ah,ah
        EXPECT SC_Q, 'KEY_ANY = Q, the lowest latched'
        call KEY_ANY
        ZFIS 0, 'KEY_ANY clears every latch (D gone too)'
        mov  byte [key_hit+SC_Z],1
        call KEY_PEEK
        EXPECT SC_Z*256, 'KEY_PEEK hooked: AH = Z, AL = 0'
        call KEY_PEEK
        ZFIS 1, 'KEY_PEEK leaves it'
        call KEY_WAIT
        EXPECT SC_Z*256, 'KEY_WAIT hooked: AH = Z'
        mov  byte [key_hit+SC_W],1
        call KEY_FLUSH
        mov  al,SC_W
        call KEY_TAP
        ZFIS 0, 'KEY_FLUSH clears the latches'
        mov  al,SC_W+80h        ; bit 7 set: still the W cell
        mov  byte [key_held+SC_W],1
        call KEY_HELD
        ZFIS 1, 'KEY_HELD masks bit 7'
        mov  byte [key_held+SC_W],0
        ; ---- registers ----
        KEEPS KEY_HELD, SC_W, 'KEY_HELD keeps registers'
        KEEPS KEY_TAP, SC_W, 'KEY_TAP keeps registers'
        KEEPS KEY_REMOTE, 1234h, 'KEY_REMOTE keeps registers'
        KEEPS KEY_FLUSH, 1234h, 'KEY_FLUSH keeps registers'
        KEEPS KEY_ON, 1234h, 'KEY_ON keeps registers'
        ; ---- give it back ----
        STUFF SC_C, 'c'
        KEEPS KEY_OFF, 1234h, 'KEY_OFF keeps registers'
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:9*4]
        mov  bx,[es:9*4+2]
        push ds
        pop  es
        cmp  ax,[v9o]
        jne  .o1
        cmp  bx,[v9s]
.o1:    ZFIS 0, 'KEY_OFF vector 9 = the BIOS again'
        call KEY_PEEK
        ZFIS 0, 'KEY_OFF emptied the BIOS buffer'
        call KEY_OFF            ; twice: nothing
        ; ---- the BIOS path ----
        STUFF SC_X, 'x'
        call KEY_PEEK
        EXPECT SC_X*256+'x', 'KEY_PEEK BIOS: AX = 2D78h (X, x)'
        call KEY_WAIT
        EXPECT SC_X*256+'x', 'KEY_WAIT BIOS: AX = 2D78h'
        call KEY_PEEK
        ZFIS 0, 'KEY_PEEK BIOS: empty after the wait'
        jmp  FINISH

; KBC_SEND - AL into the keyboard controller's output buffer (8042 command
; D2h): IRQ 1 fires and INT 9 reads it as if a key had been struck. Waits
; up to 2 ticks for the handler to empty the buffer. DOSBox 0.74 answers
; D2h with nothing (port 60h reads FAh): the test then says SKIP.
KBC_SEND:
        push ax
        push cx
        mov  ah,al
.w1:    in   al,64h             ; the controller ready for a command?
        test al,2
        jnz  .w1
        mov  al,0D2h            ; "write the keyboard output buffer"
        out  64h,al
.w2:    in   al,64h
        test al,2
        jnz  .w2
        mov  al,ah
        out  60h,al             ; the byte, as a scan code
        call TIM_TICK
        mov  cx,ax
.w3:    in   al,64h             ; bit 0 = the byte still waits
        test al,1
        jz   .ok                ;   gone: the handler read port 60h
        call TIM_TICK
        sub  ax,cx              ; ticks waited
        cmp  ax,2
        jb   .w3
        jmp  .out
.ok:    mov  ax,1               ; one more tick for the IRQ to finish
        call TIM_WAIT
.out:   pop  cx
        pop  ax
        ret

v9o     dw 0
v9s     dw 0
kax     dw 0
t_skip  db 'SKIP INT 9 handler via the 8042 D2h: this emulator does not do it',0

; ============================================================================
;  the test's own helpers (not kit blocks)
; ============================================================================
; FINISH - the summary line; without /AUTO wait for Esc; exit
FINISH: mov  ax,[fails]
        or   ax,ax
        jnz  .f
        mov  dx,t_all
        mov  ah,9
        int  21h
        jmp  .w
.f:     call PUTN
        mov  dx,t_nf
        mov  ah,9
        int  21h
.w:     cmp  byte [auto],0
        jne  .x
        mov  dx,t_esc
        mov  ah,9
        int  21h
.k:     mov  ah,0
        int  16h
        cmp  ah,1               ; Esc?
        jne  .k
.x:     mov  ax,4C00h
        int  21h

; GETAUTO - [auto] = 1 if the command line holds /AUTO
GETAUTO:mov  si,81h
        xor  ch,ch
        mov  cl,[80h]           ; the tail's length
.s:     jcxz .no
        lodsb
        dec  cx
        cmp  al,'/'
        jne  .s
        cmp  cx,4
        jb   .no
        mov  ax,[si]
        and  ax,0DFDFh          ; upper case
        cmp  ax,'AU'
        jne  .s
        mov  ax,[si+2]
        and  ax,0DFDFh
        cmp  ax,'TO'
        jne  .s
        mov  byte [auto],1
.no:    ret

; RESULT - ZF = 1 pass: "PASS name = got", else "FAIL ..." and fails++
RESULT: jnz  .f
        mov  dx,t_pass
        jmp  .p
.f:     mov  dx,t_fail
        inc  word [fails]       ; one more failure
.p:     mov  ah,9
        int  21h
        call PUTS
        mov  dx,t_got
        mov  ah,9
        int  21h
        mov  ax,[got]
        call PUTN
        call NL
        ret

; PUTS - the 0-ended string at SI
PUTS:   lodsb
        or   al,al
        jz   .d
        mov  dl,al
        mov  ah,2
        int  21h
        jmp  PUTS
.d:     ret

; PUTN - AX as a signed decimal number
PUTN:   or   ax,ax
        jns  .p
        push ax
        mov  dl,'-'
        mov  ah,2
        int  21h
        pop  ax
        neg  ax                 ; AX = |AX|
.p:     xor  cx,cx              ; CX = digits stacked
        mov  bx,10
.d:     xor  dx,dx
        div  bx                 ; AX = AX / 10, DX = the digit (BX = 10)
        push dx
        inc  cx                 ; one more digit
        or   ax,ax
        jnz  .d
.o:     pop  dx
        add  dl,'0'             ; the digit as a character
        mov  ah,2
        int  21h
        loop .o
        ret

NL:     mov  dx,t_nl
        mov  ah,9
        int  21h
        ret

auto    db   0
got     dw   0
fails   dw   0
t_pass  db   'PASS $'
t_fail  db   'FAIL $'
t_got   db   '  got $'
t_nl    db   13,10,'$'
t_all   db   'ALL PASS',13,10,'$'
t_nf    db   ' FAILED',13,10,'$'
t_esc   db   'Esc quits.',13,10,'$'

        include '..\..\KIT\LIB\K_KEYS.INC'
        include '..\..\KIT\LIB\K_TIME.INC'
