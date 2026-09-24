{ ==========================================================================
   PAGE 5 - RULE THREE, and the point of the whole lesson.

   The bank is a staircase: 3 a frame to 30, so ten frames up and ten back.
   Drawn on the paper at 1 cell = 3 of roll and 1 cell = 1 frame, so the
   steps ARE the squares and can be counted.

   And then the thing that is worth the lesson: the engine has been banking
   the picture since lesson 13. roll was nought, so nobody saw it.
   ========================================================================== }
procedure PageBank(upto: Integer);
var i : Integer;
begin
  Head(0.9, 0.7, INK, 'rule three: the bank');
  Lab(0.9, 2.3, REDPEN, '1 cell across = one frame. 1 cell up = 3 of roll. Count the steps.');
  Axis(CX(2), CY(16), CX(30), CY(16), PENCIL, False);
  SetColor(PENCIL); ArrowR(CX(30.5), CY(16));
  Lab(30.6, 15.6, PENCIL, 'frames');
  Axis(CX(2), CY(16), CX(2), CY(5), PENCIL, False);
  SetColor(PENCIL); ArrowU(CX(2), CY(4.5));
  Lab(0.9, 4.2, PENCIL, 'roll');
  Lab(0.9, 5.7, GREY, '30');
  Axis(CX(2), CY(6), CX(30), CY(6), PENCIL, True);
  Lab(0.9, 15.7, GREY, '0');
  if upto < 2 then Exit;

  SetColor(PEN);
  for i := 0 to 9 do
  begin
    Thick(CX(2 + i), CY(16 - i), CX(3 + i), CY(16 - i), PEN);
    Thick(CX(3 + i), CY(16 - i), CX(3 + i), CY(15 - i), PEN);
  end;
  Thick(CX(12), CY(6), CX(18), CY(6), PEN);
  Lab(8.4, 12.4, PEN, 'LEFT held: +3 a frame');
  Lab(12.4, 5.2, PEN, 'pinned at BANKMAX = 30');
  if upto < 3 then Exit;

  SetColor(REDPEN);
  for i := 0 to 9 do
  begin
    Thick(CX(18 + i), CY(6 + i), CX(19 + i), CY(6 + i), REDPEN);
    Thick(CX(19 + i), CY(6 + i), CX(19 + i), CY(7 + i), REDPEN);
  end;
  Lab(8.4, 13.6, REDPEN, 'let go: -3, back to level');
  Lab(8.4, 14.6, GREY, 'and it STOPS there - two');
  Lab(8.4, 15.4, GREY, 'compares catch the overshoot.');
  if upto < 4 then Exit;

  SetColor(PENCIL);
  Line(CX(0.9), CY(17.6), CX(35), CY(17.6));
  Lab(0.9, 18.2, INK, 'Ten frames up, ten frames back. At 69 frames a second that is a');
  Lab(0.9, 19.2, INK, 'seventh of a second each way - and 30 of 256 is');
  Lab(24.9, 19.2, REDPEN, '42 degrees');
  Ring(24.7, 19.2, 5.4);
  Lab(0.9, 20.6, GREY, 'which is a LOT of bank. It is the game''s own number.');
  if upto < 5 then Exit;

  SetColor(GREEN);
  Rectangle(CX(0.9), CY(22.4), CX(35), CY(28.6));
  Lab(1.6, 23, GREEN, 'AND THE BANK COST NOTHING.');
  Lab(1.6, 24.2, INK, 'PROJPT has called APPLYROLL on every projected point since');
  Lab(1.6, 25.2, INK, 'lesson 13. SETTRIG has been filling rsin and rcos from roll');
  Lab(1.6, 26.2, INK, 'every time it ran. roll was nought, so it rotated by nothing');
  Lab(1.6, 27.2, INK, 'and nobody saw it.');
  Lab(1.6, 28, GREEN, 'The physics did not add a rotation. It switched one on.');
end;

{ ==========================================================================
   PAGE 6 - a key is not an event.

   Why INT 16h cannot answer the question a flight model asks. Drawn as the
   buffer it really is: a queue of things that ALREADY happened.
   ========================================================================== }
