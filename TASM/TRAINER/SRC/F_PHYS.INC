; ============================================================================
;  F_PHYS.INC - the flight model, PORTED FROM OWL FLY (FLIGHT.INC):
;  air density -> engine thrust -> drag -> F = ma -> full-circle roll ->
;  LOCAL-axis rudder -> elevator through the roll plane (loops, rolls,
;  the gimbal flip at the vertical) -> energy (dive buys speed, climb
;  spends it) -> stall -> the ground cushion -> 3-D advance.
;  The ground school (nose-wheel, VR, brakes, dirt, touchdown) is ours.
; ============================================================================
THRUST  equ 720                 ; engine force (the OWLFLY jet)
DRAGK2  equ 680                 ; drag = V*V/DRAGK2 * rho/256 (quadratic)
GRAV    equ 4                   ; g along the flight path, vel units/tick
MASS    equ 8000                ; the trainer, tanks full
VSTALL  equ 300                 ; clean stall speed (flaps take 20 each)
VRSPD   equ 330                 ; rotation speed, clean (flaps take 15)
TURNDRG equ 2                   ; induced drag per tick while pulling
CEIL    equ 3000                ; the ceiling

; ============================================================================
RESET:  mov  word ptr [apx],-3100
        mov  word ptr [apy],0
        mov  word ptr [apz],-40
        mov  word ptr [hdg],64
        mov  word ptr [chdgf],64*256
        mov  word ptr [hdgr],0
        mov  word ptr [pit],0
        mov  word ptr [rol],0
        mov  word ptr [vel],0
        mov  word ptr [vsp],0
        mov  word ptr [thr],0
        mov  word ptr [flap],0
        mov  word ptr [gear],1
        mov  word ptr [brk],0
        mov  word ptr [dmg],0
        mov  word ptr [dead],0
        mov  word ptr [wrn],0
        mov  word ptr [pfrac],0
        mov  word ptr [hfrac],0
        mov  word ptr [qramp],0
        mov  word ptr [yfrac],0
        mov  word ptr [xfrac],0
        mov  word ptr [zfrac],0
        mov  word ptr [airb],0
        mov  word ptr [aoa],0
        mov  word ptr [hy],0
        mov  word ptr [hp],0
        mov  word ptr [cnp],0
        mov  word ptr [cnpt],0
        call RND16
        mov  al,ah
        cbw
        mov  cl,3
        sar  ax,cl
        mov  [wind],ax          ; the day's crosswind, -16..15
        ret

; ============================================================================
;  PHYS - one 18.2 Hz tick of the whole model
; ============================================================================
PHYS:   cmp  word ptr [dead],0
        je   @@go
        ret
@@go:
        ; ---- throttle spools while +/- is held ----
        mov  ax,[thr]
        cmp  byte ptr [KEYS+SC_W],0     ; W: layout-proof in the browser
        jne  @@ta
        cmp  byte ptr [KEYS+SC_EQ],0
        jne  @@ta
        cmp  byte ptr [KEYS+SC_NPP],0
        je   @@tb
@@ta:   add  ax,2
@@tb:   cmp  byte ptr [KEYS+SC_S],0
        jne  @@tc
        cmp  byte ptr [KEYS+SC_MIN],0
        jne  @@tc
        cmp  byte ptr [KEYS+SC_NPM],0
        je   @@td
@@tc:   sub  ax,2
@@td:   or   ax,ax
        jge  @@te
        xor  ax,ax
@@te:   cmp  ax,100
        jle  @@tf
        mov  ax,100
@@tf:   mov  [thr],ax
        ; ---- head-look: Shift + arrows; eases home hands-off ----
        mov  al,[KEYS+SC_LSH]
        or   al,[KEYS+SC_RSH]
        mov  [shft],al
        or   al,al
        jz   @@hlr
        cmp  byte ptr [KEYS+SC_LF],0
        je   @@h1
        sub  word ptr [hy],3
@@h1:   cmp  byte ptr [KEYS+SC_RT],0
        je   @@h2
        add  word ptr [hy],3
