import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color darkBlue = Color(0xFF1A2B4C);
  static const Color siam = Color(0xFF00A8B5);
  static const Color gold = Color(0xFFFFD700);
  static const Color grey = Color(0xFF808080);
  static const Color red = Color(0xFFE53935);
  static const Color green = Color(0xFF4CAF50);

  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF4F6FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE1E6EF);
  static const Color textPrimary = Color(0xFF1A2B4C);
  static const Color textSecondary = Color(0xFF5B6B85);
  static const Color darkBlueSoft = Color(0xFF2C4270);
  static const Color siamSoft = Color(0xFFE0F5F7);
  static const Color goldSoft = Color(0xFFFFF8DC);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [darkBlue, Color(0xFF223A66), siam],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [gold, Color(0xFFFFC400)],
  );
}
