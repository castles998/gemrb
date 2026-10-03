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

Configure from the repository root, substituting an installed NDK path:

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
