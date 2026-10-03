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
;  In C, the boot and the two walks below are:
;
;      int main(void)
;      {
;          rseed = bios_tick() | 1;
;          set_mode(0x13);  setpal();
;          fresh();  show();  hold();                /* four anchors        */
;          do {                                     /* one pass an octave  */
;              cool(); diam(); show(); hold();
;              cool(); squa(); show(); hold();
;              shrink();
;          } while (side > 1);
;          cool(); stretch(); show(); hold();
;          isle = 1;  show();                        /* the island, in bands */
;          for (;;) { hold(); gen(); show(); }      /* a new one per key    */
;      }
Boot:   cld                     ; string ops count UP (LODSB below)
        mov  ax, 40h            ; AX = 0040h, the BIOS data area. 0040:006C
        mov  es, ax             ; ES = 0040h    is a counter the timer bumps
        mov  ax, [es:6Ch]       ; AX = tick     18.2 times a second, the only
        or   ax, 1              ; AX |= 1       thing here that differs between
        mov  [rseed], ax        ; rseed = AX    two runs. Never zero: a
                                ;  generator that only MULTIPLIES is dead
                                ;  there. Ours also adds, so it would survive
                                ;  - but the day someone drops the +13849
                                ;  this instruction saves them, for free.
        mov  ax, 0013h          ; AX = 13h: 320x200, 256 colours
        int  10h                ; set_mode(0x13)
        mov  ax, VGA            ; AX = A000h
        mov  es, ax             ; ES = the screen, for the whole program.
                                ;  Nothing else is ever written through ES,
                                ;  so it is set once, here.
        call SetPal             ; setpal()

; ---- THE BUILD, one keypress a step ----------------------------------------
;  The same routines the fast path calls, stopped between each one so you
;  can see what it did. Nothing here is a demonstration mode: Diam and Squa
;  below ARE the generator.
        call Fresh              ; fresh()    - four anchors, 4092 of nothing
        call Show               ; show()
        call Hold               ; hold()     - wait for a key
.pass:  call Cool               ; cool()     - last step's orange goes grey
        call Diam               ; diam()     - the diamond step
        call Show               ; show()
        call Hold               ; hold()
        call Cool               ; cool()
        call Squa               ; squa()     - the square step
        call Show               ; show()
        call Hold               ; hold()
        call Shrink             ; shrink()   - half the square, half the nudge
        cmp  word [side], 1     ; side > 1 ?
        jg   .pass              ;   yes: another octave

        call Cool               ; cool()     - everything grey, so the only
        call Stretch            ; stretch()    thing that changes in the next
        call Show               ; show()       picture is CONTRAST
        call Hold               ; hold()

; ---- THE ISLAND, and then the flip-book ------------------------------------
        mov  byte [isle], 1     ; isle = 1: from here Show paints height bands
        call Show               ; show()
.roll:  call Hold               ; hold()     - any key mints another world.
        call Gen                ; gen()        Hold SPACE down and the keyboard's
        call Show               ; show()       own repeat rate turns this into a
        jmp  .roll              ; for (;;)     flip-book of worlds never seen

Bye:    mov  ax, 0003h          ; AX = 3: text mode back, the state we
        int  10h                ;  borrowed the machine in
        mov  ax, 4C00h          ; AH = 4Ch exit, AL = 0 the code
        int  21h                ; exit(0)

; ============================================================================
;  RND16 - the linear congruential generator. Out: AX = the new seed.
;  Preserves BX and DX, because every caller below is in the middle of
;  carrying a coordinate in one of them.
; ============================================================================
;  In C:
;
;      unsigned rnd16(void)
;      {
;          rseed = rseed * 25173 + 13849;      /* unsigned: wraps at 65536 */
;          return rseed;
;      }
;
;  In C the "mod 65536" is the type: an unsigned int throws the top away
;  by itself. In assembly it is which register you choose to keep.
RND16:  push bx                 ; keep BX and DX: every caller is carrying a
        push dx                 ;  coordinate in one of them
        mov  ax, [rseed]        ; AX = rseed
        mov  bx, 25173          ; BX = 25173
        mul  bx                 ; DX:AX = rseed * 25173 - all 32 bits of a
                                ;  16x16 multiply, whether you wanted them
        add  ax, 13849          ; AX += 13849. Any carry out of AX runs into
                                ;  DX, which we are about to abandon
        mov  [rseed], ax        ; rseed = AX: keeping only AX IS the mod
                                ;  65536. There is no DIV in this generator
        pop  dx                 ; DX back
        pop  bx                 ; BX back
        ret                     ; return rseed (in AX)

