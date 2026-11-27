import 'package:flutter_test/flutter_test.dart';
import 'package:gexoplayer/core/m3u.dart';
import 'package:gexoplayer/core/track.dart';

void main() {
  test('encode writes header, EXTINF lines and paths', () {
    final out = GxM3u.encode([GxTrack('/a/b.mp3', 'b'), GxTrack('/c/d.mp3', 'd')]);
    final lines = out.split('\n');
    expect(lines[0], '#EXTM3U');
    expect(lines[1], '#EXTINF:-1,b');
    expect(lines[2], '/a/b.mp3');
    expect(lines[3], '#EXTINF:-1,d');
    expect(lines[4], '/c/d.mp3');
  });

  test('decode skips comments and blank lines', () {
    const content = '#EXTM3U\n#EXTINF:-1,x\n\n/songs/x.mp3\n# comment\n/songs/y.mp3\n';
    expect(GxM3u.decode(content), ['/songs/x.mp3', '/songs/y.mp3']);
  });

  test('decode resolves relative paths against base dir', () {
    final out = GxM3u.decode('sub/tune.mp3\n', baseDir: '/music');
    expect(out, ['/music/sub/tune.mp3']);
  });

  test('decode keeps absolute paths and URLs untouched', () {
    final out = GxM3u.decode('/abs/t.mp3\nhttps://x.example/s.mp3\n',
        baseDir: '/music');
    expect(out, ['/abs/t.mp3', 'https://x.example/s.mp3']);
  });

  test('encode/decode round trip keeps paths', () {
    final tracks = [GxTrack('/m/one.mp3', 'one'), GxTrack('/m/two.mp3', 'two')];
    final decoded = GxM3u.decode(GxM3u.encode(tracks));
    expect(decoded, tracks.map((t) => t.path).toList());
  });
}
