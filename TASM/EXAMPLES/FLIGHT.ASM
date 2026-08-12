; ============================================================================
;  FLIGHT.COM - WIRE CITY engine example 08: the airshow
;
;  TKOFF's sequel: the same measured takeoff (FlightRef takeoff/v1),
;  and then the cartoon keeps flying - level-off, a full aileron roll,
;  and a hard pull into pure sky. Still no controls, still a scripted
;  keyframe performance: the maneuver program is a little table of
;  (ticks, roll rate, pitch rate) segments at the bottom of this file.
;
;  What is NEW over TKOFF is the tilted horizon. The trick stays cheap:
;  the horizon is a LINE, f(x,y) = (y-H)*cos r + (x-160)*sin r, and
;  every screen row is split by it into one sky span and one ground
;  span - two dithered fills per row, no 3D anywhere. The sky haze and
;  the grass shading are indexed by |f|, the PERPENDICULAR distance to
;  the horizon, so the gradients rotate with the world; when the roll
;  passes inverted, cos r flips sign and the ground hangs from the top
;  of the screen all by itself.
;
;  Sound: the tuned turbine ring. One steady note in the air, a +2 TC
;  strain lean while a maneuver is loading the airframe, the measured
;  spool and shake-waver on the ground - all from TKOFF.
;
;  SPACE flies, ESC quits. Sound Blaster at 220h, DMA 1 (DOSBox: yes).
; ============================================================================
SNDN    equ 8000h               ; ring length; must precede the code
TCIDLE  equ 75                  ; DSP time constant at idle  (~5512 Hz)
TCFULL  equ 165                 ; DSP time constant at power (~11025 Hz)
NRAMP   equ 46                  ; spool steps = ticks; 46/18.2 = 2.5 s
HORIZ0  equ 100                 ; horizon row, wheels on the ground
HORIZ1  equ 185                 ; horizon row, nose up - end of rotation
VROT    equ 1650                ; rotation speed, 1/16 m/s (103 m/s -
                                ; the measured hold-down takeoff)
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
        mov  ax,cs              ; ring: the next 64K-aligned segment
        add  ax,3FFFh
        and  ax,0F000h
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
        cmp  al,6               ; show over -> fly again
        jne  @@loop
@@go:   mov  byte ptr [state],1
        mov  word ptr [ridx],0
        mov  word ptr [v16],0
        mov  word ptr [odo],0
        mov  word ptr [hrow],HORIZ0
        mov  word ptr [endcnt],0
        mov  word ptr [roll],0
        mov  word ptr [mptr],0
        mov  word ptr [mleft],0
        mov  word ptr [mrr],0
        mov  word ptr [mpr],0
        mov  word ptr [mstrain],0
        mov  word ptr [alt16],0
        mov  word ptr [sinr],0
        mov  word ptr [cosr],256
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
        ; ---- the note: on the ground it wavers WITH the shake; in the ----
        ; air it holds ONE tone, leaning +2 only while a maneuver loads
        ; the airframe
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
@@air:  mov  ax,TCFULL
        add  ax,[mstrain]
        cmp  [curtc],al
        je   @@nowav
        mov  [curtc],al
        call SETTC
@@nowav:
        mov  al,[state]
        cmp  al,2
        je   @@grnd
        cmp  al,3
        je   @@rot
        cmp  al,4
        je   @@climb
        cmp  al,5
        je   @@man
        ret                     ; state 6: hold the end card
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
@@grnd: ; ---- the ground roll: accelerate, odometer, seams, rotation ----
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
@@climb:; ---- a short clean climb, then the show begins ----
        call PHYS
        inc  word ptr [endcnt]
        cmp  word ptr [endcnt],40
        jb   @@done
        mov  byte ptr [state],5
        ret
@@man:  ; ---- the airshow: walk the maneuver script ----
        call PHYS
        cmp  word ptr [mleft],0
        jne  @@mgo
        mov  bx,[mptr]          ; load the next segment
        mov  ax,[MSCRIPT+bx]
        or   ax,ax
        jnz  @@ml
        mov  byte ptr [state],6 ; the show is over
        mov  word ptr [mrr],0
        mov  word ptr [mpr],0
        mov  word ptr [mstrain],0
        ret
@@ml:   mov  [mleft],ax
        mov  ax,[MSCRIPT+bx+2]
        mov  [mrr],ax
        mov  ax,[MSCRIPT+bx+4]
        mov  [mpr],ax
        add  bx,6
        mov  [mptr],bx
@@mgo:  mov  ax,[mrr]
        add  [roll],ax
        and  word ptr [roll],255
        mov  ax,[mpr]
        add  [hrow],ax
        dec  word ptr [mleft]
        mov  ax,[mrr]           ; strain lean while anything moves
        or   ax,[mpr]
        jz   @@mq
        mov  word ptr [mstrain],2
        ret
@@mq:   mov  word ptr [mstrain],0
@@done: ret

; ---- PHYS: v += a(v), odometer += v, thump on every seam -------------------
PHYS:   mov  ax,[v16]
        mov  bx,ax
        mov  cl,9
        shr  bx,cl
        mov  cx,6               ; the measured 19.3 s hold-down roll
        sub  cx,bx
        jg   @@acc
        mov  cx,1               ; never quite stops pulling
@@acc:  add  ax,cx
        cmp  ax,1750            ; cruise cap (above VROT!)
        jbe  @@vc
        mov  ax,1750
