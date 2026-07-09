; SOUND.INC - part of WIRE CITY (included from CITY.ASM)
; ============================================================================
;  Sound Blaster engine noise, tuned to the real thing. A jet is not a
;  tone: it is BROADBAND noise (exhaust rumble, energy at the bottom)
;  plus a tonal turbine WHINE at the blade-passing frequency that rises
;  with the spool. Synthesis here:
;    - a 2048-byte loop (long enough that the loop period, 4..10 Hz, is
;      inaudible) through 8-bit auto-init DMA at base 220h;
;    - the rumble is BROWNIAN noise (a bounded random walk - red
;      spectrum, just like exhaust turbulence);
;    - the whine is a triangle at sampleRate/8: 1.1..2.4 kHz, and its
;      AMPLITUDE grows with the throttle (baked per throttle band);
;    - the DSP time constant scales the whole spectrum with the
;      throttle - both rumble and whine spool up together, like a real
;      BPF does; the afterburner adds 16 and a crackling roar;
;    - the fall is pure static, refilled every frame so it crackles,
;      with the pitch dropping as the jet goes down.
;  IRQ 7 stays masked (auto-init DMA needs no servicing in DOSBox). No
;  Blaster found = silence, the game runs on. The loop lives at CS+3000h.
; ============================================================================
SNDN    equ 2048                ; loop length (bytes)

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

; ---- SBINIT: reset the DSP, park the looping DMA, start the engine -------
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
        ret                     ; no Blaster: [sbok] stays 0, all quiet
@@got:  mov  byte ptr [sbok],1
        ; ---- the waveform loop sits in the free segment CS+3000h ----
        mov  ax,cs
        add  ax,3000h
        mov  [sndseg],ax
        mov  word ptr [sndofs],0
        mov  bx,ax              ; physical address = seg*16
        mov  cl,4
        shl  ax,cl              ; low 16 bits
        mov  cl,12
        shr  bx,cl              ; DMA page (top 4 bits)
        cmp  ax,0F800h          ; 65536-SNDN: no 64K DMA page crossing
        jb   @@fit
        mov  dx,ax
        neg  dx                 ; distance to the page start
        mov  [sndofs],dx
        xor  ax,ax
        inc  bx
@@fit:  mov  [sbdma],ax         ; DMA offset within the page
        mov  [sbpag],bx
        mov  al,0FFh            ; force the first waveform fill
        mov  [sbkey],al
        xor  al,al
        call SNDKEY
        ; ---- 8237 DMA channel 1: auto-init, read from memory ----
        mov  al,05h
        out  0Ah,al             ; mask channel 1
        xor  al,al
        out  0Ch,al             ; clear the flip-flop
        mov  al,59h
        out  0Bh,al             ; mode: auto-init, read, channel 1
        mov  ax,[sbdma]
        out  02h,al             ; address low
        mov  al,ah
        out  02h,al             ; address high
        mov  ax,SNDN-1
        out  03h,al             ; count low
        mov  al,ah
        out  03h,al             ; count high
        mov  ax,[sbpag]
        out  83h,al             ; page
        mov  al,01h
        out  0Ah,al             ; unmask channel 1
        ; ---- mask IRQ 7: the loop needs no servicing ----
        in   al,21h
        mov  [sbmsk],al
        or   al,80h
        out  21h,al
        ; ---- DSP: speaker on, pitch, block size, auto-init start ----
        mov  ah,0D1h
        call SBWR
        mov  ah,40h
        call SBWR
        mov  ah,170
        call SBWR
        mov  ah,48h             ; block size SNDN-1
        call SBWR
        mov  ax,SNDN-1
        mov  ah,al
        call SBWR
        mov  ax,SNDN-1
        call SBWR               ; high byte (in AH already)
        mov  ah,1Ch             ; 8-bit PCM, auto-init, go
        call SBWR
        ret

; ---- SNDKEY: bake the loop for state key AL = mode*8 + throttleBand ------
;  mode 0 engine, 1 afterburner, 2 the fall.
SNDKEY: mov  [sbkey],al
        mov  bl,al
        mov  cl,3
        shr  bl,cl              ; hmm: key = mode*8+band -> mode
        push bx
        ; rumble window and whine amplitude by mode/band
        mov  al,[sbkey]
        mov  ah,al
        mov  cl,3
        shr  ah,cl              ; mode
        and  al,7               ; throttle band 0..4
        cmp  ah,2
        jne  @@live
        mov  byte ptr [sbra],0  ; the fall: no structure, pure static
        mov  byte ptr [sbwa],0
        jmp  @@fill
