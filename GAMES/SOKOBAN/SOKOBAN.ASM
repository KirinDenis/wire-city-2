; ==================================================================
;  SOKOBAN.ASM - crates onto the red marks, in an isometric brick
;  warehouse on a CGA screen: 320x200, four colours.
;      MAKE in GAMES\SOKOBAN, MAKEWIN from Windows (the repository)
;      build A:\MY\SOKOBAN\SOKOBAN.ASM     (the site: FASM, then it runs)
;  ARROWS walk the grid: UP goes up-right on the screen, RIGHT goes
;         down-right, DOWN down-left, LEFT up-left.  The keypad's
;         9 3 1 7 (PgUp PgDn End Home) are the same four, named the
;         way the screen shows them.
;  Z      the whole level / close up
;  R R    the level anew      N N, P P   the next, the previous level
;  ESC    back to DOS
;  A crate onto a goal +10, off one -10; a solved level +50 to every
;  man in the warehouse.  The levels are Base-Z-47's (LEVELS.INC), the
;  pictures are text, one character a pixel (ART.INC).
;  THE ONE FACT: a CGA byte is four pixels, two bits each, and the
;  screen is two banks - the even rows at B800:0000, the odd rows
;  8 KB higher at B800:2000.
; ==================================================================
format binary as 'com'
        org  100h               ; DOS loads a .COM at offset 100h
        include '..\..\ENGINE\E_8086.INC'  ; jumps an 8086 can run

NCOL    = 32                    ; grid row stride: the widest level is 29
G_WALL  = 1                     ; the bits of a grid cell
G_GOAL  = 2
G_BOX   = 4
G_FLOOR = 8                     ; inside the walls: flooded from the man
G_MAN   = 16                    ; a man stands here
MAXP    = 8                     ; men in the warehouse
NLOOK   = 6                     ; shirt and cap pairs (LOOKS)
PFTOP   = 8                     ; the playfield: rows 8..167; above it
PFBOT   = 168                   ;  the level line, under it the players
SOLVT   = 54                    ; ticks the SOLVED banner stays: 3 s
PENDT   = 36                    ; ticks a "press again" waits: 2 s
SPRMAX  = 4096                  ; compiled pictures: 3588 bytes today

; a player
P_ON    = 0                     ; byte: 1 = in the warehouse
P_COL   = 1                     ; byte: grid column
P_ROW   = 2                     ; byte: grid row
P_LOOK  = 3                     ; byte: 0..NLOOK-1
P_SCORE = 4                     ; word, signed
P_NAME  = 6                     ; 8 letters and a zero
PSIZE   = 16

; a zoom: its steps, its lifts, its compiled pictures
Z_HX    = 0                     ; px across per grid step: 8 or 12
Z_HY    = 2                     ; px down per grid step: 4 or 6
Z_LWAL  = 4                     ; where each picture's top row goes,
Z_LBOX  = 6                     ;  counted from the tile's own top row
Z_LMAN  = 8
Z_LYOU  = 10
Z_FLR   = 12                    ; the compiled pictures
Z_GOL   = 14
Z_WAL   = 16
Z_BOX   = 18
Z_BOG   = 20
Z_YOU   = 22
Z_MAN   = 24                    ; NLOOK of them

; SPR - compile one picture and keep where it went
macro SPR art,dst,wid
{
        mov  [dst],di
        mov  si,art
        mov  cl,wid
        call COMPILE
}

START:  cld                     ; string ops count UP
        mov  ax,[2]             ; PSP:2 = the top of our memory, paragraphs
        mov  bx,cs
        sub  ax,bx              ; AX = paragraphs DOS gave us
        cmp  ax,1000h           ; a whole 64K segment? the back buffer
        jae  .mem               ;  lives at its top
        mov  dx,MSGMEM
        mov  ah,9
        int  21h                ; puts(MSGMEM)
        mov  ax,4C01h
        int  21h                ; exit(1)
.mem:   call PREP               ; tables, pictures, the font
        mov  ax,0004h           ; mode 4: CGA 320x200, four colours
        int  10h
        call SETPAL
        call TITLE              ; comes back on Enter (Esc quits)
        mov  word [level],0
        call NEWLEV
MAIN:   mov  ax,1680h           ; give the host our time slice: in a
        int  2Fh                ;  browser a tight loop starves the keys
        call KEYS
        call TIMERS
        cmp  byte [dirty],0     ; turn by turn: draw only what changed
        je   MAIN
        mov  byte [dirty],0
        call RENDER
        call WAITV
        call BLIT
        jmp  MAIN

QUIT:   mov  ax,0003h           ; text mode 3, as DOS lent it
        int  10h
        mov  ax,4C00h
        int  21h                ; exit(0)

; ------------------------------------------------------------------
;  SETPAL - green, red, yellow on black, on every card.  A CGA takes
;  port 3D9h; a VGA in mode 4 ignores it and the BIOS palette call,
;  and takes its colours from the attribute registers instead.
; ------------------------------------------------------------------
SETPAL: mov  ah,0Bh
        mov  bx,0010h           ; BH 0: background black, BL bit 4: bright
        int  10h
        mov  ah,0Bh
        mov  bx,0100h           ; BH 1: palette 0 - green red yellow
        int  10h
        mov  dx,3D9h            ; the CGA colour register itself:
        mov  al,10h             ;  bit 4 bright, bit 5 clear: palette 0
        out  dx,al
        mov  bx,3A01h           ; EGA/VGA attribute 1 = light green 3Ah
        call .att
        mov  bx,3C02h           ;                   2 = light red 3Ch
        call .att
        mov  bx,3E03h           ;                   3 = yellow 3Eh
        call .att
        mov  bx,0000h           ;                   0 = black
.att:   mov  ax,1000h           ; BL = the register, BH = its colour;
        int  10h                ;  a CGA BIOS does not know it and
        ret                     ;  leaves everything as it was

