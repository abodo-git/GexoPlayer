import 'package:flutter_test/flutter_test.dart';
import 'package:gexoplayer/core/equalizer.dart';

void main() {
  test('every preset has 10 bands within range', () {
    for (final entry in GxEq.presets.entries) {
      expect(entry.value.length, GxEq.bandFreqs.length,
          reason: entry.value.toString());
      for (final g in entry.value) {
        expect(g, inInclusiveRange(GxEq.minDb, GxEq.maxDb));
      }
    }
  });

  test('filter is empty when disabled or flat', () {
    final eq = GxEq();
    expect(eq.toMpvFilter(), '');
    eq.enabled = true;
    expect(eq.toMpvFilter(), '');
  });

  test('filter renders only non-zero bands', () {
    final eq = GxEq()
      ..enabled = true
      ..setBand(0, -3.5)
      ..setBand(4, 2);
    expect(eq.toMpvFilter(),
        'equalizer=f=60:t=q:w=1:g=-3.5,equalizer=f=1000:t=q:w=1:g=2.0');
  });

  test('band gains clamp to the Winamp range', () {
    final eq = GxEq()
      ..setBand(0, 99)
      ..setBand(1, -99);
    expect(eq.bands[0], 12.0);
    expect(eq.bands[1], -12.0);
  });

  test('preamp gain: 0 dB is unity, disabled EQ is unity', () {
    final eq = GxEq();
    expect(eq.preampGain, 1.0);
    eq.enabled = true;
    eq.preampDb = 6;
    expect(eq.preampGain, closeTo(2.0, 0.01));
    eq.enabled = false;
    expect(eq.preampGain, 1.0);
  });

  test('applyPreset copies band values', () {
    final eq = GxEq()..applyPreset('Rock');
    expect(eq.bands, GxEq.presets['Rock']);
    eq.applyPreset('No such preset');
    expect(eq.bands, GxEq.presets['Rock']);
  });

  test('json round trip', () {
    final eq = GxEq()
      ..enabled = true
      ..preampDb = -3
      ..setBand(7, 8.5);
    final copy = GxEq()..loadJson(eq.toJson());
    expect(copy.enabled, isTrue);
    expect(copy.preampDb, -3);
    expect(copy.bands, eq.bands);
  });
}
