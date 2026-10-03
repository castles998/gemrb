# SPDX-License-Identifier: GPL-2.0-or-later
[CmdletBinding()]
param([switch]$AcceptSdkLicense)
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$androidRoot = Join-Path $workspace 'build/android'
$downloadRoot = Join-Path $androidRoot 'downloads'
$sdkRoot = Join-Path $androidRoot 'sdk'
$jdkRoot = Join-Path $androidRoot 'jdk-17.0.20.1+1'
New-Item -ItemType Directory -Path $downloadRoot -Force | Out-Null

function Get-VerifiedArchive($Url, $File, $Algorithm, $Checksum) {
    if (-not (Test-Path -LiteralPath $File)) {
        & curl.exe --fail --location --retry 3 --output $File $Url
        if ($LASTEXITCODE -ne 0) { throw "Download failed: $Url" }
    }
    if ((Get-FileHash -LiteralPath $File -Algorithm $Algorithm).Hash -ne $Checksum) {
        throw "Checksum mismatch: $File. Remove the incomplete archive and retry."
    }
}

$jdkArchive = Join-Path $downloadRoot 'OpenJDK17U-jdk_x64_windows_hotspot_17.0.20.1_1.zip'
Get-VerifiedArchive 'https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.20.1%2B1/OpenJDK17U-jdk_x64_windows_hotspot_17.0.20.1_1.zip' $jdkArchive SHA256 'e53a79c3c3d86865bd7e787903884331068e71321714ffd44f145785affc7cb0'
if (-not (Test-Path (Join-Path $jdkRoot 'bin/javac.exe'))) {
    Write-Host 'Extracting JDK...'
    & tar.exe -xf $jdkArchive -C $androidRoot
    if ($LASTEXITCODE -ne 0) { throw 'JDK extraction failed' }
}
$env:JAVA_HOME = $jdkRoot

# This archive was initially verified against Google's repository SHA1. Pin its
# SHA256 here too; sdkmanager verifies the remaining Google archives itself.
$toolsArchive = Join-Path $downloadRoot 'commandlinetools-win-11076708_latest.zip'
Get-VerifiedArchive 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip' $toolsArchive SHA256 '4d6931209eebb1bfb7c7e8b240a6a3cb3ab24479ea294f3539429574b1eec862'
$toolsRoot = Join-Path $sdkRoot 'cmdline-tools/12.0'
if (-not (Test-Path (Join-Path $toolsRoot 'bin/sdkmanager.bat'))) {
    $unpackRoot = Join-Path $androidRoot 'command-line-tools-unpack'
    New-Item -ItemType Directory -Path $unpackRoot -Force | Out-Null
    & tar.exe -xf $toolsArchive -C $unpackRoot
    if ($LASTEXITCODE -ne 0) { throw 'SDK tools extraction failed' }
    New-Item -ItemType Directory -Path (Split-Path $toolsRoot) -Force | Out-Null
    Move-Item -LiteralPath (Join-Path $unpackRoot 'cmdline-tools') -Destination $toolsRoot
}
$manager = Join-Path $toolsRoot 'bin/sdkmanager.bat'
if (-not $AcceptSdkLicense) {
    throw 'Review https://developer.android.com/studio/terms and rerun with -AcceptSdkLicense only if you accept the Android SDK License Agreement.'
}
# The caller explicitly accepted the SDK license. Do not accept unrelated or
# preview licenses: these selected stable packages use android-sdk-license.
("y`n" * 12) | & $manager "--sdk_root=$sdkRoot" 'ndk;27.3.13750724' 'platforms;android-35' 'build-tools;35.0.0' 'platform-tools'
if ($LASTEXITCODE -ne 0) { throw 'SDK package installation failed' }
& (Join-Path $jdkRoot 'bin/javac.exe') -version
& (Join-Path $sdkRoot 'ndk/27.3.13750724/toolchains/llvm/prebuilt/windows-x86_64/bin/clang.exe') --version
Write-Host "Toolchain ready: $sdkRoot"
