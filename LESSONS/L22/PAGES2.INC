{ ==========================================================================
   PAGE 6 - where the aeroplane appears.

   500 was below a field: 130 -> 42 -> 210 -> 420 -> + 96 = 516. So the
   program asks the map: 255 -> 1110 -> 2220 -> + 700 = 2920.
   ========================================================================== }
procedure PageSpawn(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'where the aeroplane appears');
  Lab(0.9, 2.3, REDPEN, 'Lesson 15 started at 500. Work out what 500 means:');
  Lab(1.8, 4, INK, 'a field, map byte 130:   130 - 88 = 42');
  Lab(1.8, 5, INK, '                         42 * 5 = 210');
  Lab(1.8, 6, INK, '                         doubled by VEXAG = 420');
  Lab(1.8, 7, INK, '                         plus the clearance 96 = ');
  Lab(26.2, 7, REDPEN, '516');
  Ring(26.2, 7, 1.6);
  Lab(0.9, 8.8, INK, 'An ordinary field is above 500. You are dead before you move.');
  if upto < 2 then Exit;

  Lab(0.9, 11, GREY, 'SO THE PROGRAM ASKS THE MAP. TOPOFMAP, once, at the boot:');
  Lab(1.8, 12.4, PEN, 'lodsb over all 4096 bytes, keep the biggest');
  Lab(1.8, 13.4, PEN, 'put it through WORLDH, and the same VEXAG shift');
  Lab(1.8, 14.4, PEN, 'camy0 = that + 700');
  Lab(1.8, 16, INK, 'the worst case, 255:   (255-88)*5 = 835, over 560, so 1110');
  Lab(1.8, 17, INK, '                       doubled 2220, plus 700 = 2920');
  if upto < 3 then Exit;

  Lab(0.9, 19.4, REDPEN, 'A constant that has to be right for every map');
  Lab(0.9, 20.4, REDPEN, 'cannot be a constant.');
  Box(0.6, 19.1, 24.4, 21.3, REDPEN);
  Lab(0.9, 22.4, INK, 'And the answer is in WORLD units, through the same two steps the');
  Lab(0.9, 23.4, INK, 'ground is drawn with. Ask in map bytes, answer in world units, and');
  Lab(0.9, 24.4, INK, 'you get a number that looks fine and is wrong ten times over.');
  Lab(0.9, 26, GREY, 'Now the mountains are the only thing that can reach you - and');
  Lab(0.9, 27, GREY, 'only if you dive.');
end;

{ ==========================================================================
   PAGE 7 - what twice the reach costs.

   38 x 625 = 23750, 12 x 2401 = 28812: the bill is the number of squares.
   ========================================================================== }
procedure PageBill(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'what twice the reach costs');
  Lab(0.9, 2.3, REDPEN, 'Measured: retrace wait off, the aeroplane parked, one island.');
  Box(0.9, 3.6, 24, 9.8, PEN);
  Lab(1.8, 4.2, GREY, 'reach    squares    frames');
  Lab(1.8, 5.4, INK, '  12        625        38');
  Lab(1.8, 6.4, INK, '  16       1089        23');
  Lab(1.8, 7.4, INK, '  20       1681        17');
  Lab(1.8, 8.4, INK, '  24       2401        12');
  if upto < 2 then Exit;

  Lab(0.9, 11, GREY, 'MULTIPLY THE LAST TWO COLUMNS:');
  Lab(1.8, 12.4, INK, '38 x  625 = 23750');
  Lab(1.8, 13.4, INK, '12 x 2401 = 28812');
  Lab(15, 12.9, REDPEN, 'about the same. The bill is the');
  Lab(15, 13.9, REDPEN, 'NUMBER OF SQUARES.');
  if upto < 3 then Exit;

  Lab(0.9, 16, INK, 'Not the pixels. A far square is a handful of pixels, and it still');
  Lab(0.9, 17, INK, 'costs four corners out of the cache, a near-plane clip, four');
  Lab(0.9, 18, INK, 'perspective divides and a polygon walk. The fixed cost swamps the');
  Lab(0.9, 19, INK, 'paint. That is the opposite of what you would guess about a filler.');
  if upto < 4 then Exit;

  Box(2, 21.4, 4, 23.4, PEN);
  Lab(1.8, 24, INK, 'reach 1');
  Box(8, 21.4, 12, 25.4, PEN);
  Lab(8, 26, INK, 'reach 2');
  Lab(14, 22.4, REDPEN, 'twice the reach, FOUR times');
  Lab(14, 23.4, REDPEN, 'the squares, and a quarter of');
  Lab(14, 24.4, REDPEN, 'the frames.');
