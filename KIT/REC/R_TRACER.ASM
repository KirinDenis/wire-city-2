; ============================================================================
;  R_TRACER.ASM - recipe: bullets as a pool of tracer rounds (2D).
;
;  OWL FLY III's shared tracer pool: every gun - the player's, a bot's, a
;  flak battery's - puts its rounds into ONE pool, round robin (a new
;  round takes the oldest slot), and the pool flies and draws whatever is
;  in the air, trigger held or not. A round lives TRLIFE ticks, droops a
;  little every fourth tick, and asks the game "did I hit something?" at
;  each step; a hit spends it. Drawn as a streak from its head back half a
;  step, flickering between two colours. Hit boxes wider than a step, or a
;  fast round jumps a thin wall between two samples (guide PHYSICS).
;  Positions 12.4 (pixels x16), speeds 16ths of a pixel a tick.
;
;        mov  ax,[shipx]         ; fire: from here (pixels)...
;        mov  bx,[shipy]
;        mov  cx,0               ; ...at this speed (16ths a tick)
;        mov  dx,-96             ;  up the screen, 6 px a tick
;        call TRFIRE
;        ...each tick:  mov dx,[tickcount] / call TRSTEP
;        ...each frame: call TRDRAW          ; ES = the buffer, 320 a row
;
;  copy: TRFIRE, TRSTEP, TRDRAW and the arrays.
;  define before: TRHIT - in: AX = x, BX = y (pixels), SI = the round;
;        out: CF=1 it hit (score, damage, a flash: yours), the round is
;        spent; keeps every register. A grid game: GRD_AT at
;        (x/TILE, y/TILE) and test GRD_WALL; R_DAMAGE's HIT for buildings.
;        rseed dw.
;  needs: ENGINE\E_MATH.INC (RND16, for the flicker)
;  from: GAMES\OWLFLY3\SRC\PLANES.INC:2886-3017 (TRCUPD: life, move, droop
;        1-in-4, hit tests), 3018-3110 (GUNDRAW: streak, flicker), 3239-3247
;        (the round robin trnext); 3D to 2D
; ============================================================================
NTRC    = 32                    ; rounds in the air at once: a power of two
TRLIFE  = 48                    ; ticks a round flies
TRC1    = 44                    ; its two colours (VGA default: yellow, red)
TRC2    = 40

; ----------------------------------------------------------------------
;@ TRFIRE     a round into the pool at pixel (AX,BX), speed CX,DX (16ths)
;  in:  AX = x, BX = y (pixels), CX = vx, DX = vy (16ths of a pixel a tick)
;  out: -  (the oldest round is overwritten when all are flying)
; ----------------------------------------------------------------------
TRFIRE: push ax
        push bx
        push si
        mov  si,[trnext]
        inc  word [trnext]      ; the next round takes the next slot...
        and  word [trnext],NTRC-1   ; ...round robin
        shl  si,1               ; word index
        push cx
        mov  cl,4
        shl  ax,cl              ; x * 16
        mov  [trx+si],ax
        shl  bx,cl              ; y * 16
        mov  [try+si],bx
        pop  cx
        mov  [trvx+si],cx
        mov  [trvy+si],dx
        mov  word [trlif+si],TRLIFE
        pop  si
        pop  bx
        pop  ax
        ret

; ----------------------------------------------------------------------
;@ TRSTEP     one tick of every round: age, move, droop, off-screen, TRHIT
;  in:  DX = a tick counter (the BIOS tick will do: the droop is 1 in 4)
;  out: CX = rounds still flying
; ----------------------------------------------------------------------
TRSTEP: push ax
        push bx
        push si
        push di
        xor  cx,cx
        xor  si,si              ; SI = the round
.t:     mov  di,si
        shl  di,1               ; word index
        cmp  word [trlif+di],0
        je   .n                 ; not flying
        dec  word [trlif+di]    ; one tick older
        jz   .n                 ; spent
        mov  ax,[trvx+di]
        add  [trx+di],ax        ; x += vx
        mov  ax,[trvy+di]
        add  [try+di],ax        ; y += vy
        test dx,3
        jnz  .nodrp
        inc  word [trvy+di]     ; the round droops as it flies (1 in 4)
.nodrp: mov  ax,[trx+di]
        push cx
        mov  cl,4
        sar  ax,cl              ; x, pixels
        mov  bx,[try+di]
        sar  bx,cl              ; y, pixels
        pop  cx
        cmp  ax,320
        jae  .gone              ; off the screen (unsigned: either side)
        cmp  bx,200
        jae  .gone
        call TRHIT              ; the game's question
        jc   .gone              ; a hit: spent
        inc  cx                 ; one more still flying
        jmp  .n
.gone:  mov  word [trlif+di],0
.n:     inc  si                 ; the next round
        cmp  si,NTRC
        jb   .t
        pop  di
        pop  si
        pop  bx
        pop  ax
        ret

; ----------------------------------------------------------------------
;@ TRDRAW     every flying round: a two-pixel streak, flickering
;  in:  ES = the buffer (320 a row)
;  out: -
; ----------------------------------------------------------------------
TRDRAW: push ax
        push bx
        push cx
        push dx
        push si
        push di
        xor  si,si
.t:     mov  bx,si
        shl  bx,1
        cmp  word [trlif+bx],0
        je   .n
        mov  ax,[trx+bx]
        mov  dx,[try+bx]
        call .dot               ; the head
        mov  cx,[trvx+bx]
        sar  cx,1
        sub  ax,cx              ; half a step back...
        mov  cx,[trvy+bx]
        sar  cx,1
        sub  dx,cx
        call .dot               ; ...the tail
.n:     inc  si
        cmp  si,NTRC
        jb   .t
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
; .dot - a pixel at 12.4 (AX,DX), yellow or red by lot. keeps AX, BX, DX.
.dot:   push ax
        push dx
        mov  cl,4
        sar  ax,cl              ; pixels
        sar  dx,cl
        cmp  ax,320
        jae  .dq
        cmp  dx,200
        jae  .dq
        mov  di,dx
        mov  cl,8
        shl  di,cl              ; y*256
        mov  cl,6
        shl  dx,cl              ; y*64
        add  di,dx
        add  di,ax              ; y*320 + x
        call RND16
        mov  al,TRC1
        test ah,10h
        jz   .dc
        mov  al,TRC2            ; a flicker of red
.dc:    mov  [es:di],al
.dq:    pop  dx
        pop  ax
        ret

trnext  dw 0                    ; the slot the next round takes
trlif   rw NTRC                 ; ticks left, 0 = not flying
trx     rw NTRC                 ; position, 12.4
try     rw NTRC
trvx    rw NTRC                 ; speed, 16ths of a pixel a tick
trvy    rw NTRC
