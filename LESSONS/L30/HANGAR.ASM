; ============================================================================
;  HANGAR.ASM - Lesson 1E. THE HANGAR: an aeroplane is a list of points.
;
;      FASM HANGAR.ASM HANGAR.COM
;
;      UP / DOWN     the next aeroplane: fighter, bomber, radar, transport,
;                    tanker - OWL FLY III's whole air force
;      LEFT / RIGHT  turn it slower, faster, the other way, or not at all
;      W             how it is drawn: FILLED, FILLED + WIRE + the vertex
;                    numbers, or WIRE + numbers alone
;      ESC           back to DOS
;
;  A BREAK FROM THE FLIGHT. The source does not travel this time: this is a
;  small program of its own, EXAMPLES\JET.ASM - "the hangar" - without the
;  explosion, and with W. Next lesson the aeroplanes go into the sky, into
;  the flight program of lesson 1D.
;
;  WHAT AN AEROPLANE IS, to this program: two tables.
;
;      the vertices  a word each of x, y and z, in cells of the squared
;                    paper it was drawn on - x across the wings, y up, z
;                    along the nose. Thirteen of them make the transport
;      the faces     five bytes each: four vertex numbers round the face,
;                    and a colour. A triangle is a four-sided face with one
;                    vertex twice
;
;  Nothing else. No outline, no picture, no shape is stored anywhere - W
;  shows the bare points with their numbers, the same numbers as the table
;  and as the notebook's squared paper.
;
;  EVERY FRAME, the whole aeroplane is made again from the two tables:
;
;      1  turn     each vertex about the vertical, by the spin: the same
;                  rotate as the island's (x cos + z sin, z cos - x sin)
;      2  tilt     the stand, 20 degrees towards us - the same rotate
;                  again, about the line of the wings - and place it:
;                  times 8, a cell is eight units, out in front of the lens
;      3  sort     each face's depth is the average of its four corners;
;                  the faces are bubble-sorted far to near
;      4  paint    in that order, through the engine's near clip, the
;                  projection and the scanline fill: FACEFILL
;
;  THE PHYSICAL FACT THIS LESSON HANDS OVER:
;
;      HIDING IS ONLY ORDER. Video memory keeps the last byte written to
;      it - nothing more. Paint the far faces first and the near ones
;      last, and the near ones cover the far ones, because they were
;      written later. No test, no depth buffer: lesson 16's painter's
;      algorithm, on an aeroplane. The bubble sort is nearly free - from
;      one frame to the next the order hardly changes, and a bubble on an
;      order that is almost right does almost nothing.
;
;  WHERE THE AIR FORCE COMES FROM: GAMES\OWLFLY3\SRC\DATA.INC, MVERT1 to
;  MVERT4 and their faces - drawn by hand on squared paper, coordinates read
;  off the cells. The game's own fighter is a twin-tail F-15 from a model
;  file, res\F15.OBJ, turned into the same two tables at build time by a C#
;  tool, TOOLS\Obj2Inc (F15M.INC); the fighter here is the simpler one from
;  EXAMPLES\JET.ASM. Two ways to the same two tables.
;
;  WHAT IS BORROWED FROM THE ENGINE:
;
;      ENGINE\E_8086.INC   keeps FASM inside the 8086 instruction set
;      ENGINE\E_MATH.INC   RND16 (unused here: the explosion is gone)
;      ENGINE\E_M3D.INC    SETTRIG, SINQ, PROJPT - the lens and the sine
;      ENGINE\E_RAST.INC   FACEFILL, CLIPLINE, LINE - the face, the wire
;
;  Owlos - legacy software modernization - https://owlos.sk
; ============================================================================
FOCAL   = 220                 ; the game's lens, the island's too
NEARZ   = 40                  ; the near clip plane
MAXF    = 12                  ; the most faces any type has (the bomber)
MAXV    = 25                  ; the most vertices (the bomber again)
WIREC   = 31                  ; the wire's colour, set in SETPAL
NUMC    = 30                  ; the numbers' colour: amber
TCOS    = 241                 ; cos 20 degrees * 256: the stand's tilt
TSIN    = 88                  ; sin 20 degrees * 256

format binary as 'com'
        org 100h

        include '..\..\ENGINE\E_8086.INC'

START:  cld                     ; STOSW and MOVSW walk up
        mov  ax,cs              ; AX = our segment
        add  ax,1000h           ; AX += 64K: the back buffer, above us
        mov  [bufseg],ax        ; bufseg = it
        mov  ax,0013h           ; VGA 320x200, 256 colours
        int  10h
        call SETPAL             ; the few colours an aeroplane wears
        call SETTRIG            ; the camera: straight and level
        call SETM               ; the first aeroplane on the stand

; ---- one frame ---------------------------------------------------------------
FRAME:  mov  ax,[bufseg]        ; ---- the buffer cleared to black ----
        mov  es,ax              ; ES = the buffer
        xor  di,di              ; DI = 0
        xor  ax,ax              ; AX = 0: colour 0, twice
        mov  cx,32000           ; CX = 32000 words: the whole screen
        rep  stosw              ; clear

        ; ---- 1. THE SPIN, and its sine and cosine ----------------------------
        mov  ax,[spd]           ; AX = the spin, steps a frame
        add  [mhead],ax         ; mhead += it
        and  word [mhead],255   ; mhead &= 255: a byte is the whole circle
        mov  ax,[mhead]         ; AX = mhead
        call SINQ               ; AX = sin(mhead)*256
        mov  [msin],ax          ; msin = it
        mov  ax,[mhead]         ; AX = mhead
        add  ax,64              ; a quarter on: the cosine
        call SINQ               ; AX = cos(mhead)*256
        mov  [mcos],ax          ; mcos = it

        ; ---- 2. EVERY VERTEX TURNED, TILTED AND PLACED, into PVX/PVY/PVZ ---
        ;   the spin, about the vertical - the island's rotate:
        ;     x' = (x cos + z sin) * 8/256        a cell is eight units
        ;     z' = (z cos - x sin) * 8/256
        ;     y' =  y * 8
        ;   the stand tilted 20 degrees, so we look a little down on it -
        ;   the same rotate again, about the line of the wings:
        ;     y" = (y' cos20 + z' sin20)/256 - 20    and a little low
        ;     z" = (z' cos20 - y' sin20)/256 + the stand's distance
        ; In C:
        ;   for (i = 0; i < nv; i++) {
        ;       x1 = (vx[i]*mcos + vz[i]*msin) / 32;
        ;       z1 = (vz[i]*mcos - vx[i]*msin) / 32;
        ;       y1 =  vy[i] * 8;
        ;       pvx[i] = x1;
        ;       pvy[i] = ((long)y1*TCOS + (long)z1*TSIN) / 256 - 20;
        ;       pvz[i] = ((long)z1*TCOS - (long)y1*TSIN) / 256 + pdzc;
        ;   }
        xor  si,si              ; SI = the vertex, 6 bytes each in the table
        xor  di,di              ; DI = the vertex, 2 bytes each in the cache
