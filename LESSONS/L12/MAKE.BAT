@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 12, from inside DOS.
REM
REM   cd LESSONS\L12
REM   MAKE
REM
REM ORBITS.ASM is the lesson: the triangle that turns the sky - the rotation
REM matrix as one routine of four IMULs, and a solar system as a six-row
REM table hung on it. SINTAB.INC (the minted sine) and DRAW12.INC (the
REM toolbox, still carrying lesson 8's line) ride beside it.
REM
REM CWSDPMI first: FASM is a 32-bit program and DOS is a 16-bit system, so
REM something has to own protected mode on its behalf. With no arguments it
REM serves exactly one program and unloads itself.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist ORBITS.ASM goto nosource

echo Assembling ORBITS.ASM ...
if exist ORBITS.COM del ORBITS.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE ORBITS.ASM ORBITS.COM
if not exist ORBITS.COM goto failed

echo.
echo Built ORBITS.COM.  Type RUN to see it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson folder - cd LESSONS\L12 - and make sure you
echo mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo ORBITS.ASM is not here. Run MAKE from LESSONS\L12.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. ORBITS.COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
