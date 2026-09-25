{ ==========================================================================
   PAGE 1 - an aeroplane does not wait for you.

   The whole lesson in one comparison, drawn as two timelines. Up to here
   every lesson moved the camera one pace per keypress. That is a slide
   show with arrows on it. A flight model runs the other way round.
   ========================================================================== }
procedure PageWait(upto: Integer);
var i : Integer;
begin
  Head(0.9, 0.7, INK, 'an aeroplane does not wait for you');
  Lab(0.9, 2.3, REDPEN, 'the notebook again. Every number on these pages is the program''s own.');
  if upto < 2 then Exit;

  Lab(0.9, 4.2, GREY, 'UP TO HERE - lesson 13 and every lesson before it');
  Axis(CX(1), CY(7), CX(34), CY(7), PENCIL, False);
  SetColor(PENCIL); ArrowR(CX(34.5), CY(7));
  Lab(34.6, 6.6, PENCIL, 't');
  for i := 0 to 3 do
  begin
    SetColor(PEN);
    Line(CX(3 + i * 8), CY(5.6), CX(3 + i * 8), CY(7));
    Lab(2.4, 4.9, PEN, 'key');
    Lab(10.4, 4.9, PEN, 'key');
    Lab(18.4, 4.9, PEN, 'key');
    Lab(26.4, 4.9, PEN, 'key');
    Thick(CX(3 + i * 8), CY(7), CX(4 + i * 8), CY(7), REDPEN);
    Lab(4.3, 7.3, REDPEN, 'one frame');
    Lab(12.3, 7.3, REDPEN, 'one frame');
    Lab(20.3, 7.3, REDPEN, 'one frame');
    Lab(28.3, 7.3, REDPEN, 'one frame');
  end;
  Lab(0.9, 9, INK, 'nothing happens between the presses. The machine is asleep.');
  if upto < 3 then Exit;

  Lab(0.9, 11.6, GREY, 'FROM HERE - and the keys only lean on it');
  Axis(CX(1), CY(14.4), CX(34), CY(14.4), PENCIL, False);
  SetColor(PENCIL); ArrowR(CX(34.5), CY(14.4));
  Lab(34.6, 14, PENCIL, 't');
  for i := 0 to 32 do
    Thick(CX(1 + i), CY(14.4), CX(1.7 + i), CY(14.4), REDPEN);
  SetColor(PEN);
  Line(CX(9), CY(13), CX(9), CY(14.4));
  Line(CX(17), CY(13), CX(17), CY(14.4));
  Lab(8.4, 12.3, PEN, 'LEFT held');
  Lab(16.4, 12.3, PEN, 'let go');
  Lab(0.9, 15.4, INK, 'frame, frame, frame, whatever you do. The world advances on its');
  Lab(0.9, 16.4, INK, 'own and the keys only change WHERE it is going.');

  SetColor(PENCIL);
  Line(CX(0.9), CY(18.4), CX(35), CY(18.4));
  Lab(0.9, 19, REDPEN, 'Two things follow, and both of them are this lesson:');
  Lab(0.9, 20.4, INK, '1. There has to be a MODEL - some rules that move the world when');
  Lab(0.9, 21.4, INK, '   nobody is touching anything. Four of them, and they fit on');
  Lab(0.9, 22.4, INK, '   the next page.');
  Lab(0.9, 23.8, INK, '2. The program has to know a key is being HELD, not that it was');
  Lab(0.9, 24.8, INK, '   pressed. Those are different questions, and the one we have');
  Lab(0.9, 25.8, INK, '   been asking since lesson 3 cannot answer the first.');
  Lab(0.9, 27.4, GREY, 'Pencil out. The whole model is four rules and none of them is hard.');
end;

{ ==========================================================================
   PAGE 2 - the four rules, out of INPUT in CITY.ASM line 1873.

   Deliberately the whole model on one page, before any of it is worked
   out. A reader who sees the size of the thing first is not afraid of it.
   ========================================================================== }
