; ==================================================================
;  SOUND.INC - MULTIPLAY SOKO II's Sound Blaster, the WIRE CITY ring
;  mixer (EXAMPLES\RING.ASM, ENGINE\E_SND.INC): a 32K ring of 8-bit
;  samples loops forever through auto-init DMA on channel 1, 11025 a
;  second, no interrupts.  The ring's bed is the wind - made afresh by
;  HEAL behind the playing position, so it never loops and it wipes out
;  what was played; an effect is ADDED into the ring a little ahead of
;  the position, so effects sum like a real mixer.
;  Effects are made on the spot from a list of tones (SFXTAB): a
;  square, a soft triangle, noise, a random walk (a rumble), a buzz.
;  Birds sing now and then on their own (BIRDS, from the timer).
; ==================================================================
SNDN    = 8000h                 ; the ring: 32K samples, about 3 s

; SPROBE - a DSP at 220h? sbok 1: it answered the reset with 0AAh
SPROBE: mov  dx,226h
        mov  al,1
        out  dx,al              ; reset high...
        in   al,dx
        in   al,dx
        in   al,dx
        in   al,dx              ; (a few microseconds)
        xor  al,al
        out  dx,al              ; ...and low
        mov  cx,4000
.w:     mov  dx,22Eh
        in   al,dx
        test al,80h             ; a byte to read?
        jz   .nx
        mov  dx,22Ah
        in   al,dx
        cmp  al,0AAh            ; the DSP's hello
        je   .yes
.nx:    loop .w
        ret
.yes:   mov  byte [sbok],1
        ret

; ------------------------------------------------------------------
;  SNDON - the wind into the ring, the DMA looping, the DSP playing.
;  SNDOFF - all of it stopped and IRQ 7 as it was.
; ------------------------------------------------------------------
SNDON:  cmp  byte [sbok],0
        je   .no
        cmp  byte [sndwant],0
        je   .no
        call GENBED
        mov  al,05h
        out  0Ah,al             ; mask DMA channel 1
        xor  al,al
        out  0Ch,al             ; clear the flip-flop
        mov  al,59h
        out  0Bh,al             ; mode: auto-init, read, channel 1
        xor  al,al
        out  02h,al             ; address 0 in the segment: it starts a
        out  02h,al             ;  64K page, so the ring never crosses one
        mov  ax,SNDN-1
        out  03h,al             ; count low...
        mov  al,ah
        out  03h,al             ; ...high
        mov  ax,[rseg]
        mov  cl,12
        shr  ax,cl
        out  83h,al             ; channel 1's page: the address's top bits
        mov  al,01h
        out  0Ah,al             ; unmask channel 1
        in   al,21h
        mov  [sbmsk],al         ; IRQ 7 masked: auto-init needs no servicing
        or   al,80h
        out  21h,al
        mov  ah,0D1h            ; the speaker on
        call SBWR
        mov  ah,40h             ; time constant: 256 - 1000000/11025 = 165
        call SBWR
        mov  ah,165
        call SBWR
        mov  ah,48h             ; the block: the whole ring
        call SBWR
        mov  ax,SNDN-1
        mov  ah,al
        call SBWR
        mov  ax,SNDN-1
        call SBWR               ; (its high byte, already in AH)
        mov  ah,1Ch             ; 8-bit, auto-init: round and round
        call SBWR
        mov  byte [sndon],1
        call TICK
        mov  [birdnext],ax
.no:    ret

SNDOFF: cmp  byte [sndon],0
        je   .no
        mov  ah,0D3h            ; the speaker off...
        call SBWR
        mov  dx,226h            ; ...a reset stops the DMA loop...
        mov  al,1
        out  dx,al
        in   al,dx
        in   al,dx
        xor  al,al
        out  dx,al
        in   al,21h             ; ...and IRQ 7 back as we found it
        and  al,7Fh
        mov  ah,[sbmsk]
        and  ah,80h
        or   al,ah
        out  21h,al
        mov  byte [sndon],0
.no:    ret

; SBWR - AH to the DSP (22Ch), when it is ready, with a patience limit
SBWR:   push cx
        push dx
        mov  dx,22Ch
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

