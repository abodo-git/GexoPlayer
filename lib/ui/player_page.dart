import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../core/audio_engine.dart';
import '../core/backend.dart';
import '../core/m3u.dart';
import '../core/playlist.dart';
import '../core/state.dart';
import '../core/state_store.dart';
import '../core/track.dart';
import 'eq_sheet.dart';
import 'theme.dart';

class PlayerPage extends StatefulWidget {
  /// Inject a backend (tests, screenshots) and turn persistence off.
  final AudioBackend? backend;
  final bool persist;
  final GxThemeMode? initialTheme;
  /// Pre-filled playlist for tests and screenshots (skips the file pickers).
  final List<GxTrack>? initialTracks;
  const PlayerPage(
      {super.key,
      this.backend,
      this.persist = true,
      this.initialTheme,
      this.initialTracks});
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final AudioEngine engine = AudioEngine(
    backend: widget.backend,
    checkFiles: widget.backend == null,
    onChanged: () {
      if (mounted) setState(() {});
    },
  );
  final TextEditingController _searchCtl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _rootFocus = FocusNode();
  bool _searching = false;
  String _query = '';
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
    if (widget.initialTheme != null) themeMode = widget.initialTheme!;
    _posTimer = Timer.periodic(const Duration(seconds: 5), (_) => _persistSoon());
    if (widget.persist) {
      _restore();
    } else if (widget.initialTracks != null) {
      engine.playlist.add(widget.initialTracks!);
    }
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
    _searchCtl.dispose();
    _searchFocus.dispose();
    _rootFocus.dispose();
    if (widget.persist) unawaited(_store.save(_snapshot()));
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
      ..speed = engine.speed
      ..replayGain = engine.replayGain
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

  // --- Keyboard ------------------------------------------------------------

  bool get _typing => _searchFocus.hasFocus;

