; ============================================================================
;  K_TIME.INC - KIT: time by the BIOS tick (0040:006Ch, 18.2 a second).
;
;  Never time by CPU speed: the same program meets a 4.77 MHz XT and an
;  emulator at a hundred million cycles. The game loop every kit template
;  uses - physics in fixed steps, as many as the ticks that passed, capped:
;        call TIM_STEPS          ; once before the loop: starts the count
;  .frame:
;        call TIM_STEPS          ; AX = ticks since the last frame, 0..max
;        mov  cx,ax
;        jcxz .draw              ; no tick yet: just draw again
;  .step: call MOVE              ; one physics step = one tick
;        loop .step
;  .draw: ...draw, VGA_SHOW...
;  Guide topic TIME.
; ============================================================================

; ----------------------------------------------------------------------
;@ TIM_TICK   AX = the BIOS tick now (low word, 18.2 a second)
;  in:  -
;  out: AX = the tick
;  needs: -
;  from: EXAMPLES\NETSQ.ASM:257-262 (tick)
; ----------------------------------------------------------------------
if used TIM_TICK
TIM_TICK:
        push es
        xor  ax,ax
        mov  es,ax              ; ES = 0: 0000:046C is 0040:006C
        mov  ax,[es:046Ch]      ; AX = the tick's low word - one MOV, atomic
        pop  es
        ret
end if

; ----------------------------------------------------------------------
;@ TIM_STEPS  AX = ticks since the last call, capped at [tim_max] (fixed step)
;  in:  [tim_max] = the cap, default 4 (a slow frame does at most 4 steps)
;  out: AX = the number of physics steps to run now (0..tim_max)
;  needs: call it once before the loop (that first answer is meaningless)
;  from: GAMES\TRAINER\SRC\FIELD.ASM:100-123 (the frame), compare made
;        unsigned: at midnight the tick restarts from 0 and FIELD's signed
;        compare would hand the loop a negative count (65000 steps)
; ----------------------------------------------------------------------
if used TIM_STEPS
TIM_STEPS:
        push bx
        call TIM_TICK           ; AX = now
        mov  bx,ax              ; BX = now, kept
        sub  ax,[tim_last]      ; AX = now - last: the ticks gone by
        mov  [tim_last],bx      ; last = now
        cmp  ax,[tim_max]       ; more than the cap? (unsigned: a wrap is huge)
        jbe  .ok
        mov  ax,[tim_max]       ; AX = the cap
.ok:    pop  bx
        ret
tim_last dw 0                   ; the tick of the last call
tim_max  dw 4                   ; the most steps one frame may run
end if

; ----------------------------------------------------------------------
;@ TIM_WAIT   wait AX ticks (18 = about a second), giving the time back
;  in:  AX = ticks to wait (0 = return at once)
;  out: -
;  needs: interrupts on (the tick IS an interrupt)
;  from: new (the tick read of NETSQ + TIM_YIELD)
; ----------------------------------------------------------------------
if used TIM_WAIT
TIM_WAIT:
        push ax
        push bx
        push cx
        mov  cx,ax              ; CX = how many
        call TIM_TICK
        mov  bx,ax              ; BX = the start
.w:     call TIM_TICK
        sub  ax,bx              ; AX = ticks gone by (a wrap still counts up)
        cmp  ax,cx              ; enough?
        jae  .done
        call TIM_YIELD          ; sleep to the next tick
        jmp  .w
.done:  pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ TIM_YIELD  give the time back to Windows/DOSBox until the next tick or key
;  in:  -
;  out: - (interrupts left ON)
;  needs: use in idle loops (menus, waits), not inside a running frame:
;         it may sleep up to one tick (55 ms)
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:181-185
; ----------------------------------------------------------------------
if used TIM_YIELD
TIM_YIELD:
        push ax
        mov  ax,1680h           ; INT 2Fh 1680h: "idle" to a Windows DOS box
        int  2Fh
        sti                     ; HLT with interrupts off would never wake
        hlt                     ; sleep to the next interrupt: tick or key
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ TIM_FPS    count a frame; AX = frames drawn in the last second
;  in:  - (call once a frame)
;  out: AX = frames a second, measured (also kept in [tim_fps])
;  needs: -
;  from: LESSONS\L20\FLY.ASM:298-312
; ----------------------------------------------------------------------
if used TIM_FPS
TIM_FPS:
        push bx
        inc  word [tim_fpsn]    ; one more frame this second
        call TIM_TICK           ; AX = now
        mov  bx,ax              ; BX = now (kept: the start may take it)
        sub  ax,[tim_fpst]      ; AX = ticks since the second began
        cmp  ax,18              ; a second gone by? (18.2 ticks)
        jb   .same
        mov  [tim_fpst],bx      ; a new second starts now
        mov  ax,[tim_fpsn]
        mov  [tim_fps],ax       ; the number to show
        mov  word [tim_fpsn],0  ; count again from nothing
.same:  mov  ax,[tim_fps]       ; AX = the last full second's count
        pop  bx
        ret
tim_fpsn dw 0                   ; frames counted this second
tim_fpst dw 0                   ; the tick the second began at
tim_fps  dw 0                   ; frames in the last full second
end if

; ----------------------------------------------------------------------
;@ TIM_SECS   AX ticks -> AX whole seconds (ticks * 5 / 91)
;  in:  AX = ticks (any, 0..65535)
;  out: AX = seconds (0..3600)
;  needs: -
;  from: new (18.2065 ticks a second = 91/5, to 0.04 per cent)
; ----------------------------------------------------------------------
if used TIM_SECS
TIM_SECS:
        push bx
        push dx
        mov  bx,5
        mul  bx                 ; DX:AX = ticks * 5 (at most 327675)
        mov  bx,91              ; 91 is never 0, and the quotient is at
        div  bx                 ;  most 3600: AX = ticks * 5 / 91
        pop  dx
        pop  bx
        ret
end if
