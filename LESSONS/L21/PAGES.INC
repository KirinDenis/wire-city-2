{ ==========================================================================
   PAGE 1 - the ground stops being flat.

   Two side views of the same lattice: the sheet of graph paper we have
   been flying over since lesson 11, and the same nodes each at its own
   height. The map was always there. We drew it on the map screen and
   then threw the number away.
   ========================================================================== }
procedure PageFlat(upto: Integer);
const
  HP : array[0..8] of Real = (0, 1, 3, 5, 4, 6, 3, 1, 0);
var
  i : Integer;
begin
  Head(0.9, 0.7, INK, 'the ground stops being flat');
  Lab(0.9, 2.3, REDPEN, 'the notebook again. Every number on it is the program''s own.');
  if upto < 2 then Exit;

  Lab(0.9, 4.2, GREY, 'UP TO HERE - a sheet of graph paper, seen edge on');
  Axis(CX(2), CY(8), CX(34), CY(8), PEN, False);
  for i := 0 to 8 do Dot(CX(2 + i * 4), CY(8), PEN);
  Dim(CX(2), CX(6), CY(9.5));
  Lab(2.4, 9.9, PENCIL, '1024 units, one node');
  Lab(0.9, 11.4, INK, 'Every node sat at height nought. The island from lesson 11 was');
  Lab(0.9, 12.4, INK, 'drawn on the map screen, and then the height was thrown away.');
  if upto < 3 then Exit;

  Lab(0.9, 15, GREY, 'FROM HERE - the same nodes, each one asking the map how high');
  Axis(CX(2), CY(24), CX(34), CY(24), PENCIL, True);
  SetColor(PEN);
  for i := 0 to 7 do
    Line(CX(2 + i * 4), CY(24 - HP[i]), CX(6 + i * 4), CY(24 - HP[i + 1]));
  for i := 0 to 8 do Dot(CX(2 + i * 4), CY(24 - HP[i]), PEN);
  Lab(0.9, 25.6, INK, 'Nothing else moves. The nodes are where they always were, and');
  Lab(0.9, 26.6, INK, 'only their height is new.');
  Lab(0.9, 28.2, REDPEN, 'And now a hill can get IN THE WAY of what is behind it.');
end;

{ ==========================================================================
   PAGE 2 - where the height comes from, and why it looked flat.

   WORLDH is in ENGINE\E_TERR.INC and the game calls the same routine.
   The three worked bytes are 120, 200 and 255, and the drawing at the
   bottom is the point of the page: 1024 across against 1110 at the
   highest point of the island. VEXAG doubles the height, and nothing
   else, in one shift.
   ========================================================================== }
procedure PageHgt(upto: Integer);
const
  HG : array[0..3] of Real = (0, 0.6, 2.2, 4.3);
var
  i : Integer;
begin
  Head(0.9, 0.7, INK, 'where the height comes from');
  Lab(0.9, 2.3, REDPEN, 'WORLDH, in ENGINE\E_TERR.INC. The game calls this one too.');
  Box(0.9, 3.6, 35, 8.6, PEN);
  Lab(1.8, 4.3, PEN, 'h = (H - 88) * 5');
  Lab(1.8, 5.4, PEN, 'if h > 560 then h = h + (h - 560)');
  Lab(1.8, 6.9, GREY, 'H is the byte in the map. Below 88 the answer is 0, and 0 is');
  Lab(1.8, 7.7, GREY, 'the sea: flat, and the same everywhere.');
  if upto < 2 then Exit;

  Lab(0.9, 10, GREY, 'THREE BYTES OUT OF THE MAP, worked:');
  Lab(1.8, 11.4, INK, 'H=120   120-88=32    32*5 = 160    under 560      160');
  Lab(1.8, 12.4, INK, 'H=200   200-88=112  112*5 = 560    under 560      560');
  Lab(1.8, 13.4, INK, 'H=255   255-88=167  167*5 = 835    OVER         1110');
  Lab(1.8, 14.8, GREY, '835 + (835 - 560) = 835 + 275 = 1110. Above 560 the slope');
  Lab(1.8, 15.6, GREY, 'doubles, so mountains are mountains and fields stay fields.');
  if upto < 3 then Exit;

  Lab(0.9, 17, GREY, 'TO SCALE. 1 cell = 256 units each way, so a node is 4 cells.');
  Lab(2, 18.2, GREY, 'the game''s own heights');
  Axis(CX(2), CY(25), CX(16), CY(25), PENCIL, True);
  SetColor(PEN);
  for i := 0 to 2 do
    Line(CX(2 + i * 4), CY(25 - HG[i]), CX(6 + i * 4), CY(25 - HG[i + 1]));
  for i := 0 to 3 do Dot(CX(2 + i * 4), CY(25 - HG[i]), PEN);
  Lab(5.6, 25.6, INK, '160     560     1110');
  if upto < 4 then Exit;

  Lab(19, 18.2, GREY, 'and with VEXAG - shl ax,1');
  Axis(CX(19), CY(25), CX(33), CY(25), PENCIL, True);
  SetColor(GREEN);
  for i := 0 to 2 do
    Line(CX(19 + i * 4), CY(25 - HG[i] * 2), CX(23 + i * 4), CY(25 - HG[i + 1] * 2));
  for i := 0 to 3 do Dot(CX(19 + i * 4), CY(25 - HG[i] * 2), GREEN);
  Lab(22.6, 25.6, GREEN, '320     1120    2220');
  Lab(0.9, 27.2, REDPEN, 'The only number in the file that is not the game''s. A lie');
  Lab(0.9, 28.2, REDPEN, 'told on purpose, and the flight is a different thing for it.');
