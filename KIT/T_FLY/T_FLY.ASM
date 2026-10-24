; ============================================================================
;@ T_FLY      fly over a generated island: filled terrain, bank-and-turn, crash, FPS
;  T_FLY.ASM - KIT template: a flight over an island made from a seed. The
;  ground is filled quads far to near (R_TERRDR), the sky and ground split
;  along the banked horizon (R_HORIZ), the flight banks into its turns
;  (R_FLIGHT), and the ground is the ground (R_GROUND): fly into a hill
;  and the wreck sits there two seconds, then you are up again. The frames
;  a second are top left.
;
;      LEFT / RIGHT  turn (and bank)
;      DOWN / UP     pull back to climb, push to dive
;      ESC           back to DOS
;
;  COPY IT: A:\MY\NAME\NAME.ASM - the include paths hold from there. Grow
;  it: GND_NR below is the view's reach (12 nodes; 24 is lesson 22's and a
;  quarter of the speed); add R_STARS for a night, R_BOX3D for a town,
;  K_3D's R3_MODEL for things that fly; copy a recipe into your file when
;  you want to change it.
;  LETTERS: K_FONT's. TITLE is R_TITLE's TTLCARD over the island flying a
;  circle (its own loop: this program has its own buffer and SHOW); TER_PAL
;  owns DAC 1..14, so the card takes fly_gold and YELC from the default
;  palette's 32..255 (ttl_ramp, ttl_keyc, ttl_hotc). HUD: FPS and the keys
;  in FNT_HUD's ringed 4x6, the count in FNT_LSCORE digits, CRASH FNT_LFIRE.
;  /AUTO (the kit's test run): the title 12 ticks, then flies a fixed island by itself for ~2 s,
;  quits, and prints what happened on DOS's output.
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

GND_NR  = 12                    ; the ground reaches 12 nodes out
SC_ESC  = 01h                   ; scan codes
SC_UP   = 48h
SC_DN   = 50h
SC_LF   = 4Bh
SC_RT   = 4Dh
SKYC    = 16                    ; our two colours past TER_PAL's 1..14
HAZEC   = 17

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
        xor  ax,ax              ; a new island every run...
        cmp  byte [auto],0
        je   .seed
        mov  ax,7               ; ...but the test always flies the same
.seed:  call TER_GEN
        call GNDORD             ; the ground's drawing order, once
        mov  word [r3_quit],QUIT ; a divide fault outside the 3D code: out
        call R3_TRAP            ; INT 0 caught from here
        mov  ax,0013h
        int  10h
        call TER_PAL            ; the bands 1..6, their seams 9..14
        mov  dx,3C8h
        mov  al,SKYC
        out  dx,al
        inc  dx
        mov  si,PAL2
        mov  cx,6
.p:     lodsb
        out  dx,al              ; the sky and the haze
        loop .p
        mov  byte [hzsky],SKYC
        mov  byte [hzgnd],HAZEC
        mov  word [gcsph],0     ; start over node (0,0), heading north
        call GCSPAWN
        call TITLE              ; the title card (the BIOS's keys: before
        jc   QUIT               ;  KEYON); Esc there: back to DOS
        mov  word [gcsph],0     ; the title flew a circle: start again
        call GCSPAWN
        call KEYON              ; INT 9 ours from here
        call TICK
        mov  [t0],ax
        mov  [fpst],ax

; ---- one frame ----------------------------------------------------------------
FRAME:  call STICK              ; the keys (or the script) -> the stick
        cmp  byte [gcdead],0
        jne  .nofly
        call FLIGHT             ; R_FLIGHT: move, turn, bank
.nofly: call GCCHECK            ; R_GROUND: crash, wreck, up again
        call SCENE              ; sky, haze, the island into [buf]
        call HUD
        call SHOW
        inc  word [frames]
        inc  word [fpsn]        ; ---- frames a second ----
        call TICK
        mov  bx,ax
        sub  ax,[fpst]
        cmp  ax,18
        jb   .t
        mov  [fpst],bx
        mov  ax,[fpsn]
        mov  [fpsv],ax
        mov  word [fpsn],0
.t:     cmp  byte [KEYS+SC_ESC],0
        jne  QUIT
        cmp  byte [auto],0
        je   FRAME
        call TICK
        sub  ax,[t0]
        cmp  ax,40              ; the test: ~2 s
        jb   FRAME

; ---- every way out ------------------------------------------------------------
QUIT:   mov  ax,cs              ; (R3_INT0 may jump here: our DS and stack)
        mov  ds,ax
        call KEYOFF
        call SHOT               ; /S: the last frame into SHOT.RAW
        call R3_UNTRAP
        mov  ax,0003h
        int  10h
        mov  es,[buf]
        mov  ah,49h             ; the buffer back to DOS
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
        mov  dx,t_crs
        mov  ah,9
        int  21h
        mov  ax,[gccount]
        call PUTN
        mov  dx,t_nl
        mov  ah,9
        int  21h
        mov  dx,t_pass
        cmp  word [frames],0
        je   .f
        cmp  word [r3_faults],0
        je   .ok
.f:     mov  dx,t_fail
.ok:    mov  ah,9
        int  21h
.x:     mov  ax,4C00h
        int  21h

; ---- STICK: the four stick bytes from the keys, or from the script -----------
STICK:  cmp  byte [auto],0
        jne  .auto
        mov  al,[KEYS+SC_LF]
        mov  [flleft],al
        mov  al,[KEYS+SC_RT]
        mov  [flright],al
        mov  al,[KEYS+SC_DN]    ; DOWN: the stick pulled back - climb
        mov  [flpull],al
        mov  al,[KEYS+SC_UP]
        mov  [flpush],al
        ret
.auto:  call TICK               ; the script: by the clock, not the frames
        sub  ax,[t0]
        xor  bx,bx
        mov  [flleft],bl
        mov  [flright],bl
        mov  [flpull],bl
        mov  [flpush],bl
        cmp  ax,14
        jae  .a2
        mov  byte [flright],1   ; right, climbing
        mov  byte [flpull],1
        ret
.a2:    cmp  ax,28
        jae  .a3
        mov  byte [flleft],1    ; left, level
        ret
.a3:    mov  byte [flpush],1    ; and down
        ret

; ---- SCENE: the picture of the flight into [buf] -------------------------------
SCENE:  mov  es,[buf]
        call HZPIVOT            ; R_HORIZ: sky and haze, banked
        call HZFILL
        call GNDDRAW            ; R_TERRDR: the island
        ret

; ---- TITLE: R_TITLE's card over the island, flying a circle; until Enter
;  (CF = 0) or Esc (CF = 1); /AUTO: 12 ticks. The inks: TER_PAL owns DAC
;  1..14 here, so the card's ramp and inks come from the default 32..255.
TITLE:  mov  word [ttl_name],t_name ; our words on the card
        mov  word [ttl_sub],t_sub
        mov  word [ttl_keys],t_keys
        mov  word [ttl_ramp],fly_gold ; our own gold: FNT_LTITLE's has a 6
        mov  byte [ttl_rampn],FLYGN ;  (a band of the island here)
        mov  byte [ttl_keyc],YELC
        mov  byte [ttl_hotc],YELC
        call TICK
        mov  [tt0],ax
.f:     mov  byte [flright],1   ; a slow right-hand circle
        call FLIGHT
        call SCENE
        call TICK               ; AX = the tick: PRESS ENTER blinks by it
        call TTLCARD            ; into ES = [buf]
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
.go:    mov  byte [flright],0
        clc
        ret
.esc:   stc
        ret

; ---- HUD: frames a second top left, the keys at the foot, CRASH on a wreck -
;  K_FONT's ringed letters in white and the default palette's yellow (YELC):
;  TER_PAL took DAC 1..14
HUD:    mov  es,[buf]
        mov  byte [fnt_col],15  ; the words: the fast 4x6, ringed black
        mov  byte [fnt_rc],0
        mov  si,t_fps
        mov  bx,4
        mov  dx,5
        call FNT_HUD            ; BX = past the word
        mov  al,FNT_LSCORE      ; the count: bold ringed digits
        call FNT_LOOK
        mov  byte [fnt_col],YELC
        mov  ax,[fpsv]
        mov  cl,2               ; 09
        add  bx,4
        mov  dx,3
        call FNT_NUMZ
        mov  byte [fnt_col],15
        mov  si,t_help
        mov  bx,4
        mov  dx,191
        call FNT_HUD
        cmp  byte [gcdead],0
        je   .x
        mov  al,FNT_LFIRE       ; CRASH: 8x16 x2, the fire ramp (DAC 15, 40..44,
        call FNT_LOOK           ;  112: none of them TER_PAL's), ringed
        mov  si,t_crash
        mov  bx,160
        mov  dx,84
        call FNT_CENTER
.x:     ret

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

; SHOT - under /S: the last frame (64000 bytes) and the DAC (768) into
; SHOT.RAW, for a look at the picture from outside DOS (as KIT\TEST\DDRAW)
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
        mov  ds,[buf]           ; DS = the back buffer
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
fshot   db 'SHOT.RAW',0
shot    db 0
dac     db 768 dup(0)

PUTN:   xor  cx,cx              ; AX (unsigned) in decimal on DOS's output
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
kon     db   0
buf     dw   0
t0      dw   0
frames  dw   0
fpsn    dw   0
fpst    dw   0
fpsv    dw   0
oldi9   dw   0,0
KEYS    db   128 dup(0)
PAL2    db   20,34,58           ; 16 the sky
        db   30,36,40           ; 17 the haze past the ground's reach
YELC    = 44                    ; the default palette's yellow (DAC 1..14 are TER_PAL's)
FLYGN   = 8
fly_gold db  15,44,44,43,43,42,42,41 ; the title's ramp: white, yellow, orange
t_name  db   'Island',0         ; the title card's words (R_TITLE TTLCARD)
t_sub   db   'fly a generated land',0
t_keys  db   'Left Right',0,'turn, bank',0 ; the key, what it does...
        db   'Down',0,'pull back: climb',0
        db   'Up',0,'push: dive',0
        db   'Esc',0,'quit',0
        db   0                  ; ...an empty key ends them
t_fps   db   'FPS',0
t_help  db   'ARROWS: LEFT RIGHT TURN, DOWN CLIMBS, UP DIVES   ESC QUITS',0
t_crash db   'CRASH',0
tt0     dw   0                  ; TITLE: the tick it began
t_res   db   'T_FLY: frames $'
t_flt   db   ', divide faults $'
t_crs   db   ', crashes $'
t_nl    db   13,10,'$'
t_pass  db   'PASS T_FLY flew on its own and quit',13,10,'$'
t_fail  db   'FAIL T_FLY (no frames, or divide faults)',13,10,'$'
t_nomem db   'T_FLY: no memory for the buffer',13,10,'$'

        include '..\..\KIT\LIB\K_3D.INC'
        include '..\..\KIT\LIB\K_TERR.INC'
        include '..\..\KIT\REC\R_TERRDR.ASM'
        include '..\..\KIT\REC\R_FLIGHT.ASM'
        include '..\..\KIT\REC\R_GROUND.ASM'
        include '..\..\KIT\REC\R_HORIZ.ASM'
        include '..\..\KIT\LIB\K_FONT.INC' ; the good letters (FNT_*)
        include '..\..\KIT\REC\R_TITLE.ASM' ; TTLCARD, the title card