@@h2:   cmp  byte ptr [KEYS+SC_UP],0
        je   @@h3
        add  word ptr [hp],2
@@h3:   cmp  byte ptr [KEYS+SC_DN],0
        je   @@h4
        sub  word ptr [hp],2
@@h4:   mov  ax,[hy]
        cmp  ax,-44
        jge  @@h5
        mov  ax,-44
@@h5:   cmp  ax,44
        jle  @@h6
        mov  ax,44
@@h6:   mov  [hy],ax
        mov  ax,[hp]
        cmp  ax,-16
        jge  @@h7
        mov  ax,-16
@@h7:   cmp  ax,28
        jle  @@h8
        mov  ax,28
@@h8:   mov  [hp],ax
        jmp  @@hlx
@@hlr:  mov  ax,[hy]
        call EASE4
        mov  [hy],ax
        mov  ax,[hp]
        call EASE4
        mov  [hp],ax
@@hlx:  ; masked arrows: while Shift is held the stick stays centred
        xor  ax,ax
        cmp  byte ptr [shft],0
        jne  @@mk0
        mov  al,[KEYS+SC_LF]
        mov  ah,[KEYS+SC_RT]
@@mk0:  mov  [klf],al
        mov  [krt],ah
        xor  ax,ax
        cmp  byte ptr [shft],0
        jne  @@mk1
        mov  al,[KEYS+SC_UP]
        mov  ah,[KEYS+SC_DN]
@@mk1:  mov  [kup],al
        mov  [kdn],ah
        ; ---- the canopy swings toward its target ----
        mov  ax,[cnpt]
        mov  bx,40
        mul  bx
        mov  bx,ax
        mov  ax,[cnp]
        cmp  ax,bx
        je   @@cn2
        jl   @@cn1
        sub  ax,2
        jmp  @@cn2
@@cn1:  add  ax,2
@@cn2:  mov  [cnp],ax
        ; ---- air density: rho = 256 - alt/8, clamped 64..256 ----
        mov  ax,[apy]
        mov  bx,ax
        mov  cl,3
        shr  bx,cl
        mov  ax,256
        sub  ax,bx
        cmp  ax,64
        jge  @@r1
        mov  ax,64
@@r1:   mov  [rho],ax
        ; ---- the jet breathes air: thrust = THRUST*(rho+256)/512*thr/100 ----
        add  ax,256
        mov  bx,ax
        mov  ax,THRUST
        imul bx
        mov  bx,512
        idiv bx
        imul word ptr [thr]
        mov  bx,100
        idiv bx
        mov  [teff],ax
        ; ---- drag = V*V/DRAGK2 * rho/256: QUADRATIC, the real curve
        ; (D = half rho V^2 S Cd) - a dive meets terminal velocity ----
        mov  ax,[vel]
        imul word ptr [vel]
        mov  bx,DRAGK2
        idiv bx
        imul word ptr [rho]
        mov  bx,256
        idiv bx
        mov  [tdrag],ax
        mov  ax,[vel]
        imul word ptr [flap]
        mov  bx,32
        idiv bx
        add  [tdrag],ax
        ; ---- F = ma: accel = (thrust - drag)*64/MASS ----
        mov  ax,[teff]
        sub  ax,[tdrag]
        mov  cx,64
        imul cx
        mov  bx,MASS
        idiv bx
        add  ax,[vel]
        jns  @@v0
        xor  ax,ax
@@v0:   cmp  ax,999
        jle  @@v1
        mov  ax,999
@@v1:   mov  [vel],ax
        cmp  word ptr [apy],0
        jg   @@air
        jmp  @@gnd

        ; ================= AIRBORNE (the OWL FLY model) =================
@@air:  mov  word ptr [airb],1
        ; ---- roll: full circle; hands off near the ground, the cushion
        ; rights the wings (in free air the bank HOLDS) ----
        xor  cx,cx
        cmp  byte ptr [klf],0
        je   @@rl1
        sub  word ptr [rol],3
        mov  cx,1