@@live: cmp  ah,1
        jne  @@eng
        mov  byte ptr [sbra],52 ; burner: a roar...
        mov  byte ptr [sbwa],18 ; ...the whine half-buried in it
        jmp  @@fill
@@eng:  mov  byte ptr [sbra],26 ; engine: moderate rumble
        mov  ah,al              ; whine grows with the spool: 6+band*6
        add  ah,ah
        add  ah,al              ; band*3
        add  ah,ah              ; band*6
        add  ah,6
        mov  [sbwa],ah
@@fill: pop  bx
        ; ---- bake SNDN samples: brown noise + triangle whine ----
        push es
        mov  es,[sndseg]
        mov  di,[sndofs]
        cld
        xor  bx,bx              ; bl = brown walker (signed), bh = phase
        mov  cx,SNDN
@@f:    push cx
        call RND16              ; preserves BX/DX
        pop  cx
        cmp  byte ptr [sbkey],16 ; mode 2 (key >= 16): the static IS it
        jb   @@tone
        mov  es:[di],al
        inc  di
        loop @@f
        jmp  @@done
@@tone: ; brown walker: += rnd(-7..8), bounded by the rumble window
        mov  dl,al              ; keep noise bits
        and  al,15
        sub  al,7
        add  bl,al
        mov  al,[sbra]
        cmp  bl,al
        jle  @@b1
        mov  bl,al
@@b1:   neg  al
        cmp  bl,al
        jge  @@b2
        mov  bl,al
@@b2:   ; triangle whine at rate/8: phase += 32 per sample
        mov  al,bh
        add  bh,32
        cmp  al,128
        jb   @@t1
        neg  al                 ; fold the ramp into a triangle
@@t1:   sub  al,64              ; -64..64
        push bx
        mov  bl,[sbwa]
        imul bl                 ; tri(-64..64) * amplitude(<40)
        sar  ax,1               ; >>6: whine sample up to ~+-38
        sar  ax,1               ; (CL is the loop counter - shift by 1s)
        sar  ax,1
        sar  ax,1
        sar  ax,1
        sar  ax,1
        pop  bx
        add  al,bl              ; + rumble
        add  al,128             ; centre
        ; the burner spits: rare loud crackle
        cmp  byte ptr [sbkey],8
        jb   @@put
        and  dl,63
        jnz  @@put
        add  al,45
@@put:  mov  es:[di],al
        inc  di
        loop @@f
@@done: pop  es
        ret

; ---- SNDENG: once per frame - waveform state + pitch ----------------------
SNDENG: cmp  byte ptr [sbok],0
        je   @@r
        mov  al,0               ; mode
        cmp  byte ptr [dying],0
        je   @@m1
        mov  al,2
        jmp  @@m2
@@m1:   cmp  byte ptr [abon],0
        je   @@m2
        mov  al,1
@@m2:   mov  ah,al              ; key = mode*8 + throttle band
        mov  cl,3
        shl  ah,cl
        mov  bx,[throt]
        mov  cl,4
        shr  bx,cl              ; band 0..4
        add  ah,bl
        cmp  ah,[sbkey]
        je   @@keep
        mov  al,ah
        call SNDKEY
        jmp  @@tc
@@keep: cmp  byte ptr [sbkey],16
        jb   @@tc
        mov  al,[sbkey]         ; the fall crackles: fresh static
        call SNDKEY
@@tc:   cmp  byte ptr [dying],0 ; pitch = the whole spectrum spools
        je   @@live
        mov  bx,[dytick]        ; the whine falls with the jet
        mov  cl,2
        shr  bx,cl
        mov  ax,180
        sub  ax,bx
        cmp  ax,120
        jge  @@wr
        mov  ax,120
        jmp  @@wr
@@live: mov  ax,[throt]         ; spool: TC 140..204 = 8.6..19.2 kHz
        add  ax,140
        cmp  byte ptr [abon],0
        je   @@wr
        add  ax,16              ; the burner screams higher still
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
