import 'dart:math';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gexoplayer/core/playlist.dart';
import 'package:gexoplayer/core/sleep_timer.dart';
import 'package:gexoplayer/core/track.dart';

GxTrack tr(String path, String title, {String? artist, String? album, int? n, int? sec}) =>
    GxTrack(path, title)
      ..artist = artist
      ..album = album
      ..trackNumber = n
      ..duration = sec == null ? null : Duration(seconds: sec);

GxPlaylist lib() => GxPlaylist(rng: Random(1))
  ..add([
    tr('/m/c.mp3', 'Charlie', artist: 'Zed', album: 'B', n: 2, sec: 200),
    tr('/m/a.mp3', 'alpha', artist: 'Yan', album: 'B', n: 1, sec: 100),
    tr('/m/b.mp3', 'Bravo', artist: 'Xi', album: 'A', n: 1, sec: 300),
  ]);

void main() {
  group('queue', () {
    test('play next jumps the queue then resumes normal order', () {
      final p = lib(); // at index 0
      p.playNext(2);
      expect(p.next(auto: true)!.title, 'Bravo');
      expect(p.next(auto: true), isNull); // end of list, repeat off
    });
    test('queue keeps order of requests and ignores removed tracks', () {
      final p = lib();
      p.playNext(2);
      p.playNext(1);
      p.removeAt(2);
      expect(p.next(auto: true)!.title, 'alpha');
      expect(p.queue, isEmpty);
    });
  });

  group('sort', () {
    test('by title is case-insensitive and keeps the current track', () {
      final p = lib()..select(0);
      p.sortBy(GxSort.title);
      expect(p.tracks.map((t) => t.title), ['alpha', 'Bravo', 'Charlie']);
      expect(p.current!.title, 'Charlie');
    });
    test('by album then track number', () {
      final p = lib()..sortBy(GxSort.album);
      expect(p.tracks.map((t) => t.title), ['Bravo', 'alpha', 'Charlie']);
    });
    test('by duration descending', () {
      final p = lib()..sortBy(GxSort.duration, descending: true);
      expect(p.tracks.map((t) => t.title), ['Bravo', 'Charlie', 'alpha']);
    });
  });

  group('search', () {
    test('matches title, artist, album, file name; empty matches all', () {
      final p = lib();
      expect(p.search(''), [0, 1, 2]);
      expect(p.search('bRaVo'), [2]);
      expect(p.search('yan'), [1]);
      expect(p.search('B'), isNotEmpty);
      expect(p.search('c.mp3'), [0]);
      expect(p.search('nothing here'), isEmpty);
    });
  });

  group('sleep timer', () {
    test('fires once after the duration and reports remaining', () {
      fakeAsync((a) {
        var fired = 0;
        final t = GxSleepTimer(onFire: () => fired++);
        t.start(const Duration(seconds: 3));
        expect(t.active, isTrue);
        a.elapse(const Duration(seconds: 1));
        expect(fired, 0);
        a.elapse(const Duration(seconds: 3));
        expect(fired, 1);
        expect(t.active, isFalse);
        a.elapse(const Duration(seconds: 10));
        expect(fired, 1);
      });
    });
    test('cancel prevents firing', () {
      fakeAsync((a) {
        var fired = 0;
        final t = GxSleepTimer(onFire: () => fired++)..start(const Duration(seconds: 2));
        t.cancel();
        a.elapse(const Duration(seconds: 5));
        expect(fired, 0);
        expect(t.remaining, isNull);
      });
    });
  });
}
