; ============================================================================
;  PLAYER.ASM - play an OWV file at 640x400, 256 colours, in DOS.
;
;      PLAYER              plays TEST2.OWV
;      PLAYER SOME.OWV     plays that instead
;
;      ESC                 stop
;
;  Every run writes PLAYER.LOG: where it got to, where the time went, and
;  how far the picture drifted from the sound. Five lines for a whole clip.
;
;  ------------------------------------------------------------------------
;  THE SOUND CARD IS THE CLOCK
;  ------------------------------------------------------------------------
;  The DMA controller hands bytes to the card at a rate that does not drift
;  and cannot be interrupted; nothing else in the machine keeps real time by
;  itself. So a frame is due when the samples that belong before it have been
;  played - behind, the loop does not wait; ahead, it does. Sound is never
;  stretched to meet the picture. See SB.INC.
;
;  Without a card the player still runs, pacing itself from the BIOS tick.
;
;  ------------------------------------------------------------------------
;  THE SEGMENT DISCIPLINE, WHICH IS THE WHOLE DIFFICULTY OF THIS PROGRAM
;  ------------------------------------------------------------------------
;  Unreal mode is not a mode. It is a side effect: enter protected mode for
;  the length of two instructions, load a segment register with a descriptor
;  whose limit is 4 GB, leave again, and the processor keeps the cached limit
;  because nothing in real mode reloads it. From then on that ONE register
;  addresses the whole machine with a 32-bit offset.
;
;  "That one register" is the discipline, and it is FS.
;
;  FS and GS did not exist on the 8086, so no DOS service and no BIOS routine
;  has any reason to touch them. Every other segment register is fair game to
;  code that is not ours, and the moment anything loads one in real mode, its
;  cached limit falls back to 64 KB - and a 32-bit offset through it stops
;  meaning what it meant.
;
;  An earlier version of this file made ES flat as well, so that the bulk
;  moves could be REP MOVS. It drew the right picture and DOSBox filled its
;  log with "Illegal read"/"Illegal write" pairs at CS:IP f000:11c4 - inside
;  the BIOS, from an interrupt that arrived while ES was flat and was never
;  built to expect it. It also cost about twelve seconds a frame, all of it
;  spent printing those complaints.
;
;  So: no REP MOVS across the big buffers, because REP MOVS insists on ES.
;  The copies below go through FS by hand, four bytes at a time, unrolled.
;  That is the price of the rule, and it is a small one.
;
;  The second half of the rule: NO BIOS OR DOS CALL IN THE FRAME LOOP that
;  can be avoided. The frame delay used to be INT 15h AH=86h - a BIOS routine
;  called once per picture. It is now a wait on the BIOS tick counter read
;  directly out of the BIOS data area, which calls nothing at all.
;
;  ------------------------------------------------------------------------
;  MEMORY, AND A SHORTCUT THAT IS DELIBERATE
;  ------------------------------------------------------------------------
;  The big buffers sit at fixed addresses above 1 MB and are simply taken,
;  not allocated: no XMS handle is asked for. That is safe here because these
;  batch files start DOSBox with -noautoexec, so no memory manager is loaded
;  and nothing else owns that memory. It is NOT safe on a machine with HIMEM,
;  and it is the first thing to fix when this becomes part of a game.
;
;  The picture is assembled in system memory and blitted whole. Building it
;  in video memory instead would mean reading video memory back for every
;  skipped block, and reading from a graphics card is slow in a way that
;  writing to it is not.
;
;  NB deliberately NOT an 8086 program: E_8086.INC must not be included.
; ============================================================================

format binary as 'com'
        org 100h

; ---- the frame ------------------------------------------------------------
WIDTH   = 640
HEIGHT  = 400
PLANE   = WIDTH*HEIGHT          ; 256000
BLOCK   = 8
BLKW    = WIDTH/BLOCK           ; 80 blocks across
BLKH    = HEIGHT/BLOCK          ; 50 blocks down
BLKROW  = WIDTH*BLOCK           ; 5120 bytes per block row

; ---- linear addresses, taken outright -------------------------------------
BUFLIN  = 200000h               ; the chunk payload being decoded
FRAMEA  = 300000h               ; two frames, swapped every picture
FRAMEB  = 340000h
SCRLIN  = 380000h               ; 64 bytes, one block being unpacked

; ---- chunk types ----------------------------------------------------------
CH_KEY     = 01h
CH_DELTA   = 02h
CH_AUDIO   = 03h
CH_PALETTE = 04h
CH_END     = 0FFh

; ---- block opcodes --------------------------------------------------------
OP_FILL    = 80h
OP_LIT     = 81h
OP_COPY    = 82h
OP_RLE     = 83h
OP_ENDF    = 0FFh

