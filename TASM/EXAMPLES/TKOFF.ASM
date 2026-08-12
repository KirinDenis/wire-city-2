; ============================================================================
;  TKOFF.COM - WIRE CITY engine example 07: the measured takeoff
;
;  The cartoon before the physics: this machine REPLAYS the takeoff we
;  measured from the F-16 cockpit tape (FlightRef takeoff/v1, CURVES.md,
;  2026-07-21) as a keyframe performance - no controls, no simulation.
;  If the replay looks and sounds like the tape, the renderer and the
;  pacing are right, and the future physics has a target to reproduce.
;
;  The picture is the racing-road trick: one horizon row, and for every
;  screen row below it the ground distance is a constant (baked once at
;  startup), so the centerline stripe pattern is just (distance + odometer)
;  mod 61 m - the US runway cycle, 120 ft of paint + 80 ft of gap, the
;  same stripes we counted on the tape. No 3D pipeline at all.
;
;  The timeline, from the tape:
;    spool      2.5 s   the DSP knob rides the measured smoothstep
;    brake off          acceleration ~5.7 m/s2, decaying as speed builds
;    the shake          grows, peaks ~55 kt, and DIES ~110 kt: the tape
;                       feels airborne ten seconds before it is
;    seam thumps        every 61 m, fading with the shake
;    rotation   19 s    at ~170 kt the horizon drops fast - and the
;                       runway is simply gone
;
;  Sound rig: the RING auto-init DMA loop; turbine bed, one-shot seam
;  thumps mixed ahead of the beam, a heal pass behind it. SPACE plays
;  the takeoff, ESC quits. Sound Blaster at 220h, DMA 1 (DOSBox: yes).
; ============================================================================
SNDN    equ 8000h               ; ring length; must precede the code
TCIDLE  equ 75                  ; DSP time constant at idle  (~5512 Hz)
TCFULL  equ 165                 ; DSP time constant at power (~11025 Hz)
NRAMP   equ 46                  ; spool steps = ticks; 46/18.2 = 2.5 s
HORIZ0  equ 100                 ; horizon row, wheels on the ground - mid
                                ; screen, as the tape frames it: the pilot
                                ; is NOT looking down at the slab
HORIZ1  equ 185                 ; horizon row, nose up - end of rotation
VROT    equ 1650                ; rotation speed, 1/16 m/s (103 m/s -
                                ; the x-t scan showed a HOLD-DOWN
                                ; takeoff at ~200 kt, not a normal 88)
SEAM    equ 976                 ; stripe cycle, 1/16 m (61 m)
PAINT   equ 592                 ; painted part of the cycle, 1/16 m (37 m)
NROWS   equ 140                 ; ground row tables baked this deep

        .8086
        LOCALS
        JUMPS
CODE    SEGMENT
        ASSUME cs:CODE, ds:CODE, es:CODE, ss:CODE
        ORG  100h

START:  cld
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
@@got:  mov  ax,cs              ; back buffer: the 64K above the program
        add  ax,1000h
        mov  [bufseg],ax
        mov  ax,cs              ; ring: the next 64K-aligned segment - the
        add  ax,3FFFh           ; physical address is a multiple of 65536,
        and  ax,0F000h          ; so the ring never crosses a DMA page
        mov  [sndseg],ax
        call BAKE               ; per-row ground constants
        call GENBED             ; turbine bed + pristine copy
        ; ---- 8237 DMA channel 1: auto-init, read from memory ----
        mov  al,05h
        out  0Ah,al
        xor  al,al
        out  0Ch,al
        mov  al,59h
        out  0Bh,al
        xor  al,al
        out  02h,al
        out  02h,al
        mov  ax,SNDN-1
        out  03h,al
        mov  al,ah
        out  03h,al
        mov  ax,[sndseg]
        mov  cl,12
        shr  ax,cl
        out  83h,al
        mov  al,01h
        out  0Ah,al
        in   al,21h             ; mask IRQ 7: auto-init needs no servicing
        mov  [sbmsk],al
        or   al,80h
        out  21h,al
        ; ---- DSP: speaker on, idle rate, the eternal block ----
        mov  ah,0D1h
        call SBWR
        mov  byte ptr [curtc],TCIDLE
        call SETTC
        mov  ah,48h
        call SBWR
        mov  ax,SNDN-1
        mov  ah,al
        call SBWR
        mov  ax,SNDN-1
        call SBWR
        mov  ah,1Ch
        call SBWR
        mov  ax,0013h           ; VGA 320x200, 256 colours
        int  10h
        call SETPAL

