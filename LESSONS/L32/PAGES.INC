{ ==========================================================================
   THE TRAFFIC - small things the pages share, and pages 1 to 3.
   ========================================================================== }

procedure Thick(x1, y1, x2, y2, c: Integer);
begin
  SetColor(c);
  SetLineStyle(SolidLn, 0, ThickWidth);
  Line(x1, y1, x2, y2);
  SetLineStyle(SolidLn, 0, NormWidth);
end;

procedure Dashed(x1, y1, x2, y2, c: Integer);
begin
  SetColor(c);
  SetLineStyle(DashedLn, 0, NormWidth);
  Line(x1, y1, x2, y2);
  SetLineStyle(SolidLn, 0, NormWidth);
end;

procedure LabXY(x, y: Integer; c: Integer; s: string);
begin
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(c);
  OutTextXY(x, y, s);
end;

procedure Dot(x, y, c: Integer);
begin
  SetFillStyle(SolidFill, c);
  SetColor(c);
  PieSlice(x, y, 0, 360, 3);
end;

{ a little aeroplane seen from above at cell (u, v), flying along the
  heading h in 256ths of a circle, north up the page: a fuselage and a wing }
procedure Jet(u, v: Real; h: Integer; c: Integer);
var a, s, k : Real;
begin
  a := h * 2 * Pi / 256;
  s := Sin(a);  k := Cos(a);
  Thick(CX(u - 0.8 * s), CY(v + 0.8 * k), CX(u + 0.8 * s), CY(v - 0.8 * k), c);
  Thick(CX(u - 0.7 * k), CY(v - 0.7 * s), CX(u + 0.7 * k), CY(v + 0.7 * s), c);
  Dot(CX(u + 0.8 * s), CY(v - 0.8 * k), c);
end;

{ ==========================================================================
   PAGE 1 - an aeroplane in the sky is five numbers. The start from above;
   the table; one tick of it.
   ========================================================================== }
procedure PageFive(upto: Integer);
begin
  Big(1, 1, INK, 'FIVE NUMBERS AN AEROPLANE');
  Lab(1, 3, REDPEN, 'Lesson 20: lesson 1E''s aeroplanes, in lesson 1D''s sky.');
  { from above: you at the bottom, north up; one cell is 400 units }
  Dashed(CX(10), CY(22), CX(10), CY(6), PENCIL);
  LabXY(CX(10.3), CY(6), PENCIL, 'north');
  Jet(10, 22, 0, PEN);
  LabXY(CX(10.8), CY(22), PEN, 'you');
  { each one's name beside it, one rule for all: east of the north line
    on its right, west of it on its left - 8 pixels a letter }
  Jet(8.5, 18.25, 64, GREEN);   LabXY(CX(8.5 - 1.1) - 7 * 8, CY(18.25) - 4, GREEN, 'fighter');
  Jet(12.25, 15.5, 192, GREEN); LabXY(CX(12.25 + 1.1), CY(15.5) - 4, GREEN, 'bomber');
  Jet(6.25, 14, 0, GREEN);      LabXY(CX(6.25 - 1.1) - 5 * 8, CY(14) - 4, GREEN, 'radar');
  Jet(11, 11.5, 128, GREEN);    LabXY(CX(11 + 1.1), CY(11.5) - 4, GREEN, 'transport');
  Jet(14, 9, 32, GREEN);        LabXY(CX(14 + 1.1), CY(9) - 4, GREEN, 'tanker');
  LabXY(CX(2), CY(23.3), PENCIL, 'a square here is 400 units');
  Lab(21, 6, INK, 'Each one is FIVE numbers:');
  Lab(22, 8, PEN, 'pax  east');
  Lab(22, 9, PEN, 'pay  up');
  Lab(22, 10, PEN, 'paz  north');
  Lab(22, 11, PEN, 'pah  its heading');
  Lab(22, 12, PEN, '     and its slot: type');
  Lab(21, 14, INK, 'What it LOOKS like is');
  Lab(21, 15, INK, 'lesson 1E''s two tables.');
  if upto < 2 then Exit;

  Lab(21, 17, PEN, 'start, from you:');
  Lab(21, 18, PENCIL, '      east  up  north  hdg');
  Lab(21, 19, PEN, 'fgt   -600  60   1500   64');
  Lab(21, 20, PEN, 'bmb    900 200   2600  192');
  Lab(21, 21, PEN, 'rdr  -1500 120   3200    0');
  Lab(21, 22, PEN, 'trn    400  40   4200  128');
  Lab(21, 23, PEN, 'tnk   1600 260   5200   32');
  if upto < 3 then Exit;

  Lab(1, 25, INK, 'A tick: every fourth one, the heading turns a step - a slow circle.');
  Lab(1, 26, PEN, 'x += sin(h) x speed / 256     z += cos(h) x speed / 256');
  Lab(1, 27, PEN, 'the fighter flying east, h = 64:  x += 256 x 15 / 256 = 15 a tick');
  Lab(1, 28, REDPEN, 'Strays past 9000 come back in front of you: the game''s leash.');
