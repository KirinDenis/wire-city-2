; ============================================================================
;  SOLO.COM - WIRE CITY engine example 12: the first solo
;
;  The whole flight school in one machine, and nobody in the back
;  seat. You start PARKED on the slab: throttle up, roll, rotate when
;  the wing is ready (the lift decides, not a script), fly the flat
;  world - runways repeat every 12 km down the line - judge your
;  descent, drop the GEAR, drop the FLAPS, and put it on the NEXT
;  runway. Grease it and roll to a stop: SOLO COMPLETE. Miss the
;  concrete, land on the belly, or slam it, and the card says so.
;
;      lift  L = k * v^2 * alpha, k grows with FLAPS, +12% near the
;            slab; the wheels leave and return when L crosses m*g
;      drag  1.00 clean  +0.25 gear  +0.25 flaps  (times v^2)
;      thrust a real lever: the spool chases it, the note follows
;      mass  12 000 kg, brakes 3 m/s2, rolling friction on the wheels
;
;  Keys (the F-15 SE II scheme where it applies):
;      arrows = stick   + - = throttle   L = gear   F = flaps
;      B = brakes on/off   SPACE = start / again   ESC = quit
;
;  Instruments, the F-15 SE II manual's list: speed tape with the
;  landing tick and the STALL band, altitude tape with VVI, pitch
;  lines every 5 deg, the flight path indicator (the circle - put IT
;  on the concrete, not the nose), heading ruler with the range to the
;  next slab, AoA staple (stay in the bracket!), the G readout,
;  GEAR/FLAP/BRK/STALL lights.
; ============================================================================
SNDN    equ 8000h               ; ring length; must precede the code
TCIDLE  equ 75                  ; DSP time constant at idle  (~5512 Hz)
TCAPP   equ 92                  ; parked idle note
HGEAR   equ 436                 ; camera height on the gear, 1/64 m (6.8)
H0      equ 436                 ; you start ON the slab
V0      equ 0                   ; parked
THRESH  equ 1000                ; first runway threshold, m of world
RWLEN   equ 2400                ; runway length, m
RWGAP   equ 12000               ; a fresh runway every 12 km
PWRAP   equ 60000               ; world wrap (5 runways, seamless)
SEAM    equ 976                 ; stripe cycle, 1/16 m (61 m)
PAINT   equ 592                 ; painted part, 1/16 m (37 m)
VSTLC   equ 233                 ; stall speed clean, km/h  (mg/8 = v^2*a/1241
VSTLF   equ 218                 ; stall with FLAPS, km/h    at the stick's
                                ; alpha limit of 4352 - the physics, not taste)

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
        call DBGINIT            ; the umbilical, if anyone listens

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
        je   @@sp
        cmp  al,'l'             ; L = gear, the manual's key
        je   @@gr
        cmp  al,'L'
        je   @@gr
        cmp  al,'f'             ; F = flaps
        je   @@flp
        cmp  al,'F'
        je   @@flp
        cmp  al,'b'             ; B = brakes on/off
        je   @@br
        cmp  al,'B'
        je   @@br
        cmp  al,'+'             ; throttle, the manual's +/-
        je   @@thu
        cmp  al,'='
        je   @@thu
        cmp  al,'-'
        je   @@thd
        or   al,al              ; extended: the arrows are the stick
        jz   @@ext              ; (grey arrows arrive as AL=E0h on
        cmp  al,0E0h            ; enhanced keyboards - accept both)
        jne  @@loop
@@ext:  cmp  ah,48h             ; up-arrow = stick FORWARD = nose down
        je   @@nd
        cmp  ah,50h             ; down-arrow = stick back = nose up
        je   @@nu
        jmp  @@loop
@@gr:   xor  byte ptr [gear],1  ; the legs thunk in and out
        mov  word ptr [bamp],22
        call KNOCK
        jmp  @@loop
@@flp:  xor  byte ptr [flaps],1
        jmp  @@loop
@@br:   xor  byte ptr [brk],1
        jmp  @@loop
@@thu:  add  word ptr [Tt4],600 ; the LEVER moves; the spool follows
        cmp  word ptr [Tt4],18000
        jle  @@loop             ; full military power
        mov  word ptr [Tt4],18000
        jmp  @@loop
@@thd:  sub  word ptr [Tt4],600
        cmp  word ptr [Tt4],250
        jge  @@loop
        mov  word ptr [Tt4],250
        jmp  @@loop
@@nd:   sub  word ptr [alpha8],40
        cmp  word ptr [alpha8],1024
        jge  @@loop
        mov  word ptr [alpha8],1024
        jmp  @@loop
@@nu:   add  word ptr [alpha8],40
        cmp  word ptr [alpha8],4352
        jle  @@loop
        mov  word ptr [alpha8],4352
        jmp  @@loop
@@sp:   mov  al,[state]
        or   al,al              ; idle -> fly the approach
        jz   @@go
        cmp  al,6               ; stopped -> around again
        jne  @@loop
@@go:   call RESETF
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

