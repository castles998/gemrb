# Development APK dependency notice

This is a personal development/debug build, not a public release package.
No proprietary game data is included.

- GemRB: GPL-2.0-or-later. Source: https://github.com/gemrb/gemrb and this checkout's
  Android addition. Original license is bundled as `GemRB-COPYING`.
- SDL2 2.32.10: zlib license, bundled in `licenses/SDL2/LICENSE.txt`.
  Source: https://www.libsdl.org/release/SDL2-2.32.10.tar.gz
  Java glue comes from this same release, unchanged.
- OpenAL Soft 1.22.2: license bundled in `licenses/OpenAL/COPYING`.
  Source: https://github.com/kcat/openal-soft/tree/dc83d99c95a42c960150ddeee06c124134b52208
- GNU libiconv 1.17: library license bundled in `licenses/iconv/COPYING.LIB`.
  Source: https://ftp.gnu.org/gnu/libiconv/libiconv-1.17.tar.gz
  The Android-only wrapper compiles unchanged library sources.
- Python 3.10.5: original CPython license bundled in `licenses/Python-3.10.5-LICENSE`.
  Source: https://github.com/python/cpython/tree/v3.10.5
  Android binary origin: https://github.com/beeware/Python-Android-support/releases/tag/3.10-b2
  Interpreter/extension binaries are unchanged; extension files are packaged under
  APK-compatible library names and linked into the extracted Python home.
- NDK r27d libc++ runtime: from the SDK's NDK, not a Windows runtime.
  NDK source/license information: https://android.googlesource.com/platform/ndk/

The BeeWare archive also includes OpenSSL, libffi, bzip2, SQLite, xz/liblzma and
Rubicon support libraries. Their exact binary provenance and complete transitive
notices/source-offer requirements need an audit before sharing or publishing a
release APK. This notice is not that completed audit. Android system libraries
such as zlib are linked from the device and are not copied into this APK.
