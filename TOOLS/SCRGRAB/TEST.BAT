@echo off
REM ============================================================================
REM TEST.BAT - prove SCRGRAB installs, is found again, and unloads cleanly.
REM
REM It cannot press the hotkey for you, so it does not test capturing. What it
REM does test is the part that goes wrong quietly: a resident that installs
REM twice, or one that will not come back out. Both leave a machine that has
REM to be rebooted, and neither announces itself.
REM
REM Everything lands in TEST.LOG so the run can be read afterwards.
REM
REM   TEST EXIT   runs and then closes DOSBox, for TESTWIN.BAT.
REM ============================================================================
if not exist SCRGRAB.COM goto nobin

echo SCRGRAB self-test > TEST.LOG
echo. >> TEST.LOG

echo --- unload with nothing loaded: should refuse politely >> TEST.LOG
SCRGRAB.COM /U >> TEST.LOG

echo. >> TEST.LOG
echo --- install >> TEST.LOG
SCRGRAB.COM >> TEST.LOG

echo. >> TEST.LOG
echo --- install again: should say it is already there >> TEST.LOG
SCRGRAB.COM >> TEST.LOG

echo. >> TEST.LOG
echo --- unload >> TEST.LOG
SCRGRAB.COM /U >> TEST.LOG

echo. >> TEST.LOG
echo --- unload again: should refuse politely >> TEST.LOG
SCRGRAB.COM /U >> TEST.LOG

echo.
echo Done - read TEST.LOG.
goto end

:nobin
echo.
echo SCRGRAB.COM is not here. Run MAKE first.
:end
if "%1"=="EXIT" exit
