# SPDX-License-Identifier: GPL-2.0-or-later
[CmdletBinding()]
param([ValidateSet('arm64-v8a', 'x86_64')][string]$Abi = 'arm64-v8a', [switch]$SkipNative)
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$androidRoot = Join-Path $workspace 'build/android'
if (-not $SkipNative) { & (Join-Path $PSScriptRoot 'build-native.ps1') -Abi $Abi }
& (Join-Path $PSScriptRoot 'inspect-native.ps1') -Abi $Abi
& (Join-Path $PSScriptRoot 'stage-apk.ps1') -Abi $Abi
$env:JAVA_HOME = Join-Path $androidRoot 'jdk-17.0.20.1+1'
$signingRoot = Join-Path $androidRoot 'debug-signing'
$debugKey = Join-Path $signingRoot 'debug.keystore'
if (-not (Test-Path $debugKey)) {
    New-Item -ItemType Directory -Force -Path $signingRoot | Out-Null
    & (Join-Path $env:JAVA_HOME 'bin/keytool.exe') -genkeypair -keystore $debugKey `
        -storepass android -keypass android -alias androiddebugkey -keyalg RSA -keysize 2048 `
        -validity 10000 -dname 'CN=Android Debug,O=Android,C=US'
    if ($LASTEXITCODE -ne 0) { throw 'Debug signing key creation failed' }
}
$env:ANDROID_HOME = Join-Path $androidRoot 'sdk'
$env:GRADLE_USER_HOME = Join-Path $androidRoot 'gradle-home'
& (Join-Path $PSScriptRoot 'apk/gradlew.bat') -p (Join-Path $PSScriptRoot 'apk') `
    --project-cache-dir (Join-Path $androidRoot 'gradle-project-cache') "-PgemrbAbi=$Abi" :app:testDebugUnitTest :app:assembleDebug --console=plain
if ($LASTEXITCODE -ne 0) { throw 'APK build failed' }
Write-Host "Debug APK: $androidRoot/gradle-apk/app/outputs/apk/debug/app-debug.apk"
