; ==================================================================
;  MENU.INC - the first screen: text mode, so it shows on every card -
;  which picture, the sound, your name.  1 2 3 pick the card (one this
;  machine has not got refuses the key), 4 the sound on and off,
;  letters your name, Enter plays, Esc back to DOS.  By default the
;  best card here (EGA, "for authenticity") and the sound on, if a
;  Sound Blaster answered.  Through the BIOS (INT 10h 09h), so a
;  Hercules' or an MDA's mono text is as good as a colour one.
; ==================================================================
MENU:   mov  ah,0Fh
        int  10h                ; the mode DOS lent us
        mov  [origmode],al
        mov  ax,0003h
        cmp  byte [origmode],7
        jne  .set
        mov  byte [mono],1      ; a monochrome screen: mode 7, mono colours
        mov  ax,0007h
.set:   int  10h                ; text, cleared
        mov  ah,01h
        mov  cx,2000h           ; no cursor
        int  10h
        mov  al,[sbok]
        mov  [sndwant],al       ; the sound on, if there is a Blaster
.draw:  call MDRAW
.key:   mov  ah,0
        int  16h                ; AL = the character
        cmp  al,27
        jne  .ent
        jmp  QUIT
.ent:   cmp  al,13
        je   .go
        cmp  al,8
        je   .bs
        cmp  al,'1'
        jb   .name
        cmp  al,'4'
        ja   .name
        je   .snd
        sub  al,'0'             ; 1 2 3: CARD_EGA, CARD_CGA, CARD_HGC
        mov  bl,al
        xor  bh,bh
        cmp  byte [capega-1+bx],0
        je   .key               ; not on this machine
        mov  [card],al
        jmp  .draw
.snd:   cmp  byte [sbok],0
        je   .key               ; no Blaster: the sound stays off
        xor  byte [sndwant],1
        jmp  .draw
.bs:    mov  bl,[mylen]
        or   bl,bl
        jz   .key
        dec  bl                 ; Backspace: the last letter off
        mov  [mylen],bl
        xor  bh,bh
        mov  byte [myname+bx],0
        jmp  .draw
.name:  call NAMECH
        jmp  .draw
.go:    cmp  byte [mylen],0
        jne  .ok
        mov  si,TPLAYER         ; nothing typed: PLAYER
        mov  di,myname
        mov  cx,8
        rep  movsb
        mov  byte [mylen],6
.ok:    ret

; NAMECH - character AL into your name: letters (as capitals), digits,
; '-', eight at most; anything else is not a name's
NAMECH: cmp  al,'a'
        jb   .up
        cmp  al,'z'
        ja   .no
        sub  al,20h             ; a..z -> A..Z: 20h apart in ASCII
.up:    cmp  al,'-'
        je   .ok
        cmp  al,'0'
        jb   .no
        cmp  al,'9'
        jbe  .ok
        cmp  al,'A'
        jb   .no
        cmp  al,'Z'
        ja   .no
.ok:    mov  bl,[mylen]
        cmp  bl,8
        jae  .no                ; eight already
        xor  bh,bh
        mov  [myname+bx],al
        inc  byte [mylen]
.no:    ret

; MDRAW - the whole menu, every line, as it stands now
MDRAW:  mov  ax,0600h           ; the screen cleared...
        mov  bh,[MA_TEXT]
        xor  cx,cx
        mov  dx,184Fh
        int  10h
        mov  al,MA_BOX-MATTR    ; ...a double frame round it
        call MATT
        mov  dx,0208h
        mov  al,0C9h
        call MPUTC
        mov  cx,62
.top:   mov  al,0CDh
        call MPUTC
        loop .top
        mov  al,0BBh
        call MPUTC
        mov  dx,0308h
.side:  mov  al,0BAh
        call MPUTC
        add  dl,62
        mov  al,0BAh
        call MPUTC
        sub  dl,64
        inc  dh
        cmp  dh,22
        jb   .side
        mov  dl,8
        mov  al,0C8h
        call MPUTC
        mov  cx,62
.bot:   mov  al,0CDh
        call MPUTC
        loop .bot
        mov  al,0BCh
        call MPUTC
        mov  si,MLINES          ; the fixed lines
.fix:   lodsb
        cmp  al,0FFh
        je   .cards
        mov  dh,al
        lodsb
        mov  dl,al
        lodsb
        call MATT
        call MPUTS
        jmp  .fix
.cards: mov  dh,9               ; the three cards, a line each
        mov  byte [mcard],CARD_EGA
        mov  si,MEGA
.card:  mov  dl,14
        mov  al,MA_KEY-MATTR
        call MATT
        mov  al,[mcard]
        add  al,'0'
        call MPUTC              ; its key
        mov  al,' '
        call MPUTC
        call MPUTC
        mov  bl,[mcard]
        xor  bh,bh
        mov  al,MA_ON-MATTR
        cmp  byte [capega-1+bx],0
        jne  .has
        mov  al,MA_OFF-MATTR    ; not on this machine: grey
