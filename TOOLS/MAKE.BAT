@echo off
REM ============================================================================
REM MAKE.BAT - assemble the model precompiler, from inside DOS.
REM
REM   cd TOOLS
REM   MAKE            ->  OBJ2DAT.COM
REM
REM OBJ2DAT turns a Wavefront .OBJ into the packed vertex/face table the games
REM load at runtime, so the 8086 never has to parse text. It is a DOS program
REM built by the same DOS toolchain as everything else here - the C# tools in
REM the subdirectories are a separate matter and build on Windows.
REM
REM   OBJ2DAT model.OBJ MODEL.DAT 4        the 4 is the scale divisor
REM
REM Run MAKE from this folder. Every path below is relative to here on
REM purpose: a path from a drive root only works if the repository happens to
REM be mounted AS a drive root.
REM
REM WHY IT LOADS CWSDPMI. FASM is a 32-bit program, DOS is a 16-bit system,
REM and something has to own protected mode on its behalf; DOSBox offers
REM nothing. CWSDPMI with no arguments stays resident for one program and
REM unloads itself again.
REM
REM   MAKE EXIT   assembles and then closes DOSBox, for MAKEWIN.BAT.
REM ============================================================================
if not exist FASM\FASM.EXE goto nofasm
if not exist OBJ2DAT.ASM goto nosource

echo Assembling OBJ2DAT.ASM ...
if exist OBJ2DAT.COM del OBJ2DAT.COM
CWSDPMI\CWSDPMI.EXE
FASM\FASM.EXE OBJ2DAT.ASM OBJ2DAT.COM
if not exist OBJ2DAT.COM goto failed
echo.
echo Built OBJ2DAT.COM
goto end

:nofasm
echo.
echo Cannot find FASM\FASM.EXE - run MAKE from the TOOLS folder.
goto end

:nosource
echo.
echo OBJ2DAT.ASM is not here. Run MAKE from TOOLS.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. OBJ2DAT.COM was not
echo written, so nothing was overwritten with a broken build.

:end
if "%1"=="EXIT" exit
