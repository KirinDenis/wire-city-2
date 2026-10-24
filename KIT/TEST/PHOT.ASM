; ============================================================================
;  PHOT.ASM - KIT test: K_HOT.INC (hotspots: the two-pass hit test, the
;  flags, the centre, drawing the things).
;
;      PHOT           runs the checks, prints PASS/FAIL (no picture: the
;      PHOT /AUTO     hit test reads the sprites, the drawing goes into a
;                     buffer of its own from DOS)
;
;  The things, drawn in this order (the last on top):
;    0 RING  12x12 at (100,50): a ring two pixels thick, its middle 8x8 a hole
;    1 BLOCK  6x6  at (108,58): solid, over the ring's bottom-right corner
;    2 VEIL  30x30 at  (90,40): see-through but one pixel at (2,2) - its
;                               rectangle covers the ring and the block
;    3 a plain rectangle (no sprite) 10x10 at (200,100)
;    4 an empty entry, not LOADED
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

NTH     = 5

Main:   cld
        call IsAuto
        mov  si,RING
        mov  di,ringc
        call SPR_COMPILE
        mov  si,BLOCK
        mov  di,blockc
        call SPR_COMPILE
        mov  si,VEIL
        mov  di,veilc
        call SPR_COMPILE
        mov  di,things          ; 0 the ring
        mov  si,ringc
        mov  bx,100
        mov  dx,50
        call HOT_PUT
        add  di,HOT_SIZE        ; 1 the block
        mov  si,blockc
        mov  bx,108
        mov  dx,58
        call HOT_PUT
        add  di,HOT_SIZE        ; 2 the veil
        mov  si,veilc
        mov  bx,90
        mov  dx,40
        call HOT_PUT
        add  di,HOT_SIZE        ; 3 a rectangle, no sprite
        xor  si,si
        mov  cx,10
        mov  ax,10
        mov  bx,200
        mov  dx,100
        call HOT_PUT
        ; 4 stays all zero: not loaded

; ---- 1. HOT_PUT: the size from the sprite, LOADED --------------------------
        cmp  word [things+HOT_W],12
        jne  .p0
        cmp  word [things+HOT_H],12
        jne  .p0
        cmp  word [things+2*HOT_SIZE+HOT_W],30
        jne  .p0
        cmp  word [things+3*HOT_SIZE+HOT_H],10
        jne  .p0
        cmp  byte [things+HOT_FLAGS],HOT_LOADED
        call PassZ
.p0:    mov  si,mPut
        call ChkOk

; ---- 2. an opaque pixel of a LOWER thing beats the rectangle of the top one -
        mov  ax,100             ; the ring's corner; inside the veil's box
        mov  dx,50
        call Hit
        cmp  bx,0
        jne  .a0
        cmp  byte [hot_how],1
        call PassZ
.a0:    mov  si,mLower
        call ChkOk

; ---- 3. where two opaque things overlap, the one drawn last wins ------------
        mov  ax,109
        mov  dx,59
        call Hit
        cmp  bx,1
        jne  .b0
        cmp  byte [hot_how],1
        call PassZ
.b0:    mov  si,mLast
        call ChkOk

; ---- 4. within 3 pixels of a lone opaque pixel counts -----------------------
        mov  ax,95              ; the veil's dot is at (92,42): 3 away
        mov  dx,45
        call Hit
        cmp  bx,2
        jne  .c0
        cmp  byte [hot_how],1
        jne  .c0
        mov  ax,96              ; 4 away: the veil's box only - but the
        mov  dx,42              ; ring is not under (96,42) either:
        call Hit                ; pass 2 gives the veil
        cmp  bx,2
        jne  .c0
        cmp  byte [hot_how],2
        call PassZ
.c0:    mov  si,mNear
        call ChkOk

