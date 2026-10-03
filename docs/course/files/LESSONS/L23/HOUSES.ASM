; ============================================================================
;  HOUSES.ASM - Lesson 17. A TOWN ON THE GROUND.
;
;      FASM HOUSES.ASM HOUSES.COM
;
;      1  the island from above, and the mark where you are about to be
;         standing - which is now five squares short of its biggest town,
;         facing it. SPACE takes off
;      2  the flight, and it does not wait for you
;
;      LEFT / RIGHT  turn, and the world banks into it
;      DOWN          nose up. UP puts it down - it is a control column
;      N             night, and N again for day
;      F             FAST or CLASSIC arithmetic
;      SPACE         after a crash: another aeroplane
;      ESC           land
;
;  WHAT IS NEW: HOUSES. A block of sixteen - four streets by four - stands
;  on every flat square of sand or grass that the town plan does not keep
;  as a park. Each is a box: two walls you can see and a roof when you are
;  over it, their outlines a shade darker than their paint, and two windows
;  a storey on every wall you look at.
;
;  AND FOUR THINGS THE HOUSES FORCED, which are the real lesson:
;
;  ONE: THE SCALE. A house on a square of lesson 16's size would be one
;  house to a hill. So everything the aeroplane is measured against - the
;  houses, the storeys, the heights of the hills - is halved, and the
;  squares of the island are twice the size they were beside it. Not the
;  squares themselves: 64 of them at 1024 is 65536, EXACTLY ONE WORD, and
;  squares of 2048 would need a seventeenth bit for every position.
;
;  TWO: THE POSITION GOT A FRACTION. The aeroplane moves eleven units a
;  frame, and on a gentle heading the sideways part of that is less than
;  one. A word has no room for less than one. So a BYTE of 1/256ths sits
;  beside each coordinate, and the carry out of it goes into the word with
;  ADC - the 8086's own way of adding numbers wider than its registers.
;  ADC is new in this lesson; its box is in PHYS.
;
;  THREE: THE WINDOWS ARE ALWAYS THE RIGHT SIZE. A pane is drawn exactly
;  as big as it is on the screen, measured on the wall's own projected
;  corners with the perspective corrected - so a far window is one lit
;  pixel, and it grows into a pane a pixel at a time as you close in.
;  Nothing switches at a distance, and nothing pops.
;
;  FOUR: NIGHT IS NOTHING BUT THE DAC. N writes eighty one colour bytes
;  to it and redraws nothing. Every pixel keeps its number; the chip between
;  the frame buffer and the monitor is told that the numbers mean other
;  colours now. By day windows 35 and 36 are the same dark glass. By night
;  35 is a lit room and 36 is nobody home.
;
;  THE PHYSICAL FACT THIS LESSON HANDS OVER:
;
;      THE WORLD IS AS BIG AS THE REGISTER. The island is 65536 units
;      across because that is what sixteen wires count to, and every
;      decision about the town - how big a house is, how fast you fly,
;      how the eye finds its own square - was made inside that word. And
;      when the arithmetic needs more than a register holds, the machine
;      has an answer built into its silicon: a CARRY flag, and ADC.
;
;  WHAT IT COSTS, measured in DOSBox at 30000 cycles with the retrace wait
;  ON - so the rate steps down whole retraces at a time, 23, 17, 14:
;
;      bare ground, twenty four nodes of it           23 frames a second
;      over the densest town, windows lit             14 to 17
;
;  and measured one part at a time over a parked town: the houses take
;  the rate from 23 to 17, and the windows from 17 to 14 - one retrace
;  each. The outlines cost less than one. The boxes themselves - four
;  corners, two walls, a roof, each through the near clip and the
;  projection - are where most of the time goes.
;
;  THE SOURCE TRAVELS. This file started as a copy of LESSONS\L22\FILL.ASM,
;  and everything lesson 16 built is still here, unchanged: the painter,
;  the crash, the circle, the outcodes, each edge drawn once. The flight
;  model and the keyboard are lesson 14's; REMOTE is the window into INT 9
;  that the recording uses to fly it.
;
;  WHAT IS BORROWED FROM THE GAME AND THE ENGINE:
;
;      ENGINE\E_8086.INC   keeps FASM inside the 8086 instruction set
;      ENGINE\E_MATH.INC   RND16, the congruential draw of lesson 0x11
;      ENGINE\E_TERR.INC   DSGEN, HGET and WORLDH - the island
;      ENGINE\E_M3D.INC    SETTRIG, ROTXZ, PROJPT - the camera
;      ENGINE\E_RAST.INC   FACEFILL, SCANPOLY, STROKEPOLY, LINE - the paint
;
;  and out of GAMES\OWLFLY3\SRC: FACEV and FACETOPC (WORLD2.INC), the wall
;  test of VISFILL and the box of ROTCUL (WORLD.INC), and the two rules
;  of WINFACEF (TOWN.INC) - a pane lies ON the wall, and the decision is
;  made once per wall. Open them and read along.
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
SPAWNUP = 150                 ; how far ABOVE the highest point of the whole
                              ;  island the aeroplane appears, on an island
                              ;  with no town to fly at. Not above the
                              ;  ground under it - above the WORST ground
                              ;  there is, so no run can start inside a
                              ;  mountain however the dice fell
TOWNUP  = 300                 ; ...but TOWNSPOT puts you this far above the
                              ;  tallest ground on the way into a town...
TOWNBACK = 5                  ; ...this many squares short of it
CEILUP  = 1200                ; ...and how far above it the ceiling sits, so
                              ;  there is somewhere to climb to

; ---- the flight model. Every one of these is CITY.ASM's, and the three
;      that measure a DISTANCE are multiplied by four, because the game's
;      world is built on a 256-unit cell and this lattice on a 1024-unit
;      node. The three that measure an ANGLE are not touched: a circle is
;      256 steps here and 256 steps there.
; ---- THE SCALE. A whole block of sixteen houses stands in one square of
;      the lattice, and the aeroplane is smaller than one house. So
;      everything that the aeroplane is measured against - the houses,
;      the storeys, the hills - is divided down, and the squares of the
;      island are twice the size they were beside it. The aeroplane is NOT
;      slowed - it is FASTER: eleven units a frame, about twenty frames a
;      second, a square in five seconds and the whole map (65536 units) in
;      five minutes. It is the town that is small.
;
;      Why not simply make the squares bigger? Because the map is 64
;      squares of 1024 and that is 65536 - exactly one word. Squares of
;      2048 need a seventeenth bit for every position on the island. So
;      the island stays the size a word can hold, and everything ELSE -
;      the aeroplane, the houses, the storeys, the heights of the hills -
;      is halved. To the eye it is the same thing.
SPEEDV  = 11                  ; forward units a frame. There is no throttle.
                              ;  STEPXZ's step is hsin*SPEEDV in 256ths: at
                              ;  most 2816, and its high byte - 11 - is what
                              ;  PHYS adds as whole units. Up to 127 fits
STEPY   = 22                   ; climb/dive units a frame - twice the
                              ;  forward speed, so a dive is steep enough to
                              ;  reach the town before the coffee goes cold
CAMYCL  = 48                  ; HOW CLOSE TO THE GROUND you may get. Not a
                              ;  height any more - a clearance, measured
                              ;  from whatever happens to be underneath.
                              ;  One and a half storeys

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
RH      = 6                   ; THE TOWN'S REACH, in squares: the ones HOUSES4
                              ;  looks at. The ground goes on to NR; past the
                              ;  town it is a landscape without people
HFULL   = 3072                ; a house nearer than this has all its storeys;
HMAX    = 4096                ;  between the two it rises out of the ground,
                              ;  and past HMAX it is not built. Three squares
                              ;  of town and one of horizon
FLOORH  = 32                  ; one storey, in world units. A house is two
                              ;  sixteenths of a square wide, 128, so four
                              ;  storeys make a cube
FLATH   = 6                   ; a square is flat enough to build on if its
                              ;  four corners differ by at most six map steps.
                              ;  Gentle slopes get houses: their walls follow
                              ;  the ground down - see HOUSES4
WMINPX  = 3                   ; a wall narrower or lower than this many
                              ;  pixels on the screen gets no windows
SKY     = 16                  ; THE SKY'S COLOUR NUMBER. Every frame starts
                              ;  as a sheet of it; the DAC says what it is
BACKOFF = 64                 ; how far the camera steps back on a crash.
                              ;  The game's is 100 on a 256-unit cell; ours
                              ;  is a 1024-unit node, so four times it
VEXAG   = 0                   ; 0: the game's own heights. Lesson 16
                              ;  doubled them for the look of the thing;
                              ;  with houses standing on the hills there is
                              ;  a ruler in every picture now, and halving
                              ;  the hills is part of halving everything
                              ;  but the island - see THE SCALE
TURNV   = 1                   ; heading change a frame, of 256 = a whole
                              ;  turn: twelve seconds for a circle, and the
                              ;  smallest step a byte of heading has
BANKMAX = 30                  ; how far it leans into a turn, of 256
BANKSTP = 3                   ; and how fast it gets there - and back

; ---- scan codes. Not ASCII: these are what the keyboard hardware itself
;      sends, and what KBINT stores. A released key arrives as the same
;      number with bit 7 set.
SC_ESC  = 01h
SC_SP   = 39h
SC_F    = 21h
SC_N    = 31h
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
        call TOWNSPOT           ; townspot()  - and where its biggest town
                                ;  is: that is where you will fly in

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
        call DAYNIGHT           ; daynight() - the palette, day to start
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

        ; ---- N: day or night, ON THE WAY DOWN, like F ---------------------
        ; Before the wreck test on purpose: night falls on a crash site too.
        cmp  byte [KEYS+SC_N],0 ; is N held?
        je   .nup               ;   no: remember that
        cmp  byte [nwas],0      ; held last frame too?
        jne  .nok               ;   yes: one press, one change
        xor  byte [night],1     ; night ^= 1
        call DAYNIGHT           ; daynight(): the DAC, and nothing else
        mov  byte [nwas],1      ; nwas = 1
        jmp  .nok
