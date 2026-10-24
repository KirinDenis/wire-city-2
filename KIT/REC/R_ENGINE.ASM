; ============================================================================
;  R_ENGINE.ASM - recipe: the speaker sounds a vehicle game wants - an engine
;  that RUMBLES while it pushes, a rising chime when it lands, a falling
;  noisy crash. One voice, set once per BIOS tick.
;
;  The pilot judged these the best-sounding of the kit's first experiment
;  (its game A, MY\LANDA\LANDA.ASM "sound"): the rumble is a low tone whose
;  divisor jumps by a random amount every tick, which the ear hears as
;  engine noise, not as a note.
;
;  Copy it, then once per BIOS tick (after your physics step):
;        mov  al,[thrusting]     ; 1 while the engine pushes, else 0
;        call ENG_TICK
;  and when it happens:  call ENG_CHIME  (landed)   /  call ENG_CRASH
;  On every way out: call SPK_STOP (K_SPK) - it shuts the gate.
;  A chime or a crash plays to its end and wins over the engine.
;  If the game also uses SPK_FX / SPK_TICK, call ENG_TICK AFTER SPK_TICK and
;  only while eng_t <> 0 or the engine runs - else one shuts what the other set.
;  Needs: K_SPK (SPK_TONE, SPK_OFF), K_MATH (MTH_RND).
;  Tested: KIT\TEST\SENG.ASM.
; ============================================================================

ENG_RUMBLE = 9000               ; the engine's base divisor (~130 Hz)
ENG_SPREAD = 4                  ; shift of the random jump: 16 x 0..255

; ----------------------------------------------------------------------
;@ ENG_TICK   once a tick: the chime or crash if one plays, else the engine rumble or silence
;  in:  AL = 1 the engine pushes now, 0 it does not
;  out: -
;  needs: K_SPK, K_MATH
;  from: MY\LANDA\LANDA.ASM sound (the kit experiment's game A)
; ----------------------------------------------------------------------
ENG_TICK:
        push ax
        push bx
        push cx
        cmp  word [eng_t],0
        je   .engine
        dec  word [eng_t]       ; one tick of the chime or crash gone
        cmp  byte [eng_kind],1
        je   .chime
        ; the crash: a pitch falling as it goes, with noise on it
        mov  ax,ENG_CRLEN
        sub  ax,[eng_t]         ; ticks since the crash
        mov  cl,7
        shl  ax,cl              ; x128: the divisor grows, the pitch falls
        add  ax,1500            ; from about 800 Hz
        mov  bx,ax
        call MTH_RND
        mov  al,ah              ; the high bits: the low ones repeat
        xor  ah,ah
        and  al,3Fh             ; 0..63
        shl  ax,1               ; x2: the noise
        add  ax,bx              ; tone plus noise
        call SPK_TONE
        jmp  .x
.chime: mov  bx,[eng_t]         ; C E G C' by quarters of the chime
        mov  ax,2281            ; C
        cmp  bx,30
        ja   .say
        mov  ax,1810            ; E
        cmp  bx,20
        ja   .say
        mov  ax,1522            ; G
        cmp  bx,10
        ja   .say
        mov  ax,1140            ; the high C
.say:   call SPK_TONE
        jmp  .x
.engine:
        or   al,al
        jz   .quiet
        call MTH_RND
        mov  al,ah              ; the high bits
        xor  ah,ah
        mov  cl,ENG_SPREAD
        shl  ax,cl              ; x16: a jump of 0..4080
        add  ax,ENG_RUMBLE      ; around the base: a rumble, not a note
        call SPK_TONE
        jmp  .x
.quiet: call SPK_OFF
.x:     pop  cx
        pop  bx
        pop  ax
        ret

ENG_CHLEN = 40                  ; the chime's ticks (about 2 s)
ENG_CRLEN = 40                  ; the crash's ticks

;@ ENG_CHIME  start the landing chime (C E G C', ~2 s)
;  in: -  out: -
ENG_CHIME:
        mov  byte [eng_kind],1
        mov  word [eng_t],ENG_CHLEN
        ret

;@ ENG_CRASH  start the crash: a falling pitch with noise (~2 s)
;  in: -  out: -
ENG_CRASH:
        mov  byte [eng_kind],2
        mov  word [eng_t],ENG_CRLEN
        ret

eng_t    dw 0                   ; ticks left of the chime or crash, 0 none
eng_kind db 0                   ; 1 chime, 2 crash
