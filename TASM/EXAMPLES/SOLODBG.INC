; ============================================================================
;  SOLODBG.INC - SOLO's umbilical to \Debug\FlyDbg.cs (COM1 -> TCP).
;  Adapted from GAMES\TRAINER\SRC\F_DEBUG.INC. Every tick: drain remote
;  key events (bit7 = press, low 7 = scancode) into the KEYS table,
;  apply held keys to the controls, then send one telemetry line:
;    T tick v16 alt16 alpha8 l8v vs64 T4 air state Tt4 posm cfg vsac
;      rxn last pkn
;  (FlyDbg's columns are named for the TRAINER; the MAPPING here is:
;   vel=v16, alt=alt16, pit=alpha8, rol=LIFT l8v, hdg=vs64, thr=T4,
;   wrn=air, dead=state, apx=Tt4, apz=posm, chf=gear+2*flaps+4*brk.)
;  Pokes (FlyDbg names): pit->alpha8, vel->v16, thr->Tt4, apy->h6,
;  apz->posm; the rest land in a scratch word. Self-unplugging: no
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
        jz   @@apply
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
        ; ---- apply the held remote keys to the controls ----
@@apply:
        cmp  byte ptr [KEYS+48h],0 ; UP arrow = stick forward
        je   @@k1
        sub  word ptr [alpha8],40
        cmp  word ptr [alpha8],1024
        jge  @@k1
        mov  word ptr [alpha8],1024
@@k1:   cmp  byte ptr [KEYS+50h],0 ; DOWN arrow = stick back
        je   @@k2
        add  word ptr [alpha8],40
        cmp  word ptr [alpha8],4352
        jle  @@k2
        mov  word ptr [alpha8],4352
@@k2:   cmp  byte ptr [KEYS+0Dh],0 ; PLUS = throttle up
        je   @@k3
        add  word ptr [Tt4],300
        cmp  word ptr [Tt4],18000
        jle  @@k3
        mov  word ptr [Tt4],18000
@@k3:   cmp  byte ptr [KEYS+0Ch],0 ; MINUS = throttle back
        je   @@k4
        sub  word ptr [Tt4],300
        cmp  word ptr [Tt4],250
        jge  @@k4
        mov  word ptr [Tt4],250
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
        je   @@k7
        mov  [PREVB],al
        or   al,al
        jz   @@k7
        xor  byte ptr [brk],1
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
@@k8:
        ; ---- one telemetry line ----
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
        mov  ax,[l8v]
        call DNUM
        mov  ax,[vs64]
        call DNUM
        mov  ax,[T4]
        call DNUM
        mov  al,[air]
        xor  ah,ah
        call DNUM
        mov  al,[state]
        xor  ah,ah
        call DNUM
        mov  ax,[Tt4]
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
POKETAB dw dscr,h6,posm,dscr,alpha8,dscr,v16,Tt4,dscr,dscr,dscr
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
PREVF   db 0
PREVB   db 0
PREVS   db 0
KEYS    db 128 dup(0)
DBUF    db 160 dup(0)
