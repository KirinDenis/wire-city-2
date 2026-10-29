{ ==========================================================================
   THE GUNS - small things the pages share, and pages 1 to 3.
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

{ ==========================================================================
   PAGE 1 - a round is a piece. Its velocity is the gun's and the
   aeroplane's added; gravity pulls it; how far it drops.
   ========================================================================== }
procedure PageRound(upto: Integer);
var i : Integer;
    x, y : Real;
begin
  Big(1, 1, INK, 'A ROUND IS A PIECE');
  Lab(1, 3, REDPEN, 'Lesson 22: the guns, yours and theirs, and the breakup in the sky.');
  Lab(1, 5, INK, 'Lesson 21''s piece with nothing to break: a place, a velocity, and');
  Lab(1, 6, INK, 'gravity. It leaves the gun with TWO velocities added:');
  Lab(2, 8, PEN, 'the muzzle''s     75 units a tick, along the nose');
  Lab(2, 9, PEN, 'the aeroplane''s  wdx, wdy, wdz - the step it made this tick');
  Lab(1, 11, INK, 'At 736 the aeroplane makes 11.5 a tick: a round fired forward goes');
  Lab(1, 12, REDPEN, '86.5 a tick, not 75. The gun is carried by its aeroplane.');
  if upto < 2 then Exit;

  Thick(CX(2), CY(14), CX(4), CY(14), PEN);
  for i := 1 to 15 do
  begin
    x := 4 + i * 1.9;
    y := 14 + 0.5 * 0.074 * Sqr(i * 4) / 25;    { the drop, to scale: 25 units a cell }
    Dot(CX(x), CY(y), PEN);
  end;
  Dashed(CX(4), CY(14), CX(33), CY(14), PENCIL);
  LabXY(CX(21), CY(14) - 12, PENCIL, 'where the nose points');
  LabXY(CX(9), CY(16.5), PEN, 'where the round goes');
  LabXY(CX(4), CY(19.6), PENCIL, 'one dot every 4 ticks; down to scale, 25 units a square');
  Lab(1, 21, INK, 'Gravity pulls a round like everything else: 19/256 of a unit a tick');
  Lab(1, 22, INK, 'a tick - the real 9.8, at 0.4 m a unit and 18.2 ticks a second.');
  if upto < 3 then Exit;

  Lab(2, 24, PEN, 'drop = g t^2 / 2:   12 ticks, about 1000 away:    5 units');
  Lab(2, 25, PEN, '                    60 ticks, the end of its life: 134 units');
  Lab(1, 27, REDPEN, 'Aim at something far, and aim a little high.');
  Ring(1, 27, 22);
  Lab(1, 29, PENCIL, 'a round lives 60 ticks: 75 x 60 = 4500, the game''s reach');
end;

{ ==========================================================================
   PAGE 2 - the nose, not the path. The gun is bolted to the airframe;
   the gunsight is the nose; the first build fired along the path.
   ========================================================================== }
procedure PageNose(upto: Integer);
begin
  Big(1, 1, INK, 'THE NOSE, NOT THE PATH');
  Lab(1, 3, INK, 'Lesson 1D: the aeroplane goes along its PATH, and its nose points a');
  Lab(1, 4, INK, 'little above it - the angle of attack.');
  Thick(CX(4), CY(13), CX(14), CY(10.5), PEN);
  Thick(CX(4), CY(13), CX(3), CY(11.6), PEN);
  Arrow(14, 10.5, 26, 7.5, PEN, True);
  LabXY(CX(26.4), CY(7.2), PEN, 'the nose: the gun');
  Arrow(9, 11.7, 26, 11.7, GREEN, True);
  LabXY(CX(26.4), CY(11.4), GREEN, 'the path');
  if upto < 2 then Exit;

  Lab(1, 16, INK, 'The gun is bolted to the airframe, so a round leaves along the NOSE');
  Lab(1, 17, INK, '- and the gunsight is drawn there. NOSEKEEP keeps the nose of each');
  Lab(1, 18, INK, 'frame, and FIRE1 aims by it.');
  if upto < 3 then Exit;

  Lab(1, 21, REDPEN, 'THE FIRST BUILD fired along the path, and the rounds did not go');
  Lab(1, 22, REDPEN, 'where the gunsight showed.');
  Lab(1, 24, INK, 'Path and nose part most when the aeroplane is slow and the angle of');
  Lab(1, 25, INK, 'attack is big - just when a pilot pulls hard to bring a target in.');
end;

{ ==========================================================================
   PAGE 3 - the hit is real. Four quarter steps; a box by type; no circle
   and no dice; the last hit breaks it from where the round really is.
   ========================================================================== }
procedure PageHit(upto: Integer);
begin
  Big(1, 1, INK, 'THE HIT IS REAL');
  Lab(1, 3, INK, 'OWL FLY III counts a hit when the target is inside the aiming ring');
  Lab(1, 4, INK, 'on the screen, and rolls a dice for the AI. Here a round hits only');
  Lab(1, 5, INK, 'what it really reaches.');
  if upto < 2 then Exit;

  Box(14, 9, 18, 13, PENCIL);
  LabXY(CX(14), CY(8.2), PENCIL, 'the box: R each way');
  Dot(CX(6.4), CY(11), PEN);  Dot(CX(9.1), CY(11), PEN);
  Dot(CX(11.8), CY(11), PEN);  Dot(CX(14.5), CY(11), REDPEN);
  LabXY(CX(4), CY(13.6), PEN, 'four quarter steps a tick: 75 / 4 = 19');
  Lab(1, 15, INK, 'A round moves 75 a tick and more; a fighter''s box is 28 across. In');
  Lab(1, 16, INK, 'one jump it could pass right through. So: four quarter steps, a test');
  Lab(1, 17, INK, 'after each one -');
  Lab(2, 18, PEN, '|x - pax| < R  and  |y - pay| < R  and  |z - paz| < R');
  Lab(2, 19, PENCIL, 'R: fighter 14, bomber 28, radar 18, transport 20, tanker 22');
  if upto < 3 then Exit;

  Lab(1, 22, INK, 'A fighter takes 3 hits, the big ones 5. The last one breaks it with');
  Lab(1, 23, INK, 'lesson 21''s laws: the blast starts where the round REALLY is, and');
  Lab(1, 24, INK, 'the push from outside is the round''s own momentum - mass 4, at its');
  Lab(1, 25, INK, 'speed against the aeroplane''s.');
  Lab(1, 27, REDPEN, 'Where it struck, and which way, decide the breakup.');
  Ring(1, 27, 26);
end;
