@echo off
REM ============================================================================
REM RUN.BAT - run lesson 1D.
REM
REM   1 the island from above, and the mark where you are about to stand:
REM     five squares short of the island's biggest town, facing it.
REM     SPACE takes off.
REM   2 the flight - and now a wing holds the aeroplane up: the nose points
REM     a little above where it goes, and the circle with wings under the
REM     gunsight is where it goes.
REM
REM   LEFT / RIGHT   roll
REM   DOWN / UP      pull / push: ask the wing for more G, or less - too
REM                  much, too slow, and it STALLS
REM   1 / 3          the pedals (and 7 / 9 on the number pad)
REM   W / S          throttle up / down
REM   A              the afterburner, while it is held
REM   T              the letters - with the ring, the tapes get one too
REM   N              night, and N again for day
REM   F              FAST or CLASSIC arithmetic, flipped in flight
REM   SPACE          after a crash: another aeroplane
REM   ESC            land
REM
REM The gap between the gunsight and the marker is the angle of attack, read
REM on the ladder. The G is the load the wing carries - minus one upside down
REM - and the red line on the speed tape is the stall speed for THIS pull.
REM ============================================================================
if not exist WING.COM goto nothing
echo WING.COM
WING.COM
goto end
:nothing
echo.
echo WING.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end
