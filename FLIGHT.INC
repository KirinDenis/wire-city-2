; FLIGHT.INC - part of WIRE CITY (included from CITY.ASM)
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
        cmp  byte ptr [dying],0
        je   @@alive2
        ; the fall: the world keeps turning, we just watch the wreck
        inc  word ptr [dytick]
        cmp  word ptr [dytick],18
        jb   @@dwar             ; ignore Space for the first second
        cmp  byte ptr [KEYS+SC_SP],0
        je   @@dwar
        call PLAYERRESET
@@dwar: cmp  word ptr [flbcnt],0
        je   @@dwr2
        mov  ax,[lasttk]        ; the recording is half-rate: play it so
        test ax,1
        jnz  @@dwr2
        dec  word ptr [flbcnt]  ; the flashback rolls one sample forward
        mov  ax,[flbc]
        add  ax,12
        cmp  ax,FLBSZ
        jb   @@dwr1
        xor  ax,ax
@@dwr1: mov  [flbc],ax
@@dwr2: call PLANESUPD
        call MSLUPD
        call TRCUPD
        call AMSLUPD
        call AIGUN
        call WRECKUPD
        ret
@@alive2:
        ; --- air density: rho = 256 - camy/8, clamped to 64..256 ---
        mov  ax,[camy]
        mov  bx,ax
        mov  cl,3
        shr  bx,cl
        mov  ax,256
        sub  ax,bx
        cmp  ax,64
        jge  @@r1
        mov  ax,64
@@r1:   mov  [rho],ax

        ; --- throttle: W up, S down; A holds the afterburner ---
        cmp  byte ptr [KEYS+SC_W],0
        jne  @@tup
        cmp  byte ptr [KEYS+SC_NPP],0
        jne  @@tup
        cmp  byte ptr [KEYS+SC_EQ],0
        je   @@tw
@@tup:  mov  ax,[throt]
        add  ax,2
        cmp  ax,64
        jle  @@tw1
        mov  ax,64
@@tw1:  mov  [throt],ax
@@tw:   cmp  byte ptr [KEYS+SC_S],0
        jne  @@tdn
        cmp  byte ptr [KEYS+SC_NPM],0
        jne  @@tdn
        cmp  byte ptr [KEYS+SC_MIN],0
        je   @@ts
@@tdn:  mov  ax,[throt]
        sub  ax,2
        jns  @@ts1
        xor  ax,ax
@@ts1:  mov  [throt],ax
@@ts:   mov  byte ptr [abon],0
        cmp  byte ptr [KEYS+SC_A],0
        je   @@ab0
        mov  byte ptr [abon],1  ; afterburner lit (needs fuel, checked below)
@@ab0:
        ; --- engine: burn fuel; jet thrust breathes air: T*(rho+256)/512,
        ; scaled by throttle/64; afterburner doubles it and drinks 4x fuel ---
        xor  cx,cx              ; default thrust 0 (flame-out)
        mov  ax,[fuel]
        test ax,ax
        jz   @@nofu
        dec  ax
        mov  [fuel],ax
        mov  ax,[rho]
        add  ax,256
        mov  bx,ax
        mov  ax,THRUST
        imul bx                 ; DX:AX = THRUST*(rho+256)
        mov  bx,512
        idiv bx
        imul word ptr [throt]   ; * throttle
        mov  bx,64
        idiv bx                 ; /64
        mov  cx,ax
        cmp  byte ptr [abon],0
        je   @@noth
        add  cx,cx              ; afterburner: double thrust...
        mov  ax,[fuel]          ; ...and burn 3 extra units
        sub  ax,3
        jns  @@abf
        xor  ax,ax
@@abf:  mov  [fuel],ax
        jmp  @@noth
