; ==================================================================
;  MULTSOK2.ASM - MULTIPLAY SOKO II: crates onto the red marks, in a
;  castle seen from above, for up to eight on the network - on an EGA,
;  a CGA or a Hercules, with a Sound Blaster.
;      MAKE in GAMES\MULTSOK2 (ART.DAT, then the game), MAKEWIN from Windows
;  ARROWS or W A S D   walk, and push the crate in front of you
;  SPACE  a mine where you stand: it ticks 5 s, then the nine cells round
;         it blast and every man on them stands still for 15 s.  One mine
;         a man; the next is his 60 s after he laid this one.
;  Q E    turn the view    V  isometric    Z  close up / the whole level
;  R R    the level anew      N N, P P   the next, the previous level
;  ESC    back to DOS
;  A crate onto a goal +10, off one -10; a candy +1..3; the diamond +25.
;  Every crate home: the gate in the wall rises, the drawbridge comes
;  down, and the men walk out through it - +50 each, +25 more for the
;  first; 15 s later the gate is shut, and the one who did most in the
;  level is the winner, on the podium, before the next.
;  The first screen picks the card and the sound (text mode: every card
;  shows it).  The pictures are ART.DAT, beside the game (ART.ASM);
;  the levels Base-Z-47's (LEVELS.INC).  MULTIPLAY SOKO, the first one,
;  is GAMES\MULTSOKO, CGA and its own room; this one meets in multsok2.
;  ON THE NETWORK one machine - the lowest name on the wire - keeps the
;  castle: the crates, the level, the men, the score, the clocks, the
;  candies; it sends the world whole and the others draw what it sends.
;  THE ONE FACT: the picture is drawn once, in a buffer of two pixels a
;  byte, and only what changed in each row goes out to the card - as
;  four bit planes (EGA), two banks of four-pixel bytes (CGA) or four
;  banks of eight-dot bytes (Hercules).
; ==================================================================
format binary as 'com'
        org  100h               ; DOS loads a .COM at offset 100h
        include '..\..\ENGINE\E_8086.INC'  ; jumps an 8086 can run
        include 'KINDS.INC'     ; the pictures' numbers (TOOLS\ArtGen2)

NCOL    = 32                    ; grid row stride: the widest level is 29
G_WALL  = 1                     ; the bits of a grid cell
G_GOAL  = 2
G_BOX   = 4
G_FLOOR = 8                     ; inside the walls: flooded from the man
G_MAN   = 16                    ; a man stands here
G_SEEN  = 32                    ; FREECELL's mark, cleared after it
G_CANDY = 64                    ; a candy lies here
G_OUT   = 128                   ; outside the walls (OUTSIDE)
MAXP    = 8                     ; men in the warehouse
MAXBOX  = 36                    ; crates a level may have: 35 is the most
NLOOK   = 6                     ; shirt and cap colours (LOOKS)
PFTOP   = 8                     ; the playfield: rows 8..185; above it the
PFBOT   = 186                   ;  level line, under it the players
BGOFF   = 32000                 ; the background, after the frame, in gseg
PENDT   = 36                    ; ticks a "press again" waits: 2 s
FUSE    = 91                    ; ticks a mine ticks: 5 s at 18.2 a second
BLASTT  = 9                     ; ticks the blast shows: half a second
STUNT   = 273                   ; ticks a man in the blast stands: 15 s
COOLT   = 1092                  ; ticks from one mine to the next: 60 s
PH1T    = 27                    ; ticks the gate takes to rise: 1.5 s
EXITT   = 273                   ; ticks it stays up: 15 s to walk out
WINT    = 145                   ; ticks the winner shows: 8 s
GEMWAIT = 364                   ; ticks before a diamond: 20 s (and up to 7 more)
GEMLIFE = 273                   ; ticks one lies, not taken: 15 s
GEMGROW = 18                    ; ...the first second of them growing
CANDYMAX = 3                    ; a candy is worth 1..3

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
P_GAIN  = 20                    ; word, signed: his points in this level
P_OUT   = 22                    ; byte: 0 inside, n - the n-th out of the gate
PWIRE   = 24
P_HEARD = 24                    ; word: the tick he was last heard (the host's)
P_HHEAD = 26                    ; byte: his history's next place (the host's:
P_HCNT  = 27                    ;  byte: steps in it   the steps he can take
P_HIST  = 28                    ;  NHIST bytes: dir 0..3, +4 a crate pushed   back)
NHIST   = 32
PSIZE   = P_HIST + NHIST

; a mine: one a man, in the slot of his number
M_CELL  = 0                     ; word: its cell, row*32 + column; 0FFFFh none
M_LEFT  = 2                     ; word, signed: ticks to the blast; below 0,
MSIZE   = 4                     ;  the blast showing, counting up to 0

; a packet: +0 its kind, +1 PROTO, then by its kind -
;  'H' hello, a player's heartbeat:  +2 his name, 8 letters
;  'M' a step or an order, to the host: +2 what - 0..3 a step (up, right,
;      down, left), 4 the level anew, 5 the next, 6 the previous, 7 a mine,
;      8 a step back
;  'W' the world, the host's, whole: the level and its phase, the men, the
;      mines, the crates, which floor cells still have a candy
K_KIND  = 0
K_PROTO = 1
K_ARG   = 2
W_LEVEL = 2                     ; byte
W_PHASE = 3                     ; byte: 0 play, 1 the gate rising, 2 up, 3 winner
W_MOVES = 4                     ; word
W_NBOX  = 6                     ; byte: crates listed at W_BOXES
W_WIN   = 7                     ; byte: the winner's slot, 0FFh none
W_PCLK  = 8                     ; word: ticks left in the phase
W_GATE  = 10                    ; word: the gate's cell, 0FFFFh none
W_GEM   = 12                    ; word: the diamond's cell, 0FFFFh none
W_GCLK  = 14                    ; word: its clock
W_SLOTS = 16                    ; MAXP players of PWIRE bytes
W_MINES = W_SLOTS + MAXP*PWIRE  ; 208: MAXP mines of MSIZE
W_BOXES = W_MINES + MAXP*MSIZE  ; 240: the crates' cells, words
W_CANDY = W_BOXES + MAXBOX*2    ; 312: a bit a cell, 4 bytes a row
NCROW   = 24                    ;  for rows 0..23 (the tallest level is 20)

; the network: ENGINE\E_NET.INC, everyone in the room hears everyone
NETSOCK = 5454h                 ; our socket: a palindrome; not the first
                                ;  game's 5353h, nor OWL FLY's 5757h/5858h
W_OWL   = W_CANDY + NCROW*4     ; 408: the owl's wall cell, 0FFFFh none
W_OCLK  = W_OWL + 2             ; word: its clock - to come, or to go
W_OCATCH = W_OWL + 4            ; byte: owls caught in all, for the sound
NETLEN  = W_OWL + 6             ; every packet the world's size: 414 bytes
NETRX   = 8                     ; listens: seven others and our own echo
PROTO   = 4                     ; in every packet: another version is not ours
BEAT    = 9                     ; ticks between heartbeats: twice a second
GONE    = 55                    ; ticks unheard: a player has gone (3 s)
HOSTGONE = 36                   ; ticks with no world: the host has gone (2 s)
JOINT   = 36                    ; ticks of listening for a warehouse to join
WIREWT  = 270                   ; ticks of waiting for our address: 15 s
MAXPEER = 16                    ; names heard lately, to choose the next host

NENT    = (NSIZE+1)*NKIND + 1   ; ART.DAT's pictures: every size, isometric,
ARTDIR  = 140                   ;  its floor; the directory's place in the file
ARTFDIR = 12                    ; ARTF.DAT's: after SOKOARTF, NKIND, NSIZE

START:  cld                     ; string ops count UP
        xor  ax,ax
        call LAYOUT             ; the narrow cards' segments, to begin with
        mov  bx,[2]             ; PSP:2 = the top of our memory, paragraphs
        mov  ax,[rseg]
        add  ax,1000h
        cmp  bx,ax
        jae  .ring              ; the ring's segment: the sound in its
        mov  dx,MSGMEM          ;  bottom half, the water's list in its
        jmp  FAIL               ;  top (WATERS)
.ring:  mov  ax,cs              ; and EGA 640's, a segment more: does the
        add  ax,5000h+0FFFh     ;  memory hold them? (DETECT offers it
        and  ax,0F000h          ;  only then)
        add  ax,1000h
        jc   .wn
        cmp  bx,ax
        jb   .wn
        mov  byte [widemem],1
.wn:    call SPROBE
        call DETECT
        cmp  byte [card],0
        jne  .card
        mov  dx,MSGCARD
        jmp  FAIL
.card:  call LOADLEVS           ; the levels' table (or a reason why not)
        call PREP
        call MENU               ; the card, the sound, your name
        mov  al,[card]          ; that card's segments, the buffer's rows,
        cmp  al,CARD_EGAW
        mov  al,0
        jne  .lay
        inc  al
.lay:   call LAYOUT
        call LOADART            ; the pictures, compiled (or a reason why not)
        call MKTABS             ; that card's tables
        call NETOPEN            ; the IPX card: CF=1, none - then alone
        mov  byte [vmode],1
        call VSET
        call SNDON
        call TITLE
        call BLIT
        call JOIN               ; the room's castle, or our own
MAIN:   call HEAL               ; the wind made behind the sound's beam
        call NETPOLL            ; the others: their steps, or the world
        call KEYS
        call TIMERS
        cmp  byte [dirty],0     ; draw only when something changed
        jne  .draw
        mov  ax,1680h           ; nothing to do: the time given back - to
        int  2Fh                ;  a DOS box under Windows this way, and
        sti                     ;  to DOSBox (and the browser it runs in)
        hlt                     ;  by sleeping to the next tick or key.
        jmp  MAIN               ;  It had spun flat out: a laptop's fan
.draw:  mov  byte [dirty],0     ;  (the pilot: "mind the Macs")
        call SNDDIFF            ; what changed, heard
        call RENDER
        jmp  MAIN

QUIT:   call NETCLOSE           ; the socket given back, every way out
        call SNDOFF
        cmp  byte [vmode],0
        je   .text
        call VRESET
        jmp  .exit
.text:  xor  ah,ah
        mov  al,[origmode]      ; the menu's text mode: as DOS lent it,
        or   al,al              ;  the cursor back
        jnz  .t
        mov  al,3
.t:     int  10h
.exit:  mov  ax,4C00h
        int  21h                ; exit(0)

; LEVFAIL - LEVELS.DAT would not read in the middle of a game: back to
; DOS, with the reason
LEVFAIL:call NETCLOSE
        call SNDOFF
        call VRESET
        mov  dx,MSGLEV
; FAIL - DX -> a '$' message, before any mode was changed: say it, leave
FAIL:   mov  ah,9
        int  21h
        mov  ax,4C01h
        int  21h                ; exit(1)

; ------------------------------------------------------------------
;  LOADART - ART.DAT, from the folder the game was started from (the
;  environment says where: after its double zero, a count, our own
;  path), else from the current one; read into gseg, checked, and every
;  picture compiled into sseg - each man once a look, the winner's twice
;  as big.  spt: a word per picture, NKIND a size; mant: per size, per
;  look; bigman: per look.
; ------------------------------------------------------------------
LOADART:call FINDDAT
        mov  dx,datpath
        mov  ax,3D00h
        int  21h                ; open for reading
        jnc  .open
        mov  dx,TARTDAT         ; not there: the current folder
        mov  ax,3D00h
        int  21h
        jnc  .open
.err:   mov  dx,MSGART
        jmp  FAIL
.open:  mov  bx,ax
        push ds
        mov  ds,[gseg]
        xor  dx,dx
        mov  cx,0FFFFh
        mov  ah,3Fh
        int  21h                ; the whole of it into gseg (up to 64K)
        pop  ds
        pushf
        push ax
        mov  ah,3Eh
        int  21h                ; closed
        pop  ax
        popf
        jc   .err
        cmp  ax,ARTDIR+NENT*2
        jb   .bad
        push ds
        mov  ds,[gseg]
        xor  si,si
        mov  di,TMAGIC
        mov  cx,8
        repe cmpsb              ; SOKOART2?
        pop  ds
        jne  .bad
        mov  es,[gseg]
        cmp  word [es:8],NKIND  ; the same pictures as KINDS.INC says?
        jne  .bad
        cmp  word [es:10],NSIZE
        jne  .bad
        push ds
        pop  es
        push ds
        mov  ds,[gseg]
        mov  si,12
        mov  di,artpal
        mov  cx,48+64+16        ; the palette, the CGA map, the brightness
        rep  movsb
        pop  ds
        call LOADF              ; EGA 640: the fine pictures, if there
        mov  word [area],0      ; the first place, from its start
        mov  ax,[arealo]
        mov  [adi],ax
        xor  bx,bx