.nup:   mov  byte [nwas],0      ; nwas = 0: the next press counts
.nok:

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
        call STEPXZ             ; wdx, wdz = one frame's travel, in 1/256s

        ; ---- THE POSITION HAS A FRACTION, AND IT IS ONE BYTE --------------
        ; camx is a word and the map is exactly one word wide, so it stays a
        ; word. What it gains is camxf, a BYTE of 1/256ths beside it. The
        ; step splits in two: its low byte goes into the fraction, its high
        ; byte - sign and all - into the whole units, and the CARRY out of
        ; the fraction is added in on the way. That is ADC, add with carry:
        ; the 8086's own way of doing sums wider than its registers, one
        ; register's worth at a time.
        ;
        ;   +--------------------------------------------------------------+
        ;   | ADC dest,src     ADD WITH CARRY: dest = dest + src + CF       |
        ;   |                                                              |
        ;   |   the example   camxf = 200, the fraction step BL = 100      |
        ;   |                 add [camxf],bl   200+100 = 300: the byte     |
        ;   |                                  keeps 44 and CF = 1         |
        ;   |                 adc [camx],ax    camx += AX, and +1 more     |
        ;   |                 44/256 + 1 whole = 300/256. Nothing lost.    |
        ;   |   flags         sets CF, ZF, SF, OF exactly as ADD does -    |
        ;   |                 and READS CF first. That is the only thing   |
        ;   |                 that makes it different from ADD             |
        ;   |   touches       dest, and the carry flag, and nothing else   |
        ;   |   the trap      NOTHING between the ADD and the ADC may      |
        ;   |                 change CF. MOV and INC do not; ADD, SUB,     |
        ;   |                 CMP, SHR all do. Put a CMP between these two |
        ;   |                 lines and the carry is a different carry     |
        ;   |   and negative  a step of -66/256 is FFBEh: the low byte BEh |
        ;   |                 is +190/256 and the high byte FFh is -1, and |
        ;   |                 -1 + 190/256 is -66/256. Two's complement    |
        ;   |                 splits across the bytes and adds back whole  |
        ;   +--------------------------------------------------------------+
        ;
        ; Without it: at 11 units a frame, heading 1 - one step of the
        ; stick - has hsin = 6 and hcos = 256. The step is 6*11 = 66/256 of
        ; a unit east and exactly 11 north, and a word keeps 0 and 11. The
        ; aeroplane turns and flies straight on; and at heading 10 it
        ; flies 3 degrees off where its nose points. With it, the 66 piles
        ; up in camxf and comes out as one whole unit every four frames
        ; or so, exactly.
        mov  ax,[wdx]           ; AX = the step east, in 1/256ths
        mov  bl,al              ; BL = its low byte: the fraction
        mov  al,ah              ; AL = its high byte: the whole units...
        cbw                     ; AX = ...with the sign carried up: wdx >> 8
        add  [camxf],bl         ; the fraction accumulates; past 255 it sets CF
        adc  [camx],ax          ; camx += whole units + CF
        mov  ax,[wdz]           ; the same, north
        mov  bl,al              ; BL = the fraction
        mov  al,ah              ; AL = the whole units
        cbw                     ; AX = wdz >> 8, signed
        add  [camzf],bl         ; fraction += BL
        adc  [camz],ax          ; camz += whole units + CF
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
;  TOWNSPOT - where the aeroplane appears: looking at the biggest town.
;
;  Lesson 16 put you above the tallest point of the island, because the
;  island was all there was to see. Now there are towns, and a town is
;  where the lesson is - so the program FINDS one before you take off.
;
;  THREE QUESTIONS, THE SAME ONES HOUSES4 ASKS. A square gets houses when
;  its tallest corner is sand or grass, its corners are within FLATH steps
;  of each other, and its hash is not a park. BUILT asks them of one
;  square, straight off the map, and the first pass writes the answer for
;  all 4096 squares into TOWNB: a map of the town plan, one byte a square.
;
;  THE SECOND PASS counts, for every square, how many of the nine squares
;  round it are built - and keeps the square with the most. That is the
;  middle of the biggest town. Four thousand and ninety six times nine, and
;  it runs once: at the boot, and never again.
;
;  THE SPOT. TOWNBACK squares south of it, facing north - heading nought -
;  so the town is straight ahead and rises out of the ground as you come.
;  And high enough: TOWNUP above the tallest ground anywhere on the way,
;  from three squares behind the start to two past the town. Nothing on
;  that line can reach you unless you dive.
;
;  An island with no town at all - they happen - falls back on lesson 16's
;  rule: node 32, 26, above the tallest point.
; ============================================================================
;  In C:
;
;      void townspot(void)
;      {
;          for (gi = 0; gi < 64; gi++) for (gj = 0; gj < 64; gj++)
;              TOWNB[gi*64 + gj] = built(gi, gj);
;          tbest = 0;
;          for every square (gi, gj):
;              n = the sum of TOWNB over the nine round it, wrapping;
;              if (n > tbest) { tbest = n; tgi = gi; tgj = gj; }
;          if (tbest == 0) { townx = 32*1024; townz = 26*1024;
;                            towny = camy0; return; }
;          tmax = the tallest map byte on the way in;
;          towny = (worldh(tmax) << VEXAG) + TOWNUP;
;          townx = tgi * 1024 - BIAS + 512;                /* the middle  */
;          townz = (tgj - TOWNBACK) * 1024 - BIAS + 512;   /*  of a square */
;      }
TOWNSPOT:
        xor  di,di              ; DI = gi*64 + gj: the square's index
        mov  word [gi],0        ; gi = 0
.bi:    mov  word [gj],0        ; gj = 0
.bj:    call BUILT              ; CF = 0: houses stand here
        mov  al,0               ; AL = 0 (MOV leaves CF alone)
        jc   .st                ;   not built: 0
        mov  al,1               ;   built: 1
.st:    mov  [TOWNB+di],al      ; TOWNB[index] = it
        inc  di                 ; the next square: gj + 1 is index + 1
        inc  word [gj]
        cmp  word [gj],64
        jb   .bj
        inc  word [gi]
        cmp  word [gi],64
        jb   .bi

        mov  word [tbest],0     ; ---- the second pass: the biggest town ---
        mov  word [gi],0
.ci:    mov  word [gj],0
.cj:    mov  word [tcnt],0      ; tcnt = built squares round this one
        mov  bx,-1              ; BX = -1, 0, +1: east-west
.na:    mov  dx,-1              ; DX = -1, 0, +1: north-south
.nb:    mov  ax,[gi]
        add  ax,bx              ; AX = gi + BX...
        and  ax,63              ; ...wrapped: the island is a torus
        mov  cl,6
        shl  ax,cl              ; AX = its row of TOWNB, 64 bytes a row
        mov  si,[gj]
        add  si,dx              ; SI = gj + DX...
        and  si,63              ; ...wrapped
        add  si,ax              ; SI = the neighbour's index
        mov  al,[TOWNB+si]      ; AL = built or not
        xor  ah,ah
        add  [tcnt],ax          ; tcnt += it
        inc  dx
        cmp  dx,1
        jle  .nb
        inc  bx
        cmp  bx,1
        jle  .na
        mov  ax,[tcnt]          ; AX = the count
        cmp  ax,[tbest]         ; more than the best so far?
        jle  .nx                ;   no
        mov  [tbest],ax         ;   yes: the new biggest town
        mov  ax,[gi]
        mov  [tgi],ax
        mov  ax,[gj]
        mov  [tgj],ax
.nx:    inc  word [gj]
        cmp  word [gj],64
        jb   .cj
        inc  word [gi]
        cmp  word [gi],64
        jb   .ci

        cmp  word [tbest],0     ; a town at all?
        jne  .town
        mov  word [townx],32*1024   ; no: lesson 16's spot
        mov  word [townz],26*1024
        mov  ax,[camy0]
        mov  [towny],ax
        ret

.town:  mov  byte [tmax],0      ; ---- the tallest ground on the way in ----
        mov  bx,-1              ; three squares wide...
.ha:    mov  dx,-TOWNBACK-3     ; ...from behind the start to past the town
.hb:    push bx
        push dx
        add  bx,[tgi]           ; BX = the square east-west
        add  dx,[tgj]           ; DX = north-south; HGET wraps them both
        call HGET               ; AL = its map byte
        pop  dx
        pop  bx
        cmp  al,[tmax]          ; taller?
        jbe  .hn
        mov  [tmax],al          ;   yes: keep it
.hn:    inc  dx
        cmp  dx,2
        jle  .hb
        inc  bx
        cmp  bx,1
        jle  .ha
        mov  al,[tmax]          ; AL = the tallest byte on the way
        xor  ah,ah
        call WORLDH             ; AX = in world units...
        mov  cl,VEXAG
        shl  ax,cl              ; ...the way the ground is drawn
        add  ax,TOWNUP          ; AX += the room above it
        mov  [towny],ax         ; towny = where you fly in

        mov  ax,[tgi]           ; AX = the town's square, east-west
        mov  cl,10
        shl  ax,cl              ; AX = its node, in world units
        sub  ax,BIAS-512        ; AX -= BIAS, and half a square on: the middle
        mov  [townx],ax         ; townx = straight south of the town
        mov  ax,[tgj]           ; AX = its square, north-south
        sub  ax,TOWNBACK        ; AX = TOWNBACK squares south of it
        mov  cl,10
        shl  ax,cl              ; in world units - and a word wraps with the
        sub  ax,BIAS-512        ;  island, so south of row 0 is row 63
        mov  [townz],ax         ; townz = the start
        ret

; ---- BUILT: CF = 0 if square (gi, gj) gets houses. HOUSES4's three
;      questions, asked of the map instead of the cache. Keeps DI.
BUILT:  mov  bx,[gi]            ; BX = gi   \  HGET wants x in BX, y in DX,
        mov  dx,[gj]            ; DX = gj   /  and wraps them itself
        call HGET               ; AL = corner 0's map byte
        mov  ah,al              ; AH = the highest so far
        mov  ch,al              ; CH = the lowest (HGET only touches CL)
        inc  bx                 ; corner 1: east
        call HGET
        call .mm
        inc  dx                 ; corner 2: east and north
        call HGET
        call .mm
        dec  bx                 ; corner 3: north
        call HGET
        call .mm
        cmp  ah,88              ; the tallest corner in the sea?
        jb   .no
        cmp  ah,168             ; ...or above the grass?
        jae  .no
        sub  ah,ch              ; AH = how much it slopes
        cmp  ah,FLATH           ; too steep?
        ja   .no
        mov  ax,[gi]            ; ---- and the hash: a park? ----
        and  ax,63
        mov  cl,6
        shl  ax,cl              ; AX = gi*64
        mov  bx,[gj]
        and  bx,63
        add  ax,bx              ; AX = the square's map index
        mov  bx,25173           ; the generator, as in HOUSES4
        mul  bx
        add  ax,13849
        test ah,0C0h            ; top two bits nought: a park
        jz   .no
        clc                     ; CF = 0: built
        ret
.no:    stc                     ; CF = 1: not
        ret
.mm:    cmp  al,ch              ; AL below the lowest?
        jae  .m1
        mov  ch,al
.m1:    cmp  al,ah              ; above the highest?
        jbe  .m2
        mov  ah,al
