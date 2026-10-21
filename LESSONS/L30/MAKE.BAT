@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 1E, from inside DOS.
REM
REM   cd LESSONS\L30
REM   MAKE
REM
REM HANGAR.ASM is a break from the flight: a small program of its own, the
REM aeroplanes of OWL FLY III on a stand, turning - EXAMPLES\JET.ASM without
REM the explosion, and with W, which shows the points and their numbers. The
REM sine, the projection and the face fill come out of ..\..\ENGINE, as in
REM every lesson. Lesson 1F takes these aeroplanes into lesson 1D's sky.
REM
REM CWSDPMI first: FASM is a 32-bit program and DOS is a 16-bit system, so
REM something has to own protected mode on its behalf. With no arguments it
REM serves exactly one program and unloads itself.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist HANGAR.ASM goto nosource

echo Assembling HANGAR.ASM ...
if exist HANGAR.COM del HANGAR.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE HANGAR.ASM HANGAR.COM
if not exist HANGAR.COM goto failed

echo.
echo Built HANGAR.COM.  Type RUN to see it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson folder - cd LESSONS\L30 - and make sure you
echo mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo HANGAR.ASM is not here. Run MAKE from LESSONS\L30.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. HANGAR.COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
