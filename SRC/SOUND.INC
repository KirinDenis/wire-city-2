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
SNDN    equ 8000h               ; loop length: 32768 samples (~3 s)

; ---- SBWR: write AH to the DSP (port 22Ch), with a patience limit --------
SBWR:   push cx
        push dx
        mov  dx,22Ch
        mov  cx,1000
@@w:    in   al,dx
        test al,80h
        jz   @@go
        loop @@w
@@go:   mov  al,ah
        out  dx,al
        pop  dx
        pop  cx
        ret

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
        ; ---- a 64K-aligned segment right after CS+3000h: the physical
        ; address is a multiple of 65536, so the 32K loop can never
        ; cross a DMA page boundary
        mov  ax,cs
        add  ax,3FFFh
        and  ax,0F000h
        mov  [sndseg],ax
        ; ---- load ENGINE.RAW into it ----
        mov  dx,offset ENGFN
        mov  ax,3D00h
        int  21h
        jc   @@ret              ; no sample: stay silent
        mov  bx,ax
        push ds
        mov  ax,[sndseg]
        mov  ds,ax
        xor  dx,dx
        mov  cx,SNDN
        mov  ah,3Fh
        int  21h
        pop  ds
        mov  ah,3Eh
        int  21h
        push ds                 ; pristine copy in the segment's top half:
        push es                 ; the ring self-heals from it after SFX
        mov  ax,[sndseg]
        mov  ds,ax
        mov  es,ax
        xor  si,si
        mov  di,SNDN
        mov  cx,SNDN/2
        cld
        rep  movsw
        pop  es
        pop  ds
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

; ---- SFXRAW: BX = the DMA beam position inside the ring -------------------
SFXRAW: xor  al,al
        out  0Ch,al             ; clear the flip-flop
        in   al,03h             ; channel 1 remaining count, low byte...
        mov  bl,al
        in   al,03h             ; ...then high
        mov  bh,al
        mov  ax,SNDN-1
        sub  ax,bx              ; played = total - remaining
        and  ax,SNDN-1
        mov  bx,ax
        ret

; ---- SFXMB: add the signed sample in DX to ES:[DI], clamp, advance -------
SFXMB:  mov  al,es:[di]
        xor  ah,ah
        add  ax,dx
        jns  @@p
        xor  ax,ax
@@p:    cmp  ax,255
        jle  @@q
        mov  ax,255
@@q:    mov  es:[di],al
        inc  di
        and  di,SNDN-1
        ret

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

; ---- SFXPOP: the cannon - a deep thump, almost a clap ---------------------
SFXPOP: cmp  byte ptr [sbok],0
        je   @@r
        cmp  byte ptr [sndmod],0
        je   @@r
        push bx
        push cx
        push dx
        push si
        push di
        push es
        mov  ax,[sndseg]
        mov  es,ax
        call SFXRAW
        lea  di,[bx+700]        ; ~60 ms ahead of the beam
        and  di,SNDN-1
        mov  bx,84              ; a dying deep square, ~125 Hz
        xor  si,si
@@half: mov  cx,44
        mov  dx,bx
        test si,1
        jz   @@go
        neg  dx
@@go:   call SFXMB
        loop @@go
        inc  si
        sub  bx,15
        jg   @@half
        mov  cx,160             ; and a short breath of smoke
@@nz:   push cx
        call RND16
        pop  cx
        and  ax,31
        sub  ax,15
        mov  dx,ax
        call SFXMB
        loop @@nz
        pop  es
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
@@r:    ret

; ---- SFXHISS: the missile leaves the rail - a sharp fading hiss -----------
SFXHISS:cmp  byte ptr [sbok],0
        je   @@r
        cmp  byte ptr [sndmod],0
        je   @@r
        push bx
        push cx
        push dx
        push si
        push di
        push es
        mov  ax,[sndseg]
        mov  es,ax
        call SFXRAW
        lea  di,[bx+700]
        and  di,SNDN-1
        mov  word ptr [sfa16],70*256
        mov  word ptr [sfdec],6
        mov  cx,3000
