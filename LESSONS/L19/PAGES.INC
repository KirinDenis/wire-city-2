{ ==========================================================================
   PAGE 1 - thank you, and the prize. Text, and the four pens again.
   ========================================================================== }
procedure PagePrize(upto: Integer);
procedure Swatch(row: Real; c: Integer);
begin
  SetColor(c);
  SetLineStyle(SolidLn, 0, ThickWidth);
  Line(CX(1.2), CY(row), CX(4.2), CY(row));
  SetLineStyle(SolidLn, 0, NormWidth);
end;
begin
  Head(0.9, 0.7, INK, 'thank you - and here is the prize');
  Lab(0.9, 2.3, REDPEN, 'the same notebook. Every number on these pages is the game''s own.');
  Lab(0.9, 4, INK, 'Twelve lessons of toys: a square, an orbit, an arm, a cube, a camera.');
  Lab(0.9, 5, INK, 'Every one written from nothing, on purpose, so you would know what');
  Lab(0.9, 6, INK, 'every instruction was for. That was the price of admission.');
  if upto < 2 then Exit;

  SetColor(PEN);
  Rectangle(CX(0.9), CY(8), CX(35), CY(14.8));
  Head(1.4, 8.3, PEN, 'From here on, it is the game.');
  Lab(1.4, 10.6, INK, 'Everything on the screen today is drawn by the files OWL FLY is');
  Lab(1.4, 11.6, INK, 'built from. The same include lines. The same bugs, fixed on the');
  Lab(1.4, 12.6, INK, 'same dates, the reasons still written beside them.');
  Lab(1.4, 13.7, GREEN, 'You are not being shown an engine. You are being handed one.');
  if upto < 3 then Exit;

  Swatch(17.3, PENCIL);
  Lab(4.8, 17, INK, 'pencil - construction. Axes, rays, dimensions.');
  Swatch(18.8, PEN);
  Lab(4.8, 18.5, INK, 'blue - the objects: edges, points, and the code.');
  Swatch(20.3, GREEN);
  Lab(4.8, 20, INK, 'green - the glass, the wall, and what lands on them.');
  Swatch(21.8, REDPEN);
  Lab(4.8, 21.5, INK, 'red - the answer, circled. And the margin.');
  Lab(0.9, 24, GREY, 'Still 8086, still integers, still no library. That does not change.');
  Lab(0.9, 25, GREY, 'Pencil out. Every page has a number on it that you can check.');
end;

{ ==========================================================================
   PAGE 2 - the road to here, and the five files of ENGINE\.
   ========================================================================== }
procedure PageRoad(upto: Integer);
var i : Integer;
const
  T : array[0..4] of string[36] =
    ('0F  the divide, and INT 0',
     '10  the camera: one divide',
     '11  the island: a torus',
     '12  the notebook, by hand',
     '13  the engine: five files');
  F : array[0..4] of string[12] = ('E_8086.INC', 'E_MATH.INC', 'E_TERR.INC', 'E_M3D.INC', 'E_RAST.INC');
  D : array[0..4] of string[36] =
    ('FASM kept inside the 8086 jumps',
     'RND16 - lesson 11''s draw',
     'DSGEN, HGET - the island, entire',
     'SINQ ROTXZ PROJPT CLAMPAX',
     'OUTCODE CLIPLINE LINE, the faces');