.tv:    mov  bx,[mvb]           ; BX = this type's vertex table
        mov  ax,[bx+si]         ; AX = x
        imul word [mcos]        ; AX = x*cos  (a word: |x| < 32, cos <= 256)
        mov  cx,ax              ; CX = it
        mov  ax,[bx+si+4]       ; AX = z
        imul word [msin]        ; AX = z*sin
        add  ax,cx              ; AX = x cos + z sin
        cwd                     ; DX:AX = it, signed, for IDIV
        mov  cx,32              ; CX = 32: *8 and /256 in one divide
        idiv cx                 ; AX = x', in units
        mov  [PVX+di],ax        ; x' kept: the tilt does not touch it
        mov  ax,[bx+si]         ; AX = x
        imul word [msin]        ; AX = x*sin
        mov  cx,ax              ; CX = it
        mov  ax,[bx+si+4]       ; AX = z
        imul word [mcos]        ; AX = z*cos
        sub  ax,cx              ; AX = z cos - x sin
        cwd                     ; DX:AX = it
        mov  cx,32              ; CX = 32
        idiv cx                 ; AX = z', in units
        mov  [tz],ax            ; tz = it
        mov  ax,[bx+si+2]       ; AX = y
        mov  cl,3               ; CL = 3
        shl  ax,cl              ; AX = y*8 = y'
        mov  [ty],ax            ; ty = it
        ; the tilt. y'*241 + z'*88 can pass 32767, so every product is a
        ; double word - IMUL leaves it in DX:AX - and IDIV takes DX:AX back
        mov  cx,TCOS            ; CX = cos20 * 256
        imul cx                 ; DX:AX = y' cos
        mov  bx,ax              ; BP:BX = it
        mov  bp,dx
        mov  ax,[tz]            ; AX = z'
        mov  cx,TSIN            ; CX = sin20 * 256
        imul cx                 ; DX:AX = z' sin
        add  ax,bx              ; DX:AX = y' cos + z' sin: the low words...
        adc  dx,bp              ; ...and the high, with the low's carry
        mov  cx,256             ; CX = 256
        idiv cx                 ; AX = /256
        sub  ax,20              ; AX -= 20: the aeroplane a little low
        mov  [PVY+di],ax        ; y" kept
        mov  ax,[tz]            ; AX = z'
        mov  cx,TCOS
        imul cx                 ; DX:AX = z' cos
        mov  bx,ax              ; BP:BX = it
        mov  bp,dx
        mov  ax,[ty]            ; AX = y'
        mov  cx,TSIN
        imul cx                 ; DX:AX = y' sin
        sub  bx,ax              ; BP:BX = z' cos - y' sin: the low words...
        sbb  bp,dx              ; ...and the high, with the low's borrow
        mov  ax,bx              ; DX:AX = it, for IDIV
        mov  dx,bp
        mov  cx,256             ; CX = 256
        idiv cx                 ; AX = /256
        add  ax,[pdzc]          ; AX += the stand's distance: in front of us
        mov  [PVZ+di],ax        ; z" kept
        add  si,6               ; the next vertex in the table
        add  di,2               ; and in the cache
        cmp  si,[mvn]           ; all of them?
        jb   .tv                ;   no

        ; ---- 3. THE FACES: corners, depths, and the painter's order --------
        call CORNERS            ; each face's four corners, from the cache
        call DEPTHS             ; each face's depth: the average of them
        call BUBBLE             ; far to near

        ; ---- 4. PAINT, WIRE, NUMBERS - as W says -----------------------------
        mov  ax,[bufseg]        ; ES = the buffer, for every routine below
        mov  es,ax
        cmp  byte [wmode],2     ; wire alone?
        je   .nofill            ;   then no faces
        call PAINT              ; the faces, far to near
.nofill:
        cmp  byte [wmode],0     ; filled alone?
        je   .nowire            ;   then no wire, no numbers
        mov  ax,[bufseg]        ; ES = the buffer again, whatever the
        mov  es,ax              ;  fill left in it
        call PROJV             ; every vertex onto the screen: SX, SY
        call WIRE               ; every face's four edges
        call NUMBERS            ; every vertex's number beside it
