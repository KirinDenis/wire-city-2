; ============================================================================
;  STORY.ASM - play a story: the scenes of STORY\<NAME>, section by section.
;
;      STORY                     plays ..\STORY\NIGHT
;      STORY ..\STORY\OTHER      plays that one
;      STORY ..\STORY\NIGHT /AUTO
;                                plays itself: takes every thing in a pickup,
;                                answers 1 to every quiz, waits a second on
;                                every message, and writes SHOTnn.OWV of the
;                                screen at each of those moments - so the
;                                run can be looked at afterwards, frame by
;                                frame, by a person or by the desk's --dump.
;
;      in a clip      ESC skips it, Q quits
;      in a pickup    click a thing to take it - or the arrow keys move
;                     the cursor and Enter takes; ESC skips, Q quits
;      in a quiz      1..9 answers; ESC takes the first
;
;  Every run writes STORY.LOG: which scene, which section, what was taken,
;  which code, where it went - and the player's own five lines a clip.
;
;  ------------------------------------------------------------------------
;  WHAT A STORY IS, TO THIS PROGRAM
;  ------------------------------------------------------------------------
;  STORY.INI names the first scene and lists the rest (ORDER). Each scene
;  is a folder with SCENE.INI: some text for the writer, which this program
;  skips, a CODE, an ENTERS list, and SECTIONS in play order:
;
;      MUSIC = MUSIC.PCM                  -> the scene's track, looped: on
;                                            its own under the room, mixed
;                                            under the clips
;      [VIDEO]   FILE = CLIP.OWV          -> OWVPLAY, from OWV.INC
;      [PICKUP]  FOLDER = PICKUP          -> BG.OWV, one frame, through the
;                PANEL = 64                  same OWVPLAY; then KEYS.SPR etc.
;                ITEM KEYS = ...             drawn on top, and taken by mouse;
;                TEXT KEYS = Her keys.       the panel below the room with a
;                NEED = KEYS CASSETTE        slot per thing: its outline
;                                            while it is in the room, its
;                                            picture once taken, and a line
;                                            of text over the room for a
;                                            moment at the taking
;      [QUIZ]    TEXT = ...               -> the question and numbered
;                OPTION 9 = She flies        answers over the last frame
;
;  A scene ends with a number - the quiz answer, or its CODE line - and the
;  next scene is the one whose ENTERS holds that number. This program does
;  not know the scenes by name beyond that: it reads each candidate's
;  ENTERS line and takes the first match. The desk has already checked
;  that there is exactly one.
;
;  A file that is not there is a message on the screen with the path, and
;  a key moves on. The story can be played at every stage of production.
;
;  ------------------------------------------------------------------------
;  THE PARSER IS TWENTY LINES BECAUSE THE FORMAT WAS CHOSEN FOR IT
;  ------------------------------------------------------------------------
;  A line is blank, a comment, a [SECTION], or KEY [SUB] = VALUE. Keys are
;  upper case as the desk writes them; values run to the end of the line.
;  Nothing is quoted, nothing is escaped, nothing nests. That is why it is
;  INI and not JSON: the game is assembly, and a parser is a liability.
;
;  NB deliberately NOT an 8086 program: E_8086.INC must not be included.
; ============================================================================

format binary as 'com'
        org 100h

; ---- conventional memory, inside this 64 KB segment -----------------------
;
;  0100  code and the small data
;  4000  SECTTAB  3 KB         the scene's sections, parsed
;  4C00  ORDERTAB 416 bytes    the scene ids from STORY.INI
;  4E00  ITEMTAB  512 bytes    the things of the pickup on screen
;  5000  CURSAVE  256 bytes    what is under the cursor
;  5100  HDRBUF   800 bytes    the file header of the clip being played
;  5500  MODEBUF  256 bytes    what VESA says about mode 100h
;  5600  INIBUF   4 KB         the INI being read, 0-terminated
;  6600  QUEUE    32 KB        audio waiting for the interrupt (SB.INC)
;  E600  IOBUF    4 KB         where DOS reads land before going above 1 MB
;  F600  ...      2.5 KB       the stack, growing down from FFFE
;
;  The tables are ADDRESSES, not data in the code: the code with the two
;  includes is over 12 KB, and every byte of table in it would be a byte
;  of file and a byte less for the stack.
SECTTAB  = 4000h
ORDERTAB = 4C00h
ITEMTAB  = 4E00h
CURSAVE  = 5000h
HDRBUF  = 5100h
MODEBUF = 5500h
INIBUF  = 5600h
INISZ   = 1000h
QUEUE   = 6600h
QUEUESZ = 32768
IOBUF   = 0E600h
IOSIZE  = 1000h

; ---- above 1 MB, through FS ------------------------------------------------
SPRBASE = 400000h               ; the things of a pickup, 64 KB a slot
SPRSLOT = 10000h
ICOBASE = 500000h               ; their slot pictures, 16 KB a slot
ICOSLOT = 4000h

; ---- the story, as tables ---------------------------------------------------
MAXSECT  = 8
MAXITEMS = 16
MAXOPT   = 9
MAXORDER = 32
NAMESZ   = 13                   ; 8.3 and a zero

; a section record
SECTSZ   = 384
S_KIND   = 0                    ; 1 video, 2 pickup, 3 quiz
S_NAME   = 1                    ; FILE or FOLDER, NAMESZ bytes
S_TOFF   = 14                   ; quiz TEXT: offset in INIBUF, length
S_TLEN   = 16
S_NOPT   = 18
S_OPT    = 20                   ; MAXOPT * (code w, off w, len w)
S_NEEDO  = 74                   ; NEED: offset, length
S_NEEDL  = 76
S_NITEM  = 78
S_PANEL  = 80                   ; pickup: rows of the panel below the room
S_ITEM   = 82                   ; MAXITEMS * SI_SZ
SI_SZ    = 13                   ; an item: the name and a zero, then its
SI_TOFF  = 9                    ; TEXT line - offset in INIBUF, length
SI_TLEN  = 11

K_VIDEO  = 1
K_PICKUP = 2
K_QUIZ   = 3

; a thing on the screen, once its .SPR is loaded
ITSZ     = 32
IT_X     = 0                    ; signed words: where it stands on screen
IT_Y     = 2
IT_W     = 4
IT_H     = 6
IT_ADDR  = 8                    ; linear, above 1 MB
IT_FLAGS = 12                   ; 1 loaded, 2 taken, 4 needed
IT_ICO   = 16                   ; its slot picture: linear, or 0 for none
IT_IX    = 20                   ; where the slot is, and how big
IT_IY    = 22
IT_IW    = 24
IT_IH    = 26

AUTOWAIT = 18                   ; ticks a message stays up in /AUTO: a second
AUTOSTEP = 9                    ; ticks between two things taken in /AUTO
CAPTH    = 24                   ; the caption band over the room, in rows
CAPTHOLD = 27                   ; ticks it stays: a second and a half
GREYLVL  = 38                   ; the outline's grey, in six bits (150 of 255)

START:  cld
        mov  sp,0FFFEh
        mov  ah,41h                     ; the log starts fresh
        mov  dx,LOGNAME
        int  21h

; ---------------------------------------------------------------------------
;  The command line: a story folder, and /AUTO.
; ---------------------------------------------------------------------------
        mov  si,81h
        movzx cx,byte [80h]
        mov  di,STORYDIR
        mov  byte [GOTDIR],0
CL1:    jcxz CLEND
        lodsb
        dec  cx
        cmp  al,' '
        je   CL1
        cmp  al,13
        je   CLEND
        cmp  al,'/'
        je   CLSW
        cmp  byte [GOTDIR],1            ; a second word is not ours - a batch
        je   CL3                        ; file's EXIT, say - and is skipped
        ; a word: the folder
        mov  byte [GOTDIR],1
CL2:    stosb
        jcxz CLEND0
        lodsb
        dec  cx
        cmp  al,' '
        je   CL1B
        cmp  al,13
        je   CLEND0
        jmp  CL2
CL1B:   mov  byte [di],0
        jmp  CL1
CLEND0: mov  byte [di],0
        jmp  CLEND
CLSW:   ; /AUTO, or anything else starting with a slash: the same thing
        mov  byte [AUTO],1
CL3:    jcxz CLEND
        lodsb
        dec  cx
        cmp  al,' '
        jne  CL3
        jmp  CL1
CLEND:  cmp  byte [GOTDIR],1
        je   HAVEDIR
        mov  si,DEFDIR
        mov  di,STORYDIR
        call STRCPY
HAVEDIR:
        ; a trailing backslash is not wanted
        mov  di,STORYDIR
        call STRLEN
        test cx,cx
        jz   DIROK
        mov  bx,di
        add  bx,cx
        cmp  byte [bx-1],'\'
        jne  DIROK
        mov  byte [bx-1],0
DIROK:  mov  dx,MKDIR
        mov  si,STORYDIR
        call LOGWITH

; ---------------------------------------------------------------------------
;  STORY.INI: START and ORDER.
; ---------------------------------------------------------------------------
        mov  si,STORYDIR
        mov  di,PATHBUF
        call STRCPY
        mov  al,'\'
        stosb
        mov  si,N_STORY
        call STRCPY0
        mov  dx,PATHBUF
        call READTXT
        jc   NOSTORY
        call PARSESTORY
        cmp  byte [STARTID],0
        je   NOSTORY

        mov  si,STARTID
        mov  di,CURID
        call STRCPY0

; ---------------------------------------------------------------------------
;  The machine: the BIOS font, unreal mode, the mouse, the graphics mode.
; ---------------------------------------------------------------------------
        push es
        push bp
        mov  ax,1130h                   ; the ROM's 8x8 font, all 256 glyphs
        mov  bh,3
        int  10h
        mov  [FONTSEG],es
        mov  [FONTOFF],bp
        pop  bp
        pop  es

        call UNREALON
        jc   NOUNREAL

        xor  ax,ax                      ; a mouse driver, if there is one
        int  33h
        cmp  ax,0FFFFh
        jne  NOMOUSE
        mov  byte [MOUSEOK],1
NOMOUSE:
        call REFLAT

        call GFXON
        jc   NOMODE

; ===========================================================================
;  The scene loop
; ===========================================================================
SCENELOOP:
        mov  dx,MKSCENE
        mov  si,CURID
        call LOGWITH

        ; <story>\<scene>\SCENE.INI
        mov  si,N_SCENE
        xor  bx,bx                      ; no subfolder
        call SCENEPATH
        mov  dx,PATHBUF
        call READTXT
        jc   SCENEMISSING
        call PARSESCENE
        movzx eax,word [NSECT]
        mov  di,NUMBUF
        call DEC32TO
        mov  dx,MKSECTS
        mov  si,NUMBUF
        call LOGWITH
        call MUSOPEN                    ; the scene's track, if it names one

        mov  byte [HAVEANS],0
        mov  word [SECTNO],0
SECTLOOP:
        mov  ax,[SECTNO]
        cmp  ax,[NSECT]
        jae  SECTSDONE
        mov  bx,SECTSZ
        mul  bx
        add  ax,SECTTAB
        mov  [CURSECT],ax
        mov  bx,ax
        mov  al,[bx+S_KIND]
        cmp  al,K_VIDEO
        je   DOVIDEO
        cmp  al,K_PICKUP
        je   DOPICKUP
        cmp  al,K_QUIZ
        je   DOQUIZ
        jmp  SECTNEXT

