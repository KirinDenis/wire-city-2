; SOUND.INC - part of WIRE CITY (included from OWLFLY3.ASM)
; ============================================================================
;  Sound Blaster engine sound - the REAL thing. INSTALL ships ENGINE.RAW:
;  32768 samples of an actual jet recording (8-bit unsigned, 11025 Hz,
;  loop-smoothed by res\mkengine.py). The loop spins forever through
;  8-bit auto-init DMA at base 220h, and the game touches exactly one
;  knob: the DSP time constant. Bending the sample rate bends the pitch -
;  the throttle spools a real engine, the afterburner screams over it,
;  and the dying jet winds down to a half-speed groan.
;  The loop lives in its own 64K-aligned segment (no DMA page crossing
;  by construction). No Blaster or no ENGINE.RAW = silence, the game
;  runs on. IRQ 7 stays masked: auto-init DMA needs no servicing here.
; ============================================================================
; SNDN, SBWR, SFXRAW and SFXMB live in ENGINE\E_SND.INC (shared with
; EXAMPLES\RING.ASM); this file builds the game's sound on top of them.

; ---- SBINIT: what the pilot picked, made real ------------------------------
;  The sound screen answered in [sndsel]. The Blaster path probes the DSP
;  and starts the eternal loop; the speaker path arms the PIT driver at
;  the foot of this file; NO SOUND touches not one port - a machine whose
;  220h decodes to some other card entirely is left in peace.
SBINIT: cmp  byte [sndsel],1     ; BOND: 1 = the speaker, 2 = NO SOUND -
        jne  .no                ;  the Blaster is not on the menu
        jmp  SPKINIT
.no:   ret

; ============================================================================
;  SFXPLAY - mix one RECORDED sound into the ring. AL = which, AH = volume
;  as a RIGHT SHIFT (0 full, 1 half, 2 quarter, 3 an eighth).
;
;  A shift and not a multiply, and that is the whole reason the volume is
;  coarse: this loop runs once per sample and a sound is up to fourteen
;  thousand of them. A 16-bit IMUL each time round would cost more than the
;  frame it is played in. Four steps of loudness is what the ring can afford
;  and, at eight bits over a running engine, about as many as it can show.
;
;  It writes the WHOLE sound in one go, ~60 ms ahead of the DMA beam, the
;  way SFXBOOM's rumble always did. Nothing has to be serviced afterwards:
;  the beam sweeps through it once and SNDHEAL erases it from behind out of
;  the pristine copy. That is why there is no voice pool and no mixer here -
;  the ring IS the mixer, and it always was.
;
;  The one hard rule is that a sound must be shorter than the ring, or the
;  beam laps its own tail; Snd2Dat enforces it at build time and says so.
; ============================================================================
SFXPLAY:jmp  .r

.r:    ret

; ---- SFXPOP: the cannon --------------------------------------------------
; Was a dying square wave and a breath of noise; it is now the recording.
SFXPOP: cmp  byte [spkon],0
        je   .sb
        mov  al,4               ; the speaker: the clatter, id 4
        jmp  SPKHIT
.sb:   mov  ax,SFX_GUN
        call SFXPLAY
        ret

; ---- SFXHISS: the missile leaves the rail --------------------------------
; Was fading white noise; it is now the rocket recording.
SFXHISS:cmp  byte [spkon],0
        je   .sb
        mov  al,3               ; the speaker: the rising hiss, id 3
        jmp  SPKHIT
.sb:   mov  ax,SFX_RKT
        call SFXPLAY
        ret

; ---- SFXBOOM: an explosion. AH = loudness, CX = length in samples ---------
; The signature is UNCHANGED and both are still honoured in spirit, which is
; why not one call site had to be touched: AH picks the volume step and CX,
; which used to set how long the rumble ran, is now the recording's own
; business. AH arrives as 14..95 - SFXBM2 computes it from range and gates
; anything under 14 as too far to hear - so the four steps are cut across
; that span and not across 0..255.
SFXBOOM:cmp  byte [spkon],0
        je   .sb
        cmp  ah,32              ; one volume only: what the Blaster
        jb   .far               ;  would whisper stays unheard
        mov  al,5               ; the falling rumble, id 5
        jmp  SPKHIT
