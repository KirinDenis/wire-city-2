@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 23, from inside DOS: BOTH programs.
REM
REM   cd LESSONS\L35
REM   MAKE
REM
REM MUL.ASM is lesson 22's GUNS.ASM with a meter in it: M counts the
REM multiplies and divides of one frame. NOMUL.ASM is the same flight with
REM the costly instructions taken out of its busiest places. Two programs,
REM so each can be read on its own and flown on its own.
REM
REM CWSDPMI first: FASM is a 32-bit program and DOS is a 16-bit system, so
REM something has to own protected mode on its behalf. With no arguments it
REM serves exactly one program and unloads itself - so once for each.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist MUL.ASM goto nosource
if not exist NOMUL.ASM goto nosource

echo Assembling MUL.ASM ...
if exist MUL.COM del MUL.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE MUL.ASM MUL.COM
if not exist MUL.COM goto failed

echo Assembling NOMUL.ASM ...
if exist NOMUL.COM del NOMUL.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE NOMUL.ASM NOMUL.COM
if not exist NOMUL.COM goto failed

echo.
echo Built MUL.COM and NOMUL.COM.  Type RUN MUL or RUN NOMUL.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson folder - cd LESSONS\L35 - and make sure you
echo mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo MUL.ASM or NOMUL.ASM is not here. Run MAKE from LESSONS\L35.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. The .COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
