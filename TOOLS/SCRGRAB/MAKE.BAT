@echo off
REM ============================================================================
REM MAKE.BAT - assemble SCRGRAB, from inside DOS.
REM
REM   cd TOOLS\SCRGRAB
REM   MAKE
REM
REM Every path here is relative to this folder, so it does not matter where in
REM a drive the repository was mounted.
REM
REM CWSDPMI first: FASM is a 32-bit program and something has to own protected
REM mode for it. With no arguments CWSDPMI serves exactly one program and
REM unloads itself when that program exits.
REM
REM   MAKE EXIT   assembles and then closes DOSBox, for MAKEWIN.BAT. Typed by
REM               hand, MAKE leaves you at the prompt.
REM ============================================================================
if not exist ..\..\TOOLS\FASM\FASM.EXE goto nofasm
if not exist SCRGRAB.ASM goto nosource

echo Assembling SCRGRAB.ASM ...
if exist SCRGRAB.COM del SCRGRAB.COM
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE SCRGRAB.ASM SCRGRAB.COM
if not exist SCRGRAB.COM goto failed
echo.
echo Built SCRGRAB.COM.
echo   SCRGRAB      go resident - both Shift keys capture the screen
echo   SCRGRAB /U   write SHOT00.BIN.. and unload
goto end

:nofasm
echo.
echo Cannot find ..\..\TOOLS\FASM\FASM.EXE
echo Run MAKE from the tool's own folder - cd TOOLS\SCRGRAB - and make sure
echo you mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo SCRGRAB.ASM is not here. Run MAKE from TOOLS\SCRGRAB.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. SCRGRAB.COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
