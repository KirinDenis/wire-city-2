@echo off
REM ============================================================================
REM RUNWIN.BAT - NEWTON from Windows: opens DOSBox, runs it, closes again.
REM Inside DOS the equivalent is simply RUN, in this folder.
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

if not exist GAMES\NEWTON\NEWTON.COM goto missing
"%DOSBOX%" -noautoexec -c "mount c %CD%" -c "c:" -c "cd GAMES\NEWTON" -c "NEWTON.COM" -c "exit"
goto end

:missing
echo GAMES\NEWTON\NEWTON.COM is not built. Run MAKEWIN.BAT here first.
:end
