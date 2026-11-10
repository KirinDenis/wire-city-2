{ ==========================================================================
   THE GAME ON THE 386 - pages 4, 5 and 6.
   ========================================================================== }

{ ==========================================================================
   PAGE 4 - the crystal and the divider. The wire from the quartz to INT 8;
   the two numbers; the two ports.
   ========================================================================== }
procedure PageChip(upto: Integer);
begin
  Big(1, 1, INK, 'THE CRYSTAL AND THE DIVIDER');
  Lab(1, 3, INK, 'Where does a tick come from? From a piece of quartz on the board.');
  Cellbox(2, 5, 7, GREEN, 'crystal');
  Cellbox(13, 5, 8, PEN, 'timer chip');
  Cellbox(25, 5, 6, GREEN, 'CPU');
  Arrow(9, 5.5, 13, 5.5, PENCIL, False);
  Arrow(21, 5.5, 25, 5.5, REDPEN, True);
  Lab(2, 6, PENCIL, '1193182 pulses');
  Lab(2, 7, PENCIL, 'a second');
  Lab(13, 6, PENCIL, 'counts down from N');
  Lab(21, 4, REDPEN, 'IRQ 0');
  Lab(25, 6, PENCIL, 'INT 8');
  Lab(1, 9, INK, 'The chip counts the pulses down from a number, and when it reaches');
  Lab(1, 10, INK, 'nothing it pulls a wire. That is all it does.');
  if upto < 2 then Exit;

  Lab(1, 12, INK, 'The BIOS loads the largest number there is. We load a smaller one:');
  Lab(2, 14, GREEN, '1193182 / 65536 = 18.2 a second      the tick of every PC');
  Lab(2, 15, PEN,   '1193182 / 16384 = 72.8 a second      the same crystal');
  Lab(1, 17, PENCIL, 'Nothing was made faster: a smaller number went into a counter.');
  Lab(1, 18, PENCIL, 'And 72.8 is about the screen''s own 70 frames a second.');
  if upto < 3 then Exit;

  Lab(1, 20, INK, 'The chip is two ports: 43h says what is coming, 40h takes the number.');
  LabXY(CX(4) + 4, CY(22) - 12, PENCIL, 'channel  low,high  square    binary');
  Cellbox(4, 22, 6, PEN, '00');
  Cellbox(10, 22, 6, PEN, '11');
  Cellbox(16, 22, 6, PEN, '011');
  Cellbox(22, 22, 6, PEN, '0');
  Lab(29, 22, REDPEN, '= 36h');
  Lab(2, 24, PEN, 'mov al,36h   out 43h,al');
  Lab(2, 25, PEN, 'mov ax,16384 out 40h,al   mov al,ah   out 40h,al');
  Lab(2, 26, PENCIL, 'low byte, then high. Nought means 65536: 16 bits cannot say it.');
  Lab(1, 28, REDPEN, 'The time is a crystal and a divider.');
  Ring(1, 28, 18);
end;

{ ==========================================================================
   PAGE 5 - the game's clock. T8 and the BIOS's share; the picture between
   the steps; what must be given back.
   ========================================================================== }
