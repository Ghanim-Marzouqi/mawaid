import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const primary = Color(0xFF1B5E7B);
  static const primaryVariant = Color(0xFF0D3B4F);

  // Dynamic type palette (8 colors)
  static const List<Color> typePalette = [
    Color(0xFF8B1A2B), // deep red
    Color(0xFF1A7F6D), // teal
    Color(0xFFC27A1A), // amber
    Color(0xFF5C6BC0), // indigo
    Color(0xFF00838F), // cyan
    Color(0xFF6A1B9A), // purple
    Color(0xFF2E7D32), // green
    Color(0xFFD84315), // deep orange
  ];

  static Color typeColor(int index) =>
      typePalette[index % typePalette.length];

  // Status colors
  static const confirmed = Color(0xFF2E7D32);
  static const rejected = Color(0xFFC62828);
  static const pending = Color(0xFFF57F17);
  static const suggested = Color(0xFF5C6BC0);
  static const cancelled = Color(0xFF757575);
  static const draft = Color(0xFF607D8B); // blue-grey

  // Surfaces
  static const background = Color(0xFFF5F5F0);
  static const surface = Color(0xFFFFFFFF);
  static const onSurface = Color(0xFF1C1B1F);
  static const onSurfaceVariant = Color(0xFF49454F);

  // Error
  static const error = Color(0xFFB3261E);
}
