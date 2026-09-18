{ ==========================================================================
   PAGE 7 - THE GLASS, WORKED. 1 cell = 40, the screen 8 x 5. The line
   (-80,160) -> (400,-80) is cut at (0,120) and then at (240,0), both on
   crossings, and the second cut takes a corner in one pass - which is
   the whole reason Cohen-Sutherland "goes round again".
   ========================================================================== }
procedure PageGlass(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'the glass: four bits, three sentences');
  Lab(0.9, 2.3, REDPEN, '1 cell = 40. Screen 8 x 5. One bit for every wall a point is past.');
  Axis(CX(3), CY(6), CX(21), CY(6), PENCIL, True);
  Axis(CX(3), CY(11), CX(21), CY(11), PENCIL, True);
  Axis(CX(8), CY(3.6), CX(8), CY(13.4), PENCIL, True);
  Axis(CX(16), CY(3.6), CX(16), CY(13.4), PENCIL, True);
  Thick(CX(8), CY(6), CX(16), CY(6), GREEN);
  Thick(CX(16), CY(6), CX(16), CY(11), GREEN);
  Thick(CX(16), CY(11), CX(8), CY(11), GREEN);
  Thick(CX(8), CY(11), CX(8), CY(6), GREEN);
  Lab(5, 4.6, GREY, '1001');    Lab(11.5, 4.6, GREY, '1000');   Lab(17.5, 4.6, GREY, '1010');
  Lab(5, 8.2, GREY, '0001');    Lab(11.5, 8.2, INK, '0000');    Lab(17.5, 8.2, GREY, '0010');
  Lab(5, 12, GREY, '0101');     Lab(11.5, 12, GREY, '0100');    Lab(17.5, 12, GREY, '0110');
  Lab(8.2, 5.3, PENCIL, 'top = 8');
  Lab(14.6, 11.3, PENCIL, 'bottom = 4');
  Lab(4.4, 9.4, PENCIL, 'left = 1');
  Lab(16.3, 9.4, PENCIL, 'right = 2');
  if upto < 2 then Exit;

  SetColor(PEN);
  Line(CX(6), CY(10), CX(18), CY(4));
  Dot(CX(6), CY(10), PEN);
  Dot(CX(18), CY(4), PEN);
  Lab(0.9, 11.3, PEN, 'P0 ( -80, 160 )  code 0001');
  Lab(18.6, 3.2, PEN, 'P1 ( 400, -80 )  code 1010');
  if upto < 3 then Exit;

  Lab(0.9, 13.6, INK, '0001 OR 1010 = 1011: not both zero, so not simply drawn.');
  Lab(0.9, 14.6, INK, '0001 AND 1010 = 0000: not both past ONE wall, so not thrown away. Cut.');
  Lab(0.9, 15.8, INK, 'P0 first. Its bit is LEFT, so x = 0:');
  Lab(0.9, 16.8, INK, 'ny = ( 0 - (-80) ) * ( -80 - 160 ) / ( 400 - (-80) ) + 160');
  Lab(0.9, 17.8, INK, '   = 80 * -240 / 480 + 160 = -40 + 160 =');
  Lab(21.4, 17.8, REDPEN, '120');
  Ring(21.2, 17.8, 1.8);
  SetColor(GREY);
  Line(CX(6), CY(10), CX(8), CY(9));
  Dot(CX(6), CY(10), GREY);
  Dot(CX(8), CY(9), REDPEN);
  Lab(8.3, 9.2, REDPEN, '( 0, 120 )');
  if upto < 4 then Exit;

  Lab(0.9, 19.2, INK, 'Round again. P1 is 1010, and TOP is tested first, so y = 0:');
  Lab(0.9, 20.2, INK, 'nx = ( 0 - 120 ) * 400 / ( -80 - 120 ) + 0 = -48000 / -200 =');
  Lab(30.6, 20.2, REDPEN, '240');
  Ring(30.4, 20.2, 1.8);
  SetColor(GREY);
  Line(CX(14), CY(6), CX(18), CY(4));
  Dot(CX(18), CY(4), GREY);
  Thick(CX(8), CY(9), CX(14), CY(6), GREEN);
  Dot(CX(14), CY(6), REDPEN);
  Lab(14.3, 5.2, REDPEN, '( 240, 0 )');
  Lab(0.9, 21.2, INK, 'The right wall was never needed: a corner is two walls, and one cut');
  Lab(0.9, 22.2, INK, 'took both. Both codes 0000 now. Draw it.');
  if upto < 5 then Exit;

  SetColor(PENCIL);
  Line(CX(0.9), CY(23.4), CX(35), CY(23.4));
  Lab(0.9, 23.8, REDPEN, 'both zero: draw.');
  Lab(0.9, 24.8, REDPEN, 'AND not zero: both past the SAME wall. Thrown away, no arithmetic.');
  Lab(0.9, 25.8, REDPEN, 'otherwise: cut the outside end at the first wall it is past. Go again.');
  Lab(0.9, 27.2, GREY, 'Cohen and Sutherland. ENGINE\E_RAST.INC, CLIPLINE. Four passes at most.');
  Lab(0.9, 28.2, GREY, 'IMUL then IDIV again: -19200 / 480 = -40 exactly. When there is a');
  Lab(0.9, 29.2, GREY, 'remainder it is thrown away: a pixel, at most.');
