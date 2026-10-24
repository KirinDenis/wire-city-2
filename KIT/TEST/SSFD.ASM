; SSFD.ASM - proves KIT\LIB\K_SFXDAT.INC: a recorded sound bank in the ring.
;
;   SSFD /AUTO  shrinks itself, SB_INIT (a card or not), loads OWL FLY III's
;               SFX.DAT, plays every sound in it at half loudness with
;               SB_HEAL running, a number past the bank, frees it; then a
;               file that is not there, and a play with no bank - every call
;               must return. PASS/FAIL lines.
;   SSFD        a person listens: 0..9 the sounds, Esc quits.
        org  100h
        include '..\..\ENGINE\E_8086.INC'

        cld
        mov  bx,1000h           ; the .COM keeps 64K, the rest back to DOS:
        mov  ah,4Ah             ;  the ring's 64K and the bank's come from it
        int  21h
        call ISAUTO
        jnc  AUTO
        jmp  HAND

; ============================================================================
AUTO:   mov  dx,m_head
        call PUTS
        call SB_INIT
        mov  dx,m_none
        jc   .say
        mov  dx,m_card
.say:   call PUTS
        mov  dx,bank
        call SFD_LOAD
        mov  dx,m_f1
        jc   .f1
        mov  dx,m_n
        call PUTS
        mov  ax,[sfd_n]
        call PUTN
        mov  dx,m_crlf
        call PUTS
        mov  dx,m_f1
        cmp  word [sfd_n],0
        je   .f1
        mov  dx,m_p1
.f1:    call PUTS
        ; ---- every sound once, a few ticks of SB_HEAL after each
        mov  word [id],0
.pl:    mov  al,byte [id]
        mov  ah,1               ; half loudness
        call SFD_PLAY
        call TICK
        mov  [t0],ax
.h:     call SB_HEAL
        call TICK
        sub  ax,[t0]
        cmp  ax,3               ; three ticks each
        jb   .h
        inc  word [id]          ; the next sound
        mov  ax,[id]
        cmp  ax,[sfd_n]
        jb   .pl
        mov  ax,(0 shl 8) + 250 ; a number past the bank: nothing
        call SFD_PLAY
        mov  dx,m_p2
        call PUTS
        call SFD_FREE
        call SFD_FREE           ; twice: harmless
        mov  dx,m_f3
        cmp  word [sfd_seg],0
        jne  .f3
        mov  dx,m_p3
.f3:    call PUTS
        ; ---- a file that is not there: CF=1, no memory kept
        mov  dx,nofile
        call SFD_LOAD
        mov  dx,m_f4
        jnc  .f4
        cmp  word [sfd_seg],0
        jne  .f4
        mov  ax,(0 shl 8) + 0   ; and a play with no bank returns
        call SFD_PLAY
        mov  dx,m_p4
.f4:    call PUTS
        call SB_DONE
        mov  dx,m_done
        call PUTS
        mov  ax,4C00h
        int  21h

; ============================================================================
HAND:   mov  dx,m_hand
        call PUTS
        call SB_INIT
        mov  dx,bank
        call SFD_LOAD
.lp:    call SB_HEAL
        mov  ah,1
        int  16h
        jz   .lp
        xor  ah,ah
        int  16h
        cmp  al,27
        je   .q
        cmp  al,'0'
        jb   .lp
        cmp  al,'9'
        ja   .lp
        sub  al,'0'             ; the key's number is the sound's
        xor  ah,ah              ; full loudness
        call SFD_PLAY
        jmp  .lp
.q:     call SFD_FREE
        call SB_DONE
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

t0      dw 0
id      dw 0
bank   db '..\..\GAMES\OWLFLY3\INSTALL\SFX.DAT',0
nofile  db 'NOFILE.DAT',0
m_head  db 'SSFD - K_SFXDAT.INC, a recorded sound bank',13,10,'$'
m_none  db '  no Sound Blaster: the bank loads, the plays stay silent',13,10,'$'
m_card  db '  a Sound Blaster answered: the sounds go into the ring',13,10,'$'
m_n     db '  OWL FLY III SFX.DAT loaded, sounds: $'
m_crlf  db 13,10,'$'
m_p1    db 'PASS S1 SFD_LOAD read the bank and its count',13,10,'$'
m_f1    db 'FAIL S1 SFD_LOAD could not read ..\..\GAMES\OWLFLY3\INSTALL\SFX.DAT',13,10,'$'
m_p2    db 'PASS S2 every sound mixed, one past the bank ignored',13,10,'$'
m_p3    db 'PASS S3 SFD_FREE twice: the 64K back',13,10,'$'
m_f3    db 'FAIL S3 SFD_FREE kept the bank',13,10,'$'
m_p4    db 'PASS S4 no file: CF=1, no memory kept, SFD_PLAY returns',13,10,'$'
m_f4    db 'FAIL S4 SFD_LOAD said yes to a file that is not there',13,10,'$'
m_done  db 'SSFD done',13,10,'$'
m_hand  db 'SSFD - 0..9 the recorded sounds, Esc quits',13,10,'$'

        include '..\..\KIT\LIB\K_SB.INC'
        include '..\..\KIT\LIB\K_SFXDAT.INC'
