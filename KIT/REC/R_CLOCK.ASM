; R_CLOCK.ASM - ONE scene clock: nothing in step, nothing blinks
; ============================================================================
;  Recipe: copy into your program after its way out (or include it there).
;  Every living thing of a scene runs on these three numbers, from the BIOS
;  tick (18.2 a second), never from CPU speed:
;    now    the tick itself
;    fstep  tick / 2 - the frame step, 9 a second: fire, glints, wings
;    beat   tick / 8 - the BEAT: a step every 8 ticks, two to a heartbeat at
;           rest (68 a minute). Water, fountains, creatures walk on it.
;  The pilot: the game was "wildly dynamic - calm is needed, a relaxing
;  evening after work, the rhythm of a human heart". The rules (SCENE.MD):
;  - One clock for everything that moves; only fire and glints go faster,
;    at the frame rate, and never all at once.
;  - NOTHING IN STEP: every candy, torch, firefly has its own period and its
;    own phase from a hash of where it is; a period is never a multiple of
;    the beat ("every crystal moves on one timer - there is no mystery").
;    PERIOD below gives each thing its own.
;  - NOTHING BLINKS: two pictures swapped on a clock read as blinking ("the
;    torches do not burn, they blink"): change a shape a little every frame
;    (R_FLAME), fade a light in and out over a few frames (GLINT's colours).
;  - Draw a frame only when CLOCK says something changed; between frames
;    rest (STI, HLT) so a desktop DOSBox rests.
;  Mode: any. Keeps every register except those under out:.
; ============================================================================

; ----------------------------------------------------------------------
;@ CLOCK      the scene clock: now = BIOS tick, fstep = tick/2, beat = tick/8
;  in:  -
;  out: CF = 1 when fstep or beat moved on (draw a frame), else CF = 0
;  needs: -
;  from: GAMES\MULTSOK2\MULTSOK2.ASM TIMERS 2036-2063 (proven there)
; ----------------------------------------------------------------------
CLOCK:  push ax
        push cx
        push es
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:046Ch]      ; the BIOS tick, low word
        mov  [now],ax
        mov  ch,0               ; CH = 1: something moved on
        shr  ax,1               ; tick / 2: the frame step
        cmp  ax,[fstep]
        je   .beat
        mov  [fstep],ax
        mov  ch,1
.beat:  mov  ax,[now]
        mov  cl,3
        shr  ax,cl              ; tick / 8: the beat
        cmp  al,[beat]
        je   .done
        mov  [beat],al
        mov  ch,1
.done:  shr  ch,1               ; CF = what moved on
        pop  es
        pop  cx
        pop  ax
        ret

; ----------------------------------------------------------------------
;@ PERIOD     a thing's own period and moment: never in step with another
;  in:  AX = the thing's seed (its cell number, or x + 3y), BX = the
;       shortest period in ticks (1 or more), CL = the spread (a mask:
;       127 gives periods BX .. BX+127)
;  out: AX = which time round it is, DX = ticks into this time,
;       CX = its period
;  needs: CLOCK called this frame ([now])
;  from: GAMES\MULTSOK2\SCENE.INC GLINT 1969-1986 (proven there)
; ----------------------------------------------------------------------
PERIOD: push bx
        push si
        mov  si,bx              ; the shortest period
        mov  bx,40503
        mul  bx                 ; AX = the seed scattered  (DX goes)
        mov  bx,ax              ; BX: its moment in the period
        mov  al,ah
        and  al,cl              ; the spread
        xor  ah,ah
        add  ax,si              ; its period: shortest + spread
        mov  cx,ax              ; (1 or more: never a divide by 0)
        mov  ax,[now]
        add  ax,bx              ; its own moment
        xor  dx,dx
        div  cx                 ; AX = which time, DX = ticks into it
        pop  si
        pop  bx
        ret

now     dw 0                    ; the BIOS tick
fstep   dw 0                    ; tick / 2
beat    db 0                    ; tick / 8
