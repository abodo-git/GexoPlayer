import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gexoplayer/core/track.dart';

/// flutter test renders with a block font by default; load real fonts so
/// screenshots are readable. Fonts are bundled in test/fonts so results match CI.
Future<void> loadTestFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    var any = false;
    for (final p in paths) {
      final f = File(p);
      if (f.existsSync()) {
        loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
        any = true;
      }
    }
    if (any) await loader.load();
  }

  const d = 'test/fonts';
  await load('Roboto', ['$d/Roboto-Regular.ttf', '$d/Roboto-Bold.ttf']);
  await load('MaterialIcons', ['$d/MaterialIcons-Regular.otf']);
  await load('monospace', ['$d/DejaVuSansMono.ttf']);
}

/// Demo library with tags (no files needed).
List<GxTrack> demoTracks({Uint8List? cover}) => [
      GxTrack('/demo/blue_hour.mp3', 'Blue Hour')
        ..artist = 'Gexo Quartet'
        ..album = 'Tone Poems'
        ..duration = const Duration(minutes: 3, seconds: 41)
        ..cover = cover
        ..metaLoaded = true,
      GxTrack('/demo/amber.flac', 'Amber')
        ..artist = 'Alpha Trio'
        ..album = 'Tone Poems'
        ..duration = const Duration(minutes: 4, seconds: 12)
        ..metaLoaded = true,
      GxTrack('/demo/night_drive.mp3', 'Night Drive')
        ..artist = 'Neon Harbor'
        ..album = 'After Dark'
        ..duration = const Duration(minutes: 5, seconds: 3)
        ..metaLoaded = true,
      GxTrack('/demo/untagged.ogg', 'untagged')..metaLoaded = true,
    ];

/// Render the widget under [key] to a PNG file.
Future<void> savePng(WidgetTester tester, GlobalKey key, String path) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
