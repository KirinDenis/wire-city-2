@echo off
REM ============================================================================
REM RUN.BAT - run lesson 10.
REM
REM Seven stages. A key moves the still one on; a key STOPS the moving ones.
REM
REM   1 the world from the origin      2 move an OBJECT - one row changes
REM   3 move the WORLD - every row     4 move the CAMERA - and it looks the
REM                                      same as stage 3 did
REM   5 both at once, grey under white, red where they disagree
REM   6 turn the camera - the world swings the other way
REM   7 FLY IT: the arrow keys walk and turn. ESC ends the program.
REM ============================================================================
if not exist CAM.COM goto nothing
echo CAM.COM
CAM.COM
goto end
:nothing
echo.
echo CAM.COM is not built yet. Type MAKE first - this course ships the
echo source and the assembler, never the program.
:end
