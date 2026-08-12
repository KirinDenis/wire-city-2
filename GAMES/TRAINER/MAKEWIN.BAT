@echo off
REM ============================================================================
REM MAKEWIN.BAT - build the flight school from Windows.
REM
REM   MAKEWIN         pack the models and assemble, as MAKE does inside DOS
REM   MAKEWIN CHECK   account for the difference against the Turbo Assembler
REM                   build in TASM\TRAINER
REM
REM It drives this folder's own MAKE.BAT through DOSBox rather than repeating
REM the build, with the argument EXIT so the emulator closes itself.
REM
REM The instrument panel is a different matter and has to happen on Windows:
REM res\mkpanel.py turns the drawn panel into the raw bitmap the game loads.
REM It used to live in the root MAKEWIN.BAT and came here with the rest of
REM the flight school. If Python is not installed the panel simply is not
REM regenerated - PANEL1.RAW is committed, so the build still works.
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

if /i "%~1"=="CHECK" goto check

echo Regenerating the instrument panel...
python GAMES\TRAINER\res\mkpanel.py
if errorlevel 1 echo   (skipped - PANEL1.RAW as committed will be used)

echo Assembling in DOS...
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "c:" -c "cd GAMES\TRAINER" -c "MAKE.BAT EXIT"
if not exist GAMES\TRAINER\FIELD.COM goto failed
echo.
echo Built GAMES\TRAINER\FIELD.COM
goto end

:check
dotnet run --project TOOLS\BinAccount -c Release -- TASM\TRAINER\FIELD.COM GAMES\TRAINER\FIELD.COM
goto end

:failed
echo.
echo Build failed - see the messages above.
:end
