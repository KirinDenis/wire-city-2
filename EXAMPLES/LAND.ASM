; ============================================================================
;  LAND.COM - WIRE CITY engine example 09: the measured landing
;
;  The third cartoon (FlightRef landing/v1, CURVES.md, 2026-07-21):
;  short final at 60 m, the worked throttle of a real approach, flare
;  over the threshold, the ~15 second FLOAT in ground effect that the
;  tape taught us (the user's ears caught the touchdown - the camera
;  cannot), the kiss at ~65 m/s, quick derotation, and a steady
;  3 m/s2 rollout with the seam thumps fading as the jet slows.
;
;  What is NEW: the ground is drawn in TRUE perspective from a camera
;  that actually DESCENDS - no baked row tables; every row divides
;  d = 220*h/y fresh, the runway exists from 1000 m to 3400 m of world
;  and grows toward the window as height bleeds away. Three divisions
;  per runway row, and the 8086 does not mind.
;
;  Sound: the approach is the star - on final the RPM knob RANDOM
;  WALKS (the spectrogram shows the pilot never holds the throttle
;  still), slides to idle through the flare, then it is all wheels.
;
;  SPACE lands, ESC quits. Sound Blaster at 220h, DMA 1 (DOSBox: yes).
; ============================================================================
SNDN    equ 8000h               ; ring length; must precede the code
TCIDLE  equ 75                  ; DSP time constant at idle  (~5512 Hz)
TCAPP   equ 128                 ; approach mid-power time constant
HGEAR   equ 436                 ; camera height on the gear, 1/64 m (6.8)
H0      equ 3840                ; final starts at 60 m
V0      equ 1152                ; final speed 72 m/s (140 kt), 1/16 m/s
VTOUCH  equ 1040                ; ~65 m/s at the kiss
THRESH  equ 1000                ; runway threshold, m of world
RWLEN   equ 2400                ; runway length, m
SEAM    equ 976                 ; stripe cycle, 1/16 m (61 m)
PAINT   equ 592                 ; painted part, 1/16 m (37 m)

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
        call BAKE               ; sky ramp + clouds (no ground tables!)
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
        ; ---- DSP: speaker on, approach power, the eternal block ----
        mov  ah,0D1h
        call SBWR
        mov  byte ptr [curtc],TCAPP
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
        or   al,al              ; idle -> fly the approach
        jz   @@go
        cmp  al,6               ; stopped -> around again
        jne  @@loop
@@go:   mov  byte ptr [state],1
        mov  word ptr [h6],H0
        mov  word ptr [hacc],0
        mov  word ptr [vs8],2970
        mov  word ptr [v16],V0
        mov  word ptr [vacc],0
        mov  word ptr [posm],0
        mov  word ptr [posacc],0
        mov  word ptr [odo],0
        mov  word ptr [hrow],95
        mov  word ptr [wtc],0
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
        je   @@final
        cmp  al,2
        je   @@flare
        cmp  al,3
        je   @@float
        cmp  al,4
        je   @@derot
        cmp  al,5
        je   @@roll
        ret                     ; state 6: hold the end card
@@idle: ; ---- idle on the card: the engine breathes at approach power ----
        test word ptr [tcnt],7
        jnz  @@done
        call RND16
        and  ax,1
        add  al,TCAPP
        mov  [curtc],al
        call SETTC
        ret
@@final:; ---- short final: sink 3.3 m/s, and WORK the throttle - the ----
        ; tape's RPM line never holds still on approach
        call MOVE
        call SINK
        test word ptr [tcnt],1
        jnz  @@f1
        call RND16
        mov  bx,ax
        and  bx,7
        sub  bx,3               ; the walk: -3..+4 per step
        add  [wtc],bx
        cmp  word ptr [wtc],-12
        jge  @@f2
        mov  word ptr [wtc],-12
@@f2:   cmp  word ptr [wtc],12
        jle  @@f3
        mov  word ptr [wtc],12