@@rl1:  cmp  byte ptr [krt],0
        je   @@rl2
        add  word ptr [rol],3
        mov  cx,1
@@rl2:  and  word ptr [rol],255
        jcxz @@rlt
        jmp  @@rud0
@@rlt:  cmp  word ptr [apy],90
        jge  @@rud0
        mov  ax,[rol]
        or   ax,ax
        jz   @@rud0
        cmp  ax,128
        ja   @@rlu
        sub  ax,2
        jns  @@rls
        xor  ax,ax
@@rls:  cmp  ax,2
        ja   @@rlw
        xor  ax,ax
@@rlw:  mov  [rol],ax
        jmp  @@rud0
@@rlu:  add  ax,2
        cmp  ax,254
        jb   @@rlx
        xor  ax,ax
@@rlx:  mov  [rol],ax
        ; ---- rudder: LOCAL yaw about the plane's own vertical axis:
        ; wings level = flat turn, knife-edge = the top rudder holds
        ; the nose. hfrac/pfrac carry the eighths. ----
@@rud0: xor  cx,cx
        cmp  byte ptr [KEYS+SC_Z],0
        je   @@rd1
        sub  cx,8
@@rd1:  cmp  byte ptr [KEYS+SC_C],0
        je   @@rd2
        add  cx,8
@@rd2:  jcxz @@elev
        push cx
        mov  ax,[rol]
        add  ax,64
        and  ax,255
        call SINQ               ; cos(roll)
        pop  cx
        push cx
        imul cx
        mov  bx,256
        idiv bx
        add  ax,[hfrac]
        cwd
        mov  bx,8
        idiv bx
        mov  [hfrac],dx
        add  ax,[hdg]
        and  ax,255
        mov  [hdg],ax
        mov  ax,[rol]
        and  ax,255
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
        add  [pit],ax
        ; ---- elevator: the pull rotates the nose through the roll
        ; plane: pitch += q*cos(roll), heading += q*sin(roll). A tap
        ; nudges, a hold ramps to the full rate in ~0.4 s. ----
@@elev: xor  cx,cx
        cmp  byte ptr [kdn],0
        je   @@q1
        mov  cx,1               ; pull: nose up
@@q1:   cmp  byte ptr [kup],0
        je   @@q2
        sub  cx,1               ; push: nose down
@@q2:   jcxz @@noq
        mov  ax,[qramp]
        add  ax,2
        cmp  ax,16
        jle  @@qr
        mov  ax,16
@@qr:   mov  [qramp],ax
        or   cx,cx
        jns  @@qs
        neg  ax
@@qs:   mov  cx,ax              ; q, signed, in eighths
        mov  ax,[vel]           ; pulling bleeds a little airspeed
        sub  ax,TURNDRG
        jns  @@qv
        xor  ax,ax
@@qv:   mov  [vel],ax
        push cx
        mov  ax,[rol]
        add  ax,64
        and  ax,255
        call SINQ               ; cos(roll)
        pop  cx
        push cx
        imul cx
        mov  bx,256
        idiv bx
        add  ax,[pfrac]
        cwd
        mov  bx,8
        idiv bx
        mov  [pfrac],dx
        add  [pit],ax
        mov  ax,[rol]
        and  ax,255
        call SINQ               ; sin(roll)
        pop  cx
        imul cx
        mov  bx,256
        idiv bx
        add  ax,[hfrac]
        cwd
        mov  bx,8
        idiv bx
        mov  [hfrac],dx
        add  ax,[hdg]
        and  ax,255
        mov  [hdg],ax
        jmp  @@flip
@@noq:  mov  word ptr [qramp],0 ; stick centred: attitude holds free -
        cmp  word ptr [apy],90  ; near the deck the cushion floats a
        jge  @@flip             ; dropped nose back level
        mov  ax,[pit]
        or   ax,ax
        jns  @@flip
        inc  ax
        mov  [pit],ax
        ; ---- the gimbal flip at the vertical: over the top the loop
        ; swaps to inverted flight and closes smoothly ----
