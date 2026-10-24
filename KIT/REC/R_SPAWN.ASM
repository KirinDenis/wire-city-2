; ============================================================================
;  R_SPAWN.ASM - recipe: a prize on a random free cell, and a timed bomb.
;
;  Guide TILES: "a rare prize that comes and goes" - a diamond grows out of
;  the floor 20 to 27 s apart, lies 15 s; it must never block a move. And
;  "mines are the game's sting": one a man, 5 s of fuse, then the nine
;  cells round it stand still for 15 s, whoever laid it; the next a minute
;  later. Consequences, not guardrails.
;
;        mov  al,GRD_WALL+GRD_BOX+GRD_MAN+GRD_GOAL+GRD_ITEM+GRD_FLOOR ; looked at
;        mov  ah,GRD_FLOOR                                  ; must be: bare floor
;        call SPAWNAT            ; CF=1 none free: try again in 5 s
;        mov  [gemcell],bx
;
;        mov  bx,[mancell]
;        call MINESET            ; Space: the mine where he stands
;        ...each frame, DX = the ticks gone (R_TIMERS):
;        call MINETICK           ; CF=1 it went off now:
;        jnc  .q
;        mov  bx,[mancell]
;        call INBLAST            ; CF=1 he was in the nine cells
;
;  copy: SPAWNAT, MINESET, MINETICK, INBLAST and the words at the end.
;  define before: rseed dw (seed it from the tick, OR 1)
;  needs: ENGINE\E_MATH.INC (RND16), LIB\K_GRID.INC (grd_map)
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:2202-2247 (GEMSPAWN: count the cells
;        that will do, pick one by lot), 2249-2312 (BLAST, PLACEMINE),
;        2094-2117 (TICKER's mines: a signed clock, fuse then blast)
; ============================================================================
FUSE    = 91                    ; ticks a mine ticks: 5 s
BLASTT  = 9                     ; ticks the blast shows: half a second

; ----------------------------------------------------------------------
;@ SPAWNAT    BX = a random cell whose bits AND AL equal AH (by lot, fair)
;  in:  AL = the bits looked at, AH = what they must be
;  out: CF=0 BX = the cell; CF=1 no cell will do (BX kept)
; ----------------------------------------------------------------------
SPAWNAT:push ax
        push cx
        push dx
        push bx
        xor  cx,cx              ; CX = how many cells will do
        xor  bx,bx
.c:     call .ok
        jne  .cn
        inc  cx                 ; one more
.cn:    inc  bx                 ; the next cell
        cmp  bx,GRD_CELLS
        jb   .c
        jcxz .none
        push ax
        call RND16              ; AX = a random word
        xor  dx,dx
        div  cx                 ; DX = which of them (CX >= 1: no fault)
        pop  ax
        xor  bx,bx
.f:     call .ok
        jne  .fn
        or   dx,dx
        jz   .here
        dec  dx                 ; one fewer to pass
.fn:    inc  bx                 ; the next cell
        jmp  .f
.here:  add  sp,2               ; drop the BX that came in
        pop  dx
        pop  cx
        pop  ax
        clc
        ret
.none:  pop  bx
        pop  dx
        pop  cx
        pop  ax
        stc
        ret
.ok:    push ax                 ; ZF=1: cell BX will do
        and  al,[grd_map+bx]    ; its bits under the mask
        cmp  al,ah
        pop  ax
        ret

; ----------------------------------------------------------------------
;@ MINESET    lay the mine on cell BX: a FUSE-tick fuse (CF=1 one still burns)
;  in:  BX = the cell
;  out: CF=1 refused (the last mine is still there); CF=0 laid
; ----------------------------------------------------------------------
MINESET:cmp  word [minecell],0FFFFh
        jne  .no                ; the last one still burns
        mov  [minecell],bx
        mov  word [mineleft],FUSE
        clc
        ret
.no:    stc
        ret

; ----------------------------------------------------------------------
;@ MINETICK   the mine's clock by DX ticks: CF=1 it went off in this call
;  in:  DX = the ticks gone (R_TIMERS)
;  out: CF=1 the blast now (INBLAST says who is caught); [mineleft] < 0
;       while the blast shows, [minecell] = 0FFFFh once it is over
; ----------------------------------------------------------------------
MINETICK:
        push ax
        cmp  word [minecell],0FFFFh
        je   .q                 ; no mine
        mov  ax,[mineleft]
        or   ax,ax
        js   .fade              ; the blast is showing
        sub  ax,dx              ; the fuse burns
        jg   .burn
        mov  word [mineleft],-BLASTT    ; out: the blast
        pop  ax
        stc
        ret
.burn:  mov  [mineleft],ax
        jmp  .q
.fade:  add  ax,dx              ; the blast fades
        js   .fd
        mov  word [minecell],0FFFFh     ; gone
        jmp  .q
.fd:    mov  [mineleft],ax
.q:     pop  ax
        clc
        ret

; ----------------------------------------------------------------------
;@ INBLAST    CF=1 if cell BX is one of the nine round the mine
;  in:  BX = a cell
;  out: CF=1 inside the blast's nine cells
; ----------------------------------------------------------------------
INBLAST:push ax
        push cx
        cmp  word [minecell],0FFFFh
        je   .no
        mov  ax,[minecell]
        mov  ch,al
        and  ch,31              ; CH = its column
        mov  cl,5
        shr  ax,cl
        mov  cl,al              ; CL = its row
        mov  al,bl
        and  al,31              ; AL = the cell's column
        sub  al,ch
        inc  al                 ; -1, 0, +1 away become 0, 1, 2
        cmp  al,2
        ja   .no                ; (anything further, either way, is more)
        mov  ax,bx
        push cx
        mov  cl,5
        shr  ax,cl              ; AX = the cell's row
        pop  cx
        sub  al,cl
        inc  al                 ; -1, 0, +1 become 0, 1, 2
        cmp  al,2
        ja   .no
        pop  cx
        pop  ax
        stc
        ret
.no:    pop  cx
        pop  ax
        clc
        ret

minecell dw 0FFFFh              ; the mine's cell, 0FFFFh none
mineleft dw 0                   ; ticks of fuse; below 0 the blast, up to 0
