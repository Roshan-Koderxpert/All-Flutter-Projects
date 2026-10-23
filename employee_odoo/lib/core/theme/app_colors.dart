import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand palette
  static const Color brandBlue = Color(0xFF1F5786);
  static const Color brandOrange = Color(0xFFF06022);
  static const Color brandBlueLight = Color(0xFF2D6FA3);
  static const Color brandOrangeLight = Color(0xFFF07842);

  static const Color primary = brandBlue;
  static const Color primaryDark = Color(0xFF184A72);
  static const Color accent = brandOrange;
  static const Color accentLight = Color(0xFFFFF3ED);
  static const Color authbuttoncolor = Color(0xFF6B3E60);

  static const Color white = Colors.white;
  static const Color black = Color(0xFF1A1A1A);
  /// App-wide screen / scaffold background.
  static const Color background = Colors.white;
  static const Color surface = Colors.white;
  /// Subtle fill for inputs on white screens (not page background).
  static const Color inputFill = Color(0xFFF8F9FB);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color border = Color(0xFFE8EDF3);
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFFEBEE);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandBlue, brandOrange],
  );

  static const LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandBlue, brandBlueLight],
  );

  static const LinearGradient orangeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandOrange, brandOrangeLight],
  );
}
