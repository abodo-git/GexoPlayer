# GexoPlayer upgrade plan (professional player)

Starting point (v0.2.0): playlist, themes, 10-band EQ, M3U, persisted state. About 1,600 lines. Tag-blind (titles are file names), no cover art, no search, no queue, no media-session integration, never run on a device, UI untestable without libmpv.

Working loop for every chunk: implement -> unit tests -> widget tests with real fonts -> screenshots inspected by eye -> independent re-run of the whole suite -> commit -> next chunk. Anything that needs a real device or ears is listed under "Unverified" in the changelog, not claimed.

## Phases

| # | Theme | Items | Status |
|---|---|---|---|
| 1 | Foundation + library feel | AudioBackend seam (fake backend for tests/screens), tag + cover art reading off the UI isolate, search, sort, play-next queue, sleep timer, playback speed, mute, keyboard shortcuts, ListTile ink fix | done (v0.3.0) |
| 2 | Playback quality | gapless/prefetch (done), ReplayGain track/album (done), A-B loop (done), missing/unreadable file skip + mark (done); remaining: crossfade, per-track resume for long files, audio-device selection | v0.4.0 partly done |
| 3 | Library | persistent media library (SQLite), scan folders in background with progress, Albums / Artists / Folders / Genres views, album grid with covers, recently added/played, favorites, multiple named playlists | |
| 4 | System integration | Android foreground service + notification + lock-screen controls (audio_service), headset buttons, audio focus; Windows SMTC/media keys, tray, single instance, file associations/"Open with" | |
| 5 | Visuals | real spectrum/waveform visualizer (FFT via libmpv/PCM tap), mini mode, now-playing full screen, dynamic colors from cover art, skin system (Winamp-style) with theme editor | |
| 6 | Lyrics + tags | embedded/.lrc synced lyrics, tag editor, cover search/replace | |
| 7 | Polish + release | Arabic/English UI (RTL), settings screen, accessibility pass, icon, installer (MSIX), signed Android build, perf profile on 50k tracks | |

## Test strategy
- Pure-Dart core (playlist, sort, search, queue, sleep timer, state, EQ, M3U) unit tested.
- Tag reader tested against real files generated with ffmpeg (mp3 with cover, flac, untagged, corrupt).
- AudioEngine tested with FakeBackend: auto-advance, queue, restore without autoplay, volume/mute/speed/preamp wiring, sleep timer.
- Widget tests drive the real PlayerPage with FakeBackend (taps, keyboard, search, menus).
- Screenshots: `SHOTS_DIR=/tmp/shots flutter test test/player_ui_test.dart` writes PNGs for phone and desktop in both themes; they are reviewed by eye each chunk (docs/screenshots).
- CI runs analyze + tests on every push, builds APK/AAB/Windows zip on tags.
- Needs a human/device: real audio output, EQ by ear, Android background playback, Windows media keys. Tracked as "Unverified".
