{ ==========================================================================
   PAGE 1 - the four forces, and the two the game keeps.
   The aeroplane side on in the middle; thrust and drag along it, lift and
   weight across it. Then lift and weight are crossed out: there is no wing
   in this model, and a climb is paid for out of speed instead.
   ========================================================================== }
procedure PageForces(upto: Integer);
begin
  Big(1, 1, INK, 'THE FORCES');
  Lab(1, 3, REDPEN, 'Lesson 14: no throttle, no mass, no drag. Today they arrive.');
  Plane(14, 13);
  Arrow(21, 13, 28, 13, PEN, True);        { thrust, out of the nose }
  Lab(24, 11, PEN, 'THRUST');
  Arrow(7, 13, 2, 13, PEN, True);          { drag, out of the tail }
  Lab(2, 11, PEN, 'DRAG');
  Arrow(14, 11, 14, 6, PEN, True);         { lift, up out of the wing }
  Lab(15, 9, PEN, 'LIFT');
  Arrow(14, 15, 14, 20, PEN, True);        { weight, down }
  Lab(15, 16, PEN, 'WEIGHT');
  Lab(1, 22, INK, 'Four forces on every aeroplane. The engine pulls it forward,');
  Lab(1, 23, INK, 'the air holds it back; the wing holds it up, the earth pulls it');
  Lab(1, 24, INK, 'down.');
  if upto < 2 then Exit;

  Thick(CX(12), CY(5), CX(17), CY(8), PENCIL);     { lift, crossed out }
  Thick(CX(12), CY(8), CX(17), CY(5), PENCIL);
  Thick(CX(12), CY(18), CX(17), CY(21), PENCIL);   { weight, crossed out }
  Thick(CX(12), CY(21), CX(17), CY(18), PENCIL);
  Lab(19, 7, PENCIL, 'no wing in the model');
  Lab(19, 20, PENCIL, 'a climb costs speed');
  Lab(1, 26, PEN, 'OWL FLY III keeps two of them: THRUST against DRAG, along the');
  Lab(1, 27, PEN, 'path. The other two become ONE rule: climbing costs speed.');
  if upto < 3 then Exit;

  Lab(1, 28, REDPEN, 'vel += (thrust - drag) x 64 / mass,  18.2 times a second');
  Ring(1, 28, 28);
end;

{ ==========================================================================
   PAGE 2 - the air. rho against height, the engine that breathes it, and
   the top speed: where thrust and drag are equal.
   The graph: one cell across is 125 units of height (0..2000 in 16 cells),
   one cell up is 16 of rho (0..256 in 16 cells). Origin at (3, 22).
   ========================================================================== }
function GX(h: Real): Real;
begin GX := 3 + h / 125; end;

function GY(r: Real): Real;
begin GY := 22 - r / 16; end;

procedure PageAir(upto: Integer);
begin
  Big(1, 1, INK, 'THE AIR');
  Thick(CX(3), CY(22), CX(20), CY(22), PENCIL);
  Thick(CX(3), CY(22), CX(3), CY(5), PENCIL);
  Lab(14, 23, PENCIL, 'height');
  Lab(1, 4, PENCIL, 'rho');
  Lab(1, 6, PENCIL, '256');
  Lab(1, 18, PENCIL, ' 64');
  Lab(3, 23, PENCIL, '0');
  Lab(15, 24, PENCIL, '1536');
  Axis(CX(GX(1536)), CY(22), CX(GX(1536)), CY(GY(64)), PENCIL, True);
  Thick(CX(GX(0)), CY(GY(256)), CX(GX(1536)), CY(GY(64)), PEN);
  Thick(CX(GX(1536)), CY(GY(64)), CX(GX(2000)), CY(GY(64)), PEN);
  Lab(21, 5, PEN, 'rho = 256 - height/8');
  Lab(21, 6, PEN, '...and never under 64');
  Lab(21, 8, INK, 'Thinner up high. Real air');
  Lab(21, 9, INK, 'thins EXPONENTIALLY - this');
  Lab(21, 10, INK, 'is a straight line, one');
  Lab(21, 11, INK, 'shift and one SUB.');
  if upto < 2 then Exit;

  Lab(21, 13, PEN, 'THRUST: the engine breathes');
  Lab(21, 14, PEN, '720 x (rho + 256) / 512');
  Lab(21, 15, PEN, '  720 at the sea');
  Lab(21, 16, PEN, '  450 up high');
  Lab(21, 18, PEN, 'DRAG: vel x rho / 256');
  Lab(21, 19, PEN, '  half the air, half the');
  Lab(21, 20, PEN, '  drag');
  if upto < 3 then Exit;

  Lab(1, 25, INK, 'TOP SPEED is where thrust and drag are equal.');
  Lab(1, 26, INK, 'At the sea: 720 = vel x 256/256, so vel = 720.');
  Lab(1, 27, INK, 'At 1000: rho 131, thrust 544, and 544 x 256 / 131 = 1063.');
  Lab(1, 28, REDPEN, 'Climb, and the same engine flies faster.');
  Ring(1, 28, 20);
end;

