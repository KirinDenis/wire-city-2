; ============================================================================
;  FILL.ASM - Lesson 16. THE GROUND BECOMES A SURFACE.
;
;      FASM FILL.ASM FILL.COM
;
;      1  the island from above - lesson 0x11's map, and the mark where
;         you are about to be standing. SPACE takes off
;      2  the flight, and it does not wait for you
;
;      LEFT / RIGHT  turn, and the world banks into it
;      DOWN          nose up. UP puts it down - it is a control column
;      F             FAST or CLASSIC arithmetic
;      SPACE         after a crash: another aeroplane
;      ESC           land
;
;  TWO THINGS CHANGE, and they are the same thing said twice.
;
;  ONE: THE GROUND IS FILLED. Every square of the lattice is a polygon
;  now, painted in the colour of its tallest corner, and the squares are
;  drawn FAR TO NEAR so that each one covers whatever was behind it. That
;  is the painter's algorithm, and it is not really an algorithm - it is
;  an order. Nothing is tested and nothing is remembered.
;
;  Lesson 15 hid the far hills with an array of 320 bytes and a compare
;  for every pixel. All of that is gone from this file. So are the line
;  routines it was built on: DRAWEDGE3D, NEARCLIP, CLIPP0, CLIPP1 and
;  PROJ2, which lesson 13 wrote and which nothing calls any more. Their
;  four jobs are all still done - they are done inside FACEFILL, for a
;  FACE instead of for an edge, by the engine the games are built from.
;
;  TWO: THE GROUND HITS BACK. Lesson 15 carried you up to the surface if
;  you flew into it, which is what a FLOOR does. A filled hillside is not
;  a floor, and flying into it ends the flight: the model stops, the
;  camera steps back and looks at what you hit, and SPACE puts another
;  aeroplane in the air. That is CRASHHANDLE out of the game, with the
;  cinema left out - see the banner over CRASH for what the game does on
;  top of these two lines.
;
;  WHAT IT COSTS, measured the same way lesson 15's numbers were (retrace
;  wait off, fixed island, the aeroplane parked so the picture holds
;  still):
;
;      lesson 15, wireframe, see through        76 frames a second
;      lesson 15, wireframe, hidden lines       60
;      this file, filled, at lesson 15's reach  76
;      this file, filled, at TWICE that reach   27
;
;  THE LAST TWO LINES ARE THE SAME PROGRAM with one constant changed, and
;  the constant is NR. The full table and what it means is up beside it;
;  the short version is that the bill is the NUMBER OF SQUARES and almost
;  nothing else, so twice the distance is about four times the price.
;
;  AND LOOK AT THE FIRST LINE AND THE THIRD TOGETHER. At lesson 15's reach
;  a FILLED world, with every seam drawn, now runs exactly as fast as
;  lesson 15's bare wireframe did. That is not because filling is cheap.
;  It is the circle, the cull, each edge drawn once, and three bytes of
;  the engine taken out - see the table beside NR for what each one bought.
;
;  READ THE REST HONESTLY TOO, because it is not the advertisement lesson
;  15 wrote. Hiding did not get cheaper - it got FREE, and the paint that
;  gives it away costs more than the hiding ever did. What you buy for
;  those frames is not a faster picture. It is a WORLD: a surface that
;  stops light, stops the far hills, and now stops the aeroplane. You
;  cannot crash into a wireframe.
;
;  THE SOURCE TRAVELS. This file started as a copy of LESSONS\L21\RELIEF.ASM
;  and it is still mostly lesson 13's program underneath. The island, the
;  trigonometry, the rotate, the projection, the rasterizer and the line
;  clipper all come out of ENGINE\ - the same five files the games are
;  built from.
;
;  THE PHYSICAL FACT THIS LESSON HANDS OVER:
;
;      AN AEROPLANE DOES NOT WAIT FOR YOU. Up to here, every lesson moved
;      the camera one pace per keypress and drew a picture between them.
;      That is a slide show with arrows. A flight model is the other way
;      round: the world advances on its own, every frame, and the keys
;      only lean on it. Nothing in this file asks "has a key been
;      pressed". It asks "is a key being HELD", which is a different
;      question and needs a different piece of machinery.
;
;  THE FOUR RULES, and all four are copied out of INPUT in
;  GAMES\WIRECITY\CITY.ASM (line 1873). There is no fifth:
;
;      1. IT ALWAYS MOVES FORWARD.  camx += SPEEDV*hsin/256
;                                   camz += SPEEDV*hcos/256
;         Every frame, whatever you do. There is no throttle and no brake
;         in this game, and taking them out is what makes the rest simple.
;
;      2. LEFT AND RIGHT TURN IT.   heading = (heading -+ TURNV) & 255
;         A byte is a whole circle, so the turn cannot overflow and needs
;         no range check - lesson 0x0B's table, still paying.
;
;      3. THE TURN BANKS IT.        roll walks toward -+BANKMAX by BANKSTP
;                                   while you turn, and back to 0 when you
;                                   let go.
;         This is the whole of the "feel". It is four compares and two
;         adds, it models nothing - no lift, no mass, no aerodynamics -
;         and it is completely convincing.
;
;      4. THE ARROWS CLIMB, THE OTHER WAY ROUND. DOWN puts the nose up,
;         because the thing in your hand is a stick and you pull it back.
;         And the floor is not a number any more: it is the ground.
;
;  AND THE BANK COSTS NOTHING, which is the part worth stopping on. The
;  engine has been banking the picture since lesson 13 and you have never
;  seen it, because `roll` was zero. PROJPT calls APPLYROLL on every
;  projected point already; SETTRIG has been filling rsin/rcos from `roll`
;  every time it ran. Put a number in `roll` and the whole world tilts.
;  The physics did not add a rotation - it switched one on.
;
;  THE KEYBOARD, and this is the second new piece. INT 16h hands you keys
;  one at a time, out of a buffer, AFTER the operating system has decided
;  what they mean - so it can tell you a key was pressed and cannot tell
;  you it is still down, and it cannot tell you that two are down at once.
;  A flight model needs both. So the program takes INT 9 - the interrupt
;  the keyboard hardware itself raises - reads the scan code off port 60h,
;  and keeps its own table of 128 bytes: 1 while a key is held, 0 when it
;  is let go. KBINT below is copied out of CITY.ASM and is twenty
;  instructions.
;
;  That means the BIOS never sees a key while this program runs, so
;  nothing in here can use INT 16h any more - including the "press
;  anything" wait on the map. And it means the vector has to be given back
;  on the way out, exactly like INT 0. Two borrowed vectors now.
;
;  AND ONE WINDOW IS LEFT IN THAT DOOR, which is REMOTE below. Closing the
;  BIOS off closes it to EVERYBODY, and that includes anything driving the
;  program from outside: a macro, a test script, or the resident that types
;  these lessons while they are being recorded. All of those put their keys
;  in the BIOS buffer, because that is where a keystroke normally lands,
;  and nothing in here would ever read them. So once a frame the program
;  looks, and a code it finds is held in the table for RHOLD frames as
;  though a finger had been on it. With nobody driving, nothing arrives.
;
;  WHAT THE NUMBERS ARE. The game's constants, scaled by four, because its
;  world is built on a 256-unit cell and this lattice on a 1024-unit node:
;
;      game            here          what it is
;      SPEEDV 12       48            forward units per frame
;      STEPY  5        20            climb units per frame
;      camy 24..420    96..1680      the floor and the ceiling
;      TURNV  2        2             angles do not scale
;      BANKMAX 30      30
;      BANKSTP 3       3
;
;  STILL NO HOUSES. The lattice is flat and coloured by the Diamond-Square
;  map, exactly as lesson 13 left it. Houses are the lesson after this
;  one, and the relief the one after that.
;
;  WHAT IS STILL BORROWED FROM THE GAME AND THE ENGINE:
;
;      ENGINE\E_8086.INC   keeps FASM inside the 8086 instruction set
;      ENGINE\E_MATH.INC   RND16, the congruential draw of lesson 0x11
;      ENGINE\E_TERR.INC   DSGEN and HGET - lesson 0x11's island, entire
;      ENGINE\E_M3D.INC    SINQ, SETTRIG, ROTXZ, PROJPT, APPLYROLL, CLAMPAX
;      ENGINE\E_RAST.INC   OUTCODE, CLIPLINE, LINE
;
;  and DRAWEDGE3D, NEARCLIP, CLIPP0, CLIPP1, KBINT and the flight model
;  are copied out of GAMES\WIRECITY\CITY.ASM. Open it and read along.
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
; ---- HOW FAR YOU CAN SEE, and it is a measured number ---------------------
;  Lesson 15 stopped at twelve nodes because a wireframe at thirteen
;  missed the retrace and halved. A filled world is a different account
;  altogether, and this is it, measured with the retrace wait off, a fixed
;  island and the aeroplane parked so the picture holds still:
;
;      NR      squares    plain    with the side cull
;      12        625        38            54
;      16       1089        23            36
;      20       1681        17            25
;      24       2401        12            19
;
;  And then, at twenty four nodes, one change at a time, each measured on
;  the same parked picture of the same island:
;
;      the square, as above                          19
;      the CIRCLE - a quarter fewer squares          22
;      + the outcode cull, an AND of four bytes      23
;      + each edge drawn once, by its owner          26
;      + the pitch taken out of the engine           27
;
;  THE THIRD LINE IS THE HONEST ONE. The outcode cull is five times
;  cheaper per square than the test it replaced, and it bought ONE frame.
;  The old test was already throwing away the same squares; all the new
;  one saves is the cost of throwing them away, and that was never where
;  the time went. The time is in the squares that are DRAWN - and the two
;  lines under it are both about those: half the lines, and no pitch.
;  Measure before you believe the instruction count.
;
;  READ THE FIRST TWO COLUMNS TOGETHER. Multiply them: 38 x 625 is about
;  twenty four thousand, and so is 12 x 2401. THE COST IS THE NUMBER OF
;  SQUARES, almost exactly, and it does not care how big they are on the
;  screen. That is the opposite of what you would guess about a filler,
;  and it is worth knowing why: a far square is a handful of pixels, but
;  it still gets four corners lifted out of the cache, a near-plane clip,
;  four perspective divides and a polygon walk. The fixed cost per square
;  swamps its paint.
;
;  Which is why the FOURTH COLUMN is where the distance came from. Doubling
;  the reach is FOUR times the squares, and the naive version pays all of
;  it. The side cull throws away the ones that are in front of you but
;  past the edge of the screen, and that is most of the corners of the
;  block: it buys a third of the frame rate back at twelve nodes and more
;  than half at twenty four. See the cull itself in DRAWQUAD.
NR      = 24                  ; TWENTY FOUR NODES, twice lesson 15's reach...
NSIDE   = 2*NR+1              ; ...so it is forty nine SQUARES across...
TSIDE   = 2*NR+2              ; ...and fifty NODES, because every
                              ;  square draws the edge to its neighbour and
                              ;  the last one still needs a neighbour to
                              ;  draw to. One more row, one more column.
; ---- WHERE THE AEROPLANE APPEARS, and it is NOT a constant ---------------
;  Lesson 15 wrote CAMY0 = 500 and that was fine, because flying into a
;  hill only carried you up over it. The moment the ground can kill you,
;  a fixed starting height is a bug with a fuse on it: the island is made
;  fresh every run and the spot you appear on is whatever that run put
;  there. Land on a peak and you are dead before the first frame.
;
;  Work out what 500 means and you see how small the margin was. Ordinary
;  grass at map byte 130 is (130-88)*5, doubled by VEXAG, which is 420 -
;  and the clearance is 96. At 500 you are a few seconds from a field.
;
;  So the program ASKS. TOPOFMAP reads all four thousand and ninety six
;  bytes of the island once, at the boot, finds the tallest, and puts it
;  through the same WORLDH the ground is drawn with. Everything below is
;  measured from that, so it is right for an island nobody has seen yet.
;
;  A CONSTANT THAT HAS TO BE RIGHT FOR EVERY MAP CANNOT BE A CONSTANT.
SPAWNUP = 700                 ; how far ABOVE the highest point of the whole
                              ;  island the aeroplane appears. Not above the
                              ;  ground under it - above the WORST ground
                              ;  there is, so no run can start inside a
                              ;  mountain however the dice fell
CEILUP  = 2400                ; ...and how far above it the ceiling sits, so
                              ;  there is somewhere to climb to

; ---- the flight model. Every one of these is CITY.ASM's, and the three
;      that measure a DISTANCE are multiplied by four, because the game's
;      world is built on a 256-unit cell and this lattice on a 1024-unit
;      node. The three that measure an ANGLE are not touched: a circle is
;      256 steps here and 256 steps there.
SPEEDV  = 48                  ; forward units a frame. There is no throttle
STEPY   = 20                  ; climb/dive units a frame
CAMYCL  = 96                  ; HOW CLOSE TO THE GROUND you may get. Not a
                              ;  height any more - a clearance, measured
                              ;  from whatever happens to be underneath

