# SPDX-License-Identifier: GPL-2.0-or-later
[CmdletBinding()]
param([ValidateSet('arm64-v8a', 'x86_64', 'armeabi-v7a')][string]$Abi = 'arm64-v8a')
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$androidRoot = Join-Path $workspace 'build/android'
$downloads = Join-Path $androidRoot 'downloads'
$pythonRoot = Join-Path $androidRoot 'python-3.10.5-b2'
New-Item -ItemType Directory -Path $downloads -Force | Out-Null
$archive = Join-Path $downloads 'Python-3.10-Android-support.b2.zip'
if (-not (Test-Path $archive)) {
    & curl.exe --fail --location --retry 3 --output $archive 'https://github.com/beeware/Python-Android-support/releases/download/3.10-b2/Python-3.10-Android-support.b2.zip'
    if ($LASTEXITCODE -ne 0) { throw 'Python download failed' }
}
if ((Get-FileHash $archive -Algorithm SHA256).Hash -ne '22433891b09352e2ca90d3d29f5c2147bb495854a663104f817cf93d2a690e0f') {
    throw 'Python support archive checksum mismatch'
}
if (-not (Test-Path (Join-Path $pythonRoot 'include/python3.10/Python.h'))) {
    Expand-Archive -LiteralPath $archive -DestinationPath $pythonRoot
}
$ndkRoot = Join-Path $androidRoot 'sdk/ndk/27.3.13750724'
if (-not (Test-Path (Join-Path $ndkRoot 'build/cmake/android.toolchain.cmake'))) {
    throw 'Run platforms/android/setup-toolchain.ps1 first'
}
# Use a private Ninja downloaded by vcpkg, or a caller-supplied Ninja on PATH.
$ninjaCommand = Get-Command ninja.exe -ErrorAction SilentlyContinue
$ninja = if ($ninjaCommand) { $ninjaCommand.Source } else {
    Get-ChildItem (Join-Path $workspace 'build/vcpkg/downloads/tools') -Recurse -Filter ninja.exe -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $ninja) { throw 'Ninja is required. Install Ninja or put ninja.exe on PATH.' }
$output = Join-Path $androidRoot "probe-$Abi"
& cmake -S $PSScriptRoot -B $output -G Ninja "-DCMAKE_MAKE_PROGRAM=$ninja" `
    "-DCMAKE_TOOLCHAIN_FILE=$ndkRoot/build/cmake/android.toolchain.cmake" `
    "-DANDROID_ABI=$Abi" -DANDROID_PLATFORM=android-26 "-DPYTHON_ANDROID_ROOT=$pythonRoot"
if ($LASTEXITCODE -ne 0) { throw 'Android probe configuration failed' }
& cmake --build $output
if ($LASTEXITCODE -ne 0) { throw 'Android probe compilation failed' }
Write-Host "Compiled probe: $output/gemrb_python_probe"
