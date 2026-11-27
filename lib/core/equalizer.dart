import 'dart:math';

/// Winamp-style 10-band graphic equalizer state. Pure Dart, unit tested.
class GxEq {
  static const bandFreqs = <double>[
    60, 170, 310, 600, 1000, 3000, 6000, 12000, 14000, 16000
  ];
  static const minDb = -12.0;
  static const maxDb = 12.0;

  /// Classic Winamp presets (dB per band).
  static const presets = <String, List<double>>{
    'Flat': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    'Classical': [0, 0, 0, 0, 0, 0, -4.4, -4.4, -4.4, -5.8],
    'Club': [0, 0, 5, 3.4, 3.4, 3.4, 2, 0, 0, 0],
    'Dance': [5.8, 4.4, 1.6, 0, 0, -3.4, -4.4, -4.4, 0, 0],
    'Full bass': [5.8, 5.8, 5.8, 3.4, 1, -2.6, -4.8, -5.8, -5.8, -5.8],
    'Full bass & treble': [4.4, 3.4, 0, -4.4, -2.6, 1, 5, 6.8, 7.2, 7.2],
    'Full treble': [-5.8, -5.8, -5.8, -2.6, 1.6, 6.6, 9.6, 9.6, 9.6, 10],
    'Laptop / headphones': [2.6, 6.6, 3.4, -2.2, -1.6, 1, 2.8, 5.8, 8.4, 10.2],
    'Large hall': [6.2, 6.2, 3.4, 3.4, 0, -2.8, -2.8, -2.8, 0, 0],
    'Live': [-2.8, 0, 2.4, 3.2, 3.4, 3.4, 2.4, 1.8, 1.8, 1.8],
    'Party': [4.4, 4.4, 0, 0, 0, 0, 0, 0, 4.4, 4.4],
    'Pop': [-1, 2.8, 4.2, 4.6, 3.2, 0, -1.4, -1.4, -1, -1],
    'Reggae': [0, 0, 0, -3.4, 0, -3.8, -3.8, 0, 0, 0],
    'Rock': [4.8, 2.8, -3.4, -4.8, -2, 2.4, 5.4, 6.8, 6.8, 6.8],
    'Ska': [-1.4, -2.8, -2.4, 0, 2.4, 3.4, 5.4, 5.6, 5.8, 5.8],
    'Soft': [2.8, 1.2, 0, -1.4, 0, -2.2, -4.2, -5.8, -6.6, -7.2],
    'Soft rock': [2.4, 2.4, 1.4, 0, -2.4, -3.4, -2, 0, 1.4, 5.2],
    'Techno': [5.4, 4.4, 0, -3.4, -2.8, 0, 5.2, 5.8, 5.8, 5.6],
  };

  bool enabled = false;
  double preampDb = 0;
  final List<double> bands = List.filled(bandFreqs.length, 0.0);

  static double clampDb(double v) => v.clamp(minDb, maxDb).toDouble();

  void setBand(int i, double db) {
    if (i >= 0 && i < bands.length) bands[i] = clampDb(db);
  }

  void applyPreset(String name) {
    final p = presets[name];
    if (p == null) return;
    for (var i = 0; i < bands.length && i < p.length; i++) {
      bands[i] = clampDb(p[i]);
    }
  }

  void zero() {
    for (var i = 0; i < bands.length; i++) {
      bands[i] = 0;
    }
    preampDb = 0;
  }

  void copyFrom(GxEq other) {
    enabled = other.enabled;
    preampDb = other.preampDb;
    for (var i = 0; i < bands.length && i < other.bands.length; i++) {
      bands[i] = other.bands[i];
    }
  }

  /// libmpv `af` filter graph for the current bands, or '' when off/flat.
  String toMpvFilter() {
    if (!enabled) return '';
    final parts = <String>[];
    for (var i = 0; i < bands.length; i++) {
      final g = bands[i];
      if (g == 0) continue;
      parts.add(
          'equalizer=f=${bandFreqs[i].toInt()}:t=q:w=1:g=${g.toStringAsFixed(1)}');
    }
    return parts.join(',');
  }

  /// Volume multiplier for the preamp gain.
  double get preampGain {
    if (!enabled || preampDb == 0) return 1.0;
    return pow(10, preampDb / 20).toDouble().clamp(0.25, 4.0).toDouble();
  }

  Map<String, dynamic> toJson() =>
      {'enabled': enabled, 'preampDb': preampDb, 'bands': bands};

  void loadJson(Map<String, dynamic> j) {
    enabled = j['enabled'] == true;
    final p = j['preampDb'];
    preampDb = p is num ? clampDb(p.toDouble()) : 0;
    final b = j['bands'];
    if (b is List) {
      for (var i = 0; i < bands.length && i < b.length; i++) {
        final v = b[i];
        bands[i] = v is num ? clampDb(v.toDouble()) : 0;
      }
    }
  }
}
