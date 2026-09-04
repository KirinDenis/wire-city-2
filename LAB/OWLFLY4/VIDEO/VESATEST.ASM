; ============================================================================
;  VESATEST.ASM - can this machine do what OWL FLY 4's video player needs?
;
;      VESATEST        ask each question, wait for a key between stages
;      VESATEST /A     ask them all without stopping, and write VESATEST.LOG
;
;  Three questions, asked in the order that keeps the answers even when the
;  next question kills the program:
;
;    1. Is there a 386, and what does VESA offer for mode 100h (640x400x256)?
;       Printed in text mode. Nothing here can crash.
;    2. Does the mode work through the BANKED window at A000h? Real mode,
;       64 KB at a time. This is the fallback if 3 is refused.
;    3. Does UNREAL MODE work - a 4 GB limit cached in FS, so a real-mode
;       program reaches the linear framebuffer with a 32-bit offset?
;
;  Question 3 decides how the player is built. The plan for this game assumes
;  32-bit addressing with no DOS extender, and LOCAL.BAT on this machine says
;  plain DOSBox 0.74 grants no unreal mode. Better learned from a program,
;  now, than from a player that has already been written.
;
;  TWO INSTRUMENTS, AND THEY ANSWER DIFFERENT THINGS.
;
;  The picture: both stages draw a grey ramp, colour = (x/2 + y), climbing
;  right and down. Drawn correctly it is a smooth diagonal wash. Wrong
;  scanline stride shears it; wrong addressing tears or repeats it. An eye
;  reads that in an instant and no number says it as well.
;
;  The readback: after drawing, the program reads pixels back through the
;  same path it wrote them and counts how many disagree. That needs no eye
;  and lands in the log, which is what makes /A worth having - a machine can
;  run it and report.
;
;  Neither is sufficient. A zero mismatch count with a sheared picture means
;  the writes are consistent and the stride assumption is wrong, and that is
;  exactly the bug worth catching before a player is built on it.
;
;  NB deliberately NOT an 8086 program: E_8086.INC must not be included here.
;  Everything after the CPU check needs a 386.
; ============================================================================

format binary as 'com'
        org 100h

VBEBUF  = 4000h                 ; VBE info block, 512 bytes
MODEBUF = 4400h                 ; mode info block, 256 bytes
LOGBUF  = 4800h                 ; the transcript, dumped to VESATEST.LOG

START:  cld
        mov  word [LOGPTR],LOGBUF

        ; /A anywhere in the command tail means: do not stop for keys.
        mov  si,81h
        movzx cx,byte [80h]
        jcxz  NOAUTO
SCANA:  lodsb
        cmp  al,'/'
        jne  SCANNX
        mov  al,[si]
        and  al,0DFh
        cmp  al,'A'
        jne  SCANNX
        mov  byte [AUTO],1
        jmp  NOAUTO
SCANNX: loop SCANA
NOAUTO:
        mov  dx,MSGBANNER
        call PUTS

; ---------------------------------------------------------------------------
;  1a. Which processor. The 8086 keeps bits 12-15 of FLAGS set whatever is
;      pushed into them; the 286 keeps them clear in real mode; only a 386
;      lets them be written and read back.
; ---------------------------------------------------------------------------
        pushf
        pop  bx
        and  bx,0FFFh
        push bx
        popf
        pushf
        pop  ax
        and  ax,0F000h
        cmp  ax,0F000h
        je   IS8086
        or   bx,0F000h
        push bx
        popf
        pushf
        pop  ax
        and  ax,0F000h
        jz   IS286
        mov  dx,MSG386
        call PUTS
        jmp  VBEINFO
IS8086: mov  dx,MSG8086
        call PUTS
        jmp  BAILOUT
IS286:  mov  dx,MSG286
        call PUTS
        jmp  BAILOUT