@@flip: mov  ax,[pit]
        cmp  ax,64
        jle  @@fl1
        mov  bx,128
        sub  bx,ax
        mov  [pit],bx
        jmp  @@fl2
@@fl1:  cmp  ax,-64
        jge  @@fl3
        mov  bx,-128
        sub  bx,ax
        mov  [pit],bx
@@fl2:  mov  ax,[hdg]
        add  ax,128
        and  ax,255
        mov  [hdg],ax
        mov  ax,[rol]
        add  ax,128
        and  ax,255
        mov  [rol],ax
@@fl3:
        ; ---- energy: climbing costs airspeed, diving buys it back ----
        mov  ax,[pit]
        and  ax,255
        call SINQ
        mov  bx,GRAV
        imul bx
        mov  bx,256
        idiv bx
        mov  bx,[vel]
        sub  bx,ax
        jns  @@en1
        xor  bx,bx
@@en1:  mov  [vel],bx
        ; ---- stall: below Vs the nose falls through on its own ----
        mov  ax,[flap]
        mov  bx,20
        imul bx
        mov  bx,VSTALL
        sub  bx,ax              ; Vs for this flap setting
        mov  ax,[vel]
        cmp  ax,bx
        jge  @@nst
        cmp  word ptr [apy],60  ; in ground effect the nose holds
        jl   @@nst
        mov  ax,[pit]
        cmp  ax,-48
        jle  @@nst
        dec  ax
        mov  [pit],ax
@@nst:  mov  ax,[wind]          ; the crosswind owns the airborne
        mov  cl,3
        sar  ax,cl
        add  [apz],ax
        jmp  @@move

        ; ================= ON THE GROUND (the school) =================
@@gnd:  mov  word ptr [apy],0
        cmp  word ptr [gear],1
        je   @@gok
        mov  word ptr [dead],1
        ret
@@gok:  cmp  word ptr [brk],0
        je   @@nbr
        mov  ax,[vel]
        mov  cl,5
        sar  ax,cl
        add  ax,3
        sub  [vel],ax
        cmp  word ptr [vel],0
        jge  @@nbr
        mov  word ptr [vel],0
@@nbr:  mov  ax,[vel]           ; rolling resistance of the wheels
        mov  cl,8
        sar  ax,cl
        inc  ax
        sub  [vel],ax
        cmp  word ptr [vel],0
        jge  @@rr1
        mov  word ptr [vel],0
@@rr1:  ; nose-wheel steering: the rate GROWS with ground speed
        xor  ax,ax
        cmp  byte ptr [klf],0
        je   @@s1
        sub  ax,12
@@s1:   cmp  byte ptr [krt],0
        je   @@s2
        add  ax,12
@@s2:   cmp  byte ptr [KEYS+SC_Z],0
        je   @@s3
        sub  ax,6
@@s3:   cmp  byte ptr [KEYS+SC_C],0
        je   @@s4
        add  ax,6
@@s4:   imul word ptr [vel]
        cmp  ax,512
        jle  @@s5
        mov  ax,512
@@s5:   cmp  ax,-512
        jge  @@s6
        mov  ax,-512
@@s6:   add  [hdgr],ax          ; 8.8 residue: slow taxi turns count
        mov  ax,[hdgr]
        mov  cl,8
        sar  ax,cl
        add  [hdg],ax
        and  word ptr [hdg],255
        mov  cl,8
        shl  ax,cl
        sub  [hdgr],ax
        ; rotation: past VR the pull raises the nose; below it stays down
        mov  ax,[flap]
        mov  bx,15
        imul bx
        mov  bx,VRSPD
        sub  bx,ax              ; VR for this flap setting
        mov  ax,[vel]
        cmp  ax,bx
        jl   @@pdn
        cmp  byte ptr [kdn],0
        je   @@pdn
        mov  ax,[pit]
        inc  ax
        cmp  ax,14
        jle  @@pst
        mov  ax,14
@@pst:  mov  [pit],ax
        jmp  @@flt
@@pdn:  mov  ax,[pit]
        or   ax,ax
        jle  @@pz
        dec  ax
        mov  [pit],ax
        jmp  @@flt
