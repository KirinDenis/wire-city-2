{ ==========================================================================
  INFOGR.PAS - the opening infographic for lesson 13 (clipping a line: the
  near plane, the glass - and the engine the game is built from).

     D:\BIN\TPC.EXE -B -UD:\UNITS INFOGR.PAS     (see MAKEINFO.BAT)

  NOT PART OF THE LESSON - the title sequence the video opens with. It
  carries what the COM cannot say out loud: the thank-you, the ladder that
  led here, the two fences and the thing that is not a fence, and the two
  numbers on the glass.

  THE LADDER IT CLIMBS - the pilot's order, 2026-09-17:
   - thank you, and the prize: from here on it is the game's own engine
   - the road to here: 0F, 10, 11, 12 - and the five files of ENGINE\
   - the lattice: 1024 a node, 65536 a map, one word; a square per height
   - one edge's road: DRAWEDGE3D, five lines, four of them fences
   - the near plane: a point behind the eye has no image; the cut
   - why not just divide: INT 0, and the trap that returns
   - the glass: four bits, three sentences
   - two fences, not one: what cannot be drawn, what need not be
   - CLAMPAX is not a fence: it substitutes. 18.2
   - two engines, one byte: 88 and 60 - and the staircase of the beam
   - the closing card: houses next, then the relief

  ONE COLOUR, ONE MEANING:
     white         the game's code, and the picture as it should be
     yellow        the cut - the point put ON the plane, and what is caught
     cyan          a number: FPS, ticks, 18.2, four thousand
     green         what is cheap, and what the fast engine does
     magenta       the ONE argued thing on the slide
     dark grey     what is thrown away, behind, or not drawn

  TP7 SCARS: a source line dies past 126 characters; a BGI string too wide
  for 640 pixels is refused outright. Cap1 <= 39 chars, Cap2 <= 78.

  Keys: any key = next step, ESC = leave early.
  INFOGR N starts at step N.

  Owlos - legacy software modernization - https://owlos.sk
  ========================================================================== }
program Infogr;
{$R-}
{$Q-}

uses Graph, Crt;

