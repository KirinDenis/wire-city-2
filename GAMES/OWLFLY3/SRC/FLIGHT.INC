; FLIGHT.INC - part of WIRE CITY (included from OWLFLY3.ASM)
; ============================================================================
;  INPUT  (via KEYS table) -> update camera
; ============================================================================
; turn (yaw) + bank (roll) + climb + auto-advance along heading
; ============================================================================
;  INPUT - one physics tick of the jet flight model (see constants block).
;  Order: air density -> engine (fuel burn, thrust) -> drag -> F=ma airspeed
;  -> turn + bank (induced drag) -> pitch/energy (dive gains speed, climb
;  costs it) -> stall -> altitude clamp -> wind drift -> advance along heading.
; ============================================================================
INPUT:
        cmp  byte [spect],0 ; WATCHING: the world turns, we do not fly
        je   .nspec
        call SYMSEG:SPECTUPF
        jmp  .dwr2             ; ...and everything else still gets its tick
.nspec:
        cmp  byte [dying],0
        je   .alive2
        ; the fall: the world keeps turning, we just watch the wreck
        inc  word [dytick]
        cmp  byte [ride],0      ; riding: the pilot's SPACE is the
        je   .dyspc            ;  Shilka's TRIGGER, not the answer to
        call RIDEHANDS          ;  the prompt - his hands keep working,
        jmp  .dwar              ;  and the wreck waits for his return
.dyspc: cmp  word [dytick],18
        jb   .dwar             ; ignore Space for the first second
        mov  al,[KEYS+SC_SP]    ; held, or the tap the latch rescued -
        or   al,[tapsp]         ;  a lost SPACE here read as a dead key
        je   .dwar
        call UISEG:PLAYERRESETF   ; EVICTED to UISEG, beside the landing code
                                ;  it now has to talk to. Once per death, and
                                ;  it was the coldest thing left in here
.dwar: cmp  word [flbcnt],0
        je   .dwr2
        mov  ax,[lasttk]        ; the recording is half-rate: play it so
        test ax,1
        jnz  .dwr2
        dec  word [flbcnt]  ; the flashback rolls one sample forward
        mov  ax,[flbc]
        add  ax,12
        cmp  ax,FLBSZ
        jb   .dwr1
        xor  ax,ax
.dwr1: mov  [flbc],ax
.dwr2: call PLANESUPD
        call MSLUPD
        call TRCUPD
        call AMSLUPD
        call AIGUN
        call WRECKUPD
        ret
.alive2:
        ; --- the crewed seat: the pilot's hands are on the Shilka. Hand
        ; them over ONCE a tick, then fly the jet below hands-off - every
        ; stick and pedal read gates on [ride], the physics does not.
        cmp  byte [ride],0
        je   .own2
        call RIDEHANDS
.own2:
        ; --- air density: rho = 256 - camy/8, clamped to 64..256 ---
        mov  ax,[camy]
        mov  bx,ax
        mov  cl,3
        shr  bx,cl
        mov  ax,256
        sub  ax,bx
        cmp  ax,64
        jge  .r1
        mov  ax,64
.r1:   mov  [rho],ax
        cmp  byte [ride],0      ; riding: W and S are the BARRELS now -
        je   .thok              ;  the throttle holds where he left it,
        mov  byte [abon],0      ;  and nobody's hand is on the burner
        jmp  .ab0
.thok:
        ; --- throttle: W up, S down; A holds the afterburner. The
        ; F-15 SE II gates joined in OWL FLY II: Shift+plus slams the
        ; lever to the stop, Shift+minus chops it to idle ---
        mov  al,[KEYS+SC_W]     ; held...
        or   al,[tapw]          ; ...or the tap the latch rescued
        jne  .tup
        cmp  byte [KEYS+SC_NPP],0
        jne  .tup
        cmp  byte [KEYS+SC_EQ],0
        je   .tw
.tup:  ; The throttle GATE: ANY throttle key with a shift on it slams the
        ; lever to the stop.
        ;
        ; THIS WENT ROUND ONCE AND CAME BACK, so the reasoning is written
        ; down. '+' IS Shift+'=' on a real keyboard - the same keystroke,
        ; indistinguishable at the scancode - so a rule that says "shift
        ; slams" necessarily makes '+' slam, and '+' can then never ramp.
        ; That was reported once as "+ does nothing" (2026-07-27) and the
        ; gate was narrowed to Shift+W alone; it was then reported the other
        ; way as "Shift with +/- does not work" (2026-08-06), which is the
        ; same fact seen from the other side.
        ;
        ; It cannot be both, so it is resolved by MEANING instead of by
        ; keyboard: '=' is the gentle one and ramps, '+' is the loud one and
        ; slams. Ramping still lives on W/S and on the numpad pair, so
        ; nothing is lost - and a pilot who wants everything at once reaches
        ; for '+', which is now exactly what it does.
        mov  al,[KEYS+SC_LSH]
        or   al,[KEYS+SC_RSH]
        jz   .tu1
        mov  word [throt],64
        jmp  .tw
.tu1:  mov  ax,[throt]
        add  ax,4               ; FOUR a tick, not two: idle to the stop in
                                ;  nine tenths of a second instead of nearly
                                ;  two. A lever you have to hold down while
                                ;  counting does not read as a throttle, it
                                ;  reads as a delay - and the slam gates
                                ;  (Shift+W, '+', Shift+numpad) exist
                                ;  precisely because the ramp was still too
                                ;  slow to use in a fight
        cmp  ax,64
        jle  .tw1
        mov  ax,64
.tw1:  mov  [throt],ax
.tw:   mov  al,[KEYS+SC_S]
        or   al,[tapsd]         ; the rescued tap counts too
        jne  .tdn
        cmp  byte [KEYS+SC_NPM],0
        jne  .tdn
        cmp  byte [KEYS+SC_MIN],0
        je   .ts
.tdn:  mov  al,[KEYS+SC_LSH]   ; idle gate: same rule, same reasoning
        or   al,[KEYS+SC_RSH]
        jz   .td1
        mov  word [throt],0
        jmp  .ts
.td1:  mov  ax,[throt]
        sub  ax,4               ; and back the same way it went up
        jns  .ts1
        xor  ax,ax
.ts1:  mov  [throt],ax
.ts:   mov  byte [abon],0
        cmp  byte [KEYS+SC_A],0
        je   .ab0
        mov  byte [abon],1  ; afterburner lit (needs fuel, checked below)
