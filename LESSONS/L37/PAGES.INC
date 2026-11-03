{ ==========================================================================
   WHAT THE 386 CHANGED - small things the pages share, and pages 1-3.
   ========================================================================== }

procedure LabXY(x, y: Integer; c: Integer; s: string);
begin
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(c);
  OutTextXY(x, y, s);
end;

{ a cell-sized box with a word in the middle of it: a byte, a field }
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
   PAGE 1 - the map: the 8086 against the 386, row by row; the 186 and 286
   passed over; every program asks first.
   ========================================================================== }
procedure PageMap(upto: Integer);

  procedure Row(v: Integer; what, was, now: string; same: Boolean);
  begin
    Lab(2, v, PEN, what);
    Lab(10, v, GREEN, was);
    if same then Lab(22, v, GREEN, now)
            else Lab(22, v, PEN, now);
  end;

begin
  Big(1, 1, INK, 'WHAT THE 386 CHANGED');
  Lab(1, 3, REDPEN, 'Lesson 25: the 8086 and the 386, side by side.');
  Lab(1, 5, INK, 'From here on the course writes for the 80386. First the map:');
  Lab(1, 6, INK, 'what changed, what is new, and what stayed as it was.');
  Lab(10, 8, PENCIL, '8086');
  Lab(22, 8, PENCIL, '386');
  Row(9,  'registers', '16 bits: AX, BX...',   '32 bits: EAX, EBX...', False);
  Row(10, 'addresses', 'BX BP SI DI, plus n',  'any, times 1 2 4 8',   False);
  Row(11, 'segments',  'CS DS ES SS',          'and FS, GS',           False);
  Row(12, 'one job',   'several instructions', 'MOVZX, SETcc, BSR...', False);
  Row(13, 'memory',    'one address a MOV',    'one address a MOV',    True);
  Row(14, 'real mode', '1 MB, 64 KB segments', '1 MB, 64 KB segments', True);
  if upto < 2 then Exit;

  Lab(1, 16, INK, 'The 80186 and 80286 are passed over: what they added, the 386');
  Lab(1, 17, INK, 'has as well.');
  Lab(2, 19, PEN, '80186   a shift by a number written in it, PUSH 5, PUSHA');
  Lab(2, 20, PEN, '80286   protected mode, 16 megabytes');
  Lab(1, 22, INK, 'Want a lesson on them? Write in our group, and we will make it.');
  if upto < 3 then Exit;

  Lab(1, 24, INK, 'Every program of this lesson asks first, in 8086 code:');
  Lab(2, 25, PEN, 'call NEED386        ; ENGINE\E_CPU.INC: lesson 24''s verdict');
  Lab(2, 26, GREEN, 'an 8086 or 286:  This program needs an 80386 or newer.');
  Lab(1, 28, REDPEN, 'Ask in 8086 - then speak 32 bits.');
  Ring(1, 28, 17);
end;

{ ==========================================================================
   PAGE 2 - the registers. EAX and its names; what R1 printed; the carry
   that the 8086 leaves in a flag and the 386 carries on.
   ========================================================================== }
