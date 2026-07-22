@echo off
REM Launch SOLO inside DOSBox with COM1 bridged to TCP :5310 (the same
REM serial.conf the TRAINER rig uses). FlyDbg.exe connects afterwards.
cd /d %~dp0..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe
start "" "%DOSBOX%" -conf Debug\serial.conf -noautoexec -c "config -set cycles=30000" -c "mount c %CD%" -c "c:" -c "cd EXAMPLES" -c "SOLO" -c "exit"
