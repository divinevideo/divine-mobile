// ABOUTME: Reads the device's physical RAM through a native method channel.
// ABOUTME: Returns null where the platform does not report it.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:unified_logger/unified_logger.dart';

/// Method-channel-backed reader for the device's physical memory.
///
/// Android reports `ActivityManager.MemoryInfo.totalMem`, iOS
/// `ProcessInfo.physicalMemory`. Both are a little below the installed RAM,
/// because the kernel and firmware keep part of it. Web and desktop builds
/// have no channel and report null.
class DeviceMemoryService {
  const DeviceMemoryService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'divine/device_memory';

  final MethodChannel _channel;

  /// Physical memory in bytes as the OS reports it, or null when unknown.
  Future<int?> physicalMemoryBytes() async {
    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return null;
    }

    try {
      final bytes = await _channel.invokeMethod<int>('getPhysicalMemoryBytes');
      return bytes != null && bytes > 0 ? bytes : null;
    } on PlatformException catch (e) {
      Log.warning(
        'Device memory lookup failed: ${e.code}',
        name: 'DeviceMemoryService',
        category: LogCategory.system,
      );
      return null;
    } on MissingPluginException {
      Log.warning(
        'Device memory channel missing',
        name: 'DeviceMemoryService',
        category: LogCategory.system,
      );
      return null;
    }
  }
}