.far:  ret
.sb:   mov  ah,ah              ; (AH = loudness, as it always was)
        cmp  ah,64
        jae  .v0
        cmp  ah,40
        jae  .v1
        cmp  ah,24
        jae  .v2
        mov  ah,3
        jmp  .go
.v0:   xor  ah,ah
        jmp  .go
.v1:   mov  ah,1
        jmp  .go
.v2:   mov  ah,2
.go:   mov  al,SFX_BOOM
        call SFXPLAY
        ret

; ---- SFXDETH: the player's own aeroplane coming apart ---------------------
; Its own recording, because this one is not an event in the world - it is
; the end of your sortie, and it is the only sound in the game that is about
; you. Always full volume: there is no range to it.
SFXDETH:cmp  byte [spkon],0
        je   .sb
        mov  al,6               ; the long fall, id 6 - nothing
        jmp  SPKHIT             ;  outranks your own end
.sb:   mov  ax,SFX_DETH
        call SFXPLAY
        ret

; ---- SFXBM2: an explosion at world (DX,BX) - loudness falls with range ----
SFXBM2:

        cmp  byte [spkon],0
        jne  .on
        ret
.on:   cmp  byte [sndmod],0
        je   .r
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        mov  ax,dx
        sub  ax,[camx]
        jns  .a1
        neg  ax
.a1:   mov  cl,6
        shr  ax,cl
        mov  si,ax
        mov  ax,bx
        sub  ax,[camz]
        jns  .a2
        neg  ax
.a2:   shr  ax,cl
        add  si,ax              ; manhattan range / 64
        mov  ax,92
        sub  ax,si
        cmp  ax,14
        jl   .done             ; too far off to hear
        mov  ah,al
        mov  cx,5500
        call SFXBOOM
.done: pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
.r:    ret

; ---- SFXBEEP: the caution audio. BL now says WHICH, not what pitch --------
; It used to be a square wave and BL was its half-period, so each lamp sang
; its own note. There are two recordings instead of four notes, and the
; split is by URGENCY rather than by lamp: a lock is somebody else's missile
; and gets the critical tone, everything else gets the caution tone. BL = 0
; caution, non-zero critical.
SFXBEEP:cmp  byte [spkon],0
        je   .sb
        mov  al,1               ; caution: one plain note
        or   bl,bl
        jz   .pk
        mov  al,2               ; critical: the warble
.pk:   jmp  SPKHIT
.sb:   mov  al,SFX_CAUT
        or   bl,bl
        jz   .bq
        mov  al,SFX_WARN
.bq:   mov  ah,1               ; a step down: these repeat, and an alarm at
        call SFXPLAY            ;  full swing every second is a hammer
        ret

; ---- SNDBEEP: the caution lamps sing, each its own note (tick-side) -------
; one lamp per 16-tick slot, so at worst it is a slow round-robin choir:
; STALL urgent and high, FUEL mid, TERRAIN a low horn, LOCK a top blip
SNDBEEP:

        cmp  byte [spkon],0
        jne  .on
        ret
.on:   cmp  byte [sndmod],0
        je   .r
        mov  ax,[lasttk]
        cmp  ax,[lastbp]
        je   .r
        mov  bx,ax
        and  bx,15
        or   bx,bx
        jnz  .f
        mov  ax,[vel]           ; slot 0: STALL
        cmp  ax,[vstl]
        jge  .r
        mov  bl,0               ; STALL: caution
        jmp  .go
.f:    cmp  bx,4               ; slot 4: FUEL
        jne  .t
        cmp  word [fuel],1200
        jge  .r
        mov  bl,0               ; FUEL: caution
        jmp  .go
.t:    cmp  bx,8               ; slot 8: TERRAIN
        jne  .l
        mov  ax,[camy]
        sub  ax,[lgnd]
        cmp  ax,150
        jge  .r
        mov  bl,0               ; TERRAIN: caution
        jmp  .go
.l:    cmp  bx,12              ; slot 12: LOCK
        jne  .r
        cmp  word [locki],0FFFFh
        je   .r
        mov  bl,1               ; LOCK: the critical one
