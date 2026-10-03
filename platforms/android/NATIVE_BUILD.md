# Android native build

This is milestone 2, not an installable APK. Run from the repository root:

```powershell
./platforms/android/build-native.ps1
# Repeat ELF/export checks without rebuilding:
./platforms/android/inspect-native.ps1
# Optional emulator architecture:
./platforms/android/build-native.ps1 -Abi x86_64
```

First install the toolchain as described in `probe/README.md`. The script verifies
the pinned source archives and Python package, builds dependencies, then builds
`build/android/native-arm64-v8a/gemrb/libgemrb.so`. Generated files and downloaded
tools stay under the ignored `build/android` directory. Ninja must be on PATH or
available in the existing workspace's vcpkg downloads. CMake is required on PATH.
Use `-Jobs 2` to reduce build memory use.

## Dependency choices

- Python 3.10.5, BeeWare `3.10-b2`: unchanged from the verified milestone 1 probe
  and matching the Windows Python version.
- SDL2 2.32.10: Android-only dependency pin. Desktop SDL2 2.0.22 calls
  `ALooper_pollAll`, which NDK r27 marks unavailable. Packaging must use the Java
  sources from this exact SDL release, not the legacy Java wrapper.
- OpenAL Soft 1.22.2: an intentional audio backend, with Android OpenSL ES support.
  The Android dependency wrapper removes versioned library names for APK loading.
- GNU libiconv 1.17: full legacy game encodings. Android's system iconv only
  supports Unicode/ASCII; it cannot replace GNU iconv for these games. A small
  Android-only CMake wrapper builds upstream library sources without GNU tools or
  Autotools on the Windows host, and checks libc's wide-character functions.
- zlib: public Android system library from the NDK sysroot (`libz.so`).

Archive origins and SHA256 pins are in `build-native.ps1` and the dependency
CMake project. SDL and iconv/OpenAL license files are installed into the local
dependency prefix. The complete APK notices/Python transitive license inventory
remain packaging work.

## Engine integration

The engine's maintained CMake source lists build the core and plugins as PIC
static archives. Existing whole-archive linkage keeps plugin registration
initializers. The Android entry target is a shared library exposing `SDL_main`,
linked against SDL2, Python, OpenAL, iconv, Android logging and libc++. The linker
rejects unresolved required symbols. Optional PNG, FreeType, Vorbis, SDL_mixer,
VLC and GPU rendering are intentionally disabled for this first engine build;
this is not feature parity or playable validation.

The initial arm64-v8a build linked 41 plugin archives. ELF checks passed for all
six primary runtime libraries, and Windows ALL_BUILD plus all seven desktop
CTest suites passed. x86_64 is supported by the build script but has not yet
been validated for the full engine.

Shared changes are limited to `if(ANDROID)` entry-target/link settings in
`gemrb/CMakeLists.txt`, plus resetting the static-plugin target cache on Android
reconfigure to prevent duplicated whole-archive entries. The Android-only
entry/logger use current logging APIs, remove obsolete SDL1 callbacks and
external-storage assumptions, and run current
plugin cleanup. The launcher must supply explicit config and Python paths in
milestone 3 before engine initialization; no game data is bundled.

Minimum API remains 26. New native libraries request flexible page-size support,
but the Python prebuilt is still 4 KB aligned: this entire runtime currently
targets the tested 4 KB-page devices, not 16 KB-page devices.
