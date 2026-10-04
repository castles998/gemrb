# Android development APK

From the repository root, after toolchain setup:

```powershell
./platforms/android/build-apk.ps1
./platforms/android/run-apk.ps1
# Choose a device explicitly if more than one is connected:
./platforms/android/run-apk.ps1 -Serial DEVICE_SERIAL
```

APK: `build/android/gradle-apk/app/outputs/apk/debug/app-debug.apk`.
This is a debug-signed, ARM64 personal development build, not a release package.
It requires Android API 26+ and 4 KB pages. Do not install on 16 KB-page devices
until the Python binaries have been rebuilt. Keep the device unlocked and awake
during diagnostics. SDK licenses are accepted separately via the setup script.

The build command cross-builds the engine/dependencies, stages assets/libraries,
runs three asset-extraction unit tests and builds the APK using the checked-in
Gradle wrapper. Gradle 8.9 (distribution SHA256 pinned) and AGP 8.7.3 use the local
JDK 17 and installed SDK/build tools 35. SDL Java sources come directly from the
same pinned SDL2 2.32.10 native dependency source tree. The generated Gradle
wrapper JAR SHA256 is
`498495120a03b9a6ab5d155f5de3c8f0d986a449153702fb80fc80e134484f17`.
`-SkipNative` skips recompilation only when the native library is already current.
The local debug key is generated under ignored `build/android/debug-signing`,
never committed. Keep it across rebuilds so APK updates retain the same signature.
Removing/changing it can prevent updating an installed APK; back up saves/config
before any uninstall. This is not a release signing key.
Native-only details are in `NATIVE_BUILD.md`. Full-engine x86_64 is not yet tested.

## Startup validation

`run-apk.ps1` installs/updates only `org.gemrb.android`, force-stops that app and
launches its no-game diagnostic. It wakes the screen but cannot unlock it. It
checks a fresh generated report, not an old success marker. A passing result is
`ANDROID_APK_RUNTIME_OK` in the report and logcat. The SDL activity briefly renders
a green frame, returns to the launcher, and shows the diagnostic summary.

The diagnostic checks SDL video/renderer creation, static class-plugin registration,
Python 3.10.5, native extension imports (including ssl, ctypes, sqlite3 and zlib),
GemRB/_GemRB bindings, and game-independent GUI modules GUIDefines and MetaClasses.
It also checks the engine's paletted sprite uploads into an RGBA render target:
opaque pixels must retain alpha 255 and color-key pixels alpha 0, both on initial
upload and refresh. Logcat's `ANDROID_TILE_ALPHA_PROBE` also records the raw SDL
opaque-texture path for comparison; a zero alpha there is the known GLES2 issue,
not a failed test of the corrected engine path.
It does **not** call the game's GUI initialization, import GUIClasses/GameCheck
(which need a live engine), play audio, or start gameplay. Those require game data
and milestone 4 validation. Library loading alone is not playable validation.

Reports are at app-private `files/runtime-check.txt`. Useful commands:

```powershell
./build/android/sdk/platform-tools/adb.exe shell run-as org.gemrb.android cat files/runtime-check.txt
./build/android/sdk/platform-tools/adb.exe logcat -s GemRB SDL
```

Use adb's `-s DEVICE_SERIAL` when needed. No global logcat buffer is cleared.

## Owned assets and persistent files

GUIScripts, override, unhardcoded data, Python home and notices are packaged in a
deterministic archive. Its content hash identifies the app-private runtime
directory. An extraction-complete marker avoids re-extracting unchanged data.
Interrupted extraction is retried; paths are checked against ZIP traversal.
Python extensions are installed as APK native libraries; owned Python-home
symlinks point to them and are refreshed when Android moves the installed library
directory during an APK update. Python paths are set before interpreter startup.

User config is created only if missing, at:

`/sdcard/Android/data/org.gemrb.android/files/GemRB.cfg`

The default GamePath and SavePath use that directory's `game` and `saves` folders.
Config and saves are separate from versioned runtime assets. Updating the APK
with `adb install -r` preserves them; **uninstalling the app can remove them**.
App-owned engine paths are supplied independently of user config so updates
cannot leave stale script paths. Old owned runtime versions are retained for now.

No game data is bundled. Starting without `chitin.key` shows explicit setup
instructions and logs `ANDROID_GAME_DATA_MISSING`. For milestone 4, select a
supported game, copy its complete legal game data into app-accessible storage,
configure its GamePath/GameType, and run:

```powershell
./platforms/android/run-apk.ps1 -Game
```

The storage-picker/import UI and touch/audio/save/lifecycle testing are milestone 4
work. PNG, FreeType, Vorbis, SDL_mixer and VLC are still disabled. Full engine
startup may expose additional Android-specific failures; the runtime diagnostic
does not establish game compatibility.

See `APK_NOTICES.md` for bundled notices and the remaining transitive license/
binary provenance audit required before public distribution. Release signing and
Google Play publication are outside this milestone.

## Build references

- AGP compatibility: https://developer.android.com/build/releases/agp-8-7-0-release-notes
- SDL Android integration: https://wiki.libsdl.org/SDL2/README-android
- Wrapper checksums: https://gradle.org/release-checksums/
