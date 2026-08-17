@echo off
REM ============================================================================
REM MAKEWIN.BAT - build MENU.COM from Windows, without opening DOSBox by
REM hand.
REM
REM   MAKEWIN         assemble it, exactly the way MAKE does inside DOS
REM   MAKEWIN CHECK   assemble a second time with the Windows build of FASM
REM                   and compare - honest only while they agree
REM
REM It does not reimplement the build: it starts DOSBox and runs this
REM folder's own MAKE.BAT with the argument EXIT. There is one build, and
REM it is the DOS one.
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

if /i "%~1"=="CHECK" goto check
if /i "%~1"=="RECON" goto recon

echo Assembling in DOS...
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "c:" -c "cd TOOLS\MENU" -c "MAKE.BAT EXIT"
if not exist TOOLS\MENU\MENU.COM goto failed
echo.
echo Built TOOLS\MENU\MENU.COM
goto end

:recon
echo Assembling the reconstruction in DOS...
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "c:" -c "cd TOOLS\MENU" -c "RECON.BAT"
if not exist TOOLS\MENU\RECON.COM goto failed
fc /b TOOLS\MENU\RECON.COM TOOLS\MENU\MENU.COM >nul
if errorlevel 1 goto rdiffer
echo.
echo The reconstruction assembles to the same bytes as MENU.COM.
goto end
:rdiffer
echo.
echo RECON.COM and MENU.COM DIFFER - the script does not type this program.
goto end

:check
echo Assembling with the Windows FASM for comparison...
TOOLS\FASM\WIN\FASM.EXE TOOLS\MENU\MENU.ASM TOOLS\MENU\MENUW.COM
if errorlevel 1 goto failed
fc /b TOOLS\MENU\MENU.COM TOOLS\MENU\MENUW.COM >nul
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