.nowire:
        call GLOW               ; the nozzle burns
        call SHEET              ; the words

        ; ---- the frame onto the screen ---------------------------------------
        call WAITVR             ; wait for the beam to go back up
        push ds                 ; keep DS
        mov  ax,0A000h          ; AX = the screen's segment
        mov  es,ax              ; ES = the screen
        mov  ds,[bufseg]        ; DS = the buffer
        xor  si,si              ; SI = 0
        xor  di,di              ; DI = 0
        mov  cx,32000           ; CX = 32000 words
        rep  movsw              ; the buffer onto the screen
        pop  ds                 ; DS = ours again

        ; ---- the keys ---------------------------------------------------------
        mov  ah,1               ; a key waiting?
        int  16h
        jz   FRAME              ;   no: the next frame
        xor  ah,ah              ; yes: take it - AL = ASCII, AH = scan code
        int  16h
        cmp  al,27              ; ESC?
        je   QUIT
        and  al,0DFh            ; lower case to upper - lesson 1A's AND
        cmp  al,'W'             ; W?
        jne  .nw
        inc  byte [wmode]       ; the next way of drawing it
        cmp  byte [wmode],3     ; past the last?
        jb   FRAME
        mov  byte [wmode],0     ;   back to FILLED
        jmp  FRAME
.nw:    cmp  ah,48h             ; UP: the next aeroplane
        jne  .kdn
        inc  word [cmodel]      ; cmodel++
        cmp  word [cmodel],5    ; past the tanker?
        jb   .set
        mov  word [cmodel],0    ;   back to the fighter
        jmp  .set
.kdn:   cmp  ah,50h             ; DOWN: the one before
        jne  .klf
        dec  word [cmodel]      ; cmodel--
        jns  .set               ; still nought or more?
        mov  word [cmodel],4    ;   no: the tanker
.set:   call SETM               ; roll it out
        jmp  FRAME
.klf:   cmp  ah,4Bh             ; LEFT: spin less, or the other way
        jne  .krt
        cmp  word [spd],-4      ; as far as it goes?
        jle  FRAME
        dec  word [spd]         ; spd--
        jmp  FRAME
.krt:   cmp  ah,4Dh             ; RIGHT: spin more
        jne  FRAME
        cmp  word [spd],4
        jge  FRAME
        inc  word [spd]         ; spd++
        jmp  FRAME

QUIT:   mov  ax,0003h           ; text mode again
        int  10h
        mov  ax,4C00h           ; and back to DOS
        int  21h

; ---- SETM: the aeroplane [cmodel] onto the stand - its tables, its sizes ----
SETM:   mov  bx,[cmodel]        ; BX = which
        add  bx,bx              ; BX *= 2: a word a type in each table
        mov  ax,[MVTAB+bx]      ; its vertex table
        mov  [mvb],ax
        mov  ax,[MVNTAB+bx]     ; how many bytes of it
        mov  [mvn],ax
        mov  ax,[MFTAB+bx]      ; its face table
        mov  [mfb],ax
        mov  ax,[NFCTAB+bx]     ; how many faces
        mov  [nfc],ax
        mov  ax,[PDZT+bx]       ; how far back it stands
        mov  [pdzc],ax
        ret

; ---- CORNERS: for each face, its four corners out of the vertex cache ------
;  CAX/CAY/CAZ hold four corners a face, eight bytes; the face table holds
;  five bytes a face - four vertex numbers and a colour.
CORNERS:
        mov  word [pfc],0       ; pfc = the face, from 0
.cf:    mov  si,[pfc]           ; SI = f
        mov  bx,si              ; BX = f
        shl  bx,1               ; BX = f*2
        shl  bx,1               ; BX = f*4
        add  bx,si              ; BX = f*5: five bytes a face
        add  bx,[mfb]           ; BX = &faces[f]
        mov  ax,si              ; AX = f
        mov  cl,3               ; CL = 3
        shl  ax,cl              ; AX = f*8: four words a face
        mov  di,ax              ; DI = the face's corners
        xor  cx,cx              ; CX = k, the corner, 0..3
.cc:    mov  si,cx              ; SI = k
        mov  al,[bx+si]         ; AL = the k-th vertex number of the face
        xor  ah,ah              ; AX = it
        add  ax,ax              ; AX = *2: a word a vertex in the cache
        mov  si,ax              ; SI = it
        mov  ax,[PVX+si]        ; that vertex, into the corner
        mov  [CAX+di],ax
        mov  ax,[PVY+si]
        mov  [CAY+di],ax
        mov  ax,[PVZ+si]
        mov  [CAZ+di],ax
        add  di,2               ; the next corner
        inc  cx                 ; k++
        cmp  cx,4               ; four?
        jb   .cc
        inc  word [pfc]         ; the next face
        mov  ax,[nfc]
        cmp  [pfc],ax           ; all of them?
        jb   .cf
        ret

; ---- DEPTHS: each face's depth = the average z of its corners --------------
;  Halves of halves - (a+b)/2 and (c+d)/2, then their average - so no sum
;  of four ever needs more than a word.
DEPTHS: mov  word [pfc],0       ; pfc = the face
.fd:    mov  si,[pfc]           ; SI = f
        mov  ax,si
        mov  cl,3
        shl  ax,cl              ; AX = f*8
        mov  si,ax              ; SI = the face's corners
        mov  cx,[CAZ+si]        ; CX = z0
        add  cx,[CAZ+si+2]      ; CX = z0 + z1
        sar  cx,1               ; CX = /2
        mov  dx,[CAZ+si+4]      ; DX = z2
        add  dx,[CAZ+si+6]      ; DX = z2 + z3
        sar  dx,1               ; DX = /2
        add  cx,dx              ; CX = both halves
        sar  cx,1               ; CX = /2: the average of the four
        mov  si,[pfc]           ; SI = f
        mov  bx,si
        add  bx,bx              ; BX = f*2
        mov  [FCD+bx],cx        ; depth[f] = it
        mov  ax,si
        mov  [FCO+si],al        ; order[f] = f: start in table order
        inc  word [pfc]
        mov  ax,[nfc]
        cmp  [pfc],ax
        jb   .fd
        ret

