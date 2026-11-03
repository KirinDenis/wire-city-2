{ ==========================================================================
   WHAT THE 386 CHANGED - pages 4 and 5.
   ========================================================================== }

{ ==========================================================================
   PAGE 4 - the new instructions: what each does and what the 8086 needed
   for it; what R3 printed; the ones only named.
   ========================================================================== }
procedure PageNew(upto: Integer);

  procedure Row(v: Integer; ins, does, was: string);
  begin
    Lab(2, v, PEN, ins);
    Lab(9, v, PEN, does);
    Lab(26, v, GREEN, was);
  end;

begin
  Big(1, 1, INK, 'THE NEW INSTRUCTIONS');
  Lab(1, 3, INK, 'One instruction where the 8086 needed several:');
  Lab(2, 5, PENCIL, '386');
  Lab(9, 5, PENCIL, 'does');
  Lab(26, 5, PENCIL, 'the 8086 needed');
  Row(6,  'MOVZX r,byte', 'a byte made wider, new bits 0',   'MOV, then MOV AH,0');
  Row(7,  'MOVSX r,byte', 'the same, new bits = its sign',   'MOV, then CBW');
  Row(8,  'IMUL  r,r',    'any register times any',          'AX only; DX spoilt');
  Row(9,  'SETL  r8',     'a condition made 0 or 1',         'CMP, a jump, a MOV');
  Row(10, 'BSR   r,r',    'the number of the highest 1',     'a loop of shifts');
  Lab(1, 12, PENCIL, 'MOVSX is not MOVSB or MOVSD: S for SIGN here, for STRING there.');
  if upto < 2 then Exit;

  Lab(1, 14, INK, 'R3 does each one both ways, and prints both:');
  Lab(4, 15, PENCIL, '                 8086       386');
  Lab(4, 16, PEN, 'MOVZX  200       00C8       000000C8');
  Lab(4, 17, PEN, 'MOVSX  -5        FFFB       FFFFFFFB');
  Lab(4, 18, PEN, 'IMUL   1000*300  0004:93E0  000493E0');
  Lab(4, 19, PEN, 'SETL   5 < 9 ?   01         01');
  Lab(4, 20, PEN, 'BSR    320       0008       00000008');
  Box(12.3, 18, 17.2, 19, REDPEN);       { the 8086's answer, in two }
  Box(17.8, 18, 22.2, 19, REDPEN);       {  registers; the 386's, one }
  if upto < 3 then Exit;

  Lab(1, 22, INK, 'Named here only: BT BTS BTR BTC test and set one bit; SHLD and');
  Lab(1, 23, INK, 'SHRD shift through two registers; a conditional jump reaches the');
  Lab(1, 24, INK, 'whole segment - 0F 8x, the very jump that hung lesson 24''s 186.');
  Lab(1, 25, GREEN, 'From the 186: SHL AX,4   PUSH 5   PUSHA - the 386 has them too.');
  Lab(1, 28, REDPEN, 'One instruction where the 8086 needed several.');
  Ring(1, 28, 23);
end;

{ ==========================================================================
   PAGE 5 - what did not change. The ModR/M byte and its one address;
   memory to memory through a register; the string instructions; real
   mode.
   ========================================================================== }
procedure PageSame(upto: Integer);
begin
  Big(1, 1, INK, 'WHAT DID NOT CHANGE');
  Lab(1, 3, INK, 'After its opcode an instruction has one ModR/M byte:');
  LabXY(CX(6) + 4, CY(5) + 4, PENCIL, '7   6');
  LabXY(CX(10) + 4, CY(5) + 4, PENCIL, '5   4   3');
  LabXY(CX(16) + 4, CY(5) + 4, PENCIL, '2   1   0');
  Cellbox(6, 6, 4, PEN, 'mod');
  Cellbox(10, 6, 6, PEN, 'reg');
  Cellbox(16, 6, 6, PEN, 'r/m');
  Lab(6, 7, PENCIL, 'how');
  Lab(10, 7, PENCIL, 'a register');
  Lab(16, 7, PENCIL, 'a register');
  Lab(16, 8, PENCIL, 'OR memory');
  Lab(1, 10, INK, 'Room for ONE address. On the 8086 and on the 386 alike:');
  Lab(2, 11, PEN, 'mov  [Dst], [Src]');
  Lab(14, 11, REDPEN, 'FASM: error: invalid operand.');
  if upto < 2 then Exit;

  Lab(1, 13, INK, 'Memory to memory goes through a register; the 386''s is wider.');
  Lab(2, 14, PEN, '8086  mov ax,[Src]   mov [Dst],ax    twice');
  Lab(2, 15, PEN, '386   mov eax,[Src]  mov [Dst],eax   once');
  Lab(29, 14, REDPEN, 'OWL!');
  Lab(29, 15, REDPEN, 'OWL!');
  Lab(1, 17, INK, 'The exception is as old as the 8086: the string instructions,');
  Lab(1, 18, INK, 'DS:SI to ES:DI. REP repeats them CX times. The 386 adds MOVSD:');
  Lab(2, 19, PEN, '8086  rep movsw       CX = 4');
  Lab(2, 20, PEN, '386   rep movsd       CX = 2');
  Lab(29, 19, REDPEN, 'WIRECITY');
  Lab(29, 20, REDPEN, 'WIRECITY');
  if upto < 3 then Exit;

  Lab(1, 22, INK, 'And real mode: segment * 16 + offset, 1 megabyte, 64 KB a');
  Lab(1, 23, INK, 'segment - the 8086''s rules, still. The 4 gigabytes belong to');
  Lab(1, 24, INK, 'protected mode, a lesson of its own.');
  Lab(1, 28, REDPEN, 'In real mode the 386 is a wide, fast 8086.');
  Ring(1, 28, 21);
end;