; ------------------------------------------------------------------
;  PREP - the row table, both sizes of every picture, the 8x8 font,
;  and you in player slot 0.
; ------------------------------------------------------------------
PREP:   mov  di,rowtab          ; rowtab[y] = bbuf + y*80
        mov  ax,bbuf
        mov  cx,200
.row:   stosw
        add  ax,80              ; 80 bytes a row: 320 px, 4 a byte
        loop .row
        mov  di,sprbuf
        SPR  FLRS,ZS+Z_FLR,4    ; small: 16 px = 4 bytes a row
        SPR  GOLS,ZS+Z_GOL,4
        SPR  WALS,ZS+Z_WAL,4
        SPR  BOXS,ZS+Z_BOX,4
        SPR  BOGS,ZS+Z_BOG,4
        SPR  YOUS,ZS+Z_YOU,4
        SPR  FLRB,ZB+Z_FLR,6    ; big: 24 px = 6 bytes a row
        SPR  GOLB,ZB+Z_GOL,6
        SPR  WALB,ZB+Z_WAL,6
        SPR  BOXB,ZB+Z_BOX,6
        SPR  BOGB,ZB+Z_BOG,6
        SPR  YOUB,ZB+Z_YOU,6
        xor  bx,bx              ; the men, one per look, both sizes
.man:   mov  dx,word [LOOKS+bx] ; DL = shirt, DH = cap and trousers
        mov  [ZS+Z_MAN+bx],di
        mov  si,MANS
        mov  cl,4
        push bx
        call COMPILE
        pop  bx
        mov  [ZB+Z_MAN+bx],di
        mov  si,MANB
        mov  cl,6
        push bx
        call COMPILE
        pop  bx
        add  bx,2               ; the next look: two bytes each
        cmp  bx,NLOOK*2
        jb   .man
        cmp  di,sprbuf+SPRMAX   ; did they all fit?
        jbe  .font
        mov  ax,0003h
        int  10h
        mov  dx,MSGSPR
        mov  ah,9
        int  21h                ; puts(MSGSPR)
        mov  ax,4C01h
        int  21h                ; exit(1)
.font:  mov  ax,0F000h          ; the 8x8 font: a CGA BIOS keeps it at
        mov  es,ax              ;  F000:FA6E; an EGA or VGA BIOS says
        mov  bp,0FA6Eh          ;  where its own is in ES:BP
        mov  ax,1130h
        mov  bh,3               ; BH 3: the 8x8 font, characters 0..127
        int  10h
        mov  word [fontp],bp
        mov  word [fontp+2],es
        push cs
        pop  es                 ; ES = our segment again
        ret

; ------------------------------------------------------------------
;  COMPILE - text art into mask and ink bytes.  in: SI -> art (db rows,
;  then rows strings of CL*4 characters), DI -> out, CL = bytes a row,
;  DL = shirt colour, DH = cap colour.  out: db rows, db CL, then a
;  (mask, ink) pair per byte; SI, DI past them.  clobbers AX, BX, CX.
;  Drawn as  screen = (screen AND mask) OR ink.
; ------------------------------------------------------------------
COMPILE:lodsb                   ; rows
        stosb
        mov  ch,al              ; CH = rows to go
        mov  al,cl
        stosb                   ; bytes a row
.row:   push cx
.byte:  push cx
        xor  bx,bx              ; BL = mask, BH = ink
        mov  cx,4               ; four pixels a byte
.pix:   shl  bl,1
        shl  bl,1               ; mask << 2: room for this pixel
        shl  bh,1
        shl  bh,1               ; ink << 2
        lodsb
        cmp  al,'.'
        jne  .ink
        or   bl,3               ; see-through: keep the screen's two bits
        jmp  .next
.ink:   cmp  al,'S'
        jne  .cap
        or   bh,dl              ; the shirt
        jmp  .next
.cap:   cmp  al,'P'
        jne  .dig
        or   bh,dh              ; the cap and trousers
        jmp  .next
.dig:   sub  al,'0'             ; '0'..'3' -> colour 0..3
        or   bh,al
.next:  loop .pix
        mov  al,bl
        stosb                   ; the mask...
        mov  al,bh
        stosb                   ; ...and the ink
        pop  cx
        dec  cl
        jnz  .byte
        pop  cx
        dec  ch
        jnz  .row
        ret

; ------------------------------------------------------------------
;  TITLE - the name, a picture of the job, the keys.  Back on Enter.
; ------------------------------------------------------------------
TITLE:  call CLS
        mov  word [tcol],13     ; 7 big letters, 16 px each: from x 104
        mov  word [trow],14
        mov  byte [tclr],2
        mov  si,TNAME
        call PRBIG
        mov  si,TLINES
        call PRLIST
        call VIGNET
        call WAITV
        call BLIT
.wait:  mov  ax,1680h
        int  2Fh                ; yield, as in MAIN
        mov  ah,1
        int  16h                ; a key?
        jz   .wait
        mov  ah,0
        int  16h
        cmp  al,27
        jne  .ent
        jmp  QUIT
.ent:   cmp  al,13
        jne  .wait
        ret

; VIGNET - a man, a crate, a goal before a wall: the game in one row
VIGNET: mov  word [ox],124      ; centres the 6 tiles: 96 px wide
        mov  word [oy],60
        mov  byte [vc],0
.flr:   mov  al,[vc]            ; the floor: row 1, columns 0..5
        mov  ah,1
        mov  bx,[zoomp]
        mov  si,[bx+Z_FLR]
        cmp  al,5
        jne  .f1
        mov  si,[bx+Z_GOL]      ; the last one a goal
.f1:    xor  cx,cx
        call PUTAT
        inc  byte [vc]
        cmp  byte [vc],6
        jb   .flr
        mov  byte [vc],0
