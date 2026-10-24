; ============================================================================
;  GPHYS.ASM - KIT test of LIB\K_PHYS.INC: the fraction carry, integration,
;  the bounce, falling to rest, drag, clamp, ease, sines, a pace along a
;  heading, turning the short way. Text only: PASS/FAIL lines through DOS.
;      GPHYS /AUTO   checks and quits;   GPHYS   checks, then waits for Esc
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

START:  cld
; ---- PHY_ADD: 10 + 1.5 + 1.5 - 0.5 = 12.5 ----
        mov  si,AXA
        mov  word [si+PHY_P],10
        mov  byte [si+PHY_F],0
        mov  ax,0180h           ; 1.5
        call PHY_ADD
        call PHY_ADD
        mov  ax,-80h            ; -0.5
        call PHY_ADD
        mov  dx,T_ADD
        cmp  word [si+PHY_P],12
        jne  .f1
        cmp  byte [si+PHY_F],80h
.f1:    call ZREP
; ---- PHY_INTEG: a = 40 for 10 ticks: v 400, p 2200/256 = 8 + 152/256 ----
        mov  si,AXA
        xor  ax,ax
        mov  [si+PHY_V],ax
        mov  [si+PHY_P],ax
        mov  [si+PHY_F],al
        mov  cx,10
        mov  ax,40
.i:     call PHY_INTEG
        loop .i
        mov  dx,T_INTEG
        cmp  word [si+PHY_V],400
        jne  .f2
        cmp  word [si+PHY_P],8
        jne  .f2
        cmp  byte [si+PHY_F],152
.f2:    call ZREP
; ---- PHY_INTEG saturates instead of wrapping ----
        mov  word [si+PHY_V],32700
        mov  ax,100
        call PHY_INTEG
        mov  dx,T_SAT
        cmp  word [si+PHY_V],7FFFh
        call ZREP
; ---- PHY_BOUNCE: v 1000 at the floor comes back -1000*205/256 = -801 ----
        mov  si,AXA
        mov  word [si+PHY_P],101
        mov  word [si+PHY_V],1000
        mov  bx,100
        mov  cx,205
        call PHY_BOUNCE
        mov  dx,T_BOUNCE
        jnc  .x3
        cmp  word [si+PHY_V],-801
        jne  .f3
        cmp  word [si+PHY_P],100
        jmp  .f3
.x3:    or   sp,sp              ; ZF=0: a fail
.f3:    call ZREP
; ---- PHY_FALL: dropped from 0 onto 100, it bounces and comes to rest ----
        mov  si,AXA
        xor  ax,ax
        mov  [si+PHY_V],ax
        mov  [si+PHY_P],ax
        mov  [si+PHY_F],al
        mov  word [bounces],0
        mov  word [steps],0
.fl:    mov  ax,40
        mov  bx,100
        mov  cx,205
        call PHY_FALL
        jnc  .fa
        cmp  word [si+PHY_V],0
        je   .rest              ; on the floor and still: done
        inc  word [bounces]     ; one more bounce
.fa:    inc  word [steps]       ; one more tick
        cmp  word [steps],3000
        jb   .fl
.rest:  mov  dx,T_FALL
        cmp  word [steps],3000
        jae  .x4                ; never came to rest
        cmp  word [bounces],3
        jb   .x4                ; it should bounce a few times first
        cmp  word [si+PHY_P],100
        jmp  .f4
.x4:    or   sp,sp
.f4:    call ZREP
; ---- PHY_DRAG: 1000 by 1/16 a step: 938 first, then down to 0 ----
        mov  ax,1000
        mov  cl,4
        call PHY_DRAG
        mov  dx,T_DRAG
        cmp  ax,938
        jne  .f5
        mov  bx,0               ; steps
.d1:    call PHY_DRAG
        inc  bx                 ; one more
        or   ax,ax
        jz   .d2
        cmp  bx,500
        jb   .d1
.d2:    or   ax,ax              ; stopped?
        jnz  .f5
        mov  ax,-1000
        mov  bx,0
.d3:    call PHY_DRAG
        inc  bx                 ; one more
        or   ax,ax
        jz   .f5
        cmp  bx,500
        jb   .d3
        or   sp,sp              ; never stopped: ZF=0, a fail
.f5:    call ZREP
; ---- PHY_CLAMPV / PHY_EASE ----
        mov  dx,T_CLAMP
        mov  bx,300
        mov  ax,500
        call PHY_CLAMPV
        cmp  ax,300
        jne  .f6
        mov  ax,-500
        call PHY_CLAMPV
        cmp  ax,-300
        jne  .f6
        mov  ax,100
        call PHY_CLAMPV
        cmp  ax,100
        jne  .f6
        mov  bx,4
        mov  ax,10
        call PHY_EASE
        cmp  ax,6
        jne  .f6
        mov  ax,-3
        call PHY_EASE
        cmp  ax,0
        jne  .f6
        mov  ax,-10
        call PHY_EASE
        cmp  ax,-6
.f6:    call ZREP
; ---- PHY_SIN / PHY_COS ----
        mov  dx,T_SIN
        mov  si,SINCASE
