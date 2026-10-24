; ============================================================================
;  R_UNDO.ASM - recipe: a step back - the undo ring of a grid game.
;
;  Guide TILES, "Mercy that keeps the game honest": Backspace (or U) takes
;  your own last step back, and the crate you pushed with it - 32 steps;
;  only while the cells are as you left them; the crate's points go back
;  by the same rule as any push; treats eaten stay eaten. Without it one
;  stuck crate restarts the level.
;
;        call PUSHMOVE           ; R_PUSH
;        jc   .no
;        call HREC               ; remember the step (AL from PUSHMOVE)
;        ...
;   Backspace (scan 0Eh) or U (16h):
;        call UNSTEP             ; CF=1: nothing to take back
;
;  copy: HREC, UNSTEP, HCLEAR and the words at the end.
;  define before: mancell (R_PUSH.ASM), SCORE (R_SCORE.ASM or your own)
;  needs: LIB\K_GRID.INC (GRD_STEP, grd_map, grd_ngood)
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:1773-1868 (HREC, UNSTEP: one man, the
;        per-player ring in his record made one ring; the gate and the
;        diamond taken out)
; ============================================================================
NHIST   = 32                    ; steps kept: a power of two (the ring's AND)

; ----------------------------------------------------------------------
;@ HREC       remember step AL (direction, +4 a crate went) in the undo ring
;  in:  AL = PUSHMOVE's answer
;  out: -  (past NHIST the oldest is forgotten)
; ----------------------------------------------------------------------
HREC:   push bx
        mov  bl,[hhead]
        xor  bh,bh
        mov  [hist+bx],al       ; into the ring at its head
        inc  bx                 ; the head on...
        and  bl,NHIST-1         ; ...round the ring
        mov  [hhead],bl
        cmp  byte [hcnt],NHIST
        jae  .r                 ; full: the oldest just went
        inc  byte [hcnt]        ; one more to take back
.r:     pop  bx
        ret

; ----------------------------------------------------------------------
;@ HCLEAR     forget every step (a new level)
;  in:  -
;  out: -
; ----------------------------------------------------------------------
HCLEAR: mov  word [hhead],0     ; hhead and hcnt
        ret

; ----------------------------------------------------------------------
;@ UNSTEP     take the last step back, and pull its crate after the man
;  in:  [mancell], the ring
;  out: CF=1 nothing taken back (none left, or the way is not as he left
;       it); CF=0 done: [mancell], the crate, grd_ngood, SCORE as a push
; ----------------------------------------------------------------------
UNSTEP: push ax
        push bx
        push cx
        push dx
        push di
        push bp
        cmp  byte [hcnt],0
        je   .no                ; nothing to take back
        mov  bl,[hhead]
        xor  bh,bh
        dec  bx                 ; his last step...
        and  bx,NHIST-1         ; ...round the ring
        push bx                 ; (the head goes back here if it works)
        mov  al,[hist+bx]
        mov  ch,al              ; CH = the step: direction, +4 a crate
        call GRD_STEP           ; DX = the step he made
        mov  di,[mancell]       ; DI = where he stands
        mov  bx,di
        sub  bx,dx              ; BX = where he came from
        test byte [grd_map+bx],GRD_WALL or GRD_BOX or GRD_MAN
        jnz  .no1               ; somebody's thing there now
        test byte [grd_map+bx],GRD_FLOOR
        jz   .no1
        test ch,4
        jz   .walk              ; he pushed nothing
        mov  bp,di
        add  bp,dx              ; BP = where his crate went
        test byte [grd_map+bp],GRD_BOX
        jz   .no1               ; gone on since
        and  byte [grd_map+bp],0FFh xor GRD_BOX   ; the crate back...
        or   byte [grd_map+di],GRD_BOX            ; ...where he stood
        test byte [grd_map+bp],GRD_GOAL
        jz   .off
        push bx
        mov  bx,bp
        mov  cx,-10             ; off a goal: -10
        call SCORE
        pop  bx
        dec  word [grd_ngood]   ; one fewer home
.off:   test byte [grd_map+di],GRD_GOAL
        jz   .walk
        push bx
        mov  bx,di
        mov  cx,10              ; onto one: +10
        call SCORE
        pop  bx
        inc  word [grd_ngood]   ; one more home
.walk:  and  byte [grd_map+di],0FFh xor GRD_MAN
        or   byte [grd_map+bx],GRD_MAN
        mov  [mancell],bx
        pop  ax                 ; the place of the step taken back
        mov  [hhead],al         ; is the ring's head now
        dec  byte [hcnt]        ; one fewer to take back
        clc
        jmp  .r
.no1:   pop  bx                 ; (the head stays)
.no:    stc
.r:     pop  bp
        pop  di
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

hhead   db 0                    ; the ring's next place
hcnt    db 0                    ; steps in it (must follow hhead: HCLEAR)
hist    rb NHIST                ; the steps: direction 0..3, +4 a crate went