; ---- conventional memory, inside this 64 KB segment -----------------------
;
;  0100  code and data, growing upwards
;  2000  HDRBUF   800 bytes    the file header, palette included
;  2400  MODEBUF  256 bytes    what VESA says about mode 100h
;  2800  QUEUE    16 KB        audio waiting for the interrupt (see SB.INC)
;  6800  IOBUF    32 KB        where DOS reads land before going above 1 MB
;  E800  ...      6 KB         the stack, growing down from FFFE
;
;  These used to start at 1000h, which was comfortable until the sound code
;  pushed the program past 4 KB and it began writing over its own header
;  buffer - the palette turned to noise and the log filled with PCM. The
;  assertion at the very bottom of this file makes that a build error now
;  instead of a puzzle.
HDRBUF  = 2000h
MODEBUF = 2400h
IOBUF   = 6800h
IOSIZE  = 8000h

; The BIOS tick counter runs at 1193182/65536 Hz. Ticks per frame in 16.16
; fixed point is therefore 1193182/fps exactly - no constant to round.
TICKHZ  = 1193182

START:  cld
        mov  sp,0FFFEh

        ; The linear address of IOBUF. DOS can only read into conventional
        ; memory, so the file lands here first and is carried up - and the
        ; carrying is done through FS, which wants a flat address.
        xor  eax,eax
        mov  ax,ds
        shl  eax,4
        add  eax,IOBUF
        mov  [IOBUFLIN],eax

        ; PLAYER.LOG is written every run - five lines for the whole
        ; programme, not five a frame. A switch to turn it on was tried and
        ; twice failed to reach the program through two layers of batch file,
        ; which wasted more time than the log will ever cost.
        mov  ah,41h                     ; start it fresh
        mov  dx,LOGNAME
        int  21h

; ---------------------------------------------------------------------------
;  The file name: the first word of the command line, or TEST2.OWV.
; ---------------------------------------------------------------------------
        mov  si,81h
        movzx cx,byte [80h]
        mov  di,FNAME
        jcxz  DEFNAME
SKIPSP: lodsb
        cmp  al,' '
        jne  GOTNAME
        loop SKIPSP
        jmp  DEFNAME
GOTNAME:
        cmp  al,'/'                     ; a switch, not a name
        je   DEFNAME
        stosb
        dec  cx
        jz   ENDNAME
CPNAME: lodsb
        cmp  al,' '
        je   ENDNAME
        cmp  al,13
        je   ENDNAME
        stosb
        loop CPNAME
ENDNAME:
        xor  al,al
        stosb
        jmp  OPENIT
DEFNAME:
        mov  si,DEFAULTN
        mov  di,FNAME
DN1:    lodsb
        stosb
        test al,al
        jnz  DN1

; ---------------------------------------------------------------------------
;  Open it and read the 800-byte header.
; ---------------------------------------------------------------------------
OPENIT:
        mov  ax,3D00h
        mov  dx,FNAME
        int  21h
        jc   NOFILE
        mov  [FH],ax

        mov  bx,[FH]
        mov  cx,800
        mov  dx,HDRBUF
        mov  ah,3Fh
        int  21h
        jc   BADFILE
        cmp  ax,800
        jne  BADFILE
        cmp  dword [HDRBUF],'OWV1'
        jne  BADFILE
        mov  ax,[HDRBUF+4]
        cmp  ax,WIDTH
        jne  BADSIZE
        mov  ax,[HDRBUF+6]
        cmp  ax,HEIGHT
        jne  BADSIZE

        ; ticks per frame, 16.16
        movzx ecx,byte [HDRBUF+8]
        test ecx,ecx
        jnz  FPSOK
        jmp  BADFILE
FPSOK:  mov  [FPSD],ecx

        ; The sound card, if the file has audio and the machine has a card.
        ; Without one the player still runs - it just falls back to timing
        ; frames from the BIOS tick, which is what it did before there was
        ; any sound at all.
        test byte [HDRBUF+9],1
        jz   NOSOUND
        mov  ax,[HDRBUF+12]
        mov  [SBRATE],ax
        call SBINIT
        jc   NOSOUND

        mov  dx,MKSOUND
        call LOGMARK
        jmp  SNDREADY
NOSOUND:
        mov  dx,MKNOSND
        call LOGMARK
SNDREADY:
        mov  dx,MK1
        call LOGMARK

; ---------------------------------------------------------------------------
;  Unreal mode - FS only. ES is left alone on purpose; see the note at the
;  top of this file for what happened when it was not.
; ---------------------------------------------------------------------------
        mov  ax,2401h                   ; A20, or everything above 1 MB
        int  15h                        ; folds onto the first 64 KB

        xor  eax,eax
        mov  ax,cs
        shl  eax,4
        add  eax,GDT
        mov  dword [GDTR+2],eax
        lgdt [GDTR]
        mov  byte [FLATOK],1
        call REFLAT

        mov  dx,MK1B
        call LOGMARK

        ; Prove it before building anything on top of the assumption.
        mov  edi,BUFLIN
        mov  byte [fs:edi],5Ah
        cmp  byte [fs:edi],5Ah
        jne  NOUNREAL
        mov  dx,MK2
        call LOGMARK

