{ ==========================================================================
  INFOGR.PAS - lesson 12, the notebook. Squared paper, a pencil and a pen,
  and not one line of assembler in the whole lecture.

     D:\BIN\TPC.EXE -B -UD:\UNITS INFOGR.PAS     (see MAKEINFO.BAT)
     INFOGR [n]    draw the page up to level n (default: all of it)

  EVERY LENGTH IN THIS FILE IS IN CELLS, NOT PIXELS - that is the whole
  point of CX and CY below, and it is not tidiness. The pilot caught the
  first four drafts drawing with correct SPACING but arbitrary ORIGINS: the
  lines ran parallel to the squares and a whole number of squares apart, and
  not one of them landed ON a square. You cannot count a drawing like that,
  and counting is the only reason to use squared paper at all.

  Writing CX(12) instead of 192 makes the fault unwritable. A corner off the
  grid would have to be typed as CX(12.37), and nobody types that.

  THE SCALE, and it is on the page so the reader has it too:

      1 cell = 40 pixels          screen 320 x 200 = 8 x 5 cells
      d = 6 cells = 240           cube 4 cells = 160, at z = 8 .. 12

  Those numbers were chosen so the arithmetic comes out whole: the front
  corners project to 1.5 cells and the back ones to exactly 1, and the
  worked vertex lands on (100, 40) with nothing left over. On paper a
  result that is nearly right teaches the student that he made a mistake.

  FOUR PENS, ONE MEANING EACH - the notebook version of the course's law:

      pencil   construction: rays, axes, dimensions. The stuff you rub out.
      blue     the objects themselves
      green    the glass, and whatever lands on it
      red      the ANSWER, circled - and the margin rule down the right

  THE PAGE GROWS A STROKE AT A TIME. A step of the deck adds lines to what
  is already there and does NOT clear the sheet; only turning the page
  clears it. That is what lets the narrator draw along with the student
  instead of flashing a finished diagram at him.

  Owlos - legacy software modernization - https://owlos.sk
  ========================================================================== }
program Infogr;

uses Graph, Crt;

const
  CELL  = 16;                  { one square of the paper, in pixels }

  { our own palette - SetRGBPalette was measured working under VGAHi, see
    PROBE.PAS. Without it the sixteen EGA colours have no paper and no
    pale blue rule, and the page looks like a diagram instead of a page. }
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
{ DefaultFont is exactly 8 pixels a character, and a cell is 16 - so two
  characters fill one square and the writing sits on the paper instead of
  floating over it. Measured in PROBE.LOG; the stroke fonts are half again
  as wide and are kept for headlines. }
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

{ A dot that LEAVES THE PEN WHERE IT FOUND IT. The first version set the
  colour and walked away, so the second vector on the circle page came out
  in the colour of the dot before it - one blue ray and seven red ones.
  A helper that changes state the caller did not ask about is a trap. }
procedure Dot(x, y, c: Integer);
var keep : Word;
begin
  keep := GetColor;
  SetFillStyle(SolidFill, c);
  SetColor(c);
  PieSlice(x, y, 0, 360, 3);
  SetColor(keep);
end;