; ---------------------------------------------------------------------------
;  1b. VBE controller information. Putting 'VBE2' in the signature before the
;      call is what makes a card fill in the 2.0 fields - among them the one
;      this whole design rests on, the linear framebuffer.
; ---------------------------------------------------------------------------
VBEINFO:
        mov  ax,ds
        mov  es,ax
        mov  di,VBEBUF
        mov  dword [di],'VBE2'
        mov  ax,4F00h
        int  10h
        cmp  ax,004Fh
        jne  NOVBE
        cmp  dword [VBEBUF],'VESA'
        jne  NOVBE

        mov  dx,MSGVBEVER
        call PUTS
        mov  ax,[VBEBUF+4]              ; VbeVersion - 0200h is 2.0
        call PUTHEX16
        call CRLF

        mov  ax,ds
        mov  es,ax
        mov  di,MODEBUF
        mov  cx,100h                    ; 640x400x256
        mov  ax,4F01h
        int  10h
        cmp  ax,004Fh
        jne  NOMODE
        test word [MODEBUF],1           ; bit 0: supported at all
        jz   NOMODE

        mov  dx,MSGATTR
        call PUTS
        mov  ax,[MODEBUF]
        call PUTHEX16
        call CRLF

        mov  dx,MSGRES
        call PUTS
        mov  ax,[MODEBUF+12h]           ; XResolution
        call PUTHEX16
        mov  dl,'x'
        call PUTCH
        mov  ax,[MODEBUF+14h]           ; YResolution
        call PUTHEX16
        mov  dl,' '
        call PUTCH
        movzx ax,byte [MODEBUF+19h]     ; BitsPerPixel
        call PUTHEX16
        mov  dx,MSGBPP
        call PUTS

        mov  dx,MSGPITCH
        call PUTS
        mov  ax,[MODEBUF+10h]           ; BytesPerScanLine
        mov  [PITCH],ax
        movzx ecx,ax                    ; the same as a dword, for imul
        mov  [PITCH2],ecx
        call PUTHEX16
        call CRLF

        ; Window granularity, in KB. The number handed to 4F05h counts
        ; granularity units, NOT 64 KB windows - assume they are the same and
        ; a 4 KB-granularity card draws every bank in the wrong place.
        mov  ax,[MODEBUF+4]
        mov  [GRANKB],ax
        mov  dx,MSGGRAN
        call PUTS
        call PUTHEX16
        call CRLF

        mov  dx,MSGLFB
        call PUTS
        mov  eax,[MODEBUF+28h]          ; PhysBasePtr
        mov  [LFB],eax
        call PUTHEX32
        call CRLF

        test word [MODEBUF],80h         ; bit 7: linear framebuffer available
        jz   NOLFB
        mov  dx,MSGHASLFB
        call PUTS
        mov  byte [CANLFB],1
        jmp  STAGE2
NOLFB:  mov  dx,MSGNOLFB
        call PUTS
        jmp  STAGE2

NOVBE:  mov  dx,MSGNOVBE
        call PUTS
        jmp  BAILOUT
NOMODE: mov  dx,MSGNOMODE
        call PUTS
        jmp  BAILOUT

; ---------------------------------------------------------------------------
;  2. The banked window: real mode, 64 KB at a time at A000h.
; ---------------------------------------------------------------------------
STAGE2: mov  dx,MSGSTAGE2
        call PUTS
        call STEPWAIT

        mov  ax,4F02h
        mov  bx,100h                    ; no LFB bit
        int  10h
        cmp  ax,004Fh
        jne  BANKFAIL

        call GREYRAMP

        ; units to advance the window per 64 KB = 65536 / (granularity*1024)
        movzx eax,word [GRANKB]
        test eax,eax
        jnz  GRAN1
        mov  eax,64                     ; zero means "not windowed"
GRAN1:  shl  eax,10                     ; granularity in bytes
        mov  ecx,eax
        mov  eax,65536
        xor  edx,edx
        div  ecx
        mov  [BANKMUL],ax

        mov  ax,0A000h
        mov  es,ax
        mov  word [CURBANK],0FFFFh
        movzx ecx,word [PITCH]
        xor  ebx,ebx                    ; y
