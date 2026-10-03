@echo off
REM ============================================================================
REM RUN.BAT - OWL FLY III BOND, from inside DOS.
REM
REM   cd GAMES\OWLFLY3B
REM   RUN
REM
REM It runs from INSTALL\, where the game and the four files it loads live
REM together - that folder is the whole of what ships.
REM
REM You arrive as a spectator over the bot war. ENTER takes a jet, stopped on
REM your own runway with the brakes set.  ESC quits.
REM ============================================================================
if not exist INSTALL\OWLFLY3B.EXE goto missing
cd INSTALL
OWLFLY3B.EXE
cd ..
goto end

:missing
echo.
echo INSTALL\OWLFLY3B.EXE is not built. Type MAKE first.

:end
