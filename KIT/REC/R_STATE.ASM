; ============================================================================
;  R_STATE.ASM - recipe: the game's states - a title card, play, an end card.
;
;  One byte says what the game is doing; each tick does only what that
;  state does, and the picture draws the card of the state over the world
;  (EXAMPLES\SOLO.ASM: 0 parked on the title, 1 flying, 6 holding the card
;  that says how it ended - "THE BELLY GRINDS", "BROKEN"...). The end card
;  is the judge's verdict (R_LAND): it names the cause.
;
;        ...each tick:
;        mov  ah,[key]           ; the scan code pressed this tick, 0 none
;        call STATETICK
;        ...each frame, after the world:
;        call CARDTEXT           ; SI = the card's text, 0 = none in play
;        or   si,si
;        jz   .nocard
;        ...print it in the middle (K_DRAW / your TXT)
;
;  copy: STATETICK, CARDTEXT and the words; add states to sttab.
;  define before: NEWGAME (a fresh game: keeps every register),
;        PLAYTICK (one tick of play: CF=1 the game ended, SI = the end
;        card's text; keeps every other register)
;  calls: those two.   needs: -
;  from: EXAMPLES\SOLO.ASM:267-300 (TICK by state), 933-949 (the cards);
;        the card's minimum hold new (a key held from play must not skip it)
; ============================================================================
ST_TITLE = 0                    ; the title card: Enter plays
ST_PLAY  = 1                    ; the game runs
ST_END   = 2                    ; the end card: a key back to the title
CARDHOLD = 18                   ; ticks an end card shows before a key counts: 1 s

; ----------------------------------------------------------------------
;@ STATETICK  one tick of the game by its state (title, play, end card)
;  in:  AH = the scan code pressed this tick (0 none)
;  out: -  [state] may change
; ----------------------------------------------------------------------
STATETICK:
        push bx
        mov  bl,[state]
        xor  bh,bh
        shl  bx,1               ; a word per state
        call [sttab+bx]
        pop  bx
        ret
sttab   dw ST0TICK, ST1TICK, ST2TICK

ST0TICK:cmp  ah,1Ch             ; Enter?
        jne  .r
        call NEWGAME
        mov  byte [state],ST_PLAY
.r:     ret

ST1TICK:push si
        call PLAYTICK           ; CF=1: over, SI = why
        jnc  .r
        mov  [cardp],si
        mov  word [cardclk],CARDHOLD
        mov  byte [state],ST_END
.r:     pop  si
        ret

ST2TICK:cmp  word [cardclk],0
        je   .k
        dec  word [cardclk]     ; still holding
        ret
.k:     or   ah,ah
        jz   .r                 ; no key yet
        mov  byte [state],ST_TITLE
.r:     ret

; ----------------------------------------------------------------------
;@ CARDTEXT   SI = the text of the card to draw now (0 in play)
;  in:  -
;  out: SI = TITLETXT on the title, the verdict on the end card, 0 in play
; ----------------------------------------------------------------------
CARDTEXT:
        xor  si,si
        cmp  byte [state],ST_PLAY
        je   .r
        mov  si,TITLETXT
        cmp  byte [state],ST_TITLE
        je   .r
        mov  si,[cardp]
.r:     ret

state   db ST_TITLE             ; what the game is doing
cardp   dw 0                    ; the end card's text
cardclk dw 0                    ; ticks before a key ends the card
TITLETXT db 'ENTER TO PLAY',0   ; your title
