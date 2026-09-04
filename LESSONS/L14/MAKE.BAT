@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 0E, from inside DOS.
REM
REM   cd LESSONS\L14
REM   MAKE
REM
REM CUBE.ASM is the lesson: a robot arm as one four-row table, where every
REM link inherits its parent's place AND its turn - and because every joint
REM here turns about the same axis, that inheritance is one ADD. SINTAB.INC
REM (the minted sine, unchanged since lesson 10) and DRAW14.INC (the toolbox,
REM still carrying lesson 8's line) ride beside it.
REM
REM CWSDPMI first: FASM is a 32-bit program and DOS is a 16-bit system, so
REM something has to own protected mode on its behalf. With no arguments it
REM serves exactly one program and unloads itself.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist CUBE.ASM goto nosource

echo Assembling CUBE.ASM ...
if exist CUBE.COM del CUBE.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE CUBE.ASM CUBE.COM
if not exist CUBE.COM goto failed

echo.
echo Built CUBE.COM.  Type RUN to see it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson folder - cd LESSONS\L14 - and make sure you
echo mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo CUBE.ASM is not here. Run MAKE from LESSONS\L14.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. CUBE.COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
