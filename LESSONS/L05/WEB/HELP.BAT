@echo off
REM Twenty-three lines and no more: this prints on an 80x25 screen with the
REM prompt underneath, and one line too many scrolls the title off the top.
echo.
echo  LESSON 5 - SIXTY-FIVE NUMBERS, AND WHAT THEY ARE FOR
echo.
echo  No sine instruction, no floating point, no division. Sixty-five whole
echo  numbers in SINT.INC, and a dozen instructions that unfold them into a
echo  whole circle. MKSIN.C is the C program that made them, on a machine
echo  that HAS floating point - it is here to read, not to build.
echo.
echo    MAKE                assemble TURN.ASM  (771 bytes)
echo    RUN                 four frames. A key moves on.
echo.
echo      1 the wave         the table drawn as what it is
echo      2 the ring         the same numbers, put on a radius
echo      3 the vector       the triangle those two numbers come from
echo      4 no multiply      the ring again in shifts and adds. The white
echo                         covers the red, and the strip stays black.
echo.
echo    EDIT TURN.ASM       RAD is 70. Try 40, or 95. Then MAKE and RUN.
echo                        Above 127 the ring turns inside out - the
echo                        comment beside IMUL says why.
echo.
