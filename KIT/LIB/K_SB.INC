; K_SB.INC - the Sound Blaster: one ring of samples that IS the mixer
; ============================================================================
;  A 32K ring of 8-bit samples (unsigned, 80h = silence) loops for ever
;  through auto-init DMA, 11025 a second (about 3 s round), no interrupts.
;  Behind the playing position SB_HEAL writes the ring afresh - the
;  ambient bed (a breeze with waves, birds now and then) or silence - and
;  so wipes out what was played. An effect is ADDED into the ring a little
;  (60 ms) ahead of the position, in one go: effects sum like a real
;  mixer, nothing is serviced afterwards.
;
;  Program pattern:
;        call SB_INIT           ; CF=1: no card - fine, every call below
;                               ;  then does nothing, the game runs on
;        mov  al,1
;        call SB_BED            ; the breeze and waves (0 = silence)
;  MAIN: call SB_HEAL           ; every frame (at least 4 times a second)
;        ...  mov al,SBX_PUSH / call SB_FX   when something happens
;  QUIT: call SB_DONE           ; on EVERY way out: silence, DMA masked,
;                               ;  the IRQ as it was, the ring's memory freed
;
;  MEMORY: SB_INIT takes 64K from DOS (INT 21h 48h) for the ring, unless
;  [sb_seg] was set before (a segment on a 64K boundary, or at most 800h
;  paragraphs past one - a DMA transfer must not cross a 64K page). A .COM
;  owns all memory when it starts: shrink it first,
;        mov  bx,1000h          ; 64K for the .COM itself
;        mov  ah,4Ah            ; ES = CS (it is, at start)
;        int  21h
;  or SB_INIT finds no memory and stays silent (CF=1).
;
;  THE CARD: the BLASTER variable (A220 I7 D1 ...) gives the port, IRQ and
;  8-bit DMA channel if it is set ([sb_env]=0 ignores it); else 220h, 7, 1.
;  [sb_want]=0 (the player chose no sound) touches not one port.
;
;  AN EFFECT IS DATA - a list of tones, each 10 bytes, ended by db 0FFh:
;        db wave, rewind            wave: 0 a rest, 1 square, 2 noise,
;                                         3 rumble (a random walk), 4 buzz
;                                         (half square, half noise), 5 soft
;                                         triangle (the calm one)
;                                   rewind 1: this tone starts where the
;                                         effect started (under the others)
;        dw samples                 its length, 1..; 11025 = one second
;        dw halfper0, halfper1      the half period at its start and end,
;                                   in samples * 256 (8.8); 7FFFh: noise/rest
;        db loud0, loud1            loudness at start and end, 0..127
;  The SB_TONE macro writes one from Hz:
;        SB_TONE wave,rewind,samples,fromHz,toHz,fromLoud,toLoud
;  (Hz 0 for noise or a rest; Hz must be 22 or more; a macro must come
;  before its use, so a program's own tone lists go AFTER the include
;  of this file). The whole effect,
;  rewinds and all, must stay under 30000 samples (the ring is 32768).
;        my_zap: SB_TONE 1,0,1500,1200,300,40,0   ; a falling zap
;                db 0FFh
;        mov  si,my_zap
;        mov  ah,16             ; full loudness
;        call SB_PLAY
;
;  needs: nothing (no other kit file; ENGINE\E_SND.INC's SBWR/SFXRAW/SFXMB
;         are copied in here because they hard-wire 220h and DMA 1). 8086.
;  from: GAMES\MULTSOK2\SOUND.INC:16-595 (SPROBE, SNDON/SNDOFF, SBWR,
;        SFXRAW, SFX, SAMPLE, GENBED, WIND, WAVES, HEAL, BIRDS, TONE, FX
;        tables - proven there), ENGINE\E_SND.INC, the BLASTER parse from
;        LAB\OWLFLY4\VIDEO\SB.INC:176-252 (SBENV, ported to the 8086);
;        any DMA channel/IRQ, volume and SB_PLAY are new.
; ============================================================================

SB_N    = 8000h                 ; the ring: 32768 samples, about 3 s

; ---- the effects (SB_FX AL = one of these) -----------------------------------
SBX_PUSH  = 0                   ; a crate slides on stone, a soft knock
SBX_HOME  = 1                   ; a thing put right: G, then the C above
SBX_OFF   = 2                   ; a thing put wrong again: E down to C
SBX_LAY   = 3                   ; something laid down: a low wooden knock
SBX_TICK  = 4                   ; a clock's tick
SBX_BOOM  = 5                   ; an explosion, heard from a field away
SBX_GEMUP = 6                   ; a jewel grows: a long rising tone
SBX_COIN  = 7                   ; a coin / jewel taken: C E G C music box
SBX_GATE  = 8                   ; a chain rattling, a winch under it
SBX_THUD  = 9                   ; something heavy settles
SBX_OUT   = 10                  ; out through a door: E, A
SBX_WIN   = 11                  ; the win: a lullaby, E E G and a low C
SBX_HOOT  = 12                  ; an owl: hoo... hoo-hoo
SBX_POP   = 13                  ; a soft pop (a candy eaten)
SBX_SONG1 = 14                  ; a songbird far off (three songs)
SBX_SONG2 = 15
SBX_SONG3 = 16
SBX_CATCH = 17                  ; wings beat, a startled hoo, then E, A
SBX_SHOOT = 18                  ; a shot: a crack and a falling square
SBX_JUMP  = 19                  ; a jump: a square rising
SBX_HIT   = 20                  ; a hit: a dull thump
SBX_LOSE  = 21                  ; a life lost: three notes falling
SBX_N     = 22                  ; how many

