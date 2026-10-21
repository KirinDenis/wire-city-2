@echo off
REM ============================================================================
REM RUN.BAT - play MULTIPLAY SOKO. A plain 16-bit DOS program on a CGA
REM screen: it wants nothing but DOS and a colour card (CGA, EGA or VGA).
REM
REM   Arrows   walk, and push the crate in front of you
REM   W A S D  the same, for the left hand
REM   Space    a mine: 5 s, then the 3x3 round it stands still 15 s
REM   Q, E     turn the view;  V  isometric;  Z  the whole level / close up
REM   R R      the level anew       N N, P P   the next, the previous level
REM   ESC      quit
REM
REM The title asks a name. With an IPX card (the site, or DOSBox on ipxnet)
REM everyone in the room works one warehouse; with none, alone.
REM ============================================================================
if not exist MULTSOKO.COM goto missing
MULTSOKO.COM
goto end

:missing
echo.
echo MULTSOKO.COM is not here. Build it:
echo     MAKE
:end