@@f3:   mov  ax,TCAPP
        add  ax,[wtc]
        mov  [curtc],al
        call SETTC
@@f1:   cmp  word ptr [h6],640  ; 10 m: begin the flare
        jg   @@done
        mov  byte ptr [state],2
        ret
@@flare:; ---- flare: nose up, sink arrested, throttle to idle ----
        call MOVE
        call SINK
        inc  word ptr [hrow]    ; 95 -> 125: the nose rises
        mov  ax,[vs8]
        sub  ax,100             ; sink dies fast...
        cmp  ax,30
        jge  @@fl1
        mov  ax,30              ; ...into the float's ~15 s settle
@@fl1:  mov  [vs8],ax
        cmp  byte ptr [curtc],TCIDLE
        jbe  @@fl2
        sub  byte ptr [curtc],2
        call SETTC
@@fl2:  cmp  word ptr [hrow],125
        jb   @@done
        mov  byte ptr [state],3
        ret
@@float:; ---- the float: ~15 s in ground effect, speed bleeding ----
        call MOVE
        call SINK
        mov  ax,[vacc]          ; v decays 72 -> 65 across the float
        add  ax,105
        mov  bx,ax
        mov  cl,8
        shr  bx,cl
        sub  [v16],bx
        and  ax,255
        mov  [vacc],ax
        cmp  word ptr [h6],HGEAR
        jg   @@done
        mov  word ptr [h6],HGEAR
        mov  word ptr [vs8],0
        mov  byte ptr [state],4
        call TDTHUMP            ; the kiss
        ret
@@derot:; ---- derotation: nosewheel down in ~2 s ----
        call MOVE
        dec  word ptr [hrow]    ; 125 -> 100
        cmp  word ptr [hrow],100
        jg   @@done
        mov  byte ptr [state],5
        ret
@@roll: ; ---- rollout: steady brakes, the seams sing the speed ----
        call MOVE
        sub  word ptr [v16],3   ; ~3.4 m/s2
        cmp  word ptr [v16],160
        jg   @@done
        mov  word ptr [v16],160
        mov  byte ptr [state],6
@@done: ret

; ---- MOVE: advance the world by one tick of speed --------------------------
; posm is metres: += v16/291 via an 8.8 accumulator (x7/8 of v16/256).
; odo tracks 1/16 m mod 61 m for the stripes and the rolling seams.
MOVE:   mov  ax,[v16]
        mov  bx,ax
        mov  cl,3
        sar  bx,cl
        sub  ax,bx              ; v16 * 7/8 ~= metres/tick in 8.8
        add  ax,[posacc]
        mov  bx,ax
        mov  cl,8
        shr  bx,cl
        add  [posm],bx
        and  ax,255
        mov  [posacc],ax
        mov  ax,[v16]           ; odometer, 1/16 m
        xor  dx,dx
        mov  bx,18
        div  bx
        add  [odo],ax
        cmp  word ptr [odo],SEAM
        jb   @@ret
        sub  word ptr [odo],SEAM
        cmp  byte ptr [state],4 ; only rolling wheels feel the seams
        jl   @@ret
        call THUMP
@@ret:  ret

; ---- SINK: bleed height by vs8 (8.8 of 1/64 m per tick) --------------------
SINK:   mov  ax,[hacc]
        add  ax,[vs8]
        mov  bx,ax
        mov  cl,8
        shr  bx,cl
        sub  [h6],bx
        and  ax,255
        mov  [hacc],ax
        ret

; ---- THUMP: a rolling seam, loudness follows speed -------------------------
THUMP:  mov  ax,[v16]
        mov  cl,4
        shr  ax,cl              ; 72 m/s -> 72, fading to 10
        cmp  ax,60
        jbe  @@t1
        mov  ax,60
@@t1:   mov  [bamp],ax
        jmp  KNOCK
; ---- TDTHUMP: the touchdown kiss - one firm knock --------------------------
TDTHUMP:mov  word ptr [bamp],70
KNOCK:  push es
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
        ret

