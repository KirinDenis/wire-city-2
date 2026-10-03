@echo off
REM ============================================================================
REM DISK.BAT - OWL FLY III BOND onto floppy images, from Windows.
REM
REM   DISK            ->  DISK\OWLFLY3B.IMG   720K 3.5", the Bondwell's drive
REM                       DISK\OWL360.IMG     360K 5.25", any IBM PC or XT
REM
REM The images are made and filled by DOSBox-X's own IMGMAKE and COPY - a
REM real DOS format, not a hand-built FAT. Boot DOS from its own disk, then
REM put this one in and type OWLFLY3B.
REM
REM Everything in INSTALL\ goes on the disk; INSTALL\ holds only what the
REM BOND loads. Since the cockpit is drawn instead of photographed that is
REM about 250K, which is why the 360K disk exists at all - it is the one a
REM stock XT (and PCjs's XT) can read. Build first with MAKEWIN.BAT.
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOXX%"=="" goto nox
if not exist GAMES\OWLFLY3B\INSTALL\OWLFLY3B.EXE goto noexe

set D=%CD%\GAMES\OWLFLY3B\DISK
if not exist "%D%" mkdir "%D%"
if exist "%D%\OWLFLY3B.IMG" del "%D%\OWLFLY3B.IMG"
if exist "%D%\OWL360.IMG" del "%D%\OWL360.IMG"
if exist "%D%\DISK.LOG" del "%D%\DISK.LOG"
REM ONE IMAGE PER DOSBox-X RUN. Both in one chain of -c lines made both
REM images and then never reached the closing "exit" - the window sat
REM there until it was killed (2026-10-02). Seven lines a run is the shape
REM that has always closed.
"%DOSBOXX%" -noautoexec -c "mount c %CD%\GAMES\OWLFLY3B" -c "c:" -c "imgmake %D%\OWLFLY3B.IMG -t fd_720" -c "imgmount a %D%\OWLFLY3B.IMG -t floppy" -c "copy c:\INSTALL\*.* a:\ > c:\DISK\DISK.LOG" -c "dir a:\ >> c:\DISK\DISK.LOG" -c "exit"
"%DOSBOXX%" -noautoexec -c "mount c %CD%\GAMES\OWLFLY3B" -c "c:" -c "imgmake %D%\OWL360.IMG -t fd_360" -c "imgmount a %D%\OWL360.IMG -t floppy" -c "copy c:\INSTALL\*.* a:\ >> c:\DISK\DISK.LOG" -c "dir a:\ >> c:\DISK\DISK.LOG" -c "exit"
if not exist "%D%\OWLFLY3B.IMG" goto failed
for %%A in ("%D%\OWLFLY3B.IMG") do if not %%~zA==737280 goto failed
if not exist "%D%\OWL360.IMG" goto failed
for %%A in ("%D%\OWL360.IMG") do if not %%~zA==368640 goto failed
type "%D%\DISK.LOG"
echo.
echo Built DISK\OWLFLY3B.IMG (720K) and DISK\OWL360.IMG (360K)
goto end

:nox
echo DOSBOXX is not set - see LOCAL.BAT. IMGMAKE is a DOSBox-X command.
goto end
:noexe
echo INSTALL\OWLFLY3B.EXE is not built. Run MAKEWIN.BAT first.
goto end
:failed
echo Making the disks failed - an image is missing or the wrong size.
:end