; ---- the main loop ---------------------------------------------------------
@@loop: call HEAL
        push es
        mov  ax,40h
        mov  es,ax
        mov  ax,es:[6Ch]        ; the stock 18.2 Hz heartbeat
        pop  es
        cmp  ax,[ltick]
        je   @@rend
        mov  [ltick],ax
        call TICK
@@rend: call RENDER
        call WAITVR
        push ds                 ; blit the frame
        mov  ax,0A000h
        mov  es,ax
        mov  ds,[bufseg]
        xor  si,si
        xor  di,di
        mov  cx,32000
        rep  movsw
        pop  ds
        mov  ah,1
        int  16h
        jz   @@loop
        xor  ah,ah
        int  16h
        cmp  al,27
        je   @@quit
        cmp  al,' '
        jne  @@loop
        mov  al,[state]
        or   al,al              ; idle -> fly
        jz   @@go
        cmp  al,5               ; ended -> fly again
        jne  @@loop
@@go:   mov  byte ptr [state],1
        mov  word ptr [ridx],0
        mov  word ptr [v16],0
        mov  word ptr [odo],0
        mov  word ptr [hrow],HORIZ0
        mov  word ptr [endcnt],0
        jmp  @@loop

@@quit: mov  ah,0D3h            ; speaker off, DSP reset stops the loop
        call SBWR
        mov  dx,226h
        mov  al,1
        out  dx,al
        in   al,dx
        in   al,dx
        xor  al,al
        out  dx,al
        in   al,21h             ; IRQ 7 back as we found it
        and  al,7Fh
        mov  ah,[sbmsk]
        and  ah,80h
        or   al,ah
        out  21h,al
        mov  ax,0003h
        int  10h
        mov  ax,4C00h
        int  21h

; ---- TICK: one 55 ms step of the performance -------------------------------
TICK:   inc  word ptr [tcnt]
        mov  al,[state]
        or   al,al
        jz   @@idle
        cmp  al,1
        je   @@spool
        ; ---- the note: on the ground it wavers WITH the shake (same ----
        ; speed curve - both die by ~110 kt); in the air, at a held
        ; throttle, a turbine sings ONE note - no waver at all
        cmp  byte ptr [state],2
        jne  @@air
        test word ptr [tcnt],1
        jnz  @@nowav
        mov  cx,[shamp]
        or   cx,cx
        jz   @@air
        call RND16
        mov  bx,cx
        add  bx,bx
        and  ax,bx
        sub  ax,cx              ; -amp..+amp around the top rate
        add  ax,TCFULL
        mov  [curtc],al
        call SETTC
        jmp  @@nowav
@@air:  cmp  byte ptr [curtc],TCFULL
        je   @@nowav
        mov  byte ptr [curtc],TCFULL
        call SETTC
@@nowav:
        mov  al,[state]
        cmp  al,2
        je   @@roll
        cmp  al,3
        je   @@rot
        cmp  al,4
        je   @@climb
        ret                     ; state 5: hold the end card
@@idle: ; ---- idle: a slow breath, one step every 8 ticks ----
        test word ptr [tcnt],7
        jnz  @@done
        call RND16
        and  ax,1
        add  al,TCIDLE
        mov  [curtc],al
        call SETTC
        ret
@@spool:; ---- the measured 2.5 s ramp; the world does not move yet ----
        mov  bx,[ridx]
        mov  al,[TCRAMP+bx]
        mov  [curtc],al
        call SETTC
        inc  bx
        mov  [ridx],bx
        cmp  bx,NRAMP
        jb   @@done
        mov  byte ptr [state],2 ; brake release
        ret
@@roll: ; ---- the ground roll: accelerate, odometer, seams, rotation ----
        call PHYS
        mov  ax,[v16]
        cmp  ax,VROT
        jb   @@done
        mov  byte ptr [state],3 ; ~170 kt: rotate
        ret
@@rot:  ; ---- rotation: the horizon falls out of the window ----
        call PHYS
        add  word ptr [hrow],5
        cmp  word ptr [hrow],HORIZ1
        jb   @@done
        mov  byte ptr [state],4
        ret
