{ ==========================================================================
  INFOGR.PAS - the opening infographic for lesson 12 (the triangle that
  turns the sky: sin and cos out of the school triangle, the rotation
  matrix out of two anchor arrows, and a solar system out of one routine).

     D:\BIN\TPC.EXE -B -UD:\UNITS INFOGR.PAS     (see MAKEINFO.BAT)

  NOT PART OF THE LESSON - the title sequence the video opens with.

  THE LADDER IT CLIMBS:
     the school right triangle: legs, hypotenuse, the angle
   - grow it: the RATIOS hold - sin and cos belong to the ANGLE
   - hypotenuse 1: the tip walks a circle - every point is (cos a, sin a)
   - the radius arm is lesson 10's VECTOR, come back
   - turn the two anchor arrows (1,0) and (0,1): where they LAND
   - write the landings as COLUMNS: the rotation MATRIX - 4 multiplies
   - the elegant rival: complex numbers - same four multiplies, but no
     translate, no third axis, and a chain multiplies at every point
   - the task: a SKY - Sun, Earth, Moon, satellites
   - Earth = Sun + R(a) x (r,0): a turned vector on a standing centre
   - Moon = Earth + R(b) x (r,0): a turn around a MOVING centre
   - the whole chain: one matrix per body - thousands of points pay 4
   - trails on: the Moon's satellite writes the LACE
   - the reveal: the clock formula was the matrix's first column

  ONE COLOUR, ONE MEANING (the house rule): vectors and the arms that
  carry the sky are green; the ANGLE - its arc, and the Sun that owns
  the sky's angles - is yellow; red is reserved for the ONE thing being
  argued: the MATRIX. Bodies: Earth white, Moon grey, satellites cyan,
  and the Moon's satellite magenta - the pen that draws the lace.

  THE RULE OF THE ARROW does not apply here - nothing executes; this
  deck is geometry, not a CPU walk. What replaces it: a step never
  shows a word before naming it in the legend on the right.

  Keys: any key = next step, ESC = leave early.
  INFOGR N starts at step N (the state fast-forwards honestly).

  Owlos - legacy software modernization - https://owlos.sk
  ========================================================================== }
program Infogr;

uses Graph, Crt;

