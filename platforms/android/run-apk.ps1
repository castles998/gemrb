# SPDX-License-Identifier: GPL-2.0-or-later
[CmdletBinding()]
param([ValidatePattern('^[A-Za-z0-9_.:-]+$')][string]$Serial, [switch]$Game)
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$androidRoot = Join-Path $workspace 'build/android'
$adb = Join-Path $androidRoot 'sdk/platform-tools/adb.exe'
$adbArgs = @()
if ($Serial) { $adbArgs = @('-s', $Serial) }
function Invoke-Adb([string[]]$Arguments) {
    $result = & $adb @adbArgs @Arguments
    if ($LASTEXITCODE -ne 0) { throw "adb failed: $Arguments" }
    return $result
}
$abi = (Invoke-Adb @('shell', 'getprop ro.product.cpu.abi')).Trim()
$api = [int](Invoke-Adb @('shell', 'getprop ro.build.version.sdk')).Trim()
$pages = (Invoke-Adb @('shell', 'getconf PAGE_SIZE')).Trim()
if ($abi -ne 'arm64-v8a') { throw "This APK was validated for arm64-v8a, not $abi" }
if ($api -lt 26 -or $pages -ne '4096') { throw "Requires API 26+ and 4 KB pages; device API=$api, pages=$pages" }
$apk = Join-Path $androidRoot 'gradle-apk/app/outputs/apk/debug/app-debug.apk'
if (-not (Test-Path $apk)) { throw 'Run build-apk.ps1 first' }
Invoke-Adb @('shell', 'input keyevent KEYCODE_WAKEUP') | Out-Host
Write-Host 'Leave the device unlocked and awake; waking the screen does not unlock it.'
Invoke-Adb @('install', '-r', $apk) | Out-Host
Invoke-Adb @('shell', 'am force-stop org.gemrb.android') | Out-Host
if (-not $Game) {
    # Remove only the generated diagnostic report; never config/game/save files.
    Invoke-Adb @('shell', 'run-as org.gemrb.android rm -f files/runtime-check.txt') | Out-Host
}
$extra = if ($Game) { 'startGame' } else { 'diagnostic' }
Invoke-Adb @('shell', "am start -W -n org.gemrb.android/.LauncherActivity --ez $extra true") | Out-Host
if ($Game) { Write-Host 'Configured game startup requested. Watch logcat with tag GemRB.'; return }
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    Start-Sleep -Seconds 2
    $report = & $adb @adbArgs shell "run-as org.gemrb.android sh -c '[ -f files/runtime-check.txt ] && cat files/runtime-check.txt'"
    if ($LASTEXITCODE -eq 0) {
        $report | Out-Host
        if (($report -join "`n") -notmatch 'ANDROID_APK_RUNTIME_OK') { throw 'APK runtime diagnostic failed; inspect logcat' }
        Write-Host "Verified APK startup/imports on $abi, API $api, $pages-byte pages. Gameplay remains untested."
        return
    }
}
throw 'No runtime report within 60 seconds. Inspect adb logcat -s GemRB SDL AndroidRuntime.'
