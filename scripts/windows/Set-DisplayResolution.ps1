<#
.SYNOPSIS
  List or set the display resolution / refresh rate on Windows and Windows Server.

.DESCRIPTION
  Uses the Win32 API (EnumDisplayDevices / EnumDisplaySettings /
  ChangeDisplaySettingsEx) through P/Invoke, so it works on every Windows and
  Windows Server release - including ones where the Set-DisplayResolution cmdlet
  is missing - and does not depend on any external tool.

  Changes are persisted to the registry (they survive reboot).

.PARAMETER List
  List monitors and all modes each supports.

.PARAMETER Width
  Target width in pixels.

.PARAMETER Height
  Target height in pixels.

.PARAMETER Refresh
  Target refresh rate in Hz. 0 = leave unchanged / pick the best match.

.PARAMETER Device
  Device name such as "\\.\DISPLAY1". Defaults to the primary display.

.PARAMETER Best
  Choose the highest resolution offered by the display.

.PARAMETER Current
  Show the current mode of each attached display.

.EXAMPLE
  .\Set-DisplayResolution.ps1 -List

.EXAMPLE
  .\Set-DisplayResolution.ps1 -Width 1366 -Height 768

.EXAMPLE
  .\Set-DisplayResolution.ps1 -Best

.NOTES
  Run as Administrator for reliable results. Part of the
  ProLiant-ML10-Graphics-fix repository (MIT).
#>
[CmdletBinding(DefaultParameterSetName = 'Current')]
param(
    [Parameter(ParameterSetName = 'List')][switch]$List,
    [Parameter(ParameterSetName = 'Current')][switch]$Current,
    [Parameter(ParameterSetName = 'Best')][switch]$Best,
    [Parameter(ParameterSetName = 'Set', Mandatory = $true)][int]$Width,
    [Parameter(ParameterSetName = 'Set', Mandatory = $true)][int]$Height,
    [Parameter(ParameterSetName = 'Set')][int]$Refresh = 0,
    [string]$Device = $null
)

$ErrorActionPreference = 'Stop'

if (-not ([System.Management.Automation.PSTypeName]'WinDisplay.Native').Type) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace WinDisplay
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct DEVMODE
    {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
        public ushort dmSpecVersion;
        public ushort dmDriverVersion;
        public ushort dmSize;
        public ushort dmDriverExtra;
        public uint dmFields;
        public int dmPositionX;
        public int dmPositionY;
        public uint dmDisplayOrientation;
        public uint dmDisplayFixedOutput;
        public short dmColor;
        public short dmDuplex;
        public short dmYResolution;
        public short dmTTOption;
        public short dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
        public ushort dmLogPixels;
        public uint dmBitsPerPel;
        public uint dmPelsWidth;
        public uint dmPelsHeight;
        public uint dmDisplayFlags;
        public uint dmDisplayFrequency;
        public uint dmICMMethod;
        public uint dmICMIntent;
        public uint dmMediaType;
        public uint dmDitherType;
        public uint dmReserved1;
        public uint dmReserved2;
        public uint dmPanningWidth;
        public uint dmPanningHeight;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct DISPLAY_DEVICE
    {
        public uint cb;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string DeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceString;
        public uint StateFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceID;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceKey;
    }

    public static class Native
    {
        public const int ENUM_CURRENT_SETTINGS = -1;
        public const int ENUM_REGISTRY_SETTINGS = -2;
        public const uint DM_PELSWIDTH = 0x80000;
        public const uint DM_PELSHEIGHT = 0x100000;
        public const uint DM_DISPLAYFREQUENCY = 0x400000;
        public const uint CDS_UPDATEREGISTRY = 0x01;
        public const uint DISPLAY_DEVICE_ATTACHED_TO_DESKTOP = 0x01;
        public const uint DISPLAY_DEVICE_PRIMARY_DEVICE = 0x04;

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern bool EnumDisplaySettings(string lpszDeviceName, int iModeNum, ref DEVMODE lpDevMode);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern int ChangeDisplaySettingsEx(string lpszDeviceName, ref DEVMODE lpDevMode, IntPtr hwnd, uint dwflags, IntPtr lParam);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern bool EnumDisplayDevices(string lpDevice, uint iDevNum, ref DISPLAY_DEVICE lpDisplayDevice, uint dwFlags);
    }
}
"@
}