; ---- THE ONE NUMBER IN THIS FILE THAT IS NOT THE GAME'S --------------------
;  VEXAG - vertical exaggeration, as a shift count. 1 doubles every height.
;
;  WORLDH gives five units of height for one step of the map, and the nodes
;  stand a thousand and twenty four apart. So the real landscape is gentle:
;  a hundred and sixty units of climb across a thousand of ground, which is
;  a slope of about nine degrees. The game gets away with that because it
;  FILLS its quads, and a filled slope reads even when it is shallow. A
;  wireframe does not - the lines simply look straight.
;
;  So the heights are doubled here, once, where TERRPREP writes them. It is
;  a decision about the PICTURE and not about the world, every map that ever
;  showed a mountain has made it, and it is written down here in one place
;  with its reason - because a map that quietly lies about its own scale is
;  a map that lies.
BACKOFF = 400                 ; how far the camera steps back on a crash.
                              ;  The game's is 100 on a 256-unit cell; ours
                              ;  is a 1024-unit node, so four times it
VEXAG   = 1                   ; 1 = doubled. 0 would be the game's own
TURNV   = 2                   ; heading change a frame, of 256 = a whole turn
BANKMAX = 30                  ; how far it leans into a turn, of 256
BANKSTP = 3                   ; and how fast it gets there - and back

; ---- scan codes. Not ASCII: these are what the keyboard hardware itself
;      sends, and what KBINT stores. A released key arrives as the same
;      number with bit 7 set.
SC_ESC  = 01h
SC_SP   = 39h
SC_F    = 21h
SC_UP   = 48h                 ; THE UP AND DOWN ARROWS. Not PgUp and PgDn,
SC_DN   = 50h                 ;  which are 49h and 51h - an easy hour to lose
SC_LF   = 4Bh
SC_RT   = 4Dh

RHOLD   = 20                  ; how many frames a key fed from outside is
                              ;  held - about a third of a second, and the
                              ;  bank needs ten frames in a row to build,
                              ;  so one frame would show nothing at all

CELLW   = 3                   ; the map view: 3x3 pixels a node
ORGX    = 64
ORGY    = 4

;  In C, the boot is:
;
;      int main(void)
;      {
;          bufseg  = cs + 0x1000;                 /* the 64K above us        */
;          rseed   = bios_tick() | 1;             /* never zero              */
;          dsgen();                               /* the island              */
;          oldi0   = int_vector[0];               /* keep DOS's INT 0 ...    */
;          int_vector[0] = trap0;                 /* ... and take it         */
;          set_mode(0x13);  setpal();  settrig();
;          camx = 32*1024;  camz = 26*1024;  camy = camy0;  heading = 0;
;          ...the five stages...
;      }
START:  cld                     ; string ops count UP (STOSW, MOVSW, LODSB)
        mov  ax,cs              ; AX = cs
        add  ax,1000h           ; AX = cs + 1000h  - 64K above us, in
        mov  [bufseg],ax        ; bufseg = AX        paragraphs of 16 bytes

        push es                 ; keep ES
        mov  ax,40h             ; AX = 0040h, the BIOS data segment
        mov  es,ax              ; ES = 0040h
        mov  ax,[es:6Ch]        ; AX = the tick count at 0040:006C - the only
        pop  es                 ;  thing on this machine that differs between
        or   ax,1               ; AX |= 1     two runs. Never zero: a seed of
        mov  [rseed],ax         ; rseed = AX  nought would breed noughts
        call DSGEN              ; dsgen()     - the island, in one call
        call ORDPREP            ; ordprep()   - the drawing order, once
        ; ---- TAKE THE PITCH OUT OF THE ENGINE, three bytes, once ---------
        ; Lesson 8's line routine writes its step sizes into its own
        ; instructions before the loop runs. This is the same idea used the
        ; other way round: not to put a number INTO an instruction, but to
        ; take an instruction OUT.
        ;
        ; Every polygon the engine fills goes through CLIPNEAR, and the
        ; first thing CLIPNEAR does is `call PITCH4`: rotate all four
        ; corners about the camera's X axis by the pitch. Four corners,
        ; four IMULs and four IDIVs each - and this aeroplane has no pitch.
        ; psin is nought and pcos is 256, so PITCH4 multiplies every number
        ; by 256 and divides it by 256 again, sixteen hundred times a frame,
        ; and changes nothing.
        ;
        ; The game NEEDS that call - it loops and dives - so the source is
        ; not touched. This program simply knows, at the boot, that it never
        ; pitches, and overwrites the three bytes of the CALL in its own
        ; copy with three NOPs. After that, CLIPNEAR starts one instruction
        ; later and never knows.
        ;
        ; LOOK BEFORE YOU WRITE. The first byte is checked to be E8, a near
        ; CALL, before anything is overwritten. If the engine ever changes
        ; and CLIPNEAR starts with something else, the program leaves it
        ; alone and runs slower instead of running garbage.
        ;
        ; And the rule from lesson 8 holds: patch, then JUMP, because the
        ; prefetch queue may already hold the old bytes. This patch is made
        ; long before CLIPNEAR first runs, with hundreds of jumps between.
        cmp  byte [CLIPNEAR],0E8h   ; is it the CALL we think it is?
        jne  .nopatch               ;   no: leave the engine as it is
        mov  word [CLIPNEAR],9090h  ; NOP NOP  \  the CALL, gone
        mov  byte [CLIPNEAR+2],90h  ; NOP      /
.nopatch:
        call TOPOFMAP           ; topofmap()  - and how high this island is,
                                ;  which decides where the aeroplane appears.
                                ;  AFTER dsgen, obviously: there is nothing
                                ;  to measure until the island exists

        xor  ax,ax              ; AX = 0                ---- take INT 0 ----
        mov  es,ax              ; ES = 0: the vector table is at 0000:0000
        mov  ax,[es:0]          ; AX = low word of vector 0  (offset)
        mov  [oldi0],ax         ; oldi0.offset = AX
        mov  ax,[es:2]          ; AX = high word of vector 0 (segment)
        mov  [oldi0+2],ax       ; oldi0.segment = AX
        cli                     ; interrupts off: two words, and an interrupt
        mov  word [es:0],TRAP0  ; vector[0].offset  = TRAP0    between them
        mov  [es:2],cs          ; vector[0].segment = cs       would find
        sti                     ; interrupts on               half a vector

        xor  ax,ax              ; AX = 0                ---- and take INT 9
        mov  es,ax              ; ES = 0: the vector table again
        mov  ax,[es:9*4]        ; AX = low word of vector 9  (offset)
        mov  [oldi9],ax         ; oldi9.offset = AX
        mov  ax,[es:9*4+2]      ; AX = high word of vector 9 (segment)
        mov  [oldi9+2],ax       ; oldi9.segment = AX
        cli                     ; interrupts off - and this one matters more
        mov  word [es:9*4],KBINT    ; vector[9].offset  = KBINT   than INT 0:
        mov  [es:9*4+2],cs          ; vector[9].segment = cs      a keystroke
        sti                     ; interrupts on              lands here now

        mov  ax,0013h           ; AX = 13h: VGA 320x200, 256 colours
        int  10h                ; set_mode(0x13)
        call SETPAL             ; setpal()   - the island's six colours
        call SETTRIG            ; settrig()  - hsin/hcos for heading 0

        call AIRBORNE               ; airborne(): the camera, the bank and
                                    ;  the crash flag, all in one place

; ---- 1. the island from above, and SPACE to take off ---------------------
;      The wait is on OUR key table, not the BIOS: from the moment INT 9 is
;      taken, INT 16h never hears anything again.
        call MAPVIEW            ; mapview()   - the island from above
        call SHOW               ; show()      - onto the screen
.wsp:   call REMOTE                 ; anything fed from outside?
        cmp  byte [KEYS+SC_SP],0    ; is SPACE held?
        je   .wsp                   ;   no: wait for it
        mov  byte [KEYS+SC_SP],0    ; taken. Cleared by hand, or the flight
        mov  byte [rkey],0          ;  would see the same press again - and
        mov  byte [rhold],0         ;  SPACE does nothing once you are up

; ---- 2. the flight. Both fences up, and they stay up ---------------------
        call FLY                ; fly()  until escape

;  In C:  int_vector[9] = oldi9;  int_vector[0] = oldi0;  set_mode(3);  exit(0);
QUIT:   xor  ax,ax              ; AX = 0          ---- GIVE INT 9 BACK first:
        mov  es,ax              ; ES = 0          until this runs, every key
        cli                     ; interrupts off  on the machine is still
        mov  ax,[oldi9]         ; AX = oldi9.offset      coming to a routine
        mov  [es:9*4],ax        ; vector[9].offset = AX  that is about to
        mov  ax,[oldi9+2]       ; AX = oldi9.segment     stop existing
        mov  [es:9*4+2],ax      ; vector[9].segment = AX
        sti                     ; interrupts on

        xor  ax,ax              ; AX = 0          GIVE INT 0 BACK. A .COM
        mov  es,ax              ; ES = 0          that keeps a vector pointing
        cli                     ; interrupts off  into memory DOS is about to
        mov  ax,[oldi0]         ; AX = oldi0.offset      hand to the next
        mov  [es:0],ax          ; vector[0].offset = AX  program has not
        mov  ax,[oldi0+2]       ; AX = oldi0.segment     finished: the next
        mov  [es:2],ax          ; vector[0].segment = AX divide fault would
        sti                     ; interrupts on          jump into whatever
                                ;                        loads here next
        mov  ax,0003h           ; AX = 3: text mode back, the state we
        int  10h                ;  borrowed the machine in
        mov  ax,4C00h           ; AH = 4Ch exit, AL = 0 the code
        int  21h                ; exit(0)

; ============================================================================
;  FLY - the flight loop. It draws a frame, moves the aeroplane, and goes
;  round again. It never waits for anything.
;
;  Lesson 13's version of this routine asked the BIOS for a key and drew a
;  picture between presses. Everything below the frame counter is new, and
;  all of it is CITY.ASM's GAMELOOP: settrig, draw, then INPUT.
;
;  SETTRIG AT THE TOP, once, because both the heading and the roll change
;  every frame now and every projected point wants their sines. Which also
;  means the step PHYS takes is computed from the trig of the frame BEFORE
;  its turn - one frame stale, exactly as the game does it, and at two
;  parts in two hundred and fifty six of a turn nobody has ever seen it.
; ============================================================================
;  In C:
;
;      void fly(void)
;      {
;          for (;;) {
;              settrig();                               /* heading AND roll */
;              frame();
;              fpsn++;                                  /* frames this second */
;              int tick = bios_tick();                  /* 0040:006C          */
;              if (tick - fpst >= 18) {                 /* ~one second        */
;                  fpst = tick;  fpsv = fpsn;  fpsn = 0;
;              }
;              phys();                                  /* the four rules     */
;              if (KEYS[SC_F] && !fwas) { fastp ^= 1; }  /* on the way down   */
;              fwas = KEYS[SC_F];
;              if (KEYS[SC_ESC]) return;
;          }
;      }
FLY:    call SETTRIG            ; settrig(): hsin/hcos from heading, and
                                ;  rsin/rcos from roll - the bank, which
                                ;  APPLYROLL has been waiting for
        call FRAME              ; frame()
        inc  word [fpsn]        ; fpsn++      ---- the frame counter ------
        push es                 ; (ES is the buffer; borrow it for a moment)
        mov  ax,40h             ; AX = 0040h, the BIOS data segment
        mov  es,ax              ; ES = 0040h
        mov  ax,[es:6Ch]        ; AX = tick, the timer count at 0040:006C
        pop  es                 ; ES = the buffer again
        mov  bx,ax              ; BX = tick   (kept: fpst may take it)
        sub  ax,[fpst]          ; AX = tick - fpst
        cmp  ax,18              ; a second gone by? (18.2 ticks a second)
        jb   .move              ;   no: on with the flight
        mov  [fpst],bx          ; fpst = tick    - a new second starts
        mov  ax,[fpsn]          ; AX = fpsn
        mov  [fpsv],ax          ; fpsv = fpsn    - the number the HUD shows
        mov  word [fpsn],0      ; fpsn = 0

.move:  call REMOTE             ; remote(): anything fed from outside

        ; ---- A WRECK DOES NOT FLY -----------------------------------------
        ; One byte, read once. The frame above was drawn exactly as it
        ; always is, and the frame below will be too; the only thing that
        ; stops is the model. That is what makes a crash cheap.
        cmp  byte [dying],0     ; are we a wreck?
        je   .live              ;   no: fly it
        inc  word [dytick]      ; dytick++ - the message blinks on this
        cmp  byte [KEYS+SC_SP],0    ; is SPACE held?
        je   .esc                   ;   no: go on lying in the hill
        mov  byte [KEYS+SC_SP],0    ; taken - cleared by hand, or the new
        mov  byte [rkey],0          ;  aeroplane would see the same press
        mov  byte [rhold],0         ;  again on its first frame
        call AIRBORNE           ; airborne(): a new one, in the air
        jmp  .esc               ; on to the escape test
