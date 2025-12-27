/// SMARTCARE+ Color Constants
///
/// Dark Futuristic Theme Color Palette
/// Neon accents with glassmorphism support

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ============= Primary Dark Backgrounds =============
  
  /// Deep space black - Main background
  static const Color background = Color(0xFF0A0E17);
  
  /// Card/Surface background
  static const Color surface = Color(0xFF111827);
  
  /// Elevated surface (inputs, hover states)
  static const Color surfaceLight = Color(0xFF1F2937);
  
  /// Even lighter surface for layering
  static const Color surfaceLighter = Color(0xFF374151);

  // ============= Neon Accent Colors =============
  
  /// Primary accent - Cyan neon
  static const Color neonCyan = Color(0xFF00F5FF);
  
  /// Secondary accent - Purple neon
  static const Color neonPurple = Color(0xFFBF00FF);
  
  /// Tertiary accent - Pink neon
  static const Color neonPink = Color(0xFFFF00E5);
  
  /// Success states - Green neon
  static const Color neonGreen = Color(0xFF00FF88);
  
  /// Warning states - Orange neon
  static const Color neonOrange = Color(0xFFFF6B00);
  
  /// Error/Alert states - Red neon
  static const Color neonRed = Color(0xFFFF0055);
  
  /// Info states - Blue neon
  static const Color neonBlue = Color(0xFF0088FF);

  // ============= Text Colors =============
  
  /// Primary white text
  static const Color textPrimary = Color(0xFFFFFFFF);
  
  /// Secondary gray text
  static const Color textSecondary = Color(0xFF9CA3AF);
  
  /// Muted/disabled text
  static const Color textMuted = Color(0xFF6B7280);
  
  /// Hint text
  static const Color textHint = Color(0xFF4B5563);

  // ============= Glassmorphism =============
  
  /// Glass effect - 10% white overlay
  static const Color glassWhite = Color(0x1AFFFFFF);
  
  /// Glass border - 20% white
  static const Color glassBorder = Color(0x33FFFFFF);
  
  /// Glass shadow
  static const Color glassShadow = Color(0x40000000);

  // ============= Service-Specific Colors =============
  
  /// Physio Service accent (matches neonCyan)
  static const Color physioAccent = Color(0xFF00F5FF);
  
  /// Nutrition Service accent (green-ish)
  static const Color nutritionAccent = Color(0xFF00FF88);
  
  /// Guardian Service accent (alert-focused)
  static const Color guardianAccent = Color(0xFFFF6B00);

  // ============= Gradients =============
  
  /// Primary gradient (Cyan to Purple)
  static const List<Color> primaryGradient = [neonCyan, neonPurple];
  
  /// Alert gradient (Red to Orange)
  static const List<Color> alertGradient = [neonRed, neonOrange];
  
  /// Success gradient (Green to Cyan)
  static const List<Color> successGradient = [neonGreen, neonCyan];
  
  /// Info gradient (Blue to Cyan)
  static const List<Color> infoGradient = [neonBlue, neonCyan];
  
  /// Background gradient (Dark space effect)
  static const List<Color> backgroundGradient = [
    Color(0xFF0A0E17),
    Color(0xFF0D1321),
    Color(0xFF111827),
  ];

  // ============= Utility Methods =============
  
  /// Get color with glow effect
  static BoxShadow glowShadow(Color color, {double blur = 20, double spread = 2}) {
    return BoxShadow(
      color: color.withOpacity(0.4),
      blurRadius: blur,
      spreadRadius: spread,
    );
  }
  
  /// Get neon border decoration
  static BoxDecoration neonBorder(Color color, {double radius = 16, double width = 2}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: color, width: width),
      boxShadow: [glowShadow(color)],
    );
  }
}
