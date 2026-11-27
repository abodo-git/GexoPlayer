# Architecture

- **Playlist (`core/playlist.dart`)**: pure Dart state: tracks, current index, shuffle, repeat. No I/O, fully unit tested.
- **AudioEngine (`core/audio_engine.dart`)**: owns the media_kit `Player` and the playlist. Opens the current track, advances on completion, exposes position/duration streams.
- **UI (`ui/`)**: reads engine state; no playback logic in widgets.
- Future: a `Skin` layer (theme + layout definitions) and an optional Rust DSP/EQ module via `flutter_rust_bridge`, behind the AudioEngine interface so the UI does not change.
