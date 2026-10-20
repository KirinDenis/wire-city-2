@echo off
REM ============================================================================
REM MAKE.BAT - assemble MULTSOKO, from inside DOS.
REM
REM   cd GAMES\MULTSOKO
REM   MAKE
REM
REM Run it from this folder: every path below is relative to here, so it does
REM not matter where the repository is mounted. CWSDPMI is loaded for FASM
REM (a 32-bit program needs a DPMI host and DOSBox has none); with no
REM arguments it stays for one program and leaves with it.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT, since a
REM               batch file started from a DOSBox -c line swallows the -c
REM               lines after it.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist MULTSOKO.ASM goto nosource

echo Assembling MULTSOKO.ASM ...
if exist MULTSOKO.COM del MULTSOKO.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE MULTSOKO.ASM MULTSOKO.COM
if not exist MULTSOKO.COM goto failed
echo.
echo Built MULTSOKO.COM.  Type RUN to play it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the game's own folder - cd GAMES\MULTSOKO - and make sure
echo you mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo MULTSOKO.ASM is not here. Run MAKE from GAMES\MULTSOKO.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. MULTSOKO.COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
