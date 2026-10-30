{ ==========================================================================
   PAGE 4 - a table pays when one factor is known in advance. The grid;
   the tables; the pitch the same way.
   ========================================================================== }
procedure PageTable(upto: Integer);
var i, j : Integer;
    x, y : Integer;
begin
  Big(1, 1, INK, 'A TABLE PAYS');
  Lab(1, 3, INK, 'TERRPREP turns all 2500 nodes of the ground by the heading:');
  Lab(2, 5, PEN, 'rc_x = wdx * cos / 256  -  wdz * sin / 256');
  Lab(2, 6, PEN, 'rc_z = wdx * sin / 256  +  wdz * cos / 256');
  for i := 0 to 6 do
    for j := 0 to 6 do
    begin
      x := CX(3 + i * 1.5);  y := CY(9 + j * 1.5);
      SetFillStyle(SolidFill, PENCIL);
      SetColor(PENCIL);
      PieSlice(x, y, 0, 360, 2);
    end;
  LabXY(CX(2.6), CY(18.4), PENCIL, 'the ground: 50 x 50 nodes');
  if upto < 2 then Exit;

  SetColor(PEN);
  SetLineStyle(SolidLn, 0, ThickWidth);
  Line(CX(6), CY(8.5), CX(6), CY(18.5));             { a column }
  Line(CX(2.5), CY(13.5), CX(12.5), CY(13.5));       { a row }
  SetLineStyle(SolidLn, 0, NormWidth);
  Lab(14, 9, PEN, 'down a COLUMN, wdx never changes:');
  Lab(14, 10, PEN, '50 different wdx in the frame');
  Lab(14, 12, PEN, 'along a ROW, wdz never changes:');
  Lab(14, 13, PEN, '50 different wdz');
  Lab(14, 15, GREEN, 'and cos and sin: one each for');
  Lab(14, 16, GREEN, 'the whole frame');
  Lab(1, 20, INK, 'So each product ONCE, into a table, at the top of the frame:');
  Lab(2, 21, PEN, 'XC[a] = wdx(a) * cos / 256    XS, ZC, ZS the same:  200 IMULs');
  Lab(2, 22, REDPEN, 'rc_x = XC[a] - ZS[b]      rc_z = XS[a] + ZC[b]    reads, adds');
  if upto < 3 then Exit;

  Lab(1, 24, INK, 'The pitch the same way: 256 map bytes, so only 256 heights, and');
  Lab(1, 25, INK, 'their products are tables too. 912 IMULs a frame instead of about');
  Lab(1, 26, INK, '21800 - and the SAME numbers, every term the same middle bytes.');
  Lab(1, 28, REDPEN, 'A table pays when one factor is known in advance.');
  Ring(1, 28, 25);
  Lab(1, 29, PENCIL, '2336 bytes of tables: a segment of their own, cs+2000h, read via ES');
end;

{ ==========================================================================
   PAGE 5 - what a table cannot do, and the meter, before and after.
   ========================================================================== }
procedure PageResult(upto: Integer);
begin
  Big(1, 1, INK, 'AND WHAT IT CANNOT');
  Lab(1, 3, INK, 'The famous one - a table of squares multiplies ANY two numbers:');
  Lab(2, 5, PEN, 'a * b = ((a+b)^2 - (a-b)^2) / 4      7 * 5 = (144 - 4) / 4 = 35');
  Lab(1, 7, INK, 'Two reads and a subtraction. But on the 8086 a read costs its');
  Lab(1, 8, INK, 'address arithmetic: about 60 clocks, where a MUL of bytes is 70.');
  Lab(1, 9, INK, 'Words take four of them: about 250, against MUL''s 118 to 133.');
  Lab(1, 10, PENCIL, 'It is for processors with no MUL at all - the 6502, the Z80.');
  if upto < 2 then Exit;

  Lab(1, 13, INK, 'The meter, one frame, the same island, the same second of flight:');
  Lab(2, 15, PENCIL, '              MUL      DIV      at 4.77 MHz');
  Lab(2, 16, GREEN, 'MUL.COM       57303    30300    about 2.8 s');
  Lab(2, 17, REDPEN, 'NOMUL.COM     36592    10650    about 1.5 s');
  Lab(1, 19, INK, 'DOSBox shows both at the same frame rate: it charges every');
  Lab(1, 20, INK, 'instruction alike. A real 8086 charges an IDIV 170 clocks.');
  if upto < 3 then Exit;

  Lab(1, 22, REDPEN, 'The costly instruction is not made faster. It is made rarer.');
  Ring(1, 22, 30);
  Lab(1, 24, PENCIL, 'NOT YET, SAID SO:');
  Lab(2, 25, PENCIL, 'PROJPT divides by a depth that is new every time: no table');
  Lab(2, 26, PENCIL, 'the filler divides once a line, an edge: the next lesson');
  Lab(2, 27, PENCIL, 'PITCH4 still turns a corner once for every face it is in');
  Lab(2, 28, PENCIL, 'the island is fixed in both, ISEED, so the meters compare');
end;