{ ==========================================================================
   PAGE 3 - Newton. a = F/m with real numbers; the speed creeping up to
   where thrust = drag; and the fraction that makes small forces count.
   The curve: vel against time, rising to 720 and never quite reaching it.
   ========================================================================== }
procedure PageNewton(upto: Integer);
var k : Integer;
    t, v, v0 : Real;
begin
  Big(1, 1, INK, 'NEWTON');
  Big(3, 4, PEN, 'a = F / m');
  FBox(3, 7, 3 + 720 / 60, 8, PEN, PEN);           { thrust, 12 cells }
  Lab(16, 7, PEN, 'THRUST 720');
  FBox(3, 9, 3 + 600 / 60, 10, PENCIL, PENCIL);    { drag at vel 600 }
  Lab(14, 9, PENCIL, 'DRAG 600 (vel 600)');
  Lab(1, 11, INK, 'F = 720 - 600 = 120.  m = 4000 + fuel/3 = 8000 full.');
  Lab(1, 12, INK, 'a = 120 x 64 / 8000 = 0.96 vel a tick.');
  if upto < 2 then Exit;

  { the curve: v' = (720 - v) x 64 / 8000 a tick, from 300; one cell
    across is 50 ticks, one cell up is 80 vel }
  Thick(CX(3), CY(24), CX(20), CY(24), PENCIL);
  Thick(CX(3), CY(24), CX(3), CY(14), PENCIL);
  Dashed(CX(3), CY(24 - 720 / 80), CX(20), CY(24 - 720 / 80), PENCIL);
  Lab(21, 15, PENCIL, '720: thrust = drag');
  Lab(15, 25, PENCIL, 'ticks');
  v := 300;  v0 := v;
  for k := 1 to 850 do
  begin
    v := v + (720 - v) * 64 / 8000;
    if k mod 10 = 0 then
    begin
      Thick(CX(3 + (k - 10) / 50), CY(24 - v0 / 80),
            CX(3 + k / 50), CY(24 - v / 80), PEN);
      v0 := v;
    end;
  end;
  Lab(21, 17, INK, 'The faster it goes, the');
  Lab(21, 18, INK, 'harder the air pushes: the');
  Lab(21, 19, INK, 'speed CREEPS up to 720 and');
  Lab(21, 20, INK, 'never needs a limit.');
  if upto < 3 then Exit;

  Lab(1, 26, INK, 'Cruising, thrust and drag nearly cancel: 58 x 64 / 8000 = 0.46.');
  Lab(1, 27, INK, 'In whole numbers that is NOUGHT, every tick, for ever.');
  Lab(1, 28, REDPEN, 'x256: 118/256 into velf, and ADC carries it. Lesson 17 again.');
  Ring(1, 28, 31);
end;

{ ==========================================================================
   PAGE 4 - the climb. A ball thrown up pays for its height out of its
   speed; so does this aeroplane, since it has no wing. Then SBB, and the
   stall that recovers itself.
   ========================================================================== }
procedure PageClimb(upto: Integer);
var k : Integer;
    x, y, xo, yo : Real;
begin
  Big(1, 1, INK, 'THE CLIMB');
  { the ball's path: a parabola from (3,20) up to (11,8) and down }
  xo := 3;  yo := 20;
  for k := 1 to 32 do
  begin
    x := 3 + k * 0.5;
    y := 20 - 12 * (1 - Sqr((x - 11) / 8));
    Thick(CX(xo), CY(yo), CX(x), CY(y), PENCIL);
    xo := x;  yo := y;
  end;
  Arrow(3, 20, 5.5, 14, PEN, True);         { fast at the bottom }
  Arrow(7, 11.2, 8.6, 9.2, PEN, True);
  Arrow(10, 8.2, 11, 8, PEN, True);         { slow at the top }
  Lab(12, 7, PEN, 'slow');
  Lab(1, 21, PEN, 'fast');
  Lab(21, 5, INK, 'No wing, so no lift. A');
  Lab(21, 6, INK, 'climb is paid for out of');
  Lab(21, 7, INK, 'the speed - like a ball.');
  Lab(21, 9, PEN, 'vel -= 12 x sin(nose)');
  Lab(21, 11, INK, 'nose 18 = 25 degrees:');
  Lab(21, 12, INK, 'sin x 256 = 109');
  Lab(21, 13, INK, '12 x 109 = 1308 256ths:');
  Lab(21, 14, REDPEN, '5 vel a tick, 93 a second');
  if upto < 2 then Exit;

  Lab(1, 23, INK, 'A small nose is a small cost: nose 1, sin 6, 12 x 6 = 72 256ths.');
  Lab(1, 24, PEN, 'sub [velf],72   40-72: the byte keeps 224, CF = 1 - a BORROW');
  Lab(1, 25, PEN, 'sbb [vel],0     vel - 0 - CF: one whole vel lent to the fraction');
  Lab(1, 26, GREEN, 'SBB is ADC the other way round: subtract, and the borrow.');
  if upto < 3 then Exit;

  Lab(1, 27, REDPEN, 'Below 300 the nose falls; the dive gives the speed back.');
  Lab(1, 28, REDPEN, 'Nobody wrote a recovery. It falls out of one line.');
  Ring(1, 28, 26);
end;