@@vc:   mov  [v16],ax
        cmp  byte ptr [state],3 ; airborne: integrate the altitude -
        jb   @@noal             ; climb rate ~ v * pitch (rows/FOCAL)
        mov  ax,[hrow]
        sub  ax,HORIZ0
        jle  @@noal
        imul word ptr [v16]
        mov  bx,3960            ; FOCAL 220 * 18 ticks
        idiv bx
        add  [alt16],ax
@@noal: mov  ax,[v16]
        xor  dx,dx              ; odometer advance = v/18 (one tick)
        mov  bx,18
        div  bx
        add  [odo],ax
        cmp  word ptr [odo],SEAM
        jb   @@ret
        sub  word ptr [odo],SEAM
        cmp  byte ptr [state],3 ; airborne: the seams fall silent
        jae  @@ret
        call THUMP
@@ret:  ret

; ---- THUMP: one concrete seam through the wheels ---------------------------
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

; ---- RENDER: ground phase = TKOFF's runway; airshow = tilted horizon -------
RENDER: cmp  byte ptr [state],5
        jae  MREND
        push es
        mov  ax,[bufseg]
        mov  es,ax
        ; ---- the sway: two slow triangle waves, NOT jitter ----
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
        ; ---- sky: rows 0..hcur-1, ramp hanging from the horizon ----
        xor  di,di
        xor  dx,dx              ; screen row
@@sky:  cmp  dx,[hcur]
        jae  @@skyd
        mov  bx,[hcur]
        dec  bx
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
        mov  ax,bx              ; cloud's own vertical ramp: bluish
        add  ax,ax              ; base, soft white, sunlit top
        mov  cx,ax
        add  ax,ax
        add  ax,cx
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
        mov  ax,[DMOD+bx]       ; stripe phase = distance + odometer
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
        inc  si
        jmp  @@row
@@rows_done:
        ; ---- the shake amplitude for the NEXT frame, from speed ----
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
        call HUD
        ; ---- the card ----
        cmp  byte ptr [state],0
        jne  @@cdone
        mov  byte ptr [tcol],5
        mov  si,offset MTITLE
        mov  ax,180
        mov  bx,56
        call TXT
@@cdone:
        pop  es
        ret

; ---- MREND: the airshow renderer - the horizon is a tilted LINE ------------
; f(x,y) = (y-H)*cos r + (x-160)*sin r splits every row into one sky
; span and one ground span; |f| is the perpendicular distance to the
; horizon and indexes the same haze/grass ramps, so the gradients
; ROTATE with the world. Inverted flight needs no special case: cos r
; goes negative and the ground hangs from the top on its own.
MREND:  push es
        mov  ax,[bufseg]
        mov  es,ax
        inc  word ptr [swph1]   ; the gentle flight bob
        mov  ax,[swph1]
        call TRI
        mov  cl,4
        sar  ax,cl              ; -1..+1 rows
        add  ax,[hrow]
        mov  [hcur],ax
        mov  al,byte ptr [roll]
        xor  ah,ah
        call TSIN
        mov  [sinr],ax
        mov  al,byte ptr [roll]
        add  al,64
        xor  ah,ah
        call TSIN
        mov  [cosr],ax
        mov  word ptr [mrow],0
        mov  word ptr [rowb],0
@@mr:   mov  ax,[mrow]
        sub  ax,[hcur]
        imul word ptr [cosr]
        mov  bx,256
        idiv bx
        mov  [fmv],ax           ; f at the row's centre column
        mov  bx,[sinr]
        or   bx,bx
        jge  @@ab
        neg  bx
@@ab:   cmp  bx,8               ; wings level: one span per row
        jae  @@split
        mov  word ptr [spa],0
        mov  word ptr [spl],320
        mov  al,0
        cmp  word ptr [fmv],0
        jl   @@ws
        mov  al,1
@@ws:   mov  [sptype],al
        call FSP
        jmp  @@nr
@@split:mov  ax,[fmv]           ; x0 = 160 - f*256/sin r
        mov  cx,256
        imul cx
        idiv word ptr [sinr]
        mov  bx,160
        sub  bx,ax
        cmp  bx,0
        jge  @@x1
        xor  bx,bx
@@x1:   cmp  bx,320
        jle  @@x2
        mov  bx,320
@@x2:   cmp  word ptr [sinr],0
        jl   @@neg
        mov  word ptr [spa],0   ; sky left of the line, ground right
        mov  [spl],bx
        mov  byte ptr [sptype],0
        push bx
        call FSP
        pop  bx
        mov  [spa],bx
        mov  ax,320
        sub  ax,bx
        mov  [spl],ax
        mov  byte ptr [sptype],1
        call FSP
        jmp  @@nr
@@neg:  mov  word ptr [spa],0   ; ground left, sky right
        mov  [spl],bx
        mov  byte ptr [sptype],1
        push bx
        call FSP
        pop  bx
        mov  [spa],bx
        mov  ax,320
        sub  ax,bx
        mov  [spl],ax
        mov  byte ptr [sptype],0
        call FSP
@@nr:   add  word ptr [rowb],320
        inc  word ptr [mrow]
        cmp  word ptr [mrow],200
        jb   @@mr
        ; ---- clouds return whenever the wings are level and upright ----
        cmp  word ptr [cosr],0
        jle  @@mcard
        mov  ax,[sinr]
        or   ax,ax
        jge  @@a2
        neg  ax
@@a2:   cmp  ax,8
        jae  @@mcard
        mov  ax,[hcur]
        cmp  ax,21
        jl   @@mcard
        cmp  ax,198
        jg   @@mcard
        call CLPASS
