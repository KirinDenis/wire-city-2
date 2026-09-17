; ============================================================================
;  CLIP.ASM - Lesson 13. CLIPPING A LINE: the near plane, and the glass.
;
;      FASM CLIP.ASM CLIP.COM
;
;      1  the island from above - lesson 0x11's map, and the mark where
;         you are about to be standing and which way you will be facing
;      2  the flight, with both fences up - flat coloured squares, so you
;         know what right looks like before anything is taken away
;      3  the NEAR PLANE taken away. The glass is still clipped, so it is
;         tidy - and the world behind your head is drawn, mirrored, above
;         the horizon. This stage is the whole lesson
;      4  the GLASS taken away too. Nothing clipped, a frame a minute,
;         drawn straight onto the screen so you can watch what it costs
;      5  everything back. Fly it
;
;  THIS LESSON STOPS WRITING AND STARTS READING, and that is the point of
;  it. Every line of arithmetic below comes out of the game. Not a lesson
;  version of the game's idea - the routines themselves, from the files
;  that are assembled into the thing you can go and play:
;
;      ENGINE\E_8086.INC   keeps FASM inside the 8086 instruction set
;      ENGINE\E_MATH.INC   RND16, the congruential draw of lesson 0x11
;      ENGINE\E_TERR.INC   DSGEN and HGET - lesson 0x11's island, entire
;      ENGINE\E_M3D.INC    SINQ, SETTRIG, ROTXZ, PROJPT, CLAMPAX
;      ENGINE\E_RAST.INC   OUTCODE, CLIPLINE, LINE
;
;  and the four routines this file carries itself - DRAWEDGE3D, NEARCLIP,
;  CLIPP0, CLIPP1 - are copied out of GAMES\WIRECITY\CITY.ASM without one
;  instruction changed. Open that file at line 818 and read along.
;
;  The ONE edit is two bytes of flag, so the stages can turn each fence
;  off and let you watch what it was holding back. Everything else is the
;  game.
;
;  WHAT IS ON THE SCREEN. WIRE CITY flew over a flat lattice: world-aligned
;  lines around the camera, and the ground was a plane at zero. This is
;  that lattice - flat, still - except that every square is painted by its
;  own height out of the Diamond-Square map. So the coastline is there,
;  and the woods, and the snow, and you can fly to them; the ground simply
;  has no relief yet. The relief is the next lesson, and it is one number
;  per corner away.
;
;  THE PHYSICAL FACT THIS LESSON HANDS OVER:
;
;      A POINT BEHIND YOUR EYE HAS NO IMAGE. Not a wrong image - none.
;      There is no line from it through your eye that ever meets the
;      glass, because the glass is on the other side of you. Ask for one
;      anyway and the machine does not argue: it hands you a number.
;
;  And a lattice cannot be dropped whole the way lesson 0x10 dropped a
;  cube. You are standing in the middle of it. Half of it is behind you in
;  every frame, for ever, and every one of those lines runs from behind
;  your head to somewhere in front of you.
;
;  THE TWO FENCES, and they are not the same fence:
;
;      NEARCLIP  cuts the edge in THREE dimensions, at z = NEARZ, before
;                anything is divided. It is about what CANNOT be drawn.
;      CLIPLINE  cuts the line in TWO dimensions, at the edges of the
;                screen, after the divide. It is about what NEED not be.
;
;  Stage 3 takes the first one down and leaves the second, and the picture stays nonsense.
;  That stage is the whole lesson: clipping the symptom is not the same as
;  fixing the cause, and a program can be perfectly tidy about drawing the
;  wrong thing.
;
;  AND A THIRD THING THAT IS NOT A FENCE AT ALL. CLAMPAX, in E_M3D.INC,
;  pins a projected coordinate at plus or minus four thousand. It does not
;  clip - it SUBSTITUTES. Move one endpoint of a line and the whole
;  segment swings. That is the bug written up at GRID in
;  GAMES\OWLFLY3\SRC\WORLD.INC under the heading "WHY THE GRID CAME APART,
;  IN ONE NUMBER", and stage 4 is that bug, on purpose, at full size.
;
;  Owlos - legacy software modernization - https://owlos.sk
; ============================================================================
format binary as 'com'
        org  100h

        ; .8086 in the TASM source. FASM has no such directive - without
        ; this include it silently uses 386 jumps when a target is out of
        ; range, and the lessons up to here did it by hand.
        include '..\..\ENGINE\E_8086.INC'