@@nofu: mov  byte ptr [abon],0  ; tanks dry: no burner glow either
@@noth: mov  [teff],cx

        ; --- drag = vel*rho/DRAGK ; net force = thrust - drag ---
        mov  ax,[vel]
        imul word ptr [rho]     ; DX:AX = vel*rho
        mov  bx,DRAGK
        idiv bx
        mov  bx,ax              ; bx = drag
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
        jns  @@v0
        xor  ax,ax              ; airspeed never negative
@@v0:   mov  [vel],ax

        ; --- ROLL: left/right arrows spin the ailerons, full 360 degrees ---
        mov  word ptr [tmpi],0
        cmp  byte ptr [tgtcam],0
        jne  @@nr               ; F4: hands off, dihedral takes over
        cmp  byte ptr [KEYS+SC_LF],0
        je   @@nl
        mov  ax,[roll]
        sub  ax,3               ; roll rate: full barrel roll in ~4.7 s
        and  ax,255
        mov  [roll],ax
        mov  word ptr [tmpi],1
@@nl:   cmp  byte ptr [KEYS+SC_RT],0
        je   @@nr
        mov  ax,[roll]
        add  ax,3
        and  ax,255
        mov  [roll],ax
        mov  word ptr [tmpi],1
@@nr:   cmp  word ptr [tmpi],0  ; hands off: dihedral stability rights the
        jne  @@rlp              ; plane, rolling the SHORT way back to level
        mov  ax,[roll]
        test ax,ax
        jz   @@rlp
        cmp  ax,128
        ja   @@rlup             ; 129..255: roll upward to 256 (= level)
        sub  ax,2               ; 1..128: roll down toward 0
        jns  @@rls1
        xor  ax,ax
@@rls1: cmp  ax,2               ; snap the last couple of units
        ja   @@rls2
        xor  ax,ax
@@rls2: mov  [roll],ax
        jmp  @@rlp
@@rlup: add  ax,2
        and  ax,255
        cmp  ax,254
        jb   @@rlu2
        xor  ax,ax
@@rlu2: mov  [roll],ax
@@rlp:
        ; --- RUDDER: Q/E yaw the nose flat, no bank. Slow like a real
        ; rudder: 1 unit/tick = a full circle in ~14 s. Good for lining
        ; up a runway or a gun run without dropping a wing.
        cmp  byte ptr [KEYS+SC_Q],0
        jne  @@rdl
        cmp  byte ptr [KEYS+SC_Z],0
        jne  @@rdl
        cmp  byte ptr [KEYS+SC_NP7],0
        je   @@rdq
@@rdl:  mov  ax,[heading]
        dec  ax
        and  ax,255
        mov  [heading],ax
@@rdq:  cmp  byte ptr [KEYS+SC_E],0
        jne  @@rdr
        cmp  byte ptr [KEYS+SC_C],0
        jne  @@rdr
        cmp  byte ptr [KEYS+SC_NP9],0
        je   @@rde
@@rdr:  mov  ax,[heading]
        inc  ax
        and  ax,255
        mov  [heading],ax
@@rde:
        ; --- PITCH: real fighter controls. Pull (DOWN key) rotates the nose
        ; through the roll plane: pitch_rate = q*cos(roll), yaw = q*sin(roll).
        ; Wings level -> loop; knife-edge -> flat turn; inverted -> split-S.
        xor  cx,cx              ; q = elevator input
        cmp  byte ptr [tgtcam],0
        jne  @@nopq             ; F4: the stick is centred
        cmp  byte ptr [KEYS+SC_DN],0
        je   @@q1
        mov  cx,2               ; pull: nose up
@@q1:   cmp  byte ptr [KEYS+SC_UP],0
        je   @@q2
        sub  cx,2               ; push: nose down
@@q2:   jcxz @@nopq
        mov  ax,[vel]           ; turning bleeds a bit of airspeed
        sub  ax,TURNDRG
        jns  @@qd
        xor  ax,ax
