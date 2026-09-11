@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 10, from inside DOS.
REM
REM   cd LESSONS\L16
REM   MAKE
REM
REM CAM.ASM is the lesson: there is no camera - the world moves instead.
REM link inherits its parent's place AND its turn - and because every joint
REM here turns about the same axis, that inheritance is one ADD. SINTAB.INC
REM (the minted sine, unchanged since lesson 10) and DRAW16.INC (the toolbox,
REM still carrying lesson 8's line) ride beside it.
REM
REM CWSDPMI first: FASM is a 32-bit program and DOS is a 16-bit system, so
REM something has to own protected mode on its behalf. With no arguments it
REM serves exactly one program and unloads itself.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist CAM.ASM goto nosource

echo Assembling CAM.ASM ...
if exist CAM.COM del CAM.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE CAM.ASM CAM.COM
if not exist CAM.COM goto failed

echo.
echo Built CAM.COM.  Type RUN to see it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson folder - cd LESSONS\L16 - and make sure you
echo mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo CAM.ASM is not here. Run MAKE from LESSONS\L16.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. CAM.COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
