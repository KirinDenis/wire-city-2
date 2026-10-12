@echo off
REM ============================================================================
REM PUBLISH.BAT [game] ["message"] - deploy a game bundle to GitHub Pages.
REM   PUBLISH                 - publish OWLFLY2, the game being worked on
REM   PUBLISH OWLFLY          - the 40 KB predecessor (finished, archived)
REM   PUBLISH WIRECITY        - publish the 1986 original
REM   PUBLISH OWLFLY2 "msg"   - with a commit message
REM Steps: pack a fresh <game>_vN.jsdos (new filename busts the js-dos
REM IndexedDB cache), patch the player page, then confirm + git push.
REM
REM The default moved from OWLFLY to OWLFLY2 on 2026-07-28. It had been
REM pointing at the finished predecessor, so a bare PUBLISH shipped a
REM byte-for-byte identical bundle under a new version number - the push
REM went through, the page reloaded, and the new feature was never in it.
REM Per-game wrappers (GAMES\<game>\PUBLISH.BAT) say it out loud instead.
REM ============================================================================
setlocal
cd /d %~dp0
set GAME=%~1
if "%GAME%"=="" set GAME=OWLFLY2

if /i "%GAME%"=="OWLVID" goto owlnight
echo [1/2] Packing a fresh %GAME% bundle ...
powershell -NoProfile -ExecutionPolicy Bypass -File docs\pack.ps1 -Game %GAME%
if errorlevel 1 goto fail
if /i not "%GAME%"=="OWLFLY3" goto packed
REM OWL FLY III ships as TWO bundles - the colour machine and the Hercules
REM machine - and they publish together or the pages tell different
REM versions of the game.
echo [1b/2] ...and the Hercules edition ...
powershell -NoProfile -ExecutionPolicy Bypass -File docs\pack.ps1 -Game OWLFLY3H
if errorlevel 1 goto fail
goto packed

REM OWL NIGHT is not a bundle: its clips, rooms and music are assets of a
REM GitHub RELEASE (up to 2 GB each, outside the repository), and the page
REM fetches them one by one into the emulator before it boots. The packer
REM stages them and writes the manifest the page reads; the upload itself
REM is gh commands in docs\owlnight\upload.cmd, run by hand, because it is
REM publishing. The commit below carries the manifest and the page only.
:owlnight
echo [1/3] Staging OWL NIGHT for its release ...
powershell -NoProfile -ExecutionPolicy Bypass -File docs\pack-night.ps1
if errorlevel 1 goto fail
echo.
echo [2/3] Upload the changed assets - this talks to GitHub:
echo       docs\owlnight\upload.cmd
echo.
set /p UP=Run it now? [y/N]
if /i "%UP%"=="y" call docs\owlnight\upload.cmd
if errorlevel 1 goto fail
goto packed
:packed

if /i "%GAME%"=="OWLVID" (echo [3/3] Commit + push ...) else (echo [2/2] Commit + push ...)
echo.
echo --- files that will be committed to the PUBLIC repo: ---
git status --short
echo ---------------------------------------------------------
set /p CONFIRM=Publish these files? [y/N]
if /i not "%CONFIRM%"=="y" (
  echo Aborted - nothing was committed or pushed.
  exit /b 1
)
set MSG=%~2
if "%MSG%"=="" set MSG=publish %GAME% build
git add -A
git commit -m "%MSG%"
git push
if errorlevel 1 goto fail
echo.
echo OK - Pages will redeploy in about a minute.
exit /b 0
:fail
echo.
echo PUBLISH FAILED - nothing (or only part) was deployed.
exit /b 1
