@echo off
REM ============================================================================
REM MAKEWIN.BAT - build the teaching machines from Windows, without opening
REM DOSBox by hand.
REM
REM   MAKEWIN         all thirteen
REM   MAKEWIN JET     just that one - JET.ASM and JET.COM do as well, since
REM                   Tab completion will hand you one of those
REM   MAKEWIN CHECK   account for the difference between every one of them and
REM                   the Turbo Assembler builds in TASM\EXAMPLES
REM
REM It does not reimplement the build: it starts DOSBox and runs this folder's
REM own MAKE.BAT, with the argument EXIT so the emulator closes itself when
REM the assembler is done. There is one build, and it is the DOS one.
REM ============================================================================
cd /d %~dp0..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

if /i "%~1"=="CHECK" goto check
set WHAT=%~n1

echo Assembling in DOS...
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "c:" -c "cd EXAMPLES" -c "MAKE.BAT %WHAT% EXIT"
echo.
REM Show what was actually asked for. Listing all thirteen after building one
REM reads as though all thirteen were rebuilt.
if "%WHAT%"=="" dir /b EXAMPLES\*.COM 2>nul
if not "%WHAT%"=="" dir /b EXAMPLES\%WHAT%.COM 2>nul
goto end

REM The accounting, which is what makes the port provable. The two builds are
REM NOT supposed to match - TASM pads with NOP where it reserved room it could
REM not take back - so what has to hold is that every byte of the difference
REM can be named. BinAccount decodes both and stops at anything it cannot.
:check
for %%P in (TERRA RING SPOOL FLIGHT LAND LNDPHYS TKOFF TKPHYS SMOKE AVIO JET SOLO BBS) do (
  if exist EXAMPLES\%%P.COM if exist TASM\EXAMPLES\%%P.COM (
    echo === %%P ===
    dotnet run --project TOOLS\BinAccount -c Release -- TASM\EXAMPLES\%%P.COM EXAMPLES\%%P.COM
  )
)

:end
