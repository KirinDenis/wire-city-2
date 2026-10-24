; ============================================================================
;  R_SCORE.ASM - recipe: points a player feels, and the mercy of asking twice.
;
;  Guide TILES, "Points a player feels": every point shows where it is
;  made - a gain of 5 or more rises gold over the cell for two seconds, a
;  loss rises red; points by rule both ways (a crate onto a mark +10, off
;  one -10), so a crate slid mark to mark earns 0 and shows nothing. Small
;  treats worth 1..3 by a hash of the cell, so every level differs.
;  "Mercy": R R, N N, P P - the first press only asks, in the top line; the
;  second does it; a couple of seconds and it forgets.
;
;  copy: the routines and the words at the end. Rename freely.
;  define before: -    calls: -    needs: nothing from the kit
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:1949-1952 (SCORE), SCENE.INC:358-385
;        (HASH), 2061-2075 (CANDYV), MULTSOK2.ASM:1509-1520, 2043-2050 (pend);
;        the pop-up clock new (MULTSOK2 draws its POPS from the world).
; ============================================================================
POPT    = 36                    ; ticks a pop-up rises: 2 s
ASKT    = 36                    ; ticks a question waits for its second press

; ----------------------------------------------------------------------
;@ SCORE      CX points (signed) made at cell BX: score, the level's, a pop-up
;  in:  CX = points, BX = the cell (or any place the drawing understands)
;  out: -  [score] += CX, [gain] += CX; |CX| >= 5: [popval] = CX,
;       [popcell] = BX, [popclk] = POPT (draw it while popclk > 0: risen
;       (POPT - popclk)/2 px over the cell, gold if popval > 0, else red)
; ----------------------------------------------------------------------
SCORE:  add  [score],cx         ; the score
        add  [gain],cx          ; and this level's share of it
        cmp  cx,5
        jge  .pop               ; worth showing
        cmp  cx,-5
        jg   .r                 ; too small either way: no pop-up
.pop:   mov  [popval],cx
        mov  [popcell],bx
        mov  word [popclk],POPT
.r:     ret

; ----------------------------------------------------------------------
;@ POPTICK    the pop-up's clock down by DX elapsed ticks (never under 0)
;  in:  DX = ticks since the last call (R_TIMERS' or K_TIME's count)
;  out: -
; ----------------------------------------------------------------------
POPTICK:push ax
        mov  ax,[popclk]
        sub  ax,dx              ; down by the ticks...
        jnc  .s
        xor  ax,ax              ; ...to 0, never under
.s:     mov  [popclk],ax
        pop  ax
        ret

; ----------------------------------------------------------------------
;@ CELLVAL    AX = 1..3, a treat's worth for cell BX in level AX (a hash)
;  in:  BX = the cell (row*32 + column), AX = the level's number
;  out: AX = 1, 2 or 3 - the same cell, the same level: the same worth
; ----------------------------------------------------------------------
CELLVAL:push bx
        push cx
        push dx
        mov  dx,ax
        mov  cl,12
        shl  dx,cl              ; DX = level * 4096
        mov  ax,bx
        mov  cl,5
        shr  ax,cl              ; AX = the row
        add  ax,9               ; (CANDYV's offsets: row+9, column+5)
        and  ax,63
        mov  cl,6
        shl  ax,cl              ; AX = (row AND 63) * 64
        mov  cx,bx
        and  cx,31              ; CX = the column
        add  cx,5
        and  cx,63
        add  ax,cx              ; + (column AND 63)
        add  ax,dx              ; + level * 4096
        mov  bx,25173
        mul  bx                 ; the LCG once (DX goes)
        add  ax,13849
        xchg al,ah              ; its bytes swapped
        mul  bx                 ; and again
        add  ax,13849
        mov  al,ah              ; the high byte: the good one
        xor  ah,ah              ; AX = 0..255
        mov  bl,3
        div  bl                 ; AH = AX mod 3 (AL <= 85: it fits)
        mov  al,ah
        xor  ah,ah              ; AX = 0..2
        inc  ax                 ; 1..3
        pop  dx
        pop  cx
        pop  bx
        ret

; ----------------------------------------------------------------------
;@ ASK2       press twice to do it: CF=1 the first press (only asks)
;  in:  AL = which question (1..255: 1 the level anew, 2 the next...),
;       DX = the tick now
;  out: CF=1 asked: show "R AGAIN: THE LEVEL ANEW" while [ask] <> 0;
;       CF=0 the second press of the same key: do it ([ask] = 0)
; ----------------------------------------------------------------------
ASK2:   cmp  al,[ask]
        je   .do
        mov  [ask],al           ; the first press only asks
        mov  [askt],dx
        stc
        ret
.do:    mov  byte [ask],0       ; the second does it
        clc
        ret

; ----------------------------------------------------------------------
;@ ASKAGE     forget an unanswered question after ASKT ticks: CF=1 forgot
;  in:  DX = the tick now
;  out: CF=1 the question just went (redraw the top line)
; ----------------------------------------------------------------------
ASKAGE: cmp  byte [ask],0
        je   .no
        push ax
        mov  ax,dx
        sub  ax,[askt]          ; ticks since it was asked
        cmp  ax,ASKT
        pop  ax
        jb   .no
        mov  byte [ask],0       ; not pressed again: forget it
        stc
        ret
.no:    clc
        ret

score   dw 0                    ; the player's score, signed
gain    dw 0                    ; his points in this level (zero it at a new level)
popval  dw 0                    ; the last pop-up's points
popcell dw 0                    ; ...where
popclk  dw 0                    ; ...ticks left rising
ask     db 0                    ; the question waiting for its second press, 0 none
askt    dw 0                    ; the tick it was asked
