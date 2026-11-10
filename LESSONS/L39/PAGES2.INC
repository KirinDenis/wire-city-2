{ ==========================================================================
   FLAT MEMORY - pages 4, 5 and 6.
   ========================================================================== }

{ ==========================================================================
   PAGE 4 - a selector is a line. FLAT2's four lines; a descriptor's eight
   bytes; the switch and the way back.
   ========================================================================== }
procedure PageLine(upto: Integer);
const
  What : array[0..7] of string[7] =
    ('length', 'length', 'start', 'start', 'start', 'kind', 'G B len', 'start');
  Bits : array[0..7] of string[7] =
    ('0-7', '8-15', '0-7', '8-15', '16-23', '92h 9Ah', 'CFh', '24-31');
var i : Integer;
    s : string[1];
begin
  Big(1, 1, INK, 'A SELECTOR IS A LINE');
  Lab(1, 3, INK, 'In protected mode a segment register holds a SELECTOR: the number');
  Lab(1, 4, INK, 'of a line in a table we write ourselves, the GDT. FLAT2''s has four:');
  Lab(2, 6, PENCIL, '00h   nothing: the processor wants the first line empty');
  Lab(2, 7, PEN, '08h   our code, 64K, starting where DOS put us');
  Lab(2, 8, PEN, '10h   our data, the same place and length');
  Lab(2, 9, REDPEN, '18h   FLAT: starting at nought, 4 GB - every byte there is');
  if upto < 2 then Exit;

  Lab(1, 11, INK, 'A line is a DESCRIPTOR, eight bytes:');
  for i := 0 to 7 do
  begin
    Str(i, s);
    Lab(3 + i * 4, 12, PENCIL, s);
    Cellbox(2 + i * 4, 13, 4, PEN, What[i]);
    Lab(2 + i * 4, 14, PENCIL, Bits[i]);
  end;
  Lab(1, 16, INK, 'The start comes in three pieces, for the 286''s sake. The length');
  Lab(1, 17, INK, 'counts in 4K pieces when G is set: FFFFFh + 1 of them is 4 GB.');
  if upto < 3 then Exit;

  Lab(1, 19, INK, 'The trip, with the interrupts off all the way:');
  Lab(2, 20, PEN, 'lgdt [GdtPtr]                     ; where the table is');
  Lab(2, 21, PEN, 'mov eax,cr0  or al,1  mov cr0,eax ; PE = 1');
  Lab(2, 22, PEN, 'jmp 08h:.pm                       ; a far jump: CS = line 08h');
  Lab(2, 23, REDPEN, 'mov [fs:edi],edi                  ; FS = 18h: EDI is the address');
  Lab(2, 24, GREEN, 'home: 64K lines in every segment, PE = 0, RETF to our paragraph');
  Lab(1, 25, PENCIL, 'FLAT2 writes a megabyte above 1 MB, each double word its own');
  Lab(1, 26, PENCIL, 'address, and reads it back: 1048576 bytes, nought wrong.');
  Lab(1, 28, REDPEN, 'Through a flat line one register is a whole address.');
  Ring(1, 28, 26);
end;

{ ==========================================================================
   PAGE 5 - a program that lives there. The IDT; the clash of INT 8; the
   faults that come home, and what is given back.
   ========================================================================== }
