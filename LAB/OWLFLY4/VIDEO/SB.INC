; ============================================================================
;  SB.INC - Sound Blaster playback, auto-init DMA, and the clock built on it.
;
;  Included by PLAYER.ASM. It will move to ENGINE/ when a second program
;  wants it; until then it lives beside the one that does.
;
;  ------------------------------------------------------------------------
;  WHY THE SOUND CARD IS THE CLOCK
;  ------------------------------------------------------------------------
;  The DMA controller reads a ring buffer and hands bytes to the card at a
;  fixed rate, whatever the processor is doing. That rate does not drift,
;  cannot be interrupted, and is the only thing in the machine that keeps
;  real time by itself.
;
;  So the picture is pulled to it: a frame is due when the card has played
;  the samples that belong before it. Behind, drop a frame; ahead, hold one.
;  Timed the other way round - frames on a timer, sound poured after them -
;  the two drift apart within a minute and nothing afterwards can fix it.
;
;  The position is read from the DMA controller's own current-count register
;  rather than counted in the interrupt, so it is exact to the sample and
;  does not depend on interrupts arriving on time.
;
;  ------------------------------------------------------------------------
;  AUTO-INIT, AND WHY THE BUFFER IS PLACED THE WAY IT IS
;  ------------------------------------------------------------------------
;  In auto-init mode the DMA controller reloads its address and count by
;  itself at the end of the buffer, and the card interrupts at each half.
;  The program refills the half that just finished while the other plays. If
;  a refill is late the card repeats stale audio rather than stopping - a
;  click instead of silence, which is the better failure.
;
;  The 8237 cannot carry across a 64 KB physical boundary: its address
;  counter is sixteen bits and the page register is latched separately, so a
;  buffer that straddles one wraps to the start of its own page and plays
;  garbage. Twice the space is therefore allocated and a straight stretch
;  chosen inside it.
; ============================================================================

RINGSZ  = 8192                  ; the whole DMA ring
HALFSZ  = RINGSZ/2              ; refilled at each interrupt
; Audio waiting to be played, inside our own 64 KB segment: IOBUF ends at
; A000h and the stack lives at the top, so the queue takes the 16 KB between
; them. At 22 kHz that is three quarters of a second - chunks arrive every
; 83 ms and a half is drained every 186 ms, so it is a wide margin. The size
; must stay a power of two: the wrap is a mask, not a compare.
QUEUESZ = 16384
QUEUE   = 2800h

; ---------------------------------------------------------------------------
;  SBINIT - find the card, take it, start it playing silence.
;  Returns carry set if there is no card; the player then falls back to
;  timing frames from the BIOS tick counter.
; ---------------------------------------------------------------------------
SBINIT:
        call SBENV                      ; parse BLASTER
        jc   SBFAIL
        call SBRESET
        jc   SBFAIL
        call SBBUF                      ; find a stretch that does not
        jc   SBFAIL                     ; straddle a 64 KB page

        ; The time constant is what an 8-bit card actually takes, so the rate
        ; is rounded whether we like it or not. Work out what came back and
        ; use THAT for the sync arithmetic - assuming the rate we asked for
        ; is how a minute of video ends up a frame adrift.
        mov  eax,1000000
        xor  edx,edx
        movzx ecx,word [SBRATE]
        div  ecx
        mov  ecx,256
        sub  ecx,eax
        mov  [SBTC],cl
        mov  eax,1000000
        xor  edx,edx
        mov  ebx,256
        sub  ebx,ecx
        div  ebx
        mov  [SBACTUAL],eax             ; the rate the card will really run

        call SBHOOK                     ; take the interrupt vector
        call SBDMA                      ; program the 8237
        call SBSTART
        mov  byte [SBON],1
        mov  byte [SBRUN],1
        clc
        ret
SBFAIL: stc
        ret

