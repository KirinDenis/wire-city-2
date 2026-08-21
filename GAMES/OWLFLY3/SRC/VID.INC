; VID.INC - part of OWL FLY III (included from OWLFLY3.ASM, after TOWN.INC)
;
;  THE SIXTH SEGMENT, opened 2026-08-18 for the retro players: the game
;  asks "SELECT VIDEO SYSTEM" at the front step and, for anything short
;  of VGA/MCGA, converts the finished 320x200x256 frame out of bufseg
;  into the picked card's memory. The renderer never knows: everything
;  still draws into bufseg, and the two copies out of it - BLIT in the
;  game loop, UBLIT on the front door - gate on [vcard] and send the
;  retro cards here. Skill\VIDTASK.md holds the whole plan.
;
;  THE MENU RUNS FIRST, BEFORE THE INT 9 HOOK: it reads keys through
;  BIOS INT 16h, which the game's own keyboard handler silences. It also
;  never sets a text mode - it re-enters whatever mode DOS handed us,
;  because a real Hercules machine boots in mode 7 and must not be asked
;  for mode 3. Re-entering the current mode is the portable "clear to
;  black" and nothing more.
;
;  VMRDY is the build's honesty: a card whose converter has not shipped
;  yet is listed but cannot be picked - digits and arrows both skip it.
;  Each converter stage flips its byte to 1 when it lands.
;
;  Code here runs with DS = the main segment (vcard lives there); every
;  word of our own - strings, vmsel, VMRDY - takes cs:.
; ============================================================================

segment VIDSEG

; the INTERNAL card codes VMENUF returns in AL. Not the menu order: the
; gates in BLIT/UBLIT/APPLYPALF test "vcard >= VMMCGA -> the straight
; mode-13h path", so everything that CONVERTS - including the 16-colour
; VGA mode - must sit below VMMCGA. VMPICK translates menu row to code.
SC_H    = 23h                   ; H: swap the CGA hardware palette in
                                ; flight - cyan/magenta <-> green/red
VMHERC  = 1                     ; Hercules 720x348 mono
VMCGA   = 2                     ; CGA mode 4, palette 1
VMEGA   = 3                     ; EGA mode 10h, 640x350x16
VMEGLO  = 4                     ; EGA mode 0Dh, 320x200x16 - runs on ANY
                                ; EGA: the 64K launch card and the
                                ; CGA-monitor rigs that mode 10h cannot
VMV480  = 5                     ; VGA mode 12h, 640x480x16 - a VGA mode,
                                ; but 16 colours means the converter
VMMCGA  = 6                     ; mode 13h, straight
VMVGA   = 7                     ; mode 13h, straight

vmsel   db 6                    ; the chevron's perch, a MENU row:
                                ; row 6 is VGA 320x200x256, the default
VMRDY   db 1,1,1,1,1,1,1        ; every menu row is BUILT (2026-08-18)
VMOKT   rb 7                    ; ...but only what THIS machine owns is
                                ; offered: filled per boot by VMENUF's
                                ; hardware quiz. The pilot picked
                                ; Hercules on a VGA host and got a
                                ; blinking cursor over an invisible
                                ; game - the menu asks the machine now.
VMNONE  db '- NOT IN THIS MACHINE',0
VMPICK  db VMHERC,VMCGA,VMEGLO,VMEGA,VMMCGA,VMVGA,VMV480
                                ; menu row -> internal code

VMTEXT  db 13,10
        db '  OWL FLY III',13,10
        db 13,10
        db '  SELECT VIDEO SYSTEM',13,10
        db 13,10
        db '    1) HERCULES    720x348    MONO',13,10
        db '    2) CGA         320x200    4 COLORS',13,10
        db '    3) EGA         320x200    16 COLORS',13,10
        db '    4) EGA         640x350    16 COLORS',13,10
        db '    5) MCGA        320x200    256 COLORS',13,10
        db '    6) VGA         320x200    256 COLORS',13,10
        db '    7) VGA         640x480    16 COLORS',13,10
        db 13,10
        db '  PRESS 1..7, OR ARROWS AND ENTER',13,10,0

; ---- the second screen: how much of it the machine is asked to work out ---
;  Three levels, and they are conditions that SKIP WORK - not other
;  renderers. FULL is this game exactly as it has always been.
;  The three items sit on CONSECUTIVE rows, 5, 6 and 7 - so item n lands on
;  row n+4, which is the card menu's own arithmetic, and VMMOVE/VMMARK drive
;  the chevron here without a line of new drawing code.
QMTEXT  db 13,10
        db '  OWL FLY III',13,10
        db 13,10
        db '  GRAPHICS DETAIL',13,10
        db 13,10
        db '    1) FULL     everything, as the game was born',13,10
        db '    2) MEDIUM   a nearer horizon: the world to 12 nodes, not 20',13,10
        db '    3) LOW      WIRE: flat ground, no filled faces, no glass',13,10
        db 13,10
        db '  The physics, the war and every instrument are the same in all',13,10
        db '  three. Only how much of the picture gets worked out changes.',13,10
        db 13,10
        db '  PRESS 1..3, OR ARROWS AND ENTER',13,10,0

; ---- the third screen: what the machine is asked to sound like ------------
;  The same manners as the other two: digits, arrows, ENTER takes the
;  chevron. The Blaster row is QUIZZED like the video cards are - a DSP
;  that does not answer 220h is listed, marked and refuses the key, and
;  the chevron then starts on the speaker: an ancient machine should get
;  a voice by default, not silence.
SMOKT   rb 3                    ; which of the three THIS machine offers
SMTEXT  db 13,10
        db '  OWL FLY III',13,10
        db 13,10
        db '  SELECT SOUND SYSTEM',13,10
        db 13,10
        db '    1) SOUND BLASTER  the recorded turbine, effects mixed in',13,10
        db '    2) PC SPEAKER     one square wave, 1981 style',13,10
        db '    3) NO SOUND       instruments only',13,10
        db 13,10
        db '  The speaker bends one tone: the engine is a drone that spools',13,10
        db '  with the lever, guns clatter, and a warning is a plain beep.',13,10
        db 13,10
        db '  PRESS 1..3, OR ARROWS AND ENTER',13,10,0

