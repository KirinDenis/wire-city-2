@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 21, from inside DOS.
REM
REM   cd LESSONS\L33
REM   MAKE
REM
REM BREAKUP.ASM is a test stand of its own, as lesson 1E's hangar was: an
REM aeroplane is hit by a shell and comes apart, and every piece obeys the
REM same few laws - its mass is its area, the blast pushes it by mass, the
REM pushes sum to nothing, the shell brings the only momentum from outside.
REM The sine, the lens and the face fill come out of ..\..\ENGINE.
REM
REM CWSDPMI first: FASM is a 32-bit program and DOS is a 16-bit system, so
REM something has to own protected mode on its behalf. With no arguments it
REM serves exactly one program and unloads itself.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist BREAKUP.ASM goto nosource

echo Assembling BREAKUP.ASM ...
if exist BREAKUP.COM del BREAKUP.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE BREAKUP.ASM BREAKUP.COM
if not exist BREAKUP.COM goto failed

echo.
echo Built BREAKUP.COM.  Type RUN to see it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson folder - cd LESSONS\L33 - and make sure you
echo mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo BREAKUP.ASM is not here. Run MAKE from LESSONS\L33.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. BREAKUP.COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
