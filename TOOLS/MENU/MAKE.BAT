@echo off
REM ============================================================================
REM MAKE.BAT - assemble the workbench catalogue, from inside DOS.
REM
REM   cd TOOLS\MENU
REM   MAKE
REM
REM MENU.COM is what the workbench disk's autoexec runs: the catalogue of
REM lessons, examples and games, read from their .INF manifests. It ships
REM to the disk root as a TOOL (like FASM itself), not as a lesson - the
REM student builds the lessons, not the furniture.
REM
REM CWSDPMI first: the assembler is a 32-bit program and something has to
REM own protected mode on its behalf. With no arguments it serves exactly
REM one program and unloads itself.
REM
REM   MAKE EXIT   assembles and then closes DOSBox - for MAKEWIN.BAT.
REM ============================================================================
if not exist ..\FASM\FASM.EXE goto nofasm
if not exist MENU.ASM goto nosource

echo Assembling MENU.ASM ...
if exist MENU.COM del MENU.COM
..\CWSDPMI\CWSDPMI.EXE
..\FASM\FASM.EXE MENU.ASM MENU.COM
if not exist MENU.COM goto failed
echo.
echo Built MENU.COM.
goto end

:nofasm
echo.
echo Cannot find ..\FASM\FASM.EXE
echo Run MAKE from the tool's own folder - cd TOOLS\MENU - and make sure
echo you mounted the whole repository, not just this directory.
goto end

:nosource
echo.
echo MENU.ASM is not here. Run MAKE from TOOLS\MENU.
goto end

:failed
echo.
echo Assembly failed - the reason is printed just above. MENU.COM was not
echo written, so nothing was overwritten with a broken build.
:end
if "%1"=="EXIT" exit