; ============================================================================
;  VMENUF - the front step. Text mode, black, English, numbered - as the
;  retro players asked. Returns the pick in AL (1..5, menu order).
;  Digits take an item outright; Up/Down walk the chevron over the ready
;  ones and ENTER takes it. Nothing else answers - this game's front
;  door has never listened to ESC and the menu keeps that manner.
; ============================================================================
VMENUF:
        mov  ah,0Fh             ; which mode did DOS hand us?
        int  10h
        xor  ah,ah              ; ...re-enter it: cleared, black, cursor
        int  10h                ; home - and mode 7 stays mode 7
        ; ---- ask the MACHINE before offering. The BIOS data area's
        ; CRTC base splits mono from colour; a VGA or MCGA answers
        ; INT 10h AX=1A00h by name; an EGA answers AH=12h. A card the
        ; quiz does not find is listed but marked and refuses the key -
        ; picking Hercules on a VGA host used to fly the game into an
        ; invisible B000 behind a blinking cursor.
        push ds
        mov  ax,40h
        mov  ds,ax
        mov  ax,[63h]           ; active CRTC base: 3B4h = mono family
        pop  ds
        mov  byte [cs:vcaps],0
        cmp  ax,3B4h
        jne  .clr
        ; a mono machine: Hercules and nothing else
        mov  byte [cs:VMOKT+0],1
        mov  cx,6
        mov  bx,1
.zm:   mov  byte [cs:VMOKT+bx],0
        inc  bx
        loop .zm
        jmp  .quizd
.clr:  mov  ax,1A00h           ; VGA and MCGA answer by name
        int  10h
        cmp  al,1Ah
        jne  .nvg
        cmp  bl,7
        je   .isv
        cmp  bl,8
        je   .isv
        cmp  bl,0Ah
        jb   .nvg
        cmp  bl,0Ch
        ja   .nvg
        or   byte [cs:vcaps],4  ; MCGA
        jmp  .nvg
.isv:  or   byte [cs:vcaps],2  ; VGA
.nvg:  mov  ah,12h             ; an EGA answers this one
        mov  bl,10h
        int  10h
        cmp  bl,10h
        je   .neg
        or   byte [cs:vcaps],1  ; EGA (a VGA answers here too - implied)
.neg:  mov  byte [cs:VMOKT+0],0 ; no Hercules on a colour machine
        mov  byte [cs:VMOKT+1],1 ; CGA modes: every colour card
        mov  al,0
        test byte [cs:vcaps],3  ; the EGA planar modes: EGA or VGA
        jz   @f
        mov  al,1
@@:    mov  [cs:VMOKT+2],al
        mov  [cs:VMOKT+3],al
        mov  al,0
        test byte [cs:vcaps],6  ; mode 13h: MCGA or VGA
        jz   @f
        mov  al,1
@@:    mov  [cs:VMOKT+4],al
        mov  [cs:VMOKT+5],al
        mov  al,0
        test byte [cs:vcaps],2  ; 640x480x16: VGA alone
        jz   @f
        mov  al,1
@@:    mov  [cs:VMOKT+6],al
.quizd:
        ; only what is BUILT stays offered
        xor  bx,bx
        mov  cx,7
.mg:   mov  al,[cs:VMRDY+bx]
        and  [cs:VMOKT+bx],al
        inc  bx
        loop .mg
        ; the chevron's default: the best row this machine owns
        mov  bl,6
.df:   xor  bh,bh
        cmp  byte [cs:VMOKT-1+bx],0
        jne  .dok
        dec  bl
        jnz  .df
        mov  bl,7               ; nothing below 7? then 7 it is
.dok:  mov  [cs:vmsel],bl
        mov  si,VMTEXT
        call VMPUTS
        ; mark what the machine has not got
        mov  bl,1
.mk:   xor  bh,bh
        cmp  byte [cs:VMOKT-1+bx],0
        jne  .mnx
        mov  dh,bl
        add  dh,4
        mov  dl,44
        push bx
        call VMAT
        mov  si,VMNONE
        call VMPUTS
        pop  bx
.mnx:  inc  bl
        cmp  bl,8
        jb   .mk
        call VMMARK             ; the chevron on the default
.key:  xor  ah,ah
        int  16h                ; BIOS keyboard: AL ascii, AH scan
        cmp  al,0Dh
        je   .take
        cmp  al,'1'
        jb   .ext
        cmp  al,'7'
        ja   .ext
        sub  al,'0'
        mov  bl,al
        xor  bh,bh
        cmp  byte [cs:VMOKT-1+bx],0
        je   .key               ; this machine has not got it: no key
        call VMMOVE
        jmp  .take
.ext:  or   al,al              ; an extended key reports AL 0 - or E0h
        jz   .e1                ; from an enhanced BIOS - and the scan
        cmp  al,0E0h            ; code in AH tells which
        jne  .key
.e1:   cmp  ah,48h             ; up
        je   .mvup
        cmp  ah,50h             ; down
        jne  .key
        mov  bl,[cs:vmsel]      ; down: next offered item, or stay put
.md1:  inc  bl
        cmp  bl,8
        jae  .key
        xor  bh,bh
        cmp  byte [cs:VMOKT-1+bx],0
        je   .md1
        call VMMOVE
        jmp  .key
.mvup: mov  bl,[cs:vmsel]      ; up: previous offered item, or stay put
.mu1:  dec  bl
        jz   .key
        xor  bh,bh
        cmp  byte [cs:VMOKT-1+bx],0
        je   .mu1
        call VMMOVE
        jmp  .key
.take: mov  bl,[cs:vmsel]      ; the menu row picked...
        xor  bh,bh
        mov  al,[cs:VMPICK-1+bx] ; ...as the INTERNAL card code
        push ax
        call QMENU              ; ...then the detail, on its own screen...
        push ax
        call SMENU              ; ...then the sound, on its own screen too
        mov  dl,al
        pop  bx
        pop  ax
        mov  ah,bl              ; AL = card, AH = 0 FULL / 1 MEDIUM / 2 LOW,
        retf                    ;  DL = 0 BLASTER / 1 SPEAKER / 2 NO SOUND

; ---- QMENU: the detail screen. Digits only, and ENTER means FULL ----------
;  No chevron and no quiz here: all three levels exist on every machine, so
;  there is nothing to grey out and nothing to walk over. A player who does
;  not care presses ENTER and gets the game as it has always been.
QMENU:  mov  ah,0Fh             ; re-enter the mode: cleared, black, home
        int  10h
        xor  ah,ah
        int  10h
        mov  si,QMTEXT
        call VMPUTS
        mov  byte [cs:vmsel],1  ; the chevron starts on FULL, and vmsel is
        call VMMARK             ;  free now - the card it was choosing has
                                ;  already been taken
.k:    xor  ah,ah
        int  16h
        cmp  al,0Dh             ; ENTER takes whatever the chevron is on
        je   .take
        cmp  al,'1'
        jb   .ext
        cmp  al,'3'
        ja   .ext
        sub  al,'0'             ; a digit moves the chevron AND takes it,
        mov  bl,al              ;  so the eye sees what the key did
        call VMMOVE
        jmp  .take
.ext:  or   al,al              ; extended keys: AL 0, or E0h from an
        jz   .e1                ;  enhanced BIOS, with the scan code in AH
        cmp  al,0E0h
        jne  .k
.e1:   cmp  ah,48h             ; up
        je   .up
        cmp  ah,50h             ; down
        jne  .k
        mov  bl,[cs:vmsel]
        cmp  bl,3
        jae  .k
        inc  bl
        call VMMOVE
        jmp  .k