FOCAL   = 220                 ; the game's lens: ~72 degrees across
NEARZ   = 40                  ; the game's near clip plane
BIAS    = 8192                ; world->cell bias, keeps the cell shift unsigned
NR      = 10                  ; the lattice reaches ten nodes each way...
NSIDE   = 2*NR+1              ; ...so it is twenty one nodes across
CAMY0   = 900                 ; how high the eye flies over the plane
STEPF   = 96                  ; how far one key walks you...
STEPT   = 3                   ; ...and how far it turns you

CELLW   = 3                   ; the map view of stage 1: 3x3 pixels a node
ORGX    = 64
ORGY    = 4

START:  cld
        mov  ax,cs              ; the back buffer: the 64K above us, the
        add  ax,1000h           ;  way every EXAMPLES program does it
        mov  [bufseg],ax

        push es
        mov  ax,40h             ; 0040:006C, the BIOS tick - the only thing
        mov  es,ax              ;  on this machine that differs between two
        mov  ax,[es:6Ch]        ;  runs. Lesson 0x11 seeded from it too
        pop  es
        or   ax,1
        mov  ax,4242            ; SCRATCH: one fixed world
        mov  [rseed],ax
        call DSGEN              ; ...and there is the island, in one call

        xor  ax,ax              ; ---- take INT 0, and say why -----------
        mov  es,ax              ;  the vector table starts at 0000:0000 and
        mov  ax,[es:0]          ;  vector 0 is its first four bytes
        mov  [oldi0],ax
        mov  ax,[es:2]
        mov  [oldi0+2],ax
        cli                     ; two words, and an interrupt between them
        mov  word [es:0],TRAP0  ;  would find half a vector
        mov  [es:2],cs
        sti

        mov  ax,0013h           ; VGA 320x200, 256 colours
        int  10h
        call SETPAL
        call SETTRIG            ; straight, level, no bank

        mov  word [camx],32*1024
        mov  word [camz],26*1024
        mov  word [camy],CAMY0
        mov  word [heading],0

; ---- SCRATCH dispatcher: SHOT <stage><pose>, four seconds, then out -----
        mov  al,[82h]
        sub  al,'0'
        mov  ah,[83h]
        sub  ah,'0'
        cmp  ah,9
        jbe  .pose
        xor  ah,ah
.pose:  or   ah,ah
        je   .p0
        mov  word [heading],40
        push ax
        call SETTRIG
        pop  ax
.p0:    or   al,al
        je   .bench
        cmp  al,5
        je   .run
        cmp  al,6
        jne  .n6
        mov  byte [fastp],0
        jmp  .run
.n6:        cmp  al,1
        je   .map
        cmp  al,2
        jbe  .go
        mov  byte [doside],1
        cmp  al,3
        je   .go
        mov  byte [donear],1
.go:    call FRAME
        jmp  .hold
.map:   call MAPVIEW
        call SHOW
        jmp  .hold
.run:   mov  byte [donear],1     ; frames for forty ticks, counting, so the
        mov  byte [doside],1     ;  HUD has a real number on it
        push es
        mov  ax,40h
        mov  es,ax
        mov  ax,[es:6Ch]
        pop  es
        mov  [fpst],ax
        add  ax,40
        push ax
.rl:    call FRAME
        inc  word [fpsn]
        push es
        mov  ax,40h
        mov  es,ax
        mov  ax,[es:6Ch]
        pop  es
        mov  bx,ax
        sub  ax,[fpst]
        cmp  ax,18
        jb   .rk
        mov  [fpst],bx
        mov  ax,[fpsn]
        mov  [fpsv],ax
        mov  word [fpsn],0
.rk:    pop  ax
        push ax
        cmp  bx,ax
        jb   .rl
        pop  ax
        jmp  .hold
.bench: mov  byte [donear],1     ; both fences up: the real frame
        mov  byte [doside],1
        push es
        mov  ax,40h
        mov  es,ax
        mov  ax,[es:6Ch]
        pop  es
        push ax
        mov  cx,60
.bl:    push cx
        call FRAME
        pop  cx
        loop .bl
        push es
        mov  ax,40h
        mov  es,ax
        mov  bx,[es:6Ch]
        pop  es
        pop  ax
        sub  bx,ax              ; ticks for twenty frames
        mov  ax,bx
        mov  bx,10
        mul  bx                 ; ten pixels a tick
        mov  cx,ax
        mov  ax,0A000h
        mov  es,ax
        mov  di,320*2
        mov  al,15
        rep  stosb
.hold:  push es
        mov  ax,40h
        mov  es,ax
        mov  ax,[es:6Ch]
        add  ax,70
