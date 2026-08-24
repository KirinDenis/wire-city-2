@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 9, from inside DOS.
REM
REM   cd LESSONS\L09
REM   MAKE
REM
REM SMC.ASM is the lesson: self-modifying code - the opening titles'
REM little program, placed at the very addresses the titles drew, run live.
REM
REM CWSDPMI first: FASM is a 32-bit program and DOS is a 16-bit system, so
REM something has to own protected mode on its behalf. With no arguments it
REM serves exactly one program and unloads itself, so it is loaded once per
REM assembly below.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist SMC.ASM goto nosource

echo Assembling SMC.ASM ...
if exist SMC.COM del SMC.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE SMC.ASM SMC.COM
if not exist SMC.COM goto failed

echo.
echo Built SMC.COM.  Type RUN to see it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson folder - cd LESSONS\L09 - and make sure you
echo mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo SMC.ASM is not here. Run MAKE from LESSONS\L09.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. SMC.COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
