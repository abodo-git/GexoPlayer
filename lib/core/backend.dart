import 'dart:async';

import 'package:media_kit/media_kit.dart';

/// The only thing the engine needs from an audio library. Lets tests and
/// UI screenshots run without native libmpv.
abstract class AudioBackend {
  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<bool> get playingStream;
  Stream<bool> get completed;
  bool get isPlaying;
  Future<void> open(String path, {bool play = true});
  Future<void> playOrPause();
  Future<void> stop();
  Future<void> seek(Duration d);
  /// 0..130, 100 is unity.
  Future<void> setVolume(double v);
  Future<void> setSpeed(double s);
  Future<void> setFilter(String af);
  Future<void> dispose();
}

class MediaKitBackend implements AudioBackend {
  final Player _p = Player();

  MediaKitBackend() {
    final platform = _p.platform;
    if (platform is NativePlayer) {
      unawaited(() async {
        try {
          await platform.setProperty('volume-max', '130');
        } catch (_) {}
      }());
    }
  }

  @override
  Stream<Duration> get position => _p.stream.position;
  @override
  Stream<Duration> get duration => _p.stream.duration;
  @override
  Stream<bool> get playingStream => _p.stream.playing;
  @override
  Stream<bool> get completed => _p.stream.completed;
  @override
  bool get isPlaying => _p.state.playing;
  @override
  Future<void> open(String path, {bool play = true}) =>
      _p.open(Media(path), play: play);
  @override
  Future<void> playOrPause() => _p.playOrPause();
  @override
  Future<void> stop() => _p.stop();
  @override
  Future<void> seek(Duration d) => _p.seek(d);
  @override
  Future<void> setVolume(double v) => _p.setVolume(v);
  @override
  Future<void> setSpeed(double s) => _p.setRate(s);
  @override
  Future<void> setFilter(String af) async {
    final platform = _p.platform;
    if (platform is NativePlayer) {
      try {
        await platform.setProperty('af', af);
      } catch (_) {}
    }
  }

  @override
  Future<void> dispose() => _p.dispose();
}

/// In-memory backend for tests and screenshots. Records what was asked.
class FakeBackend implements AudioBackend {
  final _pos = StreamController<Duration>.broadcast();
  final _dur = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _done = StreamController<bool>.broadcast();
  bool _isPlaying = false;
  String? opened;
  double volume = 100;
  double speed = 1.0;
  String filter = '';
  Duration lastSeek = Duration.zero;
  final List<String> openLog = [];

  void finishTrack() => _done.add(true);
  void emitPosition(Duration d) => _pos.add(d);
  void emitDuration(Duration d) => _dur.add(d);

  @override
  Stream<Duration> get position => _pos.stream;
  @override
  Stream<Duration> get duration => _dur.stream;
  @override
  Stream<bool> get playingStream => _playing.stream;
  @override
  Stream<bool> get completed => _done.stream;
  @override
  bool get isPlaying => _isPlaying;
  @override
  Future<void> open(String path, {bool play = true}) async {
    opened = path;
    openLog.add(path);
    _isPlaying = play;
    _playing.add(play);
  }

  @override
  Future<void> playOrPause() async {
    _isPlaying = !_isPlaying;
    _playing.add(_isPlaying);
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
    _playing.add(false);
  }

  @override
  Future<void> seek(Duration d) async => lastSeek = d;
  @override
  Future<void> setVolume(double v) async => volume = v;
  @override
  Future<void> setSpeed(double s) async => speed = s;
  @override
  Future<void> setFilter(String af) async => filter = af;
  @override
  Future<void> dispose() async {}
}
