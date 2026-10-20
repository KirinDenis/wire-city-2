@echo off
REM ============================================================================
REM MAKEWIN.BAT - build MULTSOKO from Windows, without opening DOSBox by hand.
REM
REM   MAKEWIN         assemble it, exactly the way MAKE does inside DOS
REM   MAKEWIN CHECK   assemble it a second time with the Windows build of
REM                   FASM into MULTSOKOW.COM and compare the two
REM
REM It does not reimplement the build: it starts DOSBox and runs this folder's
REM own MAKE.BAT EXIT. There is one build, and it is the DOS one.
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

if /i "%~1"=="CHECK" goto check

echo Assembling in DOS...
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "c:" -c "cd GAMES\MULTSOKO" -c "MAKE.BAT EXIT"
if not exist GAMES\MULTSOKO\MULTSOKO.COM goto failed
echo.
echo Built GAMES\MULTSOKO\MULTSOKO.COM
goto end

:check
echo Assembling with the Windows FASM for comparison...
TOOLS\FASM\WIN\FASM.EXE GAMES\MULTSOKO\MULTSOKO.ASM GAMES\MULTSOKO\MULTSOKOW.COM
if errorlevel 1 goto failed
fc /b GAMES\MULTSOKO\MULTSOKO.COM GAMES\MULTSOKO\MULTSOKOW.COM >nul
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
