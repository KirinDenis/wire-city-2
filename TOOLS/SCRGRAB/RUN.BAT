@echo off
REM ============================================================================
REM RUN.BAT - load SCRGRAB and leave it resident.
REM
REM   RUN        go resident
REM   RUN U      write SHOT00.BIN.. to this folder and unload
REM
REM While it is resident, press BOTH Shift keys together to capture whatever
REM is on the screen. A short beep means it took one. Up to eight.
REM ============================================================================
if not exist SCRGRAB.COM goto missing
if /i "%1"=="U" goto unload
SCRGRAB.COM
goto end

:unload
SCRGRAB.COM /U
goto end

:missing
echo.
echo SCRGRAB.COM is not here. Build it:
echo     MAKE
:end
