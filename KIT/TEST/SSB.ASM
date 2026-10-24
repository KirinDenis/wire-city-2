; SSB.ASM - proves KIT\LIB\K_SB.INC: the Sound Blaster ring, both ways.
;
;   SSB /AUTO  shrinks itself (4Ah), SB_INIT and prints what it found; with
;              a card: every effect mixed once, then a second of SB_FX and
;              SB_HEAL by the BIOS tick, registers kept, SB_DONE twice, the
;              64K given back. Then the no-card paths: the player said no
;              sound ([sb_want]=0), and a port with nothing on it (280h) -
;              every call must return. PASS/FAIL lines.
;   SSB        a person listens: 0..9 and A..L the effects, Space the bed
;              (off / waves / and birds), + and - the volume, Esc quits.
        org  100h
        include '..\..\ENGINE\E_8086.INC'

        cld
        mov  bx,1000h           ; the .COM keeps 64K, the rest back to DOS
        mov  ah,4Ah             ;  (ES = CS at start) - SB_INIT's ring is
        int  21h                ;  taken from what this frees
        call ISAUTO
        jnc  AUTO
        jmp  HAND

; ============================================================================
AUTO:   mov  dx,m_head
        call PUTS
        call SB_INIT
        jnc  .card
        mov  dx,m_none
        call PUTS
        jmp  .nocard
.card:  mov  dx,m_card
        call PUTS
        mov  ax,[sb_port]
        call PUTH
        mov  dx,m_irq
        call PUTS
        mov  al,[sb_irq]
        xor  ah,ah
        call PUTN
        mov  dx,m_dma
        call PUTS
        mov  al,[sb_dma]
        xor  ah,ah
        call PUTN
        mov  dx,m_seg
        call PUTS
        mov  ax,[sb_seg]
        call PUTH
        mov  dx,m_crlf
        call PUTS
        mov  dx,m_p1
        mov  ax,[sb_seg]
        test ax,0FFFh
        jz   .al                ; on a 64K page
        and  ax,0FFFh
        cmp  ax,800h
        jbe  .al                ; or 32K before its end
        mov  dx,m_f1
.al:    call PUTS
        ; ---- every effect once, timed
        mov  al,2
        call SB_BED
        call TICK
        mov  [t0],ax
        xor  al,al
.fx:    call SB_FX
        call SB_HEAL
        inc  al                 ; the next effect
        cmp  al,SBX_N
        jb   .fx
        call TICK
        sub  ax,[t0]            ; ticks it took
        mov  dx,m_fxt
        call PUTS
        call PUTN
        mov  dx,m_crlf
        call PUTS
        mov  dx,m_p2
        call PUTS
        ; ---- a second: an effect each tick, SB_HEAL flat out, regs kept
        call SB_POS
        mov  [pos0],bx
        call TICK
        mov  [last],ax
        mov  [t0],ax
        mov  byte [id],0
.lp:    mov  ax,1111h           ; every register a known value
        mov  bx,2222h
        mov  cx,3333h
        mov  dx,4444h
        mov  si,5555h
        mov  di,6666h
        mov  bp,7777h
        call SB_HEAL
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
.rk:    inc  word [nheal]       ; one more heal
        call SB_POS
        cmp  bx,[pos0]
        je   .t
        mov  byte [moved],1     ; the DMA plays: its position moves
.t:     call TICK
        cmp  ax,[last]
        je   .lp
        mov  [last],ax
        sub  ax,[t0]
        cmp  ax,18              ; a second gone?
        jae  .sec
        mov  al,[id]
        mov  ah,8               ; half loudness
        call SB_FXV
        inc  byte [id]          ; the next one
        cmp  byte [id],SBX_N
        jb   .lp
        mov  byte [id],0
        jmp  .lp
.sec:   mov  dx,m_heals
        call PUTS
        mov  ax,[nheal]
        call PUTN
        mov  dx,m_mov
        cmp  byte [moved],0
        jne  .mv
        mov  dx,m_still