; ---------------------------------------------------------------------------
;  BLASTER=A220 I5 D1 T4 ... - the card announces itself in the environment.
;  Nothing else is probed: poking at ports to find a card is how you hang a
;  machine that has something else at that address.
; ---------------------------------------------------------------------------
SBENV:  push es
        mov  es,[2Ch]                   ; the environment segment, from the PSP
        xor  di,di
SBE1:   cmp  byte [es:di],0             ; end of the whole block?
        je   SBENO
        ; does this entry start with BLASTER= ?
        mov  si,SBNAME
        mov  bx,di
SBE2:   lodsb
        test al,al
        jz   SBEGOT
        cmp  al,[es:bx]
        jne  SBE3
        inc  bx
        jmp  SBE2
SBE3:   ; skip to the end of this entry and try the next
SBE4:   cmp  byte [es:di],0
        je   SBE5
        inc  di
        jmp  SBE4
SBE5:   inc  di
        jmp  SBE1

SBEGOT: mov  di,bx                      ; just past "BLASTER="
        mov  word [SBBASE],0
        mov  byte [SBIRQ],0FFh
        mov  byte [SBDMACH],0FFh
SBE6:   mov  al,[es:di]
        test al,al
        jz   SBEEND
        cmp  al,'A'
        je   SBEA
        cmp  al,'a'
        je   SBEA
        cmp  al,'I'
        je   SBEI
        cmp  al,'i'
        je   SBEI
        cmp  al,'D'
        je   SBED
        cmp  al,'d'
        je   SBED
        inc  di
        jmp  SBE6
SBEA:   inc  di
        call SBHEX                      ; base port, in hex
        mov  [SBBASE],ax
        jmp  SBE6
SBEI:   inc  di
        call SBDEC
        mov  [SBIRQ],al
        jmp  SBE6
SBED:   inc  di
        call SBDEC
        mov  [SBDMACH],al
        jmp  SBE6
SBEEND: pop  es
        cmp  word [SBBASE],0
        je   SBENO2
        cmp  byte [SBIRQ],0FFh
        je   SBENO2
        cmp  byte [SBDMACH],3           ; 8-bit channels only
        ja   SBENO2
        clc
        ret
SBENO:  pop  es
SBENO2: stc
        ret

; ES:DI -> hex digits, returns AX. DI left past them.
SBHEX:  xor  ax,ax
SBH1:   mov  bl,[es:di]
        cmp  bl,'0'
        jb   SBH9
        cmp  bl,'9'
        jbe  SBH2
        and  bl,0DFh
        cmp  bl,'A'
        jb   SBH9
        cmp  bl,'F'
        ja   SBH9
        sub  bl,7
SBH2:   sub  bl,'0'
        shl  ax,4
        or   al,bl
        inc  di
        jmp  SBH1
SBH9:   ret

; ES:DI -> decimal digits, returns AL. DI left past them.
SBDEC:  xor  ax,ax
SBD1:   mov  bl,[es:di]
        cmp  bl,'0'
        jb   SBD9
        cmp  bl,'9'
        ja   SBD9
        sub  bl,'0'
        mov  cx,ax
        shl  ax,3
        add  ax,cx
        add  ax,cx                      ; ax = ax*10
        add  al,bl
        inc  di
        jmp  SBD1
SBD9:   ret

; ---------------------------------------------------------------------------
;  Reset the DSP: 1 to the reset port, hold, 0, then 0AAh comes back.
; ---------------------------------------------------------------------------
SBRESET:
        mov  dx,[SBBASE]
        add  dx,6
        mov  al,1
        out  dx,al
        mov  cx,100                     ; well over the 3 us the card wants
SBR1:   in   al,80h                     ; a port read is the classic delay:
        loop SBR1                       ; it costs an ISA cycle, whatever the
        xor  al,al                      ; processor speed
        out  dx,al

        mov  cx,1000
