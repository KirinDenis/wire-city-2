{ ==========================================================================
   THE PENS - the first page, and it teaches the language of all the rest.

   One colour, one meaning, exactly as the programs do it - only here the
   colours are the four things you actually hold.
   ========================================================================== }
procedure PagePens(upto: Integer);
procedure Swatch(row: Real; c: Integer);
begin
  SetColor(c);
  SetLineStyle(SolidLn, 0, ThickWidth);
  Line(CX(2), CY(row), CX(5), CY(row));
  SetLineStyle(SolidLn, 0, NormWidth);
end;
begin
  Head(0.9, 0.7, INK, 'a pencil, a pen, and squared paper');
  Lab(0.9, 2.3, REDPEN, 'lesson twelve, and there is no assembler on any page of it.');
  if upto < 2 then Exit;

  Swatch(6.2, PENCIL);
  Lab(5.6, 5.9, INK, 'pencil - rays, axes, dimensions. What you rub out.');
  Swatch(8.2, PEN);
  Lab(5.6, 7.9, INK, 'blue - the things themselves.');
  Swatch(10.2, GREEN);
  Lab(5.6, 9.9, INK, 'green - the glass, and whatever lands on it.');
  Swatch(12.2, REDPEN);
  Lab(5.6, 11.9, INK, 'red - the ANSWER. And the margin, down the right.');
  if upto < 3 then Exit;

  SetColor(PENCIL);
  Line(CX(0.9), CY(15), CX(24), CY(15));
  Lab(0.9, 15.6, INK, 'Take a notebook. Draw along with me, do not just watch.');
  Lab(0.9, 16.6, INK, 'By the last page you will work out, with a pencil, which');
  Lab(0.9, 17.6, INK, 'pixel a corner of a cube lands on.');
  Lab(0.9, 19.4, GREY, 'A machine does that sixty times a second and tells you');
  Lab(0.9, 20.4, GREY, 'nothing about how. You are going to do it once, slowly,');
  Lab(0.9, 21.4, GREY, 'and then you will know.');
end;

{ ==========================================================================
   THE RIGHT TRIANGLE, the way every book draws it: y UPWARD.

   It is deliberately the textbook picture, because that is the one the
   reader already has in his head - and because the page after next is
   going to turn it over and show what that costs.

   The numbers are a 3-4-5 scaled up: eight cells across, six up, ten along
   the slope. You do not measure that triangle, you COUNT it.
   ========================================================================== }
procedure PageTri(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'the right triangle, as a book draws it');
  Lab(0.9, 2.3, REDPEN, '1 cell = 40.  y UPWARD, origin at the bottom left.');
  SetColor(PENCIL);
  Line(CX(4), CY(17), CX(23), CY(17));  ArrowR(CX(23.5), CY(17));
  Lab(23.8, 16.6, PENCIL, 'x');
  Line(CX(4), CY(17), CX(4), CY(6));    ArrowU(CX(4), CY(6));
  Lab(2.9, 5.6, PENCIL, 'y');
  if upto < 2 then Exit;

  SetColor(PEN);                        { 8 across, 6 up, 10 on the slope }
  Line(CX(4),  CY(17), CX(12), CY(17));
  Line(CX(12), CY(17), CX(12), CY(11));
  Line(CX(12), CY(11), CX(4),  CY(17));
  Dot(CX(12), CY(11), REDPEN);
  if upto < 3 then Exit;

  SetColor(PENCIL);
  Arc(CX(4), CY(17), 0, 37, CX(2));
  Lab(6.2, 16.2, INK, 'a');
  Lab(6.6, 17.3, INK, 'x = 320  - 8 cells');
  Lab(12.3, 13.6, INK, 'y = 240');
  Lab(12.3, 14.6, GREY, '6 cells');
  Lab(6.2, 13.4, INK, 'r = 400');
  Lab(12.6, 10.6, REDPEN, '( 320, 240 )');
  Lab(0.9, 22.2, GREY, 'eight across, six up, ten along the slope - the 3-4-5');
  Lab(0.9, 23.2, GREY, 'you can count instead of trusting me.');
  if upto < 4 then Exit;

  SetColor(PENCIL);
  Line(CX(25), CY(5), CX(25), CY(22));
  Lab(25.6, 5.6, INK,  'x = r cos a');
  Lab(25.6, 6.6, INK,  'y = r sin a');
  Lab(25.6, 8.4, GREY, 'a = 36.87 deg');
  Lab(25.6, 9.4, GREY, 'cos a = 0.8');
  Lab(25.6, 10.4, GREY, 'sin a = 0.6');
  if upto < 5 then Exit;

  Lab(25.6, 12.2, INK, 'x = 400 * 0.8');
  Lab(25.6, 13.2, INK, 'y = 400 * 0.6');
  Lab(25.6, 14.6, REDPEN, 'x = 320');
  Lab(25.6, 15.6, REDPEN, 'y = 240');
  SetColor(REDPEN);
  Ellipse(CX(28), CY(14.9), 0, 360, CX(2.4), CY(0.5));
  Ellipse(CX(28), CY(15.9), 0, 360, CX(2.4), CY(0.5));
  Lab(25.6, 17.4, GREY, 'and there it is:');
  Lab(25.6, 18.4, GREY, 'DECIMALS. A machine');
  Lab(25.6, 19.4, GREY, 'with none cannot');
  Lab(25.6, 20.4, GREY, 'do this at all.');
