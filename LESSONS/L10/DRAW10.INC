; ============================================================================
;  DRAW10.INC - the small routines lesson 10 leans on.
;
;  Lesson 8's toolbox, carried forward - and lesson 8's LINE itself, byte
;  for byte: the routine this course spent a whole hour earning is now
;  simply a tool, which is the point of earning things. Two newcomers:
;  Vsync waits for the tube's vertical retrace, so a frame is wiped while
;  the beam is not looking; KeyChk asks the keyboard WITHOUT waiting, so
;  the spin frames can turn until a key says stop.
; ============================================================================

attr    db 07h                  ; the colour the next character is written in
dcol    db 15                   ; the colour Dot stamps with

; ---- one character at ES:DI, in [attr], and DI moves on --------------------
PutC:   mov  ah, [attr]
        stosw                   ; character AND colour, in one instruction
        ret

; ---- an asciiz string at ES:DI ---------------------------------------------
PutS:   lodsb
        or   al, al
        jz   .done
        mov  ah, [attr]
        stosw
        jmp  PutS
.done:  ret

; ---- the whole text screen, blank -------------------------------------------
TClear: xor  di, di
        mov  cx, 80*25
        mov  ax, 0720h          ; a space, in grey on black
        rep  stosw
        ret

; ---- the whole graphics screen, black --------------------------------------
GClear: xor  di, di
        xor  ax, ax
        mov  cx, W*H/2          ; words, because STOSW writes two bytes
        rep  stosw
        ret

; ---- no cursor, so nothing blinks through the explanation ------------------
TextOff:
        mov  ah, 1
        mov  cx, 2000h          ; bit 5 of CH turns it off
        int  10h
        ret

; ---- wait for a key ---------------------------------------------------------
Key:    mov  ah, 0
        int  16h
        ret

; ---- ask for a key, but do not wait -----------------------------------------
;  AL = 1 a key was hit (and is consumed), 0 the keyboard is quiet. The
;  spin frames call this once a frame: the picture turns until told not to.
KeyChk: mov  ah, 1
        int  16h
        jz   .no
        mov  ah, 0
        int  16h                ; take it, or it waits in the buffer forever
        mov  al, 1
        ret
.no:    xor  al, al
        ret

; ---- wait for the beam to fly home ------------------------------------------
;  Port 3DAh, bit 3: the VERTICAL RETRACE - the beam is off the glass,
;  climbing back to the top left. Wipe and redraw NOW and the eye never
;  sees the half-drawn picture. First wait OUT any retrace already
;  running, then wait for the next one to begin: a whole frame, every time.
Vsync:  push ax
        push dx
        mov  dx, 3DAh
.out:   in   al, dx
        test al, 8
        jnz  .out
.in:    in   al, dx
        test al, 8
        jz   .in
        pop  dx
        pop  ax
        ret

; A fifth of a second, off the BIOS tick at 0040:006C - the same clock the
; whole PC counts on, eighteen and a bit times a second.
Hold:   push es
        mov  ax, 0040h
        mov  es, ax
        mov  bx, [es:6Ch]
        add  bx, 4
.wait:  mov  ax, [es:6Ch]
        cmp  ax, bx
        jb   .wait
        pop  es
        ret

; ---- the hint at the bottom of a text frame --------------------------------
Bottom: mov  si, t_key
        mov  di, 23*ROW + 34*2
        mov  byte [attr], 08h
        call PutS
        mov  byte [attr], NORM
        ret

; ---- Dot: a vertex made visible - five pixels in [dcol] --------------------
;  in: AX = x, BX = y. Offset = y * 320 + x: lesson 7's formula, every time.
Dot:    push ax
        mov  ax, bx
        mov  bx, W
        mul  bx                 ; y * 320...
        pop  bx
        add  ax, bx             ; ...+ x
        mov  di, ax
        mov  al, [dcol]
        mov  [es:di], al
        mov  [es:di-1], al
        mov  [es:di+1], al
        mov  [es:di-W], al
        mov  [es:di+W], al
        ret

; ============================================================================
;  The line - LESSON 8's, byte for byte (SLANT.ASM, frame 5). From
;  (p0x,p0y) to (p1x,p1y) in [col]: one routine for every direction,
;  because the two directions it must remember are decided once and
;  WRITTEN INTO the two ADDs of the loop - self-modifying code, doing the
;  day job it was invented for. The rule rides with it: patch, then jump.
; ============================================================================
p0x     dw 0                    ; the line: from (p0x,p0y) to (p1x,p1y)
p0y     dw 0
p1x     dw 0
p1y     dw 0
adx     dw 0                    ; |dx|, |dy| - the two distances
ady     dw 0
stx     dw 0                    ; and the two signed steps: +-1, +-320
sty     dw 0
dmaj    dw 0                    ; the long distance drives the loop...
dmin    dw 0                    ; ...the short one feeds the debt
col     db 15

Line:
        mov  ax, [p1x]
        sub  ax, [p0x]          ; dx, signed...
        mov  bx, 1              ; ...and the step right that goes with it
        or   ax, ax
        jns  .dxp
        neg  ax                 ; the DISTANCE must be positive; its SIGN
        mov  bx, -1             ;  moves into the step instead
.dxp:   mov  [adx], ax
        mov  [stx], bx
        mov  ax, [p1y]
        sub  ax, [p0y]          ; dy, signed, the same way...
        mov  bx, W              ; ...but ITS step is a whole row
        or   ax, ax
        jns  .dyp
        neg  ax
        mov  bx, -W
.dyp:   mov  [ady], ax
        mov  [sty], bx

        ; ---- which distance is longer DRIVES the loop; the other one
        ; feeds the debt. Both answers are written into the code.
        mov  ax, [adx]
        cmp  ax, [ady]
        jb   .ymaj
        mov  [dmaj], ax         ; x-major: step right every pixel...
        mov  ax, [ady]
        mov  [dmin], ax
        mov  ax, [stx]
        mov  [.majs+2], ax      ; ...so the driving ADD gets +-1
        mov  ax, [sty]
        mov  [.mins+2], ax      ; ...and the debt ADD gets +-320
        jmp  .go
.ymaj:  mov  [dmin], ax         ; y-major: the roles swap, nothing else
        mov  ax, [ady]
        mov  [dmaj], ax
        mov  ax, [sty]
        mov  [.majs+2], ax
        mov  ax, [stx]
        mov  [.mins+2], ax
.go:    jmp  short .fl          ; THE RULE: patch, then jump
.fl:
        mov  ax, [p0y]          ; where the line starts, lesson 7's formula
        mov  bx, W
        mul  bx                 ; y * 320 ...
        add  ax, [p0x]          ; ... + x
        mov  di, ax
        mov  bl, [col]
        mov  cx, [dmaj]
        inc  cx                 ; both ends belong to the line
        xor  dx, dx             ; DX = the debt, starting clean
.px:    mov  [es:di], bl
        add  dx, [dmin]         ; every step, the debt grows by the short
        cmp  dx, [dmaj]         ;  distance - reached the long one?
        jb   .nod
        sub  dx, [dmaj]         ; paid off...
.mins:  add  di, W              ; ...with one sideways step   (REWRITTEN)
.nod:
.majs:  add  di, W              ; the driving step, every pixel (REWRITTEN)
        loop .px
        ret