SBR2:   mov  dx,[SBBASE]
        add  dx,0Eh
        in   al,dx
        test al,80h
        jz   SBR3
        mov  dx,[SBBASE]
        add  dx,0Ah
        in   al,dx
        cmp  al,0AAh
        je   SBROK
SBR3:   loop SBR2
        stc
        ret
SBROK:  clc
        ret

; ---------------------------------------------------------------------------
;  A ring that does not cross a 64 KB physical boundary. Twice the space is
;  taken so that there is always a straight stretch inside it.
; ---------------------------------------------------------------------------
SBBUF:  push es
        mov  ax,cs                      ; give back everything past our 64 KB
        mov  es,ax                      ; before asking for more
        mov  ah,4Ah
        mov  bx,1000h
        int  21h

        mov  ah,48h
        mov  bx,(RINGSZ*2)/16
        int  21h
        jc   SBBNO
        mov  [SBSEG],ax

        movzx eax,ax                    ; physical address of the block
        shl  eax,4
        mov  ebx,eax
        and  ebx,0FFFFh                 ; where it sits inside its page
        add  ebx,RINGSZ
        cmp  ebx,10000h
        jbe  SBBOK                      ; fits: use it as it is
        add  eax,0FFFFh                 ; else start at the next boundary
        and  eax,0FFFF0000h
SBBOK:  mov  [SBPHYS],eax
        shr  eax,4
        mov  [SBRSEG],ax                ; the same place, for the processor
        pop  es
        clc
        ret
SBBNO:  pop  es
        stc
        ret

; ---------------------------------------------------------------------------
;  Program the 8237 for the whole ring, auto-init, memory to device.
; ---------------------------------------------------------------------------
SBDMA:  movzx bx,byte [SBDMACH]

        mov  al,4                       ; mask this channel while we set it
        or   al,bl
        out  0Ah,al

        xor  al,al                      ; clear the high/low flip-flop
        out  0Ch,al

        mov  al,58h                     ; single mode, auto-init, read
        or   al,bl
        out  0Bh,al

        mov  eax,[SBPHYS]               ; address, low sixteen bits
        mov  dx,bx
        shl  dx,1                       ; channel*2 is the address port
        out  dx,al
        mov  al,ah
        out  dx,al

        mov  eax,[SBPHYS]               ; page, bits 16..23
        shr  eax,16
        mov  si,SBPAGES
        add  si,bx
        mov  dl,[si]
        xor  dh,dh
        out  dx,al

        xor  al,al                      ; the flip-flop again, for the count
        out  0Ch,al
        mov  ax,RINGSZ-1                ; the 8237 counts one less
        mov  dx,bx
        shl  dx,1
        inc  dx                         ; channel*2+1 is the count port
        out  dx,al
        mov  al,ah
        out  dx,al

        mov  al,bl                      ; and let it run
        out  0Ah,al
        ret

; ---------------------------------------------------------------------------
;  Speaker on, rate, block size, and the auto-init command itself.
; ---------------------------------------------------------------------------
SBSTART:
        ; The ring starts as silence, because the queue is empty until the
        ; first audio chunk has been read.
        ;
        ; KNOWN, AND NOT YET FIXED: that costs about two half-buffers of
        ; silence at the head of every clip - a fifth of a second, counted in
        ; the log as underruns. Starting the card only once a whole ring of
        ; real audio was banked was tried and broke the player within the
        ; first seconds in a way that would not localise cheaply, so it was
        ; taken back out rather than left half-done. The proper fix is
        ; probably in the CONVERTER: front-load a ring's worth of audio
        ; chunks at the head of the file, the way an FMV file of the period
        ; would, and the player primes itself with no special case at all.
        push es
        mov  es,[SBRSEG]
        xor  di,di
        mov  cx,RINGSZ
        mov  al,80h                     ; unsigned 8-bit silence is the middle
        rep  stosb
        pop  es
        mov  byte [SBHALF],0

        mov  al,0D1h                    ; speaker on
        call DSPWR
        mov  al,40h                     ; sample rate, as a time constant
        call DSPWR
        mov  al,[SBTC]
        call DSPWR
        mov  al,48h                     ; block size = one half of the ring
        call DSPWR
        mov  ax,HALFSZ-1
        call DSPWR
        mov  al,ah
        call DSPWR
        mov  al,1Ch                     ; 8-bit auto-init PCM
        call DSPWR
        ret