; ============================================================================
;  Idx - BX = x, DX = y  ->  BX = the byte's offset in the map.
;  Clobbers CX. These few instructions are the entire torus.
; ============================================================================
;  In C:   int idx(int x, int y) { return (x & 63) * 64 + (y & 63); }
;
;  hmap is one array of 4096 bytes, column by column: hmap[idx(x, y)].
Idx:    and  bx, 63             ; BX = x & 63: x mod 64. 64 is a power of two,
                                ;  so the remainder IS the low six bits - and
                                ;  a remainder that costs one AND is the
                                ;  reason the map is square and 64 wide
        mov  cl, 6              ; CL = 6
        shl  bx, cl             ; BX <<= 6: * 64, the start of column x. The
                                ;  8086 shifts by one or by CL, never by a
                                ;  constant - that arrived with the 286
        and  dx, 63             ; DX = y & 63: y mod 64, the same trick
        add  bx, dx             ; BX += y: the row inside the column
        ret                     ; return BX

; ---- HGET: BX = x, DX = y -> AL = height. BX and DX come back untouched ----
;  In C:   int hget(int x, int y) { return hmap[idx(x, y)]; }
HGET:   push dx                 ; keep x and y for the caller
        push bx                 ; keep x
        call Idx                ; BX = idx(x, y)
        mov  al, [hmap+bx]      ; AL = hmap[BX]
        pop  bx                 ; x back
        pop  dx                 ; y back
        ret                     ; return AL

; ---- HPUT: AL = height at BX = x, DX = y. Same promise about BX and DX ----
;  In C:   void hput(int x, int y, int h) { hmap[idx(x,y)] = h; seen[idx(x,y)] = 2; }
HPUT:   push dx                 ; keep x and y
        push bx                 ; keep x
        call Idx                ; BX = idx(x, y)
        mov  [hmap+bx], al      ; hmap[BX] = h
        mov  byte [seen+bx], 2  ; seen[BX] = 2. SEEN IS NOT PART OF THE
                                ;  ALGORITHM. It is
                                ;  one byte per node saying nothing (0),
                                ;  older (1) or written just now (2), and
                                ;  it exists so the picture can show you
                                ;  where the generator has been. Delete it
                                ;  and the islands are identical.
        pop  bx                 ; x back
        pop  dx                 ; y back
        ret                     ; return

; ============================================================================
;  Noise - AX = [acc]/4 + a random nudge, clamped to 0..255.
;  [acc] holds the sum of the four neighbours. Clobbers AX and BX.
; ============================================================================
;  In C:
;
;      int noise(void)                       /* acc = the four neighbours' sum */
;      {
;          int r = (rnd16() >> 8) & (amp - 1);   /* 0..amp-1, from the HIGH byte */
;          int h = acc / 4 + r - amp / 2;        /* the average, nudged either way */
;          if (h < 0)   h = 0;
;          if (h > 255) h = 255;
;          return h;
;      }
Noise:  call RND16              ; AX = rnd16()
        mov  al, ah             ; AL = the HIGH byte. The low byte of this
        xor  ah, ah             ; AX = that byte    generator has a period of
                                ;  512 - see the note at the top. This one
                                ;  instruction is the difference between a
                                ;  landscape and a pattern
        mov  bx, [amp]          ; BX = amp
        dec  bx                 ; BX = amp - 1: amp is a power of two, so
        and  ax, bx             ; AX &= amp - 1    this is a mask: 0..amp-1
        mov  bx, [amp]          ; BX = amp
        shr  bx, 1              ; BX = amp / 2
        sub  ax, bx             ; AX -= amp / 2: -amp/2 .. amp/2-1, as likely
                                ;  down as up, which keeps the island from
                                ;  drifting off the top of the range
        mov  bx, [acc]          ; BX = acc, the sum of four neighbours
        shr  bx, 1              ; BX /= 2   \  the average of four is a sum
        shr  bx, 1              ; BX /= 2   /  and two shifts. No divide
        add  ax, bx             ; AX = h = acc / 4 + nudge
        jns  .lo                ; h >= 0 ?  (JNS: the sign bit is clear)
        xor  ax, ax             ;   no: h = 0   - a height is one byte:
.lo:    cmp  ax, 255            ; h > 255 ?      clamp both ends
        jle  .hi                ;   no: h fits
        mov  ax, 255            ;   yes: h = 255
.hi:    ret                     ; return h (in AX)

; ============================================================================
;  Fresh - an empty map with four heights in it, and the coarsest grid.
; ============================================================================
;  In C:
;
;      void fresh(void)
;      {
;          side = 32;  amp = 128;
;          for (int i = 0; i < 4096; i++) hmap[i] = seen[i] = 0;
;          anchor(0, 0);  anchor(32, 0);  anchor(0, 32);  anchor(32, 32);
;      }
;      void anchor(int x, int y) { hput(x, y, ((rnd16() >> 8) & 127) + 64); }
Fresh:  mov  word [side], 32    ; side = 32: the first square is half the map
                                ;  across. On a torus its four corners are
                                ;  (0,0), (32,0), (0,32) and (32,32) - and
                                ;  each of those is the corner of four
                                ;  squares at once, because the map wraps
        mov  word [amp], 128    ; amp = 128: the first nudge is half the range
        xor  si, si             ; i = 0
.z:     mov  byte [hmap+si], 0  ; hmap[i] = 0
        mov  byte [seen+si], 0  ; seen[i] = 0
        inc  si                 ; i++
        cmp  si, 4096           ; i < 4096 ?
        jb   .z                 ;   yes: next
        xor  bx, bx             ; x = 0   \  anchor(0, 0)
        xor  dx, dx             ; y = 0   /
        call Anchor             ; hput(x, y, an anchor height)
        mov  bx, 32             ; x = 32  \  anchor(32, 0)
        xor  dx, dx             ; y = 0   /
        call Anchor             ; hput(x, y, an anchor height)
        xor  bx, bx             ; x = 0   \  anchor(0, 32)
        mov  dx, 32             ; y = 32  /
        call Anchor             ; hput(x, y, an anchor height)
        mov  bx, 32             ; x = 32  \  anchor(32, 32)
        mov  dx, 32             ; y = 32  /
        call Anchor             ; hput(x, y, an anchor height)
        ret                     ; return

Anchor: call RND16              ; AX = rnd16()
        mov  al, ah             ; AL = the high byte again, every time
        and  al, 127            ; AL &= 127: 0..127 ...
        add  al, 64             ; AL += 64:  ... shifted to 64..191. The
                                ;  anchors start in the middle of the range
                                ;  on purpose: an anchor at 250 has nowhere
                                ;  left to go up, and the map would flatten
                                ;  against the ceiling before the stretch
                                ;  could help it
        call HPUT               ; hput(x, y, AL)   - x and y still in BX, DX
        ret                     ; return

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
;  In C:
;
;      void diam(void)
;      {
;          int s = side, h = side / 2;
;          half = h;
;          for (gx = 0; gx < 64; gx += s)
;              for (gy = 0; gy < 64; gy += s) {
;                  acc = hget(gx, gy) + hget(gx + s, gy)
;                      + hget(gx + s, gy + s) + hget(gx, gy + s);
;                  hput(gx + h, gy + h, noise());
;              }
;      }
Diam:   mov  ax, [side]         ; AX = side
        shr  ax, 1              ; AX = side / 2
        mov  [half], ax         ; half = AX: h, needed by the square step too
        mov  word [gx], 0       ; gx = 0                      (outer for)