; SFXRAW - BX = where in the ring the DMA plays now
SFXRAW: xor  al,al
        out  0Ch,al             ; clear the flip-flop
        in   al,03h             ; channel 1's count left, low byte...
        mov  bl,al
        in   al,03h             ; ...high
        mov  bh,al
        mov  ax,SNDN-1
        sub  ax,bx              ; played = all - left
        and  ax,SNDN-1
        mov  bx,ax
        ret

; ------------------------------------------------------------------
;  GENBED - the ring filled with the wind, before it starts playing
; ------------------------------------------------------------------
GENBED: push es
        push bp
        mov  es,[rseg]
        xor  di,di
        mov  si,[wstate]
        mov  bp,[wseed]
.g:     call WIND
        stosb
        cmp  di,SNDN
        jb   .g
        mov  [wstate],si
        mov  [wseed],bp
        pop  bp
        pop  es
        ret

; WIND - one sample of the shore: its own noise through a soft filter -
; the waves' wash, SI, at [wvol] 64ths - and through it once more, darker
; - the breeze, [ws2], at [hvol] 64ths, steady under it.  BP = the
; noise's seed; SI and BP carried on.  Out AL.  clobbers DX.
WIND:   mov  ax,25173
        mul  bp                 ; (DX goes)
        add  ax,13849
        mov  bp,ax              ; the wind's own noise, not the game's RND
        mov  al,ah
        cbw                     ; -128..127
        sub  ax,si
        sar  ax,1
        sar  ax,1
        sar  ax,1               ; (noise - wash) / 8: a one-pole low pass
        add  si,ax              ;  (SI stays in -128..127: AL is it)
        mov  ax,si
        sub  ax,[cs:ws2]
        sar  ax,1
        sar  ax,1
        sar  ax,1               ; (wash - breeze) / 8: low-passed again
        add  [cs:ws2],ax
        mov  ax,si
        imul byte [cs:wvol]     ; the wash at the wave's height
        mov  dx,ax
        mov  al,byte [cs:ws2]
        imul byte [cs:hvol]     ; the breeze under it
        add  ax,dx
        shl  ax,1
        shl  ax,1
        mov  al,ah              ; * 4 / 256: in 64ths
        add  al,128             ; around the midline
        ret

; WAVES - the waves on the shore, [wvol] 0..15: one rolls in, its wash
; rising for 2 to 3 s, draws back for 3 to 5, and the shore is still for
; 2 to 6 s; each with a height of its own, never on a beat.  The pilot,
; after a steady wind: "like white noise - a calm breeze is wanted, with
; waves coming in" (before it, a swell every 10 s: "too many waves").
WAVES:  mov  ax,[now]
        sub  ax,[wst]           ; ticks into this part of the wave
        cmp  ax,[wlen]
        jb   .h
        mov  ax,[now]           ; the next part
        mov  [wst],ax
        call RND
        mov  al,ah
        inc  byte [wph]
        cmp  byte [wph],3
        jb   .p
        mov  byte [wph],0
.p:     cmp  byte [wph],1
        je   .rise
        ja   .fall
        and  ax,63
        add  ax,36              ; still: 2 to 5.5 s
        jmp  .len
.rise:  push ax
        and  al,7
        add  al,8
        mov  [wpeak],al         ; this one's height: 8..15 (at most 6 dB
                                ;  over the breeze)
        pop  ax
        mov  cl,3
        shr  al,cl
        and  ax,15
        add  ax,36              ; rolling in: 2 to 2.8 s
        jmp  .len
.fall:  and  ax,31
        add  ax,55              ; drawing back: 3 to 4.7 s
.len:   mov  [wlen],ax
        xor  ax,ax
.h:     cmp  byte [wph],0       ; AX = ticks into it
        jne  .w
        mov  byte [wvol],0      ; still
        ret
.w:     cmp  byte [wph],1
        je   .up
        neg  ax
        add  ax,[wlen]          ; drawing back: what is left of it