; ---- [VIDEO] ---------------------------------------------------------------
DOVIDEO:
        mov  bx,[CURSECT]
        lea  si,[bx+S_NAME]
        mov  dx,MKVIDEO
        call LOGWITH
        mov  bx,[CURSECT]
        lea  si,[bx+S_NAME]
        xor  bx,bx
        call SCENEPATH
        mov  dx,PATHBUF
        call OWVPLAY
        test al,al
        jnz  VIDMISSING
        cmp  byte [OWVKEY],'q'
        je   QUITGAME
        cmp  byte [OWVKEY],'Q'
        je   QUITGAME
        jmp  SECTNEXT
VIDMISSING:
        call MISSING                    ; PATHBUF names it
        jmp  SECTNEXT

; ---- [QUIZ] ----------------------------------------------------------------
DOQUIZ: call RUNQUIZ                    ; sets ANSWER, HAVEANS
        cmp  byte [QUITFLAG],1
        je   QUITGAME
        jmp  SECTNEXT

; ---- [PICKUP] --------------------------------------------------------------
DOPICKUP:
        call RUNPICKUP
        cmp  byte [QUITFLAG],1
        je   QUITGAME
        jmp  SECTNEXT

SECTNEXT:
        inc  word [SECTNO]
        jmp  SECTLOOP

; ---- the scene is over: an ending, or a code, or nothing ------------------
SECTSDONE:
        call MUSCLOSE
        cmp  byte [SENDING],1
        je   THEEND
        cmp  byte [HAVEANS],1
        jne  SD1
        mov  eax,[ANSWER]
        jmp  SD2
SD1:    cmp  byte [HAVECODE],1
        jne  NOCODE
        mov  eax,[SCODE]
SD2:    mov  [EXITCODE],eax
        mov  di,NUMBUF
        call DEC32TO
        mov  dx,MKCODE
        mov  si,NUMBUF
        call LOGWITH

        call FINDNEXT                   ; -> CURID, or CF
        jc   NONEXT
        jmp  SCENELOOP

; ---- the ways a scene can end the story --------------------------------------
THEEND: mov  dx,MKEND
        call LOGMARK
        mov  si,T_END
        mov  dx,T_KEY
        call MSGBOX
        jmp  QUITGAME

NOCODE: mov  dx,MKNOCODE
        call LOGMARK
        mov  si,T_NOCODE
        mov  dx,T_KEY
        call MSGBOX
        jmp  QUITGAME

NONEXT: mov  dx,MKNONEXT
        mov  si,NUMBUF
        call LOGWITH
        mov  si,T_NONEXT
        mov  dx,T_KEY
        call MSGBOX
        jmp  QUITGAME

SCENEMISSING:
        call MISSING
        jmp  QUITGAME

QUITGAME:
        call MUSCLOSE
        call TEXTMODE
        call SBRELEASE
        mov  dx,MSGDONE
        call PUTS
        jmp  QUIT

NOSTORY:
        mov  dx,MSGNOSTORY
        call PUTS
        mov  dx,PATHBUF
        call PUTZ
        mov  dx,CRLF
        call PUTS
        mov  dx,MKNOSTORY
        mov  si,PATHBUF
        call LOGWITH
        cmp  byte [AUTO],1              ; driven from a batch that will close
        je   QUIT                       ; the emulator, the message must wait
        mov  dx,MSGANYKEY               ; for a person to read it
        call PUTS
        xor  ah,ah
        int  16h
        jmp  QUIT
NOUNREAL:
        mov  dx,MSGNOUNREAL
        call PUTS
        jmp  QUIT
NOMODE: call SBRELEASE
        mov  dx,MSGNOMODE
        call PUTS
QUIT:   mov  ax,4C00h
        int  21h

; ===========================================================================
;  The pickup: the room, the things, the mouse.
; ===========================================================================
RUNPICKUP:
        mov  bx,[CURSECT]
        lea  si,[bx+S_NAME]
        mov  dx,MKPICK
        call LOGWITH

        ; the room: <scene>\<FOLDER>\BG.OWV, one frame, shown by OWVPLAY
        mov  bx,[CURSECT]
        lea  bx,[bx+S_NAME]
        mov  si,N_BG
        call SCENEPATH
        mov  dx,PATHBUF
        call OWVPLAY
        test al,al
        jz   PKROOM
        call MISSING
        ret
PKROOM: mov  eax,[PFRAME]               ; the frame just shown
        mov  [BGFRAME],eax
        call PALCOLS
        ; the room is the rows above the panel; the panel's backing is
        ; already in the frame, laid there by the converter
        mov  bx,[CURSECT]
        mov  ax,HEIGHT
        sub  ax,[bx+S_PANEL]
        cmp  ax,HEIGHT
        ja   PKNOPANEL
        cmp  ax,CAPTH*2
        jb   PKNOPANEL
        mov  [ROOMH],ax
        jmp  PKROOMH
PKNOPANEL:
        mov  word [ROOMH],HEIGHT
PKROOMH:
        mov  byte [CAPTON],0

        ; the things: <scene>\<FOLDER>\<NAME>.SPR, each to its slot
        mov  bx,[CURSECT]
        movzx cx,byte [bx+S_NITEM]
        mov  [NITEMS],cx
        movzx eax,cx
        mov  di,NUMBUF
        call DEC32TO
        mov  dx,MKITEMS
        mov  si,NUMBUF
        call LOGWITH
        xor  cx,cx
PKLOAD: cmp  cx,[NITEMS]
        jae  PKLOADED
        push cx
        call LOADSPR                    ; CX = index
        pop  cx
        inc  cx
        jmp  PKLOAD
PKLOADED:
        call MARKNEED
        call DRAWALL
        call DRAWPANEL                  ; every slot: an outline, nothing taken yet
        call MUSSTART                   ; the card for the room's music
        mov  byte [WASDOWN],0
        mov  word [CURX],320
        mov  word [CURY],200
        cmp  byte [MOUSEOK],1
        jne  PKNOMOUSE
        mov  ax,7                       ; the driver's idea of the screen:
        xor  cx,cx                      ; ours, exactly
        mov  dx,WIDTH-1
        int  33h
        mov  ax,8
        xor  cx,cx
        mov  dx,HEIGHT-1
        int  33h
        mov  ax,4
        mov  cx,[CURX]
        mov  dx,[CURY]
        int  33h
        call REFLAT
PKNOMOUSE:
        call CURSHOW
        call SHOT
        call TICK
        mov  [AUTOT],eax

PKLOOP: ; a key? ESC, Q - or the keyboard as a mouse: the arrows move the
        ; cursor eight pixels, Enter or space clicks. A mouse in an emulator
        ; has to be captured first and in a browser has to be allowed; the
        ; keys always work, and the quests of the period had them too.
        mov  ah,1
        int  16h
        jz   PKNOKEY
        xor  ah,ah
        int  16h
        cmp  al,27
        je   PKDONE
        cmp  al,'q'
        je   PKQUIT
        cmp  al,'Q'
        je   PKQUIT
        cmp  al,13
        je   PKKCLICK
        cmp  al,' '
        je   PKKCLICK
        test al,al                      ; an extended key: the scan code is in AH
        jnz  PKNOKEY
        xor  cx,cx
        xor  dx,dx
        cmp  ah,48h                     ; up
        jne  PKK1
        mov  dx,-8
PKK1:   cmp  ah,50h                     ; down
        jne  PKK2
        mov  dx,8
PKK2:   cmp  ah,4Bh                     ; left
        jne  PKK3
        mov  cx,-8
PKK3:   cmp  ah,4Dh                     ; right
        jne  PKK4
        mov  cx,8
PKK4:   mov  ax,cx
        or   ax,dx
        jz   PKNOKEY
        call CURHIDE
        add  cx,[CURX]
        add  dx,[CURY]
        cmp  cx,0
        jge  PKK5
        xor  cx,cx
PKK5:   cmp  cx,WIDTH-1
        jle  PKK6
        mov  cx,WIDTH-1
PKK6:   cmp  dx,0
        jge  PKK7
        xor  dx,dx
PKK7:   cmp  dx,HEIGHT-1
        jle  PKK8
        mov  dx,HEIGHT-1
PKK8:   mov  [CURX],cx
        mov  [CURY],dx
        cmp  byte [MOUSEOK],1           ; keep the driver in step, or its next
        jne  PKK9                       ; reading pulls the cursor back
        mov  ax,4
        int  33h
        call REFLAT
PKK9:   call CURSHOW
        jmp  PKCHECK
PKKCLICK:
        mov  ax,[CURX]
        mov  dx,[CURY]
        call HITTEST                    ; -> CX, or CF
        jc   PKCHECK
        push cx                         ; CURHIDE counts on CX and hands
        call CURHIDE                    ; back zero - so without this every
        pop  cx                         ; click took thing number 0
        call TAKE
        call CURSHOW
        jmp  PKCHECK
PKNOKEY:
        call REFLAT
        call MUSFEED                    ; the queue kept full from here
        call CAPTCHECK                  ; a caption that has had its time
        ; /AUTO: every AUTOSTEP ticks, take the next thing
        cmp  byte [AUTO],1
        jne  PKMOUSE
        call TICK
        sub  eax,[AUTOT]
        cmp  eax,AUTOSTEP
        jb   PKMOUSE
        call TICK
        mov  [AUTOT],eax
        call NEXTWANTED                 ; -> CX, or CF
        jc   PKMOUSE
        push cx
        call CENTRE                     ; -> AX, DX: the middle of thing CX
        call CURHIDE
        mov  [CURX],ax
        mov  [CURY],dx
        cmp  byte [MOUSEOK],1           ; and the driver's idea of where the
        jne  PKAUTO1                    ; mouse is, or its next reading pulls
        mov  cx,ax                      ; the cursor straight back
        mov  ax,4
        int  33h
        call REFLAT
PKAUTO1:
        call CURSHOW
        pop  cx
        ; and then exactly what a click does - through HITTEST, not straight
        ; to TAKE: the first version took the thing by its index, and the
        ; hit test itself had never once run when a person clicked and
        ; nothing happened
        push cx                         ; the index, for the fallback
        mov  ax,[CURX]
        mov  dx,[CURY]
        call HITTEST
        jc   PKAUTOMISS
        add  sp,2                       ; HITTEST's CX is the thing
        push cx
        call CURHIDE
        pop  cx
        call TAKE
        call CURSHOW
        call SHOT
        jmp  PKCHECK
PKAUTOMISS:
        pop  cx                         ; a miss is logged and the thing is
        push cx                         ; taken by its index anyway, so the
        movzx eax,word [CURX]           ; run goes on and the log says why
        mov  di,MISSX
        call DEC32TO
        mov  byte [di],','
        inc  di
        movzx eax,word [CURY]
        call DEC32TO
        mov  byte [di],13
        mov  byte [di+1],10
        mov  byte [di+2],'$'
        mov  dx,MKMISSED
        call LOGMARK
        call CURHIDE
        pop  cx
        call TAKE
        call CURSHOW
        jmp  PKCHECK

PKMOUSE:
        cmp  byte [MOUSEOK],1
        jne  PKCHECK
        mov  ax,3
        int  33h                        ; BX buttons, CX x, DX y
        call REFLAT
        push bx
        cmp  cx,[CURX]
        jne  PKMOVED
        cmp  dx,[CURY]
        je   PKSTILL
PKMOVED:
        push cx
        push dx
        call CURHIDE
        pop  dx
        pop  cx
        mov  [CURX],cx
        mov  [CURY],dx
        call CURSHOW
PKSTILL:
        pop  bx
        test bl,1
        jz   PKUP
        cmp  byte [WASDOWN],1
        je   PKCHECK
        mov  byte [WASDOWN],1
        ; a click: on a thing?
        mov  ax,[CURX]
        mov  dx,[CURY]
        call HITTEST                    ; -> CX, or CF
        jc   PKCHECK
        push cx                         ; CURHIDE counts on CX and hands
        call CURHIDE                    ; back zero - so without this every
        pop  cx                         ; click took thing number 0
        call TAKE
        call CURSHOW
        jmp  PKCHECK
