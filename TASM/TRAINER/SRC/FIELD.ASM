; ============================================================================
;  FIELD.COM - THE FLIGHT SCHOOL (GAMES\TRAINER)
;
;  Grown out of engine example 07 into its own game. The airfield is
;  laid out to the real rules, the physics knows VR and the stall, and
;  the aircraft is no longer hard-wired: PLANE3D draws whatever model
;  PLANE1.DAT holds - Blender -> OBJ -> \TOOLS\OBJ2DAT.COM -> DAT,
;  loaded at start-up (see F_PLANE.INC).
;
;  Sources: FIELD.ASM   the frame loop, keys, state
;           F_PHYS.INC  flight model, ground handling, warnings
;           F_WORLD.INC runway, taxiway, hangars, the radar
;           F_PLANE.INC the model loader and the aircraft renderer
;           F_HUD.INC   readouts, warnings, the text kit, palette
;
;  Keys: arrows = stick / nose-wheel     + - = throttle
;        F flaps (0/1/2)   G gear   B brakes   Z/C rudder
;        V view (chase / first person)  R reset  ESC quit
; ============================================================================
FOCAL   equ 220
NEARZ   equ 40
; keyboard scancodes for the INT 9 key-state table (the OWLFLY scheme)
SC_ESC  equ 01h
SC_MIN  equ 0Ch
SC_EQ   equ 0Dh
SC_R    equ 13h
SC_W    equ 11h
SC_S    equ 1Fh
SC_O    equ 18h
SC_F    equ 21h
SC_G    equ 22h
SC_Z    equ 2Ch
SC_C    equ 2Eh
SC_V    equ 2Fh
SC_B    equ 30h
SC_LSH  equ 2Ah
SC_RSH  equ 36h
SC_UP   equ 48h
SC_NPM  equ 4Ah
SC_LF   equ 4Bh
SC_RT   equ 4Dh
SC_NPP  equ 4Eh
SC_DN   equ 50h

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
        mov  ax,3509h           ; take INT 9: we read key STATE, not the
        int  21h                ;  BIOS buffer - held keys act every tick
        mov  [oldoff],bx
        mov  [oldseg],es
        mov  ax,cs
        mov  es,ax
        mov  dx,offset KBINT
        mov  ax,2509h
        int  21h
        call DBGINIT            ; the debug umbilical, if anyone listens
        push es
        mov  ax,40h
        mov  es,ax
        mov  ax,es:[6Ch]
        pop  es
        or   ax,1
        mov  [rseed],ax
        call LOADMDL
        mov  ax,0013h
        int  10h
        mov  si,offset PAL
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
@@pd:   call MPALS              ; model palettes ride in their DATs
        call RESET
        push es
        mov  ax,40h
        mov  es,ax
        mov  ax,es:[6Ch]
        pop  es
        mov  [ltick],ax

; ============================ the frame ====================================
@@frame:
        push es
        mov  ax,40h
        mov  es,ax
        mov  ax,es:[6Ch]
        pop  es
        mov  bx,ax
        sub  ax,[ltick]
        mov  [ltick],bx
        cmp  ax,4
        jle  @@d1
        mov  ax,4
@@d1:   cmp  word ptr [dbgslow],0
        je   @@d1a
        mov  ax,1               ; flight-recorder slow-mo: 1 tick/frame
@@d1a:  or   ax,ax
        jz   @@pd2
        add  [spin],ax          ; the radar dish turns on real time
@@pl:   push ax
        call PHYS
        call DBGTICK
        pop  ax
        dec  ax
        jnz  @@pl
@@pd2:  call CAMERA
        call SETTRIG
        call BACKDROP
        call HAZE
        call WORLD
        cmp  word ptr [view],0
        jne  @@fpv
        call PLANE3D
        jmp  @@nv0
@@fpv:  ; call COCKPIT - PARKED with the panel (user's call: the whole
        ; cockpit reads as alien to the modern eye); the models still
        ; load and head-look still works - restore this call to revive
        ; call PNLDRW - the bitmap panel is PARKED (user's call: right
        ; for 1986, foreign to the modern eye); flip this back on and
        ; ship PANEL1.RAW in the bundle to revive it
@@nv0:  call HUDTXT
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
        cmp  word ptr [dbgslow],0
        je   @@nsl
        mov  cx,[dbgslow]
@@slw:  push cx
        call WAITVR
        pop  cx
        loop @@slw
@@nsl:
        call KEYSED             ; edge toggles: F G B V R
        cmp  byte ptr [KEYS+SC_ESC],0
        jne  @@quit
        jmp  @@frame
@@quit: mov  dx,[oldoff]        ; give INT 9 back to the BIOS
        push ds
        mov  ds,[oldseg]
        mov  ax,2509h
        int  21h
        pop  ds
        mov  ax,0003h
        int  10h
        mov  ax,4C00h
        int  21h

