@echo off
REM RUN.BAT - run lesson 3. A key moves to the next frame; there are six.
if not exist PIXEL.COM goto nobuild
PIXEL.COM
goto end
:nobuild
echo.
echo PIXEL.COM is not built yet. Type MAKE first.
:end