; ---------------------------------------------------------------------------
;  Mode 100h with the linear framebuffer.
; ---------------------------------------------------------------------------
        push ds
        pop  ax
        mov  es,ax                      ; VBE wants ES:DI - an ordinary
        mov  di,MODEBUF                 ; real-mode ES, which is all it ever
        mov  cx,100h                    ; is in this program
        mov  ax,4F01h
        int  10h
        cmp  ax,004Fh
        jne  NOMODE
        mov  eax,[MODEBUF+28h]
        mov  [LFB],eax
        movzx eax,word [MODEBUF+10h]
        mov  [PITCH],eax

        mov  ax,4F02h
        mov  bx,4100h                   ; 640x400x256, linear
        int  10h
        cmp  ax,004Fh
        jne  NOMODE
        mov  byte [INGFX],1
        call REFLAT

        call SETPAL
        call REFLAT

        mov  dword [PFRAME],FRAMEA
        mov  dword [CFRAME],FRAMEB
        call TICK
        mov  [TICKBASE],eax

        mov  dx,MK3
        call LOGMARK

; ===========================================================================
;  The chunk loop
; ===========================================================================
NEXTCHUNK:
        mov  bx,[FH]
        mov  cx,6
        mov  dx,CHDR
        mov  ah,3Fh
        int  21h
        ; The flag tests come BEFORE the refresh: REFLAT compares, pushes and
        ; pops, and every one of those writes the flags the carry test needs.
        jc   FINISH
        cmp  ax,6
        jne  FINISH
        call REFLAT

        mov  al,[CHDR]
        mov  ecx,dword [CHDR+2]         ; payload length

        cmp  al,CH_END
        je   FINISH
        cmp  al,CH_AUDIO
        je   DOAUDIO
        cmp  al,CH_PALETTE
        je   DOPAL
        cmp  al,CH_KEY
        je   DOKEY
        cmp  al,CH_DELTA
        je   DODELTA
        jmp  SKIPPAY                    ; unknown: step over it

; ---- audio: into the queue the interrupt drains ---------------------------
DOAUDIO:
        cmp  byte [SBON],1
        jne  SKIPPAY                    ; no card: step over it
        call READPAY                    ; ECX survives - the byte count
        mov  esi,BUFLIN
        call SBFEED
        jmp  NEXTCHUNK

; ---- anything unknown: read past it ---------------------------------------
SKIPPAY:
        mov  bx,[FH]
        mov  ax,4201h                   ; seek from current position
        mov  dx,cx
        shr  ecx,16
        int  21h
        call REFLAT
        jmp  NEXTCHUNK

; ---- palette --------------------------------------------------------------
DOPAL:  call READPAY
        mov  esi,BUFLIN
        movzx edx,byte [fs:esi]
        inc  esi
        movzx ecx,byte [fs:esi]
        inc  esi
        inc  ecx
        mov  ax,dx
        mov  dx,3C8h
        out  dx,al
        mov  dx,3C9h
PALLOOP:
        mov  al,[fs:esi]
        out  dx,al
        inc  esi
        mov  al,[fs:esi]
        out  dx,al
        inc  esi
        mov  al,[fs:esi]
        out  dx,al
        inc  esi
        dec  ecx
        jnz  PALLOOP
        jmp  NEXTCHUNK

; ---- a whole frame, RLE ---------------------------------------------------
DOKEY:  call TICKIN
        call READPAY
        call TICKOUT
        add  [ACCREAD],eax

        call TICKIN
        mov  esi,BUFLIN
        mov  edi,[CFRAME]
        mov  ecx,PLANE
        call RLEOUT
        call TICKOUT
        add  [ACCBLK],eax
        jmp  SHOWFRAME

; ---- a frame as changes ---------------------------------------------------
DODELTA:
        call TICKIN
        call READPAY                    ; ECX survives it: the payload length
        call TICKOUT
        add  [ACCREAD],eax

        mov  eax,BUFLIN
        add  eax,ecx
        mov  [BUFEND],eax

        mov  esi,BUFLIN
        movsx eax,byte [fs:esi]
        mov  [GDX],eax
        inc  esi
        movsx eax,byte [fs:esi]
        mov  [GDY],eax
        inc  esi
        mov  [SRC],esi

        call TICKIN
        call SHIFTFRAME
        call TICKOUT
        add  [ACCSHIFT],eax

        call TICKIN
        mov  dword [BLKX],0
        mov  dword [ROWBASE],0
        mov  esi,[SRC]

        ; Two fences. A decoder reading a file it did not write must STOP on
        ; nonsense rather than wander: without these a single bad byte turns
        ; into a hang that has to be killed from outside.
BLKLOOP:
        cmp  esi,[BUFEND]
        jae  BLKDONE
        cmp  dword [ROWBASE],PLANE
        jae  BLKDONE
        mov  al,[fs:esi]
        inc  esi
        cmp  al,OP_ENDF
        je   BLKDONE
        test al,80h
        jnz  BLKOP
        movzx ecx,al                    ; skip (al+1) blocks
        inc  ecx
        call ADVANCE
        jmp  BLKLOOP