function Get-Adapter {
    param([string]$Name)
    $i = 0
    while ($true) {
        $dd = New-Object WinDisplay.DISPLAY_DEVICE
        $dd.cb = [uint32][System.Runtime.InteropServices.Marshal]::SizeOf($dd)
        if (-not [WinDisplay.Native]::EnumDisplayDevices($null, $i, [ref]$dd, 0)) { break }
        $attached = ($dd.StateFlags -band [WinDisplay.Native]::DISPLAY_DEVICE_ATTACHED_TO_DESKTOP) -ne 0
        $primary  = ($dd.StateFlags -band [WinDisplay.Native]::DISPLAY_DEVICE_PRIMARY_DEVICE) -ne 0
        if ($attached) {
            if ($Name) { if ($dd.DeviceName -eq $Name) { return $dd } }
            elseif ($primary) { return $dd }
        }
        $i++
    }
    # fall back to the first attached display if no primary was found
    $i = 0
    while ($true) {
        $dd = New-Object WinDisplay.DISPLAY_DEVICE
        $dd.cb = [uint32][System.Runtime.InteropServices.Marshal]::SizeOf($dd)
        if (-not [WinDisplay.Native]::EnumDisplayDevices($null, $i, [ref]$dd, 0)) { break }
        if (($dd.StateFlags -band [WinDisplay.Native]::DISPLAY_DEVICE_ATTACHED_TO_DESKTOP) -ne 0) { return $dd }
        $i++
    }
    return $null
}

function Get-Modes {
    param([string]$DeviceName)
    $modes = @()
    $n = 0
    while ($true) {
        $dm = New-Object WinDisplay.DEVMODE
        $dm.dmSize = [uint16][System.Runtime.InteropServices.Marshal]::SizeOf($dm)
        if (-not [WinDisplay.Native]::EnumDisplaySettings($DeviceName, $n, [ref]$dm)) { break }
        if ($dm.dmBitsPerPel -ge 32) {
            $modes += [pscustomobject]@{
                Width   = [int]$dm.dmPelsWidth
                Height  = [int]$dm.dmPelsHeight
                Hz      = [int]$dm.dmDisplayFrequency
                Bpp     = [int]$dm.dmBitsPerPel
            }
        }
        $n++
    }
    $modes
}

function Show-Current {
    $i = 0
    while ($true) {
        $dd = New-Object WinDisplay.DISPLAY_DEVICE
        $dd.cb = [uint32][System.Runtime.InteropServices.Marshal]::SizeOf($dd)
        if (-not [WinDisplay.Native]::EnumDisplayDevices($null, $i, [ref]$dd, 0)) { break }
        if (($dd.StateFlags -band [WinDisplay.Native]::DISPLAY_DEVICE_ATTACHED_TO_DESKTOP) -ne 0) {
            $dm = New-Object WinDisplay.DEVMODE
            $dm.dmSize = [uint16][System.Runtime.InteropServices.Marshal]::SizeOf($dm)
            if ([WinDisplay.Native]::EnumDisplaySettings($dd.DeviceName, [WinDisplay.Native]::ENUM_CURRENT_SETTINGS, [ref]$dm)) {
                '{0}  {1}  {2}x{3} @ {4} Hz' -f $dd.DeviceName, $dd.DeviceString, $dm.dmPelsWidth, $dm.dmPelsHeight, $dm.dmDisplayFrequency
            }
        }
        $i++
    }
}