.up:   mov  bl,[cs:vmsel]
        cmp  bl,1
        jbe  .k
        dec  bl
        call VMMOVE
        jmp  .k
.take: mov  al,[cs:vmsel]      ; row 1..3 -> level 0..2
        dec  al
        ret

; ---- SMENU: the sound screen. Returns AL = 0 Blaster / 1 speaker / 2 none -
;  The quiz first: the DSP reset dance from SBINIT, and its answer fills
;  SMOKT the way VMENUF's quiz fills VMOKT. The speaker and silence are
;  never refused - every PC since the first one has both.
SMENU:  mov  byte [cs:SMOKT+1],1
        mov  byte [cs:SMOKT+2],1
        call SPROBE
        mov  [cs:SMOKT],al
        mov  ah,0Fh             ; re-enter the mode: cleared, black, home
        int  10h
        xor  ah,ah
        int  10h
        mov  si,SMTEXT
        call VMPUTS
        mov  bl,1               ; the chevron: the Blaster when it answered,
        cmp  byte [cs:SMOKT],0  ;  the speaker when it did not - an old
        jne  .df                ;  machine gets a voice by default
        mov  dh,5               ; ...and the absent row wears the mark
        mov  dl,44
        call VMAT
        mov  si,VMNONE
        call VMPUTS
        mov  bl,2
.df:   mov  [cs:vmsel],bl
        call VMMARK
.k:    xor  ah,ah
        int  16h
        cmp  al,0Dh             ; ENTER takes whatever the chevron is on
        je   .take
        cmp  al,'1'
        jb   .ext
        cmp  al,'3'
        ja   .ext
        sub  al,'0'
        mov  bl,al
        xor  bh,bh
        cmp  byte [cs:SMOKT-1+bx],0
        je   .k                ; this machine has not got it: no key
        call VMMOVE
        jmp  .take
.ext:  or   al,al              ; extended keys: AL 0, or E0h from an
        jz   .e1                ;  enhanced BIOS, with the scan code in AH
        cmp  al,0E0h
        jne  .k
.e1:   cmp  ah,48h             ; up
        je   .up
        cmp  ah,50h             ; down
        jne  .k
        mov  bl,[cs:vmsel]
.dn1:  inc  bl
        cmp  bl,3
        ja   .k
        xor  bh,bh
        cmp  byte [cs:SMOKT-1+bx],0
        je   .dn1
        call VMMOVE
        jmp  .k
.up:   mov  bl,[cs:vmsel]
.up1:  dec  bl
        jz   .k
        xor  bh,bh
        cmp  byte [cs:SMOKT-1+bx],0
        je   .up1
        call VMMOVE
        jmp  .k
.take: mov  al,[cs:vmsel]      ; row 1..3 -> choice 0..2
        dec  al
        ret

; ---- SPROBE: is a DSP listening at 220h? AL = 1 yes / 0 no ----------------
;  SBINIT's own reset pulse, asked a boot earlier: reset, then wait for
;  the 0AAh hello. Nothing is left running - SBINIT will do it all again
;  for real if the pilot picks the Blaster.
SPROBE: mov  dx,226h
        mov  al,1
        out  dx,al
        in   al,dx
        in   al,dx
        in   al,dx
        in   al,dx
        xor  al,al
        out  dx,al
        mov  cx,4000
.w:    mov  dx,22Eh
        in   al,dx
        test al,80h
        jz   .nx
        mov  dx,22Ah
        in   al,dx
        cmp  al,0AAh
        je   .yes
.nx:   loop .w
        xor  al,al
        ret
.yes:  mov  al,1
        ret

; ---- VMMOVE: the chevron to item BL (erase old, mark new) ------------------
; VMPUTC trashes BX for the BIOS call, hence the push across the erase.
VMMOVE: push bx
        mov  dh,[cs:vmsel]
        add  dh,4               ; item n sits on text row n+4
        mov  dl,2
        call VMAT
        mov  al,' '
        call VMPUTC
        pop  bx
        mov  [cs:vmsel],bl
VMMARK: mov  dh,[cs:vmsel]      ; (VMMOVE falls through to repaint)
        add  dh,4
        mov  dl,2
        call VMAT
        mov  al,'>'
        call VMPUTC
        ret

; ---- VMPUTS: ASCIIZ at cs:SI through BIOS teletype -------------------------
VMPUTS: mov  al,[cs:si]
        inc  si
        or   al,al
        jz   .d
        call VMPUTC
        jmp  VMPUTS
.d:    ret

VMPUTC: mov  ah,0Eh             ; teletype; BH page 0 (BL only matters
        xor  bx,bx              ; in graphics modes)
        int  10h
        ret

VMAT:   mov  ah,02h             ; cursor to DH row, DL column
        xor  bh,bh
        int  10h
        ret

; ============================================================================
;  VSETMDF - the picked card's graphics mode up. Called where the bare
;  "mov ax,0013h / int 10h" used to stand, DS = the main segment.
; ============================================================================
VSETMDF:
        mov  al,[vcard]
        cmp  al,VMMCGA
        jb   .retro
        mov  ax,0013h           ; VGA and MCGA: mode 13h IS MCGA's mode -
        int  10h                ; the game as born, untouched
        retf