@@qd:   mov  [vel],ax
        push cx
        mov  ax,[roll]          ; cr = cos(roll)
        add  ax,64
        call SINQ
        pop  cx
        push cx
        imul cx                 ; q*cos(roll)*256
        mov  bx,256
        idiv bx
        add  [pitch],ax
        mov  ax,[roll]          ; sr = sin(roll)
        call SINQ
        pop  cx
        imul cx                 ; q*sin(roll)*256
        mov  bx,256
        idiv bx
        add  ax,[heading]
        and  ax,255
        mov  [heading],ax
        jmp  @@gflip            ; active stick: skip the self-trim
@@nopq: ; stick released: longitudinal stability eases the nose back level
        mov  ax,[pitch]
        test ax,ax
        jz   @@gflip
        jg   @@tr1
        inc  ax
        jmp  @@tr2
@@tr1:  dec  ax
@@tr2:  mov  [pitch],ax
@@gflip:
        ; --- gimbal flip at the vertical (the classic Euler trick): going
        ; over the top swaps to inverted flight so the loop closes smoothly
        mov  ax,[pitch]
        cmp  ax,64
        jle  @@pf1
        mov  bx,128
        sub  bx,ax
        mov  [pitch],bx
        jmp  @@pflip
@@pf1:  cmp  ax,-64
        jge  @@pok
        mov  bx,-128
        sub  bx,ax
        mov  [pitch],bx
@@pflip:
        mov  ax,[heading]
        add  ax,128
        and  ax,255
        mov  [heading],ax
        mov  ax,[roll]
        add  ax,128
        and  ax,255
        mov  [roll],ax
@@pok:

        ; --- energy: climbing costs airspeed, diving buys it back ---
        mov  ax,[psin]          ; sin(pitch)*256
        mov  bx,24
        imul bx                 ; DX:AX = psin*24
        mov  bx,256
        idiv bx                 ; -24..24 per tick
        mov  bx,[vel]
        sub  bx,ax
        jns  @@ve
        xor  bx,bx
@@ve:   mov  [vel],bx
        ; --- stall: below VSTALL the nose falls through on its own ---
        mov  ax,[vel]
        cmp  ax,VSTALL
        jge  @@nst
        mov  ax,[pitch]
        cmp  ax,-48
        jle  @@nst
        dec  ax
        mov  [pitch],ax
@@nst:
        ; --- altitude clamp [24, CEIL] ---
        mov  ax,[camy]
        cmp  ax,24
        jge  @@y1
        mov  ax,24
@@y1:   cmp  ax,CEIL
        jle  @@y2
        mov  ax,CEIL
@@y2:   mov  [camy],ax

        ; --- N key: toggle day/night palette (on key-down edge only) ---
        mov  al,[KEYS+SC_N]
        cmp  al,[prevn]
        je   @@nn
        mov  [prevn],al
        test al,al
        jz   @@nn
        xor  byte ptr [daymode],1
        call APPLYPAL
@@nn:
        ; --- F2: cockpit panel on/off (edge-triggered; C is rudder now) ---
        mov  al,[KEYS+SC_F2]
        cmp  al,[prevc]
        je   @@ncp
        mov  [prevc],al
        test al,al
        jz   @@ncp
        xor  byte ptr [cockpit],1
@@ncp:
        ; --- F3: chase camera (edge) ---
        mov  al,[KEYS+SC_F3]
        cmp  al,[prevv]
        je   @@nf3
        mov  [prevv],al
        test al,al
        jz   @@nf3
        xor  byte ptr [chsview],1
@@nf3:
        ; --- F4: orbit camera around the locked target (edge) ---
        mov  al,[KEYS+SC_F4]
        cmp  al,[prevt4]
        je   @@nf4
        mov  [prevt4],al
        test al,al
        jz   @@nf4
        cmp  byte ptr [tgtcam],0
        jne  @@f4off
        mov  si,[locki]
        cmp  si,0FFFFh
        je   @@nf4              ; nothing locked: nothing to orbit
        mov  ax,[pah+si]
        mov  [tgaz],ax          ; start right behind the target
        mov  word ptr [tgel],12
        mov  byte ptr [tgtcam],1
        jmp  @@nf4
