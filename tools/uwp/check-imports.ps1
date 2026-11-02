<#
.SYNOPSIS
    Lists the DLLs (and functions) imported by the Dusklight UWP build and flags the ones that
    are usually not available on Xbox, so desktop-only dependencies can be found before (or after)
    the app fails to start on the console.

.DESCRIPTION
    Needs dumpbin.exe: run it from the "x64 Native Tools Command Prompt for VS" (fase2.bat runs it
    automatically) or from a "Developer PowerShell for VS", after building stage 2.
    By default it looks for dusklight-uwp.exe under build\uwp and checks the executable and every
    DLL next to it. The full report is saved to imports-report.txt at the repository root and a
    summary is printed.

    DLLs shipped prebuilt by extern\uwp-dep are reported separately ([~]): they come from the
    uwp-dep project and are not built here. A DLL that replaces one of them under the same name
    (the SDL3.dll built by sdl3.bat) is checked like the files built here.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\uwp\check-imports.ps1
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\uwp\check-imports.ps1 -Path build\uwp\Release
#>
param(
    [string]$Path = (Join-Path $PSScriptRoot "..\..\build\uwp"),
    [string]$Report = (Join-Path $PSScriptRoot "..\..\imports-report.txt")
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command dumpbin.exe -ErrorAction SilentlyContinue)) {
    Write-Error ("dumpbin.exe not found. Run this script from the 'x64 Native Tools Command Prompt " +
        "for VS' or a 'Developer PowerShell for VS'.")
}

# English dumpbin output whatever the Visual Studio language, so it can be parsed.
$env:VSLANG = "1033"

# DLLs that exist on desktop Windows but not (or only partially) in the Xbox app environment,
# plus the desktop VC++ runtime, which UWP packages replace with the *_app.dll variants.
$suspicious = @(
    "user32.dll", "gdi32.dll", "shell32.dll", "comdlg32.dll", "comctl32.dll", "winspool.drv",
    "dbghelp.dll", "imagehlp.dll", "version.dll", "shlwapi.dll", "setupapi.dll", "dwmapi.dll",
    "uxtheme.dll", "imm32.dll", "opengl32.dll", "vulkan-1.dll", "d3d9.dll", "dinput8.dll",
    "winmm.dll", "hid.dll", "psapi.dll", "wtsapi32.dll", "userenv.dll", "netapi32.dll",
    "vcruntime140.dll", "vcruntime140_1.dll", "msvcp140.dll", "msvcp140_1.dll", "concrt140.dll"
)

# Functions from the list above that the 1.1.1 port (same toolchain, working on Xbox) already
# imported: ImGui clipboard/IME/shell defaults and its SDL3 backend, and RmlUi's assert dialog.
$knownOnXbox = @{
    "user32.dll" = @("CloseClipboard", "EmptyClipboard", "GetClipboardData", "GetWindowLongA",
        "MessageBoxA", "OpenClipboard", "SetClipboardData", "SetWindowLongA", "ShowWindow")
    "imm32.dll" = @("ImmGetContext", "ImmReleaseContext", "ImmSetCandidateWindow", "ImmSetCompositionWindow")
    "shell32.dll" = @("ShellExecuteW")
}

$uwpDepBin = Join-Path $PSScriptRoot "..\..\extern\uwp-dep\x64\bin"
$prebuilt = @{}
if (Test-Path $uwpDepBin) {
    Get-ChildItem -Path $uwpDepBin -Filter "*.dll" | ForEach-Object { $prebuilt[$_.Name.ToLowerInvariant()] = $_.FullName }
}

$item = Get-Item $Path
if ($item.PSIsContainer) {
    $exe = Get-ChildItem -Path $item.FullName -Recurse -Filter "dusklight-uwp.exe" |
        Where-Object { $_.FullName -notmatch "\\AppPackages\\" } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $exe) {
        Write-Error "dusklight-uwp.exe not found under $($item.FullName). Build stage 2 first."
    }
    $binaries = @($exe) + @(Get-ChildItem -Path $exe.DirectoryName -Filter "*.dll")
} else {
    $binaries = @($item)
}

$lines = New-Object System.Collections.Generic.List[string]
$problems = New-Object System.Collections.Generic.List[string]
$notes = New-Object System.Collections.Generic.List[string]

$lines.Add("Checked: $($binaries[0].FullName)")
$lines.Add("")

foreach ($binary in $binaries) {
    # Prebuilt only if it is the very file from uwp-dep, not just one with the same name.
    $source = $prebuilt[$binary.Name.ToLowerInvariant()]
    $isPrebuilt = [bool]$source -and
        ((Get-FileHash $source).Hash -eq (Get-FileHash $binary.FullName).Hash)
    $lines.Add("== $($binary.Name)$(if ($isPrebuilt) { ' (prebuilt, uwp-dep)' })")
    $current = $null
    $functions = [ordered]@{}
    foreach ($line in (& dumpbin.exe /nologo /imports $binary.FullName)) {
        if ($line -match '^\s{4}(\S+\.(dll|drv|exe))\s*$') {
            $current = $Matches[1].ToLowerInvariant()
            if (-not $functions.Contains($current)) {
                $functions[$current] = New-Object System.Collections.Generic.List[string]
            }
        } elseif ($current -and $line -match '^\s+[0-9A-Fa-f]+\s+(\S+)\s*$') {
            $functions[$current].Add($Matches[1])
        } elseif ($line -match '^\s*Summary\s*$') {
            break
        }
    }
    foreach ($dll in ($functions.Keys | Sort-Object)) {
        $unknown = @($functions[$dll] | Where-Object { $knownOnXbox[$dll] -notcontains $_ })
        if ($suspicious -contains $dll -and $unknown.Count -eq 0) {
            $lines.Add("      $dll ($($functions[$dll].Count), all used by the 1.1.1 port)")
        } elseif ($suspicious -contains $dll) {
            $names = ($unknown | Select-Object -First 25) -join ", "
            $entry = "$($binary.Name) imports $dll ($names)"
            if ($isPrebuilt) {
                $lines.Add("  [~] $dll -> $names")
                $notes.Add($entry)
            } else {
                $lines.Add("  [!] $dll -> $names")
                $problems.Add($entry)
            }
        } else {
            $lines.Add("      $dll ($($functions[$dll].Count))")
        }
    }
}

$summary = New-Object System.Collections.Generic.List[string]
if ($problems.Count -eq 0) {
    $summary.Add("No suspicious imports found in the files built here.")
} else {
    $summary.Add("Suspicious imports ($($problems.Count)):")
    foreach ($problem in $problems) {
        $summary.Add("  [!] $problem")
    }
}
if ($notes.Count -gt 0) {
    $summary.Add("Prebuilt uwp-dep DLLs (informational, $($notes.Count)):")
    foreach ($note in $notes) {
        $summary.Add("  [~] $note")
    }
}

$lines.Add("")
$lines.AddRange($summary)
$lines | Set-Content -Path $Report -Encoding UTF8

$summary | Write-Output
Write-Output "Report saved to $((Resolve-Path $Report).Path)"
