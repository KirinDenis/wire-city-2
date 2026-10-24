; ============================================================================
;  R3D.ASM - KIT test: K_3D.INC (the engine's 3D, wrapped).
;
;      R3D          checks, then shows a spinning cube until Esc
;      R3D /AUTO    the same, holds the picture ~2 s, prints PASS/FAIL
;
;  Known points are projected and their screen places checked to the pixel:
;  straight ahead lands on (160,100), behind gives CF, a turn, a pitch, a
;  roll, a wrapped world, the orbit and the chase. Then a cube, a line and
;  a quad are drawn and their pixels read back out of the buffer, the INT 0
;  trap is shown catching a real divide by zero, and given back.
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

; EXPECT v, 'name' - AX must be v: a PASS/FAIL line with what AX was
macro EXPECT v, text
{
        local ..str, ..skip
        mov  [got],ax
        cmp  ax,v
        mov  si, ..str
        call RESULT
        jmp ..skip
..str     db   text,0
..skip:
}
; CFIS v, 'name' - the carry flag must be v (0/1)
macro CFIS v, text
{
        mov  ax,0
        adc  ax,0               ; AX = CF
        EXPECT v, text
}
; CAM x,y,z,h,p,r - the camera
macro CAM x,y,z,h,p,r
{
        mov  ax,x
        mov  bx,y
        mov  cx,z
        mov  dx,h
        mov  si,p
        mov  di,r
        call R3_CAMERA
}
; PT x,y,z - project a world point: AX,BX = screen, CF
macro PT x,y,z
{
        mov  ax,x
        mov  bx,y
        mov  cx,z
        call R3_POINT
}

start:  call GETAUTO
        mov  bx,1000h           ; the .COM keeps 64K...
        mov  ah,4Ah
        int  21h
        mov  bx,0FA0h           ; ...and asks DOS for 64000 bytes more
        mov  ah,48h
        int  21h
        jnc  .mem
        mov  dx,t_nomem
        mov  ah,9
        int  21h
        mov  ax,4C01h
        int  21h
.mem:   mov  [buf],ax

        ; ---- the constants ----
        mov  ax,FOCAL
        EXPECT 220, 'FOCAL defaults to 220'
        mov  ax,NEARZ
        EXPECT 40, 'NEARZ defaults to 40'

        ; ---- the camera at the origin, looking north ----
        CAM  0,0,0, 0,0,0
        PT   0,0,1000
        mov  [sv],bx
        mov  [sv2],ax
        CFIS 0, 'R3_POINT ahead: on the screen (CF 0)'
        mov  ax,[sv2]
        EXPECT 160, 'R3_POINT ahead: x = 160'
        mov  ax,[sv]
        EXPECT 100, 'R3_POINT ahead: y = 100 (horiz)'
        PT   100,0,1000
        EXPECT 182, 'R3_POINT 100 right at 1000: x = 160+100*220/1000'
        PT   0,100,1000
        mov  ax,bx
        EXPECT 78, 'R3_POINT 100 up at 1000: y = 78'
        PT   0,0,-1000
        CFIS 1, 'R3_POINT behind: CF = 1'
        PT   0,0,30
        CFIS 1, 'R3_POINT nearer than NEARZ: CF = 1'
        PT   5000,0,1000
        CFIS 1, 'R3_POINT far off to the side: CF = 1'
        mov  ax,[r3_pz]
        EXPECT 1000, 'R3_POINT leaves the depth in r3_pz'

        ; ---- turned east ----
        CAM  0,0,0, 64,0,0
        PT   1000,0,0
        mov  [sv],bx
        EXPECT 160, 'heading 64: a point east is ahead, x = 160'
        mov  ax,[sv]
        EXPECT 100, 'heading 64: y = 100'
        PT   0,0,1000
        CFIS 1, 'heading 64: north is off the left edge (CF)'

        ; ---- a moved camera, and a wrapped world ----
        CAM  5000,200,5000, 0,0,0
        PT   5000,200,6000
        EXPECT 160, 'camera at 5000,200,5000: the point 1000 north, x 160'
        CAM  0,0,30000, 0,0,0
        PT   0,0,-30000
        mov  [sv],bx
        CFIS 0, 'z -30000 seen from 30000 wraps to 5536 ahead (CF 0)'
        mov  ax,[sv]
        EXPECT 100, 'the wrapped point: y = 100'

        ; ---- pitch and roll ----
        CAM  0,0,0, 0,16,0
        PT   0,0,1000
        mov  ax,bx
        EXPECT 190, 'pitch 16 (nose up): the point ahead drops to y 190'
        CAM  0,0,0, 0,0,64
        PT   100,0,1000
        mov  [sv],bx
        EXPECT 160, 'roll 64 (banked right): a point on the right: x 160'
        mov  ax,[sv]
        EXPECT 78, '...and it rises to y 78'

        ; ---- registers kept ----
        CAM  0,0,0, 0,0,0
        mov  dx,3333h
        mov  si,4444h
        mov  di,5555h
        mov  bp,6666h
        mov  cx,1000
        xor  ax,ax
        xor  bx,bx
        call R3_POINT
        xor  ax,ax
        cmp  cx,1000
        jne  .k1
        cmp  dx,3333h
        jne  .k1
        cmp  si,4444h
        jne  .k1
        cmp  di,5555h
        jne  .k1
        cmp  bp,6666h
        jne  .k1
        jmp  .k2
.k1:    mov  ax,1
.k2:    EXPECT 0, 'R3_POINT keeps CX DX SI DI BP'

        ; ---- the orbit ----
        xor  ax,ax
        xor  bx,bx
        xor  cx,cx
        xor  dx,dx
        mov  si,1000
        xor  di,di
        call R3_ORBIT
        mov  ax,[r3_camz]
        EXPECT -1000, 'R3_ORBIT d 1000 h 0: the eye 1000 south (z -1000)'
        PT   0,0,0
        EXPECT 160, 'R3_ORBIT: the point in the middle, x 160'
        xor  ax,ax
        xor  bx,bx
        xor  cx,cx
        xor  dx,dx
        mov  si,1000
        mov  di,1000
        call R3_ORBIT
        mov  ax,[pitch]
        EXPECT -32, 'R3_ORBIT d 1000 h 1000: pitch -32 (45 deg down)'
        PT   0,0,0
        mov  ax,bx
        EXPECT 100, 'R3_ORBIT looking down: the point at y 100'

        ; ---- the chase ----
        mov  word [r3_chd],300
        mov  word [r3_chh],0
        mov  byte [r3_chnew],1
        mov  ax,2000
        xor  bx,bx
        mov  cx,2000
        mov  dx,64
        call R3_CHASE
        mov  ax,[r3_camx]
        EXPECT 1700, 'R3_CHASE heading 64, 300 behind: camx 1700'
        mov  ax,[r3_camz]
        EXPECT 2000, 'R3_CHASE: camz 2000'
        mov  ax,2000
        xor  bx,bx
        mov  cx,2000
        mov  dx,104
        call R3_CHASE
        mov  ax,[r3_chang]
        EXPECT 74, 'R3_CHASE eases a quarter of 40: heading 74'

        ; ---- the model's limits ----
        mov  si,CUBEV
        mov  di,CUBEF
        mov  cx,R3_MAXV+1
        mov  dx,6
        xor  al,al
        call R3_MODEL
        CFIS 1, 'R3_MODEL with too many vertices: CF = 1'

        ; ---- the trap ----
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:0]
        mov  [old0],ax
        mov  ax,[es:2]
        mov  [old0+2],ax
        call R3_TRAP
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:0]
        sub  ax,R3_INT0
        mov  bx,[es:2]
        mov  cx,cs
        sub  bx,cx
        or   ax,bx
        EXPECT 0, 'R3_TRAP: vector 0 = CS:R3_INT0'
        mov  ax,[r3_faults]
        mov  [f0],ax
        mov  si,DIV0
        call R3_SAFE
        CFIS 1, 'R3_SAFE: a real divide by 0 is caught, CF = 1'
        mov  ax,[r3_faults]
        sub  ax,[f0]
        EXPECT 1, '...and counted in r3_faults'
        mov  si,GIVE
        call R3_SAFE
        mov  [sv],ax
        CFIS 0, 'R3_SAFE: a clean routine, CF = 0'
        mov  ax,[sv]
        EXPECT 1234, '...and its AX comes back'
        mov  ax,[r3_savesp]
        EXPECT 0, 'no guard left set after R3_SAFE'

        ; ---- the picture ----
        mov  ax,[r3_faults]
        mov  [f0],ax
        mov  ax,0013h
        int  10h
        call FRAME              ; the first frame: the checked one
        push ds
        mov  ds,[buf]           ; read the pixels back out of the buffer
        mov  al,[100*320+160]
        mov  ah,[152*320+160]
        mov  bl,[100*320+50]
        pop  ds
        mov  [pc1],al
        mov  [pc2],ah
        mov  [pc3],bl
        mov  ax,[r3_faults]
        sub  ax,[f0]
        mov  [nf],ax
        call SHOW
        call TICK
        mov  [t0],ax
