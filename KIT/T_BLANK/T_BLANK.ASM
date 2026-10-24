; ============================================================================
;@ T_BLANK    the smallest real-time game: 13h + back buffer + keys + fixed step
;  T_BLANK.ASM - a white dot moved by the arrows on a black field. Copy the
;  folder to A:\MY\NAME\, rename, and grow it: put the game's state where
;  the dot is, its rules in STEP, its picture in DRAW.
;
;  The shape every kit game keeps:
;    MEM_INIT  -> VGA_ON  -> KEY_ON  -> the loop  -> KEY_OFF -> VGA_OFF -> exit
;    the loop:  TIM_STEPS ticks gone by -> STEP that many times (the rules
;               run at 18.2 a second on every machine) -> DRAW -> VGA_SHOW
;  Esc quits (read from the latch: a tap at 1 fps still counts). With /AUTO
;  on the command line it quits by itself after about 2 seconds and says
;  PASS - the kit's tests run it that way.
;  Letters: K_FONT (FNT_LOOK, FNT_CENTER) - ringed, so text reads on any
;  picture; KIT\REC\R_TITLE.ASM has a whole title card when you want one.
;  Uses: K_MEM K_VGA K_KEYS K_TIME K_MATH (MTH_CLAMP) K_FONT. Build: KIT\MAKEWIN T_BLANK T_BLANK,
;  on the site: build A:\MY\NAME\NAME.ASM
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

SPEED   = 3                     ; pixels a step (a step = one BIOS tick)
DOTC    = 15                    ; the dot's colour (white in the BIOS palette)
EDGEC   = 8                     ; the frame's colour (dark grey)
AUTOT   = 36                    ; /AUTO: ticks before it quits (2 s)

start:  call GETAUTO            ; [auto] = 1 with /AUTO
        call MEM_INIT           ; our 64K kept, the rest for DOS to give
        call VGA_ON             ; mode 13h and the back buffer
        jc   nomem
        call KEY_ON             ; our keyboard: held keys and taps
        call TIM_TICK
        mov  [t0],ax            ; when the game began (for /AUTO)
        call TIM_STEPS          ; start the step count
        cmp  byte [auto],0
        je   frame
        mov  cx,4D00h           ; /AUTO: a Right arrow into the BIOS buffer -
        mov  ah,05h             ;  KEY_REMOTE holds it 20 frames, as a
        int  16h                ;  script or a replay would

frame:  call KEY_REMOTE         ; keys fed from outside (scripts) count too
        mov  al,SC_ESC
        call KEY_TAP            ; Esc pressed since the last frame?
        jnz  quit
        cmp  byte [auto],0
        je   .run
        call TIM_TICK
        sub  ax,[t0]            ; ticks since the start
        cmp  ax,AUTOT
        jae  quit               ; /AUTO: long enough
.run:   call TIM_STEPS          ; AX = steps to run now, 0..4
        mov  cx,ax
        jcxz .draw              ; no tick yet: draw again
.step:  call STEP               ; the rules, once a tick
        loop .step
.draw:  call DRAW
        call VGA_SHOW           ; the retrace, the buffer onto the screen
        inc  word [frames]      ; one more frame
        jmp  frame

quit:   call KEY_OFF            ; the BIOS gets its keyboard back
        call VGA_OFF            ; text mode 3, the buffer given back
        cmp  byte [auto],0
        je   .bye
        mov  dx,t_pass
        cmp  word [dotx],160    ; did the fed arrow move the dot right?
        ja   .say
        mov  dx,t_fail
.say:   mov  ah,9
        int  21h                ; "PASS ..." for the test run
.bye:   mov  ax,4C00h
        int  21h

nomem:  mov  dx,t_nomem         ; no memory for the buffer: say so, leave
        mov  ah,9
        int  21h
        mov  ax,4C01h
        int  21h

; ---- STEP: one tick of the rules: the dot moves by the held arrows -------
STEP:   push bx                 ; the loop around STEP counts in CX: keep it
        push cx
        mov  al,SC_UP
        call KEY_HELD
        jz   .s1
        sub  word [doty],SPEED  ; up: y -= SPEED
.s1:    mov  al,SC_DN
        call KEY_HELD
        jz   .s2
        add  word [doty],SPEED  ; down: y += SPEED
.s2:    mov  al,SC_LF
        call KEY_HELD
        jz   .s3
        sub  word [dotx],SPEED  ; left: x -= SPEED
.s3:    mov  al,SC_RT
        call KEY_HELD
        jz   .s4
        add  word [dotx],SPEED  ; right: x += SPEED
.s4:    mov  ax,[dotx]          ; keep it inside the frame
        mov  bx,2
        mov  cx,320-5
        call MTH_CLAMP          ; AX = x held to 2..315
        mov  [dotx],ax
        mov  ax,[doty]
        mov  cx,200-5
        call MTH_CLAMP          ; AX = y held to 2..195
        mov  [doty],ax
        pop  cx
        pop  bx
        ret

; ---- DRAW: the picture into the back buffer ------------------------------
DRAW:   xor  al,al
        call VGA_CLS            ; black
        push es
        mov  es,[vga_buf]       ; ES = the buffer, 320 bytes a row
        mov  al,EDGEC
        xor  di,di              ; the top row
        mov  cx,320
        rep  stosb
        mov  di,199*320         ; the bottom row
        mov  cx,320
        rep  stosb
        xor  di,di
        mov  cx,200
.side:  mov  [es:di],al         ; the left column
        mov  [es:di+319],al     ; the right column
        add  di,320             ; the next row
        loop .side
        mov  ax,[doty]
        call VGA_ROW            ; DI = y * 320
        add  di,[dotx]          ; DI = the dot's corner
        mov  al,DOTC
        mov  bx,3               ; 3 rows
.dot:   mov  cx,3               ; of 3 pixels
        rep  stosb
        add  di,320-3           ; the next row's corner
        dec  bx
        jnz  .dot
        mov  al,FNT_LBODY       ; the title line: K_FONT's 8x8 letters,
        call FNT_LOOK           ;  white,
        mov  byte [fnt_style],FNT_RING ; a black ring round each - it
        mov  byte [fnt_col],15  ;  reads over the dot and the frame alike
        mov  si,t_title
        mov  bx,160             ; centred on x 160
        mov  dx,6               ; its top
        call FNT_CENTER
        pop  es
        ret

; ---- GETAUTO: [auto] = 1 if the command line holds /AUTO -----------------
GETAUTO:mov  si,81h
        xor  ch,ch
        mov  cl,[80h]           ; the command line's length
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

dotx    dw   160                ; the dot, in pixels
doty    dw   100
t0      dw   0
frames  dw   0
auto    db   0
t_title db 'T_BLANK - arrows move, Esc quits',0
t_pass  db   'PASS T_BLANK ran in 13h and quit by itself, the fed arrow moved the dot',13,10,'$'
t_fail  db   'FAIL T_BLANK: the fed Right arrow did not move the dot',13,10,'$'
t_nomem db   'Not enough memory for the screen buffer.',13,10,'$'

        include '..\..\KIT\LIB\K_MEM.INC'
        include '..\..\KIT\LIB\K_VGA.INC'
        include '..\..\KIT\LIB\K_KEYS.INC'
        include '..\..\KIT\LIB\K_TIME.INC'
        include '..\..\KIT\LIB\K_MATH.INC'
        include '..\..\KIT\LIB\K_FONT.INC' ; the good letters (FNT_*)
