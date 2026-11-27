import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/audio_engine.dart';
import '../core/playlist.dart';
import '../core/track.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final AudioEngine engine = AudioEngine(onChanged: () {
    if (mounted) setState(() {});
  });
  Duration pos = Duration.zero, dur = Duration.zero;
  double volume = 1;

  @override
  void initState() {
    super.initState();
    engine.position.listen((d) => mounted ? setState(() => pos = d) : null);
    engine.duration.listen((d) => mounted ? setState(() => dur = d) : null);
  }

  @override
  void dispose() {
    engine.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final r = await FilePicker.pickFiles(type: FileType.audio);
    if (r.isEmpty) return;
    await engine.addTracks(
        r.map((f) => f.path).whereType<String>().map(GxTrack.fromPath));
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final pl = engine.playlist;
    return Scaffold(
      appBar: AppBar(title: const Text('GexoPlayer'), actions: [
        IconButton(
            tooltip: 'Add files',
            icon: const Icon(Icons.library_add),
            onPressed: _add),
        IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => setState(pl.clear)),
      ]),
      body: Column(children: [
        Expanded(
          child: pl.tracks.isEmpty
              ? const Center(child: Text('Add music to start'))
              : ListView.builder(
                  itemCount: pl.tracks.length,
                  itemBuilder: (_, i) => ListTile(
                    selected: i == pl.index,
                    leading: Icon(i == pl.index && engine.playing
                        ? Icons.graphic_eq
                        : Icons.music_note),
                    title: Text(pl.tracks[i].title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => engine.playIndex(i),
                    trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => pl.removeAt(i))),
                  ),
                ),
        ),
        Slider(
          value: pos.inMilliseconds
              .clamp(0, dur.inMilliseconds == 0 ? 1 : dur.inMilliseconds)
              .toDouble(),
          max: dur.inMilliseconds == 0 ? 1 : dur.inMilliseconds.toDouble(),
          onChanged: (v) => engine.seek(Duration(milliseconds: v.toInt())),
        ),
        Text('${_fmt(pos)} / ${_fmt(dur)}'),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
              icon: Icon(Icons.shuffle,
                  color: pl.shuffle ? Colors.deepPurpleAccent : null),
              onPressed: () => setState(() => pl.shuffle = !pl.shuffle)),
          IconButton(
              iconSize: 36,
              icon: const Icon(Icons.skip_previous),
              onPressed: engine.previous),
          IconButton(
              iconSize: 56,
              icon: Icon(engine.playing
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill),
              onPressed: engine.toggle),
          IconButton(
              iconSize: 36,
              icon: const Icon(Icons.skip_next),
              onPressed: engine.next),
          IconButton(
              icon: Icon(
                  pl.repeat == GxRepeat.one ? Icons.repeat_one : Icons.repeat,
                  color: pl.repeat == GxRepeat.off
                      ? null
                      : Colors.deepPurpleAccent),
              onPressed: () => setState(() => pl.repeat = GxRepeat
                  .values[(pl.repeat.index + 1) % GxRepeat.values.length])),
        ]),
        Row(children: [
          const SizedBox(width: 16),
          const Icon(Icons.volume_up),
          Expanded(
              child: Slider(
                  value: volume,
                  onChanged: (v) {
                    setState(() => volume = v);
                    engine.setVolume(v);
                  })),
        ]),
        const SizedBox(height: 8),
      ]),
    );
  }
}