.live:  call PHYS               ; phys(): the four rules, once a frame

        ; ---- F flips the engine, ON THE WAY DOWN --------------------------
        ; A held key is 1 for as long as it is held, so the flip has to
        ; happen on the change and not on the state, or one press would
        ; flip it sixty times and land wherever it liked.
        cmp  byte [KEYS+SC_F],0 ; is F held?
        je   .fup               ;   no: remember that
        cmp  byte [fwas],0      ; was it held last frame too?
        jne  .esc               ;   yes: nothing to do, it is one press
        xor  byte [fastp],1     ; fastp ^= 1   THE SWITCH. One byte, read by
        mov  byte [fwas],1      ; fwas = 1      ROTXZ and LINE in ENGINE\
        jmp  .esc               ; on to the escape test
.fup:   mov  byte [fwas],0      ; fwas = 0: F is up, the next press counts

.esc:   cmp  byte [KEYS+SC_ESC],0   ; is ESC held?
        je   FLY                    ;   no: another frame
        ret                         ;   yes: land

; ============================================================================
;  PHYS - the flight model. Four rules, out of INPUT in CITY.ASM line 1873.
;
;  It is called once a frame and it is the only thing in the program that
;  moves the camera. Notice what is NOT in it: no speed variable, no
;  acceleration, no mass, no lift, no drag. The aeroplane is a point that
;  travels at a fixed rate along the way it is pointing, and the bank is a
;  number that chases another number. That is the entire model, and in the
;  air it is convincing.
; ============================================================================
;  In C:
;
;      void phys(void)
;      {
;          int turn = 0;
;          if (KEYS[SC_LF]) { heading = (heading - TURNV) & 255;  turn = -1; }
;          if (KEYS[SC_RT]) { heading = (heading + TURNV) & 255;  turn = +1; }
;
;          if (turn < 0)       roll = max(roll - BANKSTP, -BANKMAX);
;          else if (turn > 0)  roll = min(roll + BANKSTP,  BANKMAX);
;          else if (roll < 0)  roll = min(roll + BANKSTP, 0);   /* back level */
;          else if (roll > 0)  roll = max(roll - BANKSTP, 0);
;
;          if (KEYS[SC_DN]) camy += STEPY;     /* stick back: nose up */
;          if (KEYS[SC_UP]) camy -= STEPY;
;          int floor = TWY[NR][NR] + CAMYCL;   /* the ground under you */
;          if (camy < floor)   camy = floor;
;          if (camy > camymax) camy = camymax;
;
;          step_xz();                       /* SPEEDV along the heading */
;          camx += wdx;
;          camz += wdz;
;      }
PHYS:   mov  word [turn],0      ; turn = 0: which way the stick is held
        cmp  byte [KEYS+SC_LF],0    ; is LEFT held?
        je   .nl                    ;   no
        mov  ax,[heading]           ; AX = heading
        sub  ax,TURNV               ; AX = heading - TURNV
        and  ax,255                 ; AX &= 255: a byte IS the whole circle,
        mov  [heading],ax           ;  so this cannot go out of range
        mov  word [turn],-1         ; turn = -1
.nl:    cmp  byte [KEYS+SC_RT],0    ; is RIGHT held?
        je   .nr                    ;   no
        mov  ax,[heading]           ; AX = heading
        add  ax,TURNV               ; AX = heading + TURNV
        and  ax,255                 ; AX &= 255
        mov  [heading],ax           ; heading = AX
        mov  word [turn],1          ; turn = +1

        ; ---- the bank. roll chases the turn, and falls back to level -----
        ; Four compares and two adds, and this is the whole "feel" of the
        ; aeroplane. It models nothing at all.
.nr:    mov  ax,[turn]          ; AX = turn
        test ax,ax              ; turn == 0 ?
        jz   .decay             ;   yes: fall back toward level
        jg   .bankr             ;   turn > 0: bank right
        mov  ax,[roll]          ; AX = roll            ---- bank left
        sub  ax,BANKSTP         ; AX = roll - BANKSTP
        cmp  ax,-BANKMAX        ; AX >= -BANKMAX ?
        jge  .bset              ;   yes: that is the new roll
        mov  ax,-BANKMAX        ;   no: pinned at the limit
        jmp  .bset              ; and store it
.bankr: mov  ax,[roll]          ; AX = roll            ---- bank right
        add  ax,BANKSTP         ; AX = roll + BANKSTP
        cmp  ax,BANKMAX         ; AX <= BANKMAX ?
        jle  .bset              ;   yes
        mov  ax,BANKMAX         ;   no: pinned
        jmp  .bset              ; and store it
.decay: mov  ax,[roll]          ; AX = roll            ---- back to level
        test ax,ax              ; roll == 0 ?
        jz   .bset              ;   yes: already level
        jg   .dpos              ;   roll > 0: come down
        add  ax,BANKSTP         ; AX = roll + BANKSTP   (roll was negative)
        cmp  ax,0               ; overshot past level?
        jle  .bset              ;   no
        xor  ax,ax              ;   yes: AX = 0, stop exactly level
        jmp  .bset              ; and store it
.dpos:  sub  ax,BANKSTP         ; AX = roll - BANKSTP
        cmp  ax,0               ; overshot past level?
        jge  .bset              ;   no
        xor  ax,ax              ;   yes: AX = 0
.bset:  mov  [roll],ax          ; roll = AX. SETTRIG turns this into
                                ;  rsin/rcos at the top of the next frame,
                                ;  and APPLYROLL tilts every point by it

        ; ---- climb and dive, AND THE KEYS ARE THE OTHER WAY ROUND -------
        ; DOWN climbs and UP dives, which reads wrong on paper and is
        ; right in the air. Every flight simulator has had it this way
        ; round, because the thing in your hand is not a lift button. It
        ; is a stick, and you PULL IT BACK to go up. Lesson 14 had it the
        ; lift way, and this is the fix.
        cmp  byte [KEYS+SC_DN],0    ; is DOWN held?      (the stick, back)
        je   .nu                    ;   no
        mov  ax,[camy]              ; AX = camy
        add  ax,STEPY               ; AX = camy + STEPY   - and it CLIMBS
        mov  [camy],ax              ; camy = AX
.nu:    cmp  byte [KEYS+SC_UP],0    ; is UP held?     (the stick, forward)
        je   .nd                    ;   no
        mov  ax,[camy]              ; AX = camy
        sub  ax,STEPY               ; AX = camy - STEPY   - and it drops
        mov  [camy],ax              ; camy = AX

        ; ---- and the floor is the GROUND now ----------------------------
        ; Lesson 14 pinned the height at a flat ninety six, and ninety six
        ; above a plane at nought is ninety six wherever you are. It is
        ; not a plane any more.
        ;
        ; The floor is whatever TERRPREP cached for the node the eye is
        ; standing over - the middle one of the block, at (NR, NR) - plus
        ; a clearance. Fly at a hill and you do not go through it: you are
        ; carried up its side.
        ;
        ; That is not a crash, and a crash is not what this lesson is
        ; about. It is the difference between scenery and ground.
.nd:    mov  si,(NR*TSIDE+NR)*2 ; SI = the slot of the node under the eye
        mov  bx,[TWY+si]        ; BX = the world height of the ground there
        add  bx,CAMYCL          ; BX += the clearance: the lowest you may be
        mov  ax,[camy]          ; AX = camy
        cmp  ax,bx              ; camy >= ground + clearance ?
        jge  .y1                ;   yes: you are clear of it
        call CRASH              ;   NO - AND THAT IS THE END OF THE FLIGHT.
                                ;    BX is still the ground plus the
                                ;    clearance, and CRASH wants it
        ret                     ;    Lesson 15 wrote `mov ax,bx` here and
                                ;    carried you up to the surface. That was
                                ;    a floor. This is the ground
.y1:    cmp  ax,[camymax]       ; camy <= the ceiling ?
        jle  .y2                ;   yes
        mov  ax,[camymax]       ;   no: pinned
.y2:    mov  [camy],ax          ; camy = AX

        ; ---- and it always moves forward ---------------------------------
        call STEPXZ             ; wdx, wdz = one frame's travel along heading
        mov  ax,[wdx]           ; AX = wdx
        add  [camx],ax          ; camx += wdx
        mov  ax,[wdz]           ; AX = wdz
        add  [camz],ax          ; camz += wdz
        ret                     ; return

; ============================================================================
;  TOPOFMAP - how high is the highest thing on this island?
;
;  Four thousand and ninety six bytes, one pass, once, at the boot. HMAP is
;  64 by 64 and it is laid out as one flat run, so the scan needs no rows
;  and no multiply: walk it with LODSB and keep the biggest.
;
;  Then put that byte through WORLDH and the VEXAG shift - the SAME two
;  steps TERRPREP uses on every node - because the answer has to be in the
;  units the flight model works in, not in map bytes. Ask the question in
;  one set of units and answer it in another and you get a number that
;  looks reasonable and is wrong by a factor of ten.
;
;  Everything that depends on the shape of the island is worked out here:
;  where the aeroplane appears, and where the ceiling is.
; ============================================================================
;  In C:
;
;      void topofmap(void)
;      {
;          int top = 0;
;          for (int i = 0; i < 4096; i++)
;              if (HMAP[i] > top) top = HMAP[i];
;          gtop    = worldh(top) << VEXAG;   /* in world units now */
;          camy0   = gtop + SPAWNUP;
;          camymax = gtop + CEILUP;
;      }
TOPOFMAP:
        mov  si,HMAP            ; SI = &HMAP[0]. LODSB reads DS:SI and DS is
                                ;  ours already - a .COM is one segment
        mov  cx,4096            ; CX = 64*64, the whole island
        xor  ah,ah              ; AH = 0: the tallest byte seen so far
.l:     lodsb                   ; AL = *si++
        cmp  al,ah              ; AL > AH ?
        jbe  .n                 ;   no: leave the record standing
        mov  ah,al              ;   yes: a new tallest
.n:     loop .l                 ; while (--cx)

        mov  al,ah              ; AL = the tallest map byte
        xor  ah,ah              ; AX = it, 0..255
        call WORLDH             ; AX = what that is in world units
        mov  cl,VEXAG           ; CL = the exaggeration...
        shl  ax,cl              ; AX <<= CL   ...the same one the ground got
        mov  [gtop],ax          ; gtop = the highest ground on the island

        add  ax,SPAWNUP         ; AX += SPAWNUP
        mov  [camy0],ax         ; camy0 = above the worst of it
        mov  ax,[gtop]          ; AX = gtop again
        add  ax,CEILUP          ; AX += CEILUP
        mov  [camymax],ax       ; camymax = and the ceiling over that
        ret                     ; return

; ============================================================================
;  CRASH - one byte, and the flight is over.
;
;  THE GAME'S IS CRASHHANDLE, in GAMES\OWLFLY3\SRC\FLIGHT.INC. Read it
;  next to this one, because the SHAPE is identical and everything the game
;  does extra is cinema rather than logic:
;
;      ours                    the game's, on top of it
;      dying = 1               a wreck model that breaks up and falls
;      dytick = 0              the camera dollies back and watches it
;                              the explosion, and its own recording
;                              the flashback buffer starts replaying
;                              the score counts him as a loss
;
;  And the first two lines are word for word: a wreck cannot crash twice.
;  Without that test the aeroplane hits the hill sixty times a second, and
;  every one of them resets the tick the message is blinking on.
;
;  WHY IT IS ONE BYTE AND NOT A JUMP. `dying` is read in exactly one place,
;  at the top of the flight loop, and everything else carries on as it was:
;  the frame is still drawn, the counter still counts, the keys still
;  arrive. A crash is not the program stopping. It is the program in a
;  different state, and that is why lesson 14's four rules can simply be
;  skipped rather than unpicked.
; ============================================================================
;  In C:
;
;      void crash(void)
;      {
;          if (dying) return;           /* a wreck cannot crash twice */
;          dying  = 1;
;          dytick = 0;
;      }
CRASH:  cmp  byte [dying],0     ; already a wreck?
        jne  .x                 ;   yes: nothing to do, and nothing to reset
        mov  byte [dying],1     ; dying = 1
        mov  word [dytick],0    ; dytick = 0: the message starts blinking now
        mov  [camy],bx          ; camy = the ground here plus the clearance,
                                ;  which PHYS had in BX one instruction ago.
                                ;  Without this the eye stays where the dive
                                ;  put it - UNDER the surface - and the last
                                ;  picture of the flight is one flat colour

        ; ---- and step back, so you can see what you hit -------------------
        ; The game dollies the camera a hundred units back along the
        ; heading and watches the wreck fall. We have no wreck to watch, so
        ; this is the half of it that carries the meaning: stand behind the
        ; point of impact and look at the hillside. BACKOFF is the game's
        ; hundred, in our units - its world is built on a 256-unit cell and
        ; this one on a 1024-unit node, so the same distance is four times
        ; the number.
        mov  ax,[hsin]          ; AX = hsin  \  one step BACKWARDS along the
        mov  bx,BACKOFF         ; BX = BACKOFF  way we were pointing: the
        imul bx                 ; DX:AX = ...   same sum STEPXZ does, and
        mov  bx,256             ; BX = 256      then SUBtracted instead of
        idiv bx                 ; AX = hsin*BACKOFF/256   added
        sub  [camx],ax          ; camx -= AX
        mov  ax,[hcos]          ; AX = hcos
        mov  bx,BACKOFF         ; BX = BACKOFF
        imul bx                 ; DX:AX = hcos * BACKOFF
        mov  bx,256             ; BX = 256
        idiv bx                 ; AX = hcos * BACKOFF / 256
        sub  [camz],ax          ; camz -= AX
