@echo off
REM MAKE.BAT - the full build pipeline, run from Windows (NOT inside DOSBox):
REM   1. res\mkpanel.py  - convert res\panel1.bmp + res\panel2.bmp into
REM                        PANELIMG.INC / PALPNL.INC  (needs Python + Pillow)
REM   2. DOSBox headless - BUILDQ.BAT assembles RESDAT + CITY (TASM/TLINK)
REM Output: CITY.COM + CITY.DAT, build messages in BUILD.LOG.
cd /d %~dp0
echo === 1/2 panel converter ===
python res\mkpanel.py
if errorlevel 1 goto err
echo === 2/2 DOSBox build ===
C:\DOSBox-0.74-3\DOSBox.exe -noautoexec -noconsole -c "mount c %~dp0" -c "mount d c:\DOSFiles\bp" -c "c:" -c "buildq.bat" -c "exit"
type BUILD.LOG
findstr /C:"BUILD OK" BUILD.LOG >nul
if errorlevel 1 goto err
echo.
echo MAKE OK - run CITY.COM (or PUBLISH.BAT for the web)
goto end
:err
echo.
echo MAKE FAILED - see messages above
:end
