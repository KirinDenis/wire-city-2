@echo off
REM ============================================================================
REM MAKE.BAT - assemble WIRE CITY, from inside DOS.
REM
REM   cd GAMES\WIRECITY
REM   MAKE
REM
REM Run it from this folder. Every path below is relative to here, on purpose:
REM an earlier version said \TOOLS\FASM\FASM.EXE, which only works if the
REM repository happens to be mounted AS the root of a drive. Mount the folder
REM above it instead - a perfectly normal thing to do - and every tool path
REM points at nothing. Relative paths do not care where the repository sits.
REM
REM WHY IT LOADS CWSDPMI. The assembler is a 32-bit program, DOS is a 16-bit
REM system, and something has to own protected mode on its behalf; DOSBox
REM offers nothing. CWSDPMI with no arguments stays resident FOR ONE PROGRAM
REM and unloads itself when that program exits, so it is loaded here, used by
REM FASM, and gone again. Nothing accumulates and nothing has to be set up
REM beforehand - in particular this does NOT depend on GO having been run,
REM because a file manager runs each command in its own environment and any
REM variable GO had set would already be gone.
REM
REM   MAKE EXIT   assembles and then closes DOSBox. That is for MAKEWIN.BAT,
REM               which drives this file from Windows; a batch file started
REM               from a DOSBox -c line swallows the -c lines that follow it,
REM               so the emulator has to be closed from in here or not at all.
REM               Typing MAKE by hand leaves you at the prompt, as it should.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist CITY.ASM goto nosource

echo Assembling CITY.ASM ...
if exist CITY.COM del CITY.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE CITY.ASM CITY.COM
if not exist CITY.COM goto failed
echo.
echo Built CITY.COM.  Type RUN to play it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the game's own folder - cd GAMES\WIRECITY - and make sure
echo you mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo CITY.ASM is not here. Run MAKE from GAMES\WIRECITY.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. CITY.COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