@@f4off:
        mov  byte ptr [tgtcam],0
@@nf4:  cmp  word ptr [locki],0FFFFh ; the lock died: so does the view
        jne  @@lkok
        mov  byte ptr [tgtcam],0
@@lkok:
        ; --- F4 active: the arrows steer the camera, not the jet ---
        cmp  byte ptr [tgtcam],0
        je   @@ntc
        cmp  byte ptr [KEYS+SC_LF],0
        je   @@tc1
        sub  word ptr [tgaz],2
        and  word ptr [tgaz],255
@@tc1:  cmp  byte ptr [KEYS+SC_RT],0
        je   @@tc2
        add  word ptr [tgaz],2
        and  word ptr [tgaz],255
@@tc2:  cmp  byte ptr [KEYS+SC_UP],0
        je   @@tc3
        mov  ax,[tgel]
        inc  ax
        cmp  ax,56
        jle  @@tcu
        mov  ax,56
@@tcu:  mov  [tgel],ax
@@tc3:  cmp  byte ptr [KEYS+SC_DN],0
        je   @@ntc
        mov  ax,[tgel]
        dec  ax
        cmp  ax,-30
        jge  @@tcd
        mov  ax,-30
@@tcd:  mov  [tgel],ax
@@ntc:
        ; --- M key: right MFD mode, map <-> target camera (edge) ---
        mov  al,[KEYS+SC_M]
        cmp  al,[prevm]
        je   @@nmfd
        mov  [prevm],al
        test al,al
        jz   @@nmfd
        xor  byte ptr [mfdmode],1
@@nmfd:
        ; --- Enter: lock the plane inside the aiming ring (edge). The
        ; nearest jet whose screen point is within 24 px of the ring
        ; centre (160,100) wins; nothing there = lock dropped.
        mov  al,[KEYS+SC_ENT]
        cmp  al,[prevt]
        je   @@nlk
        mov  [prevt],al
        test al,al
        jz   @@nlk
        mov  word ptr [locki],0FFFFh
        mov  word ptr [lockd],7FFFh
        xor  si,si
@@lks:  mov  bx,si              ; cannot lock a dead jet
        shr  bx,1
        cmp  byte ptr [pst+bx],0
        jne  @@lkn
        mov  ax,[pax+si]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[paz+si]
        sub  ax,[camz]
        mov  [wdz],ax
        push si
        call ROTXZ
        pop  si
        mov  ax,[rcz]
        cmp  ax,NEARZ
        jl   @@lkn
        mov  [tpi],ax           ; keep the range for the best-pick test
        mov  dx,[pay+si]
        sub  dx,[camy]
        mov  ax,[rcx]
        mov  cx,[rcz]
        push si
        call PPOINT             ; last frame's view state: close enough
        pop  si
        jc   @@lkn
        sub  ax,160
        jns  @@lk1
        neg  ax
@@lk1:  cmp  ax,24
        jg   @@lkn
        sub  dx,100
        jns  @@lk2
        neg  dx
@@lk2:  cmp  dx,24
        jg   @@lkn
        mov  ax,[tpi]
        cmp  ax,[lockd]
        jae  @@lkn
        mov  [lockd],ax
        mov  [locki],si
@@lkn:  add  si,2
        cmp  si,NPLANE*2
        jb   @@lks
