import 'package:flutter/cupertino.dart';

class AppPalette {
  const AppPalette._();

  static const Color brand = Color(0xFF168A98);
  static const Color brandDark = Color(0xFF0B5C66);
  static const Color brandLight = Color(0xFFE5F7F8);
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundCool = Color(0xFFF6F8F9);
  static const Color surface = CupertinoColors.white;
  static const Color surfaceWarm = Color(0xFFF3F5F6);
  static const Color border = Color(0xFFE1E5E7);
  static const Color mutedText = Color(0xFF737A7E);
  static const Color strongText = Color(0xFF14191B);
  static const Color warmAccent = Color(0xFFE85267);
  static const Color yellow = Color(0xFFFFCF5A);
  static const Color mint = Color(0xFFD4F0F2);
  static const Color success = Color(0xFF159A68);
  static const Color ink = Color(0xFF20282B);
}

CupertinoThemeData buildAppTheme() {
  return const CupertinoThemeData(
    primaryColor: AppPalette.brand,
    primaryContrastingColor: CupertinoColors.white,
    scaffoldBackgroundColor: AppPalette.background,
    barBackgroundColor: AppPalette.surface,
    textTheme: CupertinoTextThemeData(
      textStyle: TextStyle(
        color: AppPalette.strongText,
        fontSize: 16,
        height: 1.4,
      ),
      navTitleTextStyle: TextStyle(
        color: AppPalette.strongText,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      navLargeTitleTextStyle: TextStyle(
        color: AppPalette.strongText,
        fontSize: 30,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
