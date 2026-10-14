/*
 * DisplayFix.c - tiny Win32 tool to inspect and set display modes.
 *
 * Part of the ProLiant-ML10-Graphics-fix repository (MIT).
 *
 * Why: Windows Server has no reliable built-in CLI to change the screen mode,
 * and a native .exe is convenient for unattended installs / logon scripts.
 *
 * Build:
 *   Linux (mingw-w64):  x86_64-w64-mingw32-gcc -O2 -o DisplayFix.exe DisplayFix.c -luser32 -lgdi32 -lshell32
 *   MSVC:               cl /O2 /DUNICODE /D_UNICODE DisplayFix.c user32.lib gdi32.lib shell32.lib /Fe:DisplayFix.exe
 *   MinGW on Windows:   gcc -O2 -o DisplayFix.exe DisplayFix.c -luser32 -lgdi32 -lshell32
 *
 * Usage:
 *   DisplayFix.exe                     Show current mode of each display
 *   DisplayFix.exe --list              Show displays and all supported modes
 *   DisplayFix.exe --current [dev]     Show the current mode
 *   DisplayFix.exe --modes [dev]       List supported modes
 *   DisplayFix.exe --set W H [Hz] [dev] Set a mode (persisted)
 *   DisplayFix.exe --best [dev]        Set the highest-resolution mode
 *
 * "dev" is a device name such as "\\.\DISPLAY1". If omitted, the primary
 * display is used.
 */

#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif

#include <windows.h>
#include <shellapi.h>
#include <stdio.h>
#include <stdlib.h>
#include <wchar.h>

static void die(const wchar_t *msg) {
    fwprintf(stderr, L"[x] %ls (GetLastError=%lu)\n", msg, (unsigned long)GetLastError());
    ExitProcess(1);
}

/* Find a DISPLAY_DEVICE by name, or the primary one when name==NULL. */
static BOOL find_display(const wchar_t *name, DISPLAY_DEVICEW *out) {
    DISPLAY_DEVICEW dd;
    ZeroMemory(&dd, sizeof(dd));
    dd.cb = sizeof(dd);

    /* first pass: exact name or primary */
    for (DWORD i = 0; EnumDisplayDevicesW(NULL, i, &dd, 0); i++) {
        if (!(dd.StateFlags & DISPLAY_DEVICE_ATTACHED_TO_DESKTOP))
            continue;
        if (name) {
            if (_wcsicmp(dd.DeviceName, name) == 0) { *out = dd; return TRUE; }
        } else if (dd.StateFlags & DISPLAY_DEVICE_PRIMARY_DEVICE) {
            *out = dd; return TRUE;
        }
        ZeroMemory(&dd, sizeof(dd));
        dd.cb = sizeof(dd);
    }

    /* second pass: first attached display */
    ZeroMemory(&dd, sizeof(dd));
    dd.cb = sizeof(dd);
    for (DWORD i = 0; EnumDisplayDevicesW(NULL, i, &dd, 0); i++) {
        if (dd.StateFlags & DISPLAY_DEVICE_ATTACHED_TO_DESKTOP) { *out = dd; return TRUE; }
        ZeroMemory(&dd, sizeof(dd));
        dd.cb = sizeof(dd);
    }
    return FALSE;
}

static void show_current(const wchar_t *name) {
    DISPLAY_DEVICEW dd;
    DEVMODEW dm;
    if (!find_display(name, &dd))
        die(L"no attached display found");
    ZeroMemory(&dm, sizeof(dm));
    dm.dmSize = sizeof(dm);
    if (!EnumDisplaySettingsW(dd.DeviceName, ENUM_CURRENT_SETTINGS, &dm))
        die(L"EnumDisplaySettings(current) failed");
    wprintf(L"%ls  %ls  %lux%lu @ %lu Hz  %lu bpp\n",
            dd.DeviceName, dd.DeviceString,
            dm.dmPelsWidth, dm.dmPelsHeight, dm.dmDisplayFrequency, dm.dmBitsPerPel);
}

