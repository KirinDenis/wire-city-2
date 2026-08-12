@echo off
REM ============================================================================
REM MAKE.BAT - assemble OWL FLY, from inside DOS.
REM
REM   cd GAMES\OWLFLY
REM   MAKE            ->  INSTALL\FLYOWL.COM  and  INSTALL\CITY.DAT
REM
REM TWO ASSEMBLIES, and they are not alternatives. SRC\RESDAT.ASM is not a
REM program at all: it is the cockpit artwork, the palette and the font laid
REM out as bytes, assembled into a plain blob and shipped as CITY.DAT, which
REM the game loads at startup. Keeping it out of the game's own image is what
REM leaves room in the 64K segment for the game.
REM
REM Run MAKE from this folder. Every path below is relative to here on
REM purpose: a path from a drive root only works if the repository happens to
REM be mounted AS a drive root, and mounting the folder above it - a perfectly
REM ordinary thing to do - would leave every tool path pointing at nothing.
REM
REM WHY IT LOADS CWSDPMI. FASM is a 32-bit program, DOS is a 16-bit system,
REM and something has to own protected mode on its behalf; DOSBox offers
REM nothing. CWSDPMI with no arguments stays resident for one program and
REM unloads itself again, so it is loaded once per assembly.
REM
REM   MAKE EXIT   assembles and then closes DOSBox, for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist SRC\CITY.ASM goto nosource

echo Assembling the resource blob ...
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE SRC\RESDAT.ASM INSTALL\CITY.DAT
if not exist INSTALL\CITY.DAT goto failed

echo Assembling SRC\CITY.ASM ...
if exist INSTALL\FLYOWL.COM del INSTALL\FLYOWL.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE SRC\CITY.ASM INSTALL\FLYOWL.COM
if not exist INSTALL\FLYOWL.COM goto failed
echo.
echo Built INSTALL\FLYOWL.COM.  Type RUN to fly it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from GAMES\OWLFLY, and make sure you mounted the whole
echo repository rather than just this directory.
goto end

:nosource
echo.
echo SRC\CITY.ASM is not here. Run MAKE from GAMES\OWLFLY.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. Nothing was
echo overwritten with a broken build.

:end
if "%1"=="EXIT" exit
