@echo off
REM ============================================================================
REM MAKE.BAT - assemble NEWTON, from inside DOS.
REM
REM   cd GAMES\NEWTON
REM   MAKE                       ->  NEWTON.COM
REM
REM The source is in SRC\ and the binary lands here, beside this file, because
REM that is where you run it from.
REM
REM Run MAKE from this folder. Every path below is relative to here on
REM purpose: a path from a drive root only works if the repository happens to
REM be mounted AS a drive root, and mounting the folder above it - a perfectly
REM ordinary thing to do - would leave every tool path pointing at nothing.
REM
REM WHY IT LOADS CWSDPMI. The assembler is a 32-bit program, DOS is a 16-bit
REM system, and something has to own protected mode on its behalf; DOSBox
REM offers nothing. CWSDPMI with no arguments stays resident for one program
REM and unloads itself when that program exits.
REM
REM   MAKE EXIT   assembles and then closes DOSBox. That is for MAKEWIN.BAT;
REM               a batch started from a DOSBox -c line swallows the -c lines
REM               after it, so the emulator has to close itself from in here.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist SRC\NEWTON.ASM goto nosource

echo Assembling SRC\NEWTON.ASM ...
if exist NEWTON.COM del NEWTON.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE SRC\NEWTON.ASM NEWTON.COM
if not exist NEWTON.COM goto failed
echo.
echo Built NEWTON.COM.  Type RUN to fly it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from GAMES\NEWTON, and make sure you mounted the whole
echo repository rather than just this directory.
goto end

:nosource
echo.
echo SRC\NEWTON.ASM is not here. Run MAKE from GAMES\NEWTON.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. NEWTON.COM was not
echo written, so nothing was overwritten with a broken build.

:end
if "%1"=="EXIT" exit
