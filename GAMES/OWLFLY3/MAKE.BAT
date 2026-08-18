@echo off
REM ============================================================================
REM MAKE.BAT - assemble OWL FLY III, from inside DOS.
REM
REM   cd GAMES\OWLFLY3
REM   MAKE            ->  INSTALL\OWLFLY3.EXE and the two resource blobs
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
if not exist SRC\OWLFLY3.ASM goto nosource

REM BOTH checks after each assembly, and they catch different lies:
REM "if not exist" catches a FASM that never ran (Illegal command sets
REM no errorlevel), "if errorlevel 1" catches a FASM that DID run,
REM CREATED the file and then failed - a host-side file lock once left
REM a zero-byte EXE here and the exist check alone called it Built.
echo Assembling the cockpit blob ...
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE SRC\RESDAT.ASM INSTALL\CITY.DAT
if errorlevel 1 goto failed
if not exist INSTALL\CITY.DAT goto failed

echo Assembling the side views ...
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE SRC\SIDEDAT.ASM INSTALL\CPSIDE.DAT
if errorlevel 1 goto failed
if not exist INSTALL\CPSIDE.DAT goto failed

echo Assembling SRC\OWLFLY3.ASM ...
REM The EXE is written under a .NEW name and RENAMED into place. Writing
REM INSTALL\OWLFLY3.EXE directly kept failing on the host side - a
REM freshly created .EXE gets grabbed by the machine's scanner and
REM FASM's write dies, leaving a zero-byte file (2026-08-18, twice).
REM A .DAT never suffered it, so the fix is to not BE an .EXE while
REM being written. The del of the old EXE still happens - after the new
REM one provably exists - so a failed build can never leave yesterday's
REM binary looking like today's.
if exist INSTALL\OWLFLY3.NEW del INSTALL\OWLFLY3.NEW
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE SRC\OWLFLY3.ASM INSTALL\OWLFLY3.NEW
if errorlevel 1 goto failed
if not exist INSTALL\OWLFLY3.NEW goto failed
if exist INSTALL\OWLFLY3.EXE del INSTALL\OWLFLY3.EXE
ren INSTALL\OWLFLY3.NEW OWLFLY3.EXE
if not exist INSTALL\OWLFLY3.EXE goto failed
echo.
echo Built INSTALL\OWLFLY3.EXE.  Type RUN to fly it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from GAMES\OWLFLY3, and make sure you mounted the whole
echo repository rather than just this directory.
goto end

:nosource
echo.
echo SRC\OWLFLY3.ASM is not here. Run MAKE from GAMES\OWLFLY3.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. Nothing was
echo overwritten with a broken build.

:end
if "%1"=="EXIT" exit
