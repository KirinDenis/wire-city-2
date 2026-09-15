; ============================================================================
;  TERRAIN.ASM - Lesson 11. Diamond-Square: a landscape out of a table of
;  random numbers, on a 64 by 64 torus, in integers.
;
;      FASM TERRAIN.ASM TERRAIN.COM
;
;      the four anchors        four heights, and nothing else exists yet
;      five octaves            diamond, then square, ten steps in all. The
;                              cells each step writes burn ORANGE and cool
;                              to grey on the next one, so you can watch
;                              the grid halve itself under your eyes.
;      the stretch             the same map, the contrast opened up
;      the island              six colour bands, and it is land and sea
;      SPACE                   another island. Hold it down.
;      ESC                     back to DOS
;
;  WHAT A GAME ACTUALLY SHIPS. Not a world - a recipe for one. WIRE CITY's
;  islands are four kilobytes of heightmap that never existed until the
;  program was started, and the whole of the generator is below. The
;  Sentinel shipped ten thousand landscapes on a cassette this way.
;
;  ------------------------------------------------------------------------
;  THE MENU, because Diamond-Square is not the only way and it would be
;  dishonest to show one door and call it the building:
;
;      VALUE NOISE     a random number at every lattice point, smoothly
;                      interpolated between them. Cheap, and it looks it:
;                      the lattice shows through as a grid of blobs.
;      PERLIN NOISE    a random GRADIENT at every lattice point, and the
;                      value comes from a dot product with it. Much better
;                      looking. Two multiplies per corner per point, four
;                      corners, then the blend - per SAMPLE, not per node.
;      SIMPLEX         Perlin's own repair of Perlin: a triangular lattice
;                      instead of a square one, fewer corners to visit.
;      FAULT LINES     draw a random line across the map, raise everything
;                      on one side of it, repeat a thousand times. Adds and
;                      compares only - honestly the cheapest of the lot,
;                      and it makes worlds that look geological and boring.
;      PARTICLES       drop grains on the map and let them roll downhill.
;                      Beautiful, slow, and it needs a second buffer.
;      EROSION         take any of the above and run water over it. This is
;                      what modern terrain generators spend their time on.
;      VORONOI         scatter points, colour by nearest one. Cells, not
;                      hills - good for continents, wrong for ground.
;      DIAMOND-SQUARE  midpoint displacement in two dimensions. Below.
;
;  WHY THIS ONE, HERE. Count what it costs. Diamond-Square touches every
;  node exactly once, and at each node it does four ADDs, two SHRs, one AND
;  and one random number. No multiply. No divide. No interpolation, because
;  the midpoint IS the sample - there is nothing between the nodes to ask
;  about. Perlin cannot say that: its whole method is a dot product, and a
;  dot product on this machine is the instruction lesson 4 spent ten
;  minutes telling you not to reach for.
;
;  ------------------------------------------------------------------------
;  ALL OF THEM NEED A RANDOM NUMBER, and this machine has none. There is no
;  instruction. There is no chip to ask. So we make one, and the recipe is
;  one multiply and one add:
;
;      seed = (seed * 25173 + 13849) mod 65536
;
;  This is a LINEAR CONGRUENTIAL GENERATOR, and everything about it is
;  visible in that line. It is a recurrence: every number is made out of
;  the one before it, so the sequence is completely determined by where it
;  starts. Give it the same seed and you get the same world, every time, on
;  every machine - which is a FEATURE, and the reason a game can ship a
;  world as a single number. Give it the BIOS clock at boot, as we do, and
;  nobody ever sees the same one twice.
;
;  "mod 65536" costs nothing at all: the multiply already leaves its low
;  half in AX and its high half in DX, and we simply do not look at DX.
;  Dropping the top half IS the remainder. There is no DIV anywhere in it.
;
;  THE PART THAT BIT US, and it is the best thing in this lesson. The low
;  bits of an LCG like this are not random. Bit 0 alternates every draw.
;  Bit 1 has period four. Bit k has period 2^(k+1) - you can prove it in a
;  line, because arithmetic mod 2^16 carries only upward, so the bottom k
;  bits never learn anything from the bits above them. Take the low byte
;  and you have a number with a period of 512. Take the HIGH byte, which
;  every carry in the multiply has walked through, and it behaves.
;
;  AND ONE MORE, which cost a day. One island is EXACTLY 4096 draws:
;
;      4 anchors + 12 + 48 + 192 + 768 + 3072  =  4096
;
;  4096 divides 65536. So island number two started 4096 steps along a
;  65536-long circle, island three at 8192, and after sixteen islands the
;  seed was back where it began - and half of those sixteen are the same
;  map anyway, because the masks below throw away bit 15. A flip-book that
;  repeated every eight frames. The fix is one instruction at the end of
;  the generator: draw a number and throw it away. The stride becomes 4097,
;  which is odd and therefore coprime with 65536, and now the islands walk
;  the whole orbit - all 65536 of them before one repeats.
;
;  ------------------------------------------------------------------------
;  DIAMOND-SQUARE ITSELF, and it is four lines of English.
;
;  Start with a square whose four corners have heights. Then, for ever:
;
;      DIAMOND  the centre of each square gets the average of its four
;               corners, plus a random nudge
;      SQUARE   the middle of each edge gets the average of the four points
;               around it - two corners and two of the centres just made -
;               plus a random nudge
;
;  ...and then halve the square, halve the nudge, and go again. The grid
;  doubles in resolution each pass: 2x2 anchors, then 4x4 known, 8x8, 16,
;  32, 64. Five passes and every one of the 4096 nodes has a height.
;
;  THE HALVING OF THE NUDGE IS THE LANDSCAPE. Nothing else in this program
;  decides what the ground looks like. Big features got big random numbers
;  because they were placed first, when the amplitude was 128; the last
;  pass is placing pebbles with an amplitude of 4. Detail that shrinks as
;  fast as the distance between the points carrying it - that is what real
;  ground does, and it is why this looks like ground and not like static.
;
;  THE MAP IS A TORUS. Every coordinate is masked with AND 63 before it is
;  used, so 64 means 0 and -1 means 63. This costs one instruction and buys
;  the whole of the edge handling: there is no special case at the border,
;  because there is no border. The left edge IS the right edge. Walk off
;  the top of WIRE CITY's island and you arrive at the bottom.
;
;  AND WHY IT ENDS WITH A STRETCH. Averaging pulls everything toward the
;  middle. Four numbers near 128 average to something nearer 128 still, and
;  by the fifth pass the whole map is crowded into the middle of the range
;  with an amplitude of 4 either side. The heights are RIGHT - the shape is
;  there - but the range is wrong, and a colour band picked at 88 would
;  find the entire island on one side of it. So the last thing the
;  generator does is find the lowest and the highest it actually made and
;  re-spread them across the full 0..255. That pass is the one place in
;  this program with a MUL and a DIV in it, and they are affordable for a
;  reason worth saying out loud: they run 4096 times per ISLAND, not once
;  per pixel per frame. Lesson 4's argument was never "never multiply". It
;  was "never multiply in the inner loop", and this is not one.
;
;  WHAT THIS LESSON DOES NOT DO. The map is drawn flat, from above, as
;  colour. It is not drawn as a landscape, because a landscape is 4096
;  points that need the camera of lesson 10 and something to say about the
;  ones that end up behind the viewer - and that is the next lesson, not
;  this one.
;
;  Owlos - legacy software modernization - https://owlos.sk
; ============================================================================
format binary as 'com'
        org  100h

