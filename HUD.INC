; HUD.INC - part of WIRE CITY (included from CITY.ASM)
; ============================================================================
;  HUD (BIOS text overlay on top of the frame)
; ============================================================================
HUD:    mov  byte ptr [HCOL],8
        mov  ah,02h
        mov  bh,0
        mov  dh,0
        mov  dl,0
        int  10h
        mov  si,offset MSGTITLE
        call PRSTR
        mov  ah,02h
        mov  bh,0
        mov  dh,0
        mov  dl,28
        int  10h
        mov  si,offset MSGALT
        call PRSTR
        mov  ax,[camy]
        call PRNUM
        mov  ah,02h
        mov  bh,0
        mov  dh,24
        mov  dl,0
        int  10h
        mov  si,offset MSGHDG
        call PRSTR
        mov  ax,[heading]
        call PRNUM
        mov  si,offset MSGSPD   ; airspeed (vel units, jet-style number)
        call PRSTR
        mov  ax,[vel]
        call PRNUM
        mov  si,offset MSGFUE   ; fuel as 0..100 percent
        call PRSTR
        mov  ax,[fuel]
        xor  dx,dx
        mov  bx,60
        div  bx
        call PRNUM
        mov  si,offset MSGTHR   ; throttle as 0..100 percent
        call PRSTR
        mov  ax,[throt]
        mov  bx,100
        imul bx
        mov  bx,64
        idiv bx
        call PRNUM
        cmp  byte ptr [abon],0  ; '+' marks a lit afterburner
        je   @@nab
        mov  al,'+'
        call PRCH
@@nab:
        ; real-time seconds (BIOS tick, 18.2 Hz) - compare against a stopwatch
        mov  ah,02h
        mov  bh,0
        mov  dh,0
        mov  dl,15
        int  10h
        mov  si,offset MSGT
        call PRSTR
        push es
        mov  ax,40h
        mov  es,ax
        mov  ax,es:[6Ch]       ; BIOS tick low word (18.2 Hz)
        pop  es
        xor  dx,dx
        mov  bx,18
        div  bx                ; ax ~= seconds
        call PRNUM
        ret

PRSTR:  lodsb
        test al,al
        jz   @@e
        call PRCH
        jmp  PRSTR
@@e:    ret

PRCH:   mov  ah,0Eh
        mov  bl,[HCOL]
        mov  bh,0
        int  10h
        ret

PRNUM:  mov  cx,0
        mov  bx,10
@@d:    xor  dx,dx
        div  bx
        push dx
        inc  cx
        test ax,ax
        jnz  @@d
@@p:    pop  dx
        add  dl,'0'
        mov  al,dl
        call PRCH
        loop @@p
        ret