; ---- 5. the ring's clear middle: pass 1 misses, pass 2 - last drawn first ---
        mov  ax,106
        mov  dx,56
        call Hit                ; the veil's box is on top
        cmp  bx,2
        jne  .d0
        cmp  byte [hot_how],2
        jne  .d0
        mov  si,things          ; the veil taken: no longer clicked
        mov  bx,2
        call HOT_TAKE
        mov  ax,106
        mov  dx,56
        call Hit                ; now the ring's own box: the ring
        cmp  bx,0
        jne  .d0
        cmp  byte [hot_how],2
        call PassZ
.d0:    mov  si,mHole
        call ChkOk

; ---- 6. nothing there; the panel below hot_maxy; BX kept on a miss ----------
        mov  bx,1234h
        mov  ax,10
        mov  dx,10
        call Hit
        jnc  .e0
        cmp  bx,1234h
        jne  .e0
        mov  word [hot_maxy],60
        mov  ax,100             ; the ring's row 10 - but the panel
        mov  dx,60
        call Hit
        mov  word [hot_maxy],200
        jnc  .e0
        mov  ax,100
        mov  dx,59              ; one above: the ring
        call Hit
        jc   .e0
        cmp  bx,0
        call PassZ
.e0:    mov  si,mMiss
        call ChkOk

; ---- 7. a thing with no sprite is solid all over; HOT_HIT keeps the rest ----
        mov  ax,205
        mov  dx,105
        mov  si,things
        mov  cx,NTH
        call Regs
        call HOT_HIT
        jc   .f0
        cmp  bx,3
        jne  .f0
        mov  bx,[rg]            ; BX is the answer: put the old one back
        call RegsSame           ; for the comparison
        jne  .f0
        cmp  ax,205
        call PassZ
.f0:    mov  si,mRect
        call ChkOk

; ---- 8. needed, next wanted, all taken --------------------------------------
        mov  si,things
        mov  cx,NTH
        call HOT_NEEDALL
        test byte [things+4*HOT_SIZE+HOT_FLAGS],HOT_NEEDED
        jnz  .g0                ; not loaded: never needed
        call HOT_ALLTAKEN
        jc   .g0                ; three still wanted
        call HOT_NEXTWANTED
        jc   .g0
        cmp  bx,0               ; the ring first (the veil is taken)
        jne  .g0
        call HOT_TAKE
        call HOT_NEXTWANTED
        cmp  bx,1
        jne  .g0
        call HOT_TAKE
        call HOT_NEXTWANTED
        cmp  bx,3               ; 2 was taken in check 5
        jne  .g0
        call HOT_TAKE
        mov  bx,77
        call HOT_NEXTWANTED     ; none: CF, BX kept
        jnc  .g0
        cmp  bx,77
        jne  .g0
        call HOT_ALLTAKEN
        jnc  .g0
        cmp  ax,ax
        call PassZ
.g0:    mov  si,mNeed
        call ChkOk

; ---- 9. the centre, and the centre clicks the thing (the /AUTO path) ------
        mov  si,things
        and  byte [things+HOT_FLAGS],0FFh-HOT_TAKEN ; the ring back
        and  byte [things+HOT_SIZE+HOT_FLAGS],0FFh-HOT_TAKEN ; the block back
        mov  bx,1
        call HOT_CENTRE         ; the block: (111,61)
        cmp  ax,111
        jne  .h0
        cmp  dx,61
        jne  .h0
        call Hit
        cmp  bx,1
        jne  .h0
        mov  word [things+3*HOT_SIZE+HOT_X],318 ; off the right edge,
        mov  word [hot_maxy],103                ; under the panel line
        mov  bx,3
        call HOT_CENTRE
        mov  word [hot_maxy],200
        cmp  ax,319
        jne  .h0
        cmp  dx,102
        call PassZ
.h0:    mov  si,mCentre
        call ChkOk