@@climb:; ---- a few seconds of clean climb, then the end card ----
        call PHYS
        inc  word ptr [endcnt]
        cmp  word ptr [endcnt],80
        jb   @@done
        mov  byte ptr [state],5
@@done: ret

; ---- PHYS: v += a(v), odometer += v, thump on every seam -------------------
; a decays with speed: 5 - v/1024 units of 1/16 m/s per tick, which is
; ~5.7 m/s2 at brake release and ~4.1 m/s2 at rotation - the measured
; fade. The odometer only ever needs (position mod 61 m).
PHYS:   mov  ax,[v16]
        mov  bx,ax
        mov  cl,9
        shr  bx,cl
        mov  cx,6               ; ~6.8 m/s2 decaying: 103 m/s in ~20 s,
        sub  cx,bx              ; the measured 19.3 s roll
        jg   @@acc
        mov  cx,1               ; never quite stops pulling
@@acc:  add  ax,cx
        mov  [v16],ax
        xor  dx,dx              ; odometer advance = v/18 (one tick of 18.2)
        mov  bx,18
        div  bx
        add  [odo],ax
        add  [odom],ax          ; the full odometer (tyre wear patches)
        add  [odoj],ax          ; the 15 m joint cycle
        cmp  word ptr [odoj],240
        jb   @@oj
        sub  word ptr [odoj],240
@@oj:   cmp  word ptr [odo],SEAM
        jb   @@ret
        sub  word ptr [odo],SEAM
        cmp  byte ptr [state],3 ; airborne: the seams fall silent
        jae  @@ret
        call THUMP
@@ret:  ret

; ---- THUMP: one concrete seam through the wheels ---------------------------
; A short square knock mixed ~60 ms ahead of the DMA beam. Loudness
; fades with speed and is GONE by ~110 kt: the tape's "feels airborne
; at 1:29" - ten seconds before the wheels actually leave.
THUMP:  mov  ax,900
        sub  ax,[v16]
        jle  @@ret
        mov  cl,4
        shr  ax,cl              ; amplitude 56..0
        mov  [bamp],ax
        push es
        mov  ax,[sndseg]
        mov  es,ax
        call SFXRAW
        lea  di,[bx+700]
        and  di,SNDN-1
        mov  dx,[bamp]          ; down into the ground...
        neg  dx
        mov  cx,20
@@d1:   call SFXMB
        loop @@d1
        mov  dx,[bamp]          ; ...and the bounce back
        shr  dx,1
        mov  cx,20
@@d2:   call SFXMB
        loop @@d2
        pop  es
@@ret:  ret

; ---- SETTC: program the DSP sample rate from [curtc] -----------------------
SETTC:  mov  ah,40h
        call SBWR
        mov  ah,[curtc]
        call SBWR
        ret

; ---- RENDER: sky, then the baked ground rows -------------------------------
RENDER: push es
        mov  ax,[bufseg]
        mov  es,ax
        ; ---- the sway: two slow triangle waves, NOT jitter - the tape ----
        ; rocks (~1 Hz, a touch faster with speed), it does not rattle
        mov  ax,[v16]
        mov  cl,10
        shr  ax,cl
        inc  ax                 ; phase speed 1..2
        add  [swph1],ax
        inc  word ptr [swph2]   ; the lateral wave beats against it
        mov  ax,[swph1]
        call TRI
        imul word ptr [shamp]
        mov  cl,4
        sar  ax,cl              ; -2..+2 rows of pitch bob
        mov  bx,[hrow]
        add  bx,ax
        cmp  bx,20              ; keep the horizon sane
        jge  @@h1
        mov  bx,20
@@h1:   cmp  bx,198
        jle  @@h2
        mov  bx,198
@@h2:   mov  [hcur],bx
        mov  ax,[swph2]
        call TRI
        imul word ptr [shamp]
        mov  cl,5
        sar  ax,cl              ; -1..+1 px of lateral drift
        add  ax,160
        mov  [cx0],ax
        ; ---- sky: rows 0..hcur-1, dithered vertical ramp ----
        xor  di,di
        xor  dx,dx              ; screen row
