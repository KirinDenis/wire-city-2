; ============================================================================
;  NEWTON.COM - WIRE CITY: the aeroplane with every axis, flown by force
;
;  Forked from EXAMPLES\SOLO.ASM (engine example 12) on the day its
;  landing model was trusted. SOLO is a two-axis machine in a corridor;
;  NEWTON is meant to grow the rest - ailerons, rudder, a world with a
;  compass, loops and rolls - WITHOUT giving up the thing that made
;  SOLO feel right: every motion comes from a force on a mass, never
;  from a rate we picked because it looked good. TRAINER already flies
;  the other way (angles that turn at a chosen rate, ported from OWL
;  FLY); this is the honest branch, and the two are not meant to meet.
;
;  Milestone 1 (this file, right now): SOLO moved house unchanged. The
;  same parked start, the same lift-decides rotation, the same landing
;  judgement, the same HUD. Nothing new flies yet - the point of the
;  step is that the old flight still does, on the new foundation.
;
;  The road from here, one milestone per flight test:
;    2. sky and ground drawn by the LINE horizon (FLIGHT.ASM's trick):
;       the world learns to tilt, roll still nailed to zero
;    3. the runway as a projected quad (TRAINER's GQUAD) so it survives
;       the tilt - without it there is nothing to land on in a bank
;    4. ailerons on the left/right arrows: roll as a state, its rate
;       from aileron authority (~v^2), and the turn that follows from
;       the tilted lift vector - the G readout finally earns its place
;    5. rudder and a real sideslip; crosswind approaches
;    6. pitch through the vertical: loops, rolls, the gimbal
;
;  The old briefing, still true of the flight itself:
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
RWGAP   equ 16384               ; a fresh runway every 16 384 m. Power of
                                ; two ON PURPOSE: the world is 65 536 m
                                ; around (posm wraps with the WORD), the
                                ; heightmap is 64 nodes of 1024 m - the
                                ; torus, the runways and the arithmetic
                                ; all close at the same seam, which is
                                ; to say: no seam at all
TNODE   equ 1024                ; heightmap node spacing, metres
NEARD   equ 8                   ; the near plane, metres. It was 48 and
                                ; the bottom of the glass looked at
                                ; ground 15..47 m away - an amputated
                                ; band the pilot read as falling through
                                ; the world. Eight covers the deepest
                                ; visible row from gear height in the
                                ; worst low bank, with margin
NR      equ 12                  ; terrain cache radius, nodes (12 km)
NSIDE   equ 25                  ; the cached lattice is NSIDE x NSIDE
SEAM    equ 976                 ; stripe cycle, 1/16 m (61 m)
PAINT   equ 592                 ; painted part, 1/16 m (37 m)
CALIB   equ 0                   ; 1 = the CALIBRATION WORLD: flat, and
                                ; every 1024 m node square wears a colour
                                ; that is a pure function of its world
                                ; coordinates - so what the eye sees can
                                ; be CHECKED against where things are.
                                ; Flip to 0 for the real island.
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
        mov  si,0               ; the sky's tile rows never move
@@ts:   mov  ax,si
        and  ax,15
        mov  cl,4
        shl  ax,cl
        mov  [TSKY+si],al
        inc  si
        cmp  si,256
        jb   @@ts
        push es                 ; ---- mint this run's island ----
        mov  ax,40h             ; seed the LCG from the clock: every
        mov  es,ax              ; launch grows a DIFFERENT world (the
        mov  ax,es:[6Ch]        ; noise bed downstream neither knows
        pop  es                 ; nor cares which noise it gets)
        or   ax,1               ; the LCG must never see zero
        mov  [rseed],ax
        call DSGEN
IF CALIB EQ 1
        xor  si,si              ; the calibration world is a BILLIARD
@@cfl:  mov  byte ptr [HMAP+si],88 ; TABLE: raw 88 = sea level = flat.
        inc  si                 ; No hills to hide behind: if a square
        cmp  si,4096            ; dances, the RENDERER danced it
        jb   @@cfl
ENDIF
IF CALIB EQ 2
        ; the PYRAMID: one mountain owning the whole map. 21 m of rise
        ; per 1024-m node, peak 672 m at node (32,32) = world
        ; (32768,32768): the height under ANY point is arithmetic you
        ; can do while flying, off the coordinates on the glass. When
        ; a frame breaks, its numbers pin the spot; after the fix we
        ; teleport straight back and compare.
        xor  si,si
@@pyr:  mov  ax,si
        mov  cl,6
        shr  ax,cl              ; node x (HMAP is x*64+z)
        sub  ax,32
        jns  @@px1
        neg  ax
@@px1:  mov  bx,si
        and  bx,63              ; node z
        sub  bx,32
        jns  @@pz1
        neg  bx
@@pz1:  cmp  ax,bx              ; Chebyshev: a SQUARE pyramid
        jae  @@pm1
        mov  ax,bx
@@pm1:  mov  bx,32
        sub  bx,ax
        mov  ax,bx
        add  ax,ax
        add  ax,bx              ; *3 raw = 21 m world per node
        add  ax,88
        mov  [HMAP+si],al
        inc  si
        cmp  si,4096
        jb   @@pyr
ENDIF
        ; ---- stamp the aprons: four flat fields for four runways ----
        ; Raw 88 is sea level, which WORLDH maps to exactly zero: the
        ; runways stand on still ground whatever island came up, and a
        ; half-blend ring keeps the hills from starting at the fence.
        ; This replaces the old corridor-wide valley: everywhere else
        ; the terrain is now REAL, including straight ahead.
        mov  word ptr [dsx],0
@@apr:  mov  ax,[dsx]
        mov  cl,4
        shl  ax,cl              ; z node base = runway * 16
        mov  [dsh],ax
        mov  word ptr [dsy],-1
@@apz:  mov  bx,-3
@@apx:  mov  dx,[dsh]
        add  dx,[dsy]
        mov  al,88
        cmp  bx,-3
        je   @@blnd
        cmp  bx,3
        je   @@blnd
        cmp  word ptr [dsy],-1
        je   @@blnd
        cmp  word ptr [dsy],4
        je   @@blnd
        call HPUT
        jmp  @@apn
@@blnd: call HGET
        xor  ah,ah
        add  ax,88
        shr  ax,1
        call HPUT
@@apn:  inc  bx
        cmp  bx,4
        jl   @@apx
        inc  word ptr [dsy]
        cmp  word ptr [dsy],5
        jl   @@apz
        inc  word ptr [dsx]
        cmp  word ptr [dsx],4
        jl   @@apr
        call BAKE               ; sky ramp + clouds (lost once in a
                                ; block reshuffle: the world went
                                ; palette-zero BLACK and the pixels
                                ; confessed R0 G0 B0)
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
        mov  ax,3509h           ; ---- take the keyboard ----
        int  21h                ; BIOS hands out key EVENTS at the
        mov  [oldk9],bx         ; typematic rate, with a pause before
        mov  [oldk9+2],es       ; the first repeat: that pause IS the
        push ds                 ; jerk. Our handler keeps key STATE, and
        mov  ax,2509h           ; the stick moves once per tick from it
        mov  dx,offset KBINT
        int  21h
        pop  ds

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
        cmp  byte ptr [KEYS+1],0 ; ESC is the only key the loop still
        je   @@loop              ; reads for itself: everything that
                                 ; flies moved into KEYAPP, one move
                                 ; per tick, no typematic pause

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
        push ds                 ; the keyboard back to DOS, or the next
        mov  dx,[oldk9]         ; program at this prompt types nothing
        mov  ax,[oldk9+2]
        mov  ds,ax
        mov  ax,2509h
        int  21h
        pop  ds
        mov  ax,0003h
        int  10h
        mov  ax,4C00h
        int  21h

; ---- KBINT: our INT 9 - the key table IS the stick ------------------------
; Straight out of OWL FLY's KEYB.INC. Make sets, break clears, and the
; EOI goes back to the PIC by hand because the BIOS handler never runs.
KBINT:  push ax
        push bx
        push di
        push ds
        mov  ax,cs
        mov  ds,ax
        in   al,60h
        mov  ah,al
        and  al,7Fh
        mov  bl,al
        xor  bh,bh
        mov  di,offset KEYS
        add  di,bx
        test ah,80h
        jnz  @@brk
        mov  byte ptr [di],1
        jmp  @@eoi
@@brk:  mov  byte ptr [di],0
@@eoi:  mov  al,20h
        out  20h,al
        pop  ds
        pop  di
        pop  bx
        pop  ax
        iret

; ---- RESETF: park a fresh jet on the slab ----------------------------------
RESETF: mov  byte ptr [state],1
        mov  byte ptr [abon],0
        mov  word ptr [gam],0
        mov  word ptr [gamf],0
        mov  word ptr [sing],0
        mov  word ptr [cosg],256
        mov  byte ptr [ginv],0
        mov  word ptr [roll],0
        mov  word ptr [px],0
        mov  word ptr [pxacc],0
        mov  word ptr [hdg],0
        mov  word ptr [hdgf],0
        mov  word ptr [hgnd],0
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

; ---- ACTRL: the Pilot Automatic - the arcade half of the two-mode deal -----
; The player's keys set a TARGET path angle; this flies the SAME
; Newton airframe to it - alpha chased toward trim + coordination +
; a proportional pull on the error, with a stall guard that trades
; nose for speed before the wing quits. No second physics anywhere:
; an unseen pilot, not an unseen engine.
ACTRL:  cmp  byte ptr [amode],0
        je   @@ret
        cmp  byte ptr [air],0
        je   @@ret
        mov  ax,[v16]           ; stall guard: below ~1.15 Vs the
        cmp  ax,1120            ; commanded path yields to the speed
        jae  @@ng
        cmp  word ptr [gtgt],-6
        jle  @@ng
        dec  word ptr [gtgt]
@@ng:   mov  ax,[gtgt]
        sub  ax,[gam]
        and  ax,255
        cmp  ax,128
        jb   @@w1
        sub  ax,256             ; the error, folded signed
@@w1:   mov  cx,96              ; gain doubled: the old 48 could not
        imul cx                 ; even reach negative alpha, and "down"
        cmp  ax,3800            ; was a word the autopilot knew but
        jle  @@c1               ; could not do
        mov  ax,3800
@@c1:   cmp  ax,-3800
        jge  @@c2
        mov  ax,-3800
@@c2:   mov  [gerr],ax
        mov  ax,[roll]
        call TSIN
        or   ax,ax
        jns  @@c3
        neg  ax
@@c3:   mov  cx,5
        imul cx
        add  ax,2400            ; trim + coordination + the pull...
        add  ax,[gerr]
        add  ax,[gboost]        ; ...and the player's own G, when the
        cmp  ax,-1536           ; bank turns the arrows into a G lever
        jge  @@c4
        mov  ax,-1536
@@c4:   cmp  ax,4352
        jle  @@c5
        mov  ax,4352
@@c5:   mov  bx,[alpha8]        ; ease the stick, not teleport it
        sub  ax,bx
        cmp  ax,80
        jle  @@c6
        mov  ax,80
@@c6:   cmp  ax,-80
        jge  @@c7
        mov  ax,-80
@@c7:   add  bx,ax
        mov  [alpha8],bx
@@ret:  ret

; ---- TICK: one 55 ms step - no controllers, no script: just you ------------
TICK:   inc  word ptr [tcnt]
        call DBGTICK            ; drain the umbilical and report
        call KEYAPP             ; one stick movement per tick, from the
                                ; key STATE - whoever set it
        call ACTRL              ; ...and the Pilot Automatic, if hired
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
@@k2:   mov  bx,[alpha8]        ; alpha may be NEGATIVE now: pushing the
        cmp  bx,-1536           ; wing below the wind is how a nose gets
        jge  @@ae1              ; pointed at the ground - the "cushion"
        mov  bx,-1536           ; was a stick that could not push
@@ae1:  cmp  bx,4608
        jle  @@ae2
        mov  bx,4608
@@ae2:  or   bx,bx              ; unsigned MUL wants the magnitude
        jns  @@lpp
        neg  bx
        mov  ax,[v2v]
        mul  bx
        cmp  dx,cx
        jb   @@lnv
        mov  ax,60000
        jmp  @@lns
@@lnv:  div  cx
@@lns:  mov  word ptr [lgv],0   ; the G readout shows no negative G
        shr  ax,1               ; dynamics at HALF SCALE (the ninth
        cmp  ax,30000           ; integer trap dodged by arithmetic,
        jbe  @@ln2              ; not by a cap this time): mg/16 =
        mov  ax,30000           ; 7357, four G fit a signed word
@@ln2:  neg  ax
        mov  [ldyn],ax
        jmp  @@lgo
@@lpp:  mov  ax,[v2v]
        mul  bx
        cmp  dx,cx              ; the quotient would burst the word -
        jb   @@ldv              ; saturate (a wing has limits; so does
        mov  ax,60000           ; a 16-bit DIV, and it FAULTS: this was
        jmp  @@lst              ; the mystery freeze past ~550 km/h)
@@ldv:  div  cx
@@lst:  mov  [lgv],ax           ; the full value feeds the G readout
        shr  ax,1
        cmp  ax,30000
        jbe  @@lp2
        mov  ax,30000
@@lp2:  mov  [ldyn],ax
@@lgo:  mov  ax,[ldyn]
        cmp  byte ptr [air],0
        jne  @@l2
        cmp  ax,7357            ; on the wheels: the wing takes it?
        jbe  @@gnd
        mov  byte ptr [air],1   ; liftoff - by lift, as always
        mov  byte ptr [flew],1
        mov  word ptr [gtgt],6  ; AUTO's climb-out: a tidy 8 degrees
        call UNLOAD
        jmp  @@l2
@@gnd:  mov  word ptr [vs64],0
        mov  word ptr [gam],0   ; wheels on the world: the path is flat
        mov  word ptr [gamf],0
        mov  word ptr [sing],0
        mov  word ptr [cosg],256
        mov  word ptr [h6],HGEAR
        cmp  byte ptr [gear],0  ; rolling with no legs: the belly
        jne  @@gok              ; grinds and the day is over
        cmp  word ptr [v16],32
        jle  @@gok
        mov  byte ptr [state],6
        mov  word ptr [cardp],offset MBELLY
@@gok:  jmp  @@long
@@l2:   ; ---- the tilted lift vector, now in BOTH planes ------------
        ; Bank the wing and the same lift splits: L*sin swings the
        ; heading, L*cos fights gravity in the vertical - and the
        ; vertical is a FULL CIRCLE now: v*dgamma = L*cos(phi) -
        ; mg*cos(gamma). Pull and the path curves up; keep pulling and
        ; cos(gamma) goes negative over the top and GRAVITY helps you
        ; around. A loop is not a manoeuvre here, it is this arithmetic
        ; run six hundred times.
        mov  ax,[gam]
        add  ax,64
        call TSIN
        mov  [cosg],ax          ; cos(gamma), the whole branch needs it
        mov  ax,[roll]
        call TSIN
        mov  cx,ax              ; sin(roll)
        mov  ax,[ldyn]
        imul cx
        mov  cx,256
        idiv cx                 ; L16*sin, +-30000
        mov  cx,196             ; 196/256 with the HALF-scale lift: the
        imul cx                 ; same omega as before, but four G of
        mov  cx,256             ; headroom instead of two and a half -
        idiv cx                 ; pulling in the bank TIGHTENS it now
        mov  cx,[vmv]
        cmp  cx,16
        jae  @@tnv
        mov  cx,16              ; divisor floor, the idiv rule
@@tnv:  cwd
        idiv cx
        mov  bx,[cosg]          ; near the vertical the heading is a
        or   bx,bx              ; word without meaning: hold it
        jns  @@tg1
        neg  bx
@@tg1:  cmp  bx,32
        jl   @@tg2
        add  ax,[hdgf]
        mov  bx,ax
        mov  cl,8
        sar  bx,cl
        add  [hdg],bx
        and  word ptr [hdg],255
        and  ax,255
        mov  [hdgf],ax
@@tg2:  mov  ax,[roll]
        add  ax,64
        call TSIN               ; cos(roll)
        mov  cx,ax
        mov  ax,[ldyn]
        imul cx
        mov  cx,256
        idiv cx                 ; the lift the WEIGHT sees - negative
        mov  [l8e],ax           ; when inverted or pushing, and both
        ; ---- the pitch impulse, scaled before the subtraction so the
        ; sum L*cos(phi) + mg can never burst a signed word ----
        mov  cx,196
        imul cx
        mov  cx,256
        idiv cx                 ; L-part, +-22968
        mov  [gtmp],ax
        mov  ax,5632            ; mg/8 * 98/256, folded at build time
        mov  cx,[cosg]
        imul cx
        mov  cx,256
        idiv cx                 ; g-part, +-5632
        mov  cx,[gtmp]
        sub  cx,ax
        mov  ax,cx
        mov  cx,[vmv]
        cmp  cx,16
        jae  @@gnv
        mov  cx,16
@@gnv:  cwd
        idiv cx                 ; dgamma, 8.8 units/tick
        cmp  ax,512             ; ~36 deg/s: the airframe's pitch stop
        jle  @@gc1
        mov  ax,512
@@gc1:  cmp  ax,-512
        jge  @@gc2
        mov  ax,-512
@@gc2:  add  ax,[gamf]
        mov  bx,ax
        mov  cl,8
        sar  bx,cl
        add  [gam],bx
        and  word ptr [gam],255
        and  ax,255
        mov  [gamf],ax
        mov  ax,[gam]
        mov  [dvsdbg],ax        ; umbilical: gamma rides the gpi column
        mov  ax,[gam]
        call TSIN
        mov  [sing],ax
        mov  cx,[v16]           ; vs is DERIVED now: v*sin(gamma),
        imul cx                 ; not integrated - one source of truth
        mov  cx,64
        idiv cx                 ; 1/16 m/s * sin/256 -> 1/64 m/s
        neg  ax                 ; the tape's +down convention
        cmp  ax,15500
        jle  @@vs1
        mov  ax,15500
@@vs1:  cmp  ax,-15500
        jge  @@vs2
        mov  ax,-15500
@@vs2:  mov  [vs64],ax
        mov  ax,[vs64]          ; h -= vs: 14/256 of a unit per tick
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
        ; ---- induced drag: the fighter's tax ----
        ; Lift is bought with drag ~ L^2/v^2. This one term is most of
        ; what "fighter physics" means: pull hard and the speed melts,
        ; idle at high alpha and the mush BLEEDS energy instead of
        ; floating on it - which retires the marshmallow, prices every
        ; turn in knots, and lets a landing flare actually end.
        mov  ax,[ldyn]
        or   ax,ax              ; negative lift buys drag all the same
        jns  @@dip
        neg  ax
@@dip:  mov  cl,3
        shr  ax,cl
        mul  ax                 ; (L/128)^2, all 32 bits of it
        mov  cx,[v2v]
        shr  cx,1
        shr  cx,1
        shr  cx,1               ; v^2/8, the calibrated denominator
        cmp  cx,8
        jae  @@di1
        mov  cx,8               ; a parked jet divides by nothing
@@di1:  cmp  dx,cx              ; quotient past a word: saturate the tax
        jae  @@di2
        div  cx
        cmp  ax,9000
        jbe  @@di3
@@di2:  mov  ax,9000
@@di3:  sub  bx,ax
        cmp  byte ptr [air],0
        jne  @@fr0
        sub  bx,883             ; rolling friction...
        cmp  byte ptr [brk],0
        je   @@fr0
        sub  bx,7400            ; ...and the brakes
@@fr0:  mov  ax,bx              ; dv16(8.8) = N4*256/3412...
        mov  cx,256
        imul cx
        mov  cx,3412
        idiv cx
        mov  bx,ax
        mov  ax,[sing]          ; ...minus gravity along the PATH:
        mov  cx,69              ; mg*sin(gamma), pre-scaled (2208 full).
        imul cx                 ; The climb spends exactly what the
        mov  cx,8               ; dive refunds - a zoom trades speed
        idiv cx                 ; for height at par, both directions
        sub  bx,ax
        mov  ax,bx
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
@@l4:   mov  ax,[v16]           ; the step this tick (metres, 8.8) -
        mov  bx,ax              ; along the heading, times cos(gamma):
        mov  cl,3               ; going straight up, the map stops
        sar  bx,cl
        sub  ax,bx
        mov  cx,[cosg]
        imul cx
        mov  al,ah
        mov  ah,dl
        mov  [adv8],ax
        mov  ax,[hdg]
        add  ax,64
        call TSIN               ; cos(hdg)
        mov  cx,[adv8]
        imul cx
        mov  al,ah              ; (DX:AX) >> 8, the middle bytes
        mov  ah,dl
        add  ax,[posacc]
        mov  bx,ax
        mov  cl,8
        sar  bx,cl              ; signed floor: south is a direction,
        add  [posm],bx          ; not an error; the ADD wraps the torus
        and  ax,255
        mov  [posacc],ax
        mov  ax,[hdg]
        call TSIN               ; sin(hdg)
        mov  cx,[adv8]
        imul cx
        mov  al,ah
        mov  ah,dl
        add  ax,[pxacc]
        mov  bx,ax
        mov  cl,8
        sar  bx,cl
        add  [px],bx
        and  ax,255
        mov  [pxacc],ax
        ; ---- the ground is not flat any more ----
        mov  bx,[px]
        mov  dx,[posm]
        call HBIL               ; ax = ground here, metres
        mov  cx,ax
        sub  ax,[hgnd]          ; how much it rose under us this tick
        mov  [hgnd],cx
        cmp  byte ptr [air],0
        je   @@hgw              ; on the wheels the strut just follows
        or   ax,ax
        jns  @@hup
        neg  ax                 ; falling ground: height above it grows
        mov  cx,64
        mul  cx                 ; metres -> 1/64 m, same as the rise
        add  [h6],ax
        cmp  word ptr [h6],65000
        jbe  @@hgw
        mov  word ptr [h6],65000
        jmp  @@hgw
@@hup:  mov  cx,64
        mul  cx                 ; metres -> 1/64 m (rise is small)
        sub  [h6],ax
        jnc  @@hgw
        mov  word ptr [h6],HGEAR ; the hill came up through the wheels:
@@hgw:                           ; the TOUCH path will say the rest
        mov  ax,[v16]           ; stripe odometer, 1/16 m
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
        mov  byte ptr [ginv],0
        mov  ax,[alpha8]        ; on the ground the nose IS the alpha -
        sub  ax,3072            ; drawn at the same world scale as the
        mov  cx,182             ; sky it rotates into
        imul cx
        mov  al,ah
        mov  ah,dl
        mov  cx,11
        imul cx
        mov  cx,512
        idiv cx
        mov  bx,ax
        add  bx,95
        cmp  bx,60
        jge  @@g1
        mov  bx,60
@@g1:   cmp  bx,170
        jle  @@g2
        mov  bx,170
@@g2:   mov  [hrow],bx
        ret
@@aa:   ; the attitude is gamma + alpha and it WRAPS: fold it into
        ; +-90 degrees with an inverted flag. The flag turns the whole
        ; rendered world through 180 - roll and heading both - which
        ; is exactly what the top of a loop looks like out the glass.
        mov  ax,[alpha8]
        sub  ax,2400            ; approach trim = the baseline view
        mov  cx,182             ; 8.8 degrees -> 8.8 circle units
        imul cx
        mov  al,ah
        mov  ah,dl
        mov  bx,[gam]
        mov  cl,8
        shl  bx,cl
        add  bx,[gamf]
        add  ax,bx              ; theta, 8.8 units on the full circle
        mov  byte ptr [ginv],0
        cmp  ax,16384           ; past straight up...
        jle  @@f1
        mov  bx,-32768          ; 8000h: minus and plus 32768 are the
        sub  bx,ax              ; same word, so this IS 32768 - theta
        mov  ax,bx
        mov  byte ptr [ginv],1
        jmp  @@f3
@@f1:   cmp  ax,-16384          ; ...or past straight down
        jge  @@f3
        mov  bx,-32768
        sub  bx,ax
        mov  ax,bx              ; -32768 - theta
        mov  byte ptr [ginv],1
@@f3:   mov  cx,11              ; 5.5 px per unit: the WORLD's focal
        imul cx                 ; length (220), not the HUD's. Drawn at
        mov  cx,512             ; 8 px/deg the horizon fled the glass at
        idiv cx                 ; twelve degrees of pitch and the whole
        add  ax,95              ; screen went ground - the two-focal-
        cmp  ax,-400            ; lengths debt, called in. Now horizon,
        jge  @@a1               ; ladder, FPI and the terrain speak one
        mov  ax,-400            ; scale, and the glass holds +-19 deg
@@a1:   cmp  ax,600
        jle  @@a2
        mov  ax,600
@@a2:   mov  [hrow],ax
        ; the FPI hangs alpha below the datum - the gap IS the AoA
        mov  ax,[alpha8]
        sub  ax,2400
        mov  cx,182
        imul cx
        mov  al,ah
        mov  ah,dl
        mov  cx,11
        imul cx
        mov  cx,512
        idiv cx
        neg  ax
        mov  [fpr],ax
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
; The world grew two more ways to miss: the concrete has EDGES now (44 m
; either side of the centreline), and it points somewhere (land more
; than ~10 degrees across it and the gear goes sideways).
TOUCH:  mov  word ptr [h6],HGEAR
        mov  word ptr [roll],0  ; the wheels level the wings
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
@@t2:   mov  ax,[posm]          ; on the concrete at all? (the SUB wraps
        sub  ax,THRESH          ; with the world)
        xor  dx,dx
        mov  cx,RWGAP
        div  cx
        cmp  dx,RWLEN
        jbe  @@t2a
        jmp  @@grs
@@t2a:  mov  ax,[px]            ; between the edge lines?
        or   ax,ax
        jns  @@t2b
        neg  ax
@@t2b:  cmp  ax,44
        ja   @@grs
        mov  ax,[hdg]           ; and pointing DOWN the slab?
        cmp  ax,128
        jbe  @@t2c
        neg  ax                 ; fold the circle: 255 -> 1
        and  ax,255
@@t2c:  cmp  ax,8
        jbe  @@t4
@@grs:  mov  byte ptr [state],6
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

; ---- RENDER: a world that can hang upside down -----------------------------
; The horizon stopped being a screen row and became a LINE (FLIGHT.ASM's
; trick): f(x,y) = ((y-hcur)*cos r - (x-cx0)*sin r)/256 is the signed
; distance to it, one sky span and one ground span per row, both shaded
; by |f|. When the roll passes inverted, cos r flips sign and the earth
; hangs from the top of the screen with no code to help it.
; The concrete is no longer drawn by walking screen rows at all: SLAB
; projects its four world corners and fills the quad, so the threshold,
; the far end and the centreline survive any attitude. The same two
; routines - PROJW and POLY4 - are what the terrain will be made of.
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
@@sw1:
IF CALIB
        xor  ax,ax              ; the calibration bench does not sway
ENDIF
        add  ax,[hrow]
        cmp  ax,-700            ; the horizon is allowed clean off the
        jge  @@h1               ; glass: straight up is all sky, and
        mov  ax,-700            ; that is the truth of it
@@h1:   cmp  ax,900
        jle  @@h2
        mov  ax,900
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
@@sw2:
IF CALIB
        xor  ax,ax
ENDIF
        add  ax,160
        mov  [cx0],ax
        ; ---- the bank: one pair of numbers rules the whole frame ----
        mov  al,[ginv]          ; past the vertical the DISPLAY frame
        xor  ah,ah              ; turns half a circle - roll and heading
        mov  cl,7               ; both - and the world hangs upside
        shl  ax,cl              ; down over the top of the loop for free
        mov  bx,[roll]
        add  bx,ax
        and  bx,255
        mov  [droll],bx
        mov  bx,[hdg]
        add  bx,ax
        and  bx,255
        mov  [dhdg],bx
        mov  cl,8               ; the frame's heading trig, computed
        shl  bx,cl              ; ONCE and WITH its fraction: clouds,
        add  bx,[hdgf]          ; terrain and slab all turn together
        mov  ax,bx              ; now (the clouds used to borrow LAST
        push bx                 ; frame's heading and dance against
        call TSINF              ; the ground)
        mov  [hs2],ax
        pop  bx
        mov  ax,bx
        add  ax,16384
        call TSINF
        mov  [hc2],ax
        mov  ax,[droll]
        call TSIN
        neg  ax                 ; bank RIGHT and the horizon's right end
        mov  [sinr],ax          ; must RISE - tilt your head and see
        mov  ax,[droll]
        add  ax,64
        call TSIN
        mov  [cosr],ax
        mov  word ptr [pmrow],-9999
        call LEVELQ             ; who fills the spans this frame
        mov  byte ptr [wdith],0
        jnz  @@lvl
        mov  byte ptr [wdith],1
@@lvl:
        call BGND               ; sky and grass, split by the horizon line
        call WCLOUD             ; the sky's own weather, wherever it is
        call TERR               ; the hills next: a cloud behind a ridge
        call SLAB               ; is painted over, as it should be
@@grd:  mov  ax,[h6]            ; HUD altitude: height above the gear...
        sub  ax,HGEAR           ; (h6 can top 32767: stay unsigned)
        jnc  @@ha
        xor  ax,ax
@@ha:   mov  cl,2
        shr  ax,cl              ; 1/64 m -> 1/16 m
        mov  cx,[hgnd]          ; ...plus the ground under it: the tape
        mov  bx,cx              ; reads ASL now, because 500 m over a
        mov  cl,4               ; 400 m ridge is NOT five hundred metres
        shl  bx,cl              ; of anything
        add  ax,bx
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
@@lg3:  cmp  byte ptr [abon],0  ; the burner announces itself in amber
        je   @@lg3a
        mov  byte ptr [tcol],5
        mov  si,offset LAB
        mov  ax,188
        mov  bx,240
        call TXT
        mov  byte ptr [tcol],21
@@lg3a: cmp  byte ptr [amode],0 ; and so does the unseen pilot
        je   @@lg3b
        mov  byte ptr [tcol],5
        mov  si,offset LAUTO
        mov  ax,188
        mov  bx,268
        call TXT
        mov  byte ptr [tcol],21
@@lg3b: ; ---- the manual's Control Stick Indicator, at last ----
        ; the box shows the HANDS: sideways = the aileron key held,
        ; up-down = the elevator's alpha; in AUTO the amber dash is
        ; the commanded path - "куда меня несёт" now has an answer
        mov  ax,164
        call ROWAD
        add  ax,296
        mov  di,ax
        mov  cx,22
@@cs1:  mov  byte ptr es:[di],23
        mov  byte ptr es:[di+22*320],23
        inc  di
        loop @@cs1
        mov  ax,164
        call ROWAD
        add  ax,296
        mov  di,ax
        mov  cx,22
@@cs2:  mov  byte ptr es:[di],23
        mov  byte ptr es:[di+21],23
        add  di,320
        loop @@cs2
        xor  bx,bx              ; x: which aileron key is down
        cmp  byte ptr [KEYS+4Bh],0
        je   @@cs3
        mov  bx,-7
@@cs3:  cmp  byte ptr [KEYS+4Dh],0
        je   @@cs4
        mov  bx,7
@@cs4:  add  bx,306
        mov  ax,[alpha8]        ; y: the stick fore-aft, pull = down
        sub  ax,1408
        mov  cx,300
        cwd
        idiv cx
        cmp  ax,-9
        jge  @@cs5
        mov  ax,-9
@@cs5:  cmp  ax,9
        jle  @@cs6
        mov  ax,9
@@cs6:  add  ax,175
        call ROWAD
        add  ax,bx
        mov  di,ax
        mov  byte ptr es:[di-1],15
        mov  byte ptr es:[di],15
        mov  byte ptr es:[di+1],15
        mov  byte ptr es:[di-320],15
        mov  byte ptr es:[di+320],15
        cmp  byte ptr [amode],0
        je   @@cs9
        mov  ax,[gtgt]          ; the pilot automatic's wish, in amber
        add  ax,ax
        add  ax,[gtgt]
        sar  ax,1               ; gtgt * 1.5 px, climb = up
        neg  ax
        add  ax,175
        call ROWAD
        add  ax,306
        mov  di,ax
        mov  byte ptr es:[di-3],5
        mov  byte ptr es:[di-2],5
        mov  byte ptr es:[di+2],5
        mov  byte ptr es:[di+3],5
@@cs9: cmp  byte ptr [air],0   ; the wing is on the edge of quitting
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

; ---- LEVELQ: ZF=0 (jnz) when the wings are level AND the world upright ----
; Eight units of sine is about two degrees - inside that the split
; below is a rounding error and the old fast path is honest.
LEVELQ: cmp  word ptr [cosr],0
        jle  @@no
        mov  ax,[sinr]
        or   ax,ax
        jge  @@a
        neg  ax
@@a:    cmp  ax,8
        jae  @@no
        mov  ax,1
        or   ax,ax              ; ZF=0: level
        ret
@@no:   xor  ax,ax              ; ZF=1: banked
        ret

; ---- BGND: sky and grass, split by the horizon LINE ------------------------
; One span each side of the line per row, shaded by the PERPENDICULAR
; distance to it - so the haze and the grass ramps rotate with the
; world instead of with the screen.
BGND:   mov  word ptr [mrow],0
        mov  word ptr [rowb],0
@@mr:   mov  ax,[mrow]
        sub  ax,[hcur]
        imul word ptr [cosr]
        mov  bx,256
        idiv bx
        mov  [fmv],ax           ; f at the pivot column of this row
        mov  bx,[sinr]
        or   bx,bx
        jge  @@ab
        neg  bx
@@ab:   cmp  bx,8               ; level: the row is all one thing
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
@@split:mov  ax,[fmv]           ; the line crosses this row at
        mov  cx,256             ; x = cx0 + f*256/sin r
        imul cx
        idiv word ptr [sinr]
        add  ax,[cx0]
        mov  bx,ax
        or   bx,bx
        jge  @@x1
        xor  bx,bx
@@x1:   cmp  bx,320
        jle  @@x2
        mov  bx,320
@@x2:   cmp  word ptr [sinr],0
        jl   @@neg
        mov  word ptr [spa],0   ; sin>0: f falls as x grows - ground left
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
        jmp  @@nr
@@neg:  mov  word ptr [spa],0   ; sin<0: sky on the left instead
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
@@nr:   add  word ptr [rowb],320
        inc  word ptr [mrow]
        cmp  word ptr [mrow],200
        jb   @@mr
        ret

; ---- FSP: fill span [spa..spa+spl) of row [mrow], sky or ground ------------
; One shade per span, taken at its centre - the retro compromise, and
; the same one FLIGHT.ASM's airshow flies with.
FSP:    cmp  word ptr [spl],0
        jle  @@fr
        mov  ax,[spl]
        shr  ax,1
        add  ax,[spa]
        sub  ax,[cx0]
        imul word ptr [sinr]
        mov  bx,256
        idiv bx
        neg  ax                 ; f = fmv - (x-cx0)*sin/256
        add  ax,[fmv]
        or   ax,ax
        jge  @@f1
        neg  ax
@@f1:   cmp  ax,199
        jbe  @@f2
        mov  ax,199
@@f2:   mov  bx,ax
        cmp  byte ptr [sptype],0
        jne  @@fg
        mov  word ptr [texp],offset TSKY
        mov  al,[SBASE+bx]      ; the sky ramp, by height above the line
        mov  [pbase],al
        mov  al,[SFRAC+bx]
        mov  [pfrac],al
        jmp  @@ff
@@fg:   mov  ax,bx              ; the floor: SOLID bands by distance.
        mov  cl,5               ; The dither has left the land - its
        shr  ax,cl              ; per-tick remixing was the shimmer the
        cmp  ax,3               ; pilot kept squinting at - and the sky
        jbe  @@fb               ; keeps its grain, which was always the
        mov  ax,3               ; pretty half
@@fb:   add  al,24
        mov  di,[rowb]
        add  di,[spa]
        mov  cx,[spl]
        jcxz @@fr
        rep  stosb
        ret
@@ff:   mov  di,[rowb]
        add  di,[spa]
        mov  cx,[spl]
        cmp  byte ptr [wdith],0
        je   @@fast
        mov  ax,[mrow]          ; banked: the slow, honest grain
        mov  bx,[spa]
        call WSTART
        call DFILLW
        ret
@@fast: mov  ax,[mrow]
        call MKPATT
        call DFILL
@@fr:   ret

; ---- CLSEG: a span drawn ALONG the horizon, not along a screen row -------
; The clouds live at a height above the horizon and stretch sideways
; along it, so in a bank their spans are tilted lines. Stepping one
; pixel at a time leaves the odd gap at 45 degrees - on a dithered
; cloud that is invisible, and the caller walks f in half steps anyway.
;  in: AX=x0, DX=y0 (screen), CX=length, pbase/pfrac shade
; The screen address walks by a DDA - one add and a carry, never a
; multiply - and the tile indices ride the same 8.8 accumulators the
; span fills use. A pixel that lands off the glass is skipped, not
; clipped: the segments are short and the test is two compares.
CLSEG:  or   cx,cx
        jle  @@z
        push bp
        push cx                 ; CL is needed for the shifts below
        mov  [cxv],ax           ; the screen walk: integers plus an 8.8
        mov  [cyv],dx           ; error each, so nothing overflows at
        mov  word ptr [cxe],0   ; x = 300 the way a packed 8.8 would
        mov  word ptr [cye],0
        mov  cl,8
        mov  ax,[cosr]
        mov  bx,ax
        sar  bx,cl
        mov  [dxi],bx
        and  ax,255
        shl  ax,cl
        mov  [dxf],ax
        mov  ax,[sinr]
        mov  bx,ax
        sar  bx,cl
        mov  [dyi],bx
        and  ax,255
        shl  ax,cl
        mov  [dyf],ax
        mov  ax,[cyv]
        call ROWAD
        mov  [crb],ax           ; the row base moves by +-320, never by
        mov  bx,[cfv]           ; a multiply. f is CONSTANT along the
        and  bx,255             ; segment - it is a line parallel to the
        mov  si,[texp]          ; horizon - so its tile row is too
        add  si,bx
        mov  bl,[si]
        xor  bh,bh
        mov  [ctrow],bx
        xor  bx,bx              ; bx = the walk's column counter
        pop  cx
@@p:    mov  ax,[cxv]
        or   ax,ax
        jl   @@nx
        cmp  ax,319
        jg   @@nx
        mov  dx,[cyv]
        or   dx,dx
        jl   @@nx
        cmp  dx,199
        jg   @@nx
        mov  di,[crb]
        add  di,ax
        mov  ax,bx
        and  ax,15
        add  ax,[ctrow]
        mov  si,ax
        mov  ah,[BNOISE+si]
        mov  al,[pbase]
        cmp  [pfrac],ah
        jbe  @@p1
        inc  al
@@p1:   mov  es:[di],al
        mov  si,[cdup]          ; and a twin one pixel ACROSS the line:
        or   si,si              ; neighbouring segments sit 1 px apart
        jz   @@nx               ; perpendicular, and a rotated lattice
        cmp  si,320             ; drops pixels between them - this is
        je   @@d1               ; what closes the gaps
        cmp  word ptr [cxv],319
        jge  @@nx
@@d1:   add  si,di
        mov  es:[si],al
@@nx:   inc  bx
        mov  ax,[dxi]
        add  [cxv],ax
        mov  ax,[dxf]
        add  [cxe],ax
        jnc  @@y
        inc  word ptr [cxv]
@@y:    mov  ax,[dyi]
        or   ax,ax
        jz   @@y1
        add  [cyv],ax
        mov  dx,320
        cmp  ax,0
        jg   @@y0
        neg  dx
@@y0:   add  [crb],dx
@@y1:   mov  ax,[dyf]
        add  [cye],ax
        jnc  @@y2
        inc  word ptr [cyv]
        add  word ptr [crb],320
@@y2:   loop @@p
        pop  bp
@@z:    ret

; ---- WCLOUD: the weather lives in the WORLD now ---------------------------
; Sixteen clouds stand on the torus at random spots, heights and sizes,
; wearing one of four silhouettes baked fresh each launch - fly past
; them, turn and find different ones, climb and look DOWN on them. Each
; is drawn as horizon-parallel rows through ROTPT + CLSEG, so banks and
; the top of a loop cost nothing. Far to near, and the terrain pass
; afterwards buries whatever hides behind a ridge.
WCLOUD: mov  word ptr [texp],offset TSKY
        mov  ax,[sinr]          ; the twin-pixel direction, once
        or   ax,ax
        jge  @@s1
        neg  ax
@@s1:   mov  bx,[cosr]
        or   bx,bx
        jge  @@s2
        neg  bx
@@s2:   mov  word ptr [cdup],320
        cmp  ax,bx
        jle  @@s3
        mov  word ptr [cdup],1
@@s3:   ; ---- cull and collect ----
        xor  si,si              ; instance index
        mov  word ptr [qcn],0
@@cull: mov  ax,si
        add  ax,ax
        mov  di,ax
        mov  ax,[CLX+di]
        sub  ax,[px]
        mov  [wdx2],ax
        mov  ax,[CLZ+di]
        sub  ax,[posm]
        mov  [wdz2],ax
        push si
        call WCAM
        pop  si
        mov  ax,[pd]
        cmp  ax,250
        jl   @@next
        cmp  ax,11500
        jg   @@next
        mov  bx,[pu]
        or   bx,bx
        jns  @@c1
        neg  bx
@@c1:   mov  cx,ax
        add  cx,cx
        cmp  bx,cx              ; more than two widths off the bow
        jg   @@next
        mov  bx,[qcn]
        cmp  bx,20              ; the visible list has walls
        jae  @@next
        add  bx,bx
        mov  [VLD+bx],ax        ; keep its distance...
        mov  ax,[pu]
        mov  [VLU+bx],ax        ; ...and its sideways reach
        shr  bx,1
        mov  ax,si
        mov  [VLI+bx],al       ; ...and who it is
        inc  word ptr [qcn]
@@next: inc  si
        cmp  si,96
        jb   @@cull
        ; ---- draw, farthest first ----
@@pick: mov  word ptr [qcb],-1
        mov  bx,-1
        xor  si,si
@@fmax: cmp  si,[qcn]
        jae  @@fdn
        mov  di,si
        add  di,di
        mov  ax,[VLD+di]
        cmp  ax,bx
        jle  @@fnx
        mov  bx,ax
        mov  [qcb],si
@@fnx:  inc  si
        jmp  @@fmax
@@fdn:  cmp  word ptr [qcb],-1
        je   @@done
        mov  si,[qcb]
        add  si,si
        mov  ax,[VLD+si]
        mov  [qcd],ax           ; this cloud's d
        mov  ax,[VLU+si]
        mov  [qcu],ax           ; and u
        mov  word ptr [VLD+si],-1
        shr  si,1
        mov  bl,[VLI+si]
        xor  bh,bh
        mov  [qci],bx
        call CDRAW
        jmp  @@pick
@@done: ret

; ---- CDRAW: one cloud, rows of CLSEG under the shape tables ---------------
CDRAW:  mov  bx,[qci]
        add  bx,bx
        mov  di,bx
        mov  ax,[qcu]           ; t of the centre: 220*u/d
        mov  cx,220
        imul cx
        idiv word ptr [qcd]
        mov  [qct],ax
        mov  ax,[h6]
        mov  cl,6
        shr  ax,cl
        add  ax,[hgnd]          ; the camera, metres ASL
        sub  ax,[CLH+di]        ; minus the cloud's base
        mov  cx,220
        imul cx
        idiv word ptr [qcd]
        mov  [qcf],ax           ; f of the cloud base
        cmp  ax,-950
        jl   @@out
        cmp  ax,1000
        jg   @@out
        mov  ax,[CLM+di]        ; scale: 352*size/d, 8.8 of table cols
        mov  cx,352
        imul cx
        idiv word ptr [qcd]
        cmp  ax,8
        jge  @@sc1
        mov  ax,8
@@sc1:  cmp  ax,640
        jle  @@sc2
        mov  ax,640
@@sc2:  mov  [qcs],ax
        mov  bx,ax              ; rows on screen: 64*scale/512 (clouds
        mov  cl,3               ; squat: half as tall as wide)
        shr  bx,cl
        cmp  bx,2
        jge  @@h1
        mov  bx,2
@@h1:   cmp  bx,80
        jle  @@h2
        mov  bx,80
@@h2:   mov  [qch],bx
        mov  ax,16384           ; source step per screen row, 8.8
        cwd
        idiv bx
        mov  [qcp],ax
        mov  word ptr [qcr],0   ; the source walker
        mov  word ptr [qcw],0   ; the screen row walker
        mov  ax,[qci]
        mov  cl,6
        shl  ax,cl              ; shape base = shape*64 (shape = index&3
        and  ax,255             ; folds sixteen clouds onto four coats)
        mov  [qcb],ax
@@row:  mov  ax,[qcr]
        mov  al,ah
        xor  ah,ah              ; source row 0..63
        add  ax,[qcb]
        mov  si,ax
        mov  al,[CSHW+si]
        or   al,al
        jz   @@nr
        xor  ah,ah
        mov  cx,[qcs]
        imul cx
        mov  al,ah              ; width in px: W*scale/256
        mov  ah,dl
        or   ax,ax
        jnz  @@w1
        mov  ax,1
@@w1:   mov  [qcv],ax
        mov  al,[CSHS+si]
        xor  ah,ah
        sub  ax,70              ; the silhouette's own centre
        mov  cx,[qcs]
        imul cx
        mov  al,ah
        mov  ah,dl
        add  ax,[qct]           ; t of this row's left edge
        mov  bx,[qcf]
        sub  bx,[qcw]           ; the rows stack UP from the base
        mov  [cfv],bx           ; CLSEG's tile row rides f
        push ax
        mov  ax,[qcr]           ; the old cloud light: haze-blue at the
        mov  al,ah              ; base, sunlit white up top
        xor  ah,ah
        mov  cx,6
        imul cx
        add  ax,40
        cmp  ax,511
        jbe  @@sh1
        mov  ax,511
@@sh1:  mov  [pfrac],al
        mov  al,ah
        add  al,10
        mov  [pbase],al
        pop  ax
        mov  bx,[cfv]
        call ROTPT
        mov  cx,[qcv]
        call CLSEG
@@nr:   mov  ax,[qcp]
        add  [qcr],ax
        inc  word ptr [qcw]
        mov  ax,[qcw]
        cmp  ax,[qch]
        jl   @@row
@@out:  ret

; ---- WCAM: world delta (wdx2 east, wdz2 north) -> pu, pd through hdg ------
; The one rotation everything shares: the terrain lattice, the slab,
; the paint. d = dz*cos + dx*sin, u = dx*cos - dz*sin, 32-bit inside,
; middle bytes out.
WCAM:   mov  ax,[wdz2]
        imul word ptr [hc2]
        mov  bx,ax
        mov  cx,dx
        mov  ax,[wdx2]
        imul word ptr [hs2]
        add  bx,ax
        adc  cx,dx
        mov  al,bh
        mov  ah,cl
        mov  [pd],ax
        mov  ax,[wdx2]
        imul word ptr [hc2]
        mov  bx,ax
        mov  cx,dx
        mov  ax,[wdz2]
        imul word ptr [hs2]
        sub  bx,ax
        sbb  cx,dx
        mov  al,bh
        mov  ah,cl
        mov  [pu],ax
        ret

; ---- SLAB: the runways, standing in the world -----------------------------
; Two candidates - the slab of our slot and the one after it - each
; drawn only when its threshold is within sight. Corners are WORLD
; points now: turn away and the runway swings out of the window like
; everything else; line up and it comes back.
SLAB:   mov  ax,[posm]
        sub  ax,THRESH          ; wraps with the world
        xor  dx,dx
        mov  cx,RWGAP
        div  cx
        mov  cl,14
        shl  ax,cl              ; slot * 16384
        add  ax,THRESH
        mov  [rwz],ax
        call SLAB1
        mov  ax,[rwz]
        add  ax,RWGAP
        mov  [rwz],ax
        call SLAB1
        ret
SLAB1:  mov  ax,[rwz]
        sub  ax,[posm]          ; signed and wrapped: the near maths
        mov  [dthr],ax
        cmp  ax,4500
        jg   @@out
        cmp  ax,-3000
        jl   @@out
        mov  ax,-44             ; near-left corner, world
        sub  ax,[px]
        mov  [wdx2],ax
        mov  ax,[dthr]
        mov  [wdz2],ax
        call WCAM
        mov  word ptr [ph],0
        call PROJH
        mov  [qx0],ax
        mov  [qy0],dx
        mov  ax,44
        sub  ax,[px]
        mov  [wdx2],ax
        mov  ax,[dthr]
        mov  [wdz2],ax
        call WCAM
        mov  word ptr [ph],0
        call PROJH
        mov  [qx1],ax
        mov  [qy1],dx
        mov  ax,44
        sub  ax,[px]
        mov  [wdx2],ax
        mov  ax,[dthr]
        add  ax,RWLEN
        mov  [wdz2],ax
        call WCAM
        mov  word ptr [ph],0
        call PROJH
        mov  [qx2],ax
        mov  [qy2],dx
        mov  ax,-44
        sub  ax,[px]
        mov  [wdx2],ax
        mov  ax,[dthr]
        add  ax,RWLEN
        mov  [wdz2],ax
        call WCAM
        mov  word ptr [ph],0
        call PROJH
        mov  [qx3],ax
        mov  [qy3],dx
        mov  byte ptr [qmode],0 ; concrete, shaded by distance
        mov  word ptr [qn],4    ; the slab never meets the knife
        call POLY4
        call STRIPES
@@out:  ret
; ---- STRIPES: the centreline, one painted band at a time ------------------
; Bands of the WORLD now: each is a 2 m wide quad standing on the slab,
; rotated and projected like everything else. Far bands round to zero
; width and vanish - paint fades with distance, as paint does.
STRIPES:mov  word ptr [sn],0
@@s:    mov  ax,[sn]
        mov  cx,61
        imul cx
        add  ax,[dthr]
        mov  [sd0],ax
        add  ax,37
        mov  [sd1],ax
        cmp  ax,60              ; behind us once BOTH ends are
        jl   @@nx
        mov  ax,[sd0]
        cmp  ax,4400
        jg   @@done
        mov  ax,-1              ; near-left
        sub  ax,[px]
        mov  [wdx2],ax
        mov  ax,[sd0]
        mov  [wdz2],ax
        call WCAM
        mov  word ptr [ph],0
        call PROJH
        mov  [qx0],ax
        mov  [qy0],dx
        mov  ax,1               ; near-right
        sub  ax,[px]
        mov  [wdx2],ax
        mov  ax,[sd0]
        mov  [wdz2],ax
        call WCAM
        mov  word ptr [ph],0
        call PROJH
        mov  [qx1],ax
        mov  [qy1],dx
        mov  ax,1               ; far-right
        sub  ax,[px]
        mov  [wdx2],ax
        mov  ax,[sd1]
        mov  [wdz2],ax
        call WCAM
        mov  word ptr [ph],0
        call PROJH
        mov  [qx2],ax
        mov  [qy2],dx
        mov  ax,-1              ; far-left
        sub  ax,[px]
        mov  [wdx2],ax
        mov  ax,[sd1]
        mov  [wdz2],ax
        call WCAM
        mov  word ptr [ph],0
        call PROJH
        mov  [qx3],ax
        mov  [qy3],dx
        mov  byte ptr [qmode],1
        mov  byte ptr [qcol],3
        mov  word ptr [qn],4
        call POLY4
@@nx:   inc  word ptr [sn]
        cmp  word ptr [sn],40
        jb   @@s
@@done: ret
; ---- HBIL: the ground under world point (BX = x, DX = z), metres ASL ------
; Bilinear over the node torus, so the field is CONTINUOUS: the jet,
; the mesh and the landing judgment all stand on the same smooth
; ground, and nothing steps when a node line slides underneath.
HBIL:   push si
        mov  [wbx],bx
        mov  [wbz],dx
        mov  ax,bx
        mov  cl,10
        shr  ax,cl
        mov  [wnx],ax
        mov  ax,dx
        shr  ax,cl
        mov  [wnz],ax
        mov  ax,[wbx]
        mov  cl,2
        shr  ax,cl
        and  ax,255
        mov  [wfx],ax           ; fraction across the node, 0..255
        mov  ax,[wbz]
        shr  ax,cl
        and  ax,255
        mov  [wfz],ax
        mov  bx,[wnx]
        mov  dx,[wnz]
        call HGET
        xor  ah,ah
        call WORLDH2
        mov  [wh00],ax
        mov  bx,[wnx]
        inc  bx
        mov  dx,[wnz]
        call HGET
        xor  ah,ah
        call WORLDH2
        mov  [wh10],ax
        mov  bx,[wnx]
        mov  dx,[wnz]
        inc  dx
        call HGET
        xor  ah,ah
        call WORLDH2
        mov  [wh01],ax
        mov  bx,[wnx]
        inc  bx
        mov  dx,[wnz]
        inc  dx
        call HGET
        xor  ah,ah
        call WORLDH2
        mov  [wh11],ax
        mov  ax,[wh10]          ; lerp the near edge...
        sub  ax,[wh00]
        imul word ptr [wfx]
        mov  al,ah
        mov  ah,dl
        add  ax,[wh00]
        mov  si,ax
        mov  ax,[wh11]          ; ...the far edge...
        sub  ax,[wh01]
        imul word ptr [wfx]
        mov  al,ah
        mov  ah,dl
        add  ax,[wh01]
        sub  ax,si              ; ...and between them
        imul word ptr [wfz]
        mov  al,ah
        mov  ah,dl
        add  ax,si
        pop  si
        ret

; ---- ROTPT: (AX=t, BX=f) -> AX=x, DX=y on the banked screen ---------------
ROTPT:  push bx
        push si
        mov  si,ax              ; si = t
        imul word ptr [cosr]
        mov  cx,256
        idiv cx
        mov  di,ax              ; t*cos
        mov  ax,bx
        imul word ptr [sinr]
        mov  cx,256
        idiv cx
        sub  di,ax              ; x = cx0 + (t*cos - f*sin)/256
        add  di,[cx0]
        mov  ax,si
        imul word ptr [sinr]
        mov  cx,256
        idiv cx
        mov  si,ax              ; t*sin
        mov  ax,bx
        imul word ptr [cosr]
        mov  cx,256
        idiv cx
        add  ax,si              ; y = hcur + (t*sin + f*cos)/256
        add  ax,[hcur]
        mov  dx,ax
        mov  ax,di
        pop  si
        pop  bx
        ret

; ---- PROJH: world vertex (pu aside, pd ahead, ph high) -> AX,DX on screen --
; The slab's PROJW with a third coordinate. The guard is arithmetic,
; not taste: IDIV faults when a quotient bursts 16 bits, and a vertex
; eighty degrees off axis is off the glass anyway - so past |u| = 4d
; (or |dh| = 4d) the answer is a clamped +-1500 and no divide at all.
PROJH:  mov  ax,[pd]
        cmp  ax,NEARD           ; the slab still rides this clamp, and
        jge  @@d1               ; it must reach as deep as the terrain's
        mov  ax,NEARD           ; knife or the concrete stops short of
@@d1:   mov  [pd],ax            ; the glass while the ground goes on
        mov  ax,[h6]
        mov  cl,6
        shr  ax,cl
        add  ax,[hgnd]          ; the camera lives at SEA-LEVEL height,
        sub  ax,[ph]            ; not gear height: five seconds off the
        mov  [phd],ax           ; apron the ground rises, and the old
                                ; AGL camera sank INTO the island -
                                ; the picture "fine, then it breaks"
        or   ax,ax
        jns  @@a1
        neg  ax
@@a1:   mov  [pah],ax
        mov  ax,[pu]
        or   ax,ax
        jns  @@a2
        neg  ax
@@a2:   cmp  ax,[pah]
        jae  @@a3
        mov  ax,[pah]
@@a3:   mov  [pam],ax           ; the taller of |u|, |hd|
        mov  cl,3
        shr  ax,cl
        cmp  ax,[pd]
        jae  @@far              ; past 8d the quotients burst words
        mov  ax,[pu]
        mov  cx,220
        imul cx
        idiv word ptr [pd]
        mov  [ptv],ax
        mov  ax,[phd]
        mov  cx,220
        imul cx
        idiv word ptr [pd]
        jmp  @@rot
@@far:  mov  ax,[pu]            ; the box projection: the vertex slides
        mov  cx,1500            ; OUT ALONG ITS OWN RAY to the 1500
        imul cx                 ; boundary, direction intact - the old
        mov  cx,[pam]           ; corner-clamp bent it sideways and the
        idiv cx                 ; polygon slashed across the sky
        mov  [ptv],ax
        mov  ax,[phd]
        mov  cx,1500
        imul cx
        mov  cx,[pam]
        idiv cx
@@rot:  mov  bx,ax
        mov  ax,[ptv]
        call ROTPT
        ret

; ---- WORLDH2: the island, forty percent taller ----------------------------
; The engine's WORLDH is shared with TRAINER and stays untouched; the
; NEWTON island scales it 7/5 on top - peaks near 1550 m, because at
; the world's focal length the old 1110 read as rolling meadows.
WORLDH2:call WORLDH
        push cx
        mov  cx,7
        imul cx
        mov  cx,5
        idiv cx
        pop  cx
        ret

; ---- TERRPREP: rotate the node lattice around the camera ------------------
; 25x25 nodes centred on the camera's node, vertices LOCKED to world
; nodes - the OWL FLY way - so nothing swims when the camera turns or
; crosses a node line. Cached per frame: camera-frame u,d and height.
TERRPREP:
        mov  ax,[h6]
        mov  cl,6
        shr  ax,cl
        add  ax,[hgnd]
        mov  [thcam],ax         ; the camera's sea-level height, once
        mov  ax,[px]            ; (hs2/hc2 come from RENDER now, one
                                ; fractional heading for the whole frame)
        and  ax,1023
        mov  [tfx],ax
        mov  ax,[posm]
        and  ax,1023
        mov  [tfz],ax
        mov  ax,[px]
        mov  cl,10
        shr  ax,cl
        mov  [tnx],ax
        mov  ax,[posm]
        shr  ax,cl
        mov  [tnz],ax
        xor  si,si
        mov  word ptr [tta],-NR
@@a:    mov  word ptr [ttb],-NR
@@b:    mov  ax,[tta]
        mov  cl,10
        shl  ax,cl
        sub  ax,[tfx]
        mov  [wdx2],ax
        mov  ax,[ttb]
        shl  ax,cl
        sub  ax,[tfz]
        mov  [wdz2],ax
        push si
        call WCAM
        pop  si
        mov  ax,[pd]
        mov  [TRD+si],ax
        mov  ax,[pu]
        mov  [TRU+si],ax
        mov  bx,[tnx]
        add  bx,[tta]
        mov  dx,[tnz]
        add  dx,[ttb]
        call HGET
        xor  ah,ah
        call WORLDH2
        mov  [THT+si],ax
        add  si,2
        inc  word ptr [ttb]
        cmp  word ptr [ttb],NR
        jle  @@b
        inc  word ptr [tta]
        cmp  word ptr [tta],NR
        jle  @@a
        ret

; ---- NCLIP: cut the quad IU/ID/IH[0..3] on the plane d = 48 ---------------
; Sutherland-Hodgman against one plane: corners in front pass, corners
; behind die, and every crossing edge births a vertex ON the plane.
; Out: QU/QD/QH[0..qn-1], qn = 0..5. This is what ended the squares
; blinking out at the bottom of a banked window: a quad the camera has
; half-passed keeps its visible half.
NCLIP:  mov  word ptr [qn],0
        mov  word ptr [ncv],0
@@e:    mov  bx,[ncv]
        inc  bx
        and  bx,3
        mov  [ncj],bx           ; j = the edge's far end
        mov  bx,[ncv]
        add  bx,bx
        mov  si,[ncj]
        add  si,si
        mov  ax,[ID+bx]
        cmp  ax,[ncd]
        jl   @@ain
        push bx                 ; A is in front: A joins the polygon
        push si
        mov  di,[qn]
        add  di,di
        mov  cx,[IU+bx]
        mov  [QU+di],cx
        mov  cx,[ID+bx]
        mov  [QD+di],cx
        mov  cx,[IH+bx]
        mov  [QH+di],cx
        inc  word ptr [qn]
        pop  si
        pop  bx
@@ain:  mov  ax,[ID+bx]
        cmp  ax,[ncd]
        jl   @@bhalf
        mov  cx,[ID+si]         ; A front: crossing only if B behind
        cmp  cx,[ncd]
        jge  @@next
        jmp  @@cross
@@bhalf:mov  cx,[ID+si]         ; A behind: crossing only if B in front
        cmp  cx,[ncd]
        jl   @@next
@@cross:mov  ax,[ncd]           ; t = (knife - dA) * 256 / (dB - dA)
        sub  ax,[ID+bx]
        mov  cx,256
        imul cx
        mov  cx,[ID+si]
        sub  cx,[ID+bx]
        idiv cx
        mov  [wtmp2],ax         ; t, 0..256
        mov  ax,[IU+si]
        sub  ax,[IU+bx]
        imul word ptr [wtmp2]
        mov  al,ah
        mov  ah,dl
        add  ax,[IU+bx]
        mov  di,[qn]
        add  di,di
        mov  [QU+di],ax
        mov  cx,[ncd]
        mov  [QD+di],cx
        mov  ax,[IH+si]
        sub  ax,[IH+bx]
        imul word ptr [wtmp2]
        mov  al,ah
        mov  ah,dl
        add  ax,[IH+bx]
        mov  [QH+di],ax
        inc  word ptr [qn]
@@next: inc  word ptr [ncv]
        cmp  word ptr [ncv],4
        jl   @@e
        ret

; ---- TERR: the island around the camera, painter's order from TORD --------
; TORD walks the 576 quads farthest-first (baked at build time, sorted
; by true distance - a square ring is NOT a circle, and the corners of
; one used to poke through the sides of the next). Each quad is four
; cached corners through PROJH and one solid colour off the height
; ramp: banked, inverted, or pointed anywhere at all.
TERR:   call TERRPREP
        mov  word ptr [tqi],0
@@q:    mov  bx,[tqi]
        cmp  bx,576
        jae  @@done
        add  bx,bx
        mov  al,[TORD+bx]
        cbw
        mov  [tca],ax           ; the quad's node, kept for the checker
        add  ax,NR
        mov  cx,NSIDE
        imul cx
        mov  si,ax
        mov  al,[TORD+bx+1]
        cbw
        mov  [tcb],ax
        add  ax,NR
        add  si,ax
        add  si,si              ; word index of corner (a,b)
        ; ---- gather the four corners in camera space, cyclic order --
        mov  ax,[TRU+si]
        mov  [IU+0],ax
        mov  ax,[TRD+si]
        mov  [ID+0],ax
        mov  ax,[THT+si]
        mov  [IH+0],ax
        mov  ax,[TRU+si+2*NSIDE]
        mov  [IU+2],ax
        mov  ax,[TRD+si+2*NSIDE]
        mov  [ID+2],ax
        mov  ax,[THT+si+2*NSIDE]
        mov  [IH+2],ax
        mov  ax,[TRU+si+2*NSIDE+2]
        mov  [IU+4],ax
        mov  ax,[TRD+si+2*NSIDE+2]
        mov  [ID+4],ax
        mov  ax,[THT+si+2*NSIDE+2]
        mov  [IH+4],ax
        mov  ax,[TRU+si+2]
        mov  [IU+6],ax
        mov  ax,[TRD+si+2]
        mov  [ID+6],ax
        mov  ax,[THT+si+2]
        mov  [IH+6],ax
        mov  ax,[ID+0]          ; ---- the near and far of it ----
        mov  bx,ax
        mov  cx,[ID+2]
        cmp  cx,ax
        jge  @@x1
        mov  ax,cx
@@x1:   cmp  cx,bx
        jle  @@x2
        mov  bx,cx
@@x2:   mov  cx,[ID+4]
        cmp  cx,ax
        jge  @@x3
        mov  ax,cx
@@x3:   cmp  cx,bx
        jle  @@x4
        mov  bx,cx
@@x4:   mov  cx,[ID+6]
        cmp  cx,ax
        jge  @@x5
        mov  ax,cx
@@x5:   cmp  cx,bx
        jle  @@x6
        mov  bx,cx
@@x6:   mov  [tqd],ax           ; the near distance, kept for the haze
        push ax
        push bx
        mov  word ptr [ncd],NEARD ; ---- the FLOATING knife ----
        xor  si,si              ; the plane sits at max(8, |dh|/8) for
@@hm:   mov  ax,[thcam]         ; THIS quad's own corners, so every
        sub  ax,[IH+si]         ; vertex that survives the cut divides
        jns  @@hm1              ; EXACTLY - one projection per polygon.
        neg  ax                 ; Mixed exact-and-boxed corners buckled
@@hm1:  mov  cl,3               ; the quad into a bowtie, and its hull
        shr  ax,cl              ; fill was the triangle bleeding into
        inc  ax                 ; the neighbour square
        cmp  ax,[ncd]
        jle  @@hm2
        mov  [ncd],ax
@@hm2:  add  si,2
        cmp  si,8
        jb   @@hm
        pop  bx
        pop  ax
        cmp  bx,[ncd]           ; every corner behind the knife: gone
        jl   @@skip
        cmp  ax,12500           ; every corner past the haze: gone
        jg   @@skip
        cmp  ax,[ncd]
        jge  @@whole            ; all in front: no knife needed
        call NCLIP              ; the knife: keep the visible half
        cmp  word ptr [qn],3    ; (a sliver of nothing is nothing)
        jl   @@skip
        jmp  @@proj
@@whole:mov  word ptr [qn],4    ; untouched quads ride through whole
        mov  ax,[IU+0]
        mov  [QU+0],ax
        mov  ax,[ID+0]
        mov  [QD+0],ax
        mov  ax,[IH+0]
        mov  [QH+0],ax
        mov  ax,[IU+2]
        mov  [QU+2],ax
        mov  ax,[ID+2]
        mov  [QD+2],ax
        mov  ax,[IH+2]
        mov  [QH+2],ax
        mov  ax,[IU+4]
        mov  [QU+4],ax
        mov  ax,[ID+4]
        mov  [QD+4],ax
        mov  ax,[IH+4]
        mov  [QH+4],ax
        mov  ax,[IU+6]
        mov  [QU+6],ax
        mov  ax,[ID+6]
        mov  [QD+6],ax
        mov  ax,[IH+6]
        mov  [QH+6],ax
@@proj: mov  word ptr [ncv],0   ; ---- project every corner we kept ----
@@pj:   mov  bx,[ncv]
        add  bx,bx
        mov  ax,[QU+bx]
        mov  [pu],ax
        mov  ax,[QD+bx]
        mov  [pd],ax
        mov  ax,[QH+bx]
        mov  [ph],ax
        push si
        call PROJH
        pop  si
        mov  bx,[ncv]
        add  bx,bx
        add  bx,bx              ; the qx/qy pairs stride by four
        mov  [qx0+bx],ax
        mov  [qy0+bx],dx
        inc  word ptr [ncv]
        mov  ax,[ncv]
        cmp  ax,[qn]
        jl   @@pj
IF CALIB
        mov  ax,[tca]           ; the checker: colour = f(world node),
        add  ax,[tnx]           ; nothing else - a 4x4 palette of
        and  ax,3               ; sixteen distinct coats repeating
        mov  cx,[tcb]           ; every 4 km, so any square on screen
        add  cx,[tnz]           ; can be NAMED and checked
        and  cx,3
        shl  cx,1
        shl  cx,1
        add  ax,cx
        mov  bx,ax
        mov  bl,[CTAB+bx]
ELSE
        mov  ax,[THT+si]        ; ---- colour IS altitude, as before ----
        add  ax,[THT+si+2*NSIDE]
        add  ax,[THT+si+2*NSIDE+2]
        add  ax,[THT+si+2]
        mov  cl,2
        shr  ax,cl
        jnz  @@land
        mov  bl,29
        jmp  @@have
@@land: mov  bx,ax
        add  ax,ax
        add  ax,bx
        mov  bl,ah
        cmp  bl,12
        jbe  @@rmp
        mov  bl,12
@@rmp:  add  bl,32
        ; ---- the sun lives in the EAST: slopes facing it take a
        ; lighter coat, slopes turned away a darker one - and the flat
        ; look the pilot complained of becomes hills with two sides
        push bx
        mov  ax,[THT+si+2*NSIDE]
        add  ax,[THT+si+2*NSIDE+2]
        sub  ax,[THT+si]
        sub  ax,[THT+si+2]
        mov  cx,160             ; one shade per ~80 m of rise per node
        cwd
        idiv cx
        cmp  ax,2
        jle  @@sh1
        mov  ax,2
@@sh1:  cmp  ax,-2
        jge  @@sh2
        mov  ax,-2
@@sh2:  pop  bx
        add  bl,al
        cmp  bl,32              ; stay on the ramp
        jae  @@sh3
        mov  bl,32
@@sh3:  cmp  bl,44
        jbe  @@have
        mov  bl,44
@@have:
ENDIF
        mov  [qcol],bl
        mov  byte ptr [qmode],1 ; ---- the haze, three bands deep ----
        mov  byte ptr [qedge],0
        cmp  bl,29              ; water is water: no mesh on the sea -
        je   @@hz0              ; its grid dots read as static
        mov  ax,[tqd]
        cmp  ax,2000            ; the grid only on ground CLOSE enough
        jg   @@hz0              ; to want scale from it
        mov  byte ptr [qedge],1
@@hz0:  mov  ax,[tqd]           ; near: its own colour; middle: half
        cmp  ax,7000            ; dissolved into grey-green fog; far:
        jle  @@hzn              ; gone into it - and the 12.5 km cull
        cmp  ax,10200           ; pops inside the fog, unseen
        jle  @@hzm
        mov  byte ptr [qcol],45
        jmp  @@hzn
@@hzm:  mov  byte ptr [qmode],3
@@hzn:  call POLY4
        mov  byte ptr [qedge],0
@@skip: inc  word ptr [tqi]
        jmp  @@q
@@done: ret
; ---- POLY4: fill the convex quad (qx0,qy0)..(qx3,qy3) --------------------
; Per row: intersect all four edges, keep the outermost pair. Slow and
; obvious on purpose - a wrong slab is worse than a cheap one, and this
; is the routine the terrain will lean on.
;   qmode 0 = concrete (f-shaded, edge lines)   1 = flat colour [qcol]
POLY4:  mov  ax,[qy0]           ; ymin / ymax over the four corners
        mov  bx,ax
        cmp  ax,[qy1]
        jle  @@n1
        mov  ax,[qy1]
@@n1:   cmp  ax,[qy2]
        jle  @@n1a
        mov  ax,[qy2]
@@n1a:  cmp  ax,[qy3]
        jle  @@n2
        mov  ax,[qy3]
@@n2:   cmp  bx,[qy1]
        jge  @@n3
        mov  bx,[qy1]
@@n3:   cmp  bx,[qy2]
        jge  @@n3a
        mov  bx,[qy2]
@@n3a:  cmp  bx,[qy3]
        jge  @@n4
        mov  bx,[qy3]
@@n4:   cmp  word ptr [qn],5    ; the clip's fifth corner votes too
        jl   @@n4a
        cmp  ax,[qy4]
        jle  @@n4b
        mov  ax,[qy4]
@@n4b:  cmp  bx,[qy4]
        jge  @@n4a
        mov  bx,[qy4]
@@n4a:  or   ax,ax
        jge  @@n5
        xor  ax,ax
@@n5:   cmp  bx,199
        jle  @@n6
        mov  bx,199
@@n6:   mov  [tyv],ax
        mov  [tye],bx
@@row:  mov  ax,[tyv]
        cmp  ax,[tye]
        jg   @@done
        mov  word ptr [txl],32767
        mov  word ptr [txr],-32768
        mov  ax,[qx0]           ; edge 0-1
        mov  bx,[qy0]
        mov  cx,[qx1]
        mov  dx,[qy1]
        call EDGEX
        mov  ax,[qx1]           ; edge 1-2
        mov  bx,[qy1]
        mov  cx,[qx2]
        mov  dx,[qy2]
        call EDGEX
        mov  ax,[qx2]           ; edge 2-3
        mov  bx,[qy2]
        mov  cx,[qx3]
        mov  dx,[qy3]
        call EDGEX
        cmp  word ptr [qn],5
        je   @@e5
        mov  ax,[qx3]           ; edge 3-0, the plain quad's last
        mov  bx,[qy3]
        mov  cx,[qx0]
        mov  dx,[qy0]
        call EDGEX
        jmp  @@ecl
@@e5:   mov  ax,[qx3]           ; the clipped pentagon closes in two
        mov  bx,[qy3]
        mov  cx,[qx4]
        mov  dx,[qy4]
        call EDGEX
        mov  ax,[qx4]
        mov  bx,[qy4]
        mov  cx,[qx0]
        mov  dx,[qy0]
        call EDGEX
@@ecl:
        mov  ax,[txl]
        cmp  ax,[txr]
        jg   @@nx
        or   ax,ax              ; clip the span to the screen
        jge  @@c1
        xor  ax,ax
@@c1:   mov  [txl],ax
        mov  ax,[txr]
        cmp  ax,319
        jle  @@c2
        mov  ax,319
@@c2:   mov  [txr],ax
        mov  ax,[txl]
        cmp  ax,[txr]
        jg   @@nx
        cmp  byte ptr [qmode],1
        je   @@flat
        cmp  byte ptr [qmode],3
        je   @@half
        ; ---- the shade: f at the span centre, SOLO's concrete ramp ----
        mov  ax,[txr]
        add  ax,[txl]
        sar  ax,1
        sub  ax,[cx0]
        imul word ptr [sinr]
        mov  bx,256
        idiv bx
        mov  si,ax
        mov  ax,[tyv]
        sub  ax,[hcur]
        imul word ptr [cosr]
        mov  bx,256
        idiv bx
        sub  ax,si              ; f = ((y-hcur)cos - (x-cx0)sin)/256
        or   ax,ax
        jg   @@f1
        mov  ax,1
@@f1:   mov  cl,3
        shl  ax,cl
        cmp  ax,1023
        jbe  @@f2
        mov  ax,1023
@@f2:   mov  bx,ax
        mov  al,bh
        add  al,16
        mov  [pbase],al
        mov  al,bl
        mov  [pfrac],al
        mov  ax,[tyv]
        call ROWAD
        mov  di,ax
        add  di,[txl]
        mov  cx,[txr]
        sub  cx,[txl]
        inc  cx
        push di
        push cx
        mov  ax,[tyv]
        mov  bx,[txl]
        call WSTART
        call DFILLW
        pop  cx
        pop  di
        mov  byte ptr es:[di],4 ; the edge lines, both sides
        add  di,cx
        dec  di
        mov  byte ptr es:[di],4
        jmp  @@nx
@@half: mov  ax,[tyv]           ; the middle distance: every other
        call ROWAD              ; blue-noise pixel yields to the horizon
        mov  di,ax              ; haze - depth for the price of a
        add  di,[txl]           ; threshold test
        mov  cx,[txr]
        sub  cx,[txl]
        inc  cx
        mov  ax,[tyv]
        and  ax,15
        mov  bx,ax
        mov  cl,4
        shl  bx,cl              ; the tile row, screen-anchored
        mov  si,[txl]
@@hp:   mov  ax,si
        and  ax,15
        add  ax,bx
        push si
        mov  si,ax
        mov  al,[BNOISE+si]
        pop  si
        cmp  al,128
        jb   @@h10
        mov  al,[qcol]
        jmp  @@h11
@@h10:  mov  al,45              ; the fog's own grey-green
@@h11:  mov  es:[di],al
        inc  di
        inc  si
        loop @@hp
        jmp  @@nx
@@flat: mov  ax,[tyv]           ; paint: one colour...
        call ROWAD
        mov  di,ax
        add  di,[txl]
        mov  cx,[txr]
        sub  cx,[txl]
        inc  cx
        mov  al,[qcol]
        push di
        push cx
        rep  stosb
        pop  cx
        pop  di
        cmp  byte ptr [qedge],0 ; ...and OWL FLY's grid on the near
        je   @@nx               ; ground: a dark stroke down each side
        mov  byte ptr es:[di],0 ; of the quad, the scale the eye needs
        add  di,cx              ; when a kilometre of hillside fills
        dec  di                 ; the glass at seventy metres
        mov  byte ptr es:[di],0
@@nx:   inc  word ptr [tyv]
        jmp  @@row
@@done: ret

; ---- EDGEX: where edge (AX,BX)-(CX,DX) crosses row [tyv] -> txl/txr -------
EDGEX:  cmp  bx,dx
        je   @@out              ; horizontal edges cross nothing
        jl   @@ord
        xchg ax,cx              ; make BX the top
        xchg bx,dx
@@ord:  mov  si,[tyv]
        cmp  si,bx
        jl   @@out
        cmp  si,dx
        jge  @@out
        sub  si,bx              ; x = x0 + (y-y0)*(x1-x0)/(y1-y0)
        sub  dx,bx
        mov  [edy],dx           ; IMUL eats DX: the divisor must hide
        sub  cx,ax              ; in memory, and the base with it
        mov  [ex0],ax
        mov  ax,si
        imul cx
        idiv word ptr [edy]
        add  ax,[ex0]
        cmp  ax,[txl]
        jge  @@e1
        mov  [txl],ax
@@e1:   cmp  ax,[txr]
        jle  @@out
        mov  [txr],ax
@@out:  ret

; ---- TSINF: AX angle in 8.8 units -> AX = sin*256, lerped between units ----
; The render turned in whole units - 1.4 degree snaps, one every few
; ticks in a steady bank: the "two steps forward, one back" stutter the
; pilot reported. The physics always HAD the fraction; now the picture
; gets it too.
TSINF:  push bx
        push cx
        push dx
        mov  bx,ax
        mov  al,bh              ; the unit below
        xor  ah,ah
        push bx
        call TSIN
        mov  cx,ax
        pop  bx
        push cx
        mov  al,bh
        inc  al                 ; the unit above (TSIN wraps for free)
        xor  ah,ah
        call TSIN
        pop  cx
        sub  ax,cx
        mov  dl,bl              ; the fraction walks between them
        xor  dh,dh
        imul dx
        mov  al,ah
        mov  ah,dl
        add  ax,cx
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
        ; ---- the heading tape, finally telling the truth ----
        ; 3 px per unit, +-26 units of window; a dot every 4 units, a
        ; bar every 8, and the label every 32 - the 45-degree points,
        ; which a 256-unit circle hits exactly. The cyan mark is the
        ; RUNWAY AXIS: put it under the caret and the concrete is
        ; somewhere off the nose.
        mov  word ptr [tm],-26
@@ct:   mov  ax,[tm]
        cmp  ax,26
        jg   @@ctd
        mov  ax,[dhdg]
        add  ax,[tm]
        and  ax,255
        mov  [ty],ax            ; the unit under this column
        test ax,3
        jnz  @@ctn
        mov  ax,[tm]
        add  ax,ax
        add  ax,[tm]
        add  ax,160
        mov  di,ax              ; x = 160 + 3*offset
        mov  ax,[ty]
        test ax,31
        jz   @@big
        test ax,7
        jz   @@bar
        mov  ax,12              ; the lone dot between bars
        call ROWAD
        add  ax,di
        mov  di,ax
        mov  byte ptr es:[di],15
        jmp  @@ctn
@@bar:  mov  ax,11
        call ROWAD
        add  ax,di
        mov  di,ax
        mov  byte ptr es:[di],15
        mov  byte ptr es:[di+320],15
        mov  byte ptr es:[di+640],15
        jmp  @@ctn
@@big:  push di
        mov  ax,9
        call ROWAD
        add  ax,di
        mov  di,ax
        mov  cx,7
@@ct1:  mov  byte ptr es:[di],15
        add  di,320
        loop @@ct1
        pop  di
        mov  ax,[ty]            ; the label: unit/32 names the point
        mov  cl,5
        shr  ax,cl
        add  ax,ax
        mov  si,ax
        mov  si,[LBPT+si]
        mov  bx,di              ; centred under its bar; the +-26
        sub  bx,5               ; window keeps it on the glass
        mov  ax,2
        call FDR
@@ctn:  inc  word ptr [tm]
        jmp  @@ct
@@ctd:  mov  ax,[dhdg]          ; the runway axis rides the tape in cyan
        neg  ax
        and  ax,255
        cmp  ax,128
        jbe  @@cw1
        sub  ax,256
@@cw1:  cmp  ax,-26
        jl   @@ncy
        cmp  ax,26
        jg   @@ncy
        mov  bx,ax
        add  ax,ax
        add  ax,bx
        add  ax,160
        mov  di,ax
        mov  ax,20
        call ROWAD
        add  ax,di
        mov  di,ax
        mov  byte ptr es:[di-1],21
        mov  byte ptr es:[di],21
        mov  byte ptr es:[di+1],21
        mov  byte ptr es:[di+320-1],21
        mov  byte ptr es:[di+320],21
        mov  byte ptr es:[di+320+1],21
@@ncy:  mov  byte ptr es:[17*320+160],15
        mov  byte ptr es:[18*320+159],15
        mov  byte ptr es:[18*320+161],15
        ; the DME grew a second leg: how far to the slab, counting the
        ; sideways miles too (max + min/2, the honest octagon)
        mov  ax,[posm]
        sub  ax,THRESH          ; wraps with the world
        xor  dx,dx
        mov  cx,RWGAP
        div  cx
        mov  ax,RWGAP
        sub  ax,dx              ; metres ahead to the NEXT threshold
        mov  bx,[px]
        cmp  bx,8000h
        jb   @@px1
        neg  bx                 ; |east of the line|
@@px1:  cmp  ax,bx              ; ax = max, bx = min
        jae  @@oc1
        xchg ax,bx
@@oc1:  shr  bx,1
        add  ax,bx
        jnc  @@oc2
        mov  ax,0FFFFh
@@oc2:  xor  dx,dx
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
        ; ---- the surveyor's corner: north, east, thrust - the exact
        ; words, right of the compass, for the day the picture breaks
        ; and the hunt needs coordinates instead of adjectives
        mov  ax,[posm]
        call NUM
        mov  si,offset NBUF
        mov  ax,1
        mov  bx,244
        call FDR
        mov  ax,[px]
        call NUM
        mov  si,offset NBUF
        mov  ax,8
        mov  bx,244
        call FDR
        mov  ax,[T4]
        call NUM
        mov  si,offset NBUF
        mov  ax,15
        mov  bx,244
        call FDR
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
; 5.4 px per degree - the world's own focal length, shared with the
; horizon, the FPI and the terrain. The ladder belongs to the world,
; not to the glass: it lies parallel to the horizon and rolls with it.
; Solid above, dotted below - the instant which-way-is-the-earth cue.
; A gap in the middle is left for the datum, the FPI and the staple.
; Caller has ES = the back buffer.
LADR:   cmp  byte ptr [air],0   ; on the wheels there is nothing to read
        je   @@done
        mov  ax,100             ; the pilot's old rule, back in force:
        sub  ax,[hcur]          ; while the REAL horizon crosses the
        imul word ptr [cosr]    ; window, the ladder stays OUT of it -
        mov  cx,256             ; the rails light up only when sky and
        idiv cx                 ; ground have both walked off the glass
        mov  [lfc],ax           ; and these lines are all the pilot has
        or   ax,ax
        jns  @@fc1
        neg  ax
@@fc1:  cmp  ax,92              ; 110 was FLIGHT's number at 8 px/deg;
        jle  @@done             ; at the world scale it left a two-
                                ; degree band with neither horizon nor
                                ; rails - the all-green screen with
                                ; nothing to read. 92 lights the rungs
                                ; just BEFORE the horizon slips away
        mov  ax,[lfc]           ; and they follow the NOSE, not the
        cwd                     ; long-gone horizon: the four rungs
        mov  cx,27              ; nearest the datum, in degrees of five
        idiv cx
        neg  ax
        mov  cx,5
        imul cx
        sub  ax,5
        mov  [lp],ax
        add  ax,15
        mov  [lke],ax
@@l:    cmp  word ptr [lp],0
        je   @@next             ; zero belongs to the world, not to us
        cmp  word ptr [lp],-90  ; past the poles the numbers stop
        jl   @@next             ; meaning pitch
        cmp  word ptr [lp],90
        jg   @@next
        mov  ax,[lp]            ; f = -P*27/5: 5.4 px per degree, the
        mov  cx,27              ; WORLD focal length - the ladder must
        imul cx                 ; measure the same sky the horizon and
        mov  cx,5               ; the terrain are drawn in, or it lies
        idiv cx
        mov  bx,ax
        neg  bx
        xor  ax,ax              ; the line's centre sits at t = 0
        call ROTPT
        mov  [lcx],ax           ; ...rotated onto the banked screen
        mov  [lcy],dx
        cmp  dx,-60
        jl   @@next             ; the whole line is off the glass
        cmp  dx,260
        jg   @@next
        mov  ax,[cosr]          ; walk out along the HORIZON direction,
        mov  cx,-60             ; 8.8, starting 60 px to one side
        imul cx
        mov  [lx8],ax
        mov  ax,[sinr]
        mov  cx,-60
        imul cx
        mov  [ly8],ax
        mov  word ptr [li],0
@@pt:   mov  ax,[li]            ; 0..119: the centre gap is 44..76
        cmp  ax,44
        jb   @@vis
        cmp  ax,76
        jb   @@skip
@@vis:  cmp  word ptr [lp],0    ; below the horizon: dotted
        jg   @@draw
        test word ptr [li],1
        jnz  @@skip
@@draw: mov  ax,[lx8]
        mov  cl,8
        sar  ax,cl
        add  ax,[lcx]
        js   @@skip
        cmp  ax,319
        jg   @@skip
        mov  [lpx],ax
        mov  ax,[ly8]
        mov  cl,8
        sar  ax,cl
        add  ax,[lcy]
        js   @@skip
        cmp  ax,199
        jg   @@skip
        call ROWAD
        add  ax,[lpx]
        mov  di,ax
        mov  byte ptr es:[di],23
@@skip: mov  ax,[cosr]          ; one pixel further along the line
        add  [lx8],ax
        mov  ax,[sinr]
        add  [ly8],ax
        inc  word ptr [li]
        cmp  word ptr [li],120
        jb   @@pt
        mov  ax,[lp]            ; the label, at the line's left end
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
        mov  ax,[cosr]          ; the label rides the line's left end,
        mov  cx,-76             ; but stays upright: a 4x6 font has no
        imul cx                 ; rotation, and the era's HUDs did not
        mov  cl,8               ; turn their numbers either
        sar  ax,cl
        add  ax,[lcx]
        js   @@nolb
        cmp  ax,300
        jg   @@nolb
        mov  bx,ax
        mov  ax,[sinr]
        mov  cx,-76
        imul cx
        mov  cl,8
        sar  ax,cl
        add  ax,[lcy]
        sub  ax,2
        js   @@nolb
        cmp  ax,193
        jg   @@nolb
        mov  byte ptr [fcol],23
        mov  si,offset LBUF
        call FDR
        mov  byte ptr [fcol],15
@@nolb:
@@next: add  word ptr [lp],5
        mov  ax,[lp]
        cmp  ax,[lke]
        jle  @@l
@@done: ret

; ---- FPIND: the Flight Path Indicator - where the jet is REALLY going ------
; The circle sits gamma below the horizon, so it marks the spot the
; nose is merely pointing NEAR. On final you fly the CIRCLE onto the
; threshold; the gap up to the datum is the angle of attack, and the
; manual says that gap is normal.
FPIND:  cmp  byte ptr [air],0
        je   @@done
        mov  bx,[fpr]           ; it marks a place in the WORLD, so it
        cmp  bx,-56             ; rides the bank like the ladder does
        jge  @@c1
        mov  bx,-56
@@c1:   cmp  bx,56
        jle  @@c2
        mov  bx,56
@@c2:   xor  ax,ax
        call ROTPT
        cmp  ax,8
        jge  @@x1
        mov  ax,8
@@x1:   cmp  ax,311
        jle  @@x2
        mov  ax,311
@@x2:   mov  si,ax
        mov  ax,dx
        cmp  ax,44
        jge  @@f1
        mov  ax,44
@@f1:   cmp  ax,156
        jle  @@f2
        mov  ax,156
@@f2:   call ROWAD
        add  ax,si
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
        push cx
        push dx
        push si
        push di
        cmp  ax,[pmrow]         ; the row's tile anchor, cached: three
        jne  @@cut              ; spans in a row ask for the same one -
        mov  si,[texp]          ; unless one of them is sky and the
        cmp  si,[pmtex]         ; next is ground, which is a different
        je   @@have             ; table entirely
@@cut:  mov  [pmrow],ax
        mov  si,[texp]
        mov  [pmtex],si
        sub  ax,[hcur]          ; wings level, the world frame IS the
        mov  ah,0               ; screen frame; the tile row comes from
        mov  si,[texp]          ; the same table the banked path reads
        add  si,ax
        mov  al,[si]
        xor  ah,ah
        mov  [pf0],ax
        mov  ax,[cx0]
        neg  ax
        and  ax,15
        mov  [pt0],ax
@@have: mov  ax,[pt0]
        mov  [pti],ax
        xor  bx,bx
@@m:    mov  ax,[pti]
        and  ax,15
        add  ax,[pf0]
        mov  si,ax
        mov  ah,[BNOISE+si]
        mov  al,[pbase]
        cmp  [pfrac],ah
        jbe  @@m1
        inc  al
@@m1:   mov  [PATT+bx],al
        inc  word ptr [pti]
        inc  bx
        cmp  bx,16
        jb   @@m
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        ret

; ---- DFILLW: the same span, but the GRAIN BELONGS TO THE WORLD ------------
; No integer map can rotate a dither: it preserves the pixel lattice, so
; the 4x4 tile stays square with the screen and only its thresholds get
; shuffled - which is exactly why the grain kept reading horizontal. A
; real rotation has to walk fractional world coordinates per pixel, and
; that is what this does: t and f as 8.8 accumulators, stepping by
; (cos, -sin). The wrap at 65536 is harmless - 1024 divides it, and all
; we ever read are bits 8..9.
;  in: ES:DI dest, CX count, wt8/wf8 the span start, pbase/pfrac shade
DFILLW: jcxz @@z
        push bx
        push dx
        push si
        push bp
        mov  bx,[wt8]
        mov  dx,[wf8]
        mov  bp,[texp]          ; sky stands still, ground streams: the
@@p:    mov  al,dh              ; only difference is which table says
        xor  ah,ah              ; what tile row this distance is on
        mov  si,ax
        mov  al,[bp+si]
        mov  ah,bh              ; floor(t) & 15 the column
        and  ah,15
        add  al,ah
        xor  ah,ah
        mov  si,ax
        mov  ah,[BNOISE+si]
        mov  al,[pbase]
        cmp  [pfrac],ah
        jbe  @@l1
        inc  al
@@l1:   stosb
        add  bx,[cosr]          ; one pixel east in the WORLD frame
        sub  dx,[sinr]
        loop @@p
        pop  bp
        pop  si
        pop  dx
        pop  bx
@@z:    ret

; ---- WSTART: world coords of (BX = x, AX = y) into wt8/wf8, 8.8 ----------
WSTART: push cx
        push dx
        push si
        sub  ax,[hcur]
        mov  si,ax              ; si = dy
        sub  bx,[cx0]           ; bx = dx
        mov  ax,bx
        imul word ptr [cosr]
        mov  cx,ax
        mov  ax,si
        imul word ptr [sinr]
        add  ax,cx
        mov  [wt8],ax           ; t*256 = dx*cos + dy*sin
        mov  ax,si
        imul word ptr [cosr]
        mov  cx,ax
        mov  ax,bx
        imul word ptr [sinr]
        sub  cx,ax
        mov  [wf8],cx           ; f*256 = dy*cos - dx*sin
        pop  si
        pop  dx
        pop  cx
        ret

; ---- DFILL: fill CX pixels at ES:DI with PATT, phased by screen x ----------
DFILL:  jcxz @@z                ; CX=0 must mean zero, not 65536
        push bx
        mov  bx,di
        and  bx,15              ; the tile is 16 wide now, and 320 is
@@f:    mov  al,[PATT+bx]       ; still a multiple of it
        stosb
        inc  bx
        and  bx,15
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
        ; ---- four cloud coats, cut fresh every launch: the same
        ; random walk the old glued-on pair wore, now a wardrobe ----
        xor  bp,bp              ; bp = shape base in the tables
@@sh:   xor  bx,bx              ; the width walk
        mov  dx,55              ; the start walk begins near centre
        xor  si,si
@@cw:   call RND16
        mov  al,ah
        xor  ah,ah
        and  ax,7
        sub  ax,2               ; drift +3/-2: clouds like to grow
        add  bx,ax
        cmp  si,40
        jb   @@w1
        sub  bx,3               ; ...and taper at the top
@@w1:   or   bx,bx
        jns  @@w2
        xor  bx,bx
@@w2:   cmp  bx,105
        jle  @@w3
        mov  bx,105
@@w3:   call RND16
        mov  al,ah
        xor  ah,ah
        and  ax,3
        dec  ax
        add  dx,ax
        cmp  dx,15
        jge  @@w4
        mov  dx,15
@@w4:   cmp  dx,110
        jle  @@w5
        mov  dx,110
@@w5:   mov  di,bp
        add  di,si
        mov  [CSHW+di],bl
        mov  [CSHS+di],dl
        inc  si
        cmp  si,64
        jb   @@cw
        add  bp,64
        cmp  bp,256
        jb   @@sh
        ; ---- and NINETY-SIX of them, scattered over the whole torus:
        ; sixteen made a sky so big the eye called it empty ----
        xor  si,si
@@ci:   call RND16
        mov  [CLX+si],ax        ; anywhere at all: the world wraps
        call RND16
        mov  [CLZ+si],ax
        call RND16
        and  ax,1023
        add  ax,400
        mov  [CLH+si],ax        ; cloudbase 400..1423 m: real cumulus
        call RND16              ; heights, or the sky hugs the horizon
        and  ax,1023
        add  ax,500
        mov  [CLM+si],ax        ; size 500..1523 m: cumulus are BIG
        add  si,2
        cmp  si,192
        jb   @@ci
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
        db  45, 33,40,36        ; terrain haze: GREY-GREEN, not sky
                                ; blue - "синие горы" was the fog
                                ; borrowing the horizon's shirt
        db  28, 24,36,52        ; water: the pale far reach...
        db  29,  8,20,40        ; ...and the deep blue near
        ; the terrain ramp: colour IS altitude now, no dither anywhere
        ; on the land - the dither's per-tick remixing was the shimmer.
        ; Lowlands dark green climbing to light meadow, an olive hinge,
        ; browns lightening with height, white at the peaks.
        db  32,  8,24, 8        ; the darkest valley floor
        db  33, 11,28,10
        db  34, 14,32,12
        db  35, 18,36,15
        db  36, 23,40,18        ; high meadow
        db  37, 26,34,18        ; the olive hinge to rock
        db  38, 26,26,14
        db  39, 28,24,14        ; bare brown
        db  40, 34,30,20
        db  41, 42,38,30
        db  42, 50,48,42        ; scree going grey
        db  43, 57,56,54
        db  44, 63,63,63        ; the peak
        db  24, 22,36,24        ; grass, FOUR steps instead of two: the
        db  25, 18,33,19        ; dither only ever mixes NEIGHBOURS, so
        db  26, 14,30,14        ; thirding the step between shades thirds
        db  27, 11,27, 9        ; the grain the eye can see in the grass
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
LAUTO   db 'AUTO',0
LAB     db 'AB',0
C315    db '315',0
C090    db '090',0
C135    db '135',0
C180    db '180',0
C225    db '225',0
C270    db '270',0
LBPT    dw C000,C045,C090,C135  ; unit/32 -> the compass point's name
        dw C180,C225,C270,C315
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
ldyn    dw 0                    ; lift/16, SIGNED: the dynamics scale
lgv     dw 0                    ; scratch: lift/8 uncapped (G readout)
posm    dw 0                    ; world position NORTH, metres (wraps)
posacc  dw 0                    ; its 8.8 accumulator
px      dw 0                    ; world position EAST, metres (wraps too:
pxacc   dw 0                    ; the island is a torus both ways)
hdg     dw 0                    ; heading, 256 = the circle, 0 = north
hdgf    dw 0                    ; its 8.8 accumulator
hgnd    dw 0                    ; the ground under the wheels, metres ASL
abon    db 0                    ; 1 = the burner is lit
amode   db 1                    ; 1 = PILOT AUTOMATIC (the manual's P):
                                ; keys command the PATH and an unseen
                                ; pilot flies the same Newton to get it.
                                ; 0 = the raw stick, for pilots. One
                                ; physics, two translators.
gtgt    dw 6                    ; AUTO's commanded path angle, units
gerr    dw 0                    ; its scratch
gboost  dw 0                    ; the player's G lever while banked
rlvt    dw 0                    ; ticks since the ailerons went idle
gam     dw 0                    ; flight path angle, 256 = full circle
gamf    dw 0                    ; its 8.8 accumulator
sing    dw 0                    ; sin/cos of gamma, *256, cached
cosg    dw 256
gtmp    dw 0                    ; pitch-impulse scratch
ginv    db 0                    ; 1 = the attitude folded past vertical
droll   dw 0                    ; DISPLAY roll / heading: physics plus
dhdg    dw 0                    ; 128 units when over the top
adv8    dw 0                    ; this tick's step along the track, 8.8
l8e     dw 0                    ; lift the WEIGHT sees: l8v * cos(roll)
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
oldk9   dw 0,0                  ; the BIOS INT 9 we borrowed
roll    dw 0                    ; bank, 256 = the full circle
sinr    dw 0                    ; its sine and cosine, *256
cosr    dw 256
mrow    dw 0                    ; background walker: screen row
fmv     dw 0                    ; f at the pivot column of that row
spa     dw 0                    ; span start / length / sky-or-ground
spl     dw 0
sptype  db 0
pu      dw 0                    ; PROJW: metres left/right of the centre
pd      dw 0                    ; ...and metres ahead
ptv     dw 0                    ; ...the resulting t, in pixels
dthr    dw 0                    ; SLAB: distance to this runway's threshold
dnear   dw 0                    ; ...and the visible span of concrete
dfar    dw 0
sn      dw 0                    ; STRIPES: which painted band
sd0     dw 0                    ; ...its near and far edge, metres
sd1     dw 0
stw     dw 0                    ; ...its half width, pixels
hs2     dw 0                    ; heading trig for the frame, *256
hc2     dw 256
tfx     dw 0                    ; camera offset inside its node
tfz     dw 0
tnx     dw 0                    ; the camera's node
tnz     dw 0
tta     dw 0                    ; lattice walkers
ttb     dw 0
wdx2    dw 0                    ; WCAM in: world delta east / north
wdz2    dw 0
tqi     dw 0                    ; TORD walker
tca     dw 0                    ; the quad's node, for the checkerboard
tcb     dw 0
tqd     dw 0                    ; the quad's near distance, for the haze
thcam   dw 0                    ; the camera's ASL height this frame
ncd     dw NEARD                ; the floating knife's plane, per quad
CTAB    db 22,44, 3,29          ; the sixteen coats: red, white, light
        db  5,27,12,39          ; grey, blue / amber, dark green, cloud
        db 21,41,14,36          ; white, brown / cyan, light brown,
        db 17,33,43,28          ; deep green, light green / concrete,
                                ; green, snow, pale blue
rwz     dw 0                    ; the candidate runway's threshold, world z
wbx     dw 0                    ; HBIL scratch: the point, its node,
wbz     dw 0                    ; its fraction, its four corners
wnx     dw 0
wnz     dw 0
wfx     dw 0
wfz     dw 0
wh00    dw 0
wh10    dw 0
wh01    dw 0
wh11    dw 0
qedge   db 0                    ; flat mode: 1 = OWL FLY's near grid
qmode   db 0                    ; POLY4: 0 concrete, 1 flat, 2 terrain
qcol    db 0                    ; the flat mode's colour
ph      dw 0                    ; PROJH: the vertex height, metres
phd     dw 0                    ; ...camera-minus-vertex, signed
pah     dw 0                    ; ...its magnitude, and the max ray
pam     dw 0
tzn     dw 0                    ; TERR: camera z node, metres into it
tzf     dw 0
trj     dw 0                    ; ...ring being drawn
tzr     dw 0                    ; ...that ring's z node
td0     dw 0                    ; ...its near and far edge distance
td1     dw 0
tk      dw 0                    ; ...lateral node column
th0     dw 0                    ; ...the quad's corner heights
th1     dw 0
th2     dw 0
th3     dw 0
dss     dw 0                    ; DSGEN state (E_TERR.INC contract)
dsh     dw 0
dsx     dw 0
dsy     dw 0
dsamp   dw 0
dsac    dw 0
qx0     dw 0                    ; the quad being filled
qy0     dw 0
qx1     dw 0
qy1     dw 0
qx2     dw 0
qy2     dw 0
qx3     dw 0
qy3     dw 0
qx4     dw 0                    ; the near-clip's fifth corner
qy4     dw 0
qn      dw 4                    ; how many corners this time
QU      dw 5 dup(0)             ; the clipper's polygon, camera space
QD      dw 5 dup(0)
QH      dw 5 dup(0)
IU      dw 4 dup(0)             ; ...and its input copy
ID      dw 4 dup(0)
IH      dw 4 dup(0)
ncv     dw 0                    ; clip walker
ncj     dw 0
wtmp2   dw 0                    ; the crossing's parameter t
tyv     dw 0                    ; triangle walker: row, last row
tye     dw 0
txl     dw 0                    ; the row's span, outermost pair
txr     dw 0
edy     dw 1                    ; edge scratch: dy and x0
ex0     dw 0
bamp    dw 0                    ; knock amplitude
dmv     dw 0                    ; this row's ground distance, m
s16v    dw 0                    ; this row's shade value
ev      dw 0                    ; this row's runway half-width, px
relv    dw 0                    ; this row's distance past the threshold
alt16   dw 0                    ; HUD altitude, 1/16 m
fpr     dw 0                    ; flight path below the horizon, rows
lp      dw 0                    ; ladder walker, degrees
lfc     dw 0                    ; ladder: the horizon's distance from
lke     dw 0                    ; the centre, and the last rung to draw
lcx     dw 0                    ; ladder: the line's centre on screen
lcy     dw 0
lx8     dw 0                    ; ladder: the walk along the line, 8.8
ly8     dw 0
li      dw 0                    ; ladder: which pixel of the walk
lpx     dw 0                    ; ladder: the pixel's column
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
PATT    db 16 dup(0)            ; the row's 16-pixel pattern
pmrow   dw -9999               ; MKPATT: the row its anchor was cut for
pdy     dw 0                    ; ...that row's distance from the pivot
pf0     dw 0                    ; ...the world coords at its left edge
pt0     dw 0
pfi     dw 0                    ; ...and the walking copies
pti     dw 0
csx     dw 0                    ; a cloud segment's two ends
csy     dw 0
cex     dw 0
cey     dw 0
cdup    dw 320                  ; the twin pixel's offset, across the line
cf2     dw 0                    ; cloud walker: f in half steps
cfv     dw 0                    ; ...its whole part
cwv     dw 0                    ; ...the span's width
cxv     dw 0                    ; CLSEG: the walk's screen x and y...
cyv     dw 0
cxe     dw 0                    ; ...their 8.8 errors...
cye     dw 0
dxi     dw 0                    ; ...the step, split whole and fraction
dxf     dw 0
dyi     dw 0
dyf     dw 0
crb     dw 0                    ; ...the current row's base offset
ctrow   dw 0                    ; ...and the tile row, fixed per segment
texp    dw TSKY                 ; which tile-row table this span reads
pmtex   dw 0                    ; ...and which one the cache was cut for
wdith   db 0                    ; 1 = spans get the per-pixel world grain
wt8     dw 0                    ; the span's world coords, 8.8
wf8     dw 0
; ---- BNOISE: 16x16 blue noise, and the reason the grain can turn ----------
; An ORDERED matrix (Bayer) is built for sampling along the screen axes.
; Rotate the sampling and both indices change every pixel, its careful
; low-discrepancy order collapses, and the eye reads the result as dirt -
; that was the "grain at 45 degrees". Blue noise has no directional
; structure to lose: every direction samples it equally well, so the
; texture can ride the bank without paying for it in artefacts.
; Void-and-cluster, sigma 1.9, generated once and frozen here.
BNOISE  db 13,128,250,153,173,238,52,165,61,194,38,122,157,113,246,66
        db 90,222,55,5,81,199,142,120,0,150,29,255,17,97,233,200
        db 41,161,188,136,94,34,68,219,98,189,175,109,221,85,60,178
        db 119,24,209,108,230,183,248,25,86,239,145,76,210,49,171,6
        db 227,75,245,48,14,154,112,170,126,58,71,8,140,196,36,149
        db 101,141,166,125,64,213,43,202,228,47,235,207,23,164,131,253
        db 56,201,32,88,180,146,78,9,135,37,186,107,124,243,84,114
        db 12,234,191,3,223,251,103,163,220,16,159,177,99,45,73,218
        db 172,96,69,134,117,21,59,197,115,148,254,91,33,229,193,26
        db 143,40,160,242,208,35,176,89,217,130,80,63,1,211,156,65
        db 184,216,110,82,50,151,241,70,18,54,206,240,174,138,15,127
        db 237,57,7,198,168,100,123,185,44,195,31,152,118,192,106,95
        db 20,121,247,139,27,226,4,144,111,232,167,10,87,53,252,225
        db 79,155,181,92,62,205,77,249,179,22,102,137,236,74,39,203
        db 169,46,30,231,190,132,42,158,93,129,224,67,215,162,28,187
        db 105,212,72,116,19,104,214,11,244,83,204,51,182,2,133,147
HMAP    db 4096 dup(0)          ; the island: 64x64 node heights, toroidal
; the painter's order: all 576 terrain quads, farthest first, sorted by
; TRUE distance at build time (a PowerShell one-liner, not a boot loop)
TORD    label byte
        db -12,11,11,11,11,-12,-12,-12,10,11,-12,10,11,-11,11,10
        db 10,-12,-11,11,-11,-12,-12,-11,11,-10,-12,9,-12,-10,9,-12
        db 11,9,-10,11,-10,-12,9,11,-11,-11,10,-11,10,10,-11,10
        db -9,11,8,-12,11,-9,11,8,-12,8,-12,-9,8,11,-9,-12
        db 9,-11,9,10,-11,9,-10,-11,10,-10,10,9,-11,-10,-10,10
        db 7,-12,-12,-8,-8,11,11,-8,-12,7,11,7,7,11,-8,-12
        db 10,-9,10,8,8,-11,-9,-11,8,10,-9,10,-11,8,-11,-9
        db -10,9,-10,-10,9,-10,9,9,6,11,11,6,6,-12,-12,-7
        db -7,11,-7,-12,-12,6,11,-7,7,-11,10,-8,10,7,-8,10
        db -8,-11,7,10,-11,-8,-11,7,-9,9,5,-12,-10,-9,9,8
        db 5,11,8,9,8,-10,11,5,9,-9,-12,5,-10,8,11,-6
        db -12,-6,-6,-12,-9,-10,-6,11,-12,4,-5,11,-7,-11,-11,-7
        db 11,4,10,6,-5,-12,4,11,10,-7,11,-5,4,-12,-12,-5
        db -11,6,-7,10,6,10,6,-11,7,-10,7,9,-8,9,9,-8
        db 9,7,-8,-10,-10,7,-10,-8,8,-9,-9,-9,-9,8,-12,-4
        db -4,11,-4,-12,11,-4,3,11,3,-12,-12,3,11,3,8,8
        db 5,10,5,-11,10,-6,-6,-11,-11,-6,-6,10,-11,5,10,5
        db 11,-3,-12,-3,11,2,-3,-12,-3,11,2,-12,2,11,-12,2
        db -12,1,-12,-2,-2,-12,-2,11,11,-2,11,1,1,11,1,-12
        db 6,9,6,-10,11,-1,11,0,0,-12,-1,11,0,11,9,6
        db -1,-12,9,-7,-7,9,-12,0,-10,-7,-10,6,-12,-1,-7,-10
        db 10,4,-11,4,-5,10,4,10,10,-5,-5,-11,-11,-5,4,-11
        db 8,7,-8,8,7,8,-9,7,8,-8,7,-9,-8,-9,-9,-8
        db -4,10,-4,-11,10,-4,3,10,-11,-4,10,3,-11,3,3,-11
        db -10,5,-6,9,-6,-10,5,9,5,-10,-10,-6,9,-6,9,5
        db 10,2,-11,-3,2,10,-3,10,10,-3,-3,-11,-11,2,2,-11
        db 8,-7,6,8,8,6,-7,8,-9,-7,-9,6,-7,-9,6,-9
        db -2,-11,-2,10,-8,-8,1,-11,1,10,7,-8,10,1,-11,-2
        db -8,7,7,7,-11,1,10,-2,-1,10,4,9,9,4,0,10
        db -1,-11,0,-11,4,-10,9,-5,-10,4,-11,0,-10,-5,10,0
        db -11,-1,10,-1,-5,-10,-5,9,9,-4,-9,-6,-4,9,8,-6
        db 8,5,-6,8,3,-10,-4,-10,-6,-9,9,3,5,8,-9,5
        db 5,-9,3,9,-10,-4,-10,3,6,-8,7,6,7,-7,-8,6
        db 6,7,-7,-8,-7,7,-8,-7,-3,-10,9,2,-10,2,2,9
        db -10,-3,9,-3,2,-10,-3,9,9,-2,-5,8,-9,-5,4,8
        db 9,1,-10,1,-9,4,-10,-2,-2,9,1,9,8,4,-5,-9
        db 4,-9,-2,-10,8,-5,1,-10,0,9,9,0,-10,0,-10,-1
        db 9,-1,-1,9,-1,-10,0,-10,-8,5,5,-8,5,7,-8,-6
        db -6,-8,7,-6,7,5,-6,7,-9,3,8,-4,-9,-4,3,-9
        db 8,3,3,8,-4,8,6,-7,-7,6,-4,-9,6,6,-7,-7
        db 2,-9,2,8,-9,-3,-3,8,8,-3,-3,-9,8,2,-9,2
        db 7,-5,-8,4,-8,-5,-5,-8,4,-8,7,4,4,7,-5,7
        db -9,1,-2,8,-9,-2,8,1,-2,-9,1,8,1,-9,8,-2
        db -9,0,-9,-1,5,-7,6,5,-7,-6,5,6,6,-6,-7,5
        db -6,6,8,-1,8,0,0,8,-1,8,-1,-9,0,-9,-6,-7
        db 3,-8,7,3,7,-4,-8,3,-4,-8,-4,7,-8,-4,3,7
        db 6,4,-7,4,6,-5,4,6,4,-7,2,-8,-7,-5,-3,7
        db -8,-3,-5,6,-3,-8,7,2,7,-3,-8,2,-5,-7,2,7
        db 5,-6,5,5,-6,-6,-6,5,-8,1,1,-8,-2,7,7,-2
        db 1,7,-2,-8,-8,-2,7,1,0,7,7,-1,-8,0,7,0
        db -8,-1,-1,-8,-1,7,0,-8,6,3,-4,6,-7,-4,-7,3
        db 3,6,3,-7,-4,-7,6,-4,5,4,-5,-6,4,-6,-6,4
        db 5,-5,-6,-5,-5,5,4,5,2,-7,-3,-7,6,2,-3,6
        db 2,6,-7,-3,6,-3,-7,2,6,1,1,-7,6,-2,-2,6
        db -7,-2,1,6,-2,-7,-7,1,-1,6,-1,-7,0,6,6,-1
        db 0,-7,6,0,-6,-4,-6,3,-4,5,-4,-6,5,-4,-7,0
        db 5,3,3,5,-7,-1,3,-6,-5,-5,-5,4,4,-5,4,4
        db -6,2,2,5,5,-3,5,2,-3,5,-6,-3,2,-6,-3,-6
        db 3,4,4,-4,-5,3,-5,-4,3,-5,4,3,1,5,-2,-6
        db -2,5,1,-6,-6,-2,5,1,5,-2,-6,1,-4,4,-4,-5
        db -6,-1,-6,0,-1,-6,5,0,5,-1,-1,5,0,-6,0,5
        db 4,2,-5,2,-5,-3,-3,-5,2,4,2,-5,4,-3,-3,4
        db -4,3,3,3,-4,-4,3,-4,4,-2,-2,4,1,4,-2,-5
        db 1,-5,4,1,-5,1,-5,-2,-1,4,4,-1,-5,0,-1,-5
        db -5,-1,0,4,0,-5,4,0,3,2,-4,2,-3,3,2,-4
        db 3,-3,-3,-4,2,3,-4,-3,1,-4,-4,-2,3,1,3,-2
        db 1,3,-4,1,-2,3,-2,-4,-4,-1,-4,0,2,-3,-1,-4
        db 2,2,0,3,0,-4,3,0,3,-1,-3,-3,-1,3,-3,2
        db -3,-2,-2,-3,-2,2,2,1,1,2,-3,1,2,-2,1,-3
        db -1,2,0,-3,2,-1,-1,-3,2,0,-3,0,-3,-1,0,2
        db -2,-2,1,-2,1,1,-2,1,0,1,-1,-2,-1,1,-2,-1
        db 1,-1,-2,0,0,-2,1,0,0,-1,0,0,-1,-1,-1,0
TRU     dw 625 dup(0)           ; the rotated lattice: camera-frame u,
TRD     dw 625 dup(0)           ; camera-frame d, and the height
THT     dw 625 dup(0)
TSKY    db 256 dup(0)           ; sky: tile row per distance, standing
SBASE   db 200 dup(0)           ; per-height-above-horizon: sky shade
SFRAC   db 200 dup(0)           ; per-height-above-horizon: sky fraction
CSHW    db 256 dup(0)           ; the four coats: width per row...
CSHS    db 256 dup(0)           ; ...and start column, 64 rows each
CLX     dw 96 dup(0)            ; the ninety-six clouds: east, north,
CLZ     dw 96 dup(0)            ; base height, size
CLH     dw 96 dup(0)
CLM     dw 96 dup(0)
VLD     dw 24 dup(0)            ; this frame's visible list: distance,
VLU     dw 24 dup(0)            ; sideways reach, instance
VLI     db 24 dup(0)
qcn     dw 0                    ; how many made the cut
qcb     dw 0                    ; scratch: pick / shape base
qcd     dw 0                    ; the cloud being drawn: d, u, index
qcu     dw 0
qci     dw 0
qct     dw 0                    ; its centre t, base f, scale 8.8
qcf     dw 0
qcs     dw 0
qch     dw 0                    ; rows to draw, source step, walkers
qcp     dw 0
qcr     dw 0
qcw     dw 0
qcv     dw 0                    ; this row's width, px

        INCLUDE N_DEBUG.INC
        INCLUDE ..\..\..\ENGINE\E_MATH.INC
        INCLUDE ..\..\..\ENGINE\E_TERR.INC
        INCLUDE ..\..\..\ENGINE\E_SND.INC

CODE    ENDS
        END START



