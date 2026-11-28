# GexoPlayer

A fast, Winamp-inspired music player. One Flutter/Dart codebase for **Windows** and **Android** (Linux builds for development). Audio is played by libmpv through [media_kit](https://pub.dev/packages/media_kit): gapless-capable, wide format support.

## Status (v0.3)
- Tags and embedded cover art (title, artist, album, length), search (Ctrl+F or /), sort, play-next queue
- Sleep timer, playback speed 0.5x-2x, mute
- Keyboard: Space play/pause, arrows seek/volume, N/P next/previous, S shuffle, R repeat, M mute
- Plan for the professional-player roadmap: docs/UPGRADE_PLAN.md

### Earlier (v0.2)
- Playlist persists across restarts (tracks, position, shuffle/repeat, volume, theme, EQ)
- Compact Winamp-style volume slider in the transport bar
- Two themes: Modern and Classic (green-on-black Winamp look with LCD readouts)
- 10-band equalizer with the classic Winamp presets and preamp (applied through libmpv)
- Drag-to-reorder playlist, remove per track, clear with Undo
- Add files or whole folders (recursive scan); M3U/M3U8 import and export
- Elapsed/remaining time toggle, resume where you left off
- Core logic (playlist, EQ, M3U, state) is pure Dart and unit tested

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
lib/core   playlist, track, audio engine (media_kit wrapper), EQ, M3U, persisted state
lib/ui     screens and widgets (player page, equalizer sheet, themes)
docs       architecture and roadmap
```
See [docs/ROADMAP.md](docs/ROADMAP.md) and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
