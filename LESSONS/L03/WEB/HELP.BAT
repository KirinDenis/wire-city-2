@echo off
REM Twenty-three lines and no more: this prints on an 80x25 screen with the
REM prompt underneath, and one line too many scrolls the title off the top.
echo.
echo  LESSON 3 - THE SCREEN, ONE BYTE AT A TIME
echo.
echo  One source, and the assembler that builds it. Nothing was installed
echo  and nothing was downloaded - this is DOSBox compiled to WebAssembly,
echo  running inside your browser tab.
echo.
echo    MAKE                assemble PIXEL.ASM
echo    RUN                 seven frames. A key moves on, Esc leaves.
echo.
echo      1 a dot             5 an outline, drawn ON TOP - the lines are
echo      2 every colour          still under it, and that is the lesson
echo      3 black             6 a filled square
echo      4 two lines         7 two hundred of them
echo.
echo  Then change it and build it again - that is the point of having the
echo  assembler in here rather than a video of one:
echo.
echo    EDIT PIXEL.ASM      the dot in frame 1 is colour 15, white. Try 4.
echo    MAKE
echo    RUN
echo.