@@nlk:
        ; --- wind drift (world space, constant breeze) ---
        mov  ax,[camx]
        add  ax,WINDX
        mov  [camx],ax
        mov  ax,[camz]
        add  ax,WINDZ
        mov  [camz],ax

        ; --- sway: the whole VIEW floats on a slow sine (screen-space,
        ; so it is per-pixel smooth - pitch steps are 5 px and jerk).
        ; Every full cycle rolls a new amplitude (3..6 px, more over
        ; mountains/water) and a new period (~7..13 s). The cockpit
        ; stays put; the world breathes behind the glass.
        mov  ax,[swph]
        add  ax,[swspd]
        mov  [swph],ax
        jnc  @@sw1              ; carry = full circle: re-roll the dice
        call RND16
        and  ax,3
        add  ax,3               ; amplitude 3..6 px
        mov  bx,[lgnd]
        cmp  bx,700
        jl   @@swm
        add  ax,3               ; mountain waves run higher
        jmp  @@swa
@@swm:  cmp  bx,440
        jge  @@swa
        inc  ax                 ; a little extra over open water
@@swa:  mov  [swamp],ax
        call RND16
        and  ax,255
        add  ax,278             ; phase step 278..533 = ~13..7 s cycle
        mov  [swspd],ax
@@sw1:  mov  ax,[swph]
        mov  cl,8
        shr  ax,cl              ; angle 0..255
        push ax
        call SINQ               ; sin*256
        imul word ptr [swamp]
        mov  cx,256
        idiv cx
        mov  [swayy],ax         ; vertical float -amp..+amp
        pop  ax
        add  ax,64              ; X leads by a quarter turn (lazy circle)
        call SINQ
        imul word ptr [swamp]
        mov  cx,512
        idiv cx                 ; half amplitude sideways
        mov  [swayx],ax
@@tb3:
        ; --- advance: split vel/16 into horizontal (cos p) and climb (sin p)
        mov  ax,[vel]
        mov  cl,4
        shr  ax,cl              ; total speed, units per tick
        push ax
        imul word ptr [psin]    ; climb component
        mov  bx,256
        idiv bx
        add  [camy],ax
        pop  ax
        imul word ptr [pcos]    ; horizontal component
        mov  bx,256
        idiv bx
        mov  [fwd],ax
        mov  ax,[hsin]
        imul word ptr [fwd]     ; DX:AX = hsin * fwd
        mov  bx,256
        idiv bx                 ; AX = fwd * sin(heading)
        add  [camx],ax
        mov  ax,[hcos]
        imul word ptr [fwd]
        mov  bx,256
        idiv bx
        add  [camz],ax
        ; --- Backspace: fire a missile (edge; sits right above Enter =
        ; lock). Homing on the lock, straight down the nose otherwise.
        mov  al,[KEYS+SC_BS]
        cmp  al,[prevf]
        je   @@nfr
        mov  [prevf],al
        test al,al
        jz   @@nfr
        cmp  byte ptr [msact],0
        jne  @@nfr
        cmp  byte ptr [pammo],0
        je   @@nfr
        dec  byte ptr [pammo]
        mov  byte ptr [msact],1
        mov  ax,[locki]
        mov  [mstgt],ax
        mov  word ptr [mlife],140
        mov  ax,[hsin]          ; spawn 100 ahead, 20 below the sightline
        mov  bx,100
        imul bx
        mov  bx,256
        idiv bx
        add  ax,[camx]
        mov  [msx],ax
        mov  [mpx],ax
        mov  ax,[hcos]
        mov  bx,100
        imul bx
        mov  bx,256
        idiv bx
        add  ax,[camz]
        mov  [msz],ax
        mov  [mpz],ax
        mov  ax,[camy]
        sub  ax,20
        mov  [msy],ax
        mov  [mpy],ax
        ; straight-flight velocity: 64/tick along heading and pitch
        mov  ax,[pcos]
        mov  bx,64
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
        mov  bx,64
        imul bx
        mov  bx,256
        idiv bx
        mov  [mvy],ax
@@nfr:
        ; --- reload: one missile back on the rails every ~20 s ---
        cmp  byte ptr [pammo],4
        jae  @@nrl
        inc  word ptr [mrel]
        cmp  word ptr [mrel],360
        jb   @@nrl
        mov  word ptr [mrel],0
        inc  byte ptr [pammo]
