; ASCENE.ASM - proves KIT\ART and the scenery recipes KIT\REC\R_*.ASM
; ============================================================================
;  1. Every KIT\ART\*.TXT is included: each must assemble (words are
;     comments, pictures db). Then every picture in each file is walked:
;     width and height 1..64, exactly width*height characters, each one
;     '.', '0'..'9' or 'A'..'F', and the file ends where its last picture
;     ends. A PASS or FAIL line per file.
;  2. A castle park is drawn from the pictures in mode 13h with the recipes:
;     the background once in two passes (R_BGTWO), the dusk over it
;     (R_DUSK), then every frame the water's frames and banks (R_WATER
;     WATERCELL), the towers, the torches with live flames (R_FLAME), the
;     fountain's four frames, the candies' glints and the gem's shimmer
;     (R_WATER GLINT, SHIMMER), butterflies, fireflies, a duck (R_LIFE), the
;     owl flying in to a wall (R_OWLFLY), all on one clock (R_CLOCK).
;  3. With /AUTO it animates ~2 s, restores text mode 3 and prints PASS
;     lines for what it can measure in the buffers; without, Esc quits.
;  Its own small drawer DRAWTXT (a text-art picture, see-through, clipped)
;  and PSET are here - copy them for your own program.
; ============================================================================
        org  100h
        include '..\..\ENGINE\E_8086.INC'

OX      = 0                     ; the map's cell (0, 0) on the screen
OY      = 8
MAPW    = 20                    ; the map: 20 x 12 cells of 16
MAPH    = 12
AUTOT   = 40                    ; /AUTO: ticks to animate (about 2.2 s)

START:  cld
        mov  cl,[80h]           ; the command tail: /AUTO?
        xor  ch,ch
        mov  si,81h
.tail:  cmp  cx,5
        jb   .tdone
        cmp  byte [si],'/'
        jne  .tnext
        cmp  word [si+1],'AU'
        jne  .tnext
        cmp  word [si+3],'TO'
        jne  .tnext
        mov  byte [auto],1
        jmp  .tdone
.tnext: inc  si
        dec  cx
        jmp  .tail
.tdone: call CHECKALL           ; 1. the pictures, a line per file
        mov  bx,1000h           ; 2. the .COM keeps 64K...
        mov  ah,4Ah
        int  21h
        jc   NOMEM
        mov  bx,4000            ; ...and takes two buffers of 64000 bytes
        mov  ah,48h
        int  21h
        jc   NOMEM
        mov  [bgseg],ax
        mov  bx,4000
        mov  ah,48h
        int  21h
        jc   NOMEM
        mov  [frseg],ax
        mov  ax,13h
        int  10h                ; 320x200, 256 colours
        mov  dx,3C8h            ; the sixteen, from PALETTE.TXT
        xor  al,al
        out  dx,al
        inc  dx
        mov  si,PAL16
        mov  cx,48
.pal:   lodsb
        out  dx,al
        loop .pal
        call CLOCK
        mov  es,[bgseg]
        call BGBUILD            ; the background: ground, then things
        mov  word [dk_x0],OX+6*16   ; the castle's box: walls 6..13, 3..8
        mov  word [dk_x1],OX+14*16-1
        mov  word [dk_y0],OY+3*16
        mov  word [dk_y1],OY+9*16-1
        call DUSKPREP
        mov  es,[frseg]         ; a copy before the dusk, to measure it
        mov  ax,[bgseg]
        call BGCOPY
        mov  es,[bgseg]
        xor  ax,ax
        mov  bx,320
        xor  cx,cx
        mov  dx,200
        call DUSK               ; the evening over all of it
        call DUSKCHK
        call BGCHK
        mov  bx,OX+10*16        ; the owl: in to the north wall
        mov  dx,OY+3*16
        call OWLCALL
        cmp  byte [auto],0
        je   .t0
        mov  word [ow_x],OX+10*16-30   ; under /AUTO from near, to land in time
        mov  word [ow_y],OY+3*16-20
.t0:    mov  ax,[now]
        mov  [t0],ax
        call FRAME
.loop:  call OWLTICK
        call CLOCK
        jnc  .rest
        call FRAME              ; a new frame only when the clock moved on
        inc  word [frames]
