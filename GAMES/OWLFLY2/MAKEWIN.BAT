@echo off
REM ============================================================================
REM MAKEWIN.BAT - build OWL FLY II from Windows, without opening DOSBox.
REM
REM   MAKEWIN         the two blobs and the game, as MAKE does inside DOS
REM
REM Artwork, models or sounds changed? CONVERT.BAT in this folder runs the
REM .NET converters that turn them into what the game includes. Their output
REM is committed, so this build does not depend on it having run.
REM   MAKEWIN CHECK   account for the difference against the Turbo Assembler
REM                   build kept in TASM\OWLFLY2\INSTALL
REM
REM CHECK is done segment by segment, which is particular to this one: it is
REM an EXE of five segments, each padded to a fixed window, so the two builds
REM are the same LENGTH even where the code inside shrank. There is nothing
REM for the tool to infer from the file sizes, so each segment is cut out at
REM its last used byte and compared on its own, with the relocation window
REM given rather than deduced.
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe

if /i "%~1"=="CHECK" goto check
REM Artwork changed? Run CONVERT.BAT here first.

echo Assembling in DOS...
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "c:" -c "cd GAMES\OWLFLY2" -c "MAKE.BAT EXIT"
if not exist GAMES\OWLFLY2\INSTALL\FLYOWL2.EXE goto failed
echo.
echo Built GAMES\OWLFLY2\INSTALL\FLYOWL2.EXE
goto end

:check
echo === the blobs, which are data and must match exactly ===
fc /b TASM\OWLFLY2\INSTALL\CITY.DAT   GAMES\OWLFLY2\INSTALL\CITY.DAT
fc /b TASM\OWLFLY2\INSTALL\CPSIDE.DAT GAMES\OWLFLY2\INSTALL\CPSIDE.DAT
echo === the game, segment by segment ===
dotnet run --project TOOLS\BinAccount -c Release -- -exe TASM\OWLFLY2\INSTALL\FLYOWL2.EXE GAMES\OWLFLY2\INSTALL\FLYOWL2.EXE
goto end

:failed
echo.
echo Build failed - see the messages above.
:end
