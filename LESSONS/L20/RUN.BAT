@echo off
REM ============================================================================
REM RUN.BAT - run lesson 14.
REM
REM   1 the island from above, and the mark where you are about to stand.
REM     SPACE takes off.
REM   2 the flight. It does not wait for you: the aeroplane is already
REM     moving and it never stops.
REM
REM   LEFT / RIGHT   turn - and the world banks into the turn
REM   PgUp / PgDn    climb and dive, between a floor and a ceiling
REM   F              FAST or CLASSIC arithmetic, flipped in flight
REM   ESC            land
REM
REM The number top left is frames a second, counted on the BIOS tick, and in
REM this lesson it finally means something: the picture is redrawn whether
REM you touch anything or not.
REM
REM Everything on the screen is drawn by the game's own routines: ENGINE\ for
REM the island, the trigonometry, the projection and the rasterizer, and
REM GAMES\WIRECITY\CITY.ASM for the near-plane clip and the flight model.
REM Read them alongside.
REM ============================================================================
if not exist FLY.COM goto nothing
echo FLY.COM
FLY.COM
goto end
:nothing
echo.
echo FLY.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end
