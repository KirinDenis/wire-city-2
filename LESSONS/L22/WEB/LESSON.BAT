@echo off
REM Twenty-three lines and no more: this prints on an 80x25 screen with the
REM prompt underneath, and one line too many scrolls the title off the top.
REM
REM NOT HELP.BAT: DOSBox has an internal HELP, and an internal command wins
REM over a batch file of the same name, extension typed or not. See L21.
echo.
echo  LESSON 16 - THE GROUND BECOMES A SURFACE
echo.
echo  Every square of the lattice is filled now, painted far to near so each
echo  one covers what was behind it - the painter's algorithm. The ground
echo  can end the flight. And the view reaches twice as far, which is why
echo  it had to become a circle: turn a square 45 degrees and its corner
echo  no longer fits in a 16-bit word.
echo.
echo    MAKE                assemble FILL.ASM
echo    RUN                 the island from above, then SPACE to take off
echo.
echo    LEFT / RIGHT        turn, and the world banks into it
echo    DOWN                nose UP. UP puts it down - it is a stick
echo    SPACE               after a crash: another aeroplane
echo    ESC                 land
echo.
echo    EDIT FILL.ASM       NR is 24. Try 12 and watch the frame rate.
echo.
echo    LESSON              print this again
