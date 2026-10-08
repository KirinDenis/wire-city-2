{ ==========================================================================
  INFOGR.PAS - lesson 19, the notebook. Squared paper, four pens, and the
  lesson where the aeroplane can go round any way it likes.

     MAKEINFO          builds it from Windows, in DOSBox, with Borland Pascal
     INFOGR [n]        start at step n (default: the first)

  THE BGI DRIVER IS INSIDE THE PROGRAM, as in lesson 18: MAKEINFO turns
  EGAVGA.BGI into EGAVGA.OBJ with BINOBJ, the $L directive below puts it in
  the EXE, and RegisterBGIdriver tells the Graph unit it is already here.
  One file, and it runs on any DOS - the course page's included.

  THE FORMAT IS LESSON 12'S: a real drawing, the formula, and real numbers
  the viewer can work out with a pencil. Everything is in CELLS, and the
  letters sit in the cells too: body text two letters to a cell (Lab), a
  headline one (Big).

  THE WORKED NUMBERS, and every one of them is what AXES.ASM does:

      the stick     q up to 16 eighths = 2 steps a tick = 51 degrees a
                    second; a tap is 2 eighths, a third of a degree.
      the bank      roll 64 (90 deg): cos 0, sin 256 - all turn, no climb.
                    roll 32 (45 deg): cos = sin = 181: 16 x 181 / 256 = 11
                    eighths of climb and 11 of turn.
      the eighths   -3: SAR 3 gives -1 step, AND 7 gives 5: -8 + 5 = -3.
      over the top  pitch 65 -> 128 - 65 = 63; heading +128; roll +128.
      the planes    160/220 = 0.73 -> 3/4; 100/220 = 0.45 -> 1/2;
                    banked: sqrt(160^2 + 100^2) = 189, 189/220 = 0.86 -> 7/8.
      the column    128 up: y' + 128 pcos/256 = pcos/2, z' + psin/2.
      the numbers   pitch 18 x 45 / 32 = 25; roll 200 -> CBW -56 ->
                    -56 x 45 = -2520, SAR 5 = -79.
      the bill      18 to 35 frames a second level, 10 to 11 banked over
                    a town (DOSBox, 30000 cycles).

  FOUR PENS, ONE MEANING EACH, as lesson 12 set them:

      pencil   construction: axes, rays, dimensions. What you rub out.
      blue     the objects: the aeroplane, the numbers
      green    what the engine was already doing for nothing
      red      the ANSWER, ringed - and the margin down the right

  Owlos - legacy software modernization - https://owlos.sk
  ========================================================================== }
program Infogr;

uses Graph, Crt;

const
  CELL  = 16;                  { one square of the paper, in pixels }

  PAPER  = 0;   RULE   = 1;   MARGN  = 2;   PEN    = 3;
  PENCIL = 4;   GREEN  = 5;   REDPEN = 6;   INK    = 7;
  SKYW   = 9;                  { a wash of sky, for the wind page }

var
  Ch : Char;
  Gd, Gm, EC : Integer;

{ ---- the driver, linked in - see the top of the file ------------------ }
procedure EgaVgaDriverProc; external;
{$L EGAVGA.OBJ}

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
  { colours 8 to 15 live at DAC 56 to 63 in the sixteen-colour mode - see
    lesson 17's notebook for the day that cost }
  SetRGBPalette(SKYW + 48, 44, 52, 60);
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

{ the aeroplane, side on, nose to the right: about 12 cells long, its
  middle at (x, y) }
procedure Plane(x, y: Real);
begin
  FillQuad(x - 6, y - 0.5, x + 5, y - 0.5, x + 6.5, y, x - 6, y + 0.5, PEN, PEN);
  FillQuad(x - 6, y + 0.5, x + 6.5, y, x + 5, y + 0.5, x - 6, y + 0.5, PEN, PEN);
  FillQuad(x - 1.5, y, x + 1.5, y, x + 0.5, y + 1.2, x - 2.5, y + 1.2, PEN, PEN);
  FillQuad(x - 6, y - 0.5, x - 5, y - 0.5, x - 5.5, y - 2.5, x - 6.5, y - 2.5, PEN, PEN);
end;

{ AN ARROW, in cells, its head at the second end. THE FORCES ARE ARROWS:
  the boldest mark on a page about forces has to be the one that pushes. }
procedure Arrow(x1, y1, x2, y2: Real; c: Integer; bold: Boolean);
var dx, dy, len, ux, uy : Real;
    hx, hy : Real;
begin
  SetColor(c);
  if bold then SetLineStyle(SolidLn, 0, ThickWidth)
          else SetLineStyle(SolidLn, 0, NormWidth);
  Line(CX(x1), CY(y1), CX(x2), CY(y2));
  dx := x2 - x1;  dy := y2 - y1;
  len := Sqrt(dx * dx + dy * dy);
  if len > 0 then
  begin
    ux := dx / len;  uy := dy / len;            { along the arrow }
    hx := x2 - 0.7 * ux;  hy := y2 - 0.7 * uy;   { the head's back }
    Line(CX(x2), CY(y2), CX(hx - 0.35 * uy), CY(hy + 0.35 * ux));
    Line(CX(x2), CY(y2), CX(hx + 0.35 * uy), CY(hy - 0.35 * ux));
  end;
  SetLineStyle(SolidLn, 0, NormWidth);
end;

{$I PAGES.INC}
{$I PAGES2.INC}

{ ==========================================================================
   THE STEP MACHINE - lesson 12's, unchanged. One key adds the next level;
   only turning the page wipes the sheet. INFOGR n jumps to step n.
   ========================================================================== }
const
  NPAGE = 7;
  P_AXES = 1;  P_STICK = 2;  P_EIGHTHS = 3;  P_TOP = 4;
  P_PITCH = 5; P_COLUMN = 6; P_NUMBERS = 7;

function MaxLevel(p: Integer): Integer;
begin
  MaxLevel := 3;
end;

procedure DrawPage(p, lv: Integer);
begin
  case p of
    P_AXES    : PageAxes(lv);
    P_STICK   : PageStick(lv);
    P_EIGHTHS : PageEighths(lv);
    P_TOP     : PageTop(lv);
    P_PITCH   : PagePitch(lv);
    P_COLUMN  : PageColumn(lv);
  else         PageNumbers(lv);
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

  if RegisterBGIdriver(@EgaVgaDriverProc) < 0 then
  begin
    WriteLn('The linked EGAVGA driver was refused - rebuild with MAKEINFO.');
    Halt(1);
  end;
  Gd := VGA; Gm := VGAHi;
  InitGraph(Gd, Gm, '');        { no path: the driver is already here }
  if GraphResult <> grOk then
  begin
    WriteLn('VGA did not start.');
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
