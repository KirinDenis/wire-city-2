{ ==========================================================================
  INFOGR.PAS - the opening infographic for lesson 0E (the first cube: eight
  vectors from one centre, a list of which to join, and what a projection
  actually costs).

     D:\BIN\TPC.EXE -B -UD:\UNITS INFOGR.PAS     (see MAKEINFO.BAT)

  NOT PART OF THE LESSON - the title sequence the video opens with. And in
  this lesson it carries more than usual: the THEORY of vectors and
  matrices in three dimensions lives here, on 640x480 with sixteen colours
  and room for labels, because the COM file is 320x200 and cannot spell a
  single word. The pilot's call, 2026-09-02.

  IT OPENS ON THE FINISHED CUBE, TURNING. Five seconds of "this is where we
  are going" before we go back to one point in space - the hook of showing
  the result first, bought without reordering the lesson.

  THE LADDER IT CLIMBS:
     the finished cube, turning - the promise
   - three axes, one point, three numbers: a VECTOR from ONE place
   - eight of them, all from the same centre - a starburst, and no cube
   - the edge list: twelve pairs, and the cube appears out of a LIST
   - lesson 12's 2x2, recalled
   - the 3x3 - and the 2x2 is sitting inside it with a 1 in the corner
   - about Y, about X: THE SAME 2x2, handed a different pair
   - turned: THE ROOM'S AXES STAND STILL, the cube's own axes turn
   - two frames, and only one of them moves
   - and the ORDER is not free: two cubes, white and red, in two places
   - translation: the same three numbers added to all eight at once
   - the screen holds two numbers and the model holds three
   - so throw z away: that deletion IS the projection, and it costs zero
   - the price: NO PERSPECTIVE - two cubes at different depths, same size
   - the other price: NO HIDDEN LINES - and what culling would have done
   - the closing card

  ONE COLOUR, ONE MEANING, and the same colours the COM file uses:
     green      a vector, a corner's own arrow - lesson 10's colour
     white      an edge
     yellow     the ROOM's origin and its axes - and they never move
     cyan       a corner, marked
     magenta    the ONE argued thing - whichever square is being made
     red        the OTHER order, and only ever that
     dark grey  what is ABSENT: the lines culling would have removed, and
                the perspective we did not pay for

  TP7 SCARS: a source line dies past 126 characters, and a BGI string too
  wide for 640 pixels is REFUSED outright rather than clipped. Captions are
  budgeted Cap1 <= 39 chars (size 2) and Cap2 <= 78 (size 1).

  Keys: any key = next step, ESC = leave early.
  INFOGR N starts at step N (the state fast-forwards honestly).

  Owlos - legacy software modernization - https://owlos.sk
  ========================================================================== }
program Infogr;

uses Graph, Crt;

