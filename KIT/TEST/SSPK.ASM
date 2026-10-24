; SSPK.ASM - proves KIT\LIB\K_SPK.INC: the PC speaker's effects, tune, drone.
;
;   SSPK /AUTO  runs every effect of the table through SPK_TICK, checks it
;               ends after its own number of ticks with the gate open while
;               it plays and shut after; priority, mute, a tune, a looping
;               tune, the drone, SPK_NOTE, registers kept. PASS/FAIL lines.
;   SSPK        a person listens: keys 1..9,0 the effects, T a tune,
;               D the drone, M mute, Esc quits.
        org  100h
        include '..\..\ENGINE\E_8086.INC'

        cld
        call ISAUTO
        jnc  AUTO
        jmp  HAND

; ============================================================================
AUTO:   mov  dx,m_head
        call PUTS
        ; ---- 1. every effect: its ticks, the gate open while it plays
        mov  byte [id],1
.e:     call SPK_STOP
        mov  al,[id]
        call SPK_FX
        xor  cx,cx              ; ticks counted
.t:     call SPK_TICK
        inc  cx                 ; one more tick
        cmp  cx,1
        jne  .t1
        in   al,61h
        and  al,3
        cmp  al,3
        je   .t1
        mov  byte [gatebad],1   ; the gate did not open
.t1:    cmp  byte [spk_fx],0
        je   .td
        cmp  cx,300
        jb   .t
.td:    mov  dx,m_fx
        call PUTS
        mov  al,[id]
        xor  ah,ah
        call PUTN
        mov  dx,m_ticks
        call PUTS
        mov  ax,cx
        call PUTN
        mov  bl,[id]
        xor  bh,bh
        mov  al,[spk_tfrm+bx]
        xor  ah,ah
        cmp  ax,cx
        je   .ok
        mov  byte [bad],1
        mov  dx,m_nok
        call PUTS
        jmp  .nx
.ok:    mov  dx,m_ok
        call PUTS
.nx:    call SPK_TICK           ; one tick more: nothing left, the gate shuts
        in   al,61h
        test al,3
        jz   .sh
        mov  byte [gatebad],1
.sh:    inc  byte [id]
        cmp  byte [id],SPX_N
        jbe  .e
        mov  dx,m_p1
        cmp  byte [bad],0
        je   .p1
        mov  dx,m_f1
.p1:    call PUTS
        mov  dx,m_p2
        cmp  byte [gatebad],0
        je   .p2
        mov  dx,m_f2
.p2:    call PUTS

        ; ---- 2. priority: a click is not heard over an explosion
        mov  al,SPX_BOOM
        call SPK_FX
        mov  al,SPX_CLICK
        call SPK_FX
        mov  dx,m_p3
        cmp  byte [spk_fx],SPX_BOOM
        je   .p3
        mov  dx,m_f3
.p3:    call PUTS
        mov  al,SPX_OVER        ; a bigger one takes over
        call SPK_FX
        mov  dx,m_p4
        cmp  byte [spk_fx],SPX_OVER
        je   .p4
        mov  dx,m_f4
.p4:    call PUTS
        call SPK_STOP

        ; ---- 3. mute: nothing starts, the gate stays shut
        mov  byte [spk_mute],1
        mov  al,SPX_COIN
        call SPK_FX
        mov  ax,3000
        call SPK_DRONE
        call SPK_TICK
        in   al,61h
        and  al,3
        mov  dx,m_p5
        jnz  .f5
        cmp  byte [spk_fx],0
        je   .p5
.f5:    mov  dx,m_f5
.p5:    call PUTS
        mov  byte [spk_mute],0
        call SPK_STOP

        ; ---- 4. a tune of 2+2+3+1 ticks: over on the 9th tick
        mov  si,tune1
        call SPK_TUNE
        xor  cx,cx
.u:     call SPK_TICK
        inc  cx                 ; one more tick
        cmp  word [spk_tp],0
        je   .ud
        cmp  cx,100
        jb   .u
.ud:    mov  dx,m_tune
        call PUTS
        mov  ax,cx
        call PUTN
        mov  dx,m_crlf
        call PUTS
        mov  dx,m_p6
        cmp  cx,9
        je   .p6
        mov  dx,m_f6