; ---- the settings a program may set (before SB_INIT) ---------------------------
sb_want db 1                    ; 0: the player chose silence - no port touched
sb_env  db 1                    ; 1: read BLASTER from the environment
sb_port dw 220h                 ; the card's base port
sb_irq  db 7                    ; its IRQ (masked while the ring runs)
sb_dma  db 1                    ; its 8-bit DMA channel, 1..3
sb_seg  dw 0                    ; the ring's segment, 0: SB_INIT takes 64K
; ---- what SB_INIT says --------------------------------------------------------
sb_ok   db 0                    ; 1: the card answered and the ring plays
; ---- the state ------------------------------------------------------------------
sb_mem  dw 0                    ; the block SB_INIT took (SB_DONE frees it)
sb_msk  db 0                    ; the PIC's mask bit for our IRQ, as found
sb_cntp db 3                    ; the DMA channel's count port
sb_vol  db 16                   ; 0..16, everything's loudness
sb_bed  db 0                    ; 0 silence, 1 breeze+waves, 2 and birds
sb_rst  dw 0                    ; HEAL's cursor
sb_fxat dw 0                    ; SFX: where the effect began
sb_fxsc dw 256                  ; SFX: loudness scale, 256 = full
sb_hvol db 16                   ; WIND: the breeze's loudness, 64ths
sb_ws   dw 0                    ;  the wash's filter
sb_ws2  dw 0                    ;  the breeze's filter
sb_wsd  dw 4321                 ;  the wind's own noise seed
sb_wvol db 0                    ; WAVES: the wash's loudness now, 64ths
sb_wpk  db 0                    ;  this wave's height
sb_wph  db 0                    ;  0 still, 1 rolling in, 2 drawing back
sb_wst  dw 0                    ;  the tick this part began
sb_wlen dw 0                    ;  its ticks
sb_now  dw 0                    ; the BIOS tick, read by SB_HEAL
sb_bird dw 0                    ; the tick of the next bird
sb_swv  db 0                    ; SAMPLE: the tone's wave
sb_ssg  db 0                    ;  which half of the period
sb_slen dw 1                    ;  its length
sb_shp  dw 0                    ;  half period now, 8.8
sb_sdhp dw 0                    ;  its change a sample
sb_samp dw 0                    ;  loudness now, 8.8
sb_sdam dw 0                    ;  its change a sample
sb_sph  dw 0                    ;  the phase, 8.8
sb_swk  dw 0                    ;  the rumble's walk
sb_seed dw 7321                 ; the effects' noise

