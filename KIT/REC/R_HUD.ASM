; ============================================================================
;  R_HUD.ASM - KIT recipe: the things a game's head-up display is made of.
;
;  A RECIPE, NOT A PROGRAM: copy the fragment you want into your program
;  (after its way out, with the LIB files it names) and change the numbers.
;  KIT\TEST\DHUD.ASM includes this file whole and proves every fragment.
;
;    HUDBAR    a segmented bar gauge (fuel, health, ammo): green, yellow
;              under half, red under a quarter, dark segments for what is gone
;    HUDBLINK  CF = 1 in the lit part of a blink: three seconds on, one off -
;              a real modulo of the BIOS tick, not a bit of it, so the duty
;              cycle can be anything
;    HUDWARN   a warning that blinks by HUDBLINK, centred, ringed
;    HUDPOPADD / HUDPOPDRAW   floating "+N" / "-N" over a thing that scored:
;              rises a pixel every three ticks, gold or red, gone after 1.6 s
;
;  needs: K_DRAW.INC (DRW_RECT, drw_col), K_TEXT.INC (TXT_CENTER, TXT_CHAR,
;         TXT_NUM and the txt_ look); the time is the caller's BIOS tick
;         (K_TIME's TIM_TICK, or [0040:006Ch]) passed in AX.
; ============================================================================

; ----------------------------------------------------------------------
;@ HUDBAR     segmented bar gauge: CX of DX at (AX,BX), [hudnseg] segments
;  in:  AX = x, BX = y, CX = the value, DX = the full value (0: an empty
;       gauge), [hudnseg] segments, [hudsw] x [hudsh] each, a gap of 1
;  out: -
;  needs: K_DRAW DRW_RECT
;  from: new (the bar every HUD here draws by hand, made a contract);
;        the lit count is value * segments / full: 32-bit through DX, the
;        value clamped to the full first so the quotient fits, and a full
;        of 0 never reaches the DIV
; ----------------------------------------------------------------------
HUDBAR:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        mov  si,ax              ; SI = x of the next segment
        mov  di,bx              ; DI = y
        xor  ax,ax              ; AX = segments lit, 0 if no full
        or   dx,dx
        jz   .lit
        cmp  cx,dx              ; more than full?
        jbe  .v
        mov  cx,dx              ;   full it is
.v:     mov  bx,dx              ; BX = the full value (not 0)
        mov  ax,cx
        mul  word [hudnseg]     ; DX:AX = value * segments
        div  bx                 ; AX = lit segments, 0..segments
        or   ax,ax              ; a little left must still show...
        jnz  .lit
        or   cx,cx
        jz   .lit
        inc  ax                 ; ...as one segment
.lit:   mov  [hudlit],ax
        mov  bl,10              ; colour: green
        mov  dx,[hudnseg]
        shr  dx,1               ; DX = half the segments
        cmp  ax,dx
        jae  .col
        mov  bl,14              ; under half: yellow
        shr  dx,1               ; DX = a quarter
        cmp  ax,dx
        jae  .col
        mov  bl,12              ; under a quarter: red
.col:   mov  [hudcol],bl
        xor  cx,cx              ; CX = the segment
.seg:   cmp  cx,[hudnseg]
        jae  .done
        mov  al,[hudcol]
        cmp  cx,[hudlit]        ; lit?
        jb   .c
        mov  al,[huddark]       ;   no: the empty colour
.c:     mov  [drw_col],al
        push cx
        mov  ax,si              ; x
        mov  bx,di              ; y
        mov  cx,[hudsw]         ; width
        mov  dx,[hudsh]         ; height
        call DRW_RECT
        pop  cx
        add  si,[hudsw]
        inc  si                 ; x += width + the gap
        inc  cx
        jmp  .seg
.done:  pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
hudnseg dw 10                   ; segments
hudsw   dw 6                    ; a segment's width
hudsh   dw 5                    ; ...and height
huddark db 8                    ; the colour of what is gone
hudlit  dw 0
hudcol  db 0

; ----------------------------------------------------------------------
;@ HUDBLINK   CF = 1 while a blink is lit: tick mod [hudbper] < [hudbon]
;  in:  AX = the BIOS tick, [hudbper] the period in ticks (not 0),
;       [hudbon] how many of them it is lit (default 73 and 55: 3 s, 1 s)
;  out: CF = 1 lit, CF = 0 dark
;  needs: -
;  from: GAMES\OWLFLY3\SRC\UI.INC:663-695 SPECTXTF ("it breathes rather
;        than flashes": a real modulo, not a bit of the counter)
; ----------------------------------------------------------------------
HUDBLINK:
        push ax
        push bx
        push dx
        xor  dx,dx              ; DX:AX = the tick
        mov  bx,[hudbper]
        or   bx,bx
        jnz  .d
        inc  bx                 ; a period of 0 would fault: 1
.d:     div  bx                 ; DX = tick mod period
        cmp  dx,[hudbon]        ; CF = 1 while below the lit part
        pop  dx
        pop  bx
        pop  ax
        ret
hudbper dw 73                   ; 73 ticks: 4.0 s the cycle...
hudbon  dw 55                   ; ...55 of them lit: 3.0 s

; ----------------------------------------------------------------------
;@ HUDWARN    warning string SI centred at y DX, blinking by HUDBLINK
;  in:  SI = the string, DX = y, AX = the BIOS tick
;  out: - (nothing drawn in the dark part)
;  needs: K_TEXT TXT_CENTER (ringed, red: the txt_ look is put back after)
;  from: GAMES\OWLFLY3\SRC\UI.INC:669-698 SPECTXTF
; ----------------------------------------------------------------------
HUDWARN:
        call HUDBLINK
        jnc  .r                 ; the dark part
        push ax
        push bx
        mov  al,[txt_col]
        mov  ah,[txt_style]
        push ax                 ; the look, to put back
        mov  byte [txt_col],12  ; red...
        mov  byte [txt_style],2 ; ...ringed, it reads on anything
        mov  bx,160
        call TXT_CENTER
        pop  ax
        mov  [txt_col],al
        mov  [txt_style],ah
        pop  bx
        pop  ax
.r:     ret

; ----------------------------------------------------------------------
;@ HUDPOPADD  start a floating "+N" (or "-N") at (BX,DX), the tick AX
;  in:  AX = the BIOS tick now, CX = the signed value, BX = its centre x,
;       DX = its bottom y (over the head of what scored)
;  out: - (the oldest is replaced when all HUDPOPN slots are busy)
;  needs: HUDPOPDRAW every frame
;  from: GAMES\MULTSOK2\SCENE.INC:2260-2345 the popups + POPNUM
; ----------------------------------------------------------------------
HUDPOPN = 8                     ; slots
HUDPOPT = 29                    ; ticks a popup lives: 1.6 s
HUDPOPS = 8                     ; bytes a slot: dw tick, x, y, value
HUDPOPADD:
        push si
        push di
        mov  si,hudpops
        mov  di,si              ; DI = the oldest found so far
.f:     cmp  word [si+6],0      ; a free slot? (value 0 = free)
        je   .put
        push ax
        push bx
        mov  bx,ax
        sub  bx,[si]            ; BX = this one's age
        push bx
        mov  bx,ax
        sub  bx,[di]            ; BX = the oldest's age
        pop  ax                 ; AX = this one's age
        cmp  ax,bx
        jbe  .o
        mov  di,si              ; older: the one to replace
.o:     pop  bx
        pop  ax
        add  si,HUDPOPS
        cmp  si,hudpops+HUDPOPN*HUDPOPS
        jb   .f
        mov  si,di              ; none free: the oldest goes
.put:   mov  [si],ax            ; its start
        mov  [si+2],bx          ; x
        mov  [si+4],dx          ; y
        mov  [si+6],cx          ; the value (0 is never shown)
        pop  di
        pop  si
        ret

; ----------------------------------------------------------------------
;@ HUDPOPDRAW draw the live popups for the tick AX, retire the old ones
;  in:  AX = the BIOS tick now
;  out: -
;  needs: K_TEXT TXT_CHAR, TXT_NUM (4x6, shadowed: the look is
;         put back after)
;  from: GAMES\MULTSOK2\SCENE.INC:2260-2345 (rising a pixel every three
;        ticks: the byte DIV there, made a word DIV here - an age past
;        767 ticks would overflow AL)
; ----------------------------------------------------------------------
HUDPOPDRAW:
        push ax
        push bx
        push cx
        push dx
        push si
        mov  [hudnow],ax
        mov  al,[txt_font]
        mov  ah,[txt_style]
        push ax                 ; the look, to put back
        mov  al,[txt_col]
        push ax
        mov  byte [txt_font],1  ; the 4x6 letters
        mov  byte [txt_style],1 ; with a shadow
        mov  si,hudpops
.p:     mov  cx,[si+6]          ; CX = the value
        jcxz .n                 ; free
        mov  ax,[hudnow]
        sub  ax,[si]            ; AX = the age in ticks
        cmp  ax,HUDPOPT
        jb   .live
        mov  word [si+6],0      ; shown long enough: free
        jmp  .n
.live:  xor  dx,dx
        mov  bx,3
        div  bx                 ; AX = pixels risen: one every 3 ticks
        mov  dx,[si+4]
        sub  dx,ax              ; DX = y, rising
        sub  dx,5               ; the letters' top: 5 above the bottom
        mov  bx,[si+2]          ; BX = the centre x
        mov  byte [txt_col],14  ; a gain: gold
        mov  al,'+'
        or   cx,cx
        jns  .s
        neg  cx                 ; CX = the size
        mov  byte [txt_col],12  ; a loss: red
        mov  al,'-'
.s:     sub  bx,4               ; the sign and one digit: 8 wide
        cmp  cx,10
        jb   .w
        sub  bx,2               ; two digits: 12
        cmp  cx,100
        jb   .w
        sub  bx,2               ; three: 16
        cmp  cx,1000
        jb   .w
        sub  bx,2               ; four or more
.w:     call TXT_CHAR           ; the sign
        mov  ax,cx
        call TXT_NUM            ; the number
.n:     add  si,HUDPOPS
        cmp  si,hudpops+HUDPOPN*HUDPOPS
        jb   .p
        pop  ax
        mov  [txt_col],al
        pop  ax
        mov  [txt_font],al
        mov  [txt_style],ah
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
hudnow  dw 0
hudpops db HUDPOPN*HUDPOPS dup(0)