; ---- RESETF: park a fresh jet on the slab ----------------------------------
RESETF: mov  byte ptr [state],1
        mov  word ptr [h6],H0
        mov  word ptr [hac],0
        mov  word ptr [vs64],0
        mov  word ptr [vsac],0
        mov  word ptr [v16],V0
        mov  word ptr [vacc],0
        mov  word ptr [alpha8],3072
        mov  word ptr [T4],250
        mov  word ptr [Tt4],250
        mov  word ptr [posm],1200
        mov  word ptr [posacc],0
        mov  word ptr [odo],0
        mov  word ptr [hrow],95
        mov  byte ptr [gear],1
        mov  byte ptr [flaps],0
        mov  byte ptr [brk],0
        mov  byte ptr [air],0
        mov  byte ptr [flew],0
        ret

; ---- TICK: one 55 ms step - no controllers, no script: just you ------------
TICK:   inc  word ptr [tcnt]
        call DBGTICK            ; drain the umbilical, apply its hands
        mov  al,[state]
        or   al,al
        jz   @@idle
        cmp  al,1
        je   @@fly
        ret                     ; state 6: hold the card
@@idle: ; ---- parked on the card, engine at idle ----
        test word ptr [tcnt],7
        jnz  @@done
        call RND16
        and  ax,1
        add  al,TCAPP
        mov  [curtc],al
        call SETTC
        ret
@@fly:  cmp  byte ptr [air],0   ; tail protection on the ground
        jne  @@fl1
        cmp  word ptr [alpha8],3840
        jle  @@fl1
        mov  word ptr [alpha8],3840
@@fl1:  call PHYSL
        call ATT
        call ENG
        cmp  byte ptr [air],0   ; flown and rolled to a stop?
        jne  @@done
        cmp  byte ptr [flew],0
        je   @@done
        cmp  word ptr [v16],0
        jg   @@done
        mov  byte ptr [state],6
        mov  word ptr [cardp],offset MDONE
@@done: ret

; ---- PHYSL: Newton per tick, landing configuration -------------------------
; L8 = v^2*alpha8/1082 (962 in ground effect below 9 m); sink and
; speed integrate in 8.8 with signed remainders; gravity feeds the
; speed while sinking (460*vs/vm); brakes join on the ground. The
; world odometer advances for the stripes - and no seam clicks.
PHYSL:  mov  bx,[Tt4]           ; the spool: thrust CHASES the lever
        sub  bx,[T4]            ; (~1.5 s time constant - and the note
        jz   @@sp0              ; rides the real thrust, so you HEAR
        mov  ax,bx              ; the turbine wind up and down)
        cwd
        mov  cx,16
        idiv cx
        or   ax,ax
        jnz  @@sp1
        mov  ax,1
        or   bx,bx
        jns  @@sp1
        neg  ax
@@sp1:  add  [T4],ax
@@sp0:  mov  ax,[v16]
        mov  cl,4
        shr  ax,cl
        or   ax,ax
        jnz  @@vg
        mov  ax,1               ; never divide by a parked jet
@@vg:   mov  [vmv],ax
        mul  ax
        mov  [v2v],ax
        mov  cx,1241            ; the clean wing...
        cmp  byte ptr [flaps],0
        je   @@k1
        mov  cx,1082            ; ...FLAPS grow it
@@k1:   cmp  word ptr [h6],576
        jae  @@k2               ; (unsigned, like every h6 compare)
        mov  ax,cx              ; ground effect: ~12% more lift
        mov  bx,8
        xor  dx,dx
        div  bx
        sub  cx,ax
@@k2:   mov  ax,[vs64]          ; the wing flies in the RELATIVE wind:
        push cx                 ;   alpha_eff = alpha + 229*vs/v
        mov  cx,229             ; (sink raises it, climb sheds it -
        imul cx                 ;  this is what stops a runaway zoom)
        mov  bx,[vmv]
        cmp  bx,16
        jae  @@w16
        mov  bx,16              ; divisor floor keeps the idiv sane
@@w16:  idiv bx
        add  ax,[alpha8]
        cmp  ax,256
        jge  @@ae1
        mov  ax,256
@@ae1:  cmp  ax,4608
        jle  @@ae2
        mov  ax,4608
@@ae2:  mov  bx,ax
        pop  cx
        mov  ax,[v2v]
        mul  bx
        cmp  dx,cx              ; the quotient would burst the word -
        jb   @@ldv              ; saturate (a wing has limits; so does
        mov  ax,60000           ; a 16-bit DIV, and it FAULTS: this was
        jmp  @@lst              ; the mystery freeze past ~550 km/h)
@@ldv:  div  cx
@@lst:  mov  [lgv],ax           ; the full value feeds the G readout;
        cmp  ax,29000           ; dynamics gets a signed-safe copy
        jbe  @@lok              ; (a lift word past 32767 flipped the
        mov  ax,29000           ; sink command's sign - bug four of
@@lok:  mov  [l8v],ax           ; the signed family)
        cmp  byte ptr [air],0
        jne  @@l2
        cmp  ax,14715           ; on the wheels: the wing takes it?
        jbe  @@gnd
        mov  byte ptr [air],1   ; liftoff - by lift, as always
        mov  byte ptr [flew],1
        call UNLOAD
        jmp  @@l2
