@echo off
REM ============================================================================
REM RUN.BAT - run lesson 1B.
REM
REM   1 the island from above, and the mark where you are about to stand:
REM     five squares short of the island's biggest town, facing it.
REM     SPACE takes off.
REM   2 the flight - and the numbers are instruments now: OWL FLY III's
REM     HUD tapes.
REM
REM   LEFT / RIGHT   roll
REM   DOWN / UP      pull / push - and watch the G under the speed
REM   1 / 3          the pedals (and 7 / 9 on the number pad)
REM   W / S          throttle up / down
REM   A              the afterburner, while it is held
REM   T              the letters - with the ring, the tapes get one too
REM   N              night, and N again for day
REM   F              FAST or CLASSIC arithmetic, flipped in flight
REM   SPACE          after a crash: another aeroplane
REM   ESC            land
REM
REM Top: the compass. Left: the speed, with the stall as a red line.
REM Right: the height, with the floor under you and the ceiling as red
REM lines, and the IVV - a cyan tick - showing the climb. Under the speed,
REM the G. Under the tapes: the throttle, the pitch and the bank.
REM ============================================================================
if not exist TAPES.COM goto nothing
echo TAPES.COM
TAPES.COM
goto end
:nothing
echo.
echo TAPES.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end
