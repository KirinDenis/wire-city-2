{ ==========================================================================
   THE MATRIX, PART TWO - a point is so many of i and so many of j, so the
   turned point is so many of i2 and so many of j2. The parallelogram tells
   you where it went before the arithmetic does.

   P = i + j on purpose: one of each. Then P2 = i2 + j2 = (4,3) + (-3,4) =
   (1, 7) cells, on a crossing, and the formula agrees: (40, 278).

   And then THE TRAP, which is mine, not the brief's: y2 needs the OLD x.
   Store x2 first and the second line reads 40 where it should read 200,
   and the point lands at (40, 183) - a shear, not a turn. ENGINE's Rot2
   parks x2 in t1 for exactly this reason. Better it is met on paper.
   ========================================================================== }
procedure PageMat2(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'any point is some i and some j');
  Lab(0.9, 2.3, REDPEN, 'so turn the arrows, and every point comes along for free.');
  SetColor(PENCIL);
  Line(CX(2), CY(8), CX(17), CY(8));   ArrowR(CX(17.5), CY(8));
  Lab(17.8, 7.6, PENCIL, 'x');
  Line(CX(7), CY(3), CX(7), CY(19));   ArrowD(CX(7), CY(19.5));
  Lab(5.9, 18.6, PENCIL, 'y');
  if upto < 2 then Exit;

  SetColor(PEN);
  SetLineStyle(SolidLn, 0, ThickWidth);
  Line(CX(7), CY(8), CX(12), CY(8));
  Line(CX(7), CY(8), CX(7),  CY(13));
  SetLineStyle(SolidLn, 0, NormWidth);
  Lab(12.3, 7.4, PEN, 'i');
  Lab(5.9, 13.2, PEN, 'j');
  SetLineStyle(DottedLn, 0, NormWidth);
  Line(CX(12), CY(8), CX(12), CY(13));
  Line(CX(7), CY(13), CX(12), CY(13));
  SetLineStyle(SolidLn, 0, NormWidth);
  Dot(CX(12), CY(13), PEN);
  Lab(12.4, 12.2, PEN, 'P = i + j');
  Lab(12.4, 13.2, GREY, '( 200, 200 )');
  if upto < 3 then Exit;

  SetColor(REDPEN);
  SetLineStyle(SolidLn, 0, ThickWidth);
  Line(CX(7), CY(8), CX(11), CY(11));
  Line(CX(7), CY(8), CX(4),  CY(12));
  SetLineStyle(SolidLn, 0, NormWidth);
  Lab(11.3, 10.4, REDPEN, 'i2');
  Lab(2.6, 11.6, REDPEN, 'j2');
  SetColor(PENCIL);
  SetLineStyle(DottedLn, 0, NormWidth);
  Line(CX(11), CY(11), CX(8), CY(15));
  Line(CX(4),  CY(12), CX(8), CY(15));
  SetLineStyle(SolidLn, 0, NormWidth);
  Dot(CX(8), CY(15), REDPEN);
  Lab(8.4, 15.4, REDPEN, 'P2 = i2 + j2');
  Lab(8.4, 16.4, GREY, '( 40, 278 )  1 across, 7 down');
  if upto < 4 then Exit;

  SetColor(PENCIL);
  Line(CX(20), CY(4), CX(20), CY(28));
  Lab(20.6, 4.2, INK,  'P is one i and one j.');
  Lab(20.6, 5.2, INK,  'turn the arrows, and P is');
  Lab(20.6, 6.2, INK,  'one i2 and one j2. The');
  Lab(20.6, 7.2, INK,  'parallelogram says where.');
  Lab(20.6, 8.8, INK,  'x2 = ( 200*102 - 200*76 ) >> 7');
  Lab(20.6, 9.8, INK,  '   = 5200 >> 7 =');
  Lab(29.2, 9.8, REDPEN, '40');
  Lab(20.6, 11.2, INK, 'y2 = ( 200*76 + 200*102 ) >> 7');
  Lab(20.6, 12.2, INK, '   = 35600 >> 7 =');
  Lab(29.8, 12.2, REDPEN, '278');
  Lab(20.6, 13.8, GREY, 'x2 = x cos - y sin');
  Lab(20.6, 14.8, GREY, 'y2 = x sin + y cos');
  Lab(20.6, 15.8, GREY, 'the matrix, written out.');
  if upto < 5 then Exit;

  SetColor(REDPEN);
  Line(CX(20.6), CY(17.6), CX(35), CY(17.6));
  Lab(20.6, 18.2, REDPEN, 'THE TRAP: y2 needs the OLD x.');
  Lab(20.6, 19.4, INK, 'store x2 first, and the second');
  Lab(20.6, 20.4, INK, 'line reads 40 where it should');
  Lab(20.6, 21.4, INK, 'read 200:');
  Lab(20.6, 22.6, INK, '( 40*76 + 200*102 ) >> 7 = 183');
  Lab(20.6, 24, INK,   'P lands at ( 40, 183 ).');
  Lab(20.6, 25, INK,   'that is a shear, not a turn.');
  Lab(20.6, 26, INK,   'park x2 until y2 is done.');
  Lab(20.6, 27, INK,   'Rot2 does exactly that.');
  SetColor(REDPEN);
  Circle(CX(8), CY(12.575), 4);
  Lab(8.4, 12.3, REDPEN, 'shear');
