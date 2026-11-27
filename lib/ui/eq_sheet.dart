import 'package:flutter/material.dart';

import '../core/audio_engine.dart';
import '../core/equalizer.dart';
import 'theme.dart';

/// Winamp-style 10-band equalizer sheet.
class GxEqSheet extends StatefulWidget {
  final AudioEngine engine;
  final GxPalette palette;
  final VoidCallback onChanged;

  const GxEqSheet({
    super.key,
    required this.engine,
    required this.palette,
    required this.onChanged,
  });

  static Future<void> show(BuildContext context,
      {required AudioEngine engine,
      required GxPalette palette,
      required VoidCallback onChanged}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.panelBg,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: GxEqSheet(engine: engine, palette: palette, onChanged: onChanged),
      ),
    );
  }

  @override
  State<GxEqSheet> createState() => _GxEqSheetState();
}

class _GxEqSheetState extends State<GxEqSheet> {
  GxEq get eq => widget.engine.eq;
  GxPalette get p => widget.palette;

  static const _labels = [
    '60', '170', '310', '600', '1K', '3K', '6K', '12K', '14K', '16K'
  ];

  void _apply() {
    setState(() {});
    widget.engine.applyEq();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Equalizer',
                  style: TextStyle(
                      color: p.text, fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(eq.enabled ? 'ON' : 'OFF',
                  style: TextStyle(
                      color: eq.enabled ? p.accent : p.text.withValues(alpha: 0.5),
                      fontWeight: FontWeight.bold)),
              Switch(
                value: eq.enabled,
                activeTrackColor: p.accent,
                onChanged: (v) {
                  eq.enabled = v;
                  _apply();
                },
              ),
            ]),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in GxEq.presets.keys)
                  ActionChip(
                    label: Text(name, style: const TextStyle(fontSize: 11)),
                    backgroundColor: p.windowBg,
                    side: BorderSide(color: p.border),
                    onPressed: () {
                      eq.applyPreset(name);
                      eq.enabled = true;
                      _apply();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 190,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PreampSlider(
                    value: eq.preampDb,
                    palette: p,
                    onChanged: (v) {
                      eq.preampDb = GxEq.clampDb(v);
                      _apply();
                    },
                  ),
                  const VerticalDivider(width: 12),
                  for (var i = 0; i < GxEq.bandFreqs.length; i++)
                    Expanded(
                      child: _BandSlider(
                        label: _labels[i],
                        value: eq.bands[i],
                        palette: p,
                        onChanged: (v) {
                          eq.setBand(i, v);
                          eq.enabled = true;
                          _apply();
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              TextButton.icon(
                onPressed: () {
                  eq.zero();
                  _apply();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reset'),
              ),
              const Spacer(),
              Text(
                '${eq.bands.map((b) => b.toStringAsFixed(1)).join('  ')} dB',
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: p.text.withValues(alpha: 0.6)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _BandSlider extends StatelessWidget {
  final String label;
  final double value;
  final GxPalette palette;
  final ValueChanged<double> onChanged;

  const _BandSlider({
    required this.label,
    required this.value,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value.toStringAsFixed(0),
          style: TextStyle(
              fontSize: 9,
              fontFamily: 'monospace',
              color: value == 0
                  ? palette.text.withValues(alpha: 0.4)
                  : palette.accent)),
      Expanded(
        child: RotatedBox(
          quarterTurns: 3,
          child: SliderTheme(
            data: const SliderThemeData(
              trackHeight: 2,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: RoundSliderOverlayShape(overlayRadius: 10),
            ),
            child: Slider(
              value: value,
              min: GxEq.minDb,
              max: GxEq.maxDb,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
      Text(label,
          style: TextStyle(
              fontSize: 9,
              fontFamily: 'monospace',
              color: palette.text.withValues(alpha: 0.7))),
    ]);
  }
}

class _PreampSlider extends StatelessWidget {
  final double value;
  final GxPalette palette;
  final ValueChanged<double> onChanged;

  const _PreampSlider({
    required this.value,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      child: Column(children: [
        Text(value.toStringAsFixed(0),
            style: TextStyle(
                fontSize: 9,
                fontFamily: 'monospace',
                color: value == 0
                    ? palette.text.withValues(alpha: 0.4)
                    : palette.accent)),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: const SliderThemeData(
                trackHeight: 2,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 10),
              ),
              child: Slider(
                value: value,
                min: GxEq.minDb,
                max: GxEq.maxDb,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
        Text('PRE',
            style: TextStyle(
                fontSize: 9,
                fontFamily: 'monospace',
                color: palette.text.withValues(alpha: 0.7))),
      ]),
    );
  }
}
