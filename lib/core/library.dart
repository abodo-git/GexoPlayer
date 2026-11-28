import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import 'metadata.dart';
import 'track.dart';

const gxAudioExts = {
  '.mp3', '.flac', '.wav', '.ogg', '.oga', '.m4a', '.aac', '.opus',
  '.wma', '.aiff', '.aif', '.ape', '.mka', '.wv', '.mpc', '.tta',
};

/// One indexed file. Cover art is not stored (loaded on demand).
class GxEntry {
  final String path;
  String title;
  String? artist, album, genre;
  int? trackNumber, year, durationMs;
  int mtimeMs;
  int addedMs;

  GxEntry(this.path, this.title,
      {this.artist,
      this.album,
      this.genre,
      this.trackNumber,
      this.year,
      this.durationMs,
      this.mtimeMs = 0,
      this.addedMs = 0});

  Map<String, dynamic> toJson() => {
        'path': path,
        'title': title,
        'artist': artist,
        'album': album,
        'genre': genre,
        'track': trackNumber,
        'year': year,
        'dur': durationMs,
        'mtime': mtimeMs,
        'added': addedMs,
      };

  static GxEntry? fromJson(Object? j) {
    if (j is! Map) return null;
    final path = j['path'];
    final title = j['title'];
    if (path is! String || title is! String) return null;
    String? s(Object? v) => v is String ? v : null;
    int? n(Object? v) => v is int ? v : null;
    return GxEntry(path, title,
        artist: s(j['artist']),
        album: s(j['album']),
        genre: s(j['genre']),
        trackNumber: n(j['track']),
        year: n(j['year']),
        durationMs: n(j['dur']),
        mtimeMs: n(j['mtime']) ?? 0,
        addedMs: n(j['added']) ?? 0);
  }

  GxTrack toTrack() {
    final t = GxTrack(path, title)
      ..artist = artist
      ..album = album
      ..genre = genre
      ..trackNumber = trackNumber
      ..year = year
      ..duration = durationMs == null ? null : Duration(milliseconds: durationMs!)
      ..metaLoaded = true;
    return t;
  }
}

class GxAlbum {
  final String name;
  final String artist;
  final List<GxEntry> tracks;
  GxAlbum(this.name, this.artist, this.tracks);
  Duration get length =>
      Duration(milliseconds: tracks.fold(0, (a, t) => a + (t.durationMs ?? 0)));
}

class GxArtist {
  final String name;
  final List<GxEntry> tracks;
  GxArtist(this.name, this.tracks);
  int get albumCount => tracks.map((t) => t.album ?? '').toSet().length;
}

class GxFolder {
  final String path;
  final List<GxEntry> tracks;
  GxFolder(this.path, this.tracks);
}

class GxScanResult {
  final int added, updated, removed, failed;
  const GxScanResult(this.added, this.updated, this.removed, this.failed);
}

/// The media library: indexed tracks plus favorites, history and playlists.
/// Pure Dart (except [scan]); persisted as one JSON document.
class GxLibrary {
  static const unknownAlbum = 'Unknown album';
  static const unknownArtist = 'Unknown artist';
  static const variousArtists = 'Various artists';
  static const maxRecent = 50;

  final Map<String, GxEntry> entries = {};
  final Set<String> favorites = {};
  final List<String> recent = [];
  final Map<String, List<String>> playlists = {};
  final List<String> roots = [];

  int get length => entries.length;

  // --- Grouping ------------------------------------------------------------