end;

{ ==========================================================================
   THE 3D CUBE - eight corners, and a third number on each of them.

   z comes OUT of the page towards you, and squared paper has a convention
   for that older than any computer: draw it at forty-five degrees through
   the corners of the cells, one across for every two of depth.

   The teaching is one sentence: a turn about y is the SAME two lines, on
   x and z, with y left alone. Three axes, three pairs, one formula.
   ========================================================================== }
procedure PageCube3(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'the cube: eight corners, three numbers each');
  Lab(0.9, 2.3, REDPEN, 'z comes out of the page. On squares you draw it at 45 degrees.');
  SetColor(PENCIL);
  Line(CX(4), CY(15), CX(19), CY(15));  ArrowR(CX(19.5), CY(15));
  Lab(19.8, 14.6, PENCIL, 'x');
  Line(CX(10), CY(8), CX(10), CY(23));  ArrowD(CX(10), CY(23.5));
  Lab(8.9, 22.6, PENCIL, 'y');
  Line(CX(10), CY(15), CX(16), CY(9));
  Line(CX(16), CY(9), CX(15.5), CY(9.1));
  Line(CX(16), CY(9), CX(15.9), CY(9.5));
  Lab(16.3, 8.4, PENCIL, 'z');
  Lab(0.9, 4, GREY, 'one cell across = two cells of depth');
  if upto < 2 then Exit;

  SetColor(PEN);                        { front face, z = -80, towards you }
  Rectangle(CX(7), CY(14), CX(11), CY(18));
  Line(CX(9), CY(12), CX(13), CY(12));  Line(CX(13), CY(12), CX(13), CY(16));
  Line(CX(7), CY(14), CX(9), CY(12));
  Line(CX(11), CY(14), CX(13), CY(12));
  Line(CX(11), CY(18), CX(13), CY(16));
  SetLineStyle(DashedLn, 0, NormWidth); { the corner you cannot see }
  Line(CX(9), CY(16), CX(9), CY(12));
  Line(CX(9), CY(16), CX(13), CY(16));
  Line(CX(9), CY(16), CX(7), CY(18));
  SetLineStyle(SolidLn, 0, NormWidth);
  Lab(6.1, 13.2, INK, 'A');  Lab(11.3, 13.2, INK, 'B');
  Lab(11.3, 18.2, INK, 'C'); Lab(6.1, 18.2, INK, 'D');
  Lab(8.4, 11.2, INK, 'E');  Lab(13.3, 11.2, INK, 'F');
  Lab(13.3, 16.2, INK, 'G'); Lab(8.2, 16.4, GREY, 'H');
  if upto < 3 then Exit;

  SetColor(PENCIL);
  Line(CX(20), CY(4), CX(20), CY(28));
  Lab(20.6, 4.2, INK,  'eight corners, one table:');
  Lab(20.6, 5.6, INK,  'A ( -80, -80, -80 )');
  Lab(20.6, 6.6, INK,  'B (  80, -80, -80 )');
  Lab(20.6, 7.6, INK,  'C (  80,  80, -80 )');
  Lab(20.6, 8.6, INK,  'D ( -80,  80, -80 )');
  Lab(20.6, 9.8, GREY, 'E to H: the same four,');
  Lab(20.6, 10.8, GREY, 'with z = +80. Two cells');
  Lab(20.6, 11.8, GREY, 'each way from the centre.');
  if upto < 4 then Exit;

  Lab(20.6, 13.4, INK,  'a turn about y is the SAME');
  Lab(20.6, 14.4, INK,  'two lines, on x and z.');
  Lab(20.6, 15.4, INK,  'y is left alone.');
  Lab(20.6, 16.8, INK,  'x2 = (x*90 - z*90) >> 7');
  Lab(20.6, 17.8, INK,  'z2 = (x*90 + z*90) >> 7');
  Lab(20.6, 19.2, INK,  'A: x2 = (-7200+7200)>>7 = 0');
  Lab(20.6, 20.2, INK,  '   z2 = (-7200-7200)>>7');
  Lab(20.6, 21.2, INK,  '      = -14400>>7 =');
  Lab(30.6, 21.2, REDPEN, '-113');
  Lab(20.6, 22.4, REDPEN, 'A2 = ( 0, -80, -113 )');
  if upto < 5 then Exit;

  SetColor(REDPEN);
  Line(CX(20.6), CY(24), CX(35), CY(24));
  Lab(20.6, 24.6, REDPEN, 'about y: use ( x, z )');
  Lab(20.6, 25.6, REDPEN, 'about x: use ( y, z )');
  Lab(20.6, 26.6, REDPEN, 'about z: use ( x, y )');
  Lab(20.6, 27.8, INK, 'one formula, three times.');
  Lab(0.9, 25.4, GREY, 'that is all a turn in three');
  Lab(0.9, 26.4, GREY, 'dimensions is: the page before,');
  Lab(0.9, 27.4, GREY, 'done to a different pair.');