@@gnd:  mov  word ptr [vs64],0
        mov  word ptr [h6],HGEAR
        cmp  byte ptr [gear],0  ; rolling with no legs: the belly
        jne  @@gok              ; grinds and the day is over
        cmp  word ptr [v16],32
        jle  @@gok
        mov  byte ptr [state],6
        mov  word ptr [cardp],offset MBELLY
@@gok:  jmp  @@long
@@l2:   mov  ax,14715           ; dvs(8.8) = (mg/8 - L8)*3/5
        sub  ax,[l8v]
        jno  @@dv1              ; saturated wing overflowed the signed
        mov  ax,-30000          ; word and FLIPPED into "sink" - cap
@@dv1:  mov  cx,3               ; the surge instead (the 4.0G-at-0-m
        imul cx                 ; screenshot found this one)
        mov  cx,5
        idiv cx
        mov  [dvsdbg],ax        ; umbilical: the raw command
        add  ax,[vsac]
        mov  cx,256
        cwd
        idiv cx
        add  [vs64],ax
        mov  [vsac],dx
        cmp  word ptr [vs64],2000 ; +-31 m/s vertical is the world's
        jle  @@vc1                ; edge (and every imul stays safe)
        mov  word ptr [vs64],2000
@@vc1:  cmp  word ptr [vs64],-2000
        jge  @@vc2
        mov  word ptr [vs64],-2000
@@vc2:  mov  ax,[vs64]          ; h -= vs: 14/256 of a unit per tick
        mov  cx,14
        imul cx
        add  ax,[hac]
        mov  cx,256
        cwd
        idiv cx
        sub  [h6],ax
        mov  [hac],dx
        cmp  word ptr [h6],62000 ; this little world has a lid.
        jbe  @@ce               ; UNSIGNED: 62000 is -3536 as a signed
        mov  word ptr [h6],62000 ; word, and the signed jle held the
        mov  word ptr [vs64],0  ; jet in a lid-floor trap forever
@@ce:   cmp  word ptr [h6],HGEAR ; down at the slab?
        ja   @@long
        cmp  word ptr [vs64],16 ; only a real SINK is a touch; a
        jg   @@tch              ; marginal liftoff rides the deck
        mov  word ptr [h6],HGEAR ; until the climb is honest
        jmp  @@long
@@tch:  call TOUCH
@@long: mov  ax,[v2v]           ; D4 = cdx*v^2/400: 1.00 clean,
        mov  cx,100             ; +0.25 gear, +0.25 flaps
        cmp  byte ptr [gear],0
        je   @@dg
        add  cx,25
@@dg:   cmp  byte ptr [flaps],0
        je   @@df
        add  cx,25
@@df:   mul  cx
        mov  cx,400
        div  cx
        mov  bx,[T4]
        sub  bx,ax
        cmp  byte ptr [air],0
        jne  @@fr0
        sub  bx,883             ; rolling friction...
        cmp  byte ptr [brk],0
        je   @@fr0
        sub  bx,7400            ; ...and the brakes
@@fr0:  mov  ax,[vs64]          ; downhill feeds the speed
        mov  cx,460
        imul cx
        mov  cx,[vmv]
        cmp  cx,32
        jae  @@gv1
        mov  cx,32              ; divisor floor keeps the idiv signed
@@gv1:  idiv cx
        add  bx,ax
        mov  ax,bx              ; dv16(8.8) = N4*256/3412
        mov  cx,256
        imul cx
        mov  cx,3412
        idiv cx
        add  ax,[vacc]
        mov  cx,256
        cwd
        idiv cx
        add  [v16],ax
        mov  [vacc],dx
        cmp  word ptr [v16],0
        jge  @@vf
        mov  word ptr [v16],0
@@vf:   cmp  word ptr [v16],3840 ; ~240 m/s: v^2 must stay in a word
        jle  @@l4
        mov  word ptr [v16],3840
@@l4:   mov  ax,[v16]           ; the world rolls by (metres, 8.8)
        mov  bx,ax
        mov  cl,3
        sar  bx,cl
        sub  ax,bx
        add  ax,[posacc]
        mov  bx,ax
        mov  cl,8
        shr  bx,cl
        add  [posm],bx
        and  ax,255
        mov  [posacc],ax
        cmp  word ptr [posm],PWRAP
        jb   @@pw
        sub  word ptr [posm],PWRAP
@@pw:   mov  ax,[v16]           ; stripe odometer, 1/16 m
        xor  dx,dx
        mov  bx,18
        div  bx
        add  [odo],ax
        cmp  word ptr [odo],SEAM
        jb   @@l5
        sub  word ptr [odo],SEAM
@@l5:   ret

; ---- ATT: attitude = alpha + flight path, mapped to the horizon row --------
; theta = alpha - gamma; gamma(8.8 deg) = 229*vs/vm. The nose-up creep
; through the float is this line doing its job.
ATT:    cmp  byte ptr [air],0
        jne  @@aa
        mov  word ptr [fpr],0   ; on the wheels there is no flight path
        mov  bx,[alpha8]        ; on the ground the nose IS the alpha
        sub  bx,3072
        mov  cl,5
        sar  bx,cl
        add  bx,95
        jmp  @@ac