PKUP:   mov  byte [WASDOWN],0

PKCHECK:
        call ALLTAKEN
        jnc  PKLOOP
        call CAPTWAIT                   ; the last thing's line gets its time
PKDONE: call CURHIDE
        call MUSSTOP
        ret
PKQUIT: mov  byte [QUITFLAG],1
        jmp  PKDONE

; Load thing CX: its .SPR into slot CX above 1 MB, and its .SLT - the
; slot picture for the panel - into the icon slot with the same number. A
; thing without its .SLT has no place on the panel, and the log says so.
LOADSPR:
        mov  [LSIDX],cx
        mov  ax,ITSZ
        mul  cx
        add  ax,ITEMTAB
        mov  [CURIT],ax
        mov  bx,ax
        mov  byte [bx+IT_FLAGS],0
        mov  dword [bx+IT_ICO],0
        ; the name from the section's item list
        mov  ax,SI_SZ
        mul  cx
        mov  bx,[CURSECT]
        add  bx,ax
        lea  si,[bx+S_ITEM]
        mov  di,NAMEBUF
        call STRCPY
        mov  [NAMEEND],di               ; the extension goes here
        mov  si,N_SPR
        call STRCPY0
        mov  dword [LOLIMIT],SPRSLOT
        call LOADOWS                    ; -> SPRHDR, the pixels at BUFLIN
        jc   LSNONE
        mov  eax,SPRSLOT
        movzx ebx,word [LSIDX]
        mul  ebx
        add  eax,SPRBASE
        mov  edi,eax
        mov  bx,[CURIT]
        mov  [bx+IT_ADDR],edi           ; the slot, BEFORE the copy moves EDI
        mov  esi,BUFLIN                 ; (COPYB hands back ECX as zero, so
        movzx ecx,word [SPRHDR+4]       ; "end minus length" was end minus 0)
        movzx eax,word [SPRHDR+6]
        mul  ecx
        mov  ecx,eax
        call COPYB
        mov  bx,[CURIT]
        mov  ax,word [SPRHDR+8]
        mov  [bx+IT_X],ax
        mov  ax,word [SPRHDR+10]
        mov  [bx+IT_Y],ax
        mov  ax,word [SPRHDR+4]
        mov  [bx+IT_W],ax
        mov  ax,word [SPRHDR+6]
        mov  [bx+IT_H],ax
        mov  byte [bx+IT_FLAGS],1
        ; the first dword of the thing, from BUFLIN and from its slot: if
        ; the two differ, the copy above 1 MB is not landing where it is read
        mov  esi,BUFLIN
        mov  eax,[fs:esi]
        mov  di,HEXA
        call HEX32TO
        mov  esi,[bx+IT_ADDR]
        mov  eax,[fs:esi]
        mov  di,HEXB
        call HEX32TO
        mov  eax,[bx+IT_ADDR]
        mov  di,HEXC
        call HEX32TO
        mov  dx,MKSPR
        mov  si,NAMEBUF
        call LOGWITH
        mov  dx,MKHEX
        call LOGMARK

        ; and the slot picture, <NAME>.SLT, into the icon slot
        mov  di,[NAMEEND]
        mov  si,N_SLT
        call STRCPY0
        mov  dword [LOLIMIT],ICOSLOT
        call LOADOWS
        jc   LSNOSLT
        mov  eax,ICOSLOT
        movzx ebx,word [LSIDX]
        mul  ebx
        add  eax,ICOBASE
        mov  edi,eax
        mov  bx,[CURIT]
        mov  [bx+IT_ICO],edi
        mov  esi,BUFLIN
        movzx ecx,word [SPRHDR+4]
        movzx eax,word [SPRHDR+6]
        mul  ecx
        mov  ecx,eax
        call COPYB
        mov  bx,[CURIT]
        mov  ax,word [SPRHDR+8]
        mov  [bx+IT_IX],ax
        mov  ax,word [SPRHDR+10]
        mov  [bx+IT_IY],ax
        mov  ax,word [SPRHDR+4]
        mov  [bx+IT_IW],ax
        mov  ax,word [SPRHDR+6]
        mov  [bx+IT_IH],ax
        ret
LSNOSLT:
        mov  dx,MKNOSLT
        mov  si,NAMEBUF
        call LOGWITH
        ret
LSNONE: ; a thing without its .SPR is not there; the log says so
        mov  dx,MKNOSPR
        mov  si,PATHBUF
        call LOGWITH
        ret

; An OWS1 file, <scene>\<FOLDER>\NAMEBUF: the sixteen-byte header into
; SPRHDR, the pixels to BUFLIN. CF = not there, not an OWS1, or bigger
; than [LOLIMIT] - the last two are logged, the first is the caller's.
LOADOWS:
        mov  bx,[CURSECT]
        lea  bx,[bx+S_NAME]
        mov  si,NAMEBUF
        call SCENEPATH
        mov  ax,3D00h
        mov  dx,PATHBUF
        int  21h
        jc   LONONE
        mov  [FH],ax
        mov  bx,ax
        mov  cx,16
        mov  dx,SPRHDR
        mov  ah,3Fh
        int  21h
        call REFLAT
        cmp  ax,16
        jne  LOBAD
        cmp  dword [SPRHDR],'OWS1'
        jne  LOBAD
        movzx ecx,word [SPRHDR+4]
        movzx eax,word [SPRHDR+6]
        mul  ecx                        ; eax = w*h
        mov  ecx,eax
        cmp  ecx,[LOLIMIT]
        ja   LOBAD
        call READPAY                    ; -> BUFLIN
        mov  bx,[FH]
        mov  ah,3Eh
        int  21h
        call REFLAT
        clc
        ret
LOBAD:  mov  dx,MKBADSPR
        mov  si,NAMEBUF
        call LOGWITH
        mov  bx,[FH]
        mov  ah,3Eh
        int  21h
LONONE: call REFLAT
        stc
        ret

; Which things must be taken: the ones named in NEED, or all of them.
MARKNEED:
        mov  word [MNIDX],0
MN1:    mov  dx,[MNIDX]
        cmp  dx,[NITEMS]
        jae  MNDONE
        mov  di,dx
        shl  di,5                       ; ITSZ = 32
        add  di,ITEMTAB
        test byte [di+IT_FLAGS],1
        jz   MN2                        ; not loaded: never needed
        mov  bx,[CURSECT]
        mov  cx,[bx+S_NEEDL]
        test cx,cx
        jz   MNALL                      ; no NEED line: everything is needed
        mov  ax,SI_SZ
        mul  dx
        mov  bx,[CURSECT]
        add  bx,ax
        lea  si,[bx+S_ITEM]             ; the name
        mov  bx,[CURSECT]
        push di
        mov  di,[bx+S_NEEDO]
        add  di,INIBUF                  ; the NEED list
        call INLIST                     ; CF = not there
        pop  di
        jc   MN2
MNALL:  or   byte [di+IT_FLAGS],4
MN2:    inc  word [MNIDX]
        jmp  MN1
MNDONE: ret

; Is the name at DS:SI (0-terminated) a word of the list at DS:DI, CX long?
INLIST: push si
        push di
        push cx
IL1:    test cx,cx
        jz   ILNO
        cmp  byte [di],' '
        je   ILSKIP
        ; compare a word
        push si
        push di
        push cx
IL2:    lodsb
        test al,al
        jz   IL3
        test cx,cx
        jz   IL4
        cmp  al,[di]
        jne  IL4
        inc  di
        dec  cx
        jmp  IL2
IL3:    ; the name ended: the word must end too
        test cx,cx
        jz   ILYES
        cmp  byte [di],' '
        je   ILYES
IL4:    pop  cx
        pop  di
        pop  si
        ; skip this word
IL5:    test cx,cx
        jz   ILNO
        cmp  byte [di],' '
        je   IL1
        inc  di
        dec  cx
        jmp  IL5
ILSKIP: inc  di
        dec  cx
        jmp  IL1
ILYES:  pop  cx
        pop  di
        pop  si
        pop  cx
        pop  di
        pop  si
        clc
        ret
ILNO:   pop  cx
        pop  di
        pop  si
        stc
        ret

; Draw every thing that is loaded and not taken.
DRAWALL:
        xor  cx,cx
DA1:    cmp  cx,[NITEMS]
        jae  DADONE
        push cx
        call DRAWSPR
        pop  cx
        inc  cx
        jmp  DA1
DADONE: ret

; Thing CX onto the screen, clipped, index 255 skipped.
DRAWSPR:
        mov  ax,ITSZ
        mul  cx
        add  ax,ITEMTAB
        mov  bx,ax
        mov  al,[bx+IT_FLAGS]
        and  al,3
        cmp  al,1                       ; loaded and not taken
        jne  DSDONE
        movsx eax,word [bx+IT_Y]
        movzx ecx,word [bx+IT_H]
        mov  esi,[bx+IT_ADDR]
DSROW:  test ecx,ecx
        jz   DSDONE
        cmp  eax,0
        jl   DSNEXT
        movzx edx,word [ROOMH]          ; the room ends where the panel starts
        cmp  eax,edx
        jge  DSDONE
        push ecx
        push eax
        ; the row: x from IT_X, w pixels
        imul eax,WIDTH
        add  eax,[LFB]
        movsx edx,word [bx+IT_X]
        add  eax,edx                    ; eax = screen address of (x, y)
        mov  edi,eax
        movzx ecx,word [bx+IT_W]
        push esi
DSPIX:  cmp  edx,0
        jl   DSSKIP
        cmp  edx,WIDTH
        jge  DSSKIP
        mov  al,[fs:esi]
        cmp  al,255
        je   DSSKIP
        mov  [fs:edi],al
DSSKIP: inc  esi
        inc  edi
        inc  edx
        dec  ecx
        jnz  DSPIX
        pop  esi
        pop  eax
        pop  ecx
        jmp  DSNEXT2
DSNEXT: push eax
        pop  eax
DSNEXT2:
        movzx edx,word [bx+IT_W]
        add  esi,edx                    ; next source row
        inc  eax
        dec  ecx
        jmp  DSROW
DSDONE: ret

; The room back over thing CX's rectangle.
RESTBG:
        mov  ax,ITSZ
        mul  cx
        add  ax,ITEMTAB
        mov  bx,ax
        movsx eax,word [bx+IT_Y]
        movzx ecx,word [bx+IT_H]
RSROW:  test ecx,ecx
        jz   RSDONE
        cmp  eax,0
        jl   RSNEXT
        movzx edx,word [ROOMH]
        cmp  eax,edx
        jge  RSDONE
        push ecx
        push eax
        movsx edx,word [bx+IT_X]
        movzx ecx,word [bx+IT_W]
        ; clip the row to the screen
        cmp  edx,0
        jge  RS1
        add  ecx,edx                    ; fewer pixels
        xor  edx,edx
RS1:    mov  edi,edx
        add  edi,ecx
        cmp  edi,WIDTH
        jle  RS2
        mov  ecx,WIDTH
        sub  ecx,edx
RS2:    cmp  ecx,0
        jle  RS3
        imul eax,WIDTH
        add  eax,edx
        mov  esi,eax
        mov  edi,eax
        add  esi,[BGFRAME]
        add  edi,[LFB]
        call COPYB
RS3:    pop  eax
        pop  ecx
RSNEXT: inc  eax
        dec  ecx
        jmp  RSROW
RSDONE: ret

