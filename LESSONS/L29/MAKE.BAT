@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 1D, from inside DOS.
REM
REM   cd LESSONS\L29
REM   MAKE
REM
REM WING.ASM is lesson 1C's LADDER.ASM with a wing: lift and the angle of
REM attack. The source travels from lesson to lesson: each one starts as a copy of
REM the last and grows. The island, the sine, the rotate, the projection and
REM the rasterizer still come out of ..\..\ENGINE - the same five files the
REM game is built from. The wing is this lesson's own: OWL FLY III's stick
REM turns the nose, and so did lessons 19 to 1C.
REM
REM CWSDPMI first: FASM is a 32-bit program and DOS is a 16-bit system, so
REM something has to own protected mode on its behalf. With no arguments it
REM serves exactly one program and unloads itself.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist WING.ASM goto nosource

echo Assembling WING.ASM ...
if exist WING.COM del WING.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE WING.ASM WING.COM
if not exist WING.COM goto failed

echo.
echo Built WING.COM.  Type RUN to see it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson folder - cd LESSONS\L29 - and make sure you
echo mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo WING.ASM is not here. Run MAKE from LESSONS\L29.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. WING.COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
