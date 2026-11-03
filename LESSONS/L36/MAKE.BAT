@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 24, from inside DOS: all four steps.
REM
REM   cd LESSONS\L36
REM   MAKE
REM
REM CPU1 to CPU4 are one program growing: each is the one before it and a
REM little more, so each can be read and run on its own.
REM
REM   CPU1   the flags register, as it is
REM   CPU2   write into it and read back: 8086, 286 or 386
REM   CPU3   the 32-bit EFLAGS: 386 or 486
REM   CPU4   CPUID: the processor says its own name
REM
REM CWSDPMI first: FASM is a 32-bit program and DOS is a 16-bit system, so
REM something has to own protected mode on its behalf. With no arguments it
REM serves exactly one program and unloads itself - so once for each.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist CPU1.ASM goto nosource

echo Assembling CPU1.ASM ...
if exist CPU1.COM del CPU1.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE CPU1.ASM CPU1.COM
if not exist CPU1.COM goto failed

echo Assembling CPU2.ASM ...
if exist CPU2.COM del CPU2.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE CPU2.ASM CPU2.COM
if not exist CPU2.COM goto failed

echo Assembling CPU3.ASM ...
if exist CPU3.COM del CPU3.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE CPU3.ASM CPU3.COM
if not exist CPU3.COM goto failed

echo Assembling CPU4.ASM ...
if exist CPU4.COM del CPU4.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE CPU4.ASM CPU4.COM
if not exist CPU4.COM goto failed

echo.
echo Built CPU1.COM to CPU4.COM.  Type RUN 1 ... RUN 4.
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson folder - cd LESSONS\L36 - and make sure you
echo mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo CPU1.ASM is not here. Run MAKE from LESSONS\L36.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. The .COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