end;

{ ==========================================================================
   PAGE 8 - two fences, not one: what cannot be drawn, what need not be.
   ========================================================================== }
procedure PageTwo(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'two fences, not one');
  Lab(0.9, 2.3, REDPEN, 'the first is about what CANNOT be drawn. The second, what NEED not be.');
  SetColor(PEN);
  Rectangle(CX(0.9), CY(4), CX(17), CY(12.8));
  Head(1.4, 4.3, PEN, 'NEARCLIP');
  Lab(1.4, 6.6, INK, 'three dimensions');
  Lab(1.4, 7.6, INK, 'BEFORE the divide');
  Lab(1.4, 9, REDPEN, 'what cannot be drawn.');
  Lab(1.4, 10.2, GREY, 'behind the eye there is no');
  Lab(1.4, 11.2, GREY, 'answer, and the machine will');
  Lab(1.4, 12.2, GREY, 'hand you one anyway.');
  SetColor(PEN);
  Rectangle(CX(18.5), CY(4), CX(35), CY(12.8));
  Head(19, 4.3, PEN, 'CLIPLINE');
  Lab(19, 6.6, INK, 'two dimensions');
  Lab(19, 7.6, INK, 'AFTER the divide');
  Lab(19, 9, REDPEN, 'what need not be.');
  Lab(19, 10.2, GREY, 'off the glass is a perfectly');
  Lab(19, 11.2, GREY, 'good point. It is just not');
  Lab(19, 12.2, GREY, 'on the screen.');
  if upto < 2 then Exit;

  Lab(0.9, 14.6, INK, 'Stage 3 takes the first down and keeps the second. The picture is tidy');
  Lab(0.9, 15.6, INK, 'and wrong: the world behind your head is drawn, mirrored, above the');
  Lab(0.9, 16.6, INK, 'horizon. Page six''s 600 - a whole lattice of them.');
  Lab(0.9, 17.8, REDPEN, 'clipping the symptom is not fixing the cause.');
  if upto < 3 then Exit;

  Lab(0.9, 19.8, INK, 'Stage 4 takes both. LINE walks every pixel it is given, on the screen');
  Lab(0.9, 20.8, INK, 'or not, and CLAMPAX hands it 4000 each way:');
  Lab(0.9, 22, INK, '882 edges, up to 8000 pixels each: about 7 000 000 pixels a frame.');
  Lab(0.9, 23, INK, 'The best part of a minute.');
  Lab(0.9, 24.4, GREY, 'Behind a back buffer that is a black screen. So stage 4 draws straight');
  Lab(0.9, 25.4, GREY, 'onto the glass, and you watch it happen.');
end;

{ ==========================================================================
   PAGE 9 - CLAMPAX is not a fence. 800 * 220 / 40 = 4400, +160 = 4560,
   and CLAMPAX writes 4000 in its place: 560 pixels short, and the line
   swings. That is the bug Owl Fly III wrote up as "18.2".
   ========================================================================== }