.mv:    call PUTS
        mov  dx,m_p3
        call PUTS
        mov  dx,m_p4
        cmp  byte [regbad],0
        je   .p4
        mov  dx,m_f4
.p4:    call PUTS
        call SB_DONE
        call SB_DONE            ; twice: harmless
        mov  dx,m_p5
        cmp  byte [sb_ok],0
        jne  .f5
        cmp  word [sb_mem],0
        jne  .f5
        mov  ah,48h             ; the 64K is DOS's again: take and give it
        mov  bx,1000h
        int  21h
        jc   .f5
        mov  es,ax
        mov  ah,49h
        int  21h
        push cs
        pop  es
        jmp  .p5
.f5:    mov  dx,m_f5
.p5:    call PUTS

        ; ---- the player chose no sound: not one port, every call returns
.nocard:mov  byte [sb_want],0
        call SB_INIT
        mov  dx,m_f6
        jnc  .f6
        call ALLCALL
        mov  dx,m_p6
.f6:    call PUTS
        ; ---- a port with nothing on it, BLASTER ignored
        mov  byte [sb_want],1
        mov  byte [sb_env],0
        mov  word [sb_port],280h
        call SB_INIT
        mov  dx,m_f7
        jnc  .f7
        cmp  word [sb_mem],0
        jne  .f7                ; no card: no memory taken either
        call ALLCALL
        mov  dx,m_p7
.f7:    call PUTS
        ; ---- the BLASTER parse, on an environment of our own
        mov  ax,[2Ch]
        push ax
        mov  ax,fakeenv
        mov  cl,4
        shr  ax,cl              ; its paragraph inside the .COM...
        mov  bx,cs
        add  ax,bx              ; ...as a segment
        mov  [2Ch],ax
        call SB_ENV
        pop  ax
        mov  [2Ch],ax           ; the real one back
        mov  dx,m_f8
        cmp  word [sb_port],240h
        jne  .f8
        cmp  byte [sb_irq],10
        jne  .f8
        cmp  byte [sb_dma],3
        jne  .f8
        mov  dx,m_p8
.f8:    call PUTS
        mov  dx,m_done
        call PUTS
        mov  ax,4C00h
        int  21h

        align 16
fakeenv db 'PATH=Z:\',0,'BLASTER=a240 i10 d3 h5 t6',0,0

; ALLCALL - every SB_ call once, with sb_ok = 0
ALLCALL:mov  al,SBX_BOOM
        call SB_FX
        mov  ax,(16 shl 8) + SBX_WIN
        call SB_FXV
        mov  si,zap
        mov  ah,16
        call SB_PLAY
        mov  al,1
        call SB_BED
        mov  al,10
        call SB_VOL
        call SB_HEAL
        call SB_DONE
        mov  al,16
        call SB_VOL
        ret

; ============================================================================
;  By hand: the keys play, SB_HEAL runs flat out
HAND:   mov  dx,m_hand
        call PUTS
        call SB_INIT
        mov  dx,m_none
        jc   .say
        mov  dx,m_card
.say:   call PUTS
        mov  dx,m_crlf
        call PUTS
        mov  al,1
        call SB_BED
.lp:    call SB_HEAL
        mov  ah,1
        int  16h
        jz   .lp
        xor  ah,ah
        int  16h
        cmp  al,27
        je   .q
        cmp  al,' '
        jne  .v
        mov  al,[sb_bed]
        inc  al                 ; the next bed: off, waves, and birds
        cmp  al,3
        jb   .b
        xor  al,al
.b:     call SB_BED
        jmp  .lp
.v:     cmp  al,'+'
        jne  .v2
        mov  al,[sb_vol]
        inc  al                 ; louder (SB_VOL stops at 16)
        call SB_VOL
        jmp  .lp
.v2:    cmp  al,'-'
        jne  .d
        mov  al,[sb_vol]
        or   al,al
        jz   .lp
        dec  al                 ; quieter
        call SB_VOL
        jmp  .lp
.d:     cmp  al,'0'
        jb   .lp
        cmp  al,'9'
        ja   .l
        sub  al,'0'             ; 0..9: effects 0..9
        call SB_FX
        jmp  .lp
