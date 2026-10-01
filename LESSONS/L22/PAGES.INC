{ ==========================================================================
   Shared by both page files: a filled four-sided shape, in cells.
   ========================================================================== }
procedure FillQuad(x1, y1, x2, y2, x3, y3, x4, y4: Real; c: Integer);
var p : array[1..4] of PointType;
begin
  p[1].X := CX(x1); p[1].Y := CY(y1);
  p[2].X := CX(x2); p[2].Y := CY(y2);
  p[3].X := CX(x3); p[3].Y := CY(y3);
  p[4].X := CX(x4); p[4].Y := CY(y4);
  SetFillStyle(SolidFill, c);
  SetColor(c);
  FillPoly(4, p);
end;

{ ==========================================================================
   PAGE 1 - the painter: draw it far to near.

   Lesson 15 hid the far hills with an array. This lesson paints them in
   an order and lets the paint do it. The whole change is one DEC.
   ========================================================================== }
procedure PagePaint(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'the painter: draw it far to near');
  Lab(0.9, 2.3, REDPEN, 'Lesson 15 hid the far hills with 320 bytes and a compare a pixel.');
  Dot(CX(2.4), CY(9), PEN);
  Lab(1.6, 7.6, INK, 'eye');
  SetColor(PEN);
  Line(CX(8), CY(12), CX(11), CY(6.4));
  Line(CX(11), CY(6.4), CX(14), CY(12));
  Lab(9.6, 12.4, INK, 'near');
  Line(CX(19), CY(12), CX(23), CY(7.6));
  Line(CX(23), CY(7.6), CX(27), CY(12));
  Lab(22.2, 12.4, INK, 'far');
  Axis(CX(2), CY(12), CX(30), CY(12), PENCIL, True);
  if upto < 2 then Exit;

  Lab(0.9, 14.4, GREY, 'SO PAINT THEM IN ORDER. On the screen, one after the other:');
  FillQuad(6, 22, 12, 17.4, 18, 22, 6, 22, RULE);
  Lab(13.4, 17.2, PENCIL, '1  the far one, first');
  FillQuad(3, 22, 8, 16.2, 13, 22, 3, 22, PEN);
  Lab(1.2, 23, PEN, '2  the near one, over it');
  Box(2, 15.6, 20, 23.8, PENCIL);
  Lab(21, 19, INK, 'the near hill covers the');
  Lab(21, 20, INK, 'far one because it was');
  Lab(21, 21, INK, 'painted LATER. Nothing');
  Lab(21, 22, INK, 'was tested at all.');
  if upto < 3 then Exit;

  Lab(0.9, 25, PEN, 'lesson 15:   mov [ordk],0         ...   inc word [ordk]');
  Lab(0.9, 26, PEN, 'lesson 16:   mov [ordk],the last  ...   dec word [ordk]');
  Lab(0.9, 27.6, REDPEN, 'The table did not move. One DEC for one INC.');
  Ring(0.9, 27.6, 22);
  Lab(0.9, 28.6, GREY, 'You do not pay for hiding. You get it with the colour.');
end;

{ ==========================================================================
   PAGE 2 - what FACEFILL does, and the arithmetic of one row.

   The quad is (2,4) (12,4) (16,12) (6,12) in its own cells, drawn two
   across and four down on the page. Row 8: left edge 2 + 4*4/8 = 4, right
   edge 12 + 4*4/8 = 14. That is SCANPOLY's IMUL and IDIV, per edge, per row.
   ========================================================================== }