end;

{ ==========================================================================
   PAGE 8 - a square turned 45 degrees does not fit.

   24 x 1024 = 24576. x 1.414 = 34756. A signed word stops at 32767, so it
   reads 34756 - 65536 = -30780. The circle: 1793 of 2401, farthest 25844.
   ========================================================================== }
procedure PageCirc(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'a square turned 45 degrees does not fit');
  Lab(0.9, 2.3, REDPEN, 'From above. The block of squares, and the same block turned.');
  Box(3, 5, 11, 13, PEN);
  Dot(CX(7), CY(9), REDPEN);
  Dim(CX(7), CX(11), CY(14));
  Lab(7.4, 14.4, PENCIL, '24 nodes');
  SetColor(GREEN);
  Line(CX(21), CY(3.4), CX(26.6), CY(9));
  Line(CX(26.6), CY(9), CX(21), CY(14.6));
  Line(CX(21), CY(14.6), CX(15.4), CY(9));
  Line(CX(15.4), CY(9), CX(21), CY(3.4));
  Dot(CX(21), CY(9), REDPEN);
  Axis(CX(21), CY(9), CX(26.6), CY(9), PENCIL, True);
  Lab(27, 8.6, REDPEN, 'x 1.414');
  if upto < 2 then Exit;

  Lab(0.9, 16.4, INK, 'along an axis:   24 x 1024 = 24576          fits');
  Lab(0.9, 17.4, INK, 'at 45 degrees:   24576 x 1.414 = 34756      does NOT');
  Lab(0.9, 18.4, GREY, 'a signed word stops at 32767, and ROTXZ adds with a 16-bit ADD');
  if upto < 3 then Exit;

  Lab(0.9, 20.2, REDPEN, '34756 - 65536 = -30780');
  Ring(0.9, 20.2, 11);
  Lab(0.9, 21.4, INK, 'The corner lands on the far side of the world. Those were the slabs');
  Lab(0.9, 22.4, INK, 'over the horizon - and why turning found them: at 0, 90, 180, 270');
  Lab(0.9, 23.4, INK, 'one product is nought and nothing overflows.');
  if upto < 4 then Exit;

  Lab(0.9, 25, GREY, 'A VIEW DISTANCE IS THE SAME EVERY WAY. It is a circle.');
  Lab(0.9, 26.2, INK, 'TORD is sorted by distance, so the circle is its first entries:');
  Lab(0.9, 27.2, INK, '1793 of the 2401 squares, and the farthest node is 25844.');
  Lab(0.9, 28.4, REDPEN, 'A turn cannot make a length longer. Nothing can overflow now.');
end;

{ ==========================================================================
   PAGE 9 - three cheaper squares.

   Outcodes, an AND of four. Edges owned by the square painted later.
   And three bytes of the engine taken out: E8 checked, 90 90 90 written.
   ========================================================================== }
