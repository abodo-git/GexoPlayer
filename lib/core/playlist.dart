import 'dart:math';
import 'track.dart';

enum GxRepeat { off, all, one }

/// Pure playlist logic (no audio dependency) so it is easy to unit test.
class GxPlaylist {
  final List<GxTrack> tracks = [];
  int? index;
  bool shuffle = false;
  GxRepeat repeat = GxRepeat.off;
  final Random _rng;

  GxPlaylist({Random? rng}) : _rng = rng ?? Random();

  GxTrack? get current => index == null ? null : tracks[index!];

  void add(Iterable<GxTrack> items) {
    tracks.addAll(items);
    index ??= tracks.isEmpty ? null : 0;
  }

  void removeAt(int i) {
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
}
