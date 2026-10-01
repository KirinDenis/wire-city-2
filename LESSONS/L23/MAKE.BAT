@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 17, from inside DOS.
REM
REM   cd LESSONS\L23
REM   MAKE
REM
REM HOUSES.ASM is lesson 16's FILL.ASM with a town built on its ground. The
REM source travels from lesson to lesson: each one starts as a copy of the
REM last and grows. The island, the sine, the rotate, the projection and the
REM rasterizer still come out of ..\..\ENGINE - the same five files the game
REM is built from - and the walls, the roof and the windows follow
REM GAMES\OWLFLY3\SRC.
REM
REM CWSDPMI first: FASM is a 32-bit program and DOS is a 16-bit system, so
REM something has to own protected mode on its behalf. With no arguments it
REM serves exactly one program and unloads itself.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist HOUSES.ASM goto nosource

echo Assembling HOUSES.ASM ...
if exist HOUSES.COM del HOUSES.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE HOUSES.ASM HOUSES.COM
if not exist HOUSES.COM goto failed

echo.
echo Built HOUSES.COM.  Type RUN to see it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson folder - cd LESSONS\L23 - and make sure you
echo mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo HOUSES.ASM is not here. Run MAKE from LESSONS\L23.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. HOUSES.COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
