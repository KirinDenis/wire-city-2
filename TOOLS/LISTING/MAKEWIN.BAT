@echo off
REM ============================================================================
REM MAKEWIN.BAT - build LISTING.EXE from Windows, without opening DOSBox by
REM hand.
REM
REM   MAKEWIN         assemble it, exactly the way MAKE does inside DOS
REM   MAKEWIN CHECK   assemble a second time with the Windows build of FASM
REM                   and compare - honest only while they agree
REM
REM It does not reimplement the build: it starts DOSBox and runs this
REM folder's own MAKE.BAT with the argument EXIT, so the emulator closes
REM itself when the assembler is done. There is one build, and it is the DOS
REM one - the one a reader with nothing but this repository will run.
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

if /i "%~1"=="CHECK" goto check

echo Assembling in DOS...
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "c:" -c "cd TOOLS\LISTING" -c "MAKE.BAT EXIT"
if not exist TOOLS\LISTING\LISTING.EXE goto failed
echo.
echo Built TOOLS\LISTING\LISTING.EXE
goto end

:check
echo Assembling with the Windows FASM for comparison...
TOOLS\FASM\WIN\FASM.EXE TOOLS\FASM\TOOLS\DOS\LISTING.ASM TOOLS\LISTING\LISTINGW.EXE
if errorlevel 1 goto failed
fc /b TOOLS\LISTING\LISTING.EXE TOOLS\LISTING\LISTINGW.EXE >nul
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