  /// Tracks sharing an album name form one album (compilations included);
  /// untagged albums are split by artist so they do not merge into one blob.
  List<GxAlbum> albums() {
    final m = <String, List<GxEntry>>{};
    for (final e in entries.values) {
      final key = e.album == null
          ? '\u0000${(e.artist ?? unknownArtist).toLowerCase()}'
          : e.album!.toLowerCase();
      m.putIfAbsent(key, () => []).add(e);
    }
    final out = <GxAlbum>[];
    for (final l in m.values) {
      final artists = l.map((e) => (e.artist ?? unknownArtist)).toSet();
      out.add(GxAlbum(l.first.album ?? unknownAlbum,
          artists.length == 1 ? artists.first : variousArtists, _byTrack(l)));
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  List<GxArtist> artists() {
    final m = <String, List<GxEntry>>{};
    final names = <String, String>{};
    for (final e in entries.values) {
      final n = e.artist ?? unknownArtist;
      m.putIfAbsent(n.toLowerCase(), () => []).add(e);
      names.putIfAbsent(n.toLowerCase(), () => n);
    }
    final out = [for (final k in m.keys) GxArtist(names[k]!, _byTrack(m[k]!))];
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  List<GxFolder> folders() {
    final m = <String, List<GxEntry>>{};
    for (final e in entries.values) {
      m.putIfAbsent(p.dirname(e.path), () => []).add(e);
    }
    final out = [for (final k in m.keys) GxFolder(k, _byTrack(m[k]!))];
    out.sort((a, b) => a.path.compareTo(b.path));
    return out;
  }

  static List<GxEntry> _byTrack(List<GxEntry> l) {
    final c = [...l];
    c.sort((a, b) {
      final t = (a.trackNumber ?? 9999).compareTo(b.trackNumber ?? 9999);
      return t != 0 ? t : a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return c;
  }

  List<GxEntry> favoriteEntries() =>
      [for (final f in favorites) if (entries[f] != null) entries[f]!];

  List<GxEntry> recentEntries() =>
      [for (final r in recent) if (entries[r] != null) entries[r]!];

  List<GxEntry> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return entries.values.toList();
    return entries.values
        .where((e) =>
            '${e.title} ${e.artist ?? ''} ${e.album ?? ''}'.toLowerCase().contains(q))
        .toList();
  }

  // --- Favorites, history, playlists ----------------------------------------

  bool toggleFavorite(String path) {
    if (!favorites.remove(path)) {
      favorites.add(path);
      return true;
    }
    return false;
  }

  void played(String path) {
    recent.remove(path);
    recent.insert(0, path);
    if (recent.length > maxRecent) recent.removeRange(maxRecent, recent.length);
  }

  /// Save [paths] as playlist [name] (replaces an existing one).
  void savePlaylist(String name, Iterable<String> paths) {
    final n = name.trim();
    if (n.isEmpty) return;
    playlists[n] = paths.toList();
  }

  bool deletePlaylist(String name) => playlists.remove(name) != null;

  // --- Scan ------------------------------------------------------------------

  /// Index every audio file under [dir]. Unchanged files (same mtime) are
  /// skipped; entries for files that vanished from [dir] are removed.
  /// [onProgress] gets (done, total).
  Future<GxScanResult> scan(Directory dir,
      {void Function(int done, int total)? onProgress}) async {
    final files = <File>[];
    await for (final e in dir.list(recursive: true, followLinks: false)
        .handleError((_) {})) {
      if (e is File && gxAudioExts.contains(p.extension(e.path).toLowerCase())) {
        files.add(e);
      }
    }
    final root = p.normalize(dir.path);
    if (!roots.contains(root)) roots.add(root);
    final seen = <String>{};
    var added = 0, updated = 0, failed = 0, done = 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    // Read tags in small batches inside one isolate per batch.
    const batch = 16;
    for (var i = 0; i < files.length; i += batch) {
      final chunk = files.sublist(i, (i + batch).clamp(0, files.length));
      final todo = <String, int>{};
      for (final f in chunk) {
        seen.add(f.path);
        final mtime = f.statSync().modified.millisecondsSinceEpoch;
        final old = entries[f.path];
        if (old != null && old.mtimeMs == mtime) continue;
        todo[f.path] = mtime;
      }
      if (todo.isNotEmpty) {
        final paths = todo.keys.toList();
        final tags = await Isolate.run(
            () => [for (final path in paths) GxMetadata.readSync(path, cover: false)]);
        for (var k = 0; k < paths.length; k++) {
          final path = paths[k];
          final g = tags[k];
          final old = entries[path];
          if (g.title == null && g.artist == null && g.duration == null) failed++;
          final e = GxEntry(path, g.title ?? p.basenameWithoutExtension(path),
              artist: g.artist,
              album: g.album,
              genre: g.genre,
              trackNumber: g.trackNumber,
              year: g.year,
              durationMs: g.duration?.inMilliseconds,
              mtimeMs: todo[path]!,
              addedMs: old?.addedMs ?? now);
          entries[path] = e;
          old == null ? added++ : updated++;
        }
      }
      done += chunk.length;
      onProgress?.call(done, files.length);
    }
    final prefix = root.endsWith(p.separator) ? root : root + p.separator;
    final gone = entries.keys
        .where((k) => k.startsWith(prefix) && !seen.contains(k))
        .toList();
    for (final k in gone) {
      entries.remove(k);
    }
    return GxScanResult(added, updated, gone.length, failed);
  }

  // --- JSON ------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'version': 1,
        'roots': roots,
        'entries': [for (final e in entries.values) e.toJson()],
        'favorites': favorites.toList(),
        'recent': recent,
        'playlists': playlists,
      };

  static GxLibrary fromJson(Map<String, dynamic> j) {
    final l = GxLibrary();
    if (j['roots'] is List) l.roots.addAll((j['roots'] as List).whereType<String>());
    if (j['entries'] is List) {
      for (final x in j['entries'] as List) {
        final e = GxEntry.fromJson(x);
        if (e != null) l.entries[e.path] = e;
      }
    }
    if (j['favorites'] is List) {
      l.favorites.addAll((j['favorites'] as List).whereType<String>());
    }
    if (j['recent'] is List) {
      l.recent.addAll((j['recent'] as List).whereType<String>().take(maxRecent));
    }
    final pl = j['playlists'];
    if (pl is Map) {
      pl.forEach((k, v) {
        if (k is String && v is List) l.playlists[k] = v.whereType<String>().toList();
      });
    }
    return l;
  }
}

/// Loads and saves the library JSON. Best effort, never throws.
class GxLibraryStore {
  final Future<File> Function() _target;
  GxLibraryStore(this._target);

  Future<GxLibrary> load() async {
    try {
      final f = await _target();
      if (!await f.exists()) return GxLibrary();
      final raw = jsonDecode(await f.readAsString());
      if (raw is Map<String, dynamic>) return GxLibrary.fromJson(raw);
    } catch (_) {}
    return GxLibrary();
  }

  Future<void> save(GxLibrary l) async {
    try {
      final f = await _target();
      await f.writeAsString(jsonEncode(l.toJson()));
    } catch (_) {}
  }
}
