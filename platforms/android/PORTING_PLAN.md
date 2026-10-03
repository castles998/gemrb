# Modern Android port plan

Status: milestones 1 and 2 passed: Python device probe and ARM64 native engine
cross-build. APK packaging and engine device startup remain pending.
Baseline: GemRB master at `5552ade1d`. The existing Windows build lives in
`build/windows-vs2022`.

## Objective and first deliverable

Build the current engine as an installable Android debug APK, then demonstrate
that it initializes Python, loads its GUI scripts, and runs a supported game.
Compilation and APK packaging are intermediate milestones, not evidence that a
game works. Google Play publication and release signing are outside the initial
scope.

Initial proposal: SDL2, Gradle + Android Gradle Plugin, the NDK's CMake toolchain,
Clang/libc++, and arm64-v8a. Add x86_64 for emulator validation when dependencies
are available for that ABI. Select and pin tool versions after the dependency
probe; minimum Android API must satisfy both SDL and the chosen Python build.
Do not reuse Windows dependency libraries for cross-compilation.

## Findings from this checkout

- The legacy preparation script expects Ant, Mercurial SDL sources, Python 2.6,
  and GNU STL. Current GemRB explicitly rejects Python 2.
- Of 198 source entries checked in the legacy Android makefile, 54 no longer
  exist at their listed repository paths. Reuse the maintained CMake source
  lists rather than reconstructing this list.
- CMake's Android branch currently creates an executable. SDLActivity needs an
  Android-loadable shared entry library and the matching SDL JNI/Java glue.
- The old Android entry point and logger need review against current logging,
  configuration, and cleanup APIs.
- The Java wrapper extracts assets on every launch and assumes old external
  storage behavior. It needs replacement with controlled, versioned extraction
  and explicit application paths.
- GemRB's GUIScript plugin uses the CPython C API and `Py_Initialize`. Android
  requires an embedded interpreter, a packaged standard library and native
  modules, and explicit initialization paths. Compatibility is unproven.
- This machine has CMake, VS2022, a Java 17 JRE and adb. No SDK/NDK or JDK was
  found at the inspected conventional locations or in environment variables.
  Confirm custom installations before downloading replacements.

## Milestones and acceptance gates

### 1. Reproducible toolchain and Python feasibility

Confirm available disk space and tool installations. Provision an isolated SDK,
NDK and compatible JDK; use a Gradle wrapper with pinned versions. Record download
origins, versions and checksums for dependencies. SDK license acceptance belongs
to the user; present the actual terms rather than automatically accepting them.

Match the existing desktop Python 3.10.5 dependency first: check ABI/API requirements,
headers, libpython, native extension modules, standard library layout, license,
and GemRB C API compatibility. If unsuitable, document the concrete failure and
choose a pinned Android Python build source. A dependency build may require a
Linux host; establish that need with a probe before adding WSL/container setup.

Gate: compile/link a small Android Python embedding probe and run imports on an
emulator or device, or record a precise blocker. Freeze the compatible dependency
versions before building the full engine.

Progress (2026-10-03): desktop installed `patchlevel.h` confirms Python 3.10.5.
Downloaded BeeWare's `3.10-b2` package and confirmed the same version in its
headers, libraries for arm64-v8a/armeabi-v7a/x86_64, and ABI-specific standard
library archives with encodings and native extension modules. Upstream specifies
API 26 minimum. An isolated probe lives in `platforms/android/probe` and compiles
and links for arm64-v8a and x86_64. SDK license acceptance was explicitly supplied
by the user and recorded by sdkmanager. Installed locally: Temurin JDK
17.0.20.1+1, SDK command-line tools 12.0, platform android-35, build-tools 35.0.0,
NDK r27d (27.3.13750724), and platform-tools. Host CMake is 4.4.3; Ninja is 1.13.2.
User-reported device validation passed: arm64-v8a, Android API 33, 4096-byte pages,
with `ANDROID_PYTHON_PROBE_OK` and runtime Python 3.10.5. The probe initializes
the interpreter and imports encodings, json, math, struct, zlib, ctypes, ssl and
sqlite3; its JSON, struct and zlib assertions passed. This validates the isolated
embedding approach, not GemRB GUI bindings or APK runtime loading. Gradle wrapper
selection and complete dependency license inventory remain packaging tasks;
they are not established by this probe. The prebuilt
Python ARM64 ELF uses 4 KB alignment; rebuild it for 16 KB device support before
adopting it for those devices. WSL is
not installed; no Linux host is currently required by this prebuilt approach.

### 2. Native engine cross-build

Build SDL2, zlib and iconv for Android, plus the chosen Python distribution. Start
with only required plugins and an intentional audio path; add PNG, FreeType,
Vorbis and other optional features as game validation requires them. Avoid host
Python/header/library discovery during CMake configuration.

Use existing core/plugin CMake targets. Adapt the Android entry target to a shared
library, connect SDL's Android entry mechanism, link Android logging, and repair
Android-only compile failures. Evaluate GemRB's existing static-plugin facility
for the first APK to simplify packaging and plugin discovery. If using it, verify
PIC, registration, symbol retention and whole-archive linkage. Otherwise package
all dynamic plugins using Android-compatible names and loading paths.

