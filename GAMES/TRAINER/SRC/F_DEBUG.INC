; ============================================================================
;  F_DEBUG.INC - the umbilical for the debug harness (\Debug\FlyDbg.cs).
;  COM1 at 115200, carried by the DOSBox nullmodem into TCP. Every
;  physics tick we drain remote key events (bit7 = press, low 7 bits =
;  scancode, written straight into the same KEYS table the cockpit
;  reads - no window focus needed) and send one telemetry line:
;      T tick vel alt pit rol hdg thr wrn dead
;  If no UART answers the scratch-register probe (a browser bundle, a
;  bare machine) the whole channel switches itself off; a stuck THR
;  unplugs it too, so a dead line can never hang the game.
; ============================================================================
UARTB   equ 3F8h

DBGINIT:
        mov  dx,UARTB+7         ; scratch probe: is anyone there?
        mov  al,5Ah
        out  dx,al
        in   al,dx
        cmp  al,5Ah
        je   @@have
        mov  byte ptr [dbgon],0
        ret
@@have: mov  byte ptr [dbgon],1
        mov  bx,7*2             ; self-test: poke thr=55 via the table
        mov  si,[POKETAB+bx]
        mov  word ptr [si],55
        mov  dx,UARTB+3
        mov  al,80h             ; DLAB on
        out  dx,al
        mov  dx,UARTB
        mov  al,1               ; divisor 1 = 115200
        out  dx,al
        mov  dx,UARTB+1
        xor  al,al
        out  dx,al
        mov  dx,UARTB+3
        mov  al,03h             ; 8N1, DLAB off
        out  dx,al
        mov  dx,UARTB+1
        xor  al,al              ; we poll, no interrupts
        out  dx,al
        mov  dx,UARTB+4
        mov  al,03h             ; DTR+RTS up
        out  dx,al
        ret

DBGTICK:
        cmp  byte ptr [dbgon],0
        jne  @@on
        ret
@@on:   inc  word ptr [dtick]
        ; ---- drain the remote keyboard ----
@@rx:   mov  dx,UARTB+5
        in   al,dx
        test al,1
        jz   @@tx
        mov  dx,UARTB
        in   al,dx
        inc  word ptr [drxn]    ; instrument: count every received byte
        mov  ah,al
        xor  ah,ah
        mov  [dlast],ax         ; ...and remember the raw value
        cmp  byte ptr [dstate],0
        jne  @@pk
        cmp  al,7Fh             ; escape: a state poke follows
        jne  @@key
        mov  byte ptr [dstate],1
        jmp  @@rx
@@key:  mov  ah,al
        and  al,7Fh
        mov  bl,al
        xor  bh,bh
        mov  al,1
        test ah,80h
        jnz  @@st
        xor  al,al
@@st:   mov  [KEYS+bx],al
        jmp  @@rx
@@pk:   cmp  al,7Fh             ; a fresh escape restarts the sequence
        jne  @@pk1
        mov  byte ptr [dstate],1
        jmp  @@rx
@@pk1:  mov  ah,al              ; nibbles ride as 40h..4Fh (telnet-safe)
        and  ah,0F0h
        cmp  ah,40h
        jne  @@pkab
        and  ax,000Fh
        mov  bl,[dstate]
        inc  byte ptr [dstate]
        cmp  bl,1
        je   @@pi1
        cmp  bl,2
        je   @@pi2
        cmp  bl,3
        jne  @@pv2
        mov  [dpval],ax         ; first value nibble
        jmp  @@rx
@@pv2:  mov  cl,4
        shl  word ptr [dpval],cl
        or   [dpval],ax
        cmp  bl,6
        jb   @@rx
        mov  bl,[dpidx]         ; all six in: commit the word
        xor  bh,bh
        cmp  bl,11
        jae  @@pkx
        add  bx,bx
        mov  si,[POKETAB+bx]
        mov  ax,[dpval]
        mov  [si],ax
@@pkx:  inc  word ptr [dpkn]    ; instrument: completed pokes
        mov  byte ptr [dstate],0
        jmp  @@rx
@@pi1:  mov  [dpidx],al
        jmp  @@rx
@@pi2:  mov  cl,4
        shl  byte ptr [dpidx],cl
        or   [dpidx],al
        jmp  @@rx
@@pkab: mov  byte ptr [dstate],0
        jmp  @@key
        ; ---- one telemetry line ----
@@tx:   push es
        mov  ax,cs
        mov  es,ax
        mov  di,offset DBUF
        mov  al,'T'
        stosb
        mov  ax,[dtick]
        call DNUM
        mov  ax,[vel]
        call DNUM
        mov  ax,[apy]
        call DNUM
        mov  ax,[pit]
        call DNUM
        mov  ax,[rol]
        call DNUM
        mov  ax,[hdg]
        call DNUM
        mov  ax,[thr]
        call DNUM
        mov  ax,[wrn]
        call DNUM
        mov  ax,[dead]
        call DNUM
        mov  ax,[apx]
        call DNUM
        mov  ax,[apz]
        call DNUM
        mov  ax,[chdgf]
        call DNUM
        mov  ax,[gpit]
        call DNUM
        mov  ax,[drxn]
        call DNUM
        mov  ax,[dlast]
        call DNUM
        mov  ax,[dpkn]
        call DNUM
        mov  al,13
        stosb
        mov  al,10
        stosb
        mov  si,offset DBUF
@@s1:   cmp  si,di
        jae  @@done
        mov  cx,4000            ; THR guard: a dead line unplugs, not hangs
@@s2:   mov  dx,UARTB+5
        in   al,dx
        test al,20h
        jnz  @@s3
        loop @@s2
        mov  byte ptr [dbgon],0
        pop  es
        ret
@@s3:   lodsb
        mov  dx,UARTB
        out  dx,al
        jmp  @@s1
@@done: pop  es
        ret

; DNUM - AX signed -> ' ' + decimal digits at ES:DI
DNUM:   push ax
        mov  al,' '
        stosb
        pop  ax
        or   ax,ax
        jns  @@pos
        push ax
        mov  al,'-'
        stosb
        pop  ax
        neg  ax
@@pos:  xor  cx,cx
        mov  bx,10
@@div:  xor  dx,dx
        div  bx
        push dx
        inc  cx
        or   ax,ax
        jnz  @@div
@@out:  pop  ax
        add  al,'0'
        stosb
        loop @@out
        ret

drxn    dw 0
dlast   dw 0
dpkn    dw 0
dstate  db 0
dpidx   db 0
dpval   dw 0
dbgslow dw 0
dbgon   db 0
dtick   dw 0
DBUF    db 128 dup(0)
