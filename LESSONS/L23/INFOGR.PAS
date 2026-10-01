{ ==========================================================================
  INFOGR.PAS - lesson 17, the notebook. Squared paper, four pens, and the
  lesson where a town stands on the ground.

     D:\BIN\TPC.EXE -B -UD:\UNITS INFOGR.PAS     (see MAKEINFO.BAT)
     INFOGR [n]    start at step n (default: the first)

  THE FORMAT IS LESSON 12'S: a real drawing, the formula, and real numbers
  the viewer can work out with a pencil. Everything is in CELLS.

  AND NOW THE LETTERS ARE IN THE CELLS TOO - the pilot's note of
  2026-09-30. Every label starts on a cell's left edge and sits in the
  middle of its row: DefaultFont is 8 px a letter, so body text is TWO
  letters to a cell, and a headline is DefaultFont at size 2, 16 px - ONE
  letter to a cell, like writing in a school exercise book. Lab and Big
  take whole cells only; there is no way left to put text between them.

  THE WORKED NUMBERS, and every one of them is what HOUSES.ASM does:

      the scale     64 squares x 1024 = 65536: one word. A house 128, a
                    street 128, four by four to a square.
      the fraction  heading 1: hsin 6, 6 x 11 = 66 -> 66/256 east, 0 in a
                    word. camxf 200 + 100 = 300: keeps 44, CF = 1.
                    -66 is FFBEh: BEh = 190/256, FFh = -1.
      the walls     hrx < a0*64 west, > a1*64 east, hrz the same.
      the order     middles 128 384 640 896, eye 300: 172 84 340 596,
                    farthest end first: 3 2 0 1.
      the hash      (20,37): 1317 -> 1562h, top bits 00, a park.
                    (20,38): 1318 -> 77B7h, built. House 5: F32Bh,
                    top bits 11 = 4 storeys, bits 3..5 of F3h = 110.
      the ground    corners 0 16 32 8, point a=5 b=3: L 24, R 304,
                    1784/256 = 6 (6.97, and SAR keeps the 6).
      the windows   zA 1000, zB 2000, u 1/2: t = 1000/1500 = 2/3.
                    Columns 1 3 5 7 eighths: 32 96 160 224 plain,
                    56 139 196 238 corrected (of 256).
      the edge      HFULL 3072, HMAX 4096: at 3584, half the height.
                    Octagon (3000,2000): 3750 against 3606.
      the night     81 colour bytes: 14 ground + 1 sky + 12 houses, x 3.
      the bill      23 bare, 17 with houses, 14 with windows.

  FOUR PENS, ONE MEANING EACH, as lesson 12 set them:

      pencil   construction: axes, rays, dimensions. What you rub out.
      blue     the objects: the ground, the houses, the numbers, the code
      green    what the engine was already doing for nothing
      red      the ANSWER, ringed - and the margin down the right

  and one wash, GLASS, for windows and nothing else.

  Owlos - legacy software modernization - https://owlos.sk
  ========================================================================== }
program Infogr;

uses Graph, Crt;