.go:   mov  ax,[lasttk]
        mov  [lastbp],ax
        call SFXBEEP
.r:    ret

; ---- SNDTOG: V key - all sounds -> effects only -> silence -> all ---------
; "effects only" flattens the engine bed in the ring at once (effects are
; still mixed in over silence); "silence" is the DSP speaker switch, the
; DMA loop keeps spinning underneath so any mode is one keypress away.
SNDTOG:

        cmp  byte [spkon],0
        jne  .pk
        ret
.pk:   mov  al,[sndmod]        ; the same three-step cycle, and no
        dec  al                 ;  ring to tend - the drone and the
        jns  .p1                ;  effects sort themselves out next
        mov  al,2               ;  frame in SPKENG
.p1:   mov  [sndmod],al
        or   al,al
        jnz  .p2
        call SPKGOFF            ; silence NOW, not at the next frame
.p2:   ret

; ---- SNDENG: once per frame - one knob, the pitch --------------------------
SNDENG: cmp  byte [paused],0    ; a frozen world holds its breath -
        jne  .r0                ;  PAUSND shut the voice at the door

        cmp  byte [spkon],0
        je   .r0
        jmp  SPKENG             ; the speaker: same job, one wave
.r0:   ret

; (GENBED moved to SKY.INC - one-shot startup code belongs in the far
; segment; the main 64K pays for every byte with stack headroom)

; ---- SBOFF: silence and put the hardware back (called from QUIT) ----------
SBOFF:  cmp  byte [spkon],0
        je   .sb
        call SPKGOFF            ; the gate shut is all it needs
.sb:    jmp  .r

.r:    ret

; ============================================================================
;  THE PC SPEAKER DRIVER - one square wave, bent once a frame.
;
;  No DMA, no samples, no mixing: PIT channel 2 makes the only sound this
;  hardware ever made, and the game bends its frequency the way SNDENG
;  bends the Blaster's sample rate. The engine is a drone that spools with
;  the lever; an effect BORROWS the wave for a few frames - a table row
;  says where its pitch starts, how it slides and how much noise jitter it
;  wears - and the drone takes over again when it is spent. One voice and
;  priorities instead of a mixer: a bigger id simply evicts a smaller one,
;  which is how it really sounded in 1988.
;
;  Everything runs at FRAME rate - a handful of OUTs, nothing per sample -
;  so it costs the 8086 practically nothing. That is the point: the
;  machines that need the speaker are the ones counting cycles.
; ============================================================================

;  one row per effect id: frames to run, starting divisor, slide per frame
;  (negative = the pitch rises), and the noise mask
;    1 caution beep    a plain 880 Hz note
;    2 warning         the same note warbling - somebody's missile
;    3 missile away    a rising hiss
;    4 cannon          a raspy clatter
;    5 explosion       a falling rumble in torn cloth
;    6 the long fall   the player's own end
SPKFRM  db 0,  6,  8, 14,  5, 30, 110
SPKDV0  dw 0, 1355, 1355, 9000, 1500, 4200, 2600
SPKSLD  dw 0,  0,  0, -520, 300, 850, 230
SPKMSK  dw 0,  0,  0, 255, 1023, 2047, 511

; ---- SPKINIT: the pilot picked the speaker ---------------------------------
SPKINIT:mov  byte [spkon],1     ; that is all - the PIT gets programmed the
        ret                     ;  first time there is a note to play

; ---- SPKHIT: an effect asks for the wave. AL = its id ----------------------
;  The id IS the priority: an equal or bigger one takes over (the cannon
;  refiring restarts its own clatter), a smaller one is not heard over
;  what already plays. One voice, honestly rationed.
SPKHIT: cmp  byte [sndmod],0
        je   .r                ; silenced with V: nothing plays
        cmp  al,[spkfx]
        jb   .r
        push bx
        mov  [spkfx],al
        xor  ah,ah
        mov  bx,ax
        mov  al,[SPKFRM+bx]
        mov  [spkfn],al
        add  bx,bx
        mov  ax,[SPKDV0+bx]
        mov  [spkdv],ax
        pop  bx
