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
;  In C:   memset(screen, 0, 64000);
GClear: xor  di, di             ; DI = 0: the top-left pixel
        xor  ax, ax             ; AX = 0: two black pixels
        mov  cx, W*H/2          ; CX = 32000 words, because STOSW writes two
        rep  stosw              ; while (cx--) *es:di++ = ax
        ret                     ; return

; ---- wait for a key ---------------------------------------------------------
;  In C:   int key(void) { return get_key(); }   - waits
Key:    mov  ah, 0              ; AH = 0: BIOS 16h, service 0 - wait for a key
        int  16h                ; AL = the character, AH = the scan code
        ret                     ; return

; ---- ask for a key, but do not wait -----------------------------------------
;  AL = 1 a key was hit (and is consumed), 0 the keyboard is quiet. Every
;  moving stage calls this once a frame: the machine works until told not to.
;  In C:   int key_check(void) { if (!key_waiting()) return 0; get_key(); return 1; }
KeyChk: mov  ah, 1              ; AH = 1: service 1 - is a key waiting?
        int  16h                ; ZF set = no
        jz   .no                ;   no: return 0
        mov  ah, 0              ; AH = 0: service 0 - take it, or it waits in
        int  16h                ;  the buffer for ever
        mov  al, 1              ; AL = 1
        ret                     ; return 1
.no:    xor  al, al             ; AL = 0
        ret                     ; return 0

; ---- wait for the beam to fly home ------------------------------------------
;  Port 3DAh, bit 3: the VERTICAL RETRACE - the beam is off the glass,
;  climbing back to the top left. Wipe and redraw NOW and the eye never
;  sees the half-drawn picture. First wait OUT any retrace already
;  running, then wait for the next one to begin: a whole frame, every time.
;  In C:   while ( inp(0x3DA) & 8) ;   while (!(inp(0x3DA) & 8)) ;
Vsync:  push ax                 ; keep AX and DX for the caller
        push dx                 ; keep DX
        mov  dx, 3DAh           ; DX = 3DAh, the VGA status port
.out:   in   al, dx             ; AL = inp(0x3DA)
        test al, 8              ; bit 3 = the beam is in vertical retrace
        jnz  .out               ; while (retrace) ;   - wait it out
.in:    in   al, dx             ; AL = inp(0x3DA)
        test al, 8              ; bit 3 again
        jz   .in                ; while (!retrace) ;  - wait for the next
        pop  dx                 ; DX back
        pop  ax                 ; AX back
        ret                     ; return

; ---- Plot: ONE pixel, in [dcol] ---------------------------------------------
;  in: AX = x, BX = y. Offset = y * 320 + x: lesson 7's formula, every time.
;  DI is saved, because the callers walk tables with it.
;  In C:   screen[y * 320 + x] = dcol;
Plot:   push di                 ; keep DI for the caller
        push ax                 ; keep x
        mov  ax, bx             ; AX = y
        mov  bx, W              ; BX = 320
        mul  bx                 ; AX = y * 320
        pop  bx                 ; BX = x
        add  ax, bx             ; AX = y * 320 + x
        mov  di, ax             ; DI = the offset
        mov  al, [dcol]         ; AL = dcol
        mov  [es:di], al        ; screen[DI] = dcol
        pop  di                 ; DI back
        ret                     ; return

; ---- Dot: five pixels in [dcol] - a mark you can see across the room -------
;  in: AX = x, BX = y.
;  In C:   int o = y * 320 + x;  screen[o] = screen[o-1] = screen[o+1]
;                                = screen[o-320] = screen[o+320] = dcol;
Dot:    push di                 ; keep DI
        push ax                 ; keep x
        mov  ax, bx             ; AX = y
        mov  bx, W              ; BX = 320
        mul  bx                 ; AX = y * 320
        pop  bx                 ; BX = x
        add  ax, bx             ; AX = y * 320 + x
        mov  di, ax             ; DI = o
        mov  al, [dcol]         ; AL = dcol
        mov  [es:di], al        ; screen[o]     = dcol   the centre
        mov  [es:di-1], al      ; screen[o-1]   = dcol   left
        mov  [es:di+1], al      ; screen[o+1]   = dcol   right
        mov  [es:di-W], al      ; screen[o-320] = dcol   above
        mov  [es:di+W], al      ; screen[o+320] = dcol   below
        pop  di                 ; DI back
        ret                     ; return

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
;  In C:
;
;      void fill_rect(void)
;      {
;          unsigned char *at = screen + fry * 320 + frx;
;          for (int r = 0; r < frh; r++, at += 320)
;              memset(at, frcol, frw);                /* one row: REP STOSB */
;      }
FillR:  mov  ax, [fry]          ; AX = fry
        mov  bx, W              ; BX = 320
        mul  bx                 ; AX = fry * 320
        add  ax, [frx]          ; AX = fry * 320 + frx
        mov  di, ax             ; DI = at, the top-left corner
        mov  dx, [frh]          ; DX = frh rows to go