.m2:    ret

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
        mov  ax,[townx]             ; camx = south of the town  \  the same
        mov  [camx],ax              ;                            > spot every
        mov  ax,[townz]             ; camz = TOWNBACK squares    > time, so a
        mov  [camz],ax              ;  short of it              /  crash is
        mov  ax,[towny]             ; camy = above everything  /  about the
        mov  [camy],ax              ;  on the way in          /   ground
        mov  word [heading],0       ; heading = 0: north, at the town
        mov  word [roll],0          ; roll = 0: wings level
        mov  word [turn],0          ; turn = 0: the stick is centred
        mov  byte [dying],0         ; dying = 0: flying again
        mov  byte [camxf],0         ; and the fractions: a reset that
        mov  byte [camzf],0         ;  forgets one number is no reset
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
STEPXZ: mov  ax,[hsin]          ; AX = hsin: the sine, times 256
        mov  bx,SPEEDV          ; BX = SPEEDV
        imul bx                 ; AX = hsin * SPEEDV. NOT divided by 256: this
                                ;  is the step in 1/256 of a unit, and the
                                ;  low byte of it is the part the old divide
                                ;  threw away. On a gentle heading that part
                                ;  is most of the sideways answer
        mov  [wdx],ax           ; wdx = AX       (it fits: 256*11 = 2816)
        mov  ax,[hcos]          ; AX = hcos
        imul bx                 ; AX = hcos * SPEEDV
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
        mov  es,ax              ; ES = bufseg           \  memset(buf,SKY,64000):
        xor  di,di              ; DI = 0                 > 32000 words of
        mov  ax,SKY*257         ; AX = SKY in both bytes/  SKY, by STOSW. The
                                ;  ground covers the bottom; what is left
                                ;  showing at the top is the sky
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
        call HPREP              ; hprep(): a sixteenth of a square, turned, and
                                ;  where the eye is inside its own square

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
        mov  al,[COLOR]         ; AL = it
        mov  [qband],al         ; qband = it, before the fold below changes
                                ;  COLOR: the houses ask sand or grass

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
        jmp  .house             ; and on to its houses

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


        ; ---- AND ITS HOUSES, straight after its own ground -----------------
        ; This is the whole of how the houses join the painter. A square's
        ; houses stand ON it, so they go down after its ground and its
        ; seams, and before every square nearer the eye - which will paint
        ; over them exactly where the nearer ground is really in front.
        ; Nothing is sorted that was not sorted already.
.house: mov  ax,[ordk]          ; AX = this square's place in the order
        cmp  ax,[ordhouse]      ; inside the town's circle, RH?
        jae  .skip              ;   no: bare ground
        call HOUSES4            ; houses4(): up to sixteen, far ones first

.skip:  ret                     ; return - to the loop, one square on

; ============================================================================
;  HPREP - the two things every house on the screen needs, once a frame.
;
;  A SIXTEENTH OF A SQUARE, TURNED. A square holds a block of four by four
;  houses, and their corners lie at sixteenths of its sides: the first
;  house from 1/16 to 3/16, the next from 5/16 to 7/16, and so on. The
;  square's own corner is in the cache already, turned by the heading. And
;  rotating is LINEAR - turn a step and add, or add and turn, the answer is
;  the same - so "k sixteenths along" is corner 0 plus k times one turned
;  sixteenth. One ROTXZ for the whole east side of a square, one for the
;  north side, and every house corner on the screen after that is two
;  table reads and two adds. Not one rotation per house.
;
;      HAX[k], HAZ[k]   k/16 of a square EAST,  turned: its x and its z
;      HBX[k], HBZ[k]   k/16 of a square NORTH, turned
;
;  WHERE THE EYE IS IN ITS SQUARE. The walls a house shows you depend on
;  which side of it you are, and that is decided in the WORLD, before any
;  turning: west of its west wall, you see the west wall. OWL FLY III's
;  VISFILL compares camx with the wall's world x. Here the world is sixty
;  four squares of 1024 - exactly the 65536 a word counts - so a world x
;  WRAPS, and the same comparison on either side of the seam comes out
;  backwards. So everything is measured from the square's own corner
;  instead: hfx is how far into its square the eye stands, 0..1023, and a
;  square da squares east of that is fx - da*1024 away. Small numbers, and
;  no seam anywhere.
; ============================================================================
;  In C:
;
;      void hprep(void)
;      {
;          hfx = (camx + BIAS) & 1023;       /* the eye, inside its square */
;          hfz = (camz + BIAS) & 1023;
;          rotxz(1024, 0);  for (k = 0; k <= 16; k++) HAX[k] = k*rc_x >> 4,
;                                                     HAZ[k] = k*rc_z >> 4;
;          rotxz(0, 1024);  for (k = 0; k <= 16; k++) HBX[k] = k*rc_x >> 4,
;                                                     HBZ[k] = k*rc_z >> 4;
;      }
HPREP:  mov  ax,[camx]          ; AX = camx
        add  ax,BIAS            ; AX = camx + BIAS: the same count TERRPREP
        and  ax,1023            ;  shifted by ten - and the ten bits it threw
        mov  [hfx],ax           ;  away are where in the square the eye is
        mov  ax,[camz]          ; AX = camz
        add  ax,BIAS            ; AX = camz + BIAS
        and  ax,1023            ; AX &= 1023
        mov  [hfz],ax           ; hfz = AX

        mov  word [wdx],1024    ; one whole square east...
        mov  word [wdz],0
        call ROTXZ              ; ...turned by the heading
        mov  ax,[rc_x]          ; AX = its x
        mov  di,HAX             ; DI = the table for it
        call HMUL               ; HAX[k] = k/16 of it
        mov  ax,[rc_z]          ; AX = its z
        mov  di,HAZ
        call HMUL               ; HAZ[k] = k/16 of it
        mov  word [wdx],0       ; one whole square north...
        mov  word [wdz],1024
        call ROTXZ              ; ...turned
        mov  ax,[rc_x]
        mov  di,HBX
        call HMUL               ; HBX[k]
        mov  ax,[rc_z]
        mov  di,HBZ
        call HMUL               ; HBZ[k]
        ret                     ; return

; ---- HMUL: DI = seventeen words, AX = a whole square's step. DI[k] = k*AX/16
;  Multiplying by counting up: add the step each time round, and divide
;  the running total by sixteen - four SARs, sign kept. Sixteen times a
;  square is 16384, still inside a word. Seventeen entries: k runs 0..16.
HMUL:   mov  bx,ax              ; BX = the step
        xor  ax,ax              ; AX = 0: the running total, k*step
        mov  cx,17              ; CX = seventeen entries
.k:     mov  dx,ax              ; DX = k*step
        sar  dx,1               ; DX /= 2
        sar  dx,1               ; DX /= 4
        sar  dx,1               ; DX /= 8
        sar  dx,1               ; DX /= 16, and SAR keeps the sign
        mov  [di],dx            ; DI[k] = k*step/16
        add  di,2               ; the next word
        add  ax,bx              ; AX += step: (k+1)*step
        loop .k                 ; seventeen times
        ret                     ; return

; ============================================================================
;  HOUSES4 - the block of houses on one square, if it has one.
;
;  THE SCALE. A whole block - four streets by four, sixteen houses - stands
;  in ONE square of the lattice: the square is 1024, a house is 128 with
;  128 of street round it. Lesson 16's hills are drawn with squares that
;  size; a town drawn with them would be one house to a hill. That is why
;  the aeroplane shrank in this lesson - the island did not grow, the town
;  is small, and the eye is down among it.
;
;  WHICH SQUARES. Nobody builds in the sea or up a mountain, and not on
;  a cliff: a square gets houses when its band is sand or grass and its
;  four corners are within FLATH map steps of each other. And then not
;  always - a quarter of the squares are left empty, parks, by a HASH.
;
;  THE HASH. The same square must look the same every frame, and the map
;  has no room for a town plan. So the square's own coordinates are
;  shuffled into a number: gi*64 + gj is its index in the map, and one
;  step of the generator lesson 0x11 grew the island with - times 25173,
;  plus 13849 - scrambles it. The top two bits say park or not; every
;  house then shuffles its own number out of this one - see HOUSE. No
;  storage, no flicker: the town is a function of where you are.
;
;  THE ORDER. Sixteen houses on a square are still a painter's problem,
;  and it is solved one axis at a time. The four columns are put in order
;  of how far their middles are from the eye east-west, farthest first;
;  the four rows the same north-south; and the houses are drawn column by
;  column, row by row. It works because the houses stand in a GRID: two
;  houses in different columns have a wall of empty street between them,
;  and the one on the far side of that street can never cover the one on
;  the near side. If the eye stands between two columns, they are on
;  opposite sides of it and cannot cover each other at all.
; ============================================================================
;  In C:
;
;      void houses4(void)
;      {
;          if (qband != 2 && qband != 3) return;          /* sand, grass */
;          slot = TORD[ordk];
;          if (max(TH[4 corners]) - min(TH[4 corners]) > FLATH) return;
;          ground_lattice();                              /* GY[8][8]    */
;          hc0x = TRX[slot];  hc0z = TRZ[slot];           /* corner 0    */
;          hrx = hfx - TDA[ordk]*1024;                    /* the eye, from */
;          hrz = hfz - TDB[ordk]*1024;                    /*  that corner  */
;          hh = ((camgi+da)&63)*64 + ((camgj+db)&63);
;          hh = hh * 25173 + 13849;
;          if ((hh >> 14) == 0) return;                   /* a park      */
;          hord(hrx, HCOL);  hord(hrz, HROW);             /* far first   */
;          for (i = 0; i < 4; i++) for (j = 0; j < 4; j++)
;              { hc = HCOL[i]; hr = HROW[j]; house(); }
;      }
HOUSES4:
        mov  al,[qband]         ; AL = the square's band
        cmp  al,2               ; sand?
        jb   .x                 ;   below it: the sea. No houses
        cmp  al,3               ; grass?
        ja   .x                 ;   above it: woods, rock, snow. No houses

        mov  bx,[ordk]          ; BX = ordk
        add  bx,bx              ; BX = ordk*2
        mov  si,[TORD+bx]       ; SI = the slot of corner 0
        mov  di,si              ; DI = the slot
        shr  di,1               ; DI /= 2: TH is bytes
        mov  al,[TH+di]         ; AL = the lowest so far
        mov  ah,al              ; AH = the highest so far
        mov  bl,[TH+di+TSIDE]   ; BL = corner 1
        call .mm                ; AL = min, AH = max
        mov  bl,[TH+di+TSIDE+1] ; BL = corner 2
        call .mm
        mov  bl,[TH+di+1]       ; BL = corner 3
        call .mm
        sub  ah,al              ; AH = how much the square slopes
        cmp  ah,FLATH           ; gentle enough to build on?
        ja   .x                 ;   no: a hillside. No houses

        ; ---- THE GROUND UNDER THE HOUSES --------------------------------
        ; A square on a slope is not flat, and one floor for every house
        ; leaves the downhill ones standing on air. So every house corner
        ; gets the height of the ground AT it: the square's four corner
        ; heights, blended by how far along each side the point is. That is
        ; BILINEAR interpolation, and on a lattice of evenly spaced points
        ; it needs no multiply at all - it is linear along each side, and a
        ; linear thing on even steps is a start and a constant step.
        ;
        ; The house corners stand at 1, 3, 5 ... 15 sixteenths each way: an
        ; eight by eight lattice, GY. Heights are taken from corner 0's, so
        ; the numbers stay small, and kept in 256ths - sixteenths of
        ; sixteenths - until the last shift:
        ;
        ;     down the west side    L(b) = d3*b          (in sixteenths)
        ;     down the east side    R(b) = d1*16 + (d2-d1)*b
        ;     across at row b       G(a,b) = (L*16 + (R-L)*a) / 256
        ;
        ; with d1, d2, d3 the other three corners minus corner 0. Every
        ; step of b is two sixteenths, and so is every step of a.
        mov  ax,[TWY+si]        ; AX = corner 0's world height
        mov  bx,[TWY+si+TSIDE*2]    ; BX = corner 1's: east
        sub  bx,ax              ; BX = d1
        mov  cx,[TWY+si+TSIDE*2+2]  ; CX = corner 2's
        sub  cx,ax              ; CX = d2
        mov  dx,[TWY+si+2]      ; DX = corner 3's: north
        sub  dx,ax              ; DX = d3
        sub  ax,[camy]          ; AX = corner 0 from the eye
        mov  [hy0],ax           ; hy0 = it: added back at the end
        mov  [gl],dx            ; L = d3*1: the west side at b = 1
        add  dx,dx              ; DX = 2*d3
        mov  [gls],dx           ; gls = its step
        sub  cx,bx              ; CX = d2 - d1
        mov  ax,bx              ; AX = d1
        shl  ax,1               ; AX = d1*2   \
        shl  ax,1               ; AX = d1*4    \  four single shifts: CL is
        shl  ax,1               ; AX = d1*8    /  busy holding d2 - d1
        shl  ax,1               ; AX = d1*16  /
        add  ax,cx              ; AX = d1*16 + (d2-d1): the east side at b = 1
        mov  [gr],ax            ; R = it
        add  cx,cx              ; CX = 2*(d2-d1)
        mov  [grs],cx           ; grs = its step
        xor  di,di              ; DI = 0: GY's first entry