.s:     mov  al,[si]
        cmp  al,0FFh
        je   .sd                ; the table's end: all agreed
        cmp  byte [si+1],0
        jne  .sc
        call PHY_SIN
        jmp  .sk
.sc:    call PHY_COS
.sk:    cmp  ax,[si+2]
        jne  .f7
        add  si,4               ; the next case
        jmp  .s
.sd:    cmp  al,al              ; ZF=1
.f7:    call ZREP
; ---- PHY_STEPXZ: 2.0 east, north, south ----
        mov  cx,0200h           ; speed 2.0
        mov  al,64              ; east
        call PHY_STEPXZ
        cmp  ax,0200h
        jne  .x8
        cmp  dx,0
        jne  .x8
        mov  al,0               ; north
        call PHY_STEPXZ
        cmp  ax,0
        jne  .x8
        cmp  dx,0200h
        jne  .x8
        mov  al,128             ; south
        call PHY_STEPXZ
        cmp  dx,-0200h
        jmp  .f8
.x8:    or   sp,sp
.f8:    mov  dx,T_STEP          ; (PHY_STEPXZ took DX)
        call ZREP
; ---- PHY_TURNTO: the short way, clamped ----
        mov  dx,T_TURN
        mov  cl,3
        mov  ax,04FAh           ; now 250, wanted 4: +10 through 0, 3 at most
        call PHY_TURNTO
        cmp  al,253
        jne  .f9
        mov  cl,5
        mov  ax,200*256+10      ; now 10, wanted 200: -66, 5 at most
        call PHY_TURNTO
        cmp  al,5
        jne  .f9
        mov  ax,12*256+10       ; now 10, wanted 12: there at once
        call PHY_TURNTO
        cmp  al,12
.f9:    call ZREP
        jmp  DONE

; ---- the test's frame: ZREP, DONE ------------------------------------------
; ZREP - PASS if ZF=1, else FAIL, then the name at DX ('$' ended)
ZREP:   mov  bx,T_PASS
        jz   .p
        mov  bx,T_FAIL
        inc  byte [fails]       ; one more failed
.p:     push dx
        mov  dx,bx
        mov  ah,9
        int  21h
        pop  dx
        mov  ah,9
        int  21h
        mov  dx,T_CRLF
        mov  ah,9
        int  21h
        ret

DONE:   mov  dx,T_ALL
        cmp  byte [fails],0
        je   .p
        mov  dx,T_SOME
.p:     mov  ah,9
        int  21h
        call AUTO
        jnc  .q                 ; /AUTO: quit now
.k:     mov  ah,0
        int  16h                ; wait for a key
        cmp  ah,1
        jne  .k                 ; Esc only
.q:     mov  ax,3
        int  10h                ; text mode 3 (we never left it)
        mov  ax,4C00h
        int  21h

; AUTO - CF=0 if the command line holds /AUTO
AUTO:   mov  si,81h
        mov  cl,[80h]
        xor  ch,ch              ; CX = the tail's length
.a:     jcxz .no
        cmp  byte [si],'/'
        jne  .n
        cmp  byte [si+1],'A'
        je   .yes
.n:     inc  si                 ; the next letter
        dec  cx                 ; one fewer
        jmp  .a
.yes:   clc
        ret
.no:    stc
        ret

fails   db 0
bounces dw 0
steps   dw 0
AXA     rb PHY_AXIS
; angle, 0 sin / 1 cos, the answer
SINCASE db 0,0
        dw 0
        db 64,0
        dw 256
        db 128,0
        dw 0
        db 192,0
        dw -256
        db 32,0
        dw 181
        db 224,0
        dw -181
        db 0,1
        dw 256
        db 128,1
        dw -256
        db 0FFh
T_PASS  db 'PASS $'
T_FAIL  db 'FAIL $'
T_CRLF  db 13,10,'$'
T_ALL   db 'GPHYS: ALL PASS',13,10,'$'
T_SOME  db 'GPHYS: SOME FAILED',13,10,'$'
T_ADD   db 'GPHYS PHY_ADD 10 +1.5 +1.5 -0.5 = 12.5$'
T_INTEG db 'GPHYS PHY_INTEG a=40 x10: v 400, p 8+152/256$'
T_SAT   db 'GPHYS PHY_INTEG saturates at 32767$'
T_BOUNCE db 'GPHYS PHY_BOUNCE 1000 back as -801, pinned to the floor$'
T_FALL  db 'GPHYS PHY_FALL bounces, then rests on the floor$'
T_DRAG  db 'GPHYS PHY_DRAG 1000 -> 938, both signs reach 0$'
T_CLAMP db 'GPHYS PHY_CLAMPV and PHY_EASE$'
T_SIN   db 'GPHYS PHY_SIN / PHY_COS at 0 32 64 128 192 224$'
T_STEP  db 'GPHYS PHY_STEPXZ 2.0 east, north, south$'
T_TURN  db 'GPHYS PHY_TURNTO the short way, clamped$'

        include '..\..\KIT\LIB\K_PHYS.INC'
