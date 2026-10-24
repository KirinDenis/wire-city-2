{ ==========================================================================
  INFOGR.PAS - lesson 1F, the notebook. Squared paper, four pens, and the
  palette: a pixel is a number, and the colour lives in the DAC.

     MAKEINFO          builds it from Windows, in DOSBox, with Borland Pascal
     INFOGR [n]        start at step n (default: the first)

  THE BGI DRIVER IS INSIDE THE PROGRAM, as in lessons 18 to 1E: MAKEINFO
  turns EGAVGA.BGI into EGAVGA.OBJ with BINOBJ, the $L directive below puts
  it in the EXE, and RegisterBGIdriver tells the Graph unit it is already
  here. One file, and it runs on any DOS - the course page's included.

  THIS NOTEBOOK USES ITS OWN DAC. Colours 8 to 15 of the sixteen are set
  per page to the program's own colours, and on the first page's last step
  one of them is rewritten - and every box drawn in it changes at once,
  with nothing drawn again: the lesson's fact, done on the paper itself.

  THE WORKED NUMBERS, and every one of them is what MANDEL.ASM does:

      c = 0.5       x: 0, 2048, 3072, 4352, 6672, 12916 in 4.12 - 0, 0.5,
                    0.75, 1.06, 1.63, 3.15; at step 6 x*x = 166823056,
                    DX = 2545 >= 1024: away. Colour 6 x 4 = 24, + 1 = 25.
      c = -1        0, -1, 0, -1 ... 128 steps and home: colour 0, black.
      the ramp      entry i of 128: band i/32 of black, deep blue (4,10,44),
                    ice (44,63,63), amber (63,40,0), black; f = i mod 32;
                    a + (b - a) x f / 32. DAC 25 is ramp 24 = (3,7,33).
      the bill      measured on the course page: the picture about 170
                    ticks, a thousand turns about 60 - one turn 3.3 ms.

  FOUR PENS, ONE MEANING EACH, as lesson 12 set them:

      pencil   construction: grids, dimensions. What you rub out.
      blue     the objects: the bytes, the ports, the numbers
      green    what the machine was already doing for nothing
      red      the ANSWER, ringed - and the margin down the right

  Owlos - legacy software modernization - https://owlos.sk
  ========================================================================== }
program Infogr;

uses Graph, Crt;

const
  CELL  = 16;                  { one square of the paper, in pixels }

  PAPER  = 0;   RULE   = 1;   MARGN  = 2;   PEN    = 3;
  PENCIL = 4;   GREEN  = 5;   REDPEN = 6;   INK    = 7;
  SKYD   = 10;                 { the game's colours, for the game's letters: }
  RINGG  = 11;                 {  its sky (16), its ring (48), its ink (49) }
  INKW   = 12;                 {  and its snow (6) }
  SNOWC  = 13;

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
  SetRGBPalette(SKYD  + 48, 32, 46, 60);
  SetRGBPalette(RINGG + 48, 22, 23, 25);
  SetRGBPalette(INKW  + 48, 54, 54, 52);
  SetRGBPalette(SNOWC + 48, 46, 48, 50);
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

{ AN ARROW, in cells, its head at the second end }
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
  NPAGE = 5;
  P_NUMBER = 1;  P_PORTS = 2;  P_SET = 3;  P_HALF = 4;  P_BILL = 5;

function MaxLevel(p: Integer): Integer;
begin
  MaxLevel := 3;
end;

procedure DrawPage(p, lv: Integer);
begin
  case p of
    P_NUMBER : PageNumber(lv);
    P_PORTS  : PagePorts(lv);
    P_SET    : PageSet(lv);
    P_HALF   : PageHalf(lv);
  else        PageBill(lv);
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