; ---- BUBBLE: the faces far to near ------------------------------------------
;  Swap any neighbours that are the wrong way round, and go over the list
;  again, n-1 times. Between two frames the order hardly changes - so the
;  swaps are few, and the passes are short: n is eight, or twelve.
;  In C:
;      for (pass = nfc-1; pass > 0; pass--)
;          for (i = 0; i < nfc-1; i++)
;              if (depth[i] < depth[i+1]) { swap(depth[i], depth[i+1]);
;                                           swap(order[i], order[i+1]); }
BUBBLE: mov  cx,[nfc]           ; CX = n
        dec  cx                 ; CX = n-1 passes
.bs:    push cx
        xor  si,si              ; SI = i
.bi:    mov  bx,si
        add  bx,bx              ; BX = i*2
        mov  ax,[FCD+bx]        ; AX = depth[i]
        cmp  ax,[FCD+bx+2]      ; nearer than depth[i+1]?
        jge  .nsw               ;   no: the right way round
        xchg ax,[FCD+bx+2]      ;   yes: swap the depths...
        mov  [FCD+bx],ax
        mov  al,[FCO+si]        ;   ...and the faces
        xchg al,[FCO+si+1]
        mov  [FCO+si],al
.nsw:   inc  si                 ; i++
        mov  bx,[nfc]
        dec  bx                 ; BX = n-1
        cmp  si,bx              ; i < n-1?
        jb   .bi
        pop  cx
        loop .bs
        ret

; ---- PAINT: every face, far to near, through FACEFILL ----------------------
;  FACEFILL takes four corners in IX/IY/IZ and does the rest: the near clip,
;  the projection, the scanline fill. The later face simply overwrites the
;  earlier one - that is all the hiding there is.
PAINT:  mov  word [pfc],0       ; pfc = the place in the order
.df:    mov  si,[pfc]
        mov  al,[FCO+si]        ; AL = the face in this place
        xor  ah,ah              ; AX = f
        mov  si,ax              ; SI = f
        mov  bx,ax
        shl  bx,1
        shl  bx,1               ; BX = f*4
        add  bx,ax              ; BX = f*5
        add  bx,[mfb]           ; BX = &faces[f]
        mov  al,[bx+4]          ; AL = its colour
        mov  [COLOR],al         ; COLOR = it
        mov  ax,si
        mov  cl,3
        shl  ax,cl              ; AX = f*8
        mov  si,ax              ; SI = its corners
        xor  di,di              ; DI = the corner in IX/IY/IZ
.dc:    mov  ax,[CAX+si]        ; four corners into FACEFILL's input
        mov  [IX+di],ax
        mov  ax,[CAY+si]
        mov  [IY+di],ax
        mov  ax,[CAZ+si]
        mov  [IZ+di],ax
        add  si,2
        add  di,2
        cmp  di,8
        jb   .dc
        call FACEFILL           ; clip, project, fill
        inc  word [pfc]
        mov  ax,[nfc]
        cmp  [pfc],ax
        jb   .df
        ret

; ---- PROJV: every vertex onto the screen, into SX/SY ------------------------
;  The lens of lesson 0F: x*FOCAL/z, y*FOCAL/z, from the middle. PROJPT does
;  it - and every vertex here is far enough in front to need no clip.
PROJV:  xor  di,di              ; DI = the vertex, 2 bytes each
.pv:    mov  ax,[PVX+di]        ; AX = x
        mov  dx,[PVY+di]        ; DX = y
        mov  cx,[PVZ+di]        ; CX = z
        push di
        call PROJPT             ; AX, DX = the screen's x and y
        pop  di
        mov  [SX+di],ax         ; kept
        mov  [SY+di],dx
        add  di,2               ; the next vertex
        mov  ax,di
        add  ax,ax              ; AX = di*2...
        add  ax,di              ; ...+di = di*3: the table's bytes so far
        cmp  ax,[mvn]           ; all of them?
        jb   .pv
        ret

; ---- WIRE: every face's four edges, from vertex to vertex -------------------
;  Corner k to corner k+1, and the last back to the first. A triangle has a
;  vertex twice - one of its edges is a point, and costs nothing.
WIRE:   mov  byte [COLOR],WIREC ; the wire's colour
        mov  word [pfc],0       ; pfc = the face
.wf:    mov  si,[pfc]
        mov  bx,si
        shl  bx,1
        shl  bx,1               ; BX = f*4
        add  bx,si              ; BX = f*5
        add  bx,[mfb]           ; BX = &faces[f]
        xor  cx,cx              ; CX = k
.we:    mov  si,cx              ; SI = k
        mov  al,[bx+si]         ; AL = vertex a
        inc  si                 ; k+1...
        and  si,3               ; ...round to 0 after 3
        mov  ah,[bx+si]         ; AH = vertex b
        push bx
        push cx
        mov  bl,al              ; the edge's two ends from SX/SY
        xor  bh,bh
        add  bx,bx              ; BX = a*2
        mov  dx,[SX+bx]
        mov  [sx0],dx
        mov  dx,[SY+bx]
        mov  [sy0],dx
        mov  bl,ah
        xor  bh,bh
        add  bx,bx              ; BX = b*2
        mov  dx,[SX+bx]
        mov  [sx1],dx
        mov  dx,[SY+bx]
        mov  [sy1],dx
        call CLIPLINE           ; on the screen at all?
        jc   .wn                ;   no
        call LINE               ;   yes: draw it
.wn:    pop  cx
        pop  bx
        inc  cx                 ; the next edge
        cmp  cx,4
        jb   .we
        inc  word [pfc]         ; the next face
        mov  ax,[nfc]
        cmp  [pfc],ax
        jb   .wf
        ret

; ---- NUMBERS: each vertex's number, just right of it -----------------------
;  In lesson 1A's 4x6 digits, with a dark ring the lazy way: the number
;  drawn four times in black, a pixel off each way, then once in amber on
;  top - the numbers of the table, on the screen.
NUMBERS:
        xor  di,di              ; DI = the vertex, 2 bytes each