VGA     = 0A000h                ; the graphics screen, since lesson 3
W       = 320

MAPN    = 64                    ; the map is 64 nodes square. Sixty-four,
                                ;  and not sixty, because every wrap in
                                ;  this program is an AND with 63.
CELL    = 3                     ; a node is a 3x3 block on the screen:
ORGX    = 64                    ;  64*3 = 192 pixels wide, so (320-192)/2
ORGY    = 4                     ;  = 64 of margin each side

CGREY   = 16                    ; colours 16..31: the grey ramp, 16 steps
CEMBER  = 32                    ; colours 32..47: the SAME 16 steps, but
                                ;  hot - what this step just wrote

; ============================================================================
;  Boot
; ============================================================================
Boot:   cld
        mov  ax, 40h            ; the BIOS data area. 0040:006C is a counter
        mov  es, ax             ;  the timer interrupt bumps 18.2 times a
        mov  ax, [es:6Ch]       ;  second, and it is the only thing on this
        or   ax, 1              ;  machine that differs between two runs.
        mov  [rseed], ax        ; never zero: a generator that only
                                ;  MULTIPLIES is dead there. Ours also adds,
                                ;  so it would survive - but the day someone
                                ;  drops the +13849 this instruction saves
                                ;  them, and it costs nothing.
        mov  ax, 0013h          ; 320x200, 256 colours
        int  10h
        mov  ax, VGA
        mov  es, ax             ; ES points at the screen for the whole
                                ;  program. Nothing else is ever written
                                ;  through ES, so it is set once, here.
        call SetPal

