import 'dart:async';

import 'backend.dart';
import 'equalizer.dart';
import 'metadata.dart';
import 'playlist.dart';
import 'sleep_timer.dart';
import 'state.dart';
import 'track.dart';

/// Owns the audio backend and the playlist. UI listens via [onChanged]
/// and the position/duration streams.
class AudioEngine {
  final AudioBackend backend;
  final GxPlaylist playlist = GxPlaylist();
  final GxEq eq = GxEq();
  final void Function() onChanged;
  late final GxSleepTimer sleep;

  double _volume = 0.8;
  double get volume => _volume;
  bool _muted = false;
  bool get muted => _muted;
  double _speed = 1.0;
  double get speed => _speed;

  AudioEngine({required this.onChanged, AudioBackend? backend})
      : backend = backend ?? MediaKitBackend() {
    this.backend.completed.listen((done) {
      if (done) _play(playlist.next(auto: true));
    });
    this.backend.playingStream.listen((_) => onChanged());
    sleep = GxSleepTimer(
      onFire: () async {
        if (this.backend.isPlaying) await this.backend.playOrPause();
        onChanged();
      },
      onTick: onChanged,
    );
  }

  Stream<Duration> get position => backend.position;
  Stream<Duration> get duration => backend.duration;
  bool get playing => backend.isPlaying;

  /// Apply a saved [GxPlayerState] and cue the current track at [resumeAt]
  /// without autoplaying.
  Future<void> restore(GxPlayerState s, {Duration resumeAt = Duration.zero}) async {
    eq.copyFrom(s.eq);
    _volume = s.volume;
    _speed = s.speed;
    playlist.tracks
      ..clear()
      ..addAll(s.tracks.map(GxTrack.fromPath));
    playlist.index = s.index;
    playlist.shuffle = s.shuffle;
    playlist.repeat = s.repeat;
    final current = playlist.current;
    if (current != null) {
      try {
        await backend.open(current.path, play: false);
        unawaited(_loadMeta(current));
        if (resumeAt > Duration.zero) {
          unawaited(Future.delayed(const Duration(milliseconds: 400), () {
            backend.seek(resumeAt);
          }));
        }
      } catch (_) {}
    }
    unawaited(loadAllMetadata());
    await backend.setSpeed(_speed);
    await applyEq();
    onChanged();
  }

  Future<void> addTracks(Iterable<GxTrack> t) async {
    final list = t.toList();
    final first = playlist.tracks.isEmpty;
    playlist.add(list);
    if (first) await _play(playlist.current);
    unawaited(loadAllMetadata());
    onChanged();
  }

  Future<void> _loadMeta(GxTrack t) async {
    await GxMetadata.load(t);
    onChanged();
  }

  /// Read tags for every track that has none yet, current track first.
  Future<void> loadAllMetadata() async {
    final cur = playlist.current;
    if (cur != null) await GxMetadata.load(cur);
    onChanged();
    var n = 0;
    for (final t in List<GxTrack>.of(playlist.tracks)) {
      if (t.metaLoaded) continue;
      await GxMetadata.load(t, cover: false);
      if (++n % 10 == 0) onChanged();
    }
    onChanged();
  }

  Future<void> _play(GxTrack? t) async {
    if (t == null) {
      await backend.stop();
    } else {
      await backend.open(t.path);
      if (!t.metaLoaded) unawaited(_loadMeta(t));
      if (t.metaLoaded && t.cover == null) unawaited(_reloadCover(t));
    }
    onChanged();
  }

  // Tracks scanned in bulk skip cover art; fetch it when they start playing.
  Future<void> _reloadCover(GxTrack t) async {
    final tags = GxMetadata.readSync(t.path);
    t.cover = tags.cover;
    onChanged();
  }

  Future<void> playIndex(int i) async {
    playlist.select(i);
    await _play(playlist.current);
  }

  Future<void> next() => _play(playlist.next());
  Future<void> previous() => _play(playlist.previous());
  Future<void> toggle() => backend.playOrPause();
  Future<void> seek(Duration d) => backend.seek(d);

  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0).toDouble();
    if (_muted && _volume > 0) _muted = false;
    await _applyVolume();
  }

  Future<void> toggleMute() async {
    _muted = !_muted;
    await _applyVolume();
    onChanged();
  }

  Future<void> setSpeed(double s) async {
    _speed = s.clamp(0.5, 2.0).toDouble();
    await backend.setSpeed(_speed);
    onChanged();
  }

  Future<void> _applyVolume() async {
    final out =
        _muted ? 0.0 : (_volume * 100 * eq.preampGain).clamp(0.0, 130.0).toDouble();
    await backend.setVolume(out);
  }

  /// Push the current EQ bands to the backend and re-apply volume (preamp).
  Future<void> applyEq() async {
    await backend.setFilter(eq.toMpvFilter());
    await _applyVolume();
    onChanged();
  }

  Future<void> dispose() async {
    sleep.cancel();
    await backend.dispose();
  }
}
