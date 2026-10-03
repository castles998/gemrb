# SPDX-License-Identifier: GPL-2.0-or-later
[CmdletBinding()]
param([ValidateSet('arm64-v8a', 'x86_64')][string]$Abi = 'arm64-v8a', [int]$Jobs = 6)
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$androidRoot = Join-Path $workspace 'build/android'
$downloads = Join-Path $androidRoot 'downloads'
New-Item -ItemType Directory -Force -Path $downloads | Out-Null
$dependencies = @(
    @('SDL2-2.32.10', 'https://www.libsdl.org/release/SDL2-2.32.10.tar.gz', '5f5993c530f084535c65a6879e9b26ad441169b3e25d789d83287040a9ca5165', 'SDL2-2.32.10.tar.gz'),
    @('openal', 'https://github.com/kcat/openal-soft/archive/dc83d99c95a42c960150ddeee06c124134b52208.tar.gz', 'c31b16e18179c8525e050c4798105bdbf902338701e4efc64535d4c0ff547c5c', 'kcat-openal-soft-dc83d99c95a42c960150ddeee06c124134b52208.tar.gz'),
    @('iconv', 'https://ftp.gnu.org/gnu/libiconv/libiconv-1.17.tar.gz', '8f74213b56238c85a50a5329f77e06198771e70dd9a739779f4c02f65d971313', 'libiconv-1.17.tar.gz')
)
foreach ($dependency in $dependencies) {
    $archive = Join-Path $downloads ($dependency[0] + '.tar.gz')
    if (-not (Test-Path $archive)) {
        $cached = Join-Path $workspace ('build/vcpkg/downloads/' + $dependency[3])
        if (Test-Path $cached) { Copy-Item -LiteralPath $cached -Destination $archive } else {
            & curl.exe --fail --location --retry 3 --output $archive $dependency[1]
            if ($LASTEXITCODE -ne 0) { throw "Download failed: $($dependency[0])" }
        }
    }
    if ((Get-FileHash $archive -Algorithm SHA256).Hash -ne $dependency[2]) { throw "Checksum mismatch: $archive" }
}
& (Join-Path $PSScriptRoot 'probe/build-probe.ps1') -Abi $Abi
$pythonRoot = Join-Path $androidRoot 'python-3.10.5-b2'
$ndkRoot = Join-Path $androidRoot 'sdk/ndk/27.3.13750724'
$ninjaCommand = Get-Command ninja.exe -ErrorAction SilentlyContinue
$ninja = if ($ninjaCommand) { $ninjaCommand.Source } else {
    Get-ChildItem (Join-Path $workspace 'build/vcpkg/downloads/tools') -Recurse -Filter ninja.exe |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $ninja) { throw 'Ninja is required' }
$common = @('-G', 'Ninja', "-DCMAKE_MAKE_PROGRAM=$ninja",
    "-DCMAKE_TOOLCHAIN_FILE=$ndkRoot/build/cmake/android.toolchain.cmake",
    "-DANDROID_ABI=$Abi", '-DANDROID_PLATFORM=android-26', '-DANDROID_STL=c++_shared',
    '-DCMAKE_BUILD_TYPE=RelWithDebInfo', '-DCMAKE_POSITION_INDEPENDENT_CODE=ON',
    '-DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON')
$prefix = Join-Path $androidRoot "prefix-$Abi"
$depsBuild = Join-Path $androidRoot "dependencies-$Abi"
& cmake -S (Join-Path $PSScriptRoot 'dependencies') -B $depsBuild @common "-DDEPENDENCY_ARCHIVES=$downloads" "-DCMAKE_INSTALL_PREFIX=$prefix"
if ($LASTEXITCODE -ne 0) { throw 'Dependency configuration failed' }
& cmake --build $depsBuild --parallel $Jobs
if ($LASTEXITCODE -ne 0) { throw 'Dependency build failed' }
& cmake --install $depsBuild
if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed' }
$output = Join-Path $androidRoot "native-$Abi"
& cmake -S $workspace -B $output @common "-DCMAKE_PREFIX_PATH=$prefix" `
    "-DSDL2_DIR=$prefix/lib/cmake/SDL2" '-DPYTHON_VERSION=3.10.5' `
    "-DPython_INCLUDE_DIR=$pythonRoot/include/python3.10" "-DPython_LIBRARY=$pythonRoot/libs/$Abi/libpython3.10.so" `
    "-DIconv_INCLUDE_DIR=$prefix/include" "-DIconv_LIBRARY=$prefix/lib/libiconv.so" `
    '-DIconv_IS_BUILT_IN=OFF' "-DOPENAL_INCLUDE_DIR=$prefix/include/AL" "-DOPENAL_LIBRARY=$prefix/lib/libopenal.so" `
    '-DSTATIC_LINK=ON' '-DSDL_BACKEND=SDL2' '-DOPENGL_BACKEND=None' '-DUSE_OPENAL=ON' `
    '-DUSE_SDLMIXER=OFF' '-DUSE_LIBVLC=OFF' '-DUSE_FREETYPE=OFF' '-DUSE_PNG=OFF' `
    '-DUSE_VORBIS=OFF' '-DUSE_TESTS=OFF' '-DBUILD_TESTING=OFF' '-DDISABLE_WERROR=ON'
if ($LASTEXITCODE -ne 0) { throw 'GemRB Android configuration failed' }
& cmake --build $output --target gemrb --parallel $Jobs
if ($LASTEXITCODE -ne 0) { throw 'GemRB Android build failed' }
& (Join-Path $PSScriptRoot 'inspect-native.ps1') -Abi $Abi
Write-Host "Built Android engine: $output/gemrb/libgemrb.so (not yet an APK)"