; ---- SETTC: program the DSP sample rate from [curtc] -----------------------
SETTC:  mov  ah,40h
        call SBWR
        mov  ah,[curtc]
        call SBWR
        ret

; ---- RENDER: sky + clouds, then TRUE-perspective ground --------------------
RENDER: push es
        mov  ax,[bufseg]
        mov  es,ax
        ; ---- the gentle sway ----
        inc  word ptr [swph1]
        mov  ax,[swph1]
        call TRI
        mov  cl,4
        sar  ax,cl              ; -1..+1 rows
        add  ax,[hrow]
        cmp  ax,20
        jge  @@h1
        mov  ax,20
@@h1:   cmp  ax,198
        jle  @@h2
        mov  ax,198
@@h2:   mov  [hcur],ax
        inc  word ptr [swph2]
        mov  ax,[swph2]
        call TRI
        mov  cl,5
        sar  ax,cl
        add  ax,160
        mov  [cx0],ax
        ; ---- sky rows with the horizon-anchored ramp + clouds ----
        xor  di,di
        xor  dx,dx
@@sky:  cmp  dx,[hcur]
        jae  @@skyd
        mov  bx,[hcur]
        dec  bx
        sub  bx,dx
        cmp  bx,199
        jbe  @@sk1
        mov  bx,199
@@sk1:  mov  al,[SBASE+bx]
        mov  [pbase],al
        mov  al,[SFRAC+bx]
        mov  [pfrac],al
        mov  ax,dx
        call MKPATT
        mov  [rowb],di
        mov  cx,320
        call DFILL
        mov  bx,[hcur]          ; the clouds
        dec  bx
        sub  bx,dx
        cmp  bx,96
        jae  @@nocl
        mov  al,[C1W+bx]
        or   al,[C2W+bx]
        jz   @@nocl
        mov  ax,bx
        add  ax,ax
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
        ; ---- ground rows, TRUE perspective from the sinking camera ----
        mov  si,1               ; y = row below the horizon
@@row:  mov  ax,[hcur]
        add  ax,si
        cmp  ax,200
        jae  @@rows_done
        dec  ax
        mov  [rowscr],ax
        mov  cx,320
        mul  cx
        mov  di,ax
        mov  [rowb],ax
        mov  ax,[h6]            ; d = 220*h / (64*y) metres
        mov  cx,220
        mul  cx                 ; dx:ax = 220*h6
        mov  bx,si
        mov  cl,6
        shl  bx,cl              ; y*64
        div  bx
        or   ax,ax
        jnz  @@d1
        inc  ax                 ; never zero
@@d1:   mov  [dmv],ax
        mov  bx,1200            ; shared shade: far haze -> near dark
        sub  bx,ax
        jns  @@s1
        xor  bx,bx
@@s1:   cmp  bx,1023
        jbe  @@s2
        mov  bx,1023
@@s2:   mov  [s16v],bx
        mov  byte ptr [pbase],13 ; grass across the row first
        mov  ax,bx
        mov  cl,2
        shr  ax,cl
        cmp  ax,255
        jbe  @@s3
        mov  ax,255
@@s3:   mov  [pfrac],al
        mov  ax,[rowscr]
        call MKPATT
        mov  di,[rowb]
        mov  cx,320
        call DFILL
        mov  ax,[posm]          ; is this row on the runway?
        add  ax,[dmv]
        sub  ax,THRESH
        jl   @@norwy
        cmp  ax,RWLEN
        jg   @@norwy
        mov  [relv],ax
        mov  ax,4950            ; edge half-width = 22.5 m * 220 / d
        xor  dx,dx
        div  word ptr [dmv]
        cmp  ax,158
        jbe  @@e1
        mov  ax,158
