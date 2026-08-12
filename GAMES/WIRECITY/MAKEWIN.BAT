@echo off
REM ============================================================================
REM MAKEWIN.BAT - build WIRE CITY from Windows, without opening DOSBox by hand.
REM
REM   MAKEWIN         assemble it, exactly the way MAKE does inside DOS
REM   MAKEWIN CHECK   assemble it a second time with the Windows build of
REM                   FASM and compare - see below
REM
REM It does not reimplement the build: it starts DOSBox and runs this folder's
REM own MAKE.BAT - with the argument EXIT, so the emulator closes itself when
REM the assembler is done. There is one build, and it is the DOS one, which is
REM also the one a reader with nothing but this repository will run.
REM
REM CHECK exists because the Windows FASM is far quicker, and it is only
REM honest to lean on it if it agrees with the DOS one. It writes CITYW.COM
REM (never CITY.COM, so nothing is overwritten) and compares the two. They
REM have matched byte for byte since the day both first ran.
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

if /i "%~1"=="CHECK" goto check

echo Assembling in DOS...
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "c:" -c "cd GAMES\WIRECITY" -c "MAKE.BAT EXIT"
if not exist GAMES\WIRECITY\CITY.COM goto failed
echo.
echo Built GAMES\WIRECITY\CITY.COM
goto end

:check
echo Assembling with the Windows FASM for comparison...
TOOLS\FASM\WIN\FASM.EXE GAMES\WIRECITY\CITY.ASM GAMES\WIRECITY\CITYW.COM
if errorlevel 1 goto failed
fc /b GAMES\WIRECITY\CITY.COM GAMES\WIRECITY\CITYW.COM >nul
if errorlevel 1 goto differ
echo.
echo The DOS and Windows assemblers agree, byte for byte.
goto end

:differ
echo.
echo THEY DIFFER. The Windows assembler is no longer a safe stand-in for the
echo DOS one - find out why before trusting either.
goto end

:failed
echo.
echo Build failed - see the messages above.
:end
