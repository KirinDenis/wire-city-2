; ============================================================================
;@ T_OBJ3D    a 3D object you steer: a filled model, chase camera, floor grid, Esc
;  T_OBJ3D.ASM - KIT template: a small ship on a floor, drawn from its two
;  tables (vertices, faces) by K_3D's R3_MODEL, the camera following behind
;  it (R3_CHASE), four standing blocks to steer between, painted far to
;  near as whole objects, and a floor grid of 3D lines (R3_EDGE).
;
;      LEFT / RIGHT  turn the ship
;      UP / DOWN     forward / back
;      SPACE         how it is drawn: filled, wire, filled + outline
;      ESC           back to DOS
;
;  A MODEL IS TWO TABLES, in TOOLS\Obj2Inc's layout (it makes them from a
;  Blender .obj): SHIPV - dw x,y,z a vertex (+z is its nose, +y up); SHIPF
;  - db a,b,c,d,colour a face (a triangle repeats its last corner). Change
;  the numbers, and the ship is another ship. At most R3_MAXV vertices and
;  R3_MAXF faces (64 each; define them before the K_3D include for more).
;
;  COPY IT: A:\MY\NAME\NAME.ASM - the include paths hold from there. Grow
;  it: more objects in OBJS (they are sorted by distance every frame), a
;  K_TERR island under them, R_STARS overhead.
;  LETTERS: K_FONT's. TITLE is R_TITLE's TTLCARD over the turning ship (its
;  own loop: this program has its own buffer and SHOW, not K_VGA's), the
;  words t_name t_sub t_keys; HUD the heading in FNT_LSCORE digits, the
;  look's name and the keys in FNT_HUD's ringed 4x6.
;  /AUTO (the kit's test run): the title 12 ticks, then steers by itself for ~2 s, quits, and prints
;  what happened on DOS's output. /S also writes SHOT.RAW (the last frame).
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

SC_ESC  = 01h                   ; scan codes
SC_SPC  = 39h
SC_UP   = 48h
SC_DN   = 50h
SC_LF   = 4Bh
SC_RT   = 4Dh
GRIDN   = 8                     ; floor lines each way from the ship
GRIDS   = 256                   ; ...this far apart
OBJN    = 5                     ; the ship + four blocks

start:  cld
        call GETAUTO
        mov  bx,1000h           ; the .COM keeps 64K...
        mov  ah,4Ah
        int  21h
        mov  bx,0FA0h           ; ...and a 64000-byte back buffer
        mov  ah,48h
        int  21h
        jnc  .mem
        mov  dx,t_nomem
        mov  ah,9
        int  21h
        mov  ax,4C01h
        int  21h
.mem:   mov  [buf],ax
        mov  word [r3_quit],QUIT ; a divide fault outside the 3D code: out
        call R3_TRAP
        mov  ax,0013h
        int  10h
        mov  word [r3_chd],420  ; the chase camera: this far behind...
        mov  word [r3_chh],160  ; ...this far above
        mov  byte [r3_chnew],1
        mov  byte [r3_wirec],15 ; the outline's colour (mode 2)
        call TITLE              ; the title card (the BIOS's keys: before
        jc   QUIT               ;  KEYON); Esc there: back to DOS
        call KEYON
        call TICK
        mov  [t0],ax

; ---- one frame ----------------------------------------------------------------
FRAME:  call STICK              ; keys (or the script) -> ship
        call SCENE              ; the floor and the objects into [buf]
        call HUD                ; the ringed words over them
        call SHOW
        inc  word [frames]
        cmp  byte [KEYS+SC_ESC],0
        jne  QUIT
        cmp  byte [auto],0
        je   FRAME
        call TICK
        sub  ax,[t0]
        cmp  ax,40              ; the test: ~2 s
        jb   FRAME

; ---- every way out ------------------------------------------------------------
QUIT:   mov  ax,cs              ; (R3_INT0 may jump here)
        mov  ds,ax
        call KEYOFF
        call SHOT
        call R3_UNTRAP
        mov  ax,0003h
        int  10h
        mov  es,[buf]
        mov  ah,49h
        int  21h
        cmp  byte [auto],0
        je   .x
        mov  dx,t_res
        mov  ah,9
        int  21h
        mov  ax,[frames]
        call PUTN
        mov  dx,t_flt
        mov  ah,9
        int  21h
        mov  ax,[r3_faults]
        call PUTN
        mov  dx,t_hd
        mov  ah,9
        int  21h
        mov  ax,[shiph]
        call PUTN
        mov  dx,t_nl
        mov  ah,9
        int  21h
        mov  dx,t_pass
        cmp  word [frames],0
        je   .f
        cmp  word [r3_faults],0
        jne  .f
        mov  ax,[shipz]         ; it must have moved
        or   ax,[shipx]
        jnz  .ok
.f:     mov  dx,t_fail
.ok:    mov  ah,9
        int  21h
.x:     mov  ax,4C00h
        int  21h

; ---- STICK: turn, move, the draw mode ----------------------------------------
STICK:  cmp  byte [auto],0
        je   .keys
        call TICK               ; the script, by the clock
        sub  ax,[t0]
        mov  byte [KEYS+SC_UP],1
        mov  byte [KEYS+SC_RT],0
        mov  byte [KEYS+SC_LF],0
        cmp  ax,18
        jae  .a2
        mov  byte [KEYS+SC_RT],1
        jmp  .keys
.a2:    mov  byte [KEYS+SC_LF],1
        cmp  ax,24
        jb   .keys
        mov  byte [KEYS+SC_SPC],1  ; and try the other draw modes
.keys:  cmp  byte [KEYS+SC_LF],0
        je   .r
        sub  word [shiph],3
.r:     cmp  byte [KEYS+SC_RT],0
        je   .m
        add  word [shiph],3
.m:     and  word [shiph],255
        xor  bx,bx              ; BX = the step: 0, +12 or -12
        cmp  byte [KEYS+SC_UP],0
        je   .b
        mov  bx,12
.b:     cmp  byte [KEYS+SC_DN],0
        je   .go
        mov  bx,-12
.go:    or   bx,bx
        jz   .sp
        mov  ax,[shiph]
        call SINQ               ; AX = sin*256 (eats BX CX SI)
        mov  [tmp],ax
        mov  ax,[shiph]
        add  ax,64
        call SINQ               ; AX = cos*256
        mov  [tmp2],ax
        mov  bx,12              ; the step again (SINQ ate it)
        cmp  byte [KEYS+SC_DN],0
        je   .b2
        mov  bx,-12
.b2:    mov  ax,[tmp]
        imul bx                 ; DX:AX = sin * step
        mov  cx,256
        idiv cx                 ; AX = sin*step/256 (|q| <= 12)
        add  [shipx],ax
        mov  ax,[tmp2]
        imul bx                 ; DX:AX = cos * step
        idiv cx                 ; / 256
        add  [shipz],ax
.sp:    mov  al,[KEYS+SC_SPC]   ; SPACE: the next draw mode, once a press
        cmp  al,[spwas]
        je   .x
        mov  [spwas],al
        or   al,al
        jz   .x
        inc  byte [mode]
        cmp  byte [mode],3
        jb   .x
        mov  byte [mode],0
.x:     cmp  byte [auto],0
        je   .y
        mov  byte [KEYS+SC_SPC],0
.y:     ret

; ---- SCENE: the camera behind the ship, the buffer cleared, floor, objects
SCENE:  mov  ax,[shipx]         ; the camera behind it
        mov  bx,40
        mov  cx,[shipz]
        mov  dx,[shiph]
        call R3_CHASE
        mov  es,[buf]
        xor  di,di
        xor  ax,ax
        mov  cx,32000
        rep  stosw              ; the buffer cleared
        call FLOOR
        call OBJECTS
        ret

; ---- TITLE: R_TITLE's card over the scene, the ship turning; until Enter
;  (CF = 0) or Esc (CF = 1); /AUTO: 12 ticks. The heading is put back after.
TITLE:  mov  word [ttl_name],t_name ; our words on the card
        mov  word [ttl_sub],t_sub
        mov  word [ttl_keys],t_keys
        call TICK
        mov  [tt0],ax
.f:     add  word [shiph],2     ; the ship turns on the spot
        and  word [shiph],255   ;  (a turn is 256)
        call SCENE
        mov  es,[buf]           ; the card into the buffer
        call TICK               ; AX = the tick: PRESS ENTER blinks by it
        call TTLCARD
        call SHOW
        cmp  byte [auto],0
        je   .key
        call TICK
        sub  ax,[tt0]           ; ticks shown
        cmp  ax,12
        jb   .f
        jmp  .go
.key:   mov  ah,1
        int  16h                ; a key waiting?
        jz   .f
        xor  ah,ah
        int  16h
        cmp  al,27
        je   .esc
        cmp  al,13
        je   .go
        cmp  al,' '
        jne  .f
.go:    mov  word [shiph],0     ; the play starts facing north
        mov  byte [r3_chnew],1  ;  and the camera jumps behind it
        clc
        ret
.esc:   stc
        ret

; ---- HUD: heading and draw mode at the top, the keys at the foot, all in
;  K_FONT's ringed letters - they read on the floor, the blocks, the sky
HUD:    mov  es,[buf]
        mov  byte [fnt_col],15  ; the fast 4x6, white, ringed black
        mov  byte [fnt_rc],0
        mov  si,t_hdg
        mov  bx,4
        mov  dx,5
        call FNT_HUD            ; BX = past the word
        mov  al,FNT_LSCORE      ; the heading in bold ringed digits
        call FNT_LOOK
        mov  ax,[shiph]         ; 0..255 a turn
        mov  cx,45
        mul  cx                 ; AX = h * 45 (at most 11475; DX lost)
        mov  cl,5
        shr  ax,cl              ; AX = h * 360 / 256: degrees
        mov  cl,3               ; 045
        add  bx,4
        mov  dx,3
        call FNT_NUMZ
        mov  al,FNT_LHUD        ; the draw mode's name, right-aligned
        call FNT_LOOK
        mov  byte [fnt_col],14
        mov  bl,[mode]
        xor  bh,bh
        shl  bx,1               ; a word a name
        mov  si,[t_modes+bx]
        mov  bx,315
        mov  dx,5
        call FNT_RIGHT
        mov  byte [fnt_col],7   ; the keys, grey
        mov  si,t_help
        mov  bx,4
        mov  dx,191
        call FNT_HUD
        ret

; ---- FLOOR: a grid of 3D lines round the ship, snapped to GRIDS -----------
FLOOR:  mov  ax,[shipx]
        and  ax,-GRIDS          ; the grid line west of the ship
        mov  [gx0],ax
        mov  ax,[shipz]
        and  ax,-GRIDS
        mov  [gz0],ax
        mov  word [gk],-GRIDN
.l:     mov  ax,[gk]
        mov  cx,GRIDS
        imul cx                 ; AX = k*GRIDS (|k| <= 8: fits)
        mov  bx,ax
        add  ax,[gx0]           ; ---- a line north-south at x0 + k*S ----
        mov  [r3_x0],ax
        mov  [r3_x1],ax
        mov  ax,[gz0]
        sub  ax,GRIDN*GRIDS
        mov  [r3_z0],ax
        mov  ax,[gz0]
        add  ax,GRIDN*GRIDS
        mov  [r3_z1],ax
        mov  word [r3_y0],0
        mov  word [r3_y1],0
        mov  al,8               ; dark grey
        call R3_EDGE
        mov  ax,bx              ; ---- and east-west at z0 + k*S ----
        add  ax,[gz0]
        mov  [r3_z0],ax
        mov  [r3_z1],ax
        mov  ax,[gx0]
        sub  ax,GRIDN*GRIDS
        mov  [r3_x0],ax
        mov  ax,[gx0]
        add  ax,GRIDN*GRIDS
        mov  [r3_x1],ax
        mov  al,8
        call R3_EDGE
        inc  word [gk]
        cmp  word [gk],GRIDN
        jle  .l
        ret

; ---- OBJECTS: the ship and the blocks, far to near ------------------------
;  An object: dw x, y, z, yaw, vertices, faces, count of vertices, of faces.
;  The ship's place is copied in from shipx/shipz/shiph each frame.
OBJECTS:mov  ax,[shipx]
        mov  [OBJS],ax
        mov  ax,[shipz]
        mov  [OBJS+4],ax
        mov  ax,[shiph]
        mov  [OBJS+6],ax
        xor  si,si              ; the keys: |dx|+|dz| from the eye
        xor  di,di
.k:     mov  ax,[OBJS+si]
        sub  ax,[r3_camx]
        jns  .k1
        neg  ax
.k1:    mov  bx,[OBJS+si+4]
        sub  bx,[r3_camz]
        jns  .k2
        neg  bx
.k2:    add  ax,bx              ; (a word: the scene is small)
        mov  [okey+di],ax
        mov  [oord+di],si
        add  si,16
        add  di,2
        cmp  di,OBJN*2
        jb   .k
        mov  si,2               ; insertion sort, farthest first
.i:     mov  ax,[okey+si]
        mov  dx,[oord+si]
        mov  di,si
.j:     or   di,di
        jz   .put
        cmp  [okey+di-2],ax
        jae  .put
        mov  bx,[okey+di-2]
        mov  [okey+di],bx
        mov  bx,[oord+di-2]
        mov  [oord+di],bx
        sub  di,2
        jmp  .j
.put:   mov  [okey+di],ax
        mov  [oord+di],dx
        add  si,2
        cmp  si,OBJN*2
        jb   .i
        xor  di,di              ; ---- and drawn ----
.d:     mov  bx,[oord+di]
        mov  ax,[OBJS+bx]
        mov  [r3_mx],ax
        mov  ax,[OBJS+bx+2]
        mov  [r3_my],ax
        mov  ax,[OBJS+bx+4]
        mov  [r3_mz],ax
        mov  ax,[OBJS+bx+6]
        mov  [r3_myaw],ax
        mov  si,[OBJS+bx+8]
        mov  cx,[OBJS+bx+12]
        mov  dx,[OBJS+bx+14]
        push di
        mov  di,[OBJS+bx+10]
        mov  al,[mode]
        call R3_MODEL
        pop  di
        add  di,2
        cmp  di,OBJN*2
        jb   .d
        ret

; SHOW - after the retrace, the buffer onto the screen
SHOW:   push ds
        mov  dx,3DAh
.w1:    in   al,dx
        test al,8
        jnz  .w1
.w2:    in   al,dx
        test al,8
        jz   .w2
        mov  ax,0A000h
        mov  es,ax
        mov  ds,[buf]
        xor  si,si
        xor  di,di
        mov  cx,32000
        rep  movsw
        pop  ds
        ret

TICK:   push es
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:046Ch]
        pop  es
        ret

; ---- the keyboard: our own INT 9, one byte a scan code, 1 while held ---------
KEYON:  push es
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:9*4]
        mov  [oldi9],ax
        mov  ax,[es:9*4+2]
        mov  [oldi9+2],ax
        cli
        mov  word [es:9*4],KBINT
        mov  [es:9*4+2],cs
        sti
        mov  byte [kon],1
        pop  es
        ret
