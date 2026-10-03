# Python embedding feasibility probe

This isolated program tests Android Python initialization, exact runtime version,
standard library imports and native extension loading. It does not prove that
GemRB's GUIScript plugin works. The latter requires milestone 2/3 integration.

Dependency: BeeWare Python-Android-support `3.10-b2`, Python **3.10.5**.
Archive: `Python-3.10-Android-support.b2.zip`.
SHA256: `22433891b09352e2ca90d3d29f5c2147bb495854a663104f817cf93d2a690e0f`.
This hash records the downloaded artifact; no independent upstream checksum has
yet been verified. Upstream release specifies minimum Android API 26.

Source: https://github.com/beeware/Python-Android-support/releases/tag/3.10-b2

For the workspace-local toolchain, use the scripts:

```powershell
# Accept only after reviewing the SDK terms:
./platforms/android/setup-toolchain.ps1 -AcceptSdkLicense
./platforms/android/probe/build-probe.ps1 -Abi arm64-v8a
./platforms/android/probe/build-probe.ps1 -Abi x86_64
# Connect a device and approve this computer's USB debugging authorization:
./platforms/android/probe/run-probe.ps1
# If multiple devices are attached, add -Serial <adb-device-serial>.
```

The run script stages files only under `/data/local/tmp/gemrb-python-3.10.5-probe`.
It checks device ABI, API level and page size first. It preserves the staged
files for diagnosis or repeat tests. No APK or game files are installed.

Alternatively, configure manually from the repository root, substituting an
installed NDK path:

```powershell
cmake -S platforms/android/probe -B build/android/probe-arm64 -G Ninja `
  -DCMAKE_TOOLCHAIN_FILE=<NDK>/build/cmake/android.toolchain.cmake `
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 `
  -DPYTHON_ANDROID_ROOT="$PWD/build/android/python-3.10.5-b2"
cmake --build build/android/probe-arm64
```

To run, extract the matching ABI's `src/main/assets/stdlib/pythonhome.*.zip` to a
Python home directory. Stage that home, `libs/<ABI>/*.so`, and the probe in a
dedicated device test directory. Set `LD_LIBRARY_PATH` to the staged library
directory and invoke `gemrb_python_probe <python-home>`. Require exit code zero
and `ANDROID_PYTHON_PROBE_OK`. Device paths and results will be recorded after
toolchain installation and a connected device are available.

Before adopting this archive for the final APK, inspect its transitive library
dependencies, license inventory and ELF segment alignment. Old prebuilt native
libraries may require rebuilding to meet newer Android page-size requirements.

Verified on 2026-10-03: the probe compiles and links for arm64-v8a and x86_64
using NDK r27d (27.3.13750724), Clang 18.0.4 and host CMake 4.4.3. The Python
arm64 library depends directly on Android's libdl, libm and libc and has SONAME
`libpython3.10.so`. Its LOAD segments have 0x1000 (4 KB) alignment. Device runtime
imports have not been tested yet; no authorized device was attached at setup.
