@echo off
REM ============================================================================
REM RUN.BAT - OWL FLY III, from inside DOS.
REM
REM   cd GAMES\OWLFLY3
REM   RUN
REM
REM It runs from INSTALL\, where the game and the four files it loads live
REM together - that folder is the whole of what ships.
REM
REM You arrive as a spectator over the bot war. ENTER takes a jet, stopped on
REM your own runway with the brakes set.  ESC quits.
REM ============================================================================
if not exist INSTALL\OWLFLY3.EXE goto missing
cd INSTALL
OWLFLY3.EXE
cd ..
goto end

:missing
echo.
echo INSTALL\OWLFLY3.EXE is not built. Type MAKE first.

:end
