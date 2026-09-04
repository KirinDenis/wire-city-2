@echo off
REM ============================================================================
REM RUNWIN.BAT - the house lab from Windows: opens DOSBox, runs it, closes
REM again. Inside DOS the equivalent is simply RUN, in this folder.
REM
REM -noautoexec is not optional: without it DOSBox runs the machine's own
REM autoexec (a file manager, on this one) and every -c below is buried
REM under it.
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

if not exist LAB\HOUSE\HOUSE.COM goto missing
"%DOSBOX%" -noautoexec -c "config -set cycles=30000" -c "mount c %CD%" -c "c:" -c "cd LAB\HOUSE" -c "HOUSE.COM" -c "exit"
goto end

:missing
echo LAB\HOUSE\HOUSE.COM is not built. Run MAKEWIN.BAT in the LAB\HOUSE folder first.
:end
