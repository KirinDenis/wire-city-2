@echo off
REM ============================================================================
REM MAKE.BAT - assemble the video workbench, from inside DOS.
REM
REM   cd LAB\OWLFLY4\VIDEO
REM   MAKE              assemble everything here
REM   MAKE VESATEST     assemble just that one
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
REM   MAKE EXIT   assembles and then closes DOSBox. That is for MAKEWIN.BAT:
REM               a batch started from a DOSBox -c line swallows the -c lines
REM               that follow it, so the emulator has to close from in here.
REM
REM There is no CALL :label and no FOR in COMMAND.COM - both are cmd.exe
REM inventions. To build several programs the batch calls ITSELF with a name.
REM ============================================================================
if not exist ..\..\..\TOOLS\FASM\FASM.EXE goto nofasm
if "%1"=="VESATEST" goto one
if "%1"=="PLAYER" goto one

REM ---- no name given: build the lot ----
call MAKE.BAT VESATEST
call MAKE.BAT PLAYER
goto done

:one
if not exist %1.ASM goto nosource
echo Assembling %1.ASM ...
if exist %1.COM del %1.COM
..\..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
REM The assembler's own words go to BUILD.LOG as well as the screen. DOSBox
REM started with -noconsole takes its window away with it when MAKEWIN closes
REM it, and a build that failed for a reason nobody saw is the worst kind.
..\..\..\TOOLS\FASM\FASM.EXE %1.ASM %1.COM > BUILD.LOG
type BUILD.LOG
if not exist %1.COM goto failed
echo Built %1.COM
goto end

:nofasm
echo.
echo Cannot find ..\..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from LAB\OWLFLY4\VIDEO, and make sure you mounted the whole
echo repository rather than just this directory.
goto done

:nosource
echo.
echo %1.ASM is not here.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. %1.COM was not
echo written, so nothing was overwritten with a broken build.
goto end

:done
if "%1"=="EXIT" exit
:end
