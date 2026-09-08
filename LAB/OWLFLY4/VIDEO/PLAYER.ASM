; ============================================================================
;  PLAYER.ASM - play one OWV file at 640x400, 256 colours, in DOS.
;
;      PLAYER              plays TEST2.OWV
;      PLAYER SOME.OWV     plays that instead
;
;      ESC                 stop
;
;  Every run writes PLAYER.LOG: where it got to, where the time went, and
;  how far the picture drifted from the sound. Five lines for a whole clip.
;
;  This is the workbench: one file, then back to DOS. The decoder, the
;  sound clock, unreal mode and the whole segment discipline live in
;  OWV.INC and SB.INC, which the story engine in ..\ENGINE includes too.
;  The essays about WHY they are built that way are at the top of OWV.INC.
;
;  NB deliberately NOT an 8086 program: E_8086.INC must not be included.
; ============================================================================

format binary as 'com'
        org 100h

; ---- conventional memory, inside this 64 KB segment -----------------------
;
;  0100  code and data, growing upwards
;  2000  HDRBUF   800 bytes    the file header, palette included
;  2400  MODEBUF  256 bytes    what VESA says about mode 100h
;  2800  QUEUE    32 KB        audio waiting for the interrupt (see SB.INC)
;  A800  IOBUF    16 KB        where DOS reads land before going above 1 MB
;  E800  ...      6 KB         the stack, growing down from FFFE
;
;  These used to start at 1000h, which was comfortable until the sound code
;  pushed the program past 4 KB and it began writing over its own header
;  buffer - the palette turned to noise and the log filled with PCM. The
;  assertion at the very bottom of this file makes that a build error now
;  instead of a puzzle.
HDRBUF  = 2000h
MODEBUF = 2400h
QUEUE   = 2800h
QUEUESZ = 32768
IOBUF   = 0A800h
IOSIZE  = 4000h

START:  cld
        mov  sp,0FFFEh

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
        jmp  GO
DEFNAME:
        mov  si,DEFAULTN
        mov  di,FNAME
DN1:    lodsb
        stosb
        test al,al
        jnz  DN1

; ---------------------------------------------------------------------------
;  Unreal mode, the graphics mode, the clip, and back.
; ---------------------------------------------------------------------------
GO:     call UNREALON
        jc   NOUNREAL
        call GFXON
        jc   NOMODE

        mov  dx,FNAME
        call OWVPLAY
        push ax
        call TEXTMODE
        call SBRELEASE
        pop  ax
        cmp  al,1
        je   NOFILE
        cmp  al,2
        je   BADFILE
        cmp  al,3
        je   BADSIZE
        mov  dx,MSGDONE
        call PUTS
        jmp  QUIT

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
        jmp  QUIT
BADSIZE:
        mov  dx,MSGBADSIZE
        call PUTS
        jmp  QUIT
NOUNREAL:
        mov  dx,MSGNOUNREAL
        call PUTS
        jmp  QUIT
NOMODE: mov  dx,MSGNOMODE
        call PUTS
QUIT:   mov  ax,4C00h
        int  21h

include 'OWV.INC'
include 'SB.INC'

; ===========================================================================
;  Data
; ===========================================================================
LOGNAME  db 'PLAYER.LOG',0
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
