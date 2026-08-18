@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 6, from inside DOS.
REM
REM   cd LESSONS\L06
REM   MAKE
REM
REM CLOCK.ASM is the lesson: the radius vector, and ten clocks made of it.
REM CIRCLE.ASM and PIVOT.ASM are kept beside it - the midpoint circle and the
REM turning square - and are built too, so nothing in the folder rots.
REM
REM CWSDPMI first: FASM is a 32-bit program and DOS is a 16-bit system, so
REM something has to own protected mode on its behalf. With no arguments it
REM serves exactly one program and unloads itself, so it is loaded once per
REM assembly below.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist CLOCK.ASM goto nosource

echo Assembling CLOCK.ASM ...
if exist CLOCK.COM del CLOCK.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE CLOCK.ASM CLOCK.COM
if not exist CLOCK.COM goto failed

echo Assembling CIRCLE.ASM ...
if exist CIRCLE.COM del CIRCLE.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE CIRCLE.ASM CIRCLE.COM

echo Assembling PIVOT.ASM ...
if exist PIVOT.COM del PIVOT.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE PIVOT.ASM PIVOT.COM

echo.
echo Built CLOCK.COM.  Type RUN to see it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson folder - cd LESSONS\L06 - and make sure you
echo mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo CLOCK.ASM is not here. Run MAKE from LESSONS\L06.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. CLOCK.COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
