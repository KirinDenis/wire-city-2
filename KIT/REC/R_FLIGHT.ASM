; ============================================================================
;  R_FLIGHT.ASM - recipe: bank-and-turn flight, the whole feel of OWL FLY's
;  first island in four rules and no physics: the eye travels at a fixed
;  speed along its heading; LEFT/RIGHT turn it and the world banks into the
;  turn (the roll chases the stick and falls back to level); the stick
;  PULLED (down arrow) climbs, pushed dives; a ceiling.
;
;        ...each frame, the four stick bytes set from your keyboard:
;        mov  byte [flleft],0    ; 1 while LEFT is held
;        ...                     ; flright, flpull (DOWN), flpush (UP)
;        call FLIGHT             ; moves and turns the K_3D camera
;        ...draw (the camera is already set: no R3_CAMERA needed)
;
;  The camera IS the aeroplane: FLIGHT changes r3_camx/r3_camy/r3_camz,
;  heading and roll, then reruns the trig (R3_TRIG). Start it with
;  R3_CAMERA once (where, which way). There is no floor here: R_GROUNDC
;  ends the flight at the ground.
;
;  copy: FLIGHT and its bytes.
;  define before (optional): FLSPEED (48 units a frame), FLCLIMB (20),
;         FLTURN (2 of 256 a frame), FLBANK (30, the most roll), FLBSTEP
;         (3, how fast the roll gets there), FLCEIL (6000, the ceiling)
;  calls: K_3D (R3_TRIG, hsin/hcos, the camera)
;  from: EXAMPLES\RELIEF.ASM PHYS:354-453 + STEPXZ:565-577 (LESSONS\L20,
;        L21: CITY.ASM's INPUT)
; ============================================================================

if ~ defined FLSPEED | defined fl_d1
FLSPEED = 48                    ; forward units a frame
fl_d1   = 1
end if
if ~ defined FLCLIMB | defined fl_d2
FLCLIMB = 20                    ; climb/dive units a frame
fl_d2   = 1
end if
if ~ defined FLTURN | defined fl_d3
FLTURN  = 2                     ; heading change a frame (256 = a circle)
fl_d3   = 1
end if
if ~ defined FLBANK | defined fl_d4
FLBANK  = 30                    ; the most it leans into a turn
fl_d4   = 1
end if
if ~ defined FLBSTEP | defined fl_d5
FLBSTEP = 3                     ; how fast it gets there - and back
fl_d5   = 1
end if
if ~ defined FLCEIL | defined fl_d6
FLCEIL  = 6000                  ; the ceiling
fl_d6   = 1
end if

flleft  db 0                    ; the stick: 1 while held
flright db 0
flpull  db 0                    ; DOWN arrow: pull back, climb
flpush  db 0                    ; UP arrow: push, dive
flturn  dw 0                    ; -1, 0, 1: the way the stick is held

;@ FLIGHT     one frame of bank-and-turn flight: moves and turns the K_3D camera
; ---- FLIGHT: one frame of it. Keeps every register.
FLIGHT: push ax
        push bx
        push dx
        mov  word [flturn],0
        cmp  byte [flleft],0
        je   .nl
        sub  word [heading],FLTURN      ; turn left
        and  word [heading],255         ; a byte IS the circle
        mov  word [flturn],-1
.nl:    cmp  byte [flright],0
        je   .nr
        add  word [heading],FLTURN      ; turn right
        and  word [heading],255
        mov  word [flturn],1
.nr:    mov  ax,[roll]          ; ---- the bank chases the stick ----
        cmp  word [flturn],0
        je   .decay
        jg   .bankr
        sub  ax,FLBSTEP         ; leaning left
        cmp  ax,-FLBANK
        jge  .bset
        mov  ax,-FLBANK
        jmp  .bset
.bankr: add  ax,FLBSTEP         ; leaning right
        cmp  ax,FLBANK
        jle  .bset
        mov  ax,FLBANK
        jmp  .bset
.decay: or   ax,ax              ; ---- and falls back to level ----
        jz   .bset
        jg   .dpos
        add  ax,FLBSTEP         ; roll was negative: up toward 0
        cmp  ax,0
        jle  .bset
        xor  ax,ax              ; overshot: exactly level
        jmp  .bset
.dpos:  sub  ax,FLBSTEP         ; roll was positive: down toward 0
        cmp  ax,0
        jge  .bset
        xor  ax,ax
.bset:  mov  [roll],ax
        cmp  byte [flpull],0    ; ---- the stick back: CLIMB ----
        je   .nu
        add  word [r3_camy],FLCLIMB
.nu:    cmp  byte [flpush],0    ; the stick forward: dive
        je   .nd
        sub  word [r3_camy],FLCLIMB
.nd:    cmp  word [r3_camy],FLCEIL
        jle  .c1
        mov  word [r3_camy],FLCEIL      ; the ceiling
.c1:    call R3_TRIG            ; hsin/hcos for the new heading, the roll
        mov  ax,[hsin]          ; ---- and always forward ----
        mov  bx,FLSPEED
        imul bx                 ; DX:AX = hsin * speed
        mov  bx,256
        idiv bx                 ; AX = hsin*speed/256 (|q| <= speed)
        add  [r3_camx],ax       ; east
        mov  ax,[hcos]
        mov  bx,FLSPEED
        imul bx                 ; DX:AX = hcos * speed
        mov  bx,256
        idiv bx                 ; AX = hcos*speed/256
        add  [r3_camz],ax       ; north
        pop  dx
        pop  bx
        pop  ax
        ret