BLKOP:  cmp  al,OP_FILL
        je   BFILL
        cmp  al,OP_LIT
        je   BLIT
        cmp  al,OP_COPY
        je   BCOPY
        cmp  al,OP_RLE
        je   BRLE
        jmp  BLKDONE                    ; nonsense: stop, do not scribble

BFILL:  mov  al,[fs:esi]
        inc  esi
        call BLOCKADDR                  ; -> edi
        mov  ah,al
        push ax
        shl  eax,16
        pop  ax                         ; the byte, four times over
        mov  ecx,BLOCK
BF1:    mov  [fs:edi],eax
        mov  [fs:edi+4],eax
        add  edi,WIDTH
        dec  ecx
        jnz  BF1
        mov  ecx,1
        call ADVANCE
        jmp  BLKLOOP

BLIT:   call BLOCKADDR
        mov  ecx,BLOCK
BL1:    mov  eax,[fs:esi]
        mov  [fs:edi],eax
        mov  eax,[fs:esi+4]
        mov  [fs:edi+4],eax
        add  esi,BLOCK
        add  edi,WIDTH
        dec  ecx
        jnz  BL1
        mov  ecx,1
        call ADVANCE
        jmp  BLKLOOP

BCOPY:  movsx eax,byte [fs:esi]
        inc  esi
        movsx ebx,byte [fs:esi]
        inc  esi
        push esi
        call BLOCKADDR                  ; edi = where it goes, in CFRAME
        mov  esi,edi                    ; the same place in the frame before,
        sub  esi,[CFRAME]               ; moved by (eax, ebx) pixels
        add  esi,[PFRAME]
        imul ebx,WIDTH
        add  esi,ebx
        add  esi,eax
        mov  ecx,BLOCK
BC1:    mov  eax,[fs:esi]
        mov  [fs:edi],eax
        mov  eax,[fs:esi+4]
        mov  [fs:edi+4],eax
        add  esi,WIDTH
        add  edi,WIDTH
        dec  ecx
        jnz  BC1
        pop  esi
        mov  ecx,1
        call ADVANCE
        jmp  BLKLOOP

BRLE:   inc  esi                        ; the coded length is in the stream
        inc  esi                        ; but not needed: RLEOUT counts what
        call BLOCKADDR                  ; it produces, not what it consumes
        ; The address goes on the STACK, not in EBX: RLEOUT uses EBX for its
        ; run counter. Holding it there cost an afternoon - the block landed
        ; at a wild address and scribbled over the opcode stream being read.
        push edi
        mov  edi,SCRLIN
        mov  ecx,BLOCK*BLOCK
        call RLEOUT                     ; leaves esi past the coded bytes
        pop  ebx
        push esi
        mov  esi,SCRLIN
        mov  edi,ebx
        mov  ecx,BLOCK
BR1:    mov  eax,[fs:esi]
        mov  [fs:edi],eax
        mov  eax,[fs:esi+4]
        mov  [fs:edi+4],eax
        add  esi,BLOCK
        add  edi,WIDTH
        dec  ecx
        jnz  BR1
        pop  esi
        mov  ecx,1
        call ADVANCE
        jmp  BLKLOOP

BLKDONE:
        call TICKOUT
        add  [ACCBLK],eax

; ---------------------------------------------------------------------------
;  Show it: blit, swap, wait for this frame's turn, look for ESC.
; ---------------------------------------------------------------------------
SHOWFRAME:
        call TICKIN
        mov  esi,[CFRAME]
        mov  edi,[LFB]
        mov  ecx,PLANE/4
        call COPYD
        call TICKOUT
        add  [ACCBLIT],eax

        mov  eax,[PFRAME]
        mov  ebx,[CFRAME]
        mov  [CFRAME],eax
        mov  [PFRAME],ebx

        ; ------------------------------------------------------------------
        ;  When this frame is due.
        ;
        ;  With a card, the answer comes from the card: the DMA controller
        ;  hands bytes over at a rate that does not drift, and a frame is due
        ;  when the samples that belong before it have been played. Behind,
        ;  the next frame arrives late and the loop simply does not wait;
        ;  ahead, it waits. Sound never stretches to meet the picture, which
        ;  is the whole reason for doing it this way round.
        ;
        ;  Without a card, the BIOS tick counter, read straight out of the
        ;  BIOS data area so the frame loop still calls nothing.
        ; ------------------------------------------------------------------
        ; The target is computed from the FRAME NUMBER every time, never
        ; accumulated. An accumulator in 16.16 held about thirty-five frames
        ; of a 22 kHz clip before it overflowed thirty-two bits, and after
        ; that the due time wrapped to nothing and the player stopped waiting
        ; at all - three seconds in, on a thirty-second clip. MUL gives a
        ; sixty-four bit product for DIV to work on, so nothing overflows
        ; until the clip is days long.
        inc  dword [FRAMENO]

        ; A mark every five seconds. Six lines for a thirty-second clip, and
        ; the difference between "it stops somewhere" and "it stops HERE".
        mov  eax,[FRAMENO]
        xor  edx,edx
        mov  ecx,60
        div  ecx
        test edx,edx
        jnz  NOBEAT
        mov  eax,[FRAMENO]
        mov  di,BEATNO
        call HEX32TO
        mov  dx,MKBEAT
        call LOGMARK
