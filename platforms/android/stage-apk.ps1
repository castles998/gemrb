# SPDX-License-Identifier: GPL-2.0-or-later
[CmdletBinding()]
param([ValidateSet('arm64-v8a', 'x86_64')][string]$Abi = 'arm64-v8a')
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$androidRoot = Join-Path $workspace 'build/android'
$pythonRoot = Join-Path $androidRoot 'python-3.10.5-b2'
$inputRoot = Join-Path $androidRoot "apk-input/$Abi"
$assets = Join-Path $inputRoot 'assets'
$pythonLicense = Join-Path $androidRoot 'downloads/Python-3.10.5-LICENSE'
if (-not (Test-Path $pythonLicense)) {
    & curl.exe --fail --location --output $pythonLicense 'https://raw.githubusercontent.com/python/cpython/v3.10.5/LICENSE'
    if ($LASTEXITCODE -ne 0) { throw 'Python license download failed' }
}
if ((Get-FileHash $pythonLicense -Algorithm SHA256).Hash -ne 'f03e17cd594c2085f66a454e695c7ebe5b4d3c0eff534f4f194abc2fd164621b') {
    throw 'Python license checksum mismatch'
}
$native = Join-Path $inputRoot "jniLibs/$Abi"
New-Item -ItemType Directory -Force -Path $assets, $native | Out-Null
$stage = Join-Path $androidRoot ('runtime-stage-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage | Out-Null
foreach ($resource in @('GUIScripts', 'override', 'unhardcoded')) {
    Copy-Item -LiteralPath (Join-Path $workspace "gemrb/$resource") -Destination $stage -Recurse
}
$pythonZip = @(Get-ChildItem (Join-Path $pythonRoot 'src/main/assets/stdlib') -Filter "pythonhome.*.$Abi.zip")
if ($pythonZip.Count -ne 1) { throw 'Expected one ABI-specific Python home archive' }
Expand-Archive -LiteralPath $pythonZip[0].FullName -DestinationPath (Join-Path $stage 'pythonhome')
Copy-Item (Join-Path $pythonRoot "libs/$Abi/*.so") -Destination $native -Force
Copy-Item -LiteralPath (Join-Path $androidRoot "native-$Abi/gemrb/libgemrb.so") -Destination $native -Force
foreach ($library in @('libSDL2.so', 'libiconv.so', 'libopenal.so')) {
    Copy-Item -LiteralPath (Join-Path $androidRoot "prefix-$Abi/lib/$library") -Destination $native -Force
}
$triple = if ($Abi -eq 'arm64-v8a') { 'aarch64-linux-android' } else { 'x86_64-linux-android' }
Copy-Item -LiteralPath (Join-Path $androidRoot "sdk/ndk/27.3.13750724/toolchains/llvm/prebuilt/windows-x86_64/sysroot/usr/lib/$triple/libc++_shared.so") -Destination $native -Force
$extensions = @(Get-ChildItem (Join-Path $stage 'pythonhome') -Recurse -File -Filter '*.so')
foreach ($extension in $extensions) {
    Copy-Item -LiteralPath $extension.FullName -Destination (Join-Path $native ('libpy_' + $extension.Name)) -Force
}
Copy-Item -LiteralPath (Join-Path $workspace 'COPYING') -Destination (Join-Path $stage 'GemRB-COPYING')
Copy-Item -LiteralPath (Join-Path $androidRoot "prefix-$Abi/share/licenses") -Destination $stage -Recurse
Copy-Item -LiteralPath $pythonLicense -Destination (Join-Path $stage 'licenses/Python-3.10.5-LICENSE')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'APK_NOTICES.md') -Destination (Join-Path $stage 'licenses/APK_NOTICES.md')
Add-Type -AssemblyName System.IO.Compression
$archive = Join-Path $assets 'runtime.zip'
$stream = [IO.File]::Open($archive, [IO.FileMode]::Create)
$zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in (Get-ChildItem -LiteralPath $stage -Recurse -File | Sort-Object FullName)) {
        $relative = $file.FullName.Substring($stage.Length + 1).Replace('\', '/')
        $entry = $zip.CreateEntry($relative, [IO.Compression.CompressionLevel]::Optimal)
        $entry.LastWriteTime = [DateTimeOffset]::new(2000, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
        if ($file.Extension -ne '.so') {
            $source = [IO.File]::OpenRead($file.FullName)
            $target = $entry.Open()
            try { $source.CopyTo($target) } finally { $source.Dispose(); $target.Dispose() }
        }
    }
} finally { $zip.Dispose(); $stream.Dispose() }
$runtimeId = (Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant()
# Version manifest is generated build output, not user configuration.
[IO.File]::WriteAllText((Join-Path $assets 'runtime-id.txt'), $runtimeId, [Text.UTF8Encoding]::new($false))
Write-Host "APK inputs staged: $Abi, $($extensions.Count) Python extensions, runtime $runtimeId"
Write-Host "Source staging retained at $stage (ignored generated files)"
