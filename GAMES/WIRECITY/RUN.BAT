@echo off
REM ============================================================================
REM RUN.BAT - play WIRE CITY.
REM
REM No GO needed for this one: the game is a plain 16-bit DOS program and
REM wants nothing but DOS. GO is only needed to ASSEMBLE it.
REM
REM   Arrows  turn and climb        SPACE  restart after a crash
REM   ESC     quit
REM ============================================================================
if not exist CITY.COM goto missing
CITY.COM
goto end

:missing
echo.
echo CITY.COM is not here. Build it:
echo     GO        (once, from the repository root)
echo     MAKE
:end
