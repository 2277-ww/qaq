@echo off
rem Thin wrapper - the real implementation lives in C:\ctc\stop_stack.ps1.
rem Usage: stop_all.bat          (pauses when done)
rem        stop_all.bat /nopause (no pause)
if not exist "C:\ctc\stop_all.bat" (
  echo ERROR: C:\ctc\stop_all.bat not found. The runtime lives in C:\ctc.
  pause
  exit /b 1
)
call "C:\ctc\stop_all.bat" %*
exit /b %ERRORLEVEL%
