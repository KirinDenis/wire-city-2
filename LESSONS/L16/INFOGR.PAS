{ ==========================================================================
  INFOGR.PAS - the opening infographic for lesson 10 (the view matrix, the
  projection matrix, and the discovery that a picture cannot tell you
  whether the cube moved or the camera did).

     D:\BIN\TPC.EXE -B -UD:\UNITS INFOGR.PAS     (see MAKEINFO.BAT)

  NOT PART OF THE LESSON - the title sequence the video opens with, and in
  this lesson it carries the THEORY: three spaces, two matrices, and the
  names for them. BGI has 640x480 and letters; the COM has 320x200 and
  none, so the vocabulary is taught here.

  THE NAMES ARE THE CLASSICAL ONES AND THAT IS DELIBERATE. Model, view,
  projection. A student who learns a private vocabulary here will open any
  graphics book afterwards and find nothing he recognises. The pilot's
  ruling, 2026-09-11, and it re-scoped the whole lesson.

  THE LADDER IT CLIMBS:
     two motions, one picture - the discovery, teased and not explained
   - three spaces and two matrices, with their proper names
   - MODEL space: the cube's own corners, from lesson 0E
   - the MODEL matrix: turn it, then place it
   - WORLD space - and it is nearly empty, on purpose. Two lessons away.
   - the camera: a place to stand and a way to face
   - the VIEW matrix IS THE INVERSE of the camera's placement
   - and inverting a turn is FREE: transpose it, and it turns back
   - VIEW space: everything measured from an eye at the origin
   - the PROJECTION matrix, classical - and why ours is a bare divide
   - move the cube:   the plan, and the glass
   - move the camera: the plan, and the SAME glass
   - the two sheets of glass side by side. They are identical.
   - where the trick stops: turning is not symmetric
   - the closing card

  ONE COLOUR, ONE MEANING:
     white      an edge of the cube, and the glass it lands on
     green      the cube's own frame and its model matrix
     cyan       the camera, and everything belonging to the view matrix
     magenta    the ONE argued thing: whichever matrix is live
     yellow     the eye's axis, and the origin of whichever space is shown
     dark grey  what is absent, deferred, or thrown away

  TP7 SCARS: a source line dies past 126 characters; a BGI string too wide
  for 640 pixels is refused outright. Cap1 <= 39 chars, Cap2 <= 78.

  Keys: any key = next step, ESC = leave early.
  INFOGR N starts at step N (the state fast-forwards honestly).

  Owlos - legacy software modernization - https://owlos.sk
  ========================================================================== }
program Infogr;

uses Graph, Crt;

