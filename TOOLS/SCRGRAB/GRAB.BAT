@echo off
REM ============================================================================
REM GRAB.BAT - a whole reference session, from inside DOS.
REM
REM   load SCRGRAB  ->  run Borland's IDE  ->  write the shots  ->  done
REM
REM Quit the IDE the normal way (Alt+X) and the shots are written by
REM themselves. There is nothing to remember at the end of a session, which
REM matters: the one step everybody forgets is the one that saves the work.
REM
REM Everything lands in SHOTS\ because that is the current directory while
REM the IDE runs, and SCRGRAB /U writes where it stands.
REM
REM Drive D: must be Borland - GRABWIN.BAT mounts it from TASMDIR.
REM
REM   GRAB EXIT   closes DOSBox afterwards, for GRABWIN.BAT.
REM ============================================================================
if not exist SCRGRAB.COM goto nobin
if not exist D:\BIN\TURBO.EXE goto nobp
if not exist SHOTS md SHOTS
cd SHOTS

echo.
echo Press BOTH SHIFT KEYS to capture a screen. A beep means it took one.
echo Up to eight. Quit the IDE with Alt+X when you are done.
echo.
pause

..\SCRGRAB.COM
D:\BIN\TURBO.EXE
..\SCRGRAB.COM /U
cd ..
goto end

:nobin
echo.
echo SCRGRAB.COM is not here. Run MAKE first.
goto end

:nobp
echo.
echo D:\BIN\TURBO.EXE is not there. Drive D: should be Borland Pascal -
echo set TASMDIR in LOCAL.BAT and start this through GRABWIN.BAT.
:end
if "%1"=="EXIT" exit
