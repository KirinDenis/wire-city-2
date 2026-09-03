{ ==========================================================================
  INFOGR.PAS - the opening infographic for lesson 0D (the arm that adds up:
  a chain inherits its parent's PLACE and its parent's TURN, and about one
  axis that inheritance collapses into a single ADD).

     D:\BIN\TPC.EXE -B -UD:\UNITS INFOGR.PAS     (see MAKEINFO.BAT)

  NOT PART OF THE LESSON - the title sequence the video opens with.

  THE LADDER IT CLIMBS:
     a machine in three sticks, a motor at every joint
   - one link is lesson 12's matrix, unchanged: (r,0) turned by an angle
   - hang a second stick on the first: which way does IT point?
   - THE TRAP: give it its own angle only and the arm breaks on camera
   - lesson 12's sky was exactly that - place inherited, turn not
   - so turn it twice: the parent's matrix TIMES its own
   - multiply the two squares out
   - and the four products are two names everyone knows: cos(a+b), sin(a+b)
   - therefore R(a) x R(b) = R(a+b): EIGHT MULTIPLIES BECOME ONE ADD
   - the arm is a running sum down the chain
   - what a motor will show: a grey ZERO RAY, a wedge, and a white ball
   - turn the shoulder alone: every ball and ray moves, no arc changes
   - turn the elbow alone: one arc opens
   - the closing card, and the catch that buys the next lesson

  ONE COLOUR, ONE MEANING - and here the rule is bent on purpose, for a
  better reason: EVERY LINK WEARS THE COLOUR IT WILL WEAR IN THE PROGRAM,
  so the viewer meets the same green upper arm, yellow forearm and red
  gripper in the deck and in the COM file. That costs the deck its usual
  yellow-for-angle and red-for-argument, so the ONE argued thing - the
  SUM - takes magenta instead, and it is the only magenta on the screen.

  Balls are white and zero rays are dark grey, in the deck and in the
  program alike. The wedge wears the colour of the link its motor drives.

  STEP 10 IS THE FRAME TO COME BACK TO. The script returns to it between
  the walk and the run with INFOGR 10, because it is the promise the run
  keeps: the zero ray, the arc, and the ball.

  THE RED QUESTION left open at step 2 - "which way does the second stick
  point?" - is answered by the program, not by this deck.

  TP7 SCARS, PAID FOR IN LESSON 12: a source line dies past 126 characters,
  and a BGI string too wide for 640 pixels is refused OUTRIGHT rather than
  clipped. Captions are budgeted Cap1 <= 39 chars (size 2) and Cap2 <= 78
  (size 1), and every one of them below was counted.

  Keys: any key = next step, ESC = leave early.
  INFOGR N starts at step N (the state fast-forwards honestly).

  Owlos - legacy software modernization - https://owlos.sk
  ========================================================================== }
program Infogr;

uses Graph, Crt;

