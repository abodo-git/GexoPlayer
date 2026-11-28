import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/library.dart';
import '../core/metadata.dart';
import '../core/track.dart';
import 'theme.dart';

/// Browse the library by album, artist and folder, plus favorites,
/// recently played and saved playlists.
class LibraryPage extends StatefulWidget {
  final GxLibrary library;
  final GxPalette palette;

  /// Replace the queue with [tracks] and start at [start].
  final Future<void> Function(List<GxTrack> tracks, int start) onPlay;

  /// Append [tracks] to the queue.
  final Future<void> Function(List<GxTrack> tracks) onAdd;

  /// Pick a folder and scan it; returns a short result message (or null).
  final Future<String?> Function()? onScan;
  final void Function() onChanged;

  /// Test hook: cover loader (defaults to reading tags).
  final Future<Uint8List?> Function(String path)? coverLoader;

  const LibraryPage({
    super.key,
    required this.library,
    required this.palette,
    required this.onPlay,
    required this.onAdd,
    required this.onChanged,
    this.onScan,
    this.coverLoader,
  });

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final Map<String, Future<Uint8List?>> _covers = {};
  bool _scanning = false;

  GxLibrary get lib => widget.library;
  GxPalette get pal => widget.palette;

  Future<Uint8List?> _cover(String path) => _covers.putIfAbsent(path, () {
        final custom = widget.coverLoader;
        if (custom != null) return custom(path);
        return Isolate.run(() => GxMetadata.readSync(path).cover);
      });

  String _fmt(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    return h > 0
        ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _scan() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _scanning = true);
    final msg = await widget.onScan!();
    if (!mounted) return;
    setState(() => _scanning = false);
    if (msg != null) messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: pal.material(),
      child: DefaultTabController(
        length: 6,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: pal.panelBg,
            title: Text('Library  (${lib.length})',
                style: TextStyle(color: pal.text, fontSize: 16)),
            actions: [
              if (widget.onScan != null)
                IconButton(
                  tooltip: 'Add folder to library',
                  icon: _scanning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.create_new_folder),
                  onPressed: _scanning ? null : _scan,
                ),
            ],
            bottom: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: pal.accent,
              labelColor: pal.accent,
              unselectedLabelColor: pal.text,
              tabs: const [
                Tab(text: 'Albums'),
                Tab(text: 'Artists'),
                Tab(text: 'Folders'),
                Tab(text: 'Favorites'),
                Tab(text: 'Recent'),
                Tab(text: 'Playlists'),
              ],
            ),
          ),
          body: lib.length == 0 && lib.playlists.isEmpty
              ? Center(
                  child: Text('Library is empty.\nUse the folder button to scan your music.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: pal.text.withValues(alpha: 0.6))))
              : TabBarView(children: [
                  _albums(),
                  _artists(),
                  _folders(),
                  _flat(lib.favoriteEntries(), 'No favorites yet. Tap the heart on the player.'),
                  _flat(lib.recentEntries(), 'Nothing played yet.'),
                  _playlists(),
                ]),
        ),
      ),
    );
  }

  Widget _art(String path, double size) => FutureBuilder<Uint8List?>(
        future: _cover(path),
        builder: (_, snap) => Container(
          width: size,
          height: size,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: pal.panelBg,
            border: Border.all(color: pal.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: snap.data != null
              ? Image.memory(snap.data!,
                  fit: BoxFit.cover, errorBuilder: (_, _, _) => _noArt(size))
              : _noArt(size),
        ),
      );

  Widget _noArt(double size) => Icon(Icons.album,
      size: size * 0.45, color: pal.text.withValues(alpha: 0.3));

  Widget _albums() {
    final albums = lib.albums();
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.78),
      itemCount: albums.length,
      itemBuilder: (_, i) {
        final a = albums[i];
        return InkWell(
          onTap: () => _open(a.name, a.tracks.toList(), subtitle: a.artist),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: LayoutBuilder(
                  builder: (_, c) => _art(a.tracks.first.path, c.maxWidth)),
            ),
            const SizedBox(height: 6),
            Text(a.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: pal.text, fontWeight: FontWeight.bold, fontSize: 13)),
            Text('${a.artist}  \u2022  ${a.tracks.length}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: pal.text.withValues(alpha: 0.6), fontSize: 11)),
          ]),
        );
      },
    );
  }

  Widget _artists() {
    final artists = lib.artists();
    return ListView.builder(
      itemCount: artists.length,
      itemBuilder: (_, i) {
        final a = artists[i];
        return ListTile(
          dense: true,
          leading: CircleAvatar(
              backgroundColor: pal.panelBg,
              child: Text(a.name.isEmpty ? '?' : a.name[0].toUpperCase(),
                  style: TextStyle(color: pal.accent))),
          title: Text(a.name, style: TextStyle(color: pal.text)),
          subtitle: Text('${a.albumCount} albums, ${a.tracks.length} tracks',
              style: TextStyle(color: pal.text.withValues(alpha: 0.6), fontSize: 12)),
          onTap: () => _open(a.name, a.tracks),
        );
      },
    );
  }

  Widget _folders() {
    final folders = lib.folders();
    return ListView.builder(
      itemCount: folders.length,
      itemBuilder: (_, i) {
        final f = folders[i];
        return ListTile(
          dense: true,
          leading: Icon(Icons.folder, color: pal.accent),
          title: Text(f.path,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: pal.text)),
          subtitle: Text('${f.tracks.length} tracks',
              style: TextStyle(color: pal.text.withValues(alpha: 0.6), fontSize: 12)),
          onTap: () => _open(f.path, f.tracks),
        );
      },
    );
  }

  Widget _flat(List<GxEntry> entries, String empty) {
    if (entries.isEmpty) {
      return Center(
          child: Text(empty, style: TextStyle(color: pal.text.withValues(alpha: 0.6))));
    }
    return _EntryList(entries: entries, library: lib, palette: pal, fmt: _fmt,
        onPlay: (i) => widget.onPlay(entries.map((e) => e.toTrack()).toList(), i),
        onAdd: () => widget.onAdd(entries.map((e) => e.toTrack()).toList()),
        onFavoriteChanged: () => setState(widget.onChanged));
  }

  Widget _playlists() {
    final names = lib.playlists.keys.toList()..sort();
    if (names.isEmpty) {
      return Center(
          child: Text('No saved playlists. Use "Save playlist" in the player menu.',
              style: TextStyle(color: pal.text.withValues(alpha: 0.6))));
    }
    return ListView(children: [
      for (final n in names)
        Dismissible(
          key: ValueKey(n),
          direction: DismissDirection.endToStart,
          background: Container(
              color: Colors.red.shade900,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: const Icon(Icons.delete)),
          onDismissed: (_) {
            lib.deletePlaylist(n);
            setState(widget.onChanged);
          },
          child: ListTile(
            dense: true,
            leading: Icon(Icons.queue_music, color: pal.accent),
            title: Text(n, style: TextStyle(color: pal.text)),
            subtitle: Text('${lib.playlists[n]!.length} tracks',
                style: TextStyle(color: pal.text.withValues(alpha: 0.6), fontSize: 12)),
            onTap: () {
              final es = [
                for (final p in lib.playlists[n]!)
                  lib.entries[p]?.toTrack() ?? GxTrack.fromPath(p)
              ];
              widget.onPlay(es, 0);
              Navigator.of(context).maybePop();
            },
          ),
        ),
    ]);
  }

  void _open(String title, List<GxEntry> entries, {String? subtitle}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: pal.windowBg,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (_, scroll) => Column(children: [
          ListTile(
            title: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: pal.text, fontWeight: FontWeight.bold)),
            subtitle: subtitle == null
                ? null
                : Text(subtitle, style: TextStyle(color: pal.text.withValues(alpha: 0.6))),
          ),
          Expanded(
            child: _EntryList(
              entries: entries,
              library: lib,
              palette: pal,
              fmt: _fmt,
              controller: scroll,
              onPlay: (i) {
                widget.onPlay(entries.map((e) => e.toTrack()).toList(), i);
                Navigator.of(ctx).pop();
                Navigator.of(context).maybePop();
              },
              onAdd: () {
                widget.onAdd(entries.map((e) => e.toTrack()).toList());
                Navigator.of(ctx).pop();
              },
              onFavoriteChanged: () => setState(widget.onChanged),
            ),
          ),
        ]),
      ),
    );
  }
}

