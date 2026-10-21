@echo off
REM ============================================================================
REM RUN.BAT - play MULTIPLAY SOKO II. A plain 16-bit DOS program: the first
REM screen picks the card (EGA, CGA or Hercules) and the sound (a Sound
REM Blaster at 220h). In DOSBox the CPU is set as fast as it goes first:
REM the game keeps its time by the BIOS clock, so nothing runs too fast.
REM
REM   Arrows   walk, and push the crate in front of you
REM   W A S D  the same, for the left hand
REM   Space    a mine: 5 s, then the 3x3 round it stands still 15 s
REM   Q, E     turn the view;  V  isometric;  Z  close up / the whole level
REM   R R      the level anew       N N, P P   the next, the previous level
REM   ESC      quit
REM
REM With an IPX card (the site, or DOSBox on ipxnet) everyone in the room
REM works one castle; with none, alone.
REM ============================================================================
if not exist MULTSOK2.COM goto missing
if not exist ART.DAT goto missing
if exist Z:\CONFIG.COM config -set "cpu cycles=max"
MULTSOK2.COM
goto end

:missing
echo.
echo MULTSOK2.COM or ART.DAT is not here. Build them:
echo     MAKE
:end
