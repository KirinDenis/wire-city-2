@echo off
REM ============================================================================
REM BUILD.BAT - set Open Watcom up and build ED, from INSIDE DOSBox.
REM
REM WHY THIS FILE EXISTS AT ALL, and it is not tidiness.
REM
REM A DOSBox -c string must not end in a backslash: the backslash escapes the
REM closing quote, and DOSBox then swallows the -c that follows it. So
REM
REM     -c "set WATCOM=f:\" -c "set INCLUDE=f:\h"
REM
REM sets WATCOM to   f:" -c   and never sets INCLUDE at all - after which the
REM compiler cannot find stdio.h and says so in a way that looks like a
REM broken installation rather than a quoting bug. The lecture rig learned
REM this the expensive way and wrote it in WCENV.BAT's header; this build
REM walked into it anyway.
REM
REM In a batch file a backslash is just a backslash.
REM ============================================================================
set WATCOM=f:\
set INCLUDE=f:\h
set PATH=f:\binw;%PATH%
call MAKE.BAT %1