.rest:  sti
        hlt                     ; rest till the next tick or key
        cmp  byte [auto],0
        je   .key
        mov  ax,[now]
        sub  ax,[t0]
        cmp  ax,AUTOT
        jae  .out
.key:   mov  ah,1
        int  16h
        jz   .loop
        xor  ah,ah
        int  16h
        cmp  al,27
        jne  .loop
.out:   call FLAMECHK           ; measured in the last frame
        call WATERCHK
        mov  ax,3
        int  10h                ; text mode again
        mov  ax,cs
        mov  es,ax
        call REPORT
        mov  ax,4C00h
        int  21h
NOMEM:  mov  dx,TNOMEM
        mov  ah,9
        int  21h
        mov  ax,4C01h
        int  21h

; ----------------------------------------------------------------------
;  FRAME - the background copied under the frame, what moves over it,
;  the frame to the screen
; ----------------------------------------------------------------------
FRAME:  mov  es,[frseg]
        mov  ax,[bgseg]
        call BGCOPY
        mov  si,wlist           ; the water, each cell its own phase
        mov  cx,[nwat]
        jcxz .tow
.w:     mov  bx,[si]
        mov  dx,[si+2]
        mov  al,[si+4]
        call WATERCELL
        test byte [si+5],1
        jz   .w1
        push si
        mov  si,BANK16N         ; land to the north: its bank
        call DRAWTXT
        pop  si
.w1:    test byte [si+5],2
        jz   .w2
        push si
        mov  si,BANK16W
        call DRAWTXT
        pop  si
.w2:    add  si,6
        loop .w
.tow:   mov  si,tlist           ; the towers rise over the water
        mov  cx,[ntow]
        jcxz .tor
.t:     mov  bx,[si]
        mov  dx,[si+2]
        sub  dx,16              ; 32 rows on a 16 cell
        push si
        mov  si,TOWER16
        call DRAWTXT
        pop  si
        add  si,4
        loop .t
.tor:   mov  si,clist           ; the torches, each burning its own way
        mov  cx,[ntor]
        jcxz .fnt
.c:     mov  bx,[si]
        mov  dx,[si+2]
        push si
        mov  si,TORCH16
        call DRAWTXT
        pop  si
        mov  al,bl
        shr  al,1               ; x / 2
        add  al,dl
        add  al,dl
        add  al,dl              ; + 3y: its own place in the tables
        call FLAME
        add  si,4
        loop .c
.fnt:   mov  si,flist           ; the fountains: four frames by the beat
        mov  ax,[nfnt]
        mov  [fcnt],ax
.f:     cmp  word [fcnt],0
        je   .gl
        mov  bx,[si]
        mov  dx,[si+2]
        push si
        mov  al,[beat]
        and  ax,3
        shl  ax,1
        mov  si,ax
        mov  si,[FT_FR+si]
        sub  dx,8               ; 24 rows on a 16 cell
        call DRAWTXT
        mov  ax,bx              ; and the evening over it again
        add  bx,32
        mov  cx,dx
        add  dx,24
        call DUSK
        pop  si
        add  si,4
        dec  word [fcnt]
        jmp  .f
.gl:    mov  si,glist           ; the candies glint, each on its own period
        mov  cx,[ngl]
        jcxz .gem
.g:     mov  bx,[si]
        mov  dx,[si+2]
        mov  ax,[si+4]
        call GLINT
        add  si,6
        loop .g
.gem:   cmp  word [gemx],0
        je   .life
        mov  bx,[gemx]
        mov  dx,[gemy]
        mov  ax,[gemx]
        call SHIMMER
.life:  call LIFE               ; butterflies, fireflies, the duck
        call OWLDRAW
        mov  ax,[ow_x]          ; the dusk over the owl too
        mov  bx,ax
        add  bx,16
        mov  cx,[ow_y]
        mov  dx,cx
        add  dx,16
        call DUSK
SHOW:   push ds                 ; the frame to the screen, after the retrace
        push es
        mov  dx,3DAh
.vr1:   in   al,dx
        test al,8
        jnz  .vr1
.vr2:   in   al,dx
        test al,8
        jz   .vr2
        mov  ax,0A000h
        mov  es,ax
        mov  ds,[frseg]
        xor  si,si
        xor  di,di
        mov  cx,32000
        rep  movsw
        pop  es
        pop  ds
        ret
FT_FR   dw FOUNT32A,FOUNT32B,FOUNT32C,FOUNT32D

