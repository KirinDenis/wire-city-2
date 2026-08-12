; ============================================================================
;  N_DEBUG.INC - NEWTON's umbilical to \Debug\FlyDbg.cs (COM1 -> TCP).
;  Forked from EXAMPLES\SOLODBG.INC (itself out of TRAINER's F_DEBUG).
;  It grows with the airframe: every new axis gets a column here the
;  same day it gets a key, or it cannot be flown from a scenario.
;  Every tick: drain remote
;  key events (bit7 = press, low 7 = scancode) into the KEYS table,
;  apply held keys to the controls, then send one telemetry line:
;    T tick v16 alt16 alpha8 l8v vs64 T4 air state Tt4 posm cfg vsac
;      rxn last pkn
;  (FlyDbg's columns are named for the TRAINER; the MAPPING here is:
;   vel=v16, alt=alt16, pit=alpha8, rol=ROLL 0..255, hdg=HEADING
;   0..255, thr=T4, wrn=air, dead=state, apx=PX east metres, apz=posm
;   north metres, chf=gear+2*flaps+4*brk.)
;  Pokes (FlyDbg names): pit->alpha8, vel->v16, thr->Tt4, apy->h6,
;  apz->posm, apx->px, hdg->hdg, rol->roll; the rest land in a
;  scratch word. Self-unplugging: no
;  UART, or a stuck THR line, switches the channel off for good.
; ============================================================================
UARTB   equ 3F8h

DBGINIT:
        mov  dx,UARTB+7         ; scratch probe: is anyone there?
        mov  al,5Ah
        out  dx,al
        in   al,dx
        cmp  al,5Ah
        je   @@have
        mov  byte ptr [dbgon],0
        ret
@@have: mov  byte ptr [dbgon],1
        mov  dx,UARTB+3
        mov  al,80h             ; DLAB on
        out  dx,al
        mov  dx,UARTB
        mov  al,1               ; divisor 1 = 115200
        out  dx,al
        mov  dx,UARTB+1
        xor  al,al
        out  dx,al
        mov  dx,UARTB+3
        mov  al,03h             ; 8N1, DLAB off
        out  dx,al
        mov  dx,UARTB+1
        xor  al,al              ; we poll, no interrupts
        out  dx,al
        mov  dx,UARTB+4
        mov  al,03h             ; DTR+RTS up
        out  dx,al
        ret

DBGTICK:
        cmp  byte ptr [dbgon],0
        jne  @@on
        ret
@@on:   inc  word ptr [dtick]
        ; ---- drain the remote keyboard / pokes ----
@@rx:   mov  dx,UARTB+5
        in   al,dx
        test al,1
        jz   @@tele
        mov  dx,UARTB
        in   al,dx
        inc  word ptr [drxn]
        mov  ah,al
        xor  ah,ah
        mov  [dlast],ax
        cmp  byte ptr [dstate],0
        jne  @@pk
        cmp  al,7Fh             ; escape: a state poke follows
        jne  @@key
        mov  byte ptr [dstate],1
        jmp  @@rx
@@key:  mov  ah,al
        and  al,7Fh
        mov  bl,al
        xor  bh,bh
        mov  al,1
        test ah,80h
        jnz  @@st
        xor  al,al
@@st:   mov  [KEYS+bx],al
        jmp  @@rx
@@pk:   cmp  al,7Fh
        jne  @@pk1
        mov  byte ptr [dstate],1
        jmp  @@rx
@@pk1:  mov  ah,al              ; nibbles ride as 40h..4Fh
        and  ah,0F0h
        cmp  ah,40h
        jne  @@pkab
        and  ax,000Fh
        mov  bl,[dstate]
        inc  byte ptr [dstate]
        cmp  bl,1
        je   @@pi1
        cmp  bl,2
        je   @@pi2
        cmp  bl,3
        jne  @@pv2
        mov  [dpval],ax
        jmp  @@rx
@@pv2:  mov  cl,4
        shl  word ptr [dpval],cl
        or   [dpval],ax
        cmp  bl,6
        jb   @@rx
        mov  bl,[dpidx]
        xor  bh,bh
        cmp  bl,11
        jae  @@pkx
        add  bx,bx
        mov  si,[POKETAB+bx]
        mov  ax,[dpval]
        mov  [si],ax
@@pkx:  inc  word ptr [dpkn]
        mov  byte ptr [dstate],0
        jmp  @@rx
@@pi1:  mov  [dpidx],al
        jmp  @@rx
@@pi2:  mov  cl,4
        shl  byte ptr [dpidx],cl
        or   [dpidx],al
        jmp  @@rx
@@pkab: mov  byte ptr [dstate],0
        jmp  @@key
@@tele: jmp  TELE

; ---- KEYAPP: the held keys become control movement, ONCE PER TICK ---------
; Both keyboards write the same KEYS table - the local INT 9 handler and
; the umbilical - so a scenario and a pair of hands fly the aeroplane
; through exactly the same code. This is also why the controls stopped
; jerking: BIOS key EVENTS arrive at the typematic rate, with a pause
; before the first repeat; key STATE moves the stick every 55 ms.
KEYAPP:
        cmp  byte ptr [amode],0    ; AUTO: the arrows steer the PATH -
        je   @@k1r                 ; up means UP, the way a player who
        cmp  byte ptr [air],0      ; never met an AoA expects
        je   @@k1r
        mov  word ptr [gboost],0
        mov  ax,[roll]             ; banked past ~17 deg the up/down
        cmp  ax,128                ; keys change MEANING: they are the
        jb   @@kaf                 ; G - pull to TIGHTEN the turn,
        neg  ax                    ; push to unload it
        and  ax,255
@@kaf:  cmp  ax,12
        jg   @@kab
        test word ptr [tcnt],1     ; the command walks HALF-speed and
        jnz  @@ka2                 ; only to +-17 deg: the old +-45 at
        cmp  byte ptr [KEYS+48h],0 ; full tick rate hit the ceiling in
        je   @@ka1                 ; two taps and the jet "went nose-up
        cmp  word ptr [gtgt],-12   ; and would not come down"
        jle  @@ka1
        dec  word ptr [gtgt]
@@ka1:  cmp  byte ptr [KEYS+50h],0
        je   @@ka2
        cmp  word ptr [gtgt],12
        jge  @@ka2
        inc  word ptr [gtgt]
@@ka2:  jmp  @@k1a
@@kab:  cmp  byte ptr [KEYS+50h],0
        je   @@kac
        mov  word ptr [gboost],1400
@@kac:  cmp  byte ptr [KEYS+48h],0
        je   @@ka2
        mov  word ptr [gboost],-1000
        jmp  @@ka2
@@k1r:  cmp  byte ptr [KEYS+48h],0 ; UP arrow = stick forward - all the
        je   @@k1                  ; way into NEGATIVE alpha: a nose
        sub  word ptr [alpha8],80  ; that can actually be pushed down
        cmp  word ptr [alpha8],-1536
        jge  @@k1
        mov  word ptr [alpha8],-1536
@@k1:   cmp  byte ptr [KEYS+50h],0 ; DOWN arrow = stick back
        je   @@k1t
        add  word ptr [alpha8],80
        cmp  word ptr [alpha8],4352
        jle  @@k1a
        mov  word ptr [alpha8],4352
        jmp  @@k1a
@@k1t:  cmp  byte ptr [KEYS+48h],0 ; hands off? STICK-FREE STABILITY:
        jne  @@k1a                 ; alpha eases home to trim - and the
        cmp  byte ptr [air],0      ; trim RISES with the bank, so a
        je   @@k1a                 ; banked jet presses CANOPY-ward on
        mov  ax,[roll]             ; its own, the way pilots expect a
        call TSIN                  ; turn to feel. Full coordination is
        or   ax,ax                 ; still the stick's job; this is the
        jns  @@k1u                 ; airframe meeting it halfway
        neg  ax
@@k1u:  mov  cx,5
        imul cx                    ; trim = 2400 + |sin(roll)|*5,
        add  ax,2400               ; up to 3680 at the knife edge
        mov  bx,ax
        mov  ax,[alpha8]
        cmp  ax,bx
        je   @@k1a
        jg   @@k1d
        add  ax,12
        cmp  ax,bx
        jle  @@k1s
        mov  ax,bx
        jmp  @@k1s
@@k1d:  sub  ax,12
        cmp  ax,bx
        jge  @@k1s
        mov  ax,bx
@@k1s:  mov  [alpha8],ax
@@k1a:  cmp  byte ptr [air],0   ; on the wheels the arrows STEER: wings
        jne  @@k1f              ; pinned level, the nosewheel walks the
        mov  word ptr [roll],0  ; heading (needs a little rolling speed)
        cmp  word ptr [v16],32
        jb   @@k2
        cmp  byte ptr [KEYS+4Bh],0
        je   @@k1c
        sub  word ptr [hdgf],44
        jnc  @@k1c
        add  word ptr [hdgf],256
        dec  word ptr [hdg]
        and  word ptr [hdg],255
@@k1c:  cmp  byte ptr [KEYS+4Dh],0
        je   @@k1z
        add  word ptr [hdgf],44
        cmp  word ptr [hdgf],256
        jb   @@k1z
        sub  word ptr [hdgf],256
        inc  word ptr [hdg]
        and  word ptr [hdg],255
        jmp  @@k1z
@@k1f:  mov  cx,7                  ; RAW rolls like a fighter, 200 deg/s;
        cmp  byte ptr [amode],0    ; AUTO rolls at 115 - "?????????????? ??????????"
        je   @@k1g                 ; was the honest verdict on handing a
        mov  cx,4                  ; casual player the real rate
@@k1g:  cmp  byte ptr [KEYS+4Bh],0 ; LEFT arrow = aileron left
        je   @@k1b
        sub  [roll],cx
        and  word ptr [roll],255
        mov  word ptr [rlvt],0
@@k1b:  cmp  byte ptr [KEYS+4Dh],0 ; RIGHT arrow = aileron right
        je   @@k1w
        add  [roll],cx
        and  word ptr [roll],255
        mov  word ptr [rlvt],0
        jmp  @@k1z
@@k1w:  cmp  byte ptr [amode],0    ; AUTO with the ailerons idle levels
        je   @@k1z                 ; the wings - but only after a GRACE
        cmp  byte ptr [KEYS+4Bh],0 ; second, so a held bank is a turn
        jne  @@k1z                 ; and a released one is a wish to fly
        inc  word ptr [rlvt]       ; straight (instantly righting wings
        cmp  word ptr [rlvt],18    ; made the jet feel possessed)
        jl   @@k1z
        mov  ax,[roll]
        or   ax,ax
        jz   @@k1z
        cmp  ax,128
        ja   @@k1v
        sub  ax,2
        jns  @@k1u2
        xor  ax,ax
@@k1u2: cmp  ax,2
        ja   @@k1x
        xor  ax,ax
        jmp  @@k1x
@@k1v:  add  ax,2
        cmp  ax,254
        jb   @@k1x
        xor  ax,ax
@@k1x:  mov  [roll],ax
@@k1z:  xor  cx,cx                 ; the rudder: Z / top-row 1 / numpad
        mov  al,[KEYS+2Ch]         ; 1 or 7 left, C / 3 / numpad 3 or 9
        or   al,[KEYS+02h]         ; right - air and wheels both
        or   al,[KEYS+4Fh]
        or   al,[KEYS+47h]
        or   al,al
        jz   @@k1y
        sub  cx,96
@@k1y:  mov  al,[KEYS+2Eh]
        or   al,[KEYS+04h]
        or   al,[KEYS+51h]
        or   al,[KEYS+49h]
        or   al,al
        jz   @@k1x2
        add  cx,96
@@k1x2: jcxz @@k2
        push cx                    ; OWL FLY's lesson, re-learned the
        mov  ax,[roll]             ; hard way: yaw lives on the PLANE's
        add  ax,64                 ; vertical axis. Wings level it walks
        call TSIN                  ; the heading; on the knife edge the
        pop  cx                    ; TOP rudder raises the NOSE -
        push cx                    ; heading by cos, path by minus sin
        imul cx
        mov  cx,256
        idiv cx
        add  ax,[hdgf]
        mov  bx,ax
        mov  cl,8
        sar  bx,cl
        add  [hdg],bx
        and  word ptr [hdg],255
        and  ax,255
        mov  [hdgf],ax
        mov  ax,[roll]
        call TSIN
        pop  cx
        imul cx
        mov  cx,256
        idiv cx
        neg  ax                    ; top rudder raises the nose
        add  ax,[gamf]
        mov  bx,ax
        mov  cl,8
        sar  bx,cl
        add  [gam],bx
        and  word ptr [gam],255
        and  ax,255
        mov  [gamf],ax
@@k2:   cmp  byte ptr [KEYS+0Dh],0 ; PLUS = throttle up
        je   @@k3
        mov  al,[KEYS+2Ah]         ; the manual's Shift+: the mil stop,
        or   al,[KEYS+36h]         ; at once
        jz   @@k2a
        mov  word ptr [Tt4],30000
        mov  byte ptr [abon],0
        jmp  @@k3
@@k2a:  mov  byte ptr [abon],0     ; touching the lever leaves the burner
        add  word ptr [Tt4],300
        cmp  word ptr [Tt4],30000
        jle  @@k3
        mov  word ptr [Tt4],30000
@@k3:   cmp  byte ptr [KEYS+0Ch],0 ; MINUS = throttle back
        je   @@k4
        mov  al,[KEYS+2Ah]
        or   al,[KEYS+36h]
        jz   @@k3a
        mov  word ptr [Tt4],250    ; Shift-: chop it to idle
        mov  byte ptr [abon],0
        jmp  @@k4
@@k3a:  mov  byte ptr [abon],0
        sub  word ptr [Tt4],300
        cmp  word ptr [Tt4],250
        jge  @@k3b
        mov  word ptr [Tt4],250
@@k3b:  cmp  word ptr [Tt4],30000  ; falling out of the burner range
        jle  @@k4
        mov  word ptr [Tt4],30000
@@k4:   mov  al,[KEYS+26h]      ; L = gear (edge)
        cmp  al,[PREVL]
        je   @@k5
        mov  [PREVL],al
        or   al,al
        jz   @@k5
        xor  byte ptr [gear],1
        mov  word ptr [bamp],22
        call KNOCK
@@k5:   mov  al,[KEYS+21h]      ; F = flaps (edge)
        cmp  al,[PREVF]
        je   @@k6
        mov  [PREVF],al
        or   al,al
        jz   @@k6
        xor  byte ptr [flaps],1
@@k6:   mov  al,[KEYS+30h]      ; B = brakes (edge)
        cmp  al,[PREVB]
        je   @@k6p
        mov  [PREVB],al
        or   al,al
        jz   @@k6p
        xor  byte ptr [brk],1
@@k6p:  mov  al,[KEYS+19h]      ; P = Pilot Automatic (edge): the
        cmp  al,[PREVP]         ; manual's own key for exactly this.
        je   @@k6a              ; Toggling IN is bumpless - the target
        mov  [PREVP],al         ; becomes wherever the path already is
        or   al,al
        jz   @@k6a
        xor  byte ptr [amode],1
        cmp  byte ptr [amode],0
        je   @@k6a
        mov  ax,[gam]
        cmp  ax,128
        jb   @@k6q
        sub  ax,256
@@k6q:  cmp  ax,-32
        jge  @@k6r
        mov  ax,-32
@@k6r:  cmp  ax,32
        jle  @@k6s
        mov  ax,32
@@k6s:  mov  [gtgt],ax
@@k6a:  mov  al,[KEYS+1Eh]      ; A = the afterburner (edge): the lever
        cmp  al,[PREVA]         ; slams to the burner stop and the
        je   @@k7               ; spool does the rest - or back to the
        mov  [PREVA],al         ; military gate when it goes out
        or   al,al
        jz   @@k7
        xor  byte ptr [abon],1
        cmp  byte ptr [abon],0
        je   @@abo
        mov  word ptr [Tt4],32500
        jmp  @@k7
@@abo:  mov  word ptr [Tt4],30000
@@k7:   mov  al,[KEYS+39h]      ; SPACE = start / again (edge)
        cmp  al,[PREVS]
        je   @@k8
        mov  [PREVS],al
        or   al,al
        jz   @@k8
        mov  ah,[state]
        or   ah,ah
        jz   @@k7a
        cmp  ah,6
        jne  @@k8
@@k7a:  call RESETF
@@k8:   ret

; ---- TELE: one telemetry line down the umbilical --------------------------
TELE:
        cmp  byte ptr [dbgon],0
        jne  @@go
        ret
@@go:
        push es
        mov  ax,cs
        mov  es,ax
        mov  di,offset DBUF
        mov  al,'T'
        stosb
        mov  ax,[dtick]
        call DNUM
        mov  ax,[v16]
        call DNUM
        mov  ax,[alt16]
        call DNUM
        mov  ax,[alpha8]
        call DNUM
        mov  ax,[roll]          ; the 'rol' column is the BANK now - the
        call DNUM               ; lift it used to carry reads off the G
        mov  ax,[hdg]           ; and 'hdg' is finally a real HEADING;
        call DNUM               ; sink lives on in the alt derivative
        mov  ax,[T4]
        call DNUM
        mov  al,[air]
        xor  ah,ah
        call DNUM
        mov  al,[state]
        xor  ah,ah
        call DNUM
        mov  ax,[px]
        call DNUM
        mov  ax,[posm]
        call DNUM
        mov  al,[gear]          ; cfg = gear + 2*flaps + 4*brk
        xor  ah,ah
        mov  bl,[flaps]
        add  bl,bl
        add  al,bl
        mov  bl,[brk]
        add  bl,bl
        add  bl,bl
        add  al,bl
        call DNUM
        mov  ax,[dvsdbg]
        call DNUM
        mov  ax,[drxn]
        call DNUM
        mov  ax,[dlast]
        call DNUM
        mov  ax,[dpkn]
        call DNUM
        mov  al,13
        stosb
        mov  al,10
        stosb
        mov  si,offset DBUF
@@s1:   cmp  si,di
        jae  @@done
        mov  cx,4000            ; THR guard: a dead line unplugs, not hangs
@@s2:   mov  dx,UARTB+5
        in   al,dx
        test al,20h
        jnz  @@s3
        loop @@s2
        mov  byte ptr [dbgon],0
        pop  es
        ret
@@s3:   lodsb
        mov  dx,UARTB
        out  dx,al
        jmp  @@s1
@@done: pop  es
        ret

; DNUM - AX signed -> ' ' + decimal digits at ES:DI
DNUM:   push ax
        mov  al,' '
        stosb
        pop  ax
        or   ax,ax
        jns  @@pos
        push ax
        mov  al,'-'
        stosb
        pop  ax
        neg  ax
@@pos:  xor  cx,cx
        mov  bx,10
@@div:  xor  dx,dx
        div  bx
        push dx
        inc  cx
        or   ax,ax
        jnz  @@div
@@out:  pop  ax
        add  al,'0'
        stosb
        loop @@out
        ret

; FlyDbg poke order: apx apy apz hdg pit rol vel thr chdgf wind slow
; 'rol' pokes the BANK: holding an aileron key overshoots any target by
; the round trip (~10 ticks = 40 degrees), so a screenshot at an exact
; angle has to be set, not flown.
POKETAB dw px,h6,posm,hdg,alpha8,roll,v16,Tt4,gam,dscr,dscr
dscr    dw 0                    ; the scratch bucket for unused pokes
dvsdbg  dw 0                    ; instrument: the raw sink command
drxn    dw 0
dlast   dw 0
dpkn    dw 0
dstate  db 0
dpidx   db 0
dpval   dw 0
dbgon   db 0
dtick   dw 0
PREVL   db 0
PREVA   db 0
PREVP   db 0
PREVF   db 0
PREVB   db 0
PREVS   db 0
KEYS    db 128 dup(0)
DBUF    db 160 dup(0)

