@echo off
REM Build NEWTON inside DOS. Run from THIS folder with TASM + TLINK on
REM the path; the repo root must be the C: drive (SRC includes ENGINE\
REM through ..\..\..). No model precompiler yet - NEWTON has no DAT.
set PATH=c:\bp\bin;d:\bin;%PATH%
cd SRC
TASM /T NEWTON.ASM
if errorlevel 1 goto errs
TLINK /t NEWTON.OBJ
if errorlevel 1 goto errs
copy /y NEWTON.COM ..
del NEWTON.COM
cd ..
echo.
echo OK -- NEWTON built
goto end
:errs
cd ..
echo.
echo BUILD FAILED
:end
