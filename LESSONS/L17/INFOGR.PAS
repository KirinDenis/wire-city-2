{ ==========================================================================
  INFOGR.PAS - the opening infographic for lesson 11 (Diamond-Square, and
  the random number every terrain algorithm is built on).

     D:\BIN\TPC.EXE -B -UD:\UNITS INFOGR.PAS     (see MAKEINFO.BAT)

  NOT PART OF THE LESSON - the title sequence the video opens with. It
  carries everything the COM cannot say out loud: the menu of other
  algorithms, the arithmetic of the generator, and the two traps that cost
  us a day each.

  THE LADDER IT CLIMBS - and the order is the pilot's, 2026-09-15:
   - eight ways to make ground, and all of them need the same thing
   - why THIS one on an 8086: count the multiplies
   - the machine has no random number. There is no instruction.
   - the linear congruential generator: one multiply, one add, a memory
   - and "mod 65536" is free, because we simply do not look at DX
   - BUT THE LOW BITS ARE NOT RANDOM - drawn, bit by bit
   - the diamond step
   - the square step
   - halve the square, halve the nudge - and that is the landscape
   - the map is a torus, so it tiles
   - averaging flattens, so the generator ends with a stretch
   - 4096 draws an island, 4096 divides 65536, and it looped
   - what the run will show you
   - the closing card

  ONE COLOUR, ONE MEANING:
     white         a node that has a height, and the map itself
     yellow        the node being made right now, and the random nudge
     cyan          the random number, and everything made out of it
     green         what is cheap: adds, shifts, masks
     magenta       the ONE argued thing on the slide
     dark grey     what is thrown away, deferred, or not chosen

  THE MAPS ON THESE SLIDES ARE REAL. The same Diamond-Square, in Pascal,
  on the same 64x64 torus - so the torus slide and the stretch slide are
  showing the reader the actual thing and not an artist's impression.

  TP7 SCARS: a source line dies past 126 characters; a BGI string too wide
  for 640 pixels is refused outright. Cap1 <= 39 chars, Cap2 <= 78.

  Keys: any key = next step, ESC = leave early.
  INFOGR N starts at step N.

  Owlos - legacy software modernization - https://owlos.sk
  ========================================================================== }
program Infogr;
{$R-}
{$Q-}

uses Graph, Crt;

const
  BgCol  = Blue;
  MapC   = White;                    { a node that has a height            }
  NewC   = Yellow;                   { the node being made, and the nudge  }
  RndC   = LightCyan;                { the random number                   }
  CheapC = LightGreen;               { adds, shifts, masks                 }
  ArgC   = LightMagenta;             { the ONE argued thing                }
  GoneC  = DarkGray;                 { thrown away, deferred, not chosen   }

  MENU : array[0..7] of string[14] =
    ('VALUE', 'PERLIN', 'SIMPLEX', 'FAULTS',
     'PARTICLES', 'EROSION', 'VORONOI', 'DIAMOND-SQUARE');
  MENUD : array[0..7] of string[40] =
    ('random heights, smoothly blended',
     'random GRADIENTS, and a dot product',
     'Perlin again, on triangles',
     'a random line, one side of it raised',
     'grains dropped, and let roll downhill',
     'any of the above, plus running water',
     'nearest-point cells, not hills',
     'halve the square. Nudge the middle.');

var
  Map  : array[0..63, 0..63] of Byte;   { the island, raw                  }
  Raw  : array[0..63, 0..63] of Byte;   { ...before the stretch            }
  RSeed : Word;
  View  : Integer;
  Cap1, Cap2 : string;
  Step  : Integer;
  Ch    : Char;

{ ---- the generator, the same one the COM assembles -------------------- }

function Rnd: Word;
begin
  RSeed := RSeed * 25173 + 13849;
  Rnd := RSeed;
end;

function G(x, y: Integer): Integer;
begin
  G := Map[x and 63, y and 63];
end;

procedure P(x, y, v: Integer);
begin
  if v < 0 then v := 0;
  if v > 255 then v := 255;
  Map[x and 63, y and 63] := v;