end;

{ ==========================================================================
   PAGE 2 - into the eye's space. The ground's own turn; the model's turn
   is its heading minus yours; the pitch and the bank for nothing.
   ========================================================================== }
procedure PageEye(upto: Integer);
begin
  Big(1, 1, INK, 'WHERE THE EYE SEES IT');
  Lab(1, 3, INK, 'The hangar put the aeroplane 300 in front of a still eye. Now:');
  Lab(2, 5, PEN, 'wdx = pax - camx      wdz = paz - camz      height = pay - camy');
  Lab(2, 6, PEN, 'ROTXZ turns (wdx, wdz) by YOUR heading -> rc_x right, rc_z ahead');
  Lab(2, 7, GREEN, 'the very turn every square of the ground gets: nothing new');
  Lab(1, 9, INK, 'The transport at the start: wdx = 400, wdz = 4200, your heading 0:');
  Lab(2, 10, REDPEN, '400 right, 4200 ahead, 40 above.');
  Ring(2, 10, 16);
  if upto < 2 then Exit;

  Jet(5, 19, 0, PEN);    Jet(5, 15.5, 0, GREEN);    { you behind, it ahead }
  LabXY(CX(2), CY(21), PEN, 'the same way:');
  LabXY(CX(2), CY(21.7), PEN, 'its TAIL');
  Jet(13, 19, 0, PEN);   Jet(13, 15.5, 128, GREEN);
  LabXY(CX(10), CY(21), PEN, 'towards you:');
  LabXY(CX(10), CY(21.7), PEN, 'its NOSE');
  Lab(19, 15, INK, 'The model''s turn is ITS');
  Lab(19, 16, INK, 'heading MINUS YOURS:');
  Lab(20, 18, PEN, 'myaw = pah - heading');
  Lab(19, 20, INK, 'the transport: 128 - 0 =');
  Lab(19, 21, INK, '128, half a circle - it');
  Lab(19, 22, INK, 'flies at you, nose first.');
  if upto < 3 then Exit;

  Lab(1, 25, INK, 'The pitch and the bank are not in this code at all: FACEFILL');
  Lab(1, 26, INK, 'pitches every face (PITCH4) and PROJPT banks every corner.');
  Lab(1, 27, REDPEN, 'The aeroplanes tilt with the world for nothing.');
  Ring(1, 27, 24);
end;

{ ==========================================================================
   PAGE 3 - how big, and in what order. A fighter far away is pixels; the
   game's box; drawn after the ground, and what that costs.
   ========================================================================== }
procedure PageSize(upto: Integer);
begin
  Big(1, 1, INK, 'A FEW PIXELS, AND A BOX');
  Lab(1, 3, INK, 'One cell of 1E''s paper is ONE unit of the world here - no times 8,');
  Lab(1, 4, INK, 'as in the game. The fighter is 26 wide: a fifth of a house.');
  Lab(2, 6, PEN, 'on the screen:  26 x 220 / distance');
  Lab(2, 7, PEN, 'at 1500 ahead:  26 x 220 / 1500 = 3.8 pixels');
  Lab(2, 8, PEN, 'at 4200 ahead:  1.4 pixels - a dot');
  if upto < 2 then Exit;

  Box(4, 11, 8, 15, GREEN);
  Thick(CX(5.2), CY(13), CX(6.8), CY(13), PEN);
  Lab(10, 11, INK, 'So the game draws a box round every one in sight:');
  Lab(11, 13, PEN, 'half size = 2860 / distance + 3,  never past 24');
  Lab(11, 14, PEN, 'at 1500: 2860 / 1500 + 3 = 4 pixels either side');
  Lab(10, 16, INK, 'Its centre goes through the pitch and the lens');
  Lab(10, 17, INK, 'like a corner of a face: PPOINT, then PROJPT.');
  if upto < 3 then Exit;

  Lab(1, 20, INK, 'THE ORDER: the traffic is drawn AFTER the ground. It is in the sky,');
  Lab(1, 21, INK, 'so painting it over the land is the painter''s order we want -');
  Lab(1, 23, REDPEN, 'and one behind a hill is drawn ON the hill.');
  Ring(1, 23, 21);
  Lab(1, 25, INK, 'The game draws it the same way, and has the same fault. Said, not');
  Lab(1, 26, INK, 'hidden: a depth for every pixel is 64000 more words, two segments.');
end;
