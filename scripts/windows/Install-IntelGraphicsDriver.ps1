<#
.SYNOPSIS
  Stage an Intel graphics driver package on Windows / Windows Server.

.DESCRIPTION
  Windows Server does not ship an Intel driver for the HD Graphics P530
  (DEV_191D); it uses the "Microsoft Basic Display Adapter". This script helps
  you install the Windows 10/11 Intel driver package by:

    1. Verifying the GPU is present (Ven_8086&Dev_191D).
    2. Locating an INF inside a folder you extracted the driver to.
    3. Staging it with `pnputil`.
    4. Telling you exactly what to do in Device Manager if the driver stages but
       does not bind (the usual "not supported on this OS" situation).

  It does NOT download drivers (Microsoft/Intel do not offer a stable direct
  URL); download the Intel driver package yourself, extract it, then point this
  script at the folder.

.PARAMETER Path
  Folder containing the extracted Intel driver (searched recursively for
  igdlh64.inf / iigd_dch.inf / *.inf with "Intel" graphics).

.PARAMETER List
  Only list currently installed display drivers (no changes).

.EXAMPLE
  .\Install-IntelGraphicsDriver.ps1 -List

.EXAMPLE
  .\Install-IntelGraphicsDriver.ps1 -Path C:\SWSetup\Intel\Graphics

.NOTES
  Run as Administrator. Part of the ProLiant-ML10-Graphics-fix repository (MIT).
#>
[CmdletBinding(DefaultParameterSetName = 'Install')]
param(
    [Parameter(ParameterSetName = 'Install')][string]$Path,
    [Parameter(ParameterSetName = 'List')][switch]$List
)

$ErrorActionPreference = 'Stop'

function Test-GpuPresent {
    $found = Get-CimInstance Win32_VideoController |
        Where-Object { $_.PNPDeviceID -match 'VEN_8086&DEV_191D' }
    if ($found) {
        Write-Host ('Found GPU: {0}  ({1})' -f $found.Name, $found.PNPDeviceID) -ForegroundColor Green
        return $true
    }
    Write-Warning 'No Intel HD Graphics P530 (VEN_8086&DEV_191D) found on this machine.'
    Write-Host  'Current adapters:'
    Get-CimInstance Win32_VideoController | ForEach-Object { '  - {0}' -f $_.Name }
    return $false
}

if ($List) {
    Write-Host '===== Installed display driver packages ====='
    pnputil /enum-drivers | Select-String -Pattern 'Published Name|Original Name|Provider Name|Class Name' -Context 0,0
    Write-Host ''
    Write-Host '===== Display adapters ====='
    Get-PnpDevice -Class Display | Format-Table Status, FriendlyName, InstanceId -AutoSize
    return
}

if (-not $Path) {
    throw "Provide -Path <folder with the extracted Intel driver>, or -List to inspect."
}
if (-not (Test-Path $Path)) { throw "Path not found: $Path" }

Write-Host 'Checking hardware ...'
[void](Test-GpuPresent)

Write-Host ''
Write-Host 'Searching for an Intel graphics INF ...'
$candidates = Get-ChildItem -Path $Path -Recurse -Filter *.inf -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'igdlh64|iigd_dch|kit\d+\.inf|^igdlh' }

if (-not $candidates) {
    # fall back: any INF mentioning the device id
    $candidates = Get-ChildItem -Path $Path -Recurse -Filter *.inf -ErrorAction SilentlyContinue |
        Where-Object { (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue) -match 'DEV_191D' }
}

if (-not $candidates) {
    throw "No Intel graphics INF found under '$Path'. Extract the driver package fully and try again."
}

$inf = $candidates | Select-Object -First 1
Write-Host ('Using INF: {0}' -f $inf.FullName) -ForegroundColor Cyan

Write-Host ''
Write-Host 'Staging driver with pnputil ...'
$result = & pnputil /add-driver "$($inf.FullName)" /install 2>&1
$result | Write-Host

if ($LASTEXITCODE -eq 0) {
    Write-Host ''
    Write-Host 'Driver staged. If it did not bind automatically, finish in Device Manager:' -ForegroundColor Yellow
    Write-Host '  Device Manager -> Display adapters -> Microsoft Basic Display Adapter'
    Write-Host '  -> Update driver -> Browse my computer -> Let me pick -> Have Disk'
    Write-Host ("  -> point to: {0}" -f $inf.FullName)
    Write-Host '  -> choose "Intel(R) HD Graphics P530" -> accept the compatibility warning.'
    Write-Host ''
    Write-Host 'Then reboot and verify with: Get-GraphicsInfo.ps1'
} else {
    Write-Warning "pnputil returned $LASTEXITCODE. Use the manual Device Manager 'Have Disk' method."
}

Write-Host ''
Write-Host 'Reminder: if the monitor is not detected (no EDID through a passive adapter),' -ForegroundColor Yellow
Write-Host 'the driver alone will not fix it - use an ACTIVE DisplayPort adapter.'
