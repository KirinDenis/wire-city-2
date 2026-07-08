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
        je   @@tw
        mov  ax,[throt]
        add  ax,2
        cmp  ax,64
        jle  @@tw1
        mov  ax,64
@@tw1:  mov  [throt],ax
@@tw:   cmp  byte ptr [KEYS+SC_S],0
        je   @@ts
        mov  ax,[throt]
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
        ; --- PITCH: real fighter controls. Pull (DOWN key) rotates the nose
        ; through the roll plane: pitch_rate = q*cos(roll), yaw = q*sin(roll).
        ; Wings level -> loop; knife-edge -> flat turn; inverted -> split-S.
        xor  cx,cx              ; q = elevator input
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
        ; --- C key: cockpit panel on/off (edge-triggered) ---
        mov  al,[KEYS+SC_C]
        cmp  al,[prevc]
        je   @@ncp
        mov  [prevc],al
        test al,al
        jz   @@ncp
        xor  byte ptr [cockpit],1
@@ncp:
        ; --- wind drift (world space, constant breeze) ---
        mov  ax,[camx]
        add  ax,WINDX
        mov  [camx],ax
        mov  ax,[camz]
        add  ax,WINDZ
        mov  [camz],ax

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
        ret

; ============================================================================
;  COLLISION
; ============================================================================
COLLIDE:
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
        ; fill screen dark (index 1) -> white BIOS text renders cleanly on it
        mov  ax,0A000h
        mov  es,ax
        xor  di,di
        mov  ax,0101h
        mov  cx,32000
        rep  stosw
        ; messages (white text)
        mov  byte ptr [HCOL],8
        mov  ah,02h
        mov  bh,0
        mov  dh,11
        mov  dl,13
        int  10h
        mov  si,offset MSGCRASH
        call PRSTR
        mov  ah,02h
        mov  bh,0
        mov  dh,13
        mov  dl,12
        int  10h
        mov  si,offset MSGREST
        call PRSTR
@@w1:   cmp  byte ptr [KEYS+SC_SP],0
        je   @@w1
        mov  word ptr [camy],1450   ; respawn above everything (peaks ~1110)
        mov  word ptr [roll],0      ; so we don't reappear inside the same tower
        mov  word ptr [vel],CRUISE  ; fresh jet: cruise speed + full tank
        mov  word ptr [fuel],FUELMAX
        mov  word ptr [pitch],0     ; wings level, nose on the horizon
        mov  word ptr [throt],64    ; military power
        mov  byte ptr [abon],0
@@w2:   cmp  byte ptr [KEYS+SC_SP],0
        jne  @@w2
        ret
