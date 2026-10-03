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

; BOND: TWO ROWS, NOT SEVEN. The machine it is cut for has a CGA or a
; Hercules screen and nothing else, so the menu offers exactly those -
; the converters for the other five are still in this segment, simply
; never picked. VMROWS is the one number the loops below walk to.
VMROWS  = 2
vmsel   db 2                    ; the chevron's perch, a MENU row:
                                ; row 2 is CGA, the default
VMRDY   db 1,1                  ; every menu row is BUILT
VMOKT   rb VMROWS               ; ...but only what THIS machine owns is
                                ; offered: filled per boot by VMENUF's
                                ; hardware quiz. The pilot picked
                                ; Hercules on a VGA host and got a
                                ; blinking cursor over an invisible
                                ; game - the menu asks the machine now.
VMNONE  db '- NOT IN THIS MACHINE',0
VMPICK  db VMHERC,VMCGA         ; menu row -> internal code

VMTEXT  db 13,10
        db '  OWL FLY III BOND',13,10
        db 13,10
        db '  SELECT VIDEO SYSTEM',13,10
        db 13,10
        db '    1) HERCULES    720x348    MONO',13,10
        db '    2) CGA         320x200    4 COLORS',13,10
        db 13,10
        db '  PRESS 1..2, OR ARROWS AND ENTER',13,10,0

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
; BOND: no Blaster row at all - the speaker is item 1 and the default.
SMTEXT  db 13,10
        db '  OWL FLY III BOND',13,10
        db 13,10
        db '  SELECT SOUND SYSTEM',13,10
        db 13,10
        db '    1) PC SPEAKER     one square wave, 1981 style',13,10
        db '    2) NO SOUND       instruments only',13,10
        db 13,10
        db '  The speaker bends one tone: the engine is a drone that spools',13,10
        db '  with the lever, guns clatter, and a warning is a plain beep.',13,10
        db 13,10
        db '  PRESS 1..2, OR ARROWS AND ENTER',13,10,0

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
        ; BOND: the quiz is one question - mono or colour. A mono machine
        ; owns Hercules, a colour one owns CGA (every colour card speaks
        ; mode 4, the Bondwell's LCD included).
        mov  byte [cs:VMOKT+0],0
        mov  byte [cs:VMOKT+1],1
        cmp  ax,3B4h
        jne  .quizd
        mov  byte [cs:VMOKT+0],1
        mov  byte [cs:VMOKT+1],0
.quizd:
        ; only what is BUILT stays offered
        xor  bx,bx
        mov  cx,VMROWS
.mg:   mov  al,[cs:VMRDY+bx]
        and  [cs:VMOKT+bx],al
        inc  bx
        loop .mg
        ; the chevron's default: the best row this machine owns
        mov  bl,VMROWS
.df:   xor  bh,bh
        cmp  byte [cs:VMOKT-1+bx],0
        jne  .dok
        dec  bl
        jnz  .df
        mov  bl,VMROWS          ; nothing offered? then the last row
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
        cmp  bl,VMROWS+1
        jb   .mk
        call VMMARK             ; the chevron on the default
.key:  xor  ah,ah
        int  16h                ; BIOS keyboard: AL ascii, AH scan
        cmp  al,0Dh
        je   .take
        cmp  al,'1'
        jb   .ext
        cmp  al,'0'+VMROWS
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
        cmp  bl,VMROWS+1
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
        mov  al,2               ; BOND: no detail screen - always LOW. QMENU
        push ax                 ;  stays below, assembled and never called
        call SMENU              ; ...then the sound, on its own screen
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

; ---- SMENU: the sound screen. Returns AL = 1 speaker / 2 none -------------
;  BOND: two rows and no quiz - the speaker and silence are never refused,
;  every PC since the first one has both. The codes stay v3's (1 and 2)
;  so SBINIT and everything after it read them unchanged; 0, the Blaster,
;  can no longer come out of here.
SMENU:  mov  ah,0Fh             ; re-enter the mode: cleared, black, home
        int  10h
        xor  ah,ah
        int  10h
        mov  si,SMTEXT
        call VMPUTS
        mov  byte [cs:vmsel],1  ; the chevron on the speaker
        call VMMARK
.k:    xor  ah,ah
        int  16h
        cmp  al,0Dh             ; ENTER takes whatever the chevron is on
        je   .take
        cmp  al,'1'
        jb   .ext
        cmp  al,'2'
        ja   .ext
        sub  al,'0'
        mov  bl,al
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
        mov  bl,2
        call VMMOVE
        jmp  .k
.up:   mov  bl,1
        call VMMOVE
        jmp  .k
.take: mov  al,[cs:vmsel]      ; row 1 speaker, row 2 none - v3's codes
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
        call BONDLUT            ; BOND: the panel's colours SOLID, first
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
;  BONDLUT - the BOND's panel colours, made SOLID in the lookups. VidRig
;  cut VLUT and HLUT to IMITATE the VGA colour of every index: a dither for
;  a shade CGA has not got, Bayer densities on the mono card, and black for
;  much of the night bank. That is right for the world and wrong for the
;  panel - a caption is not a shade of amber, it is TEXT, one ink. So every
;  index the panel draws with gets one flat value in every phase of every
;  bank, day and night, both CGA palettes. Run once, before the mode goes
;  up; the tables live in this segment and nothing else writes them.
;  The vector cockpit draws in the 200..203 markers (VPDL in SYM.INC):
;  black, the frame ink, the accent ink, white.
;  Each row: palette index, CGA value (0..3 of the palette), Hercules value
;  (0 dark, 3 both dots lit).
; ============================================================================
BLTAB   db 200,0,0              ; the panel's black
        db 201,1,3              ; frame ink: cyan (palette 0: green)
        db 202,2,3              ; accent ink: magenta (palette 0: red)
        db 203,3,3              ; white
        db 97,3,3               ; the amber the MFD pages title in
        db 108,1,3              ; PNLCAP - the lamp captions
        db 109,1,3              ; PNLDIM - a legend that is not lit: still
                                ;  READ on the mono card, or half the keypad
                                ;  captions vanish (seen, 2026-10-02)
        db 110,1,3              ; PNLGRN, and its shadow and band below
        db 111,3,3              ; PNLAMB
        db 112,2,3              ; PNLRED
        db 113,1,3
        db 114,3,3
        db 115,2,3
        db 116,0,0              ; PNLNOIS - glass speckle: just glass now
        db 117,1,3
        db 118,3,3
        db 119,2,3
        db SKYK,1,0             ; the BOND's sky: cyan, dark on the mono card
        db GNDK,0,0             ; ...and its ground: black
        db 6,2,3                ; the LOW lattice: magenta, lit on mono - it
                                ;  drew in a black that sat on black ground
BLTABN  = ($-BLTAB)/3
SKYK    = 204                   ; the two markers SKYGNDF paints with
GNDK    = 205
BONDLUT:
        push es
        mov  ax,cs
        mov  es,ax
        ; ---- FIRST: CYAN BELONGS TO THE SKY. Every world ink VidRig sent
        ; to cyan (1) goes to white (3) instead, in every phase of every
        ; bank - a cyan jet, a cyan HUD box or a cyan word would vanish
        ; into a cyan sky. The panel's own inks are set after this, by
        ; BLTAB, and may use cyan again: the panel is on black.
        mov  di,VLUT+1
        mov  cx,16*256-1
.cy:   cmp  byte [es:di],1
        jne  .cn
        mov  byte [es:di],3
.cn:   inc  di
        loop .cy
        mov  si,BLTAB
        mov  dx,BLTABN
.row:  mov  bl,[cs:si]         ; the index...
        xor  bh,bh
        mov  al,[cs:si+1]       ; ...its CGA ink into all 16 VLUT tables
        mov  di,VLUT
        add  di,bx
        mov  cx,16
.vl:   mov  [es:di],al
        add  di,256
        loop .vl
        mov  al,[cs:si+2]       ; ...its Hercules dots into all 16 HLUT
        mov  di,HLUT
        add  di,bx
        mov  cx,16
.hl:   mov  [es:di],al
        add  di,256
        loop .hl
        add  si,3
        dec  dx
        jnz  .row
        pop  es
        ret

; ============================================================================
;  VBLITF - bufseg out to a retro card, one converter per vcard.
; ============================================================================
; VRSET r0,r1,c0,cn - the band the next VCONV converts: rows r0..r1-1,
; bytes c0..c0+cn-1 of each (four pixels a byte on both cards)
macro VRSET r0,r1,c0,cn {
        mov  word [cs:vr0],r0
        mov  word [cs:vr1],r1
        mov  word [cs:vc0],c0
        mov  word [cs:vcx4],(c0)*4
        mov  word [cs:vcn],cn
}

VBLITF:
        ; ---- BOND: WHICH PART OF THE SCREEN. A PARTIAL frame (vpart,
        ; decided in SKYGNDF; the panel really was drawn this frame, vpran)
        ; converts the window on the world alone. A FULL cockpit frame
        ; converts three bands - the overhead strip, the window, the panel -
        ; and NOT the black walls either side of the window: nothing ever
        ; draws there, so once is enough. They go through on the first
        ; cockpit frame after anything else (vpprev 0: a menu, F6/F7, a
        ; camera) and whenever Ctrl+D is up, because the profiler's numbers
        ; are written on them. Anything that is not a cockpit frame - and
        ; every card but CGA and Hercules - converts all 200 rows.
        ; vpran is used up here, so a second blit in a frame is a full one.
        mov  word [clipx0],0    ; whatever draws next - a menu, the crash
        mov  word [clipx1],319  ;  screen - draws on the whole screen
        mov  word [clipy0],0
        mov  word [clipy1],199
        mov  al,[cs:vplast]
        mov  [cs:vpprev],al     ; was the frame before a cockpit frame too?
        mov  al,[cs:vpran]
        mov  [cs:vplast],al     ; next frame may go partial only after this
        mov  byte [cs:vpran],0
        VRSET 0,200,0,80        ; (the default, for every road below)
        mov  bl,[vcard]
        cmp  bl,VMCGA
        je   .reg
        cmp  bl,VMHERC
        jne  .old
.reg:  or   al,al
        jz   .one              ; not a cockpit frame: the whole screen
        cmp  byte [cs:vpart],0
        jne  .part
        cmp  byte [cs:vpprev],0
        je   .one              ; the first cockpit frame: walls included
        cmp  byte [dbgm],0      ; the profiler writes on the walls - but
        je   .bands            ;  its numbers change once in 16 frames, so
        inc  byte [cs:vwcnt]    ;  once in four FULL frames is enough, and
        test byte [cs:vwcnt],3  ;  the profile stays honest about the bands
        jz   .one
.bands: VRSET 0,VPG0,92/4,(224-92)/4            ; the overhead BANK only:
                                                ;  x 92..223, the lenses and
                                                ;  the burner slot - the rest
                                                ;  of the strip is still wall
        call VCONV
        VRSET VPG0,VPG1,WINX0/4,(WINX1-WINX0)/4  ; the window
        call VCONV
        VRSET VPG1,200,0,80                     ; the panel
        call VCONV
        retf
.part: VRSET VPG0,VPG1,WINX0/4,(WINX1-WINX0)/4  ; the window alone
.one:  call VCONV
        retf
.old:  mov  al,bl              ; v3's road for the other cards
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
@@:    retf
vpprev  db 0                    ; vplast as it was BEFORE this frame
vwcnt   db 0                    ; full frames, for the profiler's walls

; VCONV - one band (vr0/vr1, vc0/vcx4/vcn) through the card's converter.
; Both converters end in RETF, so they are called far from here.
VCONV:  cmp  byte [vcard],VMCGA
        jne  .h
        push cs
        call CGABLT
        ret
.h:    push cs
        call HGCBLT
        ret

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
}                               ; BOND: no "xor bh,1" - the inks are SOLID
                                ;  (BONDLUT), so the x&1 dither phase is one
                                ;  table, not two; 4 of ~44 clocks a pixel

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
        mov  ax,[cs:vr0]        ; BOND: from the first row this frame
        mov  [cs:cy],ax         ;  converts (VBLITF sets vr0/vr1)
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
        add  si,[cs:vcx4]       ; BOND: the window's columns only (VBLITF)
        add  di,[cs:vc0]
        mov  cx,[cs:vcn]
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
        shr  cx,1               ; BOND: two bytes a turn - the loop's own