end;

function Nudge(a: Integer): Integer;
begin
  Nudge := ((Rnd shr 8) and (a - 1)) - (a div 2);
end;

procedure GenMap;
var s, h, a, x, y, v, mn, mx: Integer;
begin
  for x := 0 to 63 do
    for y := 0 to 63 do Map[x, y] := 0;
  s := 32;  a := 128;
  P(0,  0,  64 + ((Rnd shr 8) and 127));
  P(32, 0,  64 + ((Rnd shr 8) and 127));
  P(0,  32, 64 + ((Rnd shr 8) and 127));
  P(32, 32, 64 + ((Rnd shr 8) and 127));
  while s > 1 do begin
    h := s div 2;
    x := 0;
    while x < 64 do begin
      y := 0;
      while y < 64 do begin
        v := (G(x,y) + G(x+s,y) + G(x,y+s) + G(x+s,y+s)) div 4;
        P(x+h, y+h, v + Nudge(a));
        y := y + s;
      end;
      x := x + s;
    end;
    x := 0;
    while x < 64 do begin
      y := 0;
      while y < 64 do begin
        v := (G(x,y) + G(x+s,y) + G(x+h,y-h) + G(x+h,y+h)) div 4;
        P(x+h, y, v + Nudge(a));
        v := (G(x,y) + G(x,y+s) + G(x-h,y+h) + G(x+h,y+h)) div 4;
        P(x, y+h, v + Nudge(a));
        y := y + s;
      end;
      x := x + s;
    end;
    s := h;  a := a div 2;
    if a < 4 then a := 4;
  end;
  for x := 0 to 63 do
    for y := 0 to 63 do Raw[x, y] := Map[x, y];
  mn := 255;  mx := 0;
  for x := 0 to 63 do
    for y := 0 to 63 do begin
      if Map[x,y] < mn then mn := Map[x,y];
      if Map[x,y] > mx then mx := Map[x,y];
    end;
  if mx = mn then Exit;
  for x := 0 to 63 do
    for y := 0 to 63 do
      Map[x, y] := LongInt(Map[x,y] - mn) * 255 div (mx - mn);
end;

{ ---- furniture -------------------------------------------------------- }

procedure Headline;
begin
  SetTextStyle(DefaultFont, HorizDir, 2);
  SetTextJustify(CenterText, TopText);
  SetColor(White);
  OutTextXY(320, 10, 'DIAMOND-SQUARE');
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetColor(LightCyan);
  OutTextXY(320, 36, 'a landscape out of a table of random numbers - and where the numbers come from');
end;

procedure Captions;
var S: string;
begin
  SetFillStyle(SolidFill, Black);
  Bar(0, 434, 639, 479);
  Str(Step, S);
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(RightText, TopText);
  SetColor(DarkGray);
  OutTextXY(634, 470, S);
  SetColor(Yellow);
  SetTextStyle(DefaultFont, HorizDir, 2);
  SetTextJustify(CenterText, TopText);
  OutTextXY(320, 440, Cap1);
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetColor(White);
  OutTextXY(320, 462, Cap2);
end;

procedure Small(x, y, c: Integer; s: string);
begin
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(c);
  OutTextXY(x, y, s);
end;

procedure Big(x, y, c: Integer; s: string);
begin
  SetTextStyle(DefaultFont, HorizDir, 2);
  SetTextJustify(LeftText, TopText);
  SetColor(c);
  OutTextXY(x, y, s);
end;

procedure Mid(x, y, c: Integer; s: string);
begin
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(CenterText, TopText);
  SetColor(c);
  OutTextXY(x, y, s);
end;

procedure Node(x, y, c: Integer);
begin
  SetFillStyle(SolidFill, c);
  Bar(x - 4, y - 4, x + 4, y + 4);
end;

