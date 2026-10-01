@echo off
REM Twenty-three lines and no more: this prints on an 80x25 screen with the
REM prompt underneath, and one line too many scrolls the title off the top.
REM
REM NOT HELP.BAT: DOSBox has an internal HELP, and an internal command wins
REM over a batch file of the same name, extension typed or not. See L21.
echo.
echo  LESSON 17 - A TOWN ON THE GROUND
echo.
echo  Blocks of sixteen houses on the flat squares of the island, placed by
echo  a hash. You appear facing the biggest town. The windows are always as
echo  big as they are on the screen, so a far one is a lit pixel that grows.
echo  And N is night - nothing but the palette.
echo.
echo    MAKE                assemble HOUSES.ASM
echo    RUN                 the island from above, then SPACE to take off
echo.
echo    LEFT / RIGHT        turn, and the world banks into it
echo    DOWN                nose UP. UP puts it down - it is a stick
echo    N                   night, and N again for day
echo    ESC                 land
echo.
echo    EDIT HOUSES.ASM     RH is 6 and HMAX 4096. Push them and count frames.
echo.
echo    LESSON              print this again