const
  BgCol  = Blue;
  VecCol = LightGreen;               { a vector, and the arms of the sky  }
  AngCol = Yellow;                   { the angle - and the Sun            }
  MatCol = LightRed;                 { the ONE argued thing: the matrix   }
  EarthC = White;
  MoonC  = LightGray;
  SatC   = LightCyan;
  LaceC  = LightMagenta;             { the pen that draws the lace        }

  OrgX   = 170;  OrgY = 300;         { the triangle's corner / the circle }
  TriR   = 130;                      { hypotenuse / radius, in pixels     }
  TriA   = 35;                       { the angle the whole deck argues on }
  LegX   = 500;                      { the legend column                  }
  LegY   = 96;                       { ...and where it starts             }
  MatX   = 306;  MatY = 104;         { the matrix panel, top right of play}

  SunX   = 200;  SunY = 290;         { the sky: where the Sun stands - set
                                       so the farthest reach (95+34+11)
                                       grazes neither the matrix panel nor
                                       the caption bar, by arithmetic     }
  NB     = 6;                        { how many bodies the sky holds      }

const                                { the sky, as a table - same rows the }
  BPar : array[1..NB] of Integer = (0, 1, 2, 2, 2, 3);       { COM file has }
  BRad : array[1..NB] of Integer = (0, 95, 34, 18, 25, 11);
  BSpd : array[1..NB] of Integer = (0, 2, 6, 10, -8, 14);
  BCol : array[1..NB] of Integer = (AngCol, EarthC, MoonC, SatC, SatC, LaceC);

var
  BAng : array[1..NB] of Integer;    { every body's angle, degrees        }
  BX, BY : array[1..NB] of Integer;  { ...and where that puts it          }
  NBody      : Integer;              { how much of the sky is switched on }
  SkyOn      : Boolean;              { which play field: triangle or sky  }
  ShowTri, ShowSim, ShowCirc, ShowArm, ShowAnch : Boolean;
  ShowMat, ShowCplx, ShowChain : Boolean;
  HasSin, HasVec, HasMat, HasChain : Boolean;
  MatHot, ColHot : Boolean;          { the matrix argued; its first column }
  AnchTurn   : Integer;              { how far the anchors have turned     }
  DoCircle   : Boolean;              { animate the point around the circle }
  DoAnch     : Boolean;              { animate the anchors' turn           }
  DoSky      : Integer;              { animate this many sky frames        }
  Trails     : Boolean;              { ink on: the field is not wiped      }
  Scene      : Integer;              { 0 = the play; 1 = the closing card  }
  Cap1, Cap2 : string;
  Step       : Integer;
  Ch         : Char;

procedure Headline;
begin
  SetTextStyle(DefaultFont, HorizDir, 2);
  SetTextJustify(CenterText, TopText);
  SetColor(White);
  OutTextXY(320, 10, 'THE TRIANGLE THAT TURNS THE SKY');
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetColor(LightCyan);
  OutTextXY(320, 36, 'from the school triangle to the rotation matrix  -  lesson 12');
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
  SetColor(AngCol);
  SetTextStyle(DefaultFont, HorizDir, 2);
  SetTextJustify(CenterText, TopText);
  OutTextXY(320, 440, Cap1);
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetColor(White);
  OutTextXY(320, 462, Cap2);
end;

{ ---- the legend: no word on the play field before it lives here ---------- }
procedure Legend;
var Y: Integer;
begin
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(White);
  OutTextXY(LegX, LegY, 'THE NAMES');
  Line(LegX, LegY + 12, 632, LegY + 12);
  Y := LegY + 24;
  if HasSin then begin
    SetColor(AngCol);
    OutTextXY(LegX, Y, 'SIN, COS');
    SetColor(LightCyan);
    OutTextXY(LegX, Y + 12, 'the angle''s own');
    OutTextXY(LegX, Y + 24, 'two ratios');
    Y := Y + 44;
  end;
  if HasVec then begin
    SetColor(VecCol);
    Line(LegX, Y + 4, LegX + 12, Y + 4);
    SetColor(White);
    OutTextXY(LegX + 18, Y, 'VECTOR');
    SetColor(LightCyan);
    OutTextXY(LegX + 18, Y + 12, 'angle + length');
    Y := Y + 34;
  end;
  if HasMat then begin
    SetColor(MatCol);
    OutTextXY(LegX, Y, 'MATRIX');
    SetColor(LightCyan);
    OutTextXY(LegX, Y + 12, 'a turn: 4 muls');
    Y := Y + 34;
  end;
  if HasChain then begin
    SetColor(White);
    OutTextXY(LegX, Y, 'THE CHAIN');
    SetColor(LightCyan);
    OutTextXY(LegX, Y + 12, 'me = parent +');
    OutTextXY(LegX, Y + 24, 'matrix x base');
  end;
end;

{ ---- the matrix panel: the one argued thing, so it wears the red --------- }
procedure MatrixPanel;
begin
  if not ShowMat then Exit;
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  if MatHot then SetColor(MatCol) else SetColor(White);
  Rectangle(MatX, MatY, MatX + 158, MatY + 86);
  if ColHot then SetColor(MatCol) else SetColor(White);
  OutTextXY(MatX + 10, MatY +  8, 'cos a');       { the FIRST column      }
  OutTextXY(MatX + 10, MatY + 22, 'sin a');
  SetColor(White);
  OutTextXY(MatX + 70, MatY +  8, '-sin a');
  OutTextXY(MatX + 70, MatY + 22, 'cos a');
  SetColor(LightCyan);
  OutTextXY(MatX + 10, MatY + 42, 'x'' = x cos - y sin');
  OutTextXY(MatX + 10, MatY + 54, 'y'' = x sin + y cos');
  SetColor(White);
  OutTextXY(MatX + 10, MatY + 70, '4 muls, 2 adds');
end;

{ ---- the triangle play field --------------------------------------------- }
procedure PlayTri;
var PX, PY, QX, QY, I: Integer;
    AX2, AY2: Integer;
begin
  SetFillStyle(SolidFill, BgCol);
  Bar(20, 84, 470, 430);

  PX := OrgX + Round(Cos(TriA * Pi / 180) * TriR);
  PY := OrgY - Round(Sin(TriA * Pi / 180) * TriR);

  if ShowSim then begin              { the bigger brother: ratios hold    }
    QX := OrgX + Round(Cos(TriA * Pi / 180) * TriR * 1.35);
    QY := OrgY - Round(Sin(TriA * Pi / 180) * TriR * 1.35);
    SetColor(DarkGray);
    Line(OrgX, OrgY, QX, QY);
    Line(QX, OrgY, QX, QY);
    Line(OrgX, OrgY, QX, OrgY);
  end;

  if ShowCirc then begin             { hypotenuse 1: the tip's whole road }
    SetColor(LightCyan);
    Circle(OrgX, OrgY, TriR);
    SetTextStyle(DefaultFont, HorizDir, 1);
    SetTextJustify(LeftText, TopText);
    OutTextXY(OrgX - 60, OrgY - TriR - 16, '(cos a, sin a)');
  end;

  if ShowTri then begin
    SetColor(White);                 { the hypotenuse                     }
    Line(OrgX, OrgY, PX, PY);
    SetColor(LightCyan);             { the two legs                       }
    Line(OrgX, OrgY, PX, OrgY);
    Line(PX, OrgY, PX, PY);
    SetColor(AngCol);                { the angle: the star of the hour    }
    Arc(OrgX, OrgY, 0, TriA, 34);
    SetTextStyle(DefaultFont, HorizDir, 1);
    SetTextJustify(LeftText, TopText);
    OutTextXY(OrgX + 40, OrgY - 14, 'a');
    SetColor(White);
    OutTextXY(OrgX + 24, OrgY - 78, 'hypotenuse');
    SetColor(LightCyan);
    OutTextXY(PX + 6, OrgY - 40, 'opposite');
    OutTextXY(OrgX + 30, OrgY + 8, 'adjacent');
  end;

  if ShowArm then begin              { the radius arm: lesson 10's vector }
    SetColor(VecCol);
    Line(OrgX, OrgY, PX, PY);
    Line(PX - 10, PY, PX, PY);       { a small head, enough to say arrow  }
    Line(PX, PY + 10, PX, PY);
    SetFillStyle(SolidFill, AngCol);
    FillEllipse(PX, PY, 3, 3);
  end;

  if ShowAnch then begin             { the two anchors, and their landing }
    SetColor(White);
    Line(OrgX, OrgY, OrgX + 90, OrgY);            { (1,0), at rest        }
    Line(OrgX, OrgY, OrgX, OrgY - 90);            { (0,1), at rest        }
    SetColor(VecCol);
    AX2 := OrgX + Round(Cos(AnchTurn * Pi / 180) * 90);
    AY2 := OrgY - Round(Sin(AnchTurn * Pi / 180) * 90);
    Line(OrgX, OrgY, AX2, AY2);                   { (1,0), turned         }
    SetTextStyle(DefaultFont, HorizDir, 1);
    SetTextJustify(LeftText, TopText);
    OutTextXY(AX2 + 6, AY2 - 6, '(cos a, sin a)');
    AX2 := OrgX - Round(Sin(AnchTurn * Pi / 180) * 90);
    AY2 := OrgY - Round(Cos(AnchTurn * Pi / 180) * 90);
    Line(OrgX, OrgY, AX2, AY2);                   { (0,1), turned         }
    OutTextXY(AX2 + 6, AY2 - 14, '(-sin a, cos a)');
  end;

  if ShowCplx then begin             { the elegant rival, weighed         }
    SetTextStyle(DefaultFont, HorizDir, 1);
    SetTextJustify(LeftText, TopText);
    SetColor(White);
    OutTextXY(40, 110, 'COMPLEX NUMBERS');
    SetColor(LightCyan);
    OutTextXY(40, 130, 'z = x + iy');
    OutTextXY(40, 144, 'turn: multiply by');
    OutTextXY(40, 158, '(cos a + i sin a)');
    OutTextXY(40, 178, 'the SAME 4 muls');
    SetColor(White);
    OutTextXY(40, 206, 'BUT:');
    SetColor(LightCyan);
    OutTextXY(40, 226, 'no translate inside');
    OutTextXY(40, 240, 'no third axis');
    OutTextXY(40, 254, 'a CHAIN of turns is');
    OutTextXY(40, 268, 'paid at every point');
    SetColor(White);
    OutTextXY(40, 296, 'a matrix chain folds');
    OutTextXY(40, 310, 'into ONE matrix -');
    OutTextXY(40, 324, 'points pay it once.');
    SetColor(MatCol);
    OutTextXY(40, 352, 'graphics chose matrices.');
  end;

  MatrixPanel;
end;

{ ---- the sky: positions from the table, parents first -------------------- }
procedure SkyPos;
var I, P: Integer;
begin
  BX[1] := SunX;  BY[1] := SunY;
  for I := 2 to NB do begin
    P := BPar[I];
    BX[I] := BX[P] + Round(Cos(BAng[I] * Pi / 180) * BRad[I]);
    BY[I] := BY[P] - Round(Sin(BAng[I] * Pi / 180) * BRad[I]);
  end;
end;

procedure SkyBodies;                 { the leading dots, always           }
var I: Integer;
begin
  for I := 1 to NBody do begin
    SetFillStyle(SolidFill, BCol[I]);
    SetColor(BCol[I]);
    if I = 1 then FillEllipse(BX[I], BY[I], 5, 5)
             else FillEllipse(BX[I], BY[I], 2, 2);
  end;
end;

procedure PlaySky;                   { the wiped-and-redrawn view         }
var I, P: Integer;
begin
  SetFillStyle(SolidFill, BgCol);
  Bar(20, 84, 470, 430);
  SkyPos;
  if ShowChain then begin
    SetColor(VecCol);
    for I := 2 to NBody do begin
      P := BPar[I];
      Line(BX[P], BY[P], BX[I], BY[I]);
    end;
  end;
  SkyBodies;
  MatrixPanel;
end;

procedure DrawMain;
begin
  SetFillStyle(SolidFill, BgCol);
  Bar(0, 0, 639, 479);
  Headline;
  Legend;
  if SkyOn then PlaySky else PlayTri;
  Captions;
end;

procedure DrawFinal;
begin
  SetFillStyle(SolidFill, BgCol);
  Bar(0, 0, 639, 479);
  Headline;
  SetTextStyle(DefaultFont, HorizDir, 4);
  SetTextJustify(CenterText, CenterText);
  SetColor(AngCol);
  OutTextXY(320, 170, 'THE TRIANGLE.');
  SetColor(MatCol);
  OutTextXY(320, 220, 'THE MATRIX.');
  SetColor(White);
  OutTextXY(320, 270, 'THE SKY.');
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetColor(LightCyan);
  OutTextXY(320, 310, 'four multiplies, hung one on another - that is all a sky is');
  Captions;
end;

procedure DrawAll;
begin
  if Scene = 0 then DrawMain else DrawFinal;
end;

{ ---- the little films ----------------------------------------------------- }
procedure AnimCircle;                { the tip walks its whole road        }
var A: Integer;
    PX, PY: Integer;
begin
  for A := 0 to 120 do begin
    PX := OrgX + Round(Cos((TriA + A * 3) * Pi / 180) * TriR);
    PY := OrgY - Round(Sin((TriA + A * 3) * Pi / 180) * TriR);
    SetFillStyle(SolidFill, AngCol);
    SetColor(AngCol);
    FillEllipse(PX, PY, 2, 2);       { the tip leaves yellow ink: the      }
    Delay(18);                       {  circle is MADE of triangle tips    }
  end;
end;

procedure AnimAnch;                  { the anchors swing out to the angle  }
begin
  AnchTurn := 0;
  while AnchTurn < TriA do begin
    AnchTurn := AnchTurn + 1;
    PlayTri;
    Delay(30);
  end;
end;

procedure AnimSky(Frames: Integer);  { the sky runs; ink if Trails         }
var F, I: Integer;
begin
  for F := 1 to Frames do begin
    for I := 2 to NB do
      BAng[I] := (BAng[I] + BSpd[I] + 360) mod 360;
    if Trails then begin
      SkyPos;
      for I := 2 to NBody do begin
        SetFillStyle(SolidFill, BCol[I]);
        SetColor(BCol[I]);
        FillEllipse(BX[I], BY[I], 1, 1);
      end;
      SkyBodies;
    end
    else PlaySky;
    Delay(25);
  end;
end;

procedure SetStep(N: Integer);
var I: Integer;
begin
  DoCircle := False;  DoAnch := False;  DoSky := 0;
  case N of
    0: begin
         SkyOn := False;  Scene := 0;  NBody := 2;  Trails := False;
         ShowTri := True;  ShowSim := False;  ShowCirc := False;
         ShowArm := False; ShowAnch := False; ShowMat := False;
         ShowCplx := False; ShowChain := False;
         HasSin := False; HasVec := False; HasMat := False; HasChain := False;
         MatHot := False; ColHot := False; AnchTurn := 0;
         for I := 1 to NB do BAng[I] := (I * 60) mod 360;
         Cap1 := 'The school triangle.';
         Cap2 := 'Two legs, a hypotenuse, an angle - it waited years for a job.';
       end;
    1: begin ShowSim := True; HasSin := True;
         Cap1 := 'Grow it: the RATIOS do not move.';
         Cap2 := 'Leg over hypotenuse belongs to the ANGLE: the far is SIN, the near is COS.';
       end;
    2: begin ShowSim := False; ShowCirc := True; DoCircle := True;
         Cap1 := 'Hypotenuse 1: the tip walks a CIRCLE.';
         Cap2 := 'Every point of a circle is (cos a, sin a) - the triangle, bent round.';
       end;
    3: begin ShowTri := False; ShowArm := True; HasVec := True;
         Cap1 := 'An angle and a length: a VECTOR.';
         Cap2 := 'Lesson 10 turned four of them. Today we turn ANY vector at all.';
       end;
    4: begin ShowArm := False; ShowCirc := False; ShowAnch := True;
         DoAnch := True;
         Cap1 := 'Turn the two ANCHOR arrows.';
         Cap2 := '(1,0) lands on (cos,sin); (0,1) on (-sin,cos). Every vector is these two.';
       end;
    5: begin ShowMat := True; MatHot := True; HasMat := True;
         Cap1 := 'The landings, as COLUMNS: a MATRIX.';
         Cap2 := 'Four multiplies, two adds - the whole price of turning anything.';
       end;
    6: begin ShowAnch := False; ShowCplx := True; MatHot := False;
         Cap1 := 'The rival: COMPLEX numbers.';
         Cap2 := 'Same four muls - but a chain is paid per point. Matrices fold into ONE.';
       end;
    7: begin SkyOn := True; ShowChain := True; HasChain := True;
         NBody := NB;
         Cap1 := 'Now the task: a SKY.';
         Cap2 := 'Sun; Earth round it; Moon round Earth; satellites. Say it in vectors.';
       end;
    8: begin NBody := 2; DoSky := 180;
         Cap1 := 'Earth = Sun + R(a) x (r,0).';
         Cap2 := 'A vector turned by the matrix, hung on the Sun. One green arm.';
       end;
    9: begin NBody := 3; DoSky := 180;
         Cap1 := 'Moon: a turn round a MOVING centre.';
         Cap2 := 'ROTATE rides on TRANSLATE: the matrix turns, the parent carries.';
       end;
   10: begin NBody := NB; DoSky := 200;
         Cap1 := 'The chain: one matrix per body.';
         Cap2 := 'A model is thousands of points and ONE matrix - each pays 4 muls.';
       end;
   11: begin Trails := True; DoSky := 420;
         Cap1 := 'Ink on: the lace writes itself.';
         Cap2 := 'Three turns deep, and the pen is the Moon''s own satellite.';
       end;
   12: begin ColHot := True; DoSky := 200;
         Cap1 := 'Feed the matrix (r,0).';
         Cap2 := 'Out falls r cos, r sin: lesson 10''s clock formula - the FIRST COLUMN.';
       end;
   13: begin Scene := 1;
         Cap1 := 'Now for real - in a COM file.';
         Cap2 := 'Six bodies, one routine, a six-row table - the lace draws itself.';
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
    if (EC <> 0) or (S0 < 0) or (S0 > 13) then S0 := 0;
  end;
  Gd := VGA; Gm := VGAHi;
  InitGraph(Gd, Gm, 'D:\BGI');
  if GraphResult <> grOk then begin
    WriteLn('EGAVGA.BGI not found - mount Borland Pascal as D: (MAKEINFO.BAT does).');
    Halt(1);
  end;
  for Step := 0 to 13 do begin
    SetStep(Step);
    if Step < S0 then begin        { fast-forward: the STATE still replays }
      if DoAnch then AnchTurn := TriA;
      Continue;
    end;
    DrawAll;
    if DoCircle then AnimCircle;
    if DoAnch then AnimAnch;
    if DoSky > 0 then AnimSky(DoSky);
    while KeyPressed do Ch := ReadKey;  { taps buffered during a Delay must
                                          not eat the steps that follow }
    Ch := ReadKey;
    WriteLn(LF, 'step=', Step, ' sky=', Ord(SkyOn), ' key=', Ord(Ch));
    if Ch = #27 then Break;
    if Ch = #0 then Ch := ReadKey;
  end;
  Close(LF);
  CloseGraph;
end.
