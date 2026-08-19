@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 7, from inside DOS.
REM
REM   cd LESSONS\L07
REM   MAKE
REM
REM LINE.ASM is the lesson: memory is one line, and the screen is not.
REM It explains itself on the text screen and then draws on the graphics one,
REM which is the same arithmetic twice with a different fold.
REM
REM CWSDPMI first: FASM is a 32-bit program and DOS is a 16-bit system, so
REM something has to own protected mode on its behalf. With no arguments it
REM serves exactly one program and unloads itself, so it is loaded once per
REM assembly below.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist LINE.ASM goto nosource

echo Assembling LINE.ASM ...
if exist LINE.COM del LINE.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE LINE.ASM LINE.COM
if not exist LINE.COM goto failed

echo.
echo Built LINE.COM.  Type RUN to see it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson folder - cd LESSONS\L07 - and make sure you
echo mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo LINE.ASM is not here. Run MAKE from LESSONS\L07.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. LINE.COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
