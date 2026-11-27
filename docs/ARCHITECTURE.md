# Architecture

- **Playlist (`core/playlist.dart`)**: pure Dart state: tracks, current index, shuffle, repeat, reorder (`move`). No I/O, fully unit tested.
- **Equalizer (`core/equalizer.dart`)**: pure Dart 10-band EQ model with Winamp presets; renders a libmpv `af` filter graph (`equalizer=f=...:t=q:w=1:g=...`). Unit tested.
- **M3U (`core/m3u.dart`)**: pure Dart M3U/M3U8 encode/decode with relative-path resolution. Unit tested.
- **State (`core/state.dart` + `core/state_store.dart`)**: `PlayerState` is a pure, tolerant JSON model (unit tested); `StateStore` persists it to the app support directory via `path_provider`, debounced from the UI. Corrupt or partial files fall back to defaults.
- **AudioEngine (`core/audio_engine.dart`)**: owns the media_kit `Player` and the playlist. Opens the current track, advances on completion, exposes position/duration streams. Applies the EQ through `NativePlayer.setProperty('af', ...)` and the preamp by scaling volume (mpv `volume-max` 130). Restores a saved session without autoplaying.
- **UI (`ui/`)**: `PlayerPage` (transport, playlist, LCD readouts), `GxEqSheet` (equalizer), `theme.dart` (Modern/Classic palettes). No playback logic in widgets.
- Future: a `Skin` layer (theme + layout definitions) and an optional Rust DSP/EQ module via `flutter_rust_bridge`, behind the AudioEngine interface so the UI does not change.
