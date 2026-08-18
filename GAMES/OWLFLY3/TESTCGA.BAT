@echo off
REM TESTCGA.BAT - fly OWL FLY III on an emulated CGA card. The same door
REM as PLAY.BAT, but DOSBox comes up as a real CGA machine, so mode 5
REM and the burst-off cyan/red/white palette behave as the hardware
REM would. Pick 2) CGA at the front step. Cycles ride higher than
REM PLAY.BAT's: the converter pays per pixel, every frame.
cd /d %~dp0
if exist ..\..\LOCAL.BAT call ..\..\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe
"%DOSBOX%" -noautoexec -machine cga -c "config -set cycles=60000" -c "mount c %~dp0INSTALL" -c "c:" -c "OWLFLY3" -c "exit"
