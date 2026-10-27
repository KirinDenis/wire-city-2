@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 20, from inside DOS.
REM
REM   cd LESSONS\L32
REM   MAKE
REM
REM TRAFFIC.ASM is lesson 1D's WING.ASM with traffic: lesson 1E's five
REM aeroplanes fly round you, and F4 takes the eye outside to circle them -
REM OWL FLY III's orbit camera. The source travels from lesson to lesson:
REM each one starts as a copy of the last and grows. The island, the sine,
REM the rotate, the projection and the rasterizer still come out of
REM ..\..\ENGINE - the same five files the game is built from.
REM
REM CWSDPMI first: FASM is a 32-bit program and DOS is a 16-bit system, so
REM something has to own protected mode on its behalf. With no arguments it
REM serves exactly one program and unloads itself.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist TRAFFIC.ASM goto nosource

echo Assembling TRAFFIC.ASM ...
if exist TRAFFIC.COM del TRAFFIC.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE TRAFFIC.ASM TRAFFIC.COM
if not exist TRAFFIC.COM goto failed

echo.
echo Built TRAFFIC.COM.  Type RUN to see it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson folder - cd LESSONS\L32 - and make sure you
echo mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo TRAFFIC.ASM is not here. Run MAKE from LESSONS\L32.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. TRAFFIC.COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
