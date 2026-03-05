import 'package:flutter/material.dart';

abstract class AppTheme {
  static const Color bg1     = Color(0xFF0A1A2F);
  static const Color bg2     = Color(0xFF050B14);
  static const Color primary = Color(0xFF0E5CAD);
  static const Color modalBg = Color(0xFF0D1F35);

  static const BoxDecoration backgroundDecoration = BoxDecoration(
    gradient: LinearGradient(
      begin:  Alignment.topCenter,
      end:    Alignment.bottomCenter,
      colors: [bg1, bg2],
    ),
  );
}
