@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 26, from inside DOS: both steps.
REM
REM   cd LESSONS\L38
REM   MAKE
REM
REM   TICK    the timer chip on its own: five seconds, the BIOS's ticks and ours
REM   CLOCK   lesson 23's flight on the 80386: double words, one divide an edge,
REM           the chip at 72.8 ticks a second, INT 8 taken, and the picture
REM           drawn between the steps of the physics
REM
REM CWSDPMI first: FASM is a 32-bit program and DOS is a 16-bit system, so
REM something has to own protected mode on its behalf. With no arguments it
REM serves exactly one program and unloads itself - so once for each.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist CLOCK.ASM goto nosource

echo Assembling TICK.ASM ...
if exist TICK.COM del TICK.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE TICK.ASM TICK.COM
if not exist TICK.COM goto failed

echo Assembling CLOCK.ASM ...
if exist CLOCK.COM del CLOCK.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE CLOCK.ASM CLOCK.COM
if not exist CLOCK.COM goto failed

echo.
echo Built TICK.COM and CLOCK.COM.  Type TICK, or RUN to fly.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson folder - cd LESSONS\L38 - and make sure you
echo mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo CLOCK.ASM is not here. Run MAKE from LESSONS\L38.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. The .COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
