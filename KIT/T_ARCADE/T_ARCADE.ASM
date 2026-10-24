; ============================================================================
;@ T_ARCADE   2D shooter skeleton: ship, bullet pool, animated enemies, score, lives, title/over cards, sound
;  T_ARCADE.ASM - KIT template: a whole small action game to grow from.
;  A ship at the bottom moves on the arrows, Space fires from a pool of
;  bullets, enemies (two-frame text-art sprites) drift down and bounce off
;  the sides. A hit scores 10; an enemy that touches the ship or reaches
;  the bottom takes a life; three lives, then the GAME OVER card.
;
;  THE STATES (one byte, [state]):  TITLE --Enter--> PLAY --lives 0--> OVER
;  --Enter after 1 s--> TITLE. Each tick runs only its state's rules.
;
;  THE SHAPE (KIT\REC\R_MAIN.ASM explains the order):
;    MEM_INIT, VGA_ON, SB_INIT (no card: fine), KEY_ON ... the loop ...
;    SPK_STOP, SB_DONE, KEY_OFF, VGA_OFF, exit - on every way out.
;    the loop: TIM_STEPS ticks -> STEP each (rules + SPK_TICK) -> DRAW ->
;              VGA_SHOW -> SB_HEAL
;  SOUND: SNDFX plays the card's effect when SB_INIT found one, else the
;  speaker's (KIT\REC\R_SOUND.ASM's dispatch). Sound is never required.
;
;  /AUTO (the kit's test run, seeded AUTOSEED: the same game every run - a
;  random one sometimes never hit): AUTOKEYS presses the keys - Enter on the
;  title, then steers under the lowest enemy and holds Space. After ~3 s it
;  takes the last lives (the GAME OVER path), quits and prints PASS lines.
;  GROW IT: more enemy kinds (a table of sprites and speeds), waves by
;  score, power-ups (a pickup that sets firecd lower), particles (R_PARTIC).
;  LETTERS: K_FONT's - the title card is R_TITLE's TTLCARD (the words are
;  t_name, t_sub, t_keys below), the score line its TTLHUD, GAME OVER the
;  fire look; keep them ringed: they read on stars, sprites, anything.
;  Uses: K_MEM K_VGA K_KEYS K_TIME K_MATH K_DRAW K_TEXT (DOS lines only)
;  K_SPR K_SPK K_SB K_FONT, and KIT\REC\R_TITLE.ASM.
;  Build: KIT\MAKEWIN T_ARCADE T_ARCADE   Run: RUNWIN.ps1 T_ARCADE T_ARCADE
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

NEN     = 6                     ; enemies at once
NBUL    = 8                     ; the bullet pool
SHIPW   = 16                    ; the ship's sprite: 16 x 8
SHIPH   = 8
SHIPY   = 186                   ; its row (fixed)
SHIPSP  = 3                     ; pixels a tick
ENW     = 12                    ; an enemy: 12 x 8
ENH     = 8
ENVY    = 48                    ; enemy fall, 8.8: 48/256 of a pixel a tick
BULW    = 2                     ; a bullet: 2 x 5
BULH    = 5
BULSP   = 6                     ; bullet speed, pixels a tick (up)
FIRET   = 4                     ; ticks between two shots
LIVES   = 3
CARDT   = 18                    ; the GAME OVER card ignores keys 1 s
AUTOT   = 54                    ; /AUTO: ticks of play before the end test
NSTAR   = 24                    ; the starfield
AUTOSEED = 1234                 ; /AUTO's random seed: the same game each run

ST_TITLE = 0
ST_PLAY  = 1
ST_OVER  = 2

; ---- the game's sounds: one id, its Blaster effect, its speaker effect ----
SN_SHOT  = 0
SN_BOOM  = 1
SN_LOSE  = 2
SN_OVER  = 3
SN_START = 4

start:  call GETAUTO            ; [auto] = 1 with /AUTO
        call MEM_INIT           ; our 64K kept, the rest for DOS to give
        call VGA_ON             ; mode 13h and the back buffer
        jc   nomem
        call SB_INIT            ; CF=1: no card - the speaker plays instead
        call KEY_ON             ; our keyboard: held keys and taps
        call MTH_SEED           ; every game different...
        cmp  byte [auto],0
        je   .seed
        mov  word [mth_seed],AUTOSEED ; ...but the test always plays the same
