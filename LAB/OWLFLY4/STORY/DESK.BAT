@echo off
REM ============================================================================
REM DESK.BAT - open a story in SceneDesk, the production desk.
REM
REM   LAB\OWLFLY4\STORY\DESK.BAT            opens NIGHT
REM   LAB\OWLFLY4\STORY\DESK.BAT OTHER      opens STORY\OTHER\
REM
REM Windows-side: the desk is a WPF program, built from source on the spot by
REM "dotnet run" like every other C# tool here. Each story is a folder beside
REM this file, with STORY.INI and one subfolder per scene holding SCENE.INI
REM and what the game reads; its raw material is in the warehouse named
REM INSIDE STORY.INI, outside the repository.
REM
REM If the desk is ALREADY OPEN, the build cannot replace its .exe and this
REM launches nothing new. The pause below is so that failure is seen rather
REM than mistaken for "nothing changed".
REM ============================================================================
set STORY=%1
if "%STORY%"=="" set STORY=NIGHT
cd /d %~dp0..\..\..
dotnet run --project TOOLS\SceneDesk -c Release -- LAB\OWLFLY4\STORY\%STORY%
if errorlevel 1 (
  echo.
  echo The desk did not build or did not start. If it is already open, close it first.
  pause
)