@@sky:  cmp  dx,[hcur]
        jae  @@skyd
        mov  bx,[hcur]          ; the ramp hangs from the horizon,
        dec  bx                 ; not from the screen top
        sub  bx,dx
        mov  al,[SBASE+bx]
        mov  [pbase],al
        mov  al,[SFRAC+bx]
        mov  [pfrac],al
        mov  ax,dx
        call MKPATT
        mov  [rowb],di
        mov  cx,320
        call DFILL
        ; ---- the clouds: two lumps anchored to the horizon ----
        mov  bx,[hcur]
        dec  bx
        sub  bx,dx              ; height above the horizon line
        cmp  bx,96
        jae  @@nocl
        mov  al,[C1W+bx]
        or   al,[C2W+bx]
        jz   @@nocl
        mov  ax,bx              ; the cloud's OWN vertical ramp - the
        add  ax,ax              ; old sky-fraction hack saturated and
        mov  cx,ax              ; drew a hard seam mid-cloud. Now:
        add  ax,ax              ; s = 40 + crow*6 across (10,11,12) -
        add  ax,cx              ; bluish base, soft white, sunlit top
        add  ax,40
        cmp  ax,511
        jbe  @@cb
        mov  ax,511
@@cb:   mov  [pfrac],al
        mov  al,ah
        add  al,10
        mov  [pbase],al
        mov  ax,dx
        call MKPATT
        mov  al,[C1W+bx]
        or   al,al
        jz   @@nc1
        push bx
        mov  di,[rowb]
        mov  bl,[C1S+bx]
        xor  bh,bh
        add  di,bx
        pop  bx
        mov  cl,[C1W+bx]
        xor  ch,ch
        call DFILL
@@nc1:  mov  al,[C2W+bx]
        or   al,al
        jz   @@nocl
        push bx
        mov  di,[rowb]
        mov  bl,[C2S+bx]
        xor  bh,bh
        add  di,bx
        pop  bx
        mov  cl,[C2W+bx]
        xor  ch,ch
        call DFILL
@@nocl: mov  di,[rowb]
        add  di,320
        inc  dx
        jmp  @@sky
@@skyd:
        ; ---- ground rows: grass, runway span, the stripe ----
        mov  si,1               ; y = row below the horizon
@@row:  mov  ax,[hcur]
        add  ax,si
        cmp  ax,200
        jae  @@rows_done
        dec  ax                 ; screen row = hcur + y - 1
        mov  [rowscr],ax
        mov  cx,320
        mul  cx
        mov  di,ax              ; row base
        mov  [rowb],ax
        mov  bx,si
        cmp  bx,NROWS           ; beyond the tables: reuse the deepest row
        jbe  @@t1
        mov  bx,NROWS
@@t1:   add  bx,bx              ; word index
        mov  al,1               ; grass across the row
        mov  ah,al
        mov  cx,160
        push di
        rep  stosw
        pop  di
        push di
        mov  al,byte ptr [CBASE+bx]  ; concrete: the dithered ramp
        mov  [pbase],al
        mov  al,byte ptr [CFRAC+bx]
        mov  [pfrac],al
        mov  ax,[rowscr]
        call MKPATT
        mov  dx,[EDGE+bx]       ; runway half-width in pixels
        add  di,[cx0]
        sub  di,dx
        mov  cx,dx
        add  cx,dx
        call DFILL
        pop  di
        push di
        add  di,[cx0]           ; the edge lines
        sub  di,dx
        mov  al,4
        mov  es:[di],al
        add  di,dx
        add  di,dx
        mov  es:[di],al
        pop  di
        mov  ax,[DMOD+bx]       ; stripe phase = (row distance + odometer)
        add  ax,[odo]
        cmp  ax,SEAM
        jb   @@ph
        sub  ax,SEAM
@@ph:   cmp  ax,PAINT           ; inside the painted 37 m?
        jae  @@nostripe
        mov  dx,[SW+bx]         ; stripe half-width
        add  di,[cx0]
        sub  di,dx
        mov  cx,dx
        add  cx,dx
        inc  cx
        mov  al,3               ; paint
        rep  stosb
@@nostripe:
        ; (expansion joints and tyre-wear lanes tried here strobed at
        ; speed - parked until they can be done right; the DJM/DFULL/
        ; NTAB bakes below stay for that day)
        inc  si
        jmp  @@row
