@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 1A, from inside DOS.
REM
REM   cd LESSONS\L26
REM   MAKE
REM
REM LETTERS.ASM is lesson 19's AXES.ASM with OWL FLY III's own letters in it.
REM The source travels from lesson to lesson: each one starts as a copy of
REM the last and grows. The island, the sine, the rotate, the projection and
REM the rasterizer still come out of ..\..\ENGINE - the same five files the
REM game is built from - and the font is GAMES\OWLFLY3\SRC\RESDAT.ASM's.
REM
REM CWSDPMI first: FASM is a 32-bit program and DOS is a 16-bit system, so
REM something has to own protected mode on its behalf. With no arguments it
REM serves exactly one program and unloads itself.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist LETTERS.ASM goto nosource

echo Assembling LETTERS.ASM ...
if exist LETTERS.COM del LETTERS.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE LETTERS.ASM LETTERS.COM
if not exist LETTERS.COM goto failed

echo.
echo Built LETTERS.COM.  Type RUN to see it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson folder - cd LESSONS\L26 - and make sure you
echo mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo LETTERS.ASM is not here. Run MAKE from LESSONS\L26.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. LETTERS.COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