@@s:    push cx
        call RND16
        and  ax,255
        sub  ax,128
        mov  cl,byte ptr [sfa16+1]
        xor  ch,ch
        imul cx                 ; noise scaled by the fading amplitude
        mov  cl,7
        sar  ax,cl
        mov  dx,ax
        call SFXMB
        mov  ax,[sfa16]
        sub  ax,[sfdec]
        jns  @@s1
        xor  ax,ax
@@s1:   mov  [sfa16],ax
        pop  cx
        loop @@s
        pop  es
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
@@r:    ret

; ---- SFXBOOM: an explosion. AH = loudness, CX = length in samples ---------
SFXBOOM:cmp  byte ptr [sbok],0
        je   @@r
        push bx
        push cx
        push dx
        push si
        push di
        push es
        mov  al,ah
        mov  byte ptr [sfa16],0
        mov  byte ptr [sfa16+1],al
        push cx
        mov  bx,cx
        mov  ax,[sfa16]
        xor  dx,dx
        div  bx                 ; amplitude decay per sample
        or   ax,ax
        jnz  @@d1
        inc  ax
@@d1:   mov  [sfdec],ax
        pop  cx
        mov  ax,[sndseg]
        mov  es,ax
        call SFXRAW
        lea  di,[bx+700]
        and  di,SNDN-1
        xor  si,si              ; the rumble: a random walk...
@@b:    push cx
        call RND16
        and  ax,63
        sub  ax,31
        add  si,ax
        mov  cl,byte ptr [sfa16+1]
        xor  ch,ch
        cmp  si,cx              ; ...fenced by the fading loudness
        jle  @@b1
        mov  si,cx
@@b1:   neg  cx
        cmp  si,cx
        jge  @@b2
        mov  si,cx
@@b2:   mov  dx,si
        call SFXMB
        mov  ax,[sfa16]
        sub  ax,[sfdec]
        jns  @@b3
        xor  ax,ax
@@b3:   mov  [sfa16],ax
        pop  cx
        loop @@b
        pop  es
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
@@r:    ret

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

; ---- SFXBEEP: a caution note. BL = half period in samples ------------------
SFXBEEP:cmp  byte ptr [sbok],0
        je   @@r
        cmp  byte ptr [sndmod],0
        je   @@r
        push bx
        push cx
        push dx
        push si
        push di
        push es
        mov  ax,[sndseg]
        mov  es,ax
        xor  bh,bh
        mov  si,bx
        push si
        call SFXRAW
        pop  si
        lea  di,[bx+700]
        and  di,SNDN-1
        mov  cx,480             ; ~45 ms
        mov  dx,38
        mov  bx,si
@@bp:   call SFXMB
        dec  bx
        jnz  @@b2
        neg  dx                 ; the square flips
        mov  bx,si
@@b2:   loop @@bp
        pop  es
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
@@r:    ret

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
        cmp  ax,VSTALL
        jge  @@r
        mov  bl,7
        jmp  @@go
@@f:    cmp  bx,4               ; slot 4: FUEL
        jne  @@t
        cmp  word ptr [fuel],1200
        jge  @@r
        mov  bl,12
        jmp  @@go
@@t:    cmp  bx,8               ; slot 8: TERRAIN
        jne  @@l
        mov  ax,[camy]
        sub  ax,[lgnd]
        cmp  ax,150
        jge  @@r
        mov  bl,20
        jmp  @@go
@@l:    cmp  bx,12              ; slot 12: LOCK
        jne  @@r
        cmp  word ptr [locki],0FFFFh
        je   @@r
        mov  bl,5
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
@@live: mov  ax,[throt]         ; spool: TC 120..184 = 7.3..13.9 kHz
        add  ax,120             ; (the sample's native pitch ~ 2/3 throttle)
        cmp  byte ptr [abon],0
        je   @@mn1
        add  ax,10              ; the burner leans on the pitch
@@mn1:  mov  bx,[mlvl]          ; manoeuvre loading: the airflow works the
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