end;

{ ==========================================================================
   PAGE 3 - the floor is not a number any more.

   CAMYCL is 96 and it is a CLEARANCE, not a height: how close to the
   ground under you the aeroplane may get. The node under the eye is the
   middle of the cache, slot (12*26+12)*2 = 648, and it is already
   rotated - the collision costs one compare.

   And the pitch keys go the other way round, which is the pilot's.
   ========================================================================== }
procedure PageGnd(upto: Integer);
const
  HQ : array[0..6] of Real = (0, 0.4, 2.6, 3.4, 1.6, 0.6, 0);
var
  i : Integer;
begin
  Head(0.9, 0.7, INK, 'the floor is not a number any more');
  Lab(0.9, 2.3, REDPEN, 'Lesson 14 pinned the height between 96 and a ceiling.');
  Axis(CX(2), CY(7), CX(22), CY(7), PENCIL, True);
  Lab(22.6, 6.6, PENCIL, 'camy = 96');
  Dot(CX(8), CY(4.4), PEN);
  Lab(8.6, 4.1, INK, 'you');
  Lab(0.9, 8.6, GREY, 'A number. It did not know there was anything under it.');
  if upto < 2 then Exit;

  Lab(0.9, 11, GREY, 'NOW IT ASKS THE GROUND, and the ground answers in world units');
  Axis(CX(2), CY(21), CX(34), CY(21), PENCIL, True);
  SetColor(PEN);
  for i := 0 to 5 do
    Line(CX(2 + i * 5), CY(21 - HQ[i] * 1.8), CX(7 + i * 5), CY(21 - HQ[i + 1] * 1.8));
  Dot(CX(17), CY(13.38), PEN);
  Lab(17.8, 12.5, INK, 'you');
  DimV(CY(13.38), CY(14.88), CX(17));
  Lab(17.8, 13.7, REDPEN, '96');
  Lab(0.9, 22.2, PEN, 'camy = max(camy, TWY[648] + 96)');
  Lab(0.9, 23.4, GREY, 'Slot 648 is (12*26 + 12) * 2 - the node right under the eye,');
  Lab(0.9, 24.2, GREY, 'already worked out this frame. One compare, and it is free.');
  if upto < 3 then Exit;

  Lab(0.9, 26.2, GREY, 'AND THE PITCH KEYS SWAP OVER');
  Lab(0.9, 27.4, INK, 'DOWN puts the nose UP. It is a control column and you pull it');
  Lab(0.9, 28.4, INK, 'towards you to climb. Two lines exchanged, and it is right.');
end;

{ ==========================================================================
   PAGE 4 - once a node, not four times.

   The counting page. 25 squares across means 625 squares; each draws two
   edges and each edge has two ends, so the old way rotated 2500 points a
   frame. There are only 26 x 26 = 676 nodes. TERRPREP does each one once
   and the drawing loop reads a cache.
   ========================================================================== }
procedure PageOnce(upto: Integer);
var
  i, j : Integer;
