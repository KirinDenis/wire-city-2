; ============================================================================
;  RREC.ASM - KIT test: the 3D recipes, all in one program (which also
;  proves their names do not collide): R_HORIZ, R_STARS, R_BOX3D, R_TERRDR,
;  R_WIRE, R_FLIGHT, R_GROUND, R_LADDER.
;
;      RREC          checks, then shows a night scene with all of them, Esc
;      RREC /AUTO    the same, holds the scene ~2 s, prints PASS/FAIL
;      RREC /S       also writes SHOT.RAW (the scene + DAC)
;
;  Every check draws into the back buffer (before the mode is set) and
;  reads pixels back, or reads the numbers a recipe leaves.
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

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
; PIX x,y - AX = the buffer's pixel there
macro PIX x,y
{
        mov  al,[es:(y)*320+(x)]
        xor  ah,ah
}

start:  cld
        call GETAUTO
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
        mov  es,ax
        call R3_TRAP

        ; ==== R_HORIZ ====
        CAM  0,0,0, 0,0,0
        call HZPIVOT
        call HZFILL
        PIX  160,90
        EXPECT 1, 'R_HORIZ level: (160,90) is sky'
        PIX  160,110
        EXPECT 2, 'R_HORIZ level: (160,110) is ground'
        CAM  0,0,0, 0,0,32
        call HZPIVOT
        call HZFILL
        PIX  300,60
        EXPECT 2, 'R_HORIZ banked right 45: (300,60) is ground'
        PIX  20,60
        EXPECT 1, '...and (20,60) is sky'
        CAM  0,0,0, 0,16,0
        call HZPIVOT
        mov  ax,[hzrow]
        EXPECT 190, 'R_HORIZ nose up 16: the horizon drops to row 190'
        call HZFILL
        PIX  160,150
        EXPECT 1, '...and (160,150) is sky'

        ; ==== R_STARS ====
        CAM  0,0,0, 0,0,0
        call CLR
        call STARS
        mov  bx,0
        mov  cx,100
        call COUNT
        mov  [n1],ax
        mov  bx,101
        mov  cx,199
        call COUNT
        EXPECT 0, 'R_STARS: no star below the horizon (rows 101..199)'
        mov  ax,[n1]
        or   ax,ax
        jz   .s0
        mov  ax,1
.s0:    EXPECT 1, 'R_STARS: stars above it'

        ; ==== R_BOX3D ====
        CAM  0,100,0, 0,0,0
        call CLR
        mov  si,BOXA
        call BOXDRAW
        PIX  160,100
        EXPECT 4, 'R_BOX3D: a box ahead shows its south wall (lit, 4)'
        CAM  2000,100,1000, 192,0,0
        call CLR
        mov  si,BOXA
        call BOXDRAW
        PIX  160,100
        EXPECT 5, 'R_BOX3D: from the east, looking west: the east wall (5)'
        CAM  0,1000,-500, 0,-16,0
        call CLR
        mov  si,BOXA
        call BOXDRAW
        PIX  160,100
        EXPECT 6, 'R_BOX3D: from above: the roof (6)'
        CAM  0,100,0, 0,0,0
        call CLR
        mov  si,BOXL            ; the near one FIRST in the table
        mov  cx,2
        call BOXALL
        PIX  160,100
        EXPECT 4, 'R_BOX3D BOXALL: sorted - the near box (4) is on top'
        PIX  40,100
        EXPECT 9, '...and the far one (9) beside it'
        CAM  0,100,-30000, 0,0,0
        call CLR
        mov  si,BOXA
        call BOXDRAW
        mov  bx,0
        mov  cx,199
        call COUNT
        EXPECT 0, 'R_BOX3D: a box past BOXFAR is not drawn'

        ; ==== R_TERRDR ====
        mov  ax,1234
        call TER_GEN
        call GNDORD
        mov  ax,[gnddisk]
        EXPECT 441, 'R_TERRDR: the disk of 12 nodes is 441 squares'
        call TER_TOP
        add  ax,700
        mov  bx,ax
        xor  ax,ax
        xor  cx,cx
        xor  dx,dx
        xor  si,si
        xor  di,di
        call R3_CAMERA          ; high over node (8,8), level
        mov  ax,[r3_faults]
        mov  [f0],ax
        call CLR
        call GNDDRAW
        PIX  160,199
        or   ax,ax
        jz   .t0
        mov  ax,1
.t0:    EXPECT 1, 'R_TERRDR: ground at the bottom of the screen'
        PIX  160,0
        EXPECT 0, '...and nothing at the top (above the horizon)'
        mov  ax,[r3_faults]
        sub  ax,[f0]
        EXPECT 0, '...no divide faults'

        ; ==== R_WIRE ====
        call WIRORD
        xor  ax,ax              ; low over the ground, where hills hide hills
        xor  bx,bx
        call TER_H
        add  ax,150
        mov  bx,ax
        xor  ax,ax
        xor  cx,cx
        xor  dx,dx
        xor  si,si
        xor  di,di
        call R3_CAMERA
        mov  byte [wirhide],0
        call CLR
        call WIRDRAW
        mov  bx,0
        mov  cx,199
        call COUNT
        mov  [n1],ax
        mov  byte [wirhide],1
        call CLR
        call WIRDRAW
        mov  bx,0
        mov  cx,199
        call COUNT
        mov  [n2],ax
        mov  ax,[n1]
        or   ax,ax
        jz   .w0
        mov  ax,1