.ab0:
        ; --- engine: burn fuel; jet thrust breathes air: T*(rho+256)/512,
        ; scaled by throttle/64; the afterburner QUADRUPLES it and drinks
        ; eight times the fuel.
        ;
        ; IT USED TO DOUBLE, AND DOUBLE IS NOT ENOUGH TO CLIMB ON. Measured
        ; clean at full throttle, net acceleration per tick - what the pilot
        ; actually feels - against the angle he is holding:
        ;
        ;         pitch    0    14    24    32    46      (256ths of a circle)
        ;   x2, vel 450    7    -1    -6    -9   -14
        ;   x4, vel 450   18    10     5     2    -3
        ;
        ; At x2 every climb angle is zero or negative: point the nose up and
        ; the aeroplane bleeds, and past 20 degrees it bleeds into the stall
        ; and the nose falls through on its own. Nobody noticed for as long as
        ; a sortie began at 1450 doing CRUISE 736 - the jet was handed to you
        ; with all the energy it was ever going to need. Now a sortie begins
        ; STOPPED on a runway and unsticks around 264, and this game had never
        ; been flown at that end of its own model. Time to a thousand units off
        ; the deck: twenty-two seconds at x2, six at x4.
        ;
        ; ONLY THE BURNER CHANGED. Dry thrust is untouched, so the clean jet
        ; still runs out at CRUISE and cruises exactly as it always did - the
        ; proven model is not being retuned, it is being given a top end.
        ; What the burner costs is now the honest part: 8 fuel a tick against
        ; a 12000 tank is about eighty seconds of it in a sortie of eleven
        ; minutes. It is a thing you spend, not a thing you leave on. ---
        xor  cx,cx              ; default thrust 0 (flame-out)
        mov  ax,[fuel]
        test ax,ax
        jz   .nofu
        dec  ax
        mov  [fuel],ax
        mov  ax,[rho]
        add  ax,256
        mov  bx,ax
        mov  ax,THRUST
        imul bx                 ; DX:AX = THRUST*(rho+256)
        mov  bx,512
        idiv bx
        imul word [throt]   ; * throttle
        mov  bx,64
        idiv bx                 ; /64
        mov  cx,ax
        cmp  byte [abon],0
        je   .noth
        add  cx,cx              ; afterburner: FOUR times dry thrust...
        add  cx,cx
        mov  ax,[fuel]          ; ...and burn 7 extra units for it
        sub  ax,7
        jns  .abf
        xor  ax,ax
.abf:  mov  [fuel],ax
        jmp  .noth
.nofu: mov  byte [abon],0  ; tanks dry: no burner glow either
.noth: mov  [teff],cx

        ; --- F / L / B: flaps, gear, airbrake. Three edges, three toggles.
        ; Nothing is interlocked and nothing is refused - put the gear down
        ; at six hundred knots if you like, and wear the drag ---
        call UISEG:SWKEYSF   ; every plain on/off switch on the panel,
                                ;  read off one table out in UISEG
        mov  ax,VSTALL          ; flaps buy a slower stall - three quarters
        cmp  byte [flaps],0 ;  of it - and that is what they are FOR
        je   .nvs
        mov  ax,VSTALL*3/4
.nvs:  mov  [vstl],ax

        ; --- drag = vel*rho/DRAGK ; net force = thrust - drag ---
        mov  ax,[vel]
        imul word [rho]     ; DX:AX = vel*rho
        mov  bx,DRAGK
        idiv bx
        mov  bx,ax              ; bx = drag
        ; ...and everything hanging in the airstream adds its share of it.
        ; A quarter for the flaps, a half for the gear, the whole of it
        ; again for the board: full dirty is nearly three times clean, so
        ; the jet washes speed off in a hurry and will not get it back
        ; until the pilot cleans up.
        mov  ax,bx
        mov  cl,2
        shr  ax,cl              ; a quarter
        cmp  byte [flaps],0
        je   .dgr
        add  bx,ax
.dgr:  cmp  byte [gear],0
        je   .dbk
        add  bx,ax
        add  bx,ax              ; a half
.dbk:  cmp  byte [abrk],0
        je   .ddn
        add  bx,ax
        add  bx,ax
        add  bx,ax
        add  bx,ax              ; and the board doubles the clean figure
.ddn:
        mov  ax,[teff]
        sub  ax,bx              ; ax = net force (+/-)

        ; --- accel = force*64/mass ; mass = MEMPTY + fuel/3 ---
        mov  cx,64
        imul cx                 ; DX:AX = force*64 (32-bit)
        push ax
        push dx
        mov  ax,[fuel]
        xor  dx,dx
        mov  bx,3
        div  bx
        add  ax,MEMPTY
        mov  bx,ax              ; bx = mass (4000..6000)
        pop  dx
        pop  ax
        idiv bx                 ; ax = accel this tick
        add  ax,[vel]
        jns  .v0
        xor  ax,ax              ; airspeed never negative
.v0:   mov  [vel],ax

        ; --- ROLL: left/right arrows spin the ailerons, full 360 degrees ---
        mov  word [tmpi],0
        cmp  byte [tgtcam],0
        jne  .nr               ; F4: hands off, dihedral takes over
        cmp  byte [ride],0
        jne  .nr               ; riding: the arrows drive the TRACKS
        cmp  byte [KEYS+SC_CTL],0
        jne  .nr               ; Ctrl+arrow is a LOOK, not a roll - the whole
                                ; point of putting it there is that the hand
                                ; never leaves the stick, so it must not bank
        mov  al,[KEYS+SC_LF]
        or   al,[taplf]         ; a rescued tap rolls one tick
        je   .nl
        mov  ax,[roll]
        sub  ax,3               ; roll rate: full barrel roll in ~4.7 s
        and  ax,255
        mov  [roll],ax
        mov  word [tmpi],1
.nl:   mov  al,[KEYS+SC_RT]
        or   al,[taprt]
        je   .nr
        mov  ax,[roll]
        add  ax,3
        and  ax,255
        mov  [roll],ax
        mov  word [tmpi],1
.nr:   cmp  word [tmpi],0  ; hands off: the jet HOLDS its bank in free
        jne  .rlp              ; air (real handling at the big scale) - only
        cmp  byte [ride],0      ; ...unless the pilot is in the Shilka:
        jne  .rlq              ;  the autopilot rights the wings anywhere
        mov  ax,[camy]          ; the ground cushion rights the wings, and at
        sub  ax,[lgnd]          ; 2/tick it cannot save a heavy bank in time
        cmp  ax,90
        jge  .rlp
.rlq:  mov  ax,[roll]
        test ax,ax
        jz   .rlp
        cmp  ax,128
        ja   .rlup             ; 129..255: roll upward to 256 (= level)
        sub  ax,2               ; 1..128: roll down toward 0
        jns  .rls1
        xor  ax,ax
.rls1: cmp  ax,2               ; snap the last couple of units
        ja   .rls2
        xor  ax,ax
.rls2: mov  [roll],ax
        jmp  .rlp
.rlup: add  ax,2
        and  ax,255
        cmp  ax,254
        jb   .rlu2
        xor  ax,ax
.rlu2: mov  [roll],ax
.rlp:
        ; --- RUDDER: Q/E yaw the nose flat, no bank. Slow like a real
        ; rudder: 1 unit/tick = a full circle in ~14 s. Good for lining
        ; up a runway or a gun run without dropping a wing.
        xor  cx,cx              ; r = rudder input, in eighths
        cmp  byte [ride],0
        jne  .rde              ; riding: no feet on these pedals
        cmp  byte [KEYS+SC_1],0 ; the F-15 pedals: top-row 1 and 3
        jne  .rdl              ; (numpad 7/9 as aliases; Z/C left the
        cmp  byte [KEYS+SC_NP7],0 ; pedals for the radar zoom -
        je   .rdq              ; Z/X per the manual)
.rdl:  sub  cx,8
.rdq:  cmp  byte [KEYS+SC_3],0
        jne  .rdr
        cmp  byte [KEYS+SC_NP9],0
        je   .rdz