@@e1:   mov  [ev],ax
        mov  bx,[s16v]          ; concrete pattern from the shared shade
        mov  al,bh
        add  al,16
        mov  [pbase],al
        mov  al,bl
        mov  [pfrac],al
        mov  ax,[rowscr]
        call MKPATT
        mov  di,[rowb]
        add  di,[cx0]
        sub  di,[ev]
        mov  cx,[ev]
        add  cx,[ev]
        call DFILL
        mov  di,[rowb]          ; the edge lines
        add  di,[cx0]
        sub  di,[ev]
        mov  al,4
        mov  es:[di],al
        add  di,[ev]
        add  di,[ev]
        mov  es:[di],al
        mov  ax,[relv]          ; the centreline stripe, world-locked
        mov  cl,4
        shl  ax,cl              ; rel*16, 1/16 m
        xor  dx,dx
        mov  cx,SEAM
        div  cx
        cmp  dx,PAINT
        jae  @@norwy
        mov  ax,99              ; stripe half-width = 0.45 m * 220 / d
        xor  dx,dx
        div  word ptr [dmv]
        inc  ax
        cmp  ax,6
        jbe  @@w1
        mov  ax,6
@@w1:   mov  bx,ax
        mov  di,[rowb]
        add  di,[cx0]
        sub  di,bx
        mov  cx,bx
        add  cx,bx
        inc  cx
        mov  al,3
        rep  stosb
@@norwy:
        inc  si
        jmp  @@row
@@rows_done:
        mov  ax,[h6]            ; HUD altitude = height above the gear
        sub  ax,HGEAR
        jns  @@ha
        xor  ax,ax
@@ha:   mov  cl,2
        sar  ax,cl              ; 1/64 m -> 1/16 m
        mov  [alt16],ax
        call HUD
        ; ---- the cards ----
        cmp  byte ptr [state],0
        jne  @@c1
        mov  byte ptr [tcol],5
        mov  si,offset MTITLE
        mov  ax,180
        mov  bx,60
        call TXT
        jmp  @@cdone
@@c1:   cmp  byte ptr [state],6
        jne  @@cdone
        mov  byte ptr [tcol],5
        mov  si,offset MAGAIN
        mov  ax,180
        mov  bx,44
        call TXT
@@cdone:
        pop  es
        ret

; ---- HUD: the F-15 standard, metric (see FLIGHT.ASM for the story) ---------
HUD:    mov  ax,[v16]
        mov  cx,9
        mul  cx
        mov  cx,40
        div  cx
        mov  [kmh],ax
        mov  ax,[kmh]
        sub  ax,80
        jns  @@s0
        xor  ax,ax
@@s0:   add  ax,19
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
        mov  bx,[kmh]
        sub  bx,ax
        sar  bx,1
        add  bx,100
        mov  [ty],bx
        cmp  bx,61
        jl   @@snext
        cmp  bx,139
        jg   @@snext
        mov  ax,[tm]
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
        mov  ax,[tm]
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
@@sdone:mov  di,100*320+48
        mov  cx,8
@@sd:   mov  byte ptr es:[di],15
        inc  di
        loop @@sd
        mov  ax,[kmh]
        call NUM
        mov  si,offset NBUF+2
        mov  ax,97
        mov  bx,58
        call FDR
        ; altitude tape, right
        mov  ax,[alt16]
        mov  cl,4
        shr  ax,cl
        mov  [alm],ax
        mov  ax,[alm]
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
        mov  bx,[alm]
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
        mov  ax,[tm]
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
        mov  ax,[tm]
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
@@adone:mov  di,100*320+264
        mov  cx,8
@@ad:   mov  byte ptr es:[di],15
        inc  di
        loop @@ad
        mov  ax,[alm]
        call NUM
        mov  si,offset NBUF+1
        mov  ax,97
        mov  bx,246
        call FDR
        ; heading: .|.|.|. ruler, labels each 45, caret, cyan runway
        mov  word ptr [tm],-10
@@ct:   mov  ax,[tm]
        cmp  ax,10
        jg   @@ctd
        mov  bx,ax
        add  ax,ax
        add  ax,ax
        add  ax,bx
        add  ax,160
        mov  [ty],ax
        mov  cx,[tm]
        add  cx,12