.w0:    EXPECT 1, 'R_WIRE: the see-through lattice draws'
        mov  ax,[n1]
        call INFO
        mov  ax,[n2]
        call INFO
        mov  ax,[n2]
        cmp  ax,[n1]
        mov  ax,1
        jb   .w1
        xor  ax,ax
.w1:    EXPECT 1, 'R_WIRE: the skyline hides some of it'
        mov  ax,[r3_line]
        EXPECT 0, '...and leaves r3_line as it found it'

        ; ==== R_FLIGHT ====
        CAM  0,1000,0, 0,0,0
        mov  cx,10
.f1:    call FLIGHT
        loop .f1
        mov  ax,[r3_camz]
        EXPECT 480, 'R_FLIGHT: 10 frames north at 48 = z 480'
        mov  byte [flright],1
        mov  byte [flpull],1
        mov  cx,10
.f2:    call FLIGHT
        loop .f2
        mov  ax,[heading]
        EXPECT 20, 'R_FLIGHT: 10 frames of RIGHT turn 20'
        mov  ax,[roll]
        EXPECT 30, '...and bank to the limit, 30'
        mov  ax,[r3_camy]
        EXPECT 1200, '...and the stick back climbs 200'
        mov  byte [flright],0
        mov  byte [flpull],0
        mov  cx,5
.f3:    call FLIGHT
        loop .f3
        mov  ax,[roll]
        EXPECT 15, 'R_FLIGHT: let go, 5 frames: the bank falls to 15'

        ; ==== R_GROUND ====
        CAM  0,0,0, 0,0,0       ; on (in) the ground
        call GCCHECK
        xor  ah,ah
        EXPECT 1, 'R_GROUND: under the ground: crashed (AL 1)'
        mov  ax,[r3_camx]
        mov  bx,[r3_camz]
        call TER_H
        add  ax,GCCLEAR
        cmp  ax,[r3_camy]
        mov  ax,1
        jg   .g0
        xor  ax,ax
.g0:    EXPECT 0, '...the eye put back above the ground'
        call GCCHECK
        xor  ah,ah
        EXPECT 2, 'R_GROUND: then a wreck (AL 2)'
        sub  word [gctick],GCWAIT+1 ; as if two seconds went by
        call GCCHECK
        xor  ah,ah
        EXPECT 3, 'R_GROUND: then up again (AL 3)'
        call TER_TOP
        add  ax,GCUP
        sub  ax,[r3_camy]
        EXPECT 0, '...above the highest point by GCUP'
        call GCCHECK
        xor  ah,ah
        EXPECT 0, 'R_GROUND: high up: flying (AL 0)'

        ; ==== R_LADDER ====
        CAM  0,0,0, 0,0,0
        call HZPIVOT
        call CLR
        call LADDER
        PIX  100,62
        EXPECT 10, 'R_LADDER: the +10 rung at row 62 (tan*FOCAL = 38)'
        PIX  160,62
        EXPECT 0, '...with its gap in the middle'
        PIX  100,138
        EXPECT 10, 'R_LADDER: the -10 rung at row 138...'
        PIX  104,138
        EXPECT 0, '...dashed'
        call CLR
        call COMPASS
        PIX  160,8
        EXPECT 10, 'R_LADDER COMPASS: heading 0, the long tick at x 160'
        call CLR
        mov  ax,1000
        mov  bx,296
        call VTAPE
        PIX  303,100
        EXPECT 10, 'R_LADDER VTAPE 1000: the long tick 1000 on the pointer row'
        PIX  299,88
        EXPECT 10, '...1100 a short one 12 rows up'
        PIX  300,88
        EXPECT 0, '...4 pixels long'

        ; ==== the scene, to look at ====
        mov  ax,0013h
        int  10h
        call TER_PAL
        mov  byte [hzsky],0     ; a night: black sky...
        mov  byte [hzgnd],8     ;  ...and black ground past the reach
        mov  byte [starlo],15   ; (TER_PAL made 7 a red)
        CAM  -3000,0,-6000, 16,0,8
        call TER_TOP
        mov  [r3_camy],ax       ; just over the highest point
        call R3_TRIG
        call HZPIVOT
        call HZFILL
        call STARS
        call GNDDRAW
        mov  si,TOWN
        mov  cx,TOWNN
        call BOXALL
        call LADDER
        call COMPASS
        mov  ax,[r3_camy]
        mov  bx,296
        call VTAPE
        call SHOW
        call SHOT
        call TICK
        mov  [t0],ax
.hold:  cmp  byte [auto],0
        je   .key
        call TICK
        sub  ax,[t0]
        cmp  ax,36
        jb   .hold
        jmp  .end
