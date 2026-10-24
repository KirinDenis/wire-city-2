{ ==========================================================================
   ONLY THE PALETTE MOVES - small things the pages share.
   ========================================================================== }

procedure Thick(x1, y1, x2, y2, c: Integer);
begin
  SetColor(c);
  SetLineStyle(SolidLn, 0, ThickWidth);
  Line(x1, y1, x2, y2);
  SetLineStyle(SolidLn, 0, NormWidth);
end;

procedure Dashed(x1, y1, x2, y2, c: Integer);
begin
  SetColor(c);
  SetLineStyle(DashedLn, 0, NormWidth);
  Line(x1, y1, x2, y2);
  SetLineStyle(SolidLn, 0, NormWidth);
end;

{ text at a PIXEL position, for labels that sit in a box and not in a row }
procedure LabXY(x, y: Integer; c: Integer; s: string);
begin
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(c);
  OutTextXY(x, y, s);
end;

procedure Dot(x, y, c: Integer);
begin
  SetFillStyle(SolidFill, c);
  SetColor(c);
  PieSlice(x, y, 0, 360, 3);
end;

{ the program's own colours live in colours 8..15, DAC 56..63 }
procedure SetDac(slot, r, g, b: Integer);
begin
  SetRGBPalette(slot + 48, r, g, b);
end;

{ rub a strip of the paper clean, squares and all, in cells }
procedure Rub(u1, v1, u2, v2: Integer);
var i : Integer;
begin
  SetFillStyle(SolidFill, PAPER);
  Bar(u1 * CELL + 1, v1 * CELL + 1, u2 * CELL - 1, v2 * CELL - 1);
  SetColor(RULE);
  for i := u1 + 1 to u2 - 1 do Line(i * CELL, v1 * CELL, i * CELL, v2 * CELL);
  for i := v1 + 1 to v2 - 1 do Line(u1 * CELL, i * CELL, u2 * CELL, i * CELL);
end;

{ the ramp's colours, one every 16 entries, into colours 8..15 - MANDEL's
  MKRAMP worked by hand: a + (b - a) x f / 32 }
procedure RampDac;
begin
  SetDac(8,  0,  0,  0);
  SetDac(9,  2,  5, 22);
  SetDac(10, 4, 10, 44);
  SetDac(11, 24, 36, 53);
  SetDac(12, 44, 63, 63);
  SetDac(13, 53, 51, 31);
  SetDac(14, 63, 40,  0);
  SetDac(15, 31, 20,  0);
end;

{ ==========================================================================
   PAGE 1 - a pixel is a number. Bytes in video memory, the DAC's table,
   the colours on the screen; then the DAC rewritten - on this very page.
   ========================================================================== }
const
  MEMV : array[0..5] of Integer = (0, 25, 25, 41, 57, 25);

function Slot(n: Integer): Integer;
begin
  case n of
    0  : Slot := 8;
    25 : Slot := 9;
    41 : Slot := 10;
  else  Slot := 11;
  end;
end;

procedure PageNumber(upto: Integer);
var k : Integer;
    s : string;
begin
  SetDac(8, 0, 0, 0);            { DAC 0, 25, 41, 57 of the ramp at phase 0 }
  SetDac(9, 3, 7, 33);
  SetDac(10, 14, 23, 48);
  SetDac(11, 34, 49, 58);
  Big(1, 1, INK, 'A PIXEL IS A NUMBER');
  Lab(1, 3, REDPEN, 'Lesson 1F. Lesson 1E''s nozzle burned, and we never said how.');
  Lab(1, 5, PEN, 'VIDEO MEMORY: a byte a pixel');
  for k := 0 to 5 do
  begin
    Box(2 + 2 * k, 6, 4 + 2 * k, 8, PEN);
    Str(MEMV[k], s);
    LabXY(CX(2 + 2 * k) + 8, CY(6) + 12, PEN, s);
  end;
  Arrow(8, 8.3, 8, 11.7, GREEN, True);
  LabXY(CX(8.5), CY(9.6), GREEN, 'the DAC looks it up');
  Lab(1, 12, PEN, 'THE SCREEN: a colour');
  for k := 0 to 5 do FBox(2 + 2 * k, 13, 4 + 2 * k, 15, Slot(MEMV[k]), INK);
  Lab(19, 5, PEN, 'THE DAC: 256 entries');
  Lab(19, 6, PENCIL, ' n    red green blue');
  Lab(19, 7, PEN, ' 0      0    0    0');
  Lab(19, 8, PEN, '25      3    7   33');
  Lab(19, 9, PEN, '41     14   23   48');
  Lab(19, 10, PEN, '57     34   49   58');
  for k := 0 to 3 do FBox(32, 7 + k + 0.15, 34, 8 + k - 0.15, 8 + k, INK);
  Lab(19, 11, PENCIL, '... and 252 more');
  if upto < 2 then Exit;

  Lab(1, 17, INK, 'The DAC: 256 entries of red, green, blue - six bits each, 0 to 63.');
  Lab(1, 18, INK, '18 bits: 262144 colours to choose from, 256 on the screen at once.');
  Lab(1, 19, GREEN, 'Read for every pixel as the beam draws it - 70 pictures a second.');
  if upto < 3 then Exit;

  Rub(19, 8, 31, 9);
  Lab(19, 8, REDPEN, '25     63   40    0');
  SetDac(9, 63, 40, 0);          { THE FACT, on the paper: nothing is drawn }
  Lab(1, 22, INK, 'Write three new bytes into entry 25, and every pixel that holds 25');
  Lab(1, 23, INK, 'is amber at once, in the next picture - on this page too: nothing');
  Lab(1, 24, INK, 'was drawn again. Lesson 1E''s nozzle was entry 94, three colours.');
  Lab(1, 27, REDPEN, 'A pixel is a number. The colour lives in the DAC.');
  Ring(1, 27, 25);
end;

{ ==========================================================================
   PAGE 2 - two ports. OUT 3C8h and 3C9h; the ramp turned by one; the
   count of OUTs, and the beam's way back.
   ========================================================================== }
procedure PagePorts(upto: Integer);
var k : Integer;
begin
  RampDac;
  Big(1, 1, INK, 'TWO PORTS');
  Lab(1, 3, INK, 'The DAC is a chip of its own. The 8086 talks to it through PORTS,');
  Lab(1, 4, INK, 'not memory: OUT writes a byte to a port number, IN reads one.');
  Lab(2, 6, PEN, 'mov  dx,3C8h     ; the DAC''s write index');
  Lab(2, 7, PEN, 'mov  al,1        ; from entry 1');
  Lab(2, 8, PEN, 'out  dx,al');
  Lab(2, 9, PEN, 'inc  dx          ; 3C9h: the colours');
  Lab(2, 10, PEN, 'out  dx,al       ; red, green, blue, red, green...');
  Lab(1, 11, GREEN, 'The DAC steps on to the next entry by itself after every three.');
  if upto < 2 then Exit;

  Lab(1, 13, PEN, 'THE RAMP, made once, 128 colours:');
  for k := 0 to 7 do FBox(2 + 4 * k, 14, 6 + 4 * k, 15.5, 8 + k, INK);
  for k := 0 to 6 do Arrow(4 + 4 * (k + 1), 15.7, 4.4 + 4 * k, 17.3, PENCIL, False);
  for k := 0 to 7 do FBox(2 + 4 * k, 17.5, 6 + 4 * k, 19, 8 + (k + 1) mod 8, INK);
  Lab(1, 19, PEN, 'TURNED BY ONE: entry k shows the ramp''s colour k + 1 -');
  Lab(1, 20, PEN, 'the colours flow left, and the first comes round to the end.');
  LabXY(CX(22), CY(13) + 4, PENCIL, 'a box here is 16 entries');
  if upto < 3 then Exit;

  Lab(1, 22, INK, 'One turn: 1 OUT for the index, and 128 x 3 for the colours -');
  Lab(1, 23, REDPEN, '385 OUTs, and the whole picture moves.');
  Ring(1, 23, 19);
  Lab(1, 25, INK, 'Only while the beam flies back to the top: bit 3 of port 3DAh, IN.');
  Lab(1, 26, INK, 'Turned in the middle of a picture, the top would show the old');
  Lab(1, 27, INK, 'colours and the bottom the new: a tear across the screen.');
end;

{ ==========================================================================
   PAGE 3 - the picture: z = z*z + c. The rule, two points worked, and
   the step in 4.12 with its double word.
   ========================================================================== }
procedure PageSet(upto: Integer);
begin
  Big(1, 1, INK, 'THE PICTURE: Z = Z*Z + C');
  Lab(1, 3, INK, 'For every pixel, a point c of the plane. Start at z = 0, and repeat:');
  Lab(3, 5, PEN, 'x'' = x*x - y*y + cx          y'' = 2*x*y + cy');
  Lab(1, 7, INK, 'Past a distance of 2 - x*x + y*y > 4 - a point never comes back.');
  Lab(1, 8, INK, 'The pixel''s number: how many steps it took to run away.');
  if upto < 2 then Exit;

  Lab(1, 11, PEN, 'c = 0.5:  0, 0.5, 0.75, 1.06, 1.63, 3.15 - away at step 6');
  Lab(1, 12, PEN, 'c = -1:   0, -1, 0, -1, 0, -1 ... home: 128 steps, black');
  Lab(1, 14, INK, 'Step 6 is colour 6 x 4 + 1 = 25. Four colours of the ramp a step:');
  Lab(1, 15, INK, 'the rings round the set are narrow - and they flow.');
  if upto < 3 then Exit;

  Lab(1, 18, PEN, '4.12 FIXED POINT: a word with 12 bits of fraction. 1.0 = 4096.');
  Lab(1, 19, PEN, 'step 6: x = 3.15 = 12916, x*x = 166823056 - 24 bits of fraction,');
  Lab(1, 20, PEN, 'not a word. IMUL leaves it in DX:AX, and DX = 2545.');
  Lab(1, 22, INK, 'Four is 4 << 24, and its high word is 1024. 2545 >= 1024: away.');
  Lab(1, 24, REDPEN, 'The test for 4 reads one word: CMP DX,1024.');
  Ring(1, 24, 22);
  Lab(1, 27, PENCIL, 'back to 4.12: (AX >> 12) OR (DX << 4) - a shift across two words');
end;