.has:   call MATT
        push si
        mov  si,MRADIO0
        mov  al,[mcard]
        cmp  al,[card]
        jne  .rad
        mov  si,MRADIO1
.rad:   call MPUTS              ; ( ) or (*)
        pop  si
        call MPUTS              ; its name and what it shows (SI: the next's)
        push si
        mov  al,[mcard]
        xor  ah,ah
        mov  di,ax
        cmp  byte [capega-1+di],0
        jne  .nx
        mov  si,MNOTHERE
        call MPUTS
.nx:    pop  si
        inc  dh
        inc  byte [mcard]
        cmp  byte [mcard],CARD_HGC
        jbe  .card
        mov  dx,0E0Eh           ; the sound
        mov  al,MA_KEY-MATTR
        call MATT
        mov  al,'4'
        call MPUTC
        mov  al,' '
        call MPUTC
        mov  al,' '
        call MPUTC
        mov  al,MA_ON-MATTR
        cmp  byte [sbok],0
        jne  .sb
        mov  al,MA_OFF-MATTR
.sb:    call MATT
        mov  si,MCHECK0
        cmp  byte [sndwant],0
        je   .ck
        mov  si,MCHECK1
.ck:    call MPUTS
        mov  si,MSOUND
        cmp  byte [sbok],0
        jne  .sn
        mov  si,MNOSB
.sn:    call MPUTS
        mov  dx,1110h           ; the name, a cursor after it
        mov  al,MA_HEAD-MATTR
        call MATT
        mov  si,MNAME
        call MPUTS
        mov  al,MA_ON-MATTR
        call MATT
        mov  si,myname
        call MPUTS
        mov  al,MA_KEY-MATTR
        call MATT
        mov  al,'_'
        call MPUTC
        mov  dx,141Ch           ; PRESS ENTER, blinking
        mov  al,MA_ENTER-MATTR
        call MATT
        mov  si,MENTER
        call MPUTS
        mov  dx,1900h           ; the cursor off the screen
        mov  ah,02h
        xor  bh,bh
        int  10h
        ret

; MATT - BL = attribute number AL, for a colour or a mono screen
MATT:   push si
        xor  ah,ah
        mov  si,ax
        mov  bl,[MATTR+si]
        cmp  byte [mono],0
        je   .c
        mov  bl,[MMONO+si]
.c:     pop  si
        ret

; MPUTC - character AL at row DH, column DL, attribute BL; DL on one
MPUTC:  push ax
        push bx
        push cx
        mov  ah,02h
        xor  bh,bh
        int  10h                ; the cursor there
        pop  cx
        pop  bx
        pop  ax
        push ax
        push bx
        push cx
        mov  ah,09h
        xor  bh,bh
        mov  cx,1
        int  10h                ; the character, with its attribute
        pop  cx
        pop  bx
        pop  ax
        inc  dl
        ret

; MPUTS - the zero-ended string at SI, from DH, DL, in BL; SI past it
MPUTS:  lodsb
        or   al,al
        jz   .e
        call MPUTC
        jmp  MPUTS
.e:     ret

; the attributes: colour screen, then mono screen
MATTR:
MA_TEXT db 07h
MA_BOX  db 09h                  ; light blue frame
MA_TIT  db 0Eh                  ; yellow title
MA_HEAD db 0Bh                  ; light cyan headings
MA_KEY  db 0Eh                  ; the keys, yellow
MA_ON   db 0Fh                  ; what can be chosen, white
MA_OFF  db 08h                  ; what cannot, dark grey
MA_ENTER db 8Ah                 ; light green, blinking
MA_DIM  db 03h
MMONO   db 07h,07h,0Fh,0Fh,0Fh,0Fh,07h,8Fh,07h
; db row, column, attribute number, 'text', 0 ... 0FFh
MLINES  db 4,23,MA_TIT-MATTR,'M U L T I P L A Y   S O K O   I I',0
        db 5,13,MA_TEXT-MATTR,'crates onto the red marks, up to eight in one castle',0
        db 7,14,MA_HEAD-MATTR,'THE PICTURE',0
        db 13,14,MA_HEAD-MATTR,'THE SOUND',0
        db 21,10,MA_DIM-MATTR,'1 2 3 the card   4 the sound   letters: your name   Esc: DOS',0
        db 0FFh
MEGA    db 'EGA        320 x 200, sixteen colours',0
MCGA    db 'CGA        320 x 200, four colours',0
MHGC    db 'HERCULES   720 x 348, black and amber',0
MNOTHERE db '  - not here',0
MRADIO0 db '( ) ',0
MRADIO1 db '(*) ',0
MCHECK0 db '[ ] ',0
MCHECK1 db '[x] ',0
MSOUND  db 'SOUND      Sound Blaster at 220h: wind, birds',0
MNOSB   db 'SOUND      no Sound Blaster answers at 220h',0
MNAME   db 'YOUR NAME  ',0
MENTER  db 'PRESS  ENTER',0