class _EntryList extends StatefulWidget {
  final List<GxEntry> entries;
  final GxLibrary library;
  final GxPalette palette;
  final String Function(Duration) fmt;
  final void Function(int index) onPlay;
  final VoidCallback onAdd;
  final VoidCallback onFavoriteChanged;
  final ScrollController? controller;
  const _EntryList({
    required this.entries,
    required this.library,
    required this.palette,
    required this.fmt,
    required this.onPlay,
    required this.onAdd,
    required this.onFavoriteChanged,
    this.controller,
  });
  @override
  State<_EntryList> createState() => _EntryListState();
}

class _EntryListState extends State<_EntryList> {
  @override
  Widget build(BuildContext context) {
    final pal = widget.palette;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          FilledButton.icon(
              onPressed: () => widget.onPlay(0),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play all')),
          const SizedBox(width: 8),
          OutlinedButton.icon(
              onPressed: widget.onAdd,
              icon: const Icon(Icons.playlist_add),
              label: const Text('Add to queue')),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          controller: widget.controller,
          itemCount: widget.entries.length,
          itemBuilder: (_, i) {
            final e = widget.entries[i];
            final fav = widget.library.favorites.contains(e.path);
            return ListTile(
              dense: true,
              title: Text(e.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: pal.text)),
              subtitle: Text(
                  [if (e.artist != null) e.artist!, if (e.album != null) e.album!].join('  \u2022  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: pal.text.withValues(alpha: 0.6), fontSize: 12)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (e.durationMs != null)
                  Text(widget.fmt(Duration(milliseconds: e.durationMs!)),
                      style: TextStyle(color: pal.text.withValues(alpha: 0.6), fontSize: 12)),
                IconButton(
                  tooltip: fav ? 'Remove favorite' : 'Add favorite',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                      size: 18, color: fav ? pal.accent : pal.text),
                  onPressed: () {
                    widget.library.toggleFavorite(e.path);
                    setState(() {});
                    widget.onFavoriteChanged();
                  },
                ),
              ]),
              onTap: () => widget.onPlay(i),
            );
          },
        ),
      ),
    ]);
  }
}
