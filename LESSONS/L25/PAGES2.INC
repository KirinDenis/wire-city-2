{ ==========================================================================
   PAGE 5 - the picture pitches, and the cull has to know. PITCH4's sums;
   what was "behind" a level eye is in front of a pitched one; the five
   planes, and the turned screen's circle: 189/220 = 0.86 -> 7/8.
   ========================================================================== }
procedure PagePitch(upto: Integer);
begin
  Big(1, 1, INK, 'THE PICTURE PITCHES');
  Lab(1, 3, INK, 'PITCH4 is back - lessons 16 to 18 cut it out at the boot.');
  Lab(2, 5, PEN, 'y'' = (y x pcos - z x psin) / 256');
  Lab(2, 6, PEN, 'z'' = (y x psin + z x pcos) / 256');
  Lab(21, 5, INK, 'four multiplies, each');
  Lab(21, 6, INK, 'one''s answer its middle bytes');
  if upto < 2 then Exit;

  { the eye, its view pitched down, and the ground under it }
  Thick(CX(1), CY(16), CX(18), CY(16), GREEN);
  Lab(13, 17, GREEN, 'the ground');
  Dot(CX(5), CY(9), PEN);
  Axis(CX(5), CY(9), CX(17), CY(9), PENCIL, True);
  Lab(12, 8, PENCIL, 'level: z');
  Thick(CX(5), CY(9), CX(12), CY(16), PEN);
  Thick(CX(5), CY(9), CX(2.5), CY(16), PEN);
  Lab(1, 10, PEN, 'nose down');
  FBox(3.5, 15.5, 4.5, 16.5, REDPEN, REDPEN);
  Lab(5, 18, REDPEN, 'BEHIND a level eye (z < 0) -');
  Lab(5, 19, REDPEN, 'in front of THIS one');
  Lab(21, 9, INK, 'So the cull asks the');
  Lab(21, 10, INK, 'PITCHED question: it tests');
  Lab(21, 11, INK, 'y'' and z'', not y and z.');
  if upto < 3 then Exit;

  Lab(1, 21, INK, 'Five planes. Level: 160/220 -> 3/4 wide, 100/220 -> 1/2 high.');
  Lab(1, 22, INK, 'Banked, the screen turns and its CORNERS reach furthest:');
  Lab(1, 23, INK, 'sqrt(160 x 160 + 100 x 100) = 189, and 189 / 220 = 0.86.');
  Box(26, 19.5, 32.2, 23.3, PEN);
  SetColor(GREEN);
  Circle(CX(29.1), CY(21.4), Round(3.6 * CELL));
  Box(25.4, 17.7, 32.8, 25.1, REDPEN);
  Lab(1, 26, REDPEN, 'Banked: 7/8 both ways - a square round the turned screen''s circle.');
  Ring(1, 26, 33);
end;

{ ==========================================================================
   PAGE 6 - a node is a column. The ground below the bottom plane, a roof
   above it; both ends tested, a plane counts if both are outside.
   ========================================================================== }
procedure PageColumn(upto: Integer);
begin
  Big(1, 1, INK, 'A NODE IS A COLUMN');
  Dot(CX(3), CY(7), PEN);
  Lab(1, 6, PEN, 'eye');
  Thick(CX(3), CY(7), CX(20), CY(15), PENCIL);
  Lab(14, 11, PENCIL, 'the bottom of the screen');
  Thick(CX(1), CY(17), CX(22), CY(17), GREEN);
  FBox(15, 13, 18, 17, PAPER, PEN);
  Dot(CX(16.5), CY(17), REDPEN);
  Lab(19, 18, REDPEN, 'the ground: below the screen');
  Dot(CX(16.5), CY(13), PEN);
  Lab(19, 13, PEN, 'the roof: on it');
  Lab(1, 20, INK, 'Cull the square by its GROUND and its houses go with it - roofs that');
  Lab(1, 21, INK, 'are on the screen. Houses stand up to four storeys: 128 units.');
  if upto < 2 then Exit;

  Lab(1, 23, PEN, 'So each node is tested TWICE: the ground, and 128 above it.');
  Lab(1, 24, PEN, 'A plane counts only when BOTH are outside it: AND the two codes.');
  if upto < 3 then Exit;

  Lab(1, 26, INK, '128 up, as the camera sees it: y'' + 128 x pcos / 256 = y'' + pcos / 2,');
  Lab(1, 27, INK, 'z'' by psin / 2. Two shifts, no multiply.');
  Lab(1, 29, REDPEN, 'Everything between two points outside a plane is outside it.');
  Ring(1, 29, 30);
end;

{ ==========================================================================
   PAGE 7 - the numbers with a sign, and the bill. pitch 18 -> 25 degrees;
   roll 200 -> CBW -56 -> -79. 18-35 frames level, 10-11 banked over a town.
   ========================================================================== }
procedure PageNumbers(upto: Integer);
begin
  Big(1, 1, INK, 'THE NUMBERS, AND THE BILL');
  FBox(1, 4, 12, 12, SKYW, PEN);
  Lab(2, 5, INK, 'THR 100%');
  Lab(2, 6, INK, 'SPD  736');
  Lab(2, 7, INK, 'ALT 1500');
  Lab(2, 8, INK, 'HDG 000');
  Lab(2, 9, REDPEN, 'PIT + 25');
  Lab(2, 10, REDPEN, 'BNK - 79');
  Lab(14, 5, PEN, 'pitch 18 x 45 / 32 = 25 degrees');
  Lab(14, 7, PEN, 'roll 200: CBW reads the byte as -56,');
  Lab(14, 8, PEN, '-56 x 45 = -2520, SAR 5 = -79');
  Lab(14, 10, GREEN, 'SNUMOUT: NEG it, and the sign');
  Lab(14, 11, GREEN, 'goes in front of the digits');
  if upto < 2 then Exit;

  Lab(1, 14, INK, 'THE BILL, measured at 30000 cycles:');
  Lab(3, 16, PEN, 'level flight              18 to 35 frames a second');
  Lab(3, 17, PEN, 'banked, over a town       10 to 11');
  Lab(1, 19, INK, 'Banked, the planes are wider, and the houses lose their own cull.');
  if upto < 3 then Exit;

  Lab(1, 22, INK, 'Still not honest, on purpose: drag grows with the speed, not its');
  Lab(1, 23, INK, 'square; there is no wing; the air thins in a straight line.');
  Lab(1, 25, REDPEN, 'The picture pitches now - that one is off the list.');
  Ring(1, 25, 25);
end;
