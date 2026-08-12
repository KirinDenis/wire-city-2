@echo off
REM ============================================================================
REM RUN.BAT - the flight school, from inside DOS.
REM
REM   cd GAMES\TRAINER
REM   RUN
REM
REM   ESC   quit
REM ============================================================================
if not exist FIELD.COM goto missing
FIELD.COM
goto end

:missing
echo.
echo FIELD.COM is not built. Type MAKE first.

:end
