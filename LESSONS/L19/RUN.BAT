@echo off
REM ============================================================================
REM RUN.BAT - run lesson 13.
REM
REM Five stages. ESC leaves the stage you are in and starts the next one;
REM ESC in the last one ends the program.
REM
REM   1 the island from above, and the mark where you are about to stand
REM   2 the flight, both fences up: flat coloured squares. This is right
REM   3 the NEAR PLANE taken away. Tidy, and wrong: the world behind your
REM     head is drawn mirrored above the horizon
REM   4 the GLASS taken away too. Nothing clipped, a frame a minute, drawn
REM     straight onto the screen so you can watch what it costs. ESC early
REM   5 everything back. Fly it
REM
REM Arrow keys walk and turn, PgUp and PgDn climb and dive. F flips the
REM engine between FAST (the lessons' way: no divide in the rotate, lesson
REM 8's self-patching line) and CLASSIC (what the game shipped with), and
REM the number top left is frames a second, counted on the BIOS tick.
REM
REM Everything on the screen is drawn by the game's own routines: ENGINE\ for
REM the island, the trigonometry, the projection and the rasterizer, and
REM GAMES\WIRECITY\CITY.ASM for the near-plane clip. Read them alongside.
REM ============================================================================
if not exist CLIP.COM goto nothing
echo CLIP.COM
CLIP.COM
goto end
:nothing
echo.
echo CLIP.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end