.w:     mov  bx,[es:6Ch]
        cmp  bx,ax
        jb   .w
        pop  es
QUIT:   xor  ax,ax              ; GIVE INT 0 BACK. A .COM that keeps a
        mov  es,ax              ;  vector pointing into memory DOS is about
        cli                     ;  to hand to the next program has not
        mov  ax,[oldi0]         ;  finished; the next divide fault on this
        mov  [es:0],ax          ;  machine would jump into whatever loads
        mov  ax,[oldi0+2]       ;  here next
        mov  [es:2],ax
        sti
        mov  ax,0003h           ; text mode back, and hand DOS the machine
        int  10h                ;  in the state we borrowed it in
        mov  ax,4C00h
        int  21h

; ============================================================================
;  FLY - one step a key, a picture between each. ESC leaves the stage.
;
;  Arrow keys arrive with AL zero and the scan code in AH - that is what an
;  EXTENDED key is, and lesson 11 met them at the wire.
; ============================================================================
FLY:    call FRAME
        inc  word [fpsn]        ; ---- the frame counter ------------------
        push es                 ;  frames since the tick in fpst; every
        mov  ax,40h             ;  eighteen ticks - one second, near enough
        mov  es,ax              ;  - the count moves to fpsv and starts
        mov  ax,[es:6Ch]        ;  again. OWL FLY III's own meter, the same
        pop  es                 ;  three words
        mov  bx,ax
        sub  ax,[fpst]
        cmp  ax,18
        jb   .poll
        mov  [fpst],bx
        mov  ax,[fpsn]
        mov  [fpsv],ax
        mov  word [fpsn],0
.poll:  mov  ah,1               ; ---- a key? -----------------------------
        int  16h                ;  Not WAIT for one: the picture is drawn
        jz   FLY                ;  whether you press anything or not, which
        mov  ah,0               ;  is what makes a frame rate a thing that
        int  16h                ;  can be measured at all
        cmp  al,27
        je   .out
        cmp  al,'f'
        je   .flip
        cmp  al,'F'
        je   .flip
        or   al,al
        jnz  FLY                ; an ordinary key: not ours
        cmp  ah,72              ; up
        je   .fwd
        cmp  ah,80              ; down
        je   .back
        cmp  ah,75              ; left
        je   .left
        cmp  ah,77              ; right
        je   .right
        cmp  ah,73              ; PgUp
        je   .clmb
        cmp  ah,81              ; PgDn
        je   .dive
        jmp  FLY
.fwd:   call STEPXZ
        mov  ax,[wdx]
        add  [camx],ax
        mov  ax,[wdz]
        add  [camz],ax
        jmp  FLY
.back:  call STEPXZ
        mov  ax,[wdx]
        sub  [camx],ax
        mov  ax,[wdz]
        sub  [camz],ax
        jmp  FLY
.left:  sub  word [heading],STEPT
        and  word [heading],255
        call SETTRIG
        jmp  FLY
.right: add  word [heading],STEPT
        and  word [heading],255
        call SETTRIG
        jmp  FLY
.clmb:  add  word [camy],64
        jmp  FLY
.dive:  cmp  word [camy],128
        jbe  FLY
        sub  word [camy],64
        jmp  FLY
.flip:  xor  byte [fastp],1     ; THE SWITCH. One byte, read by ROTXZ and
        jmp  FLY                ;  LINE in ENGINE\, and the number changes
.out:   ret

; ---- STEPXZ: one pace along the way the camera is facing ------------------
;  The heading's own sine and cosine are already in hsin/hcos, put there by
;  SETTRIG once a turn, so a pace is two multiplies and no table lookup.
STEPXZ: mov  ax,[hsin]
        mov  bx,STEPF
        imul bx
        mov  bx,256
        idiv bx                 ; STEPF*sin/256
        mov  [wdx],ax
        mov  ax,[hcos]
        mov  bx,STEPF
        imul bx
        mov  bx,256
        idiv bx
        mov  [wdz],ax
        ret

; ============================================================================
;  FRAME - clear, draw the lattice, show it.
; ============================================================================
FRAME:  mov  ax,cs              ; the back buffer: the 64K above us...
        add  ax,1000h
        cmp  byte [doside],0
        jne  .buf
        mov  ax,0A000h          ; ...UNLESS the glass is not being clipped,
                                ;  and then we take the back buffer away and
                                ;  draw on the screen itself. Not for effect:
                                ;  E_RAST's LINE walks every pixel of a line
                                ;  whether the pixel is on the screen or not,
                                ;  and with CLAMPAX handing it four thousand
                                ;  a frame is seven million pixels and the
                                ;  best part of a minute. Behind a buffer
                                ;  that is a black screen and a mystery. On
                                ;  the screen it is a thing you can watch.
