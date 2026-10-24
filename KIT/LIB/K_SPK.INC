; K_SPK.INC - the PC speaker: one voice, effects, notes and a little tune
; ============================================================================
;  PIT channel 2 makes a square wave; port 61h bits 0 and 1 open the gate
;  to the speaker. That is the whole instrument. A game sets the pitch a
;  few times a second and nothing else - no samples, no interrupts, almost
;  no CPU. So everything here is driven by ONE call, SPK_TICK, once per
;  BIOS tick (18.2 a second) - or once a frame, if the frames are steady.
;
;  One voice, three layers, the top one that has something is heard:
;    1. an EFFECT (SPK_FX)  - a row of the table: ticks, start divisor,
;       slide per tick, noise mask, a jump, a warble. The effect id IS its
;       priority: an equal or bigger id takes the voice, a smaller one is
;       not heard over what plays. Spent, it gives the voice back.
;    2. a TUNE (SPK_TUNE)   - a list of note,ticks pairs; it keeps its
;       tempo under an effect (it just is not heard for those ticks).
;    3. a DRONE (SPK_DRONE) - a steady divisor, an engine under it all.
;  Nothing left: the gate shuts.
;
;  Divisor = 1193182 / Hz. Bigger divisor = lower note. Divisor 0 is
;  never sent to the PIT (it would mean 65536): 0 means silence here.
;
;  SOUND IS NEVER REQUIRED: a PC without a speaker just stays silent; set
;  [spk_mute] to 1 and nothing is heard (the tune still keeps its time).
;  On every way out of the program call SPK_STOP, or the note goes on
;  sounding in DOS.
;
;  Program pattern:
;        mov  al,SPX_COIN
;        call SPK_FX            ; whenever something happens
;        ...
;        call SPK_TICK          ; once per new BIOS tick, in the main loop
;        ...
;  QUIT: call SPK_STOP
;
;  needs: nothing (no other kit file). 8086.
;  from: GAMES\OWLFLY3\SRC\SOUND.INC:583-701 (SPKHIT/SPKENG/SPKOUT/SPKGOFF
;        and their table, proven there); the throttle drone stripped to
;        SPK_DRONE; the jump column, notes and tune are new.
; ============================================================================

; ---- the effects: id = priority (a bigger one evicts a smaller one) -------
SPX_CLICK = 1                   ; a menu click: one tick of a high note
SPX_BLIP  = 2                   ; a short plain blip
SPX_COIN  = 3                   ; a coin: B then E above it
SPX_JUMP  = 4                   ; a jump: a quick rising swoop
SPX_SHOOT = 5                   ; a shot: a raspy falling clatter
SPX_HIT   = 6                   ; a hit: a low noisy thump
SPX_POWER = 7                   ; a power-up: a long rising slide
SPX_ALARM = 8                   ; an alarm: two notes warbling
SPX_BOOM  = 9                   ; an explosion: a falling rumble in noise
SPX_OVER  = 10                  ; game over: the long fall
SPX_N     = 10                  ; how many (the table has row 0 unused)

; ----------------------------------------------------------------------------
;  THE TABLE, one column per array, row = effect id. A new effect is a new
;  row in each (and SPX_N one bigger). Times are in SPK_TICK calls.
;    spk_tfrm  ticks it runs
;    spk_tdv0  the divisor it starts at
;    spk_tsld  added to the divisor every tick (negative: the pitch rises)
;    spk_tmsk  noise: a random 0..mask is added each tick (0: a clean note)
;    spk_tjt   when the ticks left come down to this, the jump happens once
;    spk_tja   the jump: added to the divisor then (coin: up a fourth)
;    spk_twb   warble: added on the ticks whose count-left has bit 1 set
; ----------------------------------------------------------------------------
;              -   clk  blip coin jump  shoot hit   pwr   alrm  boom  over
spk_tfrm db    0,  1,   2,   6,   4,    3,    3,    10,   8,    12,   30
spk_tdv0 dw    0,  1100,2000,1208,4500, 1500, 3200, 4500, 1355, 4200, 2600
spk_tsld dw    0,  0,   0,   0,   -900, 400,  600,  -340, 0,    1500, 380
spk_tmsk dw    0,  0,   0,   0,   0,    1023, 511,  0,    0,    2047, 511
spk_tjt  db    0,  0,   0,   5,   0,    0,    0,    0,    0,    0,    0
spk_tja  dw    0,  0,   0,   -303,0,    0,    0,    0,    0,    0,    0
spk_twb  dw    0,  0,   0,   0,   0,    0,    0,    0,    340,  0,    0

