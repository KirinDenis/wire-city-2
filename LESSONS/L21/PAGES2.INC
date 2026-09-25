{ ==========================================================================
   PAGE 6 - the order: nearest first.

   A wireframe does not care what order its lines go down in. Hiding does.
   The order never changes, because the eye is always in the middle of the
   block, so it is worked out once at the boot into TORD.

   Sorted by the SQUARE of the distance, because comparing squares puts
   things in the same order as comparing distances and costs no square
   root. 3 and 4 give 9 + 16 = 25, and 5 squared is 25.
   ========================================================================== }
procedure PageOrd(upto: Integer);
var
  i, j : Integer;
begin
  Head(0.9, 0.7, INK, 'the order: nearest first');
  Lab(0.9, 2.3, REDPEN, 'FROM ABOVE. The eye is always in the middle of the block.');
  for i := 0 to 6 do
    for j := 0 to 6 do
      Box(2 + i * 2, 4.6 + j * 2, 4 + i * 2, 6.6 + j * 2, PENCIL);
  Dot(CX(9), CY(11.6), REDPEN);
  Lab(5.2, 11.3, REDPEN, 'eye');
  Lab(10.8, 11.3, INK, '1');
  Lab(12.8, 11.3, INK, '4');
  Lab(14.8, 11.3, INK, '9');
  Lab(8.8, 9.3, INK, '1');
  Lab(8.8, 7.3, INK, '4');
  Lab(8.8, 5.3, INK, '9');
  Lab(10.8, 9.3, INK, '2');
  Lab(12.8, 7.3, INK, '8');
  Lab(17, 9.4, GREY, 'the number in each square is');
  Lab(17, 10.4, GREY, 'how far it is from the eye,');
  Lab(17, 11.4, GREY, 'SQUARED. Draw them in that');
  Lab(17, 12.4, GREY, 'order and everything nearer');
  Lab(17, 13.4, GREY, 'is already on the screen.');
  if upto < 2 then Exit;

  Lab(0.9, 19.4, GREY, 'WHY SQUARED, and this is the whole trick:');
  Lab(1.8, 20.8, PEN, 'd = (ta - 12) * (ta - 12) + (tb - 12) * (tb - 12)');
  Lab(1.8, 22.2, INK, '3 across and 4 up: 9 + 16 = 25. And the real distance is 5,');
  Lab(1.8, 23.2, INK, 'and 5 squared is 25. A square root would tell you nothing');
  Lab(1.8, 24.2, INK, 'you did not already know, and it would cost a fortune.');
  if upto < 3 then Exit;

  Lab(0.9, 26.2, REDPEN, 'Built ONCE at the boot, into TORD. And the game has this same');
  Lab(0.9, 27.2, REDPEN, 'table - read the other way round, far to near, because a');
  Lab(0.9, 28.2, REDPEN, 'painter works back to front. That is the next lesson.');
end;

{ ==========================================================================
   PAGE 7 - the floating horizon, walked by hand.

   One byte a column. Everything below is bookkeeping. Column 160 takes
   138, refuses 151, takes 122 and refuses 130, and the four numbers are
   on the page where they can be counted.

   Remember y grows DOWNWARD. "Above" is a SMALLER number, which is the
   one thing about this array that catches people.
   ========================================================================== }
procedure PageHor(upto: Integer);
var
  i : Integer;
begin
  Head(0.9, 0.7, INK, 'the floating horizon');
  Lab(0.9, 2.3, REDPEN, 'One byte for every column of the screen. Three hundred and');
  Lab(0.9, 3.3, REDPEN, 'twenty of them, and that is the whole algorithm.');
  Box(1.8, 5, 17.8, 11, PENCIL);
  for i := 0 to 7 do
    Axis(CX(1.8 + i * 2), CY(5), CX(1.8 + i * 2), CY(11), RULE, True);
  Lab(2, 11.4, INK, '200 200 200 200 200 200 200 200');
  Lab(1.8, 12.8, GREY, 'all 200 to start: the bottom row. Nothing drawn yet, so');
  Lab(1.8, 13.6, GREY, 'anything at all is above it and anything at all shows.');
  if upto < 2 then Exit;

  Lab(20, 5, GREY, 'THE RULE:');
  Lab(20, 6.4, PEN, 'if (y < HOR[x]) {');
  Lab(20, 7.4, PEN, '    plot;');
  Lab(20, 8.4, PEN, '    HOR[x] = y;');
  Lab(20, 9.4, PEN, '}');
  Lab(20, 11, REDPEN, 'y grows DOWNWARD.');
  Lab(20, 12, REDPEN, 'Above is SMALLER.');
  if upto < 3 then Exit;

  Lab(0.9, 15.4, GREY, 'ONE COLUMN, x = 160. Rows 110 to 160 only, so you can see them.');
  Axis(CX(3), CY(17), CX(3), CY(27), PENCIL, False);
  Lab(1.4, 16.4, PENCIL, '110');
  Lab(1.4, 27.2, PENCIL, '160');
  Lab(4.2, 27.2, GREY, 'and HOR[160] starts at 200, off the bottom of this strip');
  Thick(CX(2.4), CY(22.6), CX(3.6), CY(22.6), PEN);
  Lab(4.2, 22.3, INK, 'y = 138   138 < 200, so DRAW.   HOR[160] = 138');
  if upto < 4 then Exit;

  Dashed(CX(2.4), CY(25.2), CX(3.6), CY(25.2), GREY);
  Lab(4.2, 24.9, GREY, 'y = 151   151 is not < 138. HIDDEN, and nothing written.');
  Thick(CX(2.4), CY(19.4), CX(3.6), CY(19.4), PEN);
  Lab(4.2, 19.1, INK, 'y = 122   122 < 138, so DRAW.   HOR[160] = 122');
  Ring(26.2, 19.1, 2);
  if upto < 5 then Exit;

  Dashed(CX(2.4), CY(21), CX(3.6), CY(21), GREY);
  Lab(4.2, 20.7, GREY, 'y = 130   130 is not < 122. HIDDEN.');
  Lab(0.9, 28.4, REDPEN, 'The skyline in that column ends at 122. One compare a pixel.');