.rdr:  add  cx,8
.rdz:  jcxz .rde
        ; LOCAL yaw (community feedback): the rudder turns about the
        ; plane's own vertical axis, so it blends by bank exactly like
        ; the elevator does - wings level it is the old flat turn, in
        ; knife-edge the top rudder holds the nose up, and coordinated
        ; turns finally add up. Fractions ride pfrac/hfrac.
        push cx
        mov  ax,[roll]
        add  ax,64
        call SINQ               ; cos(roll)
        pop  cx
        push cx
        imul cx                 ; r*cos*256 (32-bit)
        mov  bx,256
        idiv bx                 ; eighths of heading
        add  ax,[hfrac]
        cwd
        mov  bx,8
        idiv bx
        mov  [hfrac],dx
        add  ax,[heading]
        and  ax,255
        mov  [heading],ax
        mov  ax,[roll]
        call SINQ               ; sin(roll)
        pop  cx
        imul cx
        mov  bx,256
        idiv bx
        neg  ax                 ; top rudder raises the nose
        add  ax,[pfrac]
        cwd
        mov  bx,8
        idiv bx
        mov  [pfrac],dx
        add  [pitch],ax
.rde:
        ; --- PITCH: real fighter controls. Pull (DOWN key) rotates the nose
        ; through the roll plane: pitch_rate = q*cos(roll), yaw = q*sin(roll).
        ; Wings level -> loop; knife-edge -> flat turn; inverted -> split-S.
        xor  cx,cx              ; q = elevator direction
        cmp  byte [tgtcam],0
        jne  .nopq             ; F4: the stick is centred
        cmp  byte [ride],0
        jne  .nopq             ; riding: centred too - hands-off trim
        mov  al,[KEYS+SC_DN]
        or   al,[tapdn]         ; a rescued tap pulls one tick
        je   .q1
        mov  cx,1               ; pull: nose up
.q1:   mov  al,[KEYS+SC_UP]
        or   al,[tapup]
        je   .q2
        sub  cx,1               ; push: nose down
.q2:   jcxz .nopq
        ; the stick ramps: a tap nudges the nose a third of a degree
        ; (aiming), a hold builds to the full combat rate in ~0.4 s.
        ; q is in EIGHTHS of a unit; pfrac/hfrac carry the remainders.
        mov  ax,[qramp]
        add  ax,2
        cmp  ax,16
        jle  .qr1
        mov  ax,16
.qr1:  mov  [qramp],ax
        or   cx,cx
        jns  .qr2
        neg  ax
.qr2:  mov  cx,ax              ; q, signed, in eighths
        mov  [gq],cx            ; the G meter reads the live stick
        mov  ax,[vel]           ; turning bleeds a bit of airspeed
        sub  ax,TURNDRG
        jns  .qd
        xor  ax,ax
.qd:   mov  [vel],ax
        push cx
        mov  ax,[roll]          ; cr = cos(roll)
        add  ax,64
        call SINQ
        pop  cx
        push cx
        imul cx                 ; q*cos(roll)*256 (32-bit)
        mov  bx,256
        idiv bx                 ; = q*cos in eighths/tick
        add  ax,[pfrac]
        cwd
        mov  bx,8
        idiv bx                 ; whole units carry into pitch...
        mov  [pfrac],dx         ; ...the remainder waits for the next tick
        add  [pitch],ax
        mov  ax,[roll]          ; sr = sin(roll)
        call SINQ
        pop  cx
        imul cx                 ; q*sin(roll)*256
        mov  bx,256
        idiv bx
        add  ax,[hfrac]
        cwd
        mov  bx,8
        idiv bx
        mov  [hfrac],dx
        add  ax,[heading]
        and  ax,255
        mov  [heading],ax
        jmp  .gflip            ; active stick: skip the self-trim
.nopq: mov  word [qramp],0 ; stick centred: the ramp lets go
        cmp  byte [ride],0      ; the autopilot trims for LEVEL: one unit
        je   .apl              ;  a tick toward the horizon, so the jet
        mov  ax,[pitch]         ;  left climbing does not bleed into the
        or   ax,ax              ;  stall while its pilot mans the guns
        jz   .apl
        jns  .apd
        inc  ax
        jmp  .apw
.apd:  dec  ax
.apw:  mov  [pitch],ax
.apl:
        mov  word [gq],0    ; hands off: one G on the meter
        ; no auto-trim in free air - the attitude holds.
        ; Near the ground the cushion pushes a dropped nose back level,
        ; so a gentle descent surfs the terrain instead of meeting it.
        mov  ax,[camy]
        sub  ax,[lgnd]
        cmp  ax,90
        jge  .gflip
        mov  ax,[pitch]
        test ax,ax
        jns  .gflip            ; nose level or up: nothing to push
        inc  ax
        mov  [pitch],ax
.gflip:
        ; --- gimbal flip at the vertical (the classic Euler trick): going
        ; over the top swaps to inverted flight so the loop closes smoothly
        mov  ax,[pitch]
        cmp  ax,64
        jle  .pf1
        mov  bx,128
        sub  bx,ax
        mov  [pitch],bx
        jmp  .pflip
.pf1:  cmp  ax,-64
        jge  .pok
        mov  bx,-128
        sub  bx,ax
        mov  [pitch],bx
.pflip:
        mov  ax,[heading]
        add  ax,128
        and  ax,255
        mov  [heading],ax
        mov  ax,[roll]
        add  ax,128
        and  ax,255
        mov  [roll],ax
.pok:

        ; --- energy: climbing costs airspeed, diving buys it back ---
        mov  ax,[psin]          ; sin(pitch)*256
        mov  bx,24
        imul bx                 ; DX:AX = psin*24
        mov  bx,256
        idiv bx                 ; -24..24 per tick
        mov  bx,[vel]
        sub  bx,ax
        jns  .ve
        xor  bx,bx
.ve:   ; --- AND THE AIRFRAME LIMIT, which this jet has never had. Every
        ; multiply and divide in this program was written when vel could not
        ; pass about 1500 - that was the old burner's terminal - and the
        ; burner is now four times dry thrust. At altitude the air is thin
        ; enough that drag collapses (rho floors at 64) and the level
        ; terminal works out near 7200, which is not a fast aeroplane, it is
        ; Mach 6 and it is nonsense. VNE puts the top back where an airframe
        ; has one; it is still three and a half times CRUISE, so nothing the
        ; pilot enjoys is taken away. The trainer has always clamped its own
        ; vel for exactly this reason. This is the LAST write to vel in the
        ; tick, so one clamp here bounds every reader downstream. ---
        cmp  bx,VNE
        jle  .ve1
        mov  bx,VNE
.ve1:  mov  [vel],bx
        ; --- stall: below the stall speed AS FLOWN (flaps lower it) the
        ; nose falls through on its own ---
        mov  ax,[vel]
        cmp  ax,[vstl]
        jge  .nst
        mov  ax,[pitch]
        cmp  ax,-48
        jle  .nst
        dec  ax
        mov  [pitch],ax
.nst:
        ; --- altitude clamp [24, CEIL] ---
        mov  ax,[camy]
        cmp  ax,24
        jge  .y1
        mov  ax,24
.y1:   cmp  ax,CEIL
        jle  .y2
        mov  ax,CEIL
.y2:   mov  [camy],ax

        ; --- V key: sound mode - all / effects only / silence (edge) ---
        cmp  byte [KHIT+SC_V],0   ; the LATCH, not the live key: a tap between
        je   .nv                 ;  two frames must not vanish (see KHIT)
        mov  byte [KHIT+SC_V],0   ; consumed
        call SNDTOG