procedure PageFace(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'what FACEFILL does');
  Lab(0.9, 2.3, REDPEN, 'Lesson 13 did four jobs for a LINE. The engine does them for a FACE.');
  Lab(1.8, 3.8, INK, '1  clip it to the near plane        (CLIPNEAR)');
  Lab(1.8, 4.8, INK, '2  project every corner that is left (PROJPOLY)');
  Lab(1.8, 5.8, INK, '3  fill between the edges, a row at a time (SCANPOLY)');
  Lab(1.8, 7, GREY, 'and the screen clip is inside the third: a row is cut to 0..319.');
  if upto < 2 then Exit;

  SetColor(PEN);
  Line(CX(4), CY(12), CX(14), CY(12));
  Line(CX(14), CY(12), CX(18), CY(20));
  Line(CX(18), CY(20), CX(8), CY(20));
  Line(CX(8), CY(20), CX(4), CY(12));
  Dot(CX(4), CY(12), PEN);   Lab(1.6, 11.2, PEN, '(2,4)');
  Dot(CX(14), CY(12), PEN);  Lab(13.6, 11.2, PEN, '(12,4)');
  Dot(CX(18), CY(20), PEN);  Lab(18.4, 20.2, PEN, '(16,12)');
  Dot(CX(8), CY(20), PEN);   Lab(5, 20.6, PEN, '(6,12)');
  Thick(CX(6), CY(16), CX(16), CY(16), REDPEN);
  Lab(0.9, 15.7, REDPEN, 'row 8');
  Lab(6, 16.4, REDPEN, '4');
  Lab(15.8, 16.4, REDPEN, '14');
  if upto < 3 then Exit;

  Lab(20.6, 11.4, GREY, 'WHERE A ROW CROSSES AN EDGE:');
  Lab(20.6, 12.6, PEN, 'x = x0 + (x1-x0)(y-y0)');
  Lab(20.6, 13.4, PEN, '         / (y1-y0)');
  Lab(20.6, 14.8, INK, 'left:  2 + 4*4/8 =  4');
  Lab(20.6, 15.8, INK, 'right: 12 + 4*4/8 = 14');
  Lab(20.6, 17.2, INK, 'fill 4 to 14. Done.');
  Lab(0.9, 23, REDPEN, 'One IMUL and one IDIV, for every edge, on every row. That is');
  Lab(0.9, 24, REDPEN, 'SCANPOLY, and it is why a tall square costs more than a flat one.');
  Lab(0.9, 25.6, GREY, 'The game calls exactly this routine. Not a line of it is ours.');
end;

{ ==========================================================================
   PAGE 3 - the colour, and the fold.

   Corners 128 141 176 150: tallest 176, woods, colour 4, fold 12.
   ========================================================================== }
procedure PageFold(upto: Integer);
var i : Integer;
begin
  Head(0.9, 0.7, INK, 'the colour, and the fold');
  Lab(0.9, 2.3, REDPEN, 'A square is ONE colour, and it is its TALLEST corner''s.');
  Box(3, 4.4, 11, 10.4, PEN);
  Lab(1.2, 3.6, INK, '128');
  Lab(10.6, 3.6, INK, '141');
  Lab(10.6, 10.8, REDPEN, '176');
  Ring(10.6, 10.8, 1.5);
  Lab(1.2, 10.8, INK, '150');
  Lab(13, 6, GREY, 'the map bytes at its four');
  Lab(13, 7, GREY, 'corners. Take the lowest and');
  Lab(13, 8, GREY, 'a snow cap grows a ring of rock.');
  if upto < 2 then Exit;

  Lab(0.9, 12.6, GREY, 'THE LADDER, and 176 lands on the fourth rung:');
  Lab(1.8, 13.8, INK, 'under 88 sea 1   under 120 sand 2   under 168 grass 3');
  Lab(1.8, 14.8, REDPEN, 'under 200 woods 4');
  Lab(10.4, 14.8, INK, '  under 230 rock 5   else snow 6');
  if upto < 3 then Exit;

  Lab(0.9, 16.8, GREY, 'THE PALETTE IS IN TWO HALVES, EIGHT APART:');
  for i := 1 to 8 do
  begin
    Box(1.8 + (i - 1) * 2.4, 18, 3.8 + (i - 1) * 2.4, 19.6, PEN);
    Lab(2.4 + (i - 1) * 2.4, 18.5, PEN, Chr(Ord('0') + i));
  end;
  for i := 9 to 14 do
  begin
    Box(1.8 + (i - 9) * 2.4, 21, 3.8 + (i - 9) * 2.4, 22.6, PEN);
    if i < 10 then Lab(2.4 + (i - 9) * 2.4, 21.5, PEN, '9')
    else Lab(2.2 + (i - 9) * 2.4, 21.5, PEN, '1' + Chr(Ord('0') + i - 10));
  end;
  Lab(21.4, 18.5, GREY, '7 crash red, 8 empty');
  Lab(16.6, 21.5, GREY, 'the same six, at half');
  Lab(16.6, 22.3, GREY, 'the brightness');
  if upto < 4 then Exit;

  Lab(0.9, 24.4, REDPEN, 'fold = colour + 8. One ADD: woods 4 -> 12, grass 3 -> 11.');
  Ring(0.9, 24.4, 13);
  Lab(0.9, 25.8, INK, 'The gap at 7 and 8 is not waste. It is what makes the ADD free.');
  Lab(0.9, 27.2, INK, 'One dark colour over everything is a WIRE lying on the picture.');
  Lab(0.9, 28.2, INK, 'The square''s own colour, darker, is a FOLD in the ground.');
end;

{ ==========================================================================
   PAGE 4 - the sea came out in waves.

   WORLDH's second instruction is MOV BX,5. A raw byte kept in BL across
   the call is eaten for every node at or above 88 - and only those.
   ========================================================================== }
