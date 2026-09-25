{ ==========================================================================
  INFOGR.PAS - lesson 15, the notebook. Squared paper, four pens, and the
  first lesson in which the picture has to know what is in front of what.

     D:\BIN\TPC.EXE -B -UD:\UNITS INFOGR.PAS     (see MAKEINFO.BAT)
     INFOGR [n]    start at step n (default: the first)

  THE FORMAT IS LESSON 12'S, kept by the pilot's ruling of 2026-09-17: a
  real drawing, the formula, and real numbers the viewer can work out with
  a pencil. Everything is in CELLS, not pixels - that is what CX and CY
  are for, and it is what puts a corner ON a crossing where it can be
  counted instead of measured.

  THE WORKED NUMBERS, and every one of them is what the program does:

      the height   WORLDH: (H-88)*5, and doubled again above 560.
                   H=120 -> 160.  H=200 -> 560.  H=255 -> 1110.
                   Below 88 it is 0 - that is the sea, and it is flat.
      the scale    a node is 1024 units apart and a hill is 1110 tall.
                   THAT is why it looked flat. VEXAG doubles the height
                   and nothing else, and it is the only number in the
                   program that is not the game's.
      once a node  625 squares x 2 edges x 2 ends = 2500 rotations a
                   frame. 26 x 26 nodes = 676. The cache is 3.7 times
                   less work for the same picture.
      the order    squared distance, (ta-12)^2 + (tb-12)^2, because 3 and
                   4 give 9+16=25 and 5 squared is 25: comparing squares
                   orders the same as comparing distances, and costs no
                   square root.
      the skyline  320 bytes, one a column, all 200 to start. Column 160
                   in turn: 138 draws, 151 hidden, 122 draws, 130 hidden.
      the cost     measured: see through with lesson 8's line 76 frames,
                   HIDDEN 60, see through with the classic line 53. The
                   hiding is FASTER than a plain line. The 16 frames went
                   on leaving lesson 8's line behind.
      the Z-buffer 64000 pixels, a word of depth each, is 128000 bytes.
                   A segment holds 65536. That is the end of it.

  FOUR PENS, ONE MEANING EACH, as lesson 12 set them:

      pencil   construction: axes, rays, dimensions. What you rub out.
      blue     the objects: the ground, the numbers, the code
      green    what the engine was already doing for nothing
      red      the ANSWER, circled - and the margin down the right

  THE PAGE GROWS A STROKE AT A TIME. A key adds the next level to what is
  already there; only turning the page wipes it. The page procedures are
  cumulative - Page(4) draws levels one to four.

  TP7 SCARS: a source line dies past 126 characters. DefaultFont is 8 px a
  character and a cell is 16, so a label from cell 0.9 holds 70 characters
  before the margin, and one from cell 20.6 holds 30.

  Owlos - legacy software modernization - https://owlos.sk
  ========================================================================== }
program Infogr;

uses Graph, Crt;

const
  CELL  = 16;                  { one square of the paper, in pixels }

  PAPER  = 0;   RULE   = 1;   MARGN  = 2;   PEN    = 3;
  PENCIL = 4;   GREEN  = 5;   REDPEN = 6;   INK    = 7;   GREY = 8;

var
  Ch : Char;
  Gd, Gm, EC : Integer;

{ ---- cells, not pixels ------------------------------------------------- }
function CX(c: Real): Integer;
begin CX := Round(c * CELL); end;

function CY(c: Real): Integer;
begin CY := Round(c * CELL); end;

{ ---- the sheet --------------------------------------------------------- }
procedure Palette;
begin
  SetRGBPalette(PAPER,  63, 62, 58);
  SetRGBPalette(RULE,   46, 51, 58);
  SetRGBPalette(MARGN,  56, 21, 18);
  SetRGBPalette(PEN,     6, 15, 34);
  SetRGBPalette(PENCIL, 34, 34, 34);
  SetRGBPalette(GREEN,   7, 30, 17);
  SetRGBPalette(REDPEN, 50, 13, 10);
  SetRGBPalette(INK,    10, 11, 13);
  SetRGBPalette(GREY,   24, 26, 30);
end;

procedure Sheet;
var i : Integer;
begin
  SetFillStyle(SolidFill, PAPER);
  Bar(0, 0, GetMaxX, GetMaxY);
  SetColor(RULE);
  i := 0;
  while i <= GetMaxX do begin Line(i, 0, i, GetMaxY); Inc(i, CELL); end;
  i := 0;
  while i <= GetMaxY do begin Line(0, i, GetMaxX, i); Inc(i, CELL); end;
  SetColor(MARGN);                       { the red rule, down the RIGHT }
  Line(CX(36), 0, CX(36), GetMaxY);
end;

{ ---- writing ----------------------------------------------------------- }
procedure Lab(u, v: Real; c: Integer; s: string);
begin
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(c);
  OutTextXY(CX(u), CY(v), s);
end;

procedure Head(u, v: Real; c: Integer; s: string);
begin
  SetTextStyle(TriplexFont, HorizDir, 2);
  SetTextJustify(LeftText, TopText);
  SetColor(c);
  OutTextXY(CX(u), CY(v), s);
end;

{ ---- pencil furniture --------------------------------------------------- }
procedure ArrowR(x, y: Integer);
begin Line(x, y, x - 7, y - 3); Line(x, y, x - 7, y + 3); end;

procedure ArrowL(x, y: Integer);
begin Line(x, y, x + 7, y - 3); Line(x, y, x + 7, y + 3); end;