.seed:
        mov  si,ship_t          ; text art -> compiled sprites, once
        mov  di,ship_c
        call SPR_COMPILE
        mov  si,en_t0
        mov  di,en_c            ; two frames one after the other:
        call SPR_COMPILE        ;  SPR_NTH finds frame n
        mov  si,en_t1
        call SPR_COMPILE        ; DI went on past frame 0
        call STARS0             ; the starfield's places
        mov  word [ttl_name],t_name ; R_TITLE's title card says OUR words
        mov  word [ttl_sub],t_sub
        mov  word [ttl_keys],t_keys
        call TIM_STEPS          ; start the step count

frame:  mov  al,SC_ESC
        call KEY_TAP            ; Esc since the last frame?
        jnz  quit
        cmp  byte [auto],0
        je   .run
        cmp  word [aplay],AUTOT ; /AUTO: played long enough?
        jae  autoend
.run:   call TIM_STEPS          ; AX = ticks gone by, 0..4
        mov  cx,ax
        jcxz .draw              ; no tick yet: draw again
.step:  call STEP               ; the rules, once a tick (keeps CX)
        loop .step
.draw:  call DRAW
        call VGA_SHOW           ; the retrace, the buffer onto the screen
        call SB_HEAL            ; the card's ring renewed (no card: nothing)
        jmp  frame

; /AUTO's end: the last lives taken the game's own way, the card shown
autoend:
.lose:  cmp  byte [state],ST_PLAY
        jne  .shown             ; (only a game in play has lives to take)
        call LOSELIFE           ; one life, as a crash takes it
        jmp  .lose
.shown: call DRAW               ; the GAME OVER card, held half a second
        call VGA_SHOW
        mov  ax,9
        call TIM_WAIT

quit:   call SPK_STOP           ; the speaker silent
        call SB_DONE            ; the card silent, its DMA and IRQ as found
        call KEY_OFF            ; the BIOS gets its keyboard back
        call VGA_OFF            ; text mode 3, the buffer given back
        cmp  byte [auto],0
        je   .bye
        call REPORT             ; the PASS / FAIL lines
.bye:   mov  ax,4C00h
        int  21h

nomem:  mov  dx,t_nomem         ; no memory for the buffer: say so, leave
        mov  ah,9
        int  21h
        mov  ax,4C01h
        int  21h

; ---- STEP: one tick of the rules, by the state. Keeps every register -----
STEP:   push ax
        push bx
        push cx
        push dx
        push si
        push di
        inc  word [ticks]       ; the game's clock
        cmp  byte [auto],0
        je   .st
        call AUTOKEYS           ; /AUTO: the keys a player would press
.st:    call STARMOVE
        mov  al,[state]
        cmp  al,ST_PLAY
        je   .play
        cmp  al,ST_OVER
        je   .over
        mov  al,SC_ENTER        ; TITLE: Enter starts a game
        call KEY_TAP
        jz   .snd
        call NEWGAME
        jmp  .snd
.over:  cmp  word [cardclk],0
        je   .ok
        dec  word [cardclk]     ; the card's minimum hold, a tick less
        jmp  .snd
.ok:    mov  al,SC_ENTER
        call KEY_TAP
        jz   .snd
        mov  byte [state],ST_TITLE
        jmp  .snd
.play:  call PLAYTICK
.snd:   call SPK_TICK           ; the speaker's effect, one tick on
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; ---- NEWGAME: score 0, lives full, the pool empty, enemies in view -------
NEWGAME:mov  word [score],0
        mov  byte [lives],LIVES
        mov  word [shipx],160-SHIPW/2
        mov  byte [state],ST_PLAY
        inc  word [plays]       ; games started (a check)
        xor  bx,bx              ; BX = slot * 2 (word arrays)
.b:     mov  word [bul_on+bx],0 ; every bullet free
        add  bx,2               ; the next slot
        cmp  bx,NBUL*2
        jb   .b
        xor  bx,bx
