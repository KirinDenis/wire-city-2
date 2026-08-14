@echo off
REM ============================================================================
REM MAKE.BAT - assemble lesson 3, from inside DOS.
REM
REM   cd LESSONS\L03
REM   MAKE
REM   RUN
REM
REM One source and one program: PIXEL.COM draws seven frames, a key between
REM each. Nothing else is needed - there is no library to link against,
REM because on this machine there is no library.
REM
REM Paths are relative on purpose: mount the folder ABOVE the repository - a
REM perfectly normal thing to do - and any absolute \TOOLS\... path points at
REM nothing.
REM
REM CWSDPMI is loaded first because FASM is a 32-bit program and DOS is not.
REM With no arguments it stays resident for exactly one program and unloads
REM itself when that program exits, so nothing accumulates.
REM
REM   MAKE EXIT   assemble and then close DOSBox, for MAKEWIN.BAT. A batch
REM               file started from a DOSBox -c line swallows the -c lines
REM               after it, so the emulator has to be closed from in here.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist PIXEL.ASM goto nosource

if exist PIXEL.COM del PIXEL.COM

echo Assembling PIXEL.ASM ...
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE PIXEL.ASM PIXEL.COM
if not exist PIXEL.COM goto failed

echo.
echo Built PIXEL.COM.  Type RUN. A key moves on, Esc leaves early:
echo.
echo    1 a dot           2 every colour      3 black
echo    4 two lines       5 an outline        6 a filled square
echo    7 two hundred of them
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the lesson's own folder - cd LESSONS\L03 - and make sure
echo you mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo PIXEL.ASM is not here. Run MAKE from LESSONS\L03.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. Nothing was
echo overwritten with a broken build.
:end
if "%1"=="EXIT" exit