Gate: engine and required plugins link for arm64-v8a with no host libraries or
unresolved required symbols. Inspect ELF dependencies, ABI and native library
alignment requirements. Rebuild Windows to catch shared CMake/API regressions.

Progress (2026-10-03): `build-native.ps1` built `libgemrb.so` for arm64-v8a,
API 26, with 41 static plugin archives and PIC core, whole-archive retention,
Python 3.10.5 and linker `--no-undefined`. Android dependencies are SDL2 2.32.10,
OpenAL Soft 1.22.2, GNU libiconv 1.17 and system zlib. SDL2 2.0.22 was tried but
uses `ALooper_pollAll`, removed by NDK r27; the newer SDL is Android-only. GNU
iconv is necessary because Android's system implementation lacks legacy game
encodings. A Windows-host-compatible Android CMake wrapper builds its library
sources without modifying them. Archive origins and checksums are pinned.

ELF inspection confirms AArch64 shared libraries, unversioned SONAMEs, exported
`SDL_main`, `PyInit_GemRB` and `PyInit__GemRB`, retained key plugin factories and
static initialization code, and only expected Android system/package dependencies.
New engine/SDL/OpenAL/iconv libraries have 16 KB LOAD alignment; prebuilt Python
still has 4 KB alignment. Runtime plugin registration remains an APK startup
test, not proven by symbol retention alone. `inspect-native.ps1` repeats ABI,
dependency and export checks. No shared engine C++ changes were required: shared
CMake changes are tagged and guarded with `if(ANDROID)`; the obsolete Android
entry/logger were repaired in the platform directory. Windows ALL_BUILD succeeded
and all seven CTest suites passed after the shared target changes. Optional PNG,
FreeType, Vorbis, SDL_mixer and VLC remain disabled in this initial Android build.
See `NATIVE_BUILD.md` for commands and dependency/runtime boundaries.

### 3. APK packaging and application startup

Add a Gradle Android application using the SDL2 Java sources from exactly the same
release as the native SDL library. Package all native runtime dependencies,
Python assets, GUIScripts, override and unhardcoded data. Extract owned assets
only when their version changes, preserve configuration and save files, and pass
explicit engine/Python paths before initialization.

Gate: a debug APK builds from documented commands, installs, starts SDL, initializes
Python, imports GemRB/GUI modules and produces useful logcat output. Missing game
data yields an actionable message instead of an unexplained startup crash.

### 4. Game data and playable validation

First use a user-supplied supported game in app-accessible storage to validate the
engine. For ordinary user import, use Android's directory/file picker and design
a deliberate import/copy flow: GemRB expects normal filesystem paths, whereas
document-provider URIs are not those paths. Show storage requirements and copy
progress; keep saves and configuration persistent. No game files are bundled.

Gate: load one identified supported game, display its menu, enter gameplay, verify
touch input and audio, save/load, and background/resume without losing saves or
crashing. Test on a physical device; emulator success alone is insufficient.

### 5. Developer workflow and hardening

Add VS Code tasks for configure, assemble, install and logcat. Document clean
setup and troubleshooting; add build automation once local commands work. Verify
an independent build using the pinned toolchain/dependencies. Add focused tests
for asset/config preservation and import behavior. Then broaden game/device
coverage and investigate rotation, back navigation and memory pressure.

Gate: reproducible APK build and recorded device validation results. Release
signing/publication require a separate decision and user-owned credentials.

## Responsibilities

Agent: implement and debug build integration, dependency packaging, native entry
and logging updates, Java wrapper, asset/Python initialization, import support,
VS Code tasks, documentation, and relevant verification. Make small reviewable
commits at verified milestones; record incomplete gates honestly.

User: identify the first device and Android version, supply legally obtained
supported game files, accept SDK licenses when presented, and enable USB debugging
and authorize this computer if using a physical device. Provide hands-on feedback
for controls/audio/gameplay the agent cannot observe. If a Linux dependency build
is needed, help select/provision WSL or another available Linux environment.

No secrets or local SDK paths belong in commits. Keep downloaded tools and build
outputs under ignored build directories or existing user tool installations.

## Risks and sequencing

Python compatibility and distribution is the first technical uncertainty. Android
storage integration and game import is the largest application change. Plugin
registration and dependency loading can fail at runtime even after linking.
Lifecycle, input and audio require device validation. This is multi-stage work;
a credible time estimate follows the first Python and engine cross-build probes.

Next implementation step: milestone 3, package the native engine with matching
SDL Java glue and explicit Python/config/assets paths. Do not declare playable
success based on compilation or a scaffold APK.

## Primary references

- Python Android embedding: https://docs.python.org/3/using/android.html
- SDL2 Android integration: https://wiki.libsdl.org/SDL2/README-android
- NDK CMake integration: https://developer.android.com/ndk/guides/cmake