procedure ArrowU(x, y: Integer);
begin Line(x, y, x - 3, y + 7); Line(x, y, x + 3, y + 7); end;

procedure ArrowD(x, y: Integer);
begin Line(x, y, x - 3, y - 7); Line(x, y, x + 3, y - 7); end;

procedure Axis(x1, y1, x2, y2, c: Integer; dotted: Boolean);
begin
  SetColor(c);
  if dotted then SetLineStyle(DottedLn, 0, NormWidth)
            else SetLineStyle(SolidLn, 0, NormWidth);
  Line(x1, y1, x2, y2);
  SetLineStyle(SolidLn, 0, NormWidth);
end;

{ a dot that leaves the pen where it found it - lesson 12's lesson }
procedure Dot(x, y, c: Integer);
var keep : Word;
begin
  keep := GetColor;
  SetFillStyle(SolidFill, c);
  SetColor(c);
  PieSlice(x, y, 0, 360, 3);
  SetColor(keep);
end;

{ a dimension line with a tick at each end }
procedure Dim(x1, x2, y: Integer);
begin
  SetColor(PENCIL);
  Line(x1, y, x2, y);
  Line(x1, y - 5, x1, y + 5);
  Line(x2, y - 5, x2, y + 5);
end;

{ the same, upright }
procedure DimV(y1, y2, x: Integer);
begin
  SetColor(PENCIL);
  Line(x, y1, x, y2);
  Line(x - 5, y1, x + 5, y1);
  Line(x - 5, y2, x + 5, y2);
end;

{ a thick line in one colour, and the width put back }
procedure Thick(x1, y1, x2, y2, c: Integer);
begin
  SetColor(c);
  SetLineStyle(SolidLn, 0, ThickWidth);
  Line(x1, y1, x2, y2);
  SetLineStyle(SolidLn, 0, NormWidth);
end;

{ a dashed line in one colour, and the style put back }
procedure Dashed(x1, y1, x2, y2, c: Integer);
begin
  SetColor(c);
  SetLineStyle(DashedLn, 0, NormWidth);
  Line(x1, y1, x2, y2);
  SetLineStyle(SolidLn, 0, NormWidth);
end;

{ the answer, ringed in red: an ellipse w cells wide round the text at u,v }
procedure Ring(u, v, w: Real);
begin
  SetColor(REDPEN);
  Ellipse(CX(u + w / 2), CY(v + 0.3), 0, 360, CX(w / 2 + 0.3), CY(0.55));
end;

{ a box, in cells }
procedure Box(u1, v1, u2, v2: Real; c: Integer);
begin
  SetColor(c);
  Rectangle(CX(u1), CY(v1), CX(u2), CY(v2));
end;

{$I PAGES.INC}
{$I PAGES2.INC}

{ ==========================================================================
   THE STEP MACHINE - lesson 12's, unchanged. One key adds the next level;
   only turning the page wipes the sheet. INFOGR n jumps to step n.
   ========================================================================== }
const
  NPAGE = 9;
  P_FLAT = 1;  P_HGT  = 2;  P_GND  = 3;  P_ONCE = 4;  P_THRU = 5;
  P_ORD  = 6;  P_HOR  = 7;  P_COST = 8;  P_FINAL = 9;

function MaxLevel(p: Integer): Integer;
begin
  case p of
    P_FLAT : MaxLevel := 3;
    P_HGT  : MaxLevel := 4;
    P_GND  : MaxLevel := 3;
    P_ONCE : MaxLevel := 4;
    P_THRU : MaxLevel := 3;
    P_ORD  : MaxLevel := 3;
    P_HOR  : MaxLevel := 5;
    P_COST : MaxLevel := 4;
  else       MaxLevel := 3;
  end;
end;

procedure DrawPage(p, lv: Integer);
begin
  case p of
    P_FLAT : PageFlat(lv);
    P_HGT  : PageHgt(lv);
    P_GND  : PageGnd(lv);
    P_ONCE : PageOnce(lv);
    P_THRU : PageThru(lv);
    P_ORD  : PageOrd(lv);
    P_HOR  : PageHor(lv);
    P_COST : PageCost(lv);
  else       PageFinal(lv);
  end;
end;

var
  LF : Text;
  pg, lv, S0, Step : Integer;
begin
  S0 := 0;                      { INFOGR n starts at step n }
  if ParamCount > 0 then
  begin
    Val(ParamStr(1), S0, EC);
    if EC <> 0 then S0 := 0;
  end;

  Assign(LF, 'INFOGR.LOG');
  Rewrite(LF);

  Gd := VGA; Gm := VGAHi;
  InitGraph(Gd, Gm, 'D:\BGI');
  if GraphResult <> grOk then
  begin
    WriteLn('EGAVGA.BGI not found - mount Borland Pascal as D: (MAKEINFO.BAT does).');
    Halt(1);
  end;
  Palette;

  Step := 0;
  for pg := 1 to NPAGE do
  begin
    Sheet;                      { the ONLY place the paper is wiped }
    for lv := 1 to MaxLevel(pg) do
    begin
      Inc(Step);
      DrawPage(pg, lv);
      if Step < S0 then Continue;
      while KeyPressed do Ch := ReadKey;
      Ch := ReadKey;
      WriteLn(LF, 'step=', Step, ' page=', pg, ' level=', lv, ' key=', Ord(Ch));
      if Ch = #27 then
      begin
        Close(LF);
        CloseGraph;
        Halt(0);
      end;
      if Ch = #0 then Ch := ReadKey;
    end;
  end;

  Close(LF);
  CloseGraph;
end.
