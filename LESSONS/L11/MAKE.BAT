@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 11, from inside DOS.
REM
REM   cd LESSONS\L11
REM   MAKE
REM
REM KEYS.ASM is the lesson: the keyboard is a computer. The wire's scan
REM codes at port 60h, the BIOS floor with its 16-cell buffer, the DOS
REM floor with its free line editor - and then our own INT 9, a KEYS
REM table, and a square that drives diagonally because two keys can be
REM HELD at once. DRAW11.INC (the toolbox, carrying lesson 8's PutB)
REM rides beside it.
REM
REM CWSDPMI first: FASM is a 32-bit program and DOS is a 16-bit system, so
REM something has to own protected mode on its behalf. With no arguments it
REM serves exactly one program and unloads itself.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist KEYS.ASM goto nosource

echo Assembling KEYS.ASM ...
if exist KEYS.COM del KEYS.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE KEYS.ASM KEYS.COM
if not exist KEYS.COM goto failed

echo.
echo Built KEYS.COM.  Type RUN to see it.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson folder - cd LESSONS\L11 - and make sure you
echo mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo KEYS.ASM is not here. Run MAKE from LESSONS\L11.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. KEYS.COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