NOBEAT:
        cmp  byte [SBRUN],1             ; playing yet? the card starts a few
        jne  WAITTICK                   ; frames in, once its ring is full

        ; The sample clock is re-based at the frame sound actually began, so
        ; the frames paced by the tick before that are not counted against a
        ; card which had not played a byte of them.
        cmp  byte [BASED],1
        je   WS1
        mov  byte [BASED],1
        mov  eax,[FRAMENO]
        mov  [BASEFRAME],eax
WS1:    mov  eax,[FRAMENO]
        sub  eax,[BASEFRAME]
        mul  dword [SBACTUAL]           ; edx:eax = frames * samples a second
        div  dword [FPSD]               ; -> samples that belong before this one
        mov  [WANTED],eax
        mov  ebx,eax
WAITS:  call SBPOS
        cmp  eax,ebx
        jb   WAITS
        jmp  WAITDONE

WAITTICK:
        mov  eax,[FRAMENO]
        mov  edx,TICKHZ
        mul  edx
        div  dword [FPSD]
        mov  [WANTED],eax
        add  eax,[TICKBASE]
        mov  ebx,eax
WAITT:  call TICK
        cmp  eax,ebx
        jb   WAITT
WAITDONE:

        mov  ah,1
        int  16h
        jz   NOKEY
        xor  ah,ah
        int  16h
        cmp  al,27
        je   FINISH
NOKEY:  call REFLAT
        jmp  NEXTCHUNK

        ; How long this actually took, measured INSIDE the machine. A
        ; stopwatch on the host counts DOSBox starting up and, if a batch
        ; forgets to close it, an idle emulator as well - which is how a
        ; six-second clip once looked like two minutes.
FINISH: call SBDRAIN                    ; the sound is a ring behind the
        mov  dx,MKFIN                   ; picture - let it finish the sentence
        call LOGMARK
        call TICK
        sub  eax,[TICKBASE]
        mov  di,TIMELAP
        call HEX32TO

        cmp  byte [SBON],1              ; the clock's own numbers, before the
        jne  FIN1                       ; card is handed back
        call SBPOS
        mov  di,TIMPLAY
        call HEX32TO
FIN1:   mov  eax,[SBWRAPS]
        mov  di,TIMWRAP
        call HEX32TO
        mov  eax,[SBLAST]
        mov  di,TIMPOS
        call HEX32TO
        mov  eax,[WANTED]
        mov  di,TIMWANT
        call HEX32TO

        call SBSTOP                     ; hand the machine back before anything
        call TEXTMODE                   ; else, interrupt vector included
        mov  ax,[SBUNDER]
        mov  di,TIMUNDER
        call HEX16TO
        mov  ax,[SBDROP]
        mov  di,TIMDROP
        call HEX16TO
        mov  eax,[ACCREAD]
        mov  di,TIMREAD
        call HEX32TO
        mov  eax,[ACCSHIFT]
        mov  di,TIMSHIFT
        call HEX32TO
        mov  eax,[ACCBLK]
        mov  di,TIMBLK
        call HEX32TO
        mov  eax,[ACCBLIT]
        mov  di,TIMBLIT
        call HEX32TO
        mov  dx,TIMLINE
        call LOGMARK

        mov  bx,[FH]
        mov  ah,3Eh
        int  21h
        mov  dx,MSGDONE
        call PUTS
        mov  ax,4C00h
        int  21h

; ===========================================================================
;  Bulk memory, all of it through FS
;
;  REP MOVS would be shorter and, on real hardware, faster - but it writes
;  through ES, and ES may not be flat in this program. Four bytes a step,
;  unrolled four ways, is what the rule leaves; it is fast enough that the
;  blit of a whole 640x400 frame does not show up against a frame time.
; ===========================================================================

; ECX dwords from FS:ESI to FS:EDI.
COPYD:  push eax
        push ecx
        shr  ecx,2
        jz   CD2
CD1:    mov  eax,[fs:esi]
        mov  [fs:edi],eax
        mov  eax,[fs:esi+4]
        mov  [fs:edi+4],eax
        mov  eax,[fs:esi+8]
        mov  [fs:edi+8],eax
        mov  eax,[fs:esi+12]
        mov  [fs:edi+12],eax
        add  esi,16
        add  edi,16
        dec  ecx
        jnz  CD1
CD2:    pop  ecx
        and  ecx,3
        jz   CD4
CD3:    mov  eax,[fs:esi]
        mov  [fs:edi],eax
        add  esi,4
        add  edi,4
        dec  ecx
        jnz  CD3
CD4:    pop  eax
        ret

; ECX dwords of EAX at FS:EDI.
FILLD:  push ecx
        shr  ecx,2
        jz   FD2