begin
  Head(0.9, 0.7, INK, 'once a node, not four times');
  Lab(0.9, 2.3, REDPEN, 'A node belongs to FOUR squares. Look at the one in the middle.');
  for i := 0 to 2 do
    for j := 0 to 2 do
      Box(2 + i * 3, 4.6 + j * 3, 5 + i * 3, 7.6 + j * 3, PENCIL);
  Thick(CX(5), CY(7.6), CX(11), CY(7.6), GREEN);
  Thick(CX(5), CY(13.6), CX(11), CY(13.6), GREEN);
  Thick(CX(5), CY(7.6), CX(5), CY(13.6), GREEN);
  Thick(CX(11), CY(7.6), CX(11), CY(13.6), GREEN);
  Thick(CX(5), CY(10.6), CX(11), CY(10.6), GREEN);
  Thick(CX(8), CY(7.6), CX(8), CY(13.6), GREEN);
  Dot(CX(8), CY(10.6), REDPEN);
  Lab(13, 9, INK, 'four squares meet here, and');
  Lab(13, 10, INK, 'each one used to rotate this');
  Lab(13, 11, INK, 'node for itself. The same');
  Lab(13, 12, INK, 'sum, four times over.');
  if upto < 2 then Exit;

  Lab(0.9, 15, GREY, 'COUNT THE OLD WAY. The lattice is 25 squares each way:');
  Lab(1.8, 16.4, INK, '25 * 25 = 625 squares');
  Lab(1.8, 17.4, INK, '625 * 2 edges * 2 ends = 2500 rotations a frame');
  if upto < 3 then Exit;

  Lab(0.9, 19.4, GREY, 'COUNT THE NEW WAY. There are only so many nodes:');
  Lab(1.8, 20.8, INK, '26 * 26 = 676 nodes, each rotated once');
  Lab(1.8, 22, REDPEN, '2500 / 676 = 3.7 times less work, same picture');
  Ring(1.8, 22, 22);
  if upto < 4 then Exit;

  Lab(0.9, 24.4, GREY, 'AND WHILE WE ARE THERE, cache the colour band as well:');
  Lab(1.8, 25.8, PEN, 'TRX  TRZ   the turned position of every node');
  Lab(1.8, 26.8, PEN, 'TWY        its height in the world');
  Lab(1.8, 27.8, PEN, 'TCOL       its colour - so the drawing loop never');
  Lab(1.8, 28.8, PEN, '           touches the map at all');
end;

{ ==========================================================================
   PAGE 5 - a wireframe has no front and no back.

   The problem, drawn. Both ridges are in front of the eye and both are
   on the screen, so neither clipper has anything to say. The far one is
   simply BEHIND, and nothing in a screen full of bytes records that.
   ========================================================================== }
procedure PageThru(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'a wireframe has no front and no back');
  Lab(0.9, 2.3, REDPEN, 'SIDE ON. The eye on the left, two ridges in front of it.');
  Dot(CX(2.4), CY(10), PEN);
  Lab(1.4, 8.6, INK, 'eye');
  SetColor(PEN);
  Line(CX(8), CY(14), CX(11), CY(8));
  Line(CX(11), CY(8), CX(14), CY(14));
  Lab(9.4, 14.4, INK, 'near');
  Line(CX(20), CY(14), CX(24), CY(9.6));
  Line(CX(24), CY(9.6), CX(28), CY(14));
  Lab(22.4, 14.4, INK, 'far');
  Axis(CX(2.4), CY(10), CX(31), CY(10), PENCIL, True);
  Axis(CX(2.4), CY(10), CX(31), CY(6.2), PENCIL, True);
  Axis(CX(2.4), CY(10), CX(31), CY(14.6), PENCIL, True);
  if upto < 2 then Exit;

  Lab(0.9, 16.4, GREY, 'AND ON THE SCREEN, both of them, drawn one after the other:');
  Box(4, 17.6, 20, 24, PENCIL);
  SetColor(PEN);
  Line(CX(5), CY(23), CX(9), CY(19));
  Line(CX(9), CY(19), CX(13), CY(23));
  SetColor(REDPEN);
  Line(CX(6), CY(22.4), CX(11), CY(20.2));
  Line(CX(11), CY(20.2), CX(16), CY(22.4));
  Lab(21, 19, REDPEN, 'the far ridge comes');
  Lab(21, 20, REDPEN, 'straight through the');
  Lab(21, 21, REDPEN, 'near one. A net, not');
  Lab(21, 22, REDPEN, 'a landscape.');
  if upto < 3 then Exit;

  Lab(0.9, 25.4, INK, 'NEARCLIP throws away what is behind your head. CLIPLINE throws');
  Lab(0.9, 26.4, INK, 'away what is off the edge. This line is neither. It is on the');
  Lab(0.9, 27.4, INK, 'screen and perfectly legal - it is simply BEHIND something,');
  Lab(0.9, 28.4, INK, 'and 64000 bytes in a row do not record that.');
end;
