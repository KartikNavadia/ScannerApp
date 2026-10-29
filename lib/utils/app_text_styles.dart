import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale (Geist), sizes/line heights in logical pixels.
class AppTextStyles {
  AppTextStyles._();

  static const headlineSm = TextStyle(
    fontFamily: 'Geist',
    fontSize: 18,
    height: 26 / 18,
    letterSpacing: -0.18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const bodyMd = TextStyle(
    fontFamily: 'Geist',
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const bodySm = TextStyle(
    fontFamily: 'Geist',
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const labelMd = TextStyle(
    fontFamily: 'Geist',
    fontSize: 13,
    height: 16 / 13,
    letterSpacing: -0.13,
    fontWeight: FontWeight.w500,
  );

  static const labelSm = TextStyle(
    fontFamily: 'Geist',
    fontSize: 11,
    height: 14 / 11,
    letterSpacing: 0.22,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
}