.pic:   mov  [pidx2],bx
        push ds
        mov  ds,[gseg]
        shl  bx,1
        mov  si,[ARTDIR+bx]     ; where picture BX starts in the file
        pop  ds
        mov  [psrc],si
        cmp  bx,NSIZE*NKIND*2
        jb   .new               ; an isometric one that is the 16 px one
        cmp  bx,(NSIZE+1)*NKIND*2
        jae  .new               ;  (a man, a mine, a tree...): compiled
        push ds                 ;  already - the same place
        mov  ds,[gseg]
        cmp  si,[ARTDIR+bx-NSIZE*NKIND*2]
        pop  ds
        jne  .new
        shl  bx,1               ; 4 bytes an entry: where, which segment
        mov  ax,[spt+bx-NSIZE*NKIND*4]
        mov  [spt+bx],ax
        mov  ax,[spt+bx-NSIZE*NKIND*4+2]
        mov  [spt+bx+2],ax
        jmp  .pn
.new:   call ROOM               ; CX: the most it can take
        call PLACE              ; ES:DI: where it goes
        jc   .full
        mov  bx,[pidx2]
        shl  bx,1
        shl  bx,1
        mov  [spt+bx],di
        mov  [spt+bx+2],es
        cmp  byte [hasfine],0   ; EGA 640: a fine one drawn for it?
        je   .dbl
        mov  bx,[pidx2]
        shl  bx,1
        push ds
        mov  ds,[bgseg]
        mov  si,[ARTFDIR+bx]
        or   si,si
        jz   .nof
        call COMPILEF           ; ARTF.DAT's, twice as fine across
        pop  ds
        jmp  .cd
.nof:   pop  ds
.dbl:   push ds
        mov  ds,[gseg]
        mov  si,[cs:psrc]
        mov  bp,LOOKS           ; (a man in look 0: MANT has them all)
        call PCOMP
        pop  ds
.cd:    mov  [adi],di
.pn:    mov  bx,[pidx2]
        inc  bx
        cmp  bx,NENT
        jb   .pic
        xor  bx,bx              ; the men: every size, every look
.man:   mov  [pidx2],bx
        mov  ax,bx
        xor  dx,dx
        mov  cx,NLOOK
        div  cx                 ; AX = the size, DX = the look
        push dx
        mov  cx,NKIND
        mul  cx
        add  ax,K_MAN
        shl  ax,1
        mov  si,ax              ; the size's MAN in the directory
        push ds
        mov  ds,[gseg]
        mov  si,[ARTDIR+si]
        pop  ds
        mov  [psrc],si
        call ROOM
        call PLACE
        pop  dx
        jc   .full
        shl  dx,1
        shl  dx,1
        mov  bp,LOOKS
        add  bp,dx              ; the look's four colours
        mov  bx,[pidx2]
        shl  bx,1
        shl  bx,1
        mov  [mant+bx],di
        mov  [mant+bx+2],es
        push ds
        mov  ds,[gseg]
        mov  si,[cs:psrc]
        call PCOMP
        pop  ds
        mov  [adi],di
        mov  bx,[pidx2]
        inc  bx
        cmp  bx,(NSIZE+1)*NLOOK
        jb   .man
        mov  cx,2+32*16*2       ; the winner's man, twice as big: room for
        cmp  byte [wide],0      ;  one, compiled when he has won (MKBIG) -
        je   .big               ;  EGA 640's twice as wide again
        mov  cx,2+32*32*2
.big:   call PLACE
        jc   .full
        mov  [bigat],di
        mov  [bigseg],es
        add  di,cx
        mov  [adi],di
        push ds                 ; and the 16 px man's raw picture kept for
        pop  es                 ;  it: the file's room is the frame's soon
        push ds
        mov  ds,[gseg]
        mov  si,[ARTDIR+K_MAN*2]
        mov  di,rawman
        mov  cx,2+16*16
        rep  movsb
        pop  ds
        mov  byte [biglook],0FFh
        ret
.bad:   mov  dx,MSGBAD
        jmp  FAIL
.full:  mov  dx,MSGFULL
        jmp  FAIL

; LOADF - EGA 640's fine pictures: ARTF.DAT, from the game's folder or
; the current one, into bgseg (free until the first background) and
; checked: hasfine 1.  Not there, or not this game's: hasfine 0, and
; every picture is ART.DAT's doubled.
LOADF:  mov  byte [hasfine],0
        cmp  byte [wide],0
        je   .r
        push ds
        pop  es
        mov  si,TARTF
        call DATNAME
        mov  dx,datpath
        mov  ax,3D00h
        int  21h
        jnc  .open
        mov  dx,TARTF
        mov  ax,3D00h
        int  21h
        jc   .r                 ; none: doubled it is
.open:  mov  bx,ax
        push ds
        mov  ds,[bgseg]
        xor  dx,dx
        mov  cx,0FFFFh
        mov  ah,3Fh
        int  21h                ; the whole of it into bgseg
        pop  ds
        pushf
        push ax
        mov  ah,3Eh
        int  21h
        pop  ax
        popf
        jc   .r
        cmp  ax,ARTFDIR+NENT*2
        jb   .r
        push ds
        mov  ds,[bgseg]
        xor  si,si
        mov  di,TFMAGIC         ; (ES = CS)
        mov  cx,8
        repe cmpsb              ; SOKOARTF?
        jne  .bad
        cmp  word [8],NKIND
        jne  .bad
        cmp  word [10],NSIZE
        jne  .bad
        pop  ds
        mov  byte [hasfine],1
.r:     ret
.bad:   pop  ds
        ret

; ROOM - CX: the most the picture at gseg:[psrc] can compile to - a mask
; and an ink byte for every two pixels; at EGA 640 for every one
ROOM:   push ds
        mov  ds,[gseg]
        mov  si,[cs:psrc]
        lodsw                   ; AL = width, AH = height
        pop  ds
        mul  ah                 ; AX = its pixels
        cmp  byte [wide],0
        je   .n
        shl  ax,1               ; twice as wide: two bytes a pixel
.n:     add  ax,2               ; and its rows, its bytes a row
        mov  cx,ax
        ret

