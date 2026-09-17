; ============================================================================
;  DRAW12.INC - the small routines lesson 12 leans on.
;
;  Lesson 10's toolbox, carried forward whole - and inside it lesson 8's
;  LINE, byte for byte, earning its keep a third time: today it draws the
;  green arms that carry the sky. Vsync waits for the tube's vertical
;  retrace; KeyChk asks the keyboard WITHOUT waiting, so an orrery can
;  turn until a key says stop.
; ============================================================================

attr    db 07h                  ; the colour the next character is written in
dcol    db 15                   ; the colour Dot stamps with

; ---- one character at ES:DI, in [attr], and DI moves on --------------------
;  In C:   *text++ = (attr << 8) | AL;    - a cell is two bytes: the character, its colour
PutC:   mov  ah, [attr]         ; AH = attr: the colour, above the character in AL
        stosw                   ; *es:di++ = AX: character AND colour, in one instruction
        ret                     ; return

; ---- an asciiz string at ES:DI ---------------------------------------------
;  In C:   while (*s) *text++ = (attr << 8) | *s++;
PutS:   lodsb                   ; AL = *si++
        or   al, al             ; the end of the string?
        jz   .done              ;   yes: return
        mov  ah, [attr]         ; AH = attr
        stosw                   ; *es:di++ = AX
        jmp  PutS               ; the next character
.done:  ret                     ; return

; ---- the whole text screen, blank -------------------------------------------
;  In C:   for (i = 0; i < 80*25; i++) text[i] = 0x0720;    - a space, grey on black
TClear: xor  di, di             ; DI = 0: the top-left cell
        mov  cx, 80*25          ; CX = 2000 cells
        mov  ax, 0720h          ; AX = 0720h: a space, in grey on black
        rep  stosw              ; while (cx--) *es:di++ = ax
        ret                     ; return

; ---- the whole graphics screen, black --------------------------------------
;  In C:   memset(screen, 0, 64000);
GClear: xor  di, di             ; DI = 0: the top-left pixel
        xor  ax, ax             ; AX = 0: two black pixels
        mov  cx, W*H/2          ; CX = 32000 words, because STOSW writes two
        rep  stosw              ; while (cx--) *es:di++ = ax
        ret                     ; return

; ---- no cursor, so nothing blinks through the explanation ------------------
;  In C:   cursor_off();   - BIOS 10h, service 1: set the cursor's shape
TextOff:
        mov  ah, 1              ; AH = 1: set cursor shape
        mov  cx, 2000h          ; CX = 2000h: bit 5 of CH turns it off
        int  10h                ; cursor_off()
        ret                     ; return

; ---- wait for a key ---------------------------------------------------------
;  In C:   int key(void) { return get_key(); }   - waits
Key:    mov  ah, 0              ; AH = 0: BIOS 16h, service 0 - wait for a key
        int  16h                ; AL = the character, AH = the scan code
        ret                     ; return

; ---- ask for a key, but do not wait -----------------------------------------
;  AL = 1 a key was hit (and is consumed), 0 the keyboard is quiet. The
;  orrery calls this once a frame: the sky turns until told not to.
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
.in:   in   al, dx              ; AL = inp(0x3DA)
        test al, 8              ; bit 3 again
        jz   .in                ; while (!retrace) ;  - wait for the next
        pop  dx                 ; DX back
        pop  ax                 ; AX back
        ret                     ; return

; A fifth of a second, off the BIOS tick at 0040:006C - the same clock the
; whole PC counts on, eighteen and a bit times a second.
;  In C:   int t = bios_tick() + 4;  while (bios_tick() < t) ;   - a fifth of a second
Hold:   push es                 ; keep ES
        mov  ax, 0040h          ; AX = 0040h, the BIOS data segment
        mov  es, ax             ; ES = 0040h
        mov  bx, [es:6Ch]       ; BX = the tick count at 0040:006C
        add  bx, 4              ; BX = t = tick + 4
.wait:  mov  ax, [es:6Ch]       ; AX = the tick now
        cmp  ax, bx             ; tick < t ?
        jb   .wait              ;   yes: keep waiting
        pop  es                 ; ES back
        ret                     ; return

; ---- the hint at the bottom of a text frame --------------------------------
;  In C:   attr = 8;  puts_at(23, 34, "- any key -");  attr = NORM;
Bottom: mov  si, t_key          ; SI = the string
        mov  di, 23*ROW + 34*2  ; DI = row 23, column 34
        mov  byte [attr], 08h   ; attr = 8, dark grey
        call PutS               ; puts()
        mov  byte [attr], NORM  ; attr = NORM
        ret                     ; return

; ---- Dot: a body made visible - five pixels in [dcol] -----------------------
;  in: AX = x, BX = y. Offset = y * 320 + x: lesson 7's formula, every time.
;  In C:   int o = y * 320 + x;  screen[o] = screen[o-1] = screen[o+1]
;                                = screen[o-320] = screen[o+320] = dcol;
Dot:    push ax                 ; keep x
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
