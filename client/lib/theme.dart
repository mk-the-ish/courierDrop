import "package:flutter/material.dart";

// Shared DropCity palette
const Color dropCityOrangeAccent = Color(0xFF008080);
const Color dropCityOrangeLight = Color(0xFF26A69A);
const Color dropCityDarkGradientStart = Color(0xFF1A1A2E);
const Color dropCityDarkGradientEnd = Color(0xFF16213E);
const Color dropCityTransitTeal = Color(0xFF008080);
const Color dropCityActiveMint = Color(0xFF26A69A);
const Color dropCitySafeSlate = Color(0xFF2F4F4F);
const Color dropCityAlertAmber = Color(0xFFFFBF00);
const Color dropCitySlateGrey = Color(0xFF94A3B8);
const Color dropCityObsidianDeep = Color(0xFF06030C);
const Color dropCityCloudWhite = Color(0xFFF8F9FA);
const Color dropCityTextLight = Color(0xFFFFFFFF);
const Color dropCityTextDark = Color(0xFF0F172A);
const Color dropCityTextGrey = dropCitySlateGrey;
const Color dropCityBorderDark = Color(0xFF4B5563);
const Color dropCityErrorRed = Color(0xFFEF5350);
const Color dropCitySuccessGreen = Color(0xFF4CAF50);
const double dropCityBorderRadius = 12.0;
const Color dropCityInputBackground = Color(0xFF2A2A3E);
const Color dropCityInputBorder = Color(0xFF404050);

InputDecorationTheme _inputDecorationTheme({required bool dark}) {
  final labelColor = dark ? dropCityTextGrey : dropCitySafeSlate;
  final hintColor = dark ? dropCityTextGrey : dropCityBorderDark;

  return InputDecorationTheme(
    filled: true,
    fillColor: dark ? dropCityInputBackground : Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(dropCityBorderRadius),
      borderSide: const BorderSide(color: dropCityInputBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(dropCityBorderRadius),
      borderSide: BorderSide(color: dark ? dropCityInputBorder : dropCityBorderDark.withOpacity(0.25)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(dropCityBorderRadius),
      borderSide: const BorderSide(color: dropCityTransitTeal, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(dropCityBorderRadius),
      borderSide: const BorderSide(color: dropCityErrorRed, width: 2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(dropCityBorderRadius),
      borderSide: const BorderSide(color: dropCityErrorRed, width: 2),
    ),
    labelStyle: TextStyle(color: labelColor),
    hintStyle: TextStyle(color: hintColor),
    errorStyle: const TextStyle(color: dropCityErrorRed),
    prefixIconColor: MaterialStateColor.resolveWith(
      (states) => states.contains(MaterialState.focused) ? dropCityTransitTeal : labelColor,
    ),
    suffixIconColor: MaterialStateColor.resolveWith(
      (states) => states.contains(MaterialState.focused) ? dropCityTransitTeal : hintColor,
    ),
    helperStyle: TextStyle(color: hintColor),
    floatingLabelStyle: const TextStyle(color: dropCityTransitTeal),
  );
}

TextTheme _textTheme({required bool dark}) {
  final primaryText = dark ? dropCityTextLight : dropCityTextDark;
  final secondaryText = dark ? dropCityTextGrey : dropCitySafeSlate;

  return TextTheme(
    displayLarge: TextStyle(color: primaryText, fontWeight: FontWeight.bold),
    displayMedium: TextStyle(color: primaryText, fontWeight: FontWeight.bold),
    displaySmall: TextStyle(color: primaryText, fontWeight: FontWeight.bold),
    headlineLarge: TextStyle(color: primaryText, fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(color: primaryText, fontWeight: FontWeight.bold),
    headlineSmall: TextStyle(color: primaryText, fontWeight: FontWeight.bold),
    titleLarge: TextStyle(color: primaryText, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(color: primaryText, fontWeight: FontWeight.w600),
    titleSmall: TextStyle(color: primaryText, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(color: primaryText, fontWeight: FontWeight.w500),
    bodyMedium: TextStyle(color: primaryText),
    bodySmall: TextStyle(color: secondaryText),
    labelLarge: TextStyle(color: primaryText),
    labelMedium: TextStyle(color: secondaryText),
    labelSmall: TextStyle(color: secondaryText),
  );
}

final ThemeData dropCityLightTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: dropCityCloudWhite,
  primaryColor: dropCityTransitTeal,
  cardColor: Colors.white,
  colorScheme: const ColorScheme.light(
    primary: dropCityTransitTeal,
    secondary: dropCityActiveMint,
    surface: Colors.white,
    error: dropCityErrorRed,
    onPrimary: Colors.white,
    onSurface: dropCityTextDark,
    onSecondary: Colors.white,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: dropCityCloudWhite,
    foregroundColor: dropCitySafeSlate,
    elevation: 0,
  ),
  inputDecorationTheme: _inputDecorationTheme(dark: false),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: dropCityTransitTeal,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(dropCityBorderRadius),
      ),
      elevation: 4,
      shadowColor: dropCityTransitTeal.withOpacity(0.25),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: dropCityTextDark,
      side: const BorderSide(color: dropCityBorderDark),
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(dropCityBorderRadius),
      ),
    ),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Colors.white,
    selectedItemColor: dropCityTransitTeal,
    unselectedItemColor: dropCityTextGrey,
  ),
  textTheme: _textTheme(dark: false),
  useMaterial3: true,
);

final ThemeData dropCityDarkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: dropCityDarkGradientStart,
  primaryColor: dropCityTransitTeal,
  cardColor: dropCityDarkGradientEnd,
  colorScheme: const ColorScheme.dark(
    primary: dropCityTransitTeal,
    secondary: dropCityActiveMint,
    surface: dropCityDarkGradientEnd,
    error: dropCityErrorRed,
    onPrimary: Colors.white,
    onSurface: dropCityCloudWhite,
    onSecondary: Colors.white,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  inputDecorationTheme: _inputDecorationTheme(dark: true),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: dropCityTransitTeal,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(dropCityBorderRadius),
      ),
      elevation: 8,
      shadowColor: dropCityTransitTeal.withOpacity(0.4),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: dropCityTransitTeal, width: 2),
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(dropCityBorderRadius),
      ),
    ),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: dropCityObsidianDeep,
    selectedItemColor: dropCityTransitTeal,
    unselectedItemColor: dropCityTextGrey,
  ),
  textTheme: _textTheme(dark: true),
  useMaterial3: true,
);
