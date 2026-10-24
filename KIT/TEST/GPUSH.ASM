; ============================================================================
;  GPUSH.ASM - KIT test of the Sokoban recipes REC\R_PUSH, R_UNDO, R_DEAD,
;  R_SCORE on LIB\K_GRID: a push onto a goal and off it, two steps back,
;  an empty history, a blocked push, a wall, the crate in the corner that
;  loses the level, the pop-up, a treat's worth, asking twice.
;      GPUSH /AUTO   checks and quits;   GPUSH   checks, then waits for Esc
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

START:  cld
        mov  si,LEVEL
        xor  di,di
        call GRD_LOAD
        mov  bx,[grd_start]
        mov  [mancell],bx
        mov  ax,GRD_WALL*256 + GRD_FLOOR
        call GRD_FLOOD
        mov  si,QUEUE
        call LIVEGEN
; ---- R_DEAD: the crate in the corner (1,3) is lost, the other is not ----
        call STUCK
        mov  dx,T_STUCK
        jnc  .x0
        cmp  bx,3*32+1
        jne  .f0
        mov  bx,1*32+2          ; the crate beside the goal: still live
        call LIVEAT
        jz   .x0
        cmp  al,al
        jmp  .f0
.x0:    or   sp,sp              ; ZF=0: a fail
.f0:    call ZREP
; ---- R_PUSH: right, the crate onto the goal: +10, one home ----
        mov  al,1
        call PUSHMOVE
        mov  dx,T_PUSH1
        jc   .x1
        cmp  al,1+4
        jne  .f1
        cmp  word [mancell],1*32+2
        jne  .f1
        cmp  word [grd_ngood],1
        jne  .f1
        cmp  word [score],10
        jne  .f1
        test byte [grd_map+1*32+3],GRD_BOX
        jz   .x1
        cmp  word [popval],10   ; the pop-up: +10 over the man
        jne  .f1
        cmp  word [popcell],1*32+2
        jne  .f1
        cmp  word [popclk],POPT
        jmp  .f1
.x1:    or   sp,sp
.f1:    call ZREP
        call HREC
; ---- R_PUSH: right again, off the goal: back to 0 ----
        mov  al,1
        call PUSHMOVE
        mov  dx,T_PUSH2
        jc   .x2
        cmp  word [grd_ngood],0
        jne  .f2
        cmp  word [score],0
        jne  .f2
        test byte [grd_map+1*32+4],GRD_BOX
        jz   .x2
        cmp  al,al
        jmp  .f2
.x2:    or   sp,sp
.f2:    call ZREP
        call HREC
; ---- R_UNDO: one step back: the crate home again, +10 ----
        call UNSTEP
        mov  dx,T_UNDO1
        jc   .x3
        cmp  word [score],10
        jne  .f3
        cmp  word [grd_ngood],1
        jne  .f3
        cmp  word [mancell],1*32+2
        jne  .f3
        test byte [grd_map+1*32+4],GRD_BOX
        jnz  .x3
        test byte [grd_map+1*32+3],GRD_BOX
        jz   .x3
        cmp  al,al
        jmp  .f3
.x3:    or   sp,sp
.f3:    call ZREP
; ---- R_UNDO: another: all as the level began ----
        call UNSTEP
        mov  dx,T_UNDO2
        jc   .x4
        cmp  word [score],0
        jne  .f4
        cmp  word [grd_ngood],0
        jne  .f4
        cmp  word [mancell],1*32+1
        jne  .f4
        cmp  byte [grd_map+1*32+2],GRD_BOX or GRD_FLOOR
        jne  .f4
        cmp  byte [grd_map+1*32+1],GRD_MAN or GRD_FLOOR
        jmp  .f4
.x4:    or   sp,sp
.f4:    call ZREP
; ---- R_UNDO: nothing left to take back ----
        call UNSTEP
        mov  dx,T_UNDO3
        mov  al,0
        adc  al,0               ; AL = 1: refused, as it should be
        cmp  al,1
        call ZREP
; ---- R_PUSH: down, then down against the crate in the corner: refused ----
        mov  al,2
        call PUSHMOVE
        mov  dx,T_BLOCK
        jc   .x5
        cmp  word [mancell],2*32+1
        jne  .f5
        mov  al,2
        call PUSHMOVE           ; the crate below has a wall behind it
        jnc  .x5
        cmp  word [mancell],2*32+1
        jne  .f5
        test byte [grd_map+3*32+1],GRD_BOX
        jz   .x5
        mov  al,3
        call PUSHMOVE           ; and to the left is a wall
        jnc  .x5
        cmp  word [mancell],2*32+1
        jmp  .f5
.x5:    or   sp,sp
.f5:    call ZREP
; ---- R_SCORE: CELLVAL 1..3 and the same twice; ASK2 asks, then does ----
        mov  dx,T_VAL
        mov  bx,0
.v:     mov  ax,7               ; level 7
        call CELLVAL
        cmp  ax,1
        jb   .x6
        cmp  ax,3
        ja   .x6
        mov  cx,ax
        mov  ax,7
        call CELLVAL
        cmp  ax,cx
        jne  .f6
        inc  bx                 ; the next cell
        cmp  bx,GRD_CELLS
        jb   .v
        mov  dx,100             ; "the tick"
        mov  al,1
        call ASK2               ; the first R: asks
        jnc  .x6
        mov  al,1
        call ASK2               ; the second: does it
        jc   .x6
        mov  al,1
        call ASK2               ; asks again
        mov  dx,100+ASKT        ; ASKT ticks later
        call ASKAGE             ; forgotten
        jnc  .x6
        cmp  byte [ask],0
        jmp  .f6
.x6:    or   sp,sp
.f6:    mov  dx,T_VAL
        call ZREP
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
T_PASS  db 'PASS $'
T_FAIL  db 'FAIL $'
T_CRLF  db 13,10,'$'
T_ALL   db 'GPUSH: ALL PASS',13,10,'$'
T_SOME  db 'GPUSH: SOME FAILED',13,10,'$'
T_STUCK db 'GPUSH R_DEAD: the corner crate is STUCK, the other live$'
T_PUSH1 db 'GPUSH R_PUSH onto the goal: +10, one home, the pop-up$'
T_PUSH2 db 'GPUSH R_PUSH off the goal: back to 0$'
T_UNDO1 db 'GPUSH R_UNDO one step back: home again, +10$'
T_UNDO2 db 'GPUSH R_UNDO two steps back: as it began$'
T_UNDO3 db 'GPUSH R_UNDO nothing left: refused$'
T_BLOCK db 'GPUSH R_PUSH a crate against a wall, a wall: refused$'
T_VAL   db 'GPUSH R_SCORE CELLVAL 1..3 and stable, ASK2, ASKAGE$'

LEVEL   db 7,5
        db '#######'
        db '#@$.  #'
        db '#     #'
        db '#$    #'
        db '#######'

        include '..\..\KIT\LIB\K_GRID.INC'
        include '..\..\KIT\REC\R_SCORE.ASM'
        include '..\..\KIT\REC\R_PUSH.ASM'
        include '..\..\KIT\REC\R_UNDO.ASM'
        include '..\..\KIT\REC\R_DEAD.ASM'
QUEUE   rw GRD_CELLS
