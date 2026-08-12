@echo off
REM ============================================================================
REM GO.BAT - start here.
REM
REM It changes nothing and sets nothing up. Building works whether or not this
REM was ever run: each program's MAKE.BAT loads what it needs by itself, using
REM paths relative to its own folder. This exists to say where things are and
REM what to type, which is the one thing a directory listing cannot.
REM
REM It deliberately does NOT put the assembler on the PATH. A PATH entry has
REM to be an absolute path to be useful from another directory, and the
REM absolute path depends on where the repository was mounted - which this
REM file cannot know. A convenience that works only when the repository
REM happens to be mounted as a drive root is worse than none.
REM ============================================================================
echo.
echo   WIRE CITY - a DOS game, and the source it is built from.
echo.
echo   Every program here is built and run from its own folder:
echo.
echo       cd GAMES\WIRECITY
echo       MAKE            assemble it
echo       RUN             play it
echo.
echo   MAKE should answer "3 passes, 5230 bytes". That is the whole game:
echo   one source file, plain 8086 assembly, no libraries and no engine.
echo   Open CITY.ASM, change something, MAKE again.
echo.
echo   The assembler lives in TOOLS\FASM and is free to use and to pass on.
echo   Nothing here has to be bought or installed.
echo.