.up:    mov  dl,[wpeak]
        xor  dh,dh
        mul  dx                 ; height * ticks  (DX goes)
        div  word [wlen]        ;  / its length
        mov  [wvol],al
        ret

; HEAL - behind the playing position, the ring made the shore again: new
; noise, never the same three seconds twice (a loop of noise is heard as
; a beat), the breeze steady and the waves in it (WAVES).
HEAL:   cmp  byte [sndon],0
        je   .hr
        call SFXRAW             ; BX = the position
        mov  ax,bx
        sub  ax,64              ; just behind it
        and  ax,SNDN-1
        mov  cx,ax
        sub  cx,[sbrst]
        and  cx,SNDN-1
        cmp  cx,4096            ; at most this much at a time (after a stall)
        jbe  .h1
        mov  cx,4096
.h1:    jcxz .hr
        push cx
        call WAVES              ; the wave's height now
        pop  cx
        mov  di,[sbrst]
        mov  ax,di
        add  ax,cx
        and  ax,SNDN-1
        mov  [sbrst],ax
        push es
        push bp
        mov  es,[rseg]
        mov  si,[wstate]
        mov  bp,[wseed]
.hc:    call WIND
        stosb
        and  di,SNDN-1
        loop .hc
        mov  [wstate],si
        mov  [wseed],bp
        pop  bp
        pop  es
.hr:    ret

; ------------------------------------------------------------------
;  SFX - effect AL (SF_...), mixed into the ring 700 samples (60 ms)
;  ahead of the playing position.  Nothing when the sound is off.
;  A tone: db wave, rewind (1: it starts where the effect started, under
;  what came before it), dw length (samples), dw the half period at its
;  start and its end (samples, 8.8), db the loudness at its start and end.
; ------------------------------------------------------------------
SFX:
if defined TESTKEYS
        inc  word [tsfx]        ; a test build counts every effect asked for
end if
        cmp  byte [sndon],0
        jne  .on
        ret
.on:    push es
        xor  ah,ah
        mov  si,ax
        shl  si,1
        mov  si,[SFXTAB+si]
        mov  es,[rseg]
        call SFXRAW
        lea  di,[bx+700]
        and  di,SNDN-1
        mov  [sfxat],di
.tone:  lodsb
        cmp  al,0FFh
        je   .end
        mov  [swave],al
        lodsb
        or   al,al
        jz   .on1
        mov  di,[sfxat]         ; a rewind: back to the effect's start
.on1:   lodsw
        mov  [slen],ax
        lodsw
        mov  [shp],ax
        mov  bx,ax
        lodsw
        sub  ax,bx              ; the half period's change, all told
        cwd
        idiv word [slen]
        mov  [sdhp],ax          ; ...a sample
        lodsb
        xor  ah,ah
        mov  bl,ah
        mov  bh,al
        mov  [samp],bx          ; the loudness, 8.8
        lodsb
        xor  ah,ah
        mov  dh,al
        xor  dl,dl
        sub  dx,bx
        mov  ax,dx
        cwd
        idiv word [slen]
        mov  [sdamp],ax
        mov  word [sph],0
        push si
        mov  cx,[slen]
.s:     push cx
        call SAMPLE             ; DX = this sample
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
        and  di,SNDN-1
        mov  ax,[sdhp]
        add  [shp],ax
        mov  ax,[sdamp]
        add  [samp],ax
        pop  cx
        loop .s
        pop  si
        jmp  .tone
.end:   pop  es
        ret

; SAMPLE - the next sample of the tone in hand, signed, in DX
SAMPLE: add  word [sph],256     ; a sample on
        mov  ax,[sph]
        cmp  ax,[shp]
        jb   .in
        sub  ax,[shp]           ; past half a period: the wave turns over
        mov  [sph],ax
        xor  byte [ssign],1
.in:    mov  bl,byte [samp+1]   ; BL = the loudness now, 0..127
        and  bl,7Fh
        mov  al,[swave]
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
        cmp  byte [ssign],0
        je   .r
        neg  dx
.r:     ret
.nz:    call RND
        mov  al,ah
        imul bl                 ; -128..127 * loudness
        mov  cl,7
        sar  ax,cl
        mov  dx,ax
        ret