end;

{ ==========================================================================
   THE CAMERA AND PERSPECTIVE - and it is the triangle again, for the
   fourth time, only now there are two of them and they are the same shape.

   The small one is eye - glass - where the ray hits. The big one is
   eye - foot of the point - the point. Same angle at the eye, so the sides
   keep one ratio: y2 over d equals y over z. One divide. That is the whole
   of perspective, and lesson 0F paid for it in clocks.
   ========================================================================== }
procedure PagePersp(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'the camera: one divide');
  Lab(0.9, 2.3, REDPEN, 'the triangle, a fourth time - but now there are two, the same shape.');
  Axis(CX(4), CY(14), CX(18.5), CY(14), PENCIL, True);
  SetColor(PENCIL); ArrowR(CX(19), CY(14));
  Lab(19.2, 13.6, PENCIL, 'z');
  SetColor(PEN);
  Line(CX(4), CY(14), CX(4), CY(18));   ArrowD(CX(4), CY(18.5));
  Lab(2.9, 17.6, PEN, 'y');
  Dot(CX(4), CY(14), PEN);
  Lab(0.9, 13.6, INK, 'eye');
  SetColor(GREEN);
  SetLineStyle(SolidLn, 0, ThickWidth);
  Line(CX(10), CY(11.5), CX(10), CY(16.5));
  SetLineStyle(SolidLn, 0, NormWidth);
  Lab(8.4, 10.6, GREEN, 'the glass, 200 tall');
  if upto < 2 then Exit;

  SetColor(PEN);
  Dot(CX(16), CY(17), PEN);
  Lab(16.4, 17.2, PEN, 'P');
  Lab(10.4, 18.2, PEN, 'y = 120,  z = 480');
  SetColor(PENCIL);
  SetLineStyle(DottedLn, 0, NormWidth);
  Line(CX(16), CY(14), CX(16), CY(17));
  SetLineStyle(SolidLn, 0, NormWidth);
  Line(CX(4), CY(14), CX(16), CY(17));
  Dot(CX(10), CY(15.5), GREEN);
  Lab(10.4, 15.8, GREEN, 'y2');
  if upto < 3 then Exit;

  SetColor(PENCIL);
  Dim(CX(4), CX(10), CY(21));   Lab(4.3, 21.4, INK, 'd = 6 cells = 240');
  Dim(CX(4), CX(16), CY(22.5)); Lab(4.3, 22.9, INK, 'z = 12 cells = 480');
  Line(CX(20), CY(4), CX(20), CY(28));
  Lab(20.6, 4.2, INK,  'two triangles, one shape.');
  Lab(20.6, 5.2, INK,  'eye, glass, hit - and');
  Lab(20.6, 6.2, INK,  'eye, foot, P. Same angle');
  Lab(20.6, 7.2, INK,  'at the eye, so the sides');
  Lab(20.6, 8.2, INK,  'keep one ratio:');
  Lab(20.6, 9.6, INK,  'y2 / d  =  y / z');
  Lab(20.6, 11, REDPEN, 'y2  =  y * d / z');
  if upto < 4 then Exit;

  Lab(20.6, 12.8, INK, 'y2 = 120 * 240 / 480 =');
  Lab(32.2, 12.8, REDPEN, '60');
  Lab(20.6, 13.8, GREY, '60 is one and a half cells.');
  Lab(20.6, 14.8, GREY, 'count it, on the glass.');
  Lab(20.6, 16.2, INK, 'x the same way, seen from');
  Lab(20.6, 17.2, INK, 'above:  x2 = x * d / z');
  if upto < 5 then Exit;

  SetColor(REDPEN);
  Line(CX(20.6), CY(19), CX(35), CY(19));
  Lab(20.6, 19.6, REDPEN, 'ONE divide. That is all');
  Lab(20.6, 20.6, REDPEN, 'perspective is.');
  Lab(20.6, 22, INK,   'and d is where YOU sit.');
  Lab(20.6, 23, INK,   'six cells is about 67');
  Lab(20.6, 24, INK,   'degrees of view. Halve d');
  Lab(20.6, 25, INK,   'and the world bulges.');
  Lab(20.6, 26, INK,   'double it and it flattens.');
  Lab(20.6, 27.2, GREY, 'the game uses 270. Lesson 0F.');
