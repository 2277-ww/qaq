@echo off
rem Thin wrapper - the real implementation lives in C:\ctc\start_stack.ps1,
rem which is also what the Startup-folder entry runs at logon.
rem Usage: start_all.bat          (pauses when done)
rem        start_all.bat /nopause (no pause)
if not exist "C:\ctc\start_all.bat" (
  echo ERROR: C:\ctc\start_all.bat not found. The runtime lives in C:\ctc.
  pause
  exit /b 1
)
call "C:\ctc\start_all.bat" %*
exit /b %ERRORLEVEL%