procedure Arrow(x1, y1, x2, y2, c: Integer);
var dx, dy: Real; L: Real;
begin
  SetColor(c);
  Line(x1, y1, x2, y2);
  dx := x2 - x1;  dy := y2 - y1;
  L := Sqrt(dx * dx + dy * dy);
  if L < 1 then Exit;
  dx := dx / L;  dy := dy / L;
  Line(x2, y2, Round(x2 - 9 * dx - 4 * dy), Round(y2 - 9 * dy + 4 * dx));
  Line(x2, y2, Round(x2 - 9 * dx + 4 * dy), Round(y2 - 9 * dy - 4 * dx));
end;

{ draw the map at (gx,gy), one node = px pixels, in 16 greys of blue      }
procedure DrawMap(gx, gy, px: Integer; stretched: Boolean);
var x, y, v: Integer;
begin
  for x := 0 to 63 do
    for y := 0 to 63 do begin
      if stretched then v := Map[x, y] else v := Raw[x, y];
      v := v shr 6;                        { 0..3: BGI has sixteen colours }
      case v of
        0: SetFillStyle(SolidFill, Black);
        1: SetFillStyle(SolidFill, DarkGray);
        2: SetFillStyle(SolidFill, LightGray);
      else SetFillStyle(SolidFill, White);
      end;
      Bar(gx + x * px, gy + (63 - y) * px, gx + x * px + px - 1,
          gy + (63 - y) * px + px - 1);
    end;
end;

{ ---- the slides ------------------------------------------------------- }

procedure VMenu;
var i, y: Integer;
begin
  for i := 0 to 7 do begin
    y := 78 + i * 42;
    if i = 7 then begin
      SetColor(ArgC);
      Rectangle(46, y - 8, 620, y + 24);
      Big(60, y, ArgC, MENU[i]);
      Small(310, y + 6, White, MENUD[i]);
    end
    else begin
      Big(60, y, GoneC, MENU[i]);
      Small(310, y + 6, LightGray, MENUD[i]);
    end;
  end;
end;

procedure VCost;
var i: Integer;
begin
  SetColor(GoneC);
  Rectangle(40, 80, 310, 400);
  Big(60, 96, GoneC, 'PERLIN');
  Small(60, 140, LightGray, 'per SAMPLE, not per node:');
  Small(60, 166, LightGray, '  4 corner gradients');
  Small(60, 184, LightGray, '  a dot product with each');
  Small(60, 202, LightGray, '  = 8 multiplies');
  Small(60, 220, LightGray, '  then a blend in x, in y');
  Small(60, 256, GoneC, 'MUL on an 8086:');
  Small(60, 274, GoneC, 'about 120 clocks. Each.');
  SetFillStyle(SolidFill, GoneC);
  Bar(60, 310, 290, 340);
  Small(60, 350, GoneC, 'what it costs, to scale');

  SetColor(ArgC);
  Rectangle(330, 80, 600, 400);
  Big(350, 96, ArgC, 'DIAMOND-SQUARE');
  Small(350, 140, White, 'per NODE, and there are 4096:');
  Small(350, 166, CheapC, '  4 adds');
  Small(350, 184, CheapC, '  2 shifts (the divide by four)');
  Small(350, 202, CheapC, '  1 and  (the divide by amp)');
  Small(350, 220, RndC,   '  1 random number');
  Small(350, 256, ArgC, 'NOT ONE MULTIPLY, and');
  Small(350, 274, ArgC, 'nothing between nodes to ask about.');
  SetFillStyle(SolidFill, CheapC);
  Bar(350, 310, 366, 340);
  Small(350, 350, CheapC, 'what it costs, to the same scale');
end;

procedure VNoRnd;
begin
  Big(100, 110, White, 'MOV  AX, ?');
  SetColor(GoneC);
  Rectangle(80, 96, 440, 148);
  Line(80, 96, 440, 148);
  Small(70, 166, LightGray, 'There is no instruction. There is no chip to ask. Nothing in');
  Small(70, 184, LightGray, 'this machine is uncertain - that is what a computer IS.');

  Big(70, 240, ArgC, 'SO WE BUILD ONE.');
  Small(70, 284, White, 'Out of the instructions there ARE: one multiply, one add,');
  Small(70, 302, White, 'and sixteen bits of memory holding the last answer.');
  Small(70, 338, RndC, 'It is not random. It is a sequence nobody can see the pattern');
  Small(70, 356, RndC, 'in, which for a landscape is the same thing - and being');
  Small(70, 374, RndC, 'repeatable is a FEATURE: a whole world, shipped as one number.');