; Take thing CX: gone from the screen, the others drawn again on top.
TAKE:   push cx
        mov  ax,ITSZ
        mul  cx
        add  ax,ITEMTAB
        mov  bx,ax
        or   byte [bx+IT_FLAGS],2
        pop  cx
        push cx
        call RESTBG
        call DRAWALL
        pop  cx
        push cx
        call SLOTON                     ; its slot turns to colour
        pop  cx
        push cx
        call CAPTION                    ; and its line, if it has one
        pop  cx
        ; the log: which one
        mov  ax,SI_SZ
        mul  cx
        mov  bx,[CURSECT]
        add  bx,ax
        lea  si,[bx+S_ITEM]
        mov  dx,MKTAKE
        call LOGWITH
        ret

; The thing under (AX, DX): CX, or CF if the click hit only the room. The
; last thing drawn is on top, so the search runs from the last one back.
; Two passes. First by the thing's own pixels, so that where two things
; overlap the one actually under the cursor wins; then, if nothing was
; under it, by the rectangle - because the middle of a glass ashtray is
; see-through, and a player who clicks on the ashtray has clicked on the
; ashtray. The quests of the period used rectangles and nothing else.
HITTEST:
        mov  [HX],ax
        mov  [HY],dx
        cmp  dx,[ROOMH]                 ; the panel is not the room: a click
        jae  HTNO                       ; there takes nothing
        mov  byte [HTPASS],0
HTPASS0:
        mov  cx,[NITEMS]
HT1:    test cx,cx
        jz   HTAGAIN
        dec  cx
        mov  bx,cx
        shl  bx,5                       ; ITSZ = 32
        add  bx,ITEMTAB
        mov  al,[bx+IT_FLAGS]
        and  al,3
        cmp  al,1
        jne  HT1
        mov  ax,[HX]
        sub  ax,[bx+IT_X]               ; ax = x within the thing
        jl   HT1
        cmp  ax,[bx+IT_W]
        jge  HT1
        mov  dx,[HY]
        sub  dx,[bx+IT_Y]
        jl   HT1
        cmp  dx,[bx+IT_H]
        jge  HT1
        ; inside the rectangle: is there an opaque pixel of the thing within
        ; three of the click? Exactly the pixel under it is not enough - the
        ; middle of a glass ashtray is see-through, and a click on its
        ; centre found nothing.
        mov  [HTX],ax
        mov  [HTY],dx
        cmp  byte [HTPASS],1            ; the second pass: the rectangle is enough
        je   HTHIT
        mov  si,-3
HTY1:   mov  di,-3
HTX1:   mov  ax,[HTX]
        add  ax,di
        jl   HTNEXTX
        cmp  ax,[bx+IT_W]
        jge  HTNEXTX
        mov  dx,[HTY]
        add  dx,si
        jl   HTNEXTX
        cmp  dx,[bx+IT_H]
        jge  HTNEXTX
        push esi
        movzx esi,dx
        movzx edx,word [bx+IT_W]
        imul esi,edx
        movzx eax,ax
        add  esi,eax
        add  esi,[bx+IT_ADDR]
        cmp  byte [fs:esi],255
        pop  esi
        jne  HTHIT
HTNEXTX:
        inc  di
        cmp  di,3
        jle  HTX1
        inc  si
        cmp  si,3
        jle  HTY1
        jmp  HT1
HTHIT:  clc
        ret
HTAGAIN:
        cmp  byte [HTPASS],1
        je   HTNO
        mov  byte [HTPASS],1
        jmp  HTPASS0
HTNO:   stc
        ret

; The next thing that is wanted and still there: CX, or CF.
NEXTWANTED:
        xor  cx,cx
NW1:    cmp  cx,[NITEMS]
        jae  NWNO
        mov  ax,ITSZ
        mul  cx
        add  ax,ITEMTAB
        mov  bx,ax
        mov  al,[bx+IT_FLAGS]
        and  al,7
        cmp  al,5                       ; loaded, needed, not taken
        je   NWYES
        inc  cx
        jmp  NW1
NWYES:  clc
        ret
NWNO:   stc
        ret

; Every needed thing taken? CF = yes.
ALLTAKEN:
        call NEXTWANTED
        jnc  ATNO
        stc
        ret
ATNO:   clc
        ret

; The middle of thing CX -> AX, DX, clamped to the screen.
CENTRE: mov  ax,ITSZ
        mul  cx
        add  ax,ITEMTAB
        mov  bx,ax
        mov  ax,[bx+IT_W]
        shr  ax,1
        add  ax,[bx+IT_X]
        mov  dx,[bx+IT_H]
        shr  dx,1
        add  dx,[bx+IT_Y]
        cmp  ax,0
        jge  CE1
        xor  ax,ax
CE1:    cmp  ax,WIDTH-1
        jle  CE2
        mov  ax,WIDTH-1
CE2:    cmp  dx,0
        jge  CE3
        xor  dx,dx
CE3:    mov  cx,[ROOMH]                 ; inside the room, not the panel
        dec  cx
        cmp  dx,cx
        jle  CE4
        mov  dx,cx
CE4:    ret

; ---------------------------------------------------------------------------
;  The cursor: sixteen by sixteen, drawn by hand with what was under it kept
;  aside. The mouse driver draws its own cursor in the modes it knows, and
;  a VESA mode is not one of them.
; ---------------------------------------------------------------------------
; Both keep every register: the first version of CURHIDE left the screen
; address in EDX and its loop count in CX, and the caller that had just
; computed a position in AX,DX stored the address instead - the cursor
; went to "257,62784" and every hit test missed.
CURSHOW:
        cmp  byte [CURON],1
        je   CSDONE
        pushad
        call CURADDR                    ; -> edi, and CURDX/CURDY set
        ; keep what is under it
        push edi
        mov  si,CURSAVE
        mov  cx,16
CS1:    push cx
        mov  cx,16
CS2:    mov  al,[fs:edi]
        mov  [si],al
        inc  si
        inc  edi
        loop CS2
        pop  cx
        add  edi,WIDTH-16
        loop CS1
        pop  edi
        ; the outline in black, the arrow in white
        mov  bx,CUROUT
        mov  al,[BLACK]
        call CURBITS
        mov  bx,CURIN
        mov  al,[WHITE]
        call CURBITS
        mov  byte [CURON],1
        popad
CSDONE: ret

; Sixteen rows of sixteen bits at DS:BX, colour AL, at FS:EDI.
CURBITS:
        push edi
        mov  cx,16
CB1A:   push cx
        mov  dx,[bx]
        add  bx,2
        mov  cx,16
CB2A:   shl  dx,1
        jnc  CB3A
        mov  [fs:edi],al
CB3A:   inc  edi
        loop CB2A
        pop  cx
        add  edi,WIDTH-16
        loop CB1A
        pop  edi
        ret

; Restores at the place the cursor was DRAWN (CURDX/CURDY), whatever CURX
; and CURY say by now - they may already hold the next position.
CURHIDE:
        cmp  byte [CURON],1
        jne  CHDONE
        pushad
        mov  edi,[CURDY]
        imul edi,WIDTH
        add  edi,[CURDX]
        add  edi,[LFB]
        mov  si,CURSAVE
        mov  cx,16
CH1:    push cx
        mov  cx,16
CH2:    mov  al,[si]
        mov  [fs:edi],al
        inc  si
        inc  edi
        loop CH2
        pop  cx
        add  edi,WIDTH-16
        loop CH1
        mov  byte [CURON],0
        popad
CHDONE: ret

; Where the cursor is drawn: its position, kept inside the screen.
CURADDR:
        movzx eax,word [CURX]
        cmp  eax,WIDTH-16
        jbe  CA1
        mov  eax,WIDTH-16
CA1:    mov  [CURDX],eax
        movzx edx,word [CURY]
        cmp  edx,HEIGHT-16
        jbe  CA2
        mov  edx,HEIGHT-16
CA2:    mov  [CURDY],edx
        imul edx,WIDTH
        add  edx,eax
        add  edx,[LFB]
        mov  edi,edx
        ret

; ===========================================================================
;  The quiz: the question and its answers over the last frame.
; ===========================================================================
RUNQUIZ:
        call PALCOLS
        mov  bx,[CURSECT]
        movzx cx,byte [bx+S_NOPT]
        mov  [NOPTS],cx
        ; the box: a line for the question, one per answer, 24 pixels each
        inc  cx
        mov  ax,24
        mul  cx
        add  ax,16
        mov  [RHGT],ax
        mov  cx,HEIGHT
        sub  cx,ax
        mov  [RY],cx
        mov  word [RX],0
        mov  word [RWID],WIDTH
        mov  al,[BLACK]
        call FILLRECT

        mov  word [TX],8
        mov  ax,[RY]
        add  ax,8
        mov  [TY],ax
        mov  bx,[CURSECT]
        mov  si,[bx+S_TOFF]
        add  si,INIBUF
        mov  cx,[bx+S_TLEN]
        call DRAWTXT

        xor  dx,dx                      ; answer index
QZ1:    cmp  dx,[NOPTS]
        jae  QZDRAWN
        push dx
        add  word [TY],24
        mov  word [TX],8
        mov  al,dl
        add  al,'1'
        mov  [DIGIT],al
        mov  si,DIGIT
        mov  cx,2                       ; the digit and a space
        call DRAWTXT
        pop  dx
        push dx
        mov  ax,6
        mul  dx
        mov  bx,[CURSECT]
        add  bx,ax
        mov  si,[bx+S_OPT+2]
        add  si,INIBUF
        mov  cx,[bx+S_OPT+4]
        call DRAWTXT
        pop  dx
        inc  dx
        jmp  QZ1
QZDRAWN:
        call SHOT
        mov  dx,MKQUIZ
        call LOGMARK
        call MUSSTART                   ; the scene's music under the question
        call TICK
        mov  [AUTOT],eax
QZWAIT: mov  ah,1
        int  16h
        jz   QZNOKEY
        xor  ah,ah
        int  16h
        cmp  al,27
        je   QZFIRST
        cmp  al,'q'
        je   QZQUIT
        cmp  al,'Q'
        je   QZQUIT
        sub  al,'1'
        jb   QZNOKEY
        movzx dx,al
        cmp  dx,[NOPTS]
        jae  QZNOKEY
        jmp  QZPICK
QZNOKEY:
        call REFLAT
        call MUSFEED
        cmp  byte [AUTO],1
        jne  QZWAIT
        call TICK
        sub  eax,[AUTOT]
        cmp  eax,AUTOWAIT
        jb   QZWAIT
QZFIRST:
        xor  dx,dx
QZPICK: ; answer DX -> its code
        mov  ax,6
        mul  dx
        mov  bx,[CURSECT]
        add  bx,ax
        movzx eax,word [bx+S_OPT]
        mov  [ANSWER],eax
        mov  byte [HAVEANS],1
        mov  di,NUMBUF
        call DEC32TO
        mov  dx,MKANSWER
        mov  si,NUMBUF
        call LOGWITH
        call MUSSTOP
        ret
QZQUIT: mov  byte [QUITFLAG],1
        call MUSSTOP
        ret

; ===========================================================================
;  Text on the screen, from the ROM's 8x8 font, doubled.
; ===========================================================================
; DS:SI, CX bytes, at [TX],[TY]; TX advances. Stops at the right edge.
DRAWTXT:
        jcxz DTDONE
DT1:    cmp  word [TX],WIDTH-16
        ja   DTDONE
        push cx
        lodsb
        cmp  al,13
        je   DTSKIP
        cmp  al,10
        je   DTSKIP
        call DRAWCHAR
        add  word [TX],16
DTSKIP: pop  cx
        loop DT1
DTDONE: ret

