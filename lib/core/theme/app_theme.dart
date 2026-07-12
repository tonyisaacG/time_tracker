import 'package:flutter/material.dart';

class AppTheme {
  // Slate dark theme color palette
  static const Color background = Color(0xff0f172a); // Slate 900
  static const Color surface = Color(0xff1e293b);    // Slate 800
  static const Color surfaceHover = Color(0xff334155); // Slate 700
  static const Color border = Color(0xff334155);      // Slate 700
  static const Color primary = Color(0xff8b5cf6);     // Violet 500
  static const Color primaryGlow = Color(0xffa78bfa); // Violet 400
  static const Color textPrimary = Color(0xfff8fafc); // Slate 50
  static const Color textSecondary = Color(0xff94a3b8); // Slate 400
  static const Color textMuted = Color(0xff64748b);     // Slate 500

  // Modern preset activity colors
  static const List<Color> activityColors = [
    Color(0xff8b5cf6), // Violet
    Color(0xff10b981), // Emerald
    Color(0xff06b6d4), // Cyan
    Color(0xfff59e0b), // Amber
    Color(0xffef4444), // Coral Red
    Color(0xffec4899), // Pink
    Color(0xff3b82f6), // Blue
    Color(0xffa855f7), // Purple
  ];

  static const List<String> activityColorNames = [
    'Violet',
    'Emerald',
    'Cyan',
    'Amber',
    'Coral',
    'Pink',
    'Blue',
    'Purple',
  ];

  // Preset activity icons (Material Icon Data mapped to string key for serialization)
  static const Map<String, IconData> activityIcons = {
    'book': Icons.book_rounded,
    'code': Icons.code_rounded,
    'language': Icons.translate_rounded,
    'exercise': Icons.fitness_center_rounded,
    'work': Icons.work_rounded,
    'music': Icons.music_note_rounded,
    'star': Icons.star_rounded,
    'brain': Icons.psychology_rounded,
    'chat': Icons.chat_bubble_rounded,
    'flight': Icons.flight_takeoff_rounded,
    'heart': Icons.favorite_rounded,
    'coffee': Icons.coffee_rounded,
    'reading_deep': Icons.menu_book_rounded,
    'programming_computer': Icons.computer_rounded,
    'drawing_art': Icons.palette_rounded,
    'brush_art': Icons.brush_rounded,
    'courses_study': Icons.school_rounded,
    'sitting_relax': Icons.weekend_rounded,
    'mobile_phone': Icons.phone_android_rounded,
    'gaming': Icons.sports_esports_rounded,
    'tasks_todo': Icons.task_alt_rounded,
    'social_people': Icons.people_rounded,
    'shopping_bag': Icons.shopping_bag_rounded,
    'sleep_relax': Icons.bedtime_rounded,
    'movie_tv': Icons.movie_rounded,
    'home_house': Icons.home_rounded,
  };

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: primaryGlow,
        background: background,
        surface: surface,
        onBackground: textPrimary,
        onSurface: textPrimary,
        error: Color(0xffef4444),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: border, width: 1),
        ),
        titleTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: textPrimary, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        headlineMedium: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
        bodySmall: TextStyle(color: textMuted, fontSize: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffef4444)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryGlow,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: background,
        selectedIconTheme: IconThemeData(color: primaryGlow, size: 28),
        unselectedIconTheme: IconThemeData(color: textSecondary, size: 24),
        selectedLabelTextStyle: TextStyle(color: primaryGlow, fontWeight: FontWeight.bold),
        unselectedLabelTextStyle: TextStyle(color: textSecondary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withOpacity(0.2),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
        ),
      ),
    );
  }
}