const
  BgCol  = Blue;
  EdgeC  = White;                    { an edge, and the glass              }
  ModelC = LightGreen;               { the cube's own frame                }
  CamC   = LightCyan;                { the camera and the view matrix      }
  ArgC   = LightMagenta;             { the ONE argued thing                }
  AxisC  = Yellow;                   { an origin, and the eye's axis       }
  GoneC  = DarkGray;                 { absent, deferred, or thrown away    }

  DEYE   = 270;                      { lesson 0F's d - sixty degrees       }
  HOMEZ  = 170;                      { where the cube stands               }
  MYAW   = 34;                       { its resting yaw, in degrees         }
  MPITCH = 28;                       { and its fixed tilt, so it reads     }

  PCX    = 132;  PBY = 396;          { the PLAN view: where world zero is  }
  PSC    = 10;   PSD = 9;            { ...and its scale, 10/9              }

  LegX   = 486;
  LegY   = 96;

  VX : array[0..7] of Integer = (-18, 18, 18,-18,-18, 18, 18,-18);
  VY : array[0..7] of Integer = (-18,-18, 18, 18,-18,-18, 18, 18);
  VZ : array[0..7] of Integer = (-18,-18,-18,-18, 18, 18, 18, 18);
  EA : array[0..11] of Integer = (0,1,2,3,4,5,6,7,0,1,2,3);
  EB : array[0..11] of Integer = (1,2,3,0,5,6,7,4,4,5,6,7);

var
  GXa, GYa : array[0..7] of Integer; { the eight corners, in 320x200       }
  ObjX, ObjZ : Real;                 { the MODEL matrix, as numbers        }
  ObjYaw   : Real;
  CamX, CamZ : Real;                 { the VIEW matrix, as numbers         }
  CamYaw   : Real;
  View     : Integer;                { 0 glass 1 pipeline 2 model 3 world  }
                                     { 4 plan+glass 5 twoglass 6 text      }
  Mat      : Integer;                { which matrix is on show: 0..4       }
  Scene    : Integer;
  ShowFrame, ShowCam : Boolean;
  HasModel, HasView, HasProj : Boolean;
  DoSlide, DoCamSlide, DoSpin, DoCamTurn : Boolean;
  Cap1, Cap2 : string;
  Step     : Integer;
  Ch       : Char;

procedure Headline;
begin
  SetTextStyle(DefaultFont, HorizDir, 2);
  SetTextJustify(CenterText, TopText);
  SetColor(White);
  OutTextXY(320, 10, 'MOVE THE CAMERA, OR MOVE THE CUBE');
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetColor(LightCyan);
  OutTextXY(320, 36, 'the view matrix, the projection matrix, and a picture that cannot tell');
end;

procedure Captions;
var S: string;
begin
  SetFillStyle(SolidFill, Black);
  Bar(0, 434, 639, 479);
  Str(Step, S);
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(RightText, TopText);
  SetColor(DarkGray);
  OutTextXY(634, 470, S);
  SetColor(Yellow);
  SetTextStyle(DefaultFont, HorizDir, 2);
  SetTextJustify(CenterText, TopText);
  OutTextXY(320, 440, Cap1);
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetColor(White);
  OutTextXY(320, 462, Cap2);
end;

procedure Legend;
var Y: Integer;
begin
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(White);
  OutTextXY(LegX, LegY, 'THE NAMES');
  Line(LegX, LegY + 12, 632, LegY + 12);
  Y := LegY + 24;
  if HasModel then begin
    SetColor(ModelC);
    OutTextXY(LegX, Y, 'MODEL');
    SetColor(LightCyan);
    OutTextXY(LegX, Y + 14, 'turn it, place it:');
    OutTextXY(LegX, Y + 26, 'where the cube is');
    Y := Y + 46;
  end;
  if HasView then begin
    SetColor(CamC);
    OutTextXY(LegX, Y, 'VIEW');
    SetColor(LightCyan);
    OutTextXY(LegX, Y + 14, 'the INVERSE of');
    OutTextXY(LegX, Y + 26, 'placing the camera');
    Y := Y + 46;
  end;
  if HasProj then begin
    SetColor(ArgC);
    OutTextXY(LegX, Y, 'PROJECTION');
    SetColor(LightCyan);
    OutTextXY(LegX, Y + 14, 'z into w, then');
    OutTextXY(LegX, Y + 26, 'divide by w');
  end;
end;

{ ---- the pipeline, once - and this is the slide that matters ---------- }
procedure Pipeline;
  procedure Box(y: Integer; nm, sub: string; c: Integer);
  begin
    SetColor(c);
    Rectangle(60, y, 300, y + 34);
    SetTextStyle(DefaultFont, HorizDir, 1);
    SetTextJustify(LeftText, TopText);
    OutTextXY(72, y + 6, nm);
    SetColor(LightCyan);
    OutTextXY(72, y + 20, sub);
  end;
  procedure Arrow(y: Integer; nm: string; c: Integer);
  begin
    SetColor(c);
    Line(180, y, 180, y + 26);
    Line(180, y + 26, 175, y + 19);
    Line(180, y + 26, 185, y + 19);
    SetTextJustify(LeftText, TopText);
    OutTextXY(196, y + 8, nm);
  end;
begin
  Box(100, 'MODEL SPACE',   'the cube''s own corners', ModelC);
  Arrow(134, 'the MODEL matrix', ModelC);
  Box(160, 'WORLD SPACE',   'the cube, placed somewhere', EdgeC);
  Arrow(194, 'the VIEW matrix', CamC);
  Box(220, 'VIEW SPACE',    'measured from the eye', CamC);
  Arrow(254, 'the PROJECTION', ArgC);
  Box(280, 'THE GLASS',     'two numbers, and a pixel', EdgeC);
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(GoneC);
  OutTextXY(60, 336, 'Those are not our names for them. They are');
  OutTextXY(60, 350, 'everybody''s. Learn them here and every book');
  OutTextXY(60, 364, 'you open afterwards is talking about these.');
end;

{ ---- the matrices, written out the way a book writes them ------------- }
procedure MatPanel;
begin
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  if Mat = 1 then begin              { the MODEL matrix                   }
    SetColor(White);
    OutTextXY(40, 104, 'THE MODEL MATRIX - turn, then place:');
    SetColor(ArgC);
    OutTextXY(40, 134, '| cos a   0   sin a  |  tx |');
    OutTextXY(40, 148, '|   0     1     0    |  ty |');
    OutTextXY(40, 162, '| -sin a  0   cos a  |  tz |');
    OutTextXY(40, 176, '|   0     0     0    |  1  |');
    SetColor(LightCyan);
    OutTextXY(40, 204, 'The left three columns turn it.');
    OutTextXY(40, 218, 'The fourth says where it stands.');
    SetColor(White);
    OutTextXY(40, 248, 'In the program that is two calls to');
    OutTextXY(40, 262, 'Rot2 and three adds. Same thing,');
    OutTextXY(40, 276, 'written without the ceremony.');
    SetColor(GoneC);
    OutTextXY(40, 306, 'Both are read RIGHT TO LEFT: turn');
    OutTextXY(40, 320, 'first, then move. Swap them and the');
    OutTextXY(40, 334, 'cube orbits the origin instead.');
  end;
  if Mat = 2 then begin              { the VIEW matrix                    }
    SetColor(White);
    OutTextXY(40, 100, 'TO PLACE A CAMERA at c, turned by a:');
    SetColor(GoneC);
    OutTextXY(40, 122, '     T(c) x R(a)');
    SetColor(White);
    OutTextXY(40, 150, 'TO LOOK THROUGH IT, invert that -');
    OutTextXY(40, 164, 'and inverting reverses the order:');
    SetColor(ArgC);
    OutTextXY(40, 192, '     R(-a) x T(-c)');
    SetColor(LightCyan);
    OutTextXY(40, 220, 'THAT IS THE VIEW MATRIX. Subtract');
    OutTextXY(40, 234, 'where the camera is, then turn by');
    OutTextXY(40, 248, 'minus its angle. Both halves flipped,');
    OutTextXY(40, 262, 'and in the opposite order.');
    SetColor(White);
    OutTextXY(40, 292, 'Every engine has this under this name.');
    SetColor(ArgC);
    OutTextXY(40, 318, 'LOOKING IS THE INVERSE OF PLACING.');
  end;
  if Mat = 3 then begin              { the transpose                      }
    SetColor(White);
    OutTextXY(40, 104, 'A TURN BY a:');
    SetColor(ArgC);
    OutTextXY(40, 128, '   | cos a  -sin a |');
    OutTextXY(40, 142, '   | sin a   cos a |');
    SetColor(White);
    OutTextXY(40, 172, 'FLIP IT ABOUT ITS DIAGONAL -');
    OutTextXY(40, 186, 'that is called the TRANSPOSE:');
    SetColor(ArgC);
    OutTextXY(40, 210, '   | cos a   sin a |');
    OutTextXY(40, 224, '   | -sin a  cos a |');
    SetColor(LightCyan);
    OutTextXY(40, 254, 'And cos(-a) is cos a, while sin(-a)');
    OutTextXY(40, 268, 'is minus sin a. So that IS the turn');
    OutTextXY(40, 282, 'by MINUS a. The same matrix, back.');
    SetColor(White);
    OutTextXY(40, 312, 'INVERTING A ROTATION IS FREE.');
    SetColor(LightCyan);
    OutTextXY(40, 332, 'No division. No determinant. Not even');
    OutTextXY(40, 346, 'a second table. On this chip: NEG AL.');
  end;
  if Mat = 4 then begin              { the PROJECTION matrix              }
    SetColor(White);
    OutTextXY(40, 100, 'THE PROJECTION MATRIX, as a book has it:');
    SetColor(ArgC);
    OutTextXY(40, 128, '| d  0  0  0 |');
    OutTextXY(40, 142, '| 0  d  0  0 |');
    OutTextXY(40, 156, '| 0  0  1  0 |');
    OutTextXY(40, 170, '| 0  0  1  0 |');
    SetColor(LightCyan);
    OutTextXY(40, 192, 'The last row copies z into w.');
    OutTextXY(40, 212, 'Out comes (dx, dy, z, z) - and then,');
    OutTextXY(40, 226, 'at the very end, x/w and y/w.');
    SetColor(White);
    OutTextXY(40, 254, 'x/w IS x*d/z. It is last lesson''s');
    OutTextXY(40, 268, 'divide, wearing a hat.');
    SetColor(GoneC);
    OutTextXY(40, 298, 'WHY THE HAT? So that a LONG CHAIN of');
    OutTextXY(40, 312, 'matrices can be multiplied together');
    OutTextXY(40, 326, 'first, and the divide paid ONCE at the');
    OutTextXY(40, 340, 'end. We have no chain. We have one');
    OutTextXY(40, 354, 'divide, done where it happens.');
  end;
end;

{ ---- the cube, projected into a 320x200 picture ---------------------- }
procedure Place;
var i: Integer;
    x, y, z, t, ca, sa, dz: Real;
begin
  for i := 0 to 7 do begin
    x := VX[i];  y := VY[i];  z := VZ[i];
    ca := Cos(ObjYaw * Pi / 180);  sa := Sin(ObjYaw * Pi / 180);
    t := x*ca - z*sa;  z := x*sa + z*ca;  x := t;
    ca := Cos(MPITCH * Pi / 180);  sa := Sin(MPITCH * Pi / 180);
    t := y*ca - z*sa;  z := y*sa + z*ca;  y := t;
    x := x + ObjX - CamX;                { MODEL place, then VIEW minus   }
    z := z + HOMEZ - CamZ;
    ca := Cos(-CamYaw * Pi / 180);  sa := Sin(-CamYaw * Pi / 180);
    t := x*ca - z*sa;  z := x*sa + z*ca;  x := t;
    if z < 40 then z := 40;
    GXa[i] := 160 + Round(x * DEYE / z);
    GYa[i] := 100 - Round(y * DEYE / z);
  end;
end;

{ ---- a sheet of glass, with the cube on it --------------------------- }
procedure GlassAt(gx, gy, gw: Integer; lab: string);
var i, gh, ax, ay, bx, by: Integer;
    s: Real;
begin
  s := gw / 320.0;
  gh := Round(200 * s);
  SetColor(GoneC);
  Rectangle(gx, gy, gx + gw, gy + gh);
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(CenterText, TopText);
  OutTextXY(gx + gw div 2, gy + gh + 6, lab);
  SetColor(AxisC);                   { the eye's axis, nailed to the middle }
  Line(gx + gw div 2 - 4, gy + gh div 2, gx + gw div 2 + 4, gy + gh div 2);
  Line(gx + gw div 2, gy + gh div 2 - 4, gx + gw div 2, gy + gh div 2 + 4);
  SetColor(EdgeC);
  for i := 0 to 11 do begin
    ax := gx + Round(GXa[EA[i]] * s);
    ay := gy + Round(GYa[EA[i]] * s);
    bx := gx + Round(GXa[EB[i]] * s);
    by := gy + Round(GYa[EB[i]] * s);
    if (ax > gx) and (ax < gx + gw) and (bx > gx) and (bx < gx + gw) and
       (ay > gy) and (ay < gy + gh) and (by > gy) and (by < gy + gh) then
      Line(ax, ay, bx, by);
  end;
end;

{ ---- walk a ray's far end back until it is inside the play field ------
  The field-of-view rays are long, and a long ray out of a camera near the
  bottom of the plan will happily draw straight over the headline - BGI
  clips to the viewport and we have not set one. Lesson 0F lost a title
  bar to exactly this. Rather than shift every coordinate in this file
  into viewport space, the two rays that CAN escape are shortened until
  they cannot.                                                           }
procedure ClipRay(sx, sy: Integer; var ex, ey: Integer);
var n: Integer;
begin
  n := 0;
  while ((ex < 24) or (ex > 466) or (ey < 88) or (ey > 426)) and (n < 60) do
  begin
    ex := sx + (ex - sx) * 9 div 10;
    ey := sy + (ey - sy) * 9 div 10;
    n := n + 1;
  end;
end;

{ ---- the world from above: where the camera is, where the cube is ---- }
procedure PlanView(gx: Integer);
var cx, cy, ox, oy, i, rx, ry: Integer;
    a: Real;
    qx, qy: array[0..3] of Integer;
begin
  cx := gx + Round(CamX * PSC / PSD);
  cy := PBY - Round(CamZ * PSC / PSD);
  ox := gx + Round(ObjX * PSC / PSD);
  oy := PBY - Round(HOMEZ * PSC / PSD);

  SetColor(GoneC);                   { the ground, seen from above        }
  Line(gx - 96, PBY, gx + 96, PBY);
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(CenterText, TopText);
  OutTextXY(gx, PBY + 16, 'seen from above');

  SetColor(CamC);                    { the field of view, two dashed rays }
  SetLineStyle(DottedLn, 0, NormWidth);
  for i := 0 to 1 do begin
    a := (CamYaw + (i * 2 - 1) * 30) * Pi / 180;
    rx := cx + Round(Sin(a) * 230);
    ry := cy - Round(Cos(a) * 230);
    ClipRay(cx, cy, rx, ry);
    Line(cx, cy, rx, ry);
  end;
  SetLineStyle(SolidLn, 0, NormWidth);

  SetColor(ModelC);                  { the cube, from above: a square     }
  for i := 0 to 3 do begin
    a := (ObjYaw + 45 + i * 90) * Pi / 180;
    qx[i] := ox + Round(Sin(a) * 26 * PSC / PSD);
    qy[i] := oy - Round(Cos(a) * 26 * PSC / PSD);
  end;
  for i := 0 to 3 do
    Line(qx[i], qy[i], qx[(i + 1) mod 4], qy[(i + 1) mod 4]);
  SetTextJustify(CenterText, TopText);
  OutTextXY(ox, oy - 34, 'the cube');

  SetColor(CamC);                    { the camera: a little arrowhead     }
  a := CamYaw * Pi / 180;
  Line(cx, cy, cx + Round(Sin(a - 2.4) * 14), cy - Round(Cos(a - 2.4) * 14));
  Line(cx, cy, cx + Round(Sin(a + 2.4) * 14), cy - Round(Cos(a + 2.4) * 14));
  Line(cx + Round(Sin(a - 2.4) * 14), cy - Round(Cos(a - 2.4) * 14),
       cx + Round(Sin(a + 2.4) * 14), cy - Round(Cos(a + 2.4) * 14));
  OutTextXY(cx, cy + 10, 'the camera');
end;

procedure PlayField;
begin
  SetFillStyle(SolidFill, BgCol);
  Bar(20, 84, 470, 430);
  case View of
    0: begin Place; GlassAt(115, 150, 260, 'what the glass shows'); end;
    1: Pipeline;
    2: begin                         { model space: the cube, and its own }
         Place;                      {  frame drawn on it                 }
         GlassAt(115, 150, 260, 'the cube, and nothing else');
       end;
    4: begin                         { the plan AND the glass, together   }
         PlanView(132);
         Place;
         GlassAt(258, 150, 200, 'what the glass shows');
       end;
    6: MatPanel;
  end;
end;

procedure DrawMain;
begin
  SetFillStyle(SolidFill, BgCol);
  Bar(0, 0, 639, 479);
  Headline;
  Legend;
  PlayField;
  Captions;
end;

procedure DrawFinal;
begin
  SetFillStyle(SolidFill, BgCol);
  Bar(0, 0, 639, 479);
  Headline;
  SetTextStyle(DefaultFont, HorizDir, 3);
  SetTextJustify(CenterText, CenterText);
  SetColor(ModelC);
  OutTextXY(320, 150, 'MODEL.');
  SetColor(CamC);
  OutTextXY(320, 195, 'VIEW.');
  SetColor(ArgC);
  OutTextXY(320, 240, 'PROJECTION.');
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetColor(LightCyan);
  OutTextXY(320, 285, 'three spaces, two matrices, and a divide you already wrote');
  SetColor(White);
  OutTextXY(320, 310, 'and a picture that cannot tell you which of two things moved');
  SetColor(DarkGray);
  OutTextXY(320, 334, 'because only where the eye is RELATIVE to the cube decides it');
  Captions;
end;

procedure DrawAll;
begin
  if Scene = 0 then DrawMain else DrawFinal;
end;

{ ---- the little films ------------------------------------------------- }
procedure AnimSlide;                 { the cube walks, and comes back     }
var i: Integer;
begin
  for i := 1 to 44 do begin ObjX := ObjX + 1; PlayField; Delay(26); end;
  for i := 1 to 88 do begin ObjX := ObjX - 1; PlayField; Delay(26); end;
  for i := 1 to 44 do begin ObjX := ObjX + 1; PlayField; Delay(26); end;
end;

procedure AnimCamSlide;              { the camera walks the other way     }
var i: Integer;
begin
  for i := 1 to 44 do begin CamX := CamX - 1; PlayField; Delay(26); end;
  for i := 1 to 88 do begin CamX := CamX + 1; PlayField; Delay(26); end;
  for i := 1 to 44 do begin CamX := CamX - 1; PlayField; Delay(26); end;
end;

procedure AnimSpin;                  { the cube turns where it stands     }
var i: Integer;
begin
  for i := 1 to 150 do begin ObjYaw := ObjYaw + 2.4; PlayField; Delay(24); end;
end;

procedure AnimCamTurn;               { the camera turns, and it is not    }
var i: Integer;                      {  the same thing at all             }
begin
  for i := 1 to 30 do begin CamYaw := CamYaw + 0.5; PlayField; Delay(30); end;
  for i := 1 to 60 do begin CamYaw := CamYaw - 0.5; PlayField; Delay(30); end;
  for i := 1 to 30 do begin CamYaw := CamYaw + 0.5; PlayField; Delay(30); end;
end;

procedure SetStep(N: Integer);
begin
  DoSlide := False;  DoCamSlide := False;  DoSpin := False;
  DoCamTurn := False;
  case N of
    0: begin
         Scene := 0;  View := 0;  Mat := 0;
         HasModel := False; HasView := False; HasProj := False;
         ObjX := 0;  ObjZ := HOMEZ;  ObjYaw := MYAW;
         CamX := 0;  CamZ := 0;  CamYaw := 0;
         DoSlide := True;
         Cap1 := 'Two motions. One picture.';
         Cap2 := 'By the end of this hour you will not be able to tell which one happened.';
       end;
    1: begin View := 1;  ObjX := 0;
         Cap1 := 'Three spaces, two matrices.';
         Cap2 := 'Model, view, projection - and those are the names everybody else uses.';
       end;
    2: begin View := 2;  HasModel := True;
         Cap1 := 'Model space: the cube alone.';
         Cap2 := 'Eight corners from its own centre. It does not know where it is standing.';
       end;
    3: begin View := 6;  Mat := 1;
         Cap1 := 'The MODEL matrix puts it there.';
         Cap2 := 'Turn it, then move it. Those two operations together ARE the matrix.';
       end;
    4: begin View := 4;  Mat := 0;
         Cap1 := 'World space: the cube, placed.';
         Cap2 := 'One cube makes a thin world. We fill it in two lessons; today one is enough.';
       end;
    5: begin
         Cap1 := 'And here is the camera.';
         Cap2 := 'A place to stand and a way to face - exactly as much as the cube has.';
       end;
    6: begin View := 6;  Mat := 2;  HasView := True;
         Cap1 := 'The VIEW matrix is its INVERSE.';
         Cap2 := 'To look from c turned by a: subtract c, and turn by MINUS a. That is all.';
       end;
    7: begin Mat := 3;
         Cap1 := 'And inverting a turn is free.';
         Cap2 := 'Transpose it - flip it about its diagonal - and it is the turn back again.';
       end;
    8: begin Mat := 4;  HasProj := True;
         Cap1 := 'The PROJECTION matrix.';
         Cap2 := 'A row that copies z into w, and a divide by w. Ours is that divide, bare.';
       end;
    9: begin View := 4;  Mat := 0;  ObjX := 0;  CamX := 0;
         DoSlide := True;
         Cap1 := 'Now watch. Move the cube.';
         Cap2 := 'The plan shows it slide right. The glass shows it slide right. Nothing odd.';
       end;
   10: begin View := 4;  ObjX := 0;  CamX := 0;
         DoCamSlide := True;
         Cap1 := 'Now move the CAMERA instead.';
         Cap2 := 'The plan shows the camera slide LEFT. Now look at the glass. Look again.';
       end;
   11: begin View := 4;  ObjX := 0;  CamX := 0;
         Cap1 := 'The glass cannot tell you.';
         Cap2 := 'Only where the eye is RELATIVE to the cube decides it. Nothing else can.';
       end;
   12: begin View := 4;  ObjYaw := MYAW;  DoSpin := True;
         Cap1 := 'But turning is a different trick.';
         Cap2 := 'Spin the cube and it spins where it stands. Watch the plan while it does.';
       end;
   13: begin View := 4;  ObjYaw := MYAW;  CamYaw := 0;
         DoCamTurn := True;
         Cap1 := 'Turn the camera, and it travels.';
         Cap2 := 'The whole picture swings about the EYE - which is not where the cube is.';
       end;
   14: begin Scene := 1;
         Cap1 := 'Now for real - in a COM file.';
         Cap2 := 'Seven stages, and the last one hands you the arrow keys.';
       end;
  end;
end;

var Gd, Gm, S0, EC: Integer;
    LF: Text;
begin
  Assign(LF, 'INFOGR.LOG');
  Rewrite(LF);
  S0 := 0;
  if ParamCount > 0 then begin
    Val(ParamStr(1), S0, EC);
    if (EC <> 0) or (S0 < 0) or (S0 > 14) then S0 := 0;
  end;
  Gd := VGA; Gm := VGAHi;
  InitGraph(Gd, Gm, 'D:\BGI');
  if GraphResult <> grOk then begin
    WriteLn('EGAVGA.BGI not found - mount Borland Pascal as D: (MAKEINFO.BAT does).');
    Halt(1);
  end;
  for Step := 0 to 14 do begin
    SetStep(Step);
    if Step < S0 then Continue;
    DrawAll;
    if DoSlide then AnimSlide;
    if DoCamSlide then AnimCamSlide;
    if DoSpin then AnimSpin;
    if DoCamTurn then AnimCamTurn;
    while KeyPressed do Ch := ReadKey;
    Ch := ReadKey;
    WriteLn(LF, 'step=', Step, ' key=', Ord(Ch));
    if Ch = #27 then Break;
    if Ch = #0 then Ch := ReadKey;
  end;
  Close(LF);
  CloseGraph;
end.
