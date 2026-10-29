{ ==========================================================================
   THE BREAKUP - small things the pages share, and pages 1 to 3.
   ========================================================================== }

procedure Thick(x1, y1, x2, y2, c: Integer);
begin
  SetColor(c);
  SetLineStyle(SolidLn, 0, ThickWidth);
  Line(x1, y1, x2, y2);
  SetLineStyle(SolidLn, 0, NormWidth);
end;

procedure LabXY(x, y: Integer; c: Integer; s: string);
begin
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  SetColor(c);
  OutTextXY(x, y, s);
end;

procedure Dot(x, y, c: Integer);
begin
  SetFillStyle(SolidFill, c);
  SetColor(c);
  PieSlice(x, y, 0, 360, 3);
end;

{ ---- THE FIGHTER: BREAKUP.ASM's MVERT and MFACE, the same numbers ------- }
const
  FX : array[0..12] of Integer = (0, -2, 2, -2, 2, -13, 13, 0, -2, 2, 0, 0, 0);
  FZ : array[0..12] of Integer = (16, -11, -11, -11, -11, -8, -8, 6, -11, -11, -5, -13, -11);
  FF : array[0..7, 0..3] of Byte = ((0, 1, 2, 0), (0, 3, 4, 0), (0, 1, 3, 0),
                                    (0, 2, 4, 0), (7, 5, 8, 7), (7, 6, 9, 7),
                                    (10, 11, 12, 10), (1, 2, 4, 3));

{ the fighter from above at cell (u, v), nose up the page, half a cell a
  square of the model's paper; face f drawn in colour c }
procedure FaceTop(f: Integer; u, v: Real; c: Integer; bold: Boolean);
var k, a, b : Integer;
begin
  for k := 0 to 3 do
  begin
    a := FF[f, k];  b := FF[f, (k + 1) mod 4];
    if bold then
      Thick(CX(u + FX[a] * 0.5), CY(v - FZ[a] * 0.5), CX(u + FX[b] * 0.5), CY(v - FZ[b] * 0.5), c)
    else
    begin
      SetColor(c);
      Line(CX(u + FX[a] * 0.5), CY(v - FZ[a] * 0.5), CX(u + FX[b] * 0.5), CY(v - FZ[b] * 0.5));
    end;
  end;
end;

{ ==========================================================================
   PAGE 1 - an aeroplane is already its pieces. The fighter's eight faces;
   their masses; the wing's area worked.
   ========================================================================== }
procedure PagePieces(upto: Integer);
var f : Integer;
begin
  Big(1, 1, INK, 'AN AEROPLANE IS ITS PIECES');
  Lab(1, 3, REDPEN, 'Lesson 21: the breakup. A shell, and the laws the pieces obey.');
  for f := 0 to 7 do FaceTop(f, 8, 14, PENCIL, False);
  FaceTop(4, 8, 14, PEN, True);
  FaceTop(5, 8, 14, PEN, True);
  FaceTop(6, 8, 14, GREEN, True);
  LabXY(CX(8.4), CY(5.2), PENCIL, 'nose');
  LabXY(CX(1.2), CY(19.3), PEN, 'wings');
  LabXY(CX(9.0), CY(20.5), GREEN, 'fin');
  Lab(17, 6, INK, 'Every face of the model is a PIECE:');
  Lab(18, 8, PEN, 'a centre');
  Lab(18, 9, PEN, 'four corners, from the centre');
  Lab(18, 10, PEN, 'a velocity, a mass, a spin');
  Lab(17, 12, INK, 'Flying, all eight have the same');
  Lab(17, 13, INK, 'velocity and no spin. That is all');
  Lab(17, 14, INK, '"in one piece" means.');
  if upto < 2 then Exit;

  Lab(17, 16, INK, 'THE MASS IS THE AREA: one sheet,');
  Lab(17, 17, INK, 'one thickness. The fighter:');
  Lab(18, 19, PEN, 'top, belly, two sides   54 each');
  Lab(18, 20, PEN, 'two wings               96 each');
  Lab(18, 21, PEN, 'fin 15, nozzle 16');
  Lab(18, 22, REDPEN, 'all of it              439');
  if upto < 3 then Exit;

  Lab(1, 24, INK, 'A face''s area is half the cross product of its diagonals. The wing:');
  Lab(2, 25, PEN, 'd1 = (-2, 0, -17)   d2 = (13, 0, 14)   d1 x d2 = (0, -193, 0)');
  Lab(2, 26, PEN, 'length = square root of 37249 = 193: half of it, 96');
  Lab(1, 28, PENCIL, 'The root of a double word: lesson 1D''s Newton, ten rounds from 16384.');
end;

{ ==========================================================================
   PAGE 2 - the blast. Where it strikes; the push falling with distance;
   the same push moving a small piece fast and a wing slowly.
   ========================================================================== }
procedure PageBlast(upto: Integer);
begin
  Big(1, 1, INK, 'THE BLAST: dv = J / m');
  Lab(1, 3, INK, 'The shell strikes 60 short of the centre, on the side it comes from:');
  Lab(2, 4, PEN, 'P = centre of mass - direction x 60');
  Lab(1, 6, INK, 'Each piece is pushed away from P, along d = its centre - P,');
  Lab(1, 7, INK, 'and the push falls with the distance:');
  Lab(2, 9, PEN, 's = 40920 / ((|d|/8)^2 + 64)        J = s x d');
  Lab(2, 10, PENCIL, '/8 keeps the square in a word; +64 keeps a piece AT P finite');
  if upto < 2 then Exit;

  Lab(1, 12, INK, 'The fighter, the shell from behind and right. Two pieces:');
  Lab(2, 14, PEN, 'nozzle  d = (-45,-6,42)   6x6+1+5x5 = 62, +64 = 126,  s = 324');
  Lab(2, 15, PEN, '        J = (-14580, -1944, 13608)');
  Lab(2, 17, PEN, 'wing    d = (29,2,72)     3x3+0+9x9 = 90, +64 = 154,  s = 265');
  Lab(2, 18, PEN, '        J = (7685, 530, 19080)');
  if upto < 3 then Exit;

  Lab(1, 21, INK, 'Pushes of the same size. Shared by mass:');
  Lab(2, 23, PEN, 'nozzle, 16:  J / 16 = (-911, -121, 850)');
  Lab(2, 24, PEN, 'wing,   96:  J / 96 = (80, 5, 198)');
  Lab(1, 26, REDPEN, 'A small piece flies off fast; a wing barely moves.');
  Ring(1, 26, 25);
  Lab(1, 28, PENCIL, 'velocities in 256ths of a unit a frame: 850 is over 3 a frame');
end;

{ ==========================================================================
   PAGE 3 - no net push. The sum of the blast's pushes taken out; the
   shell's momentum, the only one from outside.
   ========================================================================== }
procedure PageNoNet(upto: Integer);
begin
  Big(1, 1, INK, 'NO NET PUSH');
  Lab(1, 3, INK, 'Add up every piece''s push, as computed:');
  Lab(2, 5, PEN, 'SUM(J) = (73448, 4914, 103866)       not nothing');
  Lab(1, 7, INK, 'But a blast is the aeroplane pushing on ITSELF. Whatever it pushes');
  Lab(1, 8, INK, 'one way, it pushes back the other: the sum must be nothing.');
  if upto < 2 then Exit;

  Lab(1, 11, INK, 'So the sum is shared back out by mass, and taken off every piece:');
  Lab(2, 13, PEN, 'dv = J/m - SUM(J)/M        SUM(J)/439 = (167, 11, 236)');
  Lab(1, 15, INK, 'Times m, added over the pieces:  SUM(m dv) = SUM(J) - SUM(J) = 0.');
  Lab(1, 16, GREEN, 'Three double-word sums and three divides: ADD, ADC, IDIV.');
  if upto < 3 then Exit;

  Lab(1, 19, INK, 'The SHELL is the one push from OUTSIDE. Its momentum goes to every');
  Lab(1, 20, INK, 'piece alike per unit of mass, along its own path:');
  Lab(2, 22, PEN, 'dv += 675 x direction / M       675 x 181 / 439 = 278');
  Lab(1, 24, INK, 'The same shell moves a bomber - 2029 - less than a quarter as much.');
  Lab(1, 26, REDPEN, 'The whole moves only by what came from outside.');
  Ring(1, 26, 24);
end;