@@rows_done:
        ; ---- the shake amplitude for the NEXT frame, from speed ----
        ; a triangle: grows to ~55 kt, gone by ~110 kt - the smooth zone
        cmp  byte ptr [state],3
        jb   @@shg
        mov  ax,1               ; airborne: a gentle residual bob
        jmp  @@sh0
@@shg:  mov  ax,[v16]
        mov  bx,880
        sub  bx,ax
        jg   @@sh1
        xor  ax,ax
        jmp  @@sh0
@@sh1:  cmp  ax,bx
        jbe  @@sh2
        mov  ax,bx
@@sh2:  mov  cl,220
        div  cl                 ; al = min(v,880-v)/220 -> 0..2
        xor  ah,ah
@@sh0:  mov  [shamp],ax
        ; ---- the cards ----
        cmp  byte ptr [state],0
        jne  @@c1
        mov  si,offset MTITLE
        mov  ax,180
        mov  bx,60
        call TXT
        jmp  @@cdone
@@c1:   cmp  byte ptr [state],5
        jne  @@cdone
        mov  si,offset MAGAIN
        mov  ax,180
        mov  bx,48
        call TXT
@@cdone:
        pop  es
        ret

; ---- TRI: AX phase -> a triangle wave, -16..+16 ----------------------------
TRI:    and  ax,63
        cmp  ax,32
        jb   @@a
        neg  ax
        add  ax,48              ; 32..63 -> 16..-15
        ret
@@a:    sub  ax,16              ; 0..31 -> -16..15
        ret

; ---- MKPATT: bake the 4-pixel dither pattern for one screen row ------------
; in: AX = screen row, [pbase]/[pfrac] = ramp shade and its fraction.
; The Bayer threshold lattice is fixed in SCREEN space - the tape's
; frame-diff proves the grid must stand still while the world slides
; through it; only threshold crossings flip.
MKPATT: push bx
        push si
        and  ax,3
        add  ax,ax
        add  ax,ax
        mov  si,ax              ; bayer row base
        xor  bx,bx
@@m:    mov  ah,[BAYER+si]      ; threshold, premultiplied 0..240
        mov  al,[pbase]
        cmp  [pfrac],ah
        jbe  @@m1
        inc  al                 ; the brighter neighbour shade
@@m1:   mov  [PATT+bx],al
        inc  si
        inc  bx
        cmp  bx,4
        jb   @@m
        pop  si
        pop  bx
        ret

; ---- DFILL: fill CX pixels at ES:DI with PATT, phased by screen x ----------
; A row is 320 wide = 0 mod 4, so DI & 3 IS the screen x phase.
DFILL:  push bx
        mov  bx,di
        and  bx,3
@@f:    mov  al,[PATT+bx]
        stosb
        inc  bx
        and  bx,3
        loop @@f
        pop  bx
        ret

; ---- BAKE: the per-row ground constants ------------------------------------
; Camera 3 m over the slab, the game lens FOCAL=220: a row y below the
; horizon sees the ground at d = 660/y metres. Baked as 1/16 m, plus
; d mod 61 m for the stripe phase, the runway half-width in pixels
; (23 m wide) and the stripe half-width - all constants per row.
BAKE:   mov  si,1
@@b:    mov  bx,si
        add  bx,bx
        mov  ax,24000           ; 1500 m * 16: the camera rides high so
        xor  dx,dx              ; the nearest visible slab is ~15 m out -
        div  si                 ; the nose hides everything closer
        mov  [DFULL+bx],ax
        xor  dx,dx
        mov  cx,SEAM
        div  cx
        mov  [DMOD+bx],dx       ; d16 mod 61 m
        mov  ax,[DFULL+bx]
        xor  dx,dx
        mov  cx,240
        div  cx
        mov  [DJM+bx],dx        ; d16 mod 15 m (the joints)
        mov  ax,si              ; edge half-width: 6.5 px per row - read
        mov  cx,13              ; off the user's ruler lines on the tape:
        mul  cx                 ; the edges leave the vanishing point
        mov  cx,2               ; SHALLOW, exit the screen sides within
        div  cx                 ; ~25 rows, and grass survives only as a
        cmp  ax,158             ; thin band under the horizon
        jbe  @@e1
        mov  ax,158
@@e1:   mov  [EDGE+bx],ax
        mov  ax,si              ; stripe half-width: y/8 + 1, scaled to
        mov  cx,8               ; the wide wedge (0.9 m of paint)
        xor  dx,dx
        div  cx
        inc  ax
        cmp  ax,14
        jbe  @@e2
        mov  ax,14
