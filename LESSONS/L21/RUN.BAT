@echo off
REM ============================================================================
REM RUN.BAT - run lesson 15.
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
REM   H              hide what is behind the hills, or see through them
REM   F              FAST or CLASSIC arithmetic, flipped in flight
REM   ESC            land
REM
REM The number top left is frames a second, counted on the BIOS tick, and in
REM this lesson it finally means something: the picture is redrawn whether
REM you touch anything or not. Press H and watch it fall from 70 to 35 in
REM one step - there is no 60 to be had, and lesson 13 explained why.
REM
REM Everything on the screen is drawn by the game's own routines: ENGINE\ for
REM the island, the trigonometry, the projection and the rasterizer, and
REM GAMES\WIRECITY\CITY.ASM for the near-plane clip and the flight model.
REM Read them alongside.
REM ============================================================================
if not exist RELIEF.COM goto nothing
echo RELIEF.COM
RELIEF.COM
goto end
:nothing
echo.
echo RELIEF.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end