.walk:  call RND
        mov  al,ah
        cbw
        sar  ax,1
        sar  ax,1
        sar  ax,1               ; -16..15
        add  ax,[swalk]
        xor  bh,bh
        cmp  ax,bx
        jle  .w1
        mov  ax,bx              ; fenced by the loudness
.w1:    neg  bx
        cmp  ax,bx
        jge  .w2
        mov  ax,bx
.w2:    mov  [swalk],ax
        mov  dx,ax
        ret
.buzz:  call .sq
        sar  dx,1               ; half a square...
        push dx
        call .nz
        sar  dx,1               ; ...half noise: a crow's throat
        pop  ax
        add  dx,ax
        ret
.tri:   mov  ax,[sph]           ; the phase in the half period, 0..hp
        mov  cl,bl
        xor  ch,ch
        shl  cx,1               ; 2 * loudness
        mul  cx                 ; DX:AX = phase * 2 * loudness
        mov  cx,[shp]
        or   cx,cx
        jz   .t0
        cmp  dx,cx
        jae  .t0                ; (it cannot overflow: phase < hp)
        div  cx                 ; 0..2*loudness across the half period
        xor  bh,bh
        sub  ax,bx              ; -loudness..+loudness
        cmp  byte [ssign],0
        je   .t1
        neg  ax                 ; and back down in the other half
.t1:    mov  dx,ax
        ret
.t0:    xor  dx,dx
        ret

; RND - AX: the next of a 16-bit generator (the high byte is the good one)
RND:    mov  ax,[rseed]
        mov  dx,25173
        mul  dx                 ; (DX goes)
        add  ax,13849
        mov  [rseed],ax
        ret

; BIRDS - now and then a bird sings, far off in the park: every 10 to
; 24 s one of three songs.  From TIMERS; nothing when the sound is off.
BIRDS:  cmp  byte [sndon],0
        je   .no
        mov  ax,[now]
        sub  ax,[birdnext]
        js   .no                ; not yet
        call RND
        mov  al,ah
        xor  ah,ah
        add  ax,180             ; 10..24 s to the next: a bird far off
        add  ax,[now]
        mov  [birdnext],ax
        call RND
        mov  al,ah
        and  al,3
        cmp  al,3
        jb   .s
        dec  al                 ; four draws, three songs: the last twice
.s:     add  al,SF_SONG1
        call SFX
.no:    ret

; ------------------------------------------------------------------
;  The effects.  TONE wave,rewind,samples,from Hz,to Hz,from,to loudness
;  (Hz 0: noise or a rest - no period).  The half period is the sample
;  rate over twice the pitch, kept 8.8: 11025*128/Hz.
; ------------------------------------------------------------------
macro TONE w,rw,len,f0,f1,a0,a1
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
; The pilot's ear: calm, after work - so the effects are soft triangle
; tones (wave 5) more than squares, low, long, never loud; the blast is a
; muffled roll, the gate's chain far off, the winner's a lullaby.
SF_PUSH  = 0
SF_HOME  = 1
SF_OFF   = 2
SF_LAY   = 3
SF_TICK  = 4
SF_BOOM  = 5
SF_GEMUP = 6
SF_GEMGET = 7
SF_GATE  = 8
SF_THUD  = 9
SF_OUT   = 10
SF_WIN   = 11
SF_HOOT  = 12
SF_CANDY = 13
SF_SONG1 = 14                   ; three of them
SF_CATCH = 17
SFXTAB  dw FXPUSH,FXHOME,FXOFF,FXLAY,FXTICK,FXBOOM,FXGEMUP,FXGEMGET
        dw FXGATE,FXTHUD,FXOUT,FXWIN,FXHOOT,FXCANDY,FXSONG1,FXSONG2,FXSONG3
        dw FXCATCH
FXPUSH: TONE 3,0,1200,0,0,20,0          ; the crate slides on the stone
        TONE 5,1,700,90,70,18,0         ;  a soft knock under it
        db 0FFh
