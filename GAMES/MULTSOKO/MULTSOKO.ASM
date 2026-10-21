; ==================================================================
;  MULTSOKO.ASM - MULTIPLAY SOKO: crates onto the red marks, in a brick
;  warehouse seen straight down, on a CGA screen: 320x200, four colours.
;      MAKE in GAMES\MULTSOKO, MAKEWIN from Windows (the repository)
;      build A:\MY\MULTSOKO\MULTSOKO.ASM     (the site: FASM, then it runs)
;  ARROWS or W A S D   walk, and push the crate in front of you
;  SPACE  a mine where you stand: it ticks 5 s, then the nine cells round
;         it blast and every man on them stands still for 15 s.  One mine
;         a man; the next is his 60 s after he laid this one.
;  Z      the whole level / close up
;  R R    the level anew      N N, P P   the next, the previous level
;  ESC    back to DOS
;  A crate onto a goal +10, off one -10; a solved level +50 to every
;  man in the warehouse.  The levels are Base-Z-47's (LEVELS.INC), the
;  pictures are text, one character a pixel (ART.INC).  It was first
;  isometric, then three-quarter: prettier, but the players got lost -
;  seen from above nothing stands in front of anything, and an arrow
;  goes where it points.
;  ON THE NETWORK everyone in one room works one warehouse (on the
;  WIRE CITY site: the Games menu, room multsoko; desktop DOSBox: ipxnet).
;  One machine - the lowest name on the wire - keeps the crates, the
;  level, the men and the score, and sends the world whole: the others
;  send it their steps and draw what it sends, so two men never push
;  one crate two ways.  When it goes quiet for 2 s, the next lowest
;  carries on from the world it last drew.  No IPX: alone, the same.
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
G_SEEN  = 32                    ; FREECELL's mark, cleared after it
MAXP    = 8                     ; men in the warehouse
MAXBOX  = 36                    ; crates a level may have: 35 is the most
NLOOK   = 6                     ; shirt and cap pairs (LOOKS)
PFTOP   = 8                     ; the playfield: rows 8..167; above it
PFBOT   = 168                   ;  the level line, under it the players
SOLVT   = 54                    ; ticks the SOLVED banner stays: 3 s
PENDT   = 36                    ; ticks a "press again" waits: 2 s
SPRMAX  = 5120                  ; compiled pictures: 4712 bytes today
FUSE    = 91                    ; ticks a mine ticks: 5 s at 18.2 a second
BLASTT  = 9                     ; ticks the blast shows: half a second
STUNT   = 273                   ; ticks a man in the blast stands: 15 s
COOLT   = 1092                  ; ticks from one mine to the next: 60 s

; a player: the first PWIRE bytes are what the world packet carries
P_PID   = 0                     ; word: his name on the wire
P_COL   = 2                     ; byte: grid column
P_ROW   = 3                     ; byte: grid row
P_LOOK  = 4                     ; byte: 0..NLOOK-1
P_ON    = 5                     ; byte: 1 = in the warehouse
P_SCORE = 6                     ; word, signed
P_NAME  = 8                     ; 8 letters, zeros after a short one
P_STUN  = 16                    ; word: ticks he still stands still
P_COOL  = 18                    ; word: ticks to his next mine (0: he has one)
PWIRE   = 20
P_HEARD = 20                    ; word: the tick he was last heard (the host's)
PSIZE   = 22

; a mine: one a man, in the slot of his number
M_CELL  = 0                     ; word: its cell, row*32 + column; 0FFFFh none
M_LEFT  = 2                     ; word, signed: ticks to the blast; below 0,
MSIZE   = 4                     ;  the blast showing, counting up to 0

; a packet: +0 its kind, +1 PROTO, then by its kind -
;  'H' hello, a player's heartbeat:  +2 his name, 8 letters
;  'M' a step or an order, to the host: +2 what - 0..3 a step (up, right,
;      down, left), 4 the level anew, 5 the next, 6 the previous, 7 a mine
;  'W' the world, the host's, whole: +2 level, +3 solved (0/1), +4 moves
;      (word), +6 crates, +8 MAXP players of PWIRE bytes, then MAXP mines
;      of MSIZE, then the crates' cells as words (row*32 + column)
K_KIND  = 0
K_PROTO = 1
K_ARG   = 2
W_LEVEL = 2
W_SOLVED = 3
W_MOVES = 4
W_NBOX  = 6
W_SLOTS = 8
W_MINES = W_SLOTS + MAXP*PWIRE  ; 168
W_BOXES = W_MINES + MAXP*MSIZE  ; 200

; the network: ENGINE\E_NET.INC, everyone in the room hears everyone
NETSOCK = 5353h                 ; our socket: a palindrome - its byte order
                                ;  cannot bite; never OWL FLY's 5757h/5858h
NETLEN  = W_BOXES + MAXBOX*2    ; every packet the world's size: 272 bytes
NETRX   = 8                     ; listens: seven others and our own echo
PROTO   = 2                     ; in every packet: another version is not ours
                                ;  (2: the mines; 1 had none)
BEAT    = 9                     ; ticks between heartbeats: twice a second
GONE    = 55                    ; ticks unheard: a player has gone (3 s)
HOSTGONE = 36                   ; ticks with no world: the host has gone (2 s)
JOINT   = 36                    ; ticks of listening for a warehouse to join
WIREWT  = 270                   ; ticks of waiting for our address: 15 s
MAXPEER = 16                    ; names heard lately, to choose the next host

; a view: how a cell lands on the screen, its lifts, its pictures.  The
; grid is turned first (TURNED: Q and E), then cell (cc,rr) of the turned
; grid has its picture's top left corner at
;     x = ox + cc*CX + rr*RX,     y = oy + cc*CY + rr*RY
; straight down: CX = the cell's width, RY its height, CY = RX = 0; the
; isometric view (V): CX = 12, CY = 6 - a column on is right and down -
; and RX = -12, RY = 6 - a row on is left and down.
Z_CX    = 0
Z_CY    = 2
Z_RX    = 4
Z_RY    = 6
Z_SW    = 8                     ; a tile's width in px: 8, 16 or 24
Z_SH    = 10                    ; ...and its height: 8, 16 or 12
Z_LWAL  = 12                    ; where each picture's top row goes,
Z_LBOX  = 14                    ;  counted from its tile's own top row
Z_LMAN  = 16
Z_LYOU  = 18
Z_LMIN  = 20
Z_FLR   = 22                    ; the compiled pictures
Z_GOL   = 24
Z_WAL   = 26
Z_BOX   = 28
Z_BOG   = 30
Z_YOU   = 32
Z_MIN   = 34
Z_BLA   = 36
Z_MAN   = 38                    ; NLOOK of them

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
        call NETOPEN            ; the IPX card: CF=1, none - then alone
        mov  ax,0004h           ; mode 4: CGA 320x200, four colours
        int  10h
        call SETPAL
        call TITLE              ; your name; back on Enter (Esc quits)
        call JOIN               ; the room's warehouse, or our own
MAIN:   mov  ax,1680h           ; give the host our time slice: in a
        int  2Fh                ;  browser a tight loop starves the keys
        call NETPOLL            ; the others: their steps, or the world
        call KEYS
        call TIMERS
        cmp  byte [dirty],0     ; turn by turn: draw only what changed
        je   MAIN
        mov  byte [dirty],0
        call RENDER
        call WAITV
        call BLIT
        jmp  MAIN

QUIT:   call NETCLOSE           ; the socket given back, every way out
        mov  ax,0003h           ; text mode 3, as DOS lent it
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
        SPR  FLRS,ZS+Z_FLR,2    ; small: 8 px = 2 bytes a row
        SPR  GOLS,ZS+Z_GOL,2
        SPR  WALS,ZS+Z_WAL,2
        SPR  BOXS,ZS+Z_BOX,2
        SPR  BOGS,ZS+Z_BOG,2
        SPR  YOUS,ZS+Z_YOU,2
        SPR  MINS,ZS+Z_MIN,2
        SPR  BLAS,ZS+Z_BLA,2
        SPR  FLRB,ZB+Z_FLR,4    ; big: 16 px = 4 bytes a row
        SPR  GOLB,ZB+Z_GOL,4
        SPR  WALB,ZB+Z_WAL,4
        SPR  BOXB,ZB+Z_BOX,4
        SPR  BOGB,ZB+Z_BOG,4
        SPR  YOUB,ZB+Z_YOU,4
        SPR  MINB,ZB+Z_MIN,4
        SPR  BLAB,ZB+Z_BLA,4
        SPR  FLRI,ZI+Z_FLR,6    ; isometric: 24 px = 6 bytes a row
        SPR  GOLI,ZI+Z_GOL,6
        SPR  WALI,ZI+Z_WAL,6
        SPR  BOXI,ZI+Z_BOX,6
        SPR  BOGI,ZI+Z_BOG,6
        SPR  YOUI,ZI+Z_YOU,6
        SPR  MINI,ZI+Z_MIN,6
        SPR  BLAI,ZI+Z_BLA,6
        xor  bx,bx              ; the men, one per look, every view
.man:   mov  dx,word [LOOKS+bx] ; DL = shirt, DH = cap and trousers
        mov  [ZS+Z_MAN+bx],di
        mov  si,MANS
        mov  cl,2
        push bx
        call COMPILE
        pop  bx
        mov  [ZB+Z_MAN+bx],di
        mov  si,MANB
        mov  cl,4
        push bx
        call COMPILE
        pop  bx
        mov  [ZI+Z_MAN+bx],di
        mov  si,MANI
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
        mov  di,players         ; nobody in the warehouse yet, and the
        mov  cx,(MAXP+1)*PSIZE/2 ;  ghost behind them cleared too
        xor  ax,ax
        rep  stosw
        jmp  CLRMINES           ; and no mines

; CLRMINES - every mine gone.  clobbers CX, DI.
CLRMINES:
        mov  di,mines
        mov  cx,MAXP
.m:     mov  word [di+M_CELL],0FFFFh
        mov  word [di+M_LEFT],0
        add  di,MSIZE
        loop .m
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
        mov  word [tcol],6      ; 14 big letters, 16 px each: from x 48
        mov  word [trow],14
        mov  byte [tclr],2
        mov  si,TNAME
        call PRBIG
        mov  si,TLINES
        call PRLIST
        call VIGNET
.name:  call NAMELN             ; the name as typed so far
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
        je   .go
        cmp  al,8
        je   .bs
        call NAMECH             ; a letter more, if it is one
        jmp  .name
.bs:    mov  bl,[mylen]
        or   bl,bl
        jz   .wait
        dec  bl                 ; Backspace: the last one off
        mov  [mylen],bl
        xor  bh,bh
        mov  byte [myname+bx],0
        jmp  .name
.go:    cmp  byte [mylen],0
        jne  .ok
        mov  si,TPLAYER         ; nothing typed: PLAYER
        mov  di,myname
        mov  cx,8
        rep  movsb
        mov  byte [mylen],6
.ok:    ret

; NAMELN - "YOUR NAME: " and the name, a cursor, blanks over the rest
NAMELN: mov  word [trow],168
        mov  word [tcol],9
        mov  byte [tclr],3
        mov  si,TNAMEQ
        call PRINT
        mov  byte [tclr],1
        mov  si,myname
        call PRINT
        mov  byte [tclr],3
        mov  al,'_'
        call PUTCH              ; where the next letter goes
        mov  cx,9               ; and blanks over what Backspace took
.b:     push cx
        mov  al,' '
        call PUTCH
        pop  cx
        loop .b
        ret

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

; ------------------------------------------------------------------
;  JOIN - into the room's warehouse.  Wait for the wire to name us (in
;  a browser the address comes seconds after the start), listen JOINT
;  ticks for a host's world and work in it; nobody there - open our own
;  and host it.  No IPX, no name in WIREWT ticks, or Enter while we
;  wait: alone.
; ------------------------------------------------------------------
JOIN:   cmp  byte [net_ok],0
        je   .alone             ; no IPX card here
        call TICK
        mov  [jstart],ax