.buf:   mov  [bufseg],ax
        mov  es,ax
        xor  di,di
        xor  ax,ax
        mov  cx,32000
        rep  stosw
        call SKY
        mov  word [faults],0
        call GRIDC
        call TALLY
        call HUD
        cmp  byte [doside],0
        je   .out               ; drawn straight on: there is nothing to blit
        ; (bench) no WAITVR: the clock must see the render, not the beam
        push ds
        mov  ax,0A000h
        mov  es,ax
        mov  ds,[bufseg]
        xor  si,si
        xor  di,di
        mov  cx,32000
        rep  movsw
        pop  ds
.out:   ret

; ---- TALLY: one red pixel along the top row for every caught divide -------
;  Nothing to read on a good frame, because there is nothing to count. On
;  stage 2 it is a red bar as wide as the trouble.
TALLY:  mov  cx,[faults]
        jcxz  .none
        cmp  cx,320
        jbe  .fit
        mov  cx,320
.fit:   mov  ax,[bufseg]
        mov  es,ax
        xor  di,di
        mov  al,12              ; red, out of the default palette: this is
        rep  stosb              ;  instrumentation, not scenery
.none:  ret

; ---- HUD: the frame rate and which engine drew it, top left ---------------
;  Two digits: one DIV, once a frame, on a number under a hundred. The
;  lesson has nothing against dividing; it has something against dividing
;  a hundred and sixty thousand times a second.
HUD:    mov  ax,[fpsv]
        cmp  ax,99
        jbe  .two
        mov  ax,99
.two:   mov  bl,10
        div  bl                 ; AL = tens, AH = units
        add  ax,'00'            ; ...both made into characters at once
        mov  si,HUDF
        cmp  byte [fastp],0
        jne  .put
        mov  si,HUDC
.put:   mov  [si],al
        mov  [si+1],ah
        mov  ax,4               ; row 4: under the tally bar
        mov  bx,8
        call TXT
        ret

HUDF    db '00 FPS   FAST  (F)',0
HUDC    db '00 FPS   CLASSIC  (F)',0

; ---- TXT: AX = y, BX = x, SI = the string; the PC's own 8x8 font ---------
;  Straight from EXAMPLES\JET.ASM. The glyphs live at F000:FA6E in every
;  PC's ROM - the same ones the BIOS boots with - so a program that wants
;  to write a number needs no font of its own.
TXT:    push es
        push dx
        mov  cx,ax
        mov  ax,[bufseg]
        mov  es,ax
        mov  ax,cx
        mov  cx,320
        mul  cx
        add  ax,bx
        mov  di,ax              ; destination top-left
.ch:    lodsb
        or   al,al
        jz   .done
        push si
        xor  ah,ah
        mov  cl,3
        shl  ax,cl              ; glyph offset = char*8
        mov  si,0FA6Eh
        add  si,ax
        push ds
        mov  ax,0F000h
        mov  ds,ax
        mov  cx,8
        push di
.row:   lodsb                   ; one row of bits, MSB = left pixel
        mov  ah,al
        push cx
        mov  cx,8
.px:    shl  ah,1
        jnc  .np
        mov  al,[cs:tcol]
        mov  [es:di],al
.np:    inc  di
        loop .px
        add  di,320-8
        pop  cx
        loop .row
        pop  di
        pop  ds
        pop  si
        add  di,8               ; the next character cell
        jmp  .ch
.done:  pop  dx
        pop  es
        ret

; ---- the horizon, so there is a sky to tell the ground from ---------------
;  A flat plane at y = 0 meets the eye's axis at `horiz` and nowhere else,
;  whatever the camera does with x and z. One line, one constant, and it is
;  the same hundred PROJPT subtracts from.
SKY:    mov  ax,[bufseg]
        mov  es,ax
        mov  word [sx0],0
        mov  word [sx1],319
        mov  ax,[horiz]
        mov  [sy0],ax
        mov  [sy1],ax
        mov  byte [COLOR],8
        call LINE
        ret

