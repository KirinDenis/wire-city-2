@echo off
REM ============================================================================
REM CONVERT.BAT - prepare OWL FLY's instrument panel and engine sample.
REM
REM   CONVERT
REM
REM These run BEFORE the DOS build and turn the drawn panel and a recorded
REM engine note into the byte tables the game includes. Their output is
REM committed, so a plain MAKEWIN does not need this to have run - only a
REM change to the artwork does.
REM
REM THESE TWO ARE PYTHON, and they are the last of it. The project's tooling
REM contract is C#; OWL FLY II's equivalents went that way and these did not,
REM because nothing has needed to touch them. If Python is not installed the
REM committed output is used and the build works.
REM
REM They came out of the repository-wide MAKEWIN.BAT when the last program
REM finished migrating and that file was retired.
REM ============================================================================
cd /d %~dp0..\..

echo === the instrument panel ===
python GAMES\OWLFLY\res\mkpanel.py
if errorlevel 1 goto skipped

echo === the engine sample ===
python GAMES\OWLFLY\res\mkengine.py
if errorlevel 1 goto skipped

echo.
echo Done. Now build it: MAKEWIN, in the game's folder.
goto end

:skipped
echo.
echo A converter did not run - the committed output will be used instead.

:end
