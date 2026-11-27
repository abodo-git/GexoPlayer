import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'ui/player_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const GexoPlayerApp());
}

class GexoPlayerApp extends StatelessWidget {
  const GexoPlayerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'GexoPlayer',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: const PlayerPage(),
      );
}