@@mcard:call HUD
        cmp  byte ptr [state],6
        jne  @@md
        mov  byte ptr [tcol],5
        mov  si,offset MAGAIN
        mov  ax,180
        mov  bx,56
        call TXT
@@md:   pop  es
        ret

; ---- FSP: fill span [spa..spa+spl) of row [mrow] as sky or ground ----------
; The ramp index is |f| at the span's CENTRE - one shade per span, the
; retro compromise (a row is never split twice).
FSP:    cmp  word ptr [spl],0
        jle  @@fr
        mov  ax,[spl]
        shr  ax,1
        add  ax,[spa]
        sub  ax,160
        imul word ptr [sinr]
        mov  bx,256
        idiv bx
        add  ax,[fmv]           ; f at the span centre
        or   ax,ax
        jge  @@f1
        neg  ax
@@f1:   cmp  ax,199
        jbe  @@f2
        mov  ax,199
@@f2:   mov  bx,ax
        cmp  byte ptr [sptype],0
        jne  @@fg
        mov  al,[SBASE+bx]      ; sky: the haze ramp
        mov  [pbase],al
        mov  al,[SFRAC+bx]
        mov  [pfrac],al
        jmp  @@fp
@@fg:   mov  byte ptr [pbase],13 ; grass: haze green -> deep green
        mov  ax,bx
        add  ax,ax
        cmp  ax,255
        jbe  @@f3
        mov  ax,255
@@f3:   mov  [pfrac],al
@@fp:   mov  ax,[mrow]
        call MKPATT
        mov  di,[rowb]
        add  di,[spa]
        mov  cx,[spl]
        call DFILL
@@fr:   ret

; ---- CLPASS: the two clouds, over the level-flight sky ---------------------
CLPASS: xor  dx,dx              ; crow = height above the horizon
@@c:    cmp  dx,96
        jae  @@cd
        mov  bx,dx
        mov  al,[C1W+bx]
        or   al,[C2W+bx]
        jz   @@cn
        mov  ax,[hcur]
        dec  ax
        sub  ax,dx              ; screen row
        jl   @@cd
        mov  [rowscr],ax
        push dx
        mov  cx,320
        mul  cx
        mov  [rowb],ax
        pop  dx
        mov  ax,dx              ; cloud ramp: s = 40 + crow*6
        add  ax,ax
        mov  cx,ax
        add  ax,ax
        add  ax,cx
        add  ax,40
        cmp  ax,511
        jbe  @@cc
        mov  ax,511
@@cc:   mov  [pfrac],al
        mov  al,ah
        add  al,10
        mov  [pbase],al
        mov  ax,[rowscr]
        call MKPATT
        mov  bx,dx
        mov  al,[C1W+bx]
        or   al,al
        jz   @@c2
        mov  di,[rowb]
        push bx
        mov  bl,[C1S+bx]
        xor  bh,bh
        add  di,bx
        pop  bx
        mov  cl,[C1W+bx]
        xor  ch,ch
        call DFILL
@@c2:   mov  al,[C2W+bx]
        or   al,al
        jz   @@cn
        mov  di,[rowb]
        push bx
        mov  bl,[C2S+bx]
        xor  bh,bh
        add  di,bx
        pop  bx
        mov  cl,[C2W+bx]
        xor  ch,ch
        call DFILL
@@cn:   inc  dx
        jmp  @@c
@@cd:   ret

; ---- HUD: the 1990 standard, metric -----------------------------------------
; Modelled on the F-15 SE II frame the user supplied: MOVING tapes with
; two tick weights - a big labelled tick every 50 km/h (speed, left) /
; every 500 m (altitude, right, labels go 500, 1K, 1K5... past the
; thousand), a small tick halfway; the current value sits at the fixed
; centre with a pointer dash. Up top the heading ruler: labels every
; 45 deg, heavy tick each 15, light each 5, the caret, and the CYAN
; mark = bearing to the runway (000 for now - the show flies straight).
; Labels wear OWLFLY's 4x6 font (resource 1 of CITY.DAT, embedded).
; Plus the waterline datum and the world-riding pitch ladder (LADR).
; Caller has ES = the back buffer.
HUD:    ; ==== speed tape, left: 1 px = 1 km/h ====
        mov  ax,[v16]
        mov  cx,9
        mul  cx
        mov  cx,40
        div  cx
        mov  [kmh],ax           ; (no spine line - the tape is ticks
        mov  ax,[kmh]           ; and labels only, as on the F-15)
        sub  ax,80              ; first tick: round v-80 up to 20 -
        jns  @@s0               ; the user's ruler: a labelled tick per
        xor  ax,ax              ; HUNDRED, four small ones between, at
@@s0:   add  ax,19              ; 2 km/h per pixel
        xor  dx,dx
        mov  cx,20
        div  cx
        mul  cx
        mov  [tm],ax
@@sl:   mov  ax,[tm]
        mov  bx,[kmh]
        add  bx,80
        cmp  ax,bx
        jg   @@sdone
        mov  bx,[kmh]           ; y = 100 - (m - v)/2: faster is higher
        sub  bx,ax
        sar  bx,1
        add  bx,100
        mov  [ty],bx
        cmp  bx,61
        jl   @@snext
        cmp  bx,139
        jg   @@snext
        mov  ax,[tm]            ; big tick when m mod 100 = 0
        xor  dx,dx
        mov  cx,100
        div  cx
        or   dx,dx
        jnz  @@smin
        mov  ax,[ty]
        call ROWAD
        add  ax,38
        mov  di,ax
        mov  cx,9