{ a dimension line with a tick at each end, the draughtsman's way }
procedure Dim(x1, x2, y: Integer);
begin
  SetColor(PENCIL);
  Line(x1, y, x2, y);
  Line(x1, y - 5, x1, y + 5);
  Line(x2, y - 5, x2, y + 5);
end;


{$I PAGES.INC}
{$I PAGES2.INC}
{$I PAGES3.INC}
{$I PAGES4.INC}
{ ==========================================================================
   PAGE 1 - the camera, the glass and the cube, in three views.

   The plan hands you sx and the side hands you sy: that is why both are
   here and why they share one z axis, with construction lines dropped
   between them. Everything is in cells, so the reader counts.
   ========================================================================== }
procedure PageViews(upto: Integer);
var i : Integer;
begin
  { ---- 1. the headline and the scale ---- }
  Head(0.9, 0.7, INK, 'three views of one cube');
  Lab(0.9, 2.3, REDPEN,
      '1 cell = 40 pixels.  every corner on a crossing - so you count.');
  if upto < 2 then Exit;

  { ---- 2. the PLAN: eye at 4 cells across, 9 down ---- }
  Lab(0.9, 3.5, GREY, 'PLAN - from above.  z right, x down');
  Axis(CX(4), CY(9), CX(18.5), CY(9), PENCIL, True);
  SetColor(PENCIL); ArrowR(CX(19), CY(9));
  Lab(19.3, 8.6, PENCIL, 'z');
  SetColor(PEN);
  Line(CX(4), CY(9), CX(4), CY(12));
  ArrowD(CX(4), CY(12.5));
  Lab(2.9, 11.4, PEN, 'x');
  Dot(CX(4), CY(9), PEN);
  Lab(0.9, 8.6, INK, 'eye');

  SetColor(PENCIL);                       { the four rays }
  Line(CX(4), CY(9), CX(12), CY(7));
  Line(CX(4), CY(9), CX(12), CY(11));
  Line(CX(4), CY(9), CX(16), CY(7));
  Line(CX(4), CY(9), CX(16), CY(11));

  SetColor(GREEN);                        { the glass, edge on: 8 cells }
  SetLineStyle(SolidLn, 0, ThickWidth);
  Line(CX(10), CY(5), CX(10), CY(13));
  SetLineStyle(SolidLn, 0, NormWidth);
  Line(CX(9.6), CY(5), CX(10.4), CY(5));
  Line(CX(9.6), CY(13), CX(10.4), CY(13));
  Dot(CX(10), CY(7.5), GREEN);  Dot(CX(10), CY(10.5), GREEN);
  Dot(CX(10), CY(8), GREEN);    Dot(CX(10), CY(10), GREEN);
  Lab(10.3, 4.4, GREEN, '320 px wide = 8 cells');

  SetColor(PEN);                          { the cube, 4 cells }
  Rectangle(CX(12), CY(7), CX(16), CY(11));
  if upto < 3 then Exit;

  { ---- 3. the shared z, dimensioned once for both views ---- }
  SetColor(PENCIL);
  SetLineStyle(DottedLn, 0, NormWidth);
  Line(CX(10), CY(13), CX(10), CY(16.5));
  Line(CX(12), CY(11), CX(12), CY(17));
  Line(CX(16), CY(11), CX(16), CY(17));
  SetLineStyle(SolidLn, 0, NormWidth);
  Dim(CX(4), CX(10), CY(14));   Lab(10.3, 13.6, INK, 'd = 6 cells = 240');
  Dim(CX(4), CX(12), CY(15));   Lab(12.3, 14.6, INK, 'z = 8 cells = 320');
  Dim(CX(4), CX(16), CY(16));   Lab(16.3, 15.6, INK, 'z = 12 cells = 480');
  if upto < 4 then Exit;

  { ---- 4. the SIDE: same z, y down the page ---- }
  Axis(CX(4), CY(19), CX(18.5), CY(19), PENCIL, True);
  SetColor(PENCIL); ArrowR(CX(19), CY(19));
  Lab(19.3, 18.6, PENCIL, 'z');
  SetColor(PEN);
  Line(CX(4), CY(19), CX(4), CY(21.5));
  ArrowD(CX(4), CY(22));
  Lab(2.9, 21, PEN, 'y');
  Dot(CX(4), CY(19), PEN);
  Lab(0.9, 18.6, INK, 'eye');

  SetColor(PENCIL);
  Line(CX(4), CY(19), CX(12), CY(17));
  Line(CX(4), CY(19), CX(12), CY(21));
  Line(CX(4), CY(19), CX(16), CY(17));
  Line(CX(4), CY(19), CX(16), CY(21));

  SetColor(GREEN);
  SetLineStyle(SolidLn, 0, ThickWidth);
  Line(CX(10), CY(16.5), CX(10), CY(21.5));
  SetLineStyle(SolidLn, 0, NormWidth);
  Line(CX(9.6), CY(16.5), CX(10.4), CY(16.5));
  Line(CX(9.6), CY(21.5), CX(10.4), CY(21.5));
  Dot(CX(10), CY(17.5), GREEN);  Dot(CX(10), CY(20.5), GREEN);
  Dot(CX(10), CY(18), GREEN);    Dot(CX(10), CY(20), GREEN);

  SetColor(PEN);
  Rectangle(CX(12), CY(17), CX(16), CY(21));

  SetColor(PENCIL);                       { the captions live to the RIGHT }
  Line(CX(18.7), CY(17.5), CX(19.8), CY(17));
  Lab(20, 16.8, GREY,  'SIDE - from the left');
  Lab(20, 17.8, GREY,  'z right, y down the page');
  Lab(20, 19,   GREEN, 'the glass: 200 px = 5 cells');
  Lab(20, 20,   PEN,   'the cube: 4 cells, z = 8..12');
  Lab(20, 21,   INK,   'this view hands you sy');
  if upto < 5 then Exit;

  { ---- 5. the screen itself: 8 x 5 cells, origin at 25 across, 23 down ---- }
  Lab(25.5, 22.2, GREEN, 'and this is the screen');
  SetColor(GREEN);
  Rectangle(CX(25), CY(23), CX(33), CY(28));
  SetColor(PEN);
  Rectangle(CX(27.5), CY(24), CX(30.5), CY(27));
  SetLineStyle(DashedLn, 0, NormWidth);
  Rectangle(CX(28), CY(24.5), CX(30), CY(26.5));
  SetLineStyle(SolidLn, 0, NormWidth);
  Line(CX(27.5), CY(24), CX(28), CY(24.5));
  Line(CX(30.5), CY(24), CX(30), CY(24.5));
  Line(CX(30.5), CY(27), CX(30), CY(26.5));
  Line(CX(27.5), CY(27), CX(28), CY(26.5));
  Dot(CX(27.5), CY(24), REDPEN);
  Lab(26.4, 23.4, REDPEN, 'A''');
  Lab(23.2, 22.2, GREY, '0,0');
  Lab(26.4, 28.3, GREY, '320 px = 8 cells');
  Lab(33.3, 25.3, GREY, '200');
  SetColor(PENCIL);
  Line(CX(28.7), CY(25.5), CX(29.3), CY(25.5));
  Line(CX(29), CY(25.2), CX(29), CY(25.8));
  if upto < 6 then Exit;

  { ---- 6. the worked vertex. The answer is the culmination of the page. ---- }
  SetColor(PENCIL);
  Line(CX(0.9), CY(23), CX(18.5), CY(23));
  Lab(0.9, 23.4, INK, 'sx = 160 + x * d / z');
  Lab(12, 23.4, INK, 'sy = 100 + y * d / z');
  Lab(0.9, 25,   INK, 'A = ( -80, -80, 320 )    d = 240');
  Lab(0.9, 26,   INK, 'sx = 160 + ( -80 * 240 / 320 ) = 100');
  Lab(0.9, 27,   INK, 'sy = 100 + ( -80 * 240 / 320 ) =  40');
  Lab(0.9, 28.3, REDPEN, 'A'' = ( 100, 40 )');
  SetColor(REDPEN);
  Ellipse(CX(4.2), CY(28.5), 0, 360, CX(3.5), CY(0.55));
  Lab(8.6, 28.3, GREY, '- plan gives sx, side gives sy');
  if upto < 7 then Exit;

  { ---- 7. how it really sits. THE ONLY FIGURE ON THE PAGE WITH NO SCALE,
       and it says so: it answers "where is everything" and nothing else.
       Written in pixels rather than cells for exactly that reason - there
       is nothing here to count. Depth is foreshortened to 0.8 of width,
       or the cube reads as a long box. ---- }
  Lab(21.5, 3.3, GREY, 'how it really sits, no scale');
  SetColor(PENCIL);
  Line(400, 160, 443,  96);  Line(400, 160, 491,  96);
  Line(400, 160, 491, 144);  Line(400, 160, 443, 144);

  SetColor(PEN);                          { the cube }
  Rectangle(443, 96, 491, 144);
  Line(477, 76, 525, 76);  Line(525, 76, 525, 124);
  Line(443,  96, 477,  76);
  Line(491,  96, 525,  76);
  Line(491, 144, 525, 124);
  SetLineStyle(DashedLn, 0, NormWidth);   { the corner hidden behind it }
  Line(477, 124, 477, 76);
  Line(477, 124, 525, 124);
  Line(477, 124, 443, 144);
  SetLineStyle(SolidLn, 0, NormWidth);

  SetColor(GREEN);                        { the glass, seen at an angle }
  Rectangle(412, 111, 472, 159);
  SetColor(PEN);                          { ...with the image already on it }
  Rectangle(427, 120, 457, 150);
  SetLineStyle(DashedLn, 0, NormWidth);
  Rectangle(432, 125, 452, 145);
  SetLineStyle(SolidLn, 0, NormWidth);

  SetColor(PEN);                          { the camera: NEAR face drawn last }
  Rectangle(378, 148, 414, 177);
  Line(378, 148, 365, 156);
  Line(414, 148, 401, 156);
  Line(414, 177, 401, 184);
  SetFillStyle(SolidFill, PAPER);
  Bar(366, 157, 400, 183);
  Rectangle(365, 156, 401, 184);
  SetFillStyle(SolidFill, PAPER);
  PieSlice(400, 160, 0, 360, 5);
  SetColor(PEN);
  Circle(400, 160, 5);
  Dot(400, 160, PEN);

  SetColor(GREEN);  Line(396, 104, 412, 116);
  Lab(20.7, 6.1, GREEN, 'glass');
  SetColor(PENCIL); Line(480, 168, 458, 152);
  Lab(30.2, 10.6, INK, 'the image');
  Lab(21.5, 12.2, INK, 'camera');
end;


{ ==========================================================================
   THE STEP MACHINE.

   A page is not one picture, it is a SEQUENCE of strokes. One key adds the
   next stroke to what is already on the paper; only turning the page wipes
   it. That is what lets the narrator draw along with the student instead
   of flashing a finished diagram at him.

   The page procedures are CUMULATIVE - Page(4) draws levels one to four -
   and the machine simply never clears between levels. Redrawing the same
   line in the same colour changes no pixel, so there is no flicker and the
   sheet grows. It also means one procedure serves both the take and
   INFOGR n, which jumps straight to a level for a flashback.
   ========================================================================== }
const
  NPAGE = 13;
  P_PENS = 1;  P_TRI = 2;  P_TAB = 3;  P_YDOWN = 4;
  P_VEC  = 5;  P_CIRC = 6;  P_SQ  = 7;  P_MAT1 = 8;
  P_MAT2 = 9;  P_CUBE3 = 10;  P_PERSP = 11;  P_VIEWS = 12;  P_ALL = 13;

function MaxLevel(p: Integer): Integer;
begin
  case p of
    P_PENS  : MaxLevel := 3;
    P_TRI   : MaxLevel := 5;
    P_TAB   : MaxLevel := 5;
    P_YDOWN : MaxLevel := 5;
    P_VEC   : MaxLevel := 5;
    P_CIRC  : MaxLevel := 5;
    P_SQ    : MaxLevel := 5;
    P_MAT1  : MaxLevel := 5;
    P_MAT2  : MaxLevel := 5;
    P_CUBE3 : MaxLevel := 5;
    P_PERSP : MaxLevel := 5;
    P_ALL   : MaxLevel := 5;
  else        MaxLevel := 7;
  end;
end;

procedure DrawPage(p, lv: Integer);
begin
  case p of
    P_PENS  : PagePens(lv);
    P_TRI   : PageTri(lv);
    P_TAB   : PageTab(lv);
    P_YDOWN : PageYDown(lv);
    P_VEC   : PageVec(lv);
    P_CIRC  : PageCirc(lv);
    P_SQ    : PageSq(lv);
    P_MAT1  : PageMat1(lv);
    P_MAT2  : PageMat2(lv);
    P_CUBE3 : PageCube3(lv);
    P_PERSP : PagePersp(lv);
    P_ALL   : PageAll(lv);
  else        PageViews(lv);
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
