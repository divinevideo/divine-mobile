// ABOUTME: Build configuration service providing compile-time feature flag defaults
// ABOUTME: Maps environment variables to feature flag defaults for build-time configuration

import 'package:openvine/config/song_catalog_config.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';

class BuildConfiguration {
  const BuildConfiguration({
    this.consentDeliveryVerified = const bool.fromEnvironment(
      'PARENT_CONSENT_DELIVERY_VERIFIED',
    ),
    this.songCatalogConfigured = SongCatalogConfig.isConfigured,
  });

  /// Enabled only in builds targeting a verified consent deployment.
  final bool consentDeliveryVerified;

  /// Whether this build carries the developer token the song catalog needs.
  final bool songCatalogConfigured;

  /// Get the default value for a feature flag from environment variables
  bool getDefault(FeatureFlag flag) {
    switch (flag) {
      case FeatureFlag.publishingIdeas:
        return const bool.fromEnvironment('FF_PUBLISHING_IDEAS');
      case FeatureFlag.debugTools:
        return const bool.fromEnvironment('FF_DEBUG_TOOLS', defaultValue: true);
      case FeatureFlag.blueskyPublishing:
        return const bool.fromEnvironment('FF_BLUESKY_PUBLISHING');
      case FeatureFlag.integratedApps:
        return const bool.fromEnvironment('FF_INTEGRATED_APPS');
      case FeatureFlag.accountSwitching:
        return const bool.fromEnvironment('FF_ACCOUNT_SWITCHING');
      case FeatureFlag.advancedRelaySettings:
        return const bool.fromEnvironment('FF_ADVANCED_RELAY_SETTINGS');
      case FeatureFlag.feedTuning:
        // TODO(#6649): Re-promote after divine-funnelcake#691 ships.
        return const bool.fromEnvironment('FF_FEED_TUNING');
      case FeatureFlag.communityContentWarnings:
        // Default OFF pending T&S sign-off on surfacing warnings from
        // unverified community votes (#4771).
        return const bool.fromEnvironment('FF_COMMUNITY_CONTENT_WARNINGS');
      case FeatureFlag.newPostNotifications:
        // Default OFF until divine-push-service fans kind 34236 out to
        // d=notify subscribers. On without it, the bell publishes a
        // subscription no service reads.
        return const bool.fromEnvironment('FF_NEW_POST_NOTIFICATIONS');
      case FeatureFlag.clientSeenFiltering:
        return const bool.fromEnvironment(
          'FF_CLIENT_SEEN_FILTERING',
          defaultValue: true,
        );
      case FeatureFlag.postPublishConfirmationExperiment:
        return const bool.fromEnvironment(
          'FF_POST_PUBLISH_CONFIRMATION_EXPERIMENT',
          defaultValue: true,
        );
      case FeatureFlag.postPublishConfirmationTreatment:
        return const bool.fromEnvironment(
          'FF_POST_PUBLISH_CONFIRMATION_TREATMENT',
          defaultValue: true,
        );
      case FeatureFlag.groupMessages:
        // Default OFF until group messaging is ready to turn on (#8269). The
        // flag gates the picker that starts a group and filing a room someone
        // else starts as a room.
        return const bool.fromEnvironment('FF_GROUP_MESSAGES');
      case FeatureFlag.bunnyPlayback:
        return const bool.fromEnvironment('FF_BUNNY_PLAYBACK');
      case FeatureFlag.b2PlaybackCanary:
      case FeatureFlag.bunnyPlaybackCanary:
        // A device-local developer opt-in, never enabled for an entire build.
        return false;
      case FeatureFlag.concordChat:
        // A configured public community is the release opt-in. Invalid invite
        // material stays visible as a membership error, never a POC fallback.
        // Unconfigured developer/reviewer builds retain their explicit opt-in.
        return const String.fromEnvironment('CONCORD_INVITE_URL').isNotEmpty ||
            const bool.fromEnvironment('FF_CONCORD_CHAT');
      case FeatureFlag.songCatalog:
        // An internal prototype: off unless a build asks for it, and a
        // preference cannot turn it on in a build without a developer token.
        return songCatalogConfigured &&
            const bool.fromEnvironment('FF_SONG_CATALOG');
      case FeatureFlag.confirmationSignIn:
        return const bool.fromEnvironment('FF_CONFIRMATION_SIGN_IN');
      case FeatureFlag.minorConsentInAppRecording:
        // A preference cannot override the build's verified-deployment gate.
        return consentDeliveryVerified &&
            const bool.fromEnvironment('FF_MINOR_CONSENT_IN_APP_RECORDING');
      case FeatureFlag.largeScreenLayout:
        return const bool.fromEnvironment('FF_LARGE_SCREEN_LAYOUT');
    }
  }

  /// Check if a flag has a default value defined
  bool hasDefault(FeatureFlag flag) {
    // All flags have defaults in our implementation
    return true;
  }

  /// Get the environment variable key for a flag
  String getEnvironmentKey(FeatureFlag flag) {
    switch (flag) {
      case FeatureFlag.publishingIdeas:
        return 'FF_PUBLISHING_IDEAS';
      case FeatureFlag.debugTools:
        return 'FF_DEBUG_TOOLS';
      case FeatureFlag.blueskyPublishing:
        return 'FF_BLUESKY_PUBLISHING';
      case FeatureFlag.integratedApps:
        return 'FF_INTEGRATED_APPS';
      case FeatureFlag.accountSwitching:
        return 'FF_ACCOUNT_SWITCHING';
      case FeatureFlag.advancedRelaySettings:
        return 'FF_ADVANCED_RELAY_SETTINGS';
      case FeatureFlag.feedTuning:
        return 'FF_FEED_TUNING';
      case FeatureFlag.communityContentWarnings:
        return 'FF_COMMUNITY_CONTENT_WARNINGS';
      case FeatureFlag.newPostNotifications:
        return 'FF_NEW_POST_NOTIFICATIONS';
      case FeatureFlag.clientSeenFiltering:
        return 'FF_CLIENT_SEEN_FILTERING';
      case FeatureFlag.postPublishConfirmationExperiment:
        return 'FF_POST_PUBLISH_CONFIRMATION_EXPERIMENT';
      case FeatureFlag.postPublishConfirmationTreatment:
        return 'FF_POST_PUBLISH_CONFIRMATION_TREATMENT';
      case FeatureFlag.groupMessages:
        return 'FF_GROUP_MESSAGES';
      case FeatureFlag.bunnyPlayback:
        return 'FF_BUNNY_PLAYBACK';
      case FeatureFlag.b2PlaybackCanary:
        return 'FF_B2_PLAYBACK_CANARY';
      case FeatureFlag.bunnyPlaybackCanary:
        return 'FF_BUNNY_PLAYBACK_CANARY';
      case FeatureFlag.concordChat:
        return 'FF_CONCORD_CHAT';
      case FeatureFlag.songCatalog:
        return 'FF_SONG_CATALOG';
      case FeatureFlag.confirmationSignIn:
        return 'FF_CONFIRMATION_SIGN_IN';
      case FeatureFlag.minorConsentInAppRecording:
        return 'FF_MINOR_CONSENT_IN_APP_RECORDING';
      case FeatureFlag.largeScreenLayout:
        return 'FF_LARGE_SCREEN_LAYOUT';
    }
  }
}
