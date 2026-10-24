; ============================================================================
;  R_AIGUN.ASM - recipe: enemy guns - in range, a burst, and a dice roll.
;
;  Guide GAMEPLAY "Bots and their decisions": the AI may roll dice; the
;  player never does. OWL FLY III's bot guns: every ~0.8 s a RANDOM gunner
;  with the player within range fires a 4-round burst into the shared
;  tracer pool - real, visible rounds - and 1 burst in 4 connects. The
;  dice decide the hit, the rounds are the warning; the player's own
;  rounds are judged for real (R_TRACER's TRHIT). Tune AIRNG, AIGT and the
;  dice, never the player's armour.
;
;        ...each tick (DX = ticks gone):
;        call AIGUN
;        jnc  .safe
;        inc  byte [phits]       ; hit: yours to decide (a thump, a jolt,
;        ...                     ;  a red flash - three senses, one edge)
;
;  copy: AIGUN and its words.
;  define before: NEN (gunners), enx, eny (their pixel places, words),
;        enon (bytes, 1 alive), plx, ply (the player's pixel place); rseed.
;        A grid game: enx = column*TILE + TILE/2 from R_PATROL's encell.
;  calls: TRFIRE (R_TRACER.ASM)
;  needs: ENGINE\E_MATH.INC (RND16)
;  from: GAMES\OWLFLY3\SRC\PLANES.INC:3112-3300 (AIGUN: aigt 14 ticks,
;        range 2500 Manhattan, velocity = dir*75/max(|d|), spread +-3,
;        1 in 4); 3D to 2D, one target (the player)
; ============================================================================
AIGT    = 14                    ; ticks between bursts: ~0.8 s
AIRNG   = 120                   ; range, pixels (Manhattan)
AISPD   = 64                    ; a round's speed, 16ths of a pixel a tick

; ----------------------------------------------------------------------
;@ AIGUN      every AIGT ticks a random gunner in range fires a burst; CF=1 a hit
;  in:  DX = the ticks gone
;  out: CF=1 this burst hit the player (1 in 4); CF=0 no burst or a miss
; ----------------------------------------------------------------------
AIGUN:  push ax
        push bx
        push cx
        push dx
        push si
        push di
        sub  [aigt],dx          ; the clock between bursts
        jg   .no
        mov  word [aigt],AIGT
        call RND16
        xor  dx,dx
        mov  cx,NEN
        div  cx                 ; DX = which gunner (NEN >= 1)
        mov  si,dx
        cmp  byte [enon+si],0
        je   .no                ; that one is dead: no burst this time
        shl  si,1               ; word index
        mov  ax,[plx]
        sub  ax,[enx+si]
        mov  [aidx],ax          ; dx to the player
        jns  .p1
        neg  ax
.p1:    mov  bx,ax              ; BX = |dx|
        mov  ax,[ply]
        sub  ax,[eny+si]
        mov  [aidy],ax          ; dy to the player
        jns  .p2
        neg  ax
.p2:    mov  cx,ax              ; CX = |dy|
        add  ax,bx
        cmp  ax,AIRNG
        jae  .no                ; out of range
        cmp  cx,bx
        jle  .m
        mov  bx,cx              ; BX = m = max(|dx|,|dy|)
.m:     or   bx,bx
        jz   .no                ; on top of each other: hold fire
        mov  [aim],bx
        mov  di,4               ; a 4-round burst
.b:     mov  ax,[aidx]
        mov  cx,AISPD
        imul cx                 ; dx * speed
        idiv word [aim]         ; / m: |dx| <= m, so it is at most AISPD
        mov  cx,ax
        call RND16
        and  ax,7
        sub  ax,3               ; a spread -3..4
        add  cx,ax              ; CX = vx
        mov  ax,[aidy]
        mov  dx,AISPD
        imul dx                 ; dy * speed
        idiv word [aim]
        mov  dx,ax
        call RND16
        and  ax,7
        sub  ax,3
        add  dx,ax              ; DX = vy
        mov  ax,[enx+si]
        mov  bx,[eny+si]
        call TRFIRE             ; into the shared pool
        dec  di                 ; one round fewer to go
        jnz  .b
        call RND16
        test ah,3               ; the dice (high bits): 1 burst in 4 connects
        jnz  .no
        stc
        jmp  .r
.no:    clc
.r:     pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

aigt    dw AIGT                 ; ticks to the next burst
aidx    dw 0                    ; to the player, pixels
aidy    dw 0
aim     dw 1                    ; max(|dx|,|dy|)