procedure PageRules(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'the whole flight model');
  Lab(0.9, 2.3, REDPEN, 'GAMES\WIRECITY\CITY.ASM, line 1873. There is no fifth rule.');

  SetColor(PEN);
  Rectangle(CX(0.9), CY(4), CX(35), CY(19.4));
  Lab(1.6, 4.8, REDPEN, '1');
  Lab(3.4, 4.8, INK, 'IT ALWAYS MOVES FORWARD');
  Lab(3.4, 5.9, PEN, 'camx += SPEEDV * hsin / 256');
  Lab(3.4, 6.9, PEN, 'camz += SPEEDV * hcos / 256');
  Lab(3.4, 8, GREY, 'every frame. No throttle, no brake, no speed variable.');

  Lab(1.6, 9.6, REDPEN, '2');
  Lab(3.4, 9.6, INK, 'LEFT AND RIGHT TURN IT');
  Lab(3.4, 10.7, PEN, 'heading = (heading -+ TURNV) AND 255');
  Lab(3.4, 11.8, GREY, 'a byte is a whole circle, so it cannot go out of range.');

  Lab(1.6, 13.4, REDPEN, '3');
  Lab(3.4, 13.4, INK, 'THE TURN BANKS IT');
  Lab(3.4, 14.5, PEN, 'roll walks to -+BANKMAX, and back to 0');
  Lab(3.4, 15.6, GREY, 'four compares and two adds. This is the whole feel.');

  Lab(1.6, 17.2, REDPEN, '4');
  Lab(3.4, 17.2, INK, 'THE UP AND DOWN ARROWS CLIMB');
  Lab(3.4, 18.3, PEN, 'camy -+ STEPY, between a floor and a ceiling');
  if upto < 2 then Exit;

  Lab(0.9, 21, INK, 'Now read what is NOT in it. No mass. No lift. No drag. No');
  Lab(0.9, 22, INK, 'acceleration. Nothing that a physics book would call physics.');
  Lab(0.9, 23.4, INK, 'The aeroplane is a POINT that travels at a fixed rate along the');
  Lab(0.9, 24.4, INK, 'way it is pointing, and the bank is a number chasing another');
  Lab(0.9, 25.4, INK, 'number. In the air it is completely convincing.');
  Lab(0.9, 27, REDPEN, 'That is worth knowing before you write your own: the convincing');
  Lab(0.9, 28, REDPEN, 'part was never the arithmetic. It was choosing what to leave out.');
end;

{ ==========================================================================
   PAGE 3 - RULE ONE, WORKED. 1 cell = 11 world units, so the answer, 33,
   lands three cells out on both axes and can be counted.

   heading 32 of 256 is 45 degrees. SINT[32] = 181, not 256, and that is
   the whole of the fixed point: the table is sin times 256, and the 256
   is taken off again by the shift.
   ========================================================================== }
procedure PageFwd(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'rule one: it always moves forward');
  Lab(0.9, 2.3, REDPEN, '1 cell = 11 world units. PLAN, from above: x east, z north.');
  Axis(CX(4), CY(18), CX(19), CY(18), PENCIL, False);
  SetColor(PENCIL); ArrowR(CX(19.5), CY(18));
  Lab(19.7, 17.6, PENCIL, 'x  east');
  Axis(CX(4), CY(18), CX(4), CY(5), PENCIL, False);
  SetColor(PENCIL); ArrowU(CX(4), CY(4.5));
  Lab(2.9, 4.2, PENCIL, 'z  north');
  Dot(CX(4), CY(18), PEN);
  Lab(1.4, 18.3, INK, 'the eye');
  if upto < 2 then Exit;

  Thick(CX(4), CY(18), CX(11), CY(11), PEN);
  SetColor(PEN); ArrowR(CX(11.3), CY(10.7));
  Lab(11.4, 10.2, PEN, 'heading 32');
  Lab(11.4, 11.2, GREY, '32 of 256 = 45 deg');
  SetColor(PENCIL);
  Arc(CX(4), CY(18), 0, 45, CX(3));
  Lab(7.4, 16.4, PENCIL, '45');
  if upto < 3 then Exit;

  Lab(21, 4.2, INK, 'the table, from lesson 11:');
  Lab(21, 5.4, PEN, 'SINT[32] = 181');
  Lab(21, 6.6, GREY, 'not 256. The table is the');
  Lab(21, 7.6, GREY, 'sine TIMES 256, so 181 is');
  Lab(21, 8.6, GREY, '181/256 = 0.707. And the');
  Lab(21, 9.6, GREY, 'cosine is the same table,');
  Lab(21, 10.6, GREY, '64 steps along: also 181.');
  if upto < 4 then Exit;

  Lab(21, 12.4, INK, 'wdx = 48 * 181 / 256');
  Lab(21, 13.4, INK, '    = 8688 / 256');
  Lab(21, 14.4, INK, '    =');
  Lab(24.2, 14.4, REDPEN, '33');
  Ring(24, 14.4, 1.4);
  Lab(21, 15.8, INK, 'wdz: the same sum,');
  Lab(21, 16.8, INK, 'also 33.');
  SetColor(PENCIL);
  SetLineStyle(DottedLn, 0, NormWidth);
  Line(CX(7), CY(18), CX(7), CY(15));
  Line(CX(4), CY(15), CX(7), CY(15));
  SetLineStyle(SolidLn, 0, NormWidth);
  Dot(CX(7), CY(15), REDPEN);
  Lab(7.3, 14.2, REDPEN, '( 33, 33 )');
  Lab(5.6, 18.4, GREY, '33 = 3 cells');
  Lab(1.2, 15.2, GREY, '33');
  if upto < 5 then Exit;

  SetColor(PENCIL);
  Line(CX(0.9), CY(20.4), CX(35), CY(20.4));
  Lab(0.9, 21, INK, 'AND NOW MEASURE WHAT YOU DREW. The step should be 48 long. You');
  Lab(0.9, 22, INK, 'have 33 across and 33 up, so it is really');
  Lab(22, 22, REDPEN, '46.7');
  Ring(21.8, 22, 2.4);
  Lab(0.9, 23.4, INK, 'Two truncations did that: 8688/256 is 33.94 and the divide throws');
  Lab(0.9, 24.4, INK, 'the .94 away, twice. The aeroplane is three per cent slow on the');
  Lab(0.9, 25.4, INK, 'diagonal and exactly right due north. Nobody has ever noticed.');
  Lab(0.9, 26.8, GREY, 'That is the honest price of having no fractions - lesson 12 paid it');
  Lab(0.9, 27.8, GREY, 'in two pixels, and this is the same coin.');
