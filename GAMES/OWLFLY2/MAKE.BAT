@echo off
REM ============================================================================
REM MAKE.BAT - assemble OWL FLY II, from inside DOS.
REM
REM   cd GAMES\OWLFLY2
REM   MAKE            ->  INSTALL\FLYOWL2.EXE and the two resource blobs
REM
REM THREE ASSEMBLIES, and only the last is a program. SRC\RESDAT.ASM and
REM SRC\SIDEDAT.ASM are artwork, palettes and fonts laid out as bytes: they
REM assemble to plain blobs the game loads at startup, which is what leaves
REM room in the segments for the game.
REM
REM THIS ONE IS AN EXE, not a COM - the only one here. It carries five
REM segments end to end: the main one at 64K, then SKYSEG, UISEG, SYMSEG and
REM TOWNSEG, and the game works out where its back buffer goes by counting
REM paragraphs past them. Change a segment's size and everything above it
REM moves, so each ends by claiming its window with a reservation.
REM
REM Run MAKE from this folder. Every path below is relative to here on
REM purpose: a path from a drive root only works if the repository happens to
REM be mounted AS a drive root.
REM
REM WHY IT LOADS CWSDPMI. FASM is a 32-bit program, DOS is a 16-bit system,
REM and something has to own protected mode on its behalf; DOSBox offers
REM nothing. CWSDPMI with no arguments stays resident for one program and
REM unloads itself again, so it comes before each assembly.
REM
REM   MAKE EXIT   assembles and then closes DOSBox, for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist SRC\CITY.ASM goto nosource

echo Assembling the cockpit blob ...
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE SRC\RESDAT.ASM INSTALL\CITY.DAT
if not exist INSTALL\CITY.DAT goto failed

echo Assembling the side views ...
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE SRC\SIDEDAT.ASM INSTALL\CPSIDE.DAT
if not exist INSTALL\CPSIDE.DAT goto failed

echo Assembling SRC\CITY.ASM ...
if exist INSTALL\FLYOWL2.EXE del INSTALL\FLYOWL2.EXE
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE SRC\CITY.ASM INSTALL\FLYOWL2.EXE
if not exist INSTALL\FLYOWL2.EXE goto failed
echo.
echo Built INSTALL\FLYOWL2.EXE.  Type RUN to fly it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from GAMES\OWLFLY2, and make sure you mounted the whole
echo repository rather than just this directory.
goto end

:nosource
echo.
echo SRC\CITY.ASM is not here. Run MAKE from GAMES\OWLFLY2.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. Nothing was
echo overwritten with a broken build.

:end
if "%1"=="EXIT" exit
