; ============================================================================
;  R_SCRIPT.ASM - recipe: a keyframe script - moves played by the tick.
;
;  A script is a list of segments: for so many ticks, add this much to one
;  value and that much to another each tick (EXAMPLES\FLIGHT.ASM's airshow:
;  roll rate and pitch rate; a title's camera, a boss's dance, a demo's
;  hands). The script owns nothing: two pointers say which words it moves.
;  Keep demo moves gentle (guide GAMEPLAY: a 700 ms full pull stalls).
;
;  A SCRIPT:   dw ticks, add to A, add to B   ...   dw 0  (the end)
;        MYSHOW  dw 17, 0,-5             ; 17 ticks: A still, B down 5 a tick
;                dw 32, 4, 0             ; 32 ticks: A up 4 a tick
;                dw 0
;
;        mov  bx,MYSHOW
;        mov  word [scpa],roll ; the words it moves
;        mov  word [scpb],hrow
;        call SCRSTART
;        ...each tick:
;        call SCRSTEP            ; CF=1: the script is over
;
;  copy: SCRSTART, SCRSTEP and the words.
;  define before: -   calls: -   needs: -
;  from: EXAMPLES\FLIGHT.ASM:278-310 (the maneuver script), 1706 (MSCRIPT);
;        the two targets made pointers (FLIGHT moved roll and hrow)
; ============================================================================

; ----------------------------------------------------------------------
;@ SCRSTART   start the keyframe script at BX (segments: dw ticks, dA, dB)
;  in:  BX -> the script; [scpa], [scpb] -> the two words it moves
;  out: -
; ----------------------------------------------------------------------
SCRSTART:
        mov  [scptr],bx
        mov  word [scleft],0  ; the first SCRSTEP loads the first segment
        ret

; ----------------------------------------------------------------------
;@ SCRSTEP    one tick of the script: add its rates to the two words
;  in:  -
;  out: CF=1 the script is over (nothing moved); CF=0 a tick played
; ----------------------------------------------------------------------
SCRSTEP:push ax
        push bx
        cmp  word [scleft],0
        jne  .go
        mov  bx,[scptr]       ; load the next segment
        mov  ax,[bx]
        or   ax,ax
        jz   .end               ; the 0: over
        mov  [scleft],ax
        mov  ax,[bx+2]
        mov  [scda],ax
        mov  ax,[bx+4]
        mov  [scdb],ax
        add  bx,6               ; the next segment
        mov  [scptr],bx
.go:    mov  bx,[scpa]
        mov  ax,[scda]
        add  [bx],ax            ; A += its rate
        mov  bx,[scpb]
        mov  ax,[scdb]
        add  [bx],ax            ; B += its rate
        dec  word [scleft]    ; one tick of the segment gone
        clc
        jmp  .r
.end:   stc
.r:     pop  bx
        pop  ax
        ret

scptr    dw 0                   ; the next segment
scleft   dw 0                   ; ticks left in this one
scda     dw 0                   ; its rate for A
scdb     dw 0                   ; and for B
scpa     dw scsink              ; -> the word A (set them before SCRSTART)
scpb     dw scsink              ; -> the word B
scsink   dw 0                   ; where an unset target's adds go