.e:     call RESPAWN
        mov  ax,40
        call MTH_RANGE          ; AX = 0..39
        add  ax,16              ; the first wave starts in view: y 16..55
        mov  [en_y+bx],ax
        add  bx,2               ; the next enemy
        cmp  bx,NEN*2
        jb   .e
        mov  ax,[en_x]
        mov  [chkx],ax          ; where enemy 0 began (a check)
        mov  ax,[en_y]
        mov  [chky],ax
        mov  al,SN_START
        call SNDFX
        ret

; ---- RESPAWN: enemy BX/2 anew above the top, a random column and drift --
RESPAWN:push ax
        mov  ax,320-ENW
        call MTH_RANGE          ; AX = 0..307
        mov  [en_x+bx],ax
        mov  ax,30
        call MTH_RANGE          ; AX = 0..29
        neg  ax                 ; above the top...
        sub  ax,ENH             ; ...by its height and more
        mov  [en_y+bx],ax
        mov  byte [en_yf+bx],0  ; no fraction yet
        mov  ax,2
        call MTH_RANGE          ; 0 or 1
        inc  ax                 ; drift 1 or 2 pixels a tick
        mov  [en_dx+bx],ax
        mov  ax,2
        call MTH_RANGE
        or   ax,ax
        jz   .r
        neg  word [en_dx+bx]    ; half of them drift left
.r:     pop  ax
        ret

; ---- PLAYTICK: one tick of play -----------------------------------------
PLAYTICK:
        mov  al,SC_LF           ; the ship on the arrows
        call KEY_HELD
        jz   .p1
        sub  word [shipx],SHIPSP ; left: x -= speed
.p1:    mov  al,SC_RT
        call KEY_HELD
        jz   .p2
        add  word [shipx],SHIPSP ; right: x += speed
.p2:    mov  ax,[shipx]
        xor  bx,bx
        mov  cx,320-SHIPW
        call MTH_CLAMP          ; AX held to 0..304
        mov  [shipx],ax
        cmp  word [firecd],0    ; the gun: cooled down?
        je   .fire
        dec  word [firecd]      ; not yet: a tick less to wait
        jmp  .bul
.fire:  mov  al,SC_SPACE
        call KEY_HELD
        jz   .bul
        xor  bx,bx              ; find a free bullet
.free:  cmp  word [bul_on+bx],0
        je   .take
        add  bx,2               ; the next slot
        cmp  bx,NBUL*2
        jb   .free
        jmp  .bul               ; the pool is full: no shot
.take:  mov  word [bul_on+bx],1
        mov  ax,[shipx]
        add  ax,SHIPW/2-BULW/2  ; from the ship's nose
        mov  [bul_x+bx],ax
        mov  word [bul_y+bx],SHIPY-BULH
        mov  word [firecd],FIRET
        inc  word [shots]       ; a check
        mov  al,SN_SHOT
        call SNDFX
.bul:   xor  bx,bx              ; ---- bullets fly up
.b1:    cmp  word [bul_on+bx],0
        je   .b2
        sub  word [bul_y+bx],BULSP ; y -= speed
        cmp  word [bul_y+bx],-BULH ; off the top?
        jg   .b2
        mov  word [bul_on+bx],0 ; free again
.b2:    add  bx,2               ; the next slot
        cmp  bx,NBUL*2
        jb   .b1
        xor  bx,bx              ; ---- enemies drift, fall, bounce
.e1:    mov  ax,[en_x+bx]
        add  ax,[en_dx+bx]      ; x += drift
        cmp  ax,0
        jl   .flip
        cmp  ax,320-ENW
        jle  .e2
.flip:  neg  word [en_dx+bx]    ; a wall: the drift turns round
        mov  ax,[en_x+bx]       ; and this tick it stays put
.e2:    mov  [en_x+bx],ax
        add  byte [en_yf+bx],ENVY ; 8.8 fall: the fraction grows...
        adc  word [en_y+bx],0   ; ...its carry is a whole pixel down
        cmp  word [en_y+bx],SHIPY
        jl   .e3
        call RESPAWN            ; reached the bottom: it got through
        call LOSELIFE
.e3:    add  bx,2               ; the next enemy
        cmp  bx,NEN*2
        jb   .e1
        call HITS               ; bullets against enemies, enemies vs ship
        ret

