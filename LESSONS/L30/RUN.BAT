@echo off
REM ============================================================================
REM RUN.BAT - run lesson 1E: the hangar.
REM
REM   One aeroplane on a stand, turning: the transport first, the one the
REM   notebook draws on squared paper.
REM
REM   UP / DOWN      the next aeroplane: fighter, bomber, radar picket,
REM                  transport, tanker
REM   LEFT / RIGHT   turn it slower, faster, the other way, or stop it
REM   W              FILLED, then FILLED + WIRE + the vertex numbers, then
REM                  the WIRE and the numbers alone
REM   ESC            back to DOS
REM
REM The numbers on the screen are the rows of the vertex table in
REM HANGAR.ASM: vertex 0 is the first dw x,y,z line, and so on down.
REM ============================================================================
if not exist HANGAR.COM goto nothing
echo HANGAR.COM
HANGAR.COM
goto end
:nothing
echo.
echo HANGAR.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end