.wal:   mov  al,[vc]            ; the wall behind it: row 0
        xor  ah,ah
        mov  bx,[zoomp]
        mov  si,[bx+Z_WAL]
        mov  cx,[bx+Z_LWAL]
        call PUTAT
        inc  byte [vc]
        cmp  byte [vc],6
        jb   .wal
        mov  ax,0103h           ; the man: column 3, row 1
        mov  bx,[zoomp]
        mov  si,[bx+Z_MAN]
        mov  cx,[bx+Z_LMAN]
        call PUTAT
        mov  ax,0104h           ; his crate, in front of him: column 4
        mov  bx,[zoomp]
        mov  si,[bx+Z_BOX]
        mov  cx,[bx+Z_LBOX]
        jmp  PUTAT

; ------------------------------------------------------------------
;  NEWLEV - level [level] into the grid; your man on its start.
; ------------------------------------------------------------------
NEWLEV: mov  di,gridpad         ; a zero row in front, then the grid
        mov  cx,(NCOL+NCOL*NCOL)/2
        xor  ax,ax
        rep  stosw
        mov  [nbox],ax
        mov  [ngood],ax
        mov  [moves],ax
        mov  [solved],al
        mov  [pend],al
        mov  bx,[level]
        shl  bx,1               ; a word per level
        mov  si,[LEVTAB+bx]
        lodsb
        mov  [lvw],al
        lodsb
        mov  [lvh],al
        mov  di,grid
        mov  dh,[lvh]           ; rows to go
.row:   push di
        mov  dl,[lvw]           ; columns to go
.col:   lodsb
        mov  ah,G_WALL
        cmp  al,'#'
        je   .put
        mov  ah,G_BOX
        cmp  al,'$'
        je   .box
        mov  ah,G_BOX or G_GOAL
        cmp  al,'*'
        je   .good
        mov  ah,G_GOAL
        cmp  al,'.'
        je   .put
        cmp  al,'+'             ; the man on a goal
        je   .man
        xor  ah,ah
        cmp  al,'@'
        jne  .put
.man:   mov  [start],di
        jmp  .put
.good:  inc  word [ngood]       ; a crate already home
.box:   inc  word [nbox]
.put:   mov  [di],ah
        inc  di
        dec  dl
        jnz  .col
        pop  di
        add  di,NCOL            ; the next grid row
        dec  dh
        jnz  .row
        call FLOOD
        mov  bx,[start]
        or   byte [bx],G_MAN
        mov  si,[mep]
        call SETPOS             ; your man: column and row from BX
        mov  byte [camnew],1
        mov  byte [dirty],1
        ret

; SETPOS - a player's column and row from his cell.  in: SI player,
; BX -> cell.  clobbers AX, CL.
SETPOS: mov  ax,bx
        sub  ax,grid            ; AX = row*32 + column
        mov  [si+P_COL],al
        and  byte [si+P_COL],NCOL-1  ; the low 5 bits: the column
        mov  cl,5
        shr  ax,cl              ; /32: the row
        mov  [si+P_ROW],al
        ret

; ------------------------------------------------------------------
;  FLOOD - G_FLOOR on every cell a man could reach with no crate in
;  the way: the floor to draw; outside it is the void.  Passes over
;  the grid until one adds nothing.  The rows above and below and the
;  column right of the level are zero, so no neighbour test can leak.
; ------------------------------------------------------------------
FLOOD:  mov  bx,[start]
        or   byte [bx],G_FLOOR
.pass:  mov  byte [chg],0
        mov  bx,grid
        mov  dh,[lvh]
.row:   push bx
        mov  dl,[lvw]
.col:   test byte [bx],G_WALL or G_FLOOR
        jnz  .next
        mov  al,[bx-1]
        or   al,[bx+1]
        or   al,[bx-NCOL]
        or   al,[bx+NCOL]       ; the four neighbours' bits together
        test al,G_FLOOR
        jz   .next
        or   byte [bx],G_FLOOR
        mov  byte [chg],1
.next:  inc  bx
        dec  dl
        jnz  .col
        pop  bx
        add  bx,NCOL
        dec  dh
        jnz  .row
        cmp  byte [chg],0
        jne  .pass
        ret

; ------------------------------------------------------------------
;  KEYS - one key from the BIOS, if one waits.  Sokoban is turn by
;  turn, so the BIOS buffer is the right reader: every press counts.
; ------------------------------------------------------------------
KEYS:   mov  ah,1
        int  16h                ; a key waiting? ZF set = no
        jz   .end
        mov  ah,0
        int  16h                ; AH = scan code, AL = character
        cmp  al,27
        jne  .live
        jmp  QUIT
.live:  cmp  byte [solved],0
        jne  .end               ; the banner is up: the next level comes
        mov  bx,DIRKEYS
        mov  cx,8
.dk:    cmp  ah,[bx]
        je   .dir
        add  bx,2
        loop .dk
        or   al,20h             ; letters to lower case
        cmp  al,'z'
        je   .zoom
        xor  bx,bx
        cmp  al,'r'
        je   .q1
        cmp  al,'n'
        je   .q2
        cmp  al,'p'
        je   .q3
.end:   ret
.dir:   mov  al,[bx+1]          ; 0 up, 1 right, 2 down, 3 left
        jmp  MOVE
.zoom:  xor  word [zoomp],ZS xor ZB  ; flip between the two sizes
        mov  byte [camnew],1
        mov  byte [dirty],1
        ret
.q3:    inc  bx
.q2:    inc  bx
.q1:    inc  bx                 ; BL = 1 R, 2 N, 3 P
        cmp  bl,[pend]
        je   .act
        mov  [pend],bl          ; the first press only asks
        mov  ax,[now]
        mov  [pendt],ax
        mov  byte [dirty],1
        ret