.nv:
        ; --- Enter: lock the plane inside the aiming ring (edge). The
        ; nearest jet whose screen point is within 24 px of the ring
        ; centre (160,100) wins; nothing there = lock dropped.
        cmp  byte [KHIT+SC_ENT],0   ; the LATCH, not the live key: a tap between
        je   .nlk                 ;  two frames must not vanish (see KHIT)
        mov  byte [KHIT+SC_ENT],0   ; consumed
        mov  word [locki],0FFFFh
        mov  word [lockd],7FFFh
        ; The master mode used to gate this scan - A-A saw only aircraft,
        ; A-G only the ground - and that was wrong, for a reason worth
        ; writing down: LOOKING IS THE PILOT'S OWN CAPABILITY. He points the
        ; aeroplane at a thing and the ring locks it, always. What the boxes
        ; on the panel decide is whether ANYONE ELSE hears about it and acts
        ; on it - that is what a radio is - and whether he is recognised.
        ; A switch may take away other people's help. It may not take away
        ; his own eyes.
        xor  si,si
.lks:  mov  bx,si              ; cannot lock a dead jet
        shr  bx,1
        cmp  byte [pst+bx],0
        jne  .lkn
        mov  ax,[pax+si]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[paz+si]
        sub  ax,[camz]
        mov  [wdz],ax
        push si
        call ROTXZ
        pop  si
        mov  ax,[rc_z]
        cmp  ax,NEARZ
        jl   .lkn
        mov  [tpi],ax           ; keep the range for the best-pick test
        mov  dx,[pay+si]
        sub  dx,[camy]
        mov  ax,[rc_x]
        mov  cx,[rc_z]
        push si
        call PPOINT             ; last frame's view state: close enough
        pop  si
        jc   .lkn
        sub  ax,160
        jns  .lk1
        neg  ax
.lk1:  cmp  ax,24
        jg   .lkn
        sub  dx,[horiz]         ; the RING moved to the glass centre when
        jns  .lk2              ; the panel grew; this test did not, so the
                                ; game was still looking for targets around
                                ; row 100 - a hoop forty rows below the one
                                ; the pilot was aiming through
        neg  dx
.lk2:  cmp  dx,24
        jg   .lkn
        mov  ax,[tpi]
        cmp  ax,[lockd]
        jae  .lkn
        mov  [lockd],ax
        mov  [locki],si
.lkn:  add  si,2
        cmp  si,NPLANE*2
        jb   .lks
        call UISEG:RSLOCKF   ; the ground radars are targets too, and
        call UISEG:SHKLOCKF   ; so are the guns - all three legs play by
                                ; the same nearest-wins rule, so pointing
                                ; at a thing is how you pick it
.nlk:
        ; --- the wind moved OUT to WINDDRF in UISEG (see there for why it
        ; had to stop being a constant, and why it costs this segment
        ; nothing to have got better) ---

        ; --- sway: the whole VIEW floats on a slow sine (screen-space,
        ; so it is per-pixel smooth - pitch steps are 5 px and jerk).
        ; Every full cycle rolls a new amplitude (3..6 px, more over
        ; mountains/water) and a new period (~7..13 s). The cockpit
        ; stays put; the world breathes behind the glass.
        ;
        ; A JET ON ITS WHEELS DOES NOT BREATHE. This is the airframe riding
        ; moving air, and a machine standing on concrete is not riding
        ; anything - so the horizon has to be nailed down or the whole scene
        ; rocks while the aeroplane is plainly parked, which reads as the
        ; picture being broken rather than as weather. It could never show
        ; before, because before this the jet was never stationary.
        cmp  byte [onrwy],0
        je   .swgo
        mov  word [swayy],0
        mov  word [swayx],0
        jmp  .swjolt
.swgo: mov  ax,[swph]
        add  ax,[swspd]
        mov  [swph],ax
        jnc  .sw1              ; carry = full circle: re-roll the dice
        call RND16
        and  ax,3
        add  ax,3               ; amplitude 3..6 px
        mov  bx,[lgnd]
        cmp  bx,700
        jl   .swm
        add  ax,3               ; mountain waves run higher
        jmp  .swa
.swm:  cmp  bx,440
        jge  .swa
        inc  ax                 ; a little extra over open water
.swa:  mov  [swamp],ax
        call RND16
        and  ax,255
        add  ax,278             ; phase step 278..533 = ~13..7 s cycle
        mov  [swspd],ax
.sw1:  mov  ax,[swph]
        mov  cl,8
        shr  ax,cl              ; angle 0..255
        push ax
        call SINQ               ; sin*256
        imul word [swamp]
        mov  cx,256
        idiv cx
        mov  [swayy],ax         ; vertical float -amp..+amp
        pop  ax
        add  ax,64              ; X leads by a quarter turn (lazy circle)
        call SINQ
        imul word [swamp]
        mov  cx,512
        idiv cx                 ; half amplitude sideways
        mov  [swayx],ax
.swjolt:
        ; ---- AND THE KICK OF BEING HIT, on top of whatever the air was
        ; doing - and on the ground too, which is why it sits below the
        ; branch and not inside it. It rides swayx/swayy because those are
        ; already added to every projected vertex in PROJPT: the WORLD jumps
        ; and the cockpit does not, which is exactly what a hit looks like
        ; from inside one. Scaled by phit, so it is a jolt that settles
        ; rather than a wobble that runs for half a second.
        cmp  word [phit],0
        je   .tb3
        mov  ax,[lasttk]
        and  ax,3
        sub  ax,2               ; -2..+1, a new number every tick
        imul word [phit]
        mov  cl,2
        sar  ax,cl
        add  [swayy],ax
        mov  ax,[lasttk]
        inc  ax                 ; the other axis, a tick out of step with it
        and  ax,3
        sub  ax,2
        imul word [phit]
        mov  cl,2
        sar  ax,cl
        add  [swayx],ax
.tb3:
        ; --- advance: split vel/16 into horizontal (cos p) and climb (sin p)
        mov  ax,[vel]
        mov  cl,5
        shr  ax,cl              ; total speed: the world is x4, the speed
                                ; only x2 down - a jet still moves like one
        push ax
        imul word [psin]    ; climb component
        mov  bx,256
        idiv bx
        mov  [vvy],ax           ; the HUD's IVV caret reads this
        add  [camy],ax
        pop  ax
        imul word [pcos]    ; horizontal component
        mov  bx,256
        idiv bx
        mov  [fwd],ax
        mov  ax,[hsin]
        imul word [fwd]     ; DX:AX = hsin * fwd
        mov  bx,256
        idiv bx                 ; AX = fwd * sin(heading)
        add  [camx],ax
        mov  ax,[hcos]
        imul word [fwd]
        mov  bx,256
        idiv bx
        add  [camz],ax
        ; --- and THE GROUND SCHOOL, which is the whole of the flight model
        ; below the wheels: brakes, rolling resistance, nose-wheel steering,
        ; rotation at VR and the grass beside the concrete. It runs HERE, at
        ; the end of the advance, on purpose - the airborne code above has
        ; already had its say and this overrides whichever parts of it a jet
        ; standing on three legs is entitled to argue with. It also keeps the
        ; sink rate in 8.8 every tick, airborne or not, because the one tick
        ; anybody reads it is the tick she arrives. See GNDSCH in UI.INC.
        call UISEG:GNDSCHF
        ; --- Backspace: fire a missile (edge; sits right above Enter =
        ; lock). Homing on the lock, straight down the nose otherwise.
        cmp  byte [KHIT+SC_BS],0   ; the LATCH, not the live key: a tap between
        je   .nfr                 ;  two frames must not vanish (see KHIT)
        mov  byte [KHIT+SC_BS],0   ; consumed
        ; ---- A FREE RAIL, not "the missile is not in flight". The gate used
        ; to be one airborne missile at a time, so a second launch was
        ; impossible for up to fifteen seconds - which is precisely the
        ; moment in a fight when you want it. Four rails, four in the air if
        ; you like; what stops you is pammo, and pammo does not come back. ----
        call SYMSEG:MSLFREEF   ; a rail with nothing on it
        jc   .nfr
        cmp  byte [pammo],0
        je   .nfr
        dec  byte [pammo]
        mov  byte [msact],1
        mov  ax,[locki]
        mov  [mstgt],ax
        mov  word [mlife],280
        call SFXHISS            ; off the rail with a sharp hiss
        cmp  byte [mslcam],0
        je   .nomc
        mov  byte [mcact],1 ; armed: the camera rides this one, and it
        mov  ax,[msi]           ;  has to remember WHICH one
        mov  [mcsl],ax
        mov  ax,[heading]
        mov  [mch],ax