const
  BgCol  = Blue;
  LinkA  = LightGreen;               { the upper arm - its colour in the COM }
  LinkB  = Yellow;                   { the forearm                           }
  LinkC  = LightRed;                 { the gripper                           }
  NeedC  = White;                    { the BALL: the shaft, ABSOLUTE angle   }
  MarkC  = DarkGray;                 { the ZERO RAY: the PARENT's direction  }
  ArgC   = LightMagenta;             { the ONE argued thing: the SUM         }
  BoneC  = LightGray;                { floor and pillar - the dead metal     }

  ArmX   = 200;  ArmY = 350;         { the shoulder's pivot, on the field    }
  FloorY = 412;
  L1     = 96;   L2 = 74;  L3 = 34;  { the three sticks, in pixels           }
  MR     = 14;                       { a motor ring                          }

  LegX   = 490;                      { the legend column                     }
  LegY   = 96;

  HomeA1 = 90;   HomeA2 = -90;       { the pose it rests in: up, then east   }
  HomeA3 = 0;

var
  A1, A2, A3 : Integer;              { the three OWN angles, degrees         }
  ShowArm    : Boolean;              { the play field: the machine...        }
  ShowAlg    : Boolean;              { ...or the algebra                     }
  ShowSky    : Boolean;              { ...or lesson 12's sky, recalled       }
  ShowMot    : Boolean;              { rings, rays, wedges and balls         }
  ShowGrip   : Boolean;              { the third stick - hidden while two    }
  Broken     : Boolean;              { draw it the WRONG way, on purpose     }
  AlgStage   : Integer;              { how far the algebra has got: 1..4     }
  HasLink, HasOwn, HasAbs, HasSum : Boolean;
  DoLink, DoBroken, DoSh, DoEl : Boolean;
  Scene      : Integer;              { 0 = the play; 1 = the closing card    }
  Cap1, Cap2 : string;
  Step       : Integer;
  Ch         : Char;

procedure Headline;
begin
  SetTextStyle(DefaultFont, HorizDir, 2);
  SetTextJustify(CenterText, TopText);
  SetColor(White);
  OutTextXY(320, 10, 'THE ARM THAT ADDS UP');
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetColor(LightCyan);
  OutTextXY(320, 36, 'a chain of turns, and why they collapse into one add  -  lesson 0D');
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
  if HasLink then begin
    SetColor(LinkA);
    Line(LegX, Y + 4, LegX + 12, Y + 4);
    SetColor(White);
    OutTextXY(LegX + 18, Y, 'LINK');
    SetColor(LightCyan);
    OutTextXY(LegX, Y + 14, 'a stick, and a');
    OutTextXY(LegX, Y + 26, 'motor at its end');
    Y := Y + 46;
  end;
  if HasOwn then begin
    SetColor(MarkC);
    OutTextXY(LegX, Y, 'ZERO RAY');
    SetColor(LightCyan);
    OutTextXY(LegX, Y + 14, 'this motor''s zero:');
    OutTextXY(LegX, Y + 26, 'its parent''s way');
    Y := Y + 46;
  end;
  if HasAbs then begin
    SetColor(NeedC);
    OutTextXY(LegX, Y, 'THE BALL');
    SetColor(LightCyan);
    OutTextXY(LegX, Y + 14, 'the shaft: where');
    OutTextXY(LegX, Y + 26, 'the link points');
    Y := Y + 46;
  end;
  if HasSum then begin
    SetColor(ArgC);
    OutTextXY(LegX, Y, 'THE SUM');
    SetColor(LightCyan);
    OutTextXY(LegX, Y + 14, 'absolute =');
    OutTextXY(LegX, Y + 26, 'parent + own');
  end;
end;

{ ---- one motor: the ring, the ZERO RAY, the wedge, and the ball ---------
  The first version of this drew a fat dot on the HOUSING and a thin needle
  on the shaft. Every number was right and the picture was dead: the boldest
  mark on the screen was the only one that could not move, and at the
  shoulder - the motor the deck tells you to watch first - it was nailed to
  east for ever. Weight goes on what MOVES.

     the ring       in this link's own colour
     the ZERO RAY   grey, from the centre outward at the PARENT's angle -
                    the parent's direction CONTINUED through the joint,
                    which is where this link would point if the motor stood
                    at zero. The skeleton alone can never show this line:
                    the parent's link arrives from the opposite side.
     the WEDGE      dots from the ray round to the link. ITS LENGTH IS THE
                    OWN ANGLE, drawn.
     the BALL       white, on the rim where the link crosses it: the shaft.
                    No needle is drawn to it - the link IS the needle.     }
procedure Motor(X, Y, Own, Parent, LinkCol: Integer);
var Ab, NX, NY, I, N, S, D: Integer;
begin
  Ab := Parent + Own;
  SetColor(LinkCol);
  Circle(X, Y, MR);
  SetColor(MarkC);                   { the zero ray: the PARENT's direction }
  NX := X + Round(Cos(Parent * Pi / 180) * (MR + 10));
  NY := Y - Round(Sin(Parent * Pi / 180) * (MR + 10));
  Line(X, Y, NX, NY);
  N := Abs(Own) div 6;               { the wedge: as long as the own angle  }
  if N > 30 then N := 30;
  D := 6;
  if Own < 0 then D := -6;
  for I := 0 to N do begin
    S := Parent + I * D;
    NX := X + Round(Cos(S * Pi / 180) * (MR - 6));
    NY := Y - Round(Sin(S * Pi / 180) * (MR - 6));
    PutPixel(NX, NY, LinkCol);
  end;
  NX := X + Round(Cos(Ab * Pi / 180) * MR);      { the ball: the shaft      }
  NY := Y - Round(Sin(Ab * Pi / 180) * MR);
  SetColor(NeedC);
  SetFillStyle(SolidFill, NeedC);
  FillEllipse(NX, NY, 3, 3);
end;

{ ---- the machine. Mode: correct = the sums; Broken = own angle only ------ }
procedure ArmDraw;
var b1, b2, b3: Integer;
    x0, y0, x1, y1, x2, y2, x3, y3: Integer;
begin
  b1 := A1;
  if Broken then begin b2 := A2; b3 := A3; end
            else begin b2 := b1 + A2; b3 := b2 + A3; end;
  x0 := ArmX;  y0 := ArmY;
  x1 := x0 + Round(Cos(b1 * Pi / 180) * L1);
  y1 := y0 - Round(Sin(b1 * Pi / 180) * L1);
  x2 := x1 + Round(Cos(b2 * Pi / 180) * L2);
  y2 := y1 - Round(Sin(b2 * Pi / 180) * L2);
  x3 := x2 + Round(Cos(b3 * Pi / 180) * L3);
  y3 := y2 - Round(Sin(b3 * Pi / 180) * L3);

  SetColor(BoneC);
  Line(40, FloorY, 455, FloorY);
  Line(x0, FloorY, x0, y0);

  SetColor(LinkA);
  Line(x0, y0, x1, y1);
  SetColor(LinkB);
  Line(x1, y1, x2, y2);
  if ShowGrip then begin
    SetColor(LinkC);
    Line(x2, y2, x3, y3);
  end;

  if ShowMot then begin
    Motor(x0, y0, A1, 0, LinkA);     { each motor wears the colour of the }
    Motor(x1, y1, A2, b1, LinkB);    {  link it drives, not of the one it }
    if ShowGrip then Motor(x2, y2, A3, b2, LinkC);   { is bolted to       }
  end
  else begin
    SetColor(White);
    Circle(x0, y0, 4);
    Circle(x1, y1, 4);
    if ShowGrip then Circle(x2, y2, 4);
  end;

  if Broken then begin               { name the fault, do not hide it      }
    SetColor(ArgC);
    Circle(x1, y1, MR + 8);
    SetTextStyle(DefaultFont, HorizDir, 2);
    SetTextJustify(LeftText, TopText);
    OutTextXY(x1 + 24, y1 - 30, '?');
  end;
end;

{ ---- lesson 12's sky, recalled in one small picture ---------------------- }
procedure SkyDraw;
var SX, SY, EX, EY, MX, MY: Integer;
begin
  SX := 150;  SY := 250;
  EX := SX + 90;  EY := SY - 40;
  MX := EX + 38;  MY := EY - 16;
  SetColor(Yellow);
  SetFillStyle(SolidFill, Yellow);
  FillEllipse(SX, SY, 7, 7);
  SetColor(DarkGray);
  Circle(SX, SY, 99);
  SetColor(White);
  SetFillStyle(SolidFill, White);
  FillEllipse(EX, EY, 4, 4);
  SetColor(DarkGray);
  Circle(EX, EY, 41);
  SetColor(LightGray);
  SetFillStyle(SolidFill, LightGray);
  FillEllipse(MX, MY, 3, 3);
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(LightCyan);
  OutTextXY(SX - 20, SY + 16, 'Sun');
  OutTextXY(EX - 14, EY + 50, 'Earth');
  OutTextXY(MX + 8, MY - 12, 'Moon');
  SetColor(ArgC);
  OutTextXY(60, 340, 'spin the Earth and the Moon''s orbit does NOT tilt:');
  OutTextXY(60, 354, 'the sky inherited a PLACE and nothing else.');
  SetColor(White);
  OutTextXY(60, 378, 'A machine is not a sky.');
end;

{ ---- the algebra: four panels, each one a step of the argument ----------- }
procedure AlgDraw;
begin
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(White);
  OutTextXY(40, 100, 'THE PARENT''S TURN, AND THEN ITS OWN');
  SetColor(LightCyan);
  OutTextXY(40, 130, '| cos a  -sin a |     | cos b  -sin b |');
  OutTextXY(40, 144, '|               |  x  |               |');
  OutTextXY(40, 158, '| sin a   cos a |     | sin b   cos b |');
  SetColor(White);
  OutTextXY(40, 178, 'R(a) - the parent          R(b) - its own');

  if AlgStage >= 2 then begin
    SetColor(White);
    OutTextXY(40, 212, 'MULTIPLY THEM OUT - the left column:');
    SetColor(LightCyan);
    OutTextXY(40, 236, 'top     cos a cos b - sin a sin b');
    OutTextXY(40, 250, 'bottom  sin a cos b + cos a sin b');
    SetColor(DarkGray);
    OutTextXY(40, 266, 'eight multiplies to place ONE link.');
  end;

  if AlgStage >= 3 then begin
    SetColor(ArgC);
    OutTextXY(40, 292, 'cos a cos b - sin a sin b  =  cos (a+b)');
    OutTextXY(40, 306, 'sin a cos b + cos a sin b  =  sin (a+b)');
    SetColor(White);
    OutTextXY(40, 330, 'a = 30, b = 45:');
    SetColor(LightCyan);
    OutTextXY(40, 346, '0.866 x 0.707 - 0.500 x 0.707  =  0.259');
    OutTextXY(40, 360, 'and cos 75                     =  0.259');
  end;

  if AlgStage >= 4 then begin
    SetFillStyle(SolidFill, BgCol);
    Bar(30, 200, 465, 400);
    SetTextStyle(DefaultFont, HorizDir, 2);
    SetColor(ArgC);
    OutTextXY(40, 230, 'R(a) x R(b)  =  R(a + b)');
    SetTextStyle(DefaultFont, HorizDir, 1);
    SetColor(White);
    OutTextXY(40, 280, 'So the matrices need never be multiplied:');
    SetColor(ArgC);
    OutTextXY(40, 300, 'THE ANGLES SIMPLY ADD.');
    SetColor(LightCyan);
    OutTextXY(40, 330, 'eight multiplies    ->    one ADD AL, [own]');
    SetColor(DarkGray);
    OutTextXY(40, 356, 'and an angle in a byte wraps round by itself.');
  end;
end;

{ ---- the running sum, written beside the machine ------------------------- }
procedure SumPanel;
begin
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(White);
  OutTextXY(300, 110, 'THE RUNNING SUM');
  SetColor(LinkA);
  OutTextXY(300, 132, 'shoulder   0 + own');
  SetColor(LinkB);
  OutTextXY(300, 146, 'forearm    that + own');
  SetColor(LinkC);
  OutTextXY(300, 160, 'gripper    that + own');
  SetColor(ArgC);
  OutTextXY(300, 182, 'three adds, whole arm');
end;

procedure PlayField;
begin
  SetFillStyle(SolidFill, BgCol);
  Bar(20, 84, 470, 430);
  if ShowSky then SkyDraw;
  if ShowAlg then AlgDraw;
  if ShowArm then begin
    ArmDraw;
    if HasSum and not ShowMot then SumPanel;
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
  SetColor(LinkA);
  OutTextXY(320, 160, 'THE STICK.');
  SetColor(ArgC);
  OutTextXY(320, 210, 'THE SUM.');
  SetColor(White);
  OutTextXY(320, 260, 'THE MACHINE.');
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetColor(LightCyan);
  OutTextXY(320, 300, 'one add a joint - and every skeleton in every game works this way');
  SetColor(DarkGray);
  OutTextXY(320, 322, 'the catch: angles add only about ONE axis. Three of them do not.');
  Captions;
end;

procedure DrawAll;
begin
  if Scene = 0 then DrawMain else DrawFinal;
end;

{ ---- the little films ----------------------------------------------------- }
procedure AnimLink;                  { the upper arm alone, swinging        }
var I: Integer;
begin
  for I := 1 to 80 do begin
    if I <= 40 then A1 := A1 + 1 else A1 := A1 - 1;
    PlayField;
    Delay(24);
  end;
end;

procedure AnimBroken;                { the shoulder turns, the arm breaks   }
var I: Integer;
begin
  for I := 1 to 100 do begin
    if I <= 50 then A1 := A1 + 1 else A1 := A1 - 1;
    PlayField;
    Delay(26);
  end;
end;

procedure AnimShoulder;              { every needle moves, no gap changes   }
var I: Integer;
begin
  for I := 1 to 120 do begin
    if I <= 60 then A1 := A1 + 1 else A1 := A1 - 1;
    PlayField;
    Delay(26);
  end;
end;

procedure AnimElbow;                 { one gap opens, and only one          }
var I: Integer;
begin
  for I := 1 to 120 do begin
    if I <= 60 then A2 := A2 + 1 else A2 := A2 - 1;
    PlayField;
    Delay(26);
  end;
end;

procedure SetStep(N: Integer);
begin
  DoLink := False;  DoBroken := False;  DoSh := False;  DoEl := False;
  case N of
    0: begin
         Scene := 0;  ShowArm := True;  ShowAlg := False;  ShowSky := False;
         ShowMot := False;  ShowGrip := True;  Broken := False;
         AlgStage := 0;
         HasLink := True; HasOwn := False; HasAbs := False; HasSum := False;
         A1 := HomeA1;  A2 := HomeA2;  A3 := HomeA3;
         Cap1 := 'A machine, in three sticks.';
         Cap2 := 'Shoulder, forearm, gripper - a motor at every joint, all turning one way.';
       end;
    1: begin ShowGrip := False;  DoLink := True;
         Cap1 := 'One link: a stick lying east.';
         Cap2 := 'Turn it by lesson 12''s matrix: out falls r cos a, r sin a. Nothing new.';
       end;
    2: begin
         Cap1 := 'Hang a second stick on its end.';
         Cap2 := 'The elbow is where the first stopped. But which way does the second point?';
       end;
    3: begin Broken := True;  DoBroken := True;  HasOwn := True;
         Cap1 := 'The wrong answer looks right.';
         Cap2 := 'Give the forearm its OWN angle only: the shoulder turns without it.';
       end;
    4: begin Broken := False;  ShowArm := False;  ShowSky := True;
         Cap1 := 'Lesson 12 inherited PLACE only.';
         Cap2 := 'A moon''s orbit does not tilt when its planet spins. Wrong for a machine.';
       end;
    5: begin ShowSky := False;  ShowAlg := True;  AlgStage := 1;
         HasAbs := True;
         Cap1 := 'So turn it twice: R(a), then R(b).';
         Cap2 := 'The parent''s matrix times its own. Two little squares, multiplied.';
       end;
    6: begin AlgStage := 2;
         Cap1 := 'Multiply the two squares out.';
         Cap2 := 'The top left comes out cos a cos b - sin a sin b. Four products, one cell.';
       end;
    7: begin AlgStage := 3;
         Cap1 := 'Those names are already known.';
         Cap2 := 'cos a cos b - sin a sin b IS cos(a+b). Try 30 and 45: both give 0.259.';
       end;
    8: begin AlgStage := 4;  HasSum := True;
         Cap1 := 'R(a) x R(b) = R(a + b).';
         Cap2 := 'A whole matrix product collapses to one ADD. THE ANGLES SIMPLY ADD.';
       end;
    9: begin ShowAlg := False;  ShowArm := True;  ShowGrip := True;
         A1 := HomeA1;  A2 := HomeA2;  A3 := HomeA3;
         Cap1 := 'So the arm is a running SUM.';
         Cap2 := 'Each link points at its parent''s angle plus its own: three adds in all.';
       end;
   10: begin ShowMot := True;
         Cap1 := 'What a motor will show you.';
         Cap2 := 'The grey ray is this motor''s zero. The ball is the shaft. The arc is its own.';
       end;
   11: begin DoSh := True;
         Cap1 := 'Turn the shoulder alone.';
         Cap2 := 'Every ball and every ray moves - and no arc changes size. Inheritance.';
       end;
   12: begin DoEl := True;
         Cap1 := 'Now the elbow alone.';
         Cap2 := 'One arc opens, and only one. A child can never move its parent.';
       end;
   13: begin Scene := 1;
         Cap1 := 'Now for real - in a COM file.';
         Cap2 := 'One table, one add a joint. And the catch: this works about ONE axis.';
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
    if Step < S0 then Continue;    { fast-forward: the STATE still replays }
    DrawAll;
    if DoLink then AnimLink;
    if DoBroken then AnimBroken;
    if DoSh then AnimShoulder;
    if DoEl then AnimElbow;
    while KeyPressed do Ch := ReadKey;  { taps buffered during a Delay must
                                          not eat the steps that follow }
    Ch := ReadKey;
    WriteLn(LF, 'step=', Step, ' a1=', A1, ' a2=', A2, ' key=', Ord(Ch));
    if Ch = #27 then Break;
    if Ch = #0 then Ch := ReadKey;
  end;
  Close(LF);
  CloseGraph;
end.