.nv:    mov  ax,di
        shr  ax,1               ; AX = the vertex's number
        call NUMSTR             ; SI = its digits
        mov  bx,[SX+di]
        add  bx,3               ; BX = x + 3: just right of the point
        mov  ax,[SY+di]
        sub  ax,7               ; AX = y - 7: just above it
        push di
        call DIGITS             ; draw them, ringed
        pop  di
        add  di,2               ; the next vertex
        mov  ax,di
        add  ax,ax
        add  ax,di              ; AX = di*3
        cmp  ax,[mvn]
        jb   .nv
        ret

; ---- DIGITS: SI = digits, BX = x, AX = y: the ring four times, then the ink -
DIGITS: mov  [dgx],bx           ; keep where
        mov  [dgy],ax
        mov  [dgs],si           ; and what
        mov  byte [dgc],0       ; black, four times:
        mov  bx,[dgx]
        dec  bx                 ; BX = x-1
        mov  ax,[dgy]
        call DIG1               ; one to the left
        mov  bx,[dgx]
        inc  bx                 ; BX = x+1
        mov  ax,[dgy]
        call DIG1               ; one to the right
        mov  bx,[dgx]
        mov  ax,[dgy]
        dec  ax                 ; AX = y-1
        call DIG1               ; one up
        mov  bx,[dgx]
        mov  ax,[dgy]
        inc  ax                 ; AX = y+1
        call DIG1               ; one down
        mov  byte [dgc],NUMC    ; then amber, in the middle
        mov  bx,[dgx]
        mov  ax,[dgy]
        call DIG1
        ret

; ---- DIG1: [dgs] in 4x6 digits at BX = x, AX = y, colour [dgc] -------------
;  Each row of a digit is a byte, the top three bits its pixels - SHL drops
;  them into the carry one at a time. Lesson 1A's TXT46, digits only.
DIG1:   mov  [dgyc],ax          ; dgyc = the digits' top row
        mov  si,[dgs]           ; SI = the digits
.ch:    lodsb                   ; AL = the next one
        or   al,al              ; the end?
        jz   .done
        sub  al,'0'             ; AL = 0..9
        xor  ah,ah              ; AX = d
        mov  cx,ax              ; CX = d
        shl  ax,1               ; AX = d*2
        shl  cx,1
        shl  cx,1               ; CX = d*4
        add  ax,cx              ; AX = d*6: six rows a digit
        add  ax,DIG46           ; AX = &DIG46[d*6]
        push si                 ; keep the place in the digits
        push bx                 ; and the digit's left column
        mov  si,ax              ; SI = its rows
        mov  word [dgr],0       ; dgr = the row, from 0
        mov  cx,6               ; CX = six rows
.row:   push cx
        lodsb                   ; AL = the row's bits
        mov  ah,al              ; AH = them
        mov  cx,3               ; CX = three columns
        push bx
.px:    shl  ah,1               ; CF = the next pixel
        jnc  .np                ;   0: nothing
        call DOT                ;   1: plot it
.np:    inc  bx                 ; the next column
        loop .px
        pop  bx                 ; back to the left column
        pop  cx
        inc  word [dgr]         ; the next row down
        loop .row
        pop  bx
        pop  si
        add  bx,4               ; the next digit: four pixels on
        jmp  .ch
.done:  ret

; ---- DOT: one pixel at x = BX, y = [dgyc] + [dgr], colour [dgc] ------------
;  Off the screen is skipped; keeps every register.
DOT:    push ax
        push dx
        push di
        mov  ax,[dgyc]          ; AX = the digits' top row
        add  ax,[dgr]           ; AX += the row within the digit
        cmp  ax,0               ; on the screen?
        jl   .x
        cmp  ax,199
        jg   .x
        cmp  bx,0
        jl   .x
        cmp  bx,319
        jg   .x
        mov  di,320             ; DI = 320
        mul  di                 ; AX = y*320
        add  ax,bx              ; AX = y*320 + x
        mov  di,ax              ; DI = it
        mov  al,[dgc]           ; AL = the colour
        mov  [es:di],al         ; the pixel
.x:     pop  di
        pop  dx
        pop  ax
        ret

; ---- NUMSTR: AX = n -> SI = its digits in NBUF ------------------------------
NUMSTR: mov  si,NBUF+5          ; SI = just past the last digit (0 ends it)
        mov  bx,10              ; BX = 10
.d:     xor  dx,dx              ; DX:AX = n
        div  bx                 ; AX = n/10, DX = the last digit
        add  dl,'0'             ; DL = its character
        dec  si                 ; one place left
        mov  [si],dl
        or   ax,ax              ; more?
        jnz  .d
        ret

; ---- GLOW: the nozzle burns - one DAC entry rewritten, no pixel touched ----
GLOW:   inc  word [gcnt]        ; gcnt++
        test word [gcnt],7      ; every eighth frame
        jnz  .ng
        mov  bx,[gph]           ; BX = the phase
        add  bx,bx
        add  bx,[gph]           ; BX = phase*3: three bytes a colour
        mov  dx,3C8h            ; the DAC's write index
        mov  al,94              ; colour 94, the nozzle
        out  dx,al
        inc  dx                 ; the DAC's data port
        mov  al,[GLOWT+bx]      ; red
        out  dx,al
        mov  al,[GLOWT+bx+1]    ; green
        out  dx,al
        mov  al,[GLOWT+bx+2]    ; blue
        out  dx,al
        inc  word [gph]         ; the next phase
        cmp  word [gph],3
        jb   .ng
        mov  word [gph],0
.ng:    ret