.act:   mov  byte [pend],0      ; the second one does it
        mov  ax,[level]
        cmp  bl,1
        je   .go                ; R: this level again
        inc  ax                 ; N: the next...
        cmp  bl,2
        je   .wrap
        sub  ax,2               ; P: one back from where we were
        jns  .go
        mov  ax,NLEVELS-1       ;  before the first: the last
        jmp  .go
.wrap:  cmp  ax,NLEVELS
        jb   .go
        xor  ax,ax              ;  after the last: the first
.go:    mov  [level],ax
        jmp  NEWLEV

; ------------------------------------------------------------------
;  MOVE - your man one step.  A crate in the way goes too, if the cell
;  behind it is floor with nothing on it.  in: AL = 0 up, 1 right,
;  2 down, 3 left (the grid's directions).
; ------------------------------------------------------------------
MOVE:   xor  ah,ah
        shl  ax,1               ; a word per direction
        mov  bx,ax
        mov  dx,[DSTEP+bx]      ; DX = the step in grid bytes
        mov  si,[mep]
; STEP - player SI one step of DX grid bytes
STEP:   mov  al,[si+P_ROW]
        xor  ah,ah
        mov  cl,5
        shl  ax,cl              ; row * 32
        add  al,[si+P_COL]      ; + column: no carry, the column is < 32
        add  ax,grid
        mov  di,ax              ; DI -> the man's cell
        mov  bx,ax
        add  bx,dx              ; BX -> the cell he steps into
        mov  al,[bx]
        test al,G_WALL or G_MAN
        jnz  .no
        test al,G_BOX
        jz   .walk
        mov  bp,bx
        add  bp,dx              ; BP -> the cell behind the crate
        mov  ah,[bp]            ; (SS = DS in a .COM)
        test ah,G_WALL or G_BOX or G_MAN
        jnz  .no
        test ah,G_FLOOR
        jz   .no
        and  byte [bx],0FFh xor G_BOX   ; the crate leaves...
        or   byte [bp],G_BOX            ; ...and lands
        test al,G_GOAL
        jz   .off
        sub  word [si+P_SCORE],10  ; off a goal: -10
        dec  word [ngood]
.off:   test ah,G_GOAL
        jz   .walk
        add  word [si+P_SCORE],10  ; onto a goal: +10
        inc  word [ngood]
.walk:  and  byte [di],0FFh xor G_MAN
        or   byte [bx],G_MAN
        call SETPOS
        inc  word [moves]
        mov  byte [dirty],1
        mov  ax,[ngood]
        cmp  ax,[nbox]          ; every crate home?
        jne  .no
        mov  byte [solved],1
        mov  ax,[now]
        mov  [soltick],ax
        mov  bx,players         ; +50 to every man here: the level
.p:     cmp  byte [bx+P_ON],0   ;  was everyone's
        je   .n
        add  word [bx+P_SCORE],50
.n:     add  bx,PSIZE
        cmp  bx,players+MAXP*PSIZE
        jb   .p
.no:    ret

; ------------------------------------------------------------------
;  TIMERS - the BIOS tick: the SOLVED banner's end, a question's end.
; ------------------------------------------------------------------
TIMERS: push ds
        xor  ax,ax
        mov  ds,ax
        mov  ax,[046Ch]         ; the BIOS tick, 18.2 a second
        pop  ds
        mov  [now],ax
        cmp  byte [solved],0
        je   .pend
        sub  ax,[soltick]       ; ticks since: unsigned, a wrap still
        cmp  ax,SOLVT           ;  gives a small difference
        jb   .pend
        mov  ax,[level]
        inc  ax                 ; the next level
        cmp  ax,NLEVELS
        jb   .lv
        xor  ax,ax              ; after the last, the first again
.lv:    mov  [level],ax
        jmp  NEWLEV
.pend:  cmp  byte [pend],0
        je   .end
        mov  ax,[now]
        sub  ax,[pendt]
        cmp  ax,PENDT
        jb   .end
        mov  byte [pend],0      ; not pressed again: forget it
        mov  byte [dirty],1
.end:   ret

; ------------------------------------------------------------------
;  CAMERA - ox, oy: where grid cell 0,0 lands.  Tile (c,r) has its top
;  row at  x = ox + (c-r)*hx,  y = oy + (c+r)*hy.  A level that fits
;  is centred; a bigger one follows your man, who walks the middle
;  half of the screen freely before it scrolls.
; ------------------------------------------------------------------
CAMERA: mov  bx,[zoomp]
        mov  al,[lvw]
        add  al,[lvh]
        xor  ah,ah
        mov  [wph],ax           ; w+h: the level's span in steps
        mul  word [bx+Z_HX]     ; (w+h)*hx: its width in px
        mov  [wpx],ax
        mov  ax,[wph]
        mul  word [bx+Z_HY]     ; (w+h)*hy...
        add  ax,6               ; ...and the back walls stand 6 above
        mov  [hpx],ax
        mov  al,[lvh]
        xor  ah,ah
        dec  ax                 ; h-1
        mul  word [bx+Z_HX]
        neg  ax                 ; xmin = -(h-1)*hx: the left corner
        mov  [xmin],ax
        mov  si,[mep]
        mov  al,[si+P_COL]
        sub  al,[si+P_ROW]
        cbw                     ; c - r, signed
        imul word [bx+Z_HX]
        add  ax,[bx+Z_HX]       ; + hx: the middle of his tile
        mov  [manx],ax
        mov  al,[si+P_COL]
        add  al,[si+P_ROW]
        xor  ah,ah              ; c + r
        mul  word [bx+Z_HY]
        mov  [many],ax
; across
        mov  ax,[wpx]
        cmp  ax,320
        ja   .xfol
        mov  ax,320
        sub  ax,[wpx]
        sar  ax,1               ; the margin either side
        sub  ax,[xmin]          ; ox = margin - xmin
        jmp  .xset
.xfol:  mov  ax,[ox]
        cmp  byte [camnew],0
        je   .xkeep
        mov  ax,160
        sub  ax,[manx]          ; a new level: the man in the middle
.xkeep: mov  dx,ax
        add  dx,[manx]          ; DX = his x on the screen
        cmp  dx,80
        jge  .xr
        add  ax,80              ; off the left quarter: ox += 80 - x
        sub  ax,dx
.xr:    cmp  dx,240
        jle  .xc
        sub  ax,dx              ; off the right quarter: ox -= x - 240
        add  ax,240
.xc:    mov  dx,[xmin]
        neg  dx                 ; the left edge stays off the screen:
        cmp  ax,dx              ;  ox <= -xmin
        jle  .xc2
        mov  ax,dx
.xc2:   mov  dx,320             ; and the right edge: ox >= 320-xmax,
        sub  dx,[xmin]          ;  xmax = xmin + width
        sub  dx,[wpx]
        cmp  ax,dx
        jge  .xset
        mov  ax,dx
.xset:  and  ax,0FFFCh          ; a whole byte: four pixels
        mov  [ox],ax
; down
        mov  ax,[hpx]
        cmp  ax,PFBOT-PFTOP
        ja   .yfol
        mov  ax,PFBOT-PFTOP
        sub  ax,[hpx]
        sar  ax,1               ; the margin above and below
        add  ax,PFTOP+6         ; the back walls' tops are 6 over oy
        jmp  .yset
.yfol:  mov  ax,[oy]
        cmp  byte [camnew],0
        je   .ykeep
        mov  ax,(PFTOP+PFBOT)/2
        sub  ax,[many]
.ykeep: mov  dx,ax
        add  dx,[many]          ; DX = his y on the screen
        cmp  dx,PFTOP+40
        jge  .yb
        add  ax,PFTOP+40        ; too high: oy += top band - y
        sub  ax,dx
.yb:    cmp  dx,PFBOT-40
        jle  .yc
        sub  ax,dx              ; too low: oy -= y - bottom band
        add  ax,PFBOT-40
.yc:    cmp  ax,PFTOP+6         ; the top edge stays off: oy-6 <= PFTOP
        jle  .yc2
        mov  ax,PFTOP+6
.yc2:   mov  dx,PFBOT+6         ; the bottom too: oy-6+hpx >= PFBOT
        sub  dx,[hpx]
        cmp  ax,dx
        jge  .yset
        mov  ax,dx
.yset:  mov  [oy],ax
        mov  byte [camnew],0
        ret

; ------------------------------------------------------------------
;  RENDER - the warehouse into the back buffer, back to front: first
;  every floor, then row by row the walls, crates and men - a tile
;  further down the screen is always nearer, so it is drawn later.
; ------------------------------------------------------------------
RENDER: call CLS
        call CAMERA
        mov  byte [pass],0
.pass:  mov  ax,[ox]            ; row 0 starts at the origin
        mov  [rowx],ax
        mov  ax,[oy]
        mov  [rowy],ax
        mov  word [cidx],grid
        mov  byte [crow],0
.row:   mov  ax,[rowx]
        mov  [curx],ax
        mov  ax,[rowy]
        mov  [cury],ax
        mov  ax,[cidx]
        mov  [cptr],ax
        mov  byte [ccol],0
.cell:  mov  bx,[cptr]
        mov  al,[bx]            ; the cell's bits
        or   al,al
        jz   .next              ; the void: nothing to draw
        mov  bx,[zoomp]
        cmp  byte [pass],0
        jne  .thing
        test al,G_FLOOR
        jz   .next
        mov  si,[bx+Z_FLR]
        test al,G_GOAL
        jz   .flr
        mov  si,[bx+Z_GOL]
.flr:   xor  cx,cx              ; a floor lies on its own row
        call DRAWAT
        jmp  .next
.thing: test al,G_WALL
        jz   .nowal
        mov  si,[bx+Z_WAL]
        mov  cx,[bx+Z_LWAL]
        call DRAWAT
        jmp  .next
.nowal: test al,G_BOX
        jz   .nobox
        mov  si,[bx+Z_BOX]
        test al,G_GOAL
        jz   .box
        mov  si,[bx+Z_BOG]      ; home: the green crate
.box:   mov  cx,[bx+Z_LBOX]
        call DRAWAT
        jmp  .next
.nobox: test al,G_MAN
        jz   .next
        call DRAWMEN
.next:  mov  bx,[zoomp]
        mov  ax,[bx+Z_HX]
        add  [curx],ax          ; a column on: right and down
        mov  ax,[bx+Z_HY]
        add  [cury],ax
        inc  word [cptr]
        inc  byte [ccol]
        mov  al,[ccol]
        cmp  al,[lvw]
        jb   .cell
        mov  ax,[bx+Z_HX]
        sub  [rowx],ax          ; a row on: left and down
        mov  ax,[bx+Z_HY]
        add  [rowy],ax
        add  word [cidx],NCOL
        inc  byte [crow]
        mov  al,[crow]
        cmp  al,[lvh]
        jb   .row
        inc  byte [pass]
        cmp  byte [pass],2
        jb   .pass
        jmp  HUD

; DRAWMEN - every man standing on cell ccol, crow; the arrow over yours
DRAWMEN:mov  word [pidx],players
.p:     mov  bx,[pidx]
        cmp  byte [bx+P_ON],0
        je   .n
        mov  al,[bx+P_COL]
        cmp  al,[ccol]
        jne  .n
        mov  al,[bx+P_ROW]
        cmp  al,[crow]
        jne  .n
        mov  al,[bx+P_LOOK]
        xor  ah,ah
        shl  ax,1               ; a word per look
        mov  bx,[zoomp]
        add  bx,ax
        mov  si,[bx+Z_MAN]      ; his picture
        mov  bx,[zoomp]
        mov  cx,[bx+Z_LMAN]
        call DRAWAT
        mov  ax,[pidx]
        cmp  ax,[mep]           ; this machine's man?
        jne  .n
        mov  bx,[zoomp]
        mov  si,[bx+Z_YOU]
        mov  cx,[bx+Z_LYOU]
        call DRAWAT
.n:     add  word [pidx],PSIZE
        cmp  word [pidx],players+MAXP*PSIZE
        jb   .p
        ret

; PUTAT - a picture on cell AL = column, AH = row of the current zoom.
; in: SI picture, CX lift.  clobbers everything but BP.
PUTAT:  push cx
        push si
        push ax
        mov  bx,[zoomp]
        sub  al,ah
        cbw                     ; c - r, signed
        imul word [bx+Z_HX]     ; (DX goes too: c and r are on the stack)
        add  ax,[ox]
        mov  [curx],ax
        pop  ax
        add  al,ah
        xor  ah,ah              ; c + r
        mul  word [bx+Z_HY]
        add  ax,[oy]
        mov  [cury],ax
        pop  si
        pop  cx
; DRAWAT - picture SI at curx, cury + CX
DRAWAT: mov  bx,[curx]
        mov  dx,[cury]
        add  dx,cx              ; lifted: where its top row goes
; ------------------------------------------------------------------
;  DRAWSPR - a compiled picture into the back buffer.  in: SI ->
;  picture, BX = x (a multiple of 4, may be negative), DX = y (may be
;  negative).  Rows outside PFTOP..PFBOT-1 and bytes off the sides
;  are skipped.  clobbers AX, BX, CX, DX, SI, DI.
;  In C:  for each row, for each byte b:
;           buf[y][x/4+b] = (buf[y][x/4+b] & mask) | ink;
; ------------------------------------------------------------------
DRAWSPR:push bp
        lodsb
        xor  ah,ah
        mov  cx,ax              ; CX = rows
        lodsb
        mov  bp,ax              ; BP = bytes a row (AH still 0)
        sar  bx,1
        sar  bx,1               ; x/4: the byte column, signed
.row:   cmp  dx,PFTOP
        jl   .skip
        cmp  dx,PFBOT
        jge  .done              ; rows only go down: nothing more shows
        mov  di,dx
        shl  di,1               ; a word per row
        mov  di,[rowtab+di]     ; DI = bbuf + y*80
        add  di,bx              ; + the byte column
        push cx
        push bx
        mov  cx,bp
.byte:  lodsw                   ; AL = mask, AH = ink
        cmp  bx,80              ; unsigned: a negative column is huge
        jae  .off
        and  [di],al
        or   [di],ah
.off:   inc  di
        inc  bx
        loop .byte
        pop  bx
        pop  cx
        jmp  .down
.skip:  add  si,bp
        add  si,bp              ; past this row's pairs: 2 bytes each
.down:  inc  dx
        loop .row
.done:  pop  bp
        ret

; ------------------------------------------------------------------
;  HUD - the level line on top, the players under the playfield, and
;  over it the banner or the question, if any.
; ------------------------------------------------------------------
HUD:    xor  ax,ax
        mov  [trow],ax
        mov  [tcol],ax
        mov  si,TLEV
        mov  byte [tclr],1
        call PRINT
        mov  ax,[level]
        inc  ax                 ; levels count from 1 on the screen
        mov  cl,2
        mov  byte [tclr],3
        call PNUM
        mov  si,TSLASH
        mov  byte [tclr],1
        call PRINT
        mov  ax,NLEVELS
        mov  cl,2
        mov  byte [tclr],3
        call PNUM
        mov  word [tcol],14
        mov  si,TCRATE
        mov  byte [tclr],1
        call PRINT
        mov  ax,[ngood]
        mov  cl,1
        mov  byte [tclr],3
        call PNUM
        mov  si,TSLASH
        mov  byte [tclr],1
        call PRINT
        mov  ax,[nbox]
        mov  cl,1
        mov  byte [tclr],3
        call PNUM
        mov  word [tcol],29
        mov  si,TMOVES
        mov  byte [tclr],1
        call PRINT
        mov  ax,[moves]
        mov  cl,1
        mov  byte [tclr],3
        call PNUM
        call PLIST
        cmp  byte [solved],0
        je   .ask
        mov  si,TSOLV
        mov  dx,80
        call BANNER
.ask:   mov  bl,[pend]
        or   bl,bl
        jz   .end
        xor  bh,bh
        shl  bx,1               ; a word per question
        mov  si,[QTAB+bx]
        mov  dx,PFBOT-16
        call BANNER
.end:   ret

; PLIST - the players: two columns of four under the playfield
PLIST:  mov  word [pidx],players
        mov  byte [pslot],0
.p:     mov  bx,[pidx]
        cmp  byte [bx+P_ON],0
        je   .n
        mov  al,[pslot]
        and  ax,1               ; left or right column
        mov  cx,20
        mul  cx                 ; 0 or 20  (DX goes)
        mov  [pcol],ax
        mov  [tcol],ax
        mov  al,[pslot]
        xor  ah,ah
        shr  ax,1               ; the line, 0..3
        mov  cl,3
        shl  ax,cl              ; 8 px a line
        add  ax,PFBOT
        mov  [trow],ax
        mov  al,' '
        mov  bx,[pidx]
        cmp  bx,[mep]
        jne  .mark
        mov  al,16              ; a pointer at this machine's man
.mark:  mov  byte [tclr],3
        call PUTCH
        mov  bx,[pidx]
        mov  al,[bx+P_LOOK]
        xor  ah,ah
        shl  ax,1
        mov  bx,ax
        mov  al,[LOOKS+bx]      ; his shirt's colour
        mov  [tclr],al
        mov  al,2               ; a face
        call PUTCH
        inc  word [tcol]        ; a space
        mov  byte [tclr],1
        mov  si,[pidx]
        add  si,P_NAME
        call PRINT
        mov  ax,[pcol]
        add  ax,12              ; the score in its own column
        mov  [tcol],ax
        mov  byte [tclr],3
        mov  bx,[pidx]
        mov  ax,[bx+P_SCORE]
        mov  cl,1
        call PSNUM
        inc  byte [pslot]
.n:     add  word [pidx],PSIZE
        cmp  word [pidx],players+MAXP*PSIZE
        jb   .p
        ret

; BANNER - string SI centred on text row y = DX, in yellow
BANNER: mov  [trow],dx
        mov  di,si
        xor  cx,cx
.len:   cmp  byte [di],0
        je   .go
        inc  di
        inc  cx
        jmp  .len
.go:    mov  ax,40
        sub  ax,cx
        shr  ax,1               ; (40 - length) / 2
        mov  [tcol],ax
        mov  byte [tclr],3
        jmp  PRINT

; ------------------------------------------------------------------
;  Text with the BIOS 8x8 font: [tcol] 0..39 (8 px each), [trow] y,
;  [tclr] 1..3.  A character cell is opaque: it reads over anything.
; ------------------------------------------------------------------
; PRLIST - db column, y, colour, 'text', 0 ... then db 0FFh
PRLIST: lodsb
        cmp  al,0FFh
        je   .end
        xor  ah,ah
        mov  [tcol],ax
        lodsb
        mov  [trow],ax
        lodsb
        mov  [tclr],al
        call PRINT
        jmp  PRLIST
.end:   ret

; PRINT - the zero-ended string at SI; SI ends past the zero
PRINT:  lodsb
        or   al,al
        jz   .end
        call PUTCH
        jmp  PRINT
.end:   ret

; PNUM - AX unsigned, at least CL digits; PSNUM - AX signed
PSNUM:  or   ax,ax
        jns  PNUM
        push ax
        push cx
        mov  al,'-'
        call PUTCH
        pop  cx
        pop  ax
        neg  ax                 ; print the size, the sign is out
PNUM:   push si
        mov  di,nbuf+6
        mov  byte [di],0
        mov  bx,10
        xor  ch,ch              ; digits so far
.dig:   xor  dx,dx
        div  bx                 ; AX = value / 10, DX = the last digit
        add  dl,'0'
        dec  di
        mov  [di],dl
        inc  ch
        or   ax,ax
        jnz  .dig
.pad:   cmp  ch,cl
        jae  .out
        dec  di
        mov  byte [di],'0'      ; zeros in front up to CL digits
        inc  ch
        jmp  .pad
.out:   mov  si,di
        call PRINT
        pop  si
        ret

; GETGLY - character AL's 8 rows into glyph.  clobbers AX, CX, DI.
GETGLY: push si
        push ds
        xor  ah,ah
        mov  cl,3
        shl  ax,cl              ; 8 bytes a glyph
        lds  si,[fontp]         ; DS:SI = the font (read before DS moves)
        add  si,ax
        mov  di,glyph           ; ES = our segment
        mov  cx,4
        rep  movsw
        pop  ds
        pop  si
        ret

; PUTCH - character AL.  clobbers AX, BX, CX, DX, DI; keeps SI.
PUTCH:  call GETGLY
        push si
        mov  bx,[trow]
        shl  bx,1
        mov  di,[rowtab+bx]     ; DI = bbuf + y*80
        mov  ax,[tcol]
        shl  ax,1               ; two bytes a character
        add  di,ax
        mov  al,[tclr]
        mov  ah,55h
        mul  ah                 ; colour * 55h: the colour in all 4 pixels
        mov  dl,al              ; DL = the ink
        mov  si,glyph
        mov  bx,EXP4
        mov  cx,8
.row:   lodsb                   ; 8 pixels, a bit each
        mov  ah,al
        shr  al,1
        shr  al,1
        shr  al,1
        shr  al,1               ; the left four
        xlatb                   ; each bit -> two bits
        and  al,dl
        mov  [di],al
        mov  al,ah
        and  al,0Fh             ; the right four
        xlatb
        and  al,dl
        mov  [di+1],al
        add  di,80              ; the next row
        loop .row
        inc  word [tcol]
        pop  si
        ret

; PRBIG - string SI at double size: 16x16 a character, 2 columns each
PRBIG:  lodsb
        or   al,al
        jz   .end
        call GETGLY
        push si
        mov  bx,[trow]
        shl  bx,1
        mov  di,[rowtab+bx]
        mov  ax,[tcol]
        shl  ax,1
        add  di,ax
        mov  al,[tclr]
        mov  ah,55h
        mul  ah                 ; the ink in all 4 pixels
        mov  dl,al
        mov  si,glyph
        mov  bx,DBL4
        mov  cx,8
.row:   lodsb
        mov  ah,al
        push cx
        mov  cx,4               ; four bytes out, two glyph bits each
.q:     rol  ah,1
        rol  ah,1               ; the next two bits to the bottom
        mov  al,ah
        and  al,3
        xlatb                   ; 2 bits -> 4 pixels: each one doubled
        and  al,dl
        mov  [di],al            ; this row...
        mov  [di+80],al         ; ...and the one under it
        inc  di
        loop .q
        pop  cx
        add  di,160-4           ; two rows down, back to the left
        loop .row
        add  word [tcol],2
        pop  si
        jmp  PRBIG
.end:   ret

; ------------------------------------------------------------------
;  CLS, WAITV, BLIT - the back buffer, the retrace, the copy out.
; ------------------------------------------------------------------
CLS:    mov  di,bbuf
        mov  cx,8000            ; 16000 bytes: 320x200 at 4 a byte
        xor  ax,ax
        rep  stosw
        ret

WAITV:  mov  dx,3DAh
.w1:    in   al,dx
        test al,8
        jnz  .w1                ; finish a retrace already running
.w2:    in   al,dx
        test al,8
        jz   .w2                ; the next one begins
        ret

; BLIT - the even rows to B800:0000, the odd ones to B800:2000
BLIT:   push es
        mov  ax,0B800h
        mov  es,ax
        mov  si,bbuf
        xor  di,di
        mov  dx,100             ; 100 pairs of rows
.pair:  mov  cx,40
        rep  movsw              ; an even row
        add  di,2000h-80        ; to the odd bank, the same line
        mov  cx,40
        rep  movsw              ; the odd row under it
        sub  di,2000h           ; back to the even bank, the next line
        dec  dx
        jnz  .pair
        pop  es
        ret

; ------------------------------------------------------------------
;  Data
; ------------------------------------------------------------------
MSGMEM  db 'SOKOBAN needs a whole 64 KB segment of memory.',13,10,'$'
MSGSPR  db 'SOKOBAN: the pictures outgrew SPRMAX.',13,10,'$'
TNAME   db 'SOKOBAN',0
TLINES  db 7,36,1,'CRATES ONTO THE RED MARKS',0
        db 2,116,3,'ARROWS',0
        db 10,116,1,'WALK: UP GOES UP-RIGHT',0
        db 2,124,3,'9 3 1 7',0
        db 10,124,1,'KEYPAD: THE SCREEN',27h,'S WAYS',0
        db 2,132,3,'Z',0
        db 10,132,1,'WHOLE LEVEL OR CLOSE UP',0
        db 2,140,3,'R R',0
        db 10,140,1,'THE LEVEL ANEW',0
        db 2,148,3,'N N P P',0
        db 10,148,1,'NEXT OR PREVIOUS LEVEL',0
        db 2,156,3,'ESC',0
        db 10,156,1,'BACK TO DOS',0
        db 14,172,3,'PRESS ENTER',0
        db 8,188,2,'LEVELS FROM BASE-Z-47',0
        db 0FFh
TLEV    db 'LEVEL ',0
TSLASH  db '/',0
TCRATE  db 'CRATES ',0
TMOVES  db 'MOVES ',0
TSOLV   db ' SOLVED!  +50 EACH ',0
TQ1     db ' R AGAIN: THE LEVEL ANEW ',0
TQ2     db ' N AGAIN: THE NEXT LEVEL ',0
TQ3     db ' P AGAIN: THE PREVIOUS LEVEL ',0
QTAB    dw 0,TQ1,TQ2,TQ3
; the keys that walk: scan code, direction (0 up 1 right 2 down 3 left)
DIRKEYS db 48h,0, 49h,0         ; Up, PgUp (9): up-right on the screen
        db 4Dh,1, 51h,1         ; Right, PgDn (3): down-right
        db 50h,2, 4Fh,2         ; Down, End (1): down-left
        db 4Bh,3, 47h,3         ; Left, Home (7): up-left
DSTEP   dw -NCOL, 1, NCOL, -1   ; a step in grid bytes, per direction
; shirt, cap and trousers: green 1, red 2, yellow 3; look 0 is yours
LOOKS   db 3,2, 2,1, 1,2, 2,3, 1,3, 3,1
; a nibble's 4 bits -> 4 two-bit pixels
EXP4:
rept 16 n:0 { db ((n shr 3) and 1)*0C0h + ((n shr 2) and 1)*30h + ((n shr 1) and 1)*0Ch + (n and 1)*3 }
DBL4    db 00h,0Fh,0F0h,0FFh    ; 2 bits -> 4 pixels, each one twice
; the two zooms: hx, hy, lifts of wall, crate, man, arrow; pictures
ZS      dw 8,4, -6,-7,-9,-12
        dw (6+NLOOK) dup 0
ZB      dw 12,6, -6,-8,-11,-15
        dw (6+NLOOK) dup 0
zoomp   dw ZB                   ; close up to begin with
mep     dw players              ; this machine's man
players db 1,0,0,0              ; you: here, column, row, look 0
        dw 0                    ; score
        db 'YOU',0,0,0,0,0,0    ; name
        db 1 dup 0              ; to PSIZE
        db ((MAXP-1)*PSIZE) dup 0 ; the others, when the wire brings them
level   dw 0
lvw     db 0
lvh     db 0
start   dw 0
nbox    dw 0
ngood   dw 0
moves   dw 0
solved  db 0
soltick dw 0
pend    db 0
pendt   dw 0
now     dw 0
dirty   db 0
camnew  db 0
chg     db 0
pass    db 0
ccol    db 0
crow    db 0
vc      db 0
pslot   db 0
ox      dw 0
oy      dw 0
rowx    dw 0
rowy    dw 0
curx    dw 0
cury    dw 0
cidx    dw 0
cptr    dw 0
pidx    dw 0
pcol    dw 0
wph     dw 0
wpx     dw 0
hpx     dw 0
xmin    dw 0
manx    dw 0
many    dw 0
tcol    dw 0
trow    dw 0
tclr    db 0
fontp   dd 0
glyph   db 8 dup 0
nbuf    db 7 dup 0

        include 'ART.INC'
        include 'LEVELS.INC'

; not in the file, and not zeroed: each is filled before it is read
sprbuf  rb SPRMAX
rowtab  rw 200
gridpad rb NCOL                 ; a zero row above the grid
grid    rb NCOL*NCOL
bbuf    rb 16000                ; the back buffer: 320x200, 4 px a byte
if $ > 0FE00h                   ; the stack falls from FFFEh: leave it
        err                     ;  512 bytes
end if
