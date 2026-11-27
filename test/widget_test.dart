import 'package:flutter_test/flutter_test.dart';
import 'package:gexoplayer/core/track.dart';

void main() {
  test('track title comes from file name', () {
    expect(GxTrack.fromPath('/a/b/My Song.mp3').title, 'My Song');
  });
}