; ---- SHEET: the words - counts and the W mode on top, the spec at the foot -
SHEET:  mov  ax,[mvn]           ; AX = the vertex table's bytes
        xor  dx,dx
        mov  bx,6
        div  bx                 ; AX = the vertices: six bytes each
        call NUMSTR             ; SI = their count
        mov  di,HCNT            ; copy it into "nn VERTICES"
        call COPYN
        mov  ax,[nfc]           ; AX = the faces
        call NUMSTR
        mov  di,HCNT+13         ; into "nn FACES"
        call COPYN
        mov  byte [tcol],28     ; grey
        mov  si,HCNT
        mov  ax,4               ; row 4
        mov  bx,8               ; column 8
        call TXT
        mov  bl,[wmode]         ; the W mode's name
        xor  bh,bh
        add  bx,bx
        mov  si,[WMTAB+bx]
        mov  byte [tcol],30     ; amber
        mov  ax,14              ; row 14
        mov  bx,8
        call TXT
        mov  bx,[cmodel]        ; the spec sheet, three lines a type
        add  bx,bx
        mov  ax,bx
        add  ax,ax
        add  bx,ax              ; BX = cmodel*6
        mov  byte [tcol],30     ; amber name
        push bx
        mov  si,[INFTAB+bx]
        mov  ax,168
        mov  bx,8
        call TXT
        pop  bx
        mov  byte [tcol],28     ; grey data
        push bx
        mov  si,[INFTAB+bx+2]
        mov  ax,180
        mov  bx,8
        call TXT
        pop  bx
        mov  si,[INFTAB+bx+4]
        mov  ax,190
        mov  bx,8
        call TXT
        ret

; ---- COPYN: the digits at SI into DI, right-aligned in two places ----------
COPYN:  mov  word [di],'  '     ; two blanks first
        mov  cx,NBUF+5          ; CX = the end of the digits
        sub  cx,si              ; CX = how many: 1 or 2
        cmp  cx,1
        jne  .two
        inc  di                 ; one digit: in the second place
.two:   lodsb                   ; copy them
        or   al,al
        jz   .x
        mov  [di],al
        inc  di
        jmp  .two
.x:     ret

; ---- TXT: ASCIIZ at SI -> the buffer at (BX, AX), colour [tcol] ------------
;  The PC's ROM font at F000:FA6E - lesson 1A's first kind of letters.
TXT:    push es
        push dx
        mov  cx,ax
        mov  ax,[bufseg]
        mov  es,ax
        mov  ax,cx
        mov  cx,320
        mul  cx                 ; AX = y*320
        add  ax,bx              ; AX = y*320 + x
        mov  di,ax              ; DI = the first cell's top-left
.ch:    lodsb                   ; AL = the next character
        or   al,al
        jz   .done
        push si
        xor  ah,ah
        mov  cl,3
        shl  ax,cl              ; AX = char*8: its glyph
        mov  si,0FA6Eh
        add  si,ax              ; SI = F000:FA6E + char*8
        push ds
        mov  ax,0F000h
        mov  ds,ax              ; DS = the ROM
        mov  cx,8               ; eight rows
        push di
.row:   lodsb                   ; AL = a row of bits
        mov  ah,al
        push cx
        mov  cx,8               ; eight columns
.px:    shl  ah,1               ; CF = the next pixel
        jnc  .np
        mov  al,[cs:tcol]       ; ([cs:] because DS is the ROM)
        mov  [es:di],al
.np:    inc  di
        loop .px
        add  di,320-8           ; the next row of the cell
        pop  cx
        loop .row
        pop  di
        pop  ds
        pop  si
        add  di,8               ; the next cell
        jmp  .ch
.done:  pop  dx
        pop  es
        ret

; ---- WAITVR: the vertical retrace's start ----------------------------------
WAITVR: mov  dx,3DAh
.w1:    in   al,dx
        test al,8
        jnz  .w1
.w2:    in   al,dx
        test al,8
        jz   .w2
        ret

; ---- SETPAL: the few DAC entries this hangar uses ---------------------------
SETPAL: mov  si,PAL
.p:     lodsb                   ; AL = the colour number
        cmp  al,255             ; the end?
        je   .done
        mov  dx,3C8h            ; DAC write index
        out  dx,al
        inc  dx                 ; DAC data
        lodsb                   ; red, green, blue
        out  dx,al
        lodsb
        out  dx,al
        lodsb
        out  dx,al
        jmp  .p
.done:  ret
PAL     db   0,  2, 4,12        ; the backdrop: a night blue
        db  16, 20,20,22        ; the body's shade
        db  24, 52,52,56        ; the body, sun-lit
        db  25, 34,34,38        ; the sides and the fin
        db  27, 44,44,46        ; the wings
        db  94, 63,34, 6        ; the nozzle (cycled by GLOW)
        db  28, 56,56,56        ; grey words
        db  30, 63,42,10        ; amber words and numbers
        db  31, 20,60,63        ; the wire: cyan
        db 255

; ---- THE AIR FORCE. GAMES\OWLFLY3\SRC\DATA.INC's hand-drawn tables, as
;      EXAMPLES\JET.ASM has them (the wings coloured 27 for this palette).
;      The types share the first 13 vertices and 8 faces; the engines and
;      the dome are vertices and faces added on.
MVTAB   dw MVERT,MVERT1,MVERT2,MVERT3,MVERT4
MVNTAB  dw 13*6,25*6,19*6,13*6,19*6     ; vertex bytes: six a vertex
MFTAB   dw MFACE,MFACE1,MFACE2,MFACE3,MFACE4
NFCTAB  dw 8,12,10,8,10                 ; faces
PDZT    dw 300,560,420,400,460          ; how far back each one stands
MVERT   dw   0,  1, 16          ; FIGHTER                 0  the nose
        dw  -2,  2,-11          ;                         1  tail, top left
        dw   2,  2,-11          ;                         2  tail, top right
        dw  -2, -2,-11          ;                         3  tail, low left
        dw   2, -2,-11          ;                         4  tail, low right
        dw -13,  1, -8          ;                         5  left wing tip
        dw  13,  1, -8          ;                         6  right wing tip
        dw   0,  1,  6          ;                         7  the wing root
        dw  -2,  1,-11          ;                         8  wing, rear left
        dw   2,  1,-11          ;                         9  wing, rear right
        dw   0,  2, -5          ;                        10  fin, front
        dw   0,  7,-13          ;                        11  fin, top
        dw   0,  2,-11          ;                        12  fin, rear
