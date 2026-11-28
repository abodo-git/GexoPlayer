import 'package:flutter_test/flutter_test.dart';
import 'package:gexoplayer/core/metadata.dart';
import 'package:gexoplayer/core/track.dart';

void main() {
  test('mp3: tags, duration and embedded cover are read', () {
    final g = GxMetadata.readSync('test/fixtures/tagged.mp3');
    expect(g.title, 'Blue Hour');
    expect(g.artist, 'Gexo Quartet');
    expect(g.album, 'Tone Poems');
    expect(g.trackNumber, 2);
    expect(g.duration!.inSeconds, inInclusiveRange(2, 4));
    expect(g.cover, isNotNull);
    expect(g.cover!.length, greaterThan(100));
  });

  test('flac: vorbis comments are read', () {
    final g = GxMetadata.readSync('test/fixtures/tagged.flac');
    expect(g.title, 'Amber');
    expect(g.artist, 'Alpha Trio');
    expect(g.trackNumber, 1);
  });

  test('untagged and broken files keep the file-name title and never throw', () async {
    final t = GxTrack.fromPath('test/fixtures/untagged_song.mp3');
    await GxMetadata.load(t, cover: false);
    expect(t.title, 'untagged_song');
    expect(t.artist, isNull);
    final b = GxTrack.fromPath('test/fixtures/broken.mp3');
    await GxMetadata.load(b);
    expect(b.title, 'broken');
    expect(b.metaLoaded, isTrue);
  });

  test('load applies tags to the track off the UI isolate', () async {
    final t = GxTrack.fromPath('test/fixtures/tagged.mp3');
    await GxMetadata.load(t);
    expect(t.display, 'Gexo Quartet - Blue Hour');
    expect(t.cover, isNotNull);
  });
}