.x:     ret                     ; return

; ============================================================================
;  AIRBORNE - put an aeroplane in the air. Called at the boot, and again by
;  every press of SPACE on the crash screen.
;
;  It exists because a reset that forgets ONE number is worse than no reset
;  at all: put the camera back and leave the bank at forty degrees and the
;  new aeroplane starts in a knife-edge turn. Everything the flight model
;  touches is listed here, in one place, and that is the only way to keep
;  the list honest as the model grows.
; ============================================================================
AIRBORNE:
        mov  word [camx],32*1024    ; camx = node 32   \  the same spot every
        mov  word [camz],26*1024    ; camz = node 26    > time, so a crash is
        mov  ax,[camy0]             ; AX = camy0       /  about the ground and
        mov  [camy],ax              ; camy = camy0     /  not about the seed
        mov  word [heading],0       ; heading = 0         not about the seed
        mov  word [roll],0          ; roll = 0: wings level
        mov  word [turn],0          ; turn = 0: the stick is centred
        mov  byte [dying],0         ; dying = 0: flying again
        mov  word [dytick],0        ; dytick = 0
        ret                         ; return

; ============================================================================
;  KBINT - our own INT 9. Copied out of CITY.ASM line 259.
;
;  The keyboard raises this interrupt itself, on every press AND on every
;  release. The scan code is waiting on port 60h: the key's number, with
;  bit 7 set if it is coming up rather than going down. We write 1 or 0
;  into our own table and tell the interrupt controller we are finished.
;
;  It does NOT chain to the handler it replaced, so the BIOS never learns
;  that a key happened and INT 16h stays empty for as long as this program
;  runs. That is the price of the table, it is what the game pays, and it
;  is why the map screen above waits on KEYS and not on the BIOS.
;
;  A HANDLER OWNS NOTHING. It can fire between any two instructions of the
;  program it interrupts, so every register it touches is pushed first -
;  including DS, because the program it interrupted may have had its own.
; ============================================================================
;  In C:
;
;      void interrupt kbint(void)
;      {
;          unsigned char code = inp(0x60);
;          KEYS[code & 0x7F] = (code & 0x80) ? 0 : 1;
;          outp(0x20, 0x20);                    /* end of interrupt */
;      }
KBINT:  push ax                 ; save every register this touches...
        push bx                 ; keep BX
        push di                 ; keep DI
        push ds                 ; ...DS included: whoever we interrupted
        mov  ax,cs              ; AX = cs       had its own
        mov  ds,ax              ; DS = cs: now KEYS means our KEYS
        in   al,60h             ; AL = the scan code, straight off the port
        mov  ah,al              ; AH = a copy, with bit 7 still on it
        and  al,7Fh             ; AL = the key itself, bit 7 cleared
        mov  bl,al              ; BL = the key
        xor  bh,bh              ; BH = 0: BX = the key, as an index
        mov  di,KEYS            ; DI = &KEYS[0]
        add  di,bx              ; DI = &KEYS[key]
        test ah,80h             ; bit 7 set = the key came UP
        jnz  .brk               ;   yes: it was released
        mov  byte [di],1        ; KEYS[key] = 1: held down
        jmp  .eoi               ; and finish
.brk:   mov  byte [di],0        ; KEYS[key] = 0: let go
.eoi:   mov  al,20h             ; AL = 20h, "end of interrupt"
        out  20h,al             ; tell the controller, or nothing fires again
        pop  ds                 ; everything back, exactly as it was found
        pop  di                 ; DI back
        pop  bx                 ; BX back
        pop  ax                 ; AX back
        iret                    ; return from interrupt

; ============================================================================
;  REMOTE - the one window left in the BIOS door.
;
;  Taking INT 9 shut the BIOS keyboard off, and it shut it off for
;  EVERYONE, not only for a person at the keyboard. Anything that drives
;  this program from outside puts its keys in the BIOS buffer, because
;  that is where a keystroke normally lands - and after INT 9 was taken,
;  nothing in here would ever read them.
;
;  So once a frame we look. A scan code found there is written into the
;  key table and HELD for RHOLD frames, as though a finger had been on
;  it. Held, not tapped: the bank needs ten frames in a row to build, and
;  a key that lasted one frame would move it three and let it fall
;  straight back. Each new code refreshes the hold, so a stream of them
;  is one long press.
;
;  The real keyboard never comes through here. KBINT does not pass a key
;  on, so the BIOS buffer only ever holds what somebody else put in it.
; ============================================================================
;  In C:
;
;      void remote(void)
;      {
;          if (key_waiting()) { rkey = scan_of(get_key());  rhold = RHOLD; }
;          if (rhold)     { rhold--;  KEYS[rkey] = 1; }
;          else if (rkey) { KEYS[rkey] = 0;  rkey = 0; }
;      }
REMOTE: mov  ah,1               ; AH = 1: is anything in the BIOS buffer?
        int  16h                ; ZF set = nothing there
        jz   .hold              ;   nothing fed: on to the hold
        mov  ah,0               ; AH = 0: take it out of the buffer
        int  16h                ; AH = the scan code, AL the character
        mov  [rkey],ah          ; rkey = the scan code
        mov  byte [rhold],RHOLD ; rhold = RHOLD - a new one refreshes it
.hold:  cmp  byte [rhold],0     ; still holding one?
        je   .let               ;   no: let it go
        dec  byte [rhold]       ; rhold--
        mov  bl,[rkey]          ; BL = rkey
        xor  bh,bh              ; BX = rkey, as an index into the table
        mov  byte [KEYS+bx],1   ; KEYS[rkey] = 1: held, this frame too
        ret                     ; return
.let:   mov  bl,[rkey]          ; BL = rkey
        or   bl,bl              ; was there one at all?
        jz   .none              ;   no: nothing to let go of
        xor  bh,bh              ; BX = rkey
        mov  byte [KEYS+bx],0   ; KEYS[rkey] = 0: let go
        mov  byte [rkey],0      ; rkey = 0: and forgotten
.none:  ret                     ; return

; ---- STEPXZ: one pace along the way the camera is facing ------------------
;  The heading's own sine and cosine are already in hsin/hcos, put there by
;  SETTRIG once a turn, so a pace is two multiplies and no table lookup.
;  In C:
;
;      void step_xz(void)
;      {
;          wdx = SPEEDV * hsin / 256;    /* hsin, hcos are sin/cos * 256 */
;          wdz = SPEEDV * hcos / 256;
;      }
STEPXZ: mov  ax,[hsin]          ; AX = hsin
        mov  bx,SPEEDV          ; BX = SPEEDV
        imul bx                 ; DX:AX = hsin * SPEEDV
        mov  bx,256             ; BX = 256
        idiv bx                 ; AX = hsin * SPEEDV / 256
        mov  [wdx],ax           ; wdx = AX
        mov  ax,[hcos]          ; AX = hcos
        mov  bx,SPEEDV          ; BX = SPEEDV
        imul bx                 ; DX:AX = hcos * SPEEDV
        mov  bx,256             ; BX = 256
        idiv bx                 ; AX = hcos * SPEEDV / 256
        mov  [wdz],ax           ; wdz = AX
        ret                     ; return

; ============================================================================
;  FRAME - clear, draw the lattice, show it.
; ============================================================================
; ============================================================================
;  In C:
;
;      void frame(void)
;      {
;          bufseg = cs + 0x1000;            /* always: see below */
;          memset(buf, 0, 64000);           /* clear   */
;          faults = 0;  ground();  tally();  hud();
;          wait_retrace();
;          memcpy(screen, buf, 64000);      /* blit    */
;      }
;
;  LESSON 13 CHOSE HERE, and it does not any more. With the screen clip
;  switchable, a stage that took it down had to draw ON THE SCREEN instead
;  of behind a buffer - a line walking four thousand pixels off the edge
;  takes the best part of a minute, and behind a buffer that is a black
;  screen and a mystery. There is no such stage now and no such switch:
;  every frame is built in the back buffer and blitted whole.
FRAME:  mov  ax,cs              ; AX = cs
        add  ax,1000h           ; AX = cs + 1000h: the back buffer
        mov  [bufseg],ax        ; bufseg = AX
        mov  es,ax              ; ES = bufseg           \  memset(buf,0,64000):
        xor  di,di              ; DI = 0                 > 32000 words of 0,
        xor  ax,ax              ; AX = 0                /  written by STOSW
        mov  cx,32000           ; CX = 32000
        rep  stosw              ; while (cx--) *es:di++ = ax
                                ;
                                ; AND NOTHING ELSE IS PAINTED. Lesson 13 drew
                                ; a grey line across the middle here, to mark
                                ; where a flat plane meets the eye's axis, and
                                ; it was worth having while the camera stayed
                                ; level. An aeroplane does not. The moment the
                                ; world banks, a line pinned to row 100 says
                                ; "the ground is tilted and you are not",
                                ; which is exactly backwards.
                                ;
                                ; The game has no such line either. It fills
                                ; the top half with sky and the bottom with
                                ; ground - and if you look at its palette,
                                ; those two colours are 6,9,22 and 4,6,16.
                                ; The same dark blue twice. WIRE CITY has no
                                ; visible horizon at all, and that is why its
                                ; level split never argues with its bank.
                                ;
                                ; A sky that banks with the world is a filled
                                ; polygon, and SCANPOLY in E_RAST.INC would
                                ; draw it today. It belongs to the lesson that
                                ; earns it.
        mov  word [faults],0    ; faults = 0
        call GROUND             ; ground()   - the land, filled
        call TALLY              ; tally()    - the red pixels
        call HUD                ; hud()      - the frame rate
        call WAITVR             ; wait_retrace()
        push ds                 ; keep DS
        mov  ax,0A000h          ; AX = the screen segment
        mov  es,ax              ; ES = screen           \  memcpy(screen,
        mov  ds,[bufseg]        ; DS = bufseg            > buf, 64000) with
        xor  si,si              ; SI = 0                /  MOVSW, 32000 words
        xor  di,di              ; DI = 0
        mov  cx,32000           ; CX = 32000
        rep  movsw              ; while (cx--) *es:di++ = *ds:si++
        pop  ds                 ; DS = ours again
        ret

; ---- TALLY: one red pixel along the top row for every caught divide -------
;  Nothing to read on a good frame, because there is nothing to count. On
;  stage 2 it is a red bar as wide as the trouble.
;  In C:
;
;      void tally(void)
;      {
;          int n = faults;  if (n > 320) n = 320;
;          for (int i = 0; i < n; i++) buf[i] = 12;      /* row 0, red */
;      }
TALLY:  mov  cx,[faults]        ; CX = n = faults
        jcxz  .none             ; if (n == 0) return
        cmp  cx,320             ; n > 320 ?
        jbe  .fit               ;   no: n fits
        mov  cx,320             ;   n = 320   (one row is all we have)
.fit:   mov  ax,[bufseg]        ; AX = bufseg
        mov  es,ax              ; ES = bufseg
        xor  di,di              ; DI = 0      - row 0, column 0
        mov  al,12              ; AL = 12, red out of the default palette:
        rep  stosb              ; while (cx--) *es:di++ = al   instrumentation,
.none:  ret                     ;                              not scenery

; ---- HUD: the frame rate and which engine drew it, top left ---------------
;  Two digits: one DIV, once a frame, on a number under a hundred. The
;  lesson has nothing against dividing; it has something against dividing
;  a hundred and sixty thousand times a second.
;  In C:
;
;      void hud(void)
;      {
;          int n = fpsv;  if (n > 99) n = 99;
;          char *s = fastp ? HUDF : HUDC;          /* "00 FPS   FAST  (F)" */
;          s[0] = '0' + n / 10;
;          s[1] = '0' + n % 10;
;          txt(4, 8, s);                            /* row 4, column 8 */
;      }
HUD:    mov  ax,[fpsv]          ; AX = n = fpsv
        cmp  ax,99              ; n > 99 ?
        jbe  .two               ;   no: n fits
        mov  ax,99              ;   n = 99   (the corner holds two digits)