; ============================================================================
;@ SB_INIT    find the Sound Blaster, start the ring looping (CF=1: no sound)
;  in:  [sb_want] [sb_env] [sb_port] [sb_irq] [sb_dma] [sb_seg] as wanted
;  out: CF=0 and [sb_ok]=1 playing; CF=1 [sb_ok]=0: no card/no memory/not
;       wanted - every SB_ call is then a quiet no-op
;  needs: a .COM shrunk with INT 21h 4Ah first (see the file's header)
;  from: GAMES\MULTSOK2\SOUND.INC:16-90 (SPROBE, SNDON)
; ----------------------------------------------------------------------
if used SB_INIT
SB_INIT:cmp  byte [sb_ok],0
        je   .go
        clc                     ; already playing
        ret
.go:    push ax
        push bx
        push cx
        push dx
        push si
        push di
        push es
        cmp  byte [sb_want],0
        je   .no
        cmp  byte [sb_env],0
        je   .probe
        call SB_ENV             ; BLASTER, if it is there and makes sense
.probe: call SB_RST
        jc   .no                ; nobody answered: silence, the game runs on
        mov  al,[sb_dma]
        cmp  al,1
        jb   .no                ; channel 0 refreshes memory on old PCs
        cmp  al,3
        ja   .no                ; 4..7 are 16-bit channels
        add  al,al              ; the count port: channel * 2 + 1
        inc  al
        mov  [sb_cntp],al
        cmp  word [sb_seg],0
        jne  .have
        mov  ah,48h             ; 64K from DOS: somewhere in it a 32K run
        mov  bx,1000h           ;  that crosses no 64K page
        int  21h
        jc   .no
        mov  [sb_mem],ax
        mov  bx,ax
        and  bx,0FFFh           ; paragraphs past the 64K page's start
        cmp  bx,800h
        jbe  .al                ; 32K still fit before the page ends
        add  ax,0FFFh           ; else up to the next page, which
        and  ax,0F000h          ;  lies inside the block we took
.al:    mov  [sb_seg],ax
.have:  call SB_GENB            ; the ring filled before it plays
        ; ---- the 8237: channel [sb_dma], auto-init, read from memory
        mov  bl,[sb_dma]
        xor  bh,bh
        mov  al,bl
        or   al,4
        out  0Ah,al             ; mask the channel
        xor  al,al
        out  0Ch,al             ; clear the flip-flop
        mov  al,58h
        or   al,bl
        out  0Bh,al             ; mode: single, auto-init, read, channel
        mov  ax,[sb_seg]
        mov  cl,4
        shl  ax,cl              ; the address inside its 64K page:
        mov  dx,bx              ;  (segment and 0FFFh) * 16 - the shift
        add  dx,dx              ;  drops the page's own bits
        out  dx,al              ; address port = channel * 2: low...
        mov  al,ah
        out  dx,al              ; ...high
        inc  dx                 ; count port = channel * 2 + 1
        mov  ax,SB_N-1
        out  dx,al              ; count low...
        mov  al,ah
        out  dx,al              ; ...high
        mov  ax,[sb_seg]
        mov  cl,12
        shr  ax,cl              ; the page: the address's top 4 bits
        mov  dl,[sb_pgp+bx]
        xor  dh,dh
        out  dx,al
        mov  al,bl
        out  0Ah,al             ; unmask the channel
        ; ---- our IRQ masked: auto-init needs no servicing
        call SB_IRQP            ; DX = the PIC's mask port, AH = the bit
        in   al,dx
        and  al,ah
        mov  [sb_msk],al        ; the bit as we found it
        in   al,dx
        or   al,ah
        out  dx,al
        ; ---- the DSP: speaker on, 11025 a second, the whole ring, go
        mov  ah,0D1h
        call SB_WR
        mov  ah,40h             ; time constant: 256 - 1000000/11025 = 165
        call SB_WR
        mov  ah,165
        call SB_WR
        mov  ah,48h             ; the block: the whole ring
        call SB_WR
        mov  ax,SB_N-1
        mov  ah,al
        call SB_WR
        mov  ax,SB_N-1
        call SB_WR              ; (its high byte, already in AH)
        mov  ah,1Ch             ; 8-bit, auto-init: round and round
        call SB_WR
        mov  word [sb_rst],0
        call SB_TIK
        add  ax,90              ; the first bird in 5 s
        mov  [sb_bird],ax
        mov  byte [sb_ok],1
        pop  es
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        clc
        ret
.no:    mov  byte [sb_ok],0
        pop  es
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        stc
        ret
sb_pgp  db 87h,83h,81h,82h      ; the page ports of DMA channels 0..3
end if

; ============================================================================
;@ SB_DONE    silence the card, stop the DMA, IRQ as found, ring memory freed
;  in:  -  (call it on every way out; harmless twice or with no card)
;  out: -
;  needs: nothing
;  from: GAMES\MULTSOK2\SOUND.INC:92-110 (SNDOFF)
; ----------------------------------------------------------------------
if used SB_DONE
SB_DONE:cmp  byte [sb_ok],0
        je   .r
        push ax
        push dx
        push es
        mov  ah,0D3h            ; the speaker off...
        call SB_WR
        call SB_RST             ; ...a reset stops the DMA loop...
        mov  al,[sb_dma]
        or   al,4
        out  0Ah,al             ; ...the channel masked...
        call SB_IRQP            ; ...and our IRQ's bit back as we found it
        in   al,dx
        not  ah
        and  al,ah
        or   al,[sb_msk]
        out  dx,al
        mov  byte [sb_ok],0
        mov  ax,[sb_mem]
        or   ax,ax
        jz   .x
        mov  es,ax              ; the 64K given back to DOS
        mov  ah,49h
        int  21h
        mov  word [sb_mem],0
        mov  word [sb_seg],0
.x:     pop  es
        pop  dx
        pop  ax
.r:     ret
end if

; ============================================================================
;@ SB_HEAL    renew the ring behind the playing position (call every frame)
;  in:  -  (at least 4 times a second; a longer stall is caught up)
;  out: -
;  needs: SB_INIT; with no card it returns at once
;  from: GAMES\MULTSOK2\SOUND.INC:275-311 (HEAL) and 450-469 (BIRDS)
; ----------------------------------------------------------------------
if used SB_HEAL
SB_HEAL:cmp  byte [sb_ok],0
        jne  .on
        ret
.on:    push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        push es
        call SB_TIK
        mov  [sb_now],ax
        call SB_POS             ; BX = the position
        mov  ax,bx
        sub  ax,64              ; just behind it
        and  ax,SB_N-1
        mov  cx,ax
        sub  cx,[sb_rst]        ; how much was played since last time
        and  cx,SB_N-1
        cmp  cx,4096            ; at most this much at a time (after a stall)
        jbe  .h1
        mov  cx,4096
.h1:    jcxz .birds
        push cx
        call SB_WAVE            ; the wave's height now
        pop  cx
        mov  di,[sb_rst]
        mov  ax,di
        add  ax,cx              ; the cursor moves on by what we write
        and  ax,SB_N-1
        mov  [sb_rst],ax
        mov  es,[sb_seg]
        cmp  byte [sb_bed],0
        jne  .bed
.sil:   mov  byte [es:di],80h   ; no bed: silence behind the position
        inc  di
        and  di,SB_N-1
        loop .sil
        jmp  .birds
.bed:   mov  si,[sb_ws]
        mov  bp,[sb_wsd]
.hc:    call SB_WIND
        stosb
        and  di,SB_N-1
        loop .hc
        mov  [sb_ws],si
        mov  [sb_wsd],bp
.birds: cmp  byte [sb_bed],2
        jne  .x
        mov  ax,[sb_now]
        sub  ax,[sb_bird]
        js   .x                 ; not yet
        call SB_RND
        mov  al,ah
        xor  ah,ah
        add  ax,180             ; 10..24 s to the next: a bird far off
        add  ax,[sb_now]
        mov  [sb_bird],ax
        call SB_RND
        mov  al,ah
        and  al,3
        cmp  al,3
        jb   .s
        dec  al                 ; four draws, three songs: the last twice
.s:     add  al,SBX_SONG1
        mov  ah,10              ; far off: 10 sixteenths
        call SB_FXV
.x:     pop  es
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ============================================================================
;@ SB_BED     the ambient bed: 0 silence, 1 breeze and waves, 2 and birds
;  in:  AL = 0, 1 or 2
;  out: -
;  needs: SB_HEAL every frame (the bed comes in over ~3 s as it heals)
;  from: new (MULTSOK2's bed, made switchable)
; ----------------------------------------------------------------------
if used SB_BED
SB_BED: cmp  al,2
        jbe  .ok
        mov  al,2
.ok:    mov  [sb_bed],al
        ret
end if

; ============================================================================
;@ SB_VOL     everything's loudness: effects and bed, 0 (silent) .. 16 (full)
;  in:  AL = 0..16 (above 16 is 16)
;  out: -
;  needs: nothing (effects already in the ring keep their loudness)
;  from: new
; ----------------------------------------------------------------------
if used SB_VOL
SB_VOL: cmp  al,16
        jbe  .ok
        mov  al,16
.ok:    mov  [sb_vol],al
        mov  [sb_hvol],al       ; the breeze: 16 64ths at full
        ret
end if

; ============================================================================
;@ SB_SPKR    the card's output switch: AL=0 silent at once, 1 heard again
;  in:  AL = 0 or 1
;  out: -
;  needs: SB_INIT (no card: nothing); the ring keeps turning underneath, so
;         sound is back the moment it is switched on
;  from: GAMES\OWLFLY3\SRC\SOUND.INC:409-433 (SNDTOG's DSP D3h/D1h)
; ----------------------------------------------------------------------
if used SB_SPKR
SB_SPKR:cmp  byte [sb_ok],0
        je   .r
        push ax
        or   al,al
        mov  ah,0D3h            ; the speaker off
        jz   .w
        mov  ah,0D1h            ; on
.w:     call SB_WR
        pop  ax
.r:     ret
end if

; ============================================================================
;@ SB_FX      play effect AL (SBX_...) at full loudness, mixed into the ring
;  in:  AL = SBX_ id
;  out: -
;  needs: SB_INIT (no card: nothing happens)
;  from: GAMES\MULTSOK2\SOUND.INC:313-410 (SFX)
; ----------------------------------------------------------------------
if used SB_FX
SB_FX:  push ax
        mov  ah,16
        call SB_FXV
        pop  ax
        ret
end if

; ============================================================================
;@ SB_FXV     play effect AL at loudness AH (0..16): the far ones quieter
;  in:  AL = SBX_ id, AH = loudness 0..16
;  out: -
;  needs: SB_INIT
;  from: GAMES\MULTSOK2\SOUND.INC:313-410 (SFX), loudness new
; ----------------------------------------------------------------------
if used SB_FXV
SB_FXV: cmp  al,SBX_N
        jae  .r                 ; not in the table
        push si
        push bx
        mov  bl,al
        xor  bh,bh
        add  bx,bx              ; word rows
        mov  si,[sb_fxtab+bx]
        pop  bx
        call SB_PLAY
        pop  si
.r:     ret
end if

; ============================================================================
;@ SB_PLAY    mix a tone list (the format in this file's header) into the ring
;  in:  SI -> the tone list, ended by db 0FFh; AH = loudness 0..16
;  out: -
;  needs: SB_INIT (no card: nothing happens)
;  from: GAMES\MULTSOK2\SOUND.INC:313-410 (SFX)
; ----------------------------------------------------------------------
if used SB_PLAY
SB_PLAY:cmp  byte [sb_ok],0
        jne  .on
        ret
.on:    push ax
        push bx
        push cx
        push dx
        push si
        push di
        push es
        mov  al,ah              ; the loudness times the volume:
        cmp  al,16
        jbe  .l1
        mov  al,16
.l1:    mul  byte [sb_vol]      ; AX = loud * vol, 0..256
        or   ax,ax
        jz   .end               ; silent: nothing to mix
        mov  [sb_fxsc],ax
        mov  es,[sb_seg]
        call SB_POS
        lea  di,[bx+700]        ; 60 ms ahead of the position
        and  di,SB_N-1
        mov  [sb_fxat],di
.tone:  lodsb
        cmp  al,0FFh
        je   .end
        mov  [sb_swv],al
        lodsb
        or   al,al
        jz   .on1
        mov  di,[sb_fxat]       ; a rewind: back to the effect's start
.on1:   lodsw
        mov  [sb_slen],ax
        or   ax,ax
        jnz  .len
        add  si,6               ; a tone of no length: skip it, never
        jmp  .tone              ;  divide by it
.len:   lodsw
        mov  [sb_shp],ax
        mov  bx,ax
        lodsw
        sub  ax,bx              ; the half period's change, all told
        cwd
        idiv word [sb_slen]     ; ...a sample (slen > 0, |change| < 32768)
        mov  [sb_sdhp],ax
        lodsb
        call .scale             ; AL = loudness * scale / 256
        xor  ah,ah
        mov  bl,ah
        mov  bh,al
        mov  [sb_samp],bx       ; the loudness, 8.8
        lodsb
        call .scale
        mov  dh,al
        xor  dl,dl
        sub  dx,bx              ; its change, all told
        mov  ax,dx
        cwd
        idiv word [sb_slen]     ; ...a sample
        mov  [sb_sdam],ax
        mov  word [sb_sph],0
        push si
        mov  cx,[sb_slen]
.s:     push cx
        call SB_SMP             ; DX = this sample, signed
        mov  al,[es:di]
        xor  ah,ah
        add  ax,dx              ; added to what is there...
        jns  .p
        xor  ax,ax
.p:     cmp  ax,255             ; ...and kept inside a byte
        jle  .q
        mov  ax,255
.q:     mov  [es:di],al
        inc  di
        and  di,SB_N-1
        mov  ax,[sb_sdhp]
        add  [sb_shp],ax        ; the pitch slides
        mov  ax,[sb_sdam]
        add  [sb_samp],ax       ; the loudness slides
        pop  cx
        loop .s
        pop  si
        jmp  .tone
.end:   pop  es
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
; AL (0..127) * [sb_fxsc] / 256 -> AL; keeps DX
.scale: push dx
        and  al,7Fh
        xor  ah,ah
        mul  word [sb_fxsc]     ; DX:AX = loud * scale, under 32768
        mov  al,ah              ; / 256
        pop  dx
        ret
end if

; ---- SB_SMP - the next sample of the tone in hand, signed, in DX -------------
;  (internal; clobbers AX BX CX)
if used SB_PLAY
SB_SMP: add  word [sb_sph],256  ; a sample on
        mov  ax,[sb_sph]
        cmp  ax,[sb_shp]
        jb   .in
        sub  ax,[sb_shp]        ; past half a period: the wave turns over
        mov  [sb_sph],ax
        xor  byte [sb_ssg],1
.in:    mov  bl,byte [sb_samp+1] ; BL = the loudness now, 0..127
        and  bl,7Fh
        mov  al,[sb_swv]
        cmp  al,1
        je   .sq
        cmp  al,2
        je   .nz
        cmp  al,3
        je   .walk
        cmp  al,4
        je   .buzz
        cmp  al,5
        je   .tri
        xor  dx,dx              ; 0: a rest
        ret
.sq:    mov  dl,bl
        xor  dh,dh
        cmp  byte [sb_ssg],0
        je   .r
        neg  dx
.r:     ret
.nz:    call SB_RND
        mov  al,ah
        imul bl                 ; -128..127 * loudness (signed byte: BL <= 127)
        mov  cl,7
        sar  ax,cl              ; / 128
        mov  dx,ax
        ret
.walk:  call SB_RND
        mov  al,ah
        cbw
        sar  ax,1
        sar  ax,1
        sar  ax,1               ; -16..15
        add  ax,[sb_swk]        ; the walk steps
        xor  bh,bh
        cmp  ax,bx
        jle  .w1
        mov  ax,bx              ; fenced by the loudness
.w1:    neg  bx
        cmp  ax,bx
        jge  .w2
        mov  ax,bx
.w2:    mov  [sb_swk],ax
        mov  dx,ax
        ret
.buzz:  call .sq
        sar  dx,1               ; half a square...
        push dx
        call .nz
        sar  dx,1               ; ...half noise
        pop  ax
        add  dx,ax              ; together
        ret
.tri:   mov  ax,[sb_sph]        ; the phase in the half period, 0..hp
        mov  cl,bl
        xor  ch,ch
        shl  cx,1               ; 2 * loudness
        mul  cx                 ; DX:AX = phase * 2 * loudness
        mov  cx,[sb_shp]
        or   cx,cx
        jz   .t0
        cmp  dx,cx
        jae  .t0                ; (the quotient would not fit: never here)
        div  cx                 ; 0..2*loudness across the half period
        xor  bh,bh
        sub  ax,bx              ; -loudness..+loudness
        cmp  byte [sb_ssg],0
        je   .t1
        neg  ax                 ; and back down in the other half
.t1:    mov  dx,ax
        ret
.t0:    xor  dx,dx
        ret
end if

; ============================================================================
;  internal pieces (no ;@ - nobody calls them from outside)
; ============================================================================

; SB_WR - AH to the DSP (base+0Ch) when it is ready, with a patience limit
;  keeps all but AL
if used SB_WR
SB_WR:  push cx
        push dx
        mov  dx,[sb_port]
        add  dx,0Ch             ; the write port
        mov  cx,1000
.w:     in   al,dx
        test al,80h
        jz   .go
        loop .w
.go:    mov  al,ah
        out  dx,al
        pop  dx
        pop  cx
        ret
end if

; SB_RST - reset the DSP at [sb_port]: CF=0 it answered 0AAh. Keeps all.
if used SB_RST
SB_RST: push ax
        push cx
        push dx
        mov  dx,[sb_port]
        add  dx,6               ; the reset port
        mov  al,1
        out  dx,al              ; reset high...
        in   al,dx
        in   al,dx
        in   al,dx
        in   al,dx              ; (a few microseconds)
        xor  al,al
        out  dx,al              ; ...and low
        mov  cx,4000
.w:     mov  dx,[sb_port]
        add  dx,0Eh             ; the read-status port
        in   al,dx
        test al,80h             ; a byte to read?
        jz   .nx
        sub  dx,4               ; the read port, base+0Ah
        in   al,dx
        cmp  al,0AAh            ; the DSP's hello
        je   .yes
.nx:    loop .w
        pop  dx
        pop  cx
        pop  ax
        stc
        ret
.yes:   pop  dx
        pop  cx
        pop  ax
        clc
        ret
end if

; SB_IRQP - DX = the PIC mask port of [sb_irq], AH = its bit. Keeps the rest.
if used SB_IRQP
SB_IRQP:push cx
        mov  cl,[sb_irq]
        and  cl,15
        cmp  cl,2
        jne  .n2
        mov  cl,9               ; IRQ 2 on an AT is 9: masking bit 2 would
.n2:    mov  dx,21h             ;  shut the whole second PIC. 0..7: the first
        cmp  cl,8
        jb   .b
        mov  dx,0A1h            ; 8..15: the second
        sub  cl,8               ; its bit there
.b:     mov  ah,1
        shl  ah,cl              ; the IRQ's bit
        pop  cx
        ret
end if

; SB_POS - BX = where in the ring the DMA plays now. Keeps all but BX.
if used SB_POS
SB_POS: push ax
        push dx
        xor  al,al
        out  0Ch,al             ; clear the flip-flop
        mov  dl,[sb_cntp]
        xor  dh,dh
        in   al,dx              ; the count left, low byte...
        mov  bl,al
        in   al,dx              ; ...high
        mov  bh,al
        mov  ax,SB_N-1
        sub  ax,bx              ; played = all - left
        and  ax,SB_N-1
        mov  bx,ax
        pop  dx
        pop  ax
        ret
end if

; SB_TIK - AX = the BIOS tick's low word
if used SB_TIK
SB_TIK: push es
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:46Ch]
        pop  es
        ret
end if

; SB_RND - AX = the next of a 16-bit generator (the high byte is the good one)
;  keeps all but AX
if used SB_RND
SB_RND: push dx
        mov  ax,[sb_seed]
        mov  dx,25173
        mul  dx                 ; seed * 25173 (DX goes)
        add  ax,13849           ; + 13849
        mov  [sb_seed],ax
        pop  dx
        ret
end if

; SB_GENB - the whole ring filled with the bed (or silence) before it plays
if used SB_GENB
SB_GENB:push ax
        push cx
        push dx
        push si
        push di
        push bp
        push es
        mov  es,[sb_seg]
        xor  di,di
        cmp  byte [sb_bed],0
        jne  .g0
        mov  al,80h             ; silence
        mov  cx,SB_N
        rep  stosb
        jmp  .x
.g0:    mov  si,[sb_ws]
        mov  bp,[sb_wsd]
.g:     call SB_WIND
        stosb
        cmp  di,SB_N
        jb   .g
        mov  [sb_ws],si
        mov  [sb_wsd],bp
.x:     pop  es
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  ax
        ret
end if

; SB_WIND - one sample of the bed: noise through a soft filter - the wash
;  of the waves, SI, at [sb_wvol] 64ths - and through it again, darker -
;  the breeze, [sb_ws2], at [sb_hvol] 64ths. BP = the noise seed; SI and
;  BP carried on. Out AL (unsigned, around 80h). Clobbers DX, AH.
if used SB_WIND
SB_WIND:mov  ax,25173
        mul  bp                 ; seed * 25173 (DX goes)
        add  ax,13849           ; + 13849
        mov  bp,ax              ; the wind's own noise
        mov  al,ah
        cbw                     ; -128..127
        sub  ax,si
        sar  ax,1
        sar  ax,1
        sar  ax,1               ; (noise - wash) / 8: a one-pole low pass
        add  si,ax              ;  (SI stays in -128..127)
        mov  ax,si
        sub  ax,[sb_ws2]
        sar  ax,1
        sar  ax,1
        sar  ax,1               ; (wash - breeze) / 8: low-passed again
        add  [sb_ws2],ax
        mov  ax,si
        imul byte [sb_wvol]     ; the wash at the wave's height (0..15)
        mov  dx,ax
        mov  al,byte [sb_ws2]
        imul byte [sb_hvol]     ; the breeze under it (0..16)
        add  ax,dx              ; both
        shl  ax,1
        shl  ax,1
        mov  al,ah              ; * 4 / 256: in 64ths
        add  al,128             ; around the midline
        ret
end if

; SB_WAVE - the waves, [sb_wvol] 0..15: one rolls in for 2 to 3 s, draws
;  back for 3 to 5, the shore is still for 2 to 6 s; each its own height.
;  Clobbers AX, CX, DX.
if used SB_WAVE
SB_WAVE:mov  ax,[sb_now]
        sub  ax,[sb_wst]        ; ticks into this part of the wave
        cmp  ax,[sb_wlen]
        jb   .h
        mov  ax,[sb_now]        ; the next part
        mov  [sb_wst],ax
        call SB_RND
        mov  al,ah
        inc  byte [sb_wph]
        cmp  byte [sb_wph],3
        jb   .p
        mov  byte [sb_wph],0
.p:     cmp  byte [sb_wph],1
        je   .rise
        ja   .fall
        and  ax,63
        add  ax,36              ; still: 2 to 5.5 s
        jmp  .len
.rise:  push ax
        and  al,7
        add  al,8               ; this one's height: 8..15
        mul  byte [sb_vol]      ; * volume (AX = 0..240)
        mov  cl,4
        shr  ax,cl              ; / 16
        mov  [sb_wpk],al
        pop  ax
        mov  cl,3
        shr  al,cl
        and  ax,15
        add  ax,36              ; rolling in: 2 to 2.8 s
        jmp  .len
.fall:  and  ax,31
        add  ax,55              ; drawing back: 3 to 4.7 s
.len:   mov  [sb_wlen],ax       ; never 0: the divide below is safe
        xor  ax,ax
.h:     cmp  byte [sb_wph],0    ; AX = ticks into it, < [sb_wlen]
        jne  .w
        mov  byte [sb_wvol],0   ; still
        ret
.w:     cmp  byte [sb_wph],1
        je   .up
        neg  ax
        add  ax,[sb_wlen]       ; drawing back: what is left of it
.up:    mov  dl,[sb_wpk]
        xor  dh,dh
        mul  dx                 ; height * ticks (DX:AX, DX goes)
        div  word [sb_wlen]     ;  / its length: < height, no overflow
        mov  [sb_wvol],al
        ret
end if

; SB_ENV - BLASTER=A220 I7 D1 ... into [sb_port] [sb_irq] [sb_dma]: the
;  port if A is there; I if 0..15; D if an 8-bit channel 1..3. Keeps all.
if used SB_ENV
SB_ENV: push ax
        push bx
        push cx
        push dx
        push si
        push di
        push es
        mov  es,[2Ch]           ; the environment segment, from the PSP
        xor  di,di
.e1:    cmp  byte [es:di],0     ; the end of the whole block?
        je   .no
        mov  si,sb_envn         ; does this entry start with BLASTER= ?
        mov  bx,di
.e2:    lodsb
        or   al,al
        jz   .got
        cmp  al,[es:bx]
        jne  .e4
        inc  bx
        jmp  .e2
.e4:    cmp  byte [es:di],0     ; no: to the end of this entry
        je   .e5
        inc  di
        jmp  .e4
.e5:    inc  di                 ; and the next
        jmp  .e1
.got:   mov  di,bx              ; just past "BLASTER="
        xor  bx,bx              ; BX = the port found, 0 none
        mov  cx,0FFFFh          ; CL = IRQ, CH = DMA, 0FFh none
.e6:    mov  al,[es:di]
        or   al,al
        jz   .end
        and  al,0DFh            ; a letter to a capital
        inc  di
        cmp  al,'A'
        je   .a
        cmp  al,'I'
        je   .i
        cmp  al,'D'
        je   .d
        jmp  .e6
.a:     call .hex
        mov  bx,ax
        jmp  .e6
.i:     call .dec
        mov  cl,al
        jmp  .e6
.d:     call .dec
        mov  ch,al
        jmp  .e6
.end:   or   bx,bx
        jz   .no                ; no port: the variable says nothing
        mov  [sb_port],bx
        cmp  cl,15
        ja   .ni                ; no IRQ (0FFh) or nonsense: the default
        mov  [sb_irq],cl
.ni:    cmp  ch,1
        jb   .no
        cmp  ch,3
        ja   .no                ; 8-bit channels 1..3 only
        mov  [sb_dma],ch
.no:    pop  es
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
; ES:DI -> hex digits: AX, DI past them. Keeps CX.
.hex:   push cx
        xor  ax,ax
.h1:    mov  dl,[es:di]
        cmp  dl,'0'
        jb   .h9
        cmp  dl,'9'
        jbe  .h2
        and  dl,0DFh
        cmp  dl,'A'
        jb   .h9
        cmp  dl,'F'
        ja   .h9
        sub  dl,7               ; 'A'..'F' to just past '9'
.h2:    sub  dl,'0'             ; the digit's value
        mov  cl,4
        shl  ax,cl              ; the number so far * 16
        or   al,dl              ; + the digit
        inc  di
        jmp  .h1
.h9:    pop  cx
        ret
; ES:DI -> decimal digits: AL (up to 255), DI past them. Keeps CX.
.dec:   push cx
        xor  ax,ax
.d1:    mov  dl,[es:di]
        cmp  dl,'0'
        jb   .d9
        cmp  dl,'9'
        ja   .d9
        sub  dl,'0'             ; the digit's value
        mov  cx,ax
        shl  ax,1
        shl  ax,1               ; * 4
        add  ax,cx              ; * 5
        shl  ax,1               ; * 10
        add  al,dl              ; + the digit
        inc  di
        jmp  .d1
.d9:    pop  cx
        ret
sb_envn db 'BLASTER=',0
end if

; ============================================================================
;  THE EFFECTS. SB_TONE wave,rewind,samples,fromHz,toHz,fromLoud,toLoud
;  (Hz 0: noise or a rest - no period). The half period is the rate over
;  twice the pitch, kept 8.8: 11025*128/Hz.
; ============================================================================
macro SB_TONE w,rw,len,f0,f1,a0,a1
{
        db w,rw
        dw len
  if f0 = 0
        dw 7FFFh,7FFFh
  else
        dw (11025*128)/f0,(11025*128)/f1
  end if
        db a0,a1
}

if used SB_FXV
sb_fxtab dw sb_tpush,sb_thome,sb_toff,sb_tlay,sb_ttick,sb_tboom,sb_tgemup
         dw sb_tcoin,sb_tgate,sb_tthud,sb_tout,sb_twin,sb_thoot,sb_tpop
         dw sb_tsng1,sb_tsng2,sb_tsng3,sb_tcatch,sb_tshot,sb_tjump,sb_thit
         dw sb_tlose
; the calm ones, from MULTIPLAY SOKO II: soft triangles, low, long
sb_tpush: SB_TONE 3,0,1200,0,0,20,0     ; the crate slides on the stone
        SB_TONE 5,1,700,90,70,18,0      ;  a soft knock under it
        db 0FFh
sb_thome: SB_TONE 5,0,1500,784,784,26,18 ; G, then C above it
        SB_TONE 5,0,3600,1047,1047,26,0
        db 0FFh
sb_toff: SB_TONE 5,0,1500,659,659,22,14  ; E down to C
        SB_TONE 5,0,3000,523,523,22,0
        db 0FFh
sb_tlay: SB_TONE 5,0,700,220,180,24,0    ; a low wooden knock
        SB_TONE 2,0,300,0,0,10,0
        db 0FFh
sb_ttick: SB_TONE 5,0,350,880,880,12,0   ; a clock's
        db 0FFh
sb_tboom: SB_TONE 3,0,10000,0,0,55,0     ; the blast, a field away
        SB_TONE 5,1,6000,55,40,36,0
        db 0FFh
sb_tgemup: SB_TONE 5,0,4500,600,1800,4,22 ; growing out of the floor
        SB_TONE 5,0,3000,1800,1800,22,0
        db 0FFh
sb_tcoin: SB_TONE 5,0,1200,1047,1047,26,20 ; C E G C, a music box
        SB_TONE 5,0,1200,1319,1319,26,20
        SB_TONE 5,0,1200,1568,1568,26,20
        SB_TONE 5,0,4500,2093,2093,26,0
        db 0FFh
sb_tgate: rept 7 {
        SB_TONE 2,0,280,0,0,22,4        ; a chain, slowly
        SB_TONE 0,0,700,0,0,0,0 }
        SB_TONE 5,1,6800,90,72,14,6     ;  under it a winch hums
        db 0FFh
sb_tthud: SB_TONE 3,0,5000,0,0,45,0      ; something heavy settles
        SB_TONE 5,1,4500,60,48,36,0
        db 0FFh
sb_tout: SB_TONE 5,0,1600,659,659,26,18  ; out through the gate
        SB_TONE 5,0,4000,880,880,26,0
        db 0FFh
sb_twin: SB_TONE 5,0,2600,659,659,30,26  ; a lullaby - E, E, G held
        SB_TONE 0,0,300,0,0,0,0
        SB_TONE 5,0,2600,659,659,30,26
        SB_TONE 0,0,300,0,0,0,0
        SB_TONE 5,0,7000,784,784,30,22
        SB_TONE 5,0,9500,523,523,22,0
        SB_TONE 5,1,17000,262,262,16,10 ;  the low C under all of it
        SB_TONE 5,0,6000,262,262,10,0
        db 0FFh
sb_thoot: SB_TONE 5,0,2600,400,380,6,24  ; hoo...
        SB_TONE 5,0,2000,380,350,24,0
        SB_TONE 0,0,2400,0,0,0,0
        SB_TONE 5,0,1200,400,390,18,0   ;  ...hoo-hoo
        SB_TONE 0,0,500,0,0,0,0
        SB_TONE 5,0,2600,390,345,20,0
        db 0FFh
sb_tpop: SB_TONE 5,0,600,1400,1800,14,0  ; a soft pop
        db 0FFh
sb_tsng1: SB_TONE 5,0,700,1900,2700,6,16 ; two whistles up and a fall
        SB_TONE 0,0,500,0,0,0,0
        SB_TONE 5,0,700,2000,2800,6,16
        SB_TONE 0,0,600,0,0,0,0
        SB_TONE 5,0,1400,2700,1800,15,0
        db 0FFh
sb_tsng2: rept 4 {
        SB_TONE 5,0,400,2400,2100,14,8  ; a slow trill
        SB_TONE 0,0,250,0,0,0,0 }
        SB_TONE 5,0,1000,2100,2600,12,0
        db 0FFh
sb_tsng3: SB_TONE 5,0,2000,1500,1500,4,14 ; a cuckoo's two
        SB_TONE 0,0,1200,0,0,0,0
        SB_TONE 5,0,2400,1250,1250,14,0
        db 0FFh
sb_tcatch: rept 4 {
        SB_TONE 2,0,220,0,0,16,2        ; wings beat
        SB_TONE 0,0,330,0,0,0,0 }
        SB_TONE 5,0,1800,420,520,24,0   ;  a startled hoo, up -
        SB_TONE 5,0,1400,1319,1319,22,16 ;  and E, A
        SB_TONE 5,0,4000,1760,1760,22,0
        db 0FFh
; the arcade ones (new): squares, short, brighter
sb_tshot: SB_TONE 2,0,500,0,0,40,0       ; the crack
        SB_TONE 1,1,2200,1400,250,22,0  ;  and a falling square under it
        db 0FFh
sb_tjump: SB_TONE 1,0,2000,260,620,18,6  ; a square rising
        db 0FFh
sb_thit: SB_TONE 3,0,1800,0,0,50,0       ; a dull thump
        SB_TONE 5,1,1500,110,70,40,0
        db 0FFh
sb_tlose: SB_TONE 5,0,2600,494,494,28,20 ; B, G, then E falling away
        SB_TONE 5,0,2600,392,392,28,20
        SB_TONE 5,0,7000,330,262,28,0
        db 0FFh
end if
