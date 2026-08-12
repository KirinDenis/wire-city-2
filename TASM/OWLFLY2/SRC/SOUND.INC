; SOUND.INC - part of WIRE CITY (included from CITY.ASM)
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

; ---- SBINIT: find the DSP, load the sample, start the eternal loop -------
SBINIT: mov  dx,226h            ; DSP reset pulse
        mov  al,1
        out  dx,al
        in   al,dx
        in   al,dx
        in   al,dx
        in   al,dx
        xor  al,al
        out  dx,al
        mov  cx,4000            ; wait for the 0AAh hello
@@rst:  mov  dx,22Eh
        in   al,dx
        test al,80h
        jz   @@nx
        mov  dx,22Ah
        in   al,dx
        cmp  al,0AAh
        je   @@got
@@nx:   loop @@rst
        ret                     ; no Blaster: silence, the game runs on
@@got:
        ; ---- a 64K-aligned segment right after CS+4000h: the physical
        ; address is a multiple of 65536, so the 32K loop can never
        ; cross a DMA page boundary
        mov  ax,cs
        add  ax,4FFFh
        and  ax,0F000h
        mov  [sndseg],ax
        ; ---- the NEWTON turbine: GENERATED, not loaded. ENGINE.RAW ----
        ; retired; GENBED (in the sky segment) cuts the tuned bed fresh
        ; every launch, pristine copy in the top half included
        call FAR PTR GENBEDF
        mov  byte ptr [sbok],1
        ; ---- 8237 DMA channel 1: auto-init, read from memory ----
        mov  al,05h
        out  0Ah,al             ; mask channel 1
        xor  al,al
        out  0Ch,al             ; clear the flip-flop
        mov  al,59h
        out  0Bh,al             ; mode: auto-init, read, channel 1
        xor  al,al
        out  02h,al             ; address 0 (the segment is page-aligned)
        out  02h,al
        mov  ax,SNDN-1
        out  03h,al             ; count low
        mov  al,ah
        out  03h,al             ; count high
        mov  ax,[sndseg]
        mov  cl,12
        shr  ax,cl
        out  83h,al             ; page
        mov  al,01h
        out  0Ah,al             ; unmask channel 1
        ; ---- mask IRQ 7: the loop needs no servicing ----
        in   al,21h
        mov  [sbmsk],al
        or   al,80h
        out  21h,al
        ; ---- DSP: speaker on, pitch, block size, auto-init go ----
        mov  ah,0D1h
        call SBWR
        mov  ah,40h
        call SBWR
        mov  ah,162             ; ~10.6 kHz to start
        call SBWR
        mov  ah,48h             ; block size SNDN-1
        call SBWR
        mov  ax,SNDN-1
        mov  ah,al
        call SBWR
        mov  ax,SNDN-1
        call SBWR               ; high byte (already in AH)
        mov  ah,1Ch             ; 8-bit PCM, auto-init, forever
        call SBWR
@@ret:  ret


; ============================================================================
;  ONE-SHOT EFFECTS - mixed straight into the spinning engine ring.
;  The 8237 tells us where the beam is (current-count register); effects
;  are added ~60 ms AHEAD of it, play once as the beam sweeps through,
;  and SNDHEAL erases them BEHIND the beam from the pristine copy kept
;  in the top half of the sample segment. No second channel, no mixer -
;  the ring itself is the mixer.
; ============================================================================

; ---- SNDHEAL: heal the ring behind the beam from the pristine copy -------
SNDHEAL:push cx
        push dx
        push si
        push di
        call SFXRAW
        mov  ax,bx
        sub  ax,64              ; stay just behind the beam
        and  ax,SNDN-1
        mov  cx,ax
        sub  cx,[sbrst]
        and  cx,SNDN-1
        cmp  cx,4096            ; cap a burst after a long stall
        jbe  @@n1
        mov  cx,4096
@@n1:   jcxz @@done
        mov  di,[sbrst]
        mov  ax,di
        add  ax,cx
        and  ax,SNDN-1
        mov  [sbrst],ax
        mov  bl,[sndmod]
        push ds
        push es
        mov  ax,[sndseg]
        mov  ds,ax
        mov  es,ax
        cld
@@cp:   cmp  bl,2
        jne  @@sil
        mov  si,di
        add  si,SNDN            ; the clean loop lives in the top half
        movsb
        jmp  @@nx
@@sil:  mov  al,80h             ; engine muted: heal to flat silence
        stosb
@@nx:   and  di,SNDN-1
        loop @@cp
        pop  es
        pop  ds
