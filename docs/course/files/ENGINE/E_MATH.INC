; E_MATH.INC - WIRE CITY engine: integer math primitives
; ============================================================================
;  The engine modules are the game's own code, split out so that small
;  standalone examples (see EXAMPLES\) can share them. Each module states
;  its CONTRACT: the symbols the including program must define.
;
;  CONTRACT: the includer defines
;     rseed  dw  - LCG state, seed it non-zero (the game uses the BIOS
;                  tick count at 0040h:006Ch, so every run differs)
; ============================================================================

; ----------------------------------------------------------------------------
;  RND16 - LCG pseudo-random.  out: AX. preserves BX,DX (MUL clobbers DX!).
; ----------------------------------------------------------------------------
RND16:  push bx
        push dx
        mov  ax,[rseed]
        mov  bx,25173
        mul  bx
        add  ax,13849
        mov  [rseed],ax
        pop  dx
        pop  bx
        ret
