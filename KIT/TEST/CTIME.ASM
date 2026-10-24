; CTIME.ASM - test of KIT\LIB\K_TIME.INC: the tick, waits, fixed steps and
; their cap (and the midnight wrap), FPS, seconds. About 4 s with /AUTO.
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

; WITHIN lo, hi, 'name' - AX must be lo..hi (unsigned): 0 printed if so
macro WITHIN lo, hi, text
{
        local ..no, ..yes
        mov  [val],ax
        cmp  ax,lo
        jb ..no
        cmp  ax,hi
        ja ..no
        xor  ax,ax
        jmp ..yes
..no:     mov  ax,[val]
        or   ax,8000h           ; never 0: a FAIL, showing the value
..yes:    EXPECT 0, text
}

start:  call GETAUTO
        call TIM_TICK
        mov  [t0],ax
        mov  ax,9
        call TIM_WAIT           ; half a second
        call TIM_TICK
        sub  ax,[t0]            ; AX = ticks gone by
        WITHIN 9, 10, 'TIM_WAIT 9 takes 9..10 ticks'
        call TIM_TICK
        mov  [t0],ax
        xor  ax,ax
        call TIM_WAIT           ; 0: at once
        call TIM_TICK
        sub  ax,[t0]
        WITHIN 0, 1, 'TIM_WAIT 0 returns at once'
        ; fixed steps
        call TIM_STEPS          ; start the count
        mov  ax,2
        call TIM_WAIT
        call TIM_STEPS
        WITHIN 2, 3, 'TIM_STEPS after 2 ticks = 2..3'
        call TIM_STEPS
        WITHIN 0, 1, 'TIM_STEPS straight again = 0..1'
        sub  word [tim_last],100   ; as if a frame took 100 ticks
        call TIM_STEPS
        EXPECT 4, 'TIM_STEPS capped at tim_max = 4'
        add  word [tim_last],100   ; as if the clock went BACK (midnight)
        call TIM_STEPS
        EXPECT 4, 'TIM_STEPS after a backward wrap = 4, not negative'
        mov  word [tim_max],1
        sub  word [tim_last],50
        call TIM_STEPS
        mov  word [tim_max],4
        EXPECT 1, 'TIM_STEPS cap follows tim_max'
        ; seconds
        mov  ax,182
        call TIM_SECS
        EXPECT 10, 'TIM_SECS 182 ticks = 10 s'
        mov  ax,91
        call TIM_SECS
        EXPECT 5, 'TIM_SECS 91 ticks = 5 s'
        mov  ax,18
        call TIM_SECS
        EXPECT 0, 'TIM_SECS 18 ticks = 0 s (0.99)'
        mov  ax,65535
        call TIM_SECS
        EXPECT 3600, 'TIM_SECS 65535 ticks = 3600 s'
        ; FPS: a frame a tick for 40 ticks - about 18 a second
        mov  cx,40
.f:     call TIM_FPS
        mov  ax,1
        call TIM_WAIT
        loop .f
        call TIM_FPS
        WITHIN 15, 20, 'TIM_FPS at a frame a tick = 15..20'
        call TIM_YIELD
        xor  ax,ax
        EXPECT 0, 'TIM_YIELD comes back'
        KEEPS TIM_WAIT, 1, 'TIM_WAIT keeps registers'
        KEEPS TIM_YIELD, 1234h, 'TIM_YIELD keeps registers'
        mov  bx,0FA0h
        mov  si,4444h
        call TIM_STEPS
        call TIM_TICK
        call TIM_FPS
        mov  ax,10
        call TIM_SECS
        cmp  bx,0FA0h
        mov  ax,1
        jne  .k
        cmp  si,4444h
        jne  .k
        xor  ax,ax
.k:     EXPECT 0, 'TIM_STEPS/TICK/FPS/SECS keep BX, SI'
        jmp  FINISH

t0      dw 0
val     dw 0
kax     dw 0

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

        include '..\..\KIT\LIB\K_TIME.INC'