.anim:  inc  word [spin]
        call FRAME
        call SHOW
        cmp  byte [auto],0
        je   .key
        call TICK
        sub  ax,[t0]
        cmp  ax,36              ; ~2 s
        jb   .anim
        jmp  .end
.key:   mov  ah,1
        int  16h
        jz   .anim
        mov  ah,0
        int  16h
        cmp  ah,1               ; Esc
        jne  .anim
.end:   mov  ax,0003h
        int  10h
        mov  al,[pc1]
        xor  ah,ah
        EXPECT 9, 'R3_MODEL cube ahead: its near face (9) in the middle'
        mov  al,[pc2]
        xor  ah,ah
        EXPECT 15, 'R3_EDGE: the line at y -120, z 500 crosses (160,152)'
        mov  al,[pc3]
        xor  ah,ah
        EXPECT 4, 'R3_QUAD: the quad round (-500,0,1000) fills (50,100)'
        mov  ax,[nf]
        EXPECT 0, 'the first frame (and a near-plane edge): no faults'
        call R3_UNTRAP
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:0]
        sub  ax,[old0]
        mov  bx,[es:2]
        sub  bx,[old0+2]
        or   ax,bx
        EXPECT 0, 'R3_UNTRAP: DOS vector 0 back'
        mov  es,[buf]
        mov  ah,49h
        int  21h
        mov  ax,[fails]
        or   ax,ax
        jnz  .bad
        mov  dx,t_ok
        mov  ah,9
        int  21h
        mov  ax,4C00h
        int  21h
