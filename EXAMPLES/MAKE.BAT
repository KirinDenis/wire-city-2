@echo off
REM ============================================================================
REM MAKE.BAT - assemble the teaching machines, from inside DOS.
REM
REM   cd EXAMPLES
REM   MAKE            all thirteen
REM   MAKE JET        just that one
REM
REM Run it from this folder. Every path below is relative to here on purpose:
REM a path from a drive root only works if the repository happens to be
REM mounted AS a drive root, and mounting the folder above it - a perfectly
REM ordinary thing to do - would leave every tool path pointing at nothing.
REM
REM WHY IT LOADS CWSDPMI. The assembler is a 32-bit program, DOS is a 16-bit
REM system, and something has to own protected mode on its behalf; DOSBox
REM offers nothing. CWSDPMI with no arguments stays resident FOR ONE PROGRAM
REM and unloads itself when that program exits, so it is loaded once per
REM assembly rather than once at the top.
REM
REM WHY IT CALLS ITSELF. DOS has no subroutines in a batch file - CALL :label
REM is a Windows invention, and so is FOR - so the way to run the same three
REM lines thirteen times is to CALL this file again with a name. One level
REM deep, which DOS has managed since 3.3.
REM
REM   MAKE ... EXIT   assembles and then closes DOSBox. That is for
REM                   MAKEWIN.BAT, which drives this file from Windows; a
REM                   batch started from a DOSBox -c line swallows the -c
REM                   lines after it, so the emulator has to close itself
REM                   from in here or not at all.
REM ============================================================================
if not exist ..\TOOLS\FASM\FASM.EXE goto nofasm
if "%1"=="" goto all
if "%1"=="EXIT" goto all
goto one

:all
call MAKE.BAT TERRA
call MAKE.BAT RING
call MAKE.BAT SPOOL
call MAKE.BAT FLIGHT
call MAKE.BAT LAND
call MAKE.BAT LNDPHYS
call MAKE.BAT TKOFF
call MAKE.BAT TKPHYS
call MAKE.BAT SMOKE
call MAKE.BAT AVIO
call MAKE.BAT JET
call MAKE.BAT SOLO
call MAKE.BAT BBS
echo.
echo Done. Type RUN and a name - RUN JET - to run one of them.
goto done

:one
if not exist %1.ASM goto noasm
echo Assembling %1.ASM ...
if exist %1.COM del %1.COM
..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\TOOLS\FASM\FASM.EXE %1.ASM %1.COM
if not exist %1.COM goto failed
goto done

:noasm
if exist %1 goto withext
echo.
echo %1.ASM is not here. The thirteen are TERRA RING SPOOL FLIGHT LAND
echo LNDPHYS TKOFF TKPHYS SMOKE AVIO JET SOLO BBS.
goto done

REM You typed a real file, just with its extension on - which is what Tab
REM completion gives you. DOS batch cannot take an extension off an argument,
REM so it has to be said rather than fixed.
:withext
echo.
echo Give the name on its own, with no extension - MAKE SMOKE, not %1.
goto done

:nofasm
echo.
echo Cannot find ..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the EXAMPLES folder, and make sure you mounted the whole
echo repository rather than just this directory.
goto done

:failed
echo.
echo %1 failed to assemble - the reason is printed just above. Its COM file
echo was not written, so nothing was overwritten with a broken build.

:done
if "%1"=="EXIT" exit
if "%2"=="EXIT" exit