.retro: cmp  al,VMCGA
        jne  .todo
        mov  ax,0004h           ; THE CLASSIC: mode 4, palette 1, intense
        int  10h                ; - black, cyan, magenta, white. (Mode 5's
                                ; burst-off palette was tried and renders
                                ; unpredictably - the pilot's screenshot.)
        test byte [cs:vcaps],6  ; a REAL CGA wants the intense set said
        jnz  @f                  ; out loud on 3D9h; a VGA host boots the
        mov  dx,3D9h            ; mode bright already - and ignores this
        mov  al,30h             ; port entirely (proven with a probe:
        out  dx,al              ; neither 3D9h nor INT 10h AH=0Bh moves
@@:    retf                     ; a VGA's mode-4 colours)
.todo: cmp  al,VMEGA
        jb   .herc              ; only Hercules sits below the EGA family
        mov  ah,0               ; the three 16-colour planar modes:
        cmp  al,VMEGA
        jne  @f
        mov  al,10h             ; EGA 640x350 (128K card + EGA monitor)
@@:    cmp  al,VMEGLO
        jne  @f
        mov  al,0Dh             ; EGA 320x200 (ANY EGA, any monitor)
@@:    cmp  al,VMV480
        jne  @f
        mov  al,12h             ; VGA 640x480 (VGA only)
@@:    int  10h
        push es
        mov  ax,cs
        mov  es,ax
        mov  dx,EPAL            ; the curated sixteen + border, through
        mov  ax,1002h           ; the BIOS - raw attribute ports would
        int  10h                ; break on a VGA host exactly the way
        pop  es                 ; the CGA DAC did
        retf
.herc:
        ; HERCULES HAS NO BIOS MODE - the 6845 is programmed by hand,
        ; the way every Hercules program ever did it. Config port first
        ; (allow graphics), screen dark while the timings change, the
        ; twelve registers, the page wiped (the letterbox stays black
        ; for the whole flight), then the screen back on.
        mov  dx,3BFh
        mov  al,1
        out  dx,al
        mov  dx,3B8h
        mov  al,2               ; graphics timings, video OFF
        out  dx,al
        mov  si,HGCPRM
        mov  cx,12
        xor  ah,ah              ; 6845 register index
.hp:   mov  dx,3B4h
        mov  al,ah
        out  dx,al
        inc  dx
        mov  al,[cs:si]
        inc  si
        out  dx,al
        inc  ah
        loop .hp
        push es
        mov  ax,0B000h
        mov  es,ax
        xor  di,di
        xor  ax,ax
        mov  cx,4000h
        cld
        rep  stosw
        pop  es
        mov  dx,3B8h
        mov  al,0Ah             ; graphics + video on, page 0
        out  dx,al
        retf
HGCPRM  db 35h,2Dh,2Eh,07h,5Bh,02h,57h,57h,02h,03h,00h,00h

; ============================================================================
;  VBLITF - bufseg out to a retro card, one converter per vcard.
; ============================================================================
VBLITF:
        mov  al,[vcard]
        cmp  al,VMCGA
        je   CGABLT
        cmp  al,VMEGA
        jne  @f
        mov  byte [cs:vgeom],0  ; 640x350: rows walk 2-into-3
        jmp  EGABLT
@@:    cmp  al,VMV480
        jne  @f
        mov  byte [cs:vgeom],1  ; 640x480: every row exactly twice
        jmp  EGABLT
@@:    cmp  al,VMEGLO
        jne  @f
        mov  byte [cs:vgeom],2  ; 320x200: one to one, shrunk bytes
        jmp  EGABLT
@@:    cmp  al,VMHERC
        je   HGCBLT
        retf

; ============================================================================
;  CGABLT - the finished 320x200x256 frame onto CGA mode 5.
;
;  Two rules, and the second is the whole trick:
;
;  1. Every pixel converts through VLUT - four 256-byte tables per
;     palette (phase = x&1 + (y&1)*2, the 2x2 ordered dither baked into
;     the tables by TOOLS\VidRig, day and night banks, [cs:vlutoff]
;     picking the bank). The tables are 512-aligned so the phase walk
;     is XOR on BH alone.
;
;  2. THE PANEL IS RECOGNISED, NOT FLAGGED. A pixel whose bufseg byte
;     equals the panel artwork's byte at the same position (the artwork
;     sits in resseg:pimgo - PANELBMP copies it there every frame) is
;     the artwork, and takes its colour from the BAKED panel
;     (CPCGA.DAT, drawn offline the 1988 way). Everything else - the
;     viewport, the MFD contents, every lamp and digit the game draws
;     OVER the panel, the whole front door - differs from the artwork
;     and converts through the lookup. No mask, no gate, no flag: the
;     splash converts clean before the loader has even run, and a view
;     with no cockpit never matches the artwork at all.
;
;  Even rows land at B800:0000, odd at B800:2000, 80 bytes a row,
;  4 pixels a byte, MSB first.
; ============================================================================
cbuf    dw 0                    ; stashes of the main-segment words, taken
cres    dw 0                    ; at entry while DS still points home
cimg    dw 0
cscr    dw 0
cy      dw 0                    ; the row being converted
dib     dw 0                    ; the row's first output byte, for bakrow
vlutoff dw 1024                 ; CGA: vpal*2048 + (night? 1024 : 0) -
                                ; four banks (day is set by the first
                                ; APPLYPALF at takeoff)
vpal    db 0                    ; 0 = palette 1 (cyan/magenta), 1 =
                                ; palette 0 (green/red/yellow); H swaps
vpedge  db 0                    ; ...on the key's EDGE, once per press
elutoff dw 256                  ; EGA: 0 = day, 256 = night, same switch
vcgok   db 0                    ; the bake is in and the artwork exists
vbklen  dw 0                    ; how many bytes the bake file owes us
vgeom   db 0                    ; EGABLT's shape: 0 = 640x350 (2 rows in
                                ; 3), 1 = 640x480 (every row twice),
                                ; 2 = 320x200 (one to one, shrunk bytes)
vcaps   db 0                    ; the hardware quiz: bit0 EGA, bit1 VGA,
                                ; bit2 MCGA (mono machines skip the bits)
hoff    dw 2048                 ; Hercules: 0 = day bank, 2048 = night
hry     dw 0                    ; Hercules: the SCREEN row being written
hbev    db 0                    ; ...and whether it is even (the bake's
                                ; density codes expand differently)
orcnt   db 0                    ; EGA: output rows this source row feeds
ooff    dw 0                    ; EGA: output row offset in A000
VCGNAME db 'CPCGA.DAT',0
VEGNAME db 'CPEGA.DAT',0
VHGNAME db 'CPHGC.DAT',0
VSDNCG  db 'CPSCGA.DAT',0       ; the side consoles' marker maps
VSDNEG  db 'CPSEGA.DAT',0
VSDNHG  db 'CPSHGC.DAT',0
vsdnam  dw 0                    ; which of the three rides this card
vsfh    dw 0                    ; the marker file while transcoding
vsbn    dw 0                    ; bytes left in the chunk buffer
vsbp    dw 0                    ; ...and the read cursor in it
cscp    dw 0                    ; cpsseg, stashed for the transcoder
; 4-bit static mask -> 8-bit, two bits per pixel, MSB pixel first
MEXP    db 000h,003h,00Ch,00Fh,030h,033h,03Ch,03Fh
        db 0C0h,0C3h,0CCh,0CFh,0F0h,0F3h,0FCh,0FFh