.pl2:  xor  dx,dx              ;  17 clocks paid half as often (vcn is
        CGPXP                   ;  always even: 80 or 48)
        CGPXP
        CGPXP
        CGPXP
        mov  al,dl
        stosb
        xor  dx,dx
        CGPXP
        CGPXP
        CGPXP
        CGPXP
        mov  al,dl
        stosb
        loop .pl2
.rowd:
        inc  word [cs:cy]
        mov  ax,[cs:cy]
        cmp  ax,[cs:vr1]        ; BOND: to the last
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
        mov  ax,[cs:vr0]        ; BOND: from the first row this frame
        mov  [cs:cy],ax         ;  converts - and the screen row it lands
        mov  bx,ax              ;  on: 24 + r0 + ceil(r0/2), since even
        inc  bx                 ;  rows paint two screen rows, odd one
        shr  bx,1
        add  ax,bx
        add  ax,24
        mov  [cs:hry],ax        ; the first picture row under the box
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
        add  si,[cs:vcx4]       ; BOND: the window's columns only (VBLITF)
        add  di,[cs:vc0]
        mov  cx,[cs:vcn]
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
        shr  cx,1               ; BOND: two bytes a turn - the loop's own
.pl2:  xor  dx,dx              ;  17 clocks paid half as often (vcn is
        CGPXP                   ;  always even: 80 or 48)
        CGPXP
        CGPXP
        CGPXP
        mov  al,dl
        stosb
        xor  dx,dx
        CGPXP
        CGPXP
        CGPXP
        CGPXP
        mov  al,dl
        stosb
        loop .pl2