; ---- 10. HOT_DRAW draws the things there, not the taken ones ----------------
        mov  ah,4Ah
        mov  bx,1000h           ; this .COM: 64K
        push cs
        pop  es
        int  21h
        mov  ah,48h
        mov  bx,0FA0h           ; 64000 bytes
        int  21h
        jc   .i0
        mov  es,ax
        mov  [bufseg],ax
        xor  di,di
        mov  cx,32000
        xor  ax,ax
        rep  stosw              ; all 0
        or   byte [things+2*HOT_SIZE+HOT_FLAGS],HOT_TAKEN ; the veil taken
        mov  si,things
        mov  cx,NTH
        call HOT_DRAW
        mov  ax,100
        mov  dx,50
        call Peek
        cmp  al,12              ; the ring, C
        jne  .i0
        mov  ax,109
        mov  dx,59
        call Peek
        cmp  al,14              ; the block over it, E
        jne  .i0
        mov  ax,106
        mov  dx,56
        call Peek
        cmp  al,0               ; the ring's hole
        jne  .i0
        mov  ax,92
        mov  dx,42
        call Peek
        cmp  al,0               ; the veil's dot: taken, not drawn
        call PassZ
.i0:    mov  si,mDraw
        call ChkOk
        mov  ax,[bufseg]
        test ax,ax
        jz   .done
        mov  es,ax
        mov  ah,49h
        int  21h                ; the buffer back to DOS
.done:  push cs
        pop  es
        call Report
        mov  ax,4C00h
        int  21h

; Hit - HOT_HIT on the whole table at AX,DX
Hit:    push si
        push cx
        mov  si,things
        mov  cx,NTH
        call HOT_HIT
        pop  cx
        pop  si
        ret

; Peek - AL = the buffer's pixel at (AX,DX)
Peek:   push bx
        push di
        mov  bx,dx
        mov  di,bx
        mov  cl,8
        shl  di,cl              ; y * 256
        mov  cl,6
        shl  bx,cl              ; y * 64
        add  di,bx              ; y * 320
        add  di,ax              ; + x
        mov  al,[es:di]
        pop  di
        pop  bx
        ret

RING    db 12,12
        db 'CCCCCCCCCCCC'
        db 'CCCCCCCCCCCC'
        db 'CC........CC'
        db 'CC........CC'
        db 'CC........CC'
        db 'CC........CC'
        db 'CC........CC'
        db 'CC........CC'
        db 'CC........CC'
        db 'CC........CC'
        db 'CCCCCCCCCCCC'
        db 'CCCCCCCCCCCC'
BLOCK   db 6,6
        db 'EEEEEE'
        db 'EEEEEE'
        db 'EEEEEE'
        db 'EEEEEE'
        db 'EEEEEE'
        db 'EEEEEE'
VEIL    db 30,30
        db '..............................'
        db '..............................'
        db '..F...........................'
        db 27*30 dup('.')

mPut    db 'HOT_PUT: the size from the sprite, LOADED; a plain rectangle$'
mLower  db 'HOT_HIT an opaque pixel of a lower thing beats the top box$'
mLast   db 'HOT_HIT two opaque things overlap: the last drawn wins$'
mNear   db 'HOT_HIT within 3 px of a lone pixel (pass 1); 4 away: box$'
mHole   db 'HOT_HIT a clear middle: pass 2, last drawn; taken skipped$'
mMiss   db 'HOT_HIT nothing there: CF, BX kept; hot_maxy is a panel$'
mRect   db 'HOT_HIT a thing with no sprite is solid; registers kept$'
mNeed   db 'HOT_NEEDALL / NEXTWANTED / TAKE / ALLTAKEN$'
mCentre db 'HOT_CENTRE the middle clicks the thing; clamped to edge, panel$'
mDraw   db 'HOT_DRAW draws in order, holes kept, taken ones not drawn$'
bufseg  dw 0
things  db NTH*HOT_SIZE dup(0)
ringc   db 2+12*12 dup(0)
blockc  db 2+6*6 dup(0)
veilc   db 2+30*30 dup(0)