BROW:   xor  esi,esi                    ; x
BPIX:   mov  eax,ebx
        imul eax,ecx                    ; y * pitch
        add  eax,esi                    ; + x
        mov  edx,eax
        shr  edx,16                     ; which 64 KB window
        cmp  dx,[CURBANK]
        je   BNOSW
        call SETBANK                    ; preserves eax
BNOSW:  mov  di,ax                      ; offset inside the window
        mov  eax,esi
        shr  eax,1
        add  eax,ebx
        mov  [es:di],al
        inc  esi
        cmp  esi,640
        jb   BPIX
        inc  ebx
        cmp  ebx,400
        jb   BROW

        ; Read back what is reachable in window 0 and count disagreements.
        call SETBANK0
        xor  cx,cx                      ; mismatches
        xor  ebx,ebx
BVROW:  xor  esi,esi
BVPIX:  mov  eax,ebx
        imul eax,[PITCH2]
        add  eax,esi
        cmp  eax,65536
        jae  BVDONE
        mov  di,ax
        mov  al,[es:di]
        mov  dx,ax                      ; keep what was read, in dl
        mov  eax,esi
        shr  eax,1
        add  eax,ebx
        cmp  dl,al
        je   BVOK
        inc  cx
BVOK:   add  esi,7                      ; a sparse sample is enough
        cmp  esi,640
        jb   BVPIX
        inc  ebx
        cmp  ebx,400
        jb   BVROW
BVDONE: mov  [MISMATCH],cx

        call STEPWAIT
        call TEXTMODE
        mov  dx,MSGBANKOK
        call PUTS
        mov  ax,[MISMATCH]
        call PUTHEX16
        call CRLF
        jmp  STAGE3

BANKFAIL:
        call TEXTMODE
        mov  dx,MSGBANKBAD
        call PUTS
        jmp  BAILOUT

; ---------------------------------------------------------------------------
;  3. Unreal mode. Enter protected mode for the length of two instructions,
;     load FS with a descriptor whose limit is 4 GB, and leave again. The
;     processor keeps the cached descriptor, so from here a real-mode program
;     reaches the whole machine through FS with a 32-bit offset - no DOS
;     extender, no DPMI host, DOS calls untouched.
; ---------------------------------------------------------------------------
STAGE3: cmp  byte [CANLFB],1
        jne  NOLFBSKIP
        mov  dx,MSGSTAGE3
        call PUTS
        call STEPWAIT

        mov  ax,2401h                   ; enable A20, or everything above
        int  15h                        ; 1 MB wraps onto the first 64 KB

        xor  eax,eax
        mov  ax,cs
        shl  eax,4
        add  eax,GDT
        mov  dword [GDTR+2],eax

        cli
        lgdt [GDTR]
        mov  eax,cr0
        or   al,1
        mov  cr0,eax
        jmp  $+2
        mov  bx,8                       ; the flat descriptor
        mov  fs,bx
        mov  eax,cr0
        and  al,0FEh
        mov  cr0,eax
        jmp  $+2
        sti

        ; Prove the 4 GB limit survived before trusting the framebuffer to
        ; it: write and read one byte a long way past the real-mode wall.
        mov  edi,200000h                ; 2 MB
        mov  byte [fs:edi],5Ah
        mov  al,[fs:edi]
        cmp  al,5Ah
        jne  UNREALNO
        mov  dx,MSGUNREAL
        call PUTS

        mov  ax,4F02h
        mov  bx,4100h                   ; mode 100h, LFB bit set
        int  10h
        cmp  ax,004Fh
        jne  LFBFAIL

        call GREYRAMP

        movzx ecx,word [PITCH]
        xor  ebx,ebx                    ; y
