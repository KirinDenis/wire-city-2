@echo off
REM RUN.BAT - the BROWSER copy. A key moves to the next frame; there are six.
if not exist PIXEL.COM goto nobuild
PIXEL.COM
goto end
:nobuild
echo.
echo PIXEL.COM is not built yet. Type MAKE first - that is the lesson.
:end
