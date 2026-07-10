; ============================================================================
;  RING.COM - WIRE CITY engine example 02: the ring mixer
;
;  How WIRE CITY plays an engine loop PLUS cannon, missiles and explosions
;  through ONE Sound Blaster DMA channel with no mixer chip and no second
;  voice: the spinning ring IS the mixer.
;
;   1. A 32K sample ring loops forever through 8-bit auto-init DMA.
;   2. The 8237 controller tells us where the playback beam is (current
;      count register) - no interrupt needed, we ASK.
;   3. A one-shot effect is ADDED (with clamping) into the ring ~60 ms
;      AHEAD of the beam. The beam sweeps through it once.
;   4. A heal pass restores the ring BEHIND the beam from a pristine copy
;      kept in the top half of the same 64K segment - the effect erases
;      itself after playing, and overlapping effects sum like a real mixer.
;
;  The game rides a real recorded jet on this ring; here the bed is a soft
;  procedural rumble so the example needs no data files.
;
;  Keys: 1 = cannon pop, 2 = missile hiss, 3 = explosion, 4 = beep,
;  ESC = quit. ~2 KB of .COM. Needs a Sound Blaster at 220h (DOSBox: yes).
; ============================================================================
SNDN    equ 8000h               ; the ring length; must precede the code
                                ; (one-pass TASM: immediates need the value)
        .8086
        LOCALS
        JUMPS                   ; auto-extend long conditional jumps
CODE    SEGMENT
        ASSUME cs:CODE, ds:CODE, es:CODE, ss:CODE
        ORG  100h

START:  cld
        mov  ah,9
        mov  dx,offset BANNER
        int  21h
        ; ---- find the DSP: reset pulse, wait for the 0AAh hello ----
        mov  dx,226h
        mov  al,1
        out  dx,al
        in   al,dx
        in   al,dx
        in   al,dx
        in   al,dx
        xor  al,al
        out  dx,al
        mov  cx,4000
@@rst:  mov  dx,22Eh
        in   al,dx
        test al,80h
        jz   @@nx
        mov  dx,22Ah
        in   al,dx
        cmp  al,0AAh
        je   @@got
@@nx:   loop @@rst
        mov  ah,9               ; no Blaster: say so and leave
        mov  dx,offset NOSB
        int  21h
        mov  ax,4C01h
        int  21h
@@got:  ; ---- a 64K-aligned segment right above us: the physical address
        ; is a multiple of 65536, so the ring can never cross a DMA page
        mov  ax,cs
        add  ax,3FFFh
        and  ax,0F000h
        mov  [sndseg],ax
        call GENBED             ; bake the bed + the pristine copy
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
        out  83h,al             ; page register
        mov  al,01h
        out  0Ah,al             ; unmask channel 1
        in   al,21h             ; mask IRQ 7: auto-init needs no servicing
        mov  [sbmsk],al
        or   al,80h
        out  21h,al
        ; ---- DSP: speaker on, sample rate, block size, loop forever ----
        mov  ah,0D1h
        call SBWR
        mov  ah,40h             ; time constant: 256-1000000/11025 = 165
        call SBWR
        mov  ah,165
        call SBWR
        mov  ah,48h             ; block size = the whole ring
        call SBWR
        mov  ax,SNDN-1
        mov  ah,al
        call SBWR
        mov  ax,SNDN-1
        call SBWR               ; high byte (already in AH)
        mov  ah,1Ch             ; 8-bit PCM, auto-init: spin forever
        call SBWR

; ---- the main loop: heal behind the beam, react to keys -------------------
@@loop: call HEAL
        mov  ah,1               ; a key waiting?
        int  16h
        jz   @@loop
        xor  ah,ah
        int  16h
        cmp  al,27
        je   @@quit
        cmp  al,'1'
        jne  @@k2
        call SFXPOP
@@k2:   cmp  al,'2'
        jne  @@k3
        call SFXHISS
@@k3:   cmp  al,'3'
        jne  @@k4
        call SFXBOOM
@@k4:   cmp  al,'4'
        jne  @@loop
        call SFXBEEP
        jmp  @@loop

@@quit: mov  ah,0D3h            ; speaker off...
        call SBWR
        mov  dx,226h            ; ...reset stops the DMA loop...
        mov  al,1
        out  dx,al
        in   al,dx
        in   al,dx
        xor  al,al
        out  dx,al
        in   al,21h             ; ...and IRQ 7 back as we found it
        and  al,7Fh
        mov  ah,[sbmsk]
        and  ah,80h
        or   al,ah
        out  21h,al
        mov  ax,4C00h
        int  21h

; ---- GENBED: a soft procedural rumble (the game uses a real recording) ----
; low square wave + noise around the 128 midline, then a pristine copy in
; the segment's top half for the heal pass to restore from.
GENBED: push es
        cld
        mov  ax,[sndseg]
        mov  es,ax
        xor  di,di
