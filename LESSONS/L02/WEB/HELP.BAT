@echo off
REM Twenty-three lines and no more: this prints on an 80x25 screen with the
REM prompt underneath, and one line too many scrolls the title off the top.
echo.
echo  LESSON 2 - THE FILE IS THE PROGRAM
echo.
echo  Three sources are here, and the assembler that builds them. Nothing
echo  was installed and nothing was downloaded - this is DOSBox compiled
echo  to WebAssembly, running inside your browser tab.
echo.
echo    MAKE                  assemble all three
echo    HEX HELLO.COM         look at the eighteen bytes you just made
echo    HELLO                 run it
echo.
echo  Now change the finished program without assembling anything. The
echo  text starts at offset 12 - that byte is the H of HELLO:
echo.
echo    HEX HELLO.COM 12 WORLD
echo    HELLO
echo.
echo  The source still says HELLO. The program does not. That is the lesson.
echo.
echo    EDIT HELLO.ASM        change the source instead, then MAKE again
echo    HEX HELLO2.EXE        the same program as an EXE, header and all
echo    HELP                  print this again
echo.