; ---- THE BUILD, one keypress a step ----------------------------------------
;  The same routines the fast path calls, stopped between each one so you
;  can see what it did. Nothing here is a demonstration mode: Diam and Squa
;  below ARE the generator.
        call Fresh              ; four anchors, and 4092 nodes of nothing
        call Show
        call Hold
.pass:  call Cool               ; last step's orange becomes this step's grey
        call Diam
        call Show
        call Hold
        call Cool
        call Squa
        call Show
        call Hold
        call Shrink             ; half the square, half the nudge
        cmp  word [side], 1
        jg   .pass              ; ...until the square is one node wide

        call Cool               ; everything grey, so the only thing that
        call Stretch            ;  changes in the next picture is CONTRAST
        call Show
        call Hold

; ---- THE ISLAND, and then the flip-book ------------------------------------
        mov  byte [isle], 1     ; from here Show paints height bands
        call Show
.roll:  call Hold              ; any key mints another world. Hold SPACE
        call Gen                ;  down and the keyboard's own repeat rate
        call Show               ;  turns this into a flip-book: every frame
        jmp  .roll              ;  a landscape that has never existed.

Bye:    mov  ax, 0003h          ; text mode back, and hand DOS the machine
        int  10h                ;  in the state we borrowed it in
        mov  ax, 4C00h
        int  21h

; ============================================================================
;  RND16 - the linear congruential generator. Out: AX = the new seed.
;  Preserves BX and DX, because every caller below is in the middle of
;  carrying a coordinate in one of them.
; ============================================================================
RND16:  push bx
        push dx
        mov  ax, [rseed]
        mov  bx, 25173
        mul  bx                 ; DX:AX = seed * 25173. The 8086 hands back
                                ;  all 32 bits of a 16x16 multiply, whether
                                ;  you wanted them or not.
        add  ax, 13849          ; + the increment. Any carry out of AX runs
                                ;  into DX, which we are about to abandon.
        mov  [rseed], ax        ; keeping only AX IS the "mod 65536". There
                                ;  is no DIV in this generator.
        pop  dx
        pop  bx
        ret

; ============================================================================
;  Idx - BX = x, DX = y  ->  BX = the byte's offset in the map.
;  Clobbers CX. These few instructions are the entire torus.
; ============================================================================
Idx:    and  bx, 63             ; x mod 64. 64 is a power of two, so the
                                ;  remainder IS the low six bits - and a
                                ;  remainder that costs one AND is the
                                ;  reason the map is square and 64 wide.
        mov  cl, 6
        shl  bx, cl             ; * 64: the start of column x. The 8086
                                ;  shifts by one or by CL, never by a
                                ;  constant - that arrived with the 286.
        and  dx, 63             ; y mod 64, the same trick
        add  bx, dx             ; + the row inside it
        ret

; ---- HGET: BX = x, DX = y -> AL = height. BX and DX come back untouched ----
HGET:   push dx
        push bx
        call Idx
        mov  al, [hmap+bx]
        pop  bx
        pop  dx
        ret

; ---- HPUT: AL = height at BX = x, DX = y. Same promise about BX and DX ----
HPUT:   push dx
        push bx
        call Idx
        mov  [hmap+bx], al
        mov  byte [seen+bx], 2  ; SEEN IS NOT PART OF THE ALGORITHM. It is
                                ;  one byte per node saying nothing (0),
                                ;  older (1) or written just now (2), and
                                ;  it exists so the picture can show you
                                ;  where the generator has been. Delete it
                                ;  and the islands are identical.
        pop  bx
        pop  dx
        ret

