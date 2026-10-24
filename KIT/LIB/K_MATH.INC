; ============================================================================
;  K_MATH.INC - KIT: integer maths for games. Nothing here divides by what
;  can be 0 or overflow (a divide fault in DOSBox loops for ever).
;
;  ANGLES: 256 = a full circle, 64 = a right angle, any word wraps.
;  Bearings as the games steer: 0 north (+z / up), 64 east (+x / right).
;  SIN/COS come back times 256: x += speed * MTH_SIN(a) / 256.
; ============================================================================

if used mth_seed
mth_seed dw 1                   ; the random generator's state
end if

; ----------------------------------------------------------------------
;@ MTH_RND    AX = a pseudo-random word (LCG); use its HIGH bits
;  in:  [mth_seed]
;  out: AX = the next number. Its low bits repeat fast (bit 0 just
;       alternates): take AH, or MTH_RANGE, never AX AND 1
;  needs: MTH_SEED once, or every run plays the same
;  from: ENGINE\E_MATH.INC (RND16), its rseed named mth_seed
; ----------------------------------------------------------------------
if used MTH_RND
MTH_RND:
        push bx
        push dx
        mov  ax,[mth_seed]
        mov  bx,25173
        mul  bx                 ; DX:AX = seed * 25173 (MUL writes DX)
        add  ax,13849           ; + 13849, mod 65536
        mov  [mth_seed],ax
        pop  dx
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ MTH_SEED   seed the random generator from the BIOS tick (every run differs)
;  in:  -
;  out: -
;  needs: -
;  from: ENGINE\E_MATH.INC's note (the game seeds rseed from 0040:006C)
; ----------------------------------------------------------------------
if used MTH_SEED
MTH_SEED:
        push ax
        push es
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:046Ch]      ; AX = the tick
        or   ax,1               ; never 0 (any odd seed is a good one)
        mov  [mth_seed],ax
        pop  es
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ MTH_RANGE  AX = a random number 0..N-1, N in AX (N = 0 gives 0)
;  in:  AX = N (1..65535)
;  out: AX = 0..N-1, never N - by multiplying, not dividing
;  needs: MTH_SEED once
;  from: new (rnd * N / 65536: the high word of MUL, no DIV at all)
; ----------------------------------------------------------------------
if used MTH_RANGE
MTH_RANGE:
        push bx
        push dx
        mov  bx,ax              ; BX = N
        call MTH_RND            ; AX = 0..65535
        mul  bx                 ; DX:AX = rnd * N; DX = rnd * N / 65536 < N
        mov  ax,dx              ; AX = the answer (N = 0: 0)
        pop  dx
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ MTH_SIN    AX = sin(angle AX) * 256, -256..256 (256 = a circle)
;  in:  AX = the angle, any (wrapped to 0..255)
;  out: AX = sin * 256
;  needs: -
;  from: ENGINE\E_M3D.INC (SINQ) + EXAMPLES\AVIO.ASM:509-512 (SINT),
;        registers kept
; ----------------------------------------------------------------------
if used MTH_SIN
MTH_SIN:
        push bx
        and  ax,255             ; one circle
        mov  bx,ax              ; BX = the angle
        and  ax,63              ; AX = the index in its quadrant, 0..63
        test bl,64              ; quadrants 1 and 3 run backwards
        jz   .fw
        neg  ax
        add  ax,64              ; AX = 64 - index
.fw:    add  ax,ax              ; words
        xchg ax,bx              ; BX = table offset, AX = the angle
        mov  bx,[mth_sint+bx]   ; BX = the quarter table's value
        test al,128             ; quadrants 2 and 3 are below zero
        jz   .pos
        neg  bx
.pos:   mov  ax,bx              ; AX = the answer
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ MTH_COS    AX = cos(angle AX) * 256, -256..256
;  in:  AX = the angle, any
;  out: AX = cos * 256
;  needs: -
;  from: ENGINE\E_M3D.INC (cos(a) = SINQ(a + 64))
; ----------------------------------------------------------------------
if used MTH_COS
MTH_COS:
        add  ax,64              ; a quarter turn on
        jmp  MTH_SIN