end;

procedure VLcg;
var i, x: Integer; v: Word; S: string;
begin
  Big(80, 110, White, 'seed = seed * 25173 + 13849');
  Small(288, 148, RndC, 'the multiplier');
  Small(440, 176, RndC, 'the increment');
  Arrow(344, 146, 344, 130, RndC);
  Arrow(472, 174, 472, 130, RndC);
  Small(80, 190, LightGray, 'Every number is made out of the one before it. That is all a');
  Small(80, 208, LightGray, 'LINEAR CONGRUENTIAL GENERATOR is, and the whole of it fits');
  Small(80, 226, LightGray, 'in a single 16-bit word.');

  RSeed := 1;
  Small(80, 270, White, 'starting at 1, it says:');
  for i := 0 to 7 do begin
    v := Rnd;
    Str(v, S);
    x := 80 + i * 68;
    SetColor(RndC);
    Rectangle(x, 296, x + 60, 322);
    Small(x + 6, 304, RndC, S);
  end;
  Arrow(80, 344, 620, 344, GoneC);
  Small(230, 352, GoneC, 'and 65536 of them before it comes back here');
end;

procedure VMod;
begin
  Small(70, 96, White, 'MUL BX  -  the 8086 gives you all 32 bits, asked for or not');
  SetColor(GoneC);
  Rectangle(120, 130, 340, 190);
  SetColor(RndC);
  Rectangle(340, 130, 560, 190);
  Big(190, 148, GoneC, 'DX');
  Big(415, 148, RndC, 'AX');
  Small(120, 200, GoneC, 'the top half');
  Small(340, 200, RndC, 'the bottom half');

  Line(120, 130, 340, 190);
  Line(340, 130, 120, 190);

  Big(120, 250, ArgC, 'THROWING DX AWAY');
  Big(120, 278, ArgC, 'IS THE "MOD 65536".');
  Small(120, 322, White, 'There is no DIV in this generator, and no AND either. The');
  Small(120, 340, White, 'remainder is what is left in the register when you decline');
  Small(120, 358, White, 'to look at the other one.');
  Small(120, 392, CheapC, 'A modulus that is a power of two is never a division.');
end;

procedure VBits;
var i, b, x, y: Integer; v: Word;
begin
  RSeed := 1;
  Small(64, 70, White, 'twenty-four draws, written out in binary - high bit on the left');
  for i := 0 to 23 do begin
    v := Rnd;
    y := 92 + i * 12;
    for b := 0 to 15 do begin
      x := 64 + (15 - b) * 24;
      if (v shr b) and 1 = 1 then begin
        if b >= 8 then SetFillStyle(SolidFill, RndC)
                  else SetFillStyle(SolidFill, NewC);
        Bar(x, y, x + 18, y + 9);
      end
      else begin
        SetColor(GoneC);
        Rectangle(x, y, x + 18, y + 9);
      end;
    end;
  end;
  SetColor(RndC);
  Rectangle(62, 88, 64 + 8 * 24 - 4, 92 + 24 * 12);
  Small(66, 384, RndC, 'the HIGH byte: the one we take');
  Small(64 + 8 * 24, 384, NewC, 'the low byte: look down these columns');
  Small(64 + 12 * 24, 402, NewC, '16');
  Small(64 + 13 * 24, 402, NewC, '8');
  Small(64 + 14 * 24, 402, NewC, '4');
  Small(64 + 15 * 24, 402, NewC, '2');
  Small(140, 402, NewC, 'these repeat every:');
end;

