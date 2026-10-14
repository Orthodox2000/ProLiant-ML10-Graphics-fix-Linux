<#
.SYNOPSIS
  Inventory the graphics adapter, driver and monitors on Windows / Windows Server.

.DESCRIPTION
  Answers the questions that matter for this bug:
    * Is a real Intel driver bound, or is it the Microsoft Basic Display Adapter?
    * What does the OS think the monitors are (EDID read successfully)?
    * What modes are available on each output?

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File Get-GraphicsInfo.ps1

.NOTES
  Part of the ProLiant-ML10-Graphics-fix repository (MIT). Read-only.
#>
[CmdletBinding()]
param(
    [string]$ReportPath
)

$ErrorActionPreference = 'SilentlyContinue'
$out = [System.Collections.Generic.List[string]]::new()
function Add-Line([string]$s = '') { $out.Add($s) }

Add-Line "===== Graphics inventory ====="
Add-Line ("Generated : {0}" -f (Get-Date -Format o))
Add-Line ("Computer  : {0}" -f $env:COMPUTERNAME)
Add-Line ("OS        : {0}" -f (Get-CimInstance Win32_OperatingSystem).Caption)
Add-Line ("Build     : {0}" -f (Get-CimInstance Win32_OperatingSystem).Version)

Add-Line ''
Add-Line '===== Video controllers (adapters) ====='
$gpus = Get-CimInstance Win32_VideoController
foreach ($g in $gpus) {
    Add-Line ("Name            : {0}" -f $g.Name)
    Add-Line ("PNPDeviceID     : {0}" -f $g.PNPDeviceID)
    Add-Line ("DriverVersion   : {0}" -f $g.DriverVersion)
    Add-Line ("DriverDate      : {0}" -f $g.DriverDate)
    Add-Line ("Resolution      : {0}x{1} @ {2} Hz" -f $g.CurrentHorizontalResolution, $g.CurrentVerticalResolution, $g.CurrentRefreshRate)
    Add-Line ("VideoModeDescription: {0}" -f $g.VideoModeDescription)
    Add-Line ("AdapterRAM      : {0:N0} bytes" -f $g.AdapterRAM)
    Add-Line ''
}

Add-Line '===== PnP display devices (is it the basic adapter?) ====='
Get-PnpDevice -Class Display | ForEach-Object {
    Add-Line ("{0,-8} {1}" -f $_.Status, $_.FriendlyName)
    Add-Line ("         InstanceId: {0}" -f $_.InstanceId)
}

Add-Line ''
Add-Line '===== Monitors (Win32_DesktopMonitor) ====='
Get-CimInstance Win32_DesktopMonitor | ForEach-Object {
    Add-Line ("Name={0}  MonitorType={1}  PNPID={2}" -f $_.Name, $_.MonitorType, $_.PNPDeviceID)
}

Add-Line ''
Add-Line '===== EDID-derived monitor IDs (WmiMonitorID, root\wmi) ====='
try {
    $ids = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID
    foreach ($id in $ids) {
        $mfg = -join ($id.ManufacturerName | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ })
        $name = -join ($id.UserFriendlyName | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ })
        $sn = -join ($id.SerialNumberID | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ })
        Add-Line ("Manufacturer={0}  Model={1}  Serial={2}  Active={3}" -f $mfg, $name, $sn, $id.Active)
    }
    if (-not $ids) { Add-Line '(no WmiMonitorID data - EDID may not be reaching the OS)' }
} catch {
    Add-Line ("(WmiMonitorID query failed: {0})" -f $_.Exception.Message)
}

Add-Line ''
Add-Line '===== Available modes per display ====='
$ps1 = Join-Path $PSScriptRoot 'Set-DisplayResolution.ps1'
if (Test-Path $ps1) {
    Add-Line (& powershell -NoProfile -ExecutionPolicy Bypass -File $ps1 -List 2>&1 | Out-String)
} else {
    Add-Line "(Set-DisplayResolution.ps1 not found next to this script)"
}

Add-Line ''
Add-Line '===== Remote Desktop / session ====='
Add-Line ("SessionName : {0}" -f $env:SESSIONNAME)

$text = $out -join [Environment]::NewLine
if ($ReportPath) {
    $text | Set-Content -Path $ReportPath -Encoding UTF8
    Write-Host "Report written to $ReportPath"
} else {
    Write-Host $text
}
