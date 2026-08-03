@echo off
REM RUN.BAT - the house lab in DOSBox. Build it first: MAKE LAB from the
REM repo root. -noautoexec is not optional: without it DOSBox runs the
REM machine's own autoexec (a file manager, on this one) and every -c
REM below is buried under it.
cd /d %~dp0..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe
"%DOSBOX%" -noautoexec -c "config -set cycles=30000" -c "mount c %CD%" -c "c:" -c "cd LAB" -c "HOUSE" -c "exit"
