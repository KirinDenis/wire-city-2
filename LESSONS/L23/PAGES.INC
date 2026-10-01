{ ==========================================================================
   PAGE 1 - the scale. One square of the island, sixteen houses in it, and
   why the square could not simply get bigger: 64 x 1024 = 65536.
   Drawn at one cell = 64 units, so a house (128) is two cells and a
   street (128) is two cells: every corner lands on the paper's own lines.
   ========================================================================== }
procedure PageScale(upto: Integer);
var i, j : Integer;
begin
  Big(1, 1, INK, 'THE SCALE');
  Lab(1, 3, REDPEN, 'A house on lesson 16''s square would be one house to a hill.');
  Box(2, 5, 18, 21, PEN);
  Dim(CX(2), CX(18), CY(21.5));
  Lab(9, 22, PENCIL, '1024');
  Lab(20, 5, INK, 'ONE SQUARE OF THE ISLAND');
  Lab(20, 7, INK, '1024 units a side');
  Lab(20, 9, INK, 'the aeroplane: 11 a frame,');
  Lab(20, 10, INK, 'a square in 5 seconds,');
  Lab(20, 11, INK, 'the island in 5 minutes');
  if upto < 2 then Exit;

  for i := 0 to 3 do
    for j := 0 to 3 do
      FBox(3 + 4 * i, 6 + 4 * j, 5 + 4 * i, 8 + 4 * j, PEN, PEN);
  Lab(20, 13, PEN, 'SIXTEEN HOUSES, four by four:');
  Lab(20, 14, PEN, 'a house 128, a street 128.');
  Lab(20, 16, PEN, 'Each is 2/16 of the square,');
  Lab(20, 17, PEN, 'so every corner is a whole');
  Lab(20, 18, PEN, 'number of sixteenths.');
  if upto < 3 then Exit;

  Lab(1, 24, INK, 'Why not squares of 2048, then?');
  Lab(1, 25, REDPEN, '64 squares x 1024 = 65536 = ONE WORD.');
  Ring(1, 25, 19);
  Lab(1, 27, INK, 'Squares of 2048 need a seventeenth bit for every position.');
  Lab(1, 28, INK, 'So EVERYTHING ELSE is halved: the houses, the storeys, the hills.');
end;

{ ==========================================================================
   PAGE 2 - one house, three ways: plan, front, and isometric.
   One cell = 16 units: the house is 8 cells, a storey is 2, and the glass
   stands 1 to 3 and 5 to 7 cells along every wall.
   ========================================================================== }

{ the isometric drawing: x east, y up, z north, all in cells }
function IU(x, z: Real): Real;
begin IU := 30.5 + (x - z) * 0.6; end;

function IV(x, y, z: Real): Real;
begin IV := 11 + (x + z) * 0.3 - y * 0.7; end;

procedure PageHouse(upto: Integer);
var k : Integer;
    y0, y1 : Real;