MFACE   db 0,1,2,0, 24          ; the top: nose to the tail's top edge
        db 0,3,4,0, 16          ; the belly
        db 0,1,3,0, 25          ; the left side
        db 0,2,4,0, 25          ; the right side
        db 7,5,8,7, 27          ; the left wing
        db 7,6,9,7, 27          ; the right wing
        db 10,11,12,10, 25      ; the fin
        db 1,2,4,3, 94          ; the nozzle: the tail's square
MVERT1  dw   0,  1, 34          ; BOMBER: four engines under the wings
        dw  -5,  5,-22
        dw   5,  5,-22
        dw  -5, -4,-22
        dw   5, -4,-22
        dw -28,  1, -6
        dw  28,  1, -6
        dw   0,  1, 10
        dw  -5,  1,-20
        dw   5,  1,-20
        dw   0,  5,-10
        dw   0, 13,-26
        dw   0,  5,-22
        dw -10,  0,  6
        dw -10,  0, -2
        dw -10, -4,  2
        dw -19,  0,  2
        dw -19,  0, -6
        dw -19, -4, -2
        dw  10,  0,  6
        dw  10,  0, -2
        dw  10, -4,  2
        dw  19,  0,  2
        dw  19,  0, -6
        dw  19, -4, -2
MFACE1  db 0,1,2,0, 24
        db 0,3,4,0, 16
        db 0,1,3,0, 25
        db 0,2,4,0, 25
        db 7,5,8,7, 27
        db 7,6,9,7, 27
        db 10,11,12,10, 25
        db 1,2,4,3, 94
        db 13,14,15,13, 16      ; the four engines: a triangle each
        db 16,17,18,16, 16
        db 19,20,21,19, 16
        db 22,23,24,22, 16
MVERT2  dw   0,  2, 20          ; RADAR PICKET: the rotodome on top
        dw  -4,  5,-14
        dw   4,  5,-14
        dw  -4, -3,-14
        dw   4, -3,-14
        dw -18,  2, -2
        dw  18,  2, -2
        dw   0,  2,  6
        dw  -4,  2,-12
        dw   4,  2,-12
        dw   0,  5, -6
        dw   0,  9,-14
        dw   0,  5,-14
        dw   0, 10,  2
        dw   4, 10, -4
        dw   0, 10,-10
        dw  -4, 10, -4
        dw   0, 12, -4
        dw   0,  8, -4
MFACE2  db 0,1,2,0, 24
        db 0,3,4,0, 16
        db 0,1,3,0, 25
        db 0,2,4,0, 25
        db 7,5,8,7, 27
        db 7,6,9,7, 27
        db 10,11,12,10, 25
        db 1,2,4,3, 94
        db 13,14,15,16, 24      ; the dome: a flat diamond...
        db 13,17,15,18, 16      ; ...and its edge, standing up
MVERT3  dw   0,  2, 18          ; TRANSPORT: fat and slow
        dw  -5,  6,-14
        dw   5,  6,-14
        dw  -5, -4,-14
        dw   5, -4,-14
        dw -20,  3, -2
        dw  20,  3, -2
        dw   0,  3,  6
        dw  -5,  3,-12
        dw   5,  3,-12
        dw   0,  6, -6
        dw   0, 12,-16
        dw   0,  6,-14
MFACE3  db 0,1,2,0, 24
        db 0,3,4,0, 16
        db 0,1,3,0, 25
        db 0,2,4,0, 25
        db 7,5,8,7, 27
        db 7,6,9,7, 27
        db 10,11,12,10, 25
        db 1,2,4,3, 94
MVERT4  dw   0,  2, 26          ; TANKER: the fuel truck of the air
        dw  -7,  7,-18
        dw   7,  7,-18
        dw  -7, -5,-18
        dw   7, -5,-18
        dw -22,  2, -4
        dw  22,  2, -4
        dw   0,  2,  8
        dw  -7,  2,-16
        dw   7,  2,-16
        dw   0,  7, -8
        dw   0, 13,-20
        dw   0,  7,-18
        dw -11,  1,  6
        dw -11,  1, -2
        dw -11, -4,  2
        dw  11,  1,  6
        dw  11,  1, -2
        dw  11, -4,  2
MFACE4  db 0,1,2,0, 24
        db 0,3,4,0, 16
        db 0,1,3,0, 25
        db 0,2,4,0, 25
        db 7,5,8,7, 27
        db 7,6,9,7, 27
        db 10,11,12,10, 25
        db 1,2,4,3, 94
        db 13,14,15,13, 16      ; two engines under the wings
        db 16,17,18,16, 16
GLOWT   db 63,52,12             ; the nozzle: yellow...
        db 63,34, 6             ; ...orange...
        db 56,14, 4             ; ...red
; ---- lesson 1A's digits, 4x6: the top three bits of each row ---------------
DIG46   db 11100000b,10100000b,10100000b,10100000b,11100000b,00000000b ; 0
        db 01000000b,11000000b,01000000b,01000000b,11100000b,00000000b ; 1
        db 11100000b,00100000b,11100000b,10000000b,11100000b,00000000b ; 2
        db 11100000b,00100000b,11100000b,00100000b,11100000b,00000000b ; 3
        db 10100000b,10100000b,11100000b,00100000b,00100000b,00000000b ; 4
        db 11100000b,10000000b,11100000b,00100000b,11100000b,00000000b ; 5
        db 11100000b,10000000b,11100000b,10100000b,11100000b,00000000b ; 6
        db 11100000b,00100000b,01000000b,01000000b,01000000b,00000000b ; 7
        db 11100000b,10100000b,11100000b,10100000b,11100000b,00000000b ; 8
        db 11100000b,10100000b,11100000b,00100000b,11100000b,00000000b ; 9
