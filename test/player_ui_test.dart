import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gexoplayer/core/backend.dart';
import 'package:gexoplayer/core/state.dart';
import 'package:gexoplayer/ui/player_page.dart';

import 'support.dart';

Future<FakeBackend> pump(WidgetTester tester,
    {GxThemeMode theme = GxThemeMode.modern, Size size = const Size(420, 820), GlobalKey? key}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  final fake = FakeBackend();
  final cover = File('test/fixtures/cover.png').readAsBytesSync();
  await tester.pumpWidget(RepaintBoundary(
    key: key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: PlayerPage(
        backend: fake,
        persist: false,
        initialTheme: theme,
        initialTracks: demoTracks(cover: cover),
      ),
    ),
  ));
  await tester.pump();
  return fake;
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('shows tracks with artist and length, current track in LCD', (tester) async {
    await pump(tester);
    expect(find.text('Gexo Quartet - Blue Hour'), findsOneWidget);
    expect(find.text('3:41'), findsOneWidget);
    expect(find.text('Neon Harbor - Night Drive'), findsOneWidget);
    expect(find.text('untagged'), findsOneWidget);
    expect(find.text('Blue Hour'), findsOneWidget); // LCD title
  });

  testWidgets('tapping a row plays it; keyboard space pauses', (tester) async {
    final fake = await pump(tester);
    await tester.tap(find.text('Alpha Trio - Amber'));
    await tester.pump();
    expect(fake.opened, '/demo/amber.flac');
    expect(fake.isPlaying, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(fake.isPlaying, isFalse);
  });

  testWidgets('search filters the playlist and shows no-match state', (tester) async {
    await pump(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'neon');
    await tester.pump();
    expect(find.text('Neon Harbor - Night Drive'), findsOneWidget);
    expect(find.text('Alpha Trio - Amber'), findsNothing);
    expect(find.text('1 found'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('No matches'), findsOneWidget);
  });

  testWidgets('typing in search does not trigger shortcuts', (tester) async {
    final fake = await pump(tester);
    await tester.tap(find.byTooltip('Search (Ctrl+F)'));
    await tester.pump();
    await tester.pump();
    final before = fake.isPlaying;
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(fake.isPlaying, before);
  });

  testWidgets('speed menu applies to the backend', (tester) async {
    final fake = await pump(tester);
    await tester.tap(find.byTooltip('Playback speed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.5x').last);
    await tester.pumpAndSettle();
    expect(fake.speed, 1.5);
  });

  testWidgets('play next marks the row with a queue badge', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Track actions').at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play next'));
    await tester.pumpAndSettle();
    expect(find.text('Q1'), findsOneWidget);
  });

  testWidgets('mute button silences the backend', (tester) async {
    final fake = await pump(tester);
    await tester.tap(find.byTooltip('Mute (M)'));
    await tester.pump();
    expect(fake.volume, 0);
  });

  final dir = Platform.environment['SHOTS_DIR'];
  for (final t in GxThemeMode.values) {
    testWidgets('screenshot phone ${t.name}', (tester) async {
      final key = GlobalKey();
      await pump(tester, theme: t, key: key);
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();
      await savePng(tester, key, '${dir!}/phone_${t.name}.png');
    }, skip: dir == null);
    testWidgets('screenshot desktop ${t.name}', (tester) async {
      final key = GlobalKey();
      await pump(tester, theme: t, key: key, size: const Size(900, 640));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();
      await savePng(tester, key, '${dir!}/desktop_${t.name}.png');
    }, skip: dir == null);
  }
}
