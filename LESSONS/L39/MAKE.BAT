@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 27, from inside DOS: the three steps and FLY.
REM
REM   cd LESSONS\L39
REM   MAKE
REM
REM   FLAT1   where are we: the processor's mode, the A20 gate, HIMEM
REM   FLAT2   into protected mode and back, a megabyte written above the first
REM   FLAT3   a 32-bit program: its own clock and keys, a picture above 1 MB
REM   FLY     lesson 26's flight in protected mode: an .EXE past 64K
REM
REM CWSDPMI first: FASM is a 32-bit program and DOS is a 16-bit system, so
REM something has to own protected mode on its behalf. With no arguments it
REM serves exactly one program and unloads itself - so once for each.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist FLY.ASM goto nosource

echo Assembling FLAT1.ASM ...
if exist FLAT1.COM del FLAT1.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE FLAT1.ASM FLAT1.COM
if not exist FLAT1.COM goto failed

echo Assembling FLAT2.ASM ...
if exist FLAT2.COM del FLAT2.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE FLAT2.ASM FLAT2.COM
if not exist FLAT2.COM goto failed

echo Assembling FLAT3.ASM ...
if exist FLAT3.COM del FLAT3.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE FLAT3.ASM FLAT3.COM
if not exist FLAT3.COM goto failed

echo Assembling FLY.ASM ...
if exist FLY.EXE del FLY.EXE
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE FLY.ASM FLY.EXE
if not exist FLY.EXE goto failed

echo.
echo Built FLAT1.COM to FLAT3.COM and FLY.EXE.  Type FLAT1 ... FLAT3, or RUN to fly.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson folder - cd LESSONS\L39 - and make sure you
echo mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo FLY.ASM is not here. Run MAKE from LESSONS\L39.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. The program was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
