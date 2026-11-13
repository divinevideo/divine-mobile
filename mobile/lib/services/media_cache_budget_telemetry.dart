// ABOUTME: Coarse labels for the disk and the media-cache budget, recorded so
// ABOUTME: cache sizing can be tuned from real devices rather than guesses.

import 'package:openvine/constants/storage_cache_constants.dart';
import 'package:openvine/services/device_storage_service.dart';
import 'package:openvine/services/media_cache_budget.dart';

/// Marketed storage tiers, in decimal gigabytes, that a disk is named by.
const List<int> _storageTiersGb = [16, 32, 64, 128, 256, 512, 1024];

const int _bytesPerGb = 1000 * 1000 * 1000;
const int _bytesPerMb = 1024 * 1024;

/// Labels describing [storage] and the [budget] in force.
///
/// Every value is a coarse bucket — the marketed size a disk falls under, a
/// free-space band, a budget band — so the labels say what kind of device
/// this is without telling one device from another.
Map<String, String> mediaCacheBudgetProperties({
  required DeviceStorageSpace? storage,
  required MediaCacheBudget budget,
  required bool automatic,
}) => {
  'storage_total': storage == null
      ? 'unknown'
      : _storageTotalLabel(storage.totalBytes),
  'storage_free_pct': storage == null
      ? 'unknown'
      : _freePercentLabel(storage.freeBytes * 100 / storage.totalBytes),
  'cache_mode': automatic ? 'automatic' : 'fixed',
  'cache_budget': _videoBudgetLabel(budget.videoBytes),
};

/// Sends [properties] as analytics user properties and as crash-report keys,
/// so both every later event and every later crash carry them.
Future<void> reportMediaCacheBudgetProperties(
  Map<String, String> properties, {
  required Future<void> Function({
    required String name,
    required String? value,
  })
  setUserProperty,
  required Future<void> Function(String key, Object value) setCustomKey,
}) async {
  await Future.wait([
    for (final MapEntry(:key, :value) in properties.entries) ...[
      setUserProperty(name: key, value: value),
      setCustomKey(key, value),
    ],
  ]);
}

/// The smallest marketed tier the reading fits under. Android reports only
/// the data partition, so a 64 GB phone reads well under 64.
String _storageTotalLabel(int totalBytes) {
  final gb = totalBytes / _bytesPerGb;
  for (final tier in _storageTiersGb) {
    if (gb <= tier) return tier >= 1024 ? '1tb' : '${tier}gb';
  }
  return '2tb_plus';
}

String _freePercentLabel(double percent) => switch (percent) {
  < 5 => 'lt5',
  < 10 => '5_10',
  < 15 => '10_15',
  < 25 => '15_25',
  < 50 => '25_50',
  _ => '50_plus',
};

String _videoBudgetLabel(int bytes) {
  if (bytes <= kVideoCacheFloorBytes) return 'floor';
  if (bytes < 256 * _bytesPerMb) return 'lt256mb';
  if (bytes < 1024 * _bytesPerMb) return 'lt1gb';
  if (bytes < kCacheLimitDefaultBytes) return 'lt2gb';
  if (bytes == kCacheLimitDefaultBytes) return '2gb';
  return 'gt2gb';
}
