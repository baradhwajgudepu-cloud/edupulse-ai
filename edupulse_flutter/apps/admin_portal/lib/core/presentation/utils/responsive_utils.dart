import 'package:flutter/material.dart';

/// Standard responsive breakpoints for the EduPulse Admin Portal.
class ResponsiveBreakpoints {
  const ResponsiveBreakpoints._();

  /// Mobile compact viewports (< 600px), such as 360x640, 390x844.
  static const double compact = 600.0;

  /// Tablet portrait and narrow laptop viewports (< 960px), such as 768x1024.
  static const double medium = 960.0;

  /// Standard laptop viewports (< 1440px), such as 1280x720, 1366x768.
  static const double expanded = 1440.0;
}

/// Helper methods for determining device class and responsive values.
class Responsive {
  const Responsive._();

  /// True if current screen width is < 600px (Mobile).
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < ResponsiveBreakpoints.compact;
  }

  /// True if current screen width is between 600px and 960px (Tablet).
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= ResponsiveBreakpoints.compact && width < ResponsiveBreakpoints.medium;
  }

  /// True if current screen width is < 960px (Mobile or Tablet).
  static bool isCompactOrMedium(BuildContext context) {
    return MediaQuery.of(context).size.width < ResponsiveBreakpoints.medium;
  }

  /// True if current screen width is >= 960px (Laptop / Desktop).
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= ResponsiveBreakpoints.medium;
  }

  /// True if current screen width is >= 1440px (Full HD / Large Desktop).
  static bool isLargeDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= ResponsiveBreakpoints.expanded;
  }

  /// Returns a responsive value based on the current screen width.
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return desktop;
  }

  /// Computes a safe width for dialogs that fits within the current screen.
  static double dialogWidth(BuildContext context, {double maxWidth = 600.0}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final targetWidth = screenWidth * 0.94;
    return targetWidth < maxWidth ? targetWidth : maxWidth;
  }
}
