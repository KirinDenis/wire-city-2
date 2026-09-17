@echo off
REM Scratch: MAKEWIN, but keeping what FASM said in ASM.LOG.
REM Not part of the lesson - delete before it ships.
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "c:" -c "cd LESSONS\L19" -c "ASMLOG.BAT"
type LESSONS\L19\ASM.LOG