LROW:   mov  eax,ebx
        imul eax,ecx
        add  eax,[LFB]
        mov  edi,eax                    ; start of this scanline
        xor  esi,esi                    ; x
LPIX:   mov  eax,esi
        shr  eax,1
        add  eax,ebx
        mov  [fs:edi],al
        inc  edi
        inc  esi
        cmp  esi,640
        jb   LPIX
        inc  ebx
        cmp  ebx,400
        jb   LROW

        ; Read back a sparse sample of the whole frame.
        xor  cx,cx
        xor  ebx,ebx
LVROW:  mov  eax,ebx
        imul eax,[PITCH2]
        add  eax,[LFB]
        mov  edi,eax
        xor  esi,esi
LVPIX:  mov  al,[fs:edi+esi]
        mov  dl,al
        mov  eax,esi
        shr  eax,1
        add  eax,ebx
        cmp  dl,al
        je   LVOK
        inc  cx
LVOK:   add  esi,7
        cmp  esi,640
        jb   LVPIX
        inc  ebx
        cmp  ebx,400
        jb   LVROW
        mov  [MISMATCH],cx

        call STEPWAIT
        call TEXTMODE
        mov  dx,MSGLFBOK
        call PUTS
        mov  ax,[MISMATCH]
        call PUTHEX16
        call CRLF
        jmp  BAILOUT

UNREALNO:
        mov  dx,MSGUNREALNO
        call PUTS
        jmp  BAILOUT

LFBFAIL:
        call TEXTMODE
        mov  dx,MSGLFBBAD
        call PUTS
        jmp  BAILOUT

NOLFBSKIP:
        mov  dx,MSGSKIP3
        call PUTS

BAILOUT:
        mov  dx,MSGDONE
        call PUTS
        call WRITELOG
        mov  ax,4C00h
        int  21h

; ============================================================================
;  Helpers
; ============================================================================

; Set the banked window to hold byte offset EAX. Preserves EAX.
SETBANK:
        push eax
        push ebx
        push ecx
        push esi
        mov  [CURBANK],dx
        mov  ax,dx
        mul  word [BANKMUL]
        mov  dx,ax
        mov  ax,4F05h
        xor  bx,bx                      ; window A, set position
        int  10h
        pop  esi
        pop  ecx
        pop  ebx
        pop  eax
        ret

SETBANK0:
        push ax
        push bx
        push dx
        xor  dx,dx
        mov  ax,4F05h
        xor  bx,bx
        int  10h
        pop  dx
        pop  bx
        pop  ax
        ret

; Every character printed is also appended to the log buffer, so /A can hand
; the whole transcript to whoever ran it without a screen.
PUTS:   push ax
        push si
        push di
        mov  si,dx
        mov  di,[LOGPTR]
PS1:    lodsb
        cmp  al,'$'
        je   PS2
        mov  [di],al
        inc  di
        jmp  PS1
PS2:    mov  [LOGPTR],di
        pop  di
        pop  si
        pop  ax
        mov  ah,9
        int  21h
        ret

PUTCH:  push di
        mov  di,[LOGPTR]
        mov  [di],dl
        inc  di
        mov  [LOGPTR],di
        pop  di
        mov  ah,2
        int  21h
        ret

CRLF:   mov  dl,13
        call PUTCH
        mov  dl,10
        call PUTCH
        ret

PUTHEX16:
        push ax
        mov  al,ah
        call PUTHEX8
        pop  ax
        call PUTHEX8
        ret

PUTHEX32:
        push eax
        shr  eax,16
        call PUTHEX16
        pop  eax
        call PUTHEX16
        ret

PUTHEX8:
        push ax
        shr  al,4
        call PUTNIB
        pop  ax
        and  al,0Fh
PUTNIB: add  al,'0'
        cmp  al,'9'
        jbe  PN1
        add  al,7
PN1:    mov  dl,al
        call PUTCH
        ret