.addr:  call NETPID             ; AX = our name, 0 until the wire answers
        or   ax,ax
        jnz  .named
        mov  si,TWIRE
        call JOINMSG            ; the wait shows, and moves
        call JKEY               ; Enter: no more waiting - alone
        jc   .alone
        call TICK
        sub  ax,[jstart]        ; ticks waited
        cmp  ax,WIREWT
        jb   .addr
        jmp  .alone
.named: mov  [mypid],ax
        mov  byte [netmode],3   ; joining: the first world heard is ours
        call TICK
        mov  [jstart],ax
        mov  [hostheard],ax
.look:  mov  si,TLOOK
        call JOINMSG
        call NETPOLL
        cmp  byte [netmode],2   ; a host answered: we are in
        je   .done
        call TICK
        sub  ax,[jstart]
        cmp  ax,JOINT
        jb   .look
        mov  byte [netmode],1   ; nobody: our own warehouse, we host it
        mov  ax,[mypid]
        mov  [hostpid],ax
        jmp  .fresh
.alone: mov  byte [netmode],0
        mov  word [mypid],0
.fresh: mov  word [level],0
        call LOADLEV
        call ADDME              ; our man, at the start
        mov  byte [netdirty],1
.done:  mov  byte [dirty],1
        mov  byte [camnew],1
        ret

; JOINMSG - line SI on the title, a spinner after it, on the screen
JOINMSG:push si
        mov  ax,1680h
        int  2Fh                ; yield: a wait must not starve the host
        pop  si
        mov  dx,180
        call BANNER
        call TICK
        mov  cl,2
        shr  ax,cl              ; a quarter of a second a step
        and  ax,3
        mov  bx,ax
        mov  al,[SPIN+bx]
        call PUTCH
        call WAITV
        jmp  BLIT

; JKEY - CF=1: Enter was pressed; Esc quits; other keys are dropped
JKEY:   mov  ah,1
        int  16h
        jz   .none
        mov  ah,0
        int  16h
        cmp  al,27
        jne  .ent
        jmp  QUIT
.ent:   cmp  al,13
        jne  .none
        stc
        ret
.none:  clc
        ret

; ADDME - our man into the warehouse, with our name
ADDME:  mov  ax,[mypid]
        call SLOTOF
        jc   .full
        mov  [mep],bx
        lea  di,[bx+P_NAME]
        mov  si,myname
        mov  cx,8
        rep  movsb
.full:  ret

; TICK - AX = the BIOS tick, 18.2 a second
TICK:   push ds
        xor  ax,ax
        mov  ds,ax
        mov  ax,[046Ch]
        pop  ds
        ret

; VIGNET - a man, a crate, a goal before a wall: the game in one row
VIGNET: mov  word [ox],112      ; centres the 6 cells: 96 px wide
        mov  word [oy],72
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
        mov  ax,0101h           ; a mine ticking behind him: column 1
        mov  bx,[zoomp]
        mov  si,[bx+Z_MIN]
        mov  cx,[bx+Z_LMIN]
        call PUTAT
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
;  NEWLEV - level [level], and every man in it again: the host's and
;  the lone player's.  LOADLEV - the level alone, its crates as they
;  start; a client loads it so, then puts the host's crates on it.
; ------------------------------------------------------------------
NEWLEV: call LOADLEV
        call CLRMINES           ; the mines stay with the old floor
        mov  bx,players
.s:     mov  word [bx+P_STUN],0 ; and nobody starts a level standing still
        add  bx,PSIZE
        cmp  bx,players+MAXP*PSIZE
        jb   .s
        jmp  PLACEALL

LOADLEV:mov  di,gridpad         ; a zero row in front, then the grid
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
        mov  si,ghost           ; the ghost - a camera with no man - at
        call SETPOS             ;  the start, for a player not in yet
        mov  byte [loaded],1
        mov  byte [camnew],1
        mov  byte [dirty],1
        ret

; PLACEALL - every man in the warehouse onto the free floor nearest the
; start, in slot order: the first on the start itself
PLACEALL:
        mov  si,players
.p:     cmp  byte [si+P_ON],0
        je   .n
        push si
        call FREECELL           ; BX -> his cell
        pop  si
        jc   .full
        or   byte [bx],G_MAN
        call SETPOS
        jmp  .n
.full:  mov  byte [si+P_ON],0   ; no floor left for him: out
.n:     add  si,PSIZE
        cmp  si,players+MAXP*PSIZE
        jb   .p
        mov  byte [netdirty],1
        ret

; FREECELL - BX -> the free floor cell nearest the start, the floor
; walked breadth first; CF=1: none.  clobbers AX, CX, DX, SI, DI.
FREECELL:
        mov  si,bfsq            ; SI: the queue's head, DI: its tail
        mov  di,bfsq
        mov  bx,[start]
        or   byte [bx],G_SEEN
        mov  [di],bx
        add  di,2