.rowd:
        inc  word [cs:hry]
        dec  byte [cs:orcnt]
        jnz  .orow
        inc  word [cs:cy]
        mov  ax,[cs:cy]
        cmp  ax,[cs:vr1]        ; BOND: to the last
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

; ============================================================================
;  VPANELF / VPSIDEF - THE BOND'S COCKPIT, DRAWN. v3 copied a 64000-byte
;  photograph into the back buffer every frame (and two RLE photographs for
;  the F6/F7 side consoles) and the retro cards then dithered them; the BOND
;  draws the same cockpit from lists of strokes instead - the canopy bows,
;  the overhead bank, the three screens and their button columns, the side
;  consoles with their boxes and levers - in the four inks a CGA and a
;  Hercules can show SOLID (the 200..203 markers, made flat by BONDLUT).
;  That is the photographs out of CITY.DAT, CPSIDE.DAT and memory, and a
;  picture that is lines and words the way a 1980s panel was drawn.
;
;  Every coordinate below was taken off the photos (cockpit2_edit.png,
;  cockpit_left/right_art.bmp), so the code that draws ON the front panel
;  - the PZRDR/PZADI/PZMAP screens, the OSB lamps, the overhead lenses,
;  the side annunciators, the digit row - still lands in its sockets.
;
;  It lives in VIDSEG because SYMSEG had a few hundred bytes left and this
;  segment carries five converters the BOND never runs.
;
;  The list, one record per stroke (x a word, y a byte):
;    1 FILL  x,y,w,h,ink        a solid box
;    2 FRAME x,y,w,h,ink        a one-pixel outline
;    3 LINE  x0,y0,x1,y1,ink    through CLIPLINE and the engine's LINE
;    4 BAR   x0,y0,x1,y1,w,ink  a slanted bar w wide, its left edge from
;                               (x0,y0) to (x1,y1) - a canopy bow
;    5 TEXT  x,y,ink,'ABC'      the 4x6 font, five letters at most
;    6 SPAN  x0,y0,x1,y1,xs,ink every row from the edge (x0,y0)-(x1,y1)
;                               across to column xs - a canopy frame, a sill
;    0 the end
;  ES = bufseg, DS = the main segment. Everything is saved.
; ============================================================================
; ============================================================================
;  SKYGNDF - THE BOND'S SKY AND GROUND. LOW used to clear the whole back
;  buffer to index 0, which CGA shows as magenta: sky and ground were one
;  colour and only the black lattice told them apart. Now each row is cut
;  where the horizon crosses it - the same line CLEARBUF anchors, through
;  (cx0,hcur) and tilted by the roll (sinr,cosr) - sky on one side, ground
;  on the other, two flat inks (SKYK/GNDK, flattened by BONDLUT). No ramp,
;  no dither, no stars: one word fill a side (SGFILL).
;
;  A point is GROUND when (y-hcur)*cosr - (x-cx0)*sinr > 0. Per row that is
;  a single crossing xb = cx0 + (y-hcur)*cosr/sinr; nearly level (|sinr|
;  under 8) the whole row goes by the sign alone, which is also what keeps
;  the divide from overflowing - |y-hcur| is clamped to 500 first, so the
;  quotient stays under 16000. ES = bufseg, DS = the main segment.
; ============================================================================
SKYGNDF:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        ; ---- the frame's first word, so the frame's DECISIONS live here.
        ; PARTIAL: only after a frame that drew the front cockpit (vplast),
        ; three frames in four - the fourth redraws the whole panel, its
        ; screens and its lamps. See VBLITF/VPANELF.
        inc  byte [cs:vpcnt]
        mov  byte [cs:vpart],0
        cmp  byte [cs:vplast],0
        je   @f
        test byte [cs:vpcnt],VPEVERY-1
        jz   @f
        mov  byte [cs:vpart],1