; ----------------------------------------------------------------------
;  BGGROUND, BGTHING - R_BGTWO's questions: CX = column, DX = row;
;  out SI = the picture, or 0. They also list what moves.
; ----------------------------------------------------------------------
BGGROUND:
        call MAPAT              ; BX = the map's index, AX = x, DI = y
        mov  al,[GROUND+bx]
        xor  si,si
        cmp  al,'.'
        je   .r                 ; the floor: black, bare
        mov  si,GRASS16
        cmp  al,'g'
        je   .r
        mov  si,FOREST16
        cmp  al,'f'
        je   .r
        mov  si,ROAD16
        cmp  al,'r'
        je   .r
        mov  si,BRIDG16V
        cmp  al,'v'
        je   .r
        cmp  al,'m'
        jne  .nm
        call HASH
        mov  si,MEADOW16
        mov  ah,0
        mov  dl,5
        div  dl                 ; AH = hash mod 5
        or   ah,ah
        jnz  .r
        mov  si,GRASS16S        ; one meadow cell in five: grass, a stone
        ret
.nm:    cmp  al,'#'
        jne  .nw
        call HASH
        mov  si,WALL16
        test al,1
        jz   .r
        mov  si,WALL16B         ; two stones of wall, by the hash
        ret
.nw:    cmp  al,'w'
        jne  .none
        mov  si,[nwat]          ; water: listed, drawn every frame
        cmp  si,MAXWAT
        jae  .w0
        inc  word [nwat]
        mov  ax,6
        mul  si                 ; 6 bytes a cell  (DX goes)
        mov  si,ax
        add  si,wlist
        mov  ax,[cx_]
        mov  [si],ax
        mov  ax,[cy_]
        mov  [si+2],ax
        mov  dx,[mapr]          ; (MUL took DX; CX is still the column)
        call HASH
        mov  [si+4],al          ; its own phase
        mov  byte [si+5],0
        mov  bx,[mapi]
        cmp  word [mapr],0
        je   .wn
        mov  al,[GROUND+bx-MAPW]
        call ISLAND
        jc   .wn
        or   byte [si+5],1      ; land to the north: a bank
.wn:    cmp  word [mapc],0
        je   .wd
        mov  al,[GROUND+bx-1]
        call ISLAND
        jc   .wd
        or   byte [si+5],2      ; land to the west
.wd:    mov  cx,[mapc]          ; a duck on one cell in sixteen
        add  cx,11
        mov  dx,[mapr]
        add  dx,2
        call HASH
        and  al,15
        jnz  .w0
        mov  bx,[cx_]
        add  bx,8
        mov  dx,[cy_]
        add  dx,8
        mov  cl,2
        call LIFEADD
.w0:    mov  si,WATER16A
        ret
.none:  xor  si,si
.r:     ret
; ISLAND - CF=1: map character AL is not land (water, wall, floor)
ISLAND: cmp  al,'w'
        je   .y
        cmp  al,'#'
        je   .y
        cmp  al,'.'
        je   .y
        clc
        ret
.y:     stc
        ret

BGTHING:call MAPAT
        mov  al,[THINGS+bx]
        cmp  al,'.'
        jne  .some
        mov  al,[GROUND+bx]     ; nothing stands here: a wall's growth?
        xor  si,si
        cmp  al,'#'
        jne  .r
        mov  si,GROW16N         ; the north wall's outer side
        cmp  word [mapr],3
        je   .r
        mov  si,GROW16W         ; the west wall's
        cmp  word [mapc],6
        je   .r
        xor  si,si
.r:     ret
.some:  cmp  al,'X'
        je   .tower
        cmp  al,'t'
        je   .torch
        cmp  al,'F'
        je   .fount
        cmp  al,'j'
        je   .gem
        mov  si,TKIND           ; the table: code, life, picture
.k:     cmp  byte [si],0
        je   .none
        cmp  al,[si]
        je   .hit
        add  si,4
        jmp  .k
.none:  xor  si,si
        ret