@@pz:   mov  word ptr [pit],0
@@flt:  mov  ax,[flap]          ; past VLOF lift wins: she floats off
        mov  bx,15
        imul bx
        mov  bx,VRSPD+40
        sub  bx,ax
        mov  ax,[vel]
        cmp  ax,bx
        jl   @@pave
        cmp  word ptr [pit],2
        jge  @@pave
        mov  word ptr [pit],2
@@pave: call ONPAVE
        or   ax,ax
        jnz  @@pav1
        cmp  word ptr [vel],160 ; dirt at speed = wreck
        jl   @@slow
        mov  word ptr [dead],1
        ret
@@slow: call RND16
        mov  al,ah
        cbw
        mov  cl,4
        sar  ax,cl
        mov  [rol],ax           ; the dirt shakes you...
        cmp  word ptr [vel],8
        jl   @@move
        inc  word ptr [dmg]     ; ...and grinds you
        cmp  word ptr [dmg],90
        jl   @@move
        mov  word ptr [dead],1
        ret
@@pav1: mov  word ptr [rol],0
        jmp  @@move

        ; ================= 3-D ADVANCE (shared) =================
        ; spd = vel/32; climb = spd*sin(pitch) kept in 8.8 with a
        ; fraction carry; forward = spd*cos(pitch) by AIRCRAFT heading
@@move: mov  ax,[pit]
        and  ax,255
        call SINQ
        mov  [psn2],ax
        mov  ax,[pit]
        add  ax,64
        and  ax,255
        call SINQ
        mov  [pcs2],ax
        mov  ax,[vel]           ; vel*8 = (vel/32)<<8: the 8.8 speed
        mov  cl,3
        shl  ax,cl
        mov  [spd2],ax
        imul word ptr [psn2]
        mov  bx,256
        idiv bx
        mov  [vsp],ax           ; climb rate, 8.8 units/tick
        cmp  word ptr [apy],64  ; ground effect: the cushion damps sink
        jge  @@nge
        or   ax,ax
        jns  @@nge
        mov  bx,[apy]
        add  bx,16
        imul bx
        mov  bx,80
        idiv bx
        mov  [vsp],ax
@@nge:  add  [yfrac],ax
        mov  ax,[yfrac]
        mov  cl,8
        sar  ax,cl
        add  [apy],ax
        mov  cl,8
        shl  ax,cl
        sub  [yfrac],ax
        mov  ax,[spd2]
        imul word ptr [pcs2]
        mov  bx,256
        idiv bx
        mov  [fwd2],ax          ; 8.8 forward
        mov  ax,[hdg]
        and  ax,255
        call SINQ
        imul word ptr [fwd2]
        mov  bx,256
        idiv bx
        add  [xfrac],ax         ; carried east-west
        mov  ax,[xfrac]
        mov  cl,8
        sar  ax,cl
        add  [apx],ax
        mov  cl,8
        shl  ax,cl
        sub  [xfrac],ax
        mov  ax,[hdg]
        add  ax,64
        and  ax,255
        call SINQ
        imul word ptr [fwd2]
        mov  bx,256
        idiv bx
        add  [zfrac],ax         ; carried north-south
        mov  ax,[zfrac]
        mov  cl,8
        sar  ax,cl
        add  [apz],ax
        mov  cl,8
        shl  ax,cl
        sub  [zfrac],ax
        mov  ax,[apy]           ; the ceiling
        cmp  ax,CEIL
        jle  @@ce1
        mov  word ptr [apy],CEIL
@@ce1:
        ; ---- the arrival ----
        cmp  word ptr [apy],0
        jg   @@warn
        cmp  word ptr [airb],0
        je   @@ong
        mov  word ptr [airb],0
        mov  word ptr [apy],0
        mov  word ptr [yfrac],0
        cmp  word ptr [gear],1
        je   @@tg
        mov  word ptr [dead],1
        ret
@@tg:   cmp  word ptr [vsp],-700
        jg   @@sft
        mov  word ptr [dead],1  ; slammed in
        ret