.gb:    mov  bx,[gr]            ; BX = R
        sub  bx,[gl]            ; BX = R - L
        mov  ax,[gl]            ; AX = L
        mov  cl,4
        shl  ax,cl              ; AX = L*16
        add  ax,bx              ; AX = L*16 + (R-L)*1: a = 1
        add  bx,bx              ; BX = 2*(R-L): the step to a = 3
.ga:    mov  dx,ax              ; DX = the height, in 256ths
        mov  cl,8
        sar  dx,cl              ; DX /= 256, sign kept
        add  dx,[hy0]           ; DX += corner 0: from the eye now
        mov  [GY+di],dx         ; GY[b][a] = DX
        add  ax,bx              ; two sixteenths east
        add  di,2               ; the next entry
        test di,15              ; the end of a row of eight?
        jnz  .ga                ;   no
        mov  ax,[gls]           ; two sixteenths north: both sides step
        add  [gl],ax
        mov  ax,[grs]
        add  [gr],ax
        cmp  di,128             ; eight rows?
        jb   .gb                ;   no

        mov  ax,[TRX+si]        ; AX = corner 0, turned: x
        mov  [hc0x],ax          ; hc0x = it
        mov  ax,[TRZ+si]        ; AX = z
        mov  [hc0z],ax          ; hc0z = it

        ; ---- where the eye is, measured from this square's corner --------
        mov  bx,[ordk]          ; BX = ordk: TDA is bytes
        mov  al,[TDA+bx]        ; AL = da, how many squares east of the eye's
        cbw                     ; AX = da, signed
        mov  dx,ax              ; DX = da
        add  ax,[camgi]         ; AX = the square's map column...
        and  ax,63              ; ...wrapped, like the map
        mov  [hgi],ax           ; hgi = it
        mov  al,dl              ; AL = da
        shl  al,1               ; AL = da*2   \  da*1024 WITHOUT a multiply:
        shl  al,1               ; AL = da*4    > times four in the low byte,
        mov  ah,al              ; AH = da*4    > then move it up a byte, which
        xor  al,al              ; AX = da*1024/ is times 256. |da| < 32 fits
        neg  ax                 ; AX = -da*1024
        add  ax,[hfx]           ; AX = hfx - da*1024
        mov  [hrx],ax           ; hrx = the eye, east of this square's corner
        mov  al,[TDB+bx]        ; the same, north
        cbw
        mov  dx,ax              ; DX = db
        add  ax,[camgj]         ; AX = the square's map row
        and  ax,63
        mov  [hgj],ax           ; hgj = it
        mov  al,dl
        shl  al,1
        shl  al,1
        mov  ah,al
        xor  al,al              ; AX = db*1024
        neg  ax
        add  ax,[hfz]
        mov  [hrz],ax           ; hrz = the eye, north of the corner

        ; ---- the whole square past the town's edge? ----------------------
        ; The circle ORDPREP counted is measured between NODES, and the eye
        ; is not on a node - so the real edge of the town is measured here,
        ; from the eye to the square's middle, less half a diagonal.
        mov  ax,512             ; AX = the middle, east of the corner...
        sub  ax,[hrx]           ; ...less the eye: how far east of the eye
        mov  bx,512
        sub  bx,[hrz]           ; BX = how far north
        call ODIST              ; AX = the distance, near enough
        sub  ax,724             ; less half the square's diagonal
        cmp  ax,HMAX            ; every house on it past the edge?
        jge  .x                 ;   yes: bare ground

        ; ---- the hash: the town plan, worked out on the spot --------------
        mov  ax,[hgi]           ; AX = gi
        mov  cl,6               ; CL = 6
        shl  ax,cl              ; AX = gi*64
        add  ax,[hgj]           ; AX = gi*64 + gj: the square's map index
        mov  bx,25173           ; BX = the generator's multiplier
        mul  bx                 ; AX = index * 25173 (the low word is all
        add  ax,13849           ; AX += 13849  - we keep; DX is thrown away)
        mov  [hh],ax            ; hh = the square's own shuffled number
        test ah,0C0h            ; its top two bits both nought?
        jz   .x                 ;   yes: one square in four is a park

        ; ---- far houses first, one axis at a time -------------------------
        mov  ax,[hrx]           ; AX = the eye, east-west
        mov  di,HCOL            ; DI = the list of columns
        call HORD               ; HCOL = the four columns, farthest first
        mov  ax,[hrz]           ; AX = the eye, north-south
        mov  di,HROW
        call HORD               ; HROW = the four rows, farthest first

        mov  byte [hci],0       ; hci = 0: the farthest column
.cl:    mov  byte [hri],0       ; hri = 0: the farthest row
.rl:    mov  bl,[hci]           ; BL = hci
        xor  bh,bh              ; BX = hci
        mov  al,[HCOL+bx]       ; AL = which column that is
        mov  [hc],al            ; hc = it
        mov  bl,[hri]           ; BX = hri
        mov  al,[HROW+bx]       ; AL = which row
        mov  [hr],al            ; hr = it
        call HOUSE              ; house()
        inc  byte [hri]         ; hri++
        cmp  byte [hri],4       ; all four rows?
        jb   .rl                ;   no
        inc  byte [hci]         ; hci++
        cmp  byte [hci],4       ; all four columns?
        jb   .cl                ;   no
.x:     ret                     ; return

.mm:    cmp  bl,al              ; BL below the lowest?
        jae  .m1
        mov  al,bl              ;   yes: AL = BL
.m1:    cmp  bl,ah              ; BL above the highest?
        jbe  .m2
        mov  ah,bl              ;   yes: AH = BL
.m2:    ret

; ---- ODIST: AX = east, BX = north -> AX = the distance, near enough -------
;  The true distance wants a square root. The octagon does without: the
;  longer of the two plus three eighths of the shorter, never more than
;  about four per cent out - and it only has to say how tall a house far
;  away is, which nobody can measure by eye.
ODIST:  or   ax,ax              ; AX = |east|
        jns  .a
        neg  ax
.a:     or   bx,bx              ; BX = |north|
        jns  .b
        neg  bx
.b:     cmp  ax,bx              ; AX the longer?
        jae  .c
        xchg ax,bx              ;   no: swap them
.c:     shr  bx,1               ; BX = the shorter / 2
        shr  bx,1               ;          / 4
        add  ax,bx              ; AX += a quarter of it
        shr  bx,1               ;          / 8
        add  ax,bx              ; AX += an eighth: three eighths in all
        ret

; ---- HORD: AX = the eye along one axis, from the square's corner; DI = four
;      bytes out: the columns 0..3 in order of distance, FARTHEST FIRST.
;  Column c's middle is at c*256 + 128. The distances along a row of
;  columns go down and then up again - a V, with the eye at the bottom - so
;  the farthest is always one of the two ENDS still left. Take it, and
;  step that end inward. Four steps, no sort.
HORD:   mov  [oeye],ax          ; oeye = the eye
        mov  byte [olo],0       ; olo = the west (or south) end
        mov  byte [ohi],3       ; ohi = the east (or north) end
        mov  cx,4               ; CX = four to place
.o:     mov  al,[olo]           ; AL = the low end
        call .dist              ; AX = how far its middle is from the eye
        mov  bx,ax              ; BX = it
        mov  al,[ohi]           ; AL = the high end
        call .dist              ; AX = its distance
        cmp  ax,bx              ; the high end nearer?
        jb   .lo                ;   yes: the low end goes next
        mov  al,[ohi]           ;   no: the high end
        mov  [di],al            ; out = it
        dec  byte [ohi]         ; and that end steps in
        jmp  .n
.lo:    mov  al,[olo]           ; the low end
        mov  [di],al            ; out = it
        inc  byte [olo]         ; and that end steps in
.n:     inc  di                 ; the next place in the list
        loop .o                 ; four times
        ret                     ; return
.dist:  mov  ah,al              ; AX = c*256 + ...
        mov  al,128             ; ...128: the column's middle
        sub  ax,[oeye]          ; AX = middle - eye
        jns  .d1                ; negative?
        neg  ax                 ;   yes: AX = |it|
.d1:    ret

