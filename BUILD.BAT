@echo off
REM Build CITY.COM with Turbo Assembler.
REM CITY.ASM is the main file; it INCLUDEs the subsystem modules:
REM   DATA.INC KEYB.INC VIDEO.INC M3D.INC RASTER.INC TERRAIN.INC
REM   SCENE.INC WORLD.INC WORLD2.INC FLIGHT.INC HUD.INC
REM One TASM pass assembles everything (no separate linking of modules).
set PATH=c:\bp\bin;%PATH%
REM -- resources first: RESDAT.ASM assembles into a raw byte image --
TASM /T RESDAT.ASM
if errorlevel 1 goto err
TLINK /t RESDAT.OBJ
if errorlevel 1 goto err
copy /y RESDAT.COM CITY.DAT >nul
del RESDAT.COM
REM -- the game itself --
TASM /T CITY.ASM
if errorlevel 1 goto err
TLINK /t CITY.OBJ
if errorlevel 1 goto err
echo.
echo OK -- run CITY.COM
goto end
:err
echo.
echo BUILD FAILED
:end