end;

{ ==========================================================================
   PAGE 4 - rules two and four: the cheap ones.

   The byte-as-a-circle is the payoff of lesson 11's table, and it is worth
   drawing the wrap because it is the reason there is no range check.
   ========================================================================== }
procedure PageByte(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'rules two and four: the cheap ones');
  Lab(0.9, 2.3, REDPEN, 'a byte IS a circle, and a floor IS a comparison.');
  SetColor(PENCIL);
  Circle(CX(8), CY(11), CX(5));
  SetLineStyle(DottedLn, 0, NormWidth);
  Line(CX(3), CY(11), CX(13), CY(11));
  Line(CX(8), CY(6), CX(8), CY(16));
  SetLineStyle(SolidLn, 0, NormWidth);
  Lab(13.3, 10.7, GREY, '0');
  Lab(7.6, 5.2, GREY, '64');
  Lab(1.7, 10.7, GREY, '128');
  Lab(7.6, 16.3, GREY, '192');
  Lab(0.9, 4, INK, 'one turn = 256 steps');
  if upto < 2 then Exit;

  SetColor(PEN);
  Thick(CX(8), CY(11), CX(12.7), CY(10.2), PEN);
  Dot(CX(12.7), CY(10.2), PEN);
  Lab(12.9, 9.4, PEN, '254');
  SetColor(REDPEN);
  Thick(CX(8), CY(11), CX(13), CY(11), REDPEN);
  Lab(15.4, 4.2, INK, 'turning right by TURNV = 2:');
  Lab(15.4, 5.4, PEN, '254 + 2 = 256');
  Lab(15.4, 6.6, PEN, '256 AND 255 =');
  Lab(24.6, 6.6, REDPEN, '0');
  Ring(24.4, 6.6, 1);
  Lab(15.4, 8, GREY, 'round the back of the circle,');
  Lab(15.4, 9, GREY, 'and no test anywhere. An AND');
  Lab(15.4, 10, GREY, 'costs 3 clocks. A compare and');
  Lab(15.4, 11, GREY, 'a branch would cost more, and');
  Lab(15.4, 12, GREY, 'could be got wrong.');
  if upto < 3 then Exit;

  SetColor(PENCIL);
  Line(CX(0.9), CY(18), CX(35), CY(18));
  Lab(0.9, 18.6, INK, 'RULE FOUR, and it is a floor and a ceiling:');
  Lab(0.9, 20, PEN, 'if (KEYS[UP])   camy += 20;');
  Lab(0.9, 21, PEN, 'if (KEYS[DOWN]) camy -= 20;');
  Lab(0.9, 22, PEN, 'if (camy < 96)   camy = 96;');
  Lab(0.9, 23, PEN, 'if (camy > 1680) camy = 1680;');
  if upto < 4 then Exit;

  Lab(18, 19.4, INK, 'The floor is not a crash. There');
  Lab(18, 20.4, INK, 'is no crash in this lesson - the');
  Lab(18, 21.4, INK, 'ground is a surface you cannot');
  Lab(18, 22.4, INK, 'go through, and that is all.');
  Lab(0.9, 25, GREY, 'The game''s numbers are 5 and 24..420, on a 256-unit cell. Ours are');
  Lab(0.9, 26, GREY, 'four times those, because this lattice is built on a 1024-unit');
  Lab(0.9, 27, GREY, 'node. The two that measure an ANGLE were not touched: a circle is');
  Lab(0.9, 28, GREY, '256 steps here and 256 steps there.');
end;