.nomc:
        mov  ax,[hsin]          ; spawn 25 ahead, 5 below the sightline
        mov  bx,25
        imul bx
        mov  bx,256
        idiv bx
        add  ax,[camx]
        mov  [msx],ax
        mov  [mpx],ax
        mov  ax,[hcos]
        mov  bx,25
        imul bx
        mov  bx,256
        idiv bx
        add  ax,[camz]
        mov  [msz],ax
        mov  [mpz],ax
        mov  ax,[camy]
        sub  ax,5
        mov  [msy],ax
        mov  [mpy],ax
        ; straight-flight velocity: 32/tick along heading and pitch
        mov  ax,[pcos]
        mov  bx,32
        imul bx
        mov  bx,256
        idiv bx
        mov  bx,ax              ; horizontal component
        mov  ax,[hsin]
        imul bx
        push bx
        mov  bx,256
        idiv bx
        pop  bx
        mov  [mvx],ax
        mov  ax,[hcos]
        imul bx
        mov  bx,256
        idiv bx
        mov  [mvz],ax
        mov  ax,[psin]
        mov  bx,32
        imul bx
        mov  bx,256
        idiv bx
        mov  [mvy],ax
        call SYMSEG:MSLSAVEF   ; ...and onto the rail it goes
.nfr:
        ; --- THE RAILS DO NOT REFILL THEMSELVES. There used to be a reload
        ; here, one missile back every ~20 s, and between it and the
        ; one-in-flight gate the weapon read as broken: fire, wait out the
        ; missile's flight, find four on the rails again, fire one more,
        ; forever. Four is what the aeroplane carries. Spend them and you
        ; are out - which is what makes a sortie a decision, and what gives
        ; landing at your own field something to be FOR.
        ; --- Space: the cannon. Hold to fire; a volley lands every
        ; 2nd tick on whatever sits inside the aiming circle. Each jet
        ; soaks 2..5 hits (its HP roll) before it comes apart.
        cmp  byte [guntik],0
        je   .gt0
        dec  byte [guntik]
.gt0:  cmp  word [hitft],0
        je   .gt0a
        dec  word [hitft]
.gt0a: ; ---- THE HIT, heard. phit rising is the only thing all three damage
        ; sites have in common, so the sound hangs off the EDGE of it rather
        ; than off three new call sites. The explosion recording at a quarter
        ; of its swing: a thump on your own airframe, not a blast out in the
        ; world - and it is the same sample, so it costs the bank nothing.
        mov  ax,[phit]
        cmp  ax,[phitp]
        jbe  .gt0b
        push ax
        mov  ax,SFX_BOOM+(2*256)
        call SFXPLAY
        pop  ax
.gt0b: mov  [phitp],ax
        cmp  word [phit],0
        je   .gt1
        dec  word [phit]
.gt1:  cmp  byte [ride],0      ; riding: Space is the SHILKA's trigger -
        jne  .gnr              ;  the jet's cannon stays cold
        mov  al,[KEYS+SC_SP]    ; the trigger - a rescued tap is one shell
        or   al,[tapsp]
        je   .gnr
        cmp  word [gunam],0
        je   .gnf
        mov  byte [guntik],2
        ; ---- launch one tracer round (ring of NTRC, oldest reused) ----
        mov  bx,[trnext]
        inc  word [trnext]
        and  word [trnext],NTRC-1
        mov  di,bx
        add  di,di              ; word offset
        mov  byte [trcact+bx],1
        mov  word [trlif+di],60
        mov  ax,[hcos]          ; muzzle: wing-root offset, gun alternates
        mov  cx,10
        imul cx
        mov  cx,256
        idiv cx
        test bx,1
        jz   .gmr
        neg  ax                 ; left gun this time
.gmr:  add  ax,[camx]
        mov  [tcx+di],ax
        mov  ax,[hsin]
        mov  cx,10
        imul cx
        mov  cx,256
        idiv cx
        neg  ax
        test bx,1
        jz   .gmz
        neg  ax
.gmz:  add  ax,[camz]
        mov  [tcz+di],ax
        mov  ax,[camy]
        sub  ax,3
        mov  [tcy+di],ax
        mov  ax,[pcos]          ; 75/tick along the nose
        mov  cx,75
        imul cx
        mov  cx,256
        idiv cx
        mov  [dsac],ax          ; horizontal component
        mov  ax,[hsin]
        imul word [dsac]
        mov  cx,256
        idiv cx
        mov  [trvx+di],ax
        mov  ax,[hcos]
        imul word [dsac]
        mov  cx,256
        idiv cx
        mov  [trvz+di],ax
        mov  ax,[psin]
        mov  cx,75
        imul cx
        mov  cx,256
        idiv cx
        mov  [trvy+di],ax
        push di                 ; a pinch of spread on every axis
        call RND16
        pop  di
        mov  bx,ax
        and  ax,7
        sub  ax,3
        add  [trvx+di],ax
        mov  ax,bx
        mov  cl,3
        shr  ax,cl
        and  ax,7
        sub  ax,3
        add  [trvy+di],ax
        mov  ax,bx
        mov  cl,6
        shr  ax,cl
        and  ax,7
        sub  ax,3
        add  [trvz+di],ax
        mov  ax,[lasttk]
        test ax,1
        jnz  .gnf              ; volleys on even ticks
        dec  word [gunam]
        call SFXPOP             ; the deep clap of the cannon
        xor  si,si              ; who is in the ring?
.gsc:  mov  bx,si
        shr  bx,1
        cmp  byte [pst+bx],0
        jne  .gsn
        mov  ax,[pax+si]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[paz+si]
        sub  ax,[camz]
        mov  [wdz],ax
        push si
        call ROTXZ
        pop  si
        mov  ax,[rc_z]
        cmp  ax,NEARZ
        jl   .gsn
        cmp  ax,4500            ; cannon reach
        jg   .gsn
        mov  dx,[pay+si]
        sub  dx,[camy]
        mov  ax,[rc_x]
        mov  cx,[rc_z]
        push si
        call PPOINT
        pop  si
        jc   .gsn
        sub  ax,160
        jns  .gh1
        neg  ax
.gh1:  cmp  ax,18
        jg   .gsn
        sub  dx,100
        jns  .gh2
        neg  dx