end if

if used mth_sint
; sin(0..90 degrees) * 256 in 65 steps: EXAMPLES\AVIO.ASM:509-512
mth_sint dw 0,6,13,19,25,31,38,44,50,56,62,68,74,80,86,92,98,104,109,115
         dw 121,126,132,137,142,147,153,157,162,167,172,177,181,185,190,194
         dw 198,202,206,209,213,216,220,223,226,229,231,234,237,239,241,243
         dw 245,247,248,250,251,252,253,254,255,255,256,256,256
end if

; ----------------------------------------------------------------------
;@ MTH_ATAN2  AX = the bearing to (east AX, north BX): 0 north, 64 east
;  in:  AX = east (dx), BX = north (dz); any signed words
;  out: AX = 0..255 (both 0: 0)
;  needs: -
;  from: GAMES\OWLFLY3\SRC\SYM.INC:347-421 (SHKBRG) + its table SHKATN
;        (SYM.INC:55); both legs now halved below 2048 first - SHKBRG's
;        leg*32 overflowed past 2047 and gave a wrong bearing
; ----------------------------------------------------------------------
if used MTH_ATAN2
MTH_ATAN2:
        push bx
        push cx
        push dx
        mov  cx,ax              ; CX, DX = the signs, kept
        mov  dx,bx
        or   ax,ax
        jns  .b1
        neg  ax                 ; AX = |east| (8000h stays 32768 unsigned)
.b1:    or   bx,bx
        jns  .b2
        neg  bx                 ; BX = |north|
.b2:    cmp  ax,2048            ; both legs below 2048, the ratio kept
        jae  .half
        cmp  bx,2048
        jb   .small
.half:  shr  ax,1               ; AX /= 2
        shr  bx,1               ; BX /= 2
        jmp  .b2
.small: cmp  ax,bx
        ja   .wide
        ; more north/south than east/west
        or   bx,bx
        jnz  .t1
        xor  ax,ax              ; both zero: north
        jmp  .out
.t1:    push cx
        push dx
        mov  cl,5
        shl  ax,cl              ; AX = |east| * 32 (< 65536: |east| < 2048)
        xor  dx,dx
        div  bx                 ; AX = |e|*32/|n| <= 32 (|e| <= |n|, n not 0)
        mov  bx,ax
        mov  al,[mth_atn+bx]    ; AL = the angle, 0..32
        xor  ah,ah
        pop  dx
        pop  cx
        or   dx,dx
        js   .s                 ; southward
        or   cx,cx
        jns  .out               ; north-east: the angle IS the bearing
        neg  ax                 ; north-west: 256 - angle
        and  ax,255
        jmp  .out
.s:     or   cx,cx
        jns  .se
        add  ax,128             ; south-west: 128 + angle
        jmp  .out
.se:    mov  bx,128             ; south-east: 128 - angle
        sub  bx,ax
        mov  ax,bx
        jmp  .out
.wide:  ; more east/west than north/south
        push cx
        push dx
        xchg ax,bx              ; AX = |north|, BX = |east| (not 0: > AX)
        mov  cl,5
        shl  ax,cl              ; AX = |north| * 32
        xor  dx,dx
        div  bx                 ; AX = |n|*32/|e| < 32
        mov  bx,ax
        mov  al,[mth_atn+bx]
        xor  ah,ah
        pop  dx
        pop  cx
        or   cx,cx
        js   .w
        or   dx,dx              ; eastward
        js   .se2
        mov  bx,64              ; north-east: 64 - angle
        sub  bx,ax
        mov  ax,bx
        jmp  .out
.se2:   add  ax,64              ; south-east: 64 + angle
        jmp  .out
.w:     or   dx,dx              ; westward
        js   .sw
        add  ax,192             ; north-west: 192 + angle
        and  ax,255
        jmp  .out