; PLACE - room for CX bytes of pictures: ES:DI, in the place being
; filled or, when it has not got them, the next (LAYOUT's places).
; CF=1: no place has.  clobbers AX, BX.
PLACE:  mov  bx,[area]
.try:   mov  ax,[adi]
        add  ax,cx
        jc   .next
        cmp  ax,[areahi+bx]
        jbe  .ok
.next:  add  bx,2
        cmp  bx,[narea]
        jae  .no
        mov  [area],bx
        mov  ax,[arealo+bx]
        mov  [adi],ax
        jmp  .try
.no:    stc
        ret
.ok:    mov  es,[areaseg+bx]
        mov  di,[adi]
        clc
        ret

; PCOMP - COMPILE; at EGA 640, COMPILEW: the picture twice as wide
PCOMP:  cmp  byte [cs:wide],0
        je   COMPILE
        jmp  COMPILEW

; FINDDAT - datpath: the folder of our own path, and ART.DAT
FINDDAT:mov  di,datpath
        mov  bx,di              ; where the file name goes
        mov  ax,[2Ch]           ; PSP:2Ch, the environment's segment
        or   ax,ax
        jz   .name
        push ds
        mov  ds,ax
        xor  si,si
.scan:  cmp  word [si],0        ; the double zero ends the variables
        je   .end
        inc  si
        cmp  si,32000
        jb   .scan
        pop  ds
        jmp  .name
.end:   add  si,4               ; past it and the count: our own path
        mov  cx,100
.copy:  lodsb
        mov  [es:di],al         ; (ES = CS)
        inc  di
        or   al,al
        jz   .done
        cmp  al,'\'
        je   .sl
        cmp  al,':'
        jne  .nx
.sl:    mov  bx,di              ; the name goes after the last \ or :
.nx:    loop .copy
.done:  pop  ds
.name:  mov  [datname],bx
        mov  si,TARTDAT         ; ART.DAT first
; DATNAME - the zero-ended name at SI after datpath's folder
DATNAME:mov  di,[datname]
.c:     lodsb
        stosb                   ; (ES = CS)
        or   al,al
        jnz  .c
        ret

; ------------------------------------------------------------------
;  LEVELS.DAT - the levels, a file beside the game (LEVELS.ASM).
;  LEVFILE - it opened, from the game's folder or the current one: BX =
;  its handle; CF=1 not there.  LOADLEVS - its table, checked, into
;  lvtab (at start: a reason in text if not).  LEVREAD - the level at
;  its place DX into bfsq; CF=1 it would not read.
; ------------------------------------------------------------------
LEVFILE:push ds
        pop  es
        mov  si,TLEVDAT
        call DATNAME
        mov  dx,datpath
        mov  ax,3D00h
        int  21h                ; open for reading
        jnc  .ok
        mov  dx,TLEVDAT         ; not there: the current folder
        mov  ax,3D00h
        int  21h
.ok:    mov  bx,ax
        ret

LOADLEVS:
        call LEVFILE
        jc   .err
        mov  dx,bfsq
        mov  cx,12
        mov  ah,3Fh
        int  21h                ; SOKOLEV2, where the table is, how many
        jc   .cerr
        cmp  ax,12
        jne  .cerr
        mov  si,bfsq
        mov  di,TLMAGIC
        mov  cx,8
        repe cmpsb
        jne  .cerr
        cmp  word [bfsq+10],NLEVELS
        jne  .cerr
        mov  dx,[bfsq+8]
        xor  cx,cx
        mov  ax,4200h
        int  21h                ; to the table
        jc   .cerr
        mov  dx,lvtab
        mov  cx,NLEVELS*2
        mov  ah,3Fh
        int  21h
        jc   .cerr
        cmp  ax,NLEVELS*2
        jne  .cerr
        mov  ah,3Eh
        int  21h                ; closed
        ret
.cerr:  mov  ah,3Eh
        int  21h
.err:   mov  dx,MSGLEV
        jmp  FAIL

LEVREAD:push dx
        call LEVFILE
        pop  dx
        jc   .r
        xor  cx,cx
        mov  ax,4200h
        int  21h                ; to the level
        jc   .c
        mov  dx,bfsq
        mov  cx,640*2           ; it, and whatever follows it: room for
        mov  ah,3Fh             ;  the largest (29 x 20) many times over
        int  21h
.c:     pushf
        mov  ah,3Eh
        int  21h
        popf
.r:     ret

; ------------------------------------------------------------------
;  LAYOUT - the segments over the program, for AL: 0 the narrow cards,
;  1 EGA 640.  Narrow: gseg the frame and the background after it, pseg
;  what the card shows, sseg the pictures.  EGA 640: the frame the whole
;  of gseg, bgseg the background (pseg's place: no copy of the card,
;  BLITW's checksums instead), sseg and sseg2 the pictures.  Then the
;  ring, on a 64K page - its DMA must not cross one - its top half the
;  pictures' last place.  And the buffer's rows: rowtab[y] = y * rowb.
; ------------------------------------------------------------------
LAYOUT: mov  [wide],al
        mov  ax,cs
        add  ax,1000h
        mov  [gseg],ax
        mov  [tseg],ax
        mov  [bgseg],ax
        mov  word [bgoff],BGOFF
        add  ax,1000h
        mov  [pseg],ax
        mov  bx,ax              ; BX: the segment before the next
        mov  cx,160
        mov  dx,40
        cmp  byte [wide],0
        je   .n
        mov  [bgseg],ax         ; EGA 640: the background where pseg was
        mov  word [bgoff],0
        mov  cx,320             ;  320 bytes a row: 640 pixels, 2 a byte
        mov  dx,80
.n:     mov  [rowb],cx
        mov  [vstride],dx
        add  bx,1000h
        mov  [sseg],bx
        mov  [picseg],bx
        mov  [areaseg],bx       ; the pictures' places, filled in turn
        mov  word [arealo],2    ;  (0 in a table: no picture)
        mov  word [areahi],65000
        mov  si,2
        cmp  byte [wide],0
        je   .r
        add  bx,1000h
        mov  [sseg2],bx
        mov  [areaseg+2],bx
        mov  word [arealo+2],0
        mov  word [areahi+2],65000
        mov  si,4
.r:     add  bx,1000h+0FFFh
        and  bx,0F000h
        mov  [rseg],bx
        mov  [areaseg+si],bx
        mov  word [arealo+si],PARKAT
        mov  word [areahi+si],0FFF0h
        add  si,2
        mov  [narea],si
        mov  di,rowtab
        xor  ax,ax
        mov  cx,200
.row:   mov  [di],ax
        add  di,2
        add  ax,[rowb]
        loop .row
        ret

; ------------------------------------------------------------------
;  PREP - the darkening table, the 8x8 font, nobody in the warehouse, no
;  mines, no diamond.
; ------------------------------------------------------------------
PREP:   xor  bx,bx              ; dimtab[b]: both nibbles a step darker
.dim:   mov  al,bl
        mov  cl,4
        shr  al,cl
        push bx
        mov  bl,al
        xor  bh,bh
        mov  al,[DIM16+bx]
        pop  bx
        shl  al,cl
        mov  ah,al
        mov  al,bl
        and  al,0Fh
        push bx
        mov  bl,al
        xor  bh,bh
        mov  al,[DIM16+bx]
        pop  bx
        or   al,ah
        mov  [dimtab+bx],al
        inc  bl
        jnz  .dim
        mov  ax,0F000h          ; the 8x8 font: a CGA BIOS keeps it at
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
        mov  word [gemcell],0FFFFh
        call TICK
        mov  [rseed],ax         ; the generator from the clock
        mov  word [owlcell],0FFFFh
        jmp  CLRMINES

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
;  JOIN - into the room's castle.  Wait for the wire to name us (in a
;  browser the address comes seconds after the start), listen JOINT
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
        call HEAL
        call NETPOLL
        cmp  byte [netmode],2   ; a host answered: we are in
        je   .done
        call TICK
        sub  ax,[jstart]
        cmp  ax,JOINT
        jb   .look
        mov  byte [netmode],1   ; nobody: our own castle, we host it
        mov  ax,[mypid]
        mov  [hostpid],ax
        jmp  .fresh
.alone: mov  byte [netmode],0
        mov  word [mypid],0
.fresh: mov  word [level],0
        call NEWLEV
        call ADDME              ; our man, at the start
        mov  byte [netdirty],1
.done:  mov  byte [dirty],1
        mov  byte [camnew],1
        ret

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

; ------------------------------------------------------------------
;  NEWLEV - level [level], and every man in it again: the host's and
;  the lone player's.  LOADLEV - the level alone, its crates and candies
;  as they start, the outside, the gate; a client loads it so, then puts
;  the host's world on it.
; ------------------------------------------------------------------
NEWLEV: call LOADLEV
        call CLRMINES           ; the mines stay with the old floor
        mov  bx,players
.s:     xor  ax,ax
        mov  [bx+P_STUN],ax     ; nobody starts a level standing still,
        mov  [bx+P_GAIN],ax     ;  with points from the last,
        mov  [bx+P_OUT],al      ;  or outside,
        mov  [bx+P_HHEAD],ax    ;  or steps to take back (and P_HCNT)
        add  bx,PSIZE
        cmp  bx,players+MAXP*PSIZE
        jb   .s
        mov  byte [phase],0
        mov  byte [winner],0FFh
        mov  word [owlcell],0FFFFh ; no owl on the new walls yet
        call OWLWAIT
        mov  word [gemcell],0FFFFh
        call RND
        mov  al,ah
        and  ax,127
        add  ax,GEMWAIT
        mov  [gemclk],ax        ; the first diamond in 20..27 s
        jmp  PLACEALL

LOADLEV:mov  di,gridpad         ; a zero row in front, then the grid
        mov  cx,(NCOL+NCOL*NCOL)/2
        xor  ax,ax
        rep  stosw
        mov  [nbox],ax
        mov  [ngood],ax
        mov  [moves],ax
        mov  [pend],al
        mov  bx,[level]
        shl  bx,1               ; a word per level
        mov  dx,[lvtab+bx]      ; where it is in LEVELS.DAT
        call LEVREAD            ; into bfsq (free until FLOOD)
        jnc  .got
        jmp  LEVFAIL
.got:   mov  si,bfsq
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
        call LIVEGEN            ; where a crate can still go home from
        call OUTSIDE
        call FINDGATE
        call PUTCANDY
        call LANDGEN            ; the land round the castle, for the picture
        mov  bx,[start]
        mov  si,ghost           ; the ghost - a camera with no man - at
        call SETPOS             ;  the start, for a player not in yet
        mov  byte [loaded],1
        jmp  VIEWSET            ; the level's size: the view's

; PUTCANDY - a candy on every floor cell with no goal and no crate, but
; the start
PUTCANDY:
        mov  bx,grid
        xor  cx,cx
.c:     mov  al,[bx]
        and  al,G_FLOOR or G_GOAL or G_BOX
        cmp  al,G_FLOOR
        jne  .n
        cmp  bx,[start]
        je   .n
        or   byte [bx],G_CANDY
        inc  cx
.n:     inc  bx
        cmp  bx,grid+NCOL*NCOL
        jb   .c
        mov  [ncandy],cx
        ret

; OUTSIDE - G_OUT on every empty cell of the level's rectangle that the
; edge reaches, empty cell by empty cell: the world beyond the walls.
; A courtyard shut in by walls stays without it.
OUTSIDE:mov  byte [chg],1
.pass:  cmp  byte [chg],0
        je   .r
        mov  byte [chg],0
        mov  bx,grid
        xor  dh,dh              ; DH = the row
.row:   push bx
        xor  dl,dl              ; DL = the column
.col:   test byte [bx],G_WALL or G_FLOOR or G_OUT
        jnz  .next
        or   dh,dh              ; on the rectangle's edge: out
        jz   .out
        or   dl,dl
        jz   .out
        mov  al,[lvh]
        dec  al
        cmp  dh,al
        je   .out
        mov  al,[lvw]
        dec  al
        cmp  dl,al
        je   .out
        mov  al,[bx-1]          ; or next to a cell that is
        or   al,[bx+1]
        or   al,[bx-NCOL]
        or   al,[bx+NCOL]
        test al,G_OUT
        jz   .next
.out:   or   byte [bx],G_OUT
        mov  byte [chg],1
.next:  inc  bx
        inc  dl
        cmp  dl,[lvw]
        jb   .col
        pop  bx
        add  bx,NCOL
        inc  dh
        cmp  dh,[lvh]
        jb   .row
        jmp  .pass
.r:     ret

; FINDGATE - the gate: a wall with the floor on one side and the outside
; on the other; of those, the one nearest the start.  hasgate 0: none
; (the level then ends as soon as it is solved).
FINDGATE:
        mov  byte [hasgate],0
        mov  word [gatecell],0FFFFh
        mov  word [gbest],0FFFFh
        mov  ax,[start]
        sub  ax,grid
        mov  bl,al
        and  bl,NCOL-1
        mov  [sc],bl            ; the start's column
        mov  cl,5
        shr  ax,cl
        mov  [sr],al            ;  ...and row
        xor  dx,dx              ; DX = r
.row:   xor  cx,cx              ; CX = c
.col:   call GRIDAT
        test al,G_WALL
        jz   .next
        mov  si,GDIRS
.dir:   push cx
        push dx
        sub  cx,[si]
        sub  dx,[si+2]
        call GRIDAT             ; the floor behind it...
        pop  dx
        pop  cx
        test al,G_FLOOR
        jz   .dn
        push cx
        push dx
        add  cx,[si]
        add  dx,[si+2]
        call GRIDAT             ; ...the outside in front
        pop  dx
        pop  cx
        test al,G_OUT
        jz   .dn
        mov  ax,cx              ; |c - sc| + |r - sr|
        sub  al,[sc]
        jns  .a1
        neg  al
.a1:    mov  bl,dl
        sub  bl,[sr]
        jns  .a2
        neg  bl
.a2:    add  al,bl
        xor  ah,ah
        cmp  ax,[gbest]
        jae  .dn
        mov  [gbest],ax         ; the nearest so far
        mov  [gatec],cx
        mov  [gater],dx
        mov  ax,[si]
        mov  [gdc],ax
        mov  ax,[si+2]
        mov  [gdr],ax
        mov  byte [hasgate],1
.dn:    add  si,4
        cmp  si,GDIRS+16
        jb   .dir
.next:  inc  cx
        cmp  cl,[lvw]
        jb   .col
        inc  dx
        cmp  dl,[lvh]
        jb   .row
        cmp  byte [hasgate],0
        je   .r
        mov  ax,[gater]
        mov  cl,5
        shl  ax,cl
        add  ax,[gatec]
        mov  [gatecell],ax
.r:     ret

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
        mov  byte [dirty],1
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
        xor  ax,ax
        mov  [bx+P_SCORE],ax
        mov  [bx+P_GAIN],ax
        mov  [bx+P_STUN],ax
        mov  [bx+P_COOL],ax
        mov  [bx+P_OUT],al
        mov  [bx+P_HHEAD],ax    ; no steps to take back (and P_HCNT)
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
        cmp  byte [phase],0
        je   .place
        mov  byte [bx+P_OUT],MAXP ; the gate is up: he waits outside
        jmp  .in
.place: push bx
        call FREECELL           ; BX -> his cell
        mov  si,bx
        pop  bx
        jc   .out
        or   byte [si],G_MAN
        xchg bx,si              ; SETPOS: SI the player, BX the cell
        call SETPOS
        xchg bx,si
.in:    mov  byte [netdirty],1
        mov  byte [dirty],1
.have:  clc
        ret
.out:   mov  byte [bx+P_ON],0   ; no free floor: not in after all
        stc
        ret

; DROPMAN - player BX gone: his man off the floor, his slot free
DROPMAN:call MANOFF
        mov  byte [bx+P_ON],0
        mov  byte [netdirty],1
        mov  byte [dirty],1
        ret
; MANOFF - player BX's man off his cell.  clobbers AX, CL, SI.
MANOFF: mov  al,[bx+P_ROW]
        xor  ah,ah
        mov  cl,5
        shl  ax,cl              ; row * 32
        add  al,[bx+P_COL]      ; + column: no carry, it is < 32
        add  ax,grid
        mov  si,ax
        and  byte [si],0FFh xor G_MAN
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
;  the grid until one adds nothing.
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
;  LIVEGEN - the cells a crate could still be pushed home from, walls
;  only counted (live, a bit a cell): back from every goal, a crate
;  pulled - the cell it is pulled onto and the one the man then stands
;  on must both be floor.  A crate anywhere else - in a corner, at the
;  foot of a wall with no goal along it - is there for good.
; ------------------------------------------------------------------
LIVEGEN:push ds
        pop  es
        mov  di,live
        mov  cx,NCOL*NCOL/16
        xor  ax,ax
        rep  stosw              ; none yet
        mov  si,bfsq            ; the queue: SI its head, DI its tail
        mov  di,bfsq
        mov  bx,grid
.g:     mov  al,[bx]
        and  al,G_GOAL or G_FLOOR
        cmp  al,G_GOAL or G_FLOOR
        jne  .gn
        call .mark              ; every goal: a crate there is home
.gn:    inc  bx
        cmp  bx,grid+NCOL*NCOL
        jb   .g
.take:  cmp  si,di
        jae  .r
        mov  bx,[si]
        add  si,2
        mov  dx,-1              ; pulled left,
        call .pull
        mov  dx,1               ;  right,
        call .pull
        mov  dx,-NCOL           ;  up,
        call .pull
        mov  dx,NCOL            ;  down
        call .pull
        jmp  .take
.r:     ret
.pull:  push bx
        add  bx,dx              ; where the crate comes to
        test byte [bx],G_FLOOR
        jz   .pn
        mov  bp,bx
        add  bp,dx              ; where the man then stands (SS = DS)
        test byte [bp],G_FLOOR
        jz   .pn
        call LIVEAT
        jnz  .pn                ; known already
        call .mark
.pn:    pop  bx
        ret
.mark:  call LIVEAT
        or   [bp],al            ; live...
        mov  [di],bx            ; ...and queued
        add  di,2
        ret

; LIVEAT - is cell BX (a pointer into grid) live?  ZF=0 yes.  Out: BP ->
; its byte of live, AL its bit.  clobbers CL.
LIVEAT: mov  ax,bx
        sub  ax,grid
        mov  cl,al
        and  cl,7               ; the bit,
        shr  ax,1
        shr  ax,1
        shr  ax,1               ;  the byte: cell / 8
        add  ax,live
        mov  bp,ax
        mov  al,1
        shl  al,cl
        test [bp],al
        ret

; ------------------------------------------------------------------
;  STUCK - a crate that can no longer go home, so the level is lost: on
;  a cell no push brings home (LIVEGEN), or in a square of four that are
;  all crates and walls - none of them can ever move again.  [stuckc]:
;  its cell, or 0FFFFh.  Every machine sees it in the floor it draws, and
;  the news line offers the way out.  The pilot: "the program could tell
;  the level cannot be won, and offer to play it again".
; ------------------------------------------------------------------
STUCK:  mov  word [stuckc],0FFFFh
        cmp  byte [phase],0
        jne  .r
        mov  bx,grid
.c:     mov  al,[bx]
        and  al,G_BOX or G_GOAL
        cmp  al,G_BOX
        jne  .n                 ; no crate, or one home
        call LIVEAT
        jz   .yes               ; where no push brings it home
        mov  si,bx              ; the four squares it is in: its own,
        call .sq                ;  with it top left,
        jc   .yes
        dec  si                 ;  top right,
        call .sq
        jc   .yes
        sub  si,NCOL            ;  bottom right,
        call .sq
        jc   .yes
        inc  si                 ;  bottom left
        call .sq
        jc   .yes
.n:     inc  bx
        cmp  bx,grid+NCOL*NCOL
        jb   .c
.r:     ret
.yes:   sub  bx,grid
        mov  [stuckc],bx
        ret
.sq:    test byte [si],G_WALL or G_BOX  ; CF=1: the square at SI (its top
        jz   .open                      ;  left) all crates and walls
        test byte [si+1],G_WALL or G_BOX
        jz   .open
        test byte [si+NCOL],G_WALL or G_BOX
        jz   .open
        test byte [si+NCOL+1],G_WALL or G_BOX
        jz   .open
        stc
        ret
.open:  clc
        ret

; ------------------------------------------------------------------
;  KEYS - one key from the BIOS, if one waits.  After a step the rest of
;  the buffer is thrown away: a key held down repeats faster than a step
;  goes to the host and back, and a pile of them walks the man on long
;  after the key is up (the testers' "sticking keys").
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
        cmp  byte [phase],3
        je   .end               ; the winner's moment: the next level comes
if defined TESTKEYS             ; FASM -d TESTKEYS=1: a test build only
        cmp  ah,44h             ; F10: every crate home at once, to test
        jne  .nt                ;  what comes after (never shipped)
        jmp  TESTSOLVE
.nt:    cmp  ah,43h             ; F9: a diamond two cells left of your man
        jne  .nt2
        mov  si,[mep]
        mov  al,[si+P_ROW]
        xor  ah,ah
        mov  cl,5
        shl  ax,cl
        add  al,[si+P_COL]
        sub  ax,2
        mov  [gemcell],ax
        mov  word [gemclk],GEMLIFE
        mov  byte [dirty],1
        ret
.nt2:   cmp  ah,42h             ; F8: RING.DAT - where the DMA plays now,
        jne  .nt3               ;  then the ring's 32K as they are
        jmp  TESTRING
.nt3:   cmp  ah,41h             ; F7: the fanfare, straight to the mixer
        jne  .nt4
        mov  al,SF_WIN
        jmp  SFX
.nt4:   cmp  ah,40h             ; F6: the owl on a wall beside your man
        jne  .nt5
        mov  si,[mep]
        mov  al,[si+P_ROW]
        xor  ah,ah
        mov  cl,5
        shl  ax,cl
        add  al,[si+P_COL]
        mov  bx,ax
        mov  si,DSTEP
        mov  cx,4
.ow:    mov  di,bx
        add  di,[si]
        test byte [grid+di],G_WALL
        jnz  .owf
        add  si,2
        loop .ow
        ret
.owf:   mov  [owlcell],di
        mov  word [owlclk],364
        mov  byte [dirty],1
        mov  byte [netdirty],1
        ret
.nt5:
end if
        cmp  ah,39h             ; Space: a mine
        je   .mine
        cmp  ah,0Eh             ; Backspace (a Mac's delete) or U: a step
        je   .back              ;  back
        cmp  ah,16h
        je   .back
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
.dir:   call FLUSHKB
        mov  al,[bx+1]          ; 0 up, 1 right, 2 down, 3 left - as the
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
.back:  call FLUSHKB            ; held down, it repeats: no pile of them
        cmp  byte [netmode],2
        je   .breq
        mov  si,[mep]
        cmp  byte [si+P_ON],0
        je   .end
        jmp  UNSTEP
.breq:  mov  al,8               ; a client: the host keeps the history
        jmp  SENDM
.zoom:  cmp  byte [view],2
        je   .end               ; isometric: one size
        xor  byte [view],1      ; the whole level / close up
        jmp  VIEWSET
.iso:   cmp  byte [view],2
        je   .flat
        mov  al,[view]
        mov  [flatview],al      ; the straight-down view to come back to
        mov  byte [view],2
        jmp  VIEWSET
.flat:  mov  al,[flatview]
        mov  [view],al
        jmp  VIEWSET
.ccw:   dec  byte [turn]        ; a quarter turn back
        jmp  .tn
.cw:    inc  byte [turn]        ; a quarter turn on
.tn:    and  byte [turn],3      ; four of them
        jmp  VIEWSET
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
        mov  byte [dirty],1
        cmp  byte [netmode],2
        jne  LEVACT             ; alone or the host: ours to do
        mov  al,bl
        add  al,3               ; 4 anew, 5 next, 6 previous
        jmp  SENDM              ; a client: the host's to do

if defined TESTKEYS
; TESTSOLVE - the crates lifted off and set on the goals, as many as
; there are; then the level is solved the usual way
TESTSOLVE:
        cmp  byte [netmode],2
        je   .r
        cmp  byte [phase],0
        jne  .r
        xor  cx,cx
        mov  bx,grid
.c:     and  byte [bx],0FFh xor G_BOX
        test byte [bx],G_GOAL
        jz   .n
        test byte [bx],G_MAN
        jnz  .n
        or   byte [bx],G_BOX
        inc  cx
.n:     inc  bx
        cmp  bx,grid+NCOL*NCOL
        jb   .c
        mov  [nbox],cx
        mov  [ngood],cx
        jmp  SOLVE
.r:     ret
TESTRING:
        xor  bx,bx
        cmp  byte [sndon],0
        je   .pos
        call SFXRAW
.pos:   mov  [tring],bx
        mov  ax,[sbrst]
        mov  [tsbr],ax
        mov  ax,[sfxat]
        mov  [tsat],ax
        mov  al,[bst]           ; and the owl: its state, where it is,
        xor  ah,ah              ;  where it goes, when the next comes
        mov  [tbst],ax
        mov  ax,[bx_]
        mov  [tbx],ax
        mov  ax,[by_]
        mov  [tby],ax
        mov  ax,[btx]
        mov  [tbtx],ax
        mov  ax,[bty]
        mov  [tbty],ax
        mov  ax,[owlclk]        ; and the owl's clock
        mov  [tbn],ax
        mov  ax,[lx0]           ; and the dusk's numbers
        mov  [tlx0],ax
        mov  ax,[lx1]
        mov  [tlx1],ax
        mov  ax,[ly0]
        mov  [tly0],ax
        mov  ax,[ly1]
        mov  [tly1],ax
        mov  al,[TXF]           ; how far the screen's left edge is across
        xor  ah,ah              ;  its margin, and the top row
        mov  [td1],ax
        mov  al,[TYF+PFTOP]
        mov  [td2],ax
        mov  dx,TRINGF
        xor  cx,cx
        mov  ah,3Ch
        int  21h                ; create RING.DAT
        jc   .r
        mov  bx,ax
        mov  dx,tring
        mov  cx,32              ; (and the test words after it)
        mov  ah,40h
        int  21h                ; the position
        push ds
        mov  ds,[rseg]
        xor  dx,dx
        mov  cx,SNDN
        mov  ah,40h
        int  21h                ; the ring
        pop  ds
        mov  ah,3Eh
        int  21h
.r:     ret
TRINGF  db 'RING.DAT',0
tring   dw 0
tsfx    dw 0
tsbr    dw 0
tsat    dw 0
tbst    dw 0
tbx     dw 0
tby     dw 0
tbtx    dw 0
tbty    dw 0
tbn     dw 0
tlx0    dw 0
tlx1    dw 0
tly0    dw 0
tly1    dw 0
td1     dw 0
td2     dw 0
end if

; FLUSHKB - the BIOS's key buffer emptied: its head made its tail
FLUSHKB:push ds
        xor  ax,ax
        mov  ds,ax
        cli
        mov  ax,[041Ah]
        mov  [041Ch],ax
        sti
        pop  ds
        ret

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
;  MOVE - your man one step.  in: AL = 0 up, 1 right, 2 down, 3 left
;  (the grid's directions).
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

; STEP - player SI one step of DX grid bytes (the host's, for anyone).
; Into the open gate: out.  A crate in the way goes too, if the cell
; behind it is floor with nothing on it; a crate rolled onto the diamond
; takes it, for him.  A candy or the diamond where he lands: his too.
STEP:   mov  [sdx],dx           ; for his history
        mov  byte [spush],0
        cmp  word [si+P_STUN],0
        jne  .no                ; standing still after a blast: no step
        cmp  byte [si+P_OUT],0
        jne  .no                ; out already
        cmp  byte [phase],3
        je   .no
        mov  al,[si+P_ROW]
        xor  ah,ah
        mov  cl,5
        shl  ax,cl              ; row * 32
        add  al,[si+P_COL]      ; + column: no carry, the column is < 32
        add  ax,grid
        mov  di,ax              ; DI -> the man's cell
        mov  bx,ax
        add  bx,dx              ; BX -> the cell he steps into
        cmp  byte [phase],2
        jne  .in
        mov  ax,bx
        sub  ax,grid
        cmp  ax,[gatecell]      ; the gate is up and he walks into it
        jne  .in
        jmp  EXITMAN
.in:    mov  ax,bx
        sub  ax,grid
        cmp  ax,[owlcell]       ; into the owl's wall: caught
        jne  .in2
        jmp  CATCH
.in2:   mov  al,[bx]
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
        mov  cx,bp
        sub  cx,grid
        cmp  cx,[gemcell]       ; the crate rolls onto the diamond: it
        jne  .push              ;  takes it, for the man who pushed it
        mov  word [gemcell],0FFFFh
        push ax
        call GEMWAITS
        mov  cx,25
        call SCORE
        pop  ax
.push:  mov  byte [spush],4
        and  byte [bx],0FFh xor G_BOX   ; the crate leaves...
        or   byte [bp],G_BOX            ; ...and lands
        test al,G_GOAL
        jz   .off
        mov  cx,-10             ; off a goal: -10
        call SCORE
        dec  word [ngood]
.off:   test ah,G_GOAL
        jz   .walk
        mov  cx,10              ; onto a goal: +10
        call SCORE
        inc  word [ngood]
.walk:  and  byte [di],0FFh xor G_MAN
        or   byte [bx],G_MAN
        call SETPOS
        test byte [bx],G_CANDY
        jz   .gem
        and  byte [bx],0FFh xor G_CANDY ; a candy: eaten
        dec  word [ncandy]
        push bx
        mov  ax,bx
        sub  ax,grid
        call CANDYV
        inc  ax
        mov  cx,ax
        call SCORE
        pop  bx
.gem:   mov  ax,bx
        sub  ax,grid
        cmp  ax,[gemcell]
        jne  .moved
        mov  word [gemcell],0FFFFh ; the diamond: his
        call GEMWAITS
        mov  cx,25
        call SCORE
.moved: call HREC
        inc  word [moves]
.done:  mov  byte [dirty],1
        mov  byte [netdirty],1  ; the room hears of it at the next tick
        cmp  byte [phase],0
        jne  .no
        mov  ax,[ngood]
        cmp  ax,[nbox]          ; every crate home?
        jne  .no
        jmp  SOLVE
.no:    ret

; HREC - the step [sdx] player SI just made into his history, +4 if a
; crate went too ([spush]); past NHIST the oldest is forgotten
HREC:   xor  ax,ax
        mov  dx,[sdx]
        cmp  dx,-NCOL           ; 0 up,
        je   .d
        inc  ax
        cmp  dx,1               ;  1 right,
        je   .d
        inc  ax
        cmp  dx,NCOL            ;  2 down, 3 left
        je   .d
        inc  ax
.d:     or   al,[spush]
        mov  bl,[si+P_HHEAD]
        xor  bh,bh
        mov  [si+P_HIST+bx],al
        inc  bx
        and  bl,NHIST-1
        mov  [si+P_HHEAD],bl
        cmp  byte [si+P_HCNT],NHIST
        jae  .r
        inc  byte [si+P_HCNT]
.r:     ret

; UNSTEP - player SI's last step taken back (Backspace, U): the man to the
; cell he came from and a crate he pushed pulled back after him - if the
; cells are as he left them (another man may stand where he came from,
; or have pushed his crate on: then nothing).  The points go back with
; the crate, by the rule of any push; candies eaten stay eaten.  While
; the gate is down only; the host's - a client asks for it ('M' 8).
UNSTEP: cmp  byte [phase],0
        jne  .no
        cmp  word [si+P_STUN],0
        jne  .no                ; standing still after a blast
        cmp  byte [si+P_HCNT],0
        je   .no                ; nothing to take back
        mov  bl,[si+P_HHEAD]
        xor  bh,bh
        dec  bx
        and  bx,NHIST-1         ; his last step
        mov  [hidx],bl
        mov  al,[si+P_HIST+bx]
        mov  [hent],al
        and  ax,3
        shl  ax,1
        mov  bx,ax
        mov  dx,[DSTEP+bx]      ; DX = the step he made
        mov  al,[si+P_ROW]
        xor  ah,ah
        mov  cl,5
        shl  ax,cl
        add  al,[si+P_COL]
        add  ax,grid
        mov  di,ax              ; DI -> where he stands
        mov  bx,ax
        sub  bx,dx              ; BX -> where he came from
        test byte [bx],G_WALL or G_BOX or G_MAN
        jnz  .no
        test byte [bx],G_FLOOR
        jz   .no
        test byte [hent],4
        jz   .walk
        mov  bp,di
        add  bp,dx              ; BP -> where his crate went
        test byte [bp],G_BOX
        jz   .no                ; gone on since
        and  byte [bp],0FFh xor G_BOX   ; the crate back...
        or   byte [di],G_BOX            ; ...where he stood
        test byte [bp],G_GOAL
        jz   .off
        mov  cx,-10             ; off a goal: -10
        call SCORE
        dec  word [ngood]
.off:   test byte [di],G_GOAL
        jz   .walk
        mov  cx,10              ; onto one: +10
        call SCORE
        inc  word [ngood]
.walk:  and  byte [di],0FFh xor G_MAN
        or   byte [bx],G_MAN
        call SETPOS
        mov  al,[hidx]
        mov  [si+P_HHEAD],al
        dec  byte [si+P_HCNT]
        cmp  word [moves],0
        je   .gem
        dec  word [moves]
.gem:   mov  ax,bx
        sub  ax,grid
        cmp  ax,[gemcell]       ; the diamond grew where he steps back to:
        jne  .ok                ;  his, as on any step
        mov  word [gemcell],0FFFFh
        call GEMWAITS
        mov  cx,25
        call SCORE
.ok:    jmp  STEP.done          ; (a crate pulled home can end the level)
.no:    ret

; CATCH - player SI walked into the wall the owl sits on: his, +10, and
; it is off; the next comes later.  The pilot: "catch the bird sitting
; on the wall, +10".  (Not a step: nothing to take back.)
CATCH:  mov  word [owlcell],0FFFFh
        inc  byte [owlcatch]    ; every machine hears it caught
        mov  cx,10
        call SCORE
        call OWLWAIT
        mov  byte [dirty],1
        mov  byte [netdirty],1
        ret

; OWLSPAWN - the owl onto a wall by lot: one with floor beside it, so a
; man can walk into it, never the gate: 3 to 5 s flying in (each
; machine's own flight), then 15 to 22 s sitting.  No wall found: again
; in 5 s.
OWLSPAWN:
        mov  byte [btries],24
.try:   call RND
        mov  al,ah
        xor  ah,ah
        mov  bl,[lvw]
        div  bl
        mov  cl,ah              ; a column
        call RND
        mov  al,ah
        xor  ah,ah
        mov  bl,[lvh]
        div  bl                 ; AH = a row
        mov  al,ah
        xor  ah,ah
        push cx
        mov  cl,5
        shl  ax,cl              ; row * 32
        pop  cx
        add  al,cl              ; + column: no carry, it is < 32
        mov  bx,ax
        test byte [grid+bx],G_WALL
        jz   .again
        cmp  bx,[gatecell]
        je   .again
        mov  al,[grid+bx-1]     ; floor beside it, one of the four ways
        or   al,[grid+bx+1]
        or   al,[grid+bx-NCOL]
        or   al,[grid+bx+NCOL]
        test al,G_FLOOR
        jz   .again
        mov  [owlcell],bx
        call RND
        mov  al,ah
        and  ax,127
        add  ax,364             ; 20..27 s: a few to fly in, 15..22 sitting
        mov  [owlclk],ax
        mov  byte [netdirty],1
        mov  byte [dirty],1
        ret
.again: dec  byte [btries]
        jnz  .try
        mov  word [owlclk],91
        ret

; OWLWAIT - the next owl in 30 to 58 s
OWLWAIT:call RND
        mov  al,ah
        xor  ah,ah
        shl  ax,1               ; 0..510 ticks
        add  ax,546             ;  + 30 s
        mov  [owlclk],ax
        ret

; CLRHIST - every man's history forgotten: a new level, a new host
CLRHIST:mov  bx,players
.p:     mov  word [bx+P_HHEAD],0        ; P_HHEAD and P_HCNT
        add  bx,PSIZE
        cmp  bx,players+MAXP*PSIZE
        jb   .p
        ret

; SCORE - CX points to player SI: his score and this level's
SCORE:  add  [si+P_SCORE],cx
        add  [si+P_GAIN],cx
        ret

; SOLVE - every crate home: the gate rises.  No gate in this level: the
; level is the winner's at once, +50 to every man.
SOLVE:  mov  word [gemcell],0FFFFh ; the diamond goes back into the floor
        mov  byte [netdirty],1
        mov  byte [dirty],1
        cmp  byte [hasgate],0
        je   .nogate
        mov  byte [phase],1
        mov  word [pclk],PH1T
        mov  byte [nout],0
        ret
.nogate:mov  si,players
.p:     cmp  byte [si+P_ON],0
        je   .n
        mov  cx,50
        call SCORE
.n:     add  si,PSIZE
        cmp  si,players+MAXP*PSIZE
        jb   .p
        jmp  ENDLEV

; EXITMAN - player SI walks out through the gate: +50, the first +75;
; when nobody is left inside, the level ends
EXITMAN:push si
        mov  bx,si
        call MANOFF
        pop  si
        inc  byte [nout]
        mov  al,[nout]
        mov  [si+P_OUT],al
        mov  cx,50
        cmp  al,1
        jne  .pts
        add  cx,25              ; the first out
.pts:   call SCORE
        mov  byte [netdirty],1
        mov  byte [dirty],1
        mov  bx,players         ; anybody still inside?
.p:     cmp  byte [bx+P_ON],0
        je   .n
        cmp  byte [bx+P_OUT],0
        je   .r                 ; yes: the gate waits for them
.n:     add  bx,PSIZE
        cmp  bx,players+MAXP*PSIZE
        jb   .p
        jmp  ENDLEV
.r:     ret

; ENDLEV - the gate shuts: the winner, the one with most from this level
ENDLEV: mov  byte [phase],3
        mov  word [pclk],WINT
        mov  byte [winner],0FFh
        mov  word [wbest],8000h ; below anyone's
        mov  bx,players
        xor  cl,cl
.p:     cmp  byte [bx+P_ON],0
        je   .n
        mov  ax,[bx+P_GAIN]
        cmp  ax,[wbest]
        jle  .n
        mov  [wbest],ax
        mov  [winner],cl
.n:     add  bx,PSIZE
        inc  cl
        cmp  bx,players+MAXP*PSIZE
        jb   .p
        mov  byte [netdirty],1
        mov  byte [dirty],1
        ret

; GEMWAITS - the next diamond in 20..27 s
GEMWAITS:
        call RND
        mov  al,ah
        and  ax,127
        add  ax,GEMWAIT
        mov  [gemclk],ax
        ret

; ------------------------------------------------------------------
;  TIMERS - the BIOS tick: the birds, the owl, the host's clocks, a
;  question's end, the animation's beat.
; ------------------------------------------------------------------
TIMERS: call TICK               ; the BIOS tick, 18.2 a second
        mov  [now],ax
        call BIRDS              ; a song now and then
        call BIRDTICK           ; the owl
        cmp  byte [netmode],2
        je   .pend              ; a client: the host keeps every clock
        call TICKER
.pend:  cmp  byte [pend],0
        je   .anim
        mov  ax,[now]
        sub  ax,[pendt]
        cmp  ax,PENDT
        jb   .anim
        mov  byte [pend],0      ; not pressed again: forget it
        mov  byte [dirty],1
.anim:  mov  ax,[now]           ; a frame every second tick, 9 a second:
        shr  ax,1               ;  the candies glint each on its own
        cmp  ax,[fstep]         ;  moments, the points rise
        je   .beat
        mov  [fstep],ax
        mov  byte [dirty],1
.beat:  mov  ax,[now]           ; the beat of everything that moves: a
        mov  cl,3               ;  step every 8 ticks, two to a heartbeat
        shr  ax,cl              ;  at rest (68 a minute) - the pilot: calm
        cmp  al,[anim]          ;  after work, a pulse, no hurry
        je   .r
        mov  [anim],al
        mov  byte [dirty],1
.r:     ret

; ------------------------------------------------------------------
;  TICKER - the host's clocks (and the lone player's), run on the ticks
;  since the last frame: each man's standing still and his wait for the
;  next mine; the fuses; the blasts; the gate's phases; the diamond.
;  While any clock runs, the world goes out again twice a second.
; ------------------------------------------------------------------
TICKER: mov  ax,[now]
        mov  dx,ax
        sub  dx,[lastt]         ; ticks since the last frame
        jnz  .go
        ret
.go:    mov  [lastt],ax
        cmp  dx,36
        jbe  .d
        mov  dx,36              ; after a stall: two seconds at most
.d:     mov  [tdt],dx
        mov  byte [act],0
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
        mov  al,[phase]         ; the gate
        or   al,al
        jz   .gem
        mov  byte [act],1
        mov  ax,[pclk]
        sub  ax,[tdt]
        mov  [pclk],ax
        jg   .beat
        mov  al,[phase]
        cmp  al,1
        jne  .ph2
        mov  byte [phase],2     ; up: out through it
        mov  word [pclk],EXITT
        jmp  .chg
.ph2:   cmp  al,2
        jne  .ph3
        call ENDLEV             ; shut: the winner
        jmp  .beat
.ph3:   mov  ax,[level]         ; the winner shown: the next level
        inc  ax
        cmp  ax,NLEVELS
        jb   .lv
        xor  ax,ax              ; after the last, the first again
.lv:    mov  [level],ax
        jmp  NEWLEV
.chg:   mov  byte [netdirty],1
        mov  byte [dirty],1
        jmp  .beat
.gem:   mov  ax,[gemclk]        ; the diamond's clock
        sub  ax,[tdt]
        mov  [gemclk],ax
        jg   .gk
        cmp  word [gemcell],0FFFFh
        jne  .gone
        call GEMSPAWN           ; time for one
        jmp  .gk
.gone:  mov  word [gemcell],0FFFFh ; not taken: back into the floor
        call GEMWAITS
        mov  byte [netdirty],1
        mov  byte [dirty],1
.gk:    cmp  word [gemcell],0FFFFh
        je   .owl
        mov  byte [act],1       ; it grows, it sparkles: keep drawing
.owl:   mov  ax,[owlclk]        ; the owl's clock: to come, or to go
        sub  ax,[tdt]
        mov  [owlclk],ax
        jg   .ok
        cmp  word [owlcell],0FFFFh
        jne  .ogo
        call OWLSPAWN           ; time for one
        jmp  .ok
.ogo:   mov  word [owlcell],0FFFFh ; not caught: off it flies
        call OWLWAIT
        mov  byte [netdirty],1
        mov  byte [dirty],1
.ok:    cmp  word [owlcell],0FFFFh
        je   .beat
        mov  byte [act],1       ; sitting: its clock goes out too
.beat:  cmp  byte [act],0
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
        sub  ax,[tdt]            ; down by the ticks...
        jnc  .z
        xor  ax,ax              ; ...to 0, never under
.z:     ret

; GEMSPAWN - a diamond on a free floor cell, by lot: no crate, no man,
; no goal, no candy, no mine; none free - try again in 5 s
GEMSPAWN:
        xor  cx,cx              ; how many cells will do
        mov  bx,grid
.c:     call .ok
        jnz  .cn
        inc  cx
.cn:    inc  bx
        cmp  bx,grid+NCOL*NCOL
        jb   .c
        jcxz .none
        call RND
        xor  dx,dx
        div  cx                 ; DX = which of them
        mov  bx,grid
.f:     call .ok
        jnz  .fn
        or   dx,dx
        jz   .here
        dec  dx
.fn:    inc  bx
        jmp  .f
.here:  sub  bx,grid
        mov  [gemcell],bx
        mov  word [gemclk],GEMLIFE
        mov  byte [netdirty],1
        mov  byte [dirty],1
        ret
.none:  mov  word [gemclk],FUSE
        ret
; .ok - ZF=1: cell BX takes a diamond.  keeps CX, DX, BX.
.ok:    mov  al,[bx]
        and  al,G_FLOOR or G_BOX or G_MAN or G_GOAL or G_CANDY
        cmp  al,G_FLOOR
        jne  .r
        mov  ax,bx
        sub  ax,grid
        push si
        call MINEAT
        pop  si
        jc   .yes               ; no mine there
        or   al,1               ; (ZF clear: a mine)
        ret
.yes:   cmp  al,al
.r:     ret

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
        cmp  byte [bx+P_OUT],0
        jne  .n                 ; out of the gate: out of reach
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
        cmp  byte [si+P_OUT],0
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
;  CAMERA - ox, oy: where the turned grid's corner lands.  A level that
;  fits is centred; a bigger one (close up, isometric) follows your man,
;  who walks the middle half of the screen freely before it scrolls.
; ------------------------------------------------------------------
CAMERA: call TURNED
        mov  al,[trows]
        xor  ah,ah
        dec  ax
        imul word [vrx]         ; (trows-1)*RX: 0, or the left corner
        mov  [xmin],ax
        mov  al,[tcols]
        xor  ah,ah
        dec  ax
        imul word [vcx]         ; (tcols-1)*CX
        add  ax,[vsw]           ; + a tile: the right edge
        sub  ax,[xmin]
        mov  [wpx],ax           ; the width in px
        mov  al,[tcols]
        xor  ah,ah
        dec  ax
        imul word [vcy]
        mov  cx,ax
        mov  al,[trows]
        xor  ah,ah
        dec  ax
        imul word [vry]
        add  ax,cx
        add  ax,[vsh]           ; the bottom edge
        sub  ax,[vlift]         ; and the walls stand above the top
        mov  [hpx],ax
        mov  ax,[vlift]
        neg  ax
        mov  [wtop],ax          ; how high above oy they rise
        mov  si,[mep]
        mov  al,[si+P_ROW]
        xor  ah,ah
        mov  cl,5
        shl  ax,cl              ; row * 32
        add  al,[si+P_COL]      ; + column: his cell
        call CELLXY             ; AX = x, DX = y of his tile
        mov  cx,[vsw]
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
.xset:  and  ax,0FFFEh          ; a whole byte: two pixels
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
;  SNDDIFF - the castle as it is against how it was at the last frame:
;  what changed, heard.  The same on every machine - a client hears
;  what the host's world brings, the host what it did - so nothing of
;  the sound goes over the wire.
; ------------------------------------------------------------------
SNDDIFF:mov  ax,[level]
        cmp  ax,[s_level]
        jne  .snap              ; a new level: nothing to compare yet
        cmp  byte [sndon],0
        je   .snap
        mov  ax,[ngood]
        cmp  ax,[s_ngood]
        je   .push
        mov  al,SF_HOME
        ja   .home
        mov  al,SF_OFF
.home:  call SFX
        jmp  .mines
.push:  call BOXSUM
        cmp  ax,[s_boxsum]
        je   .mines
        mov  al,SF_PUSH
        call SFX
.mines: xor  bx,bx              ; each mine: laid, its seconds, the blast
.m:     push bx
        call MSTATE             ; AL = 0 none, 1 burning, 2 blast; AH = secs
        mov  cl,[s_mst+bx]
        mov  ch,[s_msec+bx]
        pop  bx
        cmp  cl,0
        jne  .m1
        cmp  al,1
        jne  .mn
        mov  al,SF_LAY
        jmp  .msfx
.m1:    cmp  cl,1
        jne  .mn
        cmp  al,2
        jne  .m2
        mov  al,SF_BOOM
        jmp  .msfx
.m2:    cmp  al,1
        jne  .mn
        cmp  ah,ch
        je   .mn
        mov  al,SF_TICK
.msfx:  push bx
        call SFX
        pop  bx
.mn:    inc  bx
        cmp  bx,MAXP
        jb   .m
        mov  ax,[ncandy]        ; a candy eaten
        cmp  ax,[s_ncandy]
        jae  .gem
        mov  al,SF_CANDY
        call SFX
.gem:   mov  ax,[gemcell]       ; the diamond: up, or taken
        cmp  ax,[s_gem]
        je   .ph
        cmp  word [s_gem],0FFFFh
        jne  .gtake
        mov  al,SF_GEMUP
        call SFX
        jmp  .ph
.gtake: mov  bx,[s_gem]         ; gone: is a man or a crate on its cell?
        cmp  bx,NCOL*NCOL       ;  (taken; else it went back into the floor)
        jae  .ph
        test byte [grid+bx],G_MAN or G_BOX
        jz   .ph
        mov  al,SF_GEMGET
        call SFX
.ph:    mov  al,[owlcatch]      ; an owl caught
        cmp  al,[s_ocatch]
        je   .ph0
        mov  al,SF_CATCH
        call SFX
.ph0:   mov  al,[phase]         ; the gate
        cmp  al,[s_phase]
        je   .out
        mov  ah,[s_phase]
        mov  bl,SF_GATE
        cmp  al,1
        je   .phs
        mov  bl,SF_THUD
        cmp  al,2
        je   .phs
        mov  bl,SF_WIN
        cmp  al,3
        jne  .out
.phs:   mov  al,bl
        call SFX
.out:   call NOUTS              ; another man out through the gate
        cmp  al,[s_nout]
        jbe  .snap
        mov  al,SF_OUT
        call SFX
.snap:  mov  ax,[level]         ; now is how it was, for the next time
        mov  [s_level],ax
        mov  ax,[ngood]
        mov  [s_ngood],ax
        call BOXSUM
        mov  [s_boxsum],ax
        xor  bx,bx
.sm:    push bx
        call MSTATE
        pop  bx
        mov  [s_mst+bx],al
        mov  [s_msec+bx],ah
        inc  bx
        cmp  bx,MAXP
        jb   .sm
        mov  ax,[ncandy]
        mov  [s_ncandy],ax
        mov  ax,[gemcell]
        mov  [s_gem],ax
        mov  al,[phase]
        mov  [s_phase],al
        mov  al,[owlcatch]
        mov  [s_ocatch],al
        call NOUTS
        mov  [s_nout],al
        ret

; MSTATE - mine BX's state: AL 0 none, 1 burning (AH its seconds), 2 blast
MSTATE: push bx
        shl  bx,1
        shl  bx,1               ; 4 bytes a mine
        xor  ax,ax
        cmp  word [mines+bx+M_CELL],0FFFFh
        je   .r
        mov  ax,word [mines+bx+M_LEFT]
        or   ax,ax
        jle  .blast
        call SECS
        mov  ah,al
        mov  al,1
        pop  bx
        ret
.blast: mov  ax,2
.r:     pop  bx
        ret

; BOXSUM - AX = the crates' cells summed: it changes when one moves
BOXSUM: xor  ax,ax
        mov  bx,grid
.b:     test byte [bx],G_BOX
        jz   .n
        add  ax,bx
.n:     inc  bx
        cmp  bx,grid+NCOL*NCOL
        jb   .b
        ret

; NOUTS - AL = how many men are out through the gate
NOUTS:  xor  al,al
        mov  bx,players
.p:     cmp  byte [bx+P_ON],0
        je   .n
        cmp  byte [bx+P_OUT],0
        je   .n
        inc  al
.n:     add  bx,PSIZE
        cmp  bx,players+MAXP*PSIZE
        jb   .p
        ret

; ------------------------------------------------------------------
;  NETPOLL - once a frame: every packet that came, then the clocks -
;  players not heard, a host gone quiet, our own heartbeat.
;  The host takes 'H' and 'M' from anyone: a name it has not got gets a
;  man.  Everyone takes 'W': a client from its host or a lower name; a
;  host from a LOWER name only, and then works in that one's castle -
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
        cmp  al,8
        je   .back
        cmp  al,6
        ja   .rx                ; no such order: dropped
        sub  al,3               ; 1 anew, 2 next, 3 previous
        mov  bl,al
        call LEVACT
        jmp  .rx
.mine:  mov  si,bx              ; his mine, if he has one
        call PLACEMINE
        jmp  .rx
.back:  mov  si,bx              ; his last step taken back, if it can be
        call UNSTEP
        jmp  .rx
.step:  xor  ah,ah
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
        jmp  .take              ; it is lower: we work in its castle
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
; castle from the world we last drew.  Another's: we wait for it.
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
        mov  [lastt],ax         ; the clocks run from now
        mov  bx,players
.h:     mov  [bx+P_HEARD],ax    ; everyone heard now: the old host's man
        add  bx,PSIZE           ;  stays GONE ticks more, then goes
        cmp  bx,players+MAXP*PSIZE
        jb   .h
        call CLRHIST            ; no steps of ours to take back: we kept none
        cmp  word [mep],ghost
        jne  .in
        call ADDME              ; we had no man yet: now we have
.in:    mov  byte [netdirty],1
        mov  byte [dirty],1
.wait:  ret

; WSEND - the world, whole: the level and its phase, the men, the mines,
; every crate, every candy
WSEND:  mov  di,pkt
        mov  cx,NETLEN/2
        xor  ax,ax
        rep  stosw              ; zeros first: the candies' bits are ORed in
        mov  di,pkt
        mov  byte [di+K_KIND],'W'
        mov  byte [di+K_PROTO],PROTO
        mov  al,byte [level]
        mov  [di+W_LEVEL],al
        mov  al,[phase]
        mov  [di+W_PHASE],al
        mov  ax,[moves]
        mov  [di+W_MOVES],ax
        mov  al,[winner]
        mov  [di+W_WIN],al
        mov  ax,[pclk]
        mov  [di+W_PCLK],ax
        mov  ax,[gatecell]
        mov  [di+W_GATE],ax
        mov  ax,[gemcell]
        mov  [di+W_GEM],ax
        mov  ax,[gemclk]
        mov  [di+W_GCLK],ax
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
.c:     mov  al,[bx]
        test al,G_BOX
        jz   .cy
        cmp  dx,MAXBOX
        jae  .cy
        mov  ax,bx
        sub  ax,grid            ; its cell: row*32 + column
        stosw
        inc  dx
        mov  al,[bx]
.cy:    test al,G_CANDY         ; a candy: its bit
        jz   .cn
        mov  ax,bx
        sub  ax,grid
        cmp  ax,NCROW*NCOL
        jae  .cn
        push bx
        mov  bx,ax
        mov  cl,3
        shr  bx,cl              ; the byte: 8 cells each
        and  al,7
        mov  cl,al
        mov  al,1
        shl  al,cl
        or   [pkt+W_CANDY+bx],al
        pop  bx
.cn:    inc  bx
        cmp  bx,grid+NCOL*NCOL
        jb   .c
        mov  [pkt+W_NBOX],dl
        mov  ax,[owlcell]       ; the owl
        mov  word [pkt+W_OWL],ax
        mov  ax,[owlclk]
        mov  word [pkt+W_OCLK],ax
        mov  al,[owlcatch]
        mov  [pkt+W_OCATCH],al
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

; SENDM - AL: a step (0..3) or an order (4..7), to the host
SENDM:  mov  byte [pkt+K_KIND],'M'
        mov  byte [pkt+K_PROTO],PROTO
        mov  [pkt+K_ARG],al
        mov  si,pkt
        jmp  NETSEND

; ------------------------------------------------------------------
;  WAPPLY - the host's world (DI -> it) into ours.  Everything off the
;  wire is checked first: a level past the last drops the packet, a
;  crate or a man off the floor is left out, a name is made printable,
;  every clock kept in its range - a packet is someone else's word.
; ------------------------------------------------------------------
WAPPLY: mov  [wptr2],di
        mov  al,[di+W_LEVEL]
        xor  ah,ah
        cmp  ax,NLEVELS
        jae  .bad               ; no such level: not this game's world
        cmp  ax,[level]
        jne  .load
        cmp  byte [loaded],0
        jne  .keep
.load:  mov  [level],ax
        call LOADLEV            ; its walls, goals, floor and gate
.keep:  mov  di,[wptr2]
        mov  al,[di+W_PHASE]
        cmp  al,3
        jbe  .ph
        xor  al,al
.ph:    mov  [phase],al
        mov  ax,[di+W_MOVES]
        mov  [moves],ax
        mov  al,[di+W_WIN]
        cmp  al,MAXP
        jb   .wn
        mov  al,0FFh
.wn:    mov  [winner],al
        mov  ax,[di+W_PCLK]
        cmp  ax,EXITT
        jbe  .pc
        mov  ax,EXITT
.pc:    mov  [pclk],ax
        mov  ax,[di+W_GCLK]
        mov  [gemclk],ax
        mov  bx,grid            ; no crates, no men, no candies: the
.clr:   and  byte [bx],0FFh xor (G_BOX or G_MAN or G_CANDY) ; packet has them
        inc  bx
        cmp  bx,grid+NCOL*NCOL
        jb   .clr
        xor  ax,ax
        mov  [nbox],ax
        mov  [ngood],ax
        mov  [ncandy],ax
        mov  cl,[di+W_NBOX]
        xor  ch,ch
        cmp  cx,MAXBOX
        jbe  .cn
        mov  cx,MAXBOX
.cn:    lea  si,[di+W_BOXES]
        jcxz .cand
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
.cand:  mov  bx,grid            ; the candies: a floor cell's bit set
.cc:    mov  ax,bx
        sub  ax,grid
        cmp  ax,NCROW*NCOL
        jae  .men
        test byte [bx],G_FLOOR
        jz   .cnx
        push bx
        mov  si,ax
        mov  cl,3
        shr  si,cl
        add  si,[wptr2]
        mov  dl,[si+W_CANDY]    ; its byte...
        and  al,7
        mov  cl,al
        shr  dl,cl              ; ...its bit
        pop  bx
        test dl,1
        jz   .cnx
        or   byte [bx],G_CANDY
        inc  word [ncandy]
.cnx:   inc  bx
        jmp  .cc
.men:   mov  si,[wptr2]
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
        mov  di,[wptr2]         ; the diamond: on free floor, or none
        mov  ax,[di+W_GEM]
        cmp  ax,NCOL*NCOL
        jae  .nogem
        mov  bx,ax
        test byte [grid+bx],G_FLOOR
        jz   .nogem
        test byte [grid+bx],G_BOX
        jnz  .nogem
        mov  [gemcell],ax
        jmp  .mep
.nogem: mov  word [gemcell],0FFFFh
.mep:   mov  ax,[di+W_OWL]      ; the owl: on a wall, or none
        cmp  ax,NCOL*NCOL
        jae  .noowl
        mov  bx,ax
        test byte [grid+bx],G_WALL
        jnz  .owl
.noowl: mov  ax,0FFFFh
.owl:   mov  [owlcell],ax
        mov  ax,[di+W_OCLK]
        mov  [owlclk],ax
        mov  al,[di+W_OCATCH]
        mov  [owlcatch],al
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
; man on the grid (unless he is out through the gate); else out.
; clobbers AX, CL, SI, DI.
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
.cl:    cmp  byte [bx+P_OUT],MAXP
        jbe  .ou
        mov  byte [bx+P_OUT],MAXP
.ou:    lea  si,[bx+P_NAME]
        mov  di,si
        call COPYNAME           ; in place
        cmp  byte [bx+P_OUT],0
        jne  .ok                ; out of the gate: on no cell
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
.ok:    ret
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

        include 'DRAW.INC'
        include 'VIDEO.INC'
        include 'SOUND.INC'
        include 'MENU.INC'
        include 'SCENE.INC'
        include '..\..\ENGINE\E_NET.INC'  ; code and data: never run into
        include '..\..\ENGINE\E_MATH.INC' ; RND16, on rseed
        include '..\..\ENGINE\E_TERR.INC' ; DSGEN: the islands' Diamond-Square

; LANDGEN - the land round the castle: the engine's Diamond-Square on a
; 64x64 torus (the islands of OWL FLY are made by the same 4096 draws),
; seeded by the level so every machine - and ArtGen2's preview - grows the
; same park; the game's own generator left where it was.
LANDGEN:push word [rseed]
        mov  ax,[level]
        mov  bx,7919
        mul  bx                 ; (DX goes)
        add  ax,4242
        mov  [rseed],ax
        call DSGEN
        pop  word [rseed]
        ret

; LAND - AL = the land's height at cell CX, DX (signed): 0 the wettest,
; 255 the highest.  keeps everything but AX.
LAND:   push bx
        push cx
        mov  bx,cx
        and  bx,63
        mov  cl,6
        shl  bx,cl              ; (c AND 63) * 64
        mov  ax,dx
        and  ax,63
        add  bx,ax              ; + (r AND 63)
        mov  al,[HMAP+bx]
        pop  cx
        pop  bx
        ret

; ------------------------------------------------------------------
;  Data
; ------------------------------------------------------------------
MSGMEM  db 'MULTIPLAY SOKO II needs about 400 KB of free memory.',13,10,'$'
MSGCARD db 'MULTIPLAY SOKO II needs an EGA, a CGA or a Hercules card.',13,10,'$'
MSGART  db 'MULTIPLAY SOKO II cannot read ART.DAT: it belongs beside',13,10
        db 'MULTSOK2.COM (MAKE builds it from ART.ASM).',13,10,'$'
MSGBAD  db 'ART.DAT is not the one this MULTSOK2.COM was built with:',13,10
        db 'build both again with MAKE.',13,10,'$'
MSGFULL db 'MULTIPLAY SOKO II: the pictures outgrew their room.',13,10,'$'
MSGLEV  db 'MULTIPLAY SOKO II cannot read LEVELS.DAT: it belongs beside',13,10
        db 'MULTSOK2.COM (MAKE builds it from LEVELS.ASM).',13,10,'$'
TMAGIC  db 'SOKOART2'
TLMAGIC db 'SOKOLEV2'
TARTDAT db 'ART.DAT',0
TARTF   db 'ARTF.DAT',0
TFMAGIC db 'SOKOARTF'
hasfine db 0                    ; LOADF: ARTF.DAT is in bgseg
fmask   db 8 dup 0              ; COMPILEF: a row's see-through bits,
fcol    db 0                    ;  two pixels' colours
TLEVDAT db 'LEVELS.DAT',0
TNAME   db 'MULTIPLAY SOKO II',0
TLINES  dw 8,28
        db 14,'ARROWS OR W A S D  WALK, AND PUSH THE CRATE IN FRONT OF YOU',0
        dw 8,35
        db 7,'SPACE  YOUR MINE: 5 S, THEN THE 3X3 ROUND IT STANDS STILL 15 S',0
        dw 8,42
        db 7,'Q E  TURN THE VIEW     V  ISOMETRIC     Z  CLOSE UP',0
        dw 8,49
        db 7,'R R  THE LEVEL ANEW    N N, P P  THE NEXT, THE PREVIOUS    ESC  DOS',0
        dw 8,166
        db 10,'CANDY +1..3    THE DIAMOND +25    A CRATE HOME +10',0
        dw 8,173
        db 11,'ALL HOME: THE GATE RISES - OUT THROUGH IT +50, THE FIRST +75',0
        dw 0FFFFh
TPLAYER db 'PLAYER',0,0         ; a name nobody typed: 8 bytes, zero-padded
TWIRE   db ' THE WIRE: DIALING - ENTER PLAYS ALONE ',0
TLOOK   db ' LOOKING FOR THE CASTLE... ',0
TCOMING db ' COMING IN... ',0
SPIN    db '|/-\'
TLEV    db 'LEVEL ',0
TCRATE  db 'CRATES ',0
TMOVES  db 'MOVES ',0
TCANDY  db 'CANDY ',0
TALONE  db 'ALONE',0
THOST   db 'HOST',0
TONLINE db 'IN A ROOM',0
TOUT    db 'OUT',0
TRISE   db ' THE GATE IS RISING... ',0
TSTUCK  db 'STUCK: BACKSPACE STEPS BACK, R R ANEW',0
TWALK   db ' THE GATE IS UP: OUT THROUGH IT!  '
TWALKN  db '00 ',0
TWINNER db 'WINNER',0
TLEVPTS db ' THIS LEVEL',0
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
GDIRS   dw 0,1, 1,0, 0,-1, -1,0 ; FINDGATE's four ways out (ArtGen2's order)
; the looks: shirt, its shade, cap and trousers, their shade; 0 is yours
; (ArtGen2's looks, for its previews)
LOOKS   db 0Eh,6,9,1, 0Ch,4,0Ah,2, 0Bh,3,0Dh,5
        db 0Ah,2,0Ch,4, 0Fh,7,0Eh,6, 0Dh,5,0Bh,3
DIM16   db 0,0,0,1,0,1,4,8,0,1,2,3,4,5,6,7  ; each colour a step darker
; OWL FLY III's 4x6 letters (RESDAT.ASM), and what they lacked: ASCII 32
; to 95, five rows each, the high three bits of a row the pixels
FONT4   db 0,0,0,0,0                                        ; space
        db 01000000b,01000000b,01000000b,00000000b,01000000b ; !
        db 10100000b,10100000b,00000000b,00000000b,00000000b ; "
        db 10100000b,11100000b,10100000b,11100000b,10100000b ; #
        db 01100000b,11000000b,01000000b,01100000b,11000000b ; $
        db 10100000b,00100000b,01000000b,10000000b,10100000b ; %
        db 01000000b,10100000b,01000000b,10100000b,01100000b ; &
        db 01000000b,01000000b,00000000b,00000000b,00000000b ; '
        db 00100000b,01000000b,01000000b,01000000b,00100000b ; (
        db 10000000b,01000000b,01000000b,01000000b,10000000b ; )
        db 00000000b,10100000b,01000000b,10100000b,00000000b ; *
        db 00000000b,01000000b,11100000b,01000000b,00000000b ; +
        db 00000000b,00000000b,00000000b,01000000b,10000000b ; ,
        db 00000000b,00000000b,11100000b,00000000b,00000000b ; -
        db 00000000b,00000000b,00000000b,00000000b,01000000b ; .
        db 00100000b,00100000b,01000000b,10000000b,10000000b ; /
        db 11100000b,10100000b,10100000b,10100000b,11100000b ; 0
        db 01000000b,11000000b,01000000b,01000000b,11100000b ; 1
        db 11100000b,00100000b,11100000b,10000000b,11100000b ; 2
        db 11100000b,00100000b,11100000b,00100000b,11100000b ; 3
        db 10100000b,10100000b,11100000b,00100000b,00100000b ; 4
        db 11100000b,10000000b,11100000b,00100000b,11100000b ; 5
        db 11100000b,10000000b,11100000b,10100000b,11100000b ; 6
        db 11100000b,00100000b,01000000b,01000000b,01000000b ; 7
        db 11100000b,10100000b,11100000b,10100000b,11100000b ; 8
        db 11100000b,10100000b,11100000b,00100000b,11100000b ; 9
        db 00000000b,01000000b,00000000b,01000000b,00000000b ; :
        db 00000000b,01000000b,00000000b,01000000b,10000000b ; ;
        db 00100000b,01000000b,10000000b,01000000b,00100000b ; <
        db 00000000b,11100000b,00000000b,11100000b,00000000b ; =
        db 10000000b,01000000b,00100000b,01000000b,10000000b ; >
        db 11100000b,00100000b,01000000b,00000000b,01000000b ; ?
        db 11100000b,10100000b,11100000b,10000000b,11100000b ; @
        db 01000000b,10100000b,11100000b,10100000b,10100000b ; A
        db 11000000b,10100000b,11000000b,10100000b,11000000b ; B
        db 01100000b,10000000b,10000000b,10000000b,01100000b ; C
        db 11000000b,10100000b,10100000b,10100000b,11000000b ; D
        db 11100000b,10000000b,11000000b,10000000b,11100000b ; E
        db 11100000b,10000000b,11000000b,10000000b,10000000b ; F
        db 01100000b,10000000b,10100000b,10100000b,01100000b ; G
        db 10100000b,10100000b,11100000b,10100000b,10100000b ; H
        db 11100000b,01000000b,01000000b,01000000b,11100000b ; I
        db 00100000b,00100000b,00100000b,10100000b,01000000b ; J
        db 10100000b,11000000b,10000000b,11000000b,10100000b ; K
        db 10000000b,10000000b,10000000b,10000000b,11100000b ; L
        db 10100000b,11100000b,10100000b,10100000b,10100000b ; M
        db 11100000b,10100000b,10100000b,10100000b,10100000b ; N
        db 11100000b,10100000b,10100000b,10100000b,11100000b ; O
        db 11100000b,10100000b,11100000b,10000000b,10000000b ; P
        db 11100000b,10100000b,10100000b,11100000b,00100000b ; Q
        db 11000000b,10100000b,11000000b,10100000b,10100000b ; R
        db 11100000b,10000000b,11100000b,00100000b,11100000b ; S
        db 11100000b,01000000b,01000000b,01000000b,01000000b ; T
        db 10100000b,10100000b,10100000b,10100000b,11100000b ; U
        db 10100000b,10100000b,10100000b,10100000b,01000000b ; V
        db 10100000b,10100000b,10100000b,11100000b,10100000b ; W
        db 10100000b,10100000b,01000000b,10100000b,10100000b ; X
        db 10100000b,10100000b,01000000b,01000000b,01000000b ; Y
        db 11100000b,00100000b,01000000b,10000000b,11100000b ; Z
        db 11000000b,10000000b,10000000b,10000000b,11000000b ; [
        db 10000000b,10000000b,01000000b,00100000b,00100000b ; \
        db 01100000b,00100000b,00100000b,00100000b,01100000b ; ]
        db 01000000b,10100000b,00000000b,00000000b,00000000b ; ^
        db 00000000b,00000000b,00000000b,00000000b,11100000b ; _

; the state, in the order it is set up
gseg    dw 0                    ; the frame (and narrow, the background)
pseg    dw 0                    ; what the card shows now (narrow only)
bgseg   dw 0                    ; the background's segment...
bgoff   dw BGOFF                ;  ...and where in it
sseg    dw 0                    ; the compiled pictures,
sseg2   dw 0                    ;  EGA 640's second segment of them
picseg  dw 0                    ; the segment of the picture drawn next
tseg    dw 0                    ; DRAW: the buffer drawn into, the frame's
rseg    dw 0                    ; the sound ring
wide    db 0                    ; 1: EGA 640, the buffer 320 bytes a row
widemem db 0                    ; START: the memory holds EGA 640's segments
rowb    dw 160                  ; the buffer's bytes a row
vstride dw 40                   ; the EGA's plane bytes a row
capegaw db 0                    ; what this machine can show: EGA 640,
capega  db 0                    ;  EGA, CGA, Hercules - in CARD_ order, one
capcga  db 0                    ;  after the other (the menu counts on it)
caphgc  db 0
area    dw 0                    ; LOADART: the place it compiles into now
adi     dw 0                    ;  how far it is filled
pidx2   dw 0                    ;  the picture it is at
psrc    dw 0                    ;  where that one is in the file
areaseg dw 0,0,0                ; the places (LAYOUT's): sseg, (sseg2), the
arealo  dw 0,0,0                ;  ring's top - from,
areahi  dw 0,0,0                ;  to,
narea   dw 0                    ;  how many, *2
isvga   db 0                    ; a VGA: our own sixteen colours
card    db 0                    ; the chosen one: CARD_...
mono    db 0                    ; the menu on a monochrome screen
mcard   db 0
origmode db 0                   ; the text mode DOS lent us
vmode   db 0                    ; 1: a graphics mode is up
vfull   db 0                    ; 1: the next BLIT sends every row whole
vconv   dw 0                    ; the card's converter
sbok    db 0                    ; a Sound Blaster answered at 220h
sndwant db 0                    ; the menu's choice
sndon   db 0                    ; it plays
sbmsk   db 0
sbrst   dw 0                    ; HEAL's cursor
sfxat   dw 0                    ; SFX: where the effect began in the ring
hvol    db 16                   ; WIND: the breeze's loudness, 64ths
wstate  dw 0                    ;  the wash's filter,
ws2     dw 0                    ;  the breeze's,
wseed   dw 4321                 ;  its own noise
wvol    db 0                    ; WAVES: the wash's loudness now, 64ths
wpeak   db 0                    ;  this wave's height
wph     db 0                    ;  0 still, 1 rolling in, 2 drawing back
wst     dw 0                    ;  the tick this part began
wlen    dw 0                    ;  its ticks
swave   db 0
ssign   db 0
slen    dw 1
shp     dw 0
sdhp    dw 0
samp    dw 0
sdamp   dw 0
sph     dw 0
swalk   dw 0
rseed   dw 7321
birdnext dw 0
view    db 0                    ; 0 the whole level, 1 close up, 2 isometric
flatview db 0                   ; the straight-down one V comes back to
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
wptr2   dw 0                    ; the world packet WAPPLY reads
mylen   db 0
myname  db 9 dup 0              ; your name, as typed; a zero after it
level   dw 0
lvw     db 0
lvh     db 0
start   dw 0
nbox    dw 0
ngood   dw 0
ncandy  dw 0
moves   dw 0
phase   db 0                    ; 0 play, 1 the gate rising, 2 up, 3 winner
pclk    dw 0                    ; ticks left in the phase
nout    db 0                    ; men out of the gate so far
winner  db 0FFh                 ; the level's winner's slot
wbest   dw 0
hasgate db 0                    ; FINDGATE: is there one, where, which way out
gatecell dw 0FFFFh
gatec   dw 0
gater   dw 0
gdc     dw 0
gdr     dw 0
gbest   dw 0
sc      db 0
sr      db 0
gemcell dw 0FFFFh               ; the diamond: its cell, its clock
gemclk  dw 0
pend    db 0
pendt   dw 0
now     dw 0
tdt     dw 0
dirty   db 0
camnew  db 0
chg     db 0
pass    db 0
ccol    db 0
crow    db 0
anim    db 0                    ; the beat of the water and the torches
fstep   dw 0                    ; the tick / 2 of the last frame asked for
sdx     dw 0                    ; STEP: the step, for the history...
spush   db 0                    ;  ...4 if a crate went too
hidx    db 0                    ; UNSTEP: the entry taken back...
hent    db 0                    ;  ...and what it says
stuckc  dw 0FFFFh               ; STUCK: a crate that cannot go home, or none
popp    dw 0                    ; POPS: the slot's numbers...
prise   dw 0                    ;  ...and how far its number has risen
pops    db MAXP*POSIZE dup 0    ; per slot: who, his score, the number showing
ccell   dw 0
boff9   dw 0                    ; which of a blast's nine cells
tcols   db 0                    ; TURNED: the turned grid's columns,
trows   db 0                    ;  rows,
tstart  dw 0                    ;  its first cell,
tdcol   dw 0                    ;  a column on,
tdrow   dw 0                    ;  a row on
tcc     db 0                    ; CELLXY: a turned column, row
trr     db 0
tyy     dw 0
xmin    dw 0
lastt   dw 0                    ; TICKER: the tick it last ran
lastsec dw 0                    ;  the tick it last redrew for a clock
act     db 0                    ;  1: a clock runs
vsz     dw 0                    ; the view: the size's number (5 isometric),
cell    dw 16                   ;  a cell in px,
sptrow  dw 0                    ;  its pictures,
mantrow dw 0                    ;  its men,
vcx     dw 16                   ;  a column on: x, y
vcy     dw 0
vrx     dw 0                    ;  a row on: x, y
vry     dw 16
vsw     dw 16                   ;  a tile's width, height,
vsh     dw 16
vlift   dw 0                    ;  how far its walls rise
ox      dw 0
oy      dw 0
bgok    db 0                    ; the background is drawn, for bgox, bgoy
bgox    dw 0
bgoy    dw 0
rowx    dw 0
rowy    dw 0
curx    dw 0
cury    dw 0
cidx    dw 0
cptr    dw 0
pidx    dw 0
pcol    dw 0
pslot   db 0
wtop    dw 0
wpx     dw 0
hpx     dw 0
manx    dw 0
many    dw 0
tbase   dw 0                    ; DRAW: which buffer, and the rows drawn
clipt   dw 0
clipb   dw 200
tx      dw 0                    ; text: where, its colour, size, shadow
ty      dw 0
tclr    db 15
tscale  db 1
tshad   db 0
fontp   dd 0
glyph   db 8 dup 0
nbuf    db 7 dup 0
by      dw 0                    ; BLIT: the row, its offset, the stretch
boff    dw 0
w0      dw 0
w1      dw 0
g0      dw 0
gn      dw 0
gdst    dw 0
gsrc    dw 0
cc0     dw 0                    ; BUILDBG: the screen's cells, the one in
cc1     dw 0                    ;  hand, where it is, what it is
rr0     dw 0
rr1     dw 0
bcc     dw 0
brr     dw 0
bc      dw 0
br      dw 0
bx0     dw 0
by0     dw 0
bcls    db 0
bbits   db 0
bpass   db 0
bside   db 0
bbank   db 0
dkind   db 0                    ; STAND: the park's thing in hand
dwide   db 0
dtall   db 0
dkx     db 0
dqx     db 0
dx0     dw 0
dy0     dw 0
gatevis db 0                    ; the gate and its bridge on the screen
gatex   dw 0
gatey   dw 0
bridvis db 0
bridx   dw 0
bridy   dw 0
nwater  dw 0
ntorch  dw 0
ntower  dw 0
nfount  dw 0
nlife   dw 0                    ; LIFE: the park's creatures listed,
nbut    db 0                    ;  butterflies,
nfly    db 0                    ;  fireflies,
nduck   db 0                    ;  ducks
cglow   db 0                    ;  a firefly's frame of its glow
cfx     dw 0                    ;  where the one drawn is now
cfy     dw 0
cph     dw 0                    ;  its phase
fph     db 0                    ; FLAME: the torch's place in the tables,
flx0    dw 0                    ;  the flame's middle across (fine columns),
fly0    dw 0                    ;  its foot,
flh     dw 0                    ;  its height now,
fls     dw 0                    ;  its lean at the tip,
flv     dw 0                    ;  the row's height up it, 16ths,
flw     dw 0                    ;  its half-width,
flc     dw 0                    ;  its middle
bst     db 0                    ; the owl: 0 none, 1 in, 2 sitting, 3 off
bx_     dw 0
by_     dw 0
btx     dw 0
bty     dw 0
owlcell dw 0FFFFh               ; the owl's wall cell, the host's (in the world)
owlclk  dw 0                    ;  its clock: ticks to come, or to go
owlcatch db 0                   ;  owls caught in all
bcaw    db 0                    ; it hooted again, near its going
bwhen   dw 0
bdt     dw 0
btries  db 0
gustx   dw 0                    ; the gust over the water, its left edge
lx0     dw 0                    ; DUSK: the level's box on the screen,
lx1     dw 0
ly0     dw 0
ly1     dw 0
dkx0    dw 0                    ;  the box being darkened, its row,
dkx1    dw 0
dky     dw 0
dky1    dw 0
ddy     dw 0                    ;  that row's distance, its dither row
drow4   dw 0
dtyr    db 0
bigat   dw 0                    ; the winner's big man: where, in which
bigseg  dw 0                    ;  segment, his look
biglook db 0FFh
wtick   dw 0                    ; WINNER
wptr    dw 0
wname   db 9 dup 0
wline   db 24 dup 0
s_level dw 0FFFFh               ; SNDDIFF: how it was
s_ngood dw 0
s_boxsum dw 0
s_ncandy dw 0
s_gem   dw 0FFFFh
s_phase db 0
s_nout  db 0
s_ocatch db 0
s_mst   db MAXP dup 0
s_msec  db MAXP dup 0
peers   db MAXPEER*4 dup 0      ; names heard: name, tick (words)
pkt     db NETLEN dup 0         ; the packet we send
players db (MAXP*PSIZE) dup 0   ; the men in the warehouse...
ghost   db PSIZE dup 0          ; ...and the camera of a player not in
mines   db (MAXP*MSIZE) dup 0   ; a mine a man (CLRMINES: none)
artpal  db 48 dup 0             ; from ART.DAT: the sixteen, for the DAC,
artcga  db 64 dup 0             ;  the CGA's half-tones,
arthgc  db 16 dup 0             ;  the Hercules' brightness

virtual at 0                    ; the levels are LEVELS.DAT's (LEVELS.ASM):
        include 'LEVELS.INC'    ;  here only NLEVELS, how many
end virtual

; not in the file, and not zeroed: each is filled before it is read
datpath rb 110
datname rw 1                    ; FINDDAT: where in datpath a file's name goes
lvtab   rw NLEVELS              ; LEVELS.DAT: where each level is in it
spt     rw NENT*2               ; the pictures, size by size: where, which
mant    rw (NSIZE+1)*NLOOK*2    ;  segment; the men, size by size, look by look
rsum    rw 200                  ; BLITW: each row's checksum, as sent
rawman  rb 2+16*16              ; the 16 px man as ART.DAT has him, for MKBIG
ctab    rb 1024                 ; the card's tables: 2 row parities x 2 halves -
htab    = ctab                  ;  the CGA's or the Hercules', never both
dimtab  rb 256
rowtab  rw 200
claim   rb CLW*CLH
wbank   rw 1                    ; FRAMEFL: a water cell's banks and phase
torches rb MAXTORCH*4
towers  rb MAXTOWER*4
founts  rb MAXFOUNT*4
life    rb MAXLIFE*6            ; x, y, kind, phase
HMAP    rb 4096                 ; the land (E_TERR.INC: a byte a node)
dss     rw 1                    ; DSGEN's state
dsh     rw 1
dsx     rw 1
dsy     rw 1
dsamp   rw 1
dsac    rw 1
TXF     rb 320                  ; DUSK: how far across its margin a column is,
TYF     rb 200                  ;  ...and a row, 0..255
gridpad rb NCOL                 ; a zero row above the grid
grid    rb NCOL*NCOL
gridtail rb NCOL                ; and one below it
bfsq    rw 640                  ; FREECELL's queue: every floor cell at most
live    rb NCOL*NCOL/8          ; LIVEGEN: a bit a cell, a crate can go home
                                ;  once - the biggest level is 29x20, 580
if $ > 0FE00h                   ; the stack falls from FFFEh: leave it
        err                     ;  512 bytes
end if
