@echo off
REM Build CITY.COM from CITY.ASM with Turbo Assembler
set PATH=c:\bp\bin;%PATH%
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