; ============================================================================
;  HOUSE - one box: four walls, a roof, the windows.
;
;  ITS OWN NUMBER. The square's hash is one word, and sixteen houses need
;  more than a word of choices. So each house mixes its place in the block,
;  hn = column*4 + row, into the square's number and shuffles THAT with
;  the same generator: hs. The top two bits are its storeys, 1 to 4; three
;  more leave one plot in eight empty, a gap in the street.
;
;  THE CORNERS. In the order OWL FLY III's ROTCUL keeps them, so its
;  FACEV and FACETOPC work unchanged:
;
;      3 (a0,b1) ---- 2 (a1,b1)          north up, east right
;        |              |
;      0 (a0,b0) ---- 1 (a1,b0)
;
;  each one corner 0 of the square plus two table reads - see HPREP.
;
;  THE WALLS YOU CAN SEE are decided in the world, not on the screen, and
;  it is four comparisons: west of the west wall, you see the west wall.
;  A box shows you at most two walls and never three, the walls it shows
;  never overlap each other on the screen, and the ones it hides are
;  never drawn at all. No depth sorting inside a box: a CONVEX thing has
;  no inside to get wrong. This is VISFILL, from WORLD.INC, with camx
;  swapped for hrx - see HPREP for why.
;
;  THE ROOF, when the eye is above it: bry1 below nought.
;
;  THE COLOURS. Walls facing east or west are 33, a shade darker than
;  32, the ones facing north and south; so a corner of a house is always
;  two tones and reads as a corner. The roof is 34. And the outline is
;  the same colour folded, +8, like the ground's seams.
; ============================================================================
;  In C:
;
;      void house(void)
;      {
;          hn = hc*4 + hr;
;          hs = (hh + hn*40503) * 25173 + 13849;       /* this house's own */
;          if ((hs & 0x3800) == 0) return;             /* an empty plot    */
;          floors = (hs >> 14) + 1;
;          a0 = hc*4+1; a1 = a0+2; b0 = hr*4+1; b1 = b0+2;   /* sixteenths */
;          FRX[0] = hc0x + HAX[a0] + HBX[b0];  FRZ[0] = ... HAZ, HBZ
;          FRY[0] = GY[b0][a0];   ...and (a1,b0), (a1,b1), (a0,b1)
;          bry0 = max(FRY);  bry1 = bry0 + floors * FLOORH;
;          if (hrx < a0*64) wall(3, 0, 33);                  /* west  */
;          if (hrx > a1*64) wall(1, 2, 33);                  /* east  */
;          if (hrz < b0*64) wall(0, 1, 32);                  /* south */
;          if (hrz > b1*64) wall(2, 3, 32);                  /* north */
;          if (bry1 < 0) { facetopc(); COLOR = 34; facefill(); stroke(); }
;      }
HOUSE:  mov  al,[hc]            ; AL = the column, 0..3
        shl  al,1
        shl  al,1               ; AL = column*4
        add  al,[hr]            ; AL = column*4 + row: 0..15
        mov  [hn],al            ; hn = the house's place in the block
        xor  ah,ah              ; AX = hn
        mov  bx,40503           ; BX = a big odd number, to spread them
        mul  bx                 ; AX = hn * 40503
        add  ax,[hh]            ; AX += the square's number
        mov  bx,25173           ; ...and one step of the generator
        mul  bx
        add  ax,13849
        mov  [hs],ax            ; hs = this house's own number
        test ah,38h             ; three bits, all nought?
        jz   .x                 ;   one plot in eight: nobody built here
        mov  al,ah              ; AL = the top byte
        mov  cl,6               ; CL = 6
        shr  al,cl              ; AL = its top two bits: 0..3
        xor  ah,ah              ; AX = them
        inc  ax                 ; AX = 1..4 storeys
        mov  [hfl],ax           ; hfl = storeys

        mov  al,[hc]            ; AL = the column
        shl  al,1
        shl  al,1               ; AL = column*4
        inc  al                 ; AL = a0, in sixteenths
        xor  ah,ah              ; AX = a0
        add  ax,ax              ; AX = a0*2: a word to a table entry
        mov  [ha0],ax           ; ha0 = it
        add  ax,4               ; two sixteenths on
        mov  [ha1],ax           ; ha1 = a1*2
        mov  al,[hr]            ; the same for the row
        shl  al,1
        shl  al,1
        inc  al
        xor  ah,ah
        add  ax,ax
        mov  [hb0],ax           ; hb0 = b0*2
        add  ax,4
        mov  [hb1],ax           ; hb1 = b1*2

        ; ---- HOW FAR, and THE TOWN'S EDGE -----------------------------------
        ; A town that stops at a radius APPEARS at that radius: fly towards
        ; it and a whole block of houses is suddenly there. So the edge is
        ; soft. Nearer than HFULL a house has all its storeys; between
        ; HFULL and HMAX it has that fraction of them, and at HMAX nothing -
        ; so a house on the horizon rises out of the ground as you come,
        ; over the whole of the last square, and never pops.
        mov  ax,[ha0]           ; AX = a0*2
        mov  cl,5
        shl  ax,cl              ; AX = a0*64: the west wall
        add  ax,64              ; AX = the house's middle, east of the corner
        sub  ax,[hrx]           ; AX = how far east of the eye
        mov  bx,[hb0]
        shl  bx,cl
        add  bx,64
        sub  bx,[hrz]           ; BX = how far north
        call ODIST              ; AX = the distance
        mov  [hd],ax            ; hd = it
        cmp  ax,HMAX            ; past the edge?
        jge  .x                 ;   yes: not built yet

        mov  si,[ha0]           ; corner 0 = (a0, b0)
        mov  bx,[hb0]
        xor  di,di
        call HCORN
        mov  si,[ha1]           ; corner 1 = (a1, b0)
        mov  bx,[hb0]
        mov  di,2
        call HCORN
        mov  si,[ha1]           ; corner 2 = (a1, b1)
        mov  bx,[hb1]
        mov  di,4
        call HCORN
        mov  si,[ha0]           ; corner 3 = (a0, b1)
        mov  bx,[hb1]
        mov  di,6
        call HCORN

        ; ---- THE HOUSE'S OWN CULL - the ground's, one size smaller --------
        ; The square passed DRAWQUAD's test, but a square that is half on
        ; the screen has half its sixteen houses off it. Same three bits
        ; as TERRPREP's - behind, off the right, off the left - for the
        ; four corners of the footprint, and the same AND. The side planes
        ; stand upright, so the footprint decides for the whole house.
        mov  dl,7               ; DL = every plane, until a corner is inside
        xor  di,di              ; DI = corner 0
.oc:    xor  al,al              ; AL = this corner's code
        mov  bx,[FRZ+di]        ; BX = z
        cmp  bx,NEARZ           ; behind the near plane?
        jge  .o0
        or   al,1
.o0:    mov  cx,bx              ; CX = z
        sar  cx,1
        sar  cx,1               ; CX = z/4
        sub  bx,cx              ; BX = 3z/4
        mov  cx,[FRX+di]        ; CX = x
        cmp  cx,bx              ; off the right?
        jle  .o1
        or   al,2
.o1:    neg  bx                 ; BX = -3z/4
        cmp  cx,bx              ; off the left?
        jge  .o2
        or   al,4
.o2:    and  dl,al              ; DL &= it
        add  di,2               ; the next corner
        cmp  di,8
        jb   .oc
        or   dl,dl              ; a plane all four are outside?
        jnz  .x                 ;   yes: not one pixel of it can show

        ; ---- the floor is the HIGHEST of the four; the roof is on that ----
        ; The walls go down to the ground at each corner - FACEV takes their
        ; bottoms from FRY - but the storeys are counted from the top of
        ; the slope, so the house on a hillside gets a taller wall on its
        ; downhill side, and the windows stay out of the grass.
        mov  ax,[FRY]           ; AX = corner 0's ground
        cmp  ax,[FRY+2]
        jge  .f1
        mov  ax,[FRY+2]
.f1:    cmp  ax,[FRY+4]
        jge  .f2
        mov  ax,[FRY+4]
.f2:    cmp  ax,[FRY+6]
        jge  .f3
        mov  ax,[FRY+6]
.f3:    mov  [bry0],ax          ; bry0 = the floor
        mov  ax,[hfl]           ; AX = storeys
        mov  cl,5               ; CL = 5
        shl  ax,cl              ; AX = storeys * FLOORH, which is 32
        mov  bx,HMAX            ; BX = the edge
        sub  bx,[hd]            ; BX = how far inside it this house is
        cmp  bx,HMAX-HFULL      ; the whole last square or more?
        jge  .tall              ;   yes: every storey
        shr  bx,1               ; BX /= 4: 0..255, so that the product
        shr  bx,1               ;  below fits a word - 128 * 255
        mul  bx                 ; AX = the height * how far in, /4
        mov  al,ah              ; AX /= 256: altogether / 1024, which is
        xor  ah,ah              ;  HMAX - HFULL. The height, risen this far
.tall:  add  ax,[bry0]          ; AX += the floor
        mov  [bry1],ax          ; bry1 = the roof, from the eye

        ; ---- VISFILL: the walls this side of the house --------------------
        mov  ax,[ha0]           ; AX = a0*2
        mov  cl,5               ; CL = 5
        shl  ax,cl              ; AX = a0*64: the west wall, from the corner
        cmp  [hrx],ax           ; the eye west of it?
        jge  .e                 ;   no
        mov  byte [COLOR],33    ; west: the shaded pair
        mov  word [fa],3        ; corners 3 and 0
        mov  word [fb],0
        call HWALL
.e:     mov  ax,[ha1]
        mov  cl,5
        shl  ax,cl              ; AX = a1*64: the east wall
        cmp  [hrx],ax           ; the eye east of it?
        jle  .s
        mov  byte [COLOR],33    ; east
        mov  word [fa],1
        mov  word [fb],2
        call HWALL
.s:     mov  ax,[hb0]
        mov  cl,5
        shl  ax,cl              ; AX = b0*64: the south wall
        cmp  [hrz],ax
        jge  .n
        mov  byte [COLOR],32    ; south: the lit pair
        mov  word [fa],0
        mov  word [fb],1
        call HWALL
.n:     mov  ax,[hb1]
        mov  cl,5
        shl  ax,cl              ; AX = b1*64: the north wall
        cmp  [hrz],ax
        jle  .r
        mov  byte [COLOR],32    ; north
        mov  word [fa],2
        mov  word [fb],3
        call HWALL

.r:     cmp  word [bry1],0      ; the roof below the eye?
        jge  .x                 ;   no: it cannot be seen
        call FACETOPC           ; IX/IY/IZ = the roof
        mov  byte [COLOR],34    ; COLOR = the roof
        call FACEFILL           ; fill it
        cmp  word [NPOLY],3     ; anything left of it?
        jl   .x
        add  byte [COLOR],8     ; COLOR = the roof, folded
        call STROKEPOLY         ; its outline
.x:     ret                     ; return

; ---- HCORN: FRX/FRZ[DI] = corner 0 + SI sixteenths east + BX north --------
;      ...and FRY[DI] = the ground at that point. SI = a*2, BX = b*2
HCORN:  mov  ax,[HAX+si]        ; AX = so many sixteenths east, turned: x
        add  ax,[HBX+bx]        ; AX += so many north, turned: x
        add  ax,[hc0x]          ; AX += the square's corner
        mov  [FRX+di],ax        ; FRX[corner] = AX
        mov  ax,[HAZ+si]        ; the same for z
        add  ax,[HBZ+bx]
        add  ax,[hc0z]
        mov  [FRZ+di],ax        ; FRZ[corner] = AX
        shl  bx,1               ; ---- and the ground under it, from GY:
        shl  bx,1               ; BX = b*8
        sub  bx,8               ; BX = (b-1)*8: row (b-1)/2, sixteen bytes
        shr  si,1               ; SI = a
        dec  si                 ; SI = a-1: column (a-1)/2, two bytes each
        add  bx,si              ; BX = the entry
        mov  ax,[GY+bx]         ; AX = the ground there, from the eye
        mov  [FRY+di],ax        ; FRY[corner] = AX
        ret                     ; return

