import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'state.dart';

/// Loads/saves [GxPlayerState] as JSON in the app support directory.
/// All I/O is best-effort: persistence must never break playback.
class StateStore {
  File? _file;

  Future<File> _target() async {
    final cached = _file;
    if (cached != null) return cached;
    final dir = await getApplicationSupportDirectory();
    return _file = File(p.join(dir.path, 'gexoplayer_state.json'));
  }

  Future<GxPlayerState> load() async {
    try {
      final f = await _target();
      if (!await f.exists()) return GxPlayerState();
      final raw = jsonDecode(await f.readAsString());
      if (raw is Map<String, dynamic>) return GxPlayerState.fromJson(raw);
    } catch (_) {
      // Corrupt or unreadable state: start fresh.
    }
    return GxPlayerState();
  }

  Future<void> save(GxPlayerState s) async {
    try {
      final f = await _target();
      await f.writeAsString(jsonEncode(s.toJson()));
    } catch (_) {
      // Best-effort only.
    }
  }
}