; ============================================================================
;  Noise - AX = [acc]/4 + a random nudge, clamped to 0..255.
;  [acc] holds the sum of the four neighbours. Clobbers AX and BX.
; ============================================================================
Noise:  call RND16
        mov  al, ah             ; the HIGH byte. The low byte of this
        xor  ah, ah             ;  generator has a period of 512 - see the
                                ;  note at the top. This one instruction is
                                ;  the difference between a landscape and a
                                ;  pattern.
        mov  bx, [amp]
        dec  bx                 ; amp is always a power of two, so amp-1 is
        and  ax, bx             ;  a mask of ones: 0..amp-1, no DIV
        mov  bx, [amp]
        shr  bx, 1
        sub  ax, bx             ; -amp/2 .. amp/2-1 : as likely down as up,
                                ;  which is what keeps the island from
                                ;  drifting off the top of the range
        mov  bx, [acc]
        shr  bx, 1
        shr  bx, 1              ; the average of four numbers is a sum and
        add  ax, bx             ;  two shifts. No divide here either.
        jns  .lo
        xor  ax, ax             ; a height is one byte: clamp both ends
.lo:    cmp  ax, 255
        jle  .hi
        mov  ax, 255
.hi:    ret

; ============================================================================
;  Fresh - an empty map with four heights in it, and the coarsest grid.
; ============================================================================
Fresh:  mov  word [side], 32    ; the first square is half the map across:
                                ;  on a torus its four corners are (0,0),
                                ;  (32,0), (0,32) and (32,32) - and each of
                                ;  those is the corner of four squares at
                                ;  once, because the map wraps.
        mov  word [amp], 128    ; and the first nudge is half the range
        xor  si, si
.z:     mov  byte [hmap+si], 0
        mov  byte [seen+si], 0
        inc  si
        cmp  si, 4096
        jb   .z
        xor  bx, bx
        xor  dx, dx
        call Anchor
        mov  bx, 32
        xor  dx, dx
        call Anchor
        xor  bx, bx
        mov  dx, 32
        call Anchor
        mov  bx, 32
        mov  dx, 32
        call Anchor
        ret

Anchor: call RND16
        mov  al, ah             ; the high byte again, every time
        and  al, 127            ; 0..127 ...
        add  al, 64             ; ... shifted to 64..191. The anchors start
                                ;  in the middle of the range on purpose:
                                ;  an anchor at 250 has nowhere left to go
                                ;  up, and the map would flatten against
                                ;  the ceiling before the stretch could
                                ;  help it.
        call HPUT
        ret

; ============================================================================
;  Diam - the DIAMOND step. Every square of the current grid gets a centre:
;  the average of its four corners, plus a nudge.
;
;      x,y ------- x+s,y          the four corners are s apart, and the
;       |     o     |             centre sits h = s/2 in from each of them.
;       |           |             It is called the diamond step because
;      x,y+s ---- x+s,y+s         the four points AROUND that centre form
;                                 a diamond, not a square.
; ============================================================================
Diam:   mov  ax, [side]
        shr  ax, 1
        mov  [half], ax         ; h = s/2, needed by the square step too
        mov  word [gx], 0
.x:     mov  word [gy], 0
.y:     mov  bx, [gx]           ; corner 1: (x, y)
        mov  dx, [gy]
        call HGET
        xor  ah, ah             ; heights are bytes; the sum of four needs
        mov  [acc], ax          ;  ten bits, so it is added as a word
        mov  bx, [gx]           ; corner 2: (x+s, y)
        add  bx, [side]
        call HGET
        xor  ah, ah
        add  [acc], ax
        mov  dx, [gy]           ; corner 3: (x+s, y+s) - BX is still x+s,
        add  dx, [side]         ;  because HGET gives it back unharmed
        call HGET
        xor  ah, ah
        add  [acc], ax
        mov  bx, [gx]           ; corner 4: (x, y+s)
        call HGET
        xor  ah, ah
        add  [acc], ax
        call Noise              ; AX = the answer
        mov  bx, [gx]
        add  bx, [half]
        mov  dx, [gy]
        add  dx, [half]
        call HPUT               ; ...and it lands in the middle
        mov  ax, [gy]
        add  ax, [side]
        mov  [gy], ax
        cmp  ax, 64
        jae  .ynext             ; A CONDITIONAL JUMP ON AN 8086 REACHES 127
        jmp  .y                 ;  BYTES AND NO FURTHER. This loop body is
.ynext:                         ;  longer than that, so the condition is
        mov  ax, [gx]           ;  inverted and it steps OVER a plain JMP,
        add  ax, [side]         ;  which has no such limit. The 386 added a
        mov  [gx], ax           ;  long conditional and FASM will quietly
        cmp  ax, 64             ;  reach for it - which is why the engine
        jae  .xdone             ;  carries ENGINE\E_8086.INC to forbid it.
        jmp  .x                 ;  In this one file it is written out by
