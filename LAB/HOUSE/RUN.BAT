@echo off
REM ============================================================================
REM RUN.BAT - the house lab, from inside DOS.
REM
REM   cd LAB\HOUSE
REM   RUN
REM
REM One city block that holds still, and a camera to walk round it. The game's
REM own cells and rasteriser, with nothing flying - which is what makes it the
REM place to develop windows, textures and explosions.
REM
REM   ESC   quit
REM ============================================================================
if not exist HOUSE.COM goto missing
HOUSE.COM
goto end

:missing
echo.
echo HOUSE.COM is not built. Type MAKE first.

:end
