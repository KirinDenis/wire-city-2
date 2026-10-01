@echo off
REM ============================================================================
REM RUN.BAT - run lesson 17.
REM
REM   1 the island from above, and the mark where you are about to stand:
REM     five squares short of the island's biggest town, facing it.
REM     SPACE takes off.
REM   2 the flight. It does not wait for you: the aeroplane is already
REM     moving and it never stops. The town is straight ahead, and its
REM     houses rise out of the ground as you come.
REM
REM   LEFT / RIGHT   turn - and the world banks into the turn
REM   DOWN           nose UP, and UP is nose down. That is not a mistake:
REM                  it is a control column, and you pull it towards you
REM                  to climb. Every flight simulator has done it this way
REM   N              night, and N again for day - nothing but the palette
REM   SPACE          after a crash: another aeroplane
REM   F              FAST or CLASSIC arithmetic, flipped in flight
REM   ESC            land
REM
REM The number top left is frames a second, counted on the BIOS tick. Over
REM bare ground it is what lesson 16 made it; over a town the houses cost a
REM retrace and their windows another - measured, in the header of the
REM source.
REM
REM The houses are not solid yet: you can fly through them. The ground still
REM ends the flight, exactly as it did in lesson 16.
REM
REM Everything on the screen is drawn by the game's own routines: ENGINE\ for
REM the island, the trigonometry, the projection and the rasterizer, and
REM GAMES\OWLFLY3\SRC for the walls, the roof and the rule of the windows.
REM Read them alongside.
REM ============================================================================
if not exist HOUSES.COM goto nothing
echo HOUSES.COM
HOUSES.COM
goto end
:nothing
echo.
echo HOUSES.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end
