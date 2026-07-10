; ============================================================================
;  AVIO.COM - WIRE CITY engine example 04: the avionics
;
;  A flying instrument panel with no world attached: the artificial
;  horizon (a line rotated by roll and shifted by pitch - the same
;  quarter-table sine the game banks with), the speed and altitude
;  tapes with their red warning lines, the compass strip, and the
;  blinking STALL lamp. A toy flight model drives it: bank and the
;  heading starts walking (a banked turn!), climb and the speed bleeds,
;  stall and the nose drops on its own.
;
;  Arrows = stick, + / - = throttle, ESC quits. ~3 KB of .COM on the
;  same ENGINE\ modules as the game; text is the PC ROM font.
; ============================================================================
FOCAL   equ 220
NEARZ   equ 40

        .8086
        LOCALS
        JUMPS
CODE    SEGMENT
        ASSUME cs:CODE, ds:CODE, es:CODE, ss:CODE
        ORG  100h

START:  cld
        mov  ax,cs
        add  ax,1000h
        mov  [bufseg],ax
        mov  ax,0013h
        int  10h
        mov  si,offset PAL      ; a few DAC entries
@@p:    lodsb
        cmp  al,255
        je   @@pd
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
@@pd:
; ---- one frame -------------------------------------------------------------
@@frame:
        mov  ax,[bufseg]
        mov  es,ax
        xor  di,di
        xor  ax,ax
        mov  cx,32000
        rep  stosw
        ; ---- the toy flight model ----
        mov  ax,[roll]          ; banked turn: heading walks with the bank
        call SINQ
        mov  [rsin],ax
        mov  cl,6
        sar  ax,cl
        add  [hdg],ax
        and  word ptr [hdg],255
        mov  ax,[roll]
        add  ax,64
        call SINQ
        mov  [rcos],ax
        mov  ax,[pit]           ; climb trades speed for altitude
        call SINQ
        mov  [psin],ax
        mov  bx,[spd]
        imul bx
        mov  bx,4096
        idiv bx
        add  [alt],ax
        cmp  word ptr [alt],0
        jge  @@a1
        mov  word ptr [alt],0
@@a1:   mov  ax,[psin]
        mov  cl,5
        sar  ax,cl
        sub  [spd],ax
        cmp  word ptr [spd],600
        jle  @@s1
        mov  word ptr [spd],600
@@s1:   cmp  word ptr [spd],60
        jge  @@s2
        mov  word ptr [spd],60
@@s2:   cmp  word ptr [spd],120 ; the stall: the nose falls through
        jge  @@nst
        cmp  word ptr [pit],-40
        jle  @@nst
        dec  word ptr [pit]
@@nst:
        ; ---- the artificial horizon: rotate by roll, shift by pitch ----
        mov  ax,[psin]          ; pitch offset in pixels
        mov  bx,60
        imul bx
        mov  bx,256
        idiv bx
        mov  [pofs],ax
        mov  ax,[rcos]          ; endpoints: centre +/- 70 px along the
        mov  bx,70              ; rolled horizon direction
        imul bx
        mov  bx,256
        idiv bx
        mov  [hdx],ax
        mov  ax,[rsin]
        mov  bx,70
        imul bx
        mov  bx,256
        idiv bx
        mov  [hdy],ax
        mov  ax,160
        sub  ax,[hdx]
        mov  [sx0],ax
        mov  ax,90
        add  ax,[hdy]
        add  ax,[pofs]
        mov  [sy0],ax
        mov  ax,160
        add  ax,[hdx]
        mov  [sx1],ax
        mov  ax,90
        sub  ax,[hdy]
        add  ax,[pofs]
        mov  [sy1],ax
        mov  byte ptr [COLOR],1 ; HUD green
        call CLIPLINE
        jc   @@nhz
        call LINE
@@nhz:  mov  ax,88              ; the aircraft symbol never moves
        call ROW320
        mov  al,4
        mov  es:[di+160+640],al
        mov  es:[di+154+640],al
        mov  es:[di+155+640],al
        mov  es:[di+156+640],al
        mov  es:[di+164+640],al
        mov  es:[di+165+640],al
        mov  es:[di+166+640],al
        ; ---- the speed tape (left): 1 unit = 1/2 px, red stall line ----
        mov  ax,[spd]
        sub  ax,80
        mov  cl,4
        sar  ax,cl              ; first tick value / 16
        inc  ax
        mov  bx,16
        imul bx                 ; ...rounded up to a multiple of 16