.take:  cmp  si,di
        jae  .none              ; all the floor walked, none free
        mov  bx,[si]
        add  si,2
        test byte [bx],G_WALL or G_BOX or G_MAN
        jz   .found
        mov  dx,-1              ; its neighbours: left,
        call .near
        mov  dx,1               ;  right,
        call .near
        mov  dx,-NCOL           ;  up,
        call .near
        mov  dx,NCOL            ;  down
        call .near
        jmp  .take
.near:  push bx
        add  bx,dx              ; the neighbour
        mov  al,[bx]
        test al,G_FLOOR
        jz   .skip              ; a wall, or the void
        test al,G_SEEN
        jnz  .skip              ; queued already
        or   byte [bx],G_SEEN
        mov  [di],bx
        add  di,2
.skip:  pop  bx
        ret
.found: call .unsee
        clc
        ret
.none:  call .unsee
        stc
        ret
.unsee: push bx
        mov  bx,grid
        mov  cx,NCOL*NCOL
.u:     and  byte [bx],0FFh xor G_SEEN
        inc  bx
        loop .u
        pop  bx
        ret

; SLOTOF - player AX's slot: BX.  A name not in the warehouse gets the
; first free slot, the look of its number, the free cell nearest the
; start, 0 points and the name PLAYER until his hello brings his own.
; CF=1: eight men are in already.  clobbers AX, CX, DX, SI, DI.
SLOTOF: mov  bx,players
.find:  cmp  byte [bx+P_ON],0
        je   .nf
        cmp  [bx+P_PID],ax
        je   .have
.nf:    add  bx,PSIZE
        cmp  bx,players+MAXP*PSIZE
        jb   .find
        mov  bx,players         ; a newcomer: the first free slot
        xor  cl,cl              ; its number, for its look
.free:  cmp  byte [bx+P_ON],0
        je   .new
        add  bx,PSIZE
        inc  cl
        cmp  bx,players+MAXP*PSIZE
        jb   .free
        stc
        ret
.new:   mov  [bx+P_PID],ax
        mov  byte [bx+P_ON],1
        mov  word [bx+P_SCORE],0
        mov  al,cl
        cmp  al,NLOOK
        jb   .look
        sub  al,NLOOK           ; slots 6 and 7 wear looks 0 and 1 again
.look:  mov  [bx+P_LOOK],al
        lea  di,[bx+P_NAME]
        mov  si,TPLAYER         ; PLAYER, zeros to 8
        mov  cx,8
        rep  movsb
        call TICK
        mov  [bx+P_HEARD],ax
        push bx
        call FREECELL           ; BX -> his cell
        mov  si,bx
        pop  bx
        jc   .out
        or   byte [si],G_MAN
        xchg bx,si              ; SETPOS: SI the player, BX the cell
        call SETPOS
        xchg bx,si
        mov  byte [netdirty],1
        mov  byte [dirty],1
.have:  clc
        ret
.out:   mov  byte [bx+P_ON],0   ; no free floor: not in after all
        stc
        ret

; DROPMAN - player BX gone: his man off the floor, his slot free
DROPMAN:mov  al,[bx+P_ROW]
        xor  ah,ah
        mov  cl,5
        shl  ax,cl              ; row * 32
        add  al,[bx+P_COL]      ; + column: no carry, it is < 32
        add  ax,grid
        mov  si,ax
        and  byte [si],0FFh xor G_MAN
        mov  byte [bx+P_ON],0
        mov  byte [netdirty],1
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
        jne  .view
        jmp  QUIT
.view:  mov  bl,al
        or   bl,20h             ; letters to lower case
        cmp  bl,'z'             ; the view's keys work at any time
        je   .zoom
        cmp  bl,'v'
        je   .iso
        cmp  bl,'q'
        je   .ccw
        cmp  bl,'e'
        je   .cw
        cmp  byte [solved],0
        jne  .end               ; the banner is up: the next level comes
        cmp  ah,39h             ; Space: a mine
        je   .mine
        mov  bx,DIRKEYS
        mov  cx,8
.dk:    cmp  ah,[bx]
        je   .dir
        add  bx,2
        loop .dk
        or   al,20h
        xor  bx,bx
        cmp  al,'r'
        je   .q1
        cmp  al,'n'
        je   .q2
        cmp  al,'p'
        je   .q3
.end:   ret
.dir:   mov  al,[bx+1]          ; 0 up, 1 right, 2 down, 3 left - as the
        sub  al,[turn]          ;  screen shows it; minus the turn: as
        and  al,3               ;  the grid has it (mod 4)
        cmp  byte [netmode],2
        jne  MOVE               ; alone or the host: our own step
        jmp  SENDM              ; a client asks the host for it
.mine:  cmp  byte [netmode],2
        je   .mreq
        mov  si,[mep]
        cmp  byte [si+P_ON],0
        je   .end
        jmp  PLACEMINE
.mreq:  mov  al,7
        jmp  SENDM
.zoom:  cmp  word [zoomp],ZI
        je   .end               ; isometric: one size
        xor  word [zoomp],ZS xor ZB  ; flip between the two sizes
        mov  ax,[zoomp]
        mov  [topz],ax          ; the size V comes back to
        jmp  .new
.iso:   mov  ax,ZI
        cmp  [zoomp],ax
        jne  .set
        mov  ax,[topz]          ; isometric already: straight down again
.set:   mov  [zoomp],ax
        jmp  .new
.ccw:   dec  byte [turn]        ; a quarter turn back
        jmp  .tn
.cw:    inc  byte [turn]        ; a quarter turn on
.tn:    and  byte [turn],3      ; four of them
.new:   mov  byte [camnew],1
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
        cmp  byte [netmode],2
        jne  LEVACT             ; alone or the host: ours to do
        mov  al,bl
        add  al,3               ; 4 anew, 5 next, 6 previous
        jmp  SENDM              ; a client: the host's to do

; LEVACT - BL = 1 the level anew, 2 the next, 3 the previous
LEVACT: mov  ax,[level]
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
MOVE:   mov  si,[mep]
        cmp  byte [si+P_ON],0
        je   .no                ; no man of ours in the warehouse yet
        xor  ah,ah
        shl  ax,1               ; a word per direction
        mov  bx,ax
        mov  dx,[DSTEP+bx]      ; DX = the step in grid bytes
        jmp  STEP
.no:    ret

; STEP - player SI one step of DX grid bytes (the host's, for anyone)
STEP:   cmp  word [si+P_STUN],0
        jne  .no                ; standing still after a blast: no step
        mov  al,[si+P_ROW]
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
        mov  byte [netdirty],1  ; the room hears of it at the next tick
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
TIMERS: call TICK               ; the BIOS tick, 18.2 a second
        mov  [now],ax
        cmp  byte [netmode],2
        je   .pend              ; a client: the host keeps every clock
        call TICKER             ; fuses, blasts, men standing still
        mov  ax,[now]
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
;  TICKER - the host's clocks (and the lone player's), run on the ticks
;  since the last frame: each man's standing still and his wait for the
;  next mine count down to 0; a fuse burns down to its blast; a blast
;  fades.  While any clock runs, the screen and the world go out again
;  twice a second, so every count moves on every machine.
; ------------------------------------------------------------------
TICKER: mov  ax,[now]
        mov  dx,ax
        sub  dx,[lastt]         ; ticks since the last frame
        jz   .ret
        mov  [lastt],ax
        cmp  dx,36
        jbe  .d
        mov  dx,36              ; after a stall: two seconds at most
.d:     mov  byte [act],0
        mov  bx,players
.p:     cmp  byte [bx+P_ON],0
        je   .pn
        mov  ax,[bx+P_STUN]
        call .down
        mov  [bx+P_STUN],ax
        mov  ax,[bx+P_COOL]
        call .down
        mov  [bx+P_COOL],ax
.pn:    add  bx,PSIZE
        cmp  bx,players+MAXP*PSIZE
        jb   .p
        mov  si,mines
.m:     cmp  word [si+M_CELL],0FFFFh
        je   .mn
        mov  byte [act],1
        mov  ax,[si+M_LEFT]
        or   ax,ax
        js   .fade
        sub  ax,dx              ; the fuse burns
        jg   .burn
        push dx
        push si
        call BLAST              ; it is out: the nine cells
        pop  si
        pop  dx
        mov  word [si+M_LEFT],-BLASTT
        jmp  .mn
.burn:  mov  [si+M_LEFT],ax
        jmp  .mn