@@aa:   mov  ax,[vs64]
        mov  cx,229
        imul cx
        mov  cx,[vmv]
        cmp  cx,16
        jae  @@ag1
        mov  cx,16              ; divisor floor, same signed-idiv rule
@@ag1:  idiv cx
        mov  cl,5               ; the same 8 px per degree serves both
        mov  bx,ax              ; gamma in ROWS: the FPI rides this far
        sar  bx,cl              ; below the horizon (sink is positive)
        mov  [fpr],bx
        mov  bx,[alpha8]
        sub  bx,ax
        sub  bx,2400            ; approach trim = the baseline view
        sar  bx,cl
        add  bx,95
@@ac:   cmp  bx,60
        jge  @@a1
        mov  bx,60
@@a1:   cmp  bx,170
        jle  @@a2
        mov  bx,170
@@a2:   mov  [hrow],bx
        ret

; ---- ENG: the note follows the REAL throttle and the REAL load -------------
; TC = 96 + T4/32 - (alpha-12)/128 + vs/64: power raises it, pulling
; drags it down (working hard), sinking frees it (downhill is easy).
ENG:    mov  ax,[T4]
        mov  cl,7
        shr  ax,cl
        add  ax,90
        mov  bx,[alpha8]
        sub  bx,3072
        mov  cl,7
        sar  bx,cl
        sub  ax,bx
        mov  bx,[vs64]
        mov  cl,6
        sar  bx,cl
        add  ax,bx
        cmp  ax,78
        jge  @@e1
        mov  ax,78
@@e1:   cmp  ax,160
        jle  @@e2
        mov  ax,160
@@e2:   cmp  [curtc],al
        je   @@e3
        mov  [curtc],al
        call SETTC
@@e3:   ret

; ---- KNOCK: one knock into the ring, amplitude in [bamp] -------------------
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

; ---- UNLOAD: the liftoff clunk - mains unload, then the nose strut ---------
UNLOAD: push es
        mov  ax,[sndseg]
        mov  es,ax
        call SFXRAW
        lea  di,[bx+700]
        and  di,SNDN-1
        mov  dx,-34             ; the mains
        mov  cx,16
@@u1:   call SFXMB
        loop @@u1
        mov  dx,17
        mov  cx,16
@@u2:   call SFXMB
        loop @@u2
        add  di,330             ; ~30 ms later...
        and  di,SNDN-1
        mov  dx,-22             ; ...the nose strut
        mov  cx,14
@@u3:   call SFXMB
        loop @@u3
        mov  dx,11
        mov  cx,14
@@u4:   call SFXMB
        loop @@u4
        pop  es
        ret

; ---- TOUCH: the wheels meet the world - and the world judges ---------------
TOUCH:  mov  word ptr [h6],HGEAR
        cmp  byte ptr [gear],0  ; no legs? the belly grinds
        jne  @@t1
        mov  byte ptr [state],6
        mov  word ptr [cardp],offset MBELLY
        ret
@@t1:   cmp  word ptr [vs64],256 ; over 4 m/s down: broken
        jle  @@t2
        mov  byte ptr [state],6
        mov  word ptr [cardp],offset MSLAM
        ret
@@t2:   mov  ax,[posm]          ; on the concrete at all?
        sub  ax,THRESH
        jns  @@t3
        add  ax,PWRAP
@@t3:   xor  dx,dx
        mov  cx,RWGAP
        div  cx
        cmp  dx,RWLEN
        jbe  @@t4
        mov  byte ptr [state],6
        mov  word ptr [cardp],offset MGRASS
        ret
@@t4:   mov  ax,[vs64]          ; a fair touch: the kiss, loud as the
        cmp  ax,36              ; sink it arrived with
        jge  @@t5
        mov  ax,36
@@t5:   xor  dx,dx
        mov  cx,3
        div  cx
        cmp  ax,70
        jle  @@t6
        mov  ax,70
@@t6:   mov  [bamp],ax
        call KNOCK
        mov  byte ptr [air],0
        mov  word ptr [vs64],0
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
        ; ---- the gentle sway (a PARKED jet stands still) ----
        inc  word ptr [swph1]
        mov  ax,[swph1]
        call TRI
        mov  cl,4
        sar  ax,cl              ; -1..+1 rows
        cmp  byte ptr [air],0
        jne  @@sw1
        cmp  word ptr [v16],320 ; below ~20 m/s on the wheels: rock
        jae  @@sw1              ; nothing
        xor  ax,ax
@@sw1:  add  ax,[hrow]
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
        cmp  byte ptr [air],0   ; parked: no lateral drift either
        jne  @@sw2
        cmp  word ptr [v16],320
        jae  @@sw2
        xor  ax,ax
@@sw2:  add  ax,160
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
        cmp  dx,bx              ; past ~290 m the far rows overflow
        jb   @@dm1              ; this DIV and FAULT the CPU - the
        mov  ax,0FFFFh          ; long-flight hang. Far is just far:
        jmp  @@dm2              ; saturate
