import 'dart:math';
import 'track.dart';

enum GxRepeat { off, all, one }

enum GxSort { title, artist, album, fileName, duration }

/// Pure playlist logic (no audio dependency) so it is easy to unit test.
class GxPlaylist {
  final List<GxTrack> tracks = [];
  int? index;
  bool shuffle = false;
  GxRepeat repeat = GxRepeat.off;
  final Random _rng;
  /// "Play next" queue: consumed before the normal order.
  final List<GxTrack> queue = [];

  GxPlaylist({Random? rng}) : _rng = rng ?? Random();

  GxTrack? get current => index == null ? null : tracks[index!];

  void add(Iterable<GxTrack> items) {
    tracks.addAll(items);
    index ??= tracks.isEmpty ? null : 0;
  }

  void removeAt(int i) {
    queue.remove(tracks[i]);
    tracks.removeAt(i);
    if (tracks.isEmpty) {
      index = null;
    } else if (index != null) {
      if (i < index!) {
        index = index! - 1;
      } else if (i == index!) {
        index = min(index!, tracks.length - 1);
      }
    }
  }

  void clear() {
    queue.clear();
    tracks.clear();
    index = null;
  }

  /// Move the track at [from] to final position [to], keeping the
  /// current selection on the same track.
  void move(int from, int to) {
    if (from == to) return;
    if (from < 0 || from >= tracks.length || to < 0 || to >= tracks.length) {
      return;
    }
    final t = tracks.removeAt(from);
    tracks.insert(to, t);
    if (index == null) return;
    if (index == from) {
      index = to;
    } else if (from < index! && to >= index!) {
      index = index! - 1;
    } else if (from > index! && to <= index!) {
      index = index! + 1;
    }
  }

  void select(int i) {
    if (i >= 0 && i < tracks.length) index = i;
  }

  /// Advance to the next track. [auto] is true when a track ended naturally.
  GxTrack? next({bool auto = false}) {
    if (tracks.isEmpty) return null;
    if (auto && repeat == GxRepeat.one) return current;
    while (queue.isNotEmpty) {
      final q = queue.removeAt(0);
      final qi = tracks.indexOf(q);
      if (qi >= 0) {
        index = qi;
        return current;
      }
    }
    if (shuffle && tracks.length > 1) {
      int n;
      do {
        n = _rng.nextInt(tracks.length);
      } while (n == index);
      index = n;
      return current;
    }
    final i = (index ?? -1) + 1;
    if (i >= tracks.length) {
      if (repeat == GxRepeat.all || !auto) {
        index = 0;
        return current;
      }
      return null;
    }
    index = i;
    return current;
  }

  GxTrack? previous() {
    if (tracks.isEmpty) return null;
    index = ((index ?? 0) - 1 + tracks.length) % tracks.length;
    return current;
  }

  /// Queue the track at [i] to play right after the current one.
  void playNext(int i) {
    if (i < 0 || i >= tracks.length) return;
    final t = tracks[i];
    queue.remove(t);
    queue.add(t);
  }

  /// Sort in place, keeping the selection on the same track.
  void sortBy(GxSort key, {bool descending = false}) {
    final cur = current;
    String s(String? v) => (v ?? '').toLowerCase();
    int cmp(GxTrack a, GxTrack b) {
      switch (key) {
        case GxSort.title:
          return s(a.title).compareTo(s(b.title));
        case GxSort.artist:
          final c = s(a.artist).compareTo(s(b.artist));
          return c != 0 ? c : s(a.title).compareTo(s(b.title));
        case GxSort.album:
          final c = s(a.album).compareTo(s(b.album));
          return c != 0
              ? c
              : (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0);
        case GxSort.fileName:
          return s(a.fileName).compareTo(s(b.fileName));
        case GxSort.duration:
          return (a.duration ?? Duration.zero)
              .compareTo(b.duration ?? Duration.zero);
      }
    }
    tracks.sort(descending ? (a, b) => cmp(b, a) : cmp);
    if (cur != null) index = tracks.indexOf(cur);
  }

  /// Indices of tracks matching [query] (title, artist, album, file name).
  /// An empty query matches everything.
  List<int> search(String query) {
    final q = query.trim().toLowerCase();
    return [
      for (var i = 0; i < tracks.length; i++)
        if (q.isEmpty || _hay(tracks[i]).contains(q)) i
    ];
  }

  static String _hay(GxTrack t) =>
      '${t.title} ${t.artist ?? ''} ${t.album ?? ''} ${t.fileName}'.toLowerCase();
}
