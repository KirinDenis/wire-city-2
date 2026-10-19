@echo off
REM ============================================================================
REM RUN.BAT - play MULTIPLAY SOKO. A plain 16-bit DOS program on a CGA
REM screen: it wants nothing but DOS and a colour card (CGA, EGA or VGA).
REM
REM   Arrows   walk, and push the crate in front of you
REM   W A S D  the same, for the left hand
REM   Z        the whole level / close up
REM   R R      the level anew       N N, P P   the next, the previous level
REM   ESC      quit
REM ============================================================================
if not exist SOKOBAN.COM goto missing
SOKOBAN.COM
goto end

:missing
echo.
echo SOKOBAN.COM is not here. Build it:
echo     MAKE
:end
