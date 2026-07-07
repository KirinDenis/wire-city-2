@echo off
REM ============================================================================
REM PUBLISH.BAT - deploy the current build to GitHub Pages. Run it from
REM Windows AFTER building CITY.COM in DOSBox (BUILD.BAT) and checking it.
REM
REM   PUBLISH "message"   - commit message for git (optional)
REM
REM Steps: 1) repack docs\city.jsdos from CITY.COM
REM        2) bump the cache-busting ?v=N in docs\index.html
REM        3) git add + commit + push  ->  Pages redeploys in ~1 minute
REM ============================================================================
setlocal
cd /d %~dp0

if not exist CITY.COM (
  echo ERROR: CITY.COM not found - build it in DOSBox first ^(BUILD.BAT^)
  exit /b 1
)

echo [1/3] Packing docs\city.jsdos ...
powershell -NoProfile -ExecutionPolicy Bypass -File docs\pack.ps1
if errorlevel 1 goto fail

echo [2/3] Bumping cache version in docs\index.html ...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p='docs/index.html'; $s=Get-Content $p -Raw;" ^
  "$m=[regex]::Match($s,'city\.jsdos\?v=(\d+)');" ^
  "if(-not $m.Success){ Write-Error 'version tag not found'; exit 1 };" ^
  "$n=[int]$m.Groups[1].Value+1;" ^
  "$s=$s -replace 'city\.jsdos\?v=\d+',('city.jsdos?v='+$n);" ^
  "Set-Content -Encoding ascii $p $s; Write-Host ('  -> v='+$n)"
if errorlevel 1 goto fail

echo [3/3] Commit + push ...
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