.xdone: ret                     ;  hand, in the four places it is needed.

; ============================================================================
;  Squa - the SQUARE step. Every EDGE midpoint gets the average of the four
;  points around it, plus a nudge.
;
;            o                   Two corners of the original square, and
;            |                   two centres the diamond step has just
;      o --- X --- o             made. Those four are a SQUARE standing on
;            |                   its corner, h away in each direction -
;            o                   hence the name, and hence the fact that
;                                this step cannot run before the other.
;
;  One pass over the grid does both of a square's two new edge midpoints -
;  (x+h, y) and (x, y+h) - and because the grid covers the whole torus,
;  every edge in the map is covered exactly once.
; ============================================================================
Squa:   mov  word [gx], 0
.x:     mov  word [gy], 0
.y:     mov  bx, [gx]           ; ---- the midpoint at (x+h, y) ----
        mov  dx, [gy]           ; west corner (x, y)
        call HGET
        xor  ah, ah
        mov  [acc], ax
        mov  bx, [gx]           ; east corner (x+s, y)
        add  bx, [side]
        call HGET
        xor  ah, ah
        add  [acc], ax
        mov  bx, [gx]           ; north centre (x+h, y-h) - the square
        add  bx, [half]         ;  ABOVE this one, whose centre the diamond
        mov  dx, [gy]           ;  step made a moment ago. On the first row
        sub  dx, [half]         ;  y-h is negative, and AND 63 quietly
        call HGET               ;  reads it off the bottom of the map. The
        xor  ah, ah             ;  torus again, and no code for it.
        add  [acc], ax
        mov  dx, [gy]           ; south centre (x+h, y+h) - our own
        add  dx, [half]
        call HGET
        xor  ah, ah
        add  [acc], ax
        call Noise
        mov  bx, [gx]
        add  bx, [half]
        mov  dx, [gy]
        call HPUT
        mov  bx, [gx]           ; ---- and the midpoint at (x, y+h) ----
        mov  dx, [gy]           ; north corner (x, y)
        call HGET
        xor  ah, ah
        mov  [acc], ax
        mov  dx, [gy]           ; south corner (x, y+s)
        add  dx, [side]
        call HGET
        xor  ah, ah
        add  [acc], ax
        mov  bx, [gx]           ; west centre (x-h, y+h)
        sub  bx, [half]
        mov  dx, [gy]
        add  dx, [half]
        call HGET
        xor  ah, ah
        add  [acc], ax
        mov  bx, [gx]           ; east centre (x+h, y+h)
        add  bx, [half]
        call HGET
        xor  ah, ah
        add  [acc], ax
        call Noise
        mov  bx, [gx]
        mov  dx, [gy]
        add  dx, [half]
        call HPUT
        mov  ax, [gy]
        add  ax, [side]
        mov  [gy], ax
        cmp  ax, 64
        jae  .ynext             ; over a JMP again - this body is twice as
        jmp  .y                 ;  long as the diamond step's
.ynext:
        mov  ax, [gx]
        add  ax, [side]
        mov  [gx], ax
        cmp  ax, 64
        jae  .xdone
        jmp  .x
.xdone: ret

; ============================================================================
;  Shrink - the next octave: half the square, half the nudge.
;  THIS ROUTINE IS THE LANDSCAPE. Shift the amplitude twice instead of once
;  and you get a smooth desert; take the shift out and you get static.
; ============================================================================
Shrink: mov  ax, [half]
        mov  [side], ax         ; the grid the next pass works on is the one
                                ;  this pass has just finished filling
        mov  ax, [amp]
        shr  ax, 1              ; and the nudge halves with it
        cmp  ax, 4
        jge  .ok
        mov  ax, 4              ; a floor, because a nudge of zero would
.ok:    mov  [amp], ax          ;  make the last pass a plain average and
        ret                     ;  the ground would come out varnished

; ============================================================================
;  Stretch - find the lowest and the highest the generator actually used,
;  and re-spread the whole map across 0..255.
; ============================================================================
Stretch:
        mov  al, 255            ; AL = the lowest seen so far ...
        xor  ah, ah             ; AH = ... and the highest. Two counters in
                                ;  one register, because both are bytes
        xor  si, si
.mm:    mov  bl, [hmap+si]
        cmp  bl, al
        jae  .m1
        mov  al, bl
