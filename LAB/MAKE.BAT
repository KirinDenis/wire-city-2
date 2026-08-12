@echo off
REM ============================================================================
REM MAKE.BAT - assemble the house lab, from inside DOS.
REM
REM   cd LAB
REM   MAKE            ->  HOUSE.COM
REM
REM Run it from this folder. Every path below is relative to here on purpose:
REM a path from a drive root only works if the repository happens to be
REM mounted AS a drive root, and mounting the folder above it - a perfectly
REM ordinary thing to do - would leave every tool path pointing at nothing.
REM
REM WHY IT LOADS CWSDPMI. The assembler is a 32-bit program, DOS is a 16-bit
REM system, and something has to own protected mode on its behalf; DOSBox
REM offers nothing. CWSDPMI with no arguments stays resident FOR ONE PROGRAM
REM and unloads itself when that program exits.
REM
REM   MAKE EXIT   assembles and then closes DOSBox. That is for MAKEWIN.BAT,
REM               which drives this file from Windows; a batch started from a
REM               DOSBox -c line swallows the -c lines that follow it, so the
REM               emulator has to be closed from in here or not at all.
REM ============================================================================
if not exist ..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist HOUSE.ASM goto nosource

echo Assembling HOUSE.ASM ...
if exist HOUSE.COM del HOUSE.COM
..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\TOOLS\FASM\FASM.EXE HOUSE.ASM HOUSE.COM
if not exist HOUSE.COM goto failed
echo.
echo Built HOUSE.COM.  Type RUN to walk round it.
goto end

:nofasm
echo.
echo Cannot find ..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the LAB folder, and make sure you mounted the whole
echo repository rather than just this directory.
goto end

:nosource
echo.
echo HOUSE.ASM is not here. Run MAKE from LAB.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. HOUSE.COM was not
echo written, so nothing was overwritten with a broken build.

:end
if "%1"=="EXIT" exit