@@m3:   cmp  cx,3
        jb   @@m3d
        sub  cx,3
        jmp  @@m3
@@m3d:  jcxz @@big
        mov  ax,12
        call ROWAD
        add  ax,[ty]
        mov  di,ax
        mov  byte ptr es:[di],15
        jmp  @@ctn
@@big:  mov  ax,9
        call ROWAD
        add  ax,[ty]
        mov  di,ax
        mov  cx,7
@@ct1:  mov  byte ptr es:[di],15
        add  di,320
        loop @@ct1
@@ctn:  inc  word ptr [tm]
        jmp  @@ct
@@ctd:  mov  si,offset C315
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
        mov  byte ptr es:[17*320+160],15
        mov  byte ptr es:[18*320+159],15
        mov  byte ptr es:[18*320+161],15
        mov  di,20*320+159
        mov  cx,3
@@cy:   mov  byte ptr es:[di],21
        mov  byte ptr es:[di+320],21
        inc  di
        loop @@cy
        ; waterline
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
        ret

; ---- ROWAD: AX = screen row -> AX = row * 320 ------------------------------
ROWAD:  push bx
        push cx
        mov  bx,ax
        mov  cl,8
        shl  ax,cl
        mov  cl,6
        shl  bx,cl
        add  ax,bx
        pop  cx
        pop  bx
        ret

; ---- FDR: OWLFLY's 4x6 font - digits, K, space - at row AX col BX ----------
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
        add  ax,ax
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

; ---- TRI: AX phase -> a triangle wave, -16..+16 ----------------------------
TRI:    and  ax,63
        cmp  ax,32
        jb   @@a
        neg  ax
        add  ax,48
        ret
@@a:    sub  ax,16
        ret

; ---- MKPATT: bake the 4-pixel dither pattern for one screen row ------------
MKPATT: push bx
        push si
        and  ax,3
        add  ax,ax
        add  ax,ax
        mov  si,ax
        xor  bx,bx
@@m:    mov  ah,[BAYER+si]
        mov  al,[pbase]
        cmp  [pfrac],ah
        jbe  @@m1
        inc  al
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

; ---- BAKE: sky ramp + clouds (the ground needs no tables here) -------------
BAKE:   xor  si,si              ; sky ramp by height above the horizon
@@sk:   mov  ax,si
        add  ax,ax
        add  ax,ax
        add  ax,si
        cmp  ah,4
        jb   @@s2
        mov  dl,6
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
        xor  si,si              ; the two clouds
        xor  bx,bx
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
        xor  si,si
        xor  bp,bp
        mov  word ptr [bm1],0
        mov  word ptr [bm2],0
        mov  word ptr [bm3],0
        mov  word ptr [bm4],0
        mov  word ptr [praw],0
@@g:    call RND16
        mov  al,ah
        xor  ah,ah
        and  ax,31
        sub  ax,15
        mov  bx,ax
        mov  cl,4
        shl  ax,cl
        sub  ax,[bm1]
        sar  ax,1
        sar  ax,1
        add  [bm1],ax
        mov  ax,[bm1]
        sub  ax,[bm2]
        sar  ax,1
        sar  ax,1
        add  [bm2],ax
        mov  ax,[bm2]
        sub  ax,[bm3]
        sar  ax,1
        add  [bm3],ax
        mov  ax,[bm3]
        sub  ax,[bm4]
        sar  ax,1
        add  [bm4],ax
        mov  dx,[bm4]
        sar  dx,1
        sar  dx,1
        cmp  dx,38
        jle  @@r1
        mov  dx,38
@@r1:   cmp  dx,-38
        jge  @@r2
        mov  dx,-38
@@r2:   mov  ax,bx
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
        cmp  si,3
        jae  @@g2
        add  dx,2
        jmp  @@g3
@@g2:   sub  dx,2
@@g3:   mov  ax,dx
        add  ax,[praw]
        sar  ax,1
        mov  [praw],dx
        add  ax,128
        cmp  word ptr [warmc],0
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
        xor  si,si
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
        push ds
        mov  ax,es
        mov  ds,ax
        xor  si,si
        mov  cx,SNDN/2
        rep  movsw
        pop  ds
        pop  es
        ret