FD1:    mov  [fs:edi],eax
        mov  [fs:edi+4],eax
        mov  [fs:edi+8],eax
        mov  [fs:edi+12],eax
        add  edi,16
        dec  ecx
        jnz  FD1
FD2:    pop  ecx
        and  ecx,3
        jz   FD4
FD3:    mov  [fs:edi],eax
        add  edi,4
        dec  ecx
        jnz  FD3
FD4:    ret

; ECX bytes from FS:ESI to FS:EDI.
;
; Four at a time, and NO alignment check: x86 permits an unaligned dword
; access, and inside an emulator it costs exactly what an aligned one costs.
; The byte-at-a-time version this replaces was the single most expensive
; thing in the player - the frame shift alone spent 54 ms a picture in it.
COPYB:  push eax
        push ecx
        shr  ecx,2
        jz   CB2
CB1:    mov  eax,[fs:esi]
        mov  [fs:edi],eax
        add  esi,4
        add  edi,4
        dec  ecx
        jnz  CB1
CB2:    pop  ecx
        and  ecx,3
        jz   CB4
CB3:    mov  al,[fs:esi]
        mov  [fs:edi],al
        inc  esi
        inc  edi
        dec  ecx
        jnz  CB3
CB4:    pop  eax
        ret

; ===========================================================================
;  Workers
; ===========================================================================

; Read ECX bytes of payload from the file to BUFLIN. DOS cannot write above
; 1 MB, so it lands in a 32 KB conventional buffer and is carried up.
READPAY:
        push eax
        push ebx
        push ecx
        push edx
        push esi
        push edi
        mov  edi,BUFLIN
RP1:    test ecx,ecx
        jz   RPDONE
        mov  eax,ecx
        cmp  eax,IOSIZE
        jbe  RP2
        mov  eax,IOSIZE
RP2:    push ecx                        ; total still wanted
        mov  bx,[FH]
        mov  cx,ax
        mov  dx,IOBUF
        mov  ah,3Fh
        int  21h
        call REFLAT                     ; DOS has just had the segments
        movzx eax,ax                    ; how many actually arrived
        push eax
        mov  esi,[IOBUFLIN]
        mov  ecx,eax
        call COPYB
        pop  eax
        pop  ecx
        sub  ecx,eax
        test eax,eax
        jnz  RP1
RPDONE: pop  edi
        pop  esi
        pop  edx
        pop  ecx
        pop  ebx
        pop  eax
        ret

; RLE: FS:ESI in, FS:EDI out, ECX bytes to produce. A lead byte under 80h is
; a literal run of n+1; at or above, a repeat of (n-7Fh). One bit tested and
; one mask - no table and no branch tree.
RLEOUT:
        test ecx,ecx
        jz   RLDONE
        mov  al,[fs:esi]
        inc  esi
        test al,80h
        jnz  RLREP
        movzx ebx,al
        inc  ebx
        cmp  ebx,ecx                    ; never write past what was asked for
        jbe  RLL1
        mov  ebx,ecx
RLL1:   sub  ecx,ebx
        push ecx
        mov  ecx,ebx
        call COPYB
        pop  ecx
        jmp  RLEOUT
RLREP:  sub  al,7Fh
        movzx ebx,al
        mov  ah,[fs:esi]                ; the byte to repeat
        inc  esi
        cmp  ebx,ecx
        jbe  RLR1
        mov  ebx,ecx
RLR1:   sub  ecx,ebx
        mov  al,ah
RLRP1:  mov  [fs:edi],al
        inc  edi
        dec  ebx
        jnz  RLRP1
        jmp  RLEOUT
RLDONE: ret

; The previous frame, moved by (GDX, GDY), becomes the starting point for
; this one. This is what makes a slow pan cost almost nothing: everything
; that merely moved is already in place before a block opcode is read.
SHIFTFRAME:
        push eax
        push ebx
        push ecx
        push edx
        push esi
        push edi
        ; Nothing moved: the whole previous picture carries over, and there
        ; is no uncovered strip to clear. Most frames of most scenes take
        ; this path, so it is worth the four lines.
        mov  eax,[GDX]
        or   eax,[GDY]
        jnz  SFMOVED
        mov  esi,[PFRAME]
        mov  edi,[CFRAME]
        mov  ecx,PLANE/4
        call COPYD
        jmp  SFEXIT

SFMOVED:
        mov  edi,[CFRAME]               ; clear first - what scrolls in from
        mov  ecx,PLANE/4                ; outside has no source at all
        xor  eax,eax
        call FILLD

        xor  ebx,ebx                    ; y
SFROW:  mov  eax,ebx
        sub  eax,[GDY]                  ; source row
        js   SFNEXT
        cmp  eax,HEIGHT
        jge  SFNEXT

        imul eax,WIDTH
        add  eax,[PFRAME]
        mov  esi,eax                    ; source row, at x = 0
        mov  eax,ebx
        imul eax,WIDTH
        add  eax,[CFRAME]
        mov  edi,eax                    ; destination row, at x = 0

        mov  ecx,WIDTH
        mov  edx,[GDX]
        test edx,edx
        js   SFNEG
        add  edi,edx                    ; moving right
        sub  ecx,edx
        jle  SFNEXT
        jmp  SFCOPY
