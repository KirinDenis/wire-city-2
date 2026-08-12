@echo off
REM ============================================================================
REM RUNWIN.BAT - the flight school from Windows: opens DOSBox, runs it, closes
REM again. Inside DOS the equivalent is simply RUN, in this folder.
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

if not exist GAMES\TRAINER\FIELD.COM goto missing
"%DOSBOX%" -noautoexec -c "mount c %CD%" -c "c:" -c "cd GAMES\TRAINER" -c "FIELD.COM" -c "exit"
goto end

:missing
echo GAMES\TRAINER\FIELD.COM is not built. Run MAKEWIN.BAT here first.
:end
