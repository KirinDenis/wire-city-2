; ============================================================================
;  SPOOL.COM - WIRE CITY engine example 06: the spool-up
;
;  The first sound in the reference tape is not the takeoff - it is the
;  2.5 seconds BEFORE it: a line on the spectrogram climbing from ~1.5
;  to ~3 kHz while nothing on screen moves yet (F-16 cockpit tape,
;  FlightRef takeoff/v1, spool at 1:17.5-1:19.8, brake release 1:20.5).
;
;  This machine plays that line on the game's own sound rig. The bed is
;  a procedural turbine (rumble square + whine square + air noise) on
;  the RING auto-init DMA loop, and the whole performance is ONE knob:
;  the DSP time constant. Half rate = idle. Full rate = mil power. The
;  46-step ramp between them is smoothstep - slow catch, steep middle,
;  flat top - which is the shape the spectrogram line draws, and one
;  octave up mirrors the measured 1.5 -> 3 kHz climb. Each ramp tick
;  prints a '#': you HEAR the curve and SEE its length.
;
;  At mil power the knob wavers by a step - a turbine at power is never
;  a clean note. At idle it breathes the same way, slower.
;
;  SPACE throttles up (and, at power, back down: the wind-down rides
;  the same table backwards at half speed). ESC quits. Needs a Sound
;  Blaster at 220h, DMA 1 (DOSBox: yes). ~1.5 KB of .COM.
; ============================================================================
SNDN    equ 8000h               ; the ring length; must precede the code
                                ; (one-pass TASM: immediates need the value)
TCIDLE  equ 75                  ; time constant at idle:  ~5512 Hz
TCFULL  equ 165                 ; time constant at power: ~11025 Hz
NRAMP   equ 46                  ; ramp steps = ticks; 46/18.2 = 2.5 s

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
        call GENBED             ; bake the turbine bed
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
        ; ---- DSP: speaker on, idle rate, block size, loop forever ----
        mov  ah,0D1h
        call SBWR
        mov  byte ptr [curtc],TCIDLE
        call SETTC
        mov  ah,48h             ; block size = the whole ring
        call SBWR
        mov  ax,SNDN-1
        mov  ah,al
        call SBWR
        mov  ax,SNDN-1
        call SBWR               ; high byte (already in AH)
        mov  ah,1Ch             ; 8-bit PCM, auto-init: spin forever
        call SBWR
        mov  ah,9
        mov  dx,offset MIDLE
        int  21h

; ---- the main loop: one state step per BIOS tick, react to keys -----------
@@loop: push es
        mov  ax,40h
        mov  es,ax
        mov  ax,es:[6Ch]        ; the stock 18.2 Hz heartbeat
        pop  es
        cmp  ax,[ltick]
        je   @@keys
        mov  [ltick],ax
        call TICK
@@keys: mov  ah,1               ; a key waiting?
        int  16h
        jz   @@loop
        xor  ah,ah
        int  16h
        cmp  al,27
        je   @@quit
        cmp  al,' '
        jne  @@loop
        cmp  byte ptr [state],0 ; idle -> start the spool
        jne  @@sdn
        mov  byte ptr [state],1
        mov  word ptr [ridx],0
        mov  ah,9
        mov  dx,offset MUP
        int  21h
        jmp  @@loop
@@sdn:  cmp  byte ptr [state],2 ; at power -> wind down
        jne  @@loop             ; mid-ramp presses are ignored
        mov  byte ptr [state],3
        mov  ah,9
        mov  dx,offset MDOWN
        int  21h
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
        mov  ah,9
        mov  dx,offset MBYE
        int  21h
        mov  ax,4C00h
        int  21h

; ---- TICK: advance the state machine one 55 ms step -----------------------
TICK:   inc  word ptr [tcnt]
        mov  al,[state]
        or   al,al
        jz   @@idle
        cmp  al,1
        je   @@up
        cmp  al,2
        je   @@full
        ; ---- state 3: wind-down - the table backwards at half speed ----
        test word ptr [tcnt],1
        jnz  @@done
        mov  bx,[ridx]
        or   bx,bx
        jz   @@toidle
        dec  bx
        mov  [ridx],bx
        mov  al,[TCRAMP+bx]
        mov  [curtc],al
        call SETTC
        ret
