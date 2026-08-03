@echo off
REM Build the house lab inside DOS. Run from THIS folder (LAB) with
REM TASM + TLINK on the path. HOUSE.COM stays here.
set PATH=c:\bp\bin;d:\bin;%PATH%
TASM /T HOUSE.ASM
if errorlevel 1 goto err
TLINK /t HOUSE.OBJ
if errorlevel 1 goto err
echo.
echo OK -- HOUSE.COM
goto end
:err
echo.
echo BUILD FAILED
:end