const
  NPAGE  = 10;                       { views 0..10                         }
  BgCol  = Blue;
  CodeC  = White;                    { the game's code                     }
  CutC   = Yellow;                   { the cut, and what is caught         }
  NumC   = LightCyan;                { a number                            }
  CheapC = LightGreen;               { what is cheap                       }
  ArgC   = LightMagenta;             { the ONE argued thing                }
  GoneC  = DarkGray;                 { thrown away, behind, not drawn      }

var
  View  : Integer;
  Cap1, Cap2 : string;
  Step  : Integer;
  Ch    : Char;

{ ---- furniture -------------------------------------------------------- }

procedure Headline;
begin
  SetTextStyle(DefaultFont, HorizDir, 2);
  SetTextJustify(CenterText, TopText);
  SetColor(White);
  OutTextXY(320, 10, 'CLIPPING');
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetColor(LightCyan);
  OutTextXY(320, 36, 'a wall in front of your eye, a frame around the glass - and the game''s engine');
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

procedure Small(x, y, c: Integer; s: string);
begin
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(c);
  OutTextXY(x, y, s);
end;

procedure Big(x, y, c: Integer; s: string);
begin
  SetTextStyle(DefaultFont, HorizDir, 2);
  SetTextJustify(LeftText, TopText);
  SetColor(c);
  OutTextXY(x, y, s);
end;

procedure Mid(x, y, c: Integer; s: string);
begin
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(CenterText, TopText);
  SetColor(c);
  OutTextXY(x, y, s);
end;

procedure Dot(x, y, c: Integer);
var keep: Word;
begin
  keep := GetColor;
  SetFillStyle(SolidFill, c);  SetColor(c);
  PieSlice(x, y, 0, 360, 4);
  SetColor(keep);
end;

procedure Arrow(x1, y1, x2, y2, c: Integer);
var dx, dy: Real; L: Real;
begin
  SetColor(c);
  Line(x1, y1, x2, y2);
  dx := x2 - x1;  dy := y2 - y1;
  L := Sqrt(dx * dx + dy * dy);
  if L < 1 then Exit;
  dx := dx / L;  dy := dy / L;
  Line(x2, y2, Round(x2 - 9 * dx - 4 * dy), Round(y2 - 9 * dy + 4 * dx));
  Line(x2, y2, Round(x2 - 9 * dx + 4 * dy), Round(y2 - 9 * dy - 4 * dx));
end;

procedure Box(x1, y1, x2, y2, c: Integer);
begin
  SetColor(c);
  Rectangle(x1, y1, x2, y2);
end;

{ ---- 0: thank you, and the prize ---------------------------------------- }
procedure VTitle;
begin
  Big(60, 84, White, 'Thank you for your patience.');
  Small(60, 118, LightGray, 'Twelve lessons of toys: a square, an orbit, an arm, a cube, a camera.');
  Small(60, 136, LightGray, 'Every one of them written from nothing, on purpose, so that you would');
  Small(60, 154, LightGray, 'know what every instruction was for.');

  Box(46, 190, 600, 330, ArgC);
  Big(60, 204, ArgC, 'From here on, it is the game.');
  Small(60, 240, White, 'Everything on the screen today is drawn by the files OWL FLY is built');
  Small(60, 258, White, 'from - not a lesson version of them. The same include lines. The same');
  Small(60, 276, White, 'bugs, fixed on the same dates, the reasons still written beside them.');
  Small(60, 304, CheapC, 'You are not being shown an engine. You are being handed one.');

  Small(60, 360, GoneC, 'Still 8086, still integers, still no library. That does not change.');
end;

{ ---- 1: the road to here, and the five files ---------------------------- }
procedure VLadder;
var i, y: Integer;
const
  L  : array[0..4] of string[6] = ('0F', '10', '11', '12', '13');
  T  : array[0..4] of string[40] =
    ('the divide, and INT 0',
     'the camera: one divide',
     'the island: a torus',
     'the notebook, by hand',
     'the engine: five files');
  F  : array[0..4] of string[12] = ('E_8086.INC', 'E_MATH.INC', 'E_TERR.INC', 'E_M3D.INC', 'E_RAST.INC');
  D  : array[0..4] of string[44] =
    ('FASM kept inside the 8086 jump set',
     'RND16 - the draw of lesson 11',
     'DSGEN, HGET - the island, entire',
     'SINQ SETTRIG ROTXZ PROJPT CLAMPAX',
     'OUTCODE CLIPLINE LINE, the faces');
begin
  for i := 0 to 4 do begin
    y := 80 + i * 34;
    if i = 4 then begin
      Box(46, y - 6, 300, y + 22, ArgC);
      Big(60, y, ArgC, L[i]);
      Small(110, y + 6, White, T[i]);
    end
    else begin
      Big(60, y, GoneC, L[i]);
      Small(110, y + 6, LightGray, T[i]);
      Arrow(78, y + 24, 78, y + 32, GoneC);
    end;
  end;
  Box(330, 74, 610, 254, White);
  Small(346, 84, White, 'ENGINE\');
  for i := 0 to 4 do begin
    y := 106 + i * 28;
    Small(346, y, CheapC, F[i]);
    Small(346, y + 12, LightGray, D[i]);
  end;
  Small(60, 270, White, 'And GAMES\WIRECITY\CITY.ASM, line 818: the four routines the lesson');
  Small(60, 288, White, 'carries itself - DRAWEDGE3D, NEARCLIP, CLIPP0, CLIPP1 - copied, not');
  Small(60, 306, White, 'rewritten. Open it and read along.');
  Small(60, 340, ArgC, 'The one edit: two bytes of flag, so a stage can take a fence down.');
end;

{ ---- 2: the lattice ------------------------------------------------------ }
procedure VGrid;
const
  B : array[0..5, 0..5] of Byte =
    ((1, 1, 2, 3, 3, 3), (1, 2, 3, 3, 4, 3), (2, 3, 3, 4, 5, 4),
     (3, 3, 4, 5, 6, 5), (3, 4, 4, 5, 5, 4), (3, 3, 4, 4, 3, 3));
  C : array[1..6] of Byte = (LightBlue, Yellow, LightGreen, Green, LightGray, White);
var i, j, x, y: Integer;
begin
  for j := 0 to 5 do
    for i := 0 to 5 do begin
      x := 60 + i * 44;  y := 78 + j * 44;
      SetColor(C[B[j, i]]);
      Rectangle(x, y, x + 44, y + 44);
    end;
  Dot(60 + 3 * 44 + 18, 78 + 3 * 44 + 30, CutC);
  Small(60 + 3 * 44 + 26, 78 + 3 * 44 + 22, CutC, 'eye');
  Small(60, 352, LightGray, 'sea sand grass woods rock snow');
  Small(60, 368, GoneC, 'the six bands of lesson 11');

  Small(350, 84, White, 'A node every 1024 units.');
  Small(350, 102, White, 'The map is 64 nodes wide.');
  Small(350, 130, NumC, '64 x 1024 = 65536');
  Small(350, 148, White, '...which is exactly one word.');
  Small(350, 166, CheapC, 'So the torus costs nothing:');
  Small(350, 184, CheapC, 'the subtraction wraps by itself.');
  Small(350, 214, White, 'Which node the eye is over:');
  Small(350, 232, CodeC, '  (camx + BIAS) >> 10');
  Small(350, 250, LightGray, 'two then eight - an 8086 shifts');
  Small(350, 268, LightGray, 'by one or by CL, never by ten.');
  Small(350, 298, White, 'Every square: two edges of its');
  Small(350, 316, White, 'own, east and north, coloured');
  Small(350, 334, White, 'by the height at its corner.');
  Small(350, 364, ArgC, 'Flat. Still. The relief is the');
  Small(350, 382, ArgC, 'next lesson: one number a corner.');
end;

{ ---- 3: one edge's road -------------------------------------------------- }
procedure VRoad;
begin
  Small(60, 80, LightGray, 'GAMES\WIRECITY\CITY.ASM, line 818:');
  Big(60, 104, CodeC, 'DRAWEDGE3D:');
  Big(80, 132, ArgC,  'call NEARCLIP');
  Big(80, 156, CodeC, 'jc   .skip');
  Big(80, 180, CodeC, 'call PROJ2');
  Big(80, 204, ArgC,  'call CLIPLINE');
  Big(80, 228, CodeC, 'jc   .skip');
  Big(80, 252, CodeC, 'call LINE');
  Big(60, 276, CodeC, '.skip: ret');

  Arrow(330, 140, 300, 140, ArgC);
  Small(340, 134, White, 'the wall in front of your eye');
  Small(340, 150, LightGray, 'in 3D, before anything is divided');
  Arrow(330, 188, 300, 188, CodeC);
  Small(340, 182, White, 'the divide: lesson 0F, guarded');
  Arrow(330, 212, 300, 212, ArgC);
  Small(340, 206, White, 'the four edges of the glass');
  Small(340, 222, LightGray, 'in TWO dimensions, after the divide');
  Arrow(330, 260, 300, 260, CodeC);
  Small(340, 254, White, 'and only then a pixel is written');

  Small(60, 330, White, 'Five lines. Two of them are fences, and they are not the same fence.');
  Small(60, 348, White, 'The stages take them down one at a time and let you look.');
  Small(60, 380, GoneC, 'A cube could be dropped whole when it misbehaved - lesson 10 did.');
  Small(60, 398, GoneC, 'A lattice cannot. You are standing in the middle of it.');
end;

{ ---- 4: the near plane --------------------------------------------------- }
procedure VNear;
var cx, cy: Integer;
begin
  { a side view: z runs right, the eye at the left, the glass at NEARZ }
  Arrow(60, 300, 600, 300, LightGray);
  Small(590, 306, LightGray, 'z');
  Dot(150, 300, White);
  Small(120, 312, White, 'the eye');
  SetColor(ArgC);
  Line(250, 130, 250, 360);
  Small(258, 132, ArgC, 'z = NEARZ = 40');
  Small(258, 148, ArgC, 'the glass');

  { the edge: from behind the eye to well in front }
  SetColor(GoneC);
  Line(80, 350, 250, 265);          { the part behind: thrown away }
  SetColor(White);
  Line(250, 265, 520, 130);         { the part in front: kept }
  Dot(80, 350, GoneC);
  Small(60, 358, GoneC, 'z0 < 40: no image');
  Dot(520, 130, White);
  Small(500, 110, White, 'z1');
  cx := 250; cy := 265;
  Dot(cx, cy, CutC);
  Small(262, 270, CutC, 'the cut');

  Small(60, 76, White, 'A point behind your eye has no image. Not a wrong one - none.');
  Small(60, 94, White, 'There is no line from it through the eye that meets the glass.');

  Small(330, 190, CodeC, 'CLIPP0:');
  Small(330, 206, CodeC, '  t   = (NEARZ - z0) / (z1 - z0)');
  Small(330, 222, CodeC, '  x0 += (x1 - x0) * t');
  Small(330, 238, CodeC, '  y0 += (y1 - y0) * t');
  Small(330, 254, CutC,  '  z0  = NEARZ   assigned, not computed');

  Small(60, 384, CheapC, 'IMUL word, then IDIV word. A 32-bit product in DX:AX, and a 32-bit');
  Small(60, 402, CheapC, 'dividend back. Exact, nothing rounded in between - no fixed point.');
end;

{ ---- 5: why not just divide ---------------------------------------------- }
procedure VTrap;
begin
  Big(60, 80, ArgC, 'INT 0 is BOTH.');
  Small(60, 112, White, 'Divide by zero fires it. A quotient too big for AX fires it.');
  Small(60, 130, White, 'Take NEARCLIP away and z reaches PROJPT at nought or below.');
  Small(60, 148, White, 'idiv cx.  cx = 0.');

  Box(46, 176, 300, 262, GoneC);
  Small(60, 186, GoneC, 'DOS''s handler:');
  Small(60, 206, GoneC, 'prints a line in text mode,');
  Small(60, 224, GoneC, 'takes the program away.');
  Small(60, 242, GoneC, 'Stage 4 is a black screen.');

  Box(330, 176, 610, 292, CutC);
  Small(346, 186, CutC, 'TRAP0, lesson 0F''s vector, taken:');
  Small(346, 206, CodeC, '  mov  sp,[savesp]  ; to DRAWEDGE3D');
  Small(346, 224, CodeC, '  inc  word [faults]');
  Small(346, 242, CodeC, '  sti               ; INT cleared it');
  Small(346, 260, CodeC, '  ret               ; as if it drew');

  Small(60, 316, White, 'DRAWEDGE3D saves SP as its first instruction. At that moment the top');
  Small(60, 334, White, 'of the stack is the return into GRIDC - so a handler that puts SP');
  Small(60, 352, White, 'back and does a plain RET lands exactly where a finished edge would.');

  SetFillStyle(SolidFill, LightRed);
  Bar(60, 386, 260, 390);
  Small(270, 382, CutC, 'one red pixel per caught fault, along the top');
  Small(60, 404, ArgC, 'Not a wrong picture. A machine that stopped - caught.');
end;

{ ---- 6: the glass -------------------------------------------------------- }
procedure VGlass;
var x, y: Integer;
begin
  Small(60, 62, White, 'OUTCODE: one bit for every wall a point is past. Zero means inside.');
  x := 300; y := 124;
  SetColor(GoneC);
  Line(x - 70, y, x + 210, y);          Line(x - 70, y + 140, x + 210, y + 140);
  Line(x, y - 40, x, y + 180);          Line(x + 140, y - 40, x + 140, y + 180);
  Box(x, y, x + 140, y + 140, White);
  Small(x + 44, y + 64, White, '0000');
  Small(x - 60, y - 30, GoneC, '1001');  Small(x + 54, y - 30, GoneC, '1000');  Small(x + 160, y - 30, GoneC, '1010');
  Small(x - 60, y + 64, GoneC, '0001');                                        Small(x + 160, y + 64, GoneC, '0010');
  Small(x - 60, y + 158, GoneC, '0101'); Small(x + 54, y + 158, GoneC, '0100'); Small(x + 160, y + 158, GoneC, '0110');
  Small(x + 54, y - 44, LightGray, 'top');
  Small(x + 176, y + 50, LightGray, 'right');
  Small(x + 44, y + 172, LightGray, 'bottom');
  Small(x - 66, y + 50, LightGray, 'left');

  { one line, in from the left region, out through the right wall }
  SetColor(GoneC);  Line(x - 66, y + 96, x, y + 78);
  SetColor(White);  Line(x, y + 78, x + 140, y + 41);
  SetColor(GoneC);  Line(x + 140, y + 41, x + 180, y + 30);
  Dot(x, y + 78, CutC);  Dot(x + 140, y + 41, CutC);

  Small(60, 316, CheapC, 'both zero            draw it');
  Small(60, 334, CheapC, 'AND not zero         both past the SAME wall: thrown away, no maths');
  Small(60, 352, CutC,   'otherwise            cut the outside end at the first wall it is past,');
  Small(60, 370, CutC,   '                     and GO ROUND AGAIN - a corner is two walls');
  Small(60, 398, White,  'Cohen and Sutherland. ENGINE\E_RAST.INC, CLIPLINE. Four passes at most.');
end;

{ ---- 7: two fences, not one ---------------------------------------------- }
procedure VTwo;
begin
  Box(46, 76, 310, 250, ArgC);
  Big(60, 88, ArgC, 'NEARCLIP');
  Small(60, 122, White, 'three dimensions');
  Small(60, 140, White, 'BEFORE the divide');
  Small(60, 168, ArgC, 'what CANNOT be drawn.');
  Small(60, 186, LightGray, 'Behind the eye there is no');
  Small(60, 204, LightGray, 'answer, and the machine will');
  Small(60, 222, LightGray, 'hand you one anyway.');

  Box(330, 76, 600, 250, ArgC);
  Big(346, 88, ArgC, 'CLIPLINE');
  Small(346, 122, White, 'two dimensions');
  Small(346, 140, White, 'AFTER the divide');
  Small(346, 168, ArgC, 'what NEED not be.');
  Small(346, 186, LightGray, 'Off the glass is a perfectly');
  Small(346, 204, LightGray, 'good point. It is just not');
  Small(346, 222, LightGray, 'on the screen.');

  Small(60, 274, White, 'Stage 3 takes the first down, keeps the second: the picture is tidy,');
  Small(60, 292, White, 'and the world behind your head is drawn, mirrored, above the horizon.');
  Small(60, 310, ArgC, 'Clipping the symptom is not fixing the cause.');

  Small(60, 344, White, 'Stage 4 takes both. LINE walks every pixel it is given, on the screen');
  Small(60, 362, White, 'or not, and CLAMPAX hands it four thousand:');
  Small(60, 380, NumC,  '  about 7 000 000 pixels a frame. The best part of a minute.');
  Small(60, 398, GoneC, 'Behind a back buffer that is a black screen so it draws on the screen.');
end;

{ ---- 8: CLAMPAX is not a fence ------------------------------------------- }
procedure VClamp;
begin
  Small(60, 80, LightGray, 'ENGINE\E_M3D.INC:');
  Big(60, 100, CodeC, 'CLAMPAX:');
  Small(60, 128, CodeC, '  cmp  ax,4000');
  Small(60, 144, CodeC, '  jle  .a1');
  Small(60, 160, CodeC, '  mov  ax,4000');
  Small(60, 176, CodeC, '  ...and -4000 the same way');

  Big(330, 100, ArgC, 'It does not clip.');
  Big(330, 128, ArgC, 'It SUBSTITUTES.');
  Small(330, 166, White, 'With FOCAL 220 that happens when');
  Small(330, 184, NumC,  '   |x| / z  passes  18.2');
  Small(330, 202, White, 'Past that, PROJPT stops dividing');
  Small(330, 220, White, 'and puts a number in its place.');

  Small(60, 250, White, 'A filled polygon does not mind: the span filler clips it either way.');
  Small(60, 268, ArgC, 'A LINE does. Move one endpoint and the whole segment swings.');

  Box(46, 296, 600, 400, GoneC);
  Small(60, 306, GoneC, 'GAMES\OWLFLY3\SRC\WORLD.INC, at GRID:');
  Small(60, 324, White, '"WHY THE GRID CAME APART, IN ONE NUMBER" - the splash screen, the');
  Small(60, 342, White, 'camera turns, the grid explodes. Nothing to do with machine speed.');
  Small(60, 360, White, 'The first fix did not take: off by nearly double. The comment says');
  Small(60, 378, CutC,  'the REAL cure is clipping the edge against the side planes, in 3D.');
  Small(60, 410, GoneC, 'That sentence is a later lesson. Today you have read the bug it names.');
end;

{ ---- 9: two engines, one byte ------------------------------------------- }
procedure VTwoEng;
var i: Integer;
const
  ST : array[0..3] of string[3] = ('70', '35', '23', '17');
  RT : array[0..3] of string[10] = ('1 retrace', '2 retraces', '3 retraces', '4 retraces');
begin
  Small(60, 76, White, 'The same lattice, the same DOSBox, one byte. F flips it in flight.');
  Big(60, 104, CheapC, 'FAST');
  SetFillStyle(SolidFill, CheapC);  Bar(190, 104, 190 + 88 * 4, 120);
  Big(190 + 88 * 4 + 10, 104, NumC, '88');
  Small(60, 130, CheapC, 'ROTXZ: four IDIV 256 -> the two MOVs of lesson 10.');
  Small(60, 148, CheapC, 'LINE:  a PUTPIXEL and a MUL a pixel -> lesson 8''s Line, patched.');
  Big(60, 180, GoneC, 'CLASSIC');
  SetFillStyle(SolidFill, GoneC);   Bar(190, 180, 190 + 60 * 4, 196);
  Big(190 + 60 * 4 + 10, 180, NumC, '60');
  Small(60, 206, GoneC, 'what the game shipped with. Kept, as ROTXZC and LINEC.');

  Small(60, 230, White, 'And why you will see "70 against 35", not "88 against 60":');
  for i := 0 to 3 do begin
    SetFillStyle(SolidFill, NumC);
    Bar(60 + i * 120, 312 - i * 14, 60 + i * 120 + 100, 316);
    Mid(60 + i * 120 + 50, 320, NumC, ST[i] + ' fps');
    Mid(60 + i * 120 + 50, 312 - i * 14 - 16, GoneC, RT[i]);
  end;
  Small(60, 342, White, 'A frame that waits for the beam is a whole number of retraces: 1/70,');
  Small(60, 360, White, '2/70, 3/70. A staircase. Two engines a millisecond apart can land');
  Small(60, 378, White, 'on different steps and read as double - or on the same one and read');
  Small(60, 396, White, 'as equal. Measure with the wait off. The honest gap is about a third,');
  Small(60, 414, ArgC, 'and on a real 8086 - where IDIV is 150 clocks, not four - it is more.');
end;

{ ---- 10: the closing card ------------------------------------------------ }
procedure VFinal;
begin
  Big(60, 100, White, 'One edge, all the way to a pixel.');
  Small(60, 140, White, 'A wall in front of the eye, in three dimensions, before the divide.');
  Small(60, 158, White, 'A frame around the glass, in two, after it.');
  Small(60, 176, White, 'And a trap under both, counting what would have stopped the machine.');

  Box(46, 210, 600, 330, ArgC);
  Small(60, 222, ArgC, 'NEXT:');
  Small(60, 246, White, '14  houses out of cubes, on this lattice - the painter''s algorithm,');
  Small(60, 264, White, '    and a FACE cut by the near plane: 3, 4 or 5 corners come out.');
  Small(60, 290, White, '15  the relief: every corner lifted to its height, and filled.');
  Small(60, 308, GoneC, '    Both are already in the game. You will read them out of it.');

  Small(60, 360, CheapC, 'Now the source. It includes five files, and none of them is a lesson');
  Small(60, 378, CheapC, 'version of anything.');
end;

procedure DrawAll;
begin
  SetFillStyle(SolidFill, BgCol);
  Bar(0, 0, 639, 479);
  if View <> NPAGE then Headline;
  case View of
     0: VTitle;
     1: VLadder;
     2: VGrid;
     3: VRoad;
     4: VNear;
     5: VTrap;
     6: VGlass;
     7: VTwo;
     8: VClamp;
     9: VTwoEng;
  else  VFinal;
  end;
  Captions;
end;

procedure SetStep(N: Integer);
begin
  View := N;
  case N of
    0: begin
         Cap1 := 'Thank you. Here is the prize.';
         Cap2 := 'From this lesson on, the code on the screen is the code in the game.';
       end;
    1: begin
         Cap1 := 'Five files. The game is built of them.';
         Cap2 := 'ENGINE\ - and four routines copied out of WIRE CITY without a change.';
       end;
    2: begin
         Cap1 := 'A lattice, painted by an island.';
         Cap2 := '1024 a node, 64 nodes a map, 65536 a word: the torus wraps by itself.';
       end;
    3: begin
         Cap1 := 'Five lines. Two of them are fences.';
         Cap2 := 'DRAWEDGE3D: near plane, divide, glass, pixel. And they are not the same fence.';
       end;
    4: begin
         Cap1 := 'Behind your eye there is no image.';
         Cap2 := 'So the edge is cut where it meets the glass: IMUL, IDIV, exact, no fractions.';
       end;
    5: begin
         Cap1 := 'INT 0 is both. So we take it.';
         Cap2 := 'Divide by zero and overflow are one fault. The trap counts it, and returns.';
       end;
    6: begin
         Cap1 := 'Four bits, three sentences.';
         Cap2 := 'Both zero: draw. Both past one wall: throw away. Otherwise cut, and go again.';
       end;
    7: begin
         Cap1 := 'Two fences. The second alone lies.';
         Cap2 := 'Stage 3 is tidy and wrong. Stage 4 is seven million pixels and a minute.';
       end;
    8: begin
         Cap1 := 'CLAMPAX is not a fence.';
         Cap2 := 'It substitutes - and that is why the grid came apart, at 18.2, in the game.';
       end;
    9: begin
         Cap1 := 'Two engines, one byte: 88 and 60.';
         Cap2 := 'And the staircase of the beam, which is why the eye sees 70 against 35.';
       end;
   10: begin
         Cap1 := 'One edge, all the way to a pixel.';
         Cap2 := 'Now the source - five includes, and not one of them a lesson version.';
       end;
  end;
end;

var Gd, Gm, S0, EC: Integer;
    LF: Text;
begin
  Assign(LF, 'INFOGR.LOG');
  Rewrite(LF);
  S0 := 0;
  if ParamCount > 0 then begin
    Val(ParamStr(1), S0, EC);
    if (EC <> 0) or (S0 < 0) or (S0 > NPAGE) then S0 := 0;
  end;
  Gd := VGA; Gm := VGAHi;
  InitGraph(Gd, Gm, 'D:\BGI');
  if GraphResult <> grOk then begin
    WriteLn('EGAVGA.BGI not found - mount Borland Pascal as D: (MAKEINFO.BAT does).');
    Halt(1);
  end;
  for Step := 0 to NPAGE do begin
    SetStep(Step);
    if Step < S0 then Continue;
    DrawAll;
    while KeyPressed do Ch := ReadKey;
    Ch := ReadKey;
    WriteLn(LF, 'step=', Step, ' key=', Ord(Ch));
    if Ch = #27 then Break;
    if Ch = #0 then Ch := ReadKey;
  end;
  Close(LF);
  CloseGraph;
end.
