import 'package:media_kit/media_kit.dart';
import 'playlist.dart';
import 'track.dart';

/// Wraps media_kit (libmpv) and the [GxPlaylist]. UI listens via streams.
class AudioEngine {
  final Player _player = Player();
  final GxPlaylist playlist = GxPlaylist();
  final void Function() onChanged;

  AudioEngine({required this.onChanged}) {
    _player.stream.completed.listen((done) {
      if (done) _play(playlist.next(auto: true));
    });
    _player.stream.playing.listen((_) => onChanged());
  }

  Stream<Duration> get position => _player.stream.position;
  Stream<Duration> get duration => _player.stream.duration;
  bool get playing => _player.state.playing;

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
  Future<void> setVolume(double v) => _player.setVolume(v * 100);
  Future<void> dispose() => _player.dispose();
}
