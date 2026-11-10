@echo off
REM ========================================================================
REM RUN.BAT - run lesson 26: the flight on the 80386, on its own clock.
REM
REM   1 the island from above. SPACE takes off.
REM   2 the flight:
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
REM   ESC            land: the clock and INT 8 are given back
REM ========================================================================
if not exist CLOCK.COM goto nothing
echo CLOCK.COM
CLOCK.COM
goto end
:nothing
echo.
echo CLOCK.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end