; ---------------------------------------------------------------------------
;  Take the card's interrupt.
; ---------------------------------------------------------------------------
SBHOOK: movzx bx,byte [SBIRQ]
        mov  al,bl
        cmp  al,8
        jb   SBH2A
        add  al,68h                     ; IRQ 8..15 -> INT 70h..77h
        jmp  SBH3A
SBH2A:  add  al,8                       ; IRQ 0..7  -> INT 08h..0Fh
SBH3A:  mov  [SBVEC],al

        push es
        mov  ah,35h                     ; keep the old handler to put back
        int  21h
        mov  [SBOLDOFF],bx
        mov  [SBOLDSEG],es
        pop  es

        push ds
        mov  dx,SBIRQH
        mov  ax,cs
        mov  ds,ax
        mov  al,[SBVEC]
        mov  ah,25h
        int  21h
        pop  ds

        movzx cx,byte [SBIRQ]           ; unmask it in the interrupt controller
        cmp  cl,8
        jb   SBHM1
        sub  cl,8
        in   al,0A1h
        mov  bl,1
        shl  bl,cl
        not  bl
        and  al,bl
        out  0A1h,al
        in   al,21h                     ; and let the cascade through
        and  al,0FBh
        out  21h,al
        ret
SBHM1:  in   al,21h
        mov  bl,1
        shl  bl,cl
        not  bl
        and  al,bl
        out  21h,al
        ret

; ---------------------------------------------------------------------------
;  The interrupt: refill the half that has just been played.
;
;  It runs with the segment registers of whatever it interrupted, so it sets
;  up its own DS and touches nothing else. In particular it does not go near
;  FS: the main program keeps a 4 GB limit cached there and a handler that
;  reloaded it would take that away at random.
; ---------------------------------------------------------------------------
SBIRQH: push ax
        push bx
        push cx
        push dx
        push si
        push di
        push ds
        push es
        mov  ax,cs
        mov  ds,ax

        mov  es,[SBRSEG]
        xor  di,di
        cmp  byte [SBHALF],0
        je   SBI1
        mov  di,HALFSZ
SBI1:   xor  byte [SBHALF],1

        ; pour HALFSZ bytes out of the queue, or silence if it has run dry
        mov  cx,HALFSZ
SBI2:   mov  ax,[QHEAD]
        cmp  ax,[QTAIL]
        je   SBI3                       ; empty
        mov  si,ax
        mov  al,[si+QUEUE]
        mov  [es:di],al
        inc  di
        inc  word [QHEAD]
        and  word [QHEAD],QUEUESZ-1
        dec  cx
        jnz  SBI2
        jmp  SBI4
SBI3:   mov  al,80h                     ; nothing to play: silence
        mov  [es:di],al
        inc  di
        cmp  byte [SBDRAINF],1          ; ...which is the POINT during the
        je   SBI3A                      ; drain, so do not count it there or
        inc  word [SBUNDER]             ; the number stops meaning anything
SBI3A:  dec  cx
        jnz  SBI2

SBI4:   mov  dx,[SBBASE]                ; acknowledge the card: reading this
        add  dx,0Eh                     ; port is what clears its interrupt
        in   al,dx

        mov  al,20h                     ; and the interrupt controller
        cmp  byte [SBIRQ],8
        jb   SBI5
        out  0A0h,al
SBI5:   out  20h,al

        pop  es
        pop  ds
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        iret

