// ABOUTME: Device configuration matrix for golden tests across different screen sizes
// ABOUTME: Defines standard test devices to ensure UI consistency across form factors

import 'package:flutter/widgets.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

/// Standard device configurations for golden testing
class GoldenTestDevices {
  /// iPhone SE - Small phone
  static const iphoneSE = Device(
    name: 'iphone_se',
    size: Size(375, 667),
    devicePixelRatio: 2.0,
  );

  /// iPhone 11 - Standard phone
  static const iphone11 = Device.iphone11;

  /// iPhone 14 Pro Max - Large phone
  static const iphone14ProMax = Device(
    name: 'iphone_14_pro_max',
    size: Size(430, 932),
    devicePixelRatio: 3.0,
  );

  /// iPad - Tablet portrait
  static const ipadPortrait = Device.tabletPortrait;

  /// iPad - Tablet landscape
  static const ipadLandscape = Device.tabletLandscape;

  /// Android Phone - Medium size
  static const androidPhone = Device(
    name: 'android_phone',
    size: Size(412, 869),
    devicePixelRatio: 2.5,
  );

  /// Default test devices for most golden tests
  static const defaultDevices = [
    iphoneSE,
    iphone11,
    androidPhone,
    ipadPortrait,
  ];

  /// Minimal device set for quick tests
  static const minimalDevices = [iphone11, androidPhone];

  /// Comprehensive device set for critical UI components
  static const comprehensiveDevices = [
    iphoneSE,
    iphone11,
    iphone14ProMax,
    androidPhone,
    ipadPortrait,
    ipadLandscape,
  ];

  /// Phone-only device set
  static const phoneDevices = [
    iphoneSE,
    iphone11,
    iphone14ProMax,
    androidPhone,
  ];

  /// Tablet-only device set
  static const tabletDevices = [ipadPortrait, ipadLandscape];
}
