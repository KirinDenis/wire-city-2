; ============================================================================
;  K_MENU.INC - KIT: text-mode screens before the game - pick a card, a
;  level, the sound; type a name. Text mode shows on EVERY card (colour or
;  mono), so the setup screen works before anything is known. Read through
;  INT 16h: call these BEFORE the game hooks INT 9 (its handler silences
;  the BIOS keyboard), and nothing here touches a graphics mode.
;
;        mov  si,MYMENU
;        mov  al,0               ; the chevron on the first offered item
;        call MNU_SHOW           ; AL = 1..n, 0 = Esc
;  MYMENU  db 'MY GAME - THE PICTURE',0     ; the title
;          db 1,'EGA        320 x 200, 16 COLOURS',0
;          db 0,'HERCULES   720 x 348, MONO',0   ; 0: greyed, key refused
;          db 0FFh
;  Patch an item's flag byte at run time from what the machine has (for
;  instance from K_CARD's crd_cap). A mono machine (mode 7) gets mono
;  attributes by itself.
; ============================================================================

if used mnu_mono
mnu_mono  db 0                  ; 1: a mono screen (mode 7)
mnu_n     db 0                  ; MNU_SHOW: items
mnu_sel   db 0                  ;  the chevron's item, 1..n (0: none)
mnu_at    dw 0                  ; MNU_NAME: where the name begins
mnu_item  dw 9 dup 0            ;  each item's text
mnu_ok    db 9 dup 0            ;  each item's flag: 1 offered
; attributes, by number: colour screen, then mono screen
mnu_attr  db 07h,0Eh,0Fh,08h,0Eh,03h   ; text, title, offered, greyed,
mnu_amono db 07h,0Fh,0Fh,07h,0Fh,07h   ;  chevron/keys, the help line
end if
MNU_A_TEXT  = 0
MNU_A_TITLE = 1
MNU_A_ON    = 2
MNU_A_OFF   = 3
MNU_A_KEY   = 4
MNU_A_HELP  = 5

; ----------------------------------------------------------------------
;@ MNU_SHOW   a numbered text menu: digits, arrows + Enter pick, Esc -> 0
;  in:  SI = the menu: a zero-ended title, then up to 9 items, each
;       db flag (1 offered, 0 greyed), 'text', 0; then db 0FFh.
;       AL = the item the chevron starts on (1..n; 0 or a greyed one: the
;       first offered)
;  out: AX = the item taken, 1..n; 0 = Esc. The text screen stays as drawn
;       (the cursor shape restored)
;  needs: text mode or not - it sets mode 3 (7 on a mono machine) itself.
;       Uses INT 16h: before any INT 9 hook.
;  from: GAMES\OWLFLY3\SRC\VID.INC:99-262,384-424 VMENUF, VMMOVE, VMMARK
;        (numbered rows, greyed absent items, the chevron); attributes and
;        INT 10h 09h output from GAMES\MULTSOK2\MENU.INC:94-272 (proven)
; ----------------------------------------------------------------------
if used MNU_SHOW
MNU_SHOW:
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        push es
        push ax                 ; the wanted start
        call MNU_SCREEN         ; text mode, cleared, mono or not
        mov  dx,0102h           ; the title: row 1, column 2
        mov  al,MNU_A_TITLE
        call MNU_PUTS           ; SI past the title
        xor  bx,bx              ; BX = items so far
.item:  mov  al,[si]
        cmp  al,0FFh
        je   .ends
        cmp  bx,9
        jae  .ends              ; nine at most: digits 1..9
        inc  si
        mov  [mnu_ok+bx],al     ; its flag
        shl  bx,1
        mov  [mnu_item+bx],si   ; its text
        shr  bx,1
        inc  bx                 ; one more item
.skip:  lodsb                   ; past its text
        or   al,al
        jnz  .skip
        jmp  .item
.ends:  mov  [mnu_n],bl
        mov  bp,1               ; draw them: item n on row n+2
.draw:  cmp  bp,bx
        ja   .drawn
        mov  dx,bp
        mov  dh,dl
        add  dh,2               ; row n+2
        mov  dl,4               ; column 4
        mov  ax,bp
        add  al,'0'             ; its digit
        mov  ah,MNU_A_KEY
        call MNU_PUTC
        mov  al,')'
        call MNU_PUTC
        mov  al,' '
        call MNU_PUTC
        mov  di,bp
        mov  al,MNU_A_ON
        cmp  byte [mnu_ok-1+di],0
        jne  .on
        mov  al,MNU_A_OFF       ; not offered: grey
.on:    shl  di,1
        mov  si,[mnu_item-2+di]
        push ax
        call MNU_PUTS
        pop  ax
        cmp  al,MNU_A_OFF
        jne  .nx
        mov  si,.none
        call MNU_PUTS           ; and says so
.nx:    inc  bp                 ; the next item
        jmp  .draw