; A key between stages, unless /A said not to stop. In automatic mode there
; is still a pause, because a person watching the run should see the ramp.
STEPWAIT:  cmp  byte [AUTO],1
        je   AUTOPAUSE
        xor  ah,ah
        int  16h
        ret
AUTOPAUSE:
        mov  cx,0022h                   ; about 2.2 seconds, in microseconds
        mov  dx,0000h
        mov  ah,86h
        int  15h
        ret

TEXTMODE:
        mov  ax,3
        int  10h
        ret

WRITELOG:
        mov  ah,3Ch                     ; create or truncate
        xor  cx,cx
        mov  dx,LOGNAME
        int  21h
        jc   WLDONE
        mov  bx,ax
        mov  cx,[LOGPTR]
        sub  cx,LOGBUF
        mov  dx,LOGBUF
        mov  ah,40h
        int  21h
        mov  ah,3Eh
        int  21h
WLDONE: ret

; A grey ramp in the DAC, so the wash reads as a gradient rather than as the
; default palette's confetti. Six bits per channel is what the DAC takes.
GREYRAMP:
        mov  dx,3C8h
        xor  al,al
        out  dx,al
        inc  dx
        xor  cx,cx
GR1:    mov  al,cl
        shr  al,2
        out  dx,al
        out  dx,al
        out  dx,al
        inc  cx
        cmp  cx,256
        jb   GR1
        ret

; ============================================================================
;  Data
; ============================================================================
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
        dd 0                            ; linear address of GDT, set at run time

AUTO     db 0
CANLFB   db 0
PITCH    dw 0
PITCH2   dd 0                           ; the same, as a dword for imul
GRANKB   dw 0
BANKMUL  dw 1
CURBANK  dw 0FFFFh
MISMATCH dw 0
LOGPTR   dw 0
LFB      dd 0
LOGNAME  db 'VESATEST.LOG',0

MSGBANNER  db 13,10,'VESATEST - what this machine grants OWL FLY 4',13,10
           db '---------------------------------------------',13,10,'$'
MSG8086    db 'CPU      8086/8088 - stop: everything below needs a 386',13,10,'$'
MSG286     db 'CPU      286 - stop: everything below needs a 386',13,10,'$'
MSG386     db 'CPU      386 or better',13,10,'$'
MSGNOVBE   db 'VESA     no VBE at all - no 640x400x256 this way',13,10,'$'
MSGNOMODE  db 'VESA     mode 100h is not offered',13,10,'$'
MSGVBEVER  db 'VBE      version $'
MSGATTR    db 'attribs  $'
MSGRES     db 'mode100  $'
MSGBPP     db ' bpp',13,10,'$'
MSGPITCH   db 'pitch    $'
MSGGRAN    db 'window   granularity KB $'
MSGLFB     db 'LFB at   $'
MSGHASLFB  db 'LFB      offered (attribute bit 7)',13,10,'$'
MSGNOLFB   db 'LFB      NOT offered - banked window only',13,10,'$'
MSGSTAGE2  db 13,10,'Stage 2: banked window, real mode.',13,10,'$'
MSGBANKOK  db 'banked   ramp drawn, readback mismatches in window 0: $'
MSGBANKBAD db 'banked   mode 100h refused to set',13,10,'$'
MSGSTAGE3  db 13,10,'Stage 3: unreal mode and the linear framebuffer.',13,10,'$'
MSGUNREAL  db 'unreal   GRANTED - 2 MB was written and read back',13,10,'$'
MSGUNREALNO db 'unreal   REFUSED - the 4 GB limit did not survive',13,10,'$'
MSGLFBOK   db 'LFB      ramp drawn through FS, readback mismatches: $'
MSGLFBBAD  db 'LFB      mode 100h with the LFB bit refused to set',13,10,'$'
MSGSKIP3   db 13,10,'Stage 3 skipped: no LFB on offer.',13,10,'$'
MSGDONE    db 13,10,'done.',13,10,'$'