begin
  Big(1, 1, INK, 'ONE HOUSE, THREE WAYS');

  Big(2, 4, INK, 'PLAN');
  Box(2, 6, 10, 14, PEN);
  Thick(CX(3), CY(6), CX(5), CY(6), GLASS);       { the glass, seen from }
  Thick(CX(7), CY(6), CX(9), CY(6), GLASS);       {  above: a line on    }
  Thick(CX(3), CY(14), CX(5), CY(14), GLASS);     {  each wall           }
  Thick(CX(7), CY(14), CX(9), CY(14), GLASS);
  Thick(CX(2), CY(7), CX(2), CY(9), GLASS);
  Thick(CX(2), CY(11), CX(2), CY(13), GLASS);
  Thick(CX(10), CY(7), CX(10), CY(9), GLASS);
  Thick(CX(10), CY(11), CX(10), CY(13), GLASS);
  Dim(CX(2), CX(10), CY(15.5));
  Lab(5, 16, PENCIL, '128');
  Lab(1, 18, INK, 'PLAN, from above: 128 by 128. The glass sits 1/8 to 3/8 and');
  Lab(1, 19, INK, '5/8 to 7/8 of the way along every wall.');
  if upto < 2 then Exit;

  Big(14, 4, INK, 'FRONT');
  FBox(14, 6, 22, 14, PAPER, PEN);
  for k := 1 to 3 do
    Axis(CX(14), CY(6 + 2 * k), CX(22), CY(6 + 2 * k), PENCIL, True);
  for k := 0 to 3 do
  begin
    FBox(15, 12.5 - 2 * k, 17, 13.5 - 2 * k, GLASS, GLASS);
    FBox(19, 12.5 - 2 * k, 21, 13.5 - 2 * k, GLASS, GLASS);
  end;
  Thick(CX(14), CY(6), CX(22), CY(6), PEN);
  DimV(CY(12), CY(14), CX(23));
  Lab(24, 13, PENCIL, '32');
  Lab(1, 21, INK, 'FRONT: a storey is 32. The glass runs from a quarter of it to');
  Lab(1, 22, INK, 'three quarters. Two panes a storey, and one to four storeys.');
  if upto < 3 then Exit;

  Big(26, 4, INK, 'ISO');
  FillQuad(IU(0, 0), IV(0, 8, 0), IU(8, 0), IV(8, 8, 0),              { the roof }
           IU(8, 8), IV(8, 8, 8), IU(0, 8), IV(0, 8, 8), PAPER, PEN);
  FillQuad(IU(8, 0), IV(8, 0, 0), IU(8, 0), IV(8, 8, 0),              { east wall }
           IU(8, 8), IV(8, 8, 8), IU(8, 8), IV(8, 0, 8), PAPER, PEN);
  FillQuad(IU(0, 8), IV(0, 0, 8), IU(0, 8), IV(0, 8, 8),              { north wall }
           IU(8, 8), IV(8, 8, 8), IU(8, 8), IV(8, 0, 8), PAPER, PEN);
  for k := 0 to 3 do
  begin
    y0 := 2 * k + 0.5;  y1 := 2 * k + 1.5;
    FillQuad(IU(8, 1), IV(8, y0, 1), IU(8, 1), IV(8, y1, 1),
             IU(8, 3), IV(8, y1, 3), IU(8, 3), IV(8, y0, 3), GLASS, GLASS);
    FillQuad(IU(8, 5), IV(8, y0, 5), IU(8, 5), IV(8, y1, 5),
             IU(8, 7), IV(8, y1, 7), IU(8, 7), IV(8, y0, 7), GLASS, GLASS);
    FillQuad(IU(1, 8), IV(1, y0, 8), IU(1, 8), IV(1, y1, 8),
             IU(3, 8), IV(3, y1, 8), IU(3, 8), IV(3, y0, 8), GLASS, GLASS);
    FillQuad(IU(5, 8), IV(5, y0, 8), IU(5, 8), IV(5, y1, 8),
             IU(7, 8), IV(7, y1, 8), IU(7, 8), IV(7, y0, 8), GLASS, GLASS);
  end;
  Lab(1, 24, INK, 'ISO: what the program really draws. The two walls that face');
  Lab(1, 25, INK, 'you, and the roof when you are above it. Never a third wall.');
  Lab(1, 27, REDPEN, 'One cell is 16 units: a house is 8 cells, a storey 2.');
end;

{ ==========================================================================
   PAGE 3 - a byte of fraction, and ADC.
   Heading 1: hsin 6, 6 x 11 = 66, 66/256 of a unit: a word keeps 0.
   camxf 200 + 100 = 300: keeps 44, CF = 1. -66 = FFBEh.
   ========================================================================== }
procedure PageFrac(upto: Integer);
begin
  Big(1, 1, INK, 'A BYTE OF FRACTION');
  Lab(1, 3, REDPEN, '11 units a frame. Heading 1 - one step of the stick:');
  Lab(2, 5, PEN, 'east   hsin x 11  =    6 x 11 =   66  =  66/256 of a unit');
  Lab(2, 6, PEN, 'north  hcos x 11  =  256 x 11 = 2816  =  exactly 11');
  Lab(2, 8, INK, 'A word keeps 0 and 11. The nose turned, and the aeroplane');
  Lab(2, 9, INK, 'flies on STRAIGHT. At heading 10 it is 3 degrees off its nose.');
  Thick(CX(30), CY(16), CX(30), CY(11), PEN);
  Dashed(CX(30), CY(16), CX(33), CY(11), REDPEN);
  Lab(22, 12, PEN, 'the path');
  Lab(22, 14, REDPEN, 'the nose');
  if upto < 2 then Exit;

  Lab(1, 17, GREY, 'SO A BYTE OF 1/256ths STANDS BESIDE THE WORD:');
  Lab(2, 19, PEN, 'add  [camxf],bl   200 + 100 = 300: the byte keeps 44, CF = 1');
  Lab(2, 20, PEN, 'adc  [camx],ax    camx + the whole units + CF');
  Lab(2, 21, INK, '44/256 left in the byte, 1 carried out of it: 300/256.');
  Lab(2, 22, REDPEN, 'Nothing is lost.');
  Ring(2, 22, 8);
  if upto < 3 then Exit;

  Lab(1, 24, REDPEN, 'ADC is ADD plus the carry flag - the one new instruction.');
  Lab(1, 25, INK, 'The trap: NOTHING between the ADD and the ADC may change CF.');
  Lab(1, 27, INK, 'Backwards works too. -66 is FFBEh: BEh is +190/256, FFh is -1,');
  Lab(1, 28, INK, 'and -1 + 190/256 = -66/256. Two''s complement adds back whole.');
end;

{ ==========================================================================
   PAGE 4 - which walls you see. VISFILL: four comparisons, in the world,
   measured from the square's own corner.
   ========================================================================== }
