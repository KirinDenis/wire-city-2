; ============================================================================
;  DRAW13.INC - the small routines lesson 0D leans on.
;
;  Lesson 12's toolbox with the text-screen half taken out - this lesson
;  prints no prose - and one thing added: FillR, a filled rectangle, for
;  the cube and the two fixtures.
;
;  Inside it, LESSON 8'S LINE, byte for byte, on its fourth tour of duty:
;  today it draws the pillar, the three links, the jaws and every needle.
;  Vsync waits for the tube's vertical retrace; KeyChk asks the keyboard
;  WITHOUT waiting, so a machine can work until a key says stop.
; ============================================================================

dcol    db 15                   ; the colour Plot and Dot stamp with

; ---- the whole graphics screen, black --------------------------------------
GClear: xor  di, di
        xor  ax, ax
        mov  cx, W*H/2          ; words, because STOSW writes two bytes
        rep  stosw
        ret

; ---- wait for a key ---------------------------------------------------------
Key:    mov  ah, 0
        int  16h
        ret

; ---- ask for a key, but do not wait -----------------------------------------
;  AL = 1 a key was hit (and is consumed), 0 the keyboard is quiet. Every
;  moving stage calls this once a frame: the machine works until told not to.
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

; ---- Plot: ONE pixel, in [dcol] ---------------------------------------------
;  in: AX = x, BX = y. Offset = y * 320 + x: lesson 7's formula, every time.
;  DI is saved, because the callers walk tables with it.
Plot:   push di
        push ax
        mov  ax, bx
        mov  bx, W
        mul  bx                 ; y * 320...
        pop  bx
        add  ax, bx             ; ...+ x
        mov  di, ax
        mov  al, [dcol]
        mov  [es:di], al
        pop  di
        ret

; ---- Dot: five pixels in [dcol] - a mark you can see across the room -------
;  in: AX = x, BX = y.
Dot:    push di
        push ax
        mov  ax, bx
        mov  bx, W
        mul  bx
        pop  bx
        add  ax, bx
        mov  di, ax
        mov  al, [dcol]
        mov  [es:di], al
        mov  [es:di-1], al
        mov  [es:di+1], al
        mov  [es:di-W], al
        mov  [es:di+W], al
        pop  di
        ret

; ---- FillR: a solid rectangle - the cube, and the fixtures under it --------
;  in: [frx],[fry] the top left corner, [frw],[frh] its size, [frcol] its ink.
;  One REP STOSB a row: the frame buffer is FLAT, so a rectangle is just
;  the same run of bytes, W apart, [frh] times.
frx      dw 0
fry      dw 0
frw      dw 0
frh      dw 0
frcol    db 0

;  STOSB is STOSW's byte twin, and the pair have been on duty since lesson
;  seven: store AL at ES:DI, then step DI on by one. REP repeats it CX
;  times, and CLD decided back in Boot which way DI walks - forwards.
FillR:  mov  ax, [fry]
        mov  bx, W
        mul  bx
        add  ax, [frx]
        mov  di, ax
        mov  dx, [frh]
.row:   push di
        mov  cx, [frw]
        mov  al, [frcol]
        rep  stosb              ; one row, in one instruction
        pop  di
        add  di, W
        dec  dx
        jnz  .row
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