@@nrl:
        ; --- Space: the cannon. Hold to fire; a volley lands every
        ; 2nd tick on whatever sits inside the aiming circle. Each jet
        ; soaks 2..5 hits (its HP roll) before it comes apart.
        cmp  byte ptr [guntik],0
        je   @@gt0
        dec  byte ptr [guntik]
@@gt0:  cmp  word ptr [hitft],0
        je   @@gt0a
        dec  word ptr [hitft]
@@gt0a: cmp  word ptr [phit],0
        je   @@gt1
        dec  word ptr [phit]
@@gt1:  cmp  byte ptr [KEYS+SC_SP],0
        je   @@gnr
        cmp  word ptr [gunam],0
        je   @@gnf
        mov  byte ptr [guntik],2
        ; ---- launch one tracer round (ring of NTRC, oldest reused) ----
        mov  bx,[trnext]
        inc  word ptr [trnext]
        and  word ptr [trnext],NTRC-1
        mov  di,bx
        add  di,di              ; word offset
        mov  byte ptr [trcact+bx],1
        mov  word ptr [trlif+di],30
        mov  ax,[hcos]          ; muzzle: wing-root offset, gun alternates
        mov  cx,40
        imul cx
        mov  cx,256
        idiv cx
        test bx,1
        jz   @@gmr
        neg  ax                 ; left gun this time
@@gmr:  add  ax,[camx]
        mov  [tcx+di],ax
        mov  ax,[hsin]
        mov  cx,40
        imul cx
        mov  cx,256
        idiv cx
        neg  ax
        test bx,1
        jz   @@gmz
        neg  ax
@@gmz:  add  ax,[camz]
        mov  [tcz+di],ax
        mov  ax,[camy]
        sub  ax,14
        mov  [tcy+di],ax
        mov  ax,[pcos]          ; 150/tick along the nose
        mov  cx,150
        imul cx
        mov  cx,256
        idiv cx
        mov  [dsac],ax          ; horizontal component
        mov  ax,[hsin]
        imul word ptr [dsac]
        mov  cx,256
        idiv cx
        mov  [trvx+di],ax
        mov  ax,[hcos]
        imul word ptr [dsac]
        mov  cx,256
        idiv cx
        mov  [trvz+di],ax
        mov  ax,[psin]
        mov  cx,150
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
        jnz  @@gnf              ; volleys on even ticks
        dec  word ptr [gunam]
        xor  si,si              ; who is in the ring?
@@gsc:  mov  bx,si
        shr  bx,1
        cmp  byte ptr [pst+bx],0
        jne  @@gsn
        mov  ax,[pax+si]
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,[paz+si]
        sub  ax,[camz]
        mov  [wdz],ax
        push si
        call ROTXZ
        pop  si
        mov  ax,[rcz]
        cmp  ax,NEARZ
        jl   @@gsn
        cmp  ax,4500            ; cannon reach
        jg   @@gsn
        mov  dx,[pay+si]
        sub  dx,[camy]
        mov  ax,[rcx]
        mov  cx,[rcz]
        push si
        call PPOINT
        pop  si
        jc   @@gsn
        sub  ax,160
        jns  @@gh1
        neg  ax
@@gh1:  cmp  ax,18
        jg   @@gsn
        sub  dx,100
        jns  @@gh2
        neg  dx
@@gh2:  cmp  dx,18
        jg   @@gsn
        mov  [hitfx],si         ; hit! sparkle on the victim
        mov  word ptr [hitft],5
        mov  bx,si
        shr  bx,1
        dec  byte ptr [php+bx]
        jnz  @@gnf              ; wounded, still flying
        push si
        call BOOM
        pop  si
        inc  word ptr [psc]
        jmp  @@gnf
@@gsn:  add  si,2
        cmp  si,NPLANE*2
        jb   @@gsc
        jmp  @@gnf