@@st1:  mov  byte ptr es:[di],15
        inc  di
        loop @@st1
        mov  ax,[tm]            ; the label
        call NUM
        mov  si,offset NBUF+2
        mov  ax,[ty]
        sub  ax,2
        mov  bx,22
        call FDR
        jmp  @@snext
@@smin: mov  ax,[ty]
        call ROWAD
        add  ax,42
        mov  di,ax
        mov  cx,5
@@st2:  mov  byte ptr es:[di],15
        inc  di
        loop @@st2
@@snext:add  word ptr [tm],20
        jmp  @@sl
@@sdone:mov  di,100*320+48      ; the pointer dash, inside the scale...
        mov  cx,8
@@sd:   mov  byte ptr es:[di],15
        inc  di
        loop @@sd
        mov  ax,[kmh]           ; ...and the current value rides just
        call NUM                ; behind it
        mov  si,offset NBUF+2
        mov  ax,97
        mov  bx,58
        call FDR
        ; ==== altitude tape, right: 1 px = 10 m ====
        mov  ax,[alt16]
        mov  cl,4
        shr  ax,cl
        mov  [alm],ax           ; (ticks and labels only, no spine)
        mov  ax,[alm]           ; first tick: round a-400 up to 100
        sub  ax,400
        jns  @@a0
        xor  ax,ax
@@a0:   add  ax,99
        xor  dx,dx
        mov  cx,100
        div  cx
        mul  cx
        mov  [tm],ax
@@al:   mov  ax,[tm]
        mov  bx,[alm]
        add  bx,400
        cmp  ax,bx
        jg   @@adone
        mov  bx,[alm]           ; y = 100 - (m - a)/10
        sub  bx,ax
        mov  ax,bx
        cwd
        mov  bx,10
        idiv bx
        add  ax,100
        mov  [ty],ax
        cmp  ax,61
        jl   @@anext
        cmp  ax,139
        jg   @@anext
        mov  ax,[tm]            ; big tick when m/100 is a fifth
        xor  dx,dx
        mov  cx,100
        div  cx
        xor  dx,dx
        mov  cx,5
        div  cx
        or   dx,dx
        jnz  @@amin
        mov  ax,[ty]
        call ROWAD
        add  ax,273
        mov  di,ax
        mov  cx,9
@@at1:  mov  byte ptr es:[di],15
        inc  di
        loop @@at1
        mov  ax,[tm]            ; the label: metres, or NK / NK5 past 1000
        cmp  ax,1000
        jae  @@kfmt
        call NUM
        mov  si,offset NBUF+2
        jmp  @@ldr
@@kfmt: xor  dx,dx
        mov  cx,1000
        div  cx
        add  al,'0'
        mov  [ABUF],al
        mov  byte ptr [ABUF+1],'K'
        mov  ax,dx
        xor  dx,dx
        mov  cx,100
        div  cx
        or   al,al
        jz   @@k0
        add  al,'0'
        mov  [ABUF+2],al
        mov  byte ptr [ABUF+3],0
        jmp  @@k1
@@k0:   mov  byte ptr [ABUF+2],0
@@k1:   mov  si,offset ABUF
@@ldr:  mov  ax,[ty]
        sub  ax,2
        mov  bx,284
        call FDR
        jmp  @@anext
@@amin: mov  ax,[ty]
        call ROWAD
        add  ax,273
        mov  di,ax
        mov  cx,5
@@at2:  mov  byte ptr es:[di],15
        inc  di
        loop @@at2
@@anext:add  word ptr [tm],100
        jmp  @@al
@@adone:mov  ax,[alm]           ; current value + pointer dash, inside
        call NUM
        mov  si,offset NBUF+1
        mov  ax,97
        mov  bx,246
        call FDR
        mov  di,100*320+264
        mov  cx,8
@@ad:   mov  byte ptr es:[di],15
        inc  di
        loop @@ad
        ; ==== heading ruler, top: labels /45, bar /15, dot /5 - the ====
        ; F-15's .|.|.|. pattern, no solid line
        mov  word ptr [tm],-10  ; tick counter, 5 deg each
@@ct:   mov  ax,[tm]
        cmp  ax,10
        jg   @@ctd
        mov  bx,ax              ; x = 160 + 5*t
        add  ax,ax
        add  ax,ax
        add  ax,bx
        add  ax,160
        mov  [ty],ax            ; (borrow ty as the x)
        mov  cx,[tm]            ; heavy when t mod 3 = 0
        add  cx,12
@@m3:   cmp  cx,3
        jb   @@m3d
        sub  cx,3
        jmp  @@m3
@@m3d:  jcxz @@big
        mov  ax,12              ; light: a single dot
        call ROWAD
        add  ax,[ty]
        mov  di,ax
        mov  byte ptr es:[di],15
        jmp  @@ctn
@@big:  mov  ax,9               ; heavy: y 9..15
        call ROWAD
        add  ax,[ty]
        mov  di,ax
        mov  cx,7
@@ct1:  mov  byte ptr es:[di],15
        add  di,320
        loop @@ct1
@@ctn:  inc  word ptr [tm]
        jmp  @@ct
@@ctd:  mov  si,offset C315     ; the 45-deg labels
        mov  ax,2
        mov  bx,109
        call FDR
        mov  si,offset C000
        mov  ax,2
        mov  bx,154
        call FDR
        mov  si,offset C045
        mov  ax,2
        mov  bx,199
        call FDR
        mov  byte ptr es:[17*320+160],15   ; the caret
        mov  byte ptr es:[18*320+159],15
        mov  byte ptr es:[18*320+161],15
        mov  di,20*320+159      ; CYAN: bearing to the runway (000)
        mov  cx,3
