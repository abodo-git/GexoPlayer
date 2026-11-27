import 'equalizer.dart';
import 'playlist.dart';

/// Visual theme choice.
enum GxThemeMode { modern, classic }

/// Everything that survives an app restart. Pure Dart, unit tested;
/// [StateStore] handles the file I/O.
class GxPlayerState {
  List<String> tracks = [];
  int? index;
  bool shuffle = false;
  GxRepeat repeat = GxRepeat.off;
  int positionMs = 0;
  double volume = 0.8;
  GxThemeMode theme = GxThemeMode.modern;
  bool showRemaining = false;
  final GxEq eq = GxEq();

  static const schemaVersion = 2;

  Map<String, dynamic> toJson() => {
        'version': schemaVersion,
        'tracks': tracks,
        'index': index,
        'shuffle': shuffle,
        'repeat': repeat.name,
        'positionMs': positionMs,
        'volume': volume,
        'theme': theme.name,
        'showRemaining': showRemaining,
        'eq': eq.toJson(),
      };

  /// Tolerant parse: any missing or malformed field falls back to default.
  static GxPlayerState fromJson(Map<String, dynamic> j) {
    final s = GxPlayerState();
    final t = j['tracks'];
    if (t is List) s.tracks = t.whereType<String>().toList();
    final i = j['index'];
    if (i is int && i >= 0 && i < s.tracks.length) s.index = i;
    s.shuffle = j['shuffle'] == true;
    s.repeat = GxRepeat.values.asNameMap()[j['repeat']] ?? GxRepeat.off;
    final pm = j['positionMs'];
    if (pm is int && pm >= 0) s.positionMs = pm;
    final v = j['volume'];
    if (v is num) s.volume = v.toDouble().clamp(0.0, 1.0).toDouble();
    s.theme =
        GxThemeMode.values.asNameMap()[j['theme']] ?? GxThemeMode.modern;
    s.showRemaining = j['showRemaining'] == true;
    final e = j['eq'];
    if (e is Map<String, dynamic>) s.eq.loadJson(e);
    return s;
  }
}
