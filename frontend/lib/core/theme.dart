import 'package:flutter/material.dart';

class AppTheme {
  static const _seed = Color(0xFFE85D04);

  static const _cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
  );

  static const _pillShape = StadiumBorder();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.light,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(shape: _pillShape),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(shape: _pillShape),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(shape: _pillShape),
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: _cardShape,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(shape: _pillShape),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(shape: _pillShape),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(shape: _pillShape),
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: _cardShape,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
        ),
      );

  // Palette of gradients for auth screens
  static const List<List<Color>> tripGradients = [
    [Color(0xFFE85D04), Color(0xFFDC2F02)], // coral → red-orange
    [Color(0xFF0096C7), Color(0xFF0077B6)], // teal → deep teal
    [Color(0xFF6A0572), Color(0xFF9B2226)], // purple → deep red
    [Color(0xFFF4A261), Color(0xFFE76F51)], // sandy → salmon
  ];

  // Solid colors for trip cards — assigned by trip.id % 5
  static const List<Color> tripColors = [
    Color.fromARGB(255, 106, 75, 55), // coral
    Color.fromARGB(255, 85, 139, 156), // teal
    Color.fromARGB(255, 116, 59, 121), // purple
    Color.fromARGB(255, 60, 111, 88), // forest green
    Color.fromARGB(255, 131, 60, 62), // deep red
  ];
}
