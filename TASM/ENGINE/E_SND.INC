; E_SND.INC - WIRE CITY engine: Sound Blaster primitives
; ============================================================================
;  The three primitives under the ring-mixer architecture: talk to the DSP,
;  ask the 8237 where the DMA beam is, and mix one signed sample into the
;  spinning ring with clamping. Everything else (the eternal loop setup,
;  effects, healing) is built from these - see SRC\SOUND.INC for the full
;  game version and EXAMPLES\RING.ASM for the minimal one.
;
;  CONTRACT: Sound Blaster at base 220h, DMA channel 1. SFXMB expects
;  ES = the ring segment and DI = the write cursor inside it. The includer
;  defines SNDN equ 8000h (the ring length) BEFORE its own code - one-pass
;  TASM needs constants to precede their use as immediates.
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
