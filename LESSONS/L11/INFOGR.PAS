{ ==========================================================================
  INFOGR.PAS - the opening infographic for lesson 11 (the keyboard is a
  computer: scan codes, the port, the BIOS buffer, the DOS line - and the
  question none of those floors can answer).

     D:\BIN\TPC.EXE -B -UD:\UNITS INFOGR.PAS     (see MAKEINFO.BAT)

  NOT PART OF THE LESSON - the title sequence the video opens with.

  THE LADDER IT CLIMBS:
     the keyboard, drawn as what it is: a computer of its own
   - press W: a BYTE flies up the wire - 11h, the NUMBER of a key
   - release: 91h - the same number, top bit up. Make and break.
   - the byte lands in a LATCH - port 60h - and INT 9 RINGS
   - the BIOS floor: numbers become letters, sixteen wait in a ring
   - the TRAP: typed while the program is busy - kept, and heard late
   - the DOS floor: whole lines, edited for free, heard last of all
   - THE TOWER, complete - the flashback frame the lesson returns to
   - the hook, in red: which keys are held DOWN, right now? No floor
     can say. The game will unplug the BIOS and listen to the wire.

  ONE COLOUR, ONE MEANING (the house rule): a press is yellow, a release
  is dim grey - exactly the colours the lesson's own program uses on the
  same bytes. Floors are cyan, what they hand over is green. Red is
  reserved for the ONE argued thing: the question the tower cannot answer.

  THE RULE OF THE ARROW: an arrow is the byte's road, always upward,
  always one meaning. No word appears on the play field before the
  legend on the right names it.

  Keys: any key = next step, ESC = leave early.
  INFOGR N starts at step N (the state fast-forwards honestly).

  Owlos - legacy software modernization - https://owlos.sk
  ========================================================================== }
program Infogr;

uses Graph, Crt;

