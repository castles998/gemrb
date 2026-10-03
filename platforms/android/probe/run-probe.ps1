# SPDX-License-Identifier: GPL-2.0-or-later
[CmdletBinding()]
param([ValidatePattern('^[A-Za-z0-9_.:-]+$')][string]$Serial)
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$androidRoot = Join-Path $workspace 'build/android'
$adb = Join-Path $androidRoot 'sdk/platform-tools/adb.exe'
$adbArgs = @()
if ($Serial) { $adbArgs = @('-s', $Serial) }
function Invoke-Adb([string[]]$Arguments) {
    $result = & $adb @adbArgs @Arguments
    if ($LASTEXITCODE -ne 0) { throw "adb failed: $Arguments" }
    return $result
}
if ((Invoke-Adb @('get-state')).Trim() -ne 'device') {
    throw 'Connect and authorize a device with USB debugging enabled.'
}
$abi = (Invoke-Adb @('shell', 'getprop ro.product.cpu.abi')).Trim()
if ($abi -notin @('arm64-v8a', 'x86_64', 'armeabi-v7a')) { throw "Unsupported probe ABI: $abi" }
$api = [int](Invoke-Adb @('shell', 'getprop ro.build.version.sdk')).Trim()
$pageSize = (Invoke-Adb @('shell', 'getconf PAGE_SIZE')).Trim()
if ($api -lt 26) { throw "The Python support archive requires API 26; device is API $api" }
if ($pageSize -ne '4096') { throw "Python prebuilt uses 4 KB ELF alignment; device page size is $pageSize. Rebuild Python before testing here." }
& (Join-Path $PSScriptRoot 'build-probe.ps1') -Abi $abi
$pythonRoot = Join-Path $androidRoot 'python-3.10.5-b2'
$stage = Join-Path $androidRoot "device-stage-$abi"
$homeRoot = Join-Path $stage 'pythonhome'
if (-not (Test-Path (Join-Path $homeRoot 'lib/python3.10/encodings/__init__.py'))) {
    $homeZip = @(Get-ChildItem (Join-Path $pythonRoot 'src/main/assets/stdlib') -Filter "pythonhome.*.$abi.zip")
    if ($homeZip.Count -ne 1) { throw 'Expected exactly one matching standard library archive' }
    Expand-Archive -LiteralPath $homeZip[0].FullName -DestinationPath $homeRoot
}
New-Item -ItemType Directory -Path (Join-Path $stage 'libs') -Force | Out-Null
Copy-Item (Join-Path $pythonRoot "libs/$abi/*.so") (Join-Path $stage 'libs') -Force
Copy-Item (Join-Path $androidRoot "probe-$abi/gemrb_python_probe") $stage -Force
# Only writes to this dedicated probe directory; leaves all game/app data alone.
$remote = '/data/local/tmp/gemrb-python-3.10.5-probe'
Invoke-Adb @('shell', "mkdir -p $remote") | Out-Host
Invoke-Adb @('push', "$stage/.", $remote) | Out-Host
Invoke-Adb @('shell', "chmod 755 $remote/gemrb_python_probe") | Out-Host
$result = Invoke-Adb @('shell', "LD_LIBRARY_PATH=$remote/libs $remote/gemrb_python_probe $remote/pythonhome")
$result | Out-Host
if (($result -join "`n") -notmatch 'ANDROID_PYTHON_PROBE_OK') { throw 'Probe success marker missing' }
Write-Host "Verified Python 3.10.5 imports on $abi, Android API $api, page size $pageSize."