@@cy:   mov  byte ptr es:[di],21
        mov  byte ptr es:[di+320],21
        inc  di
        loop @@cy
        ; ==== the waterline datum: -v- fixed at (160,100) ====
        mov  di,100*320+150
        mov  cx,7
@@wl1:  mov  byte ptr es:[di],15
        inc  di
        loop @@wl1
        mov  di,100*320+164
        mov  cx,7
@@wl2:  mov  byte ptr es:[di],15
        inc  di
        loop @@wl2
        mov  byte ptr es:[101*320+159],15
        mov  byte ptr es:[101*320+161],15
        mov  byte ptr es:[102*320+160],15
        call LADR
        ret

; ---- ROWAD: AX = screen row -> AX = row * 320 ------------------------------
ROWAD:  push bx
        push cx
        mov  bx,ax
        mov  cl,8
        shl  ax,cl              ; y*256
        mov  cl,6
        shl  bx,cl              ; y*64
        add  ax,bx
        pop  cx
        pop  bx
        ret

; ---- FDR: OWLFLY's 4x6 font - digits, K, space - at row AX col BX ----------
; SI = ASCIIZ, ES = back buffer, colour 15. Advances 4 px per glyph.
FDR:    push dx
        call ROWAD
        add  ax,bx
        mov  di,ax
@@c:    lodsb
        or   al,al
        jz   @@done
        cmp  al,' '
        jne  @@g
        add  di,4
        jmp  @@c
@@g:    cmp  al,'K'
        jne  @@d
        mov  al,10
        jmp  @@i
@@d:    sub  al,'0'
@@i:    xor  ah,ah
        add  ax,ax              ; glyph offset = idx*6 = idx*2 + idx*4
        mov  bx,ax
        add  ax,ax
        add  bx,ax
        push si
        push di
        mov  si,offset HFONT
        add  si,bx
        mov  cx,6
@@r:    lodsb
        mov  ah,al
        push cx
        mov  cx,3
@@p:    shl  ah,1
        jnc  @@n
        mov  byte ptr es:[di],15
@@n:    inc  di
        loop @@p
        add  di,320-3
        pop  cx
        loop @@r
        pop  di
        pop  si
        add  di,4
        jmp  @@c
@@done: pop  dx
        ret

; ---- LADR: the pitch ladder - dashes parallel to the WORLD horizon ---------
; Every 5 degrees out to +/-50 (19 rows per 5 deg at FOCAL 220): the
; ladder's real job is the SHARP maneuver, when the horizon itself has
; left the window and these lines are all the pilot has. Solid above
; the horizon, DASHED below - the instant which-way-is-the-earth cue.
; Each line's centre is projected in screen space with 32-bit math
; (50 deg of offset overflows 8.8), then the dashes step 8.8 from it.
; And the pilot's rule the user set: while the REAL horizon is in the
; window, the ladder stays OUT of it - it lights up only when the
; horizon has left the screen.
LADR:   mov  ax,100             ; horizon distance from screen centre:
        sub  ax,[hcur]          ; f(160,100) = (100-H)*cos r / 256
        imul word ptr [cosr]
        mov  bx,256
        idiv bx
        mov  [fcv],ax
        or   ax,ax
        jge  @@abs
        neg  ax
@@abs:  cmp  ax,110             ; horizon still in view: no ladder
        jg   @@on
        ret
@@on:   mov  ax,[fcv]           ; FOUR lines are enough: the ones
        cwd                     ; nearest the nose - k0 = -fc/19,
        mov  bx,19              ; then k0-1 .. k0+2
        idiv bx
        neg  ax
        mov  bx,ax
        dec  ax
        mov  [lk],ax
        add  bx,2
        mov  [lke],bx
@@lk:   mov  ax,[lk]
        cmp  ax,[lke]
        jg   @@ret
        cmp  word ptr [lk],0
        je   @@nx               ; zero IS the world horizon
        mov  ax,[lk]
        mov  cx,-19
        imul cx
        mov  [ld],ax            ; perpendicular offset, rows
        imul word ptr [sinr]    ; line centre, screen coords
        mov  bx,256
        idiv bx
        add  ax,160
        mov  [lcx],ax
        mov  ax,[ld]
        imul word ptr [cosr]
        mov  bx,256
        idiv bx
        add  ax,[hcur]
        mov  [lcy],ax
        cmp  ax,-40             ; whole line far off screen: skip it
        jl   @@nx
        cmp  ax,240
        jg   @@nx
        mov  ax,[cosr]          ; start at t = -36 along the line
        mov  cx,-36
        imul cx
        mov  [lx8],ax
        mov  ax,[sinr]
        mov  cx,36
        imul cx
        mov  [ly8],ax
        mov  word ptr [li],0
@@pt:   mov  ax,[li]
        cmp  ax,9
        jb   @@vis
        cmp  ax,16
        jb   @@skip             ; the centre gap
@@vis:  cmp  word ptr [lk],0    ; below the horizon: dashed
        jg   @@draw
        test word ptr [li],2
        jnz  @@skip