.l:     and  al,0DFh            ; a capital
        cmp  al,'A'
        jb   .lp
        sub  al,'A'-10          ; A..L: effects 10..21
        call SB_FX              ; (past the table: SB_FX ignores it)
        jmp  .lp
.q:     call SB_DONE
        mov  ax,3
        int  10h
        mov  ax,4C00h
        int  21h

; ============================================================================
;  the test's own helpers (plain DOS)
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
TICK:   push es
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:46Ch]
        pop  es
        ret
PUTS:   push ax
        mov  ah,9
        int  21h
        pop  ax
        ret
PUTN:   push ax
        push bx
        push cx
        push dx
        mov  bx,10
        xor  cx,cx
.d:     xor  dx,dx
        div  bx                 ; AX / 10, DX the digit (BX is 10, never 0)
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
; PUTH - AX in four hex digits
PUTH:   push ax
        push bx
        push cx
        push dx
        mov  bx,ax
        mov  cx,4
.h:     push cx
        mov  cl,4
        rol  bx,cl              ; the top digit to the bottom
        pop  cx
        mov  dl,bl
        and  dl,15
        add  dl,'0'             ; 0..9
        cmp  dl,'9'
        jbe  .o
        add  dl,7               ; A..F
.o:     mov  ah,2
        int  21h
        loop .h
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

id      db 0
regbad  db 0
moved   db 0
nheal   dw 0
pos0    dw 0
t0      dw 0
last    dw 0
m_head  db 'SSB - K_SB.INC, the Sound Blaster ring',13,10,'$'
m_none  db '  no Sound Blaster answered: silent, the program runs on',13,10,'$'
m_card  db '  a Sound Blaster at $'
m_irq   db 'h  IRQ $'
m_dma   db '  DMA $'
m_seg   db '  ring at segment $'
m_crlf  db 13,10,'$'
m_fxt   db '  every effect mixed once, ticks: $'
m_heals db '  a second of SB_HEAL, calls: $'
m_mov   db '  (the DMA position moved)',13,10,'$'
m_still db '  (the DMA position stood still - a silent mixer)',13,10,'$'
m_p1    db 'PASS S1 the ring crosses no 64K page',13,10,'$'
m_f1    db 'FAIL S1 the ring would cross a 64K page',13,10,'$'
m_p2    db 'PASS S2 every effect mixed into the ring and returned',13,10,'$'
m_p3    db 'PASS S3 a second of SB_FX and SB_HEAL, no hang',13,10,'$'
m_p4    db 'PASS S4 SB_HEAL keeps every register',13,10,'$'
m_f4    db 'FAIL S4 SB_HEAL changed a register',13,10,'$'
m_p5    db 'PASS S5 SB_DONE twice: silent, the 64K back with DOS',13,10,'$'
m_f5    db 'FAIL S5 SB_DONE left the card on or the memory taken',13,10,'$'
m_p6    db 'PASS S6 no sound chosen: SB_INIT CF=1, every call returns',13,10,'$'
m_f6    db 'FAIL S6 SB_INIT played with sb_want = 0',13,10,'$'
m_p7    db 'PASS S7 no card at 280h: SB_INIT CF=1, no memory, calls return',13,10,'$'
m_f7    db 'FAIL S7 SB_INIT found a card at 280h or kept memory',13,10,'$'
m_p8    db 'PASS S8 BLASTER=a240 i10 d3: port 240h, IRQ 10, DMA 3',13,10,'$'
m_f8    db 'FAIL S8 the BLASTER parse got it wrong',13,10,'$'
m_done  db 'SSB done',13,10,'$'
m_hand  db 'SSB - 0..9 A..L effects, Space the bed, + - volume, Esc quits',13,10,'$'

        include '..\..\KIT\LIB\K_SB.INC'
; a program's own effect, as data - after the include: SB_TONE is its macro
zap:    SB_TONE 1,0,1500,1200,300,40,0  ; a falling zap
        db 0FFh
