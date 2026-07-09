@echo off
REM MAKE.BAT - the full build pipeline, run from Windows (NOT inside DOSBox):
REM   1. res\mkpanel.py  - convert res\panel1.bmp + res\panel2.bmp into
REM                        PANELIMG.INC / PALPNL.INC  (needs Python + Pillow)
REM   2. DOSBox headless - BUILDQ.BAT assembles RESDAT + CITY (TASM/TLINK)
REM Output: INSTALL\CITY.COM + INSTALL\CITY.DAT, log in BUILD.LOG.
cd /d %~dp0
echo === 1/2 panel converter ===
python res\mkpanel.py
if errorlevel 1 goto err
echo === 2/2 DOSBox build ===
REM stale logs lie: kill it first, so a failed DOSBox run cannot pass
if exist BUILD.LOG del BUILD.LOG
REM %~dp0 ends with a backslash - DOSBox mount silently rejects that
set MKROOT=%~dp0
if "%MKROOT:~-1%"=="\" set MKROOT=%MKROOT:~0,-1%
C:\DOSBox-0.74-3\DOSBox.exe -noautoexec -noconsole -c "mount c %MKROOT%" -c "mount d c:\DOSFiles\bp" -c "c:" -c "buildq.bat" -c "exit"
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
