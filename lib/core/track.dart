import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// One playable file. Tag fields are filled in lazily by [GxMetadata].
class GxTrack {
  final String path;
  String title;
  String? artist;
  String? album;
  String? genre;
  int? trackNumber;
  int? year;
  Duration? duration;
  Uint8List? cover;
  bool metaLoaded = false;
  /// Set when the file could not be found or played; skipped on advance.
  bool missing = false;

  GxTrack(this.path, this.title);

  factory GxTrack.fromPath(String path) =>
      GxTrack(path, p.basenameWithoutExtension(path));

  /// "Artist - Title" when the artist is known, otherwise just the title.
  String get display => (artist == null || artist!.isEmpty) ? title : '$artist - $title';

  String get fileName => p.basename(path);
}