.hit:   mov  dl,[si+1]          ; its life: 0 none, 1 butterfly, 2 firefly,
        mov  si,[si+2]          ;  3 a candy's glint
        or   dl,dl
        jz   .r
        cmp  dl,3
        je   .glint
        push si
        mov  bx,[mapi]
        mov  al,[THINGS+bx]     ; which thing it is
        mov  bx,[cx_]
        add  bx,8               ; its home: over the cell's middle,
        mov  dx,[cy_]           ;  at its top
        call LIFEOF             ; CL = the kind, DX moved for a firefly
        call LIFEADD
        pop  si
        ret
.glint: mov  di,[ngl]           ; a candy: listed for its glint
        cmp  di,MAXGL
        jae  .r
        inc  word [ngl]
        mov  ax,6
        mul  di                 ; (DX goes)
        mov  di,ax
        mov  ax,[cx_]
        mov  word [glist+di],ax
        mov  ax,[cy_]
        mov  word [glist+di+2],ax
        mov  ax,[mapi]
        mov  word [glist+di+4],ax    ; its seed: the cell
        ret
.tower: mov  di,tlist
        mov  si,ntow
        jmp  .list
.torch: mov  di,clist
        mov  si,ntor
        jmp  .list
.fount: mov  di,flist
        mov  si,nfnt
.list:  mov  bx,[si]
        cmp  bx,MAXLST
        jae  .nl
        inc  word [si]
        shl  bx,1
        shl  bx,1               ; 4 bytes an entry
        mov  ax,[cx_]
        mov  [di+bx],ax
        mov  ax,[cy_]
        mov  [di+bx+2],ax
.nl:    xor  si,si              ; drawn every frame, not here
        ret
.gem:   mov  ax,[cx_]
        mov  [gemx],ax
        mov  ax,[cy_]
        mov  [gemy],ax
        mov  si,GEM16
        ret
; LIFEOF - the kind of creature for thing AL: CL (0 butterfly, 1 firefly);
; a firefly lives by its tree's middle (DX + 8)
LIFEOF: mov  cl,0
        cmp  al,'n'
        je   .r
        cmp  al,'k'
        je   .r
        mov  cl,1
        add  dx,8
.r:     ret

; MAPAT - for cell CX, DX: BX = its index in the maps, [cx_] [cy_] its
; screen place, [mapc] [mapr] [mapi] kept for the questions after
MAPAT:  mov  [mapc],cx
        mov  [mapr],dx
        mov  ax,dx
        mov  bx,MAPW
        mul  bx                 ; row * 20  (DX goes)
        add  ax,cx
        mov  bx,ax
        mov  [mapi],ax
        mov  ax,cx
        mov  cl,4
        shl  ax,cl              ; column * 16
        add  ax,OX
        mov  [cx_],ax
        mov  ax,[mapr]
        shl  ax,cl              ; row * 16
        add  ax,OY
        mov  [cy_],ax
        mov  cx,[mapc]
        mov  dx,[mapr]
        ret

; HASH - AL = a byte for cell CX, DX and the level (SCATTER.TXT; from
; GAMES\MULTSOK2\SCENE.INC HASH 358-383). keeps everything but AX.
HASH:   push bx
        push cx
        push dx
        mov  ax,dx
        and  ax,63
        mov  bx,cx
        mov  cl,6
        shl  ax,cl              ; (r AND 63) * 64
        and  bx,63
        add  ax,bx              ; + (c AND 63)
        mov  bx,[level]
        mov  cl,12
        shl  bx,cl              ; + level * 4096
        add  ax,bx
        mov  bx,25173
        mul  bx                 ; (DX goes)
        add  ax,13849
        xchg al,ah              ; its bytes swapped
        mul  bx
        add  ax,13849
        mov  al,ah              ; the high byte: the good one
        xor  ah,ah
        pop  dx
        pop  cx
        pop  bx
        ret

; ----------------------------------------------------------------------
;  DRAWTXT - a text-art picture (KIT\ART's form: db width, height, then a
;  character a pixel, '.' see-through, '0'..'9' 'A'..'F' colours 0..15)
;  at x BX, y DX (its top left) into ES, 320 bytes a row, clipped to the
;  screen. in: SI the picture. keeps every register.
; ----------------------------------------------------------------------
DRAWTXT:push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        lodsw                   ; AL = width, AH = height
        mov  cl,al
        xor  ch,ch
        mov  [dt_w],cx
        mov  al,ah
        xor  ah,ah
        mov  bp,ax              ; BP = rows left