@@:     ; ---- THE WINDOW: after a cockpit frame the world is seen through
        ; the small window WINX0..WINX1-1 x VPG0..VPG1-1 alone, on every
        ; frame, full or partial. The line clipper is narrowed to it - the
        ; world is not even drawn past its edges - and only it is filled.
        ; The full frame's panel paints the walls round it (VPDL).
        mov  word [clipx0],0
        mov  word [clipx1],319
        mov  word [clipy0],0
        mov  word [clipy1],199
        mov  word [cs:sgx0],0
        mov  word [cs:sgx1],320
        xor  si,si              ; the first row...
        mov  word [cs:sgend],200 ; ...and the row to stop before
        cmp  byte [cs:vplast],0
        je   @f
        mov  word [clipx0],WINX0
        mov  word [clipx1],WINX1-1
        mov  word [clipy0],VPG0
        mov  word [clipy1],VPG1-1
        mov  word [cs:sgx0],WINX0
        mov  word [cs:sgx1],WINX1
        mov  si,VPG0
        mov  word [cs:sgend],VPG1
@@:    mov  ax,si              ; DI = the first row's first filled byte
        mov  cx,320
        mul  cx
        add  ax,[cs:sgx0]
        mov  di,ax
        mov  ax,[cs:sgx1]       ; ...and the step from one row's end to the
        sub  ax,[cs:sgx0]       ;  next one's start
        neg  ax
        add  ax,320
        mov  [cs:sgskip],ax
        cld
.row:  mov  ax,si
        sub  ax,[hcur]
        cmp  ax,500
        jle  @f
        mov  ax,500
@@:    cmp  ax,-500
        jge  @f
        mov  ax,-500
@@:    imul word [cosr]        ; DX:AX = (y-hcur)*cosr
        mov  bx,[sinr]
        mov  cx,bx
        or   cx,cx
        jns  @f
        neg  cx
@@:    cmp  cx,8
        jae  .tilt
        mov  bl,SKYK            ; level: the sign decides the whole row
        or   dx,dx
        js   .one
        jnz  .gnd
        or   ax,ax
        jz   .one
.gnd:  mov  bl,GNDK
.one:  mov  al,bl
        mov  ah,bl
        xor  cx,cx              ; one colour: the crossing anywhere will do
        jmp  .fill
.tilt: idiv bx                 ; the crossing, relative to cx0
        add  ax,[cx0]
        mov  cx,ax
        mov  al,GNDK            ; sinr > 0: the ground is on the left
        mov  ah,SKYK
        or   bx,bx
        jns  .fill
        xchg al,ah              ; sinr < 0: the sky is
.fill: cmp  cx,[cs:sgx0]       ; the crossing, held inside the fill
        jge  @f
        mov  cx,[cs:sgx0]
@@:    cmp  cx,[cs:sgx1]
        jle  @f
        mov  cx,[cs:sgx1]
@@:    push cx
        sub  cx,[cs:sgx0]
        call SGFILL             ; left of the crossing...
        pop  cx
        neg  cx
        add  cx,[cs:sgx1]
        mov  al,ah
        call SGFILL             ; ...and right of it
        add  di,[cs:sgskip]
.next: inc  si
        cmp  si,[cs:sgend]
        jb   .row
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        retf
sgend   dw 200                  ; the row SKYGNDF stops before
sgx0    dw 0                    ; ...and the columns it fills
sgx1    dw 320
sgskip  dw 0
WINX0   = 64                    ; THE WINDOW ON THE WORLD, columns (rows are
WINX1   = 256                   ;  VPG0..VPG1): 192 wide, centred - 60% of
                                ;  the glass, and every frame pays for it in
                                ;  fill, clipped lines and conversion alike

; SGFILL - CX bytes of AL at ES:DI, by words: on an 8088 a rep stosw costs
; about 7 clocks a byte against stosb's 10. AX is kept.
SGFILL: push ax
        mov  ah,al
        shr  cx,1
        rep  stosw
        jnc  @f
        stosb
@@:    pop  ax
        ret

; ============================================================================
;  THE BOND'S KEYBOARD MEMORY. Physics runs in a BURST at the top of each
;  frame - up to MAXSTEP steps, one after another - and INPUT reads KEYS,
;  the state of the keys at that instant. At 60 frames a second that is the
;  same as watching the keys all the time. At one frame in two seconds it is
;  a photograph every two seconds: hold an arrow for a second between two
;  photographs and the aeroplane never knew. The pilot's word: "it barely
;  listens to the keys".
;
;  So the interrupt keeps the HISTORY: KMAKEF stamps the BIOS tick a key
;  went down, KBRKF adds the ticks it was held to kheld when it comes up.
;  KBURSTF, at the burst, turns that into a number of steps - the share of
;  the burst the key was really down, kheld * n / elapsed, at least one -
;  and KHOLDF/KRESTF hold the key down in KEYS for exactly those steps,
;  around each INPUT. Half a second of arrow in a two-second frame is half
;  the burst of turn. A key still held at the burst needs none of this:
;  KEYS already says 1, for every step.
;
;  Only the flight keys in KLIST are replayed - a key that opens a menu
;  or flips a switch acts on its KHIT latch and must not fire twice.
; ============================================================================
KLIST   db 48h,50h,4Bh,4Dh      ; the stick
        db 10h,12h,2Ch,02h,04h  ; rudder: Q E Z 1 3
        db 47h,49h              ;  ...and numpad 7 9
        db 11h,1Fh,4Eh,4Ah,0Dh,0Ch ; throttle: W S, numpad + -, main = -
        db 1Eh                  ; A, the burner
        db 39h                  ; Space, the cannon
        db 0FFh
kreal   db 128 dup(0)           ; the key's REAL state, as INT 9 saw it
kdown   dw 128 dup(0)           ; the tick it went down
kheld   dw 128 dup(0)           ; ticks held and let go since the last burst
kds     db 128 dup(0)           ; ...as steps of THIS burst
ktprev  dw 0                    ; the tick of the last burst
kforced dw 0                    ; steps a released key was held down for
kstep   db 0                    ; the step about to run