.m1:    cmp  bl, ah
        jbe  .m2
        mov  ah, bl
.m2:    inc  si
        cmp  si, 4096
        jb   .mm
        mov  bl, ah
        sub  bl, al             ; the range the map actually occupies
        jz   .done              ; a flat map would divide by zero, and the
                                ;  only honest answer for one is to leave
                                ;  it alone
        xor  bh, bh
        mov  [hrng], bx
        xor  ah, ah             ; AX = the minimum on its own now
        mov  [hmin], ax
        xor  si, si
.sc:    mov  al, [hmap+si]
        xor  ah, ah
        sub  ax, [hmin]         ; how far above the floor this node is
        mov  cx, 255
        mul  cx                 ; DX:AX = that * 255. DX comes out zero -
                                ;  the biggest this can be is 255*255
        div  word [hrng]        ; ... / the range: 0..255, the full scale.
                                ;  ONE MUL AND ONE DIV PER NODE, and they
                                ;  are here on purpose. 4096 of each, once
                                ;  per island. Lesson 4 said not to put
                                ;  them in the inner loop, and this is not
                                ;  the inner loop - it runs when a world is
                                ;  born, not when a frame is drawn.
        mov  [hmap+si], al
        inc  si
        cmp  si, 4096
        jb   .sc
.done:  call RND16              ; THE 4097th DRAW, and the number is thrown
                                ;  away. An island is exactly 4096 random
                                ;  numbers; 4096 divides 65536, so island
                                ;  after island started 4096 steps apart on
                                ;  the same circle and the flip-book looped
                                ;  every eight frames. 4097 is odd, odd is
                                ;  coprime with a power of two, and a stride
                                ;  coprime with the period visits all of it.
        ret

; ============================================================================
;  Gen - a whole island, no stopping. This is the routine a game calls.
; ============================================================================
Gen:    call Fresh
.p:     call Diam
        call Squa
        call Shrink
        cmp  word [side], 1
        jg   .p
        call Stretch
        ret

; ============================================================================
;  Cool - every "written just now" becomes "was already there".
;  Presentation only, like SEEN itself.
; ============================================================================
Cool:   mov  si, seen
        mov  cx, 4096
.c:     cmp  byte [si], 2
        jne  .n
        mov  byte [si], 1
.n:     inc  si
        dec  cx
        jnz  .c
        ret

; ============================================================================
;  SetPal - three ramps, written straight into the VGA DAC.
;
;  Port 3C8h takes the colour NUMBER to start at, then port 3C9h takes red,
;  green and blue - 0..63 each, and the index steps on by itself after every
;  third write. That is the whole protocol.
; ============================================================================
SetPal: mov  dx, 3C8h
        mov  al, 1              ; colours 1..6: the island
        out  dx, al
        inc  dx
        mov  si, PAL
        mov  cx, 6*3
.p:     lodsb
        out  dx, al
        dec  cx
        jnz  .p

        mov  dx, 3C8h           ; colours 16..31: sixteen greys
        mov  al, CGREY
        out  dx, al
        inc  dx
        xor  bx, bx
.g:     mov  ax, bx
        mov  cl, 2
        shl  ax, cl             ; step * 4 ...
        add  al, 3              ; ... + 3, so the darkest land is still
        out  dx, al             ;  visible against a black nothing
        out  dx, al
        out  dx, al
        inc  bx
        cmp  bx, 16
        jb   .g

        mov  dx, 3C8h           ; colours 32..47: the same sixteen, hot
        mov  al, CEMBER
        out  dx, al
        inc  dx
        xor  bx, bx
.e:     mov  ax, bx
        add  ax, ax             ; red climbs 32..62 ...
        add  al, 32
        out  dx, al
        mov  ax, bx             ; ... green a quarter as fast, 0..15 ...
        out  dx, al
        xor  al, al             ; ... and no blue at all. ONE COLOUR, ONE
        out  dx, al             ;  MEANING: orange means "this step".
        inc  bx
        cmp  bx, 16
        jb   .e
        ret

; Six colours and five thresholds, and NOTHING in the generator knows about
; them. The map is heights; the bands are a decision taken afterwards, by
; whoever is looking. WIRE CITY uses these same five thresholds to decide
; where a city may be built - different meaning, same numbers, same map.
PAL     db  4,10,28             ; 1 sea
        db 46,42,26             ; 2 sand
        db 16,38,10             ; 3 grass
        db 10,26, 8             ; 4 woods
        db 26,24,22             ; 5 rock
        db 46,48,50             ; 6 snow