; ============================================================================
;  GRIDC - WIRE CITY's ground lattice, one SQUARE at a time.
;
;  The game drew it as long lines: twelve across and twelve down, each one
;  running the whole width of the grid, because its ground was one colour
;  and a long line is cheaper than the squares it is made of. Ours is not
;  one colour. Every square is painted by the height of the Diamond-Square
;  node at its corner, so every square has to be its own two edges - the
;  one going east and the one going north - and the node at the far corner
;  is another square's business.
;
;  That is the only thing about this routine that is not the game's, and it
;  costs exactly what you would think: the game rotated two endpoints per
;  long line, and we rotate two per SEGMENT, so every node goes through
;  ROTXZ four times instead of once. The game has an answer to that and its
;  name is TERRPREP. It belongs to the next lesson, with the relief that
;  makes it worth having.
;
;  A node is 1024 world units from its neighbour - the heightmap's own
;  pitch, four of the game's building cells - and the map is 64 nodes
;  square, so 64 times 1024 is 65536, which is exactly one word. The torus
;  needs no arithmetic at all here: the subtraction wraps by itself.
; ============================================================================
GRIDC:  mov  ax,[camx]          ; which node the eye is standing over
        add  ax,BIAS
        mov  cl,2
        shr  ax,cl
        mov  cl,8
        shr  ax,cl              ; (camx+BIAS)>>10, the game's own shift
        mov  [camgi],ax
        mov  ax,[camz]
        add  ax,BIAS
        mov  cl,2
        shr  ax,cl
        mov  cl,8
        shr  ax,cl
        mov  [camgj],ax

        mov  ax,[camgj]
        sub  ax,NR
        mov  [gj],ax
.rz:    mov  ax,[camgi]
        sub  ax,NR
        mov  [gi],ax

.rx:    mov  ax,[gi]            ; ---- what colour is this square? --------
        mov  bx,[gj]
        call BAND

        mov  ax,[gi]            ; ---- the corner it hangs from -----------
        mov  bx,[gj]
        mov  di,x0
        call NODEV
        mov  ax,[camy]
        neg  ax                 ; the plane is at y = 0, so the eye sees it
        mov  [y0],ax            ;  camy below - GRID's own two lines
        mov  [y1],ax

        mov  ax,[gi]            ; ---- the edge going east ----------------
        inc  ax
        mov  bx,[gj]
        mov  di,x1
        call NODEV
        call DRAWEDGE3D

        mov  ax,[gi]            ; ---- ...and the one going north ---------
        mov  bx,[gj]
        mov  di,x0
        call NODEV              ; p0 again: DRAWEDGE3D CUTS, and what it
                                ;  cut was this same corner
        mov  ax,[camy]
        neg  ax
        mov  [y0],ax
        mov  [y1],ax
        mov  ax,[gi]
        mov  bx,[gj]
        inc  bx
        mov  di,x1
        call NODEV
        call DRAWEDGE3D

        inc  word [gi]
        mov  ax,[camgi]
        add  ax,NR
        cmp  ax,[gi]
        jl   .ez
        jmp  .rx
.ez:    inc  word [gj]
        mov  ax,[camgj]
        add  ax,NR
        cmp  ax,[gj]
        jl   .done
        jmp  .rz
.done:  ret

; ---- NODEV: node (AX = gi, BX = gj) into camera space, at [di] and [di+2] -
;  Straight out of GRID: the node's world position, minus where the camera
;  stands, through ROTXZ. The shift is the game's - two then eight, because
;  the 8086 shifts by one or by CL and 1024 is ten places.
NODEV:  push di
        mov  cl,2
        shl  ax,cl
        mov  cl,8
        shl  ax,cl              ; gi*1024
        sub  ax,BIAS
        sub  ax,[camx]
        mov  [wdx],ax
        mov  ax,bx
        mov  cl,2
        shl  ax,cl
        mov  cl,8
        shl  ax,cl
        sub  ax,BIAS
        sub  ax,[camz]
        mov  [wdz],ax
        call ROTXZ
        pop  di
        mov  ax,[rc_x]
        mov  [di],ax
        mov  ax,[rc_z]
        mov  [di+2],ax
        ret

; ---- BAND: COLOR from the height at node (AX = gi, BX = gj) ---------------
;  The boundaries are lesson 0x11's and the engine's - the same numbers
;  GETZONE sorts the world by. The six colours are the island's, so a
;  square here is the colour that square was on the map in stage 1.
BAND:   mov  dx,bx
        mov  bx,ax
        call HGET               ; AL = 0..255, and HGET does the wrapping
        mov  ah,1               ; sea
        cmp  al,88
        jb   .set
        mov  ah,2               ; sand
        cmp  al,120
        jb   .set
        mov  ah,3               ; grass
        cmp  al,168
        jb   .set
        mov  ah,4               ; woods
        cmp  al,200
        jb   .set
        mov  ah,5               ; rock
        cmp  al,230
        jb   .set
        mov  ah,6               ; snow