end;

{ ==========================================================================
   EVERYTHING TOGETHER - model, turn, move, view, glass - and corner A
   walked through all five with a pencil. The first row lands on (100, 40),
   the very pixel the three-view page showed, so the lesson closes on a
   number the reader has now reached by two different roads.
   ========================================================================== }
procedure PageAll(upto: Integer);
procedure Box(c: Real; s: string);
begin
  SetColor(INK);
  Rectangle(CX(c), CY(4), CX(c + 5), CY(6));
  Lab(c + 0.5, 4.6, INK, s);
end;
begin
  Head(0.9, 0.7, INK, 'all five steps, by hand');
  Lab(0.9, 2.3, REDPEN, 'model, turn, move, view, glass. You have drawn every one of them.');
  Box(1, 'MODEL');  Box(7.5, 'TURN');  Box(14, 'MOVE');  Box(20.5, 'VIEW');  Box(27, 'GLASS');
  SetColor(PENCIL);
  Line(CX(6), CY(5), CX(7.5), CY(5));    ArrowR(CX(7.5), CY(5));
  Line(CX(12.5), CY(5), CX(14), CY(5));  ArrowR(CX(14), CY(5));
  Line(CX(19), CY(5), CX(20.5), CY(5));  ArrowR(CX(20.5), CY(5));
  Line(CX(25.5), CY(5), CX(27), CY(5));  ArrowR(CX(27), CY(5));
  if upto < 2 then Exit;

  Lab(0.9, 8, INK,   'corner A of the cube, from its own centre:');
  Lab(0.9, 9, PEN,   'A = ( -80, -80, -80 )');
  Lab(0.9, 10.4, GREY, 'row one: no turn. Move the cube 400 away.');
  if upto < 3 then Exit;

  Lab(0.9, 12, INK,  'MOVE:  ( -80, -80, -80 + 400 )  =  ( -80, -80, 320 )');
  Lab(0.9, 13, INK,  'VIEW:  the camera is at 0, looking along z. Subtract nothing.');
  Lab(0.9, 14.4, INK, 'GLASS: sx = 160 + ( -80 * 240 / 320 ) = 160 - 60 = 100');
  Lab(0.9, 15.4, INK, '       sy = 100 + ( -80 * 240 / 320 ) = 100 - 60 =  40');
  Lab(0.9, 16.8, REDPEN, 'A2 = ( 100, 40 )');
  SetColor(REDPEN);
  Ellipse(CX(4.3), CY(17.1), 0, 360, CX(4), CY(0.55));
  Lab(9.4, 16.8, GREY, '- the pixel the three views gave you.');
  if upto < 4 then Exit;

  SetColor(PENCIL);
  Line(CX(0.9), CY(18.6), CX(35), CY(18.6));
  Lab(0.9, 19.2, GREY, 'row two: TURN it first, by 32 about y - page ten.');
  Lab(0.9, 20.4, INK,  'TURN:  A -> ( 0, -80, -113 )');
  Lab(0.9, 21.4, INK,  'MOVE:  ( 0, -80, -113 + 400 )  =  ( 0, -80, 287 )');
  Lab(0.9, 22.8, INK,  'GLASS: sx = 160 + 0 = 160');
  Lab(0.9, 23.8, INK,  '       sy = 100 + ( -80 * 240 / 287 ) = 100 - 66 = 34');
  Lab(0.9, 25.2, REDPEN, 'A2 = ( 160, 34 )');
  SetColor(REDPEN);
  Ellipse(CX(4.3), CY(25.5), 0, 360, CX(4), CY(0.55));
  Lab(9.4, 25.2, GREY, '- one turn moved it sixty pixels across.');
  if upto < 5 then Exit;

  SetColor(REDPEN);
  SetLineStyle(SolidLn, 0, ThickWidth);
  Line(CX(0.9), CY(27.2), CX(35), CY(27.2));
  SetLineStyle(SolidLn, 0, NormWidth);
  Lab(0.9, 27.6, REDPEN, 'a machine does this sixty times a second. You have now done it once.');
  Lab(0.9, 28.6, REDPEN, 'that is the difference between using it and knowing it.');
end;
