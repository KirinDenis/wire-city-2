@echo off
REM ============================================================================
REM PLAYWIN.BAT - play one of the kit's templates in DOSBox, from Windows.
REM
REM   KIT\PLAYWIN T_ARCADE   (or T_SNAKE, T_BREAK, T_PLAT, T_FX, T_GRID, T_FLY,
REM                           T_OBJ3D, T_ROOM, T_NET, T_BLANK)
REM
REM With sound. DOSBox closes when the game quits to DOS (Esc).
REM ============================================================================
cd /d %~dp0..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe
if "%1"=="" goto usage
if not exist KIT\%1\%1.COM goto nocom
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "c:" -c "cd KIT\%1" -c "%1" -c "exit"
goto end
:nocom
echo KIT\%1\%1.COM is not built: KIT\MAKEWIN %1 %1
goto end
:usage
echo Usage: KIT\PLAYWIN T_ARCADE
:end