KEYOFF: cmp  byte [kon],0
        je   .x
        push es
        xor  ax,ax
        mov  es,ax
        cli
        mov  ax,[oldi9]
        mov  [es:9*4],ax
        mov  ax,[oldi9+2]
        mov  [es:9*4+2],ax
        sti
        mov  byte [kon],0
        pop  es
.x:     ret
KBINT:  push ax                 ; from EXAMPLES\RELIEF.ASM KBINT
        push bx
        push ds
        mov  ax,cs
        mov  ds,ax
        in   al,60h             ; the scan code
        mov  ah,al
        and  al,7Fh
        mov  bl,al
        xor  bh,bh
        test ah,80h             ; bit 7: released
        jnz  .up
        mov  byte [KEYS+bx],1
        jmp  .eoi
.up:    mov  byte [KEYS+bx],0
.eoi:   in   al,61h             ; acknowledge the keyboard (as the BIOS)
        mov  ah,al
        or   al,80h
        out  61h,al
        mov  al,ah
        out  61h,al
        mov  al,20h
        out  20h,al             ; end of interrupt
        pop  ds
        pop  bx
        pop  ax
        iret

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

; SHOT - under /S: the last frame (64000 bytes) and the DAC (768) into SHOT.RAW
SHOT:   cmp  byte [shot],0
        je   .r
        push ds
        mov  dx,3C7h
        xor  al,al
        out  dx,al              ; read the DAC from entry 0
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
        int  21h                ; create SHOT.RAW
        jc   .x
        mov  bx,ax
        mov  ds,[buf]
        xor  dx,dx
        mov  cx,64000
        mov  ah,40h
        int  21h                ; the pixels
        pop  ds
        push ds
        mov  dx,dac
        mov  cx,768
        mov  ah,40h
        int  21h                ; the palette
        mov  ah,3Eh
        int  21h
