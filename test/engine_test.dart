import 'package:flutter_test/flutter_test.dart';
import 'package:gexoplayer/core/audio_engine.dart';
import 'package:gexoplayer/core/backend.dart';
import 'package:gexoplayer/core/playlist.dart';
import 'package:gexoplayer/core/state.dart';
import 'package:gexoplayer/core/track.dart';

void main() {
  late FakeBackend fake;
  late AudioEngine e;
  setUp(() {
    fake = FakeBackend();
    e = AudioEngine(backend: fake, onChanged: () {});
  });

  List<GxTrack> files() => [
        GxTrack.fromPath('test/fixtures/tagged.mp3'),
        GxTrack.fromPath('test/fixtures/tagged.flac'),
        GxTrack.fromPath('test/fixtures/untagged_song.mp3'),
      ];

  test('first add starts playback; completion advances; end stops', () async {
    await e.addTracks(files());
    expect(fake.opened, 'test/fixtures/tagged.mp3');
    expect(fake.isPlaying, isTrue);
    fake.finishTrack();
    await Future<void>.delayed(Duration.zero);
    expect(fake.opened, 'test/fixtures/tagged.flac');
    fake.finishTrack();
    fake.finishTrack();
    await Future<void>.delayed(Duration.zero);
    expect(fake.isPlaying, isFalse); // repeat off, ran out
  });

  test('play next queue is honoured on auto advance', () async {
    await e.addTracks(files());
    e.playlist.playNext(2);
    fake.finishTrack();
    await Future<void>.delayed(Duration.zero);
    expect(fake.opened, 'test/fixtures/untagged_song.mp3');
  });

  test('volume, preamp, mute and speed reach the backend', () async {
    await e.setVolume(0.5);
    expect(fake.volume, 50);
    await e.toggleMute();
    expect(fake.volume, 0);
    await e.setVolume(0.6); // raising volume unmutes
    expect(e.muted, isFalse);
    expect(fake.volume, closeTo(60, 0.001));
    await e.setSpeed(5); // clamped
    expect(fake.speed, 2.0);
    await e.setSpeed(0.1);
    expect(fake.speed, 0.5);
  });

  test('restore cues without autoplay and loads tags in the background', () async {
    final s = GxPlayerState()
      ..tracks = files().map((t) => t.path).toList()
      ..index = 1
      ..speed = 1.25
      ..repeat = GxRepeat.all;
    await e.restore(s);
    expect(fake.opened, 'test/fixtures/tagged.flac');
    expect(fake.isPlaying, isFalse);
    expect(fake.speed, 1.25);
    // tags for the whole list arrive shortly after
    for (var i = 0; i < 50 && !e.playlist.tracks.every((t) => t.metaLoaded); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(e.playlist.tracks[1].title, 'Amber');
    expect(e.playlist.tracks[0].artist, 'Gexo Quartet');
    expect(e.playlist.tracks[0].duration, isNotNull);
  });

  test('sleep timer pauses playback', () async {
    await e.addTracks(files());
    e.sleep.start(const Duration(seconds: 1));
    await Future<void>.delayed(const Duration(milliseconds: 2300));
    expect(fake.isPlaying, isFalse);
    expect(e.sleep.active, isFalse);
  });

  test('speed persists in state json and clamps bad values', () {
    final s = GxPlayerState()..speed = 1.5;
    expect(GxPlayerState.fromJson(s.toJson()).speed, 1.5);
    expect(GxPlayerState.fromJson({'speed': 99}).speed, 2.0);
    expect(GxPlayerState.fromJson({'speed': 'fast'}).speed, 1.0);
  });
}