.two:   mov  bl,10              ; BL = 10
        div  bl                 ; AL = n / 10, AH = n % 10  (byte DIV: both)
        add  ax,'00'            ; AL += '0', AH += '0'  - one ADD, both digits,
                                ;  because '00' is 3030h and neither can carry
        mov  si,HUDF            ; SI = HUDF
        cmp  byte [fastp],0     ; fastp ?
        jne  .put               ;   yes: FAST
        mov  si,HUDC            ;   no: SI = HUDC
.put:   mov  [si],al            ; s[0] = tens
        mov  [si+1],ah          ; s[1] = units
        mov  ax,4               ; AX = row 4: under the tally bar
        mov  bx,8               ; BX = column 8
        call TXT                ; txt(4, 8, s)

        ; ---- and the crash screen, which is two lines of text -------------
        ; The game has a falling wreck, an explosion and a flashback here.
        ; What it also has is these two lines, and they are the part that
        ; tells you what happened.
        cmp  byte [dying],0     ; a wreck?
        je   .out               ;   no: nothing more to say
        test byte [dytick],8    ; bit 3 of the tick: on for eight frames,
        jnz  .press             ;  off for eight. That is the blink, and it
                                ;  costs one TEST - no timer, no counter
        mov  byte [tcol],7      ; tcol = 7: red, and only for this line
        mov  si,MSGCRASH        ; SI = *** CRASH ***
        mov  ax,88              ; AX = row 88
        mov  bx,120             ; BX = column 120
        call TXT                ; txt(88, 120, s)
        mov  byte [tcol],15     ; tcol = 15: white again, for everyone else
.press: mov  si,MSGSPACE        ; SI = PRESS SPACE
        mov  ax,104             ; AX = row 104
        mov  bx,116             ; BX = column 116
        call TXT                ; txt(104, 116, s)
.out:   ret                     ; return

HUDF    db '00 FPS   FAST  (F)',0
HUDC    db '00 FPS   CLASSIC  (F)',0
MSGCRASH db '*** CRASH ***',0   ; the game's own words, DATA.INC line 2044
MSGSPACE db 'PRESS SPACE',0

; ---- TXT: AX = y, BX = x, SI = the string; the PC's own 8x8 font ---------
;  Straight from EXAMPLES\JET.ASM. The glyphs live at F000:FA6E in every
;  PC's ROM - the same ones the BIOS boots with - so a program that wants
;  to write a number needs no font of its own.
;  In C:
;
;      void txt(int y, int x, char *s)
;      {
;          unsigned char *rom = (unsigned char far *)0xF000FA6E;  /* 8x8 glyphs */
;          int at = y * 320 + x;
;          for (; *s; s++, at += 8) {                  /* one character cell */
;              unsigned char *g = rom + *s * 8;        /* its eight rows     */
;              for (int r = 0; r < 8; r++) {
;                  unsigned char bits = g[r];
;                  for (int c = 0; c < 8; c++, bits <<= 1)
;                      if (bits & 0x80) buf[at + r * 320 + c] = tcol;
;              }
;          }
;      }
TXT:    push es                 ; keep ES and DX for the caller
        push dx                 ; keep DX
        mov  cx,ax              ; CX = y      (AX is needed for MUL)
        mov  ax,[bufseg]        ; AX = bufseg
        mov  es,ax              ; ES = bufseg
        mov  ax,cx              ; AX = y
        mov  cx,320             ; CX = 320
        mul  cx                 ; AX = y * 320
        add  ax,bx              ; AX = y * 320 + x
        mov  di,ax              ; DI = at      - the top-left of the first cell
.ch:    lodsb                   ; AL = *s++
        or   al,al              ; end of string?
        jz   .done              ;   yes: return
        push si                 ; keep s
        xor  ah,ah              ; AX = the character
        mov  cl,3               ; CL = 3   (shift count: * 8)
        shl  ax,cl              ; AX = char * 8     - offset of its glyph
        mov  si,0FA6Eh          ; SI = FA6Eh        \  g = rom + char*8
        add  si,ax              ; SI = FA6Eh + char*8 /
        push ds                 ; keep DS
        mov  ax,0F000h          ; AX = F000h
        mov  ds,ax              ; DS = F000h        - now DS:SI is the ROM
        mov  cx,8               ; CX = 8 rows
        push di                 ; keep at
.row:   lodsb                   ; AL = bits = g[r]  - MSB is the left pixel
        mov  ah,al              ; AH = bits
        push cx                 ; keep the row count
        mov  cx,8               ; CX = 8 columns
.px:    shl  ah,1               ; bits <<= 1; CF = the pixel that fell off
        jnc  .np                ; if (bit was 0) skip
        mov  al,[cs:tcol]       ; AL = tcol   ([cs:] because DS is the ROM)
        mov  [es:di],al         ; buf[at] = tcol
.np:    inc  di                 ; at++  (next column)
        loop .px                ; 8 columns
        add  di,320-8           ; at += 320 - 8   (next row, same column)
        pop  cx                 ; the row count again
        loop .row               ; 8 rows
        pop  di                 ; DI = at, the cell's top-left again
        pop  ds                 ; DS = ours again
        pop  si                 ; SI = s
        add  di,8               ; at += 8   - the next character cell
        jmp  .ch                ; next character
.done:  pop  dx
        pop  es                 ; ES back
        ret                     ; return


; ============================================================================
;  GROUND - the landscape, FILLED, and drawn FAR TO NEAR.
;
;  THIS IS THE GAME'S TERRAIN ROUTINE. It is in GAMES\OWLFLY3\SRC\TERRAIN.INC
;  and it draws sixteen hundred quads where this draws six hundred and
;  twenty five; the level-of-detail start point and the buildings are the
;  only things left out. Everything else below is copied.
;
;  THE PAINTER'S ALGORITHM, and it is not an algorithm so much as an order.
;  Draw the farthest square first and the nearest last, and every square
;  paints over whatever was behind it. Nothing is tested, nothing is
;  compared, nothing is remembered. Lesson 15's skyline needed an array of
;  320 bytes and a compare for every pixel; this needs neither, because a
;  filled polygon already covers what is behind it. You do not pay for
;  hiding - you get it with the colour.
;
;  AND IT IS THE SAME TABLE. TORD was built nearest-first for the skyline.
;  Here it is read from the END backwards, and that is the entire change:
;  one `dec` where lesson 15 had an `inc`. The table did not move.
;
;  WHAT THE PAINTER CANNOT DO, said now rather than later: it is an order,
;  so it is only right when an order exists. Two long quads that overlap
;  each other cannot be sorted, and no amount of care fixes it - the answer
;  is to cut them, which costs more than everything above. A height field
;  never has that problem, because the squares are laid out on a grid and
;  the grid IS the order.
; ============================================================================
;  In C:
;
;      void ground(void)
;      {
;          terrprep();                           /* every node, rotated once */
;          for (ordk = NSIDE*NSIDE - 1; ordk >= 0; ordk--) {
;              si = TORD[ordk];                  /* FARTHEST SQUARE FIRST    */
;              /* the four corners, straight out of the cache */
;              IX[0] = TRX[si];  IZ[0] = TRZ[si];  IY[0] = TWY[si] - camy;
;              ...and the same for si+TSIDE, si+TSIDE+1, si+1
;              if (max_z_of_the_four < NEARZ) continue;      /* behind you */
;              qband(max_H_of_the_four);                     /* the colour */
;              draw_quad();                      /* and it is a CALL: see */
;          }                                     /*  the banner on it     */
;      }
GROUND: call TERRPREP           ; terrprep(): every node rotated ONCE, and
                                ;  its height looked up once, into the cache

        mov  ax,[orddisk]       ; AX = how many squares are in the CIRCLE
        dec  ax                 ; AX = the last of them: the farthest square
        mov  [ordk],ax          ;  inside radius NR. Lesson 15 started at
                                ;  nought and ran to the corner of the block.

        ; ---- WHY A CIRCLE, and why it had to be one -----------------------
        ; The block of squares is a SQUARE, and a square turned forty five
        ; degrees pokes its corners out 41 per cent further than its sides.
        ; At twelve nodes nobody noticed: the corner is 12 x 1024 x 1.41,
        ; seventeen thousand, and a word holds thirty two thousand. At
        ; TWENTY FOUR nodes the corner is thirty four thousand seven hundred
        ; - and ROTXZ adds its two products with a sixteen-bit ADD.
        ;
        ;     heading 0     x' = x*cos - z*sin = 24576 - 0      fits
        ;     heading 45    x' = 17378 + 17378 = 34756          does NOT
        ;
        ; 34756 in a signed word is -30780. The corner of the block is
        ; flung to the far side of the world, the squares hanging off it
        ; become slabs floating over the horizon, and the ones you saw sat
        ; in exactly the directions a diagonal heading points them. That is
        ; why TURNING found them: at 0, 90, 180 and 270 degrees one of the
        ; two products is nought and nothing overflows.
        ;
        ; The fix is not a bigger register. It is the right shape. A view
        ; distance is the same in every direction, and TORD is ALREADY
        ; sorted by distance - so the circle of radius NR is simply the
        ; first `orddisk` entries of it, and GROUND starts there instead of
        ; at the end. The farthest node any drawn square touches is then
        ; NR plus one diagonal step, about twenty six thousand. A turn
        ; cannot make a length longer, so no heading can overflow it.
        ;
        ; And it is a quarter less work: 1793 of the 2401 squares.

.rx:    call DRAWQUAD           ; draw_quad(): one square of the lattice
        dec  word [ordk]        ; ordk--      - and NEARER, which is the
        jns  .rx                ;  whole of the painter's algorithm
        ret                     ; return

; ============================================================================
;  DRAWQUAD - one square. It is a ROUTINE and not the body of the loop
;  above, and that is deliberate: TRAP0 works by putting the stack pointer
;  back to `savesp` and doing a plain RET, so whatever is on top of the
;  stack at `savesp` is where a faulting quad resumes. Inside a routine
;  that is the return address into the loop, and the trap costs one square.
;  Written inline it would be the loop's OWN return address, and a single
;  bad divide would abandon the whole landscape. Lesson 13 learned this
;  with DRAWEDGE3D; the shape is the same and so is the reason.
; ============================================================================
DRAWQUAD:
        mov  [savesp],sp        ; savesp = sp - WHERE THE DIVIDE TRAP COMES
                                ;  BACK TO. At this instant the top of the
                                ;  stack is the return into GROUND's loop
        mov  bx,[ordk]          ; BX = ordk
        add  bx,bx              ; BX = ordk*2: a word to an entry
        mov  si,[TORD+bx]       ; SI = the slot of this square's first corner
        ; ---- THE CULL, and it is four bytes and an AND ---------------------
        ; TERRPREP gave every node three bits: behind, off the right, off
        ; the left. If some plane has ALL FOUR corners outside it, the whole
        ; square is outside it - a convex square with every corner on one
        ; side of a plane lies entirely on that side - and not one pixel of
        ; it can reach the screen. AND the four codes together and any bit
        ; that survives is such a plane.
        ;
        ; This used to be seventy instructions a square, AFTER twelve words
        ; had been loaded to feed them. Now it is thirteen, and a square
        ; that fails it never loads a corner at all. Behind you and off to
        ; the sides is where most of the lattice is, so most squares end
        ; right here.
        ;
        ; And the OR comes free with it: bit 0 of the OR says the near
        ; plane cuts through this square, which the stroke below needs.
        mov  di,si              ; DI = the slot
        shr  di,1               ; DI /= 2: TOUT is bytes
        mov  al,[TOUT+di]       ; AL = corner 0's code
        mov  ah,al              ; AH = the same: the OR starts here too
        mov  bl,[TOUT+di+TSIDE] ; BL = corner 1's
        and  al,bl              ; AL &= it
        or   ah,bl              ; AH |= it
        mov  bl,[TOUT+di+TSIDE+1]   ; BL = corner 2's
        and  al,bl              ; AL &= it
        or   ah,bl              ; AH |= it
        mov  bl,[TOUT+di+1]     ; BL = corner 3's
        and  al,bl              ; AL &= it
        or   ah,bl              ; AH |= it
        or   al,al              ; a plane all four are outside?
        jnz  .skip              ;   yes: gone, and not a corner loaded
        mov  [qor],ah           ; qor = the OR, for the stroke



        ; ---- the four corners, and every number is already worked out -----
        ; The square hangs off node (ta,tb); its other three are one row on,
        ; one row and one node on, and one node on. TSIDE*2 is a whole row
        ; of the cache in bytes, and the assembler works it out.
        mov  ax,[TRX+si]        ; corner 0 = (ta, tb)
        mov  [IX],ax            ; IX[0] = AX          - ALREADY ROTATED
        mov  ax,[TRZ+si]        ; AX = TRZ[slot]
        mov  [IZ],ax            ; IZ[0] = AX
        mov  ax,[TWY+si]        ; AX = the node's world height
        sub  ax,[camy]          ; AX -= camy: how far below the eye it is
        mov  [IY],ax            ; IY[0] = AX
        mov  ax,[TRX+si+TSIDE*2]        ; corner 1 = (ta+1, tb)
        mov  [IX+2],ax          ; IX[1] = AX
        mov  ax,[TRZ+si+TSIDE*2]        ; AX = its z
        mov  [IZ+2],ax          ; IZ[1] = AX
        mov  ax,[TWY+si+TSIDE*2]        ; AX = its height
        sub  ax,[camy]          ; AX -= camy
        mov  [IY+2],ax          ; IY[1] = AX
        mov  ax,[TRX+si+TSIDE*2+2]      ; corner 2 = (ta+1, tb+1)
        mov  [IX+4],ax          ; IX[2] = AX
        mov  ax,[TRZ+si+TSIDE*2+2]      ; AX = its z
        mov  [IZ+4],ax          ; IZ[2] = AX
        mov  ax,[TWY+si+TSIDE*2+2]      ; AX = its height
        sub  ax,[camy]          ; AX -= camy
        mov  [IY+4],ax          ; IY[2] = AX
        mov  ax,[TRX+si+2]              ; corner 3 = (ta, tb+1)
        mov  [IX+6],ax          ; IX[3] = AX
        mov  ax,[TRZ+si+2]      ; AX = its z
        mov  [IZ+6],ax          ; IZ[3] = AX
        mov  ax,[TWY+si+2]      ; AX = its height
        sub  ax,[camy]          ; AX -= camy
        mov  [IY+6],ax          ; IY[3] = AX

        ; ---- the colour: the HIGHEST of the four corners -------------------
        ; A square is one colour, and it is decided by its tallest corner.
        ; Take the lowest instead and a snow cap grows a ring of rock.
        mov  di,si              ; DI = the slot
        shr  di,1               ; DI /= 2: TH is bytes
        mov  al,[TH+di]         ; AL = corner 0's raw height
        mov  ah,[TH+di+TSIDE]   ; AH = corner 1's
        cmp  al,ah              ; AL >= AH ?
        jae  .c1
        mov  al,ah              ; AL = the taller
