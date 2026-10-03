@echo off
REM ============================================================================
REM MAKEWIN.BAT - build OWL FLY III BOND from Windows, without opening DOSBox.
REM
REM   MAKEWIN         the game, as MAKE does inside DOS
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
REM And the result is MEASURED - at least 40000 bytes or it did not
REM happen (a zero-byte EXE passes existence checks everywhere), with
REM three attempts before giving up.
set ATTEMPT=0
:build
set /a ATTEMPT+=1
REM EACH ASSEMBLER'S OUTPUT GOES TO A FILE, and that is not tidiness. With
REM the three of them writing to the DOSBox console the third one - the big
REM one, eight seconds of work - failed to land about three runs in four,
REM silently, leaving no OWLFLY3B.NEW and no message anyone could read.
REM Redirected, the same ten -c lines have landed every time. It also means
REM BUILD.LOG holds what the assembler actually said, which is the thing you
REM want the moment a build starts arguing.
if exist GAMES\OWLFLY3B\BUILD.LOG del GAMES\OWLFLY3B\BUILD.LOG
"%DOSBOX%" -noautoexec -c "mount c %CD%" -c "c:" -c "cd GAMES\OWLFLY3B" -c "..\..\TOOLS\CWSDPMI\CWSDPMI.EXE" -c "..\..\TOOLS\FASM\FASM.EXE SRC\OWLFLY3B.ASM INSTALL\OWLFLY3B.NEW > BUILD.LOG" -c "exit"
if not exist GAMES\OWLFLY3B\INSTALL\OWLFLY3B.NEW goto retry
for %%A in (GAMES\OWLFLY3B\INSTALL\OWLFLY3B.NEW) do if %%~zA LSS 40000 goto retry
del GAMES\OWLFLY3B\INSTALL\OWLFLY3B.EXE 2>nul
ren GAMES\OWLFLY3B\INSTALL\OWLFLY3B.NEW OWLFLY3B.EXE
if exist GAMES\OWLFLY3B\INSTALL\OWLFLY3B.EXE goto built
:retry
if %ATTEMPT% LSS 3 (
  echo   attempt %ATTEMPT% left no real EXE - going again
  goto build
)
goto failed
:built
echo.
echo Built GAMES\OWLFLY3B\INSTALL\OWLFLY3B.EXE
for %%A in (GAMES\OWLFLY3B\INSTALL\OWLFLY3B.EXE) do echo   %%~zA bytes, %%~tA
goto end

:failed
echo.
echo Build failed - see the messages above.
:end
