import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();
}

class AppSizes {
  AppSizes._();

  // Padding & Margins
  static const double p4  = 4.0;
  static const double p8  = 8.0;
  static const double p12 = 12.0;
  static const double p14 = 14.0;
  static const double p16 = 16.0;
  static const double p20 = 20.0;
  static const double p24 = 24.0;
  static const double p32 = 32.0;
  static const double p40 = 40.0;
  static const double p48 = 48.0;
  static const double p64 = 64.0;
  static const double p120 = 120.0;

  // Radius (double)
  static const double radiusS = 8.0;
  static const double radiusM = 16.0;
  static const double radiusL = 24.0;
  // Short aliases used in widgets
  static const double r8  = 8.0;
  static const double r12 = 12.0;
  static const double r16 = 16.0;
  static const double r24 = 24.0;

  // Icon Sizes
  static const double iconS  = 16.0;
  static const double iconM  = 24.0;
  static const double iconL  = 32.0;
  static const double iconXL = 48.0;

  // Circular Border Radius (non-const because BorderRadius.circular is not const)
  static BorderRadius get defaultBorderRadius => BorderRadius.circular(radiusM);
}