@@gnr:  cmp  word ptr [gunam],250 ; trigger released: the belt feeds in
        jae  @@gnf
        inc  word ptr [gunreg]
        cmp  word ptr [gunreg],8
        jb   @@gnf
        mov  word ptr [gunreg],0
        inc  word ptr [gunam]
@@gnf:
        ; --- the black box: record every 2nd tick for the flashback ---
        mov  ax,[lasttk]
        test ax,1
        jnz  @@fbskip
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
        jb   @@fbw
        xor  bx,bx
@@fbw:  mov  [flbh],bx
@@fbskip:
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
        cmp  byte ptr [dying],0
        je   @@live3
        ret                     ; the wreck cannot crash twice
@@live3:
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
        mov  bx,[camy]
        sub  bx,ax              ; height above ground
        cmp  bx,250
        jge  @@gfx
        cmp  word ptr [vel],150
        jl   @@gfx
        mov  ax,250
        sub  ax,bx              ; cushion grows as the gap shrinks
        mov  cl,4
        shr  ax,cl              ; up to ~15 units of lift per tick
        add  [camy],ax
@@gfx:  mov  ax,[lgnd]
        add  ax,14              ; hull clearance above the slope
        cmp  [camy],ax
        jge  @@terok
        call CRASHHANDLE        ; flew into the hillside
        ret
@@terok:
        call HBLD
        mov  ax,[bstreet]
        cmp  ax,0
        jne  @@nocol            ; street / patch -> free air
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
        jge  @@a1
        neg  ax
@@a1:   cmp  ax,[bhw]
        jge  @@nocol
        mov  ax,[camz]
        sub  ax,[wcz]
        cmp  ax,0
        jge  @@a2
        neg  ax
@@a2:   cmp  ax,[bhd]
        jge  @@nocol
        mov  ax,[gi]            ; rooftop = terrain base + building height
        mov  bx,[gj]
        call GETH
        call WORLDH
        add  ax,[bhgt2]
        cmp  [camy],ax
        jge  @@nocol            ; above roof -> safe
        call CRASHHANDLE
@@nocol:
        ret

CRASHHANDLE:
        ; cinematic death: our jet becomes a wreck (same breakup as the
        ; AI), the camera freezes on the chase spot and watches it fall.
        ; INPUT switches to the spectator branch until PLAYERRESET.
        cmp  byte ptr [dying],0
        jne  @@cr               ; already falling
        mov  byte ptr [dying],1
        mov  word ptr [dytick],0
        mov  ax,[flbh]          ; the flashback starts at the oldest tick
        mov  [flbc],ax
        mov  word ptr [flbcnt],FLBN
        call PBOOM
        mov  ax,[hsin]          ; freeze the camera behind the wreck
        mov  bx,400
        imul bx
        mov  bx,256
        idiv bx
        mov  bx,[camx]
        sub  bx,ax
        mov  [dcx],bx
        mov  ax,[hcos]
        mov  bx,400
        imul bx
        mov  bx,256
        idiv bx
        mov  bx,[camz]
        sub  bx,ax
        mov  [dcz],bx
        mov  ax,[camy]
        add  ax,60
        mov  [dcy],ax
@@cr:   ret

; PLAYERRESET - Space pressed during the fall: take a fresh jet.
PLAYERRESET:
        mov  byte ptr [dying],0
        mov  word ptr [dytick],0
        mov  word ptr [camy],1450   ; respawn above everything
        mov  word ptr [roll],0
        mov  word ptr [vel],CRUISE  ; fresh jet: cruise speed + full tank
        mov  word ptr [fuel],FUELMAX
        mov  word ptr [pitch],0
        mov  word ptr [throt],42    ; 65% power
        mov  byte ptr [abon],0
        mov  byte ptr [pammo],4
        mov  byte ptr [msact],0
        mov  word ptr [gunam],250
        mov  byte ptr [pdam],0
        mov  word ptr [flbcnt],0
        call FLBSEED            ; a fresh black box for a fresh jet
        ret