procedure PageClamp(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'CLAMPAX is not a fence');
  Lab(0.9, 2.3, REDPEN, 'ENGINE\E_M3D.INC. It does not clip. It substitutes.');
  Lab(0.9, 4.4, PEN, 'CLAMPAX:');
  Lab(0.9, 5.6, PEN, '  cmp  ax,4000');
  Lab(0.9, 6.8, PEN, '  jle  .a1');
  Lab(0.9, 8, PEN,   '  mov  ax,4000');
  Lab(0.9, 9.2, GREY, '  ...and -4000 the same way');
  if upto < 2 then Exit;

  Lab(15, 4.4, INK, 'x = 800, z = 40:');
  Lab(15, 5.4, INK, '800 * 220 / 40 = 4400');
  Lab(15, 6.4, INK, '160 + 4400 = 4560');
  Lab(15, 7.6, INK, '4560 > 4000, so');
  Lab(23.4, 7.6, REDPEN, '4000');
  Ring(23.2, 7.6, 2.2);
  Lab(15, 9, INK, 'a number, in place of the real');
  Lab(15, 10, INK, 'one. 560 pixels short.');
  Lab(15, 11.4, INK, '4000 / 220 = 18.2: past x / z =');
  Lab(15, 12.4, INK, '18.2 every number is invented.');
  Lab(15, 13.4, GREY, '4000 is a hundred cells off the');
  Lab(15, 14.4, GREY, 'right of this page.');
  if upto < 3 then Exit;

  Lab(0.9, 15.6, GREY, 'no scale: the far end moved, so the whole segment swings');
  Thick(CX(2), CY(18), CX(6), CY(18), GREEN);
  Thick(CX(6), CY(18), CX(6), CY(20.5), GREEN);
  Thick(CX(6), CY(20.5), CX(2), CY(20.5), GREEN);
  Thick(CX(2), CY(20.5), CX(2), CY(18), GREEN);
  Dot(CX(2.5), CY(19.5), PEN);
  SetColor(PEN);
  Line(CX(2.5), CY(19.5), CX(34), CY(17.6));
  Dot(CX(34), CY(17.6), PEN);
  Lab(30.6, 16.8, PEN, '4560, true');
  Dashed(CX(2.5), CY(19.5), CX(12), CY(17.6), REDPEN);
  Dot(CX(12), CY(17.6), REDPEN);
  Lab(12.4, 16.6, REDPEN, '4000, put there - x pulled back');
  Lab(6.4, 19.8, GREY, 'two different lines cross the glass');
  if upto < 4 then Exit;

  SetColor(GREY);
  Rectangle(CX(0.9), CY(22), CX(35), CY(28.6));
  Lab(1.4, 22.4, GREY, 'GAMES\OWLFLY3\SRC\WORLD.INC, at GRID:');
  Lab(1.4, 23.6, INK, '"WHY THE GRID CAME APART, IN ONE NUMBER" - the splash screen, the');
  Lab(1.4, 24.6, INK, 'camera turns, the grid explodes. Nothing to do with machine speed.');
  Lab(1.4, 25.6, INK, 'The first fix did not take: off by nearly double. The comment says');
  Lab(1.4, 26.6, REDPEN, 'the real cure is clipping the edge against the side planes, in 3D.');
  Lab(1.4, 27.6, GREY, 'That sentence is a later lesson. Today you have read the bug it names.');
end;

{ ==========================================================================
   PAGE 10 - two engines, and the staircase of the beam. One cell is one
   retrace, 1/70 s. A frame that waits for the beam ends on a cell line,
   so 11.4 ms becomes 14.3 and 16.7 becomes 28.6: 70 against 35.
   ========================================================================== }