.fade:  add  ax,dx              ; the blast fades
        js   .fd
        mov  word [si+M_CELL],0FFFFh  ; gone
        mov  byte [netdirty],1
        mov  byte [dirty],1
        jmp  .mn
.fd:    mov  [si+M_LEFT],ax
.mn:    add  si,MSIZE
        cmp  si,mines+MAXP*MSIZE
        jb   .m
        cmp  byte [act],0
        je   .ret
        mov  ax,[now]
        sub  ax,[lastsec]
        cmp  ax,BEAT            ; twice a second while a clock runs
        jb   .ret
        mov  ax,[now]
        mov  [lastsec],ax
        mov  byte [dirty],1
        mov  byte [netdirty],1
.ret:   ret
.down:  or   ax,ax
        jz   .z                 ; not running
        mov  byte [act],1
        sub  ax,dx              ; down by the ticks...
        jnc  .z
        xor  ax,ax              ; ...to 0, never under
.z:     ret

; BLAST - mine SI goes off: every man on its nine cells stands still
; STUNT ticks, whoever laid it.  clobbers AX, BX, CX.
BLAST:  mov  ax,[si+M_CELL]
        mov  ch,al
        and  ch,NCOL-1          ; CH = its column
        mov  cl,5
        shr  ax,cl
        mov  cl,al              ; CL = its row
        mov  bx,players
.p:     cmp  byte [bx+P_ON],0
        je   .n
        mov  al,[bx+P_COL]
        sub  al,ch
        inc  al                 ; -1, 0, +1 away become 0, 1, 2
        cmp  al,2
        ja   .n                 ; (and anything further, either way, more)
        mov  al,[bx+P_ROW]
        sub  al,cl
        inc  al
        cmp  al,2
        ja   .n
        mov  word [bx+P_STUN],STUNT   ; caught
.n:     add  bx,PSIZE
        cmp  bx,players+MAXP*PSIZE
        jb   .p
        mov  byte [netdirty],1
        mov  byte [dirty],1
        ret

; PLACEMINE - player SI lays his mine where he stands: if he is not
; standing still, has a mine (his wait is over) and his last one is gone.
; Its place is the mines' slot of his number.  clobbers AX, BX, DX, DI.
PLACEMINE:
        cmp  word [si+P_STUN],0
        jne  .no
        cmp  word [si+P_COOL],0
        jne  .no
        mov  ax,si
        sub  ax,players
        xor  dx,dx
        mov  bx,PSIZE
        div  bx                 ; AX = his slot number  (DX: 0)
        shl  ax,1
        shl  ax,1               ; * MSIZE: 4 bytes a mine
        add  ax,mines
        mov  di,ax
        cmp  word [di+M_CELL],0FFFFh
        jne  .no                ; his last one still burns
        mov  al,[si+P_ROW]
        xor  ah,ah
        mov  cl,5
        shl  ax,cl              ; row * 32
        add  al,[si+P_COL]      ; + column
        mov  [di+M_CELL],ax
        mov  word [di+M_LEFT],FUSE
        mov  word [si+P_COOL],COOLT   ; the next one in a minute
        mov  byte [netdirty],1
        mov  byte [dirty],1
.no:    ret

; ------------------------------------------------------------------
;  TURNED - the grid as the view turns it (Q, E): [turn] 0..3 quarter
;  turns clockwise.  Out: tcols, trows - the turned grid's columns and
;  rows; tstart - the cell (row*32 + column) at its top left; tdcol,
;  tdrow - what a column on and a row on add to a cell.  The cell at
;  turned (cc,rr) is, for turn 0: (cc, rr); 1: (rr, h-1-cc);
;  2: (w-1-cc, h-1-rr); 3: (w-1-rr, cc) - as (column, row).
; ------------------------------------------------------------------
TURNED: mov  al,[lvw]
        mov  ah,[lvh]
        mov  bl,[turn]
        cmp  bl,1
        je   .t1
        cmp  bl,2
        je   .t2
        cmp  bl,3
        je   .t3
        mov  [tcols],al         ; turn 0: as it is
        mov  [trows],ah
        mov  word [tstart],0
        mov  word [tdcol],1
        mov  word [tdrow],NCOL
        ret
.t1:    mov  [tcols],ah         ; a quarter: h columns of w rows
        mov  [trows],al
        mov  al,ah
        xor  ah,ah
        dec  ax                 ; h-1
        mov  cl,5
        shl  ax,cl              ; (h-1)*32: the bottom left cell
        mov  [tstart],ax
        mov  word [tdcol],-NCOL ; a column on: a row up
        mov  word [tdrow],1     ; a row on: a column right
        ret
.t2:    mov  [tcols],al         ; a half: upside down
        mov  [trows],ah
        mov  bl,al              ; BL = w
        mov  al,ah
        xor  ah,ah
        dec  ax
        mov  cl,5
        shl  ax,cl              ; (h-1)*32...
        add  al,bl
        dec  ax                 ; ...+ w-1: the bottom right cell
        mov  [tstart],ax
        mov  word [tdcol],-1
        mov  word [tdrow],-NCOL
        ret
.t3:    mov  [tcols],ah         ; three quarters
        mov  [trows],al
        xor  ah,ah
        dec  ax                 ; w-1: the top right cell
        mov  [tstart],ax
        mov  word [tdcol],NCOL  ; a column on: a row down
        mov  word [tdrow],-1    ; a row on: a column left
        ret

; CELLXY - where cell AX (row*32 + column) lands: AX = x, DX = y, before
; ox and oy are added - the grid turned, then projected.  TURNED first.
; clobbers BX, CX.
CELLXY: mov  bl,al
        and  bl,NCOL-1          ; BL = c
        mov  cl,5
        shr  ax,cl
        mov  bh,al              ; BH = r
        mov  al,[turn]
        cmp  al,1
        je   .t1
        cmp  al,2
        je   .t2
        cmp  al,3
        je   .t3
        mov  cl,bl              ; CL = cc, CH = rr
        mov  ch,bh
        jmp  .proj
.t1:    mov  cl,[lvh]
        dec  cl
        sub  cl,bh              ; cc = h-1-r
        mov  ch,bl              ; rr = c
        jmp  .proj
.t2:    mov  cl,[lvw]
        dec  cl
        sub  cl,bl              ; cc = w-1-c
        mov  ch,[lvh]
        dec  ch
        sub  ch,bh              ; rr = h-1-r
        jmp  .proj
.t3:    mov  cl,bh              ; cc = r
        mov  ch,[lvw]
        dec  ch
        sub  ch,bl              ; rr = w-1-c
.proj:  mov  [tcc],cl
        mov  [trr],ch
        mov  bx,[zoomp]
        mov  al,[tcc]
        xor  ah,ah
        imul word [bx+Z_CX]     ; cc*CX  (DX goes)
        mov  cx,ax
        mov  al,[trr]
        xor  ah,ah
        imul word [bx+Z_RX]
        add  cx,ax              ; x = cc*CX + rr*RX
        mov  al,[tcc]
        xor  ah,ah
        imul word [bx+Z_CY]
        mov  [tyy],ax
        mov  al,[trr]
        xor  ah,ah
        imul word [bx+Z_RY]
        add  ax,[tyy]           ; y = cc*CY + rr*RY
        mov  dx,ax
        mov  ax,cx
        ret

; ------------------------------------------------------------------
;  CAMERA - ox, oy: where the turned grid's corner lands.  A level that
;  fits is centred; a bigger one follows your man, who walks the middle
;  half of the screen freely before it scrolls.  The turned level spans
;  x from xmin = (trows-1)*RX (left of 0 only in the isometric view) to
;  (tcols-1)*CX + SW, and y from the walls' lift to (tcols-1)*CY +
;  (trows-1)*RY + SH.
; ------------------------------------------------------------------
CAMERA: call TURNED
        mov  bx,[zoomp]
        mov  al,[trows]
        xor  ah,ah
        dec  ax
        imul word [bx+Z_RX]     ; (trows-1)*RX: 0, or the left corner
        mov  [xmin],ax
        mov  al,[tcols]
        xor  ah,ah
        dec  ax
        imul word [bx+Z_CX]     ; (tcols-1)*CX
        add  ax,[bx+Z_SW]       ; + a tile: the right edge
        sub  ax,[xmin]
        mov  [wpx],ax           ; the width in px
        mov  al,[tcols]
        xor  ah,ah
        dec  ax
        imul word [bx+Z_CY]
        mov  cx,ax
        mov  al,[trows]
        xor  ah,ah
        dec  ax
        imul word [bx+Z_RY]
        add  ax,cx
        add  ax,[bx+Z_SH]       ; the bottom edge
        sub  ax,[bx+Z_LWAL]     ; and the walls stand above the top
        mov  [hpx],ax
        mov  ax,[bx+Z_LWAL]
        neg  ax
        mov  [wtop],ax          ; how high above oy they rise
        mov  si,[mep]
        mov  al,[si+P_ROW]
        xor  ah,ah
        mov  cl,5
        shl  ax,cl              ; row * 32
        add  al,[si+P_COL]      ; + column: his cell
        call CELLXY             ; AX = x, DX = y of his tile
        mov  bx,[zoomp]
        mov  cx,[bx+Z_SW]
        shr  cx,1               ; + half a tile: his middle
        add  ax,cx
        mov  [manx],ax
        mov  [many],dx