.bad:   mov  dx,t_bad
        mov  ah,9
        int  21h
        mov  ax,4C01h
        int  21h

; FRAME - the picture: a cube (spinning after the first frame), a line,
; one through the near plane, a quad, a ground grid
FRAME:  mov  es,[buf]
        xor  di,di
        xor  ax,ax
        mov  cx,32000
        rep  stosw              ; the buffer cleared
        CAM  0,0,0, 0,0,0
        mov  word [r3_mx],0
        mov  word [r3_my],0
        mov  word [r3_mz],600
        mov  ax,[spin]
        mov  [r3_myaw],ax
        mov  si,CUBEV
        mov  di,CUBEF
        mov  cx,8
        mov  dx,6
        xor  al,al              ; filled
        cmp  word [spin],0
        je   .m
        mov  al,2               ; spinning: filled + outlined
.m:     call R3_MODEL
        mov  word [r3_x0],-200  ; a line in front
        mov  word [r3_y0],-120
        mov  word [r3_z0],500
        mov  word [r3_x1],200
        mov  word [r3_y1],-120
        mov  word [r3_z1],500
        mov  al,15
        call R3_EDGE
        mov  word [r3_x0],300   ; a line from behind the eye to ahead
        mov  word [r3_y0],-120
        mov  word [r3_z0],-500
        mov  word [r3_x1],300
        mov  word [r3_y1],-120
        mov  word [r3_z1],800
        mov  al,14
        call R3_EDGE
        mov  si,QUADC
        mov  di,r3_qx
        push ds
        pop  es
        mov  cx,12
        rep  movsw              ; the quad's corners
        mov  es,[buf]
        mov  ax,0004h           ; red, filled
        call R3_QUAD
        ret

