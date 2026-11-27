import 'dart:convert';

import 'package:path/path.dart' as p;

import 'track.dart';

/// M3U/M3U8 playlist import & export. Pure Dart, unit tested.
class GxM3u {
  /// Extended M3U with one #EXTINF line per track.
  static String encode(List<GxTrack> tracks) {
    final b = StringBuffer('#EXTM3U\n');
    for (final t in tracks) {
      b.writeln('#EXTINF:-1,${t.title}');
      b.writeln(t.path);
    }
    return b.toString();
  }

  /// Paths/URLs from [content]. Comment and header lines are skipped.
  /// Relative paths resolve against [baseDir] (the .m3u file's folder).
  static List<String> decode(String content, {String? baseDir}) {
    final out = <String>[];
    for (final raw in const LineSplitter().convert(content)) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final isRemote = line.contains('://');
      if (baseDir != null && baseDir.isNotEmpty && !isRemote && !p.isAbsolute(line)) {
        out.add(p.normalize(p.join(baseDir, line)));
      } else {
        out.add(line);
      }
    }
    return out;
  }
}
