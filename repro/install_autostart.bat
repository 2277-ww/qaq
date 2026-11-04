@echo off
rem Install (or reinstall) the logon autostart entry for the CTC web stack.
rem The entry is a tiny VBS in the per-user Startup folder that runs
rem C:\ctc\start_stack.ps1 with a hidden window.
rem NOTE: schtasks.exe is blocked by this machine's security policy,
rem       so the Startup folder is used instead of a scheduled task.
setlocal
set SRC=C:\ctc\launch_hidden.vbs
set PS1=C:\ctc\start_stack.ps1
set DST=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\CTC-Web-Stack.vbs

if not exist "%PS1%" (
  echo ERROR: %PS1% not found - install the runtime first.
  pause
  exit /b 1
)
if not exist "%SRC%" (
  echo ERROR: %SRC% not found - install the runtime first.
  pause
  exit /b 1
)

copy /Y "%SRC%" "%DST%" >nul
if errorlevel 1 (
  echo ERROR: could not write %DST%
  pause
  exit /b 1
)

echo Installed autostart entry:
echo   %DST%
echo   -^> powershell -File %PS1%  (hidden window)
echo.
echo It starts Redis + MySQL + PHP at every logon and runs a health check.
pause
endlocal
