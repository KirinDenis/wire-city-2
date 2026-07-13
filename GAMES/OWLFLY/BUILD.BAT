@echo off
REM Build OWL FLY inside DOS. Run from THIS folder with TASM + TLINK
REM on the path. Resources first: RESDAT becomes CITY.DAT, then the
REM game. NB: run res\mkpanel.py from Windows first if the cockpit
REM art changed - DOS only assembles what the converter wrote.
set PATH=c:\bp\bin;d:\bin;%PATH%
cd SRC
TASM /T RESDAT.ASM
if errorlevel 1 goto err
TLINK /t RESDAT.OBJ
if errorlevel 1 goto err
copy /y RESDAT.COM ..\INSTALL\CITY.DAT
del RESDAT.COM
TASM /T CITY.ASM
if errorlevel 1 goto err
TLINK /t CITY.OBJ
if errorlevel 1 goto err
copy /y CITY.COM ..\INSTALL\FLYOWL.COM
del CITY.COM
cd ..
echo.
echo OK -- run INSTALL\FLYOWL.COM
goto end
:err
cd ..
echo.
echo BUILD FAILED
:end