; ============================================================================
;  KBINT - the INT 9 handler (the OWLFLY scheme): KEYS[scan] = 1/0
; ============================================================================
KBINT:  push ax
        push bx
        push di
        push ds
        mov  ax,cs
        mov  ds,ax
        in   al,60h
        mov  ah,al
        and  al,7Fh
        mov  bl,al
        xor  bh,bh
        mov  di,offset KEYS
        add  di,bx
        test ah,80h
        jnz  @@brk
        mov  byte ptr [di],1
        jmp  @@eoi
@@brk:  mov  byte ptr [di],0
@@eoi:  mov  al,20h
        out  20h,al
        pop  ds
        pop  di
        pop  bx
        pop  ax
        iret

; KEYSED - once per frame: keys that TOGGLE fire on the press edge
KEYSED: mov  al,[KEYS+SC_F]
        cmp  al,[lF]
        je   @@g
        mov  [lF],al
        or   al,al
        jz   @@g
        inc  word ptr [flap]
        cmp  word ptr [flap],2
        jle  @@g
        mov  word ptr [flap],0
@@g:    mov  al,[KEYS+SC_G]
        cmp  al,[lG]
        je   @@b
        mov  [lG],al
        or   al,al
        jz   @@b
        xor  word ptr [gear],1
@@b:    mov  al,[KEYS+SC_B]
        cmp  al,[lB]
        je   @@v
        mov  [lB],al
        or   al,al
        jz   @@v
        xor  word ptr [brk],1
@@v:    mov  al,[KEYS+SC_V]
        cmp  al,[lV]
        je   @@o
        mov  [lV],al
        or   al,al
        jz   @@o
        xor  word ptr [view],1
@@o:    mov  al,[KEYS+SC_O]
        cmp  al,[lO]
        je   @@r
        mov  [lO],al
        or   al,al
        jz   @@r
        xor  word ptr [cnpt],1
@@r:    mov  al,[KEYS+SC_R]
        cmp  al,[lR]
        je   @@out
        mov  [lR],al
        or   al,al
        jz   @@out
        call RESET
@@out:  ret


        INCLUDE F_PHYS.INC
        INCLUDE F_WORLD.INC
        INCLUDE F_PLANE.INC
        INCLUDE F_HUD.INC
        INCLUDE F_DEBUG.INC

; ---- state ------------------------------------------------------------------
rseed   dw 1
ltick   dw 0
spin    dw 0
view    dw 0
apx      dw 0
apy      dw 0
apz      dw 0
hdg     dw 64
pit     dw 0
rol     dw 0
vel     dw 0
vsp     dw 0
thr     dw 0
flap    dw 0
gear    dw 1
brk     dw 0
dmg     dw 0
dead    dw 0
wrn     dw 0
wind    dw 0
stkx    dw 0
stky    dw 0
rud     dw 0
hrow    dw 100
qx0     dw 0
qz0     dw 0
qx1     dw 0
qz1     dw 0
vwy     dw 0
hx0     dw 0
hz0     dw 0
hx1     dw 0
hz1     dw 0
hh      dw 0
dsn     dw 0
dcs     dw 0
t1      dw 0
gu      dw 0
gv      dw 0
msin    dw 0
mcos    dw 0
rsn     dw 0
rcs     dw 0
psn     dw 0
pcs     dw 0
m1      dw 0
m2      dw 0
m3      dw 0
mx      dw 0
my      dw 0
mz      dw 0
wx      dw 0
wy      dw 0
wz      dw 0
KEYS    db 128 dup(0)
oldoff  dw 0
oldseg  dw 0
lF      db 0
lG      db 0
lB      db 0
lV      db 0
lR      db 0
lO      db 0
velf    dw 0
chdgf   dw 64*256
hdgr    dw 0
pfc     dw 0
PVX     dw 255 dup(0)
PVY     dw 255 dup(0)
PVZ     dw 255 dup(0)
FCD     dw 300 dup(0)
FCO     dw 300 dup(0)
tcol    db 9
bufseg  dw 0
; ---- engine contract (E_MATH + E_M3D + E_RAST) ------------------------------
heading dw 0
pitch   dw 0
roll    dw 0
hsin    dw 0
hcos    dw 256
rsin    dw 0
rcos    dw 256
psin    dw 0
pcos    dw 256
pofs    dw 0
horiz   dw 100
swayx   dw 0
swayy   dw 0
camx    dw 0
camy    dw 0
camz    dw 0
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
POKETAB dw apx,apy,apz,hdg,pit,rol,vel,thr,chdgf,wind,dbgslow
SINT    dw 0,6,13,19,25,31,38,44,50,56,62,68,74,80,86,92,98,104,109,115
        dw 121,126,132,137,142,147,153,157,162,167,172,177,181,185,190,194
        dw 198,202,206,209,213,216,220,223,226,229,231,234,237,239,241,243
        dw 245,247,248,250,251,252,253,254,255,255,256,256,256

        INCLUDE ..\..\..\ENGINE\E_MATH.INC
        INCLUDE ..\..\..\ENGINE\E_M3D.INC
        INCLUDE ..\..\..\ENGINE\E_RAST.INC

CODE    ENDS
        END START
