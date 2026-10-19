@echo off
REM ============================================================================
REM MAKE.BAT - assemble SOKOBAN, from inside DOS.
REM
REM   cd GAMES\SOKOBAN
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
if not exist SOKOBAN.ASM goto nosource

echo Assembling SOKOBAN.ASM ...
if exist SOKOBAN.COM del SOKOBAN.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE SOKOBAN.ASM SOKOBAN.COM
if not exist SOKOBAN.COM goto failed
echo.
echo Built SOKOBAN.COM.  Type RUN to play it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the game's own folder - cd GAMES\SOKOBAN - and make sure
echo you mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo SOKOBAN.ASM is not here. Run MAKE from GAMES\SOKOBAN.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. SOKOBAN.COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