; ---- HEAL: restore the ring behind the beam --------------------------------
HEAL:   call SFXRAW
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

; ---- TXT: ASCIIZ at SI -> back buffer at (BX,AX), colour [tcol] ------------
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
PAL     db   3, 58,58,58        ; the painted stripe
        db   4, 46,46,44        ; edge lines
        db   5, 63,42,10        ; amber cards
        db   6, 12,22,42        ; sky ramp: zenith deep...
        db   7, 15,26,48
        db   8, 18,30,53
        db   9, 22,35,58
        db  10, 27,41,62        ; ...the haze over the horizon
        db  11, 46,50,60        ; cloud ramp: base...
        db  12, 58,59,63        ; ...sunlit top
        db  13, 22,36,24        ; grass: haze green far...
        db  14, 11,27, 9        ; ...deep green below
        db  15, 60,62,63        ; HUD white
        db  16, 47,46,48        ; concrete ramp: far haze (warm)
        db  17, 43,43,47        ; (cool)
        db  18, 40,39,41        ; (warm)
        db  19, 36,36,41        ; (cool)
        db  20, 32,32,34        ; near slab
        db  21, 30,58,63        ; HUD cyan
        db 255

; ---- data ------------------------------------------------------------------
NOSB    db 'No Sound Blaster at 220h.',13,10,'$'
MTITLE  db 'LAND - SPACE',0
MAGAIN  db 'FULL STOP - SPACE AGAIN',0
C315    db '315',0
C000    db '000',0
C045    db '045',0
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
state   db 0                    ; 0 idle 1 final 2 flare 3 float
                                ; 4 derotation 5 rollout 6 stopped
curtc   db TCAPP                ; current DSP time constant
ltick   dw 0                    ; last BIOS tick seen
tcnt    dw 0                    ; tick counter
v16     dw V0                   ; speed, 1/16 m/s
vacc    dw 0                    ; speed decay accumulator (8.8)
h6      dw H0                   ; camera height AGL, 1/64 m
hacc    dw 0                    ; sink accumulator (8.8)
vs8     dw 2970                 ; sink rate, 8.8 of 1/64 m per tick
posm    dw 0                    ; world position, metres
posacc  dw 0                    ; its 8.8 accumulator
odo     dw 0                    ; odometer mod 61 m, 1/16 m
wtc     dw 0                    ; the approach throttle walk
swph1   dw 0                    ; sway phase, pitch bob
swph2   dw 21                   ; sway phase, lateral
cx0     dw 160                  ; centre column, swaying
rowb    dw 0                    ; current row base offset
hrow    dw 95                   ; horizon row (nose attitude)
hcur    dw 95                   ; horizon row as drawn
bamp    dw 0                    ; knock amplitude
dmv     dw 0                    ; this row's ground distance, m
s16v    dw 0                    ; this row's shade value
ev      dw 0                    ; this row's runway half-width, px
relv    dw 0                    ; this row's distance past the threshold
alt16   dw 0                    ; HUD altitude, 1/16 m
tcol    db 5                    ; TXT colour (amber cards)
NBUF    db 6 dup(0)             ; NUM scratch
ABUF    db 4 dup(0)             ; altitude label scratch
kmh     dw 0                    ; current speed, km/h
alm     dw 0                    ; current altitude, m
tm      dw 0                    ; tape tick walker
ty      dw 0                    ; tape tick row (or ruler x)
rowscr  dw 0                    ; current screen row (dither phase)
pbase   db 0                    ; dither: ramp shade in play
pfrac   db 0                    ; dither: its fraction
PATT    db 4 dup(0)             ; the row's 4-pixel pattern
BAYER   db   0,128, 32,160      ; 4x4 ordered matrix, premultiplied x16
        db 192, 64,224, 96
        db  48,176, 16,144
        db 240,112,208, 80
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