procedure PageStair(upto: Integer);
var k : Integer;
begin
  Head(0.9, 0.7, INK, 'two engines, and the staircase');
  Lab(0.9, 2.3, REDPEN, 'one cell = one retrace = 1/70 s = 14.3 ms. Frames end on a line.');
  Axis(CX(6), CY(12), CX(26.5), CY(12), PENCIL, False);
  SetColor(PENCIL); ArrowR(CX(27), CY(12));
  Lab(27.3, 11.6, PENCIL, 't');
  SetColor(GREEN);
  for k := 0 to 20 do Line(CX(6 + k), CY(9.6), CX(6 + k), CY(14.4));
  Lab(5.8, 12.4, GREY, '0');   Lab(15.6, 12.4, GREY, '10');   Lab(25.4, 12.4, GREY, '20');
  Lab(6.2, 8.6, GREEN, 'the beam goes home every 14.3 ms - every green line');
  if upto < 2 then Exit;

  Lab(0.9, 10.2, PEN, 'FAST');
  for k := 0 to 19 do
  begin
    SetFillStyle(SolidFill, PEN);
    Bar(CX(6 + k), CY(10.2), CX(6 + k + 0.8), CY(10.8));
    SetFillStyle(SolidFill, GREY);
    Bar(CX(6 + k + 0.8), CY(10.4), CX(6 + k + 1), CY(10.6));
  end;
  Lab(0.9, 15.6, INK, 'FAST:     1000 / 88 = 11.4 ms = 0.8 cell. It waits to the line at 1.');
  Lab(0.9, 16.6, INK, '          one frame every retrace: 70 / 1 =');
  Lab(22.6, 16.6, REDPEN, '70');
  Ring(22.4, 16.6, 1.4);
  if upto < 3 then Exit;

  Lab(0.9, 13.2, GREY, 'CLASSIC');
  for k := 0 to 9 do
  begin
    SetFillStyle(SolidFill, PEN);
    Bar(CX(6 + 2 * k), CY(13.2), CX(6 + 2 * k + 1.17), CY(13.8));
    SetFillStyle(SolidFill, GREY);
    Bar(CX(6 + 2 * k + 1.17), CY(13.4), CX(6 + 2 * k + 2), CY(13.6));
  end;
  Lab(0.9, 18.2, INK, 'CLASSIC:  1000 / 60 = 16.7 ms = 1.17 cells. It waits to the line at 2.');
  Lab(0.9, 19.2, INK, '          one frame every two: 70 / 2 =');
  Lab(20.6, 19.2, REDPEN, '35');
  Ring(20.4, 19.2, 1.4);
  Lab(0.9, 20.6, REDPEN, '88 against 60 reads as 70 against 35. A staircase, not a measurement.');
  Lab(0.9, 21.6, INK, 'Measure with the wait off. The honest gap is about a third.');
  if upto < 4 then Exit;

  SetColor(PENCIL);
  Line(CX(0.9), CY(23), CX(35), CY(23));
  Lab(0.9, 23.4, INK, 'what the one byte flips - F, in flight:');
  Lab(0.9, 24.6, PEN, 'ROTXZ  four IDIV 256 a node  ->  two MOVs. Lesson 10.');
  Lab(0.9, 25.6, PEN, 'LINE   a call and a MUL a pixel  ->  lesson 8''s Line, patched.');
  Lab(0.9, 26.8, GREY, 'the classic is kept, as ROTXZC and LINEC: what the game shipped with.');
  Lab(0.9, 28, REDPEN, 'on a real 8086 IDIV is 150 clocks, not four. The gap there is wider.');
end;

{ ==========================================================================
   PAGE 11 - the closing card.
   ========================================================================== }
procedure PageFinal(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'one edge, all the way to a pixel');
  Lab(0.9, 2.3, REDPEN, 'a wall before the eye, a frame round the glass, a trap under both.');
  Lab(0.9, 4, INK, 'The wall, in three dimensions, before the divide: t = 80 / 160, exact.');
  Lab(0.9, 5, INK, 'The frame, in two, after it: four bits, three sentences, four passes.');
  Lab(0.9, 6, INK, 'And under both, INT 0 taken: 44000 does not fit, the machine stops -');
  Lab(0.9, 7, INK, 'and is caught, counted, and returned.');
  SetColor(PEN);
  Rectangle(CX(0.9), CY(9), CX(35), CY(16));
  Lab(1.4, 9.4, REDPEN, 'NEXT:');
  Lab(1.4, 10.8, INK, '14  houses out of cubes, on this lattice - the painter''s algorithm,');
  Lab(1.4, 11.8, INK, '    and a FACE cut by the near plane: 3, 4 or 5 corners come out.');
  Lab(1.4, 13.2, INK, '15  the relief: every corner lifted to its height, and filled.');
  Lab(1.4, 14.6, GREY, '    both are already in the game. You will read them out of it.');
  if upto < 2 then Exit;

  Lab(0.9, 18, GREEN, 'Now the source. It includes five files, and none of them is a lesson');
  Lab(0.9, 19, GREEN, 'version of anything.');
  Lab(0.9, 21, GREY, 'Keep the notebook open. The cut, the glass and the trap are all in it,');
  Lab(0.9, 22, GREY, 'with the numbers you are about to see fly.');
end;
