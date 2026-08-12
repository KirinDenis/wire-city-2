@echo off
REM ============================================================================
REM MAKEWIN.BAT - build the model precompiler from Windows.
REM
REM   MAKEWIN         assemble it, exactly the way MAKE does inside DOS
REM   MAKEWIN CHECK   account for the difference against the Turbo Assembler
REM                   build in TASM\TOOLS
REM
REM It drives this folder's own MAKE.BAT through DOSBox rather than repeating
REM the build. Note this is the DOS tool only; the C# converters in the
REM subdirectories are built by dotnet, from the root MAKEWIN.BAT.
REM ============================================================================
cd /d %~dp0..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

if /i "%~1"=="CHECK" goto check

echo Assembling in DOS...
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "c:" -c "cd TOOLS" -c "MAKE.BAT EXIT"
if not exist TOOLS\OBJ2DAT.COM goto failed
echo.
echo Built TOOLS\OBJ2DAT.COM
goto end

:check
dotnet run --project TOOLS\BinAccount -c Release -- TASM\TOOLS\OBJ2DAT.COM TOOLS\OBJ2DAT.COM
goto end

:failed
echo.
echo Build failed - see the messages above.
:end
