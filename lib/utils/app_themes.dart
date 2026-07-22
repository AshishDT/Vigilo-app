import 'package:flutter/material.dart';

import 'constants.dart';

ThemeData darkTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: VigiloUiColors.bg(true),
  colorScheme: ColorScheme.dark(
    primary: VigiloUiColors.blue(true),
    secondary: VigiloUiColors.amber(true),
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
  scaffoldBackgroundColor: VigiloUiColors.bg(false),
  colorScheme: ColorScheme.light(
    primary: VigiloUiColors.blue(false),
    secondary: VigiloUiColors.amber(false),
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
