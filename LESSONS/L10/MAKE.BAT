@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 10, from inside DOS.
REM
REM   cd LESSONS\L10
REM   MAKE
REM
REM SQUARE.ASM is the lesson: the square that is not there - four radius
REM vectors, their tips named vertices, joined into edges, turned, moved
REM and scaled. SINTAB.INC (the minted sine) and DRAW10.INC (the toolbox,
REM carrying lesson 8's line) ride beside it.
REM
REM CWSDPMI first: FASM is a 32-bit program and DOS is a 16-bit system, so
REM something has to own protected mode on its behalf. With no arguments it
REM serves exactly one program and unloads itself.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist SQUARE.ASM goto nosource

echo Assembling SQUARE.ASM ...
if exist SQUARE.COM del SQUARE.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE SQUARE.ASM SQUARE.COM
if not exist SQUARE.COM goto failed

echo.
echo Built SQUARE.COM.  Type RUN to see it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson folder - cd LESSONS\L10 - and make sure you
echo mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo SQUARE.ASM is not here. Run MAKE from LESSONS\L10.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. SQUARE.COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
