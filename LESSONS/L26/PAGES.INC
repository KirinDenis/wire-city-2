{ ==========================================================================
   THE LETTERS AS BITS - the tables and the small drawings the pages share.
   ========================================================================== }

const
  { the ROM's A, F000:FC76: eight rows of eight }
  ROMA  : array[0..7] of Byte = ($30, $78, $CC, $CC, $FC, $CC, $CC, $00);
  { the game's A, glyph 10 of FONT46: the top three bits }
  G46A  : array[0..5] of Byte = ($40, $A0, $E0, $A0, $A0, $00);
  { the A's third row, alone, for the carry }
  ROW3  : array[0..0] of Byte = ($A0);
  { this lesson's three: ( ) * }
  G46LP : array[0..5] of Byte = ($20, $40, $40, $40, $20, $00);
  G46RP : array[0..5] of Byte = ($80, $40, $40, $40, $80, $00);
  G46ST : array[0..5] of Byte = ($00, $A0, $40, $A0, $00, $00);
  { THE RING, worked by hand for the A. Its rows shifted right one, with
    an empty row above: q = 0 0 20 50 70 50 50 00 0 0 (hex) }
  HERE8 : array[0..7] of Byte = ($00, $20, $50, $70, $50, $50, $00, $00);
  TALL8 : array[0..7] of Byte = ($20, $70, $70, $70, $70, $50, $50, $00);
  WIDE8 : array[0..7] of Byte = ($70, $F8, $F8, $F8, $F8, $F8, $F8, $00);
  RING8 : array[0..7] of Byte = ($70, $D8, $A8, $88, $A8, $A8, $F8, $00);

  { the six letters of SPD 620, out of FONT46, for WORD46 }
  GKEY = 'SPD620';
  GF : array[1..6, 0..5] of Byte = (
    ($E0, $80, $E0, $20, $E0, $00),     { S }
    ($E0, $A0, $E0, $80, $80, $00),     { P }
    ($C0, $A0, $A0, $A0, $C0, $00),     { D }
    ($E0, $80, $E0, $A0, $E0, $00),     { 6 }
    ($E0, $20, $E0, $80, $E0, $00),     { 2 }
    ($E0, $A0, $A0, $A0, $E0, $00));    { 0 }

{ a byte as eight binary digits, in two fours }
function Bin8(b: Byte): string;
var s : string;
    i : Integer;
begin
  s := '';
  for i := 7 downto 0 do
  begin
    if (b shr i) and 1 = 1 then s := s + '1' else s := s + '0';
    if i = 4 then s := s + ' ';
  end;
  Bin8 := s;
end;

{ a byte as two hex digits }
function Hex2(b: Byte): string;
const D : string[16] = '0123456789ABCDEF';
begin
  Hex2 := D[b shr 4 + 1] + D[b and 15 + 1];
end;

{ ROWS AS SQUARES: each row of r is a byte, its top w bits drawn as squares
  of sz cells from the top-left (u, v) - a 1 filled with ink, a 0 an empty
  square of the grid, if empties }
procedure Bits(u, v, sz: Real; const r: array of Byte; w: Integer;
               ink, grid: Integer; empties: Boolean);
var i, j : Integer;
begin
  for i := 0 to High(r) do
    for j := 0 to w - 1 do
      if (r[i] shl j) and $80 <> 0 then
        FBox(u + j * sz, v + i * sz, u + (j + 1) * sz, v + (i + 1) * sz, ink, grid)
      else if empties then
        Box(u + j * sz, v + i * sz, u + (j + 1) * sz, v + (i + 1) * sz, grid);
end;

{ one pixel of the game's screen, px real pixels square }
procedure Pix(x, y, px, c: Integer);
begin
  SetFillStyle(SolidFill, c);
  Bar(x, y, x + px - 1, y + px - 1);
end;

{ WORD46 - TXT46 and TXT46O again, in Pascal: s in the game's letters at
  screen pixel (x, y), each of the game's pixels px real ones square. With
  ringed, the ring is worked out here exactly as LETTERS.ASM does it, and
  the hand-worked RING8 above has to come out the same. }
procedure Word46(x, y, px: Integer; s: string; ringed: Boolean;
                 ringc, inkc: Integer);
var k, i, r, col, at : Integer;
    q : array[0..9] of Byte;
    here, o : Byte;
begin
  for k := 1 to Length(s) do
  begin
    i := Pos(s[k], GKEY);
    at := x + (k - 1) * 4 * px;
    if i > 0 then
      if ringed then
      begin
        FillChar(q, SizeOf(q), 0);
        for r := 0 to 5 do q[r + 2] := GF[i, r] shr 1;
        for r := 0 to 7 do
        begin
          here := q[r + 1];
          o := q[r] or here or q[r + 2];                    { taller }
          o := Byte(((o or (o shl 1) or (o shr 1)) and not here) and $FF);
          for col := 0 to 4 do
          begin
            if (o shl col) and $80 <> 0 then
              Pix(at - px + col * px, y - px + r * px, px, ringc);
            if (here shl col) and $80 <> 0 then
              Pix(at - px + col * px, y - px + r * px, px, inkc);
          end;
        end;
      end
      else
        for r := 0 to 5 do
          for col := 0 to 2 do
            if (GF[i, r] shl col) and $80 <> 0 then
              Pix(at + col * px, y + r * px, px, inkc);
  end;
end;

{ A STRIP OF THE GAME'S WORLD, three cells high - its sky, then its snow -
  with SPD 620 written over each, six real pixels to one of the game's }
procedure Band(v: Integer; ringed: Boolean; ringc, inkc: Integer);
begin
  FBox(2, v, 18, v + 3, SKYD, SKYD);
  FBox(18, v, 34, v + 3, SNOWC, SNOWC);
  Word46(CX(4),  CY(v) + 6, 6, 'SPD 620', ringed, ringc, inkc);
  Word46(CX(21), CY(v) + 6, 6, 'SPD 620', ringed, ringc, inkc);
end;

{ ==========================================================================
   PAGE 1 - the letters are not in the screen. Text mode: the card draws
   them. Mode 13h: nobody does.
   ========================================================================== }
procedure PageCard(upto: Integer);
begin
  Big(1, 1, INK, 'THE LETTERS ARE NOT IN THE SCREEN');
  Lab(1, 3, REDPEN, 'Lesson 1A, a breather: the numbers in the corner, drawn by hand.');
  Big(1, 5, INK, 'TEXT MODE');
  Lab(1, 7, PENCIL, 'B800:0000');
  FBox(6, 7, 8, 8, PAPER, PEN);   Lab(6, 7, PEN, ' 41');
  FBox(8, 7, 10, 8, PAPER, PEN);  Lab(8, 7, PEN, ' 0F');
  Arrow(10.5, 7.5, 13.5, 7.5, PEN, True);
  Box(14, 6, 23, 9, PEN);
  Lab(15, 6, PEN, 'the card''s');
  Lab(15, 7, PEN, 'character');
  Lab(15, 8, PEN, 'generator');
  Arrow(23.5, 7.5, 26.5, 7.5, PEN, True);
  Bits(27.5, 5.5, 0.5, ROMA, 8, PEN, PENCIL, True);
  Lab(1, 11, INK, 'You write 41h. Seventy times a second the card itself looks the A');
  Lab(1, 12, INK, 'up in its own font and lights its pixels, scanline by scanline.');
  if upto < 2 then Exit;

  Big(1, 14, INK, 'MODE 13h');
  Lab(1, 16, PENCIL, 'A000:0000');
  FBox(6, 16, 8, 17, PAPER, PEN); Lab(6, 16, PEN, ' 41');
  Arrow(8.5, 16.5, 11.5, 16.5, PEN, True);
  FBox(12, 16, 13, 17, PEN, PEN);
  Lab(14, 16, PEN, 'one pixel, of colour 65. That is all.');
  Lab(1, 18, INK, 'The character generator is switched off. Nobody draws letters here.');
  if upto < 3 then Exit;

  Lab(1, 21, INK, 'Every letter in a graphics game is a picture the program puts');
  Lab(1, 22, INK, 'there itself, bit by bit. Lessons 17 to 19 borrowed the BIOS''s;');
  Lab(1, 23, INK, 'today the game''s own - and a ring to keep them readable.');
  Lab(1, 26, REDPEN, 'Letters are pictures: in mode 13h you draw them.');
  Ring(1, 26, 24);
end;

{ ==========================================================================
   PAGE 2 - the PC's own. The ROM's A, row by row; where it lives.
   ========================================================================== }
procedure PageRom(upto: Integer);
var i : Integer;
begin
  Big(1, 1, INK, 'THE PC''S OWN: EIGHT BYTES A LETTER');
  Bits(2, 5, 1, ROMA, 8, PEN, PENCIL, True);
  for i := 0 to 7 do
    Lab(12, 5 + i, PEN, Bin8(ROMA[i]) + '   ' + Hex2(ROMA[i]) + 'h');
  Lab(25, 6, INK, 'A 1 is ink,');
  Lab(25, 7, INK, 'a 0 is not.');
  Lab(25, 9, INK, 'The bits ARE');
  Lab(25, 10, INK, 'the pixels.');
  if upto < 2 then Exit;

  Lab(1, 15, INK, 'Where: F000:FA6E, in every PC''s ROM - the font the BIOS boots with.');
  Lab(1, 17, PEN, 'A = 41h.  Eight bytes a letter:  41h x 8 = 208h,  SHL by 3');
  Lab(1, 18, PEN, 'FA6E + 208 = FC76: the A''s eight rows');
  Lab(1, 19, REDPEN, 'F000:FC76');
  Ring(1, 19, 5);
  if upto < 3 then Exit;

  Lab(1, 22, INK, 'Eight pixels wide: forty letters across 320.');
  Lab(1, 23, INK, 'SPD 620 is 56 pixels - a sixth of the screen, for one number.');
  Lab(1, 24, INK, 'Lessons 17 to 19 wrote every number this way.');
  Lab(1, 26, REDPEN, 'A letter is a byte a row: the ones are the ink.');
  Ring(1, 26, 24);
end;

{ ==========================================================================
   PAGE 3 - the game's own: four by six. The A, where the font is, how big,
   and how glyph i is found without a MUL.
   ========================================================================== }
procedure PageOurs(upto: Integer);
var i : Integer;
begin
  Big(1, 1, INK, 'THE GAME''S OWN: FOUR BY SIX');
  Bits(2, 4, 1, G46A, 8, PEN, PENCIL, True);
  for i := 0 to 5 do
    Lab(12, 4 + i, PEN, Bin8(G46A[i]) + '   ' + Hex2(G46A[i]) + 'h');
  Lab(25, 5, INK, 'Three bits a row:');
  Lab(25, 6, INK, 'the top three.');
  Lab(25, 8, INK, 'Five rows, and');
  Lab(25, 9, INK, 'a blank sixth.');
  if upto < 2 then Exit;

  Lab(1, 12, INK, 'GAMES\OWLFLY3\SRC\RESDAT.ASM, resource 1: forty one letters, six');
  Lab(1, 13, INK, 'bytes each - 246 bytes, the whole font. The ROM''s is 1024.');
  Lab(1, 15, PEN, 'ROM 8x8    SPD 620    56 pixels wide');
  Lab(1, 16, PEN, 'OUR 4x6    SPD 620    28 pixels wide: half');
  if upto < 3 then Exit;

  Lab(1, 19, INK, 'Order: 0-9 are glyphs 0 to 9, A-Z 10 to 35, then + - : % .');
  Lab(1, 21, PEN, 'glyph i is at FONT46 + i x 6');
  Lab(1, 22, PEN, 'i x 6 = i x 4 + i x 2: two shifts and an ADD, no MUL');
  Lab(1, 23, PEN, 'the A is glyph 10:  10 x 4 + 10 x 2 = 60');
  Lab(1, 26, REDPEN, 'FONT46 + 60: the A.');
  Ring(1, 26, 10);
end;

{ ==========================================================================
   PAGE 4 - SHL drops a pixel into the carry. The A's third row, A0h.
   ========================================================================== }
procedure PageShl(upto: Integer);
begin
  Big(1, 1, INK, 'SHL DROPS A PIXEL INTO THE CARRY');
  Lab(1, 3, INK, 'The A''s third row: 1010 0000. Three pixels, three shifts.');
  Lab(2, 5, PENCIL, '              CF    AH');
  Lab(2, 6, PEN,    'start               1010 0000');
  Lab(2, 7, PEN,    'SHL AH,1       1    0100 0000     ink');
  if upto < 2 then Exit;

  Lab(2, 8, PEN,    'SHL AH,1       0    1000 0000     leave');
  Lab(2, 9, PEN,    'SHL AH,1       1    0000 0000     ink');
  Bits(29, 6, 1.5, ROW3, 3, PEN, PENCIL, True);
  Lab(2, 11, INK, 'The bit that falls off the top lands in the carry flag;');
  Lab(2, 12, INK, 'JNC jumps past the ink when it was a 0.');
  if upto < 3 then Exit;

  Lab(2, 15, PEN, '.px:  shl  ah,1          ; CF = the left pixel');
  Lab(2, 16, PEN, '      jnc  .np           ;   0: leave the picture');
  Lab(2, 17, PEN, '      mov  [es:di],al    ;   1: the ink');
  Lab(2, 18, PEN, '.np:  inc  di            ; the next column');
  Lab(2, 20, INK, 'Three columns, then ADD DI,320-3: the next row down.');
  Lab(2, 21, INK, 'Six rows, then the next letter, four pixels on:');
  Lab(2, 22, INK, 'three of letter, one of gap.');
  Lab(2, 26, REDPEN, 'The ROM''s loop again: three wide, not eight.');
  Ring(2, 26, 22);
end;