.drawn: mov  dh,bl
        add  dh,4               ; under the items, a line between
        mov  dl,2
        mov  si,.help
        mov  al,MNU_A_HELP
        call MNU_PUTS
        mov  al,bl
        add  al,'0'             ; "1..n"
        mov  ah,MNU_A_HELP
        call MNU_PUTC
        mov  si,.help2
        mov  al,MNU_A_HELP
        call MNU_PUTS
        pop  ax                 ; the wanted start
        mov  [mnu_sel],al
        call .valid
        jnc  .mark
        mov  byte [mnu_sel],0   ; not offered: the first offered one
        call .down
.mark:  call .chev
.key:   xor  ah,ah
        int  16h                ; BIOS keyboard: AL ascii, AH scan
        cmp  al,27
        je   .esc
        cmp  al,13
        je   .enter
        cmp  al,'1'
        jb   .ext
        cmp  al,'9'
        ja   .ext
        sub  al,'0'             ; a digit: that item
        mov  ah,[mnu_sel]
        mov  [mnu_sel],al
        call .valid
        jc   .back              ; not there or greyed: the key refused
        mov  al,ah
        call .unchev            ; the old chevron off
        call .chev              ; the new one on, so the eye sees it
        jmp  .take
.back:  mov  [mnu_sel],ah
        jmp  .key
.ext:   or   al,al              ; an extended key: AL 0, or E0h from an
        jz   .e1                ;  enhanced BIOS; the scan code in AH
        cmp  al,0E0h
        jne  .key
.e1:    mov  al,[mnu_sel]
        cmp  ah,48h             ; up
        je   .mvup
        cmp  ah,50h             ; down
        jne  .key
        call .down
        jmp  .moved
.mvup:  call .up
.moved: call .unchev            ; AL = the old item
        call .chev
        jmp  .key
.enter: cmp  byte [mnu_sel],0
        je   .key               ; nothing offered: Enter means nothing
.take:  mov  al,[mnu_sel]
        jmp  .out
.esc:   xor  al,al
.out:   xor  ah,ah              ; AX = the item
        push ax
        mov  ah,01h
        mov  cx,0607h           ; the cursor's shape back (colour)
        cmp  byte [mnu_mono],0
        je   .cur
        mov  cx,0B0Ch           ;  (mono)
.cur:   int  10h
        mov  dx,1800h           ; the cursor on the last row
        mov  ah,02h
        xor  bh,bh
        int  10h
        pop  ax
        pop  es
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        ret
; .valid - CF = 0 if item [mnu_sel] is there and offered
.valid: push bx
        mov  bl,[mnu_sel]
        xor  bh,bh
        or   bl,bl
        jz   .inv
        cmp  bl,[mnu_n]
        ja   .inv
        cmp  byte [mnu_ok-1+bx],0
        je   .inv
        pop  bx
        clc
        ret
.inv:   pop  bx
        stc
        ret
; .down / .up - the chevron to the next / previous offered item (stays
; if there is none)
.down:  push ax
        mov  al,[mnu_sel]
.d1:    inc  byte [mnu_sel]
        mov  ah,[mnu_sel]
        cmp  ah,[mnu_n]
        ja   .stay
        call .valid
        jc   .d1
        pop  ax
        ret
.up:    push ax
        mov  al,[mnu_sel]
.u1:    dec  byte [mnu_sel]
        jz   .stay
        call .valid
        jc   .u1
        pop  ax
        ret
.stay:  mov  [mnu_sel],al       ; none that way: where it was
        pop  ax
        ret
; .chev - the chevron at item [mnu_sel]; .unchev - off item AL
.chev:  push ax
        mov  al,[mnu_sel]
        or   al,al
        jz   .cx
        mov  dh,al
        add  dh,2               ; item n on row n+2
        mov  dl,2
        mov  al,'>'
        mov  ah,MNU_A_KEY
        call MNU_PUTC
.cx:    pop  ax
        ret
.unchev:push ax
        or   al,al
        jz   .ux
        mov  dh,al
        add  dh,2
        mov  dl,2
        mov  al,' '
        mov  ah,MNU_A_TEXT
        call MNU_PUTC
.ux:    pop  ax
        ret
.none   db '  - NOT IN THIS MACHINE',0
.help   db 'PRESS 1..',0
.help2  db ', OR ARROWS AND ENTER.  ESC QUITS.',0
end if