procedure VDiamond;
var cx, cy, r: Integer;
begin
  cx := 250;  cy := 230;  r := 120;
  SetColor(GoneC);
  Rectangle(cx - r, cy - r, cx + r, cy + r);
  Node(cx - r, cy - r, MapC);
  Node(cx + r, cy - r, MapC);
  Node(cx - r, cy + r, MapC);
  Node(cx + r, cy + r, MapC);
  Arrow(cx - r + 12, cy - r + 12, cx - 14, cy - 14, MapC);
  Arrow(cx + r - 12, cy - r + 12, cx + 14, cy - 14, MapC);
  Arrow(cx - r + 12, cy + r - 12, cx - 14, cy + 14, MapC);
  Arrow(cx + r - 12, cy + r - 12, cx + 14, cy + 14, MapC);
  Node(cx, cy, NewC);
  Small(cx - r - 10, cy - r - 22, MapC, 'a');
  Small(cx + r - 4, cy - r - 22, MapC, 'b');
  Small(cx - r - 10, cy + r + 12, MapC, 'c');
  Small(cx + r - 4, cy + r + 12, MapC, 'd');
  Small(cx + 12, cy - 6, NewC, 'new');

  Small(430, 120, White, 'the four corners are');
  Small(430, 138, White, 's apart. The centre');
  Small(430, 156, White, 'sits h = s/2 in from');
  Small(430, 174, White, 'each of them.');
  Big(430, 214, NewC, '(a+b+c+d)');
  SetColor(NewC);
  Line(430, 240, 580, 240);
  Big(490, 244, NewC, '4');
  Big(430, 282, NewC, '+ nudge');
  Small(430, 330, CheapC, 'three adds and two');
  Small(430, 348, CheapC, 'shifts. The four-way');
  Small(430, 366, CheapC, 'average of bytes is');
  Small(430, 384, CheapC, 'never a division.');
end;

procedure VSquare;
var cx, cy, r: Integer;
begin
  cx := 250;  cy := 230;  r := 120;
  SetColor(GoneC);
  Rectangle(cx - r, cy - r, cx + r, cy + r);
  Rectangle(cx - r, cy - r - 2 * r, cx + r, cy - r);
  Node(cx - r, cy - r, MapC);
  Node(cx + r, cy - r, MapC);
  Node(cx - r, cy + r, MapC);
  Node(cx + r, cy + r, MapC);
  Node(cx, cy, MapC);
  Node(cx, cy - 2 * r, MapC);
  SetColor(NewC);
  Line(cx - r, cy - r, cx, cy);
  Line(cx, cy, cx + r, cy - r);
  Line(cx + r, cy - r, cx, cy - 2 * r);
  Line(cx, cy - 2 * r, cx - r, cy - r);
  Node(cx, cy - r, NewC);
  Small(cx + 12, cy - r - 6, NewC, 'new');

  Small(430, 120, White, 'the four points around');
  Small(430, 138, White, 'an EDGE midpoint are');
  Small(430, 156, White, 'two old corners and');
  Small(430, 174, White, 'two centres the diamond');
  Small(430, 192, White, 'step has just made.');
  Small(430, 228, NewC, 'They form a square');
  Small(430, 246, NewC, 'standing on its corner -');
  Small(430, 264, NewC, 'hence the name.');
  Small(430, 306, ArgC, 'And hence the order:');
  Small(430, 324, ArgC, 'this step cannot run');
  Small(430, 342, ArgC, 'before the other one.');
  Small(430, 378, GoneC, 'off the top of the map?');
  Small(430, 396, GoneC, 'See two slides on.');
end;

