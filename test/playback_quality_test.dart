import 'package:flutter_test/flutter_test.dart';
import 'package:gexoplayer/core/audio_engine.dart';
import 'package:gexoplayer/core/backend.dart';
import 'package:gexoplayer/core/state.dart';
import 'package:gexoplayer/core/track.dart';

void main() {
  late FakeBackend fake;
  late AudioEngine e;
  setUp(() {
    fake = FakeBackend();
    e = AudioEngine(backend: fake, onChanged: () {});
  });
  const good = 'test/fixtures/tagged.mp3';
  const good2 = 'test/fixtures/tagged.flac';

  test('gapless and prefetch are enabled on the backend', () {
    expect(fake.options['gapless-audio'], 'yes');
    expect(fake.options['prefetch-playlist'], 'yes');
  });

  test('replaygain maps to mpv values and persists', () async {
    await e.setReplayGain(GxReplayGain.album);
    expect(fake.options['replaygain'], 'album');
    await e.setReplayGain(GxReplayGain.off);
    expect(fake.options['replaygain'], 'no');
    final s = GxPlayerState()..replayGain = GxReplayGain.track;
    expect(GxPlayerState.fromJson(s.toJson()).replayGain, GxReplayGain.track);
    expect(GxPlayerState.fromJson({'replayGain': 'bogus'}).replayGain, GxReplayGain.off);
    await e.restore(s);
    expect(fake.options['replaygain'], 'track');
  });

  test('A-B loop: set A, set B, clear; B before A is ignored; new track clears', () async {
    await e.addTracks([GxTrack.fromPath(good), GxTrack.fromPath(good2)]);
    await e.cycleLoop(const Duration(seconds: 1));
    expect(e.loopA, const Duration(seconds: 1));
    expect(fake.loopA, isNull);
    await e.cycleLoop(const Duration(milliseconds: 500)); // before A: ignored
    expect(e.looping, isFalse);
    await e.cycleLoop(const Duration(seconds: 2));
    expect(e.looping, isTrue);
    expect(fake.loopA, const Duration(seconds: 1));
    expect(fake.loopB, const Duration(seconds: 2));
    await e.next();
    expect(e.looping, isFalse);
    expect(fake.loopA, isNull);
    await e.cycleLoop(const Duration(seconds: 1));
    await e.cycleLoop(const Duration(seconds: 2));
    await e.cycleLoop(Duration.zero); // third press clears
    expect(e.loopA, isNull);
    expect(fake.loopB, isNull);
  });

  test('missing files are marked and skipped on advance', () async {
    await e.addTracks([
      GxTrack.fromPath(good),
      GxTrack.fromPath('test/fixtures/does_not_exist.mp3'),
      GxTrack.fromPath(good2),
    ]);
    fake.finishTrack();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(fake.opened, good2);
    expect(e.playlist.tracks[1].missing, isTrue);
    expect(e.playlist.current!.path, good2);
  });

  test('previous skips missing files backwards', () async {
    await e.addTracks([
      GxTrack.fromPath(good),
      GxTrack.fromPath('test/fixtures/gone.mp3'),
      GxTrack.fromPath(good2),
    ]);
    await e.playIndex(2);
    await e.previous();
    expect(fake.opened, good);
  });

  test('all tracks missing stops instead of looping forever', () async {
    await e.addTracks([
      GxTrack.fromPath('nope1.mp3'),
      GxTrack.fromPath('nope2.mp3'),
    ]);
    expect(fake.isPlaying, isFalse);
    expect(e.playlist.tracks.every((t) => t.missing), isTrue);
  });

  test('a backend playback error marks the track and moves on', () async {
    await e.addTracks([GxTrack.fromPath(good), GxTrack.fromPath(good2)]);
    fake.emitError('unsupported');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(e.playlist.tracks[0].missing, isTrue);
    expect(fake.opened, good2);
  });
}
