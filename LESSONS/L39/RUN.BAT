@echo off
REM ========================================================================
REM RUN.BAT - run lesson 27: the flight in protected mode, past 64K.
REM
REM   RUN 1, RUN 2, RUN 3   the three steps, FLAT1 to FLAT3
REM   RUN                   FLY: the island from above, SPACE takes off
REM
REM   SPACE          the gun, while it is held; after a crash, another aeroplane
REM   LEFT / RIGHT   roll
REM   DOWN / UP      pull / push
REM   1 / 3          the pedals (and 7 / 9 on the number pad)
REM   W / S          throttle up / down
REM   A              the afterburner, while it is held
REM   B              a target to practise on
REM   T, N           the letters, night
REM   F4             the eye outside
REM   ESC            land: the host gives the machine back to DOS
REM
REM FLY needs real mode - no EMM386 - and HIMEM with 128 KB free; it says
REM so and stops if it has not got them.
REM ========================================================================
set P=FLY.EXE
if "%1"=="1" set P=FLAT1.COM
if "%1"=="2" set P=FLAT2.COM
if "%1"=="3" set P=FLAT3.COM
if not exist %P% goto nothing
%P%
goto end
:nothing
echo.
echo %P% is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end
set P=