procedure VOct;
var i, n, gx, gy, k, sp, aw: Integer; S: string;
begin
  for i := 0 to 4 do begin
    n := 2;
    for k := 1 to i do n := n * 2;           { 2, 4, 8, 16, 32 }
    gx := 40 + i * 120;
    gy := 96;
    SetColor(GoneC);
    Rectangle(gx, gy, gx + 96, gy + 96);
    sp := 96 div n;
    for k := 0 to n - 1 do begin
      SetFillStyle(SolidFill, MapC);
      for aw := 0 to n - 1 do
        Bar(gx + k * sp, gy + aw * sp, gx + k * sp + 2, gy + aw * sp + 2);
    end;
    Str(n, S);
    Small(gx, gy + 104, White, S + ' x ' + S);
    aw := 96;
    for k := 1 to i do aw := aw div 2;
    SetFillStyle(SolidFill, NewC);
    Bar(gx, gy + 140, gx + aw, gy + 164);
    Str(128 shr i, S);
    Small(gx, gy + 172, NewC, 'nudge ' + S);
  end;
  Small(40, 300, White, 'The grid doubles. The nudge halves. Five passes and all 4096 nodes');
  Small(40, 318, White, 'have a height - the first ones placed with a nudge of 128, the last');
  Small(40, 336, White, 'with a nudge of 4.');
  Small(40, 372, ArgC, 'DETAIL THAT SHRINKS AS FAST AS THE DISTANCE BETWEEN THE POINTS');
  Small(40, 390, ArgC, 'CARRYING IT. That is what ground does, and it is the whole recipe.');
end;

procedure VTorus;
begin
  DrawMap(60, 80, 2, True);
  DrawMap(60 + 128, 80, 2, True);
  DrawMap(60, 80 + 128, 2, True);
  DrawMap(60 + 128, 80 + 128, 2, True);
  SetColor(NewC);
  Rectangle(60, 80, 60 + 127, 80 + 127);
  Arrow(200, 60, 120, 78, NewC);
  Small(206, 54, NewC, 'one map');
  Small(60, 350, White, 'four copies of the SAME 64x64 map, and you cannot find the seam');

  Small(400, 100, White, 'Every coordinate is');
  Small(400, 118, White, 'masked before it is used:');
  Big(400, 148, CheapC, 'AND 63');
  Small(400, 190, White, 'so 64 means 0, and -1');
  Small(400, 208, White, 'means 63.');
  Small(400, 244, ArgC, 'There is no code for the');
  Small(400, 262, ArgC, 'edges because there are');
  Small(400, 280, ArgC, 'no edges. The left edge');
  Small(400, 298, ArgC, 'IS the right edge.');
  Small(400, 334, CheapC, 'One instruction, and the');
  Small(400, 352, CheapC, 'whole special case is');
  Small(400, 370, CheapC, 'gone. It is why the map');
  Small(400, 388, CheapC, 'is 64 wide and not 60.');
end;

procedure Histo(gx, gy: Integer; stretched: Boolean; c: Integer);
var h: array[0..31] of Integer;
    x, y, i, v, mx: Integer;
begin
  for i := 0 to 31 do h[i] := 0;
  for x := 0 to 63 do
    for y := 0 to 63 do begin
      if stretched then v := Map[x, y] else v := Raw[x, y];
      Inc(h[v shr 3]);
    end;
  mx := 1;
  for i := 0 to 31 do if h[i] > mx then mx := h[i];
  SetColor(GoneC);
  Rectangle(gx, gy, gx + 32 * 7, gy + 110);
  SetFillStyle(SolidFill, c);
  for i := 0 to 31 do begin
    v := LongInt(h[i]) * 106 div mx;
    if v > 0 then Bar(gx + i * 7 + 1, gy + 109 - v, gx + i * 7 + 6, gy + 109);
  end;
  Small(gx, gy + 116, GoneC, '0');
  Small(gx + 32 * 7 - 24, gy + 116, GoneC, '255');
end;

procedure VStretch;
begin
  DrawMap(40, 84, 2, False);
  Small(40, 216, White, 'the map the generator made');
  Histo(40, 244, False, GoneC);
  Small(40, 384, GoneC, 'every height crowded into the middle');

  Arrow(300, 200, 350, 200, ArgC);
  Small(286, 210, ArgC, 'stretch');

  DrawMap(400, 84, 2, True);
  Small(400, 216, White, 'the same map, re-spread');
  Histo(400, 244, True, White);
  Small(400, 384, White, 'the same shape, the full range');

  Small(40, 60, LightGray, 'Averaging pulls everything toward the middle: four numbers near 128');
  Small(40, 410, ArgC, 'MUL and DIV, 4096 of each - once per ISLAND, not once per pixel.');
