{ ==========================================================================
   PAGE 6 - a town plan, and no map of it.
   (20,37): 1317 -> 1562h, a park. (20,38): 1318 -> 77B7h, built; its
   sixteen houses, storeys worked out by the program's own sum.
   ========================================================================== }
procedure PageHash(upto: Integer);
const
  { storeys of the sixteen houses of square (20,38), house n = column*4 +
    row; 0 is an empty plot. Worked out with HOUSE's own arithmetic. }
  ST : array[0..15] of Integer = (0, 3, 1, 0, 2, 4, 3, 1, 3, 2, 4, 2, 1, 3, 1, 4);
var c, r, n : Integer;
begin
  Big(1, 1, INK, 'A TOWN PLAN, NO MAP');
  Lab(1, 3, REDPEN, 'The town is not stored anywhere. It is worked out on the spot.');
  Lab(2, 5, PEN, 'square (20,37):   20*64 + 37 = 1317');
  Lab(2, 6, PEN, '1317 x 25173 + 13849, the low word:   1562h');
  Lab(2, 7, PEN, '1562h = 0001 0101 0110 0010');
  Lab(2, 8, REDPEN, 'top two bits 00: a PARK');
  Ring(2, 8, 12);
  if upto < 2 then Exit;

  Lab(2, 10, PEN, 'square (20,38):   1318  ->  77B7h,  top bits 01: built');
  Lab(2, 11, PEN, 'house 5 of it:    (5 x 40503 + 77B7h) x 25173 + 13849');
  Lab(2, 12, PEN, '                  -> F32Bh.  F3h = 1111 0011');
  Lab(2, 13, INK, '                  top two bits 11: 4 storeys');
  Lab(2, 14, INK, '                  bits 5 4 3 = 110, not 000: a house');
  for c := 0 to 3 do
    for r := 0 to 3 do
    begin
      n := c * 4 + r;
      if ST[n] = 0 then Lab(2 + 2 * c + 1, 24 - 2 * r, PENCIL, '.')
      else Lab(2 + 2 * c + 1, 24 - 2 * r, PEN, Chr(Ord('0') + ST[n]));
    end;
  Box(2, 17, 10, 25, PENCIL);
  Lab(12, 18, INK, 'n = column*4 + row.');
  Lab(12, 19, INK, 'A dot: one plot in eight');
  Lab(12, 20, INK, 'is left empty.');
  Lab(12, 22, GREY, 'storeys, from above,');
  Lab(12, 23, GREY, 'north up');
  if upto < 3 then Exit;

  Lab(1, 26, REDPEN, 'No storage, no flicker: the town is a FUNCTION of the square.');
  Lab(1, 27, INK, 'TOWNSPOT asks the same three questions of all 4096 squares, counts');
  Lab(1, 28, INK, 'the nine round each, and starts you facing the most: the big town.');
end;

{ ==========================================================================
   PAGE 7 - the ground under a house. Corners 0 16 32 8, point a=5 b=3:
   L 24, R 304, (384 + 1400)/256 = 1784/256 = 6. One cell = one sixteenth.
   ========================================================================== }
procedure PageGround(upto: Integer);
var i, j : Integer;
begin
  Big(1, 1, INK, 'THE GROUND UNDER A HOUSE');
  Lab(1, 3, REDPEN, 'A square on a slope is not flat. Each house corner gets its own.');
  Box(2, 6, 18, 22, PEN);
  Lab(1, 5, PEN, '8');
  Lab(18, 5, PEN, '32');
  Lab(1, 22, PEN, '0');
  Lab(18, 22, PEN, '16');
  for i := 0 to 7 do
    for j := 0 to 7 do
    begin
      SetFillStyle(SolidFill, PENCIL);
      Bar(CX(3 + 2 * i) - 1, CY(21 - 2 * j) - 1, CX(3 + 2 * i) + 1, CY(21 - 2 * j) + 1);
    end;
  Dot(CX(7), CY(19), REDPEN);
  Lab(8, 19, REDPEN, 'a=5 b=3');
  Lab(20, 6, INK, 'corner heights, off the map');
  Lab(20, 8, INK, 'd1 = 16   east');
  Lab(20, 9, INK, 'd2 = 32');
  Lab(20, 10, INK, 'd3 =  8   north');
  if upto < 2 then Exit;

  Lab(20, 12, PEN, 'west side  L = d3*b = 24');
  Lab(20, 13, PEN, 'east side  R = d1*16');
  Lab(20, 14, PEN, '   + (d2-d1)*b = 304');
  Lab(20, 16, PEN, 'G = (L*16 + (R-L)*a)/256');
  Lab(20, 17, PEN, '  = (384 + 1400)/256');
  Lab(20, 18, REDPEN, '  = 1784/256 = 6');
  Ring(22, 18, 6);
  Lab(20, 19, GREY, '6.97: SAR keeps the 6');
  Lab(20, 21, INK, 'Every step is 2 sixteenths:');
  Lab(20, 22, INK, 'a start, then an ADD.');
  if upto < 3 then Exit;

  Lab(1, 24, INK, 'The walls go down to the ground at EACH corner. The roof is level,');
  Lab(1, 25, INK, 'counted from the HIGHEST corner - so a house on a slope has a');
  Lab(1, 26, INK, 'taller wall downhill, and its windows stay out of the grass.');
  Lab(1, 28, REDPEN, 'FACEV, one change from the game: two bottoms instead of one.');
end;

{ ==========================================================================
   PAGE 8 - the windows grow. Five facades from near to far; then the
   perspective of a wall, and the pane that would vanish.
   ========================================================================== }

{ a two-storey facade w cells square, top-left at (x, y); every pane as big
  as it is, and never less than one pixel }
procedure Facade(x, y, w: Real);
var s, k : Integer;
    px0, px1, py0, py1 : Integer;
    c0, yb : Real;
begin
  FBox(x, y, x + w, y + w, PAPER, PEN);
  for s := 0 to 1 do
  begin
    yb := y + w - s * w / 2;
    for k := 0 to 1 do
    begin
      c0 := x + w * (1 + 4 * k) / 8;
      px0 := CX(c0);  px1 := CX(c0 + w / 4);
      py0 := CY(yb - w * 3 / 8);  py1 := CY(yb - w / 8);
      if px1 <= px0 then px1 := px0 + 1;
      if py1 <= py0 then py1 := py0 + 1;
      SetFillStyle(SolidFill, GLASS);
      Bar(px0, py0, px1 - 1, py1 - 1);
    end;
  end;
end;

procedure PageWin(upto: Integer);
begin
  Big(1, 1, INK, 'THE WINDOWS GROW');
  Lab(1, 3, REDPEN, 'A pane is drawn exactly as big as it is on the screen.');
  Facade(2, 5, 8);
  Facade(12, 9, 4);
  Facade(18, 11, 2);
  Facade(22, 12, 1);
  Facade(25, 12.5, 0.5);
  Facade(27, 12.75, 0.25);
  Lab(2, 14, PENCIL, 'near');
  Lab(26, 14, PENCIL, 'far');
  Lab(1, 15, INK, 'Nothing switches at a distance. The farthest pane is ONE pixel, and');
  Lab(1, 16, INK, 'it grows into a rectangle a pixel at a time as you close in.');
  if upto < 2 then Exit;

  Lab(1, 18, REDPEN, 'But halfway along a wall is NOT halfway on the screen:');
  Lab(2, 19, PEN, 't = u*zB / ((1-u)*zA + u*zB)');
  Lab(2, 20, PEN, 'A at 1000, B at 2000, u = 1/2:   t = 1000/1500 = 2/3');
  if upto < 3 then Exit;

  Lab(2, 22, INK, 'the columns, eighths along:    1    3    5    7');
  Lab(2, 23, INK, 'plain, of 256:                32   96  160  224');
  Lab(2, 24, REDPEN, 'corrected, of 256:            56  139  196  238');
  if upto < 4 then Exit;

  Lab(1, 26, INK, 'SCANPOLY fills from the top row down to, not including, the bottom.');
  Lab(1, 27, INK, 'So a pane whose top and bottom land on one row would fill NOTHING.');
  Lab(1, 28, REDPEN, 'Such a pane is given its row. Far off, that row is a lit dot.');
end;

{ ==========================================================================
   PAGE 9 - the edge of the town. HFULL 3072, HMAX 4096: at 3584 a house
   has half its height. One cell = 128 units along the axis.
   The octagon: (3000, 2000) -> 3750, the true 3606.
   ========================================================================== }
procedure PageEdge(upto: Integer);
begin
  Big(1, 1, INK, 'THE EDGE OF THE TOWN');
  Lab(1, 3, REDPEN, 'A town that stops at a radius APPEARS at that radius.');
  Lab(1, 4, INK, 'Fly at it, and a whole block is suddenly there.');
  if upto < 2 then Exit;

  Axis(CX(2), CY(16), CX(34), CY(16), PENCIL, False);
  Axis(CX(2), CY(8), CX(2), CY(16), PENCIL, False);
  Thick(CX(2), CY(8), CX(26), CY(8), PEN);
  Thick(CX(26), CY(8), CX(34), CY(16), PEN);
  Dashed(CX(30), CY(12), CX(30), CY(16), PENCIL);
  Dot(CX(30), CY(12), REDPEN);
  Lab(21, 12, REDPEN, '3584: half');
  Lab(1, 17, PENCIL, '0');
  Lab(24, 17, PENCIL, '3072');
  Lab(32, 17, PENCIL, '4096');
  Lab(3, 7, PENCIL, 'every storey');
  Lab(1, 19, INK, 'Nearer than 3072, every storey. Past 4096, not built. Between,');
  Lab(1, 20, INK, 'the fraction of them: the house RISES out of the ground as you come.');
  if upto < 3 then Exit;

  Lab(1, 22, REDPEN, 'And a distance with no square root - the octagon:');
  Lab(2, 23, PEN, 'the longer, plus three eighths of the shorter');
  Lab(2, 24, PEN, '(3000, 2000):   3000 + 750 = 3750');
  Lab(2, 25, PEN, 'the true one:   3606.  Four per cent out.');
  Lab(1, 27, INK, 'It only says how tall a far house is. Nobody measures that by');
  Lab(1, 28, INK, 'eye - and a square root would cost more than the house.');
end;

{ ==========================================================================
   PAGE 10 - night is the DAC, and the card the lesson leaves on the desk.
   81 bytes: (14 + 1 + 12) colours x 3.
   ========================================================================== }
procedure PageNight(upto: Integer);
begin
  Big(1, 1, INK, 'NIGHT IS THE DAC');
  Lab(1, 3, REDPEN, 'Every pixel keeps its NUMBER. N changes what the numbers MEAN.');
  Lab(8, 5, INK, '16 sky');
  Lab(16, 5, INK, '35 window');
  Lab(24, 5, INK, '36 window');
  Lab(2, 7, INK, 'day');
  FBox(8, 6, 14, 8, SKYD, PEN);
  FBox(16, 6, 22, 8, DGLASS, PEN);
  FBox(24, 6, 30, 8, DGLASS, PEN);
  if upto < 2 then Exit;

  Lab(2, 10, INK, 'night');
  FBox(8, 9, 14, 11, SKYN, PEN);
  FBox(16, 9, 22, 11, LIT, PEN);
  FBox(24, 9, 30, 11, DARKW, PEN);
  Lab(1, 13, INK, 'N writes 81 colour bytes to the DAC - 14 ground, 1 sky and 12');
  Lab(1, 14, INK, 'house colours, three bytes each - and redraws NOTHING.');
  Lab(1, 15, REDPEN, 'By day 35 and 36 are the same glass. At night they part.');
  if upto < 3 then Exit;

  Lab(1, 18, GREY, 'WHAT THIS LESSON HANDS OVER:');
  Lab(1, 19, REDPEN, 'THE WORLD IS AS BIG AS THE REGISTER.');
  Ring(1, 19, 18);
  Lab(1, 21, INK, 'The island is 65536 units because sixteen wires count that far,');
  Lab(1, 22, INK, 'and every size in the town was chosen inside it. When a sum needs');
  Lab(1, 23, INK, 'more, the silicon has an answer: a CARRY flag, and ADC.');
  Lab(1, 25, PEN, 'bare ground 23 frames a second, houses 17, their windows 14.');
  Lab(1, 27, GREY, 'Next lesson: the town gets solid.');
end;
