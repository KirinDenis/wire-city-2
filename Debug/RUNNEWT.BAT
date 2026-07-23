@echo off
REM Launch NEWTON inside DOSBox with COM1 bridged to TCP :5310 (the same
REM serial.conf the SOLO/TRAINER rigs use). FlyDbg.exe connects afterwards.
cd /d %~dp0..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe
REM 100000 cycles is the TARGET machine, not the old rig's 30000: NEWTON
REM is heading for an EXE on early-Pentium hardware, and the per-pixel
REM passes (world dither, banked clouds) are budgeted for that. Drop it
REM back to 30000 to see what a 386 would have made of it.
start "" "%DOSBOX%" -conf Debug\serial.conf -noautoexec -c "config -set cycles=100000" -c "mount c %CD%" -c "c:" -c "cd GAMES\NEWTON" -c "NEWTON" -c "exit"