.r:    ret

; ---- SPKENG: once a frame - the one knob this hardware has -----------------
SPKENG: cmp  byte [sndmod],0
        jne  .on
.qt:   jmp  SPKGOFF            ; V said silence: the gate shut, done
.on:   cmp  byte [spkfx],0
        je   .dro
        jmp  .fx
.dro:  cmp  byte [sndmod],2    ; V's middle step mutes the drone, the way
        jne  .qt                ;  it flattens the Blaster's engine bed
        cmp  byte [dying],0
        jne  .qt                ; the fall is id 6's business, then quiet
        mov  ax,[throt]         ; THE SPOOL, as SNDENG keeps it: target
        add  ax,ax              ;  N2 = throt*4, the burner leans on it,
        add  ax,ax              ;  and the note chases the lever - about
        cmp  byte [abon],0      ;  a second to wind up, never a step
        je   .t0
        add  ax,24
.t0:   mov  bx,ax
        sub  bx,[sbn2]
        mov  ax,bx
        sar  ax,1
        sar  ax,1
        sar  ax,1
        sar  ax,1
        jnz  .t1
        or   bx,bx
        jz   .t2
        mov  ax,1
        or   bx,bx
        jns  .t1
        neg  ax
.t1:   add  [sbn2],ax
.t2:   mov  ax,[sbn2]          ; divisor 21500 - n2*32: idle is a 55 Hz
        mov  bx,ax              ;  mutter, the burner a 105 Hz snarl - a
        mov  cl,5               ;  fighter idling two fields away
        shl  bx,cl
        mov  ax,21500
        sub  ax,bx
        mov  bx,[mlvl]          ; g pulls the note down a shade - the same
        add  bx,bx              ;  intake sag the Blaster's bed wears
        add  bx,bx
        add  ax,bx
        jmp  SPKOUT
        ; ---- an effect owns the wave: slide it, roughen it, count it out
.fx:   mov  bl,[spkfx]
        xor  bh,bh
        add  bx,bx
        mov  ax,[spkdv]
        add  ax,[SPKSLD+bx]
        mov  [spkdv],ax
        cmp  byte [spkfx],2     ; the warning warbles: two notes, frame
        jne  .j0                ;  pairs apart - unmistakably an alarm
        test byte [spkfn],2
        jz   .j0
        add  ax,340
.j0:   push ax
        mov  ax,[spklc]         ; the LCG: the only noise a square wave
        mov  bx,25173           ;  will ever know
        mul  bx
        add  ax,13849
        mov  [spklc],ax
        mov  bl,[spkfx]
        xor  bh,bh
        add  bx,bx
        and  ax,[SPKMSK+bx]
        pop  bx
        add  ax,bx
        dec  byte [spkfn]       ; spent? the drone returns next frame -
        jnz  SPKOUT             ;  the last frame still sounds
        mov  byte [spkfx],0
        ; fall through

; ---- SPKOUT: AX = the divisor, onto the metal ------------------------------
SPKOUT: mov  bx,ax
        mov  al,0B6h            ; channel 2, lo/hi, square wave
        out  43h,al
        mov  al,bl
        out  42h,al
        mov  al,bh
        out  42h,al
        in   al,61h             ; and the gate open - bits 0 and 1
        or   al,3
        out  61h,al
        ret

; ---- SPKGOFF: the gate shut - the timer may spin, nobody listens -----------
SPKGOFF:in   al,61h
        and  al,0FCh
        out  61h,al
        ret

; ---- PAUSND: the pause crossing - quiet going in, the voice back out ------
;  Called ONCE from the ESC latch, not per frame. In: the Blaster's DSP
;  speaker switch (the DMA loop spins silently underneath, as SNDTOG's
;  silence always worked) and the PIT gate shut. Out: the switch back on -
;  unless V had already chosen silence - and the speaker side needs
;  nothing at all: SPKENG re-opens the gate on the next live frame.
PAUSND: cmp  byte [paused],0
        je   .back
        jmp  .pk

.pk:   cmp  byte [spkon],0
        je   .r
        jmp  SPKGOFF
.back:  jmp  .r

.r:    ret
