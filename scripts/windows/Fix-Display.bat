@echo off
REM ============================================================================
REM  Fix-Display.bat - convenience wrapper for the PowerShell tools.
REM  Part of the ProLiant-ML10-Graphics-fix repository (MIT).
REM
REM  Usage:
REM    Fix-Display.bat                 show current mode(s)
REM    Fix-Display.bat info            full graphics inventory
REM    Fix-Display.bat list            list all supported modes
REM    Fix-Display.bat best            set the highest mode
REM    Fix-Display.bat set 1366 768    set a specific mode
REM    Fix-Display.bat install [path]  install the Intel graphics driver
REM    Fix-Display.bat drivers         list installed display driver packages
REM ============================================================================
setlocal
set "HERE=%~dp0"

set "PS=powershell -NoProfile -ExecutionPolicy Bypass"

if /I "%~1"=="info" (
  %PS% -File "%HERE%Get-GraphicsInfo.ps1"
  goto :end
)
if /I "%~1"=="list" (
  %PS% -File "%HERE%Set-DisplayResolution.ps1" -List
  goto :end
)
if /I "%~1"=="best" (
  %PS% -File "%HERE%Set-DisplayResolution.ps1" -Best
  goto :end
)
if /I "%~1"=="install" (
  if "%~2"=="" (
    %PS% -File "%HERE%Install-IntelGraphicsDriver.ps1"
  ) else (
    %PS% -File "%HERE%Install-IntelGraphicsDriver.ps1" -Path "%~2"
  )
  goto :end
)
if /I "%~1"=="drivers" (
  %PS% -File "%HERE%Install-IntelGraphicsDriver.ps1" -List
  goto :end
)
if /I "%~1"=="set" (
  if "%~2"=="" (
    echo Usage: Fix-Display.bat set ^<width^> ^<height^> [refresh]
    goto :end
  )
  if "%~3"=="" (
    echo Usage: Fix-Display.bat set ^<width^> ^<height^> [refresh]
    goto :end
  )
  if "%~4"=="" (
    %PS% -File "%HERE%Set-DisplayResolution.ps1" -Width %~2 -Height %~3
  ) else (
    %PS% -File "%HERE%Set-DisplayResolution.ps1" -Width %~2 -Height %~3 -Refresh %~4
  )
  goto :end
)

REM default: show current
%PS% -File "%HERE%Set-DisplayResolution.ps1" -Current

:end
endlocal
