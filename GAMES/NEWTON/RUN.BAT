@echo off
REM ============================================================================
REM RUN.BAT - NEWTON, from inside DOS.
REM
REM   cd GAMES\NEWTON
REM   RUN
REM
REM The force-model aeroplane: nothing here follows a script, the whole flight
REM comes out of lift, drag, thrust and gravity.
REM
REM   ESC   quit
REM ============================================================================
if not exist NEWTON.COM goto missing
NEWTON.COM
goto end

:missing
echo.
echo NEWTON.COM is not built. Type MAKE first.

:end