FXHOME: TONE 5,0,1500,784,784,26,18     ; home: G, then C above it
        TONE 5,0,3600,1047,1047,26,0
        db 0FFh
FXOFF:  TONE 5,0,1500,659,659,22,14     ; off a mark: E down to C
        TONE 5,0,3000,523,523,22,0
        db 0FFh
FXLAY:  TONE 5,0,700,220,180,24,0       ; a mine down: a low wooden knock
        TONE 2,0,300,0,0,10,0
        db 0FFh
FXTICK: TONE 5,0,350,880,880,12,0       ; its seconds, a clock's
        db 0FFh
FXBOOM: TONE 3,0,10000,0,0,55,0         ; the blast, heard from a field away
        TONE 5,1,6000,55,40,36,0
        db 0FFh
FXGEMUP:TONE 5,0,4500,600,1800,4,22     ; a diamond grows out of the floor
        TONE 5,0,3000,1800,1800,22,0
        db 0FFh
FXGEMGET:TONE 5,0,1200,1047,1047,26,20  ; taken: C E G C, a music box
        TONE 5,0,1200,1319,1319,26,20
        TONE 5,0,1200,1568,1568,26,20
        TONE 5,0,4500,2093,2093,26,0
        db 0FFh
FXGATE: rept 7 {
        TONE 2,0,280,0,0,22,4           ; the portcullis's chain, slowly
        TONE 0,0,700,0,0,0,0 }
        TONE 5,1,6800,90,72,14,6        ;  under it the winch hums
        db 0FFh
FXTHUD: TONE 3,0,5000,0,0,45,0          ; the drawbridge settles
        TONE 5,1,4500,60,48,36,0
        db 0FFh
FXOUT:  TONE 5,0,1600,659,659,26,18     ; a man out through the gate
        TONE 5,0,4000,880,880,26,0
        db 0FFh
FXWIN:  TONE 5,0,2600,659,659,30,26     ; the winner: a lullaby - E, E,
        TONE 0,0,300,0,0,0,0            ;  G held; the C below under it
        TONE 5,0,2600,659,659,30,26
        TONE 0,0,300,0,0,0,0
        TONE 5,0,7000,784,784,30,22
        TONE 5,0,9500,523,523,22,0
        TONE 5,1,17000,262,262,16,10    ;  the low C, held under all of it
        TONE 5,0,6000,262,262,10,0
        db 0FFh
FXHOOT: TONE 5,0,2600,400,380,6,24      ; the owl on the wall: hoo...
        TONE 5,0,2000,380,350,24,0
        TONE 0,0,2400,0,0,0,0
        TONE 5,0,1200,400,390,18,0      ;  ...hoo-hoo
        TONE 0,0,500,0,0,0,0
        TONE 5,0,2600,390,345,20,0
        db 0FFh
FXCANDY:TONE 5,0,600,1400,1800,14,0     ; a candy eaten: a soft pop
        db 0FFh
FXSONG1:TONE 5,0,700,1900,2700,6,16     ; a songbird far off: two whistles up
        TONE 0,0,500,0,0,0,0            ;  and a fall
        TONE 5,0,700,2000,2800,6,16
        TONE 0,0,600,0,0,0,0
        TONE 5,0,1400,2700,1800,15,0
        db 0FFh
FXSONG2:rept 4 {
        TONE 5,0,400,2400,2100,14,8     ; a slow trill
        TONE 0,0,250,0,0,0,0 }
        TONE 5,0,1000,2100,2600,12,0
        db 0FFh
FXSONG3:TONE 5,0,2000,1500,1500,4,14    ; a long note, a cuckoo's two
        TONE 0,0,1200,0,0,0,0
        TONE 5,0,2400,1250,1250,14,0
        db 0FFh
FXCATCH:rept 4 {
        TONE 2,0,220,0,0,16,2           ; the owl caught: its wings beat,
        TONE 0,0,330,0,0,0,0 }
        TONE 5,0,1800,420,520,24,0      ;  a startled hoo, up -
        TONE 5,0,1400,1319,1319,22,16   ;  and it is yours: E, A
        TONE 5,0,4000,1760,1760,22,0
        db 0FFh