const
  BgCol  = Blue;
  KbdCol = White;                    { the keyboard's body                }
  PrsCol = Yellow;                   { a PRESS byte - the lesson's colour }
  RelCol = DarkGray;                 { a RELEASE byte - dim, going away   }
  FlrCol = LightCyan;                { a floor: port, BIOS, DOS           }
  OutCol = LightGreen;               { what a floor hands the program     }
  HotCol = LightRed;                 { the ONE argued thing: the question }

  KbX1 = 100;  KbY1 = 356;           { the keyboard's box                 }
  KbX2 = 380;  KbY2 = 424;
  WireX = 240;                       { the wire the bytes climb           }
  PtY1 = 288;  PtY2 = 326;           { the port floor                     }
  BiY1 = 196;  BiY2 = 250;           { the BIOS floor                     }
  DoY1 = 104;  DoY2 = 158;           { the DOS floor                      }
  FlX1 = 140;  FlX2 = 360;           { floors share one width             }
  PgX1 = 392;  PgX2 = 472;           { the program, off to the right      }
  LegX = 500;                        { the legend column                  }
  LegY = 96;

var
  ShowPort, ShowBios, ShowDos : Boolean;
  ShowPair, ShowHook          : Boolean;
  Cells      : Integer;              { how full the BIOS ring is, 0..16   }
  Busy       : Integer;              { 0 no lamp, 1 red, 2 green          }
  PressKey   : Boolean;              { the W keycap, held down            }
  HasScan, HasPort, HasBuf, HasDos : Boolean;
  Scene      : Integer;              { 0 = the play; 1 = the closing card }
  Cap1, Cap2 : string;
  Step       : Integer;
  Ch         : Char;

procedure Headline;
begin
  { size 2, not 3: at size 3 a long line is wider than the screen and
    BGI silently refuses to draw it - lesson 10 lost its title that way }
  SetTextStyle(DefaultFont, HorizDir, 2);
  SetTextJustify(CenterText, TopText);
  SetColor(White);
  OutTextXY(320, 10, 'THE KEYBOARD IS A COMPUTER');
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetColor(LightCyan);
  OutTextXY(320, 36, 'scan codes, the port, the floors  -  lesson 11');
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
  SetColor(PrsCol);
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
  OutTextXY(LegX, LegY, 'THE WORDS');
  Line(LegX, LegY + 12, 632, LegY + 12);
  Y := LegY + 24;
  if HasScan then begin
    SetFillStyle(SolidFill, PrsCol);
    Bar(LegX, Y, LegX + 12, Y + 8);
    SetColor(White);
    OutTextXY(LegX + 18, Y, 'SCAN CODE');
    SetColor(LightCyan);
    OutTextXY(LegX + 18, Y + 12, 'a KEY''s number');
    Y := Y + 34;
  end;
  if HasPort then begin
    SetColor(FlrCol);
    Rectangle(LegX, Y, LegX + 12, Y + 8);
    SetColor(White);
    OutTextXY(LegX + 18, Y, 'PORT + INT 9');
    SetColor(LightCyan);
    OutTextXY(LegX + 18, Y + 12, 'the doorbell');
    Y := Y + 34;
  end;
  if HasBuf then begin
    SetColor(White);
    OutTextXY(LegX, Y, 'THE BUFFER');
    SetColor(LightCyan);
    OutTextXY(LegX, Y + 12, 'sixteen wait');
    Y := Y + 34;
  end;
  if HasDos then begin
    SetColor(White);
    OutTextXY(LegX, Y, 'THE LINE');
    SetColor(LightCyan);
    OutTextXY(LegX, Y + 12, 'edited for free');
  end;
end;

{ ---- the keyboard: a body, keycaps, and the chip that makes it a computer - }
procedure Keyboard;
var I, J, X, Y: Integer;
begin
  SetColor(KbdCol);
  Rectangle(KbX1, KbY1, KbX2, KbY2);
  for J := 0 to 2 do
    for I := 0 to 11 do begin
      X := KbX1 + 12 + I * 22;
      Y := KbY1 + 8 + J * 20;
      if PressKey and (I = 1) and (J = 1) then begin
        SetFillStyle(SolidFill, PrsCol);       { W, held down }
        Bar(X, Y, X + 16, Y + 14);
        SetColor(Black);
        SetTextStyle(DefaultFont, HorizDir, 1);
        SetTextJustify(LeftText, TopText);
        OutTextXY(X + 5, Y + 4, 'W');
        SetColor(KbdCol);
      end
      else
        Rectangle(X, Y, X + 16, Y + 14);
    end;
  { the chip: the whole argument in one label }
  SetFillStyle(SolidFill, Black);
  Bar(KbX1 + 80, KbY2 - 13, KbX1 + 200, KbY2 - 1);
  SetColor(OutCol);
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  OutTextXY(KbX1 + 86, KbY2 - 11, 'its own CPU inside');
end;

{ ---- one floor: a box with a name ----------------------------------------- }
procedure Floor(Y1, Y2: Integer; Name: string);
begin
  SetColor(FlrCol);
  Rectangle(FlX1, Y1, FlX2, Y2);
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(White);
  OutTextXY(FlX1 + 8, Y1 + 6, Name);
end;

{ ---- the byte's road: an upward arrow ------------------------------------- }
procedure Road(Y1, Y2: Integer);
begin
  SetColor(PrsCol);
  Line(WireX, Y1, WireX, Y2);
  Line(WireX - 4, Y2 + 6, WireX, Y2);
  Line(WireX + 4, Y2 + 6, WireX, Y2);
end;

{ ---- the program, and its lamp -------------------------------------------- }
procedure Prog;
begin
  SetColor(White);
  Rectangle(PgX1, BiY1, PgX2, BiY2);
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  OutTextXY(PgX1 + 8, BiY1 + 6, 'your');
  OutTextXY(PgX1 + 8, BiY1 + 18, 'program');
  if Busy > 0 then begin
    if Busy = 1 then SetFillStyle(SolidFill, HotCol)
    else SetFillStyle(SolidFill, OutCol);
    FillEllipse(PgX2 - 14, BiY1 + 12, 6, 6);
    SetColor(White);
    if Busy = 1 then OutTextXY(PgX1 + 8, BiY2 - 14, 'BUSY')
    else OutTextXY(PgX1 + 8, BiY2 - 14, 'ready');
  end;
end;

{ ---- the play field, erased and redrawn as one ----------------------------- }
procedure Play;
var I, X: Integer;
begin
  SetFillStyle(SolidFill, BgCol);
  Bar(20, 84, 478, 430);
  Keyboard;
  if ShowPort then begin
    Road(KbY1 - 2, PtY2 + 2);
    Floor(PtY1, PtY2, 'PORT 60h - the latch');
    SetColor(PrsCol);
    SetTextJustify(LeftText, TopText);
    OutTextXY(FlX2 - 40, PtY1 + 18, '11');
    SetColor(White);
    OutTextXY(FlX1 + 8, PtY1 + 22, 'INT 9 rings');
  end;
  if ShowBios then begin
    Road(PtY1 - 2, BiY2 + 2);
    Floor(BiY1, BiY2, 'BIOS - INT 16h');
    for I := 0 to 15 do begin                  { the ring: sixteen cells }
      X := FlX1 + 10 + I * 13;
      SetColor(White);
      Rectangle(X, BiY2 - 22, X + 10, BiY2 - 8);
      if I < Cells then begin
        SetFillStyle(SolidFill, PrsCol);
        Bar(X + 1, BiY2 - 21, X + 9, BiY2 - 9);
      end;
    end;
    Prog;
    SetColor(OutCol);                          { what the BIOS hands over }
    Line(FlX2, (BiY1 + BiY2) div 2, PgX1, (BiY1 + BiY2) div 2);
    Line(PgX1 - 6, (BiY1 + BiY2) div 2 - 4, PgX1, (BiY1 + BiY2) div 2);
    Line(PgX1 - 6, (BiY1 + BiY2) div 2 + 4, PgX1, (BiY1 + BiY2) div 2);
    if ShowPair then begin
      SetTextJustify(LeftText, TopText);
      SetColor(OutCol);
      OutTextXY(FlX2 - 70, BiY1 + 6, '11 -> w');
    end;
  end;
  if ShowDos then begin
    Road(BiY1 - 2, DoY2 + 2);
    Floor(DoY1, DoY2, 'DOS - INT 21h');
    SetColor(OutCol);
    SetTextJustify(LeftText, TopText);
    OutTextXY(FlX1 + 8, DoY1 + 24, '> hello_');
    SetColor(White);
    OutTextXY(FlX1 + 8, DoY1 + 38, 'a whole LINE, backspace and all');
  end;
  if ShowHook then begin
    { the question stands IN FRONT of the tower - a black card over the
      DOS floor, red-framed: the one thing the whole building cannot do }
    SetFillStyle(SolidFill, Black);
    Bar(28, 88, 470, 176);
    SetColor(HotCol);
    Rectangle(28, 88, 470, 176);
    SetTextStyle(DefaultFont, HorizDir, 1);
    SetTextJustify(LeftText, TopText);
    OutTextXY(40, 96, 'the game asks:');
    SetTextStyle(DefaultFont, HorizDir, 2);
    OutTextXY(40, 110, 'WHICH KEYS ARE HELD');
    OutTextXY(40, 130, 'DOWN - RIGHT NOW?');
    SetTextStyle(DefaultFont, HorizDir, 1);
    SetColor(White);
    OutTextXY(40, 152, 'every floor answers a different');
    OutTextXY(40, 164, 'question: which key ARRIVED.');
  end;
end;

{ ---- one byte flies up the wire, keyboard to port -------------------------- }
procedure FlyByte(S: string; C: Word);
var Y: Integer;
begin
  for Y := 0 to 10 do begin
    Play;
    SetFillStyle(SolidFill, C);
    Bar(WireX + 6, KbY1 - 12 - Y * 2, WireX + 32, KbY1 - Y * 2);
    SetColor(Black);
    SetTextStyle(DefaultFont, HorizDir, 1);
    SetTextJustify(LeftText, TopText);
    OutTextXY(WireX + 10, KbY1 - 10 - Y * 2, S);
    Delay(60);
  end;
  Delay(250);
  Play;
end;

{ ---- the trap: four keys typed into a busy program ------------------------- }
procedure AnimTrap;
var I: Integer;
begin
  Busy := 1;
  Play;
  Delay(400);
  for I := 1 to 4 do begin
    Cells := I;
    Play;
    Delay(350);
  end;
  Delay(500);
  Busy := 2;
  Play;
  Delay(400);
  while Cells > 0 do begin
    Cells := Cells - 1;
    Play;
    Delay(250);
  end;
end;

procedure DrawMain;
begin
  SetFillStyle(SolidFill, BgCol);
  Bar(0, 0, 639, 479);
  Headline;
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
  SetColor(PrsCol);
  OutTextXY(320, 180, 'SCAN. BUFFER. LINE.');
  SetTextStyle(DefaultFont, HorizDir, 2);
  SetColor(White);
  OutTextXY(320, 240, 'and the wire underneath them all');
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetColor(LightCyan);
  OutTextXY(320, 280, 'now for real, in a COM file - and the game unplugs the BIOS');
  Captions;
end;

procedure DrawAll;
begin
  if Scene = 0 then DrawMain else DrawFinal;
end;

procedure SetStep(N: Integer);
begin
  case N of
    0: begin ShowPort := False; ShowBios := False; ShowDos := False;
             ShowPair := False; ShowHook := False;
             Cells := 0; Busy := 0; PressKey := False; Scene := 0;
             HasScan := False; HasPort := False;
             HasBuf := False; HasDos := False;
             Cap1 := 'The keyboard is a computer of its own.';
             Cap2 := 'A processor lives inside it. It does not send letters - it cannot. It sends BYTES.';
       end;
    1: begin PressKey := True; HasScan := True;
             Cap1 := 'Press W: 11h flies down the wire.';
             Cap2 := 'Not a letter - the NUMBER of a KEY. The scan code. Every key has one, shifts and arrows too.';
       end;
    2: begin PressKey := False;
             Cap1 := 'Release: 91h - top bit up.';
             Cap2 := 'Make and break: the keyboard reports both edges, and the top bit is the whole difference.';
       end;
    3: begin ShowPort := True; HasPort := True;
             Cap1 := 'The latch at port 60h. INT 9 rings.';
             Cap2 := 'Not a queue - a latch: the LAST byte, sitting there. The doorbell is an INTERRUPT.';
       end;
    4: begin ShowBios := True; ShowPair := True; Cells := 1; HasBuf := True;
             Cap1 := 'The BIOS floor: numbers become letters.';
             Cap2 := 'Its INT 9 handler reads the port, mints the ASCII, and queues the PAIR - sixteen fit.';
       end;
    5: begin ShowPair := False;
             Cap1 := 'The trap: type at a BUSY program.';
             Cap2 := 'Nothing is lost - and nothing is heard NOW. The buffer answers later, all at once.';
       end;
    6: begin ShowDos := True; HasDos := True; Cells := 0; Busy := 0;
             Cap1 := 'The DOS floor: a whole LINE, free.';
             Cap2 := 'Backspace, the length limit, the beep - INT 21h sells all of it. Highest floor, latest word.';
       end;
    7: begin
             Cap1 := 'The tower. Remember this picture.';
             Cap2 := 'The wire. The port and its bell. The BIOS and its sixteen. DOS and its line.';
       end;
    8: begin ShowHook := True;
             Cap1 := 'And one question NO floor can answer.';
             Cap2 := 'Held is not arrived. To know what is held RIGHT NOW, the game must listen to the wire itself.';
       end;
    9: begin Scene := 1;
             Cap1 := 'Lesson 11 - now for real, in COM.';
             Cap2 := 'Four frames: the port, the buffer, the line - and a square that drives on our own INT 9.';
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
    if (EC <> 0) or (S0 < 0) or (S0 > 9) then S0 := 0;
  end;
  Gd := VGA; Gm := VGAHi;
  InitGraph(Gd, Gm, 'D:\BGI');
  if GraphResult <> grOk then begin
    WriteLn('EGAVGA.BGI not found - mount Borland Pascal as D: (MAKEINFO.BAT does).');
    Halt(1);
  end;
  for Step := 0 to 9 do begin
    SetStep(Step);
    if Step < S0 then Continue;      { fast-forward: the STATE still replays }
    DrawAll;
    if Step = 1 then FlyByte('11', PrsCol);
    if Step = 2 then FlyByte('91', RelCol);
    if Step = 5 then AnimTrap;
    while KeyPressed do Ch := ReadKey;  { taps buffered during a Delay must
                                          not eat the steps that follow }
    Ch := ReadKey;
    WriteLn(LF, 'step=', Step, ' cells=', Cells, ' key=', Ord(Ch));
    if Ch = #27 then Break;
    if Ch = #0 then Ch := ReadKey;
  end;
  Close(LF);
  CloseGraph;
end.
