; ============================================================================
;  K_PHYS.INC - KIT: motion in 8.8 fixed point, one step per BIOS tick.
;
;  A number with a fraction is a word whose low byte is 256ths: 3.5 is
;  0380h = 896. Speeds and accelerations are 8.8 words per tick; a
;  position is an AXIS record that keeps its whole units in a word and its
;  fraction in a byte beside it, so a slow thing still gets somewhere
;  (guide PHYSICS: "keep the remainder of every small rate"):
;
;  an AXIS, 6 bytes:
PHY_V    = 0                    ; word: velocity, 8.8 units a tick, signed
PHY_F    = 2                    ; byte: the position's fraction, 256ths
PHY_P    = 4                    ; word: the position, whole units, signed
PHY_AXIS = 6                    ; (byte 3 unused)
;
;        ballx  rb PHY_AXIS      ; one record per axis
;        bally  rb PHY_AXIS
;        ...
;        mov  si,bally
;        mov  ax,40              ; gravity 40/256 of a pixel a tick, a tick
;        mov  bx,180             ; the floor
;        mov  cx,205             ; four fifths of the speed back
;        call PHY_FALL           ; one tick: fall, bounce, come to rest
;
;  Angles are bytes, 256 a circle (64 = 90 degrees); sines are x256.
;  The sine table is the kit's own (phy_sint, the same 65 words as
;  ENGINE\E_M3D.INC's SINT) - K_PHYS needs no other file.
;  Physics runs on the tick, never the frame (K_TIME's TIM_STEPS).
;  Guide topics PHYSICS, TIME.
; ============================================================================

; ----------------------------------------------------------------------
;@ PHY_ADD    move axis SI by AX (8.8): the fraction carries into the whole
;  in:  SI -> an axis record, AX = the distance, 8.8 signed
;  out: -  ([si+PHY_P]:[si+PHY_F] += AX)
;  needs: -
;  from: LESSONS\L23\HOUSES.ASM:691-703 (the ADC pattern: nothing between
;        the ADD and the ADC may touch CF)
; ----------------------------------------------------------------------
if used PHY_ADD
PHY_ADD:push ax
        push bx
        mov  bl,al              ; BL = the fraction
        mov  al,ah              ; AL = the whole units...
        cbw                     ; AX = ...with the sign carried up: AX >> 8
        add  [si+PHY_F],bl      ; the fraction accumulates; past 255 it sets CF
        adc  [si+PHY_P],ax      ; whole units + CF
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ PHY_INTEG  one tick on axis SI: v += AX, then p += v (fraction kept)
;  in:  SI -> an axis record, AX = the acceleration, 8.8 a tick, signed
;  out: -  (v saturates at +-32767 instead of wrapping)
;  needs: -
;  from: LESSONS\L04\MATH.ASM:377-383 (v = v + g, y = y + v) with the
;        fraction carry of LESSONS\L23\HOUSES.ASM:691-703
; ----------------------------------------------------------------------
if used PHY_INTEG
PHY_INTEG:
        push ax
        add  ax,[si+PHY_V]      ; AX = v + a
        jno  .ok
        js   .hi                ; wrapped negative: it was a big positive
        mov  ax,8001h           ; wrapped positive: the most negative we keep
        jmp  .ok
.hi:    mov  ax,7FFFh           ; the most positive
.ok:    mov  [si+PHY_V],ax      ; v = v + a
        call PHY_ADD            ; p = p + v
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ PHY_BOUNCE axis SI past floor BX: pin it there, v = -v * CX/256 (CF=1)
;  in:  SI -> an axis record (positions grow DOWN, as screen rows),
;       BX = the floor, whole units; CX = what is kept, 256ths (205 = 4/5,
;       0 = it stops dead, 256 = no loss)
;  out: CF=1 it was at or past the floor (now on it); CF=0 in the air
;  needs: -
;  from: LESSONS\L04\MATH.ASM:385-410 (the floor; -v*205 >> 8 by picking
;        the bytes AH, DL out of DX:AX)
; ----------------------------------------------------------------------
if used PHY_BOUNCE
PHY_BOUNCE:
        push ax
        push dx
        cmp  [si+PHY_P],bx      ; at or below the floor? (signed)
        jl   .air
        mov  [si+PHY_P],bx      ; no sinking into it
        mov  byte [si+PHY_F],0
        mov  ax,[si+PHY_V]
        or   ax,ax
        jle  .t                 ; already going up: leave its speed
        neg  ax                 ; AX = -v: the fall turned into a rise
        imul cx                 ; DX:AX = -v * kept (fits: |v| <= 32767, CX <= 256)
        mov  al,ah              ; the top byte of AX to the bottom...
        mov  ah,dl              ; ...DX's bottom byte on top: DX:AX >> 8
        mov  [si+PHY_V],ax      ; v = -v * kept / 256
.t:     pop  dx
        pop  ax
        stc
        ret
.air:   pop  dx
        pop  ax
        clc
        ret
end if

; ----------------------------------------------------------------------
;@ PHY_FALL   one tick of a falling, bouncing thing that comes to rest
;  in:  SI -> its vertical axis (down grows), AX = gravity 8.8 a tick,
;       BX = the floor, CX = bounce kept, 256ths (205 = 4/5)
;  out: CF=1 on the floor this tick (resting when [si+PHY_V] = 0)
;  needs: -
;  from: LESSONS\L04\MATH.ASM:377-410; the rest rule new: a bounce slower
;        than two ticks of gravity ends it, else it trembles a pixel for ever
; ----------------------------------------------------------------------
if used PHY_FALL
PHY_FALL:
        push dx
        call PHY_INTEG          ; v += g, p += v
        call PHY_BOUNCE
        jnc  .r                 ; still in the air
        mov  dx,[si+PHY_V]
        neg  dx                 ; DX = the speed it bounced up with
        sub  dx,ax
        sub  dx,ax              ; DX = that - 2g
        jg   .on                ; faster: a real bounce
        mov  word [si+PHY_V],0  ; too slow: it rests
.on:    stc
.r:     pop  dx
        ret
end if

; ----------------------------------------------------------------------
;@ PHY_DRAG   AX -= AX >> CL: lose 1/2^CL of a speed, and its last bit too
;  in:  AX = a speed (any fixed point, signed), CL = the shift (4 = 1/16)
;  out: AX = the slower speed; reaches 0 in the end
;  needs: -
;  from: EXAMPLES\SMOKE.ASM:315-323 (velocity decays by 1/16); new: when the
;        shift gives 0 one unit is taken, else a small positive speed
;        never dies (SAR of -1 is -1, of +1 is 0)
; ----------------------------------------------------------------------
if used PHY_DRAG
PHY_DRAG:
        push bx
        mov  bx,ax
        sar  bx,cl              ; BX = v >> k, signed
        or   bx,bx
        jnz  .sub
        or   ax,ax
        jz   .r                 ; stopped
        js   .neg
        dec  ax                 ; a crawl forward: one unit off
        jmp  .r
.neg:   inc  ax                 ; a crawl back: one unit off
        jmp  .r
.sub:   sub  ax,bx              ; v = v - v/2^k
.r:     pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ PHY_CLAMPV AX limited to -BX..+BX
;  in:  AX = a value (signed), BX = the limit, 0..32767
;  out: AX clamped
;  needs: -
;  from: EXAMPLES\SOLO.ASM:400-405 (vs64 within +-2000)
; ----------------------------------------------------------------------
if used PHY_CLAMPV
PHY_CLAMPV:
        cmp  ax,bx
        jle  .lo
        mov  ax,bx              ; too high: the limit
        ret
.lo:    push bx
        neg  bx                 ; BX = -limit
        cmp  ax,bx
        jge  .r
        mov  ax,bx              ; too low: -limit
.r:     pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ PHY_EASE   AX toward 0 by BX, landing exactly on 0 (a spring back, a stop)
;  in:  AX = a value (signed), BX = the step, 0..32767
;  out: AX = AX - BX if it was above BX, + BX if below -BX, else 0
;  needs: -
;  from: GAMES\TRAINER\SRC\F_PHYS.INC:685-696 (EASE4, the 4 made a step)
; ----------------------------------------------------------------------
if used PHY_EASE
PHY_EASE:
        cmp  ax,bx
        jg   .dn                ; above the step: down by it
        push bx
        neg  bx                 ; BX = -step
        cmp  ax,bx
        pop  bx
        jl   .up                ; below -step: up by it
        xor  ax,ax              ; within a step: snap to 0
        ret
.dn:    sub  ax,bx              ; AX -= step
        ret
.up:    add  ax,bx              ; AX += step
        ret
end if

; ----------------------------------------------------------------------
;@ PHY_SIN    AX = sin(AL) * 256  (AL: 256 a circle; -256..256)
;  in:  AL = the angle
;  out: AX = sin * 256
;  needs: -
;  from: ENGINE\E_M3D.INC:31-64 (SINQ: a quarter table and symmetry)
; ----------------------------------------------------------------------
if used PHY_SIN
PHY_SIN:push bx
        push dx
        mov  dl,al              ; DL = the angle: its top bits the quadrant
        and  ax,63              ; AX = the place in the quadrant, 0..63
        test dl,64
        jz   .a                 ; quadrants 0 and 2 read the table forward,
        neg  ax                 ;  1 and 3 backward:
        add  ax,64              ;  AX = 64 - place
.a:     shl  ax,1               ; a word per entry
        mov  bx,ax
        mov  ax,[phy_sint+bx]   ; AX = the table's sine
        test dl,128
        jz   .r                 ; the upper half circle: positive
        neg  ax                 ; the lower half: negative
.r:     pop  dx
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ PHY_COS    AX = cos(AL) * 256
;  in:  AL = the angle (256 a circle)
;  out: AX = cos * 256
;  needs: -
;  from: ENGINE\E_M3D.INC:29 (cos(a) = SINQ(a+64))
; ----------------------------------------------------------------------
if used PHY_COS
PHY_COS:add  al,64              ; a quarter circle on
        jmp  PHY_SIN            ; (AL goes: AX is the answer anyway)
end if

if used phy_sint
phy_sint dw 0,6,13,19,25,31,38,44,50,56,62,68,74,80,86,92,98,104,109,115
        dw 121,126,132,137,142,147,153,157,162,167,172,177,181,185,190,194
        dw 198,202,206,209,213,216,220,223,226,229,231,234,237,239,241,243
        dw 245,247,248,250,251,252,253,254,255,255,256,256,256
end if

; ----------------------------------------------------------------------
;@ PHY_STEPXZ one pace of speed CX along heading AL: AX east, DX north (8.8)
;  in:  AL = heading (0 north, 64 east, 128 south, 192 west), CX = speed,
;       8.8 a tick, signed (|CX| up to 32767)
;  out: AX = the step east (8.8), DX = the step north (8.8) - feed them to
;       PHY_ADD; on the screen north is UP, so y takes -DX
;  needs: -
;  from: LESSONS\L20\FLY.ASM:545-567 (STEPXZ: speed*hsin/256, speed*hcos/256),
;        the /256 done by picking bytes (it never divides)
; ----------------------------------------------------------------------
if used PHY_STEPXZ
PHY_STEPXZ:
        push bx
        mov  bl,al              ; BL = the heading, kept
        call PHY_SIN            ; AX = sin * 256
        imul cx                 ; DX:AX = sin * 256 * speed
        mov  al,ah              ; DX:AX >> 8 by the bytes:
        mov  ah,dl              ;  AX = speed * sin, 8.8
        push ax                 ; the step east, kept
        mov  al,bl
        call PHY_COS            ; AX = cos * 256
        imul cx                 ; DX:AX = cos * 256 * speed
        mov  al,ah
        mov  ah,dl              ; AX = speed * cos, 8.8
        mov  dx,ax              ; DX = the step north
        pop  ax                 ; AX = the step east
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ PHY_TURNTO angle AL turned toward AH the short way, at most CL a call
;  in:  AL = the angle now, AH = the angle wanted (256 a circle), CL = the
;       most it may turn, 1..127 (a turret's slew, a ship's helm)
;  out: AL = the new angle
;  needs: -
;  from: GAMES\OWLFLY3\SRC\UI.INC:3744-3762 (SHKMOVE: the shorter way round,
;        signed, clamped to SHKSTR); LESSONS\L13\ARM.ASM:718-733 (StepJ)
; ----------------------------------------------------------------------
if used PHY_TURNTO
PHY_TURNTO:
        push bx
        mov  bl,ah
        sub  bl,al              ; BL = wanted - now: as a SIGNED byte, the short way
        cmp  bl,cl
        jle  .c1
        mov  bl,cl              ; no more than CL one way...
.c1:    mov  bh,cl
        neg  bh                 ; BH = -CL
        cmp  bl,bh
        jge  .c2
        mov  bl,bh              ; ...nor the other
.c2:    add  al,bl              ; turn (wraps round the circle by itself)
        pop  bx
        ret
end if