.gh2:  cmp  dx,18
        jg   .gsn
        mov  [hitfx],si         ; hit! sparkle on the victim
        mov  word [hitft],5
        mov  bx,si
        shr  bx,1
        cmp  byte [premote+bx],0
        je   .gai              ; an AI jet: settle it here as always
        push si                 ; a real pilot: the wire carries the round,
        mov  al,bl              ; HIS machine counts his wounds
        mov  ah,1               ; cannon: one hit of the five
        call SKYSEG:NETHITF
        pop  si
        jmp  .gnf
.gai:  dec  byte [php+bx]
        jnz  .gnf              ; wounded, still flying
        push si
        call BOOM
        pop  si
        inc  word [psc]
        jmp  .gnf
.gsn:  add  si,2
        cmp  si,NPLANE*2
        jb   .gsc
        jmp  .gnf
.gnr:  ; the belt does not grow back either, for the same reason. Two
        ; hundred and fifty rounds is what the drum holds; letting go of
        ; the trigger used to feed one back in every eight ticks, so the
        ; gun could never actually run dry and the count on the panel was
        ; decoration.
.gnf:
        call SNDBEEP            ; the caution lamps sing
        ; --- manoeuvre loading for the engine sound: how hard is the
        ; airframe working the air? Attitude deltas, plus stall buffet;
        ; rises instantly, decays over ~a second.
        mov  ax,[pitch]
        sub  ax,[mprvp]
        jns  .md1
        neg  ax
.md1:  mov  bx,ax              ; |dpitch|
        mov  ax,[roll]
        sub  ax,[mprvr]
        and  ax,255
        cmp  ax,128
        jb   .md2
        neg  ax
        add  ax,256             ; |droll| the short way round
.md2:  add  bx,ax
        add  bx,bx              ; scale the kick
        mov  ax,[vel]
        cmp  ax,[vstl]
        jge  .md3
        add  bx,4               ; stall buffet shakes the engine note
.md3:  mov  ax,[mlvl]          ; decay 1/16 per tick, add the kick
        mov  dx,ax
        mov  cl,4
        shr  dx,cl
        sub  ax,dx
        add  ax,bx
        cmp  ax,48
        jle  .md4
        mov  ax,48
.md4:  mov  [mlvl],ax
        mov  ax,[pitch]
        mov  [mprvp],ax
        mov  ax,[roll]
        mov  [mprvr],ax
        ; --- the black box: record every 2nd tick for the flashback ---
        mov  ax,[lasttk]
        test ax,1
        jnz  .fbskip
        mov  bx,[flbh]
        mov  ax,[camx]
        mov  [FLB+bx],ax
        mov  ax,[camy]
        mov  [FLB+bx+2],ax
        mov  ax,[camz]
        mov  [FLB+bx+4],ax
        mov  ax,[heading]
        mov  [FLB+bx+6],ax
        mov  ax,[pitch]
        mov  [FLB+bx+8],ax
        mov  ax,[roll]
        mov  [FLB+bx+10],ax
        add  bx,12
        cmp  bx,FLBSZ
        jb   .fbw
        xor  bx,bx
.fbw:  mov  [flbh],bx
.fbskip:
        call PLANESUPD          ; AI traffic flies on the same clock
        call MSLUPD             ; the missile chases on the same clock
        call TRCUPD             ; tracer rounds fly on the same clock
        call AMSLUPD            ; the AI shoots its own war
        call AIGUN              ; ...and strafes at knife range
        call WRECKUPD           ; debris falls on the same clock
        ret

; ============================================================================
;  COLLISION
; ============================================================================
COLLIDE:
        cmp  byte [dying],0
        je   .live3
        ret                     ; the wreck cannot crash twice
.live3:
        mov  ax,[camx]          ; camera cell
        add  ax,BIAS
        mov  cl,8
        shr  ax,cl
        mov  [gi],ax
        mov  ax,[camz]
        add  ax,BIAS
        mov  cl,8
        shr  ax,cl
        mov  [gj],ax
        ; --- terrain collision first: bilinear ground height under camera ---
        call TERRH              ; AX = ground height at (camx,camz)
        mov  [lgnd],ax          ; remembered for the TERR caution light
        ; --- ground effect: within 250 units of the surface the wing rides
        ; its own compressed air, pushing up harder the lower you get.
        ; Needs airflow (vel >= 150), so a stalled drop still hits dirt.
        ; ...unless the GEAR IS DOWN, and this is the whole reason a landing
        ; was impossible. The cushion is up to seven units a tick and the
        ; approach settles at three: over a runway the aeroplane was being
        ; pushed up harder than it was coming down, so it hung there, and
        ; the only way through the cushion was to dive - which arrives too
        ; fast to be a landing and is why it broke every time. A pilot with
        ; his legs out has said what he intends.
        cmp  byte [gear],0
        jne  .gfx
        mov  bx,[camy]
        sub  bx,ax              ; height above ground
        cmp  bx,62
        jge  .gfx
        cmp  word [vel],150
        jl   .gfx
        mov  ax,62
        sub  ax,bx              ; cushion grows as the gap shrinks
        mov  cl,3
        shr  ax,cl              ; strong: up to ~7 units of lift per tick
        add  [camy],ax
.gfx:  mov  ax,[lgnd]
        add  ax,14              ; hull clearance above the slope
        cmp  [camy],ax
        jge  .terok
        call UISEG:LANDF   ; an arrival, or an accident?
        jc   .terok
        call CRASHHANDLE        ; flew into the hillside
        ret
.terok:
        call HBLD
        mov  ax,[bstreet]
        cmp  ax,0
        jne  .nocol            ; street / patch -> free air
        call BCHK
        jnz  .nocol            ; a ruin: fly through the smoke
        ; --- building: inside footprint AND below rooftop (base+height)? ---
        mov  ax,[gi]
        mov  cl,8
        shl  ax,cl
        add  ax,128
        sub  ax,BIAS
        mov  [wcx],ax
        mov  ax,[gj]
        mov  cl,8
        shl  ax,cl
        add  ax,128
        sub  ax,BIAS
        mov  [wcz],ax
        mov  ax,[camx]
        sub  ax,[wcx]
        cmp  ax,0
        jge  .a1
        neg  ax
.a1:   cmp  ax,[bhw]
        jge  .nocol
        mov  ax,[camz]
        sub  ax,[wcz]
        cmp  ax,0
        jge  .a2
        neg  ax
.a2:   cmp  ax,[bhd]
        jge  .nocol
        mov  ax,[gi]            ; rooftop = terrain base + building height
        mov  bx,[gj]
        call GETH
        call WORLDH
        add  ax,[bhgt2]
        cmp  [camy],ax
        jge  .nocol            ; above roof -> safe
        call BSET               ; the building comes down with us
        call BWRECK
        call CRASHHANDLE
.nocol:
        ret

CRASHHANDLE:
        ; cinematic death: our jet becomes a wreck (same breakup as the
        ; AI), the camera freezes on the chase spot and watches it fall.
        ; INPUT switches to the spectator branch until PLAYERRESET.
        cmp  byte [dying],0
        jne  .cr               ; already falling
        mov  byte [dying],1
        mov  word [dytick],0
        inc  word [tsch]    ; the player is a green too: his loss
        mov  ax,[flbh]          ; the flashback starts at the oldest tick
        mov  [flbc],ax
        mov  word [flbcnt],FLBN
        call PBOOM
        call SFXDETH            ; OUR bang, and its OWN recording - the only
                                ;  sound in the game that is about you rather
                                ;  than about something in the world
        mov  ax,[hsin]          ; freeze the camera behind the wreck
        mov  bx,100
        imul bx
        mov  bx,256
        idiv bx
        mov  bx,[camx]
        sub  bx,ax
        mov  [dcx],bx
        mov  ax,[hcos]
        mov  bx,100
        imul bx
        mov  bx,256
        idiv bx
        mov  bx,[camz]
        sub  bx,ax
        mov  [dcz],bx
        mov  ax,[camy]
        add  ax,15
        mov  [dcy],ax