; ---- HITS: SPR_HIT on every bullet x enemy pair, then enemy x ship -------
HITS:   xor  si,si              ; SI = enemy * 2
.en:    mov  ax,[en_x+si]
        mov  [boxb],ax          ; box B = this enemy
        mov  ax,[en_y+si]
        mov  [boxb+2],ax
        xor  bx,bx              ; BX = bullet * 2
.bu:    cmp  word [bul_on+bx],0
        je   .nb
        mov  ax,[bul_x+bx]
        mov  [boxa],ax          ; box A = this bullet
        mov  ax,[bul_y+bx]
        mov  [boxa+2],ax
        mov  word [boxa+4],BULW
        mov  word [boxa+6],BULH
        call HITAB              ; CF = 1 they overlap
        jnc  .nb
        mov  word [bul_on+bx],0 ; the bullet is spent
        xchg bx,si
        call RESPAWN            ; the enemy is gone - a new one above
        xchg bx,si
        add  word [score],10    ; 10 points a hit
        inc  word [hits]        ; a check
        mov  al,SN_BOOM
        call SNDFX
        jmp  .ne                ; this enemy is done with
.nb:    add  bx,2               ; the next bullet
        cmp  bx,NBUL*2
        jb   .bu
        mov  ax,[shipx]         ; box A = the ship
        mov  [boxa],ax
        mov  word [boxa+2],SHIPY
        mov  word [boxa+4],SHIPW
        mov  word [boxa+6],SHIPH
        call HITAB
        jnc  .ne
        xchg bx,si
        call RESPAWN            ; it rammed the ship: gone, and a life too
        xchg bx,si
        call LOSELIFE
.ne:    add  si,2               ; the next enemy
        cmp  si,NEN*2
        jb   .en
        ret
; HITAB: CF = 1 if boxa and boxb overlap (SPR_HIT on our two boxes)
HITAB:  push si
        push di
        mov  si,boxa
        mov  di,boxb
        call SPR_HIT
        pop  di
        pop  si
        ret

; ---- LOSELIFE: one life less; none left -> the GAME OVER card ------------
LOSELIFE:
        push ax
        cmp  byte [state],ST_PLAY
        jne  .r                 ; only a game in play can lose one
        dec  byte [lives]       ; one fewer
        mov  al,SN_LOSE
        jnz  .snd
        mov  byte [state],ST_OVER ; the last one: the card
        mov  word [cardclk],CARDT
        mov  ax,[score]
        cmp  ax,[hiscore]
        jbe  .o
        mov  [hiscore],ax       ; a new best, kept while the program runs
.o:     mov  al,SN_OVER
.snd:   call SNDFX
.r:     pop  ax
        ret

; ---- SNDFX: sound AL (SN_...) on the card if it answered, else speaker --
SNDFX:  push ax
        push bx
        mov  bl,al
        xor  bh,bh              ; BX = the sound's row
        inc  word [sndcnt]      ; a check
        cmp  byte [sb_ok],0
        je   .spk
        mov  al,[sn_sbx+bx]
        call SB_FX              ; mixed into the card's ring
        jmp  .r
.spk:   mov  al,[sn_spx+bx]
        call SPK_FX             ; the speaker, by priority
.r:     pop  bx
        pop  ax
        ret
sn_sbx  db SBX_SHOOT, SBX_BOOM,  SBX_HIT, SBX_LOSE, SBX_COIN
sn_spx  db SPX_SHOOT, SPX_BOOM,  SPX_HIT, SPX_OVER, SPX_POWER

; ---- AUTOKEYS (/AUTO only): press what a player would, into the tables --
AUTOKEYS:
        mov  byte [key_held+SC_LF],0
        mov  byte [key_held+SC_RT],0
        mov  byte [key_held+SC_SPACE],0
        cmp  byte [state],ST_PLAY
        je   .play
        cmp  word [ticks],5     ; the title shown 5 ticks: Enter
        jb   .r
        mov  byte [key_hit+SC_ENTER],1
        ret