; ============================================================================
;  FACEV and FACETOPC - out of GAMES\OWLFLY3\SRC\WORLD2.INC, and ONE
;  change: the game's FACEV puts both bottoms at bry0, a flat floor. Here
;  each bottom is the ground at its own corner, FRY - so the wall's lower
;  edge runs down the slope and the roof stays level.
;  FACEV builds a wall from footprint corners [fa] and [fb], in the order
;  A bottom, A top, B top, B bottom.
;  FACETOPC builds the roof from all four corners at bry1.
; ============================================================================
FACEV:  mov  si,[fa]            ; SI = corner A
        add  si,si              ; SI *= 2: a word
        mov  ax,[FRX+si]        ; AX = A's x
        mov  [IX],ax            ; A bottom and A top share it
        mov  [IX+2],ax
        mov  ax,[FRZ+si]        ; AX = A's z
        mov  [IZ],ax
        mov  [IZ+2],ax
        mov  ax,[FRY+si]        ; A bottom: the ground at A
        mov  [IY],ax
        mov  si,[fb]            ; SI = corner B
        add  si,si
        mov  ax,[FRX+si]
        mov  [IX+4],ax          ; B top and B bottom
        mov  [IX+6],ax
        mov  ax,[FRZ+si]
        mov  [IZ+4],ax
        mov  [IZ+6],ax
        mov  ax,[FRY+si]        ; B bottom: the ground at B
        mov  [IY+6],ax
        mov  ax,[bry1]          ; the tops
        mov  [IY+2],ax
        mov  [IY+4],ax
        ret

FACETOPC:
        mov  ax,[FRX]
        mov  [IX],ax
        mov  ax,[FRZ]
        mov  [IZ],ax
        mov  ax,[FRX+2]
        mov  [IX+2],ax
        mov  ax,[FRZ+2]
        mov  [IZ+2],ax
        mov  ax,[FRX+4]
        mov  [IX+4],ax
        mov  ax,[FRZ+4]
        mov  [IZ+4],ax
        mov  ax,[FRX+6]
        mov  [IX+6],ax
        mov  ax,[FRZ+6]
        mov  [IZ+6],ax
        mov  ax,[bry1]
        mov  [IY],ax
        mov  [IY+2],ax
        mov  [IY+4],ax
        mov  [IY+6],ax
        ret

; ============================================================================
;  HWALL - one wall: fill, outline, and its windows.
;
;  THE WINDOWS ARE ON THE WALL, not stamped on the screen. OWL FLY III's
;  WINFACEF learned that the hard way: a square of fixed size does not
;  foreshorten, and look along a street and the glass floats off the
;  brick. Two panes to a storey, at 1/8..3/8 and 5/8..7/8 of the wall's
;  width, from a quarter of a storey up to three quarters.
;
;  AND THEY ARE ALWAYS THE RIGHT SIZE. A pane is drawn as big as it
;  really is on the screen, however far away - so a house far off has
;  panes of one pixel, and as you close in they grow into rectangles a
;  pixel at a time. Nothing switches at a distance. A pane too thin to
;  cover a single row of pixels is given that one row, so no pane ever
;  vanishes: far off it is a dot, and the dot simply grows.
;
;  TWO WAYS TO GET THE SAME PANES. A wall the near plane has cut is right
;  beside you, and its panes go through FACEFILL one by one, as quads in
;  the world. Every other wall is still WHOLE on the screen - its four
;  corners are in PX/PY - and its panes are measured there instead, in
;  WSCREEN, for a fraction of the price. Both are exact, so the change
;  from one to the other shows nothing.
;
;  LIT OR DARK. Two colours, 35 and 36, and they are THE SAME by day:
;  dark glass. By night 35 is a lit room and 36 stays dark. Which pane
;  gets which is a hash of the house, the wall, the storey and the pane,
;  so it never changes - and the night is still nothing but the DAC. The
;  frame buffer does not know what time it is.
; ============================================================================
HWALL:  call FACEV              ; IX/IY/IZ = the wall
        call FACEFILL           ; fill it
        cmp  word [NPOLY],3     ; did anything of it reach the screen?
        jl   .x                 ;   no
        add  byte [COLOR],8     ; COLOR = the wall, folded
        call STROKEPOLY         ; its outline, from the same PX/PY

        ; ---- the wall's box on the screen ---------------------------------
        mov  cx,[NPOLY]         ; CX = how many corners
        mov  ax,[PX]            ; start the box at corner 0
        mov  [fbx0],ax
        mov  [fbx1],ax
        mov  ax,[PY]
        mov  [fby0],ax
        mov  [fby1],ax
        dec  cx                 ; the rest of them
        mov  si,2
.bb:    mov  ax,[PX+si]         ; AX = this corner's x
        cmp  ax,[fbx0]
        jge  .b1
        mov  [fbx0],ax          ; the leftmost so far
.b1:    cmp  ax,[fbx1]
        jle  .b2
        mov  [fbx1],ax          ; the rightmost
.b2:    mov  ax,[PY+si]
        cmp  ax,[fby0]
        jge  .b3
        mov  [fby0],ax          ; the top
.b3:    cmp  ax,[fby1]
        jle  .b4
        mov  [fby1],ax          ; the bottom
.b4:    add  si,2
        loop .bb
        cmp  word [fbx1],0      ; wholly off the glass? nothing to glaze
        jl   .x
        cmp  word [fbx0],319
        jg   .x
        cmp  word [fby1],0
        jl   .x
        cmp  word [fby0],199
        jg   .x
        mov  ax,[fbx1]          ; AX = right - left
        sub  ax,[fbx0]
        cmp  ax,WMINPX          ; a sliver?
        jl   .x                 ;   yes: nothing at all
        mov  ax,[fby1]          ; AX = bottom - top
        sub  ax,[fby0]
        cmp  ax,WMINPX
        jl   .x

        cmp  word [IZ],NEARZ    ; did the near plane cut this wall?
        jl   .near              ;   A is behind it
        cmp  word [IZ+4],NEARZ
        jl   .near              ;   B is
        jmp  WSCREEN            ; no: the wall is whole on the screen

        ; ---- the near way: every pane a quad in the world -----------------
        ; FACEFILL has not touched IX/IZ: CLIPNEAR reads them and writes
        ; OX/OZ. So A is still IX[0], IZ[0], and B is IX[4], IZ[4].
.near:  mov  ax,[IX+4]          ; AX = B - A, x
        sub  ax,[IX]
        sar  ax,1
        sar  ax,1
        sar  ax,1               ; AX = an eighth of it
        mov  [wux],ax           ; wux = it
        mov  ax,[IZ+4]          ; and z
        sub  ax,[IZ]
        sar  ax,1
        sar  ax,1
        sar  ax,1
        mov  [wuz],ax           ; wuz = an eighth, z
        mov  ax,[IX]            ; AX = A + one eighth: x
        add  ax,[wux]
        mov  [HWX],ax           ; HWX[0] = 1/8
        add  ax,[wux]
        add  ax,[wux]
        mov  [HWX+2],ax         ; HWX[1] = 3/8
        add  ax,[wux]
        add  ax,[wux]
        mov  [HWX+4],ax         ; HWX[2] = 5/8
        add  ax,[wux]
        add  ax,[wux]
        mov  [HWX+6],ax         ; HWX[3] = 7/8
        mov  ax,[IZ]            ; the same for z
        add  ax,[wuz]
        mov  [HWZ],ax
        add  ax,[wuz]
        add  ax,[wuz]
        mov  [HWZ+2],ax
        add  ax,[wuz]
        add  ax,[wuz]
        mov  [HWZ+4],ax
        add  ax,[wuz]
        add  ax,[wuz]
        mov  [HWZ+6],ax

        mov  ax,[bry0]          ; AX = the floor
        add  ax,FLOORH/4        ; AX = a quarter of a storey up
        mov  [wy],ax            ; wy = the bottom of the first row of glass
        mov  ax,[hfl]           ; AX = storeys
        mov  [wf],ax            ; wf = rows still to do
.fl:    xor  si,si              ; SI = 0: the left pane, points 0 and 1
.pn:    mov  ax,[HWX+si]        ; AX = its left edge, x
        mov  [IX],ax            ; bottom left and top left
        mov  [IX+2],ax
        mov  ax,[HWZ+si]
        mov  [IZ],ax
        mov  [IZ+2],ax
        mov  ax,[HWX+si+2]      ; its right edge
        mov  [IX+4],ax
        mov  [IX+6],ax
        mov  ax,[HWZ+si+2]
        mov  [IZ+4],ax
        mov  [IZ+6],ax
        mov  ax,[wy]            ; AX = the bottom of the glass
        mov  [IY],ax
        mov  [IY+6],ax
        add  ax,FLOORH/2        ; half a storey tall
        mov  [IY+2],ax
        mov  [IY+4],ax
        call HLIT               ; COLOR = 35 or 36: lit tonight, or not
        push si                 ; FACEFILL eats SI
        call FACEFILL           ; the pane
        pop  si
        add  si,4               ; the right pane: points 2 and 3
        cmp  si,8
        jb   .pn
        add  word [wy],FLOORH   ; up a storey
        dec  word [wf]          ; one row fewer
        jnz  .fl
.x:     ret                     ; return

; ---- HLIT: COLOR = 35 or 36 for pane SI (0 or 4) of row [wf] --------------
;  A hash of the house, the wall, the storey and the pane, so it never
;  changes - and both ways of drawing a pane ask it the same question, so
;  a window that is a lit dot from a mile away is a lit pane close to.
HLIT:   mov  ax,[hs]            ; AX = the house's number
        mov  al,ah              ; AL = its high byte
        add  al,[hn]            ; + where it stands in the block
        add  al,byte [fa]       ; + which wall
        mov  bl,byte [wf]       ; + which storey, three times
        add  al,bl
        add  al,bl
        add  al,bl
        mov  bx,si              ; + which pane, five times
        add  al,bl
        add  al,bl
        add  al,bl
        add  al,bl
        add  al,bl
        and  al,3               ; AL = 0..3
        mov  byte [COLOR],35    ; three in four: a room with the light on
        jnz  .lit
        mov  byte [COLOR],36    ; one in four: dark all night
.lit:   ret