; ---------------------------------------------------------------------------
;  SBFEED - hand CX bytes at FS:ESI to the queue. Anything that does not fit
;  is dropped: a queue that blocks would stall the picture, and audio that
;  arrives late is of no use anyway.
; ---------------------------------------------------------------------------
SBFEED: cmp  byte [SBON],1
        jne  SBFDONE
        push ax
        push bx
        push cx
        push di
SBF1:   test cx,cx
        jz   SBF9
        mov  ax,[QTAIL]
        inc  ax
        and  ax,QUEUESZ-1
        cmp  ax,[QHEAD]
        je   SBF9                       ; full - drop the rest
        mov  di,[QTAIL]
        mov  bl,[fs:esi]
        mov  [di+QUEUE],bl
        inc  esi
        mov  [QTAIL],ax
        dec  cx
        jmp  SBF1
SBF9:   ; Whatever is left in CX did not fit and has been thrown away. Worth
        ; counting: dropped audio is a discontinuity, and a discontinuity in
        ; eight-bit sound is a click, not a gap.
        add  [SBDROP],cx
        pop  di
        pop  cx
        pop  bx
        pop  ax
SBFDONE:
        ret

; ---------------------------------------------------------------------------
;  SBPOS - how many samples the card has played, in EAX.
;
;  Read from the DMA controller's own count rather than counted in the
;  interrupt handler, so it is exact and does not care whether interrupts
;  are arriving on time. The wrap is spotted by the position going backwards,
;  which is safe as long as this is called more than once per ring - it is
;  called once a frame, and a frame is a quarter of a ring.
; ---------------------------------------------------------------------------
SBPOS:  push ebx
        push ecx
        push edx
        movzx bx,byte [SBDMACH]
        pushf
        cli                             ; the two halves of the count must
        xor  al,al                      ; come from the same instant
        out  0Ch,al
        mov  dx,bx
        shl  dx,1
        inc  dx
        in   al,dx
        mov  cl,al
        in   al,dx
        mov  ch,al
        popf
        movzx ecx,cx                    ; counts DOWN from RINGSZ-1
        mov  eax,RINGSZ-1
        sub  eax,ecx                    ; -> position within the ring

        ; A REAL wrap drops the position by most of the ring. Anything
        ; smaller going backwards is the count being read mid-update, and
        ; counting those as wraps made the clock run 1.6 times too fast -
        ; the picture finished a thirty-second clip in eighteen seconds
        ; while the sound was still playing. So: big drops only, and a small
        ; dip holds the last position rather than moving backwards. The
        ; clock this hands out never goes down.
        mov  ecx,[SBLAST]
        cmp  eax,ecx
        jae  SBPKEEP
        mov  ebx,ecx
        sub  ebx,eax
        cmp  ebx,RINGSZ/2
        jae  SBPWRAP
        mov  eax,ecx                    ; a stutter in the read: hold still
        jmp  SBPOUT
SBPWRAP:
        inc  dword [SBWRAPS]
SBPKEEP:
        mov  [SBLAST],eax
SBPOUT: mov  ecx,[SBWRAPS]
        imul ecx,RINGSZ
        add  eax,ecx
        pop  edx
        pop  ecx
        pop  ebx
        ret

; ---------------------------------------------------------------------------
;  SBDRAIN - let the sound finish before the machine is taken back.
;
;  The audio runs a whole ring behind the picture: the card began on the
;  silence it was handed, so the last third of a second of a clip is still
;  sitting in the queue when the last frame has been shown. Halting there
;  cuts the tail off mid-word and leaves the DAC holding whatever level it
;  had - a click, and before it, the end of the sentence missing.
;
;  So: wait for the queue to empty, then for one more ring to pass. By then
;  the handler has been pouring silence for a while and the card stops on
;  silence, which is what a clean ending sounds like.
;
;  Bounded, because a card that has stopped interrupting must not be able to
;  hang the program that is trying to put it away.
; ---------------------------------------------------------------------------
SBDRAIN:
        cmp  byte [SBRUN],1
        jne  SBDRD
        mov  byte [SBDRAINF],1
        call SBPOS
        mov  ebx,eax
        add  ebx,RINGSZ*4               ; the longest we will ever wait