; BKTICK - AX = the BIOS tick (0040:006C, the low word)
BKTICK:  push es
        mov  ax,40h
        mov  es,ax
        mov  ax,[es:6Ch]
        pop  es
        ret

; KMAKEF / KBRKF - from INT 9, BX = the scan code (0..127). AX is the
; interrupt's own; everything is kept.
KMAKEF: cmp  byte [cs:kreal+bx],0
        jne  .r                 ; typematic repeat: still the same press
        push ax
        push bx
        mov  byte [cs:kreal+bx],1
        call BKTICK
        add  bx,bx
        mov  [cs:kdown+bx],ax
        pop  bx
        pop  ax
.r:    retf
KBRKF:  cmp  byte [cs:kreal+bx],0
        je   .r
        push ax
        push bx
        mov  byte [cs:kreal+bx],0
        call BKTICK
        add  bx,bx
        sub  ax,[cs:kdown+bx]
        inc  ax                 ; a tap inside one tick still counts as one
        add  [cs:kheld+bx],ax
        jnc  @f
        mov  word [cs:kheld+bx],0FFFFh
@@:    pop  bx
        pop  ax
.r:    retf

; KBURSTF - the burst is about to run AX steps. Each flight key's held
; ticks become steps of it - ceil(held * n / E), E the ticks the interval
; lasted, at least one for any press - and the next interval starts.
KBURSTF:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        mov  byte [cs:kstep],0
        mov  cx,ax              ; CX = n, the steps
        call BKTICK
        mov  dx,ax              ; DX = now
        sub  ax,[cs:ktprev]
        mov  [cs:ktprev],dx
        or   ax,ax
        jnz  @f
        inc  ax
@@:    mov  si,ax              ; SI = E
        xor  di,di
.l:    mov  bl,[cs:KLIST+di]
        cmp  bl,0FFh
        je   .d
        xor  bh,bh
        cmp  byte [cs:kreal+bx],0
        je   .up
        ; still down: KEYS says 1 for every step anyway. Its next
        ; interval counts from now, and anything banked is spent.
        mov  byte [cs:kds+bx],0
        push bx
        add  bx,bx
        mov  [cs:kdown+bx],dx
        mov  word [cs:kheld+bx],0
        pop  bx
        jmp  .nx
.up:   push bx
        add  bx,bx
        mov  ax,[cs:kheld+bx]
        mov  word [cs:kheld+bx],0
        pop  bx
        or   ax,ax
        jz   .z
        cmp  ax,si
        jbe  @f
        mov  ax,si              ; never more than the interval
@@:    push dx
        mul  cx                 ; held * n
        add  ax,si
        adc  dx,0
        sub  ax,1
        sbb  dx,0               ; + E - 1: round UP
        div  si                 ; E >= held >= 1, so the quotient is <= n
        pop  dx
        cmp  ax,cx
        jbe  @f
        mov  ax,cx
@@:    or   ax,ax
        jnz  @f
        inc  ax
@@:    mov  [cs:kds+bx],al
        jmp  .nx
.z:    mov  byte [cs:kds+bx],0
.nx:   inc  di
        jmp  .l
.d:    pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        retf

; KHOLDF - before a step: every flight key owed this step is down in KEYS
KHOLDF: push ax
        push bx
        push di
        xor  di,di
.l:    mov  bl,[cs:KLIST+di]
        cmp  bl,0FFh
        je   .d
        xor  bh,bh
        mov  al,[cs:kstep]
        cmp  [cs:kds+bx],al
        jbe  .nx
        cmp  byte [KEYS+bx],0   ; counted only when it CHANGED something:
        jne  .nx               ;  the profiler shows kforced (Ctrl+D, the
        inc  word [cs:kforced]  ;  last number on line two)
        mov  byte [KEYS+bx],1
.nx:   inc  di
        jmp  .l
.d:    inc  byte [cs:kstep]
        pop  di
        pop  bx
        pop  ax
        retf

; KRESTF - after a step: KEYS back to what the keyboard really says. The
; read and the write sit inside CLI, or an INT 9 between them would be
; overwritten with the state it had just changed.
KRESTF: push ax
        push bx
        push di
        xor  di,di
.l:    mov  bl,[cs:KLIST+di]
        cmp  bl,0FFh
        je   .d
        xor  bh,bh
        cli
        mov  al,[cs:kreal+bx]
        mov  [KEYS+bx],al
        sti
        inc  di
        jmp  .l
.d:    pop  di
        pop  bx
        pop  ax
        retf

VPK     = 200                   ; black
VPC     = 201                   ; frame ink
VPM     = 202                   ; accent ink
VPW     = 203                   ; white
macro VFILL x,y,w,h,c  { db 1
                         dw x
                         db y
                         dw w
                         db h,c }
macro VFRAME x,y,w,h,c { db 2
                         dw x
                         db y
                         dw w
                         db h,c }
macro VLINE x0,y0,x1,y1,c { db 3
                         dw x0
                         db y0
                         dw x1
                         db y1,c }
macro VBAR x0,y0,x1,y1,w,c { db 4
                         dw x0
                         db y0
                         dw x1
                         db y1,w,c }
macro VTEXT x,y,c,s    { db 5
                         dw x
                         db y,c,s,0 }
macro VPFULL { db 7 }           ; 7: the rest is for a FULL frame only
VPEVERY = 8                     ; one full frame in this many (a power of 2).
                                ;  4 at first; 8 since the window (2026-10-03):
                                ;  the screens and lamps refresh twice as
                                ;  rarely, a full frame costs half as much
VPG0    = 18                    ; the glass rows a partial frame converts:
VPG1    = 110                   ;  under the overhead bank, over the panel
vr0     dw 0                    ; the rows VBLITF converts this frame
vr1     dw 200
vc0     dw 0                    ; ...the first byte of each (4 px a byte)
vcx4    dw 0                    ; ...the same, in source pixels
vcn     dw 80                   ; ...and how many bytes
vpcnt   db 0                    ; frames, for VPEVERY
vpart   db 0                    ; this frame is PARTIAL (SKYGNDF decides)
vpran   db 0                    ; VPANELF drew this frame
vplast  db 0                    ; ...and the frame before
macro VSPAN x0,y0,x1,y1,xs,c { db 6
                         dw x0
                         db y0
                         dw x1
                         db y1
                         dw xs
                         db c }