.x:     mov  word [gy], 0       ; gy = 0                      (inner for)
.y:     mov  bx, [gx]           ; x = gx    \  corner 1: (x, y)
        mov  dx, [gy]           ; y = gy    /
        call HGET               ; AL = hget(x, y)
        xor  ah, ah             ; AX = AL: heights are bytes, the sum of four
        mov  [acc], ax          ; acc = AX   needs ten bits, so it adds as words
        mov  bx, [gx]           ; x = gx
        add  bx, [side]         ; x = gx + s  - corner 2: (x+s, y)
        call HGET               ; AL = hget(x+s, y)
        xor  ah, ah             ; AX = AL
        add  [acc], ax          ; acc += AX
        mov  dx, [gy]           ; y = gy
        add  dx, [side]         ; y = gy + s  - corner 3: (x+s, y+s). BX is
        call HGET               ; AL = hget(x+s, y+s)   still x+s, because
        xor  ah, ah             ; AX = AL               HGET gives it back
        add  [acc], ax          ; acc += AX             unharmed
        mov  bx, [gx]           ; x = gx      - corner 4: (x, y+s)
        call HGET               ; AL = hget(x, y+s)
        xor  ah, ah             ; AX = AL
        add  [acc], ax          ; acc += AX
        call Noise              ; AX = noise(): the average of the four, nudged
        mov  bx, [gx]           ; x = gx
        add  bx, [half]         ; x = gx + h  \  the middle of the square
        mov  dx, [gy]           ; y = gy       >
        add  dx, [half]         ; y = gy + h  /
        call HPUT               ; hput(gx + h, gy + h, AX)
        mov  ax, [gy]           ; AX = gy
        add  ax, [side]         ; AX = gy + s
        mov  [gy], ax           ; gy += s
        cmp  ax, 64             ; gy < 64 ?
        jae  .ynext             ;   no: this column is done. A CONDITIONAL
        jmp  .y                 ;   yes: next    JUMP ON AN 8086 REACHES 127
.ynext:                         ;  BYTES AND NO FURTHER. This loop body is
        mov  ax, [gx]           ; AX = gx        longer than that, so the
        add  ax, [side]         ; AX = gx + s    condition is inverted and it
        mov  [gx], ax           ; gx += s        steps OVER a plain JMP, which
        cmp  ax, 64             ; gx < 64 ?      has no such limit. The 386
        jae  .xdone             ;   no: done     added a long conditional and
        jmp  .x                 ;   yes: next    FASM will quietly reach for
