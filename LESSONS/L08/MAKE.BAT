@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 8, from inside DOS.
REM
REM   cd LESSONS\L08
REM   MAKE
REM
REM SLANT.ASM is the lesson: the program that rewrites itself - what JIT
REM was called in 1986 - and the slanted lines that earn their speed by it.
REM
REM CWSDPMI first: FASM is a 32-bit program and DOS is a 16-bit system, so
REM something has to own protected mode on its behalf. With no arguments it
REM serves exactly one program and unloads itself, so it is loaded once per
REM assembly below.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist SLANT.ASM goto nosource

echo Assembling SLANT.ASM ...
if exist SLANT.COM del SLANT.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE SLANT.ASM SLANT.COM
if not exist SLANT.COM goto failed

echo.
echo Built SLANT.COM.  Type RUN to see it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson folder - cd LESSONS\L08 - and make sure you
echo mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo SLANT.ASM is not here. Run MAKE from LESSONS\L08.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. SLANT.COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
