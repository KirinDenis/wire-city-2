{ ==========================================================================
   PAGE 4 - hiding is only order. A depth a face, two faces painted far
   first, and the bubble sort that is nearly free.
   ========================================================================== }
procedure PagePaint(upto: Integer);
begin
  Big(1, 1, INK, 'HIDING IS ONLY ORDER');
  Lab(1, 3, INK, 'Every face gets a depth: the average z" of its four corners.');
  Lab(2, 5, PEN, 'depth = ((z0 + z1) / 2 + (z2 + z3) / 2) / 2');
  Lab(2, 6, PENCIL, 'halves of halves: no sum of four ever needs more than a word');
  if upto < 2 then Exit;

  FBox(3, 9, 12, 14, PENCIL, INK);
  FBox(8, 11, 17, 17, PEN, INK);
  LabXY(CX(3.3), CY(9.3), PAPER, '1  far');
  LabXY(CX(12.3), CY(15.5), PAPER, '2  near');
  Lab(19, 9, INK, 'Far first, near last. Video');
  Lab(19, 10, INK, 'memory keeps the LAST byte');
  Lab(19, 11, INK, 'written to it, nothing more:');
  Lab(19, 12, INK, 'the near face covers the far');
  Lab(19, 13, INK, 'one because it came later.');
  Lab(19, 15, GREEN, 'FACEFILL, the engine''s, does');
  Lab(19, 16, GREEN, 'the clip, the lens, the fill.');
  if upto < 3 then Exit;

  Lab(1, 19, PEN, 'BUBBLE: swap two neighbours the wrong way round; go over it again.');
  Lab(2, 21, PENCIL, 'for example, last frame:  512 497 470 455 431 420 404 388');
  Lab(2, 22, PENCIL, '            this frame:  512 470 497 455 431 420 404 388');
  Lab(2, 23, PEN, '                         one swap, and the order is right again');
  Lab(1, 25, INK, 'From frame to frame the order hardly changes: a bubble on an order');
  Lab(1, 26, INK, 'that is almost right does almost nothing.');
  Lab(1, 28, REDPEN, 'The last byte written wins. That is all the hiding there is.');
  Ring(1, 28, 30);
end;

{ ==========================================================================
   PAGE 5 - W, and the air force. The points on the screen; the five types
   in vertices, faces and bytes; where the game's F-15 comes from.
   ========================================================================== }
procedure TypeRow(v: Integer; name: string; nv, nf: Integer; c: Integer);
begin
  Lab(2, v, c, name);
  Lab(13, v, c, IStr(nv));
  Lab(19, v, c, IStr(nf));
  Lab(24, v, c, IStr(nv * 6 + nf * 5));
end;

procedure PageForce(upto: Integer);
begin
  Big(1, 1, INK, 'W: THE POINTS ON THE SCREEN');
  Lab(1, 3, INK, 'W: FILLED, then FILLED + WIRE + NUMBERS, then the WIRE alone.');
  Lab(1, 5, PEN, 'PROJV    every vertex through the lens, into SX and SY');
  Lab(1, 6, PEN, 'WIRE     every face''s four edges, corner k to corner k + 1');
  Lab(6, 7, GREEN, 'CLIPLINE and LINE, the engine''s');
  Lab(1, 8, PEN, 'NUMBERS  each vertex''s number in lesson 1A''s 4x6 digits:');
  Lab(6, 9, PEN, 'black four times, a pixel off each way, then amber');
  Lab(1, 11, INK, 'A triangle''s repeated vertex makes an edge of no length.');
  if upto < 2 then Exit;

  Lab(2, 13, PENCIL, 'TYPE');
  Lab(13, 13, PENCIL, 'VERTICES');
  Lab(19, 13, PENCIL, 'FACES');
  Lab(24, 13, PENCIL, 'BYTES');
  TypeRow(14, 'FIGHTER', 13, 8, PEN);
  TypeRow(15, 'BOMBER', 25, 12, PEN);
  TypeRow(16, 'RADAR PICKET', 19, 10, PEN);
  TypeRow(17, 'TRANSPORT', 13, 8, REDPEN);
  TypeRow(18, 'TANKER', 19, 10, PEN);
  Lab(2, 20, PENCIL, 'UP and DOWN put the next one on the stand; LEFT and RIGHT spin it');
  if upto < 3 then Exit;

  Lab(1, 22, INK, 'The game''s own fighter is a twin-tail F-15 from a model file,');
  Lab(1, 23, INK, 'res\F15.OBJ, turned into the same two tables when the game is');
  Lab(1, 24, INK, 'built, by a C# tool, Obj2Inc: 23 vertices and 14 faces.');
  Lab(1, 27, REDPEN, 'Next lesson: these aeroplanes, into the sky of lesson 1D.');
  Ring(1, 27, 29);
end;
