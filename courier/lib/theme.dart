import "package:flutter/material.dart";

// Primary Brand Colors
const Color dropCityOrangeAccent = Color(0xFFFF6B35);
const Color dropCityOrangeLight = Color(0xFFFFA500);
const Color dropCityDarkGradientStart = Color(0xFF1a1a2e);
const Color dropCityDarkGradientEnd = Color(0xFF16213e);

// Secondary Colors (kept for compatibility)
const Color dropCityTransitTeal = Color(0xFF008080);
const Color dropCityActiveMint = Color(0xFF26A69A);
const Color dropCitySafeSlate = Color(0xFF2F4F4F);
const Color dropCityObsidianDeep = Color(0xFF06030C);
const Color dropCityCloudWhite = Color(0xFFF8F9FA);

// Neutral Colors
const Color dropCityTextLight = Color(0xFFFFFFFF);
const Color dropCityTextGrey = Color(0xFF9CA3AF);
const Color dropCityBorderDark = Color(0xFF4B5563);
const Color dropCityErrorRed = Color(0xFFEF5350);
const Color dropCitySuccessGreen = Color(0xFF4CAF50);

// Input Field Styling
const double dropCityBorderRadius = 12.0;
const Color dropCityInputBackground = Color(0xFF2A2A3E);
const Color dropCityInputBorder = Color(0xFF404050);

final ThemeData dropCityLightTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: dropCityCloudWhite,
  primaryColor: dropCityOrangeAccent,
  cardColor: Colors.white,
  colorScheme: const ColorScheme.light(
    primary: dropCityOrangeAccent,
    secondary: dropCityActiveMint,
    surface: Color(0xFFFFFFFF),
    error: Color(0xFFB3261E),
    onPrimary: Colors.white,
    onSurface: dropCitySafeSlate,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: dropCitySafeSlate,
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  useMaterial3: true,
);

final ThemeData dropCityDarkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: dropCityDarkGradientStart,
  primaryColor: dropCityOrangeAccent,
  cardColor: dropCitySafeSlate,
  colorScheme: const ColorScheme.dark(
    primary: dropCityOrangeAccent,
    secondary: dropCityOrangeLight,
    surface: dropCityDarkGradientEnd,
    error: dropCityErrorRed,
    onPrimary: Colors.white,
    onSurface: dropCityCloudWhite,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: dropCityInputBackground,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(dropCityBorderRadius),
      borderSide: const BorderSide(color: dropCityInputBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(dropCityBorderRadius),
      borderSide: const BorderSide(color: dropCityInputBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(dropCityBorderRadius),
      borderSide: const BorderSide(
        color: dropCityOrangeAccent,
        width: 2,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(dropCityBorderRadius),
      borderSide: const BorderSide(
        color: dropCityErrorRed,
        width: 2,
      ),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(dropCityBorderRadius),
      borderSide: const BorderSide(
        color: dropCityErrorRed,
        width: 2,
      ),
    ),
    labelStyle: const TextStyle(color: dropCityTextGrey),
    hintStyle: TextStyle(color: Colors.grey[600]),
    errorStyle: const TextStyle(color: dropCityErrorRed),
    prefixIconColor: MaterialStateColor.resolveWith((states) =>
        states.contains(MaterialState.focused)
            ? dropCityOrangeAccent
            : dropCityTextGrey),
    suffixIconColor: MaterialStateColor.resolveWith((states) =>
        states.contains(MaterialState.focused)
            ? dropCityOrangeAccent
            : Colors.grey[600] ?? Colors.grey),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: dropCityOrangeAccent,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(dropCityBorderRadius),
      ),
      elevation: 8,
      shadowColor: dropCityOrangeAccent.withOpacity(0.4),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(
        color: dropCityOrangeAccent,
        width: 2,
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(dropCityBorderRadius),
      ),
    ),
  ),
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      color: dropCityTextLight,
      fontWeight: FontWeight.bold,
    ),
    displayMedium: TextStyle(
      color: dropCityTextLight,
      fontWeight: FontWeight.bold,
    ),
    displaySmall: TextStyle(
      color: dropCityTextLight,
      fontWeight: FontWeight.bold,
    ),
    headlineLarge: TextStyle(
      color: dropCityTextLight,
      fontWeight: FontWeight.bold,
    ),
    headlineMedium: TextStyle(
      color: dropCityTextLight,
      fontWeight: FontWeight.bold,
    ),
    headlineSmall: TextStyle(
      color: dropCityTextLight,
      fontWeight: FontWeight.bold,
    ),
    bodyLarge: TextStyle(
      color: dropCityTextLight,
      fontWeight: FontWeight.w500,
    ),
    bodyMedium: TextStyle(
      color: dropCityTextLight,
    ),
    bodySmall: TextStyle(
      color: dropCityTextGrey,
    ),
  ),
  useMaterial3: true,
);
