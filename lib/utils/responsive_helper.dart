import 'package:flutter/material.dart';

/// Comprehensive responsive design helper for RoadAid
/// Supports mobile, tablet, and desktop layouts
class ResponsiveHelper {
  // ============================================
  // Screen Size Detection
  // ============================================
  
  static double screenWidth(BuildContext context) => MediaQuery.of(context).size.width;
  static double screenHeight(BuildContext context) => MediaQuery.of(context).size.height;
  
  // Device type detection (Material Design breakpoints)
  static bool isMobile(BuildContext context) => screenWidth(context) < 600;
  static bool isTablet(BuildContext context) => screenWidth(context) >= 600 && screenWidth(context) < 1200;
  static bool isDesktop(BuildContext context) => screenWidth(context) >= 1200;
  
  // Orientation detection
  static bool isPortrait(BuildContext context) => MediaQuery.of(context).orientation == Orientation.portrait;
  static bool isLandscape(BuildContext context) => MediaQuery.of(context).orientation == Orientation.landscape;
  
  // ============================================
  // Responsive Values
  // ============================================
  
  /// Get responsive value based on device type
  static double responsiveValue(BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    if (isDesktop(context) && desktop != null) return desktop;
    if (isTablet(context) && tablet != null) return tablet;
    return mobile;
  }
  
  /// Get responsive value with orientation support
  static T responsiveValueWithOrientation<T>(
    BuildContext context, {
    required T mobilePortrait,
    T? mobileLandscape,
    T? tabletPortrait,
    T? tabletLandscape,
    T? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? mobilePortrait;
    if (isTablet(context)) {
      return isPortrait(context)
          ? (tabletPortrait ?? mobilePortrait)
          : (tabletLandscape ?? tabletPortrait ?? mobilePortrait);
    }
    return isPortrait(context)
        ? mobilePortrait
        : (mobileLandscape ?? mobilePortrait);
  }
  
  // ============================================
  // Padding & Margins
  // ============================================
  
  /// Responsive padding (all sides)
  static EdgeInsets responsivePadding(BuildContext context, {
    double mobile = 16.0,
    double? tablet,
    double? desktop,
  }) {
    final value = responsiveValue(
      context,
      mobile: mobile,
      tablet: tablet ?? mobile * 1.5,
      desktop: desktop ?? mobile * 2,
    );
    return EdgeInsets.all(value);
  }
  
  /// Responsive horizontal padding
  static EdgeInsets responsiveHorizontalPadding(BuildContext context, {
    double mobile = 16.0,
    double? tablet,
    double? desktop,
  }) {
    final value = responsiveValue(
      context,
      mobile: mobile,
      tablet: tablet ?? mobile * 1.5,
      desktop: desktop ?? mobile * 2,
    );
    return EdgeInsets.symmetric(horizontal: value);
  }
  
  /// Responsive vertical padding
  static EdgeInsets responsiveVerticalPadding(BuildContext context, {
    double mobile = 16.0,
    double? tablet,
    double? desktop,
  }) {
    final value = responsiveValue(
      context,
      mobile: mobile,
      tablet: tablet ?? mobile * 1.5,
      desktop: desktop ?? mobile * 2,
    );
    return EdgeInsets.symmetric(vertical: value);
  }
  
  // ============================================
  // Typography
  // ============================================
  
  /// Responsive font size with scaling
  static double responsiveFontSize(BuildContext context, {
    required double baseFontSize,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = screenWidth / 375; // 375 is iPhone 8 width (baseline)
    return baseFontSize * scaleFactor.clamp(0.8, 1.3);
  }
  
  /// Get specific font sizes for different text styles
  static double headlineFontSize(BuildContext context) {
    return responsiveValue(context, mobile: 24, tablet: 28, desktop: 32);
  }
  
  static double titleFontSize(BuildContext context) {
    return responsiveValue(context, mobile: 20, tablet: 22, desktop: 24);
  }
  
  static double bodyFontSize(BuildContext context) {
    return responsiveValue(context, mobile: 14, tablet: 15, desktop: 16);
  }
  
  static double captionFontSize(BuildContext context) {
    return responsiveValue(context, mobile: 12, tablet: 13, desktop: 14);
  }
  
  // ============================================
  // Layout Dimensions
  // ============================================
  
  /// Safe area padding
  static EdgeInsets safeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }
  
  /// App bar height
  static double appBarHeight(BuildContext context) {
    return responsiveValue(
      context,
      mobile: kToolbarHeight,
      tablet: kToolbarHeight * 1.2,
      desktop: kToolbarHeight * 1.5,
    );
  }
  
  /// Maximum content width (for desktop centering)
  static double maxContentWidth(BuildContext context) {
    return responsiveValue(
      context,
      mobile: double.infinity,
      tablet: 900,
      desktop: 1200,
    );
  }
  
  /// Card elevation
  static double cardElevation(BuildContext context) {
    return responsiveValue(context, mobile: 2, tablet: 3, desktop: 4);
  }
  
  /// Border radius
  static double borderRadius(BuildContext context, {double base = 12.0}) {
    return responsiveValue(
      context,
      mobile: base,
      tablet: base * 1.2,
      desktop: base * 1.4,
    );
  }
  
  // ============================================
  // Grid & List Layouts
  // ============================================
  
  /// Grid columns based on screen size
  static int gridColumns(BuildContext context) {
    if (isDesktop(context)) return 4;
    if (isTablet(context)) return 3;
    return 2;
  }
  
  /// Grid aspect ratio
  static double gridAspectRatio(BuildContext context) {
    return responsiveValue(context, mobile: 1.0, tablet: 1.1, desktop: 1.2);
  }
  
  /// List tile height
  static double listTileHeight(BuildContext context) {
    return responsiveValue(context, mobile: 72, tablet: 80, desktop: 88);
  }
  
  // ============================================
  // Spacing
  // ============================================
  
  /// Responsive spacing (general purpose)
  static double spacing(BuildContext context, {double base = 16.0}) {
    return responsiveValue(
      context,
      mobile: base,
      tablet: base * 1.25,
      desktop: base * 1.5,
    );
  }
  
  /// Small spacing
  static double smallSpacing(BuildContext context) => spacing(context, base: 8.0);
  
  /// Medium spacing
  static double mediumSpacing(BuildContext context) => spacing(context, base: 16.0);
  
  /// Large spacing
  static double largeSpacing(BuildContext context) => spacing(context, base: 24.0);
  
  // ============================================
  // Buttons & Interactive Elements
  // ============================================
  
  /// Button height
  static double buttonHeight(BuildContext context) {
    return responsiveValue(context, mobile: 48, tablet: 52, desktop: 56);
  }
  
  /// Icon size
  static double iconSize(BuildContext context, {double base = 24.0}) {
    return responsiveValue(
      context,
      mobile: base,
      tablet: base * 1.2,
      desktop: base * 1.4,
    );
  }
  
  /// FAB size
  static double fabSize(BuildContext context) {
    return responsiveValue(context, mobile: 56, tablet: 64, desktop: 72);
  }
  
  // ============================================
  // Dialogs & Bottom Sheets
  // ============================================
  
  /// Dialog width
  static double dialogWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (isDesktop(context)) return 600;
    if (isTablet(context)) return screenWidth * 0.7;
    return screenWidth * 0.9;
  }
  
