import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class PlatformUtil {
  static BaseDeviceInfo? deviceInfo;

  static bool _isTable = false;

  static Future<void> init(BuildContext context) async {
    if (deviceInfo == null) {
      var deviceInfoPlus = DeviceInfoPlugin();
      deviceInfo = await deviceInfoPlus.deviceInfo;
    }

    var size = MediaQuery.of(context).size;
    if (!isWeb() &&
        Platform.isIOS &&
        deviceInfo != null &&
        deviceInfo!.data["systemName"] == "iPadOS") {
      _isTable = true;
    } else {
      if (size.shortestSide > 600) {
        _isTable = true;
      }
    }

    // double ratio = size.width / size.height;
    // if ((ratio >= 0.74) && (ratio < 1.5)) {
    //   _isTable = true;
    // }
  }

  static bool isWindows() {
    if (isWeb()) {
      return false;
    }

    return Platform.isWindows;
  }

  static bool isMacOS() {
    if (isWeb()) {
      return false;
    }

    return Platform.isMacOS;
  }

  static bool isAndroid() {
    if (isWeb()) {
      return false;
    }

    return Platform.isAndroid;
  }

  static bool isIOS() {
    if (isWeb()) {
      return false;
    }

    return Platform.isIOS;
  }

  static bool isWeb() {
    return kIsWeb;
  }

  static bool isTableModeWithoutSetting() {
    if (isPC()) {
      return true;
    }

    return _isTable;
  }

  static bool isWindowsOrLinux() {
    if (isWeb()) {
      return false;
    }
    return Platform.isWindows || Platform.isLinux;
  }

  static bool isPC() {
    if (isWeb()) {
      return false;
    }
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  static String getPlatformName() {
    if (isWeb()) {
      return "Web";
    } else if (Platform.isAndroid) {
      return "Android";
    } else if (Platform.isIOS) {
      return "IOS";
    } else if (Platform.isWindows) {
      return "Windows";
    } else if (Platform.isMacOS) {
      return "MacOS";
    }

    return "Unknow";
  }
}
