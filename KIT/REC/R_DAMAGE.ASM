; ============================================================================
;  R_DAMAGE.ASM - recipe: things that take a few hits and then stay rubble.
;
;  OWL FLY III's town: one BIT a cell says "rubble" (4096 cells, 512 bytes),
;  and only the buildings being hit right now need a hit count - a tiny
;  table of four, round robin ("an old wound may be forgotten, war is
;  hazy"). A ruin stays on the map in grey: the ruin is information (guide
;  GAMEPLAY). Decrement and act in the same place: count down and destroy
;  at zero in one routine, or an immortal thing is born (WAR.INC WSHKGF).
;
;        call RUINED             ; BX = the cell hit
;        jnz  .through           ; rubble already: the shot sails on
;        call RND16
;        and  al,3
;        inc  al                 ; a fresh one takes 1..4 more hits
;        call HIT
;        jnc  .standing
;        ...it fell: a wreck (R_DEBRIS), a fireball (R_BLAST), points
;
;  copy: RUINED, RUIN, HIT and the words at the end.
;  define before: -   calls: -   needs: - (cells 0..4095: a 64x64 map,
;        or K_GRID's 0..1023)
;  from: GAMES\OWLFLY3\SRC\PLANES.INC:3960-4053 (BCHK, BSET, BDAMAGE).
;        TRAP there: the table's cells start as 0, so cell 0 would read as
;        a wound already in the table - here they start as 0FFFFh.
; ============================================================================
NWOUND  = 4                     ; things remembered as hit-but-standing

; ----------------------------------------------------------------------
;@ RUINED     ZF=0 if cell BX is rubble
;  in:  BX = a cell 0..4095
;  out: ZF=0 rubble, ZF=1 standing
; ----------------------------------------------------------------------
RUINED: push ax
        push bx
        push cx
        and  bx,4095            ; never past the bitmap
        mov  cl,bl
        and  cl,7               ; the bit,
        shr  bx,1
        shr  bx,1
        shr  bx,1               ; the byte: cell / 8
        mov  al,1
        shl  al,cl
        test [ruins+bx],al
        pop  cx                 ; (POP keeps the flags)
        pop  bx
        pop  ax
        ret

; ----------------------------------------------------------------------
;@ RUIN       make cell BX rubble for good
;  in:  BX = a cell 0..4095
;  out: -
; ----------------------------------------------------------------------
RUIN:   push ax
        push bx
        push cx
        and  bx,4095
        mov  cl,bl
        and  cl,7               ; the bit,
        shr  bx,1
        shr  bx,1
        shr  bx,1               ; the byte
        mov  al,1
        shl  al,cl
        or   [ruins+bx],al      ; down it goes
        pop  cx
        pop  bx
        pop  ax
        ret

; ----------------------------------------------------------------------
;@ HIT        one hit on cell BX: CF=1 it fell with this one (now rubble)
;  in:  BX = the cell; AL = how many MORE hits a fresh one takes, 1..255
;       (only read on its first hit)
;  out: CF=1 it fell (RUIN done); CF=0 still standing (or rubble already)
; ----------------------------------------------------------------------
HIT:    push ax
        push si
        call RUINED
        jnz  .stand             ; rubble already: nothing to hit
        xor  si,si
.s:     cmp  [wcell+si],bx
        je   .known
        add  si,2               ; the next wound
        cmp  si,NWOUND*2
        jb   .s
        mov  si,[wnext]         ; a fresh one: this hit counted, it takes AL more
        add  word [wnext],2     ; the next fresh one goes in the next slot...
        and  word [wnext],NWOUND*2-1   ; ...round robin (NWOUND a power of two)
        mov  [wcell+si],bx
        shr  si,1               ; a byte a count
        mov  [whp+si],al
        jmp  .stand
.known: shr  si,1
        dec  byte [whp+si]      ; one hit fewer to go
        jnz  .stand
        shl  si,1
        mov  word [wcell+si],0FFFFh   ; the slot is free again
        call RUIN
        pop  si
        pop  ax
        stc
        ret
.stand: pop  si
        pop  ax
        clc
        ret

wcell   dw NWOUND dup 0FFFFh    ; the wounded cells (0FFFFh: a free slot)
whp     db NWOUND dup 0         ; the hits each still takes
wnext   dw 0                    ; the slot a fresh wound takes
ruins   rb 512                  ; a bit a cell: rubble (zero it at a new map)