procedure PageWalls(upto: Integer);
begin
  Big(1, 1, INK, 'WHICH WALLS YOU SEE');
  Lab(1, 3, REDPEN, 'Decided in the WORLD, before anything turns. Four comparisons:');
  Box(14, 7, 22, 15, PEN);
  Lab(17, 10, PEN, 'plan');
  Dot(CX(6), CY(11), INK);
  Lab(5, 12, INK, 'eye');
  Dashed(CX(6), CY(11), CX(14), CY(7), PENCIL);
  Dashed(CX(6), CY(11), CX(14), CY(15), PENCIL);
  Thick(CX(14), CY(7), CX(14), CY(15), REDPEN);
  Lab(2, 18, PEN, 'hrx < a0*64   the eye west of the house:  the WEST wall');
  Lab(2, 19, PEN, 'hrx > a1*64   east of it:                 the EAST wall');
  Lab(2, 20, PEN, 'hrz < b0*64   south of it:                the SOUTH wall');
  Lab(2, 21, PEN, 'hrz > b1*64   north of it:                the NORTH wall');
  if upto < 2 then Exit;

  Thick(CX(14), CY(7), CX(14), CY(15), PAPER);    { the first eye's wall: }
  SetColor(PEN);                                  {  back to plain pen    }
  Line(CX(14), CY(7), CX(14), CY(15));
  Dot(CX(30), CY(16), INK);
  Lab(31, 16, INK, 'eye');
  Dashed(CX(30), CY(16), CX(22), CY(7), PENCIL);
  Dashed(CX(30), CY(16), CX(14), CY(15), PENCIL);
  Thick(CX(22), CY(7), CX(22), CY(15), REDPEN);
  Thick(CX(14), CY(15), CX(22), CY(15), REDPEN);
  Lab(1, 23, INK, 'Off a corner you see TWO walls. Never three, and the two never');
  Lab(1, 24, INK, 'cover each other. A convex box has no inside to get wrong.');
  if upto < 3 then Exit;

  Lab(1, 26, REDPEN, 'hrx = (camx + BIAS) AND 1023, minus da*1024: from the SQUARE.');
  Lab(1, 27, INK, 'The world''s x wraps at 65536, and the comparison would come out');
  Lab(1, 28, INK, 'backwards on the seam. One square never wraps.');
end;

{ ==========================================================================
   PAGE 5 - sixteen houses, far first. Middles 128 384 640 896, the eye at
   300: 172 84 340 596. Take the farther END: 3, 2, 0, 1.
   One cell = 32 units: the square is 32 cells, a house 4.
   ========================================================================== }
procedure PageOrder(upto: Integer);
begin
  Big(1, 1, INK, 'SIXTEEN HOUSES, FAR FIRST');
  Lab(1, 3, REDPEN, 'Lesson 16 said the houses would not be on a grid. They are.');
  Lab(1, 4, INK, 'And a grid can be sorted one axis at a time.');
  Axis(CX(2), CY(10), CX(34), CY(10), PENCIL, False);
  FBox(4, 8, 8, 10, PEN, PEN);
  FBox(12, 8, 16, 10, PEN, PEN);
  FBox(20, 8, 24, 10, PEN, PEN);
  FBox(28, 8, 32, 10, PEN, PEN);
  Lab(6, 6, PEN, '0');
  Lab(14, 6, PEN, '1');
  Lab(22, 6, PEN, '2');
  Lab(30, 6, PEN, '3');
  Lab(5, 11, PENCIL, '128');
  Lab(13, 11, PENCIL, '384');
  Lab(21, 11, PENCIL, '640');
  Lab(29, 11, PENCIL, '896');
  Lab(1, 11, PENCIL, '0');
  if upto < 2 then Exit;

  Dot(CX(2 + 300 / 32), CY(10), REDPEN);
  Lab(9, 13, REDPEN, 'the eye, 300');
  Lab(1, 15, INK, 'how far each middle is from it:');
  Lab(5, 16, INK, '172');
  Lab(14, 16, INK, '84');
  Lab(21, 16, INK, '340');
  Lab(29, 16, INK, '596');
  Lab(1, 18, INK, 'A V, with the eye at the bottom: the farthest is always an END.');
  if upto < 3 then Exit;

  Lab(2, 20, PEN, 'ends 0 and 3:  3 is farther.  3, and step in');
  Lab(2, 21, PEN, 'ends 0 and 2:  2 is farther.  2, and step in');
  Lab(2, 22, PEN, 'ends 0 and 1:  0 is farther.  0, and 1 is last');
  Lab(2, 24, REDPEN, 'order 3 2 0 1');
  Ring(2, 24, 7);
  Lab(1, 26, INK, 'Between two columns is a street of empty air. The house beyond');
  Lab(1, 27, INK, 'it can never cover the one on this side, so it goes down first.');
  Lab(1, 28, INK, 'Columns, then rows inside them: sixteen houses, no sort.');
end;
