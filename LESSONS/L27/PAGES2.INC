{ ==========================================================================
   PAGE 5 - the red lines are numbers PHYS already has. A height tape, one
   cell to 50, the pointer at 1000; then what the model does not have.
   ========================================================================== }
procedure PageRed(upto: Integer);
var m : Integer;
    v : Real;
begin
  Big(1, 1, INK, 'RED LINES: WHERE THE LIMITS ARE');
  Thick(CX(6), CY(5), CX(6), CY(25), PEN);
  m := 550;
  while m <= 1450 do
  begin
    v := 15 - (m - 1000) / 50;
    SetColor(PEN);
    if m mod 100 = 0 then
    begin
      Line(CX(6), CY(v), CX(7.2), CY(v));
      LabXY(CX(7.6), CY(v) - 3, PEN, IStr(m));
    end
    else Line(CX(6), CY(v), CX(6.6), CY(v));
    Inc(m, 50);
  end;
  Arrow(1.5, 15, 5.6, 15, PEN, True);
  LabXY(CX(1), CY(15) - 14, PEN, '1000');
  Thick(CX(6), CY(8), CX(9.5), CY(8), REDPEN);
  Thick(CX(6), CY(21), CX(9.5), CY(21), REDPEN);
  Lab(12, 7, REDPEN, 'THE CEILING: camymax, set at the boot -');
  Lab(12, 8, INK, 'the tallest ground on the island + 1200');
  Lab(12, 20, REDPEN, 'THE FLOOR: the ground under you + 48 -');
  Lab(12, 21, INK, 'the height at which PHYS calls CRASH.');
  Lab(12, 22, INK, 'Not where the grass is: where the flight ends.');
  if upto < 2 then Exit;

  Lab(12, 11, REDPEN, 'THE STALL, on the speed tape: VSTALL, 300');
  Lab(12, 13, INK, 'Each red line is a number PHYS already');
  Lab(12, 14, INK, 'compares against. The tape only shows WHERE');
  Lab(12, 15, INK, 'it is - before you get there.');
  if upto < 3 then Exit;

  Lab(1, 25, INK, 'STILL NOT HONEST, AND SAID SO:');
  Lab(1, 26, PEN, 'no gravity: hands off and upside down, a real meter reads -1, ours 1');
  Lab(1, 27, PEN, 'no wing: no angle of attack; the stall is a line that never moves');
  Lab(1, 28, REDPEN, 'Next lesson: lift, the angle of attack, a stall that moves with G.');
end;

{ ==========================================================================
   PAGE 6 - rings first, then ink. A spine and one tick, in the game's own
   pixels, a cell each: drawn one bar at a time, and drawn in two passes.
   Then BAR's trap: DX comes back nought.
   ========================================================================== }
procedure Spine(du: Integer; c: Integer);
var r : Integer;
begin
  for r := 6 to 14 do Pix1(du + 6, r, c);
end;

procedure Tick(du: Integer; c: Integer);
var x : Integer;
begin
  for x := 3 to 5 do Pix1(du + x, 10, c);
end;

procedure SpineRing(du: Integer);
begin
  FBox(du + 5, 5, du + 8, 16, RINGG, RINGG);
end;

procedure TickRing(du: Integer);
begin
  FBox(du + 2, 9, du + 7, 12, RINGG, RINGG);
end;

procedure PageRings(upto: Integer);
begin
  Big(1, 1, INK, 'RINGS FIRST, THEN THE INK');
  Lab(1, 3, INK, 'Every bar is drawn with a ring a pixel round it - lesson 1A''s ring.');
  SpineRing(0);  Spine(0, PEN);
  TickRing(0);   Tick(0, PEN);
  Lab(1, 17, PEN, 'one bar at a time:');
  Lab(1, 18, REDPEN, 'the tick''s ring bites the spine');
  if upto < 2 then Exit;

  SpineRing(18);  TickRing(18);
  Spine(18, PEN); Tick(18, PEN);
  Lab(20, 17, PEN, 'every ring, then every ink:');
  Lab(20, 18, GREEN, 'the spine stays whole');
  Lab(1, 20, INK, 'So TAPES runs twice: pass 0 paints every bar a pixel bigger, in');
  Lab(1, 21, INK, 'grey; pass 1 paints the bars and the numbers. Lesson 16''s painter''s');
  Lab(1, 22, INK, 'order - nothing tested, only an order.');
  if upto < 3 then Exit;

  Lab(1, 24, PEN, 'THE TRAP: BAR counts DX down to nought. A second BAR that trusted');
  Lab(1, 25, PEN, 'DX began at 0 - and DEC DX is FFFFh: 65536 rows, round the buffer,');
  Lab(1, 26, PEN, 'stripes down the whole screen.');
  Lab(1, 28, REDPEN, 'Set CX and DX before every call.');
  Ring(1, 28, 16);
end;

{ ==========================================================================
   PAGE 7 - the glass upside down. One pane, upright and inverted, and the
   test that flattened it; then the lesson in one line.
   ========================================================================== }
procedure PageGlass(upto: Integer);
begin
  Big(1, 1, INK, 'UPSIDE DOWN, THE GLASS SLID');
  Lab(1, 3, INK, 'A pane too thin for a row gets one row. The test was "is the top');
  Lab(1, 4, INK, 'NOT above the bottom?" - true for a thin pane, upright.');
  FBox(4, 7, 10, 11, PEN, PEN);
  LabXY(CX(10.5), CY(7) - 3, PENCIL, 'top');
  LabXY(CX(10.5), CY(11) - 3, PENCIL, 'bottom');
  Lab(3, 13, PEN, 'upright: top above');
  FBox(21, 7, 27, 11, PENCIL, PENCIL);
  FBox(21, 6, 27, 7, REDPEN, REDPEN);
  LabXY(CX(27.5), CY(7) - 3, PENCIL, 'bottom');
  LabXY(CX(27.5), CY(11) - 3, PENCIL, 'top');
  Lab(20, 13, PEN, 'upside down: top BELOW -');
  Lab(20, 14, REDPEN, 'flattened to one row');
  if upto < 2 then Exit;

  Lab(2, 17, PEN, 'cmp  [PY+2],ax');
  Lab(2, 18, PEN, 'jl   .h1          ; was: top above? leave it');
  Lab(2, 19, GREEN, 'jne  .h1          ; now: not on the same row? leave it');
  Lab(2, 21, INK, 'Right while the aeroplane flew upright, wrong since lesson 19.');
  Lab(2, 22, INK, 'The houses and the horizon were fine; only the glass slid.');
  if upto < 3 then Exit;

  Lab(2, 25, INK, 'Tapes, the IVV, the G, red lines - all read out of PHYS.');
  Lab(2, 27, REDPEN, 'A number becomes a place.');
  Ring(2, 27, 13);
end;
