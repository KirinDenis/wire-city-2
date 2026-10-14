{ ==========================================================================
   PAGE 4 - a line is walked, not multiplied. Banked 30: each step adds
   (222, 128) to an 8.8 offset; SAR 8 gives the pixel. Then the glass.
   ========================================================================== }
procedure PageWalk(upto: Integer);
const
  WX : array[0..8] of Integer = (0, 0, 1, 2, 3, 4, 5, 6, 6);
  WY : array[0..8] of Integer = (0, 0, 1, 1, 2, 2, 3, 3, 4);
var k : Integer;
begin
  Big(1, 1, INK, 'A LINE IS WALKED');
  Lab(1, 3, INK, 'Each pixel of a rung is one step along (rcos, rsin), kept in 256ths:');
  Lab(1, 4, INK, 'an 8.8 number - lesson 17''s byte of fraction. Banked 30 degrees:');
  Lab(2, 6, PENCIL, 'step     x8     y8      x    y');
  Lab(2, 7, PEN,    '  0       0      0      0    0');
  Lab(2, 8, PEN,    '  1     222    128      0    0');
  Lab(2, 9, PEN,    '  2     444    256      1    1');
  Lab(2, 10, PEN,   '  3     666    384      2    1');
  Lab(2, 11, PEN,   '  4     888    512      3    2');
  Lab(2, 12, PENCIL, '         +222   +128   SAR 8');
  for k := 0 to 8 do
    FBox(22 + WX[k], 6 + WY[k], 23 + WX[k], 7 + WY[k], PEN, PENCIL);
  LabXY(CX(22), CY(12) + 4, PENCIL, 'the pixels it lands on');
  if upto < 2 then Exit;

  Lab(1, 15, INK, 'TWO ADDs A PIXEL, not four IMULs: the centre is the only multiply.');
  Lab(1, 16, INK, 'The offset starts at -60 x rcos, and SAR keeps its sign.');
  Lab(1, 17, INK, 'Five rungs of 120 pixels: six hundred pixels a frame.');
  if upto < 3 then Exit;

  Lab(1, 20, PEN, 'THE GLASS. Banked, a rung reaches right across the screen - over');
  Lab(1, 21, PEN, 'the tapes and the compass. So the middle is drawn only between');
  Lab(1, 22, PEN, 'them: x 84 to 236, y 40 to 172. And lesson 1B''s G moved under');
  Lab(1, 23, PEN, 'the speed tape: the rungs'' numbers came down on top of it.');
  Lab(1, 26, REDPEN, 'Clip to the glass, and every instrument stays readable.');
  Ring(1, 26, 28);
end;

{ ==========================================================================
   PAGE 5 - what is still not there: where the aeroplane is going. The
   gunsight, a flight path marker under it, and the gap - alpha.
   ========================================================================== }
procedure PageNext(upto: Integer);
begin
  Big(1, 1, INK, 'NEXT: THE WING');
  Lab(1, 3, INK, 'The gunsight shows where the nose points. Where is the aeroplane');
  Lab(1, 4, INK, 'GOING? In this model, the same place: it flies along its nose.');
  Sight(10, 10, PEN);
  Thick(CX(4), CY(8), CX(8), CY(8), PEN);
  Thick(CX(12), CY(8), CX(16), CY(8), PEN);
  LabXY(CX(16.5), CY(8) - 3, PEN, '10');
  if upto < 2 then Exit;

  SetColor(GREEN);
  Circle(CX(10), CY(14), 8);
  Line(CX(10) - 18, CY(14), CX(10) - 8, CY(14));
  Line(CX(10) + 8, CY(14), CX(10) + 18, CY(14));
  Line(CX(10), CY(14) - 8, CX(10), CY(14) - 14);
  Arrow(13.5, 10, 13.5, 13.6, REDPEN, True);
  LabXY(CX(14), CY(11.6), REDPEN, 'alpha');
  LabXY(CX(12), CY(14) + 6, GREEN, 'where you go');
  Lab(19, 8, INK, 'With a wing, the path sags');
  Lab(19, 9, INK, 'below the nose, and a marker');
  Lab(19, 10, INK, 'shows where you go.');
  Lab(19, 12, INK, 'The gap between them, read');
  Lab(19, 13, INK, 'on this ladder, is the');
  Lab(19, 14, REDPEN, 'ANGLE OF ATTACK.');
  if upto < 3 then Exit;

  Lab(1, 19, PEN, 'Next lesson: lift, alpha, a G that is honest upside down, and a');
  Lab(1, 20, PEN, 'stall that comes from the angle of the wing, not from the speed.');
  Lab(1, 23, REDPEN, 'The ladder is the ruler the wing will be read on.');
  Ring(1, 23, 25);
end;