; ============================================================================
;  Show - paint all 4096 nodes as 3x3 blocks, north up.
;
;  NOT ONE MULTIPLY IN IT. The screen address walks: three pixels right per
;  node, three scanlines down per row. The map offset walks too - one step
;  in x is 64 bytes, because the map is stored column by column.
; ============================================================================
Show:   mov  di, ORGY*W+ORGX    ; the map's top-left corner on the screen
        mov  word [gy], 63      ; the TOP row of the picture is the HIGHEST
                                ;  y in the map: north up, like every map
                                ;  ever printed, and the opposite of the way
                                ;  the screen counts
.row:   push di
        mov  si, [gy]           ; node (0, gy) lives at offset gy
        mov  dx, 64             ; 64 nodes across. DX, not CX - CX is about
                                ;  to be needed for a shift, and the 8086
                                ;  will only shift by CL.
.col:   mov  al, [hmap+si]
        mov  bl, [seen+si]
        cmp  byte [isle], 0
        jne  .band
        or   bl, bl
        jnz  .lit
        xor  al, al             ; never written yet: black
        jmp  .paint
.lit:   mov  cl, 4
        shr  al, cl             ; height 0..255 -> which of sixteen steps
        shl  bl, cl             ; seen 1 -> 16, seen 2 -> 32: which ramp
        add  al, bl             ; and the colour is the two added. The two
        jmp  .paint             ;  ramps being sixteen apart is not a
                                ;  coincidence - it is what makes this one
                                ;  ADD instead of a branch.
.band:  mov  ah, 1              ; sea
        cmp  al, 88
        jb   .set
        mov  ah, 2              ; sand
        cmp  al, 120
        jb   .set
        mov  ah, 3              ; grass
        cmp  al, 168
        jb   .set
        mov  ah, 4              ; woods
        cmp  al, 200
        jb   .set
        mov  ah, 5              ; rock
        cmp  al, 230
        jb   .set
        mov  ah, 6              ; snow
.set:   mov  al, ah
.paint: mov  [es:di], al        ; nine stores, no inner loop: a 3x3 block
        mov  [es:di+1], al      ;  is small enough that the loop would cost
        mov  [es:di+2], al      ;  more than the copies
        mov  [es:di+W], al
        mov  [es:di+W+1], al
        mov  [es:di+W+2], al
        mov  [es:di+W*2], al
        mov  [es:di+W*2+1], al
        mov  [es:di+W*2+2], al
        add  si, 64             ; one node east is 64 bytes on in the map
        add  di, CELL           ; ...and three pixels right on the screen
        dec  dx
        jz   .cdone             ; over a JMP: the six colour bands alone
        jmp  .col               ;  put this body past 127 bytes
.cdone: pop  di
        add  di, CELL*W         ; three scanlines down
        dec  word [gy]
        js   .rdone             ; gy is a word: 63 down to 0, and then -1
        jmp  .row               ;  turns the sign bit on and we are done
.rdone: ret

; ============================================================================
;  Hold - wait for a key. ESC never comes back.
; ============================================================================
Hold:  mov  ah, 0
        int  16h
        cmp  al, 27
        jne  .ok
        jmp  Bye                ; nothing on the stack matters now: the next
.ok:    ret                     ;  thing that happens is INT 21h/4Ch

; ============================================================================
;  State. Seven words, one flag and two maps.
; ============================================================================
rseed   dw 1                    ; the generator's whole memory
side    dw 0                    ; the current square's side, 32 down to 2
half    dw 0                    ; ...and half of it, where the new node goes
amp     dw 0                    ; the nudge, 128 down to 4
acc     dw 0                    ; the sum of four neighbours
gx      dw 0                    ; the loops' own counters
gy      dw 0
hmin    dw 0                    ; the stretch's two numbers
hrng    dw 0
isle    db 0                    ; 0 = grey build, 1 = the island

; The two maps are RESERVED, not declared: `rb` asks the assembler for room
; without putting 8192 bytes of zeros in the file. A .COM is handed the whole
; 64K segment whatever its size, and Fresh clears both before anything reads
; them - so the file stays under a kilobyte and the program still gets its
; eight.
hmap    rb 4096                 ; 64 columns of 64 heights
seen    rb 4096                 ; and one byte of picture-keeping each