; ---- THE FRONT PANEL -------------------------------------------------------
VPDL:
        ; ==== ONLY ON A FULL FRAME, ALL OF IT (VPFULL). A partial frame
        ; converts the small window alone, so nothing here would reach the
        ; screen - and the screens, lamps and words PANELBMP puts on the
        ; panel are skipped with it. The canopy bows and arch of the first
        ; cut are gone: the window IS the frame now (2026-10-03), the way
        ; the sims of the day split their screen.
        VPFULL
        ; ---- the cockpit walls round the window on the world
        VFILL 0,0,320,VPG0,VPK
        VFILL 0,VPG0,WINX0,VPG1-VPG0,VPK
        VFILL WINX1,VPG0,320-WINX1,VPG1-VPG0,VPK
        VFRAME WINX0-1,VPG0-1,WINX1-WINX0+2,VPG1-VPG0+2,VPW
        ; ---- the overhead bank: the plate, the burner slot, seven lenses
        VFILL 92,0,131,18,VPK
        VFRAME 92,0,131,18,VPC
        VFRAME 144,3,32,11,VPC
        VFRAME 96,8,7,6,VPC
        VFRAME 108,8,7,6,VPC
        VFRAME 119,8,7,6,VPC
        VFRAME 131,8,7,6,VPC
        VFRAME 183,8,7,6,VPC
        VFRAME 195,8,7,6,VPC
        VFRAME 208,8,7,6,VPC
        ; ---- the panel: a black slab, its top edge stepped at the corners
        VFILL 27,110,266,8,VPK
        VFILL 14,114,292,4,VPK
        VFILL 0,118,320,82,VPK
        VLINE 0,118,27,110,VPC
        VLINE 27,110,292,110,VPC
        VLINE 292,110,319,118,VPC
        ; ---- the two annunciator columns at the panel's ends
        VFRAME 11,126,22,54,VPC
        VFRAME 287,126,22,54,VPC
        ; ---- the three screens: a white bezel, a frame-ink lip
        ; Measured off the code that draws INTO them, not off the photo:
        ; the screens are PZRDR/PZADI/PZMAP (50..104, 131..185, 213..267),
        ; a lens is 4x3 at OSBX+4, rows OSBYT+OSBDY. The first cut put the
        ; lens columns ON the screens' lips - every rectangle overlapping
        ; its neighbour (the pilot, 2026-10-03). Now each has a pixel of air.
        VFRAME 40,121,74,61,VPW
        VFRAME 50,125,55,53,VPC
        VFRAME 120,124,79,59,VPW
        VFRAME 131,128,55,52,VPC
        VFRAME 202,121,76,61,VPW
        VFRAME 213,125,55,53,VPC
        ; ---- their button columns (OSBX/OSBYT in UI.INC light the lenses)
        VFRAME 44,130,6,42,VPC
        VFRAME 106,130,6,42,VPC
        VFRAME 125,132,6,42,VPC
        VFRAME 188,133,6,42,VPC
        VFRAME 207,130,6,42,VPC
        VFRAME 270,130,6,42,VPC
        ; ---- the strip over the centre screen
        VFRAME 128,113,63,9,VPC
        VLINE 141,113,141,121,VPC
        VLINE 154,113,154,121,VPC
        VLINE 167,113,167,121,VPC
        VLINE 180,113,180,121,VPC
        ; ---- the two keypads under the side screens. Their captions are
        ; drawn by UISEG over the frame; dividers here cut the words.
        VFRAME 40,184,74,12,VPC
        VFRAME 202,184,76,12,VPC
        ; ---- the two knobs on the coaming, accent ink
        VFRAME 35,115,7,7,VPM
        VFRAME 278,115,7,7,VPM
        ; ---- the legends over the digit row (PZDIG0..3)
        VTEXT 124,186,VPC,'SPD'
        VTEXT 141,186,VPC,'ALT'
        VTEXT 164,186,VPC,'HDG'
        VTEXT 182,186,VPC,'VS'
        db 0

; ---- F6, THE LEFT CONSOLE --------------------------------------------------
; The glass is the upper right; the canopy frame comes down the left edge
; and the sill runs from it, falling to the right.
VPSL:
        VFILL 0,0,320,5,VPK
        VSPAN 70,5,38,50,0,VPK
        VSPAN 38,50,48,82,0,VPK
        VSPAN 48,82,319,118,0,VPK
        VFILL 0,118,320,82,VPK
        VLINE 0,5,319,5,VPC
        VLINE 70,5,38,50,VPC
        VLINE 38,50,48,82,VPC
        VLINE 48,82,319,118,VPC
        VLINE 30,96,319,130,VPC
        ; the throttle quadrant: the lever across three gates
        VFRAME 18,104,48,82,VPC
        VTEXT 30,98,VPC,'THROT'
        VFILL 30,108,26,6,VPW
        VLINE 26,118,26,180,VPC
        VLINE 36,118,36,180,VPC
        VLINE 46,118,46,180,VPC
        VTEXT 54,124,VPC,'MAX'
        VTEXT 54,146,VPC,'MIL'
        VTEXT 50,164,VPC,'IDLE'
        ; the switch boxes
        VFRAME 76,110,34,23,VPC
        VTEXT 78,112,VPC,'FLAPS'
        VFILL 92,121,2,8,VPW
        VFRAME 76,135,34,23,VPC
        VTEXT 78,137,VPC,'BRAKE'
        VFILL 92,146,2,8,VPW
        VFRAME 76,160,34,24,VPC
        VTEXT 82,162,VPC,'PARK'
        VFILL 80,171,22,3,VPM
        VFRAME 113,116,28,40,VPC
        VTEXT 115,118,VPC,'LIGHT'
        VFILL 126,128,2,8,VPW
        VFILL 126,144,2,8,VPW
        VFRAME 113,158,28,26,VPC
        VTEXT 119,160,VPC,'BOMB'
        VFILL 126,170,2,8,VPW
        ; the landing gear handle, the one red thing on the console
        VFRAME 143,130,26,48,VPW
        VTEXT 148,132,VPC,'GEAR'
        VFILL 151,142,10,30,VPM
        ; a vent and the stick
        VFRAME 200,156,16,20,VPC
        VLINE 202,161,213,161,VPC
        VLINE 202,166,213,166,VPC
        VLINE 202,171,213,171,VPC
        VFRAME 276,148,14,34,VPC
        VFILL 278,141,10,7,VPM
        db 0

