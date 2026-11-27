import 'package:flutter/material.dart';

/// Hand-tuned palettes: the modern Material look and the classic
/// Winamp look (green-on-black playlist, LCD-style readouts).
class GxPalette {
  final String name;
  final Color windowBg;
  final Color panelBg;
  final Color border;
  final Color text;
  final Color accent;
  final Color playlistBg;
  final Color playlistText;
  final Color playlistSelectedBg;
  final Color playlistSelectedText;
  final Color lcdBg;
  final Color lcdText;

  const GxPalette({
    required this.name,
    required this.windowBg,
    required this.panelBg,
    required this.border,
    required this.text,
    required this.accent,
    required this.playlistBg,
    required this.playlistText,
    required this.playlistSelectedBg,
    required this.playlistSelectedText,
    required this.lcdBg,
    required this.lcdText,
  });

  ThemeData material() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: windowBg,
        colorScheme: ColorScheme.dark(
          primary: accent,
          secondary: accent,
          surface: panelBg,
        ),
        iconTheme: IconThemeData(color: text),
        sliderTheme: const SliderThemeData(
          trackHeight: 2,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: panelBg,
          contentTextStyle: TextStyle(color: text),
        ),
      );
}

const classicPalette = GxPalette(
  name: 'Classic',
  windowBg: Color(0xFF141414),
  panelBg: Color(0xFF202020),
  border: Color(0xFF3A3A3A),
  text: Color(0xFFE8E8E8),
  accent: Color(0xFF00E060),
  playlistBg: Color(0xFF000000),
  playlistText: Color(0xFF00E060),
  playlistSelectedBg: Color(0xFF0A2E14),
  playlistSelectedText: Color(0xFFFFFFFF),
  lcdBg: Color(0xFF000000),
  lcdText: Color(0xFF00FF66),
);

const modernPalette = GxPalette(
  name: 'Modern',
  windowBg: Color(0xFF191022),
  panelBg: Color(0xFF241833),
  border: Color(0xFF3A2C4D),
  text: Color(0xFFF2ECFA),
  accent: Color(0xFF7C4DFF),
  playlistBg: Color(0xFF141018),
  playlistText: Color(0xFFE6DEF2),
  playlistSelectedBg: Color(0xFF3A2C5A),
  playlistSelectedText: Color(0xFFFFFFFF),
  lcdBg: Color(0xFF0D0A12),
  lcdText: Color(0xFFB79CFF),
);

/// Monospace LCD-style text used for time readouts.
TextStyle lcdStyle(GxPalette p, {double size = 15}) => TextStyle(
      fontFamily: 'monospace',
      fontSize: size,
      letterSpacing: 1.5,
      color: p.lcdText,
    );