static void show_all_displays(void) {
    DISPLAY_DEVICEW dd;
    ZeroMemory(&dd, sizeof(dd));
    dd.cb = sizeof(dd);
    for (DWORD i = 0; EnumDisplayDevicesW(NULL, i, &dd, 0); i++) {
        if (dd.StateFlags & DISPLAY_DEVICE_ATTACHED_TO_DESKTOP) {
            DEVMODEW dm;
            ZeroMemory(&dm, sizeof(dm));
            dm.dmSize = sizeof(dm);
            if (EnumDisplaySettingsW(dd.DeviceName, ENUM_CURRENT_SETTINGS, &dm)) {
                wprintf(L"%ls  %ls  %lux%lu @ %lu Hz%s\n",
                        dd.DeviceName, dd.DeviceString,
                        dm.dmPelsWidth, dm.dmPelsHeight, dm.dmDisplayFrequency,
                        (dd.StateFlags & DISPLAY_DEVICE_PRIMARY_DEVICE) ? L"  [primary]" : L"");
            }
        }
        ZeroMemory(&dd, sizeof(dd));
        dd.cb = sizeof(dd);
    }
}

static void list_modes(const wchar_t *name) {
    DISPLAY_DEVICEW dd;
    DEVMODEW dm;
    if (!find_display(name, &dd))
        die(L"no attached display found");
    wprintf(L"== %ls [%ls] ==\n", dd.DeviceName, dd.DeviceString);
    for (DWORD i = 0; ; i++) {
        ZeroMemory(&dm, sizeof(dm));
        dm.dmSize = sizeof(dm);
        if (!EnumDisplaySettingsW(dd.DeviceName, i, &dm))
            break;
        if (dm.dmBitsPerPel >= 32)
            wprintf(L"  %lux%lu @ %lu Hz\n", dm.dmPelsWidth, dm.dmPelsHeight, dm.dmDisplayFrequency);
    }
}

static int apply_mode(const wchar_t *name, DWORD w, DWORD h, DWORD hz, BOOL have_hz) {
    DISPLAY_DEVICEW dd;
    DEVMODEW dm;
    LONG rc;
    if (!find_display(name, &dd))
        die(L"no attached display found");

    ZeroMemory(&dm, sizeof(dm));
    dm.dmSize = sizeof(dm);
    if (!EnumDisplaySettingsW(dd.DeviceName, ENUM_CURRENT_SETTINGS, &dm))
        die(L"EnumDisplaySettings(current) failed");

    dm.dmPelsWidth = w;
    dm.dmPelsHeight = h;
    dm.dmFields = DM_PELSWIDTH | DM_PELSHEIGHT;
    if (have_hz) {
        dm.dmDisplayFrequency = hz;
        dm.dmFields |= DM_DISPLAYFREQUENCY;
    }

    rc = ChangeDisplaySettingsExW(dd.DeviceName, &dm, NULL, CDS_UPDATEREGISTRY, NULL);
    if (rc == DISP_CHANGE_SUCCESSFUL) {
        wprintf(L"[+] %ls set to %lux%lu%s\n", dd.DeviceName, w, h,
                have_hz ? L" (requested refresh applied)" : L"");
        return 0;
    }
    fwprintf(stderr, L"[x] ChangeDisplaySettingsExW failed: %ld", rc);
    switch (rc) {
        case DISP_CHANGE_BADMODE:        fwprintf(stderr, L" (mode not supported)"); break;
        case DISP_CHANGE_BADPARAM:       fwprintf(stderr, L" (bad parameter)"); break;
        case DISP_CHANGE_RESTART:        fwprintf(stderr, L" (reboot required)"); break;
        case DISP_CHANGE_FAILED:         fwprintf(stderr, L" (driver failed the mode)"); break;
        case DISP_CHANGE_NOTUPDATED:     fwprintf(stderr, L" (could not write to registry)"); break;
        default: break;
    }
    fwprintf(stderr, L"\n");
    return 1;
}

