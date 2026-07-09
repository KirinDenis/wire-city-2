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

; ---- SNDENG: once per frame - one knob, the pitch --------------------------
SNDENG: cmp  byte ptr [sbok],0
        je   @@r
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
