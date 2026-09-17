{ ==========================================================================
   THE MATRIX IS JUST TWO ARROWS - part one, and the whole point of it is
   that nothing here is memorised. The reader DRAWS the matrix and then
   discovers that is what it was.

   The arrows are five cells long, and the angle is our step 26, because
   those two choices make the turned pair land exactly on crossings:

       i  = ( 200,   0 )  ->  ( 159, 118 )   =  4 right, 3 down
       j  = (   0, 200 )  ->  (-119, 159 )   =  3 left,  4 down

   That is the three-four-five triangle for the third time in this lesson,
   and now it is the turned basis. A reader who counts squares can check
   the whole page without believing a word of it.
   ========================================================================== }
procedure PageMat1(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'the matrix is just two arrows');
  Lab(0.9, 2.3, REDPEN, 'nothing to memorise on this page. You are going to draw it.');
  SetColor(PENCIL);
  Line(CX(3), CY(9), CX(17), CY(9));    ArrowR(CX(17.5), CY(9));
  Lab(17.8, 8.6, PENCIL, 'x');
  Line(CX(8), CY(4), CX(8), CY(20));    ArrowD(CX(8), CY(20.5));
  Lab(6.9, 19.6, PENCIL, 'y');
  if upto < 2 then Exit;

  SetColor(PEN);                        { the two arrows we start from }
  SetLineStyle(SolidLn, 0, ThickWidth);
  Line(CX(8), CY(9), CX(13), CY(9));
  Line(CX(8), CY(9), CX(8),  CY(14));
  SetLineStyle(SolidLn, 0, NormWidth);
  Dot(CX(13), CY(9), PEN);
  Dot(CX(8), CY(14), PEN);
  Lab(13.3, 8.4, PEN, 'i');
  Lab(6.9, 14.2, PEN, 'j');
  Lab(0.9, 4, GREY, 'two arrows, five cells each.');
  Lab(0.9, 5, GREY, 'one along x, one along y.');
  Lab(0.9, 22, GREY, 'every point on the page is so many of i');
  Lab(0.9, 23, GREY, 'and so many of j. Nothing else.');
  if upto < 3 then Exit;

  SetColor(PENCIL);
  Arc(CX(8), CY(9), 323, 360, CX(4));
  Lab(11.4, 10.4, GREY, 'a = 26');
  SetColor(REDPEN);                     { where they land. Count the cells. }
  SetLineStyle(SolidLn, 0, ThickWidth);
  Line(CX(8), CY(9), CX(12), CY(12));
  Line(CX(8), CY(9), CX(5),  CY(13));
  SetLineStyle(SolidLn, 0, NormWidth);
  Dot(CX(12), CY(12), REDPEN);
  Dot(CX(5), CY(13), REDPEN);
  Lab(12.3, 12.2, REDPEN, 'i2');
  Lab(1.4, 13.4, REDPEN, 'j2  3 left, 4 down');
  if upto < 4 then Exit;

  SetColor(PENCIL);
  Line(CX(20), CY(4), CX(20), CY(28));
  Lab(20.6, 4.2, INK,  'turn both, and write down');
  Lab(20.6, 5.2, INK,  'where they went:');
  Lab(20.6, 6.8, PEN,  'i  ( 200,   0 )');
  Lab(20.6, 7.8, REDPEN, '   ( 159, 118 )');
  Lab(20.6, 9.2, PEN,  'j  (   0, 200 )');
  Lab(20.6, 10.2, REDPEN, '   (-119, 159 )');
  Lab(20.6, 11.8, GREY, 'both on crossings, both');
  Lab(20.6, 12.8, GREY, 'countable. Check them.');
  if upto < 5 then Exit;

  Lab(20.6, 14.6, INK, 'now stand the two answers');
  Lab(20.6, 15.6, INK, 'up as COLUMNS:');
  SetColor(INK);
  Line(CX(21.6), CY(17.2), CX(21.2), CY(17.2));
  Line(CX(21.2), CY(17.2), CX(21.2), CY(19.4));
  Line(CX(21.2), CY(19.4), CX(21.6), CY(19.4));
  Line(CX(28.4), CY(17.2), CX(28.8), CY(17.2));
  Line(CX(28.8), CY(17.2), CX(28.8), CY(19.4));
  Line(CX(28.8), CY(19.4), CX(28.4), CY(19.4));
  Lab(22, 17.4, REDPEN, ' 102   -76');
  Lab(22, 18.6, REDPEN, '  76   102');
  Lab(29.2, 17.9, INK, '/ 128');
  Lab(20.6, 20.6, GREY, 'that is the rotation matrix,');
  Lab(20.6, 21.6, GREY, 'and it is not a rule. It is');
  Lab(20.6, 22.6, GREY, 'the two arrows you just drew,');
  Lab(20.6, 23.6, GREY, 'stood on end.');
  Lab(20.6, 25.2, REDPEN, '102 is SINTAB[26+64].');
  Lab(20.6, 26.2, REDPEN, ' 76 is SINTAB[26].');
  Lab(20.6, 27.4, GREY, 'the same two bytes as before.');
end;
