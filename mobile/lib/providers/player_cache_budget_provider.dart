// ABOUTME: Riverpod provider for the Android player-cache budget configured at
// ABOUTME: launch, which can only be set when the player cache is created.

import 'package:divine_video_player/divine_video_player.dart'
    show kDefaultCacheMaxSizeBytes;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The byte budget the Android player's disk cache was created with.
///
/// Startup sizes it to the disk once (`startupPlayerCacheBudgetBytes`) and
/// pins the result into every account container through
/// `DeviceScope.overrides`, so Settings → Storage and bug reports show the
/// limit actually in force. [kDefaultCacheMaxSizeBytes] where nothing sized
/// it: platforms without a player cache, and containers built in tests.
final playerCacheBudgetBytesProvider = Provider<int>(
  (ref) => kDefaultCacheMaxSizeBytes,
);
