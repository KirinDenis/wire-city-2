{ ==========================================================================
   THE MIDDLE OF THE DISPLAY - small things the pages share.
   ========================================================================== }

{ ---- pencil furniture, lesson 19's, in pixels ---------------------------- }
procedure Axis(x1, y1, x2, y2, c: Integer; dotted: Boolean);
begin
  SetColor(c);
  if dotted then SetLineStyle(DottedLn, 0, NormWidth)
            else SetLineStyle(SolidLn, 0, NormWidth);
  Line(x1, y1, x2, y2);
  SetLineStyle(SolidLn, 0, NormWidth);
end;

procedure Dot(x, y, c: Integer);
begin
  SetFillStyle(SolidFill, c);
  SetColor(c);
  PieSlice(x, y, 0, 360, 3);
end;

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

{ text at a PIXEL position, for labels that sit on a tick and not in a row }
procedure LabXY(x, y: Integer; c: Integer; s: string);
begin
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(c);
  OutTextXY(x, y, s);
end;

function IStr(n: Integer): string;
var s : string;
begin
  Str(n, s);
  IStr := s;
end;

{ one pixel of the game's screen, drawn as a whole cell }
procedure Pix1(u, v: Real; c: Integer);
begin
  FBox(u, v, u + 1, v + 1, c, c);
end;

{ a dimension line, pencil, between two x's at row y (pixels) }
procedure Dim(x1, x2, y: Integer);
begin
  SetColor(PENCIL);
  Line(x1, y, x2, y);
  Line(x1, y - 5, x1, y + 5);
  Line(x2, y - 5, x2, y + 5);
end;

{ the gunsight, centred at cell (u, v): the bar with its gap, and the tick }
procedure Sight(u, v: Real; c: Integer);
begin
  Thick(CX(u - 2), CY(v), CX(u - 0.5), CY(v), c);
  Thick(CX(u + 0.5), CY(v), CX(u + 2), CY(v), c);
  Thick(CX(u), CY(v - 0.5), CX(u), CY(v - 1.2), c);
end;

{ ==========================================================================
   PAGE 1 - the nose and the horizon. The gunsight is where the nose meets
   the glass; the horizon is FOCAL*tan(p) below it. Side view: eye, the
   nose line, the level line, and the glass FOCAL away (12 cells).
   ========================================================================== }
procedure PageNose(upto: Integer);
begin
  Big(1, 1, INK, 'THE MIDDLE OF THE DISPLAY');
  Lab(1, 3, REDPEN, 'Lesson 1C: the gunsight, the horizon line and the pitch ladder.');
  Box(2, 5, 18, 14, PENCIL);
  Sight(10, 9.5, PEN);
  Thick(CX(5.5), CY(12.5), CX(9), CY(12.5), PEN);
  Thick(CX(11), CY(12.5), CX(14.5), CY(12.5), PEN);
  LabXY(CX(2.3), CY(5) + 4, PENCIL, 'the screen');
  LabXY(CX(14.7), CY(12.5) - 3, PEN, 'horizon');
  Lab(20, 6, INK, 'The gunsight is where the');
  Lab(20, 7, INK, 'NOSE points: the middle of');
  Lab(20, 8, INK, 'the screen, 160, 100.');
  Lab(20, 10, INK, 'The horizon line is where');
  Lab(20, 11, INK, 'the horizon really is.');
  if upto < 2 then Exit;

  Dot(CX(3), CY(25), INK);
  LabXY(CX(1), CY(25) + 6, INK, 'the eye');
  Arrow(3, 25, 15, 20.6, PEN, True);
  Dashed(CX(3), CY(25), CX(15), CY(25), PENCIL);
  Axis(CX(15), CY(18), CX(15), CY(27), PENCIL, False);
  LabXY(CX(15.3), CY(18), PENCIL, 'the glass');
  LabXY(CX(8), CY(22.3), PEN, 'the nose');
  LabXY(CX(8), CY(25) + 5, PENCIL, 'level');
  LabXY(CX(5.2), CY(24.4), PEN, 'p');
  Thick(CX(16), CY(20.6), CX(16), CY(25), REDPEN);
  LabXY(CX(16.4), CY(22.5), REDPEN, 'f');
  Dim(CX(3), CX(15), CY(27.2));
  LabXY(CX(7), CY(27.5), PENCIL, 'FOCAL = 220');
  Lab(20, 17, PEN, 'Nose up by p: the horizon is');
  Lab(20, 18, PEN, 'p BELOW the nose, and the');
  Lab(20, 19, PEN, 'lens puts it');
  Lab(20, 21, REDPEN, 'f = FOCAL x tan(p)');
  Ring(20, 21, 9);
  Lab(20, 23, PEN, 'p 10: 220 x 0.18 = 39 px');
  Lab(20, 24, PEN, 'p 30: 220 x 0.58 = 127 px');
  if upto < 3 then Exit;

  Lab(1, 15, GREEN, 'FOCAL is the number the island is drawn with: the marks');
  Lab(1, 16, GREEN, 'lie ON the world. A HUD is focused at infinity - conformal.');
end;

{ ==========================================================================
   PAGE 2 - turned by the bank. The horizon's own frame, t along and f
   across, and the turn APPLYROLL gives every corner of the world.
   bank 30: rcos = 222, rsin = 128.
   ========================================================================== }
procedure PageTurn(upto: Integer);
begin
  Big(1, 1, INK, 'TURNED BY THE BANK');
  Lab(1, 3, INK, 'Everything in the middle is drawn in the HORIZON''S frame: t along');
  Lab(1, 4, INK, 'it, f across it, f growing DOWN - and then turned by the bank.');
  Lab(2, 6, PEN, 'x = 160 + (t x rcos - f x rsin) / 256');
  Lab(2, 7, PEN, 'y = 100 + (t x rsin + f x rcos) / 256');
  Lab(2, 9, INK, 'The same turn APPLYROLL gives every corner of the island.');
  if upto < 2 then Exit;

  Axis(CX(4), CY(18), CX(16), CY(18), PENCIL, True);
  Axis(CX(10), CY(12), CX(10), CY(24), PENCIL, True);
  Arrow(10, 18, 10 + 6 * 0.866, 18 + 6 * 0.5, PEN, True);
  Arrow(10, 18, 10 - 4 * 0.5, 18 + 4 * 0.866, GREEN, True);
  LabXY(CX(15.4), CY(21), PEN, 't');
  LabXY(CX(7.6), CY(21.8), GREEN, 'f');
  Sight(10, 18, REDPEN);
  Lab(19, 13, PEN, 'banked 30 degrees:');
  Lab(19, 14, PEN, 'rcos = 222, rsin = 128');
  Lab(19, 16, PEN, 't = 50, f = 0 lands at');
  Lab(19, 17, PEN, 'x = 160 + 50 x 222/256 = 203');
  Lab(19, 18, PEN, 'y = 100 + 50 x 128/256 = 125');
  if upto < 3 then Exit;

  Lab(1, 26, INK, 'The sky is negative f. Upside down rcos is negative, and the');
  Lab(1, 27, INK, 'gunsight''s tick points DOWN the screen - which is where the sky is.');
  Lab(1, 28, REDPEN, 'One turn for the world and for the HUD.');
  Ring(1, 28, 19);
end;

{ ==========================================================================
   PAGE 3 - the ladder, measured from the nose; the game's sum beside it;
   and when the rungs show.
   ========================================================================== }
procedure PageLadder(upto: Integer);
begin
  Big(1, 1, INK, 'THE LADDER: FROM THE NOSE');
  Lab(1, 3, INK, 'A rung every 7 steps of 256: 9.84 degrees, near enough its 10.');
  Lab(1, 4, INK, 'A rung at angle a, from a nose at pitch p, is p - a below the nose:');
  Lab(2, 6, REDPEN, 'f = FOCAL x tan(p - a)');
  Ring(2, 6, 11);
  Lab(2, 8, PEN, 'nose 37 degrees, 26 steps:');
  Lab(3, 9, PEN, 'rung 40, 28 steps:  220 x tan(-2.8)  = -11  just over the sight');
  Lab(3, 10, PEN, 'rung 50, 35 steps:  220 x tan(-12.7) = -49');
  Lab(3, 11, PEN, 'rung 30, 21 steps:  220 x tan(7.0)   =  27  under it');
  if upto < 2 then Exit;

  Lab(1, 14, INK, 'THE GAME MEASURES FROM THE HORIZON:');
  Lab(2, 15, PEN, 'f = FOCAL x tan(p) - FOCAL x tan(a)');
  Lab(2, 16, PEN, 'level, the two agree. Nose 60, rung 50:');
  Lab(2, 17, PEN, '220 x (1.73 - 1.19) = 119 pixels. The lens: 220 x tan(10) = 39.');
  Lab(2, 19, REDPEN, 'A tangent of a difference is not a difference of tangents.');
  if upto < 3 then Exit;

  Lab(1, 22, INK, 'ONLY WHEN THE HORIZON HAS GONE: |220 x tan(p)| over 92 pixels -');
  Lab(1, 23, INK, 'about 23 degrees. While you can see the horizon, the rungs stay out');
  Lab(1, 24, INK, 'of the way: the game''s rule, learned in NEWTON.');
  Lab(1, 26, PEN, 'Solid above the horizon, dashed below; the number at the end that');
  Lab(1, 27, PEN, 'is on the LEFT of the screen - upside down, that is the other one.');
end;
