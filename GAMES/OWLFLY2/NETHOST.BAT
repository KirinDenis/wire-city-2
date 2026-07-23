@echo off
REM NETHOST.BAT - host an OWL FLY II sky: starts the IPXNET server on
REM UDP port 213 and takes off. Friends join with NETJOIN.BAT <your-ip>.
cd /d %~dp0
if exist ..\..\LOCAL.BAT call ..\..\LOCAL.BAT
if "%DOSBOX%"=="" set DOSBOX=dosbox.exe
"%DOSBOX%" -noautoexec -conf NET.CONF -c "ipxnet startserver 213" -c "mount c %~dp0INSTALL" -c "c:" -c "FLYOWL2"