SFNEG:  sub  esi,edx                    ; moving left - edx is negative
        add  ecx,edx
        jle  SFNEXT
SFCOPY: call COPYB
SFNEXT: inc  ebx
        cmp  ebx,HEIGHT
        jb   SFROW
SFEXIT: pop  edi
        pop  esi
        pop  edx
        pop  ecx
        pop  ebx
        pop  eax
        ret

; The linear address of the current block in CFRAME.
BLOCKADDR:
        push eax
        mov  edi,[ROWBASE]
        mov  eax,[BLKX]
        shl  eax,3
        add  edi,eax
        add  edi,[CFRAME]
        pop  eax
        ret

; Step the block cursor on by ECX blocks.
ADVANCE:
        push eax
        mov  eax,[BLKX]
        add  eax,ecx
ADV1:   cmp  eax,BLKW
        jb   ADV2
        sub  eax,BLKW
        add  dword [ROWBASE],BLKROW
        jmp  ADV1
ADV2:   mov  [BLKX],eax
        pop  eax
        ret

; The palette out of the file header: 256 entries of three 6-bit values.
SETPAL: mov  dx,3C8h
        xor  al,al
        out  dx,al
        mov  dx,3C9h
        mov  si,HDRBUF+32
        mov  cx,768
SP1:    lodsb
        out  dx,al
        loop SP1
        ret

; The BIOS tick counter, 0040:006C. Read through an ordinary real-mode
; segment: this is in the frame loop, and the frame loop calls nothing.
TICK:   push ds
        mov  ax,40h
        mov  ds,ax
        mov  eax,[6Ch]
        pop  ds
        ret

TICKIN: call TICK
        mov  [TMPT],eax
        ret

TICKOUT:
        call TICK
        sub  eax,[TMPT]
        ret

; Give FS the flat descriptor back.
;
; Loading a segment register in real mode refills its descriptor cache from
; the real-mode reading of the value - base times sixteen, limit 64 KB - so
; the 4 GB limit is gone the moment anything writes to it. DOS is not
; supposed to touch FS and in practice does not, but "in practice" is not a
; thing to build a decoder on, and this costs eight instructions.
;
; Before LGDT has run there is nothing to refresh FROM: with an unloaded
; GDTR the processor reads its descriptor out of the interrupt vector table
; and comes back with a garbage base. The first version of the logging above
; called this before LGDT and wrecked the program it was there to diagnose.
REFLAT: cmp  byte [FLATOK],1
        jne  RFSKIP
        push eax
        push bx
        cli
        mov  eax,cr0
        or   al,1
        mov  cr0,eax
        jmp  $+2
        mov  bx,8
        mov  fs,bx
        mov  eax,cr0
        and  al,0FEh
        mov  cr0,eax
        jmp  $+2
        sti
        pop  bx
        pop  eax
RFSKIP: ret

; Append one line to PLAYER.LOG, opening and closing the file each time.
; Four DOS calls a line is wasteful and that is the point: the file is CLOSED
; when this returns, so the line survives a machine that has to be killed
; from outside. DX = a $-terminated message.
LOGMARK:
        pushad
        mov  [LOGMSG],dx
        mov  ax,3D01h
        mov  dx,LOGNAME
        int  21h
        jnc  LM1
        mov  ah,3Ch
        xor  cx,cx
        mov  dx,LOGNAME
        int  21h
        jc   LMFAIL
LM1:    mov  bx,ax
        mov  ax,4202h                   ; seek to the end
        xor  cx,cx
        xor  dx,dx
        int  21h
        mov  si,[LOGMSG]
        xor  cx,cx
LM2:    lodsb
        cmp  al,'$'
        je   LM3
        inc  cx
        jmp  LM2
LM3:    mov  dx,[LOGMSG]
        mov  ah,40h
        int  21h
        mov  ah,3Eh
        int  21h
LMFAIL: call REFLAT
        popad
        ret

; AX as four hex digits at DS:DI.
HEX16TO:
        push cx
        mov  cx,4
H16A:   rol  ax,4
        push ax
        and  al,0Fh
        add  al,'0'
        cmp  al,'9'
        jbe  H16B
        add  al,7
H16B:   mov  [di],al
        inc  di
        pop  ax
        loop H16A
        pop  cx
        ret

; EAX as eight hex digits at DS:DI.
HEX32TO:
        push cx
        mov  cx,8
H32A:   rol  eax,4
        push eax
        and  al,0Fh
        add  al,'0'
        cmp  al,'9'
        jbe  H32B
        add  al,7
H32B:   mov  [di],al
        inc  di
        pop  eax
        loop H32A
        pop  cx
        ret

TEXTMODE:
        cmp  byte [INGFX],1
        jne  TMDONE
        mov  ax,3
        int  10h
        mov  byte [INGFX],0
        call REFLAT
TMDONE: ret

