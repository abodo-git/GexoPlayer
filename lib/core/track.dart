import 'package:path/path.dart' as p;

class GxTrack {
  final String path;
  final String title;
  const GxTrack(this.path, this.title);

  factory GxTrack.fromPath(String path) =>
      GxTrack(path, p.basenameWithoutExtension(path));
}
