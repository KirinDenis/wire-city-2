@echo off
REM ============================================================================
REM MAKE.BAT - assemble the story engine, from inside DOS.
REM
REM   cd LAB\OWLFLY4\ENGINE
REM   MAKE              assemble STORY.COM
REM   MAKE EXIT         assemble, then close DOSBox (for MAKEWIN.BAT)
REM
REM Run it from this folder. Every path below is relative to here on purpose:
REM a path from a drive root only works if the repository happens to be
REM mounted AS a drive root. The engine includes ..\VIDEO\OWV.INC and
REM ..\VIDEO\SB.INC - the same decoder and sound clock the workbench uses.
REM
REM WHY IT LOADS CWSDPMI. The assembler is a 32-bit program, DOS is a 16-bit
REM system, and something has to own protected mode on its behalf; DOSBox
REM offers nothing. CWSDPMI with no arguments stays resident FOR ONE PROGRAM
REM and unloads itself when that program exits.
REM ============================================================================
if not exist ..\..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist STORY.ASM goto nosource
echo Assembling STORY.ASM ...
if exist STORY.COM del STORY.COM
..\..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\..\TOOLS\FASM\FASM.EXE STORY.ASM STORY.COM > BUILD.LOG
type BUILD.LOG
if not exist STORY.COM goto failed
echo Built STORY.COM
goto done

:nofasm
echo.
echo Cannot find ..\..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from LAB\OWLFLY4\ENGINE, and make sure you mounted the whole
echo repository rather than just this directory.
goto done

:nosource
echo.
echo STORY.ASM is not here.
goto done

:failed
echo.
echo Assembly failed - the reason is printed just above. STORY.COM was not
echo written, so nothing was overwritten with a broken build.

:done
if "%1"=="EXIT" exit
