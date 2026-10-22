@echo off
REM ============================================================================
REM MAKEWIN.BAT - build MULTIPLAY SOKO II from Windows, without opening DOSBox
REM by hand.
REM
REM   MAKEWIN         assemble it, exactly the way MAKE does inside DOS
REM   MAKEWIN CHECK   assemble it a second time with the Windows build of
REM                   FASM into MULTSOK2W.COM and ARTW.DAT and compare
REM
REM It does not reimplement the build: it starts DOSBox and runs this folder's
REM own MAKE.BAT EXIT. There is one build, and it is the DOS one.
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

if /i "%~1"=="CHECK" goto check

echo Assembling in DOS...
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "c:" -c "cd GAMES\MULTSOK2" -c "MAKE.BAT EXIT"
if not exist GAMES\MULTSOK2\MULTSOK2.COM goto failed
echo.
echo Built GAMES\MULTSOK2\ART.DAT, ARTF.DAT, LEVELS.DAT and MULTSOK2.COM
goto end

:check
echo Assembling with the Windows FASM for comparison...
TOOLS\FASM\WIN\FASM.EXE GAMES\MULTSOK2\ART.ASM GAMES\MULTSOK2\ARTW.DAT
if errorlevel 1 goto failed
TOOLS\FASM\WIN\FASM.EXE GAMES\MULTSOK2\ARTF.ASM GAMES\MULTSOK2\ARTFW.DAT
if errorlevel 1 goto failed
TOOLS\FASM\WIN\FASM.EXE GAMES\MULTSOK2\LEVELS.ASM GAMES\MULTSOK2\LEVELSW.DAT
if errorlevel 1 goto failed
TOOLS\FASM\WIN\FASM.EXE GAMES\MULTSOK2\MULTSOK2.ASM GAMES\MULTSOK2\MULTSOK2W.COM
if errorlevel 1 goto failed
fc /b GAMES\MULTSOK2\ART.DAT GAMES\MULTSOK2\ARTW.DAT >nul
if errorlevel 1 goto differ
fc /b GAMES\MULTSOK2\ARTF.DAT GAMES\MULTSOK2\ARTFW.DAT >nul
if errorlevel 1 goto differ
fc /b GAMES\MULTSOK2\LEVELS.DAT GAMES\MULTSOK2\LEVELSW.DAT >nul
if errorlevel 1 goto differ
fc /b GAMES\MULTSOK2\MULTSOK2.COM GAMES\MULTSOK2\MULTSOK2W.COM >nul
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
