{ ==========================================================================
  INFOGR.PAS - lesson 13, the notebook again. Squared paper, four pens, and
  every number on every page is the game's own, worked out where you can
  count it.

     D:\BIN\TPC.EXE -B -UD:\UNITS INFOGR.PAS     (see MAKEINFO.BAT)
     INFOGR [n]    start at step n (default: the first)

  WHY IT IS A NOTEBOOK. The first deck for this lesson was slides: blue
  background, captions, arrows. The pilot watched it and ruled otherwise,
  2026-09-17: the squared-paper experience is the right one - people are
  shown a real drawing, with the formula, and real numbers they can work
  out themselves. So it is lesson 12's page again - CELLS, NOT PIXELS, a scale
  written in red at the top of every page, and a worked example on each
  one that a reader can check with a pencil:

      the lattice      camx 32768 + BIAS 8192 = 40960, >> 10 = node 40
      the near plane   P0 (-80,-40) P1 (120,120): t = 80/160, the cut (20,40)
      the divide       (-80 * 220) / (-40) = +440: behind you, drawn in front
      the trap         -200 * 220 / -1 = 44000: does not fit AX. INT 0.
      the glass        (-80,160) -> (400,-80): cut at (0,120), then (240,0)
      the clamp        800 * 220 / 40 = 4400 -> 4000. Substituted, not cut.
      the staircase    1000/88 = 11.4 ms waits to 14.3; 1000/60 waits to 28.6

  Every one of those is the arithmetic in CITY.ASM and ENGINE\ - IMUL then
  IDIV, exact, remainder thrown away - and the page says so where it bites.

  FOUR PENS, ONE MEANING EACH, as lesson 12 taught them:

      pencil   construction: axes, rays, dimensions. What you rub out.
      blue     the objects: edges, points, the code
      green    the glass, the wall in front of the eye, what lands on them
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

{$I PAGES.INC}
{$I PAGES2.INC}

{ ==========================================================================
   THE STEP MACHINE - lesson 12's, unchanged. One key adds the next level;
   only turning the page wipes the sheet. INFOGR n jumps to step n.
   ========================================================================== }
const
  NPAGE = 11;
  P_PRIZE = 1;  P_ROAD = 2;  P_LATT = 3;  P_EDGE = 4;  P_NEAR = 5;
  P_TRAP  = 6;  P_GLASS = 7; P_TWO = 8;   P_CLAMP = 9; P_STAIR = 10;
  P_FINAL = 11;

function MaxLevel(p: Integer): Integer;
begin
  case p of
    P_PRIZE : MaxLevel := 3;
    P_ROAD  : MaxLevel := 2;
    P_LATT  : MaxLevel := 4;
    P_EDGE  : MaxLevel := 2;
    P_NEAR  : MaxLevel := 5;
    P_TRAP  : MaxLevel := 4;
    P_GLASS : MaxLevel := 5;
    P_TWO   : MaxLevel := 3;
    P_CLAMP : MaxLevel := 4;
    P_STAIR : MaxLevel := 4;
  else        MaxLevel := 2;
  end;
end;

procedure DrawPage(p, lv: Integer);
begin
  case p of
    P_PRIZE : PagePrize(lv);
    P_ROAD  : PageRoad(lv);
    P_LATT  : PageLatt(lv);
    P_EDGE  : PageEdge(lv);
    P_NEAR  : PageNear(lv);
    P_TRAP  : PageTrap(lv);
    P_GLASS : PageGlass(lv);
    P_TWO   : PageTwo(lv);
    P_CLAMP : PageClamp(lv);
    P_STAIR : PageStair(lv);
  else        PageFinal(lv);
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