@@dm1:  div  bx
@@dm2:
        or   ax,ax
        jnz  @@d1
        inc  ax                 ; never zero
@@d1:   mov  [dmv],ax
        mov  bx,si              ; shared shade: linear in SCREEN rows -
        mov  cl,3               ; the TKOFF look (distance-linear
        shl  bx,cl              ; clumped the whole wedge dark and
        cmp  bx,1023            ; killed the checker)
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
        cmp  word ptr [dmv],4000 ; beyond ~4 km no runway is visible -
        ja   @@norwy             ; and a saturated row once got e=0,
                                 ; and LOOP with CX=0 spins 65536 times:
                                 ; the grey-sky screenshot
        mov  ax,[posm]          ; runways repeat every 12 km: fold the
        add  ax,[dmv]           ; world and test the remainder
        jnc  @@r0
        add  ax,5536            ; wrapped past 65536: fold into 60000
        jmp  @@r1
@@r0:   cmp  ax,PWRAP
        jb   @@r1
        sub  ax,PWRAP
@@r1:   sub  ax,THRESH
        jns  @@r2
        add  ax,PWRAP
@@r2:   xor  dx,dx
        mov  cx,RWGAP
        div  cx
        cmp  dx,RWLEN
        jg   @@norwy
        mov  [relv],dx
        mov  ax,9750            ; edge half-width: matched to TKOFF's
        xor  dx,dx              ; tape-calibrated wide flat wedge
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
        mov  ax,195             ; stripe half-width, scaled with the
        xor  dx,dx              ; widened wedge
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
        sub  ax,HGEAR           ; (h6 can top 32767: stay unsigned)
        jnc  @@ha
        xor  ax,ax
@@ha:   mov  cl,2
        shr  ax,cl              ; 1/64 m -> 1/16 m
        mov  [alt16],ax
        call HUD
        ; ---- the config lights: what is hanging in the wind ----
        cmp  byte ptr [state],0
        je   @@nap
        mov  byte ptr [tcol],21
        cmp  byte ptr [gear],0
        je   @@lg1
        mov  si,offset LGEAR
        mov  ax,188
        mov  bx,4
        call TXT
@@lg1:  cmp  byte ptr [flaps],0
        je   @@lg2
        mov  si,offset LFLAP
        mov  ax,188
        mov  bx,48
        call TXT
@@lg2:  cmp  byte ptr [brk],0
        je   @@lg3
        mov  si,offset LBRK
        mov  ax,188
        mov  bx,92
        call TXT
@@lg3:  cmp  byte ptr [air],0   ; the wing is on the edge of quitting
        je   @@nap
        mov  ax,[kmh]
        cmp  ax,[vstl]
        jae  @@nap
        mov  byte ptr [tcol],22
        mov  si,offset LSTALL
        mov  ax,188
        mov  bx,136
        call TXT
@@nap:  ; ---- the cards ----
        cmp  byte ptr [state],0
        jne  @@c1
        mov  byte ptr [tcol],5
        mov  si,offset MTITLE
        mov  ax,180
        mov  bx,36
        call TXT
        jmp  @@cdone
@@c1:   cmp  byte ptr [state],6
        jne  @@cdone
        mov  byte ptr [tcol],5
        mov  si,[cardp]
        mov  ax,180
        mov  bx,44
        call TXT
@@cdone:
        pop  es
        ret

; ---- HUD: the F-15 standard, metric (see FLIGHT.ASM for the story) ---------
HUD:    call LADR               ; the ladder goes down FIRST: everything
                                ; else is allowed to write over it
        mov  ax,[v16]
        mov  cx,9
        mul  cx
        mov  cx,40
        div  cx
        mov  [kmh],ax
        mov  ax,[kmh]
        sub  ax,120             ; the tape spans +-120 km/h now: rows
        jns  @@s0               ; 40..160, near the full height of the
        xor  ax,ax              ; glass, the way the manual draws it
@@s0:   add  ax,19
        xor  dx,dx
        mov  cx,20
        div  cx
        mul  cx
        mov  [tm],ax
@@sl:   mov  ax,[tm]
        mov  bx,[kmh]
        add  bx,120
        cmp  ax,bx
        jg   @@sdone
        mov  bx,[kmh]
        sub  bx,ax
        sar  bx,1
        add  bx,100
        mov  [ty],bx
        cmp  bx,40
        jl   @@snext
        cmp  bx,160
        jg   @@snext
        mov  ax,[tm]
        xor  dx,dx
        mov  cx,100
        div  cx
        or   dx,dx
        jnz  @@smin
        mov  ax,[ty]
        call ROWAD
        add  ax,24
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
        mov  bx,8
        call FDR
        jmp  @@snext
@@smin: mov  ax,[ty]
        call ROWAD
        add  ax,28
        mov  di,ax
        mov  cx,5
@@st2:  mov  byte ptr es:[di],15
        inc  di
        loop @@st2
@@snext:add  word ptr [tm],20
        jmp  @@sl
@@sdone:mov  di,100*320+34
        mov  cx,8