.cr:   ret

; PLAYERRESET lived here until 2026-08-06. It is now PLAYERRESETF in
; UI.INC (UISEG) - see the note at its head. It ran once per death and
; cost this segment about 150 bytes, which is what the ground school is
; standing on.

; ---------------------------------------------------------------------------
;  UIKEYS - the GLASS: cameras, zooms, pages, the palette. Moved out of
;  INPUT (2026-08-20) and called once per FRAME from GAMELOOP, because
;  pause froze physics and took every view key down with it. The pilot's
;  ruling: on pause the world stands still but the glass stays alive -
;  views, radar zoom, map zoom and the MFD keep answering. These are all
;  edge-triggered latches (or camera dollies that WANT frame rate), so
;  per-frame instead of per-tick changes nothing in ordinary flight.
;  What stays in INPUT is what CHANGES THE WORLD: lock, missile, cannon,
;  throttle, the switches - and V, because sound is muted on pause anyway.
; ---------------------------------------------------------------------------
UIKEYS:
        cmp  byte [spect],0    ; WATCHING or falling: these keys were
        jne  .off              ;  never alive outside the pilot's seat.
        cmp  byte [dying],0    ;  The spectator camera OWNS tgtcam, and
        je   .on               ;  the F4 machine below fought it for the
.off:  ret                     ;  glass, one flip a frame - the violent
.on:                           ;  PRESS-ENTER shake of v7 (2026-08-21)
        ; --- N key: toggle day/night palette (on key-down edge only) ---
        cmp  byte [KHIT+SC_N],0   ; the LATCH, not the live key: a tap between
        je   .nn                 ;  two frames must not vanish (see KHIT)
        mov  byte [KHIT+SC_N],0   ; consumed
        xor  byte [daymode],1
        call UISEG:APPLYPALF
.nn:
        ; --- F2: cockpit panel on/off (edge-triggered; C is rudder now) ---
        cmp  byte [KHIT+SC_F2],0   ; the LATCH, not the live key: a tap between
        je   .ncp                 ;  two frames must not vanish (see KHIT)
        mov  byte [KHIT+SC_F2],0   ; consumed
        cmp  byte [ride],0         ; the turret seat: the jet's panel is
        jne  .ncp                  ;  the JET's - F2 must not reach it
        xor  byte [cockpit],1
.ncp:
        ; --- F3: chase camera (edge) ---
        cmp  byte [KHIT+SC_F3],0   ; the LATCH, not the live key: a tap between
        je   .nf3                 ;  two frames must not vanish (see KHIT)
        mov  byte [KHIT+SC_F3],0   ; consumed
        cmp  byte [ride],0
        je   .f3jet
        inc  byte [rdext]          ; the seat's views CYCLE: cabin ->
        cmp  byte [rdext],3        ;  FOLLOW (tied to the stern, comes
        jb   .f3v                  ;  round with the hull) -> ORBIT
        mov  byte [rdext],0        ;  (Q/E walk around her) -> cabin.
.f3v:  cmp  byte [rdext],1        ;  The hands never leave the controls.
        jne  .nf3
        call UISEG:SHKCAM0F  ; stepping out: park behind the hull
        jmp  .nf3
.f3jet:
        xor  byte [chsview],1
.nf3:
        ; --- Z / X: the scope zooms in and out, the manual's way - EXCEPT
        ; while the orbit camera is up, when they walk the camera in and
        ; out instead. Same two fingers, and the scope is not on the glass
        ; in that view anyway, so nothing is taken away. Held, not tapped:
        ; a camera dolly wants a continuous pull, not an edge.
        cmp  byte [tgtcam],0
        je   .nzk
        cmp  byte [KEYS+SC_Z],0
        je   .nzk1
        mov  ax,[tgrad]         ; in, by a twelfth a tick: smooth at any
        mov  bx,ax              ; distance, and it never crawls when far
        mov  cl,4
        shr  bx,cl
        inc  bx
        sub  ax,bx
        cmp  ax,TGRMIN
        jge  .nzk2
        mov  ax,TGRMIN
.nzk2: mov  [tgrad],ax
.nzk1: cmp  byte [KEYS+SC_X],0
        je   .nzo
        mov  ax,[tgrad]         ; ...and out
        mov  bx,ax
        mov  cl,4
        shr  bx,cl
        inc  bx
        add  ax,bx
        cmp  ax,TGRMAX
        jle  .nzk3
        mov  ax,TGRMAX
.nzk3: mov  [tgrad],ax
        jmp  .nzo
.nzk:  cmp  byte [ride],0      ; riding: Z and X are the walk-around
        je   .nzk0             ;  DOLLY - the jet's radar zoom must not
        mov  byte [KHIT+SC_Z],0    ;  swallow (or answer) the taps
        mov  byte [KHIT+SC_X],0
        jmp  .nzo
.nzk0:        cmp  byte [KHIT+SC_Z],0   ; the LATCH, not the live key: a tap between
        je   .nzi                 ;  two frames must not vanish (see KHIT)
        mov  byte [KHIT+SC_Z],0   ; consumed
        cmp  byte [rzsh],6
        jbe  .nzi
        dec  byte [rzsh]
.nzi:        cmp  byte [KHIT+SC_X],0   ; the LATCH, not the live key: a tap between
        je   .nzo                 ;  two frames must not vanish (see KHIT)
        mov  byte [KHIT+SC_X],0   ; consumed
        cmp  byte [rzsh],10
        jae  .nzo
        inc  byte [rzsh]
.nzo:
        ; --- K: the MAP zooms, 1 / 2 / 4 pixels to a world node, cycling.
        ; PROVISIONAL KEY - the whole keyboard is still to be laid out; K is
        ; simply free and next to M, which pages this same screen. ---
        cmp  byte [KHIT+SC_K],0   ; the LATCH, not the live key: a tap between
        je   .nmz                 ;  two frames must not vanish (see KHIT)
        mov  byte [KHIT+SC_K],0   ; consumed
        mov  al,[mmzs]
        inc  al
        cmp  al,MMZN
        jb   .mzs
        xor  al,al
.mzs:  mov  [mmzs],al
.nmz:
        ; --- F5: arm/disarm the missile camera (edge) ---
        cmp  byte [KHIT+SC_F5],0   ; the LATCH, not the live key: a tap between
        je   .nf5                 ;  two frames must not vanish (see KHIT)
        mov  byte [KHIT+SC_F5],0   ; consumed
        cmp  byte [ride],0         ; the missile rail is the jet's too
        jne  .nf5
        xor  byte [mslcam],1
