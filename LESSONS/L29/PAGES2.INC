{ ==========================================================================
   PAGE 4 - the path bends. The two lines, then the aeroplane from behind
   three times - level, banked sixty, upside down - lift against weight;
   then the bug that looped by itself.
   ========================================================================== }

{ from behind at (u, v), banked a (radians): wings, fin, and the lift and
  the weight as arrows, cells long }
procedure Rear(u, v, a, lift: Real);
var c, s : Real;
begin
  c := Cos(a);  s := Sin(a);
  Thick(CX(u - 2.5 * c), CY(v - 2.5 * s), CX(u + 2.5 * c), CY(v + 2.5 * s), PEN);
  Thick(CX(u), CY(v), CX(u + 1 * s), CY(v - 1 * c), PEN);
  Arrow(u, v, u + lift * s, v - lift * c, GREEN, True);
  Arrow(u, v, u, v + 3, REDPEN, True);
end;

procedure PageBend(upto: Integer);
begin
  Big(1, 1, INK, 'THE PATH BENDS');
  Lab(1, 3, INK, 'The lift, tilted by the bank, against the weight, always down.');
  Lab(2, 5, PEN, 'dpitch   = 2 x (N x cos(roll) - 10 x cos(pitch)) / vel');
  Lab(2, 6, PEN, 'dheading = 2 x N x sin(roll) / vel / cos(pitch)');
  Lab(2, 7, PENCIL, 'eighths of a step a tick; level and pulling, q itself, as before');
  if upto < 2 then Exit;

  Rear(6, 13, 0, 3);
  Rear(18, 13, Pi / 3, 3);
  Rear(30, 13, Pi, 3);
  LabXY(CX(2), CY(17.5), GREEN, 'level: 1 G up,');
  LabXY(CX(2), CY(18.3), REDPEN, '1 G down: flat');
  LabXY(CX(13), CY(17.5), GREEN, 'banked 60, hands off:');
  LabXY(CX(13), CY(18.3), REDPEN, 'half a G up: it SINKS');
  LabXY(CX(13), CY(19.1), PEN, 'hold the height: 2 G');
  LabXY(CX(26), CY(17.5), GREEN, 'upside down:');
  LabXY(CX(26), CY(18.3), REDPEN, 'lift down: DIVES');
  LabXY(CX(26), CY(19.1), PEN, 'push: -1 G holds');
  if upto < 3 then Exit;

  Lab(1, 22, INK, 'THE BUG: the first build asked for 1 G with the stick centred. In a');
  Lab(1, 23, INK, 'climb only cos(pitch) of the weight is across the path - the spare');
  Lab(1, 24, INK, 'lift bent it up, and it looped by itself, into the ground.');
  Lab(1, 26, REDPEN, 'Hands off asks for 10 x cos(pitch): it holds the path.');
  Ring(1, 26, 27);
end;

{ ==========================================================================
   PAGE 5 - honest now, and not yet.
   ========================================================================== }
procedure PageHonest(upto: Integer);
begin
  Big(1, 1, INK, 'HONEST NOW, AND NOT YET');
  Lab(1, 3, INK, 'The G meter reads the load the wing CARRIES: 1.0 level, -1.0 upside');
  Lab(1, 4, INK, 'down holding the height, less than the ask in a stall.');
  Lab(1, 6, INK, 'pitch and heading are the PATH now. NOSEIN turns the picture to the');
  Lab(1, 7, INK, 'nose - path plus alpha - for one frame; NOSEOUT gives PHYS the path.');
  if upto < 2 then Exit;

  Lab(1, 10, PEN, 'STILL NOT HONEST, AND SAID SO:');
  Lab(2, 11, PEN, 'the lift is a straight line in alpha up to the stall');
  Lab(2, 12, PEN, 'a turn costs a flat TURNDRG, not the drag a wing makes');
  Lab(2, 13, PEN, 'drag is still a straight line in the speed');
  Lab(2, 14, PEN, 'no sideslip: the nose and the path share the bank');
  Lab(2, 15, PEN, 'and the air still thins in a straight line');
  if upto < 3 then Exit;

  Lab(1, 19, REDPEN, 'A wing flies at an angle -');
  Lab(1, 20, REDPEN, 'and the stall is an angle, not a speed.');
  Ring(1, 20, 20);
end;
