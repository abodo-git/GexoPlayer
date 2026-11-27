import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:gexoplayer/core/playlist.dart';
import 'package:gexoplayer/core/track.dart';

GxPlaylist make(int n) =>
    GxPlaylist(rng: Random(1))..add(List.generate(n, (i) => GxTrack('/m/$i.mp3', 't$i')));

void main() {
  test('first add selects first track', () {
    expect(make(3).current?.title, 't0');
  });
  test('next wraps manually, stops at end when auto and repeat off', () {
    final p = make(2);
    expect(p.next(auto: true)?.title, 't1');
    expect(p.next(auto: true), isNull);
    expect(p.next()?.title, 't0');
  });
  test('repeat all and one', () {
    final p = make(2)..repeat = GxRepeat.all;
    p.next(auto: true);
    expect(p.next(auto: true)?.title, 't0');
    p.repeat = GxRepeat.one;
    expect(p.next(auto: true)?.title, 't0');
  });
  test('previous wraps', () {
    expect(make(3).previous()?.title, 't2');
  });
  test('shuffle never repeats same index', () {
    final p = make(4)..shuffle = true;
    for (var i = 0; i < 50; i++) {
      final before = p.index;
      p.next();
      expect(p.index, isNot(before));
    }
  });
  test('removeAt keeps current stable', () {
    final p = make(3)..select(2);
    p.removeAt(0);
    expect(p.current?.title, 't2');
    p.removeAt(1);
    expect(p.current?.title, 't1');
    p.clear();
    expect(p.current, isNull);
  });
}
