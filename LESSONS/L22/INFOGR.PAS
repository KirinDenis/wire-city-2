{ ==========================================================================
  INFOGR.PAS - lesson 16, the notebook. Squared paper, four pens, and the
  lesson where the ground becomes something you can hit.

     D:\BIN\TPC.EXE -B -UD:\UNITS INFOGR.PAS     (see MAKEINFO.BAT)
     INFOGR [n]    start at step n (default: the first)

  THE FORMAT IS LESSON 12'S, kept by the pilot's ruling of 2026-09-17: a
  real drawing, the formula, and real numbers the viewer can work out with
  a pencil. Everything is in CELLS, not pixels.

  THE WORKED NUMBERS, and every one of them is what FILL.ASM does:

      the painter   lesson 15 walked TORD from 0 upwards; this one walks it
                    from the end downwards. One DEC for one INC.
      the scanline  a quad with corners (2,4) (12,4) (16,12) (6,12). Row 8:
                    left edge 2 + 4*4/8 = 4, right edge 12 + 4*4/8 = 14.
                    Fill 4 to 14. One IMUL and one IDIV per edge per row.
      the colour    four corners 128 141 176 150: the tallest is 176, woods,
                    colour 4. Its fold is 4 + 8 = 12. Grass 3 folds to 11.
      the waves     WORLDH's second instruction is MOV BX,5. A byte kept in
                    BL across it comes back as 5 for every node at or above
                    88, and 5 is "sea". Below 88 WORLDH returns first and BL
                    survives - so only the LAND was wrong.
      the crash     clearance 96. The camera steps back 400: the game's 100
                    on a 256 cell, times four for a 1024 node.
      the spawn     map byte 130 is (130-88)*5 = 210, doubled 420, plus 96
                    is 516 - above lesson 15's start of 500. Now: the
                    tallest byte on the island, through WORLDH, doubled,
                    plus 700. For 255 that is 2220 + 700 = 2920.
      the bill      38 x 625 = 23750 and 12 x 2401 = 28812: the cost is the
                    NUMBER OF SQUARES. Twice the reach, four times the bill.
      the circle    24 nodes x 1024 = 24576 along an axis. At 45 degrees the
                    corner is 24576 x 1.414 = 34756, and a signed word stops
                    at 32767: it reads -30780. The circle: 1793 of 2401
                    squares, farthest node 25844.
      the three     outcodes: 3 bits a node, a square culled by an AND of 4.
                    Edges: owned by the square painted LATER; neighbours'
                    squared distances differ by 2d+1, which is odd, so
                    never a tie. PITCH4: check E8, write 90 90 90.
      the chain     measured, 24 nodes: 19 22 23 26 27. At 12 nodes: 76,
                    which is lesson 15's bare wireframe.

  FOUR PENS, ONE MEANING EACH, as lesson 12 set them:

      pencil   construction: axes, rays, dimensions. What you rub out.
      blue     the objects: the ground, the numbers, the code
      green    what the engine was already doing for nothing
      red      the ANSWER, circled - and the margin down the right

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
  NPAGE = 10;
  P_PAINT = 1;  P_FACE  = 2;  P_FOLD  = 3;  P_WAVES = 4;  P_CRASH = 5;
  P_SPAWN = 6;  P_BILL  = 7;  P_CIRC  = 8;  P_THREE = 9;  P_FINAL = 10;

function MaxLevel(p: Integer): Integer;
begin
  case p of
    P_PAINT : MaxLevel := 3;
    P_FACE  : MaxLevel := 3;
    P_FOLD  : MaxLevel := 4;
    P_WAVES : MaxLevel := 3;
    P_CRASH : MaxLevel := 3;
    P_SPAWN : MaxLevel := 3;
    P_BILL  : MaxLevel := 4;
    P_CIRC  : MaxLevel := 4;
    P_THREE : MaxLevel := 4;
  else        MaxLevel := 3;
  end;
end;

procedure DrawPage(p, lv: Integer);
begin
  case p of
    P_PAINT : PagePaint(lv);
    P_FACE  : PageFace(lv);
    P_FOLD  : PageFold(lv);
    P_WAVES : PageWaves(lv);
    P_CRASH : PageCrash(lv);
    P_SPAWN : PageSpawn(lv);
    P_BILL  : PageBill(lv);
    P_CIRC  : PageCirc(lv);
    P_THREE : PageThree(lv);
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