@@st:   mov  bx,[spd]
        add  bx,80
        cmp  ax,bx
        jg   @@std
        push ax
        sub  ax,[spd]
        sar  ax,1
        mov  bx,90
        sub  bx,ax              ; tick row
        mov  ax,bx
        call ROW320
        add  di,24
        mov  al,4
        mov  cx,4
        pop  bx
        push bx
        test bx,63              ; every 4th tick is a major with a number
        jnz  @@stm
        mov  cx,8
@@stm:  rep  stosb
        pop  ax
        add  ax,16
        jmp  @@st
@@std:  mov  ax,120             ; the red stall line
        sub  ax,[spd]
        sar  ax,1
        mov  bx,90
        sub  bx,ax
        cmp  bx,20
        jl   @@nsl
        cmp  bx,180
        jg   @@nsl
        mov  ax,bx
        call ROW320
        add  di,20
        mov  al,3
        mov  cx,12
        rep  stosb
@@nsl:  mov  byte ptr [tcol],1  ; the readout
        mov  si,offset MSGSPD
        mov  ax,30
        mov  bx,8
        call TXT
        mov  ax,[spd]
        mov  bx,8
        mov  dx,40
        call TXTNUM
        ; ---- the altitude tape (right): 1 unit = 1/10 px ----
        mov  ax,[alt]
        mov  bx,100
        cwd
        idiv bx
        inc  ax
        imul bx                 ; first 100-multiple above alt-?? window
        sub  ax,700
@@at:   mov  bx,[alt]
        add  bx,700
        cmp  ax,bx
        jg   @@atd
        cmp  ax,0
        jl   @@atn
        push ax
        sub  ax,[alt]
        cwd
        mov  bx,10
        idiv bx
        mov  bx,90
        sub  bx,ax
        cmp  bx,20
        jl   @@atp
        cmp  bx,180
        jg   @@atp
        mov  ax,bx
        call ROW320
        add  di,288
        mov  al,4
        mov  cx,4
        rep  stosb
@@atp:  pop  ax
@@atn:  add  ax,100
        jmp  @@at
@@atd:  mov  byte ptr [tcol],1
        mov  si,offset MSGALT
        mov  ax,30
        mov  bx,270
        call TXT
        mov  ax,[alt]
        mov  bx,270
        mov  dx,40
        call TXTNUM
        ; ---- the compass strip (top), heading-up like the game ----
        mov  ax,[hdg]
        and  ax,7
        mov  bx,ax              ; sub-tick scroll
        mov  cx,-10             ; 21 ticks across
@@cp:   push cx
        mov  ax,cx
        mov  dx,8
        imul dx
        sub  ax,bx
        add  ax,ax
        add  ax,160             ; tick x
        cmp  ax,60
        jl   @@cpn
        cmp  ax,260
        jg   @@cpn
        push ax
        push bx
        mov  ax,10
        call ROW320
        pop  bx
        pop  ax
        add  di,ax
        mov  al,4
        mov  es:[di],al
        mov  es:[di+320],al
@@cpn:  pop  cx
        inc  cx
        cmp  cx,11
        jl   @@cp
        push bx                 ; the lubber line
        mov  ax,14
        call ROW320
        pop  bx
        mov  al,3
        mov  es:[di+160],al
        mov  es:[di+160+320],al
        mov  byte ptr [tcol],2
        mov  ax,[hdg]           ; heading readout 0..255
        mov  bx,152
        mov  dx,22
        call TXTNUM
        ; ---- STALL lamp: blinking red when slow ----
        cmp  word ptr [spd],120
        jge  @@nlmp
        inc  word ptr [blk]
        test word ptr [blk],8
        jz   @@nlmp
        mov  byte ptr [tcol],3
        mov  si,offset MSGSTL
        mov  ax,120
        mov  bx,140
        call TXT
@@nlmp:
        ; ---- vsync, blit, keys ----
        call WAITVR
        push ds
        mov  ax,0A000h
        mov  es,ax
        mov  ds,[bufseg]
        xor  si,si
        xor  di,di
        mov  cx,32000
        rep  movsw
        pop  ds
        mov  ah,1
        int  16h
        jz   @@j
        xor  ah,ah
        int  16h
        cmp  al,27
        je   @@quit
        cmp  al,'+'
        jne  @@k1
        add  word ptr [spd],8