SBDR1:  mov  ax,[QHEAD]
        cmp  ax,[QTAIL]
        je   SBDR2
        call SBPOS
        cmp  eax,ebx
        jb   SBDR1
        jmp  SBDRD                      ; it stopped moving: stop anyway
SBDR2:  call SBPOS                      ; queue empty - now play the ring out
        mov  ebx,eax
        add  ebx,RINGSZ
SBDR3:  call SBPOS
        cmp  eax,ebx
        jb   SBDR3
SBDRD:  ret

; ---------------------------------------------------------------------------
;  SBSTOP - give the machine back exactly as it was found.
; ---------------------------------------------------------------------------
SBSTOP: cmp  byte [SBON],1
        jne  SBSDONE
        cmp  byte [SBRUN],1             ; never started: nothing to halt, but
        jne  SBSVEC                     ; the vector still has to go back
        mov  al,0D0h                    ; halt the DMA transfer
        call DSPWR
        mov  al,0DAh                    ; and leave auto-init mode
        call DSPWR
        mov  al,0D3h                    ; speaker off
        call DSPWR

SBSVEC: movzx bx,byte [SBDMACH]         ; mask the channel again
        mov  al,4
        or   al,bl
        out  0Ah,al

        ; Everything this needs is read BEFORE DS is changed. Setting a
        ; vector wants DS:DX pointing at the handler, so DS stops being ours
        ; for the length of the call - and a [SBVEC] read after that point
        ; fetches a byte out of somebody else's segment and hands INT 21h a
        ; random interrupt number to overwrite.
        mov  cl,[SBVEC]
        mov  dx,[SBOLDOFF]
        mov  bx,[SBOLDSEG]
        push ds
        mov  ds,bx
        mov  al,cl
        mov  ah,25h
        int  21h
        pop  ds
        mov  byte [SBON],0
        mov  byte [SBRUN],0
SBSDONE:
        ret

; ---------------------------------------------------------------------------
;  Write AL to the DSP, once it says it is ready for it.
; ---------------------------------------------------------------------------
DSPWR:  push bx
        push dx
        mov  bl,al
        mov  dx,[SBBASE]
        add  dx,0Ch
        mov  cx,0FFFFh
DW1:    in   al,dx
        test al,80h
        jz   DW2
        loop DW1
DW2:    mov  al,bl
        out  dx,al
        pop  dx
        pop  bx
        ret

; ---------------------------------------------------------------------------
SBNAME   db 'BLASTER=',0
SBPAGES  db 87h,83h,81h,82h             ; page register per DMA channel

SBON     db 0                            ; a card was found and taken
SBRUN    db 0                            ; ...and is actually playing
SBBASE   dw 0
SBIRQ    db 0FFh
SBDMACH  db 0FFh
SBVEC    db 0
SBTC     db 0
SBRATE   dw 22050                       ; asked for; the header overwrites it
SBACTUAL dd 22050                       ; what the time constant really gives
SBSEG    dw 0                           ; what DOS gave us
SBRSEG   dw 0                           ; the ring, as a segment
SBPHYS   dd 0                           ; the ring, as a physical address
SBHALF   db 0
SBUNDER  dw 0                           ; bytes of silence poured in when dry
SBDROP   dw 0                           ; bytes thrown away when the queue was full
SBDRAINF db 0                           ; playing the tail out on purpose
SBLAST   dd 0
SBWRAPS  dd 0
SBOLDOFF dw 0
SBOLDSEG dw 0
QHEAD    dw 0                           ; the interrupt reads here
QTAIL    dw 0                           ; the main loop writes here
