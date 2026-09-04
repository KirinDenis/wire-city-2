@echo off
REM ============================================================================
REM MAKEWIN.BAT - build the house lab from Windows, without opening DOSBox by
REM hand.
REM
REM   MAKEWIN         assemble it, exactly the way MAKE does inside DOS
REM   MAKEWIN CHECK   account for the difference against the Turbo Assembler
REM                   build in TASM\LAB
REM
REM It does not reimplement the build: it starts DOSBox and runs this folder's
REM own MAKE.BAT with the argument EXIT, so the emulator closes itself when
REM the assembler is done. There is one build, and it is the DOS one.
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

if /i "%~1"=="CHECK" goto check

echo Assembling in DOS...
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "c:" -c "cd LAB\HOUSE" -c "MAKE.BAT EXIT"
if not exist LAB\HOUSE\HOUSE.COM goto failed
echo.
echo Built LAB\HOUSE\HOUSE.COM
goto end

REM The two builds are NOT supposed to match - TASM pads with NOP where it
REM reserved room it could not take back - so what has to hold is that every
REM byte of the difference can be named.
:check
dotnet run --project TOOLS\BinAccount -c Release -- TASM\LAB\HOUSE.COM LAB\HOUSE\HOUSE.COM
goto end

:failed
echo.
echo Build failed - see the messages above.
:end
