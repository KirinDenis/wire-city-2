@echo off
REM MAKE.BAT - the full build pipeline, run from Windows (NOT inside DOSBox):
REM   1. res\mkpanel.py  - convert res\panel1.bmp + res\panel2.bmp into
REM                        SRC\PANELIMG.INC / SRC\PALPNL.INC (Python + Pillow)
REM   2. DOSBox headless - BUILDQ.BAT assembles SRC, installs into INSTALL
REM Output: INSTALL\CITY.COM + INSTALL\CITY.DAT, log in BUILD.LOG.
REM
REM Machine-specific paths live in LOCAL.BAT (gitignored), e.g.:
REM   set DOSBOX=C:\Games\DOSBox\DOSBox.exe
REM   set TASMDIR=d:\borland\bp
cd /d %~dp0
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe
if "%TASMDIR%"=="" set TASMDIR=c:\bp

echo === 1/2 panel + engine sample converters ===
python res\mkpanel.py
if errorlevel 1 goto err
python res\mkengine.py
if errorlevel 1 goto err
echo === 2/2 DOSBox build ===
REM stale logs lie: kill it first, so a failed DOSBox run cannot pass
if exist BUILD.LOG del BUILD.LOG
REM %~dp0 ends with a backslash - DOSBox mount silently rejects that
set MKROOT=%~dp0
if "%MKROOT:~-1%"=="\" set MKROOT=%MKROOT:~0,-1%
"%DOSBOX%" -noautoexec -noconsole -c "mount c %MKROOT%" -c "mount d %TASMDIR%" -c "c:" -c "buildq.bat" -c "exit"
if not exist BUILD.LOG goto norun
type BUILD.LOG
findstr /C:"BUILD OK" BUILD.LOG >nul
if errorlevel 1 goto err
echo.
echo MAKE OK - run INSTALL\CITY.COM (or PUBLISH.BAT for the web)
goto end
:norun
echo BUILD.LOG was never written - the DOSBox mount or BUILDQ.BAT failed
:err
echo.
echo MAKE FAILED - see messages above
:end