end;

{ ==========================================================================
   PAGE 8 - what it costs, and the surprise.

   Measured on this program with the retrace wait taken off and the
   aeroplane parked, so all three draw the same picture. The obvious
   reading of the table is the wrong one.
   ========================================================================== }
procedure PageCost(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'what it costs');
  Lab(0.9, 2.3, REDPEN, 'Measured. Retrace wait off, aeroplane parked, same picture.');
  Box(0.9, 3.8, 35, 9.4, PEN);
  Lab(1.8, 4.6, INK, 'see through, lesson 8''s patched line        76 frames');
  Lab(1.8, 6.0, INK, 'HIDDEN, the skyline                         60');
  Lab(1.8, 7.4, INK, 'see through, the classic line   (F)         53');
  if upto < 2 then Exit;

  Lab(0.9, 11, GREY, 'NOW READ THE LAST TWO ROWS AGAIN.');
  Lab(1.8, 12.4, REDPEN, '60 against 53. The hiding is FASTER.');
  Ring(1.8, 12.4, 18);
  Lab(1.8, 14, INK, 'A pixel it throws out is a pixel it never writes. The skyline');
  Lab(1.8, 15, INK, 'does not cost anything at all. It saves.');
  if upto < 3 then Exit;

  Lab(0.9, 17, GREY, 'SO WHERE DID THE 16 FRAMES GO?');
  Lab(1.8, 18.4, INK, 'The moment we wrote our OWN line we left lesson 8''s behind -');
  Lab(1.8, 19.4, INK, 'the one that writes its step sizes into its own instructions.');
  Lab(1.8, 20.8, REDPEN, 'The price of hiding was paid in lesson 8''s coin.');
  if upto < 4 then Exit;

  Lab(0.9, 23, GREY, 'AND THE COUNTER WILL NOT SAY 60. It says 35:');
  Thick(CX(2), CY(25.2), CX(14), CY(25.2), PEN);
  Lab(14.4, 24.9, INK, '70');
  Thick(CX(2), CY(26.6), CX(8), CY(26.6), PEN);
  Lab(8.4, 26.3, INK, '35');
  Thick(CX(2), CY(28), CX(5.9), CY(28), PEN);
  Lab(6.3, 27.7, INK, '23');
  Lab(18, 25, INK, '60 is under 70, so the frame');
  Lab(18, 26, INK, 'waits for TWO retraces. There');
  Lab(18, 27, INK, 'is no 60 to be had. Lesson 13''s');
  Lab(18, 28, INK, 'staircase, met from below.');
end;

{ ==========================================================================
   PAGE 9 - four answers, and one of them wins.

   The closing card. The Z-buffer arithmetic is the one to leave on the
   screen: 64000 pixels with a word of depth each is 128000 bytes, and a
   segment holds 65536. On this machine that is the end of the sentence.
   ========================================================================== }
procedure PageFinal(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'four answers, and one of them wins');
  Box(0.9, 2.6, 35, 16.4, PEN);
  Lab(1.6, 3.4, REDPEN, '1');
  Lab(3.4, 3.4, INK, 'DO NOTHING');
  Lab(3.4, 4.4, GREY, 'it is a wireframe. Games shipped like this.');

  Lab(1.6, 6, REDPEN, '2');
  Lab(3.4, 6, INK, 'DRAW LESS - pull the far clip in');
  Lab(3.4, 7, GREY, 'cheap, and it costs you the view. We just bought that view.');

  Lab(1.6, 8.6, REDPEN, '3');
  Lab(3.4, 8.6, INK, 'THE FLOATING HORIZON - 320 bytes');
  Lab(3.4, 9.6, GREY, 'this lesson. Exact, and it needs the near-to-far order.');

  Lab(1.6, 11.2, REDPEN, '4');
  Lab(3.4, 11.2, INK, 'THE PAINTER - draw FAR TO NEAR, let the paint cover it');
  Lab(3.4, 12.2, GREY, 'the same table, read backwards. Hiding comes free with the');
  Lab(3.4, 13, GREY, 'colour: you do not pay for it, you get it with the fill.');
  Lab(3.4, 14.4, GREY, '(and a Z-buffer? 64000 pixels, a word each, is 128000 bytes.');
  Lab(3.4, 15.2, GREY, 'A segment holds 65536. That is the end of the sentence.)');
  if upto < 2 then Exit;

  Lab(0.9, 17.8, GREY, 'AND THE REAL LIMIT OF NUMBER 3:');
  Lab(1.8, 18.8, INK, 'HOR holds ONE skyline for each column. A height field has');
  Lab(1.8, 19.8, INK, 'exactly one. A house with a gap under it has two, and from');
  Lab(1.8, 20.8, INK, 'that moment the array is lying. Next lesson there are houses.');
  if upto < 3 then Exit;

  Lab(0.9, 23, REDPEN, 'SO: the ground has height, and one shift makes it worth flying');
  Lab(0.9, 24, REDPEN, 'between. The order is built once and costs nothing after that.');
  Lab(0.9, 25, REDPEN, 'And hiding is not expensive - leaving a good line routine is.');
  Lab(0.9, 27, INK, 'Next lesson: the ground gets FILLED, far to near, and every');
  Lab(0.9, 28, INK, 'line in this file that hides anything comes straight out.');
end;
