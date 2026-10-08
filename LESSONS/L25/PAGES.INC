{ ==========================================================================
   THE AEROPLANE THREE WAYS - small drawings the pages share. All in cells.
   ========================================================================== }

{ side on, nose to the right: the pitch view }
procedure Side(x, y: Real);
begin
  Thick(CX(x - 3), CY(y), CX(x + 3), CY(y), PEN);              { the body }
  Thick(CX(x + 3), CY(y), CX(x + 3.6), CY(y + 0.2), PEN);      { the nose }
  Thick(CX(x - 3), CY(y), CX(x - 3.4), CY(y - 1.3), PEN);      { the fin }
  Thick(CX(x - 0.6), CY(y + 0.1), CX(x + 0.6), CY(y + 0.6), PEN);  { the wing, edge on }
end;

{ from behind, rolled by a (radians, right wing down for a > 0): the roll view }
procedure Rear(x, y, a: Real);
var c, s : Real;
begin
  c := Cos(a);  s := Sin(a);
  Thick(CX(x - 4 * c), CY(y - 4 * s), CX(x + 4 * c), CY(y + 4 * s), PEN);   { the wings }
  Thick(CX(x), CY(y), CX(x + 1.6 * s), CY(y - 1.6 * c), PEN);               { the fin }
  SetColor(PEN);
  SetFillStyle(SolidFill, PEN);
  PieSlice(CX(x), CY(y), 0, 360, 9);                                         { the body }
end;

{ from above, nose up the page: the yaw view }
procedure Top(x, y: Real);
begin
  Thick(CX(x), CY(y - 3), CX(x), CY(y + 3), PEN);              { the body }
  Thick(CX(x - 3.5), CY(y + 0.3), CX(x + 3.5), CY(y + 0.3), PEN);  { the wings }
  Thick(CX(x - 1.4), CY(y + 2.7), CX(x + 1.4), CY(y + 2.7), PEN);  { the tail }
end;

