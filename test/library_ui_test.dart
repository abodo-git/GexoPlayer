import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gexoplayer/core/backend.dart';
import 'package:gexoplayer/core/library.dart';
import 'package:gexoplayer/core/track.dart';
import 'package:gexoplayer/ui/library_page.dart';
import 'package:gexoplayer/ui/player_page.dart';
import 'package:gexoplayer/ui/theme.dart';

import 'support.dart';

GxLibrary demoLib() {
  final l = GxLibrary();
  void add(String path, String title, String artist, String album, int n, int sec) {
    l.entries[path] = GxEntry(path, title,
        artist: artist, album: album, trackNumber: n, durationMs: sec * 1000);
  }

  add('/m/a/1.mp3', 'Blue Hour', 'Gexo Quartet', 'Tone Poems', 1, 221);
  add('/m/a/2.mp3', 'Amber', 'Gexo Quartet', 'Tone Poems', 2, 252);
  add('/m/b/1.mp3', 'Night Drive', 'Neon Harbor', 'After Dark', 1, 303);
  add('/m/b/2.mp3', 'Afterglow', 'Neon Harbor', 'After Dark', 2, 190);
  add('/m/c/1.flac', 'Solo', 'Alpha Trio', 'Singles', 1, 140);
  l.favorites.add('/m/a/2.mp3');
  l.played('/m/b/1.mp3');
  l.savePlaylist('Night shift', ['/m/b/1.mp3', '/m/b/2.mp3']);
  return l;
}

void main() {
  setUpAll(loadTestFonts);

  Future<GlobalKey> pumpLib(WidgetTester tester, GxLibrary lib,
      {List<List<GxTrack>>? played, List<List<GxTrack>>? added}) async {
    tester.view.physicalSize = const Size(420, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final key = GlobalKey();
    final cover = File('test/fixtures/cover.png').readAsBytesSync();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: LibraryPage(
          library: lib,
          palette: modernPalette,
          coverLoader: (path) async => path.contains('/a/') ? cover : null,
          onChanged: () {},
          onPlay: (t, s) async => played?.add([...t.skip(s)]),
          onAdd: (t) async => added?.add(t),
        ),
      ),
    ));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    return key;
  }

  testWidgets('albums grid lists albums with artist and count', (tester) async {
    await pumpLib(tester, demoLib());
    expect(find.text('Tone Poems'), findsOneWidget);
    expect(find.text('After Dark'), findsOneWidget);
    expect(find.text('Gexo Quartet  \u2022  2'), findsOneWidget);
  });

  testWidgets('opening an album and tapping Play all sends tracks in order', (tester) async {
    final played = <List<GxTrack>>[];
    await pumpLib(tester, demoLib(), played: played);
    await tester.tap(find.text('Tone Poems'));
    await tester.pumpAndSettle();
    expect(find.text('Play all'), findsOneWidget);
    await tester.tap(find.text('Play all'));
    await tester.pumpAndSettle();
    expect(played.single.map((t) => t.title), ['Blue Hour', 'Amber']);
  });

  testWidgets('add to queue appends the album', (tester) async {
    final added = <List<GxTrack>>[];
    await pumpLib(tester, demoLib(), added: added);
    await tester.tap(find.text('After Dark'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to queue'));
    await tester.pumpAndSettle();
    expect(added.single.map((t) => t.title), ['Night Drive', 'Afterglow']);
  });

  testWidgets('artists, favorites, recent and playlists tabs', (tester) async {
    final played = <List<GxTrack>>[];
    await pumpLib(tester, demoLib(), played: played);
    await tester.tap(find.text('Artists'));
    await tester.pumpAndSettle();
    expect(find.text('Alpha Trio'), findsOneWidget);
    expect(find.text('1 albums, 1 tracks'), findsOneWidget);
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    expect(find.text('Amber'), findsOneWidget);
    expect(find.text('Solo'), findsNothing);
    await tester.tap(find.text('Recent'));
    await tester.pumpAndSettle();
    expect(find.text('Night Drive'), findsOneWidget);
    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();
    expect(find.text('Night shift'), findsOneWidget);
    expect(find.text('2 tracks'), findsOneWidget);
  });

  testWidgets('favorite heart toggles the library', (tester) async {
    final lib = demoLib();
    await pumpLib(tester, lib);
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove favorite'));
    await tester.pumpAndSettle();
    expect(lib.favorites, isEmpty);
  });

  testWidgets('empty library shows a hint', (tester) async {
    await pumpLib(tester, GxLibrary());
    expect(find.textContaining('Library is empty'), findsOneWidget);
  });

  testWidgets('player: heart on now-playing marks favorite; menu opens Library', (tester) async {
    tester.view.physicalSize = const Size(420, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final lib = GxLibrary();
    final tracks = demoTracks();
    await tester.pumpWidget(MaterialApp(
      home: PlayerPage(
          backend: FakeBackend(), persist: false, initialTracks: tracks, initialLibrary: lib),
    ));
    await tester.pump();
    await tester.tap(find.byTooltip('Add favorite'));
    await tester.pump();
    expect(lib.favorites, {'/demo/blue_hour.mp3'});
    expect(find.byTooltip('Remove favorite'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Library is empty'), findsOneWidget);
  });

  final dir = Platform.environment['SHOTS_DIR'];
  testWidgets('screenshot library albums', (tester) async {
    final key = await pumpLib(tester, demoLib());
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    await savePng(tester, key, '${dir!}/library_albums.png');
  }, skip: dir == null);
  testWidgets('screenshot library album sheet', (tester) async {
    final key = await pumpLib(tester, demoLib());
    await tester.tap(find.text('Tone Poems'));
    await tester.pumpAndSettle();
    await savePng(tester, key, '${dir!}/library_album_sheet.png');
  }, skip: dir == null);
}
