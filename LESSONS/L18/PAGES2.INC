{ ==========================================================================
   A VECTOR IS NOT A PLACE - it is a displacement, and the triangle we drew
   twice already IS one. Read forwards it turns an angle into a pair; read
   backwards, the pair is the only thing a program ever stores.

   From this page on y runs DOWN. The page before earned that.
   ========================================================================== }
procedure PageVec(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'a vector is not a place');
  Lab(0.9, 2.3, REDPEN, 'it is a DISPLACEMENT: so many across, so many down.');
  SetColor(PENCIL);
  Line(CX(4), CY(6), CX(26), CY(6));   ArrowR(CX(26.5), CY(6));
  Lab(26.8, 5.6, PENCIL, 'x');
  Line(CX(4), CY(6), CX(4), CY(20));   ArrowD(CX(4), CY(20.5));
  Lab(2.9, 19.6, PENCIL, 'y');
  if upto < 2 then Exit;

  SetColor(PEN);
  SetLineStyle(SolidLn, 0, ThickWidth);
  Line(CX(4), CY(6), CX(12), CY(12));
  SetLineStyle(SolidLn, 0, NormWidth);
  Dot(CX(12), CY(12), REDPEN);
  Lab(12.4, 11.2, REDPEN, '( 320, 240 )');
  SetColor(PENCIL);
  SetLineStyle(DottedLn, 0, NormWidth);
  Line(CX(4), CY(12), CX(12), CY(12));
  Line(CX(12), CY(6), CX(12), CY(12));
  SetLineStyle(SolidLn, 0, NormWidth);
  Lab(5.2, 12.6, GREY, '320 = 8 cells');
  Lab(12.4, 8.6, GREY, '240 = 6 cells');
  if upto < 3 then Exit;

  SetColor(PENCIL);
  Line(CX(16), CY(14), CX(24), CY(20));  Dot(CX(24), CY(20), PENCIL);
  Line(CX(6),  CY(16), CX(14), CY(22));  Dot(CX(14), CY(22), PENCIL);
  Lab(24.4, 20.2, GREY, 'the same vector');
  Lab(14.4, 22.2, GREY, 'and again');
  if upto < 4 then Exit;

  SetColor(INK);
  Rectangle(CX(28), CY(8), CX(34), CY(10));
  Lab(28.6, 8.6, INK, '320, 240');
  Lab(28, 11, GREY,   'that pair IS the');
  Lab(28, 12, GREY,   'whole vector.');
  Lab(28, 13.4, GREY, 'where you start');
  Lab(28, 14.4, GREY, 'it is no part');
  Lab(28, 15.4, GREY, 'of it at all.');
  if upto < 5 then Exit;

  SetColor(PENCIL);
  Line(CX(0.9), CY(24), CX(35), CY(24));
  Lab(0.9, 24.6, INK, 'now read it BACKWARDS. Choose a length and an angle,');
  Lab(0.9, 25.6, INK, 'and the table hands you the pair:');
  Lab(0.9, 27, INK,   'r = 400,  a = 26   gives   x = 318,  y = 237');
  Lab(0.9, 28.4, REDPEN, 'two numbers. That is all a program ever keeps.');
end;

{ ==========================================================================
   ONE VECTOR, TURNED, IS A CIRCLE. Lesson 6 drew this thirty times a
   second; here it is at one point a minute, with a pencil.

   The page is about the COST: four multiplies and two shifts buy one point,
   and sixty-four points look like a circle to anybody alive.
   ========================================================================== }
procedure PageCirc(upto: Integer);
var i : Integer;
    ax, ay : Real;
begin
  Head(0.9, 0.7, INK, 'one vector, turned, is a circle');
  Lab(0.9, 2.3, REDPEN, 'the same two lines, over and over. Nothing else at all.');
  SetColor(PENCIL);
  Line(CX(1), CY(15), CX(21), CY(15));
  Line(CX(11), CY(5), CX(11), CY(25));
  Dot(CX(11), CY(15), PENCIL);
  if upto < 2 then Exit;

  SetColor(PENCIL);
  Circle(CX(11), CY(15), CX(10));
  Lab(0.9, 4, GREY, 'r = 400 = 10 cells');
  if upto < 3 then Exit;

  SetColor(PEN);
  for i := 0 to 7 do
  begin
    ax := 11 + 10 * Cos(i * Pi / 4);
    ay := 15 + 10 * Sin(i * Pi / 4);
    Line(CX(11), CY(15), CX(ax), CY(ay));
    Dot(CX(ax), CY(ay), REDPEN);
  end;
  Lab(0.9, 26.4, INK, 'the TIPS are the circle. Nothing draws a');
  Lab(0.9, 27.4, INK, 'curve - one vector just points elsewhere.');
  if upto < 4 then Exit;

  Lab(23.6, 5, GREY, '  a      x      y');
  SetColor(PENCIL);
  Line(CX(23.6), CY(5.8), CX(34), CY(5.8));
  Lab(23.6, 6.4, INK,  '  0    396      0');
  Lab(23.6, 7.4, INK,  ' 32    280    280');
  Lab(23.6, 8.4, INK,  ' 64      0    396');
  Lab(23.6, 9.4, INK,  ' 96   -281    280');
  Lab(23.6, 10.4, INK, '128   -396      0');
  Lab(23.6, 12, GREY,  'every one of them');
  Lab(23.6, 13, GREY,  'out of the SAME');
  Lab(23.6, 14, GREY,  'table, by the same');
  Lab(23.6, 15, GREY,  'two lines.');
  if upto < 5 then Exit;

  Lab(23.6, 17, INK,   'x = r * SINTAB');
  Lab(25.6, 18, INK,   '[ a + 64 ] >> 7');
  Lab(23.6, 19.4, INK, 'y = r * SINTAB');
  Lab(25.6, 20.4, INK, '[ a ] >> 7');
  Lab(23.6, 22, REDPEN, 'four multiplies and');
  Lab(23.6, 23, REDPEN, 'two shifts buy one');
  Lab(23.6, 24, REDPEN, 'point.');
  Lab(23.6, 25.4, GREY, 'sixty-four of them');
  Lab(23.6, 26.4, GREY, 'is a circle to any');
  Lab(23.6, 27.4, GREY, 'eye alive.');
