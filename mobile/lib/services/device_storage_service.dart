// ABOUTME: Reads the device's disk capacity and free space through a native
// ABOUTME: method channel. Returns null where the platform does not report it.

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:unified_logger/unified_logger.dart';

/// Capacity and free space of the volume that holds the app's data.
class DeviceStorageSpace extends Equatable {
  /// Creates a storage reading.
  const DeviceStorageSpace({required this.totalBytes, required this.freeBytes});

  /// Total capacity of the volume in bytes.
  final int totalBytes;

  /// Bytes the app could still write.
  final int freeBytes;

  @override
  List<Object?> get props => [totalBytes, freeBytes];
}

/// Method-channel-backed reader for the device's disk space.
///
/// iOS reports `volumeAvailableCapacityForImportantUsage`, which includes
/// space the OS would purge on demand. Android reports `StatFs` over the
/// app's files directory. Web and desktop builds have no channel and report
/// null.
class DeviceStorageService {
  /// Creates a reader that talks to [channel], or the app's own channel.
  const DeviceStorageService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'divine/device_storage';

  final MethodChannel _channel;

  /// The current disk capacity and free space, or null when unknown.
  Future<DeviceStorageSpace?> storageSpace() async {
    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return null;
    }

    try {
      final reading = await _channel.invokeMapMethod<String, Object?>(
        'getStorageSpace',
      );
      final total = reading?['totalBytes'];
      final free = reading?['freeBytes'];
      if (total is! int || free is! int) return null;
      if (total <= 0 || free < 0 || free > total) return null;
      return DeviceStorageSpace(totalBytes: total, freeBytes: free);
    } on PlatformException catch (e) {
      Log.warning(
        'Device storage lookup failed: ${e.code}',
        name: 'DeviceStorageService',
        category: LogCategory.system,
      );
      return null;
    } on MissingPluginException {
      Log.warning(
        'Device storage channel missing',
        name: 'DeviceStorageService',
        category: LogCategory.system,
      );
      return null;
    }
  }
}
