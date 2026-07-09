; SOUND.INC - part of WIRE CITY (included from CITY.ASM)
; ============================================================================
;  Sound Blaster engine noise. A 256-byte waveform loops forever through
;  8-bit auto-init DMA (channel 1, base 220h - the DOSBox default); the
;  game only touches two knobs per frame:
;    - the DSP time constant (40h): the sample rate IS the engine pitch,
;      so the rumble follows the throttle, rises on the afterburner and
;      falls with the dying jet;
;    - the waveform itself on a state change: clean-ish square for the
;      engine, dirty wide noise for the burner, pure static (refilled
;      every frame, so it crackles) for the fall.
;  IRQ 7 is masked at the PIC - auto-init DMA needs no servicing in
;  DOSBox, and we would rather not host another interrupt handler (the
;  PIT/INT8 saga taught humility). No Blaster detected = silence, the
;  game runs on.  The buffer lives in the free segment CS+3000h.
; ============================================================================

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
        in   al,dx              ; a few microseconds of patience
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
        ; ---- the waveform buffer sits in the free segment CS+3000h ----
        mov  ax,cs
        add  ax,3000h
        mov  [sndseg],ax
        mov  word ptr [sndofs],0
        mov  bx,ax              ; physical address = seg*16
        mov  cl,4
        shl  ax,cl              ; low 16 bits
        mov  cl,12
        shr  bx,cl              ; DMA page (top 4 bits)
        cmp  ax,0FF00h          ; the loop must not cross a 64K DMA page
        jb   @@fit
        mov  dx,ax
        neg  dx                 ; distance to the page start
        mov  [sndofs],dx
        xor  ax,ax
        inc  bx
@@fit:  mov  [sbdma],ax         ; DMA offset within the page
        mov  [sbpag],bx
        mov  al,0FFh            ; force the first waveform fill
        mov  [sbmode],al
        mov  al,0
        call SBWAVE
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
        mov  al,255
        out  03h,al             ; count low  (256 bytes - 1)
        xor  al,al
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
        mov  ah,150
        call SBWR
        mov  ah,48h             ; block size 255 (one full loop)
        call SBWR
        mov  ah,255
        call SBWR
        mov  ah,0
        call SBWR
        mov  ah,1Ch             ; 8-bit PCM, auto-init, go
        call SBWR
        ret

; ---- SBWAVE: fill the loop. AL = 0 engine, 1 afterburner, 2 the fall -----
SBWAVE: push es
        mov  [sbfill],al
        mov  es,[sndseg]
        mov  di,[sndofs]
        cld
        mov  cx,256
@@f:    push cx
        call RND16              ; the dirt component
        pop  cx
        mov  bl,al              ; noise byte
        mov  al,128
        cmp  byte ptr [sbfill],2
        je   @@sta              ; the fall: pure wide static
        test cl,32              ; a slow square carries the rumble
        jz   @@lo
        add  al,30
        jmp  @@mix
@@lo:   sub  al,30
@@mix:  cmp  byte ptr [sbfill],1
        jne  @@n0
        and  bl,63              ; burner: loud dirt on the square
        sub  al,32
        add  al,bl
        jmp  @@put
@@n0:   and  bl,15              ; engine: just a little texture
        sub  al,8
        add  al,bl
        jmp  @@put
@@sta:  mov  al,bl              ; static: the noise IS the signal
@@put:  stosb
        loop @@f
        pop  es
        ret

; ---- SNDENG: once per frame - waveform state + pitch ----------------------
SNDENG: cmp  byte ptr [sbok],0
        je   @@r
        mov  al,0               ; pick the mode
        cmp  byte ptr [dying],0
        je   @@m1
        mov  al,2
        jmp  @@m2
@@m1:   cmp  byte ptr [abon],0
        je   @@m2
        mov  al,1
@@m2:   cmp  al,[sbmode]
        je   @@keep
        mov  [sbmode],al
        call SBWAVE
        jmp  @@tc
@@keep: cmp  byte ptr [sbmode],2
        jne  @@tc
        mov  al,2               ; the fall crackles: fresh static each frame
        call SBWAVE
@@tc:   cmp  byte ptr [dying],0 ; pitch
        je   @@live
        mov  bx,[dytick]        ; the whine falls with the jet
        mov  cl,2
        shr  bx,cl
        mov  ax,164
        sub  ax,bx
        cmp  ax,100
        jge  @@wr
        mov  ax,100
        jmp  @@wr
@@live: mov  ax,[throt]         ; rumble follows the throttle...
        add  ax,130
        cmp  byte ptr [abon],0
        je   @@wr
        add  ax,18              ; ...and the burner screams higher
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