; SHOW - the buffer onto the screen
SHOW:   push ds
        mov  ax,0A000h
        mov  es,ax
        mov  ds,[buf]
        xor  si,si
        xor  di,di
        mov  cx,32000
        rep  movsw
        pop  ds
        ret

; TICK - AX = the BIOS tick
TICK:   push es
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:046Ch]
        pop  es
        ret

DIV0:   xor  bx,bx
        mov  ax,5
        xor  dx,dx
        div  bx                 ; a divide by nought, on purpose
        ret
GIVE:   mov  ax,1234
        ret

GETAUTO:mov  si,81h
        xor  ch,ch
        mov  cl,[80h]           ; the tail's length
.s:     jcxz .no
        lodsb
        dec  cx
        cmp  al,'/'
        jne  .s
        cmp  cx,4
        jb   .no
        mov  ax,[si]
        and  ax,0DFDFh          ; upper case
        cmp  ax,'AU'
        jne  .s
        mov  ax,[si+2]
        and  ax,0DFDFh
        cmp  ax,'TO'
        jne  .s
        mov  byte [auto],1
.no:    ret

; RESULT - ZF = 1 pass: "PASS name = got", else "FAIL ..." and fails++
RESULT: jnz  .f
        mov  dx,t_pass
        jmp  .p
.f:     mov  dx,t_fail
        inc  word [fails]       ; one more failure
.p:     mov  ah,9
        int  21h
        call PUTS
        mov  dx,t_got
        mov  ah,9
        int  21h
        mov  ax,[got]
        call PUTN
        mov  dx,t_nl
        mov  ah,9
        int  21h
        ret

; PUTS - the 0-ended string at SI
PUTS:   lodsb
        or   al,al
        jz   .d
        mov  dl,al
        mov  ah,2
        int  21h
        jmp  PUTS
.d:     ret

; PUTN - AX as a signed decimal number
PUTN:   or   ax,ax
        jns  .p
        push ax
        mov  dl,'-'
        mov  ah,2
        int  21h
        pop  ax
        neg  ax                 ; AX = |AX|
.p:     xor  cx,cx              ; CX = digits stacked
        mov  bx,10
.d:     xor  dx,dx
        div  bx                 ; AX = AX / 10, DX = the digit (BX = 10)
        push dx
        inc  cx                 ; one more digit
        or   ax,ax
        jnz  .d
.o:     pop  dx
        add  dl,'0'             ; the digit as a character
        mov  ah,2
        int  21h
        loop .o
        ret

auto    db   0
got     dw   0
fails   dw   0
sv      dw   0
sv2     dw   0
buf     dw   0
f0      dw   0
nf      dw   0
t0      dw   0
spin    dw   0
old0    dw   0,0
pc1     db   0
pc2     db   0
pc3     db   0
t_pass  db   'PASS $'
t_fail  db   'FAIL $'
t_got   db   '  got $'
t_nl    db   13,10,'$'
t_ok    db   'R3D: all PASS',13,10,'$'
t_bad   db   'R3D: FAILED',13,10,'$'
t_nomem db   'R3D: no memory for the buffer',13,10,'$'

; the cube: 8 corners of +-100, 6 faces (Obj2Inc's layout)
CUBEV   dw -100,-100,-100,  100,-100,-100,  100, 100,-100, -100, 100,-100
        dw -100,-100, 100,  100,-100, 100,  100, 100, 100, -100, 100, 100
CUBEF   db 0,1,2,3, 9           ; the near face (z -100)
        db 5,4,7,6, 1           ; the far one
        db 4,0,3,7, 2           ; left
        db 1,5,6,2, 3           ; right
        db 3,2,6,7, 14          ; top
        db 4,5,1,0, 6           ; bottom
QUADC   dw -600,-400,-400,-600  ; x of the four corners
        dw  -50, -50,  50,  50  ; y
        dw 1000,1000,1000,1000  ; z

        include '..\..\KIT\LIB\K_3D.INC'