@@sd:   mov  byte ptr es:[di],15
        inc  di
        loop @@sd
        mov  ax,[kmh]
        call NUM
        mov  si,offset NBUF+2
        mov  ax,97
        mov  bx,44
        call FDR
        ; the manual's Landing Speed Indicator: a cyan tick riding the
        ; tape at 234 km/h (the measured 65 m/s kiss)
        mov  bx,[kmh]
        sub  bx,234
        sar  bx,1
        add  bx,100
        cmp  bx,41
        jl   @@nls
        cmp  bx,159
        jg   @@nls
        mov  ax,bx
        call ROWAD
        add  ax,22
        mov  di,ax
        mov  cx,6
@@ls2:  mov  byte ptr es:[di],21
        inc  di
        loop @@ls2
@@nls:  ; the manual's Stall Speed Indicator: the wing quits below this
        ; tick, and everything under it on the tape is red. FLAPS move
        ; it down 15 km/h - that is what they are FOR.
        mov  ax,VSTLC
        cmp  byte ptr [flaps],0
        je   @@ss0
        mov  ax,VSTLF
@@ss0:  mov  [vstl],ax
        cmp  byte ptr [air],0   ; parked and rolling you are ALWAYS below
        je   @@nst              ; it: the band would just paint the tape
        mov  bx,[kmh]
        sub  bx,ax
        sar  bx,1
        add  bx,100
        cmp  bx,160
        jg   @@nst              ; the whole band is below the glass
        cmp  bx,41
        jge  @@ss1
        mov  bx,41              ; ...or the whole tape is in the red
@@ss1:  mov  ax,bx
        call ROWAD
        add  ax,22
        mov  di,ax
        mov  cx,6
@@ss2:  mov  byte ptr es:[di],22
        inc  di
        loop @@ss2
        mov  ax,bx
@@ss3:  add  ax,2               ; the band, every other row
        cmp  ax,160
        jg   @@nst
        push ax
        call ROWAD
        add  ax,22
        mov  di,ax
        mov  byte ptr es:[di],22
        mov  byte ptr es:[di+1],22
        pop  ax
        jmp  @@ss3
@@nst:  ; altitude tape, right
        mov  ax,[alt16]
        mov  cl,4
        shr  ax,cl
        mov  [alm],ax
        mov  ax,[alm]
        sub  ax,600             ; +-600 m over the same 120 rows
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
        add  bx,600
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
        cmp  ax,40
        jl   @@anext
        cmp  ax,160
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
        add  ax,287
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
        mov  bx,298
        call FDR
        jmp  @@anext
@@amin: mov  ax,[ty]
        call ROWAD
        add  ax,287
        mov  di,ax
        mov  cx,5
@@at2:  mov  byte ptr es:[di],15
        inc  di
        loop @@at2
@@anext:add  word ptr [tm],100
        jmp  @@al
@@adone:mov  di,100*320+276
        mov  cx,8
@@ad:   mov  byte ptr es:[di],15
        inc  di
        loop @@ad
        mov  ax,[alm]
        call NUM
        mov  si,offset NBUF+1
        mov  ax,97
        mov  bx,258
        call FDR
        ; the manual's VVI: a cyan caret sliding with the sink
        mov  bx,[vs64]
        mov  cl,4               ; 1 px = 0.25 m/s. At the old 0.125 the
        sar  bx,cl              ; caret sat on the stop through every
        add  bx,100             ; climb; +-15 m/s is the honest range
        cmp  bx,42
        jge  @@v1
        mov  bx,42
@@v1:   cmp  bx,158
        jle  @@v2
        mov  bx,158
@@v2:   mov  ax,bx
        call ROWAD
        add  ax,285
        mov  di,ax              ; the manual's caret: a triangle whose
        mov  byte ptr es:[di],21          ; tip touches the tape
        mov  byte ptr es:[di+1],21
        mov  byte ptr es:[di+2],21
        mov  byte ptr es:[di-320],21
        mov  byte ptr es:[di-320+1],21
        mov  byte ptr es:[di+320],21
        mov  byte ptr es:[di+320+1],21
        mov  byte ptr es:[di-640],21
        mov  byte ptr es:[di+640],21
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
        ; the INS job in a world with no yaw: not WHICH way the slab is
        ; (always straight ahead) but HOW FAR - the number that decides
        ; when the descent starts.
        mov  ax,[posm]
        sub  ax,THRESH
        jnc  @@r1
        add  ax,PWRAP
@@r1:   xor  dx,dx
        mov  cx,RWGAP
        div  cx
        mov  ax,RWGAP
        sub  ax,dx              ; metres to the NEXT threshold
        xor  dx,dx
        mov  cx,1000
        div  cx
        mov  bx,ax              ; bx = km
        mov  ax,dx
        xor  dx,dx
        mov  cx,100
        div  cx
        add  al,'0'
        mov  [RBUF+3],al        ; the tenth
        mov  ax,bx
        xor  dx,dx
        mov  cx,10
        div  cx
        or   al,al
        jz   @@r2
        add  al,'0'
        mov  [RBUF],al
        jmp  @@r3