procedure PageThree(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'three cheaper squares');
  Lab(0.9, 2.3, REDPEN, 'ONE: three bits a NODE, worked out once:');
  Lab(1.8, 3.6, PEN, 'bit 0 behind      bit 1 off the right      bit 2 off the left');
  Lab(1.8, 5, INK, 'the four corners of a square:   010  010  011  010');
  Lab(1.8, 6, INK, 'AND them together:               010');
  Lab(22, 6, REDPEN, 'all four off the right');
  Lab(1.8, 7.2, GREY, 'A square with every corner past one plane is ALL past it. Culled,');
  Lab(1.8, 8, GREY, 'and not one corner loaded. Lesson 13 called these outcodes too.');
  if upto < 2 then Exit;

  Lab(0.9, 10, REDPEN, 'TWO: every edge drawn ONCE, by the square painted LATER.');
  FillQuad(3, 11.4, 9, 11.4, 9, 15.4, 3, 15.4, RULE);
  FillQuad(9, 11.4, 15, 11.4, 15, 15.4, 9, 15.4, PEN);
  Thick(CX(9), CY(11.4), CX(9), CY(15.4), REDPEN);
  Lab(3.4, 15.8, PENCIL, 'far: first');
  Lab(10, 15.8, PEN, 'near: last');
  Lab(17, 12, INK, 'the shared edge belongs to');
  Lab(17, 13, INK, 'the near one, so its own fill');
  Lab(17, 14, INK, 'never covers it. Neighbours''');
  Lab(17, 15, INK, 'distances differ by 2d+1: odd,');
  Lab(17, 16, INK, 'so never a tie.');
  if upto < 3 then Exit;

  Lab(0.9, 18.2, REDPEN, 'THREE: take an instruction OUT of the engine.');
  Lab(1.8, 19.6, PEN, 'CLIPNEAR:  E8 xx xx     call PITCH4');
  Lab(1.8, 20.6, INK, 'rotates four corners by the pitch: 16 IMULs, 16 IDIVs a square.');
  Lab(1.8, 21.6, INK, 'This aeroplane never pitches: psin 0, pcos 256. It changes nothing.');
  if upto < 4 then Exit;

  Lab(1.8, 23.2, PEN, 'at the boot:  is it E8?  then write  90 90 90');
  Ring(1.8, 23.2, 22);
  Lab(0.9, 24.8, INK, 'Look before you write: if the engine ever changes, it is left alone.');
  Lab(0.9, 26, INK, 'Lesson 8 wrote numbers INTO an instruction. This takes one OUT.');
  Lab(0.9, 27.2, GREY, 'The game needs that call - it loops and dives - so its source is');
  Lab(0.9, 28.2, GREY, 'not touched. Only this program''s own copy, in its own memory.');
end;

{ ==========================================================================
   PAGE 10 - what each one bought. The closing card.
   ========================================================================== }
procedure PageFinal(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'what each one bought');
  Lab(0.9, 2.3, REDPEN, 'Twenty four nodes. One change at a time. The same picture.');
  Box(0.9, 3.6, 30, 10.2, PEN);
  Lab(1.8, 4.2, INK, 'the square, as it was                    19');
  Lab(1.8, 5.2, INK, 'the CIRCLE: a quarter fewer squares      22');
  Lab(1.8, 6.2, INK, '+ outcodes: an AND of four bytes         23');
  Lab(1.8, 7.2, INK, '+ each edge drawn once                   26');
  Lab(1.8, 8.2, INK, '+ the pitch taken out of the engine      27');
  if upto < 2 then Exit;

  Lab(0.9, 11.6, REDPEN, 'The outcode cull is five times cheaper a square - and bought');
  Lab(0.9, 12.6, REDPEN, 'ONE frame. The old test threw away the same squares already.');
  Lab(0.9, 13.8, INK, 'The time is in the squares that are DRAWN, and the next two lines');
  Lab(0.9, 14.8, INK, 'are both about those.');
  Lab(0.9, 16.2, REDPEN, 'Measure before you believe the instruction count.');
  Ring(0.9, 16.2, 25);
  if upto < 3 then Exit;

  Lab(0.9, 18.8, INK, 'At lesson 15''s reach, twelve nodes, it now runs at 76 frames.');
  Lab(0.9, 19.8, INK, 'That is exactly lesson 15''s BARE WIREFRAME - filled, with every');
  Lab(0.9, 20.8, INK, 'seam drawn, and a ground that can kill you.');
  Lab(0.9, 22.6, GREY, 'SIXTEEN BITS IS A WALL. A word holds 32767, and turning a square');
  Lab(0.9, 23.6, GREY, 'forty five degrees can walk straight into it. That is the part of');
  Lab(0.9, 24.6, GREY, 'the machine this lesson touched.');
  Lab(0.9, 26.4, REDPEN, 'Next lesson: houses on this ground - and the painter will have');
  Lab(0.9, 27.4, REDPEN, 'to sort things that are not on a grid.');
end;