; ============================================================================
;  WSCREEN - the panes of a whole wall, measured on the screen.
;
;  The wall's four corners are projected already: PX/PY hold A bottom,
;  A top, B top, B bottom. Every pane corner lies on the wall, so every
;  pane corner is somewhere BETWEEN those four points - and finding
;  "somewhere between" is a blend, not a projection. No divide by z per
;  point: two blends a coordinate.
;
;  ONE CATCH, AND IT IS THE WHOLE OF PERSPECTIVE. Halfway along the wall
;  is NOT halfway between A and B on the screen: the far half of a wall
;  looks shorter than the near half. Blend on the screen with the plain
;  fraction and the windows slide towards the far end as you turn, and
;  jump when the near way takes over. The fraction has to be corrected by
;  the two depths:
;
;                 u * zB                  u  - how far along the WALL
;      t  =  -----------------            t  - how far along the SCREEN
;             (1-u)*zA + u*zB             zA, zB - the depths of A and B
;
;  One divide per column of panes, four a wall. Up the wall there is no
;  such catch: a column stands at one depth, so its screen line is even.
;
;  THE FLOOR IS NOT THE BOTTOM. The bottom corners stand on the ground,
;  and on a slope that is below the floor the storeys count from (see
;  HOUSE). So first the floor line is found on the two edges, A and B:
;  the fraction of the way down from the roof at which bry0 lies - one
;  divide an edge, and none at all on flat ground.
;
;  THE LATTICE. Columns at 1, 3, 5, 7 eighths along the wall; rows at
;  1/4 and 3/4 of every storey, which over F storeys is (2i+1)/4F of the
;  way from the floor to the roof - HLEVQ has them in 256ths. The points
;  go into LX/LY, eight bytes a row, and the panes are read straight out
;  of them.
; ============================================================================
WSCREEN:
        mov  ax,[PX+2]          ; ---- the roof line: A top, B top ----
        mov  [wta],ax
        mov  ax,[PY+2]
        mov  [wta+2],ax
        mov  ax,[PX+4]
        mov  [wtb],ax
        mov  ax,[PY+4]
        mov  [wtb+2],ax
        mov  ax,[IY]            ; ---- the floor line, on edge A ----
        xor  si,si              ; SI = A bottom, in PX/PY
        mov  di,2               ; DI = A top
        mov  bx,wfa             ; out: wfa
        call WFLOOR
        mov  ax,[IY+6]          ; ...and on edge B
        mov  si,6               ; B bottom
        mov  di,4               ; B top
        mov  bx,wfb
        call WFLOOR

        ; ---- the lattice, then the panes out of it ------------------------
        mov  ax,[hfl]           ; AX = storeys
        mov  [wf],ax            ; (HLIT counts them down, bottom first)
        dec  ax                 ; AX = storeys - 1
        mov  cl,3
        shl  ax,cl              ; AX = (storeys-1)*8: this house's row of
        add  ax,HLEVQ           ;  HLEVQ, eight bytes a row
        mov  [wll],ax           ; wll = the rows' levels
        mov  ax,[hfl]
        add  ax,ax
        mov  [wnl],ax           ; two rows a storey
        mov  word [wkl],HKQ     ; four columns
        mov  word [wnk],4
        call WLAT               ; LX/LY = the lattice

        mov  word [wrow],0      ; wrow = 0: the bottom storey's glass
.fl:    xor  si,si              ; SI = 0: the left pane
.pn:    mov  bx,[wrow]          ; BX = storey*16: two rows of eight bytes
        add  bx,si              ; + pane*4: two columns of two bytes
        mov  ax,[LX+bx]         ; its four corners, round the quad:
        mov  [PX],ax            ;  bottom left
        mov  ax,[LY+bx]
        mov  [PY],ax
        mov  ax,[LX+bx+8]       ;  top left: the next row up
        mov  [PX+2],ax
        mov  ax,[LY+bx+8]
        mov  [PY+2],ax
        mov  ax,[LX+bx+10]      ;  top right
        mov  [PX+4],ax
        mov  ax,[LY+bx+10]
        mov  [PY+4],ax
        mov  ax,[LX+bx+2]       ;  bottom right
        mov  [PX+6],ax
        mov  ax,[LY+bx+2]
        mov  [PY+6],ax

        ; ---- NO PANE VANISHES -------------------------------------------
        ; SCANPOLY fills the rows from the top of a polygon down to, but
        ; not including, its bottom - so a pane whose top and bottom came
        ; out on the SAME row fills nothing at all, and a far facade would
        ; lose its windows at random, one here and one there, as you fly.
        ; So a side of the pane with no height is given one row. Far off
        ; that is a single pixel: the lit dot of a window across the town.
        mov  ax,[PY]            ; left side: top on the bottom's row?
        cmp  [PY+2],ax
        jl   .h1
        dec  ax                 ;   yes: the top one row up
        mov  [PY+2],ax
.h1:    mov  ax,[PY+6]          ; right side, the same
        cmp  [PY+4],ax
        jl   .h2
        dec  ax
        mov  [PY+4],ax
.h2:    mov  word [NPOLY],4
        call HLIT               ; COLOR = lit or dark
        push si                 ; SCANPOLY eats SI
        call SCANPOLY           ; the pane, straight into the buffer
        pop  si
        add  si,4               ; the right pane
        cmp  si,8
        jb   .pn
        add  word [wrow],16     ; up a storey
        dec  word [wf]
        jnz  .fl
        ret

; ---- WFLOOR: where the floor bry0 crosses one edge of the wall ------------
;  AX = the ground at this edge, from the eye. SI = the edge's bottom in
;  PX/PY, DI = its top. BX = two words out: the point's x and y.
;  The edge is a vertical line at one depth, so its screen line is even:
;  the floor is (bry1 - bry0) / (bry1 - ground) of the way down from the top.
WFLOOR: mov  cx,[bry1]          ; CX = bry1
        sub  cx,ax              ; CX = bry1 - ground: the whole edge
        mov  ax,[bry1]
        sub  ax,[bry0]          ; AX = bry1 - bry0: the storeys
        cmp  ax,cx              ; the same? the floor IS the ground here
        jne  .r
        mov  ax,[PX+si]         ; the bottom corner itself
        mov  [bx],ax
        mov  ax,[PY+si]
        mov  [bx+2],ax
        ret
.r:     push bx
        mov  bx,256             ; AX = storeys * 256 / edge: a fraction,
        imul bx                 ;  in 256ths, of the way down
        idiv cx
        mov  [wr],ax            ; wr = it
        pop  bx
        mov  ax,[PX+si]         ; x = top + (bottom - top) * wr / 256
        sub  ax,[PX+di]
        imul word [wr]          ; DX:AX = the difference * wr
        mov  al,ah              ; the middle two bytes of the product ARE
        mov  ah,dl              ;  the product over 256 - ROTXZ's trick
        add  ax,[PX+di]
        mov  [bx],ax
        mov  ax,[PY+si]         ; y the same
        sub  ax,[PY+di]
        imul word [wr]
        mov  al,ah
        mov  ah,dl
        add  ax,[PY+di]
        mov  [bx+2],ax
        ret

; ---- WLAT: the lattice. [wkl]/[wnk] = the columns, in eighths along the
;      wall; [wll]/[wnl] = the rows, in 256ths from floor to roof.
;      LX/LY[row*8 + column*2] = each point on the screen.
WLAT:   mov  ax,[IZ]            ; AX = zA
        sar  ax,1
        sar  ax,1               ; /4: small enough that k*z fits a word
        mov  [wza],ax
        mov  ax,[IZ+4]          ; zB, the same
        sar  ax,1
        sar  ax,1
        mov  [wzb],ax
        mov  word [wci],0       ; the first column
.c:     mov  si,[wkl]           ; ---- t for this column ----
        add  si,[wci]
        mov  al,[si]            ; AL = k: eighths along the wall
        xor  ah,ah
        mov  [wk],ax
        mul  word [wzb]         ; AX = k*zB
        mov  [wnum],ax          ; the top of the fraction
        mov  ax,8
        sub  ax,[wk]            ; AX = 8 - k
        mul  word [wza]         ; AX = (8-k)*zA
        add  ax,[wnum]          ; AX = (8-k)*zA + k*zB
        mov  cx,ax              ; CX = the bottom of it
        mov  ax,[wnum]          ; AX = k*zB
        mov  bx,256
        mul  bx                 ; DX:AX = k*zB*256
        div  cx                 ; AX = t, in 256ths: 0..256
        mov  cx,ax              ; CX = t
        mov  ax,[wfa]           ; ---- the column's floor point ----
        mov  bx,[wfb]
        call LERP8
        mov  [cfx],ax
        mov  ax,[wfa+2]
        mov  bx,[wfb+2]
        call LERP8
        mov  [cfy],ax
        mov  ax,[wta]           ; ---- and its roof point ----
        mov  bx,[wtb]
        call LERP8
        mov  [ctx],ax
        mov  ax,[wta+2]
        mov  bx,[wtb+2]
        call LERP8
        mov  [cty],ax
        mov  word [wli],0       ; ---- up the column, row by row ----
.l:     mov  si,[wll]
        add  si,[wli]
        mov  cl,[si]            ; CL = the row's level, in 256ths
        xor  ch,ch              ; CX = it
        mov  ax,[cfx]           ; x = floor + (roof - floor) * level
        mov  bx,[ctx]
        call LERP8
        mov  di,[wli]           ; DI = row*8 + column*2
        shl  di,1
        shl  di,1
        shl  di,1
        add  di,[wci]
        add  di,[wci]
        mov  [LX+di],ax
        mov  ax,[cfy]           ; y the same
        mov  bx,[cty]
        call LERP8
        mov  [LY+di],ax
        inc  word [wli]
        mov  ax,[wli]
        cmp  ax,[wnl]           ; every row?
        jb   .l
        inc  word [wci]
        mov  ax,[wci]
        cmp  ax,[wnk]           ; every column?
        jb   .c
        ret

; ---- LERP8: AX = a + (b - a) * CX / 256. AX = a, BX = b, CX = the blend ----
LERP8:  sub  bx,ax              ; BX = b - a
        push ax                 ; keep a
        mov  ax,bx              ; AX = b - a
        imul cx                 ; DX:AX = (b - a) * blend
        mov  al,ah              ; /256: the middle two bytes
        mov  ah,dl
        pop  bx                 ; BX = a
        add  ax,bx              ; AX = a + that
        ret

;  The columns, in eighths along the wall: the edges of the panes.
HKQ     db 1, 3, 5, 7
;  The rows, in 256ths from floor to roof. HLEVQ: the bottom and top of the
;  glass, (2i+1)/4F.
HLEVQ   db  64,192,  0,  0,  0,  0,  0,  0   ; one storey
        db  32, 96,160,224,  0,  0,  0,  0   ; two
        db  21, 64,107,149,192,235,  0,  0   ; three
        db  16, 48, 80,112,144,176,208,240   ; four

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
        mov  al,byte [ta]       ; AL = ta
        sub  al,NR              ; AL = da: squares east of the eye's
        mov  [TDA+si],al        ; TDA[ordn] = da - HOUSES4 needs to know
        mov  al,byte [tb]       ;  WHERE a square is, and the slot alone
        sub  al,NR              ;  would take a divide to say it
        mov  [TDB+si],al        ; TDB[ordn] = db
        inc  word [ordn]        ; ordn++

.nx:    inc  word [tb]          ; tb++
        cmp  word [tb],NSIDE    ; tb < NSIDE ?
        jl   .bl                ;   yes
        inc  word [ta]          ; ta++
        cmp  word [ta],NSIDE    ; ta < NSIDE ?
        jl   .al                ;   yes
        cmp  word [ordd],RH*RH  ; did that pass finish the TOWN's circle?
        jne  .nh
        mov  ax,[ordn]          ; AX = how many squares that is
        mov  [ordhouse],ax      ; ordhouse = it. HOUSES4 builds on these
.nh:    cmp  word [ordd],NR*NR  ; did that pass finish THE CIRCLE of radius
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
SETPAL: mov  dx,3C8h            ; DX = 3C8h, the DAC index port. SI = the
                                ;  table: runs of [first, count, r g b ...]