procedure PageKey(upto: Integer);
var i : Integer;
begin
  Head(0.9, 0.7, INK, 'a key is not an event');
  Lab(0.9, 2.3, REDPEN, 'the question changed, so the machinery has to change with it.');
  Lab(0.9, 4.2, GREY, 'WHAT WE HAVE ASKED SINCE LESSON 3 - the BIOS keyboard buffer');
  SetColor(PEN);
  for i := 0 to 5 do
    Rectangle(CX(3 + i * 2.6), CY(6), CX(5 + i * 2.6), CY(7.4));
  Lab(3.6, 6.3, PEN, 'L');  Lab(6.2, 6.3, PEN, 'L');  Lab(8.8, 6.3, PEN, 'U');
  Lab(11.4, 6.3, GREY, '.'); Lab(14, 6.3, GREY, '.'); Lab(16.6, 6.3, GREY, '.');
  SetColor(PENCIL);
  Line(CX(2.6), CY(8.4), CX(3.6), CY(7.6));
  Lab(1.4, 8.6, INK, 'you take them one at a time, oldest first');
  Lab(0.9, 10, INK, 'It can tell you a key WAS PRESSED. It cannot tell you a key is');
  Lab(0.9, 11, INK, 'STILL DOWN, and it cannot tell you that two are down at once.');
  Lab(0.9, 12.4, REDPEN, 'A flight model needs both of those, every single frame.');
  if upto < 2 then Exit;

  Lab(0.9, 14.4, GREY, 'WHAT WE ASK FROM HERE - our own table, one byte a key');
  SetColor(GREEN);
  for i := 0 to 5 do
    Rectangle(CX(3 + i * 3.4), CY(16.2), CX(5.4 + i * 3.4), CY(17.6));
  Lab(3.3, 15.4, GREY, '75');   Lab(6.7, 15.4, GREY, '77');
  Lab(10.1, 15.4, GREY, '72');  Lab(13.5, 15.4, GREY, '80');
  Lab(16.9, 15.4, GREY, '33');  Lab(20.3, 15.4, GREY, '1');
  Lab(3.9, 16.5, GREEN, '1');   Lab(7.3, 16.5, GREY, '0');
  Lab(10.7, 16.5, GREEN, '1');  Lab(14.1, 16.5, GREY, '0');
  Lab(17.5, 16.5, GREY, '0');   Lab(20.9, 16.5, GREY, '0');
  Lab(3, 18, INK, 'LEFT and PgUp are held, this instant. Both. No queue, no order,');
  Lab(3, 19, INK, 'nothing waiting to be taken out.');
  if upto < 3 then Exit;

  SetColor(PENCIL);
  Line(CX(0.9), CY(20.6), CX(35), CY(20.6));
  Lab(0.9, 21.2, INK, 'To keep that table we take INT 9 - the interrupt the keyboard');
  Lab(0.9, 22.2, INK, 'hardware raises itself, on every press AND on every release.');
  Lab(0.9, 23.6, REDPEN, 'And there is a price, paid in full on the next page but one:');
  Lab(0.9, 24.8, INK, 'our handler does not pass the key on, so the BIOS never learns');
  Lab(0.9, 25.8, INK, 'a key happened. INT 16h is empty for as long as we run - which');
  Lab(0.9, 26.8, INK, 'is why even the "press SPACE" on the map screen had to change.');
end;

{ ==========================================================================
   PAGE 7 - THE SCAN CODE, WORKED. One byte, and bit 7 is the whole story.
   ========================================================================== }
procedure PageScan(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'the scan code: one byte, one bit');
  Lab(0.9, 2.3, REDPEN, 'not ASCII. This is what the keyboard hardware itself sends.');
  Lab(0.9, 4.2, INK, 'Press the LEFT arrow. Port 60h has:');
  ByteBox(3, 5.6, '01001011', PEN);
  Lab(15.4, 5.9, PEN, '= 4B = 75');
  if upto < 2 then Exit;

  Lab(0.9, 8, INK, 'Let it go. The SAME key arrives again, like this:');
  ByteBox(3, 9.4, '11001011', PEN);
  Lab(15.4, 9.7, PEN, '= CB = 203');
  SetColor(REDPEN);
  Rectangle(CX(2.9), CY(9.3), CX(4.3), CY(10.7));
  Lab(2.6, 11, REDPEN, 'bit 7');
  Lab(0.9, 12.4, INK, 'One bit apart. 75 and 203 differ by 128, and nothing else about');
  Lab(0.9, 13.4, INK, 'them is different at all.');
  if upto < 3 then Exit;

  SetColor(PENCIL);
  Line(CX(0.9), CY(15), CX(35), CY(15));
  Lab(0.9, 15.6, INK, 'So the handler is two instructions and a store:');
  Lab(0.9, 17, PEN,  'and  al,7Fh        ; strip bit 7  -> 75, either way');
  Lab(0.9, 18, PEN,  'test ah,80h        ; read bit 7   -> which one was it');
  Lab(0.9, 19, PEN,  'KEYS[75] = 1 or 0');
  Lab(0.9, 20.4, INK, 'AND 7F keeps the key. TEST 80 keeps the news. The same byte');
  Lab(0.9, 21.4, INK, 'answers both questions, which is why one is enough.');
  if upto < 4 then Exit;

  SetColor(GREEN);
  Rectangle(CX(0.9), CY(23), CX(35), CY(28.4));
  Lab(1.6, 23.6, GREEN, 'AND THEN TELL THE CONTROLLER YOU ARE FINISHED:');
  Lab(1.6, 24.8, PEN, 'mov al,20h');
  Lab(1.6, 25.8, PEN, 'out 20h,al');
  Lab(14, 24.8, INK, 'Leave this out and NOTHING');
  Lab(14, 25.8, INK, 'ever interrupts again - not');
  Lab(14, 26.8, INK, 'the keyboard, not the clock.');
  Lab(1.6, 27.4, GREY, 'The machine does not hang. It just goes deaf, which is worse.');
end;

{ ==========================================================================
   PAGE 8 - how fast is this machine, really. All four numbers measured.
   ========================================================================== }
