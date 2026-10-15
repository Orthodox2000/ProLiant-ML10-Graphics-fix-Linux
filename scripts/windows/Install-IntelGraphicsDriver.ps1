<#
.SYNOPSIS
  Stage an Intel graphics driver package on Windows / Windows Server.

.DESCRIPTION
  Windows Server does not ship an Intel driver for the HD Graphics P530
  (DEV_191D); it uses the "Microsoft Basic Display Adapter". This script helps
  you install the Windows 10/11 Intel driver package by:

    1. Verifying the GPU is present (Ven_8086&Dev_191D).
    2. Locating an INF inside a folder you extracted the driver to.
    3. Staging it with `pnputil` (/add-driver /install).
    4. Telling you exactly what to do in Device Manager if the driver stages but
       does not bind (the usual "not supported on this OS" situation).

  It does NOT download drivers (Microsoft/Intel do not offer a stable direct
  URL); download the Intel driver package yourself, extract it, then run this
  script (it will auto-detect common extraction paths if -Path is omitted).

.PARAMETER Path
  Folder containing the extracted Intel driver (searched recursively for
  igdlh64.inf / iigd_dch.inf / *.inf with "Intel" graphics). If omitted, common
  paths are auto-searched.

.PARAMETER List
  Only list currently installed display drivers (no changes).

.EXAMPLE
  .\Install-IntelGraphicsDriver.ps1 -List

.EXAMPLE
  .\Install-IntelGraphicsDriver.ps1 -Path C:\SWSetup\Intel\Graphics

.EXAMPLE
  .\Install-IntelGraphicsDriver.ps1        # auto-detect extracted driver

.NOTES
  Must be run as Administrator. This script will self-elevate if launched
  without admin rights. Part of the ProLiant-ML10-Graphics-fix repository (MIT).
#>
[CmdletBinding(DefaultParameterSetName = 'Install')]
param(
    [Parameter(ParameterSetName = 'Install')][string]$Path,
    [Parameter(ParameterSetName = 'List')][switch]$List
)

$ErrorActionPreference = 'Stop'

function Test-Admin {
    $current = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $current.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-SelfElevate {
    if (Test-Admin) { return }

    # Rebuild the command line, quoting the script path and -Path (spaces!).
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $PSCommandPath + '"'))
    if ($Path) {
        $resolved = $Path
        try { $resolved = (Resolve-Path -LiteralPath $Path).Path } catch { }
        $argList += @('-Path', ('"' + $resolved + '"'))
    }

    $hostExe = (Get-Process -Id $PID).Path
    if (-not $hostExe) { $hostExe = 'powershell.exe' }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName        = $hostExe
    $psi.Arguments       = ($argList -join ' ')
    $psi.UseShellExecute = $true   # required for Verb='runas' (UAC)
    $psi.Verb            = 'runas'
    try {
        [System.Diagnostics.Process]::Start($psi) | Out-Null
    } catch {
        Write-Warning 'Failed to elevate. Please run this script as Administrator.'
    }
    exit 0
}

Invoke-SelfElevate

function Find-IntelGraphicsInf {
    param([string[]]$SearchRoots)

    $patterns = @('igdlh64.inf','iigd_dch.inf','kit*.inf','igdlh.inf')
    foreach ($root in $SearchRoots) {
        if (-not $root -or -not (Test-Path $root)) { continue }
        foreach ($p in $patterns) {
            $c = Get-ChildItem -Path $root -Recurse -Filter $p -ErrorAction SilentlyContinue
            if ($c) { return ($c | Select-Object -First 1) }
        }
    }
    # fallback: any INF mentioning DEV_191D
    foreach ($root in $SearchRoots) {
        if (-not $root -or -not (Test-Path $root)) { continue }
        $c = Get-ChildItem -Path $root -Recurse -Filter *.inf -ErrorAction SilentlyContinue |
            Where-Object { (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue) -match 'DEV_191D' }
        if ($c) { return ($c | Select-Object -First 1) }
    }
    return $null
}

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
    pnputil /enum-drivers 2>&1 |
        Select-String -Pattern 'Published Name|Original Name|Provider Name|Class Name|Driver Version'
    Write-Host ''
    Write-Host '===== Display adapters ====='
    Get-PnpDevice -Class Display | Format-Table Status, FriendlyName, InstanceId -AutoSize
    return
}

$searchRoots = @()
if ($Path) {
    $searchRoots += $Path
} else {
    $searchRoots += @(
        "$env:SYSTEMDRIVE\SWSetup\Intel\Graphics",
        "$env:SYSTEMDRIVE\SWSetup\Intel",
        "$env:SYSTEMDRIVE\Drivers\Intel\Graphics",
        "$env:SYSTEMDRIVE\Drivers\Intel",
        "$env:USERPROFILE\Downloads\Intel\Graphics",
        "$env:USERPROFILE\Downloads",
        (Get-Location).Path
    )
}

Write-Host 'Checking hardware ...'
[void](Test-GpuPresent)

Write-Host ''
Write-Host 'Searching for an Intel graphics INF (igdlh64.inf / iigd_dch.inf / *.inf with DEV_191D)...'
$inf = Find-IntelGraphicsInf -SearchRoots $searchRoots
if (-not $inf) {
    $msg = "No Intel graphics INF found. Tried:`n"
    foreach ($r in $searchRoots) { if ($r) { $msg += "  - $r`n" } }
    $msg += "`nDownload the Windows 10/11 x64 Intel graphics driver for HD Graphics P530, extract it (do not just run the EXE in-place), then run:`n  .\Install-IntelGraphicsDriver.ps1 -Path C:\path\to\extracted\folder`nor double-click Install-IntelGraphicsDriver.bat in this folder."
    throw $msg
}

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
