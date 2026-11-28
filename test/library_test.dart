import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gexoplayer/core/library.dart';

void main() {
  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('gxlib');
    Directory('${tmp.path}/Albums/Poems').createSync(recursive: true);
    Directory('${tmp.path}/Loose').createSync();
    File('test/fixtures/tagged.mp3').copySync('${tmp.path}/Albums/Poems/02 Blue Hour.mp3');
    File('test/fixtures/tagged.flac').copySync('${tmp.path}/Albums/Poems/01 Amber.flac');
    File('test/fixtures/untagged_song.mp3').copySync('${tmp.path}/Loose/untagged_song.mp3');
    File('test/fixtures/broken.mp3').copySync('${tmp.path}/Loose/broken.mp3');
    File('${tmp.path}/Loose/notes.txt').writeAsStringSync('ignore me');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('scan indexes audio files with tags and reports progress', () async {
    final lib = GxLibrary();
    final progress = <int>[];
    final r = await lib.scan(tmp, onProgress: (d, t) {
      expect(t, 4);
      progress.add(d);
    });
    expect(lib.length, 4); // txt ignored
    expect(r.added, 4);
    expect(r.failed, greaterThanOrEqualTo(1)); // broken.mp3
    expect(progress.last, 4);
    final e = lib.entries.values.firstWhere((x) => x.title == 'Blue Hour');
    expect(e.artist, 'Gexo Quartet');
    expect(e.durationMs, greaterThan(1000));
    expect(lib.roots, [tmp.path]);
  });

  test('rescan skips unchanged files, picks up new, drops deleted', () async {
    final lib = GxLibrary();
    await lib.scan(tmp);
    final again = await lib.scan(tmp);
    expect(again.added, 0);
    expect(again.updated, 0);
    File('${tmp.path}/Loose/untagged_song.mp3').deleteSync();
    File('test/fixtures/tagged.flac').copySync('${tmp.path}/Loose/new.flac');
    final r = await lib.scan(tmp);
    expect(r.added, 1);
    expect(r.removed, 1);
    expect(lib.length, 4);
  });

  test('albums, artists, folders group and sort correctly', () async {
    final lib = GxLibrary();
    await lib.scan(tmp);
    final albums = lib.albums();
    final poems = albums.firstWhere((a) => a.name == 'Tone Poems');
    expect(poems.tracks.map((t) => t.title), ['Amber', 'Blue Hour']); // by track no.
    expect(poems.artist, GxLibrary.variousArtists);
    expect(albums.any((a) => a.name == GxLibrary.unknownAlbum), isTrue);
    final artists = lib.artists().map((a) => a.name).toList();
    expect(artists.indexOf('Alpha Trio'), lessThan(artists.indexOf('Gexo Quartet')));
    expect(lib.folders().length, 2);
  });

  test('favorites, recent (dedupe, cap) and playlists', () {
    final lib = GxLibrary();
    expect(lib.toggleFavorite('/a'), isTrue);
    expect(lib.toggleFavorite('/a'), isFalse);
    for (var i = 0; i < 60; i++) {
      lib.played('/t$i');
    }
    lib.played('/t10');
    expect(lib.recent.length, GxLibrary.maxRecent);
    expect(lib.recent.first, '/t10');
    expect(lib.recent.where((x) => x == '/t10').length, 1);
    lib.savePlaylist('  Gym ', ['/a', '/b']);
    expect(lib.playlists['Gym'], ['/a', '/b']);
    lib.savePlaylist('', ['/a']);
    expect(lib.playlists.length, 1);
    expect(lib.deletePlaylist('Gym'), isTrue);
  });

  test('search matches title, artist and album', () async {
    final lib = GxLibrary();
    await lib.scan(tmp);
    expect(lib.search('quartet').map((e) => e.title), ['Blue Hour']);
    expect(lib.search('poems').length, 2);
    expect(lib.search('').length, 4);
  });

  test('json round trip keeps everything; junk is tolerated', () async {
    final lib = GxLibrary();
    await lib.scan(tmp);
    lib.toggleFavorite(lib.entries.keys.first);
    lib.played(lib.entries.keys.last);
    lib.savePlaylist('Mix', lib.entries.keys.take(2));
    final back = GxLibrary.fromJson(jsonDecode(jsonEncode(lib.toJson())));
    expect(back.length, lib.length);
    expect(back.favorites, lib.favorites);
    expect(back.recent, lib.recent);
    expect(back.playlists['Mix'], lib.playlists['Mix']);
    final junk = GxLibrary.fromJson({
      'entries': [1, null, {'path': 5}, {'path': '/x.mp3', 'title': 'X'}],
      'favorites': [1, '/x.mp3'],
      'playlists': {'ok': ['/x.mp3', 3], 4: []},
    });
    expect(junk.length, 1);
    expect(junk.favorites, {'/x.mp3'});
    expect(junk.playlists['ok'], ['/x.mp3']);
  });

  test('store survives missing and corrupt files', () async {
    final f = File('${tmp.path}/lib.json');
    final store = GxLibraryStore(() async => f);
    expect((await store.load()).length, 0);
    f.writeAsStringSync('{not json');
    expect((await store.load()).length, 0);
    final lib = GxLibrary()..favorites.add('/q');
    await store.save(lib);
    expect((await store.load()).favorites, {'/q'});
  });

  test('entry converts to a ready track', () {
    final t = GxEntry('/m/a.mp3', 'A', artist: 'Z', durationMs: 90000).toTrack();
    expect(t.display, 'Z - A');
    expect(t.duration, const Duration(seconds: 90));
    expect(t.metaLoaded, isTrue);
  });
}
