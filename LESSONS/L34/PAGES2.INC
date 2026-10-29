{ ==========================================================================
   PAGE 4 - their guns. Two products say where you are from its point of
   view; in its sights; the fighter turns towards you; no lead.
   ========================================================================== }
procedure PageTheirs(upto: Integer);
begin
  Big(1, 1, INK, 'THEIR GUNS');
  Lab(1, 3, INK, 'Where are you, from its point of view? dx, dz: you, from it; h: its');
  Lab(1, 4, INK, 'heading. Two products of a sine and a distance:');
  Lab(2, 6, PEN, 'ahead = sin h x dx + cos h x dz        how far in front');
  Lab(2, 7, PEN, 'side  = sin h x dz - cos h x dx        negative: to its right');
  Lab(1, 8, GREEN, 'products of a sine and a distance: double words, IMUL, ADD/ADC, SBB');
  if upto < 2 then Exit;

  Lab(1, 11, INK, 'IN ITS SIGHTS: ahead > 0, |side| < ahead / 4 - about 14 degrees -');
  Lab(1, 12, INK, 'ahead < 1800, and not too steep. Then it fires: 75 + its own speed');
  Lab(1, 13, INK, 'along its heading, and up or down at you by 19200 x dy / ahead.');
  Lab(2, 15, PEN, 'it flies north, you 300 north of it:      ahead 300, side 0 - FIRE');
  Lab(2, 16, PEN, 'you 300 north and 100 east:   side -100, and 100 > 300/4 - no;');
  Lab(2, 17, PEN, '                              side < 0: you are on its right');
  if upto < 3 then Exit;

  Lab(1, 20, INK, 'The FIGHTER chases: a step towards your side every second tick.');
  Lab(1, 22, REDPEN, 'They do not lead you. They fire where you ARE, not where you will');
  Lab(1, 23, REDPEN, 'be - so a crossing shot misses, and a pursuer on your tail does not.');
  Lab(1, 25, INK, 'Your hull takes eight. The eighth breaks your own aeroplane by the');
  Lab(1, 26, INK, 'same laws - and the world goes on: the traffic, the rounds, and your');
  Lab(1, 27, INK, 'pieces falling among them.');
end;

{ ==========================================================================
   PAGE 5 - a gun is carried by its aeroplane. The fact; the red sky;
   what is not done yet.
   ========================================================================== }
procedure PageCarried(upto: Integer);
begin
  Big(1, 1, INK, 'A GUN IS CARRIED');
  Lab(1, 3, INK, 'A round leaves with the aeroplane''s velocity added to the muzzle''s:');
  Lab(2, 5, PEN, 'fired forward at 736:      86.5 a tick');
  Lab(2, 6, PEN, 'a pursuer at 15 a tick: its rounds 90; you ahead at 11.5:');
  Lab(2, 7, PEN, '                           they close on you at 78.5');
  if upto < 2 then Exit;

  Lab(1, 9, INK, 'A hit on you: the sky red for five frames - lesson 1F, one DAC');
  Lab(1, 10, INK, 'entry, no pixel touched. And for three of them OWL FLY III''s red');
  Lab(1, 11, INK, 'and yellow bands over the world: every 2nd, 3rd, 4th row, thinning.');
  Lab(1, 13, REDPEN, 'A gun is carried by its aeroplane.');
  Ring(1, 13, 17);
  Lab(1, 15, INK, 'That is the physical fact - and gravity pulls every round: nothing');
  Lab(1, 16, INK, 'in the sky starts from standing still, and nothing flies straight.');
  if upto < 3 then Exit;

  Lab(1, 19, PENCIL, 'NOT YET, SAID SO:');
  Lab(2, 20, PENCIL, 'their aim does not lead you');
  Lab(2, 21, PENCIL, 'rounds pass through the ground and the houses');
  Lab(2, 22, PENCIL, 'the air does not slow a round');
  Lab(2, 23, PENCIL, 'two wrecks at most: a third takes the older slot');
  Lab(2, 24, PENCIL, 'GUNS.COM is 63 thousand bytes: one .COM segment is nearly full');
end;
