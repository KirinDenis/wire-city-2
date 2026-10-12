{ ==========================================================================
   PAGE 5 - a new letter is six numbers. ( ) and *; and lower case for one
   AND.
   ========================================================================== }
procedure PageNew(upto: Integer);
var i : Integer;
begin
  Big(1, 1, INK, 'A NEW LETTER IS SIX NUMBERS');
  Lab(1, 3, INK, 'The game never needed brackets or a star. This lesson does.');
  Bits(2, 5, 1, G46LP, 3, PEN, PENCIL, True);
  for i := 0 to 5 do Lab(6, 5 + i, PEN, Bin8(G46LP[i]));
  if upto < 2 then Exit;

  Bits(13, 5, 1, G46RP, 3, PEN, PENCIL, True);
  for i := 0 to 5 do Lab(17, 5 + i, PEN, Bin8(G46RP[i]));
  Bits(24, 5, 1, G46ST, 3, PEN, PENCIL, True);
  for i := 0 to 5 do Lab(28, 5 + i, PEN, Bin8(G46ST[i]));
  Lab(1, 12, INK, 'Draw it on squared paper, read the rows as binary, add the line');
  Lab(1, 13, INK, 'to FONT46 and the character to PUNCT. That is the whole job.');
  if upto < 3 then Exit;

  Big(1, 15, INK, 'LOWER CASE: ONE AND');
  Lab(1, 17, PEN, '''a'' = 61h = 0110 0001');
  Lab(1, 18, PEN, '''A'' = 41h = 0100 0001      32 apart: bit 5, and only bit 5');
  Lab(1, 20, PEN, 'AND AL,0DFh   1101 1111: every bit but bit 5');
  Lab(1, 21, PEN, '''a'' becomes 0100 0001, ''A'';  and ''A'' stays ''A''');
  Lab(1, 23, INK, 'The people who laid out ASCII put the two cases 32 apart on purpose.');
  Lab(1, 26, REDPEN, 'AND AL,0DFh: lower case costs one instruction.');
  Ring(1, 26, 23);
end;

{ ==========================================================================
   PAGE 6 - OR grows, AND NOT carves. The A, four ways: itself, taller,
   wider, and the ring that is left. Then the game's strip again, ringed.
   ========================================================================== }
procedure PageRing(upto: Integer);
begin
  Big(1, 1, INK, 'OR GROWS, AND NOT CARVES');
  Lab(1, 3, INK, 'Light letters vanish on a light sky - and this island has snow.');
  Band(5, False, RINGG, INKW);
  Bits(2, 10, 1, HERE8, 5, PEN, PENCIL, True);
  Lab(2, 19, PEN, 'the letter:');
  Lab(2, 20, PEN, 'here');
  if upto < 2 then Exit;

  Bits(11, 10, 1, TALL8, 5, PEN, PENCIL, True);
  Lab(11, 19, PEN, 'taller:');
  Lab(11, 20, PEN, 'up | here | down');
  Bits(20, 10, 1, WIDE8, 5, PEN, PENCIL, True);
  Lab(20, 19, PEN, 'wider:');
  Lab(20, 20, PEN, 'o | o<<1 | o>>1');
  if upto < 3 then Exit;

  Bits(29, 10, 1, RING8, 5, RINGG, PENCIL, True);
  Bits(29, 10, 1, HERE8, 5, PEN, PENCIL, False);
  Lab(29, 19, PEN, 'the ring:');
  Lab(29, 20, PEN, 'o & NOT here');
  Band(22, True, RINGG, INKW);
  Lab(2, 26, REDPEN, 'Now it reads on anything.');
  Ring(2, 26, 13);
end;

{ ==========================================================================
   PAGE 7 - grey, not black. The first ring, the one in the game now, and
   the two DAC entries that make the difference.
   ========================================================================== }
procedure PageGrey(upto: Integer);
begin
  Big(1, 1, INK, 'GREY, NOT BLACK');
  Lab(1, 3, INK, 'The first ring was black under white, and it read too well: the eye');
  Lab(1, 4, INK, 'went to the numbers and stayed there, instead of on the island.');
  Band(6, True, INK, PAPER);
  Lab(2, 9, PENCIL, 'black and white: loud');
  if upto < 2 then Exit;

  Band(11, True, RINGG, INKW);
  Lab(2, 14, PENCIL, 'colours 48 and 49 of their own, set in the DAC: quiet');
  Lab(2, 16, PEN, '          ring (48)     letters (49)');
  Lab(2, 17, PEN, 'day       22,23,25      54,54,52');
  Lab(2, 18, PEN, 'night     12,12,14      44,44,42');
  Lab(2, 19, PENCIL, 'out of 63: six bits a colour, as every DAC entry has');
  if upto < 3 then Exit;

  Lab(2, 22, INK, 'T switches in flight: ROM 8X8, OUR 4X6, OUR 4X6 RINGED.');
  Lab(2, 23, INK, 'Only two DAC entries changed. The mask is the same.');
  Lab(2, 26, REDPEN, 'OR grows, AND NOT carves: every mask in graphics.');
  Ring(2, 26, 25);
end;
