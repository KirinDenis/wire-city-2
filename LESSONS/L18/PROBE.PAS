{ ==========================================================================
  PROBE.PAS - measurements, not opinions. Throwaway: it exists to answer two
  questions before a line of the lesson is drawn, and it is kept afterwards
  only so the answers can be re-checked when the machine changes.

     PROBE        measure and quit, writing PROBE.LOG
     PROBE SHOW   draw the palette test and wait for a key

  QUESTION ONE - WHICH FONT. The lesson is a page of squared paper covered in
  small annotations: "(160,100)", "d = 6 cells = 240". At 640x480 those have
  to be legible AND narrow, and BGI's stroke fonts are neither predictable
  nor documented in a way you can lay out from. So: measure every font the
  machine actually has, at every size, and let the numbers choose.

  SCRI.CHR is in the list on purpose. A notebook is handwriting, and if the
  script font is legible at these sizes it beats a serif for this one lesson.

  QUESTION TWO - CAN WE REPAINT THE PALETTE. Squared paper wants a warm
  white and a pale blue rule; the sixteen EGA colours have neither.
  SetRGBPalette repoints a colour at a DAC entry, and under the VGA driver at
  640x480 it should work - "should" being the reason for this program. There
  is no read-back for the DAC, so this half cannot be settled by measuring:
  PROBE SHOW paints the swatches and a person looks once.

  Owlos - legacy software modernization - https://owlos.sk
  ========================================================================== }
program Probe;

uses Graph, Crt;

const
  FONTNAME : array[0..10] of string[14] =
    ('Default', 'Triplex', 'Small', 'SansSerif', 'Gothic',
     'Script', 'Simplex', 'TriplexScr', 'Complex', 'European', 'Bold');

  { the strings the page really has to fit, longest first }
  SAMPLE : array[0..4] of string[60] =
    ('1 cell = 40 pixels.  screen 320 x 200 = 8 x 5 cells.',
     'the camera, the glass and the cube - three views',
     'sx = 160 + x * d / z',
     'd = 6 cells = 240',
     '(160,100)');

var
  LF   : Text;
  Gd, Gm, EC : Integer;
  f, s, i, w, h : Integer;
  Show : Boolean;

procedure Measure;
begin
  WriteLn(LF, 'font          size   ', SAMPLE[4], '   ', SAMPLE[3],
              '   sx=...   headline   subtitle      height');
  WriteLn(LF, '------------------------------------------------------------------------');
  for f := 0 to 10 do
  begin
    for s := 1 to 4 do
    begin
      SetTextStyle(f, HorizDir, s);
      { GraphResult after SetTextStyle tells you the .CHR was found. A font
        that failed to load silently draws as DefaultFont, and the only way
        to catch that is to compare widths - which is what this table is. }
      EC := GraphResult;
      Write(LF, FONTNAME[f]:12, s:5);
      for i := 4 downto 0 do
      begin
        w := TextWidth(SAMPLE[i]);
        Write(LF, w:9);
      end;
      h := TextHeight('Hg');
      Write(LF, h:8);
      if EC <> grOk then Write(LF, '   <-- GraphResult ', EC);
      WriteLn(LF);
    end;
  end;
  WriteLn(LF);
  WriteLn(LF, 'the page is 640 wide. A caption starting at x=14 may be 560 wide;');
  WriteLn(LF, 'a label inside the drawing may be about 90. Read the columns for');
  WriteLn(LF, 'the two longest samples against those two numbers.');
end;

{ Whether SetRGBPalette REACHED THE HARDWARE, measured rather than admired.
  There is no Graph call that reads a DAC entry back, but the DAC itself will
  tell you: write the entry number to 3C7h, then read 3C9h three times for
  red, green and blue, 0..63 each. Write seven colours, read the same seven,
  and compare. If they come back changed, the paper can be warm white; if
  they come back as the stock EGA values, the lesson uses the stock sixteen
  and nobody has to squint at a photograph to find out. }
procedure DacCheck;
const
  WANT : array[0..6, 0..2] of Byte =
    ((63,62,58), (46,51,58), (56,21,18), (6,15,34), (34,34,34), (7,30,17), (50,13,10));
var
  i, ok : Integer;
  r, g, b : Byte;
