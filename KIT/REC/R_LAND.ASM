; ============================================================================
;  R_LAND.ASM - recipe: judge an outcome by thresholds, the first rule
;  broken names the cause.
;
;  EXAMPLES\SOLO.ASM's TOUCH judges a landing in one place: no gear - the
;  belly grinds; sinking over 4 m/s - broken; off the concrete - grass;
;  else a kiss, as loud as the sink it came with. Guide PHYSICS: "a new
;  outcome hooks into the one place an outcome is decided"; GAMEPLAY: keep
;  the sting and make its cause visible. As data, a judge is a table: the
;  rules in order, each a word, a limit, how it fails, and its verdict.
;
;  A RULE:  dw the word judged, the limit  db J_GT/J_LT/J_ZERO  dw the verdict
;        TOUCHRULES:
;                dw gear, 0          ; no legs?
;                db J_ZERO
;                dw MBELLY           ;   'THE BELLY GRINDS'
;                dw vs64, 256        ; over 4 m/s down (1/64 m/s)?
;                db J_GT
;                dw MSLAM            ;   'BROKEN'
;                dw offrwy, 0        ; off the concrete (worked out first)?
;                db J_GT
;                dw MGRASS
;                dw 0                ; the end: all kept - a landing
;
;        mov  si,TOUCHRULES
;        call JUDGE
;        jnc  .kiss              ; every rule kept
;        mov  [cardp],si         ; the verdict: R_STATE's end card
;
;  copy: JUDGE and the J_ numbers.   define before: -   calls: -   needs: -
;  from: EXAMPLES\SOLO.ASM:614-651 (TOUCH), made a table (new)
; ============================================================================
J_GT    = 0                     ; broken if the word > the limit (signed)
J_LT    = 1                     ; broken if the word < the limit (signed)
J_ZERO  = 2                     ; broken if the word is 0 (the limit unused)
J_UGT   = 3                     ; broken if the word > the limit (UNSIGNED:
                                ;  a height 62000 is not -3536)

; ----------------------------------------------------------------------
;@ JUDGE      the first rule of table SI that is broken: SI = its verdict
;  in:  SI -> rules of 7 bytes: dw word, limit, db how, dw verdict; dw 0 ends
;  out: CF=1 SI = the verdict of the first broken rule; CF=0 all kept (SI
;       at the table's end)
; ----------------------------------------------------------------------
JUDGE:  push ax
        push bx
.r:     mov  bx,[si]            ; BX -> the word judged
        or   bx,bx
        jz   .kept              ; the end: nothing broken
        mov  ax,[bx]            ; AX = its value
        mov  bl,[si+4]          ; BL = how it fails
        cmp  bl,J_ZERO
        je   .z
        cmp  bl,J_LT
        je   .lt
        cmp  bl,J_UGT
        je   .ugt
        cmp  ax,[si+2]          ; J_GT
        jg   .broken
        jmp  .next
.lt:    cmp  ax,[si+2]
        jl   .broken
        jmp  .next
.ugt:   cmp  ax,[si+2]
        ja   .broken
        jmp  .next
.z:     or   ax,ax
        jz   .broken
.next:  add  si,7               ; the next rule
        jmp  .r
.broken:mov  si,[si+5]          ; SI = its verdict
        pop  bx
        pop  ax
        stc
        ret
.kept:  pop  bx
        pop  ax
        clc
        ret
