@echo off
REM ============================================================================
REM RUN.BAT - run lesson 21: the breakup.
REM
REM   An aeroplane flies across the stand over a floor ruled in squares.
REM
REM   SPACE          fire: the shell comes in along the yellow line
REM   LEFT / RIGHT   where the shell comes from, round the aeroplane
REM   W / S          how fast the aeroplane flies, 0 to 6
REM   UP / DOWN      the next aeroplane
REM   P              slow: the physics one frame in four
REM   R              a new aeroplane
REM   ESC            back to DOS
REM
REM After the hit: the red cross is the centre of mass of all the pieces,
REM the amber dots a whole aeroplane flown by the same laws. They stay
REM together until the first piece reaches the floor.
REM ============================================================================
if not exist BREAKUP.COM goto nothing
echo BREAKUP.COM
BREAKUP.COM
goto end
:nothing
echo.
echo BREAKUP.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end