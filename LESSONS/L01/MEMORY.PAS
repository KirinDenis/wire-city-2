{ a screen is memory. this machine has two:

    B800:0000   text      80 x 25 cells, two bytes each
    A000:0000   graphics  320 x 200 pixels, one byte each

  both are one long row of bytes, written a line at a time:

    offset = y * width + x  }

{ ==========================================================================
  MEMORY.PAS - Lesson 1, "The Screen Is Memory".

  Turbo Pascal 7, real mode, DOS. No graphics unit, no BGI driver, no
  output function: two addresses and a byte each.

      $B800  the text screen. 80 x 25 cells, TWO bytes per cell -
             the character code, and then its colour attribute.
      $A000  the graphics screen in mode 13h. 320 x 200, ONE byte per
             pixel, and that byte is the colour.

  Run it in the Turbo Pascal IDE with Ctrl-F9, or compile with TPC.
  It waits for a key between stages, so press one to move along.

  Video: https://github.com/KirinDenis/wire-city-2
  Owlos - legacy software modernization - https://owlos.sk
  ========================================================================== }
program Memory;
uses Dos;
var i: Word;

{ Interrupt 16h, function 0: stop until somebody presses something. }
procedure WaitKey;
var r: Registers;
begin
  r.AH := 0;
  Intr($16, r);
end;

{ Interrupt 10h, function 0: ask the video BIOS for a screen mode. }
procedure SetMode(m: Byte);
var r: Registers;
begin
  r.AH := 0;
  r.AL := m;
  Intr($10, r);
end;

{ Text screen. Row * 80 + column, times two - because every cell is a pair. }
procedure WriteAt(col, row: Word; s: String; a: Byte);
var i, o: Word;
begin
  for i := 1 to Length(s) do
  begin
    o := (row * 80 + col + i - 1) * 2;
    Mem[$B800:o] := Ord(s[i]);
    Mem[$B800:o + 1] := a;
  end;
end;

{ Graphics screen. Row * 320 + column. One byte, and the byte is the colour. }
procedure Plot(x, y: Word; c: Byte);
var o: Word;
begin
  o := y * 320 + x;
  Mem[$A000:o] := c;
end;

begin
  { Nothing is cleared and nothing is printed - the video card was already
    showing these bytes before we finished writing them. }
  WriteAt(10, 5, 'HELLO', $1F);
  WriteAt(10, 7, 'nobody printed this', $0E);
  WaitKey;

  SetMode($13);

  Plot(160, 30, 15);                                  { one pixel, white }
  WaitKey;

  for i := 60 to 260 do Plot(i, 60, 10);              { a line, green }
  WaitKey;

  for i := 60 to 260 do Plot(i, 75, 12);              { one number later, red }
  WaitKey;

  for i := 112 to 208 do                              { a square is four lines }
  begin
    Plot(i, 100, 14);
    Plot(i, 180, 14);
  end;
  for i := 100 to 180 do
  begin
    Plot(112, i, 14);
    Plot(208, i, 14);
  end;
  WaitKey;

  { Always hand the text screen back. }
  SetMode(3);
  WriteAt(37, 9, 'OWLOS', $0F);
  WriteAt(25, 11, 'LEGACY SOFTWARE MODERNIZATION', $07);
  WriteAt(32, 13, 'https://owlos.sk', $0E);
  WaitKey;
end.
