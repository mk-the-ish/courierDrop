import "package:flutter/material.dart";

const Color dropCityTransitTeal = Color(0xFF008080);
const Color dropCityActiveMint = Color(0xFF26A69A);
const Color dropCitySafeSlate = Color(0xFF2F4F4F);
const Color dropCityObsidianDeep = Color(0xFF06030C);
const Color dropCityCloudWhite = Color(0xFFF8F9FA);

final ThemeData dropCityLightTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: dropCityCloudWhite,
  primaryColor: dropCityTransitTeal,
  cardColor: Colors.white,
  colorScheme: const ColorScheme.light(
    primary: dropCityTransitTeal,
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
  scaffoldBackgroundColor: dropCityObsidianDeep,
  primaryColor: dropCityTransitTeal,
  cardColor: dropCitySafeSlate,
  colorScheme: const ColorScheme.dark(
    primary: dropCityTransitTeal,
    secondary: dropCityActiveMint,
    surface: dropCitySafeSlate,
    error: Color(0xFFCF6679),
    onPrimary: Colors.white,
    onSurface: dropCityCloudWhite,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: dropCitySafeSlate,
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  useMaterial3: true,
);