@@e2:   mov  [SW+bx],ax
        mov  ax,si              ; concrete shade: s16 = y*10 -
        mov  cx,10              ; far rows light haze, near rows dark
        mul  cx
        cmp  ah,3               ; clamp into the last blend pair
        jbe  @@c1
        mov  ah,3
        mov  al,255
@@c1:   mov  dl,ah
        add  dl,16              ; ramp starts at colour 16
        xor  dh,dh
        mov  [CBASE+bx],dx
        mov  dl,al
        xor  dh,dh
        mov  [CFRAC+bx],dx
        inc  si
        cmp  si,NROWS
        jbe  @@b
        xor  si,si              ; sky ramp, indexed by HEIGHT ABOVE THE
@@sk:   mov  ax,si              ; HORIZON: the haze rides the horizon
        add  ax,ax              ; down through the pull-up instead of
        add  ax,ax              ; flooding the screen bottom white.
        add  ax,si              ; t = crow*5; shade = 10 - t/256
        cmp  ah,4
        jb   @@s2
        mov  dl,6               ; high above: solid zenith
        xor  al,al
        jmp  @@s3
@@s2:   or   al,al
        jnz  @@s4
        mov  dl,10              ; exactly on a shade
        sub  dl,ah
        jmp  @@s3
@@s4:   mov  dl,9               ; between shades, counting DOWN, so the
        sub  dl,ah              ; blend fraction flips
        neg  al
@@s3:   mov  [SBASE+si],dl
        mov  [SFRAC+si],al
        inc  si
        cmp  si,200
        jb   @@sk
        xor  si,si              ; wear noise: a fenced random walk,
        mov  bx,128             ; smooth enough to read as patches
@@nt:   call RND16
        mov  al,ah
        xor  ah,ah
        and  ax,15
        sub  ax,7
        add  bx,ax
        cmp  bx,64
        jge  @@n1
        mov  bx,64
@@n1:   cmp  bx,192
        jle  @@n2
        mov  bx,192
@@n2:   mov  [NTAB+si],bl
        inc  si
        cmp  si,256
        jb   @@nt
        xor  si,si              ; the two clouds: width/start random
        xor  bx,bx              ; walks up from the horizon, tapering
        xor  bp,bp              ; at the top
        mov  dx,60
        mov  di,200
@@cl:   call RND16
        mov  al,ah
        xor  ah,ah
        and  ax,7
        sub  ax,2               ; widths tend to grow...
        add  bx,ax
        cmp  si,48              ; ...until the taper starts
        jb   @@t2
        sub  bx,3
@@t2:   cmp  bx,0
        jge  @@t3
        xor  bx,bx
@@t3:   cmp  bx,70
        jle  @@t4
        mov  bx,70
@@t4:   call RND16
        mov  al,ah
        xor  ah,ah
        and  ax,7
        sub  ax,2
        add  bp,ax
        cmp  si,40
        jb   @@t5
        sub  bp,2
@@t5:   cmp  bp,0
        jge  @@t6
        xor  bp,bp
@@t6:   cmp  bp,60
        jle  @@t7
        mov  bp,60
@@t7:   call RND16
        mov  al,ah
        xor  ah,ah
        and  ax,3
        dec  ax                 ; the starts drift -1..2
        add  dx,ax
        cmp  dx,10
        jge  @@t8
        mov  dx,10
@@t8:   cmp  dx,120
        jle  @@t9
        mov  dx,120
@@t9:   call RND16              ; cloud 2's edge wanders too - a fixed
        mov  al,ah              ; start reads as a wall, not a cloud
        xor  ah,ah
        and  ax,3
        dec  ax
        add  di,ax
        cmp  di,160
        jge  @@ta
        mov  di,160
@@ta:   cmp  di,250
        jle  @@tb
        mov  di,250
@@tb:   mov  [C1W+si],bl
        mov  ax,bp
        mov  [C2W+si],al
        mov  [C1S+si],dl
        mov  ax,di
        mov  [C2S+si],al
        inc  si
        cmp  si,96
        jb   @@cl
        ret

