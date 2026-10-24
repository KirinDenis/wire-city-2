; ============================================================================
;  R_TIMERS.ASM - recipe: a game's clocks, counted down by the BIOS tick.
;
;  Guide TILES "Phases and clocks", TIME: every clock of the game - a fuse,
;  a man standing still after a blast, the wait for the next mine, the
;  gate rising, the diamond's life - is a word of ticks counted down by the
;  ticks since the last frame, capped at 2 s after a stall, never under 0.
;  An event fires on the EDGE (the call in which a clock reaches 0), never
;  on "it equals 9 now", which is true on different ticks on different
;  machines.
;
;        mov  word [clocks+CK_GEM*2],364   ; a diamond in 20 s
;        ...every frame:
;        call TIMERS             ; AX = the clocks that ran out just now
;        test ax,1 shl CK_GEM
;        jz   .nogem
;        call SPAWNAT ...        ; R_SPAWN
;        ...DX = the ticks gone: hand it to the other clocks (POPTICK...)
;
;  Pause: while paused call TIMOFF instead - tmlast stays fresh, nothing
;  counts, and the resume has no catch-up burst.
;
;  copy: TIMERS, TIMOFF and the words at the end; set NCLK and name the
;        clocks (CK_GEM = 0, CK_MINE = 1 ...).
;  define before: -   calls: -   needs: -
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:2036-2065 (TIMERS), 2072-2189
;        (TICKER: elapsed capped at 36, .down to 0 never under)
; ============================================================================
NCLK    = 8                     ; clocks: up to 16 (a bit each in AX)
TMCAP   = 36                    ; the most ticks one call counts: 2 s

; ----------------------------------------------------------------------
;@ TIMERS     count every running clock down by the ticks since the last call
;  in:  clocks (words: 0 = not running)
;  out: AX = a bit per clock that reached 0 in THIS call; DX = the ticks
;       counted (0..TMCAP); CX = how many clocks still run
; ----------------------------------------------------------------------
TIMERS: push bx
        push si
        push es
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:046Ch]      ; the BIOS tick, 18.2 a second
        pop  es
        mov  dx,ax
        sub  dx,[tmlast]        ; ticks since the last call (wraps cleanly)
        mov  [tmlast],ax
        cmp  dx,TMCAP           ; UNSIGNED: a midnight jump is huge, not negative
        jbe  .d
        mov  dx,TMCAP           ; after a stall: two seconds at most
.d:     xor  ax,ax              ; AX = the clocks that ran out
        xor  cx,cx              ; CX = the clocks still running
        xor  si,si              ; SI = the clock's place (words)
        mov  bx,1               ; BX = its bit
.c:     cmp  word [clocks+si],0
        je   .n                 ; not running
        sub  [clocks+si],dx     ; down by the ticks...
        ja   .run               ; (unsigned: still above 0)
        mov  word [clocks+si],0 ; ...to 0, never under
        or   ax,bx              ; it ran out now
        jmp  .n
.run:   inc  cx                 ; one more still running
.n:     shl  bx,1               ; the next clock's bit
        add  si,2               ; the next clock
        cmp  si,NCLK*2
        jb   .c
        pop  si
        pop  bx
        ret

; ----------------------------------------------------------------------
;@ TIMOFF     paused: keep the tick fresh, count nothing (no burst on resume)
;  in:  -
;  out: -
; ----------------------------------------------------------------------
TIMOFF: push ax
        push es
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:046Ch]      ; the tick now
        mov  [tmlast],ax        ; is the last one counted
        pop  es
        pop  ax
        ret

tmlast  dw 0                    ; the tick TIMERS last counted from (TIMOFF once at start)
clocks  rw NCLK                 ; the clocks, ticks to go (0 = stopped)