.rec:   lodsb                   ; AL = the first colour of this run
        mov  bl,al              ; BL = it
        lodsb                   ; AL = how many colours in the run
        or   al,al              ; nought?
        jz   .done              ;   the end of the table
        mov  cl,al              ; CL = count
        xor  ch,ch              ; CX = count
        mov  ax,cx              ; AX = count
        add  cx,cx              ; CX = count*2
        add  cx,ax              ; CX = count*3: an r, a g and a b each
        mov  al,bl              ; AL = the first colour
        out  dx,al              ; outp(0x3C8, first): where writing starts
        inc  dx                 ; DX = 3C9h, the data port
.p:     lodsb                   ; AL = *si++
        out  dx,al              ; outp(0x3C9, AL) - the index steps on by
        loop .p                 ;  itself after every third write
        dec  dx                 ; DX = 3C8h again, for the next run
        jmp  .rec               ; the next run
.done:  ret                     ; return

; ============================================================================
;  DAYNIGHT - load the palette the clock says, day or night.
;
;  THIS IS THE WHOLE NIGHT. Nothing on the screen is redrawn to make it:
;  every pixel keeps its number, and the DAC - the chip between the frame
;  buffer and the monitor - is told that the numbers mean different
;  colours now. Colour 35 is dark glass by day and a lit room by night; the
;  frame buffer never finds out. Sixty-odd bytes down two ports, and the
;  whole world changes in one retrace. The game does exactly this, on N,
;  with a bank per card.
; ============================================================================
DAYNIGHT:
        mov  si,PALDAY          ; SI = the day bank
        cmp  byte [night],0     ; night?
        je   .s                 ;   no
        mov  si,PALNIGHT        ;   yes: SI = the night bank
.s:     jmp  SETPAL             ; setpal(si), and its RET is ours

; ---- THE PALETTE IS IN TWO HALVES, EIGHT APART, AND NOW IN TWO BANKS ---
;  1 to 6 are the ground and 9 to 14 are the same six a fifth darker, so
;  a fold is colour + 8 - one ADD. A fifth and not a half: a seam is there
;  to show where one square meets the next, and it should be the square's
;  own colour, only just darker - not a black net thrown over the island. The houses follow the same rule at 32:
;  32 to 36 are the walls, the roof and two windows, 40 to 42 the folds.
;  Colour 15 is left alone on purpose: it is the BIOS white the frame
;  counter is written in, day or night.
;
;  Each bank is a list of RUNS - first colour, how many, then r g b for
;  each - ending with a run of nought. Two runs a bank.
PALDAY  db 1, 14                ; ---- the ground, by day ----
        db  4,10,28             ; 1 sea
        db 46,42,26             ; 2 sand
        db 16,38,10             ; 3 grass
        db 10,26, 8             ; 4 woods
        db 26,24,22             ; 5 rock
        db 46,48,50             ; 6 snow
        db 60,12, 8             ; 7 the crash message - its own entry,
                                ;  because this is not the BIOS palette
        db  0, 0, 0             ; 8 empty: the gap that makes the ADD free
        db  3, 8,22             ; 9  sea, folded: four fifths of 1
        db 37,34,21             ; 10 sand
        db 13,30, 8             ; 11 grass
        db  8,21, 6             ; 12 woods
        db 21,19,18             ; 13 rock
        db 37,38,40             ; 14 snow
        db 16, 1                ; ---- the sky, by day ----
        db 32,46,60             ; 16 a plain blue sheet
        db 32, 12               ; ---- the houses, by day ----
        db 46,44,40             ; 32 a wall facing north or south
        db 32,31,29             ; 33 a wall facing east or west: shaded
        db 30,16,12             ; 34 the roof
        db 12,18,28             ; 35 the window: dark glass
        db 12,18,28             ; 36 ANOTHER window, and the same glass: by
                                ;  day nobody can tell 35 and 36 apart
        db  0, 0, 0, 0,0,0, 0,0,0          ; 37-39 empty
        db 37,35,32             ; 40 the folds, eight up, a fifth darker
        db 26,25,23             ; 41
        db 24,13,10             ; 42
        db  6, 9,14             ; 43
        db 0, 0                 ; end

PALNIGHT db 1, 14               ; ---- the ground, by night: a third, and
        db  1, 2, 8             ; 1 sea                 bluer - moonlight
        db 11,10, 9             ; 2 sand
        db  3, 8, 4             ; 3 grass
        db  2, 5, 3             ; 4 woods
        db  7, 7, 8             ; 5 rock
        db 14,15,18             ; 6 snow
        db 60,12, 8             ; 7 the crash red, the same by night
        db  0, 0, 0             ; 8
        db  1, 1, 6             ; 9  folds, a fifth darker
        db  9, 8, 7             ; 10
        db  2, 6, 3             ; 11
        db  1, 4, 2             ; 12
        db  5, 5, 6             ; 13
        db 11,12,14             ; 14
        db 16, 1                ; ---- the sky, by night ----
        db  1, 2, 9             ; 16 not black: a very dark blue
        db 32, 12               ; ---- the houses, by night ----
        db  6, 6, 8             ; 32 walls, nearly gone
        db  4, 4, 6             ; 33
        db  3, 3, 4             ; 34 roof
        db 34,52,63             ; 35 THE WINDOW: a lit room, and blue -
                                ;  the television, perhaps
        db  3, 4, 7             ; 36 ...and here they part: nobody home
        db  0, 0, 0, 0,0,0, 0,0,0          ; 37-39 empty
        db  5, 5, 6             ; 40 a fifth darker, as by day
        db  3, 3, 5             ; 41
        db  2, 2, 3             ; 42
        db 40,30, 8             ; 43 a lit window's frame
        db 0, 0                 ; end

; ============================================================================
;  State: the lesson's own, then the contract the engine modules expect.
; ============================================================================
camx    dw 0                    ; where the eye stands, in world units
rawh    db 0                    ; TERRPREP: one node's raw map height, kept
                                ;  across WORLDH, which does not spare BX
tgi     dw 0                    ; TOWNSPOT: the biggest town's square...
tgj     dw 0
tbest   dw 0                    ; ...how many built squares round it
tcnt    dw 0                    ; ...the count for the square being looked at
tmax    db 0                    ; ...the tallest byte on the way in
townx   dw 0                    ; ...and where you appear: AIRBORNE reads it
townz   dw 0
towny   dw 0
camxf   db 0                    ; THE FRACTION of camx, in 1/256ths
camzf   db 0                    ; ...and of camz. Carried in by ADC
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
ordhouse dw 0                   ; ...and inside RH: the ones with houses
qband   db 0                    ; DRAWQUAD: the square's band, unfolded

; ---- the houses ----------------------------------------------------------
hfx     dw 0                    ; HPREP: the eye, inside its own square
hfz     dw 0
HAX     dw 17 dup(0)            ; k/16 of a square east, turned: x...
HAZ     dw 17 dup(0)            ; ...and z
HBX     dw 17 dup(0)            ; k/16 of a square north, turned: x...
HBZ     dw 17 dup(0)            ; ...and z
hc0x    dw 0                    ; HOUSES4: the square's corner 0, turned
hc0z    dw 0
hrx     dw 0                    ; ...the eye, from that corner, in the world
hrz     dw 0
hgi     dw 0                    ; ...the square's place on the map
hgj     dw 0
hh      dw 0                    ; ...and its hash: the town plan
hy0     dw 0                    ; ...corner 0's ground, from the eye
gl      dw 0                    ; ...the west side, down the lattice...
gls     dw 0
gr      dw 0                    ; ...and the east
grs     dw 0
GY      dw 64 dup(0)            ; ...the ground at the 64 house corners
HCOL    db 4 dup(0)             ; ...the columns, farthest first
HROW    db 4 dup(0)             ; ...and the rows
hci     db 0                    ; ...which of them it is on
hri     db 0
oeye    dw 0                    ; HORD: the eye along its axis
olo     db 0                    ; ...and the two ends still left
ohi     db 0
hc      db 0                    ; HOUSE: its column, 0..3
hr      db 0                    ; ...its row
hn      db 0                    ; ...its place in the block, 0..15
hd      dw 0                    ; ...how far it is from the eye
hs      dw 0                    ; ...its own number
ha0     dw 0                    ; ...its walls, in sixteenths times two
ha1     dw 0
hb0     dw 0
hb1     dw 0
hfl     dw 0                    ; ...its storeys
bry0    dw 0                    ; ...its floor and its roof, from the eye
bry1    dw 0
FRY     dw 4 dup(0)             ; ...the ground at its four corners
fa      dw 0                    ; FACEV: the wall's two corners
fb      dw 0
FRX     dw 4 dup(0)             ; the four corners, turned: x...
FRZ     dw 4 dup(0)             ; ...and z
fbx0    dw 0                    ; HWALL: the wall's box on the screen
fbx1    dw 0
fby0    dw 0
fby1    dw 0
wux     dw 0                    ; ...the near way: an eighth of the wall
wuz     dw 0
HWX     dw 4 dup(0)             ; ...1, 3, 5 and 7 eighths along it
HWZ     dw 4 dup(0)
wy      dw 0                    ; ...the bottom of this row of glass
wf      dw 0                    ; ...and how many rows are left
wta     dw 0,0                  ; WSCREEN: the roof line, A and B...
wtb     dw 0,0
wfa     dw 0,0                  ; ...and the floor line
wfb     dw 0,0
wr      dw 0                    ; WFLOOR: how far down the floor is
wrow    dw 0                    ; ...the row of panes being drawn
wkl     dw 0                    ; WLAT: the columns' list...
wnk     dw 0                    ; ...and how many
wll     dw 0                    ; ...the rows' list...
wnl     dw 0                    ; ...and how many
wza     dw 0                    ; ...the two depths, quartered
wzb     dw 0
wci     dw 0                    ; ...which column, which row
wli     dw 0
wk      dw 0                    ; ...this column, in eighths
wnum    dw 0                    ; ...the top of its fraction
cfx     dw 0                    ; ...its floor point
cfy     dw 0
ctx     dw 0                    ; ...its roof point
cty     dw 0
LX      dw 32 dup(0)            ; ...and the lattice: eight rows of four
LY      dw 32 dup(0)

savesp  dw 0                    ; where TRAP0 puts the stack back to
faults  dw 0                    ; ...and how many times it had to, this frame
oldi0   dw 0,0                  ; the INT 0 vector we borrowed...
oldi9   dw 0,0                  ; ...and the INT 9 one. Both go back at QUIT

dying   db 0                    ; 1 = a wreck. The flight model is skipped,
                                ;  everything else carries on
dytick  dw 0                    ; frames since the impact - the message
                                ;  blinks on bit 3 of it
turn    dw 0                    ; which way the stick is held: -1, 0 or +1
night   db 0                    ; 0 = day, 1 = night. N flips it
nwas    db 0                    ; was N held last frame?
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

TOWNB   db 4096 dup(0)          ; TOWNSPOT: 1 where a square has houses
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
TDA     db NSIDE*NSIDE dup(0)   ; ...where each square is: squares east
TDB     db NSIDE*NSIDE dup(0)   ;  and north of the eye's own
TEDGE   db NSIDE*NSIDE dup(0)   ; ...and beside each one, the edges that
                                ;  square owns: bit i = corner i to i+1
