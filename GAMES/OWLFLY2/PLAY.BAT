@echo off
REM PLAY.BAT - fly OWL FLY II offline in DOSBox. Nothing needs building:
REM INSTALL\ holds the game and the files it loads, and they are committed.
REM For a shared sky use NETHOST.BAT
REM / NETJOIN.BAT instead. -noautoexec is not optional: without it DOSBox
REM runs the machine's own autoexec and every -c below is buried under it.
cd /d %~dp0
if exist ..\..\LOCAL.BAT call ..\..\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe
"%DOSBOX%" -noautoexec -c "config -set cycles=30000" -c "mount c %~dp0INSTALL" -c "c:" -c "FLYOWL2" -c "exit"
