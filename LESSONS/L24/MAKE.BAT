@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 18, from inside DOS.
REM
REM   cd LESSONS\L24
REM   MAKE
REM
REM FORCES.ASM is lesson 17's HOUSES.ASM with OWL FLY III's forces in it. The
REM source travels from lesson to lesson: each one starts as a copy of the
REM last and grows. The island, the sine, the rotate, the projection and the
REM rasterizer still come out of ..\..\ENGINE - the same five files the game
REM is built from - and the forces follow INPUT in
REM GAMES\OWLFLY3\SRC\FLIGHT.INC.
REM
REM CWSDPMI first: FASM is a 32-bit program and DOS is a 16-bit system, so
REM something has to own protected mode on its behalf. With no arguments it
REM serves exactly one program and unloads itself.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist FORCES.ASM goto nosource

echo Assembling FORCES.ASM ...
if exist FORCES.COM del FORCES.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE FORCES.ASM FORCES.COM
if not exist FORCES.COM goto failed

echo.
echo Built FORCES.COM.  Type RUN to see it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson folder - cd LESSONS\L24 - and make sure you
echo mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo FORCES.ASM is not here. Run MAKE from LESSONS\L24.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. FORCES.COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