end;

{ ==========================================================================
   THE SAME TRIANGLE, THROUGH OUR TABLE - and the answer is not the same.

   Two roundings, not one: the angle is squeezed into 256 steps, and then
   127/128 is not quite one. Both are visible on the page, and both are
   small. That is the honest price of having no decimals, and it is worth
   more to a student than pretending there is no price.
   ========================================================================== }
procedure PageTab(upto: Integer);
var i : Integer;
begin
  Head(0.9, 0.7, INK, 'the same triangle, through our table');
  Lab(0.9, 2.3, REDPEN, 'no sines, no decimals. 256 bytes, a multiply and a shift.');
  SetColor(PENCIL);
  Circle(CX(9), CY(11), CX(5));
  SetLineStyle(DottedLn, 0, NormWidth);
  Line(CX(4), CY(11), CX(14), CY(11));
  Line(CX(9), CY(6),  CX(9),  CY(16));
  SetLineStyle(SolidLn, 0, NormWidth);
  Lab(14.3, 10.7, GREY, '0');
  Lab(8.6, 5.2,  GREY, '64');
  Lab(2.9, 10.7, GREY, '128');
  Lab(8.6, 16.3, GREY, '192');
  Lab(0.9, 3.3, GREY, 'one turn = 256 steps,');
  Lab(0.9, 4.3, GREY, 'so an angle wraps in a byte');
  if upto < 2 then Exit;

  SetColor(PEN);
  Line(CX(9), CY(11), CX(13), CY(8));
  Dot(CX(13), CY(8), PEN);
  Lab(13.3, 7.4, PEN, 'a = 26');
  SetColor(GREEN);
  Line(CX(9), CY(11), CX(6), CY(7));
  Dot(CX(6), CY(7), GREEN);
  Lab(3.4, 6.2, GREEN, 'a + 64 = 90');
  SetColor(PENCIL);
  Line(CX(9.7), CY(10.4), CX(10.2), CY(11));
  Line(CX(9.7), CY(10.4), CX(9.2),  CY(9.9));
  Lab(0.9, 17.3, INK, 'a quarter turn apart - so cos a = sin ( a + 64 ),');
  Lab(0.9, 18.3, INK, 'and one table does for both.');
  if upto < 3 then Exit;

  Lab(16.6, 4, GREY, 'SINTAB - 256 bytes, 127 x sin');
  Lab(16.6, 5, GREY, '127 is the most a signed byte holds');
  for i := 0 to 5 do
  begin
    SetColor(PEN);
    Rectangle(CX(17 + i * 2.6), CY(7), CX(19 + i * 2.6), CY(8.4));
    SetColor(GREY);
    Lab(17.2 + i * 2.6, 6.2, GREY, ' ');
  end;
  Lab(17.3, 6.2, GREY, '24');   Lab(19.9, 6.2, GREY, '25');
  Lab(22.5, 6.2, REDPEN, '26'); Lab(25.1, 6.2, GREY, '27');
  Lab(27.7, 6.2, GREY, '28');   Lab(30.3, 6.2, GREY, '29');
  Lab(17.3, 7.4, INK, '71');    Lab(19.9, 7.4, INK, '73');
  Lab(22.5, 7.4, REDPEN, '76'); Lab(25.1, 7.4, INK, '78');
  Lab(27.7, 7.4, INK, '81');    Lab(30.3, 7.4, INK, '83');
  for i := 0 to 5 do
  begin
    SetColor(PEN);
    Rectangle(CX(17 + i * 2.6), CY(10), CX(19 + i * 2.6), CY(11.4));
  end;
  Lab(17.3, 9.2, GREY, '88');   Lab(19.9, 9.2, GREY, '89');
  Lab(22.4, 9.2, REDPEN, '90'); Lab(25.1, 9.2, GREY, '91');
  Lab(27.7, 9.2, GREY, '92');   Lab(30.3, 9.2, GREY, '93');
  Lab(17.2, 10.4, INK, '106');  Lab(19.8, 10.4, INK, '104');
  Lab(22.3, 10.4, REDPEN, '102'); Lab(25.0, 10.4, INK, '100');
  Lab(27.7, 10.4, INK, '98');   Lab(30.3, 10.4, INK, '96');
  SetColor(REDPEN);
  Rectangle(CX(22.2), CY(7), CX(24.2), CY(8.4));
  Rectangle(CX(22.2), CY(10), CX(24.2), CY(11.4));
  if upto < 4 then Exit;

  SetColor(PENCIL);
  Line(CX(0.9), CY(20), CX(24), CY(20));
  Lab(0.9, 20.6, INK, 'y = r * SINTAB[ a ] >> 7');
  Lab(1.9, 21.6, INK, '= 400 * 76 >> 7 = 30400 >> 7 =');
  Lab(17.4, 21.6, REDPEN, '237');
  Lab(20.6, 21.6, GREY, 'was 240');
  Lab(0.9, 23.2, INK, 'x = r * SINTAB[ a + 64 ] >> 7');
  Lab(1.9, 24.2, INK, '= 400 * 102 >> 7 = 40800 >> 7 =');
  Lab(18.0, 24.2, REDPEN, '318');
  Lab(21.2, 24.2, GREY, 'was 320');
  Lab(0.9, 25.8, INK, 'shifting seven places IS dividing by 128:');
  Lab(0.9, 26.8, INK, '128 * 237 = 30336, 64 left over - thrown away.');
  if upto < 5 then Exit;

  Lab(25.6, 20, GREY, 'TWO roundings,');
  Lab(25.6, 21, GREY, 'not one:');
  Lab(25.6, 22.4, INK, 'the angle, into');
  Lab(25.6, 23.4, INK, '256 steps -');
  Lab(25.6, 24.6, INK, 'and 127/128,');
  Lab(25.6, 25.6, INK, 'which is not 1.');
  Lab(25.6, 27, REDPEN, 'two pixels. That');
  Lab(25.6, 28, REDPEN, 'is the whole bill.');