PUTS:   mov  ah,9
        int  21h
        ret

; ---- the ways this can go wrong -------------------------------------------
NOFILE: mov  dx,MSGNOFILE
        call PUTS
        jmp  QUIT
BADFILE:
        mov  dx,MSGBADFILE
        call PUTS
        jmp  CLOSEQUIT
BADSIZE:
        mov  dx,MSGBADSIZE
        call PUTS
        jmp  CLOSEQUIT
NOUNREAL:
        mov  dx,MKNOUNR
        call LOGMARK
        mov  dx,MSGNOUNREAL
        call PUTS
        jmp  CLOSEQUIT
NOMODE: call TEXTMODE
        mov  dx,MKNOMODE
        call LOGMARK
        mov  dx,MSGNOMODE
        call PUTS
CLOSEQUIT:
        call SBSTOP
        mov  bx,[FH]
        mov  ah,3Eh
        int  21h
QUIT:   mov  ax,4C00h
        int  21h

include 'SB.INC'

; ===========================================================================
;  Data
; ===========================================================================
        align 8
GDT:    dq 0                            ; null descriptor
GDTFLAT:
        dw 0FFFFh                       ; limit 15..0
        dw 0                            ; base 15..0
        db 0                            ; base 23..16
        db 92h                          ; present, ring 0, data, writable
        db 0CFh                         ; 4 KB granular, 32-bit, limit 19..16
        db 0                            ; base 31..24
GDTEND:
GDTR:   dw GDTEND-GDT-1
        dd 0                            ; linear address of the GDT

FH       dw 0
INGFX    db 0
FLATOK   db 0
DEBUG    db 0
LFB      dd 0
PITCH    dd 0
PFRAME   dd 0
CFRAME   dd 0
GDX      dd 0
GDY      dd 0
BLKX     dd 0
ROWBASE  dd 0
SRC      dd 0
BUFEND   dd 0
IOBUFLIN dd 0
TICKBASE dd 0
FRAMENO  dd 0
FPSD     dd 12
WANTED   dd 0
BASED    db 0
BASEFRAME dd 0
TMPT     dd 0
ACCREAD  dd 0
ACCSHIFT dd 0
ACCBLK   dd 0
ACCBLIT  dd 0
CHDR     db 6 dup (0)

LOGMSG   dw 0
LOGNAME  db 'PLAYER.LOG',0
TIMLINE  db 'ticks  read='
TIMREAD  db '00000000'
         db '  shift='
TIMSHIFT db '00000000'
         db '  blocks='
TIMBLK   db '00000000'
         db '  blit='
TIMBLIT  db '00000000'
         db '  underruns='
TIMUNDER db '0000'
         db '  dropped='
TIMDROP  db '0000'
         db 13,10
         db 'clock  wraps='
TIMWRAP  db '00000000'
         db '  lastpos='
TIMPOS   db '00000000'
         db '  played='
TIMPLAY  db '00000000'
         db '  wanted='
TIMWANT  db '00000000'
         db '  elapsed ticks='
TIMELAP  db '00000000'
         db 13,10,'$'

MK1      db 'reached: header read, about to enter unreal mode',13,10,'$'
MK1B     db 'reached: GDT loaded, FS made flat',13,10,'$'
MK2      db 'reached: unreal mode granted, 2 MB written and read',13,10,'$'
MK3      db 'reached: VESA 100h set, palette loaded, playing',13,10,'$'
MKNOUNR  db 'FAILED: the 4 GB limit did not survive',13,10,'$'
MKNOMODE db 'FAILED: VESA 100h with the LFB bit was refused',13,10,'$'
MKFIN    db 'reached: the end of the stream',13,10,'$'
MKBEAT   db 'frame    '
BEATNO   db '00000000',13,10,'$'
MKSOUND  db 'sound:   Sound Blaster found, it is the clock',13,10,'$'
MKNOSND  db 'sound:   none - frames timed from the BIOS tick instead',13,10,'$'

DEFAULTN db 'TEST2.OWV',0
FNAME    db 80 dup (0)

MSGNOFILE   db 'Cannot open that file.',13,10,'$'
MSGBADFILE  db 'That is not an OWV file, or it is truncated.',13,10,'$'
MSGBADSIZE  db 'This player is built for 640x400 only.',13,10,'$'
MSGNOUNREAL db 'Unreal mode was refused - no 32-bit addressing here.',13,10,'$'
MSGNOMODE   db 'VESA mode 100h with a linear framebuffer was refused.',13,10,'$'
MSGDONE     db 'done.',13,10,'$'

; ============================================================================
;  The program must not grow into its own buffers.
;
;  It did: the sound code took it past 4 KB and over HDRBUF, and the symptom
;  was a palette of noise and a log full of PCM - which points at everything
;  except the cause. A file that assembles is not the same as a file that
;  fits, and only the assembler can tell the difference cheaply.
; ============================================================================
if $ > HDRBUF
        display 'PLAYER has grown into HDRBUF - move the buffers up', 13, 10
        err
end if
