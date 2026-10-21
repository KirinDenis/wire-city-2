; ==================================================================
;  SOUND.INC - MULTIPLAY SOKO II's Sound Blaster, the WIRE CITY ring
;  mixer (EXAMPLES\RING.ASM, ENGINE\E_SND.INC): a 32K ring of 8-bit
;  samples loops forever through auto-init DMA on channel 1, 11025 a
;  second, no interrupts.  The ring's bed is the wind - its clean copy
;  in the segment's top half, which HEAL puts back behind the playing
;  position; an effect is ADDED into the ring a little ahead of it, so
;  effects sum like a real mixer and wipe themselves out once played.
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
;  GENBED - the wind: noise through a soft filter, swelling and dying
;  in one gust the length of the ring (so the loop has no seam
;  in its loudness); the clean copy beside it.
; ------------------------------------------------------------------
GENBED: push es
        mov  es,[rseg]
        xor  di,di
        xor  si,si              ; SI = the filter's state
.g:     call RND
        mov  al,ah
        cbw                     ; -128..127
        sub  ax,si
        sar  ax,1
        sar  ax,1
        sar  ax,1               ; (noise - state) / 8: a one-pole low pass
        add  si,ax
        mov  ax,di
        shl  ax,1               ; the gust: up over half the ring, down
        jns  .up                ;  over the other half (0..7FFFh)
        not  ax
.up:    mov  cl,12
        shr  ax,cl              ; 0..7
        add  ax,3               ; 3..10: the wind never quite stops
        imul si                 ; state * loudness  (DX goes)
        mov  cl,5
        sar  ax,cl
        add  al,128             ; around the midline
        stosb
        cmp  di,SNDN
        jb   .g
        push ds
        push es
        pop  ds
        xor  si,si              ; the clean copy: ring 0..7FFF -> 8000..FFFF
        mov  cx,SNDN/2
        rep  movsw
        pop  ds
        pop  es
        ret

; HEAL - behind the playing position, the ring back to the clean wind
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
        mov  di,[sbrst]
        mov  ax,di
        add  ax,cx
        and  ax,SNDN-1
        mov  [sbrst],ax
        push ds
        push es
        mov  ax,[rseg]
        mov  ds,ax
        mov  es,ax
.hc:    mov  si,di
        add  si,SNDN            ; the clean copy is the top half
        movsb
        and  di,SNDN-1
        loop .hc
        pop  es
        pop  ds
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

; BIRDS - now and then a bird sings, somewhere in the park: every 3 to
; 10 s one of three songs.  From TIMERS; nothing when the sound is off.
BIRDS:  cmp  byte [sndon],0
        je   .no
        mov  ax,[now]
        sub  ax,[birdnext]
        js   .no                ; not yet
        call RND
        mov  al,ah
        xor  ah,ah
        and  al,127
        add  ax,55              ; 3..10 s to the next
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
SF_CAW   = 12
SF_CANDY = 13
SF_SONG1 = 14                   ; three of them
SFXTAB  dw FXPUSH,FXHOME,FXOFF,FXLAY,FXTICK,FXBOOM,FXGEMUP,FXGEMGET
        dw FXGATE,FXTHUD,FXOUT,FXWIN,FXCAW,FXCANDY,FXSONG1,FXSONG2,FXSONG3
FXPUSH: TONE 3,0,900,0,0,40,0           ; the crate scrapes the stone
        TONE 1,1,500,70,55,30,0         ;  under it a low knock
        db 0FFh
FXHOME: TONE 1,0,900,1047,1047,40,25    ; home: two notes up, C and G
        TONE 1,0,1800,1568,1568,40,0
        db 0FFh
FXOFF:  TONE 1,0,900,784,784,35,20      ; off a mark: down, G to C
        TONE 1,0,1500,523,523,35,0
        db 0FFh
FXLAY:  TONE 1,0,350,300,200,45,0       ; a mine down: a clack
        TONE 2,0,300,0,0,30,0
        db 0FFh
FXTICK: TONE 1,0,160,1800,1800,30,0     ; its second
        db 0FFh
FXBOOM: TONE 3,0,9000,0,0,110,0         ; the blast
        TONE 1,1,3000,60,45,60,0
        db 0FFh
FXGEMUP:TONE 5,0,2600,700,2400,10,40    ; a diamond grows out of the floor
        TONE 5,0,1200,2400,2400,40,0
        db 0FFh
FXGEMGET:TONE 1,0,700,1047,1047,45,35   ; taken: C E G C
        TONE 1,0,700,1319,1319,45,35
        TONE 1,0,700,1568,1568,45,35
        TONE 1,0,2400,2093,2093,45,0
        db 0FFh
FXGATE: rept 9 {
        TONE 2,0,260,0,0,55,10          ; the portcullis's chain, link by link
        TONE 0,0,330,0,0,0,0 }
        TONE 1,1,5300,80,58,22,8        ;  under it the winch groans
        db 0FFh
FXTHUD: TONE 3,0,4000,0,0,100,0         ; the drawbridge lands
        TONE 1,1,3000,55,45,70,0
        db 0FFh
FXOUT:  TONE 1,0,900,784,784,45,35      ; a man out through the gate
        TONE 1,0,2000,1047,1047,45,0
        db 0FFh
FXWIN:  TONE 1,0,1300,784,784,50,45     ; the winner: a fanfare
        TONE 1,0,1300,1047,1047,50,45
        TONE 1,0,1300,1319,1319,50,45
        TONE 1,0,2600,1568,1568,50,45
        TONE 1,0,1300,1319,1319,50,45
        TONE 1,0,6500,1568,1568,50,0
        TONE 5,1,7800,392,392,30,25     ;  and a soft bass under it
        TONE 5,0,6500,523,523,30,0
        db 0FFh
FXCAW:  TONE 4,0,2400,520,380,70,10     ; a crow on the wall: kraa...
        TONE 0,0,900,0,0,0,0
        TONE 4,0,2600,500,360,65,0      ; ...kraa
        db 0FFh
FXCANDY:TONE 1,0,260,1200,1700,30,0     ; a candy eaten
        db 0FFh
FXSONG1:TONE 5,0,500,1900,2900,10,28    ; a songbird: two whistles up and a fall
        TONE 0,0,300,0,0,0,0
        TONE 5,0,500,2000,3000,10,28
        TONE 0,0,400,0,0,0,0
        TONE 5,0,1000,2900,1800,26,0
        db 0FFh
FXSONG2:rept 5 {
        TONE 5,0,260,2600,2200,24,14    ; a trill
        TONE 0,0,120,0,0,0,0 }
        TONE 5,0,700,2200,2900,22,0
        db 0FFh
FXSONG3:TONE 5,0,1400,1500,1500,8,20    ; a long note, a cuckoo's two
        TONE 0,0,700,0,0,0,0
        TONE 5,0,1700,1250,1250,20,0
        db 0FFh