end;

procedure Ring(cx, cy, r, stride, n, c: Integer);
var i: Integer; p: LongInt; a: Real;
begin
  SetColor(GoneC);
  Circle(cx, cy, r);
  p := 0;
  SetFillStyle(SolidFill, c);
  for i := 0 to n - 1 do begin
    a := p * 2 * Pi / 65536.0;
    Bar(Round(cx + r * Sin(a)) - 2, Round(cy - r * Cos(a)) - 2,
        Round(cx + r * Sin(a)) + 2, Round(cy - r * Cos(a)) + 2);
    p := (p + stride) mod 65536;
  end;
end;

procedure VRes;
begin
  Small(60, 66, White, 'the generator''s 65536 states, drawn as a circle. Each dot is where');
  Small(60, 84, White, 'one island started.');

  Ring(180, 230, 100, 4096, 16, GoneC);
  Mid(180, 344, GoneC, 'stride 4096');
  Mid(180, 362, GoneC, 'an island is EXACTLY 4096 draws');
  Mid(180, 380, ArgC, 'sixteen stops, then it repeats');

  Ring(460, 230, 100, 4097, 400, RndC);
  Mid(460, 344, RndC, 'stride 4097');
  Mid(460, 362, RndC, 'one extra draw, thrown away');
  Mid(460, 380, CheapC, 'odd, so coprime: all 65536');

  Arrow(300, 230, 350, 230, ArgC);
  Mid(325, 240, ArgC, '+1');
end;

procedure VRun;
begin
  Small(70, 80, White, 'TERRAIN.COM - a key moves it on one step');
  SetColor(GoneC);
  Line(70, 100, 570, 100);
  Small(70, 118, NewC, '1');
  Small(110, 118, White, 'four anchors, and 4092 nodes of nothing');
  Small(70, 148, NewC, '2 - 11');
  Small(110, 148, White, 'five octaves: diamond, then square, ten steps');
  Small(110, 166, ArgC, 'what each step wrote burns orange, and cools to grey');
  Small(70, 202, NewC, '12');
  Small(110, 202, White, 'the stretch - same map, contrast opened up');
  Small(70, 232, NewC, '13');
  Small(110, 232, White, 'the island, in six colour bands');
  Small(70, 268, NewC, 'then');
  Small(110, 268, White, 'every key mints another world. HOLD SPACE DOWN.');
  Small(70, 298, NewC, 'ESC');
  Small(110, 298, White, 'back to DOS');
  SetColor(GoneC);
  Line(70, 330, 570, 330);
  Small(70, 348, GoneC, 'And what it does NOT do: draw the ground as ground. That needs the');
  Small(70, 366, GoneC, 'camera of the last lesson pointed at 4096 points, and something');
  Small(70, 384, GoneC, 'honest to say about the ones that end up behind the viewer.');
  Small(70, 402, GoneC, 'Next lesson.');
end;

procedure VFinal;
begin
  SetTextStyle(DefaultFont, HorizDir, 3);
  SetTextJustify(CenterText, CenterText);
  SetColor(CheapC);
  OutTextXY(320, 140, 'FOUR ADDS.');
  OutTextXY(320, 185, 'TWO SHIFTS.');
  SetColor(RndC);
  OutTextXY(320, 230, 'ONE RANDOM NUMBER.');
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetColor(White);
  OutTextXY(320, 288, 'per node, four thousand and ninety-six times');
  SetColor(ArgC);
  OutTextXY(320, 316, 'and out comes a world that has never existed before');
  SetColor(GoneC);
  OutTextXY(320, 344, 'a game does not ship a world. It ships the recipe for one.');
end;

