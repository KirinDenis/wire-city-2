@echo off
REM ============================================================================
REM MAKE.BAT [target] - the arcade build orchestrator. Run from Windows.
REM   MAKE            - build EVERYTHING (all games + examples)
REM   MAKE OWLFLY     - the flight simulator only (converters + TASM)
REM   MAKE WIRECITY   - the 1986 original only
REM   MAKE EXAMPLES   - the teaching machines only
REM Per-game folders have one-line wrappers calling this with their target.
REM All build logic lives HERE: DOSBox always mounts the repo root as C:
REM because ENGINE\ is shared by every target. Log: BUILD.LOG in the root.
REM Machine paths live in LOCAL.BAT (gitignored):
REM   set DOSBOX=C:\Games\DOSBox\DOSBox.exe
REM   set TASMDIR=d:\borland\bp
REM ============================================================================
cd /d %~dp0
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe
if "%TASMDIR%"=="" set TASMDIR=c:\bp
set TARGET=%~1
if "%TARGET%"=="" set TARGET=ALL

if "%TARGET%"=="WIRECITY" goto skipconv
if "%TARGET%"=="EXAMPLES" goto skipconv
echo === 1/2 OWLFLY converters (panel + engine sample) ===
python GAMES\OWLFLY\res\mkpanel.py
if errorlevel 1 goto err
python GAMES\OWLFLY\res\mkengine.py
if errorlevel 1 goto err
:skipconv

echo === 2/2 DOSBox build: %TARGET% ===
if exist BUILD.LOG del BUILD.LOG
set MKROOT=%~dp0
if "%MKROOT:~-1%"=="\" set MKROOT=%MKROOT:~0,-1%
"%DOSBOX%" -noautoexec -noconsole -c "mount c %MKROOT%" -c "mount d %TASMDIR%" -c "c:" -c "buildq.bat %TARGET%" -c "exit"
if not exist BUILD.LOG goto norun
type BUILD.LOG
findstr /C:"BUILD OK" BUILD.LOG >nul
if errorlevel 1 goto err
echo.
echo MAKE OK [%TARGET%]
goto end
:norun
echo BUILD.LOG was never written - the DOSBox mount or BUILDQ.BAT failed
:err
echo.
echo MAKE FAILED [%TARGET%] - see messages above
:end
