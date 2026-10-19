@echo off
REM ============================================================================
REM RUN.BAT - play SOKOBAN. A plain 16-bit DOS program on a CGA screen: it
REM wants nothing but DOS and any colour card (CGA, EGA or VGA).
REM
REM   Arrows   walk the grid: UP goes up-right on the screen
REM   9 3 1 7  the keypad: the same four, the way the screen shows them
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