procedure PageGate(upto: Integer);
begin
  Big(1, 1, INK, 'A PROGRAM THAT STAYS');
  Lab(1, 3, INK, 'FLAT2 went with the interrupts off. FLAT3 stays, and needs them: a');
  Lab(1, 4, INK, 'second table, the IDT, eight bytes a GATE - which routine takes it:');
  Lab(2, 6, PEN, '0..31    the processor''s complaints: divide by 0, a wrong selector');
  Lab(2, 7, PEN, '32, 33   IRQ 0, the timer - and IRQ 1, the keys');
  Lab(2, 8, PENCIL, '34..47   the IRQs we mask: nothing comes');
  if upto < 2 then Exit;

  Lab(1, 10, INK, 'The timer is IRQ 0, and the interrupt controller sends it as INT 8.');
  Lab(1, 11, INK, 'IBM used 8 to 15 for the IRQs. Intel had kept 0 to 31 for itself:');
  Cellbox(3, 13, 6, PEN, 'IRQ 0');
  Cellbox(14, 13, 7, GREEN, 'INT 8');
  Cellbox(14, 16, 7, REDPEN, 'INT 32');
  Arrow(9, 13.5, 14, 13.5, PENCIL, False);
  Arrow(9, 13.7, 14, 16.4, REDPEN, True);
  Lab(22, 13, GREEN, 'protected mode:');
  Lab(22, 14, GREEN, 'DOUBLE FAULT');
  Lab(22, 16, REDPEN, 'ours: the timer');
  Lab(1, 18, PENCIL, 'So the controller is told new numbers - IRQ 0..7 as INT 32..39 -');
  Lab(1, 19, PENCIL, 'and its old ones on the way out. Four bytes: ICW1 to ICW4.');
  if upto < 3 then Exit;

  Lab(1, 21, INK, 'No gate for a fault: a second fault, then a third, and the PC');
  Lab(1, 22, INK, 'resets. So each of the 32 has a stub: it keeps its number, goes home.');
  Lab(2, 24, GREEN, 'given back: the controller, the timer, text mode, the gate, HIMEM''s');
  Lab(2, 25, GREEN, 'megabyte. And the BIOS clock at 46Ch: every fourth tick of ours.');
  Lab(1, 28, REDPEN, 'INT 8: the timer to IBM, the double fault to Intel.');
  Ring(1, 28, 26);
end;

{ ==========================================================================
   PAGE 6 - the game past 64K. FLY's two segments; where everything went;
   the five lines that meant something else in 32 bits.
   ========================================================================== }
procedure PageFly(upto: Integer);
begin
  Big(1, 1, INK, 'THE GAME PAST 64K');
  Lab(1, 3, INK, 'FLY is lesson 26''s flight as an .EXE of two segments:');
  Cellbox(2, 5, 11, GREEN, 'host, use16');
  Cellbox(21, 5, 11, PEN, 'game, use32');
  Arrow(13, 5.5, 21, 5.5, REDPEN, True);
  Lab(14, 4, REDPEN, 'a far jump');
  Lab(2, 6, PENCIL, 'real mode: HIMEM,');
  Lab(2, 7, PENCIL, 'A20, the tables');
  Lab(21, 6, PENCIL, 'CLOCK''s code, line');
  Lab(21, 7, PENCIL, 'for line, 32-bit');
  if upto < 2 then Exit;

  Lab(1, 9, INK, 'A paragraph in a segment register is a selector now:');
  Lab(2, 11, GREEN, 'cs + 1000h   the back buffer');
  Lab(19, 11, PEN, 'SEL_BUF: HIMEM''s, above 1 MB');
  Lab(2, 12, GREEN, 'cs + 2000h   the tables');
  Lab(19, 12, PEN, 'SEL_TAB: the next 64K of it');
  Lab(2, 13, GREEN, '0A000h       the screen');
  Lab(19, 13, PEN, 'SEL_SCR: from 0A0000h');
  Lab(2, 14, GREEN, 'INT 8, INT 9 vectors');
  Lab(19, 14, PEN, 'gates 32 and 33 of the IDT');
  Lab(1, 16, PENCIL, '78471 bytes, and the 64K wall is not there.');
  if upto < 3 then Exit;

  Lab(1, 18, INK, 'Every line of CLOCK assembled again, the 32-bit way. Five meant');
  Lab(1, 19, INK, 'something else there:');
  Lab(2, 21, PEN, '1  the code grew: a 16-bit address stops at 64K - data first');
  Lab(2, 22, PEN, '2  JCXZ reaches 127 bytes: TEST and JZ');
  Lab(2, 23, PEN, '3  LOOP and REP count with all of ECX: MOVZX first');
  Lab(2, 24, PEN, '4  code that rewrites itself: its number moved one byte on');
  Lab(2, 25, PEN, '5  MOV AX,CS gives the code line: write through it, exception 13');
  Lab(1, 28, REDPEN, 'The same flight, and no 64K wall.');
  Ring(1, 28, 17);
end;
