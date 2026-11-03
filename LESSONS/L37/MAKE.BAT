@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 25, from inside DOS: all four steps.
REM
REM   cd LESSONS\L37
REM   MAKE
REM
REM R1 to R4 are one program growing: each is the one before it and a
REM little more, so each can be read and run on its own.
REM
REM   R1   the registers: 32 bits, the low half keeps its 8086 name
REM   R2   the addresses: any register, times 1, 2, 4 or 8
REM   R3   the new instructions: one where the 8086 needed several
REM   R4   what did not change: one address an instruction
REM
REM CWSDPMI first: FASM is a 32-bit program and DOS is a 16-bit system, so
REM something has to own protected mode on its behalf. With no arguments it
REM serves exactly one program and unloads itself - so once for each.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist R1.ASM goto nosource

echo Assembling R1.ASM ...
if exist R1.COM del R1.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE R1.ASM R1.COM
if not exist R1.COM goto failed

echo Assembling R2.ASM ...
if exist R2.COM del R2.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE R2.ASM R2.COM
if not exist R2.COM goto failed

echo Assembling R3.ASM ...
if exist R3.COM del R3.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE R3.ASM R3.COM
if not exist R3.COM goto failed

echo Assembling R4.ASM ...
if exist R4.COM del R4.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE R4.ASM R4.COM
if not exist R4.COM goto failed

echo.
echo Built R1.COM to R4.COM.  Type RUN 1 ... RUN 4.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson folder - cd LESSONS\L37 - and make sure you
echo mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo R1.ASM is not here. Run MAKE from LESSONS\L37.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. The .COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