procedure PageSpeed(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'how fast is this machine, really');
  Lab(0.9, 2.3, REDPEN, 'DOSBox''s own words: "cycles: instructions emulated each millisecond"');
  Lab(0.9, 4.2, INK, 'So a cycles number is not megahertz. It is instructions a');
  Lab(0.9, 5.2, INK, 'millisecond, and you can turn it into a machine:');
  Lab(0.9, 6.6, PEN, '2500 cycles = 2 500 000 instructions a second');
  Lab(0.9, 7.8, GREY, 'A 4.77 MHz 8086 spends well over ten clocks on a typical');
  Lab(0.9, 8.8, GREY, 'instruction, so it manages some 300 to 500 thousand.');
  Lab(0.9, 10, INK, 'A real 8086 is therefore about');
  Lab(22.6, 10, REDPEN, '300 cycles');
  Ring(22.4, 10, 5.4);
  Lab(0.9, 11.2, GREY, 'and 2500 is five to ten times faster than one.');
  if upto < 2 then Exit;

  SetColor(PEN);
  Rectangle(CX(0.9), CY(13), CX(24), CY(19.4));
  Line(CX(0.9), CY(14.4), CX(24), CY(14.4));
  Line(CX(8), CY(13), CX(8), CY(19.4));
  Line(CX(16), CY(13), CX(16), CY(19.4));
  Lab(1.4, 13.4, INK, 'cycles');   Lab(9.4, 13.4, INK, 'FAST');  Lab(17.4, 13.4, INK, 'CLASSIC');
  Lab(1.4, 14.9, INK, '30000');    Lab(9.4, 14.9, PEN, '69');    Lab(17.4, 14.9, PEN, '35');
  Lab(1.4, 16.4, INK, '2500');     Lab(9.4, 16.4, PEN, '7');     Lab(17.4, 16.4, PEN, '5');
  Lab(1.4, 17.9, INK, '300');      Lab(9.4, 17.9, PEN, '1');     Lab(17.4, 17.9, PEN, '1');
  Lab(24.6, 13.4, GREY, 'measured, on');
  Lab(24.6, 14.4, GREY, 'this program,');
  Lab(24.6, 15.4, GREY, 'flying level.');
  if upto < 3 then Exit;

  Lab(0.9, 20.4, INK, 'Read the three rows. At 30000 the two engines are 69 and 35 -');
  Lab(0.9, 21.4, INK, 'and those are lesson 13''s staircase, not a measurement: both');
  Lab(0.9, 22.4, INK, 'frames are waiting for the beam, one retrace and two.');
  Lab(0.9, 23.8, REDPEN, 'At 2500 the wait stops mattering and the gap is honest: 7 to 5.');
  if upto < 4 then Exit;

  Lab(0.9, 25.4, INK, 'At 300 - the machine this was all written for - both say ONE, and');
  Lab(0.9, 26.4, INK, 'the counter has given up: two digits cannot separate 1.1 from 1.7.');
  Lab(0.9, 27.8, GREY, 'To show an 8086 honestly you stop counting frames a second and');
  Lab(0.9, 28.8, GREY, 'start timing ONE frame. That is the next thing this program needs.');
end;

{ ==========================================================================
   PAGE 9 - the closing card.
   ========================================================================== }
procedure PageFinal(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'four rules, and a table of 128 bytes');
  Lab(0.9, 2.3, REDPEN, 'that is the whole of it. Nothing was modelled. Something was left out.');
  Lab(0.9, 4.2, INK, 'It always moves forward - 48 times 181 over 256, which is 33.');
  Lab(0.9, 5.2, INK, 'The arrows turn it - and a byte is a circle, so nothing is tested.');
  Lab(0.9, 6.2, INK, 'The turn banks it - and the engine was already banking, for free.');
  Lab(0.9, 7.2, INK, 'PgUp and PgDn climb - between a floor and a ceiling.');
  Lab(0.9, 8.6, INK, 'And under all four, our own INT 9, because a flight model has to');
  Lab(0.9, 9.6, INK, 'ask whether a key is HELD and the BIOS cannot answer that.');
  if upto < 2 then Exit;

  SetColor(PEN);
  Rectangle(CX(0.9), CY(11.6), CX(35), CY(18));
  Lab(1.6, 12.2, REDPEN, 'NEXT:');
  Lab(1.6, 13.6, INK, '15  houses out of cubes on this lattice - the painter''s');
  Lab(1.6, 14.6, INK, '    algorithm, and a FACE cut by the near plane: 3, 4 or 5');
  Lab(1.6, 15.6, INK, '    corners come out of it.');
  Lab(1.6, 17, GREY, '    And a sky that banks with the world, which is a filled');
  Lab(1.6, 17.9, GREY, '    polygon and is why there is no horizon on the screen today.');
  Lab(0.9, 20, GREEN, 'The source now travels from lesson to lesson. This one started as');
  Lab(0.9, 21, GREEN, 'a copy of lesson 13 and grew two routines. That is the shape from');
  Lab(0.9, 22, GREEN, 'here on: one program, growing.');
  Lab(0.9, 24, GREY, 'Now the source. Read the four rules in it and count them.');
end;
