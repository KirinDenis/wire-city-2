; ============================================================================
;  T_GRID.ASM - KIT template: a turn-based tile game (crates onto the red
;  marks) on EVERY card: EGA 640, EGA, CGA, Hercules, or VGA/MCGA mode 13h -
;  one 4-bits-a-pixel back buffer, sent to the card by K_CARD.
;      cd KIT  then  MAKE T_GRID T_GRID      (or KIT\MAKEWIN T_GRID T_GRID)
;      T_GRID          a text menu picks the card (the best one marked)
;      T_GRID /AUTO    plays a scripted solution, holds 2 s, quits, PASS
;      T_GRID /AUTO 3  the same on card 3 (1 EGA 640, 2 EGA, 3 CGA,
;                      4 Hercules, 5 VGA 13h - one this machine has)
;  ARROWS walk and push the crate in front of you, R the level anew,
;  ESC back to DOS.
;  To grow it: LEVEL (the map: # wall, space floor, . goal, $ crate,
;  * crate on a goal, @ you), the tiles (16x16 text art, KIT\ART's colours),
;  MOVE (the rules), DRAW (the picture). Everything is redrawn after a
;  move; CRD_BLIT sends only what changed to the card.
;  Blocks: K_CARD (cards), K_D4 (drawing), K_MENU (the menu), K_FONT +
;  REC\R_TITLE (the letters). The grid logic is a minimal copy here
;  (KIT\LIB\K_GRID.INC has the full one).
;  LETTERS: FNT_OND4 after D4_INIT sends K_FONT into the 4bpp frame - every
;  font, scale, ring and look then works on EGA, CGA and Hercules too
;  (colours 0..15; the gold and fire ramps turn into their 16-colour
;  twins). TITLE is R_TITLE's TTLCARD over the level with a CRD_BLIT loop
;  (TTLRUN is mode 13h's); the HUD is FNT_HUD + FNT_LSCORE, SOLVED FNT_LFIRE.
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

GW      = 10                    ; the level: columns
GH      = 7                     ;  and rows
TILE    = 16                    ; a cell's pixels
ORGX    = 80                    ; the grid's top left on the screen
ORGY    = 40                    ;  (x in the game's 320 columns, even)
STEPT   = 4                     ; /AUTO: ticks between scripted moves
HOLDT   = 36                    ; /AUTO: ticks the solved picture stays: 2 s

start:  cld
        call GETARGS            ; [auto], [want] (the card asked for)
        call CRD_DETECT         ; what this machine shows
        cmp  byte [crd_card],0
        jne  .card
        mov  dx,mnocard         ; none of the five: say so, leave
        jmp  FAIL
.card:  cmp  byte [auto],0
        je   .menu
        mov  bl,[want]          ; /AUTO N: that card, if it is here
        or   bl,bl
        jz   .go
        xor  bh,bh
        cmp  byte [crd_cap-1+bx],0
        je   .notit
        mov  [crd_card],bl
        jmp  .go
.notit: mov  byte [refused],1   ; not here: the best one instead
        jmp  .go
.menu:  mov  si,MCARDS          ; the menu: what is not here is greyed
        mov  di,MCARDS
.skip0: lodsb                   ; past the title
        or   al,al
        jnz  .skip0
        xor  bx,bx              ; card 1..5 = item 1..5
.flag:  mov  al,[crd_cap+bx]
        mov  [si],al            ; the item's flag byte
        inc  si
.skip1: lodsb                   ; past its text
        or   al,al
        jnz  .skip1
        inc  bx                 ; the next card
        cmp  bx,CRD_N
        jb   .flag
        mov  si,MCARDS
        mov  al,[crd_card]      ; the chevron on the best
        call MNU_SHOW
        or   al,al
        jnz  .took
        jmp  BYE                ; Esc in the menu: straight back to DOS
.took:  mov  [crd_card],al
.go:    call CRD_MEM            ; the frame (and the copy) from DOS
        jnc  .mem
        mov  dx,mnomem
        jmp  FAIL
.mem:   mov  ax,[crd_buf]
        mov  bl,[crd_wide]
        call D4_INIT            ; drawing into it
        call FNT_OND4           ; K_FONT's letters into it too (16 colours)
        call TILES              ; the pictures compiled for this card
        call CRD_SET            ; the mode up
        jnc  .set
        mov  dx,mnocard
        jmp  FAIL
.set:   call LOADLV
        call TITLE              ; the title card until Enter (Esc: DOS)
        jc   QUIT
        call DRAW
        call CRD_BLIT

MAIN:   cmp  byte [auto],0
        jne  .auto
        xor  ah,ah
        int  16h                ; a person: wait for a key
        jmp  .key
.auto:  mov  ah,1
        int  16h                ; a key pressed under /AUTO? Esc still quits
        jz   .script
        xor  ah,ah
        int  16h
        cmp  al,27
        je   QUIT
.script:mov  cx,STEPT
        call WAITT
        mov  bx,[spos]
        mov  ah,[SCRIPT+bx]     ; the next scripted arrow
        mov  al,0               ;  (no character with it)
        or   ah,ah
        jz   .done
        inc  word [spos]
        jmp  .key
.done:  mov  cx,HOLDT           ; the script is over: let it be seen
        call WAITT
        jmp  QUIT
.key:   cmp  al,27
        je   QUIT
        and  al,0DFh            ; r -> R
        cmp  al,'R'
        jne  .arrow
        call LOADLV             ; the level anew
        jmp  .show
.arrow: mov  dx,0FF00h          ; DL = dx, DH = dy: up
        cmp  ah,48h
        je   .move
        mov  dx,0100h           ; down
        cmp  ah,50h
        je   .move
        mov  dx,00FFh           ; left
        cmp  ah,4Bh
        je   .move
        mov  dx,0001h           ; right
        cmp  ah,4Dh
        jne  MAIN
.move:  cmp  byte [won],0
        jne  MAIN               ; solved: only R or Esc now
        call MOVE
.show:  call DRAW
        call CRD_BLIT
        jmp  MAIN

QUIT:   call CRD_RESET          ; text mode back (DOS's own: 3, or 7 mono)
        cmp  byte [auto],0
        je   BYE
        call REPORT             ; /AUTO: the PASS lines
BYE:    mov  ax,4C00h
        int  21h

; FAIL - DX -> a '$' message, before any mode was changed
FAIL:   mov  ah,9
        int  21h
        mov  ax,4C01h
        int  21h

; ----------------------------------------------------------------------------
; LOADLV - LEVEL into the grid; you out of it into [px], [py]
LOADLV: mov  si,LEVEL
        mov  di,grid
        xor  bx,bx              ; BX = the cell
.c:     lodsb
        cmp  al,'@'
        je   .you
        cmp  al,'+'             ; you on a goal
        jne  .put
        mov  al,'.'
        jmp  .at
.you:   mov  al,' '
.at:    push ax
        mov  ax,bx
        mov  cl,GW
        div  cl                 ; AL = row, AH = column (CL = GW, not 0)
        mov  [py],al
        mov  [px],ah
        pop  ax
.put:   stosb
        inc  bx                 ; the next cell
        cmp  bx,GW*GH
        jb   .c
        mov  word [moves],0
        mov  byte [won],0
        ret

; CELL - BX = the cell offset of column AL, row AH (keeps the rest)
CELL:   push ax
        push cx
        mov  cl,ah
        xor  ch,ch
        mov  bx,cx
        shl  bx,1               ; row*2
        shl  cx,1
        shl  cx,1
        shl  cx,1               ; row*8
        add  bx,cx              ; row*10 = row*8 + row*2
        xor  ah,ah
        add  bx,ax              ; + the column
        pop  cx
        pop  ax
        ret

; MOVE - one step DL (dx -1/0/1), DH (dy): a wall stops you; a crate moves
; if what is behind it is free. The grid's edge is all wall.
MOVE:   mov  al,[px]
        add  al,dl              ; the cell in front
        mov  ah,[py]
        add  ah,dh
        call CELL
        mov  cl,[grid+bx]
        cmp  cl,'#'
        je   .no
        cmp  cl,'$'
        je   .push
        cmp  cl,'*'
        jne  .walk
.push:  push bx                 ; the crate's cell
        add  al,dl              ; the cell behind it
        add  ah,dh
        mov  si,bx
        call CELL
        mov  ch,[grid+bx]
        cmp  ch,' '
        je   .free
        cmp  ch,'.'
        je   .free
        pop  bx                 ; a wall or a crate behind: no
        ret
.free:  mov  byte [grid+bx],'$'
        cmp  ch,'.'
        jne  .left
        mov  byte [grid+bx],'*' ; onto a goal
.left:  pop  bx
        mov  byte [grid+bx],' '
        cmp  cl,'*'
        jne  .walk
        mov  byte [grid+bx],'.' ; off a goal: the mark shows again
.walk:  add  [px],dl            ; you step
        add  [py],dh
        inc  word [moves]       ; one move more
        mov  si,grid            ; solved: no crate off a goal
        mov  cx,GW*GH
.w:     lodsb
        cmp  al,'$'
        je   .no
        loop .w
        mov  byte [won],1
.no:    ret

; ----------------------------------------------------------------------------
; TITLE - R_TITLE's title card over the level, on whatever card this is:
; TTLCARD draws through K_FONT, and FNT_OND4 sent K_FONT into the 4bpp frame.
; Out: CF = 1 Esc. /AUTO: shown 12 ticks.
TITLE:  mov  word [ttl_name],MNAME ; our words on the card
        mov  word [ttl_sub],MSUB
        mov  word [ttl_keys],MKEYS
        call TICK
        mov  [t0],ax
.f:     call GRID               ; the level behind the card
        call TICK               ; AX = the tick: PRESS ENTER blinks by it
        call TTLCARD
        call CRD_BLIT           ; only the rows that changed go out
        cmp  byte [auto],0
        je   .key
        call TICK
        sub  ax,[t0]            ; ticks shown
        cmp  ax,12
        jb   .f
        clc
        ret
.key:   mov  ah,1
        int  16h                ; a key waiting?
        jz   .f
        xor  ah,ah
        int  16h
        cmp  al,27
        je   .esc
        cmp  al,13
        je   .go
        cmp  al,' '
        jne  .f
.go:    clc
        ret
.esc:   stc
        ret
; TICK - AX = the BIOS tick (0040:006Ch)
TICK:   push es
        xor  ax,ax
        mov  es,ax
        mov  ax,[es:046Ch]
        pop  es
        ret

; DRAW - the whole picture into the buffer: the level, the words over it
DRAW:   call GRID
        mov  al,FNT_LSUB        ; the name: K_FONT 8x8 x2 smooth, ringed
        call FNT_LOOK
        mov  byte [fnt_col],14
        mov  si,MNAME
        mov  bx,160             ; centred
        mov  dx,10
        call FNT_CENTER
        mov  byte [fnt_col],15  ; MOVES: the fast 4x6, ringed (FNT_HUD)
        mov  byte [fnt_rc],0
        mov  si,MMOVES
        mov  bx,ORGX
        mov  dx,ORGY+GH*TILE+10
        call FNT_HUD            ; BX = past the word
        mov  al,FNT_LSCORE      ; the count: bold ringed digits
        call FNT_LOOK
        mov  ax,[moves]
        mov  cl,3               ; 009
        add  bx,4
        mov  dx,ORGY+GH*TILE+8  ; 7 high: the foot on the word's foot
        call FNT_NUMZ
        mov  byte [fnt_col],11  ; the keys, pale cyan, ringed
        mov  si,MHELP
        mov  bx,ORGX
        mov  dx,ORGY+GH*TILE+22
        call FNT_HUD
        cmp  byte [won],0
        je   .out
        mov  al,FNT_LFIRE       ; SOLVED over the grid: 8x16 x2, the fire
        call FNT_LOOK           ;  ramp in its 16 colours, ringed
        mov  si,MSOLVED
        mov  bx,160
        mov  dx,ORGY+GH*TILE/2-16 ; its middle on the grid's
        call FNT_CENTER
.out:   ret

; GRID - the floor, the walls, the crates and you
GRID:   xor  ax,ax
        mov  dx,200
        mov  bl,1               ; deep blue all over
        call D4_ROWS
        xor  di,di              ; DI = the cell
        mov  byte [cy],0
.row:   mov  byte [cx_],0
.col:   mov  al,[grid+di]
        mov  si,[tfloor]
        cmp  al,'#'
        jne  .g
        mov  si,[twall]
.g:     cmp  al,'.'
        je   .goal
        cmp  al,'*'
        jne  .base
.goal:  mov  si,[tgoal]
.base:  call .at                ; BX, DX = the cell's top left
        mov  ax,cs
        call D4_SPR             ; the ground
        mov  al,[grid+di]
        mov  si,[tcrate]
        cmp  al,'$'
        je   .top
        mov  si,[tcrok]
        cmp  al,'*'
        jne  .you
.top:   mov  ax,cs
        call D4_SPR             ; a crate on it
.you:   mov  al,[cx_]
        cmp  al,[px]
        jne  .next
        mov  al,[cy]
        cmp  al,[py]
        jne  .next
        mov  si,[tman]
        mov  ax,cs
        call D4_SPR             ; you
.next:  inc  di                 ; the next cell
        inc  byte [cx_]
        cmp  byte [cx_],GW
        jb   .col
        inc  byte [cy]
        cmp  byte [cy],GH
        jb   .row
        ret
; .at - BX, DX = the screen place of cell [cx_], [cy]
.at:    mov  al,[cx_]
        mov  ah,TILE
        mul  ah                 ; column * 16
        add  ax,ORGX
        mov  bx,ax
        mov  al,[cy]
        mov  ah,TILE
        mul  ah                 ; row * 16
        add  ax,ORGY
        mov  dx,ax
        ret

; TILES - every picture compiled for this card (EGA 640: twice as wide)
TILES:  push cs
        pop  es
        mov  di,tiles
        mov  si,PFLOOR
        mov  [tfloor],di
        call D4_COMP
        mov  [twall],di
        call D4_COMP            ; PWALL follows PFLOOR
        mov  [tgoal],di
        call D4_COMP
        mov  [tcrate],di
        call D4_COMP
        mov  [tcrok],di
        call D4_COMP
        mov  [tman],di
        call D4_COMP
        ret

; ----------------------------------------------------------------------------
; WAITT - CX BIOS ticks (18.2 a second)
WAITT:  push ax
        push es
        xor  ax,ax
        mov  es,ax
.t:     mov  ax,[es:046Ch]
.w:     cmp  ax,[es:046Ch]
        je   .w                 ; the next tick
        loop .t
        pop  es
        pop  ax
        ret

; GETARGS - /AUTO in the command tail: [auto] = 1; a digit after it: [want]
GETARGS:mov  si,81h
        mov  cl,[80h]
        xor  ch,ch
.s:     cmp  cx,5
        jb   .no
        mov  ax,[si]
        and  ax,0DFFFh          ; 'a' -> 'A' ('/' unchanged)
        cmp  ax,'/A'
        jne  .n
        mov  ax,[si+2]
        and  ax,0DFDFh
        cmp  ax,'UT'
        jne  .n
        mov  al,[si+4]
        and  al,0DFh
        cmp  al,'O'
        jne  .n
        mov  byte [auto],1
        add  si,5               ; past /AUTO
        sub  cx,5
.d:     jcxz .no
        lodsb
        dec  cx
        cmp  al,' '
        je   .d
        sub  al,'0'
        cmp  al,CRD_N
        ja   .no                ; not a card's digit
        mov  [want],al
        ret
.n:     inc  si
        dec  cx
        jmp  .s
.no:    ret

; REPORT - /AUTO's lines: solved, in how many moves, on which card
REPORT: mov  dx,mpass
        cmp  byte [won],0
        jne  .w
        mov  dx,mfail
.w:     mov  ah,9
        int  21h
        mov  dx,msolve
        mov  ah,9
        int  21h
        mov  ax,[moves]
        call PNUM
        mov  dx,mcard
        mov  ah,9
        int  21h
        mov  al,[crd_card]
        xor  ah,ah
        call PNUM
        mov  dx,crlf
        mov  ah,9
        int  21h
        cmp  byte [refused],0
        je   .r
        mov  dx,mrefuse
        mov  ah,9
        int  21h
.r:     mov  dx,mpass
        cmp  word [moves],9
        je   .m
        mov  dx,mfail
.m:     mov  ah,9
        int  21h
        mov  dx,mnine
        mov  ah,9
        int  21h
        ret
; PNUM - AX unsigned in decimal to DOS
PNUM:   xor  cx,cx
        mov  bx,10
.d:     xor  dx,dx
        div  bx                 ; AX = /10, DX = the digit (BX = 10)
        push dx
        inc  cx                 ; one more digit
        or   ax,ax
        jnz  .d
.o:     pop  dx
        add  dl,'0'
        mov  ah,2
        int  21h
        loop .o
        ret

; ----------------------------------------------------------------------------
; THE LEVEL: # wall, space floor, . goal, $ crate, * crate on goal, @ you
LEVEL   db '##########'
        db '#        #'
        db '#  @$ .  #'
        db '#        #'
        db '#   $  . #'
        db '#        #'
        db '##########'
; /AUTO's solution: the arrows' scan codes (48 up 50 down 4B left 4D right)
SCRIPT  db 4Dh,4Dh,50h,4Bh,4Bh,50h,4Dh,4Dh,4Dh,0

; THE TILES: 16x16 text art, '0'..'F' a colour (KIT\ART\PALETTE.TXT),
; '.' see-through, S s P p the look (K_D4's d4_look). Keep this order:
; TILES compiles them one after the other.
PFLOOR  db 16,16
        db '0000000000000008'
        db '0000000000000008'
        db '0000000000000008'
        db '0000000000000008'
        db '0000000000000008'
        db '0000000000000008'
        db '0000000000000008'
        db '0000000000000008'
        db '0000000000000008'
        db '0000000000000008'
        db '0000000000000008'
        db '0000000000000008'
        db '0000000000000008'
        db '0000000000000008'
        db '0000000000000008'
        db '8888888888888888'
PWALL   db 16,16
        db '7777777877777778'
        db '7FFFFF7877FFFF78'
        db '7777777877777778'
        db '8888888888888888'
        db '7778777777787777'
        db 'F778FFFF77787FFF'
        db '7778777777787777'
        db '8888888888888888'
        db '7777777877777778'
        db '7FFFFF7877FFFF78'
        db '7777777877777778'
        db '8888888888888888'
        db '7778777777787777'
        db 'F778FFFF77787FFF'
        db '7778777777787777'
        db '8888888888888888'
PGOAL   db 16,16
        db '0000000000000008'
        db '0000000000000008'
        db '0000000000000008'
        db '0000000000000008'
        db '0000CCCCCCCC0008'
        db '0000C444444C0008'
        db '0000C400004C0008'
        db '0000C400004C0008'
        db '0000C400004C0008'
        db '0000C400004C0008'
        db '0000C444444C0008'
        db '0000CCCCCCCC0008'
        db '0000000000000008'
        db '0000000000000008'
        db '0000000000000008'
        db '8888888888888888'
PCRATE  db 16,16
        db 'EEEEEEEEEEEEEEEE'
        db 'E46666666666664E'
        db 'E64666666666646E'
        db 'E66466666666466E'
        db 'E66646666664666E'
        db 'E44444444444444E'
        db 'E66666466466666E'
        db 'E66666644666666E'
        db 'E66666644666666E'
        db 'E66666466466666E'
        db 'E44444444444444E'
        db 'E66646666664666E'
        db 'E66466666666466E'
        db 'E64666666666646E'
        db 'E46666666666664E'
        db 'EEEEEEEEEEEEEEEE'
PCROK   db 16,16                ; a crate on its goal: the lime rim
        db 'AAAAAAAAAAAAAAAA'
        db 'A46666666666664A'
        db 'A64666666666646A'
        db 'A66466666666466A'
        db 'A66646666664666A'
        db 'A44444444444444A'
        db 'A66666466466666A'
        db 'A66666644666666A'
        db 'A66666644666666A'
        db 'A66666466466666A'
        db 'A44444444444444A'
        db 'A66646666664666A'
        db 'A66466666666466A'
        db 'A64666666666646A'
        db 'A46666666666664A'
        db 'AAAAAAAAAAAAAAAA'
PMAN    db 16,16
        db '................'
        db '......4444......'
        db '.....444444.....'
        db '.....EEEEEE.....'
        db '.....E0EE0E.....'
        db '.....EEEEEE.....'
        db '......EEEE......'
        db '....SSSSSSSS....'
        db '...SSSSSSSSSS...'
        db '...sSSSSSSSSs...'
        db '...E.SSSSSS.E...'
        db '.....PPPPPP.....'
        db '.....PP..PP.....'
        db '.....PP..PP.....'
        db '.....pp..pp.....'
        db '....000..000....'

; the card menu: K_MENU's form; the flags filled from crd_cap at run time
MCARDS  db 'T_GRID - THE PICTURE',0
        db 0,'EGA 640    640 x 200, 16 COLOURS',0
        db 0,'EGA        320 x 200, 16 COLOURS',0
        db 0,'CGA        320 x 200, 4 COLOURS',0
        db 0,'HERCULES   720 x 348, MONO',0
        db 0,'VGA        320 x 200, 256 COLOURS (16 USED)',0
        db 0FFh
MNAME   db 'Crates',0           ; the title card's words (R_TITLE TTLCARD)
MSUB    db 'every card, one frame',0
MKEYS   db 'Arrows',0,'walk, push',0 ; the key, what it does...
        db 'R',0,'again',0
        db 'Esc',0,'quit',0
        db 0                    ; ...an empty key ends them
MMOVES  db 'MOVES',0
MHELP   db 'ARROWS MOVE   R AGAIN   ESC QUITS',0
MSOLVED db 'SOLVED!',0
mnocard db 'T_GRID: no EGA, CGA, Hercules or VGA answers here.',13,10,'$'
mnomem  db 'T_GRID: DOS has no 64000 bytes for the picture.',13,10,'$'
mpass   db 'PASS $'
mfail   db 'FAIL $'
msolve  db 'T_GRID solved the level: moves $'
mcard   db ', card $'
mrefuse db 'NOTE the card asked for is not in this machine: the best one ran',13,10,'$'
mnine   db 'T_GRID the scripted solution takes 9 moves',13,10,'$'
crlf    db 13,10,'$'

auto    db 0                    ; 1: /AUTO
want    db 0                    ; /AUTO N: the card asked for
refused db 0                    ;  ...and it is not here
won     db 0
px      db 0                    ; you: column, row
py      db 0
cx_     db 0                    ; DRAW's cell: column, row
cy      db 0
moves   dw 0
t0      dw 0                    ; TITLE: the tick it began
spos    dw 0                    ; /AUTO: the script's next step
tfloor  dw 0                    ; the compiled tiles
twall   dw 0
tgoal   dw 0
tcrate  dw 0
tcrok   dw 0
tman    dw 0
grid    rb GW*GH
tiles   rb 6*520                ; EGA 640, holed: 2 + 16*16*2 bytes each

        include '..\..\KIT\LIB\K_CARD.INC'
        include '..\..\KIT\LIB\K_D4.INC'
        include '..\..\KIT\LIB\K_MENU.INC'
        include '..\..\KIT\LIB\K_FONT.INC' ; the good letters (FNT_*)
        include '..\..\KIT\REC\R_TITLE.ASM' ; TTLCARD (TTLRUN is 13h's)