end;

{ ==========================================================================
   WHICH WAY DOES Y GROW - the page that stops a student dead for a week.

   The pilot named this one himself: "этот аспект многих заводит в тупик".
   So it does not state a rule, it shows a BREAKAGE. And the breakage is a
   house rather than the cube, because the cube is symmetric about the
   middle of the screen and comes out looking identical when it is flipped
   - only the letters move. A roof does not have that problem.
   ========================================================================== }
procedure PageYDown(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'which way does y grow?');
  Lab(0.9, 2.3, REDPEN, 'every book says up. Every screen says down. Here is the bill.');
  Lab(0.9, 4, GREY, 'THE BOOK - y up, origin bottom left');
  SetColor(PENCIL);
  Line(CX(3), CY(17), CX(13), CY(17));  ArrowR(CX(13.5), CY(17));
  Line(CX(3), CY(17), CX(3),  CY(11));  ArrowU(CX(3), CY(11));
  Lab(1.9, 10.6, PEN, 'y');
  SetLineStyle(DottedLn, 0, NormWidth);
  Line(CX(3), CY(14.5), CX(12), CY(14.5));
  SetLineStyle(SolidLn, 0, NormWidth);
  Lab(9.4, 14.7, GREY, 'y = 100');
  SetColor(PEN);
  Line(CX(3), CY(17), CX(7), CY(17));
  Line(CX(7), CY(17), CX(7), CY(14));
  Line(CX(7), CY(14), CX(3), CY(17));
  Dot(CX(7), CY(14), REDPEN);
  Lab(7.3, 13.4, REDPEN, '( 160, 120 )');
  Lab(0.9, 18.4, PEN, '120 is ABOVE the middle.');
  if upto < 2 then Exit;

  Lab(19.4, 4, GREY, 'THE SCREEN - y DOWN, origin top left');
  SetColor(GREEN);
  Rectangle(CX(21), CY(8), CX(29), CY(13));
  Lab(19.4, 7.4, REDPEN, '0,0');
  SetColor(PEN);
  Line(CX(21), CY(8), CX(21), CY(12));  ArrowD(CX(21), CY(12.4));
  Lab(19.9, 11.4, PEN, 'y');
  SetColor(PENCIL);
  SetLineStyle(DottedLn, 0, NormWidth);
  Line(CX(21), CY(10.5), CX(29), CY(10.5));
  SetLineStyle(SolidLn, 0, NormWidth);
  Lab(29.3, 10.2, GREY, 'y = 100');
  Dot(CX(25), CY(11), REDPEN);
  Lab(25.3, 11.3, REDPEN, '( 160, 120 )');
  Lab(19.4, 14.4, REDPEN, 'the same two numbers -');
  Lab(19.4, 15.4, REDPEN, 'and now 120 is BELOW.');
  Lab(19.4, 16.8, GREY, 'neither picture is wrong.');
  Lab(19.4, 17.8, GREY, 'they simply do not mean');
  Lab(19.4, 18.8, GREY, 'the same thing.');
  if upto < 3 then Exit;

  SetColor(PENCIL);
  Line(CX(0.9), CY(20), CX(35), CY(20));
  Lab(0.9, 20.6, GREY, 'so draw a house - walls y = 20..100, apex y = 150, measured the book way');
  SetColor(GREEN);
  Rectangle(CX(4), CY(22), CX(12), CY(27));
  SetColor(PEN);
  Line(CX(6.5), CY(24.5), CX(9.5), CY(24.5));
  Line(CX(9.5), CY(24.5), CX(9.5), CY(26.5));
  Line(CX(9.5), CY(26.5), CX(6.5), CY(26.5));
  Line(CX(6.5), CY(26.5), CX(6.5), CY(24.5));
  Line(CX(6.5), CY(24.5), CX(8),   CY(23.25));
  Line(CX(8),   CY(23.25), CX(9.5), CY(24.5));
  Lab(1.4, 27.6, PEN, 'sy = 200 - y.  A house.');
  if upto < 4 then Exit;

  SetColor(GREEN);
  Rectangle(CX(20), CY(22), CX(28), CY(27));
  SetColor(REDPEN);
  Line(CX(22.5), CY(22.5), CX(25.5), CY(22.5));
  Line(CX(25.5), CY(22.5), CX(25.5), CY(24.5));
  Line(CX(25.5), CY(24.5), CX(22.5), CY(24.5));
  Line(CX(22.5), CY(24.5), CX(22.5), CY(22.5));
  Line(CX(22.5), CY(24.5), CX(24),   CY(25.75));
  Line(CX(24),   CY(25.75), CX(25.5), CY(24.5));
  Lab(19.4, 27.6, REDPEN, 'sy = y.  The roof is underneath.');
  SetColor(PENCIL);
  Line(CX(13), CY(24.5), CX(19), CY(24.5));  ArrowR(CX(19.5), CY(24.5));
  Lab(14.2, 23.6, GREY, 'same numbers');
  if upto < 5 then Exit;

  SetColor(REDPEN);
  SetLineStyle(SolidLn, 0, ThickWidth);
  Line(CX(0.9), CY(28.6), CX(35), CY(28.6));
  SetLineStyle(SolidLn, 0, NormWidth);
  Lab(0.9, 28.9, REDPEN, 'so we stop fighting it: y downward from here, and the formula gets a PLUS.');
end;