; ---- GENBED: the procedural turbine + the pristine copy --------------------
; Matched to the reference octave profile: the jet is a 125-500 Hz roar
; HUMP falling ~10 dB/octave above it, a sub rumble ~3 dB under the
; hump, and a whisper of blade whine. Four cascaded one-pole lowpasses
; (two ~440 Hz, two ~880) shape LCG noise into the hump; a leaky
; brownian walk is the sub; the final neighbour average is the cockpit
; muffle. Noise takes the LCG HIGH byte (the low bits ring - TERRA).
; The top half of the segment keeps the clean copy for the heal pass -
; seam thumps erase themselves after playing.
GENBED: push es
        cld
        mov  ax,[sndseg]
        mov  es,ax
        xor  di,di
        xor  si,si              ; whine phase 0..5
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
        cmp  word ptr [warmc],0 ; warm-up: run the filters to steady
        je   @@st               ; state before the first sample lands -
        dec  word ptr [warmc]   ; a cold start made the loop's head
        jmp  @@wh               ; sound different from its tail: the
@@st:   stosb                   ; once-per-loop "wave"
@@wh:   inc  si
        cmp  si,6
        jb   @@g4
        xor  si,si
@@g4:   cmp  di,SNDN
        jb   @@g
        xor  si,si              ; and splice the seam: the last 512
@@xf:   mov  di,si              ; samples fade into the first 512
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
        push ds                 ; pristine copy: ring 0..7FFF -> 8000..FFFF
        mov  ax,es
        mov  ds,ax
        xor  si,si
        mov  cx,SNDN/2
        rep  movsw
        pop  ds
        pop  es
        ret

; ---- HEAL: restore the ring behind the beam from the pristine copy ---------
HEAL:   call SFXRAW             ; BX = beam position (needs no ES)
        mov  ax,bx
        sub  ax,64
        and  ax,SNDN-1
        mov  cx,ax
        sub  cx,[sbrst]
        and  cx,SNDN-1
        cmp  cx,4096
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
        add  si,SNDN
        movsb
        and  di,SNDN-1
        loop @@hc
        pop  es
        pop  ds
@@hr:   ret

; ---- TXT: ASCIIZ at SI -> back buffer at (BX,AX), amber --------------------
; Glyphs straight from the PC's ROM font at F000:FA6E, as everywhere.
TXT:    push es
        push dx
        mov  cx,ax
        mov  ax,[bufseg]
        mov  es,ax
        mov  ax,cx
        mov  cx,320
        mul  cx
        add  ax,bx
        mov  di,ax
@@ch:   lodsb
        or   al,al
        jz   @@fin
        push si
        xor  ah,ah
        mov  cl,3
        shl  ax,cl
        mov  si,0FA6Eh
        add  si,ax
        push ds
        mov  ax,0F000h
        mov  ds,ax
        mov  cx,8
        push di
@@rw:   lodsb
        mov  ah,al
        push cx
        mov  cx,8
@@px:   shl  ah,1
        jnc  @@np
        mov  al,5
        mov  es:[di],al
@@np:   inc  di
        loop @@px
        add  di,320-8
        pop  cx
        loop @@rw
        pop  di
        pop  ds
        pop  si
        add  di,8
        jmp  @@ch
@@fin:  pop  dx
        pop  es
        ret

; ---- wait for the vertical retrace edge ------------------------------------
WAITVR: mov  dx,3DAh
@@w1:   in   al,dx
        test al,8
        jnz  @@w1
@@w2:   in   al,dx
        test al,8
        jz   @@w2
        ret

; ---- the few DAC entries this cartoon wears --------------------------------
SETPAL: mov  si,offset PAL
@@p:    lodsb
        cmp  al,255
        je   @@fin
        mov  dx,3C8h
        out  dx,al
        inc  dx
        lodsb
        out  dx,al
        lodsb
        out  dx,al
        lodsb
        out  dx,al
        jmp  @@p
