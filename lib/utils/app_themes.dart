import 'package:flutter/material.dart';

import 'constants.dart';

ThemeData darkTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kDarkBg,
  colorScheme: ColorScheme.dark(
    primary: kBlue,
    secondary: kAmber,
    surface: VigiloUiColors.panel(true),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    titleTextStyle: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: Colors.white,
    ),
    iconTheme: IconThemeData(color: Colors.white),
  ),
  cardTheme: CardThemeData(
    color: VigiloUiColors.panel(true),
    elevation: 0,
    margin: EdgeInsets.zero,
  ),
  dividerColor: Colors.white12,
);

ThemeData lightTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: kLightBg,
  colorScheme: const ColorScheme.light(
    primary: kBlue,
    secondary: kAmber,
    surface: Colors.white,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    titleTextStyle: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: Color(0xFF0B253A),
    ),
  ),
  cardTheme: const CardThemeData(
    color: Colors.white,
    elevation: 0,
    margin: EdgeInsets.zero,
  ),
  dividerColor: Color(0xFFE6ECF3),
);