; ---- F7, THE RIGHT CONSOLE -------------------------------------------------
; The mirror of F6: the frame comes down the right edge and the sill
; falls to the left.
VPSR:
        VFILL 0,0,320,5,VPK
        VSPAN 255,5,285,50,319,VPK
        VSPAN 285,50,270,80,319,VPK
        VSPAN 270,80,0,118,319,VPK
        VFILL 0,118,320,82,VPK
        VLINE 0,5,319,5,VPC
        VLINE 255,5,285,50,VPC
        VLINE 285,50,270,80,VPC
        VLINE 270,80,0,118,VPC
        VLINE 290,94,0,130,VPC
        ; the oxygen flow on the frame
        VFRAME 292,70,22,16,VPC
        VTEXT 296,75,VPC,'O2'
        ; the weapons stack
        VFRAME 256,108,34,76,VPW
        VTEXT 262,111,VPC,'WPNS'
        VTEXT 260,124,VPC,'GUN'
        VFILL 280,124,5,5,VPM
        VTEXT 260,144,VPC,'MSL'
        VFILL 280,144,5,5,VPM
        VTEXT 260,164,VPC,'BMB'
        VFILL 280,164,5,5,VPM
        ; the switch boxes
        VFRAME 140,120,38,36,VPC
        VTEXT 148,123,VPC,'ARM'
        VFILL 154,135,10,10,VPM
        VFRAME 185,116,32,34,VPC
        VTEXT 194,119,VPC,'ECM'
        VFILL 200,131,2,8,VPW
        VFRAME 219,116,32,34,VPC
        VTEXT 228,119,VPC,'IFF'
        VFILL 234,131,2,8,VPW
        VFRAME 146,158,32,26,VPC
        VTEXT 154,160,VPC,'JETT'
        VFILL 158,170,8,8,VPM
        VFRAME 182,158,34,26,VPC
        VTEXT 184,160,VPC,'CHAFF'
        VFILL 198,170,2,8,VPW
        VFRAME 218,158,34,26,VPC
        VTEXT 220,160,VPC,'FLARE'
        VFILL 234,170,2,8,VPW
        ; a vent and the throttle hand's stick
        VFRAME 104,156,16,20,VPC
        VLINE 106,161,117,161,VPC
        VLINE 106,166,117,166,VPC
        VLINE 106,171,117,171,VPC
        VFRAME 30,148,14,34,VPC
        VFILL 32,141,10,7,VPM
        db 0

vpx     dw 0                    ; the record being drawn, unpacked
vpy     dw 0
vpw     dw 0
vph     dw 0
vpc     db 0
vpx1    dw 0
vpy1    dw 0
vpxs    dw 0                    ; SPAN: the far column

; Returns CF = 1 on a FULL frame: PANELBMP goes on to the screens and the
; lamps. CF = 0: a partial frame, the glass furniture only - PANELBMP stops.
VPANELF:
        push si
        mov  byte [cs:vpran],1
        mov  word [clipx0],0    ; the panel draws on the WHOLE screen: the
        mov  word [clipx1],319  ;  world's window clip ends here
        mov  word [clipy0],0
        mov  word [clipy1],199
        mov  si,VPDL
        call VPDRAW
        pop  si
        cmp  byte [cs:vpart],1  ; 0 - 1 borrows: CF = 1 on a full frame
        retf

; VPSIDEF - the side console F6 (sview 1) or F7 (sview 2) is looking at
VPSIDEF:
        push si
        mov  si,VPSL
        cmp  byte [sview],1
        je   @f
        mov  si,VPSR
@@:    call VPDRAW
        pop  si
        retf

; VPDRAW - walk the stroke list at cs:SI
VPDRAW: push ax
        push bx
        push cx
        push dx
        push si
        push di
        cld
.op:   mov  al,[cs:si]
        inc  si
        or   al,al
        jz   .done
        cmp  al,3
        je   .line
        cmp  al,4
        je   .bar
        cmp  al,5
        je   .text
        cmp  al,6
        je   .span
        cmp  al,7
        jne  .box
        cmp  byte [cs:vpart],0  ; VPFULL: a partial frame ends the list here
        jne  .done
        jmp  .op
.box:  push ax                 ; FILL and FRAME share a record
        call VPBOX
        pop  ax
        cmp  al,1
        je   .fill
        call VPFRM
        jmp  .op
.fill: call VPFIL
        jmp  .op
.line: mov  ax,[cs:si]
        mov  [sx0],ax
        mov  al,[cs:si+2]
        xor  ah,ah
        mov  [sy0],ax
        mov  ax,[cs:si+3]
        mov  [sx1],ax
        mov  al,[cs:si+5]
        xor  ah,ah
        mov  [sy1],ax
        mov  al,[cs:si+6]
        mov  [COLOR],al
        add  si,7
        push si
        call CODE:CLIPLINF
        jc   .ln
        call CODE:LINEF
.ln:   pop  si
        jmp  .op
.bar:  call VPEDGE              ; the edge, then the width and the ink
        mov  al,[cs:si]
        xor  ah,ah
        mov  [cs:vpw],ax
        mov  al,[cs:si+1]
        mov  [cs:vpc],al
        add  si,2
        call VPRUN
        jmp  .op
