@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 1B, from inside DOS.
REM
REM   cd LESSONS\L27
REM   MAKE
REM
REM TAPES.ASM is lesson 1A's LETTERS.ASM with OWL FLY III's HUD tapes in it.
REM The source travels from lesson to lesson: each one starts as a copy of
REM the last and grows. The island, the sine, the rotate, the projection and
REM the rasterizer still come out of ..\..\ENGINE - the same five files the
REM game is built from - and the tapes follow HUDBARS in
REM GAMES\OWLFLY3\SRC\HUD.INC.
REM
REM CWSDPMI first: FASM is a 32-bit program and DOS is a 16-bit system, so
REM something has to own protected mode on its behalf. With no arguments it
REM serves exactly one program and unloads itself.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist TAPES.ASM goto nosource

echo Assembling TAPES.ASM ...
if exist TAPES.COM del TAPES.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE TAPES.ASM TAPES.COM
if not exist TAPES.COM goto failed

echo.
echo Built TAPES.COM.  Type RUN to see it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson folder - cd LESSONS\L27 - and make sure you
echo mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo TAPES.ASM is not here. Run MAKE from LESSONS\L27.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. TAPES.COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
