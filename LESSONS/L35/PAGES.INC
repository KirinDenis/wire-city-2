{ ==========================================================================
   MULTIPLYING WITHOUT MUL - small things the pages share, and pages 1-3.
   ========================================================================== }

procedure LabXY(x, y: Integer; c: Integer; s: string);
begin
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(c);
  OutTextXY(x, y, s);
end;

{ a cell-sized box with a word in the middle of it: a byte, a bit }
procedure Cellbox(u, v, w: Real; c: Integer; s: string);
begin
  Box(u, v, u + w, v + 1, c);
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(CenterText, CenterText);
  SetColor(c);
  OutTextXY(CX(u + w / 2), CY(v + 0.5) + 1, s);
  SetTextJustify(LeftText, TopText);
end;

{ a bar of the meter's chart: n of them, 2000 to a cell }
procedure MBar(v: Integer; c: Integer; n: LongInt; s, ns: string);
begin
  Lab(1, v, INK, s);
  SetFillStyle(SolidFill, c);
  Bar(CX(12), CY(v) + 3, CX(12) + Round(n / 2000 * CELL), CY(v) + 13);
  LabXY(CX(12) + Round(n / 2000 * CELL) + 6, CY(v) + 4, c, ns);
end;

{ ==========================================================================
   PAGE 1 - what a multiply costs. The clocks; the paper; a frame.
   ========================================================================== }
procedure PagePrice(upto: Integer);
begin
  Big(1, 1, INK, 'WHAT A MULTIPLY COSTS');
  Lab(1, 3, REDPEN, 'Lesson 23: multiplying without MUL - and where a table pays.');
  Lab(1, 5, INK, 'An 8086 counts its time in CLOCKS, 4.77 million a second. What');
  Lab(1, 6, INK, 'one instruction costs, out of Intel''s own tables:');
  Lab(2, 8, PEN, 'MOV  AX,BX           2');
  Lab(2, 9, PEN, 'ADD  AX,BX           3');
  Lab(2, 10, PEN, 'SHL  AX,1            2');
  Lab(2, 11, PEN, 'MOV  AX,[SI+8]      17');
  Lab(19, 8, REDPEN, 'MUL  BX     118 - 133');
  Lab(19, 9, REDPEN, 'IMUL BX     128 - 154');
  Lab(19, 10, REDPEN, 'DIV  BX     144 - 162');
  Lab(19, 11, REDPEN, 'IDIV BX     165 - 184');
  if upto < 2 then Exit;

  Lab(1, 13, INK, 'Why so dear? There is no multiplier in the chip. A MUL is a small');
  Lab(1, 14, INK, 'program in its microcode, and it does what you do on paper:');
  Lab(4, 15, PEN, '     1011     11');
  Lab(4, 16, PEN, '   x 0110      6');
  Lab(4, 17, PENCIL, '     ----');
  Lab(4, 18, PEN, '     0000');
  Lab(4, 19, PEN, '    1011');
  Lab(4, 20, PEN, '   1011');
  Lab(4, 21, PEN, '  0000');
  Lab(4, 22, PENCIL, '  -------');
  Lab(4, 23, REDPEN, '  1000010     66');
  Lab(15, 18, PENCIL, 'bit 0 of 6 is 0: nothing');
  Lab(15, 19, PENCIL, 'bit 1 is 1: 11, shifted once');
  Lab(15, 20, PENCIL, 'bit 2 is 1: 11, shifted twice');
  Lab(15, 21, PENCIL, 'bit 3 is 0: nothing');
  Lab(15, 23, INK, 'a shift and an add a bit:');
  Lab(15, 24, INK, 'sixteen of them for a word');
  if upto < 3 then Exit;

  Lab(1, 26, INK, 'Lesson 22, one frame over the town: some 85 thousand MULs and');
  Lab(1, 27, INK, 'DIVs - nearly three seconds of them, before a single pixel.');
  Lab(1, 28, REDPEN, 'The 8086 multiplies the way you do on paper.');
  Ring(1, 28, 22);
end;

{ ==========================================================================
   PAGE 2 - who counts them: the trap flag, the opcode, the chart.
   ========================================================================== }
procedure PageMeter(upto: Integer);
var i : Integer;
begin
  Big(1, 1, INK, 'WHO COUNTS THEM');
  Lab(1, 3, INK, 'Reading the source cannot say: one IMUL in a loop over 2500 nodes');
  Lab(1, 4, INK, 'is 2500 IMULs. So the PROCESSOR counts them.');
  for i := 0 to 15 do
    if i = 7 then Cellbox(2 + i * 1.5, 6, 1.5, REDPEN, 'TF')
    else Cellbox(2 + i * 1.5, 6, 1.5, PENCIL, '');
  LabXY(CX(2), CY(7.2), PENCIL, 'the flags: bit 15 ... bit 0');
  LabXY(CX(12.5), CY(5.2), REDPEN, 'bit 8');
  Lab(1, 9, INK, 'TF, the TRAP FLAG. While it is 1, the CPU stops after EVERY');
  Lab(1, 10, INK, 'instruction and calls INT 1 - the way a debugger single-steps.');
  if upto < 2 then Exit;

  Lab(1, 12, INK, 'Our INT 1 reads the bytes of the instruction about to run:');
  Lab(2, 14, PEN, 'imul word [hcos]    F7  2E  lo  hi');
  Lab(2, 15, PEN, '                        2E = 00 101 110');
  Lab(2, 17, PEN, 'the middle three:   4 MUL    5 IMUL    6 DIV    7 IDIV');
  Lab(1, 19, INK, 'F6 or F7, and a middle of 4 to 7: one more. M counts one frame.');
  if upto < 3 then Exit;

  MBar(21, REDPEN, 36000, 'PITCH4, ROLL', '36000');
  MBar(22, PEN, 21800, 'ground nodes', '21800');
  MBar(23, PEN, 9000, 'PROJPT', '9000');
  MBar(24, PEN, 7900, 'the filler', '7900');
  MBar(25, PEN, 3200, 'houses', '3200');
  MBar(26, PENCIL, 2500, 'the rest', '2500');
  Lab(1, 28, PENCIL, 'MUL.COM, one frame over the town, the nose level: 80349 in all');
end;

{ ==========================================================================
   PAGE 3 - a divide that is not a divide. Four bytes; the middle two.
   ========================================================================== }
procedure PageBytes(upto: Integer);
begin
  Big(1, 1, INK, 'NOT A DIVIDE');
  Lab(1, 3, INK, 'PITCH4 turns each corner of a face by the pitch, APPLYROLL each');
  Lab(1, 4, INK, 'point of the screen by the bank. The sines are in 256ths, so:');
  Lab(2, 6, PEN, 'y'' = (y * cos - z * sin) / 256');
  Lab(1, 8, INK, 'IMUL leaves the product in DX:AX - thirty-two bits, four bytes:');
  Cellbox(6, 10, 3, PEN, 'DH');
  Cellbox(9, 10, 3, PEN, 'DL');
  Cellbox(12, 10, 3, PEN, 'AH');
  Cellbox(15, 10, 3, PEN, 'AL');
  if upto < 2 then Exit;

  SetColor(REDPEN);
  Line(CX(9), CY(11.5), CX(15), CY(11.5));
  Line(CX(9), CY(11.5), CX(9), CY(11.2));
  Line(CX(15), CY(11.5), CX(15), CY(11.2));
  LabXY(CX(19), CY(10.3), PENCIL, '/ 256: the lowest byte drops');
  Lab(7, 12, REDPEN, 'the product / 256');
  Lab(2, 14, GREEN, 'the engine:   mov  bx,256       4');
  Lab(2, 15, GREEN, '              idiv bx         165 - 184');
  Lab(2, 17, PEN, 'NOMUL.ASM:    mov  al,ah        2');
  Lab(2, 18, PEN, '              mov  ah,dl        2');
  Lab(1, 20, INK, 'Eight of them a corner, about 18 thousand IDIVs a frame - the');
  Lab(1, 21, INK, 'biggest single cost the meter found.');
  if upto < 3 then Exit;

  Lab(1, 23, INK, 'Lesson 10 did this to ROTXZ. And the same one difference:');
  Lab(2, 25, PEN, '-300 / 256:   IDIV  -1, toward zero     the bytes  -2, down');
  Lab(1, 27, INK, 'A coordinate one unit lower, sometimes: a pixel, sometimes.');
  Lab(1, 28, REDPEN, 'The cheapest divide is the one that was never a divide.');
  Ring(1, 28, 28);
end;