.span: call VPEDGE              ; the edge, then the far column and the ink
        mov  ax,[cs:si]
        mov  [cs:vpxs],ax
        mov  al,[cs:si+2]
        mov  [cs:vpc],al
        add  si,3
        mov  word [cs:vpw],0    ; width 0 means "across to vpxs"
        call VPRUN
        jmp  .op
.text: mov  ax,[cs:si]
        mov  [ftx],ax
        mov  al,[cs:si+2]
        xor  ah,ah
        mov  [fty],ax
        mov  al,[cs:si+3]
        mov  [COLOR],al
        add  si,4
        mov  di,NB              ; FDRAW reads DS:SI - the main segment -
.tc:   mov  al,[cs:si]         ;  so the word goes into NB first
        inc  si
        mov  [di],al
        inc  di
        or   al,al
        jnz  .tc
        push si
        mov  si,NB
        call CODE:FDRAWF
        pop  si
        jmp  .op
.done: pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; VPBOX - unpack a FILL/FRAME record at cs:SI, SI past it
VPBOX:  mov  ax,[cs:si]
        mov  [cs:vpx],ax
        mov  al,[cs:si+2]
        xor  ah,ah
        mov  [cs:vpy],ax
        mov  ax,[cs:si+3]
        mov  [cs:vpw],ax
        mov  al,[cs:si+5]
        xor  ah,ah
        mov  [cs:vph],ax
        mov  al,[cs:si+6]
        mov  [cs:vpc],al
        add  si,7
        ret

; VPEDGE - unpack the x0,y0,x1,y1 a BAR or a SPAN starts with
VPEDGE: mov  ax,[cs:si]
        mov  [cs:vpx],ax
        mov  al,[cs:si+2]
        xor  ah,ah
        mov  [cs:vpy],ax
        mov  ax,[cs:si+3]
        mov  [cs:vpx1],ax
        mov  al,[cs:si+5]
        xor  ah,ah
        mov  [cs:vpy1],ax
        add  si,6
        ret

; VPROW - DI = AX*320 + BX, for a row under 256
VPROW:  mov  ah,al
        xor  al,al              ; y*256
        mov  di,ax
        shr  ax,1
        shr  ax,1               ; y*64
        add  di,ax
        add  di,bx
        ret

; VPFIL - the box at vpx,vpy,vpw,vph in vpc
VPFIL:  mov  dx,[cs:vph]
        mov  ax,[cs:vpy]
.r:    push ax
        mov  bx,[cs:vpx]
        call VPROW
        mov  al,[cs:vpc]
        mov  cx,[cs:vpw]
        rep  stosb
        pop  ax
        inc  ax
        dec  dx
        jnz  .r
        ret

; VPFRM - the outline of the same box
VPFRM:  mov  ax,[cs:vpy]
        mov  bx,[cs:vpx]
        call VPROW
        mov  al,[cs:vpc]
        mov  cx,[cs:vpw]
        push di
        rep  stosb              ; the top edge
        pop  di
        mov  dx,[cs:vph]
        dec  dx
        mov  bx,[cs:vpw]
        dec  bx
.s:    add  di,320             ; the two sides, row by row...
        mov  [es:di],al
        mov  [es:di+bx],al
        dec  dx
        jnz  .s
        mov  cx,[cs:vpw]        ; ...and the bottom edge over the last one
        rep  stosb
        ret

; VPRUN - one run a row from vpy to vpy1, starting on the edge
;  x = x0 + (y-y0)*(x1-x0)/(y1-y0), worked out afresh each row with a
;  multiply and a divide: the edges reach x 319, past what an 8.8 word
;  holds, and these lists draw once a frame, not once a pixel.
;  vpw > 0: vpw pixels from the edge. vpw = 0: from the edge to vpxs,
;  whichever side of it the column lies.
VPRUN:  mov  ax,[cs:vpy]
.r:    cmp  ax,[cs:vpy1]
        ja   .d
        push ax
        sub  ax,[cs:vpy]        ; y-y0
        mov  cx,[cs:vpx1]
        sub  cx,[cs:vpx]
        imul cx                 ; *(x1-x0), in DX:AX
        mov  cx,[cs:vpy1]
        sub  cx,[cs:vpy]
        jz   .x0                ; one row: the edge is x0
        idiv cx
        jmp  .x1
.x0:   xor  ax,ax
.x1:   add  ax,[cs:vpx]        ; the edge's column on this row
        mov  bx,ax
        mov  cx,[cs:vpw]
        or   cx,cx
        jnz  .go               ; a bar: vpw from the edge
        mov  cx,[cs:vpxs]       ; a span: edge to vpxs, low end first
        cmp  cx,bx
        jae  .fw
        xchg cx,bx
.fw:   sub  cx,bx
        inc  cx
.go:   pop  ax
        push ax
        push cx
        call VPROW
        pop  cx
        mov  al,[cs:vpc]
        rep  stosb
        pop  ax
        inc  ax
        jmp  .r
.d:    ret

        include 'VIDLUT.INC'   ; the 256->4 tables, day and night, from
                                ; TOOLS\VidRig emit - regenerate after any
                                ; PALDAY/PALNITE change

label VIDEND byte
VIDFREE = 5FF0h - $             ; BOND: the report the other windows print
if VIDFREE < 256
        display "VIDSEG free: under 256",13,10
else if VIDFREE < 1024
        display "VIDSEG free: 256..1023",13,10
else if VIDFREE < 4096
        display "VIDSEG free: 1024..4095",13,10
else
        display "VIDSEG free: 4096 or more",13,10
end if
        rb 5FF0h - $   ; claim the whole window - TWENTY-FOUR K since the
                        ; second CGA palette's banks (each growth moved
                        ; bufseg and resseg up 200h; the note beside
                        ; resseg keeps the count. CITY.DAT now ends 79
                        ; paragraphs short of sndseg's guaranteed floor -
                        ; the NEXT growth must take a page ABOVE instead)