.row:   or   bp,bp
        jz   .done
        cmp  dx,200
        jae  .skip              ; off the screen (a negative row: huge)
        push bx
        xor  bx,bx
        call ROWADR             ; DI = the row's start
        pop  bx
        mov  [dt_row],di
        push bx
        mov  cx,[dt_w]
.px:    lodsb
        cmp  al,'.'
        je   .nx                ; see-through
        cmp  bx,320
        jae  .nx                ; off the left or right edge
        sub  al,'0'             ; '0'..'9' -> 0..9
        cmp  al,9
        jbe  .put
        sub  al,7               ; 'A'..'F' -> 10..15
.put:   mov  di,[dt_row]
        add  di,bx
        mov  [es:di],al
.nx:    inc  bx
        loop .px
        pop  bx
        jmp  .nr
.skip:  add  si,[dt_w]          ; the row's characters, unread
.nr:    inc  dx
        dec  bp
        jmp  .row
.done:  pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; PSET - colour AL at x BX, y DX into ES; off the screen nothing. keeps all.
PSET:   cmp  bx,320
        jae  .r                 ; (a negative x is huge unsigned: off)
        cmp  dx,200
        jae  .r
        push di
        call ROWADR
        mov  [es:di],al
        pop  di
.r:     ret

; ROWADR - DI = DX * 320 + BX (DX 0..199). keeps all but DI.
ROWADR: push dx
        mov  di,dx
        shl  di,1
        shl  di,1
        shl  di,1
        shl  di,1
        shl  di,1
        shl  di,1               ; y * 64
        mov  dh,dl
        xor  dl,dl              ; y * 256
        add  di,dx              ; y * 320
        add  di,bx              ; + x
        pop  dx
        ret

; ----------------------------------------------------------------------
;  CHECKALL - every art file: its pictures walked from its first byte to
;  its end label, sizes and characters checked; a line per file
; ----------------------------------------------------------------------
CHECKALL:
        mov  si,ARTTAB
.f:     cmp  word [si],0
        je   .r
        push si
        mov  di,[si+2]          ; DI = where the file ends
        mov  bx,[si+4]          ; BX = its name
        mov  si,[si]            ; SI = its first picture
        xor  bp,bp              ; BP = pictures counted
.p:     cmp  si,di
        je   .ok                ; ends where its last picture ends
        ja   .bad
        mov  ax,[si]            ; AL = width, AH = height
        or   al,al
        jz   .bad
        or   ah,ah
        jz   .bad
        cmp  al,64
        ja   .bad
        cmp  ah,64
        ja   .bad
        mul  ah                 ; AX = width * height
        mov  cx,ax
        add  ax,si
        add  ax,2               ; where it must end
        cmp  ax,di
        ja   .bad               ; past the file's end: a row too long
        add  si,2
.c:     lodsb
        call LEGAL
        jc   .bad
        loop .c
        inc  bp
        inc  word [npics]
        jmp  .p
.ok:    mov  dx,TPASS
        jmp  .say
.bad:   inc  word [bad]
        mov  dx,TFAIL
.say:   mov  ah,9
        int  21h
        mov  dx,bx
        mov  ah,9
        int  21h                ; the file's name
        mov  dx,TPICS
        mov  ah,9
        int  21h
        mov  ax,bp
        call PRNUM
        mov  dx,TCRLF
        mov  ah,9
        int  21h
        inc  word [nfiles]
        pop  si
        add  si,6
        jmp  .f
.r:     ret
; LEGAL - CF=0: AL is '.', '0'..'9' or 'A'..'F'
LEGAL:  cmp  al,'.'
        je   .y
        cmp  al,'0'
        jb   .n
        cmp  al,'9'
        jbe  .y
        cmp  al,'A'
        jb   .n
        cmp  al,'F'
        jbe  .y
.n:     stc
        ret
.y:     clc
        ret

; ----------------------------------------------------------------------
;  The measures: what the recipes left in the buffers
; ----------------------------------------------------------------------
; DUSKCHK - the background after DUSK against its copy before: pixels
; darkened outside the castle's box (must be some), inside it (must be 0)
DUSKCHK:push ds
        push es
        mov  es,[frseg]
        mov  ds,[cs:bgseg]
        xor  si,si
        xor  dx,dx              ; DX = the row
