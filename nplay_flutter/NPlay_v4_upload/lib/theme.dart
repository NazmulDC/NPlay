import 'package:flutter/material.dart';

class C {
  static const bg = Color(0xFF070C1B);
  static const bg2 = Color(0xFF0E1630);
  static const card = Color(0xFF14214A);
  static const blue = Color(0xFF2C7BFF);
  static const blue2 = Color(0xFF4D9BFF);
  static const mut = Color(0xFF8D9CC4);
  static const deep = Color(0xFF0A2A6B);
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Poppins',
    scaffoldBackgroundColor: C.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: C.blue,
      brightness: Brightness.dark,
    ).copyWith(primary: C.blue2),
    sliderTheme: const SliderThemeData(
      activeTrackColor: C.blue,
      thumbColor: C.blue2,
      inactiveTrackColor: Color(0x55FFFFFF),
      trackHeight: 3,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: C.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
