{ ==========================================================================
  INFOGR.PAS - the opening infographic for lesson 9 (JIT, second sitting).

     D:\BIN\TPC.EXE -B -UD:\UNITS INFOGR.PAS     (see MAKEINFO.BAT)

  NOT PART OF THE LESSON - the title sequence the video opens with.

  THE PROGRAM IT SHOWS is a real COM file's memory, addresses ascending
  down the page in reading order (0100h right after the PSP):

      0100  E8 0D 00            Start:   call Patch
      0103  C7 06 11 01 78 56   Change:  mov  word [0111h], 5678h
      0109  E8 04 00                     call Patch
      010C  ..                           (four unused cells)
      0110  B8 34 12            Patch:   mov  ax, 1234h
      0113  89 06 00 02                  mov  [0200h], ax
      0117  C3                           ret

  The write is the LONG form of mov on purpose - unlike A3 it carries a
  REGISTER FIELD, so act 2 can poke both registers: B8->BB (three bits
  in the opcode) and 06->1E (three bits in the modrm), and the run then
  works through BX end to end.

  THE RULE OF THE ARROW, everywhere: CS:IP standing ON an instruction
  means it has NOT happened yet - and that holds for the register (ax
  shows ???? until B8 has run) and for [0200h] (rubbish until the write has).
  The source line under the arrow wears the same red as its cells.

  THREE ACTS (the director's cut, 2026-08-24):
   1  the honest walk: call, load, write-swapped, ret home; then code
      changes code - the write itself is ANIMATED (traces crawl, cells
      flash, only then the arrow moves on) - and the second call runs
      the full walk again through the new number.
   2  the registers: pokes from OUTSIDE (DEBUG's e command) into BOTH
      register fields - B8->BB in the opcode, 06->1E in the modrm - and
      a full honest run that works through BX end to end.
      Freshly poked cells are YELLOW; red means CS:IP is executing here.
   3  the road: a fresh little screen - jmp short is EB and a DISTANCE
      CELL; poke the distance and the same jump takes the other road.
      An if whose question was asked once - and how OWL FLY III picks
      its video card.

  The closing card says JIT. 8086. - the processor, not a year.

  Keys: any key = next step, ESC = leave early.

  Owlos - legacy software modernization - https://owlos.sk
  ========================================================================== }
program Infogr;

uses Graph, Crt;

const
  CellW  = 48;  CellH = 30;
  ChsX   = 32;  ChsY  = 200;         { 0100..010B - the caller + changer  }
  MemX   = 32;  MemY  = 300;         { 0110..0116 - Patch, further DOWN   }
  DstX   = 480;
  DstY   = 84;
  SrcX   = 24;  SrcY  = 52;

  BgCol  = Blue;
  PanCol = LightGray;
  HotCol = LightRed;
  ImmCol = Yellow;
  IpCol  = LightGreen;

  GrbLo  = $A7; GrbHi = $0E;         { the previous program's rubbish     }

  { Ip: -1 nowhere; 100/103/109 = the top strip's three instructions;
    0/3/6 = Patch's cells                                              }

var
  Imm     : Word;
  RegB    : Byte;                    { B8 mov ax / BB mov bx            }
  Reg2B   : Byte;                    { the write's modrm: 06 ax / 1E bx  }
  AxVal   : LongInt;
  DstW    : LongInt;
  Ip      : Integer;
  PImm    : Word;
  Scene   : Integer;                 { 0 = the program; 1 = the road      }
  JDisp   : Byte;                    { the road's distance cell           }
  JHot    : Boolean;                 { ...freshly poked?                  }
  DoAnim  : Boolean;                 { step 6 animates the write          }
  DoPoke  : Boolean;                 { act 2's pokes animate the same way }
  PokeReg : Boolean;                 { act 2: cells 0110-0112 fresh-poked }
  TrOn    : Boolean;                 { the red write-traces are on screen }
  DstHot  : Boolean;                 { [0200h] freshly written - YELLOW   }
  Cap1, Cap2 : string;
  Step    : Integer;
  Ch      : Char;

function HexB(B: Byte): string;
const H: string[16] = '0123456789ABCDEF';
begin
  HexB := H[B div 16 + 1] + H[B mod 16 + 1];
end;

function HexW(W: Word): string;
begin
  HexW := HexB(Hi(W)) + HexB(Lo(W));
end;

function RegName: string;
begin
  if RegB = $B8 then RegName := 'ax' else RegName := 'bx';
end;

function Reg2Name: string;
begin
  if Reg2B = $06 then Reg2Name := 'ax' else Reg2Name := 'bx';
end;

procedure Cell(X, Y: Integer; Txt: string; Addr: Word; St: Integer);
{ St: 0 plain, 1 red = CS:IP is HERE, 2 yellow = freshly POKED }
begin
  case St of
    1: SetFillStyle(SolidFill, HotCol);
    2: SetFillStyle(SolidFill, ImmCol);
    else SetFillStyle(SolidFill, PanCol);
  end;
  Bar(X, Y, X + CellW - 8, Y + CellH);
  SetColor(White);
  Rectangle(X, Y, X + CellW - 8, Y + CellH);
  if St = 1 then SetColor(White) else SetColor(Black);
  SetTextStyle(DefaultFont, HorizDir, 2);
  SetTextJustify(CenterText, CenterText);
  OutTextXY(X + (CellW - 8) div 2, Y + CellH div 2, Txt);
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetColor(LightCyan);
  OutTextXY(X + (CellW - 8) div 2, Y + CellH + 8, HexW(Addr));
end;

procedure Brace(StripX, StripY, FirstCell, Count: Integer; Txt: string);
var X1, X2, Y: Integer;
begin
  X1 := StripX + FirstCell * CellW + 2;
  X2 := StripX + (FirstCell + Count) * CellW - 12;
  Y  := StripY + CellH + 20;
  SetColor(White);
  Line(X1, Y, X2, Y);
  Line(X1, Y, X1, Y - 5);
  Line(X2, Y, X2, Y - 5);
  Line((X1 + X2) div 2, Y, (X1 + X2) div 2, Y + 4);
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(CenterText, TopText);
  OutTextXY((X1 + X2) div 2, Y + 7, Txt);
end;

procedure IpArrow(X, StripY: Integer; Lbl: string);
begin
  SetColor(IpCol);
  SetFillStyle(SolidFill, IpCol);
  FillEllipse(X, StripY - 20, 4, 4);
  Line(X, StripY - 20, X, StripY - 4);
  Line(X - 6, StripY - 10, X, StripY - 4);
  Line(X + 6, StripY - 10, X, StripY - 4);
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(CenterText, BottomText);
  OutTextXY(X, StripY - 25, Lbl);
end;

procedure Headline;
begin
  SetTextStyle(DefaultFont, HorizDir, 3);
  SetTextJustify(CenterText, TopText);
  SetColor(White);
  OutTextXY(320, 8, 'THE PROGRAM THAT REWRITES ITSELF');
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetColor(LightCyan);
  OutTextXY(320, 36, 'self-modifying code  -  lesson 9');
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
  SetTextJustify(CenterText, TopText);
  SetColor(ImmCol);
  SetTextStyle(DefaultFont, HorizDir, 2);
  SetTextJustify(CenterText, TopText);
  OutTextXY(320, 440, Cap1);
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetColor(White);
  OutTextXY(320, 462, Cap2);
end;

{ ---- the write's red traces, from the changer's cells down to Patch's ----- }
procedure Traces;
var X: Integer;
begin
  SetColor(HotCol);
  X := ChsX + CellW * 7 + (CellW - 8) div 2;
  Line(X, ChsY + CellH + 12, MemX + CellW + (CellW - 8) div 2, MemY - 4);
  X := ChsX + CellW * 8 + (CellW - 8) div 2;
  Line(X, ChsY + CellH + 12, MemX + CellW * 2 + (CellW - 8) div 2, MemY - 4);
end;

{ ---- scene 0: the program ------------------------------------------------- }
procedure DrawMain;
var I, X: Integer;
    B: array[0..7] of Byte;
    T: array[0..11] of Byte;
    Hot: Boolean;
begin
  SetFillStyle(SolidFill, BgCol);
  Bar(0, 0, 639, 479);
  Headline;

  { the source - reading order = address order = execution order. The
    line CS:IP stands on wears the same red as its cells. }
  case Ip of
    100: I := 0;  103: I := 1;  109: I := 2;
    0:   I := 3;  3:   I := 4;  7:   I := 5;
    else I := -1;
  end;
  if I >= 0 then begin
    if I >= 3 then X := SrcY + 40 + (I - 3) * 12
              else X := SrcY + I * 12;
    SetFillStyle(SolidFill, HotCol);
    Bar(SrcX - 6, X - 2, SrcX + 274, X + 9);
  end;
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(White);
  OutTextXY(SrcX, SrcY,      'Start:   call Patch');
  if I = 1 then SetColor(White)   { the label must live on the bar }
           else SetColor(LightRed);
  OutTextXY(SrcX, SrcY + 12, 'Change:');
  SetColor(White);
  OutTextXY(SrcX + 9 * 8, SrcY + 12, 'mov  word [0111h],');
  SetColor(ImmCol);
  OutTextXY(SrcX + 28 * 8, SrcY + 12, HexW(PImm) + 'h');
  SetColor(White);
  OutTextXY(SrcX, SrcY + 24, '         call Patch');
  OutTextXY(SrcX, SrcY + 40, 'Patch:   mov  ' + RegName + ',');
  SetColor(ImmCol);
  OutTextXY(SrcX + 18 * 8, SrcY + 40, HexW(Imm) + 'h');
  SetColor(White);
  OutTextXY(SrcX, SrcY + 52, '         mov  [0200h], ' + Reg2Name);
  OutTextXY(SrcX, SrcY + 64, '         ret');

  { the right column: the register, then the destination word }
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetColor(White);
  Rectangle(DstX - 10, 50, 628, 70);
  if RegB = $B8 then begin
    if AxVal < 0 then
      OutTextXY(DstX, 57, 'ax = ????')
    else
      OutTextXY(DstX, 57, 'ax = ' + HexW(Word(AxVal)));
  end else begin
    { act 2: BOTH registers - ax kept its act-one word, bx is the story }
    if AxVal < 0 then
      OutTextXY(DstX, 57, 'ax=5678 bx=????')
    else
      OutTextXY(DstX, 57, 'ax=5678 bx=' + HexW(Word(AxVal)));
  end;
  OutTextXY(DstX, DstY - 12, 'the word at [0200h]:');
  if DstW < 0 then begin
    Cell(DstX,          DstY, HexB(GrbLo), $0200, 0);
    Cell(DstX + CellW,  DstY, HexB(GrbHi), $0201, 0);
    SetTextStyle(DefaultFont, HorizDir, 1);
    SetTextJustify(LeftText, TopText);
    SetColor(LightGray);
    OutTextXY(DstX - 10, DstY + CellH + 20, 'rubbish left behind');
  end else begin
    if DstHot then begin
      Cell(DstX,          DstY, HexB(Lo(Word(DstW))), $0200, 2);
      Cell(DstX + CellW,  DstY, HexB(Hi(Word(DstW))), $0201, 2);
    end else begin
      Cell(DstX,          DstY, HexB(Lo(Word(DstW))), $0200, 0);
      Cell(DstX + CellW,  DstY, HexB(Hi(Word(DstW))), $0201, 0);
    end;
    SetTextStyle(DefaultFont, HorizDir, 1);
    SetTextJustify(LeftText, TopText);
    SetColor(ImmCol);
    OutTextXY(DstX - 10, DstY + CellH + 20, HexW(Word(DstW)) + 'h lies as ' +
              HexB(Lo(Word(DstW))) + ' ' + HexB(Hi(Word(DstW))));
    OutTextXY(DstX - 10, DstY + CellH + 32, '- low byte first');
  end;

  { the whole program, as MEMORY sees it }
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(White);
  OutTextXY(ChsX, ChsY - 52, 'the program, as MEMORY sees it - loaded at 0100, right after the PSP:');
  T[0] := $E8; T[1] := $0D; T[2]  := $00;
  T[3] := $C7; T[4] := $06; T[5]  := $11; T[6] := $01;
  T[7] := Lo(PImm); T[8] := Hi(PImm);
  T[9] := $E8; T[10] := $04; T[11] := $00;
  for I := 0 to 11 do begin
    if I < 3 then Hot := (Ip = 100)
    else if I < 9 then Hot := (Ip = 103)
    else Hot := (Ip = 109);
    if Hot then Cell(ChsX + I * CellW, ChsY, HexB(T[I]), $0100 + I, 1)
           else Cell(ChsX + I * CellW, ChsY, HexB(T[I]), $0100 + I, 0);
  end;
  Brace(ChsX, ChsY, 0, 3, 'call Patch (3)');
  Brace(ChsX, ChsY, 3, 6, 'mov word [0111h],' + HexW(PImm) + 'h (6)');
  Brace(ChsX, ChsY, 9, 3, 'call Patch (3)');
  if Ip = 100 then IpArrow(ChsX + (CellW - 8) div 2, ChsY, 'CS:IP = 0100');
  if Ip = 103 then IpArrow(ChsX + CellW * 3 + (CellW - 8) div 2, ChsY, 'CS:IP = 0103');
  if Ip = 109 then
    IpArrow(ChsX + CellW * 9 + (CellW - 8) div 2, ChsY, 'CS:IP = 0109');
  if TrOn then Traces;

  { the gap - real programs have unused cells too }
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(LightGray);
  OutTextXY(MemX + CellW * 8, MemY + 8, '010C..010F: four');
  OutTextXY(MemX + CellW * 8, MemY + 20, 'cells unused');

  { Patch, further down the same memory }
  B[0] := RegB; B[1] := Lo(Imm); B[2] := Hi(Imm);
  B[3] := $89;  B[4] := Reg2B;   B[5] := $00;
  B[6] := $02;  B[7] := $C3;
  for I := 0 to 7 do begin
    X := 0;
    if PokeReg and ((I < 3) or (I = 4)) then X := 2;  { fresh pokes, YELLOW }
    case Ip of
      0: if I <= 2 then X := 1;
      3: if (I >= 3) and (I <= 6) then X := 1;
      7: if I = 7 then X := 1;
    end;
    Cell(MemX + I * CellW, MemY, HexB(B[I]), $0110 + I, X);
  end;
  Brace(MemX, MemY, 0, 3, 'mov ' + RegName + ',' + HexW(Imm) + 'h (3)');
  Brace(MemX, MemY, 3, 4, 'mov [0200h],' + Reg2Name + ' (4)');
  Brace(MemX, MemY, 7, 1, 'ret (1)');
  if (Ip = 0) or (Ip = 3) or (Ip = 7) then
    IpArrow(MemX + Ip * CellW + (CellW - 8) div 2, MemY,
            'CS:IP = 01' + HexB($10 + Ip));

  Captions;
end;

{ ---- scene 1: the road - a jump's distance is a cell ---------------------- }
procedure DrawRoad;
const RdY = 300;
var X0, XT, I: Integer;
    R: array[0..7] of Byte;
begin
  SetFillStyle(SolidFill, BgCol);
  Bar(0, 0, 639, 479);
  Headline;

  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(White);
  OutTextXY(SrcX, SrcY,      'Road:    jmp  short ?');
  OutTextXY(SrcX, SrcY + 16, 'Day:     mov  bl, 1');
  OutTextXY(SrcX, SrcY + 28, '         jmp  short On');
  OutTextXY(SrcX, SrcY + 44, 'Night:   mov  bl, 2');
  OutTextXY(SrcX, SrcY + 60, 'On:      ...');

  SetColor(White);
  OutTextXY(32, RdY - 108, 'one program, two roads - and the ROAD IS A CELL:');

  R[0] := $EB; R[1] := JDisp;
  R[2] := $B3; R[3] := $01;
  R[4] := $EB; R[5] := $02;
  R[6] := $B3; R[7] := $02;
  for I := 0 to 7 do
    if JHot and (I = 1) then Cell(32 + I * CellW, RdY, HexB(R[I]), $0100 + I, 2)
                        else Cell(32 + I * CellW, RdY, HexB(R[I]), $0100 + I, 0);
  Brace(32, RdY, 0, 2, 'jmp short (2)');
  Brace(32, RdY, 2, 2, 'Day (2)');
  Brace(32, RdY, 4, 2, 'jmp On (2)');
  Brace(32, RdY, 6, 2, 'Night (2)');

  { the arc: from the distance cell to where it lands. The distance
    counts from the NEXT address, 0102 - said on the glass. }
  X0 := 32 + CellW + (CellW - 8) div 2;
  if JDisp = 0 then XT := 32 + CellW * 2 + (CellW - 8) div 2
               else XT := 32 + CellW * 6 + (CellW - 8) div 2;
  SetColor(IpCol);
  Line(X0, RdY - 8, X0, RdY - 56);
  Line(X0, RdY - 56, XT, RdY - 56);
  Line(XT, RdY - 56, XT, RdY - 8);
  Line(XT - 6, RdY - 16, XT, RdY - 8);
  Line(XT + 6, RdY - 16, XT, RdY - 8);
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(CenterText, BottomText);
  OutTextXY((X0 + XT) div 2, RdY - 62,
            'jump = 0102 + ' + HexB(JDisp) + 'h');

  { where the run ended up }
  SetTextJustify(LeftText, TopText);
  SetColor(White);
  Rectangle(DstX - 10, 50, 628, 70);
  if JDisp = 0 then OutTextXY(DstX, 57, 'bl = 01  (Day)')
               else OutTextXY(DstX, 57, 'bl = 02  (Night)');

  Captions;
end;

{ ---- scene 2: the closing card - its own clean frame, not a return --- }
procedure DrawFinal;
begin
  SetFillStyle(SolidFill, BgCol);
  Bar(0, 0, 639, 479);
  Headline;
  SetTextStyle(DefaultFont, HorizDir, 5);
  SetTextJustify(CenterText, CenterText);
  SetColor(ImmCol);
  OutTextXY(320, 200, 'JIT. 8086.');
  SetTextStyle(DefaultFont, HorizDir, 2);
  SetColor(White);
  OutTextXY(320, 260, 'the processor could always do this');
  Captions;
end;

procedure DrawAll;
begin
  case Scene of
    0: DrawMain;
    1: DrawRoad;
    else DrawFinal;
  end;
end;

{ ---- step 6's little film: the write crawls, the cells flash, and only
  then does the arrow move on - a hard cut was too sudden to follow ------- }
procedure AnimWrite;
begin
  Traces;                            { the red lines crawl out... }
  Delay(500);
  Imm := PImm;                       { ...the cells take the bytes... }
  Cell(MemX + CellW,     MemY, HexB(Lo(Imm)), $0111, 1);
  Cell(MemX + CellW * 2, MemY, HexB(Hi(Imm)), $0112, 1);
  Delay(600);
  Ip := 109;                         { ...and only now the arrow moves }
  DrawAll;
end;

{ ---- act 2's pokes, before your eyes: cell by cell, then the redraw
  rewrites the source lines too - the substitution must be SEEN, not
  arrived at (the director, 2026-08-24) --------------------------------- }
procedure AnimPoke;
begin
  Cell(MemX,             MemY, HexB(RegB),    $0110, 2);
  Delay(450);
  Cell(MemX + CellW,     MemY, HexB(Lo(Imm)), $0111, 2);
  Cell(MemX + CellW * 2, MemY, HexB(Hi(Imm)), $0112, 2);
  Delay(450);
  Cell(MemX + CellW * 4, MemY, HexB(Reg2B),   $0114, 2);
  Delay(450);
  DrawAll;
end;

procedure SetStep(N: Integer);
begin
  DoAnim := False;
  DoPoke := False;
  TrOn   := False;
  DstHot := False;
  case N of
    0: begin Imm := $1234; PImm := $5678; RegB := $B8;
             Reg2B := $06;
             AxVal := -1; DstW := -1; Ip := -1; Scene := 0;
             PokeReg := False;
             Cap1 := 'A program is cells of memory.';
             Cap2 := 'Loaded at 0100h, right after the PSP. Note 1234h inside Patch, lying as 34 12.';
       end;
    1: begin Ip := 100;
             Cap1 := 'CS:IP starts at 0100.';
             Cap2 := 'call: push the way home - 0103 - and jump. ax still holds nobody-knows-what.';
       end;
    2: begin Ip := 0;
             Cap1 := 'Inside Patch. Standing on B8: nothing has happened yet.';
             Cap2 := 'B8 is "mov ax, and the next two bytes" - the number rides INSIDE the code.';
       end;
    3: begin Ip := 3; AxVal := $1234;
             Cap1 := 'B8 ran: ax = 1234h. Standing on the write - 89 06.';
             Cap2 := 'The LONG mov on purpose: 89 06 carries a REGISTER FIELD. Nothing written yet.';
       end;
    4: begin Ip := 7; DstW := $1234; DstHot := True;
             Cap1 := 'The write LANDED - swapped: 34 12, low byte first.';
             Cap2 := 'C3: ret pops the way home and returns to 0103.';
       end;
    5: begin Ip := 103;
             Cap1 := 'Home again - and the next instruction CHANGES CODE.';
             Cap2 := 'Standing on it: cells 0111-0112 below still hold 34 12. Watch them.';
       end;
    6: begin DoAnim := True; TrOn := True;   { AnimWrite moves Imm and Ip }
             Cap1 := 'One step - and Patch is DIFFERENT code now.';
             Cap2 := '78 56 landed in cells 0111-0112. No permission asked. Next: the second call.';
       end;
    7: begin Ip := 0;
             Cap1 := 'The second call jumps in - into DIFFERENT code.';
             Cap2 := 'Standing on B8 again - and the call also EMPTIED the prefetch queue (lesson 8).';
       end;
    8: begin Ip := 3; AxVal := $5678;
             Cap1 := 'B8 ran: ax = 5678h - a number nobody ever typed.';
             Cap2 := 'Standing on the write; [0200h] still holds the OLD 34 12.';
       end;
    9: begin Ip := 7; DstW := $5678; DstHot := True;
             Cap1 := 'Landed: 78 56. And ret returns honestly - to 010C this time.';
             Cap2 := 'Same seven cells, a different deed. Nobody retyped anything.';
       end;
   10: begin Ip := -1;
             Cap1 := 'Act two. Watch THREE places below.';
             Cap2 := 'Cells 0110, 0111-0112, and 0114 - DEBUG is about to poke all of them.';
       end;
   11: begin DoPoke := True;   { AnimPoke films these landing }
             RegB := $BB; Imm := $9ABC; Reg2B := $1E;
             PokeReg := True; AxVal := -1;
             Cap1 := 'Poked, before your eyes:  e 0110 BB BC 9A  +  e 0114 1E';
             Cap2 := 'Three bits in the opcode, three in the modrm: mov bx,9ABCh / mov [0200h],bx.';
       end;
   12: begin Ip := 100;
             Cap1 := 'Run it from Start - DEBUG once more:  g =0100';
             Cap2 := 'CS:IP back at 0100, exactly like the first walk - into the poked cells now.';
       end;
   13: begin Ip := 0; PokeReg := False;
             Cap1 := 'Standing on BB: mov bx, and the next two cells.';
             Cap2 := 'bx = ???? still - the rule of the arrow holds for every register.';
       end;
   14: begin Ip := 3; AxVal := $9ABC;
             Cap1 := 'BB ran: bx = 9ABCh. Standing on the write - 89 1E now.';
             Cap2 := 'Three bits in the modrm turned 06 into 1E: this write reads BX.';
       end;
   15: begin Ip := 7; DstW := $9ABC; DstHot := True;
             Cap1 := 'BC 9A landed - THROUGH BX, end to end.';
             Cap2 := 'Two pokes, two register fields, one working subroutine. ax was never touched.';
       end;
   16: begin Ip := 103;
             Cap1 := 'ret came home to 0103 - and there stands the CHANGER.';
             Cap2 := 'Cells 0111-0112 hold BC 9A. It is about to write 5678h over them. Again.';
       end;
   17: begin DoAnim := True; TrOn := True;   { the write, filmed again }
             Cap1 := 'Struck again: mov bx,5678h now.';
             Cap2 := 'It only writes the NUMBER cells - BB stays. The BX poke survives.';
       end;
   18: begin Ip := 0;
             Cap1 := 'The second call jumps in. Standing on BB.';
             Cap2 := 'bx still holds 9ABC from the last pass - BB has not run yet.';
       end;
   19: begin Ip := 3; AxVal := $5678;
             Cap1 := 'BB ran: bx = 5678h. Standing on the write - 89 1E.';
             Cap2 := 'Poked opcode, patched number, one honest machine.';
       end;
   20: begin Ip := 7; DstW := $5678; DstHot := True;
             Cap1 := '78 56 landed - through BX again. ret returns to 010C: done.';
             Cap2 := 'Full circle: the operation, the register, the number - every one a cell.';
       end;
   21: begin Scene := 1; JDisp := 0; JHot := False;
             Cap1 := 'Last door: a jump is an opcode and a DISTANCE CELL.';
             Cap2 := 'EB 00: jump nought forward - the Day road. The run sets bl = 1.';
       end;
   22: begin JDisp := 4; JHot := True;
             Cap1 := 'Poke the distance -  e 0101 04  - and the SAME jump takes the Night road.';
             Cap2 := 'An if whose question was asked ONCE. OWL FLY III picks its video card like this.';
       end;
   23: begin Scene := 2;
             Cap1 := 'Lesson 9 - now for real, in a COM file.';
             Cap2 := 'On the screen, patched live, byte by byte.';
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
    if (EC <> 0) or (S0 < 0) or (S0 > 23) then S0 := 0;
  end;
  Gd := VGA; Gm := VGAHi;
  InitGraph(Gd, Gm, 'D:\BGI');
  if GraphResult <> grOk then begin
    WriteLn('EGAVGA.BGI not found - mount Borland Pascal as D: (MAKEINFO.BAT does).');
    Halt(1);
  end;
  for Step := 0 to 23 do begin
    SetStep(Step);
    if Step < S0 then begin        { fast-forward: the STATE still replays }
      if DoAnim then begin Imm := PImm; Ip := 109; end;
      Continue;
    end;
    if DoPoke then AnimPoke
    else if DoAnim then AnimWrite
    else DrawAll;
    while KeyPressed do Ch := ReadKey;  { taps buffered during a Delay must
                                          not eat the steps that follow }
    Ch := ReadKey;
    WriteLn(LF, 'step=', Step, ' ip=', Ip, ' key=', Ord(Ch));
    if Ch = #27 then Break;
    if Ch = #0 then Ch := ReadKey;
  end;
  Close(LF);
  CloseGraph;
end.