.p6:    call PUTS

        ; ---- 5. a looping tune runs on until SPK_STOP; registers kept
        mov  si,tune2
        call SPK_TUNE
        mov  al,SPX_ALARM       ; an effect over it, too
        call SPK_FX
        mov  cx,40
.l:     mov  ax,1111h           ; every register a known value
        mov  bx,2222h
        mov  dx,4444h
        mov  si,5555h
        mov  di,6666h
        mov  bp,7777h
        push cx
        mov  cx,3333h
        call SPK_TICK
        cmp  ax,1111h
        jne  .rb
        cmp  bx,2222h
        jne  .rb
        cmp  cx,3333h
        jne  .rb
        cmp  dx,4444h
        jne  .rb
        cmp  si,5555h
        jne  .rb
        cmp  di,6666h
        jne  .rb
        cmp  bp,7777h
        je   .rk
.rb:    mov  byte [regbad],1
.rk:    pop  cx
        loop .l
        mov  dx,m_p7
        cmp  word [spk_tp],0
        jne  .p7
        mov  dx,m_f7
.p7:    call PUTS
        call SPK_STOP
        in   al,61h
        and  al,3
        mov  dx,m_p8
        jnz  .f8
        cmp  word [spk_tp],0
        je   .p8
.f8:    mov  dx,m_f8
.p8:    call PUTS
        mov  dx,m_p9
        cmp  byte [regbad],0
        je   .p9
        mov  dx,m_f9
.p9:    call PUTS

        ; ---- 6. the drone holds the gate open alone; SPK_NOTE's A4
        mov  ax,3000
        call SPK_DRONE
        call SPK_TICK
        in   al,61h
        and  al,3
        mov  dx,m_pa
        cmp  al,3
        je   .pa
        mov  dx,m_fa
.pa:    call PUTS
        call SPK_STOP
        mov  al,34
        call SPK_NOTE
        mov  dx,m_pb
        cmp  ax,2712
        jne  .fb
        mov  al,0
        call SPK_NOTE
        or   ax,ax
        jz   .pb
.fb:    mov  dx,m_fb
.pb:    call PUTS

        ; ---- 7. one effect at the real pace: by the BIOS tick
        mov  al,SPX_BOOM
        call SPK_FX
        call TICK
        mov  [last],ax
.r:     call TICK
        cmp  ax,[last]
        je   .r
        mov  [last],ax
        call SPK_TICK
        cmp  byte [spk_fx],0
        jne  .r
        call SPK_STOP
        mov  dx,m_pc
        call PUTS
        mov  dx,m_done
        call PUTS
        mov  ax,4C00h
        int  21h

; ============================================================================
;  By hand: the keys play, the BIOS tick drives SPK_TICK
HAND:   mov  dx,m_hand
        call PUTS
        call TICK
        mov  [last],ax
.lp:    call TICK
        cmp  ax,[last]
        je   .key
        mov  [last],ax
        call SPK_TICK
.key:   mov  ah,1
        int  16h
        jz   .lp
        xor  ah,ah
        int  16h
        cmp  al,27
        je   .q
        and  al,0DFh            ; letters to capitals (the digits go by scan code)
        cmp  ah,0Bh             ; the 0 key's scan code
        jne  .d
        mov  al,SPX_OVER
        call SPK_FX
        jmp  .lp
.d:     cmp  ah,2               ; scan codes 2..10 are the keys 1..9
        jb   .o
        cmp  ah,10
        ja   .o
        mov  al,ah
        dec  al                 ; key 1 (scan 2) is effect 1
        call SPK_FX
        jmp  .lp
.o:     cmp  al,'T'
        jne  .o2
        mov  si,tune1
        call SPK_TUNE
        jmp  .lp
.o2:    cmp  al,'D'
        jne  .o3
        mov  ax,[spk_dro]
        xor  ax,9000            ; 0 <-> 9000: the drone on and off
        call SPK_DRONE
        jmp  .lp
.o3:    cmp  al,'M'
        jne  .lp
        xor  byte [spk_mute],1
        jmp  .lp
.q:     call SPK_STOP
        mov  ax,3
        int  10h
        mov  ax,4C00h
        int  21h

