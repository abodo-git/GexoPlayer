import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../core/audio_engine.dart';
import '../core/m3u.dart';
import '../core/playlist.dart';
import '../core/state.dart';
import '../core/state_store.dart';
import '../core/track.dart';
import 'eq_sheet.dart';
import 'theme.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final AudioEngine engine = AudioEngine(onChanged: () {
    if (mounted) setState(() {});
  });
  final StateStore _store = StateStore();

  Duration pos = Duration.zero, dur = Duration.zero;
  GxThemeMode themeMode = GxThemeMode.modern;
  bool showRemaining = false;
  bool _restored = false;

  Timer? _saveTimer;
  Timer? _posTimer;

  GxPalette get palette =>
      themeMode == GxThemeMode.classic ? classicPalette : modernPalette;

  @override
  void initState() {
    super.initState();
    engine.position.listen((d) {
      if (mounted) setState(() => pos = d);
    });
    engine.duration.listen((d) {
      if (mounted) setState(() => dur = d);
    });
    _posTimer = Timer.periodic(const Duration(seconds: 5), (_) => _persistSoon());
    _restore();
  }

  Future<void> _restore() async {
    final s = await _store.load();
    if (!mounted) return;
    themeMode = s.theme;
    showRemaining = s.showRemaining;
    await engine.restore(s, resumeAt: Duration(milliseconds: s.positionMs));
    if (!mounted) return;
    setState(() => _restored = true);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _posTimer?.cancel();
    unawaited(_store.save(_snapshot()));
    engine.dispose();
    super.dispose();
  }

  GxPlayerState _snapshot() {
    final pl = engine.playlist;
    final s = GxPlayerState()
      ..tracks = pl.tracks.map((t) => t.path).toList()
      ..index = pl.index
      ..shuffle = pl.shuffle
      ..repeat = pl.repeat
      ..positionMs = pos.inMilliseconds
      ..volume = engine.volume
      ..theme = themeMode
      ..showRemaining = showRemaining;
    s.eq.copyFrom(engine.eq);
    return s;
  }

  void _persistSoon() {
    if (!_restored) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(
        const Duration(milliseconds: 600), () => unawaited(_store.save(_snapshot())));
  }

  // --- Library actions -----------------------------------------------------

  Future<void> _addFiles() async {
    final messenger = ScaffoldMessenger.of(context);
    final r = await FilePicker.pickFiles(type: FileType.audio);
    if (r.isEmpty) return;
    final tracks =
        r.map((f) => f.path).whereType<String>().map(GxTrack.fromPath).toList();
    if (tracks.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('No files selected')));
      return;
    }
    await engine.addTracks(tracks);
    _persistSoon();
  }

  static const _audioExts = {
    '.mp3', '.flac', '.wav', '.ogg', '.oga', '.m4a', '.aac', '.opus',
    '.wma', '.aiff', '.aif', '.ape', '.mka', '.wv', '.mpc', '.tta',
  };

  Future<void> _addFolder() async {
    final messenger = ScaffoldMessenger.of(context);
    final dir = await FilePicker.getDirectoryPath();
    if (dir == null) return;
    final found = <GxTrack>[];
    try {
      await for (final e in Directory(dir).list(recursive: true, followLinks: false)) {
        if (e is File && _audioExts.contains(p.extension(e.path).toLowerCase())) {
          found.add(GxTrack.fromPath(e.path));
        }
      }
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not scan that folder')));
      return;
    }
    if (found.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('No audio files found in that folder')));
      return;
    }
    found.sort((a, b) => a.path.compareTo(b.path));
    await engine.addTracks(found);
    messenger.showSnackBar(
        SnackBar(content: Text('Added ${found.length} tracks from folder')));
    _persistSoon();
  }

  Future<void> _importM3u() async {
    final messenger = ScaffoldMessenger.of(context);
    final r = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: ['m3u', 'm3u8']);
    if (r.isEmpty) return;
    final path = r.first.path;
    if (path == null) return;
    try {
      final content = await File(path).readAsString();
      final paths = GxM3u.decode(content, baseDir: p.dirname(path));
      if (paths.isEmpty) {
        messenger.showSnackBar(
            const SnackBar(content: Text('That playlist file is empty')));
        return;
      }
      await engine.addTracks(paths.map(GxTrack.fromPath));
      messenger.showSnackBar(
          SnackBar(content: Text('Imported ${paths.length} tracks')));
      _persistSoon();
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not read that playlist file')));
    }
  }

  Future<void> _exportM3u() async {
    final messenger = ScaffoldMessenger.of(context);
    final tracks = engine.playlist.tracks;
    if (tracks.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Playlist is empty')));
      return;
    }
    try {
      final bytes = Uint8List.fromList(utf8.encode(GxM3u.encode(tracks)));
      final out = await FilePicker.saveFile(
        dialogTitle: 'Save playlist',
        fileName: 'playlist.m3u',
        bytes: bytes,
      );
      if (out != null) {
        messenger.showSnackBar(SnackBar(content: Text('Playlist saved: $out')));
      }
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not save the playlist')));
    }
  }

  void _clearPlaylist() {
    final messenger = ScaffoldMessenger.of(context);
    final pl = engine.playlist;
    final old = List<GxTrack>.of(pl.tracks);
    final oldIndex = pl.index;
    setState(pl.clear);
    _persistSoon();
    messenger.showSnackBar(SnackBar(
      content: const Text('Playlist cleared'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          setState(() {
            pl.add(old);
            pl.index = oldIndex;
          });
          _persistSoon();
        },
      ),
    ));
  }

  void _removeAt(int i) {
    setState(() => engine.playlist.removeAt(i));
    _persistSoon();
  }

  // --- Formatting ----------------------------------------------------------

  String _fmt(Duration d) {
    final sign = d.isNegative ? '-' : '';
    final a = d.abs();
    final h = a.inHours;
    final m = a.inMinutes % 60;
    final sec = (a.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0
        ? '$sign$h:${m.toString().padLeft(2, '0')}:$sec'
        : '$sign$m:$sec';
  }

  // --- UI ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final pl = engine.playlist;
    return Theme(
      data: palette.material(),
      child: Scaffold(
        body: SafeArea(
          child: Column(children: [
            _header(),
            _nowPlaying(),
            Expanded(child: _playlistView(pl)),
            _seekCluster(),
            _transport(pl),
          ]),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: palette.panelBg,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(children: [
        Icon(Icons.graphic_eq, color: palette.accent, size: 20),
        const SizedBox(width: 8),
        Text('GexoPlayer',
            style: TextStyle(
                color: palette.text,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5)),
        const SizedBox(width: 8),
        Text(palette.name,
            style: TextStyle(
                color: palette.text.withValues(alpha: 0.45), fontSize: 11)),
        const Spacer(),
        IconButton(
          tooltip: 'Equalizer',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.tune,
              color: engine.eq.enabled ? palette.accent : palette.text),
          onPressed: () => GxEqSheet.show(context,
              engine: engine, palette: palette, onChanged: _persistSoon),
        ),
        IconButton(
          tooltip: 'Switch theme',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.palette, color: palette.text),
          onPressed: () {
            setState(() {
              themeMode = themeMode == GxThemeMode.modern
                  ? GxThemeMode.classic
                  : GxThemeMode.modern;
            });
            _persistSoon();
          },
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: palette.text),
          onSelected: (v) {
            switch (v) {
              case 'files':
                _addFiles();
              case 'folder':
                _addFolder();
              case 'import':
                _importM3u();
              case 'export':
                _exportM3u();
              case 'clear':
                _clearPlaylist();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'files', child: Text('Add files')),
            PopupMenuItem(value: 'folder', child: Text('Add folder')),
            PopupMenuDivider(),
            PopupMenuItem(value: 'import', child: Text('Import M3U playlist')),
            PopupMenuItem(value: 'export', child: Text('Export as M3U')),
            PopupMenuDivider(),
            PopupMenuItem(value: 'clear', child: Text('Clear playlist')),
          ],
        ),
      ]),
    );
  }

  Widget _nowPlaying() {
    final t = engine.playlist.current;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.lcdBg,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        t == null ? 'GexoPlayer ready' : t.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: lcdStyle(palette, size: 13),
      ),
    );
  }

  Widget _playlistView(GxPlaylist pl) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: palette.playlistBg,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: pl.tracks.isEmpty
          ? Center(
              child: Text('Add music to start  (menu, top right)',
                  style: TextStyle(color: palette.playlistText.withValues(alpha: 0.5))))
          : ReorderableListView.builder(
              buildDefaultDragHandles: true,
              itemCount: pl.tracks.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  pl.move(oldIndex, newIndex);
                });
                _persistSoon();
              },
              itemBuilder: (_, i) {
                final t = pl.tracks[i];
                final selected = i == pl.index;
                return Container(
                  key: ObjectKey(t),
                  color: selected ? palette.playlistSelectedBg : null,
                  child: ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: SizedBox(
                      width: 34,
                      child: Text('${i + 1}.',
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: palette.playlistText.withValues(alpha: 0.6))),
                    ),
                    title: Text(
                      t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: selected
                            ? palette.playlistSelectedText
                            : palette.playlistText,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close,
                          size: 16,
                          color: palette.playlistText.withValues(alpha: 0.6)),
                      onPressed: () => _removeAt(i),
                    ),
                    onTap: () async {
                      await engine.playIndex(i);
                      _persistSoon();
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _seekCluster() {
    final maxMs = dur.inMilliseconds == 0 ? 1 : dur.inMilliseconds;
    final right = showRemaining ? -(dur - pos) : dur;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(children: [
        Slider(
          value: pos.inMilliseconds.clamp(0, maxMs).toDouble(),
          max: maxMs.toDouble(),
          onChanged: (v) {
            engine.seek(Duration(milliseconds: v.toInt()));
            _persistSoon();
          },
        ),
        Row(children: [
          _lcd(_fmt(pos)),
          const Spacer(),
          GestureDetector(
            onTap: () {
              setState(() => showRemaining = !showRemaining);
              _persistSoon();
            },
            child: _lcd(_fmt(right)),
          ),
        ]),
      ]),
    );
  }

  Widget _lcd(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.lcdBg,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(text, style: lcdStyle(palette)),
    );
  }

  Widget _transport(GxPlaylist pl) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          tooltip: 'Shuffle',
          icon: Icon(Icons.shuffle,
              size: 20, color: pl.shuffle ? palette.accent : palette.text),
          onPressed: () {
            setState(() => pl.shuffle = !pl.shuffle);
            _persistSoon();
          },
        ),
        IconButton(
          tooltip: 'Previous',
          iconSize: 34,
          icon: const Icon(Icons.skip_previous),
          onPressed: () async {
            await engine.previous();
            _persistSoon();
          },
        ),
        IconButton(
          tooltip: engine.playing ? 'Pause' : 'Play',
          iconSize: 52,
          icon: Icon(
            engine.playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
            color: palette.accent,
          ),
          onPressed: () async {
            await engine.toggle();
            _persistSoon();
          },
        ),
        IconButton(
          tooltip: 'Next',
          iconSize: 34,
          icon: const Icon(Icons.skip_next),
          onPressed: () async {
            await engine.next();
            _persistSoon();
          },
        ),
        IconButton(
          tooltip: 'Repeat',
          icon: Icon(
            pl.repeat == GxRepeat.one ? Icons.repeat_one : Icons.repeat,
            size: 20,
            color: pl.repeat == GxRepeat.off ? palette.text : palette.accent,
          ),
          onPressed: () {
            setState(() => pl.repeat =
                GxRepeat.values[(pl.repeat.index + 1) % GxRepeat.values.length]);
            _persistSoon();
          },
        ),
        const SizedBox(width: 4),
        Icon(Icons.volume_up, size: 18, color: palette.text.withValues(alpha: 0.8)),
        SizedBox(
          width: 110,
          child: Slider(
            value: engine.volume,
            onChanged: (v) {
              engine.setVolume(v);
              setState(() {});
              _persistSoon();
            },
          ),
        ),
      ]),
    );
  }
}