.c1:    mov  ah,[TH+di+TSIDE+1] ; AH = corner 2's
        cmp  al,ah              ; AL >= AH ?
        jae  .c2
        mov  al,ah              ; AL = the taller
.c2:    mov  ah,[TH+di+1]       ; AH = corner 3's
        cmp  al,ah              ; AL >= AH ?
        jae  .c3
        mov  al,ah              ; AL = the tallest of the four
.c3:    call QBAND              ; COLOR = the band that height falls in

        ; ---- and paint it --------------------------------------------------
        mov  ax,[bufseg]        ; ES = the buffer the polygon goes into
        mov  es,ax              ; ES = bufseg
        call FACEFILL           ; facefill(): clip to the near plane, project
                                ;  what survives, and run the scanline filler

        ; ---- and the seams: each edge ONCE, by the square on top ----------
        ; ORDPREP gave every square the edges it OWNS - the ones it shares
        ; with farther neighbours, which were painted before it. So its own
        ; fill cannot cover them and nothing painted later touches them.
        ; Half the lines of stroking every side, and every line still lands
        ; on top.
        ;
        ; It reads PX and PY, which FACEFILL has just projected - the
        ; outline costs no projection of its own. That only works while PX
        ; and PY ARE the square's four corners, in order, and they are
        ; exactly when the near-plane clip had nothing to cut. When it did
        ; cut, the polygon it left is a different shape with a different
        ; number of corners, and that square is outlined whole, as before.
        ; Those are the few squares right beside you.
        cmp  word [NPOLY],3     ; did the clip leave a polygon at all?
        jl   .skip              ;   no: FACEFILL drew nothing
        add  byte [COLOR],8     ; COLOR += 8: the same band, folded
        test byte [qor],1       ; did the near plane cut this square?
        jz   .own               ;   no: PX/PY are its four corners, in order
        call STROKEPOLY         ;   yes: outline whatever the clip left
        ret                     ; return

.own:   mov  bx,[ordk]          ; BX = ordk
        mov  al,[TEDGE+bx]      ; AL = the edges this square owns, one bit each
        mov  [qedge],al         ; qedge = them
        mov  word [qe],0        ; qe = 0: edge 0, which starts at corner 0
.e:     shr  byte [qedge],1     ; CF = does it own this edge?
        jnc  .en                ;   no: its nearer neighbour draws it
        mov  si,[qe]            ; SI = this corner, in bytes
        mov  ax,[PX+si]         ; AX = its screen x
        mov  [sx0],ax           ; sx0 = AX
        mov  ax,[PY+si]         ; AX = its screen y
        mov  [sy0],ax           ; sy0 = AX
        add  si,2               ; SI = the next corner round...
        and  si,7               ; ...and 8 AND 7 is 0: corner 3 goes to 0
        mov  ax,[PX+si]         ; AX = its x
        mov  [sx1],ax           ; sx1 = AX
        mov  ax,[PY+si]         ; AX = its y
        mov  [sy1],ax           ; sy1 = AX
        call CLIPLINE           ; clip_line(): on the screen at all?
        jc   .en                ;   no
        call LINE               ; line()
.en:    add  word [qe],2        ; the next edge
        cmp  word [qe],8        ; all four looked at?
        jl   .e                 ;   no

.skip:  ret                     ; return - to the loop, one square on

; ============================================================================
;  ORDPREP - the drawing order, worked out ONCE at the boot.
;
;  A wireframe does not care what order its lines go down in. The thing
;  coming next does: hidden-line removal only works if everything NEARER
;  has already been drawn, so the squares have to be walked from the eye
;  outwards.
;
;  The order never changes, because it is a property of the block of
;  squares and not of where the aeroplane is: the eye is always in the
;  middle of it. So it is worked out once, into TORD, and after that the
;  drawing loop just reads a list.
;
;  Sorted by the SQUARE of the distance in squares, which is
;  (ta - NR)^2 + (tb - NR)^2 - no square root, because comparing distances
;  and comparing their squares put things in the same order. The largest
;  is 2*NR^2, so the outer loop runs that many times and each pass picks
;  up everything at exactly that distance. Slow, and it runs once.
;
;  THE GAME HAS THIS TABLE TOO, in TERRAIN.INC, and calls it TORD - only
;  its copy runs the other way, far to near, because a painter works back
;  to front. Same table, read backwards. That is the next lesson.
; ============================================================================
;  In C:
;
;      void ordprep(void)
;      {
;          int n = 0;
;          for (int d = 0; d <= 2*NR*NR; d++)
;              for (int ta = 0; ta < NSIDE; ta++)
;                  for (int tb = 0; tb < NSIDE; tb++)
;                      if ((ta-NR)*(ta-NR) + (tb-NR)*(tb-NR) == d)
;                          TORD[n++] = (ta * TSIDE + tb) * 2;
;      }
ORDPREP:
        mov  word [ordn],0      ; ordn = 0: nothing in the list yet
        mov  word [ordd],0      ; ordd = 0: start with the nearest
.dl:    mov  word [ta],0        ; ta = 0
.al:    mov  word [tb],0        ; tb = 0
.bl:    mov  ax,[ta]            ; AX = ta
        sub  ax,NR              ; AX = ta - NR: how far east of the middle
        imul ax                 ; DX:AX = that, squared  (small: fits AX)
        mov  bx,ax              ; BX = the square of it
        mov  ax,[tb]            ; AX = tb
        sub  ax,NR              ; AX = tb - NR
        imul ax                 ; AX = that, squared
        add  ax,bx              ; AX = the square of the distance
        cmp  ax,[ordd]          ; is it exactly the distance we are on?
        jne  .nx                ;   no: leave it for a later pass

        mov  ax,[ta]            ; AX = ta     \  the slot, the only place
        mov  bx,TSIDE           ; BX = TSIDE   > in the program that has to
        mul  bx                 ; AX = ta*TSIDE   multiply - and it runs
        add  ax,[tb]            ; AX += tb        once, at the boot
        add  ax,ax              ; AX *= 2: a word to a slot
        mov  bx,[ordn]          ; BX = ordn
        add  bx,bx              ; BX = ordn*2: a word to an entry
        mov  [TORD+bx],ax       ; TORD[ordn] = the slot

        ; ---- and which of its four edges this square OWNS ----------------
        ; Every inner edge of the lattice is shared by two squares, and
        ; stroking all four sides of every square draws each of them twice.
        ; So each edge gets ONE owner, and the owner has to be the square
        ; painted LATER - the painter goes far to near, and a line drawn by
        ; the earlier square would be half covered by the fill of the later.
        ; Later is nearer, so: a square owns the edges it shares with
        ; FARTHER neighbours. Its neighbour across the high-a side is at
        ; (da+1)^2 + db^2, farther exactly when da >= 0 - and so on round:
        ;
        ;     edge 0   corner 0 -> 1   the low-b side    owned if db <= 0
        ;     edge 1   corner 1 -> 2   the high-a side   owned if da >= 0
        ;     edge 2   corner 2 -> 3   the high-b side   owned if db >= 0
        ;     edge 3   corner 3 -> 0   the low-a side    owned if da <= 0
        ;
        ; Two edges for almost every square, three along the two axes, all
        ; four for the one in the middle. Two neighbours are never the same
        ; distance away - their squares differ by 2d+1, which is odd - so
        ; every edge has exactly one owner and nothing is left undrawn.
        mov  si,[ordn]          ; SI = ordn: TEDGE has one BYTE an entry
        xor  al,al              ; AL = 0: owns nothing yet
        mov  bx,[tb]            ; BX = tb
        sub  bx,NR              ; BX = db
        cmp  bx,0               ; db > 0 ?
        jg   .e0                ;   yes: the low-b neighbour is nearer
        or   al,1               ;   no: owns edge 0
.e0:    cmp  bx,0               ; db < 0 ?
        jl   .e2                ;   yes: the high-b neighbour is nearer
        or   al,4               ;   no: owns edge 2
.e2:    mov  bx,[ta]            ; BX = ta
        sub  bx,NR              ; BX = da
        cmp  bx,0               ; da < 0 ?
        jl   .e1                ;   yes
        or   al,2               ;   no: owns edge 1
.e1:    cmp  bx,0               ; da > 0 ?
        jg   .e3                ;   yes
        or   al,8               ;   no: owns edge 3
.e3:    mov  [TEDGE+si],al      ; TEDGE[ordn] = the four bits
        inc  word [ordn]        ; ordn++

.nx:    inc  word [tb]          ; tb++
        cmp  word [tb],NSIDE    ; tb < NSIDE ?
        jl   .bl                ;   yes
        inc  word [ta]          ; ta++
        cmp  word [ta],NSIDE    ; ta < NSIDE ?
        jl   .al                ;   yes
        cmp  word [ordd],NR*NR  ; did that pass finish THE CIRCLE of radius
        jne  .nd                ;  NR? Everything so far is inside it...
        mov  ax,[ordn]          ; AX = how many squares that is
        mov  [orddisk],ax       ; orddisk = it. GROUND draws only these
.nd:    inc  word [ordd]        ; ordd++: the next distance out
        cmp  word [ordd],2*NR*NR+1  ; past the far corner?
        jl   .dl                ;   no: another pass
        ret                     ; return