.key:   mov  ah,0
        int  16h
        cmp  ah,1
        jne  .key
.end:   mov  ax,0003h
        int  10h
        call R3_UNTRAP
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

; CLR - the buffer to 0 (ES = it)
CLR:    push ax
        push cx
        push di
        xor  di,di
        xor  ax,ax
        mov  cx,32000
        rep  stosw
        pop  di
        pop  cx
        pop  ax
        ret

; COUNT - AX = the non-zero pixels in rows BX..CX of ES
COUNT:  push bx
        push cx
        push dx
        push si
        sub  cx,bx
        inc  cx                 ; rows
        mov  ax,320
        mul  bx                 ; AX = the first row's offset
        mov  si,ax
        mov  ax,320
        mul  cx                 ; AX = the bytes (< 64000)
        mov  cx,ax
        xor  ax,ax
.l:     cmp  byte [es:si],0
        je   .n
        inc  ax
.n:     inc  si
        loop .l
        pop  si
        pop  dx
        pop  cx
        pop  bx
        ret

SHOW:   push ds
        push es
        mov  ax,0A000h
        mov  es,ax
        mov  ds,[buf]
        xor  si,si
        xor  di,di
        mov  cx,32000
        rep  movsw
        pop  es
        pop  ds
        ret

TICK:   push es
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:046Ch]
        pop  es
        ret

; GETAUTO - [auto] = 1 for /AUTO (or /A), [shot] = 1 for /S
GETAUTO:mov  si,81h
        xor  ch,ch
        mov  cl,[80h]
.l:     jcxz .no
        lodsb
        dec  cx
        cmp  al,'/'
        jne  .l
        jcxz .no
        lodsb
        dec  cx
        and  al,0DFh            ; upper case
        cmp  al,'A'
        jne  .s
        mov  byte [auto],1
.s:     cmp  al,'S'
        jne  .l
        mov  byte [shot],1
        jmp  .l
.no:    ret

; SHOT - under /S: the buffer and the DAC into SHOT.RAW
SHOT:   cmp  byte [shot],0
        je   .r
        push ds
        mov  dx,3C7h
        xor  al,al
        out  dx,al
        mov  dx,3C9h
        mov  di,dac
        mov  cx,768
.p:     in   al,dx
        mov  [di],al
        inc  di
        loop .p
        mov  dx,fshot
        xor  cx,cx
        mov  ah,3Ch
        int  21h
        jc   .x
        mov  bx,ax
        mov  ds,[buf]
        xor  dx,dx
        mov  cx,64000
        mov  ah,40h
        int  21h
        pop  ds
        push ds
        mov  dx,dac
        mov  cx,768
        mov  ah,40h
        int  21h
        mov  ah,3Eh
        int  21h
.x:     pop  ds
.r:     ret

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

; INFO - "  info: AX" on a line of its own
INFO:   push ax
        mov  dx,t_info
        mov  ah,9
        int  21h
        pop  ax
        call PUTN
        mov  dx,t_nl
        mov  ah,9
        int  21h
        ret

PUTS:   lodsb
        or   al,al
        jz   .d
        mov  dl,al
        mov  ah,2
        int  21h
        jmp  PUTS
.d:     ret

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
shot    db   0
got     dw   0
fails   dw   0
buf     dw   0
n1      dw   0
n2      dw   0
f0      dw   0
t0      dw   0
fshot   db   'SHOT.RAW',0
dac     db   768 dup(0)
t_pass  db   'PASS $'
t_fail  db   'FAIL $'
t_got   db   '  got $'
t_nl    db   13,10,'$'
t_info  db   '      pixels lit: $'
t_ok    db   'RREC: all PASS',13,10,'$'
t_bad   db   'RREC: FAILED',13,10,'$'
t_nomem db   'RREC: no memory for the buffer',13,10,'$'

; boxes: x, z, hw, hd, y0, y1;  lit, shade, roof, line
BOXA    dw 0,1000, 200,200, 0,400
        db 4,5,6,0
BOXL    dw 0,1000, 100,100, 0,300       ; near, small
        db 4,5,6,0
        dw -600,3000, 1000,200, 0,900   ; far, wide
        db 9,9,9,0
TOWN    dw -2600,-3000, 150,150, 1500,2300
        db 12,11,13,9
        dw -2100,-2400, 100,200, 1400,2000
        db 12,11,13,9
        dw -3200,-2200, 200,120, 1500,2600
        db 12,11,13,9
TOWNN   = 3

        include '..\..\KIT\LIB\K_3D.INC'
        include '..\..\KIT\LIB\K_TERR.INC'
        include '..\..\KIT\REC\R_HORIZ.ASM'
        include '..\..\KIT\REC\R_STARS.ASM'
        include '..\..\KIT\REC\R_BOX3D.ASM'
        include '..\..\KIT\REC\R_TERRDR.ASM'
        include '..\..\KIT\REC\R_WIRE.ASM'
        include '..\..\KIT\REC\R_FLIGHT.ASM'
        include '..\..\KIT\REC\R_GROUND.ASM'
        include '..\..\KIT\REC\R_LADDER.ASM'