.xdone: ret                     ;  it - which is why the engine carries
                                ;  ENGINE\E_8086.INC to forbid it. In this
                                ;  one file it is written out by hand, in
                                ;  the four places it is needed

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
;  In C:
;
;      void squa(void)
;      {
;          int s = side, h = half;
;          for (gx = 0; gx < 64; gx += s)
;              for (gy = 0; gy < 64; gy += s) {
;                  acc = hget(gx, gy) + hget(gx + s, gy)            /* (x+h, y)  */
;                      + hget(gx + h, gy - h) + hget(gx + h, gy + h);
;                  hput(gx + h, gy, noise());
;                  acc = hget(gx, gy) + hget(gx, gy + s)            /* (x, y+h)  */
;                      + hget(gx - h, gy + h) + hget(gx + h, gy + h);
;                  hput(gx, gy + h, noise());
;              }
;      }
;
;  gy - h and gx - h go negative on the first row and column. hget's & 63
;  reads them off the far side of the map: the torus, with no code for it.
Squa:   mov  word [gx], 0       ; gx = 0                      (outer for)
.x:     mov  word [gy], 0       ; gy = 0                      (inner for)
.y:     mov  bx, [gx]           ; x = gx    \  ---- the midpoint at (x+h, y) ----
        mov  dx, [gy]           ; y = gy    /  west corner (x, y)
        call HGET               ; AL = hget(x, y)
        xor  ah, ah             ; AX = AL
        mov  [acc], ax          ; acc = AX
        mov  bx, [gx]           ; x = gx
        add  bx, [side]         ; x = gx + s   - east corner (x+s, y)
        call HGET               ; AL = hget(x+s, y)
        xor  ah, ah             ; AX = AL
        add  [acc], ax          ; acc += AX
        mov  bx, [gx]           ; x = gx
        add  bx, [half]         ; x = gx + h   - north centre (x+h, y-h): the
        mov  dx, [gy]           ; y = gy         square ABOVE this one, whose
        sub  dx, [half]         ; y = gy - h     centre the diamond step made a
        call HGET               ; AL = hget()    moment ago. On the first row
        xor  ah, ah             ; AX = AL        y-h is negative, and AND 63
        add  [acc], ax          ; acc += AX      reads it off the bottom of the
                                ;                map. The torus, no code for it
        mov  dx, [gy]           ; y = gy
        add  dx, [half]         ; y = gy + h   - south centre (x+h, y+h): ours
        call HGET               ; AL = hget(x+h, y+h)
        xor  ah, ah             ; AX = AL
        add  [acc], ax          ; acc += AX
        call Noise              ; AX = noise()
        mov  bx, [gx]           ; x = gx
        add  bx, [half]         ; x = gx + h
        mov  dx, [gy]           ; y = gy
        call HPUT               ; hput(gx + h, gy, AX)
        mov  bx, [gx]           ; x = gx    \  ---- and the midpoint at (x, y+h) ----
        mov  dx, [gy]           ; y = gy    /  north corner (x, y)
        call HGET               ; AL = hget(x, y)
        xor  ah, ah             ; AX = AL
        mov  [acc], ax          ; acc = AX
        mov  dx, [gy]           ; y = gy
        add  dx, [side]         ; y = gy + s   - south corner (x, y+s)
        call HGET               ; AL = hget(x, y+s)
        xor  ah, ah             ; AX = AL
        add  [acc], ax          ; acc += AX
        mov  bx, [gx]           ; x = gx
        sub  bx, [half]         ; x = gx - h   \  west centre (x-h, y+h)
        mov  dx, [gy]           ; y = gy        >
        add  dx, [half]         ; y = gy + h   /
        call HGET               ; AL = hget(x-h, y+h)
        xor  ah, ah             ; AX = AL
        add  [acc], ax          ; acc += AX
        mov  bx, [gx]           ; x = gx
        add  bx, [half]         ; x = gx + h   - east centre (x+h, y+h)
        call HGET               ; AL = hget(x+h, y+h)
        xor  ah, ah             ; AX = AL
        add  [acc], ax          ; acc += AX
        call Noise              ; AX = noise()
        mov  bx, [gx]           ; x = gx
        mov  dx, [gy]           ; y = gy
        add  dx, [half]         ; y = gy + h
        call HPUT               ; hput(gx, gy + h, AX)
        mov  ax, [gy]           ; AX = gy
        add  ax, [side]         ; AX = gy + s
        mov  [gy], ax           ; gy += s
        cmp  ax, 64             ; gy < 64 ?
        jae  .ynext             ;   no: column done   (over a JMP again -
        jmp  .y                 ;   yes: next          this body is twice as
.ynext:                         ;                      long as the diamond's)
        mov  ax, [gx]           ; AX = gx
        add  ax, [side]         ; AX = gx + s
        mov  [gx], ax           ; gx += s
        cmp  ax, 64             ; gx < 64 ?
        jae  .xdone             ;   no: done
        jmp  .x                 ;   yes: next column
.xdone: ret

; ============================================================================
;  Shrink - the next octave: half the square, half the nudge.
;  THIS ROUTINE IS THE LANDSCAPE. Shift the amplitude twice instead of once
;  and you get a smooth desert; take the shift out and you get static.
; ============================================================================
;  In C:   void shrink(void) { side = half;  amp = amp / 2;  if (amp < 4) amp = 4; }
Shrink: mov  ax, [half]         ; AX = half
        mov  [side], ax         ; side = half: the grid the next pass works
                                ;  on is the one this pass just filled
        mov  ax, [amp]          ; AX = amp
        shr  ax, 1              ; AX = amp / 2: the nudge halves with it
        cmp  ax, 4              ; amp / 2 < 4 ?
        jge  .ok                ;   no: the halving stands
        mov  ax, 4              ;   yes: AX = 4. A floor, because a nudge of
.ok:    mov  [amp], ax          ; amp = AX  zero would make the last pass a
        ret                     ;  plain average: ground varnished flat

; ============================================================================
;  Stretch - find the lowest and the highest the generator actually used,
;  and re-spread the whole map across 0..255.
; ============================================================================
;  In C:
;
;      void stretch(void)
;      {
;          int lo = 255, hi = 0;
;          for (int i = 0; i < 4096; i++) {           /* the range it used  */
;              if (hmap[i] < lo) lo = hmap[i];
;              if (hmap[i] > hi) hi = hmap[i];
;          }
;          if (hi == lo) return;                       /* flat: leave it     */
;          for (int i = 0; i < 4096; i++)              /* re-spread to 0..255 */
;              hmap[i] = (hmap[i] - lo) * 255 / (hi - lo);
;          rnd16();                                    /* the 4097th draw    */
;      }
Stretch:
        mov  al, 255            ; AL = lo = 255   \  two counters in one
        xor  ah, ah             ; AH = hi = 0      / register: both are bytes
        xor  si, si             ; i = 0
.mm:    mov  bl, [hmap+si]      ; BL = hmap[i]
        cmp  bl, al             ; hmap[i] < lo ?
        jae  .m1                ;   no: not a new low
        mov  al, bl             ;   yes: lo = hmap[i]
.m1:    cmp  bl, ah             ; hmap[i] > hi ?
        jbe  .m2                ;   no: not a new high
        mov  ah, bl             ;   yes: hi = hmap[i]
.m2:    inc  si                 ; i++
        cmp  si, 4096           ; i < 4096 ?
        jb   .mm                ;   yes: next
        mov  bl, ah             ; BL = hi
        sub  bl, al             ; BL = hi - lo: the range the map occupies
        jz   .done              ; if (hi == lo) return: a flat map would
                                ;  divide by zero, and the only honest
                                ;  answer for one is to leave it alone
        xor  bh, bh             ; BX = hi - lo
        mov  [hrng], bx         ; hrng = hi - lo
        xor  ah, ah             ; AX = lo
        mov  [hmin], ax         ; hmin = lo
        xor  si, si             ; i = 0
.sc:    mov  al, [hmap+si]      ; AL = hmap[i]
        xor  ah, ah             ; AX = hmap[i]
        sub  ax, [hmin]         ; AX = hmap[i] - lo: how far above the floor
        mov  cx, 255            ; CX = 255
        mul  cx                 ; DX:AX = (hmap[i] - lo) * 255. DX comes out
                                ;  zero - the biggest this can be is 255*255
        div  word [hrng]        ; AX = that / (hi - lo): 0..255, full scale.
                                ;  ONE MUL AND ONE DIV PER NODE, and they
                                ;  are here on purpose. 4096 of each, once
                                ;  per island. Lesson 4 said not to put
                                ;  them in the inner loop, and this is not
                                ;  the inner loop - it runs when a world is
                                ;  born, not when a frame is drawn.
        mov  [hmap+si], al      ; hmap[i] = AL
        inc  si                 ; i++
        cmp  si, 4096           ; i < 4096 ?
        jb   .sc                ;   yes: next
.done:  call RND16              ; rnd16(): THE 4097th DRAW, and the number is thrown
                                ;  away. An island is exactly 4096 random
                                ;  numbers; 4096 divides 65536, so island
                                ;  after island started 4096 steps apart on
                                ;  the same circle and the flip-book looped
                                ;  every eight frames. 4097 is odd, odd is
                                ;  coprime with a power of two, and a stride
                                ;  coprime with the period visits all of it.
        ret                     ; return

; ============================================================================
;  Gen - a whole island, no stopping. This is the routine a game calls.
; ============================================================================
;  In C:
;
;      void gen(void)
;      {
;          fresh();
;          do { diam(); squa(); shrink(); } while (side > 1);
;          stretch();
;      }
Gen:    call Fresh              ; fresh()
.p:     call Diam               ; diam()      \
        call Squa               ; squa()       > one octave
        call Shrink             ; shrink()    /
        cmp  word [side], 1     ; side > 1 ?
        jg   .p                 ;   yes: another
        call Stretch            ; stretch()
        ret                     ; return

; ============================================================================
;  Cool - every "written just now" becomes "was already there".
;  Presentation only, like SEEN itself.
; ============================================================================
;  In C:   for (i = 0; i < 4096; i++) if (seen[i] == 2) seen[i] = 1;
Cool:   mov  si, seen           ; SI = &seen[0]
        mov  cx, 4096           ; CX = 4096
.c:     cmp  byte [si], 2       ; *SI == 2 ?  ("written just now")
        jne  .n                 ;   no: leave it
        mov  byte [si], 1       ;   yes: *SI = 1  ("was already there")
.n:     inc  si                 ; SI++
        dec  cx                 ; CX--
        jnz  .c                 ; while (CX)
        ret                     ; return

; ============================================================================
;  SetPal - three ramps, written straight into the VGA DAC.
;
;  Port 3C8h takes the colour NUMBER to start at, then port 3C9h takes red,
;  green and blue - 0..63 each, and the index steps on by itself after every
;  third write. That is the whole protocol.
; ============================================================================
;  In C:
;
;      void setpal(void)
;      {
;          outp(0x3C8, 1);                              /* colours 1..6     */
;          for (i = 0; i < 18; i++) outp(0x3C9, PAL[i]);
;          outp(0x3C8, CGREY);                          /* 16..31: greys    */
;          for (i = 0; i < 16; i++) {
;              int v = i * 4 + 3;
;              outp(0x3C9, v); outp(0x3C9, v); outp(0x3C9, v);
;          }
;          outp(0x3C8, CEMBER);                         /* 32..47: embers   */
;          for (i = 0; i < 16; i++) {
;              outp(0x3C9, i * 2 + 32);                 /* red              */
;              outp(0x3C9, i);                          /* green            */
;              outp(0x3C9, 0);                          /* blue             */
;          }
;      }
;
;  Port 3C8h takes the colour NUMBER to start at, then port 3C9h takes red,
;  green and blue, 0..63 each, and steps the number on by itself after every
;  third write.
SetPal: mov  dx, 3C8h           ; DX = 3C8h, the DAC index port
        mov  al, 1              ; AL = 1: colours 1..6, the island
        out  dx, al             ; outp(0x3C8, 1)
        inc  dx                 ; DX = 3C9h, the DAC data port
        mov  si, PAL            ; SI = PAL
        mov  cx, 6*3            ; CX = 18: six colours, r g b each
.p:     lodsb                   ; AL = *SI++
        out  dx, al             ; outp(0x3C9, AL)
        dec  cx                 ; CX--
        jnz  .p                 ; while (CX)

        mov  dx, 3C8h           ; DX = 3C8h
        mov  al, CGREY          ; AL = 16: colours 16..31, sixteen greys
        out  dx, al             ; outp(0x3C8, 16)
        inc  dx                 ; DX = 3C9h
        xor  bx, bx             ; i = 0
.g:     mov  ax, bx             ; AX = i
        mov  cl, 2              ; CL = 2
        shl  ax, cl             ; AX = i * 4 ...
        add  al, 3              ; AL = i * 4 + 3: ... + 3, so the darkest land
        out  dx, al             ; outp(red)     is still visible against a
        out  dx, al             ; outp(green)   black nothing
        out  dx, al             ; outp(blue)
        inc  bx                 ; i++
        cmp  bx, 16             ; i < 16 ?
        jb   .g                 ;   yes: next grey

        mov  dx, 3C8h           ; DX = 3C8h
        mov  al, CEMBER         ; AL = 32: colours 32..47, the same sixteen, hot
        out  dx, al             ; outp(0x3C8, 32)
        inc  dx                 ; DX = 3C9h
        xor  bx, bx             ; i = 0
.e:     mov  ax, bx             ; AX = i
        add  ax, ax             ; AX = i * 2
        add  al, 32             ; AL = i * 2 + 32: red climbs 32..62 ...
        out  dx, al             ; outp(red)
        mov  ax, bx             ; AL = i: ... green a quarter as fast, 0..15 ...
        out  dx, al             ; outp(green)
        xor  al, al             ; AL = 0: ... and no blue at all. ONE COLOUR,
        out  dx, al             ; outp(blue)   ONE MEANING: orange = "this step"
        inc  bx                 ; i++
        cmp  bx, 16             ; i < 16 ?
        jb   .e                 ;   yes: next ember
        ret                     ; return

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
;  In C:
;
;      void show(void)
;      {
;          for (gy = 63; gy >= 0; gy--) {                  /* north up       */
;              unsigned char *at = screen + (ORGY + (63-gy)*3) * 320 + ORGX;
;              for (x = 0; x < 64; x++, at += 3) {
;                  int h = hmap[x*64 + gy], s = seen[x*64 + gy], c;
;                  if (isle)         c = band_of(h);      /* 1..6           */
;                  else if (s == 0)  c = 0;               /* never written  */
;                  else              c = (h >> 4) + s*16; /* grey or ember  */
;                  for (r = 0; r < 3; r++)                /* a 3x3 block    */
;                      at[r*320] = at[r*320+1] = at[r*320+2] = c;
;              }
;          }
;      }
Show:   mov  di, ORGY*W+ORGX    ; at = the map's top-left corner on the screen
        mov  word [gy], 63      ; gy = 63: the TOP row of the picture is the
                                ;  HIGHEST y in the map. North up, like every
                                ;  map ever printed, and the opposite of the
                                ;  way the screen counts
.row:   push di                 ; keep the row's start
        mov  si, [gy]           ; SI = gy: node (0, gy) lives at offset gy
        mov  dx, 64             ; DX = 64 nodes across. DX, not CX - CX is
                                ;  about to be needed for a shift, and the
                                ;  8086 will only shift by CL
.col:   mov  al, [hmap+si]      ; AL = h = hmap[SI]
        mov  bl, [seen+si]      ; BL = s = seen[SI]
        cmp  byte [isle], 0     ; isle ?
        jne  .band              ;   yes: colour by band
        or   bl, bl             ; s == 0 ?
        jnz  .lit               ;   no: s is 1 or 2, it has a height
        xor  al, al             ;   yes: c = 0, never written yet: black
        jmp  .paint             ; paint c
.lit:   mov  cl, 4              ; CL = 4
        shr  al, cl             ; AL = h >> 4: which of sixteen steps
        shl  bl, cl             ; BL = s << 4: seen 1 -> 16, seen 2 -> 32:
        add  al, bl             ; AL = c = step + ramp    which ramp. The two
        jmp  .paint             ;  ramps being sixteen apart is not a
                                ;  coincidence - it is what makes this one
                                ;  ADD instead of a branch
.band:  mov  ah, 1              ; AH = 1 (sea)    - the answer so far
        cmp  al, 88             ; h < 88 ?
        jb   .set               ;   yes: sea
        mov  ah, 2              ; AH = 2 (sand)
        cmp  al, 120            ; h < 120 ?
        jb   .set               ;   yes
        mov  ah, 3              ; AH = 3 (grass)
        cmp  al, 168            ; h < 168 ?
        jb   .set               ;   yes
        mov  ah, 4              ; AH = 4 (woods)
        cmp  al, 200            ; h < 200 ?
        jb   .set               ;   yes
        mov  ah, 5              ; AH = 5 (rock)
        cmp  al, 230            ; h < 230 ?
        jb   .set               ;   yes
        mov  ah, 6              ; AH = 6 (snow)  - the else
.set:   mov  al, ah             ; c = AH
.paint: mov  [es:di], al        ; at[0] = c      nine stores, no inner loop:
        mov  [es:di+1], al      ; at[1] = c      a 3x3 block is small enough
        mov  [es:di+2], al      ; at[2] = c      that the loop would cost
        mov  [es:di+W], al      ; at[320] = c    more than the copies
        mov  [es:di+W+1], al    ; at[321] = c
        mov  [es:di+W+2], al    ; at[322] = c
        mov  [es:di+W*2], al    ; at[640] = c
        mov  [es:di+W*2+1], al  ; at[641] = c
        mov  [es:di+W*2+2], al  ; at[642] = c
        add  si, 64             ; SI += 64: one node east is 64 bytes on
        add  di, CELL           ; at += 3: ...and three pixels right
        dec  dx                 ; DX--
        jz   .cdone             ; row done?   (over a JMP: the six colour
        jmp  .col               ;   no: next   bands alone put this body
.cdone: pop  di                 ; at = the row's start   past 127 bytes)
        add  di, CELL*W         ; at += 960: three scanlines down
        dec  word [gy]          ; gy--
        js   .rdone             ; gy < 0 ? done. gy is a word: 63 down to 0,
        jmp  .row               ;   no: next row   then -1 sets the sign bit
.rdone: ret

; ============================================================================
;  Hold - wait for a key. ESC never comes back.
; ============================================================================
;  In C:   void hold(void) { if (get_key() == ESC) exit(0); }
Hold:  mov  ah, 0              ; get_key()   (BIOS 16h, service 0: waits)
        int  16h                ; AL = the character
        cmp  al, 27             ; AL == ESC ?
        jne  .ok                ;   no: return
        jmp  Bye                ;   yes: exit. Nothing on the stack matters
.ok:    ret                     ;  now: the next thing is INT 21h/4Ch

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