.set:   mov  [COLOR],ah
        ret

; ============================================================================
;  THE GAME'S OWN CLIPPING, from GAMES\WIRECITY\CITY.ASM line 818.
;
;  Copied, not rewritten. The only thing added is the two flags, and they
;  exist so the stages can take a fence down and let you look.
; ============================================================================
DRAWEDGE3D:
        mov  [savesp],sp        ; WHERE THE TRAP COMES BACK TO - see TRAP0.
                                ;  At this instant the top of the stack is the
                                ;  return address into GRIDC, so a handler that
                                ;  restores SP and does a plain RET lands exactly
                                ;  where a finished edge would have
        cmp  byte [donear],0
        je   .noz
        call NEARCLIP
        jc   .skip
.noz:   call PROJ2
        cmp  byte [doside],0
        je   .no2
        call CLIPLINE
        jc   .skip
.no2:   mov  ax,[bufseg]
        mov  es,ax
        call LINE
.skip:  ret

; ============================================================================
;  TRAP0 - INT 0, and lesson 0x0F is the reason this program can be filmed.
;
;  Take NEARCLIP away and a node behind your eye reaches PROJPT with z at or
;  below nought. `idiv cx` with cx = 0 is a divide fault; `idiv cx` with a
;  quotient too big for AX is ALSO a divide fault, because on the 8086 INT 0
;  is both. DOS's own handler prints a line and takes the program away, and
;  stage 2 is a black screen and nothing to teach with.
;
;  So we take the vector. The handler throws away whatever PROJPT had pushed,
;  puts the stack back to where DRAWEDGE3D started, counts the fault, and
;  RETURNS - into GRIDC, at the instruction after the call, as though that
;  edge had simply been drawn. STI because an INT clears the flag on its way
;  in and nothing else will put it back.
;
;  Every red pixel along the top of stage 2 is one of these. That is not a
;  wrong picture - it is a machine that stopped, caught.
; ============================================================================
TRAP0:  mov  ax,cs
        mov  ds,ax              ; SS is ours already: a .COM is one segment
        mov  sp,[savesp]        ; back to the top of DRAWEDGE3D
        inc  word [faults]
        sti
        ret

; ----- near Z-plane clipping ------------------------------------------------
NEARCLIP:
        mov  ax,[z0]
        cmp  ax,NEARZ
        jge  .p0in
        mov  bx,[z1]
        cmp  bx,NEARZ
        jl   .rej
        call CLIPP0
        clc
        ret
.p0in:  mov  bx,[z1]
        cmp  bx,NEARZ
        jge  .both
        call CLIPP1
        clc
        ret
.both:  clc
        ret
.rej:   stc
        ret

; ----- and the cut itself, which is the lesson ------------------------------
;  t = (NEARZ - z0) / (z1 - z0), spent on x and on y. What makes it fit an
;  8086 with no fractions at all is that IMUL leaves a THIRTY-TWO bit
;  product in DX:AX and IDIV takes a thirty-two bit dividend back:
;
;      (x1-x0) * num / den
;
;  is exact, in two instructions, with nothing rounded in between. No fixed
;  point, no scaling by 256, no shifts. That is the whole reason this
;  routine is twenty instructions and not sixty.
;
;  z is not computed at the end. It is ASSIGNED: the point now sits exactly
;  on the plane, and an answer that missed it by one would leave the vertex
;  outside and the test would throw the edge away.
CLIPP0: mov  bx,[z1]
        sub  bx,[z0]
        mov  ax,NEARZ
        sub  ax,[z0]
        mov  [tnum],ax
        mov  [tden],bx
        mov  ax,[x1]
        sub  ax,[x0]
        imul word [tnum]
        idiv word [tden]
        add  ax,[x0]
        mov  [x0],ax
        mov  ax,[y1]
        sub  ax,[y0]
        imul word [tnum]
        idiv word [tden]
        add  ax,[y0]
        mov  [y0],ax
        mov  word [z0],NEARZ
        ret

CLIPP1: mov  bx,[z0]
        sub  bx,[z1]
        mov  ax,NEARZ
        sub  ax,[z1]
        mov  [tnum],ax
        mov  [tden],bx
        mov  ax,[x0]
        sub  ax,[x1]
        imul word [tnum]
        idiv word [tden]
        add  ax,[x1]
        mov  [x1],ax
        mov  ax,[y0]
        sub  ax,[y1]
        imul word [tnum]
        idiv word [tden]
        add  ax,[y1]
        mov  [y1],ax
        mov  word [z1],NEARZ
        ret

