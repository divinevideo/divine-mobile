// ABOUTME: Exposes the device-level post Live Activity repository to
// ABOUTME: account containers; null where the feature does not exist.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/services/post_live_activity_channel.dart';
import 'package:openvine/services/post_live_activity_registrar.dart';
import 'package:post_live_activity_repository/post_live_activity_repository.dart';

/// The device-level pieces of the post Live Activity. Device-scoped because
/// an activity outlives an account switch.
class PostLiveActivityDevice {
  /// Creates the device-level bundle.
  const PostLiveActivityDevice({
    required this.channel,
    required this.registrar,
    required this.repository,
  });

  /// The native bridge.
  final PostLiveActivityChannel channel;

  /// Sends registrations as the account that owns them.
  final PostLiveActivityRegistrar registrar;

  /// Decides when the activity starts, registers and ends.
  final PostLiveActivityRepository repository;
}

/// The shared repository, or null off iOS. Overridden from `DeviceScope`.
final postLiveActivityRepositoryProvider =
    Provider<PostLiveActivityRepository?>(
      (_) => null,
    );

/// The shared registrar, or null off iOS. Overridden from `DeviceScope`.
final postLiveActivityRegistrarProvider = Provider<PostLiveActivityRegistrar?>(
  (_) => null,
);
