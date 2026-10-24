{ ==========================================================================
   PAGE 4 - half the work, and square pixels. The mirror in the x axis;
   pixels taller than wide; black, the colour that never turns.
   ========================================================================== }
procedure PageHalf(upto: Integer);
begin
  Big(1, 1, INK, 'HALF THE WORK');
  Dashed(CX(2), CY(9), CX(20), CY(9), PENCIL);
  LabXY(CX(20.3), CY(9) - 3, PENCIL, 'x');
  SetColor(PEN);
  Circle(CX(13), CY(9), 3 * CELL);
  Circle(CX(8.6), CY(9), Round(1.4 * CELL));
  Dot(CX(17), CY(6.5), REDPEN);
  Dot(CX(17), CY(11.5), REDPEN);
  Dashed(CX(17), CY(6.5), CX(17), CY(11.5), REDPEN);
  LabXY(CX(17.4), CY(6.5) - 4, REDPEN, 'row r');
  LabXY(CX(17.4), CY(11.5) - 4, REDPEN, 'row 199 - r');
  Lab(23, 4, INK, 'The set is its own');
  Lab(23, 5, INK, 'reflection in the x');
  Lab(23, 6, INK, 'axis. 100 rows are');
  Lab(23, 7, INK, 'worked out, and 200');
  Lab(23, 8, INK, 'written: half the work.');
  Lab(1, 14, PEN, 'cy = (r - 100) x 54 + 27: half a step off the axis, so row r and');
  Lab(1, 15, PEN, 'row 199 - r are exactly opposite.');
  if upto < 2 then Exit;

  Box(3, 17.5, 5, 19.9, PEN);
  LabXY(CX(3.6), CY(20.1), PENCIL, '1');
  LabXY(CX(5.3), CY(18.4), PENCIL, '1.2');
  Lab(8, 17, INK, 'Mode 13h spreads 320 x 200 over a 4:3 screen:');
  Lab(8, 18, INK, 'a pixel stands 1.2 times taller than it is wide.');
  Lab(8, 19, PEN, 'XSTEP = 45, YSTEP = 54 = 1.2 x 45 - and the set');
  Lab(8, 20, PEN, 'comes out round, not squashed.');
  if upto < 3 then Exit;

  Lab(1, 23, INK, 'Home after 128 steps: number 0. The turning writes entries 1 to');
  Lab(1, 24, INK, '128 and never 0 - the set stays black while all round it flows.');
  Lab(1, 27, REDPEN, 'Black is the one colour the turning never touches.');
  Ring(1, 27, 25);
end;

{ ==========================================================================
   PAGE 5 - the bill. The picture against a thousand turns, both on the
   BIOS clock; what the DOS games did with it.
   ========================================================================== }
procedure PageBill(upto: Integer);
begin
  Big(1, 1, INK, 'THE BILL');
  Lab(1, 3, INK, 'THE PICTURE: 64000 pixels, 32000 worked out, up to 128 steps each,');
  Lab(1, 4, INK, 'three IMULs a step - and the screen fills a row at a time.');
  Lab(1, 6, PEN, 'At the foot of the screen, in ticks of the BIOS clock at 0040:006C,');
  Lab(1, 7, PEN, '18.2 a second. On the course page: about 170 ticks, nine seconds.');
  if upto < 2 then Exit;

  Lab(1, 10, INK, 'ONE TURN of the palette: 385 OUTs. A thousand turns: about 60 ticks');
  Lab(1, 11, INK, '- one turn is 3.3 ms, under a quarter of one 70 Hz picture.');
  Lab(1, 13, REDPEN, 'One picture costs as much as three thousand turns.');
  Ring(1, 13, 25);
  if upto < 3 then Exit;

  Lab(1, 16, INK, 'Drawn once, moved by the DAC: water, fire, lights that run along a');
  Lab(1, 17, INK, 'runway, a nozzle that burns - the trick of the DOS games and demos.');
  Lab(1, 19, GREEN, 'R draws the picture again: watch the bill paid a second time.');
  Lab(1, 22, REDPEN, 'A pixel is a number. The colour lives in the DAC.');
  Ring(1, 22, 25);
  Lab(1, 25, INK, 'Next lesson: the aeroplanes of the hangar, in the sky.');
end;
