{ ==========================================================================
  INFOGR.PAS - the opening infographic for lesson 0F (perspective is one
  divide: the pinhole, two similar triangles, the divide and its trap, and
  the table that replaces it).

     D:\BIN\TPC.EXE -B -UD:\UNITS INFOGR.PAS     (see MAKEINFO.BAT)

  NOT PART OF THE LESSON - the title sequence the video opens with, and
  the place the THEORY lives: a side view of an eye, a screen and a point,
  with the two triangles drawn and labelled. Mode 13h cannot spell a word;
  BGI can, so the argument is made here and the COM file only spends it.

  IT OPENS ON THE FINISHED THING: lesson 0E's cube, in perspective now,
  coming towards you and getting bigger - the one thing the last lesson
  could not do.

  THE LADDER IT CLIMBS:
     the cube, in perspective, coming and going - the promise
   - the camera obscura: a hole in a wall, and the world upside down
   - the eye is the same machine: a pupil, a retina, an inverted picture
   - graphics puts the glass IN FRONT of the eye, so the picture is upright
   - the triangle: the eye, the short leg to the screen, the ray to the point
   - the SECOND triangle, to the point itself - and they are SIMILAR
   - so x'/d = x/z, and x' = x*d/z. One divide. That is all of it.
   - far divides by more: two points, same height, the far one lands lower
   - d IS THE FIELD OF VIEW: the same cube drawn for an eye on the glass and
     for an eye at arm's length - the first reads as a tapered box, because
     the viewer's eye is at arm's length. The pilot's eye found this one.
   - the divide on this chip: what it costs, and INT 0 when it cannot answer
   - the other way: a table of d/z - the sine table's trick, aimed at division
   - the table's two ends ARE the two clipping planes
   - what the near plane protects: with it the cube stops; without it, INT 0
   - do it twice: divided and looked-up, drawn on top of each other
   - the closing card

  ONE COLOUR, ONE MEANING:
     yellow     the eye, and its axis
     white      the screen, and the cube's edges
     green      a ray from the eye to a point - lesson 10's vector colour
     cyan       where a point lands on the screen
     magenta    the ONE argued thing: whichever triangle or formula is live
     red        the fault - INT 0, and nothing else
     dark grey  what is absent or forbidden: the far plane, the rows below
                the near plane, the divided cube underneath the table's

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
  EyeC   = Yellow;
  ScrC   = White;
  RayC   = LightGreen;
  HitC   = LightCyan;
  ArgC   = LightMagenta;
  FltC   = LightRed;
  GoneC  = DarkGray;

  EX     = 70;   EY = 262;           { the eye, in the side view           }
  SX0    = 190;                      { the screen: a vertical line here    }
  SD     = 120;                      { ...which is d, in pixels            }
  PXa    = 400;  PYa = 150;          { the point the triangle is drawn to  }

  CX     = 245;  CY = 250;           { the cube's axis on the play field   }
  DEYE   = 390;                      { the eye-to-screen distance - AND THE
                                       FIELD OF VIEW: 390 across a field
                                       225 wide each side is about sixty
                                       degrees, roughly where the viewer's
                                       own eye sits. The first build used
                                       170: a hundred and six degrees, a
                                       fisheye, and the pilot's eye read
                                       the cube as a tapered box. d is
                                       where YOU are.                     }
  DWIDE  = 120;                      { ...and the fisheye, kept for step 8 }
  ZNEAR  = 90;
  VXO    = 20;   VYO = 84;           { the play field's corner: the cube is
                                       drawn inside a CLIPPED viewport, so
                                       nothing can ever spill over the
                                       headline. The first build let a
                                       close cube paint the title bar.   }

  LegX   = 486;
  LegY   = 96;

  VX : array[0..7] of Integer = (-25, 25, 25,-25,-25, 25, 25,-25);
  VY : array[0..7] of Integer = (-25,-25, 25, 25,-25,-25, 25, 25);
  VZ : array[0..7] of Integer = (-25,-25,-25,-25, 25, 25, 25, 25);
  EA : array[0..11] of Integer = (0,1,2,3,4,5,6,7,0,1,2,3);
  EB : array[0..11] of Integer = (1,2,3,0,5,6,7,4,4,5,6,7);

var
  SXa, SYa : array[0..7] of Integer;
  AngY, AngX : Real;
  Tz       : Real;                   { how far out the cube's centre sits  }
  View     : Integer;                { 0 cube  1 obscura  2 eye  3 glass   }
                                     { 4 triangle  5 far/near  6 text      }
  TriSmall, TriBig, ShowRay, ShowHit, TwoPts : Boolean;
  Panel    : Integer;                { which text panel: 0 none, 1 cost,   }
                                     {  2 table, 3 planes                  }
  Quant    : Boolean;                { draw the table's cube on the divided}
  TwoD     : Boolean;                { step 8: the same cube for two eyes  }
  Dcur     : Real;                   { the d Place projects with           }
  Cxo      : Integer;                { ...and the axis it projects onto    }
  PlaneOn  : Boolean;                { the near plane, drawn               }
  Guard    : Boolean;                { stop at it, or not                  }
  Scene    : Integer;
  HasRay, HasTri, HasDiv, HasTab : Boolean;
  DoCome, DoApproach : Boolean;
  Cap1, Cap2 : string;
  Step     : Integer;
  Ch       : Char;

procedure Headline;
begin
  SetTextStyle(DefaultFont, HorizDir, 2);
  SetTextJustify(CenterText, TopText);
  SetColor(White);
  OutTextXY(320, 10, 'PERSPECTIVE IS ONE DIVIDE');
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetColor(LightCyan);
  OutTextXY(320, 36, 'a pinhole, two triangles, one divide - and what the divide costs  -  0F');
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
  if HasRay then begin
    SetColor(RayC);
    Line(LegX, Y + 4, LegX + 12, Y + 4);
    SetColor(White);
    OutTextXY(LegX + 18, Y, 'THE RAY');
    SetColor(LightCyan);
    OutTextXY(LegX, Y + 14, 'eye to point;');
    OutTextXY(LegX, Y + 26, 'it crosses the glass');
    Y := Y + 46;
  end;
  if HasTri then begin
    SetColor(ArgC);
    OutTextXY(LegX, Y, 'SIMILAR');
    SetColor(LightCyan);
    OutTextXY(LegX, Y + 14, 'two triangles,');
    OutTextXY(LegX, Y + 26, 'one hypotenuse');
    Y := Y + 46;
  end;
  if HasDiv then begin
    SetColor(FltC);
    OutTextXY(LegX, Y, 'THE DIVIDE');
    SetColor(LightCyan);
    OutTextXY(LegX, Y + 14, '~100 clocks, and');
    OutTextXY(LegX, Y + 26, 'it can stop the CPU');
    Y := Y + 46;
  end;
  if HasTab then begin
    SetColor(GoneC);
    OutTextXY(LegX, Y, 'THE TABLE');
    SetColor(LightCyan);
    OutTextXY(LegX, Y + 14, 'd/z, 256 rows;');
    OutTextXY(LegX, Y + 26, 'row 0 holds nothing');
  end;
end;

{ ---- the cube, in perspective: lesson 0E's corners, divided ------------- }
procedure Place;
var i: Integer;
    x, y, z, t, ca, sa, dz: Real;
begin
  for i := 0 to 7 do begin
    x := VX[i];  y := VY[i];  z := VZ[i];
    ca := Cos(AngY);  sa := Sin(AngY);
    t := x*ca - z*sa;  z := x*sa + z*ca;  x := t;
    ca := Cos(AngX);  sa := Sin(AngX);
    t := y*ca - z*sa;  z := y*sa + z*ca;  y := t;
    dz := z + Tz;
    if dz < 1 then dz := 1;
    if Quant then begin              { the table: d/z in 256ths, floored }
      SXa[i] := (Cxo - VXO) + Round(x * Int(Dcur * 256 / dz) / 256);
      SYa[i] := (CY - VYO) - Round(y * Int(Dcur * 256 / dz) / 256);
    end
    else begin                       { viewport coordinates: see CubeView }
      SXa[i] := (Cxo - VXO) + Round(x * Dcur / dz);
      SYa[i] := (CY - VYO) - Round(y * Dcur / dz);
    end;
  end;
end;

procedure CubeEdges(C: Integer);
var i: Integer;
begin
  SetColor(C);
  for i := 0 to 11 do
    Line(SXa[EA[i]], SYa[EA[i]], SXa[EB[i]], SYa[EB[i]]);
end;

{ Everything in here is drawn inside a CLIPPED viewport over the play
  field, in viewport coordinates - (CX-VXO, CY-VYO) is the axis - so a
  cube that comes too close is cut at the field's edge and never paints
  the headline. The first build let it, and the pilot saw the title bar
  fill with lines.                                                       }
procedure CubeView;
var vx, vy: Integer;
    keep: Real;
begin
  SetViewPort(VXO, VYO, 470, 430, ClipOn);
  vx := CX - VXO;  vy := CY - VYO;
  if TwoD then begin                 { THE SAME CUBE, AT THE SAME SIZE ON
                                       THE GLASS, DRAWN FOR TWO EYES. Not
                                       the same depth: d alone only scales
                                       a picture, and two cubes at one
                                       depth would differ in size and in
                                       nothing else. What makes the fisheye
                                       is d against the DISTANCE TO THE
                                       THING. So: left, d = 120 with the
                                       cube 80 out - an eye almost on the
                                       glass, the cube almost on the eye.
                                       Right, d = 390 with the cube 263
                                       out - an eye at arm's length. Same
                                       size on the glass. The viewer's eye
                                       IS at arm's length, so the left one
                                       reads as a tapered box: the brain
                                       explains convergence it cannot
                                       account for as SHAPE. Neither is
                                       wrong. The left one is for somebody
                                       else.                              }
    keep := Tz;
    Dcur := DWIDE;  Cxo := CX - 110;  Tz := 80;   Place;  CubeEdges(ScrC);
    SetColor(EyeC);  Line(vx - 115, vy, vx - 105, vy);  Line(vx - 110, vy - 5, vx - 110, vy + 5);
    Dcur := DEYE;   Cxo := CX + 110;  Tz := 263;  Place;  CubeEdges(ScrC);
    SetColor(EyeC);  Line(vx + 105, vy, vx + 115, vy);  Line(vx + 110, vy - 5, vx + 110, vy + 5);
    Tz := keep;
    SetTextStyle(DefaultFont, HorizDir, 1);
    SetTextJustify(CenterText, TopText);
    SetColor(LightCyan);
    OutTextXY(vx - 110, vy + 100, 'd = 120, the cube 80 out');
    OutTextXY(vx + 110, vy + 100, 'd = 390, the cube 263 out');
    SetColor(GoneC);
    OutTextXY(vx, vy + 130, 'same corners, same size on the glass. Your eye is on the right.');
    Cxo := CX;
    SetViewPort(0, 0, 639, 479, ClipOff);
    Exit;
  end;
  Dcur := DEYE;  Cxo := CX;
  SetColor(EyeC);
  Line(vx - 5, vy, vx + 5, vy);
  Line(vx, vy - 5, vx, vy + 5);
  if Quant then begin                { the divided cube first, in grey... }
    Quant := False;  Place;  CubeEdges(GoneC);
    Quant := True;   Place;  CubeEdges(ScrC);   { ...the table's on top   }
  end
  else begin
    Place;  CubeEdges(ScrC);
  end;
  if PlaneOn then begin              { as big as the stopped cube reaches }
    SetColor(GoneC);
    SetLineStyle(DashedLn, 0, NormWidth);
    Rectangle(vx - 190, vy - 158, vx + 190, vy + 158);
    SetLineStyle(SolidLn, 0, NormWidth);
    SetTextStyle(DefaultFont, HorizDir, 1);
    SetTextJustify(LeftText, TopText);
    OutTextXY(vx - 186, vy - 154, 'the near plane: this big and no bigger');
  end;
  SetViewPort(0, 0, 639, 479, ClipOff);
end;

{ ---- the camera obscura, and the eye: a side view ----------------------- }
procedure Obscura(AsEye: Boolean);
var bx1, by1, bx2, by2, hx, hy: Integer;
begin
  bx1 := 230;  by1 := 150;  bx2 := 440;  by2 := 370;
  hx := bx1;   hy := 260;
  SetColor(ScrC);
  if AsEye then begin
    Circle(335, 260, 105);
    SetColor(EyeC);
    Circle(hx + 8, hy, 9);           { the pupil                          }
    SetTextStyle(DefaultFont, HorizDir, 1);
    SetTextJustify(LeftText, TopText);
    OutTextXY(hx - 20, hy + 60, 'pupil');
    OutTextXY(bx2 - 30, by1 - 20, 'retina');
  end
  else begin
    Rectangle(bx1, by1, bx2, by2);
    SetColor(BgCol);
    Line(hx, hy - 4, hx, hy + 4);    { the hole: a gap in the wall         }
    SetColor(EyeC);
    Circle(hx, hy, 6);
    SetTextStyle(DefaultFont, HorizDir, 1);
    SetTextJustify(LeftText, TopText);
    OutTextXY(hx - 24, hy + 60, 'a hole');
    OutTextXY(bx2 - 62, by1 - 20, 'the back wall');
  end;
  SetColor(HitC);                    { the object: an arrow, pointing UP   }
  Line(90, 330, 90, 190);
  Line(90, 190, 80, 205);
  Line(90, 190, 100, 205);
  SetColor(RayC);                    { two rays through the hole: they cross }
  Line(90, 190, hx, hy);  Line(hx, hy, bx2 - 4, 330);
  Line(90, 330, hx, hy);  Line(hx, hy, bx2 - 4, 190);
  SetColor(HitC);                    { ...and the image, pointing DOWN     }
  Line(bx2 - 4, 190, bx2 - 4, 330);
  Line(bx2 - 4, 330, bx2 - 14, 315);
  Line(bx2 - 4, 330, bx2 + 6, 315);
  SetColor(White);
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  OutTextXY(60, 350, 'the world');
  OutTextXY(bx2 - 60, 350, 'upside down');
end;

{ ---- the glass in front of the eye, and the triangles ------------------- }
procedure SideView;
var hy, hy2, px2: Integer;
begin
  SetColor(EyeC);                    { the eye, and its axis               }
  Circle(EX, EY, 6);
  Line(EX, EY, 460, EY);
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  OutTextXY(EX - 14, EY + 12, 'eye');
  SetColor(ScrC);                    { the screen, edge-on: a vertical line}
  Line(SX0, 130, SX0, 390);
  OutTextXY(SX0 + 4, 134, 'the glass');
  SetColor(HitC);
  SetFillStyle(SolidFill, HitC);
  FillEllipse(PXa, PYa, 3, 3);
  OutTextXY(PXa + 8, PYa - 12, 'a point: (x, z)');

  hy := EY - Round((EY - PYa) * (SX0 - EX) / (PXa - EX));
  if ShowRay then begin
    SetColor(RayC);
    Line(EX, EY, PXa, PYa);
  end;
  if ShowHit then begin
    SetColor(HitC);
    FillEllipse(SX0, hy, 3, 3);
    OutTextXY(SX0 - 34, hy - 16, 'x''');
  end;
  if TriSmall then begin             { d along the axis, x'' up the glass }
    SetColor(ArgC);
    Line(EX, EY, SX0, EY);
    Line(SX0, EY, SX0, hy);
    Line(EX, EY, SX0, hy);
    OutTextXY(EX + 50, EY + 10, 'd');
    OutTextXY(SX0 + 6, (EY + hy) div 2, 'x''');
  end;
  if TriBig then begin               { z along the axis, x up to the point }
    SetColor(ArgC);
    Line(EX, EY, PXa, EY);
    Line(PXa, EY, PXa, PYa);
    Line(EX, EY, PXa, PYa);
    OutTextXY(EX + 220, EY + 10, 'z');
    OutTextXY(PXa + 6, (EY + PYa) div 2, 'x');
  end;
  if TwoPts then begin               { a second point, same x, nearer      }
    px2 := 290;
    hy2 := EY - Round((EY - PYa) * (SX0 - EX) / (px2 - EX));
    SetColor(HitC);
    FillEllipse(px2, PYa, 3, 3);
    SetColor(RayC);
    Line(EX, EY, px2, PYa);
    SetColor(HitC);
    FillEllipse(SX0, hy2, 3, 3);
    SetColor(White);
    OutTextXY(SX0 - 60, hy2 - 16, 'near');
    OutTextXY(SX0 - 60, hy - 16, 'far');
    SetColor(GoneC);
    OutTextXY(230, 400, 'same x. The far one divides by a bigger z, and lands nearer the axis.');
  end;
end;

{ ---- the text panels ---------------------------------------------------- }
procedure TextPanel;
begin
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  if Panel = 1 then begin
    SetColor(White);
    OutTextXY(40, 104, 'ON THIS CHIP:');
    SetColor(LightCyan);
    OutTextXY(40, 130, 'IMUL  byte     about  80 clocks');
    SetColor(FltC);
    OutTextXY(40, 144, 'IDIV  byte     about 100 clocks');
    SetColor(LightCyan);
    OutTextXY(40, 158, 'IDIV  word     about 160 clocks');
    SetColor(White);
    OutTextXY(40, 188, 'Two per corner, sixty frames a');
    OutTextXY(40, 202, 'second - a real price. But the');
    OutTextXY(40, 216, 'price is not the worst of it.');
    SetColor(FltC);
    OutTextXY(40, 246, 'IDIV byte: the answer must fit AL.');
    OutTextXY(40, 260, '-128 .. +127, and NOT ONE MORE.');
    SetColor(White);
    OutTextXY(40, 286, 'Bring a corner close enough that');
    OutTextXY(40, 300, 'x*d/z is 130, and it does not');
    OutTextXY(40, 314, 'round, and it does not clip.');
    SetColor(FltC);
    OutTextXY(40, 340, 'It raises INT 0.');
    SetColor(LightCyan);
    OutTextXY(40, 354, 'The same interrupt as dividing by');
    OutTextXY(40, 368, 'zero - and the program is over.');
  end;
  if Panel = 2 then begin
    SetColor(White);
    OutTextXY(40, 104, 'THE MACHINE HAS NO SINE.');
    OutTextXY(40, 118, 'So lesson 10 minted a table.');
    SetColor(ArgC);
    OutTextXY(40, 148, 'The machine has no cheap divide.');
    OutTextXY(40, 162, 'So mint a table of d/z.');
    SetColor(LightCyan);
    OutTextXY(40, 192, 'RECIP: 256 rows, one per depth,');
    OutTextXY(40, 206, 'each holding d/z in 256ths.');
    SetColor(White);
    OutTextXY(40, 236, 'x * d / z   becomes');
    SetColor(ArgC);
    OutTextXY(40, 256, '  look up   RECIP[z]');
    OutTextXY(40, 270, '  multiply  x * that');
    OutTextXY(40, 284, '  shift     right by eight');
    SetColor(LightCyan);
    OutTextXY(40, 314, 'The sine table''s three moves,');
    OutTextXY(40, 328, 'aimed at division. About the same');
    OutTextXY(40, 342, 'time as one byte divide -');
    SetColor(White);
    OutTextXY(40, 366, 'and it CANNOT TRAP. That is the');
    OutTextXY(40, 380, 'purchase. Not the clocks.');
  end;
  if Panel = 3 then begin
    SetColor(White);
    OutTextXY(40, 104, 'THE TABLE HAS TWO ENDS.');
    SetColor(GoneC);
    OutTextXY(40, 134, 'row   0 ..  49      0  0  0  0  0');
    SetColor(ArgC);
    OutTextXY(40, 148, 'row  50           512   = d/50');
    SetColor(LightCyan);
    OutTextXY(40, 162, 'row 100           256   = d/100');
    OutTextXY(40, 176, 'row 200           128   = d/200');
    SetColor(ArgC);
    OutTextXY(40, 190, 'row 255           100   = d/255');
    SetColor(GoneC);
    OutTextXY(40, 204, 'row 256           - no such row -');
    SetColor(White);
    OutTextXY(40, 234, 'Row zero holds NOTHING: a depth');
    OutTextXY(40, 248, 'that close has no honest d/z.');
    SetColor(ArgC);
    OutTextXY(40, 268, 'That is the NEAR PLANE.');
    SetColor(White);
    OutTextXY(40, 294, 'Row 255 is the last depth with');
    OutTextXY(40, 308, 'an address at all.');
    SetColor(ArgC);
    OutTextXY(40, 328, 'That is the FAR PLANE.');
    SetColor(LightCyan);
    OutTextXY(40, 356, 'Neither is a rule of taste. Both');
    OutTextXY(40, 370, 'are the size of a byte, drawn.');
  end;
end;

procedure PlayField;
begin
  SetFillStyle(SolidFill, BgCol);
  Bar(20, 84, 470, 430);
  case View of
    0: CubeView;
    1: Obscura(False);
    2: Obscura(True);
    3: SideView;
    4: SideView;
    5: SideView;
    6: TextPanel;
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
  SetColor(ArgC);
  OutTextXY(320, 160, 'TWO TRIANGLES.');
  SetColor(FltC);
  OutTextXY(320, 210, 'ONE DIVIDE.');
  SetColor(GoneC);
  OutTextXY(320, 260, 'AND A TABLE INSTEAD.');
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetColor(LightCyan);
  OutTextXY(320, 300, 'far things get small - and the near plane is a byte with no row zero');
  SetColor(DarkGray);
  OutTextXY(320, 322, 'lesson 0E''s cube, 2311 bytes, and a divide that ends the program on cue');
  Captions;
end;

procedure DrawAll;
begin
  if Scene = 0 then DrawMain else DrawFinal;
end;

{ ---- the little films --------------------------------------------------- }
procedure AnimCome;                  { in from far, and back out - and only
                                       between 240 and 160: further out the
                                       box is small enough to flip in the
                                       eye, nearer in it outgrows the field.
                                       The first build ran 260 down to 95.  }
var i: Integer;
begin
  for i := 1 to 80 do begin
    Tz := Tz - 1.0;  AngY := AngY + 0.02;
    PlayField;  Delay(24);
  end;
  for i := 1 to 80 do begin
    Tz := Tz + 1.0;  AngY := AngY + 0.02;
    PlayField;  Delay(24);
  end;
end;

procedure AnimApproach;              { in from far - and STOP at the plane }
var i: Integer;
begin
  for i := 1 to 170 do begin
    if Tz > ZNEAR + 44 then Tz := Tz - 1.0;
    PlayField;  Delay(22);
  end;
end;

procedure SetStep(N: Integer);
begin
  DoCome := False;  DoApproach := False;
  case N of
    0: begin
         Scene := 0;  View := 0;  Panel := 0;  Quant := False;
         TwoD := False;  Dcur := DEYE;  Cxo := CX;
         PlaneOn := False;  Guard := True;
         TriSmall := False;  TriBig := False;  ShowRay := False;
         ShowHit := False;  TwoPts := False;
         HasRay := False; HasTri := False; HasDiv := False; HasTab := False;
         AngY := 0.45;  AngX := 0.30;  Tz := 240;
         DoCome := True;
         Cap1 := 'By the end of this hour.';
         Cap2 := 'Lesson 0E''s cube - and now, when it comes towards you, it gets BIGGER.';
       end;
    1: begin View := 1;
         Cap1 := 'A hole in a wall.';
         Cap2 := 'The camera obscura: the world paints itself on the back wall, upside down.';
       end;
    2: begin View := 2;
         Cap1 := 'Your eye is the same machine.';
         Cap2 := 'A pupil for the hole, a retina for the wall - and the picture is inverted.';
       end;
    3: begin View := 3;  ShowRay := True;  ShowHit := True;  HasRay := True;
         Cap1 := 'Graphics puts the glass IN FRONT.';
         Cap2 := 'The ray from the eye to a point crosses the screen. THAT crossing is x''.';
       end;
    4: begin View := 4;  TriSmall := True;  HasTri := True;
         Cap1 := 'The small triangle.';
         Cap2 := 'Legs d and x'' - the eye to the glass, and up the glass to the crossing.';
       end;
    5: begin TriBig := True;
         Cap1 := 'And the big one, to the point.';
         Cap2 := 'Legs z and x. Same corner at the eye, same hypotenuse. They are SIMILAR.';
       end;
    6: begin
         Cap1 := 'x'' / d  =  x / z';
         Cap2 := 'So x'' = x * d / z. One multiply, ONE DIVIDE. That is the whole of it.';
       end;
    7: begin View := 5;  TriSmall := False;  TriBig := False;  TwoPts := True;
         Cap1 := 'Far divides by more.';
         Cap2 := 'Two points at the same height. The far one lands nearer the axis.';
       end;
    8: begin View := 0;  TwoD := True;  Tz := 200;  AngY := 0.45;
         Cap1 := 'd is where YOU are.';
         Cap2 := 'Same cube, two eyes. Draw it for an eye on the glass and it looks tapered.';
       end;
    9: begin View := 6;  TwoD := False;  Panel := 1;  HasDiv := True;
         Cap1 := 'What the divide costs.';
         Cap2 := 'Clocks - and worse: an answer that does not fit the register is INT 0.';
       end;
   10: begin Panel := 2;  HasTab := True;
         Cap1 := 'The other way: a table.';
         Cap2 := 'd/z for every depth, minted once. Look up, multiply, shift. It cannot trap.';
       end;
   11: begin Panel := 3;
         Cap1 := 'The table''s two ends.';
         Cap2 := 'Row zero holds nothing: the near plane. Row 255 is the last: the far plane.';
       end;
   12: begin View := 0;  Panel := 0;  PlaneOn := True;  Tz := 240;
         AngY := 0.45;  DoApproach := True;
         Cap1 := 'What the near plane protects.';
         Cap2 := 'The cube comes in - and STOPS. Take the plane away, and the divide traps.';
       end;
   13: begin PlaneOn := False;  Quant := True;  Tz := 180;
         Cap1 := 'Done twice, drawn on top of each other.';
         Cap2 := 'Grey is the divide. White is the table. Count the pixels between them.';
       end;
   14: begin Scene := 1;
         Cap1 := 'Now for real - in a COM file.';
         Cap2 := 'Six stages, and the last one ends the program on purpose.';
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
    if DoCome then AnimCome;
    if DoApproach then AnimApproach;
    while KeyPressed do Ch := ReadKey;
    Ch := ReadKey;
    WriteLn(LF, 'step=', Step, ' key=', Ord(Ch));
    if Ch = #27 then Break;
    if Ch = #0 then Ch := ReadKey;
  end;
  Close(LF);
  CloseGraph;
end.