procedure PageRegs(upto: Integer);
begin
  Big(1, 1, INK, 'THE REGISTERS');
  Lab(1, 3, INK, 'Every register twice as long. The low half keeps the 8086''s name;');
  Lab(1, 4, INK, 'the top half has none - only a shift reaches it.');

  LabXY(CX(4), CY(6) + 6, PENCIL, '31');
  LabXY(CX(20) - 20, CY(6) + 6, PENCIL, '16');
  LabXY(CX(20) + 4, CY(6) + 6, PENCIL, '15');
  LabXY(CX(26) - 12, CY(6) + 6, PENCIL, '8');
  LabXY(CX(26) + 4, CY(6) + 6, PENCIL, '7');
  LabXY(CX(31) + 8, CY(6) + 6, PENCIL, '0');
  Lab(1, 7, PEN, 'EAX');
  Cellbox(4, 7, 16, PENCIL, 'top half: no name');
  Cellbox(20, 7, 6, GREEN, 'AH');
  Cellbox(26, 7, 6, GREEN, 'AL');
  SetColor(GREEN);
  Line(CX(20), CY(8.5), CX(32), CY(8.5));
  Line(CX(20), CY(8.2), CX(20), CY(8.5));
  Line(CX(32), CY(8.2), CX(32), CY(8.5));
  Lab(25, 9, GREEN, 'AX');
  Lab(2, 11, PEN, 'EAX EBX ECX EDX ESI EDI EBP ESP  EFLAGS EIP  +FS, GS');
  if upto < 2 then Exit;

  Lab(1, 13, INK, 'R1 prints them. Writing AX leaves the top half alone:');
  Lab(2, 14, PEN, 'mov eax,12345678h   AX = 5678   AH = 56   AL = 78');
  Lab(2, 15, PEN, 'mov ax,0            EAX = 12340000');
  Lab(2, 16, PEN, 'shr eax,16          EAX = 00001234: the top half, down');
  if upto < 3 then Exit;

  Lab(1, 18, INK, '100000 + 50000 = 150000: more than 16 bits hold (65535).');
  Lab(2, 20, PENCIL, '8086: DX:AX, ADD then ADC');
  Lab(21, 20, PENCIL, '386: EAX, one ADD');

  { the 8086: two columns, and the carry goes through CF }
  Lab(3, 22, PEN, '0001');
  Lab(9, 22, PEN, '86A0');
  Lab(2, 23, PEN, '+');
  Lab(3, 23, PEN, '0000');
  Lab(9, 23, PEN, 'C350');
  SetColor(PENCIL);
  Line(CX(3), CY(24), CX(5), CY(24));
  Line(CX(9), CY(24), CX(11), CY(24));
  Lab(3, 24, REDPEN, '0002');
  Lab(9, 24, REDPEN, '49F0');
  Lab(3, 25, PENCIL, 'ADC');
  Lab(9, 25, PENCIL, 'ADD');
  Cellbox(6, 21, 2, REDPEN, 'CF');
  Arrow(9.5, 21.5, 8, 21.5, REDPEN, True);
  Arrow(6, 21.5, 4.5, 21.5, REDPEN, True);

  { the 386: one column, and the carry runs on inside it }
  Lab(23, 22, PEN, '0001 86A0');
  Lab(22, 23, PEN, '+');
  Lab(23, 23, PEN, '0000 C350');
  SetColor(PENCIL);
  Line(CX(23), CY(24), CX(27.5), CY(24));
  Lab(23, 24, REDPEN, '0002 49F0');
  Arrow(25.6, 21.5, 24.6, 21.5, REDPEN, True);
  Lab(22, 25, PENCIL, 'bit 15 to bit 16,');
  Lab(22, 26, PENCIL, 'inside the adder');

  Lab(1, 28, REDPEN, 'The carry the 8086 left in a flag, the 386 carries into bit 16.');
  Ring(1, 28, 32);
end;

{ ==========================================================================
   PAGE 3 - the addresses. The 8086's nine sums; the 386's one form; LEA
   as a calculator; real mode's limit.
   ========================================================================== }
procedure PageAddr(upto: Integer);
begin
  Big(1, 1, INK, 'THE ADDRESSES');
  Lab(1, 3, INK, 'The 8086 makes an address out of these sums, and no others:');
  Lab(2, 5, GREEN, '[BX+SI+n]   [BX+DI+n]   [BP+SI+n]   [BP+DI+n]');
  Lab(2, 6, GREEN, '[SI+n]      [DI+n]      [BP+n]      [BX+n]      [n]');
  Lab(1, 8, INK, 'Four registers may point - BX, BP, SI, DI. [AX] does not exist,');
  Lab(1, 9, INK, 'and nothing multiplies: a table of words doubles its index by hand.');
  if upto < 2 then Exit;

  Lab(1, 11, INK, 'The 386: any register, the index times 1, 2, 4 or 8, and a number.');
  Lab(4, 13, PEN, '[ base    +  index    *  scale    +  n ]');
  Lab(5, 14, PENCIL, 'any of 8     any but ESP   1, 2, 4, 8  a number');
  Lab(2, 16, PEN, 'squares[7]  8086  mov bx,ax  shl bx,1  mov ax,[Sq+bx]');
  Lab(2, 17, PEN, '            386   mov ax,[Sq+eax*2]     67 8B 84 00 ...');
  Lab(1, 18, PENCIL, '67h: "this address is 32 bits" - lesson 24''s 66h, for addresses.');
  if upto < 3 then Exit;

  Lab(1, 20, INK, 'LEA works an address out and keeps the number: a calculator.');
  Lab(2, 21, PENCIL, 'pixel (100, 50) of mode 13h: 320*y + x');
  Lab(2, 22, PEN, '8086  y*256 + y*64: two shifts by CL, two ADDs');
  Lab(2, 23, PEN, '386   lea eax,[eax+eax*4]   ; y*5');
  Lab(2, 24, PEN, '      shl eax,6             ; y*5*64 = y*320');
  Lab(2, 25, PEN, '      add eax,100           ; + x');
  Lab(29, 22, REDPEN, '3EE4');
  Lab(29, 25, REDPEN, '00003EE4');
  Lab(1, 26, PENCIL, 'Real mode still: an address under 10000h - so the top half of');
  Lab(1, 27, PENCIL, 'an index register must be 0: MOV EAX,7, never MOV AX,7.');
  Lab(1, 28, REDPEN, 'Any register, times 1, 2, 4 or 8.');
  Ring(1, 28, 17);
end;