; across
        mov  ax,[wpx]
        cmp  ax,320
        ja   .xfol
        mov  ax,320
        sub  ax,[wpx]
        sar  ax,1               ; the margin either side...
        sub  ax,[xmin]          ; ...and ox = margin - xmin
        jmp  .xset
.xfol:  mov  ax,[ox]
        cmp  byte [camnew],0
        je   .xkeep
        mov  ax,160
        sub  ax,[manx]          ; a new level or view: the man in the middle
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
.xc2:   mov  dx,320             ; and the right edge:
        sub  dx,[xmin]          ;  ox >= 320 - (xmin + width)
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
        add  ax,PFTOP
        add  ax,[wtop]          ; the back walls' tops are wtop over oy
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
.yc:    mov  dx,PFTOP           ; the top edge stays off:
        add  dx,[wtop]          ;  oy - wtop <= PFTOP
        cmp  ax,dx
        jle  .yc2
        mov  ax,dx
.yc2:   mov  dx,PFBOT           ; the bottom too:
        add  dx,[wtop]          ;  oy - wtop + hpx >= PFBOT
        sub  dx,[hpx]
        cmp  ax,dx
        jge  .yset
        mov  ax,dx
.yset:  mov  [oy],ax
        mov  byte [camnew],0
        ret

; ------------------------------------------------------------------
;  RENDER - the warehouse into the back buffer, the turned grid row by
;  row, back to front: first every floor, then the walls, mines, crates
;  and men - a tile further down the screen is nearer, so it is drawn
;  later, and in the isometric view what stands up covers the bottom of
;  what is behind.  Seen straight down nothing overlaps at all.  Then
;  the blasts and the numbers over everything (OVERLAY), then the HUD.
; ------------------------------------------------------------------
RENDER: call CLS
        call CAMERA             ; (it turns the grid: TURNED)
        mov  byte [pass],0
.pass:  mov  ax,[ox]            ; the turned row 0 starts at the origin
        mov  [rowx],ax
        mov  ax,[oy]
        mov  [rowy],ax
        mov  ax,[tstart]
        add  ax,grid
        mov  [cidx],ax
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
.nowal: mov  ax,[cptr]
        sub  ax,grid
        call MINEAT             ; a mine ticking here?
        jc   .nomin
        mov  bx,[zoomp]
        mov  si,[bx+Z_MIN]
        mov  cx,[bx+Z_LMIN]
        call DRAWAT
.nomin: mov  bx,[cptr]
        mov  al,[bx]
        mov  bx,[zoomp]
        test al,G_BOX
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
        mov  ax,[bx+Z_CX]
        add  [curx],ax          ; a column on
        mov  ax,[bx+Z_CY]
        add  [cury],ax
        mov  ax,[tdcol]
        add  [cptr],ax
        inc  byte [ccol]
        mov  al,[ccol]
        cmp  al,[tcols]
        jb   .cell
        mov  ax,[bx+Z_RX]
        add  [rowx],ax          ; a row on
        mov  ax,[bx+Z_RY]
        add  [rowy],ax
        mov  ax,[tdrow]
        add  [cidx],ax
        inc  byte [crow]
        mov  al,[crow]
        cmp  al,[trows]
        jb   .row
        inc  byte [pass]
        cmp  byte [pass],2
        jb   .pass
        call OVERLAY
        jmp  HUD

; MINEAT - a mine ticking on cell AX?  CF=0: yes, SI -> it.  keeps AX.
MINEAT: mov  si,mines
.m:     cmp  [si+M_CELL],ax
        jne  .n
        cmp  word [si+M_LEFT],0
        jg   .yes               ; still ticking (below 0: the blast)
.n:     add  si,MSIZE
        cmp  si,mines+MAXP*MSIZE
        jb   .m
        stc
        ret
.yes:   clc
        ret

; DRAWMEN - every man standing on cell [cptr]; your marker over yours
DRAWMEN:mov  ax,[cptr]
        sub  ax,grid
        mov  [ccell],ax         ; the cell: row*32 + column
        mov  word [pidx],players
.p:     mov  bx,[pidx]
        cmp  byte [bx+P_ON],0
        je   .n
        mov  al,[bx+P_ROW]
        xor  ah,ah
        mov  cl,5
        shl  ax,cl              ; row * 32
        add  al,[bx+P_COL]      ; + column
        cmp  ax,[ccell]
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

; ------------------------------------------------------------------
;  OVERLAY - over the whole warehouse: each blast on its nine cells,
;  each mine's seconds to go on it, and over every man standing still
;  his seconds to go - in the small view only the blasts: a digit is as
;  big as a cell there, and the list under the floor has every count.
; ------------------------------------------------------------------
OVERLAY:mov  word [pidx],mines
.m:     mov  si,[pidx]
        mov  ax,[si+M_CELL]
        cmp  ax,0FFFFh
        je   .mn
        mov  dx,[si+M_LEFT]
        or   dx,dx
        jns  .fuse
        mov  [ccell],ax         ; a blast: its nine cells
        mov  word [boff],-NCOL-1 ; from up-left...
.b:     mov  ax,[ccell]
        add  ax,[boff]          ; one of the nine
        cmp  ax,NCOL*NCOL
        jae  .bn                ; off the grid
        mov  bx,ax
        test byte [grid+bx],G_FLOOR or G_WALL
        jz   .bn                ; the void: nothing to light
        call CELLXY
        add  ax,[ox]
        add  dx,[oy]
        mov  bx,ax
        mov  si,[zoomp]
        mov  si,[si+Z_BLA]
        call DRAWSPR
.bn:    inc  word [boff]        ; the next of the nine
        mov  ax,[boff]
        and  ax,NCOL-1
        cmp  ax,2               ; past +1 in the row?
        jne  .bc
        add  word [boff],NCOL-3 ; the next row, one left
.bc:    cmp  word [boff],NCOL+1
        jle  .b
        jmp  .mn
.fuse:  cmp  word [zoomp],ZS
        je   .mn
        call CELLXY             ; a ticking mine: its seconds on it
        mov  bx,[zoomp]
        add  dx,[bx+Z_LMIN]
        mov  cx,[bx+Z_SH]
        sub  cx,8
        sar  cx,1
        add  dx,cx              ; the middle of its tile, down
        add  dx,[oy]
        mov  cx,[bx+Z_SW]
        shr  cx,1
        add  ax,cx              ; and across
        add  ax,[ox]
        mov  bx,ax
        mov  si,[pidx]
        mov  ax,[si+M_LEFT]
        call SECS
        mov  cl,3               ; yellow
        call OVNUM
.mn:    add  word [pidx],MSIZE
        cmp  word [pidx],mines+MAXP*MSIZE
        jb   .m
        cmp  word [zoomp],ZS
        je   .done
        mov  word [pidx],players ; the men standing still: their seconds
.p:     mov  si,[pidx]
        cmp  byte [si+P_ON],0
        je   .pn
        cmp  word [si+P_STUN],0
        je   .pn
        mov  al,[si+P_ROW]
        xor  ah,ah
        mov  cl,5
        shl  ax,cl
        add  al,[si+P_COL]
        call CELLXY
        mov  bx,[zoomp]
        add  dx,[bx+Z_LMAN]     ; at the top of his picture
        add  dx,[oy]
        mov  cx,[bx+Z_SW]
        shr  cx,1
        add  ax,cx
        add  ax,[ox]
        mov  bx,ax
        mov  si,[pidx]
        mov  ax,[si+P_STUN]
        call SECS
        mov  cl,2               ; red
        call OVNUM
.pn:    add  word [pidx],PSIZE
        cmp  word [pidx],players+MAXP*PSIZE
        jb   .p
.done:  ret