; the two CGA palettes as ATTRIBUTE values for the VGA-host road,
; registers 1..3. These are the EGA-style 6-bit codes (secondary bits
; at 38h), NOT CGA colour numbers - 0Bh in a palette register comes out
; teal, 3Bh is the light cyan you meant.
VPATT1  db 3Bh,3Dh,3Fh          ; light cyan, light magenta, white
VPATT0  db 3Ah,3Ch,3Eh          ; light green, light red, yellow
; the EGA packer's plane tables: entry index = first*16+second (two
; colours 0..15), TPHp gives the byte's high nibble (pixels 0-1, each
; DOUBLED to two bits), TPLp the low (pixels 2-3), one table per plane.
; Pure bit arithmetic, so FASM computes them at assemble time.
macro TPTAB maskH, maskL, p
{
  repeat 256
    db (((%-1) shr (4+p)) and 1)*maskH + (((%-1) shr p) and 1)*maskL
  end repeat
}
TPH0:   TPTAB 0C0h,30h,0
TPH1:   TPTAB 0C0h,30h,1
TPH2:   TPTAB 0C0h,30h,2
TPH3:   TPTAB 0C0h,30h,3
TPL0:   TPTAB 0Ch,03h,0
TPL1:   TPTAB 0Ch,03h,1
TPL2:   TPTAB 0Ch,03h,2
TPL3:   TPTAB 0Ch,03h,3
; the 320-wide fold: a DOUBLED plane byte's four bit-pairs back to four
; single bits, so mode 0Dh reuses the whole 640 packer and then halves
SHRK:
  repeat 256
    db (((%-1) shr 7) and 1) shl 3 + (((%-1) shr 5) and 1) shl 2 + (((%-1) shr 3) and 1) shl 1 + (((%-1) shr 1) and 1)
  end repeat
; the Hercules bake expander for EVEN screen rows: each 2-bit density
; code becomes its even-row dot pair - 0 off, quarter off, half -> the
; right dot, full -> both. (On ODD rows every code IS its own pattern -
; quarter -> right, half -> left, full -> both - so odd rows read the
; baked byte raw and no table exists for them.)
HBEXP:
  repeat 256
    db ((((%-1) shr 7) and 1)*(1+(((%-1) shr 6) and 1)*2)) shl 6 + ((((%-1) shr 5) and 1)*(1+(((%-1) shr 4) and 1)*2)) shl 4 + ((((%-1) shr 3) and 1)*(1+(((%-1) shr 2) and 1)*2)) shl 2 + ((((%-1) shr 1) and 1)*(1+((%-1) and 1)*2))
  end repeat
artrow  rb 320                  ; this row of the artwork (copied per row
bakrow  rb 160                  ; so the pixel loops need only CS; the
crow    rb 320                  ; EGA bake is nibbles, hence 160), the
epln    rb 320                  ; final-colour row and the four plane rows

; one converted pixel, artwork-compared: bit is the static-mask bit
macro CGPX bit
{
        lodsb
        cmp  al,[cs:bp]
        jne  @f
        or   dh,bit
@@:     inc  bp
        xlat [cs:bx]
        shl  dl,1
        shl  dl,1
        or   dl,al
        xor  bh,1
}
; one converted pixel, plain lookup (the front door, or no bake file)
macro CGPXP
{
        lodsb
        xlat [cs:bx]
        shl  dl,1
        shl  dl,1
        or   dl,al
        xor  bh,1
}

CGABLT:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        push ds
        push es
        ; ---- H swaps the hardware palette, in flight. It rides HERE
        ; because this code already runs once per frame on the CGA card
        ; and nowhere else - no new call site, no main-segment byte.
        ; Both halves move together: the 3D9h register AND the lookup
        ; bank, or the picture aims at colours the card no longer shows.
        mov  al,[KEYS+SC_H]     ; DS is the main segment on entry
        or   al,al
        jz   .hup
        cmp  byte [cs:vpedge],0
        jne  .hdn
        mov  byte [cs:vpedge],1
        xor  byte [cs:vpal],1
        ; TWO ROADS TO THE SAME PALETTE, split by the hardware quiz. A
        ; real CGA changes colours on its 3D9h port; a VGA playing this
        ; mode IGNORES that port AND INT 10h AH=0Bh (proven with a
        ; bands-probe, 2026-08-18) - there the four colours live in the
        ; attribute registers, remapped through INT 10h AX=1000h.
        test byte [cs:vcaps],6
        jnz  .vgap
        mov  dx,3D9h            ; the metal: one byte
        mov  al,30h             ; palette 1 intense
        cmp  byte [cs:vpal],0
        je   @f
        mov  al,10h             ; palette 0 intense
@@:    out  dx,al
        jmp  .lut
.vgap: mov  si,VPATT1          ; the VGA host: attribute regs 1..3
        cmp  byte [cs:vpal],0
        je   @f
        mov  si,VPATT0
@@:    mov  cx,3
        mov  bl,1
.vp:   push cx
        push si
        push bx
        mov  bh,[cs:si]
        mov  ax,1000h
        int  10h
        pop  bx
        pop  si
        pop  cx
        inc  si
        inc  bl
        loop .vp
.lut:  call VPALSW             ; ...and the lookup bank follows
        jmp  .hdn
.hup:  mov  byte [cs:vpedge],0
.hdn:
        mov  ax,[bufseg]
        mov  [cs:cbuf],ax
        mov  ax,[resseg]
        mov  [cs:cres],ax
        mov  ax,[pimgo]
        mov  [cs:cimg],ax
        mov  ax,[scrseg]
        mov  [cs:cscr],ax
        mov  ax,0B800h
        mov  es,ax
        cld
        mov  word [cs:cy],0
.row:
        cmp  byte [cs:vcgok],0
        je   .noart
        ; ---- pass A: this row of the artwork and of the bake, into CS,
        ; so the pixel loop below never needs a fourth segment ----
        push es
        mov  ax,cs
        mov  es,ax
        mov  ax,[cs:cy]
        mov  cx,320
        mul  cx
        add  ax,[cs:cimg]
        mov  si,ax
        mov  ds,[cs:cres]
        mov  di,artrow
        mov  cx,160
        rep  movsw
        mov  ax,[cs:cy]
        mov  cx,80
        mul  cx
        add  ax,2000h           ; the bake sits past the two map pages
        mov  si,ax
        mov  ds,[cs:cscr]
        mov  di,bakrow
        mov  cx,40
        rep  movsw
        pop  es
.noart:
        ; ---- pass B: convert the row ----
        mov  ax,[cs:cy]
        mov  cx,320
        mul  cx
        mov  si,ax
        mov  ds,[cs:cbuf]
        mov  ax,[cs:cy]
        shr  ax,1
        mov  cx,80
        mul  cx
        test byte [cs:cy],1
        jz   .ev
        add  ax,2000h
.ev:   mov  di,ax
        mov  [cs:dib],ax
        mov  bx,VLUT
        add  bx,[cs:vlutoff]
        test byte [cs:cy],1
        jz   .t0
        add  bx,512
.t0:   mov  bp,artrow
        mov  cx,80
        cmp  byte [cs:vcgok],0
        je   .plain
.mb:   xor  dx,dx
        CGPX 8
        CGPX 4
        CGPX 2
        CGPX 1
        or   dh,dh
        jz   .dyn
        cmp  dh,0Fh
        je   .sta
        push bx                 ; mixed byte: bake and lookup share it
        mov  bl,dh
        xor  bh,bh
        mov  ah,[cs:MEXP+bx]
        mov  bx,di
        sub  bx,[cs:dib]
        mov  al,[cs:bakrow+bx]
        pop  bx
        and  al,ah
        not  ah
        and  dl,ah
        or   al,dl
        jmp  .put
