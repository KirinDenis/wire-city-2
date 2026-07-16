@echo off
REM Launch the trainer inside DOSBox with COM1 bridged to TCP :5310
REM (see serial.conf). FlyDbg.exe connects to that port afterwards.
cd /d %~dp0..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe
start "" "%DOSBOX%" -conf Debug\serial.conf -noautoexec -c "mount c %CD%" -c "c:" -c "cd GAMES\TRAINER" -c "FIELD" -c "exit"