  /// Bottom sheet max height
  static double bottomSheetMaxHeight(BuildContext context) {
    return screenHeight(context) * 0.9;
  }
  
  // ============================================
  // Utility Widgets
  // ============================================
  
  /// Responsive builder widget
  static Widget builder({
    required BuildContext context,
    required Widget Function(BuildContext context, DeviceType deviceType) builder,
  }) {
    DeviceType deviceType;
    if (isDesktop(context)) {
      deviceType = DeviceType.desktop;
    } else if (isTablet(context)) {
      deviceType = DeviceType.tablet;
    } else {
      deviceType = DeviceType.mobile;
    }
    return builder(context, deviceType);
  }
  
  /// Wrap content with max width constraint (for desktop)
  static Widget constrainedContent({
    required BuildContext context,
    required Widget child,
    double? maxWidth,
  }) {
    final width = maxWidth ?? maxContentWidth(context);
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: width),
        child: child,
      ),
    );
  }
}

/// Device type enum
enum DeviceType {
  mobile,
  tablet,
  desktop,
}

/// Extension for easier responsive access
extension ResponsiveContext on BuildContext {
  bool get isMobile => ResponsiveHelper.isMobile(this);
  bool get isTablet => ResponsiveHelper.isTablet(this);
  bool get isDesktop => ResponsiveHelper.isDesktop(this);
  bool get isPortrait => ResponsiveHelper.isPortrait(this);
  bool get isLandscape => ResponsiveHelper.isLandscape(this);
  
  double get screenWidth => ResponsiveHelper.screenWidth(this);
  double get screenHeight => ResponsiveHelper.screenHeight(this);
}