.sta:  push bx
        mov  bx,di
        sub  bx,[cs:dib]
        mov  al,[cs:bakrow+bx]
        pop  bx
        jmp  .put
.dyn:  mov  al,dl
.put:  stosb
        loop .mb
        jmp  .rowd
.plain:
        xor  dx,dx
        CGPXP
        CGPXP
        CGPXP
        CGPXP
        mov  al,dl
        stosb
        loop .plain
.rowd:
        inc  word [cs:cy]
        cmp  word [cs:cy],200
        jb   .row
        pop  es
        pop  ds
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        retf

; ============================================================================
;  EGABLT - the finished 320x200x256 frame onto EGA mode 10h: 640x350,
;  the picture 640x300 (width doubled, 2 source rows into 3 output
;  rows), letterboxed 25 lines top and bottom, the curated sixteen,
;  and NO dither anywhere - the pilot's call, so the lookup is flat.
;
;  Three passes per source row, each simple enough to hold in three
;  segment registers:
;    A: the artwork row and the baked row into CS (as CGABLT does);
;    0: the FINAL COLOUR row into cs:crow - lookup for what differs
;       from the artwork, the drawn grey bake for what matches (the
;       same recognition trick as CGA: no masks, no gates);
;    1: crow packed into four plane rows (cs:epln) - two table
;       lookups per plane per FOUR output pixels, tables computed at
;       assemble time;
;    2: the plane rows out to A000 through the sequencer map mask,
;       once per output row (twice for even source rows).
; ============================================================================
EGABLT:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        push ds
        push es
        mov  ax,[bufseg]        ; DS is the main segment on entry
        mov  [cs:cbuf],ax
        mov  ax,[resseg]
        mov  [cs:cres],ax
        mov  ax,[pimgo]
        mov  [cs:cimg],ax
        mov  ax,[scrseg]
        mov  [cs:cscr],ax
        cld
        mov  word [cs:cy],0
        mov  word [cs:ooff],2000 ; 640x350: 25 letterbox rows * 80 bytes
        cmp  byte [cs:vgeom],1
        jne  @f
        mov  word [cs:ooff],3200 ; 640x480: 40 letterbox rows * 80
@@:    cmp  byte [cs:vgeom],2
        jne  @f
        mov  word [cs:ooff],0    ; 320x200: no letterbox, 40-byte rows
@@:
.row:
        cmp  byte [cs:vcgok],0
        je   .noart
        ; ---- pass A: artwork row and baked row into CS ----
        push es
        mov  ax,cs
        mov  es,ax
        mov  ax,[cs:cy]
        mov  cx,320
        mul  cx
        add  ax,[cs:cimg]
        mov  si,ax
        mov  ds,[cs:cres]
        mov  di,artrow
        mov  cx,160
        rep  movsw
        mov  ax,[cs:cy]
        mov  cx,160
        mul  cx
        add  ax,2000h           ; the bake sits past the two map pages
        mov  si,ax
        mov  ds,[cs:cscr]
        mov  di,bakrow
        mov  cx,80
        rep  movsw
        pop  es
.noart:
        ; ---- pass 0: the final-colour row into cs:crow ----
        push es
        mov  ax,cs
        mov  es,ax
        mov  ax,[cs:cy]
        mov  cx,320
        mul  cx
        mov  si,ax
        mov  ds,[cs:cbuf]
        mov  di,crow
        mov  bx,ELUT
        add  bx,[cs:elutoff]
        mov  bp,artrow
        mov  cx,320
        cmp  byte [cs:vcgok],0
        je   .q0
.p0:   lodsb
        cmp  al,[cs:bp]
        jne  .dl
        push bx                 ; the artwork: its baked nibble
        mov  bx,di
        sub  bx,crow            ; x
        shr  bx,1               ; CF = x&1: odd pixel rides the low nibble
        mov  al,[cs:bakrow+bx]
        jc   .lo
        shr  al,1
        shr  al,1
        shr  al,1
        shr  al,1
        jmp  .ns
.lo:   and  al,0Fh
.ns:   pop  bx
        jmp  .pw
.dl:   xlat [cs:bx]            ; anything drawn over it: the lookup
.pw:   inc  bp
        stosb
        loop .p0
        jmp  .pack
.q0:   lodsb                   ; no bake file: the whole row converts
        xlat [cs:bx]
        stosb
        loop .q0
.pack:
        ; ---- pass 1: crow -> four plane rows, all inside CS ----
        mov  ax,cs
        mov  ds,ax
        mov  si,crow
        mov  di,epln
        xor  bh,bh
        mov  cx,80
.p1:   lodsb
        mov  dl,al
        shl  dl,1
        shl  dl,1
        shl  dl,1
        shl  dl,1
        lodsb
        or   dl,al              ; first pair of colours
        lodsb
        mov  dh,al
        shl  dh,1
        shl  dh,1
        shl  dh,1
        shl  dh,1
        lodsb
        or   dh,al              ; second pair
        mov  bl,dl
        mov  al,[TPH0+bx]
        mov  bl,dh
        or   al,[TPL0+bx]
        mov  [di],al
        mov  bl,dl
        mov  al,[TPH1+bx]
        mov  bl,dh
        or   al,[TPL1+bx]
        mov  [di+80],al
        mov  bl,dl
        mov  al,[TPH2+bx]
        mov  bl,dh
        or   al,[TPL2+bx]
        mov  [di+160],al
        mov  bl,dl
        mov  al,[TPH3+bx]
        mov  bl,dh
        or   al,[TPL3+bx]
        mov  [di+240],al
        inc  di
        loop .p1
        cmp  byte [cs:vgeom],2
        jne  .noshr
        ; ---- 320-wide only: fold the doubled plane rows in half. The
        ; planes pack down contiguously (40 bytes each), so pass 2's
        ; flow from plane to plane survives unchanged. ----
        mov  si,epln
        mov  di,epln            ; reader stays ahead of the writer
        mov  bx,SHRK
        mov  cx,160             ; 4 planes x 40 output bytes
.sh:   lodsb
        xlatb
        shl  al,1
        shl  al,1
        shl  al,1
        shl  al,1
        mov  ah,al
        lodsb
        xlatb
        or   al,ah
        stosb
        loop .sh
.noshr:
        pop  es                  ; ES back to whatever the caller... no -
        push es                  ; keep the stack balanced; A000 goes in
        mov  ax,0A000h           ; fresh either way
        mov  es,ax
        ; ---- pass 2: the plane rows out - once, twice, or 2-into-3 ----
        mov  al,2
        cmp  byte [cs:vgeom],1
        je   .rc                 ; 640x480: every source row twice
        cmp  byte [cs:vgeom],2
        jne  .g0
        mov  al,1                ; 320x200: once
        jmp  .rc