.play:  inc  word [aplay]       ; ticks played (the run's length)
        mov  byte [key_held+SC_SPACE],1 ; fire all the time
        xor  bx,bx
        mov  dx,-100            ; DX = the lowest enemy's y so far
        mov  cx,160             ; CX = its centre x
.f:     mov  ax,[en_y+bx]
        cmp  ax,dx
        jle  .n
        mov  dx,ax              ; lower than any so far
        mov  cx,[en_x+bx]
        add  cx,ENW/2           ; its centre
.n:     add  bx,2               ; the next enemy
        cmp  bx,NEN*2
        jb   .f
        mov  ax,[shipx]
        add  ax,SHIPW/2         ; AX = the ship's centre
        sub  cx,ax              ; CX = how far the target is across
        cmp  cx,-2
        jge  .rt
        mov  byte [key_held+SC_LF],1 ; it is to the left
.rt:    cmp  cx,2
        jle  .r
        mov  byte [key_held+SC_RT],1 ; it is to the right
.r:     ret

; ---- the starfield: NSTAR dots falling at 1 or 2 pixels a tick ----------
STARS0: xor  bx,bx
.s:     mov  ax,320
        call MTH_RANGE
        mov  [st_x+bx],ax       ; x 0..319
        mov  ax,200
        call MTH_RANGE
        mov  [st_y+bx],ax       ; y 0..199
        add  bx,2               ; the next star
        cmp  bx,NSTAR*2
        jb   .s
        ret
STARMOVE:
        xor  bx,bx
.s:     mov  ax,bx
        and  ax,2               ; every other star...
        shr  ax,1               ; ...0 or 1
        inc  ax                 ; speed 1 or 2: near ones faster
        add  ax,[st_y+bx]       ; y += speed
        cmp  ax,200
        jb   .k
        sub  ax,200             ; off the bottom: round to the top
.k:     mov  [st_y+bx],ax
        add  bx,2               ; the next star
        cmp  bx,NSTAR*2
        jb   .s
        ret

; ---- DRAW: the picture into the back buffer ------------------------------
DRAW:   push es
        mov  es,[vga_buf]       ; ES = the buffer, 320 bytes a row
        xor  al,al
        call VGA_CLS            ; black space
        xor  bx,bx
.st:    mov  ax,[st_x+bx]       ; the stars
        mov  di,bx
        and  di,2               ; near (2) or far (0)?
        mov  cl,8
        add  cl,[st_c+di]       ; grey 8 far, white 15 near
        mov  [drw_col],cl
        push bx
        mov  bx,[st_y+bx]
        call DRW_PIXEL
        pop  bx
        add  bx,2               ; the next star
        cmp  bx,NSTAR*2
        jb   .st
        cmp  byte [state],ST_TITLE
        je   .title
        call DRAWWORLD
        cmp  byte [state],ST_OVER
        jne  .x
        mov  al,FNT_LFIRE       ; GAME OVER over the frozen world: 8x16 x2,
        call FNT_LOOK           ;  the fire ramp, ringed and shadowed
        mov  si,t_over
        mov  bx,160             ; centred on x 160
        mov  dx,66              ; its top
        call FNT_CENTER
        mov  al,FNT_LSUB        ; BEST, 8x8 x2 smooth, ringed
        call FNT_LOOK
        mov  si,t_best
        mov  bx,104
        mov  dx,112
        call FNT_PUT            ; BX = past the word
        mov  al,FNT_LSCORE      ; the best in bold ringed digits, x2
        call FNT_LOOK
        mov  byte [fnt_scale],2
        mov  byte [fnt_smooth],1
        mov  ax,[hiscore]
        mov  cl,5               ; five digits: 00120
        add  bx,8               ; a gap after BEST
        mov  dx,113
        call FNT_NUMZ           ; the best this session
        jmp  .x
.title: call TIM_TICK           ; AX = the tick: PRESS ENTER blinks by it
        call TTLCARD            ; R_TITLE: the name big in gold, the
                                ;  subtitle, the keys, PRESS ENTER - over
                                ;  the moving stars already in ES
.x:     pop  es
        ret

; DRAWWORLD: enemies, bullets, ship, the score line
DRAWWORLD:
        xor  bx,bx
.en:    mov  ax,[ticks]         ; the clock...
        add  ax,bx              ; ...each enemy a little out of step
        push bx
        mov  bx,0204h           ; 4 ticks a frame, 2 frames
        call SPR_ANIM           ; AX = frame 0 or 1
        pop  bx
        mov  si,en_c
        call SPR_NTH            ; SI = that frame
        push bx
        mov  dx,[en_y+bx]
        mov  bx,[en_x+bx]
        call SPR_DRAW           ; clipped: half above the top is fine
        pop  bx
        add  bx,2               ; the next enemy
        cmp  bx,NEN*2
        jb   .en
        mov  byte [drw_col],14  ; bullets: yellow bars
        xor  si,si
.bu:    cmp  word [bul_on+si],0
        je   .nb
        mov  ax,[bul_x+si]
        mov  bx,[bul_y+si]
        mov  cx,BULW
        mov  dx,BULH
        call DRW_RECT
.nb:    add  si,2               ; the next bullet
        cmp  si,NBUL*2
        jb   .bu
        mov  si,ship_c
        mov  bx,[shipx]
        mov  dx,SHIPY
        call SPR_DRAW
        mov  ax,[score]         ; the score line: R_TITLE's TTLHUD - SCORE,
        mov  cx,[hiscore]       ;  HI, LIVES in 4x6 ringed labels and bold
        mov  dl,[lives]         ;  ringed digits: they read over any picture
        call TTLHUD
        ret

; ---- REPORT (/AUTO): the checks, on DOS's output -------------------------
REPORT: mov  si,c_play          ; Enter on the title started a game
        cmp  word [plays],0
        call PF
        mov  si,c_shot          ; Space fired from the pool
        cmp  word [shots],0
        call PF
        mov  ax,[en_x]          ; enemy 0 moved off where it began
        cmp  ax,[chkx]
        jne  .mv
        mov  ax,[en_y]
        cmp  ax,[chky]
.mv:    mov  si,c_move
        call PF
        mov  si,c_hit           ; SPR_HIT found a bullet on an enemy
        cmp  word [hits],0
        call PF
        mov  si,c_score         ; ...and the score went up
        cmp  word [score],0
        call PF
        mov  si,c_over          ; LOSELIFE ran the lives out: GAME OVER
        call PFZ
        mov  si,c_snd           ; sounds were asked for
        cmp  word [sndcnt],0
        call PF
        mov  dx,t_card          ; which voice played them
        cmp  byte [sb_ok],0
        jne  .v
        mov  dx,t_spkr
.v:     call TXT_DOS
        mov  si,t_scorep
        call TXT_DOSZ
        mov  ax,[score]
        call TXT_DOSNUM
        call TXT_DOSCR
        ret
; PF: PASS if the last compare said "not equal" (a count above 0), else FAIL
PF:     mov  dx,t_pass
        jne  .s
        mov  dx,t_fail
.s:     call TXT_DOS
        call TXT_DOSZ           ; the check's words
        call TXT_DOSCR
        ret
; PFZ: PASS if [state] is OVER with no lives and the best is the score
PFZ:    mov  dx,t_fail
        cmp  byte [state],ST_OVER
        jne  .s
        cmp  byte [lives],0
        jne  .s
        mov  ax,[score]
        cmp  ax,[hiscore]
        jne  .s
        mov  dx,t_pass
.s:     call TXT_DOS
        call TXT_DOSZ
        call TXT_DOSCR
        ret

; ---- GETAUTO: [auto] = 1 if the command line holds /AUTO -----------------
GETAUTO:mov  si,81h
        xor  ch,ch
        mov  cl,[80h]           ; the command line's length
.s:     jcxz .no
        lodsb
        dec  cx                 ; one character read
        cmp  al,'/'
        jne  .s
        cmp  cx,4
        jb   .no
        mov  ax,[si]
        and  ax,0DFDFh          ; upper case
        cmp  ax,'AU'
        jne  .s
        mov  ax,[si+2]
        and  ax,0DFDFh
        cmp  ax,'TO'
        jne  .s
        mov  byte [auto],1
.no:    ret

; ---- the pictures (text art: '.' see-through, 0..F the 16 BIOS colours) --
ship_t  db SHIPW,SHIPH
        db '.......FF.......'
        db '......F99F......'
        db '......F99F......'
        db '.....F9BB9F.....'
        db '..7..F9BB9F..7..'
        db '.77.F999999F.77.'
        db '7777F999999F7777'
        db '.C..CC....CC..C.'
en_t0   db ENW,ENH
        db '...5....5...'
        db '....5..5....'
        db '...DDDDDD...'
        db '..DD.DD.DD..'
        db '.DDDDDDDDDD.'
        db '.D.DDDDDD.D.'
        db '.D.D....D.D.'
        db '...D....D...'
en_t1   db ENW,ENH
        db '...5....5...'
        db '....5..5....'
        db '...DDDDDD...'
        db '..DD.DD.DD..'
        db '.DDDDDDDDDD.'
        db 'D..DDDDDD..D'
        db 'D..D....D..D'
        db '....D..D....'

; ---- the game's state -----------------------------------------------------
state   db ST_TITLE
lives   db 0
score   dw 0
hiscore dw 0
shipx   dw 0
firecd  dw 0
ticks   dw 0
cardclk dw 0
bul_on  dw NBUL dup(0)          ; the pool: 1 = flying
bul_x   dw NBUL dup(0)
bul_y   dw NBUL dup(0)
en_x    dw NEN dup(0)           ; enemies: x, y (whole pixels, signed)
en_y    dw NEN dup(0)
en_yf   dw NEN dup(0)           ;  the fall's fraction (low byte), 256ths
en_dx   dw NEN dup(0)           ;  drift, pixels a tick
st_x    dw NSTAR dup(0)
st_y    dw NSTAR dup(0)
st_c    db 0,0,7,0              ; star shade added to 8: far 8, near 15
boxa    dw 0,0,0,0              ; SPR_HIT's two boxes: x, y, w, h
boxb    dw 0,0,ENW,ENH
; /AUTO and its checks
auto    db 0
aplay   dw 0
plays   dw 0
shots   dw 0
hits    dw 0
sndcnt  dw 0
chkx    dw 0
chky    dw 0
; the words
t_name  db 'Arcade',0           ; the title card's words (R_TITLE TTLCARD):
t_sub   db 'a shooter to grow',0 ;  the name ~9 letters, the subtitle ~18,
t_keys  db 'Arrows',0,'move',0  ;  then the keys: the key, what it does...
        db 'Space',0,'fire',0
        db 'Enter',0,'play',0
        db 'Esc',0,'quit',0
        db 0                    ;  ...an empty key ends them
t_over  db 'GAME OVER',0
t_best  db 'BEST',0
t_pass  db 'PASS T_ARCADE $'
t_fail  db 'FAIL T_ARCADE $'
c_play  db 'Enter on the title card started a game',0
c_shot  db 'Space fired bullets from the pool',0
c_move  db 'the enemies moved (drift + 8.8 fall)',0
c_hit   db 'SPR_HIT found bullets on enemies',0
c_score db 'the score went up by the hits',0
c_over  db 'the lives ran out: GAME OVER card, best score kept',0
c_snd   db 'sound effects were asked for',0
t_card  db '  sound went to the Sound Blaster',13,10,'$'
t_spkr  db '  sound went to the PC speaker',13,10,'$'
t_scorep db '  final score ',0
t_nomem db 'Not enough memory for the screen buffer.',13,10,'$'
ship_c  db 2+SHIPW*SHIPH dup(0) ; the compiled sprites
en_c    db 2*(2+ENW*ENH) dup(0)

        include '..\..\KIT\LIB\K_MEM.INC'
        include '..\..\KIT\LIB\K_VGA.INC'
        include '..\..\KIT\LIB\K_KEYS.INC'
        include '..\..\KIT\LIB\K_TIME.INC'
        include '..\..\KIT\LIB\K_MATH.INC'
        include '..\..\KIT\LIB\K_DRAW.INC'
        include '..\..\KIT\LIB\K_TEXT.INC'
        include '..\..\KIT\LIB\K_SPR.INC'
        include '..\..\KIT\LIB\K_SPK.INC'
        include '..\..\KIT\LIB\K_SB.INC'
        include '..\..\KIT\LIB\K_FONT.INC' ; the good letters (FNT_*)
        include '..\..\KIT\REC\R_TITLE.ASM' ; the title card and the HUD
