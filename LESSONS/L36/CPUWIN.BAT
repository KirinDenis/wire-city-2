@echo off
REM ============================================================================
REM CPUWIN.BAT - run CPU4 on processors DOSBox cannot be, from Windows.
REM
REM   CPUWIN 8086     CPUWIN 286     CPUWIN 386
REM   CPUWIN 486old   CPUWIN 486     CPUWIN pentium
REM
REM DOSBox and the course page are a 386, a 486 or a Pentium. DOSBox-X can
REM also be an 8086 or a 286 - the two branches of CPU2 no other emulator
REM here can reach. LOCAL.BAT says where DOSBox-X lives (DOSBOXX).
REM
REM Build first (MAKEWIN). DOSBox-X opens, runs CPU4 on the processor named,
REM and waits at the prompt: look, then type EXIT.
REM ============================================================================
cd /d %~dp0..\..
if exist LOCAL.BAT call .\LOCAL.BAT
if "%DOSBOXX%"=="" goto nox
if "%~1"=="" goto usage
if not exist LESSONS\L36\CPU4.COM goto nobuild

"%DOSBOXX%" -nopromptfolder -set "cpu cputype=%~1" -set "cpu core=normal" -set "cpu cycles=fixed 3000" -c "mount c %CD%" -c "c:" -c "cd LESSONS\L36" -c "CPU4.COM"
goto end

:usage
echo Say which processor: CPUWIN 8086, 286, 386, 486old, 486 or pentium.
goto end
:nox
echo LOCAL.BAT did not set DOSBOXX - point it at dosbox-x.exe.
goto end
:nobuild
echo LESSONS\L36\CPU4.COM is not built yet - run MAKEWIN first.
:end