.g0:   test byte [cs:cy],1     ; 640x350: even source rows paint two
        jz   .rc
        dec  al
.rc:   mov  [cs:orcnt],al
.wrow: mov  si,epln
        mov  bp,[cs:ooff]
        mov  bl,1               ; plane mask walks 1,2,4,8
.pl:   mov  dx,3C4h
        mov  al,2
        out  dx,al
        inc  dx
        mov  al,bl
        out  dx,al
        mov  di,bp
        mov  cx,40
        cmp  byte [cs:vgeom],2
        jne  @f
        mov  cx,20              ; 40-byte rows in the 320-wide mode
@@:    rep  movsw              ; DS=CS: epln flows plane to plane
        shl  bl,1
        cmp  bl,10h
        jb   .pl
        mov  ax,80
        cmp  byte [cs:vgeom],2
        jne  @f
        mov  ax,40
@@:    add  [cs:ooff],ax
        dec  byte [cs:orcnt]
        jnz  .wrow
        pop  es
        inc  word [cs:cy]
        cmp  word [cs:cy],200
        jb   .row
        ; leave the map mask open on all four planes, the BIOS default
        mov  dx,3C4h
        mov  al,2
        out  dx,al
        inc  dx
        mov  al,0Fh
        out  dx,al
        pop  es
        pop  ds
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        retf

; ============================================================================
;  HGCBLT - the finished 320x200x256 frame onto Hercules: 720x348 mono,
;  the picture 640x300 (width doubled, 2 source rows into 3 screen
;  rows), boxed 40 dots left and right and 24 rows top and bottom.
;
;  Mono is dither DENSITY, and the tables carry all of it: HLUT maps a
;  palette byte to its TWO output dots (the pixel is doubled) through a
;  4x4 Bayer on luminance, phase picked by screen row & 3 - so the
;  SAME source row converts differently for each of its duplicate
;  screen rows, and the grain stays 1:1 on the glass. The panel rides
;  the same artwork-recognition as every card: a bufseg byte equal to
;  the artwork's takes its baked density code (CPHGC.DAT - seams off,
;  texture a quarter, plates half, strokes and lamps full), expanded
;  per row parity; everything drawn over it converts through HLUT.
;
;  B000 is 4-way interlaced: row y lives at (y&3)*2000h + (y/4)*90,
;  90 bytes a row, our 80 start 5 bytes in.
; ============================================================================
HGCBLT:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        push ds
        push es
        mov  ax,[bufseg]        ; DS is the main segment on entry
        mov  [cs:cbuf],ax
        mov  ax,[resseg]
        mov  [cs:cres],ax
        mov  ax,[pimgo]
        mov  [cs:cimg],ax
        mov  ax,[scrseg]
        mov  [cs:cscr],ax
        mov  ax,0B000h
        mov  es,ax
        cld
        mov  word [cs:cy],0
        mov  word [cs:hry],24   ; the first picture row under the box
.row:
        cmp  byte [cs:vcgok],0
        je   .noart
        ; ---- pass A: this row of the artwork and of the bake ----
        push es
        mov  ax,cs
        mov  es,ax
        mov  ax,[cs:cy]
        mov  cx,320
        mul  cx
        add  ax,[cs:cimg]
        mov  si,ax
        mov  ds,[cs:cres]
        mov  di,artrow
        mov  cx,160
        rep  movsw
        mov  ax,[cs:cy]
        mov  cx,80
        mul  cx
        add  ax,2000h
        mov  si,ax
        mov  ds,[cs:cscr]
        mov  di,bakrow
        mov  cx,40
        rep  movsw
        pop  es
.noart:
        mov  al,2               ; even source rows paint two screen rows
        test byte [cs:cy],1
        jz   .rc
        dec  al
.rc:   mov  [cs:orcnt],al
.orow:
        ; ---- where on the glass, and which grain ----
        mov  ax,[cs:hry]
        mov  dx,ax
        and  dx,3
        mov  cl,13
        shl  dx,cl              ; (y&3)*2000h
        mov  di,dx
        shr  ax,1
        shr  ax,1
        mov  bx,90
        mul  bx
        add  di,ax
        add  di,5               ; 40 dots of left box
        mov  [cs:dib],di
        mov  ax,[cs:hry]
        and  al,1
        xor  al,1
        mov  [cs:hbev],al       ; 1 when the screen row is even
        mov  ax,[cs:hry]
        and  ax,3
        mov  bx,ax
        add  bx,bx              ; (y&3)*2 tables of 256...
        mov  cl,8
        shl  bx,cl              ; ...= (y&3)*512
        add  bx,HLUT
        add  bx,[cs:hoff]
        ; ---- source row in, converted bits out ----
        mov  ax,[cs:cy]
        mov  cx,320
        mul  cx
        mov  si,ax
        mov  ds,[cs:cbuf]
        mov  bp,artrow
        mov  cx,80
        cmp  byte [cs:vcgok],0
        je   .plain
.mb:   xor  dx,dx
        CGPX 8
        CGPX 4
        CGPX 2
        CGPX 1
        or   dh,dh
        jz   .dyn
        cmp  dh,0Fh
        je   .sta
        push bx                 ; mixed byte: bake and lookup share it
        mov  bl,dh
        xor  bh,bh
        mov  ah,[cs:MEXP+bx]
        mov  bx,di
        sub  bx,[cs:dib]
        mov  al,[cs:bakrow+bx]
        cmp  byte [cs:hbev],0
        je   @f
        mov  bx,HBEXP           ; even rows expand the density codes
        xlat [cs:bx]
@@:    pop  bx
        and  al,ah
        not  ah
        and  dl,ah
        or   al,dl
        jmp  .put
.sta:  push bx
        mov  bx,di
        sub  bx,[cs:dib]
        mov  al,[cs:bakrow+bx]
        cmp  byte [cs:hbev],0
        je   @f
        mov  bx,HBEXP
        xlat [cs:bx]
@@:    pop  bx
        jmp  .put
.dyn:  mov  al,dl
.put:  stosb
        loop .mb
        jmp  .rowd
.plain:
        xor  dx,dx
        CGPXP
        CGPXP
        CGPXP
        CGPXP
        mov  al,dl
        stosb
        loop .plain
.rowd:
        inc  word [cs:hry]
        dec  byte [cs:orcnt]
        jnz  .orow
        inc  word [cs:cy]
        cmp  word [cs:cy],200
        jb   .row
        pop  es
        pop  ds
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        retf

; ============================================================================
;  VPALSWF - the lookup banks follow the day/night switch. Called from
;  APPLYPALF's tail (DS = the main segment there), so the L key keeps
;  working on every card without one extra call site.
; ============================================================================
VPALSWF:
        call VPALSW
        retf