; AL at [TX],[TY] in [WHITE], 2x2 pixels a dot.
DRAWCHAR:
        push si
        push es
        movzx bx,al
        shl  bx,3
        add  bx,[FONTOFF]
        mov  es,[FONTSEG]
        movzx eax,word [TY]
        imul eax,WIDTH
        movzx edx,word [TX]
        add  eax,edx
        add  eax,[LFB]
        mov  edi,eax                    ; top left of the cell
        mov  cx,8
DC1:    push cx
        mov  dl,[es:bx]                 ; one row of the glyph
        inc  bx
        mov  cx,8
        mov  al,[WHITE]
DC2:    shl  dl,1
        jnc  DC3
        mov  [fs:edi],al
        mov  [fs:edi+1],al
        mov  [fs:edi+WIDTH],al
        mov  [fs:edi+WIDTH+1],al
DC3:    add  edi,2
        loop DC2
        add  edi,WIDTH*2-16             ; two rows down, back to the left
        pop  cx
        loop DC1
        pop  es
        pop  si
        ret

; A rectangle [RX],[RY],[RWID],[RHGT] of colour AL.
FILLRECT:
        movzx edi,word [RY]
        imul edi,WIDTH
        movzx edx,word [RX]
        add  edi,edx
        add  edi,[LFB]
        movzx ecx,word [RHGT]
FR1:    push ecx
        push edi
        movzx ecx,word [RWID]
FR2:    mov  [fs:edi],al
        inc  edi
        dec  ecx
        jnz  FR2
        pop  edi
        add  edi,WIDTH
        pop  ecx
        dec  ecx
        jnz  FR1
        ret

; The brightest and the darkest entries of the palette in HDRBUF: every
; clip has its own colours, and text has to be readable over all of them.
; And the entry nearest a mid grey, for the outlines on the panel - a
; night-time palette has few greys, so "nearest" is measured as the
; distance from the grey level AND the distance from being grey at all,
; or a strong colour of the right brightness would win.
PALCOLS:
        mov  si,HDRBUF+32
        xor  cx,cx
        mov  word [PMAX],0
        mov  word [PMIN],0FFFFh
        mov  word [PGREY],0FFFFh
PC1:    movzx ax,byte [si]
        movzx bx,byte [si+1]
        add  ax,bx
        movzx bx,byte [si+2]
        add  ax,bx
        cmp  ax,[PMAX]
        jbe  PC2
        mov  [PMAX],ax
        mov  [WHITE],cl
PC2:    cmp  ax,[PMIN]
        jae  PC3
        mov  [PMIN],ax
        mov  [BLACK],cl
PC3:    push cx
        movzx ax,byte [si]              ; r
        movzx bx,byte [si+1]            ; g
        movzx dx,byte [si+2]            ; b
        add  si,3
        xor  cx,cx
        mov  di,ax
        sub  di,GREYLVL
        call ABSADD                     ; cx += |r - grey|
        mov  di,bx
        sub  di,GREYLVL
        call ABSADD
        mov  di,dx
        sub  di,GREYLVL
        call ABSADD
        mov  di,ax
        sub  di,bx
        call ABSADD                     ; cx += |r - g|
        mov  di,bx
        sub  di,dx
        call ABSADD                     ; cx += |g - b|
        mov  di,cx
        pop  cx
        cmp  di,[PGREY]
        jae  PC4
        mov  [PGREY],di
        mov  [GREY],cl
PC4:    inc  cx
        cmp  cx,256
        jb   PC1
        ret
ABSADD: test di,di
        jns  AA1
        neg  di
AA1:    add  cx,di
        ret

; ---------------------------------------------------------------------------
;  A message: two lines in a box at the top, a key (or a second) to go on.
;  DS:SI the first line, DS:DX the second, both 0-terminated.
; ---------------------------------------------------------------------------
MSGBOX: push dx
        push si
        call PALCOLS
        mov  word [RX],0
        mov  word [RY],0
        mov  word [RWID],WIDTH
        mov  word [RHGT],56
        mov  al,[BLACK]
        call FILLRECT
        pop  si
        mov  word [TX],8
        mov  word [TY],8
        call STRLEN2                    ; -> CX
        call DRAWTXT
        pop  si
        mov  word [TX],8
        mov  word [TY],32
        call STRLEN2
        call DRAWTXT
        call SHOT
        call WAITKEY
        ret

; MISSING: PATHBUF is the file that is not there.
MISSING:
        mov  dx,MKMISS
        mov  si,PATHBUF
        call LOGWITH
        mov  si,T_MISSING
        mov  dx,PATHBUF
        call MSGBOX
        ret

; Any key - or, in /AUTO, a second. Q sets the quit flag either way.
WAITKEY:
        call TICK
        mov  [AUTOT],eax
WK1:    mov  ah,1
        int  16h
        jz   WK2
        xor  ah,ah
        int  16h
        cmp  al,'q'
        je   WKQ
        cmp  al,'Q'
        je   WKQ
        jmp  WKDONE
WK2:    call REFLAT
        cmp  byte [AUTO],1
        jne  WK1
        call TICK
        sub  eax,[AUTOT]
        cmp  eax,AUTOWAIT
        jb   WK1
WKDONE: call REFLAT
        ret
WKQ:    mov  byte [QUITFLAG],1
        jmp  WKDONE

; ===========================================================================
;  SHOT - the screen to SHOTnn.OWV, in /AUTO: a one-frame OWV of what is on
;  the screen right now, palette and all, that the desk's --dump can render.
;  The KEY chunk is all literal runs of 128 - no compression, no thought.
; ===========================================================================
SHOT:   cmp  byte [AUTO],1
        jne  SHDONE
        pushad
        inc  byte [SHOTNO]
        mov  al,[SHOTNO]
        cmp  al,99
        ja   SHEXIT
        aam                             ; tens in AH, units in AL
        add  ax,'00'
        mov  [SHOTNAME+4],ah
        mov  [SHOTNAME+5],al
        mov  ah,3Ch
        xor  cx,cx
        mov  dx,SHOTNAME
        int  21h
        jc   SHEXIT
        mov  [SHFH],ax
        ; the header: the clip's, with one silent frame
        mov  si,HDRBUF
        mov  di,IOBUF
        mov  cx,800
        rep  movsb
        mov  byte [IOBUF+9],0
        mov  word [IOBUF+10],1
        mov  word [IOBUF+12],0
        mov  bx,[SHFH]
        mov  cx,800
        mov  dx,IOBUF
        mov  ah,40h
        int  21h
        ; the KEY chunk header
        mov  byte [IOBUF],CH_KEY
        mov  byte [IOBUF+1],0
        mov  dword [IOBUF+2],PLANE+PLANE/128
        mov  cx,6
        mov  dx,IOBUF
        mov  ah,40h
        int  21h
        call REFLAT
        ; 2000 runs of 128, 31 to a write: 31 * 129 = 3999 bytes, which is
        ; what fits in IOBUF. 62 did not, and the overflow ran off the end of
        ; the segment and over the program's own start.
        mov  esi,[LFB]
        mov  word [SHRUNS],PLANE/128
SH1:    mov  di,IOBUF
        mov  cx,31
        cmp  cx,[SHRUNS]
        jbe  SH2
        mov  cx,[SHRUNS]
SH2:    jcxz SHEND
        sub  [SHRUNS],cx
        push cx
SH3:    mov  byte [di],7Fh              ; a literal run of 128
        inc  di
        push cx
        mov  cx,32
SH4:    mov  eax,[fs:esi]
        mov  [di],eax
        add  esi,4
        add  di,4
        loop SH4
        pop  cx
        loop SH3
        pop  cx
        mov  ax,129
        mul  cx
        mov  cx,ax
        mov  bx,[SHFH]
        mov  dx,IOBUF
        mov  ah,40h
        int  21h
        call REFLAT
        jmp  SH1
SHEND:  mov  byte [IOBUF],CH_END
        mov  byte [IOBUF+1],0
        mov  dword [IOBUF+2],0
        mov  bx,[SHFH]
        mov  cx,6
        mov  dx,IOBUF
        mov  ah,40h
        int  21h
        mov  ah,3Eh
        int  21h
        call REFLAT
        mov  dx,MKSHOT
        mov  si,SHOTNAME
        call LOGWITH
SHEXIT: popad
SHDONE: ret

; ===========================================================================
;  The INI files
; ===========================================================================

; DS:DX = a path. The file into INIBUF, 0-terminated. CF = not there.
READTXT:
        mov  ax,3D00h
        int  21h
        jc   RTNO
        mov  bx,ax
        mov  cx,INISZ-1
        mov  dx,INIBUF
        mov  ah,3Fh
        int  21h
        jc   RTCLOSE
        mov  di,ax
        mov  byte [di+INIBUF],0
        mov  ah,3Eh
        int  21h
        call REFLAT
        clc
        ret
RTCLOSE:
        mov  ah,3Eh
        int  21h
RTNO:   call REFLAT
        stc
        ret

; ---- STORY.INI: START and ORDER -------------------------------------------
PARSESTORY:
        mov  byte [STARTID],0
        mov  word [NORDER],0
        mov  word [INIPOS],INIBUF
PS1:    call NEXTLINE                   ; -> SI at a key, or CF at the end
        jc   PSDONE
        cmp  byte [LINEKIND],2          ; a key line?
        jne  PS1
        mov  di,KEYBUF
        mov  bx,K_START
        call STREQ
        jnc  PSSTART
        mov  bx,K_ORDER
        call STREQ
        jnc  PSORDER
        jmp  PS1
PSSTART:
        mov  si,[VALOFF]
        mov  cx,[VALLEN]
        mov  di,STARTID
        call COPYNAME
        jmp  PS1
PSORDER:
        mov  si,[VALOFF]
        mov  cx,[VALLEN]
        mov  di,ORDERTAB
PO1:    ; skip spaces
        jcxz PS1
        cmp  byte [si],' '
        jne  PO2
        inc  si
        dec  cx
        jmp  PO1
PO2:    cmp  word [NORDER],MAXORDER
        jae  PS1
        push di
        call COPYNAME                   ; one word into DI, SI/CX past it
        pop  di
        add  di,NAMESZ
        inc  word [NORDER]
        jmp  PO1
PSDONE: ret

; ---- SCENE.INI: the code, the ending, the sections ------------------------
PARSESCENE:
        mov  byte [HAVECODE],0
        mov  byte [SENDING],0
        mov  byte [MUSNAME],0
        mov  word [NSECT],0
        mov  word [CURSECT],0
        mov  word [INIPOS],INIBUF
PC1A:   call NEXTLINE
        jc   PCDONE
        cmp  byte [LINEKIND],1
        je   PCSECT
        cmp  byte [LINEKIND],2
        jne  PC1A
        mov  bx,[CURSECT]
        test bx,bx
        jnz  PCINSECT
        ; top level: CODE, ENDING, MUSIC
        mov  di,KEYBUF
        mov  bx,K_CODE
        call STREQ
        jnc  PCCODE
        mov  bx,K_ENDING
        call STREQ
        jnc  PCENDING
        mov  bx,K_MUSIC
        call STREQ
        jnc  PCMUSIC
        jmp  PC1A
PCMUSIC:
        mov  si,[VALOFF]
        mov  cx,[VALLEN]
        mov  di,MUSNAME
        call COPYNAME
        jmp  PC1A
PCCODE: mov  si,[VALOFF]
        mov  cx,[VALLEN]
        jcxz PC1A
        call PARSENUM
        jc   PC1A
        mov  [SCODE],eax
        mov  byte [HAVECODE],1
        jmp  PC1A
PCENDING:
        mov  si,[VALOFF]
        mov  al,[si]
        cmp  al,'y'
        je   PCEY
        cmp  al,'Y'
        jne  PC1A
