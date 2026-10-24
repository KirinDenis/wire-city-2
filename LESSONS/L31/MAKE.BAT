@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 1F, from inside DOS.
REM
REM   cd LESSONS\L31
REM   MAKE
REM
REM MANDEL.ASM is a debt paid: lesson 1E's nozzle burned by rewriting the
REM palette, and never said how. A small program of its own - the Mandelbrot
REM set, drawn once, then set in motion by the palette alone. Only
REM ..\..\ENGINE\E_8086.INC is borrowed. Lesson 1G takes the aeroplanes of
REM lesson 1E into lesson 1D's sky.
REM
REM CWSDPMI first: FASM is a 32-bit program and DOS is a 16-bit system, so
REM something has to own protected mode on its behalf. With no arguments it
REM serves exactly one program and unloads itself.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist MANDEL.ASM goto nosource

echo Assembling MANDEL.ASM ...
if exist MANDEL.COM del MANDEL.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE MANDEL.ASM MANDEL.COM
if not exist MANDEL.COM goto failed

echo.
echo Built MANDEL.COM.  Type RUN to see it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson folder - cd LESSONS\L31 - and make sure you
echo mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo MANDEL.ASM is not here. Run MAKE from LESSONS\L31.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. MANDEL.COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
