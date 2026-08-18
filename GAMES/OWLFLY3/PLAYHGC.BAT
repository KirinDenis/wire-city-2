@echo off
REM PLAYHGC.BAT - fly OWL FLY III on a HERCULES, in DOSBox. This is THE
REM door for the mono experience: DOSBox must come up as a Hercules
REM machine, because a VGA-host DOSBox (plain PLAY.BAT) marks the
REM Hercules item "- NOT IN THIS MACHINE" - the mono ports lead nowhere
REM there, exactly as in the metal. The front step lands on 1) HERCULES
REM by itself: this machine owns nothing else, so it is one ENTER to
REM the sky. Cycles ride higher than PLAY.BAT's: the mono converter
REM pays per dot, every frame. -noautoexec is not optional: without it
REM DOSBox runs the machine's own autoexec and every -c below is buried.
cd /d %~dp0
if exist ..\..\LOCAL.BAT call ..\..\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe
"%DOSBOX%" -noautoexec -machine hercules -c "config -set cycles=60000" -c "mount c %~dp0INSTALL" -c "c:" -c "OWLFLY3" -c "exit"