@@draw: mov  ax,[lx8]
        mov  cl,8
        sar  ax,cl
        add  ax,[lcx]
        js   @@skip
        cmp  ax,319
        jg   @@skip
        mov  [px],ax
        mov  ax,[ly8]
        mov  cl,8
        sar  ax,cl
        add  ax,[lcy]
        js   @@skip
        cmp  ax,199
        jg   @@skip
        mov  bx,ax              ; plot: y*320 + x
        mov  cl,6
        shl  ax,cl
        mov  dx,ax
        mov  ax,bx
        mov  cl,8
        shl  ax,cl
        add  ax,dx
        add  ax,[px]
        mov  di,ax
        mov  byte ptr es:[di],15
@@skip: mov  ax,[cosr]          ; advance 3 px along the line
        add  ax,ax
        add  ax,[cosr]
        add  [lx8],ax
        mov  ax,[sinr]
        add  ax,ax
        add  ax,[sinr]
        sub  [ly8],ax
        inc  word ptr [li]
        cmp  word ptr [li],25
        jb   @@pt
@@nx:   inc  word ptr [lk]
        jmp  @@lk
@@ret:  ret

; ---- NUM: AX -> right-aligned decimal in NBUF (5 chars) --------------------
NUM:    push bx
        push cx
        push dx
        mov  bx,offset NBUF
        mov  cx,5
@@z:    mov  byte ptr [bx],' '
        inc  bx
        loop @@z
        mov  bx,offset NBUF+4
@@d:    xor  dx,dx
        mov  cx,10
        div  cx
        add  dl,'0'
        mov  [bx],dl
        dec  bx
        or   ax,ax
        jnz  @@d
        pop  dx
        pop  cx
        pop  bx
        ret

; ---- TSIN: AX angle (0..255 = full circle) -> AX = sin * 256 ---------------
TSIN:   push bx
        push dx
        mov  dx,ax
        and  dx,255
        mov  bx,dx
        and  bx,63
        test dl,64              ; quarters 2 and 4 mirror the index
        jz   @@u
        mov  ax,64
        sub  ax,bx
        mov  bx,ax
@@u:    add  bx,bx
        mov  ax,[SINT+bx]
        test dl,128             ; the bottom half is negative
        jz   @@p
        neg  ax
@@p:    pop  dx
        pop  bx
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