procedure DrawAll;
begin
  SetFillStyle(SolidFill, BgCol);
  Bar(0, 0, 639, 479);
  if View <> 13 then Headline;
  case View of
     0: VMenu;
     1: VCost;
     2: VNoRnd;
     3: VLcg;
     4: VMod;
     5: VBits;
     6: VDiamond;
     7: VSquare;
     8: VOct;
     9: VTorus;
    10: VStretch;
    11: VRes;
    12: VRun;
  else  VFinal;
  end;
  Captions;
end;

procedure SetStep(N: Integer);
begin
  View := N;
  case N of
    0: begin
         Cap1 := 'Eight ways to make ground.';
         Cap2 := 'Every one of them needs the same thing first, and this machine has not got it.';
       end;
    1: begin
         Cap1 := 'Count the multiplies.';
         Cap2 := 'Lesson 4 spent ten minutes on why MUL is the instruction you cannot afford.';
       end;
    2: begin
         Cap1 := 'The machine has no random number.';
         Cap2 := 'There is no instruction for it, and there is nothing uncertain to ask.';
       end;
    3: begin
         Cap1 := 'One multiply, one add, a memory.';
         Cap2 := 'Give it the same seed and you get the same world - on any machine, for ever.';
       end;
    4: begin
         Cap1 := 'And "mod 65536" is free.';
         Cap2 := 'The multiply already split the answer in two. We decline to look at the top.';
       end;
    5: begin
         Cap1 := 'But the low bits are not random.';
         Cap2 := 'Bit 0 alternates. Bit 1 has period four. Bit k repeats every 2^(k+1) draws.';
       end;
    6: begin
         Cap1 := 'The diamond step: fill the middle.';
         Cap2 := 'The average of four corners, plus a random nudge. No multiply, no divide.';
       end;
    7: begin
         Cap1 := 'The square step: fill the edges.';
         Cap2 := 'The average of the four points around an edge midpoint, plus a nudge.';
       end;
    8: begin
         Cap1 := 'Halve the square. Halve the nudge.';
         Cap2 := 'That second halving is the only thing here deciding what ground looks like.';
       end;
    9: begin
         Cap1 := 'The map has no edges.';
         Cap2 := 'One AND makes it a torus, and a torus tiles - which is why there is no seam.';
       end;
   10: begin
         Cap1 := 'Averaging flattens. So: stretch.';
         Cap2 := 'Find the lowest and the highest actually used, and re-spread them over 0..255.';
       end;
   11: begin
         Cap1 := 'Two islands in, it repeated.';
         Cap2 := 'An island is 4096 draws and 4096 divides 65536. One more draw fixed it.';
       end;
   12: begin
         Cap1 := 'Now watch it happen.';
         Cap2 := 'Thirteen steps, and then it mints a new world for every key you hold down.';
       end;
   13: begin
         Cap1 := 'A recipe, not a world.';
         Cap2 := 'Now the source - and it is one file, and it includes nothing.';
       end;
  end;
end;

var Gd, Gm, S0, EC: Integer;
    LF: Text;
begin
  Assign(LF, 'INFOGR.LOG');
  Rewrite(LF);
  S0 := 0;
  if ParamCount > 0 then begin
    Val(ParamStr(1), S0, EC);
    if (EC <> 0) or (S0 < 0) or (S0 > 13) then S0 := 0;
  end;
  RSeed := 27077;                    { the deck's island is always the same:
                                       the frames must match the narration }
  GenMap;
  Gd := VGA; Gm := VGAHi;
  InitGraph(Gd, Gm, 'D:\BGI');
  if GraphResult <> grOk then begin
    WriteLn('EGAVGA.BGI not found - mount Borland Pascal as D: (MAKEINFO.BAT does).');
    Halt(1);
  end;
  for Step := 0 to 13 do begin
    SetStep(Step);
    if Step < S0 then Continue;
    DrawAll;
    while KeyPressed do Ch := ReadKey;
    Ch := ReadKey;
    WriteLn(LF, 'step=', Step, ' key=', Ord(Ch));
    if Ch = #27 then Break;
    if Ch = #0 then Ch := ReadKey;
  end;
  Close(LF);
  CloseGraph;
end.