; ---- the test's own harness ---------------------------------------------
; PassZ - ZF = 1: this check passed so far ([okf] = 1). All kept.
PassZ:  jnz  .o
        mov  byte [okf],1
.o:     ret

; ChkOk - record [okf] as the result (SI = its name), then [okf] = 0
ChkOk:  cmp  byte [okf],1
        mov  byte [okf],0       ; (flags kept)
        jmp  Chk

; Chk - record one result: ZF = 1 PASS, SI = its name ($-ended). All kept.
Chk:    push ax
        push bx
        mov  al,0
        jnz  .f
        mov  al,1
.f:     mov  bx,[nres]
        shl  bx,1
        shl  bx,1               ; four bytes a result
        mov  [res+bx],si
        mov  byte [res+bx+2],al
        inc  word [nres]
        pop  bx
        pop  ax
        ret

; Report - the PASS/FAIL lines by DOS (to NAME.OUT under RUNWIN)
Report: mov  si,res
        mov  cx,[nres]
        jcxz .sum
.l:     mov  dx,sPass
        cmp  byte [si+2],1
        je   .p
        mov  dx,sFail
        mov  byte [bad],1
.p:     mov  ah,9
        int  21h
        mov  dx,[si]
        mov  ah,9
        int  21h
        mov  dx,sCrlf
        mov  ah,9
        int  21h
        add  si,4
        loop .l
.sum:   mov  dx,sAll
        cmp  byte [bad],0
        je   .s
        mov  dx,sSome
.s:     mov  ah,9
        int  21h
        ret

; IsAuto - [auto] = 1 if the command line holds /A (/AUTO)
IsAuto: mov  si,81h
        mov  cl,[80h]
        xor  ch,ch              ; CX = the tail's length
        jcxz .no
.l:     lodsb
        cmp  al,'/'
        jne  .n
        mov  al,[si]
        and  al,0DFh            ; capital
        cmp  al,'A'
        jne  .n
        mov  byte [auto],1
.n:     loop .l
.no:    ret

; Hold - ~2 s by the BIOS tick under /AUTO; else until Esc
Hold:   cmp  byte [auto],0
        je   .key
        push es
        xor  ax,ax
        mov  es,ax
        mov  bx,[es:046Ch]      ; BX = the tick now
.t:     mov  ax,[es:046Ch]
        sub  ax,bx              ; AX = ticks gone
        cmp  ax,36              ; ~2 s?
        jb   .t
        pop  es
        ret
.key:   xor  ah,ah
        int  16h                ; wait for a key
        cmp  al,27              ; Esc?
        jne  .key
        ret

; Regs / RegsSame - snapshot BX CX DX SI DI BP ES, compare: ZF = 1 same
Regs:   mov  [rg],bx
        mov  [rg+2],cx
        mov  [rg+4],dx
        mov  [rg+6],si
        mov  [rg+8],di
        mov  [rg+10],bp
        mov  [rg+12],es
        ret
RegsSame:
        cmp  [rg],bx
        jne  .o
        cmp  [rg+2],cx
        jne  .o
        cmp  [rg+4],dx
        jne  .o
        cmp  [rg+6],si
        jne  .o
        cmp  [rg+8],di
        jne  .o
        cmp  [rg+10],bp
        jne  .o
        push ax
        mov  ax,es
        cmp  [rg+12],ax
        pop  ax
.o:     ret

auto    db 0
okf     db 0
bad     db 0
nres    dw 0
rg      dw 7 dup(0)
res     dw 2*80 dup(0)
sPass   db 'PASS $'
sFail   db 'FAIL $'
sCrlf   db 13,10,'$'
sAll    db 'ALL PASS',13,10,'$'
sSome   db 'SOME FAILED',13,10,'$'

        include '..\..\KIT\LIB\K_HOT.INC'
        include '..\..\KIT\LIB\K_SPR.INC'
