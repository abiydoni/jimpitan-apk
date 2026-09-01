import 'package:flutter/material.dart';

class AppTheme {
  static final ValueNotifier<Color> primaryColorNotifier = ValueNotifier<Color>(const Color(0xFF1E3A8A)); // Default: Biru Dongker (Biru Tua)

  static Color get primaryColor => primaryColorNotifier.value;
  static Color get secondaryColor => _darken(primaryColor, 0.2);
  static Color get lightColor => primaryColor.withValues(alpha: 0.1);

  // Available Themes (Warna Tua/Gelap)
  static const List<Map<String, dynamic>> availableThemes = [
    {'name': 'Coklat Kopi', 'color': Color(0xFF6F4E37)},
    {'name': 'Biru Dongker', 'color': Color(0xFF1E3A8A)},
    {'name': 'Hijau Hutan', 'color': Color(0xFF166534)},
    {'name': 'Merah Marun', 'color': Color(0xFF7F1D1D)},
    {'name': 'Abu Tua', 'color': Color(0xFF374151)},
    {'name': 'Teal Gelap', 'color': Color(0xFF0F766E)},
    {'name': 'Ungu Tua', 'color': Color(0xFF4C1D95)},
    {'name': 'Biru Malam', 'color': Color(0xFF0F172A)},
    {'name': 'Merah Bata', 'color': Color(0xFF9A3412)},
    {'name': 'Hijau Zaitun', 'color': Color(0xFF3F6212)},
    {'name': 'Coklat Tanah', 'color': Color(0xFF451A03)},
    {'name': 'Hitam Arang', 'color': Color(0xFF18181B)},
    {'name': 'Abu Kebiruan', 'color': Color(0xFF334155)},
    {'name': 'Merah Anggur', 'color': Color(0xFF581C87)},
    {'name': 'Tembaga Tua', 'color': Color(0xFF713F12)},
  ];

  static void changeTheme(Color color) {
    primaryColorNotifier.value = color;
  }

  static Color _darken(Color color, [double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