PCEY:   mov  byte [SENDING],1
        jmp  PC1A

PCSECT: ; [NAME]: a new section, if the name is one of ours
        mov  di,KEYBUF
        mov  bx,K_VIDEON
        call STREQ
        mov  al,K_VIDEO
        jnc  PCNEW
        mov  bx,K_PICKUPN
        call STREQ
        mov  al,K_PICKUP
        jnc  PCNEW
        mov  bx,K_QUIZN
        call STREQ
        mov  al,K_QUIZ
        jnc  PCNEW
        mov  word [CURSECT],0           ; an unknown section: its keys are skipped
        jmp  PC1A
PCNEW:  cmp  word [NSECT],MAXSECT
        jae  PC1A
        push ax
        mov  ax,SECTSZ
        mul  word [NSECT]
        add  ax,SECTTAB
        mov  [CURSECT],ax
        inc  word [NSECT]
        mov  di,ax
        mov  cx,SECTSZ
        push di
        xor  al,al
        rep  stosb
        pop  di
        pop  ax
        mov  [di+S_KIND],al
        jmp  PC1A

PCINSECT:
        mov  al,[bx+S_KIND]
        cmp  al,K_VIDEO
        je   PCV
        cmp  al,K_PICKUP
        je   PCP
        jmp  PCQ
PCV:    mov  di,KEYBUF
        mov  bx,K_FILE
        call STREQ
        jc   PC1A
PCNAME: mov  bx,[CURSECT]
        lea  di,[bx+S_NAME]
        mov  si,[VALOFF]
        mov  cx,[VALLEN]
        call COPYNAME
        jmp  PC1A
PCP:    mov  di,KEYBUF
        mov  bx,K_FOLDER
        call STREQ
        jnc  PCNAME
        mov  bx,K_NEED
        call STREQ
        jnc  PCNEED
        mov  bx,K_ITEM
        call STREQ
        jnc  PCITEM
        mov  bx,K_PANEL
        call STREQ
        jnc  PCPANEL
        mov  bx,K_TEXT
        call STREQ
        jnc  PCITEXT
        jmp  PC1A
PCPANEL:
        mov  si,[VALOFF]
        mov  cx,[VALLEN]
        call PARSENUM
        jc   PC1A
        mov  bx,[CURSECT]
        mov  [bx+S_PANEL],ax
        jmp  PC1A
PCITEXT:
        ; TEXT <item> = a line: to the item of that name, if it is one of
        ; the section's - the desk writes the ITEM lines first
        mov  bx,[CURSECT]
        movzx cx,byte [bx+S_NITEM]
        lea  bx,[bx+S_ITEM]
PT1:    test cx,cx
        jz   PC1A
        mov  di,SUBBUF
        call STREQ                      ; DS:DI against DS:BX, the name
        jnc  PT2
        add  bx,SI_SZ
        dec  cx
        jmp  PT1
PT2:    mov  ax,[VALOFF]
        sub  ax,INIBUF
        mov  [bx+SI_TOFF],ax
        mov  ax,[VALLEN]
        mov  [bx+SI_TLEN],ax
        jmp  PC1A
PCNEED: mov  bx,[CURSECT]
        mov  ax,[VALOFF]
        sub  ax,INIBUF
        mov  [bx+S_NEEDO],ax
        mov  ax,[VALLEN]
        mov  [bx+S_NEEDL],ax
        jmp  PC1A
PCITEM: mov  bx,[CURSECT]
        movzx ax,byte [bx+S_NITEM]
        cmp  ax,MAXITEMS
        jae  PC1A
        inc  byte [bx+S_NITEM]
        mov  cx,SI_SZ
        mul  cx
        add  bx,ax
        lea  di,[bx+S_ITEM]
        mov  si,SUBBUF                  ; the item's name, from the key
        mov  cx,8
PI1:    lodsb
        test al,al
        jz   PI2
        stosb
        loop PI1
PI2:    mov  byte [di],0
        jmp  PC1A
PCQ:    mov  di,KEYBUF
        mov  bx,K_TEXT
        call STREQ
        jnc  PCTEXT
        mov  bx,K_OPTION
        call STREQ
        jnc  PCOPT
        jmp  PC1A
PCTEXT: mov  bx,[CURSECT]
        mov  ax,[VALOFF]
        sub  ax,INIBUF
        mov  [bx+S_TOFF],ax
        mov  ax,[VALLEN]
        mov  [bx+S_TLEN],ax
        jmp  PC1A
PCOPT:  mov  bx,[CURSECT]
        movzx ax,byte [bx+S_NOPT]
        cmp  ax,MAXOPT
        jae  PC1A
        push bx
        mov  cx,6
        mul  cx
        add  bx,ax
        lea  di,[bx+S_OPT]
        mov  si,SUBBUF
        mov  cx,8
        call PARSENUM
        pop  bx
        jc   PC1A
        mov  [di],ax
        mov  ax,[VALOFF]
        sub  ax,INIBUF
        mov  [di+2],ax
        mov  ax,[VALLEN]
        mov  [di+4],ax
        inc  byte [bx+S_NOPT]
        jmp  PC1A
PCDONE: ret

; ---- the next scene: the first in ORDER whose ENTERS holds EXITCODE --------
FINDNEXT:
        xor  cx,cx
FN1:    cmp  cx,[NORDER]
        jae  FNNO
        push cx
        mov  ax,NAMESZ
        mul  cx
        add  ax,ORDERTAB
        mov  si,ax
        mov  di,CANDID
        call STRCPY0
        ; <story>\<candidate>\SCENE.INI
        mov  si,STORYDIR
        mov  di,PATHBUF
        call STRCPY
        mov  al,'\'
        stosb
        mov  si,CANDID
        call STRCPY
        mov  al,'\'
        stosb
        mov  si,N_SCENE
        call STRCPY0
        mov  dx,PATHBUF
        call READTXT
        jc   FNNEXT
        mov  word [INIPOS],INIBUF
FN2:    call NEXTLINE
        jc   FNNEXT
        cmp  byte [LINEKIND],2
        jne  FN2
        mov  di,KEYBUF
        mov  bx,K_ENTERS
        call STREQ
        jc   FN2
        ; the list of numbers
        mov  si,[VALOFF]
        mov  cx,[VALLEN]
FN3:    jcxz FNNEXT
        cmp  byte [si],' '
        jne  FN4
        inc  si
        dec  cx
        jmp  FN3
FN4:    call PARSENUM
        jc   FNNEXT
        cmp  eax,[EXITCODE]
        je   FNFOUND
        jmp  FN3
FNNEXT: pop  cx
        inc  cx
        jmp  FN1
FNFOUND:
        pop  cx
        mov  si,CANDID
        mov  di,CURID
        call STRCPY0
        mov  dx,MKNEXT
        mov  si,CURID
        call LOGWITH
        clc
        ret
FNNO:   stc
        ret

; ---------------------------------------------------------------------------
;  The line scanner. SI in the text; on return SI is at the next line and
;  LINEKIND says what was read: 1 a [section] (name in KEYBUF), 2 a key line
;  (KEYBUF, SUBBUF, VALOFF/VALLEN), 0 nothing (blank, comment). CF = the end.
; ---------------------------------------------------------------------------
; The cursor lives in INIPOS, not in SI: the first version carried it in SI
; and every handler that used SI for its own string - the ITEM name, the
; OPTION number - ended the parse on the spot, after exactly one of them.
NEXTLINE:
        mov  si,[INIPOS]
        mov  byte [LINEKIND],0
NL0:    call SKIPSP
        mov  al,[si]
        test al,al
        jz   NLEND
        cmp  al,13
        je   NLEOL
        cmp  al,10
        je   NLEOL
        cmp  al,';'
        je   NLCOMMENT
        cmp  al,'['
        je   NLSECT
        ; a key: letters up to a space or '='
        mov  di,KEYBUF
        mov  cx,15
NK1:    mov  al,[si]
        cmp  al,' '
        je   NK2
        cmp  al,'='
        je   NK2
        cmp  al,13
        je   NLSKIP
        cmp  al,10
        je   NLSKIP
        test al,al
        jz   NLEND
        stosb
        inc  si
        loop NK1
NK2:    mov  byte [di],0
        call SKIPSP
        ; a sub-key, if the next thing is not '='
        mov  di,SUBBUF
        mov  byte [di],0
        cmp  byte [si],'='
        je   NK4
        mov  cx,15
NK3:    mov  al,[si]
        cmp  al,' '
        je   NK3E
        cmp  al,'='
        je   NK3E
        cmp  al,13
        je   NLSKIP
        test al,al
        jz   NLEND
        stosb
        inc  si
        loop NK3
NK3E:   mov  byte [di],0
        call SKIPSP
        cmp  byte [si],'='
        jne  NLSKIP                     ; not a key line after all
NK4:    inc  si
        call SKIPSP
        mov  [VALOFF],si
        ; to the end of the line, then trim
        mov  di,si
NK5:    mov  al,[di]
        test al,al
        jz   NK6
        cmp  al,13
        je   NK6
        cmp  al,10
        je   NK6
        inc  di
        jmp  NK5
NK6:    mov  cx,di
        sub  cx,si
NK7:    test cx,cx
        jz   NK8
        cmp  byte [di-1],' '
        jne  NK8
        dec  di
        dec  cx
        jmp  NK7
NK8:    mov  [VALLEN],cx
        mov  byte [LINEKIND],2
        mov  si,di
        jmp  NLTOEOL
NLSECT: inc  si
        mov  di,KEYBUF
        mov  cx,15
NS1:    mov  al,[si]
        cmp  al,']'
        je   NS2
        cmp  al,13
        je   NS2
        test al,al
        jz   NS2
        stosb
        inc  si
        loop NS1
NS2:    mov  byte [di],0
        mov  byte [LINEKIND],1
        jmp  NLTOEOL
NLCOMMENT:
NLSKIP: mov  byte [LINEKIND],0
NLTOEOL:
        mov  al,[si]
        test al,al
        jz   NLRET
        cmp  al,13
        je   NLEOL
        cmp  al,10
        je   NLEOL
        inc  si
        jmp  NLTOEOL
NLEOL:  ; past CR and/or LF
        mov  al,[si]
        cmp  al,13
        jne  NLE1
        inc  si
NLE1:   cmp  byte [si],10
        jne  NLE2
        inc  si
NLE2:   cmp  byte [LINEKIND],0
        jne  NLRET
        jmp  NL0                        ; a blank or a comment: the next one
NLRET:  mov  [INIPOS],si
        clc
        ret
NLEND:  mov  [INIPOS],si
        stc
        ret

SKIPSP: cmp  byte [si],' '
        je   SS1
        cmp  byte [si],9
        jne  SS2
SS1:    inc  si
        jmp  SKIPSP
SS2:    ret

; DS:SI, CX bytes: a decimal number -> EAX; SI/CX past it. CF = no digits.
PARSENUM:
        xor  eax,eax
        xor  bx,bx                      ; digits seen
PN1:    jcxz PN2
        mov  dl,[si]
        cmp  dl,'0'
        jb   PN2
        cmp  dl,'9'
        ja   PN2
        sub  dl,'0'
        movzx edx,dl
        imul eax,10
        add  eax,edx
        inc  si
        dec  cx
        inc  bx
        jmp  PN1
PN2:    test bx,bx
        jz   PNNO
        clc
        ret
PNNO:   stc
        ret

; ---- strings ---------------------------------------------------------------
; DS:SI -> DS:DI, up to the 0, which is not copied (DI left after the text).
STRCPY: lodsb
        test al,al
        jz   SC1
        stosb
        jmp  STRCPY