.sw:    mov  bx,192             ; south-west: 192 - angle
        sub  bx,ax
        mov  ax,bx
.out:   pop  dx
        pop  cx
        pop  bx
        ret
; atan(i/32) in 256ths of a circle, i = 0..32 (SYM.INC:55 SHKATN)
mth_atn db 0,1,3,4,5,6,8,9,10,11,12,13,15,16,17,18,19
        db 20,21,22,23,24,25,25,26,27,28,29,29,30,31,31,32
end if

; ----------------------------------------------------------------------
;@ MTH_DIST   AX = the distance to (AX, BX), near enough (octagon, ~4%)
;  in:  AX, BX = the two legs, signed
;  out: AX = longer + 3/8 shorter (unsigned; legs past ~40000 overflow)
;  needs: -
;  from: LESSONS\L23\HOUSES.ASM:1967-1988 (ODIST), BX kept
; ----------------------------------------------------------------------
if used MTH_DIST
MTH_DIST:
        push bx
        or   ax,ax
        jns  .a
        neg  ax                 ; AX = |AX|
.a:     or   bx,bx
        jns  .b
        neg  bx                 ; BX = |BX|
.b:     cmp  ax,bx              ; AX the longer?
        jae  .c
        xchg ax,bx              ;   no: swap them
.c:     shr  bx,1               ; BX = the shorter / 2
        shr  bx,1               ;          / 4
        add  ax,bx              ; AX += a quarter of it
        shr  bx,1               ;          / 8
        add  ax,bx              ; AX += an eighth: three eighths in all
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ MTH_LERP   AX = a + (b - a) * t / 256  (AX = a, BX = b, CX = t 0..256)
;  in:  AX = a, BX = b, CX = t (0 = a, 256 = b); b - a must fit a signed
;       word
;  out: AX
;  needs: -
;  from: LESSONS\L23\HOUSES.ASM:2756-2766 (LERP8), BX CX DX kept
; ----------------------------------------------------------------------
if used MTH_LERP
MTH_LERP:
        push bx
        push dx
        sub  bx,ax              ; BX = b - a
        push ax                 ; keep a
        mov  ax,bx              ; AX = b - a
        imul cx                 ; DX:AX = (b - a) * t
        mov  al,ah              ; / 256: the middle two bytes
        mov  ah,dl
        pop  bx                 ; BX = a
        add  ax,bx              ; AX = a + that
        pop  dx
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ MTH_CLAMP  AX held between BX and CX (signed, BX <= CX)
;  in:  AX, BX = the lowest, CX = the highest
;  out: AX
;  needs: -
;  from: new (the shape of ENGINE\E_M3D.INC's clamp to +-4000)
; ----------------------------------------------------------------------
if used MTH_CLAMP
MTH_CLAMP:
        cmp  ax,bx
        jge  .lo
        mov  ax,bx              ; below: the lowest
.lo:    cmp  ax,cx
        jle  .hi
        mov  ax,cx              ; above: the highest
.hi:    ret
end if

; ----------------------------------------------------------------------
;@ MTH_ABS    AX = |AX|  (-32768 stays 8000h: read it unsigned)
;  in:  AX
;  out: AX
;  needs: -
;  from: new
; ----------------------------------------------------------------------
if used MTH_ABS
MTH_ABS:
        or   ax,ax
        jns  .p
        neg  ax                 ; AX = -AX
.p:     ret
end if

; ----------------------------------------------------------------------
;@ MTH_SGN    AX = -1, 0 or 1 by the sign of AX
;  in:  AX
;  out: AX
;  needs: -
;  from: new
; ----------------------------------------------------------------------
if used MTH_SGN
MTH_SGN:
        or   ax,ax
        jz   .z                 ; 0 stays 0
        js   .n
        mov  ax,1
        ret
.n:     mov  ax,-1
.z:     ret
end if

; ----------------------------------------------------------------------
;@ MTH_HASH   AX = 0..255, the same for the same cell every time (scenery)
;  in:  CX = column, DX = row (low 6 bits each), BX = salt (a level, a
;       kind of thing: low 4 bits)
;  out: AX = 0..255 - a stone here or not, which tree, how bright
;  needs: -
;  from: GAMES\MULTSOK2\SCENE.INC:358-385 (HASH), [level] made BX
; ----------------------------------------------------------------------
if used MTH_HASH
MTH_HASH:
        push bx
        push cx
        push dx
        mov  ax,dx
        and  ax,63              ; AX = row AND 63
        and  cx,63              ; CX = column AND 63
        push cx
        mov  cl,6
        shl  ax,cl              ; AX = (row AND 63) * 64
        pop  cx
        add  ax,cx              ; + column
        mov  cl,12
        shl  bx,cl              ; BX = salt * 4096
        add  ax,bx              ; + it
        mov  bx,25173
        mul  bx                 ; DX:AX = AX * 25173 (DX goes)
        add  ax,13849           ; an LCG step
        xchg al,ah              ; its bytes swapped
        mul  bx                 ; again
        add  ax,13849
        mov  al,ah              ; the high byte: the good one
        xor  ah,ah
        pop  dx
        pop  cx
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ MTH_SQRT   AX = floor(sqrt(AX)), unsigned 0..65535 -> 0..255
;  in:  AX
;  out: AX
;  needs: - (slow: up to 255 rounds; for a table at start, not per pixel)
;  from: GAMES\OWLFLY3\SRC\SYM.INC:1810-1819 (BLSQRT), BX CX kept
; ----------------------------------------------------------------------
if used MTH_SQRT
MTH_SQRT:
        push bx
        push cx
        xor  cx,cx              ; CX = the root so far
        mov  bx,1               ; BX = the odd numbers 1, 3, 5...
.s:     cmp  ax,bx              ; can the next odd number come off?
        jb   .d
        sub  ax,bx              ; AX -= it: 1+3+...+(2n-1) = n*n
        add  bx,2               ; the next odd number
        inc  cx                 ; one more
        jmp  .s
.d:     mov  ax,cx
        pop  cx
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ MTH_MULDIV AX = AX * BX / CX, signed, guarded: CF = 1 on /0 or overflow
;  in:  AX, BX, CX signed words
;  out: AX = the quotient, toward zero; CF = 1 (and AX = 0) when CX = 0
;       or the answer does not fit -32768..32767
;  needs: -
;  from: new (unsigned DIV on the magnitudes after a range check: never
;        an IDIV that can fault)
; ----------------------------------------------------------------------
if used MTH_MULDIV
MTH_MULDIV:
        push bx
        push cx
        push dx
        push si
        jcxz .bad               ; / 0
        imul bx                 ; DX:AX = AX * BX, signed
        mov  si,dx
        xor  si,cx              ; SI bit 15 = the answer's sign
        or   dx,dx              ; |DX:AX|
        jns  .p1
        not  ax
        not  dx
        add  ax,1               ; DX:AX = -DX:AX (two's complement)
        adc  dx,0
.p1:    or   cx,cx              ; |CX|
        jns  .p2
        neg  cx                 ; CX = |CX| (8000h = 32768 unsigned)
.p2:    cmp  dx,cx              ; high word >= divisor: the quotient
        jae  .bad               ;  would not fit 16 bits - DIV would fault
        div  cx                 ; AX = |a*b| / |c|, unsigned; DX = rest
        or   si,si
        js   .neg
        cmp  ax,7FFFh           ; positive: at most 32767
        ja   .bad
        jmp  .ok
.neg:   cmp  ax,8000h           ; negative: at most 32768 below zero
        ja   .bad
        neg  ax                 ; AX = -quotient
.ok:    clc
        jmp  .out
.bad:   xor  ax,ax              ; AX = 0
        stc                     ; and the alarm
.out:   pop  si
        pop  dx
        pop  cx
        pop  bx
        ret
end if
