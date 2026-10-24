; ============================================================================
;  R_DEAD.ASM - recipe: say when the level can no longer be won.
;
;  Guide TILES, "Mercy": a crate not on a goal that sits where no push can
;  ever bring it home, or in a 2x2 square that is all crates and walls
;  (none of the four can ever move again), loses the level. Cross it in
;  red and say the way out: "STUCK: BACKSPACE STEPS BACK, R R ANEW".
;  Where a crate can still go home is computed once a level (LIVEGEN):
;  from every goal, PULL a crate back - the cell it comes to and the cell
;  the man then stands on must both be floor - a search over the walls only.
;
;        call GRD_LOAD ... GRD_FLOOD     ; the floor first
;        mov  si,queue
;        call LIVEGEN                    ; once a level
;        ...after every push and step back:
;        call STUCK
;        jc   .lost                      ; BX = the crate to cross out
;
;  copy: LIVEGEN, LIVEAT, STUCK and live.
;  define before: -
;  needs: LIB\K_GRID.INC (grd_map with GRD_FLOOR flooded); a queue of 2
;        bytes a cell (2048 bytes always do)
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:1249-1369 (LIVEGEN, LIVEAT, STUCK)
; ============================================================================

; ----------------------------------------------------------------------
;@ LIVEGEN    mark every cell a crate could still be pushed home from
;  in:  SI -> a queue, 2 bytes a cell
;  out: -  (live: a bit a cell)
; ----------------------------------------------------------------------
LIVEGEN:push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        push es
        push ds
        pop  es
        mov  di,live
        mov  cx,GRD_CELLS/16    ; 1024 bits: 64 words
        xor  ax,ax
        cld
        rep  stosw              ; none live yet
        mov  di,si              ; the queue: SI its head, DI its tail
        xor  bx,bx
.g:     mov  al,[grd_map+bx]
        and  al,GRD_GOAL or GRD_FLOOR
        cmp  al,GRD_GOAL or GRD_FLOOR
        jne  .gn
        call .mark              ; every goal: a crate there is home
.gn:    inc  bx                 ; the next cell
        cmp  bx,GRD_CELLS
        jb   .g
.take:  cmp  si,di
        jae  .r
        mov  bx,[si]
        add  si,2               ; head on
        mov  dx,-1              ; pulled left,
        call .pull
        mov  dx,1               ;  right,
        call .pull
        mov  dx,-GRD_ROW        ;  up,
        call .pull
        mov  dx,GRD_ROW         ;  down
        call .pull
        jmp  .take
.r:     pop  es
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
.pull:  push bx
        add  bx,dx              ; where the crate comes to
        test byte [grd_map+bx],GRD_FLOOR
        jz   .pn
        mov  bp,bx
        add  bp,dx              ; where the man then stands (SS = DS)
        test byte [grd_map+bp],GRD_FLOOR
        jz   .pn
        call LIVEAT
        jnz  .pn                ; known already
        call .mark
.pn:    pop  bx
        ret
.mark:  push ax
        push bx
        push cx
        mov  cl,bl
        and  cl,7               ; CL = the bit,
        shr  bx,1
        shr  bx,1
        shr  bx,1               ; BX = the byte: cell / 8
        mov  al,1
        shl  al,cl
        or   [live+bx],al       ; live...
        pop  cx
        pop  bx
        pop  ax
        mov  [di],bx            ; ...and queued
        add  di,2               ; tail on
        ret

; ----------------------------------------------------------------------
;@ LIVEAT     ZF=0 if a crate on cell BX can still be pushed home
;  in:  BX = a cell 0..1023
;  out: ZF=0 live, ZF=1 dead
; ----------------------------------------------------------------------
LIVEAT: push ax
        push bx
        push cx
        mov  cl,bl
        and  cl,7               ; the bit,
        shr  bx,1
        shr  bx,1
        shr  bx,1               ; the byte: cell / 8
        mov  al,1
        shl  al,cl
        test [live+bx],al
        pop  cx                 ; (POP keeps the flags)
        pop  bx
        pop  ax
        ret

; ----------------------------------------------------------------------
;@ STUCK      CF=1, BX = a crate that can never go home (the level is lost)
;  in:  -
;  out: CF=1 BX = its cell; CF=0 none (BX kept)
; ----------------------------------------------------------------------
STUCK:  push ax
        push si
        push bx
        xor  bx,bx
.c:     mov  al,[grd_map+bx]
        and  al,GRD_BOX or GRD_GOAL
        cmp  al,GRD_BOX
        jne  .n                 ; no crate, or one home
        call LIVEAT
        jz   .yes               ; where no push brings it home
        mov  si,bx              ; the four squares it is in: its own,
        call .sq                ;  with it top left,
        jc   .yes
        dec  si                 ;  top right,
        call .sq
        jc   .yes
        sub  si,GRD_ROW         ;  bottom right,
        call .sq
        jc   .yes
        inc  si                 ;  bottom left
        call .sq
        jc   .yes
.n:     inc  bx                 ; the next cell
        cmp  bx,GRD_CELLS
        jb   .c
        pop  bx                 ; none
        pop  si
        pop  ax
        clc
        ret
.yes:   add  sp,2               ; drop the BX that came in
        pop  si
        pop  ax
        stc
        ret
.sq:    test byte [grd_map+si],GRD_WALL or GRD_BOX          ; CF=1: the
        jz   .open                                          ;  square at SI
        test byte [grd_map+si+1],GRD_WALL or GRD_BOX        ;  (its top left)
        jz   .open                                          ;  all crates
        test byte [grd_map+si+GRD_ROW],GRD_WALL or GRD_BOX  ;  and walls
        jz   .open
        test byte [grd_map+si+GRD_ROW+1],GRD_WALL or GRD_BOX
        jz   .open
        stc
        ret
.open:  clc
        ret

live    rb GRD_CELLS/8          ; LIVEGEN: a bit a cell, a crate can go home