@@done: pop  di
        pop  si
        pop  dx
        pop  cx
        ret

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
SFXPLAY:cmp  byte ptr [sbok],0
        je   @@r
        cmp  byte ptr [sndmod],0
        je   @@r
        cmp  word ptr [sfxseg],0
        je   @@r                ; no bank on disk: silence, the game runs on
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        push ds
        push es
        mov  bl,ah              ; the shift, out of the way of SFXRAW
        xor  ah,ah
        mov  si,ax
        add  si,si
        add  si,si
        add  si,4               ; index entry: past 'SF' and the count
        push bx
        call SFXRAW             ; BX = where the beam is now
        lea  di,[bx+700]        ; ~60 ms ahead of it
        and  di,SNDN-1
        pop  bx
        mov  ax,[sndseg]        ; READ BOTH SEGMENTS FIRST - the moment DS
        mov  dx,[sfxseg]        ;  moves, no main-segment word is reachable
        mov  es,ax
        mov  ds,dx
        mov  cx,[si+2]          ; how long this one is...
        mov  si,[si]            ; ...and where it starts
        jcxz @@x
        mov  bp,cx              ; the count rides BP: CL is the shift
@@m:    lodsb                   ; DS:SI = the bank
        cbw                     ; signed 8-bit delta -> 16
        mov  cl,bl
        sar  ax,cl
        mov  dx,ax
        call SFXMB              ; ES:DI, adds, clamps, advances, wraps
        dec  bp
        jnz  @@m
@@x:    pop  es
        pop  ds
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
@@r:    ret

; ---- SFXPOP: the cannon --------------------------------------------------
; Was a dying square wave and a breath of noise; it is now the recording.
SFXPOP: mov  ax,SFX_GUN
        call SFXPLAY
        ret

; ---- SFXHISS: the missile leaves the rail --------------------------------
; Was fading white noise; it is now the rocket recording.
SFXHISS:mov  ax,SFX_RKT
        call SFXPLAY
        ret

; ---- SFXBOOM: an explosion. AH = loudness, CX = length in samples ---------
; The signature is UNCHANGED and both are still honoured in spirit, which is
; why not one call site had to be touched: AH picks the volume step and CX,
; which used to set how long the rumble ran, is now the recording's own
; business. AH arrives as 14..95 - SFXBM2 computes it from range and gates
; anything under 14 as too far to hear - so the four steps are cut across
; that span and not across 0..255.
SFXBOOM:mov  ah,ah              ; (AH = loudness, as it always was)
        cmp  ah,64
        jae  @@v0
        cmp  ah,40
        jae  @@v1
        cmp  ah,24
        jae  @@v2
        mov  ah,3
        jmp  @@go
@@v0:   xor  ah,ah
        jmp  @@go
@@v1:   mov  ah,1
        jmp  @@go
@@v2:   mov  ah,2
@@go:   mov  al,SFX_BOOM
        call SFXPLAY
        ret

; ---- SFXDETH: the player's own aeroplane coming apart ---------------------
; Its own recording, because this one is not an event in the world - it is
; the end of your sortie, and it is the only sound in the game that is about
; you. Always full volume: there is no range to it.
SFXDETH:mov  ax,SFX_DETH
        call SFXPLAY
        ret

; ---- SFXBM2: an explosion at world (DX,BX) - loudness falls with range ----
SFXBM2: cmp  byte ptr [sbok],0
        je   @@r
        cmp  byte ptr [sndmod],0
        je   @@r
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        mov  ax,dx
        sub  ax,[camx]
        jns  @@a1
        neg  ax
@@a1:   mov  cl,6
        shr  ax,cl
        mov  si,ax
        mov  ax,bx
        sub  ax,[camz]
        jns  @@a2
        neg  ax
@@a2:   shr  ax,cl
        add  si,ax              ; manhattan range / 64
        mov  ax,92
        sub  ax,si
        cmp  ax,14
        jl   @@done             ; too far off to hear
        mov  ah,al
        mov  cx,5500
        call SFXBOOM
@@done: pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
@@r:    ret

; ---- SFXBEEP: the caution audio. BL now says WHICH, not what pitch --------
; It used to be a square wave and BL was its half-period, so each lamp sang
; its own note. There are two recordings instead of four notes, and the
; split is by URGENCY rather than by lamp: a lock is somebody else's missile
; and gets the critical tone, everything else gets the caution tone. BL = 0
; caution, non-zero critical.
SFXBEEP:mov  al,SFX_CAUT
        or   bl,bl
        jz   @@bq
        mov  al,SFX_WARN
@@bq:   mov  ah,1               ; a step down: these repeat, and an alarm at
        call SFXPLAY            ;  full swing every second is a hammer
        ret

; ---- SNDBEEP: the caution lamps sing, each its own note (tick-side) -------
; one lamp per 16-tick slot, so at worst it is a slow round-robin choir:
; STALL urgent and high, FUEL mid, TERRAIN a low horn, LOCK a top blip
SNDBEEP:cmp  byte ptr [sbok],0
        je   @@r
        cmp  byte ptr [sndmod],0
        je   @@r
        mov  ax,[lasttk]
        cmp  ax,[lastbp]
        je   @@r
        mov  bx,ax
        and  bx,15
        or   bx,bx
        jnz  @@f
        mov  ax,[vel]           ; slot 0: STALL
        cmp  ax,[vstl]
        jge  @@r
        mov  bl,0               ; STALL: caution
        jmp  @@go
@@f:    cmp  bx,4               ; slot 4: FUEL
        jne  @@t
        cmp  word ptr [fuel],1200
        jge  @@r
        mov  bl,0               ; FUEL: caution
        jmp  @@go
