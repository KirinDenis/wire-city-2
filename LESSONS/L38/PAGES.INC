{ ==========================================================================
   THE GAME ON THE 386 - small things the pages share, and pages 1-3.
   ========================================================================== }

procedure LabXY(x, y: Integer; c: Integer; s: string);
begin
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(c);
  OutTextXY(x, y, s);
end;

{ a box with a word in the middle of it: a byte, a field, a chip }
procedure Cellbox(u, v, w: Real; c: Integer; s: string);
begin
  Box(u, v, u + w, v + 1, c);
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(CenterText, CenterText);
  SetColor(c);
  OutTextXY(CX(u + w / 2), CY(v + 0.5) + 1, s);
  SetTextJustify(LeftText, TopText);
end;

{ ==========================================================================
   PAGE 1 - the flight of lesson 23 on the 386: the five things that are
   new, the one path, and what did not move.
   ========================================================================== }
procedure PageGame(upto: Integer);

  procedure Row(v: Integer; what, does: string);
  begin
    Lab(2, v, PEN, what);
    Lab(11, v, INK, does);
  end;

begin
  Big(1, 1, INK, 'THE GAME ON THE 386');
  Lab(1, 3, REDPEN, 'Lesson 26: the flight, in double words, on a clock of its own.');
  Lab(1, 5, INK, 'One file, CLOCK.ASM, and five things are new in it:');
  Row(7,  'NEED386',  'the first line asks: lesson 24''s verdict');
  Row(8,  'SPANFILL', 'every fill, four pixels a write');
  Row(9,  'SCANPOLY', 'every polygon, one divide an edge');
  Row(10, 'TIMERON',  'the timer chip at 72.8 ticks a second');
  Row(11, 'FINEANG',  'the picture turns in eighths of a step');
  if upto < 2 then Exit;

  Lab(1, 12, INK, 'There is one path through this program: the fast one.');
  Lab(2, 14, GREEN, 'E_8086.INC   gone: this is 386 code now');
  Lab(2, 15, GREEN, 'the F key    gone: no slower way to go back to');
  Lab(2, 16, GREEN, 'the meter    gone: lesson 23''s counter did its job');
  if upto < 3 then Exit;

  Lab(1, 18, INK, 'What stays: the island, the aeroplane, the keys, and every number');
  Lab(1, 19, INK, 'in the physics. A tick of the forces is still 1/18.2 of a second.');
  Lab(1, 21, PENCIL, 'Two small programs: TICK, the timer chip on its own - and CLOCK,');
  Lab(1, 22, PENCIL, 'the flight with all of it in.');
  Lab(1, 28, REDPEN, 'The same flight, faster and smoother.');
  Ring(1, 28, 18);
end;

{ ==========================================================================
   PAGE 2 - four pixels a write. REP STOSD on the sky; why a double word
   wants an address divisible by 4; a span in three parts.
   ========================================================================== }
procedure PageFour(upto: Integer);
var i : Integer;
begin
  Big(1, 1, INK, 'FOUR PIXELS A WRITE');
  Lab(1, 3, INK, 'A pixel of mode 13h is a byte. A double word is four of them.');
  Lab(2, 5, GREEN, 'lesson 23:  mov  al,SKY            mov  cx,64000   rep stosb');
  Lab(2, 6, PEN,   'this one:   mov  eax,SKY*01010101h mov  cx,16000   rep stosd');
  Lab(1, 8, INK, 'The colour four times in EAX, a quarter of the writes. The same');
  Lab(1, 9, INK, 'for the frame going to the screen: REP MOVSD, 16000 of them.');
  if upto < 2 then Exit;

  Lab(1, 11, INK, 'Memory is wired in rows of four bytes, and the 386 has 32 data');
  Lab(1, 12, INK, 'wires. A double word that starts on a row is ONE trip. One that');
  Lab(1, 13, INK, 'crosses two rows is two.');
  for i := 0 to 7 do
    Box(4 + i * 2, 15, 6 + i * 2, 16, PENCIL);
  SetColor(PENCIL);
  SetLineStyle(SolidLn, 0, ThickWidth);
  Line(CX(12), CY(14.7), CX(12), CY(16.3));
  SetLineStyle(SolidLn, 0, NormWidth);
  Lab(4, 16, PEN, 'address 100');
  Lab(12, 16, PEN, 'address 104');
  FBox(8, 15, 16, 16, GREEN, GREEN);
  Lab(22, 15, GREEN, 'crosses the line:');
  Lab(22, 16, GREEN, 'two trips');
  if upto < 3 then Exit;

  Lab(1, 18, INK, 'A span of a polygon starts anywhere. So it comes in three parts:');
  Cellbox(4, 20, 6, GREEN, 'STOSB');
  Cellbox(10, 20, 14, PEN, 'REP STOSD');
  Cellbox(24, 20, 6, GREEN, 'REP STOSB');
  Lab(4, 21, PENCIL, 'up to 3');
  Lab(10, 21, PENCIL, 'whole double words');
  Lab(24, 21, PENCIL, 'the last 0 to 3');
  Lab(2, 23, PEN, 'test di,3        ; DI divisible by 4? Its low two bits say');
  Lab(2, 24, PEN, 'shr  cx,2        ; pixels into double words: / 4');
  Lab(2, 25, PEN, 'and  cx,3        ; what was left over: mod 4');
  Lab(1, 28, REDPEN, 'A row of memory is four bytes: write on the row.');
  Ring(1, 28, 24);