begin
  Head(0.9, 0.7, INK, 'the road to here, and the five files');
  Lab(0.9, 2.3, REDPEN, 'nought F, ten, eleven, twelve - and thirteen is the engine itself.');
  for i := 0 to 3 do
  begin
    Lab(1.4, 4.6 + i * 1.8, GREY, T[i]);
    SetColor(PENCIL);
    Line(CX(2.2), CY(5.4 + i * 1.8), CX(2.2), CY(6.2 + i * 1.8));
    ArrowD(CX(2.2), CY(6.2 + i * 1.8));
  end;
  SetColor(REDPEN);
  Rectangle(CX(0.9), CY(11.4), CX(16.5), CY(12.8));
  Lab(1.4, 11.8, REDPEN, T[4]);
  if upto < 2 then Exit;

  SetColor(PEN);
  Rectangle(CX(18), CY(4), CX(35), CY(16));
  Lab(18.6, 4.4, PEN, 'ENGINE\');
  for i := 0 to 4 do
  begin
    Lab(18.6, 5.8 + i * 2, INK, F[i]);
    Lab(18.6, 6.7 + i * 2, GREY, D[i]);
  end;
  Lab(0.9, 17.6, INK, 'And GAMES\WIRECITY\CITY.ASM, line 818: the four routines the lesson');
  Lab(0.9, 18.6, INK, 'carries itself - DRAWEDGE3D, NEARCLIP, CLIPP0, CLIPP1 - copied, not');
  Lab(0.9, 19.6, INK, 'rewritten. Open it and read along.');
  Lab(0.9, 21.2, REDPEN, 'The one edit: two bytes of flag, so a stage can take a fence down.');
end;

{ ==========================================================================
   PAGE 3 - the lattice, a node a cell. 21 x 21 nodes round the eye, and
   the eye's node worked out of camx with one shift.
   ========================================================================== }
procedure PageLatt(upto: Integer);
var i : Integer;
begin
  Head(0.9, 0.7, INK, 'the lattice: a node a cell');
  Lab(0.9, 2.3, REDPEN, '1 cell = 1024 = one node. NR = 10: ten nodes each way from the eye.');
  SetColor(PEN);
  for i := 0 to 20 do
  begin
    Line(CX(1 + i), CY(4), CX(1 + i), CY(24));
    Line(CX(1), CY(4 + i), CX(21), CY(4 + i));
  end;
  Dot(CX(11), CY(14), REDPEN);
  Lab(11.3, 13.2, REDPEN, 'eye');
  Lab(0.6, 24.3, GREY, '30');   Lab(10.6, 24.3, GREY, '40');   Lab(20.6, 24.3, GREY, '50');
  Lab(21.3, 3.7, GREY, '44');   Lab(21.3, 13.7, GREY, '34');   Lab(21.3, 23.7, GREY, '24');
  Lab(4, 24.9, PENCIL, 'x: node gi, east');
  Lab(21.3, 8.7, PENCIL, 'z');
  Lab(21.3, 9.5, PENCIL, 'gj');
  if upto < 2 then Exit;

  Lab(22.6, 4.2, INK, 'which node the eye is over:');
  Lab(22.6, 5.4, PEN, '(camx + BIAS) >> 10');
  Lab(22.6, 6.8, INK, 'camx = 32768 at the start');
  Lab(22.6, 7.8, INK, 'BIAS = 8192');
  Lab(22.6, 8.8, INK, '32768 + 8192 = 40960');
  Lab(22.6, 9.8, INK, '40960 >> 10 = 40960 / 1024');
  Lab(22.6, 10.8, INK, '            =');
  Lab(29.8, 10.8, REDPEN, '40');
  Ring(29.6, 10.8, 1.4);
  Lab(22.6, 12, GREY, 'two shifts, by two then eight:');
  Lab(22.6, 13, GREY, 'an 8086 shifts by 1 or by CL,');
  Lab(22.6, 14, GREY, 'never by ten.');
  Lab(22.6, 15.2, GREY, 'camz = 26624: the same sum');
  Lab(22.6, 16.2, GREY, 'gives 34. Count to the eye.');
  if upto < 3 then Exit;

  Lab(22.6, 17.8, INK, 'BIAS, because a shift is');
  Lab(22.6, 18.8, INK, 'unsigned: push the world 8192');
  Lab(22.6, 19.8, INK, 'up first, and a camx just under');
  Lab(22.6, 20.8, INK, 'nought lands on node 7, not 63.');
  Lab(0.9, 25.8, INK, '64 nodes x 1024 = 65536. One word:');
  Lab(0.9, 26.8, INK, '65535 + 1 = 0. So node 63''s neighbour');
  Lab(0.9, 27.8, INK, 'to the east is node 0, and a node''s');
  Lab(0.9, 28.8, INK, 'distance from the eye wraps by itself.');
  if upto < 4 then Exit;

  Thick(CX(11), CY(14), CX(12), CY(14), REDPEN);
  Thick(CX(11), CY(14), CX(11), CY(13), REDPEN);
  Lab(22.6, 22.4, INK, 'every square draws two edges');
  Lab(22.6, 23.4, INK, 'of its own: east, and north.');
  Lab(22.6, 24.4, INK, 'Coloured by the height at its');
  Lab(22.6, 25.4, INK, 'corner - lesson 11''s six bands.');
  Lab(22.6, 26.8, REDPEN, 'Flat. Still. The relief is');
  Lab(22.6, 27.8, REDPEN, 'next: one number a corner.');
end;

{ ==========================================================================
   PAGE 4 - one edge's road: DRAWEDGE3D, five lines out of CITY.ASM.
   ========================================================================== }
procedure PageEdge(upto: Integer);
procedure Note(row: Real; c: Integer; s: string);
begin
  SetColor(PENCIL);
  Line(CX(9.6), CY(row + 0.3), CX(8.6), CY(row + 0.3));
  Lab(10, row, c, s);
end;
begin
  Head(0.9, 0.7, INK, 'one edge''s road');
  Lab(0.9, 2.3, REDPEN, 'GAMES\WIRECITY\CITY.ASM, line 818. Five lines. Two of them are fences.');
  Lab(0.9, 4.4, PEN, 'DRAWEDGE3D:');
  Lab(0.9, 5.6, PEN, '    call NEARCLIP');
  Lab(0.9, 6.8, PEN, '    jc   .skip');
  Lab(0.9, 8, PEN,   '    call PROJ2');
  Lab(0.9, 9.2, PEN, '    call CLIPLINE');
  Lab(0.9, 10.4, PEN, '    jc   .skip');
  Lab(0.9, 11.6, PEN, '    call LINE');
  Lab(0.9, 12.8, PEN, '.skip: ret');
  Note(5.6, INK, 'the wall before your eye: 3D, before the divide');
  Note(8, GREY, 'the divide of lesson 0F, with its guard');
  Note(9.2, INK, 'the four edges of the glass: 2D, after the divide');
  Note(11.6, GREY, 'and only then a pixel is written');
  if upto < 2 then Exit;

  SetColor(PENCIL);
  Line(CX(0.9), CY(14.6), CX(35), CY(14.6));
  Lab(0.9, 15.2, INK, 'Two fences, and they are not the same fence. The stages take them');
  Lab(0.9, 16.2, INK, 'down one at a time and let you look.');
  Lab(0.9, 17.8, GREY, 'A cube could be dropped whole when it misbehaved - lesson 10 did.');
  Lab(0.9, 18.8, GREY, 'A lattice cannot. You are standing in the middle of it.');
  Lab(0.9, 20.6, REDPEN, 'the next three pages: the first fence, worked. The trap under it.');
  Lab(0.9, 21.6, REDPEN, 'And the second fence, worked.');
end;

{ ==========================================================================
   PAGE 5 - THE NEAR PLANE, WORKED. 1 cell = 20, so P0 (-80,-40), P1
   (120,120) and the cut (20,40) all sit on crossings. CLIPP0's arithmetic
   exactly: tnum = NEARZ - z0, tden = z1 - z0, IMUL then IDIV.
   ========================================================================== }
procedure PageNear(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'the near plane, worked');
  Lab(0.9, 2.3, REDPEN, '1 cell = 20.  PLAN, from above: z to the right, x down.  NEARZ = 40.');
  Axis(CX(4), CY(12), CX(17.5), CY(12), PENCIL, True);
  SetColor(PENCIL); ArrowR(CX(18), CY(12));
  Lab(18.3, 11.6, PENCIL, 'z');
  Axis(CX(8), CY(5), CX(8), CY(20), PENCIL, False);
  SetColor(PENCIL); ArrowD(CX(8), CY(20.5));
  Lab(6.9, 19.6, PENCIL, 'x');
  Dot(CX(8), CY(12), PEN);
  Lab(8.3, 12.3, INK, 'eye');
  Thick(CX(10), CY(5), CX(10), CY(20), GREEN);
  Lab(10.3, 4.2, GREEN, 'the wall, z = 40');
  if upto < 2 then Exit;

  SetColor(PEN);
  Line(CX(6), CY(8), CX(14), CY(18));
  Dot(CX(6), CY(8), PEN);
  Dot(CX(14), CY(18), PEN);
  Lab(0.9, 6.2, PEN, 'P0 ( x -80, z -40 )');
  Lab(0.9, 7.2, GREY, 'behind the eye');
  Lab(14.4, 18.2, PEN, 'P1 ( 120, 120 )');
  Axis(CX(6), CY(8), CX(6), CY(12), PENCIL, True);
  Axis(CX(14), CY(12), CX(14), CY(18), PENCIL, True);
  Axis(CX(6), CY(8), CX(8), CY(8), PENCIL, True);
  Axis(CX(8), CY(18), CX(14), CY(18), PENCIL, True);
  Lab(4.4, 12.3, GREY, '-40');  Lab(13.6, 11.2, GREY, '120');
  Lab(8.3, 7.6, GREY, '-80');   Lab(8.3, 18.2, GREY, '120');
  if upto < 3 then Exit;

  SetColor(GREY);
  Line(CX(6), CY(8), CX(10), CY(13));
  Dot(CX(6), CY(8), GREY);
  Lab(0.9, 9.2, GREY, 'thrown away');
  Dot(CX(10), CY(13), REDPEN);
  Lab(10.4, 13.2, REDPEN, 'the cut ( 20, 40 )');
  Lab(20.6, 4.2, PEN, 'CLIPP0:');
  Lab(20.6, 5.4, INK, 'tnum = NEARZ - z0');
  Lab(20.6, 6.4, INK, '     = 40 - (-40) = 80');
  Lab(20.6, 7.6, INK, 'tden = z1 - z0');
  Lab(20.6, 8.6, INK, '     = 120 - (-40) = 160');
  Lab(20.6, 9.8, INK, 'x0 += (x1 - x0) * tnum / tden');
  Lab(20.6, 10.8, INK, '    = 200 * 80 / 160');
  Lab(20.6, 11.8, INK, '    = 16000 / 160 = 100');
  Lab(20.6, 13, INK, 'x0 = -80 + 100 =');
  Lab(29.4, 13, REDPEN, '20');
  Ring(29.2, 13, 1.4);
  Lab(20.6, 14.4, INK, 'z0 = 40. Assigned, not');
  Lab(20.6, 15.4, INK, 'computed: on the wall exactly.');
  if upto < 4 then Exit;

  Lab(20.6, 17, INK, 'IMUL word, then IDIV word.');
  Lab(20.6, 18, INK, '16000 is a 32-bit product in');
  Lab(20.6, 19, INK, 'DX:AX, and IDIV takes it back');
  Lab(20.6, 20, INK, 'whole. Exact. No fixed point,');
  Lab(20.6, 21, INK, 'no shift, nothing rounded.');
  Lab(20.6, 22.4, GREY, 'y the same way. Both ends at');
  Lab(20.6, 23.4, GREY, 'y = -6, so the cut is at -6.');
  if upto < 5 then Exit;

  SetColor(PENCIL);
  Line(CX(0.9), CY(24.2), CX(35), CY(24.2));
  Lab(0.9, 24.6, INK, 'and lesson 0F''s divide, on the cut:');
  Lab(0.9, 25.6, INK, 'sx = 160 + x * 220 / z = 160 + 20 * 220 / 40 = 160 + 110 =');
  Lab(29.6, 25.6, REDPEN, '270');
  Ring(29.4, 25.6, 1.8);
  Lab(0.9, 26.6, INK, 'sy = 100 - y * 220 / z = 100 - (-6) * 220 / 40 = 100 + 33 = 133');
  Lab(0.9, 27.8, REDPEN, 'the cut lands on the glass at ( 270, 133 ).');
  Lab(0.9, 28.8, GREY, 'and P1: 160 + 120 * 220 / 120 = 380. Off the glass: the next fence.');
end;

{ ==========================================================================
   PAGE 6 - why not just divide. The same P0, not cut, worked: +440, and
   the point lands on the wrong side. Then the number that stops the
   machine, and the trap that catches it.
   ========================================================================== }
procedure PageTrap(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'why not just divide');
  Lab(0.9, 2.3, REDPEN, 'the same P0, not cut: x = -80, z = -40. Two cells behind your eye.');
  Lab(0.9, 4, INK, 'sx = 160 + ( -80 * 220 ) / ( -40 )');
  Lab(0.9, 5, INK, '   = 160 + ( -17600 / -40 )');
  Lab(0.9, 6, INK, '   = 160 + 440 =');
  Lab(9.4, 6, REDPEN, '600');
  Ring(9.2, 6, 1.8);
  Lab(0.9, 7.6, INK, 'A point on your LEFT, behind you. The machine puts it on the RIGHT,');
  Lab(0.9, 8.6, INK, 'in front. A wrong number - not an error. Nothing stops.');
  Thick(CX(2), CY(10.5), CX(10), CY(10.5), GREEN);
  Thick(CX(10), CY(10.5), CX(10), CY(15.5), GREEN);
  Thick(CX(10), CY(15.5), CX(2), CY(15.5), GREEN);
  Thick(CX(2), CY(15.5), CX(2), CY(10.5), GREEN);
  Lab(2, 15.9, GREY, 'the glass: 1 cell = 40, 8 x 5');
  Dashed(CX(10), CY(12.2), CX(17), CY(12.2), PENCIL);
  Dot(CX(17), CY(12.2), REDPEN);
  Lab(17.4, 11.6, REDPEN, '600 - and mirrored');
  Lab(17.4, 12.6, GREY, 'seven cells off the glass');
  if upto < 2 then Exit;

  Lab(0.9, 18, INK, 'now z = -1 and x = -200:  -200 * 220 = -44000.  -44000 / -1 = 44000.');
  Lab(0.9, 19, INK, 'AX holds 32767 at most. The quotient does not fit.');
  Lab(0.9, 20.2, REDPEN, 'INT 0.');
  Ring(0.7, 20.2, 3);
  Lab(4.8, 20.2, INK, 'And z = 0 is a divide by nought: INT 0. One interrupt for both.');
  if upto < 3 then Exit;

  SetColor(GREY);
  Rectangle(CX(0.9), CY(22), CX(16.5), CY(27.2));
  Lab(1.4, 22.4, GREY, 'DOS''s handler:');
  Lab(1.4, 23.6, GREY, 'prints a line, in text mode,');
  Lab(1.4, 24.6, GREY, 'takes the program away.');
  Lab(1.4, 25.8, GREY, 'stage 3 is a black screen.');
  SetColor(PEN);
  Rectangle(CX(17.5), CY(22), CX(35), CY(27.2));
  Lab(18, 22.4, PEN, 'TRAP0, lesson 0F''s vector:');
  Lab(18, 23.6, INK, 'mov  sp,[savesp] ; DRAWEDGE3D''s');
  Lab(18, 24.6, INK, 'inc  word [faults]');
  Lab(18, 25.6, INK, 'sti              ; INT cleared it');
  Lab(18, 26.6, INK, 'ret              ; as if it drew');
  if upto < 4 then Exit;

  Lab(0.9, 28, INK, 'DRAWEDGE3D saves SP first. The top of the stack is the return into');
  Lab(0.9, 29, REDPEN, 'GRIDC: a plain RET lands where a finished edge would. Caught, counted.');
end;