@@fin:  ret
; The gradient-grid lesson from the quantized tape: flat surfaces are a
; screen-fixed 4x4 Bayer checker MIXING two NEIGHBOURING ramp shades,
; and the neighbours deliberately lean warm/cool in turn - the mix
; shimmers alive as the iso-brightness bands crawl through the static
; lattice. (Frame-diff proof: the checker never scrolls with the world;
; only pixels whose value crossed a threshold flip.)
PAL     db   1, 10,26, 8        ; grass
        db   3, 58,58,58        ; the painted stripe
        db   4, 46,46,44        ; edge lines
        db   5, 63,42,10        ; amber cards
        db   6, 12,22,42        ; sky ramp: zenith deep...
        db   7, 15,26,48
        db   8, 18,30,53
        db   9, 22,35,58
        db  10, 27,41,62        ; ...the haze over the horizon
        db  11, 46,50,60        ; cloud ramp: soft blue-white base...
        db  12, 58,59,63        ; ...and the sunlit top (clouds only)
        db  16, 47,46,48        ; concrete ramp: far haze (warm)
        db  17, 43,43,47        ; (cool)
        db  18, 40,39,41        ; (warm)
        db  19, 36,36,41        ; (cool)
        db  20, 32,32,34        ; near slab
        db 255

; ---- data ------------------------------------------------------------------
NOSB    db 'No Sound Blaster at 220h.',13,10,'$'
MTITLE  db 'TKOFF - SPACE',0
MAGAIN  db 'LIFTOFF 1:39 - SPACE AGAIN',0
; The spool ramp: smoothstep, 46 ticks = 2.5 s - the shape and length
; of the spool line measured on the reference spectrogram.
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
bufseg  dw 0                    ; back buffer segment
sndseg  dw 0                    ; ring segment (64K-aligned)
sbrst   dw 0                    ; heal cursor
sbmsk   db 0                    ; saved IRQ 7 mask bit
state   db 0                    ; 0 idle 1 spool 2 roll 3 rotate 4 climb 5 end
ridx    dw 0                    ; spool ramp position
curtc   db TCIDLE               ; current DSP time constant
ltick   dw 0                    ; last BIOS tick seen
tcnt    dw 0                    ; tick counter (waver / breath phases)
v16     dw 0                    ; speed, 1/16 m/s
odo     dw 0                    ; odometer mod 61 m, 1/16 m
odom    dw 0                    ; full odometer, 1/16 m (wraps at 4 km)
odoj    dw 0                    ; odometer mod 15 m (the joint cycle)
swph1   dw 0                    ; sway phase, pitch bob
swph2   dw 21                   ; sway phase, lateral (offset: they beat)
cx0     dw 160                  ; runway centre column, swaying
rowb    dw 0                    ; current row base offset
hrow    dw HORIZ0               ; horizon row (rises through rotation)
hcur    dw HORIZ0               ; horizon row as drawn (with the shake)
shamp   dw 0                    ; shake amplitude, rows
bamp    dw 0                    ; current seam thump amplitude
endcnt  dw 0                    ; climb frames before the end card
rowscr  dw 0                    ; current screen row (dither phase)
pbase   db 0                    ; dither: ramp shade in play
pfrac   db 0                    ; dither: its fraction 0..255
PATT    db 4 dup(0)             ; the row's 4-pixel pattern
BAYER   db   0,128, 32,160      ; 4x4 ordered matrix, premultiplied x16
        db 192, 64,224, 96
        db  48,176, 16,144
        db 240,112,208, 80
DMOD    dw NROWS+1 dup(0)       ; per-row: ground distance mod 61 m (1/16 m)
EDGE    dw NROWS+1 dup(0)       ; per-row: runway half-width, pixels
SW      dw NROWS+1 dup(0)       ; per-row: stripe half-width, pixels
CBASE   dw NROWS+1 dup(0)       ; per-row: concrete ramp shade
CFRAC   dw NROWS+1 dup(0)       ; per-row: concrete blend fraction
DFULL   dw NROWS+1 dup(0)       ; per-row: full ground distance, 1/16 m
DJM     dw NROWS+1 dup(0)       ; per-row: distance mod 15 m (joints)
SBASE   db 200 dup(0)           ; per-screen-row: sky ramp shade
SFRAC   db 200 dup(0)           ; per-screen-row: sky blend fraction
NTAB    db 256 dup(0)           ; smooth wear noise (tyre patches)
C1W     db 96 dup(0)            ; cloud 1: width per row above horizon
C1S     db 96 dup(0)            ; cloud 1: start column
C2W     db 96 dup(0)            ; cloud 2: width
C2S     db 96 dup(0)            ; cloud 2: start column

        INCLUDE ..\ENGINE\E_MATH.INC
        INCLUDE ..\ENGINE\E_SND.INC

CODE    ENDS
        END START