end;

{ ==========================================================================
   A SQUARE, TURNED, BY WHOLE NUMBERS - and still no matrix in sight.

   The angle is 32, one eighth of a turn, because at 32 the answers are
   checkable BY EYE: every corner lands on an axis. A pencil that puts them
   anywhere else has made a mistake, and says so without being told.

   Then the detail that is worth the page: 168 one way and 169 the other. A
   shift does not round, it rounds DOWN, and it does that for negatives too,
   so the turned square comes out a pixel lopsided.
   ========================================================================== }
procedure PageSq(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'a square, turned, by whole numbers');
  Lab(0.9, 2.3, REDPEN, 'no matrix yet. Just those two lines, four times over.');
  SetColor(PENCIL);
  Line(CX(3), CY(14), CX(17), CY(14));
  Line(CX(9), CY(8),  CX(9),  CY(20));
  Lab(3.2, 7.2, GREY, 'y is DOWN from here');
  if upto < 2 then Exit;

  SetColor(PEN);
  Rectangle(CX(6), CY(11), CX(12), CY(17));
  Dot(CX(12), CY(17), PEN);
  Lab(12.3, 17.4, PEN, 'A');
  if upto < 3 then Exit;

  SetColor(PENCIL);
  Line(CX(19), CY(4), CX(19), CY(28));
  Lab(19.6, 4.2, INK,  'a = 32, an eighth of a turn');
  Lab(19.6, 5.4, GREY, 'SINTAB[32] = 90   SINTAB[96] = 90');
  Lab(19.6, 7, INK,    'x2 = ( x*90 - y*90 ) >> 7');
  Lab(19.6, 8, INK,    'y2 = ( x*90 + y*90 ) >> 7');
  Lab(19.6, 9.6, INK,  'A:  x2 = ( 10800 - 10800 ) >> 7 = 0');
  Lab(19.6, 10.6, INK, '    y2 = ( 10800 + 10800 ) >> 7');
  Lab(19.6, 11.6, INK, '       = 21600 >> 7 =');
  Lab(30.6, 11.6, REDPEN, '168');
  if upto < 4 then Exit;

  Lab(19.6, 13.2, GREY, 'and the other three, the same way:');
  Lab(19.6, 14.4, INK,  'A ( 120, 120)  ->  (    0,  168 )');
  Lab(19.6, 15.4, INK,  'B (-120, 120)  ->  ( -169,    0 )');
  Lab(19.6, 16.4, INK,  'C (-120,-120)  ->  (    0, -169 )');
  Lab(19.6, 17.4, INK,  'D ( 120,-120)  ->  (  168,    0 )');
  SetColor(REDPEN);
  Line(CX(9),     CY(18.2),  CX(4.775), CY(14));
  Line(CX(4.775), CY(14),    CX(9),     CY(9.775));
  Line(CX(9),     CY(9.775), CX(13.2),  CY(14));
  Line(CX(13.2),  CY(14),    CX(9),     CY(18.2));
  Dot(CX(9), CY(18.2), REDPEN);
  if upto < 5 then Exit;

  SetColor(REDPEN);
  Line(CX(19.6), CY(19.4), CX(35), CY(19.4));
  Lab(19.6, 20, REDPEN, 'look at 168 against 169.');
  Lab(19.6, 21.4, INK, 'a shift does not round. It rounds');
  Lab(19.6, 22.4, INK, 'DOWN - and for negatives too, so');
  Lab(19.6, 23.4, INK, 'minus 168.75 becomes minus 169');
  Lab(19.6, 24.4, INK, 'while 168.75 becomes 168.');
  Lab(19.6, 25.8, GREY, 'your turned square is one pixel');
  Lab(19.6, 26.8, GREY, 'lopsided, and now you know why.');
end;
