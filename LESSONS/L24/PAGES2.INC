{ ==========================================================================
   PAGE 5 - the wind. The nose points north, the air carries the aeroplane
   east and south, and the path over the ground is the sum: a triangle of
   arrows. Then how the wind dies near the ground, and where it goes in the
   code. Scale of the triangle: 11.5 units a tick is 20 cells.
   ========================================================================== }
procedure PageWind(upto: Integer);
begin
  Big(1, 1, INK, 'THE WIND');
  FBox(1, 3, 35, 24, SKYW, SKYW);
  Arrow(8, 24, 8, 4, PEN, True);              { the nose: 11.5 north = 20 cells }
  Lab(1, 12, PEN, 'THE NOSE');
  Lab(1, 13, PEN, '11.5 north');
  if upto < 2 then Exit;

  Arrow(8, 4, 11.5, 5.7, GREEN, True);        { the wind: 2 east, 1 south }
  Lab(13, 4, GREEN, 'THE WIND: 2 east, 1 south');
  Arrow(8, 24, 11.5, 5.7, REDPEN, True);      { the path over the ground }
  Lab(13, 9, REDPEN, 'THE TRACK: where it really');
  Lab(13, 10, REDPEN, 'goes over the ground');
  Lab(1, 25, INK, 'The aeroplane flies in the air, and the air is moving. Point the');
  Lab(1, 26, INK, 'nose at a town and it drifts past it: the wind is added to the step.');
  if upto < 3 then Exit;

  { how strong, by height: nothing at the ground, all of it at 512 }
  Axis(CX(22), CY(22), CX(34), CY(22), PENCIL, False);
  Axis(CX(22), CY(22), CX(22), CY(14), PENCIL, False);
  Thick(CX(22), CY(22), CX(30), CY(15), PEN);
  Thick(CX(30), CY(15), CX(34), CY(15), PEN);
  Lab(23, 23, PENCIL, 'height  512');
  Lab(23, 13, PENCIL, 'the wind');
  Lab(1, 27, REDPEN, 'wdx += WINDX x agl / 2 - in 256ths, so lesson 17''s ADC');
  Lab(1, 28, REDPEN, 'carries a quarter of a unit a tick, and nothing is lost.');
  Ring(1, 28, 28);
end;

{ ==========================================================================
   PAGE 6 - the clock. A crystal, a divider, a count in memory; frames
   against ticks on one second of paper; and the subtraction on a circle.
   The ruler: one second is 32 cells, from cell 2 to cell 34.
   ========================================================================== }
procedure PageClock(upto: Integer);
var k : Integer;
begin
  Big(1, 1, INK, 'THE CLOCK');
  FBox(1, 4, 8, 7, PAPER, PEN);
  Lab(2, 5, PEN, '1.193182');
  Lab(2, 6, PEN, 'MHz');
  Arrow(8, 5.5, 11, 5.5, PEN, False);
  FBox(11, 4, 20, 7, PAPER, PEN);
  Lab(12, 5, PEN, '8253 timer');
  Lab(12, 6, PEN, '/ 65536');
  Arrow(20, 5.5, 23, 5.5, PEN, False);
  FBox(23, 4, 35, 7, PAPER, PEN);
  Lab(24, 5, PEN, '18.2 a second:');
  Lab(24, 6, PEN, '0040:006C += 1');
  Lab(1, 9, INK, '1193182 / 65536 = 18.2. The BIOS counts it whatever the program');
  Lab(1, 10, INK, 'is doing: a clock that does not care how fast the picture is.');
  if upto < 2 then Exit;

  Axis(CX(2), CY(16), CX(34), CY(16), PENCIL, False);
  Lab(2, 13, PEN, 'FRAMES, 23 a second');
  for k := 0 to 23 do
    Axis(CX(2 + k * 32 / 23), CY(14.5), CX(2 + k * 32 / 23), CY(16), PEN, False);
  Lab(2, 18, GREEN, 'TICKS, 18 a second');
  for k := 0 to 18 do
    Thick(CX(2 + k * 32 / 18.2), CY(16), CX(2 + k * 32 / 18.2), CY(17.5), GREEN);
  Lab(1, 20, INK, 'Each frame runs the physics once for every tick since the last');
  Lab(1, 21, INK, 'one: usually 1, now and then 0, after a slow frame 2. Up to');
  Lab(1, 22, INK, 'lesson 17 the frame WAS the step - 23 a second over a field and');
  Lab(1, 23, INK, '14 over a town. Now a second is a second, over anything.');
  if upto < 3 then Exit;

  Lab(1, 25, PEN, 'owed = tick - lasttk:  2 - 65534 = 4  in sixteen bits.');
  Lab(1, 26, INK, 'The count wraps, and the SUB wraps with it: the clock is a circle.');
  Lab(1, 28, REDPEN, 'At most MAXSTEP = 6 owed: a stall is forgotten, not paid.');
  Ring(1, 28, 29);
end;

{ ==========================================================================
   PAGE 7 - the numbers on the screen, and the honest list of what the
   model leaves out.
   ========================================================================== }
procedure PageNumbers(upto: Integer);
begin
  Big(1, 1, INK, 'THE NUMBERS');
  FBox(1, 4, 12, 10, SKYW, PEN);
  Lab(2, 5, INK, 'THR 100%');
  Lab(2, 6, INK, 'SPD  736');
  Lab(2, 7, INK, 'ALT  645');
  Lab(2, 8, INK, 'HDG 000');
  Lab(14, 5, PEN, 'throttle 0..64 x 25 / 16 = per cent');
  Lab(14, 6, PEN, 'vel itself: vel/64 is units a tick');
  Lab(14, 7, PEN, 'camy itself: height over the sea');
  Lab(14, 8, PEN, 'heading 0..255 x 45 / 32 = degrees');
  Lab(14, 10, GREEN, '360/256 = 45/32: one MUL, one shift');
  if upto < 2 then Exit;

  Lab(1, 12, INK, 'NUMOUT: DIV by ten hands the digits over LAST FIRST.');
  Lab(3, 14, PEN, '736 / 10 =  73  remainder 6');
  Lab(3, 15, PEN, ' 73 / 10 =   7  remainder 3');
  Lab(3, 16, PEN, '  7 / 10 =   0  remainder 7');
  Lab(22, 15, REDPEN, '"SPD  736"');
  Arrow(18, 15, 21.5, 15, REDPEN, False);
  Lab(1, 18, INK, 'So they are written right to left. DIV divides DX:AX - DX must');
  Lab(1, 19, INK, 'be nought first, or the quotient overflows and faults.');
  if upto < 3 then Exit;

  Lab(1, 21, REDPEN, 'WHAT THIS MODEL LEAVES OUT, on purpose:');
  Lab(2, 23, INK, 'drag grows with the speed; a real one with its SQUARE');
  Lab(2, 24, INK, 'no wing, no lift: a climb is paid for out of speed');
  Lab(2, 25, INK, 'the air thins in a straight line, not exponentially');
  Lab(2, 26, INK, 'the picture does not pitch: the nose is in the numbers');
  Lab(1, 28, REDPEN, 'Cheaper, and it flies better. Tuned for a pilot, not a tunnel.');
  Ring(1, 28, 31);
end;
