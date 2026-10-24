; ============================================================================
;  R_LADDER.ASM - recipe: the head-up display's scales. A PITCH LADDER whose
;  rungs (every 10 degrees) lie in the same sky the world is projected into
;  and turn with the bank; a COMPASS TAPE across the top; a vertical TAPE
;  for any value (height, speed) sliding past a fixed pointer. Every mark
;  is drawn by a 16-bit pattern: a rung above the horizon is solid, below
;  it dashed, and a pattern of your own changes the look without code.
;
;        call HZPIVOT            ; R_HORIZ: the horizon's pivot this frame
;        mov  es,[buffer]
;        call LADDER             ; rungs -80..+80 degrees, a gap in the middle
;        call COMPASS            ; the heading, top middle
;        mov  ax,[r3_camy]       ; the value
;        mov  bx,296             ; the tape's column
;        call VTAPE              ; ticks every [tapestep], 1 px a 2^[tapeshr]
;
;  A tape is one sum: row = TAPEMID - (mark - value) >> shift - the scale
;  is drawn again from the value every frame and nothing is stored. Numbers
;  are not drawn (no font here): add K_TEXT's beside the long ticks.
;
;  copy: LADDER COMPASS VTAPE HPAT and their words.
;  define before: -   ([ladc] the ink; [patup]/[patdn] the rung patterns)
;  calls: R_HORIZ (HZPIVOT's hzrow/hzcol/hzsin/hzcos), K_3D (SINQ, heading,
;         FOCAL)
;  from: GAMES\OWLFLY3B\SRC\HUD.INC LADR:50-191 + LROT:193-222 (the rungs by
;        true tangent, turned about the horizon's pivot); LESSONS\L27\
;        TAPES.ASM TAPES:1948-2060 (the compass and the sliding tape)
; ============================================================================

ladc    db 10                   ; the ink
patup   dw 0FFFFh               ; a rung above the horizon: solid...
patdn   dw 0F0F0h               ; ...below it: dashed
pattk   dw 0FFFFh               ; the tapes' ticks
tapestep dw 100                 ; VTAPE: a tick every this many units...
tapeshr db 3                    ; ...one pixel per 2^this units
TAPEY0  = 50                    ; VTAPE's window, rows...
TAPEY1  = 150
TAPEMID = 100                   ; ...and the pointer's row
ladk    dw 0                    ; LADDER's rung, -8..8
ladcx   dw 0                    ; the rung's middle on the screen
ladcy   dw 0
ladx8   dw 0                    ; the walk along it, 8.8
lady8   dw 0
ladi    dw 0
ladpat  dw 0                    ; the pattern this rung is drawn with
ladsn   dw 0
tmark   dw 0                    ; the tapes' mark

;@ HPAT       plot (AX,BX) if bit CX of the 16-bit pattern [ladpat] is set
; ---- HPAT: plot (AX,BX) in [ladc] if pattern bit (CX and 15) of [ladpat]
;  is set and it is on the screen. Keeps every register.
HPAT:   push ax
        push bx
        push cx
        push dx
        push di
        and  cl,15
        mov  dx,[ladpat]
        rol  dx,cl              ; bit 15 = this pixel's bit
        or   dx,dx
        jns  .x                 ; a gap in the pattern
        cmp  ax,0
        jl   .x
        cmp  ax,319
        jg   .x
        cmp  bx,0
        jl   .x
        cmp  bx,199
        jg   .x
        mov  di,bx
        mov  cl,8
        shl  di,cl              ; y*256
        mov  cl,6
        shl  bx,cl              ; y*64
        add  di,bx
        add  di,ax
        mov  al,[ladc]
        mov  [es:di],al
.x:     pop  di
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

;@ LADDER     pitch ladder: rungs every 10 deg by true tangent, banked, dashed below
; ---- LADDER: rungs every 7 of 256 (~10 degrees), k = -8..8 but 0 (the
;  horizon is the horizon), 120 pixels long with a gap of 32 in the middle.
;  Keeps every register.
LADDER: push ax
        push bx
        push cx
        push dx
        push si
        push di
        mov  word [ladk],-8
.l:     cmp  word [ladk],0
        je   .next
        mov  ax,[ladk]          ; a = k*7 units = k*10 degrees
        mov  cx,7
        imul cx                 ; AX = k*7 (small)
        push ax
        call SINQ
        mov  [ladsn],ax         ; sin(a)*256
        pop  ax
        add  ax,64
        call SINQ               ; AX = cos(a)*256 (>= 44 for |a| <= 56)
        mov  cx,ax
        mov  ax,[ladsn]
        mov  bx,FOCAL
        imul bx                 ; DX:AX = sin*FOCAL
        idiv cx                 ; AX = tan(a)*FOCAL (< 1300: fits)
        neg  ax                 ; f: up the sky is negative rows
        mov  si,ax              ; SI = f
        ; the rung's middle: (hzcol - f*sin/256, hzrow + f*cos/256)
        imul word [hzsin]       ; DX:AX = f*sin
        mov  bx,256
        idiv bx                 ; / 256
        mov  di,[hzcol]
        sub  di,ax
        mov  [ladcx],di
        mov  ax,si
        imul word [hzcos]       ; DX:AX = f*cos
        idiv bx                 ; / 256
        add  ax,[hzrow]
        mov  [ladcy],ax
        cmp  ax,-60             ; the whole rung off the glass?
        jl   .next
        cmp  ax,260
        jg   .next
        mov  ax,[patup]         ; above the horizon: solid
        cmp  word [ladk],0
        jg   .p
        mov  ax,[patdn]         ; below: dashed
.p:     mov  [ladpat],ax
        mov  ax,[hzcos]         ; walk along the horizon's direction,
        mov  cx,-60             ;  8.8, starting 60 px to one side
        imul cx                 ; AX = cos*-60 (fits)
        mov  [ladx8],ax
        mov  ax,[hzsin]
        imul cx                 ; AX = sin*-60
        mov  [lady8],ax
        mov  word [ladi],0
.pt:    mov  ax,[ladi]          ; 0..119: the gap is 44..75
        cmp  ax,44
        jb   .vis
        cmp  ax,76
        jb   .skip
.vis:   mov  ax,[ladx8]
        mov  cl,8
        sar  ax,cl              ; whole pixels
        add  ax,[ladcx]
        mov  bx,[lady8]
        sar  bx,cl
        add  bx,[ladcy]
        mov  cx,[ladi]
        call HPAT
.skip:  mov  ax,[hzcos]         ; one pixel further along
        add  [ladx8],ax
        mov  ax,[hzsin]
        add  [lady8],ax
        inc  word [ladi]
        cmp  word [ladi],120
        jb   .pt
.next:  inc  word [ladk]
        cmp  word [ladk],8
        jle  .l
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

;@ COMPASS    heading tape across the top: a tick every 5.6 deg, a caret
; ---- COMPASS: 40 steps either side of the heading, a tick every 4 (5.6
;  degrees), a long one every 32 (45); x = 160 + off*3/2; a caret under the
;  middle. Rows 6..14. Keeps every register.
COMPASS:push ax
        push bx
        push cx
        push dx
        mov  ax,[pattk]
        mov  [ladpat],ax
        mov  ax,[heading]
        add  ax,219             ; heading - 40, +3 to round up, +256
        and  ax,0FFFCh          ; a multiple of four: the first tick
        mov  [tmark],ax
.cp:    mov  ax,[tmark]
        sub  ax,256
        sub  ax,[heading]       ; off: steps from the nose, signed
        cmp  ax,40
        jg   .cpd
        mov  bx,ax
        add  ax,ax
        add  ax,bx              ; off*3
        sar  ax,1               ; off*3/2 (SAR: off can be negative)
        add  ax,160             ; x
        mov  dx,4               ; a short tick: rows 10..13
        mov  bx,10
        test word [tmark],31
        jnz  .t
        mov  dx,8               ; a long one: rows 6..13
        mov  bx,6
.t:     xor  cx,cx              ; (pattern bit = the row)
.tr:    call HPAT
        inc  bx
        inc  cx
        dec  dx
        jnz  .tr
        add  word [tmark],4
        jmp  .cp
.cpd:   mov  ax,160             ; the caret
        mov  bx,16
        xor  cx,cx
        call HPAT
        dec  ax
        inc  bx
        call HPAT
        inc  ax
        call HPAT
        inc  ax
        call HPAT
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

;@ VTAPE      a vertical tape: value AX at column BX sliding past a pointer
; ---- VTAPE: AX = the value, BX = the column. Ticks every [tapestep]
;  units (long every 5th), 1 pixel per 2^[tapeshr] units, in rows
;  TAPEY0..TAPEY1; the pointer at TAPEMID. Keeps every register.
VTAPE:  push ax
        push bx
        push cx
        push dx
        push si
        push di
        mov  si,ax              ; SI = the value
        mov  di,bx              ; DI = the column
        mov  ax,[pattk]
        mov  [ladpat],ax
        mov  ax,TAPEMID-TAPEY0  ; the window's half height, in units:
        mov  cl,[tapeshr]
        shl  ax,cl              ;  rows << shift
        mov  dx,si
        sub  dx,ax              ; the bottom of the window, in units
        mov  ax,dx
        mov  cx,[tapestep]
        or   cx,cx
        jle  .ptr               ; a step of 0 or less: no ticks (no divide)
        cwd
        idiv cx                 ; AX = whole steps (toward 0), DX = rest
        or   dx,dx
        jle  .m0
        inc  ax                 ; round up when the rest is positive
.m0:    mov  [ladk],ax          ; the tick's number (for the long ones)
        imul cx                 ; AX = the first mark
        mov  [tmark],ax
.tk:    mov  ax,[tmark]
        sub  ax,si              ; mark - value
        mov  cl,[tapeshr]
        sar  ax,cl              ; in pixels
        mov  bx,TAPEMID
        sub  bx,ax              ; the row
        cmp  bx,TAPEY0
        jl   .ptr               ; past the top: done
        cmp  bx,TAPEY1
        jg   .tn
        mov  ax,[ladk]          ; long every 5th
        cwd
        mov  cx,5
        idiv cx                 ; DX = k mod 5
        mov  cx,4               ; short: 4 px
        or   dx,dx
        jnz  .tw
        mov  cx,8               ; long: 8 px
.tw:    mov  ax,di
.tp:    push cx
        xor  cx,cx
        call HPAT
        pop  cx
        inc  ax
        loop .tp
.tn:    mov  ax,[tapestep]
        add  [tmark],ax
        inc  word [ladk]
        jmp  .tk
.ptr:   mov  ax,di              ; the pointer: a small arrow at TAPEMID
        sub  ax,3
        mov  bx,TAPEMID
        xor  cx,cx
        call HPAT
        dec  ax
        dec  bx
        call HPAT
        add  bx,2
        call HPAT
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
