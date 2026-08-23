@echo off
REM ============================================================================
REM MAKEWIN.BAT - build lesson 8 from Windows, without opening DOSBox by hand.
REM
REM   MAKEWIN         assemble it, exactly the way MAKE does inside DOS
REM   MAKEWIN RECON   assemble the lecture script reconstruction (RECON.ASM)
REM
REM It does not reimplement the build: it starts DOSBox and runs this folder
REM own MAKE.BAT with the argument EXIT, so the emulator closes itself when
REM the assembler is done. There is one build, and it is the DOS one.
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

if /i "%~1"=="RECON" goto recon

echo Assembling in DOS...
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "c:" -c "cd LESSONS\L08" -c "MAKE.BAT EXIT"
if not exist LESSONS\L08\SLANT.COM goto failed
echo.
echo Built LESSONS\L08\SLANT.COM
goto end

:recon
echo Assembling the reconstruction in DOS...
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "c:" -c "cd LESSONS\L08" -c "RECON.BAT"
if not exist LESSONS\L08\RECON.COM goto failed
fc /b LESSONS\L08\RECON.COM LESSONS\L08\SLANT.COM >nul
if errorlevel 1 goto rdiffer
echo.
echo The reconstruction assembles to the same bytes as SLANT.COM.
goto end
:rdiffer
echo.
echo RECON.COM and SLANT.COM DIFFER - the script does not type this program.
goto end

:failed
echo.
echo Build failed - see the messages above.
:end
