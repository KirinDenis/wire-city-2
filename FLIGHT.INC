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

        ; --- engine: burn fuel; jet thrust breathes air: T*(rho+256)/512 ---
        xor  cx,cx              ; default thrust 0 (flame-out)
        mov  ax,[fuel]
        test ax,ax
        jz   @@noth
        dec  ax
        mov  [fuel],ax
        mov  ax,[rho]
        add  ax,256
        mov  bx,ax
        mov  ax,THRUST
        imul bx                 ; DX:AX = THRUST*(rho+256)
        mov  bx,512
        idiv bx
        mov  cx,ax              ; cx = effective thrust
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

        ; --- turn (yaw) ---
        mov  word ptr [tmpi],0  ; tmpi = turn direction (-1/0/+1)
        cmp  byte ptr [KEYS+SC_LF],0
        je   @@nl
        mov  ax,[heading]       ; turn left
        sub  ax,TURNV
        and  ax,255
        mov  [heading],ax
        mov  word ptr [tmpi],-1
@@nl:   cmp  byte ptr [KEYS+SC_RT],0
        je   @@nr
        mov  ax,[heading]       ; turn right
        add  ax,TURNV
        and  ax,255
        mov  [heading],ax
        mov  word ptr [tmpi],1
@@nr:   ; induced drag: turning bleeds a little airspeed
        mov  ax,[tmpi]
        test ax,ax
        jz   @@ntd
        mov  ax,[vel]
        sub  ax,TURNDRG
        jns  @@td1
        xor  ax,ax
@@td1:  mov  [vel],ax
@@ntd:  ; bank toward target (roll follows turn, decays to 0)
        mov  ax,[tmpi]
        test ax,ax
        jz   @@decay
        jg   @@bankr
        ; bank left: roll -> -BANKMAX
        mov  ax,[roll]
        sub  ax,BANKSTP
        cmp  ax,-BANKMAX
        jge  @@bset
        mov  ax,-BANKMAX
        jmp  @@bset
@@bankr:
        mov  ax,[roll]
        add  ax,BANKSTP
        cmp  ax,BANKMAX
        jle  @@bset
        mov  ax,BANKMAX
        jmp  @@bset
@@decay:
        mov  ax,[roll]          ; return roll toward 0
        test ax,ax
        jz   @@bset
        jg   @@dpos
        add  ax,BANKSTP
        cmp  ax,0
        jle  @@bset
        xor  ax,ax
        jmp  @@bset
@@dpos: sub  ax,BANKSTP
        cmp  ax,0
        jge  @@bset
        xor  ax,ax
@@bset: mov  [roll],ax

        ; --- pitch & energy (yoke convention: UP = nose down = dive) ---
        ; vertical rate scales with airspeed: vrate = vel/40
        mov  ax,[vel]
        xor  dx,dx
        mov  bx,40
        div  bx
        mov  [vrate],ax
        cmp  byte ptr [KEYS+SC_UP],0
        je   @@nu
        mov  ax,[camy]          ; dive: lose altitude...
        sub  ax,[vrate]
        mov  [camy],ax
        mov  ax,[vrate]         ; ...and trade it for airspeed (energy)
        mov  cl,2
        shr  ax,cl
        add  [vel],ax
@@nu:   cmp  byte ptr [KEYS+SC_DN],0
        je   @@nd
        mov  ax,[vel]           ; climb only above stall speed
        cmp  ax,VSTALL
        jl   @@nd
        mov  ax,[camy]          ; climb: gain altitude...
        add  ax,[vrate]
        mov  [camy],ax
        mov  ax,[vrate]         ; ...paying with airspeed (energy)
        shr  ax,1
        sub  [vel],ax
@@nd:
        ; --- pitch visual: horizon eases toward 78 (dive) / 122 (climb) /100 ---
        mov  cx,100             ; neutral
        cmp  byte ptr [KEYS+SC_UP],0
        je   @@h1
        mov  cx,78              ; nose down -> horizon rises on screen
@@h1:   cmp  byte ptr [KEYS+SC_DN],0
        je   @@h2
        mov  cx,122             ; nose up -> horizon sinks on screen
@@h2:   mov  ax,[horiz]
        cmp  ax,cx
        je   @@hd
        jl   @@hup
        sub  ax,3               ; ease down toward target
        cmp  ax,cx
        jge  @@hs
        mov  ax,cx
        jmp  @@hs
@@hup:  add  ax,3               ; ease up toward target
        cmp  ax,cx
        jle  @@hs
        mov  ax,cx
@@hs:   mov  [horiz],ax
@@hd:
        ; --- stall: below VSTALL the nose drops on its own ---
        mov  ax,[vel]
        cmp  ax,VSTALL
        jge  @@nst
        mov  bx,VSTALL
        sub  bx,ax
        mov  cl,3
        shr  bx,cl              ; sink = (VSTALL-vel)/8
        mov  ax,[camy]
        sub  ax,bx
        mov  [camy],ax
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
        ; --- wind drift (world space, constant breeze) ---
        mov  ax,[camx]
        add  ax,WINDX
        mov  [camx],ax
        mov  ax,[camz]
        add  ax,WINDZ
        mov  [camz],ax

        ; --- advance along heading at vel/16 units per tick ---
        mov  ax,[vel]
        mov  cl,4
        shr  ax,cl
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
        mov  word ptr [horiz],100   ; level pitch
@@w2:   cmp  byte ptr [KEYS+SC_SP],0
        jne  @@w2
        ret