@@k1:   cmp  al,'-'
        jne  @@k2
        sub  word ptr [spd],8
@@k2:   or   al,al
        jnz  @@j
        cmp  ah,4Bh             ; left
        jne  @@k3
        sub  word ptr [roll],4
@@k3:   cmp  ah,4Dh             ; right
        jne  @@k4
        add  word ptr [roll],4
@@k4:   cmp  ah,50h             ; down = pull
        jne  @@k5
        inc  word ptr [pit]
        cmp  word ptr [pit],48
        jle  @@k5
        mov  word ptr [pit],48
@@k5:   cmp  ah,48h             ; up = push
        jne  @@j
        dec  word ptr [pit]
        cmp  word ptr [pit],-48
        jge  @@j
        mov  word ptr [pit],-48
@@j:    and  word ptr [roll],255
        jmp  @@frame
@@quit: mov  ax,0003h
        int  10h
        mov  ax,4C00h
        int  21h

; ---- ROW320: AX = row -> DI = row*320 (clobbers BX,CL) ---------------------
ROW320: mov  bx,ax
        mov  cl,6
        shl  ax,cl              ; row*64
        mov  cl,8
        shl  bx,cl              ; row*256
        add  ax,bx
        mov  di,ax
        ret

; ---- TXTNUM: AX unsigned -> digits at (BX,DX) via TXT ------------------------
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
        pop  ax                 ; row
        pop  bx                 ; x
        call TXT
        ret
NBUF    db 6 dup(0)

; ---- TXT: ASCIIZ at SI -> back buffer at (BX,AX), colour [tcol] -----------
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
PAL     db   1, 16,52,24        ; HUD green
        db   2, 63,42,10        ; amber
        db   3, 60,12, 8        ; warning red
        db   4, 44,46,48        ; tick grey
        db 255
MSGSPD  db 'SPD',0
MSGALT  db 'ALT',0
MSGSTL  db 'STALL',0
pit     dw 0                    ; the toy flight state
spd     dw 300
alt     dw 1500
hdg     dw 0
blk     dw 0                    ; lamp blink counter
pofs    dw 0
hdx     dw 0
hdy     dw 0
tcol    db 1
bufseg  dw 0
; ---- engine contract (E_M3D + E_RAST; see the module headers) --------------
heading dw 0
pitch   dw 0
roll    dw 0
hsin    dw 0
hcos    dw 256
rsin    dw 0
rcos    dw 256
psin    dw 0
pcos    dw 256
horiz   dw 100
swayx   dw 0
swayy   dw 0
wdx     dw 0
wdz     dw 0
rcx     dw 0
rcz     dw 0
rddx    dw 0
rddy    dw 0
rsxo    dw 0
ptmp    dw 0
IX      dw 4 dup(0)
IY      dw 4 dup(0)
IZ      dw 4 dup(0)
OX      dw 6 dup(0)
OY      dw 6 dup(0)
OZ      dw 6 dup(0)
PX      dw 6 dup(0)
PY      dw 6 dup(0)
NPOLY   dw 0
oc      dw 0
ci      dw 0
ni      dw 0
pk      dw 0
pminy   dw 0
pmaxy   dw 0
scy     dw 0
scymax  dw 0
scxl    dw 0
scxr    dw 0
tnum    dw 0
tden    dw 0
cdx     dw 0
cdy     dw 0
nx      dw 0
ny      dw 0
oc0     db 0
oc1     db 0
ocsel   db 0
lx      dw 0
ly      dw 0
ldx     dw 0
ldy     dw 0
lsx     dw 0
lsy     dw 0
lerr    dw 0
sx0     dw 0
sy0     dw 0
sx1     dw 0
sy1     dw 0
COLOR   db 0
SINT    dw 0,6,13,19,25,31,38,44,50,56,62,68,74,80,86,92,98,104,109,115
        dw 121,126,132,137,142,147,153,157,162,167,172,177,181,185,190,194
        dw 198,202,206,209,213,216,220,223,226,229,231,234,237,239,241,243
        dw 245,247,248,250,251,252,253,254,255,255,256,256,256

        INCLUDE ..\ENGINE\E_M3D.INC
        INCLUDE ..\ENGINE\E_RAST.INC

CODE    ENDS
        END START
