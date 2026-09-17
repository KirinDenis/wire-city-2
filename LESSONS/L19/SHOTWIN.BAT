@echo off
REM Scratch: build SHOT.ASM and leave DOSBox showing stage %1 for a few
REM seconds, then close itself. Not part of the lesson - delete before it
REM ships.
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "c:" -c "cd LESSONS\L19" -c "SHOTMAK.BAT %1"
