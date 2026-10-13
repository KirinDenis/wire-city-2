{ ==========================================================================
   THE TAPES - small things the pages share.
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

{ ==========================================================================
   PAGE 1 - a number becomes a place. A number line, a window on it, and
   the sum that puts every mark on its row. One cell is 25 of speed.
   ========================================================================== }
procedure PageTape(upto: Integer);
var m : Integer;
    v, len : Real;
    inside : Boolean;
    c : Integer;
begin
  Big(1, 1, INK, 'A NUMBER BECOMES A PLACE');
  Lab(1, 3, REDPEN, 'Lesson 1B: the numbers in the corner become instruments.');
  { the whole number line, 500 to 1000, and the window round 736 }
  Axis(CX(6), CY(5), CX(6), CY(26), PENCIL, False);
  m := 500;
  while m <= 1000 do
  begin
    v := 15 - (m - 736) / 25;
    if (v >= 5) and (v <= 26) then
    begin
      inside := Abs(m - 736) <= 140;
      if inside then c := PEN else c := PENCIL;
      if m mod 100 = 0 then len := 1.2 else len := 0.6;
      SetColor(c);
      Line(CX(6 - len), CY(v), CX(6), CY(v));
      if m mod 100 = 0 then LabXY(CX(1.6), CY(v) - 3, c, IStr(m));
    end;
    Inc(m, 25);
  end;
  Thick(CX(6), CY(15 - 140 / 25), CX(6), CY(15 + 140 / 25), PEN);
  Box(0.8, 15 - 140 / 25, 7, 15 + 140 / 25, PEN);
  Arrow(10, 15, 6.4, 15, REDPEN, True);
  LabXY(CX(10.4), CY(15) - 3, REDPEN, '736 now');
  Lab(13, 6, INK, 'A scale is a number line seen through a');
  Lab(13, 7, INK, 'window. The window''s middle is the value');
  Lab(13, 8, INK, 'now; the box is what fits on the screen.');
  if upto < 2 then Exit;

  Lab(13, 11, PEN, 'y = 83 - (mark - value) / 4');
  Lab(13, 13, PEN, 'mark 800:  83 - (800 - 736)/4 = 67');
  Lab(13, 14, PEN, 'mark 700:  83 - (700 - 736)/4 = 92');
  Lab(13, 16, INK, 'Row 83 is the pointer. More speed is');
  Lab(13, 17, INK, 'higher up; 140 either side fits.');
  if upto < 3 then Exit;

  Lab(13, 20, INK, 'Speed up, and the whole scale slides');
  Lab(13, 21, INK, 'DOWN past the pointer, like a tape drum.');
  Lab(13, 22, INK, 'Nothing is stored: it is drawn again');
  Lab(13, 23, INK, 'from the value, every frame.');
  Lab(13, 26, REDPEN, 'A digit is read. A place is SEEN.');
  Ring(13, 26, 17);
end;

{ ==========================================================================
   PAGE 2 - where the first mark is. DIV and MUL for the speed; for the
   compass, whose step is a power of two, an AND.
   ========================================================================== }
procedure PageFirst(upto: Integer);
begin
  Big(1, 1, INK, 'WHERE THE FIRST MARK IS');
  Lab(1, 3, INK, 'The bottom of the window: 736 - 140 = 596. The first mark above it:');
  Lab(2, 5, PEN, 'first = (bottom + step - 1) / step x step');
  Lab(2, 7, PEN, '(596 + 24) / 25 = 24, rest 20     DIV: the rest is thrown away');
  Lab(2, 8, PEN, '24 x 25 = 600                     MUL: back to a mark');
  Lab(2, 10, INK, 'Add step - 1 first, and the divide rounds UP instead of down.');
  if upto < 2 then Exit;

  Big(1, 12, INK, 'THE COMPASS: AN AND');
  Lab(2, 14, INK, 'Its step is 4, a power of two - and then the divide is an AND.');
  Lab(2, 16, PEN, 'heading 10:   10 - 40 + 3 + 256 = 229');
  Lab(2, 17, PEN, '229 = 1110 0101   AND 1111 1100   = 1110 0100 = 228');
  Lab(2, 18, PEN, '228 - 256 - 10 = -38 steps from the nose');
  Lab(2, 19, PEN, 'x = 160 + (-38) x 3/2 = 103: a step is a pixel and a half');
  if upto < 3 then Exit;

  Lab(2, 22, INK, 'Lesson 1A''s mask again: clear the low two bits, and the number');
  Lab(2, 23, INK, 'falls to a multiple of four. The 256 keeps it above nought.');
  Lab(2, 26, REDPEN, 'Round down to a power of two: an AND, no DIV.');
  Ring(2, 26, 23);
end;

{ ==========================================================================
   PAGE 3 - the IVV. One tick's step along the nose, split into a run and
   a climb; the climb is wdy, and the IVV is wdy on the tape.
   tan(14 deg) = 0.25: twenty cells along, five up.
   ========================================================================== }
procedure PageIvv(upto: Integer);
begin
  Big(1, 1, INK, 'THE IVV: HOW FAST YOU CLIMB');
  Lab(1, 3, INK, 'Each tick PHYS moves the aeroplane one step along its nose.');
  Dashed(CX(3), CY(12), CX(23), CY(12), PENCIL);
  Arrow(3, 12, 23, 7, PEN, True);
  Arrow(23, 12, 23, 7, REDPEN, True);
  LabXY(CX(9), CY(12) + 6, PENCIL, 'the run: step x cos(nose)');
  LabXY(CX(23.6), CY(9.4), REDPEN, 'the climb:');
  LabXY(CX(23.6), CY(9.4) + 10, REDPEN, 'step x sin(nose)');
  LabXY(CX(7), CY(10.5) - 4, PEN, 'the step');
  LabXY(CX(5.6), CY(11.4), PENCIL, '14 deg');
  if upto < 2 then Exit;

  Lab(2, 14, PEN, 'vel 736:  step = 736 x 4 = 2944 256ths of a unit a tick');
  Lab(2, 15, PEN, 'nose 10 steps up, 14 degrees:  sin = 62/256');
  Lab(2, 16, PEN, 'climb = 2944 x 62 / 256 = 713 256ths: 2.8 units a tick');
  Lab(2, 17, PEN, '2.8 x 18.2 ticks a second: 51 units a second');
  if upto < 3 then Exit;

  Lab(2, 20, INK, 'On the tape: 713 SAR 7 = 5 pixels over the pointer, in cyan.');
  Lab(2, 21, INK, 'The IVV leads: it shows where the height is GOING, before');
  Lab(2, 22, INK, 'the height tape has moved a pixel.');
  Lab(2, 26, REDPEN, 'The IVV is wdy: the climb PHYS already worked out.');
  Ring(2, 26, 25);
end;

{ ==========================================================================
   PAGE 4 - the G. The bottom of a pull-up: the path bends, the seat
   presses up into the pilot, by v x w on top of the weight.
   ========================================================================== }
procedure PageG(upto: Integer);
begin
  Big(1, 1, INK, 'THE G: HOW HARD THE SEAT PUSHES');
  Lab(1, 3, INK, 'Pull, and the path bends into a circle. On a circle, a body is');
  Lab(1, 4, INK, 'pressed outward by v x w: the speed times how fast it turns.');
  SetColor(PENCIL);
  SetLineStyle(DashedLn, 0, NormWidth);
  Circle(CX(9), CY(13), 6 * CELL);
  SetLineStyle(SolidLn, 0, NormWidth);
  Dot(CX(9), CY(19), PEN);
  Arrow(9, 19, 14.5, 19, PEN, True);
  LabXY(CX(14.7), CY(19) - 3, PEN, 'v');
  Arrow(9, 19.4, 9, 23.5, REDPEN, True);
  LabXY(CX(9.5), CY(22.5), REDPEN, '1 + v x w / g');
  Arrow(9, 18.6, 9, 14.5, PENCIL, False);
  LabXY(CX(9.5), CY(15), PENCIL, 'to the middle');
  if upto < 2 then Exit;

  Lab(18, 7, INK, 'One G is the weight. The pull');
  Lab(18, 8, INK, 'adds v x w / g on top of it.');
  Lab(18, 10, PEN, 'G = 1 + v x w / g');
  Lab(18, 11, PEN, 'v = vel; w = q, the stick,');
  Lab(18, 12, PEN, '  in eighths of a step a tick');
  Lab(18, 13, PEN, 'the game folds g and the rest');
  Lab(18, 14, PEN, '  into one number, 512:');
  Lab(18, 16, REDPEN, 'G = 1 + q x vel / 512');
  Ring(18, 16, 11);
  if upto < 3 then Exit;

  Lab(18, 19, PEN, 'full pull at cruise:');
  Lab(18, 20, PEN, '16 x 736 / 512 = 23 tenths: 3.3');
  Lab(18, 21, PEN, 'twice the speed: twice the G');
  Lab(18, 23, INK, 'In tenths, so it is an integer.');
  Lab(18, 24, INK, '16 x 2600 is past 32767: IMUL');
  Lab(18, 25, INK, 'into DX:AX, then IDIV by 512.');
  Lab(1, 27, REDPEN, 'A fast pull is a hard pull: why pilots grey out.');
end;