end;

{ ==========================================================================
   PAGE 3 - one divide an edge. The straight line; 16.16 in a double word;
   the list of rows.
   ========================================================================== }
procedure PageEdge(upto: Integer);
var i : Integer;
begin
  Big(1, 1, INK, 'ONE DIVIDE AN EDGE');
  Lab(1, 3, INK, 'The filler stopped at every row and asked every edge where it was:');
  Lab(2, 4, GREEN, 'x = x0 + dx * (y - y0) / dy     an IMUL and an IDIV, row after row');
  { the edge, crossing the rows }
  SetColor(PENCIL);
  for i := 0 to 4 do
    Line(CX(26), CY(6 + i), CX(35), CY(6 + i));
  SetLineStyle(SolidLn, 0, ThickWidth);
  SetColor(PEN);
  Line(CX(27), CY(6), CX(33), CY(10));
  SetLineStyle(SolidLn, 0, NormWidth);
  Lab(1, 6, INK, 'But an edge is a straight line. From row to row');
  Lab(1, 7, INK, 'its x moves by the same amount, all the way down:');
  Lab(2, 9, PEN, 'step = dx / dy     ONCE, for the edge');
  Lab(2, 10, PEN, 'x = x + step       every row after that');
  if upto < 2 then Exit;

  Lab(1, 12, INK, 'The step is a fraction: 3 pixels in 10 rows is 0.3 a row. So x lives');
  Lab(1, 13, INK, 'in a double word as 16.16 - the top half pixels, the bottom 65536ths.');
  Cellbox(4, 15, 10, PEN, 'pixels');
  Cellbox(14, 15, 10, PENCIL, '65536ths of a pixel');
  Lab(25, 15, PEN, 'EAX');
  Lab(2, 17, PEN, 'step = 3 * 65536 / 10 = 19660 = 0000 4CCC');
  Lab(2, 18, PEN, 'x:  0005 0000   0005 4CCC   0005 9998   0005 E664   0006 3330');
  for i := 0 to 3 do
    LabXY(76 + i * 96, CY(19) + 4, REDPEN, '5');
  LabXY(76 + 4 * 96, CY(19) + 4, REDPEN, '6');
  Lab(1, 20, PENCIL, 'One ADD EAX,EBX moves both halves; the carry between them is free.');
  if upto < 3 then Exit;

  Lab(1, 22, INK, 'Two passes. The edges walk down and write each row''s left and right');
  Lab(1, 23, INK, 'into a list, a double word a row; then the rows are filled.');
  Cellbox(4, 25, 8, PEN, 'right');
  Cellbox(12, 25, 8, PEN, 'left');
  Lab(21, 25, PENCIL, 'at SPANS: 64000 and on, past the');
  Lab(21, 26, PENCIL, 'picture, in the buffer''s own 64K');
  Lab(1, 28, REDPEN, 'One divide an edge, then only adds.');
  Ring(1, 28, 18);
end;