@@g:    mov  bl,121             ; square: period 128 samples ~ 86 Hz
        test di,64
        jz   @@g1
        mov  bl,135
@@g1:   call RND16              ; plus a little air
        and  ax,15
        sub  ax,7
        add  al,bl
        stosb
        cmp  di,SNDN
        jb   @@g
        push ds                 ; pristine copy: ring 0..7FFF -> 8000..FFFF
        mov  ax,es
        mov  ds,ax
        xor  si,si              ; DI is already SNDN
        mov  cx,SNDN/2
        rep  movsw
        pop  ds
        pop  es
        ret

; ---- HEAL: restore the ring behind the beam from the pristine copy --------
HEAL:   call SFXRAW             ; BX = beam position
        mov  ax,bx
        sub  ax,64              ; stay just behind the beam
        and  ax,SNDN-1
        mov  cx,ax
        sub  cx,[sbrst]
        and  cx,SNDN-1
        cmp  cx,4096            ; cap a burst after a stall
        jbe  @@h1
        mov  cx,4096
@@h1:   jcxz @@hr
        mov  di,[sbrst]
        mov  ax,di
        add  ax,cx
        and  ax,SNDN-1
        mov  [sbrst],ax
        push ds
        push es
        mov  ax,[sndseg]
        mov  ds,ax
        mov  es,ax
        cld
@@hc:   mov  si,di
        add  si,SNDN            ; the clean copy lives in the top half
        movsb
        and  di,SNDN-1
        loop @@hc
        pop  es
        pop  ds
@@hr:   ret

; ---- SFXPOP: the cannon - a deep dying square, almost a clap --------------
SFXPOP: push es
        mov  ax,[sndseg]
        mov  es,ax
        call SFXRAW
        lea  di,[bx+700]        ; ~60 ms ahead of the beam
        and  di,SNDN-1
        mov  bx,84              ; ~125 Hz square, fading fast
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
        mov  cx,160             ; a short breath of smoke
@@nz:   push cx
        call RND16
        pop  cx
        and  ax,31
        sub  ax,15
        mov  dx,ax
        call SFXMB
        loop @@nz
        pop  es
        ret

; ---- SFXHISS: the missile - a sharp hiss fading over ~0.3 s ---------------
SFXHISS:push es
        mov  ax,[sndseg]
        mov  es,ax
        call SFXRAW
        lea  di,[bx+700]
        and  di,SNDN-1
        mov  word ptr [sfa16],70*256 ; amplitude, 8.8 fixed point
        mov  word ptr [sfdec],6      ; decay per sample
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
        ret

; ---- SFXBOOM: the explosion - a random walk fenced by fading loudness -----
SFXBOOM:push es
        mov  ax,[sndseg]
        mov  es,ax
        mov  word ptr [sfa16],90*256
        mov  word ptr [sfdec],4      ; ~0.55 s to silence
        call SFXRAW
        lea  di,[bx+700]
        and  di,SNDN-1
        mov  cx,6000
        xor  si,si              ; the walker
@@b:    push cx
        call RND16
        and  ax,63
        sub  ax,31
        add  si,ax              ; wander...
        mov  cl,byte ptr [sfa16+1]
        xor  ch,ch
        cmp  si,cx              ; ...inside the shrinking fence
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
        ret

; ---- SFXBEEP: a caution note - plain square, ~610 Hz, 45 ms ---------------
SFXBEEP:push es
        mov  ax,[sndseg]
        mov  es,ax
        call SFXRAW
        lea  di,[bx+700]
        and  di,SNDN-1
        mov  si,9               ; half period in samples
        mov  bx,si
        mov  dx,38
        mov  cx,480
@@bp:   call SFXMB
        dec  bx
        jnz  @@b2
        neg  dx                 ; the square flips
        mov  bx,si
@@b2:   loop @@bp
        pop  es
        ret

; ---- data ------------------------------------------------------------------
BANNER  db 'RING - the WIRE CITY one-channel mixer',13,10
        db '1 cannon  2 missile  3 explosion  4 beep  ESC quit',13,10,'$'
NOSB    db 'No Sound Blaster at 220h.',13,10,'$'
rseed   dw 7321                 ; LCG state (fixed seed: noise is noise)
sndseg  dw 0                    ; the ring segment (64K-aligned)
sbrst   dw 0                    ; heal cursor
sbmsk   db 0                    ; saved IRQ 7 mask bit
sfa16   dw 0                    ; effect amplitude, 8.8 fixed point
sfdec   dw 0                    ; effect decay per sample

        INCLUDE ..\ENGINE\E_MATH.INC
        INCLUDE ..\ENGINE\E_SND.INC

CODE    ENDS
        END START
