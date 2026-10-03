# SPDX-License-Identifier: GPL-2.0-or-later
[CmdletBinding()]
param([ValidateSet('arm64-v8a', 'x86_64')][string]$Abi = 'arm64-v8a')
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$androidRoot = Join-Path $workspace 'build/android'
$llvmRoot = Join-Path $androidRoot 'sdk/ndk/27.3.13750724/toolchains/llvm/prebuilt/windows-x86_64'
$readelf = Join-Path $llvmRoot 'bin/llvm-readelf.exe'
$nm = Join-Path $llvmRoot 'bin/llvm-nm.exe'
$engine = Join-Path $androidRoot "native-$Abi/gemrb/libgemrb.so"
$triple = if ($Abi -eq 'arm64-v8a') { 'aarch64-linux-android' } else { 'x86_64-linux-android' }
$machine = if ($Abi -eq 'arm64-v8a') { 'AArch64' } else { 'Advanced Micro Devices X86-64' }
$libraries = @($engine,
    (Join-Path $androidRoot "prefix-$Abi/lib/libSDL2.so"),
    (Join-Path $androidRoot "prefix-$Abi/lib/libiconv.so"),
    (Join-Path $androidRoot "prefix-$Abi/lib/libopenal.so"),
    (Join-Path $androidRoot "python-3.10.5-b2/libs/$Abi/libpython3.10.so"),
    (Join-Path $llvmRoot "sysroot/usr/lib/$triple/libc++_shared.so"))
$allowed = @('libgemrb.so', 'libSDL2.so', 'libiconv.so', 'libopenal.so', 'libpython3.10.so',
    'libc++_shared.so', 'libc.so', 'libm.so', 'libdl.so', 'liblog.so', 'libz.so',
    'libandroid.so', 'libOpenSLES.so', 'libGLESv1_CM.so', 'libGLESv2.so')
foreach ($library in $libraries) {
    if (-not (Test-Path -LiteralPath $library)) { throw "Missing runtime: $library" }
    $elf = & $readelf -h -d -l $library
    if ($LASTEXITCODE -ne 0) { throw "ELF inspection failed: $library" }
    if (-not ($elf -match "Machine:\s+$machine")) { throw "Wrong architecture: $library" }
    if (-not ($elf -match 'Type:\s+DYN')) { throw "Not a shared ELF: $library" }
    $needed = @($elf | Select-String '\(NEEDED\).*\[(.+)\]' | ForEach-Object { $_.Matches[0].Groups[1].Value })
    foreach ($name in $needed) {
        if ($allowed -notcontains $name) { throw "Unexpected dependency $name in $library" }
    }
    Write-Host "$(Split-Path $library -Leaf): $($needed -join ', ')"
    $elf | Select-String '^\s+LOAD\s' | ForEach-Object { Write-Host $_.Line.Trim() }
}
$exports = & $nm --dynamic --defined-only $engine
if ($LASTEXITCODE -ne 0) { throw 'Engine export inspection failed' }
foreach ($symbol in @('SDL_main', 'PyInit_GemRB', 'PyInit__GemRB')) {
    if (-not ($exports -match "\bT $symbol$")) { throw "Missing exported entry: $symbol" }
}
$symbols = & $nm --demangle $engine
if ($LASTEXITCODE -ne 0) { throw 'Plugin symbol inspection failed' }
foreach ($plugin in @('GUIScript', 'SDL20VideoDriver', 'OpenALBackend')) {
    if (-not ($symbols -match "CreatePlugin<GemRB::$plugin>::func")) { throw "Missing retained plugin: $plugin" }
}
Write-Host 'ANDROID_NATIVE_LINK_OK: SDL/Python entry exports and key plugin factories retained.'
Write-Host 'This is link evidence, not APK startup or runtime plugin-registration validation.'
Write-Host 'Python remains 4 KB aligned; do not claim 16 KB-device compatibility.'