@@t:    cmp  bx,8               ; slot 8: TERRAIN
        jne  @@l
        mov  ax,[camy]
        sub  ax,[lgnd]
        cmp  ax,150
        jge  @@r
        mov  bl,0               ; TERRAIN: caution
        jmp  @@go
@@l:    cmp  bx,12              ; slot 12: LOCK
        jne  @@r
        cmp  word ptr [locki],0FFFFh
        je   @@r
        mov  bl,1               ; LOCK: the critical one
@@go:   mov  ax,[lasttk]
        mov  [lastbp],ax
        call SFXBEEP
@@r:    ret

; ---- SNDTOG: V key - all sounds -> effects only -> silence -> all ---------
; "effects only" flattens the engine bed in the ring at once (effects are
; still mixed in over silence); "silence" is the DSP speaker switch, the
; DMA loop keeps spinning underneath so any mode is one keypress away.
SNDTOG: cmp  byte ptr [sbok],0
        je   @@r
        mov  al,[sndmod]
        dec  al
        jns  @@m1
        mov  al,2
@@m1:   mov  [sndmod],al
        or   al,al
        jnz  @@on
        mov  ah,0D3h            ; mode 0: hardware speaker off
        call SBWR
        ret
@@on:   mov  ah,0D1h            ; speaker back on
        call SBWR
        push cx
        push si
        push di
        push es
        mov  bx,[sndseg]
        mov  es,bx
        xor  di,di
        cld
        cmp  byte ptr [sndmod],2
        je   @@cp
        mov  ax,8080h           ; effects only: flatten the engine bed now
        mov  cx,SNDN/2
        rep  stosw
        jmp  @@fin
@@cp:   push ds                 ; full sound: bring the engine back at once
        mov  ds,bx
        mov  si,SNDN
        mov  cx,SNDN/2
        rep  movsw
        pop  ds
@@fin:  pop  es
        pop  di
        pop  si
        pop  cx
@@r:    ret

; ---- SNDENG: once per frame - one knob, the pitch --------------------------
SNDENG: cmp  byte ptr [sbok],0
        je   @@r
        call SNDHEAL            ; erase spent effects behind the beam
        cmp  byte ptr [dying],0
        je   @@live
        mov  bx,[dytick]        ; the fall: wind down to a slow groan
        mov  cl,1
        shr  bx,cl
        mov  ax,150
        sub  ax,bx
        cmp  ax,60
        jge  @@wr
        mov  ax,60
        jmp  @@wr
@@live: mov  ax,[throt]         ; the lever: target N2 = throt*4 (0..256)
        add  ax,ax
        add  ax,ax
        cmp  byte ptr [abon],0
        je   @@sp0
        add  ax,24              ; the burner leans on the spool
@@sp0:  mov  bx,ax              ; THE SPOOL: the note chases the lever
        sub  bx,[sbn2]          ; the way a real turbine does - about a
        mov  ax,bx              ; second to wind up, never a step
        sar  ax,1
        sar  ax,1
        sar  ax,1
        sar  ax,1
        jnz  @@sp1
        or   bx,bx              ; the last fifteen counts still walk in,
        jz   @@sp2              ; one a frame, or the settle never lands
        mov  ax,1
        or   bx,bx
        jns  @@sp1
        neg  ax
@@sp1:  add  [sbn2],ax
@@sp2:  mov  ax,[sbn2]          ; TC = 90 + n2/4: idle 90, military 154,
        sar  ax,1               ; the burner tops out at 160 - the tuned
        sar  ax,1               ; bed's own range from NEWTON's ENG
        add  ax,90
        mov  bx,[mlvl]          ; manoeuvre loading: the airflow works the
        mov  cl,3               ; intake - the note sags under g...
        shr  bx,cl
        sub  ax,bx
        push ax
        mov  ax,[lasttk]        ; ...and wavers at ~2 Hz while it lasts
        add  ax,ax
        and  ax,7
        sub  ax,4
        imul word ptr [mlvl]
        mov  bx,64
        cwd
        idiv bx
        mov  bx,ax
        pop  ax
        add  ax,bx
@@wr:   cmp  ax,[sbtc]
        je   @@r
        mov  [sbtc],ax
        mov  ah,40h
        call SBWR
        mov  ah,byte ptr [sbtc]
        call SBWR
@@r:    ret

; (GENBED moved to SKY.INC - one-shot startup code belongs in the far
; segment; the main 64K pays for every byte with stack headroom)

; ---- SBOFF: silence and put the hardware back (called from QUIT) ----------
SBOFF:  cmp  byte ptr [sbok],0
        je   @@r
        mov  ah,0D3h            ; speaker off
        call SBWR
        mov  dx,226h            ; reset stops the DMA loop
        mov  al,1
        out  dx,al
        in   al,dx
        in   al,dx
        xor  al,al
        out  dx,al
        in   al,21h             ; give IRQ 7 back as we found it
        and  al,7Fh
        mov  ah,[sbmsk]
        and  ah,80h
        or   al,ah
        out  21h,al
@@r:    ret
