{ ==========================================================================
   WHICH PROCESSOR IS THIS - small things the pages share, and pages 1-3.
   ========================================================================== }

procedure LabXY(x, y: Integer; c: Integer; s: string);
begin
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(c);
  OutTextXY(x, y, s);
end;

{ a cell-sized box with a word in the middle of it: a byte, a bit }
procedure Cellbox(u, v, w: Real; c: Integer; s: string);
begin
  Box(u, v, u + w, v + 1, c);
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(CenterText, CenterText);
  SetColor(c);
  OutTextXY(CX(u + w / 2), CY(v + 0.5) + 1, s);
  SetTextJustify(LeftText, TopText);
end;

{ a red ring round a few letters inside a line: x is the middle, in pixels }
procedure RingAt(x, v, rx: Integer);
begin
  SetColor(REDPEN);
  Ellipse(x, v * CELL + 8, 0, 360, rx, 10);
end;

{ ==========================================================================
   PAGE 1 - which processor is this? The family; what each one added; the
   two mistakes of this lesson's own drafts.
   ========================================================================== }
procedure PageWhich(upto: Integer);
begin
  Big(1, 1, INK, 'WHICH PROCESSOR IS THIS?');
  Lab(1, 3, REDPEN, 'Lesson 24: the flags, the 386, and CPUID.');
  Lab(1, 5, INK, 'One .COM file runs on every PC from the 8086 to the Pentium,');
  Lab(1, 6, INK, 'and nothing tells it which one it is on. Each one added more:');
  Lab(2, 8, GREEN, '8086, 8088   16 bits - this course, up to now');
  Lab(2, 9, PEN, '80186        SHR AX,4 - a count written in the instruction');
  Lab(2, 10, PEN, '80286        protected mode, 16 megabytes');
  Lab(2, 11, PEN, '80386        32 bits: EAX, EBX... and 4 gigabytes');
  Lab(2, 12, PEN, '80486        the maths chip and a cache, inside');
  Lab(2, 13, PEN, 'Pentium      two pipelines - and CPUID, on every one');
  if upto < 2 then Exit;

  Lab(1, 15, INK, 'An instruction a chip does not have is not refused politely.');
  Lab(1, 16, INK, 'Two of this lesson''s own drafts, on an emulated 8086 and 186:');
  Lab(2, 18, PEN, 'shr  al,4       C0 E8 04       the 186''s: printed nothing');
  Lab(2, 19, PEN, 'jnz  far        0F 85 lo hi    the 386''s: hung');
  Lab(1, 21, INK, 'FASM wrote the second by itself, for a jump too far to reach.');
  Lab(1, 22, INK, 'To an 8086 the byte 0F begins another instruction altogether.');
  if upto < 3 then Exit;

  Lab(1, 24, INK, 'So the detector is 8086 code to its last byte - E_8086.INC');
  Lab(1, 25, INK, 'keeps its jumps short - and only past its verdict may the');
  Lab(1, 26, INK, 'newer instructions run.');
  Lab(1, 28, REDPEN, 'Ask in the oldest language; answer in the newest.');
  Ring(1, 28, 25);
end;

{ ==========================================================================
   PAGE 2 - the flags register. Sixteen cells; PUSHF and a loop; the same
   program on three processors.
   ========================================================================== }
procedure PageFlags(upto: Integer);
const
  NAMES : string[16] = '-NIIODITSZ-A-P-C';
var i, c : Integer;
    s : string[2];