.y:     xor  bx,bx              ; BX = the column
.x:     mov  al,[si]
        cmp  al,[es:si]
        je   .n
        cmp  bx,[cs:dk_x0]
        jl   .out
        cmp  bx,[cs:dk_x1]
        jg   .out
        cmp  dx,[cs:dk_y0]
        jl   .out
        cmp  dx,[cs:dk_y1]
        jg   .out
        inc  word [cs:dkin]     ; darkened inside the box: wrong
        jmp  .n
.out:   inc  word [cs:dkout]
.n:     inc  si
        inc  bx
        cmp  bx,320
        jb   .x
        inc  dx
        cmp  dx,200
        jb   .y
        pop  es
        pop  ds
        ret
; BGCHK - pixels of the background that are not black (the park drawn)
BGCHK:  push ds
        mov  ds,[cs:bgseg]
        xor  si,si
        mov  cx,64000
        xor  dx,dx
.l:     lodsb
        or   al,al
        jz   .n
        inc  dx
.n:     loop .l
        pop  ds
        mov  [bgpix],dx
        ret
; FLAMECHK - fire's colours (15 white, 14 gold, 12 red) over the first
; torch's cup in the last frame: only FLAME draws them there
; that are not in the background there (the wall has white stones)
FLAMECHK:
        cmp  word [ntor],0
        je   .r
        push ds
        push es
        mov  es,[frseg]
        mov  dx,word [clist+2]       ; the torch's cell, top left
        mov  bx,word [clist]
        mov  ds,[bgseg]         ; DS = the background (variables by CS:)
        mov  cx,9               ; the rows over its cup
.y:     push cx
        push bx
        mov  cx,16
.x:     call ROWADR
        mov  al,[es:di]
        cmp  al,[di]
        je   .n                 ; as the background has it
        cmp  al,15
        je   .f
        cmp  al,14
        je   .f
        cmp  al,12
        jne  .n
.f:     inc  word [cs:flpix]
.n:     inc  bx
        loop .x
        pop  bx
        pop  cx
        inc  dx
        loop .y
        pop  es
        pop  ds
.r:     ret
; WATERCHK - the first water cell with no bank, in the last frame: its
; pixels water's colours (1, 3, 9, 11) but for a creature on it (8 at most)
WATERCHK:
        mov  si,wlist
        mov  cx,[nwat]
        jcxz .none
.find:  cmp  byte [si+5],0
        je   .got
        add  si,6
        loop .find
.none:  mov  word [wtbad],999   ; no plain water cell: nothing to see
        ret
.got:   push es
        mov  es,[frseg]
        mov  bx,[si]
        mov  dx,[si+2]
        mov  cx,16
.y:     push cx
        mov  cx,16
        push bx
.x:     push di
        call ROWADR
        mov  al,[es:di]
        pop  di
        cmp  al,1
        je   .ok
        cmp  al,3
        je   .ok
        cmp  al,9
        je   .ok
        cmp  al,11
        je   .ok
        inc  word [wtbad]       ; not water
.ok:    inc  bx
        loop .x
        pop  bx
        pop  cx
        inc  dx
        loop .y
        pop  es
.r:     ret

; REPORT - the PASS / FAIL lines of what was measured
REPORT: mov  dx,TPASS           ; the art, all of it
        cmp  word [bad],0
        je   .a1
        mov  dx,TFAIL
.a1:    call SAY
        mov  dx,TART
        call SAY
        mov  ax,[nfiles]
        call PRNUM
        mov  dx,TART2
        call SAY
        mov  ax,[npics]
        call PRNUM
        call CRLF
        mov  dx,TPASS           ; R_BGTWO: the park drawn
        cmp  word [bgpix],30000
        ja   .b1
        mov  dx,TFAIL
.b1:    call SAY
        mov  dx,TBG
        call SAY
        mov  ax,[bgpix]
        call PRNUM
        call CRLF
        mov  dx,TPASS           ; R_DUSK: dark outside, light inside
        cmp  word [dkout],0
        je   .d0
        cmp  word [dkin],0
        je   .d1
.d0:    mov  dx,TFAIL
.d1:    call SAY
        mov  dx,TDK
        call SAY
        mov  ax,[dkout]
        call PRNUM
        mov  dx,TDK2
        call SAY
        mov  ax,[dkin]
        call PRNUM
        call CRLF
        mov  dx,TPASS           ; R_FLAME: fire over the torch
        cmp  word [flpix],0
        jne  .f1
        mov  dx,TFAIL
