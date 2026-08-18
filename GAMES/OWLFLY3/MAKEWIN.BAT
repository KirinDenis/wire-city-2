@echo off
REM ============================================================================
REM MAKEWIN.BAT - build OWL FLY III from Windows, without opening DOSBox.
REM
REM   MAKEWIN         the two blobs and the game, as MAKE does inside DOS
REM
REM Artwork, models or sounds changed? CONVERT.BAT in this folder runs the
REM .NET converters that turn them into what the game includes. Their output
REM is committed, so this build does not depend on it having run.
REM
REM There is no CHECK here: OWL FLY II kept one because it had a frozen Turbo
REM Assembler build to account against, and this game never had one - it was
REM born on FASM, forked from GAMES\OWLFLY2 after that migration finished.
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

REM Artwork changed? Run CONVERT.BAT here first.

echo Assembling in DOS...
REM THE STEPS RIDE THE -c LINES, NOT "MAKE.BAT EXIT" - and that is a
REM scar, not a style (2026-08-18). On this host, a build that runs as
REM a BATCH inside DOSBox and then EXITs from within reproducibly
REM leaves the EXE as ZERO BYTES on the Windows side - four times in a
REM row - while the SAME CWSDPMI+FASM steps handed to DOSBox as -c
REM lines with a -c exit land every byte, every time. Same tools, same
REM order, same mount: only the sequencing moved. MAKE.BAT itself is
REM untouched and stays the build a stranger runs BY HAND inside DOS,
REM where it works with a visible console and no exit.
REM And the result is MEASURED - at least 100000 bytes or it did not
REM happen (a zero-byte EXE passes existence checks everywhere), with
REM three attempts before giving up.
set ATTEMPT=0
:build
set /a ATTEMPT+=1
"%DOSBOX%" -noautoexec -c "mount c %CD%" -c "c:" -c "cd GAMES\OWLFLY3" -c "..\..\TOOLS\CWSDPMI\CWSDPMI.EXE" -c "..\..\TOOLS\FASM\FASM.EXE SRC\RESDAT.ASM INSTALL\CITY.DAT" -c "..\..\TOOLS\CWSDPMI\CWSDPMI.EXE" -c "..\..\TOOLS\FASM\FASM.EXE SRC\SIDEDAT.ASM INSTALL\CPSIDE.DAT" -c "..\..\TOOLS\CWSDPMI\CWSDPMI.EXE" -c "..\..\TOOLS\FASM\FASM.EXE SRC\OWLFLY3.ASM INSTALL\OWLFLY3.NEW" -c "exit"
if not exist GAMES\OWLFLY3\INSTALL\OWLFLY3.NEW goto retry
for %%A in (GAMES\OWLFLY3\INSTALL\OWLFLY3.NEW) do if %%~zA LSS 100000 goto retry
del GAMES\OWLFLY3\INSTALL\OWLFLY3.EXE 2>nul
ren GAMES\OWLFLY3\INSTALL\OWLFLY3.NEW OWLFLY3.EXE
if exist GAMES\OWLFLY3\INSTALL\OWLFLY3.EXE goto built
:retry
if %ATTEMPT% LSS 3 (
  echo   attempt %ATTEMPT% left no real EXE - going again
  goto build
)
goto failed
:built
echo.
echo Built GAMES\OWLFLY3\INSTALL\OWLFLY3.EXE
for %%A in (GAMES\OWLFLY3\INSTALL\OWLFLY3.EXE) do echo   %%~zA bytes, %%~tA
goto end

:failed
echo.
echo Build failed - see the messages above.
:end
