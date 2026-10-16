{ ==========================================================================
   THE WING - small things the pages share.
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

{ the flight path marker, centred at cell (u, v): a circle, wings, a fin }
procedure Marker(u, v: Real; c: Integer);
begin
  SetColor(c);
  Circle(CX(u), CY(v), 6);
  Line(CX(u) - 16, CY(v), CX(u) - 7, CY(v));
  Line(CX(u) + 7, CY(v), CX(u) + 16, CY(v));
  Line(CX(u), CY(v) - 7, CX(u), CY(v) - 12);
end;

{ ==========================================================================
   PAGE 1 - the nose is not the path. Side on: the nose, the path under
   it, and alpha between; then the same on the HUD.
   ========================================================================== }
procedure PageAlpha(upto: Integer);
begin
  Big(1, 1, INK, 'THE NOSE IS NOT THE PATH');
  Lab(1, 3, REDPEN, 'Lesson 1D: the wing - lift, the angle of attack, and the stall.');
  Thick(CX(4), CY(12), CX(14), CY(9.5), PEN);
  Thick(CX(4), CY(12), CX(3), CY(10.6), PEN);
  Arrow(14, 9.5, 19, 8.25, PEN, True);
  LabXY(CX(19.3), CY(8) - 4, PEN, 'the nose');
  Arrow(9, 10.7, 19, 10.7, GREEN, True);
  LabXY(CX(19.3), CY(10.7) - 3, GREEN, 'where it goes');
  SetColor(REDPEN);
  Arc(CX(9), CY(10.7), 0, 14, 7 * CELL);
  LabXY(CX(16.4), CY(9.7) - 2, REDPEN, 'alpha');
  Lab(1, 14, INK, 'A wing holds the aeroplane up by turning the air down - and to do');
  Lab(1, 15, INK, 'that it meets the air at an angle. The nose points a little ABOVE');
  Lab(1, 16, INK, 'where the aeroplane goes: the ANGLE OF ATTACK, alpha.');
  if upto < 2 then Exit;

  Sight(8, 21, PEN);
  Thick(CX(3), CY(19), CX(6.5), CY(19), PENCIL);
  Thick(CX(9.5), CY(19), CX(13), CY(19), PENCIL);
  LabXY(CX(13.4), CY(19) - 3, PENCIL, '10');
  Marker(8, 24, GREEN);
  Arrow(11, 21, 11, 23.8, REDPEN, True);
  LabXY(CX(11.4), CY(22.3), REDPEN, 'alpha');
  Lab(17, 20, PEN, 'On the HUD: the gunsight is the');
  Lab(17, 21, PEN, 'nose, the circle with wings the');
  Lab(17, 22, PEN, 'path. y = 100 + alpha x 173/256');
  Lab(17, 23, PEN, 'Cruising: 19 eighths, 3.4 degrees,');
  Lab(17, 24, PEN, '13 pixels under the gunsight.');
  if upto < 3 then Exit;

  Lab(1, 27, REDPEN, 'Read on 1C''s ladder, the gap IS the angle of attack.');
  Ring(1, 27, 26);
end;

{ ==========================================================================
   PAGE 2 - lift. What the wing has, what the pilot asks, and the angle
   that squares them; cruising numbers.
   ========================================================================== }
procedure PageLift(upto: Integer);
begin
  Big(1, 1, INK, 'LIFT');
  Lab(1, 3, INK, 'L = k x rho x vel^2 x alpha: the air, the speed squared, the angle.');
  Lab(1, 4, INK, 'At the critical angle, ACRIT, fifteen degrees, the wing gives most:');
  Lab(2, 6, PEN, 'Nmax = 10 x (vel / VS1)^2 x rho / 256       tenths of a G');
  Lab(2, 7, PENCIL, 'VS1 = 250: one G at ACRIT, in the air by the sea');
  if upto < 2 then Exit;

  Lab(1, 10, INK, 'The stick ASKS for a load - hands off, enough to hold the path:');
  Lab(2, 12, PEN, 'Ncmd = 10 x cos(pitch) + q x vel / 512');
  Lab(1, 14, INK, 'and the wing finds the angle that gives it:');
  Lab(2, 16, REDPEN, 'alpha = ACRIT x Ncmd / Nmax');
  Ring(2, 16, 13);
  if upto < 3 then Exit;

  Lab(1, 19, PEN, 'cruising, 736, at a height of 1000:  rho = 256 - 1000/8 = 131');
  Lab(1, 20, PEN, 'Nmax = 10 x (736/250)^2 x 131/256 = 44: four point four G to give');
  Lab(1, 21, PEN, 'hands off:  alpha = 85 x 10 / 44 = 19 eighths = 3.4 degrees');
  Lab(1, 22, PEN, 'full pull:  Ncmd = 10 + 16 x 736/512 = 33,  alpha = 63 = 11 degrees');
  Lab(1, 25, INK, 'Slower, or higher, and the same G takes a bigger angle.');
end;

{ ==========================================================================
   PAGE 3 - the stall is an angle. Lift against alpha: up to ACRIT, then
   down to nothing at twice it. Then the stall speed, and Newton.
   ========================================================================== }
procedure PageStall(upto: Integer);
begin
  Big(1, 1, INK, 'THE STALL IS AN ANGLE');
  Axis(CX(3), CY(12), CX(19), CY(12), PENCIL, False);
  Axis(CX(3), CY(12), CX(3), CY(4), PENCIL, False);
  LabXY(CX(19.3), CY(12) - 3, PENCIL, 'alpha');
  LabXY(CX(3.3), CY(4) - 2, PENCIL, 'lift');
  Thick(CX(3), CY(12), CX(11), CY(5), PEN);
  Thick(CX(11), CY(5), CX(18), CY(12), REDPEN);
  Axis(CX(11), CY(5), CX(11), CY(12), PENCIL, True);
  LabXY(CX(10), CY(12) + 5, PENCIL, 'ACRIT');
  LabXY(CX(17), CY(12) + 5, PENCIL, '2 ACRIT');
  LabXY(CX(11.4), CY(5) - 4, PEN, 'Nmax');
  Lab(21, 5, INK, 'Up to ACRIT the lift');
  Lab(21, 6, INK, 'grows with the angle.');
  Lab(21, 8, REDPEN, 'Past it the air leaves');
  Lab(21, 9, REDPEN, 'the top of the wing,');
  Lab(21, 10, REDPEN, 'and the lift FALLS.');
  if upto < 2 then Exit;

  Lab(1, 15, INK, 'Ask for more than the wing has - pull too hard, or fly too slow -');
  Lab(1, 16, INK, 'and alpha passes ACRIT: the lift falls, the path drops, the nose');
  Lab(1, 17, INK, 'stays high. At ANY speed.');
  Lab(2, 18, PEN, 'N = Nmax x (2 x ACRIT - alpha) / ACRIT');
  if upto < 3 then Exit;

  Lab(1, 21, INK, 'The tape shows the speed THIS pull would stall at:');
  Lab(2, 22, PEN, 'vstall = VS1 x sqrt(Ncmd/10 x 256/rho)');
  Lab(2, 23, PEN, 'at a height of 1000:  1 G 349,  3.3 G 635');
  Lab(2, 25, PEN, 'Newton: T = 122112.  2048, 1053, 584, 396, 352, 349');
  Lab(1, 27, REDPEN, 'Guess big, average with T / guess. Six times.');
  Ring(1, 27, 23);
end;