{ a curved arrow round (x, y), radius r cells, from angle a0 to a1 (degrees,
  counter-clockwise from three o'clock, as BGI counts them), head at a1 }
procedure Turn(x, y, r: Real; a0, a1: Integer; c: Integer);
var t, hx, hy, tx, ty : Real;
begin
  SetColor(c);
  SetLineStyle(SolidLn, 0, ThickWidth);
  Arc(CX(x), CY(y), a0, a1, Round(r * CELL));
  SetLineStyle(SolidLn, 0, NormWidth);
  t := a1 * Pi / 180;
  hx := x + r * Cos(t);  hy := y - r * Sin(t);       { the end of the arc }
  tx := -Sin(t);  ty := -Cos(t);                     { the way it was going }
  Line(CX(hx), CY(hy), CX(hx - 0.6 * tx + 0.35 * ty), CY(hy - 0.6 * ty - 0.35 * tx));
  Line(CX(hx), CY(hy), CX(hx - 0.6 * tx - 0.35 * ty), CY(hy - 0.6 * ty + 0.35 * tx));
end;

{ ==========================================================================
   PAGE 1 - the three axes. Pitch side on, roll from behind, yaw from above;
   and which control works which one, now.
   ========================================================================== }
procedure PageAxes(upto: Integer);
begin
  Big(1, 1, INK, 'THE THREE AXES');
  Lab(1, 3, REDPEN, 'Lesson 14 turned with the arrows. An aeroplane has three axes.');
  Side(6, 10);
  Turn(9.6, 10.2, 2, 10, 110, REDPEN);
  Big(2, 15, INK, 'PITCH');
  Lab(2, 17, PEN, 'the nose up or down');
  Lab(2, 18, PEN, 'THE STICK: DOWN, UP');
  if upto < 2 then Exit;

  Rear(18, 10, 0.35);
  Turn(18, 10, 3.2, 200, 340, REDPEN);
  Big(14, 15, INK, 'ROLL');
  Lab(14, 17, PEN, 'about the nose itself');
  Lab(14, 18, PEN, 'THE ARROWS: LEFT, RIGHT');
  if upto < 3 then Exit;

  Top(30, 9.5);
  Turn(30, 9.5, 4.2, 60, 120, REDPEN);
  Big(26, 15, INK, 'YAW');
  Lab(26, 17, PEN, 'the heading');
  Lab(26, 18, PEN, 'no key of its own');
  Lab(1, 22, INK, 'Lesson 14 had ONE axis, yaw, on the arrows, and leaned the picture');
  Lab(1, 23, INK, 'to look like a turn. Now the arrows ROLL, the stick PITCHES, and the');
  Lab(1, 24, INK, 'heading changes only because of the two together.');
  Lab(1, 27, REDPEN, 'A turn is two moves: bank, then pull.');
  Ring(1, 27, 19);
end;

{ ==========================================================================
   PAGE 2 - the stick is in the aeroplane. The same pull, three banks.
   q = 16 eighths: roll 64 -> cos 0, sin 256; roll 32 -> 181 and 181.
   ========================================================================== }
procedure PageStick(upto: Integer);
begin
  Big(1, 1, INK, 'THE STICK IS IN THE AEROPLANE');
  Lab(1, 3, INK, 'Pull, and the nose goes towards the PILOT''S HEAD - wherever that is.');
  Rear(6, 10, 0);
  Arrow(6, 9, 6, 5.5, REDPEN, True);
  Lab(7, 5, REDPEN, 'the pull');
  Lab(2, 15, PEN, 'wings level:');
  Lab(2, 16, PEN, 'the pull CLIMBS');
  if upto < 2 then Exit;

  Rear(18, 10, Pi / 4);
  Arrow(18 + 0.7 * 0.71, 10 - 0.7 * 0.71, 18 + 3.4 * 0.71, 10 - 3.4 * 0.71, REDPEN, True);
  Lab(14, 15, PEN, 'banked 45:');
  Lab(14, 16, PEN, 'half climb, half turn');
  Rear(30, 10, Pi / 2);
  Arrow(31, 10, 33.8, 10, REDPEN, True);
  Lab(26, 15, PEN, 'banked 90:');
  Lab(26, 16, PEN, 'the pull TURNS');
  if upto < 3 then Exit;

  Lab(1, 19, PEN, 'pitch   += q x cos(roll)      the part of the pull that climbs');
  Lab(1, 20, PEN, 'heading += q x sin(roll)      the part of the pull that turns');
  Lab(1, 22, INK, 'q = 16 eighths. Banked 90 (roll 64): cos 0, sin 256 - all turn.');
  Lab(1, 23, INK, 'Banked 45 (roll 32): cos = sin = 181: 16 x 181 / 256 = 11 eighths');
  Lab(1, 24, INK, 'of climb AND 11 of turn. Upside down: cos -256, and the pull dives.');
  Lab(1, 27, REDPEN, 'Every turn in the program is these two lines.');
  Ring(1, 27, 23);
end;

{ ==========================================================================
   PAGE 3 - the eighths. q ramps 2 a tick to 16; what does not make a whole
   step waits in pfrac. 11 a tick: 1 r3, 1 r6, 2 r1. And -3.
   ========================================================================== }
procedure PageEighths(upto: Integer);
var k, q, q0 : Integer;
begin
  Big(1, 1, INK, 'EIGHTHS OF A STEP');
  Thick(CX(2), CY(13), CX(18), CY(13), PENCIL);
  Thick(CX(2), CY(13), CX(2), CY(4), PENCIL);
  Lab(13, 14, PENCIL, 'ticks held');
  Lab(1, 4, PENCIL, 'q');
  Lab(19, 5, PENCIL, '16');
  q0 := 0;
  for k := 1 to 15 do
  begin
    q := 2 * k;  if q > 16 then q := 16;
    Thick(CX(2 + k - 1), CY(13 - q0 / 2), CX(2 + k), CY(13 - q0 / 2), PEN);
    Thick(CX(2 + k), CY(13 - q0 / 2), CX(2 + k), CY(13 - q / 2), PEN);
    q0 := q;
  end;
  Lab(21, 6, INK, 'A held pull BUILDS: two');
  Lab(21, 7, INK, 'eighths a tick, up to 16 -');
  Lab(21, 8, INK, 'two whole steps a tick,');
  Lab(21, 9, INK, '51 degrees a second.');
  Lab(21, 11, REDPEN, 'A tap is 2 eighths: a third');
  Lab(21, 12, REDPEN, 'of a degree. That is aiming.');
  if upto < 2 then Exit;

  Lab(1, 16, INK, 'A step is a 256th of a circle; less than one waits, in pfrac:');
  Lab(3, 18, PEN, 'tick 1:  11      -> 1 step,  3 eighths wait');
  Lab(3, 19, PEN, 'tick 2:  11 + 3  -> 1 step,  6 wait');
  Lab(3, 20, PEN, 'tick 3:  11 + 6  -> 2 steps, 1 waits');
  if upto < 3 then Exit;

  Lab(1, 22, INK, 'Steps = SAR by 3, the eighths left = AND 7. And backwards too:');
  Lab(3, 23, PEN, '-3:  SAR 3 -> -1 step,  AND 7 -> 5 eighths,  -8 + 5 = -3');
  Lab(1, 26, REDPEN, 'Lesson 17''s fraction again - three bits instead of eight.');
  Ring(1, 26, 28);
end;

{ ==========================================================================
   PAGE 4 - over the top. A loop, and the seam three angles have at the
   vertical: pitch 65 -> 63, heading + 128, roll + 128.
   ========================================================================== }
procedure PageTop(upto: Integer);
begin
  Big(1, 1, INK, 'OVER THE TOP');
  SetColor(PENCIL);
  Circle(CX(10), CY(14), 7 * CELL);
  Side(10, 21);
  Lab(8, 23, PEN, 'pitch 0');
  Lab(18, 14, PEN, 'pitch 64:');
  Lab(18, 15, PEN, 'straight up');
  Lab(6, 5, PEN, 'upside down');
  Turn(10, 14, 7, 300, 350, REDPEN);
  if upto < 2 then Exit;

  Lab(18, 17, INK, 'One more step of pull and pitch');
  Lab(18, 18, INK, 'would be 65 - which means 63,');
  Lab(18, 19, INK, 'the other way, upside down.');
  Lab(18, 21, PEN, 'pitch    65  ->  128 - 65 = 63');
  Lab(18, 22, PEN, 'heading  +128: half a circle');
  Lab(18, 23, PEN, 'roll     +128: half a circle');
  if upto < 3 then Exit;

  Lab(1, 26, INK, 'All three describe the same aeroplane, so the picture does not jump.');
  Lab(1, 28, REDPEN, 'A direction in three numbers has a SEAM. The program steps over it.');
  Ring(1, 28, 33);
end;
