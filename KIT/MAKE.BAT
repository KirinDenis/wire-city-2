@echo off
REM ============================================================================
REM MAKE.BAT - assemble one program of the kit, from inside DOS.
REM
REM   cd KIT
REM   MAKE TEST T_VGA         TEST\T_VGA.ASM  ->  TEST\T_VGA.COM
REM   MAKE T_ARCADE T_ARCADE  a template
REM   MAKE ... EXIT           the same, then close DOSBox (for MAKEWIN.BAT)
REM
REM It goes into the folder first: the programs include ..\..\ENGINE and
REM ..\..\KIT\LIB, paths that hold from two levels below the disk's root.
REM FASM's words go to NAME.LOG beside the source.
REM ============================================================================
if not exist ..\TOOLS\FASM\FASM.EXE goto nofasm
if "%2"=="" goto usage
if not exist %1\%2.ASM goto noasm
cd %1
if exist %2.COM del %2.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE %2.ASM %2.COM > %2.LOG
cd ..
if not exist %1\%2.COM echo FAILED: %1\%2 - read %1\%2.LOG
if exist %1\%2.COM echo Built %1\%2.COM
goto done

:usage
echo Usage: MAKE FOLDER NAME   - MAKE TEST T_VGA
goto done

:noasm
echo %1\%2.ASM is not here.
goto done

:nofasm
echo ..\TOOLS\FASM\FASM.EXE is not here: run this from the KIT folder.

:done
if "%3"=="EXIT" exit
