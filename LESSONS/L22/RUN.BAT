@echo off
REM ============================================================================
REM RUN.BAT - run lesson 16.
REM
REM   1 the island from above, and the mark where you are about to stand.
REM     SPACE takes off.
REM   2 the flight. It does not wait for you: the aeroplane is already
REM     moving and it never stops.
REM
REM   LEFT / RIGHT   turn - and the world banks into the turn
REM   DOWN           nose UP, and UP is nose down. That is not a mistake:
REM                  it is a control column, and you pull it towards you
REM                  to climb. Every flight simulator has done it this way
REM   SPACE          after a crash: another aeroplane
REM   F              FAST or CLASSIC arithmetic, flipped in flight
REM   ESC            land
REM
REM The number top left is frames a second, counted on the BIOS tick. What it
REM costs is measured in the source, beside NR: the bill is the NUMBER OF
REM SQUARES, almost exactly, and twice the view distance is four times the
REM squares. The view is a circle because a square block turned forty five
REM degrees no longer fits in a 16-bit word.
REM
REM AND YOU CAN NOW DIE. The ground is a surface, not a floor: fly into a
REM hillside and the flight ends, the camera steps back to show you what you
REM hit, and SPACE puts another aeroplane in the air. You always appear 700
REM units above the TALLEST point of the island, whatever the island is, so
REM nothing can reach you unless you dive.
REM
REM Everything on the screen is drawn by the game's own routines: ENGINE\ for
REM the island, the trigonometry, the projection and the rasterizer, and
REM GAMES\WIRECITY\CITY.ASM for the near-plane clip and the flight model.
REM Read them alongside.
REM ============================================================================
if not exist FILL.COM goto nothing
echo FILL.COM
FILL.COM
goto end
:nothing
echo.
echo FILL.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end