.f1:    call SAY
        mov  dx,TFL
        call SAY
        mov  ax,[flpix]
        call PRNUM
        call CRLF
        mov  dx,TPASS           ; R_WATER: the water cells drawn
        cmp  word [nwat],0
        je   .w0
        cmp  word [wtbad],8      ; (a duck or a firefly may sit on it)
        jbe  .w1
.w0:    mov  dx,TFAIL
.w1:    call SAY
        mov  dx,TWT
        call SAY
        mov  ax,[nwat]
        call PRNUM
        call CRLF
        mov  dx,TPASS           ; R_LIFE: creatures listed
        cmp  word [lf_n],0
        jne  .l1
        mov  dx,TFAIL
.l1:    call SAY
        mov  dx,TLF
        call SAY
        mov  ax,[lf_n]
        call PRNUM
        call CRLF
        mov  dx,TPASS           ; R_OWLFLY: the owl flew (or sits)
        cmp  byte [ow_st],0
        jne  .o1
        mov  dx,TFAIL
.o1:    call SAY
        mov  dx,TOW
        call SAY
        mov  al,[ow_st]
        xor  ah,ah
        call PRNUM
        call CRLF
        mov  dx,TPASS           ; R_CLOCK: frames drawn on the clock
        cmp  byte [auto],0
        je   .c1                ; (a person looked: any number)
        cmp  word [frames],10
        jae  .c1
        mov  dx,TFAIL
.c1:    call SAY
        mov  dx,TCK
        call SAY
        mov  ax,[frames]
        call PRNUM
        call CRLF
        ret
SAY:    mov  ah,9
        int  21h
        ret
CRLF:   mov  dx,TCRLF
        jmp  SAY
; PRNUM - AX in decimal
PRNUM:  push ax
        push bx
        push cx
        push dx
        mov  bx,10
        xor  cx,cx
.d:     xor  dx,dx
        div  bx                 ; AX = AX / 10, DX = the digit (BX = 10)
        push dx
        inc  cx
        or   ax,ax
        jnz  .d
.p:     pop  dx
        add  dl,'0'
        mov  ah,2
        int  21h
        loop .p
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; ----------------------------------------------------------------------
;  The recipes under test (KIT\REC), then the art (KIT\ART)
; ----------------------------------------------------------------------
        include '..\REC\R_CLOCK.ASM'
        include '..\REC\R_FLAME.ASM'
        include '..\REC\R_WATER.ASM'
        include '..\REC\R_LIFE.ASM'
        include '..\REC\R_OWLFLY.ASM'
        include '..\REC\R_DUSK.ASM'
        include '..\REC\R_BGTWO.ASM'

ARTFILES equ BANK,BIRCH,BLAST,BLOSSOM,BOULDER,BRIDGE,BUSH,CANDY,CRATE,DEER,\
             FLOWERS,FOLIAGE,FOREST,FOUNTAIN,GATE,GEM,GOAL,GRASS,GROWTH,\
             HEDGE,LAMP,MEADOW,MINE,MUSHROOM,OAK,OWL,PINE,POND,RABBIT,ROAD,\
             RULES,SCATTER,SHADE,SHADOW,SPARKLE,STATUE,STONES,STUMP,TORCH,\
             TOWER,TREE,WATER,WELL,WILLOW