.row:   push di                 ; keep the row's start
        mov  cx, [frw]          ; CX = frw bytes
        mov  al, [frcol]        ; AL = frcol
        rep  stosb              ; while (cx--) *es:di++ = al: one row, one instruction
        pop  di                 ; DI = the row's start again
        add  di, W              ; at += 320: the next row
        dec  dx                 ; rows--
        jnz  .row               ; while (rows)
        ret                     ; return

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

;  In C:
;
;      void line(void)
;      {
;          int adx = abs(p1x - p0x), stx = (p1x >= p0x) ? 1 : -1;
;          int ady = abs(p1y - p0y), sty = (p1y >= p0y) ? 320 : -320;
;          int dmaj, dmin, major_step, minor_step;
;          if (adx >= ady) { dmaj = adx; dmin = ady; major_step = stx; minor_step = sty; }
;          else            { dmaj = ady; dmin = adx; major_step = sty; minor_step = stx; }
;          int at = p0y * 320 + p0x, debt = 0;
;          for (int n = dmaj + 1; n > 0; n--) {
;              screen[at] = col;
;              debt += dmin;
;              if (debt >= dmaj) { debt -= dmaj; at += minor_step; }
;              at += major_step;
;          }
;      }
;
;  What C cannot show: major_step and minor_step are not variables here.
;  They are written INTO the two ADD instructions of the loop, so the loop
;  carries no `if` about which way the line leans. THE RULE for code that
;  rewrites itself on an 8086: patch, then JUMP - the prefetch queue has
;  already fetched the old bytes, and only a jump throws them away.
Line:
        mov  ax, [p1x]          ; AX = p1x
        sub  ax, [p0x]          ; AX = dx = p1x - p0x, signed...
        mov  bx, 1              ; BX = stx = +1: ...and the step right with it
        or   ax, ax             ; dx < 0 ?
        jns  .dxp               ;   no
        neg  ax                 ;   yes: AX = -dx   the DISTANCE must be
        mov  bx, -1             ;        BX = -1    positive; its SIGN moves
.dxp:   mov  [adx], ax          ; adx = |dx|         into the step instead
        mov  [stx], bx          ; stx = +-1
        mov  ax, [p1y]          ; AX = p1y
        sub  ax, [p0y]          ; AX = dy = p1y - p0y, the same way...
        mov  bx, W              ; BX = sty = +320: ...but ITS step is a row
        or   ax, ax             ; dy < 0 ?
        jns  .dyp               ;   no
        neg  ax                 ;   yes: AX = -dy
        mov  bx, -W             ;        BX = -320
.dyp:   mov  [ady], ax          ; ady = |dy|
        mov  [sty], bx          ; sty = +-320

        ; ---- which distance is longer DRIVES the loop; the other one
        ; feeds the debt. Both answers are written into the code.
        mov  ax, [adx]          ; AX = adx
        cmp  ax, [ady]          ; adx < ady ?
        jb   .ymaj              ;   yes: y-major
        mov  [dmaj], ax         ; dmaj = adx    x-major: step right every pixel...
        mov  ax, [ady]          ; AX = ady
        mov  [dmin], ax         ; dmin = ady
        mov  ax, [stx]          ; AX = stx
        mov  [.majs+2], ax      ; major_step = stx  ...so the driving ADD gets +-1
        mov  ax, [sty]          ; AX = sty
        mov  [.mins+2], ax      ; minor_step = sty  ...and the debt ADD gets +-320
        jmp  .go                ; over the y-major case
.ymaj:  mov  [dmin], ax         ; dmin = adx    y-major: the roles swap, no more
        mov  ax, [ady]          ; AX = ady
        mov  [dmaj], ax         ; dmaj = ady
        mov  ax, [sty]          ; AX = sty
        mov  [.majs+2], ax      ; major_step = sty
        mov  ax, [stx]          ; AX = stx
        mov  [.mins+2], ax      ; minor_step = stx
.go:    jmp  short .fl          ; THE RULE: patch, then jump
.fl:
        mov  ax, [p0y]          ; AX = p0y       where the line starts:
        mov  bx, W              ; BX = 320       lesson 7's formula
        mul  bx                 ; AX = p0y * 320
        add  ax, [p0x]          ; AX = p0y * 320 + p0x
        mov  di, ax             ; DI = at
        mov  bl, [col]          ; BL = col
        mov  cx, [dmaj]         ; CX = dmaj
        inc  cx                 ; CX = n = dmaj + 1: both ends belong to the line
        xor  dx, dx             ; DX = debt = 0, starting clean
.px:    mov  [es:di], bl        ; screen[at] = col
        add  dx, [dmin]         ; debt += dmin: every step the debt grows by
        cmp  dx, [dmaj]         ; debt >= dmaj ?  the short distance - reached
        jb   .nod               ;   no             the long one?
        sub  dx, [dmaj]         ;   yes: debt -= dmaj, paid off...
.mins:  add  di, W              ;        at += minor_step  ...one sideways step   (REWRITTEN)
.nod:
.majs:  add  di, W              ; at += major_step: the driving step, every pixel (REWRITTEN)
        loop .px                ; n-- ; while (n)
        ret                     ; return
