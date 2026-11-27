import 'package:flutter_test/flutter_test.dart';
import 'package:gexoplayer/core/playlist.dart';
import 'package:gexoplayer/core/state.dart';

void main() {
  test('defaults are sane', () {
    final s = PlayerState();
    expect(s.tracks, isEmpty);
    expect(s.index, isNull);
    expect(s.volume, 0.8);
    expect(s.repeat, GxRepeat.off);
    expect(s.theme, GxThemeMode.modern);
  });

  test('json round trip preserves everything', () {
    final s = PlayerState()
      ..tracks = ['/a.mp3', '/b.mp3']
      ..index = 1
      ..shuffle = true
      ..repeat = GxRepeat.all
      ..positionMs = 42000
      ..volume = 0.4
      ..theme = GxThemeMode.classic
      ..showRemaining = true;
    s.eq.enabled = true;
    s.eq.setBand(0, 6);

    final back = PlayerState.fromJson(s.toJson());
    expect(back.tracks, ['/a.mp3', '/b.mp3']);
    expect(back.index, 1);
    expect(back.shuffle, isTrue);
    expect(back.repeat, GxRepeat.all);
    expect(back.positionMs, 42000);
    expect(back.volume, 0.4);
    expect(back.theme, GxThemeMode.classic);
    expect(back.showRemaining, isTrue);
    expect(back.eq.enabled, isTrue);
    expect(back.eq.bands[0], 6);
  });

  test('malformed fields fall back to defaults', () {
    final back = PlayerState.fromJson({
      'tracks': 'not-a-list',
      'index': 9,
      'shuffle': 'yes',
      'repeat': 'sideways',
      'volume': 42,
      'theme': 'neon',
      'eq': 'broken',
    });
    expect(back.tracks, isEmpty);
    expect(back.index, isNull);
    expect(back.shuffle, isFalse);
    expect(back.repeat, GxRepeat.off);
    expect(back.volume, 1.0);
    expect(back.theme, GxThemeMode.modern);
    expect(back.eq.enabled, isFalse);
  });

  test('out-of-range index is dropped', () {
    final back = PlayerState.fromJson({
      'tracks': ['/a.mp3'],
      'index': 5,
    });
    expect(back.index, isNull);
  });
}
