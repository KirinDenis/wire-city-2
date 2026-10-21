{ ==========================================================================
   THE HANGAR - small things the pages share, and the transport itself.
   ========================================================================== }

{ ---- pencil furniture, lesson 19's, in pixels ---------------------------- }
procedure Axis(x1, y1, x2, y2, c: Integer; dotted: Boolean);
begin
  SetColor(c);
  if dotted then SetLineStyle(DottedLn, 0, NormWidth)
            else SetLineStyle(SolidLn, 0, NormWidth);
  Line(x1, y1, x2, y2);
  SetLineStyle(SolidLn, 0, NormWidth);
end;

procedure Dot(x, y, c: Integer);
begin
  SetFillStyle(SolidFill, c);
  SetColor(c);
  PieSlice(x, y, 0, 360, 3);
end;

procedure Thick(x1, y1, x2, y2, c: Integer);
begin
  SetColor(c);
  SetLineStyle(SolidLn, 0, ThickWidth);
  Line(x1, y1, x2, y2);
  SetLineStyle(SolidLn, 0, NormWidth);
end;

{ text at a PIXEL position, for labels that sit on a point and not in a row }
procedure LabXY(x, y: Integer; c: Integer; s: string);
begin
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(c);
  OutTextXY(x, y, s);
end;

function IStr(n: Integer): string;
var s : string;
begin
  Str(n, s);
  IStr := s;
end;

{ ---- THE TRANSPORT: HANGAR.ASM's MVERT3 and MFACE3, the same numbers ----- }
const
  NV = 13;  NF = 8;
  TX : array[0..12] of Integer = (0, -5, 5, -5, 5, -20, 20, 0, -5, 5, 0, 0, 0);
  TY : array[0..12] of Integer = (2, 6, 6, -4, -4, 3, 3, 3, 3, 3, 6, 12, 6);
  TZ : array[0..12] of Integer = (18, -14, -14, -14, -14, -2, -2, 6, -12, -12,
                                  -6, -16, -14);
  TF : array[0..7, 0..3] of Byte = ((0, 1, 2, 0), (0, 3, 4, 0), (0, 1, 3, 0),
                                    (0, 2, 4, 0), (7, 5, 8, 7), (7, 6, 9, 7),
                                    (10, 11, 12, 10), (1, 2, 4, 3));
  SCALE = 0.5;                 { one square of the paper is two units }

  V_TOP = 0;  V_SIDE = 1;  V_REAR = 2;

{ where vertex i falls on the paper, in pixels, for a view centred at cell
  (cu, cv): from above, x across and z up the page; from the side, y
  across and z up - the same rows as from above; from behind, x across and
  y up }
procedure ViewPt(kind, i: Integer; cu, cv: Real; var px, py: Integer);
var a, b : Real;
begin
  case kind of
    V_TOP  : begin a := TX[i]; b := TZ[i]; end;
    V_SIDE : begin a := TY[i]; b := TZ[i]; end;
  else       begin a := TX[i]; b := TY[i]; end;
  end;
  px := CX(cu + a * SCALE);
  py := CY(cv - b * SCALE);
end;

{ one face's four edges, corner k to corner k+1 and the last to the first -
  HANGAR.ASM's WIRE, on paper }
procedure FaceEdges(kind, f: Integer; cu, cv: Real; c: Integer; bold: Boolean);
var k, x1, y1, x2, y2 : Integer;
begin
  for k := 0 to 3 do
  begin
    ViewPt(kind, TF[f, k], cu, cv, x1, y1);
    ViewPt(kind, TF[f, (k + 1) mod 4], cu, cv, x2, y2);
    if bold then Thick(x1, y1, x2, y2, c)
    else begin SetColor(c); Line(x1, y1, x2, y2); end;
  end;
end;

{ the whole aeroplane in one view: the wire in pencil, the points in blue,
  and their numbers - two points that fall on one place share one label }
procedure DrawView(kind: Integer; cu, cv: Real);
var f, i, j, x, y, x2, y2 : Integer;
    s : string;
    first : Boolean;
begin
  for f := 0 to NF - 1 do FaceEdges(kind, f, cu, cv, PENCIL, False);
  for i := 0 to NV - 1 do
  begin
    ViewPt(kind, i, cu, cv, x, y);
    first := True;
    for j := 0 to i - 1 do
    begin
      ViewPt(kind, j, cu, cv, x2, y2);
      if (x2 = x) and (y2 = y) then first := False;
    end;
    if first then
    begin
      s := IStr(i);
      for j := i + 1 to NV - 1 do
      begin
        ViewPt(kind, j, cu, cv, x2, y2);
        if (x2 = x) and (y2 = y) then s := s + ',' + IStr(j);
      end;
      Dot(x, y, PEN);
      LabXY(x + 5, y - 10, PEN, s);
    end;
  end;
end;

{ ==========================================================================
   PAGE 1 - an aeroplane is a list of points. The transport from above and
   from the side, every point numbered; then one of them as a table row.
   ========================================================================== }
procedure PagePoints(upto: Integer);
begin
  Big(1, 1, INK, 'AN AEROPLANE IS POINTS');
  Lab(1, 3, REDPEN, 'Lesson 1E: the hangar. The transport, on squared paper.');
  DrawView(V_TOP, 11, 14);
  Lab(3, 24, PEN, 'FROM ABOVE: x across, z along');
  Lab(3, 25, PENCIL, 'a square here is two units');
  if upto < 2 then Exit;

  DrawView(V_SIDE, 27, 14);
  Lab(21, 24, PEN, 'FROM THE SIDE: y across');
  Lab(21, 25, PENCIL, 'the same z, the same rows');
  if upto < 3 then Exit;

  Lab(1, 27, INK, 'Vertex 5, the left wing tip: 20 left, 3 up, 2 back -');
  Lab(28, 27, REDPEN, 'dw -20,3,-2');
  Ring(28, 27, 6);
  Lab(1, 28, INK, 'Thirteen rows like it, 78 bytes. No outline is stored anywhere.');
end;

{ ==========================================================================
   PAGE 2 - faces. Four vertex numbers and a colour; a triangle names one
   vertex twice; the nozzle from behind; the bytes of an aeroplane.
   ========================================================================== }
procedure PageFaces(upto: Integer);
var x, y, i : Integer;
begin
  Big(1, 1, INK, 'FACES: FOUR NUMBERS AND A COLOUR');
  DrawView(V_TOP, 11, 14);
  FaceEdges(V_TOP, 4, 11, 14, REDPEN, True);
  Lab(22, 5, REDPEN, 'db 7,5,8,7, 27');
  Lab(22, 6, INK, 'the left wing. Four');
  Lab(22, 7, INK, 'vertex numbers round');
  Lab(22, 8, INK, 'the face, then a colour.');
  Lab(22, 10, INK, 'A triangle names one');
  Lab(22, 11, INK, 'vertex twice: 7 ... 7.');
  if upto < 2 then Exit;

  FaceEdges(V_REAR, 7, 28, 17.5, REDPEN, True);
  for i := 1 to 4 do
  begin
    ViewPt(V_REAR, i, 28, 17.5, x, y);
    Dot(x, y, PEN);
    if TX[i] < 0 then LabXY(x - 12, y - 4, PEN, IStr(i))
                 else LabXY(x + 6, y - 4, PEN, IStr(i));
  end;
  Lab(22, 13, REDPEN, 'db 1,2,4,3, 94');
  Lab(22, 20, INK, 'the nozzle, from behind:');
  Lab(22, 21, INK, 'a square, 1 2 4 3 round');
  Lab(22, 22, INK, 'it. GLOW makes 94 burn.');
  if upto < 3 then Exit;

  Lab(1, 25, INK, 'Eight faces of five bytes, 40:');
  Lab(17, 25, REDPEN, 'transport: 78 + 40 = 118 bytes');
  Ring(17, 25, 15);
  Lab(1, 27, INK, 'Fighter, radar and tanker are these 13 points and 8 faces, moved;');
  Lab(1, 28, INK, 'the bomber adds four engines, the radar a dome, the tanker two.');
end;

{ ==========================================================================
   PAGE 3 - every frame, from the table. Vertex 5 through the spin, the
   tilt and the lens, in HANGAR.ASM's own arithmetic.
   ========================================================================== }
procedure PageFrame(upto: Integer);
begin
  Big(1, 1, INK, 'EVERY FRAME, FROM THE TABLE');
  Lab(1, 3, INK, 'Nothing is kept from the last frame: each point is made again.');
  Lab(1, 5, PEN, 'THE SPIN, about the vertical - the island''s rotate:');
  Lab(2, 6, PEN, 'x'' = (x cos + z sin) / 32      z'' = (z cos - x sin) / 32');
  Lab(2, 7, PENCIL, '/32 is x8 and /256 in one divide: a square of the table is 8 units');
  Lab(1, 9, INK, 'Vertex 5, dw -20,3,-2, the stand turned 45 degrees: sin = cos = 181');
  Lab(2, 10, PEN, 'x'' = (-3620 - 362) / 32 = -124     z'' = (-362 + 3620) / 32 = 101');
  Lab(2, 11, PEN, 'y'' = 3 x 8 = 24');
  if upto < 2 then Exit;

  Lab(1, 13, PEN, 'THE TILT, 20 degrees towards us - the same rotate, about the wings:');
  Lab(2, 14, PEN, 'y" = (y'' x 241 + z'' x 88) / 256 - 20     cos 20 = 241, sin 20 = 88');
  Lab(2, 15, PEN, 'z" = (z'' x 241 - y'' x 88) / 256 + 400   400: how far back it stands');
  Lab(2, 16, PEN, 'y" = 14672 / 256 - 20 = 37         z" = 22229 / 256 + 400 = 486');
  Lab(1, 18, INK, 'The bomber''s fin top, turned half round: 104 x 241 + 208 x 88 =');
  Lab(1, 19, INK, '43368 - past 32767. IMUL leaves a double word in DX:AX; ADD the low');
  Lab(1, 20, INK, 'words, ADC the high ones with the carry, and IDIV takes DX:AX back.');
  if upto < 3 then Exit;

  Lab(1, 22, PEN, 'THE LENS, lesson 0F''s one divide:');
  Lab(2, 23, PEN, 'sx = 160 + x'' x 220 / z" = 160 - 27280 / 486 = 104');
  Lab(2, 24, PEN, 'sy = 100 - y" x 220 / z" = 100 -  8140 / 486 =  84');
  Lab(1, 26, REDPEN, 'The left wing tip is at (104, 84) - this frame.');
  Ring(1, 26, 24);
end;