; ----- project both points --------------------------------------------------
PROJ2:  mov  ax,[x0]
        mov  dx,[y0]
        mov  cx,[z0]
        call PROJPT
        mov  [sx0],ax
        mov  [sy0],dx
        mov  ax,[x1]
        mov  dx,[y1]
        mov  cx,[z1]
        call PROJPT
        mov  [sx1],ax
        mov  [sy1],dx
        ret

; ============================================================================
;  Stage 1: the island from above, and where you are about to stand.
;  Lesson 0x11's picture, redrawn from the same map the flight reads.
; ============================================================================
MAPVIEW:
        mov  ax,[bufseg]
        mov  es,ax
        xor  di,di
        xor  ax,ax
        mov  cx,32000
        rep  stosw
        mov  word [gj],63       ; the TOP of the picture is the HIGHEST z:
.row:   mov  word [gi],0        ;  north up, like every map ever printed
.col:   mov  ax,[gi]
        mov  bx,[gj]
        call BAND
        mov  ax,[gj]
        mov  bx,63
        sub  bx,ax
        mov  ax,bx
        mov  bx,320*CELLW
        mul  bx
        add  ax,ORGY*320
        mov  di,ax
        mov  ax,[gi]
        mov  bx,CELLW
        mul  bx
        add  di,ax
        add  di,ORGX
        mov  al,[COLOR]
        mov  cx,CELLW
.r3:    mov  [es:di],al         ; a 3x3 block a node, the way lesson 0x11
        mov  [es:di+1],al       ;  painted it
        mov  [es:di+2],al
        add  di,320
        loop .r3
        inc  word [gi]
        cmp  word [gi],64
        jb   .col
        dec  word [gj]
        jns  .row

        mov  ax,[camx]          ; and the mark: where you stand, and the
        add  ax,BIAS            ;  way you will be looking
        mov  cl,2
        shr  ax,cl
        mov  cl,8
        shr  ax,cl
        and  ax,63
        mov  bx,CELLW
        mul  bx
        add  ax,ORGX
        mov  [sx0],ax
        mov  [sx1],ax
        mov  ax,[camz]
        add  ax,BIAS
        mov  cl,2
        shr  ax,cl
        mov  cl,8
        shr  ax,cl
        and  ax,63
        mov  bx,63
        sub  bx,ax
        mov  ax,bx
        mov  bx,CELLW
        mul  bx
        add  ax,ORGY
        mov  [sy0],ax
        sub  ax,8*CELLW
        mov  [sy1],ax
        mov  byte [COLOR],15
        call LINE
        ret

; ---- SHOW: the back buffer onto the screen --------------------------------
SHOW:   call WAITVR
        push ds
        mov  ax,0A000h
        mov  es,ax
        mov  ds,[bufseg]
        xor  si,si
        xor  di,di
        mov  cx,32000
        rep  movsw
        pop  ds
        ret

; ---- WAITVR: wait for the beam to fly home --------------------------------
;  Port 3DAh, bit 3: the VERTICAL RETRACE. Wait OUT any retrace already
;  running, then wait for the next one to begin - a whole frame, every time.
WAITVR: push ax
        push dx
        mov  dx,3DAh
.o:     in   al,dx
        test al,8
        jnz  .o
.i:     in   al,dx
        test al,8
        jz   .i
        pop  dx
        pop  ax
        ret

; ---- SETPAL: the island's six colours, written into the VGA DAC -----------
;  Port 3C8h takes the colour NUMBER to start at, then 3C9h takes red,
;  green and blue - 0..63 each, and the index steps on by itself after
;  every third write. Lesson 0x11's ramp, unchanged, so a square in the
;  air is the colour it was on the map.
SETPAL: mov  dx,3C8h
        mov  al,1
        out  dx,al
        inc  dx
        mov  si,PAL
        mov  cx,6*3
.p:     lodsb
        out  dx,al
        loop .p
        ret

PAL     db  4,10,28             ; 1 sea
        db 46,42,26             ; 2 sand
        db 16,38,10             ; 3 grass
        db 10,26, 8             ; 4 woods
        db 26,24,22             ; 5 rock
        db 46,48,50             ; 6 snow

; ============================================================================
;  State: the lesson's own, then the contract the engine modules expect.
; ============================================================================
camx    dw 0                    ; where the eye stands, in world units
camy    dw CAMY0                ; how high over the plane
camz    dw 0
camgi   dw 0                    ; ...and which node that is
camgj   dw 0
gi      dw 0                    ; the lattice's own counters
gj      dw 0