  Map<ShortcutActivator, VoidCallback> _shortcuts() {
    void guard(VoidCallback f) {
      if (!_typing) f();
    }

    void seekBy(int sec) {
      final t = pos + Duration(seconds: sec);
      final max = dur == Duration.zero ? t : dur;
      engine.seek(t < Duration.zero ? Duration.zero : (t > max ? max : t));
    }

    void vol(double d) {
      engine.setVolume(engine.volume + d);
      setState(() {});
      _persistSoon();
    }

    return {
      const SingleActivator(LogicalKeyboardKey.space): () => guard(engine.toggle),
      const SingleActivator(LogicalKeyboardKey.arrowRight): () => guard(() => seekBy(5)),
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () => guard(() => seekBy(-5)),
      const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): () =>
          guard(() => seekBy(30)),
      const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): () =>
          guard(() => seekBy(-30)),
      const SingleActivator(LogicalKeyboardKey.arrowUp): () => guard(() => vol(0.05)),
      const SingleActivator(LogicalKeyboardKey.arrowDown): () => guard(() => vol(-0.05)),
      const SingleActivator(LogicalKeyboardKey.keyN): () => guard(() => engine.next()),
      const SingleActivator(LogicalKeyboardKey.keyP): () => guard(() => engine.previous()),
      const SingleActivator(LogicalKeyboardKey.keyM): () => guard(engine.toggleMute),
      const SingleActivator(LogicalKeyboardKey.keyS): () => guard(() {
            setState(() => engine.playlist.shuffle = !engine.playlist.shuffle);
            _persistSoon();
          }),
      const SingleActivator(LogicalKeyboardKey.keyR): () => guard(() {
            final pl = engine.playlist;
            setState(() => pl.repeat =
                GxRepeat.values[(pl.repeat.index + 1) % GxRepeat.values.length]);
            _persistSoon();
          }),
      const SingleActivator(LogicalKeyboardKey.keyF, control: true): _toggleSearch,
      const SingleActivator(LogicalKeyboardKey.slash): () => guard(_toggleSearch),
      const SingleActivator(LogicalKeyboardKey.escape): () {
        if (_searching) _toggleSearch();
      },
    };
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _query = '';
        _searchCtl.clear();
        _rootFocus.requestFocus();
      }
    });
    if (_searching) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocus.requestFocus());
    }
  }

  Widget _searchBar() {
    final n = engine.playlist.search(_query).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: TextField(
        controller: _searchCtl,
        focusNode: _searchFocus,
        style: TextStyle(color: palette.text, fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: Icon(Icons.search, size: 18, color: palette.text),
          suffixText: _query.isEmpty ? null : '$n found',
          hintText: 'Search title, artist, album',
          border: OutlineInputBorder(
              borderSide: BorderSide(color: palette.border)),
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
    );
  }

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  String _speedLabel(double s) => s == s.roundToDouble() ? '${s.toInt()}x' : '${s}x';

  Future<void> _sleepMenu() async {
    final r = await showMenu<int>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 56, 8, 0),
      items: [
        for (final m in [5, 10, 15, 30, 45, 60, 90])
          PopupMenuItem(value: m, child: Text('Stop after $m min')),
        if (engine.sleep.active)
          const PopupMenuItem(value: -1, child: Text('Cancel sleep timer')),
      ],
    );
    if (r == null) return;
    if (r < 0) {
      engine.sleep.cancel();
    } else {
      engine.sleep.start(Duration(minutes: r));
    }
    setState(() {});
  }

  // --- UI ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final pl = engine.playlist;
    return Theme(
      data: palette.material(),
      child: CallbackShortcuts(
        bindings: _shortcuts(),
        child: Focus(
          focusNode: _rootFocus,
          autofocus: true,
          child: Scaffold(
            body: SafeArea(
              child: Column(children: [
                _header(),
                _nowPlaying(),
                if (_searching) _searchBar(),
                Expanded(child: _playlistView(pl)),
                _seekCluster(),
                _toolsRow(),
                _transport(pl),
              ]),
            ),
          ),
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
            maxLines: 1,
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
          tooltip: 'Search (Ctrl+F)',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.search, color: _searching ? palette.accent : palette.text),
          onPressed: _toggleSearch,
        ),
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
              default:
                if (v.startsWith('sort:')) {
                  final key = GxSort.values.byName(v.substring(5));
                  setState(() => engine.playlist.sortBy(key));
                  _persistSoon();
                }
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'files', child: Text('Add files')),
            PopupMenuItem(value: 'folder', child: Text('Add folder')),
            PopupMenuDivider(),
            PopupMenuItem(value: 'import', child: Text('Import M3U playlist')),
            PopupMenuItem(value: 'export', child: Text('Export as M3U')),
            PopupMenuDivider(),
            PopupMenuItem(value: 'sort:title', child: Text('Sort by title')),
            PopupMenuItem(value: 'sort:artist', child: Text('Sort by artist')),
            PopupMenuItem(value: 'sort:album', child: Text('Sort by album')),
            PopupMenuItem(value: 'sort:fileName', child: Text('Sort by file name')),
            PopupMenuItem(value: 'sort:duration', child: Text('Sort by length')),
            PopupMenuDivider(),
            PopupMenuItem(value: 'clear', child: Text('Clear playlist')),
          ],
        ),
      ]),
    );
  }

  Widget _cover(GxTrack? t, double size) {
    final box = BoxDecoration(
      color: palette.panelBg,
      border: Border.all(color: palette.border),
      borderRadius: BorderRadius.circular(4),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: box,
      child: t?.cover != null
          ? Image.memory(t!.cover!,
              fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, _, _) => _noArt(size))
          : _noArt(size),
    );
  }

  Widget _noArt(double size) => Icon(Icons.music_note,
      size: size * 0.5, color: palette.text.withValues(alpha: 0.35));

  Widget _nowPlaying() {
    final t = engine.playlist.current;
    final sub = [if (t?.artist != null) t!.artist!, if (t?.album != null) t!.album!]
        .join('  \u2022  ');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: palette.lcdBg,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(children: [
        _cover(t, 64),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              t == null ? 'GexoPlayer ready' : t.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: lcdStyle(palette, size: 15),
            ),
            if (sub.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: lcdStyle(palette, size: 12)
                        .copyWith(color: palette.lcdText.withValues(alpha: 0.7))),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _row(GxPlaylist pl, int i, {Key? key}) {
    final t = pl.tracks[i];
    final selected = i == pl.index;
    final queued = pl.queue.indexOf(t);
    final fg = selected ? palette.playlistSelectedText : palette.playlistText;
    return KeyedSubtree(
      key: key,
      child: ListTile(
        tileColor: selected ? palette.playlistSelectedBg : null,
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
          t.missing ? '${t.display}  (file missing)' : t.display,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            decoration: t.missing ? TextDecoration.lineThrough : null,
            color: t.missing ? Colors.redAccent : fg,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (queued >= 0)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text('Q${queued + 1}',
                  style: TextStyle(
                      color: palette.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          if (t.duration != null)
            Text(_fmt(t.duration!),
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: palette.playlistText.withValues(alpha: 0.7))),
          PopupMenuButton<String>(
            tooltip: 'Track actions',
            icon: Icon(Icons.more_horiz,
                size: 18, color: palette.playlistText.withValues(alpha: 0.7)),
            onSelected: (v) {
              switch (v) {
                case 'next':
                  setState(() => pl.playNext(i));
                case 'remove':
                  _removeAt(i);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'next', child: Text('Play next')),
              PopupMenuItem(value: 'remove', child: Text('Remove')),
            ],
          ),
        ]),
        onTap: () async {
          await engine.playIndex(i);
          _persistSoon();
        },
      ),
    );
  }

  Widget _playlistView(GxPlaylist pl) {
    final matches = pl.search(_query);
    final filtering = _query.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Material(
        color: palette.playlistBg,
        child: pl.tracks.isEmpty
          ? Center(
              child: Text('Add music to start  (menu, top right)',
                  style: TextStyle(color: palette.playlistText.withValues(alpha: 0.5))))
          : filtering
              ? (matches.isEmpty
                  ? Center(
                      child: Text('No matches',
                          style: TextStyle(
                              color: palette.playlistText.withValues(alpha: 0.5))))
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (_, k) => _row(pl, matches[k], key: ValueKey(matches[k])),
                    ))
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
                  itemBuilder: (_, i) => _row(pl, i, key: ObjectKey(pl.tracks[i])),
                ),
      ),
    );
  }

  Widget _chip({required Widget child, VoidCallback? onTap, bool active = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: active ? palette.accent : palette.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      ),
    );
  }

  Widget _toolsRow() {
    final rem = engine.sleep.remaining;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
      child: Row(children: [
        PopupMenuButton<double>(
          tooltip: 'Playback speed',
          initialValue: engine.speed,
          onSelected: (v) {
            engine.setSpeed(v);
            _persistSoon();
          },
          itemBuilder: (_) => [
            for (final v in _speeds)
              CheckedPopupMenuItem(
                  value: v, checked: v == engine.speed, child: Text(_speedLabel(v))),
          ],
          child: IgnorePointer(
            child: _chip(
              active: engine.speed != 1.0,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.speed, size: 14, color: palette.text),
                const SizedBox(width: 4),
                Text(_speedLabel(engine.speed),
                    style: TextStyle(color: palette.text, fontSize: 12)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _chip(
          active: engine.sleep.active,
          onTap: _sleepMenu,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.bedtime, size: 14, color: palette.text),
            const SizedBox(width: 4),
            Text(rem == null ? 'Sleep' : _fmt(rem),
                style: TextStyle(color: palette.text, fontSize: 12)),
          ]),
        ),
        const SizedBox(width: 8),
        _chip(
          active: engine.loopA != null,
          onTap: () {
            engine.cycleLoop(pos);
            setState(() {});
          },
          child: Text(
              engine.looping
                  ? 'A-B on'
                  : engine.loopA != null
                      ? 'A set'
                      : 'A-B',
              style: TextStyle(color: palette.text, fontSize: 12)),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<GxReplayGain>(
          tooltip: 'ReplayGain',
          initialValue: engine.replayGain,
          onSelected: (v) {
            engine.setReplayGain(v);
            _persistSoon();
          },
          itemBuilder: (_) => [
            for (final m in GxReplayGain.values)
              CheckedPopupMenuItem(
                  value: m,
                  checked: m == engine.replayGain,
                  child: Text(m == GxReplayGain.off
                      ? 'ReplayGain off'
                      : 'ReplayGain: ${m.name}')),
          ],
          child: IgnorePointer(
            child: _chip(
              active: engine.replayGain != GxReplayGain.off,
              child: Text('RG',
                  style: TextStyle(color: palette.text, fontSize: 12)),
            ),
          ),
        ),
        const Spacer(),
        Text('${engine.playlist.tracks.length} tracks',
            style: TextStyle(color: palette.text.withValues(alpha: 0.5), fontSize: 11)),
      ]),
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
          tooltip: 'Shuffle (S)',
          visualDensity: VisualDensity.compact,
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
          tooltip: 'Repeat (R)',
          visualDensity: VisualDensity.compact,
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
        IconButton(
          tooltip: 'Mute (M)',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 30, height: 40),
          icon: Icon(engine.muted ? Icons.volume_off : Icons.volume_up,
              size: 18, color: engine.muted ? palette.accent : palette.text.withValues(alpha: 0.8)),
          onPressed: engine.toggleMute,
        ),
        SizedBox(
          width: 96,
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
