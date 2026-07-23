@echo off
REM NETJOIN.BAT [host-ip] - join an OWL FLY II sky. Default host is
REM this machine (two windows side by side is the dogfight lab).
cd /d %~dp0
if exist ..\..\LOCAL.BAT call ..\..\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe
set HOSTIP=%~1
if "%HOSTIP%"=="" set HOSTIP=127.0.0.1
"%DOSBOX%" -noautoexec -conf NET.CONF -c "ipxnet connect %HOSTIP% 213" -c "mount c %~dp0INSTALL" -c "c:" -c "FLYOWL2"