.x:     pop  ds
.r:     ret

PUTN:   or   ax,ax              ; AX signed, in decimal on DOS's output
        jns  .p
        push ax
        mov  dl,'-'
        mov  ah,2
        int  21h
        pop  ax
        neg  ax                 ; |AX|
.p:     xor  cx,cx
        mov  bx,10
.d:     xor  dx,dx
        div  bx                 ; AX = /10, DX = the digit
        push dx
        inc  cx
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
kon     db   0
mode    db   0                  ; 0 filled, 1 wire, 2 filled + outline
spwas   db   0
buf     dw   0
t0      dw   0
frames  dw   0
tmp     dw   0
tmp2    dw   0
shipx   dw   0                  ; the ship: where, which way
shipz   dw   0
shiph   dw   0
gx0     dw   0                  ; FLOOR's scratch
gz0     dw   0
gk      dw   0
okey    dw   OBJN dup(0)        ; OBJECTS: distances and order
oord    dw   OBJN dup(0)
oldi9   dw   0,0
KEYS    db   128 dup(0)
fshot   db   'SHOT.RAW',0
dac     db   768 dup(0)

; the objects: x, y, z, yaw, vertex table, face table, vertices, faces
OBJS    dw     0,  40,    0,  0, SHIPV, SHIPF, SHIPNV, SHIPNF
        dw  -600, 100,  900, 20, BLOCKV, BLOCKF, 8, 6
        dw   700, 100,  700, 40, BLOCKV, BLOCKF, 8, 6
        dw  -500, 100, -800, 60, BLOCKV, BLOCKF, 8, 6
        dw   800, 100, -600, 90, BLOCKV, BLOCKF, 8, 6