; SECS - AX ticks as whole seconds, rounded up: (AX + 17) / 18
; (18.2 a second: 91 ticks are 5).  AX < 4600.  clobbers CL.
SECS:   add  ax,17
        mov  cl,18
        div  cl                 ; AL = seconds, AH = the rest
        xor  ah,ah
        ret

; OVNUM - number AX (1..99) on the playfield, centred on x BX (a multiple
; of 4), its top at y DX, in colour CL; nothing outside the playfield.
OVNUM:  mov  [tclr],cl
        mov  [trow],dx
        cmp  dx,PFTOP
        jl   .no
        cmp  dx,PFBOT-8
        jg   .no
        mov  cl,10
        div  cl                 ; AL = tens, AH = ones (AX < 100)
        push ax
        mov  ax,bx
        sub  ax,4
        sar  ax,1
        sar  ax,1               ; the byte column of one digit centred
        mov  [txb],ax
        pop  ax
        or   al,al
        jz   .one
        dec  word [txb]         ; two digits: half a character left
        push ax
        add  al,'0'
        call PUTCHB
        pop  ax
        add  word [txb],2
.one:   mov  al,ah
        add  al,'0'
        jmp  PUTCHB
.no:    ret

; PUTAT - a picture on cell AL = column, AH = row of the current view,
; not turned (the title's picture).  in: SI picture, CX lift.
; clobbers everything but BP.
PUTAT:  push cx
        push si
        mov  [tcc],al
        mov  [trr],ah
        mov  bx,[zoomp]
        xor  ah,ah
        imul word [bx+Z_CX]     ; c*CX  (DX goes)
        mov  cx,ax
        mov  al,[trr]
        xor  ah,ah
        imul word [bx+Z_RX]
        add  ax,cx              ; x = c*CX + r*RX
        add  ax,[ox]
        mov  [curx],ax
        mov  al,[tcc]
        xor  ah,ah
        imul word [bx+Z_CY]
        mov  cx,ax
        mov  al,[trr]
        xor  ah,ah
        imul word [bx+Z_RY]
        add  ax,cx              ; y = c*CY + r*RY
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
        je   .in
        mov  si,TSOLV
        mov  dx,80
        call BANNER
.in:    cmp  byte [netmode],2
        jne  .ask
        cmp  word [mep],ghost   ; a client the host has not let in yet
        jne  .ask
        mov  si,TCOMING
        mov  dx,96
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
        call PNAME
        mov  ax,[pcol]
        add  ax,11              ; a star by the host's name
        mov  [tcol],ax
        cmp  byte [netmode],0
        je   .score             ; alone: no host to mark
        mov  bx,[pidx]
        mov  ax,[bx+P_PID]
        cmp  ax,[hostpid]
        jne  .score
        mov  byte [tclr],2
        mov  al,'*'
        call PUTCH
.score: mov  ax,[pcol]
        add  ax,12              ; the score in its own column
        mov  [tcol],ax
        mov  byte [tclr],3
        mov  bx,[pidx]
        mov  ax,[bx+P_SCORE]
        mov  cl,1
        call PSNUM
        mov  ax,[pcol]          ; his clocks: Z15 standing still, M42 the
        add  ax,16              ;  seconds to his next mine, M he has one
        mov  [tcol],ax
        mov  bx,[pidx]
        mov  ax,[bx+P_STUN]
        or   ax,ax
        jz   .cool
        mov  byte [tclr],2
        mov  al,'Z'
        call PUTCH
        mov  bx,[pidx]
        mov  ax,[bx+P_STUN]
        jmp  .secs
.cool:  mov  ax,[bx+P_COOL]
        or   ax,ax
        jz   .ready
        mov  byte [tclr],1
        mov  al,'M'
        call PUTCH
        mov  bx,[pidx]
        mov  ax,[bx+P_COOL]
.secs:  call SECS
        mov  cl,1
        call PNUM
        jmp  .slot
.ready: mov  byte [tclr],3
        mov  al,'M'
        call PUTCH
.slot:  inc  byte [pslot]
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

; PNAME - a player's name at SI: up to 8 letters, to the first zero
PNAME:  mov  cx,8
.c:     lodsb
        or   al,al
        jz   .end
        push cx
        call PUTCH
        pop  cx
        loop .c
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

; PUTCH - character AL at [tcol], then tcol on one.  PUTCHB - character
; AL at byte column [txb] (4 px each), nothing if that is off the row.
; Both at y [trow], in [tclr].  clobber AX, BX, CX, DX, DI; keep SI.
PUTCH:  push ax
        mov  ax,[tcol]
        shl  ax,1               ; two bytes a character
        mov  [txb],ax
        pop  ax
        call PUTCHB
        inc  word [tcol]
        ret
PUTCHB: cmp  word [txb],78
        jbe  .on                ; unsigned: a negative column is huge too
        ret
.on:    call GETGLY
        push si
        mov  bx,[trow]
        shl  bx,1
        mov  di,[rowtab+bx]     ; DI = bbuf + y*80
        add  di,[txb]
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
;  NETPOLL - once a frame: every packet that came, then the clocks -
;  players not heard, a host gone quiet, our own heartbeat.
;  The host takes 'H' and 'M' from anyone: a name it has not got gets a
;  man.  Everyone takes 'W': a client from its host or a lower name; a
;  host from a LOWER name only, and then works in that one's warehouse -
;  two that started alone at once end as one.
; ------------------------------------------------------------------
NETPOLL:cmp  byte [netmode],0
        jne  .rx
        ret                     ; alone: no wire to read
.rx:    call NETRECV            ; CF=0: DI -> NETIN, AX = who sent it
        jc   .clocks
        cmp  byte [di+K_PROTO],PROTO
        jne  .rx                ; another version of the game: not ours
        mov  [sender],ax
        call PEER               ; heard now: a candidate to host
        mov  al,[di+K_KIND]
        cmp  al,'W'
        je   .world
        cmp  byte [netmode],1
        jne  .rx                ; hellos and steps are the host's
        mov  ax,[sender]
        push di
        call SLOTOF             ; BX = his slot; a newcomer gets a man
        pop  di
        jc   .rx                ; eight in already: he can only watch
        call TICK
        mov  [bx+P_HEARD],ax
        mov  al,[di+K_KIND]
        cmp  al,'H'
        je   .hello
        cmp  al,'M'
        jne  .rx
        mov  al,[di+K_ARG]      ; a step or an order
        cmp  al,4
        jb   .step
        cmp  al,7
        je   .mine
        cmp  al,6
        ja   .rx                ; no such order: dropped
        sub  al,3               ; 1 anew, 2 next, 3 previous
        mov  bl,al
        call LEVACT
        jmp  .rx
.mine:  mov  si,bx              ; his mine, if he has one
        call PLACEMINE
        jmp  .rx
.step:  cmp  byte [solved],0
        jne  .rx                ; the banner is up: no more steps
        xor  ah,ah
        shl  ax,1               ; a word per direction
        mov  si,ax
        mov  dx,[DSTEP+si]
        mov  si,bx              ; STEP: SI = the player
        call STEP
        jmp  .rx
.hello: lea  si,[di+K_ARG]      ; his name, made printable
        lea  di,[bx+P_NAME]
        call COPYNAME
        mov  byte [netdirty],1
        jmp  .rx
.world: mov  ax,[sender]
        cmp  byte [netmode],1
        jne  .wc
        cmp  ax,[mypid]         ; two hosts: the lower name keeps it
        jae  .rx
        jmp  .take              ; it is lower: we work in its warehouse
.wc:    cmp  byte [netmode],3
        je   .take              ; joining: the first world heard
        cmp  ax,[hostpid]
        jbe  .take              ; our host, or a lower name
        call TICK
        sub  ax,[hostheard]
        cmp  ax,HOSTGONE
        jb   .rx                ; ours still talks: this one will yield
.take:  mov  byte [netmode],2
        mov  ax,[sender]
        mov  [hostpid],ax
        call TICK
        mov  [hostheard],ax
        call WAPPLY
        jmp  .rx
.clocks:call TICK
        mov  [now],ax
        cmp  byte [netmode],1
        jne  .client
        mov  bx,players         ; the host: who has gone quiet?
.p:     cmp  byte [bx+P_ON],0
        je   .pn
        cmp  bx,[mep]
        je   .pn                ; our own man never does
        mov  ax,[now]
        sub  ax,[bx+P_HEARD]
        cmp  ax,GONE
        jb   .pn
        call DROPMAN
.pn:    add  bx,PSIZE
        cmp  bx,players+MAXP*PSIZE
        jb   .p
        mov  ax,[now]
        cmp  ax,[lastsend]
        je   .done              ; one world a tick at most
        cmp  byte [netdirty],0
        jne  .sendw             ; it changed: at once
        sub  ax,[lastbeat]
        cmp  ax,BEAT
        jb   .done
.sendw: jmp  WSEND              ; ...or on the beat, for a newcomer
.client:cmp  byte [netmode],2
        jne  .done              ; joining: JOIN keeps the time
        mov  ax,[now]
        sub  ax,[lastbeat]
        cmp  ax,BEAT
        jb   .quiet
        call HSEND              ; hello on the beat: we are still here
.quiet: mov  ax,[now]
        sub  ax,[hostheard]
        cmp  ax,HOSTGONE
        jb   .done
        jmp  NEXTHOST           ; the host is quiet: is it us now?
.done:  ret

; PEER - name [sender] heard now: kept with the tick, for NEXTHOST.  A new
; one takes an empty place, or the place heard from longest ago.
; keeps DI.
PEER:   push di
        call TICK
        mov  cx,ax              ; CX = now
        mov  ax,[sender]
        mov  si,peers
        xor  di,di              ; the place for a new one...
        xor  dx,dx              ; ...and how old it is
.l:     cmp  [si],ax
        je   .have
        mov  bx,cx
        sub  bx,[si+2]          ; this one's age in ticks
        cmp  word [si],0
        jne  .age
        mov  bx,0FFFFh          ; an empty place is the oldest of all
.age:   cmp  bx,dx
        jb   .n
        mov  dx,bx
        mov  di,si
.n:     add  si,4
        cmp  si,peers+MAXPEER*4
        jb   .l
        mov  si,di
        mov  [si],ax
.have:  mov  [si+2],cx
        pop  di
        ret

; NEXTHOST - the host has gone quiet: of the names heard in the last
; GONE ticks, ours among them, the lowest carries on.  Ours: we keep the
; warehouse from the world we last drew.  Another's: we wait for it.
NEXTHOST:
        mov  dx,[mypid]         ; the lowest so far: ours
        mov  si,peers
.l:     mov  ax,[si]
        or   ax,ax
        jz   .n                 ; an empty place
        cmp  ax,[hostpid]
        je   .n                 ; the one gone quiet
        mov  cx,[now]
        sub  cx,[si+2]
        cmp  cx,GONE
        jae  .n                 ; not heard lately
        cmp  ax,dx
        jae  .n
        mov  dx,ax
.n:     add  si,4
        cmp  si,peers+MAXPEER*4
        jb   .l
        cmp  dx,[mypid]
        jne  .wait
        mov  byte [netmode],1   ; ours: we host now
        mov  [hostpid],dx
        mov  ax,[now]
        mov  bx,players
.h:     mov  [bx+P_HEARD],ax    ; everyone heard now: the old host's man
        add  bx,PSIZE           ;  stays GONE ticks more, then goes
        cmp  bx,players+MAXP*PSIZE
        jb   .h
        cmp  word [mep],ghost
        jne  .in
        call ADDME              ; we had no man yet: now we have
.in:    mov  byte [netdirty],1
        mov  byte [dirty],1
.wait:  ret

; WSEND - the world, whole: the level, the men, every crate
WSEND:  mov  di,pkt
        mov  byte [di+K_KIND],'W'
        mov  byte [di+K_PROTO],PROTO
        mov  al,byte [level]
        mov  [di+W_LEVEL],al
        mov  al,[solved]
        mov  [di+W_SOLVED],al
        mov  ax,[moves]
        mov  [di+W_MOVES],ax
        mov  si,players
        add  di,W_SLOTS
.p:     mov  cx,PWIRE
        rep  movsb              ; a man's wire part
        add  si,PSIZE-PWIRE     ; past the host's own bookkeeping
        cmp  si,players+MAXP*PSIZE
        jb   .p
        mov  si,mines           ; the mines, as they are (DI: W_MINES)
        mov  cx,MAXP*MSIZE
        rep  movsb
        mov  di,pkt+W_BOXES
        xor  dx,dx              ; crates so far
        mov  bx,grid
.c:     test byte [bx],G_BOX
        jz   .cn
        cmp  dx,MAXBOX
        jae  .cn
        mov  ax,bx
        sub  ax,grid            ; its cell: row*32 + column
        stosw
        inc  dx
.cn:    inc  bx
        cmp  bx,grid+NCOL*NCOL
        jb   .c
        mov  [pkt+W_NBOX],dl
        mov  si,pkt
        call NETSEND
        mov  ax,[now]
        mov  [lastsend],ax
        mov  [lastbeat],ax
        mov  byte [netdirty],0
        ret

; HSEND - hello: our name, so the host keeps our man and shows it
HSEND:  mov  byte [pkt+K_KIND],'H'
        mov  byte [pkt+K_PROTO],PROTO
        mov  si,myname
        mov  di,pkt+K_ARG
        mov  cx,8
        rep  movsb
        mov  si,pkt
        call NETSEND
        mov  ax,[now]
        mov  [lastbeat],ax
        ret

; SENDM - AL: a step (0..3) or an order (4..6), to the host
SENDM:  mov  byte [pkt+K_KIND],'M'
        mov  byte [pkt+K_PROTO],PROTO
        mov  [pkt+K_ARG],al
        mov  si,pkt
        jmp  NETSEND

; ------------------------------------------------------------------
;  WAPPLY - the host's world (DI -> it) into ours: its level, crates
;  and men.  Everything off the wire is checked first: a level past the
;  last drops the packet, a crate or a man off the floor is left out, a
;  name is made printable - a packet is someone else's word.
; ------------------------------------------------------------------
WAPPLY: mov  [wptr],di
        mov  al,[di+W_LEVEL]
        xor  ah,ah
        cmp  ax,NLEVELS
        jae  .bad               ; no such level: not this game's world
        cmp  ax,[level]
        jne  .load
        cmp  byte [loaded],0
        jne  .keep
.load:  mov  [level],ax
        call LOADLEV            ; its walls, goals and floor
.keep:  mov  di,[wptr]
        mov  al,[di+W_SOLVED]
        and  al,1
        mov  [solved],al
        mov  ax,[di+W_MOVES]
        mov  [moves],ax
        mov  bx,grid            ; no crates, no men: the packet has them
.clr:   and  byte [bx],0FFh xor (G_BOX or G_MAN)
        inc  bx
        cmp  bx,grid+NCOL*NCOL
        jb   .clr
        xor  ax,ax
        mov  [nbox],ax
        mov  [ngood],ax
        mov  cl,[di+W_NBOX]
        xor  ch,ch
        cmp  cx,MAXBOX
        jbe  .cn
        mov  cx,MAXBOX
.cn:    lea  si,[di+W_BOXES]
        jcxz .men
.c:     lodsw                   ; a crate's cell
        cmp  ax,NCOL*NCOL
        jae  .cx                ; off the grid
        mov  bx,ax
        add  bx,grid
        test byte [bx],G_FLOOR
        jz   .cx                ; not floor
        test byte [bx],G_BOX
        jnz  .cx                ; named twice
        or   byte [bx],G_BOX
        inc  word [nbox]
        test byte [bx],G_GOAL
        jz   .cx
        inc  word [ngood]
.cx:    loop .c
.men:   mov  si,[wptr]
        add  si,W_SLOTS
        mov  bx,players
.m:     mov  di,bx
        mov  cx,PWIRE
        rep  movsb              ; his wire part; P_HEARD stays ours
        push si
        call CHECKMAN
        pop  si
        add  bx,PSIZE
        cmp  bx,players+MAXP*PSIZE
        jb   .m
        mov  di,mines           ; the mines (SI: W_MINES), each checked:
        mov  cx,MAXP            ;  on the floor, its clock in range
.mi:    lodsw
        cmp  ax,NCOL*NCOL
        jae  .mx                ; none, or off the grid
        mov  bx,ax
        test byte [grid+bx],G_FLOOR
        jz   .mx                ; not floor
        mov  [di+M_CELL],ax
        lodsw
        cmp  ax,FUSE
        jle  .ml
        mov  ax,FUSE
.ml:    cmp  ax,-BLASTT
        jge  .ms
        mov  ax,-BLASTT
.ms:    mov  [di+M_LEFT],ax
        jmp  .mnx
.mx:    lodsw                   ; its clock, unread
        mov  word [di+M_CELL],0FFFFh
.mnx:   add  di,MSIZE
        loop .mi
        mov  word [mep],ghost   ; which one is ours?
        mov  bx,players
.f:     cmp  byte [bx+P_ON],0
        je   .fn
        mov  ax,[bx+P_PID]
        cmp  ax,[mypid]
        jne  .fn
        mov  [mep],bx
.fn:    add  bx,PSIZE
        cmp  bx,players+MAXP*PSIZE
        jb   .f
        mov  byte [dirty],1
.bad:   ret

; CHECKMAN - player BX as the wire gave him: on the floor of this level,
; on a cell with nothing else, a look we have, a printable name - and his
; man on the grid; else out.  clobbers AX, CL, SI, DI.
CHECKMAN:
        cmp  byte [bx+P_ON],0
        je   .out
        mov  byte [bx+P_ON],1
        mov  al,[bx+P_COL]
        cmp  al,[lvw]
        jae  .out
        mov  al,[bx+P_ROW]
        cmp  al,[lvh]
        jae  .out
        cmp  byte [bx+P_LOOK],NLOOK
        jb   .lk
        mov  byte [bx+P_LOOK],0
.lk:    cmp  word [bx+P_STUN],STUNT
        jbe  .st
        mov  word [bx+P_STUN],STUNT   ; clocks in range
.st:    cmp  word [bx+P_COOL],COOLT
        jbe  .cl
        mov  word [bx+P_COOL],COOLT
.cl:    lea  si,[bx+P_NAME]
        mov  di,si
        call COPYNAME           ; in place
        mov  al,[bx+P_ROW]
        xor  ah,ah
        mov  cl,5
        shl  ax,cl              ; row * 32
        add  al,[bx+P_COL]      ; + column: no carry, it is < 32
        add  ax,grid
        mov  si,ax
        test byte [si],G_FLOOR
        jz   .out
        test byte [si],G_MAN or G_BOX
        jnz  .out
        or   byte [si],G_MAN
        ret
.out:   mov  byte [bx+P_ON],0
        ret

; COPYNAME - 8 letters SI -> DI, printable: 32..126 kept, others '?',
; zeros after the first zero.  SI = DI is allowed.  clobbers AX, CX.
COPYNAME:
        mov  cx,8
.c:     lodsb
        or   al,al
        jz   .pad
        cmp  al,32
        jb   .q
        cmp  al,126
        jbe  .put
.q:     mov  al,'?'
.put:   stosb
        loop .c
        ret
.pad:   rep  stosb              ; AL = 0: the rest of the name
        ret

        include '..\..\ENGINE\E_NET.INC'  ; code and data: never run into

; ------------------------------------------------------------------
;  Data
; ------------------------------------------------------------------
MSGMEM  db 'MULTIPLAY SOKO needs a whole 64 KB segment of memory.',13,10,'$'
MSGSPR  db 'MULTIPLAY SOKO: the pictures outgrew SPRMAX.',13,10,'$'
TNAME   db 'MULTIPLAY SOKO',0
TLINES  db 7,36,1,'CRATES ONTO THE RED MARKS',0
        db 2,108,3,'ARROWS',0
        db 10,108,1,'WALK AND PUSH (OR W A S D)',0
        db 2,116,3,'SPACE',0
        db 10,116,1,'MINE: 5 S, 3X3 STAND 15 S',0
        db 2,124,3,'Q E',0
        db 10,124,1,'TURN THE VIEW',0
        db 2,132,3,'V   Z',0
        db 10,132,1,'ISOMETRIC  WHOLE LEVEL',0
        db 2,140,3,'R R',0
        db 10,140,1,'THE LEVEL ANEW',0
        db 2,148,3,'N N P P',0
        db 10,148,1,'NEXT OR PREVIOUS LEVEL',0
        db 2,156,3,'ESC',0
        db 10,156,1,'BACK TO DOS',0
        db 8,180,3,'TYPE A NAME, PRESS ENTER',0
        db 9,192,2,'LEVELS FROM BASE-Z-47',0
        db 0FFh
TNAMEQ  db 'YOUR NAME: ',0
TPLAYER db 'PLAYER',0,0         ; a name nobody typed: 8 bytes, zero-padded
TWIRE   db ' THE WIRE: DIALING - ENTER PLAYS ALONE ',0
TLOOK   db '     LOOKING FOR THE WAREHOUSE...      ',0
TCOMING db ' COMING IN... ',0
SPIN    db '|/-\'
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
DIRKEYS db 48h,0, 11h,0         ; Up, W: a row up the screen
        db 4Dh,1, 20h,1         ; Right, D
        db 50h,2, 1Fh,2         ; Down, S
        db 4Bh,3, 1Eh,3         ; Left, A
DSTEP   dw -NCOL, 1, NCOL, -1   ; a step in grid bytes, per direction
; shirt, cap and trousers: green 1, red 2, yellow 3; look 0 is yours
LOOKS   db 3,2, 2,1, 1,2, 2,3, 1,3, 3,1
; a nibble's 4 bits -> 4 two-bit pixels
EXP4:
rept 16 n:0 { db ((n shr 3) and 1)*0C0h + ((n shr 2) and 1)*30h + ((n shr 1) and 1)*0Ch + (n and 1)*3 }
DBL4    db 00h,0Fh,0F0h,0FFh    ; 2 bits -> 4 pixels, each one twice
; the three views: CX, CY, RX, RY (a column on, a row on), the tile's
; width and height, the lifts of wall, crate, man, marker and mine (rows
; above the tile's top row, as ART.INC says), then the pictures
ZS      dw 8,0, 0,8, 8,8, 0,0,0,0,0     ; straight down, the whole level
        dw (8+NLOOK) dup 0
ZB      dw 16,0, 0,16, 16,16, 0,0,0,0,0 ; straight down, close up
        dw (8+NLOOK) dup 0
ZI      dw 12,6, -12,6, 24,12, -6,-8,-8,-11,-2   ; isometric
        dw (8+NLOOK) dup 0
zoomp   dw ZB                   ; straight down, close up, to begin with
topz    dw ZB                   ; the straight-down size V comes back to
turn    db 0                    ; quarter turns clockwise, 0..3 (Q, E)
mep     dw ghost                ; this machine's man: none until it is in
netmode db 0                    ; 0 alone, 1 the host, 2 a client, 3 joining
mypid   dw 0                    ; our name on the wire (0 alone)
hostpid dw 0                    ; the host's name
hostheard dw 0                  ; the tick its world last came
sender  dw 0                    ; who sent the packet in hand
lastbeat dw 0                   ; the tick of our last heartbeat
lastsend dw 0FFFFh              ; the tick of the host's last world
netdirty db 0                   ; 1: the world changed, send it
loaded  db 0                    ; 1: a level is in the grid
jstart  dw 0                    ; when JOIN's wait began
wptr    dw 0                    ; the world packet WAPPLY reads
mylen   db 0
myname  db 9 dup 0              ; your name, as typed; a zero after it
peers   db MAXPEER*4 dup 0      ; names heard: name, tick (words)
pkt     db NETLEN dup 0         ; the packet we send
players db (MAXP*PSIZE) dup 0   ; the men in the warehouse...
ghost   db PSIZE dup 0          ; ...and the camera of a player not in
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
ccell   dw 0                    ; DRAWMEN's cell; a blast's centre
boff    dw 0                    ; which of a blast's nine cells
tcols   db 0                    ; TURNED: the turned grid's columns,
trows   db 0                    ;  rows,
tstart  dw 0                    ;  its first cell,
tdcol   dw 0                    ;  a column on,
tdrow   dw 0                    ;  a row on
tcc     db 0                    ; CELLXY, PUTAT: a turned column, row
trr     db 0
tyy     dw 0
xmin    dw 0                    ; the turned level's left edge, from ox
txb     dw 0                    ; PUTCHB's byte column
lastt   dw 0                    ; TICKER: the tick it last ran
lastsec dw 0                    ;  the tick it last redrew for a clock
act     db 0                    ;  1: a clock runs
mines   db (MAXP*MSIZE) dup 0   ; a mine a man (CLRMINES: none)
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
wtop    dw 0
wpx     dw 0
hpx     dw 0
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
bfsq    rw NCOL*NCOL            ; FREECELL's queue: every cell at most once
bbuf    rb 16000                ; the back buffer: 320x200, 4 px a byte
if $ > 0FE00h                   ; the stack falls from FFFEh: leave it
        err                     ;  512 bytes
end if
