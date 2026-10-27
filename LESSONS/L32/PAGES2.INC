{ ==========================================================================
   PAGE 4 - F4: the eye on a sphere. From the side: the height and the
   distance; from above: the way round; worked on the fighter.
   ========================================================================== }
procedure PageSphere(upto: Integer);
var a: Real;
begin
  Big(1, 1, INK, 'F4: THE EYE ON A SPHERE');
  Lab(1, 3, INK, 'OWL FLY III''s orbit camera. Three numbers place the eye:');
  Lab(2, 4, PEN, 'tgaz  the way round    tgel  how high    tgrad  how far');
  { from the side: the aeroplane at (8, 14), the eye up and back }
  a := 0.42;                              { about 24 degrees, for the drawing }
  Jet(8, 14, 64, GREEN);
  Dashed(CX(2), CY(14), CX(17), CY(14), PENCIL);
  Thick(CX(8), CY(14), CX(8 - 7 * Cos(a)), CY(14 - 7 * Sin(a)), PEN);
  Dot(CX(8 - 7 * Cos(a)), CY(14 - 7 * Sin(a)), REDPEN);
  LabXY(CX(8 - 7 * Cos(a)) - 10, CY(14 - 7 * Sin(a)) - 14, REDPEN, 'eye');
  Dashed(CX(8 - 7 * Cos(a)), CY(14 - 7 * Sin(a)), CX(8 - 7 * Cos(a)), CY(14), PENCIL);
  LabXY(CX(5), CY(9.4), PEN, 'tgrad');
  LabXY(CX(6.0), CY(13.2), PENCIL, 'tgel');
  LabXY(CX(0.6), CY(12.2), PENCIL, 'h');
  LabXY(CX(3.5), CY(14.3), PENCIL, 'r');
  Lab(19, 7, PEN, 'h = sin(tgel) x tgrad');
  Lab(19, 8, PEN, 'r = cos(tgel) x tgrad');
  Lab(19, 10, INK, 'h above the aeroplane,');
  Lab(19, 11, INK, 'r out along the ground.');
  if upto < 2 then Exit;

  Lab(1, 17, PEN, 'camx = x - sin(tgaz) x r   camz = z - cos(tgaz) x r   camy = y + h');
  Lab(1, 18, INK, 'Behind it along tgaz - and it LOOKS at the aeroplane:');
  Lab(2, 19, REDPEN, 'heading = tgaz        pitch = -tgel');
  Lab(1, 20, PENCIL, 'up on the sphere is looking down. The roll: nought.');
  if upto < 3 then Exit;

  Lab(1, 23, INK, 'F4 on the fighter, flying east: tgaz = 64, tgel = 12, tgrad = 100.');
  Lab(2, 24, PEN, 'sin 12 = 74, cos 12 = 245:  h = 74 x 100 / 256 = 28,  r = 95');
  Lab(2, 25, PEN, 'sin 64 = 256, cos 64 = 0:   the eye 95 west of it, 28 above');
  Lab(1, 27, REDPEN, 'Right behind its tail, a little high, looking down 17 degrees.');
end;

{ ==========================================================================
   PAGE 5 - a camera is six numbers. The keys; CAMSET and CAMRST round the
   frame; the fact; and what is not done yet.
   ========================================================================== }
procedure PageSix(upto: Integer);
begin
  Big(1, 1, INK, 'A CAMERA IS SIX NUMBERS');
  Lab(1, 3, INK, 'The keys, the game''s, held - the eye wants a pull, not a step:');
  Lab(2, 5, PEN, 'LEFT / RIGHT   tgaz -/+ 2         the way round');
  Lab(2, 6, PEN, 'UP / DOWN      tgel +/- 1         -30 to 56: below to overhead');
  Lab(2, 7, PEN, 'Z / X          tgrad -/+ (tgrad/16 + 1)   in and out');
  Lab(1, 9, INK, 'While the eye is outside the arrows are the camera''s: the stick');
  Lab(1, 10, INK, 'is let go, and your aeroplane flies on hands off.');
  if upto < 2 then Exit;

  Lab(1, 12, PEN, 'CAMSET   put camx camy camz heading pitch roll aside,');
  Lab(1, 13, PEN, '         write the sphere''s into the same six words');
  Lab(1, 14, GREEN, 'FRAME    the ground, the houses, the traffic: unchanged');
  Lab(1, 15, PEN, 'CAMRST   the six words back, and SETTRIG - before PHYS');
  Lab(1, 17, INK, 'The physics never sees the camera. The aeroplane flies on from');
  Lab(1, 18, INK, 'where it is; only the picture was taken from somewhere else.');
  if upto < 3 then Exit;

  Lab(1, 20, REDPEN, 'Three of position and three of turn, and nothing else.');
  Ring(1, 20, 27);
  Lab(1, 22, INK, 'In OWL FLY III the chase view, the missile camera and the crash');
  Lab(1, 23, INK, 'replay are the same trick: other numbers in the same six words.');
  Lab(1, 25, PENCIL, 'NOT YET: the traffic turns but never banks or climbs; nobody');
  Lab(1, 26, PENCIL, 'shoots; the eye outside may go into a hill; your own aeroplane');
  Lab(1, 27, PENCIL, 'outside is drawn level.');
end;