switch ($PSCmdlet.ParameterSetName) {
    'List' {
        $i = 0
        while ($true) {
            $dd = New-Object WinDisplay.DISPLAY_DEVICE
            $dd.cb = [uint32][System.Runtime.InteropServices.Marshal]::SizeOf($dd)
            if (-not [WinDisplay.Native]::EnumDisplayDevices($null, $i, [ref]$dd, 0)) { break }
            if (($dd.StateFlags -band [WinDisplay.Native]::DISPLAY_DEVICE_ATTACHED_TO_DESKTOP) -ne 0) {
                Write-Host ("== {0}  [{1}]" -f $dd.DeviceName, $dd.DeviceString) -ForegroundColor Cyan
                Get-Modes -DeviceName $dd.DeviceName | Sort-Object Width, Height, Hz -Unique |
                    ForEach-Object { '   {0,5}x{1,-5} @ {2,3} Hz' -f $_.Width, $_.Height, $_.Hz }
            }
            $i++
        }
    }
    'Best' {
        $adapter = Get-Adapter -Name $Device
        if (-not $adapter) { throw 'No attached display found.' }
        $best = Get-Modes -DeviceName $adapter.DeviceName |
                Sort-Object Width, Height, Hz -Descending | Select-Object -First 1
        Write-Host ("Best mode for {0}: {1}x{2} @ {3} Hz" -f $adapter.DeviceName, $best.Width, $best.Height, $best.Hz)
        $dm = New-Object WinDisplay.DEVMODE
        $dm.dmSize = [uint16][System.Runtime.InteropServices.Marshal]::SizeOf($dm)
        [void][WinDisplay.Native]::EnumDisplaySettings($adapter.DeviceName, [WinDisplay.Native]::ENUM_CURRENT_SETTINGS, [ref]$dm)
        $dm.dmPelsWidth = [uint32]$best.Width
        $dm.dmPelsHeight = [uint32]$best.Height
        $dm.dmDisplayFrequency = [uint32]$best.Hz
        $dm.dmFields = [WinDisplay.Native]::DM_PELSWIDTH -bor [WinDisplay.Native]::DM_PELSHEIGHT -bor [WinDisplay.Native]::DM_DISPLAYFREQUENCY
        $rc = [WinDisplay.Native]::ChangeDisplaySettingsEx($adapter.DeviceName, [ref]$dm, [IntPtr]::Zero, [WinDisplay.Native]::CDS_UPDATEREGISTRY, [IntPtr]::Zero)
        if ($rc -eq 0) { Write-Host 'Applied.' -ForegroundColor Green } else { Write-Warning "ChangeDisplaySettingsEx returned $rc" }
    }
    'Set' {
        $adapter = Get-Adapter -Name $Device
        if (-not $adapter) { throw 'No attached display found.' }
        $dm = New-Object WinDisplay.DEVMODE
        $dm.dmSize = [uint16][System.Runtime.InteropServices.Marshal]::SizeOf($dm)
        [void][WinDisplay.Native]::EnumDisplaySettings($adapter.DeviceName, [WinDisplay.Native]::ENUM_CURRENT_SETTINGS, [ref]$dm)
        $dm.dmPelsWidth = [uint32]$Width
        $dm.dmPelsHeight = [uint32]$Height
        if ($Refresh -gt 0) { $dm.dmDisplayFrequency = [uint32]$Refresh }
        $dm.dmFields = [WinDisplay.Native]::DM_PELSWIDTH -bor [WinDisplay.Native]::DM_PELSHEIGHT
        if ($Refresh -gt 0) { $dm.dmFields = $dm.dmFields -bor [WinDisplay.Native]::DM_DISPLAYFREQUENCY }
        Write-Host ("Setting {0} to {1}x{2}{3} ..." -f $adapter.DeviceName, $Width, $Height, $(if ($Refresh -gt 0) { " @ $Refresh Hz" } else { '' }))
        $rc = [WinDisplay.Native]::ChangeDisplaySettingsEx($adapter.DeviceName, [ref]$dm, [IntPtr]::Zero, [WinDisplay.Native]::CDS_UPDATEREGISTRY, [IntPtr]::Zero)
        switch ($rc) {
            0 { Write-Host 'Applied successfully.' -ForegroundColor Green }
            -2 { Write-Warning 'Mode not supported by this display.' }
            default { Write-Warning "ChangeDisplaySettingsEx returned $rc" }
        }
    }
    default {
        Show-Current
    }
}