; ---- the words ---------------------------------------------------------------
HCNT    db 'nn VERTICES  nn FACES',0
WMTAB   dw WM0,WM1,WM2
WM0     db 'W: FILLED',0
WM1     db 'W: FILLED + WIRE + NUMBERS',0
WM2     db 'W: WIRE + NUMBERS',0
INF0A   db 'FIGHTER',0
INF0B   db 'WEIGHT 18T   SPEED 950 KM/H',0
INF0C   db 'AIR SUPERIORITY        2-5 HITS TO KILL',0
INF1A   db 'BOMBER',0
INF1B   db 'WEIGHT 110T  SPEED 700 KM/H',0
INF1C   db 'LEVELS ENEMY CITY BLOCKS    6 HITS',0
INF2A   db 'RADAR PICKET',0
INF2B   db 'WEIGHT 78T   SPEED 650 KM/H',0
INF2C   db 'THE EYES OF THE TEAM        5 HITS',0
INF3A   db 'TRANSPORT',0
INF3B   db 'WEIGHT 92T   SPEED 600 KM/H',0
INF3C   db 'DROPS PARATROOPERS          5 HITS',0
INF4A   db 'TANKER',0
INF4B   db 'WEIGHT 140T  SPEED 600 KM/H',0
INF4C   db 'THE FLYING FUEL STATION     5 HITS',0
INFTAB  dw INF0A,INF0B,INF0C, INF1A,INF1B,INF1C, INF2A,INF2B,INF2C
        dw INF3A,INF3B,INF3C, INF4A,INF4B,INF4C

; ---- the state ---------------------------------------------------------------
bufseg  dw 0
mhead   dw 0                    ; the spin's angle
spd     dw 1                    ; the spin a frame, -4..4
cmodel  dw 3                    ; which aeroplane: the transport first - the
                                ;  one the notebook draws
mvb     dw MVERT                ; its vertex table...
mvn     dw 13*6                 ; ...its bytes...
mfb     dw MFACE                ; ...its face table...
nfc     dw 8                    ; ...its faces...
pdzc    dw 300                  ; ...and how far back it stands
wmode   db 0                    ; W: 0 filled, 1 filled + wire, 2 wire
tcol    db 28                   ; TXT's colour
rseed   dw 1                    ; RND16's state (E_MATH wants it)
gcnt    dw 0                    ; GLOW's frame count
gph     dw 0                    ; GLOW's phase
NBUF    db 6 dup(0)             ; NUMSTR's digits; NBUF+5 stays 0
dgx     dw 0                    ; DIGITS: where...
dgy     dw 0
dgs     dw 0                    ; ...what...
dgc     db 0                    ; ...in what colour
dgr     dw 0                    ; DIG1/DOT: the row within a digit
dgyc    dw 0                    ; DOT: the digit's top row
CAX     dw MAXF*4 dup(0)        ; every face's four corners
CAY     dw MAXF*4 dup(0)
CAZ     dw MAXF*4 dup(0)
PVX     dw MAXV dup(0)          ; every vertex, turned and placed
PVY     dw MAXV dup(0)
PVZ     dw MAXV dup(0)
SX      dw MAXV dup(0)          ; every vertex on the screen (W)
SY      dw MAXV dup(0)
FCD     dw MAXF dup(0)          ; every face's depth
FCO     db MAXF dup(0)          ; the painter's order
heading dw 0                    ; ---- the camera: straight and level ----
pitch   dw 0
roll    dw 0
hsin    dw 0
hcos    dw 256
rsin    dw 0
rcos    dw 256
psin    dw 0
pcos    dw 256
pofs    dw 0
horiz   dw 100
swayx   dw 0
swayy   dw 0
wdx     dw 0
wdz     dw 0
rc_x    dw 0
rc_z    dw 0
rddx    dw 0
rddy    dw 0
rsxo    dw 0
ptmp    dw 0
ty      dw 0                    ; a vertex's y' and z', before the tilt
tz      dw 0
msin    dw 0                    ; the spin's sine and cosine
mcos    dw 0
pfc     dw 0                    ; the face being worked on
IX      dw 4 dup(0)             ; FACEFILL: a face's four corners in...
IY      dw 4 dup(0)
IZ      dw 4 dup(0)
OX      dw 6 dup(0)             ; ...clipped by the near plane...
OY      dw 6 dup(0)
OZ      dw 6 dup(0)
PX      dw 6 dup(0)             ; ...and on the screen
PY      dw 6 dup(0)
NPOLY   dw 0
oc      dw 0
ci      dw 0
ni      dw 0
pk      dw 0
pminy   dw 0
pmaxy   dw 0
scy     dw 0
scymax  dw 0
scxl    dw 0
scxr    dw 0
tnum    dw 0
tden    dw 0
cdx     dw 0
cdy     dw 0
nx      dw 0
ny      dw 0
oc0     db 0
oc1     db 0
ocsel   db 0
lx      dw 0
ly      dw 0
ldx     dw 0
ldy     dw 0
lsx     dw 0
lsy     dw 0
lerr    dw 0
sx0     dw 0
sy0     dw 0
sx1     dw 0
sy1     dw 0
COLOR   db 0
; the quarter sine: SINT[i] = round(256*sin(i*90/64 deg)), i = 0..64
SINT    dw 0,6,13,19,25,31,38,44,50,56,62,68,74,80,86,92,98,104,109,115
        dw 121,126,132,137,142,147,153,157,162,167,172,177,181,185,190,194
        dw 198,202,206,209,213,216,220,223,226,229,231,234,237,239,241,243
        dw 245,247,248,250,251,252,253,254,255,255,256,256,256

        include '..\..\ENGINE\E_MATH.INC'
        include '..\..\ENGINE\E_M3D.INC'
        include '..\..\ENGINE\E_RAST.INC'