.nf5:
        ; --- F4: orbit camera around the locked target (edge) ---
        cmp  byte [KHIT+SC_F4],0   ; the LATCH, not the live key: a tap between
        je   .nf4                 ;  two frames must not vanish (see KHIT)
        mov  byte [KHIT+SC_F4],0   ; consumed
        cmp  byte [ride],0         ; and the orbit rig orbits the jet's
        jne  .nf4                  ;  locks - not the turret's, not yet
        cmp  byte [tgtcam],0
        jne  .f4off
        mov  si,[locki]
        cmp  si,0FFFFh
        je   .nf4              ; nothing locked: nothing to orbit
        mov  [tgti],si          ; remember the star of the show
        ; How far to stand off depends on WHAT is being orbited, and the
        ; old flat 100 was a jet's number. A Shilka is 100 units long by
        ; itself and a radar mast is 190 tall, so the camera was born
        ; INSIDE them - that was "the camera appears somewhere odd". One
        ; threshold buys both, and Z/X trims from there. Written this
        ; tight (BX, one compare) because the main segment had 21 bytes
        ; of stack-guard headroom left and the readable ladder cost 28.
        xor  ax,ax              ; ground targets have no heading to sit behind
        mov  bx,100             ; a jet is small: four wingspans out
        cmp  si,SHKLK
        jb   .f4pl
        mov  bx,450             ; a Shilka or a mast: clear of the thing
        jmp  .f4rd
.f4pl: mov  ax,[pah+si]
.f4rd: mov  [tgrad],bx
.f4az: mov  [tgaz],ax          ; start right behind the target
        mov  word [tgel],12
        mov  byte [tgtcam],1
        jmp  .nf4
.f4off:
        mov  byte [tgtcam],0
.nf4:  cmp  byte [tgtcam],1
        jne  .wchk
        cmp  word [locki],0FFFFh
        jne  .lkok             ; lock alive: keep orbiting the jet
        mov  byte [tgtcam],2 ; target died: stay with the debris -
        mov  ax,[wnext]         ; the freshest wreck slot is the show
        sub  ax,WRKSZ
        jns  .wok
        add  ax,WRKSZ*4
.wok:  add  ax,WRK
        mov  [tcws],ax
        jmp  .lkok
.wchk: cmp  byte [tgtcam],2
        jne  .lkok
        cmp  word [locki],0FFFFh
        je   .lkok             ; still at the funeral
        mov  byte [tgtcam],1 ; a new lock: swing to the new target
        mov  ax,[locki]
        mov  [tgti],ax
.lkok:
        ; --- F4 active: the arrows steer the camera, not the jet ---
        cmp  byte [tgtcam],0
        je   .ntc
        cmp  byte [KEYS+SC_LF],0
        je   .tc1
        sub  word [tgaz],2
        and  word [tgaz],255
.tc1:  cmp  byte [KEYS+SC_RT],0
        je   .tc2
        add  word [tgaz],2
        and  word [tgaz],255
.tc2:  cmp  byte [KEYS+SC_UP],0
        je   .tc3
        mov  ax,[tgel]
        inc  ax
        cmp  ax,56
        jle  .tcu
        mov  ax,56
.tcu:  mov  [tgel],ax
.tc3:  cmp  byte [KEYS+SC_DN],0
        je   .ntc
        mov  ax,[tgel]
        dec  ax
        cmp  ax,-30
        jge  .tcd
        mov  ax,-30
.tcd:  mov  [tgel],ax
.ntc:
        ; --- M key: centre MFD page, MAP -> SIT -> TGT (edge) ---
        cmp  byte [KHIT+SC_M],0   ; the LATCH, not the live key: a tap between
        je   .nmfd                 ;  two frames must not vanish (see KHIT)
        mov  byte [KHIT+SC_M],0   ; consumed
        mov  al,[mfdmode]
        inc  al
        cmp  al,3
        jb   .mfs
        xor  al,al
.mfs:  mov  [mfdmode],al
.nmfd:
        ret

; ---------------------------------------------------------------------------
;  TapClr - the rescued taps are spent. GAMELOOP grants them before a
;  burst; the burst's FIRST step reads them (the OR sites above), then
;  this runs after every step, so steps two to six of a catch-up burst
;  fly clean. One tick per tap - never nought, never six.
; ---------------------------------------------------------------------------
TapClr: xor  al,al
        mov  [tapup],al
        mov  [tapdn],al
        mov  [taplf],al
        mov  [taprt],al
        mov  [tapw],al
        mov  [tapsd],al
        mov  [tapsp],al
        ret

; ---------------------------------------------------------------------------
;  RIDEHANDS - the pilot's hands, handed to the Shilka once a physics tick.
;  Two axes, two hands: the ARROWS drive the tracks (left/right steer the
;  hull, up/down work the pedal), W A S D lays the gun (A/D traverse the
;  drum, W/S raise and drop the barrels) - and Space is the trigger. The
;  rescued taps ride along: at real-iron frame rates a tap between two
;  frames must still steer (the 486 report; same OR sites as the jet's).
; ---------------------------------------------------------------------------
RIDEHANDS:
        xor  ax,ax              ; AL hull turn, AH pedal
        mov  cl,[KEYS+SC_LF]
        or   cl,[taplf]
        jz   .h1
        dec  al
.h1:   mov  cl,[KEYS+SC_RT]
        or   cl,[taprt]
        jz   .h2
        inc  al
.h2:   mov  cl,[KEYS+SC_UP]
        or   cl,[tapup]
        jz   .h3
        inc  ah
.h3:   mov  cl,[KEYS+SC_DN]
        or   cl,[tapdn]
        jz   .h4
        dec  ah
.h4:   xor  dx,dx              ; DL traverse, DH barrels
        cmp  byte [KEYS+SC_A],0
        je   .h5
        dec  dl
.h5:   cmp  byte [KEYS+SC_D],0
        je   .h6
        inc  dl
.h6:   mov  cl,[KEYS+SC_W]
        or   cl,[tapw]
        jz   .h7
        inc  dh
.h7:   mov  cl,[KEYS+SC_S]
        or   cl,[tapsd]
        jz   .h8
        dec  dh
.h8:   xor  cx,cx
        mov  cl,[KEYS+SC_SP]
        or   cl,[tapsp]
        jz   .h9
        mov  cl,1
.h9:   call UISEG:SHKHANDF
        ; ---- the walk-around camera's own hands: Q/E swing the orbit,
        ; Z/X dolly it. Held, not tapped - a camera wants a pull.
        cmp  byte [rdext],0
        je   .hx
        cmp  byte [rdext],2     ; Q/E belong to the free orbit alone -
        jne  .e2               ;  the follow view steers itself
        cmp  byte [KEYS+SC_Q],0
        je   .e1
        sub  word [tgaz],2
        and  word [tgaz],255
.e1:   cmp  byte [KEYS+SC_E],0
        je   .e2
        add  word [tgaz],2
        and  word [tgaz],255
.e2:   cmp  byte [KEYS+SC_Z],0
        je   .e3
        mov  ax,[tgrad]         ; in, a sixteenth a tick: smooth close,
        mov  bx,ax              ;  never a crawl from far out
        mov  cl,4
        shr  bx,cl
        inc  bx
        sub  ax,bx
        cmp  ax,90
        jge  .e3a
        mov  ax,90              ; no closer: the hull is 100 long
.e3a:  mov  [tgrad],ax
.e3:   cmp  byte [KEYS+SC_X],0
        je   .hx
        mov  ax,[tgrad]
        mov  bx,ax
        mov  cl,4
        shr  bx,cl
        inc  bx
        add  ax,bx
        cmp  ax,800
        jle  .e4
        mov  ax,800
.e4:   mov  [tgrad],ax
.hx:   ret
