import 'package:flutter/material.dart';

/// RoadAid Modern Color Theme
/// Simple, clean, and professional color scheme replacing all red colors
class RoadAidColors {
  // Primary brand colors - Clean blues and grays
  static const Color primary = Color(0xFF2E86AB);        // Professional blue
  static const Color primaryLight = Color(0xFF5BA3D1);   // Light blue
  static const Color primaryDark = Color(0xFF1E5A78);    // Dark blue
  
  // Secondary colors - Complementary greens and grays
  static const Color secondary = Color(0xFF4CAF50);      // Green for success
  static const Color secondaryLight = Color(0xFF81C784); // Light green
  static const Color secondaryDark = Color(0xFF388E3C);  // Dark green
  
  // Neutral colors - Modern grays
  static const Color surface = Color(0xFFF8F9FA);        // Light gray background
  static const Color background = Color(0xFFFFFFFF);     // White
  static const Color cardBackground = Color(0xFFF5F5F7); // Card background
  
  // Text colors - Professional grays
  static const Color textPrimary = Color(0xFF212529);    // Dark gray text
  static const Color textSecondary = Color(0xFF6C757D);  // Medium gray text
  static const Color textLight = Color(0xFF9E9E9E);      // Light gray text
  
  // Action colors - Simple and clean
  static const Color accept = Color(0xFF4CAF50);         // Green for accept
  static const Color reject = Color(0xFF9E9E9E);         // Gray for reject (instead of red)
  static const Color warning = Color(0xFFFF9800);        // Orange for warnings
  static const Color info = Color(0xFF2196F3);           // Blue for info
  
  // Status colors - Professional palette
  static const Color online = Color(0xFF4CAF50);         // Green for online
  static const Color offline = Color(0xFF9E9E9E);        // Gray for offline
  static const Color busy = Color(0xFFFF9800);           // Orange for busy
  static const Color available = Color(0xFF4CAF50);      // Green for available
  
  // Button colors - Clean and modern
  static const Color buttonPrimary = Color(0xFF2E86AB);  // Primary blue
  static const Color buttonSecondary = Color(0xFF6C757D); // Gray
  static const Color buttonSuccess = Color(0xFF4CAF50);  // Green
  static const Color buttonWarning = Color(0xFFFF9800);  // Orange
  static const Color buttonDanger = Color(0xFF9E9E9E);   // Gray (instead of red)
  
  // Border and divider colors
  static const Color border = Color(0xFFE0E0E0);         // Light gray border
  static const Color divider = Color(0xFFEEEEEE);        // Very light gray
  
  // Special colors
  static const Color emergency = Color(0xFFFF9800);      // Orange for emergency (instead of red)
  static const Color towing = Color(0xFF9E9E9E);         // Gray for towing (instead of red)
  static const Color delete = Color(0xFF9E9E9E);         // Gray for delete (instead of red)
  
  // Gradient colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient successGradient = LinearGradient(
    colors: [secondary, secondaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Material color swatches for compatibility
  static const MaterialColor primarySwatch = MaterialColor(
    0xFF2E86AB,
    <int, Color>{
      50: Color(0xFFE3F2FD),
      100: Color(0xFFBBDEFB),
      200: Color(0xFF90CAF9),
      300: Color(0xFF64B5F6),
      400: Color(0xFF42A5F5),
      500: Color(0xFF2E86AB),
      600: Color(0xFF1E88E5),
      700: Color(0xFF1976D2),
      800: Color(0xFF1565C0),
      900: Color(0xFF0D47A1),
    },
  );
  
  static const MaterialColor graySwatch = MaterialColor(
    0xFF9E9E9E,
    <int, Color>{
      50: Color(0xFFFAFAFA),
      100: Color(0xFFF5F5F5),
      200: Color(0xFFEEEEEE),
      300: Color(0xFFE0E0E0),
      400: Color(0xFFBDBDBD),
      500: Color(0xFF9E9E9E),
      600: Color(0xFF757575),
      700: Color(0xFF616161),
      800: Color(0xFF424242),
      900: Color(0xFF212121),
    },
  );
}

/// Theme Data for RoadAid App
class RoadAidTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primarySwatch: RoadAidColors.primarySwatch,
      primaryColor: RoadAidColors.primary,
      scaffoldBackgroundColor: RoadAidColors.surface,
      cardColor: RoadAidColors.cardBackground,
      
      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: RoadAidColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      
      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RoadAidColors.buttonPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
      ),
      
      // Card theme
      cardTheme: CardTheme(
        color: RoadAidColors.cardBackground,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      // Text theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: RoadAidColors.textPrimary),
        displayMedium: TextStyle(color: RoadAidColors.textPrimary),
        displaySmall: TextStyle(color: RoadAidColors.textPrimary),
        headlineLarge: TextStyle(color: RoadAidColors.textPrimary),
        headlineMedium: TextStyle(color: RoadAidColors.textPrimary),
        headlineSmall: TextStyle(color: RoadAidColors.textPrimary),
        titleLarge: TextStyle(color: RoadAidColors.textPrimary),
        titleMedium: TextStyle(color: RoadAidColors.textPrimary),
        titleSmall: TextStyle(color: RoadAidColors.textSecondary),
        bodyLarge: TextStyle(color: RoadAidColors.textPrimary),
        bodyMedium: TextStyle(color: RoadAidColors.textSecondary),
        bodySmall: TextStyle(color: RoadAidColors.textLight),
      ),
      
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: RoadAidColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: RoadAidColors.primary, width: 2),
        ),
      ),
      
      // Divider theme
      dividerTheme: const DividerThemeData(
        color: RoadAidColors.divider,
        thickness: 1,
      ),
      
      colorScheme: const ColorScheme.light(
        primary: RoadAidColors.primary,
        primaryContainer: RoadAidColors.primaryLight,
        secondary: RoadAidColors.secondary,
        secondaryContainer: RoadAidColors.secondaryLight,
        surface: RoadAidColors.surface,
        error: RoadAidColors.warning, // Use orange instead of red for errors
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: RoadAidColors.textPrimary,
        onError: Colors.white,
      ),
    );
  }
}










