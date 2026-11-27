# GexoPlayer

A fast, Winamp-inspired music player. One Flutter/Dart codebase for **Windows** and **Android** (Linux builds for development). Audio is played by libmpv through [media_kit](https://pub.dev/packages/media_kit): gapless-capable, wide format support.

## Status (v0.1)
- Add multiple audio files, playlist with select/remove/clear
- Play/pause, next/previous, seek bar, volume
- Shuffle and repeat (off / all / one)
- Playlist logic is pure Dart and unit tested

## Build
```
flutter pub get
flutter test
flutter run -d windows   # or an Android device
```
Linux desktop needs `libmpv-dev`.

## CI and releases
`.github/workflows/build.yml` runs analyze + tests, then builds on GitHub:
- Android: split-per-ABI APKs and an AAB
- Windows: `GexoPlayer-windows-x64.zip`

Every run uploads artifacts (Actions tab). Pushing a tag like `v0.1.0` also publishes a GitHub Release with the files.
Note: Android release builds are currently signed with the debug key; add a real keystore as repo secrets before publishing to Play.

## Layout
```
lib/core   playlist, track, audio engine (media_kit wrapper)
lib/ui     screens and widgets
docs       architecture and roadmap
```
See [docs/ROADMAP.md](docs/ROADMAP.md) and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