SC1:    ret
; ...and with the 0.
STRCPY0:
        call STRCPY
        mov  byte [di],0
        ret
; the length of DS:DI -> CX
STRLEN: push di
        xor  cx,cx
SL1:    cmp  byte [di],0
        je   SL2
        inc  di
        inc  cx
        jmp  SL1
SL2:    pop  di
        ret
; the length of DS:SI -> CX
STRLEN2:
        push si
        xor  cx,cx
SL3:    cmp  byte [si],0
        je   SL4
        inc  si
        inc  cx
        jmp  SL3
SL4:    pop  si
        ret
; DS:DI equal to DS:BX? CF = no.
STREQ:  push di
        push bx
SE1:    mov  al,[di]
        cmp  al,[bx]
        jne  SENO
        test al,al
        jz   SEYES
        inc  di
        inc  bx
        jmp  SE1
SEYES:  pop  bx
        pop  di
        clc
        ret
SENO:   pop  bx
        pop  di
        stc
        ret
; One word of DS:SI (CX bytes left) into DS:DI, at most NAMESZ-1, and a 0.
; SI and CX are moved past the word.
COPYNAME:
        push dx
        mov  dx,NAMESZ-1
CN1:    jcxz CN2
        mov  al,[si]
        cmp  al,' '
        je   CN2
        cmp  al,13
        je   CN2
        inc  si
        dec  cx
        test dx,dx
        jz   CN1
        stosb
        dec  dx
        jmp  CN1
CN2:    mov  byte [di],0
        pop  dx
        ret

; <story>\<CURID>\[BX folder\]SI name -> PATHBUF. BX = 0 for no folder.
SCENEPATH:
        push si
        push bx
        mov  si,STORYDIR
        mov  di,PATHBUF
        call STRCPY
        mov  al,'\'
        stosb
        mov  si,CURID
        call STRCPY
        mov  al,'\'
        stosb
        pop  si                         ; the folder, if any
        test si,si
        jz   SPNOF
        call STRCPY
        mov  al,'\'
        stosb
SPNOF:  pop  si
        call STRCPY0
        ret

; EAX as decimal at DS:DI, 0-terminated.
DEC32TO:
        push eax
        push ebx
        push ecx
        push edx
        mov  ebx,10
        xor  cx,cx
D1:     xor  edx,edx
        div  ebx
        push dx
        inc  cx
        test eax,eax
        jnz  D1
D2:     pop  ax
        add  al,'0'
        mov  [di],al
        inc  di
        loop D2
        mov  byte [di],0
        pop  edx
        pop  ecx
        pop  ebx
        pop  eax
        ret

; A log line: the $-message at DX with the 0-terminated text at SI after it.
LOGWITH:
        pushad
        push si
        mov  si,dx
        mov  di,LINEBUF
LW1:    lodsb
        cmp  al,'$'
        je   LW2
        stosb
        jmp  LW1
LW2:    pop  si
        mov  cx,70
LW3:    lodsb
        test al,al
        jz   LW4
        stosb
        loop LW3
LW4:    mov  al,13
        stosb
        mov  al,10
        stosb
        mov  al,'$'
        stosb
        mov  dx,LINEBUF
        call LOGMARK
        popad
        ret

PUTS:   mov  ah,9
        int  21h
        ret
; a 0-terminated string at DX
PUTZ:   push si
        mov  si,dx
PZ1:    lodsb
        test al,al
        jz   PZ2
        mov  dl,al
        mov  ah,2
        int  21h
        jmp  PZ1
PZ2:    pop  si
        ret

; ===========================================================================
;  The panel: a slot per thing in the band below the room. The band's
;  backing is in the room's frame already (the converter laid it there);
;  this draws only the things' slot pictures, .SLT files placed by the
;  converter, so the desk and the game put a slot in the same place by
;  construction. A thing still in the room shows as its OUTLINE - every
;  opaque pixel with a transparent neighbour, in the palette's grey - and
;  a thing that has been taken shows as itself.
; ===========================================================================
DRAWPANEL:
        xor  cx,cx
DP1:    cmp  cx,[NITEMS]
        jae  DPDONE
        push cx
        mov  ax,ITSZ
        mul  cx
        add  ax,ITEMTAB
        mov  bx,ax
        mov  al,[bx+IT_FLAGS]
        shr  al,1
        and  al,1                       ; taken -> in colour
        mov  [ICOMODE],al
        pop  cx
        push cx
        call DRAWICO
        pop  cx
        inc  cx
        jmp  DP1
DPDONE: ret

; Thing CX has been taken: its slot in colour.
SLOTON: mov  byte [ICOMODE],1
        call DRAWICO
        ret

; The slot picture of thing CX: in colour when [ICOMODE] is 1, as an
; outline when it is 0. Nothing is clipped - the converter put every
; slot inside the band.
DRAWICO:
        mov  ax,ITSZ
        mul  cx
        add  ax,ITEMTAB
        mov  bx,ax
        mov  esi,[bx+IT_ICO]
        test esi,esi
        jz   DIDONE
        movzx eax,word [bx+IT_IW]
        mov  [IWD],eax
        movzx eax,word [bx+IT_IH]
        mov  [IHD],eax
        movzx eax,word [bx+IT_IY]
        imul eax,WIDTH
        movzx edx,word [bx+IT_IX]
        add  eax,edx
        add  eax,[LFB]
        mov  edi,eax                    ; the top left, on the screen
        mov  dword [DIY],0
        mov  ecx,[IHD]
DIROW:  push ecx
        push edi
        mov  ecx,[IWD]
        xor  edx,edx                    ; x within the picture
DIPIX:  mov  al,[fs:esi]
        cmp  al,255
        je   DISKIP
        cmp  byte [ICOMODE],1
        je   DIPUT
        ; an outline pixel: at an edge of the picture, or next to a
        ; transparent one - left, right, above, below
        test edx,edx
        jz   DIEDGE
        cmp  byte [fs:esi-1],255
        je   DIEDGE
        mov  eax,edx
        inc  eax
        cmp  eax,[IWD]
        jae  DIEDGE
        cmp  byte [fs:esi+1],255
        je   DIEDGE
        cmp  dword [DIY],0
        je   DIEDGE
        push esi
        sub  esi,[IWD]
        mov  al,[fs:esi]
        pop  esi
        cmp  al,255
        je   DIEDGE
        mov  eax,[DIY]
        inc  eax
        cmp  eax,[IHD]
        jae  DIEDGE
        push esi
        add  esi,[IWD]
        mov  al,[fs:esi]
        pop  esi
        cmp  al,255
        je   DIEDGE
        jmp  DISKIP                     ; inside the shape: not drawn
DIEDGE: mov  al,[GREY]
DIPUT:  mov  [fs:edi],al
DISKIP: inc  esi
        inc  edi
        inc  edx
        dec  ecx
        jnz  DIPIX
        pop  edi
        add  edi,WIDTH
        pop  ecx
        inc  dword [DIY]
        dec  ecx
        jnz  DIROW
DIDONE: ret

; ===========================================================================
;  The caption: the thing's TEXT line, in a black band at the foot of the
;  room for a second and a half. Drawn at the taking, taken down from the
;  loop; the band is restored from the room's frame and the things drawn
;  again over it. The last thing's line gets its time before the section
;  ends (CAPTWAIT), so the video does not cut it off mid-word.
; ===========================================================================
CAPTION:
        mov  ax,SI_SZ
        mul  cx
        mov  bx,[CURSECT]
        add  bx,ax
        mov  cx,[bx+S_ITEM+SI_TLEN]
        test cx,cx
        jz   CPDONE
        mov  si,[bx+S_ITEM+SI_TOFF]
        add  si,INIBUF
        push si
        push cx
        cmp  byte [CAPTON],1            ; the last one comes down first
        jne  CP1
        call CAPTHIDE
CP1:    mov  word [RX],0
        mov  ax,[ROOMH]
        sub  ax,CAPTH
        mov  [RY],ax
        mov  word [RWID],WIDTH
        mov  word [RHGT],CAPTH
        mov  al,[BLACK]
        call FILLRECT
        pop  cx
        pop  si
        ; centred, sixteen pixels a glyph; too long for the width and it
        ; starts at the left and stops at the right edge
        mov  ax,cx
        shl  ax,4
        cmp  ax,WIDTH
        jbe  CP2
        mov  ax,WIDTH
CP2:    neg  ax
        add  ax,WIDTH
        shr  ax,1
        mov  [TX],ax
        mov  ax,[RY]
        add  ax,(CAPTH-16)/2
        mov  [TY],ax
        call DRAWTXT
        mov  byte [CAPTON],1
        call TICK
        mov  [CAPT],eax
CPDONE: ret

; From the loop: a caption that has had its time comes down.
CAPTCHECK:
        cmp  byte [CAPTON],1
        jne  CCDONE
        call TICK
        sub  eax,[CAPT]
        cmp  eax,CAPTHOLD
        jb   CCDONE
        call CURHIDE
        call CAPTHIDE
        call CURSHOW
CCDONE: ret

; Wait the caption out, feeding the music meanwhile.
CAPTWAIT:
        cmp  byte [CAPTON],1
        jne  CWDONE
CW1:    call MUSFEED
        call TICK
        sub  eax,[CAPT]
        cmp  eax,CAPTHOLD
        jb   CW1
        call CURHIDE
        call CAPTHIDE
        call CURSHOW
CWDONE: ret

; The band back from the room's frame, the things over it again.
CAPTHIDE:
        pushad
        movzx eax,word [ROOMH]
        sub  eax,CAPTH
        imul eax,WIDTH
        mov  esi,eax
        mov  edi,eax
        add  esi,[BGFRAME]
        add  edi,[LFB]
        mov  ecx,CAPTH*WIDTH
        call COPYB
        call DRAWALL
        mov  byte [CAPTON],0
        popad
        ret

; ===========================================================================
;  The scene's music. MUSIC = <file> in SCENE.INI names an OWA1 file beside
;  it - sixteen-bit mono samples with a sixteen-byte header - opened when
;  the scene starts and closed when it ends, and LOOPED: a read that comes
;  up short goes back to the first sample and carries on. Under the room
;  (and a quiz) the card is started for it and the loop keeps the queue
;  fed; under a clip the decoder hands every audio chunk through OWV_MIX
;  and the music is added in at half level. No card: silence, as before.
; ===========================================================================
MUSOPEN:
        mov  byte [MUSON],0
        cmp  byte [MUSNAME],0
        je   MODONE
        mov  si,MUSNAME
        xor  bx,bx
        call SCENEPATH
        mov  ax,3D00h
        mov  dx,PATHBUF
        int  21h
        jc   MONONE
        mov  [MUSFH],ax
        mov  bx,ax
        mov  cx,16
        mov  dx,MUSHDR
        mov  ah,3Fh
        int  21h
        call REFLAT
        cmp  ax,16
        jne  MOBAD
        cmp  dword [MUSHDR],'OWA1'
        jne  MOBAD
        cmp  byte [MUSHDR+6],16
        jne  MOBAD
        mov  ax,word [MUSHDR+4]
        mov  [MUSRATE],ax
        mov  byte [MUSON],1
        mov  dx,MKMUSIC
        mov  si,MUSNAME
        call LOGWITH
        ret
MOBAD:  mov  bx,[MUSFH]
        mov  ah,3Eh
        int  21h
        call REFLAT
        mov  dx,MKBADMUS
        mov  si,MUSNAME
        call LOGWITH
        ret
MONONE: call REFLAT
        mov  dx,MKNOMUS
        mov  si,PATHBUF
        call LOGWITH
MODONE: ret

