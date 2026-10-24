; ============================================================================
;  R_TITLE.ASM - KIT recipe: a title screen and a score line done properly.
;
;  The game's name big, outlined, a gold ramp down its letters; a blinking
;  PRESS ENTER; the score in bold ringed digits that read over any picture.
;
;  A RECIPE, NOT A PROGRAM: copy it into your program after its way out,
;  with the LIB files it names, and change the words in its data at the
;  end (TTLNAME, TTLSUB, TTLKEYS) - or include it whole and point its
;  words at your own:  mov word [ttl_name],t_name  (ttl_sub, ttl_keys,
;  ttl_press the same); a game whose DAC is its own sets ttl_ramp/ttl_rampn
;  (the name's ramp), ttl_keyc, ttl_hotc (the inks). Each routine sits in "if used": a program pays
;  only for what it calls. KIT\TEST\FTITLE.ASM includes it whole and
;  proves it; every KIT\T_* template uses it.
;  EGA, CGA, Hercules: TTLCARD and TTLHUD draw wherever K_FONT draws -
;  after FNT_OND4 that is K_D4's 4bpp buffer (KIT\T_GRID does it); the
;  colours they use (15, 14, 12, 0, the gold ramp) are in the 16 there.
;
;    TTLCARD   the title card over whatever picture is in ES: the name
;              (8x8 x4 smooth, gold ramp, 2 px ring + shadow), the
;              subtitle (8x8 x2 smooth, ringed), the keys (8x8, ringed),
;              PRESS ENTER (8x16, ringed, blinking by the tick)
;    TTLBLINK  CF = 1 in the lit part of the blink (11 ticks of 16)
;    TTLRUN    the title's loop: your background, the card, the screen,
;              until Enter or Esc (or a time out)
;    TTLHUD    the score line over the play picture: SCORE, HI, LIVES -
;              4x6 ringed labels, bold ringed digits, a dark-ringed HUD
;              reads on sky, snow, sun and its own colour alike
;
;  The layout at 320x200, the one every good title here uses:
;      y  20  the name, 32 px high            (FNT_LTITLE)
;      y  62  the subtitle, 16 px             (FNT_LSUB)
;      y  96  the keys, one 8x8 line each, 11 px apart: the key in
;             yellow ending at x 150, what it does in white from x 166
;      y 172  PRESS ENTER, 16 px, blinking    (8x16, yellow, ringed)
;
;  needs: K_FONT.INC (FNT_LOOK, FNT_CENTER, FNT_PUT, FNT_RIGHT, FNT_NUMZ,
;         FNT_HUD and the fnt_ look); for TTLRUN also K_VGA.INC (VGA_SHOW,
;         [vga_buf]) and K_TIME.INC (TIM_TICK). TTLRUN reads the keys by
;         the BIOS (INT 16h): call it while INT 9 is the BIOS's - before
;         K_KEYS' KEY_ON, or after KEY_OFF - or it never sees Enter.
; ============================================================================

; ----------------------------------------------------------------------
;@ TTLCARD    the title card (name, subtitle, keys, blinking PRESS ENTER) over the picture in ES
;  in:  AX = the BIOS tick (for the blink), ES = the picture to draw on
;       (the back buffer); TTLNAME, TTLSUB, TTLKEYS, TTLPRESS (data below)
;  out: - (the fnt_ look is left as FNT_LBODY's)
;  needs: K_FONT FNT_LOOK FNT_CENTER
;  from: new - the house's title look: GAMES\MULTSOK2\SCENE.INC:2963 TITLE
;        (name big at the top, the keys under it) in K_FONT's letters
; ----------------------------------------------------------------------
if used TTLCARD
TTLCARD:
        push ax
        push bx
        push cx
        push dx
        push si
        push ax                 ; keep the tick for the blink
        mov  al,FNT_LTITLE      ; ---- the name
        call FNT_LOOK
        cmp  word [ttl_ramp],0  ; a ramp of your own?
        je   .gold
        mov  ax,[ttl_ramp]
        mov  [fnt_gtab],ax
        mov  al,[ttl_rampn]
        mov  [fnt_gn],al
.gold:  mov  si,[ttl_name]
        mov  bx,160             ; centred
        mov  dx,20
        call FNT_CENTER
        mov  al,FNT_LSUB        ; ---- the subtitle
        call FNT_LOOK
        mov  byte [fnt_col],TTLSUBC
        mov  si,[ttl_sub]
        mov  bx,160
        mov  dx,62
        call FNT_CENTER
        mov  al,FNT_LBODY       ; ---- the keys, ringed
        call FNT_LOOK
        mov  byte [fnt_style],FNT_RING
        mov  si,[ttl_keys]
        mov  dx,96              ; the first line's top
.k:     cmp  byte [si],0        ; the list's end (an empty key)?
        je   .press
        mov  al,[ttl_keyc]
        mov  [fnt_col],al
        mov  bx,TTLKEYX
        call FNT_RIGHT          ; the key, ending at the column
        call .skip              ; SI past it
        mov  byte [fnt_col],15
        mov  bx,TTLKEYX+16
        call FNT_PUT            ; what it does, after a gap
        call .skip
        add  dx,11              ; the next line down
        jmp  .k
.skip:  cmp  byte [si],0        ; SI on past this string's zero
        je   .sk
        inc  si
        jmp  .skip
.sk:    inc  si
        ret
.press: pop  ax                 ; ---- PRESS ENTER, when the blink is lit
        call TTLBLINK
        jnc  .x
        mov  al,FNT_LMENU
        call FNT_LOOK
        mov  byte [fnt_style],FNT_RINGSH
        mov  al,[ttl_hotc]
        mov  [fnt_col],al
        mov  byte [fnt_shd],2
        mov  si,[ttl_press]
        mov  bx,160
        mov  dx,172
        call FNT_CENTER
.x:     mov  al,FNT_LBODY       ; leave a plain look behind
        call FNT_LOOK
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
ttl_name  dw TTLNAME            ; the words TTLCARD draws: point them at your
ttl_sub   dw TTLSUB             ;  own (mov word [ttl_name],t_name), or
ttl_keys  dw TTLKEYS            ;  change the strings at the end
ttl_press dw TTLPRESS
ttl_ramp  dw 0                  ; 0: the name in FNT_LTITLE's gold; or your
ttl_rampn db 0                  ;  own ramp and its length (a game that
ttl_keyc  db TTLKEYC            ;  changes DAC 0..15 or cycles colours picks
ttl_hotc  db 14                 ;  inks it keeps): the keys', PRESS ENTER's
end if

; ----------------------------------------------------------------------
;@ TTLBLINK   CF = 1 in the lit part of the blink: 11 ticks lit of every 16 (0.9 s)
;  in:  AX = the BIOS tick
;  out: CF = 1 lit, CF = 0 dark
;  needs: -
;  from: new (KIT\REC\R_HUD.ASM HUDBLINK's idea; a power of two here)
; ----------------------------------------------------------------------
if used TTLBLINK
TTLBLINK:
        push ax
        and  ax,15              ; AX = the tick within its 16
        cmp  ax,11              ; CF = 1 below 11: lit
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ TTLRUN     the title's loop: [ttlbg] draws the picture, TTLCARD over it, shown; until Enter/Esc
;  in:  [ttlbg] = the address of YOUR routine that draws the background
;       into the back buffer (ES = [vga_buf] when it is called; it may
;       move things: it is called every frame); CX = give up after so many
;       ticks (0: never)
;  out: AL = 13 Enter (or Space), 27 Esc, 0 the time ran out
;  needs: K_VGA VGA_ON first, VGA_SHOW; K_TIME TIM_TICK; INT 9 the BIOS's
;  from: new (the title loop of every game here: GAMES\MULTSOK2\SCENE.INC
;        TITLE + its key wait)
; ----------------------------------------------------------------------
if used TTLRUN
TTLRUN:
        push bx
        push cx
        push dx
        push es
        call TIM_TICK
        mov  dx,ax              ; DX = the tick it started
.f:     mov  ax,[vga_buf]
        mov  es,ax              ; ES = the back buffer
        call word [ttlbg]       ; the picture
        call TIM_TICK
        call TTLCARD            ; the card over it
        call VGA_SHOW
        mov  ah,1
        int  16h                ; a key waiting?
        jz   .t                 ;   no
        xor  ah,ah
        int  16h                ; AL = it
        cmp  al,13
        je   .x                 ; Enter
        cmp  al,' '
        je   .sp
        cmp  al,27
        je   .x                 ; Esc
.t:     jcxz .f                 ; no time limit
        call TIM_TICK
        sub  ax,dx              ; AX = ticks gone
        cmp  ax,cx
        jb   .f
        xor  al,al              ; the time ran out
        jmp  .x
.sp:    mov  al,13              ; Space counts as Enter
.x:     pop  es
        pop  dx
        pop  cx
        pop  bx
        ret
ttlbg   dw TTLNOBG              ; set it: mov word [ttlbg],MYBACKGROUND
TTLNOBG:push ax                 ; the default: a black screen
        push cx
        push di
        xor  di,di
        xor  ax,ax
        mov  cx,32000
        cld
        rep  stosw
        pop  di
        pop  cx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ TTLHUD     the score line over the play picture: SCORE 00120  HI 05000  LIVES 3, ringed
;  in:  AX = the score, CX = the best score, DL = lives (0..9), ES = the
;       picture (the back buffer, after the play is drawn)
;  out: - (the fnt_ look is left as FNT_LSCORE's)
;  needs: K_FONT FNT_HUD FNT_LOOK FNT_NUMZ FNT_RIGHT
;  from: new - LESSONS\L30\HANGAR.ASM:495-544 NUMBERS/DIGITS (numbers
;        ringed so they read on the picture) with K_FONT's bold digits
; ----------------------------------------------------------------------
if used TTLHUD
TTLHUD:
        push ax
        push bx
        push cx
        push dx
        push si
        push dx                 ; keep lives
        push cx                 ; keep the best
        push ax                 ; keep the score
        mov  byte [fnt_col],15  ; ---- the labels: 4x6, white, ringed black
        mov  byte [fnt_rc],0
        mov  si,TTLSCORE
        mov  bx,4
        mov  dx,5
        call FNT_HUD
        mov  si,TTLHI
        mov  bx,124
        call FNT_HUD
        mov  si,TTLLIVES
        mov  bx,268
        call FNT_HUD
        mov  al,FNT_LSCORE      ; ---- the numbers: bold digits, ringed
        call FNT_LOOK
        pop  ax                 ; the score, yellow
        mov  cl,5
        mov  bx,28
        mov  dx,3               ; 7 high: its foot on the labels' foot
        call FNT_NUMZ
        pop  ax                 ; the best, white
        mov  byte [fnt_col],15
        mov  bx,136
        call FNT_NUMZ
        pop  ax                 ; lives: AL = DL
        mov  ah,0
        cmp  al,9
        jbe  .l
        mov  al,9               ; one digit
.l:     mov  byte [fnt_col],15  ; white...
        cmp  al,1
        ja   .lc
        mov  byte [fnt_col],12  ; ...red on the last life
.lc:    mov  cl,1
        mov  bx,294
        call FNT_NUMZ
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ---- the words: change them -------------------------------------------------
TTLSUBC  = 15                   ; the subtitle's ink
TTLKEYC  = 14                   ; the keys' ink (what they do is white)
TTLKEYX  = 150                  ; the keys end here; what they do starts 16 on
TTLNAME  db 'Owl Run',0         ; the name: 8x8 x4 proportional, ~9 letters fit
TTLSUB   db 'over the island',0 ; the subtitle: 8x8 x2, ~18 letters fit
TTLKEYS  db 'Arrows',0,'fly',0  ; the keys: the key, what it does...
         db 'Space',0,'fire',0
         db 'P',0,'pause',0
         db 'Esc',0,'quit',0
         db 0                   ; ...and an empty key ends them
TTLPRESS db 'PRESS ENTER',0
TTLSCORE db 'SCORE',0
TTLHI    db 'HI',0
TTLLIVES db 'LIVES',0
