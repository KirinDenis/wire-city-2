@echo off
REM ============================================================================
REM RUN.BAT - run lesson 19.
REM
REM   1 the island from above, and the mark where you are about to stand:
REM     five squares short of the island's biggest town, facing it.
REM     SPACE takes off.
REM   2 the flight - and now the aeroplane has an engine. It is handed to
REM     you at CRUISE, 736, the throttle at the stop.
REM
REM   W / S          throttle up / down - THR on the screen, in per cent
REM   A              the afterburner, while it is held: four times the
REM                  thrust, eight times the fuel
REM   LEFT / RIGHT   turn - and a turn costs speed
REM   DOWN           nose UP, and UP is nose down: a control column. Hold
REM                  it and the climb drains the speed - SPD on the screen
REM                  - until the word STALL comes up and the nose falls
REM   N              night, and N again for day
REM   F              FAST or CLASSIC arithmetic, flipped in flight
REM   SPACE          after a crash: another aeroplane
REM   ESC            land
REM
REM Top left: frames a second, then THR, SPD (vel, the speed the code keeps),
REM ALT (the height over the sea) and HDG (the heading, in degrees).
REM
REM The physics runs on the BIOS clock, 18.2 times a second, whatever the
REM frame rate - so the town goes past at the same speed as the fields.
REM And the wind drifts you east and a little south: point the nose at a
REM town and watch it slide.
REM ============================================================================
if not exist AXES.COM goto nothing
echo AXES.COM
AXES.COM
goto end
:nothing
echo.
echo AXES.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end
