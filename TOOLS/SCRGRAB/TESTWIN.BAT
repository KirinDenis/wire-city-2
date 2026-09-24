@echo off
REM ============================================================================
REM TESTWIN.BAT - run the self-test from Windows and print the log.
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

if exist TOOLS\SCRGRAB\TEST.LOG del TOOLS\SCRGRAB\TEST.LOG
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "c:" -c "cd TOOLS\SCRGRAB" -c "TEST.BAT EXIT"
if not exist TOOLS\SCRGRAB\TEST.LOG goto failed
type TOOLS\SCRGRAB\TEST.LOG
goto end

:failed
echo.
echo The test produced no log - DOSBox did not get that far.
:end
