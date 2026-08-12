@echo off
REM ============================================================================
REM RUN.BAT - OWL FLY, from inside DOS.
REM
REM   cd GAMES\OWLFLY
REM   RUN
REM
REM It runs from INSTALL\, which is where the game and the two resource files
REM it loads live together - that folder is the whole of what ships.
REM
REM   ESC   quit
REM ============================================================================
if not exist INSTALL\FLYOWL.COM goto missing
cd INSTALL
FLYOWL.COM
cd ..
goto end

:missing
echo.
echo INSTALL\FLYOWL.COM is not built. Type MAKE first.

:end
