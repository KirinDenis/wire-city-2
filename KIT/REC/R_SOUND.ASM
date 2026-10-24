; R_SOUND.ASM - a game's sound: heard from what changed, quieter far off,
;               and the player's switch (all / effects only / off)
; ============================================================================
;  Three fragments to copy into a game (or include after its way out, as
;  KIT\TEST\SREC.ASM does). They work with the Sound Blaster (K_SB) when
;  it answered and fall back to the PC speaker (K_SPK) when it did not.
;
;  1. SNDDIFF - SOUND FROM STATE DIFFERENCE. The game never calls a sound
;     where a thing happens. Once a frame, before drawing, SNDDIFF compares
;     the state with a copy of how it was last frame, and plays what
;     changed: the score went up - a coin; a life fewer - a hit. In a
;     network game this is the whole trick: every machine hears what ITS
;     copy of the world did, so not one byte of sound goes over the wire.
;     A new level: nothing is compared (everything changed), only copied.
;  2. SNDNEAR - LOUDNESS BY DISTANCE. An event at world (DX,BX): the
;     Manhattan distance from the camera, /64, takes loudness off; too far
;     and it is not played at all. The speaker has one loudness: it plays
;     only what is close.
;  3. SNDTOG - THE PLAYER'S SWITCH, a key: all sound -> effects only (the
;     bed and the drone gone) -> silence -> all. The card's ring keeps
;     turning underneath, so every step is instant.
;
;  define before (the game's own, with these names or renamed here):
;     score dw, lives db, level dw   - the state SNDDIFF watches
;     camx dw, camy dw               - where the listener is (SNDNEAR)
;  calls: K_SB.INC (SB_FXV, SB_BED, SB_VOL, SB_SPKR, [sb_ok]) and
;         K_SPK.INC (SPK_FX, SPK_DRONE, [spk_mute]) - include both.
;  the game: SB_INIT at start (CF=1 is fine), SB_HEAL and SPK_TICK in the
;     main loop, SNDDIFF once a frame, SNDTOG on its key, SB_DONE and
;     SPK_STOP on every way out.
;  from: GAMES\MULTSOK2\MULTSOK2.ASM:2435-2557 (SNDDIFF), GAMES\OWLFLY3\SRC\
;        SOUND.INC:297-343 (SFXBM2) and 409-461 (SNDTOG), proven there;
;        the SB/speaker dispatch SNDFX is new.
; ============================================================================

; ---- the game's sounds: one id each, its Blaster effect and speaker effect -
SN_COIN  = 0
SN_HIT   = 1
SN_LEVEL = 2
SN_BOOM  = 3
SN_OVER  = 4
sn_sbx   db SBX_COIN, SBX_HIT, SBX_WIN,   SBX_BOOM, SBX_LOSE
sn_spx   db SPX_COIN, SPX_HIT, SPX_POWER, SPX_BOOM, SPX_OVER
SN_N     = 5

sndmode  db 2                   ; 2 all, 1 effects only, 0 off (SNDTOG)
sndbed   db 1                   ; the bed the game wants in mode 2 (SB_BED)
sndcnt   dw 0                   ; sounds asked for (a test counts them)
s_score  dw 0                   ; SNDDIFF: how it was
s_lives  db 0
s_level  dw 0FFFFh              ; (no level yet: the first frame only copies)

; ----------------------------------------------------------------------
;  SNDFX - sound AL (SN_...) at loudness AH 0..16: the card if it answered,
;  else the speaker (which has one loudness: below 8 it stays quiet)
; ----------------------------------------------------------------------
SNDFX:  cmp  byte [sndmode],0
        je   .r                 ; the player said silence
        cmp  al,SN_N
        jae  .r
        inc  word [sndcnt]      ; one more asked for
        push ax
        push bx
        mov  bl,al
        xor  bh,bh
        cmp  byte [sb_ok],0
        je   .spk
        mov  al,[sn_sbx+bx]
        call SB_FXV             ; AH = the loudness
        jmp  .x
.spk:   cmp  ah,8
        jb   .x                 ; too faint for a voice with one loudness
        mov  al,[sn_spx+bx]
        call SPK_FX
.x:     pop  bx
        pop  ax
.r:     ret

; ----------------------------------------------------------------------
;  SNDDIFF - once a frame: what changed since the last, heard
; ----------------------------------------------------------------------
SNDDIFF:push ax
        push dx
        mov  ax,[level]
        cmp  ax,[s_level]
        jne  .snap              ; a new level: nothing to compare yet
        mov  ah,16              ; full loudness: it is the player's own
        mov  al,SN_COIN
        mov  dx,[score]
        cmp  dx,[s_score]
        jbe  .l
        call SNDFX              ; the score went up
.l:     mov  dl,[lives]
        cmp  dl,[s_lives]
        jae  .snap
        mov  al,SN_HIT
        cmp  dl,0
        jne  .h
        mov  al,SN_OVER         ; the last one
.h:     call SNDFX
.snap:  mov  ax,[level]         ; now is how it was, for the next time
        mov  [s_level],ax
        mov  ax,[score]
        mov  [s_score],ax
        mov  al,[lives]
        mov  [s_lives],al
        pop  dx
        pop  ax
        ret

; ----------------------------------------------------------------------
;  SNDNEAR - sound AL at world (DX,BX): loudness falls with distance from
;  (camx,camy); 64 world units a step; 5000 or so and it is not heard
; ----------------------------------------------------------------------
SNDNEAR:push ax
        push bx
        push cx
        push dx
        push si
        mov  ah,al              ; AH = the sound for now
        push ax
        mov  ax,dx
        sub  ax,[camx]          ; x apart
        jns  .a1
        neg  ax                 ; |x apart|
.a1:    mov  cl,6
        shr  ax,cl              ; / 64
        mov  si,ax
        mov  ax,bx
        sub  ax,[camy]          ; y apart
        jns  .a2
        neg  ax                 ; |y apart|
.a2:    shr  ax,cl              ; / 64
        add  si,ax              ; Manhattan distance / 64
        mov  ax,92
        sub  ax,si              ; 92 near .. 14 the edge of hearing
        pop  dx                 ; DH = the sound
        cmp  ax,14
        jl   .x                 ; too far off to hear
        mov  bl,6
        div  bl                 ; AL = 14..92 / 6 = 2..15 (AX <= 92, BL = 6)
        mov  ah,al              ; the loudness
        mov  al,dh
        call SNDFX
.x:     pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; ----------------------------------------------------------------------
;  SNDTOG - the key: all -> effects only -> off -> all
; ----------------------------------------------------------------------
SNDTOG: push ax
        mov  al,[sndmode]
        dec  al                 ; the next step down
        jns  .m
        mov  al,2               ; below off: all again
.m:     mov  [sndmode],al
        mov  byte [spk_mute],0
        cmp  al,1
        ja   .all
        je   .fx
        mov  byte [spk_mute],1  ; off: the speaker shut...
        call SPK_STOP
        xor  al,al
        call SB_SPKR            ; ...and the card's output at once
        jmp  .x
.fx:    xor  al,al              ; effects only: no bed, no drone
        call SB_BED
        xor  ax,ax
        call SPK_DRONE
        jmp  .x
.all:   mov  al,1
        call SB_SPKR            ; heard again
        mov  al,[sndbed]
        call SB_BED             ; the bed back (it heals in over ~3 s)
.x:     pop  ax
        ret