procedure PageClock(upto: Integer);
var i : Integer;
begin
  Big(1, 1, INK, 'THE GAME''S CLOCK');
  Lab(1, 3, INK, 'INT 8 is ours now, and the BIOS still needs its 18.2. So:');
  for i := 0 to 7 do
  begin
    if (i and 3) = 3 then
      Cellbox(3 + i * 3, 5, 3, REDPEN, 'BIOS')
    else
      Cellbox(3 + i * 3, 5, 3, GREEN, 'ours');
  end;
  Lab(2, 7, PEN, 'inc  word [cs:clk]       ; every tick, whatever was running');
  Lab(2, 8, PEN, 'test byte [cs:clk],3     ; low two bits nought: every fourth');
  Lab(2, 9, GREEN, 'three of four: out 20h,20h - "done" - and IRET');
  Lab(2, 10, REDPEN, 'the fourth:    jmp to the BIOS''s INT 8. It says "done" itself');
  Lab(1, 11, PENCIL, 'TICK printed it: 91 ticks of the BIOS, 364 of ours, in five seconds.');
  if upto < 2 then Exit;

  Lab(1, 13, INK, 'The physics stays on 18.2: all its numbers are "a tick". What does');
  Lab(1, 14, INK, 'a frame show between two steps? Until now: the same place, again.');
  SetColor(PENCIL);
  Line(CX(5), CY(17), CX(29), CY(17));
  for i := 0 to 4 do
  begin
    Line(CX(5 + i * 6), CY(16.6), CX(5 + i * 6), CY(17.4));
  end;
  Lab(4, 15, PEN, 'OLD');
  Lab(28, 15, PEN, 'NEW');
  Lab(5, 17, PENCIL, 'f = 0');
  Lab(11, 17, PENCIL, 'f = 1');
  Lab(17, 17, PENCIL, 'f = 2');
  Lab(23, 17, PENCIL, 'f = 3');
  Lab(2, 19, PEN, 'f = clk - lasttk * 4           our ticks since the last step');
  Lab(2, 20, PEN, 'shown = OLD + (NEW - OLD) * f / 4');
  Lab(1, 21, PENCIL, 'One step behind, and every frame moves. The physics never sees it.');
  if upto < 3 then Exit;

  Lab(1, 23, INK, 'And the chip is not ours. QUIT writes the old number back and');
  Lab(1, 24, INK, 'returns the vector - or the machine goes on ticking four times too');
  Lab(1, 25, INK, 'fast, into a routine that is no longer there.');
  Lab(2, 26, PEN, 'mov al,36h  out 43h,al  xor al,al  out 40h,al  out 40h,al');
  Lab(1, 28, REDPEN, 'Take the wire, and give it back.');
  Ring(1, 28, 16);
end;

{ ==========================================================================
   PAGE 6 - eighths of a step. A whole step is 5.4 pixels; the eighths the
   physics always kept; the sine between two of the table's.
   ========================================================================== }
procedure PageEighth(upto: Integer);
begin
  Big(1, 1, INK, 'EIGHTHS OF A STEP');
  Lab(1, 3, INK, 'A turn is counted in steps, 256 to the circle. On the screen one');
  Lab(1, 4, INK, 'step is 220 * tan(360/256) = 5.4 pixels. Turn half a step a tick:');
  Lab(2, 6, PENCIL, 'tick         1      2      3      4      5');
  Lab(2, 7, PEN,    'heading     40     40     41     41     42');
  Lab(2, 8, PEN,    'the world    0      0    5.4      0    5.4   pixels sideways');
  Lab(1, 10, INK, 'It jumps, stands, and jumps. And between 40 and 41 there is no');
  Lab(1, 11, INK, 'whole number: OLD + (NEW - OLD) * f / 4 is 40 all the way.');
  if upto < 2 then Exit;

  Lab(1, 13, INK, 'So the picture counts in EIGHTHS: 2048 to the circle, 0.7 pixels.');
  Lab(1, 14, INK, 'The physics always had them: what did not make a step waits in hfrac.');
  Cellbox(4, 16, 14, PEN, 'heading');
  Cellbox(18, 16, 6, GREEN, 'hfrac');
  Lab(25, 16, PEN, '= eighths, 0..2047');
  Lab(4, 17, PENCIL, 'whole steps, 0..255');
  Lab(18, 17, PENCIL, '0..7');
  Lab(2, 19, PEN, 'shl  ax,3          ; heading * 8: three bits of room');
  Lab(2, 20, PEN, 'add  ax,[hfrac]    ; + the eighths that were waiting');
  if upto < 3 then Exit;

  Lab(1, 22, INK, 'The table has a sine for every whole step. An eighth falls between');
  Lab(1, 23, INK, 'two of them, and there a sine is as good as a straight line:');
  Lab(2, 24, PEN, 's = s0 + (s1 - s0) * (a and 7) / 8       the / 8 is SAR 3');
  Lab(1, 26, PENCIL, 'And the old place is kept before EVERY step of the physics: a');
  Lab(1, 27, PENCIL, 'frame that owes two steps starts from the right one.');
  Lab(1, 28, REDPEN, 'A step is 5.4 pixels: draw in eighths.');
  Ring(1, 28, 19);
end;
