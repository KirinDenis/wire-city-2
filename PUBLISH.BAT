@echo off
REM ============================================================================
REM PUBLISH.BAT - deploy the current build to GitHub Pages. Run it from
REM Windows AFTER building via MAKE.BAT and checking INSTALL\CITY.COM.
REM
REM   PUBLISH "message"   - commit message for git (optional)
REM
REM Steps: 1) repack docs\city.jsdos from CITY.COM
REM        2) bump the cache-busting ?v=N in docs\index.html
REM        3) git add + commit + push  ->  Pages redeploys in ~1 minute
REM ============================================================================
setlocal
cd /d %~dp0

if not exist INSTALL\CITY.COM (
  echo ERROR: INSTALL\CITY.COM not found - build it first ^(MAKE.BAT^)
  exit /b 1
)

echo [1/2] Packing a fresh versioned bundle (city_vN.jsdos) ...
REM the new FILENAME each release busts js-dos's IndexedDB bundle cache
REM (a ?v= query does not - pack.ps1 renames it and patches index.html)
powershell -NoProfile -ExecutionPolicy Bypass -File docs\pack.ps1
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
set MSG=%~1
if "%MSG%"=="" set MSG=publish build
git add -A
git commit -m "%MSG%"
git push
if errorlevel 1 goto fail

echo.
echo OK - Pages will redeploy in about a minute:
echo   https://kirindenis.github.io/wire-city-2/   (Ctrl+Shift+R in the browser)
exit /b 0

:fail
echo.
echo PUBLISH FAILED - nothing (or only part) was deployed. Check the error above.
exit /b 1