const
  BgCol  = Blue;
  VecC   = LightGreen;               { a vector out of the origin        }
  EdgeC  = White;                    { an edge                           }
  OrgC   = Yellow;                   { the origin, and the three axes    }
  TipC   = LightCyan;                { a corner                          }
  ArgC   = LightMagenta;             { the ONE argued thing              }
  AltC   = LightRed;                 { the OTHER order, and only that    }
  GoneC  = DarkGray;                 { what is deliberately ABSENT       }

  PX0    = 230;  PY0 = 250;          { where the model's origin sits     }
  SCN    = 3;    SCD = 2;            { model units to pixels: 3/2        }

  LegX   = 486;                      { the legend column                 }
  LegY   = 96;

  VX : array[0..7] of Integer = (-40, 40, 40,-40,-40, 40, 40,-40);
  VY : array[0..7] of Integer = (-40,-40, 40, 40,-40,-40, 40, 40);
  VZ : array[0..7] of Integer = (-40,-40,-40,-40, 40, 40, 40, 40);
  EA : array[0..11] of Integer = (0,1,2,3,4,5,6,7,0,1,2,3);
  EB : array[0..11] of Integer = (1,2,3,0,5,6,7,4,4,5,6,7);

var
  SXa, SYa : array[0..7] of Integer; { where each corner landed          }
  ZA       : array[0..7] of Real;    { ...and the depth we usually drop  }
  AngY, AngX : Real;                 { the model's two angles, radians   }
  Dx, Dy, Dz : Real;                 { and where it has been moved to    }
  Swap     : Boolean;                { Place turns X first instead of Y  }
  TwoWay   : Boolean;                { step 8: draw BOTH orders, on top  }
  ShowAx, ShowBody, ShowVec, ShowEdge : Boolean;
  NVec     : Integer;                { how many corner-arrows are on     }
  Mat      : Integer;                { which square is on show: 0..3     }
  Scene    : Integer;                { 0 the play, 1 the closing card    }
  Cull     : Boolean;                { draw what culling WOULD have done }
  Persp    : Boolean;                { the two-depths comparison         }
  Proj2    : Boolean;                { the "throw z away" panel          }
  HasVec, HasList, HasMat, HasProj : Boolean;
  DoSpin, DoWalk : Boolean;
  Cap1, Cap2 : string;
  Step     : Integer;
  Ch       : Char;

procedure Headline;
begin
  SetTextStyle(DefaultFont, HorizDir, 2);
  SetTextJustify(CenterText, TopText);
  SetColor(White);
  OutTextXY(320, 10, 'THE FIRST CUBE');
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetColor(LightCyan);
  OutTextXY(320, 36, 'eight vectors, a list of joins, and a deleted coordinate  -  0E');
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

{ ---- the legend: no word on the play field before it lives here --------- }
procedure Legend;
var Y: Integer;
begin
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(White);
  OutTextXY(LegX, LegY, 'THE NAMES');
  Line(LegX, LegY + 12, 632, LegY + 12);
  Y := LegY + 24;
  if HasVec then begin
    SetColor(VecC);
    Line(LegX, Y + 4, LegX + 12, Y + 4);
    SetColor(White);
    OutTextXY(LegX + 18, Y, 'VECTOR');
    SetColor(LightCyan);
    OutTextXY(LegX, Y + 14, 'three numbers,');
    OutTextXY(LegX, Y + 26, 'from the origin');
    Y := Y + 46;
  end;
  if HasList then begin
    SetColor(EdgeC);
    OutTextXY(LegX, Y, 'THE LIST');
    SetColor(LightCyan);
    OutTextXY(LegX, Y + 14, 'twelve pairs:');
    OutTextXY(LegX, Y + 26, 'who joins whom');
    Y := Y + 46;
  end;
  if HasMat then begin
    SetColor(ArgC);
    OutTextXY(LegX, Y, 'THE SQUARE');
    SetColor(LightCyan);
    OutTextXY(LegX, Y + 14, 'a turn: the 2x2');
    OutTextXY(LegX, Y + 26, 'you already have');
    Y := Y + 46;
  end;
  if HasProj then begin
    SetColor(GoneC);
    OutTextXY(LegX, Y, 'THE DROP');
    SetColor(LightCyan);
    OutTextXY(LegX, Y + 14, 'z thrown away:');
    OutTextXY(LegX, Y + 26, 'that IS the view');
  end;
end;

{ ---- turn and project the eight corners --------------------------------- }
procedure Place(ox, oy, oz: Real);
var i: Integer;
    x, y, z, t, ca, sa: Real;
begin
  for i := 0 to 7 do begin
    x := VX[i];  y := VY[i];  z := VZ[i];
    if Swap then begin
      ca := Cos(AngX);  sa := Sin(AngX);
      t := y*ca - z*sa;  z := y*sa + z*ca;  y := t;
      ca := Cos(AngY);  sa := Sin(AngY);
      t := x*ca - z*sa;  z := x*sa + z*ca;  x := t;
    end
    else begin
      ca := Cos(AngY);  sa := Sin(AngY);
      t := x*ca - z*sa;  z := x*sa + z*ca;  x := t;
      ca := Cos(AngX);  sa := Sin(AngX);
      t := y*ca - z*sa;  z := y*sa + z*ca;  y := t;
    end;
    x := x + ox;  y := y + oy;  z := z + oz;
    SXa[i] := PX0 + Round(x * SCN / SCD);
    SYa[i] := PY0 - Round(y * SCN / SCD);
    ZA[i]  := z;                     { kept - and, in the COM, dropped }
  end;
end;

{ ---- which corner is furthest away? Its three edges are the hidden ones - }
function FarCorner: Integer;
var i, f: Integer;
begin
  f := 0;
  for i := 1 to 7 do if ZA[i] < ZA[f] then f := i;
  FarCorner := f;
end;

procedure DrawEdges(C: Integer; HideBack: Boolean);
var i, f: Integer;
begin
  f := -1;
  if HideBack then f := FarCorner;
  for i := 0 to 11 do begin
    if HideBack and ((EA[i] = f) or (EB[i] = f)) then begin
      SetColor(GoneC);                { drawn dim, so the eye sees what }
      Line(SXa[EA[i]], SYa[EA[i]], SXa[EB[i]], SYa[EB[i]]);  { WOULD go }
    end
    else begin
      SetColor(C);
      Line(SXa[EA[i]], SYa[EA[i]], SXa[EB[i]], SYa[EB[i]]);
    end;
  end;
end;

procedure DrawVecs(N: Integer);
var i, ox, oy: Integer;
begin
  ox := PX0 + Round(Dx * SCN / SCD);
  oy := PY0 - Round(Dy * SCN / SCD);
  for i := 0 to N - 1 do begin
    SetColor(VecC);
    Line(ox, oy, SXa[i], SYa[i]);
    SetColor(TipC);
    SetFillStyle(SolidFill, TipC);
    FillEllipse(SXa[i], SYa[i], 3, 3);
  end;
end;

{ ---- THE ROOM'S AXES, AND THEY NEVER MOVE -------------------------------
  This is the frame the PROJECTION is nailed to: screen x is world x,
  screen y is minus world y, and that is true in every frame of the film.
  So these three arrows are drawn UNTURNED, always.

  AND LOOK WHAT HAPPENS TO Z. Under this projection the depth axis points
  straight at the viewer and lands on a single pixel - it has no length on
  the glass at all. There is nothing to draw. That is not a shortcoming of
  the drawing: it IS what "we threw z away" means, and it is why nothing
  in this picture can tell you how far away anything is.

  (The first version of this procedure turned the axes with the cube. It
  was drawing the CUBE'S OWN frame while calling it the room's, and it
  said neither out loud. The pilot caught it on the first look.)         }
procedure Axes;
  procedure Ray(ax, ay: Integer; nm: string);
  var sx, sy: Integer;
  begin
    sx := PX0 + Round(ax * SCN / SCD);
    sy := PY0 - Round(ay * SCN / SCD);
    SetColor(OrgC);
    Line(PX0, PY0, sx, sy);
    SetTextStyle(DefaultFont, HorizDir, 1);
    SetTextJustify(LeftText, TopText);
    OutTextXY(sx + 4, sy - 4, nm);
  end;
begin
  Ray(86, 0, 'X');
  Ray(0, 86, 'Y');
  SetColor(GoneC);                   { Z: straight at you, and therefore }
  Circle(PX0, PY0, 7);               {  exactly one pixel wide on glass  }
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  OutTextXY(PX0 + 12, PY0 + 10, 'Z - at you, and flat');
  SetColor(OrgC);
  Line(PX0 - 5, PY0, PX0 + 5, PY0);
  Line(PX0, PY0 - 5, PX0, PY0 + 5);
  OutTextXY(PX0 - 46, PY0 - 18, '0,0,0');
end;

{ ---- THE CUBE'S OWN AXES, AND THESE DO TURN -----------------------------
  Three short arrows out of the cube's own centre, carried through exactly
  the same two turns the corners are. The table in the program holds its
  corners in THIS frame; the screen reads the room's. Rotating is the act
  of asking where the one lands inside the other.

  And this is why the box reads as a box: these arrows are tilted, so their
  depth leans into across-and-up, and a flat screen gets something to draw.  }
procedure BodyAxes;
var ox, oy: Integer;
  procedure BRay(ax, ay, az: Real; nm: string);
  var x, y, z, t, ca, sa: Real;  sx, sy: Integer;
  begin
    x := ax;  y := ay;  z := az;
    ca := Cos(AngY);  sa := Sin(AngY);
    t := x*ca - z*sa;  z := x*sa + z*ca;  x := t;
    ca := Cos(AngX);  sa := Sin(AngX);
    t := y*ca - z*sa;  z := y*sa + z*ca;  y := t;
    sx := ox + Round(x * SCN / SCD);
    sy := oy - Round(y * SCN / SCD);
    SetColor(VecC);
    Line(ox, oy, sx, sy);
    SetTextStyle(DefaultFont, HorizDir, 1);
    SetTextJustify(LeftText, TopText);
    OutTextXY(sx + 3, sy - 3, nm);
  end;
begin
  ox := PX0 + Round(Dx * SCN / SCD);
  oy := PY0 - Round(Dy * SCN / SCD);
  BRay(58, 0, 0, 'x');
  BRay(0, 58, 0, 'y');
  BRay(0, 0, 58, 'z');
end;

{ ---- the squares: 2x2, then 3x3, then the pair that turns --------------- }
procedure Squares;
begin
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  if Mat = 1 then begin
    SetColor(White);
    OutTextXY(40, 110, 'LESSON 12, UNCHANGED:');
    SetColor(ArgC);
    OutTextXY(40, 136, '| cos a  -sin a |');
    OutTextXY(40, 150, '| sin a   cos a |');
    SetColor(LightCyan);
    OutTextXY(40, 176, 'x'' = x cos - y sin');
    OutTextXY(40, 190, 'y'' = x sin + y cos');
    SetColor(White);
    OutTextXY(40, 216, 'four multiplies, two adds.');
    OutTextXY(40, 230, 'It turns a PLANE.');
    SetColor(GoneC);
    OutTextXY(40, 262, 'But a corner has THREE numbers.');
  end;
  if Mat = 2 then begin
    SetColor(White);
    OutTextXY(40, 100, 'A TURN ABOUT Z, IN THREE NUMBERS:');
    SetColor(ArgC);
    OutTextXY(40, 128, '| cos a  -sin a   0 |');
    OutTextXY(40, 142, '| sin a   cos a   0 |');
    SetColor(GoneC);
    OutTextXY(40, 156, '|   0       0     1 |');
    SetColor(White);
    OutTextXY(40, 186, 'Look at what is actually there.');
    SetColor(ArgC);
    OutTextXY(40, 206, 'The 2x2 you already have,');
    OutTextXY(40, 220, 'and a 1 in the corner.');
    SetColor(LightCyan);
    OutTextXY(40, 248, 'z is multiplied by one and left');
    OutTextXY(40, 262, 'exactly where it was.');
    SetColor(White);
    OutTextXY(40, 290, 'A turn about an AXIS leaves that');
    OutTextXY(40, 304, 'axis alone, and turns the PLANE');
    OutTextXY(40, 318, 'across it. Nothing else happens.');
  end;
  if Mat = 3 then begin
    SetColor(White);
    OutTextXY(40, 104, 'SO THERE IS ONE ROUTINE,');
    OutTextXY(40, 118, 'AND YOU HAND IT A PAIR:');
    SetColor(ArgC);
    OutTextXY(40, 148, 'about Z    ->    the pair (x, y)');
    OutTextXY(40, 168, 'about Y    ->    the pair (x, z)');
    OutTextXY(40, 188, 'about X    ->    the pair (y, z)');
    SetColor(LightCyan);
    OutTextXY(40, 218, 'Same four multiplies. Same two');
    OutTextXY(40, 232, 'adds. Same table of sines.');
    SetColor(White);
    OutTextXY(40, 262, 'There is no three-dimensional');
    OutTextXY(40, 276, 'arithmetic in this lesson.');
    SetColor(ArgC);
    OutTextXY(40, 296, 'There is the arithmetic you have,');
    OutTextXY(40, 310, 'aimed twice.');
  end;
end;

{ ---- the projection panel: two numbers out of three --------------------- }
procedure ProjPanel;
begin
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(White);
  OutTextXY(40, 108, 'THE MODEL HOLDS THREE NUMBERS.');
  OutTextXY(40, 122, 'THE SCREEN HOLDS TWO.');
  SetColor(LightCyan);
  OutTextXY(40, 152, 'Something has to go, and the');
  OutTextXY(40, 166, 'cheapest answer is the honest one:');
  SetColor(ArgC);
  OutTextXY(40, 196, 'screen x   =   x');
  OutTextXY(40, 214, 'screen y   =   - y');
  SetColor(GoneC);
  OutTextXY(40, 232, 'z          =   never read again');
  SetColor(White);
  OutTextXY(40, 264, 'That deletion IS the projection.');
  SetColor(LightCyan);
  OutTextXY(40, 284, 'It costs ZERO instructions: the');
  OutTextXY(40, 298, 'program simply stops asking.');
  SetColor(GoneC);
  OutTextXY(40, 326, 'Perspective would DIVIDE by z.');
  OutTextXY(40, 340, 'We have not paid for a divide.');
end;

procedure PlayField;
var sv: Real;
begin
  SetFillStyle(SolidFill, BgCol);
  Bar(20, 84, 470, 430);
  if Mat > 0 then begin Squares; Exit; end;
  if Proj2 then begin ProjPanel; Exit; end;
  if Persp then begin                { two depths, one size - the proof }
    Place(-34, 0, -70);
    DrawEdges(EdgeC, False);
    Place(30, 0, 70);
    DrawEdges(EdgeC, False);
    SetTextStyle(DefaultFont, HorizDir, 1);
    SetTextJustify(CenterText, TopText);
    SetColor(GoneC);
    OutTextXY(245, 400, 'far and near - and not one pixel of difference');
    Exit;
  end;
  if ShowAx then Axes;
  if ShowBody then BodyAxes;
  Swap := False;                     { white is ALWAYS Y first, then X }
  Place(Dx, Dy, Dz);
  if ShowEdge then DrawEdges(EdgeC, Cull);
  if ShowVec then DrawVecs(NVec);
  if TwoWay then begin               { ...and red is the other way round.
                                       Swap must be flipped BETWEEN the two
                                       placements, or both cubes come out
                                       of the same order and the picture
                                       proves the opposite of the caption. }
    Swap := True;
    Place(Dx, Dy, Dz);
    DrawEdges(AltC, False);
    Swap := False;
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
  SetTextStyle(DefaultFont, HorizDir, 4);
  SetTextJustify(CenterText, CenterText);
  SetColor(VecC);
  OutTextXY(320, 160, 'EIGHT ARROWS.');
  SetColor(EdgeC);
  OutTextXY(320, 210, 'TWELVE PAIRS.');
  SetColor(GoneC);
  OutTextXY(320, 260, 'ONE DROPPED NUMBER.');
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetColor(LightCyan);
  OutTextXY(320, 300, 'that is a three-dimensional engine, and it fits in 1548 bytes');
  SetColor(DarkGray);
  OutTextXY(320, 322, 'no perspective, no hidden lines - and both of those on purpose');
  Captions;
end;

procedure DrawAll;
begin
  if Scene = 0 then DrawMain else DrawFinal;
end;

{ ---- the little films --------------------------------------------------- }
procedure AnimSpin(N: Integer; sy, sx: Real);
var i: Integer;
begin
  for i := 1 to N do begin
    AngY := AngY + sy;
    AngX := AngX + sx;
    PlayField;
    Delay(22);
  end;
end;

procedure AnimWalk;
var i: Integer;
begin
  for i := 1 to 60 do begin
    Dx := Dx + 1.1;  Dy := Dy + 0.5;
    PlayField;
    Delay(24);
  end;
  for i := 1 to 60 do begin
    Dx := Dx - 1.1;  Dy := Dy - 0.5;
    PlayField;
    Delay(24);
  end;
end;

procedure SetStep(N: Integer);
begin
  DoSpin := False;  DoWalk := False;
  case N of
    0: begin
         Scene := 0;  Mat := 0;  Cull := False;  Persp := False;
         Proj2 := False;  TwoWay := False;  ShowAx := False;
         ShowVec := False;  ShowEdge := True;  NVec := 8;  ShowBody := False;
         HasVec := False; HasList := False; HasMat := False; HasProj := False;
         AngY := 0.45;  AngX := 0.35;  Dx := 0; Dy := 0; Dz := 0;
         DoSpin := True;
         Cap1 := 'By the end of this hour.';
         Cap2 := 'A cube in 1548 bytes - and you will have read every one of them.';
       end;
    1: begin ShowEdge := False;  ShowAx := True;  ShowVec := True;
         NVec := 1;  HasVec := True;  AngY := 0.45;  AngX := 0.35;
         Cap1 := 'One point is THREE numbers.';
         Cap2 := 'Forty across, forty up, forty towards you - measured from ONE place.';
       end;
    2: begin NVec := 8;
         Cap1 := 'Eight of them, one centre.';
         Cap2 := 'Every corner is an arrow out of the middle of the cube. No cube yet.';
       end;
    3: begin ShowEdge := True;  HasList := True;
         Cap1 := 'Twelve pairs: WHO JOINS WHOM.';
         Cap2 := 'The corners were a cloud. This list is what makes them a box.';
       end;
    4: begin ShowVec := False;  ShowAx := False;  Mat := 1;  HasMat := True;
         Cap1 := 'How do we turn it?';
         Cap2 := 'Here is lesson 12''s square, unchanged. It turns a PLANE, not a space.';
       end;
    5: begin Mat := 2;
         Cap1 := 'The same square, with a 1 added.';
         Cap2 := 'A turn about an axis leaves that axis alone and turns the plane across.';
       end;
    6: begin Mat := 3;
         Cap1 := 'One routine, three aims.';
         Cap2 := 'About Z the pair is (x,y); about Y it is (x,z); about X it is (y,z).';
       end;
    7: begin Mat := 0;  ShowAx := True;  ShowBody := True;  DoSpin := True;
         AngY := 0.45;  AngX := 0.35;
         Cap1 := 'Turned about Y, then about X.';
         Cap2 := 'The room''s arrows do not move. The cube''s own arrows turn with it.';
       end;
    8: begin DoSpin := False;  AngY := 0.62;  AngX := 0.40;
         Cap1 := 'Two frames. Only one moves.';
         Cap2 := 'The table holds corners in the GREEN frame. The screen reads the YELLOW.';
       end;
    9: begin ShowAx := False;  ShowBody := False;  DoSpin := False;  TwoWay := True;
         AngY := 0.90;  AngX := 0.90;
         Cap1 := 'And the ORDER is not free.';
         Cap2 := 'White turned Y then X; red turned X then Y. The same two angles.';
       end;
   10: begin TwoWay := False;  ShowVec := True;  NVec := 8;
         AngY := 0.45;  AngX := 0.35;  Dx := 0; Dy := 0;
         DoWalk := True;
         Cap1 := 'Moving it is moving the corners.';
         Cap2 := 'The same three numbers added to all eight - so the shape cannot change.';
       end;
   11: begin ShowVec := False;  Dx := 0;  Dy := 0;  Mat := 0;  Proj2 := True;
         HasProj := True;
         Cap1 := 'Three numbers, and a flat screen.';
         Cap2 := 'The model holds x, y and z. The glass holds two. Something has to go.';
       end;
   12: begin Proj2 := False;  ShowEdge := True;  Persp := True;
         Cap1 := 'The price: NO PERSPECTIVE.';
         Cap2 := 'Two cubes, one far and one near, drawn exactly the same size.';
       end;
   13: begin Persp := False;  Cull := True;  AngY := 0.45;  AngX := 0.35;
         Cap1 := 'The other price: no hidden lines.';
         Cap2 := 'Grey is what culling would have removed. We draw it. That is WIREFRAME.';
       end;
   14: begin Cull := False;  DoSpin := True;
         Cap1 := 'All twelve edges, always.';
         Cap2 := 'You can see straight through the box - and now you know exactly why.';
       end;
   15: begin Scene := 1;
         Cap1 := 'Now for real - in a COM file.';
         Cap2 := 'Eight triples, twelve pairs, and one number quietly thrown away.';
       end;
  end;
end;

var Gd, Gm, S0, EC: Integer;
    LF: Text;                        { the trace: every step, every key }
begin
  Assign(LF, 'INFOGR.LOG');
  Rewrite(LF);
  S0 := 0;
  if ParamCount > 0 then begin
    Val(ParamStr(1), S0, EC);
    if (EC <> 0) or (S0 < 0) or (S0 > 15) then S0 := 0;
  end;
  Gd := VGA; Gm := VGAHi;
  InitGraph(Gd, Gm, 'D:\BGI');
  if GraphResult <> grOk then begin
    WriteLn('EGAVGA.BGI not found - mount Borland Pascal as D: (MAKEINFO.BAT does).');
    Halt(1);
  end;
  for Step := 0 to 15 do begin
    SetStep(Step);
    if Step < S0 then Continue;    { fast-forward: the STATE still replays }
    DrawAll;
    if DoSpin then AnimSpin(150, 0.035, 0.011);
    if DoWalk then AnimWalk;
    while KeyPressed do Ch := ReadKey;  { taps buffered during a Delay must
                                          not eat the steps that follow }
    Ch := ReadKey;
    WriteLn(LF, 'step=', Step, ' key=', Ord(Ch));
    if Ch = #27 then Break;
    if Ch = #0 then Ch := ReadKey;
  end;
  Close(LF);
  CloseGraph;
end.