begin
  for i := 0 to 6 do SetRGBPalette(i, WANT[i,0], WANT[i,1], WANT[i,2]);
  EC := GraphResult;
  WriteLn(LF);
  WriteLn(LF, 'SetRGBPalette: GraphResult = ', EC, '   (0 = grOk)');
  WriteLn(LF, 'entry   wanted        read back from the DAC');
  ok := 0;
  for i := 0 to 6 do
  begin
    Port[$3C7] := i;
    r := Port[$3C9];  g := Port[$3C9];  b := Port[$3C9];
    Write(LF, i:5, WANT[i,0]:6, WANT[i,1]:4, WANT[i,2]:4, '  ->', r:6, g:4, b:4);
    if (r = WANT[i,0]) and (g = WANT[i,1]) and (b = WANT[i,2]) then
    begin WriteLn(LF, '   same'); Inc(ok); end
    else WriteLn(LF, '   DIFFERENT');
  end;
  WriteLn(LF);
  if ok = 7 then
    WriteLn(LF, 'all seven took: the page can have warm paper and a pale blue rule.')
  else
    WriteLn(LF, 'only ', ok, ' of 7 took: fall back to the stock sixteen colours.');
end;

procedure Swatches;
var i, y : Integer;
begin
  { paper, rule, margin, and the four pens - the whole palette of the lesson }
  SetRGBPalette( 0, 63, 62, 58);   { paper      - warm white   }
  SetRGBPalette( 1, 46, 51, 58);   { the rule   - pale blue    }
  SetRGBPalette( 2, 56, 21, 18);   { the margin - red          }
  SetRGBPalette( 3,  6, 15, 34);   { blue pen                  }
  SetRGBPalette( 4, 34, 34, 34);   { pencil                    }
  SetRGBPalette( 5,  7, 30, 17);   { green pen                 }
  SetRGBPalette( 6, 50, 13, 10);   { red pen                   }
  EC := GraphResult;

  SetFillStyle(SolidFill, 0);
  Bar(0, 0, GetMaxX, GetMaxY);
  SetColor(1);
  i := 0;
  while i <= GetMaxX do begin Line(i, 0, i, GetMaxY); Inc(i, 16); end;
  i := 0;
  while i <= GetMaxY do begin Line(0, i, GetMaxX, i); Inc(i, 16); end;
  SetColor(2);
  Line(576, 0, 576, GetMaxY);

  SetTextStyle(TriplexFont, HorizDir, 2);
  SetColor(3);
  OutTextXY(16, 16, 'paper, rule, margin - and four pens');
  for i := 3 to 6 do
  begin
    y := 80 + (i - 3) * 40;
    SetFillStyle(SolidFill, i);
    Bar(16, y, 120, y + 28);
    SetColor(i);
    SetTextStyle(TriplexFont, HorizDir, 1);
    OutTextXY(136, y + 8, 'Triplex 1 - (160,100) d = 6 cells = 240');
    SetTextStyle(5, HorizDir, 2);            { SCRI.CHR - only if it loads by index }
    OutTextXY(136, y + 22, 'font 5 - by hand, if it loaded at all');
  end;

  SetColor(3);
  SetTextStyle(DefaultFont, HorizDir, 1);
  if EC = grOk then OutTextXY(16, 300, 'SetRGBPalette returned grOk.')
               else OutTextXY(16, 300, 'SetRGBPalette FAILED - fall back to the stock sixteen.');
  OutTextXY(16, 320, 'If the paper is warm white and the rule pale blue, it works.');
  OutTextXY(16, 340, 'If this looks like plain EGA black/blue/green, it does not.');
  OutTextXY(16, 380, 'any key leaves');
  ReadKey;
end;

begin
  Show := (ParamCount > 0);

  Assign(LF, 'PROBE.LOG');
  Rewrite(LF);
  WriteLn(LF, 'PROBE - font metrics at 640x480, VGA driver');
  WriteLn(LF);

  Gd := VGA; Gm := VGAHi;
  InitGraph(Gd, Gm, 'D:\BGI');
  if GraphResult <> grOk then
  begin
    WriteLn(LF, 'InitGraph failed - EGAVGA.BGI not found in D:\BGI');
    Close(LF);
    Halt(1);
  end;
  WriteLn(LF, 'screen is ', GetMaxX + 1, ' x ', GetMaxY + 1,
              ', colours 0..', GetMaxColor);
  WriteLn(LF);

  Measure;
  DacCheck;
  if Show then Swatches;

  Close(LF);
  CloseGraph;
end.
