@echo off
REM TESTEGA.BAT - fly OWL FLY III on an emulated EGA card. The same door
REM as PLAY.BAT, but DOSBox comes up as a real EGA machine: mode 10h,
REM 640x350, the curated sixteen through the BIOS palette call. Pick
REM 3) EGA at the front step. The second door matters too: run plain
REM PLAY.BAT and pick 3 - a VGA playing an EGA mode is how most people
REM will actually fly it, and the two must look identical.
cd /d %~dp0
if exist ..\..\LOCAL.BAT call ..\..\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe
"%DOSBOX%" -noautoexec -machine ega -c "config -set cycles=60000" -c "mount c %~dp0INSTALL" -c "c:" -c "OWLFLY3" -c "exit"
