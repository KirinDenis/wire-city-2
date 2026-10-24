; SREC.ASM - proves KIT\REC\R_SOUND.ASM: sound from state difference,
;            loudness by distance, the all / effects / off switch.
;
;   SREC /AUTO  runs the same checks twice: once on the Sound Blaster (if
;               one answers) and once on the speaker alone ([sb_want]=0).
;               The recipe's sndcnt counts the sounds it asked for.
;   SREC        the same, then waits for Esc.
        org  100h
        include '..\..\ENGINE\E_8086.INC'

        cld
        mov  bx,1000h           ; the .COM keeps 64K, the ring's comes from
        mov  ah,4Ah             ;  the rest
        int  21h
        mov  dx,m_head
        call PUTS
        call SB_INIT
        mov  dx,m_none
        jc   .say
        mov  dx,m_card
.say:   call PUTS
        call CHECKS             ; on the card, if there is one
        call SB_DONE
        mov  byte [sb_want],0   ; and on the speaker alone
        call SB_INIT
        mov  dx,m_spk
        call PUTS
        call CHECKS
        call SPK_STOP
        call SB_DONE
        mov  dx,m_done
        call PUTS
        call ISAUTO
        jnc  .q
        mov  dx,m_esc
        call PUTS
.k:     xor  ah,ah
        int  16h
        cmp  al,27
        jne  .k
.q:     mov  ax,4C00h
        int  21h

; CHECKS - the recipe through its paces; PASS/FAIL lines
CHECKS: mov  word [sndcnt],0
        mov  byte [sndmode],2
        mov  word [s_level],0FFFFh
        mov  word [level],1
        mov  word [score],0
        mov  byte [lives],3
        call SNDDIFF            ; a new level: copied, not heard
        call FRAME
        mov  ax,0
        mov  dx,m_f1
        cmp  [sndcnt],ax
        jne  .f1
        add  word [score],10    ; a coin
        call SNDDIFF
        call FRAME
        call SNDDIFF            ; nothing changed: nothing heard
        mov  dx,m_f1
        cmp  word [sndcnt],1
        jne  .f1
        dec  byte [lives]       ; a hit
        call SNDDIFF
        call FRAME
        mov  byte [lives],0     ; the last one: game over
        call SNDDIFF
        mov  dx,m_f1
        cmp  word [sndcnt],3
        jne  .f1
        inc  word [level]       ; a new level, the score with it: quiet
        add  word [score],500
        call SNDDIFF
        mov  dx,m_f1
        cmp  word [sndcnt],3
        jne  .f1
        mov  dx,m_p1
.f1:    call PUTS
        ; ---- near is heard, far is not
        mov  word [camx],1000
        mov  word [camy],1000
        mov  al,SN_BOOM
        mov  dx,1100
        mov  bx,900
        call SNDNEAR
        call FRAME
        mov  al,SN_BOOM
        mov  dx,31000
        mov  bx,-20000
        call SNDNEAR
        mov  dx,m_p2
        cmp  word [sndcnt],4
        je   .p2
        mov  dx,m_f2
.p2:    call PUTS
        ; ---- the switch: all -> effects -> off -> all
        mov  dx,m_f3
        call SNDTOG             ; effects only
        cmp  byte [sb_bed],0
        jne  .f3
        cmp  byte [spk_mute],0
        jne  .f3
        call SNDTOG             ; off
        cmp  byte [spk_mute],1
        jne  .f3
        mov  ax,(16 shl 8) + SN_COIN
        call SNDFX              ; not asked for: silence
        cmp  word [sndcnt],4
        jne  .f3
        call SNDTOG             ; all again
        cmp  byte [sndmode],2
        jne  .f3
        cmp  byte [spk_mute],0
        jne  .f3
        mov  al,[sndbed]
        cmp  [sb_bed],al
        jne  .f3
        mov  dx,m_p3
.f3:    call PUTS
        ret

; FRAME - a few ticks of the main loop's sound work
FRAME:  push ax
        push cx
        mov  cx,3
.f:     call TICK
        mov  [last],ax
.w:     call SB_HEAL
        call TICK
        cmp  ax,[last]
        je   .w
        call SPK_TICK
        loop .f
        pop  cx
        pop  ax
        ret

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

; ---- the game's own state, as the recipe wants it named
score   dw 0
lives   db 3
level   dw 1
camx    dw 0
camy    dw 0
last    dw 0
m_head  db 'SREC - KIT\REC\R_SOUND.ASM',13,10,'$'
m_none  db '  no Sound Blaster: the speaker first',13,10,'$'
m_card  db '  on the Sound Blaster:',13,10,'$'
m_spk   db '  on the PC speaker alone:',13,10,'$'
m_p1    db 'PASS S1 SNDDIFF: coin, hit, game over heard; a new level quiet',13,10,'$'
m_f1    db 'FAIL S1 SNDDIFF heard the wrong things',13,10,'$'
m_p2    db 'PASS S2 SNDNEAR: near heard, far not',13,10,'$'
m_f2    db 'FAIL S2 SNDNEAR got the distance wrong',13,10,'$'
m_p3    db 'PASS S3 SNDTOG: all, effects only, off, all again',13,10,'$'
m_f3    db 'FAIL S3 SNDTOG left the wrong state',13,10,'$'
m_done  db 'SREC done',13,10,'$'
m_esc   db 'Esc quits',13,10,'$'

        include '..\..\KIT\LIB\K_SB.INC'
        include '..\..\KIT\LIB\K_SPK.INC'
        include '..\..\KIT\REC\R_SOUND.ASM'