static int set_best(const wchar_t *name) {
    DISPLAY_DEVICEW dd;
    DEVMODEW dm, best;
    DWORD best_px = 0;
    BOOL found = FALSE;

    if (!find_display(name, &dd))
        die(L"no attached display found");

    ZeroMemory(&best, sizeof(best));
    for (DWORD i = 0; ; i++) {
        ZeroMemory(&dm, sizeof(dm));
        dm.dmSize = sizeof(dm);
        if (!EnumDisplaySettingsW(dd.DeviceName, i, &dm))
            break;
        if (dm.dmBitsPerPel < 32)
            continue;
        DWORD px = dm.dmPelsWidth * dm.dmPelsHeight;
        if (!found || px > best_px ||
            (px == best_px && dm.dmDisplayFrequency > best.dmDisplayFrequency)) {
            best = dm;
            best_px = px;
            found = TRUE;
        }
    }
    if (!found)
        die(L"no modes reported by the display");

    wprintf(L"Best mode: %lux%lu @ %lu Hz\n",
            best.dmPelsWidth, best.dmPelsHeight, best.dmDisplayFrequency);
    return apply_mode(name, best.dmPelsWidth, best.dmPelsHeight,
                      best.dmDisplayFrequency, TRUE);
}

static void usage(void) {
    wprintf(L"DisplayFix - inspect/set display modes (Win32)\n"
            L"Usage:\n"
            L"  DisplayFix.exe                        show current mode(s)\n"
            L"  DisplayFix.exe --list                 displays and all modes\n"
            L"  DisplayFix.exe --current [dev]        current mode\n"
            L"  DisplayFix.exe --modes   [dev]        list modes\n"
            L"  DisplayFix.exe --set W H [Hz] [dev]   set a mode (persisted)\n"
            L"  DisplayFix.exe --best    [dev]        set highest mode\n"
            L"  dev = e.g. \\\\.\\DISPLAY1   (default: primary)\n");
}

int wmain(int argc, wchar_t **argv) {
    if (argc < 2) {
        show_all_displays();
        return 0;
    }

    const wchar_t *cmd = argv[1];

    if (!_wcsicmp(cmd, L"--list")) {
        show_all_displays();
        wprintf(L"\n");
        /* modes for the first display */
        DISPLAY_DEVICEW dd;
        if (find_display(NULL, &dd))
            list_modes(dd.DeviceName);
        return 0;
    }
    if (!_wcsicmp(cmd, L"--current")) {
        show_current(argc > 2 ? argv[2] : NULL);
        return 0;
    }
    if (!_wcsicmp(cmd, L"--modes")) {
        list_modes(argc > 2 ? argv[2] : NULL);
        return 0;
    }
    if (!_wcsicmp(cmd, L"--best")) {
        return set_best(argc > 2 ? argv[2] : NULL);
    }
    if (!_wcsicmp(cmd, L"--set")) {
        if (argc < 4) { usage(); return 2; }
        DWORD w = (DWORD)_wtoi(argv[2]);
        DWORD h = (DWORD)_wtoi(argv[3]);
        if (!w || !h) { usage(); return 2; }
        if (argc >= 5 && argv[4][0] != L'-' && argv[4][0] != L'\\') {
            DWORD hz = (DWORD)_wtoi(argv[4]);
            const wchar_t *dev = (argc >= 6) ? argv[5] : NULL;
            return apply_mode(dev, w, h, hz, TRUE);
        }
        return apply_mode(argc >= 5 ? argv[4] : NULL, w, h, 0, FALSE);
    }
    if (!_wcsicmp(cmd, L"--help") || !_wcsicmp(cmd, L"-h") || !_wcsicmp(cmd, L"/?")) {
        usage();
        return 0;
    }

    usage();
    return 2;
}
