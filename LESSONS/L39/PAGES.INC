{ ==========================================================================
   FLAT MEMORY - small things the pages share, and pages 1-3.
   ========================================================================== }

procedure LabXY(x, y: Integer; c: Integer; s: string);
begin
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(c);
  OutTextXY(x, y, s);
end;

{ a box with a word in the middle of it: a byte, a field, a chip }
procedure Cellbox(u, v, w: Real; c: Integer; s: string);
begin
  Box(u, v, u + w, v + 1, c);
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(CenterText, CenterText);
  SetColor(c);
  OutTextXY(CX(u + w / 2), CY(v + 0.5) + 1, s);
  SetTextJustify(LeftText, TopText);
end;

{ ==========================================================================
   PAGE 1 - the 64K is full. Lesson 26's segment, byte by byte; why a real
   mode address stops at a megabyte; what the 386 has.
   ========================================================================== }
procedure PageWall(upto: Integer);
begin
  Big(1, 1, INK, 'THE 64K IS FULL');
  Lab(1, 3, REDPEN, 'Lesson 27: the flight past 64K, in protected mode.');
  Lab(1, 5, INK, 'A .COM is ONE segment: the code, the data and the stack, in 64K.');
  { the segment, to scale: 32 cells are 65536 bytes }
  FBox(2, 7, 2.13, 8, GREEN, GREEN);
  FBox(2.13, 7, 33.77, 8, PEN, PEN);
  Box(2, 7, 34, 8, PENCIL);
  Lab(1, 8, GREEN, '100h: DOS''s own, the PSP');
  Lab(9, 9, PEN, 'CLOCK.COM, lesson 26: 64803 bytes');
  Lab(25, 6, REDPEN, 'the stack: 477');
  Arrow(32.3, 6.5, 33.9, 7, REDPEN, True);
  Lab(1, 11, PENCIL, '256 + 64803 + 477 = 65536. Not one more table fits.');
  if upto < 2 then Exit;

  Lab(1, 13, INK, 'Why 64K? In real mode an address is two 16-bit numbers:');
  Lab(2, 15, PEN, 'address = segment * 16 + offset');
  Lab(2, 16, PENCIL, 'the offset: 0 to FFFFh - 64K from wherever the segment starts');
  Lab(2, 17, PENCIL, 'FFFF:FFFF = FFFF0h + FFFFh = 10FFEFh: the most it can say');
  Lab(1, 19, INK, 'One megabyte, and a little. And one register holds one segment.');
  if upto < 3 then Exit;

  Lab(1, 21, INK, 'The 386 has 32 address wires: 2^32 bytes, four gigabytes. To reach');
  Lab(1, 22, INK, 'them, a segment register must hold something else.');
  Lab(1, 24, PENCIL, 'Three small programs go and get them, one growing: FLAT1 looks,');
  Lab(1, 25, PENCIL, 'FLAT2 goes there and back, FLAT3 stays. Then FLY: lesson 26''s');
  Lab(1, 26, PENCIL, 'flight, past the wall.');
  Lab(1, 28, REDPEN, 'Real mode reaches 1 MB. Protected mode, 4 GB.');
  Ring(1, 28, 23);
end;

{ ==========================================================================
   PAGE 2 - the 21st address wire. The wrap; the gate on the keyboard chip;
   the test, and the two bytes that work the pin.
   ========================================================================== }