; ============================================================================
;  the test's own helpers (plain DOS)
; ISAUTO - CF=0 if the command tail holds /AUTO
ISAUTO: mov  si,81h
        mov  cl,[80h]
        xor  ch,ch
.s:     cmp  cx,5
        jb   .no
        cmp  word [si],'/A'
        jne  .n
        cmp  word [si+2],'UT'
        jne  .n
        cmp  byte [si+4],'O'
        jne  .n
        clc
        ret
.n:     inc  si
        dec  cx                 ; one character fewer to look at
        jmp  .s
.no:    stc
        ret
; TICK - AX = the BIOS tick's low word
TICK:   push es
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:46Ch]
        pop  es
        ret
; PUTS - DX -> '$' text
PUTS:   push ax
        mov  ah,9
        int  21h
        pop  ax
        ret
; PUTN - AX in decimal
PUTN:   push ax
        push bx
        push cx
        push dx
        mov  bx,10
        xor  cx,cx
.d:     xor  dx,dx
        div  bx                 ; AX = AX / 10, DX = the digit (BX is 10, never 0)
        push dx
        inc  cx                 ; a digit more
        or   ax,ax
        jnz  .d
.p:     pop  dx
        add  dl,'0'             ; the digit as a character
        mov  ah,2
        int  21h
        loop .p
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

id      db 0
bad     db 0
gatebad db 0
regbad  db 0
last    dw 0
tune1   db 25,2, 29,2, 32,3, 0,1, 0FFh          ; C E G, a rest
tune2   db 37,1, 41,1, 0FEh                     ; round and round
m_head  db 'SSPK - K_SPK.INC, the PC speaker',13,10,'$'
m_fx    db '  effect $'
m_ticks db ' ran ticks: $'
m_ok    db ' ok',13,10,'$'
m_nok   db ' WRONG',13,10,'$'
m_tune  db '  tune over after ticks: $'
m_crlf  db 13,10,'$'
m_p1    db 'PASS S1 every effect ends after its own ticks',13,10,'$'
m_f1    db 'FAIL S1 an effect ran a wrong number of ticks',13,10,'$'
m_p2    db 'PASS S2 the gate opens while it plays, shuts after',13,10,'$'
m_f2    db 'FAIL S2 the gate (port 61h) was wrong',13,10,'$'
m_p3    db 'PASS S3 a smaller effect is not heard over a bigger',13,10,'$'
m_f3    db 'FAIL S3 a click evicted the explosion',13,10,'$'
m_p4    db 'PASS S4 a bigger effect takes the voice',13,10,'$'
m_f4    db 'FAIL S4 game over did not take the voice',13,10,'$'
m_p5    db 'PASS S5 mute: nothing starts, the gate stays shut',13,10,'$'
m_f5    db 'FAIL S5 mute let something sound',13,10,'$'
m_p6    db 'PASS S6 the tune ends on its 9th tick',13,10,'$'
m_f6    db 'FAIL S6 the tune ended at the wrong tick',13,10,'$'
m_p7    db 'PASS S7 a looping tune runs on',13,10,'$'
m_f7    db 'FAIL S7 the looping tune stopped by itself',13,10,'$'
m_p8    db 'PASS S8 SPK_STOP: the tune gone, the gate shut',13,10,'$'
m_f8    db 'FAIL S8 SPK_STOP left something',13,10,'$'
m_p9    db 'PASS S9 SPK_TICK keeps every register',13,10,'$'
m_f9    db 'FAIL S9 SPK_TICK changed a register',13,10,'$'
m_pa    db 'PASS S10 the drone sounds alone',13,10,'$'
m_fa    db 'FAIL S10 the drone did not open the gate',13,10,'$'
m_pb    db 'PASS S11 SPK_NOTE 34 is A4 = 2712, 0 a rest',13,10,'$'
m_fb    db 'FAIL S11 SPK_NOTE gave a wrong divisor',13,10,'$'
m_pc    db 'PASS S12 an explosion by the BIOS tick reached idle',13,10,'$'
m_done  db 'SSPK done',13,10,'$'
m_hand  db 'SSPK - keys 1..9,0 effects, T tune, D drone, M mute, Esc quits',13,10,'$'

        include '..\..\KIT\LIB\K_SPK.INC'
