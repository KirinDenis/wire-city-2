@echo off
REM Build TextShot.exe with the framework csc - no SDK, no dependencies.
REM Same recipe as Debug\BUILD.BAT.
cd /d %~dp0
set CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe
if not exist "%CSC%" set CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe
if not exist "%CSC%" echo csc.exe not found & exit /b 1
"%CSC%" /nologo /warn:0 /r:System.Drawing.dll /out:TextShot.exe TextShot.cs
if errorlevel 1 exit /b 1
echo OK -- TextShot.exe
