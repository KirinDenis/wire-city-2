@echo off
REM ============================================================================
REM PUBLISH.BAT [game] ["message"] - deploy a game bundle to GitHub Pages.
REM   PUBLISH                 - publish OWLFLY (default)
REM   PUBLISH WIRECITY        - publish the 1986 original
REM   PUBLISH OWLFLY "msg"    - with a commit message
REM Steps: pack a fresh <game>_vN.jsdos (new filename busts the js-dos
REM IndexedDB cache), patch the player page, then confirm + git push.
REM ============================================================================
setlocal
cd /d %~dp0
set GAME=%~1
if "%GAME%"=="" set GAME=OWLFLY

echo [1/2] Packing a fresh %GAME% bundle ...
powershell -NoProfile -ExecutionPolicy Bypass -File docs\pack.ps1 -Game %GAME%
if errorlevel 1 goto fail

echo [2/2] Commit + push ...
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