; THE SHIP: a dart, nose +z. Five corners, five faces (four triangles).
SHIPNV  = 5
SHIPNF  = 5
SHIPV   dw    0,  0, 120        ; 0 the nose
        dw  -90,  0, -60        ; 1 the left wing tip
        dw   90,  0, -60        ; 2 the right one
        dw    0, 40, -60        ; 3 the fin's top
        dw    0,-15, -60        ; 4 the belly
SHIPF   db 0,1,3,3, 11          ; top left
        db 0,3,2,2, 3           ; top right
        db 0,4,1,1, 1           ; under left
        db 0,2,4,4, 9           ; under right
        db 1,3,2,4, 12          ; the back
; A BLOCK: a cube of +-100
BLOCKV  dw -100,-100,-100,  100,-100,-100,  100, 100,-100, -100, 100,-100
        dw -100,-100, 100,  100,-100, 100,  100, 100, 100, -100, 100, 100
BLOCKF  db 0,1,2,3, 6
        db 5,4,7,6, 6
        db 4,0,3,7, 2
        db 1,5,6,2, 2
        db 3,2,6,7, 14
        db 4,5,1,0, 8

t_name  db   'Ship 3D',0        ; the title card's words (R_TITLE TTLCARD)
t_sub   db   'steer between blocks',0
t_keys  db   'Left Right',0,'turn',0 ; the key, what it does...
        db   'Up Down',0,'go',0
        db   'Space',0,'the look',0
        db   'Esc',0,'quit',0
        db   0                  ; ...an empty key ends them
t_hdg   db   'HDG',0
t_help  db   'ARROWS STEER   SPACE THE LOOK   ESC QUITS',0
t_modes dw   t_m0,t_m1,t_m2     ; [mode]'s names
t_m0    db   'FILLED',0
t_m1    db   'WIRE',0
t_m2    db   'FILLED + OUTLINE',0
tt0     dw   0                  ; TITLE: the tick it began
t_res   db   'T_OBJ3D: frames $'
t_flt   db   ', divide faults $'
t_hd    db   ', heading $'
t_nl    db   13,10,'$'
t_pass  db   'PASS T_OBJ3D steered on its own and quit',13,10,'$'
t_fail  db   'FAIL T_OBJ3D (no frames, faults, or it never moved)',13,10,'$'
t_nomem db   'T_OBJ3D: no memory for the buffer',13,10,'$'

        include '..\..\KIT\LIB\K_3D.INC'
        include '..\..\KIT\LIB\K_FONT.INC' ; the good letters (FNT_*)
        include '..\..\KIT\REC\R_TITLE.ASM' ; TTLCARD, the title card
