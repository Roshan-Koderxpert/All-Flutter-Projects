import 'package:flutter/cupertino.dart';
import 'dart:math' as math;

class DeviceSize {
  // Mobile-focused breakpoints (logical pixels)
  static const double tabletBreakpoint = 600.0; // Common tablet boundary
  static const double largePhoneBreakpoint = 414.0; // iPhone Plus/Max, larger Androids
  static const double mediumPhoneBreakpoint = 375.0; // Standard iPhone, common Androids
  static const double smallPhoneBreakpoint = 320.0; // Older or smaller phones

  // Scale factors for mobile
  static const double tabletScale = 1.2;
  static const double largePhoneScale = 1.1;
  static const double mediumPhoneScale = 1.0;
  static const double smallPhoneScale = 0.9;

  /// Get scaled size based on width for mobile
  static double getSizeByWidth(BuildContext context, double baseSize) {
    double deviceWidth = MediaQuery.of(context).size.width;
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    double scaleFactor = deviceWidth >= tabletBreakpoint
        ? tabletScale
        : deviceWidth >= largePhoneBreakpoint
        ? largePhoneScale
        : deviceWidth >= mediumPhoneBreakpoint
        ? mediumPhoneScale
        : smallPhoneScale;

    // Adjust scale based on relative size, but keep it within reasonable bounds.
    scaleFactor *= (deviceWidth / mediumPhoneBreakpoint); // Normalize to medium phone
    scaleFactor = scaleFactor.clamp(0.8, 1.4); // More reasonable mobile range

    // Adjust for pixel density, but ensure a minimum size.
    return math.max((baseSize * scaleFactor) / (pixelRatio > 2 ? pixelRatio * 0.7 : 1), 8.0);
  }

  /// Get scaled size based on height for mobile
  static double getSizeByHeight(BuildContext context, double baseSize) {
    double deviceHeight = MediaQuery.of(context).size.height;
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    double scaleFactor = deviceHeight >= tabletBreakpoint
        ? tabletScale
        : deviceHeight >= largePhoneBreakpoint
        ? largePhoneScale
        : deviceHeight >= mediumPhoneBreakpoint
        ? mediumPhoneScale
        : smallPhoneScale;

    scaleFactor *= (deviceHeight / 667); // Normalize to standard Iphone height
    scaleFactor = scaleFactor.clamp(0.8, 1.4);

    return math.max((baseSize * scaleFactor) / (pixelRatio > 2 ? pixelRatio * 0.7 : 1), 8.0);
  }
}