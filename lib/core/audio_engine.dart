import 'dart:async';

import 'package:media_kit/media_kit.dart';

import 'equalizer.dart';
import 'playlist.dart';
import 'state.dart';
import 'track.dart';

/// Wraps media_kit (libmpv) and the [GxPlaylist]. UI listens via streams.
class AudioEngine {
  final Player _player = Player();
  final GxPlaylist playlist = GxPlaylist();
  final GxEq eq = GxEq();
  final void Function() onChanged;

  double _volume = 0.8;
  double get volume => _volume;

  AudioEngine({required this.onChanged}) {
    _player.stream.completed.listen((done) {
      if (done) _play(playlist.next(auto: true));
    });
    _player.stream.playing.listen((_) => onChanged());
    unawaited(_applyBackendOptions());
  }

  Stream<Duration> get position => _player.stream.position;
  Stream<Duration> get duration => _player.stream.duration;
  bool get playing => _player.state.playing;

  Future<void> _applyBackendOptions() async {
    final platform = _player.platform;
    if (platform is NativePlayer) {
      try {
        // Let the preamp push volume above 100% when needed.
        await platform.setProperty('volume-max', '130');
      } catch (_) {}
    }
  }

  /// Apply a previously saved [PlayerState]: playlist, modes, volume, EQ,
  /// and cue the current track at [resumeAt] without autoplaying.
  Future<void> restore(PlayerState s, {Duration resumeAt = Duration.zero}) async {
    eq.copyFrom(s.eq);
    _volume = s.volume;
    playlist.tracks
      ..clear()
      ..addAll(s.tracks.map(GxTrack.fromPath));
    playlist.index = s.index;
    playlist.shuffle = s.shuffle;
    playlist.repeat = s.repeat;
    final current = playlist.current;
    if (current != null) {
      try {
        await _player.open(Media(current.path), play: false);
        if (resumeAt > Duration.zero) {
          // Seek once the demuxer has settled.
          unawaited(Future.delayed(const Duration(milliseconds: 400), () {
            _player.seek(resumeAt);
          }));
        }
      } catch (_) {}
    }
    await applyEq();
    onChanged();
  }

  Future<void> addTracks(Iterable<GxTrack> t) async {
    final first = playlist.tracks.isEmpty;
    playlist.add(t);
    if (first) await _play(playlist.current);
    onChanged();
  }

  Future<void> _play(GxTrack? t) async {
    if (t == null) {
      await _player.stop();
    } else {
      await _player.open(Media(t.path));
    }
    onChanged();
  }

  Future<void> playIndex(int i) async {
    playlist.select(i);
    await _play(playlist.current);
  }

  Future<void> next() => _play(playlist.next());
  Future<void> previous() => _play(playlist.previous());
  Future<void> toggle() => _player.playOrPause();
  Future<void> seek(Duration d) => _player.seek(d);

  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0).toDouble();
    await _applyVolume();
  }

  Future<void> _applyVolume() async {
    final out = (_volume * 100 * eq.preampGain).clamp(0.0, 130.0).toDouble();
    await _player.setVolume(out);
  }

  /// Push the current EQ bands to libmpv and re-apply volume (preamp).
  Future<void> applyEq() async {
    final platform = _player.platform;
    if (platform is NativePlayer) {
      try {
        await platform.setProperty('af', eq.toMpvFilter());
      } catch (_) {}
    }
    await _applyVolume();
    onChanged();
  }

  Future<void> dispose() => _player.dispose();
}