@@toidle:
        mov  byte ptr [state],0
        mov  byte ptr [curtc],TCIDLE
        call SETTC
        mov  ah,9
        mov  dx,offset MIDLE
        int  21h
        ret
@@idle: ; ---- idle: a slow breath, one step every 8 ticks ----
        test word ptr [tcnt],7
        jnz  @@done
        call RND16
        and  ax,1
        add  al,TCIDLE
        mov  [curtc],al
        call SETTC
        ret
@@up:   ; ---- spool: ride the measured curve, print its progress ----
        mov  bx,[ridx]
        mov  al,[TCRAMP+bx]
        mov  [curtc],al
        call SETTC
        mov  dl,'#'
        mov  ah,2
        int  21h
        inc  bx
        mov  [ridx],bx
        cmp  bx,NRAMP
        jb   @@done
        mov  byte ptr [state],2
        mov  ah,9
        mov  dx,offset MFULL
        int  21h
        ret
@@full: ; ---- mil power: the note wavers by a step every other tick ----
        test word ptr [tcnt],1
        jnz  @@done
        call RND16
        and  ax,3
        dec  ax                 ; -1..2 around the top rate
        add  ax,TCFULL
        mov  [curtc],al
        call SETTC
@@done: ret

; ---- SETTC: program the DSP sample rate from [curtc] ----------------------
SETTC:  mov  ah,40h
        call SBWR
        mov  ah,[curtc]
        call SBWR
        ret

; ---- GENBED: the procedural turbine ---------------------------------------
; Matched to the reference octave profile (FlightRef takeoff/v1): the
; jet is a 125-500 Hz roar HUMP falling ~10 dB/octave above it, a sub
; rumble ~3 dB under the hump, and a whisper of blade whine on top.
; Four cascaded one-pole lowpasses (two at ~440 Hz, two at ~880) shape
; LCG noise into the hump; a leaky brownian walk is the sub; the final
; neighbour average is the cockpit muffle. Noise takes the LCG HIGH
; byte - the low bits ring (the TERRA lesson). Band for band this bed
; sits within ~1 dB of the tape through 1 kHz; at idle the DSP plays
; the whole ring an octave down.
GENBED: push es
        cld
        mov  ax,[sndseg]
        mov  es,ax
        xor  di,di
        xor  si,si              ; whine phase counter 0..5
        xor  bp,bp              ; the brownian walk
        mov  word ptr [bm1],0
        mov  word ptr [bm2],0
        mov  word ptr [bm3],0
        mov  word ptr [bm4],0
        mov  word ptr [praw],0
@@g:    call RND16
        mov  al,ah              ; high byte only
        xor  ah,ah
        and  ax,31
        sub  ax,15              ; n = -15..16
        mov  bx,ax              ; keep n for the walk
        mov  cl,4
        shl  ax,cl              ; x16: filter headroom
        sub  ax,[bm1]           ; pole 1 (~440 Hz): m += (x - m)/4
        sar  ax,1
        sar  ax,1
        add  [bm1],ax
        mov  ax,[bm1]           ; pole 2 (~440 Hz)
        sub  ax,[bm2]
        sar  ax,1
        sar  ax,1
        add  [bm2],ax
        mov  ax,[bm2]           ; pole 3 (~880 Hz): m += (x - m)/2
        sub  ax,[bm3]
        sar  ax,1
        add  [bm3],ax
        mov  ax,[bm3]           ; pole 4 (~880 Hz)
        sub  ax,[bm4]
        sar  ax,1
        add  [bm4],ax
        mov  dx,[bm4]           ; the roar, gain back down, fenced
        sar  dx,1
        sar  dx,1
        cmp  dx,38
        jle  @@r1
        mov  dx,38
