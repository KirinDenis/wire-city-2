{ ==========================================================================
   PAGE 4 - spin, and falling. A push off the centre turns a piece; the
   same gravity, the air, the floor; positions with a byte of fraction.
   ========================================================================== }
procedure PageSpin(upto: Integer);
begin
  Big(1, 1, INK, 'SPIN, AND FALLING');
  Lab(1, 3, INK, 'A push that misses a piece''s centre turns it - and a big piece');
  Lab(1, 4, INK, 'turns slowly: the lever is its size, the inertia its mass times');
  Lab(1, 5, INK, 'its size squared.');
  Lab(2, 7, PEN, 'spin = J / (m x size)        size = square root of m');
  Lab(2, 8, PEN, 'the fin:  15750 / (15 x 4) = 262  ->  clamped to 48');
  Lab(2, 9, PEN, 'a wing:   19080 / (96 x 10) = 19');
  Lab(1, 10, PENCIL, 'sixteenths of a step a frame; the lever is the size, not worked out');
  if upto < 2 then Exit;

  Lab(1, 13, INK, 'Then every frame, for every piece in the air:');
  Lab(2, 15, PEN, 'v.y -= 12            gravity: the same for all of them');
  Lab(2, 16, PEN, 'v   -= v / 128       the air: the same share of every speed');
  Lab(2, 17, PEN, 'pos += v             a += spin');
  Lab(2, 18, PEN, 'on the floor:        stopped dead, and still');
  if upto < 3 then Exit;

  Lab(1, 21, INK, 'A speed of 12/256 of a unit a frame must still move a piece. So a');
  Lab(1, 22, INK, 'position is a word of units and a BYTE of fraction:');
  Lab(2, 24, PEN, 'add  [frac],al      ; the low byte of v into the fraction');
  Lab(2, 25, PEN, 'mov  al,ah  / cbw   ; the high byte, signed');
  Lab(2, 26, PEN, 'adc  [pos],ax       ; into the units, with the carry');
  Lab(1, 28, GREEN, 'Lesson 17''s byte of fraction, carried with ADC: the same three lines.');
end;

{ ==========================================================================
   PAGE 5 - the centre of mass. The red cross, the amber path, and the
   fact; what is not honest yet.
   ========================================================================== }
procedure PageCentre(upto: Integer);
begin
  Big(1, 1, INK, 'THE CENTRE OF MASS');
  Lab(1, 3, INK, 'Where all the pieces are, weighed by their masses:');
  Lab(2, 5, PEN, 'cm = SUM(m x pos) / M            the red cross');
  Lab(1, 7, INK, 'and a WHOLE aeroplane, flown on from the hit by the same laws -');
  Lab(1, 8, INK, 'at its own speed plus the shell''s share:      the amber dots');
  if upto < 2 then Exit;

  Lab(1, 11, INK, 'Gravity is the same for every piece, and the air takes the same');
  Lab(1, 12, INK, 'share of every speed - so their sum, the momentum, goes exactly');
  Lab(1, 13, INK, 'as one aeroplane''s would. The cross rides the dots,');
  Lab(1, 15, REDPEN, 'until the first piece touches the floor - a push from outside too.');
  if upto < 3 then Exit;

  Lab(1, 18, REDPEN, 'An explosion has no momentum of its own.');
  Ring(1, 18, 20);
  Lab(1, 20, INK, 'Every push inside the aeroplane has its equal push back. The pieces');
  Lab(1, 21, INK, 'go everywhere; their centre goes where the aeroplane was going.');
  Lab(1, 24, PENCIL, 'NOT HONEST YET: the air is one share for every piece; the lever of');
  Lab(1, 25, PENCIL, 'the spin is the size, not where the push lands; pieces pass through');
  Lab(1, 26, PENCIL, 'each other and partly through the floor; nothing burns.');
  Lab(1, 28, INK, 'Next lesson: guns - yours and theirs - and all of it in the sky.');
end;
