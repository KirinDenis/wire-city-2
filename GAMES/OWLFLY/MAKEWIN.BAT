@echo off
REM ============================================================================
REM MAKEWIN.BAT - build OWL FLY from Windows, without opening DOSBox by hand.
REM
REM   MAKEWIN         the resource blob and the game, as MAKE does inside DOS
REM   MAKEWIN CHECK   account for the difference against the Turbo Assembler
REM                   build kept in TASM\OWLFLY\INSTALL
REM
REM It drives this folder's own MAKE.BAT through DOSBox rather than repeating
REM the build, with the argument EXIT so the emulator closes itself.
REM
REM The cockpit artwork and the engine sample are prepared by the converters
REM in res\ from the root MAKEWIN.BAT; they are committed, so this does not
REM need them to have run.
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

if /i "%~1"=="CHECK" goto check

echo Assembling in DOS...
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "c:" -c "cd GAMES\OWLFLY" -c "MAKE.BAT EXIT"
if not exist GAMES\OWLFLY\INSTALL\FLYOWL.COM goto failed
echo.
echo Built GAMES\OWLFLY\INSTALL\FLYOWL.COM
goto end

:check
echo === the resource blob, which is data and must match exactly ===
fc /b TASM\OWLFLY\INSTALL\CITY.DAT GAMES\OWLFLY\INSTALL\CITY.DAT
echo === the game ===
dotnet run --project TOOLS\BinAccount -c Release -- TASM\OWLFLY\INSTALL\FLYOWL.COM GAMES\OWLFLY\INSTALL\FLYOWL.COM
goto end

:failed
echo.
echo Build failed - see the messages above.
:end