; ----------------------------------------------------------------------
;@ MNU_NAME   type a name of up to 8 letters at row DH, column DL
;  in:  DH, DL = where; SI = a zero-ended prompt shown first; DI = the name:
;       9 bytes, zero-ended (what is in it is shown and edited)
;  out: AX = 13 Enter, 27 Esc; CX = the name's length. Letters become
;       capitals; digits and '-' are kept; anything else is refused;
;       Backspace takes the last one off
;  needs: a text screen (MNU_SHOW's, or MNU_SCREEN); INT 16h: before INT 9
;  from: GAMES\MULTSOK2\MENU.INC:10-92 MENU (.bs, .name) and NAMECH
; ----------------------------------------------------------------------
if used MNU_NAME
MNU_NAME:
        push bx
        push dx
        push si
        push ax
        mov  ah,0Fh
        int  10h                ; the mode now: 7 = mono attributes
        mov  byte [mnu_mono],0
        cmp  al,7
        jne  .c
        mov  byte [mnu_mono],1
.c:     pop  ax
        mov  al,MNU_A_TITLE
        call MNU_PUTS           ; the prompt
        mov  [mnu_at],dx        ; where the name begins
        xor  cx,cx              ; its length
.len:   mov  bx,cx
        cmp  byte [di+bx],0
        je   .shown
        inc  cx
        cmp  cx,8
        jb   .len
        mov  byte [di+8],0      ; eight at most
.shown: mov  [di+8],ch          ; (CH = 0: the ninth byte is the end)
.draw:  mov  dx,[mnu_at]
        mov  si,di
        mov  al,MNU_A_ON
        call MNU_PUTS           ; the name...
        mov  al,'_'
        mov  ah,MNU_A_KEY
        call MNU_PUTC           ; ...a cursor after it...
        mov  al,' '
        mov  ah,MNU_A_TEXT
        call MNU_PUTC           ; ...and the place a Backspace left
.key:   xor  ah,ah
        int  16h                ; AL = the character
        cmp  al,13
        je   .out
        cmp  al,27
        je   .out
        cmp  al,8
        je   .bs
        cmp  al,'a'
        jb   .up
        cmp  al,'z'
        ja   .key
        sub  al,20h             ; a..z -> A..Z: 20h apart in ASCII
.up:    cmp  al,'-'
        je   .ok
        cmp  al,'0'
        jb   .key
        cmp  al,'9'
        jbe  .ok
        cmp  al,'A'
        jb   .key
        cmp  al,'Z'
        ja   .key
.ok:    cmp  cx,8
        jae  .key               ; eight already
        mov  bx,cx
        mov  [di+bx],al
        mov  byte [di+bx+1],0
        inc  cx                 ; one letter more
        jmp  .draw
.bs:    jcxz .key               ; nothing to take off
        dec  cx                 ; the last letter off
        mov  bx,cx
        mov  byte [di+bx],0
        jmp  .draw
.out:   xor  ah,ah              ; AX = the key that ended it
        pop  si
        pop  dx
        pop  bx
        ret
end if

; ----------------------------------------------------------------------
;@ MNU_SCREEN a clean text screen: mode 3 (7 on a mono machine), no cursor
;  in:  -
;  out: - ([mnu_mono] = 1 on a mono machine)
;  needs: -
;  from: GAMES\MULTSOK2\MENU.INC:10-21 (proven there)
; ----------------------------------------------------------------------
if used MNU_SCREEN
MNU_SCREEN:
        push ax
        push bx
        push cx
        push dx
        mov  ah,0Fh
        int  10h                ; the mode DOS lent us
        mov  byte [mnu_mono],0
        mov  ah,0
        cmp  al,7
        mov  al,3               ; colour: 80x25 text, cleared
        jne  .set
        mov  byte [mnu_mono],1  ; a monochrome screen: mode 7, mono colours
        mov  al,7
.set:   int  10h
        mov  ah,01h
        mov  cx,2000h           ; no cursor
        int  10h
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ MNU_PUTC   character AL with attribute number AH at row DH, column DL
;  in:  AL, AH = MNU_A_TEXT/TITLE/ON/OFF/KEY/HELP, DH, DL
;  out: DL one on (the next column)
;  needs: a text screen; [mnu_mono] (MNU_SCREEN) picks the mono attributes
;  from: GAMES\MULTSOK2\MENU.INC:232-264 MATT, MPUTC (proven there)
; ----------------------------------------------------------------------
if used MNU_PUTC
MNU_PUTC:
        push ax
        push bx
        push cx
        push si
        push ax
        mov  ah,02h
        xor  bh,bh
        int  10h                ; the cursor there
        pop  ax
        mov  bl,ah
        xor  bh,bh
        mov  si,bx
        mov  bl,[mnu_attr+si]
        cmp  byte [mnu_mono],0
        je   .c
        mov  bl,[mnu_amono+si]
.c:     mov  ah,09h
        xor  bh,bh
        mov  cx,1
        int  10h                ; the character, with its attribute
        inc  dl                 ; the next column
        pop  si
        pop  cx
        pop  bx
        pop  ax
        ret
end if

; ----------------------------------------------------------------------
;@ MNU_PUTS   the zero-ended string SI with attribute number AL at DH, DL
;  in:  SI, AL = attribute number (as MNU_PUTC), DH, DL
;  out: SI past the zero; DL past the string
;  needs: as MNU_PUTC
;  from: GAMES\MULTSOK2\MENU.INC:266-272 MPUTS (proven there)
; ----------------------------------------------------------------------
if used MNU_PUTS
MNU_PUTS:
        push ax
        mov  ah,al              ; AH = the attribute number
.c:     lodsb
        or   al,al
        jz   .e
        call MNU_PUTC
        jmp  .c
.e:     pop  ax
        ret
end if