procedure PageWaves(upto: Integer);
var i : Integer;
begin
  Head(0.9, 0.7, INK, 'the sea came out in waves');
  Lab(0.9, 2.3, REDPEN, 'The sea is at height nought. It is flat. So what is this?');
  Axis(CX(2), CY(8), CX(34), CY(8), PENCIL, True);
  Lab(29, 8.3, PENCIL, 'sea level');
  SetColor(PEN);
  for i := 0 to 7 do
    Line(CX(2 + i * 4), CY(8 - (i mod 2) * 2.2), CX(6 + i * 4), CY(8 - ((i + 1) mod 2) * 2.2));
  Lab(0.9, 9.6, GREY, 'blue, so the program thinks it is sea - and it has hills in it.');
  if upto < 2 then Exit;

  Lab(1.8, 11.4, PEN, 'call HGET        ; AL = the raw map byte');
  Lab(1.8, 12.4, PEN, 'mov  bl,al       ; kept... in BL');
  Lab(1.8, 13.4, PEN, 'call WORLDH      ; sub ax,88 / jns .w0 / ... .w0: mov bx,5');
  Lab(1.8, 15, INK, 'H = 130:  130 - 88 = 42, not negative, so WORLDH goes on');
  Lab(1.8, 16, INK, '          to MOV BX,5. BL comes back 5. 5 is under 88: SEA.');
  Lab(1.8, 17.4, INK, 'H =  80:   80 - 88 is negative, so WORLDH returns FIRST.');
  Lab(1.8, 18.4, INK, '          BL comes back 80. Correct.');
  Lab(0.9, 20, REDPEN, 'Only the LAND was wrong: painted as sea, with the land''s height.');
  if upto < 3 then Exit;

  Lab(0.9, 22.4, REDPEN, 'A caller may assume what a routine RETURNS.');
  Lab(0.9, 23.4, REDPEN, 'Never what it spares.');
  Box(0.6, 22.1, 23.4, 24.3, REDPEN);
  Lab(0.9, 25.4, PEN, 'mov  [rawh],al   ; in MEMORY - nothing WORLDH touches');
  Lab(0.9, 26.8, GREY, 'And look how it hid: the sea itself was always right, so the');
  Lab(0.9, 27.8, GREY, 'mistake only showed where nobody was looking for a mistake.');
end;

{ ==========================================================================
   PAGE 5 - a floor, and a surface.

   Lesson 15 carried you up. Lesson 16 ends the flight. The game's
   CRASHHANDLE, and what we left out.
   ========================================================================== }
procedure PageCrash(upto: Integer);
begin
  Head(0.9, 0.7, INK, 'a floor, and a surface');
  Lab(0.9, 2.3, REDPEN, 'Lesson 15: fly into the ground and it CARRIES YOU UP.');
  SetColor(PEN);
  Line(CX(2), CY(10), CX(14), CY(10));
  Line(CX(14), CY(10), CX(20), CY(7));
  Line(CX(20), CY(7), CX(30), CY(7));
  Dashed(CX(4), CY(4.6), CX(14), CY(8.6), REDPEN);
  Dashed(CX(14), CY(8.6), CX(20), CY(5.6), REDPEN);
  Dashed(CX(20), CY(5.6), CX(30), CY(5.6), REDPEN);
  Lab(22, 4.4, REDPEN, 'the path: pushed up');
  Lab(0.9, 11.6, GREY, 'That is what a FLOOR does. You cannot fly into a wireframe.');
  if upto < 2 then Exit;

  Lab(0.9, 13.6, REDPEN, 'Lesson 16: a filled hillside ENDS THE FLIGHT.');
  Lab(1.8, 15, PEN, 'dying  = 1');
  Lab(1.8, 16, PEN, 'dytick = 0');
  Lab(12, 15, INK, 'One byte, read in ONE place. The frame is');
  Lab(12, 16, INK, 'still drawn, the counter still counts; only');
  Lab(12, 17, INK, 'the model stops. A crash is a STATE.');
  if upto < 3 then Exit;

  Lab(0.9, 19.4, GREY, 'THE GAME''S CRASHHANDLE, and what we left out:');
  Lab(1.8, 20.8, PEN, 'ours:  dying = 1,  dytick = 0,  step back');
  Lab(1.8, 22, GREY, 'the game adds: a wreck that breaks up and falls, the bang,');
  Lab(1.8, 23, GREY, 'the flashback, the score. All of it is cinema.');
  Lab(0.9, 24.8, INK, 'The camera steps back 400: the game''s 100 on a 256 cell,');
  Lab(0.9, 25.8, INK, 'times four, because our node is 1024.');
  Lab(0.9, 27.4, REDPEN, 'And the first line of both is the same: a wreck cannot');
  Lab(0.9, 28.4, REDPEN, 'crash twice.');
end;
