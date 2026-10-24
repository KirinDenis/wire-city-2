; ============================================================================
;  R_PUSH.ASM - recipe: the Sokoban step - walk, or push the crate in front.
;
;  One key, one step (guide TILES): the man walks into a free cell; a
;  crate in the way goes too if the cell behind it is floor with nothing
;  on it. A crate onto a goal +10, off one -10 - points by rule both ways.
;  The level is won when grd_ngood = grd_nbox. After a step, empty the
;  BIOS key buffer (K_KEYS' flush, MULTSOK2 FLUSHKB) or a held key walks on.
;
;        mov  al,dir             ; 0 up 1 right 2 down 3 left (GRD_KEYDIR)
;        call PUSHMOVE
;        jc   .refused           ; a wall, a man, a stuck crate: nothing moved
;        call HREC               ; R_UNDO: AL is what to remember
;        mov  ax,[grd_ngood]
;        cmp  ax,[grd_nbox]
;        je   .won
;
;  copy: PUSHMOVE and mancell.
;  define before: SCORE (CX points, BX the cell: R_SCORE.ASM, or your own
;        that keeps every register)
;  needs: LIB\K_GRID.INC (GRD_STEP, GRD_INSIDE, grd_map, grd_ngood);
;        the level loaded with GRD_LOAD and flooded with GRD_FLOOR from the man
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:1658-1752 (MOVE/STEP: one man, the
;        network, the gate, the owl and the diamond taken out)
; ============================================================================

; ----------------------------------------------------------------------
;@ PUSHMOVE   the man one step AL; a crate in front goes too if it can
;  in:  AL = direction 0..3, [mancell] = his cell (GRD_MAN set on it)
;  out: AH = the direction; CF=1 refused, nothing changed; CF=0 AL = the step for R_UNDO:
;       the direction, +4 if a crate went; [mancell] moved, grd_ngood
;       counted, SCORE called (+10 onto a goal, -10 off one)
; ----------------------------------------------------------------------
PUSHMOVE:
        push bx
        push cx
        push dx
        push di
        push bp
        and  al,3
        mov  ah,al              ; AH = the direction, kept
        call GRD_STEP           ; DX = the step in cells
        mov  di,[mancell]       ; DI = where he stands
        mov  bx,di
        add  bx,dx              ; BX = the cell he steps into
        call GRD_INSIDE
        jc   .no
        mov  al,[grd_map+bx]
        test al,GRD_WALL or GRD_MAN
        jnz  .no                ; a wall, or another man
        xor  ch,ch              ; CH = 4 if a crate goes
        test al,GRD_BOX
        jz   .walk
        mov  bp,bx
        add  bp,dx              ; BP = the cell behind the crate
        xchg bx,bp
        call GRD_INSIDE         ; (on the level at all?)
        xchg bx,bp
        jc   .no
        mov  cl,[grd_map+bp]    ; CL = its bits (SS = DS in a .COM)
        test cl,GRD_WALL or GRD_BOX or GRD_MAN
        jnz  .no                ; something there: the crate is stuck
        test cl,GRD_FLOOR
        jz   .no                ; outside the walls
        and  byte [grd_map+bx],0FFh xor GRD_BOX   ; the crate leaves...
        or   byte [grd_map+bp],GRD_BOX            ; ...and lands
        mov  ch,4
        test al,GRD_GOAL
        jz   .off
        push cx
        mov  cx,-10             ; off a goal: -10
        call SCORE
        pop  cx
        dec  word [grd_ngood]   ; one crate fewer home
.off:   test cl,GRD_GOAL
        jz   .walk
        push cx
        mov  cx,10              ; onto a goal: +10
        call SCORE
        pop  cx
        inc  word [grd_ngood]   ; one more home
.walk:  and  byte [grd_map+di],0FFh xor GRD_MAN
        or   byte [grd_map+bx],GRD_MAN
        mov  [mancell],bx
        mov  al,ah
        or   al,ch              ; AL = direction + 4 if pushed
        clc
        jmp  .r
.no:    mov  al,ah
        stc
.r:     pop  bp
        pop  di
        pop  dx
        pop  cx
        pop  bx
        ret

mancell dw 0                    ; the man's cell (set it from grd_start)