x0      dw 0                    ; the edge, and the names are the game's.
z0      dw 0                    ;  x0/z0 and x1/z1 sit in pairs so that
x1      dw 0                    ;  NODEV can fill either one through a
z1      dw 0                    ;  single pointer
y0      dw 0
y1      dw 0

savesp  dw 0                    ; where TRAP0 puts the stack back to
faults  dw 0                    ; ...and how many times it had to, this frame
oldi0   dw 0,0                  ; the INT 0 vector we borrowed

fastp   db 1                    ; WHICH ENGINE: 1 = the lessons' way (no
                                ;  divide in ROTXZ, lesson 8's Line), 0 =
                                ;  the classic the game shipped with. F
                                ;  flips it in flight; ENGINE\E_M3D.INC
                                ;  and E_RAST.INC read it and nothing else
fpsn    dw 0                    ; frames counted this second...
fpst    dw 0                    ; ...since this BIOS tick...
fpsv    dw 0                    ; ...and the number the HUD shows
tcol    db 15                   ; TXT's colour

donear  db 0                    ; THE TWO FENCES, as two bytes. This is the
doside  db 0                    ;  only thing in this file the game has not
                                ;  got, and it is here so a stage can take
                                ;  one down and let you look

; ---- engine contract: E_MATH + E_TERR ------------------------------------
rseed   dw 1                    ; LCG state
dss     dw 0                    ; DS: current side length
dsh     dw 0                    ; DS: half side
dsx     dw 0                    ; DS: loop x / scratch
dsy     dw 0                    ; DS: loop y / scratch
dsamp   dw 0                    ; DS: noise amplitude (power of two)
dsac    dw 0                    ; DS: accumulator / scratch

; ---- engine contract: E_M3D + E_RAST -------------------------------------
bufseg  dw 0
heading dw 0                    ; the camera: turned by the arrows...
pitch   dw 0                    ; ...level...
roll    dw 0                    ; ...and not banked
hsin    dw 0
hcos    dw 256
rsin    dw 0
rcos    dw 256
psin    dw 0
pcos    dw 256
pofs    dw 0
horiz   dw 100                  ; where the eye's axis meets the glass
swayx   dw 0
swayy   dw 0
wdx     dw 0                    ; ROTXZ in...
wdz     dw 0
rc_x    dw 0                    ; ...and out
rc_z    dw 0
ptmp    dw 0                    ; projection scratch
rddx    dw 0
rddy    dw 0
rsxo    dw 0
tnum    dw 0                    ; clip interpolation scratch
tden    dw 0
cdx     dw 0                    ; line clip deltas / new point
cdy     dw 0
nx      dw 0
ny      dw 0
IX      dw 4 dup(0)             ; the polygon path's face buffers. This
IY      dw 4 dup(0)             ;  lesson draws no faces - the relief in
IZ      dw 4 dup(0)             ;  the next one does - but E_RAST.INC is
OX      dw 6 dup(0)             ;  one file and it is assembled whole, so
OY      dw 6 dup(0)             ;  the names it uses have to exist
OZ      dw 6 dup(0)
PX      dw 6 dup(0)
PY      dw 6 dup(0)
NPOLY   dw 0
oc      dw 0
ci      dw 0
ni      dw 0
pk      dw 0
pminy   dw 0
pmaxy   dw 0
scy     dw 0                    ; scanline filler state
scymax  dw 0
scxl    dw 0
scxr    dw 0
oc0     db 0                    ; Cohen-Sutherland outcodes
oc1     db 0
ocsel   db 0
lx      dw 0                    ; Bresenham state (LINE)
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

; quarter sine table: SINT[i] = round(256*sin(i*90/64 deg)), i=0..64
SINT    dw 0,6,13,19,25,31,38,44,50,56,62,68,74,80,86,92,98,104,109,115
        dw 121,126,132,137,142,147,153,157,162,167,172,177,181,185,190,194
        dw 198,202,206,209,213,216,220,223,226,229,231,234,237,239,241,243
        dw 245,247,248,250,251,252,253,254,255,255,256,256,256

        include '..\..\ENGINE\E_MATH.INC'
        include '..\..\ENGINE\E_TERR.INC'
        include '..\..\ENGINE\E_M3D.INC'
        include '..\..\ENGINE\E_RAST.INC'

HMAP    db 4096 dup(0)          ; the 64x64 heightmap DSGEN fills