begin
  Big(1, 1, INK, 'THE FLAGS REGISTER');
  Lab(1, 3, INK, 'Sixteen bits the processor writes as it works. CPU1 prints');
  Lab(1, 4, INK, 'them, one under the letter that names it:');
  for i := 0 to 15 do
  begin
    Str(15 - i, s);
    LabXY(CX(2 + i * 2) + 4, CY(6) + 4, PENCIL, s);
    if i < 4 then c := REDPEN                  { 12-15: the generations }
    else if NAMES[i + 1] = '-' then c := PENCIL
    else c := PEN;
    if (NAMES[i + 1] = 'C') or (NAMES[i + 1] = 'T') then c := GREEN;
    Cellbox(2 + i * 2, 7, 2, c, NAMES[i + 1]);
  end;
  Lab(2, 9, GREEN, 'C carry (lesson 1A)   T trap (lesson 23)');
  Lab(2, 10, PEN, 'P parity  A half carry  Z zero  S sign  I interrupts');
  Lab(2, 11, PEN, 'D direction  O overflow  I I privilege  N nested task');
  if upto < 2 then Exit;

  Lab(2, 13, PEN, 'pushf             ; the flags onto the stack');
  Lab(2, 14, PEN, 'pop  bx           ; ...and into BX');
  Lab(2, 15, PEN, 'shl  bx,1         ; the top bit falls into CF');
  Lab(2, 16, PEN, 'adc  dl,0         ; ''0'' + CF: ''0'' or ''1''');
  Lab(1, 18, INK, 'Sixteen times round, and the register is on the screen.');
  if upto < 3 then Exit;

  Lab(1, 20, INK, 'CPU1, the same program, on three processors:');
  Lab(2, 22, PENCIL, '          -NIIODITSZ-A-P-C');
  Lab(2, 23, PEN, '8086      1111001000000010');
  Lab(2, 24, PEN, '286       0000001000000010');
  Lab(2, 25, PEN, '386       0111001000000010');
  LabXY(CX(17), CY(24) + 4, PENCIL, 'measured in DOSBox-X');
  Box(6.8, 23, 9.2, 26, REDPEN);                 { bits 15 to 12, all three }
  Lab(1, 28, REDPEN, 'Bits 12 to 15 are where the generations differ.');
  Ring(1, 28, 24);
end;

{ ==========================================================================
   PAGE 3 - write, and read back. The table; a cell against a wire; the
   physical fact.
   ========================================================================== }
procedure PageWires(upto: Integer);
begin
  Big(1, 1, INK, 'WRITE, AND READ BACK');
  Lab(1, 3, INK, 'POPF writes a word into the flags; PUSHF reads back what');
  Lab(1, 4, INK, 'stayed. CPU2 writes 0000h, then F000h, and reads bits 12-15:');
  Lab(2, 6, PENCIL, '              put 0000   put F000');
  Lab(2, 7, PEN, '8086, 186       1111       1111      tied to 1');
  Lab(2, 8, PEN, '286             0000       0000      tied to 0');
  Lab(2, 9, PEN, '386 and up      0000       0111      12-14 are there');
  if upto < 2 then Exit;

  { a bit the chip has: a cell, written and read }
  Box(3, 12, 9, 15, PEN);
  Lab(4, 13, PEN, 'a cell');
  Arrow(1, 13.5, 3, 13.5, PEN, False);
  Arrow(9, 13.5, 11, 13.5, PEN, False);
  LabXY(CX(1), CY(14.4), PENCIL, 'in');
  LabXY(CX(9.5), CY(14.4), PENCIL, 'out');
  Lab(2, 17, PEN, 'keeps what you');
  Lab(2, 18, PEN, 'wrote: the 386');

  { a bit tied to 1: a wire to the supply }
  SetColor(PEN);
  Line(CX(17), CY(15), CX(17), CY(12));
  Line(CX(15.5), CY(12), CX(18.5), CY(12));
  LabXY(CX(15.6), CY(11), PEN, '+5 V');
  Arrow(17, 14, 20, 14, PEN, False);
  Lab(15, 17, PEN, 'always 1:');
  Lab(15, 18, PEN, 'the 8086');

  { a bit tied to 0: a wire to the ground }
  SetColor(PEN);
  Line(CX(28), CY(12), CX(28), CY(15));
  Line(CX(26.5), CY(15), CX(29.5), CY(15));
  Line(CX(27), CY(15.4), CX(29), CY(15.4));
  Line(CX(27.5), CY(15.8), CX(28.5), CY(15.8));
  Arrow(28, 13, 31, 13, PEN, False);
  Lab(26, 17, PEN, 'always 0:');
  Lab(26, 18, PEN, 'the 286');
  if upto < 3 then Exit;

  Lab(1, 21, INK, 'Nobody wrote "this is a 286" anywhere in the chip. The answer');
  Lab(1, 22, INK, 'is how it was wired - and a program can feel for the wires.');
  Lab(2, 24, GREEN, 'An 80386 or newer: bits 12 to 14 take what we write.');
  Lab(1, 28, REDPEN, 'A bit that is not there reads back its wire.');
  Ring(1, 28, 22);
end;
