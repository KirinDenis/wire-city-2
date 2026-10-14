@echo off
REM ============================================================================
REM RUN.BAT - run lesson 1C.
REM
REM   1 the island from above, and the mark where you are about to stand:
REM     five squares short of the island's biggest town, facing it.
REM     SPACE takes off.
REM   2 the flight - and the middle of the screen is an instrument now: the
REM     gunsight, the horizon line and the pitch ladder.
REM
REM   LEFT / RIGHT   roll
REM   DOWN / UP      pull / push - past twenty degrees the ladder lights
REM   1 / 3          the pedals (and 7 / 9 on the number pad)
REM   W / S          throttle up / down
REM   A              the afterburner, while it is held
REM   T              the letters - with the ring, the tapes get one too
REM   N              night, and N again for day
REM   F              FAST or CLASSIC arithmetic, flipped in flight
REM   SPACE          after a crash: another aeroplane
REM   ESC            land
REM
REM The middle: the gunsight where the nose points, the horizon line, and -
REM once the horizon has left the middle - a rung every ten degrees, solid
REM above the horizon and dashed below. Round it, lesson 1B's tapes: the
REM compass, the speed, the height and the climb; the G under the speed.
REM ============================================================================
if not exist LADDER.COM goto nothing
echo LADDER.COM
LADDER.COM
goto end
:nothing
echo.
echo LADDER.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end