const
  CELL  = 16;                  { one square of the paper, in pixels }

  PAPER  = 0;   RULE   = 1;   MARGN  = 2;   PEN    = 3;
  PENCIL = 4;   GREEN  = 5;   REDPEN = 6;   INK    = 7;   GREY = 8;
  GLASS  = 9;                  { windows, and nothing else }
  SKYD   = 10;  SKYN   = 11;  LIT    = 12;  DARKW  = 13;  WALLN = 14;
  DGLASS = 15;                 { the program's 35 and 36 by day }

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
  { THE NEW COLOURS GO TO THEIR REAL DAC ENTRIES. In the sixteen-colour
    mode a colour number is not a DAC number: it goes through the EGA
    palette register first, and the BIOS leaves colours 8 to 15 pointing
    at DAC 56 to 63 (and 6 at 20). SetRGBPalette writes the DAC entry it
    is given - so SetRGBPalette(9, ...) paints an entry nothing shows.
    The first draw of this page came out green, cyan and magenta. }
  SetRGBPalette(GLASS  + 48, 20, 34, 52);
  SetRGBPalette(SKYD   + 48, 32, 46, 60);   { the program's own colours, }
  SetRGBPalette(SKYN   + 48,  1,  2,  9);   {  for the night page: 16 by }
  SetRGBPalette(LIT    + 48, 34, 52, 63);   {  day and by night, 35 lit, }
  SetRGBPalette(DARKW  + 48,  3,  4,  7);   {  36 dark, a wall at night, }
  SetRGBPalette(WALLN  + 48,  6,  6,  8);   {  and 35 and 36 by day      }
  SetRGBPalette(DGLASS + 48, 12, 18, 28);
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

{ ---- writing: whole cells only ------------------------------------------ }
{ two letters to a cell, in the middle of the row }
procedure Lab(u, v: Integer; c: Integer; s: string);
begin
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(c);
  OutTextXY(u * CELL, v * CELL + 4, s);
end;

{ one letter to a cell: the headline }
procedure Big(u, v: Integer; c: Integer; s: string);
begin
  SetTextStyle(DefaultFont, HorizDir, 2);
  SetTextJustify(LeftText, TopText);
  SetColor(c);
  OutTextXY(u * CELL + 1, v * CELL + 1, s);
end;

{ ---- pencil furniture --------------------------------------------------- }
procedure Axis(x1, y1, x2, y2, c: Integer; dotted: Boolean);
begin
  SetColor(c);
  if dotted then SetLineStyle(DottedLn, 0, NormWidth)
            else SetLineStyle(SolidLn, 0, NormWidth);
  Line(x1, y1, x2, y2);
  SetLineStyle(SolidLn, 0, NormWidth);
end;

procedure Dot(x, y, c: Integer);
var keep : Word;
begin
  keep := GetColor;
  SetFillStyle(SolidFill, c);
  SetColor(c);
  PieSlice(x, y, 0, 360, 3);
  SetColor(keep);
end;

procedure Dim(x1, x2, y: Integer);
begin
  SetColor(PENCIL);
  Line(x1, y, x2, y);
  Line(x1, y - 5, x1, y + 5);
  Line(x2, y - 5, x2, y + 5);
end;

procedure DimV(y1, y2, x: Integer);
begin
  SetColor(PENCIL);
  Line(x, y1, x, y2);
  Line(x - 5, y1, x + 5, y1);
  Line(x - 5, y2, x + 5, y2);
end;

procedure Thick(x1, y1, x2, y2, c: Integer);
begin
  SetColor(c);
  SetLineStyle(SolidLn, 0, ThickWidth);
  Line(x1, y1, x2, y2);
  SetLineStyle(SolidLn, 0, NormWidth);
end;

procedure Dashed(x1, y1, x2, y2, c: Integer);
begin
  SetColor(c);
  SetLineStyle(DashedLn, 0, NormWidth);
  Line(x1, y1, x2, y2);
  SetLineStyle(SolidLn, 0, NormWidth);
end;

{ the answer, ringed in red: round w cells of text starting at cell u, row v }
procedure Ring(u, v, w: Integer);
begin
  SetColor(REDPEN);
  Ellipse(u * CELL + w * CELL div 2, v * CELL + 8, 0, 360,
          w * CELL div 2 + 6, 11);
end;

{ a box, in cells }
procedure Box(u1, v1, u2, v2: Real; c: Integer);
begin
  SetColor(c);
  Rectangle(CX(u1), CY(v1), CX(u2), CY(v2));
end;

{ a filled box, in cells, with its outline }
procedure FBox(u1, v1, u2, v2: Real; fill, edge: Integer);
begin
  SetFillStyle(SolidFill, fill);
  Bar(CX(u1), CY(v1), CX(u2), CY(v2));
  SetColor(edge);
  Rectangle(CX(u1), CY(v1), CX(u2), CY(v2));
end;

{ a filled four-sided shape, in cells }
procedure FillQuad(x1, y1, x2, y2, x3, y3, x4, y4: Real; fill, edge: Integer);
var p : array[1..5] of PointType;
begin
  p[1].X := CX(x1); p[1].Y := CY(y1);
  p[2].X := CX(x2); p[2].Y := CY(y2);
  p[3].X := CX(x3); p[3].Y := CY(y3);
  p[4].X := CX(x4); p[4].Y := CY(y4);
  p[5] := p[1];
  SetFillStyle(SolidFill, fill);
  SetColor(fill);
  FillPoly(4, p);
  SetColor(edge);
  DrawPoly(5, p);
end;

{$I PAGES.INC}
{$I PAGES2.INC}

{ ==========================================================================
   THE STEP MACHINE - lesson 12's, unchanged. One key adds the next level;
   only turning the page wipes the sheet. INFOGR n jumps to step n.
   ========================================================================== }
const
  NPAGE = 10;
  P_SCALE = 1;  P_HOUSE = 2;  P_FRAC  = 3;  P_WALLS = 4;  P_ORDER = 5;
  P_HASH  = 6;  P_GROUND = 7; P_WIN   = 8;  P_EDGE  = 9;  P_NIGHT = 10;

function MaxLevel(p: Integer): Integer;
begin
  case p of
    P_WIN   : MaxLevel := 4;
  else        MaxLevel := 3;
  end;
end;

procedure DrawPage(p, lv: Integer);
begin
  case p of
    P_SCALE  : PageScale(lv);
    P_HOUSE  : PageHouse(lv);
    P_FRAC   : PageFrac(lv);
    P_WALLS  : PageWalls(lv);
    P_ORDER  : PageOrder(lv);
    P_HASH   : PageHash(lv);
    P_GROUND : PageGround(lv);
    P_WIN    : PageWin(lv);
    P_EDGE   : PageEdge(lv);
  else         PageNight(lv);
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