@@sft:  cmp  word ptr [vsp],-300
        jg   @@grs
        mov  word ptr [apy],2   ; firm: the bounce
        mov  word ptr [airb],1
        add  word ptr [pit],2
        jmp  @@warn
@@grs:  mov  word ptr [pit],0   ; greased on
        jmp  @@warn
@@ong:  mov  word ptr [apy],0

        ; ---- angle of attack (visual): slow = nose above the path ----
        xor  bx,bx
        cmp  word ptr [apy],0
        jle  @@aot
        mov  ax,360
        sub  ax,[vel]
        jle  @@aot
        mov  cl,3
        sar  ax,cl
        cmp  ax,12
        jle  @@ao1
        mov  ax,12
@@ao1:  mov  bx,ax
@@aot:  mov  ax,[aoa]
        cmp  ax,bx
        je   @@aod
        jl   @@aou
        dec  ax
        jmp  @@aos
@@aou:  inc  ax
@@aos:  mov  [aoa],ax
@@aod:
        ; ---- the avionics call it ----
@@warn: mov  word ptr [wrn],0
        cmp  word ptr [apy],0
        jle  @@w1
        mov  ax,[flap]
        mov  bx,20
        imul bx
        mov  bx,VSTALL
        sub  bx,ax
        mov  ax,[vel]
        cmp  ax,bx
        jge  @@w1
        or   word ptr [wrn],1   ; STALL
@@w1:   cmp  word ptr [apy],2
        jl   @@w3
        cmp  word ptr [apy],150
        jg   @@w3
        cmp  word ptr [vsp],0
        jge  @@w3
        cmp  word ptr [gear],0
        jne  @@w2
        or   word ptr [wrn],2   ; GEAR
@@w2:   cmp  word ptr [vel],560
        jle  @@w3
        or   word ptr [wrn],4   ; TOO FAST
@@w3:   cmp  word ptr [apy],0
        jg   @@wend
        call ONPAVE
        or   ax,ax
        jnz  @@wend
        or   word ptr [wrn],8   ; OFF RWY
@@wend: ret

; EASE4 - move AX toward zero by 4, snapping the last step
EASE4:  cmp  ax,4
        jg   @@dn
        cmp  ax,-4
        jl   @@up
        xor  ax,ax
        ret
@@dn:   sub  ax,4
        ret
@@up:   add  ax,4
        ret

; ============================================================================
;  ONPAVE - is the aircraft on pavement? (AX = 1/0)
; ============================================================================
ONPAVE: mov  ax,[apx]
        cmp  ax,-3200
        jl   @@no
        cmp  ax,1800
        jg   @@no
        mov  ax,[apz]
        cmp  ax,240
        jl   @@t1
        cmp  ax,360
        jg   @@no
        jmp  @@yes              ; the runway
@@t1:   cmp  ax,-70
        jl   @@t2
        cmp  ax,-10
        jg   @@mid
        jmp  @@yes              ; the taxiway
@@mid:  mov  ax,[apx]            ; the two connectors
        cmp  ax,-3000
        jle  @@yes
        cmp  ax,1550
        jge  @@yes
        jmp  @@no
@@t2:   mov  ax,[apx]            ; the apron
        cmp  ax,-350
        jl   @@no
        cmp  ax,350
        jg   @@no
        mov  ax,[apz]
        cmp  ax,-420
        jl   @@no
@@yes:  mov  ax,1
        ret
@@no:   xor  ax,ax
        ret

; ---- flight-model state -----------------------------------------------------
rho     dw 256
teff    dw 0
tdrag   dw 0
psn2    dw 0
pcs2    dw 0
spd2    dw 0
fwd2    dw 0
pfrac   dw 0
hfrac   dw 0
qramp   dw 0
yfrac   dw 0
xfrac   dw 0
zfrac   dw 0
airb    dw 0
aoa     dw 0
hy      dw 0
hp      dw 0
cnp     dw 0
cnpt    dw 0
shft    db 0
klf     db 0
krt     db 0
kup     db 0
kdn     db 0
