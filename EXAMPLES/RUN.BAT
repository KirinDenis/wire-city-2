@echo off
REM ============================================================================
REM RUN.BAT - run one of the teaching machines, from inside DOS.
REM
REM   cd EXAMPLES
REM   RUN JET
REM   RUN JET.COM     the same. DOS cannot take an extension off an argument -
REM                   %~n1 is a Windows thing - so instead of parsing the name
REM                   this tries JET.COM first and then whatever you typed.
REM
REM They are small programs that each demonstrate one thing, and they are
REM meant to be read as much as run - the source beside each one is the point.
REM
REM   TERRA    a Diamond-Square landscape, generated and drawn
REM   RING     the sound ring buffer, feeding the DMA beam
REM   SPOOL    spooling sound off disk while the picture keeps moving
REM   FLIGHT   the flight model on its own, with no world around it
REM   LAND     approach and touchdown
REM   LNDPHYS  the landing, with the gear and the ground taking part
REM   TKOFF    the take-off roll
REM   TKPHYS   the take-off, with the physics doing the work
REM   SMOKE    a particle trail, painter-sorted
REM   AVIO     the instrument panel
REM   JET      the aeroplane model, rotated and projected
REM   SOLO     all of it at once - the nearest thing here to a game
REM   BBS      two machines talking over IPX
REM
REM ESC quits all of them.
REM ============================================================================
if "%1"=="" goto usage
if exist %1.COM goto named
if exist %1 goto asgiven
goto missing

:named
%1.COM
goto end

:asgiven
%1
goto end

:missing
echo.
echo %1.COM is not built. Type MAKE %1 first.
goto end

:usage
echo.
echo Which one? RUN JET, for instance. The thirteen are
echo   TERRA RING SPOOL FLIGHT LAND LNDPHYS TKOFF TKPHYS SMOKE AVIO JET SOLO BBS
echo Read the top of the matching .ASM to see what it demonstrates.

:end