procedure PageWire(upto: Integer);
begin
  Big(1, 1, INK, 'THE 21ST WIRE');
  Lab(1, 3, INK, 'The 8086 had twenty address wires, A0 to A19: 2^20 is one megabyte.');
  Lab(2, 5, PEN, 'FFFF:0010 = FFFF0h + 10h = 100000h');
  Lab(2, 6, PENCIL, '          = 1 0000 0000 0000 0000 0000    a 1 and twenty noughts');
  Lab(1, 8, INK, 'There was no 21st wire to carry the 1. It fell off, the address');
  Lab(1, 9, INK, 'was 00000h, and it wrapped round. Programs counted on it.');
  if upto < 2 then Exit;

  Lab(1, 11, INK, 'The 286 had 24 wires. To keep the wrap, IBM put a GATE on A20:');
  Cellbox(2, 13, 6, PEN, 'CPU');
  Cellbox(14, 13, 6, REDPEN, 'gate');
  Cellbox(26, 13, 8, PEN, 'memory');
  Arrow(8, 13.5, 14, 13.5, PEN, False);
  Arrow(20, 13.5, 26, 13.5, PEN, False);
  Lab(10, 12, PENCIL, 'A20');
  Lab(20, 12, PENCIL, 'held at 0');
  Cellbox(12, 16, 10, GREEN, 'keyboard chip');
  Arrow(17, 16, 17, 14, REDPEN, True);
  Lab(23, 16, GREEN, 'an 8042: a spare pin');
  Lab(1, 18, PENCIL, 'Shut, A20 stays nought and the wrap is kept. Every PC since has it.');
  if upto < 3 then Exit;

  Lab(1, 20, INK, 'Is it shut? Two addresses that differ only in that wire:');
  Lab(2, 21, PEN, '0000:0500 = 00500h        FFFF:0510 = 100500h');
  Lab(2, 22, PENCIL, '00h into one, FFh into the other, read the first: FFh means shut.');
  Lab(1, 24, INK, 'To open it: D1h to port 64h - "the next byte is your pins" - then:');
  Lab(2, 25, PEN, 'DFh = 1101 1111   bit 1, the gate: open    bit 0, reset: kept 1');
  Lab(2, 26, PEN, 'DDh = 1101 1101   bit 1, the gate: shut');
  Lab(1, 28, REDPEN, 'The 21st address wire has a gate.');
  Ring(1, 28, 17);
end;

{ ==========================================================================
   PAGE 3 - whose is the machine, and who keeps the memory. CR0's PE bit;
   HIMEM's five calls; a number printed with no DIV.
   ========================================================================== }
procedure PageKeep(upto: Integer);
begin
  Big(1, 1, INK, 'WHO KEEPS IT');
  Lab(1, 3, INK, 'CR0 is the 386''s control register. Bit 0 is PE, protection enable:');
  Lab(2, 5, PEN, 'smsw ax        ; AX = the low half of CR0: any program may read it');
  Lab(2, 7, GREEN, 'PE = 0   real mode: the processor is ours');
  Lab(2, 8, GREEN, 'PE = 1   virtual 8086: a memory manager owns it. Hands off');
  if upto < 2 then Exit;

  Lab(1, 10, INK, 'The memory above 1 MB has a keeper: HIMEM. INT 2Fh finds it, and');
  Lab(1, 11, INK, 'then it is CALLED - a far call - with a number in AH:');
  Lab(2, 13, PEN, '4300h  INT 2Fh   are you there? AL = 80h: yes');
  Lab(2, 14, PEN, '4310h  INT 2Fh   where do I call you? ES:BX');
  Lab(2, 15, PEN, '08h    how much is free, in KB');
  Lab(2, 16, PEN, '09h    a block of DX KB, please: a HANDLE comes back');
  Lab(2, 17, REDPEN, '0Ch    lock it, and say where it is: DX:BX, 32 bits');
  Lab(2, 18, PEN, '0Dh    unlock it          0Ah   give it back');
  if upto < 3 then Exit;

  Lab(1, 20, INK, 'The numbers are printed with no DIV: a MUL by 2^35 / 10, rounded up.');
  Lab(2, 22, PEN, 'mov  edx,0CCCCCCCDh   mul edx   shr edx,3     ; EDX = n / 10');
  Lab(2, 23, PENCIL, 'MUL EDX: EAX times EDX, 64 bits wide, the top half in EDX');
  Lab(1, 25, GREEN, 'On the course page FLAT1 says: PE nought, the gate shut, and');
  Lab(1, 26, GREEN, '14912 KB free.');
  Lab(1, 28, REDPEN, 'Ask for it, lock it, and it has an address.');
  Ring(1, 28, 22);
end;