; ---- BAKE: the per-row ground constants (the TKOFF set) --------------------
BAKE:   mov  si,1
@@b:    mov  bx,si
        add  bx,bx
        mov  ax,24000           ; 1500 m * 16: nearest visible slab ~15 m
        xor  dx,dx
        div  si
        xor  dx,dx
        mov  cx,SEAM
        div  cx
        mov  [DMOD+bx],dx       ; d16 mod 61 m
        mov  ax,si              ; edge half-width: 6.5 px per row (the
        mov  cx,13              ; tape's shallow wedge)
        mul  cx
        mov  cx,2
        div  cx
        cmp  ax,158
        jbe  @@e1
        mov  ax,158
@@e1:   mov  [EDGE+bx],ax
        mov  ax,si              ; stripe half-width: y/8 + 1
        mov  cx,8
        xor  dx,dx
        div  cx
        inc  ax
        cmp  ax,14
        jbe  @@e2
        mov  ax,14
@@e2:   mov  [SW+bx],ax
        mov  ax,si              ; concrete shade: far haze -> near dark
        mov  cx,10
        mul  cx
        cmp  ah,3
        jbe  @@c1
        mov  ah,3
        mov  al,255
@@c1:   mov  dl,ah
        add  dl,16
        xor  dh,dh
        mov  [CBASE+bx],dx
        mov  dl,al
        xor  dh,dh
        mov  [CFRAC+bx],dx
        inc  si
        cmp  si,NROWS
        jbe  @@b
        xor  si,si              ; sky ramp, indexed by height above the
@@sk:   mov  ax,si              ; horizon: t = crow*5, shade = 10 - t/256
        add  ax,ax
        add  ax,ax
        add  ax,si
        cmp  ah,4
        jb   @@s2
        mov  dl,6               ; high above: solid zenith
        xor  al,al
        jmp  @@s3
@@s2:   or   al,al
        jnz  @@s4
        mov  dl,10
        sub  dl,ah
        jmp  @@s3
@@s4:   mov  dl,9
        sub  dl,ah
        neg  al
@@s3:   mov  [SBASE+si],dl
        mov  [SFRAC+si],al
        inc  si
        cmp  si,200
        jb   @@sk
        xor  si,si              ; the two clouds: width/start random
        xor  bx,bx              ; walks up from the horizon
        xor  bp,bp
        mov  dx,60
        mov  di,200
@@cl:   call RND16
        mov  al,ah
        xor  ah,ah
        and  ax,7
        sub  ax,2
        add  bx,ax
        cmp  si,48
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
        dec  ax
        add  dx,ax
        cmp  dx,10
        jge  @@t8
        mov  dx,10
@@t8:   cmp  dx,120
        jle  @@t9
        mov  dx,120
@@t9:   call RND16
        mov  al,ah
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

; ---- GENBED: the tuned turbine + warm-up + splice + pristine copy ----------
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
        mov  al,ah              ; high byte only (the TERRA lesson)
        xor  ah,ah
        and  ax,31
        sub  ax,15              ; n = -15..16
        mov  bx,ax
        mov  cl,4
        shl  ax,cl              ; x16: filter headroom
        sub  ax,[bm1]           ; pole 1 (~440 Hz)
        sar  ax,1
        sar  ax,1
        add  [bm1],ax
        mov  ax,[bm1]           ; pole 2 (~440 Hz)
        sub  ax,[bm2]
        sar  ax,1
        sar  ax,1
        add  [bm2],ax
        mov  ax,[bm2]           ; pole 3 (~880 Hz)
        sub  ax,[bm3]
        sar  ax,1
        add  [bm3],ax
        mov  ax,[bm3]           ; pole 4 (~880 Hz)
        sub  ax,[bm4]
        sar  ax,1
        add  [bm4],ax
        mov  dx,[bm4]           ; the roar, fenced
        sar  dx,1
        sar  dx,1
        cmp  dx,38
        jle  @@r1
        mov  dx,38
@@r1:   cmp  dx,-38
        jge  @@r2
        mov  dx,-38
@@r2:   mov  ax,bx              ; the sub: leaky brownian walk
        sar  ax,1
        add  bp,ax
        mov  ax,bp
        mov  cl,4
        sar  ax,cl
        sub  bp,ax
        cmp  bp,16
        jle  @@w1
        mov  bp,16
@@w1:   cmp  bp,-16
        jge  @@w2
        mov  bp,-16
@@w2:   add  dx,bp
        cmp  si,3               ; whisper whine
        jae  @@g2
        add  dx,2
        jmp  @@g3
@@g2:   sub  dx,2
@@g3:   mov  ax,dx              ; the muffle
        add  ax,[praw]
        sar  ax,1
        mov  [praw],dx
        add  ax,128
        cmp  word ptr [warmc],0 ; warm-up: steady state first
        je   @@st
        dec  word ptr [warmc]
        jmp  @@wh
@@st:   stosb
@@wh:   inc  si
        cmp  si,6
        jb   @@g4
        xor  si,si
@@g4:   cmp  di,SNDN
        jb   @@g
        xor  si,si              ; splice the seam: tail fades into head
@@xf:   mov  di,si
        add  di,SNDN-512
        mov  al,es:[di]
        mov  [xtt],al
        mov  al,es:[si]
        sub  al,[xtt]
        cbw
        mov  bx,si
        mov  cl,3
        shr  bx,cl
        imul bx
        mov  cl,6
        sar  ax,cl
        add  al,[xtt]
        mov  es:[di],al
        inc  si
        cmp  si,512
        jb   @@xf
        push ds                 ; pristine copy: ring -> the top half
        mov  ax,es
        mov  ds,ax
        xor  si,si
        mov  cx,SNDN/2
        rep  movsw
        pop  ds
        pop  es
        ret

; ---- HEAL: restore the ring behind the beam from the pristine copy ---------
HEAL:   call SFXRAW             ; BX = beam position
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
        mov  al,cs:[tcol]
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

; ---- the DAC entries -------------------------------------------------------
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
PAL     db   1, 10,26, 8        ; grass (runway phase, flat)
        db   3, 58,58,58        ; the painted stripe
        db   4, 46,46,44        ; edge lines
        db   5, 63,42,10        ; amber cards
        db   6, 12,22,42        ; sky ramp: zenith deep...
        db   7, 15,26,48
        db   8, 18,30,53
        db   9, 22,35,58
        db  10, 27,41,62        ; ...the haze over the horizon
        db  11, 46,50,60        ; cloud ramp: soft blue-white base...
        db  12, 58,59,63        ; ...and the sunlit top
        db  13, 22,36,24        ; airshow grass: haze green far...
        db  14, 11,27, 9        ; ...deep green below
        db  15, 60,62,63        ; HUD white (the 1990 standard; green
                                ; came later - people expect white)
        db  21, 30,58,63        ; HUD cyan: bearing to the runway
        db  16, 47,46,48        ; concrete ramp: far haze (warm)
        db  17, 43,43,47        ; (cool)
        db  18, 40,39,41        ; (warm)
        db  19, 36,36,41        ; (cool)
        db  20, 32,32,34        ; near slab
        db 255

; ---- data ------------------------------------------------------------------
NOSB    db 'No Sound Blaster at 220h.',13,10,'$'
MTITLE  db 'FLIGHT - SPACE',0
MAGAIN  db 'SHOW OVER - SPACE AGAIN',0
; The maneuver program: (ticks, roll rate, pitch rate) per segment,
; 18.2 ticks/s; roll is 0..255 = a full circle. Zero ticks ends it.
MSCRIPT dw 17, 0,-5             ; level off - the horizon comes back
        dw 45, 0, 0             ; straight and level, clouds drift
        dw 64, 4, 0             ; the aileron roll: 360 in 3.5 s
        dw 40, 0, 0             ; breathe
        dw 20, 0, 5             ; the pull: nose up hard...
        dw 25, 0, 3             ; ...into pure sky
        dw 30, 0, 0             ; hanging on the burner in blue
        dw 35, 0,-5             ; nose back down through the horizon
        dw 40, 0, 0             ; level again
        dw  0, 0, 0
; The spool ramp: smoothstep, 46 ticks = 2.5 s, from the spectrogram.
TCRAMP  db  75, 75, 76, 76, 77, 78, 79, 81, 83, 84, 86, 89
        db  91, 93, 96, 98,101,104,107,110,113,116,119,121
        db 124,127,130,133,136,139,142,144,147,149,151,154
        db 156,157,159,161,162,163,164,164,165,165
; quarter sine table: SINT[i] = round(256*sin(i*90/64 deg)), i=0..64
SINT    dw 0,6,13,19,25,31,38,44,50,56,62,68,74,80,86,92,98,104,109,115
        dw 121,126,132,137,142,147,153,157,162,167,172,177,181,185,190,194
        dw 198,202,206,209,213,216,220,223,226,229,231,234,237,239,241,243
        dw 245,247,248,250,251,252,253,254,255,255,256,256,256
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
state   db 0                    ; 0 idle 1 spool 2 roll 3 rotate 4 climb
                                ; 5 airshow 6 end card
ridx    dw 0                    ; spool ramp position
curtc   db TCIDLE               ; current DSP time constant
ltick   dw 0                    ; last BIOS tick seen
tcnt    dw 0                    ; tick counter (waver / breath phases)
v16     dw 0                    ; speed, 1/16 m/s
odo     dw 0                    ; odometer mod 61 m, 1/16 m
swph1   dw 0                    ; sway phase, pitch bob
swph2   dw 21                   ; sway phase, lateral (offset: they beat)
cx0     dw 160                  ; runway centre column, swaying
rowb    dw 0                    ; current row base offset
hrow    dw HORIZ0               ; horizon row (the script moves it)
hcur    dw HORIZ0               ; horizon row as drawn (with the bob)
shamp   dw 0                    ; shake amplitude, rows
bamp    dw 0                    ; current seam thump amplitude
endcnt  dw 0                    ; climb ticks before the show
roll    dw 0                    ; bank angle, 0..255 = full circle
sinr    dw 0                    ; sin(roll)*256
cosr    dw 256                  ; cos(roll)*256
fmv     dw 0                    ; f at the current row's centre
mrow    dw 0                    ; airshow renderer row counter
spa     dw 0                    ; span start column
spl     dw 0                    ; span length
sptype  db 0                    ; 0 = sky, 1 = ground
mptr    dw 0                    ; maneuver script cursor
mleft   dw 0                    ; ticks left in the segment
mrr     dw 0                    ; current roll rate
mpr     dw 0                    ; current pitch rate
mstrain dw 0                    ; TC lean while the airframe is loaded
alt16   dw 0                    ; altitude, 1/16 m
tcol    db 5                    ; TXT colour (amber cards)
NBUF    db 6 dup(0)             ; NUM's decimal scratch
ABUF    db 4 dup(0)             ; altitude label scratch (NK5 style)
kmh     dw 0                    ; current speed, km/h
alm     dw 0                    ; current altitude, m
tm      dw 0                    ; tape tick value walker
ty      dw 0                    ; tape tick screen row (or ruler x)
C315    db '315',0              ; the heading labels: the show flies
C000    db '000',0              ; straight, the ruler stands still
C045    db '045',0
; OWLFLY's 4x6 font, resource 1 of CITY.DAT: digits and K, embedded so
; the example still needs no data files. The binary literals ARE the art.
HFONT   db 11100000b,10100000b,10100000b,10100000b,11100000b,00000000b ; 0
        db 01000000b,11000000b,01000000b,01000000b,11100000b,00000000b ; 1
        db 11100000b,00100000b,11100000b,10000000b,11100000b,00000000b ; 2
        db 11100000b,00100000b,11100000b,00100000b,11100000b,00000000b ; 3
        db 10100000b,10100000b,11100000b,00100000b,00100000b,00000000b ; 4
        db 11100000b,10000000b,11100000b,00100000b,11100000b,00000000b ; 5
        db 11100000b,10000000b,11100000b,10100000b,11100000b,00000000b ; 6
        db 11100000b,00100000b,01000000b,01000000b,01000000b,00000000b ; 7
        db 11100000b,10100000b,11100000b,10100000b,11100000b,00000000b ; 8
        db 11100000b,10100000b,11100000b,00100000b,11100000b,00000000b ; 9
        db 10100000b,11000000b,10000000b,11000000b,10100000b,00000000b ; K
lk      dw 0                    ; ladder: current line index
ld      dw 0                    ; ladder: perpendicular offset, rows
lcx     dw 0                    ; ladder: line centre x, screen
lcy     dw 0                    ; ladder: line centre y, screen
fcv     dw 0                    ; ladder: horizon offset from centre
lke     dw 0                    ; ladder: last line index to draw
lx8     dw 0                    ; ladder: x along the line, 8.8 rel centre
ly8     dw 0                    ; ladder: y along the line, 8.8 rel horizon
li      dw 0                    ; ladder: step counter
px      dw 0                    ; ladder: plotted x scratch
rowscr  dw 0                    ; current screen row (dither phase)
pbase   db 0                    ; dither: ramp shade in play
pfrac   db 0                    ; dither: its fraction 0..255
PATT    db 4 dup(0)             ; the row's 4-pixel pattern
BAYER   db   0,128, 32,160      ; 4x4 ordered matrix, premultiplied x16
        db 192, 64,224, 96
        db  48,176, 16,144
        db 240,112,208, 80
DMOD    dw NROWS+1 dup(0)       ; per-row: ground distance mod 61 m
EDGE    dw NROWS+1 dup(0)       ; per-row: runway half-width, pixels
SW      dw NROWS+1 dup(0)       ; per-row: stripe half-width, pixels
CBASE   dw NROWS+1 dup(0)       ; per-row: concrete ramp shade
CFRAC   dw NROWS+1 dup(0)       ; per-row: concrete blend fraction
SBASE   db 200 dup(0)           ; per-height-above-horizon: sky shade
SFRAC   db 200 dup(0)           ; per-height-above-horizon: sky fraction
C1W     db 96 dup(0)            ; cloud 1: width per row above horizon
C1S     db 96 dup(0)            ; cloud 1: start column
C2W     db 96 dup(0)            ; cloud 2: width
C2S     db 96 dup(0)            ; cloud 2: start column

        INCLUDE ..\ENGINE\E_MATH.INC
        INCLUDE ..\ENGINE\E_SND.INC

CODE    ENDS
        END START
