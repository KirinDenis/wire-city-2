{ ==========================================================================
   PAGE 4 - thirty-two bits. EAX over AX; one byte in front; bit 18.
   ========================================================================== }
procedure PageWide(upto: Integer);
begin
  Big(1, 1, INK, 'THIRTY-TWO BITS');
  Lab(1, 3, INK, 'The 386 made every register twice as long. AX is the low half:');
  Lab(1, 6, PEN, 'EAX');
  Cellbox(5, 6, 12, PEN, 'the new half');
  Cellbox(17, 6, 6, GREEN, 'AH');
  Cellbox(23, 6, 6, GREEN, 'AL');
  LabXY(CX(4.4), CY(5) + 6, PENCIL, 'bit 31');
  LabXY(CX(27.6), CY(5) + 6, PENCIL, 'bit 0');
  SetColor(GREEN);
  Line(CX(17), CY(7.5), CX(29), CY(7.5));
  LabXY(CX(22.4), CY(7.8), GREEN, 'AX');
  Lab(1, 9, INK, 'EBX, ECX, EDX, ESI, EDI, EBP, ESP the same - and the flags too:');
  Lab(1, 10, INK, 'the old sixteen are the low half of EFLAGS.');
  if upto < 2 then Exit;

  Lab(1, 12, INK, 'And the instructions? The same ones, with one byte in front:');
  Lab(2, 14, GREEN, 'pushf               9C');
  Lab(2, 15, PEN, 'pushfd           66 9C');
  Lab(2, 16, GREEN, 'shl  bx,1           D1 E3');
  Lab(2, 17, PEN, 'shl  ebx,1       66 D1 E3');
  RingAt(CX(2) + 17 * 8 + 8, 15, 13);           { the 66 - the 18th letter }
  RingAt(CX(2) + 17 * 8 + 8, 17, 13);
  Lab(1, 19, INK, '66h says "the operand is 32 bits". FASM writes it when it sees');
  Lab(1, 20, INK, 'EAX. An 8086 knows no such prefix - so CPU3 stops at the verdict.');
  if upto < 3 then Exit;

  Lab(1, 22, INK, 'Then the same trick, one floor up: turn bit 18 over, read back.');
  Lab(2, 24, PENCIL, '         ----------IVVAVR-NIIODITSZ-A-P-C');
  Lab(2, 25, PEN, 'EFLAGS   00000000000000000111001000000010');
  Lab(2, 26, PEN, 'flip AC  00000000000001000111001000000010');
  RingAt(CX(2) + 22 * 8 + 4, 26, 7);            { bit 18: 9 letters, then 13 bits }
  Lab(1, 28, REDPEN, 'Bit 18 stays turned: a 486. On a 386 it springs back.');
  Ring(1, 28, 27);
end;

{ ==========================================================================
   PAGE 5 - it says its name. Bit 21; CPUID 0, twelve letters; CPUID 1,
   the signature; what the course page's DOS answers.
   ========================================================================== }
procedure PageName(upto: Integer);
begin
  Big(1, 1, INK, 'IT SAYS ITS NAME');
  Lab(1, 3, INK, 'Bit 21, ID, moves on late 486s and on every Pentium. It means:');
  Lab(1, 4, INK, 'this chip has CPUID, an instruction that answers about itself.');
  Lab(2, 6, PEN, 'xor  eax,eax      ; question 0: who made you?');
  Lab(2, 7, PEN, 'cpuid');
  LabXY(CX(3) + 4, CY(8.6), PENCIL, 'EBX');
  LabXY(CX(10) + 4, CY(8.6), PENCIL, 'EDX');
  LabXY(CX(17) + 4, CY(8.6), PENCIL, 'ECX');
  Cellbox(3, 9.4, 6, PEN, 'Genu');
  Cellbox(10, 9.4, 6, PEN, 'ineI');
  Cellbox(17, 9.4, 6, PEN, 'ntel');
  LabXY(CX(24), CY(9.6) + 2, PENCIL, 'EDX before ECX');
  if upto < 2 then Exit;

  Lab(2, 12, PEN, 'mov  eax,1        ; question 1: which one are you?');
  Lab(2, 13, PEN, 'cpuid             ; EAX = the signature');
  LabXY(CX(3) + 4, CY(14.6), PENCIL, 'bits 8-11');
  LabXY(CX(10) + 4, CY(14.6), PENCIL, 'bits 4-7');
  LabXY(CX(17) + 4, CY(14.6), PENCIL, 'bits 0-3');
  Cellbox(3, 15.4, 6, PEN, 'family 5');
  Cellbox(10, 15.4, 6, PEN, 'model 1');
  Cellbox(17, 15.4, 6, PEN, 'stepping 3');
  Lab(1, 18, INK, 'Family 4 is the 486, 5 the Pentium, 6 the Pentium Pro and on.');
  if upto < 3 then Exit;

  Lab(1, 20, INK, 'CPU4 on the course page''s DOS - DOS > Settings > CPU:');
  Lab(2, 22, PEN, '386       An 80386: bit 18, AC, is not there.');
  Lab(2, 23, PEN, 'auto      GenuineIntel  family 4, model 0, stepping 2');
  Lab(2, 24, PEN, 'Pentium   GenuineIntel  family 5, model 1, stepping 3');
  Lab(1, 26, GREEN, 'Before CPUID there was no question to ask - only wires to feel.');
  Lab(1, 28, REDPEN, 'From feeling for wires to being told.');
  Ring(1, 28, 19);
end;
