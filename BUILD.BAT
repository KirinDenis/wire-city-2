@echo off
REM Build WIRE CITY with Turbo Assembler (run INSIDE DOSBox).
REM Sources live in SRC (CITY.ASM includes the subsystem .INC modules);
REM the playable CITY.COM + CITY.DAT land in INSTALL.
REM NB: run res\mkpanel.py (Windows, Python+Pillow) first if the cockpit
REM art changed - or just use MAKE.BAT from Windows, it does both.
set PATH=c:\bp\bin;d:\bin;%PATH%
cd SRC
REM -- resources first: RESDAT.ASM assembles into a raw byte image --
TASM /T RESDAT.ASM
if errorlevel 1 goto err
TLINK /t RESDAT.OBJ
if errorlevel 1 goto err
copy /y RESDAT.COM ..\INSTALL\CITY.DAT >nul
del RESDAT.COM
REM -- the game itself --
TASM /T CITY.ASM
if errorlevel 1 goto err
TLINK /t CITY.OBJ
if errorlevel 1 goto err
copy /y CITY.COM ..\INSTALL\CITY.COM >nul
del CITY.COM
cd ..
echo.
echo OK -- run INSTALL\CITY.COM
goto end
:err
cd ..
echo.
echo BUILD FAILED
:end
