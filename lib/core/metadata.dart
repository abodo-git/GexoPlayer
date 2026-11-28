import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';

import 'track.dart';

/// Plain tag data, safe to send between isolates.
class GxTags {
  final String? title, artist, album, genre;
  final int? trackNumber, year;
  final Duration? duration;
  final Uint8List? cover;
  const GxTags({
    this.title,
    this.artist,
    this.album,
    this.genre,
    this.trackNumber,
    this.year,
    this.duration,
    this.cover,
  });
}

String? _clean(String? s) {
  final t = s?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

/// Reads tags and embedded cover art. Never throws: unreadable files give
/// an empty [GxTags] so the track keeps its file-name title.
class GxMetadata {
  static GxTags readSync(String path, {bool cover = true}) {
    try {
      final m = readMetadata(File(path), getImage: cover);
      Uint8List? art;
      if (cover && m.pictures.isNotEmpty) {
        final front = m.pictures.where((x) => x.pictureType == PictureType.coverFront);
        art = (front.isNotEmpty ? front.first : m.pictures.first).bytes;
      }
      return GxTags(
        title: _clean(m.title),
        artist: _clean(m.artist) ?? _clean(m.albumArtist),
        album: _clean(m.album),
        genre: m.genres.isEmpty ? null : _clean(m.genres.first),
        trackNumber: m.trackNumber,
        year: m.year?.year,
        duration: m.duration,
        cover: art,
      );
    } catch (_) {
      return const GxTags();
    }
  }

  static void apply(GxTrack t, GxTags g) {
    if (g.title != null) t.title = g.title!;
    t.artist = g.artist;
    t.album = g.album;
    t.genre = g.genre;
    t.trackNumber = g.trackNumber;
    t.year = g.year;
    t.duration = g.duration;
    t.cover = g.cover;
    t.metaLoaded = true;
  }

  /// Load tags for [t] off the UI isolate.
  static Future<void> load(GxTrack t, {bool cover = true}) async {
    if (t.metaLoaded) return;
    final path = t.path;
    final tags = await Isolate.run(() => readSync(path, cover: cover));
    apply(t, tags);
  }
}