match list, ARTFILES {
  irp f, list \{
    ab_\#f:
    include '..\ART\' \# \`f \# '.TXT'
    ae_\#f:
  \}
  ARTTAB:
  irp f, list \{ dw ab_\#f, ae_\#f, an_\#f \}
        dw 0
  irp f, list \{ an_\#f db \`f, '.TXT$' \}
}
        include '..\ART\PALETTE.TXT'    ; tables, not pictures: not walked

; ----------------------------------------------------------------------
;  The park: the ground and what stands on it, a character a cell
;  ground: g grass, m meadow, f pine floor, r road, v bridge, # wall,
;          w water (moves), . the castle's floor (black)
;  things: P pine, T tree, O oak, b birch, k blossom, B bush, L lamp,
;          W well, H hedge, R boulder, D deer, s stump, M mushrooms,
;          E rabbit, n flowers, Y willow, p pond, G the gate, X tower,
;          t torch, F fountain, 1 2 3 candies, o goal, h crate home,
;          x crate, j gem, m mine
; ----------------------------------------------------------------------
GROUND  db 'ffffffgggggggmmmmmmm'
        db 'fffffgggggggggmmmmmm'
        db 'ffffgwwwwwwwwwwmmmmm'
        db 'ffffgw########wmmmmm'
        db 'fffggw#......#wmmmmm'
        db 'fffggw#......#wmmmmm'
        db 'ffgggw#......#wmmmmm'
        db 'ffgggw#......#wmmmmm'
        db 'fggggw########wggmmm'
        db 'gggggwwwwvwwwwwggggg'
        db 'gggggggggrgggggggggg'
        db 'gggggggggrgggggggggg'
THINGS  db '..P....T.....B..L...'
        db 'P...P..........O....'
        db '.P.b...........H..W.'
        db 'P.T...X......X..k...'
        db '..R....1o.x2........'
        db '.D....t.3.j.....F...'
        db '..s....h.1..2t.n....'
        db 'B.M....2..m.1....Y..'
        db '..E...X..G...X......'
        db 'B...............p...'
        db '..T..n.............b'
        db 'P.....B...M....R...D'
; code, life (0 none, 1 a creature by LIFEOF, 3 a glint), picture
TKIND   db 'P',1
        dw PINE16
        db 'T',1
        dw TREE16
        db 'O',1
        dw OAK32
        db 'b',1
        dw BIRCH16
        db 'k',1
        dw BLOSSM16
        db 'n',1
        dw FLOWER16
        db 'B',0
        dw BUSH16
        db 'L',0
        dw LAMP16
        db 'W',0
        dw WELL16
        db 'H',0
        dw HEDGE32
        db 'R',0
        dw BOULDR16
        db 'D',0
        dw DEER16
        db 's',0
        dw STUMP16
        db 'M',0
        dw MUSHRM16
        db 'E',0
        dw RABBIT16
        db 'Y',0
        dw WILLOW32
        db 'p',0
        dw POND32
        db 'G',0
        dw GATE16U
        db '1',3
        dw CANDY16G
        db '2',3
        dw CANDY16Y
        db '3',3
        dw CANDY16P
        db 'o',0
        dw GOAL16
        db 'h',0
        dw CRATE16H
        db 'x',0
        dw CRATE16
        db 'm',0
        dw MINE16
        db 0

TNOMEM  db 'FAIL ASCENE: not enough memory for two buffers',13,10,'$'
TPASS   db 'PASS $'
TFAIL   db 'FAIL $'
TPICS   db ' pictures: $'
TCRLF   db 13,10,'$'
TART    db 'ASCENE art: files $'
TART2   db ', pictures $'
TBG     db 'R_BGTWO BGBUILD: background pixels drawn $'
TDK     db 'R_DUSK DUSK: darkened outside the castle $'
TDK2    db ', inside $'
TFL     db 'R_FLAME FLAME: fire pixels over the torch $'
TWT     db 'R_WATER WATERCELL: water cells, all water-coloured: $'
TLF     db 'R_LIFE LIFEADD/LIFE: creatures $'
TOW     db 'R_OWLFLY OWLTICK/OWLDRAW: the owl state (1 in, 2 sits) $'
TCK     db 'R_CLOCK CLOCK: frames drawn on the clock $'

MAXWAT  = 60
MAXGL   = 20
MAXLST  = 8
cell    dw 16                   ; the recipes' cell: the pictures' 16
level   dw 1
auto    db 0
bgseg   dw 0
frseg   dw 0
t0      dw 0
frames  dw 0
bad     dw 0
nfiles  dw 0
npics   dw 0
dkin    dw 0
dkout   dw 0
bgpix   dw 0
flpix   dw 0
wtbad   dw 0
dt_w    dw 0
dt_row  dw 0
mapc    dw 0
mapr    dw 0
mapi    dw 0
cx_     dw 0
cy_     dw 0
gemx    dw 0
gemy    dw 0
nwat    dw 0
ntow    dw 0
ntor    dw 0
nfnt    dw 0
ngl     dw 0
fcnt    dw 0
wlist   rb MAXWAT*6             ; x, y, phase, banks
tlist   rb MAXLST*4
clist   rb MAXLST*4
flist   rb MAXLST*4
glist   rb MAXGL*6