@@r1:   cmp  dx,-38
        jge  @@r2
        mov  dx,-38
@@r2:   mov  ax,bx              ; walk += n/2, minus a 1/16 leak
        sar  ax,1
        add  bp,ax
        mov  ax,bp
        mov  cl,4
        sar  ax,cl
        sub  bp,ax
        cmp  bp,16              ; fence the sub
        jle  @@w1
        mov  bp,16
@@w1:   cmp  bp,-16
        jge  @@w2
        mov  bp,-16
@@w2:   add  dx,bp              ; raw = roar + sub + whisper whine
        cmp  si,3
        jae  @@g2
        add  dx,2
        jmp  @@g3
@@g2:   sub  dx,2
@@g3:   mov  ax,dx              ; muffle: average with the neighbour
        add  ax,[praw]
        sar  ax,1
        mov  [praw],dx
        add  ax,128
        cmp  word ptr [warmc],0 ; warm-up: filters reach steady state
        je   @@st               ; before the first sample lands (a cold
        dec  word ptr [warmc]   ; start = a once-per-loop "wave")
        jmp  @@wh
@@st:   stosb
@@wh:   inc  si
        cmp  si,6
        jb   @@g4
        xor  si,si
@@g4:   cmp  di,SNDN
        jb   @@g
        xor  si,si              ; splice the seam: the last 512 samples
@@xf:   mov  di,si              ; fade into the first 512
        add  di,SNDN-512
        mov  al,es:[di]
        mov  [xtt],al
        mov  al,es:[si]
        sub  al,[xtt]
        cbw
        mov  bx,si
        mov  cl,3
        shr  bx,cl
        imul bx                 ; (head - tail) * i/8
        mov  cl,6
        sar  ax,cl              ; ... / 64  =  * i/512
        add  al,[xtt]
        mov  es:[di],al
        inc  si
        cmp  si,512
        jb   @@xf
        pop  es
        ret

; ---- data ------------------------------------------------------------------
BANNER  db 'SPOOL - the F-16 spool-up on one DSP knob',13,10
        db 'SPACE throttle up / down    ESC quit',13,10,'$'
MIDLE   db 13,10,'IDLE',13,10,'$'
MUP     db 'SPOOL ','$'
MFULL   db 13,10,'MIL POWER',13,10,'$'
MDOWN   db 'WIND-DOWN',13,10,'$'
MBYE    db 13,10,'$'
NOSB    db 'No Sound Blaster at 220h.',13,10,'$'
; The ramp: smoothstep from idle to full over 46 ticks (2.5 s) - the
; shape and duration measured on the reference spectrogram spool line.
TCRAMP  db  75, 75, 76, 76, 77, 78, 79, 81, 83, 84, 86, 89
        db  91, 93, 96, 98,101,104,107,110,113,116,119,121
        db 124,127,130,133,136,139,142,144,147,149,151,154
        db 156,157,159,161,162,163,164,164,165,165
rseed   dw 7321                 ; LCG state (fixed seed: noise is noise)
bm1     dw 0                    ; bed: lowpass pole states
bm2     dw 0
bm3     dw 0
bm4     dw 0
praw    dw 0                    ; bed: previous raw sum (the muffler)
warmc   dw 2048                 ; bed: warm-up samples to discard
xtt     db 0                    ; bed: crossfade scratch
sndseg  dw 0                    ; the ring segment (64K-aligned)
sbmsk   db 0                    ; saved IRQ 7 mask bit
state   db 0                    ; 0 idle, 1 spooling, 2 mil power, 3 down
ridx    dw 0                    ; position on the ramp
curtc   db TCIDLE               ; current DSP time constant
ltick   dw 0                    ; last BIOS tick seen
tcnt    dw 0                    ; tick counter (breath / waver phases)

        INCLUDE ..\ENGINE\E_MATH.INC
        INCLUDE ..\ENGINE\E_SND.INC

CODE    ENDS
        END START