MUSCLOSE:
        cmp  byte [MUSON],1
        jne  MCDONE
        call MUSSTOP
        mov  bx,[MUSFH]
        mov  ah,3Eh
        int  21h
        call REFLAT
        mov  byte [MUSON],0
MCDONE: ret

; The card, for a screen with no clip on it: the music's rate, sixteen
; bits, an empty queue that MUSFEED fills from the loop.
MUSSTART:
        mov  byte [MUSRUN],0
        cmp  byte [MUSON],1
        jne  MSDONE
        mov  ax,[MUSRATE]
        mov  [SBRATE],ax
        mov  byte [SBWANT16],1
        call SBINIT
        jc   MSNOCARD
        call REFLAT
        mov  byte [MUSRUN],1
        call MUSFEED
        ret
MSNOCARD:
        call REFLAT
MSDONE: ret

MUSSTOP:
        cmp  byte [MUSRUN],1
        jne  MTDONE
        call SBHALT
        mov  byte [MUSRUN],0
MTDONE: ret

; Keep the queue full: while there is room for a whole IOBUF, read one
; and hand it over. Bounded by the queue - eight pieces at the most.
MUSFEED:
        cmp  byte [MUSRUN],1
        jne  MFDONE
        pushad
MF1:    mov  ax,[QHEAD]
        sub  ax,[QTAIL]
        dec  ax
        and  ax,QUEUESZ-1               ; bytes free
        cmp  ax,IOSIZE
        jb   MFEXIT
        mov  cx,IOSIZE
        call MUSREAD                    ; -> AX bytes at IOBUF
        test ax,ax
        jz   MFEXIT
        mov  cx,ax
        mov  esi,[IOBUFLIN]
        call SBFEED
        jmp  MF1
MFEXIT: popad
MFDONE: ret

; CX bytes of the music into IOBUF, from where it left off. A read that
; comes up short is the end of the file: back to the first sample, once,
; and the rest of the piece from there - so the loop point is not a hole.
; AX = how many arrived.
MUSREAD:
        mov  [MRWANT],cx
        mov  word [MRGOT],0
        mov  byte [MRWRAP],0
MR1:    mov  cx,[MRWANT]
        sub  cx,[MRGOT]
        jz   MRDONE
        mov  bx,[MUSFH]
        mov  dx,IOBUF
        add  dx,[MRGOT]
        mov  ah,3Fh
        int  21h
        jc   MRDONE
        add  [MRGOT],ax
        cmp  ax,cx
        je   MR1
        cmp  byte [MRWRAP],1
        je   MRDONE
        mov  byte [MRWRAP],1
        mov  bx,[MUSFH]
        mov  ax,4200h                   ; seek: past the header
        xor  cx,cx
        mov  dx,16
        int  21h
        jmp  MR1
MRDONE: call REFLAT
        mov  ax,[MRGOT]
        ret

; OWV_MIX - the decoder calls this with the clip's audio chunk at BUFLIN,
; ECX bytes, before the queue gets it. The music is read in step and added
; in at half level, saturated. Sixteen-bit clips at the music's own rate
; only; anything else plays the clip alone. ECX goes back as it came.
OWV_MIX:
        cmp  byte [MUSON],1
        jne  OMDONE
        test byte [HDRBUF+9],2
        jz   OMDONE
        mov  ax,[HDRBUF+12]
        cmp  ax,[MUSRATE]
        jne  OMDONE
        pushad
        mov  esi,BUFLIN
        mov  [OMLEFT],ecx
OM1:    mov  ecx,[OMLEFT]
        test ecx,ecx
        jz   OMEXIT
        cmp  ecx,IOSIZE
        jbe  OM2
        mov  ecx,IOSIZE
OM2:    and  cx,0FFFEh                  ; whole samples
        jz   OMEXIT
        push esi
        call MUSREAD                    ; -> AX bytes at IOBUF
        pop  esi
        movzx ecx,ax
        and  ecx,0FFFFFFFEh
        jz   OMEXIT
        sub  [OMLEFT],ecx
        shr  ecx,1                      ; samples
        mov  di,IOBUF
OM3:    mov  ax,[di]
        sar  ax,1                       ; the music at half level
        mov  bx,[fs:esi]
        add  bx,ax
        jno  OM4
        mov  bx,7FFFh                   ; over the top: pinned at the rail
        test ax,ax                      ; on the side it went over
        jns  OM4
        mov  bx,8000h
OM4:    mov  [fs:esi],bx
        add  esi,2
        add  di,2
        dec  ecx
        jnz  OM3
        jmp  OM1
OMEXIT: popad
OMDONE: ret

include '..\VIDEO\OWV.INC'
include '..\VIDEO\SB.INC'

; ===========================================================================
;  Data
; ===========================================================================
LOGNAME  db 'STORY.LOG',0
DEFDIR   db '..\STORY\NIGHT',0
N_STORY  db 'STORY.INI',0
N_SCENE  db 'SCENE.INI',0
N_BG     db 'BG.OWV',0
N_SPR    db '.SPR',0
N_SLT    db '.SLT',0
SHOTNAME db 'SHOT00.OWV',0

K_START  db 'START',0
K_ORDER  db 'ORDER',0
K_CODE   db 'CODE',0
K_ENDING db 'ENDING',0
K_ENTERS db 'ENTERS',0
K_FILE   db 'FILE',0
K_FOLDER db 'FOLDER',0
K_NEED   db 'NEED',0
K_ITEM   db 'ITEM',0
K_PANEL  db 'PANEL',0
K_MUSIC  db 'MUSIC',0
K_TEXT   db 'TEXT',0
K_OPTION db 'OPTION',0
K_VIDEON db 'VIDEO',0
K_PICKUPN db 'PICKUP',0
K_QUIZN  db 'QUIZ',0

T_END    db 'THE END',0
T_KEY    db 'press a key',0
T_NOCODE db 'THE SCENE ENDS WITH NO CODE',0
T_NONEXT db 'NO SCENE ENTERS ON THIS CODE',0
T_MISSING db 'MISSING:',0

MKSCENE  db 'scene    $'
MKVIDEO  db 'video    $'
MKPICK   db 'pickup   $'
MKTAKE   db 'taken    $'
MKQUIZ   db 'quiz     shown',13,10,'$'
MKANSWER db 'answer   code $'
MKCODE   db 'ends     code $'
MKNEXT   db 'next     $'
MKNONEXT db 'FAILED: no scene enters on code $'
MKNOCODE db 'FAILED: the scene ends with no code and is not an ending',13,10,'$'
MKMISS   db 'MISSING  $'
MKNOSPR  db 'no .SPR  $'
MKEND    db 'reached: the end of the story',13,10,'$'
MKSHOT   db 'shot     $'
MKSECTS  db 'sections $'
MKMISSED db 'MISSED   at '
MISSX    db 24 dup (0)
MKDIR    db 'story    $'
MKITEMS  db 'items    $'
MKSPR    db 'loaded   $'
MKBADSPR db 'BAD .SPR $'
MKNOSLT  db 'no .SLT  $'
MKMUSIC  db 'music    $'
MKNOMUS  db 'no music $'
MKBADMUS db 'BAD music$'
MKHEX    db '         buflin='
HEXA     db '00000000  slot='
HEXB     db '00000000  at '
HEXC     db '00000000',13,10,'$'

MSGNOSTORY  db 'Cannot read $'
MSGANYKEY   db 'Press a key.',13,10,'$'
MKNOSTORY   db 'FAILED: cannot read $'
MSGNOUNREAL db 'Unreal mode was refused - no 32-bit addressing here.',13,10,'$'
MSGNOMODE   db 'VESA mode 100h with a linear framebuffer was refused.',13,10,'$'
MSGDONE     db 'STORY.LOG written.',13,10,'$'
CRLF        db 13,10,'$'

; the cursor: an arrow, its outline and its fill, sixteen rows of sixteen bits
CUROUT:  dw 1100000000000000b
         dw 1110000000000000b
         dw 1111000000000000b
         dw 1111100000000000b
         dw 1111110000000000b
         dw 1111111000000000b
         dw 1111111100000000b
         dw 1111111110000000b
         dw 1111111111000000b
         dw 1111111111100000b
         dw 1111111000000000b
         dw 1110011100000000b
         dw 1100011100000000b
         dw 1000001110000000b
         dw 0000001110000000b
         dw 0000000110000000b
CURIN:   dw 0000000000000000b
         dw 0100000000000000b
         dw 0110000000000000b
         dw 0111000000000000b
         dw 0111100000000000b
         dw 0111110000000000b
         dw 0111111000000000b
         dw 0111111100000000b
         dw 0111111110000000b
         dw 0111110000000000b
         dw 0110110000000000b
         dw 0100011000000000b
         dw 0000011000000000b
         dw 0000001100000000b
         dw 0000001100000000b
         dw 0000000000000000b

AUTO     db 0
GOTDIR   db 0
MOUSEOK  db 0
QUITFLAG db 0
CURON    db 0
WASDOWN  db 0
SHOTNO   db 0
HAVECODE db 0
HAVEANS  db 0
SENDING  db 0
LINEKIND db 0
WHITE    db 255
BLACK    db 0
DIGIT    db '1 '
SCODE    dd 0
ANSWER   dd 0
EXITCODE dd 0
AUTOT    dd 0
BGFRAME  dd 0
CURDX    dd 0
CURDY    dd 0
FONTSEG  dw 0
FONTOFF  dw 0
NSECT    dw 0
SECTNO   dw 0
CURSECT  dw 0
CURIT    dw 0
NITEMS   dw 0
NOPTS    dw 0
NORDER   dw 0
VALOFF   dw 0
VALLEN   dw 0
CURX     dw 0
CURY     dw 0
RX       dw 0
RY       dw 0
RWID       dw 0
RHGT       dw 0
TX       dw 0
TY       dw 0
PMAX     dw 0
PMIN     dw 0
SHFH     dw 0
SHRUNS   dw 0
HX       dw 0
HY       dw 0
HTX      dw 0
HTY      dw 0
HTPASS   db 0
MNIDX    dw 0
INIPOS   dw 0
ROOMH    dw HEIGHT              ; where the room ends and the panel starts
GREY     db 7                   ; the palette's grey, for the outlines
PGREY    dw 0
ICOMODE  db 0
DIY      dd 0
IWD      dd 0
IHD      dd 0
CAPTON   db 0
CAPT     dd 0
LSIDX    dw 0
NAMEEND  dw 0
LOLIMIT  dd 0
MUSON    db 0                   ; the scene has a track, and it is open
MUSRUN   db 0                   ; ...and the card is playing it by itself
MUSFH    dw 0
MUSRATE  dw 0
MRWANT   dw 0
MRGOT    dw 0
MRWRAP   db 0
OMLEFT   dd 0

STORYDIR db 80 dup (0)
PATHBUF  db 128 dup (0)
NAMEBUF  db 32 dup (0)
KEYBUF   db 16 dup (0)
SUBBUF   db 16 dup (0)
NUMBUF   db 12 dup (0)
STARTID  db NAMESZ dup (0)
CURID    db NAMESZ dup (0)
CANDID   db NAMESZ dup (0)
LINEBUF  db 96 dup (0)
SPRHDR   db 16 dup (0)
MUSNAME  db NAMESZ dup (0)
MUSHDR   db 16 dup (0)

; ============================================================================
;  The program must not grow into its own tables.
; ============================================================================
if $ > SECTTAB
        display 'STORY has grown into SECTTAB - move the layout up', 13, 10
        err
end if
if MAXORDER*NAMESZ > ITEMTAB-ORDERTAB
        err
end if
if MAXSECT*SECTSZ > ORDERTAB-SECTTAB
        err
end if
