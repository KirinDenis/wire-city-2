@echo off
REM Twenty-three lines and no more: this prints on an 80x25 screen with the
REM prompt underneath, and one line too many scrolls the title off the top.
REM
REM IT IS NOT CALLED HELP.BAT, and that is not a preference. DOSBox has an
REM internal HELP, and an internal command wins over a batch file of the
REM same name even when you type the extension and even through CALL. A
REM bundle whose autoexec says HELP.BAT greets the reader with DOSBox's own
REM command list, which is how lesson 5's bundle has greeted people for a
REM year. Measured, 2026-09-25. Any name DOSBox does not already own works;
REM INTRO is taken too.
echo.
echo  LESSON 15 - THE GROUND STOPS BEING FLAT
echo.
echo  Every node of the lattice now asks the island how high it is, and a
echo  hill can get in the way of what is behind it. H switches on hidden
echo  line removal: one byte for each of the 320 screen columns, and that
echo  is the whole algorithm. It is not in the game and next lesson drops
echo  it - read HLINE in the source and take it if you ever want it.
echo.
echo    MAKE                assemble RELIEF.ASM
echo    RUN                 the island from above, then SPACE to take off
echo.
echo    LEFT / RIGHT        turn, and the world banks into it
echo    DOWN                nose UP. It is a control column.
echo    H                   hide what is behind the hills, or see through
echo    F                   FAST or CLASSIC arithmetic
echo    ESC                 land
echo.
echo    EDIT RELIEF.ASM     VEXAG is 1, which doubles the height. Try 0 for
echo                        the game's own ground, or 2. Then MAKE and RUN.
echo.
echo    LESSON              print this again
echo.
