# Workspace instructions

## Android addition port

- Port the current checkout to Android as an addition to GemRB. Preserve desktop
  behavior and existing build workflows.
- Match the Python version used by the existing desktop build where feasible.
  Prefer matching its major/minor version over upgrading GemRB's Python APIs to
  accommodate an Android distribution. Establish the exact version from the
  installed headers/runtime, not merely the broad CMake Python requirement.
- Android-specific code under `platforms/android` may be changed or redesigned
  substantially. Keep shared engine changes small and justified; do not contort
  the Android implementation solely to avoid a necessary shared change.
- For changes under `gemrb`, guard Android-specific behavior with `#if defined(__ANDROID__)`
  or the appropriate existing platform define. Tag changes that cannot sensibly
  use a preprocessor guard with an `Android port:` comment and explain the reason.
  For CMake changes use `if(ANDROID)` where applicable and a clear comment.
- Each shared change must have a concrete build/runtime reason documented in its
  commit or the Android port notes. Verify the Windows build when shared code or
  shared build configuration changes.
- Track milestones and evidence in `platforms/android/PORTING_PLAN.md`. Distinguish
  compilation, APK packaging, device startup, Python imports and playable testing.
- Small commits at notable, verified milestones are authorized. Do not commit
  downloaded toolchains, game files, credentials, machine-specific SDK paths or
  generated build outputs. Do not rewrite existing history.
- Ask the user to accept actual SDK license terms; never auto-accept them. Devices
  and game data are available from the user for validation.