VPALSW:                          ; the near core: CGABLT's H key needs it
        mov  word [cs:vlutoff],0 ; too, and a far proc cannot be near-called
        mov  word [cs:elutoff],0
        mov  word [cs:hoff],0
        cmp  byte [daymode],0
        jne  .d
        mov  word [cs:vlutoff],1024
        mov  word [cs:elutoff],256
        mov  word [cs:hoff],2048
.d:    cmp  byte [cs:vpal],0   ; the CGA hardware palette picks its own
        je   .p                  ; pair of banks on top of day/night
        add  word [cs:vlutoff],2048
.p:    ret

; ============================================================================
;  VCGLDF - the picked card's baked panel into scrseg:2000h, one page
;  past the two minimap pages (scrseg's 64K had 56K spare; there is no
;  free page above sfxseg). CGA takes CPCGA.DAT (16000 bytes, 2-bit
;  pixels), EGA takes CPEGA.DAT (32000 bytes, nibbles). No file, or the
;  drawn-panel fallback, and the game flies on with the plain lookup.
; ============================================================================
VCGLDF:
        mov  byte [cs:vcgok],0
        cmp  word [pimgo],0
        je   .no                ; drawn-panel fallback: nothing to compare
        mov  ax,[scrseg]
        mov  [cs:cscr],ax
        mov  al,[vcard]
        cmp  al,VMHERC
        je   .hg
        cmp  al,VMCGA
        je   .cg
        cmp  al,VMEGA
        jb   .no
        cmp  al,VMV480
        ja   .no                ; the straight modes carry no bake
        mov  dx,VEGNAME         ; the whole 16-colour family shares one
        mov  cx,32000           ; drawn panel
        mov  word [cs:vsdnam],VSDNEG
        jmp  .op
.hg:   mov  dx,VHGNAME         ; the density codes
        mov  cx,16000
        mov  word [cs:vsdnam],VSDNHG
        jmp  .op
.cg:   mov  dx,VCGNAME
        mov  cx,16000
        mov  word [cs:vsdnam],VSDNCG
.op:   mov  [cs:vbklen],cx
        push ds
        mov  ax,cs
        mov  ds,ax
        mov  ax,3D00h
        int  21h
        jc   .fail
        mov  bx,ax
        mov  ds,[cs:cscr]
        mov  dx,2000h
        mov  cx,[cs:vbklen]
        mov  ah,3Fh
        int  21h
        mov  si,ax              ; bytes actually read
        mov  ah,3Eh
        int  21h
        cmp  si,[cs:vbklen]
        jne  .fail
        pop  ds
        mov  byte [cs:vcgok],1
        call VSDTRAN            ; ...and the side consoles, in place
        retf
.fail: pop  ds
.no:   retf

; ============================================================================
;  VSDTRAN - the F6/F7 side consoles for the retro cards. They exist
;  only as RLE streams in cpsseg (SIDEBMPF plays them straight onto the
;  glass), so the bake cannot ride a flat page - instead the streams
;  are TRANSCODED IN PLACE, once, here: every artwork byte becomes a
;  MARKER, 200 + colour, a range the 137-entry palette never reaches,
;  taken from the card's marker map (CPS*.DAT, one flat byte per pixel,
;  left view then right, streamed through a 1K chunk of the row
;  scratch). The lookup tables carry entries for the markers - phases
;  and all, so the CGA checker and the Hercules densities stay
;  positional even inside a long run. SIDEBMPF never changes: it keeps
;  copying bytes, the bytes just mean better. A run takes its first
;  position's marker - a run is one flat patch of one band anyway.
;  DS = the main segment on entry. No file, and the sides simply stay
;  on the plain lookup.
; ============================================================================
VSDTRAN:
        cmp  word [cpsseg],0
        je   .r                  ; no side views loaded: nothing to do
        mov  ax,[cpsseg]
        mov  [cs:cscp],ax
        push ds
        mov  ax,cs
        mov  ds,ax
        mov  dx,[vsdnam]
        mov  ax,3D00h
        int  21h
        pop  ds
        jc   .r
        mov  [cs:vsfh],ax
        mov  word [cs:vsbn],0   ; the chunk buffer starts empty
        mov  si,[cplo]
        call VSDONE
        mov  si,[cpro]          ; the right view follows the left in the
        call VSDONE             ; file, so the cursor is already there
        mov  bx,[cs:vsfh]
        mov  ah,3Eh
        int  21h
.r:    ret

; ---- one stream: walk the tokens, substitute the values -------------------
VSDONE: push ds
        mov  ds,[cs:cscp]
.t:    lodsb                   ; token
        or   al,al
        jz   .d
        mov  bl,al
        and  al,3Fh
        mov  cl,al
        xor  ch,ch
        or   cl,cl
        jnz  .n
        lodsw                   ; count 0: a word count follows
        mov  cx,ax
.n:    and  bl,0C0h
        cmp  bl,0C0h
        je   .skip
        cmp  bl,80h
        je   .run
.lp:   call VSGETB             ; literal: every byte gets its marker
        mov  [si],al
        inc  si
        loop .lp
        jmp  .t
.run:  call VSGETB             ; a run takes its first marker...
        mov  [si],al
        inc  si
        dec  cx
        jcxz .t
.sk2:  call VSGETB             ; ...and drops the rest of its span
        loop .sk2
        jmp  .t
.skip: jcxz .t
.sk3:  call VSGETB             ; transparent: consume, drop
        loop .sk3
        jmp  .t
.d:    pop  ds
        ret

; ---- the next marker-map byte, chunked through the row scratch ------------
VSGETB: push bx
        push cx
        push dx
        push ds
        cmp  word [cs:vsbn],0
        jne  .g
        mov  ax,cs
        mov  ds,ax
        mov  dx,artrow          ; the blit's row scratch is idle at load
        mov  cx,1024
        mov  bx,[vsfh]
        mov  ah,3Fh
        int  21h
        jc   .z
        or   ax,ax
        jz   .z
        mov  [vsbn],ax
        mov  word [vsbp],0
        jmp  .g
.z:    pop  ds                 ; starved: hand back black and carry on
        pop  dx
        pop  cx
        pop  bx
        xor  al,al
        ret
.g:    mov  bx,[cs:vsbp]
        mov  al,[cs:artrow+bx]
        inc  word [cs:vsbp]
        dec  word [cs:vsbn]
        pop  ds
        pop  dx
        pop  cx
        pop  bx
        ret

        include 'VIDLUT.INC'   ; the 256->4 tables, day and night, from
                                ; TOOLS\VidRig emit - regenerate after any
                                ; PALDAY/PALNITE change

label VIDEND byte
        rb 5FF0h - $   ; claim the whole window - TWENTY-FOUR K since the
                        ; second CGA palette's banks (each growth moved
                        ; bufseg and resseg up 200h; the note beside
                        ; resseg keeps the count. CITY.DAT now ends 79
                        ; paragraphs short of sndseg's guaranteed floor -
                        ; the NEXT growth must take a page ABOVE instead)