; ============================================================================
;  TERRPREP - out of GAMES\OWLFLY3\SRC\TERRAIN.INC, and it is the answer to
;  a cost lesson 13 owned up to and could not pay.
;
;  Up to here every corner went through ROTXZ FOUR times: once as the start
;  of its own east edge, once as the start of its own north edge, once as
;  the end of its west neighbour's edge, once as the end of its south
;  neighbour's. Four rotations of the same point, every frame, because a
;  square knew nothing about the square next to it.
;
;  So rotate every node ONCE, into a table, and let the squares read it.
;  Four hundred and eighty four nodes, one rotation each, and the drawing
;  loop then does no arithmetic at all beyond an index.
;
;  The height comes with it. HGET does the wrapping, WORLDH turns a map
;  byte into a world height - sea level at 88, land at five units a step,
;  mountains above 200 climbing twice as fast - and both are looked up
;  once per node here instead of once per edge down there.
; ============================================================================
;  In C:
;
;      void terrprep(void)
;      {
;          camgi = (camx + BIAS) >> 10;
;          camgj = (camz + BIAS) >> 10;
;          for (ta = 0; ta < TSIDE; ta++)
;            for (tb = 0; tb < TSIDE; tb++) {
;              gi = camgi + ta - NR;   gj = camgj + tb - NR;
;              wdx = gi * 1024 - BIAS - camx;
;              wdz = gj * 1024 - BIAS - camz;
;              rotxz();                      /* by the heading, once */
;              /* the slot walks: not one multiply in either loop */
;              TRX[ta][tb] = rc_x;
;              TRZ[ta][tb] = rc_z;
;              TWY[ta][tb] = worldh(hget(gi, gj)) << VEXAG;
;            }
;      }
TERRPREP:
        mov  ax,[camx]          ; AX = camx
        add  ax,BIAS            ; AX = camx + BIAS
        mov  cl,2               ; CL = 2   \  >> 10 in two goes: the 8086
        shr  ax,cl              ; AX >>= 2  > shifts by 1 or by CL, and CL
        mov  cl,8               ; CL = 8   /  cannot be 10 in one go
        shr  ax,cl              ; AX >>= 8
        mov  [camgi],ax         ; camgi = the node the eye is over
        mov  ax,[camz]          ; AX = camz
        add  ax,BIAS            ; AX = camz + BIAS
        mov  cl,2               ; CL = 2
        shr  ax,cl              ; AX >>= 2
        mov  cl,8               ; CL = 8
        shr  ax,cl              ; AX >>= 8
        mov  [camgj],ax         ; camgj = ...and the other axis

        mov  word [tsi],0       ; tsi = 0: the first slot, and it walks
        mov  word [ta],0        ; ta = 0
.al:    mov  word [tb],0        ; tb = 0
.bl:    mov  ax,[camgi]         ; AX = camgi    \  which node this slot is
        add  ax,[ta]            ; AX += ta       > in map coordinates
        sub  ax,NR              ; AX -= NR      /
        mov  [gi],ax            ; gi = camgi + ta - NR
        mov  ax,[camgj]         ; AX = camgj
        add  ax,[tb]            ; AX += tb
        sub  ax,NR              ; AX -= NR
        mov  [gj],ax            ; gj = camgj + tb - NR

        mov  ax,[gi]            ; AX = gi       \  its world position, as an
        mov  cl,2               ; CL = 2         > offset from the camera
        shl  ax,cl              ; AX = gi << 2  /
        mov  cl,8               ; CL = 8
        shl  ax,cl              ; AX = gi * 1024
        sub  ax,BIAS            ; AX -= BIAS
        sub  ax,[camx]          ; AX -= camx
        mov  [wdx],ax           ; wdx = how far east of the eye
        mov  ax,[gj]            ; AX = gj
        mov  cl,2               ; CL = 2
        shl  ax,cl              ; AX = gj << 2
        mov  cl,8               ; CL = 8
        shl  ax,cl              ; AX = gj * 1024
        sub  ax,BIAS            ; AX -= BIAS
        sub  ax,[camz]          ; AX -= camz
        mov  [wdz],ax           ; wdz = how far north of it
        call ROTXZ              ; rc_x, rc_z = that, turned by the heading

        mov  si,[tsi]           ; SI = this node's slot
        mov  ax,[rc_x]          ; AX = rc_x
        mov  [TRX+si],ax        ; TRX[slot] = AX
        mov  ax,[rc_z]          ; AX = rc_z
        mov  [TRZ+si],ax        ; TRZ[slot] = AX

        push si                 ; keep the slot: HGET and WORLDH are free to
        mov  bx,[gi]            ; BX = gi   \  eat SI, and one of them does
        mov  dx,[gj]            ; DX = gj   /  HGET wants x in BX, y in DX
        call HGET               ; AL = the raw map height, 0..255, wrapped
        mov  [rawh],al          ; rawh = it, IN MEMORY, and not in a register.
                                ;  WORLDH uses BX as scratch - `mov bx,5` is
                                ;  its second instruction - and it promises
                                ;  nothing about what it leaves behind. This
                                ;  line was `mov bl,al` for an afternoon, and
                                ;  the sea came out in waves: every node
                                ;  ABOVE sea level had its raw height eaten,
                                ;  so the colour ladder read 5 and called the
                                ;  hills water, while the heights beside them
                                ;  stayed right. A caller may assume what a
                                ;  routine RETURNS. Never what it spares
        xor  ah,ah              ; AX = AL
        call WORLDH             ; AX = the world height of that
        mov  cl,VEXAG           ; CL = the exaggeration, from the top of
        shl  ax,cl              ; AX <<= CL   this file. Doubled, and said
                                ;  out loud there rather than hidden here
        pop  si                 ; SI = the slot again
        mov  [TWY+si],ax        ; TWY[slot] = AX

        mov  si,[tsi]           ; SI = the slot again
        shr  si,1               ; SI /= 2: TH is bytes, not words
        mov  al,[rawh]          ; AL = the raw byte, off the shelf
        mov  [TH+si],al         ; TH[slot] = the RAW map byte. Not a colour:
                                ;  a SQUARE has four corners and the game
                                ;  colours it by the HIGHEST of them, so the
                                ;  raw number has to survive to the quad

        ; ---- and the node's OUTCODE, while its numbers are in hand --------
        ; Three bits, one for each plane the picture is bounded by:
        ;
        ;     bit 0   behind the near plane       z < NEARZ
        ;     bit 1   outside the right plane     x >  3z/4
        ;     bit 2   outside the left plane      x < -3z/4
        ;
        ; A square is invisible FOR CERTAIN when all four of its corners
        ; are outside the SAME plane, and that is an AND of four bytes -
        ; see DRAWQUAD. Lesson 13's line clipper does exactly this for the
        ; two ends of a line, and calls the bits by the same name. Worked
        ; out HERE, the answer is paid for once and shared by the four
        ; squares that meet at this node.
        ;
        ; SAR, not SHR, and it matters: z can be negative, and these are
        ; planes through the eye - a point is on one side or the other
        ; whatever its z is.
        xor  al,al              ; AL = 0: inside all three, so far
        mov  bx,[rc_z]          ; BX = z
        cmp  bx,NEARZ           ; z < NEARZ ?
        jge  .o0                ;   no
        or   al,1               ;   yes: bit 0, behind
.o0:    mov  dx,bx              ; DX = z
        sar  dx,1               ; DX = z/2   \  z/4, sign kept. Two single
        sar  dx,1               ; DX = z/4   /  shifts leave CL alone
        sub  bx,dx              ; BX = 3z/4: half the screen, at this depth
        mov  dx,[rc_x]          ; DX = x
        cmp  dx,bx              ; x > 3z/4 ?
        jle  .o1                ;   no
        or   al,2               ;   yes: bit 1, off the right
.o1:    neg  bx                 ; BX = -3z/4
        cmp  dx,bx              ; x < -3z/4 ?
        jge  .o2                ;   no
        or   al,4               ;   yes: bit 2, off the left
.o2:    mov  [TOUT+si],al       ; TOUT[slot] = the three bits

        add  word [tsi],2       ; tsi += a word. The nodes are written in
                                ;  the order they lie in memory, so the
                                ;  slot is never worked out - it walks
        inc  word [tb]          ; tb++
        cmp  word [tb],TSIDE    ; tb < TSIDE ?
        jl   .bl                ;   yes: the next node along
        inc  word [ta]          ; ta++
        cmp  word [ta],TSIDE    ; ta < TSIDE ?
        jl   .al                ;   yes: the next row of nodes
        ret                     ; return

; ---- BAND: COLOR from the height at node (AX = gi, BX = gj) ---------------
;  The boundaries are lesson 0x11's and the engine's - the same numbers
;  GETZONE sorts the world by. The six colours are the island's, so a
;  square here is the colour that square was on the map in stage 1.
;  In C:
;
;      void band(int gi, int gj)
;      {
;          int h = hget(gi & 63, gj & 63);      /* HGET does the & 63 itself */
;          if      (h <  88) COLOR = 1;         /* sea   */
;          else if (h < 120) COLOR = 2;         /* sand  */
;          else if (h < 168) COLOR = 3;         /* grass */
;          else if (h < 200) COLOR = 4;         /* woods */
;          else if (h < 230) COLOR = 5;         /* rock  */
;          else              COLOR = 6;         /* snow  */
;      }
;
;  The assembly keeps the answer in AH and OVERWRITES it on the way down:
;  every `mov ah,n` is "the answer so far", and the first `jb .set` that
;  fires is the `else if` that won.
BAND:   mov  dx,bx              ; DX = gj   \  HGET wants x in BX, y in DX
        mov  bx,ax              ; BX = gi   /
        call HGET               ; AL = h, 0..255; HGET does the wrapping
                                ;  ...and fall straight into the ladder

; ---- QBAND: the ladder on its own. AL = a raw map height, in. ------------
;      Split out of BAND because the FILLED ground already HAS the number
;      and must not look it up again: a square is coloured by the highest
;      of its four corners, and all four are in the cache.
QBAND:  mov  ah,1               ; AH = 1 (sea)      - if nothing below fires
        cmp  al,88              ; h < 88 ?
        jb   .set               ;   yes: sea
        mov  ah,2               ; AH = 2 (sand)
        cmp  al,120             ; h < 120 ?
        jb   .set               ;   yes: sand
        mov  ah,3               ; AH = 3 (grass)
        cmp  al,168             ; h < 168 ?
        jb   .set               ;   yes: grass
        mov  ah,4               ; AH = 4 (woods)
        cmp  al,200             ; h < 200 ?
        jb   .set               ;   yes: woods
        mov  ah,5               ; AH = 5 (rock)
        cmp  al,230             ; h < 230 ?
        jb   .set               ;   yes: rock
        mov  ah,6               ; AH = 6 (snow)     - the else
.set:   mov  [COLOR],ah         ; COLOR = AH
        ret                     ; return

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
;  There is no C for this one, and that is worth saying: C has no way to
;  say "abandon the function that is running and continue from the caller
;  of the function that called it". The nearest is setjmp/longjmp, and this
;  is exactly what longjmp does under the hood - restore the stack pointer
;  and jump.
;
;      void trap0(void)             /* entered by the CPU, not by a call */
;      {
;          sp = savesp;             /* everything PROJPT pushed: gone      */
;          faults++;
;          enable_interrupts();     /* INT turned them off on the way in   */
;          return;                  /* ...to GRIDC, after `call DRAWEDGE3D` */
;      }
TRAP0:  mov  ax,cs              ; AX = our segment
        mov  ds,ax              ; DS = AX: data is ours again, whatever the
                                ;  faulting code had it set to. SS is ours
                                ;  already: a .COM is one segment
        mov  sp,[savesp]        ; sp = savesp: back to the top of DRAWEDGE3D
        inc  word [faults]      ; faults++
        sti                     ; interrupts back on
        ret                     ; return - into GRIDC

; ============================================================================
;  Stage 1: the island from above, and where you are about to stand.
;  Lesson 0x11's picture, redrawn from the same map the flight reads.
; ============================================================================
;  In C:
;
;      void mapview(void)
;      {
;          memset(buf, 0, 64000);
;          for (gj = 63; gj >= 0; gj--)                /* top row = highest z: */
;              for (gi = 0; gi < 64; gi++) {           /*  north up            */
;                  band(gi, gj);
;                  int at = (ORGY + (63 - gj) * 3) * 320 + ORGX + gi * 3;
;                  for (int r = 0; r < 3; r++)         /* a 3x3 block a node   */
;                      buf[at + r*320] = buf[at + r*320 + 1]
;                                      = buf[at + r*320 + 2] = COLOR;
;              }
;          int mx = ((camx + BIAS) >> 10) & 63,  mz = ((camz + BIAS) >> 10) & 63;
;          sx0 = sx1 = ORGX + mx * 3;                  /* the mark: a line   */
;          sy0 = ORGY + (63 - mz) * 3;  sy1 = sy0 - 24; /*  eight nodes long, */
;          COLOR = 15;  line();                        /*  pointing north    */
;      }
MAPVIEW:
        mov  ax,[bufseg]        ; AX = bufseg
        mov  es,ax              ; ES = bufseg           \  memset(buf,0,64000)
        xor  di,di              ; DI = 0                 >
        xor  ax,ax              ; AX = 0                /
        mov  cx,32000           ; CX = 32000 words
        rep  stosw              ; while (cx--) *es:di++ = ax
        mov  word [gj],63       ; gj = 63     - the TOP row is the HIGHEST z:
.row:   mov  word [gi],0        ; gi = 0        north up, like every map printed
.col:   mov  ax,[gi]            ; AX = gi   \  band(gi, gj)
        mov  bx,[gj]            ; BX = gj   /
        call BAND               ; COLOR = the band
        mov  ax,[gj]            ; AX = gj
        mov  bx,63              ; BX = 63
        sub  bx,ax              ; BX = 63 - gj      - rows count down from top
        mov  ax,bx              ; AX = 63 - gj
        mov  bx,320*CELLW       ; BX = 960: one node-row of the picture
        mul  bx                 ; AX = (63 - gj) * 960
        add  ax,ORGY*320        ; AX += ORGY * 320  - the map's top margin
        mov  di,ax              ; DI = the row's start
        mov  ax,[gi]            ; AX = gi
        mov  bx,CELLW           ; BX = 3
        mul  bx                 ; AX = gi * 3
        add  di,ax              ; DI += gi * 3
        add  di,ORGX            ; DI += ORGX        - now DI = at
        mov  al,[COLOR]         ; AL = COLOR
        mov  cx,CELLW           ; CX = 3 rows
.r3:    mov  [es:di],al         ; buf[at]   = COLOR  \  a 3x3 block a node,
        mov  [es:di+1],al       ; buf[at+1] = COLOR   > the way lesson 0x11
        mov  [es:di+2],al       ; buf[at+2] = COLOR  /  painted it
        add  di,320             ; at += 320  (next pixel row)
        loop .r3                ; 3 rows
        inc  word [gi]          ; gi++
        cmp  word [gi],64       ; gi < 64 ?
        jb   .col               ;   yes: next node
        dec  word [gj]          ; gj--
        jns  .row               ; gj >= 0 ? next row  (JNS: -1 sets the sign)

        ; ---- THE WHITE MARK. The bottom end is where you are standing,
        ; and it runs eight nodes toward the top of the map, which is
        ; north. So it is both "you are here" and "this is the way you
        ; will be facing" - the flight starts on heading nought, and
        ; nought is north.
        ;
        ; It is drawn straight up rather than along the heading, and that
        ; is only honest because this screen is shown ONCE, at the boot,
        ; before anything has turned. Show the map again in mid-flight and
        ; the mark would be lying to you.
        mov  ax,[camx]          ; AX = camx             ---- the mark ----
        add  ax,BIAS            ; AX = camx + BIAS
        mov  cl,2               ; CL = 2   (shift count)
        shr  ax,cl              ; AX >>= 2   \  >> 10
        mov  cl,8               ;             >
        shr  ax,cl              ; AX >>= 8   /
        and  ax,63              ; AX &= 63          - mx, the node's column
        mov  bx,CELLW           ; BX = 3
        mul  bx                 ; AX = mx * 3
        add  ax,ORGX            ; AX = ORGX + mx * 3
        mov  [sx0],ax           ; sx0 = AX   \  a vertical line
        mov  [sx1],ax           ; sx1 = AX   /
        mov  ax,[camz]          ; AX = camz
        add  ax,BIAS            ; AX = camz + BIAS
        mov  cl,2               ; CL = 2
        shr  ax,cl              ; AX >>= 2
        mov  cl,8               ; CL = 8
        shr  ax,cl              ; AX >>= 8
        and  ax,63              ; AX &= 63          - mz, the node's row
        mov  bx,63              ; BX = 63
        sub  bx,ax              ; BX = 63 - mz
        mov  ax,bx              ; AX = 63 - mz
        mov  bx,CELLW           ; BX = 3
        mul  bx                 ; AX = (63 - mz) * 3
        add  ax,ORGY            ; AX = ORGY + (63 - mz) * 3
        mov  [sy0],ax           ; sy0 = AX          - where you stand
        sub  ax,8*CELLW         ; AX -= 24
        mov  [sy1],ax           ; sy1 = sy0 - 24    - eight nodes north
        mov  byte [COLOR],15    ; COLOR = 15, white
        call LINE               ; line()
        ret                     ; return

; ---- SHOW: the back buffer onto the screen --------------------------------
;  In C:  wait_retrace();  memcpy(screen, buf, 64000);
SHOW:   call WAITVR             ; wait_retrace()
        push ds                 ; keep DS
        mov  ax,0A000h          ; AX = A000h
        mov  es,ax              ; ES = the screen     \  memcpy(screen, buf,
        mov  ds,[bufseg]        ; DS = bufseg          > 64000): 32000 words
        xor  si,si              ; SI = 0              /  through MOVSW
        xor  di,di              ; DI = 0
        mov  cx,32000           ; CX = 32000
        rep  movsw              ; while (cx--) *es:di++ = *ds:si++
        pop  ds                 ; DS = ours again
        ret                     ; return

; ---- WAITVR: wait for the beam to fly home --------------------------------
;  Port 3DAh, bit 3: the VERTICAL RETRACE. Wait OUT any retrace already
;  running, then wait for the next one to begin - a whole frame, every time.
;  In C:
;
;      void wait_retrace(void)
;      {
;          while ( inp(0x3DA) & 8) ;     /* wait OUT any retrace running */
;          while (!(inp(0x3DA) & 8)) ;   /* wait for the next to begin   */
;      }
WAITVR: push ax                 ; keep AX and DX for the caller
        push dx                 ; keep DX
        mov  dx,3DAh            ; DX = 3DAh, the VGA status port
.o:     in   al,dx              ; AL = inp(0x3DA)
        test al,8               ; bit 3 = the beam is in vertical retrace
        jnz  .o                 ; while (retrace) ;   - wait it out
.i:     in   al,dx              ; AL = inp(0x3DA)
        test al,8               ; bit 3 again
        jz   .i                 ; while (!retrace) ;  - wait for the next
        pop  dx                 ; DX back
        pop  ax                 ; AX back
        ret                     ; return

; ---- SETPAL: the island's six colours, written into the VGA DAC -----------
;  Port 3C8h takes the colour NUMBER to start at, then 3C9h takes red,
;  green and blue - 0..63 each, and the index steps on by itself after
;  every third write. Lesson 0x11's ramp, unchanged, so a square in the
;  air is the colour it was on the map.
;  In C:
;
;      void setpal(void)
;      {
;          outp(0x3C8, 1);                        /* start at colour 1   */
;          for (int i = 0; i < 6 * 3; i++)
;              outp(0x3C9, PAL[i]);               /* r, g, b, r, g, b... */
;      }
SETPAL: mov  dx,3C8h            ; DX = 3C8h, the DAC index port
        mov  al,1               ; AL = 1
        out  dx,al              ; outp(0x3C8, 1): start at colour 1
        inc  dx                 ; DX = 3C9h, the DAC data port
        mov  si,PAL             ; SI = PAL
        mov  cx,14*3            ; CX = 42 bytes: fourteen colours, r g b
                                ;  each. Six ground bands, the crash red, a
                                ;  gap, and then the SAME six again at half
                                ;  brightness - see the table for why
.p:     lodsb                   ; AL = *si++
        out  dx,al              ; outp(0x3C9, AL)   - the index steps on by
        loop .p                 ;  itself after every third write
        ret                     ; return

; ---- THE PALETTE IS IN TWO HALVES, EIGHT APART ---------------------------
;  1 to 6 are the ground. 9 to 14 are the SAME SIX at half brightness, and
;  that is what the grid on the ground is drawn in: not one dark colour for
;  the whole world, but a darker shade of whatever square it is creasing.
;  A single dark line over sea and over snow is a WIRE lying on top of the
;  picture. A line that is the square's own colour, darker, is a FOLD in
;  the surface - and the eye reads the two completely differently.
;
;  EIGHT APART ON PURPOSE. The seam of a square is its colour plus eight,
;  one ADD, no table and no branch. That is the whole reason 7 and 8 sit
;  where they do: the gap is not waste, it is what makes the arithmetic
;  free.
PAL     db  4,10,28             ; 1 sea
        db 46,42,26             ; 2 sand
        db 16,38,10             ; 3 grass
        db 10,26, 8             ; 4 woods
        db 26,24,22             ; 5 rock
        db 46,48,50             ; 6 snow
        db 60,12, 8             ; 7 the crash message. It needs its own
                                ;  entry because THIS PALETTE IS NOT THE
                                ;  BIOS ONE any more: colour 4 is woods
                                ;  here, and asking for "red" by number
                                ;  got a dark green message
        db  0, 0, 0             ; 8 unused, and it is the gap that puts the
                                ;  dark half exactly eight above the light
        db  2, 5,14             ; 9  sea, folded
        db 23,21,13             ; 10 sand
        db  8,19, 5             ; 11 grass
        db  5,13, 4             ; 12 woods
        db 13,12,11             ; 13 rock
        db 23,24,25             ; 14 snow

; ============================================================================
;  State: the lesson's own, then the contract the engine modules expect.
; ============================================================================
camx    dw 0                    ; where the eye stands, in world units
rawh    db 0                    ; TERRPREP: one node's raw map height, kept
                                ;  across WORLDH, which does not spare BX
gtop    dw 0                    ; THE HIGHEST GROUND ON THIS ISLAND, in
                                ;  world units. TOPOFMAP works it out once
camy0   dw 0                    ; ...where the aeroplane appears, over it...
camymax dw 0                    ; ...and the ceiling, over that
camy    dw 0                    ; how high over the plane
camz    dw 0
camgi   dw 0                    ; ...and which node that is
camgj   dw 0
gi      dw 0                    ; the lattice's own counters
gj      dw 0
ta      dw 0                    ; ...and the cache's: which node, east
tb      dw 0                    ; ...and north, counted from the far corner
tsi     dw 0                    ; the slot GRIDC is working on, kept across
                                ;  DRAWEDGE3D because that eats SI
ordk    dw 0                    ; which entry of TORD is being drawn
ordn    dw 0                    ; ORDPREP: how many are in the list so far
ordd    dw 0                    ; ORDPREP: the distance it is filling in
qor     db 0                    ; DRAWQUAD: the OR of the four outcodes
qedge   db 0                    ; ...the edges still to look at
qe      dw 0                    ; ...and which one it is on, in bytes
orddisk dw 0                    ; ...and how many squares lie inside the
                                ;  circle of radius NR: all GROUND draws

savesp  dw 0                    ; where TRAP0 puts the stack back to
faults  dw 0                    ; ...and how many times it had to, this frame
oldi0   dw 0,0                  ; the INT 0 vector we borrowed...
oldi9   dw 0,0                  ; ...and the INT 9 one. Both go back at QUIT

dying   db 0                    ; 1 = a wreck. The flight model is skipped,
                                ;  everything else carries on
dytick  dw 0                    ; frames since the impact - the message
                                ;  blinks on bit 3 of it
turn    dw 0                    ; which way the stick is held: -1, 0 or +1
fwas    db 0                    ; was F held last frame? - so one press is
                                ;  one flip and not sixty
rkey    db 0                    ; REMOTE: the code fed from outside, 0 = none
rhold   db 0                    ; ...and how many frames it is still held for

fastp   db 1                    ; WHICH ENGINE: 1 = the lessons' way (no
                                ;  divide in ROTXZ, lesson 8's Line), 0 =
                                ;  the classic the game shipped with. F
                                ;  flips it in flight; ENGINE\E_M3D.INC
                                ;  and E_RAST.INC read it and nothing else
fpsn    dw 0                    ; frames counted this second...
fpst    dw 0                    ; ...since this BIOS tick...
fpsv    dw 0                    ; ...and the number the HUD shows
tcol    db 15                   ; TXT's colour

; THE TWO FENCES ARE NOT BYTES ANY MORE. Lesson 13 made donear and doside
; switchable so a stage could take one down and let you look at what it was
; holding back; lesson 14 left them standing at 1. On the polygon path they
; are not optional and there is nowhere to put a switch: the near-plane clip
; is INSIDE FACEFILL, and the scanline filler clips to the screen as it
; goes, one span at a time. The fence became part of the wall.

KEYS    db 128 dup(0)           ; THE KEY TABLE. KBINT writes it, PHYS reads
                                ;  it, and nothing else in the program knows
                                ;  the keyboard exists. One byte a scan code:
                                ;  1 while held, 0 when let go

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

; ---- the node cache TERRPREP fills, and GRIDC reads ------------------------
;  Four hundred and eighty four nodes, three words each: where the node is
;  after the heading has turned it, and how high the ground is there. Not
;  quite three kilobytes, and it buys three rotations out of every four.
TRX     dw TSIDE*TSIDE dup(0)   ; the node, rotated: east of the eye
TRZ     dw TSIDE*TSIDE dup(0)   ; ...and in front of it
TWY     dw TSIDE*TSIDE dup(0)   ; ...and the world height of the ground
TOUT    db TSIDE*TSIDE dup(0)   ; ...and each node's OUTCODE: behind, off
                                ;  the right, off the left, one bit each
TH      db TSIDE*TSIDE dup(0)   ; ...and the RAW map byte, so the drawing
                                ;  loop never touches the map at all

; ---- the drawing order, nearest square first. ORDPREP fills it once -------
TORD    dw NSIDE*NSIDE dup(0)   ; each entry is a slot, ready to use
TEDGE   db NSIDE*NSIDE dup(0)   ; ...and beside each one, the edges that
                                ;  square owns: bit i = corner i to i+1
