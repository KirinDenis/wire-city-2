@echo off
REM ============================================================================
REM MAKEPROBE.BAT - compile and RUN PROBE.PAS, then close DOSBox.
REM
REM   MAKEPROBE        measure; PROBE.LOG is the answer
REM   MAKEPROBE SHOW   ...and leave the palette swatches on screen to look at
REM
REM The measuring run must not wait for a key: the whole point is that the
REM numbers come back without anybody watching.
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe
if "%TASMDIR%"=="" (
  echo LOCAL.BAT did not set TASMDIR - point it at Borland Pascal.
  goto end
)
if /i "%~1"=="SHOW" goto show
"%DOSBOX%" -noautoexec -noconsole -c "mount c %CD%" -c "mount d %TASMDIR%" -c "c:" -c "cd LESSONS\L18" -c "D:\BIN\TPC.EXE -B -UD:\UNITS PROBE.PAS > TPC.LOG" -c "PROBE.EXE" -c "exit"
goto end
:show
"%DOSBOX%" -noautoexec -c "mount c %CD%" -c "mount d %TASMDIR%" -c "c:" -c "cd LESSONS\L18" -c "D:\BIN\TPC.EXE -B -UD:\UNITS PROBE.PAS" -c "PROBE.EXE SHOW"
:end