; ---- the state ---------------------------------------------------------------
spk_mute db 0                   ; 1: nothing is heard (the program's switch)
spk_fx   db 0                   ; the effect playing, 0 none
spk_fn   db 0                   ; its ticks left
spk_dv   dw 0                   ; its divisor now
spk_lc   dw 1                   ; the noise generator's seed
spk_dro  dw 0                   ; the drone's divisor, 0 none
spk_tp   dw 0                   ; the tune: the next pair, 0 no tune
spk_tst  dw 0                   ; the tune's start (for 0FEh, loop)
spk_tn   db 0                   ; ticks left of the tune's note now
spk_tdv  dw 0                   ; the tune note's divisor, 0 a rest

; ----------------------------------------------------------------------
;@ SPK_TONE   sound a divisor on the speaker now (PIT ch2 mode 3, gate open)
;  in:  AX = divisor (1193182/Hz); 0 = shut the gate
;  out: -
;  needs: nothing; [spk_mute]=1 makes it shut the gate instead
;  from: GAMES\OWLFLY3\SRC\SOUND.INC:671-680 (SPKOUT)
; ----------------------------------------------------------------------
if used SPK_TONE
SPK_TONE:
        cmp  byte [spk_mute],0
        jne  SPK_OFF            ; muted: the gate shut
        or   ax,ax
        jz   SPK_OFF            ; 0: silence, never 65536
        push ax
        push bx
        mov  bx,ax
        cmp  bx,32
        jae  .ok
        mov  bx,32              ; above 37 kHz nobody hears it anyway
.ok:    mov  al,0B6h            ; channel 2, low then high byte, mode 3
        out  43h,al
        mov  al,bl
        out  42h,al
        mov  al,bh
        out  42h,al
        pop  bx
        pop  ax
        jmp  SPK_ON
end if

; ----------------------------------------------------------------------
;@ SPK_ON     open the speaker gate (port 61h bits 0,1) on whatever the PIT has
;  in:  -
;  out: -
;  needs: a divisor sent before (SPK_TONE does both)
;  from: GAMES\OWLFLY3\SRC\SOUND.INC:678-680
; ----------------------------------------------------------------------
if used SPK_ON
SPK_ON: push ax
        in   al,61h
        or   al,3               ; bit 0: the timer's gate, bit 1: the speaker
        out  61h,al
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ SPK_OFF    shut the speaker gate: silence now (the state is kept)
;  in:  -
;  out: -
;  needs: nothing
;  from: GAMES\OWLFLY3\SRC\SOUND.INC:683-687 (SPKGOFF)
; ----------------------------------------------------------------------
if used SPK_OFF
SPK_OFF:push ax
        in   al,61h
        and  al,0FCh            ; bits 0 and 1 down
        out  61h,al
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ SPK_FX     start effect AL (SPX_...) if it outranks the one playing
;  in:  AL = effect id 1..SPX_N (the id is its priority)
;  out: -
;  needs: SPK_TICK called every tick to play it
;  from: GAMES\OWLFLY3\SRC\SOUND.INC:599-614 (SPKHIT)
; ----------------------------------------------------------------------
if used SPK_FX
SPK_FX: cmp  byte [spk_mute],0
        jne  .r                 ; muted: nothing starts
        or   al,al
        jz   .r
        cmp  al,SPX_N
        ja   .r                 ; not in the table
        cmp  al,[spk_fx]
        jb   .r                 ; a bigger one plays: not heard over it
        push ax
        push bx
        mov  [spk_fx],al
        xor  ah,ah
        mov  bx,ax
        mov  al,[spk_tfrm+bx]
        mov  [spk_fn],al
        add  bx,bx              ; word rows
        mov  ax,[spk_tdv0+bx]
        mov  [spk_dv],ax
        pop  bx
        pop  ax
.r:     ret
end if

; ----------------------------------------------------------------------
;@ SPK_DRONE  set the steady drone under everything (an engine)
;  in:  AX = divisor, 0 = no drone
;  out: -
;  needs: SPK_TICK to sound it
;  from: new (OWLFLY3 SOUND.INC's throttle drone, reduced to its divisor)
; ----------------------------------------------------------------------
if used SPK_DRONE
SPK_DRONE:
        mov  [spk_dro],ax
        ret
end if

; ----------------------------------------------------------------------
;@ SPK_NOTE   divisor of a note number (1 = C2, 13 = C3, 25 = middle C)
;  in:  AL = note 1..60 (C2..B6); 0 or above 60 = a rest
;  out: AX = divisor, 0 for a rest
;  needs: nothing
;  from: new
; ----------------------------------------------------------------------
if used SPK_NOTE
SPK_NOTE:
        push bx
        xor  ah,ah
        or   al,al
        jz   .rest
        cmp  al,60
        ja   .rest
        mov  bx,ax
        dec  bx                 ; note 1 is row 0
        add  bx,bx              ; word rows
        mov  ax,[spk_notes+bx]
        pop  bx
        ret
.rest:  xor  ax,ax
        pop  bx
        ret
;  divisors of C2..B6, equal temperament, A4 = 440 Hz (note 34)
spk_notes:
        dw 18243,17219,16252,15340,14479,13667,12899,12175,11492,10847,10238,9664
        dw 9121,8609,8126,7670,7240,6833,6450,6088,5746,5424,5119,4832
        dw 4561,4305,4063,3835,3620,3417,3225,3044,2873,2712,2560,2416
        dw 2280,2152,2032,1918,1810,1708,1612,1522,1437,1356,1280,1208
        dw 1140,1076,1016,959,905,854,806,761,718,678,640,604
end if

; ----------------------------------------------------------------------
;@ SPK_TUNE   start a tune: note,ticks byte pairs, played by SPK_TICK
;  in:  SI -> db note,ticks, note,ticks, ... 0FFh (end) or 0FEh (loop);
;       note 0 = a rest, ticks 1..255; SI = 0 stops the tune
;  out: -
;  needs: SPK_TICK every tick; the list stays in memory while it plays
;  from: new
; ----------------------------------------------------------------------
if used SPK_TUNE
SPK_TUNE:
        mov  [spk_tp],si
        mov  [spk_tst],si
        mov  byte [spk_tn],0    ; the first pair is read on the next tick
        mov  word [spk_tdv],0
        ret
end if

; ----------------------------------------------------------------------
;@ SPK_TICK   advance the effect and tune one step and set the speaker
;  in:  -  (call once per BIOS tick, or once per steady frame)
;  out: -
;  needs: nothing; [spk_fx]=0 and [spk_tp]=0 mean idle
;  from: GAMES\OWLFLY3\SRC\SOUND.INC:617-668 (SPKENG); tune and jump new
; ----------------------------------------------------------------------
if used SPK_TICK
SPK_TICK:
        push ax
        push bx
        push dx
        push si
        call .tune             ; the tune keeps its tempo under anything
        cmp  byte [spk_mute],0
        jne  .shut
        cmp  byte [spk_fx],0
        jne  .fx
        mov  ax,[spk_tdv]       ; no effect: the tune's note...
        or   ax,ax
        jnz  .out
        mov  ax,[spk_dro]       ; ...else the drone, else silence
        or   ax,ax
        jnz  .out
.shut:  call SPK_OFF
        jmp  .done
        ; ---- an effect owns the voice: slide it, jump it, roughen it
.fx:    mov  bl,[spk_fx]
        xor  bh,bh
        mov  al,[spk_tjt+bx]
        add  bx,bx              ; word rows from here
        cmp  al,[spk_fn]
        jne  .nj
        mov  ax,[spk_tja+bx]
        add  [spk_dv],ax        ; the jump, once: its tick passes
.nj:    mov  ax,[spk_dv]
        add  ax,[spk_tsld+bx]   ; the slide, a tick's worth
        mov  [spk_dv],ax
        test byte [spk_fn],2
        jz   .nw
        add  ax,[spk_twb+bx]    ; the warble's other note
.nw:    push ax
        mov  ax,[spk_lc]        ; the noise: an LCG, the only noise a
        mov  dx,25173           ;  square wave will ever know
        mul  dx                 ; AX = seed * 25173 (DX goes)
        add  ax,13849           ; + 13849
        mov  [spk_lc],ax
        and  ax,[spk_tmsk+bx]   ; 0..mask of it
        pop  dx
        add  ax,dx              ; onto the divisor
        jnc  .nc
        mov  ax,0FFFFh          ; past the top: the lowest note there is
.nc:    dec  byte [spk_fn]      ; spent? the last tick still sounds
        jnz  .out
        mov  byte [spk_fx],0
.out:   call SPK_TONE
.done:  pop  si
        pop  dx
        pop  bx
        pop  ax
        ret
        ; ---- the tune: a note's ticks counted down, then the next pair
        ;  (SI and AX free here: SPK_TICK keeps them for its caller)
.tune:  mov  si,[spk_tp]
        or   si,si
        jz   .tr                ; no tune
        cmp  byte [spk_tn],0
        je   .rd
        dec  byte [spk_tn]      ; a tick of this note gone
        jnz  .tr
.rd:    mov  al,[si]
        cmp  al,0FFh
        je   .end
        cmp  al,0FEh
        jne  .pair
        mov  si,[spk_tst]       ; 0FEh: round again
        cmp  byte [si],0FEh
        je   .end               ; (a list of nothing but a loop: stop)
        jmp  .rd
.pair:  call SPK_NOTE           ; AX = its divisor, 0 a rest
        mov  [spk_tdv],ax
        mov  al,[si+1]
        or   al,al
        jnz  .t1
        inc  al                 ; ticks 0 would never end: make it 1
.t1:    mov  [spk_tn],al
        add  si,2               ; the next pair
        mov  [spk_tp],si
.tr:    ret
.end:   mov  word [spk_tp],0    ; over
        mov  word [spk_tdv],0
        ret
end if

; ----------------------------------------------------------------------
;@ SPK_STOP   silence everything: effect, tune, drone, gate (every way out)
;  in:  -
;  out: -
;  needs: nothing
;  from: new
; ----------------------------------------------------------------------
if used SPK_STOP
SPK_STOP:
        mov  byte [spk_fx],0
        mov  word [spk_tp],0
        mov  word [spk_tdv],0
        mov  word [spk_dro],0
        jmp  SPK_OFF
end if
