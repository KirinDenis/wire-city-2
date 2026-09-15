@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 11, from inside DOS.
REM
REM   cd LESSONS\L17
REM   MAKE
REM
REM TERRAIN.ASM is the whole lesson and it includes nothing: the generator,
REM the random numbers it eats and the map it paints are all in the one file,
REM because the point of this lesson is that a landscape is a short program.
REM The game's own copy of the same arithmetic lives in ENGINE\E_TERR.INC.
REM
REM CWSDPMI first: FASM is a 32-bit program and DOS is a 16-bit system, so
REM something has to own protected mode on its behalf. With no arguments it
REM serves exactly one program and unloads itself.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist TERRAIN.ASM goto nosource

echo Assembling TERRAIN.ASM ...
if exist TERRAIN.COM del TERRAIN.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE TERRAIN.ASM TERRAIN.COM
if not exist TERRAIN.COM goto failed

echo.
echo Built TERRAIN.COM.  Type RUN to see it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson folder - cd LESSONS\L17 - and make sure you
echo mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo TERRAIN.ASM is not here. Run MAKE from LESSONS\L17.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. TERRAIN.COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
