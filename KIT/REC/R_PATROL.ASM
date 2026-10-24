; ============================================================================
;  R_PATROL.ASM - recipe: enemies that patrol near a post, on a leash, and
;  chase the player by the shortest path when they see him (a grid game).
;
;  OWL FLY III's flak vehicle, put on a grid: the AI only fills DEMANDS -
;  here a direction to walk - and a separate mover carries them out at the
;  unit's own pace, never knowing who asked (UI.INC SHKAI / SHKMOVE; guide
;  GAMEPLAY "make a vehicle's controls demands"). Taking a unit over is
;  then free: the player's keys write its demand instead. A leg lasts a
;  few seconds, then a new direction; past LEASH from its post it stops
;  choosing and walks home. Character comes from limits, not accuracy:
;  SIGHT, CHASE and ENSTEP (its pace) are the difficulty knobs - tune the
;  opposition, never the player's armour.
;
;        ...at a new level, per enemy: encell = enpost = its cell, enon = 1,
;           and GRD_SET its cell with ENBIT
;        ...each tick (DX = ticks gone, R_TIMERS / K_TIME):
;        call PATROLAI           ; the demands
;        call PATROLMOVE         ; the moves: CF=1 an enemy reached the man
;
;  copy: PATROLAI, PATROLMOVE, MANHAT and the arrays.
;  define before: NEN (enemies), mancell (the player's cell: R_PUSH's),
;        rseed; ENBIT = a grid bit no other thing uses (GRD_OUT if free)
;  needs: LIB\K_GRID.INC (GRD_PATH, GRD_STEP, GRD_SET, GRD_CLR, GRD_XY,
;        grd_map); ENGINE\E_MATH.INC (RND16)
;  from: GAMES\OWLFLY3\SRC\UI.INC:3700-3742 (SHKAI: the leash, the legs),
;        3744-3800 (SHKMOVE: from the inputs and nothing else);
;        PLANES.INC:95-180 (the AI writes only headings); the chase by
;        GRD_PATH new
; ============================================================================
SIGHT   = 8                     ; cells (Manhattan) it sees the man from
CHASE   = 14                    ; the longest path it will chase along
LEASH   = 5                     ; cells from its post before it turns home
LEGT    = 6                     ; moves a patrol leg lasts
ENSTEP  = 6                     ; ticks between its steps: its pace (~3 a second)

; ----------------------------------------------------------------------
;@ PATROLAI   fill each enemy's demand: chase if it sees, home if far, else roam
;  in:  encell, enpost, enon; [mancell]
;  out: -  endem[i] = 0..3 (a direction) or 0FFh (stand)
; ----------------------------------------------------------------------
PATROLAI:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        xor  si,si              ; SI = the enemy
.e:     cmp  byte [enon+si],0
        je   .n
        push si
        shl  si,1               ; word index
        mov  bx,[encell+si]
        mov  di,[mancell]
        pop  si
        call MANHAT             ; AX = how far the man is
        cmp  ax,SIGHT
        ja   .home
        push si
        mov  dx,(GRD_WALL+GRD_BOX)*256 + GRD_FLOOR
        mov  si,patq
        call GRD_PATH           ; AX = the first step to him, CX = how far
        pop  si
        jc   .home              ; no way to him
        cmp  cx,CHASE
        ja   .home              ; too far round
        mov  [endem+si],al      ; chase
        jmp  .n
.home:  push si
        shl  si,1
        mov  bx,[encell+si]
        mov  di,[enpost+si]
        pop  si
        call MANHAT             ; AX = how far its post is
        cmp  ax,LEASH
        jbe  .leg
        push si
        mov  dx,(GRD_WALL+GRD_BOX)*256 + GRD_FLOOR
        mov  si,patq
        call GRD_PATH           ; the way home
        pop  si
        jc   .leg               ; none: roam instead
        mov  [endem+si],al
        jmp  .n
.leg:   dec  byte [enleg+si]    ; inside the leash: run the leg out
        jg   .n
        mov  byte [enleg+si],LEGT
        call RND16
        and  al,3               ; a new leg, any way
        mov  [endem+si],al
.n:     inc  si                 ; the next enemy
        cmp  si,NEN
        jb   .e
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; ----------------------------------------------------------------------
;@ PATROLMOVE carry out the demands at each enemy's pace (CF=1 one reached him)
;  in:  DX = the ticks gone since the last call
;  out: CF=1 AL = the enemy that walked into the man (the game decides what
;       that costs); CF=0 none
; ----------------------------------------------------------------------
PATROLMOVE:
        push bx
        push cx
        push si
        push di
        mov  byte [encaught],0FFh
        xor  si,si
.e:     cmp  byte [enon+si],0
        je   .n
        mov  di,si
        shl  di,1               ; word index
        sub  [enclk+di],dx      ; its pace clock down by the ticks
        jg   .n                 ; not time yet
        mov  word [enclk+di],ENSTEP
        mov  al,[endem+si]
        cmp  al,0FFh
        je   .n                 ; asked to stand
        push dx
        call GRD_STEP           ; DX = the step
        mov  bx,[encell+di]
        add  bx,dx              ; BX = where it would go
        pop  dx
        cmp  bx,[mancell]
        jne  .free
        mov  ax,si
        mov  [encaught],al      ; it reached him
        jmp  .n
.free:  mov  al,[grd_map+bx]
        test al,GRD_WALL or GRD_BOX or GRD_MAN or ENBIT
        jnz  .blk
        test al,GRD_FLOOR
        jz   .blk
        push bx
        mov  bx,[encell+di]
        mov  al,ENBIT
        call GRD_CLR            ; off its old cell
        pop  bx
        call GRD_SET            ; onto the new one
        mov  [encell+di],bx
        jmp  .n
.blk:   mov  byte [enleg+si],1  ; blocked: the next AI tick picks a new leg
.n:     inc  si
        cmp  si,NEN
        jb   .e
        mov  al,[encaught]
        cmp  al,0FFh
        je   .no
        stc
        jmp  .r
.no:    clc
.r:     pop  di
        pop  si
        pop  cx
        pop  bx
        ret

; ----------------------------------------------------------------------
;@ MANHAT     AX = |columns| + |rows| between cells BX and DI
;  in:  BX, DI = cells
;  out: AX = the Manhattan distance in cells
; ----------------------------------------------------------------------
MANHAT: push bx
        push cx
        push dx
        call GRD_XY             ; AL = column, AH = row of BX
        mov  dx,ax
        mov  bx,di
        call GRD_XY             ; of DI
        sub  al,dl              ; the columns apart, signed
        jns  .c
        neg  al
.c:     sub  ah,dh              ; the rows apart
        jns  .r
        neg  ah
.r:     mov  cl,ah
        xor  ah,ah
        xor  ch,ch
        add  ax,cx              ; AX = the sum
        pop  dx
        pop  cx
        pop  bx
        ret

encell  rw NEN                  ; each enemy's cell
enpost  rw NEN                  ; the cell it guards
enclk   rw NEN                  ; ticks to its next step
endem   rb NEN                  ; its demand: 0..3, 0FFh stand
enleg   rb NEN                  ; moves left on this leg
enon    rb NEN                  ; 1 = alive
encaught db 0
patq    rw GRD_CELLS            ; GRD_PATH's queue
