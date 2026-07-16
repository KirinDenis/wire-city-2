; ============================================================================
;  F_HUD.INC - readouts, warnings, the ROM-font text kit, palette
; ============================================================================
; ============================================================================
;  HUDTXT - speeds, states, warnings, the crash banner
; ============================================================================
HUDTXT: mov  byte ptr [tcol],9
        mov  si,offset MSGH
        mov  ax,4
        mov  bx,8
        call TXT
        mov  si,offset MSGH2
        mov  ax,14
        mov  bx,4
        call TXT
        mov  si,offset MSPD
        mov  ax,186
        mov  bx,8
        call TXT
        mov  ax,[vel]
        mov  bx,42
        mov  dx,186
        call TXTNUM
        mov  si,offset MALT
        mov  ax,186
        mov  bx,78
        call TXT
        mov  ax,[apy]
        mov  bx,112
        mov  dx,186
        call TXTNUM
        mov  si,offset MTHR
        mov  ax,186
        mov  bx,150
        call TXT
        mov  ax,[thr]
        mov  bx,184
        mov  dx,186
        call TXTNUM
        mov  si,offset MFLP
        mov  ax,186
        mov  bx,214
        call TXT
        mov  ax,[flap]
        mov  bx,240
        mov  dx,186
        call TXTNUM
        ; gear / brakes flags
        cmp  word ptr [gear],1
        jne  @@g0
        mov  si,offset MGDN
        mov  ax,186
        mov  bx,254
        call TXT
@@g0:   cmp  word ptr [brk],0
        je   @@b0
        mov  byte ptr [tcol],2
        mov  si,offset MBRK
        mov  ax,186
        mov  bx,288
        call TXT
@@b0:   ; wind readout
        mov  byte ptr [tcol],9
        mov  si,offset MWND
        mov  ax,176
        mov  bx,8
        call TXT
        mov  ax,[wind]
        or   ax,ax
        jns  @@wp
        neg  ax
@@wp:   mov  bx,50
        mov  dx,176
        call TXTNUM
        ; ---- warnings blink mid-screen ----
        mov  ax,[ltick]
        test ax,4
        jz   @@dead
        mov  byte ptr [tcol],2
        test word ptr [wrn],1
        jz   @@x1
        mov  si,offset MWST
        mov  ax,60
        mov  bx,136
        call TXT
@@x1:   test word ptr [wrn],2
        jz   @@x2
        mov  si,offset MWGR
        mov  ax,72
        mov  bx,140
        call TXT
@@x2:   test word ptr [wrn],4
        jz   @@x3
        mov  si,offset MWFA
        mov  ax,84
        mov  bx,124
        call TXT
@@x3:   test word ptr [wrn],8
        jz   @@dead
        mov  si,offset MWOF
        mov  ax,96
        mov  bx,128
        call TXT
@@dead: cmp  word ptr [dead],0
        je   @@x
        mov  byte ptr [tcol],2
        mov  si,offset MCRS
        mov  ax,90
        mov  bx,96
        call TXT
@@x:    ret

; ---- the AVIO kit ----------------------------------------------------------
ROW320: mov  bx,ax
        mov  cl,6
        shl  ax,cl
        mov  cl,8
        shl  bx,cl
        add  ax,bx
        mov  di,ax
        ret

TXTNUM: push bx
        push dx
        mov  di,offset NBUF+5
        mov  byte ptr [di],0
        mov  cx,10
@@d:    dec  di
        xor  dx,dx
        div  cx
        add  dl,'0'
        mov  [di],dl
        or   ax,ax
        jnz  @@d
        mov  si,di
        pop  ax
        pop  bx
        call TXT
        ret
NBUF    db 6 dup(0)

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
        jz   @@done
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
@@row:  lodsb
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
        loop @@row
        pop  di
        pop  ds
        pop  si
        add  di,8
        jmp  @@ch
@@done: pop  dx
        pop  es
        ret

WAITVR: mov  dx,3DAh
@@w1:   in   al,dx
        test al,8
        jnz  @@w1
@@w2:   in   al,dx
        test al,8
        jz   @@w2
        ret

; ---- data ------------------------------------------------------------------
PAL     db   1, 50,10, 4        ; warning red (unused yet)
        db   2, 63,42,10        ; amber warnings
        db   9, 63,52,20        ; readout
        db   7, 32,27,18        ; far ground: the checker tones merged
        db   8, 25,20,12        ; the ground grid (edges, unused now)
        db  24, 30,26,17        ; the darker checker square
        db  10, 34,29,19        ; the tan plain
        db  11, 16,16,18        ; runway asphalt
        db  12, 22,30,44        ; sky
        db  13, 26,26,28        ; taxiway
        db  14, 58,58,60        ; white markings
        db  15, 56,48,12        ; yellow taxi line
        db  16, 42,42,47        ; walls / mast / gear
        db  17, 52,52,56        ; roofs
        db  18, 34,34,39        ; wall shade
        db  19, 52,56,58        ; radar dish
        db  20, 46,46,50        ; aircraft body
        db  21, 30,30,33        ; aircraft shade
        db  22, 40,40,43        ; aircraft side
        db  23, 55,55,58        ; wings
        db 255
MSGH    db 'FLIGHT SCHOOL',0
MSGH2   db 'arrows +-thr F G B V R Sh-look O-cnpy',0
MSPD    db 'SPD=',0
MALT    db 'ALT=',0
MTHR    db 'THR=',0
MFLP    db 'FLP=',0
MGDN    db 'GEAR',0
MBRK    db 'BRK',0
MWND    db 'WIND=',0
MWST    db 'STALL',0
MWGR    db 'GEAR !',0
MWFA    db 'TOO FAST',0
MWOF    db 'OFF RWY',0
MCRS    db 'CRASH - PRESS R',0
