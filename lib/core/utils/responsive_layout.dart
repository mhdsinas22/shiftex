import 'dart:math' as math;

import 'package:flutter/material.dart';

class ResponsiveLayout {
  final Size size;
  final EdgeInsets viewInsets;
  final EdgeInsets viewPadding;

  const ResponsiveLayout({
    required this.size,
    required this.viewInsets,
    required this.viewPadding,
  });

  factory ResponsiveLayout.of(BuildContext context) {
    return ResponsiveLayout(
      size: MediaQuery.sizeOf(context),
      viewInsets: MediaQuery.viewInsetsOf(context),
      viewPadding: MediaQuery.viewPaddingOf(context),
    );
  }

  double get width => size.width;
  double get height => size.height;

  bool get isSmallWidth => width < 360;
  bool get isMediumWidth => width >= 360 && width < 412;
  bool get isLargeWidth => width >= 412;
  bool get isTabletOrWide => width >= 600;

  bool get isShortScreen => height < 680;
  bool get isCompactScreen => height < 750;
  bool get isKeyboardVisible => viewInsets.bottom > 80;

  /// Horizontal padding inside the bottom sheet card.
  double get sheetHorizontalPadding {
    if (width < 340) return 14.0;
    if (width < 375) return 18.0;
    if (width < 430) return 22.0;
    return 24.0;
  }

  /// Max width constraint for forms on wide screens / foldables.
  double get maxContentWidth => isTabletOrWide ? 480.0 : double.infinity;

  /// Adaptive logo badge size in the header.
  double logoSize({double defaultSize = 74.0}) {
    if (isKeyboardVisible) return math.min(defaultSize, 52.0);
    if (isShortScreen) return math.min(defaultSize, 58.0);
    if (isCompactScreen) return math.min(defaultSize, 66.0);
    return defaultSize;
  }

  /// Adaptive heading font size.
  double get titleFontSize {
    if (width < 340 || isShortScreen) return 23.0;
    if (isCompactScreen) return 25.5;
    return 28.0;
  }

  /// Adaptive subtitle font size.
  double get subtitleFontSize {
    if (width < 340) return 12.5;
    if (isCompactScreen) return 13.2;
    return 13.8;
  }

  /// Primary button height.
  double get buttonHeight {
    if (isShortScreen) return 50.0;
    if (isCompactScreen) return 52.0;
    return 56.0;
  }

  /// Numeric keypad button height on OTP screens.
  double get keypadKeyHeight {
    if (height < 670) return 42.0;
    if (height < 750) return 47.0;
    if (height < 840) return 51.0;
    return 54.0;
  }

  /// Numeric keypad row gap.
  double get keypadRowGap {
    if (height < 670) return 6.0;
    if (height < 750) return 8.0;
    return 10.0;
  }

  /// Vertical spacing multiplier for compact viewports.
  double scaleVertical(double base) {
    if (isKeyboardVisible) return base * 0.72;
    if (isShortScreen) return base * 0.78;
    if (isCompactScreen) return base * 0.88;
    return base;
  }
}