@@r2:   mov  byte ptr [RBUF],' '
@@r3:   add  dl,'0'
        mov  [RBUF+1],dl
        mov  byte ptr [fcol],21
        mov  si,offset RBUF
        mov  ax,24
        mov  bx,148
        call FDR
        mov  byte ptr [fcol],15
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
        call FPIND
        ; ---- the AoA staple, left of the datum: live in the bracket ----
        mov  di,90*320+140
        mov  cx,21
@@ao1:  mov  byte ptr es:[di],15
        add  di,320
        loop @@ao1
        mov  byte ptr es:[90*320+138],15
        mov  byte ptr es:[90*320+139],15
        mov  byte ptr es:[110*320+138],15
        mov  byte ptr es:[110*320+139],15
        mov  ax,[alpha8]        ; the caret is YOUR alpha, 13 centred;
        sub  ax,3328            ; drift above the bracket and the wing
        cwd                     ; is about to give up
        mov  cx,26
        idiv cx
        neg  ax
        add  ax,100
        cmp  ax,88
        jge  @@ao2
        mov  ax,88
@@ao2:  cmp  ax,112
        jle  @@ao3
        mov  ax,112
@@ao3:  call ROWAD
        add  ax,136
        mov  di,ax
        mov  byte ptr es:[di],21
        mov  byte ptr es:[di+1],21
        mov  byte ptr es:[di+2],21
        mov  byte ptr es:[di+1-320],21
        mov  byte ptr es:[di+1+320],21
        ; ---- the G readout over the speed tape (the manual's corner) ----
        mov  ax,[lgv]           ; n = L/mg, straight from the physics
        mov  cx,10
        mul  cx
        mov  cx,14715
        div  cx
        xor  dx,dx
        mov  cx,10
        div  cx
        add  al,'0'
        mov  [ABUF],al
        mov  byte ptr [ABUF+1],'.'
        add  dl,'0'
        mov  [ABUF+2],dl
        mov  byte ptr [ABUF+3],'G'
        mov  byte ptr [ABUF+4],0
        mov  si,offset ABUF
        mov  ax,24
        mov  bx,6
        call FDR
        ret

; ---- LADR: the pitch lines, every 5 degrees, riding the WORLD --------------
; ATT maps a degree of attitude onto 8 screen rows, so 5 degrees is a
; clean 40 px. Solid above the horizon, dotted below - the old rule -
; and dim, because the horizon itself is the loud line. The gap in the
; middle (x131..x189) is left for the datum, the FPI and the staple.
; Caller has ES = the back buffer.
LADR:   cmp  byte ptr [air],0   ; on the wheels there is nothing to read
        je   @@done
        mov  word ptr [lp],-10
@@l:    cmp  word ptr [lp],0
        je   @@next             ; zero belongs to the world, not to us
        mov  bx,[lp]
        mov  cl,3
        shl  bx,cl              ; P * 8 rows
        mov  ax,[hcur]
        sub  ax,bx              ; up the screen is up the ladder
        cmp  ax,40
        jl   @@next
        cmp  ax,160
        jg   @@next
        mov  [ty],ax
        mov  dx,1               ; solid...
        mov  cx,32
        cmp  word ptr [lp],0
        jg   @@l1
        mov  dx,2               ; ...dotted below the horizon
        mov  cx,16
@@l1:   mov  ax,[ty]
        call ROWAD
        add  ax,100
        mov  di,ax
@@l2:   mov  byte ptr es:[di],23
        add  di,dx
        loop @@l2
        mov  cx,32
        cmp  word ptr [lp],0
        jg   @@l3
        mov  cx,16
@@l3:   mov  ax,[ty]
        call ROWAD
        add  ax,189
        mov  di,ax
@@l4:   mov  byte ptr es:[di],23
        add  di,dx
        loop @@l4
        mov  ax,[lp]            ; the label at the left end
        or   ax,ax
        jg   @@l5
        neg  ax
        mov  byte ptr [LBUF],'-'
        jmp  @@l6
@@l5:   mov  byte ptr [LBUF],' '
@@l6:   xor  dx,dx
        mov  cx,10
        div  cx
        add  al,'0'
        mov  [LBUF+1],al
        add  dl,'0'
        mov  [LBUF+2],dl
        mov  byte ptr [fcol],23
        mov  si,offset LBUF
        mov  ax,[ty]
        sub  ax,2
        mov  bx,84
        call FDR
        mov  byte ptr [fcol],15
@@next: add  word ptr [lp],5
        cmp  word ptr [lp],10
        jle  @@l
@@done: ret

; ---- FPIND: the Flight Path Indicator - where the jet is REALLY going ------
; The circle sits gamma below the horizon, so it marks the spot the
; nose is merely pointing NEAR. On final you fly the CIRCLE onto the
; threshold; the gap up to the datum is the angle of attack, and the
; manual says that gap is normal.
FPIND:  cmp  byte ptr [air],0
        je   @@done
        mov  ax,[hcur]
        add  ax,[fpr]
        cmp  ax,44
        jge  @@f1
        mov  ax,44
@@f1:   cmp  ax,156
        jle  @@f2
        mov  ax,156
@@f2:   call ROWAD
        add  ax,160
        mov  di,ax
        mov  si,offset FPIT
@@f3:   lodsb
        cmp  al,80h
        je   @@done
        cbw
        mov  bx,ax              ; dx, signed
        lodsb
        cbw
        mov  cx,320
        imul cx                 ; dy * 320
        add  bx,ax
        add  bx,di
        mov  byte ptr es:[bx],15
        jmp  @@f3
@@done: ret

; the circle, its wings and the stem, as (dx,dy) pairs
FPIT    db  -1,-3,  0,-3,  1,-3
        db  -2,-2,  2,-2
        db  -3,-1,  3,-1
        db  -3, 0,  3, 0
        db  -3, 1,  3, 1
        db  -2, 2,  2, 2
        db  -1, 3,  0, 3,  1, 3
        db  -7, 0, -6, 0, -5, 0, -4, 0
        db   4, 0,  5, 0,  6, 0,  7, 0
        db   0,-6,  0,-5,  0,-4
        db  80h

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
        jne  @@dot
        mov  al,10
        jmp  @@i
@@dot:  cmp  al,'.'
        jne  @@gee
        mov  al,11
        jmp  @@i
@@gee:  cmp  al,'G'
        jne  @@mns
        mov  al,12
        jmp  @@i
@@mns:  cmp  al,'-'             ; the ladder's minus
        jne  @@emm
        mov  al,13
        jmp  @@i
@@emm:  cmp  al,'M'             ; the range's kilo-METRES
        jne  @@d
        mov  al,14
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
        mov  al,[fcol]          ; white, or dim for the ladder, or cyan
        push cx
        mov  cx,3
@@p:    shl  ah,1
        jnc  @@n
        mov  es:[di],al
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
DFILL:  jcxz @@z                ; CX=0 must mean zero, not 65536
        push bx
        mov  bx,di
        and  bx,3
@@f:    mov  al,[PATT+bx]
        stosb
        inc  bx
        and  bx,3
        loop @@f
        pop  bx
@@z:    ret

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
        db  22, 63,20,10        ; HUD red: the stall band and its light
        db  23, 34,36,40        ; HUD dim: the pitch ladder - DARKER than
        db 255                  ; the clouds and lighter than the grass,
                                ; because white vanished into the cumulus

; ---- data ------------------------------------------------------------------
NOSB    db 'No Sound Blaster at 220h.',13,10,'$'
MTITLE  db 'SOLO: ARROWS +- L F B - SPACE',0
MDONE   db 'SOLO COMPLETE - SPACE',0
MSLAM   db 'HARD LANDING - SPACE',0
MBELLY  db 'GEAR UP - BELLY SCRAPE - SPACE',0
MGRASS  db 'OFF THE CONCRETE - SPACE',0
LGEAR   db 'GEAR',0
LFLAP   db 'FLAP',0
LBRK    db 'BRK',0
LSTALL  db 'STALL',0
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
        db 00000000b,00000000b,00000000b,00000000b,01000000b,00000000b ; dot
        db 01100000b,10000000b,10100000b,10100000b,01100000b,00000000b ; G
        db 00000000b,00000000b,11100000b,00000000b,00000000b,00000000b ; -
        db 10100000b,11100000b,11100000b,10100000b,10100000b,00000000b ; M
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
vacc    dw 0                    ; speed integrator remainder (8.8)
h6      dw H0                   ; camera height AGL, 1/64 m
hac     dw 0                    ; height integrator remainder
vs64    dw 0                    ; sink rate, 1/64 m/s (+down)
vsac    dw 0                    ; sink integrator remainder
alpha8  dw 3072                 ; angle of attack, 8.8 units (12.0)
T4      dw 250                  ; thrust/4, N (chases the lever)
vmv     dw 72                   ; scratch: v in m/s
v2v     dw 5184                 ; scratch: v^2
l8v     dw 0                    ; scratch: lift/8, capped for dynamics
lgv     dw 0                    ; scratch: lift/8 uncapped (G readout)
posm    dw 0                    ; world position, metres
posacc  dw 0                    ; its 8.8 accumulator
odo     dw 0                    ; odometer mod 61 m, 1/16 m
Tt4     dw 250                  ; the throttle LEVER
gear    db 1                    ; 1 = legs out
flaps   db 0                    ; 1 = flaps out
brk     db 0                    ; 1 = brakes gripping
air     db 0                    ; 1 = the wing carries the weight
flew    db 0                    ; has been airborne this attempt
cardp   dw MTITLE               ; which card state 6 shows
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
fpr     dw 0                    ; flight path below the horizon, rows
lp      dw 0                    ; ladder walker, degrees
vstl    dw VSTLC                ; stall speed for THIS configuration
tcol    db 5                    ; TXT colour (amber cards)
fcol    db 15                   ; FDR colour (white unless told otherwise)
NBUF    db 6 dup(0)             ; NUM scratch
ABUF    db 6 dup(0)             ; altitude / G-readout scratch
LBUF    db '   ',0              ; ladder label scratch
RBUF    db '  .0KM',0           ; range-to-the-slab scratch
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

        INCLUDE SOLODBG.INC
        INCLUDE ..\ENGINE\E_MATH.INC
        INCLUDE ..\ENGINE\E_SND.INC

CODE    ENDS
        END START
