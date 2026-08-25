{ ==========================================================================
  INFOGR.PAS - the opening infographic for lesson 10 (the square that is
  not there: vectors, vertices, edges, faces, and the three transformations).

     D:\BIN\TPC.EXE -B -UD:\UNITS INFOGR.PAS     (see MAKEINFO.BAT)

  NOT PART OF THE LESSON - the title sequence the video opens with.

  THE LADDER IT CLIMBS:
     one radius vector (the clock's formula, learned flat)
   - the MINUS in the y line: paper y grows up, the beam draws DOWN
   - the tip named VERTEX
   - four equal vectors, 90 apart: four vertices - still no square
   - neighbouring tips joined: EDGES (the wire skeleton)
   - filled between the edges: a FACE
   - the four ANGLES turn together: the square "rotates" - but there
     IS no square in the program, only four angles and one length
   - hide the vectors: WIREFRAME (the debug view every engine has;
     OWL FLY's LOW detail mode is exactly this picture)
   - hide the edges: the filled face alone - all a 3D engine ever shows
   - TRANSLATE: move the centre.  ROTATE: turn the angles.
     SCALE: change the lengths.  Three transformations - and no more.

  ONE COLOUR, ONE MEANING (the house rule): vectors are green, a vertex
  is yellow, edges are white, the face is light gray, the centre is
  white. Red is reserved for the ONE thing being argued: the minus.

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
  VecCol = LightGreen;               { a vector - length and direction   }
  VtxCol = Yellow;                   { a vertex - a vector's tip         }
  EdgCol = White;                    { an edge - tip to tip              }
  FacCol = LightGray;                { the face - filled between edges   }
  HotCol = LightRed;                 { the ONE argued thing: the minus   }

  HomeX  = 240;  HomeY = 260;        { the centre's home                 }
  HomeR  = 110;                      { the vectors' home length          }
  LegX   = 500;                      { the legend column                 }
  LegY   = 108;                      { ...and where it starts            }

var
  CenX, CenY : Integer;              { where the centre stands NOW       }
  RadLen     : Integer;              { how long the vectors are NOW      }
  Rot        : Integer;              { degrees added to every angle      }
  NVec       : Integer;              { 1 = the first vector, 4 = all     }
  ShowVec, ShowVtx, ShowEdg, ShowFac : Boolean;
  ShowAxes   : Boolean;              { the paper-vs-screen mini axes     }
  HasVtx, HasEdg, HasFac : Boolean;  { the legend fills as words arrive  }
  HasT, HasR, HasS       : Boolean;
  MinusHot   : Boolean;              { the formula's minus wears red     }
  DoRot      : Integer;              { animate Rot up to this value      }
  DoMove     : Boolean;              { animate the centre out and back   }
  DoScale    : Boolean;              { animate the length out and back   }
  Scene      : Integer;              { 0 = the play; 1 = the closing card }
  Cap1, Cap2 : string;
  Step       : Integer;
  Ch         : Char;

function VpX(I: Integer): Integer;
begin
  VpX := CenX + Round(Sin((Rot + 45 + I * 90) * Pi / 180) * RadLen);
end;

function VpY(I: Integer): Integer;
begin
  { the lesson's minus: screen y grows DOWN the tube }
  VpY := CenY - Round(Cos((Rot + 45 + I * 90) * Pi / 180) * RadLen);
end;

procedure Headline;
begin
  { size 2, not 3: at size 3 this line is 672 pixels and BGI silently
    refuses to draw what does not fit - the title simply vanished }
  SetTextStyle(DefaultFont, HorizDir, 2);
  SetTextJustify(CenterText, TopText);
  SetColor(White);
  OutTextXY(320, 10, 'THE SQUARE THAT IS NOT THERE');
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetColor(LightCyan);
  OutTextXY(320, 36, 'vertices, edges, faces  -  lesson 10');
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
  SetColor(VtxCol);
  SetTextStyle(DefaultFont, HorizDir, 2);
  SetTextJustify(CenterText, TopText);
  OutTextXY(320, 440, Cap1);
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetColor(White);
  OutTextXY(320, 462, Cap2);
end;

{ ---- the formula strip, under the headline. The minus is the star. ------- }
procedure Formula;
begin
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(White);
  OutTextXY(24, 56, 'x = cx + sin(a)*r');
  OutTextXY(24, 68, 'y = cy');
  if MinusHot then SetColor(HotCol) else SetColor(White);
  OutTextXY(24 + 7 * 8, 68, '-');
  SetColor(White);
  OutTextXY(24 + 9 * 8, 68, 'cos(a)*r');
  SetColor(LightCyan);
  OutTextXY(200, 62, 'the clock formula:');
  OutTextXY(200, 74, 'a LENGTH, a DIRECTION');
end;

{ ---- paper against screen: two little axes, the whole argument ----------- }
procedure MiniAxes;
begin
  SetColor(White);
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  Line(60, 170, 60, 120);            { paper: y grows UP }
  Line(56, 126, 60, 120);  Line(64, 126, 60, 120);
  OutTextXY(74, 130, 'paper:');
  OutTextXY(74, 142, 'y grows UP');
  SetColor(HotCol);
  Line(60, 200, 60, 250);            { the tube: the beam draws DOWN }
  Line(56, 244, 60, 250);  Line(64, 244, 60, 250);
  OutTextXY(74, 210, 'screen:');
  OutTextXY(74, 222, 'y grows DOWN');
  OutTextXY(74, 234, '- the beam draws so');
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
  if HasVtx then begin
    SetFillStyle(SolidFill, VtxCol);
    FillEllipse(LegX + 6, Y + 4, 4, 4);
    SetColor(White);
    OutTextXY(LegX + 18, Y, 'VERTEX');
    SetColor(LightCyan);
    OutTextXY(LegX + 18, Y + 12, 'a vector''s tip');
    Y := Y + 34;
  end;
  if HasEdg then begin
    SetColor(EdgCol);
    Line(LegX, Y + 4, LegX + 12, Y + 4);
    SetColor(White);
    OutTextXY(LegX + 18, Y, 'EDGE');
    SetColor(LightCyan);
    OutTextXY(LegX + 18, Y + 12, 'tip to tip');
    Y := Y + 34;
  end;
  if HasFac then begin
    SetFillStyle(SolidFill, FacCol);
    Bar(LegX, Y, LegX + 12, Y + 8);
    SetColor(White);
    OutTextXY(LegX + 18, Y, 'FACE');
    SetColor(LightCyan);
    OutTextXY(LegX + 18, Y + 12, 'filled inside');
    Y := Y + 34;
  end;
  if HasT or HasR or HasS then begin
    SetColor(White);
    OutTextXY(LegX, Y + 6, 'TRANSFORMATIONS');
    Line(LegX, Y + 18, 632, Y + 18);
    Y := Y + 30;
  end;
  if HasT then begin
    SetColor(White);
    OutTextXY(LegX, Y, 'TRANSLATE');
    SetColor(LightCyan);
    OutTextXY(LegX, Y + 12, 'move the centre');
    Y := Y + 30;
  end;
  if HasR then begin
    SetColor(White);
    OutTextXY(LegX, Y, 'ROTATE');
    SetColor(LightCyan);
    OutTextXY(LegX, Y + 12, 'turn the angles');
    Y := Y + 30;
  end;
  if HasS then begin
    SetColor(White);
    OutTextXY(LegX, Y, 'SCALE');
    SetColor(LightCyan);
    OutTextXY(LegX, Y + 12, 'grow and shrink');
  end;
end;

{ ---- the play field: erased and redrawn as one - animation redraws ONLY
  this rectangle, so the words around it never flicker -------------------- }
procedure Play;
var I: Integer;
    P: array[1..4] of PointType;
    DX, DY, L: Real;
    AX, AY: Integer;
begin
  SetFillStyle(SolidFill, BgCol);
  Bar(20, 84, 470, 430);
  if ShowAxes then MiniAxes;

  { the face first - everything else is drawn over it }
  if ShowFac then begin
    for I := 1 to 4 do begin
      P[I].X := VpX(I - 1);
      P[I].Y := VpY(I - 1);
    end;
    SetFillStyle(SolidFill, FacCol);
    SetColor(FacCol);
    FillPoly(4, P);
  end;

  { the edges - neighbouring tips, joined }
  if ShowEdg then begin
    SetColor(EdgCol);
    for I := 0 to 3 do
      Line(VpX(I), VpY(I), VpX((I + 1) mod 4), VpY((I + 1) mod 4));
  end;

  { the vectors - each a line from the centre with a small head }
  if ShowVec then begin
    SetColor(VecCol);
    for I := 0 to NVec - 1 do begin
      Line(CenX, CenY, VpX(I), VpY(I));
      DX := VpX(I) - CenX;  DY := VpY(I) - CenY;
      L := Sqrt(DX * DX + DY * DY);
      if L > 1 then begin
        AX := VpX(I) - Round(10 * DX / L);
        AY := VpY(I) - Round(10 * DY / L);
        Line(AX - Round(4 * DY / L), AY + Round(4 * DX / L), VpX(I), VpY(I));
        Line(AX + Round(4 * DY / L), AY - Round(4 * DX / L), VpX(I), VpY(I));
      end;
    end;
  end;

  { the vertices - the named tips }
  if ShowVtx then begin
    SetFillStyle(SolidFill, VtxCol);
    SetColor(VtxCol);
    for I := 0 to NVec - 1 do
      FillEllipse(VpX(I), VpY(I), 4, 4);
  end;

  { the centre, always - it is the thing translation will move }
  SetFillStyle(SolidFill, White);
  SetColor(White);
  FillEllipse(CenX, CenY, 3, 3);
  if NVec = 1 then begin
    SetTextStyle(DefaultFont, HorizDir, 1);
    SetTextJustify(LeftText, TopText);
    SetColor(LightCyan);
    OutTextXY(CenX + 10, CenY + 6, 'the centre (cx,cy)');
  end;
end;

procedure DrawMain;
begin
  SetFillStyle(SolidFill, BgCol);
  Bar(0, 0, 639, 479);
  Headline;
  Formula;
  Legend;
  Play;
  Captions;
end;

procedure DrawFinal;
begin
  SetFillStyle(SolidFill, BgCol);
  Bar(0, 0, 639, 479);
  Headline;
  SetTextStyle(DefaultFont, HorizDir, 4);
  SetTextJustify(CenterText, CenterText);
  SetColor(VtxCol);
  OutTextXY(320, 180, 'VERTEX. EDGE. FACE.');
  SetTextStyle(DefaultFont, HorizDir, 2);
  SetColor(White);
  OutTextXY(320, 240, 'the square was never there');
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetColor(LightCyan);
  OutTextXY(320, 280, 'four angles and a length - redrawn every frame');
  Captions;
end;

procedure DrawAll;
begin
  if Scene = 0 then DrawMain else DrawFinal;
end;

{ ---- the little films. Each redraws ONLY the play field. ----------------- }
procedure AnimRot(Target: Integer);
begin
  while Rot < Target do begin
    Rot := Rot + 3;
    Play;
    Delay(40);
  end;
end;

procedure AnimMove;
var I: Integer;
begin
  for I := 1 to 20 do begin CenX := CenX + 5; Play; Delay(35); end;
  Delay(300);
  for I := 1 to 20 do begin CenX := CenX - 5; Play; Delay(35); end;
end;

procedure AnimScale;
var I: Integer;
begin
  for I := 1 to 12 do begin RadLen := RadLen - 4; Play; Delay(35); end;
  Delay(250);
  for I := 1 to 20 do begin RadLen := RadLen + 4; Play; Delay(35); end;
  Delay(250);
  for I := 1 to 8 do begin RadLen := RadLen - 4; Play; Delay(35); end;
end;

procedure SetStep(N: Integer);
begin
  DoRot := -1;  DoMove := False;  DoScale := False;
  case N of
    0: begin CenX := HomeX; CenY := HomeY; RadLen := HomeR; Rot := 0;
             NVec := 1; Scene := 0;
             ShowVec := True;  ShowVtx := False;
             ShowEdg := False; ShowFac := False; ShowAxes := False;
             HasVtx := False; HasEdg := False; HasFac := False;
             HasT := False; HasR := False; HasS := False;
             MinusHot := False;
             Cap1 := 'A vector: a LENGTH and a DIRECTION from a centre.';
             Cap2 := 'The clock''s formula, learned flat - the hand was a vector all along.';
       end;
    1: begin ShowAxes := True; MinusHot := True;
             Cap1 := 'The notebook writes PLUS. The screen writes MINUS.';
             Cap2 := 'The beam draws top to bottom, so screen y grows DOWN - the first flip every graphics program makes.';
       end;
    2: begin ShowAxes := False; ShowVtx := True; HasVtx := True;
             Cap1 := 'Name the tip: a VERTEX.';
             Cap2 := 'A vertex is not a thing. It is where a vector ENDS - two numbers, angle and length.';
       end;
    3: begin NVec := 4;
             Cap1 := 'Four vectors. One length, angles 90 apart.';
             Cap2 := 'Four tips - four vertices. Look hard: there is still no square anywhere.';
       end;
    4: begin ShowEdg := True; HasEdg := True;
             Cap1 := 'Join neighbouring tips: EDGES.';
             Cap2 := 'Four lines between four vertices - the wire skeleton stands up.';
       end;
    5: begin ShowFac := True; HasFac := True;
             Cap1 := 'Fill between the edges: a FACE.';
             Cap2 := 'Vertex, edge, face - every 3D model ever made is these three, and nothing else.';
       end;
    6: begin DoRot := 60; HasR := True;
             Cap1 := 'Turn the four ANGLES together - the square "rotates".';
             Cap2 := 'Nothing rotates the square. There IS no square: four angles and a length, redrawn.';
       end;
    7: begin ShowVec := False; ShowVtx := False; DoRot := 120;
             Cap1 := 'Hide the vectors: WIREFRAME.';
             Cap2 := 'The debug view every engine has - OWL FLY''s LOW detail mode is exactly this picture.';
       end;
    8: begin ShowEdg := False; DoRot := 180;
             Cap1 := 'Hide the edges.';
             Cap2 := 'This is everything a 3D engine ever shows you. The rest it does - and hides - every frame.';
       end;
    9: begin ShowVec := True; ShowVtx := True; ShowEdg := True;
             DoMove := True; HasT := True;
             Cap1 := 'TRANSLATE: move the CENTRE.';
             Cap2 := 'Watch the vectors: length and angle never changed - they rode along untouched.';
       end;
   10: begin DoRot := 240;
             Cap1 := 'ROTATE: turn the ANGLES.';
             Cap2 := 'You have seen it already - now it has its name. The centre and the lengths stand still.';
       end;
   11: begin DoScale := True; HasS := True;
             Cap1 := 'SCALE: change the LENGTHS.';
             Cap2 := 'The angles stand still, the lengths breathe - the square grows and shrinks in place.';
       end;
   12: begin
             Cap1 := 'Three transformations - and there are no more.';
             Cap2 := 'Centre, angle, length: three numbers a vertex obeys. Every game moves everything this way.';
       end;
   13: begin Scene := 1;
             Cap1 := 'Lesson 10 - now for real, in a COM file.';
             Cap2 := 'A square built from four vectors, on the screen, byte by byte.';
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
      if DoRot >= 0 then Rot := DoRot;
      Continue;
    end;
    DrawAll;
    if DoRot > Rot then AnimRot(DoRot);
    if DoMove then AnimMove;
    if DoScale then AnimScale;
    while KeyPressed do Ch := ReadKey;  { taps buffered during a Delay must
                                          not eat the steps that follow }
    Ch := ReadKey;
    WriteLn(LF, 'step=', Step, ' rot=', Rot, ' key=', Ord(Ch));
    if Ch = #27 then Break;
    if Ch = #0 then Ch := ReadKey;
  end;
  Close(LF);
  CloseGraph;
end.
